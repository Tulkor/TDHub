class_name UiTheme
extends RefCounted
## Gemeinsame Farben und das Godot-Theme für alle Oberflächen.
## Stil „Arcade“: Monospace-Schrift, eckige Kanten, dicke rosa Rahmen mit türkisem Versatz-Schatten.
## eeveTD schaltet mit use_skin(DRUID) auf den Stil „Druidenhain“ um (druid_theme.gd): dieselben Namen,
## andere Farben, Schriften und Panels. Die Farben sind deshalb static var statt const.

const ARCADE := ""
const DRUID := "druid"
## Shopping Maul: Art déco wie die Menüs vor dem Spiel (deco_theme.gd), Petrol und Messing.
const DECO := "deco"
## Randgruppen TD: Plakatwand (poster_theme.gd), Papier, Druckerschwärze, Signalrot.
const POSTER := "poster"
## Tower Survivors: Hologramm (holo_theme.gd), Cyan-Linien auf halbtransparentem Dunkelblau.
const HOLO := "holo"

const ARCADE_COLORS := {
	"BG": Color("07040e"), "BAR": Color("0d0618"), "PANEL": Color("0d0618"), "PANEL_2": Color("160b28"),
	"BORDER": Color("3b2560"), "BORDER_2": Color("5b3a8a"), "TEXT": Color("f2eaff"), "MUTED": Color("a99cc8"),
	"DIM": Color("d7cdea"), "GOLD": Color("ff4fd8"), "GOLD_DARK": Color("0d0618"), "CYAN": Color("22c4ee"),
	"COIN": Color("ffd166"), "PURPLE": Color("8a4dff"), "PURPLE_LIGHT": Color("b38cff"), "HAVE": Color("5fe08a"),
	"MISSING": Color("ff5d7a"), "SHADOW": Color("22c4ee"),
}

## Aktiver Stil: ARCADE, DRUID, DECO oder POSTER.
static var skin := ARCADE

static var BG: Color = ARCADE_COLORS.BG
static var BAR: Color = ARCADE_COLORS.BAR
static var PANEL: Color = ARCADE_COLORS.PANEL
static var PANEL_2: Color = ARCADE_COLORS.PANEL_2
static var BORDER: Color = ARCADE_COLORS.BORDER
static var BORDER_2: Color = ARCADE_COLORS.BORDER_2
static var TEXT: Color = ARCADE_COLORS.TEXT
static var MUTED: Color = ARCADE_COLORS.MUTED
static var DIM: Color = ARCADE_COLORS.DIM
## Akzentfarbe (Hauptaktion, Auswahl, Titel). Heißt aus historischen Gründen GOLD.
static var GOLD: Color = ARCADE_COLORS.GOLD
## Text auf der Akzentfarbe.
static var GOLD_DARK: Color = ARCADE_COLORS.GOLD_DARK
static var CYAN: Color = ARCADE_COLORS.CYAN
## Cyan als Schriftfarbe (Hinweise, Stufen). Auf dem hellen Papier der Plakatwand ein dunkles Blau statt Gelb.
static var CYAN_TEXT: Color = ARCADE_COLORS.CYAN
## Farbe für Goldbeträge.
static var COIN: Color = ARCADE_COLORS.COIN
static var PURPLE: Color = ARCADE_COLORS.PURPLE
static var PURPLE_LIGHT: Color = ARCADE_COLORS.PURPLE_LIGHT
static var HAVE: Color = ARCADE_COLORS.HAVE
static var MISSING: Color = ARCADE_COLORS.MISSING
## Harter Versatz-Schatten unter Panels und Leisten.
static var SHADOW: Color = ARCADE_COLORS.SHADOW

const FONT := "res://assets/fonts/DejaVuSansMono.ttf"
const FONT_BOLD := "res://assets/fonts/DejaVuSansMono-Bold.ttf"


