extends Node
## Screenshots aus dem echten Spiel, ohne jedes Mal ein eigenes Aufnahme-Skript zu schreiben.
## Start über tools/screenshot.sh (setzt Xvfb und OpenGL), Optionen nach "--":
##   --szene=spiel|menu|map_editor|tower_editor|maul|heroes|survivors   Standard spiel
##   survivors: --zeit=S --bonus --nah --gold=N --klappe=S --waffe=id --neigung=Grad --auswahl=turm|1..6 --abwahl
##   Bollwerk (--szene=heroes): --zeit=S Bot spielt S Sekunden (Standard 150), --stufe=0|1|2, --setup Startfenster,
##     Etappe 3: --welle=N ab Welle N, --boss=N Kriegsherr der Welle N, --zone=arena|hain|schmiede|pruefung [--pruefung=jagd|tanz]
##     (Held steht in der Zone, mit Ausrüstung), --ereignis=haendler|karawane|blutmond|gefangener|schrein,
##                           --warnung warten, bis Warnflächen halb gefüllt sind, --boss ab Welle 10, --nah Kamera näher,
##                           --weit Kamera weit weg (ganze Karte), --shop[=grund|ruest|rezept|holz|tore] Shop offen,
##                           --gold=N Gold dazu, --farbe=0–4 --umriss=0–2 Warnflächen (Barrierefreiheit)
##                           --held=torvik|unrat|vesna|zix Held (Standard: gespeicherte Wahl)
##   --seite=single|history|profile|credits|lobby|einstellungen   im Hauptmenü diese Seite zeigen (Standard Hub)
##   --reiter=X              (mit --seite=profile) overview, history oder ein Modus (gemtd, eeve, maul, youtd …);
##   --beispielprofil        Profil mit ausgedachten Runs aller Modi füllen (Profilseite ansehen)
##   --hudbreite=80          Breite der mittigen HUD-Fläche in Prozent (60–100, wird nicht gespeichert)
##   --ui=70                 UI-Größe in Prozent (50–100), wird nicht gespeichert
##   --lobby=Anna,Ben,Max    (mit --seite=lobby) als Host mit diesen Mitspielern, --felder=0,1,1,2 Feld je Spieler
##                           (Host zuerst), --stimme=eevetd Modus vorwählen, --relay=127.0.0.1:24565 über einen Relay
##                           hosten (vorher tools/relay/relay.py starten), Code steht dann oben links
##   Shopping Maul (--szene=maul): --filiale=hm (ohne: Filialwahl), --level=N (so viele Level spielen),
##                           --welle (nächstes Level starten), --auswahl[=Tower-ID], --warten=S; Kamera aufs Zentrum
##                           (oder --punkt=x,y), Abstand --abstand=34;
##                           --sandbox, --gold=N, --reiter=xpert|main (Ladenreiter), --einheit (erste Einheit wählen),
##                           --profi (Filialwahl: Reiter Profi-Filialen), --profil (Filialwahl: Profil-Fenster offen),
##                           --bauen=h01P,h02O (diese Tower zuerst)
##   --map=<id>              Map aus data/maps (Standard classic)
##   --runden=N              N Runden automatisch spielen (Gems am Weg setzen, ersten behalten, Welle 8× laufen)
##   --tower=ruby:2,opal:0   diese Gems in der nächsten Runde setzen (Reihenfolge = Platzierung)
##   --welle=N               nächste Welle ist Welle N (Debug-Sprung)
##   --phase=bau|wahl|welle  Stand für das Bild (Standard bau); welle startet die Welle
##   --extra                 Fenster Extra Chance offen (Bauphase)
##   --warten=S              Sekunden Spielzeit vor dem Bild (z. B. Gegner unterwegs), Standard 1
##   --faehigkeiten=pierce,fork   allen Towern auf dem Feld diese Fähigkeiten (Standardwerte) dazugeben
##   --auswahl               ersten Tower der Runde (sonst den ersten auf dem Feld) auswählen
##   --treffer               nach --warten weiter warten, bis ein Treffer-Effekt leuchtet (höchstens 10 s), dann Bild
##   --grundtower=water      eeveTD: statt des festen Plans überall den Grundturm dieses Elements
##   --items                 eeveTD: Marktplatz (Feld 32,76), Lager mit Items, Höllenkohlenbecken (44,76) mit zwei Items;
##                           --auswahl wählt es, --lagerwahl=N wählt Item N im Lager, --markt öffnet das Marktplatz-Fenster
##   --winkel=oben,schraeg,nah,seite   ein Bild pro Winkel (Standard schraeg = Spielansicht)
##   --punkt=x,y             Kamera auf dieses Feld richten (nah, auch schraeg/oben/seite)
##   --abstand=N|max         Kameraabstand für schraeg/oben/seite (max = weitester Zoom, Rand der Karte prüfen)
##   --frei                  Kamera nicht auf die Karte begrenzen (CameraRig.limit_view aus, z. B. Umgebung ansehen)
##   --baufeld=x,y           Maus über dieses Feld stellen (grüne/rote Bauvorschau, auch Shopping Maul)
##   --gegner                nah: Kamera dicht auf den ersten Gegner (z. B. Boss mit --welle=42 --phase=welle)
##   --ueberlappung          Oberfläche auf Überlappungen, Ränder und abgeschnittenen Text prüfen
##                           (tools/ui_pruefung.gd): Zeilen "UI …", Fundstellen rot im Bild
##   --zuschnitt=x,y,b,h     Bild zuschneiden (Pixel)
##   --mitspieler=Anna,Ben   als Mehrspieler-Host mit diesen erfundenen Mitspielern (Liste „Mitspieler“ unten rechts)
##   --koop=Name1,Name2      als Koop-Partie mit diesen Spielern (ohne Netz), --gast = Bild aus Sicht von Spieler 2
##   --rasse=kleingarten     Randgruppen TD (--map=randgruppen): Rasse für das Bild, --bauen=N Bauvorschau Tower N
##   --vitrine               eeveTD: viele verschiedene Tower auf den Mauern (Modelle ansehen)
##   --einstellungen         Einstellungsfenster vor Runde 1 offen lassen (z. B. eeveTD)
##   --aufstieg=N            Aufstiegsstufen bis +N frei und gewählt, höchste Schwierigkeit vorausgewählt (Startfenster ansehen)
##   --rezepte, --elemente   YouTD: Fenster „Rezepte“ bzw. „Elemente“ in der Mitte öffnen (sonst bleiben beide zu)
##   --turmlicht=sockel|kontur|aus  eeveTD: Tower von Lampen im Sockel angeleuchtet, weiße Kontur oder nichts
##   --nacht                 Nachtversion des Spielfeld-Stils (FieldStyle.night, z. B. Shopping Maul im Mondlicht,
##                           eeveTD ist ohnehin nachts)
##   --tag                   eeveTD bei Tag statt Nacht
##   --bonusfelder           eeveTD: Bonusfelder (Lava, Eis, Marmor) auslegen, drei davon unter Towern des Plans
##   --ende                  eeveTD: Endbildschirm mit Wertung (Sieg)
##   --alle_wege             Koop (Shopping Maul, GemTD-Maul-Karten): auch die Gegnerwege der Mitspieler zeigen
##   --filter=aus|an         Stil-Filter des Modus ab- bzw. anschalten (ohne die Einstellung zu speichern)
##   --lichtpfad             Lichtpfad an (Lichter fliegen den Gegnerweg entlang, ohne die Einstellung zu speichern)
##   --debug                 Debug-Menü offen (GemTD, eeveTD, Shopping Maul)
##   --spielmenue[=einstellungen]  Menü im Spiel offen (wie Esc), mit =einstellungen dazu das Einstellungsfenster
##   --roguelike[=N]         GemTD-Variante Roguelike: Bonus-Auswahl nach Welle N (Standard 10) offen;
##                           --boni=ruby:damage:0.4,silver:speed:0.2 diese Werte-Boni schon vorher gewählt (z. B. fürs Infofenster),
##                           --angebot=flask:ruby,execute,ability:silver diese Boni (Bonus-ID[:Tower]) als Karten
##   --messen=S              statt eines Bildes S Sekunden Leistung messen (Bildzeit, Skriptzeit, Draw Calls,
##                           Objekte, Lichter, Knoten), Ausgabe Zeilen MESSUNG; tools/leistung.sh fasst mehrere zusammen
##   --grafik=0|1|2          Grafikqualität Niedrig/Mittel/Hoch (Standard Hoch; Xvfb würde sonst als Software-Grafik Niedrig wählen)
##   --ep=N                  (mit --auswahl) der gewählte Tower hat N EP (Level-System, leveling.gd);
##                           --level_demo: Beispiel-Freischaltungen (Reichweite ab 3, Krit ab 5), --leveltip: Level-Tooltip offen
##   --sprache=de|en
##   --aus=<ordner>          Standard /mnt/project-files/screens/auto
##   --name=<präfix>         Dateiname <präfix>_<winkel>.png, Standard bild
## Ausgabe: eine Zeile BILD <pfad> je Bild. Für eigene Zustände (Tooltip, Panel) Skript kopieren
## und nach _prepare() eigene Schritte einfügen.

