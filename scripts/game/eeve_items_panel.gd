class_name EeveItemsPanel
extends PanelContainer
## eeveTD rechts unten: das Lager des Spielers (Drops und gekaufte Items) und die Item-Plätze des gewählten
## Towers als Inventarfelder wie in WC3 (InvSlot): Items zieht man auf Tower (auch in der Welt), auf andere Felder
## oder auf ein anderes Item (tauschen, Befehl item_move). Oder: Item anklicken, eigenen Tower wählen, „einsetzen“
## bzw. „benutzen“ (item_use).
## Die Tower-Liste darüber endet über diesem Fenster (hud.tower_list.limits).

const COLS := 4

var game  # eeve_game.gd
var picked := -1   ## gewähltes Item im Lager (Index), -1 = keins
var _count: Label
var _grid: GridContainer
var _key := ""
var _detail: Label
var _slots_box: VBoxContainer
var _slots_title: Label
var _slots_row: HBoxContainer
var _use: Button
var _hint: Label


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_right = -16
	offset_bottom = -16
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size.x = 280
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiTheme.panel(12.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiUtil.label("Lager", head, 16)
	UiTheme.heading(title)
	title.tooltip_text = tr("Items fallen ab Level 11 von Gegnern, Golems bringen immer zwei. Mehr gibt es am Marktplatz.")
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	_count = UiUtil.label("", head, 14)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_color_override("font_color", UiTheme.MUTED)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_grid)
	_detail = UiUtil.wrap_label("", v, 250)
	_detail.add_theme_font_size_override("font_size", 14)

	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 6)
	v.add_child(_slots_box)
	_slots_title = UiUtil.wrap_label("", _slots_box, 250)
	_slots_title.add_theme_font_size_override("font_size", 14)
	_slots_title.add_theme_color_override("font_color", UiTheme.CYAN)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 4)
	_slots_box.add_child(_slots_row)

	_use = UiUtil.button("", v, _on_use)
	_use.focus_mode = Control.FOCUS_NONE
	_use.custom_minimum_size.y = 34
	_use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # lange Itemnamen umbrechen statt abschneiden
	UiTheme.accent_button(_use, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_hint = UiUtil.wrap_label("", v, 250)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	refresh()


func _on_icon_click(button: int, i: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		picked = -1 if picked == i else i
		refresh()


## Inventarfeld mit gezeichnetem eeveTD-Symbol; loc = Ort für item_move.
func _slot(id: String, loc: Dictionary, side: float) -> InvSlot:
	var s := InvSlot.new(side)
	if id != "":
		var ic := ItemIcon.new(side - 6.0)
		ic.bare = true
		ic.set_item(id)
		s.show_node(ic, EeveItems.is_consumable(id))
		s.drag_data = {"inv": true, "from": loc}
	s.on_drop = func(data):
		picked = -1
		game.submit({"type": "item_move", "from": data.from, "to": loc})
	return s


static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _on_use() -> void:
	var t: Tower = game.selected
	if picked < 0 or t == null:
		return
	game.submit({"type": "item_use", "index": picked, "tower": game.tower_ref(t)})
	picked = -1
	refresh()


func _own_tower() -> Tower:
	var t: Tower = game.selected
	if t == null or not is_instance_valid(t) or not t is EeveTower or t.owner_player != game.local_player:
		return null
	return t


func refresh() -> void:
	if _grid == null or game == null:
		return
	var inv: Array = game.ep(game.local_player).get("items", [])
	if picked >= inv.size():
		picked = -1
	var cap := int(EeveItems.data().get("inventory_size", 8))
	_count.text = "%d / %d" % [inv.size(), cap]
	var t := _own_tower()
	var key := str(inv) + str(picked) + (str([t.get_instance_id(), t.items, EeveItems.slots(t)]) if t != null else "")
	var rebuild := key != _key
	_key = key
	if rebuild:
		_clear(_grid)
		for i in cap:
			var id: String = inv[i] if i < inv.size() else ""
			var s := _slot(id, {"stash": i}, 52.0)
			if id != "":
				s.set_marked(i == picked)
				s.tooltip_text = _tooltip(id) + "\n" + (tr("Auf einen Tower ziehen: benutzen (wird verbraucht)") if EeveItems.is_consumable(id)
						else tr("Auf einen Tower ziehen oder auf ein anderes Item (tauschen)"))
				s.clicked.connect(func(b): _on_icon_click(b, i))
			_grid.add_child(s)
	if picked >= 0:
		var id: String = inv[picked]
		_detail.text = "%s\n%s\n%s" % [EeveItems.item_name(id), EeveItems.effect_text(id), tr("Verkaufswert %d Gold") % EeveItems.sell_price(id)]
		_detail.add_theme_color_override("font_color", UiTheme.TEXT)
	else:
		_detail.text = tr("Item auf einen eigenen Tower ziehen oder anklicken und den Tower wählen.") if not inv.is_empty() else tr("Noch keine Items.")
		_detail.add_theme_color_override("font_color", UiTheme.MUTED)

	_slots_box.visible = t != null
	if t != null and rebuild:
		var n := EeveItems.slots(t)
		if n > 0:
			_slots_title.text = tr("Item-Plätze · %s · %d von %d frei") % [t.label(), n - t.items.size(), n]
		else:
			_slots_title.text = tr("%s hat keine Item-Plätze (ab Elementstufe 3)") % t.label()
		_clear(_slots_row)
		var ref: Dictionary = game.tower_ref(t)
		for i in int(EeveItems.data().get("max_slots", 6)):
			if i >= n:
				var off := InvSlot.new(36.0).set_locked()
				off.tooltip_text = tr("Diesen Platz hat der Tower nicht") if n > 0 else tr("Item-Plätze ab Elementstufe 3")
				_slots_row.add_child(off)
				continue
			var id: String = t.items[i] if i < t.items.size() else ""
			var s := _slot(id, {"tower": ref, "slot": i}, 36.0)
			s.tooltip_text = _tooltip(id) + "\n" + tr("Ins Lager, auf einen anderen Tower oder ein anderes Item ziehen") if id != "" \
					else tr("Freier Item-Platz: Item hierher ziehen")
			_slots_row.add_child(s)

	_use.visible = picked >= 0
	_hint.text = ""
	if picked >= 0:
		var id: String = inv[picked]
		var verb := tr("%s benutzen") if EeveItems.is_consumable(id) else tr("%s einsetzen")
		_use.text = verb % EeveItems.item_name(id)
		var reason: String = game.eitems.use_reason(picked, t) if t != null else tr("eigenen Tower wählen")
		_use.disabled = reason != ""
		_hint.text = reason if reason != "" else (tr("Eingesetzte Items lassen sich jederzeit wieder ins Lager ziehen.") if not EeveItems.is_consumable(id) else "")
	if inv.is_empty() and t == null:
		_hint.text = tr("Ab Level 11 können Gegner Items fallen lassen.")


static func _tooltip(id: String) -> String:
	var it := EeveItems.item(id)
	var head := EeveItems.item_name(id)
	if int(it.get("stage", 0)) > 0:
		head += " · " + TranslationServer.translate("Stufe %s") % ItemIcon.ROMAN[int(it.stage)]
	return head + "\n" + EeveItems.effect_text(id) + "\n" + TranslationServer.translate("Verkaufswert %d Gold") % EeveItems.sell_price(id)
