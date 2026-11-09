class_name Metall
extends RefCounted
## Gemeinsamer Metall-Look aller Modi (Lukas 2026-11-09, "Metall-Shader verbessern"):
## - Spiegelungen: die Himmel-Shader rechnen nur in den Umgebungs-Würfel Studiolicht dazu
##   (assets/shaders/metall_himmel.gdshaderinc), Stärke und Farbe je Modus über himmel_werte();
##   Szenen mit einfarbigem Hintergrund bekommen über spiegel_himmel() einen unsichtbaren Himmel nur dafür.
## - Material: veredeln() gibt Metall eine fleckige Rauheit (Roughness-Variation, geteilte Rauschtextur),
##   Kantenglanz über eine dünne Klarlack-Schicht (Fresnel, auch auf vollem Metall sichtbar) und
##   genug Glanz (metallic_specular). modell() macht das für Metall in geladenen Modellen.
## Grafikstufe (Display.quality): Niedrig ohne Klarlack und mit kleinem Umgebungs-Würfel,
## Hoch mit großem Würfel (schärfere Spiegelungen). Wechsel im Spiel: stufe_anwenden().

## ab hier gilt ein Material als Metall
const AB := 0.4
## Würfelgröße der Umgebung je Grafikstufe (Niedrig, Mittel, Hoch)
const WUERFEL := [Sky.RADIANCE_SIZE_32, Sky.RADIANCE_SIZE_64, Sky.RADIANCE_SIZE_128]
## Modell-Materialien ohne eigene Werte (glTF-Standard metallic 1 / roughness 1, z. B. Kenney) sind
## nur dann Metall, wenn der Name es sagt; sonst bleiben sie wie sie sind (Steine, Holz …).
const NAMEN := ["metal", "steel", "iron", "gold", "silver", "brass", "bronze", "chrome", "copper", "messing", "eisen", "stahl", "blade", "gun"]

static var _rauheit: Texture2D
static var _alle: Array = []  ## veredelte Materialien (WeakRef), für den Wechsel der Grafikstufe
static var _modelle := {}  ## Instanz-Id der Modell-Materialien, die schon geprüft sind


## Material als Metall verbessern (nur wenn metallic >= AB). Ändert m selbst und gibt es zurück.
static func veredeln(m: BaseMaterial3D) -> BaseMaterial3D:
	if m == null or m.metallic < AB or m.has_meta("metall"):
		return m
	m.set_meta("metall", true)
	if m.roughness_texture == null:
		# Rauheit schwankt zwischen etwa 65 und 100 % des Werts: matte und blanke Stellen wie benutztes Metall
		m.roughness_texture = rauheit()
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic_specular = maxf(m.metallic_specular, 0.6)
	_stufe(m)
	_alle.append(weakref(m))
	return m


## Metall in einem geladenen Modell verbessern. Modell-Materialien sind geteilt (alle Kopien eines Modells),
## daher wird jedes Material nur einmal angefasst.
static func modell(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mesh.surface_get_material(i)
			if m is BaseMaterial3D and not _modelle.has(m.get_instance_id()):
				_modelle[m.get_instance_id()] = true
				_modell_material(m)


static func _modell_material(m: BaseMaterial3D) -> void:
	if m.metallic < AB or m.metallic_texture != null:
		return
	if m.metallic >= 0.99 and m.roughness >= 0.99:
		# glTF-Standardwerte: nur mit Metall im Namen, dann wie poliertes Metall
		var name := m.resource_name.to_lower()
		var hit := false
		for n in NAMEN:
			if name.contains(n):
				hit = true
				break
		if not hit:
			return
		m.metallic = 0.85
		m.roughness = 0.42
	veredeln(m)


## Geteilte Rauschtextur für die Rauheit (nahtlos, hell = rau).
static func rauheit() -> Texture2D:
	if _rauheit == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		noise.seed = 7
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.62, 0.62, 0.62))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.noise = noise
		t.color_ramp = ramp
		t.generate_mipmaps = true
		_rauheit = t
	return _rauheit


static func _stufe(m: BaseMaterial3D) -> void:
	# Kantenglanz: dünne Klarlack-Schicht, glänzt nach Fresnel an Kanten und flachen Blickwinkeln
	m.clearcoat_enabled = Display.quality >= Display.MEDIUM
	m.clearcoat = 0.35
	m.clearcoat_roughness = 0.22


## Spiegel-Himmel einer Umgebung auf die Grafikstufe setzen (Würfelgröße). Himmel mit Studiolicht
## werden nicht jedes Bild neu gerechnet, ändernde Himmel (Tageszeit) in Schritten über mehrere Bilder.
static func himmel(env: Environment) -> void:
	if env == null or env.sky == null:
		return
	env.sky.radiance_size = WUERFEL[clampi(Display.quality, 0, 2)]
	if env.sky.radiance_size > Sky.RADIANCE_SIZE_64:
		env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL


## Stärke und Farben des Studiolichts in einem Himmel-Shader setzen (Werte aus FieldStyle.env():
## "metall", "metall_farbe", "metall_farbe2").
static func himmel_werte(mat: Material, look: Dictionary) -> void:
	if not mat is ShaderMaterial:
		return
	mat.set_shader_parameter("metall_glanz", float(look.get("metall", 1.0)))
	mat.set_shader_parameter("metall_farbe", look.get("metall_farbe", Color(1.0, 0.96, 0.9)))
	mat.set_shader_parameter("metall_farbe2", look.get("metall_farbe2", Color(0.75, 0.85, 1.0)))


## Unsichtbarer Himmel nur für Spiegelungen (Szenen mit einfarbigem Hintergrund, z. B. Bollwerk):
## Hintergrund und Umgebungslicht bleiben wie eingestellt, Metall spiegelt Verlauf plus Studiolicht.
static func spiegel_himmel(env: Environment, oben: Color, horizont: Color, unten: Color, look := {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/stil_himmel.gdshader")
	mat.set_shader_parameter("sky_top_color", oben)
	mat.set_shader_parameter("sky_horizon_color", horizont)
	mat.set_shader_parameter("ground_horizon_color", horizont)
	mat.set_shader_parameter("ground_bottom_color", unten)
	himmel_werte(mat, look)
	env.sky = Sky.new()
	env.sky.sky_material = mat
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	himmel(env)
	return mat


## Grafikstufe auf alle veredelten Materialien und Himmel der laufenden Szene anwenden (Display.apply_quality).
static func stufe_anwenden(root: Node) -> void:
	var rest: Array = []
	for w in _alle:
		var m = w.get_ref()
		if m != null:
			_stufe(m)
			rest.append(w)
	_alle = rest
	for we in root.find_children("*", "WorldEnvironment", true, false):
		himmel(we.environment)
