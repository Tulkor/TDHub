extends Node
## Eigener Mauszeiger: ein Stil je Modus plus zwei neutrale mit hohem Kontrast, Größe 75–300 % und
## Umriss dunkel, hell oder aus. Die Formen sind SVG im 32er-Raster (Spitze bei 2,2), gerendert in genau
## der eingestellten Größe und als Systemcursor gesetzt (ruckelt nicht mit der Bildrate).
## Entwurf: /mnt/project-files/mockups/barrierefreiheit/index.html. Gespeichert in user://settings.cfg [cursor].
## AUTO folgt dem Stil: Hauptmenü Hub-Messing, im Spiel UiTheme.skin (Arcade, Druidenhain, Plakat, Art déco).

signal changed

const AUTO := "auto"
## Reihenfolge = Auswahlliste in den Einstellungen
const STYLES := ["arcade", "druid", "poster", "deco", "wc3", "white", "yellow"]
const NAMES := {
	"auto": "Passend zum Modus", "arcade": "GemTD Arcade", "druid": "Druidenhain", "poster": "Plakatwand",
	"deco": "Art déco", "wc3": "Hub (Messing)", "white": "Kontrast Weiß", "yellow": "Kontrast Signalgelb",
}
const OUTLINES := ["dark", "light", "none"]
const OUTLINE_NAMES := ["Dunkel", "Hell", "Aus"]
const SIZE_MIN := 0.75
const SIZE_MAX := 3.0
const BASE_PX := 32.0
const VIEW := 34.0  ## viewBox -1..33

## Fantasy-Zeiger nach Art von Path of Exile: Klinge mit Grat (helle und dunkle Hälfte), Parierstange,
## umwickelter Griff und Knauf mit Stein. Jeder Stil ist nur eine Palette (PAL) auf dieselbe Form.
const HEAD := "M2 2 L2.6 20.5 Q6 17 8.8 15.4 Q11 13.6 15.8 14 Z"
const HEAD_L := "M2 2 L2.6 20.5 Q6 17 8.8 15.4 Z"
const GUARD := "M6.4 19.6 L7.4 17.9 L12 13.9 L13.9 13.5 L13.3 15.4 L8.6 19.4 Z"
const GRIP := "M10.1 18.6 L14.8 24 L16.4 22.6 L11.7 17.2 Z"
const POMMEL := Vector3(16.9, 24.6, 2.7)  ## x, y, Radius
const IBEAM := "M11 3 H21 V6 H17.6 V26 H21 V29 H11 V26 H14.4 V6 H11 Z"
## l/d: Klinge hell/dunkel, e: Kante, g/gd: Parierstange, h: Griff, p: Knauf, gem: Stein, r: Grat/Rune
const PAL := {
	"arcade": {"l": "#5a3f8a", "d": "#2a1a4a", "e": "#0d0618", "g": "#ff4fd8", "gd": "#9a2a86", "h": "#2a1a45", "p": "#ff4fd8", "gem": "#22c4ee", "r": "#22c4ee"},
	"druid": {"l": "#d4e3a0", "d": "#7f9a55", "e": "#1a2420", "g": "#8a6a42", "gd": "#4a3420", "h": "#6a4a2a", "p": "#8a6a42", "gem": "#e0a84a", "r": "#eef2cf"},
	"poster": {"l": "#3a3a3a", "d": "#151515", "e": "#151515", "g": "#e8372a", "gd": "#9a1e14", "h": "#151515", "p": "#e8372a", "gem": "#ffd83a", "r": "#ffd83a"},
	"deco": {"l": "#f3dea6", "d": "#a9844f", "e": "#0a1d1f", "g": "#d8b97f", "gd": "#7d6440", "h": "#0f2a2c", "p": "#c9a36a", "gem": "#6fc1b8", "r": "#0f2a2c"},
	"wc3": {"l": "#eef1f4", "d": "#8a96a6", "e": "#140c04", "g": "#d8b97f", "gd": "#7d6440", "h": "#3a2616", "p": "#c9a36a", "gem": "#c0301c", "r": "#ffffff"},
	"white": {"l": "#ffffff", "d": "#e4e4e4", "e": "#000000", "g": "#ffffff", "gd": "#bdbdbd", "h": "#ffffff", "p": "#ffffff", "gem": "#ffffff", "r": "#9a9a9a"},
	"yellow": {"l": "#ffe600", "d": "#e8c800", "e": "#000000", "g": "#ffe600", "gd": "#b39a00", "h": "#ffe600", "p": "#ffe600", "gem": "#000000", "r": "#000000"},
}
var style := AUTO
var size := 1.0
var outline := "dark"
var _shown := ""  ## zuletzt gesetzter Stil+Größe+Umriss, damit nicht unnötig neu gerendert wird


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Display.SETTINGS) == OK:
		style = str(cfg.get_value("cursor", "style", AUTO))
		size = clampf(float(cfg.get_value("cursor", "size", 1.0)), SIZE_MIN, SIZE_MAX)
		outline = str(cfg.get_value("cursor", "outline", "dark"))
	if style != AUTO and style not in STYLES:
		style = AUTO
	if outline not in OUTLINES:
		outline = "dark"
	# Neue Szene (anderer Modus) oder neuer Knopf: Stil neu bestimmen bzw. Knopf bekommt den Klick-Zeiger
	get_tree().node_added.connect(_on_node_added)
	refresh.call_deferred()


