extends Node
## Mehrspieler Modus 1: jeder spielt sein eigenes Feld, alle sind über ENet verbunden.
## Übers Netz gehen nur der Stand jedes Spielers (für die Liste) und, solange jemand zuschaut,
## der Abzug seines Felds (net_sync.gd sendet, remote_field.gd zeigt an).
## Die Verbindung bleibt über Szenenwechsel bestehen; jeder kann unabhängig starten und neu starten.
##
## Modus 2 (Koop): alle spielen auf einem gemeinsamen Feld, der Host rechnet (start_coop, coop_sync.gd).
##
## Sitzung (Lobby): Der Host führt eine Sitzung mit dem Stand jedes Mitspielers, erkannt an einer
## festen Spieler-ID (uid). Nur der Host speichert, dabei holt er die Felder aller Mitspieler ein
## (save_session). Mitspieler melden ihren Stand außerdem zu Beginn jeder Bauphase und beim Verlassen,
## so kann jeder später wieder einsteigen (_join_game) und spielt genau dort weiter.

signal players_changed
signal connection_changed
signal field_received(peer: int, data: Dictionary)
signal map_received(peer: int, data: Dictionary)
signal enemies_received(peer: int, data: Dictionary)
signal watchers_changed
signal session_changed
signal coop_command(peer: int, cmd: Dictionary)
signal coop_ready(peer: int)
signal coop_state(data: Dictionary)
signal coop_enemies(data: Dictionary)
signal hero_input(peer: int, frame: Dictionary)

const DEFAULT_PORT := 24565
## Relay-Server, der im Feld „Server“ der Lobby steht, solange der Spieler nichts anderes einträgt
## (Feld leeren = direkt per IP). Format "host" oder "host:port" (TCP, Standard 24565), Server: tools/relay/.
const DEFAULT_RELAY := "schulak.synology.me:24565"
const MAX_PLAYERS := 8
const SETTINGS := "user://settings.cfg"
const SAVE_TIMEOUT := 2.5   ## Sekunden, die der Host beim Speichern auf die Felder der Mitspieler wartet

## peer_id -> {"name": String, "status": Dictionary, "uid": String}
var players: Dictionary = {}
var my_name := ""
## Feste Spieler-ID dieses Rechners, damit der Host einen Mitspieler beim Wiederkommen erkennt.
var uid := ""
## Laufendes Spiel (game.gd) oder null.
var game = null
## Nur beim Host: {id, map, map_name, started, loaded, players {uid: {name, state}}},
## im Koop dazu coop: [uid, ...] (Index = Spielernummer, der Host ist 0) und settings.
## Gemischt (eigene Felder und Koop-Gruppen, start_session mit groups): groups [[uid, ...], ...] nur für
## Gruppen ab 2 Spielern; der Erste einer Gruppe rechnet ihr gemeinsames Feld wie der Host im Koop.
## fields: Feldwahl der Lobby {uid: Feldnummer}, damit alle sie sehen.
var session: Dictionary = {}
## Nur beim Mitspieler: was der Host über die Sitzung meldet (siehe _info_for).
var session_info: Dictionary = {}
var _reports: Dictionary = {}   ## Host beim Speichern: peer -> true, sobald der Stand da ist

## Host: Adresse fürs Internet. public_ip kommt von api.ipify.org, upnp_state sagt, ob der Router
## den Port per UPnP freigegeben hat: "" (noch nicht), "busy", "open", "failed".
var public_ip := ""
var public_ip_failed := false
var upnp_ip := ""      ## Adresse, die der Router per UPnP meldet (weicht bei CGNAT von public_ip ab)
var upnp_state := ""
var host_port := DEFAULT_PORT
var _upnp: UPNP
var _upnp_port := 0
var _upnp_thread: Thread
var _ip_request: HTTPRequest
var last_ip := ""
## Relay-Server aus den Einstellungen (nie gesetzt = DEFAULT_RELAY, leer = direkt; eigener Schlüssel
## relay_server, weil V0_67 unter "relay" schon leere Werte gespeichert hat); läuft die Verbindung darüber, ist room_code()
## der Code, mit dem Mitspieler beitreten.
var relay_server := ""
var _relay_error := ""
## Stand des eigenen Spiels: in_game, wave, waves, lives, phase, difficulty
var my_status: Dictionary = {}
## Wer gerade meinem Feld zuschaut (peer_ids).
var watchers: Dictionary = {}
var status_text := ""


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		my_name = str(cfg.get_value("net", "name", ""))
		last_ip = str(cfg.get_value("net", "ip", ""))
		uid = str(cfg.get_value("net", "uid", ""))
		relay_server = str(cfg.get_value("net", "relay_server", DEFAULT_RELAY))
	else:
		relay_server = DEFAULT_RELAY
	if my_name == "":
		my_name = tr("Spieler") + " %d" % (randi() % 900 + 100)
	if uid == "":
		uid = _random_uid()
		save_settings()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("net", "name", my_name)
	cfg.set_value("net", "ip", last_ip)
	cfg.set_value("net", "uid", uid)
	cfg.set_value("net", "relay_server", relay_server)
	cfg.save(SETTINGS)


