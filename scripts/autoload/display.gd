extends Node
## Anzeige: Vollbild oder Fenster, die Fenstergröße, die UI-Größe und die Grafikqualität. Gespeichert in user://settings.cfg.

signal quality_changed

const SETTINGS := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1400, 900), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]

var fullscreen := false
var resolution := Vector2i(1400, 900)
const UI_SCALE_MIN := 0.5
const UI_SCALE_MAX := 1.0
var ui_scale := 1.0  ## Größe der ganzen Oberfläche, 0,5 bis 1,0 (3D-Ansicht bleibt gleich)
var path_lights := false  ## Lichtpfad: Lichter fliegen den Gegnerweg entlang (PathLights, Knopf im HUD)
var style_filter := true  ## Stil-Filter je Modus über dem 3D-Bild (StyleFilter), in den Einstellungen abschaltbar
signal style_filter_changed(on: bool)
## Breite des Spiel-HUDs: Leisten und Fenster liegen in einer mittigen Fläche, höchstens HUD_ASPECT breit
## (16:9, breitere Bildschirme bekommen links und rechts nur Spielfeld) und davon hud_width Anteil.
signal hud_width_changed
const HUD_ASPECT := 16.0 / 9.0
const HUD_WIDTH_MIN := 0.6
var hud_width := 1.0
## Grafikqualität: Niedrig, Mittel, Hoch. Was sie je Stufe ändert, steht in QUALITY; Szenen lesen dazu
## Display.quality (z. B. Laternenlichter in eeveTD) und hören auf quality_changed. "lod": ab wie vielen Pixeln
## Abweichung Godot auf die vereinfachten Fassungen der Modelle wechselt (Bäume im Wald haben 3000–5000 Dreiecke).
enum { LOW, MEDIUM, HIGH }
const QUALITY_NAMES := ["Niedrig", "Mittel", "Hoch"]
const QUALITY := [
	{"shadow_atlas": 2048, "shadow_filter": RenderingServer.SHADOW_QUALITY_HARD, "msaa": Viewport.MSAA_DISABLED, "glow": false, "hit_lights": false, "lod": 4.0},
	{"shadow_atlas": 4096, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "msaa": Viewport.MSAA_2X, "glow": true, "hit_lights": true, "lod": 2.0},
	{"shadow_atlas": 8192, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "msaa": Viewport.MSAA_2X, "glow": true, "hit_lights": true, "lod": 1.0},
]
var quality := HIGH
var _fonts: Array[FontFile] = []  ## hält die Schriften im Cache, damit die Einstellungen aus _sharpen_fonts bleiben


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		resolution = cfg.get_value("display", "resolution", resolution)
		ui_scale = clampf(float(cfg.get_value("display", "ui_scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)
		path_lights = bool(cfg.get_value("display", "path_lights", false))
		style_filter = bool(cfg.get_value("display", "style_filter", true))
		hud_width = clampf(float(cfg.get_value("display", "hud_width", 1.0)), HUD_WIDTH_MIN, 1.0)
	quality = clampi(int(cfg.get_value("display", "quality", _default_quality())), LOW, HIGH)
	_sharpen_fonts()
	_apply()
	apply_quality()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply()
	_save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply()
	_save()


func set_ui_scale(v: float) -> void:
	ui_scale = clampf(v, UI_SCALE_MIN, UI_SCALE_MAX)
	_apply()
	_save()


func set_hud_width(v: float) -> void:
	hud_width = clampf(v, HUD_WIDTH_MIN, 1.0)
	hud_width_changed.emit()
	_save()


## Breite der mittigen HUD-Fläche in UI-Pixeln für ein Fenster dieser Größe (UI-Pixel, nach ui_scale).
func hud_span(view: Vector2) -> float:
	return minf(view.x, view.y * HUD_ASPECT) * hud_width


func set_path_lights(on: bool) -> void:
	path_lights = on
	_save()


func set_style_filter(on: bool) -> void:
	style_filter = on
	style_filter_changed.emit(on)
	_save()


func set_quality(q: int) -> void:
	quality = clampi(q, LOW, HIGH)
	apply_quality()
	_save()


func q(key: String) -> Variant:
	return QUALITY[quality][key]


## Grafikkarte im Prozessor oder gar keine (Software): ohne gespeicherte Wahl mit niedrigerer Stufe starten.
func _default_quality() -> int:
	if DisplayServer.get_name() == "headless":
		return HIGH
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return MEDIUM
		RenderingDevice.DEVICE_TYPE_CPU:
			return LOW
	return HIGH


## Stufe auf Fenster, Schatten und laufende Szene anwenden (Umgebung, Treffer-Lichter, Szenen mit quality_changed).
func apply_quality() -> void:
	FxPlayer.lights_enabled = q("hit_lights")
	if DisplayServer.get_name() == "headless":
		quality_changed.emit()
		return
	get_tree().root.msaa_3d = q("msaa")
	get_tree().root.mesh_lod_threshold = q("lod")
	RenderingServer.directional_shadow_atlas_set_size(q("shadow_atlas"), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(q("shadow_filter"))
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if we.environment:
			we.environment.glow_enabled = q("glow")
	quality_changed.emit()


func _apply() -> void:
	# Bei Stretch "canvas_items" skaliert das nur die 2D-Oberfläche, die 3D-Ansicht bleibt scharf
	get_tree().root.content_scale_factor = ui_scale
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Nicht größer als der Bildschirm, dann mittig
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size := Vector2i(mini(resolution.x, screen.size.x), mini(resolution.y, screen.size.y))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


## Alle Schriften mit voller Hinting-Stufe und auf ganze Pixel gesetzt: kleine Schrift bleibt scharf, auch wenn
## die Oberfläche krumm skaliert ist (Fenstergröße, UI-Größe). Die Import-Standardwerte (leichtes Hinting,
## Teilpixel-Positionen) lassen dünne Schriften wie Federo unter etwa 14 px verschwommen aussehen.
func _sharpen_fonts() -> void:
	for f in DirAccess.get_files_at("res://assets/fonts"):
		var path := "res://assets/fonts/" + f.trim_suffix(".import").trim_suffix(".remap")
		if not path.ends_with(".ttf") or not ResourceLoader.exists(path):
			continue
		var font := load(path) as FontFile
		if font:
			_fonts.append(font)
			font.hinting = TextServer.HINTING_NORMAL
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "path_lights", path_lights)
	cfg.set_value("display", "style_filter", style_filter)
	cfg.set_value("display", "hud_width", hud_width)
	cfg.set_value("display", "quality", quality)
	cfg.save(SETTINGS)