func set_style(s: String) -> void:
	style = s
	_save()
	refresh()


func set_size(v: float) -> void:
	size = clampf(v, SIZE_MIN, SIZE_MAX)
	_save()
	refresh()


func set_outline(o: String) -> void:
	outline = o
	_save()
	refresh()


## Stil, der gerade gilt: bei AUTO der des Hauptmenüs bzw. des laufenden Modus.
func active_style() -> String:
	if style != AUTO:
		return style
	if _in_main_menu():
		return "wc3"
	match UiTheme.skin:
		UiTheme.DRUID: return "druid"
		UiTheme.POSTER: return "poster"
		UiTheme.DECO: return "deco"
	return "arcade"


## Hauptmenü ist die laufende Szene (oder direkt darunter, wie in tools/screenshot.gd)
func _in_main_menu() -> bool:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return false
	if scene.scene_file_path.ends_with("main_menu.tscn"):
		return true
	for c in scene.get_children():
		if c.scene_file_path.ends_with("main_menu.tscn"):
			return true
	return false


func refresh() -> void:
	var st := active_style()
	var key := "%s|%.2f|%s" % [st, size, outline]
	if key == _shown:
		return
	_shown = key
	if DisplayServer.get_name() != "headless":
		var px := pixels()
		var hot := Vector2(3.0, 3.0) * px / VIEW
		Input.set_custom_mouse_cursor(texture(st, "arrow", px), Input.CURSOR_ARROW, hot)
		Input.set_custom_mouse_cursor(texture(st, "click", px), Input.CURSOR_POINTING_HAND, hot)
		Input.set_custom_mouse_cursor(texture(st, "text", px), Input.CURSOR_IBEAM, Vector2(px, px) * 0.5)
	changed.emit()


## Kantenlänge des Cursorbilds in Pixeln
func pixels(scale := -1.0) -> int:
	return roundi(BASE_PX * (size if scale < 0.0 else scale))


## Cursorbild als Textur (auch für die Vorschau in den Einstellungen). kind: arrow, click, text.
func texture(st: String, kind: String, px: int, ol := "") -> ImageTexture:
	var img := Image.new()
	if img.load_svg_from_string(svg(st, kind, outline if ol == "" else ol), px / VIEW) != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


func svg(st: String, kind: String, ol: String) -> String:
	var c: Dictionary = PAL.get(st, PAL.white)
	var oc := "#ffffff" if ol == "light" else "#000000"
	var out := ""
	if ol != "none":
		out = '<g fill="%s" stroke="%s" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round">%s</g>' % [oc, oc, IBEAM_PATH() if kind == "text" else _silhouette(st)]
	var inner := ""
	if kind == "text":
		inner = '<path d="%s" fill="%s" stroke="%s" stroke-width="1"/><path d="M16 9 L17.2 10.5 L16 12 L14.8 10.5 Z" fill="%s"/>' % [IBEAM, c.l, c.e, c.gem if st != "white" else c.e]
	else:
		inner = _body(st, c)
		if kind == "click":
			var edge: String = c.e if ol == "none" else oc
			for r in [[9, 5, 12.5, 3], [10.5, 8.5, 14.5, 8.5], [8, 1.8, 9.5, 0.9]]:
				var d := "M%s %s L%s %s" % r
				inner += '<path d="%s" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % [d, edge]
				inner += '<path d="%s" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % [d, c.g]
	return '<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" viewBox="-1 -1 34 34">%s%s</svg>' % [out, inner]


