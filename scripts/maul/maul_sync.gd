class_name MaulSync
extends Node
## Koop in Shopping Maul: jeder Spieler hat sein eigenes Gebiet (Zone) im selben Einkaufszentrum, die
## Leben sind gemeinsam. Wie coop_sync.gd rechnet nur der Host:
##   Host:        führt die Befehle der Mitspieler aus (game.execute mit ihrer Spielernummer) und schickt den
##                Stand (Phase, Level, Spieler, Tower …) sofort bei jeder Änderung, sonst einmal pro Sekunde;
##                Gegner, Einheiten und Schüsse etwa 15 Mal pro Sekunde.
##   Mitspieler:  game.mirror ist an, game.submit() schickt Befehle hierher und weiter an den Host. Gegner und
##                Einheiten gleiten zur gemeldeten Stelle (maul_enemy.gd, maul_unit.gd), Tower schießen nicht.
## XP gehören dem Rechner des Spielers: der Mitspieler meldet sie mit der Filialwahl, der Host rechnet sie
## nach jedem Level weiter, der Mitspieler speichert, was zurückkommt.

const STATE_INTERVAL := 1.0
const CHECK_INTERVAL := 0.05
const ENEMY_INTERVAL := 1.0 / 15.0
const MAX_BEAMS := 96
## Befehle, die ein Mitspieler schicken darf (maul_game.gd → _execute)
const COMMANDS := ["shop", "build", "sell", "upgrade", "speed", "reveal", "bonus", "research", "item", "item_sell",
	"move_items", "item_move", "copy", "summon", "drone", "module", "module_sell", "post", "deposit", "withdraw", "auto_deposit", "bank_upgrade", "team", "xp"]
## Werte, die sich laufend ändern und allein keinen sofortigen Stand auslösen
const LIVE_KEYS := ["live", "gt", "countdown"]

var game: MaulGame
var host := true
## Wohin ein Mitspieler seine Befehle schickt (Tests verbinden zwei Spiele direkt).
var command_sink: Callable = func(cmd: Dictionary): Net.send_coop_command(cmd)
var enemies: Dictionary = {}   ## Mitspieler: net_id → MaulEnemy

var _beams: Array = []
var _last_hash := 0
var _state_timer := 0.0
var _check_timer := 0.0
var _enemy_timer := 0.0
var _sent_enemies := true
var _got_state := false
var _note_seen := 0


func _ready() -> void:
	if host:
		Net.coop_command.connect(_on_net_command)
		Net.coop_ready.connect(func(peer): Net.send_coop_state(peer, snapshot()))
	else:
		Net.coop_state.connect(apply_state)
		Net.coop_enemies.connect(apply_enemies)
		Net.send_coop_ready()
	Net.set_status({"in_game": true, "mode": "shoppingmaul"})


func _exit_tree() -> void:
	Net.set_status({"in_game": false})


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
		if not p.e.is_empty() or not p.u.is_empty() or not p.b.is_empty() or _sent_enemies:
			Net.send_coop_enemies(p)
		_sent_enemies = not p.e.is_empty() or not p.u.is_empty()


# --- Host ------------------------------------------------------------------------

func _on_net_command(peer: int, cmd: Dictionary) -> void:
	var p := Net.coop_player_of(peer)
	if p > 0:
		receive(p, cmd)


## Befehl eines Mitspielers (Spielernummer p). Nur bekannte Befehle, die Spielernummer setzt der Host.
func receive(p: int, cmd: Dictionary) -> bool:
	if not COMMANDS.has(str(cmd.get("type", ""))) or p >= game.players.size():
		return false
	cmd.player = p
	return game.execute(cmd)


func add_beam(from: Vector3, to: Vector3, col: Color, fx := "") -> void:
	if _beams.size() < MAX_BEAMS:
		_beams.append([from, to, col, fx] if fx != "" else [from, to, col])


func snapshot() -> Dictionary:
	var g := game
	var ps := []
	for p in g.players:
		ps.append({"name": p.name, "shop": p.shop, "gold": p.gold, "xp": p.xp, "bonus": p.bonus, "research": p.research,
			"kills": p.kills, "reveal_until": p.reveal_until, "reveal_ready": p.reveal_ready, "team_points": p.team_points,
			"bank": [p.account, p.auto_deposit, p.bank_level, ceilf(p.withdraw_in), p.emma_mined]})
	var ts := []
	var live := []
	for t in g.towers.values():
		ts.append([t.cell.x, t.cell.y, t.tower_id, t.owner_player, t.value, t.items, t.flat, t.side, t.paused, t.drugs,
			t.corpses, t.unleashed_until, t.summon_ready])
		live.append([t.kills, t.total_damage, snappedf(t.water, 0.1), t.active])
	return {
		"phase": g.phase,
		"level": g.level,
		"levels_done": g.levels_done,
		"debug": g.debug_used,
		"lives": g.lives,
		"max_lives": g.max_lives,
		"difficulty": g.difficulty,
		"ascension": g.ascension,
		"mode": g.mode,
		"sandbox": g.sandbox,
		"foreign_build": g.foreign_build,
		"share_gold": g.share_gold,
		"team_fx": [g.sight_until, g.winter_until],
		"killed": g.enemies_killed,
		"leaked": g.enemies_leaked,
		"je": [g.je, g.je_min, g.je_max],
		"income": g.income_pot,
		"level_info": [g.level_kind, g.level_specials, g.level_count],
		"ts": Engine.time_scale,
		"players": ps,
		"towers": ts,
		"notes": g.notes,
		"live": live,
		"gt": g.game_time,
		"countdown": g.countdown,
	}


