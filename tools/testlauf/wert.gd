extends RefCounted
## Grobe Stärke eines Towers für die Testlauf-Bots (so schätzt auch ein Spieler ab, ohne zu rechnen):
## Schaden pro Sekunde mit Crit, Fläche, Mehrfachschuss, Sprüngen, Gift; Bremsen, Betäuben und Auren als Aufschlag.


static func tier_stats(id: String, tier: int) -> Dictionary:
	var def: Dictionary = Database.towers.get(id, {})
	var tiers: Array = def.get("tiers", [])
	if tiers.is_empty():
		return {}
	return tiers[clampi(tier, 0, tiers.size() - 1)]


static func value(id: String, tier: int) -> float:
	return value_of(tier_stats(id, tier), str(Database.towers.get(id, {}).get("targets", "both")))


static func value_of(st: Dictionary, targets := "both") -> float:
	if st.is_empty():
		return 0.0
	var dmg = st.get("damage", [0, 0])
	var avg := 0.0
	if dmg is Array and dmg.size() >= 2:
		avg = (float(dmg[0]) + float(dmg[1])) / 2.0
	elif dmg is float or dmg is int:
		avg = float(dmg)
	var cd := maxf(float(st.get("cooldown", 1.0)), 0.05)
	var dps := avg / cd
	var mult := 1.0
	var extra := 0.0
	for ab in st.get("abilities", []):
		match str(ab.get("type", "")):
			"splash":
				mult *= 1.0 + float(ab.get("factor", 0.5)) * 1.5
			"multishot":
				mult *= 1.0 + (float(ab.get("targets", 2)) - 1.0) * 0.7
			"bounce", "chain":
				mult *= 1.0 + float(ab.get("count", ab.get("bounces", 2))) * 0.4
			"crit":
				mult *= 1.0 + float(ab.get("chance", 0.1)) * (float(ab.get("factor", ab.get("multiplier", 2.0))) - 1.0)
			"poison", "burn_aura", "pulse", "nova", "cone", "wave_damage":
				# Zusatzschaden; mit Auslösechance entsprechend weniger
				var ch := float(ab.get("chance", 1.0))
				extra += dps * 0.5 * minf(1.0, ch * 4.0)
			"slow", "stun", "slow_aura", "armor_reduce", "armor_aura", "area_debuff", "amplify", "hp_cut":
				mult *= 1.2
			"damage_aura", "speed_aura":
				mult *= 1.4
	var r := float(st.get("range", 5.0))
	var v := (dps * mult + extra) * sqrt(maxf(r, 1.0) / 6.0)
	if targets == "air":
		v *= 0.45
	elif targets == "ground":
		v *= 0.85
	return v


## Stärke eines Spezial-Towers mit seinen Aufwertungen (Gold kommt mit der Zeit): beste Stufe, leicht abgezinst.
static func potential(id: String) -> float:
	var tiers: Array = Database.towers.get(id, {}).get("tiers", [])
	var best := 0.0
	for i in tiers.size():
		best = maxf(best, value(id, i) * pow(0.6, i))
	return best