var opts := {}
var rng := RandomNumberGenerator.new()


## Ausgedachte Runs in allen Modi (--beispielprofil), jedes Mal neu.
func _example_profile() -> void:
	var g := ProjectSettings.globalize_path(Profile.dir)
	for sub in ["runs", "backups", ""]:
		if not DirAccess.dir_exists_absolute(g.path_join(sub)):
			continue
		for f in DirAccess.get_files_at(g.path_join(sub)):
			DirAccess.remove_absolute(g.path_join(sub).path_join(f))
	Profile.reset_cache()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var maps := {"gemtd": ["Classic", "Spirale"], "roguelike": ["Classic"], "eeve": ["Druidenhain"], "maul": ["ikea", "mediamarkt"],
		"randgruppen": ["Stadtpark"], "youtd": ["Insel"]}
	var waves := {"gemtd": 50, "roguelike": 50, "eeve": 57, "maul": 40, "randgruppen": 35, "youtd": 120}
	var towers := {"gemtd": ["ruby", "sapphire", "emerald"], "roguelike": ["ruby"], "eeve": [], "maul": [], "randgruppen": [], "youtd": []}
	for i in 60:
		var m: String = ["gemtd", "gemtd", "gemtd", "roguelike", "eeve", "maul", "maul", "randgruppen", "youtd"][r.randi() % 9]
		var n: int = waves[m]
		var won := r.randf() < 0.4
		var wave := n if won else r.randi_range(n / 3, n - 1)
		var types := {}
		for id in towers[m]:
			types[id] = {"built": r.randi_range(2, 9), "tiers": {}, "kills": r.randi_range(50, 900), "damage": r.randf_range(1e5, 9e7),
				"best_wave_damage": r.randf_range(1e4, 5e6), "best_wave": r.randi_range(1, wave), "alive": 1}
		var info := {"map": maps[m][r.randi() % maps[m].size()], "difficulty": r.randi_range(0, 2), "victory": won, "wave": wave,
			"waves": n, "lives": r.randi_range(0, 50), "score": r.randi_range(5000, 48000) if m == "gemtd" else 0,
			"kills": r.randi_range(400, 5000), "play_time": r.randi_range(900, 5400), "debug": i % 17 == 3}
		Profile.record_run(m, info, {"types": types, "towers": [], "wave_log": [], "actions": {}})
		if i % 13 == 5:
			Profile.record_abort(m, {"map": info.map, "wave": wave / 2, "waves": n, "play_time": 600})
	MaulXp.save_xp(314)
	YoutdProgress.prog().xp = 4820.0
	Profile.save()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	rng.seed = int(opts.get("seed", "1"))
	RunHistory.path = "user://screenshot_run_history.json"
	Profile.dir = "user://screenshot_profile"
	if opts.has("beispielprofil"):
		_example_profile()
	Session.skip_setup = not opts.has("einstellungen")
	if opts.has("rasse"):
		Session.rg_choice = {"race": str(opts.rasse)}
	if opts.has("aufstieg"):
		_ascension(int(opts.aufstieg))
	Display.quality = int(opts.get("grafik", Display.HIGH))
	Display.apply_quality()
	FieldStyle.night = opts.has("nacht")
	# Stil-Filter (StyleFilter) aus bzw. an, ohne die Einstellung zu speichern
	if opts.has("filter"):
		Display.style_filter = opts.filter != "aus"
	if opts.has("tag"):
		Session.eeve_choice["night"] = false
	if opts.has("turmlicht"):
		Tower.eeve_accent = "" if opts.turmlicht == "aus" else str(opts.turmlicht)
	if opts.has("koop"):
		var guest := opts.has("gast")
		Session.coop = {"role": "client" if guest else "host", "player": 1 if guest else 0, "names": String(opts.koop).split(",")}
	if opts.has("sprache"):
		Loc.set_language(opts.sprache)
	if opts.has("mitspieler"):
		Net.my_name = "Lukas"
		Net.host(24691)
		var names := String(opts.mitspieler).split(",")
		for i in names.size():
			Net.players[100 + i] = {"name": names[i], "status": {"in_game": true, "phase": 0, "wave": 3, "waves": 50, "lives": 100}, "uid": "fake-%d" % i}
	var out_dir: String = opts.get("aus", "/mnt/project-files/screens/auto")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene: String = opts.get("szene", "spiel")
	var node: Node
	match scene:
		"menu": node = load(Session.MAIN_MENU).instantiate()
		"map_editor": node = load(Session.MAP_EDITOR).instantiate()
		"tower_editor": node = load(Session.TOWER_EDITOR).instantiate()
		"maul": node = load(Session.MAUL).instantiate()
		"survivors": node = load("res://scenes/survivors_game.tscn").instantiate()
		"heroes":
			Session.skip_setup = not opts.has("setup")
			Session.difficulty = int(opts.get("stufe", "1"))
			node = load("res://scenes/heroes_game.tscn").instantiate()
			node.bot = true
			node.force_hero = str(opts.get("held", ""))
		_:
			var path := "res://data/maps/%s.json" % opts.get("map", "classic")
			Session.map_path = path
			Session.map_override = null
			# Maps eines anderen Spiels (z. B. "game": "eevetd") starten dessen Szene
			var md = Database.load_json(path)
			var kind: String = str(md.get("game", "gemtd")) if md is Dictionary else "gemtd"
			Session.game_kind = kind
			node = load(Session.game_scene()).instantiate()
	# Fenster so groß wie der Xvfb-Bildschirm (--groesse), nicht die gespeicherte Auflösung
	Display.resolution = DisplayServer.screen_get_size()
	Display.fullscreen = false
	if opts.has("hudbreite"):
		Display.hud_width = clampf(float(opts.hudbreite) / 100.0, Display.HUD_WIDTH_MIN, 1.0)
	if opts.has("ui"):
		Display.ui_scale = clampf(float(opts.ui) / 100.0, Display.UI_SCALE_MIN, Display.UI_SCALE_MAX)
	Display._apply()
	add_child(node)
	await _frames(5)
	if scene == "menu" and opts.get("seite", "") == "einstellungen":
		node._open_settings()
	elif scene == "menu" and opts.has("seite"):
		node.show_page(opts.seite)
		if opts.has("reiter") and opts.seite == "profile":
			node.profile.show_view(str(opts.reiter))
		await _frames(3)
	if scene == "menu" and opts.has("lobby"):
		await _fake_lobby(node)
	var angles: PackedStringArray = ["bild"]
	if scene == "maul":
		await _prepare_maul(node)
	if scene == "heroes":
		await _prepare_heroes(node)
	if scene == "survivors":
		await _prepare_survivors(node)
	if scene == "spiel":
		await _prepare(node)
		angles = String(opts.get("winkel", "schraeg")).split(",")
	if opts.has("extra") and scene == "spiel":
		node.hud.extra_chance_requested.emit()
	if opts.has("lichtpfad") and (scene == "spiel" or scene == "maul"):
		node.path_lights.visible = true
		node.board.set_path_dots(false)
		var lb: Button = node.hud.lights_button
		lb.set_pressed_no_signal(true)
		await _frames(30)
	if opts.has("debug") and (scene == "spiel" or scene == "maul"):
		if scene == "maul":
			node.hud.toggle_debug()
		else:
			node.hud.debug_panel.show()
			node.hud.debug_button.set_pressed_no_signal(true)
	if opts.has("spielmenue") and (scene == "spiel" or scene == "maul"):
		if scene == "maul":
			node.hud.toggle_menu()
		else:
			node.hud.open_leave_confirm()
		if str(opts.spielmenue) == "einstellungen":
			node.hud.settings_panel.open()
	if opts.has("messen"):
		if scene == "spiel":
			_camera(node, angles[0])
		await _measure(float(opts.messen))
		get_tree().quit()
		return
	for w in angles:
		if scene == "spiel":
			_camera(node, w)
		if opts.has("baufeld"):
			await _mouse_to_cell(node)
		await _frames(4)
		if opts.has("treffer") and scene == "spiel":
			await _wait_hit(node)
		var img := get_viewport().get_texture().get_image()
		if opts.has("ueberlappung"):
			var found := UiPruefung.check(get_tree().root, img)
			for line in found:
				print(line)
			print("UI-Prüfung: %d Funde" % found.size())
		if opts.has("zuschnitt"):
			var r := String(opts.zuschnitt).split(",")
			img = img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		var file := out_dir.path_join("%s_%s.png" % [opts.get("name", "bild"), w])
		img.save_png(file)
		print("BILD ", file)
	get_tree().quit()


