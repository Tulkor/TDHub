class_name TowerList
extends PanelContainer
## Tower-Liste rechts unter dem Gegner-Fenster: alle fertigen Tower auf dem Feld, scrollbar und sortierbar.
## Klick wählt den Tower aus, Doppelklick fährt die Kamera hin. Einklappbar.
## Tower, die mit anderen fertigen Towern auf dem Feld ein Rezept ergeben, haben einen hellblau unterstrichenen Namen.

const SORTS := [["group", "Nach Sorte"], ["damage", "Sortieren: Schaden"], ["kills", "Sortieren: Kills"], ["name", "Sortieren: Name"]]

var game  # game.gd
var above: Control:  ## sitzt darunter (Gegner-Fenster oder DPS-Meter)
	set(v):
		above = v
		# Sofort nachziehen, wenn das Fenster darüber wächst (sonst liegt es einen Frame lang darüber)
		if v != null:
			v.item_rect_changed.connect(func(): offset_top = (above.get_rect().end.y if above.visible else above.offset_top) + 12)
var tabs: SideTabs  ## Reiter der rechten Spalte (hud.side_tabs)
var limits: Array[Control] = []  ## endet darüber (Auswahlkarte unten, Mitspieler-Liste), solange die sichtbar sind
var sort := "group"  ## "group": eine Zeile je Sorte mit Anzahl, Klick wählt reihum den nächsten dieser Sorte
var _groups := {}  ## sort "group": Name -> Tower dieser Sorte (stärkster zuerst)
var summary: Label
var fold: Button
var body: VBoxContainer
var select: OptionButton
var scroll: ScrollContainer
var list: VBoxContainer
var rows := {}  ## instance_id -> {button, name, kills, damage, tower}

