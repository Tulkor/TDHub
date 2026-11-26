class_name HdUiStyle
extends RefCounted
## Bollwerk: „Eisenliturgie“. Nachtblaues Leder, dunkles grob gebürstetes Messing, gefasste Edelsteine.
## Nur über UiTheme.BOLLWERK aktiv; semantische Kampf-/Elementfarben bleiben erhalten.
## Baukasten (Mockup export/editoren/bollwerk-ui-baukasten.html, Lukas 2026-11-25):
## drei Materialien (Leder, Messing, Navy-Hauptaktion), vier Formen (Achteck für Flächen und Steckplätze,
## Spitz-Sechseck für Textknöpfe, Raute für Symbolknöpfe, abgeschrägte Reiter). Messingränder 2 px,
## große Panels 3 px mit Eckbeschlägen, Steinen und Krone. Was in Ecken sitzt, ist in den Rahmen eingearbeitet.

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
## Gedämpftes Eisen für gesperrte Ränder.
const IRON := Color("6d665a")
## Steine in Panel-Eckbeschlägen und Krone.
const PANEL_GEM := Color("6fa8d8")
## Hell und kontrastreich auf Karten: Taste, Mana, Abklingzeit.
const KEY_TEXT := Color("fff3d6")
const MANA_TEXT := Color("8fd8ff")
const NO_MANA_TEXT := Color("ff8c7c")
const UPGRADE := Color("7fe08a")
const BODY := "res://assets/fonts/Federo-Regular.ttf"
const HEADING := "res://assets/fonts/Cinzel-Bold.ttf"
const DISPLAY := "res://assets/fonts/CinzelDecorative-Black.ttf"
const FALLBACK := "res://assets/fonts/DejaVuSansMono.ttf"
const LEATHER_PATH := "res://assets/textures/ui/bollwerk_leather.png"
const GEM_PLUS_SHADER := preload("res://scripts/heroes/hd_gem_plus.gdshader")
## Messing ist dunkler als die Schriftfarbe GOLD (Lukas 2026-11-25).
const METAL_DARKEN := 0.1
const RIM := 2.0
## Innenpolster aller großen Fenster, ringsum gleich (Lukas 2026-11-25: einheitliches Padding).
## Regel: Polster = Rand (3) + Abstand zu den Eckbeschlägen, mindestens die halbe Schrifthöhe der größten Zeile.
const PAD := 14.0
## Abstände zwischen Elementen: 4 eng (Zeilen einer Gruppe), 8 normal, 12 zwischen Gruppen.
const GAP := 8
## Schriftregel: ab HEAD_SIZE px und einzeilig Cinzel fett mit Metallrelief (wie Knopfschrift), sonst Federo.
const HEAD_SIZE := 13
## Anteil glatter Farbe über dem Leder: 0 = volle Struktur, 1 = keine.
const LEATHER_VEIL := 0.55
const PANEL_RIM := 3.0
static var _fonts: Dictionary = {}
static var _theme: Theme
static var _metal: ShaderMaterial
static var _text_metal: ShaderMaterial
static var _icon_metal: ShaderMaterial
static var _leather: Texture2D
static var _button_face: Texture2D
static var _brushed: Texture2D


static func leather_texture() -> Texture2D:
	if _leather==null and ResourceLoader.exists(LEATHER_PATH):_leather=load(LEATHER_PATH)
	return _leather

static func button_face() -> Texture2D:
	if _button_face==null:_button_face=load(Wc3Theme.ROCK)
	return _button_face

