class_name CoopSync
extends Node
## Koop: alle spielen auf einem gemeinsamen Feld. Der Host rechnet das Spiel, die Mitspieler zeigen es nur an.
##   Host:        führt die Befehle der Mitspieler aus (game.execute mit ihrer Spielernummer) und schickt den
##                Stand: Feld (Tower, Steine, Spieler, Phase …) sofort bei jeder Änderung, sonst einmal pro
##                Sekunde (für Kills und Schaden der Tower), Gegner und Schüsse etwa 15 Mal pro Sekunde.
##   Mitspieler:  game.mirror ist an, game.submit() schickt Befehle hierher und weiter an den Host; der Stand
##                vom Host wird ins eigene Spiel übernommen, so laufen Anzeige und Regeln (welche Optionen ein
##                Tower hat) mit demselben Code wie solo. Gegner laufen wie beim Zuschauen auf dem gemeldeten
##                Weg weiter (enemy.gd → _remote_step).
##   Erlaubte Befehle und der Modus-Stand (unter "mode") kommen vom System coop (coop.gd, Werte in data/modes.json
##                → system_cfg.coop). Modi auf game.gd hängen sich außerdem mit eigenen Methoden an, falls vorhanden:
##                new_tower() Tower-Klasse für Mitspieler, coop_stats()/apply_coop_stats(d)
##                was sich laufend ändert und nicht als neuer Stand zählt (unter "mstats", wie "tstats"),
##                coop_fast()/apply_coop_fast(d) was mit den Gegnern 15 Mal pro Sekunde mitgeht (unter "m", z. B.
##                Geschosse in YouTD).

const STATE_INTERVAL := 1.0
const CHECK_INTERVAL := 0.05
const ENEMY_INTERVAL := 1.0 / 15.0
const MAX_BEAMS := 64

var game  # game.gd
var host := true
## Wohin ein Mitspieler seine Befehle schickt (Tests verbinden zwei Spiele direkt).
var command_sink: Callable = func(cmd: Dictionary): Net.send_coop_command(cmd)
## Mitspieler: Wege für die angezeigten Gegner
var paths: RemoteField
var enemies: Dictionary = {}   ## Mitspieler: net_id -> Enemy

var _beams: Array = []
var _last_hash := 0
var _state_timer := 0.0
var _check_timer := 0.0
var _enemy_timer := 0.0
var _sent_enemies := true
var _seen: Dictionary = {}   ## Host: Spielernummern, die schon im Spiel waren


func _ready() -> void:
	if host:
		Net.coop_command.connect(_on_net_command)
		Net.coop_ready.connect(func(peer): Net.send_coop_state(peer, snapshot()))
		Net.players_changed.connect(_update_away)
	else:
		paths = RemoteField.new()
		add_child(paths)
		Net.coop_state.connect(apply_state)
		Net.coop_enemies.connect(apply_enemies)
		Net.send_coop_ready()


func _process(delta: float) -> void:
	if not host:
		return
	var dt := delta / maxf(Engine.time_scale, 0.01)
	_check_timer -= dt
	_state_timer -= dt
	if _check_timer <= 0.0:
		_check_timer = CHECK_INTERVAL
		var s := snapshot()
		var h := structure_hash(s)
		if h != _last_hash or _state_timer <= 0.0:
			_last_hash = h
			_state_timer = STATE_INTERVAL
			Net.send_coop_state(0, s)
	_enemy_timer -= dt
	if _enemy_timer <= 0.0:
		_enemy_timer = ENEMY_INTERVAL
		var p := enemy_packet()
		if not p.e.is_empty() or not p.b.is_empty() or _sent_enemies:
			Net.send_coop_enemies(p)
		_sent_enemies = not p.e.is_empty()


# --- Host ------------------------------------------------------------------------

## Befehl eines Mitspielers (Spielernummer p). Nur bekannte Befehle, die Spielernummer setzt der Host.
func receive(p: int, cmd: Dictionary) -> bool:
	if not game.systems.coop.commands().has(str(cmd.get("type", ""))):
		return false
	cmd.player = p
	return game.execute(cmd)