var _refresh_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 1.0
	anchor_right = 1.0
	offset_right = -16
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size.x = 280
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiTheme.panel(12.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title := UiUtil.label("Tower", head, 16)
	UiTheme.heading(title, UiTheme.CYAN)
	summary = UiUtil.label("", head, 12)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.add_theme_color_override("font_color", UiTheme.MUTED)
	fold = Button.new()
	fold.text = "–"
	fold.focus_mode = Control.FOCUS_NONE
	fold.tooltip_text = "Ein-/ausklappen"
	fold.pressed.connect(toggle)
	head.add_child(fold)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	v.add_child(body)
	select = OptionButton.new()
	select.focus_mode = Control.FOCUS_NONE
	select.add_theme_font_size_override("font_size", 12)
	for s in SORTS:
		select.add_item(s[1])
	select.item_selected.connect(func(i):
		sort = SORTS[i][0]
		refresh())
	body.add_child(select)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 60
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	refresh()


func toggle() -> void:
	body.visible = not body.visible
	fold.text = "–" if body.visible else "+"
	refresh()


func _process(delta: float) -> void:
	if above != null:
		offset_top = (above.get_rect().end.y if above.visible else above.offset_top) + 12
	if body.visible:
		# Liste so hoch wie Platz ist: bis zur Auswahlkarte unten oder zum Bildschirmrand
		var bottom_y := get_viewport_rect().size.y - 16.0
		for limit in limits:
			var r := limit.get_global_rect()
			if limit.is_visible_in_tree() and r.end.x > global_position.x and r.position.x < get_global_rect().end.x:
				bottom_y = minf(bottom_y, r.position.y - 12.0)
		var room := clampf(bottom_y - scroll.global_position.y - 14.0, 26.0, 360.0)
		var h := minf(room, list.get_combined_minimum_size().y)
		if absf(scroll.custom_minimum_size.y - h) > 1.0:
			scroll.custom_minimum_size.y = h
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.5
		refresh()


## Fertige Tower auf dem Feld, sortiert nach der gewählten Spalte.
func towers() -> Array:
	if game == null:
		return []
	# eeveTD: Barrikaden sind nur Mauern und stehen nicht in der Liste
	var list_t: Array = game.all_towers().filter(func(t): return is_instance_valid(t) and not t.is_new and not t.def.get("eeve", {}).get("barricade", false) and not t.def.get("eeve", {}).get("market", false))
	if sort == "group":
		list_t.sort_custom(func(a, b): return a.total_damage > b.total_damage if a.total_damage != b.total_damage else a.kills > b.kills)
		_groups = {}
		var reps := []
		for t in list_t:
			var key: String = t.label()
			if not _groups.has(key):
				_groups[key] = []
				reps.append(t)
			_groups[key].append(t)
		reps.sort_custom(func(a, b): return group_damage(a) > group_damage(b))
		return reps
	match sort:
		"kills":
			list_t.sort_custom(func(a, b): return a.kills > b.kills if a.kills != b.kills else a.total_damage > b.total_damage)
		"name":
			list_t.sort_custom(func(a, b): return a.label().naturalnocasecmp_to(b.label()) < 0)
		_:
			list_t.sort_custom(func(a, b): return a.total_damage > b.total_damage if a.total_damage != b.total_damage else a.kills > b.kills)
	return list_t


func refresh() -> void:
	if list == null:
		return
	var ts := towers()
	visible = game != null and not ts.is_empty() and (tabs == null or tabs.shows("tower"))
	_update_summary(ts)
	if not body.visible or ts.is_empty():
		return
	# Zeilen nur für neue Tower bauen, weggefallene entfernen, sonst nur umsortieren und Werte setzen
	var ids := {}
	for t in ts:
		ids[t.get_instance_id()] = true
		if not rows.has(t.get_instance_id()):
			rows[t.get_instance_id()] = _row(t)
	for id in rows.keys():
		if not ids.has(id):
			rows[id].button.queue_free()
			rows.erase(id)
	var sel = game.selected
	var combinable := {}
	for t in ts:
		if not combos(t, ts).is_empty():
			combinable[t] = true
	for i in ts.size():
		var t = ts[i]
		var r: Dictionary = rows[t.get_instance_id()]
		if r.button.get_index() != i:
			list.move_child(r.button, i)
		var group: Array = _groups.get(t.label(), [t]) if sort == "group" else [t]
		r.name.text = t.label() + (" ×%d" % group.size() if group.size() > 1 else "")
		r.gem.add_theme_color_override("font_color", t.color)
		r.kills.text = "✖ %d" % group.reduce(func(a, o): return a + o.kills, 0) if t.can_attack() else "–"
		r.damage.text = DpsMeter._fmt(group_damage(t)) if t.can_attack() else tr("Aura")
		var on: bool = group.has(sel)
		if r.on != on:   # neuer Rahmen nur bei Wechsel der Auswahl, sonst baut jede Zeile alle 0,5 s ihr Layout neu
			r.on = on
			r.button.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_2 if on else UiTheme.BAR, UiTheme.CYAN if on else Color.TRANSPARENT, 0, 2, 4))
		if r.combinable != combinable.has(t):
			r.combinable = combinable.has(t)
			r.name.set_meta("combinable", r.combinable)
			r.name.queue_redraw()


## Schaden aller Tower der Sorte von t (in der Ansicht „Nach Sorte“), sonst nur von t.
func group_damage(t) -> float:
	if sort != "group":
		return t.total_damage
	return _groups.get(t.label(), [t]).reduce(func(a, o): return a + o.total_damage, 0.0)


## Klick auf eine Zeile: ohne Gruppen der Tower selbst, sonst reihum der nächste dieser Sorte.
func next_in_group(t):
	var group: Array = _groups.get(t.label(), []) if sort == "group" else []
	group = group.filter(func(o): return is_instance_valid(o))
	if group.size() <= 1:
		return t
	var i := group.find(game.selected)
	return group[(i + 1) % group.size()] if i >= 0 else group[0]


## Spezial-Tower, die t zusammen mit anderen fertigen Towern auf dem Feld ergeben würde (Namen).
## Kombinieren geht nur während der Welle, markiert wird aber immer, damit man es planen kann.
func combos(t, field: Array = []) -> Array:
	if game == null or not is_instance_valid(t) or t.is_new or str(t.def.get("category", "gem")) == "eeve" \
			or t.tower_id.begins_with("youtd_"):
		return []
	if field.is_empty():
		field = towers()
	var pool := field.filter(func(o): return o != t)
	var out := []
	for sid in Database.special_ids():
		var def: Dictionary = Database.towers[sid]
		if def.get("recipe_same_round", false):
			continue
		if game._match_recipe(def.get("recipe", []), t, pool) != null:
			out.append(Database.tower_label(sid, 0))
	return out


