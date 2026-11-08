extends "res://scripts/game/game.gd"
## YouTD (Vorbild: YouTD 2, MIT, github.com/Praytic/youtd2; Regeln in docs/youtd.md und data/youtd/rules.json).
##
## Kein Mazing: Gegner laufen einen festen Weg ("_"-Felder der Karte), Tower stehen auf den Bauflächen daneben
## und versperren nie etwas. Man erforscht mit Wissensbüchern Elemente; je nach Spielmodus würfelt jede Welle
## Tower der erforschten Elemente ins Lager (Zufall) oder man kauft sie frei (Bauen). Tower sammeln Erfahrung,
## tragen Items und lassen sich zur nächsten Stufe ihrer Familie aufwerten.
## Wellen kommen nach einem Timer (180 s vor der ersten, dann 15 s nach dem Ende der letzten), mit N auch früher;
## dann laufen mehrere Wellen gleichzeitig. Das Portal hat 100 % Leben.
## Am Ende werden die Punkte zu Spieler-XP (youtd_progress.gd), die über Partien hinweg bleibt.
##
## Tower-Fähigkeiten, Auren, Zauber und Wellen-Eigenschaften laufen in der portierten Laufzeit von YouTD 2
## (scripts/youtd/rt/, YtWorld hängt am Spielfeld): YoutdTower und YoutdEnemy haben je einen Kern (YtTower, YtCreep),
## der rechnet; Kopfgeld, Erfahrung und Itemfunde kommen von dort (drop_item, earn_gold).
## Items (YtItem mit Skript), Horadrischer Würfel (youtd_cube.gd), Baumeister (YtBuilder), Spielstand (youtd_save.gd)
## und Koop mit eigenem Weg je Spieler (youtd_coop.gd) seit Etappe 3.

## Der Weg liegt als Schlucht so tief unter den Bauflächen (Klippen, Board3D.path_depth).
const PATH_DEPTH := 0.6
const MODE_IDS := ["random_with_upgrades", "build", "totally_random"]

var rules: Dictionary = {}
var mode_index := 0          ## Index in rules.modes
var length_index := 1        ## Index in rules.lengths
var difficulty := 2          ## Index in rules.difficulties
var wave_seed := 0
var wave_rng := RandomNumberGenerator.new()   ## Wellen und Gegnerabstände
var roll_rng := RandomNumberGenerator.new()   ## Würfeln von Towern und Items

## Spieler: je einer in yt_players (YtPlayer, scripts/youtd/rt/yt_player.gd). Die Variablen hier meinen den
## gerade handelnden Spieler (acting), wie gold in game.gd.
var yt_players: Array = []
var tomes: int:
	get: return yp().tomes
	set(v): yp().tomes = v
var food_cap: int:
	get: return yp().food_cap
	set(v): yp().food_cap = v
var elements: Dictionary:
	get: return yp().elements
	set(v): yp().elements = v
var stash: Array:            ## gewürfelte Tower-IDs, die noch gebaut werden können
	get: return yp().stash
	set(v): yp().stash = v
var item_stash: Array:       ## YtItem im Lager
	get: return yp().item_stash
	set(v): yp().item_stash = v
var can_reroll: bool:        ## Startwurf wiederholen, bis der erste Tower steht
	get: return yp().can_reroll
	set(v): yp().can_reroll = v
var wisdom: Array:
	get: return yp().wisdom
var range_bonus: float:
	get: return yp().range_bonus
var tower_exp_bonus: float:
	get: return yp().tower_exp_bonus
var income_rate: float:      ## Faktor aufs Welleneinkommen (Tower-Fähigkeiten ändern ihn)
	get: return yp().income_rate
	set(v): yp().income_rate = v
var portal := 100.0          ## Leben des Portals in Prozent (gemeinsam)
var youtd_score := 0.0
var build_id := ""           ## Tower, der gerade gesetzt wird (lokal)
var picked_item := -1        ## Index im Item-Lager, das gerade eingelegt wird (lokal)
var log_lines: Array:        ## Meldungen für den lokalen Spieler (je Spieler in YtPlayer.notes)
	get: return yt_players[local_player].notes if local_player < yt_players.size() else []
var player_level_at_start := 0

## Wellen: nächste Welle, Zeit bis dahin, laufende Spawner und lebende Gegner je Welle
var next_wave := 1
var next_wave_in := 0.0
var spawners: Array = []     ## {wave, index, timer, lane}
var alive := {}              ## "Bahn:Welle" (alive_key) -> noch lebende oder kommende Gegner
var waves_done := 0
var xp_result := {}
var youtd_panel: YoutdPanel
var youtd_store: YoutdStore
var _item_row: HFlowContainer  ## Item-Plätze auf der Auswahlkarte
var scenery: EeveScenery
var world: YtWorld           ## Laufzeit von YouTD 2 (Takt, Geschosse, Effekte)
var _pending_load := {}      ## YouTD-Teil eines Spielstands, bis YtWorld steht
var _coop_count := 0         ## Spieler im Koop (0 = solo)
var _player_cfg := {}        ## Host: Baumeister und Weisheit der Mitspieler (Befehl player_setup)


func system_mode() -> String:
	return "youtd"


func _ready() -> void:
	UiTheme.use_skin(UiTheme.DRUID)
	FieldStyle.night = true
	path_depth = PATH_DEPTH
	rules = YoutdData.rules()
	Session.score_mode = false
	_coop_count = (Session.coop.get("names", []) as Array).size()
	super._ready()
	if map == null:
		return
	scenery = EeveScenery.add_to(self)
	world = YtWorld.new()
	board.add_child(world)
	if mirror:
		# Mitspieler: gerechnet wird beim Host, die Kerne hier liefern nur Werte fürs Infofenster
		world.process_mode = Node.PROCESS_MODE_DISABLED
	YtWorld.game = self
	world.add_child(YtWaveSpecial.new())
	_style_hud()
	if not _pending_load.is_empty():
		YoutdSave.restore(self, _pending_load)
		_pending_load = {}
	elif setup_done and waves.is_empty():
		# ohne Einstellungsfenster (Session.skip_setup, Screenshots): Standardwerte
		setup_done = false
		_apply_setup({"mode": mode_index, "length": length_index, "difficulty": difficulty, "wisdom": YoutdProgress.wisdom()})
	_refresh_hud()


func _exit_tree() -> void:
	super._exit_tree()
	UiTheme.use_skin(UiTheme.ARCADE)
	FieldStyle.night = false


func _style_hud() -> void:
	hud.title_label.text = "YouTD"
	hud.recipes_button.hide()
	hud.chance_value.get_parent().get_parent().hide()
	hud.path_value.get_parent().get_parent().hide()
	hud.pinned_panel.hide()
	hud.extra_chance_button.hide()
	# Linke Spalte (nächste Wellen) entfällt: die Wellen stehen im Tooltip des Wellen-Knopfs oben
	hud.left_col.hide()
	youtd_panel = YoutdPanel.new()
	youtd_panel.game = self
	# Tower- und Item-Lager fest unten links
	youtd_store = YoutdStore.new()
	youtd_store.game = self
	youtd_store.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	youtd_store.grow_vertical = Control.GROW_DIRECTION_BEGIN
	youtd_store.offset_left = 16
	youtd_store.offset_bottom = -16
	hud.root.add_child(youtd_store)
	hud.root.move_child(youtd_store, hud.recipe_book.get_index())
	# Fenster in der Mitte über den Lagern, aber unter Spielmenü und Endbildschirm
	hud.root.add_child(youtd_panel)
	hud.root.move_child(youtd_panel, hud.recipe_book.get_index())
	# Item-Plätze des gewählten Towers als Icons auf der Auswahlkarte (Ziehen ins Lager und zurück)
	_item_row = HFlowContainer.new()
	_item_row.add_theme_constant_override("h_separation", 3)
	_item_row.add_theme_constant_override("v_separation", 3)
	hud.info_left.add_child(_item_row)
	hud.info_left.move_child(_item_row, hud.info_body.get_index())


func mode_id() -> String:
	return str((rules.get("modes", []) as Array)[mode_index].get("id", "random_with_upgrades"))


func is_build_mode() -> bool:
	return mode_id() == "build"


func wave_count() -> int:
	return int((rules.get("lengths", []) as Array)[length_index].get("waves", 120))


# --- Einstellungen ---------------------------------------------------------------

func _make_setup_panel() -> Control:
	var setup := YoutdSetupPanel.new()
	setup.game = self
	return setup


