extends Node
## Grundlage der Tower-Prüfung je Modus (towers_*_test.gd): baut jeden Tower (jede Stufe) einzeln ohne Kosten,
## stellt zähe, festgehaltene Gegner (Boden und Luft) in und um seine Reichweite und prüft, dass er Schaden macht
## und jede seiner Fähigkeiten tatsächlich wirkt. Tower mit Auren für andere Tower (Tempo, Schaden, Feuerbeeren)
## stehen neben einem Helfer-Tower ohne Fähigkeiten, die Aura muss bei ihm ankommen.
## Chancen (Betäubung, Krit …) werden für die Prüfung auf 100 % gesetzt: geprüft wird, ob die Wirkung kommt.
## Der Tower läuft als Unterklasse (Probe) seiner echten Klasse, die mitzählt, was er trifft.
## Argumente: --tower=id1,id2 (nur diese), --bericht=pfad.md (Tabelle aller Tower)

const MAX_TIME := 25.0   ## Spielsekunden je Tower höchstens
const MIN_TIME := 1.5    ## so lange mindestens (Zauber, Auren)
const SCALE := 6.0
const BIG_HP := 1.0e9

## Fähigkeit → was beobachtet werden muss (Schlüssel in _seen)
const NEEDS := {
	"splash": ["secondary"], "bounce": ["secondary"], "multishot": ["multi"], "slow": ["slow"], "poison": ["poison"],
	"crit": ["crit"], "air_bonus": ["air_bonus"], "armor_reduce": ["armor"], "stun": ["stun"], "gold_on_hit": ["gold"], "stacking_damage": ["stacks"],
	"nova": ["nova"], "speed_aura": ["helper_speed"], "damage_aura": ["helper_damage"], "burn_aura": ["aura_damage"],
	"slow_aura": ["slow"], "armor_aura": ["armor"], "bounty_aura": ["bounty_aura"], "xp_aura": ["xp_aura"], "wave_damage": ["wave_damage"], "cone": ["cone"],
	# eeveTD
	"amplify": ["amplify"], "death_explosion": ["burn_mark", "explosion"], "chain": ["chain"], "rage": ["helper_damage"],
	"hp_cut": ["hp_cut"], "pulse": ["cast"], "area_debuff": [],
	# Shopping Maul
	"detect": ["detect"], "nova_spell": ["cast", "cast_hits"], "chain_spell": ["cast", "chain_hits"], "wave_spell": ["cast", "cast_hits"],
	"stun_spell": ["cast", "stun"], "flirt_spell": ["cast", "stun"], "life": ["life"],
}

const PROBE_BODY := """
var p_frames := {}
var p_multi := 0
var p_primary := 0
var p_secondary := 0
var p_crit := 0
var p_roll := 0.0
var p_cur = null
var p_air := 0.0
var p_ground := 0.0
var p_calls := {}

func p_snap() -> Dictionary:
	var d := {}
	for e in game.enemies:
		d[e] = e.hp
	return d

func p_count(name: String, before: Dictionary, skip = null) -> void:
	var n := 0
	for e in before:
		if e != skip and is_instance_valid(e) and e.hp < before[e]:
			n += 1
	var c: Array = p_calls.get(name, [0, 0, 0])
	c[0] += 1
	c[1] += n
	c[2] = maxi(c[2], n)
	p_calls[name] = c

func _roll_damage() -> float:
	p_roll = super()
	return p_roll

func _attack(e) -> void:
	var f := Engine.get_process_frames()
	p_frames[f] = p_frames.get(f, 0) + 1
	p_multi = maxi(p_multi, p_frames[f])
	p_cur = e
	super(e)
	p_cur = null

func _hit(e, dmg: float) -> void:
	if p_cur != null and not e.dead:
		if e == p_cur:
			p_primary += 1
			if dmg > p_roll * 1.01 + 0.001:
				p_crit += 1
		else:
			p_secondary += 1
	var before: float = e.hp
	super(e, dmg)
	if dmg > 0.0 and before > e.hp:
		if e.flying:
			p_air = maxf(p_air, (before - e.hp) / dmg)
		else:
			p_ground = maxf(p_ground, (before - e.hp) / dmg)

func _nova(target, ab: Dictionary) -> void:
	var b := p_snap()
	super(target, ab)
	p_count("nova", b, target)

func _cone(target_pos: Vector2, ab: Dictionary, dmg: float, target) -> void:
	var b := p_snap()
	super(target_pos, ab, dmg, target)
	p_count("cone", b, target)

func _apply_enemy_auras(delta: float) -> void:
	var b := p_snap()
	super(delta)
	p_count("aura", b)
"""

