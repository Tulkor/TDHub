class_name SvFx
extends Node3D
## Geschosse und kurze Effekte in Tower Survivors (Dev-Optik: einfache leuchtende Formen).
## Geschosse fliegen hier und melden den Einschlag an SvGame.impact(); Strahlen, Ringe, Kegel und
## Todes-Plopp sind reine Anzeige und verschwinden von selbst.

var game  ## SvGame
var shots: Array = []   ## {node, weapon, target, pos, to, kind, t, time, speed, from}
var fading: Array = []  ## {node, t, time, grow}
var lights: Array = []  ## Mündungsblitze {node, t}
var _flashes := 0
const MAX_FLASHES := 10
const FLASH_TIME := 0.09


func shoot(w: SvWeapon, target: SvEnemy, from: Vector3, dir_offset := 0.0) -> void:
	var col: Color = game.type_color(w.type())
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	var big := w.kind() == "lob"
	s.radius = 0.22 if big else 0.1
	s.height = s.radius * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = SvDev.glow(col, 5.0)
	mi.position = from
	add_child(mi)
	var to := target.center()
	if dir_offset != 0.0:
		# Fächer (Schrot): fliegt gerade in eine leicht gedrehte Richtung, trifft den ersten Gegner
		var d := (to - from)
		d.y = 0
		to = from + d.normalized().rotated(Vector3.UP, dir_offset) * w.range_()
		to.y = 0.5
		target = null
	var sh := {"node": mi, "weapon": w, "target": target, "pos": from, "to": to, "from": from,
		"kind": w.kind(), "t": 0.0, "speed": float(w.data.get("speed", 20)), "free": dir_offset != 0.0}
	if big:
		sh.time = maxf(0.35, from.distance_to(to) / sh.speed)
	shots.append(sh)


func step(dt: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var sh: Dictionary = shots[i]
		sh.t += dt
		var node: MeshInstance3D = sh.node
		if sh.kind == "lob":
			var f := clampf(sh.t / sh.time, 0.0, 1.0)
			var p: Vector3 = sh.from.lerp(sh.to, f)
			p.y += sin(f * PI) * maxf(2.5, sh.from.distance_to(sh.to) * 0.35)
			node.position = p
			if f >= 1.0:
				game.impact(sh.weapon, null, sh.to)
				_remove(i)
			continue
		var tgt = sh.target
		if tgt != null and is_instance_valid(tgt) and not tgt.dead:
			sh.to = tgt.center()
		var d: Vector3 = sh.to - node.position
		var mv: float = sh.speed * dt
		if sh.free:
			# Fächer-Kugel: trifft den ersten Gegner nahe der Bahn
			node.position += d.normalized() * mv
			var hit = game.nearest(node.position, 0.6)
			if hit != null:
				game.impact(sh.weapon, hit, node.position)
				_remove(i)
			elif d.length() <= mv:
				_remove(i)
			continue
		if d.length() <= mv + 0.15:
			var live = tgt if tgt != null and is_instance_valid(tgt) and not tgt.dead else null
			game.impact(sh.weapon, live, sh.to)
			_remove(i)
		else:
			node.position += d.normalized() * mv
	for i in range(lights.size() - 1, -1, -1):
		var lf: Dictionary = lights[i]
		lf.t += dt
		var ln: OmniLight3D = lf.node
		if lf.t >= FLASH_TIME:
			ln.queue_free()
			lights.remove_at(i)
			_flashes -= 1
		else:
			ln.light_energy = 3.0 * (1.0 - lf.t / FLASH_TIME)
	for i in range(fading.size() - 1, -1, -1):
		var f: Dictionary = fading[i]
		f.t += dt
		var k: float = f.t / f.time
		var n: Node3D = f.node
		if k >= 1.0:
			n.queue_free()
			fading.remove_at(i)
			continue
		if f.grow > 0.0:
			n.scale = Vector3.ONE * lerpf(0.2, 1.0, k) * f.grow
		var mi := n as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D:
			(mi.material_override as StandardMaterial3D).albedo_color.a = (1.0 - k) * f.alpha


func _remove(i: int) -> void:
	shots[i].node.queue_free()
	shots.remove_at(i)


func _fade(n: Node3D, time: float, grow := 0.0, alpha := 0.9) -> void:
	add_child(n)
	fading.append({"node": n, "t": 0.0, "time": time, "grow": grow, "alpha": alpha})


## Eigenes, durchsichtiges Leucht-Material (additiv, wird beim Ausblenden verändert).
func _own(c: Color, a: float) -> StandardMaterial3D:
	var m := SvDev.flat(c, a).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, a)
	return m


## Mündungsblitz: kurzes Punktlicht an der Waffe (höchstens MAX_FLASHES gleichzeitig).
func flash(at: Vector3, c: Color) -> void:
	if _flashes >= MAX_FLASHES or Display.quality == 0:
		return
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 3.0
	l.omni_range = 3.5
	l.position = at
	add_child(l)
	_flashes += 1
	lights.append({"node": l, "t": 0.0})


## Strahl zwischen zwei Punkten (Blitz, Laser).
func beam(a: Vector3, b: Vector3, c: Color, width := 0.08, time := 0.14) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := a.distance_to(b)
	bm.size = Vector3(width, width, maxf(len, 0.01))
	mi.mesh = bm
	mi.material_override = _own(c, 0.95)
	mi.position = (a + b) * 0.5
	_fade(mi, time)
	if len > 0.01:
		mi.look_at_from_position(mi.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)


## Flacher Ring (Fläche, Nova).
func ring(at: Vector3, radius: float, c: Color, time := 0.35) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(radius - 0.18, 0.05)
	tm.outer_radius = radius
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	mi.material_override = _own(c, 0.9)
	mi.position = Vector3(at.x, 0.25, at.z)
	_fade(mi, time, 1.0)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = radius
	dm.bottom_radius = radius
	dm.height = 0.04
	dm.radial_segments = 32
	disc.mesh = dm
	disc.material_override = _own(c, 0.3)
	disc.position = Vector3(at.x, 0.12, at.z)
	_fade(disc, time * 0.8, 1.0, 0.3)


## Feuerkegel vor der Waffe.
func cone(from: Vector3, dir: Vector3, length: float, angle_deg: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = tan(deg_to_rad(angle_deg * 0.5)) * length
	cm.height = length
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _own(c, 0.45)
	mi.position = from + dir * length * 0.5
	# Zylinder-Achse (Y) in Schussrichtung drehen, Spitze an der Waffe
	mi.basis = Basis(Quaternion(Vector3.DOWN, dir.normalized()))
	_fade(mi, 0.2, 0.0, 0.45)


## Schlag von oben (Orbitalzeiger).
func strike(at: Vector3, c: Color) -> void:
	beam(at + Vector3(0, 18, 0), at, c, 0.5, 0.25)


func pop(at: Vector3, c: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size * 0.6
	s.height = size * 1.2
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = _own(c, 0.8)
	mi.position = at
	_fade(mi, 0.3, 1.4, 0.8)


func clear() -> void:
	for sh in shots:
		sh.node.queue_free()
	shots.clear()
	for f in fading:
		f.node.queue_free()
	fading.clear()
	for lf in lights:
		lf.node.queue_free()
	lights.clear()
	_flashes = 0
