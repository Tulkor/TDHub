class_name MazePanel
extends PanelContainer
## Fenster „Maze-Vorlagen“ (Taste M, Lukas 2026-11-09). Liegt in der linken Spalte unter den nächsten Wellen,
## zugeklappt nur eine Zeile (Vorlage und Fortschritt), aufgeklappt: Vorlagen der Map wählen und als Overlay auf
## dem Boden zeigen, das aktuelle Maze speichern, Fortschritt, Deckkraft, und Planen (Blöcke setzen ohne zu bauen).
## Mockups /mnt/project-files/mockups/maze-vorlagen/. Rechnet nichts selbst: alles über das System mazes.

var mazes: Node  ## System mazes (scripts/systems/mazes/mazes.gd)
var expanded := false
var _body: VBoxContainer
var _fold: Button
var _summary: Label
var _title: Label
var _sub: Label
var _show_box: VBoxContainer   ## Ansicht „Vorlage zeigen“
var _plan_box: VBoxContainer   ## Ansicht „Planen“
var _list: VBoxContainer
var _scroll: ScrollContainer
## Höchstens so viele Vorlagen ohne Scrollen.
const LIST_ROWS := 4
var _bar: ProgressBar
var _progress: Label
var _conflicts: Label
var _opacity_val: Label
var _name_edit: LineEdit
var _plan_stats: Label
var _plan_hint: Label
var _hide_button: Button
var _save_plan: Button
var _lengths := {}   ## Vorlagen-ID -> Weglänge mit der Vorlage allein (Felder)
var _list_sig := ""


func _init(system: Node) -> void:
	mazes = system
	name = "MazePanel"
	custom_minimum_size.x = 340


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	_title = UiTheme.heading(UiUtil.label("Maze", head))
	_summary = UiUtil.label("", head, 12)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.clip_text = true
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary.add_theme_color_override("font_color", UiTheme.MUTED)
	_fold = UiUtil.button("+", head, toggle)
	_fold.focus_mode = Control.FOCUS_NONE
	_fold.custom_minimum_size.x = 28
	_fold.tooltip_text = tr("Maze-Vorlagen auf- und zuklappen (Taste M)")
	Hud.key_badge(_fold, "M")
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	v.add_child(_body)
	_sub = UiUtil.label("", _body, 12)
	_sub.add_theme_color_override("font_color", UiTheme.MUTED)
	_build_show(_body)
	_build_plan(_body)
	mazes.changed.connect(_refresh)
	_body.hide()
	_refresh.call_deferred()


func _build_show(parent: Node) -> void:
	_show_box = VBoxContainer.new()
	_show_box.add_theme_constant_override("separation", 6)
	parent.add_child(_show_box)
	UiTheme.caption("Vorlagen", _show_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll = scroll
	_show_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	UiTheme.caption("Fortschritt", _show_box)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 12
	_bar.add_theme_stylebox_override("background", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.HAVE))
	_show_box.add_child(_bar)
	var h := HBoxContainer.new()
	_show_box.add_child(h)
	_progress = UiUtil.label("", h, 13)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conflicts = UiUtil.label("", h, 13)
	_conflicts.add_theme_color_override("font_color", UiTheme.MISSING)
	UiTheme.caption("Anzeige", _show_box)
	var o := HBoxContainer.new()
	o.add_theme_constant_override("separation", 8)
	_show_box.add_child(o)
	UiUtil.label("Deckkraft", o, 13)
	var slider := HSlider.new()
	slider.min_value = 10
	slider.max_value = 100
	slider.step = 5
	slider.value = mazes.opacity * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(val):
		mazes.opacity = val / 100.0
		_opacity_val.text = "%d %%" % int(val))
	slider.drag_ended.connect(func(_c): mazes.save_prefs())
	o.add_child(slider)
	_opacity_val = UiUtil.label("%d %%" % int(mazes.opacity * 100.0), o, 13)
	_opacity_val.custom_minimum_size.x = 48
	_check("Gebaute Blöcke grün zeigen", mazes.show_done, func(on):
		mazes.show_done = on
		mazes.save_prefs()
		mazes.refresh(true))
	_check("Bauvorschau rastet auf Vorlage ein", mazes.snap_on, func(on):
		mazes.snap_on = on
		mazes.save_prefs())
	var b := HFlowContainer.new()
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_constant_override("v_separation", 8)
	_show_box.add_child(b)
	var save := _btn("Aktuelles Maze speichern", b, func():
		mazes.save_current(tr("Maze Welle %d") % (mazes.game.wave_index + 1)))
	UiTheme.accent_button(save, UiTheme.GOLD, UiTheme.GOLD_DARK)
	save.tooltip_text = tr("Alle Steine und Tower, die jetzt stehen, als eigene Vorlage speichern.")
	_btn("Planen", b, func(): mazes.set_editing(true)).tooltip_text = \
			tr("Blöcke setzen und entfernen, ohne etwas zu bauen. Geht jederzeit, auch vor dem ersten Gem.")
	_hide_button = _btn("Ausblenden", b, func(): mazes.hide_template())