## Grob gebürstetes Messing als Graustufen-Relief: Längsriefen (Zeilen) mit leichtem Wellengang,
## feines Korn, helle Außenfase und dunklere Innenkante. In u nahtlos wiederholbar.
## Das Metallmaterial (palette_metal) färbt es mit dem Randton ein.
static func brushed_texture() -> Texture2D:
	if _brushed != null:
		return _brushed
	var w := 256
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var rows: Array[float] = []
	var phase: Array[float] = []
	for y in h:
		rows.append(rng.randf_range(-1.0, 1.0))
		phase.append(rng.randf())
	for y in h:
		var across := float(y) / float(h - 1)
		var bevel := 1.0 + 0.24 * (1.0 - smoothstep(0.0, 0.3, across)) - 0.22 * smoothstep(0.6, 1.0, across)
		for x in w:
			var wave := sin(TAU * (float(x) / float(w) * 3.0 + phase[y])) * 0.035
			var streak := rows[y] * 0.085 + wave
			var grain := rng.randf_range(-1.0, 1.0) * 0.03
			var v := clampf(0.56 * bevel + streak + grain, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_brushed = ImageTexture.create_from_image(img)
	return _brushed

## Randton: das Messing ist eine Spur dunkler als die eingestellte Linienfarbe.
static func metal_tone(color: Color) -> Color:
	return Color(color.darkened(METAL_DARKEN), color.a)

static func leather_fill(item: RID, shape: PackedVector2Array, color: Color) -> bool:
	var texture := leather_texture()
	if texture==null or color.b<=color.r or color.v>.3:return false
	var uv := PackedVector2Array()
	for point in shape:uv.append(point/256.0)
	RenderingServer.canvas_item_set_default_texture_repeat(item,RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var tint := Color(color.r/COLORS.PANEL.r,color.g/COLORS.PANEL.g,color.b/COLORS.PANEL.b,color.a)
	RenderingServer.canvas_item_add_polygon(item,shape,PackedColorArray([tint]),uv,texture.get_rid())
	# Leder nur angedeutet (Lukas 2026-11-25): glatte Fläche in derselben Farbe darüber.
	RenderingServer.canvas_item_add_polygon(item,shape,PackedColorArray([Color(color,LEATHER_VEIL)]))
	return true

## Weicher Verlauf von der Mitte nach außen (Fächer über die Kontur): Tönung, Vignette, Innenlicht.
static func radial(item: RID, shape: PackedVector2Array, inner: Color, outer: Color) -> void:
	var center := Vector2.ZERO
	for p in shape:center += p
	center /= float(shape.size())
	for i in shape.size():
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([center, shape[i], shape[(i + 1) % shape.size()]]),
			PackedColorArray([inner, outer, outer]))

static func menu_button_style(state: String, pad := 10.0) -> MenuButtonFrame:
	var style := MenuButtonFrame.new()
	style.state=state
	style.line=GOLD_HI if state in ["hover","hover_pressed","focus"] else GOLD
	if state=="disabled":style.line=IRON
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


## Kantenglättung (Lukas 2026-11-25): Polygone haben harte Treppenkanten, deshalb ziehen alle Zeichenhelfer
## eine geglättete 1-px-Linie über ihre Außenkanten. Ungetextete Linien werden vom Metallshader heller gerechnet
## (Relief 1,6 statt ~1,25 bei der Bürsttextur), METAL_EDGE gleicht das aus.
const METAL_EDGE := 0.55

static func aa_loop(item: RID, shape: PackedVector2Array, color: Color, width := 1.0) -> void:
	if shape.size() < 2:
		return
	var points := shape.duplicate()
	points.append(shape[0])
	RenderingServer.canvas_item_add_polyline(item, points, PackedColorArray([color]), width, true)

static func _edge_tone(color: Color) -> Color:
	return Color(color.r * METAL_EDGE, color.g * METAL_EDGE, color.b * METAL_EDGE, color.a * 0.6)

## Gebürstete Messingleiste entlang einer geschlossenen Kontur; u läuft entlang der Kante, v quer dazu.
static func metal_outline(item: RID, shape: PackedVector2Array, color: Color, width: float) -> void:
	var texture := brushed_texture()
	RenderingServer.canvas_item_set_default_texture_repeat(item,RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var along := 0.0
	for i in shape.size():
		var a := shape[i]
		var b := shape[(i+1)%shape.size()]
		var length := a.distance_to(b)
		if length <= 0.01:continue
		var normal := (b-a).normalized().orthogonal()*width*.5
		var u0 := along/96.0
		var u1 := (along+length)/96.0
		RenderingServer.canvas_item_add_polygon(item,PackedVector2Array([a+normal,b+normal,b-normal,a-normal]),PackedColorArray([color]),
			PackedVector2Array([Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,1)]),texture.get_rid())
		along += length
	# geglättete Außen- und Innenkante
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := shape.size()
	for i in n:
		var prev := shape[(i - 1 + n) % n]
		var here := shape[i]
		var next := shape[(i + 1) % n]
		var n1 := (here - prev).normalized().orthogonal()
		var n2 := (next - here).normalized().orthogonal()
		var miter := (n1 + n2).normalized()
		var scale := width * 0.5 / maxf(0.35, miter.dot(n1))
		outer.append(here + miter * scale)
		inner.append(here - miter * scale)
	aa_loop(item, outer, _edge_tone(color), 0.5)
	aa_loop(item, inner, _edge_tone(color.darkened(0.3)), 0.5)

## Offene Messingleiste (z. B. Reiter ohne Unterkante).
static func metal_polyline(item: RID, points: PackedVector2Array, color: Color, width: float) -> void:
	var texture := brushed_texture()
	RenderingServer.canvas_item_set_default_texture_repeat(item,RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var along := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if length <= 0.01:continue
		var normal := (b-a).normalized().orthogonal()*width*.5
		RenderingServer.canvas_item_add_polygon(item,PackedVector2Array([a+normal,b+normal,b-normal,a-normal]),PackedColorArray([color]),
			PackedVector2Array([Vector2(along/96.0,0),Vector2((along+length)/96.0,0),Vector2((along+length)/96.0,1),Vector2(along/96.0,1)]),texture.get_rid())
		along += length

## Reiter (Shop): oben abgeschrägt, unten offen; der aktive ist höher, heller und hat Goldschrift.
static func tab_style(on: bool) -> TabFrame:
	var s := TabFrame.new()
	s.active = on
	s.line = GOLD if on else IRON
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 9 if on else 6
	s.content_margin_bottom = 6
	return s

## Balken (Leben, Mana, Welle, Boss): eingelassene Rinne mit spitzen Enden und Messingfassung.
static func bar_styles(bar: ProgressBar, fill_color: Color) -> void:
	var bg := BarFrame.new()
	bg.fill = Color(0.012, 0.024, 0.05)
	bg.line = GOLD
	var fg := BarFrame.new()
	fg.fill = fill_color
	fg.line = Color.TRANSPARENT
	fg.is_fill = true
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

## Gefüllte Messingfläche (Beschläge, Eckplatten, Krone) mit gebürsteter Struktur.
static func metal_plate(item: RID, shape: PackedVector2Array, color: Color, scale := 40.0) -> void:
	var texture := brushed_texture()
	RenderingServer.canvas_item_set_default_texture_repeat(item,RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var uv := PackedVector2Array()
	for p in shape:uv.append(Vector2(p.x/scale*0.4, p.y/scale))
	RenderingServer.canvas_item_add_polygon(item,shape,PackedColorArray([color]),uv,texture.get_rid())
	aa_loop(item, shape, _edge_tone(color))

## Geschliffener Stein in einer Messingfassung (Raute mit vier Facetten und Glanzpunkt). Ohne Metallshader zeichnen.
static func gem(item: RID, center: Vector2, half: float, color: Color) -> void:
	var ring := func(r: float) -> PackedVector2Array:
		return PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
	RenderingServer.canvas_item_add_polygon(item, ring.call(half + 2.6), PackedColorArray([Color(0.14, 0.09, 0.04, 0.95)]))
	aa_loop(item, ring.call(half + 2.6), Color(0.14, 0.09, 0.04, 0.95))
	RenderingServer.canvas_item_add_polygon(item, ring.call(half + 1.7), PackedColorArray([Color("d9bb80")]))
	RenderingServer.canvas_item_add_polygon(item, ring.call(half + 0.7), PackedColorArray([Color(0.14, 0.09, 0.04, 1.0)]))
	var p: PackedVector2Array = ring.call(half)
	var shades := [color.lerp(Color.WHITE, 0.45), color, color.darkened(0.45), color.darkened(0.2)]
	for i in 4:
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([center, p[i], p[(i + 1) % 4]]), PackedColorArray([shades[i]]))
	RenderingServer.canvas_item_add_circle(item, center + Vector2(-half * 0.28, -half * 0.3), maxf(0.8, half * 0.22), Color(1, 1, 1, 0.85))

## Messingniete statt Stein (gewöhnliche Items).
static func rivet(item: RID, center: Vector2, radius: float, color: Color) -> void:
	RenderingServer.canvas_item_add_circle(item, center, radius + 1.0, Color(0.14, 0.09, 0.04, 0.9))
	RenderingServer.canvas_item_add_circle(item, center, radius, color.darkened(0.25))
	RenderingServer.canvas_item_add_circle(item, center + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.5, color.lerp(Color.WHITE, 0.4))

## Gemalter Messing-Eckbeschlag (L entlang der Abschrägung) für eine Ecke; flip spiegelt auf die anderen Ecken.
static func _corner_points(rect: Rect2, corner: int, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector2 = p
		if corner == 1 or corner == 3:q.x = rect.size.x - q.x
		if corner == 2 or corner == 3:q.y = rect.size.y - q.y
		out.append(rect.position + q)
	return out

static func panel_fittings(item: RID, rect: Rect2, cut: float, color: Color) -> void:
	var t := 6.0
	var arm := clampf(minf(rect.size.x, rect.size.y) * 0.3, cut + t + 4.0, 34.0)
	var d := t * 1.4142
	for corner in 4:
		var pts := [Vector2(0, cut), Vector2(cut, 0), Vector2(arm, 0), Vector2(arm, t * 0.6), Vector2(arm - 3, t),
			Vector2(cut + d - t, t), Vector2(t, cut + d - t), Vector2(t, arm - 3), Vector2(t * 0.6, arm), Vector2(0, arm)]
		metal_plate(item, _corner_points(rect, corner, pts), color)
	if rect.size.x >= 200.0:
		var cx := rect.position.x + rect.size.x * 0.5
		var top := rect.position.y
		metal_plate(item, PackedVector2Array([Vector2(cx - 28, top), Vector2(cx + 28, top), Vector2(cx + 18, top + 9), Vector2(cx - 18, top + 9)]), color)

static func panel_gems(item: RID, rect: Rect2, cut: float) -> void:
	var c := cut * 0.5 + 6.0 * 0.354
	for corner in 4:
		gem(item, _corner_points(rect, corner, [Vector2(c, c)])[0], 3.6, PANEL_GEM)
	if rect.size.x >= 200.0:
		gem(item, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 3.5), 3.2, PANEL_GEM)


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
	s.content_margin_top = pad * 0.65
	s.content_margin_bottom = pad * 0.65
	if ornate:
		# Große Fenster: ringsum dasselbe Polster, Inhalt dadurch waagrecht und senkrecht mittig.
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			s.set_content_margin(side, PAD)
	return s


## Eine Schriftart je Größe (Lukas 2026-11-25): einzeilige Texte ab HEAD_SIZE in Cinzel fett mit demselben
## Metallrelief wie die Knopfschrift, neutrale Farben werden Gold, Signalfarben (Leben, Gold, Holz, Warnung) bleiben.
## Kleinere oder umbrechende Texte in Federo mit weichem Schatten. Freistehende Texte mit Kontur (card_text) bleiben.
static func normalize_label(label: Label) -> void:
	if label.has_theme_constant_override("outline_size") or label.has_meta("keep_font"):
		return
	var size := label.get_theme_font_size("font_size")
	# Überschriften ab 15 px bleiben Überschriften, auch wenn sie umbrechen; 13–14 px nur einzeilig.
	var heading := size >= 15 or (size >= HEAD_SIZE and label.autowrap_mode == TextServer.AUTOWRAP_OFF)
	if heading:
		label.add_theme_font_override("font", _font(DISPLAY) if size >= 24 else font(true))
		label.material = text_metal_material()
		label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		var c := label.get_theme_color("font_color")
		for neutral in [COLORS.TEXT, COLORS.MUTED, COLORS.DIM, GOLD_HI]:
			if c.is_equal_approx(neutral):
				label.add_theme_color_override("font_color", GOLD)
	else:
		label.add_theme_font_override("font", font(false))
		label.material = null


static func panel(pad := 14.0, _alpha := 0.95, border := Color.TRANSPARENT) -> StyleBox:
	return frame(COLORS.PANEL, GOLD if border.a == 0.0 else border, pad + 3.0, 10.0, true)


## Fähigkeitskarte: eingetieftes Leder, Achteck; gewählt = helleres Messing und warmes Innenlicht.
static func skill_frame(active := false, blocked := false) -> StyleBox:
	var s := frame(INK, GOLD_HI if active else (IRON if blocked else GOLD), 2.0, 9.0)
	s.deep = true
	s.glow = active
	return s


## Steckplatz (Inventar, Lager, Verkaufen): Achteck mit Messing-Eckplatten, Stein in Seltenheitsfarbe.
static func slot_frame(slot: InvSlot) -> SlotFrame:
	var s := SlotFrame.new()
	var tier: Color = slot.border
	s.line = GOLD
	if slot.state != InvSlot.State.ITEM:
		s.line = IRON
	if slot._drop_hover:
		s.line = Color("9fd9ff")
	elif slot._hover and slot.state == InvSlot.State.ITEM:
		s.line = GOLD_HI
	s.jewel = tier if slot.state == InvSlot.State.ITEM else Color.TRANSPARENT
	return s


## Bollwerk-Steckplatz zeichnen (aufgerufen aus InvSlot._draw): getöntes, eingetieftes Leder und großes Bild.
## Rand, Eckplatten und Steine kommen aus der Metalllage (SlotFrame).
static func draw_slot(slot: InvSlot) -> void:
	var item := slot.get_canvas_item()
	var rect := Rect2(Vector2.ZERO, slot.size)
	var shape := SlotFrame.octagon(rect.grow(-1.0), 8.0)
	if not leather_fill(item, shape, INK):
		RenderingServer.canvas_item_add_polygon(item, shape, PackedColorArray([INK]))
	if slot.state == InvSlot.State.LOCKED:
		radial(item, shape, Color(0.35, 0.35, 0.35, 0.35), Color(0.2, 0.2, 0.2, 0.5))
		return
	if slot.state == InvSlot.State.ITEM and slot.border.a > 0.0:
		var tint: Color = slot.border
		radial(item, shape, Color(tint, 0.42 if slot.marked else 0.3), Color(tint, 0.0))
	radial(item, shape, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55))
	if slot.state != InvSlot.State.ITEM:
		var c := rect.get_center()
		var r := 6.0
		RenderingServer.canvas_item_add_polyline(item, PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)]),
			PackedColorArray([Color(GOLD, 0.2)]), 1.0, true)
		return
	if slot.texture != null:
		var m := slot.size.x * 0.03
		slot.draw_texture_rect(slot.texture, Rect2(m, m, slot.size.x - 2 * m, slot.size.y - 2 * m), false, Color(1, 1, 1, 0.45 if slot.dimmed else 1.0))
	elif slot.abbr != "":
		var f := font(true)
		var fs := int(slot.size.y * 0.38)
		var w := f.get_string_size(slot.abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		slot.draw_string(f, Vector2((slot.size.x - w) / 2.0, slot.size.y / 2.0 + fs * 0.36), slot.abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, KEY_TEXT)
	if slot.consumable:
		var c := Vector2(slot.size.x * 0.5, 7.0)
		slot.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3, 1), c + Vector2(0, 4), c + Vector2(-3, 1)]), COLORS.HAVE)
	if slot.count != "":
		var f := font(true)
		var fs := 12
		var w := f.get_string_size(slot.count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(slot.size.x - w - 15.0, slot.size.y - 3.0)
		slot.draw_string_outline(f, p, slot.count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.01, 0.02, 0.04))
		slot.draw_string(f, p, slot.count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD_HI)


