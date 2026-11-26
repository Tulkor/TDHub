class_name RoguePanel
extends Control
## Roguelike: Auswahl eines Bonus aus drei Karten (rogue.gd öffnet und schließt das Fenster).
## Klick auf eine Karte wählt sie aus, „Bonus nehmen“ (oder Doppelklick) schickt den Befehl rogue_pick.
## Solange das Fenster offen ist, fängt es alle Klicks aufs Feld ab.

const CARD_W := 250.0

var game  # game.gd
var offers: Array = []
var boons: Array = []
var _cards: Array = []
var _chosen := -1
var _take: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(22.0))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	UiTheme.title(UiUtil.label("Bonus wählen", v, 32))
	var sub := UiUtil.wrap_label(tr("Welle %d geschafft. Wähle einen von drei Boni, er gilt bis zum Ende des Spiels.") % game.wave_index, v, CARD_W * 3 + 36)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for i in offers.size():
		_cards.append(_card(offers[i], i, row))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	v.add_child(bottom)
	var have := UiUtil.wrap_label(_boons_text(), bottom, 0)
	have.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	have.add_theme_color_override("font_color", UiTheme.MUTED)
	have.add_theme_font_size_override("font_size", 14)
	_take = UiUtil.button("Bonus nehmen", bottom, _confirm)
	_take.custom_minimum_size = Vector2(220, 50)
	_take.add_theme_font_size_override("font_size", 20)
	UiTheme.accent_button(_take, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_take.disabled = true


func _card(o: Dictionary, index: int, parent: Node) -> Button:
	var rar := Rogue.rarity(str(o.rarity))
	var rcol: Color = _color(str(rar.get("color", "TEXT")))
	var def: Dictionary = Database.towers.get(str(o.id), {})
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_W, 340)
	b.focus_mode = Control.FOCUS_NONE
	_style_card(b, rcol, false)
	b.pressed.connect(func(): _choose(index))
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT:
			_choose(index)
			_confirm())
	parent.add_child(b)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)

	var r := UiUtil.label(str(tr(str(rar.get("name", "")))).to_upper(), v, 13)
	r.add_theme_font_override("font", UiTheme.font(true))
	r.add_theme_color_override("font_color", rcol)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var gem := Panel.new()
	gem.custom_minimum_size = Vector2(26, 26)
	var swatch := Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	if str(o.effect) == "flask":
		swatch = Color.from_string(str(o.params.get("color", "#ffffff")), Color.WHITE)
	elif str(o.kind) == "global":
		swatch = UiTheme.GOLD
	gem.add_theme_stylebox_override("panel", UiTheme.box(swatch, UiTheme.TEXT, 0, 2, 0))
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(gem)
	var who := tr("Alle deine Tower") if str(o.kind) == "global" else tr(str(def.get("name", o.id)))
	if str(o.effect) in ["gold", "interest", "luck", "double_pick"]:
		who = tr("Für dich")
	var name := UiUtil.wrap_label(who, head, 0)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_override("font", UiTheme.font(true))
	name.add_theme_font_size_override("font_size", 20)

	var scope: String = {"gem": tr("Grund-Gem · alle Stufen"), "special": tr("Spezialtower · mit Upgrades")}.get(str(o.kind), tr("Gilt bis zum Spielende"))
	var sc := UiUtil.wrap_label(scope, v, CARD_W - 32)
	sc.add_theme_color_override("font_color", UiTheme.MUTED)
	sc.add_theme_font_size_override("font_size", 14)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	v.add_child(spacer)
	var stat: bool = str(o.effect) == "stat"
	var big := UiUtil.wrap_label(Rogue.headline(o), v, CARD_W - 32)
	big.add_theme_font_size_override("font_size", 40 if stat else 22)
	big.add_theme_font_override("font", UiTheme.font(true))
	big.add_theme_color_override("font_color", UiTheme.GOLD)
	big.add_theme_color_override("font_shadow_color", UiTheme.CYAN)
	big.add_theme_constant_override("shadow_offset_x", 2)
	big.add_theme_constant_override("shadow_offset_y", 2)
	if not stat:
		big.uppercase = true
	var st := UiUtil.wrap_label(Rogue.details(o), v, CARD_W - 32)
	if stat:
		st.uppercase = true
		st.add_theme_font_override("font", UiTheme.font(true))
		st.add_theme_font_size_override("font_size", 16)
	else:
		st.add_theme_font_size_override("font_size", 14)

	var flavor := UiUtil.wrap_label(tr(str(Rogue.boon_def(str(o.boon)).get("title", ""))), v, CARD_W - 32)
	flavor.add_theme_color_override("font_color", UiTheme.PURPLE_LIGHT)
	flavor.add_theme_font_size_override("font_size", 14)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grow)
	var info := UiUtil.wrap_label(_card_info(o), v, CARD_W - 32)
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", UiTheme.HAVE if _owned(str(o.id)) > 0 else UiTheme.MUTED)
	for c in m.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _style_card(b: Button, border: Color, chosen: bool) -> void:
	var normal := UiTheme.box(UiTheme.PANEL_2, border, 0, 3, 0)
	normal.shadow_color = UiTheme.CYAN if chosen else Color(border, 0.35)
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(6, 6) if chosen else Vector2(4, 4)
	if chosen:
		normal.border_color = UiTheme.CYAN
		normal.set_border_width_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UiTheme.PANEL_2.lightened(0.08)
	for k in ["normal", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)


## Farbe der Seltenheit (Name einer UiTheme-Farbe aus data/roguelike.json).
static func _color(key: String) -> Color:
	match key:
		"CYAN":
			return UiTheme.CYAN
		"PURPLE_LIGHT":
			return UiTheme.PURPLE_LIGHT
		"GOLD":
			return UiTheme.GOLD
		"COIN":
			return UiTheme.COIN
		"HAVE":
			return UiTheme.HAVE
	return UiTheme.TEXT


func _card_info(o: Dictionary) -> String:
	var lines := []
	var have: int = game.rogue.count(game.local_player, str(o.effect)) if game.rogue != null else 0
	if str(o.kind) == "global":
		return tr("Hast du schon %d×, stapelt sich") % have if have > 0 else ""
	var before: float = game.rogue.total(game.local_player, str(o.id), str(o.stat)) if game.rogue != null and str(o.effect) == "stat" else 0.0
	if before > 0.0:
		lines.append(tr("Bisher %s, danach %s") % [Rogue.value_text(before), Rogue.value_text(before + float(o.value))])
	var n := _owned(str(o.id))
	lines.append(tr("Auf deinem Feld: %d×") % n if n > 0 else tr("Noch nicht auf deinem Feld"))
	return "\n".join(lines)


func _owned(id: String) -> int:
	var n := 0
	for t in game.all_towers():
		if t.tower_id == id and t.owner_player == game.local_player and not t.is_new:
			n += 1
	return n


func _boons_text() -> String:
	if boons.is_empty():
		return tr("Deine Boni: noch keine")
	return tr("Deine Boni: ") + ", ".join(boons.map(func(b): return Rogue.describe(b)))


func _choose(index: int) -> void:
	_chosen = index
	for i in _cards.size():
		var rar := Rogue.rarity(str(offers[i].rarity))
		_style_card(_cards[i], _color(str(rar.get("color", "TEXT"))), i == index)
	_take.disabled = false


func _confirm() -> void:
	if _chosen < 0:
		return
	_take.disabled = true
	game.submit({"type": "rogue_pick", "index": _chosen, "id": str(offers[_chosen].id), "boon": str(offers[_chosen].boon)})
