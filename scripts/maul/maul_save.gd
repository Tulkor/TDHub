class_name MaulSave
extends RefCounted
## Spielstand für Shopping Maul (Einzelspiel und Koop), über save_game.gd verschlüsselt in user://saves/.
## Gespeichert wird immer zwischen zwei Leveln: im Countdown der Stand von jetzt, mitten im Level der Stand
## von dessen Beginn (maul_game.gd merkt ihn sich in _start_level). Geladen geht es mit dem Countdown weiter.
## Spieler und Tower nimmt der Koop-Stand (maul_sync.gd snapshot/apply_state) mit, dazu was nur der Host rechnet.
## Koop speichert der Host (save_coop) wie game.gd: Laden über „Spiel laden“ hostet die Sitzung, jeder bekommt
## beim Einstieg seine alte Spielernummer (Net._load_coop), maul_game.gd lädt den Stand beim Host.

const MODE := "shoppingmaul"
const RESUME_COUNTDOWN := 15.0


## Stand zwischen zwei Leveln, leer im Setup und nach dem Spielende.
static func capture(g: MaulGame) -> Dictionary:
	if g.phase == MaulGame.Phase.WAVE:
		return g.level_save
	if g.phase != MaulGame.Phase.COUNTDOWN:
		return {}
	return state(g)


static func state(g: MaulGame) -> Dictionary:
	var sync := MaulSync.new()
	sync.game = g
	var snap := sync.snapshot()
	sync.free()
	snap.phase = MaulGame.Phase.COUNTDOWN
	snap.countdown = maxf(g.countdown, RESUME_COUNTDOWN)
	snap.ts = 1.0
	snap.notes = {}
	var extra := []
	for p in g.players:
		extra.append({"xp_pot": p.xp_pot, "emma_timer": p.emma_timer, "level_kills": p.level_kills})
	var units := []
	for u in g.units:
		units.append({"id": u.unit_id, "p": u.owner_player, "home": [u.home.x, u.home.y], "pos": [u.pos.x, u.pos.y],
			"post": [u.post.x, u.post.y], "hp": u.hp, "energy": u.energy, "modules": u.modules, "kills": u.kills})
	return {
		"sync": snap,
		"players": extra,
		"units": units,
		"adapt_raw": g.adapt_raw.duplicate(),
		"streak": g.streak,
		"prev_budget": g.prev_budget,
		"play_time": g.play_time,
		"profile_time": roundi(g.play_time),
		"debug_used": g.debug_used,
		"xp_start": g.xp_start,
		"gold_pot": g.gold_pot,
	}


## Kurzinfo für die Liste „Spiel laden“.
static func meta_for(g: MaulGame) -> Dictionary:
	return {
		"map": "Shopping Maul",
		"wave": mini(g.levels_done + 1, g.levels.size()),
		"waves": g.levels.size(),
		"wave_label": "Level %d/%d",
		"lives": g.lives,
		"difficulty_name": str(MaulData.difficulty(g.difficulty).get("name", "")),
		"ascension": g.ascension,
		"shop": g.shop_of(g.local_player),
		"time": int(Time.get_unix_time_from_system()),
	}


## Einzelspiel speichern; dieselbe Partie überschreibt ihren Spielstand.
static func save(g: MaulGame) -> bool:
	var st := capture(g)
	if st.is_empty():
		return false
	if Session.save_id == "":
		Session.save_id = SaveGame.new_id()
	return SaveGame.write({"id": Session.save_id, "kind": "single", "mode": MODE, "meta": meta_for(g), "state": st})


## Koop (Host): die ganze Partie speichern, Spielernummern bleiben an den Spieler-IDs der Sitzung.
static func save_coop(g: MaulGame) -> bool:
	var st := capture(g)
	if st.is_empty():
		return false
	var names: Array = g.players.map(func(p): return p.name)
	var meta := meta_for(g)
	meta.players = names
	return SaveGame.write({"id": str(Net.session.get("id", SaveGame.new_id())), "kind": "coop", "mode": MODE,
		"meta": meta, "map": {"name": "Shopping Maul"}, "host_uid": Net.uid, "coop": Net.session.get("coop", []), "state": st})


## Stand in ein frisch aufgebautes Spiel (Karte, Board, HUD stehen, Phase SETUP).
static func apply(g: MaulGame, s: Dictionary) -> void:
	var snap: Dictionary = s.get("sync", {})
	var me: MaulGame.Player = g.players[g.local_player]
	var xp: int = me.xp
	var sync := MaulSync.new()
	sync.game = g
	sync.apply_state(snap)
	sync.free()
	# XP gehören dem Rechner (Profil), nicht dem Spielstand
	if not g.sandbox:
		me.xp = xp
	var extra: Array = s.get("players", [])
	for i in mini(extra.size(), g.players.size()):
		g.players[i].xp_pot = float(extra[i].get("xp_pot", 0.0))
		g.players[i].emma_timer = float(extra[i].get("emma_timer", 0.0))
	for d in s.get("units", []):
		var home := Vector2i(int(d.home[0]), int(d.home[1]))
		var u := g.spawn_unit(str(d.id), int(d.p), g.towers.get(home, null))
		u.home = home
		u.pos = Vector2(float(d.pos[0]), float(d.pos[1]))
		u.post = Vector2(float(d.post[0]), float(d.post[1]))
		u.hp = float(d.hp)
		u.energy = float(d.energy)
		u.modules = d.get("modules", {})
		u.kills = int(d.get("kills", 0))
	g.adapt_raw = s.get("adapt_raw", [1.0])
	g.streak = int(s.get("streak", 0))
	g.prev_budget = float(s.get("prev_budget", 0.0))
	g.play_time = float(s.get("play_time", 0.0))
	g.profile_time = int(s.get("profile_time", 0))
	g.debug_used = g.debug_used or bool(s.get("debug_used", false))
	g.xp_start = int(s.get("xp_start", me.xp))
	g.gold_pot = int(s.get("gold_pot", 0))
	g.level_save = state(g)
	g._refresh_paths()
	g._refresh_hud()