func _update_summary(ts: Array) -> void:
	var text := str(ts.size())
	if not body.visible and not ts.is_empty():
		var best: Array = ts.duplicate()
		best.sort_custom(func(a, b): return a.total_damage > b.total_damage)
		text += " · " + tr("Bester: %s") % best[0].label()
	summary.text = text


func _row(t) -> Dictionary:
	var b := TooltipButton.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 26
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.BAR, Color.TRANSPARENT, 0, 2, 4))
	b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_2, UiTheme.GOLD, 0, 2, 4))
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PANEL_2, UiTheme.CYAN, 0, 2, 4))
	b.tooltip_text = " "  # ohne Text kein Tooltip; der eigentliche kommt aus _tooltip
	b.make = _tooltip.bind(t)
	b.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and is_instance_valid(t):
			var pick = next_in_group(t)
			game._select(pick)
			if ev.double_click:
				focus(pick)
			refresh())
	list.add_child(b)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	b.add_child(h)
	var gem := UiUtil.label("◆", h, 12)
	gem.add_theme_color_override("font_color", t.color)
	var n := UiUtil.label(t.label(), h, 12)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.draw.connect(_draw_underline.bind(n))
	var k := UiUtil.label("", h, 11)
	k.custom_minimum_size.x = 38
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	k.add_theme_color_override("font_color", UiTheme.MUTED)
	var d := UiUtil.label("", h, 12)
	d.custom_minimum_size.x = 42
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.add_theme_color_override("font_color", UiTheme.COIN)
	for c in h.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return {"button": b, "gem": gem, "name": n, "kills": k, "damage": d, "combinable": false, "on": null}


## Kombinierbar: Name hellblau unterstrichen, so breit wie der sichtbare Text.
func _draw_underline(n: Label) -> void:
	if not n.get_meta("combinable", false):
		return
	var font := n.get_theme_font("font")
	var fs := n.get_theme_font_size("font_size")
	var w := minf(font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, n.size.x)
	var y := minf((n.size.y + font.get_height(fs)) * 0.5, n.size.y - 2.0)  # clip_text schneidet alles außerhalb ab
	n.draw_rect(Rect2(0, y, w, 2), UiTheme.CYAN)


## Kamera auf den Tower fahren.
func focus(t) -> void:
	var rig = game.camera_rig
	if rig == null:
		return
	rig.target = Vector3(t.position.x, rig.target.y, t.position.z)
	rig._clamp_target()
	rig._apply()


func _tooltip(t) -> Control:
	if not is_instance_valid(t):
		return null
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size.x = 250
	UiTheme.title(UiUtil.label(t.label(), v, 15))
	for row in [[tr("Kills"), str(t.kills), UiTheme.TEXT], [tr("Schaden gesamt"), DpsMeter._fmt(t.total_damage), UiTheme.COIN]]:
		var h := HBoxContainer.new()
		v.add_child(h)
		var l := UiUtil.label(row[0], h, 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", UiTheme.DIM)
		UiUtil.label(row[1], h, 13).add_theme_color_override("font_color", row[2])
	var made := combos(t)
	if not made.is_empty():
		var c := UiUtil.wrap_label(tr("Kombinierbar zu: %s") % ", ".join(made), v, 250)
		c.add_theme_font_size_override("font_size", 12)
		c.add_theme_color_override("font_color", UiTheme.CYAN_TEXT)
		if not game.is_wave_running():
			var w := UiUtil.wrap_label(tr("Kombinieren geht erst wieder während der Welle."), v, 250)
			w.add_theme_font_size_override("font_size", 12)
			w.add_theme_color_override("font_color", UiTheme.MUTED)
	var note := UiUtil.wrap_label(tr("Klick wählt den Tower aus, Doppelklick fährt die Kamera hin."), v, 250)
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UiTheme.MUTED)
	return v
