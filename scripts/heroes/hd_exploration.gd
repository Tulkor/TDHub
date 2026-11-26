class_name HdExploration
extends RefCounted
## Bollwerk: verborgene Fundorte, gemeinsame Rätsel und autoritative Erkundungsrasten.

const RUNES := ["Mond", "Flamme", "Welle"]
const ACTIVE_COUNT := 8
const BREAK_SECONDS := 300.0
const BOOST_SECONDS := 180.0

var game
var active := false
var remaining := 0.0
var completed := 0
var checkpoint := 0
var points: Dictionary = {}
var tower_until := 0.0
var sites: Array = []
var active_ids: Array = []
var _root: Node3D
var _markers: Dictionary = {}
var _bosses: Dictionary = {}
var _boss_away: Dictionary = {}
var _scan := 0.0
var _passage_until := {}


func setup(g) -> void:
	game = g
	_root = Node3D.new()
	_root.name = "ExplorationSecrets"
	game.add_child(_root)
	select_sites(choose_sites(game.rng))


## Der Host zieht sechs Belohnungsarten und zwei weitere Funde, ohne Zurücklegen.
static func choose_sites(rng: RandomNumberGenerator) -> Array:
	var pool: Array = HdExplorationLayout.sites().duplicate()
	var chosen: Array = []
	var gates: Array = []
	for kind in ["resources", "items", "buff", "towers", "boss", "cache"]:
		var candidates: Array = pool.filter(func(site): return str(site.kind) == kind)
		if candidates.is_empty():
			continue
		var site: Dictionary = candidates[rng.randi_range(0, candidates.size()-1)]
		chosen.append(str(site.id))
		gates.append(str(site.gate))
		pool.erase(site)
	while chosen.size() < ACTIVE_COUNT and not pool.is_empty():
		var missing: Array = pool.filter(func(site): return not gates.has(str(site.gate)))
		var candidates: Array = missing if not missing.is_empty() else pool
		var site: Dictionary = candidates[rng.randi_range(0, candidates.size()-1)]
		chosen.append(str(site.id))
		gates.append(str(site.gate))
		pool.erase(site)
	return chosen


func select_sites(ids: Array) -> bool:
	if ids.size() != ACTIVE_COUNT or ids.any(func(id): return ids.count(id) != 1):
		return false
	var catalog: Array = HdExplorationLayout.sites()
	var selected: Array = []
	for id in ids:
		var matches: Array = catalog.filter(func(site): return str(site.id) == str(id))
		if matches.is_empty():
			return false
		selected.append(matches[0])
	close_encounters()
	active_ids = ids.duplicate()
	sites = selected
	points.clear()
	for site in sites:
		points[str(site.id)] = {"discovered":false, "open":false, "clue":0, "runes":[], "inspected":false, "claimed":false, "boss_started":false, "boss_won":false}
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_markers.clear()
	_build_markers()
	return true


func begin(wave: int) -> void:
	if active or wave <= completed or wave <= 0 or wave % 10 != 0:
		return
	checkpoint = wave
	remaining = BREAK_SECONDS
	active = true
	game.message.emit(tr("Erkundungsrast: 5 Minuten. Suche verborgene Pfade."))
	game.changed.emit()


func tick_break(dt: float) -> void:
	if not active:
		return
	remaining = maxf(0.0, remaining - dt)
	if remaining <= 0.0:
		active = false
		completed = checkpoint
		game.message.emit(tr("Die Erkundungsrast endet. Die Verteidigung geht weiter!"))
		game.changed.emit()


func tower_multiplier() -> float:
	return 1.35 if game.play_time < tower_until else 1.0


func snapshot() -> Dictionary:
	return {"active_ids":active_ids.duplicate(), "active":active, "remaining":remaining, "completed":completed, "checkpoint":checkpoint, "points":points.duplicate(true), "tower_until":tower_until}


func apply_state(d: Dictionary) -> void:
	var ids: Array = d.get("active_ids", active_ids)
	if ids != active_ids and not select_sites(ids):
		return
	active = bool(d.get("active", false))
	remaining = float(d.get("remaining", 0.0))
	completed = int(d.get("completed", 0))
	checkpoint = int(d.get("checkpoint", 0))
	points = d.get("points", points).duplicate(true)
	tower_until = float(d.get("tower_until", 0.0))
	_update_markers()


