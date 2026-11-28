class_name FxPlayer
extends Node3D
## Spielt Treffer- und Schuss-Effekte (Daten: fx_data.gd) als Sprites ab.
##
## Treffer-Effekte sind nachgebaute Unity-Partikelsysteme: jede Ebene stößt Sprites aus (Bursts oder Rate),
## die über ihre Lebenszeit Größe, Farbe, Drehung und Sprite-Bild ändern. Der Effekt steht im Raum der
## Kamera (wie in der Unity-Vorschau von vorne gesehen). Alle Sprites mit demselben Material laufen über
## ein MultiMesh, die Lage rechnet _process jedes Bild neu.

const SHADER_ADD := preload("res://assets/shaders/fx_add.gdshader")
const SHADER_MIX := preload("res://assets/shaders/fx_mix.gdshader")
const PROCEDURAL := preload("res://scripts/game/fx_procedural.gd")
## Größe der Unity-Effekte im Spiel (Unity-Einheiten → Spielfeld; ein Gegner ist ~0,4 groß).
const HIT_SCALE := 0.4
## Treffer etwas zur Kamera hin versetzen, damit der Gegnerkörper sie nicht verdeckt.
const HIT_TOWARD_CAMERA := 0.35
## Obergrenzen, damit späte Wellen mit vielen Towern nicht ruckeln.
const MAX_EFFECTS := 160
const MAX_SPRITES := 2500
## Treffer leuchten kurz als echte Lichtquelle in ihrer Farbe. Forward+ rechnet Lichter gebündelt (Cluster),
## trotzdem ein Pool mit Obergrenze; Treffer nahe an einem leuchtenden Licht frischen dieses auf,
## statt ein neues zu nehmen.
const MAX_LIGHTS := 24
const LIGHT_TIME := 0.3
const LIGHT_RANGE := 2.4
const LIGHT_ENERGY := 4.0
const LIGHT_MERGE := 1.0
const LIGHT_HEIGHT := 0.35
## Dazu ein Lichtschein flach auf dem Boden: der Neon-Boden von GemTD ist unbeleuchtet und nimmt kein Licht an.
## Beleuchtete Böden (Gras, Marmor) bekommen das echte Licht und nur einen schwächeren Schein (FieldStyle "hit_glow").
const GLOW_SIZE := 3.2
const GLOW_STRENGTH := 1.6
const GLOW_KEY := "glow"

## Treffer-Lichter an/aus (z. B. für schwache Rechner).
static var lights_enabled := true

var _effects: Array = []   ## laufende Effekte
var _sprites: Array = []   ## lebende Sprites
var _batches: Dictionary = {}  ## Material-Schlüssel → {mmi, items}
var _textures: Dictionary = {}
var _cam_basis := Basis()
## Eigener Zufall: wie viele Sprites entstehen, hängt von der Bildrate ab. Mit dem globalen randf()
## verschöben sie die Würfe der Tower (Krit, Betäubung, Nova …), und 4× machte anderen Schaden als 1×.
var _rng := RandomNumberGenerator.new()
var _lights: Array = []  ## {node, t, energy}
var _procedural: RefCounted


## Treffer-Effekt am Punkt pos. fx = {"id", "shift", "sat"} aus FxData.for_tower; optional "light": false.
## delay: Sekunden bis zum Einschlag (Geschoss im Flug).
func play_hit(fx: Dictionary, pos: Vector3, scale_factor: float = 1.0, delay: float = 0.0) -> void:
	var e := FxData.hit(str(fx.get("id", "")))
	if e.is_empty() or _effects.size() >= MAX_EFFECTS:
		return
	var layers: Array = e.get("layers", [])
	var state := []
	for l in layers:
		state.append({"acc": 0.0, "bursts": [], "alive": 0})
	var basis := _camera_basis()
	if e.get("ground", false):
		basis = Basis()
		pos.y = 0.05 * Board3D.CELL
	var light := {}
	if lights_enabled and Display.quality != Display.LOW and is_inside_tree() and bool(fx.get("light", e.get("light", true))):
		light = {"pos": pos, "color": _light_color(e, float(fx.get("shift", 0.0)), float(fx.get("sat", 1.0))),
			"scale": scale_factor}
	_effects.append({"kind": "hit", "def": e, "layers": layers, "state": state, "t": -maxf(delay, 0.0), "light": light,
		"pos": pos + (Vector3.ZERO if e.get("ground", false) else basis.z * HIT_TOWARD_CAMERA * scale_factor), "basis": basis, "scale": HIT_SCALE * scale_factor, "shift": float(fx.get("shift", 0.0)),
		"sat": float(fx.get("sat", 1.0)), "length": float(e.get("length", 1.0)),
		"budget": int(e.get("budget", -1)) / 2 if Display.quality == Display.LOW and e.has("budget") else int(e.get("budget", -1))})


