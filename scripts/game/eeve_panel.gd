class_name EevePanel
extends PanelContainer
## Seitenleiste von eeveTD: Holz, Food, Elementpunkte mit den sechs Elementen (wie das Tech Center im Original),
## die Fallen (ab Elementstufe 4 direkt baubar), der Knopf für das nächste Level und die letzten Meldungen.

var game  # eeve_game.gd
var _lumber: Label
var _food: Label
var _points: Label
var _score: Label
var _rows := {}   ## Element -> {level: Label, pips: HBoxContainer, plus: Button}
var _next: Button
var _traps: VBoxContainer
var _traps_key := ""
var _log: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	custom_minimum_size.x = 280
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 14)
	v.add_child(res)
	_lumber = _value("Holz", res, UiTheme.HAVE)
	_food = _value("Food", res, UiTheme.TEXT)
	_food.get_parent().tooltip_text = tr("Jede Barrikade und jeder Tower braucht 1 Food. Pro Level gibt es abwechselnd 1 und 2 Food dazu.")
	_score = _value("Wertung", res, UiTheme.COIN)

	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiUtil.label("Elemente", head, 15)
	UiTheme.heading(t)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points = UiUtil.label("", head, 14)
	_points.add_theme_color_override("font_color", UiTheme.COIN)

	for e in game.rules.get("elements", []):
		var id := str(e.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = tr(str(e.name)) + "\n" + tr("Stärken: ") + tr(str(e.strengths)) + "\n" + tr("Schwäche: ") + tr(str(e.weakness))
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(row)
		var sw := ColorRect.new()
		sw.color = Color(str(e.color))
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
		var name := UiUtil.label(str(e.name), row, 14)
		name.custom_minimum_size.x = 64
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pips)
		for i in int(game.rules.get("point_max", 8)):
			var p := ColorRect.new()
			p.custom_minimum_size = Vector2(12, 10)
			p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(p)
		var plus := UiUtil.button("+", row, func(): game.submit({"type": "element", "element": id}))
		plus.focus_mode = Control.FOCUS_NONE
		plus.custom_minimum_size = Vector2(30, 24)
		plus.tooltip_text = tr("Elementpunkt in %s setzen") % tr(str(e.name))
		_rows[id] = {"pips": pips, "plus": plus, "color": Color(str(e.color))}

	var th := UiUtil.label("Fallen", v, 15)
	UiTheme.heading(th)
	th.tooltip_text = tr("Fallen liegen auf dem Weg, Gegner laufen darüber. Sie treffen nur Bodengegner.")
	th.mouse_filter = Control.MOUSE_FILTER_PASS
	_traps = VBoxContainer.new()
	_traps.add_theme_constant_override("separation", 4)
	v.add_child(_traps)

	_next = UiUtil.button("", v, func(): game.submit({"type": "start_level"}))
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size.y = 40
	_next.tooltip_text = tr("Pause überspringen (Taste N)")
	UiTheme.accent_button(_next, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_log = UiUtil.wrap_label("", v, 256)
	_log.add_theme_font_size_override("font_size", 14)
	_log.add_theme_color_override("font_color", UiTheme.MUTED)
	refresh()


func _value(caption: String, parent: Node, color: Color) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(h)
	UiUtil.label(caption, h, 14).add_theme_color_override("font_color", UiTheme.MUTED)
	var l := UiUtil.label("", h, 16)
	l.add_theme_color_override("font_color", color)
	return l


func refresh() -> void:
	if _lumber == null:
		return
	_lumber.text = str(game.lumber)
	_score.text = str(game.score_total())
	_score.get_parent().tooltip_text = tr("Punkte je Kill: %d\nChallenges: %d\nAm Ende kommen übrige Leben, übriges Gold und der Feldbonus dazu, alles × %s.") % [
		roundi(game.eeve_score.creeps), roundi(game.eeve_score.challenges), str(game.score_factor())]
	_food.text = "%d / %d" % [game.food_used(), game.food_cap]
	_food.add_theme_color_override("font_color", UiTheme.MISSING if game.food_used() >= game.food_cap else UiTheme.TEXT)
	_points.text = tr("%d Punkte frei") % game.points if game.points != 1 else tr("1 Punkt frei")
	_points.add_theme_color_override("font_color", UiTheme.COIN if game.points > 0 else UiTheme.MUTED)
	for id in _rows:
		var r: Dictionary = _rows[id]
		var lvl: int = game.elements.get(id, 0)
		var cap: int = game.element_caps.get(id, 4)
		var pips: HBoxContainer = r.pips
		for i in pips.get_child_count():
			var p: ColorRect = pips.get_child(i)
			if i < lvl:
				p.color = r.color
			elif i < cap:
				p.color = UiTheme.BORDER_2
			else:
				p.color = Color(UiTheme.BORDER, 0.35)
		var plus: Button = r.plus
		plus.disabled = not game.can_add_point(id)
	_refresh_traps()
	_log.text = "\n".join(game.log_lines)
	refresh_timer()


func refresh_timer() -> void:
	if _next == null:
		return
	var waiting: bool = game.phase == game.Phase.BUILD and game.setup_done
	_next.visible = waiting
	if waiting:
		var secs := ceili(maxf(game.level_pause, 0.0))
		if game.players.size() > 1:
			# Koop: das Level startet früher, wenn alle bereit sind
			var here: Array = range(game.players.size()).filter(func(i): return not game.players[i].away)
			var ready: int = here.filter(func(i): return game.ready_players.has(i)).size()
			_next.text = tr("Bereit %d/%d · %d s") % [ready, here.size(), secs]
			_next.disabled = game.ready_players.has(game.local_player)
		else:
			_next.text = tr("Level %d starten · %d s") % [game.wave_index + 1, secs]


## Knöpfe für die Fallen der Elemente auf Stufe 4 oder höher; neu gebaut nur, wenn sich etwas ändert.
func _refresh_traps() -> void:
	var list := []
	for id in game.trap_ids():
		var e: Dictionary = Database.towers[id].eeve
		if game.elements.get(str(e.element), 0) >= int(e.level):
			list.append([id, game.trap_reason(id)])
	var key: String = str(list) + game.placing_trap
	if key == _traps_key:
		return
	_traps_key = key
	for c in _traps.get_children():
		_traps.remove_child(c)
		c.queue_free()
	if list.is_empty():
		var hint := UiUtil.wrap_label(tr("Fallen gibt es ab Elementstufe 4."), _traps, 256)
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	for entry in list:
		var id: String = entry[0]
		var e: Dictionary = Database.towers[id].eeve
		var text := "%s · %d G + %d %s" % [Database.tower_label(id, 0), int(e.cost), int(e.lumber), tr("Holz")]
		var b := UiUtil.button(text, _traps, func(): game.start_trap_placement(id))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(256, 30)
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = entry[1] != "" and game.placing_trap != id
		b.tooltip_text = Database.tower_label(id, 0) + "\n" + "\n".join(
				(Database.tower_tier(id, 0).get("abilities", []) as Array).map(func(ab): return Abilities.describe(ab)))
		if entry[1] != "":
			b.tooltip_text += "\n" + str(entry[1])
		if game.placing_trap == id:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.BG)
			b.add_theme_color_override("font_hover_color", UiTheme.BG)
