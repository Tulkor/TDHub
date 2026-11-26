extends Node
## Lauf: einzeln (Name heroesscript)
## Modi: heroes
## Actual equipped scripts, all four native hero kits, bridges and friendly native casts.

var failures := 0
var checks := 0

class CastProbe extends Node:
	var cfg: Dictionary
	var ability_defs: Dictionary
	var play_time := 0.0
	var rng := RandomNumberGenerator.new()
	var events: Array = []
	var teles: Array = []
	func add_tele(tele) -> void:
		add_child(tele)
		teles.append(tele)
	func tele_hit(_src, tele, damage: float, knockdown: float) -> void:
		events.append({"kind":"hit", "shape":tele.shape, "point":tele.position, "direction":tele.forward(), "radius":tele.radius, "inner":tele.inner, "damage":damage, "knockdown":knockdown})
	func ability_hit_area(_src, _kind, at, _dir, radius, _inner, _angle, _length, _width, damage, _knockdown) -> void:
		events.append({"kind":"tick", "point":at, "radius":radius, "damage":damage})
	func move_unit(unit, direction: Vector3, speed: float, dt: float, _direct := false) -> void:
		unit.position += direction * speed * dt
	func add_pool(at, radius, dps, duration, _src) -> void:
		events.append({"kind":"pool", "point":at, "radius":radius, "dps":dps, "duration":duration})
	func enemy_projectile(_src, at, direction, speed, length, width, damage) -> void:
		events.append({"kind":"projectile", "point":at, "direction":direction, "speed":speed, "length":length, "width":width, "damage":damage})
	func summon(_src, id, count, radius) -> void:
		events.append({"kind":"summon", "id":id, "count":count, "radius":radius})
	func floater(_at, _text, _color) -> void:
		pass

func check(ok: bool, text: String) -> void:
	checks += 1
	if ok:
		print("OK   ", text)
	else:
		failures += 1
		printerr("FAIL ", text)


func _ready() -> void:
	Sfx.audible = false  # Auch GPU-Prüfungen mit Dummy-Treiber ohne WAV-Playbacks beenden.
	Session.skip_setup = true
	Session.difficulty = 0
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.bot = true
	game.force_hero = "torvik"
	game.persist_settings = false
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.cfg.arena.walls = false
	game.obstacles.clear()
	game.spawn_queue.clear()
	game.state = "play"
	game.shop.items = game.shop.items.duplicate(true)
	game.shop.items.script_test = {"id": "script_test", "name": "Testskript", "tier": 1, "stats": {}}
	game.shop.inv.fill(null)
	game.shop.inv[0] = {"id": "script_test", "n": 1}
	for hero_id in ["torvik", "unrat", "vesna", "zix"]:
		game.set_hero(hero_id)
		var hero := game.hero
		hero.position = Vector3(15, 0, 15)
		hero.auto_attack = false
		hero.def = hero.def.duplicate(true)
		var target := _enemy(game, hero.position + Vector3(4, 0, 0))
		var nearby := _enemy(game, target.position + Vector3(1, 0, 0))
		game.shop.items.script_test.effect_script = "OnHit(100%,IceBall(AoE(10m,Damage(50),Slow(20%,3s))))"
		check(hero.effect_scripts().size() == 1, hero_id + ": equipped item contributes script")
		var hp := target.hp
		game.hero_hit(target, 1.0, "script_test")
		check(is_equal_approx(target.hp, hp - 1.0), hero_id + ": ordinary hit starts projectile without immediate script damage")
		hero.script_event(target, "tick", 1.0)
		check(is_equal_approx(target.hp, hp - 51.0) and nearby.hp < nearby.max_hp, hero_id + ": actual item projectile damages both enemies")
		check(is_equal_approx(nearby.cc.speed_factor(game.play_time), 0.8), hero_id + ": item applies native CC")
		game.shop.items.script_test.effect_script = ""
		_test_native_hero_ids(game, target, hero_id)
		for enemy in [target, nearby]:
			game.enemies.erase(enemy)
			enemy.queue_free()
		await get_tree().process_frame
	game.set_hero("torvik")
	game.hero.position = Vector3(15, 0, 15)
	game.hero.def = game.hero.def.duplicate(true)
	var target := _enemy(game, game.hero.position + Vector3(4, 0, 0))
	_bridges(game, target)
	_day_night(game)
	check(not EffectScript.trigger(game.hero, target, "hit", 0, ["Invoke('definitely_unknown','{}')"]).is_empty(), "unknown native ability returns error")
	check(not EffectScript.trigger(game.hero, target, "hit", 0, ["Self(Buff('unknown_stat',1,3))"]).is_empty(), "unknown hero buff returns error")
	_native_caster_contract(game)
	_actual_native_invokes(game)
	_native_proc_guard(game)
	_torvik_ranged_form(game)
	_script_target_isolation(game)
	print("Hero scripts: %d checks, %d Fehler" % [checks, failures])
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _enemy(game: HdGame, point: Vector3) -> HdEnemy:
	var enemy := game.spawn_home("moorklauer", point, "script_test")
	enemy.position = point
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	enemy.armor = 0.0
	game._spatial_ready = false
	return enemy


