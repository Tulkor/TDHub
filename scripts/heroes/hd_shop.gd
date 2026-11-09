class_name HdShop
extends RefCounted
## Wirtschaft von Bollwerk (Etappe 2a, Design Abschnitt 6): Gold, Holz, Shop mit Grundwaren und
## Rüstkammer, Rezepte (2–4 Bauteile + Gold, mehrstufig bis Legendär), Heldeninventar mit 6 Plätzen und
## Lager in der Feste (12 Plätze), Holz gegen dauerhafte Werte, Torwerke reparieren/neu bauen.
## Fernkauf: Kaufen geht überall; außerhalb der Feste landet das Item im Lager. Zwischen Lager und Held
## tauschen nur in der Feste. Rezepte nehmen Bauteile aus Inventar und Lager.
## Alle Spieleraktionen laufen über act(cmd) (für den Koop in Etappe 4 als Befehl übertragbar) und
## geben "" (geklappt) oder den Grund zurück, warum es nicht geht.

const DATA := "res://data/heroes_items.json"

var game  ## HdGame
var cfg: Dictionary
var items: Dictionary = {}       ## id → Daten
var used_in: Dictionary = {}     ## id → [Rezepte, die es brauchen]
var gold := 0
var wood := 0
var gold_earned := 0
var wood_earned := 0
var inv: Array = []              ## Heldenplätze: null | {id, n}
var stash: Array = []            ## Lager in der Feste
var wood_bought: Dictionary = {} ## Holzwert-id → Anzahl
var crafted := 0
var trophies := 0                ## Etappe 3: Trophäen der Kriegsherren (Kriegsherren-Händler)
var marks := 0                   ## Arena-Marken
var merchant: Array = []         ## Wanderhändler: [{id, price}] solange das Ereignis läuft


func _init(g) -> void:
	game = g
	cfg = Database.load_json(DATA)
	for it in cfg.items:
		items[str(it.id)] = it
	for it in cfg.items:
		for c in it.get("recipe", []):
			if not used_in.has(c):
				used_in[c] = []
			if not used_in[c].has(it.id):
				used_in[c].append(str(it.id))
	var eco: Dictionary = game.cfg.economy
	gold = int(eco.start_gold)
	inv.resize(int(eco.slots))
	stash.resize(int(eco.stash))


func item(id: String) -> Dictionary:
	return items.get(id, {})


func tier(id: String) -> Dictionary:
	return cfg.tiers[clampi(int(item(id).get("tier", 1)) - 1, 0, cfg.tiers.size() - 1)]


func tier_color(id: String) -> Color:
	return Color(str(tier(id).color))


func consumable(id: String) -> bool:
	return item(id).has("use")


## Gesamtwert eines Items (mit allen Bauteilen), Grundlage für den Verkaufspreis.
func total_cost(id: String) -> int:
	var it := item(id)
	var c := int(it.get("price", 0))
	for p in it.get("recipe", []):
		c += total_cost(str(p))
	return c


func sell_price(id: String) -> int:
	return int(total_cost(id) * float(game.cfg.economy.sell))


func in_fortress() -> bool:
	return game.hero != null and game.hero.alive() and game.hero.position.distance_to(game.fortress_pos) <= float(game.cfg.arena.fortress_zone)


func shop_items(shop: String) -> Array:
	var out: Array = []
	for it in cfg.items:
		if shop == "rezept":
			if it.has("recipe"):
				out.append(str(it.id))
		elif str(it.get("shop", "")) == shop:
			out.append(str(it.id))
	return out


# ---------------------------------------------------------------- Gold und Holz

func add_gold(n: int) -> void:
	n = maxi(n, 0)
	gold += n
	gold_earned += n


func add_wood(n: int) -> void:
	n = maxi(n, 0)
	wood += n
	wood_earned += n


func kill_gold(e) -> int:
	return roundi(float(e.def.get("gold", float(e.def.get("xp", 10)) * float(game.cfg.economy.kill_gold))) * float(game.scaling().gold))


