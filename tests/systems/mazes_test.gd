extends Node
## Lauf: einzeln (Name sysmazes)
## Modi: system:mazes, gemtd
## Maze-Vorlagen (System mazes, Lukas 2026-11-09): mitgelieferte Vorlagen für Klassisch, Overlay-Zustände
## (offen/gebaut/Konflikt), Einrasten der Bauvorschau, Planen (setzen, entfernen, Weg nie versperren),
## eigene Vorlagen speichern, umbenennen, löschen, Fenster in der linken Spalte.
## Start: tools/run_tests.sh sysmazes

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var plain := Node.new()
	add_child(plain)
	check(SystemHost.attach(plain, "", ["mazes"]).has("mazes"), "mazes lässt sich ohne Modus anlegen")
	plain.free()
	check(SystemHost.declared("gemtd").has("mazes"), "GemTD hat das System mazes")

	Profile.dir = "user://test_profile"
	RunHistory.path = "user://test_run_history.json"
	Session.skip_setup = true
	Session.map_path = "res://data/maps/classic.json"
	var old_dir: String = load("res://scripts/systems/mazes/mazes.gd").dir
	load("res://scripts/systems/mazes/mazes.gd").dir = "user://test_mazes"
	_clean()
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	var m: Node = game.systems.mazes
	check(m.overlay != null, "Overlay liegt auf dem Feld")
	var list: Array = m.templates()
	check(list.size() == 2 and list.all(func(t): return t.get("builtin", false)), "zwei mitgelieferte Vorlagen für Klassisch")
	var len0: int = m.template_length(list[0])
	check(len0 > game.path_length and len0 < 4 * game.map.width * game.map.height, "Vorlage macht den Weg länger: %d statt %d Felder" % [len0, game.path_length])

	m.show_template(m.find("weglaenge"))
	check(m.progress() == Vector2i(0, 200) and m.overlay.plate_count() == 200, "200 offene Blöcke, 200 Platten")
	# einen Block bauen: gilt als gebaut; Einrasten auf den Block
	var a := Vector2i(-1, -1)
	for b in m.active.blocks:
		var c := Vector2i(int(b[0]), int(b[1]))
		if game.can_place(c):
			a = c
			break
	check(m.snap(a + Vector2i(1, 1), a + Vector2i(1, 0)) == a, "Bauvorschau rastet auf den offenen Block ein")
	game.submit({"type": "place", "cell": a})
	m.refresh()
	check(m.progress().x == 1, "gesetzter Gem zählt als gebaut")
	check(m.snap(a + Vector2i(1, 1), a + Vector2i(1, 0)) == a + Vector2i(1, 0), "gebauter Block rastet nicht mehr ein")
	m.show_done = false
	m.refresh(true)
	check(m.overlay.plate_count() == 199, "gebaute Blöcke ausblendbar")
	m.show_done = true

	# Planen: neuer Entwurf, setzen, entfernen, versperren geht nicht
	m.hide_template()
	m.set_editing(true)
	check(m.editing and m.block_count() == 0, "Planen ohne Vorlage beginnt leer")
	var free := _free_anchor(game, m)
	check(m.plan_click(free, free) and m.has_block(free), "Klick setzt einen Block")
	check(m.plan_length() > 0.0, "Weg mit Entwurf wird berechnet (%.1f)" % m.plan_length())
	m.plan_click(free + Vector2i(1, 1), free)
	check(not m.has_block(free), "Klick auf den Block entfernt ihn")
	var wp: Vector2i = game.map.waypoints(0)[0]
	check(not m.can_plan(wp - Vector2i(1, 1)), "kein Block auf dem Startpunkt")
	m.plan_click(free, free)
	var saved: Dictionary = m.save_active("Testmaze")
	check(not m.dirty and m.own().size() == 1 and m.own()[0].name == "Testmaze", "Entwurf gespeichert")
	m.rename(saved.id, "Umbenannt")
	check(m.find(saved.id).name == "Umbenannt", "umbenannt")
	m.set_editing(false)
	var cur: Dictionary = m.save_current("Aus dem Spiel")
	check(cur.blocks.size() == game.rocks.size() + game.towers.size(), "aktuelles Maze: alle Steine und Tower (%d)" % cur.blocks.size())
	check(m.templates()[0].id == cur.id, "neueste eigene Vorlage steht oben")
	m.delete(saved.id)
	check(m.find(saved.id).is_empty(), "gelöscht")

	# Fenster in der linken Spalte: zugeklappt eine Zeile, Taste M klappt auf
	var hud: Node = game.hud
	var panel: Node = hud.maze_panel
	check(panel != null and panel.visible and not panel.expanded, "Fenster zugeklappt in der linken Spalte")
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	hud._unhandled_input(key)
	await get_tree().process_frame
	check(panel.expanded and panel._show_box.visible, "Taste M klappt auf")
	m.set_editing(true)
	await get_tree().process_frame
	check(panel._plan_box.visible and not panel._show_box.visible, "Planen zeigt die Planen-Ansicht")
	hud._unhandled_input(key)
	check(not panel.expanded and not m.editing, "Zuklappen beendet das Planen")
	game.free()
	_clean()
	load("res://scripts/systems/mazes/mazes.gd").dir = old_dir
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _free_anchor(game: Node, m: Node) -> Vector2i:
	for y in range(2, game.map.height - 2, 2):
		for x in range(2, game.map.width - 2, 2):
			var a := Vector2i(x, y)
			if m.can_plan(a) and game.can_place(a):
				return a
	return Vector2i(-1, -1)


func _clean() -> void:
	for f in ["classic.json", "einstellungen.json"]:
		DirAccess.remove_absolute("user://test_mazes/" + f)