## Schuss von from nach to (Strahl oder Geschoss, Sprite-Sheet aus shots.json).
func play_shot(fx: Dictionary, from: Vector3, to: Vector3) -> void:
	var id := str(fx.get("id", ""))
	var e := FxData.shot(id)
	if e.is_empty() or _sprites.size() >= MAX_SPRITES:
		return
	_sprites.append({"shot": e, "key": _shot_key(id, e), "from": from, "to": to, "age": 0.0,
		"life": float(e.get("length", 0.3)), "shift": float(fx.get("shift", 0.0)), "sat": float(fx.get("sat", 1.0))})


## Nova flach auf dem Boden um center mit Radius radius.
func play_nova(fx: Dictionary, center: Vector3, radius: float) -> void:
	var id := str(fx.get("id", ""))
	var e := FxData.shot(id)
	if e.is_empty() or _sprites.size() >= MAX_SPRITES:
		return
	_sprites.append({"shot": e, "key": _shot_key(id, e), "from": center, "to": center, "radius": radius, "age": 0.0,
		"life": float(e.get("length", 0.4)), "shift": float(fx.get("shift", 0.0)), "sat": float(fx.get("sat", 1.0))})


func clear() -> void:
	_effects.clear()
	_sprites.clear()
	for l in _lights:
		l.t = LIGHT_TIME
		l.node.visible = false
	for b in _batches.values():
		b.mmi.multimesh.visible_instance_count = 0


func busy() -> bool:
	return not _effects.is_empty() or not _sprites.is_empty()


## Wie viele Treffer-Lichter gerade leuchten (Tests).
func lights_active() -> int:
	return _lights.filter(func(l): return l.t < LIGHT_TIME).size()


func _camera_basis() -> Basis:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		return (global_transform.basis.inverse() * cam.global_transform.basis).orthonormalized()
	# ohne Kamera (Tests): schräg von oben
	return Basis.from_euler(Vector3(-0.9, 0.0, 0.0))


# --- Ablauf -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _procedural != null:
		_procedural.begin_frame()
	_update_lights(delta)
	if _effects.is_empty() and _sprites.is_empty() and lights_active() == 0:
		for b in _batches.values():
			b.items.clear()
			b.mmi.multimesh.visible_instance_count = 0
		return
	_cam_basis = _camera_basis()
	for fx in _effects:
		_emit(fx, delta)
		if not fx.get("light", {}).is_empty() and fx.t >= 0.0:
			_add_light(fx.light.pos, fx.light.color, fx.light.scale)
			fx.light = {}
	_effects = _effects.filter(func(fx): return fx.t <= fx.length or _alive(fx))
	for b in _batches.values():
		b.items.clear()
	var keep := []
	for s in _sprites:
		s.age += delta
		if s.age >= s.life:
			if s.has("fx"):
				s.fx.state[s.layer_i].alive -= 1
			continue
		keep.append(s)
		if s.has("shot"):
			_draw_shot(s)
		else:
			_update_particle(s, delta)
	_sprites = keep
	_draw_glows()
	for b in _batches.values():
		_flush(b)
	if _procedural != null:
		_procedural.flush()


func _alive(fx: Dictionary) -> bool:
	for st in fx.state:
		if st.alive > 0:
			return true
	return false


func _emit(fx: Dictionary, delta: float) -> void:
	var t0: float = fx.t
	fx.t += delta
	var t1: float = fx.t
	for i in fx.layers.size():
		var l: Dictionary = fx.layers[i]
		var st: Dictionary = fx.state[i]
		var start := float(l.get("delay", 0.0))
		var dur := float(l.get("duration", 1.0))
		var lt0 := t0 - start
		var lt1 := t1 - start
		if lt1 < 0.0:
			continue
		var limit: float = fx.length if bool(l.get("loop", false)) else dur
		if lt0 > limit:
			continue
		var max_n := int(l.get("max", 1000))
		var bursts: Array = l.get("bursts", [])
		for bi in bursts.size():
			var b: Array = bursts[bi]
			var cycles := maxi(int(b[2]) if b.size() > 2 else 1, 1)
			for c in cycles:
				var bt := float(b[0]) + c * (float(b[3]) if b.size() > 3 else 0.0)
				if bt >= maxf(lt0, 0.0) and bt < lt1 or (lt0 < 0.0 and bt <= 0.0):
					for n in int(b[1]):
						if st.alive < max_n:
							_spawn(fx, i)
		var rate := float(l.get("rate", 0.0))
		if rate > 0.0 and lt1 <= limit:
			st.acc += rate * (lt1 - maxf(lt0, 0.0))
			while st.acc >= 1.0:
				st.acc -= 1.0
				if st.alive < max_n:
					_spawn(fx, i)


