extends GameSystem
## Koop für alle Modi auf game.gd: welche Befehle Mitspieler schicken dürfen, welcher Modus-Stand mitgeht und wer
## gerade weg ist. Den Abgleich selbst (Feld, Tower, Gegner) macht coop_sync.gd. Werte (Basis coop.json, Modus in
## system_cfg.coop): commands + extra_commands, fields (Spielvariablen), tower_meta (Tower-Metadaten).
## Haken: coop_extra() was der Modus darüber hinaus schickt, coop_applied(d, changed) nach dem Übernehmen
## (changed: Namen der fields, die sich geändert haben), on_player_away(p, away) Spielregel für Weggehen.


## Befehle, die ein Mitspieler schicken darf.
func commands() -> Array:
	return Array(cfg.get("commands", [])) + Array(cfg.get("extra_commands", []))


## Modus-Teil des Stands für die Mitspieler (unter "mode", siehe coop_sync.gd → snapshot).
func snapshot() -> Dictionary:
	var s := {}
	var fields: Dictionary = cfg.get("fields", {})
	for key in fields:
		var spec := _spec(fields[key])
		var v = game.get(spec.var)
		if spec.get("ceil", false):
			v = ceili(maxf(float(v), 0.0))
		elif spec.get("keys", false):
			v = (v as Dictionary).keys()
		elif v is Array or v is Dictionary:
			v = v.duplicate(true)
		s[key] = v
	var metas: Array = cfg.get("tower_meta", [])
	if not metas.is_empty():
		var tm := {}
		for m in metas:
			var per := {}
			for t in game.all_towers():
				per[tower_key(t)] = int(t.get_meta(m, 0))
			tm[m] = per
		s["_tm"] = tm
	var extra = hook("coop_extra", [], {})
	if extra is Dictionary:
		s.merge(extra, true)
	return s


## Stand vom Host übernehmen (Mitspieler).
func apply(d: Dictionary) -> void:
	var changed := []
	var fields: Dictionary = cfg.get("fields", {})
	for key in fields:
		if not d.has(key):
			continue
		var spec := _spec(fields[key])
		var old = game.get(spec.var)
		var v = d[key]
		if spec.get("keys", false):
			var dict := {}
			for k in v:
				dict[int(k) if k is float else k] = true
			v = dict
		elif old is Array or old is Dictionary:
			if not (v is Array or v is Dictionary) or v.is_empty():
				continue
		elif old is int:
			v = int(v)
		elif old is float:
			v = float(v)
		elif old is bool:
			v = bool(v)
		if v != old:
			changed.append(key)
		game.set(spec.var, v)
	var tm: Dictionary = d.get("_tm", {})
	for m in tm:
		var per: Dictionary = tm[m]
		for t in game.all_towers():
			t.set_meta(m, int(per.get(tower_key(t), 0)))
	hook("coop_applied", [d, changed])


## Spieler p ist weg (Verbindung weg, Spiel verlassen) oder wieder da. Was das für die Runde heißt, sagt der Modus.
func set_away(p: int, away: bool) -> void:
	if p < 0 or p >= game.players.size() or game.players[p].away == away:
		return
	game.players[p].away = away
	hook("on_player_away", [p, away])


## Schlüssel eines Towers im Stand: Feld und ob Falle.
static func tower_key(t) -> String:
	return "%d,%d,%s" % [t.cell.x, t.cell.y, t.is_trap()]


func _spec(s) -> Dictionary:
	return s if s is Dictionary else {"var": str(s)}
