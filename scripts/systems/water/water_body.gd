class_name WaterBody
extends Node3D
## Geometrie und Material einer Wasserfläche; keine Kollisionen oder Spielregeln.

const SURFACE_SHADERS := [preload("res://assets/shaders/water.gdshader"), preload("res://assets/shaders/water_depth.gdshader"), preload("res://assets/shaders/water_refract.gdshader")]
const FALL_SHADER := preload("res://assets/shaders/waterfall.gdshader")
const FLOW := preload("res://assets/textures/water/flow.png")
const NORMAL := preload("res://assets/textures/water/normal.png")
const FOAM := preload("res://assets/textures/water/foam.png")
const NUMBERS := ["speed", "tiling", "normal_strength", "wave_height", "foam_strength", "foam_width", "depth_distance", "refraction", "roughness"]
const COLORS := ["shallow_color", "deep_color", "foam_color"]

var definition: Dictionary
var options: Dictionary
var surface: MeshInstance3D
var material: ShaderMaterial
## Aufprallstellen von Wasserfällen auf dieser Fläche: x, z (lokal), Radius, Strömungs-V für die Schaumschleppe.
var impacts := PackedVector4Array()
const MAX_IMPACTS := 4
## Fallphysik: Erdbeschleunigung in Einheiten/s² und daraus die Bezugsgeschwindigkeit der Fall-Textur.
var gravity := 9.8
var fall_speed := 0.0
var _samples: Array[Vector3] = []
var _distances: Array[float] = []
var path_length := 0.0
var body_width := 1.0
## Grundrisse anderer Gewässer (lokal zu dieser Fläche): dort entsteht kein Uferschaum.
var open_a := PackedVector4Array()
var open_b := PackedVector4Array()

const MAX_OPEN := 16
const HEIGHT_TOLERANCE := 0.35  ## Höhenabstand, ab dem Wasser nicht mehr als „angeschlossen“ gilt.
const LINK_TOLERANCE := 0.35    ## Waagrechter Spielraum für Wasserfall-Anschlüsse.


static func vec(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func valid_vec(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for n in value:
		if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(n)) or absf(float(n)) > 100000.0:
			return false
	return true


static func validate(data: Variant, geometry: Dictionary) -> String:
	if not data is Dictionary:
		return "Eintrag muss ein Objekt sein"
	var kind := str(data.get("kind", ""))
	if kind not in ["pool", "river", "waterfall"]:
		return "kind muss pool, river oder waterfall sein"
	if not data.get("material", {}) is Dictionary:
		return "material muss ein Objekt sein"
	for key in NUMBERS + ["direction_degrees"]:
		if data.get("material", {}).has(key):
			var n = data.material[key]
			if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(n)):
				return "ungültiger Materialwert: " + key
	if kind == "pool":
		var size = data.get("size")
		if not valid_vec(data.get("center")) or not size is Array or size.size() != 2:
			return "pool braucht center [x,y,z] und size [breite,länge]"
		for n in size:
			if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(n)) or float(n) <= 0.0:
				return "Pool-Größe muss positiv und endlich sein"
		var step := maxf(float(geometry.get("step", 0.5)), 0.1)
		if ceilf(float(size[0]) / step) * ceilf(float(size[1]) / step) > int(geometry.get("max_segments", 2048)):
			return "Pool überschreitet das Geometriebudget"
	else:
		var points = data.get("points")
		if not points is Array or points.size() < 2 or points.size() > 64:
			return "Fluss/Wasserfall braucht 2 bis 64 Punkte [x,y,z]"
		var width = data.get("width", 2.0)
		if typeof(width) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(width)) or float(width) <= 0.0 or float(width) > 1000.0:
			return "Breite muss positiv und endlich sein"
		var segments := 0
		for i in points.size():
			if not valid_vec(points[i]):
				return "ungültiger Pfadpunkt"
			if i > 0:
				var distance := vec(points[i]).distance_to(vec(points[i - 1]))
				if distance < 0.001:
					return "benachbarte Pfadpunkte sind identisch"
				segments += ceili(distance / maxf(float(geometry.get("step", 0.5)), 0.1))
		if segments > int(geometry.get("max_segments", 2048)):
			return "Pfad überschreitet das Geometriebudget"
		if kind == "waterfall":
			if vec(points[0]).y <= vec(points[-1]).y:
				return "Wasserfall muss von oben nach unten führen"
			for i in range(1, points.size()):
				if vec(points[i]).y > vec(points[i - 1]).y:
					return "Wasserfall darf nicht bergauf verlaufen"
			if data.has("right") and (not valid_vec(data.right) or Vector2(float(data.right[0]), float(data.right[2])).length() < 0.001):
				return "right braucht eine horizontale Richtung"
			var across := vec(data.get("right", [1, 0, 0]))
			across.y = 0.0
			for i in range(1, points.size()):
				if (vec(points[i]) - vec(points[i - 1])).cross(across).length() < 0.001:
					return "right darf nicht parallel zur Fallrichtung verlaufen"
	return ""


