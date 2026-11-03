class_name MaulHud
extends CanvasLayer
## Oberfläche von Shopping Maul (nach dem Mockup): Leiste oben, Übersichtskarte oben links,
## Laden der eigenen Filiale rechts, ausgewählter Tower unten links, Meldung oben in der Mitte,
## dazu Filialwahl vor Level 1 und der Endbildschirm. Liest den Zustand aus MaulGame,
## Aktionen gehen als Befehle über game.submit().

const SHOP_WIDTH := 300.0
const MAP_SIZE := 200.0
const ABIL_H := 84.0  ## feste Höhe der Fähigkeiten im Auswahlfenster (mehr scrollt), damit es nicht springt

var game: MaulGame
var root: Control

var _level: Label
var _next: Label
var _timer: Label
var _gold: Label
var _xp: Label
var _value: Label
var _lives: Label
var _diff: Label
var _team: Label
var _start_button: Button
var _speed_buttons: Array = []

var _shop_title: Label
var _shop_list: VBoxContainer
var _shop_buttons: Array = []
var _reveal_button: Button
var _shop_panel: PanelContainer
var _tab := "shop"
var _tab_buttons := {}
var _shop_page: VBoxContainer
var _xpert_list: VBoxContainer
var _xpert_buttons: Array = []
var _main_box: VBoxContainer
var _live: Array = []      ## [Knopf, Callable] – Abklingzeiten, mehrmals pro Sekunde aufgefrischt
var _copy_pick := ""

var _sel_panel: PanelContainer
var _sel_box: VBoxContainer

var _banner: Label
var _minimap: MaulMinimap
var paths_button: Button = null  ## Mehrspieler: Wege der Mitspieler ein/aus
var lights_button: Button = null  ## Lichtpfad ein/aus
var _setup: MaulSetup
var _game_over: Control
var _menu: Control
var _save_button: Button
var settings_panel: SettingsPanel
var _debug: MaulDebug
var _debug_button: Button


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_build_top_bar()
	_build_shop()
	_build_selection()
	_build_minimap()
	_banner = UiUtil.label("", root, 20)
	# auf einem dunklen Schild, so schmal wie der Text: über hellem Marmor und Messing sonst schlecht lesbar
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_top = 60
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_stylebox_override("normal", UiTheme.panel(6.0, 0.88))
	_banner.visible = false
	_banner.add_theme_font_override("font", UiTheme.font(true))
	_banner.add_theme_color_override("font_color", UiTheme.GOLD)
	# dunkle Kontur und Schatten: der Schriftzug steht über hellem Marmor und Messinglinien
	_banner.add_theme_color_override("font_outline_color", UiTheme.BG)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_shadow_color", Color(UiTheme.BG, 0.8))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 3)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Leiste oben ------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var style := UiTheme.box(UiTheme.BAR, Color.TRANSPARENT, 0, 0, 10)
	style.border_color = UiTheme.GOLD
	style.border_width_bottom = 3
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)
	_level = _stat(row, "Welle")
	_next = _stat(row, "Nächstes")
	_timer = _stat(row, "Start in")
	_gold = _stat(row, "Gold")
	_gold.add_theme_color_override("font_color", UiTheme.COIN)
	_xp = _stat(row, "XP")
	_xp.add_theme_color_override("font_color", UiTheme.PURPLE_LIGHT)
	_xp.tooltip_text = "Erfahrung bleibt über Spiele hinweg erhalten. Ab 25 XP öffnen die Profi-Filialen, die XP-Tower des XPert ab 25 bis 800 XP."
	_xp.mouse_filter = Control.MOUSE_FILTER_PASS
	_value = _stat(row, "Towerwert")
	_lives = _stat(row, "Leben")
	_team = _stat(row, "Teampunkte")
	_team.add_theme_color_override("font_color", UiTheme.CYAN)
	_team.tooltip_text = "Einlösen in der Zentrale: +10 Leben, Durchblick (30 s alle Unsichtbaren angreifbar) oder Winter (10 s alle Gegner 90 % langsamer). Neue gibt es nach Level 10, 20 und 30."
	_team.mouse_filter = Control.MOUSE_FILTER_PASS
	_diff = _stat(row, "Diff")
	_diff.tooltip_text = "Selbstanpassung: wer wenig durchlässt, bekommt stärkere Gegner."
	_diff.mouse_filter = Control.MOUSE_FILTER_PASS
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_start_button = UiUtil.button("Jetzt starten", row, func(): game.submit({"type": "start_now"}))
	UiTheme.accent_button(_start_button, UiTheme.GOLD, UiTheme.BAR)
	Hud.key_badge(_start_button, "N")
	if game.solo():
		var auto := UiUtil.button("Auto", row, func(): pass)
		auto.toggle_mode = true
		auto.focus_mode = Control.FOCUS_NONE
		auto.tooltip_text = "Nächstes Level sofort starten, ohne Countdown (sonst Taste N)."
		auto.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		auto.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		auto.set_pressed_no_signal(Session.auto_wave_on())
		auto.toggled.connect(game.set_auto_wave)
		var pause := UiUtil.button("❚❚", row, func(): game.set_user_paused(true))
		pause.focus_mode = Control.FOCUS_NONE
		pause.tooltip_text = "Pause (Taste P)"
		Hud.key_badge(pause, "P")
	lights_button = UiUtil.button("Lichtpfad", row, func(): pass)
	lights_button.toggle_mode = true
	lights_button.focus_mode = Control.FOCUS_NONE
	lights_button.tooltip_text = "Lichter fliegen den Weg der Gegner entlang (Taste L)."
	lights_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	lights_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	lights_button.set_pressed_no_signal(Display.path_lights)
	lights_button.toggled.connect(func(on: bool): game.set_path_lights(on))
	Hud.key_badge(lights_button, "L")
	for f in [1.0, 2.0, 4.0]:
		var b := UiUtil.button("%d×" % int(f), row, func(): game.set_speed(f))
		b.toggle_mode = true
		b.custom_minimum_size.x = 40
		Hud.key_badge(b, str([1.0, 2.0, 4.0].find(f) + 1))
		_speed_buttons.append(b)
	# Debug-Menü nur, wo gerechnet wird (allein oder Host)
	if not game.mirror:
		_debug_button = UiUtil.button("Debug", row, toggle_debug)
		_debug_button.toggle_mode = true
		_debug_button.focus_mode = Control.FOCUS_NONE
		_debug_button.tooltip_text = "Debug-Menü"
		_debug_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		_debug_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	Hud.key_badge(UiUtil.button("Menü", row, toggle_menu), "Esc")
	_build_menu()


var _pause_banner: PanelContainer


## Schild „PAUSE“ oben in der Mitte (Taste P, maul_game.set_user_paused).
func show_pause(on: bool) -> void:
	if _pause_banner == null:
		_pause_banner = PanelContainer.new()
		_pause_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pause_banner.add_theme_stylebox_override("panel", UiTheme.panel(16.0, 0.95))
		_pause_banner.anchor_left = 0.5
		_pause_banner.anchor_right = 0.5
		_pause_banner.offset_top = 110
		_pause_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
		root.add_child(_pause_banner)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pause_banner.add_child(v)
		UiTheme.title(UiUtil.label("PAUSE", v, 28), 28).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sub := UiUtil.label("P: weiter", v, 14)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_color_override("font_color", UiTheme.MUTED)
	_pause_banner.visible = on
	var s := _pause_banner.get_combined_minimum_size()
	_pause_banner.offset_left = -s.x / 2.0
	_pause_banner.offset_right = s.x / 2.0