func _make_waves() -> Array:
	return []


## Koop: die Solo-Karte einmal je Spieler (eigener Weg und Gebiet), ein gespeicherter Koop bringt seine Karte mit.
func _load_map() -> MapData:
	var m := super._load_map()
	return YoutdCoop.koop_map(m, _coop_count) if m != null else null


func _apply_variance() -> void:
	pass


func save_mode() -> String:
	return super.save_mode() if setup_done else "none"


# --- Koop (coop_sync.gd, youtd_coop.gd) ------------------------------------------------

func coop_commands() -> Array:
	return ["research", "roll", "build", "item_put", "item_take", "item_move", "item_use", "item_lock", "transmute", "oil_merge", "tower_merge",
			"next_wave", "player_setup"]


func new_tower() -> Tower:
	return YoutdTower.new()


func coop_snapshot() -> Dictionary:
	return YoutdCoop.snapshot(self)


func apply_coop_snapshot(d: Dictionary) -> void:
	var prev = YtWorld.use(self)
	YoutdCoop.apply(self, d)
	YtWorld.use(prev)


func coop_stats() -> Dictionary:
	return YoutdCoop.stats(self)


func apply_coop_stats(d: Dictionary) -> void:
	var prev = YtWorld.use(self)
	YoutdCoop.apply_stats(self, d)
	YtWorld.use(prev)


## Geschosse gehen mit den Gegnern an die Mitspieler (15 Mal pro Sekunde).
func coop_fast() -> Dictionary:
	return {"p": world.projectile_view.packet()} if world != null and world.projectile_view != null else {}


func apply_coop_fast(d: Dictionary) -> void:
	if world != null and world.projectile_view != null:
		world.projectile_view.set_remote(d.get("p", []))


## Mitspieler zeigen Gegner vom Host an: Aussehen aus Größe und Rasse ("youtd_champion:orc").
func enemy_def(id: String) -> Dictionary:
	if not id.begins_with("youtd_"):
		return super.enemy_def(id)
	var parts := id.trim_prefix("youtd_").split(":")
	return YoutdEnemy.def_for(parts[0], parts[1] if parts.size() > 1 else "orc", 1.0, 0.0, "")


# --- Spielstand (save_game.gd, youtd_save.gd) ----------------------------------------

func save_extra() -> Dictionary:
	return YoutdSave.capture(self)


## SaveGame.apply läuft vor dem Aufbau von YtWorld: den YouTD-Teil erst danach übernehmen (_ready).
func load_extra(d: Dictionary, _made: Array) -> void:
	_pending_load = d


