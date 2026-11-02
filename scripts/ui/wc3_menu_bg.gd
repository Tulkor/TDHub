class_name Wc3MenuBg
extends Node3D
## 3D-Hintergrund des Hauptmenüs (Wc3Theme): Lichtung im Nachtwald mit Kristallschrein. Großer blauer Kristall,
## wie geschliffenes Glas mit leuchtendem Kern auf einem Kiesplatz, bemooster Säulenring, kleine bunte Kristalle,
## Kiesweg, Kirche mit Friedhof hinter den Bäumen, zwei Laternen mit Flammen, ziehende Wolken und Tiere, die weit
## hinten vorbeilaufen. Himmel = Nacht-Panorama mit Mond (assets/textures/menu/).

const M := "res://assets/models/"
const SKY := "res://assets/textures/menu/nachthimmel_mond.jpg"
## Stelle des Monds im Bild (Anteil der Breite/Höhe), daraus kommt die Richtung des Mondlichts.
const MOON_SCREEN := Vector2(0.56, 0.13)
## Flackern und Pulsieren wiederholen sich nach dieser Zeit (Sekunden).
const LOOP := 4.0

var rng := RandomNumberGenerator.new()
var camera: Camera3D
var moon: DirectionalLight3D
var _flames: Array = []   ## [OmniLight3D, Glühen (MeshInstance3D), Phase]
var _animals: Array = []  ## je Tier ein Dictionary, siehe _animal()
var _clouds: ShaderMaterial
var _core_light: OmniLight3D
var _core_mat: StandardMaterial3D
var _time := 0.0
var _tex_cache := {}

const FOG_WALL := preload("res://scripts/ui/wc3_nebelwand.gdshader")
const DETAIL := preload("res://assets/textures/ground/concrete.jpg")
const DETAIL_NORMAL := preload("res://assets/textures/ground/concrete_normal.jpg")
const STONE := preload("res://scripts/ui/wc3_stein.gdshader")
const GROUND := preload("res://scripts/ui/wc3_boden.gdshader")
const CRYSTAL := preload("res://scripts/ui/wc3_kristall.gdshader")
const FLAME := preload("res://scripts/ui/wc3_flamme.gdshader")
const CLOUDS := preload("res://scripts/ui/wc3_wolken.gdshader")
const GT := "res://assets/textures/ground/"
## Mitte des Schreins, Radius des Kiesplatzes darunter
const SHRINE := Vector3(-3.5, 0, 0)
const PLAZA_R := 5.6
## Kiesweg (x, z) vom Vordergrund über den Platz zur Kirche
const PATH: Array[Vector2] = [Vector2(4.5, 32), Vector2(2.6, 21), Vector2(0.4, 12), Vector2(-2.4, 5.5), Vector2(-3.5, 0),
	Vector2(-3.1, -10), Vector2(-2.2, -21)]
const CHURCH := Vector3(-2, 0, -26)
## Höhe des breiten Kirchenschiffs (ohne Turm)
const CHURCH_NAVE := 6.0
## Friedhof links hinter dem Schrein, neben dem Weg zur Kirche: Ecke hinten links (x, z) und Größe
const GRAVEYARD := Rect2(-31.0, -27.5, 12.0, 10.0)
## Hier laufen die Tiere quer durchs Bild (z), weit hinter dem Schrein
const ANIMAL_Z := -12.5
const CAM_POS := Vector3(5.5, 4.2, 20)


func _ready() -> void:
	rng.seed = 7
	_environment()
	_ground()
	_shrine()
	_surroundings()
	_graveyard()
	_forest()
	_animals_setup()
	_fog_wall()
	_clouds_setup()
	camera = Camera3D.new()
	camera.fov = 45
	add_child(camera)
	camera.position = CAM_POS
	camera.look_at(Vector3(0.5, 2.2, -2), Vector3.UP)
	camera.make_current()
	# Mondlicht kommt aus der Richtung, in der der Mond im Bild steht
	var vs := get_viewport().get_visible_rect().size
	var to_moon := camera.project_ray_normal(vs * MOON_SCREEN)
	moon.look_at_from_position(Vector3.ZERO, -to_moon, Vector3.UP)
	_clouds.set_shader_parameter("moon_dir", to_moon)
	_animate(0.0)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, LOOP)
	_animate(_time / LOOP)
	_walk(delta)


