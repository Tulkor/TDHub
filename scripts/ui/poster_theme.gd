class_name PosterTheme
extends RefCounted
## Stil „Plakatwand“ für Randgruppen TD (Entwurf A, Lukas 2026-10-26): Papier statt Neon, schwarze Druckerschwärze,
## Signalrot als Akzent, Textmarker-Gelb für Auswahl. Titel in Bowlby One, Text in Courier Prime (beide OFL).
## Nicht direkt benutzen: rg_game.gd ruft UiTheme.use_skin(UiTheme.POSTER) auf, danach liefern UiTheme.panel(),
## title(), font(), box(), accent_button() … und die Farbnamen diesen Stil.

## Dieselben Namen wie in UiTheme (GOLD = Akzent Rot, CYAN = Auswahl Textmarker, GOLD_DARK = Schrift darauf).
const COLORS := {
	"BG": Color("151515"),
	"BAR": Color("d9cfb5"),
	"PANEL": Color("efe8d6"),
	"PANEL_2": Color("e2d9c2"),
	"BORDER": Color("151515"),
	"BORDER_2": Color("6b6355"),
	"TEXT": Color("151515"),
	"MUTED": Color("5a5348"),
	"DIM": Color("3a352d"),
	"GOLD": Color("e8372a"),
	"GOLD_DARK": Color("151515"),
	"CYAN": Color("ffd83a"),
	"COIN": Color("a8660a"),
	"PURPLE": Color("5b3a8a"),
	"PURPLE_LIGHT": Color("7a4fc0"),
	"HAVE": Color("2e8a3e"),
	"MISSING": Color("c4161c"),
	"SHADOW": Color("151515"),
	"CYAN_TEXT": Color("1d4f7a"),
}
## Harter Plakat-Schatten unter Panels.
const DROP := Color("e8372a")

const FONT := "res://assets/fonts/CourierPrime-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/CourierPrime-Bold.ttf"
const FONT_TITLE := "res://assets/fonts/BowlbyOne-Regular.ttf"
const FONT_FALLBACK := "res://assets/fonts/DejaVuSansMono.ttf"

static var _fonts: Dictionary = {}


## Courier Prime; Zeichen wie ◆ oder · kommen aus DejaVu.
static func font(bold := false) -> Font:
	var key := "text|%s" % bold
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load(FONT_BOLD if bold else FONT)
		f.fallbacks = [load(FONT_FALLBACK)]
		_fonts[key] = f
	return _fonts[key]


## Bowlby One für Titel; was ihr fehlt, kommt aus Courier Prime.
static func title_font() -> Font:
	if not _fonts.has("title"):
		var f := FontVariation.new()
		f.base_font = load(FONT_TITLE)
		f.fallbacks = [font(true)]
		_fonts["title"] = f
	return _fonts["title"]


## Panel: Papier, schwarzer 3-px-Rahmen, harter roter Schatten nach rechts unten.
static func panel(pad := 14.0, alpha := 0.95, border: Color = COLORS.BORDER) -> StyleBox:
	var s := frame(Color(COLORS.PANEL, maxf(alpha, 0.96)), border, pad)
	s.shadow_color = DROP
	s.shadow_size = 1
	s.shadow_offset = Vector2(5, 5)
	return s


## Einfacher Kasten mit schwarzem Rahmen (Tooltips).
static func frame(bg: Color, border: Color, pad := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(COLORS.PANEL, 0.98) if bg == COLORS.BAR else bg
	s.border_color = border
	s.set_border_width_all(3)
	s.anti_aliasing = false
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


## Ergänzt das von UiTheme gebaute Theme: Fenster als Plakat, ausgegraute Knöpfe auf Papier.
static func extend_theme(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", panel(12.0))
	t.set_color("font_disabled_color", "Button", COLORS.BORDER_2)
	t.set_color("font_pressed_color", "Button", COLORS.GOLD_DARK)
	t.set_color("font_hover_pressed_color", "Button", COLORS.GOLD_DARK)


## Überschrift: Bowlby One in Großbuchstaben, schwarz mit rotem Versatz.
static func title(l: Label, size := 0) -> Label:
	l.uppercase = true
	l.add_theme_font_override("font", title_font())
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COLORS.TEXT)
	l.add_theme_color_override("font_shadow_color", DROP)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## Panel-Überschrift: wie title(), mit kleinerem Versatz. Helle Farben (Arcade-Cyan = Textmarker-Gelb) wären
## auf Papier unlesbar, dann bleibt es schwarz.
static func heading(l: Label, color := Color.TRANSPARENT) -> Label:
	title(l)
	# Plakatschrift erst ab Titelgröße, kleine Überschriften in fetter Schreibmaschine (UI-Prüfung 2026-11-25)
	if l.get_theme_font_size("font_size") < 20:
		l.add_theme_font_override("font", font(true))
	if color.a > 0.0 and color.get_luminance() < 0.5:
		l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## Hauptaktion: Farbfläche mit schwarzem Rahmen und schwarzem Versatz-Schatten wie ein aufgeklebtes Schild.
static func accent_button(b: Button, bg: Color, fg: Color) -> void:
	var normal := frame(bg, COLORS.BORDER, 14)
	normal.shadow_color = COLORS.SHADOW
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(4, 4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.12)
	pressed.shadow_offset = Vector2(1, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_font_override("font", title_font())
	# Text auf Rot hell, auf hellen Flächen schwarz
	var c := Color(COLORS.PANEL) if fg == COLORS.GOLD_DARK and bg.get_luminance() < 0.45 else fg
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, c)


## Bunte Schrift bekommt eine dünne schwarze Kontur, damit sie auf dem Papier lesbar bleibt (Wunsch von Lukas).
## Prüft alle Labels und Knöpfe unter root nach ihrer aktuellen Schriftfarbe; schwarze und graue Schrift bleibt ohne.
static func outline_colored(root: Node) -> void:
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not (c is Label or c is Button) or not c.is_visible_in_tree():
			continue
		var col: Color = c.get_theme_color("font_color")
		var colored := col.s > 0.3 and col.v > 0.35
		var has := c.has_theme_constant_override("outline_size") and c.has_meta("poster_outline")
		if colored and not has:
			c.set_meta("poster_outline", true)
			c.add_theme_constant_override("outline_size", 3)
			c.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08, 0.85))
		elif not colored and has:
			c.remove_meta("poster_outline")
			c.remove_theme_constant_override("outline_size")
			c.remove_theme_color_override("font_outline_color")
