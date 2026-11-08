class_name Leveling
extends RefCounted
## Gemeinsames Level- und EP-System (Erfahrungspunkte) für Tower in allen Modi, Daten in data/leveling.json.
## Ein Modus nutzt ein Profil (modes), ein Profil sagt:
##   max_level, curve (EP je Level-Stufe: konstant, linear, exponentiell, eigene Formel oder Tabelle, mal factor),
##   ep (EP je Kill, Faktoren für Boss/Flieger, Anteil der Gegnerleben), per_level (Boni je Level),
##   unlocks (ab Level freigeschaltete Werte oder Fähigkeiten), towers (Abweichungen je Tower-ID).
## Die Tower (tower.gd) sammeln EP mit gain_ep() und holen sich hier Level und Boni. GemTD, eeveTD und
## Randgruppen nutzen es direkt; YouTD behält seine eigene Spiellogik, holt aber die EP-Kurven (Tower und
## Spieler) von hier (youtd_data.gd); Shopping Maul hat wie im Original keine Tower-Level.

const STATS := ["damage", "speed", "range"]
const STAT_NAMES := {"damage": "Schaden", "speed": "Tempo", "range": "Reichweite"}
const CURVE_TYPES := ["konstant", "linear", "exponentiell", "formel", "tabelle"]
## Formeln hinter den festen Kurventypen (Variablen wie bei "formel")
const FORMULAS := {
	"konstant": "base",
	"linear": "base + step * (level - 1)",
	"exponentiell": "base * pow(growth, level - 1)",
}
const VARS := ["level", "base", "step", "growth"]

static var _cache := {}


## Nach dem Neuladen der Daten (Database.reload) oder in Tests nach Änderungen an Database.leveling.
static func reset() -> void:
	_cache.clear()


## Profil eines Modus ("" = keine Tower-Level in diesem Modus).
static func mode_profile_id(mode: String) -> String:
	return str(Database.leveling.get("modes", {}).get(mode, ""))


## Profil mit allem, was es über extends erbt ({} = gibt es nicht).
static func profile(id: String, _depth := 0) -> Dictionary:
	var all: Dictionary = Database.leveling.get("profiles", {})
	if id == "" or not all.has(id) or _depth > 8:
		return {}
	var own: Dictionary = all[id]
	var p := profile(str(own.get("extends", "")), _depth + 1) if own.has("extends") else {}
	p = p.duplicate(true)
	for k in own:
		if k in ["curve", "ep", "per_level", "towers"] and own[k] is Dictionary and p.get(k) is Dictionary:
			p[k].merge(own[k], true)
		else:
			p[k] = own[k].duplicate(true) if own[k] is Dictionary or own[k] is Array else own[k]
	p.id = id
	return p


## Fertiges Profil für einen Tower in einem Modus, mit den Abweichungen des Towers und der EP-Tabelle (_table).
## {} = dieser Tower steigt in diesem Modus nicht im Level.
static func for_tower(mode: String, tower_id: String) -> Dictionary:
	var key := mode + "|" + tower_id
	if _cache.has(key):
		return _cache[key]
	var p := profile(mode_profile_id(mode))
	if not p.is_empty():
		var tw: Dictionary = p.get("towers", {}).get(tower_id, {})
		for k in tw:
			match k:
				"unlocks":
					p.unlocks = p.get("unlocks", []) + tw.unlocks
				"curve", "per_level", "ep":
					var d: Dictionary = p.get(k, {})
					d.merge(tw[k], true)
					p[k] = d
				_:
					p[k] = tw[k]
		p.erase("towers")
		p._table = table(p)
	_cache[key] = p
	return p


## Profil für einen Tower im laufenden Spiel (Modus über game.profile_mode()). Profile mit "system"
## (YouTD) rechnet der Modus selbst, dort sammelt tower.gd keine EP.
static func for_game(game, tower_id: String) -> Dictionary:
	if game == null or not game.has_method("profile_mode"):
		return {}
	var p := for_tower(str(game.profile_mode()), tower_id)
	return {} if p.has("system") else p


## Profil nach Name mit fertiger EP-Tabelle (_table), zwischengespeichert (z. B. Spieler-Level).
static func cached(id: String) -> Dictionary:
	var key := "#" + id
	if not _cache.has(key):
		var p := profile(id)
		if not p.is_empty():
			p._table = table(p)
		_cache[key] = p
	return _cache[key]


## EP, die die Stufe von Level n−1 auf n kostet (vor factor).
static func step_cost(curve: Dictionary, n: int) -> float:
	var type := str(curve.get("type", "konstant"))
	if type == "tabelle":
		var t: Array = curve.get("table", [])
		if t.is_empty():
			return float(curve.get("base", 10))
		return float(t[clampi(n - 1, 0, t.size() - 1)])
	var formula := str(curve.get("formula", "")) if type == "formel" else str(FORMULAS.get(type, "base"))
	var v = evaluate(formula, n, curve)
	return float(v) if v is float or v is int else float(curve.get("base", 10))


## Rechnet eine Formel für Level n aus, null bei Fehler (falsche Schreibweise, unbekannte Funktion).
static func evaluate(formula: String, n: int, curve: Dictionary):
	var ex := Expression.new()
	if ex.parse(formula, PackedStringArray(VARS)) != OK:
		return null
	var v = ex.execute([float(n), float(curve.get("base", 10)), float(curve.get("step", 0)), float(curve.get("growth", 1.0))], null, false)
	if ex.has_execute_failed() or not (v is float or v is int) or is_nan(float(v)) or is_inf(float(v)):
		return null
	return v


