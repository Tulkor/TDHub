extends Node
## Lauf: einzeln (Name effectscript)
## Modi: kern, system:effect_script
## Parser, catalog parity contract, authority tick timing, composable geometry and native abilities.

var failures := 0
const EffectLib = preload("res://scripts/systems/effect_script/effect_script.gd")

class Actor extends Node3D:
	var game
	var def := {}
	var stats := {}
	var pos := Vector2.ZERO
	var hp := 1000.0
	var max_hp := 1000.0
	var dead := false
	var flying := false
	var size := 1.0
	var enemy_id := "script_test"
	var traveled := 0.0
	var armor_reduction := 0.0
	var poison_dps := 0.0
	var stun_time := 0.0
	var slow := 0.0
	var total_damage := 0.0
	var owner_player := 0
	var last_tower
	var last_hit_by := 0
	var kills := 0
	func take_damage(amount: float, _kind := "") -> float:
		hp -= amount
		dead = hp <= 0.0
		return amount
	func apply_slow(amount: float, _time: float) -> void:
		slow = amount
	func apply_armor_reduction(amount: float, _time: float) -> void:
		armor_reduction = amount
	func apply_poison(amount: float, _time: float, _source = null) -> void:
		poison_dps = amount
	func apply_stun(time: float) -> void:
		stun_time = time
	func take_raw_damage(amount: float) -> float:
		return take_damage(amount)
	func heal(amount: float) -> float:
		hp = minf(hp + amount, max_hp)
		return amount
	func _killed(_target) -> void:
		kills += 1
		EffectLib.trigger(self, _target, "kill")

class Game extends Node:
	var enemies: Array = []
	var rng := RandomNumberGenerator.new()
	var gold := 0
	var night := false
	var clock := 0.0
	var aura_updates := 0
	func is_night() -> bool:
		return night
	func enemies_in_radius(_p: Vector2, _r: float) -> Array:
		return enemies
	func add_gold(amount: int, _owner: int) -> void:
		gold += amount
	func current_wave() -> int:
		return 5
	func add_beam(_from: Vector3, _to: Vector3, _color: Color, _fx := "") -> void:
		pass
	func add_ring(_at: Vector2, _radius: float, _color: Color) -> void:
		pass
	func _update_auras() -> void:
		aura_updates += 1

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", description)
	else:
		print("OK   ", description)

