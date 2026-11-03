class_name DpsMeter
extends PanelContainer
## DPS-Meter rechts am Rand: die 5 Tower mit dem meisten Schaden pro Sekunde.
## Umschaltbar zwischen laufender Welle, der letzten Welle eines Typs und dem ganzen Spiel.
## Liest nur game.is_wave_running(), game.wave_index, game.waves und tower.total_damage.

const TOP := 5
const TOP_Y := 128.0  ## unter dem Phasenbanner
## [Schlüssel, Text]. Die Schlüssel sind die Typen aus game.wave_type().
const VIEWS := [
	["now", "Aktuelle Welle"],
	["Boss", "Letzte Boss-Welle"],
	["Flieger", "Letzte Flug-Welle"],
	["Boden", "Letzte Boden-Welle"],
	["Masse", "Letzte Massen-Welle"],
	["total", "Gesamt"],
]

var game  # game.gd
var avoid: Control  ## rutscht darunter, solange dieses Panel offen ist (Reiter, darüber das Debug-Menü)
var tabs: SideTabs  ## Reiter der rechten Spalte: nur sichtbar, wenn „Alle“ oder „DPS“ gewählt ist
var view := "now"
var select: OptionButton
var info: Label
var body: VBoxContainer
var rows: Array = []  ## je Zeile {swatch, name, value, bar, rest}

var _running := false
var _wave_number := 0
var _wave_type := ""
var _wave_time := 0.0
var _start: Dictionary = {}   ## instance_id -> total_damage zu Wellenbeginn
var _last: Dictionary = {}    ## Typ (und "recent") -> {wave, time, rows}
var _total: Dictionary = {}   ## instance_id -> {label, color, damage}
var _total_time := 0.0
var _refresh_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_top = TOP_Y
	offset_right = -16
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size.x = 280
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiTheme.panel(12.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiUtil.label("DPS", head, 16)
	UiTheme.heading(title, UiTheme.CYAN)
	select = OptionButton.new()
	select.focus_mode = Control.FOCUS_NONE
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_theme_font_size_override("font_size", 12)
	for item in VIEWS:
		select.add_item(item[1])
	select.item_selected.connect(func(i):
		view = VIEWS[i][0]
		refresh())
	head.add_child(select)
	var fold := Button.new()
	fold.text = "–"
	fold.focus_mode = Control.FOCUS_NONE
	fold.tooltip_text = "Ein-/ausklappen"
	fold.pressed.connect(func():
		body.visible = not body.visible
		fold.text = "–" if body.visible else "+")
	head.add_child(fold)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	v.add_child(body)
	info = UiUtil.label("", body, 12)
	info.add_theme_color_override("font_color", UiTheme.MUTED)
	for i in TOP:
		rows.append(_row())
	refresh()


func _row() -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	body.add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	box.add_child(h)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 10)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(swatch)
	var name_l := UiUtil.label("", h, 13)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var value := UiUtil.label("", h, 13)
	value.add_theme_color_override("font_color", UiTheme.COIN)
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 0)
	box.add_child(track)
	var bar := ColorRect.new()
	bar.custom_minimum_size.y = 3
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.add_child(bar)
	var rest := ColorRect.new()
	rest.color = UiTheme.BORDER
	rest.custom_minimum_size.y = 3
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.add_child(rest)
	return {"box": box, "swatch": swatch, "name": name_l, "value": value, "bar": bar, "rest": rest}


func _process(delta: float) -> void:
	if avoid != null:
		offset_top = avoid.get_rect().end.y + 8 if avoid.visible else TOP_Y
	if tabs != null:
		visible = tabs.shows("dps")
	if game == null or not game.has_method("is_wave_running"):
		return
	var running: bool = game.is_wave_running()
	if running and _running and game.wave_index + 1 != _wave_number:
		_end_wave()  # Debug: andere Welle gestartet, ohne dass die Welle endete
		_begin_wave()
	elif running and not _running:
		_begin_wave()
	elif not running and _running:
		_end_wave()
	_running = running
	if running:
		_wave_time += delta
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		refresh()


