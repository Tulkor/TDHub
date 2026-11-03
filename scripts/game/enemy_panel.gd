class_name EnemyPanel
extends PanelContainer
## Gegner-Fenster rechts unter dem DPS-Meter: wie viel Prozent der Leben der ganzen Welle schon
## abgezogen sind und wie viele Felder der vorderste Gegner noch laufen muss. Einklappbar.
## Liest nur game.enemies, game.spawn_queue, game.wave_live, game.queued_hp() und map.checkpoints.

var game  # game.gd
var above: Control:  ## sitzt darunter (DPS-Meter)
	set(v):
		above = v
		# Sofort nachziehen, wenn das Fenster darüber wächst (sonst liegt es einen Frame lang darüber)
		if v != null:
			v.item_rect_changed.connect(func(): offset_top = (above.get_rect().end.y + 12) if above.visible else above.offset_top)
var tabs: SideTabs  ## Reiter der rechten Spalte (hud.side_tabs)
var title: Label
var summary: Label  ## eingeklappt: "63 % · vorne 23 Felder"
var fold: Button
var body: VBoxContainer
var wave_label: Label
var kind_label: Label
var pct_label: Label
var hp_label: Label
var bar: ProgressBar
var chips := {}  ## alive, killed, leaked, queued -> Label
var front_label: Label
var next_label: Label
var track: Control

var _refresh_left := 0.0
var _cp_index: Array = []  ## Wegpunkt-Index jedes Checkpoints im Bodenweg
var _cp_path: PackedVector2Array
var _front := {}  ## {fields, progress, next} des vordersten Gegners, {} = keiner


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	title = UiUtil.label("Gegner", head, 16)
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
	body.add_theme_constant_override("separation", 4)
	v.add_child(body)
	kind_label = UiUtil.label("", body, 12)
	kind_label.add_theme_color_override("font_color", UiTheme.MUTED)
	UiTheme.caption("Wellen-Leben abgezogen", body)
	var big := HBoxContainer.new()
	big.add_theme_constant_override("separation", 8)
	body.add_child(big)
	pct_label = UiTheme.title(UiUtil.label("", big, 24))
	var pct_sign := UiUtil.label("%", big, 15)
	pct_sign.size_flags_vertical = Control.SIZE_SHRINK_END
	pct_sign.add_theme_color_override("font_color", UiTheme.GOLD)
	hp_label = UiUtil.label("", big, 12)
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_END
	hp_label.add_theme_color_override("font_color", UiTheme.MUTED)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 12
	bar.add_theme_stylebox_override("background", UiTheme.box(UiTheme.BORDER, Color.TRANSPARENT, 0, 0, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, Color.TRANSPARENT, 0, 0, 0))
	body.add_child(bar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for item in [["alive", "Lebend", UiTheme.TEXT], ["killed", "Besiegt", UiTheme.HAVE],
			["leaked", "Durch", UiTheme.MISSING], ["queued", "Kommen noch", UiTheme.CYAN]]:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 4))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(p)
		var h := HBoxContainer.new()
		p.add_child(h)
		var c := UiUtil.label(item[1], h, 11)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_color_override("font_color", UiTheme.MUTED)
		var n := UiUtil.label("0", h, 13)
		n.add_theme_color_override("font_color", item[2])
		chips[item[0]] = n
	UiTheme.caption("Vorderster Gegner", body)
	var fr := HBoxContainer.new()
	body.add_child(fr)
	front_label = UiUtil.label("", fr, 14)
	front_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_label.add_theme_color_override("font_color", UiTheme.COIN)
	next_label = UiUtil.label("", fr, 12)
	next_label.add_theme_color_override("font_color", UiTheme.MUTED)
	track = Control.new()
	track.custom_minimum_size.y = 26
	track.draw.connect(_draw_track)
	body.add_child(track)
	refresh()


func toggle() -> void:
	body.visible = not body.visible
	fold.text = "–" if body.visible else "+"
	refresh()


func _process(delta: float) -> void:
	if above != null:
		offset_top = (above.get_rect().end.y + 12) if above.visible else above.offset_top
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		refresh()


## Zahlen der laufenden Welle: {wave, total, dealt, alive, killed, leaked, queued}.
func data() -> Dictionary:
	if game == null or not game.is_wave_running():
		return {}
	var live: Dictionary = game.wave_live
	var total: float = float(live.gone_hp) + game.queued_hp()
	var dealt: float = float(live.gone_dealt)
	var alive := 0
	for e in game.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		alive += 1
		total += e.max_hp
		dealt += clampf(e.max_hp - e.hp, 0.0, e.max_hp)
	return {"wave": game.wave_index + 1, "total": total, "dealt": dealt, "alive": alive,
			"killed": int(live.killed), "leaked": int(live.leaked), "queued": game.spawn_queue.size()}