func _test_native_hero_ids(game: HdGame, target: HdEnemy, hero_id: String) -> void:
	var hero := game.hero
	hero.level = 10
	hero._apply_level()
	for slot in 4:
		hero.cd.fill(0.0)
		hero.mana = 10000.0
		hero.dodge_t = 0.0
		var ability := hero.ability(slot)
		var id := str(ability.get("id", ability.get("gadget", "")))
		check(not id.is_empty(), hero_id + ": native slot has exact ID " + str(slot))
		var expression := "Invoke(%s,'{}')" % JSON.stringify(id)
		var errors := EffectScript.trigger(hero, target, "hit", 0, [expression])
		check(errors.is_empty() and hero.cd[slot] > 0.0, hero_id + ": Invoke exact native ID " + id)
		var rejected := EffectScript.trigger(hero, target, "hit", 0, ["Invoke(%s,'{\"unknown_parameter\":1}')" % JSON.stringify(id)])
		check(not rejected.is_empty(), hero_id + ": native ID rejects ignored override " + id)


func _bridges(game: HdGame, target: HdEnemy) -> void:
	var hero := game.hero
	var before := game.shop.gold
	check(EffectScript.trigger(hero, target, "hit", 0, ["Gold(7)"]).is_empty() and game.shop.gold == before + 7, "Gold credits actual hero wallet")
	check(EffectScript.trigger(hero, target, "hit", 0, ["Root(2s)"]).is_empty(), "Root bridge accepts enemy")
	var point := target.position
	game.move_unit(target, Vector3.RIGHT, 5.0, 0.5)
	check(target.position.is_equal_approx(point), "Root prevents actual movement")
	check(EffectScript.trigger(hero, target, "hit", 0, ["Knockback(3m,1s)"]).is_empty() and target.knock_t == 1.0 and is_equal_approx(target.knock.length(), 3.0), "Knockback configures actual enemy impulse")
	var count := game.buildings.size()
	check(EffectScript.trigger(hero, target, "hit", 0, ["Summon('moorklauer',2,3s)"]).is_empty(), "Summon reuses enemy stats as friendly allies")
	check(game.buildings.size() == count + 2, "Summon creates requested ally count")
	game.play_time += 4.0
	game._step_script_actions(0.01)
	check(game.buildings.size() == count, "Summoned allies expire on simulation clock")
	check(not EffectScript.trigger(hero, target, "hit", 0, ["Summon('unknown',1,2s)"]).is_empty(), "unknown summon returns error")


func _day_night(game: HdGame) -> void:
	var hero := game.hero
	game.shop.items.script_test.effect_script = "OnNight(Self(Buff('dmg_out',50%,5s))); OnDay(Self(Buff('armor',3,5s)))"
	game.day_cycle.set_hour(12.0)
	game.day_cycle.set_hour(0.0)
	check(game.is_night() and is_equal_approx(hero.out_mult(), 1.5), "night transition invokes equipped script buff")
	var armor := hero.armor
	game.day_cycle.set_hour(12.0)
	check(not game.is_night() and is_equal_approx(hero.armor, armor + 3.0), "day transition refreshes real derived armor")
	game.play_time += 6.0
	hero.step(0.01, game.play_time)
	check(is_equal_approx(hero.out_mult(), 1.0) and is_equal_approx(hero.armor, armor), "day/night buffs expire and derived stats restore")
	game.shop.items.script_test.effect_script = ""


