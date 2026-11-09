extends Node
## Lauf: einzeln (Name sound)
## Modi: kern
## Sounds (sfx.gd, data/sfx.json): alle Dateien laden, jeder Tower hat einen Schuss-Sound, die acht
## Grund-Gems klingen verschieden, Drosselung bei vielen gleichen Schüssen, Ambiente an/aus.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	var data: Dictionary = Sfx._data
	check(not data.is_empty(), "sfx.json geladen")
	for id in data.sounds:
		check(Sfx._stream(id) != null, "Sound %s lädt (%s)" % [id, data.sounds[id].file])
	for ev in data.events:
		check(data.sounds.has(str(data.events[ev].sound)), "Ereignis %s hat einen Sound" % ev)

	# Jeder Tower aller Modi bekommt einen vorhandenen Schuss-Sound
	var missing := []
	for id in Database.towers:
		var s := Sfx.shot_for(id, 0)
		if s.is_empty() or not data.sounds.has(s.sound):
			missing.append(id)
	check(missing.is_empty(), "alle %d Tower haben einen Schuss-Sound %s" % [Database.towers.size(), missing])

	# Die acht Grund-Gems klingen verschieden (anderer Sound oder andere Tonhöhe)
	var seen := {}
	for id in ["ruby", "topaz", "emerald", "aquamarine", "sapphire", "amethyst", "opal", "diamond"]:
		var s := Sfx.shot_for(id, 0)
		seen["%s@%.2f" % [s.sound, s.pitch]] = id
	check(seen.size() == 8, "8 Grund-Gems, %d Klänge: %s" % [seen.size(), seen])
	check(Sfx.shot_for("ruby", 4).pitch < Sfx.shot_for("ruby", 0).pitch, "höhere Stufe klingt tiefer")
	check(Sfx.shot_for("ruby", 0).sound == "shot_blast", "Rubin knallt")
	var magic := Sfx.shot_for("eeve_magic_base_tower", 0)
	check(Sfx._stream(magic.sound).get_length() / magic.pitch < 0.4, "Magie-Turm kurz (%s)" % magic)
	check(Sfx.shot_for("eeve_rock_launcher", 0).sound == "thud", "Steinwerfer (Betäubung) dumpf")

	# Viele gleiche Schüsse auf einmal: gedrosselt, Ereignisse kommen trotzdem durch
	for i in 50:
		Sfx.play_shot("ruby", 0)
	var shots := Sfx._players.filter(func(p): return Sfx.is_busy(p) and p.has_meta("shot")).size()
	check(shots <= 1, "50 gleiche Schüsse im selben Moment: %d Stimme(n)" % shots)
	for id in ["sapphire", "emerald", "topaz", "amethyst", "diamond", "opal", "aquamarine"]:
		for t in 6:
			Sfx.play_shot(id, t)
	shots = Sfx._players.filter(func(p): return Sfx.is_busy(p) and p.has_meta("shot")).size()
	check(shots <= Sfx.MAX_SHOTS, "viele verschiedene Schüsse: höchstens %d Stimmen (%d)" % [Sfx.MAX_SHOTS, shots])
	Sfx.play("error")
	check(Sfx._players.any(func(p): return Sfx.is_busy(p) and p.stream == Sfx._stream("error")), "Fehler-Sound spielt trotz vieler Schüsse")
	Sfx.command_sound({"type": "place"}, true)
	Sfx.command_sound({"type": "option", "action": "combine"}, true)

	# Ambiente: Schleife an, wechseln, aus
	Sfx.set_ambience("amb_forest")
	check(Sfx.ambience() == "amb_forest" and Sfx._amb.stream.loop, "Wald-Ambiente läuft als Schleife")
	# Vögel nur ab und zu: erst Pause, dann ein kurzes Stück, dann wieder Pause
	var b: Dictionary = data.sounds.amb_forest.bursts
	check(not Sfx.ambience_on(), "Vögel nicht sofort")
	Sfx._process(float(b.first[1]) + 0.1)
	check(Sfx.ambience_on(), "Vögel nach der ersten Pause")
	Sfx._process(float(b.play[1]) + 0.1)
	check(not Sfx.ambience_on(), "Vögel nach höchstens %s s wieder still" % b.play[1])
	Sfx.set_ambience("amb_night")
	check(Sfx._amb.stream == Sfx._stream("amb_night"), "Nacht-Ambiente")
	Sfx.set_ambience("")
	check(Sfx.ambience() == "" and not Sfx._amb.playing, "Ambiente aus")

	Sfx.stop_all()
	for i in 3:
		await get_tree().process_frame
	print("FERTIG: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