## Aufwertung über der Fähigkeitskarte: flache Sechseck-Plakette mit dünnem Rand, darin ein schimmerndes Edelstein-Plus.
static func upgrade_button(button: Button) -> void:
	button.text = ""
	button.custom_minimum_size = Vector2(44, 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := UpgradePlate.new()
		s.line = GOLD_HI if state == "hover" else (IRON if state == "disabled" else GOLD)
		s.state = state
		button.add_theme_stylebox_override(state, s)
	if not button.has_node("GemPlus"):
		var plus := ColorRect.new()
		plus.name = "GemPlus"
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = GEM_PLUS_SHADER
		plus.material = mat
		plus.custom_minimum_size = Vector2(15, 15)
		plus.size = Vector2(15, 15)
		button.add_child(plus)
		plus.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		plus.offset_left = -7.5
		plus.offset_top = -7.5
		plus.offset_right = 7.5
		plus.offset_bottom = 7.5


## Symbolknopf (Schließen, Zoom): Raute mit gezeichnetem, exakt mittigem Zeichen statt Schrift.
## glyph: "x", "plus" oder "minus".
static func symbol_button(button: Button, glyph: String) -> void:
	button.text = ""
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := SymbolFrame.new()
		s.glyph = glyph
		s.state = state
		s.line = GOLD_HI if state == "hover" else (IRON if state == "disabled" else GOLD)
		if state == "focus":
			s.line = Color.TRANSPARENT
		button.add_theme_stylebox_override(state, s)


static func accent_button(button: Button, bg: Color, fg: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := menu_button_style(state,12.0)
		s.primary = true
		if state != "disabled":
			s.line = GOLD_HI
		button.add_theme_stylebox_override(state, s)
	button.add_theme_font_override("font", font(true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, GOLD_HI)
	button.set_meta("bollwerk_primary", true)


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


## Kontrastreiche Schrift direkt auf der Karte (Taste, Mana, Abklingzeit): fett, dunkle Kontur, dunkler Schein.
static func card_text(label: Label, color: Color, size := 14) -> Label:
	label.add_theme_font_override("font", font(true))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_outline_size", 9)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 15
	for control in ["Label", "Button", "CheckBox", "CheckButton", "OptionButton", "RichTextLabel", "TooltipLabel"]:
		t.set_color("font_color", control, COLORS.TEXT)
	# Schrift auf Leder: weicher dunkler Schatten, damit sie nicht in der Struktur verschwimmt.
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("shadow_outline_size", "Label", 2)
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
	t.set_stylebox("panel", "PopupMenu", frame(INK, GOLD, 9.0, 8.0, true))
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


## Skalierbare Grundkontur. Die Fläche zeichnet die StyleBox selbst (Leder), Messing und Steine kommen aus
## HdUiMetal: draw_metal auf der Metalllage (mit Shader), draw_jewels auf einer Lage ohne Shader darüber.
class IronFrame extends StyleBox:
	var fill := Color.TRANSPARENT
	var line := GOLD
	var cut := 8.0
	var ornate := false
	var diamond := false
	var deep := false   ## eingetieft (Karten, Steckplätze): dunkler Rand nach innen
	var glow := false   ## warmes Innenlicht (gewählte Fähigkeit)

	func _rim(rect: Rect2) -> float:
		return minf(HdUiStyle.PANEL_RIM if ornate else HdUiStyle.RIM, minf(rect.size.x, rect.size.y) * 0.16)

	func _fittings(rect: Rect2) -> bool:
		# Alle Fenster tragen die Beschläge mit Steinen (Lukas 2026-11-25), nur winzige Rahmen nicht.
		return ornate and rect.size.x >= 60.0 and rect.size.y >= 34.0

	func draw_metal(item: RID, rect: Rect2) -> void:
		if line.a<=0 or rect.size.x<=0 or rect.size.y<=0:return
		var w := _rim(rect)
		HdUiStyle.metal_outline(item,_shape(rect.grow(-w*.5)),HdUiStyle.metal_tone(line),w)
		if _fittings(rect):
			HdUiStyle.panel_fittings(item, rect, _cut(rect), HdUiStyle.metal_tone(line))

	func draw_jewels(item: RID, rect: Rect2) -> void:
		if line.a > 0 and _fittings(rect):
			HdUiStyle.panel_gems(item, rect, _cut(rect))

	func _draw(item: RID, rect: Rect2) -> void:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var shape := _shape(rect.grow(-1.0))
		if fill.a > 0.0:
			if not HdUiStyle.leather_fill(item,shape,fill):RenderingServer.canvas_item_add_polygon(item, shape, [fill])
			if deep:
				HdUiStyle.radial(item, shape, Color(0, 0, 0, 0), Color(0, 0, 0, 0.55))
			if glow:
				HdUiStyle.radial(item, shape, Color(0.96, 0.8, 0.53, 0.24), Color(0.96, 0.8, 0.53, 0.0))
		if line.a > 0.0:
			_outline(item, shape, Color(HdUiStyle.metal_tone(line), line.a * 0.6), 1.0)

	func _cut(rect: Rect2) -> float:
		return minf(cut, minf(rect.size.x, rect.size.y) * 0.22)

	func _shape(rect: Rect2) -> PackedVector2Array:
		var a := rect.position
		var b := rect.end
		if diamond:
			var center := rect.get_center()
			var half := minf(rect.size.x, rect.size.y) * 0.5
			return PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)])
		var k := _cut(rect)
		return PackedVector2Array([Vector2(a.x + k, a.y), Vector2(b.x - k, a.y), Vector2(b.x, a.y + k),
			Vector2(b.x, b.y - k), Vector2(b.x - k, b.y), Vector2(a.x + k, b.y), Vector2(a.x, b.y - k), Vector2(a.x, a.y + k)])

	func _outline(item: RID, shape: PackedVector2Array, color: Color, width: float) -> void:
		var points := shape.duplicate()
		points.append(points[0])
		RenderingServer.canvas_item_add_polyline(item, points, [color], width, true)