func _animate(t: float) -> void:
	var pulse := 0.85 + 0.15 * sin(TAU * t)
	_core_light.light_energy = 3.0 * pulse
	_core_mat.emission_energy_multiplier = 1.3 * pulse
	for f in _flames:
		var k := _flicker(t, f[2])
		f[0].light_energy = 2.0 * k
		f[1].scale = Vector3.ONE * (0.85 + 0.2 * k)


## Flackern aus drei Sinuswellen mit ganzzahligen Perioden je LOOP.
func _flicker(t: float, ph: float) -> float:
	return 1.0 + 0.16 * sin(TAU * 3.0 * t + ph) + 0.10 * sin(TAU * 7.0 * t + ph * 2.3) + 0.07 * sin(TAU * 13.0 * t + ph * 0.7)


func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(SKY)
	pano.energy_multiplier = 1.6
	sky.sky_material = pano
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3b4a78")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = Display.q("glow")
	env.glow_intensity = 0.7
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("2a3050")
	env.fog_density = 0.032
	env.fog_sky_affect = 0.12
	# Bodennebel: unterhalb der Baumkronen dichter (Lukas 2026-11-02), darüber klar für Mond und Sterne
	env.fog_height = 7.0
	env.fog_height_density = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("b8d8e8")
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	add_child(moon)


func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	g.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = GROUND
	for k in ["grass", "dirt", "gravel"]:
		var file: String = "grass_a" if k == "grass" else k
		gm.set_shader_parameter(k, load(GT + file + ".jpg"))
		gm.set_shader_parameter(k + "_n", load(GT + file + "_normal.jpg"))
	gm.set_shader_parameter("plaza", Vector3(SHRINE.x, SHRINE.z, PLAZA_R))
	gm.set_shader_parameter("path_pts", PackedVector2Array(PATH))
	g.material_override = gm
	add_child(g)


## Abstand eines Punkts (x, z) zum Kiesweg oder Platz: unter 0 = auf dem Kies.
func _path_dist(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var d := q.distance_to(Vector2(SHRINE.x, SHRINE.z)) - PLAZA_R
	for i in PATH.size() - 1:
		d = minf(d, Geometry2D.get_closest_point_to_segment(q, PATH[i], PATH[i + 1]).distance_to(q) - 1.5)
	return d


## Schrein: großer Kristall auf Sockel mit leuchtendem Kern, Säulenring, kleine Kristalle.
func _shrine() -> void:
	var c := SHRINE
	# Sockel so breit wie der Kristall, sonst wirkt er schwebend (Lukas 2026-11-02)
	var base := _place("nature/statue_block.glb", c, 0.9, 0.4, 0.7)
	base.scale *= Vector3(3.4, 1.0, 3.4)
	# Hülle wie geschliffenes Glas (wc3_kristall.gdshader): bricht den Kern und den Wald dahinter
	var shell := _place("crystals/quaternius_big_crystal.glb", c + Vector3(0, 0.9, 0), 3.2, 0.4)
	var sm := ShaderMaterial.new()
	sm.shader = CRYSTAL
	_recolor(shell, sm)
	_light(c + Vector3(0, 2.5, 0), Color("6cc8ff"), 5.0, 12.0)
	# Leuchtender Kern (Lukas, 2026-10-28): kleinere Kopie, scheint durch die Hülle
	var core := _place("crystals/quaternius_big_crystal.glb", c + Vector3(0, 1.55, 0), 1.7, 1.3)
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.2, 0.5, 0.9)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color("4fa8ff")
	_core_mat.emission_energy_multiplier = 1.8
	_core_mat.rim_enabled = true
	_core_mat.rim = 1.0
	_recolor(core, _core_mat)
	_core_light = _light(c + Vector3(0, 2.4, 0), Color("8fd8ff"), 3.0, 7.0)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var p := c + Vector3(cos(a) * 4.6, 0, sin(a) * 4.6)
		if i % 3 == 1:
			_place("nature/statue_column_damaged.glb", p, 2.2, -a, 1.0)
		else:
			_place("nature/statue_column.glb", p, 3.6, -a, 0.8)
	var cols := [Color("ff4f9a"), Color("9a6cff"), Color("4fffb0"), Color("ffcc4f")]
	for i in 7:
		var p := c + Vector3(rng.randf_range(-7, 6), 0, rng.randf_range(-4, 6))
		var k := _place("crystals/crystal_%02d.glb" % rng.randi_range(0, 27), p, rng.randf_range(0.5, 1.1), rng.randf() * TAU)
		var col: Color = cols[i % cols.size()]
		_recolor(k, _glow_mat(col.darkened(0.3), 0.8))
		_light(p + Vector3(0, 0.6, 0), col, 1.2, 4.0)