func wave_gold(n: int) -> int:
	var wg: Array = game.cfg.economy.wave_gold
	return int(wg[0]) + int(wg[1]) * n


func wood_price(stat: String) -> int:
	var w: Dictionary = cfg.wood
	var k := int(wood_bought.get(stat, 0))
	return maxi(1, roundi((float(w.base) + k * float(w.growth)) * float(game.diff().get("wood_price", 1.0))))


func wood_stat(stat: String) -> Dictionary:
	for s in cfg.wood.stats:
		if str(s.id) == stat:
			return s
	return {}


# ---------------------------------------------------------------- Plätze

## Ort {"where": "hero"|"stash", "i": k} → Liste und Index.
func _list(where: String) -> Array:
	return inv if where == "hero" else stash


func at(where: String, i: int):
	var l := _list(where)
	return l[i] if i >= 0 and i < l.size() else null


func _free(where: String) -> int:
	var l := _list(where)
	for i in l.size():
		if l[i] == null:
			return i
	return -1


func count_free(where: String) -> int:
	var n := 0
	for x in _list(where):
		if x == null:
			n += 1
	return n


## Wo ein neues Item hinkommt: in der Feste zum Helden (wenn Platz), sonst ins Lager.
func _target_for(id: String) -> Dictionary:
	var it := item(id)
	var order := ["hero", "stash"] if in_fortress() else ["stash"]
	if it.has("stack"):
		for where in order:
			var l := _list(where)
			for i in l.size():
				if l[i] != null and l[i].id == id and int(l[i].n) < int(it.stack):
					return {"where": where, "i": i, "stack": true}
	for where in order:
		var i := _free(where)
		if i >= 0:
			return {"where": where, "i": i}
	return {}


func owned_count(id: String) -> int:
	var n := 0
	for l in [inv, stash]:
		for x in l:
			if x != null and x.id == id:
				n += 1
	return n


## Werte eines Platzes: Item-Werte mit Veredelung (+per_level je Stufe) plus eingesetzte Edelsteine.
func entry_stats(x) -> Dictionary:
	var out := {}
	if x == null:
		return out
	var f: float = 1.0 + float(game.cfg.zones.schmiede.per_level) * int(x.get("up", 0))
	for k in item(x.id).get("stats", {}):
		out[k] = float(item(x.id).stats[k]) * f
	for gid in x.get("gems", []):
		var gem: Dictionary = game.zones.gem(str(gid))
		for k in gem.get("stats", {}):
			out[k] = float(out.get(k, 0.0)) + float(gem.stats[k])
	return out


## Werte aller Items am Helden (nicht im Lager) plus Holzwerte, Arena-Siege und Schrein-Segen.
func bonus() -> Dictionary:
	var out := {}
	for x in inv:
		if x == null:
			continue
		var st := entry_stats(x)
		for k in st:
			out[k] = float(out.get(k, 0.0)) + float(st[k])
	var extra: Array = [game.perma]
	if not game.blessing.is_empty() and game.wave <= int(game.blessing.until):
		extra.append(game.blessing.stats)
	for d in extra:
		for k in d:
			out[k] = float(out.get(k, 0.0)) + float(d[k])
	for s in cfg.wood.stats:
		var n := int(wood_bought.get(str(s.id), 0))
		for k in s.stats:
			out[k] = float(out.get(k, 0.0)) + float(s.stats[k]) * n
	return out


func _changed() -> void:
	if game.hero:
		game.hero.set_bonus(bonus())
	game.changed.emit()


# ---------------------------------------------------------------- Befehle

