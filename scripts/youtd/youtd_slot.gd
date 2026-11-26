class_name YoutdSlot
extends PanelContainer
## Ein Feld mit Icon für YouTD (Lager, Tower-Plätze, Würfel): Rahmen in Seltenheitsfarbe, Zahl unten rechts,
## Level oben links. Felder mit drag_data lassen sich ziehen, Felder mit on_drop nehmen Gezogenes an.

signal clicked(button: int)

var drag_data = null            ## Daten beim Ziehen (null = nicht ziehbar)
var on_drop := Callable()       ## func(data) -> void
var accepts := Callable()       ## func(data) -> bool; leer = alles mit on_drop
var _icon: TextureRect
var _count: Label
var _level: Label
var _border := Color.TRANSPARENT
var _hover := false
var _roles := {}
var _badges: Control


func _init(tex: Texture2D = null, border := Color.TRANSPARENT, side := 44.0) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_border = border
	_icon = TextureRect.new()
	_icon.texture = tex
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = _corner_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, UiTheme.TEXT)
	_level = _corner_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, UiTheme.COIN)
	_badges = Control.new()
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.draw.connect(_draw_badges)
	_badges.resized.connect(_badges.queue_redraw)
	add_child(_badges)
	_style()
	mouse_entered.connect(func(): _hover = true; _style())
	mouse_exited.connect(func(): _hover = false; _style())


func _corner_label(h: HorizontalAlignment, v: VerticalAlignment, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


## Zahl unten rechts (Ladungen, Anzahl), leer = keine.
func set_count(text: String) -> YoutdSlot:
	_count.text = text
	return self


## Kleine Zahl oben links (Item-Level).
func set_level(text: String) -> YoutdSlot:
	_level.text = text
	return self


## Symbole eines Towers (YoutdData.tower_roles): unten links Fadenkreuz (Einzelziel), Explosion (Masse) oder Vogel
## (gegen Flieger), oben rechts ein Blitz für Unterstützung: violett Kontrolle, grün Aura, gelb Ökonomie.
func set_roles(roles: Dictionary) -> YoutdSlot:
	_roles = roles
	var parts := []
	match str(roles.get("attack", "")):
		"single":
			parts.append(tr("Einzelziel"))
		"mass":
			parts.append(tr("Flächenschaden"))
		"air":
			parts.append(tr("Gegen Flieger"))
	match str(roles.get("util", "")):
		"cc":
			parts.append(tr("Kontrolle (verlangsamen, betäuben)"))
		"aura":
			parts.append(tr("Aura für Tower in der Nähe"))
		"eco":
			parts.append(tr("Ökonomie (Gold, Erfahrung, Items)"))
	set_meta("roles_text", " · ".join(parts))
	_badges.queue_redraw()
	return self


## Text zu den Symbolen für Tooltips ("" = keine).
func roles_text() -> String:
	return str(get_meta("roles_text", ""))


func _draw_badges() -> void:
	if _roles.is_empty():
		return
	var s := size.x / 44.0
	var dark := Color(UiTheme.BG, 0.85)
	var r := 7.5 * s
	var c := Vector2(r + 1, size.y - r - 1)
	_badges.draw_circle(c, r, dark)
	match str(_roles.get("attack", "")):
		"single":
			_badges.draw_arc(c, 4.0 * s, 0, TAU, 16, UiTheme.TEXT, 1.4 * s, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_badges.draw_line(c + d * 2.0 * s, c + d * 6.5 * s, UiTheme.TEXT, 1.4 * s, true)
		"mass":
			var pts := PackedVector2Array()
			for i in 16:
				var ang := TAU * i / 16.0 - PI / 2
				pts.append(c + Vector2(cos(ang), sin(ang)) * (6.5 if i % 2 == 0 else 3.0) * s)
			_badges.draw_colored_polygon(pts, UiTheme.MISSING)
			_badges.draw_circle(c, 2.0 * s, UiTheme.COIN)
		"air":
			var wing := PackedVector2Array([c + Vector2(-6, 0) * s, c + Vector2(-3, -3) * s, c + Vector2(0, 0.5) * s,
					c + Vector2(3, -3) * s, c + Vector2(6, 0) * s])
			_badges.draw_polyline(wing, UiTheme.TEXT, 1.6 * s, true)
	var util := str(_roles.get("util", ""))
	if util == "":
		return
	var col: Color = {"cc": UiTheme.PURPLE_LIGHT, "aura": UiTheme.HAVE, "eco": UiTheme.COIN}.get(util, UiTheme.TEXT)
	var b := Vector2(size.x - r - 1, r + 1)
	_badges.draw_circle(b, r, dark)
	var bolt := PackedVector2Array([b + Vector2(1.5, -6) * s, b + Vector2(-3.5, 1) * s, b + Vector2(-0.3, 1) * s,
			b + Vector2(-1.5, 6) * s, b + Vector2(3.5, -1) * s, b + Vector2(0.3, -1) * s])
	_badges.draw_colored_polygon(bolt, col)


## Hervorheben (gewählt, im Würfel); gedimmt = gerade nicht nutzbar.
func set_marked(on: bool, dimmed := false) -> YoutdSlot:
	set_meta("marked", on)
	modulate.a = 0.5 if dimmed else 1.0
	_style()
	return self


func _style() -> void:
	var marked := bool(get_meta("marked", false))
	var fill := UiTheme.CYAN if marked else UiTheme.BG
	var edge := _border if _border.a > 0.0 else UiTheme.BORDER
	if _hover and not marked:
		fill = UiTheme.PANEL
	var sb := UiTheme.box(fill, edge, 0, 2, 2.0)
	if _border.a <= 0.0:
		sb.border_color = Color(edge, 0.6)
	add_theme_stylebox_override("panel", sb)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		clicked.emit(ev.button_index)
		accept_event()


## Lange Texte (Fähigkeiten aus YouTD 2) umbrechen statt den Tooltip über den Bildschirm zu ziehen.
func _make_custom_tooltip(for_text: String) -> Object:
	var l := Label.new()
	l.text = for_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420.0 if for_text.length() > 60 else 0.0
	l.add_theme_font_size_override("font_size", 14)
	return l


func _get_drag_data(_at: Vector2) -> Variant:
	if drag_data == null:
		return null
	var p := TextureRect.new()
	p.texture = _icon.texture
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.size = size
	p.position = -size * 0.5
	var c := Control.new()
	c.add_child(p)
	set_drag_preview(c)
	return drag_data


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not on_drop.is_valid() or data == null or data == drag_data:
		return false
	return accepts.call(data) if accepts.is_valid() else true


func _drop_data(_at: Vector2, data: Variant) -> void:
	on_drop.call(data)
