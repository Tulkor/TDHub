class_name LobbyPanel
extends Control
## Mehrspieler-Lobby (Seite des Hauptmenüs). Links: Name, hosten oder per IP beitreten; verbunden die Spieler
## mit ihrer Stimme und (Host) Map und Spielart. Rechts: Abstimmung über den TD-Modus, jeder klickt einen an.
## Wählbar sind nur Modi, die spielbar und für die Spielerzahl erlaubt sind (data/modes.json).
## Gleichstand: die Stimme des Hosts zählt, sonst das Los (Net.vote_winner).
## Als Host: „Starten“; als Mitspieler: Stand der Sitzung und „Mitspielen“, auch später noch zum Wiedereinsteigen.
## Gespeicherte Sitzungen lädt der Host über „Spiel laden“ (load_panel.gd), sie bringen ihren Modus mit.

signal start_requested

## Alle Maps (Database.list_maps()), setzt das Hauptmenü.
var maps: Array = []
## Koop gewählt: alle spielen zusammen auf einem Feld (der Host rechnet, siehe coop_sync.gd).
var coop_mode := false
## Feldwahl des Hosts: uid -> Feldnummer (ab 0). Gleiche Nummer = zusammen auf einem Feld (Koop-Gruppe),
## so geht auch gemischt, z. B. zwei allein und zwei zusammen. Neue Spieler bekommen die Vorgabe von coop_mode.
var fields: Dictionary = {}

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _server_edit: LineEdit
var _port_hint: Label
var _status: Label
var _offline: VBoxContainer
var _online: VBoxContainer
var _addresses: Label
var _internet: Label
var _copy_button: Wc3Button
var _session_text: Label
var _players_caption: Label
var _list: VBoxContainer
var _start_button: Wc3Button
var _host_box: VBoxContainer
var _map_paths: Array = []
var _map_names: Array = []
var _map_path := ""
var _mode_buttons: Array[Wc3Button] = []
var _vote_cards: Array[Wc3Button] = []
var _summary: Label
var _play_button: Wc3Button
var _leave_button: Wc3Button
## Mitte: große Vorschau der Map, darunter Angaben und (Host) Pfeile zum Blättern.
var _map_caption: Label
var _map_frame: Wc3Card
var _preview: MapPreview
var _map_info: Label
var _no_map_hint: Label
var _map_row: HBoxContainer
var _map_prev: Wc3Button
var _map_next: Wc3Button
var _map_count: Label