func _on_net_command(peer: int, cmd: Dictionary) -> void:
	var p := Net.coop_player_of(peer)
	if p > 0:
		receive(p, cmd)


## Wer die Verbindung verliert oder das Spiel verlässt, hält die Runde nicht auf (System coop → set_away).
## Wer noch lädt, gilt als da.
func _update_away() -> void:
	var here := {0: true}
	for peer in Net.players:
		var p := Net.coop_player_of(peer)
		var in_game: bool = Net.player_status(peer).get("in_game", false)
		if in_game:
			_seen[p] = true
		if in_game or not _seen.has(p):
			here[p] = true
	for i in game.players.size():
		game.systems.coop.set_away(i, not here.has(i))


## Schusslinie für die Mitspieler merken (game.gd → add_beam).
func add_beam(from: Vector3, to: Vector3, col: Color, fx: String = "") -> void:
	if _beams.size() < MAX_BEAMS:
		_beams.append([from, to, col, fx] if fx != "" else [from, to, col])


## Feldstand für die Mitspieler. "tstats" (Kills, Schaden je Tower) ändert sich laufend und zählt nicht
## als Änderung, siehe structure_hash.
func snapshot() -> Dictionary:
	var list: Array = game.all_towers()
	var ts := []
	var stats := []
	for t in list:
		ts.append([t.cell.x, t.cell.y, t.is_trap(), t.tower_id, t.tier, t.is_new, t.owner_player, t.moves_left])
		stats.append([t.kills, t.total_damage, snappedf(t.ep, 0.01)])
	var rs := PackedInt32Array()
	for c in game.rocks:
		rs.append(c.x)
		rs.append(c.y)
	var ps := []
	for p in game.players:
		ps.append({"name": p.name, "gold": p.gold, "stage": p.stage, "away": p.away, "extra_chance": p.extra_chance,
			"round": p.round_towers.map(func(t): return game.tower_ref(t))})
	var s := {
		"phase": game.phase,
		"wave": game.wave_index,
		"lives": game.lives,
		"score": game.score,
		"chance": game.chance_level,
		"path_start": game.round_path_start,
		"killed": game.enemies_killed,
		"score_stats": game.score_stats,
		"final_boss": game.final_boss,
		"leaks": game.leaks_per_wave,
		"ts": Engine.time_scale,
		"setup": game.setup_done,
		"difficulty": Session.difficulty,
		"ascension": game.ascension,
		"score_mode": game.score_mode,
		"foreign_build": game.foreign_build,
		"players": ps,
		"towers": ts,
		"rocks": rs,
		"tstats": stats,
	}
	if game.rogue != null:
		s.rogue = game.rogue.to_dict()
	s.mode = game.systems.coop.snapshot()
	if game.has_method("coop_stats"):
		s.mstats = game.coop_stats()
	return s


static func structure_hash(s: Dictionary) -> int:
	var d := s.duplicate()
	d.erase("tstats")
	d.erase("mstats")
	return hash(d)


func enemy_packet() -> Dictionary:
	var list := []
	for e in game.enemies:
		if not e.dead:
			list.append(e.net_state())
	var p := {"e": list, "b": _beams, "q": game.spawn_queue.size(), "wl": game.wave_live, "now": Time.get_ticks_msec()}
	if game.has_method("coop_fast"):
		p.m = game.coop_fast()
	_beams = []
	return p


# --- Mitspieler ------------------------------------------------------------------

func send(cmd: Dictionary) -> void:
	command_sink.call(cmd)


