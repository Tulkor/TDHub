class_name YoutdStore
extends PanelContainer
## Lager unten links von YouTD: Tower-Lager (im Baumodus das Baumenü) und Item-Lager übereinander, jedes für sich
## einklappbar. Tower und Items als Icons. Items zieht man auf einen Tower (auf der Karte oder auf die Plätze der
## Auswahlkarte) und von dort zurück ins Lager. Im Kopf des Tower-Lagers „Würfeln“ und „6 → 1“, im Item-Lager
## „Öle kombinieren“. Die Würfel-Rezepte stehen im Fenster „Rezepte“ (youtd_panel.gd).

const COLS := 4
const SLOT := 40.0
const ROWS_TOWERS := 5
const ROWS_ITEMS := 6

## Welche Teile offen sind (bleibt für die Sitzung, auch in der nächsten Partie)
static var open := {"towers": true, "items": true}

var game  # youtd_game.gd
var _parts := {}           ## "towers"/"items" -> {head: Label, toggle: Button, box: Control}
var _towers: GridContainer
var _towers_scroll: ScrollContainer
var _towers_key := ""
var _merge: Button
var _roll: Button
var _items: GridContainer
var _items_scroll: ScrollContainer
var _items_key := ""
var _oils: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(10.0, 0.94))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var tbox := _part("towers", v)
	_towers_scroll = _grid_scroll(tbox, ROWS_TOWERS)
	_towers = _towers_scroll.get_child(0)
	_roll = _head_button("towers", "Würfeln", func(): game.submit({"type": "roll"}))
	_roll.tooltip_text = tr("Sechs zufällige Tower der erforschten Elemente ins Lager. Bis der erste Tower steht, darfst du neu würfeln.")
	_merge = _head_button("towers", "6 → 1", func(): _merge_pressed())

	var ibox := _part("items", v)
	_items_scroll = _grid_scroll(ibox, ROWS_ITEMS)
	_items = _items_scroll.get_child(0)
	_oils = _head_button("items", "Öle", func(): game.submit({"type": "oil_merge"}))
	_oils.tooltip_text = tr("Öle kombinieren: alle Öle so oft wie möglich im Würfel destillieren, je 4 gleicher Seltenheit ergeben 1 der nächsten.")
	_apply_parts()
	refresh()


## Kopfzeile mit Titel und Auf-/Zuklappen, darunter der Bereich.
func _part(id: String, v: VBoxContainer) -> VBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle(id))
	v.add_child(head)
	var title := UiUtil.label("", head, 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.heading(title)
	var b := UiUtil.button("–", head, func(): toggle(id))
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 22)
	b.add_theme_font_size_override("font_size", 14)
	# Knöpfe des Lagers in eigener Zeile unter dem Titel (das Lager ist nur 4 Felder breit)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	v.add_child(tools)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	v.add_child(box)
	_parts[id] = {"head": title, "toggle": b, "box": box, "row": head, "tools": tools}
	return box


