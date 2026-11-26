extends Node
## Lauf: einzeln (Name heroesitemeffects)
## Modi: heroes
## Echte aktive Items, alle Heldenmeisterschaften und alle Szepteraufwertungen.

const Effects = preload("res://scripts/heroes/hd_item_effects.gd")
var checks := 0
var failures := 0
var game: HdGame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func reset_hero() -> void:
	var h := game.hero
	game.shop.inv.fill(null)
	game.shop.stash.fill(null)
	game.shop.wood_bought.clear()
	game.perma.clear()
	game.blessing.clear()
	game.event_buffs.clear()
	h.buffs.clear()
	h.shield = 0
	h.mastery_ready = 0
	h.item_ready.clear()
	if h.has_meta(EffectScript.STATE):
		h.remove_meta(EffectScript.STATE)
	h.level = 10
	h.cd.fill(0.0)
	h.cc = HdCc.new(game.cfg.cc, "hero")
	h.set_meta("root_until", -1.0)
	h.dodge_cd = 0
	h.dodge_t = 0
	h.dodge_iframe_until = 0
	h.dead = false
	h.position = Vector3(18, 0, 18)
	h.facing = Vector3.FORWARD
	game.shop._changed()
	h.hp = h.max_hp * .5
	h.mana = h.max_mana * .5
	game.paused = false


func equip(id: String, slot := 0) -> void:
	game.shop.inv[slot] = {"id":id, "n":1}
	game.shop._changed()


func enemy() -> HdEnemy:
	var e := game.spawn("sumpfling", game.hero.position + Vector3.FORWARD * 2)
	e.max_hp = 1000000
	e.hp = e.max_hp
	e.armor = 0
	return e


func fingerprint(h: HdHero, e: HdEnemy) -> String:
	return JSON.stringify([h.hp, h.mana, h.shield, h.buffs, e.hp, e.cc._armor, e.cc._slows, h.get_meta(EffectScript.STATE, {}).get("queue", []).size()])