## Stil umschalten (ARCADE oder DRUID). Vor dem Bau der Oberfläche aufrufen; beim Verlassen zurück auf ARCADE.
static func use_skin(name: String) -> void:
	if name == skin:
		return
	skin = name
	var c: Dictionary = ARCADE_COLORS
	match name:
		DRUID: c = DruidTheme.COLORS
		DECO: c = _deco_colors()
		POSTER: c = PosterTheme.COLORS
		HOLO: c = HoloTheme.COLORS
	BG = c.BG
	BAR = c.BAR
	PANEL = c.PANEL
	PANEL_2 = c.PANEL_2
	BORDER = c.BORDER
	BORDER_2 = c.BORDER_2
	TEXT = c.TEXT
	MUTED = c.MUTED
	DIM = c.DIM
	GOLD = c.GOLD
	GOLD_DARK = c.GOLD_DARK
	CYAN = c.CYAN
	COIN = c.COIN
	PURPLE = c.PURPLE
	PURPLE_LIGHT = c.PURPLE_LIGHT
	HAVE = c.HAVE
	MISSING = c.MISSING
	SHADOW = c.SHADOW
	CYAN_TEXT = c.get("CYAN_TEXT", CYAN)


static func druid() -> bool:
	return skin == DRUID


static func deco() -> bool:
	return skin == DECO


static func poster() -> bool:
	return skin == POSTER


static func holo() -> bool:
	return skin == HOLO


## Farben von DecoTheme unter den Namen von UiTheme (kein Versatz-Schatten: SHADOW = Leistenfarbe).
static func _deco_colors() -> Dictionary:
	return {
		"BG": DecoTheme.BG, "BAR": DecoTheme.BAR, "PANEL": DecoTheme.PANEL, "PANEL_2": DecoTheme.PANEL_2,
		"BORDER": DecoTheme.BORDER, "BORDER_2": DecoTheme.BORDER_2, "TEXT": DecoTheme.TEXT, "MUTED": DecoTheme.MUTED,
		"DIM": DecoTheme.DIM, "GOLD": DecoTheme.GOLD, "GOLD_DARK": DecoTheme.GOLD_DARK, "CYAN": DecoTheme.CYAN,
		"COIN": DecoTheme.COIN, "PURPLE": DecoTheme.PURPLE, "PURPLE_LIGHT": DecoTheme.PURPLE_LIGHT,
		"HAVE": DecoTheme.HAVE, "MISSING": DecoTheme.MISSING, "SHADOW": DecoTheme.BAR,
	}

static var _themes: Dictionary = {}


