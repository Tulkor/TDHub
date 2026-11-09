class_name SvWorld
extends Node3D
## Umgebung von Tower Survivors (Lukas 2026-11-04): verschneite Eisfläche, immer wieder kleine Inseln mit
## Bäumen und Büschen, alles voller Schnee, weit draußen (außerhalb der Sichtweite) Ozean.
## Modelle: Kiefern, Büsche, Felsen aus assets/models/nature (Quaternius/Kenney, CC0), Schnee als
## Überzug-Shader auf allen nach oben zeigenden Flächen. Eis und Schnee als im Code gemalte Texturen.
## Boden als Höhenfeld (height_at, Gegner laufen darauf), unter dem Turm ein Loch im Eis mit Wasser und
## gezackter Bruchkante, treibende Eisschollen darin (Lukas 2026-11-05).

const ICE_R := 70.0          ## Radius der Eisfläche, dahinter Wasser
const HOLE_R := 5.2          ## mittlerer Radius des Lochs unter dem Turm, größer als das Deck (Gegner bleiben bei 6,2 stehen)
const ICE_BOTTOM := -0.75    ## Unterkante des Eises an Bruchkanten (Wasser bei -0.45)
const SEGMENTS := 180
const RINGS := 70
const PINES := ["pine_1", "pine_2", "pine_3", "pine_5"]
const BUSHES := ["bush_common"]
const ROCKS := ["rock_medium_1", "rock_medium_2", "rock_medium_3"]

static var _snow_overlay: ShaderMaterial
static var _scenes: Dictionary = {}
static var _ice_mat: StandardMaterial3D

var rng := RandomNumberGenerator.new()
var _hnoise := FastNoiseLite.new()
var _edge: PackedFloat32Array = []   ## Lochradius je Segment
var _arena_r := 24.0


## arena_r: Kampffläche; darin nur kleine Inseln ohne Bäume, damit nichts den Blick verstellt.
func build(arena_r: float, seed_ := 4711) -> void:
	rng.seed = seed_
	_arena_r = arena_r
	_hnoise.seed = seed_
	_hnoise.frequency = 0.045
	_hnoise.fractal_octaves = 3
	_make_edge()
	_ice()
	_shards()
	_ocean()
	# kleine flache Schneeinseln in der Arena (nur Büsche, Steine)
	_scatter(7, 9.0, arena_r - 2.0, 0.8, 2.0, false)
	# größere Inseln mit Bäumen draußen
	_scatter(26, arena_r + 3.0, ICE_R - 8.0, 2.0, 5.5, true)


## Höhe des Bodens: in der Arena sanft (bis ±0,45), draußen stärker gewellt; am Lochrand flach.
func height_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var amp := lerpf(0.45, 1.8, clampf((r - _arena_r) / 18.0, 0.0, 1.0))
	amp *= clampf((r - HOLE_R) / 3.0, 0.15, 1.0)
	return _hnoise.get_noise_2d(x, z) * amp + 0.05


func _edge_r(ang: float) -> float:
	var f := fposmod(ang / TAU, 1.0) * SEGMENTS
	var i := int(f) % SEGMENTS
	return lerpf(_edge[i], _edge[(i + 1) % SEGMENTS], f - floorf(f))


## Bruchkante: Bruchpunkte in unregelmäßigen Abständen, dazwischen gerade Kanten (wie gebrochenes
## Eis), dazu eine langsame Welle, damit das Loch nicht kreisrund ist.
func _make_edge() -> void:
	var en := FastNoiseLite.new()
	en.seed = rng.randi()
	en.frequency = 0.7
	var breaks: Array = []   # [Winkel, Radius]
	var ang := 0.0
	while ang < TAU - 0.05:
		var slow := en.get_noise_2d(cos(ang) * 2.0, sin(ang) * 2.0) * 0.6
		var r := HOLE_R + slow + rng.randf_range(-0.3, 0.3)
		# ab und zu eine tiefe Kerbe oder ein vorstehender Zacken
		if rng.randf() < 0.18:
			r += rng.randf_range(-0.45, 0.6)
		breaks.append([ang, r])
		ang += rng.randf_range(0.06, 0.32)
	_edge.resize(SEGMENTS)
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var k := 0
		while k + 1 < breaks.size() and breaks[k + 1][0] <= a:
			k += 1
		var p0: Array = breaks[k]
		var p1: Array = breaks[(k + 1) % breaks.size()]
		var a1: float = p1[0] if k + 1 < breaks.size() else TAU
		var f := (a - float(p0[0])) / maxf(a1 - float(p0[0]), 0.001)
		# gerade Kante zwischen zwei Bruchpunkten (in der Ebene, nicht im Radius)
		var v0 := Vector2(cos(p0[0]), sin(p0[0])) * float(p0[1])
		var v1 := Vector2(cos(a1), sin(a1)) * float(p1[1])
		var hit = Geometry2D.line_intersects_line(Vector2.ZERO, Vector2(cos(a), sin(a)), v0, v1 - v0)
		_edge[i] = (hit as Vector2).length() if hit != null else lerpf(float(p0[1]), float(p1[1]), f)