## Textknopf: Spitz-Sechseck, Fläche aus dem Leder der Panels (Variante A). Hauptaktion (primary): Navy der
## Fenster, helleres Messing und warmes Innenlicht statt eigener Farbe.
class MenuButtonFrame extends IronFrame:
	var state := "normal"
	var primary := false

	func _shape(rect: Rect2) -> PackedVector2Array:
		# Schmale Knöpfe: Spitzen dürfen sich nicht überkreuzen, sonst scheitert die Triangulierung.
		return Wc3Theme.hex(rect,minf(Wc3Button.TIP,minf(rect.size.y*.25,rect.size.x*.4)))

	func _draw(item: RID, rect: Rect2) -> void:
		var shape := _shape(rect.grow(-1))
		var base := Color("0e2546") if primary else HdUiStyle.COLORS.PANEL
		if not HdUiStyle.leather_fill(item,shape,base):RenderingServer.canvas_item_add_polygon(item,shape,PackedColorArray([base]))
		var top := Color(1, 0.93, 0.75, 0.07)
		var bottom := Color(0, 0, 0, 0.3)
		if state in ["hover","hover_pressed"]:
			HdUiStyle.radial(item,shape,Color(0.94,0.78,0.51,0.2),Color(0.94,0.78,0.51,0.0))
		elif state=="pressed":
			top = Color(0, 0, 0, 0.35)
		elif state=="disabled":
			bottom = Color(0.05, 0.05, 0.05, 0.55)
			top = Color(0.05, 0.05, 0.05, 0.4)
		if primary and state != "disabled":
			HdUiStyle.radial(item,shape,Color(0.94,0.78,0.51,0.14),Color(0.94,0.78,0.51,0.0))
		var mid := rect.get_center().y
		var shade := PackedColorArray()
		for p in shape:
			shade.append(top if p.y < mid else bottom)
		RenderingServer.canvas_item_add_polygon(item, shape, shade)

	func draw_metal(item: RID, rect: Rect2) -> void:
		if line.a<=0:return
		var w := HdUiStyle.RIM
		HdUiStyle.metal_outline(item,_shape(rect.grow(-w*.5)),HdUiStyle.metal_tone(line),w)


