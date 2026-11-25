class_name EffectScript
extends RefCounted
## Shared item/tower expressions. Catalog validation is also used by both HTML editors.
## All times are simulation seconds. Deferred effects advance only on authoritative tick.

const Parser = preload("res://scripts/systems/effect_script/parser.gd")
const CATALOG_PATH := "res://scripts/systems/effect_script/catalog.json"
const STATE := &"effect_script_state"
static var _catalog: Dictionary = {}
static var _cache: Dictionary = {}
static var _handlers: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	return _catalog


static func compile(text: String) -> Dictionary:
	if not _cache.has(text):
		if _cache.size() >= 256:
			_cache.clear()
		_cache[text] = Parser.new().compile(text, catalog())
	return _cache[text].duplicate(true)


static func passives(text: String) -> Array:
	return compile(text).passive


## Compile-time names remain scoped; only a capable runtime receives native type IDs.
static func native_abilities(source, text: String) -> Dictionary:
	var result := compile(text)
	var abilities: Array = []
	var errors: Array = []
	if not result.ok:
		return {"abilities": abilities, "errors": [result.error]}
	var scopes: Array = source.effect_script_native_scopes() if source.has_method("effect_script_native_scopes") else []
	for entry in result.passive:
		var type := str(entry.type)
		var scope := str(catalog().get("native_scopes", {}).get(type, "tower"))
		if not source.has_method("_effect_passives") or not scopes.has(scope):
			errors.append("Native %s benötigt den Laufzeitkontext %s" % [type, scope])
			continue
		var native: Dictionary = entry.duplicate(true)
		native.type = str(catalog().get("native_runtime_types", {}).get(type, type))
		abilities.append(native)
	return {"abilities": abilities, "errors": errors}


## Same reporting policy for every integration; caller can additionally show these in UI.
static func report_errors(source, errors: Array) -> void:
	var seen: Array = source.get_meta("effect_script_errors", [])
	for message in errors:
		if not seen.has(message):
			seen.append(message)
			push_warning(str(message))
	source.set_meta("effect_script_errors", seen)


## Extension callbacks: handler(source, target, arguments:Array) -> String error or "".
static func register_handler(name: String, handler: Callable) -> void:
	_handlers[name] = handler


static func unregister_handler(name: String) -> void:
	_handlers.erase(name)


static func scripts_for(source) -> Array:
	if source.has_method("effect_scripts"):
		return source.effect_scripts()
	var out: Array = []
	for key in ["def", "stats"]:
		if key in source and source.get(key) is Dictionary:
			var text := str(source.get(key).get("effect_script", ""))
			if not text.is_empty() and not out.has(text):
				out.append(text)
	return out


## Returned errors must be surfaced by the caller; never silently accept unsupported actions.
static func trigger(source, target, event: String, dt := 0.0, scripts: Array = []) -> Array:
	var errors: Array = []
	if not is_instance_valid(source):
		return ["Effektquelle fehlt"]
	if scripts.is_empty():
		scripts = scripts_for(source)
	if scripts.is_empty() and not source.has_meta(STATE):
		return errors
	var state: Dictionary = source.get_meta(STATE, {"clock": 0.0, "queue": [], "every": {}, "busy": false})
	if state.busy:
		return errors # Script damage/kill hooks cannot recursively proc another script.
	state.busy = true
	state.budget = 1024
	source.set_meta(STATE, state)
	var context := {"source": source, "target": target, "game": source.get("game") if "game" in source else null,
		"state": state, "errors": errors, "budget": 1024, "element": ""}
	if event == "tick":
		state.clock += maxf(dt, 0.0)
		_step_queue(context)
	for index in scripts.size():
		var text := str(scripts[index])
		var result := compile(text)
		if not result.ok:
			errors.append(result.error)
			continue
		if not result.passive.is_empty():
			errors.append_array(native_abilities(source, text).errors)
		var nodes: Array = result.ast
		for i in nodes.size():
			var node: Dictionary = nodes[i]
			var spec: Dictionary = catalog().functions[node.name]
			if spec.get("passive", false):
				continue
			if spec.has("trigger"):
				if str(spec.trigger) != event:
					continue
				var args: Array = node.args
				var offset := 0
				if node.name == "Every":
					var key := "%s/%d/%d" % [text, index, i]
					var elapsed := float(state.every.get(key, 0.0)) + dt
					var times := mini(floori(elapsed / float(args[0])), 32)
					state.every[key] = fmod(elapsed, float(args[0]))
					for n in times:
						_children(args, 1, context)
					continue
				if not args.is_empty() and args[0] is float:
					if _random(context) >= args[0]:
						continue
					offset = 1
				_children(args, offset, context)
			elif event == "hit":
				_run(node, context)
	state.busy = false
	return errors


