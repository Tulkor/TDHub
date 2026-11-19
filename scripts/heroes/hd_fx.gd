class_name HdFx
extends Node3D
## Kurzlebige Effekte in Bollwerk: Druckwellen, Blitze, Strahlen, Schwünge, Treffer und die Effekte der
## Heldenfähigkeiten (play) sowie anhaltende Effekte, die der Host jeden Schritt meldet (hold).
## Bausteine in HdFxParts, Shader assets/shaders/hd_fx_*.gdshader. Alles verschwindet von selbst.
## Koop: play/hold und die Grundformen landen in network_events, HdCoop spielt sie beim Client ab.

var _timed: Array = []   ## [Knoten, Restzeit]
const LIMIT := 180
const LIGHTS := 8
var network_events: Array = []
var _held := {}          ## Schlüssel -> {node, id, until, sent, at, to, size}
var _lights := 0
var _clock := 0.0
var _flip := false
var _held_lights := 0
var _projectile_lights := 0


func follow_light(node: Node3D, color: Color) -> void:
	if _projectile_lights >= 4 or Display.quality == Display.LOW: return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 4.0
	light.shadow_enabled = false
	node.add_child(light)
	_projectile_lights += 1
	light.tree_exiting.connect(func(): _projectile_lights -= 1)


func _sound(id: String, at: Vector3) -> void:
	var sound := get_parent().get_node_or_null("Soundscape") if get_parent() != null else null
	if sound != null: sound.effect(id, at)


func _note(event: Dictionary) -> void:
	if network_events.size() < 64:
		network_events.append(event)


func _add(n: Node3D, life: float) -> bool:
	if _timed.size() >= LIMIT:
		n.free()
		return false
	add_child(n)
	var owner_game := get_parent()
	if owner_game is HdGame: owner_game.conform_ground_effect(n)
	_timed.append([n, life])
	return true


func _process(dt: float) -> void:
	for i in range(_timed.size() - 1, -1, -1):
		var it: Array = _timed[i]
		it[1] -= dt
		if it[1] <= 0.0 or not is_instance_valid(it[0]):
			if is_instance_valid(it[0]):
				it[0].queue_free()
			_timed.remove_at(i)
	var owner_node := get_parent()
	if owner_node == null or owner_node.get("paused") != true:
		_clock += dt
	for key in _held.keys():
		var h: Dictionary = _held[key]
		if not is_instance_valid(h.node):
			_held.erase(key)
			continue
		if _clock >= float(h.until):
			_fade_out(h.node, 0.3)
			_held.erase(key)
			continue
		_tick_hold(h, dt)


# ---------------------------------------------------------------- Hilfen

static func _material(n: Node) -> ShaderMaterial:
	return n.material_override as ShaderMaterial if n is MeshInstance3D else null


## Shader-Wert eines Effektknotens über die Zeit ändern (fade, progress, head).
func _tween(n: Node, param: String, from: float, to: float, time: float, delay := 0.0) -> void:
	var m := _material(n)
	if m == null or not n.is_inside_tree():
		return
	m.set_shader_parameter(param, from)
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(m, "shader_parameter/" + param, to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Knoten samt Kindern ausblenden und danach löschen.
func _fade_out(root: Node3D, time: float) -> void:
	if not root.is_inside_tree():
		root.queue_free()
		return
	for n in [root] + root.find_children("*", "", true, false):
		if n is CPUParticles3D:
			n.emitting = false
		elif n is Light3D:
			n.create_tween().tween_property(n, "light_energy", 0.0, time)
		elif _material(n) != null:
			var current = _material(n).get_shader_parameter("fade")
			_material(n).set_shader_parameter("fade", 1.0 if current == null else float(current))
			n.create_tween().tween_property(_material(n), "shader_parameter/fade", 0.0, time)
		elif n is MeshInstance3D:
			n.create_tween().tween_property(n, "scale", Vector3.ONE * 0.01, time)
	_timed.append([root, time + 0.5])


## Bodeneffekt: wächst über grow Sekunden (progress 0→1) und blendet bis life aus.
func _ground(mode: int, at: Vector3, r: float, c: Color, life: float, grow := -1.0, length := 0.0) -> MeshInstance3D:
	var n := HdFxParts.ground(mode, r, c, length)
	n.position = Vector3(at.x, 0.12, at.z)
	if not _add(n, life):
		return null
	if grow < 0.0:
		grow = life
	_tween(n, "progress", 0.0, 1.0, grow)
	if grow < life:
		_tween(n, "fade", 1.0, 0.0, life - grow, grow)
	return n


func _sparks(at: Vector3, c: Color, count: int, opt := {}) -> void:
	var p := HdFxParts.burst(c, count, opt)
	p.position = at
	_add(p, float(opt.get("life", 0.4)) + 0.15)


## Kurzes Aufleuchten der Umgebung; höchstens LIGHTS gleichzeitig, auf Niedrig keine.
func _flash(at: Vector3, c: Color, energy := 3.0, reach := 7.0, time := 0.22) -> void:
	if _lights >= LIGHTS or Display.quality == Display.LOW:
		return
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	l.position = at + Vector3(0, 1.3, 0)
	if _add(l, time):
		_lights += 1
		l.tree_exiting.connect(func(): _lights -= 1)
		l.create_tween().tween_property(l, "light_energy", 0.0, time)


static func _aim(n: Node3D, dir: Vector3) -> void:
	if absf(dir.x) + absf(dir.z) > 0.0001:
		n.rotation.y = atan2(-dir.x, -dir.z)


static func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0, v.z)
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _zigzag(a: Vector3, b: Vector3, steps: int, jitter: float) -> PackedVector3Array:
	var pts := PackedVector3Array([a])
	for i in range(1, steps):
		pts.append(a.lerp(b, float(i) / steps) + Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter) * 0.6, randf_range(-jitter, jitter)))
	pts.append(b)
	return pts


