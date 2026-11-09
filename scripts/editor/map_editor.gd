extends Node3D
## Einfacher Map-Editor: Kacheln malen, Spawn/Ziel/Checkpoints setzen, speichern, testen.

const PANEL_WIDTH := 340.0

enum Tool { BLOCKED, WALK_ONLY, FLOOR, SPAWN, GOAL, CHECKPOINT, WATER }
const TOOL_NAMES := {
	Tool.BLOCKED: "Blockiert (#)",
	Tool.WALK_ONLY: "Nur Weg (_)",
	Tool.FLOOR: "Boden (.)",
	Tool.SPAWN: "Spawn setzen",
	Tool.GOAL: "Ziel setzen",
	Tool.CHECKPOINT: "Checkpoint +/−",
	Tool.WATER: "Wasserlauf",
}

var map: MapData
var board: Board3D
var camera_rig: CameraRig
var tool := Tool.BLOCKED
var painting := 0  ## 0 = nein, 1 = links (Werkzeug), 2 = rechts (Radierer)
var brush := 2     ## Pinselgröße in Feldern (2 = eine Towerbreite)

var tool_buttons := {}
var id_edit: LineEdit
var name_edit: LineEdit
var w_spin: SpinBox
var h_spin: SpinBox
var wave_option: OptionButton
var district_option: OptionButton
const DISTRICT_NAMES := {"": "Standard", "ueberwuchert": "Überwuchert (Pilzhof)"}
var wave_ids: Array = []
var lives_spin: SpinBox
var gold_spin: SpinBox
var radius_spin: SpinBox
var rocks_spin: SpinBox
var seed_spin: SpinBox
var load_option: OptionButton
var map_entries: Array = []
var status_label: Label
var water_tool: MapWaterEditor


func _ready() -> void:
	map = Session.editor_map.duplicate_map() if Session.editor_map != null else MapData.create_empty(60, 60)
	CameraRig.add_environment(self, {}, false)
	board = Board3D.new()
	board.map = map
	board.grid_strength = 0.25
	add_child(board)
	camera_rig = CameraRig.new()
	camera_rig.limit_view = false
	add_child(camera_rig)
	_build_ui()
	_sync_fields()
	_layout()
	_on_map_changed()
	_set_clean()


func _layout() -> void:
	camera_rig.frame_map(map.width * Board3D.CELL, map.height * Board3D.CELL)


# --- Oberfläche --------------------------------------------------------------

var TOOL_COLORS := {  ## var, weil die UiTheme-Farben static var sind
	Tool.BLOCKED: Color("3b3f48"),
	Tool.WALK_ONLY: Color("a07a4a"),
	Tool.FLOOR: Color("2d4a30"),
	Tool.SPAWN: UiTheme.HAVE,
	Tool.GOAL: UiTheme.MISSING,
	Tool.CHECKPOINT: UiTheme.GOLD,
	Tool.WATER: UiTheme.CYAN,
}
const BRUSHES := [1, 2, 4, 8]

var path_label: Label
var cell_label: Label
var dirty_label: Label
var brush_buttons := {}
var dirty := false


func _panel(parent: Node, pad := 14.0, bg := UiTheme.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(bg, UiTheme.BORDER, 0, 1, pad))
	parent.add_child(p)
	return p


func _field(parent: Node, text: String, control: Control) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	var l := UiUtil.label(text, v, 13)
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(control)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


