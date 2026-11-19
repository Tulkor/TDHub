class_name HdUiStyle
extends RefCounted
## Bollwerk: „Eisenliturgie“. Nachtblau, warmes Gold, doppelte geschmiedete Rahmen.
## Nur über UiTheme.BOLLWERK aktiv; semantische Kampf-/Elementfarben bleiben erhalten.

const COLORS := {
	"BG": Color("060b16"), "BAR": Color("080e1a"), "PANEL": Color("0a1220"), "PANEL_2": Color("111b2b"),
	"BORDER": Color("887047"), "BORDER_2": Color("a88a58"), "TEXT": Color("eee2c7"), "MUTED": Color("b7aa91"),
	"DIM": Color("d8cbb1"), "GOLD": Color("d6b37a"), "GOLD_DARK": Color("080e1a"), "CYAN": Color("749eaf"),
	"CYAN_TEXT": Color("9bbdcc"), "COIN": Color("e4c38b"), "PURPLE": Color("776986"), "PURPLE_LIGHT": Color("b1a0c8"),
	"HAVE": Color("91ba98"), "MISSING": Color("d48075"), "SHADOW": Color("03060d"),
}
const GOLD := Color("d6b37a")
const GOLD_HI := Color("f0d7a4")
const INK := Color("080e1a")
const BODY := "res://assets/fonts/Federo-Regular.ttf"
const HEADING := "res://assets/fonts/Cinzel-Bold.ttf"
const DISPLAY := "res://assets/fonts/CinzelDecorative-Black.ttf"
const FALLBACK := "res://assets/fonts/DejaVuSansMono.ttf"
static var _fonts: Dictionary = {}
static var _theme: Theme
static var _metal: ShaderMaterial
static var _text_metal: ShaderMaterial
static var _icon_metal: ShaderMaterial
static var _leather: Texture2D
static var _button_face: Texture2D
const LEATHER_PATH := "res://assets/textures/ui/bollwerk_leather.png"


static func leather_texture() -> Texture2D:
	if _leather==null and ResourceLoader.exists(LEATHER_PATH):_leather=load(LEATHER_PATH)
	return _leather

static func button_face() -> Texture2D:
	if _button_face==null:_button_face=load(Wc3Theme.ROCK)
	return _button_face

static func leather_fill(item: RID, shape: PackedVector2Array, color: Color) -> bool:
	var texture := leather_texture()
	if texture==null or color.b<=color.r or color.v>.3:return false
	var uv := PackedVector2Array()
	for point in shape:uv.append(point/256.0)
	RenderingServer.canvas_item_set_default_texture_repeat(item,RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var tint := Color(color.r/COLORS.PANEL.r,color.g/COLORS.PANEL.g,color.b/COLORS.PANEL.b,color.a)
	RenderingServer.canvas_item_add_polygon(item,shape,PackedColorArray([tint]),uv,texture.get_rid())
	return true

static func menu_button_style(state: String, pad := 10.0) -> MenuButtonFrame:
	var style := MenuButtonFrame.new()
	style.state=state
	style.line=GOLD_HI if state in ["hover","hover_pressed","focus"] else GOLD
	style.content_margin_left=pad
	style.content_margin_right=pad
	style.content_margin_top=pad*.65
	style.content_margin_bottom=pad*.65
	return style


static func metal_material() -> ShaderMaterial:
	if _metal==null:
		_metal=Wc3Theme.gloss_material().duplicate()
		_metal.set_shader_parameter("palette_metal",1.0)
		_metal.set_shader_parameter("strength",.18)
	return _metal

static func text_metal_material() -> ShaderMaterial:
	if _text_metal==null:
		_text_metal=metal_material().duplicate()
		_text_metal.set_shader_parameter("text_relief",1.0)
		_text_metal.set_shader_parameter("strength",.12)
	return _text_metal

static func icon_metal_material() -> ShaderMaterial:
	if _icon_metal==null:
		_icon_metal=text_metal_material().duplicate()
		_icon_metal.set_shader_parameter("relief_pixels",2.5)
		_icon_metal.set_shader_parameter("metal_surface",1.0)
		_icon_metal.set_shader_parameter("strength",.16)
	return _icon_metal


## Gerenderte Metallleiste auf beliebigen Konturen, mit dem bisherigen Farbwert als Tönung.
static func metal_outline(item: RID, shape: PackedVector2Array, color: Color, width: float) -> void:
	var texture: Texture2D=Wc3Theme.brass("kante_h")
	for i in shape.size():
		var a := shape[i]
		var b := shape[(i+1)%shape.size()]
		var normal := (b-a).normalized().orthogonal()*width*.5
		RenderingServer.canvas_item_add_polygon(item,PackedVector2Array([a+normal,b+normal,b-normal,a-normal]),PackedColorArray([color]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),texture.get_rid())


static func font(bold := false) -> Font:
	return _font(HEADING if bold else BODY)


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		var f := FontVariation.new()
		f.base_font = load(path)
		f.fallbacks = [load(FALLBACK)]
		_fonts[path] = f
	return _fonts[path]


static func frame(bg: Color, border := GOLD, pad := 10.0, cut := 8.0, ornate := false) -> IronFrame:
	var s := IronFrame.new()
	s.fill = bg
	s.line = border
	s.cut = cut
	s.ornate = ornate
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.65 + (3.0 if ornate else 0.0)
	s.content_margin_bottom = pad * 0.65 + (3.0 if ornate else 0.0)
	return s


static func panel(pad := 14.0, _alpha := 0.95, border := Color.TRANSPARENT) -> StyleBox:
	return frame(COLORS.PANEL, GOLD if border.a == 0.0 else border, pad + 3.0, 10.0, true)


static func skill_frame(active := false) -> StyleBox:
	return frame(GOLD if active else COLORS.PANEL_2, GOLD_HI if active else GOLD, 7.0, 8.0)


static func upgrade_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(28, 28)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := frame(GOLD if state == "pressed" else INK, GOLD_HI if state == "hover" else GOLD, 3.0, 0.0)
		s.diamond = true
		if state == "disabled":
			s.line = COLORS.BORDER.darkened(0.35)
		button.add_theme_stylebox_override(state, s)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", GOLD_HI)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", COLORS.MUTED.darkened(0.3))