func toggle_debug() -> void:
	game.debug_used = true
	if _debug == null:
		_debug = MaulDebug.new()
		_debug.game = game
		# links neben dem Laden, damit beide gleichzeitig offen bleiben können
		_debug.anchor_left = 1.0
		_debug.anchor_right = 1.0
		_debug.offset_right = -SHOP_WIDTH - 32
		_debug.offset_top = 84
		_debug.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_debug.visible = false
		root.add_child(_debug)
	_debug.visible = not _debug.visible
	_debug_button.set_pressed_no_signal(_debug.visible)
	if _debug.visible:
		_debug.refresh()


func _stat(parent: Node, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	UiTheme.caption(caption, box)
	var l := UiUtil.label("–", box, 17)
	l.add_theme_font_override("font", UiTheme.font(true))
	return l


func _build_menu() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(16))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	UiTheme.title(UiUtil.label("Menü", box), 22)
	var resume := UiUtil.button("Weiterspielen", box, func(): panel.hide())
	UiTheme.accent_button(resume, UiTheme.GOLD, UiTheme.BAR)
	UiUtil.button("Einstellungen", box, func(): settings_panel.open())
	if not game.mirror:
		var save := UiUtil.button("Speichern und verlassen", box, _save_and_leave)
		save.tooltip_text = "Mitten im Level wird der Stand vom Levelbeginn gespeichert." if game.sync == null else "Koop: speichert die Partie für alle. Laden über „Spiel laden“, die Mitspieler steigen in der Lobby wieder ein."
		_save_button = save
	if game.sync == null:
		UiUtil.button("Neu starten", box, func():
			Session.save_id = ""
			Session.goto(Session.MAUL))
	UiUtil.button("Hauptmenü", box, func(): Session.goto(Session.MAIN_MENU))
	_menu = panel
	settings_panel = SettingsPanel.new(false, true)
	root.add_child(settings_panel)


## Menü-Knopf und Esc: offenes Einstellungsfenster zuerst schließen.
func toggle_menu() -> void:
	if settings_panel.visible:
		settings_panel.close()
	else:
		_menu.visible = not _menu.visible
		if _save_button != null:
			_save_button.text = tr("Speichern und verlassen")
			_save_button.disabled = MaulSave.capture(game).is_empty()


## Spiel speichern (maul_save.gd; im Koop der Host für alle) und zurück ins Hauptmenü.
func _save_and_leave() -> void:
	var ok := MaulSave.save_coop(game) if game.sync != null else MaulSave.save(game)
	if ok:
		Session.goto(Session.MAIN_MENU)
	else:
		_save_button.text = tr("Speichern fehlgeschlagen")


# --- Laden rechts -----------------------------------------------------------------

func _build_shop() -> void:
	_shop_panel = PanelContainer.new()
	_shop_panel.add_theme_stylebox_override("panel", UiTheme.panel(12))
	_shop_panel.anchor_left = 1.0
	_shop_panel.anchor_right = 1.0
	_shop_panel.offset_left = -SHOP_WIDTH - 16
	_shop_panel.offset_right = -16
	_shop_panel.offset_top = 84
	_shop_panel.visible = false
	root.add_child(_shop_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_shop_panel.add_child(box)
	# Reiter: eigene Filiale, XPert (XP- und Ultimate-Tower), Hauptgebäude (Bonus/Rabatt, Forschung)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	box.add_child(tabs)
	for e in [["shop", "Filiale"], ["xpert", "XPert"], ["main", "Zentrale"]]:
		var id: String = e[0]
		var b := UiUtil.button(e[1], tabs, func(): _set_tab(id))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		_tab_buttons[id] = b
	_tab_buttons["main"].tooltip_text = "Hauptgebäude: Bonus-Upgrade oder Rabatt, beim TOI die Forschung"
	_shop_page = VBoxContainer.new()
	_shop_page.add_theme_constant_override("separation", 6)
	box.add_child(_shop_page)
	_shop_title = UiTheme.title(UiUtil.label("", _shop_page), 20)
	UiTheme.caption("Tower kaufen (Taste)", _shop_page)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 3)
	_shop_page.add_child(_shop_list)
	_reveal_button = UiUtil.button("Aufdecken", _shop_page, func(): game.submit({"type": "reveal"}))
	_reveal_button.tooltip_text = "Macht 30 s lang alle Unsichtbaren angreifbar, danach 60 s Pause."
	var hint := UiUtil.wrap_label("Grau = zu wenig Gold. Klick oder Taste wählt, dann ins eigene Gebiet setzen. Umschalt hält die Wahl, Rechtsklick bricht ab.", _shop_page, SHOP_WIDTH - 24)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.add_theme_font_size_override("font_size", 12)
	_xpert_list = VBoxContainer.new()
	_xpert_list.add_theme_constant_override("separation", 3)
	box.add_child(_xpert_list)
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 6)
	box.add_child(_main_box)
	_set_tab("shop")


func _set_tab(id: String) -> void:
	_tab = id
	for k in _tab_buttons:
		_tab_buttons[k].set_pressed_no_signal(k == id)
	_shop_page.visible = id == "shop"
	_xpert_list.visible = id == "xpert"
	_main_box.visible = id == "main"
	if id == "xpert":
		_build_xpert()
	elif id == "main":
		_build_main()


## Reiter XPert: XP-Tower (einer pro Spieler, ab 25 … 800 XP) und Ultimate-Tower (ab Level 21).
func _build_xpert() -> void:
	for c in _xpert_list.get_children():
		c.queue_free()
	_xpert_buttons.clear()
	var t := UiTheme.title(UiUtil.label("XPert", _xpert_list), 20)
	t.add_theme_color_override("font_color", Color.from_string(str(MaulData.xpert().get("color", "#ffe14f")), UiTheme.COIN))
	var info := UiUtil.wrap_label("Jede Filiale darf einen XP-Tower und einen Ultimate-Tower bauen. Was gesperrt ist, zeigt der Grund.", _xpert_list, SHOP_WIDTH - 24)
	info.add_theme_color_override("font_color", UiTheme.MUTED)
	info.add_theme_font_size_override("font_size", 12)
	for d in MaulData.buyable("xpert"):
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(SHOP_WIDTH - 24, 30)
		b.toggle_mode = true
		b.tooltip_text = tower_text(d)
		var id := str(d.id)
		b.pressed.connect(func(): game.choose_build(id))
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		row.offset_right = -6
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var name := UiUtil.label(str(d.name), row, 13)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost := UiUtil.label(MaulHud.big(int(d.cost)), row, 13)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_xpert_list.add_child(b)
		_xpert_buttons.append([b, d, cost])
	_refresh_xpert()


func _refresh_xpert() -> void:
	var p := game.local_player
	var gold: int = game.players[p].gold
	for e in _xpert_buttons:
		var b: Button = e[0]
		var d: Dictionary = e[1]
		var why := game.requirement_problem(d, p)
		b.set_pressed_no_signal(game.build_id == str(d.id))
		b.disabled = why != ""
		var cost: Label = e[2]
		cost.text = why if why != "" else MaulHud.big(int(d.cost))
		cost.add_theme_color_override("font_color", UiTheme.MUTED if why != "" else (UiTheme.MISSING if int(d.cost) > gold else UiTheme.COIN))
		cost.add_theme_font_size_override("font_size", 11 if why != "" else 13)