func _spin(value: float, min_v: float, max_v: float, on_changed: Callable) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = 1
	sp.allow_greater = true
	sp.value = value
	sp.value_changed.connect(func(v):
		on_changed.call(v)
		_touch())
	return sp


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Leiste oben: Map laden, neu, testen, speichern
	var top := _panel(root, 10, UiTheme.BAR)
	top.anchor_right = 1.0
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	top.add_child(th)
	UiTheme.title(UiUtil.label("Map-Editor", th, 20))
	th.add_child(_hgap(12))
	load_option = OptionButton.new()
	load_option.custom_minimum_size.x = 220
	load_option.tooltip_text = "Gespeicherte Map zum Laden auswählen"
	th.add_child(load_option)
	UiUtil.button("Laden", th, _load_selected)
	UiUtil.button("Neu", th, func(): _set_map(MapData.create_empty(int(w_spin.value), int(h_spin.value))))
	UiUtil.button("Datei importieren", th, _import).tooltip_text = "Map-Datei (.json) laden, z. B. aus dem HTML-Editor; Speichern legt sie bei den Maps ab"
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(fill)
	UiUtil.button("Testen (F5)", th, _test).tooltip_text = "Map sofort spielen, danach geht es hierher zurück"
	var save := UiUtil.button("Speichern", th, _save)
	save.custom_minimum_size.x = 120
	UiTheme.accent_button(save, UiTheme.GOLD, UiTheme.GOLD_DARK, Color.TRANSPARENT)
	UiUtil.button("Zum Menü", th, func(): Session.goto(Session.MAIN_MENU))

	# Links: Werkzeuge
	var left := _panel(root)
	left.offset_top = 52
	left.anchor_bottom = 1.0
	left.offset_bottom = -34
	left.custom_minimum_size.x = 210
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	UiTheme.caption("Werkzeug", lv)
	var group := ButtonGroup.new()
	var key := 1
	for t in TOOL_NAMES:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == tool
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 38
		b.tooltip_text = tr("Taste %d") % key
		b.pressed.connect(func(): tool = t)
		lv.add_child(b)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -10
		h.add_theme_constant_override("separation", 10)
		b.add_child(h)
		var sw := ColorRect.new()
		sw.color = TOOL_COLORS[t]
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sw)
		var name_l := UiUtil.label(tr(str(TOOL_NAMES[t]).split(" (")[0]), h, 15)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_l := UiUtil.label(str(key), h, 12)
		key_l.add_theme_color_override("font_color", UiTheme.MUTED)
		key_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_stylebox_override("pressed", UiTheme.box(Color("2a0f2e"), UiTheme.GOLD))
		tool_buttons[t] = b
		key += 1
	lv.add_child(HSeparator.new())
	UiTheme.caption("Pinsel (Felder)", lv)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	lv.add_child(brow)
	var bgroup := ButtonGroup.new()
	for n in BRUSHES:
		var b := UiUtil.button(str(n), brow, func(): brush = n)
		b.toggle_mode = true
		b.button_group = bgroup
		b.button_pressed = n == brush
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "2 Felder = eine Towerbreite"
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.GOLD))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		brush_buttons[n] = b
	lv.add_child(HSeparator.new())
	var clear := UiUtil.button("Checkpoints löschen", lv, func():
		map.checkpoints.clear()
		_on_map_changed())
	clear.add_theme_color_override("font_color", UiTheme.MISSING)
	var lfill := Control.new()
	lfill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(lfill)
	var help := UiUtil.wrap_label("Linksklick malt, Rechtsklick radiert.\nKamera: WASD/Pfeile, Fensterrand, rechte Maustaste ziehen, Q/E, Mausrad.", lv, 180)
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", UiTheme.MUTED)

	# Rechts: Eigenschaften in Tabs
	var right := _panel(root)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -PANEL_WIDTH
	right.offset_top = 52
	right.offset_bottom = -34
	var tabs := TabContainer.new()
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", UiTheme.box(UiTheme.GOLD, Color.TRANSPARENT, 4, 0, 14))
	tabs.add_theme_stylebox_override("tab_unselected", UiTheme.box(UiTheme.PANEL_2, Color.TRANSPARENT, 4, 0, 14))
	tabs.add_theme_stylebox_override("tab_hovered", UiTheme.box(Color("1f1036"), Color.TRANSPARENT, 4, 0, 14))
	tabs.add_theme_color_override("font_selected_color", UiTheme.GOLD_DARK)
	tabs.add_theme_color_override("font_unselected_color", UiTheme.TEXT)
	tabs.add_theme_color_override("font_hovered_color", UiTheme.TEXT)
	right.add_child(tabs)

	var map_tab := VBoxContainer.new()
	map_tab.name = "Map"
	map_tab.add_theme_constant_override("separation", 12)
	tabs.add_child(map_tab)
	map_tab.add_child(_vgap(4))
	name_edit = _field(map_tab, "Name", LineEdit.new())
	name_edit.text_changed.connect(func(s):
		map.name = s
		_touch())
	id_edit = _field(map_tab, "ID (Dateiname: Kleinbuchstaben, Ziffern, _)", LineEdit.new())
	id_edit.text_changed.connect(func(s):
		map.id = s
		_touch())
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	map_tab.add_child(size_row)
	w_spin = _field(size_row, "Breite", _spin(60, 10, 400, func(_v): pass))
	h_spin = _field(size_row, "Höhe", _spin(60, 10, 400, func(_v): pass))
	UiUtil.button("Größe übernehmen", map_tab, func():
		map.resize(int(w_spin.value), int(h_spin.value))
		_layout()
		_on_map_changed())
	wave_option = OptionButton.new()
	wave_ids = Database.wave_sets.keys()
	for wid in wave_ids:
		wave_option.add_item(tr(str(Database.wave_sets[wid].get("name", wid))))
	wave_option.item_selected.connect(func(i):
		map.wave_set = wave_ids[i]
		_touch())
	_field(map_tab, "Wellen", wave_option)
	# Bezirk: Umgebungs-Baukasten neben der Karte (eeveTD, YouTD), leer = Standard des Modus
	district_option = OptionButton.new()
	for did in MapData.DISTRICTS:
		district_option.add_item(tr(DISTRICT_NAMES.get(did, did)))
	district_option.item_selected.connect(func(i):
		map.district = MapData.DISTRICTS[i]
		_touch())
	_field(map_tab, "Bezirk", district_option)
	var lg := HBoxContainer.new()
	lg.add_theme_constant_override("separation", 8)
	map_tab.add_child(lg)
	lives_spin = _field(lg, "Leben", _spin(50, 1, 1000, func(v): map.lives = int(v)))
	gold_spin = _field(lg, "Startgold", _spin(0, 0, 100000, func(v): map.start_gold = int(v)))
	radius_spin = _field(map_tab, "Sperrzone um Spawn, Ziel, Checkpoints", _spin(1, 0, 10, func(v):
		map.marker_radius = int(v)
		_on_map_changed()))

	var var_tab := VBoxContainer.new()
	var_tab.name = "Varianz"
	var_tab.add_theme_constant_override("separation", 12)
	tabs.add_child(var_tab)
	var_tab.add_child(_vgap(4))
	rocks_spin = _field(var_tab, "Zufällige Steine zu Spielbeginn", _spin(0, 0, 500, func(v): map.variance["random_rocks"] = int(v)))
	seed_spin = _field(var_tab, "Seed (−1 = jedes Mal zufällig)", _spin(-1, -1, 999999, func(v): map.variance["seed"] = int(v)))
	var vh := UiUtil.wrap_label("Mit einem festen Seed liegen die Steine in jedem Spiel gleich.", var_tab, PANEL_WIDTH - 40)
	vh.add_theme_font_size_override("font_size", 13)
	vh.add_theme_color_override("font_color", UiTheme.MUTED)

	water_tool = MapWaterEditor.new()
	add_child(water_tool)
	water_tool.setup(self, tabs)

	# Statuszeile unten
	var bar := _panel(root, 8, UiTheme.BAR)
	bar.anchor_top = 1.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -34
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 24)
	bar.add_child(bh)
	path_label = UiUtil.label("", bh, 13)
	cell_label = UiUtil.label("", bh, 13)
	cell_label.add_theme_color_override("font_color", UiTheme.MUTED)
	dirty_label = UiUtil.label("", bh, 13)
	dirty_label.add_theme_color_override("font_color", UiTheme.GOLD)
	status_label = UiUtil.label("", bh, 13)
	status_label.add_theme_color_override("font_color", UiTheme.MUTED)
	_refresh_load_list()


