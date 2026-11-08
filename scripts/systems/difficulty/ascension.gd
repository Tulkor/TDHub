class_name Ascension
extends RefCounted
## Aufstiegsstufen (+1, +2, …) nach der höchsten Schwierigkeit, in allen Modi (wie Ascension in Slay the Spire
## oder Mythic+). Regeln je Modus in data/ascension.json (Balance-Editor, Reiter Aufstieg):
##   choices    welche Schwierigkeiten (Index in der Liste des Modus) im Startfenster stehen; die letzte ist die
##              Grundlage für den Aufstieg, nur auf ihr lässt sich eine Stufe wählen.
##   max_level  höchste Stufe, 0 = ohne Ende.
##   rules      jede Regel wirkt ab Stufe from (Standard = every) alle every Stufen einmal:
##              {type: "stat", stat: hp|speed|armor, percent: +% je Mal, add: +Wert je Mal}
##              {type: "flag", flag: "name", text: "Anzeige"} für Sonderregeln, die ein Modus mit flag() abfragt.
##              Unbekannte Typen werden mit ihrem text angezeigt und sonst übergangen (spätere Fassungen).
## Freischalten: wer die höchste Schwierigkeit auf der höchsten freigeschalteten Stufe gewinnt (Leben-Wertung,
## ohne Debug), bekommt die nächste. Steht im Profil unter modes.<modus>.progress.ascension {unlocked, best}.

## Werte, die eine stat-Regel ändern kann, mit Anzeige (percent / add).
const STATS := {
	"hp": ["Gegner-Leben +%s %%", "Gegner-Leben +%s"],
	"speed": ["Gegner-Tempo +%s %%", "Gegner-Tempo +%s"],
	"armor": ["Gegner-Rüstung +%s %%", "Gegner-Rüstung +%s"],
}


## Regeln eines Modus (Profil-ID wie in profile.gd; Roguelike nimmt GemTD, wenn es keine eigenen hat).
static func cfg(mode: String) -> Dictionary:
	var modes: Dictionary = Database.ascension.get("modes", {})
	if modes.has(mode):
		return modes[mode]
	if mode == "roguelike":
		return modes.get("gemtd", {})
	return {}


## Angebotene Schwierigkeiten (Indizes) bei count Einträgen in der Liste des Modus.
static func choices(mode: String, count: int) -> Array:
	var out := []
	for i in cfg(mode).get("choices", []):
		if int(i) >= 0 and int(i) < count and not out.has(int(i)):
			out.append(int(i))
	if out.is_empty():
		for i in count:
			out.append(i)
	return out


## Schwierigkeit, auf der man Stufen wählen kann (die letzte angebotene).
static func top(mode: String, count: int) -> int:
	return choices(mode, count).back()


## Nächste angebotene Schwierigkeit zu diff (alte Wahl aus einer früheren Fassung mit mehr Stufen).
static func snap(mode: String, diff: int, count: int) -> int:
	var best := -1
	for i in choices(mode, count):
		if best < 0 or absi(i - diff) < absi(best - diff) or absi(i - diff) == absi(best - diff) and i < best:
			best = i
	return best


static func max_level(mode: String) -> int:
	return int(cfg(mode).get("max_level", 0))


static func _store(mode: String) -> Dictionary:
	var p := Profile.progress(mode)
	if not p.get("ascension") is Dictionary:
		p.ascension = {"unlocked": 0, "best": -1}
	return p.ascension


## Höchste wählbare Stufe (0 = nur die Schwierigkeit selbst).
static func unlocked(mode: String) -> int:
	var n := int(_store(mode).get("unlocked", 0))
	var cap := max_level(mode)
	return mini(n, cap) if cap > 0 else n


## Höchste gewonnene Stufe (-1 = auf der höchsten Schwierigkeit noch nie gewonnen).
static func best(mode: String) -> int:
	return int(_store(mode).get("best", -1))