## Konto im Hauptgebäude (maul_bank.gd): Einzahlen, Abheben, Auto-Einzahlen, Bank-Upgrade.
## Die Deutsche Bank hat kein Konto und sieht stattdessen ihren Anteil; Tante Emma sieht die Stammkundin.
func _build_bank(me: MaulGame.Player) -> void:
	UiTheme.caption("Konto", _main_box)
	var width := SHOP_WIDTH - 24
	if me.shop == MaulBank.OWNER:
		var l := UiUtil.wrap_label(tr("Kein eigenes Konto. Am Levelende 5 %% aller Konten: jetzt %s Gold (alle Konten %s Gold).") % [MaulHud.big(MaulBank.owner_income(game)), MaulHud.big(MaulBank.total(game))], _main_box, width)
		l.add_theme_font_size_override("font_size", 13)
	else:
		var info := UiUtil.wrap_label(tr("Kontostand %s Gold, %d %% Zinsen am Levelende (höchstens auf %s Gold).") % [MaulHud.big(me.account), roundi(MaulBank.rate(me) * 100.0), MaulHud.big(int(MaulBank.cfg().get("cap", 5000)))], _main_box, width)
		info.add_theme_font_size_override("font_size", 13)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_main_box.add_child(row)
		var dep := UiUtil.button(tr("Einzahlen"), row, func(): game.submit({"type": "deposit"}))
		dep.disabled = me.gold <= 0
		dep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var wd := UiUtil.button(tr("Überweisung läuft") if me.withdraw_in > 0.0 else tr("Abheben (%d s)") % roundi(MaulBank.withdraw_delay(me)), row, func(): game.submit({"type": "withdraw"}))
		wd.disabled = me.account <= 0 or me.withdraw_in > 0.0
		wd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var auto := CheckBox.new()
		auto.text = "Am Levelende alles einzahlen"
		auto.button_pressed = me.auto_deposit
		auto.toggled.connect(func(_on): game.submit({"type": "auto_deposit"}))
		_main_box.add_child(auto)
		var cost := MaulBank.upgrade_cost(me)
		if cost > 0:
			var up := UiUtil.button(tr("Bank-Upgrade %d: %s Gold") % [me.bank_level + 1, MaulHud.big(cost)], _main_box, func(): game.submit({"type": "bank_upgrade"}))
			up.tooltip_text = tr("+2 % Zinsen, 5 s schneller abheben")
			up.disabled = cost > me.gold
	if me.shop == MaulBank.EMMA:
		UiTheme.caption("Stammkundin", _main_box)
		var e := MaulBank.emma_cfg()
		var text := tr("Bringt %d Gold alle %d s aus dem Laden, noch %s von %s Gold.") % [int(e.get("gold_per_trip", 10)), roundi(float(e.get("trip", 10.0))), MaulHud.big(int(e.get("mine", 15000)) - me.emma_mined), MaulHud.big(int(e.get("mine", 15000)))] if MaulBank.has_customer(game, game.local_player) else tr("Ein Altenheim wirbt eine Stammkundin an, die laufend Gold aus dem Laden holt.")
		var l := UiUtil.wrap_label(text, _main_box, width)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", UiTheme.COIN)


