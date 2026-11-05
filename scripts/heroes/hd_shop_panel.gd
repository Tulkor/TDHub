class_name HdShopUi
extends Control
## Wirtschafts-Oberfläche von Bollwerk im Arcade-Stil (UiTheme), Teil von HdHud:
## - Inventarleiste unten rechts: Gold, Holz, 6 Heldenplätze (gemeinsames Inventar InvSlot: ziehen =
##   tauschen, Klick auf Trank = benutzen), Knopf Shop (B).
## - Straßenleiste oben links: aktive Straßen mit Vorwerk/Innentor und Gegnerzahl, Teleport-Fortschritt.
## - Shop-Fenster links (Spiel läuft weiter): Grundwaren, Rüstkammer, Rezeptmeister (Rezeptbaum mit
##   HAVE/MISSING), Holzwerte, Torwerke; darunter das Lager (12 Plätze) und ein Feld zum Verkaufen.
## Alle Aktionen gehen über HdShop.act(cmd).

const SLOT := 46.0

var game  ## HdGame
var shop: HdShop
var tab := "grund"
var picked := ""                 ## im Shop gewähltes Item (Rezeptbaum)
var _inv_slots: Array = []       ## InvSlot ×6
var _stash_slots: Array = []     ## InvSlot ×12
var _gold: Label
var _wood: Label
var _where: Label
var _roads: VBoxContainer
var _road_rows: Array = []       ## {road, label}
var _tp: Label
var _window: PanelContainer
var _tabs: HBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _note: Label
var _sig := ""


func _init(g) -> void:
	game = g
	shop = g.shop
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build_bar()
	_build_roads()
	_build_window()
	_window.visible = false


func _panel(parent: Node, pad := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(pad))
	parent.add_child(p)
	return p


func _label(text: String, parent: Node, size := 14, color := UiTheme.TEXT, bold := false) -> Label:
	var l := UiUtil.label(text, parent, size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	return l


# ---------------------------------------------------------------- Inventarleiste

func _build_bar() -> void:
	var p := _panel(self, 10)
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -14
	p.offset_bottom = -14
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_gold = _label("", row, 16, UiTheme.COIN, true)
	_wood = _label("", row, 16, UiTheme.HAVE, true)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for i in int(game.cfg.economy.slots):
		var s := InvSlot.new(SLOT)
		grid.add_child(s)
		_inv_slots.append(s)
		var k := i
		s.clicked.connect(func(btn): _slot_clicked("hero", k, btn))
		s.on_drop = func(data): _drop(data, "hero", k)
	_where = _label("", v, 11, UiTheme.MUTED)
	var b := UiUtil.button("Shop [B]", v, toggle)
	UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.GOLD_DARK)


func _paint(s: InvSlot, entry, where: String, i: int) -> void:
	for c in s.get_children():
		c.queue_free()
	s.icon_node = null
	s.texture = null
	s.abbr = ""
	s.count = ""
	s.marked = false
	s.dimmed = false
	s.border = Color.TRANSPARENT
	if entry == null:
		s.state = InvSlot.State.FREE
		s.drag_data = null
		s.tooltip_text = ""
		s.queue_redraw()
		return
	s.show_abbr(tr(str(shop.item(entry.id).name)), shop.tier_color(entry.id))
	s.consumable = shop.consumable(entry.id)
	if shop.item(entry.id).has("stack"):
		s.set_count(str(int(entry.n)))
	s.drag_data = {"inv": true, "where": where, "i": i}
	var tip := shop.tooltip(entry.id, entry)
	if int(entry.get("up", 0)) > 0:
		s.set_count("+%d" % int(entry.up))
	if where == "hero" and s.consumable:
		tip += "\n" + tr("Klick: benutzen")
	s.tooltip_text = tip


func _slot_clicked(where: String, i: int, btn: int) -> void:
	var x = shop.at(where, i)
	if x == null:
		return
	if btn == MOUSE_BUTTON_LEFT and where == "hero" and shop.consumable(x.id):
		_say(shop.act({"kind": "use", "i": i}))
	elif btn == MOUSE_BUTTON_LEFT and shop.item(x.id).size() > 0:
		picked = x.id
		if _window.visible:
			_rebuild(true)