func _rand(r: Array) -> float:
	return _rng.randf_range(float(r[0]), float(r[1])) if r.size() > 1 else float(r[0]) if r.size() > 0 else 0.0


func _spawn(fx: Dictionary, i: int) -> void:
	if _sprites.size() >= MAX_SPRITES or fx.budget == 0:
		return
	if fx.budget > 0:
		fx.budget -= 1
	var l: Dictionary = fx.layers[i]
	var sc: float = fx.scale
	var q_arr: Array = l.get("rot", [0, 0, 0, 1])
	var lrot := Basis(Quaternion(q_arr[0], q_arr[1], q_arr[2], q_arr[3]))
	var lsc: Array = l.get("scale", [1, 1, 1])
	var lpos: Array = l.get("pos", [0, 0, 0])
	# Form: Startpunkt und Richtung im Raum der Ebene (Unity +z = hier -z)
	var local_pos := Vector3.ZERO
	var dir := Vector3(0, 0, -1)
	var shape: Dictionary = l.get("shape", {})
	if not shape.is_empty():
		var r := float(shape.get("radius", 1.0))
		match str(shape.get("type", "sphere")):
			"cone":
				var a := _rng.randf() * TAU * float(shape.get("arc", 360.0)) / 360.0
				var rr := r * sqrt(_rng.randf())
				local_pos = Vector3(cos(a) * rr, sin(a) * rr, 0.0)
				var spread := deg_to_rad(float(shape.get("angle", 25.0))) * (rr / maxf(r, 0.0001))
				dir = Vector3(sin(spread) * cos(a), sin(spread) * sin(a), -cos(spread))
			"circle":
				var a := _rng.randf() * TAU * float(shape.get("arc", 360.0)) / 360.0
				dir = Vector3(cos(a), sin(a), 0.0)
				local_pos = dir * r * sqrt(_rng.randf())
			_:
				dir = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
				if dir.length_squared() < 0.0001:
					dir = Vector3.UP
				dir = dir.normalized()
				var thick := clampf(float(shape.get("thickness", 1.0)), 0.0, 1.0)
				local_pos = dir * r * lerpf(1.0, pow(_rng.randf(), 1.0 / 3.0), thick)
	var scale_v := Vector3(lsc[0], lsc[1], lsc[2])
	var basis: Basis = fx.basis
	var p: Vector3 = fx.pos + basis * ((Vector3(lpos[0], lpos[1], lpos[2]) + lrot * (local_pos * scale_v)) * sc)
	var v: Vector3 = basis * (lrot * dir) * _rand(l.get("speed", [0, 0])) * sc
	var size := _rand(l.get("size", [1, 1])) * sc
	var size_v := Vector2(size * absf(scale_v.x), size * absf(scale_v.y))
	if l.has("size3d"):
		var s3: Array = l.size3d
		size_v = Vector2(float(s3[0]) * sc * absf(scale_v.x), float(s3[1]) * sc * absf(scale_v.y))
	var cols: Array = l.get("color", [[1, 1, 1, 1], [1, 1, 1, 1]])
	var c0: Array = cols[0]
	var c1: Array = cols[1] if cols.size() > 1 else cols[0]
	var k := _rng.randf()
	var tint: Array = l.get("tint", [1, 1, 1, 1])
	var col := Color(lerpf(c0[0], c1[0], k) * tint[0], lerpf(c0[1], c1[1], k) * tint[1], lerpf(c0[2], c1[2], k) * tint[2], lerpf(c0[3], c1[3], k) * tint[3])
	var tiles: Array = l.get("tiles", [1, 1])
	var frames_total := int(tiles[0]) * int(tiles[1])
	var spin_r: Array = l.get("spin", [])
	fx.state[i].alive += 1
	_sprites.append({"fx": fx, "layer_i": i, "l": l, "key": _layer_key(l), "pos": p, "vel": v,
		"age": 0.0, "life": maxf(_rand(l.get("life", [1, 1])), 0.01), "size": size_v, "color": col,
		"rot": -_rand(l.get("rotation", [0, 0])), "spin": -_rand(spin_r) if not spin_r.is_empty() else 0.0,
		"frame0": _rand(l.get("start_frame", [0, 0])), "frames": frames_total,
		"lbasis": basis * lrot})