## Teampunkte einlösen (wirkt fürs ganze Team, maul_game.gd → _use_team_point).
func _build_team(me: MaulGame.Player) -> void:
	var tp: Dictionary = MaulData.rules().team_points
	UiTheme.caption(tr("Teampunkte: %d") % me.team_points, _main_box)
	var active := []
	if game.sight_until > game.game_time:
		active.append(tr("Durchblick %d s") % ceili(game.sight_until - game.game_time))
	if game.winter_until > game.game_time:
		active.append(tr("Winter %d s") % ceili(game.winter_until - game.game_time))
	if not active.is_empty():
		var l := UiUtil.label(", ".join(active), _main_box, 13)
		l.add_theme_color_override("font_color", UiTheme.CYAN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_main_box.add_child(row)
	var running := game.phase == MaulGame.Phase.COUNTDOWN or game.phase == MaulGame.Phase.WAVE
	for e in [["lives", tr("+%d Leben") % int(tp.lives), tr("Nur wenn Leben fehlen, höchstens bis zum Maximum.")],
			["sight", tr("Durchblick"), tr("%d s lang sind alle Unsichtbaren für alle angreifbar.") % int(tp.sight)],
			["winter", tr("Winter"), tr("%d s lang laufen alle Gegner %d %% langsamer.") % [int(tp.winter), roundi(float(tp.winter_slow) * 100.0)]]]:
		var use: String = e[0]
		var b := UiUtil.button(e[1], row, func(): game.submit({"type": "team", "use": use}))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = e[2]
		b.disabled = me.team_points <= 0 or not running or (use == "lives" and game.lives >= game.max_lives)


## Reiter Zentrale (Hauptgebäude): Bonus-Upgrade (+5 % Schaden je Stufe) oder Rabatt (5 % zurück),
## beim TOI die Forschung, dazu die eigene Erfahrung.
func _build_main() -> void:
	for c in _main_box.get_children():
		c.queue_free()
	var p := game.local_player
	var me: MaulGame.Player = game.players[p]
	UiTheme.title(UiUtil.label("Hauptgebäude", _main_box), 20)
	_build_team(me)
	var shop := MaulData.shop(me.shop)
	var kind := str(shop.get("bonus", ""))
	var cfg: Dictionary = MaulData.pro().bonus
	if game.has_bonus(p):
		var levels := int(cfg.levels)
		var step := float(cfg.rebate_step if kind == "rebate" else cfg.damage_step)
		UiTheme.caption("Rabatt" if kind == "rebate" else "Bonus-Upgrade", _main_box)
		var now := UiUtil.wrap_label((tr("Stufe %d/%d: %d %% Rabatt auf alle Käufe") if kind == "rebate" else tr("Stufe %d/%d: +%d %% Schaden für alle Tower")) % [me.bonus, levels, roundi(me.bonus * step * 100)], _main_box, SHOP_WIDTH - 24)
		now.add_theme_font_size_override("font_size", 13)
		if me.bonus < levels:
			var cost := MaulData.bonus_cost(me.bonus + 1, kind == "rebate", game.players.size())
			var b := UiUtil.button(tr("Stufe %d kaufen: %s Gold") % [me.bonus + 1, MaulHud.big(cost)], _main_box, func(): game.submit({"type": "bonus"}))
			UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.BAR)
			b.disabled = cost > me.gold
	else:
		UiUtil.wrap_label("Diese Filiale hat kein Bonus-Upgrade.", _main_box, SHOP_WIDTH - 24).add_theme_color_override("font_color", UiTheme.MUTED)
	_build_bank(me)
	if me.shop == "tui":
		UiTheme.caption("Forschung", _main_box)
		for id in ["range", "damage", "advanced"]:
			var r: Dictionary = MaulData.pro().tui.research[id]
			var lv := int(me.research.get(id, 0))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_main_box.add_child(row)
			var l := UiUtil.label(tr("%s %d/%d") % [tr(str(r.name)), lv, int(r.max)], row, 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.tooltip_text = tr("+%s je Stufe") % TowerStats.num(float(r.step), 2)
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			var rid: String = id
			var b := UiUtil.button(MaulHud.big(int(r.cost)), row, func(): game.submit({"type": "research", "id": rid}))
			b.disabled = lv >= int(r.max) or int(r.cost) > me.gold
	UiTheme.caption("Erfahrung", _main_box)
	var xp_text := tr("%s XP, Sandbox: es gibt keine neuen XP") % MaulXp.text(me.xp) if game.sandbox else tr("%s XP. Nach jedem Level gibt es neue, das nächste Zehntel wird immer teurer.") % MaulXp.text(me.xp)
	var xl := UiUtil.wrap_label(xp_text, _main_box, SHOP_WIDTH - 24)
	xl.add_theme_font_size_override("font_size", 13)
	xl.add_theme_color_override("font_color", UiTheme.PURPLE_LIGHT)


## Ladenliste für die gewählte Filiale aufbauen.
func build_shop() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	_shop_buttons.clear()
	var shop := MaulData.shop(game.shop_of())
	_shop_title.text = str(shop.get("name", ""))
	_shop_title.add_theme_color_override("font_color", Color.from_string(str(shop.get("color", "#ff4fd8")), UiTheme.GOLD))
	var list := MaulData.buyable(game.shop_of())
	for i in list.size():
		var t: Dictionary = list[i]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(SHOP_WIDTH - 24, 30)
		b.tooltip_text = tower_text(t)
		b.toggle_mode = true
		var id := str(t.id)
		b.pressed.connect(func(): game.choose_build(id))
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		row.offset_right = -6
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var key := UiUtil.label(key_label(i), row, 13)
		key.custom_minimum_size.x = 18
		key.add_theme_font_override("font", UiTheme.font(true))
		key.add_theme_color_override("font_color", UiTheme.CYAN)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := UiUtil.label(str(t.name) + ("  ✈" if str(t.targets) == "air" else ""), row, 13)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost := UiUtil.label(MaulHud.big(int(t.cost)), row, 13)
		cost.add_theme_color_override("font_color", UiTheme.COIN)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_list.add_child(b)
		_shop_buttons.append([b, int(t.cost), id, cost])
	_reveal_button.visible = not MaulData.rules().detect_shops.has(game.shop_of())
	_shop_panel.visible = true
	_set_tab(_tab)
	refresh_shop()


## Beschriftung der Bau-Taste i (Tastaturbelegung des Systems, sonst QWERTZ).
static func key_label(i: int) -> String:
	if i >= MaulGame.BUILD_KEYS.size():
		return ""
	var key: int = MaulGame.BUILD_KEYS[i]
	var label := KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_label_from_physical(key)
	if label == KEY_NONE:
		return "QWERASDFYXC"[i]
	return OS.get_keycode_string(label)


func refresh_shop() -> void:
	if game == null:
		return
	var gold: int = game.players[game.local_player].gold
	for entry in _shop_buttons:
		var b: Button = entry[0]
		b.set_pressed_no_signal(game.build_id == entry[2])
		var poor: bool = entry[1] > gold
		b.modulate = Color(1, 1, 1, 0.45) if poor else Color.WHITE
		(entry[3] as Label).add_theme_color_override("font_color", UiTheme.MISSING if poor else UiTheme.COIN)
	if _tab == "xpert" and _shop_panel.visible:
		_refresh_xpert()
	if _reveal_button.visible:
		var me: MaulGame.Player = game.players[game.local_player]
		var wait := me.reveal_ready - game.game_time
		var active := me.reveal_until - game.game_time
		_reveal_button.disabled = wait > 0.0
		if active > 0.0:
			_reveal_button.text = tr("Aufgedeckt: %d s") % ceili(active)
		elif wait > 0.0:
			_reveal_button.text = tr("Aufdecken in %d s") % ceili(wait)
		else:
			_reveal_button.text = tr("Aufdecken")


# --- Auswahl unten links ------------------------------------------------------------

func _build_selection() -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.add_theme_stylebox_override("panel", UiTheme.panel(12))
	_sel_panel.anchor_top = 1.0
	_sel_panel.anchor_bottom = 1.0
	_sel_panel.offset_left = 16
	_sel_panel.offset_bottom = -16
	_sel_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sel_panel.custom_minimum_size.x = 340
	_sel_panel.visible = false
	root.add_child(_sel_panel)
	_sel_box = VBoxContainer.new()
	_sel_box.add_theme_constant_override("separation", 6)
	_sel_panel.add_child(_sel_box)


func refresh_selection() -> void:
	for c in _sel_box.get_children():
		_sel_box.remove_child(c)
		c.queue_free()
	_live.clear()
	var u: MaulUnit = game.selected_unit if game.selected_unit != null and is_instance_valid(game.selected_unit) else null
	var t: MaulTower = game.selected
	_sel_panel.visible = t != null or u != null
	if u != null:
		_unit_panel(u)
		return
	if t == null:
		return
	var d := t.def
	UiTheme.title(UiUtil.label(str(d.get("name", "")), _sel_box), 18)
	var sub := UiUtil.label("%s · %s" % [damage_type_name(str(d.get("damage_type", ""))), targets_name(str(d.get("targets", "both")))], _sel_box, 13)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	if t.owner_player != game.local_player:
		sub.text += " · " + game.players[t.owner_player].name
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	_sel_box.add_child(grid)
	var dmg: Array = d.get("damage", [0, 0])
	var cd := float(d.get("cooldown", 0))
	var bonus := game.damage_factor(t) * t.side_factor()
	var add := t.flat + game.flat_bonus_for(t)
	for pair in [["Schaden", TowerStats.dmg_text((float(dmg[0]) + add) * bonus, (float(dmg[1]) + add) * bonus) if cd > 0.0 else "–"],
			["Tempo", (TowerStats.num(cd, 2) + " s") if cd > 0.0 else "–"],
			["Reichweite", TowerStats.num(t.range_cells())],
			["DPS", "%d" % roundi((dps(d) + (add / cd if cd > 0.0 else 0.0)) * bonus)]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		grid.add_child(box)
		UiTheme.caption(pair[0], box)
		var v := UiUtil.label(pair[1], box, 15)
		v.add_theme_font_override("font", UiTheme.font(true))
	_ability_box(ability_lines(d))
	var done := UiUtil.label(tr("%s Schaden · %d Kills") % [MaulHud.big(roundi(t.total_damage)), t.kills], _sel_box, 13)
	done.add_theme_color_override("font_color", UiTheme.MUTED)
	var mine := t.owner_player == game.local_player
	_pro_info(t, mine)
	if not mine:
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	row.custom_minimum_size.x = 316
	_sel_box.add_child(row)
	var sell := UiUtil.button(tr("Verkaufen +%s") % MaulHud.big(game.sell_value(t)), row, func(): game.submit({"type": "sell", "cell": t.cell}))
	sell.tooltip_text = "75 % des Towerwerts zurück (Taste Entf)"
	var gold: int = game.players[game.local_player].gold
	for up in d.get("upgrades_to", []):
		var ud := MaulData.tower(str(up))
		if ud.is_empty():
			continue
		var b := UiUtil.button(tr("%s +%s") % [str(ud.name), MaulHud.big(int(ud.cost))], row, func(): game.submit({"type": "upgrade", "cell": t.cell, "to": str(up)}))
		UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.BAR)
		var why := game.requirement_problem(ud, game.local_player, t)
		b.tooltip_text = tower_text(ud) + ("\n" + why if why != "" else "")
		b.disabled = int(ud.cost) > gold or why != ""
	_pro_actions(t, gold)


## Fähigkeiten in einem Kasten mit fester Höhe, auch ohne Fähigkeit (sonst springt das Fenster beim Wechseln).
func _ability_box(lines: Array) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG, UiTheme.CYAN, 0, 1, 8))
	panel.custom_minimum_size.y = ABIL_H
	_sel_box.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	UiTheme.caption("Fähigkeiten", box)
	if lines.is_empty():
		lines = [tr("Keine besonderen Fähigkeiten")]
	for line in lines:
		var l := UiUtil.wrap_label(line, box, 0)
		l.add_theme_font_size_override("font_size", 13)
		if lines.size() == 1 and line == tr("Keine besonderen Fähigkeiten"):
			l.add_theme_color_override("font_color", UiTheme.MUTED)