func act(cmd: Dictionary) -> String:
	if game.state != "play" and game.state != "setup":
		return tr("Das Spiel ist vorbei")
	match str(cmd.get("kind", "")):
		"buy":
			return buy(str(cmd.id))
		"craft":
			return craft(str(cmd.id), bool(cmd.get("buy_missing", false)))
		"sell":
			return sell(str(cmd.where), int(cmd.i))
		"move":
			return move(str(cmd.from), int(cmd.fi), str(cmd.to), int(cmd.ti))
		"use":
			return use(int(cmd.i))
		"wood":
			return buy_wood(str(cmd.id))
		"repair":
			return repair(cmd.gate)
		"merchant":
			return buy_merchant(int(cmd.i))
		"upgrade", "socket", "lumberjack", "arena", "trial":
			return game.zones.act(cmd)
		"event":
			return game.events.act(cmd)
	return "?"


func can_buy(id: String) -> String:
	var it := item(id)
	if it.is_empty() or it.has("recipe"):
		return "?"
	if it.has("trophy") and trophies < int(it.trophy):
		return tr("Zu wenig Trophäen")
	if it.has("marks") and marks < int(it.marks):
		return tr("Zu wenig Arena-Marken")
	if gold < int(it.price):
		return tr("Zu wenig Gold")
	if _target_for(id).is_empty():
		return tr("Kein Platz im Lager") if not in_fortress() else tr("Kein Platz frei")
	return ""


func buy(id: String) -> String:
	var why := can_buy(id)
	if why != "":
		return why
	gold -= int(item(id).price)
	trophies -= int(item(id).get("trophy", 0))
	marks -= int(item(id).get("marks", 0))
	_put(id, 1)
	_changed()
	return ""


## Preis als Text (Gold, Trophäen oder Arena-Marken).
func price_text(id: String) -> String:
	var it := item(id)
	if it.has("trophy"):
		return tr("%d Trophäe") % int(it.trophy) if int(it.trophy) == 1 else tr("%d Trophäen") % int(it.trophy)
	if it.has("marks"):
		return tr("%d Marken") % int(it.marks)
	return tr("%d Gold") % int(it.price)


func can_buy_merchant(i: int) -> String:
	if i < 0 or i >= merchant.size():
		return "?"
	var m: Dictionary = merchant[i]
	if bool(m.get("sold", false)):
		return tr("Verkauft")
	if gold < int(m.price):
		return tr("Zu wenig Gold")
	if _target_for(str(m.id)).is_empty():
		return tr("Kein Platz frei")
	return ""


## Wanderhändler: seltenes Item zum Festpreis (ohne Bauteile).
func buy_merchant(i: int) -> String:
	var why := can_buy_merchant(i)
	if why != "":
		return why
	var m: Dictionary = merchant[i]
	gold -= int(m.price)
	m.sold = true
	_put(str(m.id), 1)
	_changed()
	return ""


func _put(id: String, n: int) -> Dictionary:
	var t := _target_for(id)
	var l := _list(t.where)
	if t.get("stack", false):
		l[t.i].n = int(l[t.i].n) + n
	else:
		l[t.i] = {"id": id, "n": n}
	return t


## Bauteile, die für das Rezept noch fehlen (mehrfach, wenn es ein Teil zweimal braucht).
func missing(id: String) -> Array:
	var have := {}
	for l in [inv, stash]:
		for x in l:
			if x != null:
				have[x.id] = int(have.get(x.id, 0)) + 1
	var out: Array = []
	for c in item(id).get("recipe", []):
		if int(have.get(c, 0)) > 0:
			have[c] -= 1
		else:
			out.append(str(c))
	return out


## Gold für das Rezept, mit buy_missing auch für fehlende Bauteile (die selbst Rezepte sein können).
func craft_cost(id: String, buy_missing := false) -> int:
	var c := int(item(id).get("price", 0))
	if buy_missing:
		for m in missing(id):
			c += total_cost(m)
	return c


func can_craft(id: String, buy_missing := false) -> String:
	var it := item(id)
	if not it.has("recipe"):
		return "?"
	var miss := missing(id)
	if not buy_missing and not miss.is_empty():
		return tr("Es fehlen Bauteile")
	if gold < craft_cost(id, buy_missing):
		return tr("Zu wenig Gold")
	return ""


