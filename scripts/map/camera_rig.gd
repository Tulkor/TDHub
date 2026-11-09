class_name CameraRig
extends Node3D
## Strategiekamera: WASD/Pfeiltasten, Maus am Fensterrand oder rechte Maustaste ziehen verschiebt,
## Mausrad zoomt, mittlere Maustaste ziehen oder Q/E dreht.

const PAN_SPEED := 18.0
const ROTATE_SPEED := 1.8
const MIN_DISTANCE := 6.0
const MAX_DISTANCE := 90.0
## Abstand zum Fensterrand in Pixeln, ab dem die Kamera mitläuft.
const EDGE_MARGIN := 6.0
## Ab so vielen Pixeln Mausweg gilt ein Rechtsklick als Ziehen und nicht als Klick.
const DRAG_THRESHOLD := 6.0
## So weit (Einheiten) darf das Bild über den Kartenrand hinausreichen (Wunsch von Lukas: Kamera auf das
## Spielfeld und nur minimal außerhalb beschränkt, in allen Modi).
const VIEW_MARGIN := 3.0
## Strahlen am oberen Bildrand mindestens so steil nach unten rechnen: bei flacher Kamera träfen sie den
## Boden erst am Horizont (Neigung -20°), der Bereich dahinter zählt nicht.
const MIN_RAY_DOWN := 0.3

var camera: Camera3D
var target := Vector3.ZERO
var distance := 40.0
var yaw := 0.0
var pitch := deg_to_rad(-58.0)
var bounds := Rect2(0, 0, 40, 40)
## Sichtbaren Boden auf bounds (plus VIEW_MARGIN) begrenzen: weiter herauszoomen oder -schieben geht nicht.
## Aus im Map-Editor (dort soll man die ganze Karte samt Rand sehen).
var limit_view := true
var _rotating := false
var _right_down := false
var _right_travel := 0.0
## true, wenn der letzte Rechtsklick die Kamera verschoben hat (dann kein Abwählen/Radieren).
var right_dragged := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(_apply)
	_apply()


## Kamera auf die ganze Map ausrichten (Größe in Einheiten, nicht in Feldern).
func frame_map(width: float, height: float) -> void:
	bounds = Rect2(0, 0, width, height)
	target = Vector3(width / 2.0, 0, height / 2.0 + height * 0.04)
	distance = clampf(maxf(width, height) * 1.05, MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _process(delta: float) -> void:
	# Echtzeit, damit die Kamera bei 4x Spieltempo nicht rast
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _right_down and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_right_down = false  # losgelassen über dem Seitenpanel
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	input += _edge_input()
	input = input.limit_length(1.0)
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q):
		turn += 1
	if Input.is_key_pressed(KEY_E):
		turn -= 1
	if input == Vector2.ZERO and turn == 0.0:
		return
	yaw += turn * ROTATE_SPEED * real_delta
	var move := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw) * PAN_SPEED * real_delta * (distance / 40.0)
	target += move
	_clamp_target()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and UiUtil.mouse_over_ui(get_viewport()):
			return  # über einem Fenster scrollt das Fenster, die Karte zoomt nicht mit
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(MIN_DISTANCE, distance * 0.9)
				_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(MAX_DISTANCE, distance * 1.1)
				_apply()
			MOUSE_BUTTON_MIDDLE:
				_rotating = event.pressed
			MOUSE_BUTTON_RIGHT:
				_right_down = event.pressed
				if event.pressed:
					_right_travel = 0.0
					right_dragged = false
	elif event is InputEventMouseMotion and _rotating:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch - event.relative.y * 0.006, deg_to_rad(-85), deg_to_rad(-20))
		_apply()
	elif event is InputEventMouseMotion and _right_down:
		_right_travel += event.relative.length()
		if _right_travel >= DRAG_THRESHOLD:
			right_dragged = true
			_drag_pan(event.relative)


