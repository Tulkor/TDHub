class_name UiUtil
extends RefCounted
## Kleine Helfer, um Oberflächen im Code zu bauen.


static func label(text: String, parent: Node = null, font_size := 0) -> Label:
	var l := Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if parent:
		parent.add_child(l)
	return l


static func wrap_label(text: String, parent: Node, width: float) -> Label:
	var l := label(text, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


## Steht die Maus über einem sichtbaren Fenster (Panel, Knopf, Liste)? Dann gehört das Mausrad dem Fenster und
## nicht der Kamera. Durchsichtige Ebenen über dem Spielfeld zählen nicht.
static func mouse_over_ui(vp: Viewport) -> bool:
	var c := vp.gui_get_hovered_control()
	while c != null:
		if c is PanelContainer or c is Panel or c is BaseButton or c is ScrollContainer or c is ItemList \
				or c is LineEdit or c is TextEdit or c is Range or c is Tree or c is RichTextLabel:
			return true
		c = c.get_parent() as Control
	return false


static func button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


static func spin(parent: Node, value: float, min_v: float, max_v: float, step: float, on_changed: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.allow_greater = true
	s.value = value
	s.custom_minimum_size.x = 96
	s.value_changed.connect(on_changed)
	parent.add_child(s)
	return s


static func row(text: String, parent: Node, label_width := 150.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(text, h)
	l.custom_minimum_size.x = label_width
	parent.add_child(h)
	return h


## Seitenpanel rechts am Bildschirmrand, gibt die VBox für den Inhalt zurück.
static func side_panel(layer: CanvasLayer, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -width
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.PANEL
	style.border_color = UiTheme.GOLD
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


## Dateiauswahl für eine JSON-Datei irgendwo auf dem Rechner (z. B. aus dem HTML-Editor, tools/html_editor/).
## Ruft on_loaded mit dem gelesenen Dictionary und dem Dateinamen auf; bei ungültigem Inhalt mit {}.
static func open_json_file(parent: Node, on_loaded: Callable) -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.filters = PackedStringArray(["*.json ; JSON"])
	dlg.title = parent.tr("Datei importieren")
	parent.add_child(dlg)
	dlg.file_selected.connect(func(path: String):
		var d = Database.load_json(path)
		on_loaded.call(d if typeof(d) == TYPE_DICTIONARY else {}, path.get_file())
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered_ratio(0.7)


## Zweistufiger Klick für Aktionen ohne Rückweg (Verkaufen, Abreißen): der erste Klick fragt im Knopf selbst
## nach („Nochmal klicken: …“), erst der zweite innerhalb von CONFIRM_TIME Sekunden führt aus.
## Keine Rückfrage-Fenster, damit der Spielfluss bleibt (UI-Prüfung 2026-11-25, Nielsen H3/H5).
const CONFIRM_TIME := 2.5


static func confirm_press(b: Button, action: Callable) -> void:
	var armed := [false]
	var original := [""]
	# Zweizeilige Knöpfe (Hud._two_line) haben leeren Text und eigene Kinder: die werden kurz ausgeblendet
	var set_armed := func(on: bool) -> void:
		armed[0] = on
		if on:
			original[0] = b.text
		var shown: String = original[0] if original[0] != "" else b.tooltip_text.get_slice(" · ", 0)
		b.text = b.tr("Nochmal klicken: %s") % shown if on else original[0]
		for c in b.get_children():
			if c is Control:
				c.visible = not on
	b.pressed.connect(func():
		if armed[0]:
			set_armed.call(false)
			action.call()
			return
		set_armed.call(true)
		b.get_tree().create_timer(CONFIRM_TIME).timeout.connect(func():
			if is_instance_valid(b) and armed[0]:
				set_armed.call(false)))
