extends GameSystem
## Schwierigkeit und Aufstiegsstufen (+1, +2, … über ascension.gd) für alle Modi.
## Woher die Liste der Schwierigkeiten kommt, sagt cfg.source (Basis difficulty.json, Modus in system_cfg):
##   "session"  feste Liste Session.DIFFICULTIES, gewählt in Session.difficulty (GemTD, Roguelike)
##   "rules"    game.rules.difficulties, gewählt in game.difficulty (eeveTD, Randgruppen, YouTD, Maul)
##   "cfg"      game.cfg.difficulties, gewählt in game.difficulty (Bollwerk)
## Aufstieg: game.ascension (Stufe), Regeln je Profil-Schlüssel (Haken profile_mode, sonst cfg.key).

var _asc_cache := {}


## Profil-/Aufstiegs-Schlüssel des Modus.
func key() -> String:
	return str(hook("profile_mode", [], cfg.get("key", "")))


## Alle Schwierigkeiten des Modus (Dictionaries mit name, factor …).
func list() -> Array:
	match str(cfg.get("source", "session")):
		"rules":
			return game.rules.get("difficulties", []) if "rules" in game else []
		"cfg":
			return game.cfg.get("difficulties", []) if "cfg" in game else []
	return Session.DIFFICULTIES


func count() -> int:
	return list().size()


## Index der gewählten Schwierigkeit in list().
func index() -> int:
	if str(cfg.get("source", "session")) == "session":
		return Session.difficulty
	return int(game.difficulty) if "difficulty" in game else 0


## Die gewählte Schwierigkeit (bei Index außerhalb: die nächste gültige).
func current() -> Dictionary:
	var l := list()
	return l[clampi(index(), 0, l.size() - 1)] if not l.is_empty() else {}


## Name der gewählten Schwierigkeit mit Aufstiegsstufe, z. B. „Schwer +3“.
func label() -> String:
	var n := Session.difficulty_name() if str(cfg.get("source", "session")) == "session" else str(current().get("name", ""))
	return Ascension.full_name(n, level())


## Gewählte Aufstiegsstufe (0 = keine).
func level() -> int:
	return int(game.ascension) if "ascension" in game else 0


## Index der Schwierigkeit, auf der Aufstieg möglich ist.
func top() -> int:
	return Ascension.top(key(), count())


## Gewünschte Stufe übernehmen: nur auf der höchsten Schwierigkeit, höchstens bis max_level des Modus.
func take_ascension(requested: int) -> int:
	var asc := maxi(requested, 0) if index() == top() else 0
	var cap := Ascension.max_level(key())
	if cap > 0:
		asc = mini(asc, cap)
	if "ascension" in game:
		game.ascension = asc
	return asc


## Werte-Änderungen der aktuellen Stufe (zwischengespeichert, bis sich die Stufe ändert).
func ascension_mods() -> Dictionary:
	if int(_asc_cache.get("level", -1)) != level():
		_asc_cache = Ascension.mods(key(), level())
		_asc_cache.level = level()
	return _asc_cache


## Aufstiegsstufe auf einen neuen Gegner anwenden.
func apply_ascension(e) -> void:
	if level() > 0:
		Ascension.apply(e, ascension_mods())