## Karte mit der Maus „greifen“: der Boden folgt dem Mauszeiger.
func _drag_pan(relative: Vector2) -> void:
	if camera == null:
		return
	var view_h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var per_pixel := 2.0 * distance * tan(deg_to_rad(camera.fov) / 2.0) / view_h
	var along := Vector3(-relative.x, 0, -relative.y / maxf(sin(-pitch), 0.2))
	target += along.rotated(Vector3.UP, yaw) * per_pixel
	_clamp_target()
	_apply()


## Richtung, wenn die Maus am Fensterrand steht (nur bei aktivem Fenster).
func _edge_input() -> Vector2:
	if not DisplayServer.window_is_focused() or _right_down or _rotating:
		return Vector2.ZERO
	var rect := get_viewport().get_visible_rect()
	var mp := get_viewport().get_mouse_position()
	if not rect.grow(1.0).has_point(mp):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mp.x <= rect.position.x + EDGE_MARGIN:
		dir.x -= 1
	elif mp.x >= rect.end.x - EDGE_MARGIN:
		dir.x += 1
	if mp.y <= rect.position.y + EDGE_MARGIN:
		dir.y -= 1
	elif mp.y >= rect.end.y - EDGE_MARGIN:
		dir.y += 1
	return dir


func _clamp_target() -> void:
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)


func _apply() -> void:
	_place()
	if limit_view:
		_limit_view()


func _place() -> void:
	position = target
	rotation = Vector3(pitch, yaw, 0)
	if camera:
		camera.position = Vector3(0, 0, distance)
		# Bild nach links schieben, damit das Seitenpanel rechts nichts verdeckt
		camera.h_offset = distance * 0.12


## Zoom und Lage so begrenzen, dass der sichtbare Boden in bounds plus VIEW_MARGIN liegt. Die sichtbare
## Fläche wächst linear mit distance (Ziel liegt auf dem Boden), deshalb reicht ein Schritt je Achse.
func _limit_view() -> void:
	var view := view_rect()
	if view.size == Vector2.ZERO:
		return
	var room := bounds.grow(VIEW_MARGIN)
	var f := minf(room.size.x / view.size.x, room.size.y / view.size.y)
	if f < 1.0 and distance > MIN_DISTANCE:
		var d := maxf(MIN_DISTANCE, distance * f)
		var c := Vector2(target.x, target.z)
		view = Rect2(c + (view.position - c) * d / distance, view.size * d / distance)
		distance = d
	var shift := Vector2.ZERO
	for i in 2:
		if view.size[i] > room.size[i]:
			shift[i] = room.get_center()[i] - view.get_center()[i]
		elif view.position[i] < room.position[i]:
			shift[i] = room.position[i] - view.position[i]
		elif view.end[i] > room.end[i]:
			shift[i] = room.end[i] - view.end[i]
	target += Vector3(shift.x, 0, shift.y)
	_place()


## Sichtbarer Boden (Ebene y = 0) als achsparalleles Rechteck um die Mitten der vier Bildränder (Kreuz durch die
## Bildmitte). Die Ecken zählen nicht: oben ist das Bild schräg von oben viel breiter als unten, mit den Ecken
## sähe man auf kleinen Karten nie die ganze Breite. Aus Lage, Blickwinkel und Seitenverhältnis gerechnet.
func view_rect() -> Rect2:
	if camera == null:
		return Rect2()
	var aspect := 16.0 / 9.0
	if is_inside_tree():
		var vp := get_viewport().get_visible_rect().size
		if vp.y > 0.0:
			aspect = vp.x / vp.y
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0))
	var from := target + basis * Vector3(camera.h_offset, 0, distance)
	var ty := tan(deg_to_rad(camera.fov) / 2.0)
	var r := Rect2()
	for i in 4:
		var ndc: Vector2 = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)][i]
		var dir := basis * Vector3(ndc.x * ty * aspect, ndc.y * ty, -1.0)
		dir.y = minf(dir.y, -MIN_RAY_DOWN * dir.length())
		var hit := from + dir * (from.y / -dir.y)
		var p := Vector2(hit.x, hit.z)
		r = Rect2(p, Vector2.ZERO) if i == 0 else r.expand(p)
	return r