func _ready() -> void:
	var example := "OnHit(100%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))"
	check(EffectLib.compile(example).ok, "nested example compiles")
	for text in ["OnHit(101%,Damage(1))", "OnHit(Damage(1),)", "OnHit(AoE(-1,Damage(1)))", "Damage(\"x\")", "OnHit(OnKill(Gold(1)))", "OnHit(Bogus(1))", "Damage(1e999)", "Ring(5,2,Damage(1))"]:
		check(not EffectLib.compile(text).ok, "reject invalid: " + text)
	check(EffectLib.compile("# comment\nOnHit(Damage(5, 'fire')); Every(2s,Self(Heal(1)))").ok, "comments, units, sequences")
	var native := EffectLib.compile("Native('{\"type\":\"crit\",\"chance\":0.3}')")
	check(native.ok and native.passive[0].multiplier == 2.0, "native ability validates and supplies defaults")
	check(not EffectLib.compile("Native('{\"type\":\"invented\"}')").ok, "unknown native rejected")
	check(not EffectLib.compile("Native('{\"type\":\"crit\",\"chance\":2}')").ok, "native parameter range enforced")
	check(not EffectLib.compile("Native('{\"type\":\"speed_aura\",\"chance\":0.5}')").ok, "native rejects chance where runtime would ignore it")
	var game := Game.new()
	add_child(game)
	var source := Actor.new()
	var target := Actor.new()
	var nearby := Actor.new()
	var distant := Actor.new()
	for actor in [source, target, nearby, distant]:
		game.add_child(actor)
		actor.game = game
	target.pos = Vector2(18, 0)
	nearby.pos = Vector2(19, 0)
	distant.pos = Vector2(50, 0)
	game.enemies = [target, nearby, distant]
	source.def.effect_script = example
	check(not EffectLib.trigger(source, target, "hit", 0.0, ["Native('{\"type\":\"crit\"}')"]).is_empty(), "hero cannot silently accept tower-only passive")
	check(EffectLib.trigger(source, target, "hit").is_empty(), "projectile scheduled without errors")
	check(target.hp == 1000, "projectile has flight time")
	EffectLib.trigger(source, null, "tick", 1.0)
	check(target.hp == 950 and nearby.hp == 950 and distant.hp == 1000 and nearby.slow == 0.2, "projectile impact applies nested AoE and CC")
	var doomed := Actor.new()
	game.add_child(doomed)
	doomed.game = game
	doomed.pos = Vector2(18, 0)
	EffectLib.trigger(source, doomed, "hit")
	doomed.dead = true
	doomed.free()
	EffectLib.trigger(source, null, "tick", 1.0)
	check(nearby.hp == 900, "projectile retains impact center after primary target dies and is freed")
	source.def.effect_script = "Every(2s,Gold(3)); OnKill(Gold(7))"
	EffectLib.trigger(source, null, "tick", 5.0)
	check(game.gold == 6, "periodic catches up and preserves remainder")
	EffectLib.trigger(source, null, "tick", 1.0)
	check(game.gold == 9, "periodic remainder is retained")
	source.def.effect_script = "OnNight(Gold(5)); OnDay(Gold(2)); OnHit(WhenNight(Gold(7)),WhenDay(Gold(3)))"
	EffectLib.trigger(source, nearby, "hit")
	game.night = true
	EffectLib.trigger(source, nearby, "night")
	EffectLib.trigger(source, nearby, "hit")
	game.night = false
	EffectLib.trigger(source, nearby, "day")
	check(game.gold == 26, "day/night transitions and conditions use shared game query")
	source.def.effect_script = "OnHit(DoT(10,2.5s,'fire'))"
	EffectLib.trigger(source, target, "hit")
	EffectLib.trigger(source, null, "tick", 1.0)
	EffectLib.trigger(source, null, "tick", 4.0)
	check(target.hp == 875, "DoT integrates exact duration across large steps")
	source.def.effect_script = "OnHit(Damage(10000)); OnKill(Gold(99))"
	EffectLib.trigger(source, target, "hit")
	check(source.kills == 1 and game.gold == 26, "script damage cannot recursively trigger script kill procs")
	source.def.effect_script = "OnHit(Chain(2,2m,Damage(10)))"
	EffectLib.trigger(source, nearby, "hit")
	check(nearby.hp == 890 and distant.hp == 1000, "chain skips dead and out-of-range targets")
	EffectLib.register_handler("custom", func(_source, _target, args: Array):
		game.gold += int(args[0].amount)
		return true)
	check(EffectLib.trigger(source, nearby, "hit", 0.0, ["Invoke('custom','{\"amount\":4}')"]).is_empty() and game.gold == 30, "registered existing mechanics invoke through validated JSON")
	EffectLib.unregister_handler("custom")
	check(not EffectLib.trigger(source, nearby, "hit", 0.0, ["Summon('unit',1,5)"]).is_empty(), "missing mode bridge reports explicit error")
	var tower := Tower.new()
	tower.stats = {"abilities": []}
	tower.def = {"effect_script": "Native('{\"type\":\"multishot\",\"targets\":3}')"}
	check(tower.ability("multishot").get("targets", 0) == 3, "tower consumes shared script passives")
	check(EffectLib.trigger(tower, null, "tick", 1.0).is_empty(), "tower accepts native script without duplicate execution")
	_contract(game, source, nearby, tower)
	_native_runtime_extras(game, tower)
	_eeve_native_scopes(game, tower)
	_existing_native_data()
	tower.free()
	print("EffectScript: %d Fehler" % failures)
	get_tree().quit(1 if failures else 0)