## Eisfläche als Polar-Gitter vom Lochrand bis ICE_R, dazu die senkrechte Bruchwand am Loch.
func _ice() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for ri in RINGS + 1:
		var t := float(ri) / RINGS
		var row := PackedVector3Array()
		for si in SEGMENTS:
			var ang := TAU * si / SEGMENTS
			var r0 := _edge[si]
			var r := lerpf(r0, ICE_R, pow(t, 1.6))
			var x := cos(ang) * r
			var z := sin(ang) * r
			var y := height_at(x, z) if ri > 0 else 0.08 + rng.randf_range(-0.04, 0.06)
			row.append(Vector3(x, y, z))
		pts.append(row)
	for ri in RINGS:
		for si in SEGMENTS:
			var sj := (si + 1) % SEGMENTS
			var a: Vector3 = pts[ri][si]
			var b: Vector3 = pts[ri][sj]
			var c: Vector3 = pts[ri + 1][si]
			var d: Vector3 = pts[ri + 1][sj]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = ice_material()
	add_child(m)
	# Bruchwand: von der Oberkante am Loch senkrecht ins Wasser, leicht unterschnitten
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	for si in SEGMENTS:
		var sj := (si + 1) % SEGMENTS
		var a: Vector3 = pts[0][si]
		var b: Vector3 = pts[0][sj]
		var ia := Vector3(a.x, 0, a.z).normalized()
		var ib := Vector3(b.x, 0, b.z).normalized()
		var a2 := Vector3(a.x, ICE_BOTTOM, a.z) + ia * rng.randf_range(0.05, 0.25)
		var b2 := Vector3(b.x, ICE_BOTTOM, b.z) + ib * rng.randf_range(0.05, 0.25)
		for v in [a, b, a2, b, b2, a2]:
			wall.add_vertex(v)
	wall.generate_normals()
	var w := MeshInstance3D.new()
	w.mesh = wall.commit()
	w.material_override = break_material()
	add_child(w)


## Bruchkante: klares, blaues Eis, glänzend.
static func break_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("5f9cc4")
	m.roughness = 0.15
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = Color("1d4a6a")
	m.emission_energy_multiplier = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Treibende Eisschollen im Loch zwischen Turmfuß und Bruchkante.
func _shards() -> void:
	for i in 14:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(2.5, _edge_r(ang) - 0.35)
		var poly := PackedVector2Array()
		var n := rng.randi_range(4, 6)
		var sz := rng.randf_range(0.25, 0.6)
		for k in n:
			var a := TAU * k / n + rng.randf_range(-0.4, 0.4)
			poly.append(Vector2(cos(a), sin(a)) * sz * rng.randf_range(0.6, 1.2))
		var mi := MeshInstance3D.new()
		mi.mesh = SvPlatform.prism(poly, -0.12, 0.06)
		mi.material_override = ice_material()
		mi.position = Vector3(cos(ang) * r, -0.42, sin(ang) * r)
		mi.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
		add_child(mi)


## Eis mit Schneeverwehungen: glatte bläuliche Flächen mit Rissen, darauf raue Schneeflecken.
static func ice_material() -> StandardMaterial3D:
	if _ice_mat:
		return _ice_mat
	var px := 512
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var crack := FastNoiseLite.new()
	crack.seed = 9
	crack.noise_type = FastNoiseLite.TYPE_CELLULAR
	crack.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	crack.frequency = 0.02
	# nahtlos kachelbar, sonst sieht man die Wiederholung als Linie
	var nimg := noise.get_seamless_image(px, px)
	nimg.convert(Image.FORMAT_RGBA8)
	var cimg := crack.get_seamless_image(px, px)
	cimg.convert(Image.FORMAT_RGBA8)
	var alb := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var rough := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var n := nimg.get_pixel(x, y).r * 2.0 - 1.0
			var snow := smoothstep(-0.15, 0.15, n)
			var cr := 1.0 - smoothstep(0.0, 0.08, cimg.get_pixel(x, y).r)
			var ice := Color("a9c8da").lerp(Color("86aac2"), clampf(-n * 1.5, 0.0, 1.0))
			ice = ice.lerp(Color("e3f0fa"), cr * 0.5)
			var col := ice.lerp(Color("eef3f8"), snow)
			alb.set_pixel(x, y, col)
			var r := lerpf(0.12, 0.85, snow)
			rough.set_pixel(x, y, Color(r, r, r))
	alb.generate_mipmaps()
	rough.generate_mipmaps()
	# Oberfläche: Höhen aus Schnee und Rissen als Normal-Map (Verwehungen, Rillen)
	var bump := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var hgt := nimg.get_pixel(x, y).r * 0.7 + (1.0 - cimg.get_pixel(x, y).r) * 0.3
			bump.set_pixel(x, y, Color(hgt, hgt, hgt))
	bump.bump_map_to_normal_map(5.0)
	bump.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(bump)
	m.normal_scale = 0.8
	m.albedo_texture = ImageTexture.create_from_image(alb)
	m.roughness_texture = ImageTexture.create_from_image(rough)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic_specular = 0.7
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 30.0
	_ice_mat = m
	return m