func _begin_wave() -> void:
	_wave_number = game.wave_index + 1
	_wave_type = game.wave_type(game.waves[game.wave_index]) if game.wave_index < game.waves.size() else ""
	_wave_time = 0.0
	_start.clear()
	for t in game.all_towers():
		_start[t.get_instance_id()] = t.total_damage


func _end_wave() -> void:
	var current := _current_rows()
	if _wave_time > 0.0:
		var entry := {"wave": _wave_number, "time": _wave_time, "rows": current}
		_last["recent"] = entry
		if _wave_type != "":
			_last[_wave_type] = entry
		for r in current:
			var tot: Dictionary = _total.get(r.id, {"damage": 0.0})
			tot.label = r.label
			tot.color = r.color
			tot.damage = float(tot.damage) + r.damage
			_total[r.id] = tot
		_total_time += _wave_time
	_running = false
	_wave_time = 0.0
	_start.clear()


## Schaden aller Tower seit Beginn der laufenden Welle.
func _current_rows() -> Array:
	var out := []
	if game == null:
		return out
	for t in game.all_towers():
		if not is_instance_valid(t):
			continue
		var id: int = t.get_instance_id()
		var dmg: float = t.total_damage - float(_start.get(id, 0.0))
		if dmg > 0.0:
			out.append({"id": id, "label": t.label(), "color": t.color, "damage": dmg})
	return out


## Zeilen und Dauer für die gewählte Ansicht, dazu die Infozeile.
func data() -> Dictionary:
	match view:
		"now":
			if _running:
				return {"rows": _current_rows(), "time": _wave_time, "info": tr("Welle %d läuft · %d s") % [_wave_number, int(_wave_time)]}
			if _last.has("recent"):
				var e: Dictionary = _last.recent
				return {"rows": e.rows, "time": e.time, "info": tr("Welle %d (vorbei) · %d s") % [e.wave, int(e.time)]}
			return {"rows": [], "time": 0.0, "info": tr("Noch keine Welle gelaufen")}
		"total":
			var merged := {}
			for id in _total:
				merged[id] = _total[id].duplicate()
			var time := _total_time
			if _running:
				time += _wave_time
				for r in _current_rows():
					var m: Dictionary = merged.get(r.id, {"damage": 0.0})
					m.label = r.label
					m.color = r.color
					m.damage = float(m.damage) + r.damage
					merged[r.id] = m
			return {"rows": merged.values(), "time": time, "info": tr("Alle Wellen · %d s Kampfzeit") % int(time)}
		_:
			if _last.has(view):
				var e: Dictionary = _last[view]
				return {"rows": e.rows, "time": e.time, "info": tr("Welle %d · %d s") % [e.wave, int(e.time)]}
			return {"rows": [], "time": 0.0, "info": tr("Noch keine Welle dieser Art")}


## Die besten 5 als [label, color, dps], absteigend.
func top() -> Array:
	var d := data()
	var time: float = maxf(float(d.time), 0.001)
	var list: Array = d.rows.map(func(r): return [r.label, r.color, float(r.damage) / time])
	list.sort_custom(func(a, b): return a[2] > b[2])
	return list.slice(0, TOP)


func refresh() -> void:
	if info == null:
		return
	var d := data()
	info.text = d.info
	var list := top()
	var best: float = list[0][2] if not list.is_empty() else 1.0
	for i in rows.size():
		var r: Dictionary = rows[i]
		r.box.visible = i < list.size()
		if i >= list.size():
			continue
		r.swatch.color = list[i][1]
		r.name.text = "%d. %s" % [i + 1, list[i][0]]
		r.value.text = _fmt(list[i][2])
		var f: float = clampf(list[i][2] / maxf(best, 0.001), 0.02, 1.0)
		r.bar.color = UiTheme.GOLD if i == 0 else UiTheme.CYAN
		r.bar.size_flags_stretch_ratio = f
		r.rest.size_flags_stretch_ratio = 1.0 - f + 0.0001
		r.rest.visible = f < 1.0


static func _fmt(dps: float) -> String:
	if dps >= 10000.0:
		return "%.1fk" % (dps / 1000.0)
	return "%d" % int(round(dps))