## Anzeige der Profi-Werte eines Towers (für alle sichtbar).
func _pro_info(t: MaulTower, mine: bool) -> void:
	var pro := MaulData.pro()
	var lines := []
	if pro.fitness.upkeep.has(t.tower_id):
		lines.append(tr("Stärke +%s, Nebenwirkungen: %d (−%d %%)") % [MaulHud.big(roundi(t.flat)), t.side, roundi((1.0 - t.side_factor()) * 100)])
		lines.append(tr("Anabolika: %s Gold nach jedem Level") % MaulHud.big(int(pro.fitness.upkeep[t.tower_id])))
		if t.paused:
			lines.append(tr("Kalter Entzug: setzt dieses Level aus"))
	var plant := t.plant()
	if not plant.is_empty():
		lines.append(tr("Wasser: %d / %d, %s") % [roundi(t.water), int(plant.water), tr("greift an") if t.active else tr("trocken, ab 90 % aktiv")])
	if pro.garden.irrigation.has(t.tower_id):
		lines.append(tr("Bewässert Pflanzen im Umkreis %s mit %s l/s") % [TowerStats.num(float(pro.garden.radius)), MaulHud.big(int(pro.garden.irrigation[t.tower_id]))])
	if pro.undertaker.cults.has(t.tower_id):
		lines.append(tr("Heilt Zombies im Umkreis um %s/s") % MaulHud.big(int(pro.undertaker.cults[t.tower_id])))
	if t.tower_id == str(pro.undertaker.darkness.tower):
		if t.is_unleashed():
			lines.append(tr("Entfesselt: noch %d s") % ceili(t.unleashed_until - game.game_time))
		else:
			lines.append(tr("Leichen: %d / %d, dann 30 s entfesselt") % [t.corpses, int(pro.undertaker.darkness.corpses)])
	if t.slots() > 0:
		lines.append(tr("Slots: %d / %d") % [t.items.size(), t.slots()])
	for line in lines:
		var l := UiUtil.wrap_label(line, _sel_box, 316)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", UiTheme.CYAN)
	# Eingelegte Items als Inventarfelder wie in WC3: ziehen auf andere Slots oder Tower (auch in der Welt) tauscht
	# bzw. verschiebt, Rechtsklick verkauft; Slots, die der Tower nicht hat, ausgegraut
	if t.slots() > 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_sel_box.add_child(row)
		for i in maxi(6, t.slots()):
			var s := InvSlot.new(40.0)
			row.add_child(s)
			if i >= t.slots():
				s.set_locked()
				s.tooltip_text = tr("Dieser Tower hat nur %d Slots") % t.slots()
				continue
			var loc := {"tower": t.cell, "slot": i}
			if i < t.items.size():
				var it := MaulData.item(str(t.items[i]))
				var refund := floori(int(it.get("cost", 0)) * float(MaulData.rules().sell_refund))
				s.show_abbr(MaulData.item_name(str(t.items[i])), UiTheme.GOLD)
				s.tooltip_text = item_text(it)
				if mine:
					s.tooltip_text += "\n" + tr("Ziehen: auf einen anderen Slot oder Tower") + "\n" + tr("Rechtsklick: verkaufen +%s") % MaulHud.big(refund)
					s.drag_data = {"inv": true, "from": loc}
					var slot := i
					s.clicked.connect(func(b):
						if b == MOUSE_BUTTON_RIGHT:
							game.submit({"type": "item_sell", "cell": t.cell, "slot": slot}))
			else:
				s.tooltip_text = tr("Freier Slot: Item hierher ziehen oder unten kaufen")
			if mine:
				s.on_drop = func(data): game.submit({"type": "item_move", "from": data.from, "to": loc})


## Knöpfe der Profi-Filialen für einen eigenen Tower: Items, Doping, Kopieren, Beschwören, Drohnen.
func _pro_actions(t: MaulTower, gold: int) -> void:
	var pro := MaulData.pro()
	var p := game.local_player
	if t.slots() > 0:
		_item_grid(game.items_for(p, "weapon"), gold, func(id): game.submit({"type": "item", "cell": t.cell, "item": id}),
			t.items.size() >= t.slots(), "Items kaufen", "Erst einen Laden bauen (Post: Package Store, IKEO: Store)")
	if pro.fitness.upkeep.has(t.tower_id):
		_item_grid(game.items_for(p, "drug"), gold, func(id): game.submit({"type": "item", "cell": t.cell, "item": id}),
			false, "Doping", "Erst Erich´s Pharmacy bauen")
	if t.tower_id == str(pro.copyshop.copier):
		_copy_picker(t, gold)
	for id in pro.undertaker.summons.get(t.tower_id, []):
		var uid := str(id)
		var ud := MaulData.unit(uid)
		var b := UiUtil.button("", _sel_box, func(): game.submit({"type": "summon", "cell": t.cell, "unit": uid}))
		b.tooltip_text = unit_text(ud)
		var name := MaulData.name_of(ud, uid)
		_live.append([b, func():
			var wait := float(t.summon_ready.get(uid, 0.0)) - game.game_time
			b.disabled = wait > 0.0
			b.text = tr("%s beschwören") % name if wait <= 0.0 else tr("%s in %d s") % [name, ceili(wait)]])
	if t.tower_id == str(pro.drones.charger):
		var n := game.units.filter(func(u): return u.owner_player == p and u.drone).size()
		UiTheme.caption(tr("Drohnen %d/%d") % [n, int(pro.drones.max)], _sel_box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sel_box.add_child(row)
		for kind in ["battle", "support"]:
			var k: String = kind
			var ud := MaulData.unit(k)
			var b := UiUtil.button(tr("%s %s") % [MaulData.name_of(ud, k), MaulHud.big(int(ud.cost))], row, func(): game.submit({"type": "drone", "cell": t.cell, "kind": k}))
			b.tooltip_text = unit_text(ud)
			b.disabled = n >= int(pro.drones.max) or int(ud.cost) > gold
	_refresh_live_buttons()


## Kaufliste in zwei Spalten (Items, Doping, Module). full: alle Slots belegt.
func _item_grid(ids: Array, gold: int, buy: Callable, full: bool, caption: String, empty_text: String) -> void:
	UiTheme.caption(caption, _sel_box)
	if ids.is_empty():
		var l := UiUtil.wrap_label(empty_text, _sel_box, 316)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_sel_box.add_child(grid)
	for id in ids:
		var it := MaulData.item(str(id))
		var iid := str(id)
		var b := UiUtil.button("%s %s" % [MaulData.item_name(iid), MaulHud.big(int(it.cost))], grid, func(): buy.call(iid))
		b.custom_minimum_size = Vector2(156, 26)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		b.tooltip_text = item_text(it)
		b.disabled = full or int(it.cost) > gold


## Copyshop: Tower einer Standard-Filiale oder der AOX wählen und für Wert × 1,05 − 9 Gold kopieren.
func _copy_picker(t: MaulTower, gold: int) -> void:
	UiTheme.caption("Kopieren", _sel_box)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.custom_minimum_size = Vector2(316, 30)
	opt.clip_text = true
	_sel_box.add_child(opt)
	var list := []
	for id in MaulData.towers():
		var d: Dictionary = MaulData.tower(id)
		if MaulData.pro().copyshop.shops.has(str(d.shop)) and game.requirement_problem(d, game.local_player) == "":
			list.append(d)
	list.sort_custom(func(a, b): return int(a.get("value", a.cost)) < int(b.get("value", b.cost)))
	for d in list:
		opt.add_item("%s (%s) %s" % [str(d.name), str(MaulData.shop(str(d.shop)).name), MaulHud.big(game.copy_cost(str(d.id)))])
		opt.set_item_metadata(opt.item_count - 1, str(d.id))
	var at := 0
	for i in opt.item_count:
		if str(opt.get_item_metadata(i)) == _copy_pick:
			at = i
	if opt.item_count > 0:
		opt.select(at)
		_copy_pick = str(opt.get_item_metadata(at))
	var b := UiUtil.button("", _sel_box, func(): game.submit({"type": "copy", "cell": t.cell, "to": _copy_pick}))
	UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.BAR)
	var update := func():
		var cost := game.copy_cost(_copy_pick) if _copy_pick != "" else 0
		b.text = tr("Kopieren: %s Gold") % MaulHud.big(cost)
		b.disabled = _copy_pick == "" or cost > game.players[game.local_player].gold
		b.tooltip_text = tower_text(MaulData.tower(_copy_pick)) if _copy_pick != "" else ""
	opt.item_selected.connect(func(i):
		_copy_pick = str(opt.get_item_metadata(i))
		update.call())
	update.call()


