class_name Feuer
extends Node3D
## Feuer im Stil der Feuerschalen und Lagerfeuer aus WoW (nur das Prinzip, Lukas 2026-11-09): zwei Flammen-Billboards
## (feuer.gdshader, ein breiter Körper und ein schmaler, schnellerer Kern), aufsteigende Funken und ein flackerndes
## Licht samt warmem Fleck am Boden. Das Flackern (flicker()) teilen sich Licht, Flamme und Fleck, damit alles im
## selben Takt zuckt; die Laternen von EeveScenery benutzen es ebenso.
## Grafik „Niedrig“: ohne echtes Licht und ohne Funken (Display.quality).

const SHADER := preload("res://assets/shaders/feuer.gdshader")
const POOL_SHADER := preload("res://assets/shaders/lantern_pool.gdshader")
const LIGHT := Color("ff7a24")

var light: OmniLight3D
var pool: MeshInstance3D  ## warmer Fleck am Boden (falls angelegt), y relativ zum Feuer
var pool_mat: ShaderMaterial
var light_energy := 2.6
var pool_strength := 0.5
## 0..1: wie stark Licht und Fleck gerade wirken (Tageszeit: tagsüber sieht man nur die Flamme)
var lit := 1.0
var _mats: Array[ShaderMaterial] = []
var _sparks: CPUParticles3D
var _seed := 0.0
var _base_pos := Vector3.ZERO


## Helligkeit des Flackerns zur Zeit t (um 1 herum, zwischen etwa 0.7 und 1.2), seed versetzt jede Flamme.
## Zwei Rauschfrequenzen: ruhiges Atmen und schnelles Zucken, dazu ab und zu ein kurzes Einknicken.
static func flicker(t: float, seed: float) -> float:
	var slow := noise1(t * 1.3 + seed * 17.0)
	var fast := noise1(t * 7.5 + seed * 31.0 + 40.0)
	var dip := minf(noise1(t * 2.2 + seed * 7.0 + 90.0) + 0.55, 0.0)
	return 1.0 + 0.12 * slow + 0.1 * fast + 0.5 * dip


