extends Node
## Lauf: einzeln (Name heroesexplore)
## Modi: heroes
## Erkundungsrast, geheime Zugänge, Rätsel, Beute und Koop-Zustandsvertrag.

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func _ready() -> void:
	Session.coop = {}
	Session.skip_setup = true
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.bot = true
	game.force_hero = "torvik"
	game.persist_settings = false
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.spawn_queue.clear()
	game.systems.erase("timed_events")
	game.hero.auto_attack = false
	game.imprint_claimed = [10,20,30,40]
	await get_tree().process_frame
	await get_tree().process_frame
	_test_ui(game)
	_test_map_markers(game)
	await _test_map_zoom(game)
	_test_selection(game)
	check(game.exploration.select_sites(_fixture_ids()), "Testpartie verwendet acht bestimmte aktive Fundorte")
	_test_break(game)
	_test_nature(game)
	_test_streets(game)
	_test_city(game)
	_test_layout(game)
	_test_foothills(game)
	_test_terrain_effects(game)
	_test_passages(game)
	_test_secrets(game)
	_test_network(game)
	game.queue_free()
	await get_tree().process_frame
	print("Erkundung: %d Prüfungen, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _clear_wave(game: HdGame) -> void:
	game.spawn_queue.clear()
	for enemy in game.enemies:
		enemy.dead = true
		enemy.queue_free()
	game.enemies.clear()


func _test_break(game: HdGame) -> void:
	game.wave = 10
	game.wave_time = game.wave_len(10)
	var foe: HdEnemy = game.spawn(str(game.cfg.waves.list[0].groups[0][0]))
	game.start_wave(11)
	check(game.wave == 10 and not game.exploration.active, "Welle elf wartet auch vor der Rast auf übrige Gegner")
	game.step(.1)
	check(game.wave == 10 and not game.exploration.active, "Keine automatische Folgewelle vor vollständigem Abschluss der zehnten")
	foe.dead = true
	_clear_wave(game)
	game.step(.1)
	check(game.exploration.active and game.wave == 10 and is_equal_approx(game.exploration.remaining,300.0), "Nach freier zehnter Welle beginnt volle fünfminütige Rast")
	check(game.can_call_early(), "Aktive Erkundungsrast kann bewusst vorzeitig beendet werden")
	game.start_wave(11)
	check(game.wave == 10, "Direkter Wellenstart überspringt aktive Rast nicht")
	var before_clock := game.wave_time
	var before_play := game.play_time
	game.hero.position = Vector3(0,0,10)
	game.hero.move_dir = Vector3.RIGHT
	var before_pos := game.hero.position
	game.step(1.0)
	check(is_equal_approx(game.wave_time,before_clock) and game.play_time > before_play, "Wellenzeit hält an, Spielsimulation läuft weiter")
	check(game.hero.position.distance_to(before_pos) > .1, "Held kann sich während der Erkundungspause bewegen")
	game.hero.move_dir = Vector3.ZERO
	var before_rest: float = game.exploration.remaining
	game.paused = true
	game.step(5)
	check(is_equal_approx(game.exploration.remaining,before_rest), "Manuelle Pause friert auch den Erkundungszähler ein")
	game.paused = false
	game.step(before_rest-.1)
	check(game.exploration.active and game.wave == 10, "Rast endet nicht vor Ablauf der 300 Sekunden")
	game.step(.2)
	check(not game.exploration.active and game.exploration.completed == 10 and game.wave == 11, "Nach Ablauf setzt die nächste Welle fort")
	_clear_wave(game)
	game.wave = 10
	game.wave_time = 0
	game.step(.1)
	check(not game.exploration.active, "Ein abgeschlossener Meilenstein löst nicht doppelt aus")
	game.wave = 20
	game.step(.1)
	check(game.exploration.active and game.can_call_early(), "Auch die zweite Rast bietet einen vorzeitigen Start an")
	game.call_early()
	check(not game.exploration.active and game.exploration.completed == 20 and game.wave == 21, "Expliziter Früher-Rufen-Befehl beendet die Rast und startet Welle einundzwanzig")
	_clear_wave(game)
	game.wave = 40
	game.wave_time = 0
	game.step(.1)
	check(game.exploration.active and not game.final.active, "Auch nach Welle vierzig wartet das Endgebiet auf die Erkundungspause")
	# Andere Prüfungen bleiben auf der Hauptkarte; die Finale-Suite prüft den Gebietseintritt.
	game.exploration.active = false
	game.exploration.completed = 40
	game.wave = 11
	game.wave_time = 0


func _test_nature(game: HdGame) -> void:
	var plants: Node3D=game.get_node("Atmosphere/UndergrowthPatches")
	check(int(plants.get_meta("plant_count"))>600,"Gemischtes Unterholz verteilt viele Pflanzen in Gruppen")
	check(int(plants.get_meta("triangle_budget"))<350000,"Unterholz hält das Gesamtbudget von 350k Dreiecken ein")
	check(plants.get_children().all(func(node):return node is MultiMeshInstance3D and node.visibility_range_end>0 and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Pflanzen verwenden räumlich begrenzte MultiMeshes ohne Schatten")
	check(plants.find_children("*","CollisionObject3D",true,false).is_empty(),"Unterholz besitzt keine Physikobjekte")
	check(plants.get_children().all(func(node):return maxf(node.get_aabb().size.x,node.get_aabb().size.z)<35),"Flache Pflanzen werden nach Breite begrenzt und überdecken keine halbe Karte")
	var birds=game.get_node("Atmosphere/OverheadBirdLayer/OverheadBirds")
	birds.begin_flock()
	check(birds._flock.size()<=6 and birds.altitude>=50 and birds.altitude<=100,"Höchstens sechs visuelle Vögel in gedachter Höhe von 50–100 Metern")
	game.paused=true
	var age: float=birds._age
	birds._process(1.0)
	check(birds._age==age,"Pause hält den Vogelflug an")
	game.paused=false
	var sound: HdSoundscape=game.get_node("Soundscape")
	check(sound._crow.bus==Sfx.BUS_AMB and sound._crow_calls.size()==3,"Drei Krähenrufe nutzen den Ambience-Regler")

	var roots: Array=game.get_meta("vegetation_ground_roots",[])
	var texture: Texture2D=game.get_meta("vegetation_ground_texture")
	var mask := texture.get_image()
	var bounds: Rect2=game.get_meta("vegetation_ground_bounds")
	var covered := true
	for root in roots:
		var pixel: Vector2=(Vector2(root.pos.x,root.pos.z)-bounds.position)/bounds.size*Vector2(mask.get_size())
		if not Rect2(Vector2.ZERO,Vector2(mask.get_size())).has_point(pixel):
			covered=false
			continue
		var color := mask.get_pixel(int(pixel.x),int(pixel.y))
		if color.r+color.g<.9:covered=false
	check(roots.size()>int(plants.get_meta("plant_count")),"Bodenmaske enthält Pflanzen und sämtliche Baumgruppen")
	check(covered,"Alle registrierten Pflanzenwurzeln einschließlich äußerem Waldrand liegen auf Erde oder Gras")
	var floor_mat: ShaderMaterial=game.get_node("MainTerrainGround").material_override
	var mountain_mat: ShaderMaterial=game.get_node("MixedBoundaries/OuterMountainBoundaries/ContinuousBasaltMountains").material_override
	check(floor_mat.get_shader_parameter("vegetation_mask")==texture and mountain_mat.get_shader_parameter("vegetation_mask")==texture,"Boden und Berghänge verwenden dieselbe Bewuchsmaske")


func _test_streets(game: HdGame) -> void:
	var streets: Node3D=game.get_node("Atmosphere/SettlementWalkways")
	var paths: Array=streets.get_meta("paths",[])
	check(paths.size()>=15,"Siedlungsgebäude erhalten zusammenhängende lokale Gehwege")
	var separated := true
	for path in paths:
		var lane_access: bool=game.get_meta("settlement_city_access",[]).has(path)
		for i in path.size()-1:
			var a: Vector3=path[i]
			var b: Vector3=path[i+1]
			for step in ceili(a.distance_to(b))+1:
				var at := a.move_toward(b,float(step))
				at.y=0
				if (not lane_access and game.arena_layout.inside(at,-.4)) or game.arena_layout.divider_distance(at)<4 or HdExplorationLayout.clearance(at)<3.49:separated=false
	check(separated,"Nur ausgewiesene Stadtzugänge münden in Lanes; Trennmauern und Secrets bleiben frei")
	var positions: Array=game.get_node("Atmosphere/UndergrowthPatches").get_meta("plant_positions",[])
	var clear := true
	for at: Vector3 in positions:
		for path in paths:
			for i in path.size()-1:
				var a: Vector3=path[i]
				var b: Vector3=path[i+1]
				var closest := Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),Vector2(a.x,a.z),Vector2(b.x,b.z))
				if closest.distance_to(Vector2(at.x,at.z))<1.64:clear=false
	check(clear,"Neue Pflanzenpatches lassen die Gehwege frei")
	var atmosphere: HdAtmosphere=game.get_node("Atmosphere")
	var lamps: Array=atmosphere.get_meta("street_lantern_positions",[])
	check(lamps.size()>0 and atmosphere._lamps.size()<=8,"Straßenlaternen nutzen den vorhandenen begrenzten Lichtpool")
	var grounded := true
	for at: Vector3 in lamps:
		if absf(at.y-HdArenaMountains.ground_height(game.arena_layout,at))>.01:grounded=false
	check(grounded,"Straßenlaternen stehen auch auf Hängen auf dem Boden")
	var plants: Node3D=game.get_node("Atmosphere/UndergrowthPatches")
	check(plants.get_meta("courtyard_islands",[]).size()>0,"Freie Inseln zwischen Gehwegen werden gezielt bepflanzt")
	var trees: Node3D=game.get_node("Atmosphere/CourtyardTrees")
	var tree_positions: Array=trees.get_meta("tree_positions",[])
	check(tree_positions.size()>0 and tree_positions.size()<=14 and int(trees.get_meta("triangle_budget",0))<50000,"Kleine Hofbäume bleiben statisch und innerhalb des Geometriebudgets")
	var trees_clear := true
	var sites: Array=game.get_node("SchwarzeKathedrale").get_meta("street_sites",[])
	for at: Vector3 in tree_positions:
		if preload("res://scripts/heroes/hd_settlement_streets.gd").distance(game,at)<3.6:trees_clear=false
		for site in sites:
			if (site.door as Vector3).distance_to(Vector3(at.x,0,at.z))<6:trees_clear=false
	check(trees_clear,"Baumkronen und Stämme halten Wege und Türvorplätze frei")
	check(streets.get_child_count()==0,"Gehwege werden ohne überlagerte Bodenplatten gebacken")
	var mask: Image=game.get_meta("vegetation_ground_texture").get_image()
	var rect: Rect2=game.get_meta("vegetation_ground_bounds")
	var covered := 0
	var samples := 0
	for path in paths:
		for i in path.size()-1:
			var a: Vector3=path[i]
			var b: Vector3=path[i+1]
			for step in ceili(a.distance_to(b))+1:
				var at := a.move_toward(b,float(step))
				var uv := (Vector2(at.x,at.z)-rect.position)/rect.size
				var pixel := mask.get_pixel(clampi(int(uv.x*mask.get_width()),0,mask.get_width()-1),clampi(int(uv.y*mask.get_height()),0,mask.get_height()-1))
				samples+=1
				if pixel.b>.65 and pixel.a>.2:covered+=1
	check(covered>samples*.98,"Bodenmaske zeichnet zusammenhängende verdichtete Gehwege an allen Routen")

func _test_city(game: HdGame) -> void:
	var layout := game.arena_layout
	var sites: Array=game.get_node("SchwarzeKathedrale").get_meta("street_sites",[])
	var houses: Array=sites.filter(func(site):return site.get("town",false))
	check(houses.size()>=60,"Zusammenhängende Wohnviertel füllen die niedrigen Stadtflächen")
	check(houses.all(func(site):return absf((site.front as Vector3).x)<.01),"Hausfassaden richten sich zu gemeinsamen Gassen statt zufällig in alle Richtungen")
	var facades := true
	for planned in game.get_node("SchwarzeKathedrale").get_meta("settlement_sites",[]):
		for site in sites:
			if (site.center as Vector3).distance_to(planned.pos)>.01:continue
			if (site.front as Vector3).dot(Vector3.BACK.rotated(Vector3.UP,float(planned.yaw)))<.99:facades=false
	check(facades,"Auch Ruineneingänge wenden sich zur gemeinsamen Straße")
	var paths: Array=game.get_meta("settlement_street_paths",[])
	var walkable := true
	for path in paths:
		for i in path.size()-1:
			var a: Vector3=path[i]
			var b: Vector3=path[i+1]
			for step in ceili(a.distance_to(b))+1:
				var at := a.move_toward(b,float(step))
				at.y=0
				if not layout.foothill(at,game.hero.radius):
					if walkable:print("STADT_GASSE_GESPERRT ",at," hoehe=",HdArenaMountains.ground_height(layout,at)," haus=",layout._city_blocked(at,game.hero.radius)," zugang=",game.get_meta("settlement_city_access",[]).has(path))
					walkable=false
	check(walkable,"Alle gezeichneten Stadtgassen sind für den Helden tatsächlich begehbar")
	var blocked := true
	var sliding := true
	for site in houses:
		var center: Vector3=site.center
		center.y=0
		if layout.foothill(center,game.hero.radius):blocked=false
		var edge := layout.constrain_hero(center,game.hero.radius)
		if not layout.foothill(edge,game.hero.radius) or edge.distance_to(center)>7:sliding=false
	check(blocked and sliding,"Hauskörper blockieren Helden und schieben sie nur bis zur nahen Fassade")
	check(game.get_meta("settlement_city_access",[]).size()>=8,"Mehrere Seitenstraßen verbinden Stadtviertel mit den Lanes")
	# Flächen-Flutfüllung prüft die wirkliche Heldenkontur, nicht nur den Weg-Graphen.
	var open := {}
	var reached := {}
	var queue: Array[Vector2i]=[]
	for z in range(-92,93):
		for x in range(-92,93):
			var at := Vector3(x*2,0,z*2)
			if not layout.foothill(at,game.hero.radius):continue
			var cell := Vector2i(x,z)
			open[cell]=true
			if layout.inside(at,game.hero.radius):
				reached[cell]=true
				queue.append(cell)
	var head := 0
	while head<queue.size():
		var cell := queue[head]
		head+=1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+direction
			if not open.has(next) or reached.has(next):continue
			var middle := Vector3(cell.x+next.x,0,cell.y+next.y)
			if not layout.foothill(middle,game.hero.radius):continue
			reached[next]=true
			queue.append(next)
	var accessible := 0
	for site in houses:
		var approach: Vector3=site.approach
		var cell := Vector2i(roundi(approach.x/2),roundi(approach.z/2))
		if reached.has(cell):accessible+=1
	print("STADTLAUFTEST Häuser=%d erreichbar=%d freieZellen=%d verbunden=%d" % [houses.size(),accessible,open.size(),reached.size()])
	check(accessible==houses.size(),"Jede bewohnte Häuserzeile ist über echte freie Bodenflächen von einer Lane erreichbar")
	var separated := true
	var bounds: Array=game.cfg.arena.bounds
	for divider in layout.dividers:
		var start: Vector3=divider[0]
		if not (is_equal_approx(start.x,float(bounds[0])) or is_equal_approx(start.x,float(bounds[2])) or is_equal_approx(start.z,float(bounds[1])) or is_equal_approx(start.z,float(bounds[3]))):separated=false
		for meter in ceili(start.distance_to(divider[1]))+1:
			if layout.foothill(start.move_toward(divider[1],float(meter)),game.hero.radius):separated=false
	check(separated,"Lane-Trennungen reichen ohne umgehbare Lücke vom Kartenrand bis zum gemeinsamen Knoten")


func _test_layout(game: HdGame) -> void:
	check(HdExplorationLayout.PATH_WIDTH<=1.8,"Secret-Pfade bleiben schmale Trampelpfade")
	var cover := HdExplorationLayout.concealment(game.arena_layout)
	check(cover.size()>100,"Waldsäume verbergen die Nebenpfade an mehreren Stellen")
	var free_paths := true
	for piece in cover:
		if HdExplorationLayout.clearance(piece.pos)<.3 or piece.pos.distance_to(game.arena_layout.nearest(piece.pos))<3.7:free_paths=false
	check(free_paths,"Sichtschutz hält alle Laufkonturen einschließlich benachbarter Lanes frei")
	check(HdExplorationLayout.sites().size() == 30 and HdExplorationLayout.rooms().size() == 30, "Dreißig verschiedene geheime Fundorte besitzen getrennte Höhlenräume")
	check(game.exploration.sites.size() == 8 and game.exploration.points.size() == 8, "Pro Partie sind genau acht Fundorte aktiv")
	for path in HdExplorationLayout.paths():
		var clear := true
		var entry: Vector3 = path[0]
		check(entry.distance_to(game.arena_layout.nearest(entry))<.01, "Nebenpfad ist mit einer vorhandenen Lane verbunden")
		for index in path.size()-1:
			var a: Vector3 = path[index]
			var b: Vector3 = path[index+1]
			for meter in ceili(a.distance_to(b))+1:
				if not game.arena_layout.inside(a.move_toward(b,float(meter)),game.hero.radius):
					clear = false
		check(clear, "Geheimweg besitzt eine durchgehend begehbare Kontur")
	for site in HdExplorationLayout.sites():
		check(game.arena_layout.inside(site.pos,game.hero.radius), "Versteckter Eingang erreichbar: "+str(site.id))
		game.hero.position = site.cave
		game._resolve(game.hero)
		check(game.hero.position.distance_to(site.cave)<.1, "Höhlenraum wird nicht an die Hauptkartengrenze geklemmt: "+str(site.id))
		check(game.arena_layout.inside(site.return_pos,game.hero.radius), "Rückweg aus der Höhle begehbar: "+str(site.id))
		for clue in site.clues:
			check(game.arena_layout.inside(clue,game.hero.radius), "Hinweis liegt auf begehbarem Geheimweg: "+str(site.id))
	var rooms: Array = HdExplorationLayout.rooms()
	var separated := true
	for i in rooms.size():
		for j in range(i+1,rooms.size()):
			if rooms[i].center.distance_to(rooms[j].center)<float(rooms[i].radius)+float(rooms[j].radius):
				separated = false
	check(separated, "Alle dreißig Höhlen sind räumlich voneinander getrennt")
	game.hero.position = game.hero_spawn()


func _test_passages(game: HdGame) -> void:
	var ex: HdExploration=game.exploration
	var saved: Dictionary=ex.points.duplicate(true)
	var position: Vector3=game.hero.position
	var geometry: Node3D=game.get_node("ExplorationCaverns")
	check(geometry.get_children().filter(func(child):return child.has_meta("entrance_kind")).size()==30,"Alle dreißig Secrets besitzen eine Höhlen- oder Gebäudehülle")
	var settlements: Array=game.get_node("SchwarzeKathedrale").get_meta("settlement_sites",[])
	print("SIEDLUNG ",settlements.size()," zusätzliche Gebäude und Ruinen")
	check(settlements.size()>=12,"Freie Flächen tragen zusätzliche Gebäude und Ruinen")
	check(settlements.all(func(site):return not game.arena_layout.inside(Vector3(site.pos.x,0,site.pos.z),-5.0)),"Siedlungsdetails halten die Laufwege frei")
	for site in ex.sites:
		var state: Dictionary=ex.points[str(site.id)]
		state.open=false
		ex._passage_until.clear()
		game.hero.position=site.pos+Vector3(0,0,2.5)
		ex._step_passage()
		check(game.hero.position.distance_to(site.pos)<4,"Außerhalb der Türschwelle erfolgt kein Teleport")
		game.hero.position=site.pos
		ex._step_passage()
		if str(site.gate)!="hidden":
			check(game.hero.position.distance_to(site.pos)<.01,"Runen und Spuren bleiben vor dem Öffnen verschlossen")
			state.open=true
			ex._step_passage()
		check(game.hero.position.distance_to(site.cave+Vector3(0,0,9))<.01,"Hineinlaufen führt in den separaten Secret-Raum: "+str(site.id))
		ex._step_passage()
		check(game.hero.position.distance_to(site.cave)<16,"Ankunft löst keinen sofortigen Rückteleport aus")
		ex._passage_until.clear()
		game.hero.position=site.cave+Vector3(0,0,13)
		ex._step_passage()
		check(game.hero.position.distance_to(site.return_pos)<.01,"Hinauslaufen führt zum versteckten Eingang zurück")
	ex.points=saved
	ex._passage_until.clear()
	game.hero.position=position


func _fixture_ids() -> Array:
	return ["resources","items","buff","towers","boss","cache","eisgrab","glutfalte"]


func _test_ui(game: HdGame) -> void:
	var icons = preload("res://scripts/heroes/hd_item_icons.gd")
	for item in Database.load_json("res://data/heroes_items.json").items:
		check(icons.texture(str(item.id)) != null,"Vorhandenes 2D-Icon für "+str(item.id))
	var hud: HdHud = game.hud
	check(hud.minimap.terrain_texture!=null,"Minimap besitzt eine gerasterte Geländeansicht")
	var terrain_before: Texture2D = hud.minimap.terrain_texture
	hud.minimap.queue_redraw()
	var image := terrain_before.get_image()
	var colors := {}
	for y in range(0,image.get_height(),8):
		for x in range(0,image.get_width(),8):colors[image.get_pixel(x,y).to_html()]=true
	check(colors.size()>40,"Geländekarte unterscheidet Höhen, Fels und Vegetation")
	var terrain = preload("res://scripts/heroes/hd_minimap_terrain.gd")
	var bounds := Rect2(-192,-192,384,384)
	var hidden: Image = terrain.hidden_mask(bounds,[])
	var all_ids: Array = HdExplorationLayout.sites().map(func(site):return str(site.id))
	var known: Image = terrain.hidden_mask(bounds,all_ids)
	var at: Vector3 = HdExplorationLayout.sites()[0].pos
	var pixel: Vector2 = terrain._pixel(at,bounds)
	check(hidden.get_pixel(int(pixel.x),int(pixel.y)).r>.5 and known.get_pixel(int(pixel.x),int(pixel.y)).r<.5,"Unentdeckte Zugänge werden im Gelände kaschiert, entdeckte freigelegt")
	check(hud.minimap.get_rect().end.y<hud._vitals_panel.position.y,"Minimap lässt die Heldenwerte frei")
	check(hud._skills_panel.get_rect().end.y<=get_viewport().get_visible_rect().size.y-30,"Fähigkeiten samt Banner bleiben vollständig über dem unteren Bildschirmrand")
	game.hero.skills.points=1
	hud.refresh()
	hud._position_upgrades()
	for slot in hud._slots:
		check(slot.name.get_global_rect().end.y<=slot.panel.global_position.y,"Fähigkeitsname steht im Banner über dem Iconrahmen")
		check(slot.cd.get_global_rect().end.y<=slot.panel.global_position.y,"Mana und Abklingzeit verdecken die Metallbeschläge nicht")
		check(slot.glyph.texture!=null and slot.glyph.size.x>=slot.panel.size.x*.65,"Eigenes Fähigkeitssymbol füllt den Rahmen großflächig")
		check(slot.glyph.material==HdUiStyle.icon_metal_material() and slot.glyph.material.get_shader_parameter("metal_surface")==1.0,"Fähigkeitssymbole sind als Metallbeschläge auf dem Leder ausgeführt")
		if slot.plus == null:continue
		check(slot.plus.get_global_rect().end.y<hud._skills_panel.global_position.y,"Upgrade-Plus schwebt über der Leiste")
		check(slot.plus.visible==game.hero.skills.can_upgrade(hud._slots.find(slot)),"Plus nur für tatsächlich aufwertbare Fähigkeiten")
	game.hero.skills.points=0
	var ability_icons=preload("res://scripts/heroes/hd_ability_icons.gd")
	var catalog: Dictionary=Database.load_json("res://data/heroes_helden.json")
	for hero in catalog.heroes:
		for ability in hero.abilities:
			check(ability_icons.texture(str(ability.id))!=null,"Passendes Vektorsymbol vorhanden: "+str(ability.name))
	for id in catalog.gadgets:
		check(ability_icons.texture(ability_icons.key("zix",{"gadget":id},0))!=null,"Zix-Gerät erhält ein eigenes Symbol: "+str(id))


func _test_map_markers(game: HdGame) -> void:
	var minimap: Control = game.hud.minimap
	var enemy: HdEnemy = game.spawn("sumpfling",Vector3(10,0,12))
	check(minimap.map_markers().any(func(m):return m.kind=="enemy" and m.pos==enemy.position),"Normale Gegner erscheinen auf der Karte")
	enemy.rank="boss"
	enemy.immortal=true
	check(not minimap.enemy_available(enemy),"Unverwundbarer Boss erscheint noch nicht")
	enemy.immortal=false
	check(minimap.map_markers().any(func(m):return m.kind=="boss" and m.pos==enemy.position),"Bekämpfbarer Boss erhält einen eigenen Marker")
	enemy.hide()
	check(not minimap.enemy_available(enemy),"Verborgener Boss wird nicht durch die Minimap verraten")
	enemy.show()
	game.event_arena.active=true
	game.event_arena.visibility[enemy]=true
	check(not minimap.enemy_available(enemy),"Eingefrorener Boss außerhalb der Ereignisarena bleibt verborgen")
	game.event_arena.active=false
	game.event_arena.visibility.erase(enemy)
	enemy.dead=true
	check(not minimap.enemy_available(enemy),"Besiegter Boss verschwindet von der Karte")
	game.enemies.erase(enemy)
	enemy.queue_free()
	var ally := HdAlly.new()
	ally.setup_ally(game,{"name":"Test","hp":100},"fighter",Vector3(14,0,10))
	game.add_child(ally)
	game.buildings.append(ally)
	check(not minimap.map_markers().any(func(m):return m.pos==ally.position),"Begleiter werden auf der Minimap nicht angezeigt")
	ally.destroyed=true
	check(not minimap.map_markers().any(func(m):return m.kind=="friend" and m.pos==ally.position),"Besiegte Begleiter werden nicht weiter markiert")
	game.buildings.erase(ally)
	ally.queue_free()
	check(minimap.map_markers().any(func(m):return m.kind=="building" and m.pos==game.fortress_pos),"Die Feste ist als Gebäude erkennbar")
	check(minimap.map_markers().any(func(m):return m.kind=="self" and m.pos==game.hero.position),"Eigener Held besitzt einen separaten Marker")


func _test_map_zoom(game: HdGame) -> void:
	var minimap: Control = game.hud.minimap
	var gate: HdBuilding = game.buildings[0]
	var hp_before := gate.hp
	gate.hp=gate.max_hp*.4
	var marker: Dictionary = minimap.map_markers().filter(func(m):return m.pos==gate.position)[0]
	check(is_equal_approx(float(marker.health),.4),"Gebäudemarker enthält den tatsächlichen Lebensanteil")
	check(not minimap.building_health_visible(marker),"Übersichtszoom bleibt ohne Gebäudebalken")
	var texture_before: Texture2D = minimap.terrain_texture
	var plus: Button = minimap.get_node("ZoomIn")
	var minus: Button = minimap.get_node("ZoomOut")
	check(Rect2(Vector2.ZERO,minimap.size).encloses(plus.get_rect()) and Rect2(Vector2.ZERO,minimap.size).encloses(minus.get_rect()),"Kleine Zoomknöpfe liegen unten innerhalb des Rahmens")
	var map_rect: Rect2 = minimap._map_rect()
	check(map_rect.size.is_equal_approx(minimap.size-Vector2(16,16)),"Gelände füllt den gesamten Innenrahmen ohne separate Knopfleiste")
	check(plus.get_rect().intersects(map_rect) and is_equal_approx(plus.get_rect().end.y,minimap.size.y),"Zoomknopf sitzt am unteren Rand und ragt nach innen in die Karte")
	check(minimap.get_node("MetalFrame").material==HdUiStyle.metal_material() and minimap.material==null,"Nur der Metallrahmen nutzt den gemeinsamen UI-Shader, das Gelände bleibt unverändert")
	check(game.hud._wave_panel.has_node("BollwerkMetal") and game.hud._skills_panel.has_node("BollwerkMetal"),"HUD-Leisten erhalten zentral Metallrahmen")
	check(HdUiStyle.metal_material().get_shader_parameter("palette_metal")==1.0 and HdUiStyle.GOLD==UiTheme.GOLD,"Metallmaterial verwendet weiter die bisherige Goldpalette")
	check(HdUiStyle.leather_texture()!=null,"Gewählter Lederhintergrund liegt als importiertes Projektasset vor")
	check(plus.get_theme_stylebox("normal") is HdUiStyle.MenuButtonFrame,"Minimap-Knöpfe verwenden denselben blauen Hauptmenü-Look")
	var dynamic := PanelContainer.new()
	game.hud.root.add_child(dynamic)
	await get_tree().process_frame
	await get_tree().process_frame
	check(dynamic.has_node("BollwerkMetal"),"Nachträglich geöffnete Fenster erhalten ebenfalls Metallrahmen")
	dynamic.queue_free()
	var slot: InvSlot = game.hud.econ._inv_slots[0]
	var slot_frame: Node = slot.get_node("BollwerkMetal")
	game.hud.econ._paint(slot,null,"hero",0)
	await get_tree().process_frame
	check(is_instance_valid(slot_frame) and slot.get_node("BollwerkMetal")==slot_frame,"Inventaraktualisierungen erhalten denselben Metallrahmen")
	var choice := OptionButton.new()
	choice.add_item("Test")
	game.hud.root.add_child(choice)
	await get_tree().process_frame
	await get_tree().process_frame
	check(choice.get_popup().has_node("BollwerkMetal"),"Auswahllisten erhalten auch am Popup einen Metallrahmen")
	var letters: Label=choice.get_node("BollwerkMetalText")
	check(letters.material.get_shader_parameter("text_relief")==1.0 and choice.material==null,"Reliefshader liegt ausschließlich auf der Buttonschrift")
	check(letters.text==tr(choice.text) and letters.mouse_filter==Control.MOUSE_FILTER_IGNORE and choice.get_theme_color("font_color").a==0.0,"Geprägte Beschriftung bleibt korrekt, ohne doppelten Text oder blockierte Bedienung")
	choice.queue_free()
	var tooltip := PopupPanel.new()
	tooltip.theme=game.hud.root.theme
	tooltip.theme_type_variation="TooltipPanel"
	get_tree().root.add_child(tooltip)
	await get_tree().process_frame
	await get_tree().process_frame
	check(tooltip.has_node("BollwerkMetal"),"Tooltip-Fenster außerhalb des HUD-Roots erhalten ebenfalls Metallrahmen")
	tooltip.queue_free()
	plus.pressed.emit()
	plus.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(minimap.zoom>1.5 and minimap.building_health_visible(marker),"Plus zoomt heran und blendet Gebäudebalken ein")
	check(minimap.terrain_texture==texture_before,"Minimap-Zoom verwendet dieselbe gecachte Geländetextur")
	minimap.set_zoom(100)
	check(is_equal_approx(minimap.zoom,4) and plus.disabled,"Zoom endet bei vierfacher Vergrößerung")
	minimap.set_zoom(.1)
	check(is_equal_approx(minimap.zoom,1) and minus.disabled and not minimap.building_health_visible(marker),"Herauszoomen endet bei der Übersicht und verbirgt Balken")
	gate.hp=hp_before


func _test_foothills(game: HdGame) -> void:
	var layout: HdArena = game.arena_layout
	var found := false
	for z in range(-180,181,4):
		for x in range(-180,181,4):
			var at := Vector3(x,0,z)
			var height := HdArenaMountains.ground_height(layout,at)
			if height>.01 and not layout.inside(at,game.hero.radius) and layout.foothill(at,game.hero.radius):
				found=true
				game.hero.position=at
				game._resolve(game.hero)
				check(game.hero.position.distance_to(at)<.01,"Niedriger Stadtrandhang bleibt für den Helden begehbar")
				game._process(0)
				check(is_equal_approx(game.hero._body.position.y,height),"Heldenkörper steht auf der tatsächlichen Geländehöhe")
				var lane := layout.nearest(at)
				var clipped := layout.constrain_hero(at+(at-lane).normalized()*30,game.hero.radius)
				check(layout.foothill(clipped,game.hero.radius) and clipped.distance_to(lane)>layout.width,"Hanggrenze fängt den Helden außerhalb der Lane ab")
				break
		if found:break
	check(found,"Mindestens ein sichtbarer niedriger Berghang ist erreichbar")
	for divider in layout.dividers:
		check(not layout.foothill((divider[0]+divider[1])*.5,game.hero.radius),"Trennmauer bleibt auch bei Hangfreigabe gesperrt")
	game.hero.position=game.hero_spawn()


func _test_terrain_effects(game: HdGame) -> void:
	for road: HdRoad in game.arena_layout.paths:
		for s in [0.15,0.5,0.85]:
			check(is_zero_approx(HdArenaMountains.ground_height(game.arena_layout,road.point(road.length*s))),"Monsterweg bleibt trotz Materialhügeln eben")
	check(is_zero_approx(HdArenaMountains.ground_height(game.arena_layout,game.fortress_pos+Vector3(12,0,0))),"Feste-Vorplatz bleibt eben")
	var tele := HdTelegraph.circle(5,HdTelegraph.BLUE)
	tele.position=game.hero.position
	game.add_tele(tele)
	var mat: ShaderMaterial=tele.material_override
	check(float(mat.get_shader_parameter("terrain_enabled"))>.5,"Bodenwarnung verwendet das sichtbare Höhenfeld")
	var height_texture: Texture2D=mat.get_shader_parameter("terrain_height")
	check(height_texture != null and height_texture.get_width()>100,"Höhenfeld wird einmalig als Geländetextur bereitgestellt")
	check((tele.mesh as PlaneMesh).subdivide_width>0,"Warnfläche hat Geometrie für echte Hangverformung")
	check(tele.contains(tele.position+Vector3.UP*20),"Höhenanpassung verändert die horizontale Trefferprüfung nicht")
	var heal := HdFxParts.heal_area(5)
	game.fx.add_child(heal)
	check(heal.material_override.get_shader_parameter("terrain_height")==height_texture,"Heilfläche übernimmt automatisch dieselbe Hanggeometrie")
	HdArenaMountains.conform_effect(tele,null)
	check(is_zero_approx(float(mat.get_shader_parameter("terrain_enabled"))),"Andere Arenen können die Hauptkarten-Verformung wieder deaktivieren")
	check(HdTerrain.material_masks(Vector2(-55,-55)).is_finite(),"Fels-/Erde-Höhenmaske funktioniert in negativen Weltkoordinaten")
	tele.queue_free()
	heal.queue_free()


func _test_selection(game: HdGame) -> void:
	var catalog: Array = HdExplorationLayout.sites()
	var known := {}
	for site in catalog:
		check(not known.has(str(site.id)) and not str(site.title).is_empty(), "Fundort besitzt eindeutige Kennung und eigenen Namen: "+str(site.id))
		known[str(site.id)] = true
		check(str(site.gate) in ["hunt","runes","hidden"], "Jeder Fundort verlangt einen geheimen Zugang: "+str(site.id))
		if str(site.gate) == "runes":
			var order: Array = site.order
			check(order.size()==3 and order.has(0) and order.has(1) and order.has(2), "Runenfolge enthält alle drei Siegel: "+str(site.id))
	var variations := {}
	for seed_value in 32:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var chosen: Array = HdExploration.choose_sites(rng)
		var same_rng := RandomNumberGenerator.new()
		same_rng.seed = seed_value
		check(chosen == HdExploration.choose_sites(same_rng), "Gleicher Startwert liefert dieselben acht Geheimnisse")
		var unique := {}
		var kinds := {}
		for id in chosen:
			unique[str(id)] = true
			kinds[str(_site(str(id)).kind)] = true
		check(chosen.size()==8 and unique.size()==8, "Auswahl enthält genau acht unterschiedliche Fundorte")
		check(kinds.size()==6, "Jede Partie bietet alle sechs Belohnungsarten")
		chosen.sort()
		variations[str(chosen)] = true
	check(variations.size()>1, "Verschiedene Partien verwenden unterschiedliche Fundorte")
	game.exploration.select_sites(_fixture_ids())
	var before: Array = game.exploration.active_ids.duplicate()
	check(not game.exploration.select_sites(["boss"]) and game.exploration.active_ids==before, "Ungültige Auswahl kann die Acht-Fundorte-Regel nicht verletzen")
	check(game.exploration._markers.size()==8 and game.exploration._markers.keys().all(func(id): return id in game.exploration.active_ids), "Nur die aktiven Fundorte erzeugen Hinweise und Beutemarker")
	for site in catalog:
		if str(site.id) in before:
			continue
		game.hero.position = site.pos
		check(game.exploration.nearby().is_empty(), "Inaktiver Eingang bietet keine Interaktion: "+str(site.id))
		for op in ["enter","search","clue","read","rune","summon","claim","return"]:
			game.hero.position = site.cave if op in ["summon","claim","return"] else site.pos
			check(not _act(game,str(site.id),op,0).is_empty(), "Inaktiver Fundort weist direkte Befehle ab: %s/%s" % [site.id,op])
	game.hero.position = game.hero_spawn()


func _site(id: String) -> Dictionary:
	for site in HdExplorationLayout.sites():
		if str(site.id) == id:
			return site
	return {}


func _act(game: HdGame, id: String, op: String, index := -1) -> String:
	return game.shop.act({"kind":"explore", "id":id, "op":op, "index":index})


func _test_secrets(game: HdGame) -> void:
	var ex := game.exploration
	game.hero.position = game.hero_spawn()
	check(not _act(game,"items","claim").is_empty() and not ex.points.items.claimed, "Entfernte Beute kann weder per UI noch Befehl eingesammelt werden")
	for id in ["resources","boss"]:
		var site := _site(id)
		game.hero.position = site.pos
		check(not _act(game,id,"enter").is_empty(), "Schnitzeljagd-Eingang ist vor den Hinweisen verschlossen: "+id)
		game.hero.position = site.clues[2]
		check(not _act(game,id,"clue",2).is_empty() and ex.points[id].clue == 0, "Letzter Hinweis überspringt die Schnitzeljagd nicht: "+id)
		for index in 3:
			game.hero.position = site.clues[index]
			check(_act(game,id,"clue",index).is_empty(), "Hinweis in Reihenfolge lesbar: %s/%d" % [id,index])
		check(ex.points[id].open, "Alle drei Hinweise öffnen die Höhle: "+id)
	for id in ["items","towers"]:
		var site := _site(id)
		game.hero.position = site.pos
		check(not _act(game,id,"rune",0).is_empty(), "Runen verlangen zuerst die Inschrift: "+id)
		check(_act(game,id,"read").is_empty() and ex.points[id].inspected, "Inschrift gibt tatsächlich einen Hinweis: "+id)
		_act(game,id,"rune",int(site.order[0]))
		_act(game,id,"rune",int(site.order[0]))
		check(ex.points[id].runes.is_empty() and not ex.points[id].open, "Falsche Runenfolge setzt das Rätsel zurück: "+id)
		for rune in site.order:
			_act(game,id,"rune",int(rune))
		check(ex.points[id].open, "Richtige Runenfolge öffnet Zugang: "+id)
	for id in ["buff","cache"]:
		var site := _site(id)
		game.hero.position = site.pos+Vector3.RIGHT*2.5
		check(not _act(game,id,"search").is_empty(), "Versteckter Verschluss verlangt Untersuchung aus der Nähe: "+id)
		game.hero.position = site.pos
		check(_act(game,id,"search").is_empty() and ex.points[id].open, "Versteckte Öffnung lässt sich entdecken: "+id)
	var resources := _site("resources")
	game.hero.position = resources.pos
	check(_act(game,"resources","enter").is_empty() and game.hero.position.distance_to(resources.cave)<16.0, "Entriegelter Eingang teleportiert wirklich in die separate Höhle")
	game.hero.position = resources.cave
	var gold_before: int = game.shop.gold
	var wood_before: int = game.shop.wood
	check(_act(game,"resources","claim").is_empty() and game.shop.gold>gold_before and game.shop.wood>wood_before, "Bergwerkslager gibt echte Ressourcen")
	gold_before = game.shop.gold
	check(not _act(game,"resources","claim").is_empty() and game.shop.gold==gold_before, "Wiederholtes Bergen dupliziert keine Belohnung")
	game.hero.position = resources.cave+Vector3(0,0,13)
	check(_act(game,"resources","return").is_empty() and game.hero.position.distance_to(resources.return_pos)<.1, "Rückweg bringt den Helden wieder zum Hauptkarten-Eingang")
	var stash_before: int = game.shop.count_free("stash")
	game.hero.position = _site("items").cave
	check(_act(game,"items","claim").is_empty() and game.shop.count_free("stash")<stash_before, "Krypta legt ein benutzbares Item ins bestehende Lager")
	game.hero.position = _site("buff").cave
	var damage_before := game.hero.out_mult()
	var speed_before := game.hero.speed_mult()
	check(_act(game,"buff","claim").is_empty() and game.hero.out_mult()>damage_before and game.hero.speed_mult()>speed_before, "Mondquelle verstärkt echten Schaden und Bewegung")
	game.hero.position = _site("towers").cave
	var tower: HdBuilding = game.buildings.filter(func(building): return building.road != null)[0]
	var tower_before := tower.out_mult()
	check(_act(game,"towers","claim").is_empty() and is_equal_approx(tower.out_mult(),tower_before*1.35), "Werkstatt erhöht den tatsächlichen Turm-Schadensfaktor um 35 Prozent")
	var boss_site := _site("boss")
	game.hero.position = boss_site.cave
	check(not _act(game,"boss","claim").is_empty(), "Bossbeute bleibt vor dem Sieg gesperrt")
	var waves_before := game.wave_enemies()
	check(_act(game,"boss","summon").is_empty(), "Geheime Gruft beschwört einen echten Wächter")
	var foes: Array = game.enemies.filter(func(enemy): return not enemy.dead and enemy.zone == "explore_boss")
	check(foes.size()==1 and game.wave_enemies()==waves_before, "Höhlenwächter ist vom normalen Wellenabschluss getrennt")
	if not foes.is_empty():
		check(foes[0].def.abilities.size()>=3, "Höhlenboss verfügt über mehrere Angriffe")
		var second_site := _site("eisgrab")
		game.hero.position = second_site.pos
		check(_act(game,"eisgrab","search").is_empty(), "Weiterer Boss besitzt einen eigenen versteckten Zugang")
		game.hero.position = second_site.cave
		check(_act(game,"eisgrab","summon").is_empty(), "Zweiter aktiver Bossfundort lässt sich unabhängig starten")
		var second_foes: Array = game.enemies.filter(func(enemy): return not enemy.dead and enemy.zone == "explore_eisgrab")
		check(second_foes.size()==1 and not foes[0].dead, "Zwei Höhlenbosse existieren gleichzeitig mit getrennten Kennungen")
		ex.close_encounters()
		check(foes[0].dead and not ex.points.boss.boss_started and not ex.points.boss.boss_won and second_foes.all(func(enemy): return enemy.dead) and not ex.points.eisgrab.boss_started and not ex.points.eisgrab.boss_won, "Gebietswechsel entfernt alle offenen Höhlengegner ohne Belohnung")
		game.hero.position = boss_site.cave
		_act(game,"boss","summon")
		game.hero.position = second_site.cave
		_act(game,"eisgrab","summon")
		second_foes = game.enemies.filter(func(enemy): return not enemy.dead and enemy.zone == "explore_eisgrab")
		if not second_foes.is_empty():
			game.hero_hit(second_foes[0],second_foes[0].max_hp*100,"physical",true)
			check(ex.points.eisgrab.boss_won and not ex.points.boss.boss_won, "Sieg gilt ausschließlich für die besiegte Boss-Höhle")
			check(_act(game,"eisgrab","claim").is_empty() and ex.points.eisgrab.claimed and not ex.points.boss.claimed, "Bossbelohnungen werden je Fundort getrennt geborgen")
		ex.close_encounters()
		game.hero.position = boss_site.cave
		_act(game,"boss","summon")
		game.hero.position = game.hero_spawn()
		ex.step(3.1)
		check(not ex.points.boss.boss_started and not ex.points.boss.boss_won, "Verlassene Bossbegegnung setzt zurück und gewährt keinen Sieg")
		game.hero.position = boss_site.cave
		_act(game,"boss","summon")
		foes = game.enemies.filter(func(enemy): return not enemy.dead and enemy.zone == "explore_boss")
		game.hero_hit(foes[0],foes[0].max_hp*100,"physical",true)
		check(ex.points.boss.boss_won and _act(game,"boss","claim").is_empty(), "Erst tatsächlicher Tod des Höhlenbosses gibt die Beute frei")
	game.play_time = ex.tower_until+.1
	game.hero.step(0.0,game.play_time)
	check(is_equal_approx(tower.out_mult(),tower_before) and is_equal_approx(game.hero.out_mult(),damage_before) and is_equal_approx(game.hero.speed_mult(),speed_before), "Temporäre Turm- und Heldenverstärkungen laufen wieder aus")
	game.hero.position = game.hero_spawn()


func _test_network(game: HdGame) -> void:
	game.coop = HdCoop.new()
	game.add_child(game.coop)
	game.coop.setup(game,{"role":"host","player":0,"names":["A","B"]})
	game.coop.set_process(false)
	game.coop.ensure_player(1,"unrat")
	var host_pos: Vector3=game.hero.position
	var cache := _site("cache")
	var camera_before: Vector3=game.cam_pos
	game.bot=false
	game.coop.slots[1].hero.position=cache.pos
	game.coop.with_player(1,game.exploration._step_passage)
	game.bot=true
	check(game.cam_pos==camera_before,"Remote-Eintritt verschiebt nicht die Kamera des Hosts")
	check(game.coop.slots[1].hero.position.distance_to(cache.cave)<16 and game.hero.position==host_pos,"Automatischer Koop-Eintritt versetzt nur den betreffenden Spieler")
	game.coop.slots[1].hero.position=game.hero_spawn()
	var gold_host: int = game.shop.gold
	var gold_peer: int = game.coop.slots[1].shop.gold
	var command := {"kind":"shop","cmd":{"kind":"explore","id":"cache","op":"claim"}}
	game.coop.execute(1,command)
	check(not game.exploration.points.cache.claimed and game.coop.slots[1].shop.gold==gold_peer, "Host prüft auch die Reichweite von Koop-Erkundungsbefehlen")
	game.coop.slots[1].hero.position = _site("cache").cave
	game.coop.execute(1,command)
	check(game.exploration.points.cache.claimed and game.shop.gold>gold_host and game.coop.slots[1].shop.gold>gold_peer, "Fund eines Mitspielers belohnt die gesamte Gruppe genau einmal")
	gold_host = game.shop.gold
	game.coop.execute(1,command)
	check(game.shop.gold==gold_host, "Wiederholter Koop-Befehl dupliziert keine Gruppenbeute")
	game.exploration.begin(50)
	game.exploration.tick_break(17)
	game.exploration.tower_until = game.play_time+90
	var packet: Dictionary = bytes_to_var(var_to_bytes(game.coop.snapshot()))
	check(packet.has("exploration") and packet.exploration.points.items.claimed and is_equal_approx(packet.exploration.remaining,283.0), "Koop-Snapshot transportiert Rätsel, Beute, Buff und Rastzähler")
	Session.coop = {}
	Session.skip_setup = true
	var client: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	client.bot = true
	client.persist_settings = false
	add_child(client)
	client.set_process(false)
	client.set_physics_process(false)
	client.coop = HdCoop.new()
	client.add_child(client.coop)
	client.coop.setup(client,{"role":"client","player":1,"names":["A","B"]})
	client.coop.set_process(false)
	var alternate_ids: Array = HdExplorationLayout.sites().slice(6,14).map(func(site): return str(site.id))
	check(client.exploration.select_sites(alternate_ids) and client.exploration.active_ids!=game.exploration.active_ids, "Client startet absichtlich mit einer anderen lokalen Auswahl")
	client.coop.apply_state(packet)
	check(client.exploration.snapshot()==game.exploration.snapshot(), "Koop-Client übernimmt den vollständigen autoritativen Erkundungszustand")
	check(client.exploration.active_ids==game.exploration.active_ids and client.exploration._markers.size()==8 and client.exploration.points.size()==8, "Host-Auswahl ersetzt die lokale Auswahl samt Hinweisen und Interaktionen")
	check(client.hero.position.distance_to(_site("cache").cave)<.1 and not client.exploration.nearby().is_empty(), "Client sieht nach Höhlenteleport seine lokalen Interaktionen")
	client.queue_free()
