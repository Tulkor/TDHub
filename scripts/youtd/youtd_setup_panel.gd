class_name YoutdSetupPanel
extends Control
## Einstellungen vor der ersten Welle von YouTD: Spielmodus, Länge, Schwierigkeit, Weisheits-Boni und Baumeister
## (je 6 Spielerlevel ein Punkt, die Wahl bleibt im Profil). Oben Spielerlevel und Erfahrung.
## „Los geht's“ schickt den Befehl setup an youtd_game.gd; das Fenster schließt sich, sobald game.setup_done gilt.
## Koop: Modus, Länge und Schwierigkeit wählt der Host, Weisheit und Baumeister jeder selbst („Bereit“ schickt
## player_setup); das Fenster eines Mitspielers bleibt, bis er bereit ist oder die erste Welle läuft.

var game  # youtd_game.gd
var mode := 0
var length := 1
var difficulty := 2
var wisdom: Array = []
var builder := ""
var foreign := false
var _mode_text: Label
var _builder_text: Label
var _diff_text: Label
var _asc: AscensionPicker
var _wisdom_head: Label
var _wisdom_buttons := {}
var _sent := false
var _wait: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var last: Dictionary = Session.get_meta("youtd_choice", {})
	mode = int(last.get("mode", game.mode_index))
	length = int(last.get("length", game.length_index))
	difficulty = Ascension.snap("youtd", int(last.get("difficulty", game.difficulty)), game.difficulty_count())
	wisdom = YoutdProgress.wisdom()
	builder = YoutdProgress.last_builder() if YoutdProgress.builder_open(YoutdProgress.last_builder()) else ""
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(24.0))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(760, mini(860, int(get_viewport_rect().size.y) - 120))
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	UiTheme.title(UiUtil.label("YouTD", v, 26))
	var lvl := YoutdProgress.level()
	var next := YoutdProgress.xp_to_next()
	var who := tr("Spielerlevel %d · %s XP") % [lvl, TowerStats.num(YoutdProgress.xp(), 0)]
	if next > 0.0:
		who += " · " + tr("noch %s XP bis Level %d") % [TowerStats.num(next, 0), lvl + 1]
	var info := UiUtil.wrap_label(who, v, 700)
	info.add_theme_color_override("font_color", UiTheme.COIN)
	var open := YoutdProgress.builders().filter(func(b): return b.open).size()
	var hint := UiUtil.wrap_label(tr("Punkte am Ende einer Partie werden zu Spieler-XP. Je 6 Level gibt es einen Weisheits-Punkt. Baumeister: %d von %d freigeschaltet.") % [open, YoutdData.builders().size()], v, 700)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)

	UiTheme.caption("Spielmodus", v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var host_only: Array = []
	var group := ButtonGroup.new()
	var modes: Array = game.rules.get("modes", [])
	for i in modes.size():
		var idx := i
		host_only.append(_toggle(str(modes[i].name), row, group, i == mode, func():
			mode = idx
			_update_text()))
	_mode_text = UiUtil.wrap_label("", v, 700)
	_mode_text.add_theme_color_override("font_color", UiTheme.DIM)

	UiTheme.caption("Länge", v)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	group = ButtonGroup.new()
	var lengths: Array = game.rules.get("lengths", [])
	for i in lengths.size():
		var idx := i
		host_only.append(_toggle(tr("%s · %d Wellen") % [tr(str(lengths[i].name)), int(lengths[i].waves)], row, group, i == length, func():
			length = idx
			_update_text()))

	UiTheme.caption("Schwierigkeit", v)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	group = ButtonGroup.new()
	var diffs: Array = game.rules.get("difficulties", [])
	for i in Ascension.choices("youtd", diffs.size()):
		var idx: int = i
		host_only.append(_toggle(str(diffs[i].name), row, group, i == difficulty, func():
			difficulty = idx
			_asc.set_difficulty(idx)
			_update_text()))
	_diff_text = UiUtil.wrap_label("", v, 700)
	_diff_text.add_theme_color_override("font_color", UiTheme.DIM)
	_asc = AscensionPicker.new().setup("youtd", diffs.size(), difficulty, int(Session.ascension_choice.get("youtd", 0)), not game.mirror, false, 700)
	v.add_child(_asc)
	foreign = Session.foreign_build
	host_only.append_array(SetupPanel.add_foreign_choice(self, v, true))

	_wisdom_head = UiTheme.caption("", v)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for w in game.rules.get("wisdom", []):
		var id := str(w.id)
		var b := UiUtil.button(str(w.name), grid, func(): _toggle_wisdom(id))
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(228, 34)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		b.tooltip_text = str(w.name) + "\n" + tr(str(w.get("text", "")))
		b.set_pressed_no_signal(wisdom.has(id))
		_wisdom_buttons[id] = b

	UiTheme.caption("Baumeister", v)
	var bgrid := GridContainer.new()
	bgrid.columns = 3
	bgrid.add_theme_constant_override("h_separation", 6)
	bgrid.add_theme_constant_override("v_separation", 6)
	v.add_child(bgrid)
	var bgroup := ButtonGroup.new()
	var none := _toggle(tr("Keiner"), bgrid, bgroup, builder == "", func():
		builder = ""
		_update_text())
	none.custom_minimum_size = Vector2(228, 34)
	for b in YoutdProgress.builders():
		var id := str(b.id)
		var bb := _toggle(str(b.name), bgrid, bgroup, builder == id, func():
			builder = id
			_update_text())
		bb.custom_minimum_size = Vector2(228, 34)
		bb.clip_text = true
		bb.add_theme_font_size_override("font_size", 13)
		bb.disabled = not bool(b.open)
		bb.tooltip_text = str(b.name) + "\n" + builder_text(id) + ("" if b.open else "\n" + tr("Ab Spielerlevel %d") % int(b.level))
	_builder_text = UiUtil.wrap_label("", v, 700)
	_builder_text.add_theme_color_override("font_color", UiTheme.DIM)
	_update_text()

	if game.players.size() > 1:
		var coop_hint := UiUtil.wrap_label(tr("Koop: jeder hat seinen eigenen Weg, sein Gebiet, Gold und Bücher; Portal und Wellen-Timer sind gemeinsam. Weisheit und Baumeister wählt jeder selbst."), v, 700)
		coop_hint.add_theme_color_override("font_color", UiTheme.CYAN)
	if game.mirror:
		for b in host_only:
			b.disabled = true
		var rb := UiUtil.button("Bereit", SetupPanel.bottom_row(game, v), _ready_up)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.custom_minimum_size.y = 50
		rb.add_theme_font_size_override("font_size", 20)
		UiTheme.accent_button(rb, UiTheme.GOLD, UiTheme.GOLD_DARK)
		_wait = UiUtil.wrap_label(tr("Modus, Länge und Schwierigkeit wählt der Host."), v, 700)
		_wait.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	var go := UiUtil.button("Los geht's", SetupPanel.bottom_row(game, v), _start)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size.y = 50
	go.add_theme_font_size_override("font_size", 20)
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)


