class_name RgSetupPanel
extends Control
## Einstellungen vor dem ersten Level von Randgruppen TD: Rasse (11 Karten mit ihren 7 Towern) und Schwierigkeit
## (= Leben, data/randgruppen.json). „Los geht's“ schickt den Befehl setup an rg_game.gd; das Fenster schließt sich,
## sobald die eigene Wahl beim Host angekommen ist (im Koop wählt jeder seine Rasse, nur der Host die Schwierigkeit).

var game  # rg_game.gd
var race_id := ""
var difficulty := 2
var foreign := false
var share := false
var _race_text: Label
var _diff_text: Label
var _asc: AscensionPicker
var _panel: PanelContainer
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var races: Array = game.rules.get("races", [])
	race_id = str(Session.rg_choice.get("race", races[0].id if not races.is_empty() else ""))
	difficulty = Ascension.snap("randgruppen", game.difficulty, game.difficulty_count())
	foreign = Session.foreign_build
	share = bool(Session.rg_choice.get("share", false))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	_panel = panel
	panel.set_meta("own_vandal", true)
	panel.add_theme_stylebox_override("panel", UiTheme.panel(24.0))
	panel.custom_minimum_size.x = 820
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	_title = UiTheme.title(UiUtil.label("Randgruppen TD", v, 26))
	var info := UiUtil.wrap_label(tr("Die Randgruppen der Stadt verteidigen die Hochburg der Toleranz gegen die Spießer: %d Level, Tower frei in deine Zone bauen, die Gegner laufen hindurch.") % game.waves.size(), v, 770)
	info.add_theme_color_override("font_color", UiTheme.MUTED)

	UiTheme.caption("Rasse", v)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var group := ButtonGroup.new()
	for r in races:
		var id := str(r.id)
		var b := _toggle(str(r.name), grid, group, id == race_id, func():
			race_id = id
			_update_text())
		b.tooltip_text = tr(str(r.hint))
		# Rassen mit eigenem Look zeigen ihn schon auf dem Knopf (Schrift aus RgVandal)
		var look: Dictionary = r.get("look", {})
		if int(look.get("vandal", 0)) >= 3 and RgVandal.FONTS.has(str(look.style)):
			b.add_theme_font_override("font", load(RgVandal.FONTS[str(look.style)]))
			b.add_theme_font_size_override("font_size", 17)
		# Rassenfarben sind für dunkle Flächen gedacht, auf dem Plakatpapier abgedunkelt
		b.add_theme_color_override("font_color", Color(str(r.color)).darkened(0.45))
	_race_text = UiUtil.wrap_label("", v, 770)

	UiTheme.caption("Schwierigkeit", v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	group = ButtonGroup.new()
	var diffs: Array = game.rules.get("difficulties", [])
	for i in Ascension.choices("randgruppen", diffs.size()):
		var idx: int = i
		var b := _toggle(str(diffs[i].name), h, group, i == difficulty, func():
			difficulty = idx
			_asc.set_difficulty(idx)
			_update_text())
		b.custom_minimum_size.x = 140
		b.disabled = game.local_player != 0
	_diff_text = UiUtil.wrap_label("", v, 770)
	_diff_text.add_theme_color_override("font_color", UiTheme.DIM)
	_asc = AscensionPicker.new().setup("randgruppen", diffs.size(), difficulty, int(Session.ascension_choice.get("randgruppen", 0)),
		game.local_player == 0, false, 770)
	v.add_child(_asc)
	_update_text()

	SetupPanel.add_foreign_choice(self, v, game.local_player == 0)

	# Kopfgeld wie die Option „Geldteilen“ in Shopping Maul; wählt der Host
	UiTheme.caption("Kopfgeld", v)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	v.add_child(sh)
	group = ButtonGroup.new()
	for m in [[false, "Jeder für sich", "Das Kopfgeld bekommt, wessen Tower den Gegner erledigt."],
			[true, "Geldteilen", "Das Kopfgeld jedes Kills wird gleich an alle verteilt."]]:
		var on: bool = m[0]
		var b := _toggle(str(m[1]), sh, group, on == share, func(): share = on)
		b.tooltip_text = str(m[2])
		b.disabled = game.local_player != 0

	var go := UiUtil.button("Los geht's", SetupPanel.bottom_row(game, v), func():
		if game.local_player == 0:
			Session.ascension_choice["randgruppen"] = _asc.level
		game.submit({"type": "setup", "race": race_id, "difficulty": difficulty, "foreign": foreign, "share": share, "ascension": _asc.chosen()}))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size.y = 50
	go.add_theme_font_size_override("font_size", 20)
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)


func _process(_delta: float) -> void:
	if game.setup_done or game.rp(game.local_player).chosen:
		queue_free()


func _update_text() -> void:
	var r: Dictionary = game.race(race_id)
	# das Fenster nimmt den Look der gewählten Rasse an: Verschmierungen und Titel in ihrer Schrift
	var look: Dictionary = r.get("look", {})
	RgVandal.apply(_panel, look, 3)
	if int(look.get("vandal", 0)) >= 3 and RgVandal.FONTS.has(str(look.style)):
		_title.add_theme_font_override("font", load(RgVandal.FONTS[str(look.style)]))
		_title.add_theme_color_override("font_color", Color(str(r.color)))
		_title.add_theme_font_size_override("font_size", 34)
		_title.add_theme_constant_override("outline_size", 6)
		_title.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08))
	else:
		_title.remove_theme_font_override("font")
		UiTheme.title(_title, 26)
		_title.remove_theme_constant_override("outline_size")
	var names: Array = r.get("towers", []).map(func(id): return Database.tower_label(id, 0))
	_race_text.text = tr(str(r.get("hint", ""))) + "\n" + tr("Tower: ") + ", ".join(names)
	var d: Dictionary = game.rules.difficulties[difficulty]
	_diff_text.text = tr("%d Leben für alle zusammen. Start mit %d Gold (550 minus 500 für den Baumeister).") % [int(d.lives), game.start_gold()]
	if game.local_player != 0:
		_diff_text.text = tr("Die Schwierigkeit wählt der Host.") + " " + _diff_text.text


func _toggle(text: String, parent: Node, group: ButtonGroup, on: bool, pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, pressed)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(190, 38)
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	b.set_pressed_no_signal(on)
	return b