func is_active() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not p is OfflineMultiplayerPeer \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_connecting() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not p is OfflineMultiplayerPeer \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING


func is_host() -> bool:
	return is_active() and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func host(port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		_set_status(tr("Hosten fehlgeschlagen (Port %d belegt?)") % port)
		return err
	multiplayer.multiplayer_peer = peer
	session = {"id": SaveGame.new_id(), "map": {}, "map_name": "", "started": false, "loaded": false, "players": {}}
	_set_status(tr("Hoste auf Port %d") % port)
	host_port = port
	_open_port(port)
	_fetch_public_ip()
	connection_changed.emit()
	return OK


func join(ip: String, port := DEFAULT_PORT) -> Error:
	leave()
	last_ip = ip
	save_settings()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		_set_status(tr("Verbinden fehlgeschlagen"))
		return err
	multiplayer.multiplayer_peer = peer
	_set_status(tr("Verbinde mit %s …") % ip)
	connection_changed.emit()
	return OK


# --- Über den Relay-Server (ohne Portfreigabe) --------------------------------------

## Relay-Server, über den gehostet und per Code beigetreten wird ("" = keiner eingestellt).
func relay_address() -> String:
	return relay_server.strip_edges()


func set_relay_server(address: String) -> void:
	relay_server = address.strip_edges()
	save_settings()


func via_relay() -> bool:
	return multiplayer.multiplayer_peer is RelayPeer


## Adresse des Relay-Servers der laufenden Verbindung ("" = direkt verbunden).
func relay_connection() -> String:
	var p := multiplayer.multiplayer_peer as RelayPeer
	return p.server_address if p != null else ""


## Code des Raums auf dem Relay-Server ("" = direkt verbunden oder noch nicht verbunden).
func room_code() -> String:
	var p := multiplayer.multiplayer_peer as RelayPeer
	return p.room_code if p != null else ""


## Ist der Text ein Raumcode (sonst eine IP-Adresse oder ein Rechnername)?
static func looks_like_code(t: String) -> bool:
	var s := t.strip_edges().to_upper()
	return not s.is_valid_int() and RegEx.create_from_string("^[A-Z0-9]{5}$").search(s) != null


## Hosten wie im Menü: über den Relay-Server, wenn einer eingestellt ist, sonst direkt.
func host_default() -> Error:
	return host_relay() if relay_address() != "" else host()


## Beitreten wie im Menü: ein Code geht über den Relay-Server, sonst ist der Text die Adresse des Hosts.
func join_any(text: String) -> Error:
	var t := text.strip_edges()
	if relay_address() != "" and looks_like_code(t):
		return join_relay(t)
	return join(t)


func host_relay(address := "") -> Error:
	leave()
	var peer := RelayPeer.new()
	var err := peer.host(address if address != "" else relay_address(), MAX_PLAYERS)
	if err != OK:
		_set_status(tr("Server-Adresse ungültig"))
		return err
	peer.relay_error.connect(_on_relay_error)
	peer.welcomed.connect(func(code): _set_status(tr("Raum %s auf dem Server offen") % code))
	_relay_error = ""
	multiplayer.multiplayer_peer = peer
	session = {"id": SaveGame.new_id(), "map": {}, "map_name": "", "started": false, "loaded": false, "players": {}}
	_set_status(tr("Verbinde mit dem Server %s …") % peer.server_address)
	connection_changed.emit()
	return OK


func join_relay(code: String, address := "") -> Error:
	leave()
	var peer := RelayPeer.new()
	var err := peer.join(address if address != "" else relay_address(), code)
	if err != OK:
		_set_status(tr("Server-Adresse ungültig"))
		return err
	peer.relay_error.connect(_on_relay_error)
	_relay_error = ""
	last_ip = code.strip_edges().to_upper()
	save_settings()
	multiplayer.multiplayer_peer = peer
	_set_status(tr("Trete Raum %s bei …") % last_ip)
	connection_changed.emit()
	return OK


func _on_relay_error(code: String) -> void:
	match code:
		"unknown_code": _relay_error = tr("Diesen Code gibt es nicht (oder der Host ist nicht mehr da).")
		"room_full": _relay_error = tr("Die Sitzung ist voll.")
		"full_server": _relay_error = tr("Der Server ist gerade voll, versuch es später noch einmal.")
		"version": _relay_error = tr("Der Server passt nicht zu dieser Spielversion.")
		"resolve": _relay_error = tr("Server-Adresse nicht gefunden.")
		"unreachable", "timeout": _relay_error = tr("Server nicht erreichbar.")
		_: _relay_error = tr("Der Server hat die Verbindung abgelehnt (%s).") % code


func leave() -> void:
	_close_port()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	watchers.clear()
	session = {}
	session_info = {}
	_reports.clear()
	_set_status("")
	session_changed.emit()
	players_changed.emit()
	watchers_changed.emit()
	connection_changed.emit()


# --- Erreichbarkeit übers Internet -------------------------------------------------

## Port im Router per UPnP freigeben (im Hintergrund, die Suche dauert bis zu zwei Sekunden).
func _open_port(port: int) -> void:
	# Tests laufen mit --headless: dort keinen Router fragen (der Thread lief sonst beim Beenden noch)
	if DisplayServer.get_name() == "headless" or _upnp_thread != null:
		return
	upnp_state = "busy"
	upnp_ip = ""
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> void:
	var u := UPNP.new()
	var ok := u.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() != null and u.get_gateway().is_valid_gateway()
	if ok:
		ok = u.add_port_mapping(port, port, "GemTD", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
	var ext := u.query_external_address() if ok else ""
	call_deferred("_upnp_done", u if ok else null, port, ext)


func _upnp_done(u: UPNP, port: int, ext: String) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if not is_host():
		# Inzwischen getrennt: Freigabe gleich wieder entfernen
		if u != null:
			u.delete_port_mapping(port, "UDP")
		upnp_state = ""
		return
	_upnp = u
	_upnp_port = port
	upnp_ip = ext
	upnp_state = "open" if u != null else "failed"
	connection_changed.emit()


func _close_port() -> void:
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null
	upnp_state = ""
	upnp_ip = ""


func _fetch_public_ip() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _ip_request == null:
		_ip_request = HTTPRequest.new()
		_ip_request.timeout = 6.0
		add_child(_ip_request)
		_ip_request.request_completed.connect(_on_public_ip)
	if public_ip == "":
		public_ip_failed = false
		_ip_request.cancel_request()
		_ip_request.request("https://api.ipify.org")


func _on_public_ip(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ip := body.get_string_from_utf8().strip_edges()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and ip.count(".") == 3:
		public_ip = ip
	else:
		public_ip_failed = true
	connection_changed.emit()


## Hat der Anschluss keine eigene öffentliche Adresse (Carrier-Grade-NAT, oft bei Mobilfunk und Glasfaser)?
## Dann hilft auch eine Portfreigabe nicht, nur ein virtuelles LAN.
func behind_cgnat() -> bool:
	if upnp_ip == "":
		return false
	return _is_private(upnp_ip) or (public_ip != "" and upnp_ip != public_ip)


static func _is_private(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return false
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or (a == 172 and b >= 16 and b < 32) or (a == 192 and b == 168) or (a == 100 and b >= 64 and b < 128)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:   # beim Beenden die Freigabe im Router wieder entfernen
		if _upnp_thread != null:   # laufende Suche abwarten, sonst stürzt Godot beim Beenden ab
			_upnp_thread.wait_to_finish()
			_upnp_thread = null
		_close_port()


## Eigene IPv4-Adressen im LAN, damit der Host sie weitergeben kann.
func local_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func player_name(peer: int) -> String:
	return str(players.get(peer, {}).get("name", "?"))


func player_status(peer: int) -> Dictionary:
	return players.get(peer, {}).get("status", {})


## Eigenen Stand an alle melden (nur wenn er sich geändert hat).
func set_status(s: Dictionary) -> void:
	if s == my_status:
		return
	my_status = s.duplicate()
	if is_active():
		_status.rpc(my_status)


func set_my_name(n: String) -> void:
	n = n.strip_edges()
	if n == "" or n == my_name:
		return
	my_name = n.left(24)
	save_settings()
	if is_active():
		_hello.rpc(my_name, my_status, uid)


# --- Zuschauen -----------------------------------------------------------------

## Dem Feld von peer zuschauen (true) oder aufhören (false).
func watch(peer: int, on: bool) -> void:
	if is_active() and players.has(peer):
		_watch.rpc_id(peer, on)


func send_map(peer: int, data: Dictionary) -> void:
	_map.rpc_id(peer, data)


func send_field(peer: int, data: Dictionary) -> void:
	_field.rpc_id(peer, data)


func send_enemies(peer: int, data: Dictionary) -> void:
	_enemies.rpc_id(peer, data)


# --- Sitzung -------------------------------------------------------------------

## Host: Sitzung aus einem Mehrspieler-Spielstand übernehmen (vorher host()).
func load_session(data: Dictionary) -> void:
	if not is_host() and not (via_relay() and multiplayer.is_server()):   # Relay: Raum wird noch eröffnet
		return
	if str(data.get("kind", "")) == "coop":
		_load_coop(data)
		return
	var ps: Dictionary = data.get("players", {}).duplicate(true)
	# Der eigene Stand liegt unter der uid, mit der gespeichert wurde.
	var old := str(data.get("host_uid", uid))
	if old != uid and ps.has(old):
		ps[uid] = ps[old]
		ps.erase(old)
	session = {
		"id": str(data.get("id", SaveGame.new_id())),
		"map": data.get("map", {}),
		"map_name": str(data.get("meta", {}).get("map", "")),
		"mode": str(data.get("mode", "")),
		"started": false,
		"loaded": true,
		"players": ps,
		"groups": (data.get("groups", []) as Array).map(func(g): return g.map(func(x): return uid if str(x) == old else str(x))),
	}
	for peer in players:
		players[peer].uid = _resolve_uid(peer, str(players[peer].get("asked_uid", "")))
	_push_info()


## Host: Sitzung starten. Jeder Verbundene, der gerade nicht spielt, steigt ein:
## mit seinem gespeicherten Stand, sonst neu auf der Map. map_data gilt nur für neue Sitzungen.
## groups: Koop-Gruppen [[uid, ...], ...] (wer in keiner steht, spielt allein); gilt nur für neue Sitzungen,
## gespeicherte bringen ihre Gruppen mit.
func start_session(map_data: Dictionary, groups := []) -> void:
	if not is_host():
		return
	if session.get("map", {}).is_empty():
		session.map = map_data
		session.map_name = str(map_data.get("name", ""))
	if not session.get("loaded", false):
		session.groups = []
		for g in groups:
			var list: Array = g.duplicate()
			# Der Host rechnet seine Gruppe selbst
			if list.has(uid):
				list.erase(uid)
				list.push_front(uid)
			if list.size() > 1:
				session.groups.append(list)
		session.settings = {"difficulty": Session.difficulty, "score_mode": Session.score_mode}
	session.started = true
	session.erase("coop")
	_fix_mode()
	_push_info()
	for peer in players:
		if not player_status(peer).get("in_game", false):
			_send_begin(peer)
	_send_begin(1)


## Host: einen Mitspieler (peer 1 = sich selbst) in die laufende Sitzung schicken: allein auf sein Feld oder
## in seine Koop-Gruppe; deren Erster bekommt den gespeicherten Stand der Gruppe und rechnet.
func _send_begin(peer: int) -> void:
	var u := uid if peer == 1 else str(players[peer].uid)
	var g := _group_of(u)
	if g.size() < 2:
		if peer == 1:
			_begin_local(session.map, _state_of(uid))
		else:
			_begin.rpc_id(peer, session.map, _state_of(u))
		return
	var i := g.find(u)
	var state := _state_of(u) if i == 0 else {}
	var names := g.map(func(x): return _name_of(str(x)))
	if peer == 1:
		_begin_coop_local(session.map, i, names, "host" if i == 0 else "client", state)
	else:
		_begin_coop.rpc_id(peer, session.map, i, names, session.get("settings", {}), state)


## Einer laufenden Sitzung (wieder) beitreten.
func join_session() -> void:
	if is_host():
		if session.get("started", false):
			_begin_local(session.map, _state_of(uid))
	elif is_active():
		_join_game.rpc_id(1)


## Eigenen Stand dem Host geben (beim Verlassen und zu Beginn jeder Bauphase). Leer = Partie vorbei.
func report_state(state: Dictionary) -> void:
	if is_host():
		_store_state(uid, my_name, state)
	elif is_active():
		_state_report.rpc_id(1, state, true)
		var p := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if p != null and p.host != null:
			p.host.flush()   # vor einem sofortigen Beenden noch rausschicken


## Host: Felder aller Mitspieler einholen und zusammen mit dem eigenen verschlüsselt speichern.
## Wer nicht rechtzeitig antwortet, behält seinen zuletzt gemeldeten Stand.
func save_session(g) -> bool:
	if not is_host():
		return false
	_reports.clear()
	var waiting := []
	for peer in players:
		if player_status(peer).get("in_game", false):
			waiting.append(peer)
			_request_state.rpc_id(peer)
	var deadline := Time.get_ticks_msec() + int(SAVE_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline \
			and waiting.any(func(p): return players.has(p) and not _reports.has(p)):
		await get_tree().create_timer(0.05, true, false, true).timeout
	if g != null:
		_store_state(uid, my_name, SaveGame.capture(g))
		if session.map.is_empty():
			session.map = g.map.to_dict()
			session.map_name = g.map.name
	var names := []
	for u in session.players:
		names.append(str(session.players[u].get("name", "?")))
	var meta := SaveGame.meta_for(g, {"players": names}) if g != null else {"map": session.map_name, "players": names, "time": int(Time.get_unix_time_from_system())}
	var ok := SaveGame.write({"id": session.id, "kind": "multi", "meta": meta, "map": session.map,
		"host_uid": uid, "players": session.players, "mode": str(session.get("mode", "")), "groups": session.get("groups", [])})
	_push_info()
	return ok


## Sitzungsplätze für die Lobby: [{uid, name, online, peer, wave, has_state}], der Host (peer 1) zuerst.
func session_slots() -> Array:
	var out := []
	if is_host():
		var online := {uid: 1}
		for peer in players:
			online[str(players[peer].uid)] = peer
		var uids := [uid]
		for peer in players:
			if not uids.has(players[peer].uid):
				uids.append(str(players[peer].uid))
		for u in session.get("players", {}):
			if not uids.has(u):
				uids.append(u)
		for u in uids:
			var entry: Dictionary = session.get("players", {}).get(u, {})
			var st: Dictionary = entry.get("state", {})
			var name := my_name if u == uid else (player_name(online[u]) if online.has(u) else str(entry.get("name", "?")))
			out.append({"uid": u, "name": name, "online": online.has(u), "peer": int(online.get(u, -1)),
				"has_state": not st.is_empty(), "wave": int(st.get("wave_index", 0)) + 1 if not st.is_empty() else 0,
				"field": int(session.get("fields", {}).get(u, -1))})
	else:
		out = session_info.get("slots", [])
	return out


func _state_of(u: String) -> Dictionary:
	return session.get("players", {}).get(u, {}).get("state", {})


func _store_state(u: String, n: String, state: Dictionary) -> void:
	if session.is_empty():
		return
	var ps: Dictionary = session.players
	if not ps.has(u):
		ps[u] = {}
	ps[u].name = n
	ps[u].state = state
	_push_info()


## Host: Spieler-ID eines Mitspielers festlegen. Eine schon vergebene ID (zwei Fenster auf einem
## Rechner) bekommt einen freien Platz mit gleichem Namen oder eine neue ID.
func _resolve_uid(peer: int, asked: String) -> String:
	var taken := {uid: true}
	for p in players:
		if p != peer and players[p].has("uid"):
			taken[str(players[p].uid)] = true
	if asked != "" and not taken.has(asked):
		return asked
	var n := player_name(peer)
	for u in session.get("players", {}):
		if not taken.has(u) and str(session.players[u].get("name", "")) == n:
			return u
	return _random_uid()


## Host: was ein Mitspieler über die Sitzung sieht.
func _info_for(u: String) -> Dictionary:
	var st := _state_of(u)
	var info := {
		"started": session.get("started", false),
		"loaded": session.get("loaded", false),
		"map": str(session.get("map_name", "")),
		"has_state": not st.is_empty(),
		"wave": int(st.get("wave_index", 0)) + 1 if not st.is_empty() else 0,
		"slots": session_slots(),
		"votes": session.get("votes", {}),
		"mode": str(session.get("mode", "")),
	}
	if session.has("coop"):
		info.coop = true
	info.group_peers = _group_of(u).map(func(x): return _peer_of(str(x)))
	return info


func _push_info() -> void:
	if not is_host():
		return
	for peer in players:
		if players[peer].has("uid"):
			_session_info.rpc_id(peer, _info_for(str(players[peer].uid)))
	session_changed.emit()


# --- Abstimmung über den TD-Modus ------------------------------------------------------

## Spieler in der Lobby (Host mitgezählt).
func player_count() -> int:
	return players.size() + 1 if is_active() else 1


## Eigene Stimme für einen Modus abgeben ("" = zurückziehen). Nur vor dem Start einer neuen Sitzung.
func vote(mode_id: String) -> void:
	if is_host():
		_set_vote(uid, mode_id)
	elif is_active():
		_vote.rpc_id(1, mode_id)


## Stimmen: uid -> Modus-ID.
func votes() -> Dictionary:
	return session.get("votes", {}) if is_host() else session_info.get("votes", {})


func my_vote() -> String:
	return str(votes().get(uid if is_host() else _my_slot_uid(), ""))


func _my_slot_uid() -> String:
	for slot in session_info.get("slots", []):
		if int(slot.get("peer", -1)) == my_id():
			return str(slot.get("uid", ""))
	return ""


## Auszählung: [{id, count, names}] nur für Modi, die für die aktuelle Spielerzahl erlaubt sind,
## und nur Stimmen von Verbundenen. Absteigend nach Stimmen, bei gleicher Zahl in der Reihenfolge von modes.json.
func vote_tally() -> Array:
	var online := {}
	for slot in session_slots():
		if slot.get("online", false):
			online[str(slot.uid)] = str(slot.get("name", "?"))
	var out := []
	var n := player_count()
	for m in Database.modes:
		var id := str(m.get("id", ""))
		if not Database.mode_allows(id, n):
			continue
		var names := []
		var v := votes()
		for u in v:
			if online.has(u) and str(v[u]) == id:
				names.append(online[u])
		out.append({"id": id, "count": names.size(), "names": names})
	var order := out.duplicate()
	out.sort_custom(func(a, b): return a.count > b.count or (a.count == b.count and order.find(a) < order.find(b)))
	return out


## Modi mit den meisten Stimmen (mehrere bei Gleichstand). Ohne Stimmen: alle erlaubten.
func vote_leaders() -> Array:
	var t := vote_tally()
	if t.is_empty():
		return []
	var best: int = t[0].count
	return t.filter(func(e): return e.count == best).map(func(e): return str(e.id))


## Gewinner: bei Gleichstand die Stimme des Hosts, hat er keinen der Gleichauf-Modi gewählt, das Los.
## Für die Anzeige vor dem Start gibt pick_random false den ersten Gleichauf-Modus zurück.
func vote_winner(pick_random := true) -> String:
	var leaders := vote_leaders()
	if leaders.is_empty():
		return Session.game_kind
	if leaders.size() == 1:
		return leaders[0]
	if vote_tally()[0].count == 0:
		return Session.game_kind if leaders.has(Session.game_kind) else leaders[0]
	var host_vote := ""
	for slot in session_slots():
		if int(slot.get("peer", -1)) == 1:
			host_vote = str(votes().get(str(slot.get("uid", "")), ""))
	if leaders.has(host_vote):
		return host_vote
	return leaders.pick_random() if pick_random else leaders[0]


## Host beim Start: Modus der Sitzung festlegen (gespeicherte und laufende behalten ihren).
func _fix_mode() -> void:
	if str(session.get("mode", "")) == "":
		session.mode = vote_winner()
	Session.game_kind = str(session.mode)


func _set_vote(u: String, mode_id: String) -> void:
	if session.is_empty() or session.get("started", false):
		return
	if mode_id != "" and not Database.mode_allows(mode_id, player_count()):
		return
	if not session.has("votes"):
		session.votes = {}
	if mode_id == "":
		session.votes.erase(u)
	else:
		session.votes[u] = mode_id
	_push_info()


# --- Koop -------------------------------------------------------------------------

## Reiner Koop: alle auf einem Feld, der Host rechnet (gemischte Sitzungen zählen nicht).
func is_coop() -> bool:
	return session.has("coop") or session_info.has("coop")


## Host: Feldwahl der Lobby merken, damit die Mitspieler sie sehen ({uid: Feldnummer}).
func set_fields(fields: Dictionary) -> void:
	if is_host() and session.get("fields", {}) != fields:
		session.fields = fields.duplicate()
		_push_info()


## Host: Koop-Gruppe eines Spielers (uids, der Erste rechnet), [] = spielt allein.
func _group_of(u: String) -> Array:
	if session.has("coop"):
		return session.coop if session.coop.has(u) else []
	for g in session.get("groups", []):
		if g.has(u):
			return g
	return []


## Host: peer eines Spielers (-1 = nicht verbunden).
func _peer_of(u: String) -> int:
	if u == uid:
		return 1
	for peer in players:
		if str(players[peer].get("uid", "")) == u:
			return peer
	return -1


func _name_of(u: String) -> String:
	var p := _peer_of(u)
	if p == 1:
		return my_name
	return player_name(p) if p > 0 else str(session.get("players", {}).get(u, {}).get("name", "?"))


## Peers der eigenen Koop-Gruppe in Spielerreihenfolge (-1 = gerade nicht verbunden), [] = keine.
func group_peers() -> Array:
	if is_host():
		return _group_of(uid).map(func(x): return _peer_of(str(x)))
	return session_info.get("group_peers", [])


## Peer, der das gemeinsame Feld der eigenen Gruppe rechnet (0 = keine Gruppe).
func group_host() -> int:
	var gp := group_peers()
	return int(gp[0]) if not gp.is_empty() else 0


func _i_host_group() -> bool:
	return group_host() == my_id() and my_id() > 0


## Host: Koop-Partie starten. Neu: alle Verbundenen spielen mit, in der Reihenfolge ihres Beitritts;
## Schwierigkeit und Wertung des Hosts gelten für alle. Gespeichert (_load_coop): jeder bekommt seine alte
## Spielernummer, wer fehlt, steigt später über „Mitspielen“ ein.
func start_coop(map_data: Dictionary) -> void:
	if not is_host():
		return
	var peers := players.keys()
	peers.sort()
	var state: Dictionary = session.get("coop_state", {})
	if state.is_empty():
		session.map = map_data
		session.map_name = str(map_data.get("name", ""))
		session.coop = [uid]
		for peer in peers:
			session.coop.append(str(players[peer].uid))
		session.settings = {"difficulty": Session.difficulty, "score_mode": Session.score_mode}
	else:
		session.settings = {"difficulty": int(state.get("difficulty", 1)), "score_mode": bool(state.get("score_mode", false))}
		session.erase("coop_state")
	session.started = true
	_fix_mode()
	_push_info()
	for peer in peers:
		if coop_player_of(peer) > 0:
			_begin_coop.rpc_id(peer, session.map, coop_player_of(peer), _coop_names(), session.settings)
	_begin_coop_local(session.map, 0, _coop_names(), "host", state)


## Host: gespeicherten Koop übernehmen (vorher host()). Der Host ist immer Spieler 0.
func _load_coop(data: Dictionary) -> void:
	var uids: Array = data.get("coop", []).duplicate()
	if uids.is_empty():
		uids = [uid]
	uids[0] = uid
	var names: Array = data.get("meta", {}).get("players", [])
	var ps := {}
	for i in uids.size():
		ps[str(uids[i])] = {"name": str(names[i]) if i < names.size() else "?"}
	session = {
		"id": str(data.get("id", SaveGame.new_id())),
		"map": data.get("map", {}),
		"map_name": str(data.get("meta", {}).get("map", "")),
		"mode": str(data.get("mode", "")),
		"started": false,
		"loaded": true,
		"players": ps,
		"coop": uids,
		"coop_state": data.get("state", {}),
	}
	for peer in players:
		players[peer].uid = _resolve_uid(peer, str(players[peer].get("asked_uid", "")))
	_push_info()


## Host hat die Koop-Partie verlassen: sie ist für alle vorbei (gespeichert wurde vorher, falls gewünscht).
func end_coop() -> void:
	if not _i_host_group():
		return
	for peer in _coop_peers_all():
		_coop_end.rpc_id(peer)
	if not is_host() or not session.has("coop"):
		return
	session.erase("coop")
	session.started = false
	session.loaded = false
	session.map = {}
	session.map_name = ""
	_push_info()


func _coop_peers_all() -> Array:
	return players.keys().filter(func(p): return coop_player_of(p) > 0)


## Spielernummer eines Verbundenen in der eigenen Koop-Gruppe (-1 = spielt nicht mit).
func coop_player_of(peer: int) -> int:
	if peer <= 0:
		return -1
	return group_peers().find(peer)


func _coop_names() -> Array:
	var names := []
	for u in session.get("coop", []):
		var n := my_name if u == uid else str(session.get("players", {}).get(u, {}).get("name", ""))
		for peer in players:
			if str(players[peer].get("uid", "")) == u:
				n = player_name(peer)
		names.append(n)
	return names


func _begin_coop_local(map_data: Dictionary, player: int, names: Array, role: String, state := {}) -> void:
	_begin_local(map_data, state)
	Session.coop = {"role": role, "player": player, "names": names}


## Mitspieler → Host: Befehl fürs gemeinsame Feld.
func send_coop_command(cmd: Dictionary) -> void:
	if is_active() and group_host() > 0 and not _i_host_group():
		_coop_cmd.rpc_id(group_host(), cmd)


## Mitspieler → Host: Spiel ist geladen, bitte den vollen Stand schicken.
func send_coop_ready() -> void:
	if is_active() and group_host() > 0 and not _i_host_group():
		_coop_hello.rpc_id(group_host())


## Host → Mitspieler (peer 0 = alle, die mitspielen).
func send_coop_state(peer: int, data: Dictionary) -> void:
	for p in ([peer] if peer != 0 else _coop_peers()):
		_coop_state.rpc_id(p, data)


func send_coop_enemies(data: Dictionary) -> void:
	for p in _coop_peers():
		_coop_enemies.rpc_id(p, data)


func send_hero_input(frame: Dictionary) -> void:
	if is_active() and group_host() > 0 and not _i_host_group():
		_hero_input.rpc_id(group_host(), frame)


func send_hero_frame(chunk: Dictionary) -> void:
	for peer in _coop_peers():
		_hero_frame.rpc_id(peer, chunk)


@rpc("any_peer", "call_remote", "unreliable", 3)
func _hero_frame(chunk: Dictionary) -> void:
	if _from_group_host():
		coop_enemies.emit(chunk)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _hero_input(frame: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _i_host_group() and coop_player_of(peer) > 0:
		hero_input.emit(peer, frame)


func _coop_peers() -> Array:
	if not _i_host_group():
		return []
	return players.keys().filter(func(p): return coop_player_of(p) > 0 and player_status(p).get("in_game", false))


func _begin_local(map_data: Dictionary, state: Dictionary) -> void:
	Session.coop = {}
	Session.load_state = state.duplicate(true)
	Session.save_id = ""
	Session.map_override = MapData.from_dict(state.get("map", map_data))
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.game_scene())


static func _random_uid() -> String:
	return Crypto.new().generate_random_bytes(12).hex_encode()


# --- RPCs ------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello(n: String, status: Dictionary, their_uid: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var known: Dictionary = players.get(id, {})
	players[id] = {"name": n, "status": status, "asked_uid": their_uid}
	if is_host():
		players[id].uid = str(known.uid) if known.has("uid") else _resolve_uid(id, their_uid)
		if session.players.has(players[id].uid):
			session.players[players[id].uid].name = n
		_push_info()
	players_changed.emit()


@rpc("any_peer", "reliable")
func _status(status: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].status = status
		players_changed.emit()


@rpc("any_peer", "reliable")
func _watch(on: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if on:
		watchers[id] = true
	else:
		watchers.erase(id)
	watchers_changed.emit()


@rpc("any_peer", "reliable")
func _map(data: Dictionary) -> void:
	map_received.emit(multiplayer.get_remote_sender_id(), data)


@rpc("any_peer", "reliable")
func _field(data: Dictionary) -> void:
	field_received.emit(multiplayer.get_remote_sender_id(), data)


@rpc("any_peer", "unreliable_ordered")
func _enemies(data: Dictionary) -> void:
	enemies_received.emit(multiplayer.get_remote_sender_id(), data)


## Host → Mitspieler: Spiel starten, mit gespeichertem Stand oder neu auf der Map.
@rpc("authority", "reliable")
func _begin(map_data: Dictionary, state: Dictionary) -> void:
	_begin_local(map_data, state)


## Mitspieler → Host: in die laufende Sitzung einsteigen (im Koop mit seiner Spielernummer, wer neu ist,
## schaut nur zu, bis die nächste Partie startet).
@rpc("any_peer", "reliable")
func _join_game() -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not session.get("started", false) or not players.has(id):
		return
	if session.has("coop"):
		if coop_player_of(id) > 0:
			_begin_coop.rpc_id(id, session.map, coop_player_of(id), _coop_names(), session.settings)
		return
	_send_begin(id)


## Host → Mitspieler: Koop-Partie starten. Spieler 0 rechnet das Feld seiner Gruppe (gemischte Sitzung),
## state: ihr gespeicherter Stand.
@rpc("authority", "reliable")
func _begin_coop(map_data: Dictionary, player: int, names: Array, settings: Dictionary, state := {}) -> void:
	Session.difficulty = int(settings.get("difficulty", Session.difficulty))
	Session.score_mode = bool(settings.get("score_mode", false))
	_begin_coop_local(map_data, player, names, "host" if player == 0 else "client", state)


@rpc("any_peer", "reliable")
func _coop_cmd(cmd: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if _i_host_group() and coop_player_of(id) > 0:
		coop_command.emit(id, cmd)


@rpc("any_peer", "reliable")
func _coop_hello() -> void:
	var id := multiplayer.get_remote_sender_id()
	if _i_host_group() and coop_player_of(id) > 0:
		coop_ready.emit(id)


## Nur vom Rechner, der das Feld der eigenen Gruppe rechnet.
func _from_group_host() -> bool:
	var id := multiplayer.get_remote_sender_id()
	return id > 0 and id == group_host()


@rpc("any_peer", "reliable")
func _coop_end() -> void:
	if _from_group_host() and game != null and is_instance_valid(game) and game.coop != null:
		_set_status(tr("Der Host hat die Koop-Partie beendet."))
		Session.goto(Session.MAIN_MENU)


@rpc("any_peer", "reliable")
func _coop_state(data: Dictionary) -> void:
	if _from_group_host():
		coop_state.emit(data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _coop_enemies(data: Dictionary) -> void:
	if _from_group_host():
		coop_enemies.emit(data)


## Host → Mitspieler: aktuellen Stand fürs Speichern schicken. Koop-Mitspieler haben kein eigenes Feld,
## das gemeinsame meldet der Erste ihrer Gruppe.
@rpc("authority", "reliable")
func _request_state() -> void:
	if game != null and is_instance_valid(game) and game.mirror:
		_state_report.rpc_id(1, {}, false)
	elif game != null and is_instance_valid(game):
		_state_report.rpc_id(1, SaveGame.capture(game), true)
	else:
		_state_report.rpc_id(1, {}, false)


## Mitspieler → Host: Stand des eigenen Felds (in_game false: spielt gerade nicht, nichts ändern).
@rpc("any_peer", "reliable")
func _state_report(state: Dictionary, in_game: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not players.has(id):
		return
	_reports[id] = true
	if in_game:
		_store_state(str(players[id].uid), player_name(id), state)


## Mitspieler → Host: Stimme für einen Modus.
@rpc("any_peer", "reliable")
func _vote(mode_id: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and players.has(id) and players[id].has("uid"):
		_set_vote(str(players[id].uid), mode_id)


@rpc("authority", "reliable")
func _session_info(info: Dictionary) -> void:
	session_info = info
	if str(info.get("mode", "")) != "":
		Session.game_kind = str(info.mode)
	session_changed.emit()


# --- Verbindung ----------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	_hello.rpc_id(id, my_name, my_status, uid)


func _on_peer_disconnected(id: int) -> void:
	# Wer das gemeinsame Feld meiner Gruppe gerechnet hat, ist weg: Partie vorbei
	if id != 1 and id == group_host() and not is_host() and game != null and is_instance_valid(game) and game.get("mirror"):
		session_info.erase("group_peers")
		_set_status(tr("Die Koop-Partie ist vorbei: %s hat das Spiel verlassen.") % player_name(id))
		Session.goto(Session.MAIN_MENU)
	players.erase(id)
	_reports.erase(id)
	if watchers.erase(id):
		watchers_changed.emit()
	_push_info()
	players_changed.emit()


func _on_connected() -> void:
	_set_status(tr("Verbunden"))
	connection_changed.emit()


func _on_failed() -> void:
	var why := _relay_error
	leave()
	_set_status(why if why != "" else tr("Verbindung fehlgeschlagen"))


func _on_server_lost() -> void:
	var own_room := via_relay() and multiplayer.is_server()
	leave()
	_set_status(tr("Verbindung zum Server verloren") if own_room else tr("Verbindung zum Host verloren"))


func _set_status(t: String) -> void:
	status_text = t
	connection_changed.emit()