func step(dt: float) -> void:
	if game.coop:
		for index in game.coop.slots:
			game.coop.with_player(index,_step_passage)
	else:
		_step_passage()
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.2
		for site in sites:
			var st: Dictionary = points[str(site.id)]
			for actor in _heroes():
				if actor.alive() and actor.position.distance_to(site.pos) < 5.5 and not st.discovered:
					st.discovered = true
					game.message.emit(tr("Eine verborgene Öffnung zeichnet sich zwischen den alten Steinen ab."))
		_update_markers()
	for id in _bosses.keys():
		var boss: HdEnemy = _bosses[id]
		if not is_instance_valid(boss) or boss.dead:
			_bosses.erase(id)
			_boss_away.erase(id)
			continue
		var site := _site(str(id))
		var present := false
		for actor in _heroes():
			if actor.alive() and actor.position.distance_to(site.cave) < 16.0:
				present = true
		_boss_away[id] = 0.0 if present else float(_boss_away.get(id, 0.0)) + dt
		if float(_boss_away[id]) > 3.0:
			game._remove(boss)
			points[id].boss_started = false
			_bosses.erase(id)
			_boss_away.erase(id)


## Hostseitig pro Held: nur die versteckte Schwelle löst den Wechsel aus.
func _step_passage() -> void:
	if game.coop and not game.coop.host:return
	var actor: HdHero=game.hero
	if game.state!="play" or game.paused or not actor.alive() or bool(actor.get_meta("offline",false)):return
	var key := actor.get_instance_id()
	if game.play_time<float(_passage_until.get(key,0.0)):return
	for site in sites:
		var st: Dictionary=points[str(site.id)]
		if actor.position.distance_to(site.pos)<=1.2:
			st.discovered=true
			if str(site.gate)=="hidden":st.open=true
			if not bool(st.open):return
			_passage_until[key]=game.play_time+1.0
			game.teleport_hero(site.cave+Vector3(0,0,9))
			game.changed.emit()
			_update_markers()
			return
		if actor.position.distance_to(site.cave+Vector3(0,0,13))<=1.2:
			_passage_until[key]=game.play_time+1.0
			game.teleport_hero(site.return_pos)
			return


func _heroes() -> Array:
	return game.coop.heroes() if game.coop else [game.hero]


func _site(id: String) -> Dictionary:
	for site in sites:
		if str(site.id) == id:
			return site
	return {}


func nearby() -> Dictionary:
	if not game.hero.alive():
		return {}
	var p: Vector3 = game.hero.position
	for site in sites:
		var id := str(site.id)
		var st: Dictionary = points[id]
		if p.distance_to(site.cave) < 16.0:
			var actions: Array = []
			var desc := tr("Untersuche den Altar in der Mitte. Der Rückweg liegt am südlichen Höhlenrand.")
			if bool(st.claimed):
				desc = tr("Dieser Fundort wurde bereits geborgen.")
			elif p.distance_to(site.cave) <= 4.0:
				if str(site.kind) == "boss" and not bool(st.boss_won):
					desc = tr("Der Gruftwächter bewacht die Beute. Seine Hiebe, Ringe und Anstürme lassen sich ausweichen.")
					if not bool(st.boss_started):
						actions.append(_action(tr("Gruftwächter beschwören"), id, "summon"))
				else:
					actions.append(_action(tr("Fund bergen"), id, "claim"))
			if p.distance_to(site.cave + Vector3(0, 0, 13)) <= 4.0:
				actions.append(_action(tr("Zur verborgenen Öffnung zurück"), id, "return"))
			return {"title":tr(str(site.title)), "desc":desc, "actions":actions}
		if str(site.gate) == "hunt" and not bool(st.open):
			var clues: Array = site.get("clues", [])
			for i in clues.size():
				if p.distance_to(clues[i]) <= 4.5:
					return {"title":tr("Verwitterter Wegstein"), "desc":tr("Verfolge die eingeritzten Zeichen in der richtigen Reihenfolge. Spur %d / 3.") % (int(st.clue) + 1), "actions":[_action(tr("Spur lesen"), id, "clue", i)]}
		if p.distance_to(site.pos) <= 3.5:
			var actions: Array = []
			var desc := tr("Eine schmale, zwischen Trümmern versteckte Öffnung führt in die Tiefe.")
			if bool(st.open):
				desc=tr("Der Zugang ist offen. Laufe durch die Öffnung, um einzutreten.")
				actions.append(_action(tr("Verborgene Höhle betreten"), id, "enter"))
			elif str(site.gate) == "hidden":
				desc = tr("Aus einer Spalte weht kalte Luft. Suche aus nächster Nähe nach dem verborgenen Verschluss.")
				actions.append(_action(tr("Felsspalte untersuchen"), id, "search"))
			elif str(site.gate) == "runes":
				desc = tr("Drei Runen versperren den Zugang. Die verwitterte Inschrift verrät ihre Reihenfolge.")
				if not bool(st.inspected):
					actions.append(_action(tr("Inschrift entziffern"), id, "read"))
				else:
					desc = _inscription(id) + " " + tr("Aktivierte Siegel: %d / 3.") % st.runes.size()
					for i in RUNES.size():
						actions.append(_action(tr(str(RUNES[i])), id, "rune", i))
			else:
				desc = tr("Der Eingang ist versiegelt. Folge zunächst den drei Wegsteinen auf dem verborgenen Pfad.")
			return {"title":tr("Verborgener Zugang"), "desc":desc, "actions":actions}
	return {}


