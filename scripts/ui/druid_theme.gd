class_name DruidTheme
extends RefCounted
## Stil „Druidenhain“ für eeveTD (Entwurf F01, ohne Farbverlauf in den Fenstern).
## Moosgraue Panels, doppelter Messingrahmen, Triquetren in den Ecken, Titel in Uncial Antiqua, Text in Alegreya.
## Nicht direkt benutzen: eeveTD ruft UiTheme.use_skin(UiTheme.DRUID) auf, danach liefern UiTheme.panel(),
## title(), font(), box(), accent_button() … und die Farbnamen diesen Stil.

## Dieselben Namen wie in UiTheme (GOLD = Akzent/Rahmen, CYAN = ausgewählt, GOLD_DARK = Schrift darauf).
const COLORS := {
	"BG": Color("1a2420"),
	"BAR": Color("1e2824"),
	"PANEL": Color("3a4440"),
	"PANEL_2": Color("2a3430"),
	"BORDER": Color("6a7a5a"),
	"BORDER_2": Color("8a9a6a"),
	"TEXT": Color("e8e2cc"),
	"MUTED": Color("b4b094"),
	"DIM": Color("d4cfb8"),
	"GOLD": Color("c8b070"),
	"GOLD_DARK": Color("1a2420"),
	"CYAN": Color("d8c888"),
	"COIN": Color("d8b860"),
	"PURPLE": Color("6a5a8a"),
	"PURPLE_LIGHT": Color("a88ad0"),
	"HAVE": Color("7ab85a"),
	"MISSING": Color("e8705a"),
	"SHADOW": Color("1a2420"),
}
## Graugrüne Außenkante um Panels und Leisten.
const EDGE := Color("5a6a50")
## Helles Messing für Überschriften.
const TITLE := Color("d8c888")

const FONT := "res://assets/fonts/Alegreya-Variable.ttf"
const FONT_TITLE := "res://assets/fonts/UncialAntiqua-Regular.ttf"
const FONT_FALLBACK := "res://assets/fonts/DejaVuSansMono.ttf"

static var _fonts: Dictionary = {}


## Alegreya (variable Schrift, bold = Strichstärke 700). Zeichen wie ◆ kommen aus DejaVu.
static func font(bold := false, spacing := 0) -> Font:
	var key := "text|%s|%d" % [bold, spacing]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load(FONT)
		var ts := TextServerManager.get_primary_interface()
		f.variation_opentype = {ts.name_to_tag("weight"): 700 if bold else 450}
		f.spacing_glyph = spacing
		# Alegreya hat viel Zeilenabstand; etwas enger, damit die Panels nicht höher werden als im Arcade-Stil
		f.spacing_top = -2
		f.spacing_bottom = -2
		f.fallbacks = [load(FONT_FALLBACK)]
		_fonts[key] = f
	return _fonts[key]


## Uncial Antiqua für Titel; was ihr fehlt, kommt aus Alegreya.
static func title_font() -> Font:
	if not _fonts.has("title"):
		var f := FontVariation.new()
		f.base_font = load(FONT_TITLE)
		f.fallbacks = [font(true)]
		_fonts["title"] = f
	return _fonts["title"]


## Panel: einfarbig, Messingrahmen außen, dünner Messingrahmen innen, dunkler Ring, Triquetren.
static func panel(pad := 14.0, alpha := 0.95, border: Color = COLORS.GOLD) -> StyleBox:
	var s := DruidBox.new()
	s.bg = Color(COLORS.PANEL, maxf(alpha, 0.96))
	s.line = border
	s.inner = Color(border, 0.55)
	s.ring = COLORS.BG
	s.ring_edge = EDGE
	s.knots = true
	# Wie UiTheme.box: oben und unten weniger Rand als seitlich, aber genug Abstand zum inneren Rahmen
	s.content_margin_left = pad + 4.0
	s.content_margin_right = pad + 4.0
	s.content_margin_top = pad * 0.6 + 6.0
	s.content_margin_bottom = pad * 0.6 + 6.0
	return s


## Einfacher Rahmen ohne Knoten (Tooltips).
static func frame(bg: Color, border: Color, pad := 10.0) -> StyleBox:
	var s := DruidBox.new()
	s.bg = Color(COLORS.PANEL, 0.98) if bg == COLORS.BAR else bg
	s.line = border
	s.inner = Color(border, 0.45)
	s.ring = COLORS.BG
	s.set_content_margin_all(pad + 4.0)
	return s


## Ergänzt das von UiTheme gebaute Theme: Fenster als Druiden-Panel.
static func extend_theme(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", panel(12.0))


## Überschrift: Uncial Antiqua in hellem Messing mit schwarzem Schatten, keine Großbuchstaben.
static func title(l: Label, size := 0) -> Label:
	l.uppercase = false
	l.add_theme_font_override("font", title_font())
	if size > 0:
		l.add_theme_font_size_override("font_size", size + 4)
	l.add_theme_color_override("font_color", TITLE)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## Panel-Überschrift: wie title(), etwas größer als die Arcade-Größe des Labels.
static func heading(l: Label) -> Label:
	var size := l.get_theme_font_size("font_size") if l.has_theme_font_size_override("font_size") else 15
	title(l)
	l.add_theme_font_size_override("font_size", size + 3)
	# Panel-Überschriften in fetter Textschrift: Unziale liest sich klein falsch („Nächsce“, „Laser“),
	# sie bleibt für große Fenstertitel (UI-Prüfung 2026-11-25)
	l.add_theme_font_override("font", font(true, 1))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## Hauptaktion: Messing mit dunkler Schrift, dunkler Innenlinie und schwarzem Schatten.
static func accent_button(b: Button, bg: Color, fg: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = Color(COLORS.BG, 0.7)
	normal.set_border_width_all(1)
	normal.expand_margin_left = 1
	normal.expand_margin_right = 1
	normal.shadow_color = Color(0, 0, 0, 0.6)
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(2, 2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.15)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15)
	pressed.shadow_offset = Vector2(1, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_font_override("font", font(true))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
