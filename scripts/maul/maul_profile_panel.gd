class_name MaulProfilePanel
extends ColorRect
## Profil-Fenster im Startfenster von Shopping Maul (Art déco): Erfahrung mit Balken bis zur nächsten
## Freischaltung, alle Freischaltungen, Summen und Rekorde je Filiale (maul_profile.gd).

var xp := 0


func _ready() -> void:
	color = Color(DecoTheme.BAR, 0.9)
	theme = DecoTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DecoTheme.panel(20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	box.add_child(head)
	var title := DecoTheme.title(UiUtil.label("Profil", head), 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Net.my_name != "":
		var who := UiUtil.label(Net.my_name, head, 15)
		who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		who.add_theme_color_override("font_color", DecoTheme.MUTED)

	build_content(box)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	box.add_child(bottom)
	var hint := UiUtil.label("Gezählt wird ohne Sandbox und ohne Debug-Menü. Im Koop speichert jeder sein eigenes Profil auf seinem Rechner.", bottom, 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.custom_minimum_size.x = 500
	hint.add_theme_color_override("font_color", DecoTheme.MUTED)
	var back := UiUtil.button("Zurück", bottom, queue_free)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Erfahrung, Summen, Freischaltungen und Filialen in box (auch im allgemeinen Profil, profile_panel.gd).
func build_content(box: Node) -> void:
	_xp_bar(box)
	_totals(box)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	box.add_child(cols)
	_unlock_list(cols)
	_shop_table(cols)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


## Erfahrung und Balken bis zur nächsten Freischaltung.
func _xp_bar(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var l := UiUtil.label(tr("Erfahrung: %s XP") % MaulXp.text(xp), row, 18)
	l.add_theme_font_override("font", DecoTheme.font(true))
	l.add_theme_color_override("font_color", DecoTheme.PURPLE_LIGHT)
	var next := MaulProfile.next_unlock(xp)
	var info := UiUtil.label("", row, 14)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if next.is_empty():
		info.text = tr("Alles freigeschaltet")
		info.add_theme_color_override("font_color", DecoTheme.HAVE)
		return
	info.text = tr("Nächste Freischaltung: %s ab %s XP") % [tr(str(next.name)), MaulXp.text(int(next.xp))]
	# Balken vom letzten offenen Schritt bis zum nächsten
	var from := 0
	for u in MaulProfile.unlocks(xp):
		if u.open:
			from = int(u.xp)
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, 12)
	track.add_theme_stylebox_override("panel", DecoTheme.box(DecoTheme.BG, DecoTheme.GOLD))
	parent.add_child(track)
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", DecoTheme.box(DecoTheme.BRASS_LIGHT, Color.TRANSPARENT, 0, 0))
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(float(xp - from) / float(maxi(int(next.xp) - from, 1)), 0.0, 1.0)
	fill.offset_left = 2
	fill.offset_top = 2
	fill.offset_bottom = -2
	track.add_child(fill)


func _totals(parent: Node) -> void:
	var t := MaulProfile.totals()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	parent.add_child(row)
	for e in [["Partien", str(t.games)], ["Siege", str(t.wins)], ["Level geschafft", str(t.levels)],
			["Gegner besiegt", MaulHud.big(int(t.kills))], ["Spielzeit", tr("%d h %02d min") % [int(t.minutes) / 60, int(t.minutes) % 60]]]:
		var v := VBoxContainer.new()
		row.add_child(v)
		DecoTheme.caption(e[0], v)
		UiUtil.label(e[1], v, 18).add_theme_color_override("font_color", DecoTheme.TEXT)


func _unlock_list(parent: Node) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	parent.add_child(v)
	DecoTheme.caption("Freischaltungen", v)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	v.add_child(grid)
	for u in MaulProfile.unlocks(xp):
		var name := UiUtil.label(("◆ " if u.open else "◇ ") + tr(str(u.name)), grid, 14)
		name.add_theme_color_override("font_color", DecoTheme.HAVE if u.open else DecoTheme.MUTED)
		var need := UiUtil.label(tr("%s XP") % MaulXp.text(int(u.xp)), grid, 14)
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		need.add_theme_color_override("font_color", DecoTheme.DIM if u.open else DecoTheme.MUTED)


## Je Filiale: Partien, Siege, bestes Level, schwerste gewonnene Schwierigkeit.
func _shop_table(parent: Node) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	parent.add_child(v)
	DecoTheme.caption("Rekorde je Filiale", v)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	v.add_child(grid)
	for h in ["Filiale", "Partien", "Siege", "Bestes Level", "Schwerster Sieg"]:
		var l := UiUtil.label(h, grid, 14)
		l.add_theme_color_override("font_color", DecoTheme.GOLD)
	var levels := MaulData.levels().size()
	for s in MaulData.shops():
		var r := MaulProfile.shop(str(s.id))
		var played := int(r.games) > 0
		var name := UiUtil.label(MaulData.name_of(s) + (" ★" if str(s.kind) == "pro" else ""), grid, 14)
		name.add_theme_color_override("font_color", Color.from_string(str(s.color), DecoTheme.GOLD) if played else DecoTheme.MUTED)
		var best := int(r.best_win)
		for text in [str(r.games), str(r.wins), "%d / %d" % [int(r.best_level), levels] if played else "–",
				tr(str(MaulData.difficulty(best).get("name", ""))) if best >= 0 else "–"]:
			var l := UiUtil.label(text, grid, 14)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_color_override("font_color", DecoTheme.TEXT if played else DecoTheme.MUTED)
