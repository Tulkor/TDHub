class_name SvWorld
extends Node3D
## Umgebung von Tower Survivors (Lukas 2026-11-04): verschneite Eisfläche, immer wieder kleine Inseln mit
## Bäumen und Büschen, alles voller Schnee, weit draußen (außerhalb der Sichtweite) Ozean.
## Modelle: Kiefern, Büsche, Felsen aus assets/models/nature (Quaternius/Kenney, CC0), Schnee als
## Überzug-Shader auf allen nach oben zeigenden Flächen. Eis und Schnee als im Code gemalte Texturen.

const ICE_R := 70.0          ## Radius der Eisfläche, dahinter Wasser
const PINES := ["pine_1", "pine_2", "pine_3", "pine_5"]
const BUSHES := ["bush_common"]
const ROCKS := ["rock_medium_1", "rock_medium_2", "rock_medium_3"]

static var _snow_overlay: ShaderMaterial
static var _scenes: Dictionary = {}

var rng := RandomNumberGenerator.new()


## arena_r: Kampffläche; darin nur kleine Inseln ohne Bäume, damit nichts den Blick verstellt.
func build(arena_r: float, seed_ := 4711) -> void:
	rng.seed = seed_
	_ice()
	_ocean()
	# kleine flache Schneeinseln in der Arena (nur Büsche, Steine)
	_scatter(7, 9.0, arena_r - 2.0, 0.8, 2.0, false)
	# größere Inseln mit Bäumen draußen
	_scatter(26, arena_r + 3.0, ICE_R - 8.0, 2.0, 5.5, true)


func _ice() -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = ICE_R
	c.bottom_radius = ICE_R + 0.6
	c.height = 0.6
	c.radial_segments = 96
	m.mesh = c
	m.position.y = -0.32
	m.material_override = ice_material()
	add_child(m)


## Eis mit Schneeverwehungen: glatte bläuliche Flächen mit Rissen, darauf raue Schneeflecken.
static func ice_material() -> StandardMaterial3D:
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
	var cimg := crack.get_seamless_image(px, px)
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
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(alb)
	m.roughness_texture = ImageTexture.create_from_image(rough)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic_specular = 0.7
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 30.0
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


func _island(at: Vector3, size: float, trees: bool) -> void:
	var isl := Node3D.new()
	isl.position = at
	add_child(isl)
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 20
	sm.rings = 8
	mound.mesh = sm
	mound.scale = Vector3(1.0, rng.randf_range(0.12, 0.22), rng.randf_range(0.7, 1.0))
	mound.rotation.y = rng.randf() * TAU
	mound.material_override = SvDev.snow()
	isl.add_child(mound)
	for k in rng.randi_range(1, 3):
		_prop(isl, ROCKS, size * 0.7, rng.randf_range(0.15, 0.35) * minf(size, 2.5))
	for k in rng.randi_range(1, 3):
		_prop(isl, BUSHES, size * 0.8, rng.randf_range(0.35, 0.7))
	if trees:
		for k in rng.randi_range(1, int(2 + size)):
			_prop(isl, PINES, size * 0.65, rng.randf_range(0.3, 0.6))


func _prop(parent: Node3D, names: Array, spread: float, scale_: float) -> void:
	var n: Node3D = _model(names[rng.randi() % names.size()])
	if n == null:
		return
	var a := rng.randf() * TAU
	var d := rng.randf() * spread
	n.position = Vector3(cos(a) * d, 0.05, sin(a) * d)
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