## Kleiner Knopf in der Zeile unter dem Titel.
func _head_button(id: String, text: String, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, _parts[id].tools, on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 24
	b.add_theme_font_size_override("font_size", 14)
	return b


func _grid_scroll(parent: Control, rows: int) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size = Vector2(COLS * (SLOT + 3), rows * (SLOT + 3))
	parent.add_child(s)
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	s.add_child(g)
	return s


## Tower- oder Item-Lager auf- oder zuklappen.
func toggle(id: String) -> void:
	open[id] = not bool(open.get(id, true))
	_apply_parts()


func _apply_parts() -> void:
	for id in _parts:
		var p: Dictionary = _parts[id]
		var on := bool(open.get(id, true))
		(p.box as Control).visible = on
		(p.toggle as Button).text = "–" if on else "+"
		(p.toggle as Button).tooltip_text = tr("Einklappen") if on else tr("Ausklappen")


func refresh() -> void:
	if game == null or _towers == null:
		return
	visible = game.setup_done
	_roll.visible = not game.is_build_mode() and game.can_reroll
	_roll.disabled = not game.any_element()
	_roll.text = tr("Würfeln") if game.stash.is_empty() else tr("Neu würfeln")
	_refresh_towers()
	_refresh_items()


# --- Tower ------------------------------------------------------------------------

func _refresh_towers() -> void:
	var ids: Array = game.buildable()
	var list := []
	for id in ids:
		list.append([id, game.build_reason(id)])
	var key: String = str(list) + game.build_id
	if key == _towers_key:
		return
	_towers_key = key
	(_parts.towers.head as Label).text = tr("Baumenü") if game.is_build_mode() else tr("Tower-Lager (%d)") % ids.size()
	_clear(_towers)
	var merge: Dictionary = game.merge_option()
	_merge.visible = not game.is_build_mode()
	_merge.disabled = merge.is_empty()
	_merge.tooltip_text = tr("6 Tower gleicher Seltenheit aus dem Lager werden zu 1 zufälligen Tower der nächsten Seltenheit (die ältesten zuerst).") \
			+ ("\n" + tr("Jetzt: 6× %s → 1× %s") % [YoutdData.rarity_name(merge.from), YoutdData.rarity_name(merge.to)] if not merge.is_empty()
			else "\n" + tr("Noch keine 6 Tower gleicher Seltenheit."))
	if list.is_empty():
		var hint := UiUtil.wrap_label(tr("Erforsche zuerst ein Element.") if not game.any_element()
				else tr("Nach jeder Welle kommen neue Tower dazu."), _towers, COLS * SLOT)
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	for entry in list:
		var id: String = entry[0]
		var t := YoutdData.tower(id)
		var s := YoutdSlot.new(YoutdData.tower_icon(id), YoutdData.rarity_color(str(t.get("rarity", "common"))), SLOT)
		s.set_marked(game.build_id == id, entry[1] != "")
		s.set_roles(YoutdData.tower_roles(id))
		s.tooltip_text = YoutdPanel.tower_tip(id) + ("\n" + s.roles_text() if s.roles_text() != "" else "") \
				+ ("\n" + str(entry[1]) if entry[1] != "" else "\n" + tr("Klick: bauen"))
		s.clicked.connect(func(button):
			if button == MOUSE_BUTTON_LEFT:
				game.choose_build(id))
		_towers.add_child(s)


func _merge_pressed() -> void:
	var m: Dictionary = game.merge_option()
	if not m.is_empty():
		game.submit({"type": "tower_merge", "rarity": m.from})


# --- Items ------------------------------------------------------------------------

## Lager neu zeichnen (Item gefunden, eingelegt, verwandelt).
func items_dirty() -> void:
	_items_key = ""


func _refresh_items() -> void:
	var key: String = str(game.item_stash.map(func(it): return [it.get_uid(), game.item_label(it), it.horadric_lock])) + str(game.picked_item)
	if key == _items_key:
		return
	_items_key = key
	(_parts.items.head as Label).text = tr("Item-Lager (%d)") % game.item_stash.size()
	_clear(_items)
	_oils.disabled = not game.can_merge_oils()
	var n: int = game.item_stash.size()
	var total := maxi(COLS * ROWS_ITEMS, ceili((n + 1) / float(COLS)) * COLS)
	for i in total:
		var s := InvSlot.new(SLOT)
		var loc := {"stash": -1}
		if i < n:
			var it: YtItem = game.item_stash[i]
			var d := YoutdData.item(str(it.get_id()))
			loc = {"stash": it.get_uid()}
			s.show_item(YoutdData.item_icon(str(it.get_id())), YoutdData.rarity_color(str(d.get("rarity", "common"))), it.is_consumable() or it.is_oil())
			s.set_count(str(it.get_charges()) if it.uses_charges() else "")
			s.set_marked(game.picked_item == i, it.horadric_lock)
			s.drag_data = {"inv": true, "from": loc}
			var use := tr("Klick: benutzen (wird verbraucht)") if it.is_consumable() \
					else (tr("Auf einen Tower ziehen: Öl wirkt dauerhaft und wird verbraucht") if it.is_oil()
					else tr("Auf einen Tower ziehen oder anklicken und dann den Tower"))
			s.tooltip_text = YoutdPanel.item_tip_for(it) + "\n" + use + "\n" + tr("Auf ein anderes Item ziehen: tauschen") \
					+ "\n" + (tr("Rechtsklick: für Rezepte freigeben") if it.horadric_lock else tr("Rechtsklick: für Rezepte sperren"))
			s.clicked.connect(func(button): _item_clicked(it, button))
		s.on_drop = func(data): game.submit({"type": "item_move", "from": data.from, "to": loc})
		_items.add_child(s)


func _item_clicked(it: YtItem, button: int) -> void:
	var i: int = game.item_stash.find(it)
	if i < 0:
		return
	if button == MOUSE_BUTTON_RIGHT:
		game.submit({"type": "item_lock", "uid": it.get_uid()})
		items_dirty()
		return
	game.pick_item(i)


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