func _contract(game: Game, source: Actor, target: Actor, tower: Tower) -> void:
	var definitions := EffectLib.catalog()
	var common: Array = definitions.native.keys().filter(func(name): return not str(name).contains("."))
	check(common.size() == Abilities.SCHEMA.size(), "common native catalog covers every base Tower ability")
	for name in Abilities.SCHEMA:
		var expression := "Native(%s)" % JSON.stringify(JSON.stringify({"type": name}))
		var result := EffectLib.compile(expression)
		var matches := bool(result.ok)
		for key in Abilities.SCHEMA[name].params:
			matches = matches and float(result.passive[0][key]) == float(Abilities.SCHEMA[name].params[key])
		check(matches, "native defaults match existing runtime: " + name)
		tower.def.effect_script = expression
		check(tower.ability(name) == result.passive[0], "native ability reaches Tower runtime: " + name)
		var bad := "Native(%s)" % JSON.stringify(JSON.stringify({"type": name, "invented_parameter": 1}))
		check(not EffectLib.compile(bad).ok, "native rejects ignored parameter: " + name)
	for name in definitions.functions:
		var spec: Dictionary = definitions.functions[name]
		var args: Array[String] = []
		var params: Array = spec.get("params", [])
		for i in params.size():
			if params[i] == "number":
				var bounds: Array = spec.get("ranges", [])
				args.append(str(bounds[i][0]) if i < bounds.size() and bounds[i] is Array else "1")
			else:
				args.append(JSON.stringify("{}" if name == "Invoke" and i == 1 else (JSON.stringify({"type": "crit"}) if name == "Native" else "contract")))
		if spec.get("children", false):
			args.append("Damage(0)")
		var expression: String = name + "(" + ",".join(args) + ")"
		var compiled := EffectLib.compile(expression)
		check(compiled.ok, "catalog function has runnable signature: " + name)
		if not compiled.ok:
			continue
		var event := str(spec.get("trigger", "hit"))
		var errors := EffectLib.trigger(tower if name == "Native" else source, target, event, 0.1, [expression])
		if spec.get("bridge", false):
			check(not errors.is_empty(), "mode bridge requirement is explicit: " + name)
		else:
			check(errors.is_empty() or spec.has("requires"), "built-in runs or documents target capability: " + name)
	game.night = false


func _native_runtime_extras(game: Game, tower: Tower) -> void:
	tower.game = game
	tower.stats = {"damage":[10,10],"abilities":[]}
	tower.def.effect_script = "Native('{\"type\":\"wave_damage\",\"per_wave\":20}')"
	check(is_equal_approx(tower._roll_damage(),110.0), "script native wave_damage scales actual Tower damage by wave")
	var primary := Actor.new()
	var secondary := Actor.new()
	game.add_child(primary)
	game.add_child(secondary)
	game.enemies = [primary,secondary]
	tower.def.effect_script = "Native('{\"type\":\"nova\",\"chance\":1,\"damage\":350,\"radius\":2,\"slow\":0.2}')"
	tower._hit(primary,0)
	check(primary.hp == 650 and secondary.hp == 650 and primary.slow == 0.2, "script native nova executes existing Tower AoE damage and optional slow")
	check(not EffectLib.compile("Native('{\"type\":\"nova\",\"slow\":2}')").ok, "native nova optional slow remains bounded")


