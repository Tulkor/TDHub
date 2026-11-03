extends Control
## Hauptmenü als Hub: zuerst Einzelspieler oder Mehrspieler, darunter Laden, Run-History, Editoren, Einstellungen.
## Einzelspieler: TD-Modus (data/modes.json) und Map wählen, dann Spielen.
## Mehrspieler: Lobby (lobby_panel.gd), dort stimmen alle über den Modus ab.

var maps: Array = []   ## alle Maps (Database.list_maps())
var shown_maps: Array = []   ## Maps des gewählten Modus, in der Einzelspieler-Auswahl
var selected := 0   ## Index in shown_maps
var cards_box: GridContainer
var play_button: Button
var cards: Array[Button] = []
var mode_cards: Array[Wc3Button] = []
var settings: Control
var lobby: LobbyPanel
var loader: LoadPanel
var net_tile: Wc3Button
var net_tile_text: Label
var map_caption: Label
var map_info: Label
var map_title: Label
var mode_hint: Label
var map_scroll: ScrollContainer
var no_map_hint: Label
var single_page: Control
var profile: ProfilePanel
var profile_page: Control
var credits_page: Control
var hub: Control
var hub_bg: Wc3MenuBg
var hub_tip: Label
var hub_buttons: Array[Wc3Button] = []

const SHADE := preload("res://scripts/ui/wc3_shade.gdshader")