static func accent_button(button: Button, bg: Color, fg: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state,menu_button_style(state,12.0))
	button.add_theme_font_override("font", font(true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, COLORS.TEXT)


static func title(label: Label, size := 0) -> Label:
	label.uppercase = true
	label.add_theme_font_override("font", _font(DISPLAY) if size >= 24 else font(true))
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD_HI)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


static func heading(label: Label, color := Color.TRANSPARENT) -> Label:
	label.uppercase = true
	label.add_theme_font_override("font", font(true))
	label.add_theme_color_override("font_color", GOLD if color.a == 0.0 else color)
	return label


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 15
	for control in ["Label", "Button", "CheckBox", "CheckButton", "OptionButton", "RichTextLabel", "TooltipLabel"]:
		t.set_color("font_color", control, COLORS.TEXT)
	t.set_stylebox("panel", "PanelContainer", panel(12.0))
	for control in ["Button", "OptionButton"]:
		t.set_font("font",control,Wc3Theme.font(1))
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:t.set_stylebox(state,control,menu_button_style(state))
		t.set_stylebox("focus",control,frame(Color.TRANSPARENT,GOLD_HI,10.0))
		t.set_color("font_hover_color", control, GOLD_HI)
		t.set_color("font_pressed_color", control, COLORS.TEXT)
		t.set_color("font_hover_pressed_color", control, COLORS.TEXT)
		t.set_color("font_disabled_color", control, Color("7e786c"))
	t.set_stylebox("panel", "TooltipPanel", panel(10.0))
	t.set_stylebox("panel", "PopupMenu", frame(INK, GOLD, 9.0))
	t.set_stylebox("hover", "PopupMenu", frame(COLORS.PANEL_2, GOLD, 5.0))
	t.set_color("font_color", "PopupMenu", COLORS.TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD_HI)
	t.set_stylebox("normal", "LineEdit", frame(COLORS.PANEL_2, COLORS.BORDER, 9.0))
	t.set_stylebox("focus", "LineEdit", frame(COLORS.PANEL_2, GOLD_HI, 9.0))
	t.set_color("font_color", "LineEdit", COLORS.TEXT)
	t.set_color("caret_color", "LineEdit", GOLD_HI)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.3))
	for control in ["TabContainer", "ItemList"]:
		t.set_stylebox("panel", control, panel(10.0))
	var separator := StyleBoxLine.new()
	separator.color = Color(GOLD, 0.5)
	separator.thickness = 1
	t.set_stylebox("separator", "HSeparator", separator)
	t.set_constant("separation", "HSeparator", 4)
	for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(state, "VScrollBar", frame(INK if state == "scroll" else GOLD.darkened(0.2), Color.TRANSPARENT, 3.0, 0.0))
	_theme = t
	return t