func _drop(data: Dictionary, where: String, i: int) -> void:
	_say(shop.act({"kind": "move", "from": data.where, "fi": int(data.i), "to": where, "ti": i}))


func _say(why: String) -> void:
	if why != "" and why != "?":
		game.message.emit(why)


# ---------------------------------------------------------------- Straßenleiste

func _build_roads() -> void:
	var p := _panel(self, 8)
	p.position = Vector2(12, 92)
	_roads = VBoxContainer.new()
	_roads.add_theme_constant_override("separation", 2)
	p.add_child(_roads)
	UiTheme.caption("Straßen", _roads)
	for r in game.roads:
		_road_rows.append({"road": r, "label": _label("", _roads, 12, UiTheme.TEXT)})
	_tp = _label("", _roads, 12, UiTheme.PURPLE_LIGHT, true)


func _gate_text(g) -> String:
	if g == null:
		return "–"
	if g.destroyed:
		return tr("gefallen")
	return "%d %%" % roundi(g.hp / g.max_hp * 100.0)


func _update_roads() -> void:
	if _road_rows.size() != game.roads.size():
		for row in _road_rows:
			row.label.queue_free()
		_road_rows.clear()
		for r in game.roads:
			var l := _label("", _roads, 12, UiTheme.TEXT)
			_roads.move_child(l, _roads.get_child_count() - 2)
			_road_rows.append({"road": r, "label": l})
	var counts := {}
	for e in game.enemies:
		if not e.dead and e.zone == "":
			counts[e.road] = int(counts.get(e.road, 0)) + 1
	for row in _road_rows:
		var r: HdRoad = row.road
		var n := int(counts.get(r, 0))
		var hurt: bool = r.gate("vorwerk").destroyed
		row.label.text = tr("%s · Vorwerk %s · Innentor %s · %d Gegner") % [tr(r.name), _gate_text(r.gate("vorwerk")),
			_gate_text(r.gate("innentor")), n]
		row.label.add_theme_color_override("font_color", UiTheme.MISSING if hurt else (UiTheme.GOLD if n > 0 else UiTheme.TEXT))
	if not game.tp_stone.is_empty():
		var hold := float(game.cfg.arena.teleport.get("hold", 0.8))
		var dest: String = tr("zur Feste")
		if game.tp_stone.has("zone"):
			dest = tr("zur Sonderzone %s") % tr(str(game.zones.def(str(game.tp_stone.zone)).name)) if game.tp_stone.out else tr("zur Feste")
		elif game.tp_stone.out:
			dest = tr("zur %s") % tr(game.tp_stone.road.name)
		_tp.text = tr("Teleport %s %d %%") % [dest, roundi(clampf(game.tp_hold / hold, 0, 1) * 100.0)]
	else:
		_tp.text = ""


# ---------------------------------------------------------------- Shop-Fenster

