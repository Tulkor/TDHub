class_name HdShopUi
extends Control
## Wirtschafts-Oberfläche von Bollwerk in Eisenliturgie (UiTheme), Teil von HdHud:
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
var _road_rows: Array = []       ## {road, row, name, outer, inner, count}
var _roads_open := false         ## Straßenleiste standardmäßig eingeklappt (Lukas 2026-11-25)
var _roads_toggle: Button
var _roads_summary: Label
var _tp: Label
var _window: PanelContainer
var _tabs: HBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _note: Label
var _sig := ""
var _resource_panel: PanelContainer
var _inventory_panel: PanelContainer
var _roads_panel: PanelContainer
var _clock: Label


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
	_inventory_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	UiTheme.caption("Inventar", v).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resource_panel = _panel(self, 9)
	var resources := VBoxContainer.new()
	resources.add_theme_constant_override("separation", 5)
	_resource_panel.add_child(resources)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	resources.add_child(row)
	_gold = _label("", row, 14, UiTheme.COIN, true)
	_wood = _label("", row, 14, UiTheme.HAVE, true)
	_clock = _label("", resources, 12, UiTheme.MUTED)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := UiUtil.button("Shop [B]", v, toggle)
	UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.GOLD_DARK)


func _paint(s: InvSlot, entry, where: String, i: int) -> void:
	for c in s.get_children():
		if c.has_meta("bollwerk_metal_layer"):continue
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
	s.show_item(preload("res://scripts/heroes/hd_item_icons.gd").texture(str(entry.id)), shop.tier_color(entry.id),shop.item(entry.id).get("consumable",false))
	s.consumable = shop.consumable(entry.id)
	if shop.item(entry.id).has("stack"):
		s.set_count(str(int(entry.n)))
	s.drag_data = {"inv": true, "where": where, "i": i}
	var tip := shop.tooltip(entry.id, entry)
	if int(entry.get("up", 0)) > 0:
		s.set_count("+%d" % int(entry.up))
	if where == "hero" and shop.usable(entry.id):
		tip += "\n" + tr("F%d oder Klick: benutzen") % (i + 1)
		if shop.item(entry.id).has("active"):
			var remaining: float = game.hero.ITEM_EFFECTS.active_left(game.hero, shop.item(entry.id))
			s.dimmed = remaining > 0
			if remaining > 0:
				s.set_count(str(ceili(remaining)))
				tip += "\n" + tr("Item-Abklingzeit: %d s") % ceili(remaining)
	s.tooltip_text = tip


func _slot_clicked(where: String, i: int, btn: int) -> void:
	var x = shop.at(where, i)
	if x == null:
		return
	if btn == MOUSE_BUTTON_LEFT and where == "hero" and shop.usable(x.id):
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
	_roads_panel = p
	p.position = Vector2(16, 190)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	p.add_child(box)
	# Kopf zum Auf- und Zuklappen; eingeklappt steht nur eine Zusammenfassung da.
	_roads_toggle = Button.new()
	_roads_toggle.focus_mode = Control.FOCUS_NONE
	_roads_toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_roads_toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_roads_toggle.add_theme_font_override("font", UiTheme.font(true))
	_roads_toggle.add_theme_font_size_override("font_size", 12)
	_roads_toggle.pressed.connect(func():
		_roads_open = not _roads_open
		_update_roads()
		_roads_panel.reset_size.call_deferred())
	box.add_child(_roads_toggle)
	_roads_summary = _label("", box, 11, UiTheme.MUTED)
	_roads_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roads = VBoxContainer.new()
	_roads.add_theme_constant_override("separation", 3)
	box.add_child(_roads)
	_tp = _label("", box, 12, UiTheme.PURPLE_LIGHT, true)
	_tp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tp.custom_minimum_size.x = 200


