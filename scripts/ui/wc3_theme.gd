class_name Wc3Theme
extends RefCounted
## Hauptmenü (Hub) im Warcraft-III-Stil (Lukas, 2026-10-30, Mockup v10 unter /mnt/project-files/mockups/wc3-menu/):
## Steinsäule mit doppeltem Messingrahmen und verschraubten Eckbeschlägen, spitze Knöpfe mit Stein- bzw.
## Felstextur, Cinzel als Schrift. Messington wie die Linien in Shopping Maul, kaum Farbverlauf.
## Seit 2026-11 auch die Einzelspieler-Seite (Modus und Map wählen); Lobby, Laden usw. bleiben Art déco (DecoTheme).

const GOLD := Color("c9a36a")
const GOLD_HI := Color("d8b97f")
const GOLD_LO := Color("7d6440")
## Dunkle Kontur um alles aus Messing.
const INK := Color("140c04")
const SCREW := Color("8f7440")
## Grün für „verbunden“ unten links.
const HAVE := Color("9fd3b6")
const TEXT := Color("d8b97f")
## Schrift beim Überfahren und Hotkey-Buchstabe.
const HOT := Color("f6ead2")
const CREAM := Color("e6d3a3")
const MODES := Color("cdb886")
const MUTED := Color("a69676")
## Flächen der Knöpfe über der Textur: rot = Hauptknopf, dunkel = kleiner Knopf.
const RED := Color(0.42, 0.086, 0.055, 0.8)
const RED_HOVER := Color(0.63, 0.157, 0.07, 0.8)
const DARK := Color(0.133, 0.118, 0.102, 0.72)
const DARK_HOVER := Color(0.25, 0.2, 0.16, 0.72)
## Map-Karte (Einzelspieler) über der Steintextur und Grund der Map-Vorschau.
const CARD := Color(0.09, 0.08, 0.07, 0.78)
const PREVIEW_BG := Color("15110c")
## Gesperrter Knopf: grauer Stein, graue Schrift.
const DISABLED := Color(0.16, 0.16, 0.16, 0.85)
const DISABLED_TEXT := Color("77736b")
## Abdunklung der Steinsäule.
const PILLAR_SHADE := Color(0.07, 0.055, 0.047, 0.66)

## Messingteile als 3D-Renders aus Blender (tools/menu/messing_blender.py), metallisch spiegelnd.
const BRASS_DIR := "res://assets/textures/menu/messing/"
## Glanz, der langsam über alles Messing läuft (Material für Wc3Theme.BrassLayer).
const GLOSS := preload("res://scripts/ui/wc3_glanz.gdshader")
const STONE := "res://assets/models/scenery/church_Stone.png"
const ROCK := "res://assets/models/scenery/mine_rocks_1_rock1.png"
const FONT := "res://assets/fonts/Cinzel-Bold.ttf"

static var _fonts: Dictionary = {}
static var _tex: Dictionary = {}


## Messing-Render aus BRASS_DIR (ecke, schraube, kante_h, kante_v, raute, rubin, knopf_rahmen).
static func brass(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(BRASS_DIR + name + ".png")
	return _tex[name]


## Glanz-Material für Messing; ein gemeinsames, damit der Lichtstreif über alle Teile gleich läuft.
static var _gloss_mat: ShaderMaterial
static func gloss_material() -> ShaderMaterial:
	if _gloss_mat == null:
		_gloss_mat = ShaderMaterial.new()
		_gloss_mat.shader = GLOSS
	return _gloss_mat


## Cinzel Bold mit Buchstabenabstand; Zeichen, die Cinzel nicht hat (◆, ·), kommen aus Federo bzw. DejaVu.
static func font(spacing := 0) -> Font:
	if _fonts.has(spacing):
		return _fonts[spacing]
	var base: FontFile = load(FONT)
	if base.fallbacks.is_empty():
		base.fallbacks = [load(DecoTheme.FONT), load(DecoTheme.FONT_FALLBACK)]
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = spacing
	_fonts[spacing] = f
	return f


## Schrift über dem 3D-Hintergrund: harter dunkler Schatten nach unten plus weicher dunkler Rand, damit sie
## auch über hellen Stellen (Mond, Kristall) lesbar bleibt.
static func label(text: String, parent: Node, size: int, color: Color, spacing := 0) -> Label:
	var l := UiUtil.label(text, parent, size)
	l.add_theme_font_override("font", font(spacing))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


## Spitzes Sechseck in r (Spitzen links und rechts, tip = Länge der Spitze).
static func hex(r: Rect2, tip: float) -> PackedVector2Array:
	var y := r.position.y + r.size.y / 2
	return PackedVector2Array([Vector2(r.position.x + tip, r.position.y), Vector2(r.end.x - tip, r.position.y),
		Vector2(r.end.x, y), Vector2(r.end.x - tip, r.end.y), Vector2(r.position.x + tip, r.end.y), Vector2(r.position.x, y)])


## Achteck mit abgeschnittenen Ecken (Säule).
static func cut_rect(r: Rect2, cut: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([Vector2(a.x, a.y + cut), Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
		Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut)])


## Fläche mit Kacheltextur füllen (tile = Kachelgröße in Pixeln); der CanvasItem braucht texture_repeat.
static func fill_textured(ci: CanvasItem, pts: PackedVector2Array, tex: Texture2D, tile: float, tint: Color) -> void:
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(p / tile)
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)
	ci.draw_colored_polygon(pts, tint)


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## Schatten des Messings: das Licht der Renders kommt von links oben, also fällt der Schatten nach rechts unten,
## weich aus drei versetzten Lagen (Lukas 2026-11-02: Schatten passend zum 3D).
const SHADOW_STEPS := [Vector2(1.5, 2.0), Vector2(2.5, 3.5), Vector2(3.5, 5.0)]
const SHADOW := Color(0, 0, 0, 0.22)


