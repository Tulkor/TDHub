class_name HdFx
extends Node3D
## Kurzlebige Effekte im Hero-Defense-Modus (Dev-Optik): Treffer-Formen der Heldenfähigkeiten in Blau,
## Novas, Blitze, Fernkampf-Leuchtspuren, Ausweich-Spur. Alles verschwindet von selbst.

var _timed: Array = []   ## [Knoten, Restzeit]


func _add(n: Node3D, life: float) -> void:
	add_child(n)
	_timed.append([n, life])


func _process(dt: float) -> void:
	for i in range(_timed.size() - 1, -1, -1):
		var it: Array = _timed[i]
		it[1] -= dt
		if it[1] <= 0.0 or not is_instance_valid(it[0]):
			if is_instance_valid(it[0]):
				it[0].queue_free()
			_timed.remove_at(i)


## Form einer Heldenfähigkeit kurz aufblitzen lassen (blau).
func flash_shape(t: HdTelegraph, at: Vector3, dir: Vector3) -> void:
	t.position = Vector3(at.x, 0.05, at.z)
	t.aim(dir)
	add_child(t)
	t.trigger(0.3)


## Ring, der sich von der Mitte bis r ausbreitet.
func nova(at: Vector3, r: float, c: Color) -> void:
	var t := HdTelegraph.ring(0.0, r, c)
	t.position = Vector3(at.x, 0.05, at.z)
	add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "progress", 1.0, 0.18)
	tw.tween_callback(func(): t.trigger(0.25))


## Gerade Leuchtspur (Fernkampf-Grundangriff der Gegner, Geschütz des Vorwerks).
func tracer(a: Vector3, b: Vector3, c: Color) -> void:
	_add(_segment(a, b, 0.06, c), 0.12)


## Zackiger Blitz von a nach b.
func bolt(a: Vector3, b: Vector3) -> void:
	var pts: Array = [a]
	for k in [0.33, 0.66]:
		var p := a.lerp(b, k)
		p += Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.4), randf_range(-0.4, 0.4))
		pts.append(p)
	pts.append(b)
	var holder := Node3D.new()
	for i in pts.size() - 1:
		holder.add_child(_segment(pts[i], pts[i + 1], 0.08, Color(0.75, 0.95, 1.0)))
	_add(holder, 0.18)


func dash_trail(at: Vector3, delta: Vector3) -> void:
	var t := HdTelegraph.line(delta.length(), 1.0, HdTelegraph.BLUE)
	flash_shape(t, at, delta)


func _segment(a: Vector3, b: Vector3, w: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var l := a.distance_to(b)
	bm.size = Vector3(w, w, maxf(l, 0.01))
	mi.mesh = bm
	mi.material_override = HdDev.flat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = (a + b) * 0.5
	if l > 0.001:
		mi.look_at_from_position(mi.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	return mi
