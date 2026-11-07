class_name Hud
extends CanvasLayer
## Oberfläche im Spiel: Leiste oben, Phasenbanner, angepinnte Rezepte links,
## Auswahlkarte unten (neue Gems, Werte, "Wird gebraucht für", Aktionen) und Rezeptbuch.

signal option_chosen(index: int)
## Hover über eine Aktion mit neuer Reichweite (Upgrade, Kombinieren …); 0 = Vorschau aus
signal preview_range_requested(radius: float)
signal round_gem_selected(index: int)
signal extra_chance_requested
signal speed_selected(factor: float)
signal menu_requested
signal pause_toggled(on: bool)      ## Taste P / Pausenknopf (nur Einzelspiel, game.gd hält die Welt an)
signal next_gem_requested           ## Tab: nächster neuer Gem der Runde (GemTD)
## Rückfrage beim Verlassen: speichern und verlassen / ohne Speichern verlassen (quit: Fenster schließen)
signal save_and_leave_requested(quit: bool)
signal leave_requested(quit: bool)
signal main_menu_requested
signal restart_requested
signal debug_tower_changed(key: String)
signal debug_immortal_changed(on: bool)
signal debug_gems_changed(count: int)
signal debug_gold_requested(amount: int)
signal debug_lives_requested(amount: int)
signal debug_wave_requested(number: int)

const BANNER_TOP := 64.0
const LEFT_TOP := 120.0
const SPEEDS := [1.0, 2.0, 4.0]
const INFO_W := 306.0  ## feste Breite der Werte (zwei Kacheln)
const ABIL_W := 300.0  ## feste Breite des Fähigkeiten-Fensters
const ABIL_UNDER_H := 72.0  ## feste Höhe des Fähigkeiten-Fensters unter den Werten

var root: Control
var _drag_box: Panel   ## Auswahlrahmen beim Ziehen mit der linken Maustaste
var wave_value: Label
var lives_value: Label
var gold_value: Label
var path_value: Label
var game_over: Control
var leave_confirm: Control
## Liefert "single", "host", "client" oder "none" (vom Spiel gesetzt): bestimmt die Knöpfe der Rückfrage.
var save_mode: Callable = func(): return "single"
var _leave_quit := false
var _leave_text: Label
var _leave_status: Label
var _save_leave: Button
var _leave_plain: Button
var _leave_stay: Button
var _leave_title: Label
var settings_panel: SettingsPanel
var game_over_title: Label
var game_over_stats: Label
var game_over_boss: Label        ## Endboss-Schadenscheck
var game_over_table: GridContainer  ## Punkte-Modus: Punkte nach Wellentyp
var editor_button: Button
var chance_value: Label
var extra_chance_button: Button
var extra_chance_panel: ExtraChancePanel
var _boons_value: Label = null  ## Roguelike: Anzahl Boni (set_boons)
var title_label: Label
var recipes_button: Button
var left_col: VBoxContainer
var speed_buttons: Array[Button] = []
var debug_option: OptionButton
var debug_button: Button
var paths_button: Button = null  ## Mehrspieler: Wege der Mitspieler ein/aus (add_paths_toggle)
var lights_button: Button = null  ## Lichtpfad ein/aus (add_lights_toggle)
var auto_button: Button = null    ## Nächste Welle automatisch (add_auto_toggle)
var pause_button: Button          ## Pause (Taste P), nur im Einzelspiel sichtbar
var pause_banner: PanelContainer
var user_paused := false          ## mit P pausiert (die Rückfrage beim Verlassen pausiert zusätzlich)
var panels_hidden := false        ## Taste H: Seitenleisten links und rechts aus dem Bild geschoben
var hover_card: PanelContainer    ## Kurzinfo an der Maus über einem Tower (game._update_tower_hover)
var _hover_label: Label
var side_tabs: SideTabs           ## Reiter über der rechten Spalte (DPS / Gegner / Tower / Alle)
var _gem_tags: Array = []         ## GemTD-Auswahlphase: [{tower, panel}] Schilder über den neuen Gems
var _speed_row: HBoxContainer
var debug_panel: PanelContainer
var dps_meter: DpsMeter
var enemy_panel: EnemyPanel
var tower_list: TowerList
var debug_gems: SpinBox
var debug_wave: SpinBox
var immortal_button: Button
var debug_gems_row: HBoxContainer   ## Gems pro Runde (nur GemTD)
var debug_extra: VBoxContainer      ## Platz für Zeilen eines Modus (eeveTD: Holz, Food, Elemente …)
var debug_pick_caption: Label       ## Überschrift der Auswahl „Nächster Gem“ (Modi benennen sie um)
var debug_wave_label: Label
var debug_wave_hint: Label
var debug_keys: Array[String] = []

var banner: PanelContainer
var phase_title: Label
var phase_label: Label
var oneshot_pill: PanelContainer
var oneshot_label: Label

var pinned_panel: PanelContainer
var waves_panel: PanelContainer
var _has_waves := false
var _waves_yield := false  ## Auswahlkarte bräuchte den Platz unten links: Wellen und Rezepte so lange ausblenden
var waves_box: VBoxContainer
var _waves: Array = []
var pinned_box: VBoxContainer

var bottom: PanelContainer
var strip_col: VBoxContainer
var strip_row: HBoxContainer
var strip_hint: Label
var info_col: VBoxContainer
var info_title: Label
var info_swatch: ColorRect
var info_body: Label
var info_kills: TooltipHost
const ICON_UP := "up"    ## Pfeil-Symbol aus UiTheme.icon (kein Text)
var info_oils: TooltipHost     ## „▲ Öle“ neben dem Namen, Hover zeigt die Werte durch Öle (info.oils)
var _oils_icon: TextureRect
var info_tier: PanelContainer  ## Gem-Stufe als römische Zahl neben dem Namen
var info_tier_label: Label
var info_kills_label: Label
var info_sub: Label
var info_main: HBoxContainer
var info_left: VBoxContainer
var info_tiles: GridContainer
var abil_panel: PanelContainer
var abil_box: VBoxContainer
var _tiles: Array = []  ## je Kachel {host, caption, value, normal, hover}
var _stats: Dictionary = {}  ## TowerStats.view des gewählten Towers
var _abil_key: Variant = null
var _title_size := 18  ## Grundgröße des Namens im Infofenster (je nach Skin)
var used_col: VBoxContainer
var used_row: HBoxContainer
var used_prev: Button
var used_next: Button
var used_page_label: Label
var used_page := 0
var _used_ids: Variant = null  ## sortiert, siehe sort_used_in
var _used_raw: Variant = null
var actions_col: VBoxContainer
var separators: Array[Control] = []

var help_panel: PanelContainer
var message_label: Label
var recipe_book: RecipeBook

var owned: Array = []
var owned_now := {}
var _options: Array = []
var _main_index := -1
var _main_button: Button
var _gems: Array = []
var _used_key := []
var _selection: Dictionary = {}
var _speed := -1.0
var full: Control  ## ganze Fensterfläche über root (root ist bei breiten Fenstern schmaler)
var top_bar: PanelContainer  ## obere Leiste, reicht auch bei schmaler HUD-Fläche über die ganze Breite


func _ready() -> void:
	# Läuft auch bei pausiertem Spiel weiter, damit die Rückfrage beim Verlassen bedienbar bleibt
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Vollfläche über dem ganzen Fenster für Abdunklungen, Hover-Karte und Auswahlrahmen
	full = Control.new()
	full.theme = root.theme
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full)
	_build_top_bar()
	_build_banner()
	_build_pinned()
	_build_bottom()
	_build_help()
	side_tabs = SideTabs.new()
	side_tabs.hud = self
	root.add_child(side_tabs)
	dps_meter = DpsMeter.new()
	dps_meter.game = get_parent()
	dps_meter.tabs = side_tabs
	root.add_child(dps_meter)
	# Rechte Spalte unter dem DPS-Meter: Gegner der Welle, dann die Tower-Liste
	enemy_panel = EnemyPanel.new()
	enemy_panel.game = get_parent()
	enemy_panel.above = dps_meter
	enemy_panel.tabs = side_tabs
	root.add_child(enemy_panel)
	tower_list = TowerList.new()
	tower_list.game = get_parent()
	tower_list.above = enemy_panel
	tower_list.tabs = side_tabs
	tower_list.limits.append(bottom)
	root.add_child(tower_list)
	_build_debug()
	side_tabs.avoid = debug_panel
	dps_meter.avoid = side_tabs
	_build_pause_banner()
	_build_hover_card()
	root.resized.connect(_recenter)
	_fit_width()
	get_viewport().size_changed.connect(_fit_width)
	Display.hud_width_changed.connect(_fit_width)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_label.add_theme_font_size_override("font_size", 48)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(message_label)

	recipe_book = RecipeBook.new()
	root.add_child(recipe_book)
	extra_chance_panel = ExtraChancePanel.new()
	root.add_child(extra_chance_panel)
	_build_game_over()
	_build_leave_confirm()
	recipe_book.pins_changed.connect(_refresh_pinned)
	_refresh_pinned()


func _process(_delta: float) -> void:
	_place_gem_tags()
	if Engine.time_scale != _speed:
		_speed = Engine.time_scale
		for i in SPEEDS.size():
			speed_buttons[i].set_pressed_no_signal(is_equal_approx(SPEEDS[i], _speed))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if game_over != null and game_over.visible:
		return
	if leave_confirm != null and leave_confirm.visible:
		if event.keycode == KEY_ESCAPE and settings_panel.visible:
			settings_panel.close()
		elif event.keycode == KEY_ESCAPE and not _leave_stay.disabled:
			close_leave_confirm()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_P, KEY_PAUSE:
			if pause_button == null or not pause_button.visible:
				return
			set_user_paused(not user_paused)
		KEY_F1:
			help_panel.visible = not help_panel.visible
		KEY_H:
			set_panels_hidden(not panels_hidden)
		KEY_TAB:
			if _gem_tags.is_empty():
				return
			next_gem_requested.emit()
		KEY_R:
			if not recipes_button.visible:
				return
			toggle_recipe_book()
		KEY_ESCAPE:
			if recipe_book.visible:
				recipe_book.close()
			elif extra_chance_panel.visible:
				extra_chance_panel.hide()
			elif help_panel.visible:
				help_panel.hide()
			else:
				return
		KEY_SPACE:
			if recipe_book.visible or _main_button == null or _main_button.disabled:
				return
			option_chosen.emit(_main_index)
		KEY_L:
			if lights_button == null:
				return
			lights_button.button_pressed = not lights_button.button_pressed
		_:
			return
	get_viewport().set_input_as_handled()


