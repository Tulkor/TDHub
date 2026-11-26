extends Node
## Lauf: einzeln (Name heroesplay)
## Modi: heroes
## Steuerung, acht Lanes, Ränge/Tags/Prägungen, isolierter Ereignisraum und räumliche Suche.

var failures := 0
var checks := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", text)


func _ready() -> void:
	Session.skip_setup = true
	Session.difficulty = 0
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	g.force_hero = "torvik"
	g.persist_settings = false
	add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.spawn_queue.clear()
	g.hero.auto_attack = false
	g.hero.attack_held = true
	g.hero.aim = g.hero.position + Vector3.RIGHT * 10
	g.hero.step(0.01, g.play_time)
	check(g.hero.attack_cd > 0, "M1 beginnt auch ohne Gegner einen Angriff")
	g.hero.attack_cd = 0
	g.hero.aim = g.hero.position + Vector3.LEFT * 10
	g.hero.step(0.01, g.play_time)
	check(g.hero.attack_cd > 0 and g.hero.facing.x < 0, "Gehaltenes M1 wiederholt in neuer Zielrichtung")
	g.hero.attack_held = false
	g.hero.attack_cd = 0
	g.hero.step(0.01, g.play_time)
	check(g.hero.attack_cd <= 0, "Loslassen beendet Dauerangriffe")
	g.set_hero("zix")
	g.fx.network_events.clear()
	g.hero._ranged_shot(Vector3.RIGHT, null)
	var discharge := g.fx.network_events.filter(func(event): return event.kind == "bolt")
	check(g.hero.attack_cd > 0 and discharge.size() == 3, "Zix entlädt auch ohne Ziel einen verzweigten Elektroschock")
	check(discharge.size() > 0 and discharge[0].b.is_equal_approx(g.hero.position + Vector3(1.4, 1.15, 0)), "Zix-Schock liegt vor dem Helden in Zielrichtung")
	check(g.fx.network_events.all(func(event): return event.kind in ["bolt", "impact"]), "Elektroschock nutzt vorhandene Koop-Effektereignisse")
	g.set_hero("torvik")
	var h := g.hero
	var old := h.ability(0).duplicate(true)
	h.add_xp(h.xp_needed(h.level))
	check(h.skills.points == 1 and h.skills.ranks == [1, 1, 1, 1], "Stufenaufstieg vergibt einen frei wählbaren Punkt")
	check(h.skills.tooltip(0, true).contains("→") and h.skills.points == 1, "Tooltip zeigt Vorschau ohne Punktverbrauch")
	check(h.skills.upgrade(0) and h.skills.points == 0 and h.skills.ranks == [2, 1, 1, 1], "Nur gewählte Fähigkeit steigt")
	check(float(h.ability(0).cooldown) < float(old.cooldown), "Rang verändert echte Abklingzeit")
	var damage_before: float = h.skills.metrics(h.ability(0)).damage
	h.skills.add_modifier("wrong", ["poison"], {"damage":1.0})
	check(is_equal_approx(float(h.skills.metrics(h.ability(0)).damage), damage_before), "Nicht passende Tags wirken nicht")
	h.skills.add_modifier("right", ["lightning", "melee"], {"damage":0.3})
	check(float(h.skills.metrics(h.ability(0)).damage) > damage_before, "Alle passenden Tags verstärken tatsächlich")
	check(g.cfg.arena.roads.size() == 8, "Acht Richtungen definiert")
	check(g.arena_layout.boundary_kind(Vector3(0,0,30)) == "city" and g.arena_layout.boundary_kind(Vector3(-33,0,-33)) == "city", "Stadtkern und Kirchenbezirk erhalten Stadtmauern")
	check(g.arena_layout.boundary_kind(Vector3(90,0,80)) == "mountain", "Äußere Wildnis erhält Gebirge statt Stadtmauern")
	var boundaries: Node3D = g.get_node("MixedBoundaries")
	var city: Node3D = boundaries.get_node("CityFortifications")
	var mountains: Node3D = boundaries.get_node("OuterMountainBoundaries")
	check(city.get_meta("city_wall_edges",0)>0 and city.get_meta("city_wall_height",0)>=5.0, "Stadtmauern sind massive Befestigungen")
	check(mountains.get_meta("mountain_triangles",0)>0 and mountains.get_meta("mountain_main_peaks",0)>=3, "Zusammenhängendes Gebirge mit drei großen Massiven vorhanden")
	var terrain: MeshInstance3D = mountains.get_node("ContinuousBasaltMountains")
	var safe_terrain := true
	var peak_sectors := {Vector2i(-1,-1):0.0,Vector2i(1,1):0.0,Vector2i(-1,1):0.0}
	for vertex in terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if g.arena_layout.inside(Vector3(vertex.x,0,vertex.z),-1.45):safe_terrain=false
		var sector := Vector2i(signi(roundi(vertex.x)),signi(roundi(vertex.z)))
		if peak_sectors.has(sector):peak_sectors[sector]=maxf(peak_sectors[sector],vertex.y)
	check(safe_terrain, "Berggeometrie hält sämtliche Lane- und Zonenflächen frei")
	check(peak_sectors.values().all(func(height): return float(height)>float(g.cfg.arena.boundaries.mountain_height)), "Drei große Bergmassive ragen tatsächlich über die kleineren Randrücken hinaus")
	check(boundaries.find_children("*","CollisionObject3D",true,false).is_empty(), "Begrenzungsdarstellung verändert die Bewegungskontur nicht")
	g.state = "setup"
	g.lane_ids = g.cfg.arena.roads.map(func(r): return str(r.id))
	g._build_roads()
	check(g.roads.size() == 8, "Alle acht Lanes aktivierbar")
	check(g.buildings.filter(func(building): return building.road != null).size()==16, "Alle acht aktiven Lanes besitzen jeweils zwei Türme")
	var gentle_routes := true
	for road: HdRoad in g.roads:
		if road.length<145.0:gentle_routes=false
		for i in range(1,road.points.size()-1):
			var incoming: Vector3=road.points[i]-road.points[i-1]
			var outgoing: Vector3=road.points[i+1]-road.points[i]
			if incoming.angle_to(outgoing)>deg_to_rad(60.0):gentle_routes=false
	check(gentle_routes, "Längere Lanes mit flachen Bögen statt enger U-Kurven")
	check(g.arena_layout.dividers.size()==4 and g.arena_layout.dividers.all(func(divider): return not g.arena_layout.inside((divider[0]+divider[1])*.5)), "Lane-Paare bleiben bis zum Zusammenlauf getrennt")
	var common_merge: Vector3 = g.roads[0].points.filter(func(point): return g.roads[1].points.has(point))[0]
	check(g.arena_layout.inside(common_merge,1.9), "Gemeinsamer Lane-Knoten bleibt auch für große Gegner offen")
	check(g.roads[0].length-g.roads[0].project(common_merge,0.0,g.roads[0].length)>=60.0, "Gegner laufen mindestens 60 Meter gemeinsam zur Feste")
	var route_centers_clear := true
	for road: HdRoad in g.roads:
		for meter in range(0,ceili(road.length),2):
			if not g.arena_layout.inside(road.point(float(meter)),1.7):route_centers_clear=false
	check(route_centers_clear, "Trennwände blockieren auf keiner der acht Routen die Gegnerbahn")
	var before_wall_test := h.position
	for index in g.arena_layout.dividers.size():
		var divider: Array = g.arena_layout.dividers[index]
		var along: Vector3 = (divider[1]-divider[0]).normalized()
		var middle: Vector3 = divider[1]-along*8.0
		var side := Vector3(-along.z,0,along.x)
		h.position=middle+side*4.0
		g.move_unit(h,-side,20.0,.4,true)
		check((h.position-middle).dot(side)>=HdArena.DIVIDER_HALF_WIDTH+h.radius-.02 and g.arena_layout.foothill(h.position,h.radius-.01), "Schnelle Bewegung überspringt Lane-Trennwand %d nicht" % index)
	h.position=before_wall_test
	var paving: Node3D=g._road_root.get_node("LanePavingDetails")
	check(paving.get_meta("road_detail_batches",999)<=2 and paving.has_node("RoadChevrons"), "Alle Straßen erhalten gebündelte Laufrichtungsmarkierungen")
	check(int(paving.get_meta("plaza_curbs",0))>20,"Pflasterkreis erhält denselben gebündelten Steinbord mit offenen Wegmündungen")
	var plaza: MeshInstance3D=g.get_node("SchwarzeKathedrale/FortressLightPaving")
	var basalt: MeshInstance3D=g.get_node("SchwarzeKathedrale/FortressDarkPaving")
	check(plaza.material_override==HdCathedral.path_material(),"Feste-Vorplatz verwendet exakt dasselbe weltkoordinatenbasierte Pflaster wie die Monsterwege")
	check(plaza.mesh.top_radius>basalt.mesh.size.x*.5 and basalt.position.y>plaza.position.y+plaza.mesh.height*.5,"Dunkles Pflaster deckt den größeren hellen Pflasterkreis von oben vollständig ab")
	check(not g.arena_layout.inside(Vector3(-53, 0, -53), 0), "Benachbarte Kartenseiten haben keinen unbeabsichtigten Durchgang")
	for pair in 4:
		var a: HdRoad = g.roads[pair * 2]
		var b: HdRoad = g.roads[pair * 2 + 1]
		check(a.points[0].distance_to(b.points[0]) > 40, "Paar hat zwei getrennte Spawns: " + a.id)
		check(a.point(a.length - 34).is_equal_approx(b.point(b.length - 34)), "Paar läuft vor der Feste gemeinsam: " + a.id)
		check(a.gate("innentor").position.distance_to(b.gate("innentor").position) > 8, "Türme auf gemeinsamem Abschnitt bleiben getrennt: " + a.id)
	for road: HdRoad in g.roads:
		var back: Dictionary = g.stones.filter(func(s): return s.get("road") == road and not s.out)[0]
		var first: HdBuilding = road.gate("vorwerk")
		check(back.pos.distance_to(first.position) < 4, "Rückteleporter direkt am ersten Turm: " + road.id)
		check(g.arena_layout.inside(back.pos, g.hero.radius), "Rückteleporter begehbar: " + road.id)
		check(back.to.is_equal_approx(g.hero_spawn()), "Rückteleporter führt zur Feste: " + road.id)
	for i in g.stones.size():
		for j in range(i + 1, g.stones.size()):
			check(g.stones[i].pos.distance_to(g.stones[j].pos) > 2.8, "Teleport-Aktivierungsflächen überschneiden sich nicht")
	check(g.set_lane_enabled("west", false) and g.road_by_id("west") == null and g.roads.size() == 7, "Lane einzeln deaktivierbar")
	g.lane_ids = ["nord"]
	check(not g.set_lane_enabled("nord", false), "Mindestens eine Lane bleibt aktiv")
	g.lane_ids = []
	g._build_roads()
	g.state = "play"
	var blocked := Vector3.ZERO
	for x in range(-60, 60, 4):
		for z in range(-60, 60, 4):
			var candidate := Vector3(x, 0, z)
			if not g.arena_layout.inside(candidate, 1):
				blocked = candidate
	check(blocked != Vector3.ZERO, "Karte enthält gesperrte Wandbereiche")
	h.position = g.arena_layout.constrain(blocked, h.radius)
	check(g.arena_layout.inside(h.position, h.radius - 0.01), "Wandposition wird auf begehbaren Bereich begrenzt")
	g.wave = 10
	g.bot = false
	g.offer_imprint()
	check(g.paused and g.imprint_choices.size() == 3, "Nach Welle 10 drei Prägungen und Pause")
	var before := g.play_time
	g.step(1)
	check(g.play_time == before and not g.can_call_early(), "Auswahl pausiert Simulation und Früher-rufen")
	check(g.choose_imprint(0) and not g.paused and g.imprints.size() == 1, "Auswahl übernimmt eine Prägung")
	check(not g.choose_imprint(0) and not g._imprint_due(), "Prägung nicht doppelt beanspruchbar")
	g.wave = 4
	g.bot = true
	h.hp = h.max_hp
	var foe := g.spawn("sumpfling", null, 5.0)
	var guide := HdEnemyGuide.new(g)
	var saved_foe_position := foe.position
	var saved_camera := g.camera.transform
	g.camera.position = h.position + Vector3(0, 15, 20)
	g.camera.look_at(h.position)
	foe.position = h.position + Vector3.RIGHT * 200
	guide.refresh_target()
	check(guide.indicated_enemy() == foe, "Roter Wegweiser findet entfernten Gegner außerhalb der Sicht")
	var nearer := g.spawn("sumpfling", null, 5.0)
	nearer.position = h.position + Vector3.LEFT * 100
	guide.refresh_target()
	check(guide.target == nearer, "Wegweiser wählt den nächsten Gegner zum eigenen Helden")
	nearer.visible = false
	guide.refresh_target()
	check(guide.target == foe, "Wegweiser ignoriert verborgene Gegner")
	nearer.visible = true
	nearer.dead = true
	guide.refresh_target()
	check(guide.target == foe, "Wegweiser ignoriert tote Gegner")
	nearer.dead = false
	nearer.position = h.position + Vector3.RIGHT * 3
	guide.refresh_target()
	check(guide.target == nearer and guide.indicated_enemy() == null, "Pfeil verschwindet sobald der nächste Gegner sichtbar wird")
	h.dead = true
	check(guide.indicated_enemy() == null, "Kein Gegnerpfeil am toten Helden")
	h.dead = false
	g.enemies.erase(nearer)
	nearer.free()
	g.enemies.erase(foe)
	guide.refresh_target()
	check(guide.target == null and guide.indicated_enemy() == null, "Ohne lebende Gegner bleibt der Pfeil verborgen")
	g.enemies.append(foe)
	foe.position = saved_foe_position
	g.camera.transform = saved_camera
	foe.cc.hard(5, g.play_time)
	var foe_at := foe.position
	var stun := foe.cc.stun_until
	g.spawn_queue = [{"id":"sumpfling", "t":g.play_time + 5}]
	var wave_time := g.wave_time
	var return_at := h.position
	g.events.start("schrein")
	check(g.event_arena.active and h.position.distance_to(g.event_arena.center) < 1, "Ereignis teleportiert in eigenes Gebiet")
	check(not foe.visible and not g.can_call_early(), "Wellengegner verborgen und frühe Welle gesperrt")
	guide.refresh_target()
	check(guide.target != foe, "Event-Wegweiser zeigt nicht auf eingefrorene Wellengegner")
	for i in 60:
		g.step(1.0 / 60)
	check(is_equal_approx(g.wave_time, wave_time) and foe.position == foe_at and g.spawn_queue.size() == 1, "Wellenzeit, Gegner und Spawnqueue eingefroren")
	check(absf(float(g.spawn_queue[0].t) - g.play_time - 5) < 0.01, "Restzeit des nächsten Spawns erhalten")
	g.events._decide(2)
	g.event_arena.step(0)
	check(not g.event_arena.active and h.position.distance_to(return_at) < 0.1 and foe.visible, "Rückkehr und Sichtbarkeit nach Abschluss")
	check(absf(foe.cc.stun_until - stun - 1) < 0.02, "Kontrolleffekte der Welle behalten Restdauer")
	g.events.start("gefangener")
	check(g.events.active.pos.distance_to(g.event_arena.center) < 30, "Gefangener erscheint im Ereignisgebiet")
	g.event_arena.step(181)
	check(not g.event_arena.active and g.events.active.is_empty(), "Zeitlimit beendet Ereignis und bringt Helden zurück")
	g._rebuild_spatial()
	check(g.nearby_enemies(foe.position, 2).has(foe), "Räumliche Suche enthält nahe Gegner")
	# Alle Ereignisdaten müssen ihren Inhalt im separaten Gebiet erzeugen können.
	for definition in g.systems.timed_events.pool:
		g.events.start(str(definition.id))
		check(g.event_arena.active, "%s betritt Ereignisgebiet" % definition.id)
		for enemy in g.enemies:
			if not enemy.dead and not g.event_arena.frozen(enemy):
				check(absf(enemy.position.x - g.event_arena.center.x) < 43 and absf(enemy.position.z) < 43, "%s: Ereignisgegner im Gebiet" % definition.id)
		g.events.kinds.clear()
		g.events.choice = {}
		g.events._end_prisoner("")
		g.shop.merchant = []
		g.event_arena.leave()
	# Kandidatenzahl und Ergebnis mit der vollständigen Suche vergleichen, ohne Renderkosten zu messen.
	var saved := g.enemies
	g.enemies = []
	for x in 32:
		for z in 32:
			var enemy := HdEnemy.new()
			enemy.position = Vector3(x * 4 - 64, 0, z * 4 - 64)
			g.enemies.append(enemy)
	g._rebuild_spatial()
	var candidates := g.nearby_enemies(Vector3.ZERO, 3)
	var expected := g.enemies.filter(func(e): return e.position.length() <= 3)
	check(candidates.size() < g.enemies.size() / 8, "1024 Gegner: lokale Suche prüft weniger als ein Achtel")
	check(expected.all(func(e): return candidates.has(e)), "Lokale Suche verliert kein Ziel in Reichweite")
	print("MESSUNG Abstandssuche: %d statt %d Kandidaten" % [candidates.size(), g.enemies.size()])
	for enemy in g.enemies:
		enemy.free()
	g.enemies = saved
	g._spatial_ready = false
	for id in ["torvik", "unrat", "vesna", "zix"]:
		g.set_hero(id)
		for slot in 4:
			check(not g.hero.ability(slot).get("tags", []).is_empty() and not g.hero.skills.tooltip(slot).is_empty(), "%s Slot %d: Tags und Tooltip" % [id, slot])
	var zix: HdHeroZix = g.hero
	zix.mana = 9999
	zix.cast(0, zix.position + Vector3.RIGHT * 3)
	var world_gadget = zix.gadgets[0]
	g.events.start("schrein")
	check(zix.gadgets.is_empty() and not world_gadget.destroyed, "Wellenkonstrukte bleiben eingefroren und zählen nicht zum Ereignis-Baulimit")
	zix.cd[0] = 0
	zix.cast(0, zix.position + Vector3.RIGHT * 3)
	check(zix.gadgets.size() == 1 and not world_gadget.destroyed, "Ereigniskonstrukt ersetzt kein Wellenkonstrukt")
	g.events._decide(2)
	g.event_arena.step(0)
	check(zix.gadgets.size() == 1 and zix.gadgets[0] == world_gadget and not world_gadget.destroyed, "Rückkehr stellt Wellenkonstrukte wieder her")
	# Alle acht tatsächlichen Wege mit aktiven Wänden durchlaufen, einschließlich scharfer Kurven.
	for enemy in g.enemies.duplicate():
		if not enemy.dead:
			g._remove(enemy)
	g.enemies.clear()
	g.spawn_queue.clear()
	g.lane_ids = g.cfg.arena.roads.map(func(r): return str(r.id))
	g._build_roads()
	for building in g.buildings:
		building.destroy()
	g.hero.die()
	g.hero.respawn_t = 9999
	g.wave_time = -100000
	g.lives = 9999
	var leaks := g.leaks
	for road in g.roads:
		g.spawn("sumpfling", null, 0.0, road)
	for tick in 1200:
		g.step(0.1)
		if g.enemies.is_empty():
			break
	check(g.leaks - leaks == 8 and g.enemies.is_empty(), "Alle acht Lanes erreichen trotz Wänden und Kurven die Feste")
	g.queue_free()
	await get_tree().process_frame
	print("FERTIG, %d Prüfungen, Fehler: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