func _native_caster_contract(game: HdGame) -> void:
	var probe := CastProbe.new()
	probe.cfg = game.cfg
	probe.ability_defs = game.ability_defs
	add_child(probe)
	var owner := HdHero.new()
	probe.add_child(owner)
	var opponent := HdHero.new()
	probe.add_child(opponent)
	opponent.position = Vector3(8, 0, 0)
	opponent.set_meta("script_position_history", [Vector3(6,0,0),Vector3(7,0,0),Vector3(8,0,0)])
	for ability_id in game.ability_defs:
		owner.position = Vector3.ZERO
		probe.events.clear()
		var caster := HdScriptCaster.new()
		probe.add_child(caster)
		var error := caster.begin(probe, owner, str(ability_id), opponent.position, opponent)
		check(error.is_empty(), "native caster accepts existing definition: " + str(ability_id))
		var steps := 0
		while error.is_empty() and caster.casting() and steps < 2000:
			steps += 1
			probe.play_time += 0.05
			caster.advance(0.05, probe.play_time)
		check(not caster.casting() and not probe.events.is_empty(), "existing cast completes with native effects: " + str(ability_id))
		var ability: Dictionary = game.ability_defs[ability_id]
		var hits: Array = probe.events.filter(func(event): return event.kind == "hit")
		if ability.kind in ["circle","echo","cone","ring","line","charge"]:
			var count := int(ability.get("count",1)) if ability.kind in ["circle","echo","line"] else 1
			check(hits.size() == count * int(ability.get("repeat",1)), "native geometry preserves every repetition and area count: " + str(ability_id))
		if ability.kind == "ring" and float(ability.get("grow",0)) > 0:
			check(is_equal_approx(hits[-1].radius,float(ability.radius) + float(ability.grow) * (int(ability.get("repeat",1))-1)), "native ring grows on successive repetitions: " + str(ability_id))
		if ability.kind in ["cone","line"] and float(ability.get("rotate",0)) != 0 and int(ability.get("repeat",1)) > 1:
			var spread_offset := float(ability.get("spread",0)) * (int(ability.get("count",1))-1) * 0.5 if ability.kind == "line" else 0.0
			var expected := Vector3.RIGHT.rotated(Vector3.UP,deg_to_rad(float(ability.rotate)*(int(ability.repeat)-1) + spread_offset))
			check(hits[-1].direction.is_equal_approx(expected), "native repeated shape rotates by configured angle: " + str(ability_id))
		if ability.kind == "echo" and int(ability.get("repeat",1)) > 1:
			check(hits[0].point != hits[-1].point, "native echo uses target position history: " + str(ability_id))
		if ability.kind == "skillshot":
			var projectiles: Array = probe.events.filter(func(event): return event.kind == "projectile")
			check(projectiles.size() == int(ability.get("count",1)) * int(ability.get("repeat",1)) and is_equal_approx(projectiles[0].speed,float(ability.speed)), "native skillshot preserves count, spread and speed: " + str(ability_id))
		if ability.kind == "whirl":
			check(probe.events.filter(func(event): return event.kind == "tick").size() > 1 and owner.position.x > 0, "native whirl preserves timed ticks and chase movement: " + str(ability_id))
		if ability.kind == "charge":
			check(owner.position.x > 0, "native charge moves owning hero: " + str(ability_id))
		if float(ability.get("pool",0)) > 0:
			check(probe.events.any(func(event): return event.kind == "pool" and is_equal_approx(event.duration,float(ability.pool))), "native area preserves persistent pool: " + str(ability_id))
		caster.free()
		for tele in probe.teles:
			if is_instance_valid(tele):
				tele.free()
		probe.teles.clear()
	probe.free()