## Wie oft eine Regel auf Stufe level wirkt.
static func times(rule: Dictionary, level: int) -> int:
	var every := maxi(int(rule.get("every", 1)), 1)
	var from := maxi(int(rule.get("from", every)), 1)
	if level < from:
		return 0
	return (level - from) / every + 1


## Alles, was auf Stufe level gilt: {hp, speed, armor} als Faktoren, armor_add, flags {name: true},
## lines (Anzeige je Regel).
static func mods(mode: String, level: int) -> Dictionary:
	var m := {"hp": 1.0, "speed": 1.0, "armor": 1.0, "hp_add": 0.0, "speed_add": 0.0, "armor_add": 0.0, "flags": {}, "lines": []}
	if level <= 0:
		return m
	for r in cfg(mode).get("rules", []):
		if not r is Dictionary:
			continue
		var n := times(r, level)
		if n <= 0:
			continue
		match str(r.get("type", "stat")):
			"stat":
				var stat := str(r.get("stat", ""))
				if not STATS.has(stat):
					continue
				var pct := float(r.get("percent", 0.0)) * n
				var add := float(r.get("add", 0.0)) * n
				m[stat] = float(m[stat]) + pct / 100.0
				m[stat + "_add"] = float(m[stat + "_add"]) + add
				if pct != 0.0:
					m.lines.append(TranslationServer.translate(STATS[stat][0]) % _num(pct))
				if add != 0.0:
					m.lines.append(TranslationServer.translate(STATS[stat][1]) % _num(add))
			"flag":
				m.flags[str(r.get("flag", ""))] = true
				if r.has("text"):
					m.lines.append(TranslationServer.translate(str(r.text)))
			_:
				if r.has("text"):
					m.lines.append(TranslationServer.translate(str(r.text)))
	return m


static func flag(mode: String, level: int, name: String) -> bool:
	return mods(mode, level).flags.has(name)


## Gegner beim Erscheinen verstärken (nach der Schwierigkeit des Modus).
static func apply(e: Enemy, m: Dictionary) -> void:
	e.max_hp = e.max_hp * float(m.hp) + float(m.hp_add)
	e.hp = e.max_hp
	e.speed = e.speed * float(m.speed) + float(m.speed_add)
	e.armor = e.armor * float(m.armor) + float(m.armor_add)


## „+3“, auf Stufe 0 leer.
static func label(level: int) -> String:
	return "+%d" % level if level > 0 else ""


## Name der Schwierigkeit mit Stufe, z. B. „Schwer +3“.
static func full_name(diff_name: String, level: int) -> String:
	var n := TranslationServer.translate(diff_name)
	return n + " " + label(level) if level > 0 else n


## Run eingetragen (profile.gd, ohne Debug): Sieg auf der höchsten Schwierigkeit schaltet die nächste Stufe frei.
## count = Anzahl Schwierigkeiten des Modus. Gibt die neu freigeschaltete Stufe zurück (0 = keine).
static func record(mode: String, info: Dictionary, count: int) -> int:
	if not bool(info.get("victory", false)) or bool(info.get("score_mode", false)) or count <= 0:
		return 0
	if int(info.get("difficulty", -1)) != top(mode, count):
		return 0
	var level := int(info.get("ascension", 0))
	var st := _store(mode)
	st.best = maxi(int(st.get("best", -1)), level)
	var cap := max_level(mode)
	if level < int(st.get("unlocked", 0)) or cap > 0 and level >= cap:
		return 0
	st.unlocked = level + 1
	return level + 1


## Anzahl Schwierigkeiten eines Modus (für record, wenn der Aufrufer sie nicht kennt).
static func difficulty_count(mode: String) -> int:
	match mode:
		"gemtd", "roguelike":
			return Session.DIFFICULTIES.size()
		"eeve":
			return (Database.eeve.get("difficulties", []) as Array).size()
		"randgruppen":
			return (Database.randgruppen.get("difficulties", []) as Array).size()
		"maul":
			return (MaulData.rules().get("difficulties", []) as Array).size()
		"youtd":
			return (YoutdData.rules().get("difficulties", []) as Array).size()
	return 0


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.1))