## Kirche, Laternen, Felsen und Pflanzen rund um die Lichtung.
func _surroundings() -> void:
	var c := SHRINE
	_place("scenery/church.glb", CHURCH, 13.0, 0.25)
	_light(CHURCH + Vector3(0, 4, 4), Color("ffaa55"), 4.0, 10.0)
	for p in [Vector3(-8.5, 0, 3.5), Vector3(1.0, 0, 3.5)]:
		var post := _place("scenery/lightpost_single.glb", p, 2.6)
		_darken(post, 0.32)
		_flame(p + Vector3(0, 2.1, 0.57))
	for i in 14:
		var p := Vector3(rng.randf_range(-14, 10), 0, rng.randf_range(-10, 8))
		if p.distance_to(c) < 5.5 or _path_dist(p) < 0.6:
			continue
		_place("nature/rock_medium_%d.glb" % rng.randi_range(1, 3), p, rng.randf_range(0.4, 0.9), rng.randf() * TAU, 0.6)
	var plants := ["hp_bush011", "fern_1", "bush_common", "mushroom_red_group", "hp_weed011"]
	for i in 30:
		var p := Vector3(rng.randf_range(-16, 12), 0, rng.randf_range(-12, 10))
		if p.distance_to(c) < PLAZA_R + 0.3 or _path_dist(p) < 0.4:
			continue
		_place("nature/%s.glb" % plants[i % plants.size()], p, rng.randf_range(0.5, 1.2), rng.randf() * TAU)


## Friedhof links neben der Kirche, von der Lichtung aus durch die Bäume zu sehen: Eisenzaun, Grabsteine in
## Reihen, Gruft und Holzkreuze, schwaches kaltes Licht.
func _graveyard() -> void:
	var r := GRAVEYARD
	var stones := ["round", "cross", "bevel", "broken", "wide", "decorative", "cross_large"]
	for row in 4:
		for col in 6:
			if rng.randf() < 0.18:
				continue
			var p := Vector3(r.position.x + 1.2 + col * 1.75 + rng.randf_range(-0.3, 0.3), 0,
				r.position.y + 2.0 + row * 2.3 + rng.randf_range(-0.3, 0.3))
			var kind: String = stones[rng.randi() % stones.size()]
			if rng.randf() < 0.15:
				_place("scenery/cross_wood.glb", p, rng.randf_range(1.0, 1.3), rng.randf_range(-0.3, 0.3))
			else:
				_place("scenery/gravestone_%s.glb" % kind, p, rng.randf_range(0.8, 1.2), rng.randf_range(-0.25, 0.25))
			if rng.randf() < 0.3:
				_place("scenery/grave.glb", p + Vector3(0, 0, 0.9), 0.3, 0.0)
	_place("scenery/crypt.glb", Vector3(r.position.x + 2.2, 0, r.position.y + 1.4), 2.8, 0.15)
	_place("scenery/urn_round.glb", Vector3(r.end.x - 1.5, 0, r.position.y + 1.0), 0.9)
	# Zaun vorn und links, ein Stück umgefallen
	var seg := 1.25
	for i in int(r.size.x / seg):
		var kind := "iron_fence_damaged" if i == 3 or i == 4 else "iron_fence"
		_place("scenery/%s.glb" % kind, Vector3(r.position.x + seg * (i + 0.5), 0, r.end.y), 1.1)
	for i in int(r.size.y / seg):
		_place("scenery/iron_fence.glb", Vector3(r.position.x, 0, r.position.y + seg * (i + 0.5)), 1.1, PI / 2)
	_light(Vector3(r.get_center().x, 3.0, r.get_center().y), Color("8fa8d8"), 1.6, 12.0)