# --- Aufbau ------------------------------------------------------------------

func _button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _chip(caption: String, parent: Node, color := UiTheme.TEXT) -> Label:
	var p := TooltipHost.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 10))
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	UiUtil.label(caption, h, 12).add_theme_color_override("font_color", UiTheme.MUTED)
	var v := UiUtil.label("", h, 16)
	v.add_theme_color_override("font_color", color)
	return v


## Kachel im Infofenster (Reichweite, Tempo, Schaden, Schadensart) mit Tooltip, woher der Wert kommt.
func _stat_tile() -> Dictionary:
	var host := TooltipHost.new()
	host.custom_minimum_size.x = 150
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 8)
	var hover := UiTheme.box(UiTheme.PANEL_2, UiTheme.CYAN, 0, 2, 8)
	host.add_theme_stylebox_override("panel", normal)
	host.mouse_entered.connect(func(): host.add_theme_stylebox_override("panel", hover))
	host.mouse_exited.connect(func(): host.add_theme_stylebox_override("panel", normal))
	info_tiles.add_child(host)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(v)
	var caption := UiUtil.label("", v, 11)
	caption.uppercase = true
	caption.add_theme_color_override("font_color", UiTheme.MUTED)
	var value := UiUtil.label("", v, 18)
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.custom_minimum_size.x = 1
	var tile := {"host": host, "caption": caption, "value": value}
	host.make = func(): return _stat_tooltip(_tiles.find(tile))
	return tile


func _vsep(parent: Node) -> void:
	var s := ColorRect.new()
	s.color = UiTheme.BORDER
	s.custom_minimum_size.x = 1
	parent.add_child(s)
	separators.append(s)


## Bei breiten Fenstern (oder kleinerer HUD-Breite in den Einstellungen) rückt alles in eine mittige Fläche.
func _fit_width() -> void:
	var view := get_viewport().get_visible_rect().size
	var cut := maxf(0.0, (view.x - Display.hud_span(view)) / 2.0)
	root.offset_left = cut
	root.offset_right = -cut
	# Die obere Leiste bleibt als Band über die ganze Breite, nur ihr Inhalt rückt nach innen
	top_bar.offset_left = -cut
	top_bar.offset_right = cut
	var st := top_bar.get_theme_stylebox("panel")
	st.content_margin_left = 14 + cut
	st.content_margin_right = 14 + cut


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var bar_style := UiTheme.box(UiTheme.PANEL, Color.TRANSPARENT, 0, 0, 14)
	bar_style.border_color = UiTheme.GOLD
	bar_style.border_width_bottom = 3
	bar_style.shadow_color = UiTheme.SHADOW
	bar_style.shadow_size = 1
	bar_style.shadow_offset = Vector2(0, 4)
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.anchor_right = 1.0
	bar.custom_minimum_size.y = 52
	root.add_child(bar)
	top_bar = bar
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	bar.add_child(h)
	title_label = UiTheme.title(UiUtil.label("GemTD", h, 22))
	h.add_child(_spacer(4))
	wave_value = _chip("Welle", h)
	lives_value = _chip("Leben", h, UiTheme.MISSING)
	gold_value = _chip("Gold", h, UiTheme.COIN)
	path_value = _chip("Weg", h)
	path_value.get_parent().get_parent().tooltip_text = "Länge des Laufwegs der Bodengegner in Feldern (ein Tower ist 2 Felder breit).\nIn Klammern: wie viel länger der Weg in dieser Bauphase geworden ist."
	chance_value = _chip("Chance", h)
	extra_chance_button = _button("Extra Chance", h, func(): extra_chance_requested.emit())
	extra_chance_button.tooltip_text = "Eine Gem-Sorte wählen: jeder Gem dieser Runde wird mit erhöhter Chance zu ihrem Perfekten."
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(fill)

	pause_button = _button("❚❚", h, func(): set_user_paused(not user_paused))
	pause_button.toggle_mode = true
	pause_button.tooltip_text = "Pause (Taste P): Spiel hält an, Tower lassen sich weiter ansehen."
	pause_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	pause_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	key_badge(pause_button, "P")
	pause_button.visible = false
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 0)
	h.add_child(speed_row)
	_speed_row = speed_row
	var group := ButtonGroup.new()
	for f in SPEEDS:
		var b := _button("%dx" % int(f), speed_row, func(): speed_selected.emit(f))
		b.toggle_mode = true
		b.button_group = group
		b.tooltip_text = "Tempo (Tasten 1, 2, 3)"
		key_badge(b, str(SPEEDS.find(f) + 1))
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		speed_buttons.append(b)

	debug_button = _button("Debug", h, func(): debug_panel.visible = not debug_panel.visible)
	debug_button.toggle_mode = true
	debug_button.tooltip_text = "Debug-Menü"
	debug_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	debug_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)

	recipes_button = _button("Rezepte", h, toggle_recipe_book)
	recipes_button.tooltip_text = "Rezeptbuch (Taste R)"
	key_badge(recipes_button, "R")
	key_badge(_button("Hilfe", h, func(): help_panel.visible = not help_panel.visible), "F1")
	key_badge(_button("Menü", h, open_leave_confirm), "Esc")


## Mehrspieler: Umschalter links neben dem Tempo, zeigt auch die Gegnerwege der Mitspieler.
func add_paths_toggle(on_toggled: Callable) -> void:
	paths_button = _button("Alle Wege zeigen", _speed_row.get_parent(), func(): pass)
	_speed_row.get_parent().move_child(paths_button, _speed_row.get_index())
	paths_button.toggle_mode = true
	paths_button.focus_mode = Control.FOCUS_NONE
	paths_button.tooltip_text = "Zeigt auch die Gegnerwege der Mitspieler."
	paths_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	paths_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	paths_button.toggled.connect(on_toggled)


## Umschalter links neben dem Tempo: Lichter fliegen den Gegnerweg entlang (PathLights).
func add_lights_toggle(on: bool, on_toggled: Callable) -> void:
	lights_button = _button("Lichtpfad", _speed_row.get_parent(), func(): pass)
	_speed_row.get_parent().move_child(lights_button, _speed_row.get_index())
	lights_button.toggle_mode = true
	lights_button.focus_mode = Control.FOCUS_NONE
	lights_button.tooltip_text = "Lichter fliegen den Weg der Gegner entlang (Taste L)."
	lights_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	lights_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	lights_button.set_pressed_no_signal(on)
	lights_button.toggled.connect(on_toggled)
	key_badge(lights_button, "L")


## Schalter „Auto“ links neben dem Tempo: nächste Welle ohne Pause starten (eeveTD, YouTD, Randgruppen).
func add_auto_toggle(on: bool, on_toggled: Callable) -> void:
	auto_button = _button("Auto", _speed_row.get_parent(), func(): pass)
	_speed_row.get_parent().move_child(auto_button, _speed_row.get_index())
	auto_button.toggle_mode = true
	auto_button.tooltip_text = "Nächste Welle sofort starten, sobald die alte vorbei ist (sonst Taste N)."
	auto_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	auto_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	auto_button.set_pressed_no_signal(on)
	auto_button.toggled.connect(on_toggled)


## Kleines Tasten-Kästchen rechts unten im Knopf (z. B. „1“ beim Tempo), damit man die Tasten ohne die Hilfe lernt.
## Der Knopf wird so breit, dass der mittige Text nicht darunter liegt.
static func key_badge(b: Button, key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiTheme.CYAN)
	var st := UiTheme.box(UiTheme.BG, UiTheme.CYAN, 0, 1, 0)
	st.content_margin_left = 3
	st.content_margin_right = 3
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", st)
	b.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 2)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var w := l.get_combined_minimum_size().x
	var text_w := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			b.get_theme_font_size("font_size")).x
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, text_w + 2.0 * w + 16.0)
	b.set_meta("key_badge", l)
	return l


# --- Pause (Taste P, nur Einzelspiel) -------------------------------------------------------

