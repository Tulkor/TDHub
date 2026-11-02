class_name ProfileWc3
extends RefCounted
## Bausteine der Profilseite im Warcraft-III-Stil (Wc3Theme, Mockups /mnt/project-files/mockups/wc3-profil/):
## Überschriften zwischen Messinglinien, dunkle Kacheln, Wert-Zeilen, Level-Raute mit Balken, Modus-Liste,
## Zahlen- und Zeitformate. Genutzt von profile_panel.gd (Übersicht, Detail) und profile_history.gd.

## Modi im Profil: [Schlüssel in profile.json, Name, Farbe von Edelstein und Balken]
const MODES := [
	["gemtd", "GemTD", Color("e2553c")],
	["roguelike", "Roguelike", Color("e8913a")],
	["eeve", "eeveTD", Color("69c98c")],
	["maul", "Shopping Maul", Color("b878e0")],
	["randgruppen", "Randgruppen TD", Color("5d8ff0")],
	["youtd", "YouTD", Color("e0b56a")],
]
const WIN := Color("9fd27a")
const LOSS := Color("e07b5f")
const TILE_BG := Color(0, 0, 0, 0.38)
const ROW_BG := Color(0, 0, 0, 0.24)
const GEM := "res://assets/textures/menu/messing/rubin.png"


static func mode_name(m: String) -> String:
	for x in MODES:
		if x[0] == m:
			return x[1]
	return m


## Kurzer Name für Reiter und Filter.
static func short_name(m: String) -> String:
	return {"maul": "Maul", "randgruppen": "Randgruppen"}.get(m, mode_name(m))


static func mode_color(m: String) -> Color:
	for x in MODES:
		if x[0] == m:
			return x[2]
	return Wc3Theme.GOLD


## Schrift über Stein: Cinzel (Wc3Theme.label) für Überschriften und Zahlen.
static func cin(text: String, parent: Node, size: int, color := Wc3Theme.GOLD_HI, spacing := 0) -> Label:
	var l := Wc3Theme.label(text, parent, size, color, spacing)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Fließtext: Alegreya mit dunklem Schatten (wie die Einzelspieler-Seite).
static func body(text: String, parent: Node, size := 16, color := Wc3Theme.CREAM) -> Label:
	var l := UiUtil.label(text, parent, size)
	l.add_theme_font_override("font", DruidTheme.font(false))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rule() -> Control:
	return Wc3Theme.Rule.new()


## Abschnittstitel: Cinzel in Großbuchstaben zwischen zwei Messinglinien.
static func caption(text_de: String, parent: Node) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	row.add_child(rule())
	var l := cin(tr_up(text_de), row, 17, Wc3Theme.CREAM, 4)
	row.add_child(rule())
	return l


static func tr_up(text_de: String) -> String:
	return TranslationServer.translate(text_de).to_upper()


static func flat(bg: Color, border := Color(0, 0, 0, 0), pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0 else 0)
	sb.set_content_margin_all(pad)
	return sb