## Messingschraube (3D-Render), d = Durchmesser.
static func screw(ci: CanvasItem, pos: Vector2, angle: float, d := 14.0) -> void:
	for o in SHADOW_STEPS:
		ci.draw_set_transform(pos + o * d / 20.0, angle)
		ci.draw_texture_rect(brass("schraube"), Rect2(-d / 2, -d / 2, d, d), false, SHADOW)
	ci.draw_set_transform(pos, angle)
	ci.draw_texture_rect(brass("schraube"), Rect2(-d / 2, -d / 2, d, d), false)
	ci.draw_set_transform(Vector2.ZERO)


## Ecke des Rahmens (3D-Render, 84 × 84, Ursprung = Ecke, x zeigt nach innen entlang der ersten Kante): Band mit
## Wulst um die abgeschrägte Ecke, angeschweißtes Knotenblech mit zwei Schrauben. Gleiches Profil wie edge(), damit
## die Ecke wie verschweißt wirkt (Lukas 2026-11-02). shadow false: Schatten zeichnet panel_frame() vorher.
static func corner(ci: CanvasItem, origin: Vector2, x: Vector2, _y: Vector2, shadow := true) -> void:
	if shadow:
		# Schatten in Bildschirmrichtung (nicht mitgedreht), damit er bei allen vier Ecken gleich fällt
		for o in SHADOW_STEPS:
			ci.draw_set_transform(origin + o, x.angle())
			ci.draw_texture_rect(brass("ecke"), Rect2(-2, -2, 84, 84), false, SHADOW)
	ci.draw_set_transform(origin, x.angle())
	ci.draw_texture_rect(brass("ecke"), Rect2(-2, -2, 84, 84), false)
	ci.draw_set_transform(Vector2.ZERO)


## Messingleiste waagrecht oder senkrecht von a nach b, Dicke t (17 = volles Band mit Wulst), Schatten nach rechts
## unten. flip: Profil gespiegelt (untere und rechte Kante), damit überall die Außenseite das Licht fängt wie an den Ecken.
static func edge(ci: CanvasItem, a: Vector2, b: Vector2, t := 10.0, shadow := true, flip := false) -> void:
	if shadow:
		var k := clampf(t / 13.0, 0.35, 1.0)
		for o in SHADOW_STEPS:
			_edge(ci, a + o * k, b + o * k, t, SHADOW, flip)
	_edge(ci, a, b, t, Color.WHITE, flip)


static func _edge(ci: CanvasItem, a: Vector2, b: Vector2, t: float, col: Color, flip := false) -> void:
	# Die Textur kachelt in Längsrichtung; quer skaliert auf die Dicke t
	var horizontal := is_equal_approx(a.y, b.y)
	var tex := brass("kante_h" if horizontal else "kante_v")
	var depth := float(tex.get_height() if horizontal else tex.get_width())
	var k := t / depth
	var f := -1.0 if flip else 1.0
	if horizontal:
		var y0 := a.y - t / 2 if not flip else a.y + t / 2
		ci.draw_set_transform(Vector2(minf(a.x, b.x), y0), 0.0, Vector2(k, k * f))
		ci.draw_texture_rect(tex, Rect2(0, 0, absf(b.x - a.x) / k, depth), true, col)
	else:
		var x0 := a.x - t / 2 if not flip else a.x + t / 2
		ci.draw_set_transform(Vector2(x0, minf(a.y, b.y)), 0.0, Vector2(k * f, k))
		ci.draw_texture_rect(tex, Rect2(0, 0, depth, absf(b.y - a.y) / k), true, col)
	ci.draw_set_transform(Vector2.ZERO)