func _ready() -> void:
	Sfx.audible = false
	Session.skip_setup = true
	Session.coop = {}
	Session.difficulty = 0
	game = load("res://scenes/heroes_game.tscn").instantiate()
	game.bot = true
	game.persist_settings = false
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.cfg.arena.walls = false
	game.obstacles.clear()
	game.spawn_queue.clear()
	for e in game.enemies:
		game._remove(e)
	game.enemies.clear()
	var translated: Dictionary = Database.load_json(Loc.SOURCE)
	for it in game.shop.items.values():
		check(it.has("use") or it.has("active") or it.has("effect_script") or it.has("scepter") or it.get("stats", {}).has("mastery"), "Item bietet Mechanik: " + str(it.id))
		if it.has("effect_script"):
			check(EffectScript.compile(str(it.effect_script)).ok, "Passive kompiliert: " + str(it.id))
			check(translated.has(str(it.effect_desc)), "Passiver Tooltip übersetzt: " + str(it.id))
		if it.has("active"):
			check(EffectScript.compile(str(it.active.get("effect", ""))).ok, "Aktiveffekt kompiliert: " + str(it.id))
			check(translated.has(str(it.active.desc)), "Aktiver Tooltip übersetzt: " + str(it.id))
	await _masteries_and_scepters(translated)
	_passive_items()
	_active_items()
	_passives_and_hooks()
	if "--bilder" in OS.get_cmdline_user_args():
		reset_hero()
		equip("aszendentenszepter")
		game.hud._process(0)
		game.hud.econ.tab = "rezept"
		game.hud.econ.picked = "aszendentenszepter"
		game.hud.econ.toggle()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://export/screens")
		get_viewport().get_texture().get_image().save_png("res://export/screens/bollwerk-itemeffekte.png")
	game.queue_free()
	await get_tree().process_frame
	print("FERTIG heroesitemeffects: %d Prüfungen, Fehler: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _masteries_and_scepters(translated: Dictionary) -> void:
	for id in game.hero_list:
		game.set_hero(id)
		reset_hero()
		var h := game.hero
		var profile: Dictionary = h.def.mastery
		check(translated.has(str(profile.name)) and translated.has(str(profile.desc)), "Meisterschaft übersetzt: " + id)
		equip("meisteremblem")
		check(EffectScript.compile(Effects.mastery_script(h, h.b("mastery"))).ok, "Meisterschaft kompiliert: " + id)
		var e := enemy()
		var before := fingerprint(h, e)
		h.script_event(e, str(profile.event))
		check(fingerprint(h, e) != before and h.mastery_ready > game.play_time, "Meisterschaft wirkt im Ereignishook: " + id)
		before = fingerprint(h, e)
		h.script_event(e, str(profile.event))
		check(fingerprint(h, e) == before, "Meisterschaft respektiert interne Sperre: " + id)
		check(Effects.mastery_values(h, 100) == Effects.mastery_values(h, 200), "Meisterschaft ist bei 100 gedeckelt: " + id)
		game.shop.inv.fill(null)
		game.shop._changed()
		h.mastery_ready = 0
		before = fingerprint(h, e)
		h.script_event(e, str(profile.event))
		check(fingerprint(h, e) == before, "Ohne Meisterschaftsitem kein neuer Proc: " + id)
		var upgrade: Dictionary = h.def.scepter
		var slot := int(upgrade.slot)
		var original := h.ability(slot).duplicate(true)
		var source := h.def.duplicate(true)
		equip("aszendentenszepter")
		var upgraded := h.ability(slot).duplicate(true)
		check(Effects.has_scepter(h), "Szepter erkannt: " + id)
		check(translated.has(str(upgrade.desc)), "Szepter übersetzt: " + id)
		if upgrade.has("effect"):
			check(EffectScript.compile(str(upgrade.effect)).ok, "Szepter-Nachwirkung kompiliert: " + id)
		else:
			check(original != upgraded, "Szepter verändert Fähigkeit: " + id)
		equip("aszendentenszepter", 1)
		check(h.ability(slot) == upgraded, "Doppelte Szepter stapeln die Aufwertung nicht: " + id)
		game.shop.inv.fill(null)
		game.shop._changed()
		check(h.ability(slot) == original and not Effects.has_scepter(h), "Ablegen entfernt die Aufwertung aus dem Cache: " + id)
		check(h.def == source, "Originale Helden-/Rangdaten bleiben erhalten: " + id)
		equip("aszendentenszepter")
		h.mastery_ready = INF  # Szepter-Nachwirkung getrennt von Meisterschaft beobachten.
		h.cd.fill(0.0)
		h.mana = h.max_mana
		h.dodge_t = 0
		var shots := game.projectiles.size()
		check(h.cast(slot, h.position + Vector3.FORWARD * 2), "Aufgewertete Fähigkeit wirklich wirken: " + id)
		if str(id) in ["sirra", "kaspar", "ilsabet", "kraehenfrau"]:
			check(game.projectiles.size() - shots == 3, "Szepter erzeugt drei echte Projektile: " + id)
		if id == "bruno":
			check(game.projectiles.size() - shots == 5, "Fassflut erzeugt fünf echte Fässer")
		if id == "grauhirte":
			check(h.servants.size() == 3, "Szepter erzeugt drei echte Wölfe")
		if id == "totengraeber":
			check(h.servants.size() == 4, "Szepter erzeugt vier echte Grabhelfer")
		if upgrade.has("effect"):
			# Ein vorgezogenes Mastery-Ready verhindert, dass Meisterschaft diesen Check erfüllt.
			check(h.shield > 0 or not h.buffs.is_empty() or e.cc.speed_factor(game.play_time) < 1 or float(e.get_meta("root_until", -1)) > game.play_time, "Szepter-Nachwirkung existiert im Kampf: " + id)
		game._remove(e)
		game.enemies.erase(e)
		await get_tree().process_frame


func _passive_items() -> void:
	game.set_hero("torvik")
	for it in game.shop.items.values():
		if not it.has("effect_script"):
			continue
		reset_hero()
		equip(str(it.id))
		game.hero.hp = game.hero.max_hp * .5
		game.hero.mana = game.hero.max_mana * .5
		var e := enemy()
		var script := str(it.effect_script)
		var open := script.find("(")
		var comma := script.find(",")
		# Zufall nur in der Probe ausschalten; Originalprogramm und Daten bleiben unverändert.
		if comma > open and script.substr(open + 1, comma - open - 1).strip_edges().ends_with("%"):
			script = script.left(open + 1) + "100%" + script.substr(comma)
		var compiled := EffectScript.compile(script)
		var event := str(EffectScript.catalog().functions[compiled.ast[0].name].trigger)
		var before := fingerprint(game.hero, e)
		var errors := EffectScript.trigger(game.hero, e, event, 6 if event == "tick" else 0, [script])
		check(errors.is_empty(), "Passive läuft ohne Adapterfehler: " + str(it.id))
		check(fingerprint(game.hero, e) != before, "Passive erzeugt echte Wirkung: " + str(it.id))
		game._remove(e)
		game.enemies.erase(e)


func _active_items() -> void:
	game.set_hero("torvik")
	for it in game.shop.items.values():
		if not it.has("active"):
			continue
		reset_hero()
		equip(str(it.id))
		var h := game.hero
		var e := enemy()
		var before := fingerprint(h, e)
		var origin := h.position
		check(game.shop.use(0) == "", "Aktives Item ausrüsten und benutzen: " + str(it.id))
		check(game.shop.inv[0] != null and int(game.shop.inv[0].n) == 1, "Ausrüstung wird nicht verbraucht: " + str(it.id))
		check(Effects.active_left(h, it) > 0 and game.shop.use(0) != "", "Erneute Nutzung vor Abklingzeit gesperrt: " + str(it.id))
		if float(it.active.get("distance", 0)) > 0:
			check(h.position.distance_to(origin) > .1 and h.position.distance_to(origin) <= float(it.active.distance) + .01, "Bewegung findet statt und bleibt begrenzt: " + str(it.id))
		else:
			check(fingerprint(h, e) != before, "Aktiver Effekt verändert Kampfzustand: " + str(it.id))
		check(game.shop.move("hero", 0, "hero", 1) == "" and game.shop.use(1) != "", "Verschieben setzt Abklingzeit nicht zurück: " + str(it.id))
		game.shop.inv[1] = null
		equip(str(it.id), 2)
		check(game.shop.use(2) != "", "Neues Exemplar setzt Abklingzeit nicht zurück: " + str(it.id))
		game._remove(e)
		game.enemies.erase(e)
	reset_hero()
	equip("windlaeufer")
	equip("himmelslaeufer", 1)
	check(game.shop.use(0) == "" and game.shop.use(1) != "", "Verschiedene Bewegungsitems teilen Abklingzeit")
	game.play_time += 19
	check(game.shop.use(1) == "", "Bewegungsitem nach Ablauf wieder nutzbar")
	reset_hero()
	equip("himmelslaeufer")
	game.hero.set_meta("root_until", game.play_time + 5)
	var at := game.hero.position
	check(game.shop.use(0) != "" and game.hero.position == at, "Bewegungsitem umgeht Verwurzelung nicht")
	equip("pilgerschuhe", 1)
	game.hero.cc.slow("test", .7, 10, game.play_time)
	check(game.shop.use(1) == "" and game.hero.slow_immune() and game.hero.cc.speed_factor(game.play_time) == 1 and float(game.hero.get_meta("root_until")) < game.play_time, "Utility-Item reinigt langsame Effekte und Wurzeln")
	reset_hero()
	equip("himmelslaeufer")
	var origin := game.hero.position
	game.obstacles.append([origin + Vector3.FORWARD * 3, 1.0])
	game.shop.use(0)
	check((game.hero.position - origin).dot(Vector3.FORWARD) < 2.5, "Aktiver Vorstoß durchquert kein Hindernis")
	game.obstacles.clear()
	game.paused = true
	game.hero.item_ready.clear()
	check(game.shop.use(0) != "", "Keine aktive Itemnutzung während Pause")
	game.paused = false


func _passives_and_hooks() -> void:
	reset_hero()
	game.set_hero("yuna")
	reset_hero()
	equip("meistersplitter")
	var h := game.hero
	var e := enemy()
	h.attack_cd = -1
	h._try_attack(e)
	check(h.mastery_ready > game.play_time and h.b("attack_speed") > 0, "Echter Grundangriff löst Meisterschaft genau einmal aus")
	var remaining := h.mastery_ready
	h._try_attack(e)
	check(h.mastery_ready == remaining, "Laufender Angriffstimer erzeugt keinen zweiten Proc")
	game._remove(e)
	game.enemies.erase(e)
	game.set_hero("fenn")
	reset_hero()
	equip("meisteremblem")
	h = game.hero
	var mana := h.mana
	check(h.dodge(Vector3.RIGHT) and h.mana > mana and h.speed_mult() > 1, "Echtes Ausweichen löst Weglicht aus")
	game.set_hero("vesna")
	reset_hero()
	equip("meisteremblem")
	h = game.hero
	var hp := h.hp
	check(h.cast(3, h.position) and h.mastery_ready > game.play_time and h.hp > hp, "Erfolgreicher echter Zauber löst Nachsorge aus")
	reset_hero()
	equip("weisenstab")
	equip("sternenkodex", 1)
	check(h.effect_scripts().size() == 1 and str(h.effect_scripts()[0]).contains("Mana(18)"), "Verwandte Passive wählt nur höchste Itemstufe")
	equip("sternenkodex", 2)
	check(h.effect_scripts().size() == 1, "Doppeltes Item vervielfacht keine Passive")
	var missing := h.max_mana - h.mana
	h.script_event(h, "cast")
	check(is_equal_approx(h.max_mana - h.mana, missing - 18), "Zauberfluss erstattet genau einmal Mana")
	game.shop.inv.fill(null)
	game.shop._changed()
	missing = h.max_mana - h.mana
	h.script_event(h, "cast")
	check(is_equal_approx(h.max_mana - h.mana, missing), "Abgelegte Items erzeugen keine neuen Passiven")
	reset_hero()
	equip("himmelslaeufer")
	check(game.shop.use(0) == "", "Tempobuff des aktiven Items startet")
	var base := float(game.shop.item("himmelslaeufer").stats.attack_speed)
	EffectScript.trigger(h, h, "hit", 0, ['Self(Buff("attack_speed", 8%, 2s))'])
	check(is_equal_approx(h.b("attack_speed"), base + .48), "Kleine Passive überschreibt den starken aktiven Tempobuff nicht")
	EffectScript.trigger(h, h, "hit", 0, ['Delay(1s, Self(Buff("attack_speed", 10%, 2s)))'])
	h.script_event(h, "tick", 1)
	check(is_equal_approx(h.b("attack_speed"), base + .58), "Verzögerter Buff behält seine eigene Effektquelle")
	reset_hero()
	equip("himmelslaeufer")
	equip("morgenwacht", 1)
	check(h.effect_scripts().size() == 1 and str(h.effect_scripts()[0]).contains('Damage(80'), "Bei gleicher Itemstufe gewinnt die stärkere Passive")
	game.shop.move("hero", 0, "hero", 1)
	check(h.effect_scripts().size() == 1 and str(h.effect_scripts()[0]).contains('Damage(80'), "Passive Auswahl hängt nicht von der Inventarreihenfolge ab")
	game.set_hero("yuna")
	reset_hero()
	h = game.hero
	equip("meistersplitter")
	e = enemy()
	h.script_event(e, "attack")
	game.play_time += 2.1
	equip("meisteremblem")
	h.script_event(e, "attack")
	check(is_equal_approx(h.b("attack_speed"), .14), "Änderung der Meisterschaftswertung erneuert den Proc statt ihn zu stapeln")
	game._remove(e)
	game.enemies.erase(e)
