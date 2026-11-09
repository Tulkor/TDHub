class_name EeveSetupPanel
extends Control
## Einstellungen vor dem ersten Level von eeveTD: Schwierigkeit und Feldtyp (data/eeve.json).
## „Los geht's“ schickt den Befehl setup an eeve_game.gd; das Fenster schließt sich, sobald game.setup_done gilt.
## Koop: oben die Mitspieler, nur der Host wählt, die anderen warten (ihr Fenster schließt der Stand vom Host).

var game  # eeve_game.gd
var difficulty := 2
var field := 0
var _diff_text: Label
var _field_text: Label
var _asc: AscensionPicker


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	difficulty = Ascension.snap("eeve", game.difficulty, game.difficulty_count())
	field = game.field_type
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(24.0))
	panel.custom_minimum_size.x = 640
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	UiTheme.title(UiUtil.label("eeveTD", v, 26))
	var info := UiUtil.wrap_label(tr("%d Level · Barrikaden bauen, zu Element-Towern aufwerten, Elementpunkte verteilen") % int(game.rules.get("levels", 57)), v, 590)
	info.add_theme_color_override("font_color", UiTheme.MUTED)
	var coop: bool = game.players.size() > 1
	if coop:
		_coop_box(v)

	UiTheme.caption("Schwierigkeit", v)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var group := ButtonGroup.new()
	var diffs: Array = game.rules.get("difficulties", [])
	for i in Ascension.choices("eeve", diffs.size()):
		var idx: int = i
		_toggle(str(diffs[i].name), grid, group, i == difficulty, func():
			difficulty = idx
			_asc.set_difficulty(idx)
			_update_text())
	_diff_text = UiUtil.wrap_label("", v, 590)
	_diff_text.add_theme_color_override("font_color", UiTheme.DIM)
	_asc = AscensionPicker.new().setup("eeve", diffs.size(), difficulty, int(Session.ascension_choice.get("eeve", 0)), not game.mirror, false, 590)
	v.add_child(_asc)

	UiTheme.caption("Feld", v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	group = ButtonGroup.new()
	var fields: Array = game.rules.get("fields", [])
	for i in fields.size():
		var idx := i
		_toggle(str(fields[i].name), h, group, i == field, func():
			field = idx
			_update_text())
	_field_text = UiUtil.wrap_label("", v, 590)
	_field_text.add_theme_color_override("font_color", UiTheme.DIM)
	_update_text()

	if game.mirror:
		for b in grid.get_children() + h.get_children():
			b.disabled = true
		var wait := UiUtil.wrap_label("Der Host wählt Schwierigkeit und Feld, gleich geht es los …", v, 590)
		wait.add_theme_color_override("font_color", UiTheme.CYAN)
		SetupPanel.bottom_row(game, v)
		return
	var go := UiUtil.button("Los geht's", SetupPanel.bottom_row(game, v), func():
		Session.ascension_choice["eeve"] = _asc.level
		game.submit({"type": "setup", "difficulty": difficulty, "field": field, "ascension": _asc.chosen()}))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size.y = 50
	go.add_theme_font_size_override("font_size", 20)
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)


## Koop: Mitspieler und was für alle gilt.
func _coop_box(v: VBoxContainer) -> void:
	UiTheme.caption(tr("Koop · %d Spieler") % game.players.size(), v)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 6)
	v.add_child(names)
	for i in game.players.size():
		var p: PlayerState = game.players[i]
		var b := PanelContainer.new()
		var own: bool = i == game.local_player
		b.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CYAN if own else UiTheme.PANEL, UiTheme.CYAN if own else UiTheme.BORDER, 0, 2, 6))
		names.add_child(b)
		var l := UiUtil.label((p.name if p.name != "" else tr("Spieler %d") % (i + 1)) + (" · Host" if i == 0 else ""), b, 14)
		l.add_theme_color_override("font_color", UiTheme.GOLD_DARK if own else UiTheme.TEXT)
	var extra := roundi((game.coop_hp_factor() - 1.0) * 100)
	var rules := UiUtil.wrap_label(tr("Ein Feld, gemeinsame Leben. Jeder hat eigenes Gold, Food, Holz und eigene Elementpunkte und wertet nur seine Tower auf. Gegner +%d %% Leben.") % extra, v, 590)
	rules.add_theme_color_override("font_color", UiTheme.MUTED)


func _process(_delta: float) -> void:
	if game.setup_done:
		queue_free()


func _update_text() -> void:
	var d: Dictionary = game.rules.difficulties[difficulty]
	var armor: Array = d.get("armor", [0])
	var spells := roundi((1.0 - float(d.get("spells", 1.0))) * 100)
	_diff_text.text = tr("Gegner-Leben %d %% · Rüstung +%d bis +%d · Zauberschaden −%d %% · Punkte ×%s · Pause %d s") % [
		roundi(float(d.hp) * 100), int(armor[0]), int(armor[-1]), spells, str(d.score), int(d.pause)]
	var f: Dictionary = game.rules.fields[field]
	var text := tr("Leeres Feld.") if int(f.rocks) == 0 else tr("Bis zu %d zufällige Felsen, die man umbauen muss.") % int(f.rocks)
	if int(f.get("bonus", 0)) > 0:
		text += " " + tr("Feldbonus am Ende: %d Punkte × Punktefaktor.") % int(f.bonus)
	var tiles: Array = (game.rules.get("bonus_tiles", []) as Array).map(func(k): return tr(str(k.name)) + " " + tr(str(k.text)))
	text += "\n" + tr("Je %d Bonusfelder: %s. Der Tower muss genau darauf stehen.") % [int(f.get("tiles", 0)), " · ".join(tiles)]
	_field_text.text = text


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