func _build_plan(parent: Node) -> void:
	_plan_box = VBoxContainer.new()
	_plan_box.add_theme_constant_override("separation", 6)
	parent.add_child(_plan_box)
	_plan_hint = UiUtil.wrap_label(tr("Klick setzt einen Block, Klick auf einen Block entfernt ihn. Auf einen Stein geklickt übernimmt ihn."), _plan_box, 300)
	_plan_hint.add_theme_color_override("font_color", UiTheme.COIN)
	_plan_hint.add_theme_font_size_override("font_size", 13)
	UiTheme.caption("Name", _plan_box)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 40
	_name_edit.text_changed.connect(func(_t): mazes.dirty = true; _refresh_buttons())
	_plan_box.add_child(_name_edit)
	UiTheme.caption("Entwurf", _plan_box)
	_plan_stats = UiUtil.label("", _plan_box, 13)
	var b1 := HFlowContainer.new()
	b1.add_theme_constant_override("h_separation", 8)
	b1.add_theme_constant_override("v_separation", 8)
	_plan_box.add_child(b1)
	_btn("Steine aus dem Spiel übernehmen", b1, func(): mazes.take_current())
	_btn("Alles leeren", b1, func(): mazes.clear_blocks())
	var b2 := HFlowContainer.new()
	b2.add_theme_constant_override("h_separation", 8)
	b2.add_theme_constant_override("v_separation", 8)
	_plan_box.add_child(b2)
	_save_plan = _btn("Speichern", b2, func(): mazes.save_active(_name_edit.text))
	UiTheme.accent_button(_save_plan, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_btn("Als neue Vorlage", b2, func(): mazes.save_active(_name_edit.text, true))
	var done := _btn("Fertig", b2, func(): mazes.set_editing(false))
	done.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
	done.add_theme_color_override("font_color", UiTheme.GOLD_DARK)


func _btn(text: String, parent: Node, f: Callable) -> Button:
	var b := UiUtil.button(text, parent, f)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _check(text: String, on: bool, f: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 13)
	c.toggled.connect(f)
	_show_box.add_child(c)
	return c


func open() -> void:
	expanded = true
	_body.show()
	_list_sig = ""
	_refresh()


func close() -> void:
	if mazes.editing:
		mazes.set_editing(false)
	expanded = false
	_body.hide()
	_refresh()


func toggle() -> void:
	if expanded:
		close()
	else:
		open()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var planning: bool = mazes.editing
	var p: Vector2i = mazes.progress()
	_fold.text = "−" if expanded else "+"
	_title.text = tr("Maze planen") if planning else (tr("Maze-Vorlagen") if expanded else tr("Maze"))
	UiTheme.heading(_title)
	if mazes.active.is_empty():
		_summary.text = "" if expanded else tr("keine Vorlage")
	else:
		_summary.text = "%s · %d/%d" % [tr(str(mazes.active.get("name", ""))), p.x, p.y]
	if not expanded:
		return
	_show_box.visible = not planning
	_plan_box.visible = planning
	_sub.text = tr("Map: %s · baut nichts, kostet nichts") % tr(mazes.game.map.name) if planning \
			else tr("Map: %s · nur auf diesem Rechner") % tr(mazes.game.map.name)
	if planning:
		if not _name_edit.has_focus() and _name_edit.text != str(mazes.active.get("name", "")):
			_name_edit.text = str(mazes.active.get("name", ""))
		var now: int = mazes.game.path_length
		_plan_stats.text = tr("Blöcke: %d\nWeg mit Entwurf: %d Felder\nWeg jetzt im Spiel: %d Felder") % [
			mazes.block_count(), int(mazes.plan_length() * 2.0), now]
		_refresh_buttons()
		return
	_refresh_list()
	_bar.max_value = maxi(p.y, 1)
	_bar.value = p.x
	_progress.text = tr("%d / %d gebaut") % [p.x, p.y] if not mazes.active.is_empty() else tr("Keine Vorlage gewählt")
	_conflicts.text = tr("%d Konflikte") % mazes.conflicts() if mazes.conflicts() > 0 else ""
	_hide_button.disabled = mazes.active.is_empty()


func _refresh_buttons() -> void:
	_save_plan.disabled = not mazes.dirty and str(mazes.active.get("id", "")) != "" and not mazes.active.get("builtin", false)


func _refresh_list() -> void:
	var list: Array = mazes.templates()
	var sig := "%s|%s" % [str(mazes.active.get("id", "")), str(list.map(func(t): return [t.id, t.name, t.blocks.size()]))]
	if sig == _list_sig:
		return
	_list_sig = sig
	for c in _list.get_children():
		c.queue_free()
	if list.is_empty():
		var l := UiUtil.wrap_label(tr("Für diese Map gibt es noch keine Vorlagen. Speichere dein Maze oder plane eines."), _list, 300)
		l.add_theme_color_override("font_color", UiTheme.MUTED)
		l.add_theme_font_size_override("font_size", 13)
	for t in list:
		_list.add_child(_row(t))
	# Liste so hoch wie ihr Inhalt, ab LIST_ROWS Vorlagen scrollt sie
	_scroll.custom_minimum_size.y = 0
	await get_tree().process_frame
	var rows := _list.get_children().filter(func(c): return not c.is_queued_for_deletion())
	var hgt := 0.0
	for i in mini(rows.size(), LIST_ROWS):
		hgt += rows[i].get_combined_minimum_size().y + 4.0
	_scroll.custom_minimum_size.y = hgt


func _row(t: Dictionary) -> Control:
	var sel: bool = str(t.id) == str(mazes.active.get("id", ""))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	var len: int = _lengths.get(t.id, -1)
	if len < 0:
		len = mazes.template_length(t)
		_lengths[t.id] = len
	b.text = "%s\n%s" % [tr(str(t.name)), tr("%d Blöcke · Weg %d") % [t.blocks.size(), len]]
	b.add_theme_font_size_override("font_size", 13)
	b.tooltip_text = (tr("Mitgeliefert") if t.get("builtin", false) else tr("Eigene Vorlage")) + \
			("\n" + tr(str(t.note)) if str(t.get("note", "")) != "" else "")
	if sel:
		b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
		b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.CYAN.lightened(0.15), UiTheme.CYAN))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, UiTheme.GOLD_DARK)
	var tmpl := t
	b.pressed.connect(func():
		if sel:
			mazes.hide_template()
		else:
			mazes.show_template(tmpl))
	h.add_child(b)
	if t.get("builtin", false):
		var tag := UiUtil.label(tr("MITGELIEFERT"), h, 10)
		tag.add_theme_color_override("font_color", UiTheme.PURPLE_LIGHT)
	else:
		var edit := _btn("✎", h, func():
			mazes.show_template(tmpl)
			mazes.set_editing(true))
		edit.tooltip_text = tr("Umbenennen und weiterplanen")
		var del := _btn("×", h, func(): mazes.delete(str(tmpl.id)))
		del.tooltip_text = tr("Vorlage löschen")
		del.add_theme_color_override("font_color", UiTheme.MISSING)
	return h