## Fläche mit optionalem Rahmen. Im Arcade-Stil immer eckig (radius bleibt für alte Aufrufe erhalten).
static func box(bg: Color, border := Color.TRANSPARENT, _radius := 0, border_width := 2, pad := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	if border.a > 0.0:
		s.border_color = border
		# Druidenhain: feine 1-px-Rahmen wie im Entwurf, Arcade mindestens 2 px
		s.set_border_width_all(0 if border_width <= 0 else (border_width if druid() or holo() else maxi(border_width, 2)))
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


## Kasten mit schräg abgeschnittenen Ecken oben links und unten rechts (Tooltips).
static func chamfer(bg: Color, border: Color, cut := 10, pad := 10.0) -> StyleBox:
	if druid():
		return DruidTheme.frame(bg, border, pad)
	if deco():
		return DecoTheme.chamfer(bg, border, cut, pad)
	if poster():
		return PosterTheme.frame(bg, BORDER, pad)
	if holo():
		return HoloTheme.frame(bg, border, pad, float(cut))
	var s := box(bg, border, 0, 2, pad)
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_detail = 1
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


## Hauptpanel: dicker rosa Rahmen, harter türkiser Schatten nach rechts unten.
static func panel(pad := 14.0, alpha := 0.95, border := Color.TRANSPARENT) -> StyleBox:
	if poster():
		return PosterTheme.panel(pad, alpha, BORDER if border.a == 0.0 else border)
	if holo():
		return HoloTheme.panel(pad, alpha, border)
	if border.a == 0.0:
		border = GOLD
	if druid():
		return DruidTheme.panel(pad, alpha, border)
	if deco():
		# doppelter Messingrahmen wie in den Menüs, aber knapper, damit das HUD nicht wächst
		return DecoTheme.frame(Color(BG, alpha), border, border.darkened(0.25), 0, false, pad + 4.0)
	var s := box(Color(PANEL, alpha), border, 0, 3, pad)
	s.shadow_color = SHADOW
	s.shadow_size = 1
	s.shadow_offset = Vector2(5, 5)
	return s


static func font(bold := false) -> Font:
	if druid():
		return DruidTheme.font(bold)
	if deco():
		return DecoTheme.font(bold)
	if poster():
		return PosterTheme.font(bold)
	if holo():
		return HoloTheme.font(bold)
	return load(FONT_BOLD if bold else FONT)


static func get_theme() -> Theme:
	if _themes.has(skin):
		return _themes[skin]
	if deco():
		_themes[skin] = DecoTheme.get_theme()
		return _themes[skin]
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 15 if druid() else 14
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(PANEL_2, BORDER))
	t.set_stylebox("hover", "Button", box(PANEL_2, GOLD))
	t.set_stylebox("pressed", "Button", box(CYAN, CYAN))
	var off_bg := BAR if skin != ARCADE else Color("0b0614")
	t.set_stylebox("disabled", "Button", box(off_bg, BORDER.darkened(0.3) if druid() else Color("24183a")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", BAR)
	t.set_color("font_hover_pressed_color", "Button", BAR)
	t.set_color("font_disabled_color", "Button", BORDER if druid() else Color("5a4d74"))
	t.set_stylebox("normal", "LineEdit", box(PANEL_2, BORDER))
	t.set_stylebox("focus", "LineEdit", box(PANEL_2, CYAN))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel(12.0))
	for k in ["normal", "hover", "pressed", "focus"]:
		var s := box(PANEL_2, CYAN if k == "pressed" else (GOLD if k == "hover" else BORDER))
		t.set_stylebox(k, "OptionButton", s if k != "focus" else StyleBoxEmpty.new())
	t.set_color("font_pressed_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(BAR, GOLD, 0, 2, 6))
	t.set_stylebox("hover", "PopupMenu", box(PANEL_2, CYAN, 0, 0, 4))
	t.set_color("font_separator_color", "PopupMenu", CYAN)
	t.set_stylebox("panel", "TooltipPanel", chamfer(BAR, CYAN, 14, 12))
	t.set_stylebox("separator", "HSeparator", box(BORDER, Color.TRANSPARENT, 0, 0, 0))
	t.set_constant("separation", "HSeparator", 2)
	t.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 0, 2, 12))
	t.set_stylebox("panel", "ItemList", box(PANEL, BORDER, 0, 2, 8))
	t.set_stylebox("scroll", "VScrollBar", box(off_bg, Color.TRANSPARENT, 0, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(BORDER_2, Color.TRANSPARENT, 0, 0, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, Color.TRANSPARENT, 0, 0, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(CYAN, Color.TRANSPARENT, 0, 0, 3))
	# Regler: dünne Spur, gefüllter Teil pink, eckiger Cyan-Griff
	var track := box(BORDER, Color.TRANSPARENT, 0, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var filled := box(GOLD, Color.TRANSPARENT, 0, 0, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", _square_icon(CYAN, 18))
	t.set_icon("grabber_highlight", "HSlider", _square_icon(TEXT, 18))
	t.set_icon("grabber_disabled", "HSlider", _square_icon(BORDER_2, 18))
	if druid():
		DruidTheme.extend_theme(t)
	elif poster():
		PosterTheme.extend_theme(t)
	elif holo():
		HoloTheme.extend_theme(t)
	_themes[skin] = t
	return t


static var _icons: Dictionary = {}


## Eckiges Quadrat mit dunklem Rand, z. B. als Regler-Griff.
static func _square_icon(c: Color, px: int) -> Texture2D:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(BAR)
	img.fill_rect(Rect2i(2, 2, px - 4, px - 4), c)
	return ImageTexture.create_from_image(img)

## Kleine Symbole für Aktionsknöpfe: "up" (grüner Pfeil), "down" (roter Pfeil), "combine" (Kombinieren).
static func icon(kind: String, px := 22) -> Texture2D:
	var key := "%s_%d_%s" % [kind, px, skin]
	if _icons.has(key):
		return _icons[key]
	var svg := ""
	match kind:
		"up":
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><path d="M12 2 L22 13 L15.5 13 L15.5 22 L8.5 22 L8.5 13 L2 13 Z" fill="#%s" stroke="#0d0618" stroke-width="1.5"/></svg>' % HAVE.to_html(false)
		"down":
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><path d="M12 22 L22 11 L15.5 11 L15.5 2 L8.5 2 L8.5 11 L2 11 Z" fill="#%s" stroke="#0d0618" stroke-width="1.5"/></svg>' % MISSING.to_html(false)
		"combine":
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><g fill="none" stroke="#%s" stroke-width="3.2" stroke-linecap="square" stroke-linejoin="miter"><path d="M3 4 L10 12 L3 20"/><path d="M10 12 L17 12"/></g><path d="M15 6 L23 12 L15 18 Z" fill="#%s"/></svg>' % [CYAN.to_html(false), CYAN.to_html(false)]
	var img := Image.new()
	if svg == "" or img.load_svg_from_string(svg, px / 24.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


## Button in einer Akzentfarbe (Rosa für die Hauptaktion, Lila für One-Shots), mit hartem Versatz-Schatten.
static func accent_button(b: Button, bg: Color, fg: Color, _glow: Color = Color.TRANSPARENT) -> void:
	if druid():
		DruidTheme.accent_button(b, bg, fg)
		return
	if deco():
		DecoTheme.accent_button(b, bg, fg, Color.TRANSPARENT, false)
		return
	if poster():
		PosterTheme.accent_button(b, bg, fg)
		return
	if holo():
		HoloTheme.accent_button(b, bg, fg)
		return
	var normal := box(bg, Color.TRANSPARENT, 0, 0, 14)
	normal.shadow_color = CYAN if bg != CYAN else GOLD
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(4, 4)
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


## Kleines Label mit Großbuchstaben als Abschnittstitel.
static func caption(text: String, parent: Node) -> Label:
	var l := UiUtil.label(str(TranslationServer.translate(text)).to_upper(), parent, 12)
	l.add_theme_color_override("font_color", MUTED)
	if druid():
		l.add_theme_font_override("font", DruidTheme.font(true, 2))
	elif deco():
		l.add_theme_color_override("font_color", GOLD)
	elif poster():
		l.add_theme_font_override("font", PosterTheme.font(true))
	elif holo():
		HoloTheme.caption(l)
	return l


## Panel-Überschrift (DPS, Gegner, Tower, Elemente …): Arcade in Großbuchstaben und fett, optional farbig;
## Druidenhain in Uncial Antiqua, etwas größer, in hellem Messing mit schwarzem Schatten.
static func heading(l: Label, color := Color.TRANSPARENT) -> Label:
	if druid():
		return DruidTheme.heading(l)
	if poster():
		return PosterTheme.heading(l, color)
	if holo():
		return HoloTheme.heading(l, color)
	if deco():
		# Messing, Großbuchstaben, gesperrt (Federo; Limelight erst ab DecoTheme.DISPLAY_SIZE)
		l.uppercase = true
		l.add_theme_font_override("font", DecoTheme.font(true))
		l.add_theme_color_override("font_color", color if color.a > 0.0 else GOLD)
		return l
	l.uppercase = true
	l.add_theme_font_override("font", font(true))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


## Überschrift im Arcade-Stil: Großbuchstaben, fett, rosa mit türkisem Schatten.
static func title(l: Label, size := 0) -> Label:
	if druid():
		return DruidTheme.title(l, size)
	if poster():
		return PosterTheme.title(l, size)
	if holo():
		return HoloTheme.title(l, size)
	if deco():
		return DecoTheme.title(l, size)
	l.uppercase = true
	l.add_theme_font_override("font", font(true))
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_shadow_color", CYAN)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l