## Zombie oder Drohne: Werte, Module, Posten.
func _unit_panel(u: MaulUnit) -> void:
	UiTheme.title(UiUtil.label(u.label(), _sel_box), 18)
	var mine := u.owner_player == game.local_player
	var sub := UiUtil.label(tr("Drohne") if u.drone else tr("Zombie"), _sel_box, 13)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	if not mine:
		sub.text += " · " + game.players[u.owner_player].name
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	_sel_box.add_child(grid)
	var vals := {}
	for cap in ["Energie" if u.drone else "Leben", "Schaden", "Tempo", "Reichweite"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		grid.add_child(box)
		UiTheme.caption(cap, box)
		var v := UiUtil.label("", box, 15)
		v.add_theme_font_override("font", UiTheme.font(true))
		vals[cap] = v
	var stats := UiUtil.label("", _sel_box, 13)
	stats.add_theme_color_override("font_color", UiTheme.MUTED)
	_live.append([null, func():
		if not is_instance_valid(u):
			return
		if u.drone:
			vals["Energie"].text = "%d/%d" % [roundi(u.energy), roundi(u.max_energy())]
		else:
			vals["Leben"].text = "%d/%d" % [roundi(u.hp), roundi(u.max_hp)]
		vals["Schaden"].text = MaulHud.big(roundi(u.damage()))
		vals["Tempo"].text = TowerStats.num(u.cooldown(), 2) + " s"
		vals["Reichweite"].text = TowerStats.num(u.range_cells())
		stats.text = tr("%s Schaden · %d Kills") % [MaulHud.big(roundi(u.total_damage)), u.kills]])
	var desc := UiUtil.wrap_label(tr("Verliert Leben mit der Zeit, Kultstätten heilen ihn.") if not u.drone else tr("Verbraucht im Level Energie und lädt am Drone Charger auf."), _sel_box, 316)
	desc.add_theme_font_size_override("font_size", 12)
	if not mine:
		_refresh_live_buttons()
		return
	var hint := UiUtil.wrap_label("Klick ins eigene Gebiet setzt den Posten, dort greift die Einheit an.", _sel_box, 316)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.CYAN)
	if u.drone:
		var slots := int(MaulData.pro().drones.slots)
		UiTheme.caption(tr("Module %d/%d") % [u.modules.size(), slots], _sel_box)
		for slot in u.modules:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_sel_box.add_child(row)
			var id := str(u.modules[slot])
			var l := UiUtil.label(MaulData.item_name(id), row, 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.tooltip_text = item_text(MaulData.item(id))
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			var sl := str(slot)
			var refund := floori(int(MaulData.item(id).get("cost", 0)) * float(MaulData.rules().sell_refund))
			UiUtil.button(tr("Verkaufen +%s") % MaulHud.big(refund), row, func(): game.submit({"type": "module_sell", "unit": u.net_id, "slot": sl})).add_theme_font_size_override("font_size", 12)
		var gold: int = game.players[game.local_player].gold
		var ids := game.items_for(game.local_player, "module").filter(func(id):
			var it := MaulData.item(str(id))
			return not u.modules.has(str(it.slot)) and (u.unit_id == "battle" or not it.get("battle_only", false)))
		_item_grid(ids, gold, func(id): game.submit({"type": "module", "unit": u.net_id, "item": id}),
			u.modules.size() >= slots, "Module kaufen", "Erst eine Fabrik bauen (FAC-1 bis FAC-3)")
	_refresh_live_buttons()


func _refresh_live_buttons() -> void:
	for e in _live:
		e[1].call()


# --- Texte zu Towern -----------------------------------------------------------------

static func _t(s: String) -> String:
	return str(TranslationServer.translate(s))


static func damage_type_name(dt: String) -> String:
	match dt:
		"normal":
			return _t("Normal")
		"pierce":
			return _t("Durchbohrend")
		"siege":
			return _t("Belagerung")
		"magic":
			return _t("Magisch")
		"chaos":
			return _t("Chaos")
		"hero":
			return _t("Held")
		"spells":
			return _t("Zauber")
	return dt


static func targets_name(t: String) -> String:
	match t:
		"air":
			return _t("nur Luft")
		"ground":
			return _t("nur Boden")
	return _t("Luft+Boden")


## Schaden pro Sekunde ohne Fähigkeiten (Mittelwert × Ziele / Abklingzeit).
static func dps(d: Dictionary) -> float:
	var cd := float(d.get("cooldown", 0))
	if cd <= 0.0:
		return 0.0
	var dmg: Array = d.get("damage", [0, 0])
	var n := 1
	for ab in d.get("abilities", []):
		if ab.type == "multishot":
			n = int(ab.targets)
	return (float(dmg[0]) + float(dmg[1])) / 2.0 * n / cd


static func _n(v: float) -> String:
	return TowerStats.num(v)


static func ability_lines(d: Dictionary) -> Array:
	var out := []
	for ab in d.get("abilities", []):
		match str(ab.type):
			"crit":
				out.append(_t("%d %% Chance auf %s× Schaden") % [roundi(float(ab.chance) * 100), _n(float(ab.multiplier))])
			"stun":
				if ab.has("chance"):
					out.append(_t("%d %% Chance auf %s s Betäubung") % [roundi(float(ab.chance) * 100), _n(float(ab.duration))])
				else:
					out.append(_t("Betäubt %s s") % _n(float(ab.duration)))
			"slow":
				out.append(_t("Verlangsamt um %d %% für %s s") % [roundi(float(ab.factor) * 100), _n(float(ab.duration))])
			"slow_aura":
				out.append(_t("Aura: verlangsamt um %d %% (Radius %s)") % [roundi(float(ab.factor) * 100), _n(float(ab.radius))])
			"burn_aura":
				out.append(_t("Aura: %s Schaden/s (Radius %s)") % [_n(float(ab.dps)), _n(float(ab.radius))])
			"poison":
				out.append(_t("Gift: %s Schaden/s für %s s") % [_n(float(ab.dps)), _n(float(ab.duration))])
			"splash":
				out.append(_t("Flächenschaden %d %% (Radius %s)") % [roundi(float(ab.factor) * 100), _n(float(ab.radius))])
			"multishot":
				out.append(_t("Trifft %d Ziele") % int(ab.targets))
			"air_bonus":
				out.append(_t("%s-facher Schaden gegen Luft") % _n(float(ab.multiplier)))
			"detect":
				out.append(_t("Enttarnt Unsichtbare (Radius %s)") % _n(float(ab.radius)))
			"nova_spell":
				out.append(_t("Donnerschlag: %s Schaden (Radius %s), alle %s s") % [MaulHud.big(roundi(float(ab.damage))), _n(float(ab.radius)), _n(float(ab.cooldown))])
			"chain_spell":
				out.append(_t("Kettenblitz: %s Schaden, %d Ziele, alle %s s") % [MaulHud.big(roundi(float(ab.damage))), int(ab.get("targets", 3)), _n(float(ab.cooldown))])
			"wave_spell":
				out.append(_t("Schockwelle: %s Schaden, alle %s s") % [MaulHud.big(roundi(float(ab.damage))), _n(float(ab.cooldown))])
			"stun_spell":
				out.append(_t("%s: betäubt alle Gegner im Radius %s für %s s (Bosse %s s), alle %s s") % [_t(str(ab.name)), _n(float(ab.radius)), _n(float(ab.duration)), _n(float(ab.boss_duration)), _n(float(ab.cooldown))])
			"flirt_spell":
				out.append(_t("Flirten: hält den stärksten Gegner %s s fest (Bosse %s s), alle %s s") % [_n(float(ab.duration)), _n(float(ab.boss_duration)), _n(float(ab.cooldown))])
			"life":
				out.append(_t("%d %% Chance pro Kill, Leben zurückzuholen") % roundi(float(ab.chance) * 100))
	return out


## Tooltip für Ladenknöpfe und Upgrades.
static func tower_text(d: Dictionary) -> String:
	var dmg: Array = d.get("damage", [0, 0])
	var cd := float(d.get("cooldown", 0))
	var lines := [str(d.get("name", "")) + "  ·  " + MaulHud.big(int(d.get("cost", 0))) + " " + _t("Gold")]
	lines.append(damage_type_name(str(d.get("damage_type", ""))) + " · " + targets_name(str(d.get("targets", "both"))))
	if cd > 0.0:
		lines.append(_t("Schaden %s alle %s s, Reichweite %s, DPS %d") % [TowerStats.dmg_text(float(dmg[0]), float(dmg[1])), TowerStats.num(cd, 2), TowerStats.num(float(d.get("range", 0))), roundi(dps(d))])
	else:
		lines.append(_t("Greift nicht selbst an, Reichweite %s") % TowerStats.num(float(d.get("range", 0))))
	lines.append_array(ability_lines(d))
	if not d.get("upgrades_to", []).is_empty():
		var names := []
		for up in d.upgrades_to:
			names.append(str(MaulData.tower(str(up)).get("name", up)))
		lines.append(_t("Upgrade: %s") % ", ".join(names))
	return "\n".join(lines)


## Tooltip für Items, Doping und Module.
static func item_text(it: Dictionary) -> String:
	var lines := [MaulData.name_of(it) + "  ·  " + MaulHud.big(int(it.get("cost", 0))) + " " + _t("Gold")]
	if it.has("cooldown") and it.has("damage"):
		lines.append(_t("Schaden %s alle %s s, Reichweite %s") % [MaulHud.big(int(it.damage)), TowerStats.num(float(it.cooldown), 2), TowerStats.num(float(it.get("range", 0)))])
		if str(it.get("targets", "both")) != "both":
			lines.append(targets_name(str(it.targets)))
	elif it.has("damage"):
		var d = it.damage
		lines.append(_t("+%s Schaden pro Treffer") % ("%d–%d" % [int(d[0]), int(d[1])] if d is Array else MaulHud.big(int(d))))
	if it.has("stun"):
		lines.append(_t("%d %% Chance auf %s s Betäubung") % [roundi(float(it.stun_chance) * 100), _n(float(it.stun))])
	if it.has("frost"):
		lines.append(_t("Verlangsamt um %d %% für %s s") % [roundi(float(it.frost) * 100), _n(1.0)])
	if it.has("slow_aura"):
		lines.append(_t("Aura: verlangsamt um %d %% (Radius %s)") % [roundi(float(it.slow_aura) * 100), _t("Reichweite")])
	var side = it.get("side", 0)
	if str(side) == "dose":
		lines.append(_t("Nebenwirkungen je nach Dosis"))
	elif float(side) > 0.0:
		lines.append(_t("Nebenwirkungen: +%d Stufen") % int(side))
	elif float(side) < 0.0:
		lines.append(_t("Senkt die Nebenwirkungen um %d Stufe") % -int(side))
	for e in [["speed", "Tempo +%s"], ["detect", "Enttarnt Unsichtbare (Radius %s)"], ["energy", "Energie +%s"], ["bonus_damage", "Schaden +%s"],
			["attack_speed", "Angriffstempo +%s"], ["static", "Statik: %s Schaden/s um die Drohne"]]:
		if it.has(e[0]):
			var v := float(it[e[0]])
			lines.append(_t(e[1]) % (("%d %%" % roundi(v * 100)) if e[0] == "attack_speed" else _n(v)))
	if it.get("battle_only", false):
		lines.append(_t("Nur für Kampfdrohnen"))
	return "\n".join(lines)


static func unit_text(u: Dictionary) -> String:
	var lines := [MaulData.name_of(u)]
	lines.append(_t("Schaden %s alle %s s, Reichweite %s") % [MaulHud.big(int(u.get("damage", 0))), TowerStats.num(float(u.get("cooldown", 1)), 2), TowerStats.num(float(u.get("range", 0)))])
	if u.has("hp"):
		lines.append(_t("%d Leben, verliert %d pro Sekunde, Abklingzeit %d s") % [int(u.hp), int(u.decay), int(u.summon_cd)])
	if u.has("drain"):
		lines.append(_t("Verbraucht %d Energie pro Sekunde im Level") % int(u.drain))
	if u.has("chain"):
		lines.append(_t("Trifft %d Ziele") % int(u.chain))
	if u.has("splash") or u.has("nova"):
		lines.append(_t("Flächenschaden %d %% (Radius %s)") % [50, _n(float(u.get("splash", u.get("nova", 0))))])
	if u.has("frost"):
		lines.append(_t("Verlangsamt um %d %% für %s s") % [roundi(float(u.frost) * 100), _n(1.0)])
	if u.has("life_chance"):
		lines.append(_t("%d %% Chance pro Kill auf ein Leben") % roundi(float(u.life_chance) * 100))
	return "\n".join(lines)


## 1234567 → 1.234.567
static func big(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


# --- Übersichtskarte -----------------------------------------------------------------

func _build_minimap() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(6))
	panel.offset_left = 16
	panel.offset_top = 84
	root.add_child(panel)
	_minimap = MaulMinimap.new()
	_minimap.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_minimap.game = game
	if game.players.size() <= 1:
		panel.add_child(_minimap)
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_minimap)
	# Mehrspieler: anfangs nur die Wege durchs eigene Gebiet, die der anderen auf Knopfdruck
	var b := UiUtil.button("Alle Wege zeigen", box, func(): pass)
	paths_button = b
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Zeigt auch die Gegnerwege durch die Gebiete der Mitspieler."
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	b.toggled.connect(func(on: bool): game.set_show_all_paths(on))


