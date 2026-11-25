extends Node
## Misst während eines Testlaufs je Welle, wie knapp es war, unabhängig vom Bot (alle Modi mit Enemy-Gegnern):
##   druck   effektive Leben aller erschienenen Gegner (Leben / Rüstungsfaktor, so wie sie wirklich kamen,
##           also mit Schwierigkeit, Aufstieg und Koop-Faktor)
##   knapp   wie weit der vorderste Gegner kam (Anteil des Wegs, 0..1; 1 = durchgebrochen)
##   rest    Anteil der Gegner-Leben, der beim Durchbruch noch übrig war (0 = alles getötet)
##   gold    Gold des Spielers zu Beginn der Welle
##   leben   Leben zu Beginn der Welle
## Der Bot setzt nichts: messung.ziel = bot, dann liest sie bot.game, sobald es da ist.

var ziel: Node
var _seen := {}
var druck: Array = []
var knapp: Array = []
var rest: Array = []
var gold: Array = []
var leben: Array = []
var _hp_wave: Array = []


func _process(_delta: float) -> void:
	var game = ziel.get("game") if is_instance_valid(ziel) else null
	if game == null or not is_instance_valid(game) or not "enemies" in game:
		return
	var w := welle_von(game)
	if w < 0:
		return
	_grow(w)
	# Stand zu Beginn der Welle = letzter Wert, bevor ihr erster Gegner auftaucht (nach Setup und Bauphase)
	if _hp_wave[w] == 0.0:
		gold[w] = gold_von(game)
		leben[w] = leben_von(game)
	for e in game.enemies:
		if not is_instance_valid(e):
			continue
		var id: int = e.get_instance_id()
		var ew: int = _seen.get(id, -1)
		if ew < 0:
			ew = w
			_seen[id] = w
			druck[w] += ehp(e)
			_hp_wave[w] += maxf(float(e.max_hp), 0.0)
		var p: float = e.route_progress() if e.has_method("route_progress") else 0.0
		if p > knapp[ew]:
			knapp[ew] = clampf(p, 0.0, 1.0)
		# kurz vor dem Ziel: wie viel Leben trägt der Gegner noch mit hinaus?
		if p >= 0.97 and e.max_hp > 0.0:
			var left := clampf(float(e.hp) / float(e.max_hp), 0.0, 1.0) * float(e.max_hp)
			var key := "r%d" % id
			if not _seen.has(key):
				_seen[key] = true
				rest[ew] += left


func _grow(w: int) -> void:
	while druck.size() <= w:
		druck.append(0.0)
		knapp.append(0.0)
		rest.append(0.0)
		gold.append(0)
		leben.append(0.0)
		_hp_wave.append(0.0)


## Ergebnis für die ERGEBNIS-Zeile (gerundet, damit die JSON-Zeile kurz bleibt).
func result() -> Dictionary:
	var r := []
	for i in rest.size():
		r.append(snappedf(rest[i] / _hp_wave[i], 0.001) if _hp_wave[i] > 0.0 else 0.0)
	return {
		"druck": druck.map(func(v): return roundi(v)),
		"knapp": knapp.map(func(v): return snappedf(v, 0.001)),
		"rest": r,
		"gold_verlauf": gold,
		"leben_verlauf": leben.map(func(v): return snappedf(v, 0.1)),
	}


## Effektive Leben eines Gegners: so viel roher Schaden ist nötig (WC3-Rüstungsformel wie Enemy.take_damage).
static func ehp(e) -> float:
	var a := float(e.armor)
	var f := 1.0
	if a > 0.0:
		f = 1.0 - 0.06 * a / (1.0 + 0.06 * a)
	elif a < 0.0:
		f = 2.0 - pow(0.94, -a)
	return maxf(float(e.max_hp), 0.0) / maxf(f, 0.01)


## Laufende Welle (0-basiert) in allen Modi; Shopping Maul zählt Level ab 1.
static func welle_von(game) -> int:
	if "wave_index" in game:
		return int(game.wave_index)
	if "level" in game:
		return int(game.level) - 1
	return -1


static func gold_von(game) -> int:
	if "gold" in game:
		return int(game.gold)
	if "players" in game and not game.players.is_empty() and "gold" in game.players[0]:
		return int(game.players[0].gold)
	return 0


static func leben_von(game) -> float:
	if "portal" in game:
		return float(game.portal)
	return float(game.lives) if "lives" in game else 0.0