## Wald rund um die Lichtung. Hinten ein dichter Ring aus hohen Bäumen und großen Büschen, damit der Übergang
## vom Boden zum Himmel keine gerade Linie ist (Lukas 2026-11-02). Frei bleiben: der Blick auf Kirche und Friedhof
## (dort nur einzelne Bäume), der Weg und die Spur der Tiere.
func _forest() -> void:
	var trees := ["pine_1", "pine_2", "pine_3", "pine_5", "common_tree_3", "common_tree_4", "common_tree_5"]
	var bushes := ["hp_bush011", "hp_bush021", "hp_bush031", "hp_bush041", "bush_common", "plant_1_big", "plant_7_big"]
	var cam := Vector2(CAM_POS.x, CAM_POS.z)
	var church := Vector2(CHURCH.x, CHURCH.z)
	var yard := Vector2(GRAVEYARD.get_center().x, GRAVEYARD.get_center().y)
	for i in 300:
		var a := rng.randf() * TAU
		var r := rng.randf_range(13, 51) if i < 120 else rng.randf_range(33, 51)
		var p := Vector3(cos(a) * r - 3, 0, sin(a) * r - 6)
		var q := Vector2(p.x, p.z)
		if p.z > 6 and absf(p.x + 1) < 10:
			continue
		if _path_dist(p) < 1.5 or absf(p.z - ANIMAL_Z) < 1.8:
			continue
		# Sichtachse zur Kirche frei, zum Friedhof nur lichter
		# Kirche zwischen den Bäumen, aber nicht verdeckt: vorn breite Gasse, an der Kirche schmal, dort stehen Stämme daneben
		var lane := 3.5 if p.z < CHURCH.z + 7 else 7.0
		if p.z < -4 and p.z > CHURCH.z - 9 and Geometry2D.get_closest_point_to_segment(q, cam, church).distance_to(q) < lane:
			continue
		if GRAVEYARD.grow(1.0).has_point(q):
			continue
		if p.z < -4 and Geometry2D.get_closest_point_to_segment(q, cam, yard).distance_to(q) < 5.0 and rng.randf() < 0.75:
			continue
		var h := rng.randf_range(7, 13) if r < 33 else rng.randf_range(9, 21)
		# rechts neben der Kirche nur knapp über das Kirchenschiff (Lukas 2026-11-02)
		var ang := _view_angle(p)
		if p.z < -14 and ang > 2.0 and ang < 12.0:
			h = minf(h, _church_line(p))
		_place("nature/%s.glb" % trees[rng.randi() % trees.size()], p, h, rng.randf() * TAU)
	# Von Hand: Nadelbäume links hinten in die Lücke, zwei flankieren die Kirche, rechts ein niedriger davor
	_place("nature/pine_2.glb", Vector3(-27, 0, -35), 17.0, 0.7)
	_place("nature/pine_3.glb", Vector3(-35, 0, -30), 14.5, 2.1)
	_place("nature/pine_1.glb", Vector3(-41, 0, -27), 16.0, 0.2)
	_place("nature/pine_1.glb", Vector3(-8.5, 0, -21), 11.0, 1.3)
	_place("nature/pine_5.glb", Vector3(4.2, 0, -21), _church_line(Vector3(4.2, 0, -21)), 0.4)
	_place("nature/pine_2.glb", Vector3(1.6, 0, -17.5), 5.5, 2.8)
	# Unterholz im hinteren Ring: große Büsche zwischen den Stämmen
	for i in 110:
		var a := rng.randf() * TAU
		var r := rng.randf_range(28, 50)
		var p := Vector3(cos(a) * r - 3, 0, sin(a) * r - 6)
		if p.z > 6 and absf(p.x + 1) < 10:
			continue
		if GRAVEYARD.grow(1.0).has_point(Vector2(p.x, p.z)) or absf(p.z - ANIMAL_Z) < 1.8:
			continue
		_place("nature/%s.glb" % bushes[rng.randi() % bushes.size()], p, rng.randf_range(1.6, 4.5), rng.randf() * TAU)


