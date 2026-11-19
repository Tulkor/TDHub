class_name HdScriptCaster
extends HdEnemy
## Friendly adapter around the existing enemy cast state machine; no duplicated spells.
## Add to the game, call begin(), then advance(dt, now) in the owning hero context.
## Friendly projectiles/pools must retain script_owner when emitted (caster may retire).

var script_owner: HdHero
var _real_game
var _bridge: CastGame
var _aim_point: AimPoint


class AimPoint extends Node3D:
	var radius := 0.0
	func alive() -> bool:
		return true


## Native casts use game.hero for their opponent (retarget/whirl). This view gives
## that opponent without changing the real game's active hero/damage attribution.
class CastGame extends RefCounted:
	var real_game
	var caster
	var ability_defs: Dictionary = {}
	var hero:
		get:
			return caster.target if is_instance_valid(caster.target) and caster.target.alive() else caster._aim_point
	func _get(property: StringName):
		return real_game.get(property)
	func add_tele(tele) -> void:
		tele.color = Color(0.2, 0.8, 1.0)
		real_game.add_tele(tele)
	func tele_hit(src, tele, damage: float, knockdown: float) -> void:
		real_game.tele_hit(src, tele, damage, knockdown)
	func ability_hit_area(src, kind: int, origin: Vector3, direction: Vector3, radius: float, inner: float, angle: float, length: float, width: float, damage: float, knockdown: float) -> void:
		real_game.ability_hit_area(src, kind, origin, direction, radius, inner, angle, length, width, damage, knockdown)
	func move_unit(_unit, direction: Vector3, speed: float, dt: float, direct := false) -> void:
		real_game.move_unit(caster.script_owner, direction, speed, dt, direct)
		caster.position = caster.script_owner.position
	func add_pool(at: Vector3, radius: float, dps: float, duration: float, src) -> void:
		real_game.add_pool(at, radius, dps, duration, src)
	func enemy_projectile(src, at: Vector3, direction: Vector3, speed: float, length: float, width: float, damage: float) -> void:
		real_game.enemy_projectile(src, at, direction, speed, length, width, damage)
	func summon(src, id: String, count: int, radius: float) -> void:
		real_game.summon(src, id, count, radius)
	func floater(at: Vector3, text: String, color: Color) -> void:
		real_game.floater(at, text, color)


func begin(real_game, owner_hero: HdHero, ability_id: String, point: Vector3, opponent: Node3D = null, overrides: Dictionary = {}) -> String:
	if not real_game.ability_defs.has(ability_id):
		return "Unbekannte Gegnerfähigkeit: " + ability_id
	var ability: Dictionary = real_game.ability_defs[ability_id].duplicate(true)
	for key in overrides:
		if key in ["name", "cooldown", "cast_range", "min_range"]:
			return "Native KI-/Auswahlwerte können nicht überschrieben werden: " + str(key)
		if not ability.has(key):
			return "Ungültiger nativer Fähigkeitsparameter: " + str(key)
		var both_numbers := (overrides[key] is float or overrides[key] is int) and (ability[key] is float or ability[key] is int)
		if (typeof(overrides[key]) != typeof(ability[key]) and not both_numbers) or (overrides[key] is float and not is_finite(float(overrides[key]))):
			return "Ungültiger nativer Fähigkeitsparameter: " + str(key)
		if key == "kind" and overrides[key] != ability[key]:
			return "Native Fähigkeitsform kann nicht überschrieben werden"
		if both_numbers:
			var value := float(overrides[key])
			if absf(value) > 1000000000.0 or (key != "rotate" and value < 0.0):
				return "Nativer Fähigkeitsparameter außerhalb des Bereichs: " + str(key)
			if key in ["count", "repeat"] and (value != floorf(value) or value < 1 or value > 64):
				return "Native Anzahl muss ganzzahlig zwischen 1 und 64 sein: " + str(key)
			if key in ["speed", "tick", "duration", "cooldown", "repeat_windup"] and value <= 0:
				return "Nativer Fähigkeitsparameter muss positiv sein: " + str(key)
	ability.merge(overrides, true)
	if str(ability.get("kind", "")) not in ["circle", "echo", "cone", "ring", "line", "arc", "cross", "box", "charge", "skillshot", "whirl", "summon"]:
		return "Nicht unterstützte native Fähigkeitsform: " + str(ability.get("kind", ""))
	_real_game = real_game
	script_owner = owner_hero
	set_meta("script_owner", owner_hero)
	position = owner_hero.position
	facing = owner_hero.facing
	speed = owner_hero.speed
	radius = owner_hero.radius
	def = {"size": [radius * 2, 1.0, radius * 2], "leash": 100000.0, "encounter": {"recovery": 0.0}}
	zone = "script"
	home = position
	cc = owner_hero.cc if owner_hero.cc != null else HdCc.new(real_game.cfg.cc, "hero")
	_body = Node3D.new()
	add_child(_body)
	_aim_point = AimPoint.new()
	add_child(_aim_point)
	_aim_point.top_level = true
	_aim_point.position = point
	target = opponent if is_instance_valid(opponent) else _aim_point
	_bridge = CastGame.new()
	_bridge.real_game = real_game
	_bridge.caster = self
	_bridge.ability_defs = {ability_id: ability}
	game = _bridge
	if str(ability.kind) == "echo":
		boss_brain = HdBossBrain.new(self)
		if is_instance_valid(opponent):
			for sample in opponent.get_meta("script_position_history", []):
				if sample is Vector3:
					boss_brain.history.append(sample)
	start_cast(ability_id, real_game.play_time)
	return ""


## Returns true while the native cast is running. Do not run ordinary enemy AI.
func advance(dt: float, now: float) -> bool:
	if not is_instance_valid(script_owner) or not script_owner.alive():
		if casting():
			cancel_cast(true)
		return false
	if not casting():
		return false
	if cc.stunned(now):
		cancel_cast(true)
		return false
	position = script_owner.position
	speed = script_owner.speed * script_owner.speed_mult()
	if is_instance_valid(target) and target != _aim_point:
		_aim_point.position = target.position
	_step_cast(maxf(dt, 0.000001), now)
	return casting()


func _exit_tree() -> void:
	# CastGame has a backreference; break it before either object is destroyed.
	if _bridge != null:
		_bridge.caster = null
	game = null
