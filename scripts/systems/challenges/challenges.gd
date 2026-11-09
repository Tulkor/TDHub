extends GameSystem
## Endgebiet mit Challenges für alle Modi: nach dem letzten Abschnitt betritt man ein Gebiet mit mehreren
## Challenges (kämpfen, lösen, ausweichen, halten …) und einem Tor zum Endboss, das von Anfang an offen ist.
## Jede geschaffte Challenge legt ihre Belohnung in gains; boss_mods()/hero_mods() fassen sie für den
## Endkampf zusammen. Nach cfg.awaken Sekunden erwacht der Endboss von selbst (kein endloses Farmen).
## Was eine Challenge im Spiel tut, baut der Modus über Haken; das System hält nur Zustand und Regeln.
## Werte (Basis challenges.json, Modus in system_cfg.challenges):
##   data       JSON-Datei mit {"list": [{id, name, kind, desc, reward: {boss: {}, hero: {}, …}}], …}
##   awaken     Sekunden im Gebiet, bis der Endboss von selbst erwacht (0 = nie)
##   retry      gescheiterte Challenges dürfen neu begonnen werden
## Haken: area_entered(), challenge_begin(def), challenge_abort(def), challenge_finished(def, ok),
##        final_boss_start(mods: {boss, hero, gains}, reason: "gate"|"awaken")

var data: Dictionary = {}
var list: Array = []
var open := false         ## im Endgebiet
var time := 0.0           ## Sekunden im Endgebiet
var states := {}          ## id → open | active | done | failed
var active_id := ""
var gains: Array = []     ## Belohnungen geschaffter Challenges (reward-Dictionaries)
var boss_started := false
var boss_reason := ""


func _ready() -> void:
	var path := str(cfg.get("data", ""))
	if path != "":
		var d = Database.load_json(path)
		if d is Dictionary:
			data = d
			list = d.get("list", [])


func def(id: String) -> Dictionary:
	for c in list:
		if str(c.id) == id:
			return c
	return {}


## Endgebiet betreten: alle Challenges offen, Uhr läuft.
func enter() -> void:
	open = true
	time = 0.0
	active_id = ""
	gains = []
	boss_started = false
	boss_reason = ""
	states = {}
	for c in list:
		states[str(c.id)] = "open"
	hook("area_entered")


func state_of(id: String) -> String:
	return str(states.get(id, ""))


## Kann diese Challenge jetzt beginnen? "" = ja, sonst Grund.
func can_begin(id: String) -> String:
	if not open or boss_started:
		return tr("Der Endkampf läuft")
	if active_id != "":
		return tr("Erst die laufende Challenge beenden")
	var s := state_of(id)
	if s == "done":
		return tr("Schon geschafft")
	if s == "failed" and not bool(cfg.get("retry", true)):
		return tr("Gescheitert")
	if s == "":
		return "?"
	return ""


func begin(id: String) -> String:
	var why := can_begin(id)
	if why != "":
		return why
	active_id = id
	states[id] = "active"
	hook("challenge_begin", [def(id)])
	return ""


## Laufende Challenge abschließen (ok = geschafft, sonst gescheitert).
func finish(id: String, ok: bool) -> void:
	if active_id != id:
		return
	active_id = ""
	states[id] = "done" if ok else "failed"
	var d := def(id)
	if ok:
		gains.append(d.get("reward", {}))
	hook("challenge_finished", [d, ok])


func done_count() -> int:
	var n := 0
	for id in states:
		if states[id] == "done":
			n += 1
	return n


## Sekunden, bis der Endboss von selbst erwacht (-1 = nie).
func awaken_left() -> float:
	var a := float(cfg.get("awaken", 0.0))
	return -1.0 if a <= 0.0 else maxf(0.0, a - time)


## Summen aller Belohnungen: boss {Schlüssel: Summe}, hero {Schlüssel: Summe}, Listen werden aneinandergehängt.
func boss_mods() -> Dictionary:
	return _sum("boss")


func hero_mods() -> Dictionary:
	return _sum("hero")


func _sum(part: String) -> Dictionary:
	var out := {}
	for g in gains:
		var d: Dictionary = g.get(part, {})
		for k in d:
			var v = d[k]
			if v is Array:
				var a: Array = out.get(k, [])
				out[k] = a + v
			elif v is float or v is int:
				out[k] = float(out.get(k, 0.0)) + float(v)
			else:
				out[k] = v
	return out


## Zum Endboss (Tor oder erwacht). Eine laufende Challenge bricht ab.
func start_boss(reason := "gate") -> void:
	if not open or boss_started:
		return
	if active_id != "":
		var d := def(active_id)
		states[active_id] = "failed"
		active_id = ""
		hook("challenge_abort", [d])
	boss_started = true
	boss_reason = reason
	hook("final_boss_start", [{"boss": boss_mods(), "hero": hero_mods(), "gains": gains}, reason])


## Vom Spiel je Schritt gerufen.
func tick(dt: float) -> void:
	if not open or boss_started:
		return
	time += dt
	var a := float(cfg.get("awaken", 0.0))
	if a > 0.0 and time >= a:
		start_boss("awaken")
