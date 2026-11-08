class_name SaveGame
extends RefCounted
## Spielstände: der komplette Zustand eines Felds (auch mitten in einer Welle) als Dictionary,
## verschlüsselt in user://saves/*.gtd. Godot verschlüsselt mit AES-256 und prüft eine MD5-Summe,
## eine geänderte Datei lässt sich also nicht mehr laden.
##
## Datei: {version, kind ("single"/"multi"), id, meta {name, map, wave, waves, lives, difficulty, time, players},
##         state (single) oder players {uid: {name, state}} und map (multi), mode (TD-Modus, z. B. eevetd)}
## Modi auf game.gd (eeveTD) speichern ihren eigenen Stand über save_extra()/load_extra(d) unter "mode"
## und legen Tower über new_tower() an.

const DIR := "user://saves"
const EXT := ".gtd"
const VERSION := 1
const KEY := "GemTD:7f3c9a51-e0b4-4d2e-9c61-5b8d2a4f6e13"

const ENEMY_FIELDS := ["slow_factor", "slow_time", "poison_dps", "poison_time", "armor_reduction",
	"armor_reduction_time", "stun_time", "stacks", "stack_time", "stack_boom", "invulnerable_time"]


# --- Zustand eines Felds ---------------------------------------------------------

## Alles, was man braucht, um das Spiel genau so fortzusetzen. Leer, wenn das Spiel vorbei ist.
static func capture(game) -> Dictionary:
	if game.phase >= game.Phase.GAME_OVER:
		return {}
	var list: Array = game.all_towers()
	var ts := []
	for t in list:
		ts.append({"cell": t.cell, "id": t.tower_id, "tier": t.tier, "new": t.is_new, "kills": t.kills, "ep": t.ep,
			"dmg": t.total_damage, "cd": t.cooldown_left, "moves": t.moves_left, "on_rock": t.get_meta("on_rock", false),
			"owner": t.owner_player})
	var es := []
	for e in game.enemies:
		if e.dead:
			continue
		var d := {"group": e.group, "traveled": e.traveled, "hp": e.hp, "max_hp": e.max_hp, "id": e.net_id, "lane": e.lane, "score": e.score_value}
		for f in ENEMY_FIELDS:
			d[f] = e.get(f)
		es.append(d)
	var st := {
		"map": game.map.to_dict(),
		"difficulty": Session.difficulty,
		"ascension": game.ascension,
		"phase": game.phase,
		"wave_index": game.wave_index,
		"lives": game.lives,
		"score_mode": game.score_mode,
		"foreign_build": game.foreign_build,
		"score": game.score,
		"score_stats": game.score_stats.duplicate(true),
		"final_boss": game.final_boss.duplicate(),
		"gold": game.gold,
		"gold_frac": game._gold_frac,
		"rocks": game.rocks.keys(),
		"towers": ts,
		"round": game.round_towers.map(func(t): return list.find(t)),
		"path_start": game.round_path_start,
		"undo_gems": game.undo_gems.duplicate(true),
		"killed": game.enemies_killed,
		"leaks_per_wave": game.leaks_per_wave.duplicate(),
		"play_time": game.play_time,
		"spawn_queue": game.spawn_queue.duplicate(true),
		"spawn_timer": game.spawn_timer,
		"enemies": es,
		# pro Spieler; gold, round und undo_gems oben sind die von Spieler 0 (ältere Spielstände)
		"players": game.players.map(func(p): return {"name": p.name, "gold": p.gold, "gold_frac": p.gold_frac,
			"stage": p.stage, "round": p.round_towers.map(func(t): return list.find(t)), "undo_gems": p.undo_gems.duplicate(true),
			"extra_chance": p.extra_chance}),
		"next_enemy_id": game._next_enemy_id,
		"rng_seed": game.rng.seed,
		"rng_state": game.rng.state,
	}
	if game.rogue != null:
		st.rogue = game.rogue.to_dict()
	st.run_stats = game.run_stats.capture(list)
	st.debug_used = game.debug_used
	# Die Zeit bis hier bucht das Profil beim Verlassen (record_profile_abort), nach dem Laden zählt sie nicht noch einmal
	st.profile_time = roundi(game.play_time)
	if game.has_method("save_extra"):
		st.mode = game.save_extra()
	return st