func _build_pause_banner() -> void:
	pause_banner = PanelContainer.new()
	pause_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_banner.add_theme_stylebox_override("panel", UiTheme.panel(16.0, 0.95, UiTheme.GOLD))
	pause_banner.anchor_left = 0.5
	pause_banner.anchor_right = 0.5
	pause_banner.offset_top = BANNER_TOP + 52.0
	pause_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(pause_banner)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	pause_banner.add_child(v)
	var t := UiTheme.title(UiUtil.label("PAUSE", v, 26), 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UiUtil.label("P: weiter · Tower lassen sich ansehen", v, 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	pause_banner.hide()


## Pause ein/aus (Taste P, Knopf). Die Welt steht (SceneTree.paused), Oberfläche und Kamera laufen weiter.
func set_user_paused(on: bool) -> void:
	if pause_button == null or not pause_button.visible:
		on = false
	user_paused = on
	pause_button.set_pressed_no_signal(on)
	pause_banner.visible = on
	if pause_banner.visible:
		var s := pause_banner.get_combined_minimum_size()
		pause_banner.offset_left = -s.x / 2.0
		pause_banner.offset_right = s.x / 2.0
	if not leave_confirm.visible:
		get_tree().paused = on
	pause_toggled.emit(on)


# --- Seitenleisten ausblenden (Taste H) -----------------------------------------------------

## Linke Spalte (Wellen, Rezepte, Modus-Leiste) und rechte Spalte (DPS, Gegner, Tower) aus dem Bild schieben.
func set_panels_hidden(on: bool) -> void:
	panels_hidden = on
	left_col.offset_left = -2000.0 if on else 16.0
	for c in [side_tabs, dps_meter, enemy_panel, tower_list]:
		c.offset_right = 2000.0 if on else -16.0
	show_message(tr("Seitenleisten aus · H holt sie zurück") if on else "")


# --- Kurzinfo an der Maus (Hover über Tower) -------------------------------------------------

func _build_hover_card() -> void:
	hover_card = PanelContainer.new()
	hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_card.add_theme_stylebox_override("panel", UiTheme.panel(8.0, 0.95))
	full.add_child(hover_card)
	_hover_label = UiUtil.label("", hover_card, 13)
	hover_card.hide()


## text leer = ausblenden. pos: Mausposition (Bildschirm), die Karte sitzt rechts darüber.
func show_hover_card(text: String, pos: Vector2) -> void:
	if hover_card == null:
		return
	hover_card.visible = text != ""
	if text == "":
		return
	_hover_label.text = text
	hover_card.reset_size()
	var p := full.get_global_transform().affine_inverse() * pos
	var s := hover_card.get_combined_minimum_size()
	hover_card.position = Vector2(clampf(p.x + 18.0, 8.0, full.size.x - s.x - 8.0), clampf(p.y - s.y - 12.0, 60.0, full.size.y - s.y - 8.0))


# --- GemTD-Auswahlphase: Schilder über den neuen Gems -----------------------------------------

## tags: [{tower: Node3D, text, style}] mit style "combine" (grün), "special" (pink), "pinned" (gold), "keep" (grau).
## Leeres Array blendet alle aus. Klick auf ein Schild wählt den Gem (signal round_gem_selected mit dem Index).
func set_gem_tags(tags: Array) -> void:
	var key := tags.map(func(t): return [t.tower.get_instance_id(), t.text, t.style])
	if key == get_meta("gem_tag_key", []):
		return
	set_meta("gem_tag_key", key)
	for g in _gem_tags:
		g.panel.queue_free()
	_gem_tags.clear()
	for i in tags.size():
		var t: Dictionary = tags[i]
		var col: Color = {"combine": UiTheme.HAVE, "special": UiTheme.GOLD, "pinned": UiTheme.COIN}.get(t.style, UiTheme.MUTED)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = t.text
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", col.lightened(0.3))
		b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL, col, 0, 2, 5))
		b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_2, col, 0, 2, 5))
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PANEL_2, UiTheme.CYAN, 0, 2, 5))
		b.tooltip_text = tr("Gem auswählen (Tab: nächster neuer Gem)")
		var idx := i
		b.pressed.connect(func(): round_gem_selected.emit(int(tags[idx].get("index", idx))))
		root.add_child(b)
		root.move_child(b, 0)  # unter allen Fenstern
		_gem_tags.append({"tower": t.tower, "panel": b})
	_place_gem_tags()


func _place_gem_tags() -> void:
	if _gem_tags.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var inv := root.get_global_transform().affine_inverse()
	for g in _gem_tags:
		var b: Button = g.panel
		if not is_instance_valid(g.tower):
			b.hide()
			continue
		var wp: Vector3 = g.tower.global_position + Vector3(0, 1.6, 0)
		b.visible = not cam.is_position_behind(wp)
		var p := inv * cam.unproject_position(wp)
		var s := b.get_combined_minimum_size()
		b.size = s
		b.position = Vector2(p.x - s.x / 2.0, p.y - s.y)


## Wert in der Leiste oben für einen Modus (YouTD: Bücher, Food), rechts neben Gold. Liefert das Wert-Label.
func add_bar_chip(caption: String, color := UiTheme.TEXT) -> Label:
	var h := extra_chance_button.get_parent()
	var l := _chip(caption, h, color)
	h.move_child(l.get_parent().get_parent(), extra_chance_button.get_index())
	return l


## Knopf in der Leiste oben für einen Modus: left = hinter den Werten, sonst links neben dem Tempo.
func add_bar_button(text: String, on_pressed: Callable, left := true) -> Button:
	var h := extra_chance_button.get_parent()
	var b := _button(text, h, on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	h.move_child(b, extra_chance_button.get_index() if left else _speed_row.get_index())
	return b


## Panel-Überschrift: Großbuchstaben, fett.
func _panel_title(l: Label) -> Label:
	return UiTheme.heading(l)


func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c


func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", UiTheme.panel(18.0, 0.92))
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_top = BANNER_TOP
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(banner)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	banner.add_child(h)
	phase_title = UiUtil.label("", h, 15)
	UiTheme.heading(phase_title, UiTheme.CYAN)
	phase_label = UiUtil.label("", h, 15)
	oneshot_pill = PanelContainer.new()
	oneshot_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oneshot_pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PURPLE, Color.TRANSPARENT, 0, 0, 10))
	h.add_child(oneshot_pill)
	oneshot_label = UiUtil.label("", oneshot_pill, 13)
	oneshot_label.add_theme_color_override("font_color", Color.WHITE)


func _build_pinned() -> void:
	# Linke Spalte: nächste Wellen, darunter die angepinnten Rezepte
	var left := VBoxContainer.new()
	left_col = left
	left.offset_left = 16
	left.offset_top = LEFT_TOP
	left.custom_minimum_size.x = 280
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	left.resized.connect(func(): _recenter.call_deferred())
	waves_panel = PanelContainer.new()
	waves_panel.add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	left.add_child(waves_panel)
	waves_box = VBoxContainer.new()
	waves_box.add_theme_constant_override("separation", 8)
	waves_panel.add_child(waves_box)
	pinned_panel = PanelContainer.new()
	pinned_panel.add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	left.add_child(pinned_panel)
	pinned_box = VBoxContainer.new()
	pinned_box.add_theme_constant_override("separation", 10)
	pinned_panel.add_child(pinned_box)


func _build_bottom() -> void:
	bottom = PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", UiTheme.panel(14.0, 0.96))
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = -16
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	bottom.add_child(h)

	strip_col = VBoxContainer.new()
	h.add_child(strip_col)
	UiTheme.caption("Neue Gems dieser Runde", strip_col)
	strip_row = HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 8)
	strip_col.add_child(strip_row)
	strip_hint = UiUtil.label("", strip_col, 12)
	strip_hint.add_theme_color_override("font_color", UiTheme.CYAN_TEXT)
	_vsep(h)

	# Werte links, Fähigkeiten rechts über die ganze Höhe; beide fest breit, damit die Karte beim
	# Wechseln der Auswahl nicht springt (lange Fähigkeiten scrollen statt das Fenster zu vergrößern)
	info_col = VBoxContainer.new()
	h.add_child(info_col)
	info_main = HBoxContainer.new()
	info_main.add_theme_constant_override("separation", 12)
	info_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_col.add_child(info_main)
	info_left = VBoxContainer.new()
	info_left.custom_minimum_size.x = INFO_W
	info_left.add_theme_constant_override("separation", 6)
	info_main.add_child(info_left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	info_left.add_child(head)
	info_swatch = ColorRect.new()
	info_swatch.custom_minimum_size = Vector2(22, 22)
	info_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(info_swatch)
	info_title = UiUtil.label("", head, 18)
	UiTheme.heading(info_title)
	_title_size = info_title.get_theme_font_size("font_size")
	info_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_title.mouse_filter = Control.MOUSE_FILTER_PASS
	info_tier = PanelContainer.new()
	info_tier.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.CYAN, 0, 2, 4))
	info_tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_tier.visible = false
	head.add_child(info_tier)
	info_tier_label = UiUtil.label("", info_tier, 14)
	info_tier_label.add_theme_font_override("font", QualityBadge.roman_font())
	info_tier_label.add_theme_color_override("font_color", UiTheme.CYAN_TEXT)
	# Kills neben dem Namen, Hover zeigt den Kill-Rang
	info_kills = TooltipHost.new()
	info_kills.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.COIN, 0, 2, 4))
	info_kills.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_kills.make = _kills_tooltip
	head.add_child(info_kills)
	info_kills_label = UiUtil.label("", info_kills, 12)
	info_kills_label.add_theme_color_override("font_color", UiTheme.COIN)
	# Öle neben dem Namen (YouTD): nur ein Kästchen, Hover zeigt, welche Werte der Tower durch Öle hat
	info_oils = TooltipHost.new()
	info_oils.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.HAVE, 0, 2, 4))
	info_oils.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_oils.make = _oils_tooltip
	info_oils.visible = false
	head.add_child(info_oils)
	var oils_row := HBoxContainer.new()
	oils_row.add_theme_constant_override("separation", 3)
	oils_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_oils.add_child(oils_row)
	_oils_icon = TextureRect.new()
	_oils_icon.custom_minimum_size = Vector2(12, 12)
	_oils_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_oils_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_oils_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oils_row.add_child(_oils_icon)
	UiUtil.label(tr("Öle"), oils_row, 12).add_theme_color_override("font_color", UiTheme.HAVE)
	# Breite gleich mitgeben: ohne sie misst Godot umbrechende Labels im ersten Frame ein Zeichen breit
	# und damit tausende Pixel hoch, die Auswahlkarte sprang dann kurz auf volle Bildschirmhöhe
	info_sub = UiUtil.wrap_label("", info_left, INFO_W)
	info_sub.add_theme_font_size_override("font_size", 12)
	info_sub.add_theme_color_override("font_color", UiTheme.MUTED)
	info_tiles = GridContainer.new()
	info_tiles.columns = 2
	info_tiles.add_theme_constant_override("h_separation", 6)
	info_tiles.add_theme_constant_override("v_separation", 6)
	info_left.add_child(info_tiles)
	for i in 4:
		_tiles.append(_stat_tile())
	info_body = UiUtil.wrap_label("", info_left, INFO_W)
	info_body.add_theme_font_size_override("font_size", 13)
	info_body.add_theme_color_override("font_color", UiTheme.DIM)
	# Fähigkeiten in einem eigenen Fenster rechts neben den Werten (mit den neuen Gems daneben darunter)
	abil_panel = PanelContainer.new()
	abil_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2 if UiTheme.poster() else UiTheme.BG,
			UiTheme.BORDER if UiTheme.poster() else UiTheme.CYAN, 0, 2, 10))
	abil_panel.custom_minimum_size.x = ABIL_W
	info_main.add_child(abil_panel)
	var abil_scroll := ScrollContainer.new()
	abil_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	abil_panel.add_child(abil_scroll)
	abil_box = VBoxContainer.new()
	abil_box.add_theme_constant_override("separation", 4)
	abil_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abil_scroll.add_child(abil_box)
	_vsep(h)

	used_col = VBoxContainer.new()
	h.add_child(used_col)
	# Kopfzeile mit Pfeilen zum Weiterklicken, darunter genau ein Rezept
	var used_head := HBoxContainer.new()
	used_head.add_theme_constant_override("separation", 6)
	used_col.add_child(used_head)
	UiTheme.caption("Wird gebraucht für", used_head).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	used_prev = UiUtil.button("‹", used_head, func(): _turn_used_page(-1))
	used_page_label = UiUtil.label("", used_head, 12)
	used_page_label.add_theme_color_override("font_color", UiTheme.MUTED)
	used_next = UiUtil.button("›", used_head, func(): _turn_used_page(1))
	for b in [used_prev, used_next]:
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 24)
		b.add_theme_font_size_override("font_size", 16)
	used_row = HBoxContainer.new()
	used_row.custom_minimum_size = Vector2(320, 0)
	used_col.add_child(used_row)
	_vsep(h)

	actions_col = VBoxContainer.new()
	actions_col.custom_minimum_size.x = 260
	actions_col.add_theme_constant_override("separation", 8)
	h.add_child(actions_col)
	for c in [strip_col, info_col, used_col, actions_col]:
		c.visible = false
	_update_layout()


