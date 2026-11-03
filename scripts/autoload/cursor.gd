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

const ARROW := "M2 2 L2 25 L8 19.5 L12.2 28.6 L16 27 L11.8 18 L19.5 18 Z"
const IBEAM := "M11 3 H21 V6 H17.6 V26 H21 V29 H11 V26 H14.4 V6 H11 Z"
const ARCADE_SIL := "M2 2 H4 V4 H6 V6 H8 V8 H10 V10 H12 V12 H14 V14 H16 V16 H18 V19 H12 V21 H13 V23 H14 V25 H15 V28 H11 V26 H10 V24 H9 V22 H8 V21 H6 V23 H4 V25 H2 Z"
const DRUID_SIL := "M2 2 Q2.6 14 3 24.5 Q6.5 21.5 8.6 19.6 L12.6 28.4 L15.8 27 L11.9 18.2 Q15.5 17.6 20.5 18 Q11.5 8 2 2 Z"
const POSTER_SIL := "M2 2 L2.4 25.2 L8.1 19.9 L12.4 28.8 L16.2 27.1 L12 18.3 L19.8 17.6 Z"
## Füllung und Kante je Stil (Funken des „klickbar“-Zeigers und I-Balken)
const FILL := {
	"arcade": ["#ff4fd8", "#22c4ee"], "druid": ["#a8c27a", "#1a2420"], "poster": ["#151515", "#e8372a"],
	"deco": ["#c9a36a", "#0f2a2c"], "wc3": ["#d8b97f", "#140c04"], "white": ["#ffffff", "#000000"],
	"yellow": ["#ffe600", "#000000"],
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
	var sil := _silhouette(st)
	var shadow := 2.0 if st == "arcade" else (2.2 if st == "poster" else 0.0)
	var oc := "#ffffff" if ol == "light" else "#000000"
	var fill: Array = FILL.get(st, FILL.white)
	var out := ""
	if ol != "none":
		var p := IBEAM if kind == "text" else sil
		out = '<g fill="%s" stroke="%s" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round"><path d="%s"/>' % [oc, oc, p]
		if shadow > 0.0 and kind != "text":
			out += '<path d="%s" transform="translate(%s %s)"/>' % [p, shadow, shadow * 0.7]
		out += "</g>"
	var inner := ""
	if kind == "text":
		inner = '<path d="%s" fill="%s" stroke="%s" stroke-width="1"/>' % [IBEAM, fill[0], fill[1]]
	else:
		inner = _body(st)
		if kind == "click":
			var edge: String = fill[1] if ol == "none" else oc
			for r in [[9, 5, 12.5, 3], [10.5, 8.5, 14.5, 8.5], [8, 1.8, 9.5, 0.9]]:
				var d := "M%s %s L%s %s" % r
				inner += '<path d="%s" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % [d, edge]
				inner += '<path d="%s" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % [d, fill[0]]
	return '<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" viewBox="-1 -1 34 34">%s%s</svg>' % [out, inner]


func _silhouette(st: String) -> String:
	match st:
		"arcade": return ARCADE_SIL
		"druid": return DRUID_SIL
		"poster": return POSTER_SIL
	return ARROW


func _body(st: String) -> String:
	match st:
		"arcade":
			return ('<path d="%s" transform="translate(2 2)" fill="#22c4ee"/><path d="%s" fill="#ff4fd8"/>' % [ARCADE_SIL, ARCADE_SIL]
				+ '<path d="M4 6 H6 V20 H4 Z" fill="#ffc2f2"/><path d="%s" fill="none" stroke="#0d0618" stroke-width="1"/>' % ARCADE_SIL)
		"druid":
			return ('<defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#c8de8c"/><stop offset="1" stop-color="#5f7a45"/></linearGradient></defs>'
				+ '<path d="M8.6 19.6 L12.6 28.4 L15.8 27 L11.9 18.2 Z" fill="#7a5a3a" stroke="#2a1d12" stroke-width="1"/>'
				+ '<path d="M2 2 Q2.6 14 3 24.5 Q6.5 21.5 8.6 19.6 Q10 19 11.9 18.2 Q15.5 17.6 20.5 18 Q11.5 8 2 2 Z" fill="url(#lg)" stroke="#1a2420" stroke-width="1.1"/>'
				+ '<path d="M3 3.5 Q7 11 11 17.5 M5.5 10.5 L4 15 M7.8 13.5 L12 13.4 M9 16 L6.5 20" stroke="#eef2cf" stroke-width="0.9" fill="none" stroke-linecap="round"/>')
		"poster":
			return ('<path d="%s" transform="translate(2.2 1.4)" fill="#e8372a"/><path d="%s" fill="#151515"/>' % [POSTER_SIL, POSTER_SIL]
				+ '<path d="M3.6 6 L3.9 17" stroke="#ffd83a" stroke-width="1.6" stroke-linecap="round"/>')
		"deco":
			return ('<defs><linearGradient id="dg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f3dea6"/><stop offset=".55" stop-color="#c9a36a"/><stop offset="1" stop-color="#7d6440"/></linearGradient></defs>'
				+ '<path d="%s" fill="url(#dg)" stroke="#0a1d1f" stroke-width="1.1"/>' % ARROW
				+ '<path d="M4.2 8 L4.2 19.5 L8.8 15.2 L13.6 15.2 Z" fill="#0f2a2c"/><path d="M5.4 12.6 L5.4 16.4 L7.6 14.4 Z" fill="#d8b97f"/>')
		"wc3":
			return ('<path d="M2 2 L2 25 L8 19.5 L11.8 18 L19.5 18 Z" fill="#e6c98c"/><path d="M2 2 L8.6 15 L8 19.5 L11.8 18 L19.5 18 Z" fill="#9a7a48"/>'
				+ '<path d="M8 19.5 L12.2 28.6 L16 27 L11.8 18 Z" fill="#5a4428"/>'
				+ '<path d="%s" fill="none" stroke="#140c04" stroke-width="1.1"/>' % ARROW
				+ '<circle cx="9.6" cy="17.4" r="2" fill="#b0281a" stroke="#140c04" stroke-width=".8"/><circle cx="9" cy="16.8" r=".6" fill="#ffb59c"/>')
		"yellow":
			return '<path d="%s" fill="#ffe600" stroke="#000" stroke-width="2" stroke-linejoin="round"/><path d="M4.8 9 L4.8 18" stroke="#000" stroke-width="1.4"/>' % ARROW
	return '<path d="%s" fill="#ffffff" stroke="#000" stroke-width="1.8" stroke-linejoin="round"/>' % ARROW


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