func _actual_native_invokes(game: HdGame) -> void:
	game.shop.items.script_test.effect_script = ""
	game.hero.def.erase("effect_script")
	for shot in game.projectiles:
		if is_instance_valid(shot.node):
			shot.node.queue_free()
	game.projectiles.clear()
	var target := _enemy(game, game.hero.position + Vector3(5,0,0))
	for args in [{"damage": -1}, {"damage":"bad"}, {"speed":0}, {"cooldown":1}, {"cast_range":1}, {"unknown_parameter":1}, {"kind":"summon"}]:
		var expression := "Invoke('speerwurf',%s)" % JSON.stringify(JSON.stringify(args))
		check(not EffectScript.trigger(game.hero,target,"hit",0,[expression]).is_empty(), "native override rejects malformed or ignored field: " + str(args))
	for ability_id in game.ability_defs:
		if game.ability_defs[ability_id].has("count"):
			for bad_count in [-1,0,1.5,65]:
				var expression := "Invoke(%s,%s)" % [JSON.stringify(str(ability_id)),JSON.stringify(JSON.stringify({"count":bad_count}))]
				check(not EffectScript.trigger(game.hero,target,"hit",0,[expression]).is_empty(), "native count rejects invalid number: " + str(bad_count))
			break
	target.hp = 1000000000.0
	target.max_hp = target.hp
	var count := game.buildings.size()
	for ability_id in game.ability_defs:
		game.hero.position = Vector3(15,0,15)
		game.hero.hp = game.hero.max_hp
		game.hero.aim = target.position
		var before := game.hero.hp
		var errors := EffectScript.trigger(game.hero, target, "hit", 0, ["Invoke(%s,'{}')" % JSON.stringify(str(ability_id))])
		check(errors.is_empty(), "actual Invoke accepts native catalog ID: " + str(ability_id))
		var steps := 0
		while not game._script_actions.is_empty() and steps < 2000:
			steps += 1
			game.play_time += 0.05
			game._step_script_actions(0.05)
			game._step_projectiles(0.05)
			game._step_pools(0.05,game.play_time)
		check(game._script_actions.is_empty() and is_equal_approx(game.hero.hp,before), "actual native Invoke completes and spares owner: " + str(ability_id))
		for building in game.buildings.duplicate():
			if building.has_meta("script_owner"):
				game.buildings.erase(building)
				building.queue_free()
	check(game.buildings.size() == count, "native casts leave ordinary friendly buildings intact")
	# A projectile/pool must retain the actor when its short-lived caster retires.
	for id in ["speerwurf", "giftpfuetze"]:
		game.hero.position = Vector3(15,0,15)
		target.position = game.hero.position + Vector3(5,0,0)
		game._spatial_ready = false
		var hp := target.hp
		var errors := EffectScript.trigger(game.hero,target,"hit",0,["Invoke(%s,'{}')" % JSON.stringify(id)])
		var steps := 0
		while not game._script_actions.is_empty() and steps < 200:
			steps += 1
			game.play_time += 0.05
			game._step_script_actions(0.05)
		check(errors.is_empty() and game._script_actions.is_empty(), "native caster retires before lingering effect: " + id)
		var still_pending := not game.projectiles.is_empty() if id == "speerwurf" else not game.pools.is_empty()
		check(still_pending, "native lingering effect exists after caster: " + id)
		for i in 20:
			game.play_time += 0.05
			game._step_projectiles(0.05)
			game._step_pools(0.05,game.play_time)
		check(target.hp < hp, "native lingering effect hits foe after caster retires: " + id)


func _clear_lingering(game: HdGame) -> void:
	for shot in game.projectiles:
		if is_instance_valid(shot.node):
			shot.node.queue_free()
	game.projectiles.clear()
	for pool in game.pools:
		if is_instance_valid(pool.tele):
			pool.tele.queue_free()
	game.pools.clear()


func _native_proc_guard(game: HdGame) -> void:
	_clear_lingering(game)
	for enemy in game.enemies:
		enemy.position += Vector3(0,0,100)
	game.hero.position = Vector3(15,0,15)
	var target := _enemy(game, game.hero.position + Vector3(5,0,0))
	target.hp = 1000000000.0
	target.max_hp = target.hp
	for ability_id in ["moerser", "speerwurf", "giftpfuetze"]:
		_clear_lingering(game)
		game.shop.items.script_test.effect_script = "OnHit(100%%,Invoke(%s,'{}'))" % JSON.stringify(ability_id)
		var before: int = game.get_children().filter(func(child): return child is HdScriptCaster).size()
		var hp := target.hp
		game.hero_hit(target,1.0,"physical",true)
		check(game._script_actions.size() == 1, "quiet ordinary physical hit procs native item exactly once: " + ability_id)
		for tick in 180:
			game.play_time += 0.05
			game._step_script_actions(0.05)
			game._step_projectiles(0.05)
			game._step_pools(0.05,game.play_time)
		var after: int = game.get_children().filter(func(child): return child is HdScriptCaster).size()
		check(after == before + 1 and game._script_actions.is_empty(), "native hit/projectile/pool cannot recursively proc native item: " + ability_id)
		check(target.hp < hp - 1.0, "guarded native proc still damages foe: " + ability_id)
	game.shop.items.script_test.effect_script = "OnHit(Gold(1))"
	var before_gold := game.shop.gold
	for kind in ["burn","rat","rats","plague","dot","drain"]:
		game.hero_hit(target,1.0,kind,true)
	check(game.shop.gold == before_gold, "periodic damage kinds never emit item OnHit")
	game.hero_hit(target,1.0,"physical",true)
	check(game.shop.gold == before_gold + 1, "quiet display option does not suppress ordinary physical item proc")
	game.shop.items.script_test.effect_script = ""