## Stand vom Host übernehmen.
func apply_state(s: Dictionary) -> void:
	var g = game
	var was_phase: int = g.phase
	var was_stage: int = g.stage()
	# Tower: gleicher Platz und Art (Falle oder nicht) ist derselbe Tower, so bleibt die Auswahl erhalten
	var wanted := {}
	var stats: Array = s.get("tstats", [])
	var list: Array = s.get("towers", [])
	for i in list.size():
		var d: Array = list[i]
		wanted["%d,%d,%s" % [d[0], d[1], bool(d[2])]] = [d, stats[i] if i < stats.size() else [0, 0.0]]
	for t in g.all_towers():
		if not wanted.has("%d,%d,%s" % [t.cell.x, t.cell.y, t.is_trap()]):
			_remove_tower(t)
	# Steine
	var rocks := {}
	var rs: PackedInt32Array = s.get("rocks", PackedInt32Array())
	for i in range(0, rs.size() - 1, 2):
		rocks[Vector2i(rs[i], rs[i + 1])] = true
	for c in g.rocks.keys():
		if not rocks.has(c):
			g.rocks.erase(c)
			g._occupy(c, false, false)
	for c in rocks:
		if not g.rocks.has(c):
			g.rocks[c] = true
			g._occupy(c, true, true)
	for k in wanted:
		var d: Array = wanted[k][0]
		var st: Array = wanted[k][1]
		var cell := Vector2i(int(d[0]), int(d[1]))
		var t: Tower = g.tower_from_ref({"cell": cell, "trap": bool(d[2])})
		var id := str(d[3])
		if t == null:
			if not Database.towers.has(id):
				continue
			t = g.new_tower() if g.has_method("new_tower") else Tower.new()
			t.is_new = bool(d[5])
			t.owner_player = int(d[6])
			g.board.add_child(t)
			t.setup(g, cell, id, int(d[4]))
			g._register(t)
		elif (t.tower_id != id or t.tier != int(d[4]) or t.is_new != bool(d[5])) and Database.towers.has(id):
			t.is_new = bool(d[5])
			g._unregister(t)
			t.set_tower(id, int(d[4]))
			g._register(t)
			if t == g.selected:
				t.set_selected(true)
		t.owner_player = int(d[6])
		t.moves_left = int(d[7])
		t.kills = int(st[0])
		t.total_damage = float(st[1])
		if st.size() > 2 and not is_equal_approx(float(st[2]), t.ep):
			t.set_ep(float(st[2]))
	# Spieler
	var ps: Array = s.get("players", [])
	while g.players.size() < ps.size():
		g.players.append(PlayerState.new(g.players.size()))
	for i in ps.size():
		var pd: Dictionary = ps[i]
		var p: PlayerState = g.players[i]
		p.name = str(pd.get("name", ""))
		p.gold = int(pd.get("gold", 0))
		p.stage = int(pd.get("stage", 0))
		p.away = bool(pd.get("away", false))
		p.extra_chance = str(pd.get("extra_chance", ""))
		p.round_towers = pd.get("round", []).map(func(r): return g.tower_from_ref(r)).filter(func(t): return t != null)
	# Gemeinsames
	g.wave_index = int(s.get("wave", 0))
	g.lives = int(s.get("lives", g.lives))
	g.score = float(s.get("score", 0.0))
	g.chance_level = int(s.get("chance", 0))
	g.round_path_start = int(s.get("path_start", 0))
	g.enemies_killed = int(s.get("killed", 0))
	g.score_stats = s.get("score_stats", {})
	g.final_boss = s.get("final_boss", g.final_boss)
	g.leaks_per_wave = s.get("leaks", {})
	if s.has("rogue"):
		g.enable_rogue().from_dict(s.rogue)
	if s.has("mode"):
		g.systems.coop.apply(s.mode)
	if s.has("mstats") and g.has_method("apply_coop_stats"):
		g.apply_coop_stats(s.mstats)
	g.foreign_build = bool(s.get("foreign_build", false))
	g.ascension = int(s.get("ascension", g.ascension))
	if s.get("setup", true) and not g.setup_done:
		Session.difficulty = int(s.get("difficulty", Session.difficulty))
		Session.score_mode = bool(s.get("score_mode", false))
		g.score_mode = Session.score_mode
		g.setup_done = true
	Engine.time_scale = float(s.get("ts", 1.0))
	paths.time_scale = Engine.time_scale
	var phase := int(s.get("phase", g.Phase.BUILD))
	if phase == g.Phase.WAVE and was_phase != g.Phase.WAVE:
		# Wellenstart: Warteschlange wie beim Host, sie schrumpft mit "q" aus den Gegner-Meldungen
		g.spawn_queue.clear()
		for grp in g.waves[g.wave_index].get("groups", []) if g.wave_index < g.waves.size() else []:
			g.spawn_queue.append_array(g.group_queue(grp))
		g.wave_live = {"gone_hp": 0.0, "gone_dealt": 0.0, "killed": 0, "leaked": 0}
	elif phase != g.Phase.WAVE and was_phase == g.Phase.WAVE:
		g.spawn_queue.clear()
		_clear_enemies()
		g.effects.clear()
	g._update_paths()
	g._update_auras()
	g.board.refresh_rocks()
	for i in g.lane_paths.size():
		paths.set_paths(g.lane_paths[i].ground, g.lane_paths[i].air, i)
	g.board.hover_cell = g.NO_CELL
	# Auswahl aufräumen: entfernte Steine abwählen, eigene neue Runde fertig gesetzt → letzten Gem wählen
	if g.moving != null and not is_instance_valid(g.moving):
		g.moving = null
	if g.selected_rocks.any(func(c): return not g.rocks.has(c)):
		g._select(null)
	if phase >= g.Phase.GAME_OVER:
		if was_phase < g.Phase.GAME_OVER:
			g._finish(phase)
		return
	g.phase = phase
	if g.stage() == g.Phase.CHOOSE and was_stage == g.Phase.BUILD and not g.round_towers.is_empty():
		g._select(g.round_towers[-1])
	elif g.stage() == g.Phase.BUILD and was_stage == g.Phase.CHOOSE and g.selected != null and is_instance_valid(g.selected) and g.selected.is_new:
		g._select(null)
	g._refresh_hud()


