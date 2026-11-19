extends Node
## Lauf: einzeln (Name heroesroster)
## Modi: heroes
## Kader, importierte Blender-Clips, alle nativen Fähigkeiten und rollenbezogene Prägungen.
var failures := 0
var checks := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", text)


func _ready() -> void:
	var previous_ambience := Sfx.ambience()
	Session.skip_setup = true
	Session.difficulty = 0
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.persist_settings = false
	g.force_hero = "torvik"
	add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.bot = false
	g.spawn_queue.clear()
	check(Sfx.ambience() == "hd_wind", "Bollwerk startet eigenes Ambiente")
	var atmosphere := g.get_node("Atmosphere") as HdAtmosphere
	check(atmosphere.fires.size() >= 20 and atmosphere._lamps.size() <= 8, "Viele Feuerstellen mit begrenzten aktiven Lichtern")
	for sound in ["wind","fire_loop","bell","steel","stone","chain","swing","bolt","fire","frost","heal","shadow","step"]:
		var stream := load(HdSoundscape.DIR+sound+".wav") as AudioStreamWAV
		check(stream != null and stream.get_length() > .05, "Gültiger Audiostream: "+sound)
	var roles := {"Tank":0,"Heiler":0,"DD":0}
	for id in g.hero_list:
		g.set_hero(str(id))
		var h: HdHero = g.hero
		roles[str(h.def.combat_role)] += 1
		h.level = 18
		h._apply_level()
		h.position = g.roads[0].point(55) + g.roads[0].side(55) * 2
		h.hp = h.max_hp * .5
		h.mana = 5000
		check(h.has_model(), "%s hat ein importiertes Modell" % id)
		for clip in ["idle","run","attack","cast","death"]:
			check(h._anim != null and h._anim.has_animation(clip), "%s Clip %s" % [id,clip])
		if h is HdHeroRoster:
			if str(id) == "sirra":
				h._attack_anim_index = 0
				for combo in 3:
					g.fx.network_events.clear()
					h._swing_fx()
					check(g.fx.network_events.any(func(event): return str(event.get("id","")) == "thrust") if combo < 2 else g.fx.network_events.any(func(event): return str(event.get("kind","")) == "swing"), "Sirra: zwei Stichspuren, dann Schnittspur passend zur Kombo")
					h._attack_clip()
			for slot in 4:
				var sound := HdSoundscape.palette("roster:%s:%s:cast" % [id,slot])
				check(ResourceLoader.exists(HdSoundscape.DIR+sound+".wav"), "%s Fähigkeit %s hat Klang" % [id,slot])
			for clip in ["attack_combo_1","attack_combo_2","attack_combo_finish","cast_0","cast_1","cast_2","cast_3"]:
				check(h._anim.has_animation(clip), "%s eigener Clip %s" % [id,clip])
			var cast_count := 0
			for slot in 4:
				var foe := g.spawn("sumpfling", null, 5)
				foe.position = h.position + Vector3.FORWARD * 3
				foe.max_hp = 100000
				foe.hp = foe.max_hp
				h.cd = [0.0,0.0,0.0,0.0]
				h.mana = 5000
				var target := foe.position
				var a := h.ability(slot)
				g.fx.network_events.clear()
				if str(a.op) in ["rescue","guard","buff"]: target = h.position
				if str(a.op) == "beacon_blink" and not h.fields.is_empty(): target = h.fields[0].pos
				var ok := h.cast(slot, target)
				check(ok, "%s wirkt Slot %d" % [id,slot])
				if ok:
					cast_count += 1
					check(g.fx.network_events.any(func(event): return str(event.get("id", "")) == "roster:%s:%d:cast" % [id,slot]), "%s Slot %d sendet den eigenen Fähigkeits-VFX an Koop" % [id,slot])
					check(h.cd[slot] > 0 and h.mana < 5000, "%s Slot %d kostet Mana und hat Cooldown" % [id,slot])
				for k in 25:
					g.play_time += .1
					h._kit_step(.1,g.play_time)
					g._step_projectiles(.1)
					for p in h.servants.duplicate():
						if is_instance_valid(p): p.step(.1)
				if is_instance_valid(foe) and foe.alive():
					h.on_hit(foe)
					if float(a.get("damage",0)) > 0 and str(a.op) not in ["guard","turret","summon","detonate","zone"]:
						check(foe.hp < foe.max_hp or str(a.op) == "dash", "%s Slot %d trifft tatsächlich" % [id,slot])
				for e in g.enemies.duplicate():
					g._remove(e)
				g.enemies.clear()
			check(cast_count == 4, "%s alle vier Fähigkeiten ausgeführt" % id)
			if str(id) == "brennholt" or str(id) == "sorek":
				check(h.servants.any(func(p): return is_instance_valid(p) and p.blocks(p.position)), "%s echte Projektilblockade" % id)
			if str(id) == "grauhirte":
				check(h.servants.size() <= 4, "Rudelgrenze eingehalten")
		for wave in [10,20,30]:
			g.imprint_claimed.clear()
			g.imprint_pending.clear()
			g.imprint_choices.clear()
			g.wave = wave
			g.offer_imprint()
			check(g.imprint_choices.size() == 3, "%s Welle %d drei Prägungen" % [id,wave])
			var categories: Array = g.imprint_choices.map(func(p): return str(p.category))
			check(categories == ["offense","defense","utility"], "%s Welle %d feste Kategorien" % [id,wave])
			for card in g.imprint_choices:
				var change: Dictionary = card.skill_changes[0]
				var before_value := stat(h.ability(int(change.slot)), str(change.field))
				var trial: Dictionary = card.duplicate(true)
				trial.owner = 0
				g.imprints.append(trial)
				var after_value := stat(h.ability(int(change.slot)), str(change.field))
				check(after_value > before_value if float(change.add) > 0 else after_value < before_value, "%s %s verändert die konkrete Fähigkeit" % [id,card.category])
				g.imprints.pop_back()
			check(g.choose_imprint(1), "%s Welle %d Defensive wählbar" % [id,wave])
			check(not g.choose_imprint(1), "Keine doppelte Prägung")
			check(h.b("armor") >= 2, "Defensive hat echte Rüstungswirkung")
	check(g.hero_list.size() == 24 and roles == {"Tank":8,"Heiler":4,"DD":12}, "Exakt 8 Tanks, 4 Heiler und 12 DDs")
	check(HdTerrain.material("rock") != HdTerrain.material("basalt"), "Fels und Basalt getrennte Materialien")
	g.queue_free()
	await get_tree().process_frame
	check(Sfx.ambience() == previous_ambience, "Bollwerk stellt beim Verlassen vorheriges Ambiente wieder her")
	# Bei GPU-Läufen Ressourcen vor dem RenderingServer freigeben.
	HdDev._mats.clear()
	HdDev._tex = null
	HdFxParts._textures.clear()
	HdFxParts._spark_mats.clear()
	HdFxParts._beam_mats.clear()
	HdRosterFx._materials.clear()
	await get_tree().process_frame
	print("heroesroster: %d Prüfungen, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func stat(data: Dictionary, path: String) -> float:
	var value = data
	for key in path.split("."):
		if not value is Dictionary: return 0.0
		value = value.get(key, 0.0)
	if value is Array: return float(value[0])
	return float(value)