func _curve(arr: Array, t: float) -> float:
	if arr.is_empty():
		return 1.0
	var x := clampf(t, 0.0, 1.0) * (arr.size() - 1)
	var i := mini(int(x), arr.size() - 2)
	if arr.size() == 1:
		return float(arr[0])
	return lerpf(float(arr[i]), float(arr[i + 1]), x - i)


func _curve_color(arr: Array, t: float) -> Color:
	if arr.is_empty():
		return Color.WHITE
	var x := clampf(t, 0.0, 1.0) * (arr.size() - 1)
	var i := mini(int(x), arr.size() - 2)
	var a: Array = arr[i]
	var b: Array = arr[i + 1]
	var f := x - i
	return Color(lerpf(a[0], b[0], f), lerpf(a[1], b[1], f), lerpf(a[2], b[2], f), lerpf(a[3], b[3], f))


func _update_particle(s: Dictionary, delta: float) -> void:
	var l: Dictionary = s.l
	var t: float = s.age / s.life
	if l.has("drag"):
		var mx := float(l.get("max_speed", 0.0)) * float(s.fx.scale)
		var sp: float = s.vel.length()
		if sp > mx:
			s.vel *= lerpf(1.0, mx / sp, clampf(float(l.drag), 0.0, 1.0))
	var g := float(l.get("gravity", 0.0))
	if g != 0.0:
		s.vel += Vector3.DOWN * 9.81 * g * float(s.fx.scale) * delta
	s.pos += s.vel * delta
	s.rot += s.spin * delta
	var grow := _curve(l.get("size_curve", []), t)
	var grow_y := _curve(l.get("size_curve_y", []), t) if l.has("size_curve_y") else grow
	var w: float = s.size.x * grow
	var h: float = s.size.y * grow_y
	if w <= 0.0001 or h <= 0.0001:
		return
	var col: Color = s.color * _curve_color(l.get("color_curve", []), t)
	if col.a <= 0.003:
		return
	var frame := 0.0
	if s.frames > 1:
		var ft := _curve(l.get("frames", []), t) * float(l.get("cycles", 1.0))
		frame = fmod(floorf(s.frame0 + ft * s.frames), s.frames)
	var right: Vector3
	var up: Vector3
	var normal: Vector3
	var center: Vector3 = s.pos
	var mode := str(l.get("mode", "billboard"))
	if mode == "stretch":
		var v: Vector3 = s.vel
		var axis := v - _cam_basis.z * v.dot(_cam_basis.z)
		if axis.length_squared() < 0.000001:
			axis = _cam_basis.y
		axis = axis.normalized()
		right = axis.cross(_cam_basis.z).normalized()
		up = axis
		normal = _cam_basis.z
		h = w * float(l.get("length_scale", 2.0)) + v.length() * float(l.get("velocity_scale", 0.0))
	elif str(l.get("align", "view")) == "view" and mode == "billboard":
		right = _cam_basis.x
		up = _cam_basis.y
		normal = _cam_basis.z
	elif mode == "flat":
		var b: Basis = s.fx.basis
		right = b.x
		up = -b.z
		normal = b.y
	else:
		var lb: Basis = s.lbasis
		right = lb.x
		up = lb.y
		normal = lb.z
	if s.rot != 0.0:
		var c := cos(s.rot)
		var sn := sin(s.rot)
		var r2 := right * c + up * sn
		up = up * c - right * sn
		right = r2
	if mode == "plane_left":
		center += right * w * 0.5
	_push(s.key, l, Basis(right * w, up * h, normal), center, col, frame, float(s.fx.shift), float(s.fx.sat))