func _build_window() -> void:
	_window = _panel(self, 14)
	_window.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_window.offset_left = 12
	_window.offset_top = 92
	_window.offset_bottom = -150
	_window.custom_minimum_size.x = 500
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_window.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = tr("Shop der Feste")
	UiTheme.title(t, 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	UiUtil.button("✕", head, toggle)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	v.add_child(_tabs)
	for sh in shop.cfg.shops:
		var id := str(sh.id)
		var b := UiUtil.button(str(sh.name), _tabs, func():
			tab = id
			_rebuild(true))
		b.set_meta("tab", id)
		b.add_theme_font_size_override("font_size", 12)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	v.add_child(_detail)
	_note = _label("", v, 12, UiTheme.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.caption("Lager in der Feste", v)
	var sg := HBoxContainer.new()
	sg.add_theme_constant_override("separation", 10)
	v.add_child(sg)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	sg.add_child(grid)
	for i in int(game.cfg.economy.stash):
		var s := InvSlot.new(40.0)
		grid.add_child(s)
		_stash_slots.append(s)
		var k := i
		s.clicked.connect(func(btn): _slot_clicked("stash", k, btn))
		s.on_drop = func(data): _drop(data, "stash", k)
	var sell := InvSlot.new(56.0)
	sell.abbr = ""
	sell.tooltip_text = tr("Item hierher ziehen: verkaufen")
	sell.on_drop = func(data): _say(shop.act({"kind": "sell", "where": data.where, "i": int(data.i)}))
	var sv := VBoxContainer.new()
	sg.add_child(sv)
	sv.add_child(sell)
	_label(tr("Verkaufen"), sv, 11, UiTheme.MUTED)


func toggle() -> void:
	_window.visible = not _window.visible
	if _window.visible:
		_rebuild(true)


func is_open() -> bool:
	return _window.visible


## Alles neu aufbauen, wenn sich am Wirtschaftsstand etwas geändert hat (oder force).
func _rebuild(force := false) -> void:
	var sig := "%s|%d|%d|%d|%d|%s|%s|%s|%s|%s" % [tab, shop.gold, shop.wood, shop.trophies, shop.marks, str(shop.inv), str(shop.stash), shop.in_fortress(), picked, _gate_sig()]
	if sig == _sig and not force:
		return
	_sig = sig
	for b in _tabs.get_children():
		var on: bool = b.get_meta("tab") == tab
		b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN) if on else UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER))
		b.add_theme_color_override("font_color", UiTheme.BG if on else UiTheme.TEXT)
	for c in _list.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	match tab:
		"holz":
			_fill_wood()
		"tore":
			_fill_gates()
		"trophae":
			_label(tr("Trophäen %d · Arena-Marken %d. Jeder Kriegsherr lässt eine Trophäe fallen, jeder Arena-Sieg eine Marke.") % [shop.trophies, shop.marks],
				_list, 12, UiTheme.DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			for id in shop.shop_items(tab):
				_item_row(id)
		_:
			for id in shop.shop_items(tab):
				_item_row(id)
			if picked != "":
				_fill_tree(picked)
	_note.text = tr("In der Feste: Käufe kommen direkt ins Inventar.") if shop.in_fortress() \
		else tr("Fernkauf: außerhalb der Feste landen Käufe im Lager. Lager ↔ Held nur in der Feste.")


func _gate_sig() -> String:
	if tab != "tore":
		return ""
	var out := ""
	for g in game.buildings:
		out += "%d%s%s" % [roundi(g.hp / 50.0), g.destroyed, shop.can_repair(g)]
	return out


func _row_box(sel := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.CYAN if sel else UiTheme.BORDER, 0, 2, 6))
	_list.add_child(p)
	return p