## Waagrechte Grundrisse eines Gewässers als gedrehte Kästen:
## {c: Mitte xz, dir: Längsrichtung xz, h: halbe Länge/Breite, y: Höhe}. Wasserfälle haben keinen.
static func footprints_of(data: Dictionary) -> Array:
	var out := []
	match str(data.get("kind", "")):
		"pool":
			var center := vec(data.center)
			out.append({"c": Vector2(center.x, center.z), "dir": Vector2.RIGHT, "h": Vector2(float(data.size[0]), float(data.size[1])) * 0.5, "y": center.y, "pool": true})
		"river":
			var half := float(data.get("width", 2.0)) * 0.5
			for i in range(1, data.points.size()):
				var a := vec(data.points[i - 1])
				var b := vec(data.points[i])
				var flat := Vector2(b.x - a.x, b.z - a.z)
				if flat.length() < 0.001:
					continue
				# Etwas Überlappung, damit an Knicken keine Schaumnaht entsteht.
				out.append({"c": Vector2(a.x + b.x, a.z + b.z) * 0.5, "dir": flat.normalized(), "h": Vector2(flat.length() * 0.5 + half * 0.5, half), "y": (a.y + b.y) * 0.5})
	return out


## Vorzeichenbehafteter waagrechter Abstand eines Punkts zu einem Grundriss (negativ = innen).
static func box_distance(p: Vector3, box: Dictionary) -> float:
	var c: Vector2 = box.c
	var h: Vector2 = box.h
	var v: Vector2 = Vector2(p.x, p.z) - c
	var d: Vector2 = box.dir
	var q: Vector2 = Vector2(absf(v.dot(d)), absf(v.dot(Vector2(-d.y, d.x)))) - h
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


## Liegt der Punkt in (oder direkt an) Wasser auf gleicher Höhe?
static func in_water(p: Vector3, boxes: Array) -> bool:
	for box in boxes:
		if absf(p.y - float(box.y)) <= HEIGHT_TOLERANCE and box_distance(p, box) <= LINK_TOLERANCE:
			return true
	return false


## Kästen anderer Gewässer an den Shader geben; nächstgelegene zuerst, höchstens MAX_OPEN.
func set_open_neighbors(boxes: Array) -> void:
	var own := footprints_of(definition)
	var here := Vector2(position.x, position.z)
	var scored := []
	for box in boxes:
		var best := INF
		for mine in own:
			best = minf(best, (box.c as Vector2).distance_to(mine.c) - (box.h as Vector2).length() - (mine.h as Vector2).length())
		if own.is_empty():
			best = 0.0
		scored.append([best, box])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	open_a = PackedVector4Array()
	open_b = PackedVector4Array()
	for i in mini(scored.size(), MAX_OPEN):
		var box: Dictionary = scored[i][1]
		var c: Vector2 = (box.c as Vector2) - here
		open_a.append(Vector4(c.x, c.y, box.dir.x, box.dir.y))
		# Ein Fluss, der in ein Becken mündet, blendet dort aus: keine doppelt dunkle Überlappung.
		var fade := 1.0 if box.get("pool", false) and str(definition.kind) == "river" else 0.0
		open_b.append(Vector4(box.h.x, box.h.y, float(box.y) - position.y, fade))
	if material != null:
		_apply_open()


func _apply_open() -> void:
	var a := open_a.duplicate()
	var b := open_b.duplicate()
	a.resize(MAX_OPEN)
	b.resize(MAX_OPEN)
	material.set_shader_parameter("open_count", open_a.size())
	material.set_shader_parameter("open_a", a)
	material.set_shader_parameter("open_b", b)


func configure(data: Dictionary, appearance: Dictionary, geometry: Dictionary) -> void:
	definition = data.duplicate(true)
	options = appearance.duplicate(true)
	surface = MeshInstance3D.new()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.extra_cull_margin = absf(float(options.get("wave_height", 0.025))) + 0.05
	add_child(surface)
	if str(data.kind) == "pool":
		body_width = float(data.size[0])
		path_length = float(data.size[1])
		var plane := PlaneMesh.new()
		plane.size = Vector2(body_width, path_length)
		plane.subdivide_width = maxi(ceili(body_width / float(geometry.step)) - 1, 0)
		plane.subdivide_depth = maxi(ceili(path_length / float(geometry.step)) - 1, 0)
		# Plane-UVs auf Meter umlegen, wie die UVs der Flussbänder.
		var mesh := ArrayMesh.new()
		var arrays := plane.get_mesh_arrays()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in uvs.size():
			uvs[i] *= Vector2(body_width, path_length)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		surface.mesh = mesh
		position = vec(data.center)
	else:
		body_width = float(data.get("width", 2.0))
		if str(data.kind) == "waterfall":
			surface.mesh = _fall_mesh(vec(data.points[0]), vec(data.points[-1]), float(geometry.step))
		else:
			surface.mesh = _ribbon(data.points, float(geometry.step))
	material = ShaderMaterial.new()
	surface.material_override = material
	apply_quality(Display.quality)