func _draw_shot(s: Dictionary) -> void:
	var e: Dictionary = s.shot
	if e.has("procedural"):
		if _procedural == null:
			_procedural = PROCEDURAL.new(self)
		_procedural.draw(s, _cam_basis)
		return
	var t: float = s.age / s.life
	var frames := int(e.get("frames", 1))
	var frame := float(mini(int(t * frames), frames - 1))
	var col := Color.WHITE * float(e.get("brightness", 1.0))
	col.a = 1.0
	var kind := str(e.get("kind", "line"))
	if kind == "nova":
		var d: float = s.radius * 2.0 * float(e.get("size", 1.0))
		var b := Basis(Vector3.RIGHT * d, Vector3(0, 0, -1) * d, Vector3.UP)
		_push(s.key, e, b, s.from + Vector3(0, 0.06, 0), col, frame, s.shift, s.sat)
		return
	var from: Vector3 = s.from
	var to: Vector3 = s.to
	var dir := to - from
	var dist := dir.length()
	if dist < 0.001:
		return
	dir /= dist
	var side := dir.cross(_cam_basis.z)
	if side.length_squared() < 0.000001:
		side = _cam_basis.x
	side = side.normalized()
	var width := float(e.get("width", 0.4))
	var length := dist
	var center := (from + to) * 0.5
	if kind == "projectile":
		# Geschoss mit eigener Länge fliegt über seine ganze Zeit zum Ziel; der Treffer kommt danach
		# (Effects.add_beam verzögert ihn um die Flugzeit).
		length = minf(width * float(e.get("aspect", 2.0)), dist)
		var travel := clampf(t, 0.0, 1.0)
		center = from.lerp(to - dir * length * 0.5, travel) + dir * length * 0.5 * (1.0 - travel)
	_push(s.key, e, Basis(dir * length, side * width, dir.cross(side)), center, col, frame, s.shift, s.sat)


# --- Licht -------------------------------------------------------------------

## Lichtfarbe = Effektfarbe, gedreht und entsättigt wie die Sprites (FxData._tint).
func _light_color(e: Dictionary, shift: float, sat: float) -> Color:
	var c := Color.from_string(str(e.get("color", "#ffffff")), Color.WHITE)
	return Color.from_hsv(wrapf(c.h + shift, 0.0, 1.0), clampf(c.s * sat, 0.0, 1.0), 1.0)


func _add_light(pos: Vector3, col: Color, scale_factor: float) -> void:
	var p := pos + Vector3(0, LIGHT_HEIGHT, 0)
	var pick: Dictionary = {}
	for l in _lights:
		if l.t < LIGHT_TIME and l.node.position.distance_squared_to(p) < LIGHT_MERGE * LIGHT_MERGE:
			# Treffer daneben: dieses Licht auffrischen und Farben mischen
			l.node.light_color = l.node.light_color.lerp(col, 0.5)
			l.t = 0.0
			return
	for l in _lights:
		if pick.is_empty() or l.t > pick.t:
			pick = l
	if pick.is_empty() or (pick.t < LIGHT_TIME and _lights.size() < MAX_LIGHTS):
		var n := OmniLight3D.new()
		n.shadow_enabled = false
		n.light_specular = 0.4
		n.omni_attenuation = 1.4
		add_child(n)
		pick = {"node": n, "t": LIGHT_TIME, "energy": 0.0}
		_lights.append(pick)
	pick.t = 0.0
	pick.energy = LIGHT_ENERGY * clampf(scale_factor, 0.5, 2.0)
	pick.node.omni_range = LIGHT_RANGE * clampf(scale_factor, 0.5, 2.0)
	pick.node.position = p
	pick.node.light_color = col
	pick.node.visible = true


func _draw_glows() -> void:
	var strength: float = GLOW_STRENGTH * float(FieldStyle.current().get("hit_glow", 1.0))
	if strength <= 0.0:
		return
	for l in _lights:
		if l.t >= LIGHT_TIME:
			continue
		var k: float = 1.0 - l.t / LIGHT_TIME
		var col: Color = l.node.light_color * (strength * pow(k, 1.5) * l.energy / LIGHT_ENERGY)
		col.a = 1.0
		var d: float = GLOW_SIZE * l.node.omni_range / LIGHT_RANGE
		var p: Vector3 = l.node.position
		var b := Basis(Vector3.RIGHT * d, Vector3(0, 0, -1) * d, Vector3.UP)
		_push(GLOW_KEY, {"tex": GLOW_KEY, "flat": true}, b, Vector3(p.x, 0.03, p.z), col, 0.0, 0.0, 1.0)