func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.anchor_left = 1.0
	help_panel.anchor_right = 1.0
	help_panel.offset_top = 64
	help_panel.offset_right = -16
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(help_panel)
	UiUtil.wrap_label("Linksklick: Gem setzen / Tower oder Stein auswählen\nMaus auf einem Tower: Reichweite und Kurzinfo\nLinks ziehen, Strg+Klick: bis zu 5 Steine auswählen\nStrg+Z: zuletzt gesetzten Gem zurücknehmen\nRechtsklick, Esc: Auswahl oder Bauen abbrechen\nLeertaste: große Aktion (Behalten / Kombinieren / One-Shot)\nTab: nächster neuer Gem der Runde\nN: nächste Welle sofort, „Auto“: immer sofort\nUmschalt + Klick: Falle weiter setzen\nP: Pause · 1, 2, 3: Tempo\nR: Rezeptbuch · L: Lichtpfad\nH: Seitenleisten aus/ein · F1: diese Hilfe\nWASD/Pfeile, Fensterrand, rechte Maustaste ziehen: Kamera bewegen\nQ/E oder mittlere Maustaste: drehen, Mausrad: zoomen", help_panel, 340)
	help_panel.hide()


## Debug-Menü unter dem Debug-Knopf: Gems pro Runde, Gold, Leben, nächster Gem, Unsterblich, Welle.
func _build_debug() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.anchor_left = 1.0
	debug_panel.anchor_right = 1.0
	debug_panel.offset_top = 60
	debug_panel.offset_right = -16
	debug_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	debug_panel.custom_minimum_size.x = 320
	debug_panel.add_theme_stylebox_override("panel", UiTheme.panel(14.0))
	root.add_child(debug_panel)
	debug_panel.visibility_changed.connect(func(): _recenter.call_deferred())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	debug_panel.add_child(v)
	UiTheme.title(UiUtil.label("Debug", v, 18))

	var row := _debug_row("Gems pro Runde", v)
	debug_gems_row = row
	debug_gems = SpinBox.new()
	debug_gems.min_value = 1
	debug_gems.max_value = 20
	debug_gems.value_changed.connect(func(n): debug_gems_changed.emit(int(n)))
	row.add_child(debug_gems)

	row = _debug_row("Gold", v)
	for n in [100, 1000]:
		_button("+%d" % n, row, func(): debug_gold_requested.emit(n))
	row = _debug_row("Leben", v)
	for n in [10, 50]:
		_button("+%d" % n, row, func(): debug_lives_requested.emit(n))
	debug_extra = VBoxContainer.new()
	debug_extra.add_theme_constant_override("separation", 10)
	debug_extra.hide()
	v.add_child(debug_extra)

	debug_pick_caption = UiTheme.caption("Nächster Gem", v)
	debug_option = OptionButton.new()
	debug_option.fit_to_longest_item = false
	debug_option.clip_text = true
	debug_option.focus_mode = Control.FOCUS_NONE
	debug_option.tooltip_text = "Welcher Gem als nächstes gesetzt wird"
	v.add_child(debug_option)
	debug_option.item_selected.connect(func(i): debug_tower_changed.emit(debug_keys[i]))

	immortal_button = CheckBox.new()
	immortal_button.text = "Unsterblich (Leben dürfen ins Minus)"
	immortal_button.focus_mode = Control.FOCUS_NONE
	immortal_button.toggled.connect(func(on): debug_immortal_changed.emit(on))
	v.add_child(immortal_button)

	row = _debug_row("Welle", v)
	debug_wave_label = row.get_child(0)
	debug_wave = SpinBox.new()
	debug_wave.min_value = 1
	row.add_child(debug_wave)
	_button("Starten", row, func(): debug_wave_requested.emit(int(debug_wave.value)))
	var hint := UiUtil.wrap_label("Läuft gerade eine Welle, wird sie abgebrochen und die gewählte startet sofort. In der Bau- und Wahlphase kommt sie als nächste.", v, 290)
	debug_wave_hint = hint
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	debug_panel.hide()


## Zeile im Debug-Menü für einen Modus (unter Gold und Leben), Knöpfe mit debug_button_in().
func add_debug_row(text: String) -> HBoxContainer:
	return _debug_row(text, debug_extra)


func debug_button_in(row: Node, text: String, on_pressed: Callable) -> Button:
	return _button(text, row, on_pressed)