## Waagrechter Blickwinkel (Grad) von der Kamera aus, rechts von der Kirche positiv.
func _view_angle(p: Vector3) -> float:
	var vc := Vector2(CHURCH.x - CAM_POS.x, CHURCH.z - CAM_POS.z)
	var vp := Vector2(p.x - CAM_POS.x, p.z - CAM_POS.z)
	return rad_to_deg(atan2(vc.cross(vp), vc.dot(vp)))


## Baumhöhe an Stelle p, deren Spitze von der Kamera aus knapp über dem Kirchenschiff (CHURCH_NAVE) liegt.
func _church_line(p: Vector3) -> float:
	var dc := Vector2(CHURCH.x - CAM_POS.x, CHURCH.z - CAM_POS.z).length()
	var dp := Vector2(p.x - CAM_POS.x, p.z - CAM_POS.z).length()
	return CAM_POS.y + (CHURCH_NAVE + 0.8 - CAM_POS.y) * dp / dc


## Tiere, die hinter dem Schrein quer durchs Bild laufen (Lukas 2026-11-02): Hirsch und Reh zusammen von links,
## später ein Fuchs von rechts. Jedes läuft seine Strecke, wartet unsichtbar und beginnt von vorn.
func _animals_setup() -> void:
	_animal("stag", 2.1, 1.35, -38.0, 32.0, ANIMAL_Z, -17.0, 30.0)
	_animal("deer", 1.55, 1.35, -38.0, 32.0, ANIMAL_Z + 0.9, -20.5, 30.0)
	_animal("fox", 0.75, 1.1, 30.0, -38.0, ANIMAL_Z - 0.6, 40.0, 25.0)
	# schwaches, kaltes Licht über der Spur, damit die Tiere sich vom Nebel abheben
	_light(Vector3(-15, 6, ANIMAL_Z + 3), Color("9fb4e0"), 1.2, 16.0)


func _animal(kind: String, h: float, speed: float, from_x: float, to_x: float, z: float, x0: float, pause: float) -> void:
	var n := _place("scenery/tiere/%s.glb" % kind, Vector3(x0, 0, z), h, PI / 2 * signf(to_x - from_x))
	for ap: AnimationPlayer in n.find_children("*", "AnimationPlayer", true, false):
		if not ap.has_animation("Walk"):
			continue
		ap.get_animation("Walk").loop_mode = Animation.LOOP_LINEAR
		ap.play("Walk")
		ap.seek(rng.randf() * 0.8, true)
	# Startpunkt außerhalb der Strecke = erst nach einer Pause loslaufen
	var wait := 0.0
	if (x0 - from_x) * (to_x - from_x) < 0 or absf(x0 - from_x) > absf(to_x - from_x):
		wait = absf(x0 - from_x) / speed
		x0 = from_x
	n.position.x = x0
	n.visible = wait <= 0.0
	_animals.append({"node": n, "speed": speed, "from": from_x, "to": to_x, "wait": wait, "pause": pause})


func _walk(delta: float) -> void:
	for a in _animals:
		var n: Node3D = a.node
		if a.wait > 0.0:
			a.wait -= delta
			if a.wait <= 0.0:
				n.position.x = a.from
				n.visible = true
			continue
		var dir := signf(a.to - a.from)
		n.position.x += dir * a.speed * delta
		if (n.position.x - a.to) * dir >= 0.0:
			n.visible = false
			a.wait = a.pause


## Nebelwand hinter dem Wald: ein Ring, unten dicht, bis Baumhöhe auslaufend. Die Skybox scheint dort nicht mehr
## voll durch, oben bleiben Mond und Sterne klar (Lukas 2026-11-02).
func _fog_wall() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 52.0
	mesh.bottom_radius = 52.0
	mesh.height = 34.0
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 48
	var mat := ShaderMaterial.new()
	mat.shader = FOG_WALL
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(-3, 17.0 - 1.0, -6)
	add_child(mi)


## Wolken: große Fläche hoch über der Lichtung, ziehen langsam (wc3_wolken.gdshader).
func _clouds_setup() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1000, 1000)
	_clouds = ShaderMaterial.new()
	_clouds.shader = CLOUDS
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _clouds
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 34, -60)
	add_child(mi)


