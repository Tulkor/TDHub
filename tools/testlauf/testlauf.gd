extends Node
## Automatische Testläufe: ein Bot spielt eine ganze Partie eines Modus auf Normal und schreibt das Ergebnis.
## Start: godot --headless --fixed-fps 60 --path . res://tools/testlauf/testlauf.tscn -- --modus=gemtd --stufe=3 --seed=1
## Besser über tools/testlauf.sh (mehrere Läufe parallel, Auswertung). Ausgabe: eine Zeile „ERGEBNIS {json}“.
## Stufen: 1 Gelegenheitsspieler, 2 solide, 3 gut, 4 sehr gut (Details je Bot in bot_<modus>.gd).

const BOTS := {
	"gemtd": "res://tools/testlauf/bot_gemtd.gd",
	"eevetd": "res://tools/testlauf/bot_eeve.gd",
	"shoppingmaul": "res://tools/testlauf/bot_maul.gd",
	"randgruppen": "res://tools/testlauf/bot_rg.gd",
	"youtd": "res://tools/testlauf/bot_youtd.gd",
}


func _ready() -> void:
	await get_tree().process_frame
	var args := {"modus": "gemtd", "stufe": "3", "seed": "1", "tempo": "4"}
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
	add_child(bot)
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = await bot.play(int(args.stufe), int(args.seed), float(args.tempo), args)
	res.modus = args.modus
	res.stufe = int(args.stufe)
	res.seed = int(args.seed)
	res.echtzeit_s = (Time.get_ticks_msec() - t0) / 1000.0
	print("ERGEBNIS ", JSON.stringify(res))
	Engine.time_scale = 1.0
	get_tree().quit()
	# manche Modi hängen beim Beenden (Profil, Netz): spätestens nach 10 s hart beenden
	await get_tree().create_timer(10.0, true, false, true).timeout
	OS.kill(OS.get_process_id())