## Lobby als Host mit erfundenen Mitspielern (nur fürs Bild, ohne echte Verbindungen).
func _fake_lobby(menu: Node) -> void:
	Net.my_name = "Lukas"
	if opts.has("relay"):   # --relay=127.0.0.1:24565: über einen laufenden Relay hosten (tools/relay/relay.py)
		Net.host_relay(str(opts.relay))
		for i in 300:
			if not Net.is_connecting():
				break
			await get_tree().process_frame
	else:
		Net.host(24690)
	var names := String(opts.lobby).split(",")
	for i in names.size():
		Net.players[100 + i] = {"name": names[i], "status": {}, "uid": "fake-%d" % i}
	if opts.has("stimme"):
		Net.vote(str(opts.stimme))
	var lobby = menu.lobby
	var list := String(opts.get("felder", "")).split(",", false)
	var uids := [Net.uid] + range(names.size()).map(func(i): return "fake-%d" % i)
	for i in mini(list.size(), uids.size()):
		lobby.fields[uids[i]] = int(list[i])
	Net.players_changed.emit()
	await _frames(5)


## --messen: S Sekunden lang je Bild die Leistungswerte sammeln, dann Mittel, 95-%-Wert und Höchstwert ausgeben.
func _measure(seconds: float) -> void:
	await _frames(10)
	var keys := {
		"bild_ms": -1,
		"prozess_ms": Performance.TIME_PROCESS,
		"physik_ms": Performance.TIME_PHYSICS_PROCESS,
		"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
		"objekte": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
		"dreiecke": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
		"knoten": Performance.OBJECT_NODE_COUNT,
	}
	var rows := {}
	for k in keys:
		rows[k] = []
	var t := 0.0
	var last := Time.get_ticks_usec()
	while t < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		t += dt / 1000.0
		for k in keys:
			var v: float = dt if keys[k] < 0 else Performance.get_monitor(keys[k])
			if k.ends_with("_ms") and keys[k] >= 0:
				v *= 1000.0
			rows[k].append(v)
	var counts := {"lichter": 0, "lichter_schatten": 0, "partikel": 0, "multimesh": 0, "multimesh_inst": 0, "gegner": 0, "tower": 0}
	for n in _all_nodes(get_tree().root):
		if n is Light3D and n.is_visible_in_tree():
			counts.lichter += 1
			if n.shadow_enabled:
				counts.lichter_schatten += 1
		elif (n is GPUParticles3D or n is CPUParticles3D) and n.is_visible_in_tree() and n.emitting:
			counts.partikel += 1
		elif n is MultiMeshInstance3D and n.is_visible_in_tree() and n.multimesh:
			counts.multimesh += 1
			counts.multimesh_inst += n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
		if n is Enemy:
			counts.gegner += 1
		elif n is Tower:
			counts.tower += 1
	# größte Dreiecks-Verbraucher (Mesh x Anzahl), ohne Sichtbarkeitsprüfung der Kamera
	var geo := {}
	for n in _all_nodes(get_tree().root):
		var mesh: Mesh = null
		var count := 1
		if n is MeshInstance3D and n.is_visible_in_tree():
			mesh = n.mesh
		elif n is MultiMeshInstance3D and n.is_visible_in_tree() and n.multimesh:
			mesh = n.multimesh.mesh
			count = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
		if mesh == null or count == 0:
			continue
		var name: String = mesh.resource_path.get_file() if mesh.resource_path != "" else (mesh.resource_name if mesh.resource_name != "" else "%s/%s" % [n.get_parent().name, n.name])
		var e: Array = geo.get_or_add(name, [0, 0, _tris(mesh), n is MultiMeshInstance3D])
		e[0] += count
		e[1] += count * e[2]
	var top := geo.keys()
	top.sort_custom(func(a, b): return geo[a][1] > geo[b][1])
	for k in top.slice(0, int(opts.get("geometrie", "8"))):
		print("MESSUNG geometrie %s: %d x %d = %d Dreiecke%s" % [k, geo[k][0], geo[k][2], geo[k][1], " (MultiMesh)" if geo[k][3] else ""])
	var frames: int = rows.bild_ms.size()
	print("MESSUNG bilder=%d sekunden=%.1f fps=%.1f" % [frames, t, frames / maxf(t, 0.001)])
	for k in keys:
		var a: Array = rows[k].duplicate()
		a.sort()
		var sum := 0.0
		for v in a:
			sum += v
		print("MESSUNG %s mittel=%.2f p95=%.2f max=%.2f" % [k, sum / a.size(), a[int(a.size() * 0.95)], a[-1]])
	print("MESSUNG anzahl %s" % " ".join(counts.keys().map(func(k): return "%s=%d" % [k, counts[k]])))