func _debug_row(text: String, parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := UiUtil.label(text, row, 14)
	l.custom_minimum_size.x = 120
	return row


# --- Schnittstelle für game.gd -------------------------------------------------

func setup_debug_towers(preselect: String) -> void:
	debug_option.clear()
	debug_keys = [""]
	debug_option.add_item(tr("Zufälliger Gem"))
	var specials := Database.special_ids()
	var gems := Database.gem_ids()
	var groups := [["Basis-Gems", gems], ["Spezial-Tower", specials],
			["Sonstige", Database.tower_ids().filter(func(id): return not gems.has(id) and not specials.has(id))]]
	for g in groups:
		if (g[1] as Array).is_empty():
			continue
		# Trenner: OptionButton zählt sie als Einträge mit, daher Platzhalter in debug_keys
		debug_option.add_separator(tr(g[0]))
		debug_keys.append("")
		for id in g[1]:
			for t in Database.tier_count(id):
				debug_keys.append("%s:%d" % [id, t])
				debug_option.add_item(Database.tower_label(id, t))
	debug_option.select(maxi(debug_keys.find(preselect), 0) if preselect != "" else 0)


## Werte für das Debug-Menü: Gems pro Runde und Anzahl der Wellen.
func setup_debug(gems_per_round: int, wave_count: int) -> void:
	debug_gems.set_value_no_signal(gems_per_round)
	debug_wave.max_value = maxi(wave_count, 1)


## lives: im Punkte-Modus (score) die Punkte.
func set_resources(wave: int, waves: int, lives: int, gold: int, score := false) -> void:
	wave_value.text = "%d / %d" % [wave, waves]
	lives_value.text = str(lives)
	var cap: Label = lives_value.get_parent().get_child(0)
	cap.text = tr("Punkte") if score else tr("Leben")
	lives_value.add_theme_color_override("font_color", (UiTheme.CYAN if lives >= 0 else UiTheme.MISSING) if score else UiTheme.MISSING)
	lives_value.get_parent().get_parent().tooltip_text = tr("Punkte-Modus: jeder Kill gibt Punkte, späte Wellen mehr als frühe. Ein Gegner, der durchkommt, kostet die Hälfte seines Werts.") if score else ""
	gold_value.text = str(gold)


## Roguelike: Anzahl gewählter Boni in der Leiste oben, Tooltip mit allen Boni und der nächsten Wahl
## (next_wave -1 = keine mehr). Die Kachel entsteht beim ersten Aufruf rechts neben „Chance“.
func set_boons(lines: Array, next_wave: int) -> void:
	if _boons_value == null:
		var bar := chance_value.get_parent().get_parent()
		_boons_value = _chip("Boni", bar.get_parent(), UiTheme.PURPLE_LIGHT)
		bar.get_parent().move_child(_boons_value.get_parent().get_parent(), bar.get_index() + 1)
	_boons_value.text = str(lines.size())
	var tip := tr("Roguelike: nach jeder zehnten Welle einen von drei Boni wählen.")
	tip += "\n\n" + ("\n".join(lines) if not lines.is_empty() else tr("Noch keine Boni"))
	if next_wave > 0:
		tip += "\n\n" + tr("Nächste Wahl nach Welle %d") % next_wave
	_boons_value.get_parent().get_parent().tooltip_text = tip


## level: aktuelle Chance-Stufe, next_wave: ab dieser Welle gilt die nächste (-1 = schon maximal).
func set_chance(level: int, next_wave: int) -> void:
	chance_value.text = tr("Stufe %d") % level
	var tip := tr("Bessere Gems: die Chance-Stufe steigt automatisch.") + "\n\n" + tr("Stufe %d jetzt") % level + "\n" + chance_lines(level)
	tip += "\n\n" + (tr("Stufe %d ab Welle %d") % [level + 1, next_wave] if next_wave >= 0 else tr("Höchste Stufe erreicht"))
	if next_wave >= 0:
		tip += "\n" + chance_lines(level + 1)
	var host: TooltipHost = chance_value.get_parent().get_parent()
	host.tooltip_text = tip
	host.make = _chance_tooltip.bind(level, next_wave)


## Knopf Extra Chance in der Leiste oben: shown = Modus hat sie, can_buy = jetzt kaufbar, active = gewählte Sorte.
func set_extra_chance(shown: bool, can_buy: bool, active: String) -> void:
	extra_chance_button.visible = shown
	extra_chance_button.disabled = not can_buy and active == ""
	extra_chance_button.text = tr("Extra: %s") % tr(str(Database.towers[active].get("name", active))) if active != "" else tr("Extra Chance")
	if active == "" and not can_buy and extra_chance_panel.visible:
		extra_chance_panel.hide()


## Verzierter Tooltip der Chance-Stufe: Prozent pro Qualität als Balken, darunter die nächste Stufe.
func _chance_tooltip(level: int, next_wave: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size.x = 330
	UiTheme.title(UiUtil.label("◆ " + tr("Chance · Stufe %d") % level + " ◆", v, 18))
	var sub := UiUtil.label("Steigt automatisch mit den Wellen.", v, 12)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	_chance_rows(v, level, 1.0)
	var divider := UiUtil.label("━━ " + (tr("Stufe %d ab Welle %d") % [level + 1, next_wave] if next_wave >= 0 else tr("Höchste Stufe erreicht")) + " ━━", v, 13)
	divider.uppercase = true
	divider.add_theme_font_override("font", UiTheme.font(true))
	divider.add_theme_color_override("font_color", UiTheme.CYAN_TEXT)
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if next_wave >= 0:
		_chance_rows(v, level + 1, 0.6)
	return v


## Eine Zeile pro Qualität mit Chance > 0: Qualitätssymbol, Name, 10er-Balken, Prozent.
func _chance_rows(parent: Node, level: int, alpha: float) -> void:
	var levels: Array = Database.balance.get("chance_levels", [])
	if levels.is_empty():
		return
	var weights: Array = levels[clampi(level, 0, levels.size() - 1)].get("weights", [])
	var total := 0.0
	for w in weights:
		total += float(w)
	for i in weights.size():
		if float(weights[i]) <= 0.0 or total <= 0.0:
			continue
		var pct := roundi(100.0 * float(weights[i]) / total)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.modulate.a = alpha
		parent.add_child(h)
		h.add_child(QualityBadge.new(UiTheme.GOLD, i, Database.TIER_NAMES.size(), 22.0))
		var n := UiUtil.label(Database.TIER_NAMES[mini(i, Database.TIER_NAMES.size() - 1)], h, 13)
		n.custom_minimum_size.x = 120
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 2)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(bar)
		for k in 10:
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(7, 10)
			seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			seg.color = UiTheme.CYAN if k < roundi(pct / 10.0) else UiTheme.BORDER
			bar.add_child(seg)
		var p := UiUtil.label("%3d %%" % pct, h, 13)
		p.add_theme_color_override("font_color", UiTheme.COIN)


## Chance pro Qualität in einer Chance-Stufe, z. B. "Splitter        70 %".
static func chance_lines(level: int) -> String:
	var levels: Array = Database.balance.get("chance_levels", [])
	if levels.is_empty():
		return ""
	var weights: Array = levels[clampi(level, 0, levels.size() - 1)].get("weights", [])
	var total := 0.0
	for w in weights:
		total += float(w)
	var lines := []
	for i in weights.size():
		if float(weights[i]) <= 0.0 or total <= 0.0:
			continue
		var tier_name: String = TranslationServer.translate(Database.TIER_NAMES[mini(i, Database.TIER_NAMES.size() - 1)])
		lines.append("  %-13s %3d %%" % [tier_name, roundi(100.0 * float(weights[i]) / total)])
	return "\n".join(lines)


## oneshot: Text für die lila Markierung, leer = keine.
func set_phase(title: String, text: String, oneshot := "") -> void:
	phase_title.text = title
	phase_label.text = text
	phase_label.visible = text != ""
	oneshot_pill.visible = oneshot != ""
	oneshot_label.text = oneshot
	var border := UiTheme.PURPLE_LIGHT if oneshot != "" else UiTheme.BORDER_2
	var banner_style := banner.get_theme_stylebox("panel")
	if banner_style is StyleBoxFlat:
		banner_style.border_color = border
	_recenter.call_deferred()


## Tower auf dem Feld plus neue Gems, als [id, stufe] – für die Rezeptanzeige.
## now: was gerade zum Bauen zählt, {"pool": [[id, stufe]], "wave": bool} (siehe Recipes.ready_now).
func set_owned(list: Array, now := {}) -> void:
	if list == owned and now == owned_now:
		return
	owned = list
	owned_now = now
	_used_key = []
	_refresh_used_in()
	_refresh_pinned()
	if recipe_book.visible:
		recipe_book.open(owned, owned_now)


## gems: [{label, color, selected, oneshot}] – die neuen Gems der Runde.
func set_round_gems(gems: Array, hint := "") -> void:
	strip_hint.text = hint
	if gems == _gems:
		return
	_gems = gems
	for c in strip_row.get_children():
		strip_row.remove_child(c)
		c.queue_free()
	for i in gems.size():
		var g: Dictionary = gems[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(50, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = g.label
		var border := UiTheme.GOLD if g.selected else (UiTheme.CYAN if g.oneshot else UiTheme.BORDER_2)
		var st := UiTheme.box(Color("030108"), border, 6, 2, 0)
		b.add_theme_stylebox_override("normal", st)
		var hover := st.duplicate() as StyleBoxFlat
		hover.border_color = UiTheme.GOLD
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		var badge := QualityBadge.new(g.color, int(g.get("tier", 0)), int(g.get("tiers", 1)), 38.0, str(g.get("id", "")))
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		badge.offset_left = -13
		badge.offset_top = -19
		badge.offset_right = 13
		badge.offset_bottom = 19
		b.add_child(badge)
		var num := UiUtil.label(QualityBadge.roman(int(g.get("tier", 0))), b, 11)
		num.add_theme_font_override("font", QualityBadge.roman_font())
		num.add_theme_color_override("font_color", UiTheme.TEXT)
		num.add_theme_color_override("font_outline_color", Color("030108"))
		num.add_theme_constant_override("outline_size", 4)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		num.offset_left = -26
		num.offset_top = -17
		num.offset_right = -3
		num.offset_bottom = -1
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): round_gem_selected.emit(i))
		strip_row.add_child(b)
	strip_col.visible = not gems.is_empty()
	_update_layout()


## info: {title, color, body, used_in (Array von Rezept-IDs, null = Abschnitt ausblenden)} oder {} für nichts.
func set_selection(info: Dictionary) -> void:
	_selection = info
	info_col.visible = not info.is_empty()
	if info.is_empty():
		_refresh_used_in()  # sonst bleibt "Wird gebraucht für" nach dem Abwählen stehen
		_update_layout()
		return
	info_title.text = info.title
	# Plakatwand: helle Papierfläche, Turmfarbe deshalb abdunkeln statt aufhellen
	var tint: Color = (info.color as Color).darkened(0.45) if UiTheme.poster() else (info.color as Color).lerp(Color.WHITE, 0.25)
	info_title.add_theme_color_override("font_color", tint)
	info_swatch.color = info.color
	info_tier.visible = info.has("tier")
	if info_tier.visible:
		info_tier_label.text = QualityBadge.roman(int(info.tier))
		info_tier.tooltip_text = tr("Stufe %d von %d") % [int(info.tier) + 1, QualityBadge.spawn_tiers()]
	info_oils.visible = not (info.get("oils", []) as Array).is_empty()
	if info_oils.visible:
		_oils_icon.texture = UiTheme.icon(ICON_UP, 24)  # erst hier: Farbe nach dem Stil des Modus
	info_body.text = info.get("body", "")
	info_body.visible = info_body.text != ""
	_show_stats(info.get("stats", {}))
	_fit_title()
	_refresh_used_in()
	_update_layout()


## Langer Name: Schrift verkleinern, bis er in die feste Breite passt (erst dann „…“).
func _fit_title() -> void:
	var font := info_title.get_theme_font("font")
	var text := info_title.text.to_upper() if info_title.uppercase else info_title.text
	var room := INFO_W - 32.0 - (info_kills.get_combined_minimum_size().x + 10.0 if info_kills.visible else 0.0) \
			- (info_oils.get_combined_minimum_size().x + 10.0 if info_oils.visible else 0.0) \
			- (info_tier.get_combined_minimum_size().x + 10.0 if info_tier.visible else 0.0)
	var size := _title_size
	while size > _title_size - 5 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		size -= 1
	info_title.add_theme_font_size_override("font_size", size)


## options: [{label, style}] mit style "oneshot" (lila), "primary" (gold) oder "normal".
## Der erste One-Shot, sonst die erste Hauptaktion, wird zum großen Button (Leertaste).
func set_options(options: Array) -> void:
	if options == _options:
		return
	_options = options
	_main_button = null
	preview_range_requested.emit(0.0)  # Knöpfe werden neu gebaut, ihr mouse_exited kommt nicht mehr
	for c in actions_col.get_children():
		actions_col.remove_child(c)
		c.queue_free()
	_main_index = -1
	for style in ["oneshot", "primary"]:
		if _main_index < 0:
			for i in options.size():
				if options[i].get("style", "normal") == style:
					_main_index = i
					break
	if not options.is_empty():
		UiTheme.caption("Aktionen", actions_col)
	if _main_index >= 0:
		var o: Dictionary = options[_main_index]
		var main := _main_index
		var big := _option_button(o, o.label, actions_col, func(): option_chosen.emit(main))
		_main_button = big
		big.tooltip_text = o.label + " " + tr("(Leertaste)")
		big.clip_text = true
		big.custom_minimum_size = Vector2(260, 56)
		big.add_theme_font_size_override("font_size", 18)
		if o.style == "oneshot":
			UiTheme.accent_button(big, UiTheme.PURPLE, Color.WHITE, Color(UiTheme.PURPLE_LIGHT, 0.55))
		else:
			UiTheme.accent_button(big, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.45))
		_set_icon(big, o)
		var hint: String = tr("Leertaste") + (" · " + str(o.hint) if o.has("hint") else "")
		UiUtil.wrap_label(hint, actions_col, 260).add_theme_color_override("font_color", UiTheme.MUTED)
	for i in options.size():
		if i == _main_index:
			continue
		var o: Dictionary = options[i]
		var b := _option_button(o, o.label, actions_col, func(): option_chosen.emit(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(260, 40)
		if o.has("sub"):
			_two_line(b, o.label, o.sub, UiTheme.icon(o.icon) if o.has("icon") else null)
		else:
			_set_icon(b, o)
		if o.has("tooltip"):
			b.tooltip_text = o.tooltip
		if o.has("diff") and b.tooltip_text == "":
			b.tooltip_text = o.label
		if o.get("style", "normal") == "oneshot":
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("241a38"), UiTheme.PURPLE_LIGHT))
		b.disabled = bool(o.get("disabled", false))
	actions_col.visible = not options.is_empty()
	_update_layout()