func _eeve_native_scopes(game: Game, tower: Tower) -> void:
	var eeve := EeveTower.new()
	eeve.game = game
	eeve.stats = {"range":10,"damage":[0,0],"abilities":[]}
	for scoped in EffectLib.catalog().native_scopes:
		var text := "Native(%s)" % JSON.stringify(JSON.stringify({"type":scoped}))
		var compiled := EffectLib.compile(text)
		check(compiled.ok, "scoped native signature validates: " + scoped)
		var runtime := EffectLib.native_abilities(eeve,text)
		check(runtime.errors.is_empty() and runtime.abilities[0].type == scoped.trim_prefix("eeve."), "scoped native uses existing EeveTower type: " + scoped)
		var rejected := EffectLib.native_abilities(tower,text)
		check(rejected.abilities.is_empty() and not rejected.errors.is_empty(), "base Tower rejects foreign native scope: " + scoped)
		eeve.def = {"effect_script":text}
		check(eeve.ability(scoped.trim_prefix("eeve.")) == runtime.abilities[0], "EeveTower exposes native ability: " + scoped)
		var primary := Actor.new()
		var secondary := Actor.new()
		game.add_child(primary)
		game.add_child(secondary)
		secondary.pos = Vector2(1,0)
		game.enemies = [primary,secondary]
		match scoped:
			"eeve.area_debuff":
				eeve._hit(primary,0)
				check(primary.armor_reduction == 3 and secondary.poison_dps == 60 and primary.slow == 0.1, "native area_debuff reaches existing armor/slow/poison APIs")
			"eeve.amplify":
				eeve.def.effect_script = "Native('{\"type\":\"eeve.amplify\",\"chance\":1}')"
				eeve._hit(primary,100)
				check(primary.hp == 875 and primary.has_meta("eeve_amplify"), "native amplify changes damage through existing EeveTower runtime")
			"eeve.death_explosion":
				eeve._hit(primary,0)
				check(primary.get_meta("eeve_burn", {}).get("damage",0) == 3000, "native death_explosion installs existing enemy death payload")
			"eeve.chain":
				eeve.def.effect_script = "Native('{\"type\":\"eeve.chain\",\"chance\":1,\"damage\":100,\"growth\":1.25}')"
				eeve._hit(primary,0)
				check(primary.hp == 900 and secondary.hp == 875, "eeve chain uses growing damage rather than core projectile chain")
			"eeve.pulse":
				eeve.def.effect_script = "Native('{\"type\":\"eeve.pulse\",\"stun\":2.5}')"
				check(eeve._cast(eeve.ability("pulse")) and primary.stun_time == 2.5, "native pulse delegates existing timed spell API")
			"eeve.rage":
				var before := game.aura_updates
				check(eeve._cast(eeve.ability("rage")) and eeve.rage_left == 8 and game.aura_updates == before + 1, "native rage delegates existing aura refresh and duration")
			"eeve.hp_cut":
				eeve._hp_cut(eeve.ability("hp_cut"))
				eeve._hp_cut(eeve.ability("hp_cut"))
				check(primary.hp == 770 and primary.has_meta("eeve_cut"), "native hp_cut runs once using existing enemy marker")
			"eeve.orb":
				game.enemies = [primary]
				check(eeve._orb(eeve.ability("orb")) and primary.hp == 935, "native orb delegates existing random-target DPS API")
		primary.free()
		secondary.free()
	for bad in ["Native('{\"type\":\"eeve.pulse\",\"center\":\"invalid\"}')", "Native('{\"type\":\"eeve.pulse\",\"targets\":4}')", "Native('{\"type\":\"eeve.orb\",\"color\":\"broken\"}')", "Native('{\"type\":\"eeve.chain\",\"count\":3}')"]:
		check(not EffectLib.compile(bad).ok, "scoped native rejects invalid or incompatible parameter")
	eeve.free()


func _existing_native_data() -> void:
	var checked := 0
	var invalid: Array = []
	for id in Database.towers:
		for tier in Database.towers[id].get("tiers", []):
			for ability in tier.get("abilities", []):
				var native: Dictionary = ability.duplicate(true)
				var scoped := "eeve." + str(native.type)
				if str(id).begins_with("eeve_") and EffectLib.catalog().native.has(scoped) and not (native.type == "chain" and native.has("count")):
					native.type = scoped
				var text := "Native(%s)" % JSON.stringify(JSON.stringify(native))
				var result := EffectLib.compile(text)
				if not result.ok:
					invalid.append(str(id) + ": " + result.error)
				checked += 1
	check(checked > 300 and invalid.is_empty(), "all existing Tower native ability data validates: %d entries, %s" % [checked, str(invalid)])

