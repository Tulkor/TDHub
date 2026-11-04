class_name HdCc
extends RefCounted
## Kontrolleffekte eines Ziels im Hero-Defense-Modus (Design Abschnitt 15, Lukas 2026-11-04).
## Harte CC (Betäubung, Umwerfen, Hochschleudern … alles, was handlungsunfähig macht) wird mit jeder
## weiteren CC kürzer: Faktoren aus heroes.json → cc.<rang>.steps, bei normalen Gegnern bis 35 %,
## bei Elite bis 10 %. Bosse werden nach dem letzten Schritt für cc.boss.immune Sekunden immun.
## Der Zähler setzt zurück nach cc.reset Sekunden ohne harte CC (ab Ende der letzten) oder nach
## cc.reset Sekunden am Maximum. Verlangsamung und Rüstungssenkung nehmen nie ab, wirken auf
## Bossen aber nur halb (boss_slow, boss_armor_reduction). Zeit kommt immer von außen (Spielzeit),
## damit Tests die Regeln ohne Warten prüfen können.

var cfg: Dictionary
var rank := "normal"          ## normal | elite | boss | hero
var count := 0                ## harte CC in der laufenden Kette
var stun_until := 0.0
var _last_end := -1000.0      ## Ende der letzten harten CC
var _max_since := -1.0        ## seit wann am Maximum (-1 = nicht)
var immune_until := -1.0
var _slows: Dictionary = {}   ## Quelle → [Anteil, bis]
var _armor: Dictionary = {}   ## Quelle → [Menge, bis]


func _init(cc_cfg: Dictionary, unit_rank := "normal") -> void:
	cfg = cc_cfg
	rank = unit_rank


func steps() -> Array:
	return cfg.get(rank, cfg.get("normal", {"steps": [1.0]})).get("steps", [1.0])


func _reset_time() -> float:
	return float(cfg.get("reset", 10.0))


## Zähler zurücksetzen, wenn eine der Bedingungen erfüllt ist.
func update(now: float) -> void:
	if immune_until >= 0.0 and now >= immune_until:
		immune_until = -1.0
		_clear()
	if count > 0 and now - _last_end >= _reset_time():
		_clear()
	if _max_since >= 0.0 and now - _max_since >= _reset_time():
		_clear()


func _clear() -> void:
	count = 0
	_max_since = -1.0


func immune(now: float) -> bool:
	update(now)
	return immune_until >= 0.0 and now < immune_until


## Faktor, mit dem die nächste harte CC wirken würde (0 = immun).
func next_factor(now: float) -> float:
	if immune(now):
		return 0.0
	var st := steps()
	return float(st[mini(count, st.size() - 1)])


## Harte CC anwenden. Gibt die tatsächliche Dauer zurück (0 = immun).
func hard(duration: float, now: float) -> float:
	var f := next_factor(now)
	if f <= 0.0 or duration <= 0.0:
		return 0.0
	var eff := duration * f
	var st := steps()
	count += 1
	var end_t := now + eff
	stun_until = maxf(stun_until, end_t)
	_last_end = maxf(_last_end, end_t)
	var imm := float(cfg.get(rank, {}).get("immune", 0.0))
	if imm > 0.0 and count >= st.size():
		immune_until = stun_until + imm
	elif count >= st.size() - 1 and _max_since < 0.0:
		_max_since = now
	return eff


func stunned(now: float) -> bool:
	return now < stun_until


## Stufe in der Kette für die Anzeige: 0 = volle Wirkung, steps.size()-1 = Maximum.
func level(now: float) -> int:
	update(now)
	return mini(count, steps().size() - 1)


func slow(source: String, amount: float, duration: float, now: float) -> void:
	if rank == "boss":
		amount *= float(cfg.get("boss_slow", 0.5))
	var old: Array = _slows.get(source, [0.0, 0.0])
	_slows[source] = [maxf(amount, float(old[0])) if now < float(old[1]) else amount, now + duration]


## Faktor auf das Lauftempo (1 = normal). Stärkste aktive Verlangsamung zählt.
func speed_factor(now: float) -> float:
	var best := 0.0
	for k in _slows.keys():
		var s: Array = _slows[k]
		if now >= float(s[1]):
			_slows.erase(k)
		else:
			best = maxf(best, float(s[0]))
	return 1.0 - minf(best, float(cfg.get("max_slow", 0.8)))


func reduce_armor(source: String, amount: float, duration: float, now: float) -> void:
	if rank == "boss":
		amount *= float(cfg.get("boss_armor_reduction", 0.5))
	_armor[source] = [amount, now + duration]


## Summe aller aktiven Rüstungssenkungen (verschiedene Quellen stapeln, dieselbe Quelle erneuert).
func armor_reduction(now: float) -> float:
	var sum := 0.0
	for k in _armor.keys():
		var a: Array = _armor[k]
		if now >= float(a[1]):
			_armor.erase(k)
		else:
			sum += float(a[0])
	return sum