## Skalierbare Grundkontur: Doppelrahmen, Rautenknoten und Lanzetten.
## HdUiMetal legt gerenderte Metallleisten mit derselben Kontur darüber.
class IronFrame extends StyleBox:
	var fill := Color.TRANSPARENT
	var line := GOLD
	var cut := 8.0
	var ornate := false
	var diamond := false

	func draw_metal(item: RID, rect: Rect2) -> void:
		if line.a<=0 or rect.size.x<=0 or rect.size.y<=0:return
		var width := minf(4.0,minf(rect.size.x,rect.size.y)*.16)
		var inset := minf(2.0,minf(rect.size.x,rect.size.y)*.2)
		HdUiStyle.metal_outline(item,_shape(rect.grow(-inset)),line,width)
		if not diamond and rect.size.x>38 and rect.size.y>24:
			HdUiStyle.metal_outline(item,_shape(rect.grow(-6)),Color(line,line.a*.65),1.5)

	func _draw(item: RID, rect: Rect2) -> void:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var shape := _shape(rect.grow(-1.0))
		if fill.a > 0.0:
			if not HdUiStyle.leather_fill(item,shape,fill):RenderingServer.canvas_item_add_polygon(item, shape, [fill])
		if line.a <= 0.0:
			return
		_outline(item, shape, line, 1.5)
		if diamond:
			return
		if rect.size.x > 38.0 and rect.size.y > 24.0:
			_outline(item, _shape(rect.grow(-5.0)), Color(line, line.a * 0.48), 1.0)
		if not ornate or rect.size.x < 100.0 or rect.size.y < 35.0:
			return
		var left := rect.position.x + 1.0
		var right := rect.end.x - 1.0
		var top := rect.position.y + 1.0
		var bottom := rect.end.y - 1.0
		var middle := rect.get_center().x
		for y in [top, bottom]:
			var side := -1.0 if y == top else 1.0
			RenderingServer.canvas_item_add_polyline(item, PackedVector2Array([
				Vector2(middle - 24, y), Vector2(middle - 10, y), Vector2(middle, y + side * 5),
				Vector2(middle + 10, y), Vector2(middle + 24, y)]), [line], 1.0, true)
			_diamond(item, Vector2(middle, y), 3.5)
		for x in [left, right]:
			_diamond(item, Vector2(x, top + cut), 2.4)
			_diamond(item, Vector2(x, bottom - cut), 2.4)

	func _shape(rect: Rect2) -> PackedVector2Array:
		var a := rect.position
		var b := rect.end
		if diamond:
			var center := rect.get_center()
			var half := minf(rect.size.x, rect.size.y) * 0.5
			return PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)])
		var k := minf(cut, minf(rect.size.x, rect.size.y) * 0.22)
		return PackedVector2Array([Vector2(a.x + k, a.y), Vector2(b.x - k, a.y), Vector2(b.x, a.y + k),
			Vector2(b.x, b.y - k), Vector2(b.x - k, b.y), Vector2(a.x + k, b.y), Vector2(a.x, b.y - k), Vector2(a.x, a.y + k)])

	func _outline(item: RID, shape: PackedVector2Array, color: Color, width: float) -> void:
		var points := shape.duplicate()
		points.append(points[0])
		RenderingServer.canvas_item_add_polyline(item, points, [color], width, true)

	func _diamond(item: RID, center: Vector2, size: float) -> void:
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([center + Vector2(0, -size), center + Vector2(size, 0),
			center + Vector2(0, size), center + Vector2(-size, 0)]), [line])


## Hauptmenü-Felsfläche und derselbe gerenderte Knopfrand; blaue Akzente für Bollwerk.
class MenuButtonFrame extends IronFrame:
	var state := "normal"
	var _rendered_frame: StyleBoxTexture

	func _shape(rect: Rect2) -> PackedVector2Array:
		return Wc3Theme.hex(rect,minf(Wc3Button.TIP,rect.size.y*.25))

	func _draw(item: RID, rect: Rect2) -> void:
		var shape := _shape(rect.grow(-2))
		var texture: Texture2D=HdUiStyle.button_face()
		var uv := PackedVector2Array()
		for point in shape:uv.append(point/180.0)
		RenderingServer.canvas_item_set_default_texture_repeat(item,RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		RenderingServer.canvas_item_add_polygon(item,shape,PackedColorArray([Color.WHITE]),uv,texture.get_rid())
		var tint := Color(.045,.14,.27,.86)
		if state in ["hover","hover_pressed"]:tint=Color(.075,.24,.40,.82)
		elif state=="pressed":tint=Color(.025,.09,.18,.9)
		elif state=="disabled":tint=Color(.08,.1,.13,.9)
		RenderingServer.canvas_item_add_polygon(item,shape,PackedColorArray([tint]))
		_outline(item,shape,Color("192638"),1)

	func draw_metal(item: RID, rect: Rect2) -> void:
		if rect.size.x<60 or rect.size.y<28:
			HdUiStyle.metal_outline(item,_shape(rect.grow(-2)),line,2.0)
			return
		if _rendered_frame==null:
			_rendered_frame=Wc3Button.frame_box().duplicate()
			_rendered_frame.modulate_color=line
		_rendered_frame.draw(item,rect)
