extends "res://scripts/game/game.gd"
## eeveTD (Vorbild: eeve! TD v1.01 von geX). Regeln in data/eeve.json, Tower und Gegner unter
## data/towers/eeve_*.json und data/enemies/eeve_*.json (erzeugt von tools/wc3/eeve/eeve_daten.py).
##
## Anders als GemTD gibt es keine Bau- und Wahlrunden: man baut jederzeit Barrikaden (2 Gold, 1 Food) und wertet
## sie gegen Gold zu Tower der sechs Elemente auf. Elementpunkte schalten höhere Tower frei. Zwischen zwei Leveln
## läuft eine Pause (Phase BUILD), danach startet das nächste Level (Phase WAVE), bis alle Gegner weg sind.
## Zu Beginn jedes Levels gibt es Zinsen, Einkommen und Food, alle 7 Level einen Elementpunkt und Holz,
## nach jeder Golem-Challenge einen zufälligen Elementpunkt.
## Fallen (Elementstufe 4) baut man direkt auf den Weg, Gegner laufen darüber. Ab 3 Punkten in zwei Elementen
## wird eine Barrikade zum Dual-Grundturm und der kostenlos zum Dual-Tower dieser beiden Elemente.
## Tower und Fallen sind EeveTower (eeve_tower.gd) mit den Sonderfähigkeiten der Dual-Tower und Fallen.
## Items, Lager und Marktplatz: eeve_items.gd (Werte in data/eeve_items.json), Oberfläche eeve_items_panel.gd
## (Lager rechts unten) und eeve_market_panel.gd (Fenster des Marktplatzes).
##
## Koop (Lobby, coop_sync.gd): alle bauen auf einem Feld, die Leben sind gemeinsam. Jeder hat eigenes Gold, Food,
## Holz und eigene Elementpunkte (eeve_players) und wertet nur eigene Tower auf. Die Gegner haben je weiterem
## Spieler mehr Leben (coop_hp_per_player), das nächste Level startet früher, wenn alle bereit sind.

const ELEMENT_IDS := ["nature", "earth", "fire", "storm", "magic", "water"]
const BARRICADE := "eeve_barricade"
const ROW_GAP := 0.2  ## Versatz der Reihenplätze einer Massenwelle (Towerbreiten)

var rules: Dictionary = {}
var difficulty := 2        ## Index in rules.difficulties
var field_type := 0        ## Index in rules.fields
var wave_seed := 0         ## Zufall der Wellen; Koop-Mitspieler erzeugen damit dieselben Wellen wie der Host
var level_pause := 0.0     ## Sekunden bis zum nächsten Level (nur Phase BUILD)
var ready_players := {}    ## Koop: Spieler, die das nächste Level sofort wollen (alle bereit = Start)
## Was jedem Spieler allein gehört, je Spielernummer (siehe ep()). Die Werte unten lesen und schreiben
## den Spieler, der gerade handelt (acting), wie gold in game.gd.
var eeve_players: Array = []
var lumber: int:
	get:
		return ep().lumber
	set(v):
		ep().lumber = v
var food_cap: int:
	get:
		return ep().food_cap
	set(v):
		ep().food_cap = v
var points: int:           ## noch nicht verteilte Elementpunkte
	get:
		return ep().points
	set(v):
		ep().points = v
var elements: Dictionary:  ## Element -> Stufe
	get:
		return ep().elements
var element_caps: Dictionary:  ## Element -> höchste Stufe (4 + zufällige Punkte)
	get:
		return ep().caps
var log_lines: Array:      ## letzte Meldungen (Einkommen, Punkte) für die Seitenleiste
	get:
		return ep().log
var clock := 0.0           ## Spielzeit in Wellen (für zeitlich begrenzte Effekte der Tower)
var placing_trap := ""     ## Falle, die gerade gesetzt wird (Klick aufs Feld), "" = keine
var eeve_panel: EevePanel
var scenery: EeveScenery    ## Wald, Laternen und Tag/Nacht rund um das Spielfeld
## Bonusfelder (Lava, Eis, schwarzer Marmor): Anker -> Sorte. Ein Tower bekommt den Bonus, wenn er genau darauf steht.
var bonus_tiles := {}
var bonus_view: EeveBonusTiles
## Wertung wie im Original, für das ganze Feld (im Koop gemeinsam): creeps = Punkte je Kill, challenges =
## Challenge-Punkte nach Schadensanteil. Leben, Gold und Feldbonus kommen erst am Ende dazu (score_parts()).
var eeve_score := {"creeps": 0.0, "challenges": 0.0}
var _challenge_run := {"points": 0.0, "damage": 0.0, "hp": 0.0}  ## laufende Challenge (für die Meldung danach)
var eitems: EeveItems       ## Items, Drops und Marktplatz
var items_panel: EeveItemsPanel
var market_panel: EeveMarketPanel


func system_mode() -> String:
	return "eevetd"


func _ready() -> void:
	# Stil „Druidenhain“ für die ganze Oberfläche von eeveTD, vor dem Bau des HUD in game.gd
	UiTheme.use_skin(UiTheme.DRUID)
	# eeveTD spielt nachts (Laternen, Glühwürmchen), vor dem Licht in game.gd; Tag über das Debug-Menü
	FieldStyle.night = bool(Session.eeve_choice.get("night", true))
	rules = Database.eeve
	eitems = EeveItems.new(self)
	var fresh: bool = Session.load_state.is_empty()
	difficulty = int(Session.eeve_choice.get("difficulty", difficulty))
	field_type = int(Session.eeve_choice.get("field", field_type))
	super._ready()
	if map == null:
		return
	if fresh:
		lives = int(rules.get("lives", 50))
		for p in players:
			p.gold = int(rules.get("start_gold", 200))
		level_pause = float(rules.get("first_pause", 45))
	scenery = EeveScenery.add_to(self)
	# Tageszeit läuft (Lukas 2026-11-09): Start kurz vor Sonnenuntergang, mit „Tag“ in der Wahl zur Mittagszeit
	scenery.start_cycle(DayCycle.START if FieldStyle.night else DayCycle.DAY_HOUR)
	bonus_view = EeveBonusTiles.new()
	add_child(bonus_view)
	bonus_view.show_tiles(bonus_tiles)
	_style_hud()
	_refresh_hud()


func _exit_tree() -> void:
	super._exit_tree()
	UiTheme.use_skin(UiTheme.ARCADE)
	FieldStyle.night = false


func _style_hud() -> void:
	hud.title_label.text = "eeveTD"
	hud.recipes_button.hide()
	hud.chance_value.get_parent().get_parent().hide()
	hud.pinned_panel.hide()
	eeve_panel = EevePanel.new()
	eeve_panel.game = self
	hud.left_col.add_child(eeve_panel)
	hud.left_col.move_child(eeve_panel, 0)
	items_panel = EeveItemsPanel.new()
	items_panel.game = self
	hud.root.add_child(items_panel)
	hud.tower_list.limits.append(items_panel)
	market_panel = EeveMarketPanel.new()
	market_panel.game = self
	hud.root.add_child(market_panel)
	_setup_debug()


# --- Debug-Menü ------------------------------------------------------------------------