# ---------------------------------------------------------------- Grundformen

## Form einer Heldenfähigkeit kurz aufblitzen lassen (blau).
func flash_shape(t: HdTelegraph, at: Vector3, dir: Vector3) -> void:
	t.position = Vector3(at.x, 0.10, at.z)
	t.aim(dir)
	add_child(t)
	t.trigger(0.3)


## Druckwelle, die sich von der Mitte bis r ausbreitet.
func nova(at: Vector3, r: float, c: Color) -> void:
	play("nova", at, Vector3.FORWARD, r, c)


## Gerade Leuchtspur (Fernkampf-Grundangriff der Gegner, Geschütz des Vorwerks).
func tracer(a: Vector3, b: Vector3, c: Color) -> void:
	_sound("bolt",a)
	_flash(b,c,1.3,4.5,.12)
	_note({"kind":"tracer", "a":a, "b":b, "color":c})
	var n := HdFxParts.ribbon(PackedVector3Array([a, b]), 0.34, HdFxParts.strip_material(c, {"tail": 0.6, "head": 0.2}))
	if _add(n, 0.16):
		_tween(n, "head", 0.2, 1.6, 0.16)
		_sparks(b, c, 5, {"life": 0.25, "size": 0.2, "speed": [1.0, 3.0]})


## Zackiger Blitz von a nach b mit leuchtendem Kern.
func bolt(a: Vector3, b: Vector3, c := Color(0.75, 0.95, 1.0)) -> void:
	_sound("bolt", a)
	_flash(b, c, 2.1, 6.0, .18)
	_note({"kind":"bolt", "a":a, "b":b, "color":c})
	var jitter := clampf(a.distance_to(b) * 0.09, 0.12, 0.55)
	var holder := Node3D.new()
	var pts := _zigzag(a, b, 6, jitter)
	holder.add_child(HdFxParts.ribbon(pts, 0.46, HdFxParts.strip_material(c, {"grain": 0.5, "flow": 30.0})))
	if a.distance_to(b) > 2.0:
		var from: Vector3 = pts[2 + randi() % 3]
		var side := Vector3(randf_range(-1, 1), randf_range(-0.2, 0.6), randf_range(-1, 1)).normalized() * a.distance_to(b) * 0.22
		holder.add_child(HdFxParts.ribbon(_zigzag(from, from + side, 3, jitter * 0.6), 0.18, HdFxParts.strip_material(c, {"grain": 0.5, "flow": 30.0, "taper": 0.6})))
	if _add(holder, 0.2):
		for n in holder.get_children():
			_tween(n, "fade", 1.4, 0.0, 0.2)
		_sparks(b, HdFxParts.hot(c, 0.4), 5, {"life": 0.22, "size": 0.12, "speed": [1.5, 4.0]})


## Dicker Strahl für einen Schritt (Heilstrahl, Stromzaun): jeden Frame neu zeichnen.
func beam(a: Vector3, b: Vector3, c: Color, w := 0.12) -> void:
	_flash(a.lerp(b,.5),c,.9,clampf(a.distance_to(b)*.5+2.0,3.0,10.0),.1)
	_note({"kind":"beam", "a":a, "b":b, "color":c, "width":w})
	_add(HdFxParts.ribbon(PackedVector3Array([a, b]), w * 4.0, HdFxParts.beam_material(c)), 0.05)


## Leuchtfläche am Boden, die kurz stehen bleibt (Heilfläche, Kuppel-Rand).
func disc(at: Vector3, r: float, c: Color, life := 0.3) -> void:
	play("disc", at, Vector3.FORWARD, r, c, Vector3(life, 0, 0))


func dash_trail(at: Vector3, delta: Vector3) -> void:
	play("dash", at, delta, delta.length(), Color(0.55, 0.8, 1.0))


## Schwung der Nahkampfwaffe: zwei leuchtende Bögen, die über die Schlagbahn wandern. Die Richtung
## wechselt mit jedem Schlag, damit eine Schlagfolge nicht immer gleich aussieht.
func swing(at: Vector3, facing: Vector3, reach: float, color: Color) -> void:
	_sound("swing", at)
	_flash(at, color, 1.3, reach + 2.0, .18)
	_note({"kind":"swing", "pos":at, "dir":facing, "reach":reach, "color":color})
	_flip = not _flip
	var angle := atan2(facing.x, facing.z)
	var radius := clampf(reach, 1.6, 3.4)
	var holder := Node3D.new()
	holder.position = at + Vector3(0, 1.15, 0)
	holder.rotation.y = angle
	for layer in 2:
		var from := -1.35 if _flip else 1.35
		var blade := HdFxParts.arc(radius + 0.25 - layer * 0.5, 1.25 - layer * 0.5, from, -from, HdFxParts.strip_material(color, {"tail": 0.85, "head": 0.0, "grain": 0.3, "flow": 8.0}))
		blade.rotation.z = (0.32 if _flip else -0.32) + layer * 0.08
		holder.add_child(blade)
	if _add(holder, 0.32):
		for n in holder.get_children():
			_tween(n, "head", 0.0, 1.9, 0.3)