## Vorderster Gegner: noch zu laufende Felder, Anteil des Wegs und nächster Checkpoint (1-basiert, 0 = Ziel).
func front() -> Dictionary:
	if game == null:
		return {}
	var best = null
	for e in game.enemies:
		if is_instance_valid(e) and not e.dead and (best == null or e.traveled > best.traveled):
			best = e
	if best == null or best.path.size() < 2:
		return {}
	var p: PackedVector2Array = best.path
	var rest := 0.0
	var i: int = mini(best.path_index, p.size() - 1)
	rest += best.pos.distance_to(p[i])
	for k in range(i, p.size() - 1):
		rest += p[k].distance_to(p[k + 1])
	var length: float = best.traveled + rest
	var fields := ceili(rest / Board3D.CELL - 0.001)
	var next := 0
	var cps := _checkpoint_indices(p)
	for n in cps.size():
		if cps[n] >= best.path_index:
			next = n + 1
			break
	return {"fields": fields, "progress": clampf(best.traveled / maxf(length, 0.001), 0.0, 1.0), "next": next,
			"marks": cps.map(func(k): return _dist_to(p, k) / maxf(length, 0.001))}


## Index im Weg, an dem jeder Checkpoint erreicht wird (einmal pro Weg berechnet).
func _checkpoint_indices(p: PackedVector2Array) -> Array:
	if p == _cp_path:
		return _cp_index
	_cp_path = p
	_cp_index = []
	var from := 0
	for c in game.map.checkpoints:
		var center: Vector2 = Board3D.cell_center(c)
		var best := -1
		var best_d := INF
		for k in range(from, p.size()):
			var d := p[k].distance_squared_to(center)
			if d < best_d:
				best_d = d
				best = k
			if d < 0.01:
				break
		if best < 0:
			break
		_cp_index.append(best)
		from = best
	return _cp_index


static func _dist_to(p: PackedVector2Array, idx: int) -> float:
	var d := 0.0
	for k in mini(idx, p.size() - 1):
		d += p[k].distance_to(p[k + 1])
	return d


func refresh() -> void:
	if body == null:
		return
	var d := data()
	visible = not d.is_empty() and (tabs == null or tabs.shows("gegner"))
	if d.is_empty():
		return
	var share: float = float(d.dealt) / maxf(float(d.total), 1.0)
	_front = front()
	var front_text := tr("vorne %d Felder") % int(_front.fields) if not _front.is_empty() else ""
	if body.visible:
		summary.text = tr("Welle %d") % int(d.wave)
	else:
		summary.text = "%d %%" % floori(share * 100.0) + (" · " + front_text if front_text != "" else "")
		return
	var groups: Array = game.waves[game.wave_index].get("groups", []) if game.wave_index < game.waves.size() else []
	var names := []
	for g in groups:
		names.append("%d× %s" % [int(g.get("count", 1)), tr(str(Database.enemies.get(str(g.get("enemy", "")), {}).get("name", "?")))])
	kind_label.text = tr(game.wave_type(game.waves[game.wave_index])) + (" · " + ", ".join(names) if not names.is_empty() else "")
	pct_label.text = "%d" % floori(share * 100.0)
	hp_label.text = tr("%s / %s LP") % [_big(float(d.dealt)), _big(float(d.total))]
	bar.max_value = 1.0
	bar.value = share
	for k in chips:
		chips[k].text = str(d[k])
	if _front.is_empty():
		front_label.text = tr("Kein Gegner auf dem Weg")
		next_label.text = ""
	else:
		front_label.text = tr("noch %d Felder") % int(_front.fields)
		next_label.text = (tr("nächster: %d") % int(_front.next)) if int(_front.next) > 0 else tr("nächster: Ziel")
	track.visible = not _front.is_empty()
	track.queue_redraw()


## Weg als Linie: erledigter Teil türkis, Checkpoints als Kästchen, vorderster Gegner als gelber Pfeil.
func _draw_track() -> void:
	if _front.is_empty():
		return
	var w := track.size.x - 16.0
	var x0 := 8.0
	var y := 15.0
	track.draw_rect(Rect2(x0, y - 1.5, w, 3), UiTheme.BORDER)
	track.draw_rect(Rect2(x0, y - 1.5, w * float(_front.progress), 3), UiTheme.CYAN)
	var font := UiTheme.font(true)
	var marks: Array = _front.marks + [1.0]
	for n in marks.size():
		var x: float = x0 + w * float(marks[n])
		var passed: bool = float(marks[n]) <= float(_front.progress)
		var r := Rect2(x - 7, y - 7, 14, 14)
		track.draw_rect(r, UiTheme.GOLD if passed else UiTheme.PANEL)
		track.draw_rect(r, UiTheme.GOLD, false, 2.0)
		var txt := "Z" if n == marks.size() - 1 else str(n + 1)
		track.draw_string(font, Vector2(x - 4, y + 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.PANEL if passed else UiTheme.GOLD)
	var px: float = x0 + w * float(_front.progress)
	track.draw_colored_polygon(PackedVector2Array([Vector2(px - 6, 0), Vector2(px + 6, 0), Vector2(px, 9)]), UiTheme.COIN)


static func _big(v: float) -> String:
	if v >= 100000.0:
		return "%dk" % roundi(v / 1000.0)
	var s := "%d" % roundi(v)
	if s.length() > 3:
		s = s.substr(0, s.length() - 3) + "." + s.substr(s.length() - 3)
	return s