## Debug-Menü von GemTD für eeveTD: statt Gems pro Runde Holz, Food, Elementpunkte und Elementstufen,
## „Nächster Bau“ setzt jeden Tower und jede Falle direkt (ohne Kosten und Voraussetzungen).
func _setup_debug() -> void:
	hud.debug_gems_row.hide()
	hud.debug_extra.show()
	var row := hud.add_debug_row("Holz")
	for n in [1, 5]:
		hud.debug_button_in(row, "+%d" % n, func(): _debug_add("lumber", n))
	row = hud.add_debug_row("Food")
	for n in [10, 50]:
		hud.debug_button_in(row, "+%d" % n, func(): _debug_add("food_cap", n))
	row = hud.add_debug_row("Elementpunkte")
	for n in [1, 5]:
		hud.debug_button_in(row, "+%d" % n, func(): _debug_add("points", n))
	row = hud.add_debug_row("Tageszeit")
	for t in [["Morgen", 6.4], ["Tag", DayCycle.DAY_HOUR], ["Abend", 18.9], ["Nacht", DayCycle.NIGHT_HOUR]]:
		hud.debug_button_in(row, t[0], func(): scenery.cycle.set_hour(t[1]))
	var fast := hud.debug_button_in(row, "×30", func(): scenery.cycle.speed = 30.0 if scenery.cycle.speed < 2.0 else 1.0)
	fast.tooltip_text = "Tageszeit 30-mal so schnell (nochmal: normal)"
	row = hud.add_debug_row("Elemente")
	var all := hud.debug_button_in(row, tr("Alle auf %d") % int(rules.get("point_max", 8)), _debug_max_elements)
	all.tooltip_text = "Alle sechs Elemente auf die höchste Stufe, schaltet alle Tower, Fallen und Dual-Tower frei"
	hud.debug_pick_caption.text = tr("Nächster Bau").to_upper()
	hud.debug_option.tooltip_text = "Was ein Klick aufs freie Feld baut: wie sonst eine Barrikade oder direkt einen Tower oder eine Falle, ohne Kosten und Voraussetzungen"
	hud.debug_wave_label.text = tr("Level")
	hud.debug_wave_hint.text = tr("Läuft gerade ein Level, wird es abgebrochen und das gewählte startet sofort. In der Pause kommt es als nächstes.")
	hud.debug_option.clear()
	hud.debug_keys = [""]
	hud.debug_option.add_item(tr("Barrikade (normal)"))
	var groups := {}
	for el in ELEMENT_IDS:
		groups[element_name(el)] = []
	groups[tr("Dual-Tower")] = []
	groups[tr("Fallen")] = []
	for id in Database.towers:
		var e: Dictionary = Database.towers[id].get("eeve", {})
		if e.is_empty() or id == BARRICADE:
			continue
		var g := tr("Fallen") if e.get("trap", false) else (tr("Dual-Tower") if e.has("elements") or e.get("dual_base", false) \
				else element_name(str(e.get("element", ""))))
		if groups.has(g):
			groups[g].append(id)
	for g in groups:
		var ids: Array = groups[g]
		ids.sort_custom(func(a, b):
			var la := int(Database.towers[a].eeve.get("level", 0))
			var lb := int(Database.towers[b].eeve.get("level", 0))
			return la < lb if la != lb else str(a) < str(b))
		hud.debug_option.add_separator(g)
		hud.debug_keys.append("")
		for id in ids:
			hud.debug_keys.append(id)
			hud.debug_option.add_item("%s · %d" % [Database.tower_label(id, 0), int(Database.towers[id].eeve.get("level", 0))])
	debug_tower = debug_tower if hud.debug_keys.has(debug_tower) else ""
	hud.debug_option.select(maxi(hud.debug_keys.find(debug_tower), 0))


func _debug_add(key: String, n: int) -> void:
	ep()[key] += n
	_refresh_hud()


func _debug_max_elements() -> void:
	var top := int(rules.get("point_max", 8))
	for el in ELEMENT_IDS:
		element_caps[el] = top
		elements[el] = top
	_update_auras()
	_refresh_hud()


func is_trap_id(id: String) -> bool:
	return Database.towers.get(id, {}).get("eeve", {}).get("trap", false)


## Debug: Tower oder Falle id ohne Kosten und Voraussetzungen hier setzen?
func debug_can_place(id: String, a: Vector2i) -> bool:
	if not setup_done or phase >= Phase.GAME_OVER or a == NO_CELL or not Database.towers.has(id):
		return false
	if is_trap_id(id):
		return Board3D.footprint(a, Board3D.TRAP_CELLS).all(func(c): return map.is_walkable(c) and not occupied.has(c) and not trap_cells.has(c))
	return can_place(a) and Board3D.footprint(a).all(func(c): return not trap_cells.has(c))


func debug_place(id: String, a: Vector2i) -> bool:
	if not debug_can_place(id, a):
		return false
	var t := EeveTower.new()
	t.owner_player = acting
	board.add_child(t)
	t.setup(self, a, id, 0)
	t.set_meta("spent", 0)
	_register(t)
	debug_used = true
	if not t.is_trap():
		_update_paths()
	_update_auras()
	board.hover_ok = false
	board.refresh_hover()
	_refresh_hud()
	return true


## Elemente, Food, Holz und Meldungen eines Spielers (-1 = der gerade handelt), bei Bedarf neu angelegt.
func ep(p := -1) -> Dictionary:
	var i := maxi(0, acting if p < 0 else p)
	while eeve_players.size() <= i:
		var els := {}
		var caps := {}
		for id in ELEMENT_IDS:
			els[id] = 0
			caps[id] = int(rules.get("point_max_normal", 4))
		eeve_players.append({"elements": els, "caps": caps, "points": int(rules.get("start_points", 1)),
				"food_cap": int(rules.get("start_food", 40)), "lumber": 0, "log": [], "items": [], "market": {}, "drop": ""})
	return eeve_players[i]


# --- Einstellungen und Wellen ------------------------------------------------------

func _make_setup_panel() -> Control:
	var setup := EeveSetupPanel.new()
	setup.game = self
	return setup


## Felsen kommen erst mit den Einstellungen (Feldtyp), siehe _apply_setup.
func _apply_variance() -> void:
	pass


func _make_waves() -> Array:
	wave_seed = rng.randi()
	return _waves_from_seed()


## Wellen aus wave_seed und Schwierigkeit; im Koop mit mehr Leben je weiterem Spieler.
func _waves_from_seed() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = wave_seed
	var list := EeveWaves.generate(rules, diff_rules(), r)
	var f := coop_hp_factor()
	if f != 1.0:
		for w in list:
			for g in w.get("groups", []):
				if g.has("hp"):
					g.hp = float(g.hp) * f
	return list


func coop_hp_factor() -> float:
	return 1.0 + float(rules.get("coop_hp_per_player", 0.0)) * maxi(players.size() - 1, 0)