static func structure_hash(s: Dictionary) -> int:
	var d := s.duplicate()
	for k in LIVE_KEYS:
		d.erase(k)
	return hash(d)


func enemy_packet() -> Dictionary:
	var list := []
	for e in game.enemies:
		if e.dead:
			continue
		var flags := (1 if e.flying else 0) | (2 if e.boss else 0) | (4 if e.invisible else 0) | (8 if e.ghost else 0) \
				| (16 if e.bar_shown else 0)
		list.append([e.net_id, snappedf(e.pos.x, 0.01), snappedf(e.pos.y, 0.01), roundf(e.hp), roundf(e.max_hp), flags,
			e.color.to_html(false), e.size, e.armor_type])
	var units := []
	for u in game.units:
		units.append(u.net_state())
	var p := {"e": list, "u": units, "b": _beams, "q": _queue_left()}
	_beams = []
	return p


func _queue_left() -> int:
	var n := 0
	for s in game.spawn_queue:
		n += int(s[1])
	return n


# --- Mitspieler ------------------------------------------------------------------

func send(cmd: Dictionary) -> void:
	command_sink.call(cmd)


## Stand vom Host übernehmen.
func apply_state(s: Dictionary) -> void:
	var g := game
	var was_phase: int = g.phase
	var me: MaulGame.Player = g.players[g.local_player]
	var xp_before := me.xp
	# Spieler
	var ps: Array = s.get("players", [])
	for i in mini(ps.size(), g.players.size()):
		var d: Dictionary = ps[i]
		var p: MaulGame.Player = g.players[i]
		p.name = str(d.get("name", p.name))
		p.shop = str(d.get("shop", ""))
		p.gold = int(d.get("gold", 0))
		p.xp = int(d.get("xp", p.xp))
		p.bonus = int(d.get("bonus", 0))
		p.research = d.get("research", {})
		p.kills = int(d.get("kills", 0))
		p.reveal_until = float(d.get("reveal_until", -1.0))
		p.reveal_ready = float(d.get("reveal_ready", 0.0))
		p.team_points = int(d.get("team_points", 0))
		var bank: Array = d.get("bank", [0, false, 0, 0.0, 0])
		p.account = int(bank[0])
		p.auto_deposit = bool(bank[1])
		p.bank_level = int(bank[2])
		p.withdraw_in = float(bank[3])
		p.emma_mined = int(bank[4])
	# Tower: gleicher Anker ist derselbe Tower, so bleibt die Auswahl erhalten
	var wanted := {}
	var list: Array = s.get("towers", [])
	var live: Array = s.get("live", [])
	for i in list.size():
		wanted[Vector2i(int(list[i][0]), int(list[i][1]))] = i
	for t in g.towers.values():
		if not wanted.has(t.cell):
			g._unregister(t)
			t.queue_free()
	for cell in wanted:
		var i: int = wanted[cell]
		var d: Array = list[i]
		var id := str(d[2])
		if MaulData.tower(id).is_empty():
			continue
		var t: MaulTower = g.towers.get(cell, null)
		if t == null:
			t = MaulTower.new()
			t.owner_player = int(d[3])
			g.board.add_child(t)
			t.setup(g, cell, id, 0)
			g._register(t)
		elif t.tower_id != id:
			t.set_tower(id, 0)
			t.set_selected(t == g.selected)
			g._update_detect()
		t.owner_player = int(d[3])
		t.value = int(d[4])
		t.items = d[5]
		t.flat = float(d[6])
		t.side = int(d[7])
		t.paused = bool(d[8])
		if t.drugs != d[9]:
			t.drugs = d[9]
			t._update_extra()
		t.corpses = int(d[10])
		t.unleashed_until = float(d[11])
		t.summon_ready = d[12]
		if i < live.size():
			t.kills = int(live[i][0])
			t.total_damage = float(live[i][1])
			t.water = float(live[i][2])
			t.active = bool(live[i][3])
	# Gemeinsames
	g.level = int(s.get("level", 0))
	g.levels_done = int(s.get("levels_done", 0))
	g.debug_used = g.debug_used or bool(s.get("debug", false))
	g.lives = int(s.get("lives", g.lives))
	g.max_lives = int(s.get("max_lives", g.max_lives))
	g.difficulty = int(s.get("difficulty", g.difficulty))
	g.ascension = int(s.get("ascension", 0))
	g.mode = str(s.get("mode", g.mode))
	g.sandbox = bool(s.get("sandbox", false))
	g.foreign_build = bool(s.get("foreign_build", false))
	g.share_gold = bool(s.get("share_gold", false))
	var team_fx: Array = s.get("team_fx", [-1.0, -1.0])
	g.sight_until = float(team_fx[0])
	g.winter_until = float(team_fx[1])
	g.enemies_killed = int(s.get("killed", 0))
	g.enemies_leaked = int(s.get("leaked", 0))
	var je: Array = s.get("je", [1.0, 1.0, 1.0])
	g.je = float(je[0])
	g.je_min = float(je[1])
	g.je_max = float(je[2])
	g.income_pot = int(s.get("income", g.income_pot))
	var info: Array = s.get("level_info", ["", [], 0])
	g.level_kind = str(info[0])
	g.level_specials = info[1]
	g.level_count = int(info[2])
	g.game_time = float(s.get("gt", g.game_time))
	g.countdown = float(s.get("countdown", 0.0))
	Engine.time_scale = float(s.get("ts", 1.0))
	# Meldungen für mich
	var note: Array = s.get("notes", {}).get(g.local_player, [0, ""])
	if int(note[0]) != _note_seen:
		if _got_state:
			g.show_message(str(note[1]))
		_note_seen = int(note[0])
	# XP: gehören diesem Rechner. Steigt der Mitspieler in eine laufende (geladene) Partie ein, meldet er dem
	# Host seine eigenen XP, statt die aus dem Spielstand zu übernehmen.
	if not host and not _got_state and int(s.get("phase", 0)) != MaulGame.Phase.SETUP and me.shop != "" and not g.sandbox:
		me.xp = xp_before
		send({"type": "xp", "xp": xp_before})
	elif me.xp != xp_before and _got_state and not g.debug_run():
		MaulXp.save_xp(me.xp)
		g._announce_unlocks(xp_before, me.xp)
	_got_state = true
	# Phase
	var phase := int(s.get("phase", MaulGame.Phase.SETUP))
	if phase >= MaulGame.Phase.GAME_OVER:
		if was_phase < MaulGame.Phase.GAME_OVER:
			_clear_enemies()
			g._finish(phase)
		return
	g.phase = phase
	if phase == MaulGame.Phase.WAVE and was_phase != MaulGame.Phase.WAVE:
		g.show_message(g.level_title(g.level), 4.0)
	elif phase == MaulGame.Phase.COUNTDOWN and was_phase == MaulGame.Phase.WAVE:
		_clear_enemies()
		g.effects.clear()
		g.show_message(tr("Welle %d geschafft") % g.levels_done, 4.0)
	if was_phase == MaulGame.Phase.SETUP and phase != MaulGame.Phase.SETUP:
		g.hud.refresh_setup()
	if me.shop != "" and g.hud.setup_visible():
		g.hud.hide_setup()
		g.hud.build_shop()
	g._refresh_hud()
	if g.selected != null and is_instance_valid(g.selected):
		g.hud.refresh_selection()