## Messingrahmen um r: vier Leisten (untere und rechte gespiegelt). inset = wie weit die Leisten vor der Ecke enden,
## center = Abstand der Leistenmitte vom Rand (-1: t / 2).
static func frame(ci: CanvasItem, r: Rect2, t := 10.0, inset := 30.0, center := -1.0) -> void:
	_frame(ci, r, t, inset, center, false)


static func _frame_sides(r: Rect2, inset: float, h: float) -> Array:
	return [[Vector2(r.position.x + inset, r.position.y + h), Vector2(r.end.x - inset, r.position.y + h), false],
		[Vector2(r.position.x + inset, r.end.y - h), Vector2(r.end.x - inset, r.end.y - h), true],
		[Vector2(r.position.x + h, r.position.y + inset), Vector2(r.position.x + h, r.end.y - inset), false],
		[Vector2(r.end.x - h, r.position.y + inset), Vector2(r.end.x - h, r.end.y - inset), true]]


static func _frame(ci: CanvasItem, r: Rect2, t: float, inset: float, center: float, corners: bool) -> void:
	var h := t / 2 if center < 0 else center
	var sides := _frame_sides(r, inset, h)
	var w := r.size.x
	var hh := r.size.y
	var cs := [[r.position, Vector2.RIGHT], [r.position + Vector2(w, 0), Vector2.DOWN],
		[r.position + Vector2(w, hh), Vector2.LEFT], [r.position + Vector2(0, hh), Vector2.UP]]
	# erst alle Schatten (Leisten und Ecken), dann Leisten, dann Ecken: nichts wirft Schatten auf das Messing selbst
	var k := clampf(t / 13.0, 0.35, 1.0)
	for o in SHADOW_STEPS:
		for sd in sides:
			_edge(ci, sd[0] + o * k, sd[1] + o * k, t, SHADOW, sd[2])
		if corners:
			for c in cs:
				ci.draw_set_transform(c[0] + o, (c[1] as Vector2).angle())
				ci.draw_texture_rect(brass("ecke"), Rect2(-2, -2, 84, 84), false, SHADOW)
			ci.draw_set_transform(Vector2.ZERO)
	for sd in sides:
		_edge(ci, sd[0], sd[1], t, Color.WHITE, sd[2])
	if corners:
		for c in cs:
			corner(ci, c[0], c[1], Vector2.ZERO, false)


## Großer Tafelrahmen: Band mit Wulst (17 px) und verschweißte Ecken (Säule, Tafeln, Profil).
static func panel_frame(ci: CanvasItem, r: Rect2) -> void:
	_frame(ci, r, 17.0, 40.0, 8.5, true)


## Waagrechte Messingleiste als Control (Titel- und Abschnittslinien): Rundstab mit Schatten und Glanz.
class Rule extends Control:
	var thickness := 6.0

	func _init(min_width := 30.0, t := 6.0, expand := true) -> void:
		thickness = t
		custom_minimum_size = Vector2(min_width, t + 5)
		if expand:
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = Wc3Theme.gloss_material()
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := thickness / 2 + 1
		Wc3Theme.edge(self, Vector2(0, y), Vector2(size.x, y), thickness)


## Ebene über einer Fläche, die nur das Messing zeichnet, mit dem Glanz-Material (Node2D, damit Container sie
## nicht verschieben). painter(ci) zeichnet; redraw() nach Größenänderung.
class BrassLayer extends Node2D:
	var painter: Callable

	func _init(p: Callable) -> void:
		painter = p
		material = Wc3Theme.gloss_material()

	func _draw() -> void:
		painter.call(self)


## Trennlinie mit Raute in der Mitte (zwischen den Knopfgruppen der Säule).
class Divider extends Control:
	func _init() -> void:
		custom_minimum_size.y = 20
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = Wc3Theme.gloss_material()

	func _draw() -> void:
		var y := size.y / 2
		var m := size.x / 2
		Wc3Theme.edge(self, Vector2(0, y), Vector2(m - 12, y), 5.0)
		Wc3Theme.edge(self, Vector2(m + 12, y), Vector2(size.x, y), 5.0)
		for o in Wc3Theme.SHADOW_STEPS:
			draw_texture_rect(Wc3Theme.brass("raute"), Rect2(Vector2(m - 10, y - 10) + o * 0.6, Vector2(20, 20)), false, Wc3Theme.SHADOW)
		draw_texture_rect(Wc3Theme.brass("raute"), Rect2(m - 10, y - 10, 20, 20), false)