## Steckplatz: Achteck, Messing-Eckplatten mit dunkler Fuge, darin ein gefasster Stein (oder eine Niete).
class SlotFrame extends IronFrame:
	var jewel := Color.TRANSPARENT
	const PLATE := 21.0

	static func octagon(rect: Rect2, k: float) -> PackedVector2Array:
		var a := rect.position
		var b := rect.end
		return PackedVector2Array([Vector2(a.x + k, a.y), Vector2(b.x - k, a.y), Vector2(b.x, a.y + k),
			Vector2(b.x, b.y - k), Vector2(b.x - k, b.y), Vector2(a.x + k, b.y), Vector2(a.x, b.y - k), Vector2(a.x, a.y + k)])

	func _plate(rect: Rect2) -> float:
		return minf(PLATE, minf(rect.size.x, rect.size.y) * 0.36)

	func draw_metal(item: RID, rect: Rect2) -> void:
		var tone := HdUiStyle.metal_tone(line)
		HdUiStyle.metal_outline(item, octagon(rect.grow(-1.0), 8.0), tone, HdUiStyle.RIM)
		var p := _plate(rect)
		for corner in 4:
			var pts := [Vector2(0, 8), Vector2(8, 0), Vector2(p, 0), Vector2(0, p)]
			HdUiStyle.metal_plate(item, HdUiStyle._corner_points(rect, corner, pts), tone, 30.0)
			var seam := HdUiStyle._corner_points(rect, corner, [Vector2(p, 0), Vector2(0, p)])
			RenderingServer.canvas_item_add_line(item, seam[0], seam[1], Color(0.12, 0.07, 0.02, 0.95), 1.2, true)

	func draw_jewels(item: RID, rect: Rect2) -> void:
		if jewel.a <= 0.0:
			return
		if jewel.s < 0.12:
			return  # gewöhnliche Items: nur die Eckplatten, kein Stein
		for corner in 4:
			HdUiStyle.gem(item, HdUiStyle._corner_points(rect, corner, [Vector2(7, 7)])[0], 3.8, jewel)