func _start() -> void:
	YoutdProgress.set_wisdom(wisdom)
	YoutdProgress.set_last_builder(builder)
	Session.ascension_choice["youtd"] = _asc.level
	game.submit({"type": "setup", "mode": mode, "length": length, "difficulty": difficulty, "seed": randi(), "wisdom": wisdom.duplicate(),
			"builder": builder, "foreign": foreign, "level": YoutdProgress.level(), "ascension": _asc.chosen()})


## Mitspieler: eigene Weisheit und eigenen Baumeister an den Host schicken.
func _ready_up() -> void:
	if _sent:
		return
	_sent = true
	YoutdProgress.set_wisdom(wisdom)
	YoutdProgress.set_last_builder(builder)
	game.submit({"type": "player_setup", "wisdom": wisdom.duplicate(), "builder": builder, "level": YoutdProgress.level()})
	_wait.text = tr("Bereit. Warte auf den Host …")


func _toggle_wisdom(id: String) -> void:
	if wisdom.has(id):
		wisdom.erase(id)
	elif wisdom.size() < YoutdProgress.wisdom_points():
		wisdom.append(id)
	_update_text()


func _process(_delta: float) -> void:
	if game.setup_done and (not game.mirror or _sent or game.next_wave > 1):
		queue_free()


func _update_text() -> void:
	var m: Dictionary = game.rules.modes[mode]
	_mode_text.text = tr(str(m.get("text", ""))) + " " + tr("Verkauf %d %% · Punkte ×%s") % [roundi(float(m.sell) * 100), TowerStats.num(float(m.score) * float(game.rules.lengths[length].score), 2)]
	var d: Dictionary = game.rules.difficulties[difficulty]
	_diff_text.text = tr("Punkte ×%s · Gegner-Leben und Rüstung steigen mit der Schwierigkeit.") % TowerStats.num(float(d.score), 1)
	var points := YoutdProgress.wisdom_points()
	_wisdom_head.text = tr("Weisheit · %d von %d Punkten verteilt") % [wisdom.size(), points]
	for id in _wisdom_buttons:
		var b: Button = _wisdom_buttons[id]
		b.set_pressed_no_signal(wisdom.has(id))
		b.disabled = not wisdom.has(id) and wisdom.size() >= points
	_builder_text.text = (tr("Ohne Baumeister: keine Sonderregeln.") if builder == "" else builder_text(builder))


## Beschreibung eines Baumeisters (rules.json → builders).
func builder_text(id: String) -> String:
	return tr(str(game.rules.get("builders", {}).get(id, {}).get("text", "")))


func _toggle(text: String, parent: Node, group: ButtonGroup, on: bool, pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, pressed)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(120, 38)
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	b.set_pressed_no_signal(on)
	return b
