class_name HdBossBrain
extends RefCounted
## Gemeinsamer Ablauf für Endbosse: faire Rotation, feste Pausen, Phasen und begrenzte Erinnerungen/Adds.
## Bewegung, Aggro, Leine, CC und Treffer bleiben in der vorhandenen Gegner-KI.

var enemy: HdEnemy
var cursor := 0
var history: Array[Vector3] = []
var next_sample := 0.0
var teles: Array[WeakRef] = []


func _init(owner_enemy: HdEnemy) -> void:
	enemy = owner_enemy


func rotation() -> Array:
	if enemy.phase > 0:
		return enemy.def.phases[enemy.phase - 1].get("rotation", enemy.def.rotation)
	return enemy.def.rotation


func observe(now: float) -> void:
	var hero = enemy.game.hero
	if now >= next_sample and hero != null and hero.alive():
		next_sample = now + 0.5
		history.append(hero.position)
		if history.size() > 6:
			history.pop_front()


func echo_points(count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in history:
		if point.distance_to(enemy.anchor_point()) <= float(enemy.def.leash):
			result.append(point)
	if result.is_empty():
		result.append(enemy.target.position if enemy.target != null else enemy.position)
	result.reverse()
	var samples: Array[Vector3] = []
	for i in count:
		samples.append(result[mini(i, result.size() - 1)])
	return samples


func try_cast(now: float) -> bool:
	if now < enemy.gap_until:
		return false
	var sequence := rotation()
	for offset in sequence.size():
		var index := (cursor + offset) % sequence.size()
		var aid := str(sequence[index])
		if not enemy.abilities().has(aid) or now < float(enemy.ab_ready.get(aid, 0.0)):
			continue
		var ability: Dictionary = enemy.game.ability_defs[aid]
		if str(ability.kind) == "summon" and remaining_adds() <= 0:
			continue
		if enemy._can_cast(ability):
			cursor = (index + 1) % sequence.size()
			enemy.start_cast(aid, now)
			return true
	return false


func recover(now: float) -> void:
	var recovery := float(enemy.def.encounter.get("recovery", 1.1))
	if enemy.phase > 0:
		recovery = float(enemy.def.phases[enemy.phase - 1].get("recovery", recovery))
	enemy.gap_until = maxf(enemy.gap_until, now + recovery)


func enter_phase(now: float) -> void:
	if enemy.casting():
		enemy.cancel_cast(true)
	cursor = 0
	enemy.gap_until = maxf(enemy.gap_until, now + float(enemy.def.encounter.get("phase_pause", 2.0)))


func remaining_adds() -> int:
	var count := 0
	for unit in enemy.game.enemies:
		if not unit.dead and int(unit.get_meta("boss_owner", 0)) == enemy.get_instance_id():
			count += 1
	return maxi(int(enemy.def.encounter.get("max_adds", 8)) - count, 0)


func track(tele: HdTelegraph) -> void:
	if teles.size() >= 64:
		teles = teles.filter(func(w): return w.get_ref() != null)
	teles.append(weakref(tele))


func cleanup() -> void:
	var game = enemy.game
	var owner_id := enemy.get_instance_id()
	for weak in teles:
		var tele = weak.get_ref()
		if tele != null:
			tele.queue_free()
	teles.clear()
	for i in range(game.pools.size() - 1, -1, -1):
		var pool: Dictionary = game.pools[i]
		if int(pool.get("owner_id", 0)) == owner_id:
			if is_instance_valid(pool.tele):
				pool.tele.queue_free()
			game.pools.remove_at(i)
	for i in range(game.projectiles.size() - 1, -1, -1):
		var shot: Dictionary = game.projectiles[i]
		if shot.get("src") == enemy:
			if is_instance_valid(shot.node):
				shot.node.queue_free()
			shot["cancelled"] = true
	for unit in game.enemies.duplicate():
		if not unit.dead and int(unit.get_meta("boss_owner", 0)) == owner_id:
			game._remove(unit)
