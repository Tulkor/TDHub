extends GameSystem
## Ziele finden: der am weitesten gelaufene Gegner in Reichweite eines Towers, alle Gegner in einem Kreis,
## der nächste Gegner. Gleich für alle Modi; wie ein Modus Gegner beschreibt, sagt cfg:
##   position  "pos"        e.pos ist schon Vector2 (GemTD-Familie, Maul)
##             "xz"         e.position (Vector3) auf dem Boden (Bollwerk)
##             "global_xz"  e.global_position (Vector3) auf dem Boden (Survivors)
##   radius    ""           Gegner sind Punkte
##             "radius"     e.radius zählt zur Reichweite (Bollwerk)
##             "half_size"  e.size / 2 zählt zur Reichweite (Survivors)
## Gegnerliste: game.enemies; tote Gegner (e.dead) zählen nie. Wer zuerst kommt: e.traveled (Tower-Ziele).


## Bodenpunkt eines Gegners als Vector2.
func ground(e) -> Vector2:
	match str(cfg.get("position", "pos")):
		"xz":
			return Vector2(e.position.x, e.position.z)
		"global_xz":
			var g: Vector3 = e.global_position
			return Vector2(g.x, g.z)
	return e.pos


## Wie weit der Gegner über seinen Mittelpunkt hinausreicht.
func reach(e) -> float:
	match str(cfg.get("radius", "")):
		"radius":
			return float(e.radius)
		"half_size":
			return float(e.size) * 0.5
	return 0.0


## Bis zu count Ziele für Tower t (t.can_target, t.in_range), am weitesten gelaufene zuerst.
func find_targets(t, count: int) -> Array:
	var enemies: Array = game.enemies
	if count == 1:
		# häufigster Fall ohne Lambda, Zwischenliste und Sortieren
		var best = null
		for e in enemies:
			if not e.dead and (best == null or e.traveled > best.traveled) and t.can_target(e) and t.in_range(e):
				best = e
		return [] if best == null else [best]
	var list := enemies.filter(func(e): return not e.dead and t.can_target(e) and t.in_range(e))
	list.sort_custom(func(a, b): return a.traveled > b.traveled)
	return list.slice(0, count)


## Wie find_targets, aber mit eigener Reichweite r um t.pos statt t.in_range.
func find_targets_in(t, r: float, count: int) -> Array:
	var enemies: Array = game.enemies
	var r2 := r * r
	if count == 1:
		var best = null
		for e in enemies:
			if not e.dead and (best == null or e.traveled > best.traveled) and e.pos.distance_squared_to(t.pos) <= r2 \
					and t.can_target(e):
				best = e
		return [] if best == null else [best]
	var list := enemies.filter(func(e): return not e.dead and t.can_target(e) and e.pos.distance_squared_to(t.pos) <= r2)
	list.sort_custom(func(a, b): return a.traveled > b.traveled)
	return list.slice(0, count)


## Alle lebenden Gegner, die den Kreis um p mit radius berühren (mit ihrer Ausdehnung laut cfg.radius).
func enemies_in_radius(p: Vector2, radius: float) -> Array:
	var out := []
	if str(cfg.get("radius", "")) == "" and str(cfg.get("position", "pos")) == "pos":
		var r2 := radius * radius
		for e in game.enemies:
			if not e.dead and e.pos.distance_squared_to(p) <= r2:
				out.append(e)
		return out
	for e in game.enemies:
		if not e.dead and ground(e).distance_to(p) <= radius + reach(e):
			out.append(e)
	return out


## Nächster lebender Gegner, dessen Rand höchstens r von p entfernt ist (skip: diese nicht).
func nearest(p: Vector2, r: float, skip: Array = []):
	var best = null
	var best_d := INF
	for e in game.enemies:
		if e.dead or skip.has(e):
			continue
		var d := ground(e).distance_to(p) - reach(e)
		if d <= r and d < best_d:
			best_d = d
			best = e
	return best