## Fehlertext zu einer Formel ("" = in Ordnung), für Editoren und Tests.
static func formula_error(formula: String) -> String:
	var ex := Expression.new()
	if ex.parse(formula, PackedStringArray(VARS)) != OK:
		return ex.get_error_text()
	for n in [1, 2, 10]:
		if evaluate(formula, n, {"base": 10, "step": 1, "growth": 1.1}) == null:
			return "Formel lässt sich für Level %d nicht ausrechnen" % n
	return ""


## EP, die man insgesamt für jedes Level braucht: [0, Level 1, Level 2, …, max_level]. Jede Stufe kostet mindestens 1.
static func table(p: Dictionary) -> Array:
	var curve: Dictionary = p.get("curve", {})
	var factor := float(curve.get("factor", 1.0))
	var t := [0]
	for n in range(1, int(p.get("max_level", 0)) + 1):
		t.append(int(t[-1]) + maxi(roundi(step_cost(curve, n) * factor), 1))
	return t


## Level bei so vielen EP.
static func level_at(p: Dictionary, ep: float) -> int:
	var t: Array = p.get("_table", [])
	if t.is_empty():
		t = table(p)
	var lv := 0
	while lv + 1 < t.size() and ep + 0.0001 >= float(t[lv + 1]):
		lv += 1
	return lv


## EP für einen Kill dieses Gegners (vor den Faktoren des Towers).
static func kill_ep(p: Dictionary, e) -> float:
	var ep: Dictionary = p.get("ep", {})
	var v := float(ep.get("kill", 1.0))
	if e != null:
		v += float(ep.get("hp", 0.0)) * float(e.get("max_hp") if e.get("max_hp") != null else 0.0)
		if e.get("boss") == true:
			v *= float(ep.get("boss", 1.0))
		if e.get("flying") == true:
			v *= float(ep.get("air", 1.0))
	return v


## Alle Boni bis einschließlich Level lv: {damage, speed, range, abilities}.
static func bonuses(p: Dictionary, lv: int) -> Dictionary:
	var b := {"damage": 0.0, "speed": 0.0, "range": 0.0, "abilities": []}
	var per: Dictionary = p.get("per_level", {})
	for s in STATS:
		b[s] = float(per.get(s, 0.0)) * lv
	var by_type := {}
	var order := []
	for u in _sorted_unlocks(p):
		if int(u.get("level", 1)) > lv:
			break
		if u.has("stat") and str(u.stat) in STATS:
			b[str(u.stat)] += float(u.get("value", 0.0))
		elif u.get("ability") is Dictionary:
			var ab: Dictionary = u.ability
			var type := str(ab.get("type", ""))
			if not by_type.has(type):
				order.append(type)
			by_type[type] = ab.duplicate(true)
	for type in order:
		b.abilities.append(by_type[type])
	return b


static func _sorted_unlocks(p: Dictionary) -> Array:
	var u: Array = p.get("unlocks", []).duplicate()
	u.sort_custom(func(a, b): return int(a.get("level", 1)) < int(b.get("level", 1)))
	return u


## Freischaltungen genau bei Level lv.
static func unlocks_at(p: Dictionary, lv: int) -> Array:
	return p.get("unlocks", []).filter(func(u): return int(u.get("level", 1)) == lv)


## Nächste Freischaltung über Level lv ({} = keine mehr).
static func next_unlock(p: Dictionary, lv: int) -> Dictionary:
	for u in _sorted_unlocks(p):
		if int(u.get("level", 1)) > lv and int(u.get("level", 1)) <= int(p.get("max_level", 0)):
			return u
	return {}


## Alles fürs Infofenster: {level, max_level, ep, start, next, need, progress (0..1), maxed}.
static func info(p: Dictionary, ep: float) -> Dictionary:
	var t: Array = p.get("_table", table(p))
	var lv := level_at(p, ep)
	var maxed := lv + 1 >= t.size()
	var start := float(t[lv])
	var nxt := start if maxed else float(t[lv + 1])
	return {"level": lv, "max_level": t.size() - 1, "ep": ep, "start": start, "next": nxt,
			"need": maxf(nxt - ep, 0.0), "progress": 1.0 if maxed else clampf((ep - start) / maxf(nxt - start, 0.001), 0.0, 1.0),
			"maxed": maxed}


## Kurzer Text zu einer Freischaltung, z. B. „+10 % Reichweite“ oder „Kritischer Treffer“.
static func unlock_text(u: Dictionary) -> String:
	if u.has("text"):
		return _t(str(u.text))
	if u.has("stat"):
		return "+%d %% %s" % [roundi(float(u.get("value", 0.0)) * 100.0), _t(str(STAT_NAMES.get(str(u.stat), u.stat)))]
	if u.get("ability") is Dictionary:
		return Abilities.describe(u.ability)
	return "?"


## Text der Boni je Level, z. B. „+10 % Schaden je Level“ ("" = keine).
static func per_level_text(p: Dictionary) -> String:
	var parts := []
	var per: Dictionary = p.get("per_level", {})
	for s in STATS:
		if float(per.get(s, 0.0)) != 0.0:
			parts.append("+%s %% %s" % [_pct(float(per[s])), _t(str(STAT_NAMES[s]))])
	return (", ".join(parts) + " " + _t("je Level")) if not parts.is_empty() else ""


static func _pct(v: float) -> String:
	var x := v * 100.0
	return str(roundi(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x


static func _t(s: String) -> String:
	return TranslationServer.translate(s)