# --- Aktualisieren -------------------------------------------------------------------

func refresh() -> void:
	if game == null or _level == null:
		return
	var regular := int(MaulData.rules().regular_levels)
	var total := game.levels.size()
	_level.text = "%d / %d" % [game.level, regular if game.level <= regular else total]
	var upcoming := game.level + 1 if game.phase == MaulGame.Phase.COUNTDOWN or game.phase == MaulGame.Phase.SETUP else game.level
	var lv := game.level_def(upcoming)
	var parts := [MaulGame.kind_name(str(lv.get("kind", "")))] if not lv.is_empty() else ["–"]
	if game.specials_on():
		for s in lv.get("specials", []):
			parts.append(MaulGame.special_name(s))
	_next.text = ", ".join(parts)
	(_next.get_parent().get_child(0) as Label).text = _t("Nächstes").to_upper() if game.phase != MaulGame.Phase.WAVE else _t("Läuft").to_upper()
	_gold.text = MaulHud.big(game.players[game.local_player].gold)
	_xp.text = MaulXp.text(game.players[game.local_player].xp) if not game.sandbox else tr("Sandbox")
	_value.text = MaulHud.big(game.tower_value())
	_lives.text = "%d / %d" % [game.lives, game.max_lives]
	_lives.add_theme_color_override("font_color", UiTheme.HAVE if game.lives * 3 > game.max_lives else UiTheme.MISSING)
	_team.text = str(game.players[game.local_player].team_points)
	_diff.text = "%d %%" % roundi(game.je * 100.0)
	refresh_live()
	refresh_shop()
	if _tab == "main" and _shop_panel.visible:
		_build_main()
	if game.selected != null or game.selected_unit != null:
		refresh_selection()