func _execute(cmd: Dictionary) -> bool:
	match str(cmd.get("type", "")):
		"setup":
			if setup_done:
				return false
			_apply_setup(cmd)
			take_foreign_build(cmd)
			return true
		"research":
			return research(str(cmd.get("element", "")))
		"roll":
			return roll_start()
		"build":
			return build_tower(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"item_put":
			return put_item(tower_from_ref(cmd.get("tower", {})), stash_index(int(cmd.get("uid", -1))))
		"item_use":
			return consume_item(stash_index(int(cmd.get("uid", -1))))
		"item_move":
			return move_item(cmd.get("from", {}), cmd.get("to", {}))
		"item_lock":
			var i := stash_index(int(cmd.get("uid", -1)))
			if i < 0:
				return false
			(item_stash[i] as YtItem).toggle_horadric_lock()
			return true
		"transmute":
			return transmute(cmd.get("uids", []))
		"oil_merge":
			return merge_oils()
		"tower_merge":
			return merge_towers(str(cmd.get("rarity", "")))
		"item_take":
			var tt := tower_from_ref(cmd.get("tower", {}))
			if not tt is YoutdTower or tt.owner_player != acting:
				return false
			return take_item(tt, int(cmd.get("index", -1)))
		"next_wave":
			if not setup_done or phase >= Phase.GAME_OVER or next_wave > max_wave():
				return false
			_start_next_wave()
			return true
		"option":
			var t := tower_from_ref(cmd.get("tower", {}))
			var opts := tower_options(t)
			var i := int(cmd.get("index", -1))
			if i < 0 or i >= opts.size():
				return false
			var o: Dictionary = opts[i]
			if o.action != cmd.get("action") or o.id != cmd.get("id"):
				return false
			return _apply_option(t, o)
		"debug_place":
			return debug_place(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"place", "replace_rocks", "remove_rocks", "take_back", "move_trap":
			return false
	return super._execute(cmd)


func _apply_setup(cmd: Dictionary) -> void:
	mode_index = clampi(int(cmd.get("mode", 0)), 0, (rules.get("modes", []) as Array).size() - 1)
	length_index = clampi(int(cmd.get("length", 1)), 0, (rules.get("lengths", []) as Array).size() - 1)
	difficulty = clampi(int(cmd.get("difficulty", 2)), 0, (rules.get("difficulties", []) as Array).size() - 1)
	take_ascension(cmd)
	wave_seed = int(cmd.get("seed", rng.randi()))
	wave_rng.seed = wave_seed
	YtGlobals.synced_rng.seed = wave_seed * 17 + 3
	roll_rng.seed = wave_seed * 31 + 7
	Session.set_meta("youtd_choice", {"mode": mode_index, "length": length_index, "difficulty": difficulty,
			"builder": str(cmd.get("builder", ""))})
	var st: Dictionary = rules.get("start", {})
	portal = float(st.get("lives", 100))
	_make_players()
	# Baumeister und Weisheit: der Host im Befehl, Mitspieler über player_setup (ohne: keine, Level 0)
	for p in yt_players:
		_apply_player(p, cmd if p.id == local_player else _player_cfg.get(p.id, {"level": 0}))
	waves = []
	for i in wave_count():
		waves.append(_wave(i + 1))
	next_wave = 1
	next_wave_in = float(rules.get("time", {}).get("first_wave", 180))
	setup_done = true
	hud.setup_debug(0, waves.size())
	_note(tr("Erforsche ein Element mit Wissensbüchern, dann würfle deine ersten Tower.") if not is_build_mode()
			else tr("Erforsche ein Element mit Wissensbüchern, dann kaufe Tower im Baumenü."))
	_refresh_hud()


## Mitspieler wählen Baumeister und Weisheit selbst (aus ihrem Profil), auch bevor der Host startet. Nach dem Start
## gilt die Wahl noch, solange der Spieler nichts gebaut hat und die erste Welle nicht lief.
func execute(cmd: Dictionary) -> bool:
	if str(cmd.get("type", "")) != "player_setup":
		return super.execute(cmd)
	var pid := int(cmd.get("player", -1))
	if pid <= 0 or pid >= players.size() or _player_cfg.has(pid):
		return false
	_player_cfg[pid] = {"builder": str(cmd.get("builder", "")), "wisdom": (cmd.get("wisdom", []) as Array).duplicate(),
		"level": clampi(int(cmd.get("level", 0)), 0, 1000)}
	if setup_done and next_wave == 1 and pid < yt_players.size():
		if all_towers().any(func(t): return t.owner_player == pid):
			return false
		_apply_player(yt_players[pid], _player_cfg[pid])
		_refresh_hud()
	return true


func _wave(level: int) -> Dictionary:
	var w := YoutdWaves.generate(level, diff_rules(), wave_rng)
	w["type"] = {"mass": "Masse", "air": "Flieger", "boss": "Boss", "challenge_boss": "Boss", "challenge_mass": "Masse"}.get(w.size, "Boden")
	return w


## Ein YtPlayer je Spieler (solo einer).
func _make_players() -> void:
	if yt_players.size() == players.size():
		return
	yt_players = []
	for i in players.size():
		yt_players.append(YtPlayer.new(i))


## Der Spieler, dessen Befehl gerade läuft (sonst der lokale).
func yp() -> YtPlayer:
	if yt_players.is_empty():
		_make_players()
	return yt_players[clampi(acting, 0, yt_players.size() - 1)]


## Startwerte eines Spielers: Gold, Bücher, Food, Baumeister, dann Weisheits-Boni (mit dem Faktor des Baumeisters).
func _apply_player(p: YtPlayer, cfg: Dictionary) -> void:
	var st: Dictionary = rules.get("start", {})
	players[p.id].gold = int(st.get("gold", 70))
	p.tomes = int(st.get("tomes", 90))
	p.food_cap = int(st.get("food", 55))
	p.interest_rate = float(rules.get("income", {}).get("interest", 0.05))
	for el in YoutdData.elements():
		p.elements[el] = 0
	p.level_at_start = int(cfg.get("level", YoutdProgress.level()))
	var bid := str(cfg.get("builder", ""))
	if bid != "" and not YoutdProgress.builder_open(bid, p.level_at_start):
		bid = ""
	p.set_builder(bid)
	_apply_wisdom(p, cfg.get("wisdom", []))


## Weisheits-Boni anwenden. Stärke = Faktor des Baumeisters (1) + Synergie + 0,1 % je nicht verteiltem Spielerlevel
## (Pfad des Aufstiegs).
func _apply_wisdom(p: YtPlayer, list: Array) -> void:
	var allowed := YoutdProgress.wisdom_points(p.level_at_start)
	p.wisdom = list.slice(0, allowed)
	var all: Array = rules.get("wisdom", [])
	var by_id := {}
	for w in all:
		by_id[w.id] = w
	var strength := p.builder_wisdom_multiplier
	for id in p.wisdom:
		var w: Dictionary = by_id.get(id, {})
		strength += float(w.get("strength", 0.0))
		if w.has("strength_per_free_level"):
			var spent: int = p.wisdom.size() * int(rules.get("player", {}).get("levels_per_wisdom", 6))
			strength += float(w.strength_per_free_level) * maxi(0, p.level_at_start - spent)
	for id in p.wisdom:
		var w: Dictionary = by_id.get(id, {})
		for m in w.get("mods", []):
			p.wisdom_mods[m[0]] = float(p.wisdom_mods.get(m[0], 0.0)) + float(m[1]) * strength
		p.add_tomes(floori(float(w.get("tomes", 0)) * strength))
		p.modify_food_cap(floori(float(w.get("food", 0)) * strength))
		modify_portal(float(w.get("lives", 0)) * strength)
		p.tower_exp_bonus += float(w.get("tower_exp", 0)) * strength
		p.range_bonus += float(w.get("range", 0)) * strength
		p.element_max_bonus += int(w.get("element_max", 0))
		p.tower_max_bonus += int(w.get("tower_max", 0))


## Portal-Leben ändern (Prozentpunkte); bei 0 ist das Spiel verloren.
func modify_portal(amount: float) -> void:
	portal = maxf(0.0, portal + amount)
	if portal <= 0.0 and setup_done and not Session.debug_immortal:
		_finish(Phase.GAME_OVER)


func max_element_level() -> int:
	return int(rules.get("elements", {}).get("max_level", 15)) + yp().element_max_bonus


func max_tower_level() -> int:
	return yp().get_max_tower_level()


func max_wave() -> int:
	return waves.size()


# --- Elemente, Würfeln, Bauen ------------------------------------------------------

func research_cost(el: String) -> int:
	return int(rules.get("elements", {}).get("research_base", 20)) + int(elements.get(el, 0))


func can_research(el: String) -> bool:
	return setup_done and elements.has(el) and int(elements[el]) < max_element_level() and tomes >= research_cost(el)


func research(el: String) -> bool:
	if not can_research(el):
		return false
	tomes -= research_cost(el)
	elements[el] = int(elements[el]) + 1
	_refresh_hud()
	return true


func any_element() -> bool:
	return elements.values().any(func(v): return int(v) > 0)


## Startwurf (Zufallsmodi): 6 Tower der erforschten Elemente; wiederholbar, bis der erste Tower steht.
func roll_start() -> bool:
	if is_build_mode() or not can_reroll or not any_element():
		return false
	stash = YoutdRoll.with_count(self, int(rules.get("start", {}).get("tower_rolls", 6)))
	_note(tr("Gewürfelt: %s") % ", ".join(stash.map(func(id): return YoutdData.tower(id).get("name", id))))
	_refresh_hud()
	return true


func food_used() -> int:
	var n := 0
	for t in towers.values():
		if t is YoutdTower and t.owner_player == acting:
			n += YoutdData.food_cost(t.yid)
	return n


## Warum Tower id gerade nicht gebaut werden kann ("" = geht). from: Tower, der aufgewertet wird.
func build_reason(id: String, from: YoutdTower = null) -> String:
	var t := YoutdData.tower(id)
	if t.is_empty():
		return tr("unbekannt")
	var cost := int(t.cost) - (int(YoutdData.tower(from.yid).get("cost", 0)) if from != null else 0)
	if is_build_mode() or from != null:
		var el := str(t.element)
		var need := YoutdData.required_element_level(id)
		if int(elements.get(el, 0)) < need:
			return tr("%s %d nötig") % [YoutdData.element_name(el), need]
		var wave := YoutdData.required_wave(id, is_build_mode())
		if current_wave() < wave:
			return tr("ab Welle %d") % wave
	if gold < cost:
		return tr("zu wenig Gold")
	if tomes < YoutdData.tome_cost(id, is_build_mode()):
		return tr("zu wenig Wissensbücher")
	var food := YoutdData.food_cost(id) - (YoutdData.food_cost(from.yid) if from != null else 0)
	if food_used() + food > food_cap:
		return tr("zu wenig Food")
	return ""


## Tower, die man gerade bauen kann: im Baumodus alle der erforschten Elemente (Stufe 1 jeder Familie), sonst das Lager.
func buildable() -> Array:
	if not is_build_mode():
		return stash.duplicate()
	var out := []
	var all := YoutdData.towers()
	for id in all:
		var t: Dictionary = all[id]
		if int(t.tier) == 1 and int(elements.get(str(t.element), 0)) > 0:
			out.append(id)
	out.sort_custom(func(a, b): return int(all[a].cost) < int(all[b].cost))
	return out


func can_build(a: Vector2i) -> bool:
	return can_place(a)


## Tower stehen nur auf Bauflächen und versperren nichts (kein Mazing).
## Kann Spieler pid bei Anker a bauen (YtBuildSpace, Item-Skripte)?
func can_place_for(a: Vector2i, pid: int) -> bool:
	var before := acting
	acting = pid
	var ok := can_place(a)
	acting = before
	return ok


func can_place(a: Vector2i, any_zone := false) -> bool:
	if not setup_done or phase >= Phase.GAME_OVER:
		return false
	for c in Board3D.footprint(a):
		if not map.is_buildable(c) or occupied.has(c) or not (any_zone or may_build_for(c)):
			return false
	# Maverick: Tower dürfen nicht direkt nebeneinander stehen
	if not yp().get_builder().get_allow_adjacent_towers():
		for c in Board3D.footprint(a - Vector2i.ONE, 4):
			if occupied.has(c):
				return false
	return true


func _occupy(a: Vector2i, on: bool, _solid: bool) -> void:
	for c in Board3D.footprint(a):
		if on:
			occupied[c] = a
		else:
			occupied.erase(c)


func build_tower(id: String, a: Vector2i) -> bool:
	if not can_place(a) or build_reason(id) != "":
		return false
	if not is_build_mode() and not stash.has(id):
		return false
	var t := _new_tower(id, a)
	gold -= int(YoutdData.tower(id).cost)
	t.spent = int(YoutdData.tower(id).cost)
	tomes -= YoutdData.tome_cost(id, is_build_mode())
	if not is_build_mode():
		stash.erase(id)
	can_reroll = false
	if t.owner_player == local_player and not stash.has(build_id) and not is_build_mode():
		build_id = ""
	_refresh_hud()
	return true


func _new_tower(id: String, a: Vector2i) -> YoutdTower:
	var t := YoutdTower.new()
	t.game = self
	t.cell = a
	t.owner_player = acting
	board.add_child(t)
	t.set_youtd(id)
	_register(t)
	run_stats.built(t, "build", current_wave())
	Sfx.play("place")
	return t


## Debug: Tower id ohne Kosten und Voraussetzungen setzen.
func debug_place(id: String, a: Vector2i) -> bool:
	if not can_place(a) or YoutdData.tower(id).is_empty():
		return false
	_new_tower(id, a)
	_refresh_hud()
	return true


# --- Items -----------------------------------------------------------------------

## Item i aus dem Lager in Tower t legen: Öle wirken sofort dauerhaft, normale Items belegen einen Platz,
## Verbrauchsgegenstände lassen sich nicht einlegen (consume_item).
func put_item(t: Tower, i: int) -> bool:
	if not t is YoutdTower or i < 0 or i >= item_stash.size() or t.owner_player != acting:
		return false
	var yt := t as YoutdTower
	var it: YtItem = item_stash[i]
	if it.is_consumable() or yt.core == null:
		return false
	if not it.pickup(yt.core):
		return false
	if picked_item == i:
		picked_item = -1
	_refresh_hud()
	return true


## Item k aus Tower t zurück ins Lager.
func take_item(t: YoutdTower, k: int) -> bool:
	if t == null or k < 0 or k >= t.items.size():
		return false
	var it: YtItem = t.items[k]
	it.drop()
	it.fly_to_stash(0.0)
	_refresh_hud()
	return true


## Verbrauchsgegenstand i aus dem Lager benutzen (wirkt auf den Spieler, z. B. Food, Bücher, Leben).
func consume_item(i: int) -> bool:
	if i < 0 or i >= item_stash.size():
		return false
	var it: YtItem = item_stash[i]
	if not it.is_consumable():
		return false
	stash_remove(it)
	it.consume()
	_note(tr("Benutzt: %s") % it.get_display_name())
	it.queue_free()
	if picked_item >= item_stash.size():
		picked_item = -1
	_refresh_hud()
	return true


## Ort eines Items im Inventar (InvSlot): {"stash": uid} (-1 = freies Lagerfeld) oder {"tower": ref, "slot": k}
## (k über den belegten Plätzen oder -1 = freier Platz). Ergebnis {it, tower, slot, stash} oder {} wenn ungültig.
func _inv_place(loc: Dictionary) -> Dictionary:
	if loc.has("stash"):
		var uid := int(loc.stash)
		var i := stash_index(uid) if uid >= 0 else -1
		if uid >= 0 and i < 0:
			return {}
		return {"it": item_stash[i] if i >= 0 else null, "tower": null, "slot": -1, "stash": i}
	var t := tower_from_ref(loc.get("tower", {}))
	if not t is YoutdTower or t.owner_player != acting or (t as YoutdTower).core == null:
		return {}
	var yt := t as YoutdTower
	var k := int(loc.get("slot", -1))
	return {"it": yt.items[k] if k >= 0 and k < yt.items.size() else null, "tower": yt, "slot": k, "stash": -1}


## Item an Platz idx der Liste schieben (für Tausch: beide Items landen auf dem Platz des anderen).
static func _place_at(list: Array, it, idx: int) -> void:
	list.erase(it)
	list.insert(clampi(idx, 0, list.size()) if idx >= 0 else list.size(), it)


## Item von einem Inventarort zum anderen wie in WC3: auf ein anderes Item = tauschen, auf einen freien Platz =
## verschieben. Öle wirken beim Einlegen sofort und werden verbraucht, Verbrauchsgegenstände gehen nicht in Tower.
func move_item(from: Dictionary, to: Dictionary) -> bool:
	var a := _inv_place(from)
	var b := _inv_place(to)
	if a.is_empty() or b.is_empty() or a.it == null or a.it == b.it:
		return false
	var it: YtItem = a.it
	var other: YtItem = b.it
	if b.tower == null:
		if a.tower == null:
			# im Lager umsortieren
			_place_at(item_stash, it, b.stash)
			if other != null:
				_place_at(item_stash, other, a.stash)
		elif other == null or other.is_consumable() or other.is_oil():
			return take_item(a.tower, a.slot)
		else:
			_swap_stash_tower(other, a.tower, a.slot)
	else:
		var t: YoutdTower = b.tower
		if it.is_consumable():
			return false
		if a.tower == null:
			if it.is_oil() or other == null:
				return put_item(t, a.stash)
			_swap_stash_tower(it, t, b.slot)
		elif a.tower == t:
			if other == null:
				_place_at(t.items, it, -1)
			else:
				var k: int = a.slot
				t.items[k] = other
				t.items[b.slot] = it
		elif other == null:
			if not t.core.have_item_space():
				return false
			it.drop()
			it.pickup(t.core)
		else:
			var src: YoutdTower = a.tower
			it.drop()
			other.drop()
			it.pickup(t.core)
			other.pickup(src.core)
			_place_at(t.items, it, b.slot)
			_place_at(src.items, other, a.slot)
	if youtd_store != null:
		youtd_store.items_dirty()
	_refresh_hud()
	return true


## Lager-Item s gegen das Item auf Platz k von Tower t tauschen, beide nehmen den Platz des anderen ein.
func _swap_stash_tower(s: YtItem, t: YoutdTower, k: int) -> void:
	var si := item_stash.find(s)
	var old: YtItem = t.items[k]
	old.drop()
	s.pickup(t.core)
	_place_at(t.items, s, k)
	old.fly_to_stash(0.0)
	_place_at(item_stash, old, si)


## Horadrischer Würfel: Items uids aus dem Lager des handelnden Spielers nach dem passenden Rezept verwandeln.
func transmute(uids: Array) -> bool:
	var list := []
	for uid in uids:
		var i := stash_index(int(uid))
		if i < 0 or list.has(item_stash[i]):
			return false
		list.append(item_stash[i])
	var r := YoutdCube.current_recipe(yp(), list)
	if r.is_empty():
		return false
	var res := YoutdCube.results(r, list, YtGlobals.synced_rng)
	if (res.items as Array).is_empty():
		return false
	for it in list:
		stash_remove(it)
		it.queue_free()
	var names := []
	for id in res.items:
		var it := YtItem.make(int(id), yp())
		if it != null:
			stash_add(it)
			names.append(it.get_display_name())
	var luck := int(res.luck)
	var text := tr("Würfel: %s") % ", ".join(names)
	if luck < 0:
		text += " " + tr("(Pech: %d Level)") % luck
	elif luck > 0:
		text += " " + tr("(Glück: +%d Level)") % luck
	_note(text)
	_refresh_hud()
	return true


## Sichtbare Buffs und Debuffs einer Einheit als Text (Buff-Hinweise aus data/youtd/texte.json), mit Stapeln.
static func buff_lines(u: YtUnit) -> Array:
	var out := []
	if u == null or not is_instance_valid(u):
		return out
	for b in u.get_buff_list():
		if b.is_hidden():
			continue
		var text := b.get_tooltip_text()
		if text == "" or text == b.get_buff_type_name() or text.begins_with("DEBUG"):
			continue
		if b.get_displayed_stacks() > 1:
			text += " ×%d" % b.get_displayed_stacks()
		if not out.has(text):
			out.append(text)
	return out


## Öle im Lager des handelnden Spielers, die „Öle kombinieren“ zusammenlegen kann (je Seltenheit 4 → 1 höher).
func can_merge_oils() -> bool:
	var r := YoutdCube.recipe("distill")
	var oils := item_stash.filter(func(it): return it.get_type_name() == "oil")
	for rarity in YoutdCube.RARITIES.size():
		if not YoutdCube.autofill_rarity(r, oils, rarity).is_empty():
			return true
	return false


## Alle Öle so oft wie möglich destillieren (Würfel-Rezept „Destillieren“), von gewöhnlich aufwärts, damit neue
## Öle gleich weiter zusammengelegt werden.
func merge_oils() -> bool:
	var r := YoutdCube.recipe("distill")
	var done := 0
	for rarity in YoutdCube.RARITIES.size():
		for _guard in 100:
			var oils := item_stash.filter(func(it): return it.get_type_name() == "oil")
			var list := YoutdCube.autofill_rarity(r, oils, rarity)
			if list.is_empty() or not transmute(list.map(func(it): return it.get_uid())):
				break
			done += 1
	return done > 0


## Seltenheit, die „6 → 1“ gerade zusammenlegen kann (die niedrigste mit genug Towern im Lager): {from, to} oder {}.
func merge_option() -> Dictionary:
	if is_build_mode():
		return {}
	var need := int(rules.get("merge", {}).get("count", 6))
	for ri in YoutdRoll.RARITIES.size() - 1:
		var r: String = YoutdRoll.RARITIES[ri]
		if stash.filter(func(id): return str(YoutdData.tower(id).get("rarity", "")) == r).size() >= need:
			return {"from": r, "to": YoutdRoll.RARITIES[ri + 1]}
	return {}


## 6 Tower der Seltenheit rarity aus dem Lager (die ältesten) werden zu 1 zufälligen Tower der nächsten Seltenheit.
func merge_towers(rarity: String) -> bool:
	var ri := YoutdRoll.RARITIES.find(rarity)
	if is_build_mode() or ri < 0 or ri >= YoutdRoll.RARITIES.size() - 1:
		return false
	var need := int(rules.get("merge", {}).get("count", 6))
	var pick := stash.filter(func(id): return str(YoutdData.tower(id).get("rarity", "")) == rarity).slice(0, need)
	if pick.size() < need:
		return false
	var id := YoutdRoll.merge_result(self, pick, YoutdRoll.RARITIES[ri + 1])
	if id == "":
		return false
	var list: Array = stash
	for p in pick:
		list.erase(p)
	list.append(id)
	if pick.has(build_id):
		build_id = ""
	_note(tr("6 → 1: %s") % str(YoutdData.tower(id).get("name", id)))
	_refresh_hud()
	return true


## Name eines Items mit Ladungen, z. B. „Strange Item (3)“.
func item_label(it: YtItem) -> String:
	return it.get_display_name() + (" (%d)" % it.get_charges() if it.uses_charges() else "")


## Platz des Items uid im Lager des handelnden Spielers (-1 = nicht da).
func stash_index(uid: int) -> int:
	for i in item_stash.size():
		if (item_stash[i] as YtItem).get_uid() == uid:
			return i
	return -1


## Item ins Lager seines Spielers (YtItem.fly_to_stash).
func stash_add(it: YtItem) -> void:
	var p: YtPlayer = it.get_player()
	if not p.item_stash.has(it):
		p.item_stash.append(it)
	it.place = YtItem.Place.STASH
	if youtd_store != null:
		youtd_store.items_dirty()


func stash_remove(it: YtItem) -> void:
	it.get_player().item_stash.erase(it)
	it.place = YtItem.Place.NONE
	if youtd_store != null:
		youtd_store.items_dirty()


func stash_full(p: YtPlayer) -> bool:
	return p.item_stash.size() >= int(rules.get("items", {}).get("stash_max", 40))


## Itemfund (YtUnit._killed_by_unit hat die Chance schon gewürfelt): Item nach Welle und Qualität ins Lager.
func drop_item(creep: YtCreep, quality: float, owner: YtPlayer = null) -> void:
	drop_item_id(creep, YoutdRoll.item(self, creep.get_spawn_level(), maxf(0.0, quality)), owner)


func drop_item_id(_creep: YtCreep, id: String, owner: YtPlayer = null) -> void:
	if owner == null:
		owner = YtPlayer.of(0)
	if id == "" or YoutdData.item(id).is_empty() or stash_full(owner):
		return
	var it := YtItem.make(int(id), owner)
	if it == null:
		return
	stash_add(it)
	_note(tr("Item gefunden: %s (%s)") % [it.get_display_name(), YoutdData.rarity_name(str(YoutdData.item(id).get("rarity", "")))], owner.id)


# --- Wellen ----------------------------------------------------------------------

func _enter_build() -> void:
	phase = Phase.BUILD


func current_wave() -> int:
	return maxi(next_wave - 1, 0)


func is_wave_running() -> bool:
	return phase == Phase.WAVE


func _process(delta: float) -> void:
	_ux_tick()
	if phase < Phase.GAME_OVER:
		play_time += delta / maxf(Engine.time_scale, 0.001)
	_update_hover()
	if mirror and world != null and world.projectile_view != null:
		world.projectile_view.remote_step(delta)
	if not setup_done or phase >= Phase.GAME_OVER or mirror:
		return
	# Timer läuft nur, wenn gerade keine Welle mehr kommt oder lebt (wie im Original nach dem Ende der Welle)
	if alive.is_empty() and next_wave <= max_wave():
		var before := ceili(next_wave_in)
		next_wave_in -= delta
		if next_wave_in <= 0.0:
			_start_next_wave()
		elif ceili(next_wave_in) != before and youtd_panel != null:
			youtd_panel.refresh_timer()
	_process_wave(delta)


## Bahnen, auf denen Gegner kommen: solo eine, im Koop eine je Spieler (Bahn des Spielers aus der Karte).
func wave_lanes() -> Array:
	var out := []
	for p in yt_players:
		out.append(p.id)
	return out


## Index in lane_paths für Spieler pid (Bahn mit player == pid, sonst die erste).
func lane_index(pid: int) -> int:
	for i in map.lane_count():
		if map.lane_player(i) == pid:
			return i
	return 0


## Schlüssel in alive: Welle und Bahn (Spieler).
static func alive_key(lane: int, level: int) -> String:
	return "%d:%d" % [lane, level]


func _start_next_wave() -> void:
	if next_wave > max_wave():
		return
	if next_wave > 1:
		autosave()  # Stand vor der Welle: „Weiterspielen“ im Hub setzt hier fort
	var w: Dictionary = waves[next_wave - 1]
	wave_index = next_wave - 1
	for lane in wave_lanes():
		spawners.append({"wave": w, "index": 0, "timer": 0.5, "lane": lane})
		alive[alive_key(lane, int(w.level))] = (w.creeps as Array).size()
	next_wave += 1
	next_wave_in = float(rules.get("time", {}).get("between_waves", 15))
	phase = Phase.WAVE
	wave_live = {"gone_hp": 0.0, "gone_dealt": 0.0, "killed": 0, "leaked": 0}
	Sfx.play("wave_start")
	_refresh_hud()


func _process_wave(delta: float) -> void:
	for s in spawners.duplicate():
		s.timer -= delta
		while s.timer <= 0.0 and s.index < (s.wave.creeps as Array).size():
			_spawn_youtd(s.wave, str(s.wave.creeps[s.index]), int(s.get("lane", 0)))
			s.index += 1
			s.timer += YoutdWaves.creep_delay(str(s.wave.size), wave_rng)
		if s.index >= (s.wave.creeps as Array).size():
			spawners.erase(s)


func _spawn_youtd(w: Dictionary, size_id: String, lane := 0) -> void:
	var e := YoutdEnemy.new()
	e.net_id = _next_enemy_id
	_next_enemy_id += 1
	board.add_child(e)
	var lp: Dictionary = lane_paths[lane_index(lane)]
	var hp_factor := 1.0
	if ascension > 0:
		# Aufstieg: Leben und Rüstung der Welle (Kinder aus Eigenschaften erben die Leben ihrer Eltern)
		var m := ascension_mods()
		w = w.duplicate()
		w.armor = float(w.armor) * float(m.armor) + float(m.armor_add)
		hp_factor = float(m.hp)
	e.setup_youtd(self, w, size_id, lp.air if size_id == "air" else lp.ground, hp_factor, -1.0, lane)
	e.final_boss = int(w.level) == max_wave() and size_id.contains("boss")
	enemies.append(e)
	if e.boss:
		Sfx.play("boss")


## Gegner aus einer Eigenschaft (Brut, Nekromant, Trächtig): gehört zur Welle level und zur Bahn des Spielers,
## die Stelle setzt das Skript.
func spawn_yt_creep(size: YtCreepSize.enm, armor_type: YtArmorType.enm, race: YtCreepCategory.enm, health: float, armor: float,
		level: int, player: YtPlayer = null) -> YtCreep:
	if phase >= Phase.GAME_OVER:
		return null
	var lane: int = player.id if player != null else 0
	var size_id := YtCreepSize.convert_to_string(size).replace(" ", "_")
	var w := {"level": level, "race": YtCreepCategory.convert_to_string(race), "armor": armor,
			"armor_type": YtArmorType.convert_to_string(armor_type), "hp": health, "specials": []}
	var e := YoutdEnemy.new()
	e.net_id = _next_enemy_id
	_next_enemy_id += 1
	board.add_child(e)
	var lp: Dictionary = lane_paths[lane_index(lane)]
	e.setup_youtd(self, w, size_id, lp.air if size_id == "air" else lp.ground, 1.0, health, lane)
	enemies.append(e)
	var k := alive_key(lane, level)
	alive[k] = int(alive.get(k, 0)) + 1
	return e.core


func queued_hp() -> float:
	var total := 0.0
	for s in spawners:
		var w: Dictionary = s.wave
		for i in range(int(s.index), (w.creeps as Array).size()):
			total += float(w.hp) * float(rules.get("sizes", {}).get(str(w.creeps[i]), {}).get("hp", 1.0))
	return total


func idle_speed_factor() -> float:
	return 1.0


## Punkte für einen Gegner (Creep.get_score): Schadensanteil × (Welle/8 + 1) × Schwierigkeit × Modus × Länge × Größe.
func creep_score(e: YoutdEnemy) -> float:
	if e.core == null:
		return 0.0
	var m: Dictionary = (rules.get("modes", []) as Array)[mode_index]
	var l: Dictionary = (rules.get("lengths", []) as Array)[length_index]
	var settings := float(diff_rules().get("score", 1.0)) * float(m.get("score", 1.0)) * float(l.get("score", 1.0))
	var size := float(rules.get("sizes", {}).get(e.creep_size, {}).get("score", 1))
	return e.damage_done() * (int(e.level / 8) + 1) * settings * size


## Punkte gehören dem Spieler, auf dessen Weg der Gegner lief (zusammen in youtd_score).
func _add_score(e: YoutdEnemy) -> void:
	var pts := creep_score(e)
	youtd_score += pts
	if not yt_players.is_empty():
		yt_players[clampi(e.lane, 0, yt_players.size() - 1)].score += pts


## Kopfgeld, Erfahrung und Items hat der Kern schon verteilt (YtUnit._accept_kill); hier Punkte und Wellenstand.
func on_enemy_killed(e: Enemy) -> void:
	enemies_killed += 1
	var ye := e as YoutdEnemy
	if ye != null:
		_add_score(ye)
		_creep_gone(ye)
	_remove_enemy(e)
	_refresh_hud()


## Durchgelaufen: Portalschaden 2,5 % × Größenfaktor × (1 − Schadensanteil^5) (Boss ^4), Challenges nichts,
## der Endboss alles. Punkte gibt es anteilig für den Schaden.
func on_enemy_leaked(e: Enemy) -> void:
	var ye := e as YoutdEnemy
	if ye != null:
		var dmg := 0.0
		if int(ye.level) == max_wave() and ye.final_boss:
			dmg = 100.0
		elif not ye.creep_size.begins_with("challenge"):
			var p := 4.0 if ye.creep_size == "boss" else 5.0
			dmg = 2.5 * float(rules.get("sizes", {}).get(ye.creep_size, {}).get("portal", 1)) * (1.0 - pow(ye.damage_done(), p))
			if ye.core != null:
				dmg *= ye.core.get_portal_damage_multiplier()
		_add_score(ye)
		leaks_per_wave[ye.level - 1] = int(leaks_per_wave.get(ye.level - 1, 0)) + 1
		if dmg > 0.0:
			_note(tr("%s durchgelaufen: −%s %% Leben") % [ye.display_name(), TowerStats.num(dmg)])
			Sfx.play("leak")
		_creep_gone(ye)
		_remove_enemy(e)
		modify_portal(-dmg)
	else:
		_remove_enemy(e)
	_refresh_hud()


## Ein Gegner der Welle ist weg; ist die Welle auf seiner Bahn leer: Einkommen, Bücher, neue Tower für den Spieler.
func _creep_gone(e: YoutdEnemy) -> void:
	var k := alive_key(e.lane, e.level)
	if not alive.has(k):
		return
	alive[k] = int(alive[k]) - 1
	if int(alive[k]) > 0:
		return
	alive.erase(k)
	_wave_finished(e.level, e.lane)


func _wave_finished(lvl: int, lane := 0) -> void:
	var before := acting
	acting = clampi(lane, 0, yt_players.size() - 1)
	var p := yp()
	var inc: Dictionary = rules.get("income", {})
	var upkeep := floori((int(inc.get("base", 20)) + lvl * int(inc.get("per_level", 2))) * p.income_rate)
	var interest := floori(minf(gold * p.interest_rate, float(inc.get("interest_max", 1000))))
	gold += upkeep + interest
	p.add_tomes(int(inc.get("tomes", 8)))
	p.get_builder().apply_wave_finished_effect(p)
	_note(tr("Welle %d geschafft: +%d Gold, +%d Zinsen, +%d Bücher") % [lvl, upkeep, interest, int(inc.get("tomes", 8))])
	if not is_build_mode():
		var rolled := YoutdRoll.per_wave(self)
		stash.append_array(rolled)
		if not rolled.is_empty():
			_note(tr("Neue Tower: %s") % ", ".join(rolled.map(func(id): return YoutdData.tower(id).get("name", id))))
	acting = before
	# Welle geschafft, wenn sie auf keiner Bahn mehr läuft
	for k in alive:
		if str(k).ends_with(":%d" % lvl):
			_refresh_hud()
			return
	for sp in spawners:
		if int(sp.wave.level) == lvl:
			_refresh_hud()
			return
	waves_done = maxi(waves_done, lvl)
	run_stats.wave_done(all_towers(), lvl, int(leaks_per_wave.get(lvl - 1, 0)), 0)
	if lvl >= max_wave() and alive.is_empty() and spawners.is_empty():
		_finish(Phase.VICTORY)
		return
	if alive.is_empty() and spawners.is_empty():
		phase = Phase.BUILD
		next_wave_in = float(rules.get("time", {}).get("between_waves", 15))
	_refresh_hud()


func _remove_enemy(e: Enemy) -> void:
	var ye := e as YoutdEnemy
	if ye != null and ye.core != null and is_instance_valid(ye.core) and ye.core.is_inside_tree():
		ye.core.remove_from_game()
	wave_live.gone_hp += e.max_hp
	wave_live.gone_dealt += clampf(e.max_hp - e.hp, 0.0, e.max_hp)
	if e.hp <= 0.0:
		wave_live.killed += 1
	else:
		wave_live.leaked += 1
	enemies.erase(e)
	e.queue_free()


func _finish(p: Phase) -> void:
	if phase >= Phase.GAME_OVER:
		return
	phase = p
	drop_autosave()
	if not debug_run():
		xp_result = YoutdProgress.record(my_score(), waves_done, p == Phase.VICTORY, enemies_killed)
	record_profile(p == Phase.VICTORY)
	Engine.time_scale = 1.0
	lives = ceili(portal)
	hud.show_game_over(p == Phase.VICTORY, mini(waves_done + 1, waves.size()), waves.size(), lives, enemies_killed, 0, null, {})
	var text := tr("Welle %d von %d · Portal %s %%\nGegner besiegt: %d\nPunkte: %d") % [waves_done, waves.size(), TowerStats.num(portal), enemies_killed, roundi(my_score())]
	if not xp_result.is_empty():
		text += "\n" + tr("Spieler-XP: +%s (Level %d)") % [TowerStats.num(float(xp_result.xp)), int(xp_result.level_after)]
		if int(xp_result.level_after) > int(xp_result.level_before):
			text += " · " + tr("Level aufgestiegen!")
	else:
		text += "\n" + tr("Debug-Menü benutzt: keine Spieler-XP")
	hud.game_over_stats.text = text
	_refresh_hud()


func profile_mode() -> String:
	return "youtd"


func profile_extra() -> Dictionary:
	return {"elements": elements.duplicate(), "mode": mode_id(), "score": roundi(my_score()), "wisdom": wisdom.duplicate()}


## Punkte des lokalen Spielers (solo alle).
func my_score() -> float:
	return yt_players[local_player].score if yt_players.size() > 1 and local_player < yt_players.size() else youtd_score


## Meldung für den handelnden Spieler (oder Spieler pid) in der Seitenleiste.
func _note(text: String, pid := -1) -> void:
	if yt_players.is_empty():
		return
	var n: Array = (yt_players[clampi(pid, 0, yt_players.size() - 1)] if pid >= 0 else yp()).notes
	n.append(text)
	if n.size() > 5:
		n.pop_front()


# --- Wegsuche: nur auf dem Weg ------------------------------------------------------

var _road_locked := false


## Gegner laufen nur über "_"-Felder: alle Bauflächen sind für die Wegsuche gesperrt (einmalig).
func _update_paths() -> void:
	if not _road_locked:
		_road_locked = true
		var cells: Array[Vector2i] = []
		for y in map.height:
			for x in map.width:
				var c := Vector2i(x, y)
				if map.is_buildable(c):
					cells.append(c)
		pathfinder.set_solid_cells(cells, true)
	super._update_paths()


## Fester Weg in der Schlucht: kein Lichtpfad (Wunsch von Lukas).
func has_path_lights() -> bool:
	return false


# --- Tower-Optionen --------------------------------------------------------------

func tower_options(t: Tower) -> Array:
	if not t is YoutdTower or not is_instance_valid(t) or phase >= Phase.GAME_OVER or t.owner_player != acting:
		return []
	var yt := t as YoutdTower
	var opts := []
	if mode_id() != "totally_random":
		var up := YoutdData.upgrade_of(yt.yid)
		if up != "":
			var cost := int(YoutdData.tower(up).cost) - int(YoutdData.tower(yt.yid).cost)
			opts.append({"label": tr("Aufwerten"), "action": "upgrade", "id": up, "tier": 0,
					"cost": cost, "reason": build_reason(up, yt)})
	if yt.core != null:
		var list := yt.autocasts()
		for k in list.size():
			var ac: YtAutocast = list[k]
			if ac.can_use_auto_mode():
				continue
			var why := ""
			if ac.get_remaining_cooldown() > 0.0:
				why = tr("Lädt noch %s s") % TowerStats.num(ac.get_remaining_cooldown(), 1)
			elif yt.core.get_mana() < ac.get_mana_cost():
				why = tr("Zu wenig Mana")
			opts.append({"label": tr("Zauber: %s") % ac.get_autocast_name(), "action": "cast", "id": str(ac.get_id()), "tier": k,
					"cost": 0, "reason": why})
	for k in yt.items.size():
		var it: YtItem = yt.items[k]
		opts.append({"label": tr("Herausnehmen: %s") % it.get_display_name(), "action": "take_item", "id": str(it.get_id()), "tier": k,
				"cost": 0, "reason": ""})
	opts.append({"label": tr("Verkaufen"), "action": "sell", "id": yt.yid, "tier": 0, "cost": 0, "reason": ""})
	return opts


func sell_value(t: YoutdTower) -> int:
	var m: Dictionary = (rules.get("modes", []) as Array)[mode_index]
	return floori(int(YoutdData.tower(t.yid).get("cost", 0)) * float(m.get("sell", 0.5)))


func _apply_option(t: Tower, o: Dictionary) -> bool:
	var yt := t as YoutdTower
	if yt == null or o.get("reason", "") != "":
		return false
	match str(o.action):
		"sell":
			gold += sell_value(yt)
			for it in yt.items.duplicate():
				it.drop()
				it.fly_to_stash(0.0)
			for it in yt.oils.duplicate():
				it.drop()
				it.queue_free()
			run_stats.flush(yt)
			_unregister(yt)
			if yt == selected:
				_select(null)
			yt.remove_core()
			yt.queue_free()
			_refresh_hud()
			return true
		"take_item":
			return take_item(yt, int(o.tier))
		"cast":
			var list := yt.autocasts() if yt.core != null else []
			var k := int(o.tier)
			if k < 0 or k >= list.size():
				return false
			var ok: bool = list[k].manual_cast()
			if not ok:
				_note(tr("%s: kein Ziel in Reichweite") % list[k].get_autocast_name())
			_refresh_hud()
			return ok
		"upgrade":
			if gold < int(o.cost):
				return false
			gold -= int(o.cost)
			yt.spent += int(o.cost)
			run_stats.flush(yt)
			_unregister(yt)
			yt.set_youtd(str(o.id))
			_register(yt)
			run_stats.built(yt, "upgrade", current_wave())
			if yt == selected:
				yt.set_selected(true)
			_refresh_hud()
			return true
	return false


func _on_option_chosen(index: int) -> void:
	var opts := tower_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	submit({"type": "option", "tower": tower_ref(selected), "index": index, "action": o.action, "id": o.id, "tier": o.tier})


# --- Eingabe -----------------------------------------------------------------------

## Tower zum Setzen wählen (Lager oder Baumenü), nochmal = abbrechen.
func choose_build(id: String) -> void:
	build_id = "" if build_id == id else id
	picked_item = -1
	_refresh_hud()


## Item aus dem Lager wählen: mit ausgewähltem Tower sofort einlegen, sonst danach einen Tower anklicken.
func pick_item(i: int) -> void:
	if i >= 0 and i < item_stash.size() and (item_stash[i] as YtItem).is_consumable():
		submit({"type": "item_use", "uid": (item_stash[i] as YtItem).get_uid()})
		return
	if selected is YoutdTower:
		submit({"type": "item_put", "tower": tower_ref(selected), "uid": (item_stash[i] as YtItem).get_uid()})
		return
	picked_item = -1 if picked_item == i else i
	build_id = ""
	_refresh_hud()


## Auto: sobald die letzte Welle weg ist (Timer läuft), sofort die nächste.
## Haken für das System waves (auto.due leer): Auto startet, wenn das Feld leer ist und die Pause läuft.
func auto_wave_rule() -> bool:
	return next_wave > 1 and next_wave <= max_wave() and alive.is_empty() and next_wave_in > 0.0


func _update_hover() -> void:
	_update_tower_hover(get_process_delta_time())
	var c := NO_CELL
	if setup_done and phase < Phase.GAME_OVER and (build_id != "" or debug_tower != "") and not occupied.has(board.mouse_cell(camera_rig.camera)):
		c = board.mouse_anchor(camera_rig.camera)
	# Reichweite des Towers, der gesetzt wird, als Ring um die Bauvorschau (Lukas 2026-11-03)
	var r := 0.0
	if build_id != "" and debug_tower == "":
		r = YoutdData.units(float(YoutdData.tower(build_id).get("range", 0)) + YtConstants.RANGE_CHECK_BONUS_FOR_TOWERS)
	if c != board.hover_cell or board.hover_size != Board3D.TOWER_CELLS or r != board.hover_range:
		board.hover_cell = c
		board.hover_size = Board3D.TOWER_CELLS
		board.hover_range = r
		board.hover_ok = can_place(c) and (debug_tower != "" or build_reason(build_id) == "")
		board.refresh_hover()


func _on_click(c: Vector2i, anchor: Vector2i, _add := false) -> void:
	var a: Vector2i = occupied.get(c, NO_CELL)
	if towers.has(a):
		if picked_item >= 0:
			submit({"type": "item_put", "tower": tower_ref(towers[a]), "uid": (item_stash[picked_item] as YtItem).get_uid()})
			picked_item = -1
			return
		_select(towers[a])
	elif debug_tower != "":
		var id := debug_tower.trim_prefix(YoutdTower.PREFIX).get_slice(":", 0)
		if can_place(anchor):
			submit({"type": "debug_place", "id": id, "cell": anchor})
	elif build_id != "":
		if can_place(anchor) and build_reason(build_id) == "":
			submit({"type": "build", "id": build_id, "cell": anchor})
		else:
			Sfx.play("error")
	else:
		_select(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and setup_done:
		if event.keycode == KEY_N:
			submit({"type": "next_wave"})
			return
		if event.keycode == KEY_ESCAPE and (build_id != "" or picked_item >= 0):
			build_id = ""
			picked_item = -1
			_refresh_hud()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed \
			and (build_id != "" or picked_item >= 0) and not camera_rig.right_dragged:
		build_id = ""
		picked_item = -1
		_refresh_hud()
		return
	super._unhandled_input(event)


func _box_select(_r: Rect2, _add := false) -> void:
	pass


# --- Anzeige -----------------------------------------------------------------------

func _refresh_hud_local() -> void:
	lives = ceili(portal)
	hud.set_resources(mini(maxi(current_wave(), 1), maxi(waves.size(), 1)), maxi(waves.size(), 1), lives, gold, false)
	hud.set_round_gems([], "")
	if build_id != "" and phase < Phase.GAME_OVER:
		var t := YoutdData.tower(build_id)
		hud.set_phase(str(t.get("name", "")), tr("Baufläche anklicken · Esc oder Rechtsklick = abbrechen"))
	elif picked_item >= 0 and picked_item < item_stash.size():
		hud.set_phase((item_stash[picked_item] as YtItem).get_display_name(), tr("Tower anklicken, um das Item einzulegen · Esc = abbrechen"))
	else:
		match phase:
			Phase.BUILD:
				hud.set_phase(tr("Vorbereitung") if next_wave == 1 else tr("Pause"),
						tr("Welle %d kommt in %d s · N = sofort") % [next_wave, ceili(maxf(next_wave_in, 0.0))] if setup_done else "")
			Phase.WAVE:
				hud.set_phase(tr("Welle %d") % current_wave(), tr("%d Gegner unterwegs · N = nächste Welle schon jetzt") % enemies.size())
			Phase.GAME_OVER:
				hud.set_phase(tr("Verloren"), "")
			Phase.VICTORY:
				hud.set_phase(tr("Gewonnen"), tr("Alle Wellen geschafft!"))
	_refresh_selection()
	if youtd_panel != null:
		youtd_panel.refresh()
	if youtd_store != null:
		youtd_store.refresh()


## Werte, die Tower yt durch seine Öle hat, je Art zusammengezählt: [[Text, ""], …] für den Tooltip „▲ Öle“.
static func oil_rows(yt: YoutdTower) -> Array:
	var sum := {}
	var order := []
	for it in yt.oils:
		for m in (it as YtItem)._modifier.get_modification_list():
			if not sum.has(m.type):
				sum[m.type] = YtModification.new(m.type, 0.0, 0.0)
				order.append(m.type)
			sum[m.type].value_base += m.value_base
			sum[m.type].level_add += m.level_add
	var rows := []
	for ty in order:
		var text: String = (sum[ty] as YtModification).get_tooltip_text().strip_edges()
		if text != "":
			rows.append([text, ""])
	if rows.is_empty() and not yt.oils.is_empty():
		rows.append([", ".join(yt.oils.map(func(it): return it.get_display_name())), ""])
	return rows


func _refresh_selection() -> void:
	if selected == null or not is_instance_valid(selected) or not selected is YoutdTower:
		_refresh_item_row(null)
		hud.set_selection({})
		hud.set_options([])
		return
	var yt := selected as YoutdTower
	_refresh_item_row(yt)
	var body := tr("Level %d · Erfahrung %d") % [yt.level, floori(yt.xp)]
	var table := YoutdData.tower_exp_table()
	if yt.level + 1 < table.size() and yt.level < max_tower_level():
		body += tr(" (nächstes Level bei %d)") % int(table[yt.level + 1])
	var effects := buff_lines(yt.core)
	if not effects.is_empty():
		body += "\n" + tr("Effekte:") + "\n  · " + "\n  · ".join(effects)
	body += "\n" + tr("Verkaufswert: %d Gold") % sell_value(yt)
	hud.set_selection({"title": yt.label(), "color": yt.color, "body": body, "used_in": null, "stats": yt.view(), "oils": oil_rows(yt)})
	hud.set_options(tower_options(yt).map(func(o): return _option_view(yt, o)))
	hud.set_options_enabled(true)


## Item-Plätze des Towers als Inventarfelder wie in WC3: immer alle Felder, die der Tower nicht hat ausgegraut, freie
## dunkel. Items zieht man ins Lager, auf andere Plätze oder andere Tower; auf ein Item gezogen wird getauscht.
func _refresh_item_row(yt: YoutdTower) -> void:
	if _item_row == null:
		return
	for c in _item_row.get_children():
		_item_row.remove_child(c)
		c.queue_free()
	_item_row.visible = yt != null
	if yt == null:
		return
	var mine := yt.owner_player == local_player
	var cap := int(YoutdData.rules().get("rarities", {}).get("item_slots_max", {}).get("unique", 6))
	for k in maxi(cap, yt.slots()):
		var s := InvSlot.new(40.0)
		_item_row.add_child(s)
		if k >= yt.slots():
			s.set_locked()
			s.tooltip_text = tr("Dieser Tower hat nur %d Item-Plätze") % yt.slots()
			continue
		var loc := {"tower": tower_ref(yt), "slot": k}
		if k < yt.items.size():
			var it: YtItem = yt.items[k]
			var d := YoutdData.item(str(it.get_id()))
			s.show_item(YoutdData.item_icon(str(it.get_id())), YoutdData.rarity_color(str(d.get("rarity", "common"))))
			s.set_count(str(it.get_charges()) if it.uses_charges() else "")
			s.tooltip_text = YoutdPanel.item_tip_for(it) + ("\n" + tr("Ziehen: ins Lager, auf einen anderen Platz oder Tower") if mine else "")
			if mine:
				s.drag_data = {"inv": true, "from": loc}
		else:
			s.tooltip_text = tr("Freier Item-Platz: Item aus dem Lager hierher ziehen")
		if mine:
			s.accepts = func(data):
				var it2 := _drag_item(data)
				return it2 != null and not it2.is_consumable()
			s.on_drop = func(data): submit({"type": "item_move", "from": data.from, "to": loc})


## Gezogenes Item (Lager oder anderer Tower) auf einen Tower in der Welt (InvWorldDrop, wie in WC3).
func _drag_item(data: Dictionary) -> YtItem:
	var a := _inv_place(data.get("from", {}))
	return a.get("it") if not a.is_empty() else null


func inv_drop_reason(t: Tower, data: Dictionary) -> String:
	if not t is YoutdTower or t.owner_player != local_player:
		return tr("Nicht dein Tower")
	var it := _drag_item(data)
	if it == null:
		return tr("Item nicht mehr da")
	if it.is_consumable():
		return tr("Wird per Klick im Lager benutzt")
	if it.is_oil():
		return ""
	if (t as YoutdTower).items.has(it):
		return tr("Liegt schon in diesem Tower")
	if (t as YoutdTower).items.size() >= (t as YoutdTower).slots():
		return tr("Inventar voll")
	return ""


func inv_drop_hint(t: Tower, data: Dictionary) -> String:
	var it := _drag_item(data)
	if it != null and it.is_oil():
		return "+ " + tr("Öl anwenden (wird verbraucht)")
	var yt := t as YoutdTower
	return "+ " + tr("Einlegen · %d frei") % (yt.slots() - yt.items.size())


func inv_drop_on_tower(t: Tower, data: Dictionary) -> void:
	submit({"type": "item_move", "from": data.get("from", {}), "to": {"tower": tower_ref(t), "slot": -1}})


func _option_view(_t: Tower, o: Dictionary) -> Dictionary:
	match str(o.action):
		"sell":
			return {"label": o.label, "sub": tr("+%d Gold") % sell_value(_t as YoutdTower), "style": "normal",
					"tooltip": tr("Tower verkaufen, Items gehen ins Lager.")}
		"take_item":
			return {"label": o.label, "style": "normal", "tooltip": tr("Item zurück ins Lager legen.")}
	var sub := tr("%d Gold") % int(o.cost)
	var tip: String = o.label
	if str(o.action) == "upgrade":
		tip = tr("Aufwerten zu %s") % str(YoutdData.tower(str(o.id)).get("name", o.id)) + "\n" + YoutdPanel.tower_tip(str(o.id))
	if o.get("reason", "") != "":
		# geht noch nicht: kleiner Knopf mit dem Grund, wann es geht
		sub = str(o.reason) + " · " + sub
		return {"label": o.label, "sub": sub, "style": "normal", "icon": "up", "disabled": true, "tooltip": tip}
	var label: String = o.label + " · " + sub if int(o.cost) > 0 else o.label
	return {"label": label, "sub": sub, "style": "primary", "icon": "up", "tooltip": tip}


func _upcoming_waves(count: int) -> Array:
	var list := []
	if phase >= Phase.GAME_OVER or not setup_done:
		return list
	var first := maxi(current_wave(), 1) if phase == Phase.WAVE else next_wave
	for i in range(first - 1, mini(first - 1 + count, waves.size())):
		var w: Dictionary = waves[i]
		list.append({"number": i + 1, "type": str(w.type), "detail": wave_detail(w), "state": _wave_state(int(w.level))})
	return list


func _wave_state(lvl: int) -> String:
	if alive.keys().any(func(k): return str(k).ends_with(":%d" % lvl)):
		return tr("läuft")
	if lvl == next_wave and alive.is_empty():
		return tr("in %d s") % ceili(maxf(next_wave_in, 0.0))
	return ""


## „15× Normal, 2× Champion · Lua · Ork · 1.234 LP · Schnell“
func wave_detail(w: Dictionary) -> String:
	var counts := {}
	for s in w.creeps:
		counts[s] = int(counts.get(s, 0)) + 1
	var parts := []
	for s in counts:
		parts.append("%d× %s" % [counts[s], YoutdData.size_name(str(s))])
	var hp := float(w.hp) * float(rules.get("sizes", {}).get(str(w.size), {}).get("hp", 1.0)) * (1.0 + YoutdWaves.hp_modifier(w.specials))
	var text := "%s · %s · %s · %s %s" % [", ".join(parts), YoutdData.armor_name(str(w.armor_type)), YoutdData.race_name(str(w.race)),
			_big(hp), tr("LP")]
	if not (w.specials as Array).is_empty():
		text += " · " + ", ".join((w.specials as Array).map(func(id): return YoutdData.special_name(id)))
	return text


static func _big(x: float) -> String:
	if x >= 1e6:
		return TowerStats.num(x / 1e6, 1) + " Mio."
	if x >= 1e4:
		return "%d k" % roundi(x / 1000.0)
	return str(roundi(x))
