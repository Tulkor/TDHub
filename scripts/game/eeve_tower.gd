class_name EeveTower
extends Tower
## Tower und Fallen in eeveTD. Schießt wie ein GemTD-Tower und kennt dazu die Sonderfähigkeiten der
## Dual-Tower und Fallen (Werte in data/towers/eeve_*.json, Texte stehen als "text" in den Daten):
##   area_debuff      ätzt alle Gegner um das Ziel (Rüstung, Tempo, Gift)
##   amplify          Ziel nimmt eine Weile mehr Schaden (Ertränken)
##   chain            Kettenblitz mit eigenem Schaden, der mit jedem Sprung wächst
##   death_explosion  getroffene Gegner brennen und explodieren, wenn sie in der Zeit sterben
##   pulse            Zauber mit eigener Abklingzeit (Zeitsperre, Aufspießen, Verhexen)
##   rage             Abklingzeit-Buff: +Schaden für Tower im Umkreis (Feuerbeeren)
##   hp_cut           Gegner verlieren beim Betreten des Radius einmalig einen Teil ihrer Leben
##   orb              Item-Kugel: schießt alle every Sekunden auf einen zufälligen Gegner im Radius (Zauberschaden)
## Items (eeve_items.gd) stecken in items; ihre Werte kommen über set_rogue() und flat_damage dazu.

const EXTRA := ["area_debuff", "amplify", "chain", "death_explosion"]

var rage_left := 0.0       ## Sekunden, die der Schadens-Buff noch wirkt
var _cd := {}              ## Index der Fähigkeit -> Restzeit (pulse, rage)
var items: Array = []      ## eingesetzte Items (ids aus data/eeve_items.json), bleiben im Tower
var extra_slots := 0       ## zusätzliche Item-Plätze aus Erweiterungstränken


func effect_script_native_scopes() -> Array:
	return ["tower", "eeve"]


func set_tower(id: String, t: int) -> void:
	_cd.clear()
	rage_left = 0.0
	super.set_tower(id, t)


func _process(delta: float) -> void:
	super._process(delta)
	if game == null or game.mirror or not game.is_wave_running():
		return
	var list := abilities()
	for i in list.size():
		var ab: Dictionary = list[i]
		match str(ab.get("type", "")):
			"orb":
				var left: float = _cd.get(i, 0.0) - delta
				if left <= 0.0 and _orb(ab):
					left += float(ab.get("every", 0.5))
				_cd[i] = maxf(left, -delta)
			"pulse", "rage":
				var left: float = _cd.get(i, 0.0) - delta
				if left <= 0.0 and _cast(ab):
					left += float(ab.get("every", 10.0))
				_cd[i] = maxf(left, -delta)
			"hp_cut":
				_hp_cut(ab)
	if rage_left > 0.0:
		rage_left -= delta
		if rage_left <= 0.0:
			game._update_auras()


## Gegner, die die Fähigkeit ab treffen darf ("targets" in der Fähigkeit, sonst wie der Angriff).
func _allowed(ab: Dictionary, e) -> bool:
	match str(ab.get("targets", "both")):
		"air":
			return e.flying
		"ground":
			return not e.flying
	return true


## Zauber mit Abklingzeit. true = gewirkt (sonst bleibt er bereit, bis ein Gegner kommt).
func _cast(ab: Dictionary) -> bool:
	if str(ab.type) == "rage":
		if game.enemies_in_radius(pos, range_cells()).is_empty():
			return false
		rage_left = float(ab.get("duration", 8.0))
		game._update_auras()
		game.add_ring(pos, float(ab.radius), color)
		return true
	var hit := []
	if str(ab.get("center", "tower")) == "tower":
		hit = game.enemies_in_radius(pos, float(ab.radius)).filter(func(e): return _allowed(ab, e))
	else:
		var near: Array = game.enemies_in_radius(pos, range_cells()).filter(func(e): return _allowed(ab, e))
		if near.is_empty():
			return false
		near.sort_custom(func(a, b): return a.traveled > b.traveled)
		var first = near[0]
		hit = [first]
		if float(ab.get("radius", 0.0)) > 0.0:
			hit += game.enemies_in_radius(first.pos, float(ab.radius)).filter(func(e): return e != first and _allowed(ab, e))
		game.add_beam(position + Vector3(0, 0.9, 0), first.position, color)
	if hit.is_empty():
		return false
	if ab.has("max"):
		hit = hit.slice(0, int(ab.max))
	for e in hit:
		if float(ab.get("stun", 0.0)) > 0.0:
			e.apply_stun(float(ab.stun))
		if float(ab.get("slow", 0.0)) > 0.0:
			e.apply_slow(float(ab.slow), float(ab.get("duration", 3.0)))
		if float(ab.get("damage", 0.0)) > 0.0:
			_spell(e, float(ab.damage))
	if str(ab.get("center", "tower")) == "tower":
		game.add_ring(pos, float(ab.radius), color)
	return true


