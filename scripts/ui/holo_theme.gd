class_name HoloTheme
extends RefCounted
## Stil „Hologramm“ für Tower Survivors (Lukas 2026-11-04, Entwurf 1 „Cyan-Kommando“): halbtransparente
## dunkelblaue Flächen, dünne cyanfarbene Leuchtlinien, abgeschrägte Ecken (HoloBox). Text in Rajdhani,
## Zahlen und kleine Beschriftungen in Share Tech Mono (beide OFL), Zeichen wie ■ aus DejaVu.
## Nicht direkt benutzen: sv_game.gd ruft UiTheme.use_skin(UiTheme.HOLO) auf, danach liefern UiTheme.panel(),
## title(), font(), box(), accent_button() … und die Farbnamen diesen Stil.

## Dieselben Namen wie in UiTheme (GOLD = Akzent Cyan, CYAN = Auswahl hell, GOLD_DARK = Schrift darauf).
const COLORS := {
	"BG": Color("010d1f"),
	"BAR": Color("031a33"),
	"PANEL": Color("031a33"),
	"PANEL_2": Color("06264a"),
	"BORDER": Color("1d6f8f"),
	"BORDER_2": Color("2aa9cc"),
	"TEXT": Color("e6fbff"),
	"MUTED": Color("7fb6c8"),
	"DIM": Color("c8f0ff"),
	"GOLD": Color("3fe6ff"),
	"GOLD_DARK": Color("021018"),
	"CYAN": Color("c8f8ff"),
	"COIN": Color("ffd36a"),
	"PURPLE": Color("9a7bff"),
	"PURPLE_LIGHT": Color("c59bff"),
	"HAVE": Color("5ff0b0"),
	"MISSING": Color("ff5a7a"),
	"SHADOW": Color("3fe6ff"),
}
const LINE := Color("3fe6ff")
## Füllung der Tafeln: Spielfeld scheint durch (Lukas: halb transparent)
const FILL := Color(0.012, 0.1, 0.2, 0.66)

const FONT := "res://assets/fonts/Rajdhani-SemiBold.ttf"
const FONT_BOLD := "res://assets/fonts/Rajdhani-Bold.ttf"
const FONT_MONO := "res://assets/fonts/ShareTechMono-Regular.ttf"
const FONT_FALLBACK := "res://assets/fonts/DejaVuSansMono.ttf"

static var _fonts: Dictionary = {}


static func font(bold := false) -> Font:
	var key := "text|%s" % bold
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load(FONT_BOLD if bold else FONT)
		f.fallbacks = [load(FONT_FALLBACK)]
		f.spacing_glyph = 1 if bold else 0
		_fonts[key] = f
	return _fonts[key]


## Zahlen, Kürzel, kleine Beschriftungen.
static func mono() -> Font:
	if not _fonts.has("mono"):
		var f := FontVariation.new()
		f.base_font = load(FONT_MONO)
		f.fallbacks = [load(FONT_FALLBACK)]
		_fonts["mono"] = f
	return _fonts["mono"]


## Tafel: Fläche, Leuchtlinie, Eckwinkel. tab = Lasche oben, ticks = Messstriche unten.
static func holo(pad := 14.0, alpha := 1.0, line: Color = LINE, tab := false, ticks := false) -> HoloBox:
	var s := HoloBox.new()
	s.fill = Color(FILL, FILL.a * alpha)
	s.line = line
	s.tab = tab
	s.ticks = ticks
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.75 + (6.0 if tab else 0.0)
	s.content_margin_bottom = pad * 0.75
	return s


static func panel(pad := 14.0, alpha := 0.95, border := Color.TRANSPARENT) -> StyleBox:
	return holo(pad, clampf(alpha / 0.95, 0.4, 1.4), LINE if border.a == 0.0 else border)


## Kleiner Kasten (Knöpfe, Karten, Tooltips): kleine Schräge, keine Eckwinkel.
static func frame(bg: Color, border: Color, pad := 8.0, cut := 6.0) -> HoloBox:
	var s := HoloBox.new()
	s.fill = bg
	s.line = border if border.a > 0.0 else LINE
	s.line_alpha = 0.9 if border.a > 0.0 else 0.0
	s.cut = cut
	s.brackets = false
	s.glow = false
	s.line_width = 1.0
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.5
	s.content_margin_bottom = pad * 0.5
	return s


## Ergänzt das von UiTheme gebaute Theme: Knöpfe als schräge Holo-Kästen, Fenster als Tafel.
static func extend_theme(t: Theme) -> void:
	t.default_font_size = 16
	t.set_stylebox("normal", "Button", frame(Color(LINE, 0.1), Color(LINE, 0.9)))
	t.set_stylebox("hover", "Button", frame(Color(LINE, 0.22), Color.WHITE))
	t.set_stylebox("pressed", "Button", frame(LINE, LINE))
	t.set_stylebox("disabled", "Button", frame(Color(LINE, 0.03), Color(LINE, 0.3)))
	t.set_color("font_color", "Button", COLORS.DIM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", COLORS.GOLD_DARK)
	t.set_color("font_hover_pressed_color", "Button", COLORS.GOLD_DARK)
	t.set_color("font_disabled_color", "Button", Color(COLORS.MUTED, 0.55))
	t.set_stylebox("panel", "PanelContainer", panel(12.0))
	t.set_stylebox("panel", "TooltipPanel", frame(Color(COLORS.BG, 0.94), LINE, 12.0, 10.0))
	t.set_color("font_color", "TooltipLabel", COLORS.TEXT)


static func title(l: Label, size := 0) -> Label:
	l.uppercase = true
	l.add_theme_font_override("font", font(true))
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COLORS.TEXT)
	# leichter Schein in Cyan, Schrift selbst bleibt scharf
	l.add_theme_color_override("font_shadow_color", Color(LINE, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


static func heading(l: Label, color := Color.TRANSPARENT) -> Label:
	l.uppercase = true
	l.add_theme_font_override("font", font(true))
	l.add_theme_color_override("font_color", color if color.a > 0.0 else COLORS.TEXT)
	return l


## Hauptaktion: gefüllter Cyan-Kasten mit dunkler Schrift.
static func accent_button(b: Button, bg: Color, fg: Color) -> void:
	var normal := frame(bg, Color.WHITE, 14.0, 8.0)
	normal.line_alpha = 0.5
	var hover := frame(bg.lightened(0.25), Color.WHITE, 14.0, 8.0)
	var pressed := frame(bg.darkened(0.2), Color.WHITE, 14.0, 8.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_font_override("font", font(true))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)


## Kleiner Abschnittstitel: Share Tech Mono, gesperrt, Cyan.
static func caption(l: Label) -> void:
	l.add_theme_font_override("font", mono())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", LINE)
