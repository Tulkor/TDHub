class_name RunHistoryPanel
extends VBoxContainer
## Run-History im Hauptmenü (rechte Seite statt der Map-Auswahl): links alle Läufe, rechts die Details
## des gewählten Laufs. Daten aus RunHistory (user://run_history.json).

signal replay_requested(run: Dictionary)

const FILTERS := [["all", "Alle"], ["lives", "Leben"], ["score", "Punkte"]]
const TYPE_ORDER := ["Boden", "Gemischt", "Masse", "Flieger", "Boss"]

var runs: Array = []
var filter := "all"
var selected := 0  ## Index in runs
var stats_label: Label
var list: VBoxContainer
var detail: VBoxContainer
var detail_panel: PanelContainer
var empty: Label
var _confirm_delete := false


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	# Titel steht in der Kopfzeile der Seite (main_menu.gd)
	var t := Control.new()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var group := ButtonGroup.new()
	for f in FILTERS:
		var key: String = f[0]
		var b := UiUtil.button(f[1], head, func():
			filter = key
			selected = _visible_indices()[0] if not _visible_indices().is_empty() else 0
			_rebuild())
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("pressed", DecoTheme.box(DecoTheme.CYAN, DecoTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", DecoTheme.GOLD_DARK)
		b.set_pressed_no_signal(key == filter)
	stats_label = UiUtil.label("", self, 15)
	stats_label.add_theme_color_override("font_color", DecoTheme.MUTED)
	empty = UiUtil.wrap_label("Noch keine Läufe. Spiel eine Runde, dann steht sie hier.", self, 500)
	empty.add_theme_color_override("font_color", DecoTheme.MUTED)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 360
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	detail_panel = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", DecoTheme.panel(16.0))
	row.add_child(detail_panel)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(dscroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	dscroll.add_child(detail)
	reload()


func reload() -> void:
	runs = RunHistory.load_runs()
	selected = clampi(selected, 0, maxi(runs.size() - 1, 0))
	_rebuild()


func _visible_indices() -> Array:
	var out := []
	for i in runs.size():
		var sm := bool(runs[i].get("score_mode", false))
		if filter == "all" or (filter == "score") == sm:
			out.append(i)
	return out


func _rebuild() -> void:
	var idx := _visible_indices()
	var wins := runs.filter(func(r): return r.get("victory", false) and not r.get("score_mode", false)).size()
	var best := 0
	for r in runs:
		if r.get("score_mode", false):
			best = maxi(best, int(r.get("score", 0)))
	stats_label.text = tr("%d Läufe · %d gewonnen") % [runs.size(), wins] + (" · " + tr("bester Punktestand %s") % _num(best) if best > 0 else "")
	empty.visible = idx.is_empty()
	detail_panel.visible = not idx.is_empty()
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	if idx.is_empty():
		return
	if not idx.has(selected):
		selected = idx[0]
	for i in idx:
		list.add_child(_run_button(i))
	_show_detail(runs[selected])


func _run_button(i: int) -> Button:
	var r: Dictionary = runs[i]
	var on := i == selected
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_stylebox_override("normal", DecoTheme.box(DecoTheme.PANEL_2 if on else DecoTheme.BAR, DecoTheme.GOLD if on else DecoTheme.BORDER, 0, 2))
	b.add_theme_stylebox_override("hover", DecoTheme.box(DecoTheme.PANEL_2, DecoTheme.GOLD if on else DecoTheme.BORDER_2, 0, 2))
	b.add_theme_stylebox_override("pressed", DecoTheme.box(DecoTheme.PANEL_2, DecoTheme.GOLD, 0, 2))
	b.pressed.connect(func():
		selected = i
		_confirm_delete = false
		_rebuild())
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var l1 := HBoxContainer.new()
	v.add_child(l1)
	var name_l := UiUtil.label("%s · %s" % [tr(str(r.get("map", "?"))), _difficulty(r)], l1, 15)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l1.add_theme_constant_override("separation", 8)
	l1.add_child(_badge(r))
	var l2 := HBoxContainer.new()
	v.add_child(l2)
	var when := UiUtil.label("%s · %s" % [_date(r), tr("Punkte") if r.get("score_mode", false) else tr("Leben")], l2, 14)
	when.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	when.add_theme_color_override("font_color", DecoTheme.MUTED)
	var res := tr("Welle %d") % int(r.get("wave", 0))
	if not r.get("score_mode", false):
		res += " · " + tr("%d Leben") % int(r.get("lives", 0))
	UiUtil.label(res, l2, 14).add_theme_color_override("font_color", DecoTheme.MUTED)
	for c in [l1, l2, name_l, when]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Ergebnis-Kästchen: GEWONNEN (grün), VERLOREN (rot) oder Punkte (gold).
func _badge(r: Dictionary) -> PanelContainer:
	var col := DecoTheme.COIN
	var text := tr("%s Pkt") % _num(int(r.get("score", 0)))
	if not r.get("score_mode", false):
		col = DecoTheme.HAVE if r.get("victory", false) else DecoTheme.MISSING
		text = tr("Gewonnen") if r.get("victory", false) else tr("Verloren")
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", DecoTheme.box(Color.TRANSPARENT, col, 0, 2, 3))
	var l := UiUtil.label(text, p, 14)
	l.uppercase = true
	l.add_theme_font_override("font", DecoTheme.font(true))
	l.add_theme_color_override("font_color", col)
	return p


func _show_detail(r: Dictionary) -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	detail.add_child(head)
	var badge := _badge(r)
	head.add_child(badge)
	var m := UiUtil.label(tr(str(r.get("map", "?"))), head, 17)
	m.add_theme_font_override("font", DecoTheme.font(true))
	var mode := UiUtil.label("%s · %s" % [_difficulty(r), tr("Punkte") if r.get("score_mode", false) else tr("Leben")], head, 14)
	mode.add_theme_color_override("font_color", DecoTheme.MUTED)
	var when := UiUtil.label(_date(r, true) + " · " + tr("Spielzeit %s") % _duration(int(r.get("play_time", 0))), detail, 14)
	when.add_theme_color_override("font_color", DecoTheme.MUTED)

	var summary: Dictionary = r.get("summary", {})
	var fb: Dictionary = summary.get("final_boss", {})
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	detail.add_child(grid)
	_tile(grid, "Welle", "%d / %d" % [int(r.get("wave", 0)), int(r.get("waves", 0))])
	if r.get("score_mode", false):
		_tile(grid, "Punkte", _num(int(r.get("score", 0))), DecoTheme.COIN)
	else:
		_tile(grid, "Leben übrig", "%d / %d" % [int(r.get("lives", 0)), int(r.get("max_lives", 50))], DecoTheme.HAVE if r.get("victory", false) else DecoTheme.MISSING)
	_tile(grid, "Kills", _num(int(r.get("kills", 0))))
	_tile(grid, "Weglänge", tr("%d Felder") % int(r.get("path", 0)))
	var boss_pct := 100.0 * float(fb.get("damage", 0.0)) / maxf(float(fb.get("hp", 0.0)), 1.0) if not fb.is_empty() else -1.0
	_tile(grid, "Endboss", (TowerStats.num(boss_pct, 1) + " %") if boss_pct >= 0.0 else "–", DecoTheme.COIN)
	_tile(grid, "Tower", str(int(r.get("towers", 0))))

	# Verlorene Leben (Punkte-Modus: durchgelassene Gegner) pro Welle als Balken
	var leaks: Array = r.get("leaks", [])
	var lost := 0
	var lost_waves := 0
	for x in leaks:
		lost += int(x)
		lost_waves += 1 if int(x) > 0 else 0
	var ch := HBoxContainer.new()
	detail.add_child(ch)
	var cap := DecoTheme.caption("Durchgelassen pro Welle" if r.get("score_mode", false) else "Leben verloren pro Welle", ch)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.label(tr("%d in %d Wellen") % [lost, lost_waves], ch, 14).add_theme_color_override("font_color", DecoTheme.MUTED)
	var chart := Control.new()
	chart.custom_minimum_size.y = 56
	chart.draw.connect(_draw_chart.bind(chart, leaks))
	detail.add_child(chart)

	# Nach Wellentyp (aus game.run_summary)
	var types: Dictionary = summary.get("types", {})
	if not types.is_empty():
		var th := HBoxContainer.new()
		detail.add_child(th)
		var c2 := DecoTheme.caption("Nach Wellentyp", th)
		c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not fb.is_empty():
			UiUtil.label(tr("Endboss: %s Schaden") % _num(roundi(float(fb.get("damage", 0.0)))), th, 14).add_theme_color_override("font_color", DecoTheme.MUTED)
		var tab := GridContainer.new()
		tab.columns = 3
		tab.add_theme_constant_override("h_separation", 16)
		tab.add_theme_constant_override("v_separation", 2)
		detail.add_child(tab)
		var sm := bool(r.get("score_mode", false))
		for h in ["Wellentyp", "Kills", "Punkte" if sm else "Durch"]:
			DecoTheme.caption(h, tab)
		tab.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for type in TYPE_ORDER + types.keys().filter(func(k): return k not in TYPE_ORDER):
			if not types.has(type):
				continue
			var st: Dictionary = types[type]
			UiUtil.label(tr(str(type)), tab, 14)
			_cell(tab, str(int(st.get("kills", 0))), DecoTheme.TEXT)
			if sm:
				_cell(tab, _num(roundi(float(st.get("points", 0.0)))), DecoTheme.COIN)
			else:
				var lk := int(st.get("leaks", 0))
				_cell(tab, str(lk), DecoTheme.MISSING if lk > 0 else DecoTheme.MUTED)

	# Beste Tower nach Schaden
	var top: Array = r.get("top", [])
	if not top.is_empty():
		DecoTheme.caption("Top-Tower nach Schaden", detail)
		var best := maxf(float(top[0].get("damage", 1)), 1.0)
		for i in top.size():
			var t: Dictionary = top[i]
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 2)
			detail.add_child(box)
			var h := HBoxContainer.new()
			box.add_child(h)
			UiUtil.label("◆", h, 14).add_theme_color_override("font_color", Color.from_string(str(t.get("color", "ffffff")), Color.WHITE))
			var n := UiUtil.label(str(t.get("label", "?")), h, 14)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiUtil.label(DpsMeter._fmt(float(t.get("damage", 0))), h, 14).add_theme_color_override("font_color", DecoTheme.COIN)
			# Balken wie im DPS-Meter: gefüllter Teil und Rest als zwei Streifen
			var f := clampf(float(t.get("damage", 0)) / best, 0.02, 1.0)
			var track := HBoxContainer.new()
			track.add_theme_constant_override("separation", 0)
			box.add_child(track)
			for part in [[DecoTheme.GOLD if i == 0 else DecoTheme.CYAN, f], [DecoTheme.BORDER, 1.0 - f + 0.0001]]:
				var seg := ColorRect.new()
				seg.color = part[0]
				seg.custom_minimum_size.y = 3
				seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				seg.size_flags_stretch_ratio = part[1]
				track.add_child(seg)

	var specials: Array = r.get("specials", [])
	if not specials.is_empty():
		DecoTheme.caption("Gebaute Spezial-Tower", detail)
		var sp := UiUtil.wrap_label(" · ".join(specials), detail, 440)
		sp.add_theme_font_size_override("font_size", 14)
		sp.add_theme_color_override("font_color", DecoTheme.MUTED)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	UiUtil.label("", detail, 4)
	detail.add_child(actions)
	var again := UiUtil.button("Map nochmal spielen", actions, func(): replay_requested.emit(r))
	again.focus_mode = Control.FOCUS_NONE
	again.custom_minimum_size.y = 44
	DecoTheme.accent_button(again, DecoTheme.GOLD, DecoTheme.GOLD_DARK, Color(DecoTheme.GOLD, 0.3))
	var del := UiUtil.button(tr("Wirklich löschen?") if _confirm_delete else tr("Lauf löschen"), actions, func():
		if _confirm_delete:
			RunHistory.delete(selected)
			_confirm_delete = false
			reload()
		else:
			_confirm_delete = true
			_show_detail(r))
	del.focus_mode = Control.FOCUS_NONE
	del.custom_minimum_size.y = 44
	if _confirm_delete:
		del.add_theme_color_override("font_color", DecoTheme.MISSING)


func _tile(parent: Node, caption: String, value: String, col := DecoTheme.TEXT) -> void:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", DecoTheme.box(DecoTheme.PANEL_2, DecoTheme.BORDER, 0, 2, 8))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var c := DecoTheme.caption(caption, v)
	c.add_theme_font_size_override("font_size", 14)
	var l := UiUtil.label(value, v, 17)
	l.add_theme_color_override("font_color", col)


func _cell(parent: Node, text: String, col: Color) -> void:
	var l := UiUtil.label(text, parent, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size.x = 60
	l.add_theme_color_override("font_color", col)


## Ein Balken pro Welle: rot, wenn dort Leben verloren gingen, sonst ein flacher Strich; Achse 1, 10 … 50.
func _draw_chart(c: Control, leaks: Array) -> void:
	if leaks.is_empty():
		return
	var h := c.size.y - 14.0
	var top := 1
	for x in leaks:
		top = maxi(top, int(x))
	var step := c.size.x / leaks.size()
	var font := DecoTheme.font()
	for i in leaks.size():
		var v := int(leaks[i])
		var bh := 3.0 if v <= 0 else maxf(6.0, h * v / float(top))
		c.draw_rect(Rect2(i * step + 1, h - bh, maxf(step - 2.0, 1.0), bh), DecoTheme.MISSING if v > 0 else DecoTheme.BORDER)
	c.draw_line(Vector2(0, h + 1), Vector2(c.size.x, h + 1), DecoTheme.BORDER, 1.0)
	for n in [1, 10, 20, 30, 40, 50]:
		if n <= leaks.size():
			var x := minf((n - 1) * step, c.size.x - 14.0)
			c.draw_string(font, Vector2(x, c.size.y), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DecoTheme.MUTED)


func _difficulty(r: Dictionary) -> String:
	var d := clampi(int(r.get("difficulty", 1)), 0, Session.DIFFICULTIES.size() - 1)
	return tr(str(Session.DIFFICULTIES[d].name))


## "12.10. 00:41" oder mit Jahr "12.10.2026, 00:41".
static func _date(r: Dictionary, long := false) -> String:
	var t := str(r.get("time", ""))
	if t.length() < 16:
		return t
	var day := "%s.%s." % [t.substr(8, 2), t.substr(5, 2)]
	if long:
		day += t.substr(0, 4) + ","
	return day + " " + t.substr(11, 5)


static func _duration(sec: int) -> String:
	if sec >= 3600:
		return "%d:%02d:%02d" % [sec / 3600, (sec / 60) % 60, sec % 60]
	return "%d:%02d" % [sec / 60, sec % 60]


## 48210 -> "48.210" (Deutsch) bzw. "48,210".
static func _num(v: int) -> String:
	var s := str(absi(v))
	var parts := []
	while s.length() > 3:
		parts.push_front(s.substr(s.length() - 3))
		s = s.substr(0, s.length() - 3)
	parts.push_front(s)
	return ("-" if v < 0 else "") + ("." if TranslationServer.get_locale().begins_with("de") else ",").join(parts)