## Zustand in ein frisch aufgebautes Spiel (Map, Board, HUD stehen schon) übernehmen.
static func apply(game, s: Dictionary) -> void:
	Session.difficulty = int(s.get("difficulty", Session.difficulty))
	game.ascension = int(s.get("ascension", 0))
	game.wave_index = int(s.get("wave_index", 0))
	game.lives = int(s.get("lives", game.lives))
	game.score_mode = bool(s.get("score_mode", false))
	Session.score_mode = game.score_mode
	game.foreign_build = bool(s.get("foreign_build", false))
	game.score = float(s.get("score", 0.0))
	game.score_stats = {}
	var stats: Dictionary = s.get("score_stats", {})
	for type in stats:
		var st: Dictionary = stats[type]
		game.score_stats[str(type)] = {"kills": int(st.get("kills", 0)), "points": float(st.get("points", 0.0)),
			"leaks": int(st.get("leaks", 0)), "lost": float(st.get("lost", 0.0))}
	var fb: Dictionary = s.get("final_boss", {})
	game.final_boss = {"damage": float(fb.get("damage", 0.0)), "hp": float(fb.get("hp", 0.0)),
		"kills": int(fb.get("kills", 0)), "points": float(fb.get("points", 0.0))}
	game.gold = int(s.get("gold", 0))
	game._gold_frac = float(s.get("gold_frac", 0.0))
	game.enemies_killed = int(s.get("killed", 0))
	game.leaks_per_wave = (s.get("leaks_per_wave", {}) as Dictionary).duplicate()
	game.play_time = float(s.get("play_time", 0.0))
	game._next_enemy_id = int(s.get("next_enemy_id", 1))
	game.rng.seed = int(s.get("rng_seed", game.rng.seed))
	game.rng.state = int(s.get("rng_state", game.rng.state))
	for c in s.get("rocks", []):
		game.rocks[c] = true
		game._occupy(c, true, true)
	var made := []
	for d in s.get("towers", []):
		if not Database.towers.has(str(d.id)):
			made.append(null)
			continue
		var t: Tower = game.new_tower() if game.has_method("new_tower") else Tower.new()
		t.is_new = bool(d.get("new", false))
		t.owner_player = int(d.get("owner", 0))
		game.board.add_child(t)
		t.setup(game, d.cell, str(d.id), int(d.tier))
		t.kills = int(d.get("kills", 0))
		# Ältere Spielstände ohne EP: ein Kill = EP eines normalen Kills
		t.set_ep(float(d.get("ep", t.kills * Leveling.kill_ep(t.level_profile(), null))))
		t.total_damage = float(d.get("dmg", 0.0))
		t.cooldown_left = float(d.get("cd", 0.0))
		t.moves_left = int(d.get("moves", 0))
		if d.get("on_rock", false):
			t.set_meta("on_rock", true)
		game._register(t)
		made.append(t)
	game._update_paths()
	game._update_auras()
	game.board.refresh_rocks()
	game.round_path_start = int(s.get("path_start", game.path_length))

	var phase := int(s.get("phase", game.Phase.BUILD))
	game.chance_level = game.chance_level_for(game.current_wave())
	# Ältere Spielstände haben nur einen Spieler, dessen Daten oben stehen
	var pls: Array = s.get("players", [{"gold": s.get("gold", 0), "gold_frac": s.get("gold_frac", 0.0), "stage": phase,
		"round": s.get("round", []), "undo_gems": s.get("undo_gems", [])}])
	game.players = []
	for i in pls.size():
		var pd: Dictionary = pls[i]
		var ps := PlayerState.new(i, str(pd.get("name", "")))
		ps.gold = int(pd.get("gold", 0))
		ps.gold_frac = float(pd.get("gold_frac", 0.0))
		ps.extra_chance = str(pd.get("extra_chance", ""))
		for ug in pd.get("undo_gems", []):
			if ug is Array and ug.size() == 2 and Database.towers.has(str(ug[0])):
				ps.undo_gems.append([str(ug[0]), int(ug[1])])
		for j in pd.get("round", []):
			if j >= 0 and j < made.size() and made[j] != null:
				ps.round_towers.append(made[j])
		# Wahlphase ohne Gems der Runde (z. B. kaputter Stand) heißt: wieder setzen
		ps.stage = clampi(int(pd.get("stage", phase)), game.Phase.BUILD, game.Phase.WAVE)
		if ps.stage == game.Phase.CHOOSE and ps.round_towers.is_empty():
			ps.stage = game.Phase.BUILD
		game.players.append(ps)
	game.acting = clampi(game.local_player, 0, game.players.size() - 1)
	Session.rogue = s.has("rogue")
	if s.has("rogue"):
		game.enable_rogue().from_dict(s.rogue)
		game._update_auras()
	game.run_stats.restore(s.get("run_stats", {}), made)
	game.debug_used = bool(s.get("debug_used", false))
	game.profile_time = int(s.get("profile_time", 0))
	if game.has_method("load_extra"):
		game.load_extra(s.get("mode", {}), made)
	if phase == game.Phase.WAVE:
		game.phase = game.Phase.WAVE
		game.spawn_queue = s.get("spawn_queue", []).duplicate(true)
		game.spawn_timer = float(s.get("spawn_timer", 0.5))
		for d in s.get("enemies", []):
			var g: Dictionary = d.get("group", {})
			var def: Dictionary = game.enemy_def(str(g.get("enemy", ""))) if game.has_method("enemy_def") else Database.enemies.get(str(g.get("enemy", "")), {})
			if def.is_empty():
				continue
			var e := Enemy.new()
			e.net_id = int(d.get("id", 0))
			e.lane = clampi(int(d.get("lane", 0)), 0, game.lane_paths.size() - 1)
			game.board.add_child(e)
			var lp: Dictionary = game.lane_paths[e.lane]
			e.setup(game, def, g, lp.air if def.get("flying", false) else lp.ground)
			game._apply_enemy_difficulty(e, g)
			game._apply_ascension(e)
			e.max_hp = float(d.get("max_hp", e.max_hp))
			e.hp = float(d.get("hp", e.hp))
			for f in ENEMY_FIELDS:
				if d.has(f):
					e.set(f, d[f])
			game.setup_score(e, g)
			if d.has("score"):
				e.score_value = float(d.score)
			e.place_on_path(float(d.get("traveled", 0.0)))
			game.enemies.append(e)
	else:
		game.phase = game.Phase.BUILD
		game._set_stage(game.pl().stage)
		if game.stage() == game.Phase.CHOOSE:
			game._select(game.round_towers[-1])
	game._refresh_hud()