## Strahlende Wolke: einmal pro Gegner (auch bei mehreren Wolken) einen Teil der aktuellen Leben.
func _hp_cut(ab: Dictionary) -> void:
	for e in game.enemies_in_radius(pos, float(ab.radius)):
		if e.has_meta("eeve_cut"):
			continue
		e.set_meta("eeve_cut", true)
		var challenge := str(Database.enemies.get(e.enemy_id, {}).get("eeve", {}).get("kind", "")) == "challenge"
		var f := float(ab.get("factor_challenge", ab.factor)) if challenge else float(ab.factor)
		e.last_hit_by = owner_player
		e.last_tower = self
		total_damage += e.take_raw_damage(e.hp * f)
		if e.dead:
			credit_kill(e)


func _hit(e, dmg: float) -> void:
	if e.dead:
		return
	for ab in abilities():
		var type := str(ab.get("type", ""))
		if not type in EXTRA:
			continue
		# Gemeinsame Projektil-Ketten laufen im Tower-Kern; eeve-Ketten haben eigenen Schaden.
		if type == "chain" and ab.has("count"):
			continue
		if ab.has("chance") and randf() >= float(ab.chance):
			continue
		match type:
			"area_debuff":
				for other in game.enemies_in_radius(e.pos, float(ab.radius)):
					if not can_target(other):
						continue
					other.apply_armor_reduction(float(ab.get("armor", 0.0)), float(ab.duration))
					other.apply_slow(float(ab.get("slow", 0.0)), float(ab.duration))
					other.apply_poison(float(ab.get("dps", 0.0)), float(ab.duration), self)
			"amplify":
				e.set_meta("eeve_amplify", {"until": game.clock + float(ab.duration), "bonus": float(ab.bonus)})
			"death_explosion":
				e.set_meta("eeve_burn", {"until": game.clock + float(ab.duration), "tower": self,
						"damage": float(ab.damage), "radius": float(ab.radius)})
			"chain":
				_chain(e, ab)
	if e.dead:
		return
	var amp: Dictionary = e.get_meta("eeve_amplify", {})
	if not amp.is_empty() and float(amp.until) >= game.clock:
		dmg *= 1.0 + float(amp.bonus)
	super._hit(e, dmg)


## Roter Kettenblitz: springt zum nächsten Gegner, jeder Sprung macht mehr Schaden.
func _chain(first, ab: Dictionary) -> void:
	var hit := [first]
	var current = first
	var dmg := float(ab.damage)
	_spell(first, dmg)
	for i in int(ab.get("targets", 4)):
		var next = null
		var best := INF
		for other in game.enemies_in_radius(current.pos, float(ab.get("radius", 3.0))):
			var d: float = other.pos.distance_to(current.pos)
			if not other in hit and can_target(other) and d < best:
				best = d
				next = other
		if next == null:
			break
		dmg *= float(ab.get("growth", 1.0))
		game.add_beam(current.position, next.position, Color("ff3030"))
		hit.append(next)
		_spell(next, dmg)
		current = next


func _spell(e, dmg: float) -> void:
	if e.dead:
		return
	e.last_hit_by = owner_player
	e.last_tower = self
	total_damage += e.take_damage(dmg * (1.0 + damage_bonus + kill_bonus()), "spells")
	if e.dead:
		credit_kill(e)


## Item-Kugel: ein Geschoss auf einen zufälligen Gegner im Radius, Schaden = dps × Abstand (Zauberschaden,
## ohne Element- und Kill-Bonus wie im Original). true = geschossen.
func _orb(ab: Dictionary) -> bool:
	var list: Array = game.enemies_in_radius(pos, float(ab.get("radius", 6.25))).filter(func(e): return not e.dead)
	if list.is_empty():
		return false
	var e = list[randi() % list.size()]
	game.add_beam(position + Vector3(0, 1.1, 0), _hit_point(e), Color(str(ab.get("color", "#c8b0ff"))))
	e.last_hit_by = owner_player
	e.last_tower = self
	total_damage += e.take_damage(float(ab.dps) * float(ab.get("every", 0.5)), "spells")
	if e.dead:
		credit_kill(e)
	return true
