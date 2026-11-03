class_name SettingsPanel
extends Control
## Einstellungen (Sprache, Anzeige, Auflösung, UI-Größe) als Fenster über allem.
## Im Hauptmenü in Art déco (deco = true), im Spiel im Stil des Modus (UiTheme folgt dem Skin).
## Im Menü lädt ein Sprachwechsel die Szene neu; im Spiel geht das nicht, dort wechseln
## feste Texte sofort und zusammengesetzte beim nächsten Aufbau.

signal closed

var deco := false
var in_game := false
var ui_scale_slider: HSlider


func _init(deco_style := false, game := false) -> void:
	deco = deco_style
	in_game = game


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(DecoTheme.BAR, 0.75) if deco else Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DecoTheme.panel(28.0) if deco else UiTheme.panel(28.0))
	panel.custom_minimum_size.x = 520
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	if deco:
		var orn := UiUtil.label("◆  ◆  ◆", v, 16)
		orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		orn.add_theme_color_override("font_color", DecoTheme.GOLD)
		DecoTheme.title(UiUtil.label("Einstellungen", v, 38)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		UiTheme.title(UiUtil.label("Einstellungen", v, 26)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	var lang := _option(tr("Sprache") + ("" if Loc.language == "en" else " / Language"), grid)
	for l in Loc.LANGUAGES:
		lang.add_item(l[1])
	lang.select(maxi(Loc.LANGUAGES.map(func(l): return l[0]).find(Loc.language), 0))
	lang.item_selected.connect(func(i):
		Loc.set_language(Loc.LANGUAGES[i][0])
		if not in_game:
			# Menü neu laden, damit alle Texte neu gebaut werden
			Session.reopen_settings = true
			get_tree().reload_current_scene())

	var mode := _option(tr("Anzeige"), grid)
	mode.add_item(tr("Fenster"))
	mode.add_item(tr("Vollbild"))
	mode.select(1 if Display.fullscreen else 0)

	var res := _option(tr("Auflösung"), grid)
	for r in Display.RESOLUTIONS:
		res.add_item("%d × %d" % [r.x, r.y])
	res.select(maxi(Display.RESOLUTIONS.find(Display.resolution), 0))
	res.disabled = Display.fullscreen
	res.tooltip_text = tr("Im Vollbild gilt die Auflösung des Bildschirms.") if Display.fullscreen else ""
	res.item_selected.connect(func(i): Display.set_resolution(Display.RESOLUTIONS[i]))
	mode.item_selected.connect(func(i):
		Display.set_fullscreen(i == 1)
		res.disabled = i == 1
		res.tooltip_text = tr("Im Vollbild gilt die Auflösung des Bildschirms.") if i == 1 else "")
	var gfx := _option(tr("Grafik"), grid)
	for n in Display.QUALITY_NAMES:
		gfx.add_item(tr(n))
	gfx.select(Display.quality)
	gfx.tooltip_text = tr("Niedrig: harte Schatten, ohne Leuchten, Kantenglättung, Treffer- und Laternenlichter. Für schwächere Grafikkarten.")
	gfx.item_selected.connect(Display.set_quality)
	ui_scale_slider = _ui_scale_row(grid)
	# Bildfilter je Modus (StyleFilter): Retro in GemTD, Messing im Maul, Nebelwald in eeveTD/YouTD, warm in Randgruppen
	var look := _option(tr("Stil-Filter"), grid)
	look.add_item(tr("An"))
	look.add_item(tr("Aus"))
	look.select(0 if Display.style_filter else 1)
	look.tooltip_text = tr("Bildfilter passend zum Modus: Retro-Synthwave in GemTD, Messing-Glanz in Shopping Maul, Nebelwald in eeveTD und YouTD, warme Töne in Randgruppen TD.")
	look.item_selected.connect(func(i): Display.set_style_filter(i == 0))
	_cursor_rows(grid)
	VolumeRows.add(grid, DecoTheme.font(true) if deco else UiTheme.font(true), DecoTheme.BRASS_LIGHT if deco else UiTheme.CYAN)
	var text := "Änderungen gelten sofort und bleiben gespeichert."
	if in_game:
		text = "Änderungen gelten sofort und bleiben gespeichert. Nach einem Sprachwechsel folgen manche Texte erst beim nächsten Aufbau oder in der nächsten Partie."
	var hint := UiUtil.wrap_label(text, v, 440)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DecoTheme.MUTED if deco else UiTheme.MUTED)
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	v.add_child(gap)
	var done := UiUtil.button("Fertig", v, close)
	if deco:
		done.custom_minimum_size.y = 56
		done.add_theme_font_size_override("font_size", 28)
		DecoTheme.accent_button(done)
	else:
		done.custom_minimum_size.y = 48
		done.add_theme_font_size_override("font_size", 18)
		UiTheme.accent_button(done, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.35))
	if in_game:
		var esc := UiUtil.label("Esc: zurück", v, 13)
		esc.add_theme_color_override("font_color", UiTheme.MUTED)
		esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide()