## Aktionsknopf; mit Vorschau (o.diff, o.preview_range) zeigt Hover die neuen Werte und die neue Reichweite.
func _option_button(o: Dictionary, text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := TooltipButton.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	if o.has("diff"):
		b.make = _diff_tooltip.bind(o)
	if o.has("preview_range"):
		var r: float = o.preview_range
		b.mouse_entered.connect(func(): preview_range_requested.emit(r))
		b.mouse_exited.connect(func(): preview_range_requested.emit(0.0))
	return b


## Symbol links im Knopf (Pfeil hoch/runter, Kombinieren), siehe UiTheme.icon.
func _set_icon(b: Button, o: Dictionary) -> void:
	if not o.has("icon"):
		return
	b.icon = UiTheme.icon(o.icon)
	b.add_theme_constant_override("h_separation", 10)
	for st in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(st, Color.WHITE)


## Knopf mit Name oben und kleiner goldener Zeile darunter (z. B. Upgrade und Goldkosten), optional mit Symbol links.
func _two_line(b: Button, title: String, sub: String, icon: Texture2D = null) -> void:
	b.text = ""
	b.tooltip_text = title + " · " + sub
	b.custom_minimum_size.y = 54
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	b.add_child(row)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	# Lange Namen (Items wie „Ultraheißer zOMG-Höllenmaschine“) umbrechen, der Knopf wächst mit
	var t := UiUtil.label(title, v, 15)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 120
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.minimum_size_changed.connect(func(): b.custom_minimum_size.y = maxf(54.0, v.get_combined_minimum_size().y + 12.0))
	var g := UiUtil.label(sub, v, 13)
	g.add_theme_color_override("font_color", UiTheme.COIN)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Infofenster des gewählten Towers ------------------------------------------

## st: TowerStats.view(), {} = keine Werte (Stein, Verschieben).
func _show_stats(st: Dictionary) -> void:
	_stats = st
	var has := not st.is_empty()
	info_sub.visible = has
	info_tiles.visible = has
	info_kills.visible = has and not (st.kills as Dictionary).is_empty()
	abil_panel.visible = has
	if not has:
		return
	info_sub.text = st.subtitle
	info_title.tooltip_text = info_title.text
	var tiles: Array = st.tiles
	for i in _tiles.size():
		var w: Dictionary = _tiles[i]
		w.host.visible = i < tiles.size()
		if i >= tiles.size():
			continue
		var d: Dictionary = tiles[i]
		w.caption.text = d.caption
		w.value.text = d.value
		var col := UiTheme.HAVE if d.mod else (UiTheme.PURPLE_LIGHT if d.key == "type" else UiTheme.TEXT)
		w.value.add_theme_color_override("font_color", col)
		# Text-Fallback; ohne Text zeigt Godot auch den eigenen Tooltip nicht
		w.host.tooltip_text = "\n".join((d.rows as Array).map(func(r): return "%s  %s" % [r[0], r[1]]))
	if info_kills.visible:
		var k: Dictionary = st.kills
		info_kills_label.text = "✖ " + tr("%d Kills") % int(k.kills)
		if k.get("levels", false):
			info_kills_label.text = tr("Lv %d") % int(k.level) + " · ✖ %d" % int(k.kills)
		info_kills.tooltip_text = tr("Kills: %d   Schaden gesamt: %d") % [int(k.kills), int(k.total_damage)]
	var key := [st.abilities, st.description]
	if key == _abil_key:
		return
	_abil_key = key
	for c in abil_box.get_children():
		abil_box.remove_child(c)
		c.queue_free()
	var abils: Array = st.abilities
	var head := UiUtil.label("◆ " + (tr("Beschreibung") if abils.is_empty() and str(st.description) != "" else tr("Fähigkeiten")), abil_box, 12)
	head.uppercase = true
	head.add_theme_font_override("font", UiTheme.font(true))
	head.add_theme_color_override("font_color", UiTheme.CYAN_TEXT)
	for text in abils:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		abil_box.add_child(row)
		var dot := UiUtil.label("✦", row, 12)
		dot.add_theme_color_override("font_color", UiTheme.GOLD)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var l := UiUtil.wrap_label(text, row, 0)
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if str(st.description) != "":
		var d := UiUtil.wrap_label(st.description, abil_box, 0)
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", UiTheme.MUTED)
	if abils.is_empty() and str(st.description) == "":
		var none := UiUtil.wrap_label(tr("Keine besonderen Fähigkeiten"), abil_box, 0)
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", UiTheme.MUTED)
	(abil_box.get_parent() as ScrollContainer).scroll_vertical = 0


func _tip_box(title: String, width := 300.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size.x = width
	UiTheme.title(UiUtil.label(title, v, 15))
	return v


## Zeile links Text, rechts Wert.
func _tip_row(parent: Node, left: String, right: String, color := UiTheme.TEXT, left_color := UiTheme.DIM) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	var l := UiUtil.label(left, h, 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", left_color)
	if right != "":
		UiUtil.label(right, h, 13).add_theme_color_override("font_color", color)
	return h


func _tip_line(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = UiTheme.BORDER_2
	r.custom_minimum_size.y = 1
	parent.add_child(r)


func _tip_note(parent: Node, text: String, width: float) -> void:
	var l := UiUtil.wrap_label(text, parent, width)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiTheme.MUTED)


## Woher ein Wert kommt: Grundwert, Kill-Rang, Auren anderer Tower, darunter die Summe.
func _stat_tooltip(i: int) -> Control:
	if _stats.is_empty() or i < 0 or i >= (_stats.tiles as Array).size():
		return null
	var d: Dictionary = _stats.tiles[i]
	if (d.rows as Array).is_empty():
		return null
	var v := _tip_box(d.caption, 280)
	for r in d.rows:
		_tip_row(v, r[0], r[1], UiTheme.HAVE if r[2] == "up" else UiTheme.TEXT)
	if (d.rows as Array).size() > 1 and not (d.total as Array).is_empty():
		_tip_line(v)
		_tip_row(v, d.total[0], d.total[1], UiTheme.HAVE, UiTheme.TEXT)
	else:
		_tip_note(v, tr("Gerade verändert ihn nichts."), 280)
	return v


## Öle: welche Werte der Tower durch eingesetzte Öle hat (info.oils = [[Wert, Betrag], …]).
func _oils_tooltip() -> Control:
	var rows: Array = _selection.get("oils", [])
	if rows.is_empty():
		return null
	var v := _tip_box(tr("Durch Öle"), 300)
	for r in rows:
		_tip_row(v, str(r[0]), str(r[1]), UiTheme.HAVE)
	_tip_line(v)
	_tip_note(v, tr("Öle werden beim Einsetzen verbraucht und wirken dauerhaft."), 300)
	return v


## Level und EP: Level, Fortschritt zum nächsten, Boni jetzt, nächste Freischaltung (leveling.gd).
func _kills_tooltip() -> Control:
	if _stats.is_empty() or (_stats.kills as Dictionary).is_empty():
		return null
	var k: Dictionary = _stats.kills
	if not k.get("levels", false):
		var w := _tip_box("✖ " + tr("%d Kills") % int(k.kills), 330)
		_tip_row(w, tr("Schaden gesamt"), "%d" % int(k.total_damage), UiTheme.COIN)
		return w
	var v := _tip_box(tr("Level %d") % int(k.level) + " / %d" % int(k.max_level), 330)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	v.add_child(bar)
	var filled := 10 if k.maxed else floori(10.0 * float(k.progress))
	for s in 10:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(12, 8)
		seg.color = UiTheme.COIN if s < filled else UiTheme.BORDER
		bar.add_child(seg)
	if k.maxed:
		_tip_row(v, tr("Höchstes Level erreicht"), "%s EP" % _ep(k.ep), UiTheme.COIN, UiTheme.HAVE)
	else:
		_tip_row(v, "%s / %s EP" % [_ep(k.ep), _ep(k.next)], tr("noch %s") % _ep(k.need), UiTheme.COIN)
	if float(k.bonus) > 0.0:
		_tip_row(v, tr("Schadensbonus jetzt"), TowerStats.pct(k.bonus), UiTheme.HAVE)
	for u in k.unlocked:
		var l := UiUtil.wrap_label("✓ " + str(u), v, 330)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", UiTheme.HAVE)
	if str(k.next_unlock) != "":
		var h := _tip_row(v, tr("Ab Level %d") % int(k.next_unlock_level), "", UiTheme.TEXT, UiTheme.GOLD)
		UiUtil.label(str(k.next_unlock), h, 13).add_theme_color_override("font_color", UiTheme.CYAN)
	_tip_row(v, tr("Kills"), "%d" % int(k.kills), UiTheme.COIN)
	_tip_row(v, tr("Schaden gesamt"), "%d" % int(k.total_damage), UiTheme.COIN)
	if str(k.per_level) != "":
		_tip_line(v)
		_tip_note(v, tr("EP bekommt der Tower für Kills.") + " " + str(k.per_level) + ".", 330)
	return v


static func _ep(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## Was sich bei dieser Aktion an den Werten ändert (alt → neu, grün besser, rot schlechter).
func _diff_tooltip(o: Dictionary) -> Control:
	var v := _tip_box(str(o.label), 330)
	if o.has("sub"):
		UiUtil.label(str(o.sub), v, 12).add_theme_color_override("font_color", UiTheme.COIN)
	elif o.has("tooltip"):
		UiUtil.label(str(o.tooltip), v, 12).add_theme_color_override("font_color", UiTheme.MUTED)
	var rows: Array = o.diff
	if rows.is_empty():
		_tip_note(v, tr("Die Werte bleiben gleich."), 330)
	for r in rows:
		var col := UiTheme.HAVE if int(r.dir) > 0 else (UiTheme.MISSING if int(r.dir) < 0 else UiTheme.TEXT)
		if str(r.label) == "":
			# Fähigkeit: neu/weg in einer Zeile, geändert als alt (grau) und darunter → neu
			if str(r.old) != "":
				var was := UiUtil.wrap_label(str(r.old), v, 330)
				was.add_theme_font_size_override("font_size", 12)
				was.add_theme_color_override("font_color", UiTheme.MUTED)
			var l := UiUtil.wrap_label(("→ " if str(r.old) != "" else "") + str(r.new), v, 330)
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", UiTheme.CYAN_TEXT if str(r.old) != "" else col)
			continue
		var h := _tip_row(v, str(r.label), str(r.old), UiTheme.MUTED)
		UiUtil.label("→", h, 13).add_theme_color_override("font_color", UiTheme.MUTED)
		UiUtil.label(str(r.new), h, 13).add_theme_color_override("font_color", col)
	_tip_line(v)
	_tip_note(v, tr("Grundwerte, ohne Aura- und Kill-Bonus."), 330)
	return v


## Auswahlrahmen (Bildschirmkoordinaten) zeigen; leeres Rechteck blendet ihn aus.
func show_drag_box(r: Rect2) -> void:
	if _drag_box == null:
		_drag_box = Panel.new()
		_drag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drag_box.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.CYAN, 0.12), UiTheme.CYAN, 0, 2, 0))
		full.add_child(_drag_box)
	_drag_box.visible = r.size != Vector2.ZERO
	_drag_box.position = r.position
	_drag_box.size = r.size


func set_options_enabled(enabled: bool) -> void:
	for b in actions_col.get_children():
		if b is Button:
			(b as Button).disabled = not enabled


## waves: [{number, type, detail, color, state}] – type: "Boden", "Flieger", "Masse", "Boss" oder "Gemischt",
## state: "läuft", "nächste" oder "".
func set_waves(waves: Array) -> void:
	var g = get_parent()
	if g != null and g.has_method("wave_warning"):
		waves = waves.map(func(w):
			var c: Dictionary = w.duplicate()
			c.warn = g.wave_warning(int(w.number), str(w.type))
			return c)
	if waves == _waves:
		return
	_waves = waves
	for c in waves_box.get_children():
		waves_box.remove_child(c)
		c.queue_free()
	_panel_title(UiUtil.label("Nächste Wellen", waves_box, 15))
	for w in waves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		waves_box.add_child(row)
		var icon := WaveIcon.new()
		icon.kind = w.type
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		v.add_child(head)
		UiUtil.label(tr("Welle %d") % w.number, head, 14)
		var t := UiUtil.label(tr(w.type), head, 14)
		t.add_theme_color_override("font_color", WaveIcon.COLORS.get(w.type, UiTheme.TEXT))
		if w.state != "":
			var st := UiUtil.label(w.state, head, 12)
			st.add_theme_color_override("font_color", UiTheme.GOLD)
			st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var d := UiUtil.label(w.detail, v, 12)
		d.add_theme_color_override("font_color", UiTheme.MUTED)
		if str(w.get("warn", "")) != "":
			var warn := UiUtil.label(str(w.warn), v, 13)
			warn.add_theme_color_override("font_color", UiTheme.MISSING)
	_has_waves = not waves.is_empty()
	waves_panel.visible = _has_waves and not _waves_yield


func show_message(text: String) -> void:
	message_label.text = text


## delta: wie viel länger der Weg seit Beginn der Bauphase ist (0 = nicht anzeigen).
func set_path_length(cells: int, delta: int) -> void:
	path_value.text = tr("%d Felder") % cells
	if delta != 0:
		path_value.text += " (%+d)" % delta
	path_value.add_theme_color_override("font_color", UiTheme.HAVE if delta > 0 else (UiTheme.MISSING if delta < 0 else UiTheme.TEXT))


## score: Punkte im Punkte-Modus, sonst null.
func show_game_over(victory: bool, wave: int, waves: int, lives: int, kills: int, path_cells: int, score = null, summary := {}) -> void:
	recipe_book.hide()
	help_panel.hide()
	game_over_title.text = "Gewonnen!" if victory else "Verloren"
	game_over_title.add_theme_color_override("font_color", UiTheme.GOLD if victory else UiTheme.MISSING)
	# Schwierigkeit des Modus mit Aufstiegsstufe (game.gd → difficulty_label)
	var g := get_parent()
	var diff_name: String = g.difficulty_label() if g != null and g.has_method("difficulty_label") else tr(Session.difficulty_name())
	game_over_stats.text = tr("Schwierigkeit: ") + diff_name + "\n" + tr("Welle %d von %d\nLeben übrig: %d\nGegner besiegt: %d\nWeglänge am Ende: %d Felder") % [wave, waves, lives, kills, path_cells]
	if score != null:
		game_over_title.text = "Geschafft!"
		game_over_stats.text = tr("Punkte: %d") % int(score) + "\n" + tr("Schwierigkeit: ") + diff_name + "\n" \
			+ tr("Gegner besiegt: %d") % kills + "\n" + tr("Weglänge am Ende: %d Felder") % path_cells
	if g != null and g.has_method("difficulty_label") and int(g.ascension_unlocked) > 0:
		game_over_stats.text += "\n" + tr("Aufstieg %s freigeschaltet!") % Ascension.label(int(g.ascension_unlocked))
	_fill_summary(summary)
	editor_button.visible = Session.return_scene != Session.MAIN_MENU
	editor_button.text = "Zurück zum Map-Editor" if Session.return_scene == Session.MAP_EDITOR else "Zurück zum Tower-Editor"
	game_over.show()


## Endboss-Schaden und (Punkte-Modus) woher die Punkte kommen: Kills und Punkte je Wellentyp.
func _fill_summary(summary: Dictionary) -> void:
	for c in game_over_table.get_children():
		game_over_table.remove_child(c)
		c.queue_free()
	var rows: Array = summary.get("rows", [])
	if not rows.is_empty():
		# fertige Zeilen (eeveTD-Wertung): [Text, Mitte, Punkte]
		game_over_boss.hide()
		game_over_table.show()
		for h in summary.get("headers", ["", "", ""]):
			UiTheme.caption(str(h), game_over_table)
		for r in rows:
			_summary_row(str(r[0]), str(r[1]), str(r[2]))
		return
	var fb: Dictionary = summary.get("final_boss", {})
	game_over_boss.visible = not fb.is_empty()
	if not fb.is_empty():
		var pct := 100.0 * float(fb.damage) / maxf(float(fb.hp), 1.0)
		game_over_boss.text = (tr("Endboss besiegt!") if int(fb.kills) > 0 and pct >= 99.95 else tr("Schaden am Endboss: %s (%.1f %% seiner Leben)") % [_big(float(fb.damage)), pct])
	var types: Dictionary = summary.get("types", {})
	game_over_table.visible = bool(summary.get("score_mode", false))
	if not game_over_table.visible:
		return
	for h in ["Wellentyp", "Kills", "Punkte"]:
		UiTheme.caption(h, game_over_table)
	var lost := 0.0
	var leaks := 0
	for type in ["Boden", "Gemischt", "Masse", "Flieger", "Boss"] + types.keys().filter(func(k): return k not in ["Boden", "Gemischt", "Masse", "Flieger", "Boss"]):
		if not types.has(type):
			continue
		var st: Dictionary = types[type]
		lost += float(st.get("lost", 0.0))
		leaks += int(st.get("leaks", 0))
		_summary_row(tr(str(type)), str(int(st.get("kills", 0))), "%d" % roundi(float(st.get("points", 0.0))))
	if not fb.is_empty():
		_summary_row(tr("Endboss"), "%.0f %%" % (100.0 * float(fb.damage) / maxf(float(fb.hp), 1.0)), "%d" % roundi(float(fb.points)))
	if leaks > 0:
		_summary_row(tr("Durchgelassen"), str(leaks), "−%d" % roundi(lost), UiTheme.MISSING)


func _summary_row(a: String, b: String, c: String, col := Color(0, 0, 0, 0)) -> void:
	for i in 3:
		var l := UiUtil.label([a, b, c][i], game_over_table, 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		if col.a > 0.0:
			l.add_theme_color_override("font_color", col)


## Große Zahlen mit Tausenderpunkten, z. B. 1.234.567
static func _big(x: float) -> String:
	var s := str(roundi(x))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _build_game_over() -> void:
	game_over = Control.new()
	game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over.mouse_filter = Control.MOUSE_FILTER_STOP
	full.add_child(game_over)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(28.0))
	panel.custom_minimum_size.x = 380
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	game_over_title = UiTheme.title(UiUtil.label("", v, 40))
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_stats = UiUtil.label("", v, 15)
	game_over_stats.add_theme_color_override("font_color", UiTheme.DIM)
	game_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_boss = UiUtil.label("", v, 15)
	game_over_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_boss.add_theme_color_override("font_color", UiTheme.GOLD)
	game_over_table = GridContainer.new()
	game_over_table.columns = 3
	game_over_table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game_over_table.add_theme_constant_override("h_separation", 22)
	game_over_table.add_theme_constant_override("v_separation", 4)
	v.add_child(game_over_table)
	v.add_child(_spacer(0))
	var again := _button("Nochmal spielen", v, func(): restart_requested.emit())
	again.tooltip_text = "Dieselbe Map mit denselben Einstellungen neu starten"
	again.custom_minimum_size.y = 52
	again.add_theme_font_size_override("font_size", 18)
	UiTheme.accent_button(again, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.35))
	editor_button = _button("", v, func(): menu_requested.emit())
	editor_button.custom_minimum_size.y = 44
	var menu := _button("Hauptmenü", v, func(): main_menu_requested.emit())
	menu.custom_minimum_size.y = 44
	game_over.hide()