func craft(id: String, buy_missing := false) -> String:
	var why := can_craft(id, buy_missing)
	if why != "":
		return why
	gold -= craft_cost(id, buy_missing)
	# Bauteile entnehmen, zuerst vom Helden; das Ergebnis kommt an den Platz des ersten Teils
	var spot := {}
	var have_parts: Array = item(id).recipe.duplicate()
	for m in missing(id):
		have_parts.erase(m)
	for c in have_parts:
		var found := false
		for where in ["hero", "stash"]:
			var l := _list(where)
			for i in l.size():
				if l[i] != null and l[i].id == c:
					l[i] = null
					if spot.is_empty():
						spot = {"where": where, "i": i}
					found = true
					break
			if found:
				break
	if spot.is_empty():
		var t := _target_for(id)
		if t.is_empty():
			# kein Platz: Ergebnis trotzdem ins Lager zwingen geht nicht → Gold zurück
			gold += craft_cost(id, buy_missing)
			return tr("Kein Platz frei")
		spot = t
	_list(spot.where)[spot.i] = {"id": id, "n": 1}
	crafted += 1
	game.message.emit(tr("%s geschmiedet") % tr(str(item(id).name)))
	_changed()
	return ""


func sell(where: String, i: int) -> String:
	var x = at(where, i)
	if x == null:
		return "?"
	var p := sell_price(x.id) * (int(x.n) if consumable(x.id) else 1)
	_list(where)[i] = null
	gold += p
	_changed()
	return ""


func can_move(from: String, to: String) -> String:
	if from != to and not in_fortress():
		return tr("Lager nur in der Feste")
	return ""


## Tauschen/Verschieben zwischen Plätzen; gleiche Verbrauchs-Items werden zusammengelegt.
func move(from: String, fi: int, to: String, ti: int) -> String:
	var why := can_move(from, to)
	if why != "":
		return why
	var a = at(from, fi)
	var b = at(to, ti)
	if a == null or (from == to and fi == ti):
		return "?"
	if b != null and b.id == a.id and item(a.id).has("stack"):
		var room := int(item(a.id).stack) - int(b.n)
		var k := mini(room, int(a.n))
		if k > 0:
			b.n = int(b.n) + k
			a.n = int(a.n) - k
			if int(a.n) <= 0:
				_list(from)[fi] = null
			_changed()
			return ""
	_list(from)[fi] = b
	_list(to)[ti] = a
	_changed()
	return ""


func use(i: int) -> String:
	var x = at("hero", i)
	if x == null or not consumable(x.id):
		return "?"
	var h = game.hero
	if h == null or not h.alive():
		return tr("Der Held ist gefallen")
	var u: Dictionary = item(x.id).use
	if u.has("heal"):
		if h.hp >= h.max_hp - 1.0:
			return tr("Leben ist voll")
		h.hp = minf(h.max_hp, h.hp + float(u.heal))
		game.floater(h.position + Vector3(0, 2.6, 0), "+%d" % int(u.heal), UiTheme.HAVE)
	if u.has("mana"):
		if h.mana >= h.max_mana - 1.0:
			return tr("Mana ist voll")
		h.mana = minf(h.max_mana, h.mana + float(u.mana))
	if u.has("home"):
		game.teleport_hero(game.hero_spawn())
	if u.has("shield"):
		h.ward = float(u.shield)
		h.ward_until = game.play_time + float(u.time)
	x.n = int(x.n) - 1
	if int(x.n) <= 0:
		inv[i] = null
	_changed()
	return ""


func buy_wood(stat: String) -> String:
	if wood_stat(stat).is_empty():
		return "?"
	var p := wood_price(stat)
	if wood < p:
		return tr("Zu wenig Holz")
	wood -= p
	wood_bought[stat] = int(wood_bought.get(stat, 0)) + 1
	_changed()
	return ""