## Countdown, Gegnerzahl und Tempo (mehrmals pro Sekunde).
func refresh_live() -> void:
	if game == null or _timer == null:
		return
	var cap := _timer.get_parent().get_child(0) as Label
	if game.phase == MaulGame.Phase.COUNTDOWN:
		cap.text = _t("Start in").to_upper()
		var s := maxi(ceili(game.countdown), 0)
		_timer.text = "%d:%02d" % [s / 60, s % 60]
	elif game.phase == MaulGame.Phase.WAVE:
		cap.text = _t("Gegner").to_upper()
		_timer.text = str(game.enemies.size() + game.spawn_queue.reduce(func(a, q): return a + int(q[1]), 0))
	else:
		_timer.text = "–"
	_start_button.visible = game.phase == MaulGame.Phase.COUNTDOWN
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(is_equal_approx(Engine.time_scale, [1.0, 2.0, 4.0][i]))
	if _reveal_button.visible:
		refresh_shop()
	_refresh_live_buttons()
	_minimap.queue_redraw()


func refresh_message() -> void:
	_banner.text = game.message
	_banner.visible = game.message != ""
	# schmal halten: nach kürzerem Text wieder auf die Textbreite schrumpfen
	var w := _banner.get_combined_minimum_size().x
	_banner.offset_left = -w * 0.5
	_banner.offset_right = w * 0.5


# --- Filialwahl und Ende -------------------------------------------------------------

func show_setup() -> void:
	_setup = MaulSetup.new()
	_setup.game = game
	root.add_child(_setup)


func hide_setup() -> void:
	if _setup != null:
		_setup.queue_free()
		_setup = null


func setup_visible() -> bool:
	return _setup != null


## Koop-Mitspieler: der Host hat gestartet, jetzt ist die Filialwahl offen.
func refresh_setup() -> void:
	if _setup != null:
		_setup.refresh()


func show_game_over(victory: bool) -> void:
	if _game_over != null:
		_game_over.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_game_over = dim
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(22))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := UiTheme.title(UiUtil.label("Gewonnen!" if victory else "Totalschaden!", box), 30)
	if not victory:
		title.add_theme_color_override("font_color", UiTheme.MISSING)
	var d := MaulData.difficulty(game.difficulty)
	var stats := tr("Schwierigkeit: %s\nLevel %d von %d\nLeben übrig: %d\nGegner besiegt: %d, durchgelassen: %d\nSelbstanpassung: %d–%d %%\nSpielzeit: %d min") % [
		tr(str(d.get("name", ""))), game.level, game.levels.size(), game.lives, game.enemies_killed, game.enemies_leaked,
		roundi(game.je_min * 100), roundi(game.je_max * 100), roundi(game.play_time / 60.0)]
	UiUtil.label(stats, box, 15)
	var me: MaulGame.Player = game.players[game.local_player]
	if not game.sandbox:
		var xp := UiUtil.label(tr("Erfahrung: %s XP (+%s)") % [MaulXp.text(me.xp), MaulXp.text(me.xp - game.xp_start)], box, 15)
		xp.add_theme_color_override("font_color", UiTheme.PURPLE_LIGHT)
	var news := _profile_news_text()
	if news != "":
		UiUtil.label(news, box, 15).add_theme_color_override("font_color", UiTheme.COIN)
	elif game.sandbox or game.debug_used or Session.debug_immortal:
		UiUtil.label("Zählt nicht fürs Profil (Sandbox oder Debug)", box, 13).add_theme_color_override("font_color", UiTheme.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	if game.sync == null:
		var again := UiUtil.button("Nochmal", row, func(): Session.goto(Session.MAUL))
		UiTheme.accent_button(again, UiTheme.GOLD, UiTheme.BAR)
	UiUtil.button("Hauptmenü", row, func(): Session.goto(Session.MAIN_MENU))


## Endbildschirm: neue Rekorde der Filiale aus dem Profil.
func _profile_news_text() -> String:
	var shop := MaulData.name_of(MaulData.shop(game.shop_of()))
	if game.profile_news.has("best_win"):
		return tr("Neuer Rekord für %s: gewonnen auf %s") % [shop, tr(str(MaulData.difficulty(game.difficulty).get("name", "")))]
	if game.profile_news.has("best_level"):
		return tr("Neuer Rekord für %s: Level %d") % [shop, game.levels_done]
	return ""