func _action(text: String, id: String, op: String, index := -1) -> Dictionary:
	return {"text":text, "cmd":{"kind":"explore", "id":id, "op":op, "index":index}}


func _inscription(id: String) -> String:
	var order: Array = _site(id).get("order", [0, 1, 2])
	return tr("Zuerst %s, dann %s, zuletzt %s.") % [tr(str(RUNES[int(order[0])])), tr(str(RUNES[int(order[1])])), tr(str(RUNES[int(order[2])]))]


func act(cmd: Dictionary) -> String:
	if game.state != "play" or game.paused or not game.hero.alive() or game.event_arena.active or game.final.active:
		return tr("Hier kannst du gerade nicht erkunden.")
	var id := str(cmd.get("id", ""))
	var site := _site(id)
	if site.is_empty():
		return tr("Unbekannter Fundort")
	var st: Dictionary = points[id]
	var op := str(cmd.get("op", ""))
	var p: Vector3 = game.hero.position
	var entrance := p.distance_to(site.pos) <= 3.5
	var altar := p.distance_to(site.cave) <= 4.0
	match op:
		"clue":
			var clues: Array = site.get("clues", [])
			var index := int(cmd.get("index", -1))
			if str(site.gate) != "hunt" or index < 0 or index >= clues.size() or p.distance_to(clues[index]) > 4.5:
				return tr("Gehe näher an den Wegstein heran.")
			if index != int(st.clue):
				return tr("Diese Spur ergibt erst mit den vorherigen Zeichen einen Sinn.")
			st.clue = index + 1
			st.open = int(st.clue) >= 3
			game.message.emit(tr("Die letzte Spur entriegelt den Höhleneingang.") if st.open else tr("Das Zeichen weist tiefer in den Pfad. Suche den nächsten Wegstein."))
		"read":
			if not entrance or str(site.gate) != "runes":
				return tr("Gehe näher an die Inschrift heran.")
			st.inspected = true
			game.message.emit(_inscription(id))
		"rune":
			if not entrance or str(site.gate) != "runes" or not bool(st.inspected) or bool(st.open):
				return tr("Lies zuerst die Inschrift am Runensiegel.")
			var index := int(cmd.get("index", -1))
			var order: Array = site.order
			if index != int(order[st.runes.size()]):
				st.runes = []
				game.message.emit(tr("Die Siegel erlöschen. Die Reihenfolge war falsch."))
			else:
				st.runes.append(index)
				st.open = st.runes.size() == order.size()
				if st.open:
					game.message.emit(tr("Die drei Siegel lösen sich. Ein Weg in die Tiefe öffnet sich."))
		"search":
			if str(site.gate) != "hidden" or p.distance_to(site.pos) > 1.8:
				return tr("Untersuche die Felsspalte aus nächster Nähe.")
			st.discovered = true
			st.open = true
			game.message.emit(tr("Hinter einem losen Stein findest du einen verborgenen Durchgang."))
		"enter":
			if not entrance or not bool(st.open):
				return tr("Der Zugang ist noch verschlossen.")
			game.teleport_hero(site.cave + Vector3(0, 0, 9))
		"return":
			if p.distance_to(site.cave + Vector3(0, 0, 13)) > 4.0:
				return tr("Gehe zum Rückweg am Höhlenrand.")
			game.teleport_hero(site.return_pos)
		"summon":
			if str(site.kind) != "boss" or not altar or not bool(st.open) or bool(st.boss_started) or bool(st.boss_won) or bool(st.claimed):
				return tr("Der Wächter kann hier nicht beschworen werden.")
			var boss: HdEnemy = game.spawn_home("arenawaechter", site.cave + Vector3(0, 0, -5), "explore_" + id)
			boss.def = boss.def.duplicate(true)
			boss.def.name = tr("Gruftwächter")
			boss.max_hp *= 1.4
			boss.hp = boss.max_hp
			_bosses[id] = boss
			st.boss_started = true
			_boss_away[id] = 0.0
		"claim":
			if not altar or not bool(st.open) or bool(st.claimed) or (str(site.kind) == "boss" and not bool(st.boss_won)):
				return tr("Dieser Fund kann noch nicht geborgen werden.")
			st.claimed = true
			if str(site.kind) == "towers":
				tower_until = maxf(tower_until, game.play_time + _reward_duration())
			if game.coop:
				for index in game.coop.slots:
					game.coop.with_player(index, func(): _reward(id))
			else:
				_reward(id)
			game.message.emit(tr("Fund geborgen: %s") % tr(str(site.title)))
		_:
			return tr("Unbekannte Erkundungsaktion")
	game.changed.emit()
	_update_markers()
	return ""


