class_name MaulDebug
extends PanelContainer
## Debug-Menü von Shopping Maul (Knopf „Debug“ in der Leiste oben): Gold, Leben, XP, Unsterblich,
## Filiale wechseln, Tower aller Filialen direkt bauen (freies Bauen) und zu einem Level springen.
## Wirkt beim Spieler, der rechnet (allein oder Host); Koop-Mitspieler bekommen den Knopf nicht.

var game: MaulGame
var _shop: OptionButton
var _shop_ids: Array = []
var _tower: OptionButton
var _tower_ids: Array = []
var _free: CheckBox
var _level: SpinBox


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(14.0))
	custom_minimum_size.x = 340
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	UiTheme.title(UiUtil.label("Debug", v, 18))

	var row := _row("Gold", v)
	for n in [500, 5000, 50000]:
		_button("+" + MaulHud.big(n), row, func():
			game.players[game.local_player].gold += n
			game._refresh_hud())
	row = _row("Leben", v)
	for n in [10, 50]:
		_button("+%d" % n, row, func():
			game.lives += n
			game.max_lives = maxi(game.max_lives, game.lives)
			game._refresh_hud())
	row = _row("XP", v)
	_button("+10", row, func(): game.debug_add_xp(100)).tooltip_text = "Wird nicht gespeichert"
	_button("Alles frei", row, func(): game.debug_add_xp(-1)).tooltip_text = "XP wie in der Sandbox: alle Profi-Filialen und XP-Tower. Wird nicht gespeichert."
	var immortal := CheckBox.new()
	immortal.text = "Unsterblich (Leben dürfen ins Minus)"
	immortal.focus_mode = Control.FOCUS_NONE
	immortal.button_pressed = Session.debug_immortal
	immortal.toggled.connect(func(on): Session.debug_immortal = on)
	v.add_child(immortal)

	UiTheme.caption("Filiale", v)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_shop = _option(row)
	_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in MaulData.shops():
		_shop_ids.append(str(s.id))
		_shop.add_item(str(s.name) + ("  (%s)" % tr("Profi") if str(s.kind) == "pro" else ""))
	_button("Wechseln", row, func(): game.debug_set_shop(_shop_ids[_shop.selected])).tooltip_text = "Eigene Filiale wechseln, gebaute Tower bleiben stehen"

	UiTheme.caption("Tower bauen", v)
	_tower = _option(v)
	_tower.tooltip_text = "Tower einer beliebigen Filiale (auch Upgrades, XP- und Ultimate-Tower) zum Setzen wählen, schaltet freies Bauen ein"
	_tower.add_item(tr("– wählen –"))
	_tower_ids = [""]
	for s in MaulData.shops() + [MaulData.xpert()]:
		var list: Array = (s.get("towers", []) as Array).duplicate()
		if list.is_empty():
			continue
		list.sort_custom(func(a, b): return int(a.cost) < int(b.cost))
		_tower.add_separator(str(s.get("name", s.get("id", ""))))
		_tower_ids.append("")
		for t in list:
			_tower_ids.append(str(t.id))
			_tower.add_item("%s · %s" % [str(t.name), MaulHud.big(int(t.cost))])
	_tower.item_selected.connect(func(i):
		if _tower_ids[i] == "":
			return
		_set_free(true)
		game.build_id = ""
		game.choose_build(_tower_ids[i])
		_tower.select(0))
	_free = CheckBox.new()
	_free.text = "Freies Bauen: Tower aller Filialen, ohne Voraussetzungen und Towerlimit, alle Items"
	_free.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_free.custom_minimum_size.x = 300
	_free.focus_mode = Control.FOCUS_NONE
	_free.toggled.connect(_set_free)
	v.add_child(_free)

	row = _row("Level", v)
	_level = SpinBox.new()
	_level.min_value = 1
	_level.max_value = maxi(game.levels.size(), 1)
	row.add_child(_level)
	_button("Starten", row, func(): game.debug_jump_to_level(int(_level.value)))
	var hint := UiUtil.wrap_label("Läuft gerade ein Level, verschwinden seine Gegner und das gewählte startet sofort. Im Countdown kommt es als nächstes.", v, 300)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)


## Beim Öffnen: aktuelle Filiale und nächstes Level vorauswählen.
func refresh() -> void:
	_shop.select(maxi(_shop_ids.find(game.shop_of()), 0))
	_level.set_value_no_signal(clampi(game.level + 1, 1, int(_level.max_value)))
	_free.set_pressed_no_signal(game.debug_free)


func _set_free(on: bool) -> void:
	game.debug_free = on
	_free.set_pressed_no_signal(on)
	game.hud.refresh_shop()
	if game.selected != null:
		game.hud.refresh_selection()


func _row(text: String, parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := UiUtil.label(text, row, 14)
	l.custom_minimum_size.x = 80
	return row


func _button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _option(parent: Node) -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.focus_mode = Control.FOCUS_NONE
	parent.add_child(o)
	return o