## Gegner, Einheiten und Schüsse vom Host.
func apply_enemies(packet: Dictionary) -> void:
	var g := game
	var seen := {}
	if g.phase == MaulGame.Phase.WAVE:
		for s in packet.get("e", []):
			var id := int(s[0])
			seen[id] = true
			var e: MaulEnemy = enemies.get(id)
			var at := Vector2(float(s[1]), float(s[2]))
			if e == null:
				var flags := int(s[5])
				e = MaulEnemy.new()
				e.net_id = id
				e.invisible = flags & 4 != 0
				e.ghost = flags & 8 != 0
				g.board.add_child(e)
				var def := {"id": "", "flying": flags & 1 != 0, "boss": flags & 2 != 0, "color": "#" + str(s[6])}
				var o := {"hp": float(s[4]), "size": float(s[7]), "armor_type": str(s[8])}
				e.setup(g, def, o, PackedVector2Array([at]))
				e.pos = at
				enemies[id] = e
				g.enemies.append(e)
			e.net_pos = at
			e.net_bar = int(s[5]) & 16 != 0
			e.max_hp = float(s[4])
			e.hp = float(s[3])
	for id in enemies.keys():
		if not seen.has(id):
			g.enemies.erase(enemies[id])
			if g.selected_enemy == enemies[id]:
				g.selected_enemy = null
			enemies[id].queue_free()
			enemies.erase(id)
	# Einheiten
	var useen := {}
	for d in packet.get("u", []):
		var id := int(d[0])
		useen[id] = true
		var u := g.unit_by_id(id)
		if u == null:
			u = MaulUnit.new()
			u.net_id = id
			u.home = Vector2i(int(d[11]), int(d[12]))
			g.board.add_child(u)
			u.setup(g, str(d[1]), int(d[10]), Vector2(float(d[2]), float(d[3])))
			g.units.append(u)
		u.apply_net(d)
	for u in g.units.duplicate():
		if not useen.has(u.net_id):
			g.remove_unit(u)
	var q := int(packet.get("q", 0))
	g.spawn_queue = [[0, q]] if q > 0 else []
	for b in packet.get("b", []):
		g.effects.add_beam(b[0], b[1], b[2], str(b[3]) if b.size() > 3 else "")


func _clear_enemies() -> void:
	for e in enemies.values():
		game.enemies.erase(e)
		e.queue_free()
	enemies.clear()