func apply_quality(quality: int) -> void:
	material.shader = FALL_SHADER if str(definition.kind) == "waterfall" else SURFACE_SHADERS[clampi(quality, 0, 2)]
	material.render_priority = 1 if str(definition.kind) == "waterfall" else 0
	material.set_shader_parameter("normal_tex", NORMAL)
	material.set_shader_parameter("flow_tex", FLOW)
	material.set_shader_parameter("foam_tex", FOAM)
	for key in NUMBERS:
		if options.has(key):
			material.set_shader_parameter(key, float(options[key]))
	for key in COLORS:
		if options.has(key):
			material.set_shader_parameter(key, Color.from_string(str(options[key]), Color.WHITE))
	material.set_shader_parameter("width", body_width)
	material.set_shader_parameter("body_length", path_length)
	material.set_shader_parameter("pool", str(definition.kind) == "pool")
	material.set_shader_parameter("direction", deg_to_rad(float(options.get("direction_degrees", 0.0))))
	material.set_shader_parameter("detail", 0.0 if quality == Display.LOW else 1.0)
	if str(definition.kind) == "waterfall":
		# Beim Wasserfall ist speed ein Faktor auf die Physik-Geschwindigkeit.
		material.set_shader_parameter("speed", fall_speed * float(options.get("speed", 1.0)))
	else:
		_apply_open()
		_apply_impacts()


func set_time(seconds: float) -> void:
	material.set_shader_parameter("flow_time", seconds)


## Ein Wasserfall schlägt hier auf: Schaumkern, Ringe und (bei Flüssen) eine Schaumschleppe flussab.
func add_impact(point: Vector3, radius: float) -> void:
	if impacts.size() >= MAX_IMPACTS:
		return
	var v := -1.0
	if str(definition.kind) == "river" and not _samples.is_empty():
		var best := INF
		for i in _samples.size():
			var d := Vector2(_samples[i].x - point.x, _samples[i].z - point.z).length()
			if d < best:
				best = d
				v = _distances[i]
	impacts.append(Vector4(point.x - position.x, point.z - position.z, radius, v))
	if material != null:
		_apply_impacts()


func _apply_impacts() -> void:
	var list := impacts.duplicate()
	list.resize(MAX_IMPACTS)
	material.set_shader_parameter("impact_count", impacts.size())
	material.set_shader_parameter("impacts", list)


## Wurfparabel mit waagrechtem Abflug: das Wasser verlässt die Kante mit der Geschwindigkeit,
## die nötig ist, um am Fußpunkt aufzuschlagen, und wird dabei schneller. UV.y ist Flugzeit mal
## Bezugsgeschwindigkeit, sodass die Textur im Fall sichtbar beschleunigt und sich streckt;
## COLOR.r = Belüftung (0 an der Kante, 1 beim Aufprall) steuert Schaum und Deckkraft.
func _fall_mesh(top: Vector3, bottom: Vector3, step: float) -> ArrayMesh:
	var g := maxf(gravity, 0.1)
	var height := maxf(top.y - bottom.y, 0.01)
	var flat := Vector3(bottom.x - top.x, 0.0, bottom.z - top.z)
	var duration := sqrt(2.0 * height / g)
	var launch := flat.length() / duration
	var direction := flat.normalized() if flat.length() > 0.001 else Vector3.ZERO
	var end_speed := sqrt(launch * launch + g * g * duration * duration)
	fall_speed = (launch + end_speed) * 0.5
	var across := vec(definition.get("right", [1.0, 0.0, 0.0]))
	across.y = 0.0
	across = across.normalized()
	var arc := height + flat.length()
	var count := maxi(ceili(arc / maxf(step * 0.5, 0.05)), 12)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := []
	for i in count + 1:
		var t := duration * float(i) / count
		var at := top + direction * launch * t + Vector3.DOWN * 0.5 * g * t * t
		var speed := sqrt(launch * launch + g * g * t * t)
		var aeration := clampf((speed - launch) / maxf(end_speed - launch, 0.01), 0.0, 1.0)
		rows.append([at, t * fall_speed, aeration])
	path_length = float(rows[-1][1])
	for i in count:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var l0: Vector3 = a[0] - across * body_width * 0.5
		var r0: Vector3 = a[0] + across * body_width * 0.5
		var l1: Vector3 = b[0] - across * body_width * 0.5
		var r1: Vector3 = b[0] + across * body_width * 0.5
		var normal := ((b[0] as Vector3) - (a[0] as Vector3)).cross(r0 - l0).normalized()
		for corner in [[l0, 0.0, a], [r0, body_width, a], [l1, 0.0, b], [r0, body_width, a], [r1, body_width, b], [l1, 0.0, b]]:
			st.set_normal(normal)
			st.set_color(Color(float(corner[2][2]), 0.0, 0.0))
			st.set_uv(Vector2(float(corner[1]), float(corner[2][1])))
			st.add_vertex(corner[0])
	st.index()
	st.generate_tangents()
	return st.commit()