const PROBE_EEVE := """
func _cast(ab: Dictionary) -> bool:
	var b := p_snap()
	var ok := super(ab)
	if ok:
		p_count("cast", b)
	return ok

func _chain(first, ab: Dictionary) -> void:
	var b := p_snap()
	super(first, ab)
	p_count("chain", b, first)

func _hp_cut(ab: Dictionary) -> void:
	var b := p_snap()
	super(ab)
	var c: Array = p_calls.get("hp_cut", [0, 0, 0])
	for e in b:
		if is_instance_valid(e) and e.hp < b[e]:
			c[1] += 1
	p_calls["hp_cut"] = c
"""

const PROBE_MAUL := """
func _cast(ab: Dictionary) -> bool:
	var b := p_snap()
	var ok := super(ab)
	if ok:
		p_count("cast", b)
	return ok
"""

var failures := 0
var game: Node
var mode := ""
var only: Array = []
var report_path := ""
var rows: Array = []   ## [Tower, Stufe, Schaden, Fähigkeiten, Fehler]
var _probe_scripts := {}
var _anchor := Vector2i.ZERO
var _helper_cell := Vector2i.ZERO
var _helper_id := ""
var _trap_cell := Vector2i.ZERO
var _ground_enemy := ""
var _air_enemy := ""


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile_towers"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tower="):
			only = a.trim_prefix("--tower=").split(",", false)
		elif a.begins_with("--bericht="):
			report_path = a.trim_prefix("--bericht=")
	await get_tree().process_frame
	await _start_game()
	var cases := _cases()
	check(not cases.is_empty(), "%s: Tower gefunden: %d" % [mode, cases.size()])
	for c in cases:
		await _probe(str(c[0]), int(c[1]))
	_write_report()
	var bad := rows.filter(func(r): return r[4] != "").size()
	print("TOWERS %s: %d geprüft, %d mit Fehlern" % [mode, rows.size(), bad])
	print("TOWERS TEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


# --- je Modus überschreiben -------------------------------------------------------

## Spiel laden und so weit bringen, dass Tower schießen dürfen.
func _start_game() -> void:
	pass


## [id, Stufe] aller zu prüfenden Tower.
func _cases() -> Array:
	return []


func _new_tower_base() -> String:
	return "res://scripts/game/tower.gd"


func _wave_running() -> void:
	game.phase = game.Phase.WAVE
	game.spawn_queue = []
	game.wave_index = 9


# --- gemeinsam -------------------------------------------------------------------

func _tier_cases(ids: Array) -> Array:
	var out := []
	for id in ids:
		if not only.is_empty() and not only.has(id):
			continue
		var n: int = maxi(1, (Database.towers[id].get("tiers", []) as Array).size())
		for t in n:
			out.append([id, t])
	return out


## Platz für den Helfer-Tower dicht neben dem Tower id an a (Fallen und Platten liegen auf dem Weg).
func _helper_near(id: String, a: Vector2i) -> Vector2i:
	if not _is_trap(id):
		return _helper_cell
	var center := Board3D.footprint_center(a, Board3D.TRAP_CELLS)
	var foot := Board3D.footprint(a, Board3D.TRAP_CELLS)
	var best := _helper_cell
	var best_d := INF
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var c := a + Vector2i(dx, dy)
			var d := Board3D.footprint_center(c, 2).distance_to(center)
			if d < best_d and game.can_place(c) and not Board3D.footprint(c).any(func(x): return foot.has(x)):
				best = c
				best_d = d
	return best


## Tower mit Schaden und ohne Fähigkeiten als Nachbar für Auren.
func _plain_tower(ids: Array) -> String:
	for id in ids:
		var s: Dictionary = Database.tower_tier(id, 0)
		if not _is_trap(id) and (s.get("abilities", []) as Array).is_empty() and float(s.get("cooldown", 0)) > 0.0 \
				and float((s.get("damage", [0, 0]) as Array)[1]) > 0.0:
			return id
	return ""


func _probe_script(base: String) -> GDScript:
	if _probe_scripts.has(base):
		return _probe_scripts[base]
	var s := GDScript.new()
	var body := PROBE_BODY
	if base.ends_with("eeve_tower.gd"):
		body += PROBE_EEVE
	elif base.ends_with("maul_tower.gd"):
		body += PROBE_MAUL
	s.source_code = "extends \"%s\"\n%s" % [base, body]
	var err := s.reload()
	check(err == OK, "Probe-Klasse für %s übersetzt (%s)" % [base, error_string(err)])
	_probe_scripts[base] = s
	return s


## Tower ohne Kosten an a setzen. probe = mit Zählern.
func _place(id: String, tier: int, a: Vector2i, probe: bool) -> Node:
	var t: Node = _probe_script(_new_tower_base()).new() if probe else load(_new_tower_base()).new()
	game.board.add_child(t)
	t.setup(game, a, id, tier)
	game._register(t)
	return t


func _remove(t: Node) -> void:
	if t == null or not is_instance_valid(t):
		return
	game._unregister(t)
	t.queue_free()


func _clear_enemies() -> void:
	for e in game.enemies.duplicate():
		game._remove_enemy(e)


## Ein Gegner fest an p (Tower-Einheiten), sehr zäh, ohne Rüstung.
func _enemy(flying: bool, p: Vector2, traveled: float) -> Node:
	var e: Node = _spawn(flying, p)
	if e == null:
		return null
	e.max_hp = BIG_HP
	e.hp = BIG_HP
	e.armor = 0.0
	e.spell_factor = 1.0
	e.hit_reduction = 0.0
	e.speed = 0.0
	e.path = PackedVector2Array([p, p + Vector2(500, 0)])
	e.path_index = 1
	e.set_meta("probe_pos", p)
	e.set_meta("probe_traveled", traveled)
	_pin(e)
	return e


func _spawn(flying: bool, _p: Vector2) -> Node:
	var before: int = game.enemies.size()
	game._spawn_enemy({"enemy": _air_enemy if flying else _ground_enemy}, 0)
	return game.enemies.back() if game.enemies.size() > before else null


func _pin(e: Node) -> void:
	e.pos = e.get_meta("probe_pos")
	e.traveled = e.get_meta("probe_traveled")
	e.path_index = 1
	e._sync_position()


## Gegner um den Tower: einer vorne in Reichweite (wird Ziel), drei dicht daneben (Fläche, Kette),
## einer direkt am Tower (kleine Auren), je als Boden- und Luftgegner.
func _enemies_for(t: Node) -> void:
	var r: float = t.range_cells()
	var d := clampf(minf(r * 0.6, 1.5), 0.15, maxf(r - 0.2, 0.15))
	if t.is_trap():
		d = 0.3
	var lead: Vector2 = t.pos + Vector2(d, 0)
	var spots := [[lead, 1000.0], [lead + Vector2(0.05, 0), 900.0], [lead + Vector2(0, 0.15), 800.0],
		[lead + Vector2(0, -0.25), 700.0], [t.pos + Vector2(0.2, 0.2), 500.0]]
	for s in spots:
		_enemy(false, s[0], s[1])
		_enemy(true, s[0] + Vector2(0.01, 0.01), s[1] - 1.0)


func _gold() -> int:
	return int(game.gold)


func _set_wave(n: int) -> void:
	game.wave_index = n - 1


func _probe(id: String, tier: int) -> void:
	_clear_enemies()
	var abilities := []
	var helper: Node = null
	var stats: Dictionary = _stats(id, tier)
	for ab in stats.get("abilities", []):
		abilities.append(str(ab.get("type", "")))
	var wants_helper := abilities.any(func(x): return x in ["speed_aura", "damage_aura", "rage"])
	var base_speed := 0.0
	var base_damage := 0.0
	if wants_helper:
		helper = _place(_helper_id, 0, _helper_near(id, _trap_cell if _is_trap(id) else _anchor), false)
		if game.has_method("_update_auras"):
			game._update_auras()
		base_speed = helper.speed_bonus
		base_damage = helper.damage_bonus
	var trap := _is_trap(id)
	var t: Node = _place(id, tier, _trap_cell if trap else _anchor, true)
	# eigene Kopie der Werte, Chancen auf 100 %
	t.stats = t.stats.duplicate(true)
	for ab in t.stats.get("abilities", []):
		if ab.has("chance"):
			ab.chance = 1.0
	_prepare(t)
	if game.has_method("_update_auras"):
		game._update_auras()
	_wave_running()
	_enemies_for(t)
	var detect_target: Node = null
	if abilities.has("detect"):
		detect_target = _enemy(false, t.pos + Vector2(0.3, -0.3), 100.0)
		detect_target.invisible = true
	var seen := {}
	var gold0 := _gold()
	var time := 0.0
	var needs := _needs(t, abilities)
	Engine.time_scale = SCALE
	while time < MAX_TIME:
		await get_tree().process_frame
		time += get_process_delta_time()
		for e in game.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			_pin(e)
			if e.slow_time > 0.0 and e.slow_factor > 0.0:
				seen.slow = true
			if e.poison_time > 0.0 and e.poison_dps > 0.0:
				seen.poison = true
			if e.stun_time > 0.0:
				seen.stun = true
			if e.armor_reduction > 0.0:
				seen.armor = true
			if e.stacks > 0.0:
				seen.stacks = true
			if e.has_meta("eeve_amplify"):
				seen.amplify = true
			if e.has_meta("eeve_burn"):
				seen.burn_mark = true
		if helper != null:
			if helper.speed_bonus > base_speed:
				seen.helper_speed = true
			if helper.damage_bonus > base_damage:
				seen.helper_damage = true
		# Kopfgeld- und Erfahrungs-Aura wirken auch auf den Tower selbst
		if "bounty_bonus" in t and t.bounty_bonus > 0.0:
			seen.bounty_aura = true
		if "xp_bonus" in t and t.xp_bonus > 0.0:
			seen.xp_aura = true
		if detect_target != null and game.is_detected(detect_target):
			seen.detect = true
		_collect(t, seen, gold0)
		# Zusatzschaden gegen Luft: der Tower trifft sonst nur den vordersten Bodengegner
		if needs.has("air_bonus") and t.p_ground > 0.0 and t.p_air == 0.0:
			for e in game.enemies.duplicate():
				if not e.flying:
					game._remove_enemy(e)
		if time >= MIN_TIME and needs.all(func(k): return seen.has(k) or k in ["wave_damage", "explosion", "life"]):
			break
	Engine.time_scale = 1.0
	_collect(t, seen, gold0)
	if needs.has("explosion"):
		_explode(t, seen)
	if needs.has("life"):
		_life(t, seen)
	if needs.has("wave_damage"):
		_set_wave(1)
		var low := 0.0
		for i in 20:
			low += t._roll_damage()
		_set_wave(30)
		var high := 0.0
		for i in 20:
			high += t._roll_damage()
		_set_wave(10)
		if high > low * 1.05:
			seen.wave_damage = true
	var missing: Array = needs.filter(func(k): return not seen.has(k))
	var unknown: Array = abilities.filter(func(x): return not NEEDS.has(x) and x != "")
	var dmg: float = t.total_damage
	var label := "%s%s" % [id, (" Stufe %d" % tier) if (Database.towers.get(id, {}).get("tiers", []) as Array).size() > 1 else ""]
	var problems := []
	if not missing.is_empty():
		problems.append("wirkt nicht: " + ", ".join(missing.map(_why)))
	if not unknown.is_empty():
		problems.append("Fähigkeit ohne Prüfung: " + ", ".join(unknown))
	var todo := _missing(id)
	if not todo.is_empty():
		problems.append("fehlt noch (Original): " + ", ".join(todo))
	rows.append([id, tier, dmg, abilities, "; ".join(problems), time])
	if needs.is_empty() and abilities.is_empty():
		print("INFO %s: greift nicht an und hat keine Fähigkeit (Blocker, Laden …)" % label)
	check(problems.is_empty(), "%s: Schaden %d in %.1f s, Fähigkeiten %s %s" % [label, roundi(dmg), time, abilities, "; ".join(problems)])
	_remove(t)
	_remove(helper)
	_clear_enemies()
	if "effects" in game and game.effects != null:
		game.effects.clear()
	await get_tree().process_frame


func _stats(id: String, tier: int) -> Dictionary:
	return Database.tower_tier(id, tier)


func _is_trap(id: String) -> bool:
	return str(Database.towers.get(id, {}).get("kind", "tower")) == "trap"


## Fähigkeiten des Originals, die im Spiel noch fehlen (je Modus aus den Daten).
func _missing(_id: String) -> Array:
	return []


## Vor dem Lauf, je Modus (z. B. Gärtnerei-Wasser).
func _prepare(_t: Node) -> void:
	pass


func _needs(t: Node, abilities: Array) -> Array:
	var out := []
	if t.can_attack():
		out += ["primary", "damage"]
	for i in abilities.size():
		var type: String = abilities[i]
		var ab: Dictionary = t.stats.abilities[i]
		match type:
			"gold_on_hit":
				if int(ab.get("gold", 0)) <= 0 and float(ab.get("gold_per_wave", 0)) <= 0.0:
					continue
			"area_debuff":
				if float(ab.get("armor", 0.0)) > 0.0:
					out.append("armor")
				if float(ab.get("slow", 0.0)) > 0.0:
					out.append("slow")
				if float(ab.get("dps", 0.0)) > 0.0:
					out.append("poison")
				continue
			"pulse":
				if float(ab.get("stun", 0.0)) > 0.0:
					out.append("stun")
				if float(ab.get("slow", 0.0)) > 0.0:
					out.append("slow")
				if float(ab.get("damage", 0.0)) > 0.0:
					out.append("cast_hits")
			"nova_spell":
				if float(ab.get("slow", 0.0)) > 0.0:
					out.append("slow")
			"burn_aura":
				out.append("damage")
		for k in NEEDS.get(type, []):
			if not out.has(k):
				out.append(k)
	return out


func _collect(t: Node, seen: Dictionary, gold0: int) -> void:
	if t.p_primary > 0:
		seen.primary = true
	if t.total_damage > 0.0:
		seen.damage = true
	if t.p_secondary > 0:
		seen.secondary = true
	if t.p_multi >= 2:
		seen.multi = true
	if t.p_crit > 0:
		seen.crit = true
	if t.p_ground > 0.0 and t.p_air > t.p_ground * 1.5:
		seen.air_bonus = true
	if _gold() > gold0:
		seen.gold = true
	var calls: Dictionary = t.p_calls
	if int(calls.get("nova", [0, 0])[1]) > 0:
		seen.nova = true
	if int(calls.get("cone", [0, 0])[1]) > 0:
		seen.cone = true
	if int(calls.get("aura", [0, 0])[1]) > 0:
		seen.aura_damage = true
	if int(calls.get("chain", [0, 0])[1]) > 0:
		seen.chain = true
	if int(calls.get("hp_cut", [0, 0])[1]) > 0:
		seen.hp_cut = true
	if int(calls.get("cast", [0, 0])[0]) > 0:
		seen.cast = true
	if int(calls.get("cast", [0, 0])[1]) > 0:
		seen.cast_hits = true
	if int(calls.get("cast", [0, 0, 0])[2]) >= 2:
		seen.chain_hits = true


## Flammenrost: ein markierter Bodengegner stirbt, die Explosion muss andere treffen.
func _explode(t: Node, seen: Dictionary) -> void:
	var burned = null
	for e in game.enemies:
		if not e.dead and not e.flying and e.has_meta("eeve_burn"):
			burned = e
			break
	if burned == null:
		return
	var before := {}
	for e in game.enemies:
		if e != burned:
			before[e] = e.hp
	var dmg0: float = t.total_damage
	burned.take_raw_damage(burned.hp + 1.0)
	for e in before:
		if is_instance_valid(e) and not e.flying and e.hp < before[e]:
			seen.explosion = true
	if t.total_damage <= dmg0:
		seen.erase("explosion")


## Kill-Effekt "life" (Maul): je Modus, setzt seen.life, wenn ein Kill Leben zurückbringt.
func _life(_t: Node, _seen: Dictionary) -> void:
	pass


func _why(k: String) -> String:
	const TEXT := {
		"primary": "trifft sein Ziel nicht", "damage": "macht keinen Schaden", "secondary": "keine Nebenziele (Fläche/Kette)",
		"multi": "kein Mehrfachschuss", "slow": "verlangsamt nicht", "poison": "vergiftet nicht", "crit": "kein kritischer Treffer", "air_bonus": "kein Zusatzschaden gegen Luft",
		"armor": "senkt keine Rüstung", "stun": "betäubt nicht", "gold": "kein Gold", "stacks": "kein steigender Schaden",
		"nova": "Nova trifft niemanden", "helper_speed": "Tempo-Aura kommt beim Nachbarn nicht an",
		"helper_damage": "Schadens-Buff kommt beim Nachbarn nicht an", "aura_damage": "Brand-Aura macht keinen Schaden", "bounty_aura": "Kopfgeld-Aura wirkt nicht", "xp_aura": "Erfahrungs-Aura wirkt nicht",
		"wave_damage": "Schaden steigt nicht mit der Welle", "cone": "Kegel trifft niemanden", "amplify": "Ertränken wirkt nicht",
		"burn_mark": "Flammenrost markiert nicht", "explosion": "keine Explosion beim Tod", "chain": "Kettenblitz springt nicht",
		"hp_cut": "Wolke nimmt keine Leben", "cast": "Zauber wird nie gewirkt", "cast_hits": "Zauber trifft niemanden",
		"chain_hits": "Kettenblitz springt nicht", "detect": "enttarnt nicht", "life": "Kill bringt kein Leben",
	}
	return "%s (%s)" % [k, TEXT.get(k, "?")]


func _write_report() -> void:
	if report_path == "":
		return
	var lines := ["# Tower-Prüfung %s" % mode, "", "Erzeugt von tests/towers_%s_test.gd (tools/tower_pruefen.sh)." % mode,
		"Jeder Tower einzeln gegen festgehaltene Gegner, Chancen auf 100 %%, Auren-Tower neben einem Helfer.", "",
		"| Tower | Stufe | Schaden | Fähigkeiten | Ergebnis |", "|---|---|---|---|---|"]
	for r in rows:
		lines.append("| %s | %d | %d | %s | %s |" % [r[0], r[1], roundi(r[2]), ", ".join(r[3]), "✓" if r[4] == "" else "✗ " + r[4]])
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f == null:
		printerr("Bericht nicht schreibbar: ", report_path)
		return
	f.store_string("\n".join(lines) + "\n")