## Skybox: sechs Bilder in der Reihenfolge +X, -X, +Y, -Y, +Z, -Z.
const SKY_FACES := ["right", "left", "top", "bottom", "front", "back"]
const SKY_DIR := "res://assets/textures/sky/"
static var _sky_cube: Cubemap


static func _sky() -> Sky:
	if _sky_cube == null:
		var images: Array[Image] = []
		for face in SKY_FACES:
			var tex := load(SKY_DIR + face + ".png") as Texture2D
			if tex == null:
				return null
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGB8)
			images.append(img)
		_sky_cube = Cubemap.new()
		_sky_cube.create_from_images(images)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/skybox.gdshader")
	mat.set_shader_parameter("cube", _sky_cube)
	var sky := Sky.new()
	sky.sky_material = mat
	return sky


## Licht und Himmel für eine 3D-Szene anlegen. Werte aus FieldStyle.env(), fehlende Schlüssel
## nehmen den Arcade-Stand (FieldStyle.ENV_DEFAULT). Gibt die Knoten zurück, damit ein Modus
## (z. B. eine Nachtversion) sie nachträglich ändern kann: {"env", "sun", "fill"}.
## filter = Stil-Filter des Modus (StyleFilter) dazuhängen; Editoren lassen ihn weg, dort zählen echte Farben.
static func add_environment(parent: Node, look: Dictionary = {}, filter := true) -> Dictionary:
	if look.is_empty():
		look = FieldStyle.env()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("05030c")
	# "tint": Farbstich über alle Lichter und den Himmel (z. B. wärmer)
	var tint: Color = look.tint
	if look.has("sky_top"):
		# eigener, einfacher Himmel (eeveTD, Shopping Maul)
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = look.sky_top * tint
		sky_mat.sky_horizon_color = look.sky_horizon * tint
		sky_mat.ground_horizon_color = look.sky_horizon * tint
		sky_mat.ground_bottom_color = look.ground_bottom * tint
		sky_mat.sun_angle_max = 0.0
		env.sky = Sky.new()
		env.sky.sky_material = sky_mat
		env.sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.background_mode = Environment.BG_SKY
	else:
		var sky := _sky()
		if sky != null:
			env.background_mode = Environment.BG_SKY
			env.sky = sky
	# Leuchten für helle (HDR) Flächen, z. B. die Neon-Wegpunkte
	env.glow_enabled = Display.q("glow")
	env.glow_intensity = look.glow_intensity
	env.glow_bloom = look.glow_bloom
	env.glow_hdr_threshold = look.glow_threshold
	# weicher, breiter Schein: zu den Standard-Stufen 3 und 5 auch 2 (eng) und 4 (mittel)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(3, 0.8)
	# Umgebungslicht: feste Farbe, oder mit "ambient_sky" > 0 anteilig vom Himmel (oben Himmelsfarbe,
	# unten Bodenfarbe), dann sind Oberseiten heller als Flanken und Unterseiten
	if look.ambient_sky > 0.0 and env.sky != null:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = look.ambient_sky
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = look.ambient * tint
	env.ambient_light_energy = look.ambient_energy
	env.tonemap_mode = look.tonemap
	env.tonemap_exposure = look.exposure
	env.tonemap_white = look.white
	if look.contrast != 1.0 or look.saturation != 1.0:
		env.adjustment_enabled = true
		env.adjustment_contrast = look.contrast
		env.adjustment_saturation = look.saturation
	if look.fog_density > 0.0:
		# leichter Dunst in der Ferne, damit Boden und Tower räumlicher wirken
		env.fog_enabled = true
		env.fog_light_color = look.fog
		env.fog_density = look.fog_density
		env.fog_sky_affect = 0.0
	# Forward+ (Vulkan): Umgebungsverdeckung (SSAO) dunkelt Fugen, Ecken und den Fuß der Tower ab,
	# indirektes Licht (SSIL) trägt Farbe von hellen Flächen auf die Umgebung
	if look.ssao > 0.0:
		env.ssao_enabled = true
		env.ssao_radius = look.ssao_radius
		env.ssao_intensity = look.ssao
		env.ssao_power = 1.5
		env.ssao_light_affect = 0.15
	if look.ssil > 0.0:
		env.ssil_enabled = true
		env.ssil_radius = 3.0
		env.ssil_intensity = look.ssil
	# Volumen-Nebel: Licht der Laternen und Treffer wird im Dunst sichtbar
	if look.vol_fog > 0.0:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = look.vol_fog
		env.volumetric_fog_albedo = look.fog
		env.volumetric_fog_length = 40.0
		env.volumetric_fog_ambient_inject = 0.3
		env.volumetric_fog_sky_affect = 0.0
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(look.sun_pitch), deg_to_rad(look.sun_yaw), 0)
	sun.light_color = look.sun * tint
	sun.light_energy = look.sun_energy
	sun.light_specular = look.sun_specular
	sun.shadow_enabled = true
	sun.shadow_blur = look.shadow_blur
	sun.shadow_opacity = look.shadow_opacity
	# Schatten nur so weit wie das Spielfeld reicht: feinere Schattenkanten ohne Treppen
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	parent.add_child(sun)
	# Gegenlicht von der anderen Seite ohne Schatten: hellt Schattenseiten in einer kühlen Farbe auf,
	# damit Tower und Gegner Form bekommen statt einer flachen dunklen Seite
	var fill: DirectionalLight3D = null
	if look.fill_energy > 0.0:
		fill = DirectionalLight3D.new()
		fill.rotation = Vector3(deg_to_rad(look.fill_pitch), deg_to_rad(look.sun_yaw + 180.0), 0)
		fill.light_color = look.fill * tint
		fill.light_energy = look.fill_energy
		fill.light_specular = 0.25
		fill.shadow_enabled = false
		parent.add_child(fill)
	# Schein des leuchtenden Bodens: Licht von unten in der Linienfarbe, ohne Schatten
	if look.under_energy > 0.0:
		var under := DirectionalLight3D.new()
		under.name = "FloorGlow"
		under.rotation = Vector3(deg_to_rad(look.under_pitch), deg_to_rad(look.sun_yaw + 90.0), 0)
		under.light_color = look.under * tint
		under.light_energy = look.under_energy
		under.light_specular = 0.4
		under.shadow_enabled = false
		# Tower (Tower.GEM_LAYER) leuchten von unten in ihrer eigenen Farbe, nicht pink
		under.light_cull_mask = 0xFFFFF & ~Tower.GEM_LAYER
		parent.add_child(under)
	_add_outline(parent, look)
	_add_post(parent, look)
	if filter:
		StyleFilter.attach(parent)
	return {"env": env, "sun": sun, "fill": fill}