## Raute für Symbolknöpfe; das Zeichen (x, plus, minus) wird als Linien exakt mittig gezeichnet.
class SymbolFrame extends IronFrame:
	var glyph := "x"
	var state := "normal"

	func _init() -> void:
		diamond = true

	func _draw(item: RID, rect: Rect2) -> void:
		var shape := _shape(rect.grow(-1.0))
		if not HdUiStyle.leather_fill(item, shape, HdUiStyle.COLORS.PANEL):
			RenderingServer.canvas_item_add_polygon(item, shape, PackedColorArray([HdUiStyle.COLORS.PANEL]))
		if state == "hover":
			HdUiStyle.radial(item, shape, Color(0.94, 0.78, 0.51, 0.22), Color(0.94, 0.78, 0.51, 0.0))
		var c := rect.get_center()
		var r := minf(rect.size.x, rect.size.y) * 0.2
		var color := HdUiStyle.GOLD_HI if state == "hover" else (HdUiStyle.IRON if state == "disabled" else HdUiStyle.GOLD)
		var lines: Array = []
		match glyph:
			"x":lines = [[c + Vector2(-r, -r) * 0.78, c + Vector2(r, r) * 0.78], [c + Vector2(-r, r) * 0.78, c + Vector2(r, -r) * 0.78]]
			"plus":lines = [[c + Vector2(-r, 0), c + Vector2(r, 0)], [c + Vector2(0, -r), c + Vector2(0, r)]]
			_:lines = [[c + Vector2(-r, 0), c + Vector2(r, 0)]]
		for l in lines:
			RenderingServer.canvas_item_add_line(item, l[0] + Vector2(0, 1), l[1] + Vector2(0, 1), Color(0, 0, 0, 0.8), 2.4, true)
		for l in lines:
			RenderingServer.canvas_item_add_line(item, l[0], l[1], color, 2.2, true)

	func draw_metal(item: RID, rect: Rect2) -> void:
		if line.a <= 0:return
		var w := 2.5
		HdUiStyle.metal_outline(item, _shape(rect.grow(-w * 0.7)), HdUiStyle.metal_tone(line), w)


