class_name Wc3Button
extends Button
## Knopf der Steinsäule im Hauptmenü (Wc3Theme): spitzes Sechseck mit Messingrand, innen Fels (Hauptknopf, rot)
## oder Stein (klein, dunkel), eine dünne Innenlinie folgt der Außenform. Der Hotkey-Buchstabe ist hell.

const TIP := 14.0

var main := false
## Text ohne Übersetzung; gezeigt wird tr(label_text).
var label_text := ""
## Stelle des Hotkey-Buchstabens im übersetzten Text, -1 = keiner.
var hotkey := -1
## Erklärung für die Hinweiszeile unter dem Logo.
var description := ""
## Kleiner Text rechts im Knopf (z. B. Spielerzahl); dann steht der Name links.
var side_text := ""
## Stimmen als kleine Rubine links vom side_text (Lobby): pips leuchten, von pip_max; pip_max 0 = keine.
var pips := 0
var pip_max := 0

var _tex: Texture2D
var _rock: Texture2D
## Messingrahmen (3D-Render) auf eigener Ebene mit Glanz.
var _brass: Wc3Theme.BrassLayer
static var _frame: StyleBoxTexture


func _init(text_de: String, is_main: bool) -> void:
	label_text = text_de
	main = is_main
	custom_minimum_size.y = 56 if main else 46
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_tex = load(Wc3Theme.ROCK if main else Wc3Theme.STONE)
	_rock = load(Wc3Theme.ROCK)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	_brass = Wc3Theme.BrassLayer.new(_draw_frame)
	add_child(_brass)
	resized.connect(_brass.queue_redraw)


## Rahmen als Neunteiler aus dem Render (300 × 56, Spitze 14), Spitzen bleiben bei jeder Breite gleich.
static func frame_box() -> StyleBoxTexture:
	if _frame == null:
		_frame = StyleBoxTexture.new()
		_frame.texture = Wc3Theme.brass("knopf_rahmen")
		_frame.draw_center = false
		_frame.texture_margin_left = 20
		_frame.texture_margin_right = 20
		_frame.texture_margin_top = 10
		_frame.texture_margin_bottom = 10
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			_frame.set_expand_margin(side, 2)
	return _frame


func _draw_frame(ci: CanvasItem) -> void:
	ci.draw_style_box(frame_box(), Rect2(Vector2.ZERO, size))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func shown_text() -> String:
	return tr(label_text)


func font_size() -> int:
	if main:
		return 22
	return 16 if size.x < 260 else 18


