extends Node
## Modi: kern, gemtd
## Automatischer Rauchtest: startet .../godot --headless --path . res://tests/smoke_test.tscn
## Lädt alle Szenen, spielt ein paar Runden automatisch und beendet sich mit Exit-Code 0/1.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	# Run-History der Tests nicht in die echte Liste schreiben
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile"
	# Einstellungen vor Runde 1 prüft nur _setup_test, sonst startet jedes Spiel gleich
	Session.skip_setup = true
	if FileAccess.file_exists(RunHistory.path):
		DirAccess.remove_absolute(RunHistory.path)
	await get_tree().process_frame
	check(Database.towers.size() >= 8, "Tower geladen: %d" % Database.towers.size())
	# UI-Größe: skaliert die 2D-Oberfläche, 50 bis 100 %, gespeichert
	var ui_before: float = Display.ui_scale
	Display.set_ui_scale(0.3)
	check(is_equal_approx(Display.ui_scale, 0.5) and is_equal_approx(get_tree().root.content_scale_factor, 0.5), "UI-Größe: nicht unter 50 %")
	Display.set_ui_scale(0.75)
	var ui_cfg := ConfigFile.new()
	ui_cfg.load(Display.SETTINGS)
	check(is_equal_approx(float(ui_cfg.get_value("display", "ui_scale", 0.0)), 0.75) and is_equal_approx(get_tree().root.content_scale_factor, 0.75), "UI-Größe 75 % gespeichert und angewendet")
	Display.set_ui_scale(ui_before)
	check(Database.enemies.size() >= 1, "Gegner geladen: %d" % Database.enemies.size())
	check(not Database.list_maps().is_empty(), "Maps gefunden")
	# Wellentypen: jede vierte Welle Flieger, versetzt dazu Massenwellen, dazu Bosse
	var kinds := {}
	for w in Database.wave_sets.get("classic", {}).get("waves", []):
		var k: String = load("res://scripts/game/game.gd").wave_type(w)
		kinds[k] = kinds.get(k, 0) + 1
	check(kinds.get("Masse", 0) >= 8 and kinds.get("Flieger", 0) >= 10 and kinds.get("Boss", 0) >= 1 and kinds.get("Boden", 0) >= 10,
		"alle vier Wellentypen kommen vor: %s" % [kinds])

	for m in Database.list_maps():
		var md := MapData.load_file(m.path)
		var pf := Pathfinder.new(md)
		check(not pf.compute_path().is_empty(), "Weg vorhanden auf Map %s" % m.id)
		# Rundreise JSON
		check(MapData.from_dict(md.to_dict()).to_dict() == md.to_dict(), "Map %s speichern/laden verlustfrei" % m.id)

	# Blockieren wird verhindert: Spawn einmauern
	var small := MapData.create_empty(9, 9)
	small.spawn = Vector2i(0, 0)
	small.goal = Vector2i(8, 8)
	small.marker_radius = 0
	var pf2 := Pathfinder.new(small)
	pf2.set_solid(Vector2i(1, 0), true)
	pf2.set_solid(Vector2i(1, 1), true)
	check(pf2.would_block(Vector2i(0, 1)), "letzter Ausgang wird als blockierend erkannt")
	check(not pf2.would_block(Vector2i(4, 4)), "normales Feld blockiert nicht")

	# Halbes Raster: eine Mauer aus 2×2-Towern mit einer Lücke von einem Feld bleibt passierbar
	var gap := MapData.create_empty(12, 11)
	gap.spawn = Vector2i(0, 0)
	gap.goal = Vector2i(11, 0)
	gap.marker_radius = 0
	var pf3 := Pathfinder.new(gap)
	for y in [0, 2, 4, 7, 9]:
		pf3.set_solid_cells(Board3D.footprint(Vector2i(5, y)), true)
	var gap_path := pf3.compute_path()
	check(not gap_path.is_empty() and Vector2i(5, 6) in gap_path, "Gegner passen durch eine Lücke von einer halben Towerbreite")
	check(pf3.would_block_cells(Board3D.footprint(Vector2i(4, 5))), "Tower in der Lücke würde blockieren")

	# Editoren laden
	for scene in [Session.MAP_EDITOR, Session.TOWER_EDITOR, Session.MAIN_MENU]:
		var inst: Node = load(scene).instantiate()
		add_child(inst)
		await get_tree().process_frame
		check(is_instance_valid(inst), "Szene lädt: " + scene)
		inst.queue_free()
		await get_tree().process_frame

	# Spiel automatisch spielen
	Session.map_path = Database.first_map().path
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for round_i in 3:
		var placed := 0
		var tries := 0
		while game.phase == game.Phase.BUILD and tries < 5000:
			tries += 1
			# nahe am aktuellen Weg bauen, wie ein Spieler
			var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
			var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
			if game.can_place(c):
				game.place_gem(c)
				placed += 1
		check(game.phase == game.Phase.CHOOSE, "Runde %d: %d Gems gesetzt, Auswahlphase" % [round_i + 1, placed])
		var t = game.round_towers[0]
		game._select(t)
		check(not game.choice_options(t).is_empty(), "Auswahloptionen vorhanden")
		# Große Hauptaktion: One-Shot-Rezept, sonst Kombinieren (zweiter gleicher Gem hebt ihn eine Qualität),
		# sonst Behalten
		var opts: Array = game.hud._options
		var main: int = opts.map(func(o): return o.style == "oneshot").find(true)
		if main < 0:
			main = maxi(opts.map(func(o): return o.get("combine_up", false)).find(true), 0)
		check(opts[main].style in ["primary", "oneshot"] and game.hud._main_index == main \
				and game.hud._main_button != null, "Behalten bzw. Kombinieren ist die große Hauptaktion")
		game._on_option_chosen(0)
		check(game.phase == game.Phase.WAVE, "Welle %d gestartet" % (round_i + 1))
		check(game.towers.size() == round_i + 1, "nur ein Tower behalten, Rest sind Steine (%d Steine)" % game.rocks.size())
		check(game.occupied.size() == 4 * (game.towers.size() + game.rocks.size()), "jeder Tower und Stein belegt 2×2 Felder")
		check(not game.ground_path.is_empty(), "Weg ist noch offen")
		Engine.time_scale = 8.0
		var frames := 0
		while game.phase == game.Phase.WAVE and frames < 20000:
			await get_tree().process_frame
			frames += 1
		print("  Tower-Schaden: ", game.towers.values().map(func(t): return [t.tower_id, t.cell, int(t.total_damage)]))
		check(game.phase == game.Phase.BUILD, "Welle %d beendet (Leben %d, Gold %d)" % [round_i + 1, game.lives, game.gold])

	# Stein entfernen (Bauphase)
	var rock: Vector2i = game.rocks.keys()[0]
	var gold_before: int = game.gold
	check(game.remove_rock(rock), "Stein entfernt")
	check(not game.rocks.has(rock) and game.can_place(rock), "Feld ist wieder bebaubar")
	check(game.gold == gold_before - game.rock_remove_cost(), "Kosten abgezogen")

	# Kombinieren: zwei gleiche Gems -> nächste Stufe, Rezept -> Silber
	game.debug_tower = "ruby:0"
	var cells := []
	var tries2 := 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var c := Vector2i(rng.randi_range(0, game.map.width - 1), rng.randi_range(0, game.map.height - 1))
		if game.can_place(c):
			if game.round_towers.size() == 2: game.debug_tower = "topaz:0"
			if game.round_towers.size() == 3: game.debug_tower = "diamond:0"
			if game.round_towers.size() == 4: game.debug_tower = "sapphire:0"
			game.place_gem(c)
			if game.round_towers.size() == 1:
				check(not game.can_place(c + Vector2i(1, 0)) and not game.can_place(c + Vector2i(1, 1)), "Tower überlappen sich nicht")
	var labels: Array = game.choice_options(game.round_towers[0]).map(func(o): return o.label)
	check(labels.size() == 2, "Rubin: Behalten + 2er-Kombination: %s" % [labels])
	labels = game.choice_options(game.round_towers[2]).map(func(o): return o.label)
	check(labels.any(func(l): return "Silber" in l), "Topas: Rezept Silber angeboten: %s" % [labels])

	# Falle aus derselben Runde: normaler Amethyst + fehlerhafter Smaragd -> Luftplatte (begehbar)
	game.round_towers.clear()
	for t in game.towers.values().filter(func(o): return o.is_new):
		game._turn_into_rock(t)
	game.phase = game.Phase.BUILD
	var plan := ["amethyst:2", "emerald:1", "ruby:4", "ruby:4", "ruby:4"]
	var placed_cells := []
	tries2 = 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = plan[game.round_towers.size()]
			game.place_gem(c)
	var amethyst = game.round_towers[0]
	labels = game.choice_options(amethyst).map(func(o): return o.label)
	check(labels.any(func(l): return "Luftplatte" in l), "Amethyst: Luftplatte angeboten: %s" % [labels])
	labels = game.choice_options(game.round_towers[2]).map(func(o): return o.label)
	check(labels.any(func(l): return "Großartiger Rubin" in l), "2 perfekte Rubine → Großartig: %s" % [labels])
	var down: Array = game.choice_options(game.round_towers[2]).filter(func(o): return o.label.begins_with("Abstufen"))
	check(down.size() == 1 and down[0].id == "ruby" and down[0].tier == 3, "Perfekten Rubin abstufen → %s" % [down.map(func(o): return o.label)])
	var views: Array = game.choice_options(game.round_towers[2]).map(func(o): return game._option_view(game.round_towers[2], o))
	var down_view: Array = views.filter(func(v): return v.get("icon", "") == "down")
	var up_view: Array = views.filter(func(v): return v.get("icon", "") == "up")
	check(down_view.size() == 1 and down_view[0].label == "Makelloser Rubin" and up_view.size() == 1 and up_view[0].label == "Großartiger Rubin",
		"Knöpfe: roter Pfeil + Makelloser Rubin, grüner Pfeil + Großartiger Rubin: %s" % [views])
	var amethyst_views: Array = game.choice_options(amethyst).map(func(o): return game._option_view(amethyst, o))
	check(amethyst_views.any(func(v): return v.get("icon", "") == "combine" and v.label == "Luftplatte"), "Kombinieren-Symbol + Luftplatte: %s" % [amethyst_views])
	check(UiTheme.icon("up") != null and UiTheme.icon("down") != null and UiTheme.icon("combine") != null, "Symbole für Pfeile und Kombinieren laden")
	game._select(amethyst)
	var opts: Array = game.choice_options(amethyst)
	var slate_index := opts.map(func(o): return o.label).find(opts.filter(func(o): return "Luftplatte" in o.label)[0].label)
	game._on_option_chosen(slate_index)
	check(amethyst.tower_id == "air_slate" and amethyst.is_trap(), "Luftplatte gesetzt")
	check(not game.pathfinder.astar.is_point_solid(amethyst.cell), "Falle blockiert den Weg nicht")
	var slate_cell: Vector2i = amethyst.cell
	check(game.traps.get(slate_cell) == amethyst and not game.towers.has(slate_cell) and not game.occupied.has(slate_cell), "Falle liegt auf eigener Ebene")
	# Trefferfläche 3×3 Felder (1,5 Towerbreiten) um die Mitte der Falle
	check(amethyst.in_range({"pos": amethyst.pos + Vector2(0.7, -0.7), "flying": false}) and not amethyst.in_range({"pos": amethyst.pos + Vector2(0.8, 0), "flying": false}), "Falle trifft auf 3×3 Feldern")
	# Zweimal verschieben, auch auf einen Checkpoint
	check(amethyst.moves_left == 2 and game.tower_options(amethyst).any(func(o): return o.action == "move"), "Falle hat 2 Verschiebungen")
	var on_cp: Vector2i = game.map.checkpoints[0] - Vector2i(1, 1)
	check(game.can_move_trap(amethyst, on_cp) and game.move_trap(amethyst, on_cp), "Falle auf Checkpoint verschoben")
	check(amethyst.cell == on_cp and amethyst.moves_left == 1 and game.traps.has(on_cp) and not game.traps.has(slate_cell), "Falle liegt jetzt am Checkpoint")
	check(game.move_trap(amethyst, slate_cell) and amethyst.moves_left == 0, "zweites Verschieben")
	check(not game.can_move_trap(amethyst, on_cp) and not game.tower_options(amethyst).any(func(o): return o.action == "move"), "kein drittes Verschieben")
	# Schwarzer Opal: Tauschen mit Stein und eigenem Gem (swap_cost)
	var sw_field: Array = game.towers.values().filter(func(o): return not o.is_new and o.owner_player == 0)
	if sw_field.size() >= 2 and not game.rocks.is_empty():
		var sw_opal: Tower = sw_field[0]
		var sw_other: Tower = sw_field[1]
		sw_opal.set_tower("black_opal", 0)
		game.gold = 1000
		var sw_from: Vector2i = sw_opal.cell
		var sw_rock: Vector2i = game.rocks.keys()[0]
		var sw_path_len: int = game.ground_path.size()
		check(game.tower_options(sw_opal).any(func(o): return o.action == "swap" and o.cost == 200), "Schwarzer Opal bietet Tauschen für 200 Gold")
		check(game.submit({"type": "swap", "tower": game.tower_ref(sw_opal), "with": sw_rock}), "Tauschen mit Stein")
		check(sw_opal.cell == sw_rock and game.towers.get(sw_rock) == sw_opal and game.rocks.has(sw_from) and not game.rocks.has(sw_rock) and game.gold == 800, "Opal steht am Stein, Stein am alten Platz, 200 Gold weg")
		check(game.ground_path.size() == sw_path_len, "Weg bleibt gleich lang")
		var sw_other_cell: Vector2i = sw_other.cell
		check(game.swap_tower(sw_opal, sw_other_cell) and sw_opal.cell == sw_other_cell and sw_other.cell == sw_rock and game.towers.get(sw_rock) == sw_other, "Tauschen mit eigenem Gem")
		game.gold = 100
		check(not game.can_swap(sw_opal, sw_rock), "Ohne 200 Gold kein Tauschen")
	else:
		check(false, "Für den Tausch-Test fehlen Tower oder Steine")
	# Steine auch während der Welle entfernen
	var wave_rock: Vector2i = game.rocks.keys()[0]
	check(game.remove_rock(wave_rock) and not game.ground_path.is_empty(), "Stein während der Welle entfernt")
	var dmg_before: float = amethyst.total_damage
	var frames2 := 0
	while game.phase == game.Phase.WAVE and frames2 < 20000:
		await get_tree().process_frame
		frames2 += 1
	print("  Luftplatte Schaden: ", int(amethyst.total_damage - dmg_before))

	# Tower auf eine Falle bauen; zweiter Klick wählt die Falle darunter
	check(game.can_place(slate_cell), "Tower auf Falle baubar")
	game.debug_tower = "topaz:4"
	var on_trap = game.place_gem(slate_cell)
	check(game.towers.get(slate_cell) == on_trap and game.traps.get(slate_cell) == amethyst, "Tower steht auf der Falle")
	game._select(on_trap)
	game._on_click(slate_cell, slate_cell)
	check(game.selected == amethyst, "zweiter Klick wählt die Falle unter dem Tower")

	# Stein von Bryvx: 4 gleiche perfekte Gems
	tries2 = 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = "topaz:4"
			game.place_gem(c)
	labels = game.choice_options(game.round_towers[0]).map(func(o): return o.label)
	check(labels.any(func(l): return "Bryvx" in l), "4 perfekte → Stein von Bryvx: %s" % [labels])

	# One-Shot: Silber schon in der Bauphase, sobald Topas, Diamant und Saphir stehen
	for t in game.towers.values().filter(func(o): return o.is_new):
		game._turn_into_rock(t)
	game.round_towers.clear()
	game.phase = game.Phase.BUILD
	# Fertiger Saphir, Topas und Diamant auf dem Feld: zählen für One-Shots nicht mit,
	# und kombinieren lassen sie sich erst außerhalb der Bauphase
	var field_plan := ["sapphire:0", "topaz:0", "diamond:0"]
	var field_gems := []
	tries2 = 0
	while field_gems.size() < field_plan.size() and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = field_plan[field_gems.size()]
			var g = game.place_gem(c)
			g.is_new = false
			game.round_towers.erase(g)
			field_gems.append(g)
	var field_sapphire = field_gems[0]
	var field_labels: Array = game.tower_options(field_sapphire).map(func(o): return o.label)
	check(not field_labels.any(func(l): return "Kombinieren" in l), "kein Kombinieren in der Bauphase: %s" % [field_labels])
	var shot_plan := ["topaz:0", "diamond:0", "sapphire:0"]
	tries2 = 0
	while game.round_towers.size() < shot_plan.size() and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			if game.round_towers.size() == 2:
				check(game.one_shot_hints().is_empty(), "One-Shot ignoriert Tower auf dem Feld: %s" % [game.one_shot_hints()])
			game.debug_tower = shot_plan[game.round_towers.size()]
			game.place_gem(c)
	check(game.phase == game.Phase.BUILD, "nach 3 Gems noch Bauphase")
	check(game.one_shot_hints().any(func(h): return "Silber" in h), "One-Shot-Hinweis: %s" % [game.one_shot_hints()])
	var topaz = game.round_towers[0]
	game._select(topaz)
	opts = game.choice_options(topaz)
	labels = opts.map(func(o): return o.label)
	check(labels == ["One-Shot → Silber"], "Bauphase bietet nur das Rezept an: %s" % [labels])
	game._refresh_hud()
	check(game.hud._options.size() == 2 and game.hud._options[0].style == "oneshot" and game.hud._options[1].label == "Zurücknehmen",
		"One-Shot-Button ist lila, daneben Zurücknehmen: %s" % [game.hud._options.map(func(o): return o.label)])
	check(game.hud.oneshot_pill.visible and "Silber" in game.hud.oneshot_label.text, "Banner zeigt One-Shot: " + game.hud.oneshot_label.text)
	check(game.hud._gems.all(func(g): return g.oneshot), "alle drei Zutaten lila markiert")
	game.hud.toggle_recipe_book()
	await get_tree().process_frame
	check(game.hud.recipe_book.visible and game.hud.recipe_book.grid.get_child_count() > 10, "Rezeptbuch zeigt %d Rezepte" % game.hud.recipe_book.grid.get_child_count())
	game.hud.toggle_recipe_book()
	var st := Recipes.status("silver", [["diamond", 0], ["sapphire", 0]])
	check(st.missing == 1 and st.lines[2].have == false, "Rezeptstatus Silber: Topas fehlt")
	st = Recipes.status("poison_slate", [["emerald", 2], ["opal", 1]])
	check(st.missing == 0, "Rezeptstatus Giftplatte mit 'einer von' erfüllt")
	check(Recipes.used_in("emerald", 2).has("jade") and Recipes.used_in("emerald", 2).has("poison_slate"), "Normaler Smaragd wird für Jade und Giftplatte gebraucht")
	game.hud.set_selection({"title": "Smaragd", "color": Color.GREEN, "body": "", "used_in": Recipes.used_in("emerald", 2)})
	# Fallen erscheinen nur, wenn sie gerade kombinierbar sind
	var used_n := Recipes.used_in("emerald", 2).filter(func(sid): return Database.towers[sid].get("kind", "tower") != "trap" \
			or Recipes.ready_now(sid, game.hud.owned, game.hud.owned_now)).size()
	check(game.hud.used_row.get_child_count() == 1 and game.hud.used_page_label.text == "1 / %d" % used_n, "Wird gebraucht für: ein Rezept pro Seite, Seite 1 / %d" % used_n)
	game.hud._turn_used_page(1)
	check(game.hud.used_page_label.text == "%d / %d" % [posmod(1, used_n) + 1, used_n], "Pfeil blättert weiter")
	game.hud._turn_used_page(-2)
	check(game.hud.used_page_label.text == "%d / %d" % [posmod(-1, used_n) + 1, used_n], "Pfeil zurück springt ans Ende")
	game.hud.set_owned([["emerald", 2, true]], {"pool": [["emerald", 2, true], ["ruby", 0, true]], "wave": false})
	check(not game.hud._used_ids.has("poison_slate"), "Giftplatte ohne zweite Zutat nicht unter \"Wird gebraucht für\": %s" % [game.hud._used_ids])
	game.hud.set_owned([["emerald", 2, true]], {"pool": [["emerald", 2, true], ["opal", 1, true]], "wave": false})
	check(game.hud._used_ids.has("poison_slate"), "Giftplatte erscheint, sobald sie in der Auswahl kombinierbar ist")
	game.hud.set_selection({})
	check(not game.hud.used_col.visible, "nach dem Abwählen kein \"Wird gebraucht für\" mehr")
	# Reihenfolge: meiste vorhandene Zutaten zuerst, bei Gleichstand Tower vor Fallen
	var sorted_ids: Array = Hud.sort_used_in(["air_slate", "silver"], [])
	check(sorted_ids == ["silver", "air_slate"], "Gleichstand: Tower vor Falle: %s" % [sorted_ids])
	sorted_ids = Hud.sort_used_in(["silver", "air_slate"], [["amethyst", 2, false]])
	check(sorted_ids[0] == "air_slate", "Rezept mit mehr vorhandenen Zutaten zuerst: %s" % [sorted_ids])
	st = Recipes.status("silver", [["diamond", 0, true], ["sapphire", 0], ["topaz", 0]])
	check(st.lines[0].new and not st.lines[1].new and st.missing == 0, "Neuer Gem der Runde violett, fixierter Tower grün")
	var jade_set := [["emerald", 2], ["opal", 2], ["sapphire", 1]]
	check(not Recipes.ready_now("jade", jade_set, {"pool": [], "wave": false}), "Jade mit Feld-Towern beim Setzen nicht baubar")
	check(Recipes.ready_now("jade", jade_set, {"pool": jade_set, "wave": true}), "Jade mit Feld-Towern in der Welle baubar")
	check(not Recipes.ready_now("poison_slate", [["emerald", 2], ["opal", 1]], {"pool": [["emerald", 2], ["opal", 1]], "wave": true}), "Giftplatte nur aus einer Runde, nicht in der Welle")
	Session.pinned_recipes = ["jade"]
	game._refresh_hud()
	game.hud._refresh_pinned()
	check(game.hud.pinned_panel.visible, "angepinntes Rezept wird angezeigt")
	Session.pinned_recipes = []
	var rocks_before: int = game.rocks.size()
	game._on_option_chosen(0)
	check(topaz.tower_id == "silver" and game.phase == game.Phase.WAVE, "One-Shot gebaut, Welle startet")
	check(game.rocks.size() == rocks_before + 2, "die anderen beiden Gems sind Steine")
	field_labels = game.tower_options(field_sapphire).map(func(o): return o.label)
	check(field_labels.has("Kombinieren → Silber"), "Kombinieren während der Welle: %s" % [field_labels])
	game._select(field_sapphire)
	game._on_option_chosen(field_labels.find("Kombinieren → Silber"))
	check(field_sapphire.tower_id == "silver" and game.phase == game.Phase.WAVE and not game.ground_path.is_empty(), "während der Welle kombiniert, Welle läuft weiter")
	labels = game.tower_options(topaz).map(func(o): return o.label)
	check(labels.any(func(l): return l.begins_with("Aufwerten → Sterlingsilber")), "Upgrade während der Welle: %s" % [labels])
	var up_views: Array = game.tower_options(topaz).filter(func(o): return o.action == "upgrade").map(func(o): return game._option_view(topaz, o))
	check(not up_views.is_empty() and up_views[0].label == "Sterlingsilber" and str(up_views[0].get("sub", "")).ends_with("Gold"), "Upgrade-Knopf: nur Name, darunter Goldkosten: %s" % [up_views])
	check(not (up_views[0].diff as Array).is_empty() and float(up_views[0].preview_range) > 0.0, "Upgrade-Knopf mit Werte-Vergleich und neuer Reichweite: %s" % [up_views[0].get("diff")])
	# Infofenster: Kacheln, Kills mit Rang, Herkunft der Boni, Upgrade-Vorschau
	var old_kills: int = topaz.kills
	var old_ep: float = topaz.ep
	topaz.kills = 23
	topaz.set_ep(23)
	var ki := TowerStats.level_info(topaz)
	check(ki.levels and ki.level == 2 and is_equal_approx(ki.need, 7.0) and is_equal_approx(ki.bonus, 0.2) and not ki.maxed, "Level bei 23 EP: %s" % [ki])
	topaz.damage_bonus = 0.1
	topaz.damage_source = "Kraftplatte"
	var tv := TowerStats.view(topaz)
	var tkeys: Array = tv.tiles.map(func(x): return x.key)
	check(tkeys == ["range", "speed", "damage", "type"], "Kacheln: %s" % [tkeys])
	var dtile: Dictionary = tv.tiles[2]
	check(dtile.mod and dtile.rows.any(func(r): return "Kraftplatte" in r[0]) and dtile.rows.any(func(r): return "Level 2" in r[0]), "Schaden grün, Tooltip nennt Kraftplatte und Level: %s" % [dtile.rows])
	game._select(topaz)
	game._refresh_hud()
	var hud = game.hud
	check(hud.info_kills.visible and "23" in hud.info_kills_label.text, "Kills neben dem Namen: " + hud.info_kills_label.text)
	check(hud._tiles[2].value.get_theme_color("font_color") == UiTheme.HAVE, "veränderter Schaden ist grün")
	var tips := [hud._kills_tooltip(), hud._stat_tooltip(2), hud._diff_tooltip(up_views[0])]
	check(tips.all(func(x): return x != null), "Tooltips für Kills, Schaden und Upgrade")
	var tip_text := func(n: Node) -> String:
		return " ".join(n.find_children("*", "Label", true, false).map(func(l): return l.text))
	check("noch 7" in tip_text.call(tips[0]), "Kill-Tooltip: noch 7 Kills bis Rang 3: " + tip_text.call(tips[0]))
	for x in tips:
		x.free()
	check(hud.abil_panel.visible, "Fähigkeiten-Fenster immer da (feste Größe)")
	hud.preview_range_requested.emit(float(up_views[0].preview_range))
	check(topaz._preview_ring != null, "Hover auf Upgrade zeigt die neue Reichweite")
	hud.preview_range_requested.emit(0.0)
	check(topaz._preview_ring == null, "Reichweiten-Vorschau wieder aus")
	topaz.kills = old_kills
	topaz.set_ep(old_ep)
	topaz.damage_bonus = 0.0
	topaz.damage_source = ""
	# Gegner-Fenster: Anteil der abgezogenen Wellen-Leben und Felder bis zum Ziel
	var ep: EnemyPanel = game.hud.enemy_panel
	game._process_wave(1.0)
	var ed: Dictionary = ep.data()
	check(not ed.is_empty() and float(ed.total) > 0.0 and int(ed.alive) + int(ed.queued) > 0, "Gegner-Fenster kennt die Welle: %s" % [ed])
	if not game.enemies.is_empty():
		var ge: Enemy = game.enemies[0]
		var before: float = float(ed.dealt)
		ge.hp -= ge.max_hp * 0.5
		check(is_equal_approx(float(ep.data().dealt) - before, ge.max_hp * 0.5), "Schaden am Gegner zählt zum Wellen-Anteil")
		ge.hp += ge.max_hp * 0.5
		var fr: Dictionary = ep.front()
		check(not fr.is_empty() and int(fr.fields) > 0 and float(fr.progress) >= 0.0 and float(fr.progress) < 1.0, "Vorderster Gegner: %s Felder" % [fr.get("fields")])
		var gone_before: float = float(game.wave_live.gone_hp)
		var total_before: float = float(ep.data().total)
		ge.hp = 0.0
		ge.dead = true
		game.on_enemy_killed(ge)
		check(int(game.wave_live.killed) >= 1 and is_equal_approx(float(ep.data().total), total_before), "Kill ändert die Wellen-Leben nicht, zählt aber als besiegt")
	# Tower-Liste: fertige Tower, Kamera fährt per Doppelklick hin
	var tl: TowerList = game.hud.tower_list
	tl.refresh()
	var listed: Array = tl.towers()
	check(not listed.is_empty() and listed.all(func(t): return not t.is_new) and tl.rows.size() == listed.size(), "Tower-Liste zeigt %d Tower" % listed.size())
	tl.sort = "kills"
	listed[0].kills += 1000
	tl.refresh()
	check(tl.towers()[0] == listed[0] and tl.rows[listed[0].get_instance_id()].button.get_index() == 0, "Tower-Liste sortiert nach Kills")
	listed[0].kills -= 1000
	tl.sort = "damage"
	var rig: CameraRig = game.camera_rig
	rig.target = Vector3(rig.bounds.get_center().x, 0, rig.bounds.get_center().y)
	rig._apply()
	tl.focus(listed[0])
	var tower_at := Vector2(listed[0].position.x, listed[0].position.z)
	# am Kartenrand hält die Begrenzung die Kamera etwas vor dem Tower an, er bleibt aber im Bild
	check(Vector2(rig.target.x, rig.target.z).distance_to(tower_at) < 0.5 or rig.view_rect().grow(-1.0).has_point(tower_at),
			"Doppelklick fährt die Kamera zum Tower")
	# Kamera bleibt auf der Karte: ganz herausgezoomt in die Ecke geschoben zeigt sie höchstens den Rand
	rig.distance = CameraRig.MAX_DISTANCE
	rig.target = Vector3(-50, 0, -50)
	rig._apply()
	var room := rig.bounds.grow(CameraRig.VIEW_MARGIN + 0.01)
	var view := rig.view_rect()
	check(room.encloses(view) and view.size.x > 1.0, "Kamera zeigt höchstens %.0f Einheiten neben der Karte (Bild %s)" % [CameraRig.VIEW_MARGIN, view])
	# Kombinierbare Tower sind hellblau unterstrichen: dafür kurz die Tower zu Zutaten eines Rezepts machen
	var combo_def := {}
	for sid in Database.special_ids():
		var cdef: Dictionary = Database.towers[sid]
		var rec: Array = cdef.get("recipe", [])
		if not cdef.get("recipe_same_round", false) and not rec.is_empty() and rec.size() <= listed.size() and rec.all(func(i): return i.has("tower")):
			combo_def = {"id": sid, "recipe": rec}
			break
	if not combo_def.is_empty():
		var saved := listed.map(func(t): return [t.tower_id, t.tier])
		for t in listed:
			t.tier = 99  # passt zu keinem Rezept
		for i in combo_def.recipe.size():
			listed[i].tower_id = str(combo_def.recipe[i].tower)
			listed[i].tier = int(combo_def.recipe[i].get("tier", 0))
		tl.refresh()
		var crow: Dictionary = tl.rows[listed[0].get_instance_id()]
		var cname := Database.tower_label(combo_def.id, 0)
		check(crow.combinable and crow.name.get_meta("combinable", false) and cname in tl.combos(listed[0]), "Tower-Liste: kombinierbarer Tower ist blau unterstrichen (%s)" % cname)
		check(game.tower_options(listed[0]).any(func(o): return o.action == "combine" and o.id == combo_def.id), "Markierung passt zu den Kombinieren-Optionen")
		listed[0].tower_id = "__none__"
		tl.refresh()
		check(not crow.combinable and not tl.rows[listed[1].get_instance_id()].combinable, "ohne passende Zutat nicht unterstrichen")
		for i in listed.size():
			listed[i].tower_id = saved[i][0]
			listed[i].tier = saved[i][1]
		tl.refresh()
	else:
		check(false, "kein Rezept für den Tower-Listen-Test gefunden (%d Tower)" % listed.size())

	# Sternrubin aus Fehlerhaftem Rubin (frühere Runde) + Splitter Amethyst + Splitter Rubin (neu):
	# alte Tower zählen weder als One-Shot noch in der Auswahlphase, nur während der Welle
	game.round_towers.clear()
	game.phase = game.Phase.BUILD
	var star_plan := ["ruby:1", "amethyst:0", "ruby:0", "topaz:0", "topaz:0", "topaz:0"]
	var star := []
	var star_name := Database.tower_label("star_ruby", 0)
	tries2 = 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = star_plan[star.size()]
			var g = game.place_gem(c)
			if star.is_empty():
				g.is_new = false
				game.round_towers.erase(g)
			star.append(g)
			if star.size() == 3:
				check(not game.one_shot_hints().any(func(h): return star_name in h), "kein One-Shot %s mit altem Rubin: %s" % [star_name, game.one_shot_hints()])
	labels = game.choice_options(star[1]).map(func(o): return o.label)
	check(game.phase == game.Phase.CHOOSE and not labels.any(func(l): return star_name in l), "Auswahlphase: kein %s mit altem Rubin: %s" % [star_name, labels])
	labels = game.tower_options(star[0]).map(func(o): return o.label)
	check(not labels.any(func(l): return "Kombinieren" in l), "alter Rubin kombiniert in der Auswahlphase nicht: %s" % [labels])
	labels = game.tower_options(topaz).map(func(o): return o.label)
	check(labels.is_empty(), "kein Upgrade außerhalb der Welle: %s" % [labels])

	# Wellenvorschau links
	var preview: Array = game._upcoming_waves(4)
	check(preview.size() == 4 and preview[0].number == game.wave_index + 1, "Vorschau zeigt die nächsten 4 Wellen ab Welle %d" % (game.wave_index + 1))
	# Massenwelle 10: 25 Gegner in Trupps zu 5, dicht im Trupp, Wellendauer wie einzeln
	var mg: Dictionary = game.waves[9].groups[0]
	var mq: Array = game.group_queue(mg)
	var mt := 0.0
	for q in mq:
		mt += float(q.interval)
	check(mq.size() == 25 and int(mg.get("pack", 0)) == 5 and float(mq[0].interval) < 0.3 and float(mq[4].interval) > 2.0
		and absf(mt - 25 * float(mg.interval)) < 0.01, "Massenwelle in Trupps zu 5, gleiche Dauer (%.2f s)" % mt)
	check(game.group_queue(game.waves[0].groups[0]).all(func(q): return q.interval == game.waves[0].groups[0].interval), "normale Welle einzeln")
	check(game.wave_type(game.waves[3]) == "Flieger" and game.wave_type(game.waves[0]) == "Boden" and game.wave_type(game.waves[49]) == "Boss", "Wellentypen: Boden, Flieger, Boss")
	check(game.hud.waves_panel.visible, "Wellenvorschau sichtbar")

	# Debug-Menü
	var g0: int = game.gold
	game.hud.debug_gold_requested.emit(100)
	check(game.gold == g0 + 100, "Debug: Gold +100")
	var l0: int = game.lives
	game.hud.debug_lives_requested.emit(10)
	check(game.lives == l0 + 10, "Debug: Leben +10")
	game.hud.debug_gems.value = 3
	check(game.gems_per_round() == 3, "Debug: Gems pro Runde einstellbar")
	game.hud.debug_gems.value = 5
	Session.debug_gems_per_round = 0
	var sep_ok := false
	for i in game.hud.debug_option.item_count:
		if game.hud.debug_option.is_item_separator(i) and game.hud.debug_option.get_item_text(i) == "Spezial-Tower":
			sep_ok = game.hud.debug_keys[i] == "" and game.hud.debug_keys[i + 1].begins_with(Database.special_ids()[0])
	check(sep_ok, "Debug: Gem-Liste mit Trennern Basis-Gems / Spezial-Tower")
	game.lives = l0
	game.gold = g0
	var w0: int = game.wave_index
	if game.phase != game.Phase.WAVE:
		game.debug_jump_to_wave(3)
		check(game.wave_index == 2 and game._upcoming_waves(1)[0].number == 3, "Debug: Welle 3 kommt als nächste")
		game.wave_index = w0
		game._refresh_hud()

	# Chance-Tooltip und Qualitätskästchen
	var chance_tip: String = Hud.chance_lines(1)
	check("Splitter" in chance_tip and "70 %" in chance_tip and "30 %" in chance_tip, "Chance-Tooltip zeigt Prozente pro Qualität: %s" % chance_tip)
	check("Splitter" in game.hud.chance_value.get_parent().get_parent().tooltip_text, "Tooltip hängt am Chance-Feld")
	var chance_host: TooltipHost = game.hud.chance_value.get_parent().get_parent()
	var chance_tt = chance_host._make_custom_tooltip("")
	check(chance_tt is Control and chance_tt.get_child_count() >= 5, "Chance-Tooltip mit Titel, Balken und nächster Stufe")
	if chance_tt != null:
		chance_tt.free()
	var badge := QualityBadge.new(Color.RED, 2, 6)
	check(badge.tier == 2 and badge.tiers == 5 and not badge.is_perfect() and badge.custom_minimum_size.y > badge.custom_minimum_size.x,
		"Facetten-Gem: 5 Stufen (Splitter bis Perfekt), Normal füllt 3 Facetten")
	badge.free()
	badge = QualityBadge.new(Color.RED, 4, 6)
	check(badge.is_perfect(), "Facetten-Gem: Perfekt füllt die Mitte")
	badge.free()
	badge = QualityBadge.new(Color.RED, 5, 6)
	check(badge.tier == 4 and badge.is_perfect(), "Facetten-Gem: Großartig zählt wie Perfekt")
	badge.free()
	badge = QualityBadge.new(Color("f1c40f"), 1, 6, 36.0, "topaz")
	check(badge.color == Color("ffe600"), "Facetten-Gem: Topas in grellerem Gelb")
	badge.free()

	# DPS-Meter rechts: Top 5 je Welle, letzte Welle je Typ, Gesamt
	var meter: DpsMeter = game.hud.dps_meter
	var dps_towers: Array = game.all_towers()
	check(meter != null and meter.select.item_count == 6, "DPS-Meter mit 6 Ansichten im Dropdown")
	check(meter._total_time > 0.0 and not meter._total.is_empty(), "DPS-Meter hat die bisherigen Wellen mitgezählt")
	if not dps_towers.is_empty():
		meter._last.clear()
		meter._total.clear()
		meter._total_time = 0.0
		meter._begin_wave()
		meter._running = true
		meter._wave_time = 10.0
		dps_towers[0].total_damage += 500.0
		meter.view = "now"
		var dps_top: Array = meter.top()
		check(dps_top.size() == 1 and is_equal_approx(dps_top[0][2], 50.0), "DPS-Meter: 500 Schaden in 10 s ergibt 50 DPS")
		var dps_type: String = meter._wave_type
		meter._end_wave()
		meter.view = dps_type
		check(meter._last.has(dps_type) and is_equal_approx(meter.top()[0][2], 50.0), "DPS-Meter merkt sich die letzte %s-Welle" % dps_type)
		meter.view = "total"
		meter.refresh()
		check(is_equal_approx(meter.top()[0][2], 50.0) and meter.rows[0].box.visible and not meter.rows[1].box.visible, "DPS-Meter: Gesamt zeigt den Tower")
		meter.view = "Boss" if dps_type != "Boss" else "Masse"
		check(meter.top().is_empty(), "DPS-Meter: Welle ohne Daten ist leer")
		dps_towers[0].total_damage -= 500.0
		meter._last.clear()
		meter._total.clear()
		meter._total_time = 0.0
		meter.view = "now"
		meter.refresh()

	# Menü-Knopf fragt erst nach und pausiert solange
	game.hud.open_leave_confirm()
	check(game.hud.leave_confirm.visible and get_tree().paused, "Menü-Knopf zeigt Rückfrage und pausiert")
	game.hud.close_leave_confirm()
	check(not game.hud.leave_confirm.visible and not get_tree().paused, "Weiterspielen schließt Rückfrage")
	# Esc: erst Auswahl aufheben, dann Menü; im Menü Einstellungen, Esc schließt erst diese, dann das Menü
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game._select(null, Vector2i(1, 1))
	game._unhandled_input(esc)
	check(game.selected == null and game.selected_rocks.is_empty() and not game.hud.leave_confirm.visible, "Esc hebt erst die Auswahl auf")
	game._unhandled_input(esc)
	check(game.hud.leave_confirm.visible and get_tree().paused, "Esc ohne Auswahl öffnet das Menü")
	game.hud.settings_panel.open()
	game.hud._unhandled_input(esc)
	check(game.hud.leave_confirm.visible and not game.hud.settings_panel.visible, "Esc schließt erst die Einstellungen")
	game.hud._unhandled_input(esc)
	check(not game.hud.leave_confirm.visible and not get_tree().paused, "Esc schließt das Menü")

	# Chance-Stufe steigt automatisch mit der Welle, Gold wird um gold_income_factor gekürzt
	check(game.chance_level_for(1) == 0 and game.chance_level_for(3) == 1 and game.chance_level_for(27) == 8 and game.chance_level_for(50) == 8,
		"Chance automatisch: Welle 1 → 0, Welle 3 → 1, ab Welle 27 → 8")
	var old_gold: int = game.gold
	game.gold = 0
	game._gold_frac = 0.0
	for k in 4:
		game.earn_gold(1)
	var g_start := float(Database.balance.gold_income_factor)
	check(game.gold == floori(4 * g_start), "Goldeinkommen ×%s: 4 × 1 Gold ergibt %d Gold" % [g_start, game.gold])
	var ramp: Dictionary = Database.balance.gold_income_ramp
	var g_from := int(ramp.from_wave)
	var g_to := int(ramp.to_wave)
	var g_top := float(ramp.to_factor)
	var g_mid: float = game.gold_income_factor((g_from + g_to) / 2)
	check(is_equal_approx(game.gold_income_factor(g_from), g_start) and is_equal_approx(game.gold_income_factor(g_to), g_top)
		and is_equal_approx(game.gold_income_factor(g_to + 10), g_top) and g_mid > g_start and g_mid < g_top,
		"Goldeinkommen steigt von Welle %d bis %d linear von %s auf %s" % [g_from, g_to, g_start, g_top])
	game.gold = old_gold
	game._refresh_hud()

	# Weglänge in der Leiste und Menü am Spielende
	check(game.path_length > 0 and str(game.path_length) in game.hud.path_value.text, "Weglänge angezeigt: " + game.hud.path_value.text)
	# Debug „Unsterblich“: Leben gehen ins Minus, kein Spielende
	Session.debug_immortal = true
	game.lives = 1
	var leaker := Enemy.new()
	leaker.damage = 3
	game.on_enemy_leaked(leaker)
	check(game.lives == -2 and game.phase < game.Phase.GAME_OVER, "Unsterblich: Leben %d, Spiel läuft weiter" % game.lives)
	Session.debug_immortal = false
	var tough := Enemy.new()
	tough.max_hp = 100.0
	tough.armor = 4.0
	var expect := [80.0, 90.0, 115.0]
	for d in 3:
		tough.max_hp = 100.0
		tough.armor = 4.0
		Session.difficulty = d
		tough.apply_difficulty(Session.difficulty_factor())
		check(is_equal_approx(tough.max_hp, expect[d]) and is_equal_approx(tough.armor, 4.0 * expect[d] / 100.0) and tough.hp == tough.max_hp,
			"%s: Leben %.0f, Rüstung %.2f" % [Session.difficulty_name(), tough.max_hp, tough.armor])
	tough.free()
	Session.difficulty = 1
	game._finish(game.Phase.GAME_OVER)
	check(game.hud.game_over.visible and game.hud.game_over_title.text == "Verloren", "Menü am Spielende erscheint")
	var runs := RunHistory.load_runs()
	check(runs.size() == 1 and not runs[0].victory and runs[0].map == game.map.name and (runs[0].leaks as Array).size() == game.waves.size() and runs[0].has("summary"),
			"Run-History: verlorenes Spiel gespeichert: %s" % [runs[0].keys() if not runs.is_empty() else []])
	var pr: Array = Profile.runs("gemtd")
	check(not pr.is_empty() and Profile.load_run(str(pr[0].id)).has("types") and Profile.load_run(str(pr[0].id)).has("wave_log"),
		"Profil: Run mit Tower- und Wellenwerten gespeichert")
	var rh := RunHistoryPanel.new()
	add_child(rh)
	await get_tree().process_frame
	check(rh.list.get_child_count() == 1 and rh.detail.get_child_count() > 5, "Run-History im Menü zeigt den Lauf mit Details")
	rh.filter = "score"
	rh._rebuild()
	check(rh.list.get_child_count() == 0 and rh.empty.visible, "Filter Punkte: kein Punkte-Lauf")
	rh.queue_free()

	await _save_test()
	await _score_test()
	await _rock_select_test()
	await _take_back_test()
	await _extra_chance_test()
	await _final_boss_test()
	await _command_test()
	await _coop_test()
	await _coop_sync_test()
	await _setup_test()
	await _maul_test()
	await _idle_speed_test()
	await _fx_test()

	# Alle Tower-Dateien gültig
	for id in Database.tower_ids():
		var def: Dictionary = Database.towers[id]
		check(not (def.get("tiers", []) as Array).is_empty(), "Tower %s hat Stufen" % id)
		for ing in def.get("recipe", []):
			var alts: Array = ing.get("any_of", [ing])
			for a in alts:
				check(Database.towers.has(str(a.get("tower", ""))), "Rezept von %s: Zutat %s existiert" % [id, a.get("tower", "")])
	for w in Database.wave_sets.get("classic", {}).get("waves", []):
		for g in w.groups:
			check(Database.enemies.has(g.enemy), "Gegner %s existiert" % g.enemy)

	Engine.time_scale = 1.0
	print("FERTIG, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


## Spielstände: Zustand mitten in einer Welle sichern, in ein neues Spiel laden, gleich weiter;
## Datei ist verschlüsselt und eine geänderte Datei lädt nicht mehr.
func _save_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tries := 0
	while g.phase == g.Phase.BUILD and tries < 5000:
		tries += 1
		var p: Vector2 = g.ground_path[rng.randi_range(0, g.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if g.can_place(c):
			g.place_gem(c)
	# Gegner dieser Welle unsterblich machen, damit der Stand nicht davon abhängt, wie schnell der Tower tötet
	g.waves = g.waves.duplicate(true)
	for grp in g.waves[g.wave_index].groups:
		grp.hp = 1.0e7
	g._select(g.round_towers[0])
	g._on_option_chosen(0)
	Engine.time_scale = 1.0
	var frames := 0
	# mitten in der Welle: Gegner unterwegs und noch welche in der Warteschlange
	# (ohne Mindestzahl an Bildern: bei niedriger Bildrate wäre die Warteschlange sonst schon leer)
	while g.phase == g.Phase.WAVE and (g.enemies.size() < 2 or g.spawn_queue.is_empty()) and frames < 5000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	var a: Dictionary = SaveGame.capture(g)
	check(a.phase == g.Phase.WAVE and not a.enemies.is_empty(), "Spielstand mitten in der Welle: %d Gegner, %d Tower, %d Steine" % [a.enemies.size(), a.towers.size(), a.rocks.size()])

	Session.load_state = a.duplicate(true)
	var g2: Node = load(Session.GAME).instantiate()
	add_child(g2)
	var b: Dictionary = SaveGame.capture(g2)
	var same := true
	for k in ["phase", "wave_index", "lives", "gold", "rocks", "towers", "round", "killed", "spawn_queue", "next_enemy_id", "rng_state", "difficulty"]:
		if str(a[k]) != str(b[k]):
			same = false
			print("  Unterschied bei ", k, ": ", a[k], " / ", b[k])
	check(same and is_equal_approx(a.spawn_timer, b.spawn_timer), "Geladenes Spiel hat denselben Stand")
	var close: bool = a.enemies.size() == b.enemies.size()
	for i in mini(a.enemies.size(), b.enemies.size()):
		var ea: Dictionary = a.enemies[i]
		var eb: Dictionary = b.enemies[i]
		close = close and absf(ea.traveled - eb.traveled) < 0.01 and is_equal_approx(ea.hp, eb.hp) \
			and ea.id == eb.id and is_equal_approx(ea.slow_time, eb.slow_time)
	check(close, "Gegner stehen nach dem Laden an derselben Stelle mit denselben Leben")
	check(g2.ground_path == g.ground_path and g2.map.name == g.map.name, "Weg und Map nach dem Laden gleich")

	# Datei: verschlüsselt, Änderung wird erkannt
	var data := {"id": "smoke_test_save", "kind": "single", "meta": SaveGame.meta_for(g), "state": a}
	check(SaveGame.write(data), "Spielstand geschrieben")
	var path := SaveGame.path_for("smoke_test_save")
	var raw := FileAccess.get_file_as_bytes(path)
	var text := raw.get_string_from_ascii()
	check(raw.size() > 100 and not ("towers" in text) and not (g.map.name in text) and not ("gold" in text), "Datei ist nicht im Klartext lesbar (%d Bytes)" % raw.size())
	var back := SaveGame.read(path)
	check(str(back.get("state", {})) == str(a), "Datei lädt verlustfrei")
	check(SaveGame.list().any(func(e): return e.id == "smoke_test_save" and e.meta.map == g.map.name), "Spielstand erscheint in der Liste")
	raw[raw.size() / 2] = raw[raw.size() / 2] ^ 0x55
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(raw)
	f.close()
	check(SaveGame.read(path).is_empty(), "Veränderte Datei wird abgelehnt")
	SaveGame.remove("smoke_test_save")
	check(not FileAccess.file_exists(path), "Spielstand gelöscht")

	# Rückfrage beim Verlassen bietet im Einzelspiel Speichern an
	g2.hud.open_leave_confirm()
	check(g2.save_mode() == "single" and g2.hud._save_leave.visible and not g2.hud._save_leave.disabled, "Verlassen fragt nach Speichern")
	g2.hud.close_leave_confirm()
	Session.save_id = ""
	g.queue_free()
	g2.queue_free()
	await get_tree().process_frame


## Punkte-Modus: späte Wellen zählen mehr, ein Durchbruch kostet die Hälfte, kein Leben geht verloren.
func _score_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	Session.score_mode = true
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	check(g.score_mode and g.hud.lives_value.get_parent().get_child(0).text == "Punkte", "Punkte-Modus: Leiste zeigt Punkte")
	var w1: Dictionary = g.waves[0]
	var sum := 0.0
	for grp in w1.groups:
		sum += g.score_for(grp) * int(grp.get("count", 1))
	check(is_equal_approx(sum, g.wave_points(1)), "Welle 1 ist insgesamt %.0f Punkte wert" % sum)
	var v1: float = g.score_for(w1.groups[0])
	g.wave_index = 39
	var v40: float = g.score_for(g.waves[39].groups[0])
	var full_leak_1 := 0.0
	for grp in w1.groups:
		full_leak_1 += g.leak_penalty(v1) * int(grp.get("count", 1))
	check(v40 > v1 * 3.0, "Gegner aus Welle 40 zählt mehr als aus Welle 1 (%.1f gegen %.1f)" % [v40, v1])
	check(g.leak_penalty(v40) < full_leak_1, "Durchbruch eines Gegners aus Welle 40 (−%.1f) kostet weniger als eine ganze frühe Welle (−%.1f)" % [g.leak_penalty(v40), full_leak_1])
	var e := Enemy.new()
	e.score_value = v40
	g.enemies.append(e)
	var lives_before: int = g.lives
	g.on_enemy_killed(e)
	check(is_equal_approx(g.score, v40), "Kill gibt %.1f Punkte" % v40)
	var e2 := Enemy.new()
	e2.score_value = v40
	e2.damage = 5
	g.enemies.append(e2)
	g.on_enemy_leaked(e2)
	check(is_equal_approx(g.score, v40 * 0.5) and g.lives == lives_before and g.phase < g.Phase.GAME_OVER, "Durchbruch kostet die Hälfte, keine Leben")
	var st := SaveGame.capture(g)
	check(st.score_mode and is_equal_approx(st.score, g.score), "Spielstand enthält Punkte")
	g._finish(g.Phase.VICTORY)
	check("Punkte: %d" % roundi(g.score) in g.hud.game_over_stats.text, "Endbildschirm zeigt die Punkte")
	var last: Dictionary = RunHistory.load_runs()[0]
	check(last.score_mode and last.victory and int(last.score) == roundi(g.score), "Run-History: Punkte-Lauf mit %d Punkten" % int(last.score))
	RunHistory.delete(0)
	check(RunHistory.load_runs().is_empty() or not RunHistory.load_runs()[0].score_mode, "Lauf löschen")
	Session.score_mode = false
	g.queue_free()
	await get_tree().process_frame


## Steine: per Rahmen bis zu 5 auswählen, direkt durch Gems ersetzen (nur so viele, wie die Runde noch hat), Rest entfernen.
func _rock_select_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	g.gold = 10000
	var gem_cells := [Vector2i(14, 40), Vector2i(18, 40), Vector2i(22, 40)]
	for c in gem_cells:
		g.place_gem(c)
	var rock_cells := []
	for i in 3:
		for j in 2:
			var c := Vector2i(14 + 4 * i, 32 + 4 * j)
			if g.can_place(c):
				g.rocks[c] = true
				g._occupy(c, true, true)
				rock_cells.append(c)
	g._update_paths()
	g.board.refresh_rocks()
	check(rock_cells.size() == 6 and g.gems_left() == 2, "6 Steine liegen, noch %d Gems in der Runde" % g.gems_left())
	var cam: Camera3D = g.camera_rig.camera
	var r := Rect2()
	for i in rock_cells.size():
		var p := cam.unproject_position(Board3D.to_3d(Board3D.footprint_center(rock_cells[i])))
		r = Rect2(p, Vector2.ZERO) if i == 0 else r.expand(p)
	g._press_pos = cam.unproject_position(Board3D.to_3d(Board3D.footprint_center(rock_cells[0])))
	g._box_select(r.grow(4.0))
	check(g.selected_rocks.size() == 5 and g.selected_rocks[0] == rock_cells[0] and g.board.selected_rocks.size() == 5,
		"Auswahlrahmen markiert höchstens 5 Steine (%d)" % g.selected_rocks.size())
	var picked: Array = g.selected_rocks.duplicate()
	g._on_option_chosen(0)
	var replaced := picked.slice(0, 2)
	check(g.round_towers.size() == 5 and g.phase == g.Phase.CHOOSE and replaced.all(func(c): return g.towers.has(c) and not g.rocks.has(c)),
		"Ersetzen setzt nur die 2 übrigen Gems, dann Auswahlphase")
	check(g.rocks.size() == 4, "die anderen Steine bleiben liegen (%d)" % g.rocks.size())
	var gold_before: int = g.gold
	g._select_rocks(g.rocks.keys())
	g._on_option_chosen(0)
	check(g.rocks.is_empty() and g.gold == gold_before - 4 * g.rock_remove_cost(), "ohne freie Gems entfernt die Auswahl alle 4 Steine")
	g.queue_free()
	await get_tree().process_frame


## Strg+Klick: Steine einzeln zur Auswahl hinzufügen/abwählen. Gesetzte Gems zurücknehmen, ohne neu zu würfeln.
## Extra Chance: Gem-Sorte kaufen, Gems der Runde werden mit chance zum Perfekten dieser Sorte, einmal pro Runde.
func _extra_chance_test() -> void:
	Session.game_kind = "gemtd"
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	var cfg: Dictionary = Database.balance.get("extra_chance", {})
	check(int(cfg.get("cost", 0)) == 175, "Extra Chance kostet 175 Gold")
	var saved: Dictionary = cfg.duplicate()
	cfg["chance"] = 1.0
	g.gold = 0
	check(not g.can_buy_extra_chance(), "Ohne Gold keine Extra Chance")
	g.gold = 500
	check(g.submit({"type": "extra_chance", "id": "ruby"}) and g.gold == 325 and g.pl().extra_chance == "ruby", "Extra Chance Rubin gekauft")
	check(not g.submit({"type": "extra_chance", "id": "topaz"}), "Nur einmal pro Runde")
	var t: Tower = null
	for y in range(10, 60, 4):
		if g.can_place(Vector2i(14, y)):
			t = g.place_gem(Vector2i(14, y))
			break
	check(t != null and t.tower_id == "ruby" and t.tier == 4, "Gem wird zum Perfekten Rubin: %s" % (t.label() if t != null else "keiner"))
	g._enter_build()
	check(g.pl().extra_chance == "", "Neue Runde: Extra Chance wieder frei")
	Database.balance["extra_chance"] = saved
	g.queue_free()
	await get_tree().process_frame


func _take_back_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	g.gold = 10000
	var rock_cells := []
	for i in 7:
		var c := Vector2i(14 + 4 * (i % 4), 32 + 4 * (i / 4))
		if g.can_place(c):
			g.rocks[c] = true
			g._occupy(c, true, true)
			rock_cells.append(c)
	g._update_paths()
	g.board.refresh_rocks()
	for i in 6:
		g.toggle_rock(rock_cells[i])
	check(g.selected_rocks.size() == 5 and not g.selected_rocks.has(rock_cells[5]), "Strg+Klick wählt Steine dazu, höchstens 5")
	g.toggle_rock(rock_cells[1])
	check(g.selected_rocks.size() == 4 and not g.selected_rocks.has(rock_cells[1]), "Strg+Klick auf markierten Stein wählt ihn ab")
	g._select(null)

	# Ersetzen und wieder zurücknehmen: Stein kommt zurück, Kosten werden erstattet
	var cost_before = Database.balance.get("rock_remove_cost", 0)
	Database.balance["rock_remove_cost"] = 7
	var gold0: int = g.gold
	g.replace_rocks([rock_cells[0]])
	var on_rock: Tower = g.towers.get(rock_cells[0])
	check(on_rock != null and g.gold == gold0 - 7, "Stein durch Gem ersetzt")
	var rock_gem := "%s:%d" % [on_rock.tower_id, on_rock.tier]
	check(g.take_back(on_rock) and g.rocks.has(rock_cells[0]) and g.gold == gold0 and g.round_towers.is_empty(),
		"Zurücknehmen legt den Stein wieder hin und erstattet die Kosten")
	Database.balance["rock_remove_cost"] = cost_before

	# 5 Gems setzen, Auswahlphase, einen zurücknehmen → Bauphase, nächster Gem ist derselbe
	var cells := [Vector2i(14, 40), Vector2i(18, 40), Vector2i(22, 40), Vector2i(26, 40), Vector2i(30, 40)]
	var first: Tower = g.place_gem(Vector2i(34, 40))   # der zurückgenommene Gem von oben kommt wieder
	check(first != null and _gem_key(first) == rock_gem, "zurückgenommener Gem wird beim nächsten Setzen wiederverwendet")
	for c in cells.slice(0, 4):
		g.place_gem(c)
	check(g.phase == g.Phase.CHOOSE, "5 Gems gesetzt, Auswahlphase")
	var gems: Array = g.round_towers.map(_gem_key)
	var rng_state: int = g.rng.state
	var mid: Tower = g.round_towers[2]
	var mid_gem := _gem_key(mid)
	var mid_cell := mid.cell
	var opts: Array = g.tower_options(mid)
	check(opts.any(func(o): return o.action == "take_back"), "Auswahlphase bietet Zurücknehmen")
	g._select(mid)
	g._on_option_chosen(opts.find(opts.filter(func(o): return o.action == "take_back")[0]))
	check(g.phase == g.Phase.BUILD and g.round_towers.size() == 4 and not g.towers.has(mid_cell), "Zurücknehmen in der Auswahlphase führt zurück in die Bauphase")
	# Spielstand mitten drin: auch nach dem Laden kommt derselbe Gem wieder
	var st := SaveGame.capture(g)
	var h: Node = load(Session.GAME).instantiate()
	add_child(h)
	await get_tree().process_frame
	SaveGame.apply(h, st)
	var again: Tower = h.place_gem(cells[4])
	check(again != null and _gem_key(again) == mid_gem and h.phase == h.Phase.CHOOSE, "nach Laden: derselbe Gem, nicht neu gewürfelt")
	h.queue_free()
	var re: Tower = g.place_gem(cells[4])
	check(_gem_key(re) == mid_gem and g.rng.state == rng_state, "Neusetzen würfelt nicht neu (gleicher Gem, Zufall unverändert)")
	# Alle zurücknehmen und neu setzen: genau dieselben Gems
	while not g.round_towers.is_empty():
		g.take_back(g.round_towers[-1])
	for c in cells:
		g.place_gem(c)
	var a1 := gems.duplicate()
	a1.sort()
	var a2: Array = g.round_towers.map(_gem_key)
	a2.sort()
	check(a1 == a2 and g.rng.state == rng_state, "alle zurücknehmen und neu setzen ergibt dieselben 5 Gems")
	# Nach dem Behalten (Welle) lässt sich nichts mehr zurücknehmen
	var kept: Tower = g.round_towers[0]
	g._select(kept)
	g._on_option_chosen(0)
	check(g.phase == g.Phase.WAVE and not g.can_take_back(kept) and g.round_towers.is_empty(), "nach Behalten kein Zurücknehmen mehr")
	check(not g.tower_options(kept).any(func(o): return o.action == "take_back"), "fertige Tower bieten kein Zurücknehmen")
	g.queue_free()
	await get_tree().process_frame


func _gem_key(t: Tower) -> String:
	return "%s:%d" % [t.tower_id, t.tier]


## Endboss der letzten Welle: Schadenscheck ohne Lebensverlust, im Punkte-Modus Punkte nach Schaden; Aufschlüsselung.
func _final_boss_test() -> void:
	for mode in [false, true]:
		Session.map_path = Database.first_map().path
		Session.map_override = null
		Session.score_mode = mode
		var g: Node = load(Session.GAME).instantiate()
		add_child(g)
		await get_tree().process_frame
		# ein normaler Kill in Welle 1 zählt beim Wellentyp
		g.phase = g.Phase.WAVE
		g._spawn_enemy(g.waves[0].groups[0])
		var first: Enemy = g.enemies[-1]
		g.on_enemy_killed(first)
		var t1: String = g.wave_type(g.waves[0])
		check(int(g.score_stats.get(t1, {}).get("kills", 0)) == 1, "Kill zählt beim Wellentyp %s" % t1)
		g.wave_index = g.waves.size() - 1
		check(g.is_final_boss_wave(), "letzte Welle ist der Endboss")
		g._spawn_enemy(g.waves[-1].groups[0])
		var boss: Enemy = g.enemies[-1]
		check(boss.final_boss, "Endboss markiert")
		boss.hp = boss.max_hp * 0.4
		g.lives = 1
		var score_before: float = g.score
		var st := SaveGame.capture(g)
		g.on_enemy_leaked(boss)
		check(g.lives == 1 and g.phase == g.Phase.WAVE, "%s: Endboss läuft durch, kostet keine Leben" % ("Punkte" if mode else "Leben"))
		check(is_equal_approx(g.final_boss.damage, boss.max_hp * 0.6), "Schaden am Endboss gezählt (60 %)")
		if mode:
			var expect: float = g.wave_points(g.waves.size()) * float(Database.balance.score.get("final_boss_factor", 3.0)) * 0.6
			check(is_equal_approx(g.score - score_before, expect), "Endboss bringt Punkte nach Schaden (%.0f)" % (g.score - score_before))
		else:
			check(g.score == score_before, "Leben-Modus: keine Punkte")
		g._process_wave(0.0)
		check(g.phase == g.Phase.VICTORY, "nach dem Endboss ist das Spiel gewonnen")
		check(g.hud.game_over_boss.visible and "60.0" in g.hud.game_over_boss.text, "Endbildschirm zeigt den Schaden am Endboss: %s" % g.hud.game_over_boss.text)
		check(g.hud.game_over_table.visible == mode, "Aufschlüsselung nur im Punkte-Modus (%d Felder)" % g.hud.game_over_table.get_child_count())
		# Laden mitten im Endboss: Markierung und Wertung bleiben
		var h: Node = load(Session.GAME).instantiate()
		add_child(h)
		await get_tree().process_frame
		SaveGame.apply(h, st)
		check(h.enemies.size() >= 1 and h.enemies.any(func(e): return e.final_boss) and int(h.score_stats.get(t1, {}).get("kills", 0)) == 1,
			"Spielstand: Endboss und Wertung bleiben erhalten")
		h.queue_free()
		g.queue_free()
		await get_tree().process_frame
	Session.score_mode = false


## Koop-Vorbereitung: Spieleraktionen als Befehle (reine Daten), auch nach einer Netz-Übertragung (var_to_bytes).
func _command_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	var cells := [Vector2i(14, 40), Vector2i(18, 40), Vector2i(22, 40), Vector2i(26, 40), Vector2i(30, 40)]
	check(g.submit({"type": "place", "cell": cells[0]}) and g.towers.has(cells[0]), "Befehl place setzt einen Gem")
	check(not g.submit({"type": "place", "cell": cells[0]}), "Befehl auf belegtes Feld wird verworfen")
	for c in cells.slice(1):
		var wire = bytes_to_var(var_to_bytes({"type": "place", "cell": c, "player": 0}))
		g.execute(wire)
	check(g.phase == g.Phase.CHOOSE and g.round_towers.size() == 5, "Befehle nach Netz-Übertragung: 5 Gems, Auswahlphase")
	var t: Tower = g.round_towers[0]
	var ref: Dictionary = bytes_to_var(var_to_bytes(g.tower_ref(t)))
	check(g.tower_from_ref(ref) == t, "Tower über seinen Platz wiedergefunden")
	var opts: Array = g.tower_options(t)
	check(not g.execute({"type": "option", "tower": ref, "index": 0, "action": "keep", "id": "gibt_es_nicht", "tier": 0, "player": 0}) and g.phase == g.Phase.CHOOSE,
		"veralteter Befehl (andere Option) wird verworfen")
	check(g.execute({"type": "take_back", "tower": g.tower_ref(g.round_towers[4]), "player": 0}) and g.phase == g.Phase.BUILD, "Befehl take_back")
	g.execute({"type": "place", "cell": cells[4], "player": 0})
	opts = g.tower_options(t)
	check(g.execute({"type": "option", "tower": ref, "index": 0, "action": opts[0].action, "id": opts[0].id, "tier": opts[0].tier, "player": 0}) and g.phase == g.Phase.WAVE,
		"Befehl option (Behalten) startet die Welle")
	g.queue_free()
	await get_tree().process_frame


## Koop: zwei Spieler auf einem Feld. Jeder setzt und wählt seine eigene Runde, die Welle startet erst,
## wenn beide fertig sind. Fremde Tower lassen sich nicht wählen oder zurücknehmen, das Kopfgeld geht an
## den Besitzer des Towers, der zuletzt getroffen hat.
func _coop_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	g.setup_players(["Anna", "Ben"])
	check(g.players.size() == 2 and g.players[1].gold == g.map.start_gold, "Koop: zwei Spieler, jeder mit Startgold")
	var a_cells := [Vector2i(14, 40), Vector2i(18, 40), Vector2i(22, 40), Vector2i(26, 40), Vector2i(30, 40)]
	var b_cells := [Vector2i(14, 30), Vector2i(18, 30), Vector2i(22, 30), Vector2i(26, 30), Vector2i(30, 30)]
	for c in a_cells:
		g.execute({"type": "place", "cell": c, "player": 0})
	check(g.players[0].round_towers.size() == 5 and g.stage(0) == g.Phase.CHOOSE and g.stage(1) == g.Phase.BUILD and g.phase == g.Phase.BUILD,
		"Koop: Anna wählt schon, Ben setzt noch, gemeinsam bleibt Bauphase")
	check(g.gems_left() == 0 and not g.submit({"type": "place", "cell": b_cells[0]}), "Koop: Anna kann keinen sechsten Gem setzen")
	var a0: Tower = g.players[0].round_towers[0]
	var ref_a: Dictionary = g.tower_ref(a0)
	check(a0.owner_player == 0, "Koop: Gem gehört Anna")
	check(not g.execute({"type": "take_back", "tower": ref_a, "player": 1}) and g.towers.has(a0.cell), "Koop: Ben kann Annas Gem nicht zurücknehmen")
	check(not g.execute({"type": "option", "tower": ref_a, "index": 0, "action": "keep", "id": a0.tower_id, "tier": a0.tier, "player": 1}),
		"Koop: Ben kann Annas Gem nicht behalten")
	check(not g.execute({"type": "place", "cell": b_cells[0], "player": 5}), "Koop: unbekannter Spieler wird verworfen")
	for c in b_cells:
		check(g.execute({"type": "place", "cell": c, "player": 1}), "Koop: Ben setzt %s" % c)
	check(g.phase == g.Phase.CHOOSE and g.players[1].round_towers.size() == 5, "Koop: beide in der Wahlphase")
	check(g.players[1].round_towers.all(func(t): return t.owner_player == 1), "Koop: Bens Gems gehören Ben")
	check(g.execute({"type": "option", "tower": ref_a, "index": 0, "action": "keep", "id": a0.tower_id, "tier": a0.tier, "player": 0}),
		"Koop: Anna behält einen Gem")
	check(g.stage(0) == g.Phase.WAVE and g.phase == g.Phase.CHOOSE and g.players[0].round_towers.is_empty() and g.players[1].round_towers.size() == 5,
		"Koop: Anna wartet, Ben wählt noch, keine Welle")
	check(g.hud.phase_title.text == tr("Warten"), "Koop: Anzeige sagt Warten (%s)" % g.hud.phase_title.text)
	var st := SaveGame.capture(g)
	var b0: Tower = g.players[1].round_towers[0]
	check(g.execute({"type": "option", "tower": g.tower_ref(b0), "index": 0, "action": "keep", "id": b0.tower_id, "tier": b0.tier, "player": 1})
		and g.phase == g.Phase.WAVE, "Koop: Welle startet, wenn auch Ben behalten hat")
	# Kopfgeld an den Besitzer des treffenden Towers
	g._spawn_enemy(g.waves[0].groups[0])
	var e: Enemy = g.enemies[-1]
	b0._hit(e, 1.0)
	check(e.last_hit_by == 1, "Koop: Treffer von Bens Tower merkt Ben")
	var a_before: float = g.players[0].gold + g.players[0].gold_frac
	var b_before: float = g.players[1].gold + g.players[1].gold_frac
	e.take_raw_damage(e.hp + 1.0)
	check(g.players[0].gold + g.players[0].gold_frac == a_before and g.players[1].gold + g.players[1].gold_frac > b_before,
		"Koop: Kopfgeld geht an Ben")
	check(g.tower_options(b0).is_empty(), "Koop: Anna sieht keine Optionen für Bens Tower")
	# Spielstand mitten in der Wahl: beide Spieler, Runden und Besitz kommen zurück
	var h: Node = load(Session.GAME).instantiate()
	add_child(h)
	await get_tree().process_frame
	SaveGame.apply(h, st)
	check(h.players.size() == 2 and h.stage(0) == h.Phase.WAVE and h.stage(1) == h.Phase.CHOOSE and h.phase == h.Phase.CHOOSE
		and h.players[1].round_towers.size() == 5 and h.towers[b_cells[0]].owner_player == 1 and h.players[1].name == "Ben",
		"Koop-Spielstand: Spieler, Runden und Besitz geladen")
	h.queue_free()
	g.queue_free()
	await get_tree().process_frame


## Koop übers Netz, hier ohne Netz verbunden: der Host rechnet, der Mitspieler schickt Befehle und
## übernimmt den Stand (coop_sync.gd).
func _coop_sync_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	Session.coop = {"role": "host", "player": 0, "names": ["Anna", "Ben"]}
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	Session.coop = {"role": "client", "player": 1, "names": ["Anna", "Ben"]}
	var h: Node = load(Session.GAME).instantiate()
	add_child(h)
	await get_tree().process_frame
	check(g.coop != null and g.coop.host and not g.mirror and h.mirror and h.local_player == 1, "Koop-Netz: Host rechnet, Ben spiegelt")
	h.coop.command_sink = func(cmd): g.coop.receive(1, cmd)
	h.coop.apply_state(g.coop.snapshot())
	check(h.rocks.keys().all(func(c): return g.rocks.has(c)) and h.rocks.size() == g.rocks.size() and h.players.size() == 2,
		"Koop-Netz: Steine und Spieler vom Host übernommen")
	var b_cells := [Vector2i(14, 30), Vector2i(18, 30), Vector2i(22, 30), Vector2i(26, 30), Vector2i(30, 30)]
	for c in b_cells:
		h.submit({"type": "place", "cell": c})
	check(g.players[1].round_towers.size() == 5 and h.towers.is_empty(), "Koop-Netz: Bens Befehle laufen beim Host")
	h.coop.apply_state(g.coop.snapshot())
	check(b_cells.all(func(c): return h.towers.has(c) and h.towers[c].owner_player == 1) and h.stage() == h.Phase.CHOOSE,
		"Koop-Netz: Ben sieht seine Gems und wählt")
	check(h.selected == h.round_towers[-1], "Koop-Netz: letzter Gem ausgewählt")
	var keep: Tower = h.round_towers[0]
	h._select(keep)
	h._on_option_chosen(0)
	h.coop.apply_state(g.coop.snapshot())
	check(h.stage() == h.Phase.WAVE and g.phase == g.Phase.BUILD and h.towers.has(keep.cell) and not h.towers[keep.cell].is_new,
		"Koop-Netz: Ben hat behalten und wartet, Anna setzt noch")
	check(b_cells.slice(1).all(func(c): return h.rocks.has(c)), "Koop-Netz: Bens übrige Gems sind auch bei Ben Steine")
	check(h.hud.phase_title.text == tr("Warten"), "Koop-Netz: Ben sieht Warten")
	check(not g.coop.receive(1, {"type": "place", "cell": Vector2i(14, 50)}) and not g.coop.receive(1, {"type": "debug_gold"}),
		"Koop-Netz: Ben kann nach dem Behalten nicht mehr setzen, fremde Befehle werden verworfen")
	h.submit({"type": "speed", "factor": 2.0})
	check(Engine.time_scale == 2.0, "Koop-Netz: Tempo-Befehl gilt beim Host")
	h.submit({"type": "speed", "factor": 1.0})
	for c in [Vector2i(14, 40), Vector2i(18, 40), Vector2i(22, 40), Vector2i(26, 40), Vector2i(30, 40)]:
		g.submit({"type": "place", "cell": c})
	var a0: Tower = g.round_towers[0]
	g.submit({"type": "option", "tower": g.tower_ref(a0), "index": 0, "action": "keep", "id": a0.tower_id, "tier": a0.tier})
	check(g.phase == g.Phase.WAVE, "Koop-Netz: Welle startet beim Host")
	h.coop.apply_state(g.coop.snapshot())
	check(h.phase == h.Phase.WAVE and h.spawn_queue.size() == g.spawn_queue.size(), "Koop-Netz: Ben sieht die Welle (%d Gegner)" % h.spawn_queue.size())
	g._process_wave(3.0)
	h.coop.apply_enemies(g.coop.enemy_packet())
	check(h.enemies.size() == g.enemies.size() and h.enemies.size() > 0 and h.spawn_queue.size() == g.spawn_queue.size(),
		"Koop-Netz: Gegner gespiegelt (%d)" % h.enemies.size())
	check(h.enemies.all(func(e): return e.remote), "Koop-Netz: Bens Gegner laufen nur nach")
	# Ben verlässt das Spiel mitten in der Bauphase: seine Runde blockiert nicht
	for e in g.enemies.duplicate():
		g._remove_enemy(e)
	g.spawn_queue.clear()
	g._process_wave(0.1)
	check(g.phase == g.Phase.BUILD, "Koop-Netz: nächste Bauphase")
	g.execute({"type": "place", "cell": Vector2i(14, 20), "player": 1})
	g.set_player_away(1, true)
	check(g.players[1].stage == g.Phase.WAVE and g.players[1].round_towers.is_empty() and not g.towers[Vector2i(14, 20)].is_new,
		"Koop-Netz: wer geht, behält seinen gesetzten Gem automatisch")
	var x := 10
	while g.gems_left() > 0 and x < 80:
		g.submit({"type": "place", "cell": Vector2i(x, 46)})
		x += 3
	var a1: Tower = g.round_towers[0]
	g.submit({"type": "option", "tower": g.tower_ref(a1), "index": 0, "action": "keep", "id": a1.tower_id, "tier": a1.tier})
	check(g.phase == g.Phase.WAVE, "Koop-Netz: ohne Ben startet die Welle, sobald Anna fertig ist")
	h.coop.apply_state(g.coop.snapshot())
	check(h.phase == h.Phase.WAVE and h.towers.has(Vector2i(14, 20)), "Koop-Netz: Ben sieht den Stand nach dem Wiederkommen")
	Engine.time_scale = 1.0
	h.queue_free()
	g.queue_free()
	await get_tree().process_frame


## Einstellungen vor Runde 1: Fenster im Spiel, erst danach geht es los. Im Koop wählt nur der Host.
func _setup_test() -> void:
	Session.skip_setup = false
	Session.difficulty = 1
	Session.score_mode = false
	Session.map_path = Database.first_map().path
	Session.map_override = null
	Session.coop = {"role": "host", "player": 0, "names": ["Anna", "Ben"]}
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	Session.coop = {"role": "client", "player": 1, "names": ["Anna", "Ben"]}
	var h: Node = load(Session.GAME).instantiate()
	add_child(h)
	await get_tree().process_frame
	var panel = g.hud.get_children().filter(func(c): return c is SetupPanel)
	check(not g.setup_done and panel.size() == 1, "Einstellungen: Fenster vor Runde 1")
	var wait = h.hud.get_children().filter(func(c): return c is SetupPanel)
	check(wait.size() == 1 and not h.setup_done, "Einstellungen: Mitspieler wartet auf den Host")
	check(not g.execute({"type": "place", "cell": Vector2i(14, 30), "player": 1}), "Einstellungen: Mitspieler kann vorher nichts tun")
	check(not g.execute({"type": "setup", "difficulty": 0, "score_mode": true, "player": 1}), "Einstellungen: nur der Host wählt")
	check(g.submit({"type": "setup", "difficulty": 2, "score_mode": true}) and g.setup_done and g.score_mode and Session.difficulty == 2,
		"Einstellungen: Schwer und Punkte gewählt")
	# beide Spiele teilen sich hier Session: erst den Stand nehmen, dann zurücksetzen wie auf einem anderen Rechner
	var st: Dictionary = g.coop.snapshot()
	Session.difficulty = 1
	Session.score_mode = false
	h.coop.apply_state(st)
	check(h.setup_done and h.score_mode and Session.difficulty == 2, "Einstellungen: Mitspieler übernimmt sie vom Host")
	await get_tree().process_frame
	await get_tree().process_frame
	check(g.hud.get_children().all(func(c): return not c is SetupPanel) and h.hud.get_children().all(func(c): return not c is SetupPanel),
		"Einstellungen: Fenster geschlossen")
	check(not g.submit({"type": "setup", "difficulty": 0, "score_mode": false}), "Einstellungen: nur einmal")
	h.queue_free()
	g.queue_free()
	await get_tree().process_frame
	Session.difficulty = 1
	Session.score_mode = false
	Session.skip_setup = true


## Maul-Map: zwei Zonen, zwei Bahnen. Jeder baut nur in seiner Zone, jede Welle läuft an jeder Bahn
## eines mitspielenden Spielers; Solo läuft nur die eigene Bahn.
func _maul_test() -> void:
	var path := ""
	for m in Database.list_maps():
		if m.id == "maul_2":
			path = m.path
	check(path != "", "Maul-Map vorhanden")
	# Vier Spieler: Kette im Kreis, jede Bahn durch die eigene und die nächste Zone
	var m4: MapData = null
	for m in Database.list_maps():
		if m.id == "maul_4":
			m4 = MapData.load_file(m.path)
	check(m4 != null and m4.lane_count() == 4 and m4.zones.size() == 4, "Maul (4 Spieler): vier Bahnen, vier Zonen")
	if m4 != null:
		var pf := Pathfinder.new(m4)
		var lens := range(4).map(func(i): return pf.compute_path(i).size())
		check(lens.all(func(n): return n > 100), "Maul (4 Spieler): alle Wege offen %s" % [lens])
		check(range(4).all(func(i): return m4.can_build_for(m4.waypoints(i)[1], i) and m4.can_build_for(m4.waypoints(i)[5], (i + 1) % 4)),
			"Maul (4 Spieler): jede Bahn läuft durch die eigene und die nächste Zone")
	Session.map_path = path
	Session.map_override = null
	var solo: Node = load(Session.GAME).instantiate()
	add_child(solo)
	await get_tree().process_frame
	check(solo.map.lane_count() == 2 and solo.active_lanes() == [0], "Maul solo: nur die eigene Bahn läuft")
	check(solo.lane_paths.size() == 2 and solo.lane_paths.all(func(l): return l.length > 0), "Maul: beide Bahnen haben einen Weg (%s)" % [solo.lane_paths.map(func(l): return l.length)])
	solo.queue_free()
	Session.coop = {"role": "host", "player": 0, "names": ["Anna", "Ben"]}
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	Session.coop = {"role": "client", "player": 1, "names": ["Anna", "Ben"]}
	var h: Node = load(Session.GAME).instantiate()
	add_child(h)
	await get_tree().process_frame
	h.coop.command_sink = func(cmd): g.coop.receive(1, cmd)
	check(g.active_lanes() == [0, 1], "Maul Koop: beide Bahnen laufen")
	var own_dots: int = h.board.path_points.size()
	check(own_dots == h.lane_paths[1].ground.size() and h.hud.paths_button != null, "Maul Koop: Ben sieht anfangs nur seinen Weg")
	check(not h.board.marker_texts().any(func(t): return "." in t) and h.board.marker_texts().has("S"), "Maul Koop: Wegpunkte nur mit Bens Nummern %s" % [h.board.marker_texts()])
	h.hud.paths_button.button_pressed = true
	check(h.board.path_points.size() > own_dots, "Maul Koop: Knopf zeigt auch Annas Weg")
	check(h.board.marker_texts().has("S1") and h.board.marker_texts().has("S2"), "Maul Koop: Knopf zeigt alle Wegpunkt-Nummern")
	h.hud.paths_button.button_pressed = false
	check(h.board.path_points.size() == own_dots, "Maul Koop: Knopf blendet ihn wieder aus")
	check(g.can_place(Vector2i(20, 20)) and not g.can_place(Vector2i(70, 20)), "Maul: Anna baut nur in ihrer Zone")
	check(not g.execute({"type": "place", "cell": Vector2i(20, 20), "player": 1}) and g.execute({"type": "place", "cell": Vector2i(70, 20), "player": 1}),
		"Maul: Ben baut nur in seiner Zone")
	check(g.towers[Vector2i(70, 20)].owner_player == 1, "Maul: Bens Gem in Bens Zone")
	# Welle: an jeder Bahn erscheint die Gruppe
	g.phase = g.Phase.WAVE
	g._spawn_enemy(g.waves[0].groups[0])
	var lanes: Array = g.enemies.map(func(e): return e.lane)
	check(g.enemies.size() == 2 and lanes.has(0) and lanes.has(1), "Maul: ein Gegner je Bahn")
	var e1: Enemy = g.enemies.filter(func(e): return e.lane == 1)[0]
	check(e1.pos.distance_to(Board3D.cell_center(g.map.lanes[0].spawn)) < 1.0, "Maul: Gegner der Bahn 2 startet an ihrem Spawn")
	check(is_equal_approx(g.enemies[0].score_value * 2.0, g.score_for(g.waves[0].groups[0])), "Maul: Punkte pro Welle bleiben gleich")
	# Mitspieler sieht den Gegner auf der richtigen Bahn
	h.coop.apply_state(g.coop.snapshot())
	h.coop.apply_enemies(g.coop.enemy_packet())
	var m1: Array = h.enemies.filter(func(e): return e.lane == 1)
	check(m1.size() == 1, "Maul Koop: Mitspieler kennt die Bahn")
	await get_tree().process_frame
	check(m1.size() == 1 and m1[0].pos.distance_to(e1.pos) < 2.0, "Maul Koop: Gegner läuft beim Mitspieler auf Bahn 2")
	# Spielstand: Bahn bleibt
	var st := SaveGame.capture(g)
	var k: Node = load(Session.GAME).instantiate()
	add_child(k)
	await get_tree().process_frame
	SaveGame.apply(k, st)
	check(k.enemies.any(func(e): return e.lane == 1) and k.players.size() == 2, "Maul: Spielstand behält die Bahn")
	for n in [k, h, g]:
		n.queue_free()
	await get_tree().process_frame
	Session.map_path = Database.first_map().path


## Außerhalb jeder Tower-Reichweite laufen Gegner idle_speed_factor (8×) so schnell, in Reichweite normal.
func _idle_speed_test() -> void:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	g.debug_tower = "ruby:0"
	var t: Tower = g.place_gem(Vector2i(30, 40))
	t.is_new = false
	g.phase = g.Phase.WAVE
	g._spawn_enemy(g.waves[0].groups[0])
	var e: Enemy = g.enemies[-1]
	e.set_process(false)
	check(not g.is_covered(e), "Gegner am Spawn ist außer Reichweite")
	var before: float = e.traveled
	e._process(0.05)
	check(is_equal_approx(e.traveled - before, e.speed * 0.05 * g.idle_speed_factor()) and e.boost == g.idle_speed_factor(),
		"außer Reichweite %d× so schnell (%.2f Felder)" % [int(g.idle_speed_factor()), e.traveled - before])
	e.pos = t.pos + Vector2(0.5, 0.0)
	await get_tree().process_frame
	check(g.is_covered(e), "neben dem Tower in Reichweite")
	e.place_on_path(0.0)
	# bis kurz vor die Reichweite laufen lassen: dort bremst er auf normales Tempo
	var steps := 0
	while not g.is_covered(e) and steps < 2000 and not e.dead:
		e._process(0.05)
		steps += 1
	check(g.is_covered(e) and e.pos.distance_to(t.pos) >= t.range_cells() - 0.6, "bremst am Rand der Reichweite (%.2f von %.2f)" % [e.pos.distance_to(t.pos), t.range_cells()])
	before = e.traveled
	e._process(0.05)
	check(e.boost == 1.0 and e.traveled - before <= e.speed * 0.05 + 0.001, "in Reichweite normal schnell")
	g.queue_free()
	await get_tree().process_frame


## Treffer- und Schuss-Effekte: Daten vollständig, jeder Tower bekommt Effekte, Abspielen läuft durch.
func _fx_test() -> void:
	check(FxData.hit_ids().size() >= 15, "Treffer-Effekte geladen: %d" % FxData.hit_ids().size())
	check(FxData.shot_ids(["line", "projectile", "nova"]).size() >= 4, "Schuss-Effekte geladen")
	var missing := []
	for id in FxData.hit_ids():
		for l in FxData.hit(id).get("layers", []):
			if not ResourceLoader.exists(str(l.get("tex", ""))):
				missing.append(l.get("tex", ""))
	for id in FxData.shot_ids(["line", "projectile", "nova"]):
		if not ResourceLoader.exists(str(FxData.shot(id).get("sheet", ""))):
			missing.append(FxData.shot(id).get("sheet", ""))
	check(missing.is_empty(), "Effekt-Texturen vorhanden %s" % [missing])
	var without := []
	for id in Database.tower_ids():
		var set := FxData.for_tower(id, 0)
		if not set.has("hit") or not set.has("shot"):
			without.append(id)
	check(without.is_empty(), "jeder Tower hat Treffer- und Schuss-Effekt %s" % [without])
	check(FxData.for_tower("ruby").get("shot", {}).get("id", "") == "fire_orb", "Rubin (Splash) schießt Feuer")
	check(FxData.for_tower("amethyst").get("hit", {}).get("id", "").contains("pink") or FxData.for_tower("amethyst").get("hit", {}).get("id", "").contains("purple"), "Amethyst trifft lila")
	var eff := Effects.new()
	add_child(eff)
	eff.add_beam(Vector3.ZERO, Vector3(2, 0, 1), Color.RED, "t:ruby:0")
	eff.add_beam(Vector3(1, 0, 1), Vector3(1, 1.5, 1), Color.WHITE, "n:paraiba_tourmaline:0:2.0")
	check(eff.fx.busy(), "Effekte laufen")
	for i in 120:
		eff.fx._process(1.0 / 60.0)
	check(not eff.fx.busy(), "Effekte laufen nach 2 s aus")
	eff.queue_free()