## Spielmenü (Menü-Knopf oder Esc): weiterspielen, Einstellungen, speichern und verlassen.
## Beim Schließen des Fensters dieselbe Rückfrage als „Spiel verlassen?“. Das Spiel ist solange pausiert.
func _build_leave_confirm() -> void:
	leave_confirm = Control.new()
	leave_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	full.add_child(leave_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(28.0))
	panel.custom_minimum_size.x = 380
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_leave_title = UiTheme.title(UiUtil.label("Menü", v, 26))
	_leave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leave_stay = _button("Weiterspielen", v, close_leave_confirm)
	_leave_stay.custom_minimum_size.y = 52
	_leave_stay.add_theme_font_size_override("font_size", 18)
	UiTheme.accent_button(_leave_stay, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.35))
	_button("Einstellungen", v, func(): settings_panel.open()).custom_minimum_size.y = 44
	v.add_child(_spacer(0))
	_leave_text = UiUtil.wrap_label("", v, 380)
	_leave_text.add_theme_color_override("font_color", UiTheme.DIM)
	_leave_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_leave = _button("Speichern und verlassen", v, func(): save_and_leave_requested.emit(_leave_quit))
	_save_leave.custom_minimum_size.y = 44
	_save_leave.add_theme_color_override("font_color", UiTheme.GOLD)
	_leave_plain = _button("Ohne Speichern verlassen", v, func(): leave_requested.emit(_leave_quit))
	_leave_plain.custom_minimum_size.y = 44
	_leave_plain.add_theme_color_override("font_color", UiTheme.MISSING)
	_leave_plain.add_theme_color_override("font_hover_color", UiTheme.MISSING.lightened(0.2))
	_leave_status = UiUtil.label("", v, 14)
	_leave_status.add_theme_color_override("font_color", UiTheme.CYAN_TEXT)
	_leave_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leave_status.hide()
	var hint := UiUtil.label("Esc: weiterspielen", v, 13)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_confirm.hide()
	settings_panel = SettingsPanel.new(false, true)
	leave_confirm.add_child(settings_panel)