func _ready() -> void:
	Session.load_last()
	UiTheme.use_skin(UiTheme.ARCADE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = DecoTheme.get_theme()
	_build_hub()
	_build_single()
	# Profil und Run-History im WC3-Stil über der Nachtszene (profile_panel.gd, Lukas 2026-11-01)
	profile = ProfilePanel.new()
	profile.back_requested.connect(func(): show_page(""))
	profile.replay_requested.connect(_replay)
	add_child(profile)
	profile.hide()
	profile_page = profile
	credits_page = _page()
	var cv: VBoxContainer = credits_page.get_meta("box")
	_back_button(cv.get_child(0), func(): show_page(""))
	DecoTheme.title(UiUtil.label("Mitwirkende", cv.get_child(0), 44)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DecoTheme.head_line(cv.get_child(0))
	var credits := CreditsPanel.new()
	credits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(credits)
	_reload()
	_build_settings()
	lobby = LobbyPanel.new()
	lobby.maps = maps
	add_child(lobby)
	lobby.hide()
	lobby.start_requested.connect(_start_session)
	# Die Lobby liegt über dem Hub (auch direkt geöffnet nach einer Sitzung): Säule und Logo dann ausblenden
	lobby.visibility_changed.connect(func(): hub.visible = not lobby.visible and not single_page.visible \
		and not profile_page.visible and not credits_page.visible)
	loader = LoadPanel.new()
	add_child(loader)
	loader.hide()
	loader.load_requested.connect(_load_save)
	Net.players_changed.connect(_update_net_tile)
	Net.connection_changed.connect(_update_net_tile)
	_update_net_tile()
	show_page("")
	# Zurück aus einer Sitzung: Lobby gleich zeigen, dort geht es mit „Mitspielen“ weiter
	if Net.is_active():
		lobby.show()
	if Session.reopen_settings:
		Session.reopen_settings = false
		settings.show()


## Seite zeigen: "" = Hub, "single" = Einzelspieler, "history" = Run-History, "profile" = Profil,
## "credits" = Mitwirkende, "lobby" = Mehrspieler.
func show_page(page: String) -> void:
	hub.visible = page == ""
	# Die 3D-Nachtszene bleibt auch hinter Einzelspieler und Lobby (WC3-Stil)
	hub_bg.visible = page == "" or page == "single" or page == "lobby" or page == "profile" or page == "history"
	hub_bg.process_mode = Node.PROCESS_MODE_INHERIT if hub_bg.visible else Node.PROCESS_MODE_DISABLED
	single_page.visible = page == "single"
	credits_page.visible = page == "credits"
	profile_page.visible = page == "profile" or page == "history"
	if page == "profile":
		profile.show_view("overview")
	elif page == "history":
		profile.show_view("overview")
		profile.show_history()
	lobby.visible = page == "lobby"
	if page == "single":
		_update_selection()


## Hub im Warcraft-III-Stil (Wc3Theme, Lukas 2026-10-30): 3D-Nachtszene, Logo links oben, Steinsäule mit Knöpfen
## rechts, darunter links eine Hinweiszeile zum Knopf unter der Maus. Hotkeys wie in WC3 (heller Buchstabe).
func _build_hub() -> void:
	hub_bg = Wc3MenuBg.new()
	add_child(hub_bg)
	hub = Control.new()
	hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hub)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.material = ShaderMaterial.new()
	shade.material.shader = SHADE
	hub.add_child(shade)
	# Linke Spalte: Logo, Untertitel, Modi; so breit, wie neben der Säule Platz ist
	var left := VBoxContainer.new()
	left.anchor_bottom = 1.0
	left.anchor_right = 1.0
	left.offset_left = 60
	left.offset_top = 14
	left.offset_right = -(420 + 66 + 40)
	left.offset_bottom = -40
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub.add_child(left)
	var logo := Wc3Logo.new()
	logo.custom_minimum_size.x = 0
	logo.size_flags_horizontal = Control.SIZE_FILL
	var logo_box := CenterContainer.new()
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(logo_box)
	logo_box.add_child(logo)
	logo_box.resized.connect(func(): logo.custom_minimum_size.x = minf(logo_box.size.x, 640))
	# Anzahl und Namen der Modi aus data/modes.json, damit neue Modi von selbst dazukommen
	var names := Database.modes.filter(func(m): return bool(m.get("ready", false))).map(func(m): return str(m.get("name", m.id)))
	var count_words := ["Zwei", "Drei", "Vier", "Fünf", "Sechs", "Sieben", "Acht", "Neun"]
	var count := tr(count_words[clampi(names.size() - 2, 0, count_words.size() - 1)]) if names.size() >= 2 else str(names.size())
	var rule := HBoxContainer.new()
	rule.alignment = BoxContainer.ALIGNMENT_CENTER
	rule.add_theme_constant_override("separation", 12)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(rule)
	rule.add_child(_rule_line())
	Wc3Theme.label("◆  " + tr("%s Tower-Defense-Spiele") % count + "  ◆", rule, 19, Wc3Theme.CREAM, 5)
	rule.add_child(_rule_line())
	var modes := Wc3Theme.label(" · ".join(names), left, 15, Wc3Theme.MODES, 3)
	modes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(spacer)
	hub_tip = Wc3Theme.label("", left, 17, Wc3Theme.CREAM, 1)
	hub_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Unten links: Version, bei offener Sitzung die Zahl der Verbundenen
	var foot := HBoxContainer.new()
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 24
	foot.offset_top = -38
	foot.add_theme_constant_override("separation", 18)
	hub.add_child(foot)
	Wc3Theme.label(CreditsPanel.version_text(), foot, 14, Wc3Theme.MUTED, 1)
	net_tile_text = Wc3Theme.label("", foot, 14, Wc3Theme.HAVE, 1)
	# Säule rechts, senkrecht mittig
	var pillar := Wc3Pillar.new()
	pillar.anchor_left = 1.0
	pillar.anchor_right = 1.0
	pillar.anchor_top = 0.5
	pillar.anchor_bottom = 0.5
	pillar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pillar.grow_vertical = Control.GROW_DIRECTION_BOTH
	pillar.offset_right = -66
	pillar.offset_left = -66 - 420
	hub.add_child(pillar)
	hub_buttons.clear()
	# Weiterspielen: jüngster Einzelspiel-Stand (Autosave nach jeder Welle, Lukas 2026-11-03), ein Klick
	var last := continue_save()
	if not last.is_empty():
		var meta: Dictionary = last.get("meta", {})
		var mode_name := str(Database.mode(str(last.get("mode", "gemtd"))).get("name", last.get("mode", "")))
		var desc := "%s · %s · %s" % [mode_name, tr(str(meta.get("map", ""))), tr("Welle %d") % int(meta.get("wave", 0))]
		var cont := pillar.button("Weiterspielen", true, desc, func(): _load_save(last))
		cont.set_meta("continue", true)
		hub_buttons.append(cont)
	hub_buttons.append(pillar.button("Einzelspieler", true, "Allein spielen, Modus und Map wählen und den Weg verteidigen.", func(): show_page("single")))
	net_tile = pillar.button("Mehrspieler", true, "Sitzung hosten oder per IP beitreten. In der Lobby stimmt ihr gemeinsam über den Modus ab.", func(): show_page("lobby"))
	hub_buttons.append(net_tile)
	hub_buttons.append(pillar.button("Spiel laden", true, "Einen gespeicherten Spielstand fortsetzen.", func(): loader.show()))
	pillar.separator()
	var row := pillar.row()
	hub_buttons.append(pillar.button("Profil", false, "Erfahrung, Rekorde und Werte aus allen Modi.", func(): show_page("profile"), row))
	hub_buttons.append(pillar.button("Run-History", false, "Frühere Läufe ansehen und eine Map nochmal spielen.", func(): show_page("history"), row))
	row = pillar.row()
	hub_buttons.append(pillar.button("Map-Editor", false, "Eigene Maps bauen und bearbeiten.", _open_map_editor, row))
	hub_buttons.append(pillar.button("Tower-Editor", false, "Tower und ihre Fähigkeiten bearbeiten.", _open_tower_editor, row))
	pillar.separator()
	hub_buttons.append(pillar.button("Einstellungen", false, "Anzeige, Grafik und Sprache einstellen.", _open_settings))
	hub_buttons.append(pillar.button("Mitwirkende", false, "Wer am Spiel mitgewirkt hat, mit allen Lizenzen.", func(): show_page("credits")))
	hub_buttons.append(pillar.button("Daten neu laden", false, "JSON-Dateien unter data/ neu einlesen", _reload))
	hub_buttons.append(pillar.button("Beenden", true, "Das Spiel beenden.", func(): get_tree().quit()))
	for b in hub_buttons:
		b.mouse_entered.connect(func(): hub_tip.text = tr(b.description))
		b.mouse_exited.connect(_reset_tip)
	_assign_hotkeys()
	_reset_tip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not hub_buttons.is_empty():
		_assign_hotkeys()
		_reset_tip()


func _rule_line() -> Control:
	var line := ColorRect.new()
	line.color = Wc3Theme.GOLD
	line.custom_minimum_size = Vector2(110, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _reset_tip() -> void:
	hub_tip.text = tr(hub_buttons[0].description)


## Hotkey je Knopf: erster freier Wortanfang im übersetzten Text, sonst der erste freie Buchstabe.
func _assign_hotkeys() -> void:
	var used := {}
	for b: Wc3Button in hub_buttons:
		var text := b.shown_text()
		b.hotkey = -1
		var picks: Array[int] = []
		for i in text.length():
			if (i == 0 or text[i - 1] in [" ", "-"]) and text[i].to_upper() != text[i].to_lower():
				picks.append(i)
		for i in text.length():
			if text[i].to_upper() != text[i].to_lower() and not i in picks:
				picks.append(i)
		for i in picks:
			var key := text[i].to_upper()
			if not used.has(key):
				used[key] = b
				b.hotkey = i
				break
		b.queue_redraw()


## Hotkey gedrückt: nur im Hub ohne offenes Fenster darüber.
func _hub_hotkey(event: InputEventKey) -> bool:
	if not hub.visible or settings.visible or loader.visible or lobby.visible:
		return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.unicode == 0:
		return false
	var key := String.chr(event.unicode).to_upper()
	for b: Wc3Button in hub_buttons:
		if b.hotkey >= 0 and b.shown_text()[b.hotkey].to_upper() == key and not b.disabled:
			b.pressed.emit()
			return true
	return false


func _margin(parent: Node) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 52)
	parent.add_child(margin)
	return margin


## Unterseite über dem Hub mit eigenem Hintergrund. Meta "box": VBox für den Inhalt, erstes Kind ist die Kopfzeile.
func _page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(page)
	page.add_child(DecoBackdrop.new())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_margin(page).add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	page.set_meta("box", v)
	page.hide()
	return page


func _back_button(head: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button("◂ " + tr("Zurück").to_upper(), head, on_pressed)
	b.custom_minimum_size.y = 40
	b.add_theme_font_override("font", DecoTheme._variant(DecoTheme.FONT, 0.3, 2))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Einzelspieler im Warcraft-III-Stil wie der Hub (Lukas 2026-11-01): 3D-Nachtszene bleibt im Hintergrund,
## drei Steintafeln: I. Modus (Knöpfe wie die Säule, gewählter rot), II. Map (Karten mit Messingrahmen),
## III. Start (Angaben, Spielen und Zurück unten rechts wie in WC3).
func _build_single() -> void:
	single_page = Control.new()
	single_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	single_page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(single_page)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0, 0, 0, 0.45)
	single_page.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 30)
	single_page.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	head.add_child(_rule_line())
	Wc3Theme.label("◆", head, 16, Wc3Theme.GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Wc3Theme.label(tr("Einzelspieler").to_upper(), head, 40, Wc3Theme.GOLD_HI, 6)
	Wc3Theme.label("◆", head, 16, Wc3Theme.GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_rule_line())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	v.add_child(body)

	var left := Wc3Pillar.new(false, 450)
	body.add_child(left)
	_panel_caption("I · Modus", left.box)
	# Beschreibung des gewählten Modus direkt unter der Liste
	var mode_list := VBoxContainer.new()
	mode_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_list.add_theme_constant_override("separation", 10)
	left.box.add_child(mode_list)
	for m in Database.modes:
		var b := Wc3Button.new(str(m.get("name", m.id)), false)
		b.toggle_mode = true
		b.custom_minimum_size.y = 52
		b.set_meta("mode_id", str(m.id))
		var id := str(m.id)
		b.pressed.connect(func():
			Session.game_kind = id
			_fill_maps())
		mode_list.add_child(b)
		mode_cards.append(b)
	left.separator()
	mode_hint = _body_label("", left.box, 17, Wc3Theme.CREAM)
	mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var mid := Wc3Pillar.new(false, 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid)
	map_caption = _panel_caption("II · Map", mid.box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.box.add_child(scroll)
	map_scroll = scroll
	no_map_hint = _body_label("Dieser Modus wählt seine Karte selbst vor dem Start.", mid.box, 18, Wc3Theme.MUTED)
	no_map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_map_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Zwei Spalten Map-Karten (Lukas 2026-11-01), die Karten teilen sich die Breite
	cards_box = GridContainer.new()
	cards_box.columns = 2
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("h_separation", 18)
	cards_box.add_theme_constant_override("v_separation", 18)
	var cards_margin := MarginContainer.new()
	cards_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		cards_margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(cards_margin)
	cards_margin.add_child(cards_box)

	var right := Wc3Pillar.new(false, 420)
	body.add_child(right)
	_panel_caption("III · Start", right.box)
	map_title = Wc3Theme.label("", right.box, 22, Wc3Theme.GOLD_HI, 2)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_title.custom_minimum_size.x = 280
	map_info = _body_label("", right.box, 17, Wc3Theme.CREAM)
	map_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.separator()
	var hint := _body_label("Doppelklick auf eine Map startet sie direkt. Schwierigkeit und Wertung wählst du im Spiel vor Runde 1.", right.box, 16, Wc3Theme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.box.add_child(fill)
	play_button = right.button("Spielen", true, "", _play)
	play_button.custom_minimum_size.y = 64
	right.button("Zurück", false, "", func(): show_page(""))


## Überschrift einer Steintafel: Cinzel zwischen Messinglinien.
func _panel_caption(text_de: String, parent: Node) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var a := _rule_line()
	a.custom_minimum_size.x = 30
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	var l := Wc3Theme.label(tr(text_de).to_upper(), row, 18, Wc3Theme.CREAM, 4)
	var b := _rule_line()
	b.custom_minimum_size.x = 30
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	l.set_meta("row", row)
	return l


## Fließtext auf den Steintafeln: Alegreya (wie Friz Quadrata in WC3 gut lesbar), dunkler Schatten.
func _body_label(text: String, parent: Node, size: int, color: Color) -> Label:
	var l := UiUtil.label(text, parent, size)
	l.add_theme_font_override("font", DruidTheme.font(false))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_modes() -> void:
	if not Database.mode_allows(Session.game_kind, 1):
		for m in Database.modes:
			if Database.mode_allows(str(m.id), 1):
				Session.game_kind = str(m.id)
				break
	for card in mode_cards:
		var id: String = card.get_meta("mode_id")
		var ok := Database.mode_allows(id, 1)
		var tag := ""
		if not bool(Database.mode(id).get("ready", false)):
			tag = tr("Kommt noch")
		elif not ok:
			tag = tr("Nicht solo")
		card.disabled = not ok
		card.set_pressed_no_signal(ok and id == Session.game_kind)
		card.side_text = tag if tag != "" else Database.mode_players_text(id)
		card.queue_redraw()
	mode_hint.text = tr(str(Database.mode(Session.game_kind).get("hint", "")))


## Einstellungen: gleiches Fenster wie im Spiel, hier in Art déco.
func _build_settings() -> void:
	settings = SettingsPanel.new(true)
	add_child(settings)


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _open_settings() -> void:
	settings.show()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and _hub_hotkey(event):
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		return
	if settings.visible:
		settings.hide()
	elif single_page.visible or profile_page.visible:
		show_page("")
	else:
		return
	get_viewport().set_input_as_handled()


## „Map nochmal spielen“: gleiche Map, Schwierigkeit und Wertung wie der Lauf (Run-History kennt nur GemTD).
func _replay(run: Dictionary) -> void:
	Session.game_kind = str(run.get("mode", "gemtd"))
	_fill_maps()
	for i in shown_maps.size():
		if shown_maps[i].path == str(run.get("map_path", "")) or shown_maps[i].name == str(run.get("map", "")):
			selected = i
			break
	Session.difficulty = clampi(int(run.get("difficulty", Session.difficulty)), 0, Session.DIFFICULTIES.size() - 1)
	Session.score_mode = bool(run.get("score_mode", false))
	_play()


func _reload() -> void:
	Database.reload()
	maps = Database.list_maps()
	if lobby != null:
		lobby.maps = maps
	_fill_maps()


## Map-Karten für den gewählten Modus neu aufbauen.
func _fill_maps() -> void:
	_update_modes()
	shown_maps = Database.maps_for_mode(Session.game_kind, maps)
	selected = maxi(shown_maps.map(func(m): return m.path).find(Session.map_path), 0)
	for c in cards_box.get_children():
		cards_box.remove_child(c)
		c.queue_free()
	cards.clear()
	for i in shown_maps.size():
		cards.append(_map_card(i))
	_update_selection()


func _map_card(i: int) -> Button:
	var md := MapData.load_file(shown_maps[i].path)
	var b := Wc3Card.new()
	b.custom_minimum_size = Vector2(250, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_child(b)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 16
	v.offset_right = -16
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	var preview := MapPreview.new()
	preview.custom_minimum_size = Vector2(218, 190)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.bg = Wc3Theme.PREVIEW_BG
	preview.map = md
	v.add_child(preview)
	# Lange Namen („Schlucht (zufällige Steine)“) umbrechen statt abkürzen; die Karte wächst mit
	var name_label := Wc3Theme.label(tr(shown_maps[i].name), v, 17, Wc3Theme.GOLD_HI, 1)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = 218
	var info := ""
	var short := ""
	if md != null:
		var waves: int = (Database.wave_sets.get(md.wave_set, {}).get("waves", []) as Array).size()
		info = tr("%d×%d · %d Wellen · %d Leben · %d Checkpoints") % [md.width, md.height, waves, md.lives, md.checkpoints.size()]
		short = "%d×%d · " % [md.width, md.height] + tr("%d Wellen") % waves
		var rocks := int(md.variance.get("random_rocks", 0))
		info += "\n" + tr("Weg ohne Labyrinth: %d Felder") % preview.path_length()
		if rocks > 0:
			info += " · " + tr("%d zufällige Steine") % rocks
		if not md.zones.is_empty():
			var seats := {}
			for z in md.zones:
				seats[z.player] = true
			info += "\n" + tr("Koop: %d Zonen, %d Bahnen") % [seats.size(), md.lane_count()]
	var l := _body_label(short, v, 15, Wc3Theme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	b.set_meta("info", info.replace(" · ", "\n").replace("\n\n", "\n"))
	var base_h := 190 + 24 + 6 * 2 + 22 + 30
	b.custom_minimum_size.y = base_h
	v.minimum_size_changed.connect(func():
		b.custom_minimum_size.y = maxf(base_h, v.get_combined_minimum_size().y + 30))
	b.pressed.connect(func():
		selected = i
		_update_selection())
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT:
			selected = i
			_play())
	return b


func _update_selection() -> void:
	for i in cards.size():
		cards[i].set_pressed_no_signal(i == selected)
		cards[i].queue_redraw()
	var needs_map := _needs_map()
	map_scroll.visible = needs_map
	no_map_hint.visible = not needs_map
	var ok := (not needs_map or not shown_maps.is_empty()) and Database.mode_allows(Session.game_kind, 1)
	play_button.disabled = not ok
	play_button.queue_redraw()
	var mode_name := str(Database.mode(Session.game_kind).get("name", Session.game_kind))
	if not ok:
		map_title.text = ""
		map_info.text = ""
	elif needs_map:
		map_title.text = "%s\n%s" % [mode_name, tr(shown_maps[selected].name)]
		map_info.text = cards[selected].get_meta("info", "")
	else:
		map_title.text = mode_name
		map_info.text = ""


## Wählt der Modus eine Map aus data/maps (needs_map in data/modes.json)?
func _needs_map() -> bool:
	return bool(Database.mode(Session.game_kind).get("needs_map", true))


func _play() -> void:
	if not Database.mode_allows(Session.game_kind, 1) or (_needs_map() and shown_maps.is_empty()):
		return
	if _needs_map():
		Session.map_path = shown_maps[selected].path
	Session.map_override = null
	Session.load_state = {}
	Session.save_id = ""
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.game_scene())


func _update_net_tile() -> void:
	net_tile_text.text = ("◆ " + tr("%d verbunden") % (Net.players.size() + 1)) if Net.is_active() else ""
	net_tile_text.visible = Net.is_active()


## Host: Sitzung starten, eine neue auf der in der Lobby gewählten Map.
func _start_session() -> void:
	var path := lobby.map_path()
	var m := MapData.load_file(path) if path != "" else null
	if Net.session.has("coop"):
		Net.start_coop({})
	elif lobby.no_map_mode() and not Net.session.get("loaded", false):
		# Modus mit eigener Karte (Shopping Maul): alle zusammen in einer Partie
		Net.session.mode = Net.vote_winner(false)
		Net.start_coop({"name": str(Database.mode(Net.session.mode).get("name", ""))})
	elif lobby.coop_selected() and m != null and not Net.session.get("loaded", false):
		Net.start_coop(m.to_dict())
	elif m != null or not Net.session.get("map", {}).is_empty():
		# Eigene Felder, gemischt mit Koop-Gruppen (gleiche Feldnummer in der Lobby)
		Net.start_session(m.to_dict() if m != null else {}, lobby.field_groups())


## Jüngster Einzelspiel-Spielstand (ganze Daten) oder {}.
static func continue_save() -> Dictionary:
	for e in SaveGame.list():
		if str(e.kind) == "single":
			return SaveGame.read(SaveGame.path_for(str(e.id)))
	return {}


## Spielstand laden: Einzelspiel geht direkt weiter, eine Mehrspieler-Sitzung wird gehostet.
func _load_save(data: Dictionary) -> void:
	if data.get("kind", "") in ["multi", "coop"]:
		if Net.host_default() == OK:
			Net.load_session(data)
		show_page("lobby")
		return
	var st: Dictionary = data.get("state", {})
	Session.game_kind = str(data.get("mode", "gemtd"))
	Session.load_state = st
	Session.save_id = str(data.get("id", ""))
	Session.map_override = MapData.from_dict(st.map) if st.has("map") else null
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.game_scene())


func _open_map_editor() -> void:
	Session.editor_map = null
	if not shown_maps.is_empty():
		Session.editor_map = MapData.load_file(shown_maps[selected].path)
	Session.goto(Session.MAP_EDITOR)


func _open_tower_editor() -> void:
	Session.goto(Session.TOWER_EDITOR)