func _remove_tower(t: Tower) -> void:
	game._unregister(t)
	if t == game.selected:
		game._select(null)
	if t == game.moving:
		game.moving = null
	t.queue_free()


## Gegner vom Host: wie beim Zuschauen anlegen, nachführen und entfernen.
func apply_enemies(packet: Dictionary) -> void:
	var g = game
	if packet.has("m") and g.has_method("apply_coop_fast"):
		g.apply_coop_fast(packet.m)
	if g.phase != g.Phase.WAVE:
		return
	var age: float = paths.packet_age(packet)
	var seen := {}
	for s in packet.get("e", []):
		var id := int(s[0])
		seen[id] = true
		var e: Enemy = enemies.get(id)
		if e == null:
			var def: Dictionary = game.enemy_def(str(s[1])) if game.has_method("enemy_def") else Database.enemies.get(str(s[1]), {})
			if def.is_empty():
				continue
			e = Enemy.new()
			e.remote = true
			e.remote_field = paths
			e.net_id = id
			e.lane = int(s[9]) if s.size() > 9 else 0
			g.board.add_child(e)
			var grp := _group_for(str(s[1]))
			if s.size() > 8:
				grp = grp.duplicate()
				grp.shape = str(s[7])
				grp.size = float(s[8])
			e.setup(g, def, grp, paths.path_for(bool(def.get("flying", false)), e.lane))
			g.setup_score(e, grp)
			e.traveled = float(s[2])
			enemies[id] = e
			g.enemies.append(e)
		e.apply_net_state(s, age)
	for id in enemies.keys():
		if not seen.has(id):
			g.enemies.erase(enemies[id])
			enemies[id].queue_free()
			enemies.erase(id)
	var q := int(packet.get("q", g.spawn_queue.size()))
	while g.spawn_queue.size() > q:
		g.spawn_queue.pop_front()
	g.wave_live = packet.get("wl", g.wave_live)
	for b in packet.get("b", []):
		g.effects.add_beam(b[0], b[1], b[2], str(b[3]) if b.size() > 3 else "")


func _group_for(enemy_id: String) -> Dictionary:
	if game.wave_index < game.waves.size():
		for grp in game.waves[game.wave_index].get("groups", []):
			if str(grp.get("enemy", "")) == enemy_id:
				return grp
	return {"enemy": enemy_id}


func _clear_enemies() -> void:
	for e in enemies.values():
		game.enemies.erase(e)
		e.queue_free()
	enemies.clear()