func _item_row(id: String) -> void:
	var it := shop.item(id)
	var p := _row_box(id == picked)
	p.tooltip_text = shop.tooltip(id)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked = "" if picked == id else id
			_rebuild(true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	_label(tr(str(it.name)), v, 14, shop.tier_color(id), true)
	var info := _label(shop.stat_text(it.get("stats", {})) if it.has("stats") else tr(str(it.get("desc", ""))), v, 11, UiTheme.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if it.has("recipe"):
		var parts: Array = []
		var miss := shop.missing(id)
		var left := miss.duplicate()
		for c in it.recipe:
			var have := not left.has(c)
			if not have:
				left.erase(c)
			parts.append("[color=#%s]%s[/color]" % [(UiTheme.HAVE if have else UiTheme.MISSING).to_html(false), tr(str(shop.item(c).name))])
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.add_theme_font_size_override("normal_font_size", 11)
		rt.text = " + ".join(parts) + " + %d %s" % [int(it.price), tr("Gold")]
		v.add_child(rt)
		var why := shop.can_craft(id)
		if miss.is_empty():
			var b := UiUtil.button(tr("Schmieden %d") % int(it.price), h, func(): _say(shop.act({"kind": "craft", "id": id})))
			b.disabled = why != ""
			if why == "":
				UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.GOLD_DARK)
		else:
			var cost := shop.craft_cost(id, true)
			var b := UiUtil.button(tr("Mit Teilen %d") % cost, h, func(): _say(shop.act({"kind": "craft", "id": id, "buy_missing": true})))
			b.disabled = shop.can_craft(id, true) != ""
			b.tooltip_text = tr("Kauft die fehlenden Teile mit und schmiedet sofort")
	else:
		var b := UiUtil.button(shop.price_text(id), h, func(): _say(shop.act({"kind": "buy", "id": id})))
		b.disabled = shop.can_buy(id) != ""
		b.tooltip_text = shop.can_buy(id)
		b.custom_minimum_size.x = 92


## Rezeptbaum des gewählten Items: woraus es entsteht und wohinein es geht.
func _fill_tree(id: String) -> void:
	var it := shop.item(id)
	UiTheme.caption(tr("Rezeptbaum: %s") % tr(str(it.name)), _detail)
	if it.has("recipe"):
		var parts: Array = []
		var left := shop.missing(id)
		for c in it.recipe:
			var have := not left.has(c)
			if not have:
				left.erase(c)
			parts.append((tr("✓ %s") if have else tr("✗ %s")) % tr(str(shop.item(c).name)))
		_label(tr("Aus: %s") % ", ".join(parts), _detail, 12, UiTheme.TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ups: Array = []
	for u in shop.used_in.get(id, []):
		ups.append(tr(str(shop.item(u).name)))
	if not ups.is_empty():
		_label(tr("Wird zu: %s") % ", ".join(ups), _detail, 12, UiTheme.CYAN).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif not it.has("use"):
		_label(tr("Endstufe"), _detail, 12, UiTheme.COIN)


func _fill_wood() -> void:
	_label(tr("Holz kauft dauerhafte Werte für diesen Run. Jeder Kauf macht den Wert teurer."), _list, 12, UiTheme.DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for s in shop.cfg.wood.stats:
		var id := str(s.id)
		var p := _row_box()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_label("%s  ×%d" % [tr(str(s.name)), int(shop.wood_bought.get(id, 0))], v, 14, UiTheme.HAVE, true)
		_label(shop.stat_text(s.stats), v, 11, UiTheme.DIM)
		var price := shop.wood_price(id)
		var b := UiUtil.button(tr("%d Holz") % price, h, func(): _say(shop.act({"kind": "wood", "id": id})))
		b.disabled = shop.wood < price
		b.custom_minimum_size.x = 92


func _fill_gates() -> void:
	_label(tr("Reparieren geht, wenn keine Gegner in der Nähe des Torwerks sind. Fällt das Vorwerk, laufen die Gegner dieser Straße schneller."), _list, 12, UiTheme.DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for g in game.buildings:
		if g.road == null:
			continue
		var p := _row_box()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_label(g.label(), v, 14, UiTheme.MISSING if g.destroyed else UiTheme.TEXT, true)
		_label(tr("gefallen") if g.destroyed else "%d / %d" % [roundi(g.hp), roundi(g.max_hp)], v, 11, UiTheme.DIM)
		var why := shop.can_repair(g)
		var cost := shop.repair_cost(g)
		var text := (tr("Neu bauen %d") if g.destroyed else tr("Reparieren %d")) % cost
		var gate = g
		var b := UiUtil.button(text if why != tr("Unbeschädigt") else tr("Unbeschädigt"), h, func(): _say(shop.act({"kind": "repair", "gate": gate})))
		b.disabled = why != ""
		b.tooltip_text = why
		b.custom_minimum_size.x = 132


# ---------------------------------------------------------------- Takt

func refresh() -> void:
	_gold.text = tr("%d Gold") % shop.gold
	_wood.text = tr("%d Holz") % shop.wood
	_where.text = tr("In der Feste") if shop.in_fortress() else tr("Unterwegs: Käufe ins Lager")
	for i in _inv_slots.size():
		_paint(_inv_slots[i], shop.inv[i], "hero", i)
	for i in _stash_slots.size():
		_paint(_stash_slots[i], shop.stash[i], "stash", i)
	_update_roads()
	_roads.get_parent().visible = not _window.visible
	if _window.visible:
		_rebuild()