static func _random(c: Dictionary) -> float:
	var g = c.game
	if g != null and "rng" in g and g.rng is RandomNumberGenerator:
		return g.rng.randf()
	return randf()


static func _children(args: Array, offset: int, c: Dictionary) -> void:
	for i in range(offset, args.size()):
		_run(args[i], c)


static func _position(unit) -> Vector3:
	if not is_instance_valid(unit):
		return Vector3.ZERO
	if "pos" in unit and unit.pos is Vector2:
		return Vector3(unit.pos.x, 0.0, unit.pos.y)
	if unit is Node3D:
		return unit.position
	return Vector3.ZERO


static func _valid(target) -> bool:
	return is_instance_valid(target) and not ("dead" in target and target.dead)


## Optional game policy keeps frozen/isolated actors outside every effect family.
static func _target_allowed(target, c: Dictionary) -> bool:
	return not is_instance_valid(target) or c.game == null or not c.game.has_method("effect_script_target_allowed") or bool(c.game.effect_script_target_allowed(target))


static func _near(c: Dictionary, at: Vector3, radius: float, allies := false) -> Array:
	var g = c.game
	var candidates: Array = []
	if g == null:
		c.errors.append("Flächeneffekt benötigt ein Spiel")
		return candidates
	if allies:
		if g.has_method("allies"):
			candidates = g.allies()
		elif "towers" in g:
			candidates = g.towers.values() if g.towers is Dictionary else g.towers
		else:
			c.errors.append("Allies wird von diesem Spiel nicht unterstützt")
	elif g.has_method("nearby_enemies"):
		candidates = g.nearby_enemies(at, radius)
	elif g.has_method("enemies_in_radius"):
		candidates = g.enemies_in_radius(Vector2(at.x, at.z), radius)
	elif "enemies" in g:
		candidates = g.enemies
	var out: Array = []
	for e in candidates:
		if _valid(e) and _target_allowed(e, c) and _position(e).distance_to(at) <= radius:
			out.append(e)
	return out


static func _each(targets: Array, args: Array, offset: int, c: Dictionary) -> void:
	for target in targets:
		var child := c.duplicate()
		child.target = target
		_children(args, offset, child)


static func _queue(args: Array, offset: int, seconds: float, c: Dictionary) -> void:
	if c.state.queue.size() >= 256:
		if not c.errors.has("Zu viele verzögerte Effekte (max. 256)"):
			c.errors.append("Zu viele verzögerte Effekte (max. 256)")
		return
	c.state.queue.append({"at": float(c.state.clock) + seconds, "nodes": args.slice(offset), "target": weakref(c.target) if is_instance_valid(c.target) else null, "center": _position(c.target) if is_instance_valid(c.target) else c.get("center", _position(c.source)), "element": c.element})


static func _step_queue(c: Dictionary) -> void:
	var due: Array = []
	var pending: Array = []
	for task in c.state.queue:
		if task.has("dot"):
			var target = task.target.get_ref()
			var until := minf(float(c.state.clock), float(task.end))
			if _valid(target) and until > float(task.last):
				_damage(target, float(task.dot) * (until - float(task.last)), str(task.element), c)
				task.last = until
			if _valid(target) and float(c.state.clock) < float(task.end):
				pending.append(task)
			continue
		if float(task.at) <= float(c.state.clock):
			due.append(task)
		else:
			pending.append(task)
	c.state.queue = pending
	for task in due:
		var child := c.duplicate()
		child.target = task.target.get_ref() if task.target != null else null
		child.center = task.center
		child.element = task.element
		_children(task.nodes, 0, child)