# ---------------------------------------------------------------- Torwerke

func repair_cost(g) -> int:
	var r: Dictionary = game.cfg.arena.repair
	if g.destroyed:
		return int(g.def.rebuild)
	return ceili((g.max_hp - g.hp) * float(r.gold_per_hp))


## Reparieren geht, wenn keine Gegner nahe am Torwerk sind (also zwischen den Wellen dieser Straße).
func can_repair(g) -> String:
	if g == null:
		return "?"
	if not g.destroyed and g.hp >= g.max_hp - 0.5:
		return tr("Unbeschädigt")
	if game.nearest_enemy(g.position, float(game.cfg.arena.repair.enemy_free)) != null:
		return tr("Gegner in der Nähe")
	if gold < repair_cost(g):
		return tr("Zu wenig Gold")
	return ""


func repair(g) -> String:
	if g is String:
		g = game.gate_by_name(g)
	var why := can_repair(g)
	if why != "":
		return why
	gold -= repair_cost(g)
	if g.destroyed:
		g.rebuild(float(game.cfg.arena.repair.rebuild_hp))
		game.message.emit(tr("%s wieder aufgebaut") % g.label())
	else:
		g.hp = g.max_hp
	_changed()
	return ""


# ---------------------------------------------------------------- Texte

const STAT_TEXT := {
	"hp": "+%d Leben", "mana": "+%d Mana", "armor": "+%s Rüstung", "hp_regen": "+%s Leben/s",
	"mana_regen": "+%s Mana/s", "damage": "+%d %% Schaden", "attack_speed": "+%d %% Angriffstempo",
	"speed": "+%d %% Lauftempo", "cdr": "−%d %% Abklingzeit", "lifesteal": "%d %% Lebensraub",
}
const PCT := ["damage", "attack_speed", "speed", "cdr", "lifesteal"]


static func stat_text(stats: Dictionary) -> String:
	var out: Array = []
	for k in STAT_TEXT:
		if not stats.has(k):
			continue
		var v := float(stats[k])
		if k in PCT:
			out.append(TranslationServer.translate(STAT_TEXT[k]) % roundi(v * 100.0))
		elif k in ["hp", "mana"]:
			out.append(TranslationServer.translate(STAT_TEXT[k]) % roundi(v))
		else:
			out.append(TranslationServer.translate(STAT_TEXT[k]) % String.num(v, 1))
	return " · ".join(out)


## Tooltip eines Items: Name, Stufe, Werte bzw. Wirkung, Verkaufswert.
func tooltip(id: String, x = null) -> String:
	var it := item(id)
	if x != null and (int(x.get("up", 0)) > 0 or not x.get("gems", []).is_empty()):
		var head := "%s +%d (%s)" % [tr(str(it.name)), int(x.get("up", 0)), tr(str(tier(id).name))]
		var gl: Array = []
		for gid in x.get("gems", []):
			gl.append(tr(str(game.zones.gem(str(gid)).get("name", gid))))
		var lines2: Array = [head, stat_text(entry_stats(x))]
		if not gl.is_empty():
			lines2.append(tr("Edelsteine: %s") % ", ".join(gl))
		lines2.append(tr("Verkauf %d Gold") % sell_price(id))
		return "\n".join(lines2)
	var lines: Array = ["%s (%s)" % [tr(str(it.name)), tr(str(tier(id).name))]]
	if it.has("stats"):
		lines.append(stat_text(it.stats))
	if it.has("desc"):
		lines.append(tr(str(it.desc)))
	if it.has("recipe"):
		var parts: Array = []
		for c in it.recipe:
			parts.append(tr(str(item(c).name)))
		lines.append(tr("Rezept: %s + %d Gold") % [" + ".join(parts), int(it.price)])
	lines.append(tr("Verkauf %d Gold") % sell_price(id))
	return "\n".join(lines)