## Kurzinfo für Listen.
static func meta_for(game, extra := {}) -> Dictionary:
	var m := {
		"map": game.map.name,
		"wave": mini(game.current_wave(), game.waves.size()),
		"waves": game.waves.size(),
		"lives": game.lives,
		"score_mode": game.score_mode,
		"score": roundi(game.score),
		"difficulty": Session.difficulty,
		"ascension": game.ascension,
		"time": int(Time.get_unix_time_from_system()),
	}
	m.merge(extra, true)
	return m


# --- Dateien ---------------------------------------------------------------------

static func new_id() -> String:
	return "%d_%06d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]


static func path_for(id: String) -> String:
	return DIR.path_join(id + EXT)


static var writes := 0  ## Zahl der geschriebenen Spielstände seit Programmstart (Profil: Run gespeichert?)


static func write(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	data["version"] = VERSION
	var f := FileAccess.open_encrypted_with_pass(path_for(str(data.id)), FileAccess.WRITE, KEY)
	if f == null:
		push_error("Spielstand konnte nicht geschrieben werden: %s" % FileAccess.get_open_error())
		return false
	f.store_var(data)
	f.close()
	writes += 1
	return true


## Leeres Dictionary, wenn die Datei fehlt, beschädigt oder verändert ist.
static func read(path: String) -> Dictionary:
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, KEY)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return {}
	return data


static func remove(id: String) -> void:
	DirAccess.remove_absolute(path_for(id))


## Alle Spielstände, neueste zuerst: [{id, kind, meta}]
static func list() -> Array:
	var out := []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for name in dir.get_files():
		if not name.ends_with(EXT):
			continue
		var d := read(DIR.path_join(name))
		if d.is_empty():
			continue
		out.append({"id": str(d.get("id", name.get_basename())), "kind": str(d.get("kind", "single")), "meta": d.get("meta", {})})
	out.sort_custom(func(a, b): return int(a.meta.get("time", 0)) > int(b.meta.get("time", 0)))
	return out