## Lobby im Warcraft-III-Stil (Entwurf 8, Lukas 2026-11-01): Nachtszene des Hubs dahinter, drei Steintafeln:
## links Spieler und Verbindung, in der Mitte die Map groß, rechts Modus-Abstimmung und Start.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0, 0, 0, 0.45)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	page.add_child(head)
	head.add_child(_rule())
	Wc3Theme.label("◆", head, 16, Wc3Theme.GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Wc3Theme.label(tr("Lobby").to_upper(), head, 40, Wc3Theme.GOLD_HI, 6)
	Wc3Theme.label("◆", head, 16, Wc3Theme.GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_rule())
	_status = _text("", page, 16, Wc3Theme.CREAM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	page.add_child(body)

	# Links: Name, Verbindung, Spieler, Feldwahl des Hosts
	var left := Wc3Pillar.new(false, 440)
	body.add_child(left)
	_players_caption = _caption("Spieler", left.box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.box.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	v.add_child(name_row)
	_text("Name", name_row, 16, Wc3Theme.MUTED).custom_minimum_size.x = 70
	_name_edit = _edit(name_row)
	_name_edit.text = Net.my_name
	_name_edit.max_length = 24
	_name_edit.text_changed.connect(func(t): Net.set_my_name(t))

	# Ohne Verbindung: hosten oder beitreten
	_offline = VBoxContainer.new()
	_offline.add_theme_constant_override("separation", 10)
	v.add_child(_offline)
	var server_row := HBoxContainer.new()
	server_row.add_theme_constant_override("separation", 10)
	_offline.add_child(server_row)
	_text("Server", server_row, 16, Wc3Theme.MUTED).custom_minimum_size.x = 70
	_server_edit = _edit(server_row)
	_server_edit.text = Net.relay_server
	_server_edit.placeholder_text = tr("leer = direkt per IP")
	_server_edit.tooltip_text = "Relay-Server: Host und Mitspieler verbinden sich nur mit ihm, niemand muss einen Port freigeben"
	_server_edit.text_changed.connect(func(_t): _update_join_hint())
	_server_edit.text_submitted.connect(func(_t): _save_server())
	_server_edit.focus_exited.connect(_save_server)
	_button("Neue Sitzung hosten", true, _offline, func(): _save_server(); Net.host_default())
	_text("Eine gespeicherte Sitzung setzt du über „Spiel laden“ im Hauptmenü fort.", _offline, 15, Wc3Theme.MUTED)
	_offline.add_child(Wc3Theme.Divider.new())
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	_offline.add_child(join_row)
	_ip_edit = _edit(join_row)
	_ip_edit.text = Net.last_ip
	_ip_edit.placeholder_text = tr("Code oder IP-Adresse des Hosts")
	_ip_edit.text_submitted.connect(func(_t): _join())
	var jb := _button("Beitreten", false, join_row, _join)
	jb.custom_minimum_size.x = 150
	jb.size_flags_horizontal = Control.SIZE_SHRINK_END
	_port_hint = _text("", _offline, 15, Wc3Theme.MUTED)
	_update_join_hint()

	# Verbunden: Adresse, Spieler, Feldwahl
	_online = VBoxContainer.new()
	_online.add_theme_constant_override("separation", 10)
	v.add_child(_online)
	var net_row := HBoxContainer.new()
	net_row.add_theme_constant_override("separation", 10)
	_online.add_child(net_row)
	_internet = _text("", net_row, 16, Wc3Theme.CREAM)
	_internet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy_button = _button("Kopieren", false, net_row, func(): DisplayServer.clipboard_set(Net.room_code() if Net.room_code() != "" else Net.public_ip))
	_copy_button.custom_minimum_size = Vector2(140, 40)
	_copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_copy_button.tooltip_text = "Adresse in die Zwischenablage kopieren, um sie den Mitspielern zu schicken"
	_addresses = _text("", _online, 15, Wc3Theme.MUTED)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_online.add_child(_list)

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 8)
	_online.add_child(_host_box)
	_host_box.add_child(Wc3Theme.Divider.new())
	_text("Spielfeld", _host_box, 16, Wc3Theme.MUTED)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	_host_box.add_child(modes)
	for coop in [false, true]:
		var on: bool = coop
		var b := _button("Koop" if coop else "Eigene Felder", false, modes, func():
			coop_mode = on
			fields = {}
			_refresh())
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = tr("Alle bauen zusammen ein Labyrinth: jeder setzt und wählt seine eigenen Gems, hat eigenes Gold und kombiniert nur eigene Tower. Die Leben sind gemeinsam.") if coop \
			else tr("Jeder spielt sein eigenes Feld, über „Zuschauen“ sieht man die anderen.")
		b.set_pressed_no_signal(coop == coop_mode)
		_mode_buttons.append(b)

	# Mitte: die Map groß, darunter Angaben und Blättern (nur der Host wählt)
	var mid := Wc3Pillar.new(false, 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid)
	_map_caption = _caption("Map", mid.box)
	_map_frame = Wc3Card.new()
	_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_frame.set_pressed_no_signal(true)
	_map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.box.add_child(_map_frame)
	_preview = MapPreview.new()
	_preview.bg = Wc3Theme.PREVIEW_BG
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 18
	_preview.offset_top = 18
	_preview.offset_right = -18
	_preview.offset_bottom = -18
	_map_frame.add_child(_preview)
	_no_map_hint = _text("", mid.box, 18, Wc3Theme.MUTED)
	_no_map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_map_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_no_map_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_map_info = _text("", mid.box, 16, Wc3Theme.CREAM)
	_map_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_row = HBoxContainer.new()
	_map_row.add_theme_constant_override("separation", 14)
	mid.box.add_child(_map_row)
	_map_prev = _button("«", false, _map_row, func(): _step_map(-1))
	_map_prev.custom_minimum_size.x = 100
	_map_count = Wc3Theme.label("", _map_row, 17, Wc3Theme.CREAM, 2)
	_map_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_map_next = _button("»", false, _map_row, func(): _step_map(1))
	_map_next.custom_minimum_size.x = 100

	# Rechts: Abstimmung über den Modus und Start
	var right := Wc3Pillar.new(false, 440)
	body.add_child(right)
	_caption("Modus · deine Stimme", right.box)
	for m in Database.modes:
		var id := str(m.id)
		var card := _button(str(m.get("name", id)), false, right.box, func(): Net.vote("" if Net.my_vote() == id else id))
		card.toggle_mode = true
		card.custom_minimum_size.y = 50
		card.set_meta("mode_id", id)
		_vote_cards.append(card)
	right.separator()
	_summary = _text("", right.box, 16, Wc3Theme.CREAM)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_session_text = _text("", right.box, 15, Wc3Theme.MUTED)
	_session_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.box.add_child(fill)
	_start_button = _button("Starten", true, right.box, func(): start_requested.emit())
	_start_button.custom_minimum_size.y = 62
	_play_button = _button("Mitspielen", true, right.box, func(): Net.join_session())
	_play_button.custom_minimum_size.y = 62
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	right.box.add_child(row)
	_leave_button = _button("Trennen", false, row, func(): Net.leave())
	_leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := _button("Zurück", false, row, hide)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.tooltip_text = "Zurück zum Hauptmenü, die Verbindung bleibt bestehen"

	Net.players_changed.connect(_refresh)
	Net.connection_changed.connect(_refresh)
	Net.session_changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _rule() -> Control:
	return Wc3Theme.Rule.new(150, 6.0, false)


## Überschrift einer Steintafel: Cinzel zwischen Linien.
func _caption(text_de: String, parent: Node) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	row.add_child(Wc3Theme.Rule.new())
	var l := Wc3Theme.label(tr(text_de).to_upper(), row, 18, Wc3Theme.CREAM, 4)
	row.add_child(Wc3Theme.Rule.new())
	return l


## Fließtext auf den Tafeln (Alegreya, dunkler Schatten), bricht um.
func _text(text: String, parent: Node, size: int, color: Color) -> Label:
	var l := UiUtil.label(text, parent, size)
	l.add_theme_font_override("font", DruidTheme.font(false))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 60
	return l


func _button(text_de: String, main: bool, parent: Node, on_pressed: Callable) -> Wc3Button:
	var b := Wc3Button.new(text_de, main)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


## Eingabefeld: dunkler Grund, Messingrand, Alegreya.
func _edit(parent: Node) -> LineEdit:
	var e := LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size.y = 38
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.025, 0.02, 0.75)
	box.border_color = Wc3Theme.GOLD_LO
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	var focus := box.duplicate()
	focus.border_color = Wc3Theme.GOLD_HI
	e.add_theme_stylebox_override("normal", box)
	e.add_theme_stylebox_override("focus", focus)
	e.add_theme_stylebox_override("read_only", box)
	e.add_theme_font_override("font", DruidTheme.font(false))
	e.add_theme_font_size_override("font_size", 17)
	e.add_theme_color_override("font_color", Wc3Theme.HOT)
	e.add_theme_color_override("font_placeholder_color", Wc3Theme.DISABLED_TEXT)
	e.add_theme_color_override("caret_color", Wc3Theme.GOLD_HI)
	parent.add_child(e)
	return e


## Host: Map weiterblättern.
func _step_map(d: int) -> void:
	if _map_paths.is_empty():
		return
	var i := (_map_paths.find(_map_path) + d + _map_paths.size()) % _map_paths.size()
	_map_path = str(_map_paths[i])
	_refresh()


## Wählt der Modus, der gerade vorne liegt, seine Karte selbst (needs_map false, z. B. Shopping Maul)?
## Dann spielen alle zusammen in einer Partie (Koop), Map und Spielfeld-Wahl entfallen.
func no_map_mode() -> bool:
	return not bool(Database.mode(Net.vote_winner(false)).get("needs_map", true))


## Startet die Sitzung als reiner Koop (alle auf einem Feld)? Modi mit coop_only (YouTD) immer.
func coop_selected() -> bool:
	if bool(Database.mode(Net.vote_winner(false)).get("coop_only", false)):
		return true
	var g := field_groups()
	return g.size() == 1 and (g[0].size() > 1 or coop_mode)


## Verbundene Spieler (uids) in der Reihenfolge der Spielerliste.
func _online_uids() -> Array:
	return Net.session_slots().filter(func(sl): return sl.get("online", false)).map(func(sl): return str(sl.uid))


func field_of(u: String) -> int:
	if fields.has(u):
		return int(fields[u])
	return 0 if coop_mode else _online_uids().find(u)


## Spieler nach Feld: [[uid, ...], ...], ein Eintrag je belegtem Feld.
func field_groups() -> Array:
	var by := {}
	for u in _online_uids():
		var f := field_of(u)
		if not by.has(f):
			by[f] = []
		by[f].append(u)
	var keys := by.keys()
	keys.sort()
	return keys.map(func(k): return by[k])


## Feld eines Spielers weiterschalten (Host, Klick in der Spielerliste).
func _next_field(u: String) -> void:
	var n := maxi(_online_uids().size(), 1)
	for x in _online_uids():
		fields[x] = field_of(x)
	fields[u] = (field_of(u) + 1) % n
	_refresh()


## Pfad der gewählten Map für eine neue Sitzung ("" = keine).
func map_path() -> String:
	return _map_path


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _unhandled_input(event: InputEvent) -> void:
	if visible and is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()


func _join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip != "":
		_save_server()
		Net.join_any(ip)


func _save_server() -> void:
	if _server_edit != null and _server_edit.text.strip_edges() != Net.relay_server:
		Net.set_relay_server(_server_edit.text)
	_update_join_hint()


func _update_join_hint() -> void:
	if _port_hint == null:
		return
	var relay := _server_edit.text.strip_edges() != ""
	if relay:
		_port_hint.text = tr("Mit Server: Der Host bekommt einen Code, Mitspieler geben ihn oben ein. Niemand muss einen Port freigeben. Eine IP-Adresse statt Code verbindet weiter direkt.")
	else:
		_port_hint.text = tr("Im selben Netzwerk reicht die angezeigte Adresse. Übers Internet muss der Host UDP-Port %d am Router freigeben, oder ihr nutzt ein virtuelles LAN wie Tailscale oder ZeroTier.") % Net.DEFAULT_PORT




func _refresh() -> void:
	if _list == null or not visible:
		return
	var online := Net.is_active()
	var busy := online or Net.is_connecting()
	_offline.visible = not busy
	_online.visible = online
	_leave_button.visible = busy
	_status.text = Net.status_text
	_status.visible = Net.status_text != ""
	_start_button.visible = false
	_play_button.visible = false
	_host_box.visible = false
	if not online:
		_show_votes(false, false)
		_summary.text = tr("Erst eine Sitzung hosten oder beitreten, dann stimmt ihr hier gemeinsam über den Modus ab.")
		_session_text.text = ""
		_players_caption.text = tr("Spieler").to_upper()
		_show_map("", "", false)
		return

	var started := false
	var loaded := false
	var mode_name := _mode_name(Net.vote_winner(false))
	if Net.is_host():
		_show_addresses()
		var s := Net.session
		started = bool(s.get("started", false))
		loaded = bool(s.get("loaded", false))
		var voting := not started and not loaded
		var no_map := no_map_mode()
		_host_box.visible = voting and not no_map
		# Feldwahl: Koop = alle auf Feld 1, Eigene Felder = jeder seins, sonst gemischt (keiner gedrückt)
		var groups := field_groups()
		var plan := {}
		for g in groups:
			for u in g:
				plan[u] = field_of(u)
		Net.set_fields(plan if voting and not no_map else {})
		var all_own := groups.all(func(g): return g.size() == 1) and not coop_selected()
		_mode_buttons[0].set_pressed_no_signal(all_own)
		_mode_buttons[1].set_pressed_no_signal(coop_selected())
		if voting:
			_fill_maps(Net.vote_winner(false))
		var map_name := tr(str(s.get("map_name", ""))) if str(s.get("map_name", "")) != "" else tr(_map_name())
		if no_map and str(s.get("map_name", "")) == "":
			map_name = mode_name
		if not started and s.has("coop"):
			_session_text.text = tr("Gespeicherter Koop auf %s. „Starten“ setzt das gemeinsame Feld fort, wer fehlt, kann später einsteigen.") % map_name
		elif started and s.has("coop"):
			_session_text.text = tr("Koop auf %s läuft. Mitspieler, die das Spiel verlassen haben, steigen über „Mitspielen“ wieder ein.") % map_name
		elif voting and no_map:
			_session_text.text = tr("%s: „Starten“ startet alle Verbundenen zusammen, jeder mit eigenem Gebiet und eigenem Gold, die Leben sind gemeinsam. Schwierigkeit und Modus wählt der Host.") % mode_name
		elif not started and coop_selected() and not loaded:
			_session_text.text = tr("Koop auf %s: „Starten“ startet alle Verbundenen auf einem gemeinsamen Feld, Schwierigkeit und Wertung vom Host.") % map_name
		elif voting and not coop_selected() and groups.any(func(g): return g.size() > 1):
			_session_text.text = tr("Gemischt auf %s: wer dieselbe Feldnummer hat, spielt zusammen auf einem Feld, die anderen allein. Klick auf „Feld“ in der Spielerliste ändert die Zuordnung.") % map_name
		elif started:
			_session_text.text = tr("Die Sitzung läuft auf %s. Wer dazukommt, steigt über „Mitspielen“ ein, mit seinem gespeicherten Stand, falls es einen gibt.") % map_name
		elif loaded:
			_session_text.text = tr("Gespeicherte Sitzung auf %s. „Starten“ setzt für jeden Verbundenen seinen Stand fort, wer fehlt, kann später einsteigen.") % map_name
		else:
			_session_text.text = tr("Neue Sitzung auf %s: „Starten“ startet alle Verbundenen gleichzeitig.") % map_name
		_start_button.visible = not started
		_start_button.label_text = tr("Starten: %s") % mode_name if voting else tr("Starten")
		_start_button.queue_redraw()
		_start_button.disabled = voting and ((_map_path == "" and not no_map) or Net.vote_tally().is_empty())
		_play_button.visible = started
	else:
		_addresses.visible = false
		_internet.get_parent().visible = false
		var info := Net.session_info
		started = bool(info.get("started", false))
		loaded = bool(info.get("loaded", false))
		var own := tr("Dein gespeicherter Stand: Welle %d.") % int(info.get("wave", 0)) if info.get("has_state", false) else tr("Du startest neu.")
		if info.get("coop", false):
			own = tr("Koop: ihr spielt zusammen auf einem Feld.")
		if info.is_empty():
			_session_text.text = tr("Warte auf den Host …")
		elif started:
			_session_text.text = tr("Die Sitzung läuft auf %s.") % tr(str(info.get("map", ""))) + " " + own
		else:
			_session_text.text = tr("Warte, bis der Host die Sitzung startet.") + " " + own
		_play_button.visible = true
		_play_button.disabled = not started

	if started or loaded:
		_show_votes(false, true)
		var fixed := str(Net.session.get("mode", "") if Net.is_host() else Net.session_info.get("mode", ""))
		_summary.text = tr("Modus dieser Sitzung: %s") % _mode_name(fixed if fixed != "" else Session.game_kind)
	else:
		_show_votes(true, true)
		_summary.text = _vote_text()

	var n := Net.player_count()
	_players_caption.text = (tr("Spieler · %d") % n).to_upper()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var v := Net.votes()
	for slot in Net.session_slots():
		_slot_row(slot, str(v.get(str(slot.get("uid", "")), "")) if not (started or loaded) else "")
	# Mitte: Host zeigt seine Wahl (blättern nur vor dem Start), Mitspieler die Map der Sitzung
	if Net.is_host():
		var s := Net.session
		var voting := not bool(s.get("started", false)) and not bool(s.get("loaded", false))
		var path := _map_path if voting else ""
		var shown := str(s.get("map_name", "")) if not voting else _map_name()
		_show_map(path if path != "" else _path_of(shown), shown, voting and not no_map_mode(), no_map_mode() and voting)
	else:
		var shown := str(Net.session_info.get("map", ""))
		_show_map(_path_of(shown), shown, false)


## Pfad einer Map über ihren Namen ("" = unbekannt, z. B. Mitspieler mit anderer Map-Liste).
func _path_of(map_name: String) -> String:
	for m in maps:
		if str(m.name) == map_name or tr(str(m.name)) == map_name:
			return str(m.path)
	return ""


## Mitte füllen: Vorschau, Name, Angaben; browse = Pfeile für den Host; own_map = Modus wählt seine Karte selbst.
func _show_map(path: String, map_name: String, browse: bool, own_map := false) -> void:
	var md: MapData = MapData.load_file(path) if path != "" else null
	_map_frame.visible = md != null and not own_map
	_no_map_hint.visible = not _map_frame.visible
	_map_row.visible = browse and _map_paths.size() > 1
	_map_count.text = tr("Map %d von %d") % [_map_paths.find(_map_path) + 1, _map_paths.size()]
	if own_map:
		_no_map_hint.text = tr("Dieser Modus wählt seine Karte selbst vor dem Start.")
	elif not Net.is_active():
		_no_map_hint.text = tr("Noch keine Sitzung.")
	else:
		_no_map_hint.text = tr(map_name) if map_name != "" else tr("Warte auf den Host …")
	if md == null or own_map:
		_map_caption.text = tr("Map").to_upper()
		_map_info.text = ""
		return
	_preview.map = md
	_preview.queue_redraw()
	_map_caption.text = ("%s · %d×%d" % [tr(map_name), md.width, md.height]).to_upper()
	var waves: int = (Database.wave_sets.get(md.wave_set, {}).get("waves", []) as Array).size()
	_map_info.text = tr("%d Wellen · %d Leben · %d Checkpoints") % [waves, md.lives, md.checkpoints.size()] \
		+ "\n" + tr("Weg ohne Labyrinth: %d Felder") % _preview.path_length()


## Abstimmungsknöpfe: Stimmen als Rubine; active false = grau (nicht verbunden). Nach dem Start bleibt
## der Modus der Sitzung rot, die übrigen grau.
func _show_votes(voting: bool, active: bool) -> void:
	var n := Net.player_count()
	var mine := Net.my_vote()
	var counts := {}
	for e in Net.vote_tally():
		counts[e.id] = e
	var fixed := str(Net.session.get("mode", "") if Net.is_host() else Net.session_info.get("mode", ""))
	for card in _vote_cards:
		var id: String = card.get_meta("mode_id")
		var m := Database.mode(id)
		var ok := active and voting and Database.mode_allows(id, n)
		card.disabled = not ok
		card.set_pressed_no_signal(mine == id if voting else id == fixed)
		if not bool(m.get("ready", false)):
			card.side_text = tr("Kommt noch")
		elif active and voting and not Database.mode_allows(id, n):
			card.side_text = tr("nicht für %d Spieler") % n
		elif ok:
			# Stimmen als Rubine rechts; die erlaubte Spielerzahl steht im Tooltip
			card.side_text = ""
		else:
			card.side_text = Database.mode_players_text(id)
		card.tooltip_text = Database.mode_players_text(id) + "\n" + tr(str(m.get("hint", "")))
		card.pip_max = n if ok else 0
		card.pips = int(counts[id].count) if ok and counts.has(id) else 0
		card.queue_redraw()


func _vote_text() -> String:
	var tally := Net.vote_tally()
	if tally.is_empty():
		return tr("Kein Modus ist für %d Spieler erlaubt.") % Net.player_count()
	var leaders := Net.vote_leaders()
	var n := Net.player_count()
	if int(tally[0].count) == 0:
		return tr("Noch keine Stimmen. Ohne Stimmen gilt %s.") % _mode_name(Net.vote_winner(false))
	if leaders.size() == 1:
		return tr("Vorne: %s mit %d von %d Stimmen.") % [_mode_name(leaders[0]), int(tally[0].count), n]
	var names := " / ".join(leaders.map(func(id): return _mode_name(id)))
	var winner := Net.vote_winner(false)
	var host_vote := ""
	for slot in Net.session_slots():
		if int(slot.get("peer", -1)) == 1:
			host_vote = str(Net.votes().get(str(slot.get("uid", "")), ""))
	if leaders.has(host_vote):
		return tr("Gleichstand: %s. Die Stimme des Hosts entscheidet: %s.") % [names, _mode_name(winner)]
	return tr("Gleichstand: %s. Der Host hat keinen davon gewählt, beim Start entscheidet das Los.") % names


func _mode_name(id: String) -> String:
	return str(Database.mode(id).get("name", id))


## Map-Auswahl des Hosts für den Modus, der gerade vorne liegt (Auswahl bleibt, solange die Map passt).
func _fill_maps(mode_id: String) -> void:
	var list := Database.maps_for_mode(mode_id, maps)
	var paths := list.map(func(m): return str(m.path))
	if paths == _map_paths:
		return
	_map_paths = paths
	_map_names = list.map(func(m): return str(m.name))
	if not paths.has(_map_path):
		_map_path = Session.map_path if paths.has(Session.map_path) else (str(paths[0]) if not paths.is_empty() else "")


func _map_name() -> String:
	var i := _map_paths.find(_map_path)
	return tr(_map_names[i]) if i >= 0 else ""


## Host: Adresse fürs Internet (öffentliche IP, Portfreigabe per UPnP) und fürs eigene Netzwerk.
func _show_addresses() -> void:
	_internet.get_parent().visible = true
	if Net.via_relay():
		_internet.text = tr("Code: %s") % Net.room_code()
		_internet.add_theme_color_override("font_color", Wc3Theme.GOLD_HI)
		_internet.add_theme_font_size_override("font_size", 20)
		_copy_button.visible = true
		_copy_button.tooltip_text = tr("Code in die Zwischenablage kopieren, um ihn den Mitspielern zu schicken")
		_addresses.text = tr("Über den Server %s. Mitspieler geben den Code ein, niemand muss einen Port freigeben.") % Net.relay_connection()
		_addresses.visible = true
		return
	_copy_button.tooltip_text = tr("Adresse in die Zwischenablage kopieren, um sie den Mitspielern zu schicken")
	_internet.add_theme_font_size_override("font_size", 14)
	if Net.public_ip != "":
		_internet.text = tr("Internet: %s") % Net.public_ip
	else:
		_internet.text = tr("Internet: Adresse nicht ermittelbar") if Net.public_ip_failed else tr("Internet: Adresse wird ermittelt …")
	_internet.add_theme_color_override("font_color", Wc3Theme.CREAM)
	_copy_button.visible = Net.public_ip != ""
	var port := Net.host_port
	var lines := []
	match Net.upnp_state:
		"busy":
			lines.append(tr("Router wird gefragt, ob er UDP-Port %d freigibt …") % port)
		"open":
			if Net.behind_cgnat():
				lines.append(tr("Dein Anschluss hat keine eigene öffentliche Adresse (CGNAT), Mitspieler aus dem Internet erreichen dich so nicht. Nutzt ein virtuelles LAN wie Tailscale oder ZeroTier."))
			else:
				lines.append(tr("UDP-Port %d ist im Router freigegeben, Mitspieler aus dem Internet können beitreten.") % port)
		"failed":
			lines.append(tr("Der Router hat UDP-Port %d nicht automatisch freigegeben (UPnP aus?). Gib ihn im Router von Hand für diesen PC frei, oder nutzt Tailscale oder ZeroTier.") % port)
	var addrs := Net.local_addresses()
	if not addrs.is_empty():
		lines.append(tr("Im selben Netzwerk: %s") % ", ".join(addrs))
	_addresses.text = "\n".join(lines)
	_addresses.visible = not lines.is_empty()


## Zeile in der Spielerliste; vote: Modus, für den der Spieler gestimmt hat ("" = keine Stimme).
## Name in Cinzel, Raute in der Farbe seines Feldes; offline grau.
func _slot_row(slot: Dictionary, vote: String) -> void:
	var online: bool = slot.get("online", false)
	var row := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.3)
	bg.border_color = Color(Wc3Theme.GOLD_LO, 0.5)
	bg.border_width_bottom = 1
	bg.content_margin_left = 10
	bg.content_margin_right = 6
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", bg)
	_list.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var field := int(slot.get("field", -1))
	var col: Color = Board3D.PLAYER_COLORS[maxi(field, 0) % Board3D.PLAYER_COLORS.size()] if online else Wc3Theme.DISABLED_TEXT
	Wc3Theme.label("◆", h, 18, col).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var peer := int(slot.get("peer", -1))
	var me := peer == Net.my_id()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	var n := Wc3Theme.label(str(slot.get("name", "?")) + ("  " + tr("(du)") if me else ""), info, 17, Wc3Theme.GOLD_HI if online else Wc3Theme.DISABLED_TEXT, 1)
	n.clip_text = true
	var parts := []
	if not online:
		parts.append(tr("nicht verbunden"))
	elif Net.players.has(peer):
		parts.append(NetPanel.status_text(Net.player_status(peer)))
	if slot.get("has_state", false):
		parts.append(tr("gespeichert: Welle %d") % int(slot.get("wave", 0)))
	if vote != "":
		parts.append("▸ " + _mode_name(vote))
	_text(" · ".join(parts), info, 14, Wc3Theme.MUTED)
	if field >= 0 and online:
		var u := str(slot.get("uid", ""))
		var fb := Wc3Button.new(tr("Feld %d") % (field + 1), false)
		fb.pressed.connect(func(): _next_field(u))
		fb.custom_minimum_size = Vector2(110, 40)
		fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fb.disabled = not Net.is_host()
		fb.tooltip_text = tr("Gleiche Feldnummer = zusammen auf einem Feld (Koop). Klick = nächstes Feld.") if Net.is_host() \
			else tr("Der Host teilt die Felder ein.")
		# Mehrere auf demselben Feld (Koop-Gruppe): rot wie ein gewählter Knopf
		var same: int = Net.session_slots().filter(func(sl): return int(sl.get("field", -1)) == field and sl.get("online", false)).size()
		fb.toggle_mode = true
		fb.set_pressed_no_signal(same > 1)
		h.add_child(fb)
