extends GameSystem
## Ereignis-Uhr für alle Modi: alle cfg.interval Sekunden Spielzeit ein Ereignis aus einem Pool (JSON-Datei
## cfg.pool, Liste "list"), gewichtet gezogen, ohne die letzten cfg.no_repeat zu wiederholen.
## Die Uhr läuft nur, solange der Haken event_clock_running() true gibt (z. B. nur während der Wellen,
## nicht in Boss-Wellen). Was ein Ereignis tut, entscheidet der Modus über den Haken start_event(def).
## Werte (Basis timed_events.json, Modus in system_cfg.timed_events):
##   interval   Sekunden Spielzeit zwischen zwei Ereignissen (Lukas 2026-11-09: 5 Minuten)
##   first      Sekunden bis zum ersten Ereignis (leer/0 = interval)
##   pool       Datei mit {"list": [{id, name, kind, weight, from, to, …}]}
##   no_repeat  so viele zuletzt gezogene Ereignisse nicht wiederholen
##   busy_wait  Sekunden, um die die Uhr nachgestellt wird, wenn der Modus gerade keins starten kann
## Haken: event_clock_running() -> bool, event_progress() -> int (Welle o. Ä. für from/to),
##        event_allowed(def) -> bool, event_busy() -> bool, start_event(def), event_rng() -> RandomNumberGenerator

var pool: Array = []
var clock := 0.0          ## gezählte Spielzeit
var next_at := 0.0        ## nächstes Ereignis bei clock >= next_at
var history: Array = []   ## [clock, id]
var force := ""           ## Tests/Bilder: dieses Ereignis als nächstes
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var path := str(cfg.get("pool", ""))
	if path != "":
		var d = Database.load_json(path)
		if d is Dictionary:
			pool = d.get("list", [])
	reset()


## Uhr auf Anfang (neuer Run).
func reset() -> void:
	clock = 0.0
	history = []
	var first := float(cfg.get("first", 0.0))
	next_at = first if first > 0.0 else interval()


func interval() -> float:
	return float(cfg.get("interval", 300.0))


## Ereignis-Daten nach id ({} = unbekannt).
func def(id: String) -> Dictionary:
	for e in pool:
		if str(e.id) == id:
			return e
	return {}


## Sekunden bis zum nächsten Ereignis (für die Anzeige).
func remaining() -> float:
	return maxf(0.0, next_at - clock)


func running() -> bool:
	return bool(hook("event_clock_running", [], true))


## Vom Spiel je Schritt gerufen (nicht _process, damit Tests und Simulation die Uhr treiben).
func tick(dt: float) -> void:
	if not running():
		return
	clock += dt
	if clock < next_at:
		return
	if bool(hook("event_busy", [], false)):
		next_at = clock + float(cfg.get("busy_wait", 10.0))
		return
	var d := pick()
	next_at = clock + interval()
	if d.is_empty():
		return
	history.append([clock, str(d.id)])
	hook("start_event", [d])


## Kandidaten nach Fortschritt (from/to) und Haken event_allowed, ohne die letzten no_repeat.
func candidates() -> Array:
	var n := int(hook("event_progress", [], 0))
	var recent: Array = []
	for k in range(maxi(0, history.size() - int(cfg.get("no_repeat", 8))), history.size()):
		recent.append(history[k][1])
	var out: Array = []
	for e in pool:
		if n < int(e.get("from", 0)) or (e.has("to") and n > int(e.to)):
			continue
		if str(e.id) in recent or float(e.get("weight", 1.0)) <= 0.0:
			continue
		if not bool(hook("event_allowed", [e], true)):
			continue
		out.append(e)
	return out


## Gewichtet ziehen (force gewinnt).
func pick() -> Dictionary:
	if force != "":
		var f := def(force)
		force = ""
		return f
	var list := candidates()
	if list.is_empty():
		return {}
	var rng: RandomNumberGenerator = hook("event_rng", [], _rng)
	var total := 0.0
	for e in list:
		total += float(e.get("weight", 1.0))
	var r := rng.randf() * total
	for e in list:
		r -= float(e.get("weight", 1.0))
		if r <= 0.0:
			return e
	return list[-1]