## Tangente am Punkt k für einen Abschnitt der Länge span: vorgegebene Richtung oder Catmull-Rom.
static func _tangent(points: Array, dirs: Array, k: int, span: float) -> Vector3:
	if dirs.size() == points.size() and dirs[k] != null:
		return Vector3(float(dirs[k][0]), 0.0, float(dirs[k][1])).normalized() * span
	var a := vec(points[maxi(k - 1, 0)])
	var b := vec(points[mini(k + 1, points.size() - 1)])
	return (b - a) * (0.5 if k > 0 and k < points.size() - 1 else 1.0)


## Flussband entlang einer Hermite-/Catmull-Rom-Kurve durch die Punkte (weiche Ufer statt Knicke).
## Optional `_widths` je Punkt (von WaterSystem._connect_flow, z. B. aufgeweitete Mündung).
## COLOR.g = örtliche Breite / 16 für den Uferschaum im Shader.
func _ribbon(points: Array, step: float) -> ArrayMesh:
	var widths: Array = definition.get("_widths", [])
	var dirs: Array = definition.get("_dirs", [])
	var count_points := points.size()
	var samples: Array[Vector3] = [vec(points[0])]
	var sample_widths: Array[float] = [float(widths[0]) if widths.size() == count_points else body_width]
	for i in range(1, count_points):
		var p1 := vec(points[i - 1])
		var p2 := vec(points[i])
		var span := p1.distance_to(p2)
		var m1 := _tangent(points, dirs, i - 1, span)
		var m2 := _tangent(points, dirs, i, span)
		var w1 := float(widths[i - 1]) if widths.size() == count_points else body_width
		var w2 := float(widths[i]) if widths.size() == count_points else body_width
		var count := maxi(ceili(span / maxf(step * 0.5, 0.05)), 2)
		for j in range(1, count + 1):
			var t := float(j) / count
			var t2 := t * t
			var t3 := t2 * t
			# Hermite-Kurve: Catmull-Rom-Tangenten, an Anschlüssen die vorgegebene Strömungsrichtung.
			samples.append((2.0 * t3 - 3.0 * t2 + 1.0) * p1 + (t3 - 2.0 * t2 + t) * m1 + (-2.0 * t3 + 3.0 * t2) * p2 + (t3 - t2) * m2)
			sample_widths.append(lerpf(w1, w2, smoothstep(0.0, 1.0, t)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var distances: Array[float] = [0.0]
	for i in samples.size():
		var tangent := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var across := Vector3.UP.cross(tangent).normalized()
		if across.is_zero_approx():
			across = Vector3.RIGHT
		var l := samples[i] - across * sample_widths[i] * 0.5
		var r := samples[i] + across * sample_widths[i] * 0.5
		# In engen Kurven darf das Innenufer nicht zurücklaufen (sonst faltet sich das Band).
		if i > 0 and (l - left[i - 1]).dot(tangent) < 0.0:
			l = left[i - 1]
		if i > 0 and (r - right[i - 1]).dot(tangent) < 0.0:
			r = right[i - 1]
		left.append(l)
		right.append(r)
		if i > 0:
			distances.append(distances[-1] + samples[i].distance_to(samples[i - 1]))
	path_length = distances[-1]
	_samples = samples
	_distances = distances
	for i in range(samples.size() - 1):
		var verts := [left[i], right[i], left[i + 1], right[i], right[i + 1], left[i + 1]]
		var wa := sample_widths[i]
		var wb := sample_widths[i + 1]
		var uvs := [Vector2(0, distances[i]), Vector2(wa, distances[i]), Vector2(0, distances[i + 1]), Vector2(wa, distances[i]), Vector2(wb, distances[i + 1]), Vector2(0, distances[i + 1])]
		var ws := [wa, wa, wb, wa, wb, wb]
		var normal := (samples[i + 1] - samples[i]).cross(right[i] - left[i]).normalized()
		for j in 6:
			st.set_normal(normal)
			st.set_color(Color(0.0, float(ws[j]) / 16.0, 0.0, 1.0))
			st.set_uv(uvs[j])
			st.add_vertex(verts[j])
	st.index()
	st.generate_tangents()
	return st.commit()