func _update_lights(delta: float) -> void:
	for l in _lights:
		if l.t >= LIGHT_TIME:
			continue
		l.t += delta
		if l.t >= LIGHT_TIME:
			l.node.visible = false
			continue
		var k: float = 1.0 - l.t / LIGHT_TIME
		l.node.light_energy = l.energy * k * k


# --- Zeichnen -----------------------------------------------------------------

func _layer_key(l: Dictionary) -> String:
	if not l.has("_key"):
		l["_key"] = "%s|%s|%s|%s|%s" % [l.get("tex", ""), l.get("add", true), l.get("tiles", [1, 1]), l.get("uv_scale", [1, 1]), l.get("uv_offset", [0, 0])]
	return l._key


func _shot_key(id: String, e: Dictionary) -> String:
	return "shot|" + id + "|" + str(e.get("sheet", ""))


func _batch(key: String, d: Dictionary) -> Dictionary:
	if _batches.has(key):
		return _batches[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_ADD if bool(d.get("add", true)) else SHADER_MIX
	var tex_path := str(d.get("tex", d.get("sheet", "")))
	if tex_path == GLOW_KEY and not _textures.has(tex_path):
		_textures[tex_path] = _glow_texture()
	if not _textures.has(tex_path):
		_textures[tex_path] = load(tex_path) if ResourceLoader.exists(tex_path) else null
	mat.set_shader_parameter("tex", _textures[tex_path])
	# Flach am Boden (Nova, Lichtschein): keine weichen Kanten, sonst blendet der Boden sie ganz aus
	if bool(d.get("flat", false)) or str(d.get("kind", "")) == "nova":
		mat.set_shader_parameter("soft", 0.0)
	# Lichtschein am Boden ohne glühenden Kern (sonst ein weißer Fleck unter jedem Treffer)
	if str(d.get("tex", "")) == GLOW_KEY:
		mat.set_shader_parameter("vivid", 0.0)
		mat.set_shader_parameter("hot", 0.0)
		mat.set_shader_parameter("halo", 0.0)
	if d.has("sheet"):
		mat.set_shader_parameter("tiles", Vector2(float(d.get("cols", 1)), float(d.get("rows", 1))))
	else:
		var tl: Array = d.get("tiles", [1, 1])
		mat.set_shader_parameter("tiles", Vector2(float(tl[0]), float(tl[1])))
		var us: Array = d.get("uv_scale", [1, 1])
		var uo: Array = d.get("uv_offset", [0, 0])
		mat.set_shader_parameter("uv_scale", Vector2(float(us[0]), float(us[1])))
		mat.set_shader_parameter("uv_offset", Vector2(float(uo[0]), float(uo[1])))
	# nach dem durchsichtigen Spielfeld zeichnen (die MultiMeshes haben eine riesige AABB, die Sortierung nach
	# Abstand hilft da nicht): Lichtschein über dem Boden, Sprites darüber
	mat.render_priority = 1 if bool(d.get("flat", false)) else 2
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = 16
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# sehr große Fläche, damit das MultiMesh nie weggeschnitten wird
	mmi.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	add_child(mmi)
	_batches[key] = {"mmi": mmi, "items": []}
	return _batches[key]


## Runder, weicher Verlauf für den Lichtschein am Boden (ohne eigene Bilddatei).
func _glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _push(key: String, d: Dictionary, b: Basis, origin: Vector3, col: Color, frame: float, shift: float, sat: float) -> void:
	_batch(key, d).items.append([b, origin, col, frame, shift, sat])


## Alle Sprites eines Materials in einem Rutsch ans MultiMesh (Puffer: 12 Transform, 4 Farbe, 4 Custom).
func _flush(batch: Dictionary) -> void:
	var mm: MultiMesh = batch.mmi.multimesh
	var items: Array = batch.items
	var n := items.size()
	if n == 0:
		mm.visible_instance_count = 0
		return
	if n > mm.instance_count:
		mm.instance_count = maxi(n, mm.instance_count * 2)
	var buf := PackedFloat32Array()
	buf.resize(mm.instance_count * 20)
	var o := 0
	for it in items:
		var b: Basis = it[0]
		var p: Vector3 = it[1]
		var c: Color = it[2]
		buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = p.x
		buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = p.y
		buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = p.z
		buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
		buf[o + 16] = it[3]; buf[o + 17] = it[4]; buf[o + 18] = it[5]; buf[o + 19] = 0.0
		o += 20
	mm.buffer = buf
	mm.visible_instance_count = n
