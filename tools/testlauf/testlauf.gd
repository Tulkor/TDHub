extends Node
## Automatische Testläufe: ein Bot spielt eine ganze Partie eines Modus und schreibt das Ergebnis.
## Start: godot --headless --fixed-fps 60 --path . res://tools/testlauf/testlauf.tscn -- --modus=gemtd --stufe=3 --seed=1
##   [--schwierigkeit=einfach|mittel|schwer] [--aufstieg=N] (Aufstieg nur auf Schwer, wie im Startfenster)
## Besser über tools/testlauf.sh (mehrere Läufe parallel, Auswertung). Ausgabe: eine Zeile „ERGEBNIS {json}“.
## [--skill=0..100] stufenlose Spielstärke (bot_basis.wurf). Checkpoints (checkpoint.gd): [--cp_welle=N --cp_datei=pfad]
## legt vor Welle N einen Stand ab, [--checkpoint=pfad] startet aus diesem Stand.
## Stufen: 1 Gelegenheitsspieler, 2 solide, 3 gut, 4 sehr gut (Details je Bot in bot_<modus>.gd).
## Je Welle misst messung.gd Druck (effektive Gegner-Leben), Knappheit (Weg-Anteil des vordersten Gegners) und Gold.

const Messung := preload("res://tools/testlauf/messung.gd")
const Checkpoint := preload("res://tools/testlauf/checkpoint.gd")
const SCHWIERIGKEITEN := ["einfach", "mittel", "schwer"]

const BOTS := {
	"gemtd": "res://tools/testlauf/bot_gemtd.gd",
	"eevetd": "res://tools/testlauf/bot_eeve.gd",
	"shoppingmaul": "res://tools/testlauf/bot_maul.gd",
	"randgruppen": "res://tools/testlauf/bot_rg.gd",
	"youtd": "res://tools/testlauf/bot_youtd.gd",
	"survivors": "res://tools/testlauf/bot_survivors.gd",
	"bollwerk": "res://tools/testlauf/bot_bollwerk.gd",
}
## Stärkste Stufe je Modus (Grundlage für --skill): GemTD Stufe 4 (Maze-Plan, Extra Chance) war in Testläufen auf
## Mittel/Schwer nicht besser als Stufe 3, deshalb dort 3.
const BESTE_STUFE := {"gemtd": "3"}
## Modi mit eigener Simulation (step), ohne Enemy-Gegner: keine Messung je Welle, keine Spielstände/Aufstiege.
const OHNE_MESSUNG := ["survivors", "bollwerk"]


func _ready() -> void:
	await get_tree().process_frame
	var args := {"modus": "gemtd", "stufe": "3", "seed": "1", "tempo": "4", "schwierigkeit": "mittel", "aufstieg": "0"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	seed(int(args.seed))
	Session.difficulty = 1
	Session.score_mode = false
	Session.rogue = false
	var bot: Node = load(BOTS[args.modus]).new()
	bot.name = "Bot"
	bot.diff = schwierigkeit(str(args.schwierigkeit))
	bot.aufstieg = maxi(int(args.aufstieg), 0) if bot.diff == 2 and not args.modus in OHNE_MESSUNG else 0
	# stufenlos: --skill=0..100 spielt mit der besten Stufe (--stufe, Standard BESTE_STUFE) und Fehlern (bot_basis.wurf)
	if args.has("skill"):
		bot.skill = clampf(float(args.skill), 0.0, 100.0)
		if not Array(OS.get_cmdline_user_args()).any(func(a): return str(a).begins_with("--stufe=")):
			args.stufe = BESTE_STUFE.get(args.modus, "4")
	bot.basis_stufe = int(args.stufe)
	# aus einem Checkpoint starten: Schwierigkeit und Aufstieg stehen im Stand, hier nur fürs Ergebnis
	var cp_welle := 0
	if args.has("checkpoint"):
		bot.cp_pfad = str(args.checkpoint)
		var f := FileAccess.open(bot.cp_pfad, FileAccess.READ)
		if f != null:
			var d = f.get_var()
			if d is Dictionary:
				cp_welle = int(d.get("welle", 0))
				bot.diff = int(d.get("diff", bot.diff))
				bot.aufstieg = int(d.get("aufstieg", bot.aufstieg))
	if args.has("cp_welle"):
		var cp: Node = Checkpoint.new()
		cp.ziel = bot
		cp.welle = int(args.cp_welle)
		cp.datei = str(args.get("cp_datei", "user://checkpoint_%s_w%d.stand" % [args.modus, cp.welle]))
		cp.meta = {"modus": args.modus, "diff": bot.diff, "aufstieg": bot.aufstieg, "seed": int(args.seed),
			"stufe": int(args.stufe), "skill": bot.skill}
		add_child(cp)
	add_child(bot)
	var messung: Node = null
	if not args.modus in OHNE_MESSUNG:
		messung = Messung.new()
		messung.ziel = bot
		add_child(messung)
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = await bot.play(int(args.stufe), int(args.seed), float(args.tempo), args)
	res.modus = args.modus
	res.stufe = int(args.stufe)
	if bot.skill >= 0.0:
		res.skill = bot.skill
	if cp_welle > 0:
		res.checkpoint = cp_welle
	res.seed = int(args.seed)
	res.schwierigkeit = SCHWIERIGKEITEN[bot.diff]
	res.aufstieg = bot.aufstieg
	res.tempo = float(args.tempo)
	if messung != null:
		res.merge(messung.result())
	res.echtzeit_s = (Time.get_ticks_msec() - t0) / 1000.0
	print("ERGEBNIS ", JSON.stringify(res))
	Engine.time_scale = 1.0
	get_tree().quit()
	# manche Modi hängen beim Beenden (Profil, Netz): spätestens nach 10 s hart beenden
	await get_tree().create_timer(10.0, true, false, true).timeout
	OS.kill(OS.get_process_id())


## einfach|mittel|schwer oder 0|1|2 → 0..2 (Einträge im Startfenster des Modus, siehe bot_basis.diff_index).
static func schwierigkeit(s: String) -> int:
	var i := SCHWIERIGKEITEN.find(s.to_lower())
	if i >= 0:
		return i
	return clampi(int(s), 0, 2) if s.is_valid_int() else 1