## Leichte Kontur um alles Deckende (screen_outline.gdshader), Farbe und Stärke aus "outline_color"/"outline".
static func _add_outline(parent: Node, look: Dictionary) -> void:
	var old := parent.get_node_or_null("ScreenOutline")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	if look.outline <= 0.0:
		return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/screen_outline.gdshader")
	mat.set_shader_parameter("color", look.outline_color)
	mat.set_shader_parameter("strength", look.outline)
	mat.render_priority = 0
	var quad := MeshInstance3D.new()
	quad.name = "ScreenOutline"
	quad.mesh = QuadMesh.new()
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# deckt den ganzen Bildschirm, darf nie weggeschnitten werden
	quad.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	parent.add_child(quad)



## Vignette über dem ganzen Bild (screen_post.gdshader), Stärke und Farbe aus "vignette"/"vignette_color".
static func _add_post(parent: Node, look: Dictionary) -> void:
	var old := parent.get_node_or_null("ScreenPost")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	if look.vignette <= 0.0:
		return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/screen_post.gdshader")
	mat.set_shader_parameter("vignette", look.vignette)
	mat.set_shader_parameter("vignette_color", look.vignette_color)
	# ganz zuletzt, nach Effekten und Kontur
	mat.render_priority = 100
	var quad := MeshInstance3D.new()
	quad.name = "ScreenPost"
	quad.mesh = QuadMesh.new()
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	parent.add_child(quad)