## Aufwertungs-Plakette: flaches Sechseck, dünner Rand (1,5 px), Leder; das Plus ist ein eigener Shader-Knoten.
class UpgradePlate extends IronFrame:
	var state := "normal"

	func _shape(rect: Rect2) -> PackedVector2Array:
		return Wc3Theme.hex(rect, minf(9.0, rect.size.x * 0.25))

	func _draw(item: RID, rect: Rect2) -> void:
		var shape := _shape(rect.grow(-0.5))
		var base := Color("07101c")
		if not HdUiStyle.leather_fill(item, shape, base):
			RenderingServer.canvas_item_add_polygon(item, shape, PackedColorArray([base]))
		var light := 0.26 if state == "hover" else (0.0 if state == "disabled" else 0.14)
		if light > 0.0:
			HdUiStyle.radial(item, shape, Color(0.5, 0.9, 0.55, light), Color(0.5, 0.9, 0.55, 0.0))

	func draw_metal(item: RID, rect: Rect2) -> void:
		HdUiStyle.metal_outline(item, _shape(rect.grow(-0.75)), HdUiStyle.metal_tone(line), 1.5)


## Reiter: oben abgeschrägt, unten offen.
class TabFrame extends IronFrame:
	var active := false

	func _shape(rect: Rect2) -> PackedVector2Array:
		var k := minf(7.0, rect.size.y * 0.3)
		var a := rect.position
		var b := rect.end
		return PackedVector2Array([Vector2(a.x, b.y), Vector2(a.x, a.y + k), Vector2(a.x + k, a.y), Vector2(b.x - k, a.y), Vector2(b.x, a.y + k), Vector2(b.x, b.y)])

	func _draw(item: RID, rect: Rect2) -> void:
		var shape := _shape(rect.grow(-1.0))
		var base := HdUiStyle.COLORS.PANEL if active else HdUiStyle.INK
		if not HdUiStyle.leather_fill(item, shape, base):
			RenderingServer.canvas_item_add_polygon(item, shape, PackedColorArray([base]))
		if not active:
			RenderingServer.canvas_item_add_polygon(item, shape, PackedColorArray([Color(0, 0, 0, 0.3)]))

	func draw_metal(item: RID, rect: Rect2) -> void:
		var w := HdUiStyle.RIM
		HdUiStyle.metal_polyline(item, _shape(rect.grow(-w * 0.5)), HdUiStyle.metal_tone(line), w)