static func _run(node: Dictionary, c: Dictionary) -> void:
	c.state.budget -= 1
	if c.state.budget <= 0:
		if not c.errors.has("Effektbudget überschritten"):
			c.errors.append("Effektbudget überschritten")
		return
	var name: String = node.name
	var a: Array = node.args
	var t = c.target
	var s = c.source
	var g = c.game
	var child := c.duplicate()
	if not catalog().functions[name].get("children", false) and not _target_allowed(t, c):
		return
	match name:
		"Sequence": _children(a, 0, c)
		"WhenNight", "WhenDay":
			if g == null or not g.has_method("is_night"):
				c.errors.append(name + ": Spiel bietet keine Tageszeitabfrage an")
			elif bool(g.is_night()) == (name == "WhenNight"):
				_children(a, 0, c)
		"Chance":
			if _random(c) < float(a[0]):
				_children(a, 1, c)
		"Self":
			child.target = s
			_children(a, 0, child)
		"AoE", "Allies":
			var center: Vector3 = _position(t) if is_instance_valid(t) else c.get("center", _position(s))
			_each(_near(c, center, a[0], name == "Allies"), a, 1, c)
		"Cone", "Line", "Ring":
			var origin := _position(s)
			var direction := (_position(t) - origin).normalized()
			var targets: Array = []
			var radius := float(a[1]) if name == "Ring" else float(a[0])
			for e in _near(c, origin, radius):
				var delta := _position(e) - origin
				var distance := delta.length()
				var inside := distance >= float(a[0]) if name == "Ring" else false
				if name == "Cone":
					inside = distance <= 0.001 or direction.dot(delta.normalized()) >= cos(deg_to_rad(float(a[1]) * 0.5))
				elif name == "Line":
					var along := delta.dot(direction)
					inside = along >= 0.0 and along <= radius and (delta - direction * along).length() <= float(a[1]) * 0.5
				if inside:
					targets.append(e)
			_each(targets, a, 2, c)
		"Chain":
			var hit: Array = []
			var current = t
			for i in int(a[0]):
				if not _valid(current):
					break
				hit.append(current)
				_each([current], a, 2, c)
				var best = null
				var distance := INF
				for e in _near(c, _position(current), a[1]):
					var d := _position(e).distance_to(_position(current))
					if not hit.has(e) and d < distance:
						best = e
						distance = d
				current = best
		"IceBall", "FireBall", "Projectile":
			if not _valid(t):
				return
			var speed := float(a[0]) if name == "Projectile" else 18.0
			child.element = str(catalog().functions[name].projectile)
			if g != null and "fx" in g and is_instance_valid(g.fx) and g.fx.has_method("bolt"):
				g.fx.bolt(_position(s) + Vector3.UP, _position(t) + Vector3.UP, Color("75caff") if name == "IceBall" else Color("ff9944"))
			_queue(a, 1 if name == "Projectile" else 0, _position(s).distance_to(_position(t)) / speed, child)
		"Delay": _queue(a, 1, float(a[0]), c)
		"Damage", "DamagePercent":
			if _valid(t):
				var amount := float(a[0])
				if name == "DamagePercent":
					if not "max_hp" in t:
						c.errors.append("DamagePercent: Ziel hat kein max_hp")
						return
					amount *= float(t.max_hp)
				_damage(t, amount, str(a[1]) if a.size() > 1 else str(c.element), c)
		"Slow", "ArmorReduce", "Stun", "Root": _control(name, a, c)
		"Poison", "Burn", "DoT":
			if _valid(t):
				var duration := float(a[1])
				var element := str(a[2]) if a.size() > 2 else ("fire" if name == "Burn" else "poison")
				if c.state.queue.size() >= 256:
					c.errors.append("Zu viele verzögerte Effekte (max. 256)")
				else:
					c.state.queue.append({"at": float(c.state.clock), "dot": float(a[0]), "last": float(c.state.clock), "end": float(c.state.clock) + duration, "target": weakref(t), "element": element})
		"Heal":
			if _valid(t) and t.has_method("heal"):
				t.heal(float(a[0]))
			else:
				c.errors.append("Heal: Ziel unterstützt keine Heilung")
		"Shield":
			if _valid(t) and t.has_method("add_shield"):
				t.add_shield(float(a[0]), float(a[1]))
			else:
				c.errors.append("Shield: Ziel unterstützt keine Schilde")
		"Mana":
			if _valid(t) and "mana" in t and "max_mana" in t:
				t.mana = clampf(float(t.mana) + float(a[0]), 0.0, float(t.max_mana))
			else:
				c.errors.append("Mana: Ziel hat kein Mana")
		"Gold":
			if g != null and g.has_method("add_gold"):
				g.add_gold(int(a[0]), int(s.owner_player) if "owner_player" in s else 0)
			elif "gold" in s:
				s.gold += int(a[0])
			else:
				_bridge(name, a, c)
		"Buff":
			if _valid(t) and t.has_method("add_buff"):
				if t.has_method("supports_script_buff") and not t.supports_script_buff(str(a[0])):
					c.errors.append("Buff: unbekannter Bonusname: " + str(a[0]))
				else:
					t.add_buff("script_" + str(s.get_instance_id()) + "_" + str(a[0]), {str(a[0]): float(a[1])}, float(a[2]))
			else:
				_bridge(name, a, c)
		"Invoke": _bridge(str(a[0]), [JSON.parse_string(a[1])], c)
		_: _bridge(name, a, c)


