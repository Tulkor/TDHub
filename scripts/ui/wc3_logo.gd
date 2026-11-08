class_name Wc3Logo
extends SubViewportContainer
## Logo des Hauptmenüs als 3D in eigener, durchsichtiger Welt: Schriftzug "TD HUB" aus Messing
## (assets/models/ui/td_hub_logo.glb, erzeugt von tools/menu/td_hub_logo.py) und links und rechts vom "TD"
## je ein halb durchsichtiger Rubin, die sich gegenläufig drehen, leicht wippen und rötlich auf die Schrift leuchten.

const LOGO := "res://assets/models/ui/td_hub_logo.glb"
const RUBY := "res://assets/models/crystals/crystal_16.glb"
## Mitte von "TD" im Modell (aus td_hub_logo.py), die Rubine sitzen RUBY_DX daneben.
const TD_Y := 0.61
const TD_HALF := 0.375
const RUBY_DX := 0.45
const RUBY_H := 0.4
## Seitenverhältnis Breite : Höhe des Bilds.
const ASPECT := 1.9
## Eine Umdrehung der Rubine dauert so lange (Sekunden).
const TURN := 4.0

var viewport: SubViewport
var _rubies: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	_environment(root)
	var logo: Node3D = load(LOGO).instantiate()
	root.add_child(logo)
	_metal(logo)
	for side in [-1, 1]:
		_rubies.append(_ruby(root, Vector3(side * (TD_HALF + RUBY_DX), TD_Y, 0.05)))
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 13.0
	root.add_child(cam)
	# Abstand so, dass Breite (HUB oder Rubine) und Höhe (TD über HUB, Rubine wippen) mit Rand hineinpassen
	var aabb := _aabb(logo)
	var half_w := maxf(aabb.size.x / 2, TD_HALF + RUBY_DX + RUBY_H) * 1.06
	var half_h := maxf(aabb.end.y, TD_Y + RUBY_H / 2 + 0.05) - aabb.get_center().y
	half_h = maxf(half_h, aabb.get_center().y - aabb.position.y) * 1.08
	var tan_w := tan(deg_to_rad(cam.fov) / 2)
	cam.position = Vector3(0, aabb.get_center().y + 0.03, maxf(half_w / tan_w, half_h / (tan_w / ASPECT)))
	cam.current = true
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	custom_minimum_size.y = size.x / ASPECT


func _process(delta: float) -> void:
	_time += delta
	for i in _rubies.size():
		var dir := 1.0 if i == 0 else -1.0
		_rubies[i].rotation.y = 0.6 + dir * TAU * _time / TURN
		_rubies[i].position.y = TD_Y + sin(TAU * _time / TURN + i * PI) * 0.03


## Licht passend zur Nachtszene dahinter (Lukas 2026-11-02: realistischer): kühles Mondlicht von rechts oben mit
## Schatten, warmes Laternenlicht von links unten, blaues Licht vom Kristall von unten, dazu ein Himmel mit hellem
## Horizontband nur für die Spiegelungen im Messing.
func _environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1c2850")
	sm.sky_horizon_color = Color("ffe0b0")
	sm.ground_horizon_color = Color("d89a50")
	sm.ground_bottom_color = Color("0a0604")
	sm.sky_curve = 0.18
	sm.ground_curve = 0.06
	sm.sky_energy_multiplier = 1.2
	var sky := Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.12
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.78, 0.86, 1.0)
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 30.0
	root.add_child(key)
	key.look_at_from_position(Vector3(2.5, 4, 4), Vector3(0, 0.3, 0), Vector3.UP)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.55, 1.0)
	rim.light_energy = 0.7
	root.add_child(rim)
	rim.look_at_from_position(Vector3(3, 2, -3), Vector3(0, 0.3, 0), Vector3.UP)
	# Laterne links unten, warm
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.62, 0.3)
	warm.light_energy = 1.6
	warm.omni_range = 4.5
	warm.position = Vector3(-2.2, -1.0, 1.4)
	root.add_child(warm)
	# Kristall rechts unten, blau
	var blue := OmniLight3D.new()
	blue.light_color = Color(0.4, 0.75, 1.0)
	blue.light_energy = 1.4
	blue.omni_range = 4.0
	blue.position = Vector3(1.4, -1.3, 1.2)
	root.add_child(blue)


## Messing mit Textur (Lukas 2026-11-02): fleckige Patina in der Farbe, dazu passend mal blankere, mal mattere Stellen,
## und eine gehämmerte Oberfläche aus Zellenrauschen. Eisenrand dunkel und rauer.
func _metal(logo: Node3D) -> void:
	var hammer := FastNoiseLite.new()
	hammer.noise_type = FastNoiseLite.TYPE_CELLULAR
	hammer.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	hammer.frequency = 0.16
	var bumps := NoiseTexture2D.new()
	bumps.noise = hammer
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 4.0
	var patina := FastNoiseLite.new()
	patina.frequency = 0.008
	patina.fractal_octaves = 5
	var ramp := Gradient.new()
	ramp.set_color(0, Color("9a7440"))
	ramp.set_color(1, Color("dcc088"))
	ramp.add_point(0.5, Color("c9a36a"))
	var albedo := NoiseTexture2D.new()
	albedo.noise = patina
	albedo.seamless = true
	albedo.color_ramp = ramp
	var rough_ramp := Gradient.new()
	rough_ramp.set_color(0, Color(0.48, 0.48, 0.48))
	rough_ramp.set_color(1, Color(0.2, 0.2, 0.2))
	var rough := NoiseTexture2D.new()
	rough.noise = patina
	rough.seamless = true
	rough.color_ramp = rough_ramp
	for mi: MeshInstance3D in logo.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0)
		var m := StandardMaterial3D.new()
		var iron := src != null and src.resource_name.begins_with("eisen")
		m.metallic = 1.0
		if iron:
			m.albedo_color = Color("34323a")
			m.roughness = 0.55
		else:
			m.albedo_texture = albedo
			m.roughness_texture = rough
			m.roughness = 1.0
		m.normal_enabled = true
		m.normal_texture = bumps
		m.normal_scale = 0.12
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 1.2
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _ruby(root: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	root.add_child(pivot)
	var gem: Node3D = load(RUBY).instantiate()
	pivot.add_child(gem)
	var ab := _aabb(gem)
	var s := RUBY_H / maxf(ab.size.y, 0.001)
	gem.scale = Vector3.ONE * s
	gem.position = -ab.get_center() * s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.07, 0.2, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.roughness = 0.08
	m.metallic = 0.2
	m.metallic_specular = 0.7
	m.emission_enabled = true
	m.emission = Color("ff2a5a")
	m.emission_energy_multiplier = 0.25
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.8
	for mi: MeshInstance3D in gem.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rötliches Licht vom Rubin auf die Schrift
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.2, 0.24)
	l.light_energy = 2.5
	l.omni_range = 1.6
	l.position = Vector3(0, 0, 0.3)
	pivot.add_child(l)
	return pivot


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