## Dunkle Kachel: kleine Überschrift, großer Wert, Zeile darunter.
static func tile(parent: Node, caption_de: String, value: String, sub := "", value_color := Wc3Theme.GOLD_HI) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", flat(TILE_BG, Wc3Theme.GOLD_LO, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	cin(tr_up(caption_de), v, 13, Wc3Theme.MUTED, 2)
	var l := cin(value, v, 26, value_color)
	l.clip_text = true
	if sub != "":
		body(sub, v, 14, Wc3Theme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return p


static func grid(parent: Node, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	parent.add_child(g)
	return g


## Zeile "Name ……… Wert" mit feiner Messinglinie darunter.
static func kv(parent: Node, key_de: String, value: String, color := Wc3Theme.GOLD_HI) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var k := body(key_de, row, 16)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := cin(value, row, 16, color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var line := ColorRect.new()
	line.color = Color(Wc3Theme.GOLD_LO, 0.4)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return row


## Kleiner Edelstein in Modusfarbe.
static func gem(parent: Node, m: String, h := 24) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(GEM)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(h * 0.75, h)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Rubin entfärben und in der Modusfarbe tönen
	var mat := ShaderMaterial.new()
	mat.shader = _gem_shader()
	mat.set_shader_parameter("tint", mode_color(m))
	t.material = mat
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


static var _shader: Shader


static func _gem_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = max(max(c.r, c.g), c.b);
	COLOR = vec4(tint.rgb * (0.2 + 1.0 * l) + vec3(pow(l, 6.0) * 0.25), c.a);
}"""
	return _shader


## Level eines Modus fürs Profil, {} wenn der Modus kein Spieler-Level hat:
## {name, value (Text), level (Zahl in der Raute), frac (0..1 bis zum nächsten), next (Zeile darunter)}.
static func level_info(m: String) -> Dictionary:
	match m:
		"maul":
			var xp := MaulXp.load_xp()
			var steps := [int(MaulXp.cfg().get("pro_shops", 25)) * 10]
			for v in MaulXp.cfg().get("unlocks", {}).values():
				steps.append(int(v) * 10)
			steps.sort()
			var prev := 0
			var nxt := -1
			for s in steps:
				if s <= xp:
					prev = s
				elif nxt < 0:
					nxt = s
			var next_text: String = TranslationServer.translate("Alles freigeschaltet") if nxt < 0 \
				else TranslationServer.translate("Nächste Freischaltung ab %s XP") % MaulXp.text(nxt)
			if MaulXp.pro_unlocked(xp):
				next_text = TranslationServer.translate("Profi-Filialen frei") + " · " + next_text
			return {"name": "XP", "value": MaulXp.text(xp), "level": xp / 10,
				"frac": 1.0 if nxt < 0 else clampf(float(xp - prev) / maxf(nxt - prev, 1), 0.0, 1.0), "next": next_text}
		"youtd":
			var lvl := YoutdProgress.level()
			var table := YoutdData.player_exp_table()
			var xp := YoutdProgress.xp()
			var cur := float(table[lvl]) if lvl < table.size() else xp
			var nxt := float(table[lvl + 1]) if lvl + 1 < table.size() else -1.0
			var text: String = TranslationServer.translate("%s / %s XP · Weisheit %d") % [num(roundi(xp)), num(roundi(nxt)), YoutdProgress.wisdom_points()] \
				if nxt > 0 else TranslationServer.translate("Höchstes Level")
			return {"name": TranslationServer.translate("Spielerlevel"), "value": str(lvl), "level": lvl,
				"frac": 1.0 if nxt <= 0 else clampf((xp - cur) / maxf(nxt - cur, 1.0), 0.0, 1.0), "next": text}
	return {}


## Raute mit Level, daneben Name, Balken und Zeile darunter.
static func level_card(parent: Node, m: String) -> Control:
	var info := level_info(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var d := LevelDiamond.new()
	d.level = int(info.get("level", 0))
	d.tint = mode_color(m)
	row.add_child(d)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	cin("%s · %s %s" % [TranslationServer.translate(mode_name(m)), info.get("name", ""), info.get("value", "")], v, 17)
	var b := Bar.new()
	b.frac = float(info.get("frac", 0.0))
	b.color = mode_color(m)
	b.text = TranslationServer.translate("%d %% bis zum nächsten Level") % roundi(b.frac * 100) if b.frac < 1.0 else ""
	b.custom_minimum_size.y = 22
	v.add_child(b)
	body(str(info.get("next", "")), v, 14, Wc3Theme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return row


## Ergebnis eines Index-Eintrags: [Text, Farbe].
static func result(r: Dictionary) -> Array:
	if r.get("aborted", false):
		return ["Unterbrochen" if r.get("saved", false) else "Abgebrochen", Wc3Theme.MUTED]
	return ["Sieg", WIN] if r.get("victory", false) else ["Niederlage", LOSS]


static func difficulty(r: Dictionary) -> String:
	var m := str(r.get("mode", ""))
	if m == "maul":
		return TranslationServer.translate("Stufe %d") % int(r.get("difficulty", 0))
	var d := int(r.get("difficulty", 0))
	if d < 0 or d >= Session.DIFFICULTIES.size():
		return str(d)
	return TranslationServer.translate(str(Session.DIFFICULTIES[d].name))


# --- Formate ---------------------------------------------------------------------------

static func num(v: int) -> String:
	return RunHistoryPanel._num(v)


## 4.120.000 -> "4,1 Mio."
static func short(v: float) -> String:
	if v >= 1e9:
		return TranslationServer.translate("%s Mrd.") % String.num(v / 1e9, 1).replace(".", ",")
	if v >= 1e6:
		return TranslationServer.translate("%s Mio.") % String.num(v / 1e6, 1).replace(".", ",")
	return num(roundi(v))


## Spielzeit: "41 h 12 min", unter einer Stunde "12 min".
static func hours(sec: int) -> String:
	if sec >= 3600:
		return "%d h %02d min" % [sec / 3600, (sec / 60) % 60]
	return "%d min" % (sec / 60)


static func duration(sec: int) -> String:
	return RunHistoryPanel._duration(sec)


static func percent(a: int, b: int) -> String:
	return "%d %%" % roundi(100.0 * a / maxf(b, 1))


## Balken mit Messingrand, Füllung in Modusfarbe, Text in der Mitte.
class Bar extends Control:
	var frac := 0.0
	var color := Wc3Theme.GOLD
	var text := ""

	func _init() -> void:
		custom_minimum_size = Vector2(60, 16)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.6))
		var w := (size.x - 2) * clampf(frac, 0.0, 1.0)
		if w > 0:
			draw_rect(Rect2(1, 1, w, size.y - 2), color.darkened(0.35))
			draw_rect(Rect2(1, 1, w, (size.y - 2) * 0.45), color)
		draw_rect(r, Wc3Theme.GOLD_LO, false, 1.0)
		if text != "":
			var f := Wc3Theme.font(1)
			var fs := 12
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2((size.x - tw) / 2, (size.y + f.get_ascent(fs) - f.get_descent(fs)) / 2)
			draw_string(f, pos + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
			draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Wc3Theme.HOT)


## Gedrehtes Quadrat aus Fels mit Messingrand und der Levelzahl.
class LevelDiamond extends Control:
	var level := 0
	var tint := Color("6b160e")
	var _rock: Texture2D

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_rock = load(Wc3Theme.ROCK)

	func _draw() -> void:
		var c := size / 2
		var h := minf(size.x, size.y) / 2 - 4
		var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
		Wc3Theme.fill_textured(self, pts, _rock, 120.0, Color(tint.darkened(0.55), 0.92))
		draw_polyline(Wc3Theme.closed(pts), Wc3Theme.INK, 5.0, true)
		draw_polyline(Wc3Theme.closed(pts), Wc3Theme.GOLD, 2.5, true)
		var f := Wc3Theme.font()
		var fs := 22 if level < 100 else 18
		var t := str(level)
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - tw / 2, c.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2)
		draw_string(f, pos + Vector2(0, 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
		draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Wc3Theme.HOT)