func _execute(cmd: Dictionary) -> bool:
	match str(cmd.get("type", "")):
		"setup":
			if setup_done or acting != 0:
				return false
			_apply_setup(int(cmd.get("difficulty", 2)), int(cmd.get("field", 0)))
			take_ascension(cmd)
			return true
		"build":
			return build_barricade(cmd.get("cell", NO_CELL))
		"trap":
			return build_trap(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"element":
			return add_element_point(str(cmd.get("element", "")))
		"debug_place":
			return debug_place(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"item_use":
			return _after(eitems.use(int(cmd.get("index", -1)), tower_from_ref(cmd.get("tower", {}))))
		"item_move":
			return _after(eitems.move(cmd.get("from", {}), cmd.get("to", {})))
		"item_sell":
			return _after(eitems.sell(int(cmd.get("index", -1))))
		"market_buy":
			return _after(eitems.buy(str(cmd.get("id", ""))))
		"market_upgrade":
			return _after(eitems.buy_upgrade(str(cmd.get("kind", ""))))
		"start_level":
			if phase != Phase.BUILD or not setup_done:
				return false
			# Koop: erst wenn alle (die da sind) bereit sind
			ready_players[acting] = true
			if range(players.size()).all(func(i): return ready_players.has(i) or players[i].away):
				level_pause = 0.0
			_refresh_hud()
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
		"place", "replace_rocks", "remove_rocks", "take_back":
			return false
	return super._execute(cmd)


## Nach einem Item- oder Marktplatz-Befehl die Anzeige erneuern.
func _after(ok: bool) -> bool:
	if ok:
		_refresh_hud()
	return ok


func _apply_setup(diff: int, field: int) -> void:
	difficulty = clampi(diff, 0, (rules.get("difficulties", []) as Array).size() - 1)
	field_type = clampi(field, 0, (rules.get("fields", []) as Array).size() - 1)
	Session.eeve_choice = {"difficulty": difficulty, "field": field_type}
	waves = _make_waves()
	_place_bonus_tiles(int(rules.fields[field_type].get("tiles", 0)))
	_place_field_rocks(int(rules.fields[field_type].get("rocks", 0)))
	level_pause = float(rules.get("first_pause", 45))
	setup_done = true
	hud.setup_debug(0, waves.size())
	_refresh_hud()


## Zufällige Felsen (Felsen- und WTF-Feld); sie meiden Wegpunkte und versperren nie den Weg.
func _place_field_rocks(count: int) -> void:
	var placed := 0
	for attempt in count * 30:
		if placed >= count:
			break
		var c := Vector2i(rng.randi_range(1, map.width - 3), rng.randi_range(1, map.height - 3))
		if can_place(c, true) and not _on_bonus_tile(c):
			rocks[c] = true
			_occupy(c, true, true)
			placed += 1
	_update_paths()
	board.refresh_rocks()


## Bonusfelder: count Stück je Sorte, zufällig auf freien Feldern (nicht auf Wegpunkten, nicht übereinander).
func _place_bonus_tiles(count: int) -> void:
	bonus_tiles = {}
	for kind in rules.get("bonus_tiles", []):
		var placed := 0
		for attempt in count * 40:
			if placed >= count:
				break
			var c := Vector2i(rng.randi_range(1, map.width - 3), rng.randi_range(1, map.height - 3))
			if can_place(c, true) and not _on_bonus_tile(c):
				bonus_tiles[c] = str(kind.id)
				placed += 1
	if bonus_view != null:
		bonus_view.show_tiles(bonus_tiles)


## Liegt ein Tower oder Fels mit Anker a (auch nur teilweise) auf einem Bonusfeld?
func _on_bonus_tile(a: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if bonus_tiles.has(a + Vector2i(dx, dy)):
				return true
	return false


## Regeln des Bonusfelds unter Tower t ({} = keins). Nur ganz darauf stehende Tower zählen, Fallen nie.
func bonus_tile_of(t: Tower) -> Dictionary:
	if t.is_trap() or not bonus_tiles.has(t.cell):
		return {}
	for kind in rules.get("bonus_tiles", []):
		if kind.id == bonus_tiles[t.cell]:
			return kind
	return {}


static func _tiles_to_list(tiles: Dictionary) -> Array:
	var out := []
	for a in tiles:
		out.append([a.x, a.y, tiles[a]])
	return out


static func _tiles_from_list(list: Array) -> Dictionary:
	var out := {}
	for e in list:
		out[Vector2i(int(e[0]), int(e[1]))] = str(e[2])
	return out


# --- Wertung --------------------------------------------------------------------------

func score_factor() -> float:
	return float(diff_rules().get("score", 1.0))


## Punkte am Ende in Teilen; Leben, Gold und Feldbonus nur nach einem Sieg (wie im Original).
func score_parts(victory: bool) -> Dictionary:
	var sc: Dictionary = rules.get("score", {})
	var gold_left := 0
	for p in players:
		gold_left += int(p.gold)
	var parts := {"creeps": float(eeve_score.creeps), "challenges": float(eeve_score.challenges),
		"lives": 0.0, "gold": 0.0, "field": 0.0, "lives_left": lives, "gold_left": gold_left}
	if victory:
		parts.lives = float(sc.get("lives", 100)) * maxi(lives, 0) * score_factor()
		parts.gold = float(sc.get("gold", 0.5)) * gold_left * score_factor()
		parts.field = float(rules.fields[field_type].get("bonus", 0)) * score_factor()
	return parts


func score_total(victory := false) -> int:
	var parts := score_parts(victory)
	return roundi(parts.creeps + parts.challenges + parts.lives + parts.gold + parts.field)


## Challenge-Punkte für Gegner e: Anteil des Schadens an seinen Leben mal Punkte der Challenge.
func _score_challenge(e: Enemy, killed: bool) -> void:
	var share := 1.0 if killed else clampf(1.0 - e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
	var pts := float(e.get_meta("challenge_score", 0.0)) * share * score_factor()
	eeve_score.challenges += pts
	_challenge_run.points += pts
	_challenge_run.damage += e.max_hp * share
	_challenge_run.hp += e.max_hp


# --- Ablauf: Pause, Level, Pause … --------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if phase == Phase.BUILD and setup_done and not mirror:
		level_pause -= delta
		if level_pause <= 0.0:
			_start_level()
		elif ceili(level_pause) != ceili(level_pause + delta):
			_refresh_hud()


func _enter_build() -> void:
	phase = Phase.BUILD
	for p in players:
		p.stage = Phase.BUILD
	# Nach jeder Golem-Challenge (Level 11, 22, 33, 44) ein zufälliger Elementpunkt über die Grenze hinaus
	var done := wave_index  # gerade beendetes Level (1-basiert)
	if float(_challenge_run.hp) > 0.0:
		for p in players.size():
			_note(tr("Challenge: %d %% Schaden · +%d Punkte") % [
				roundi(100.0 * _challenge_run.damage / _challenge_run.hp), roundi(_challenge_run.points)], p)
		_challenge_run = {"points": 0.0, "damage": 0.0, "hp": 0.0}
	if done > 0 and str(rules.get("challenges", {}).get(str(done), {}).get("enemy", "")) != "" and done % 11 == 0 and done <= 44:
		for p in players.size():
			var st := ep(p)
			var el: String = ELEMENT_IDS[rng.randi() % ELEMENT_IDS.size()]
			if st.elements[el] < int(rules.get("point_max", 8)):
				st.caps[el] = mini(st.caps[el] + 1, int(rules.get("point_max", 8)))
				st.elements[el] += 1
				_note(tr("Challenge geschafft: +1 Stufe %s (zufällig)") % element_name(el), p)
		_update_auras()
	level_pause = float(diff_rules().get("pause", 20)) if wave_index > 0 else float(rules.get("first_pause", 45))
	_refresh_hud()


## Neues Level: Zinsen, Einkommen und Food, alle 7 Level ein Elementpunkt und Holz, dann die Welle.
func _start_level() -> void:
	if wave_index >= waves.size():
		_finish(Phase.VICTORY)
		return
	var level := wave_index + 1
	var food_steps: Array = rules.get("food_per_level", [1, 2])
	for p in players.size():
		var ps: PlayerState = players[p]
		var interest := floori(ps.gold * float(rules.get("interest", 0.05)))
		var income: int = level * int(rules.income.per_level) + int(rules.income.base)
		ps.gold += interest + income
		_note(tr("Level %d: +%d Gold Zinsen, +%d Gold Einkommen") % [level, interest, income], p)
		var st := ep(p)
		st.food_cap += int(food_steps[level % food_steps.size()])
		if level % int(rules.get("point_every", 7)) == 0:
			st.points += 1
			st.lumber += 1
			_note(tr("Neuer Elementpunkt und 1 Holz!"), p)
	eitems.on_level_start(level)
	ready_players.clear()
	super._start_wave()
	_queue_rows()


## Massenwellen kommen wie im Original in Reihen (4 nebeneinander, dann 0,15 s Pause): innerhalb einer
## Reihe ohne Abstand, die Reihenplätze laufen leicht versetzt los (_spawn_enemy).
func _queue_rows() -> void:
	var slot := 0
	for i in spawn_queue.size():
		var g: Dictionary = spawn_queue[i]
		var row := int(g.get("row", 1))
		if row <= 1:
			continue
		var c := g.duplicate()
		c["row_slot"] = slot
		if slot < row - 1:
			c["interval"] = 0.0
		spawn_queue[i] = c
		slot = (slot + 1) % row


func _start_wave() -> void:
	# Das nächste Level startet nur über die Pause (_start_level), nicht über die Runden von GemTD
	_start_level()


func _process_wave(delta: float) -> void:
	clock += delta
	_tick_props(delta)
	super._process_wave(delta)


## Wellen-Eigenschaften, die etwas tun (Werte in eeve.json → properties):
## Unverwundbar schützt sich, sobald er Schaden nimmt; Tempo-Bremse bremst Tower in der Nähe;
## Heiler heilt verletzte Bodengegner im Umkreis; Fesselnd fesselt einen Tower, der ihn in Reichweite hat.
func _tick_props(delta: float) -> void:
	var towers := all_towers()
	for t in towers:
		t.speed_malus = 0.0
	for e in enemies:
		if e.dead or not e.has_meta("eeve_props"):
			continue
		var cd: Dictionary = e.get_meta("eeve_props")
		for id in cd:
			cd[id] = maxf(float(cd[id]) - delta, 0.0)
			var p := EeveWaves.prop(rules, id)
			match id:
				"invuln":
					if cd[id] <= 0.0 and e.hp < e.max_hp:
						e.invulnerable_time = float(p.get("duration", 4.5))
						cd[id] = float(p.get("every", 10.0))
				"ar_aura":
					for t in towers:
						if t.pos.distance_to(e.pos) <= float(p.get("radius", 3.52)):
							t.speed_malus = maxf(t.speed_malus, float(p.get("malus", 0.45)))
				"heal":
					if cd[id] <= 0.0 and _heal_around(e, p):
						cd[id] = float(p.get("every", 90.0))
				"entang":
					if cd[id] <= 0.0 and _entangle(e, towers, float(p.get("duration", 4.0))):
						cd[id] = float(p.get("every", 15.0))


## Heilt verletzte Bodengegner im Umkreis (auch sich selbst). false, wenn niemand verletzt war.
func _heal_around(e: Enemy, p: Dictionary) -> bool:
	var hurt := enemies_in_radius(e.pos, float(p.get("radius", 5.47))).filter(func(o): return not o.flying and o.hp < o.max_hp)
	if hurt.is_empty():
		return false
	for o in hurt:
		o.hp = minf(o.hp + float(p.get("amount", 225)), o.max_hp)
	add_ring(e.pos, float(p.get("radius", 5.47)), Color("6dff8a"))
	return true


## Fesselt einen zufälligen Tower, der den Gegner in Reichweite hat. false, wenn keiner da ist.
func _entangle(e: Enemy, towers: Array, duration: float) -> bool:
	var near := towers.filter(func(t): return t.can_attack() and t.rooted_time <= 0.0 and t.in_range(e))
	if near.is_empty():
		return false
	var t: Tower = near[randi() % near.size()]
	t.rooted_time = duration
	add_ring(t.pos, 0.8, Color("3f8f3a"))
	return true


func _note(text: String, p := -1) -> void:
	var lines: Array = ep(p).log
	lines.append(text)
	if lines.size() > 4:
		lines.pop_front()


func add_ring(p: Vector2, r: float, col: Color) -> void:
	var n := 24
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		effects.add_beam(Board3D.to_3d(p + Vector2(cos(a), sin(a)) * r, 0.15), Board3D.to_3d(p + Vector2(cos(b), sin(b)) * r, 0.15), col)


## Brennende Gegner (Flammenrost) explodieren beim Tod und treffen alle Gegner im Umkreis.
func on_enemy_killed(e: Enemy) -> void:
	if e.has_meta("challenge_score"):
		_score_challenge(e, true)
	else:
		eeve_score.creeps += float(Database.enemies.get(e.enemy_id, {}).get("points", 0)) * score_factor()
	super.on_enemy_killed(e)
	if not mirror:
		eitems.on_kill(e)
	var burn: Dictionary = e.get_meta("eeve_burn", {})
	if burn.is_empty() or float(burn.until) < clock or not is_instance_valid(burn.tower):
		return
	var t: Tower = burn.tower
	add_ring(e.pos, float(burn.radius), Color("ff7a30"))
	for other in enemies_in_radius(e.pos, float(burn.radius)):
		if other.flying:
			continue
		other.last_hit_by = t.owner_player
		other.last_tower = t
		t.total_damage += other.take_damage(float(burn.damage), "spells")
		if other.dead:
			t.kills += 1


func _finish(p: Phase) -> void:
	phase = p
	drop_autosave()
	var won := p == Phase.VICTORY
	record_profile(won)
	Engine.time_scale = 1.0
	hud.show_game_over(won, mini(wave_index + 1, waves.size()), waves.size(), lives, enemies_killed, path_length,
		score_total(won), score_summary(won))
	hud.game_over_title.text = tr("Gewonnen!") if won else tr("Verloren")
	hud.game_over_stats.text = tr("Punkte: %d") % score_total(won) + "\n" + tr("Schwierigkeit: ") \
		+ tr(str(diff_rules().get("name", ""))) + " · " + tr(str(rules.fields[field_type].get("name", ""))) + "\n" \
		+ tr("Level %d von %d") % [mini(wave_index + 1, waves.size()), waves.size()] + "\n" + tr("Gegner besiegt: %d") % enemies_killed
	_refresh_hud()


## Tabelle für den Endbildschirm: woher die Punkte kommen.
func score_summary(victory: bool) -> Dictionary:
	var parts := score_parts(victory)
	var rows := [
		[tr("Gegner"), str(enemies_killed), str(roundi(parts.creeps))],
		[tr("Challenges"), "", str(roundi(parts.challenges))],
	]
	if victory:
		rows.append([tr("Übrige Leben"), str(parts.lives_left), str(roundi(parts.lives))])
		rows.append([tr("Übriges Gold"), str(parts.gold_left), str(roundi(parts.gold))])
		rows.append([tr("Feldbonus"), tr(str(rules.fields[field_type].get("name", ""))), str(roundi(parts.field))])
	rows.append([tr("Punktefaktor"), "", "×" + str(score_factor())])
	return {"headers": ["Wertung", "", "Punkte"], "rows": rows}


func profile_mode() -> String:
	return "eeve"


## Zusätzlich fürs Profil: Elemente, Holz und Feld.
func profile_extra() -> Dictionary:
	return {"elements": elements.duplicate(), "lumber": lumber, "score": score_total(phase == Phase.VICTORY)}


# --- Koop (coop_sync.gd) -------------------------------------------------------------

## Befehle, die Mitspieler zusätzlich zu denen von GemTD schicken dürfen.
# --- Inventar: Items auf Tower in der Welt ziehen (System inventory) ---

func item_slots(t: Tower) -> int:
	return EeveItems.slots(t)



func inv_drop_reason(t: Tower, data: Dictionary) -> String:
	return eitems.move_reason(data.get("from", {}), {"tower": tower_ref(t), "slot": -1})


func inv_drop_hint(t: Tower, data: Dictionary) -> String:
	var from: Dictionary = data.get("from", {})
	var inv: Array = ep(local_player).items
	var i := int(from.get("stash", -1))
	if i >= 0 and i < inv.size() and EeveItems.is_consumable(inv[i]):
		return "+ " + tr("%s benutzen (wird verbraucht)") % EeveItems.item_name(inv[i])
	return systems.inventory.free_hint(t)


## Mitspieler legen Tower vom Host als EeveTower an.
func new_tower() -> Tower:
	return EeveTower.new()


## Was eeveTD über GemTD und system_cfg.coop (modes.json) hinaus an die Mitspieler schickt.
func coop_extra() -> Dictionary:
	var titems := {}
	for t in all_towers():
		if t is EeveTower and (not t.items.is_empty() or t.extra_slots > 0):
			titems[systems.coop.tower_key(t)] = _tower_items(t)
	return {"tiles": _tiles_to_list(bonus_tiles), "score": eeve_score.duplicate(), "items": titems}


func coop_applied(d: Dictionary, changed: Array) -> void:
	if changed.has("seed") or changed.has("difficulty"):
		waves = _waves_from_seed()
	var titems: Dictionary = d.get("items", {})
	for t in all_towers():
		_set_tower_items(t, titems.get(systems.coop.tower_key(t), {}))
	if d.has("score"):
		eeve_score = {"creeps": float(d.score.get("creeps", 0.0)), "challenges": float(d.score.get("challenges", 0.0))}
	var tiles := _tiles_from_list(d.get("tiles", []))
	if tiles != bonus_tiles:
		bonus_tiles = tiles
		if bonus_view != null:
			bonus_view.show_tiles(bonus_tiles)
	_update_auras()


# --- Spielstand (save_game.gd) ---------------------------------------------------------

func save_extra() -> Dictionary:
	return {"difficulty": difficulty, "field": field_type, "seed": wave_seed, "pause": level_pause, "clock": clock,
		"players": eeve_players.duplicate(true), "spent": all_towers().map(func(t): return int(t.get_meta("spent", 0))),
		"tiles": _tiles_to_list(bonus_tiles), "score": eeve_score.duplicate(),
		"items": all_towers().map(func(t): return _tower_items(t))}


## Items und Zusatzplätze eines Towers für Spielstand und Koop.
func _tower_items(t: Tower) -> Dictionary:
	return {"items": t.items.duplicate(), "slots": t.extra_slots} if t is EeveTower else {}


func _set_tower_items(t: Tower, d: Dictionary) -> void:
	if not t is EeveTower:
		return
	t.items = (d.get("items", []) as Array).map(func(id): return str(id))
	t.extra_slots = int(d.get("slots", 0))


## made: Tower in der Reihenfolge des Spielstands (null = nicht mehr vorhanden).
func load_extra(d: Dictionary, made: Array) -> void:
	if d.is_empty():
		return
	difficulty = int(d.get("difficulty", difficulty))
	field_type = int(d.get("field", field_type))
	wave_seed = int(d.get("seed", wave_seed))
	waves = _waves_from_seed()
	level_pause = float(d.get("pause", level_pause))
	clock = float(d.get("clock", 0.0))
	bonus_tiles = _tiles_from_list(d.get("tiles", []))
	if bonus_view != null:
		bonus_view.show_tiles(bonus_tiles)
	var sc: Dictionary = d.get("score", {})
	eeve_score = {"creeps": float(sc.get("creeps", 0.0)), "challenges": float(sc.get("challenges", 0.0))}
	eeve_players = []
	for ps in d.get("players", []):
		var st: Dictionary = ps.duplicate(true)
		for k in ["elements", "caps"]:
			var fixed := {}
			for el in st.get(k, {}):
				fixed[str(el)] = int(st[k][el])
			st[k] = fixed
		for k in ["points", "food_cap", "lumber"]:
			st[k] = int(st.get(k, 0))
		st.items = (st.get("items", []) as Array).map(func(id): return str(id))
		var market := {}
		for k in st.get("market", {}):
			market[str(k)] = int(st.market[k])
		st.market = market
		st.drop = str(st.get("drop", ""))
		eeve_players.append(st)
	var spent: Array = d.get("spent", [])
	for i in mini(spent.size(), made.size()):
		if made[i] != null:
			made[i].set_meta("spent", int(spent[i]))
	var titems: Array = d.get("items", [])
	for i in mini(titems.size(), made.size()):
		if made[i] != null:
			_set_tower_items(made[i], titems[i])
	_update_auras()


# --- Gegner ------------------------------------------------------------------------

## Leben, Rüstung und Eigenschaften stehen schon in der Welle (eeve_waves.gd), dazu der Zauber-Faktor.
func _apply_enemy_difficulty(e: Enemy, g: Dictionary) -> void:
	e.spell_factor = float(diff_rules().get("spells", 1.0))
	if g.has("challenge_score"):
		e.set_meta("challenge_score", float(g.challenge_score))
	var props: Array = g.get("props", [])
	if props.has("immune"):
		e.spell_factor = 0.0
	if props.has("reduct"):
		e.hit_reduction = float(EeveWaves.prop(rules, "reduct").get("reduction", 15))
	# Eigenschaften mit eigenem Ablauf (_tick_props): Abklingzeit je Fähigkeit, 0 = bereit
	var active := {}
	for id in ["invuln", "ar_aura", "heal", "entang"]:
		if props.has(id):
			active[id] = 0.0
	if not active.is_empty():
		e.set_meta("eeve_props", active)


## Reihenplätze 2–4 einer Massenwelle starten ein Stück weiter vorn, damit sie nicht genau übereinander liegen.
func _spawn_enemy(g: Dictionary, lane := -1) -> void:
	var before := enemies.size()
	super._spawn_enemy(g, lane)
	var slot := int(g.get("row_slot", 0))
	if slot > 0:
		for i in range(before, enemies.size()):
			enemies[i].place_on_path(slot * ROW_GAP)


## Ein Boss kostet Level + verbleibende Leben in Prozent (Wunsch von Lukas, im Original 40 · (1 − r⁴)):
## Level 20 mit 11 % Rest kostet 31 Leben, ein unverletzter Boss Level + 100.
static func boss_leak_damage(level: int, hp: float, max_hp: float) -> int:
	return level + roundi(100.0 * clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0))


func on_enemy_leaked(e: Enemy) -> void:
	if e.has_meta("challenge_score"):
		_score_challenge(e, false)
	if e.boss and e.damage > 0:
		e.damage = boss_leak_damage(wave_index + 1, e.hp, e.max_hp)
	super.on_enemy_leaked(e)


func queued_hp() -> float:
	var total := 0.0
	for g in spawn_queue:
		total += _group_hp(g)
	return total


# --- Elemente ----------------------------------------------------------------------

func element_name(id: String) -> String:
	for e in rules.get("elements", []):
		if e.id == id:
			return tr(str(e.name))
	return id


func element_color(id: String) -> Color:
	for e in rules.get("elements", []):
		if e.id == id:
			return Color(str(e.color))
	return UiTheme.TEXT


func can_add_point(el: String) -> bool:
	return points > 0 and elements.has(el) and elements[el] < element_caps[el] and phase < Phase.GAME_OVER


func add_element_point(el: String) -> bool:
	if not can_add_point(el):
		return false
	points -= 1
	elements[el] += 1
	_update_auras()
	_refresh_hud()
	return true


## Auren wie in GemTD, dazu der Elementbonus: +10 % Grundschaden je Stufe im Element des Towers
## (Dual-Tower: Mittel ihrer beiden Elemente) und der Buff der Feuerbeeren, solange er wirkt.
func _update_auras() -> void:
	super._update_auras()
	var per := float(rules.get("element_bonus_per_level", 0.1))
	for t in all_towers():
		var e: Dictionary = t.def.get("eeve", {})
		var els: Array = e.get("elements", [e.get("element", "")])
		var own: Dictionary = ep(t.owner_player).elements
		var lvl := 0.0
		for el in els:
			lvl += own.get(el, 0)
		lvl /= maxf(els.size(), 1)
		if lvl <= 0.0:
			continue
		var aura: String = t.damage_source
		t.damage_bonus += per * lvl
		var names := " + ".join(els.map(func(el): return element_name(el)))
		t.damage_source = tr("%s Stufe %s") % [names, str(snappedf(lvl, 0.5))] + (" + " + aura if aura != "" else "")
	for t in all_towers():
		var tile := bonus_tile_of(t)
		t.xp_factor = 1.0 + float(tile.get("xp", 0.0))
		t.set_base_tint(Color(str(tile.color)) if not tile.is_empty() else Color(0, 0, 0, 0))
		if tile.is_empty():
			continue
		var name: String = tr("%s-Feld") % tr(str(tile.name))
		if tile.has("damage"):
			t.damage_bonus += float(tile.damage)
			t.damage_source = name + (" + " + t.damage_source if t.damage_source != "" else "")
		if tile.has("speed"):
			t.speed_bonus += float(tile.speed)
			t.speed_source = name + (" + " + t.speed_source if t.speed_source != "" else "")
	for src in all_towers():
		if not src is EeveTower or src.rage_left <= 0.0:
			continue
		var ab: Dictionary = src.ability("rage")
		for t in all_towers():
			if t.pos.distance_to(src.pos) <= float(ab.radius):
				t.damage_bonus += float(ab.bonus)
				t.damage_source += " + " + src.label()
	for t in all_towers():
		eitems.apply_to(t)


# --- Bauen und Aufwerten -------------------------------------------------------------

func food_used() -> int:
	return own_towers().size()


func can_build(a: Vector2i) -> bool:
	if not (setup_done and phase < Phase.GAME_OVER and gold >= barricade_cost() and food_used() < food_cap and can_place(a)):
		return false
	# nicht auf Fallen bauen, sonst läuft dort nie ein Gegner darüber
	return Board3D.footprint(a).all(func(c): return not trap_cells.has(c))


func barricade_cost() -> int:
	return int(Database.towers.get(BARRICADE, {}).get("eeve", {}).get("cost", 2))


func build_barricade(a: Vector2i) -> bool:
	if not can_build(a):
		return false
	gold -= barricade_cost()
	var t := EeveTower.new()
	t.owner_player = acting
	board.add_child(t)
	t.setup(self, a, BARRICADE, 0)
	t.set_meta("spent", barricade_cost())
	_register(t)
	run_stats.built(t, "build", wave_index + 1)
	_update_paths()
	_update_auras()
	board.hover_ok = can_build(a)
	board.refresh_hover()
	_refresh_hud()
	return true


# --- Fallen ---------------------------------------------------------------------------

## Fallen aller Elemente in der Reihenfolge der Elemente.
func trap_ids() -> Array:
	var out := []
	for el in ELEMENT_IDS:
		for id in Database.towers:
			var e: Dictionary = Database.towers[id].get("eeve", {})
			if e.get("trap", false) and str(e.get("element", "")) == el:
				out.append(id)
	return out


## Warum die Falle gerade nicht gebaut werden kann ("" = geht).
func trap_reason(id: String) -> String:
	var e: Dictionary = Database.towers.get(id, {}).get("eeve", {})
	if elements.get(str(e.get("element", "")), 0) < int(e.get("level", 4)):
		return tr("%s %d nötig") % [element_name(str(e.element)), int(e.level)]
	if gold < int(e.get("cost", 0)):
		return tr("zu wenig Gold")
	if lumber < int(e.get("lumber", 0)):
		return tr("zu wenig Holz")
	if food_used() >= food_cap:
		return tr("kein Food frei")
	return ""


## Fallen liegen auf begehbaren Feldern (3×3), nicht unter Barrikaden, Felsen oder anderen Fallen.
func can_build_trap(id: String, a: Vector2i) -> bool:
	if not setup_done or phase >= Phase.GAME_OVER or a == NO_CELL or trap_reason(id) != "":
		return false
	for c in Board3D.footprint(a, Board3D.TRAP_CELLS):
		if not map.is_walkable(c) or occupied.has(c) or trap_cells.has(c):
			return false
	return true


func build_trap(id: String, a: Vector2i) -> bool:
	if not can_build_trap(id, a):
		return false
	var e: Dictionary = Database.towers[id].eeve
	gold -= int(e.cost)
	lumber -= int(e.get("lumber", 0))
	var t := EeveTower.new()
	t.owner_player = acting
	board.add_child(t)
	t.setup(self, a, id, 0)
	t.set_meta("spent", int(e.cost))
	_register(t)
	run_stats.built(t, "trap", wave_index + 1)
	_update_auras()
	if acting == local_player and (not Input.is_key_pressed(KEY_SHIFT) or trap_reason(id) != ""):
		placing_trap = ""  # mit gedrückter Umschalttaste bleibt die Falle gewählt (wie in Shopping Maul)
		board.hover_cell = NO_CELL
	_refresh_hud()
	return true


## Falle zum Setzen auswählen (Knopf in der Seitenleiste), nochmal drücken bricht ab.
func start_trap_placement(id: String) -> void:
	_select(null)
	placing_trap = "" if placing_trap == id or trap_reason(id) != "" else id
	board.hover_cell = NO_CELL
	_refresh_hud()


func _select_rocks(list: Array, t: Tower = null) -> void:
	placing_trap = ""
	super._select_rocks(list, t)


# --- Dual-Tower --------------------------------------------------------------------------

## Elementpaare mit mindestens 3 Punkten in beiden Elementen.
func dual_pair_ready(els: Array) -> bool:
	return els.size() == 2 and els.all(func(el): return elements.get(el, 0) >= dual_level())


func dual_level() -> int:
	return int(Database.towers.get("eeve_dual_element_base_tower", {}).get("eeve", {}).get("level", 3))


func any_dual_ready() -> bool:
	var ready := []
	for el in ELEMENT_IDS:
		if elements.get(el, 0) >= dual_level():
			ready.append(el)
	return ready.size() >= 2


## Felsen gehören zum Feld und lassen sich nicht entfernen.
func can_remove_rock(_c: Vector2i) -> bool:
	return false


func tower_options(t: Tower) -> Array:
	if t == null or not is_instance_valid(t) or phase >= Phase.GAME_OVER or t.owner_player != acting:
		return []
	var opts := []
	for id in t.def.get("eeve", {}).get("next", []):
		var nd: Dictionary = Database.towers.get(id, {}).get("eeve", {})
		if nd.is_empty():
			continue
		var cost := int(nd.get("cost", 0))
		var wood := int(nd.get("lumber", 0))
		var el := str(nd.get("element", ""))
		var need := int(nd.get("level", 1))
		var reason := ""
		# Dual-Grundturm zeigt nur die Dual-Tower, deren beide Elemente auf Stufe 3 sind
		if nd.has("elements") and not dual_pair_ready(nd.elements):
			continue
		if nd.get("market", false) and eitems.has_market(acting):
			reason = tr("nur ein Marktplatz je Spieler")
		if nd.get("dual_base", false) and not any_dual_ready():
			reason = tr("zwei Elemente auf Stufe %d nötig") % need
		elif not nd.get("dual_base", false) and el != "" and elements.get(el, 0) < need:
			reason = tr("%s %d nötig") % [element_name(el), need]
		elif reason == "" and gold < cost:
			reason = tr("zu wenig Gold")
		elif reason == "" and lumber < wood:
			reason = tr("zu wenig Holz")
		opts.append({"label": Database.tower_label(id, 0), "action": "eeve_upgrade", "id": id, "tier": 0, "consume": [],
				"cost": cost, "lumber": wood, "element": el, "level": need, "reason": reason})
	if t.def.get("eeve", {}).get("market", false):
		opts.append({"label": tr("Marktplatz öffnen"), "action": "market_open", "id": t.tower_id, "tier": t.tier, "consume": [], "cost": 0, "reason": ""})
	opts.append({"label": tr("Abreißen"), "action": "scrap", "id": t.tower_id, "tier": t.tier, "consume": [], "cost": 0, "reason": ""})
	return opts


func _apply_option(t: Tower, o: Dictionary) -> bool:
	if t == null or o.get("reason", "") != "":
		return false
	if o.action == "scrap":
		# Abreißen gibt kein Gold zurück (wie im Original), eingesetzte Items kommen zurück ins Lager
		for id in t.items:
			eitems.give(t.owner_player, id)
		run_stats.flush(t)
		_unregister(t)
		if t == selected:
			_select(null)
		t.queue_free()
		_update_paths()
		_update_auras()
		_refresh_hud()
		return true
	if o.action != "eeve_upgrade" or gold < int(o.cost) or lumber < int(o.get("lumber", 0)):
		return false
	gold -= int(o.cost)
	lumber -= int(o.get("lumber", 0))
	t.set_meta("spent", int(t.get_meta("spent", 0)) + int(o.cost))
	run_stats.flush(t)
	_unregister(t)
	t.set_tower(o.id, 0)
	_register(t)
	run_stats.built(t, "upgrade", wave_index + 1)
	if t == selected:
		t.set_selected(true)
	_update_paths()
	_update_auras()
	_refresh_hud()
	return true


# --- Eingabe -----------------------------------------------------------------------


func _update_hover() -> void:
	_update_tower_hover(get_process_delta_time())
	var r := Tower.ring_radius(Database.tower_tier(placing_trap, 0), true) if placing_trap != "" else 0.0
	if r != board.hover_range:
		board.hover_range = r
		board.refresh_hover()
	if placing_trap != "":
		var a := board.mouse_anchor(camera_rig.camera, Board3D.TRAP_CELLS)
		if a != board.hover_cell or board.hover_size != Board3D.TRAP_CELLS:
			board.hover_cell = a
			board.hover_size = Board3D.TRAP_CELLS
			board.hover_ok = can_build_trap(placing_trap, a)
			board.refresh_hover()
		return
	var size := Board3D.TRAP_CELLS if is_trap_id(debug_tower) else Board3D.TOWER_CELLS
	var c := NO_CELL
	if setup_done and phase < Phase.GAME_OVER and not occupied.has(board.mouse_cell(camera_rig.camera)):
		c = board.mouse_anchor(camera_rig.camera, size)
	if c != board.hover_cell or board.hover_size != size:
		board.hover_cell = c
		board.hover_size = size
		board.hover_ok = debug_can_place(debug_tower, c) if debug_tower != "" else can_build(c)
		board.refresh_hover()


func _on_click(c: Vector2i, anchor: Vector2i, _add := false) -> void:
	if placing_trap != "":
		var at := board.mouse_anchor(camera_rig.camera, Board3D.TRAP_CELLS)
		if can_build_trap(placing_trap, at):
			submit({"type": "trap", "id": placing_trap, "cell": at})
		return
	var a: Vector2i = occupied.get(c, NO_CELL)
	var trap: Tower = traps.get(trap_cells.get(c, NO_CELL), null)
	if towers.has(a):
		_select(towers[a])
		if towers[a].def.get("eeve", {}).get("market", false) and towers[a].owner_player == local_player:
			market_panel.open()
	elif rocks.has(a):
		_select(null, a)
	elif trap != null:
		_select(trap)
	elif debug_tower != "":
		var at := board.mouse_anchor(camera_rig.camera, Board3D.TRAP_CELLS) if is_trap_id(debug_tower) else anchor
		if debug_can_place(debug_tower, at):
			submit({"type": "debug_place", "id": debug_tower, "cell": at})
	elif can_build(anchor):
		submit({"type": "build", "cell": anchor})
	else:
		_select(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N and phase == Phase.BUILD:
			submit({"type": "start_level"})
			return
		if event.keycode == KEY_Z:
			return
		if event.keycode == KEY_ESCAPE and placing_trap != "":
			placing_trap = ""
			_refresh_hud()
			return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
			and placing_trap != "" and not camera_rig.right_dragged:
		placing_trap = ""
		_refresh_hud()
		return
	super._unhandled_input(event)



func _on_option_chosen(index: int) -> void:
	if not selected_rocks.is_empty():
		return
	var opts := tower_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	if o.action == "market_open":
		market_panel.open()
		return
	submit({"type": "option", "tower": tower_ref(selected), "index": index, "action": o.action, "id": o.id, "tier": o.tier})


# --- Anzeige -----------------------------------------------------------------------

func _refresh_hud_local() -> void:
	hud.set_resources(mini(wave_index + 1, waves.size()), waves.size(), lives, gold, false)
	hud.set_path_length(path_length, 0)
	hud.set_waves(_upcoming_waves(4))
	hud.set_round_gems([], "")
	if placing_trap != "" and phase < Phase.GAME_OVER:
		hud.set_phase(Database.tower_label(placing_trap, 0), tr("Falle auf den Weg setzen · Esc oder Rechtsklick = abbrechen"))
		_refresh_selection()
		if eeve_panel != null:
			eeve_panel.refresh()
		return
	match phase:
		Phase.BUILD:
			var next := wave_index + 1
			var title := tr("Pause") if wave_index > 0 else tr("Aufbau")
			var hint := tr("Level %d startet gleich · N = sofort starten · freies Feld anklicken = Barrikade") % next
			if players.size() > 1:
				hint = tr("Level %d startet gleich · N = bereit, los geht's, wenn alle bereit sind · freies Feld anklicken = Barrikade") % next
			hud.set_phase(title, hint)
		Phase.WAVE:
			var w: Dictionary = waves[wave_index] if wave_index < waves.size() else {}
			hud.set_phase(tr("Level %d") % (wave_index + 1), tr("noch %d Gegner") % (enemies.size() + spawn_queue.size()) + _props_text(w))
		Phase.GAME_OVER:
			hud.set_phase(tr("Verloren"), "")
		Phase.VICTORY:
			hud.set_phase(tr("Gewonnen"), tr("Alle Level geschafft!"))
	_refresh_selection()
	if eeve_panel != null:
		eeve_panel.refresh()
	if items_panel != null:
		items_panel.refresh()
	if market_panel != null:
		market_panel.refresh()


func _props_text(w: Dictionary) -> String:
	var props: Array = w.get("eeve", {}).get("props", [])
	if props.is_empty():
		return ""
	return " · " + ", ".join(props.map(func(p): return tr(str(EeveWaves.prop(rules, p).get("name", p)))))


func _refresh_selection() -> void:
	if not selected_rocks.is_empty():
		hud.set_selection({"title": tr("Fels"), "color": Color("6d6a63"), "used_in": null,
				"body": tr("Felsen gehören zum Feld und lassen sich nicht entfernen.")})
		hud.set_options([])
		return
	if selected == null or not is_instance_valid(selected):
		hud.set_selection({})
		hud.set_options([])
		if items_panel != null:
			items_panel.refresh()
		return
	var view := TowerStats.view(selected)
	var e: Dictionary = selected.def.get("eeve", {})
	if e.get("barricade", false):
		view.subtitle = tr("Barrikade · zum Grundturm eines Elements aufwerten")
	elif e.get("market", false):
		view.subtitle = tr("Marktplatz · kauft Items an, verkauft Holz, Tränke und Upgrades")
	elif e.get("trap", false):
		view.subtitle = tr("Falle · %s · Gegner laufen darüber, trifft nur Bodengegner") % element_name(str(e.get("element", "")))
	elif e.get("dual_base", false):
		view.subtitle = tr("Dual-Grundturm · kostenlos zum Dual-Tower zweier Elemente mit Stufe %d aufwerten") % dual_level()
	elif e.has("elements"):
		view.subtitle = tr("Dual-Tower · %s") % " + ".join((e.elements as Array).map(func(el): return element_name(el))) + " · " + TowerStats.targets_text(selected.target_mode())
	else:
		view.subtitle = tr("%s · Elementstufe %d") % [element_name(str(e.get("element", ""))), int(e.get("level", 1))] + " · " + TowerStats.targets_text(selected.target_mode())
	var body := ""
	for todo in e.get("todo", []):
		body += tr("Kommt noch: ") + tr(str(todo)) + "\n"
	var tile := bonus_tile_of(selected)
	if not tile.is_empty():
		body += tr("Steht auf %s: %s") % [tr(str(tile.name)), tr(str(tile.text))] + "\n"
	body += tr("Ausgegeben: %d Gold") % int(selected.get_meta("spent", 0))
	hud.set_selection({"title": selected.label(), "color": selected.color, "body": body.strip_edges(), "used_in": null, "stats": view})
	hud.set_options(tower_options(selected).map(func(o): return _option_view(selected, o)))
	hud.set_options_enabled(true)
	if items_panel != null:
		items_panel.refresh()


func _option_view(t: Tower, o: Dictionary) -> Dictionary:
	if o.action == "scrap":
		return {"label": o.label, "style": "normal", "tooltip": tr("Tower oder Barrikade entfernen. Gold gibt es nicht zurück, das Food wird frei.")}
	if o.action == "market_open":
		return {"label": o.label, "style": "primary", "tooltip": tr("Items kaufen und verkaufen, Upgrades für alle eigenen Tower")}
	var sub := tr("%d Gold") % int(o.cost) if int(o.cost) > 0 else tr("kostenlos")
	if int(o.get("lumber", 0)) > 0:
		sub += " + " + tr("%d Holz") % int(o.lumber)
	if o.get("reason", "") != "":
		sub += " · " + str(o.reason)
	var v := {"label": o.label, "sub": sub, "style": "normal", "icon": "up", "disabled": o.get("reason", "") != "",
			"tooltip": o.label}
	v.preview_range = Tower.ring_radius(Database.tower_tier(o.id, 0), false)
	var nd: Dictionary = Database.towers.get(o.id, {}).get("eeve", {})
	if nd.has("elements"):
		v.label = "%s (%s)" % [o.label, " + ".join((nd.elements as Array).map(func(el): return element_name(el)))]
	v.diff = TowerStats.diff(t, o.id, 0)
	return v


## Nächste Level für die linke Spalte, mit Typ, Leben und Eigenschaften.
func _upcoming_waves(count: int) -> Array:
	var list := []
	if phase >= Phase.GAME_OVER:
		return list
	for i in range(wave_index, mini(wave_index + count, waves.size())):
		var w: Dictionary = waves[i]
		var g: Dictionary = w.groups[0]
		var d: Dictionary = Database.enemies.get(str(g.enemy), {})
		var detail := tr("%d× %s · %d LP · Rüstung %d") % [int(g.count), tr(str(d.get("name", "?"))), roundi(float(g.hp)), roundi(float(g.armor))]
		detail += _props_text(w)
		var state := ""
		if i == wave_index:
			state = tr("läuft") if phase == Phase.WAVE else tr("in %d s") % ceili(maxf(level_pause, 0.0))
		list.append({"number": i + 1, "type": str(w.type), "detail": detail, "state": state})
	return list