func open() -> void:
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## UI-Größe 50–100 %: die Zahl folgt dem Regler sofort, umgestellt wird beim Loslassen,
## sonst springt der Regler beim Ziehen unter der Maus weg.
func _ui_scale_row(grid: GridContainer) -> HSlider:
	var l := UiUtil.label(tr("UI-Größe"), grid, 15)
	l.custom_minimum_size.x = 150
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(h)
	var s := HSlider.new()
	s.min_value = Display.UI_SCALE_MIN * 100.0
	s.max_value = Display.UI_SCALE_MAX * 100.0
	s.step = 5
	s.value = roundf(Display.ui_scale * 100.0)
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 24
	s.tooltip_text = tr("Verkleinert Menüs und Spieloberfläche, die Spielansicht bleibt gleich.")
	h.add_child(s)
	var n := UiUtil.label("%d %%" % roundi(s.value), h, 16)
	n.custom_minimum_size.x = 64
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.add_theme_font_override("font", DecoTheme.font(true) if deco else UiTheme.font(true))
	n.add_theme_color_override("font_color", DecoTheme.BRASS_LIGHT if deco else UiTheme.CYAN)
	var dragging := [false]
	s.drag_started.connect(func(): dragging[0] = true)
	s.drag_ended.connect(func(_changed):
		dragging[0] = false
		Display.set_ui_scale(s.value / 100.0))
	s.value_changed.connect(func(val):
		n.text = "%d %%" % roundi(val)
		if not dragging[0]:
			Display.set_ui_scale(val / 100.0))
	return s


func _option(text: String, grid: GridContainer) -> OptionButton:
	var l := UiUtil.label(text, grid, 15)
	l.custom_minimum_size.x = 150
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size.y = 40
	o.add_theme_font_size_override("font_size", 16)
	grid.add_child(o)
	return o


## Cursor: Stil (mit Vorschaubild, „Passend zum Modus“ zuerst), Größe 75–300 %, Umriss dunkel/hell/aus.
func _cursor_rows(grid: GridContainer) -> void:
	var cur := _option(tr("Cursor"), grid)
	var styles: Array = [Cursor.AUTO] + Cursor.STYLES
	for st in styles:
		var shown: String = Cursor.active_style() if st == Cursor.AUTO else st
		cur.add_icon_item(Cursor.texture(shown, "arrow", 26), tr(Cursor.NAMES[st]))
	cur.select(maxi(styles.find(Cursor.style), 0))
	cur.tooltip_text = tr("Eigener Mauszeiger. „Passend zum Modus“ wechselt mit dem Stil des Spiels, die Kontrast-Zeiger sind auf jedem Boden gut sichtbar.")
	cur.item_selected.connect(func(i): Cursor.set_style(styles[i]))
	var l := UiUtil.label(tr("Cursorgröße"), grid, 15)
	l.custom_minimum_size.x = 150
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(h)
	var s := HSlider.new()
	s.min_value = Cursor.SIZE_MIN * 100.0
	s.max_value = Cursor.SIZE_MAX * 100.0
	s.step = 25
	s.value = roundf(Cursor.size * 100.0)
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 24
	s.tooltip_text = tr("Größe des Mauszeigers, 100 % sind 32 Pixel.")
	h.add_child(s)
	var n := UiUtil.label("%d %%" % roundi(s.value), h, 16)
	n.custom_minimum_size.x = 64
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.add_theme_font_override("font", DecoTheme.font(true) if deco else UiTheme.font(true))
	n.add_theme_color_override("font_color", DecoTheme.BRASS_LIGHT if deco else UiTheme.CYAN)
	s.value_changed.connect(func(val):
		n.text = "%d %%" % roundi(val)
		Cursor.set_size(val / 100.0))
	var ol := _option(tr("Cursor-Umriss"), grid)
	for o in Cursor.OUTLINE_NAMES:
		ol.add_item(tr(o))
	ol.select(maxi(Cursor.OUTLINES.find(Cursor.outline), 0))
	ol.tooltip_text = tr("Heller oder dunkler Rand um den Zeiger, damit er sich vom Hintergrund abhebt.")
	ol.item_selected.connect(func(i): Cursor.set_outline(Cursor.OUTLINES[i]))