func _draw() -> void:
	var hover := is_hovered() and not disabled
	# Umschaltknopf (Modusliste): eingeschaltet sieht er aus wie ein Hauptknopf (Fels, rot), ohne eingedrückt zu wirken
	var chosen := toggle_mode and button_pressed and not disabled
	var red := main or chosen
	var down := is_pressed() and not toggle_mode
	var r := Rect2(Vector2.ZERO, size)
	var outer := Wc3Theme.hex(r, TIP)
	if hover and main:
		# Glühen um den roten Knopf
		for i in 4:
			draw_polyline(Wc3Theme.closed(Wc3Theme.hex(r.grow(1.5 + i * 1.5), TIP + 1 + i)), Color(1.0, 0.45, 0.2, 0.12 - i * 0.025), 2.0, true)
	if chosen:
		for i in 4:
			draw_polyline(Wc3Theme.closed(Wc3Theme.hex(r.grow(1.5 + i * 1.5), TIP + 1 + i)), Color(1.0, 0.45, 0.2, 0.1 - i * 0.02), 2.0, true)
	# Rahmen kommt aus dem Messing-Render (_draw_frame); heller beim Überfahren, grau wenn gesperrt
	_brass.modulate = Color(0.55, 0.55, 0.55) if disabled else (Color(1.25, 1.2, 1.1) if hover or chosen else Color.WHITE)
	# Schatten des Messingrahmens nach rechts unten (Licht der Renders von links oben)
	for o in Wc3Theme.SHADOW_STEPS:
		var sh := PackedVector2Array()
		for pt in outer:
			sh.append(pt + o * 0.8)
		draw_colored_polygon(sh, Wc3Theme.SHADOW)
	draw_colored_polygon(outer, Wc3Theme.INK)
	var fr := r.grow(-3)
	var face := Wc3Theme.hex(fr, TIP - 2)
	var tint: Color
	if red:
		tint = Wc3Theme.RED_HOVER if hover else Wc3Theme.RED
	else:
		tint = Wc3Theme.DARK_HOVER if hover else Wc3Theme.DARK
	if disabled:
		tint = Wc3Theme.DISABLED
	if down:
		tint = tint.darkened(0.25)
	Wc3Theme.fill_textured(self, face, _rock if red else _tex, 180.0 if red else 200.0, tint)
	# Innenschatten: nach innen dunkler werdende Ränder, oben ein schwacher Lichtstreif, unten Schatten
	for i in 5:
		draw_polyline(Wc3Theme.closed(Wc3Theme.hex(fr.grow(-1.5 - i * 2.0), TIP - 2 - i)), Color(0, 0, 0, 0.22 - i * 0.04), 2.0, true)
	draw_line(Vector2(TIP + 2, 5), Vector2(size.x - TIP - 2, 5), Color(1.0, 0.86, 0.63, 0.1), 2.0)
	draw_line(Vector2(TIP + 2, size.y - 6), Vector2(size.x - TIP - 2, size.y - 6), Color(0, 0, 0, 0.35), 3.0)
	draw_polyline(Wc3Theme.closed(face), Wc3Theme.INK, 1.0, true)
	_draw_text(hover or chosen, down)


## Rubine rechtsbündig bis x: leuchtend für Stimmen, dunkel für die übrigen Spieler.
func _draw_pips(right_x: float) -> void:
	if pip_max <= 0:
		return
	var tex := Wc3Theme.brass("rubin")
	var h := 18.0
	var w := h * tex.get_width() / tex.get_height()
	var x := right_x - pip_max * (w + 2)
	for i in pip_max:
		var col := Color.WHITE if i < pips else Color(0.22, 0.2, 0.2, 0.9)
		draw_texture_rect(tex, Rect2(x + i * (w + 2), (size.y - h) / 2, w, h), false, col)


func _draw_text(hover: bool, down: bool) -> void:
	var text := shown_text()
	var fs := font_size()
	var f := Wc3Theme.font(2 if main else 1)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((size.x - tw) / 2, (size.y + f.get_ascent(fs) - f.get_descent(fs)) / 2)
	if side_text != "" or pip_max > 0:
		pos.x = TIP + 16
		var sf := Wc3Theme.font(1)
		var sfs := 14
		var sw := sf.get_string_size(side_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		var sp := Vector2(size.x - TIP - 16 - sw, (size.y + sf.get_ascent(sfs) - sf.get_descent(sfs)) / 2)
		sf.draw_string(get_canvas_item(), sp + Vector2(0, 2), side_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color.BLACK)
		sf.draw_string(get_canvas_item(), sp, side_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Wc3Theme.DISABLED_TEXT if disabled else Wc3Theme.CREAM)
		_draw_pips(sp.x - 10)
	if down:
		pos += Vector2(0, 1)
	var col := Wc3Theme.HOT if hover else Wc3Theme.TEXT
	if disabled:
		col = Wc3Theme.DISABLED_TEXT
	# Schatten, dann Text in drei Teilen, damit der Hotkey-Buchstabe heller sein kann
	f.draw_string(get_canvas_item(), pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
	if hotkey < 0 or hotkey >= text.length():
		f.draw_string(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	else:
		var x := pos.x
		for part in [[text.substr(0, hotkey), col], [text.substr(hotkey, 1), Wc3Theme.HOT], [text.substr(hotkey + 1), col]]:
			f.draw_string(get_canvas_item(), Vector2(x, pos.y), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, part[1])
			x += f.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