func on_kill(e: HdEnemy) -> bool:
	if not e.zone.begins_with("explore_"):
		return false
	var id: String = e.zone.trim_prefix("explore_")
	if points.has(id) and str(_site(id).get("kind", "")) == "boss":
		points[id].boss_won = true
		_bosses.erase(id)
		_boss_away.erase(id)
		game.message.emit(tr("Der Gruftwächter ist besiegt. Die Beute am Altar ist frei."))
	return true


## Offene Nebenbegegnungen dürfen dem Gruppenwechsel in den Schlund nicht folgen.
func close_encounters() -> void:
	for id in _bosses:
		var boss: HdEnemy = _bosses[id]
		if is_instance_valid(boss) and not boss.dead:
			game._remove(boss)
			points[id].boss_started = false
	_bosses.clear()
	_boss_away.clear()


func _reward(id: String) -> void:
	var kind := str(_site(id).get("kind", ""))
	match kind:
		"resources":
			game.message.emit(HdReward.grant(game, {"gold":250, "wood":6}))
		"items", "boss":
			game.message.emit(HdReward.grant(game, {"item":2, "gold":300 if kind == "boss" else 0}))
		"buff":
			game.hero.add_buff("mondquelle", {"dmg_out":0.2, "speed":0.15}, _reward_duration())
			game.message.emit(tr("Mondsegen: +20 %% Schaden und +15 %% Bewegung für %d s.") % roundi(_reward_duration()))
		"towers":
			game.message.emit(tr("Runenwerk: Alle Verteidigungstürme verursachen für %d s 35 %% mehr Schaden.") % roundi(_reward_duration()))
		"cache":
			game.message.emit(HdReward.grant(game, {"gold":150, "wood":3}))
			game.hero.add_shield(150.0, _reward_duration())
	game.shop._changed()


func _reward_duration() -> float:
	return BOOST_SECONDS + (remaining if active else 0.0)


func _build_markers() -> void:
	var stone: Material = HdDev.mat(Color("282b32"), 0.25)
	var bronze: Material = HdDev.metall(Color("8c7962"))
	for site in sites:
		var id := str(site.id)
		var altar := Node3D.new()
		_root.add_child(altar)
		altar.add_child(HdDev.cyl(1.2, 1.6, 0.8, stone, site.cave + Vector3(0, 0.4, 0)))
		altar.add_child(HdDev.cyl(0.9, 1.1, 0.12, bronze, site.cave + Vector3(0, 0.86, 0)))
		var relic := HdDev.sphere(0.35, HdDev.mat(Color("b59bd1"), 0.25, 0.6), site.cave + Vector3(0, 1.3, 0))
		altar.add_child(relic)
		_markers[id] = {"relic":relic, "clues":[]}
		_root.add_child(HdDev.cyl(0.9, 1.1, 0.12, bronze, site.cave + Vector3(0, 0.08, 13)))
		var clues: Array = site.get("clues", []) if str(site.gate) == "hunt" else []
		for p in clues:
			var marker := HdDev.box(Vector3(0.7, 0.9, 0.35), stone, p + Vector3(0, 0.45, 0))
			_root.add_child(marker)
			var scratch := HdDev.box(Vector3(0.25, 0.04, 0.38), bronze, p + Vector3(0, 0.92, 0))
			_root.add_child(scratch)
			_markers[id].clues.append(scratch)
	_update_markers()


func _update_markers() -> void:
	for id in _markers:
		var st: Dictionary = points[id]
		_markers[id].relic.visible = not bool(st.claimed)
		var clues: Array = _markers[id].clues
		for i in clues.size():
			clues[i].visible = i <= int(st.clue)
