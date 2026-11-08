extends Node
## Lauf: einzeln (Name systeme)
## Modi: kern, system:run_record, system:difficulty, system:targeting, system:economy, system:save, system:waves, system:coop, system:inventory, system:leveling, system:build, system:controls
## Gemeinsame Spielsysteme (scripts/systems/, tools/systeme.py): jedes System im Katalog lässt sich ohne Modus
## anlegen, die Kaskade Basiswerte → Modus-Daten (modes.json system_cfg) mischt wie CSS (Modus gewinnt, tief),
## und jeder Modus bekommt seine angekreuzten Systeme als Kind-Knoten.
## Start: tools/run_tests.sh systeme

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	_catalog()
	_cascade()
	_modes()
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _catalog() -> void:
	var kat = Database.load_json(SystemHost.DIR + "katalog.json")
	check(typeof(kat) == TYPE_DICTIONARY and not kat.get("systeme", {}).is_empty(), "Katalog lesbar")
	for n in kat.get("systeme", {}):
		var path := SystemHost.script_path(n)
		check(ResourceLoader.exists(path), "%s hat ein Skript" % n)
		var obj = load(path).new()
		check(obj != null, "%s lässt sich anlegen" % n)
		if obj is Node:
			obj.free()
	var game := Node.new()
	add_child(game)
	var got := SystemHost.attach(game, "", kat.get("systeme", {}).keys())
	check(got.has("waves") and game.get_node_or_null("waves") is GameSystem, "Systeme hängen als Knoten am Spiel")
	check(not got.has("leveling"), "Bibliothek (Leveling) wird nicht als Knoten angelegt")
	check(got.waves.game == game, "System kennt sein Spiel")
	check(got.waves.hook("gibt_es_nicht", [], 7) == 7, "Haken ohne Funktion im Spiel liefert den Ersatzwert")
	game.free()


func _cascade() -> void:
	var base := {"tempo": 1.0, "liste": [1, 2], "gold": {"kill": 1, "boss": 10}, "_info": "x"}
	var over := {"liste": [3], "gold": {"boss": 25}, "neu": true, "_info": "y"}
	var c := SystemHost.cascade(SystemHost.cascade({}, base), over)
	check(c.tempo == 1.0, "Basiswert bleibt, wenn der Modus ihn nicht nennt")
	check(c.gold.boss == 25 and c.gold.kill == 1, "verschachtelt: Modus gewinnt nur bei seinen Schlüsseln")
	check(c.liste == [3], "Listen ersetzt der Modus ganz")
	check(c.neu == true, "neue Werte aus dem Modus kommen dazu")
	check(not c.has("_info"), "Schlüssel mit _ bleiben draußen")
	check(base.gold.boss == 10, "Basis bleibt unverändert")
	# echte Kaskade über modes.json: kurz einen Modus-Eintrag ergänzen
	var m: Dictionary = Database.modes[0]
	var had = m.get("system_cfg")
	m["system_cfg"] = {"waves": {"_probe": 1, "probe": {"a": 2}}}
	var cfg := SystemHost.config(str(m.id), "waves")
	check(cfg.get("probe", {}).get("a") == 2, "system_cfg des Modus landet in cfg")
	if had == null:
		m.erase("system_cfg")
	else:
		m["system_cfg"] = had


func _modes() -> void:
	for m in Database.modes:
		var list: Array = m.get("systems", [])
		check(not list.is_empty(), "%s kreuzt Systeme an" % m.id)
		var game := Node.new()
		add_child(game)
		var got := SystemHost.attach(game, str(m.id))
		check(got.size() == list.filter(func(n): return n != "leveling").size(),
			"%s bekommt %d Systeme als Knoten" % [m.id, got.size()])
		game.free()
