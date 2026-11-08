extends GameSystem
## Gold für alle Modi mit Spielern (game.players[p].gold): Einnahmen aus Kills und Fähigkeiten mit
## Einkommens-Faktor je Welle, Bruchteile werden gesammelt (gold_frac, falls der Spieler das Feld hat),
## Gold ohne Besitzer wird auf alle Spieler verteilt. Werte (Basis economy.json, Modus in system_cfg):
##   income_from_balance  true: Faktor und Anstieg aus data/balance.json (gold_income_factor, gold_income_ramp)
##   income               Faktor, wenn nicht aus balance.json (1.0 = volles Gold)
##   ramp                 {from_wave, to_wave, to_factor}: Faktor steigt linear bis to_factor, leer = fest
##   split_unowned        Gold ohne Spieler (p < 0) auf alle verteilen; sonst bekommt es der handelnde Spieler
## Haken: current_wave() für die Welle, acting für den handelnden Spieler, _refresh_hud() nach add().


## Einkommens-Faktor in Welle wave (1-basiert).
func income_factor(wave: int) -> float:
	var start := float(cfg.get("income", 1.0))
	var ramp: Dictionary = cfg.get("ramp", {})
	if cfg.get("income_from_balance", false):
		start = float(Database.balance.get("gold_income_factor", 1.0))
		ramp = Database.balance.get("gold_income_ramp", {})
	if ramp.is_empty():
		return start
	var a := int(ramp.get("from_wave", 1))
	var b := int(ramp.get("to_wave", a))
	var t := clampf(float(wave - a) / maxf(b - a, 1), 0.0, 1.0)
	return lerpf(start, float(ramp.get("to_factor", start)), t)


## Gold aus Kills und Fähigkeiten, mit income_factor der aktuellen Welle. p < 0: ohne Besitzer.
func earn(amount: float, p := -1) -> void:
	var players: Array = game.players
	if p < 0 or p >= players.size():
		if cfg.get("split_unowned", true):
			for i in players.size():
				earn(amount / players.size(), i)
			return
		p = int(game.get("acting")) if "acting" in game else 0
	var factor := income_factor(int(hook("current_wave", [], 1)))
	_credit(players[p], amount * factor)


## Gold direkt gutschreiben (ohne Faktor), p < 0 = handelnder Spieler.
func add(amount: int, p := -1) -> void:
	var players: Array = game.players
	if p < 0 or p >= players.size():
		p = int(game.get("acting")) if "acting" in game else 0
	players[p].gold += amount
	hook("_refresh_hud")


func _credit(pl, amount: float) -> void:
	if "gold_frac" in pl:
		pl.gold_frac += amount
		var whole := floori(pl.gold_frac)
		pl.gold += whole
		pl.gold_frac -= whole
	else:
		pl.gold += roundi(amount)