static func _damage(t, amount: float, kind: String, c: Dictionary) -> void:
	if not _target_allowed(t, c):
		return
	var s = c.source
	var g = c.game
	if t.has_method("take_damage"):
		if "last_tower" in t:
			t.last_tower = s
		if "last_hit_by" in t and "owner_player" in s:
			t.last_hit_by = s.owner_player
		var dealt: float = t.take_damage(amount, kind)
		if "total_damage" in s:
			s.total_damage += dealt
		if "dead" in t and t.dead and s.has_method("_killed"):
			s._killed(t)
	elif g != null and g.has_method("hero_hit") and t.has_method("take") and "cc" in t:
		g.hero_hit(t, amount, kind)
	else:
		c.errors.append("Damage: Ziel unterstützt keinen Schaden")


static func _control(name: String, args: Array, c: Dictionary) -> void:
	var t = c.target
	if not _valid(t):
		return
	var methods := {"Slow": "apply_slow", "ArmorReduce": "apply_armor_reduction", "Stun": "apply_stun"}
	if methods.has(name) and t.has_method(methods[name]):
		t.callv(methods[name], args)
	elif "cc" in t and t.cc != null:
		var now := float(c.game.play_time) if c.game != null and "play_time" in c.game else float(c.state.clock)
		var id := "script_" + str(c.source.get_instance_id())
		match name:
			"Slow": t.cc.slow(id, float(args[0]), float(args[1]), now)
			"ArmorReduce": t.cc.reduce_armor(id, float(args[0]), float(args[1]), now)
			"Stun": t.cc.hard(float(args[0]), now)
			_: _bridge(name, args, c)
	else:
		_bridge(name, args, c)


static func _bridge(name: String, args: Array, c: Dictionary) -> void:
	var result = null
	if _handlers.has(name):
		result = _handlers[name].call(c.source, c.target, args)
	elif c.game != null and c.game.has_method("effect_script_action"):
		result = c.game.effect_script_action(name, args, c.source, c.target)
	else:
		c.errors.append("Effekt in diesem Modus nicht verfügbar: " + name)
		return
	if result is String and not result.is_empty():
		c.errors.append(result)
	elif result == null or result == false:
		c.errors.append("Effekt konnte nicht ausgeführt werden: " + name)