## Eine Straßenzeile: Name, zwei kleine Torbalken (Vorwerk, Innentor) und die Zahl der Gegner.
func _road_row(r: HdRoad) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_roads.add_child(row)
	var name_label := _label("", row, 11, UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	var bars: Array = []
	for i in 2:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(38, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		HdUiStyle.bar_styles(bar, UiTheme.HAVE)
		row.add_child(bar)
		bars.append(bar)
	var count := _label("", row, 11, UiTheme.MUTED, true)
	count.custom_minimum_size.x = 20
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return {"road": r, "row": row, "name": name_label, "outer": bars[0], "inner": bars[1], "count": count}


func _gate_text(g) -> String:
	if g == null:
		return "–"
	if g.destroyed:
		return tr("gefallen")
	return "%d %%" % roundi(g.hp / g.max_hp * 100.0)


func _update_roads() -> void:
	if _road_rows.map(func(row): return row.road) != game.roads:
		for row in _road_rows:
			row.row.queue_free()
		_road_rows.clear()
		for r in game.roads:
			_road_rows.append(_road_row(r))
	var counts := {}
	for e in game.enemies:
		if not e.dead and e.zone == "":
			counts[e.road] = int(counts.get(e.road, 0)) + 1
	var total := 0
	var hurt_gates := 0
	for row in _road_rows:
		var r: HdRoad = row.road
		var n := int(counts.get(r, 0))
		total += n
		row.name.text = tr(r.name)
		row.name.add_theme_color_override("font_color", UiTheme.MISSING if r.gate("vorwerk") != null and r.gate("vorwerk").destroyed else (UiTheme.GOLD if n > 0 else UiTheme.TEXT))
		for pair in [[row.outer, r.gate("vorwerk")], [row.inner, r.gate("innentor")]]:
			var bar: ProgressBar = pair[0]
			var g = pair[1]
			var share := 0.0 if g == null or g.destroyed else clampf(g.hp / g.max_hp, 0.0, 1.0)
			if g != null and (g.destroyed or share < 0.999):
				hurt_gates += 1
			bar.value = share
			var fill: StyleBox = bar.get_theme_stylebox("fill")
			var color: Color = UiTheme.HAVE if share > 0.5 else (UiTheme.COIN if share > 0.0 else UiTheme.MISSING)
			if fill is HdUiStyle.BarFrame and fill.fill != color:
				fill.fill = color
				bar.queue_redraw()
		row.count.text = str(n) if n > 0 else "·"
		row.count.add_theme_color_override("font_color", UiTheme.GOLD if n > 0 else UiTheme.MUTED)
		row.row.tooltip_text = tr("%s · Vorwerk %s · Innentor %s · %d Gegner") % [tr(r.name), _gate_text(r.gate("vorwerk")), _gate_text(r.gate("innentor")), n]
	_roads_toggle.text = tr("Straßen") + ("  ▾" if _roads_open else "  ▸")
	_roads.visible = _roads_open
	_roads_summary.visible = not _roads_open
	_roads_summary.text = tr("%d Straßen · %d Gegner · %d Tore beschädigt") % [_road_rows.size(), total, hurt_gates]
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
	_tp.visible = _tp.text != ""


func fit_layout(area: Vector2) -> void:
	if _inventory_panel == null:
		return
	# Fenster so klein wie ihr Inhalt (Lukas 2026-11-25), rechts bündig am Rand.
	_inventory_panel.size = Vector2.ZERO
	var inv := _inventory_panel.get_combined_minimum_size()
	_inventory_panel.position = Vector2(area.x - inv.x - 16, area.y - inv.y - 39)
	_resource_panel.size = Vector2.ZERO
	_resource_panel.position = Vector2(area.x - _resource_panel.get_combined_minimum_size().x - 16, 68)
	_roads_panel.size = Vector2.ZERO
	_roads_panel.position = Vector2(16, 190)
	_window.offset_top = 190
	_window.offset_bottom = -190


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
	var close := UiUtil.button("✕", head, toggle)
	HdUiStyle.symbol_button(close, "x")
	close.custom_minimum_size = Vector2(32, 32)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.tooltip_text = tr("Schließen")
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
		b.size_flags_vertical = Control.SIZE_SHRINK_END
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
		# Reiter: oben abgeschrägt, der aktive höher mit Goldschrift (Bollwerk-Baukasten 2026-11-25).
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := HdUiStyle.tab_style(on)
			if state.begins_with("hover") and not on:
				style.line = UiTheme.GOLD
			b.add_theme_stylebox_override(state, style)
		b.add_theme_color_override("font_color", HdUiStyle.GOLD_HI if on else UiTheme.MUTED.darkened(0.3))
		b.set_meta("metal_text_color", HdUiStyle.GOLD_HI if on else UiTheme.MUTED.darkened(0.3))
		b.queue_redraw()
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
	# Bild im selben gefassten Steckplatz wie im Inventar (Stein in Seltenheitsfarbe).
	var icon := InvSlot.new(46.0)
	icon.show_item(preload("res://scripts/heroes/hd_item_icons.gd").texture(id), shop.tier_color(id))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	_label(tr(str(it.name)), v, 14, shop.tier_color(id), true)
	var info := _label(shop.stat_text(it.get("stats", {})) if it.has("stats") else tr(str(it.get("desc", ""))), v, 11, UiTheme.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var effect := str(it.get("effect_desc", ""))
	if it.has("active"):
		effect = tr("Aktiv: %s · %d s Abklingzeit") % [tr(str(it.active.desc)), int(it.active.cooldown)]
	elif bool(it.get("scepter", false)):
		effect = tr("Szepter: %s") % tr(str(game.hero.def.get("scepter", {}).get("desc", "")))
	elif effect == "" and float(it.get("stats", {}).get("mastery", 0)) > 0:
		effect = str(game.hero.def.get("mastery", {}).get("name", ""))
	if effect != "":
		_label(tr(effect), v, 13, UiTheme.TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var hour: float = game.time_of_day()
	_clock.text = "%02d:%02d · %s" % [int(hour), int(fmod(hour, 1.0) * 60), tr("Nacht") if game.is_night() else tr("Tag")]
	_where.text = tr("In der Feste") if shop.in_fortress() else tr("Unterwegs: Käufe ins Lager")
	for i in _inv_slots.size():
		_paint(_inv_slots[i], shop.inv[i], "hero", i)
	for i in _stash_slots.size():
		_paint(_stash_slots[i], shop.stash[i], "stash", i)
	_update_roads()
	_roads.get_parent().visible = not _window.visible and not game.final.active and not game.event_arena.active
	if _window.visible:
		_rebuild()
