class_name MapWaterEditor
extends Node
## Wasser im Map-Editor: Läufe („kind": "stream") vorgeben, das Wasser sucht den Rest selbst (WaterRoute).
## Erster Klick setzt die Quelle, weitere Klicks Wegpunkte, Umschalt+Klick die Mündung, Rechtsklick nimmt
## den letzten Punkt zurück. Vorschau über das gemeinsame WaterSystem mit echtem Wasser-Shader.

var editor: Node        ## der Map-Editor (map, board, pathfinder_path())
var water: WaterSystem
var selected := -1      ## Index in map.water, -1 = nächster Klick legt einen neuen Lauf an
var list: OptionButton
var width_spin: SpinBox
var dir_spin: SpinBox
var length_spin: SpinBox
var info: Label
var _entries: Array[int] = []
var _last_errors := PackedStringArray()


func setup(owner_editor: Node, tabs: TabContainer) -> void:
	editor = owner_editor
	var mode: String = editor.map.game if editor.map.game != "" else "gemtd"
	water = SystemHost.attach(editor, mode, ["water"]).get("water")
	_build_tab(tabs)
	refresh()


func _map() -> MapData:
	return editor.map


func _build_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Wasser"
	tab.add_theme_constant_override("separation", 10)
	tabs.add_child(tab)
	tab.add_child(Control.new())
	list = OptionButton.new()
	list.item_selected.connect(func(i): _select(_entries[i] if i < _entries.size() else -1))
	_field(tab, "Wasserlauf", list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tab.add_child(row)
	var new_btn := UiUtil.button("Neuer Lauf", row, func():
		_select(-1)
		info.text = tr("Klick auf die Karte setzt die Quelle."))
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.accent_button(new_btn, UiTheme.CYAN, UiTheme.GOLD_DARK)
	var del := UiUtil.button("Löschen", row, _delete)
	del.add_theme_color_override("font_color", UiTheme.MISSING)
	var props := HBoxContainer.new()
	props.add_theme_constant_override("separation", 8)
	tab.add_child(props)
	width_spin = _field(props, "Breite", _spin(1.0, 0.5, 8.0, 0.5, func(v): _put("width", v)))
	dir_spin = _field(props, "Richtung °", _spin(0.0, 0.0, 359.0, 15.0, func(v):
		var a := deg_to_rad(v)
		_put("dir", [snappedf(cos(a), 0.001), snappedf(sin(a), 0.001)])))
	length_spin = _field(tab, "Länge (0 = bis Rand, Mulde oder Sackgasse)", _spin(0.0, 0.0, 500.0, 1.0, func(v): _put("length", v)))
	var help := UiUtil.wrap_label("Werkzeug Wasserlauf (Taste 7): erster Klick setzt die Quelle, weitere Klicks Wegpunkte, Umschalt+Klick die Mündung. Rechtsklick nimmt den letzten Punkt zurück. Den Rest des Weges sucht sich das Wasser selbst: es weicht Felsen, Sperrzonen und dem Gegnerweg aus, auf Gelände fließt es bergab.", tab, 290)
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", UiTheme.MUTED)
	info = UiUtil.wrap_label("", tab, 290)
	info.add_theme_font_size_override("font_size", 12)


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


func _spin(value: float, min_v: float, max_v: float, step: float, on_changed: Callable) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = step
	sp.value = value
	sp.value_changed.connect(on_changed)
	return sp


func _stream() -> Dictionary:
	var m := _map()
	return m.water[selected] if selected >= 0 and selected < m.water.size() else {}


func _put(key: String, value: Variant) -> void:
	var s := _stream()
	if s.is_empty():
		return
	if key == "length" and float(value) <= 0.0:
		s.erase("length")
	else:
		s[key] = value
	_changed()


func _select(index: int) -> void:
	selected = index
	var s := _stream()
	if not s.is_empty():
		width_spin.set_value_no_signal(float(s.get("width", 1.0)))
		var d: Array = s.get("dir", [1, 0])
		dir_spin.set_value_no_signal(fposmod(rad_to_deg(atan2(float(d[1]), float(d[0]))), 360.0))
		length_spin.set_value_no_signal(float(s.get("length", 0.0)))
	_refresh_list()


func _delete() -> void:
	if _stream().is_empty():
		return
	_map().water.remove_at(selected)
	selected = -1
	_changed()


## Klick mit dem Wasser-Werkzeug auf Feld c. Gibt zurück, ob sich etwas geändert hat.
func click(c: Vector2i, shift: bool) -> bool:
	var m := _map()
	if not m.in_bounds(c):
		return false
	var p := Board3D.cell_center(c)
	var at := [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]
	var s := _stream()
	if s.is_empty():
		var a := deg_to_rad(dir_spin.value)
		s = {"kind": "stream", "id": _free_id(), "source": at, "width": width_spin.value, "dir": [snappedf(cos(a), 0.001), snappedf(sin(a), 0.001)]}
		if length_spin.value > 0.0:
			s.length = length_spin.value
		m.water.append(s)
		selected = m.water.size() - 1
	elif shift:
		s.end = at
	else:
		var via: Array = s.get("via", [])
		if via.size() >= WaterRoute.MAX_VIA:
			info.text = tr("Höchstens %d Wegpunkte.") % WaterRoute.MAX_VIA
			return false
		via.append(at)
		s.via = via
	_changed()
	return true


## Rechtsklick: Mündung, sonst letzten Wegpunkt, sonst den ganzen Lauf entfernen.
func undo_point() -> bool:
	var s := _stream()
	if s.is_empty():
		return false
	if s.has("end"):
		s.erase("end")
	elif not s.get("via", []).is_empty():
		s.via.pop_back()
	else:
		_delete()
		return true
	_changed()
	return true


func _free_id() -> String:
	var used := {}
	for r in _map().water:
		used[str(r.get("id", ""))] = true
	var n := 1
	while used.has("Lauf%d" % n):
		n += 1
	return "Lauf%d" % n


func _changed() -> void:
	editor._touch()
	refresh()


## Gewässer für die Vorschau: Läufe aufgelöst, Gegnerweg als Hindernis.
func regions() -> Array:
	var avoid: Array = editor.pathfinder_path()
	var result := WaterRoute.expand(_map().water, WaterRoute.map_terrain(_map(), avoid))
	_last_errors = result.errors
	return result.regions


func refresh() -> void:
	_refresh_list()
	if water != null:
		water.rebuild()
		var errors := _last_errors.duplicate()
		errors.append_array(water.last_errors)
		info.text = "\n".join(errors)
		info.add_theme_color_override("font_color", UiTheme.MISSING)


func _refresh_list() -> void:
	if list == null:
		return
	list.clear()
	_entries.clear()
	var m := _map()
	for i in m.water.size():
		if str(m.water[i].get("kind", "")) == "stream":
			_entries.append(i)
			list.add_item(str(m.water[i].get("id", "Lauf")))
	if selected < 0 or not _entries.has(selected):
		list.add_item(tr("(neuer Lauf)"))
		list.select(list.item_count - 1)
	else:
		list.select(_entries.find(selected))