func _ocean() -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(900, 900)
	p.subdivide_width = 0
	p.subdivide_depth = 0
	m.mesh = p
	m.position.y = -0.45
	var sh := ShaderMaterial.new()
	sh.shader = load("res://scripts/survivors/sv_ocean.gdshader")
	m.material_override = sh
	add_child(m)


## count Inseln zwischen r0 und r1 (Abstand zur Mitte), Größe s0–s1; trees: mit Kiefern.
func _scatter(count: int, r0: float, r1: float, s0: float, s1: float, trees: bool) -> void:
	for i in count:
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf_range(r0 * r0, r1 * r1))
		var at := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		var size := rng.randf_range(s0, s1)
		_island(at, size, trees)


## Insel mit unregelmäßigem Umriss (gestreckt, gebuchtet), flacher Kuppe und Schnee.
func _island(at: Vector3, size: float, trees: bool) -> void:
	var isl := Node3D.new()
	# auf die höchste Stelle unter der Insel setzen, sonst versinkt sie in den Bodenwellen
	var hmax := height_at(at.x, at.z)
	for k in 8:
		var ang0 := TAU * k / 8.0
		hmax = maxf(hmax, height_at(at.x + cos(ang0) * size * 1.4, at.z + sin(ang0) * size * 1.4))
	at.y = hmax - 0.1
	isl.position = at
	isl.rotation.y = rng.randf() * TAU
	add_child(isl)
	var segs := 40
	var rings := 7
	var on := FastNoiseLite.new()
	on.seed = rng.randi()
	on.frequency = 1.1
	var stretch := rng.randf_range(1.0, 1.9)
	var top := size * rng.randf_range(0.14, 0.26)
	var outline := PackedFloat32Array()
	for si in segs:
		var ang := TAU * si / segs
		var rr := size * (1.0 + on.get_noise_2d(cos(ang) * 1.5, sin(ang) * 1.5) * 0.55)
		# gestreckt: lang in x, schmal in z
		rr *= Vector2(cos(ang) * stretch, sin(ang)).length() / Vector2(cos(ang), sin(ang)).length()
		outline.append(maxf(rr, size * 0.35))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for ri in rings + 1:
		var t := float(ri) / rings
		var row := PackedVector3Array()
		for si in segs:
			var ang := TAU * si / segs
			var r := outline[si] * (1.0 - t)
			var h := top * pow(t, 0.6) + on.get_noise_2d(cos(ang) * r, sin(ang) * r) * top * 0.25 * t
			row.append(Vector3(cos(ang) * r, h - 0.02 if ri == 0 else h, sin(ang) * r))
		pts.append(row)
	for ri in rings:
		for si in segs:
			var sj := (si + 1) % segs
			for v in [pts[ri][si], pts[ri][sj], pts[ri + 1][si], pts[ri][sj], pts[ri + 1][sj], pts[ri + 1][si]]:
				st.add_vertex(v)
	st.generate_normals()
	var mound := MeshInstance3D.new()
	mound.mesh = st.commit()
	mound.material_override = SvDev.snow()
	isl.add_child(mound)
	for k in rng.randi_range(1, 3):
		_prop(isl, ROCKS, size * 0.7, rng.randf_range(0.15, 0.35) * minf(size, 2.5), top)
	for k in rng.randi_range(1, 3):
		_prop(isl, BUSHES, size * 0.8, rng.randf_range(0.35, 0.7), top)
	if trees:
		for k in rng.randi_range(1, int(2 + size)):
			_prop(isl, PINES, size * 0.65, rng.randf_range(0.3, 0.6), top)


func _prop(parent: Node3D, names: Array, spread: float, scale_: float, top := 0.0) -> void:
	var n: Node3D = _model(names[rng.randi() % names.size()])
	if n == null:
		return
	var a := rng.randf() * TAU
	var d := rng.randf() * spread
	n.position = Vector3(cos(a) * d, top * (1.0 - d / maxf(spread * 1.4, 0.01)) * 0.8, sin(a) * d)
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * scale_
	parent.add_child(n)
	snow_cover(n)


static func _model(name: String) -> Node3D:
	if not _scenes.has(name):
		var path := "res://assets/models/nature/%s.glb" % name
		_scenes[name] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scenes[name]
	return ps.instantiate() if ps else null


## Schnee auf alle nach oben zeigenden Flächen eines Modells legen (Überzug-Shader).
static func snow_cover(n: Node) -> void:
	if _snow_overlay == null:
		_snow_overlay = ShaderMaterial.new()
		_snow_overlay.shader = load("res://scripts/survivors/sv_snow.gdshader")
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_overlay = _snow_overlay
	for c in n.get_children():
		snow_cover(c)