## Glattes Rauschen in einer Dimension (-1..1), ohne Ressource (kein FastNoiseLite, das beim Beenden hängen bliebe).
static func noise1(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	var a := fposmod(sin(i * 127.1) * 43758.5453, 1.0)
	var b := fposmod(sin((i + 1.0) * 127.1) * 43758.5453, 1.0)
	return lerpf(a, b, f) * 2.0 - 1.0


## Feuer der Höhe h (Flammenhöhe in Einheiten); light_range 0 = ohne Licht, pool > 0 = Lichtfleck dieser Größe.
static func make(h: float, seed: float, light_range := 5.0, pool_size := 0.0, sparks := true) -> Feuer:
	var f := Feuer.new()
	f._seed = seed
	f._add_flame(h * 0.95, h, 0.46, 1.0, 2.2)
	# kleinerer, hellerer Kern, schneller und weniger zerrissen
	f._add_flame(h * 0.5, h * 0.55, 0.4, 1.4, 2.0, Color("ffc060"), 0.6)
	if light_range > 0.0:
		f.light = OmniLight3D.new()
		f.light.light_color = LIGHT
		f.light.omni_range = light_range
		f.light.omni_attenuation = 1.4
		f.light.light_energy = f.light_energy
		f.light.shadow_enabled = false
		f.light.light_cull_mask = 1
		f.light.position = Vector3(0, h * 0.45, 0)
		f._base_pos = f.light.position
		f.add_child(f.light)
	if pool_size > 0.0:
		var mi := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE * pool_size
		mi.mesh = quad
		f.pool_mat = ShaderMaterial.new()
		f.pool_mat.shader = POOL_SHADER
		f.pool_mat.set_shader_parameter("light_color", Color(1.0, 0.45, 0.1))
		f.pool_mat.set_shader_parameter("flicker", 0.0)
		f.pool_mat.set_shader_parameter("core", 0.3)
		f.pool_mat.set_shader_parameter("tail", 0.45)
		f.pool_mat.set_shader_parameter("post_uv", Vector2(0.5, 0.5))
		f.pool_mat.render_priority = 2
		mi.material_override = f.pool_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 0.03
		f.add_child(mi)
		f.pool = mi
	if sparks:
		f._add_sparks(h)
	return f


func _add_flame(w: float, h: float, width: float, spd: float, intensity: float,
		hot := Color("ffb848"), ragged := 1.0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	# Fuß der Flamme am Knoten, nicht die Mitte
	q.center_offset = Vector3(0, 0.5, 0)
	mi.mesh = q
	mi.scale = Vector3(w, h, 1.0)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("phase", _seed * 13.7 + spd)
	m.set_shader_parameter("speed", spd)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("col_hot", hot)
	m.set_shader_parameter("ragged", ragged)
	# nach dem Boden, dem Lichtfleck und dem Glas zeichnen
	m.render_priority = 4
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Billboard: der Rahmen darf nicht weggeschnitten werden, wenn die Kamera das Quad nur von der Seite sähe
	mi.custom_aabb = AABB(Vector3(-h, -h * 0.2, -h), Vector3(2.0 * h, 1.4 * h, 2.0 * h))
	add_child(mi)
	_mats.append(m)


## Funken: kleine, helle Punkte, die aus der Glut aufsteigen, seitlich driften und verglühen.
func _add_sparks(h: float) -> void:
	_sparks = CPUParticles3D.new()
	_sparks.amount = 10 if h < 0.6 else 18
	_sparks.lifetime = 1.6
	_sparks.preprocess = 1.6
	_sparks.randomness = 0.6
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = h * 0.18
	_sparks.direction = Vector3.UP
	_sparks.spread = 25.0
	_sparks.gravity = Vector3(0.0, h * 0.4, 0.0)
	_sparks.initial_velocity_min = h * 0.5
	_sparks.initial_velocity_max = h * 1.3
	_sparks.damping_min = h * 0.2
	_sparks.damping_max = h * 0.5
	_sparks.tangential_accel_min = -h * 0.8
	_sparks.tangential_accel_max = h * 0.8
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.2
	_sparks.position.y = h * 0.25
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	ramp.add_point(0.4, Color(1.0, 0.5, 0.12, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.7, 0.12, 0.02, 0.0))
	_sparks.color_ramp = ramp
	var dot := QuadMesh.new()
	dot.size = Vector2.ONE * maxf(h * 0.035, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(2.5, 2.0, 1.6)
	mat.disable_receive_shadows = true
	dot.material = mat
	_sparks.mesh = dot
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


func _ready() -> void:
	_on_quality()
	Display.quality_changed.connect(_on_quality)


func _on_quality() -> void:
	var low := Display.quality == Display.LOW
	if _sparks != null:
		_sparks.emitting = not low
		_sparks.visible = not low
	if light != null:
		light.visible = not low and lit > 0.02


func _process(_delta: float) -> void:
	var f := flicker(Time.get_ticks_msec() * 0.001, _seed)
	for m in _mats:
		m.set_shader_parameter("flick", 0.85 + 0.15 * f)
	if light != null and light.visible:
		light.light_energy = light_energy * f * lit
		# das Licht zuckt ein wenig mit der Flamme: Schatten und Glanz bewegen sich mit
		var t := Time.get_ticks_msec() * 0.004 + _seed * 9.0
		light.position = _base_pos + Vector3(noise1(t), 0.0, noise1(t + 50.0)) * 0.05
	if pool_mat != null:
		pool_mat.set_shader_parameter("strength", pool_strength * f * lit)


## Tageszeit: Licht und Fleck mit der Dunkelheit stärker (Flamme bleibt immer gleich).
func set_lit(v: float) -> void:
	lit = v
	_on_quality()