## Balkenrinne und -füllung: Sechseck mit kurzen Spitzen; die Füllung hat eine helle Oberkante.
class BarFrame extends IronFrame:
	var is_fill := false

	func _shape(rect: Rect2) -> PackedVector2Array:
		return Wc3Theme.hex(rect, minf(6.0, minf(rect.size.y * 0.5, rect.size.x * 0.3)))

	func _draw(item: RID, rect: Rect2) -> void:
		if rect.size.x <= 1.0 or rect.size.y <= 0.0:
			return
		var shape := _shape(rect.grow(-1.0) if not is_fill else rect.grow(-2.0))
		if shape.size() < 3:
			return
		var mid := rect.get_center().y
		var colors := PackedColorArray()
		for p in shape:
			colors.append(fill.lightened(0.25) if p.y < mid - 0.5 else (fill.darkened(0.25) if p.y > mid + 0.5 else fill))
		RenderingServer.canvas_item_add_polygon(item, shape, colors)
		HdUiStyle.aa_loop(item, shape, fill)
		if not is_fill:
			HdUiStyle.radial(item, shape, Color(0, 0, 0, 0), Color(0, 0, 0, 0.6))

	func draw_metal(item: RID, rect: Rect2) -> void:
		if is_fill or line.a <= 0:
			return
		var w := minf(1.5, rect.size.y * 0.2)
		HdUiStyle.metal_outline(item, _shape(rect.grow(-w * 0.5)), HdUiStyle.metal_tone(line), w)