## quit: das Fenster wird geschlossen statt ins Menü zu gehen.
func open_leave_confirm(quit := false) -> void:
	_leave_quit = quit
	_leave_title.text = tr("Spiel verlassen?") if quit else tr("Menü")
	settings_panel.hide()
	var mode: String = save_mode.call()
	_save_leave.visible = mode == "single" or mode == "host"
	_leave_plain.text = tr("Ohne Speichern verlassen") if _save_leave.visible else (tr("Beenden") if quit else tr("Verlassen"))
	match mode:
		"single":
			_leave_text.text = tr("Willst du vorher speichern? Über „Spiel laden“ im Hauptmenü geht es später genau hier weiter.")
		"host":
			_leave_text.text = tr("Willst du vorher speichern? Als Host sicherst du die Felder aller Mitspieler, sie können später wieder einsteigen.")
		"client":
			_leave_text.text = tr("Nur der Host speichert. Dein Stand bleibt beim Host, du kannst später wieder einsteigen.")
		_:
			_leave_text.text = tr("Die Partie ist vorbei.")
	set_leave_busy("")
	leave_confirm.show()
	get_tree().paused = true


## Während gespeichert wird: Knöpfe sperren und Hinweis zeigen (leer = wieder freigeben).
func set_leave_busy(text: String, error := false) -> void:
	_leave_status.text = text
	_leave_status.visible = text != ""
	_leave_status.add_theme_color_override("font_color", UiTheme.MISSING if error else UiTheme.CYAN)
	var busy := text != "" and not error
	for b in [_save_leave, _leave_plain, _leave_stay]:
		b.disabled = busy


func close_leave_confirm() -> void:
	settings_panel.hide()
	leave_confirm.hide()
	get_tree().paused = user_paused


func toggle_recipe_book() -> void:
	if recipe_book.visible:
		recipe_book.close()
	else:
		recipe_book.open(owned, owned_now)


# --- intern ------------------------------------------------------------------

func _refresh_used_in() -> void:
	var raw = _selection.get("used_in", null)
	if raw != null:
		# Fallen nur zeigen, wenn sie gerade wirklich kombinierbar sind (sonst wirken sie wie ein möglicher Merge)
		raw = (raw as Array).filter(func(sid): return str(Database.towers.get(sid, {}).get("kind", "tower")) != "trap" \
				or Recipes.ready_now(sid, owned, owned_now))
	var sort_key := [raw, owned, owned_now]
	if sort_key != _used_raw:
		if raw != (_used_raw[0] if _used_raw != null else null):
			used_page = 0
		_used_raw = sort_key
		# Gezählt werden nur fixierte Tower und der gerade ausgewählte Gem (steckt beides in owned)
		_used_ids = sort_used_in(raw, owned) if raw != null else null
	var ids = _used_ids
	var key := [ids, Session.pinned_recipes.duplicate(), owned, owned_now, used_page]
	if key == _used_key:
		return
	_used_key = key
	for c in used_row.get_children():
		used_row.remove_child(c)
		c.queue_free()
	used_col.visible = ids != null
	if ids == null:
		return
	var count := (ids as Array).size()
	used_prev.visible = count > 1
	used_next.visible = count > 1
	used_page_label.visible = count > 1
	used_page_label.text = "%d / %d" % [used_page + 1, count]
	if count == 0:
		UiUtil.label("Keine Rezepte brauchen diesen Tower.", used_row, 13).add_theme_color_override("font_color", UiTheme.MUTED)
		return
	var c := RecipeBook.card(ids[used_page], owned, _on_pins_changed, true, owned_now)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	used_row.add_child(c)
	_recenter.call_deferred()


## Zuerst die Rezepte, für die schon die meisten Zutaten stehen; bei Gleichstand Tower vor Fallen.
static func sort_used_in(ids: Array, have: Array) -> Array:
	var keyed := []
	for i in ids.size():
		var sid: String = ids[i]
		var recipe: Array = Database.towers.get(sid, {}).get("recipe", [])
		var got: int = recipe.size() - int(Recipes.status(sid, have).missing)
		var trap := 1 if str(Database.towers.get(sid, {}).get("kind", "tower")) == "trap" else 0
		keyed.append([got, trap, i, sid])
	keyed.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	return keyed.map(func(k): return k[3])


func _turn_used_page(step: int) -> void:
	var count := (_used_ids as Array).size() if _used_ids != null else 0
	if count == 0:
		return
	used_page = posmod(used_page + step, count)
	_refresh_used_in()


func _on_pins_changed() -> void:
	_refresh_pinned.call_deferred()
	_refresh_used_in.call_deferred()


func _refresh_pinned() -> void:
	if pinned_box == null:
		return
	for c in pinned_box.get_children():
		pinned_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	pinned_box.add_child(head)
	var t := _panel_title(UiUtil.label("Angepinnt", head, 15))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.label("%d" % Session.pinned_recipes.size(), head, 12).add_theme_color_override("font_color", UiTheme.MUTED)
	for id in Session.pinned_recipes:
		if Database.towers.has(id):
			pinned_box.add_child(RecipeBook.card(id, owned, _on_pins_changed, true, owned_now))
	pinned_panel.visible = not Session.pinned_recipes.is_empty() and not _waves_yield


func _update_layout() -> void:
	# Trennlinien nur zwischen sichtbaren Spalten
	var cols: Array[Control] = [strip_col, info_col, used_col, actions_col]
	var any_before := false
	for i in cols.size():
		if i > 0:
			separators[i - 1].visible = any_before and cols[i].visible
		any_before = any_before or cols[i].visible
	bottom.visible = any_before
	# Mit den neuen Gems daneben wird es zu breit: Fähigkeiten dann unter die Werte
	var abil_parent: Node = info_left if strip_col.visible else info_main
	if abil_panel.get_parent() != abil_parent:
		abil_panel.reparent(abil_parent)
	# Unter den Werten mit fester Höhe, daneben so hoch wie die Karte
	abil_panel.custom_minimum_size.y = ABIL_UNDER_H if strip_col.visible else 0.0
	abil_panel.size_flags_vertical = Control.SIZE_FILL
	_recenter.call_deferred()


## Linke Spalte (Modus-Seitenleiste, nächste Wellen, Rezepte) und Auswahlkarte unten dürfen sich nicht
## überdecken: Passt die Karte rechts neben die Spalte, rückt sie dorthin, sonst blenden sich
## nächste Wellen und angepinnte Rezepte aus, solange die Karte offen ist.
func _avoid_left_col(left: float, right_edge: float, s: Vector2) -> float:
	var card_top := root.size.y - 16.0 - s.y
	var yield_now := false
	if bottom.visible and left_col.visible:
		var col_w := left_col.size.x
		var y := left_col.position.y
		var sep := float(left_col.get_theme_constant("separation"))
		var ends_low := false
		for ch in left_col.get_children():
			var shown: bool = ch.visible or (ch == waves_panel and _has_waves) \
				or (ch == pinned_panel and not Session.pinned_recipes.is_empty())
			if not shown:
				continue
			# Echte Höhe (umbrochene Texte sind höher als ihr Minimum); ausgeblendete mit der zuletzt gesehenen,
			# sonst schaltet das Ein- und Ausblenden hin und her
			var hgt: float = (ch as Control).size.y if ch.visible else float(ch.get_meta("last_h", 0.0))
			if ch.visible:
				ch.set_meta("last_h", hgt)
				ch.set_meta("last_w", (ch as Control).size.x)
			col_w = maxf(col_w, float(ch.get_meta("last_w", 0.0)))
			y += maxf(hgt, (ch as Control).get_combined_minimum_size().y)
			if y > card_top:
				ends_low = true
				if ch != waves_panel and ch != pinned_panel:
					break  # Modus-Seitenleiste selbst ist zu hoch: Karte muss ausweichen
			y += sep
		var col_right := left_col.position.x + col_w + 12.0
		if ends_low:
			if right_edge - col_right >= s.x:
				left = maxf(left, col_right)
			else:
				yield_now = true
	if yield_now != _waves_yield:
		_waves_yield = yield_now
		waves_panel.visible = _has_waves and not _waves_yield
		pinned_panel.visible = not Session.pinned_recipes.is_empty() and not _waves_yield
	return left


## Banner und Auswahlkarte bleiben mittig und passen sich dem Inhalt an (auch beim Schrumpfen).
func _recenter() -> void:
	for c in [banner, bottom]:
		var s: Vector2 = c.get_combined_minimum_size()
		c.offset_left = -s.x / 2.0
		c.offset_right = s.x / 2.0
		if c == bottom:
			# Nicht unter die rechte Spalte (DPS, Tower-Liste, Mitspieler) schieben: lieber nach links
			# rücken, solange links noch Platz ist
			# Mittig bleiben, solange über der Karte noch Platz für ein paar Zeilen der Tower-Liste ist
			var w := root.size.x
			var right_edge := w - 16.0 - tower_list.custom_minimum_size.x - 12.0
			var left := w / 2.0 - s.x / 2.0
			if root.size.y - 16.0 - s.y < tower_list.offset_top + 140.0:
				left = minf(left, maxf(16.0, right_edge - s.x))
			left = _avoid_left_col(left, right_edge, s)
			c.offset_left = left - w / 2.0
			c.offset_right = c.offset_left + s.x
			c.offset_top = -16 - s.y
			c.offset_bottom = -16
		else:
			c.offset_bottom = c.offset_top + s.y
			# Offenes Debug-Fenster rechts oben nicht berühren: Banner dann nach links rücken
			if debug_panel != null and debug_panel.visible:
				var limit := debug_panel.position.x - 12.0 - root.size.x / 2.0
				if c.offset_right > limit:
					c.offset_left -= c.offset_right - limit
					c.offset_right = limit