func _hgap(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c


func _vgap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


## Merkt sich ungespeicherte Änderungen für die Statuszeile.
func _touch() -> void:
	dirty = true
	if dirty_label != null:
		dirty_label.text = "● " + tr("Ungespeicherte Änderungen")


func _set_clean() -> void:
	dirty = false
	dirty_label.text = ""


func _sync_fields() -> void:
	id_edit.text = map.id
	name_edit.text = map.name
	w_spin.set_value_no_signal(map.width)
	h_spin.set_value_no_signal(map.height)
	wave_option.select(maxi(wave_ids.find(map.wave_set), 0))
	district_option.select(maxi(MapData.DISTRICTS.find(map.district), 0))
	lives_spin.set_value_no_signal(map.lives)
	gold_spin.set_value_no_signal(map.start_gold)
	radius_spin.set_value_no_signal(map.marker_radius)
	rocks_spin.set_value_no_signal(int(map.variance.get("random_rocks", 0)))
	seed_spin.set_value_no_signal(int(map.variance.get("seed", -1)))


func _set_map(m: MapData) -> void:
	map = m
	if water_tool != null:
		water_tool.selected = -1
	board.map = m
	_sync_fields()
	_layout()
	_on_map_changed()
	_set_clean()


func _refresh_load_list() -> void:
	map_entries = Database.list_maps()
	load_option.clear()
	for e in map_entries:
		load_option.add_item(tr(e.name))


func _load_selected() -> void:
	if map_entries.is_empty():
		return
	var m := MapData.load_file(map_entries[load_option.selected].path)
	if m != null:
		_set_map(m)
		status_label.text = tr("Geladen: ") + tr(m.name)


func _import() -> void:
	UiUtil.open_json_file(self, func(d: Dictionary, file: String):
		if not d.get("tiles") is Array:
			status_label.text = tr("Keine Map-Datei: ") + file
			return
		_set_map(MapData.from_dict(d))
		_touch()
		status_label.text = tr("Importiert: %s. Speichern legt die Map ab.") % file)


func _save() -> void:
	if not _valid_id(map.id):
		status_label.text = tr("Ungültige ID: nur Kleinbuchstaben, Ziffern und _ erlaubt.")
		return
	var path := Database.writable_path("maps", map.id)
	if map.save_file(path):
		status_label.text = tr("Gespeichert: ") + path
		_refresh_load_list()
		_set_clean()


func _test() -> void:
	if pathfinder_path().is_empty():
		status_label.text = tr("Kein gültiger Weg, so kann nicht getestet werden.")
		return
	Session.editor_map = map.duplicate_map()
	Session.map_override = map.duplicate_map()
	Session.test_tower = ""
	Session.return_scene = Session.MAP_EDITOR
	Session.goto(Session.GAME)


static func _valid_id(s: String) -> bool:
	var re := RegEx.create_from_string("^[a-z0-9_]+$")
	return re.search(s) != null


# --- Malen -------------------------------------------------------------------

func _is_point_tool() -> bool:
	return tool == Tool.SPAWN or tool == Tool.GOAL or tool == Tool.CHECKPOINT or tool == Tool.WATER


func _process(_delta: float) -> void:
	var size := 1 if _is_point_tool() else brush
	var a := board.mouse_cell(camera_rig.camera) if size == 1 else board.mouse_anchor(camera_rig.camera, size)
	if a != board.hover_cell or size != board.hover_size:
		cell_label.text = tr("Feld %d, %d") % [a.x, a.y] if map.in_bounds(a) else ""
		board.hover_cell = a
		board.hover_size = size
		board.refresh_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			tool = TOOL_NAMES.keys()[event.keycode - KEY_1]
			tool_buttons[tool].button_pressed = true
		elif event.keycode == KEY_F5:
			_test()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				painting = 1
				_apply(true)
			else:
				painting = 0
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and not camera_rig.right_dragged:
			# Rechtsklick radiert einmal, rechts ziehen verschiebt die Kamera
			painting = 2
			_apply(true)
			painting = 0
	elif event is InputEventMouseMotion and painting != 0:
		_apply(false)


func _apply(is_click: bool) -> void:
	var c := board.mouse_cell(camera_rig.camera)
	if tool == Tool.WATER:
		if is_click:
			if painting == 2:
				water_tool.undo_point()
			else:
				water_tool.click(c, Input.is_key_pressed(KEY_SHIFT))
		return
	if painting == 2:
		var idx := map.checkpoints.find(c)
		if idx >= 0 and is_click:
			map.checkpoints.remove_at(idx)
		elif not _paint(MapData.FLOOR):
			return
		_on_map_changed()
		return
	match tool:
		Tool.BLOCKED, Tool.WALK_ONLY, Tool.FLOOR:
			var t: String = [MapData.BLOCKED, MapData.WALK_ONLY, MapData.FLOOR][tool]
			if not _paint(t):
				return
		Tool.SPAWN, Tool.GOAL, Tool.CHECKPOINT:
			if not map.in_bounds(c):
				return
			if not is_click:
				return
			if map.get_tile(c) == MapData.BLOCKED:
				map.set_tile(c, MapData.FLOOR)
			if tool == Tool.SPAWN:
				map.spawn = c
			elif tool == Tool.GOAL:
				map.goal = c
			else:
				var idx := map.checkpoints.find(c)
				if idx >= 0:
					map.checkpoints.remove_at(idx)
				else:
					map.checkpoints.append(c)
	_on_map_changed()


## Malt die Kachel t mit dem Pinsel unter der Maus. Gibt zurück, ob sich etwas geändert hat.
func _paint(t: String) -> bool:
	var a := board.mouse_cell(camera_rig.camera) if brush == 1 else board.mouse_anchor(camera_rig.camera, brush)
	var changed := false
	for c in Board3D.footprint(a, brush):
		if not map.in_bounds(c) or map.get_tile(c) == t:
			continue
		if t == MapData.BLOCKED and c in map.waypoints():
			continue
		map.set_tile(c, t)
		changed = true
	return changed


## Haken des Wassersystems: Läufe aufgelöst, für die Vorschau im Editor.
func water_regions() -> Variant:
	return water_tool.regions() if water_tool != null else null


func pathfinder_path() -> Array[Vector2i]:
	return Pathfinder.new(map).compute_path()


func _on_map_changed() -> void:
	var cells := pathfinder_path()
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(Board3D.cell_center(c))
	board.path_points = pts
	board.path_color = Color(0.3, 1, 0.3, 0.8)
	if cells.is_empty():
		path_label.text = "✗ " + tr("Kein gültiger Weg: Spawn, Checkpoints und Ziel müssen verbunden sein")
		path_label.add_theme_color_override("font_color", UiTheme.MISSING)
	else:
		path_label.text = "✓ " + tr("Weg gültig · %d Felder ohne Labyrinth · %d Checkpoints") % [cells.size(), map.checkpoints.size()]
		path_label.add_theme_color_override("font_color", UiTheme.HAVE)
	_touch()
	board.rebuild()
	if water_tool != null:
		water_tool.refresh()