## Mehr Oberfläche für die schlichten Modelle: Materialien ohne eigene Textur bekommen eine ruhige Steintextur mit
## Normalmap (wc3_stein.gdshader, Farbe des Modells bleibt), Säulen und Sockel dazu Moos (Lukas 2026-11-02).
func _texturize(n: Node, scale: float, moss: float) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if not (src is StandardMaterial3D) or (src as StandardMaterial3D).albedo_texture != null:
				continue
			var key := "%d|%.2f|%.2f" % [src.get_instance_id(), scale, moss]
			if not _tex_cache.has(key):
				var m := ShaderMaterial.new()
				m.shader = STONE
				var c: Color = src.albedo_color
				m.set_shader_parameter("base_color", Color(c.r, c.g, c.b))
				m.set_shader_parameter("detail", DETAIL)
				m.set_shader_parameter("detail_n", DETAIL_NORMAL)
				m.set_shader_parameter("tex_scale", scale)
				m.set_shader_parameter("moss", moss)
				if moss > 0.0:
					# Säulen und Sockel: deutlich mehr Steinstruktur (Lukas 2026-11-02)
					m.set_shader_parameter("tex_strength", 0.85)
					m.set_shader_parameter("normal_strength", 1.3)
					m.set_shader_parameter("tex_scale", 0.35)
					m.set_shader_parameter("moss_tex", load(GT + "grass_b.jpg"))
					m.set_shader_parameter("moss_n", load(GT + "grass_b_normal.jpg"))
				_tex_cache[key] = m
			mi.set_surface_override_material(i, _tex_cache[key])


## Modelle mit eigener Textur dunkler (Laternen, Lukas 2026-11-02).
func _darken(n: Node, k: float) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if src is StandardMaterial3D:
				var m: StandardMaterial3D = src.duplicate()
				m.albedo_color = m.albedo_color * Color(k, k, k)
				m.roughness = 0.6
				m.metallic = 0.5
				mi.set_surface_override_material(i, m)


## Modell auf Höhe h skaliert, mit der Unterkante auf pos.
func _place(path: String, pos: Vector3, h: float, rot := 0.0, moss := 0.0) -> Node3D:
	var n: Node3D = load(M + path).instantiate()
	add_child(n)
	if not path.begins_with("crystals/") and not path.begins_with("scenery/tiere/"):
		# Bäume feiner gekachelt als Kirche, Säulen und Steine
		_texturize(n, 0.3 if path.begins_with("nature/pine") or path.begins_with("nature/common_tree") else 0.12, moss)
	var ab := _aabb(n)
	var s: float = h / maxf(ab.size.y, 0.001)
	n.scale = Vector3.ONE * s
	n.rotation.y = rot
	n.position = pos - Vector3(0, ab.position.y * s, 0)
	return n


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _glow_mat(col: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = e
	m.metallic = 0.3
	m.roughness = 0.2
	return m


func _recolor(n: Node, mat: Material) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat


func _light(pos: Vector3, col: Color, energy: float, range_: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.4
	add_child(l)
	return l


## Flamme in der Laterne (Lukas 2026-11-02: schöneres Feuer): züngelnde Flamme aus wc3_flamme.gdshader, darum ein
## schwaches Glühen, beides ohne Tiefentest (die Laterne ist geschlossen), dazu warmes, flackerndes Licht.
func _flame(pos: Vector3) -> void:
	var fl := MeshInstance3D.new()
	fl.mesh = QuadMesh.new()
	var fm := ShaderMaterial.new()
	fm.shader = FLAME
	fm.set_shader_parameter("phase", rng.randf() * 10.0)
	fl.material_override = fm
	fl.scale = Vector3(0.2, 0.34, 1.0)
	fl.position = pos + Vector3(0, 0.02, 0)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fl)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = true
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.6, 0.25, 0.55))
	g.set_color(1, Color(1.0, 0.35, 0.08, 0.0))
	g.add_point(0.3, Color(1.0, 0.45, 0.12, 0.22))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	m.albedo_texture = gt
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var l := _light(pos + Vector3(0, 0.05, 0), Color("ff9a40"), 2.0, 6.5)
	_flames.append([l, mi, rng.randf() * TAU])