func _torvik_ranged_form(game: HdGame) -> void:
	_clear_lingering(game)
	for enemy in game.enemies:
		enemy.position += Vector3(0,0,100)
	var hero: HdHeroTorvik = game.hero
	hero.position = Vector3(15,0,15)
	hero.attack_cd = 0.0
	hero.form_t = 2.0
	hero.attack_held = true
	hero.auto_attack = false
	hero.order = {}
	hero.aim = hero.position + Vector3.RIGHT * 12
	var target := _enemy(game,hero.position + Vector3.RIGHT * 8)
	var hp := target.hp
	game._spatial_ready = false
	hero.step(0.01,game.play_time)
	check(hero.ranged() and hero.attack_range() > 8 and not game.projectiles.is_empty(), "Torvik wind form fires basic projectile without selected target")
	for tick in 20:
		game._step_projectiles(0.025)
	check(target.hp < hp, "Torvik wind basic projectile reaches enemy beyond melee range")
	hero.attack_held = false
	hero._kit_step(3.0,game.play_time)
	check(not hero.ranged() and hero.attack_range() < 8, "Torvik returns to melee reach after form expires")
	_clear_lingering(game)
	hero.attack_cd = 0.0
	hero.attack_held = true
	hp = target.hp
	hero.step(0.01,game.play_time)
	check(game.projectiles.is_empty() and is_equal_approx(target.hp,hp), "expired form basic attack cannot hit distant foe")
	hero.attack_held = false


func _script_target_isolation(game: HdGame) -> void:
	_clear_lingering(game)
	game.hero.position = Vector3(15,0,15)
	var frozen := _enemy(game,game.hero.position + Vector3(3,0,0))
	var live := _enemy(game,game.hero.position + Vector3(4,0,0))
	var arena := game.event_arena
	var was_active := arena.active
	var visibility: Dictionary = arena.visibility.duplicate()
	arena.active = true
	arena.visibility[frozen] = true
	game._spatial_ready = false # Small-wave fallback deliberately returns all enemies.
	var hp := frozen.hp
	var errors := EffectScript.trigger(game.hero,live,"hit",0,["AoE(2m,Slow(20%,3s),Stun(2s),ArmorReduce(5,3s),Damage(10)); Root(1s)"])
	check(errors.is_empty(), "script isolation policy supports area and direct effects")
	check(frozen.hp == hp and frozen.cc.speed_factor(game.play_time) == 1.0 and not frozen.cc.stunned(game.play_time) and frozen.cc.armor_reduction(game.play_time) == 0.0, "shared AoE cannot damage or CC frozen actors from small-wave candidate list")
	check(live.hp < live.max_hp and live.cc.speed_factor(game.play_time) == 0.8 and live.cc.stunned(game.play_time) and live.cc.armor_reduction(game.play_time) == 5.0, "shared AoE still damages and controls allowed event actors")
	EffectScript.trigger(game.hero,frozen,"hit",0,["Root(3s); Knockback(3m,1s); Slow(50%,3s); Stun(3s); ArmorReduce(7,3s); Damage(100)"])
	check(frozen.hp == hp and not frozen.has_meta("root_until") and frozen.knock_t == 0.0 and not frozen.cc.stunned(game.play_time) and frozen.cc.speed_factor(game.play_time) == 1.0, "direct effect bridges and CC also respect frozen actor policy")
	arena.active = was_active
	arena.visibility = visibility
