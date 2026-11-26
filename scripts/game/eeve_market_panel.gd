class_name EeveMarketPanel
extends Control
## Fenster des Marktplatzes in eeveTD (öffnet sich beim Anklicken des eigenen Marktplatzes): links Kaufen
## (Holz, Tränke, Phiole) und Verkaufen (Lager zum halben Wert), rechts die Upgrades für alle eigenen Tower
## und wie Items fallen. Werte aus data/eeve_items.json, Befehle market_buy, item_sell, market_upgrade.

var game  # eeve_game.gd
var _money: Label
var _buy: VBoxContainer
var _sell: VBoxContainer
var _ups: VBoxContainer
var _key := ""   ## Stand der letzten Anzeige, damit die Zeilen nur bei Änderungen neu gebaut werden


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(18.0))
	panel.custom_minimum_size.x = 1080
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var title := UiUtil.label("Marktplatz", head, 26)
	UiTheme.title(title, 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_money = UiUtil.label("", head, 15)
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close_b := UiUtil.button("Schließen", head, close)
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.tooltip_text = tr("Esc")

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	_section("Kaufen", "", left)
	_buy = VBoxContainer.new()
	left.add_child(_buy)
	_section("Verkaufen", tr("halber Wert"), left)
	_sell = VBoxContainer.new()
	left.add_child(_sell)

	_section("Verbesserungen", tr("für alle eigenen Tower"), right)
	_ups = VBoxContainer.new()
	right.add_child(_ups)
	var note := UiUtil.wrap_label(tr("Holz brauchen auch Fallen, Aura-, Dual- und Stufe-6-Tower. Upgrades erst kaufen, wenn Holz übrig ist."), right, 500)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UiTheme.MUTED)
	_section("Drops", "", right)
	var drops := UiUtil.wrap_label(tr("Ab Level 11 kann der erste Kill eines Levels ein Item fallen lassen, Chance und Stufe steigen mit dem Level. Jeder besiegte Golem bringt sicher zwei Items. Ist das Lager voll, wird das Item zum halben Wert verkauft."), right, 500)
	drops.add_theme_font_size_override("font_size", 14)


func _section(text: String, sub: String, parent: Node) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var l := UiUtil.label(text, h, 16)
	UiTheme.heading(l)
	if sub != "":
		var s := UiUtil.label(sub, h, 14)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		s.add_theme_color_override("font_color", UiTheme.MUTED)


func open() -> void:
	visible = true
	_key = ""
	refresh()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if not visible or game == null:
		return
	var p: int = game.local_player
	var st: Dictionary = game.ep(p)
	var saved: int = game.acting
	game.acting = p
	var key := JSON.stringify([game.gold, game.lumber, st.get("items", []), st.get("market", {}), game.eitems.has_market(p)])
	if key == _key:
		game.acting = saved
		return
	_key = key
	_money.text = tr("Gold %d · Holz %d") % [game.gold, game.lumber]
	_money.add_theme_color_override("font_color", UiTheme.COIN)
	for box in [_buy, _sell, _ups]:
		for c in box.get_children():
			c.queue_free()
	for s in EeveItems.shop():
		var id := str(s.item)
		var reason: String = game.eitems.buy_reason(id)
		_row(_buy, id, EeveItems.item_name(id), EeveItems.effect_text(id), tr("%d Gold") % int(s.price), reason, true,
			func(): game.submit({"type": "market_buy", "id": id}))
	var inv: Array = st.get("items", [])
	if inv.is_empty():
		var none := UiUtil.label(tr("Das Lager ist leer."), _sell, 14)
		none.add_theme_color_override("font_color", UiTheme.MUTED)
	for i in inv.size():
		var id := str(inv[i])
		var idx := i
		_row(_sell, id, EeveItems.item_name(id), EeveItems.effect_text(id), tr("+%d Gold") % EeveItems.sell_price(id),
			"" if game.eitems.has_market(p) else tr("erst einen Marktplatz bauen"), false,
			func(): game.submit({"type": "item_sell", "index": idx}))
	var ups: Dictionary = EeveItems.data().get("market", {}).get("upgrades", {})
	for kind in ups:
		var u: Dictionary = ups[kind]
		var lvl := EeveItems.market_level(st, kind)
		var costs: Array = u.get("costs", [])
		var c: Dictionary = game.eitems.upgrade_cost(kind)
		var price := tr("höchste Stufe") if c.is_empty() else tr("%d Gold") % int(c.gold) + (" + " + tr("%d Holz") % int(c.lumber) if int(c.lumber) > 0 else "")
		var per := float(u.get("per_level", 0.0))
		var eff := ("+%s" % TowerStats.num(per)) if kind == "range" else ("+%d %%" % roundi(per * 100.0))
		var text := tr("%s je Stufe · Stufe %d von %d") % [eff, lvl, costs.size()]
		var k := str(kind)
		_row(_ups, "", tr(str(u.get("name", kind))), text, price, game.eitems.upgrade_reason(k) if not c.is_empty() else tr("höchste Stufe"), true,
			func(): game.submit({"type": "market_upgrade", "kind": k}), lvl, costs.size())
	game.acting = saved


## Eine Zeile: Symbol, Name mit Wirkung darunter, rechts der Knopf (Preis). pips/max: Stufen als Kästchen.
func _row(parent: Node, id: String, name: String, text: String, price: String, reason: String, accent: bool,
		on_press: Callable, pips := -1, max_pips := 0) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	if id != "":
		var ic := ItemIcon.new(40.0)
		ic.set_item(id)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var n := UiUtil.label(name, info, 15)
	n.add_theme_font_override("font", UiTheme.font(true))
	var t := UiUtil.wrap_label(text.replace("\n", " · "), info, 300)
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", UiTheme.MUTED)
	if pips >= 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		info.add_child(row)
		for i in max_pips:
			var p := ColorRect.new()
			p.custom_minimum_size = Vector2(14, 8)
			p.color = UiTheme.HAVE if i < pips else UiTheme.PANEL_2
			row.add_child(p)
	var b := UiUtil.button(price, h, on_press)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 34)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = reason != ""
	b.tooltip_text = reason
	if accent:
		UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.GOLD_DARK)
	var sep := HSeparator.new()
	parent.add_child(sep)
