class_name MaulSetup
extends ColorRect
## Vor Level 1: Schwierigkeit, Modus und Filiale wählen („Filiale eröffnen“).
## Zwei Reiter: die 11 Standard-Filialen und die 9 Profi-Filialen (ab 25 XP und nur mit Speziallevels).
## Im Koop wählt der Host Schwierigkeit, Modus, Sandbox, „Überall bauen“ und Geldteilen, jeder Mitspieler nur seine Filiale.

const CARD_WIDTH := 236.0

var game: MaulGame
var _shop := ""
var _kind := "standard"
var _difficulty := 1
var _mode := "group"
var _sandbox := false
var _foreign := false
var _share := false
var _waiting := false      ## Mitspieler hat gewählt, der Host hat noch nicht gestartet
var _cards := {}
var _diff_buttons: Array = []
var _mode_buttons: Array = []
var _kind_buttons := {}
var _sandbox_button: Button
var _foreign_button: Button
var _share_button: Button
var _grid: GridContainer
var _detail: Label
var _xp: Label
var _open: Button
var _asc: AscensionPicker
var _diff_ids: Array = []   ## Schwierigkeit je Knopf in _diff_buttons


func _ready() -> void:
	color = Color(DecoTheme.BAR, 0.85)
	theme = DecoTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_difficulty = int(MaulData.rules().get("default_difficulty", 1))
	# Neustart: die Wahl der letzten Runde vorauswählen
	var last: Dictionary = Session.maul_choice
	_difficulty = Ascension.snap("maul", int(last.get("difficulty", _difficulty)), _diff_count())
	_mode = str(last.get("mode", _mode))
	_sandbox = bool(last.get("sandbox", _sandbox))
	_foreign = bool(last.get("foreign", _foreign))
	_share = bool(last.get("share", _share))
	_kind = str(last.get("kind", _kind))
	_shop = str(last.get("shop", _shop))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DecoTheme.panel(20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	box.add_child(head)
	var title := DecoTheme.title(UiUtil.label("Filiale eröffnen", head), 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp = UiUtil.label("", head, 15)
	_xp.add_theme_font_override("font", DecoTheme.font(true))
	_xp.add_theme_color_override("font_color", DecoTheme.PURPLE_LIGHT)
	_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var profile := UiUtil.button("Profil", head, _show_profile)
	profile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	profile.tooltip_text = "Erfahrung, Freischaltungen und Rekorde je Filiale. Bleiben über alle Partien erhalten."

	if not game.mirror:
		var opts := HBoxContainer.new()
		opts.add_theme_constant_override("separation", 30)
		box.add_child(opts)
		var diff_box := VBoxContainer.new()
		opts.add_child(diff_box)
		DecoTheme.caption("Schwierigkeit", diff_box)
		var diff_row := HBoxContainer.new()
		diff_box.add_child(diff_row)
		var diffs: Array = MaulData.rules().get("difficulties", [])
		for i in Ascension.choices("maul", diffs.size()):
			var d: Dictionary = diffs[i]
			var b := _toggle(str(d.name), diff_row, _set_difficulty.bind(i))
			b.tooltip_text = tr("%d Leben, Gegner-Leben ×%s") % [int(d.lives), TowerStats.num(float(d.factor), 2)]
			_diff_buttons.append(b)
			_diff_ids.append(i)
		var mode_box := VBoxContainer.new()
		opts.add_child(mode_box)
		DecoTheme.caption("Modus", mode_box)
		var mode_row := HBoxContainer.new()
		mode_box.add_child(mode_row)
		for m in [["group", "Gruppe", "Alle Gegner eines Levels kommen auf einmal."], ["line", "Linie", "Die Gegner kommen nacheinander, alle 0,8 s einer pro Spawn."]]:
			var id: String = m[0]
			var b := _toggle(m[1], mode_row, _set_mode.bind(id))
			b.tooltip_text = m[2]
			_mode_buttons.append([b, id])
		var sb_box := VBoxContainer.new()
		opts.add_child(sb_box)
		DecoTheme.caption("Übungsrunde", sb_box)
		_sandbox_button = _toggle("Sandbox", sb_box, func():
			_sandbox = not _sandbox
			_refresh())
		_sandbox_button.tooltip_text = "Zum Ausprobieren: 800 XP (alles freigeschaltet), Durchbrüche kosten keine Leben, es gibt keine neuen XP."
		var zone_box := VBoxContainer.new()
		opts.add_child(zone_box)
		DecoTheme.caption("Fremde Gebiete", zone_box)
		_foreign_button = _toggle("Überall bauen", zone_box, func():
			_foreign = not _foreign
			_refresh())
		_foreign_button.tooltip_text = "An: alle dürfen Tower auch in den Gebieten der anderen (und in leeren Gebieten) bauen und Einheiten dort aufstellen. Aus: nur im eigenen Gebiet."
		var share_box := VBoxContainer.new()
		opts.add_child(share_box)
		DecoTheme.caption("Kopfgeld", share_box)
		_share_button = _toggle("Geldteilen", share_box, func():
			_share = not _share
			_refresh())
		_share_button.tooltip_text = "An: das Kopfgeld aller Kills kommt in einen Topf und wird gleich an alle verteilt, das Einkommen ist für alle gleich. Aus: Kopfgeld bekommt, wer trifft, dafür gleicht der Konzernbonus das Einkommen nach Kills aus."
		_asc = AscensionPicker.new().setup("maul", _diff_count(), _difficulty, int(Session.ascension_choice.get("maul", 0)), true, true, CARD_WIDTH * 4 + 30)
		box.add_child(_asc)
	else:
		var info := UiUtil.wrap_label("Koop: der Host wählt Schwierigkeit und Modus, jeder eröffnet seine eigene Filiale in seinem Gebiet. Die Leben sind gemeinsam.", box, CARD_WIDTH * 4 + 30)
		info.add_theme_color_override("font_color", DecoTheme.CYAN)
		info.add_theme_font_size_override("font_size", 14)

	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 6)
	box.add_child(kinds)
	for e in [["standard", "Standard-Filialen"], ["pro", "Profi-Filialen"]]:
		var k: String = e[0]
		_kind_buttons[k] = _toggle(e[1], kinds, func():
			_kind = k
			_shop = ""
			_build_cards())
		_kind_buttons[k].custom_minimum_size.x = 220
	_kind_buttons["pro"].tooltip_text = "Ab 25 XP"

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.custom_minimum_size.y = 112 * 3 + 20
	box.add_child(_grid)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	box.add_child(bottom)
	_detail = UiUtil.label("", bottom, 14)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiUtil.button("Zurück zum Menü", bottom, func(): Session.goto(Session.MAIN_MENU)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_open = UiUtil.button("Filiale eröffnen", bottom, _start)
	_open.custom_minimum_size = Vector2(340, 58)
	_open.add_theme_font_size_override("font_size", 28)
	_open.clip_text = true
	DecoTheme.accent_button(_open)
	_build_cards()


func _toggle(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, on_pressed)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("pressed", DecoTheme.box(DecoTheme.CYAN, DecoTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", DecoTheme.GOLD_DARK)
	return b


func _build_cards() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cards.clear()
	for s in MaulData.shops():
		if str(s.kind) == _kind:
			_add_card(str(s.id), str(s.name), tr(str(s.get("text", ""))), Color.from_string(str(s.color), DecoTheme.GOLD), str(s.bonus))
	if _kind == "pro":
		_add_card("random_pro", tr("Profi-Zufall"), tr("Eine der 9 Profi-Filialen"), DecoTheme.PURPLE_LIGHT, "")
	else:
		_add_card("random", tr("Zufall"), tr("Eine der 11 Standard-Filialen"), DecoTheme.PURPLE_LIGHT, "")
	_refresh()


func _add_card(id: String, name: String, text: String, col: Color, bonus: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_WIDTH, 112)
	b.toggle_mode = true
	b.pressed.connect(_set_shop.bind(id))
	_grid.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	m.add_child(v)
	var title := UiUtil.label(name.to_upper(), v, 14)
	title.add_theme_font_override("font", DecoTheme.font(true))
	title.add_theme_color_override("font_color", col)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var short := _short(text)
	var info := UiUtil.label(short, v, 13)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.custom_minimum_size.x = CARD_WIDTH - 20
	info.max_lines_visible = 5
	info.add_theme_color_override("font_color", DecoTheme.DIM)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.tooltip_text = text.replace("  ", "\n")
	var rec := MaulProfile.shop(id)
	if int(rec.games) > 0:
		b.tooltip_text += "\n\n" + tr("Dein Rekord: Level %d, %d von %d Partien gewonnen") % [int(rec.best_level), int(rec.wins), int(rec.games)]
	var tag: Label = null
	if bonus != "" or _kind == "pro":
		tag = UiUtil.label("", v, 13)
		tag.add_theme_color_override("font_color", DecoTheme.CYAN)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards[id] = [b, title, info, tag, bonus, col]


## Kartentext: bei Profi-Filialen nur die Besonderheiten (die Werte stehen im Tooltip).
func _short(text: String) -> String:
	for key in ["Besonderheiten:", "Special:"]:
		var i := text.find(key)
		if _kind == "pro" and i >= 0:
			return text.substr(i + key.length()).replace(" / ", " ").strip_edges()
	return text.replace("Reichweite:", tr("Reichweite")).replace("  ", " ")


func _diff_count() -> int:
	return (MaulData.rules().get("difficulties", []) as Array).size()


func _set_difficulty(i: int) -> void:
	_difficulty = i
	_refresh()


func _set_mode(id: String) -> void:
	_mode = id
	_refresh()


func _set_shop(id: String) -> void:
	_shop = id
	_refresh()


## Profi-Filialen offen? Mit Sandbox immer, sonst ab 25 XP; nie ohne Speziallevels.
func _pro_open() -> bool:
	var diff := game.difficulty if game.mirror else _difficulty
	if not bool(MaulData.difficulty(diff).get("specials", true)):
		return false
	var sandbox := game.sandbox if game.mirror else _sandbox
	return sandbox or MaulXp.pro_unlocked(game.players[game.local_player].xp)


func refresh() -> void:
	if _waiting and game.phase != MaulGame.Phase.SETUP:
		_waiting = false
		game.start_game(_shop, _difficulty, _mode, _sandbox, _foreign, _share)
	_refresh()


func _refresh() -> void:
	var xp: int = game.players[game.local_player].xp
	var sandbox := game.sandbox if game.mirror else _sandbox
	_xp.text = tr("Sandbox: 800 XP") if sandbox else tr("Deine Erfahrung: %s XP") % MaulXp.text(xp)
	for i in _diff_buttons.size():
		_diff_buttons[i].set_pressed_no_signal(_diff_ids[i] == _difficulty)
	if _asc != null:
		_asc.set_difficulty(_difficulty)
	for e in _mode_buttons:
		e[0].set_pressed_no_signal(e[1] == _mode)
	if _sandbox_button != null:
		_sandbox_button.set_pressed_no_signal(_sandbox)
	if _foreign_button != null:
		_foreign_button.set_pressed_no_signal(_foreign)
	if _share_button != null:
		_share_button.set_pressed_no_signal(_share)
	for k in _kind_buttons:
		_kind_buttons[k].set_pressed_no_signal(k == _kind)
	var pro_open := _pro_open()
	if _kind == "pro" and not pro_open and _shop != "":
		_shop = ""
	for id in _cards:
		var c: Array = _cards[id]
		var locked: bool = _kind == "pro" and not pro_open
		var on: bool = id == _shop
		c[0].set_pressed_no_signal(on)
		c[0].disabled = locked
		# Ausgewählt: Cyan-Fläche, darauf dunkle Schrift
		c[1].add_theme_color_override("font_color", DecoTheme.BAR if on else (DecoTheme.MUTED if locked else c[5]))
		c[2].add_theme_color_override("font_color", DecoTheme.BAR if on else (DecoTheme.MUTED if locked else DecoTheme.DIM))
		if c[3] != null:
			var bonus: String = c[4]
			if locked:
				c[3].text = tr("Gesperrt: ab %d XP") % int(MaulXp.cfg().get("pro_shops", 25))
			elif bonus == "" or ["gaertnerei", "waffenladen"].has(id):
				c[3].text = tr("ohne Bonus-Upgrade") if _kind == "pro" and id != "random_pro" else ""
			else:
				c[3].text = tr("Rabatt statt Bonus") if bonus == "rebate" else tr("Bonus-Upgrade")
			c[3].add_theme_color_override("font_color", DecoTheme.BAR if on else (DecoTheme.MISSING if locked else DecoTheme.CYAN))
	_open.disabled = _shop == "" or _waiting
	_open.text = tr("Warte auf den Host …") if _waiting else tr("Filiale eröffnen")
	if _kind == "pro" and not pro_open:
		if not bool(MaulData.difficulty(game.difficulty if game.mirror else _difficulty).get("specials", true)):
			_detail.text = tr("Profi-Filialen gibt es nur mit Speziallevels.")
		else:
			_detail.text = tr("Profi-Filialen öffnen ab 25 XP. Du hast %s XP, nach jedem Level gibt es neue. Mit Sandbox kannst du sie ausprobieren.") % MaulXp.text(xp)
	elif _shop == "":
		_detail.text = tr("Wähle eine Filiale.")
	elif _shop == "random":
		_detail.text = tr("Zufall: eine der 11 Standard-Filialen")
	elif _shop == "random_pro":
		_detail.text = tr("Profi-Zufall: eine der 9 Profi-Filialen")
	else:
		var list := MaulData.buyable(_shop)
		var s := MaulData.shop(_shop)
		_detail.text = tr("%s: %d Tower von %s bis %s Gold") % [str(s.name), list.size(), MaulHud.big(int(list[0].cost)), MaulHud.big(int(list[-1].cost))] if not list.is_empty() else str(s.name)


func _card_color(id: String) -> Color:
	if id.begins_with("random"):
		return DecoTheme.PURPLE_LIGHT
	return Color.from_string(str(MaulData.shop(id).get("color", "#ff4fd8")), DecoTheme.GOLD)


func _show_profile() -> void:
	var p := MaulProfilePanel.new()
	p.xp = game.players[game.local_player].xp
	add_child(p)


func _start() -> void:
	if _shop == "":
		return
	if game.mirror and game.phase == MaulGame.Phase.SETUP:
		_waiting = true
		_refresh()
		return
	Session.maul_choice = {"shop": _shop, "kind": _kind, "difficulty": _difficulty, "mode": _mode, "sandbox": _sandbox, "foreign": _foreign, "share": _share}
	if _asc != null:
		Session.ascension_choice["maul"] = _asc.level
		game.ascension = _asc.chosen()
	game.start_game(_shop, _difficulty, _mode, _sandbox, _foreign, _share)