func IBEAM_PATH() -> String:
	return '<path d="%s"/>' % IBEAM


## Umriss-Form: alle Teile, beim Plakat zusätzlich der verrutschte Rotdruck
func _silhouette(st: String) -> String:
	var s := '<path d="%s"/><path d="%s"/><path d="%s"/><circle cx="%s" cy="%s" r="%s"/>' % [HEAD, GUARD, GRIP, POMMEL.x, POMMEL.y, POMMEL.z]
	if st == "poster":
		s += '<path d="%s" transform="translate(1.6 1.1)"/>' % HEAD
	return s


func _body(st: String, c: Dictionary) -> String:
	var ew := 1.5 if st in ["white", "yellow"] else 0.9
	var b := ""
	if st == "poster":
		b += '<path d="%s" transform="translate(1.6 1.1)" fill="#e8372a"/>' % HEAD
	# Griff mit Wicklung, Knauf mit Stein
	b += '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % [GRIP, c.h, c.e, ew]
	b += '<path d="M11.4 19.9 L12.9 18.6 M12.7 21.4 L14.2 20.1 M14 22.9 L15.5 21.6" stroke="%s" stroke-width="0.8"/>' % c.g
	b += '<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="%s"/>' % [POMMEL.x, POMMEL.y, POMMEL.z, c.p, c.e, ew]
	b += '<circle cx="%s" cy="%s" r="1.45" fill="%s" stroke="%s" stroke-width="0.5"/>' % [POMMEL.x, POMMEL.y, c.gem, c.e]
	b += '<circle cx="16.4" cy="24.1" r="0.5" fill="#ffffff" fill-opacity="0.8"/>'
	# Klinge: dunkle Hälfte, helle Hälfte, Kante, Grat
	b += '<path d="%s" fill="%s"/><path d="%s" fill="%s"/>' % [HEAD, c.d, HEAD_L, c.l]
	b += '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="miter"/>' % [HEAD, c.e, ew]
	match st:
		"druid":
			b += '<path d="M2.8 3.6 L8.2 14.6 M4.2 9 L3.4 13 M5.6 11.8 L9.6 11.2 M6.6 14 L4.8 16.8" stroke="%s" stroke-width="0.8" fill="none" stroke-linecap="round"/>' % c.r
		"deco":
			b += '<path d="M3.9 8.2 L4.2 16.6 L7.6 14.3 Z" fill="%s"/><path d="M4.8 12 L5 15 L6.6 13.9 Z" fill="%s"/>' % [c.r, c.g]
		"arcade":
			b += '<path d="M2.7 3.2 L8.2 14.6" stroke="%s" stroke-width="0.9"/><path d="M3.3 6 L3.6 17.5" stroke="%s" stroke-width="0.8"/>' % [c.r, c.g]
		_:
			b += '<path d="M2.8 3.4 L8.3 14.6" stroke="%s" stroke-width="0.6" stroke-opacity="0.8"/>' % c.r
	# Parierstange mit dunkler Unterkante
	b += '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % [GUARD, c.g, c.e, ew]
	b += '<path d="M8.4 18.8 L13 14.9" stroke="%s" stroke-width="0.9"/>' % c.gd
	b += '<path d="M9.7 15.9 L10.9 17.3 L9.7 18.3 L8.6 17 Z" fill="%s" stroke="%s" stroke-width="0.5"/>' % [c.gem, c.e]
	return b
## Neue Szene: Stil neu bestimmen (AUTO). Knöpfe zeigen den Klick-Zeiger, wenn sie nichts anderes wollen.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if node.mouse_default_cursor_shape == Control.CURSOR_ARROW:
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif node.get_parent() == get_tree().root:
		refresh.call_deferred()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Display.SETTINGS)
	cfg.set_value("cursor", "style", style)
	cfg.set_value("cursor", "size", size)
	cfg.set_value("cursor", "outline", outline)
	cfg.save(Display.SETTINGS)
