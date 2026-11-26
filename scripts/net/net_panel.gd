class_name NetPanel
extends CanvasLayer
## Mehrspieler im Spiel: Liste der Mitspieler (rechts unten) mit „Zuschauen“, und die
## Zuschau-Leiste oben. Beim Zuschauen wird das eigene Feld samt HUD ausgeblendet und
## remote_field.gd zeigt das Feld des Mitspielers; das eigene Spiel läuft weiter.

const PHASE_NAMES := ["Bauphase", "Auswahl", "Welle", "Verloren", "Gewonnen"]

var game  # game.gd
var watching := 0
var remote: RemoteField = null

var _list: VBoxContainer
var panel: PanelContainer  ## Mitspieler-Liste rechts unten
var avoid: Control  ## Auswahlkarte unten: die Liste rückt darüber, wenn die Karte bis unter sie reicht
var _fold: Button
var _bar: PanelContainer
var _bar_title: Label
var _bar_info: Label
var _own_info: Label
var _refresh_timer := 0.0
var _reframed := false


func _ready() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.BAR, 0.94), UiTheme.BORDER, 8, 1, 12))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_right = -16
	panel.offset_bottom = -16
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size.x = 280
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	UiTheme.caption("Mitspieler", head).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fold = Button.new()
	_fold.text = "–"
	_fold.focus_mode = Control.FOCUS_NONE
	_fold.tooltip_text = "Ein-/ausklappen"
	_fold.pressed.connect(func():
		_list.visible = not _list.visible
		_fold.text = "–" if _list.visible else "+")
	head.add_child(_fold)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)

	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.BAR, 0.94), UiTheme.GOLD, 20, 1, 16))
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.offset_top = 16
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_bar.add_child(h)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	h.add_child(texts)
	_bar_title = UiUtil.label("", texts, 16)
	_bar_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_bar_info = UiUtil.label("", texts, 14)
	_own_info = UiUtil.label("", texts, 14)
	_own_info.add_theme_color_override("font_color", UiTheme.MUTED)
	var back := UiUtil.button("Zurück zum eigenen Feld (Esc)", h, stop)
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.hide()

	Net.players_changed.connect(_rebuild_list)
	Net.connection_changed.connect(_on_connection_changed)
	Net.map_received.connect(_on_map)
	Net.field_received.connect(_on_field)
	Net.enemies_received.connect(_on_enemies)
	_rebuild_list()


func _on_map(peer: int, data: Dictionary) -> void:
	if peer == watching and remote:
		remote.apply_map(data)
		_frame_camera()


func _on_field(peer: int, data: Dictionary) -> void:
	if peer == watching and remote:
		remote.apply_field(data)
		_update_bar()


func _on_enemies(peer: int, data: Dictionary) -> void:
	if peer == watching and remote:
		remote.apply_enemies(data)


## Über der Auswahlkarte bleiben, sonst verdeckt die Liste deren Aktionsknöpfe (z. B. „Zurücknehmen“).
func _avoid_card() -> void:
	var bottom := -16.0
	if avoid != null and avoid.is_visible_in_tree():
		var card := avoid.get_global_rect()
		if card.end.x > panel.global_position.x:
			bottom = card.position.y - 12.0 - panel.get_parent_area_size().y
	if absf(panel.offset_bottom - bottom) > 0.5:
		panel.offset_bottom = bottom


func _exit_tree() -> void:
	if watching != 0:
		Net.watch(watching, false)


func _process(delta: float) -> void:
	_avoid_card()
	_refresh_timer -= delta / maxf(Engine.time_scale, 0.01)
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_update_bar()


func _unhandled_input(event: InputEvent) -> void:
	if watching == 0:
		return
	# Beim Zuschauen keine Klicks und Aktionstasten aufs eigene Feld; Kamera und Tempo bleiben frei
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				stop()
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_R:
				get_viewport().set_input_as_handled()


func spectate(peer: int) -> void:
	if peer == watching:
		return
	if watching != 0:
		Net.watch(watching, false)
		remote.queue_free()
	watching = peer
	remote = RemoteField.new()
	remote.peer = peer
	game.add_child(remote)
	game.board.visible = false
	game.hud.visible = false
	Net.watch(peer, true)
	_bar.show()
	_update_bar()
	_rebuild_list()


func stop() -> void:
	if watching == 0:
		return
	Net.watch(watching, false)
	watching = 0
	if remote:
		remote.queue_free()
		remote = null
	game.board.visible = true
	game.hud.visible = true
	if _reframed:
		_reframed = false
		game.camera_rig.frame_map(game.map.width * Board3D.CELL, game.map.height * Board3D.CELL)
	_bar.hide()
	_rebuild_list()


func _frame_camera() -> void:
	if remote == null or remote.map == null:
		return
	if remote.map.width != game.map.width or remote.map.height != game.map.height or _reframed:
		_reframed = true
		game.camera_rig.frame_map(remote.map.width * Board3D.CELL, remote.map.height * Board3D.CELL)


func _on_connection_changed() -> void:
	if not Net.is_active():
		stop()
	_rebuild_list()


static func status_text(s: Dictionary) -> String:
	if not s.get("in_game", false):
		return TranslationServer.translate("im Menü")
	var phase := int(s.get("phase", 0))
	var wave := [int(s.get("wave", 1)), int(s.get("waves", 0))]
	var parts := []
	if phase == 2:
		parts.append(TranslationServer.translate("Welle %d/%d läuft") % wave)
	else:
		parts.append(TranslationServer.translate(PHASE_NAMES[clampi(phase, 0, PHASE_NAMES.size() - 1)]))
		parts.append(TranslationServer.translate("Welle %d/%d") % wave)
	if s.get("score_mode", false):
		parts.append(TranslationServer.translate("Punkte %d") % int(s.get("score", 0)))
	else:
		parts.append(TranslationServer.translate("Leben %d") % int(s.get("lives", 0)))
	return " · ".join(parts)


func _rebuild_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if watching != 0 and not Net.player_status(watching).get("in_game", false):
		stop.call_deferred()
	var ids := Net.players.keys()
	ids.sort()
	if ids.is_empty():
		UiUtil.label("Niemand verbunden", _list, 14).add_theme_color_override("font_color", UiTheme.MUTED)
	for id in ids:
		var s := Net.player_status(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		row.add_child(texts)
		UiUtil.label(Net.player_name(id), texts, 14)
		var info := UiUtil.label(status_text(s), texts, 14)
		info.add_theme_color_override("font_color", UiTheme.MUTED)
		var peer: int = id
		var b: Button
		if peer == watching:
			b = UiUtil.button("Zurück", row, stop)
		else:
			b = UiUtil.button("Zuschauen", row, func(): spectate(peer))
			b.disabled = not s.get("in_game", false)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _update_bar() -> void:
	if watching == 0:
		return
	_bar_title.text = tr("Du schaust %s zu") % Net.player_name(watching)
	var f: Dictionary = remote.field if remote else {}
	if f.is_empty():
		_bar_info.text = tr("Warte auf Daten …")
	else:
		var diff: Array = Session.DIFFICULTIES
		var parts := [status_text(f), tr("Gold %d") % int(f.get("gold", 0)), tr("Chance %d") % int(f.get("chance", 0)),
			tr(str(diff[clampi(int(f.get("difficulty", 1)), 0, diff.size() - 1)].name))]
		_bar_info.text = " · ".join(parts)
	_own_info.text = tr("Dein Spiel: %s") % status_text({"in_game": true, "phase": game.phase,
		"wave": mini(game.current_wave(), game.waves.size()), "waves": game.waves.size(), "lives": game.lives})