## Trefferarten: Blut, Glut, Eis, Blitze, Gift, Wind und Arkan. Ein begrenzter Effekt pro Treffergruppe.
func impact(at: Vector3, element: String, direction: Vector3) -> void:
	_sound("fire" if element == "fire" else "thunder" if element == "lightning" else "impact", at)
	_note({"kind":"impact", "pos":at, "element":element, "dir":direction})
	var back := -direction * 0.4 + Vector3.UP * 0.5
	match element:
		"fire":
			_sparks(at, Color("ffb347"), 10, {"life": 0.5, "size": 0.3, "speed": [1.0, 3.5], "gravity": Vector3(0, 3.0, 0), "fade_to": Color("c2200a")})
			_sparks(at, Color(1.0, 0.55, 0.15, 0.9), 1, {"life": 0.16, "size": 2.0, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
		"cold":
			_sparks(at, Color("c9f4ff"), 9, {"life": 0.45, "size": 0.38, "speed": [1.5, 4.0], "tex": "shard", "dir": back, "spread": 70.0})
			_sparks(at, Color(0.6, 0.9, 1.0, 0.8), 1, {"life": 0.16, "size": 1.8, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
		"lightning":
			var holder := Node3D.new()
			for i in 3:
				var a := i * TAU / 3.0 + randf()
				holder.add_child(HdFxParts.ribbon(_zigzag(at, at + Vector3(cos(a), 0.5 + randf() * 0.5, sin(a)) * 1.1, 3, 0.15), 0.24, HdFxParts.strip_material(Color("bfe6ff"), {"taper": 0.5})))
			if _add(holder, 0.16):
				for n in holder.get_children():
					_tween(n, "fade", 1.3, 0.0, 0.16)
			_sparks(at, Color("e8f4ff"), 7, {"life": 0.25, "size": 0.18, "speed": [2.0, 5.0]})
			_sparks(at, Color(0.7, 0.85, 1.0, 0.8), 1, {"life": 0.12, "size": 1.6, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
		"poison":
			_sparks(at, Color("9be04a"), 9, {"life": 0.6, "size": 0.36, "speed": [0.5, 1.8], "gravity": Vector3(0, 1.6, 0), "fade_to": Color("2f6b12")})
		"wind":
			_sparks(at, Color("d2fbf7"), 10, {"life": 0.35, "size": 0.28, "speed": [2.0, 5.0], "dir": direction + Vector3.UP * 0.2, "spread": 35.0, "gravity": Vector3.ZERO, "swirl": 20.0})
		"arcane":
			_sparks(at, Color("d391ff"), 9, {"life": 0.5, "size": 0.32, "speed": [0.8, 2.5], "gravity": Vector3(0, 1.0, 0), "tex": "shard"})
			_sparks(at, Color(0.75, 0.4, 1.0, 0.8), 1, {"life": 0.18, "size": 1.9, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
		_:
			var side := Vector3(-direction.z, 0, direction.x)
			var cut := HdFxParts.ribbon(PackedVector3Array([at - side * 0.8 + Vector3.UP * 0.5, at + side * 0.8 - Vector3.UP * 0.5]), 0.5,
				HdFxParts.strip_material(Color("ff5a4d"), {"taper": 1.0, "tail": 0.7, "head": 0.0, "core": Color("ffe9d6")}))
			if _add(cut, 0.16):
				_tween(cut, "head", 0.0, 1.7, 0.16)
			_sparks(at, Color("d3243a"), 9, {"life": 0.4, "size": 0.24, "speed": [1.5, 4.0], "dir": back, "spread": 55.0, "gravity": Vector3(0, -9.0, 0), "mix": true})


# ---------------------------------------------------------------- Fähigkeiten

## Effekt einer Fähigkeit abspielen. size, color und to bedeuten je id etwas anderes (siehe unten).
func play(id: String, at: Vector3, dir := Vector3.FORWARD, size := 1.0, color := Color.WHITE, to := Vector3.ZERO) -> void:
	_sound(id, at)
	if id not in ["nova", "fire_nova", "thunder", "ascend", "scrap_blast", "plague_burst", "heal", "overdose", "overcharge"]:
		_flash(at, color, 2.6, clampf(size + 3.0, 4.0, 15.0), .38)
	_note({"kind":"play", "id":id, "pos":at, "dir":dir, "size":size, "color":color, "to":to})
	if id.begins_with("boss:"):
		HdBossFx.play(self,id,at,dir,size,color,to)
		return
	if id.begins_with("roster:"):
		HdRosterFx.play(self,id,at,dir,size,color,to)
		return
	var up := Vector3.UP
	match id:
		"thrust":
			var from := at + Vector3.UP*1.1 + _flat(dir)*.3
			var tip := from + _flat(dir)*clampf(size,1.0,2.4)
			var trail := HdFxParts.ribbon(PackedVector3Array([from,tip]),.18,HdFxParts.strip_material(color,{"tail":.6,"head":0.0,"taper":1.0}))
			if _add(trail,.22): _tween(trail,"head",0.0,1.8,.20)
			_sparks(tip,color,4,{"life":.18,"size":.08,"speed":[.1,.5]})
		"nova":
			_ground(HdFxParts.WAVE, at, size, color, 0.5)
			_sparks(at + up * 0.3, color, 14, {"life": 0.4, "size": 0.2, "ring": size * 0.3, "dir": Vector3.RIGHT, "flat": 1.0, "speed": [size * 1.4, size * 2.6], "gravity": Vector3.ZERO, "damping": 4.0})
			_flash(at, color, 2.0, size + 3.0)
		"disc":
			var glow := _ground(HdFxParts.GLOW, at, size, color, maxf(to.x, 0.2) + 0.2, 0.01)
			if glow:
				_tween(glow, "fade", 1.0, 0.0, 0.2, maxf(to.x, 0.2))
		"dash":
			var gust := _ground(HdFxParts.GUST, at, 1.1, color, 0.32, 0.2, size)
			if gust:
				_aim(gust, dir)
			_sparks(at + up * 0.3, Color(0.8, 0.9, 1.0, 0.5), 8, {"life": 0.4, "size": 0.5, "speed": [0.3, 1.2], "gravity": Vector3(0, 0.5, 0), "mix": true, "end_scale": 1.5})
		# --- Torvik
		"fire_nova":  # Glutnova: size = Radius
			_ground(HdFxParts.SCORCH, at, size * 0.92, Color("ff5a12"), 1.6, 0.2)
			_ground(HdFxParts.FLAME, at, size, Color("ff7a1c"), 0.6)
			_ground(HdFxParts.WAVE, at, size, Color("ffd27a"), 0.35)
			_sparks(at + up * 0.2, Color("ffc04a"), 30, {"life": 0.95, "size": 0.2, "ring": size * 0.7, "ring_inner": 0.2, "speed": [1.5, 4.5], "spread": 35.0, "gravity": Vector3(0, 2.0, 0), "fade_to": Color("b3190a")})
			_flash(at, Color("ff8a3a"), 4.0, size + 5.0, 0.3)
		"thunder":  # Donnerhieb: Kegel, size = Reichweite, to.x = Winkel in Grad
			var crack := _ground(HdFxParts.CRACK, at, size, Color(0.4, 0.72, 1.0), 0.6, 0.14)
			if crack:
				_material(crack).set_shader_parameter("half_angle", deg_to_rad(to.x * 0.5))
				_aim(crack, dir)
			_sparks(at + up * 0.5, Color("dff1ff"), 18, {"life": 0.28, "size": 0.14, "dir": _flat(dir), "spread": to.x * 0.5, "flat": 0.7, "speed": [size * 2.0, size * 3.6], "gravity": Vector3.ZERO, "damping": 6.0})
			_flash(at + _flat(dir) * size * 0.5, Color("9fd0ff"), 3.5, size + 4.0)
		"strike":  # Blitz aus dem Himmel auf at
			var sky := at + Vector3(randf_range(-1.5, 1.5), 11.0, randf_range(-1.5, 1.5))
			var holder := Node3D.new()
			var pts := _zigzag(sky, at, 8, 0.6)
			holder.add_child(HdFxParts.ribbon(pts, 0.75, HdFxParts.strip_material(color, {"grain": 0.4, "flow": 40.0})))
			for i in 2:
				var from: Vector3 = pts[2 + i * 3]
				holder.add_child(HdFxParts.ribbon(_zigzag(from, from + Vector3(randf_range(-2, 2), -1.6, randf_range(-2, 2)), 4, 0.3), 0.3, HdFxParts.strip_material(color, {"taper": 0.7})))
			if _add(holder, 0.26):
				for n in holder.get_children():
					_tween(n, "fade", 1.6, 0.0, 0.26)
			_ground(HdFxParts.WAVE, at, 1.4, color, 0.3)
			_sparks(at + up * 0.2, Color("f2f8ff"), 12, {"life": 0.35, "size": 0.14, "speed": [2.0, 6.0], "spread": 70.0})
			_flash(at, color, 5.0, 9.0, 0.25)
		"gust_line":  # Windschlag: Bahn, size = Länge, to.x = Breite
			var lane := _ground(HdFxParts.GUST, at, maxf(to.x, 0.8), color, 0.45, 0.25, size)
			if lane:
				_aim(lane, dir)
			_sparks(at + up * 1.0, HdFxParts.hot(color, 0.5), 22, {"life": 0.32, "size": 0.2, "dir": _flat(dir), "spread": 7.0, "speed": [size * 1.8, size * 3.2], "gravity": Vector3.ZERO, "damping": 2.0, "radius": maxf(to.x, 0.8) * 0.4})
		"ascend":  # Windaufstieg: Wirbelsäule und Druckwelle, size = Radius
			var column := HdFxParts.tube(1.0, 2.6, 5.5, 1, Color(0.6, 0.95, 1.0))
			column.position = at
			if _add(column, 1.0):
				column.scale = Vector3(0.3, 0.2, 0.3)
				column.create_tween().tween_property(column, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween(column, "fade", 1.2, 0.0, 0.55, 0.45)
			_ground(HdFxParts.WAVE, at, size, Color(0.7, 0.95, 1.0), 0.5)
			_ground(HdFxParts.SWIRL, at, size * 0.8, Color(0.55, 0.9, 1.0), 1.0, 0.35)
			_sparks(at + up * 0.3, Color("e6fffb"), 30, {"life": 0.9, "size": 0.18, "ring": 1.4, "speed": [3.0, 7.0], "spread": 25.0, "gravity": Vector3(0, 1.0, 0), "swirl": 28.0})
			_flash(at, Color("a8f0ff"), 4.0, size + 5.0, 0.35)
		# --- Unrat
		"lob":  # Schrottbombe fliegt im Bogen von at nach to, size = Flugzeit
			var bomb := HdFxParts.shot("scrap", Color.WHITE, 0.32)
			bomb.position = at
			if _add(bomb, size):
				var height := 2.2 + at.distance_to(to) * 0.22
				var fly := func(t: float) -> void:
					bomb.position = at.lerp(to, t) + Vector3.UP * sin(t * PI) * height
					bomb.rotation = Vector3(t * 9.0, t * 4.0, 0)
				bomb.create_tween().tween_method(fly, 0.0, 1.0, size)
		"scrap_blast":  # Explosion der Schrottbombe, size = Radius
			_ground(HdFxParts.WAVE, at, size, Color("ffb45a"), 0.4)
			_ground(HdFxParts.FLAME, at, size * 0.85, Color("ff8a2a"), 0.45)
			_ground(HdFxParts.SCORCH, at, size * 0.7, Color("e06a1a"), 0.9, 0.15)
			_sparks(at + up * 0.6, Color(1.0, 0.75, 0.35, 0.95), 1, {"life": 0.2, "size": size * 1.6, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
			_sparks(at + up * 0.3, Color.WHITE, 12, {"life": 0.75, "size": 0.22, "speed": [3.5, 8.0], "spread": 65.0, "gravity": Vector3(0, -17.0, 0), "box": HdDev.metall(Color("8a8c92")), "end_scale": 0.7})
			_sparks(at + up * 0.4, Color("ffc766"), 16, {"life": 0.35, "size": 0.16, "speed": [3.0, 8.0], "spread": 80.0})
			_sparks(at + up * 0.5, Color(0.25, 0.23, 0.22, 0.6), 7, {"life": 1.0, "size": 1.1, "speed": [0.4, 1.4], "spread": 40.0, "gravity": Vector3(0, 1.2, 0), "mix": true, "end_scale": 1.7, "radius": size * 0.3})
			_flash(at, Color("ffa040"), 3.5, size + 5.0)
		"rats":  # Ratten rennen von at nach to, size = Anzahl
			for i in mini(int(size), 5):
				_rat(at, to, i)
		"robe":  # Königsgewand: goldene Lichtsäule beim Anlegen
			var pillar := HdFxParts.tube(1.2, 0.9, 3.4, 2, color)
			pillar.position = at
			if _add(pillar, 0.7):
				_tween(pillar, "fade", 1.2, 0.0, 0.7)
			_ground(HdFxParts.WAVE, at, 2.0, color, 0.45)
			_sparks(at + up * 0.4, HdFxParts.hot(color, 0.4), 16, {"life": 0.7, "size": 0.16, "ring": 1.0, "speed": [1.5, 3.5], "spread": 15.0, "gravity": Vector3(0, 1.0, 0)})
		"plague_burst":  # Ausbruch des Rattenbanners, size = Radius
			_ground(HdFxParts.WAVE, at, size, color, 0.55)
			_ground(HdFxParts.SCORCH, at, size * 0.9, color.darkened(0.2), 1.4, 0.2)
			_sparks(at + up * 0.3, color, 34, {"life": 1.0, "size": 0.26, "ring": size * 0.6, "ring_inner": 0.1, "speed": [1.0, 3.5], "spread": 40.0, "gravity": Vector3(0, 1.4, 0), "fade_to": Color("1f4a0c")})
			_flash(at, color, 3.5, size + 5.0, 0.3)
		# --- Vesna
		"health_orb":  # Vorschau; autoritative 3-s-Flächen hält HdHealthOrbs auch auf Clients vor.
			var neon := Color("57ff23")
			var area := HdFxParts.heal_area(size)
			area.position = at + up * .12
			if _add(area, 3.0):
				_tween(area, "progress", 0, 1, .35)
				_tween(area, "fade", 1, 0, .25, 2.75)
			_sparks(at + up * .3, neon, 16, {"life":1.0,"size":.3,"tex":"plus","radius":size*.8,"speed":[.5,1.4],"spread":10.0,"gravity":Vector3(0,.6,0)})
		"heal":  # Heilung an at
			_sparks(at + up * 0.8, color, 7, {"life": 0.8, "size": 0.3, "tex": "plus", "radius": 0.6 * size, "speed": [0.8, 1.8], "spread": 15.0, "gravity": Vector3(0, 0.6, 0)})
			var glow := _ground(HdFxParts.GLOW, at, 1.0 * size, color, 0.6, 0.01)
			if glow:
				_tween(glow, "fade", 1.0, 0.0, 0.6)
		"capsule_pop":  # Kapsel platzt über at
			_sparks(at, color, 18, {"life": 0.5, "size": 0.18, "speed": [2.0, 5.0], "gravity": Vector3(0, -4.0, 0)})
			_sparks(at, HdFxParts.hot(color, 0.3), 8, {"life": 0.9, "size": 0.32, "tex": "plus", "speed": [0.6, 2.0], "gravity": Vector3(0, -1.0, 0), "radius": 0.4})
			_sparks(at, Color(color.r, color.g, color.b, 0.9), 1, {"life": 0.2, "size": 2.2, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
			_ground(HdFxParts.WAVE, at, 2.0, color, 0.4)
		"overdose":  # Hochdosis: goldene Lichtsäule auf dem Ziel
			var shaft := HdFxParts.tube(1.1, 0.7, 5.0, 2, color, 1.6)
			shaft.position = at
			if _add(shaft, 1.0):
				_tween(shaft, "fade", 1.4, 0.0, 1.0)
			_ground(HdFxParts.WAVE, at, 2.4, color, 0.5)
			var glow := _ground(HdFxParts.GLOW, at, 1.8, color, 1.1, 0.01)
			if glow:
				_tween(glow, "fade", 1.2, 0.0, 1.1)
			_sparks(at + up * 0.5, HdFxParts.hot(color, 0.3), 12, {"life": 1.1, "size": 0.3, "tex": "plus", "radius": 0.8, "speed": [1.2, 2.6], "spread": 10.0, "gravity": Vector3(0, 0.8, 0)})
			_flash(at, color, 3.0, 7.0, 0.4)
		"stun_hit":  # Betäubungspfeil trifft
			_sparks(at, color, 12, {"life": 0.5, "size": 0.45, "tex": "shard", "speed": [2.5, 5.5], "gravity": Vector3(0, -3.0, 0)})
			_sparks(at, Color(color.r, color.g, color.b, 0.9), 1, {"life": 0.2, "size": 2.8, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
			_ground(HdFxParts.WAVE, at, 1.8, color, 0.35)
		"muzzle":  # Mündungsblitz
			_sparks(at, color, 6, {"life": 0.18, "size": 0.14, "dir": _flat(dir), "spread": 22.0, "speed": [3.0, 7.0], "gravity": Vector3.ZERO})
			_sparks(at, Color(color.r, color.g, color.b, 0.9), 1, {"life": 0.09, "size": 0.9 * size, "speed": [0.0, 0.0], "gravity": Vector3.ZERO})
		# --- Zix
		"build":  # Gebäude entsteht an at
			var rise := HdFxParts.tube(0.9, 0.6, 2.4, 2, color, 2.0)
			rise.position = at
			if _add(rise, 0.5):
				_tween(rise, "fade", 1.3, 0.0, 0.5)
			_ground(HdFxParts.WAVE, at, 1.6, color, 0.4)
			_sparks(at + up * 0.3, color, 14, {"life": 0.5, "size": 0.14, "speed": [2.0, 5.5], "spread": 50.0, "gravity": Vector3(0, -10.0, 0)})
			_sparks(at + up * 0.3, Color.WHITE, 5, {"life": 0.6, "size": 0.16, "speed": [2.5, 5.0], "spread": 50.0, "gravity": Vector3(0, -15.0, 0), "box": HdDev.metall(Color("b08a3a")), "end_scale": 0.7})
		"overcharge":  # Überspannung: Entladung rundum, size = Radius
			_ground(HdFxParts.WAVE, at, size, color, 0.5)
			var arcs := Node3D.new()
			for i in 7:
				var a := i * TAU / 7.0 + randf() * 0.5
				var from := at + up * 1.3
				arcs.add_child(HdFxParts.ribbon(_zigzag(from, at + Vector3(cos(a), 0, sin(a)) * size * randf_range(0.45, 0.8) + up * 0.1, 5, 0.3), 0.26, HdFxParts.strip_material(color, {"grain": 0.5, "flow": 30.0, "taper": 0.3})))
			if _add(arcs, 0.3):
				for n in arcs.get_children():
					_tween(n, "fade", 1.5, 0.0, 0.3)
			_sparks(at + up * 1.2, HdFxParts.hot(color, 0.5), 20, {"life": 0.4, "size": 0.13, "speed": [3.0, 8.0], "gravity": Vector3(0, -6.0, 0)})
			_flash(at, color, 4.5, size + 4.0, 0.3)


## Eine Ratte huscht im leichten Zickzack von a nach b und springt das Ziel an.
func _rat(a: Vector3, b: Vector3, index: int) -> void:
	var rat := Node3D.new()
	var fur := HdDev.mat(Color("4a4038"), 0.5)
	rat.add_child(HdDev.box(Vector3(0.16, 0.14, 0.34), fur, Vector3(0, 0.1, 0)))
	rat.add_child(HdDev.box(Vector3(0.11, 0.1, 0.14), fur, Vector3(0, 0.12, -0.22)))
	rat.add_child(HdDev.box(Vector3(0.03, 0.03, 0.3), HdDev.mat(Color("b98a86"), 0.5), Vector3(0, 0.08, 0.3)))
	rat.add_child(HdDev.box(Vector3(0.13, 0.03, 0.03), HdDev.flat(Color("b8ff5a")), Vector3(0, 0.16, -0.29)))
	a.y = 0.0
	var flat_b := Vector3(b.x, 0, b.z)
	var side := _flat(flat_b - a).cross(Vector3.UP) * (0.5 + 0.25 * index) * (1.0 if index % 2 == 0 else -1.0)
	rat.position = a
	var time := 0.32 + index * 0.04
	if not _add(rat, time):
		return
	_aim(rat, flat_b - a)
	var run := func(t: float) -> void:
		rat.position = a.lerp(flat_b, t) + side * sin(t * PI) + Vector3.UP * (absf(sin(t * 14.0)) * 0.08 + maxf(t - 0.8, 0.0) * 3.0 * b.y)
	rat.create_tween().tween_method(run, 0.0, 1.0, time)
	var mist := HdFxParts.burst(Color(0.6, 0.85, 0.25, 0.7), 6, {"loop": true, "life": 0.3, "size": 0.14, "speed": [0.0, 0.2], "gravity": Vector3.ZERO})
	rat.add_child(mist)


# ---------------------------------------------------------------- Anhaltende Effekte

## Anhaltenden Effekt zeigen oder verlängern; der Aufrufer meldet ihn jeden Schritt neu, sonst endet er
## nach einer halben Sekunde mit Ausblenden. key unterscheidet mehrere gleichzeitige Effekte.
## id: wind_aura, shield_dome, banner_zone (to.x = abgelaufener Anteil), scrap_pile, drain (at = Quelle,
## to = Empfänger), capsule, aura.
func hold(key: String, id: String, at: Vector3, size := 1.0, color := Color.WHITE, to := Vector3.ZERO) -> void:
	var h: Dictionary = _held.get(key, {})
	if not h.is_empty() and str(h.id) != id:
		release(key)
		h = {}
	if h.is_empty() or not is_instance_valid(h.node):
		var n := _make_hold(id, size, color)
		if n == null:
			return
		add_child(n)
		if _held_lights < 4 and Display.quality != Display.LOW:
			var light := OmniLight3D.new()
			light.name = "EffectLight"
			light.position.y = 1.5
			light.light_color = color
			light.light_energy = 1.8
			light.omni_range = clampf(size + 3.0, 4.0, 14.0)
			light.shadow_enabled = false
			n.add_child(light)
			_held_lights += 1
			light.tree_exiting.connect(func(): _held_lights -= 1)
		if id != "drain":
			n.position = at
		h = {"node": n, "id": id, "sent": -1.0, "age": 0.0, "color": color}
		_held[key] = h
	h.until = _clock + 0.5
	h.at = at
	h.to = to
	h.size = size
	if _clock - float(h.sent) >= 0.15:
		h.sent = _clock
		_note({"kind":"hold", "key":key, "id":id, "pos":at, "size":size, "color":color, "to":to})


## Anhaltenden Effekt sofort beenden (z. B. Banner ersetzt).
func release(key: String) -> void:
	if _held.has(key):
		if is_instance_valid(_held[key].node):
			_fade_out(_held[key].node, 0.25)
		_held.erase(key)


func _make_hold(id: String, size: float, color: Color) -> Node3D:
	if id.begins_with("roster:"):
		return HdRosterFx.make(id,size,color)
	var n := Node3D.new()
	match id:
		"wind_aura":
			var swirl := HdFxParts.ground(HdFxParts.SWIRL, 1.7 * size, color)
			swirl.position.y = 0.12
			n.add_child(swirl)
			n.add_child(HdFxParts.tube(0.75, 1.15, 2.9, 1, Color(color.r, color.g, color.b, 0.45), 0.7))
			var leaves := HdFxParts.burst(HdFxParts.hot(color, 0.4), 12, {"loop": true, "life": 0.8, "size": 0.14, "ring": 0.9, "speed": [1.2, 2.6], "spread": 20.0, "gravity": Vector3(0, 0.6, 0), "swirl": 14.0})
			leaves.local_coords = true
			n.add_child(leaves)
		"shield_dome":
			var shell := HdFxParts.dome(1.45 * size, color)
			shell.position.y = 1.15
			shell.scale.y = 1.15
			n.add_child(shell)
			var ring := HdFxParts.ground(HdFxParts.GLOW, 1.5 * size, color)
			ring.position.y = 0.12
			n.add_child(ring)
		"banner_zone":
			var sigil := HdFxParts.ground(HdFxParts.SIGIL, size, color)
			sigil.position.y = 0.11
			sigil.name = "Sigil"
			n.add_child(sigil)
			n.add_child(_banner(color))
			var mist := HdFxParts.burst(Color(color.r, color.g, color.b, 0.55), 18, {"loop": true, "life": 1.6, "size": 0.5, "ring": size * 0.85, "ring_inner": 0.15, "speed": [0.3, 0.9], "spread": 20.0, "gravity": Vector3(0, 0.3, 0), "end_scale": 1.4})
			n.add_child(mist)
		"scrap_pile":
			var iron := HdDev.metall(Color("7d7f86"))
			for k in 6:
				var a := k * TAU / 6.0
				var part := HdDev.box(Vector3(0.34, 0.16, 0.24), iron, Vector3(cos(a) * 0.3, 0.1 + 0.07 * (k % 3), sin(a) * 0.3))
				part.rotation = Vector3(a, a * 2.0, 0.3)
				n.add_child(part)
			n.add_child(HdDev.sphere(0.22, HdDev.metall(Color("4a4c52")), Vector3(0, 0.3, 0)))
			var fuse := HdFxParts.burst(Color("ffc24a"), 8, {"loop": true, "life": 0.3, "size": 0.1, "speed": [1.0, 2.5], "spread": 40.0})
			fuse.position.y = 0.55
			n.add_child(fuse)
			var ember := HdFxParts.halo(0.7, Color(1.0, 0.6, 0.2, 0.9))
			ember.position.y = 0.55
			n.add_child(ember)
		"drain":
			var band := MeshInstance3D.new()
			band.name = "Band"
			band.material_override = HdFxParts.strip_material(color, {"flow": 7.0, "grain": 0.6, "core": Color("ff8fa3")})
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(band)
			for i in 3:
				n.add_child(HdDev.sphere(0.15, HdDev.flat(Color("ff5a70"))))
		"capsule":
			var pill := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.17
			cm.height = 0.62
			cm.radial_segments = 10
			cm.rings = 4
			pill.mesh = cm
			pill.material_override = HdDev.mat(color, 0.5, 1.6)
			pill.rotation.z = 0.5
			pill.name = "Pill"
			n.add_child(pill)
			var band_ring := HdDev.cyl(0.18, 0.18, 0.07, HdDev.flat(Color("f4f7f2")), Vector3.ZERO, 10)
			band_ring.rotation.z = 0.5
			band_ring.name = "Ring"
			n.add_child(band_ring)
			n.add_child(HdFxParts.halo(1.3, Color(color.r, color.g, color.b, 0.55)))
			n.add_child(HdFxParts.burst(color, 6, {"loop": true, "life": 0.9, "size": 0.2, "tex": "plus", "radius": 0.35, "speed": [0.2, 0.6], "gravity": Vector3(0, -0.8, 0)}))
		"aura":
			var glow := HdFxParts.ground(HdFxParts.GLOW, 1.2 * size, color)
			glow.position.y = 0.12
			n.add_child(glow)
			var motes := HdFxParts.burst(HdFxParts.hot(color, 0.3), 10, {"loop": true, "life": 0.9, "size": 0.13, "ring": 0.7 * size, "ring_inner": 0.2, "speed": [1.0, 2.2], "spread": 8.0, "gravity": Vector3(0, 0.5, 0)})
			motes.local_coords = true
			n.add_child(motes)
		_:
			n.free()
			return null
	return n


## Rattenbanner: Stange mit Querholz, zerfetztem Tuch und Rattenschädel.
func _banner(color: Color) -> Node3D:
	var b := Node3D.new()
	b.name = "Banner"
	var wood := HdDev.mat(Color("4a2f1c"), 0.5)
	var cloth := HdDev.mat(color.darkened(0.45), 0.5, 0.35)
	b.add_child(HdDev.cyl(0.07, 0.09, 3.6, wood, Vector3(0, 1.8, 0), 6))
	b.add_child(HdDev.box(Vector3(1.5, 0.09, 0.09), wood, Vector3(0, 3.2, 0)))
	var drape := Node3D.new()
	drape.name = "Tuch"
	drape.position = Vector3(0, 3.15, 0)
	for i in 4:
		var length: float = [1.5, 1.05, 1.35, 0.8][i]
		drape.add_child(HdDev.box(Vector3(0.33, length, 0.035), cloth, Vector3(-0.52 + i * 0.35, -length * 0.5, 0)))
	var crest := HdDev.box(Vector3(0.5, 0.5, 0.045), HdDev.flat(color), Vector3(0, -0.5, 0.03))
	crest.rotation.z = PI * 0.25
	drape.add_child(crest)
	b.add_child(drape)
	var bone := HdDev.mat(Color("d9d2bd"), 0.5)
	b.add_child(HdDev.box(Vector3(0.26, 0.2, 0.34), bone, Vector3(0, 3.72, 0)))
	b.add_child(HdDev.box(Vector3(0.14, 0.12, 0.2), bone, Vector3(0, 3.68, -0.24)))
	for side in [-1.0, 1.0]:
		b.add_child(HdDev.cyl(0.09, 0.09, 0.03, bone, Vector3(0.13 * side, 3.86, 0.08), 6))
		b.add_child(HdDev.box(Vector3(0.05, 0.05, 0.02), HdDev.flat(color), Vector3(0.07 * side, 3.74, -0.18)))
	return b


func _tick_hold(h: Dictionary, dt: float) -> void:
	var n: Node3D = h.node
	h.age = float(h.age) + dt
	var at: Vector3 = h.at
	var light := n.get_node_or_null("EffectLight") as OmniLight3D
	if light != null:
		light.global_position = at + Vector3.UP*1.5
		light.omni_range = clampf(float(h.size)+3.0,4.0,14.0)
	if h.id != "drain":
		n.position = n.position.lerp(at, minf(1.0, dt * 25.0))
	if str(h.id).begins_with("roster:"):
		HdRosterFx.tick(n,float(h.age),dt)
		return
	match h.id:
		"banner_zone":
			_material(n.get_node("Sigil")).set_shader_parameter("progress", clampf(h.to.x, 0.0, 1.0))
			(n.get_node("Banner/Tuch") as Node3D).rotation.x = sin(float(h.age) * 2.2) * 0.12
		"capsule":
			for part_name in ["Pill", "Ring"]:
				var part: Node3D = n.get_node(part_name)
				part.rotation.y += dt * 2.5
				part.position.y = sin(float(h.age) * 3.0) * 0.08
		"drain":
			var from: Vector3 = at
			var target: Vector3 = h.to
			var side := _flat(target - from).cross(Vector3.UP)
			var pts := PackedVector3Array()
			var age := float(h.age)
			for i in 15:
				var t := i / 14.0
				var swell := sin(t * PI)
				pts.append(from.lerp(target, t) + side * sin(t * 9.0 - age * 9.0) * 0.3 * swell + Vector3.UP * (cos(t * 7.0 - age * 7.0) * 0.18 + 0.45) * swell)
			(n.get_node("Band") as MeshInstance3D).mesh = HdFxParts.ribbon_mesh(pts, 0.7)
			for i in 3:
				var t := fposmod(age * 1.3 + i / 3.0, 1.0)
				var drop: Node3D = n.get_child(1 + i)
				drop.position = pts[clampi(int(t * 14.0), 0, 14)]
				drop.scale = Vector3.ONE * (0.5 + sin(t * PI))