func _tris(mesh: Mesh) -> int:
	if mesh is ArrayMesh or mesh is PrimitiveMesh:
		var sum := 0
		for i in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(i)
			var idx = arr[Mesh.ARRAY_INDEX]
			sum += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
		return sum
	return 0


func _all_nodes(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Spielstand für das Bild herstellen.
func _prepare(game: Node) -> void:
	game.camera_rig.set_process(false)   # kein Mitlaufen am Fensterrand (Maus steht in Xvfb in der Ecke)
	if opts.has("alle_wege") and game.has_method("set_show_all_paths"):
		game.set_show_all_paths(true)
	if game.has_method("add_element_point"):
		await _prepare_eeve(game)
		return
	# YouTD vor Randgruppen prüfen: beide haben build_tower()
	if game.has_method("roll_start"):
		await _prepare_youtd(game)
		return
	if game.has_method("race_towers"):
		await _prepare_rg(game)
		return
	for i in int(opts.get("runden", "0")):
		_place_round(game, [])
		game._select(game.round_towers[0])
		game._on_option_chosen(0)
		Engine.time_scale = 8.0
		var frames := 0
		while game.phase == game.Phase.WAVE and frames < 20000:
			await get_tree().process_frame
			frames += 1
		Engine.time_scale = 1.0
	if opts.has("welle"):
		game.debug_jump_to_wave(int(opts.welle))
	var phase: String = opts.get("phase", "bau")
	if phase != "bau" or opts.has("tower"):
		var wanted: Array = String(opts.get("tower", "")).split(",", false)
		_place_round(game, wanted)
	if phase == "welle":
		game._select(game.round_towers[0])
		game._on_option_chosen(0)
	if opts.has("faehigkeiten"):
		for t in game.towers.values():
			t.stats = t.stats.duplicate(true)
			var list: Array = t.stats.get("abilities", [])
			for type in String(opts.faehigkeiten).split(","):
				list.append(Abilities.default_for(type))
			t.stats["abilities"] = list
	if opts.has("roguelike") or opts.has("boni"):
		var r: Rogue = game.enable_rogue()
		r.on_build()
		for b in String(opts.get("boni", "")).split(",", false):
			var p := b.split(":")
			r.boons[0].append({"boon": p[1], "effect": "stat", "id": p[0], "kind": str(Database.towers.get(p[0], {}).get("category", "gem")),
					"stat": p[1], "value": float(p[2]) if p.size() > 2 else 0.2, "rarity": "common", "params": {}, "wave": 0})
		game._update_auras()
		if opts.has("roguelike"):
			game.wave_index = int(opts.roguelike) if str(opts.roguelike) != "1" else 10
			r.on_build()
			if opts.has("angebot"):
				var list := []
				for spec in String(opts.angebot).split(",", false):
					var parts := spec.split(":")
					for i in 300:
						var o: Dictionary = r._make_offer(Rogue.boon_def(parts[0]), 0, game.rng)
						if not o.is_empty() and (parts.size() < 2 or o.id == parts[1]):
							list.append(o)
							break
				r.offers[0] = list
	if opts.has("auswahl"):
		if not game.round_towers.is_empty():
			game._select(game.round_towers[0])
		elif not game.towers.is_empty():
			game._select(game.towers.values()[0])
	await _level_shot(game)
	var t := 0.0
	var wait := float(opts.get("warten", "1"))
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()


## Shopping Maul: Filiale eröffnen, im Zentrum bauen, Level im Zeitraffer spielen.
## Tower Survivors (--szene=survivors): Bot spielt --zeit=S Sekunden Spielzeit (Standard 150) im Zeitraffer,
## kauft Waffen und Upgrades; --bonus zeigt danach die Bonus-Wahl, --nah holt die Kamera an die Plattform.
func _prepare_survivors(game: Node) -> void:
	if game.state == "setup":
		return
	game.rng.seed = int(opts.get("seed", "1"))
	game.gold += float(opts.get("gold", "0"))
	var left := float(opts.get("zeit", "150"))
	var dt := 1.0 / 30.0
	var k := 0
	while left > 0.0 and game.state != "over":
		if game.state == "perk":
			if opts.has("bonus"):
				break
			game.bot_turn()
		game.step(dt)
		left -= dt
		k += 1
		if k % 15 == 0:
			game.bot_turn()
		if k % 300 == 0:
			await get_tree().process_frame
	if opts.has("klappe"):
		# --klappe=S: eine neue Waffe auf einen freien Platz, S Sekunden des Klappen-Ablaufs zeigen
		var slot: int = game.target_slot("__none__")
		if slot < 0:
			game.gold += 2000
			game.buy_upgrade("slot")
			slot = game.target_slot("__none__")
		if slot < 0:
			game.sell(game.slots_open - 1)
			for i in 40:
				game.step(1.0 / 30.0)
			slot = game.slots_open - 1
		game._equip(str(opts.get("waffe", "schiene")), slot)
		game.paid[slot] = 100
		var t := float(opts.klappe)
		while t > 0.0:
			game.platform.step(minf(t, 1.0 / 30.0))
			t -= 1.0 / 30.0
		game.paused = true
	if opts.has("neigung"):
		game.cam_pitch = float(opts.neigung)
		game._place_camera()
	if opts.has("nah"):
		game.cam_dist = 17.0 if opts.has("klappe") else 19.0
		game._place_camera()
	# --auswahl=turm|1..6 zeigt den Auswahlkreis, --abwahl dazu den Moment beim Abwählen (Kreis wächst und verblasst)
	if opts.has("auswahl"):
		var a := str(opts.auswahl)
		if a == "turm":
			game.hud.sel.select("tower")
		else:
			game.hud.sel.select("slot", int(a) - 1)
		game.hud.refresh()
		await get_tree().create_timer(0.4, true, false, true).timeout
		if opts.has("abwahl"):
			game.hud.deselect()
			await get_tree().create_timer(0.12, true, false, true).timeout
			await get_tree().process_frame
			return
	await _frames(12)


## Bollwerk: Bot spielt im Zeitraffer, danach optional auf halb gefüllte Warnflächen warten und anhalten.
func _prepare_heroes(game: Node) -> void:
	if game.state == "setup":
		return
	game.set_physics_process(false)
	game.rng.seed = int(opts.get("seed", "1"))
	if opts.has("farbe"):
		HdTelegraph.palette = int(opts.farbe)
	if opts.has("umriss"):
		HdTelegraph.outline = int(opts.umriss)
	if opts.has("gold"):
		game.shop.add_gold(int(opts.gold))
	if opts.has("boss"):
		game.spawn_queue.clear()
		game.hero.add_xp(4000.0)
		game.start_wave(int(opts.get("welle", "10")) if opts.boss == "1" else int(opts.boss))
	elif opts.has("welle"):
		game.spawn_queue.clear()
		game.hero.add_xp(400.0 * int(opts.welle))
		game.start_wave(int(opts.welle))
	if opts.has("ereignis"):
		game.events.start(str(opts.ereignis))
	if opts.has("zone"):
		var zid := str(opts.zone)
		if game.wave < 13:
			game.wave = 13
		game.hero.position = game.zones.center(zid) + (game.fortress_pos - game.zones.center(zid)).normalized() * 5.0
		game.shop.gold += 3000
		for k in 3:
			game.shop.inv[k] = {"id": ["schmiedesonne", "bollwerkplatte", "windlaeufer"][k], "n": 1, "up": [2, 0, 1][k], "gems": [["rubin"], [], ["topas", "diamant"]][k]}
		game.shop._changed()
		match zid:
			"arena":
				game.shop.act({"kind": "arena"})
			"hain":
				game.shop.act({"kind": "lumberjack"})
			"pruefung":
				if opts.has("pruefung"):
					game.shop.act({"kind": "trial", "id": str(opts.pruefung)})
	var left := float(opts.get("zeit", "150"))
	var dt := 1.0 / 30.0
	var k := 0
	var hold = game.hero.position if opts.has("zone") else null
	while left > 0.0 and game.state == "play":
		if hold != null:
			game.hero.move_dir = Vector3.ZERO
			if game.hero.position.distance_to(hold) > 6.0:
				game.hero.position = hold
			if k % 3 == 0 and opts.has("kampf"):
				game.bot_turn()
		elif k % 3 == 0:
			game.bot_turn()
		game.step(dt)
		left -= dt
		k += 1
		if k % 300 == 0:
			await get_tree().process_frame
	if opts.has("warnung"):
		var tries := 0
		while tries < 1800 and game.state == "play":
			var n := 0
			for e in game.enemies:
				if e.casting() and str(e.cast.phase) == "windup" and float(e.cast.t) > float(e.cast.windup) * 0.55:
					n += 1
			if n >= int(opts.get("warnungen", "1")):
				break
			if k % 3 == 0:
				game.bot_turn()
			game.step(dt)
			k += 1
			tries += 1
	game.paused = true
	if opts.has("shop"):
		var t := str(opts.shop)
		game.hud.econ.tab = t if t != "1" else "grund"
		if game.hud.econ.tab == "rezept":
			game.hud.econ.picked = "schmiedesonne"
		game.hud.econ.toggle()
		game.hud.refresh()
	if opts.has("nah"):
		game.cam_dist = 17.0
	if opts.has("weit"):
		game.cam_dist = 150.0
		game.cam_pos = game.fortress_pos
		game.camera.far = 400.0
		game._place_camera()
		await _frames(12)
		return
	game.cam_pos = game.hero.position
	game._place_camera()
	await _frames(12)


func _prepare_maul(game: Node) -> void:
	game.camera_rig.set_process(false)
	if opts.has("alle_wege"):
		game.set_show_all_paths(true)
	if not opts.has("filiale"):
		if opts.has("profi"):
			game.hud._setup._kind = "pro"
			game.hud._setup._build_cards()
		if opts.has("profil"):
			game.hud._setup._show_profile()
		if opts.has("ueberall"):
			game.hud._setup._foreign = true
			game.hud._setup._refresh()
		return
	var shop: String = opts.filiale
	game.start_game(shop, 1, "group", opts.has("sandbox"), opts.has("ueberall"))
	if opts.has("gold"):
		game.players[0].gold = int(opts.gold)
	var zone: Rect2i = game.map.zones[0].rect
	var spots := []
	for y in range(zone.position.y + 1, zone.end.y - 2, 4):
		for x in range(zone.position.x + 1, zone.end.x - 2, 4):
			spots.append(Vector2i(x, y))
	var mid := Vector2(zone.get_center())
	spots.sort_custom(func(a, b): return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
	var build := func():
		var list: Array = MaulData.buyable(shop)
		for id in str(opts.get("bauen", "")).split(",", false):
			for a in spots:
				if game.submit({"type": "build", "tower": id, "cell": a}):
					break
		for a in spots:
			var best := ""
			for t in list:
				if int(t.cost) <= game.players[0].gold:
					best = str(t.id)
			if best == "":
				break
			game.submit({"type": "build", "tower": best, "cell": a})
		# Profi-Filialen: Slots mit Items füllen, Drohnen und Zombies holen
		for t in game.towers.values():
			for id in game.items_for(0, "weapon"):
				game.submit({"type": "item", "cell": t.cell, "item": id})
			if t.tower_id == "h02O":
				game.submit({"type": "drone", "cell": t.cell, "kind": "battle"})
	build.call()
	for i in int(opts.get("level", "0")):
		game.submit({"type": "start_now"})
		Engine.time_scale = 8.0
		var frames := 0
		while game.phase != game.Phase.COUNTDOWN or game.level <= i:
			await get_tree().process_frame
			frames += 1
			if frames > 60000 or game.phase >= game.Phase.GAME_OVER:
				break
		Engine.time_scale = 1.0
		build.call()
	if opts.has("welle"):
		game.submit({"type": "start_now"})
	if opts.has("auswahl") and not game.towers.is_empty():
		var pick: Node = game.towers.values()[0]
		for t in game.towers.values():
			if t.slots() > 0 or t.tower_id == str(opts.get("auswahl")):
				pick = t
		game.select(pick)
	if opts.has("einheit") and not game.units.is_empty():
		game.select_unit(game.units[0])
	if opts.has("reiter"):
		game.hud._set_tab(str(opts.reiter))
	var look: Vector2 = game.map.zone_center(0)
	if opts.has("punkt"):
		var pk := String(opts.punkt).split(",")
		look = (Vector2(float(pk[0]), float(pk[1])) + Vector2(0.5, 0.5)) * Board3D.CELL
	game.camera_rig.look_at_point(look, float(opts.get("abstand", "34")))
	var t := 0.0
	var wait := float(opts.get("warten", "1"))
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()


## --vitrine: statt des festen Plans viele verschiedene Tower (Modelle aus den CC0-Paketen) auf den Mauern.
func _eeve_vitrine(game: Node, walls: Array) -> Dictionary:
	for el in game.elements:
		game.element_caps[el] = 6
		game.elements[el] = 6
	game.gold = 200000
	var targets := ["eeve_camp_fire", "eeve_orb_of_life", "eeve_brazier", "eeve_minor_bird_launcher", "eeve_shroom_field",
			"eeve_lesser_rock_launcher", "eeve_enchanted_obelisk", "eeve_thorns_tower", "eeve_heat_stakes",
			"eeve_bird_launcher", "eeve_hazardous_shroom_field", "eeve_rock_launcher", "eeve_arcane_shrine", "eeve_blazing_brazier",
			"eeve_greater_bird_launcher", "eeve_gold_mine", "eeve_altar_of_magic", "eeve_itching_thorns_tower", "eeve_searing_totem",
			"eeve_sacred_orb_of_power", "eeve_ornate_obelisk", "eeve_nonhazardous_shroom_field", "eeve_hell_brazier",
			"eeve_greater_rock_launcher", "eeve_ruinous_obelisk", "eeve_xtreme_bird_launcher"]
	if opts.has("tower"):  # --vitrine --tower=hydro_cannon,…: genau diese Tower (ohne eeve_)
		targets = Array(str(opts.tower).split(",", false)).map(func(t): return "eeve_" + t)
	var plan := {}
	var i := 0
	for id in targets:
		var chain := []
		var cur: String = id
		while cur != "" and cur != "eeve_barricade" and chain.size() < 8:
			chain.push_front(cur)
			cur = str(Database.towers.get(cur, {}).get("eeve", {}).get("from", ""))
		if i < walls.size():
			plan[walls[i]] = chain
		i += 1
	return plan


## Randgruppen TD (--map=randgruppen): zwei versetzte Reihen Tower der Rasse (--rasse=kleingarten) in der roten Zone,
## --phase=welle startet Level 1, --auswahl wählt einen Tower aus, --bauen=1 setzt die Bauvorschau für Tower 1.
func _prepare_rg(game: Node) -> void:
	if opts.has("rasse"):
		game.rp().race = str(opts.rasse)
	game.gold = 20000
	var list: Array = game.race_towers()
	var z: Rect2i = game.map.zones[0].rect
	var i := 0
	for row in [z.position.y + 14, z.position.y + 26]:
		var xs := range(z.position.x + 1, z.end.x - 8, 2) if row == z.position.y + 14 else range(z.position.x + 9, z.end.x - 1, 2)
		for x in xs:
			if game.build_tower(str(list[i % 6]), Vector2i(x, row)):
				i += 1
	game.gold = 180
	if opts.has("bauen"):
		game.start_placement(str(list[int(opts.bauen) - 1]))
	if opts.has("auswahl") and not game.own_towers().is_empty():
		game._select(game.own_towers()[3])
	if opts.get("phase", "bau") == "welle":
		game.submit({"type": "start_level"})
		Engine.time_scale = 2.0
		await _frames(int(float(opts.get("warten", "6")) * 60 / 2.0))
		Engine.time_scale = 1.0
	await _frames(5)


## eeveTD: kleines Labyrinth aus Barrikaden vor dem Eingang, einige davon zu Towern aufgewertet.
## --phase=welle startet Level 1, --auswahl wählt einen Tower aus.
## --fallen: dazu Feuer 4 mit einem Flammenrost auf dem Weg und ein Dual-Tower (Feuerbeerenstrauch, Feld 32,68),
## --auswahl wählt ihn.
func _prepare_eeve(game: Node) -> void:
	game.gold = 3000
	game.lumber = 2
	game.points = 6
	var points := ["nature", "nature", "nature", "fire", "fire", "storm"]
	if opts.has("fallen"):
		game.points = 8
		game.gold = 6000
		points += ["fire", "fire"]
	for el in points:
		game.add_element_point(el)
	if opts.has("bonusfelder"):
		game.rng.seed = 5
		game._place_bonus_tiles(15)
		for c in [Vector2i(44, 76), Vector2i(50, 76), Vector2i(40, 68), Vector2i(48, 68), Vector2i(54, 68), Vector2i(36, 76)]:
			game.bonus_tiles.erase(c)
		game.bonus_tiles[Vector2i(44, 76)] = "lava"
		game.bonus_tiles[Vector2i(50, 76)] = "ice"
		game.bonus_tiles[Vector2i(40, 68)] = "marble"
		if opts.has("bonusreihe"):   # je eine Sorte nebeneinander zwischen den Mauern (Aussehen prüfen)
			game.bonus_tiles = {Vector2i(40, 72): "lava", Vector2i(44, 72): "ice", Vector2i(48, 72): "marble"}
		game.bonus_view.show_tiles(game.bonus_tiles)
	# Zwei versetzte Mauern vor dem Eingang (unten Mitte), Gegner laufen im Bogen herum
	var walls := []
	for x in range(30, 58, 2):
		walls.append(Vector2i(x, 76))
	for x in range(32, 60, 2):
		walls.append(Vector2i(x, 68))
	for c in walls:
		game.build_barricade(c)
	var plan := {Vector2i(36, 76): ["eeve_nature_base_tower", "eeve_thorns_tower"], Vector2i(44, 76): ["eeve_fire_base_tower", "eeve_camp_fire", "eeve_brazier"],
			Vector2i(50, 76): ["eeve_storm_base_tower", "eeve_storm_lantern"], Vector2i(40, 68): ["eeve_nature_base_tower", "eeve_orb_of_life"],
			Vector2i(48, 68): ["eeve_fire_base_tower", "eeve_heat_stakes", "eeve_searing_totem"], Vector2i(54, 68): ["eeve_nature_base_tower", "eeve_minor_bird_launcher"]}
	if opts.has("vitrine"):
		plan = _eeve_vitrine(game, walls)
	if opts.has("grundtower"):
		game.points += 1
		game.add_element_point(str(opts.grundtower))
		for c in plan:
			plan[c] = ["eeve_%s_base_tower" % opts.grundtower]
	for c in plan:
		var t: Tower = game.towers.get(c)
		if t == null:
			continue
		for id in plan[c]:
			var opts: Array = game.tower_options(t)
			var i: int = opts.map(func(o): return o.id).find(id)
			if i >= 0:
				game._apply_option(t, opts[i])
	if opts.has("fallen"):
		var d: Tower = game.towers.get(Vector2i(32, 68))
		for id in ["eeve_dual_element_base_tower", "eeve_fire_berry_bush"]:
			var o: Array = game.tower_options(d)
			game._apply_option(d, o[o.map(func(x): return x.id).find(id)])
		game.lumber = 2
		# Falle auf den Weg zwischen den beiden Mauern
		var path := Array(game.pathfinder.compute_path())
		path.sort_custom(func(a, b): return a.distance_to(Vector2(42, 72)) < b.distance_to(Vector2(42, 72)))
		for p in path:
			if game.build_trap("eeve_flame_grate", Vector2i(p) - Vector2i.ONE):
				break
	if opts.has("items"):
		var m: Tower = game.towers.get(Vector2i(32, 76))
		var mo: Array = game.tower_options(m)
		game._apply_option(m, mo[mo.map(func(x): return x.id).find("eeve_marketplace")])
		var h: Tower = game.towers.get(Vector2i(44, 76))
		h.set_tower("eeve_hell_brazier", 0)
		h.items = ["glowing_blade", "orb_fire"]
		for id in ["razorblades", "sleeve_speed", "killer_claws", "orb_ice", "xp_potion", "expansion"]:
			game.ep().items.append(id)
		game.ep().market = {"damage": 1}
		game._update_auras()
		if opts.has("lagerwahl"):
			game.items_panel.picked = int(opts.lagerwahl)
	game.gold = 412 if not opts.has("items") else 1840
	game.log_lines = []
	game.eeve_score = {"creeps": 4180.0, "challenges": 23560.0}
	if opts.has("ende"):
		game.wave_index = 56
		game.lives = 37
		game._finish(game.Phase.VICTORY)
	if opts.get("phase", "bau") == "welle":
		game.submit({"type": "start_level"})
	if opts.has("auswahl"):
		game._select(game.towers.get(Vector2i(32, 68) if opts.has("fallen") else Vector2i(44, 76)))
	if opts.has("markt"):
		game.market_panel.open()
	var t := 0.0
	var wait := float(opts.get("warten", "1"))
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()


## YouTD: Elemente erforschen, entlang der ersten Bahnen verschiedene Tower setzen, Items ins Lager, Welle 1 läuft.
## Mit --einstellungen bleibt das Einstellungsfenster offen.
func _prepare_youtd(game: Node) -> void:
	if not game.setup_done:
		return
	for el in ["nature", "fire", "ice", "astral", "darkness", "iron", "storm"]:
		game.elements[el] = 4
	game.gold = 5000
	game.tomes = 120
	var ids := ["1", "41", "439", "474", "498", "673"]
	for el in ["fire", "ice", "astral", "darkness", "iron", "storm"]:
		var list: Array = YoutdRoll._group(true, el, "common")
		ids.append_array(list.slice(0, 2))
	if opts.has("tower"):  # --tower=1,41,…: genau diese YouTD-Tower (IDs aus data/youtd/towers.json)
		ids = Array(str(opts.tower).split(",", false))
	var x := 8
	for i in ids.size():
		var cell := Vector2i(x, 12 if i % 2 == 0 else 22)
		game.debug_place(str(ids[i]), cell)
		if i % 2 == 1:
			x += 4
	game.debug_used = false
	game.stash = YoutdRoll.with_count(game, 5)
	for id in [2, 3, 1001, 11, 12, 9]:
		var it := YtItem.make(id, game.yp())
		if it != null:
			game.stash_add(it)
	# ein Item im ausgewählten Tower, damit Auswahlkarte Items und Effekte zeigt
	var sel = game.towers.get(Vector2i(12, 12))
	if sel != null and not game.item_stash.is_empty():
		game.put_item(sel, game.item_stash.size() - 1)
		# zwei Öle (verbraucht, „▲ Öle“ neben dem Namen) und eines im Lager
		var oils: Array = YoutdData.items().keys().filter(func(id): return YoutdData.item(id).type == "oil")
		for k in 3:
			var o := YtItem.make(int(oils[k * 3]), game.yp())
			game.stash_add(o)
			if k < 2:
				game.put_item(sel, game.item_stash.size() - 1)
	game._note(game.tr("Gewürfelt: %s") % "Tiny Shrub, Small Cactus")
	game.submit({"type": "next_wave"})
	Engine.time_scale = 8.0
	for i in 40:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	if opts.has("auswahl"):
		game._select(game.towers.get(Vector2i(12, 12)))
	if game.youtd_panel != null:
		game.youtd_panel.close_windows()
		for w in [["rezepte", "recipes"], ["elemente", "elements"]]:
			if opts.has(w[0]):
				game.youtd_panel.open_window(w[1])
	game._refresh_hud()
	await _frames(3)


## --treffer: warten, bis ein Treffer leuchtet. Die Spielzeit läuft dabei langsam (Xvfb rendert nur wenige
## Bilder pro Sekunde, sonst wäre der Treffer schon vorbei); --treffer=0.1 = so viele Sekunden danach.
func _wait_hit(game: Node) -> void:
	var fx: FxPlayer = game.effects.fx
	Engine.time_scale = 0.05
	var t := 0.0
	while fx.lights_active() == 0 and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time() / Engine.time_scale
	var after := float(opts.treffer) if str(opts.treffer) != "1" else 0.08
	var waited := 0.0
	while waited < after:
		await get_tree().process_frame
		waited += get_process_delta_time()
	print("TREFFER Lichter=%d nach %.1f s" % [fx.lights_active(), t])


## Setzt Gems nahe am Weg, bis die Runde voll ist (wanted: "id:stufe" je Gem, Rest zufällig).
func _place_round(game: Node, wanted: Array) -> void:
	var tries := 0
	while game.phase == game.Phase.BUILD and tries < 5000:
		tries += 1
		var n: int = game.round_towers.size()
		game.debug_tower = wanted[n] if n < wanted.size() else ""
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.place_gem(c)
	game.debug_tower = ""


func _camera(game: Node, w: String) -> void:
	var rig: CameraRig = game.camera_rig
	rig.frame_map(game.map.width * Board3D.CELL, game.map.height * Board3D.CELL)
	match w:
		"oben":
			rig.pitch = deg_to_rad(-89.0)
			rig.yaw = 0.0
		"seite":
			rig.pitch = deg_to_rad(-25.0)
			rig.yaw = deg_to_rad(35.0)
			rig.distance *= 0.8
		"nah":
			rig.pitch = deg_to_rad(-50.0)
			rig.distance = 14.0
			var focus := Vector2.ZERO
			if opts.has("punkt"):
				var p := String(opts.punkt).split(",")
				focus = Vector2(int(p[0]), int(p[1])) * Board3D.CELL
			elif opts.has("gegner") and not game.enemies.is_empty():
				Engine.time_scale = 0.0  # Bild anhalten, sonst läuft der Gegner bis zur Aufnahme aus dem Bild
				focus = game.enemies[0].pos
				rig.distance = 9.0
			elif not game.towers.is_empty():
				focus = Board3D.footprint_center(game.towers.values()[0].cell)
			rig.target = Board3D.to_3d(focus)
		_:
			pass
	if w != "nah" and opts.has("punkt"):
		var p := String(opts.punkt).split(",")
		rig.target = Board3D.to_3d(Vector2(int(p[0]), int(p[1])) * Board3D.CELL)
	rig.limit_view = not opts.has("frei")
	if opts.has("abstand") and w != "nah":
		rig.distance = CameraRig.MAX_DISTANCE if str(opts.abstand) == "max" else float(opts.abstand)
	rig._clamp_target()
	rig._apply()


## Maus auf das Feld aus --baufeld stellen, das Spiel setzt die Bauvorschau dann selbst.
func _mouse_to_cell(node: Node) -> void:
	var xy := String(opts.baufeld).split(",")
	var p := Board3D.to_3d(Vector2(float(xy[0]) + 0.5, float(xy[1]) + 0.5) * Board3D.CELL)
	await _frames(2)
	var vp := get_viewport()
	Input.warp_mouse(vp.get_screen_transform() * node.camera_rig.camera.unproject_position(p))
	await _frames(2)


## Level-System fürs Bild: EP setzen, Beispiel-Freischaltungen, Level-Tooltip offen neben dem Kills-Feld.
func _level_shot(game: Node) -> void:
	if game.selected == null or not opts.has("ep"):
		return
	if opts.has("level_demo"):
		var mode := Leveling.mode_profile_id(game.profile_mode())
		Database.leveling.profiles[mode]["unlocks"] = [{"level": 3, "stat": "range", "value": 0.1},
			{"level": 5, "ability": {"type": "crit", "chance": 0.15, "multiplier": 2.0}}]
		Leveling.reset()
		game.selected.set_tower(game.selected.tower_id, game.selected.tier)
		game.selected.set_selected(true)
	game.selected.kills = int(float(opts.ep))
	game.selected.set_ep(float(opts.ep))
	game._refresh_hud()
	await get_tree().process_frame
	if not opts.has("leveltip"):
		return
	var hud = game.hud
	var tip: Control = hud._kills_tooltip()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", hud.info_kills.get_theme_stylebox("panel", "TooltipPanel"))
	box.add_child(tip)
	hud.add_child(box)
	await get_tree().process_frame
	var r: Rect2 = hud.info_kills.get_global_rect()
	box.position = Vector2(r.position.x, r.position.y - box.size.y - 6)


## --aufstieg=N: Aufstiegsstufen bis +N in allen Modi frei (nur im Speicher), N gewählt, höchste Schwierigkeit vorausgewählt.
func _ascension(n: int) -> void:
	for m in Profile.MODES:
		Profile.progress(m).ascension = {"unlocked": n, "best": n - 1}
		Session.ascension_choice[m] = n
	Session.difficulty = Ascension.top("gemtd", Session.DIFFICULTIES.size())
	Session.eeve_choice = {"difficulty": Ascension.top("eeve", Ascension.difficulty_count("eeve"))}
	var rg: Dictionary = Session.rg_choice.duplicate()
	rg.difficulty = Ascension.top("randgruppen", Ascension.difficulty_count("randgruppen"))
	Session.rg_choice = rg
	Session.set_meta("youtd_choice", {"difficulty": Ascension.top("youtd", Ascension.difficulty_count("youtd"))})
	Session.maul_choice = {"difficulty": Ascension.top("maul", Ascension.difficulty_count("maul"))}
