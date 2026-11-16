class_name Abilities
extends RefCounted
## Alle Fähigkeiten, die ein Tower in seinen JSON-Daten haben kann, mit Standardwerten.
## Der Tower-Editor baut seine Eingabefelder aus dieser Liste.
## Neue Fähigkeit: hier eintragen und in Tower._attack()/_hit()/_apply_enemy_auras()
## bzw. Game._update_auras() umsetzen.

const SCHEMA := {
	"splash": {"label": "Flächenschaden", "params": {"radius": 1.0, "factor": 0.5}},
	"slow": {"label": "Verlangsamung", "params": {"factor": 0.3, "duration": 2.0}},
	"poison": {"label": "Gift", "params": {"dps": 5.0, "duration": 3.0}},
	"crit": {"label": "Kritischer Treffer", "params": {"chance": 0.2, "multiplier": 2.0}},
	"multishot": {"label": "Mehrfachschuss", "params": {"targets": 3}},
	"bounce": {"label": "Kettenblitz", "params": {"targets": 3, "falloff": 0.8, "radius": 2.5}},
	"armor_reduce": {"label": "Rüstung senken", "params": {"amount": 3.0, "duration": 5.0}},
	"stun": {"label": "Betäubung", "params": {"chance": 0.1, "duration": 1.0}},
	"air_bonus": {"label": "Bonus gegen Luft", "params": {"multiplier": 2.0}},
	"gold_on_hit": {"label": "Gold bei Treffer", "params": {"chance": 0.05, "gold": 1}},
	"speed_aura": {"label": "Tempo-Aura (Tower)", "params": {"radius": 3.0, "bonus": 0.15}},
	"damage_aura": {"label": "Schadens-Aura (Tower)", "params": {"radius": 3.0, "bonus": 0.15}},
	"bounty_aura": {"label": "Kopfgeld-Aura (Tower)", "params": {"radius": 7.8, "bonus": 0.33}},
	"xp_aura": {"label": "Erfahrungs-Aura (Tower)", "params": {"radius": 7.8, "bonus": 0.45}},
	"stacking_damage": {"label": "Steigender Schaden", "params": {"per_hit": 35.0, "duration": 5.0, "death_damage": 0.0, "death_radius": 5.9}},
	"burn_aura": {"label": "Brand-Aura (Gegner)", "params": {"radius": 2.0, "dps": 20.0}},
	"slow_aura": {"label": "Verlangsamungs-Aura (Gegner)", "params": {"radius": 2.0, "factor": 0.3}},
	"armor_aura": {"label": "Rüstungs-Aura (Gegner)", "params": {"radius": 2.0, "amount": 3.0}},
	"cone": {"label": "Kegel", "params": {"length": 4.0, "width_start": 0.5, "width_end": 1.5}},
	"nova": {"label": "Nova", "params": {"chance": 0.1, "damage": 350.0, "radius": 0.78}},
	"wave_damage": {"label": "Schaden pro Welle", "params": {"per_wave": 20.0}},
	# Geschosse wie in Path of Exile, Reihenfolge bei jedem Treffer: Durchbohren → Gabeln → Verketten
	"pierce": {"label": "Durchbohren (Pierce)", "params": {"count": 2, "factor": 1.0}},
	"fork": {"label": "Gabeln (Fork)", "params": {"count": 1, "angle": 30.0, "reach": 3.0, "factor": 1.0}},
	"chain": {"label": "Verketten (Chain)", "params": {"count": 2, "radius": 2.5, "factor": 1.0}},
}

const PARAM_LABELS := {
	"radius": "Radius (Towerbreiten)",
	"factor": "Faktor",
	"duration": "Dauer (s)",
	"dps": "Schaden/s",
	"chance": "Chance",
	"multiplier": "Multiplikator",
	"targets": "Ziele",
	"bonus": "Bonus",
	"falloff": "Abnahme",
	"amount": "Menge",
	"gold": "Gold",
	"length": "Länge (Towerbreiten)",
	"width_start": "Breite am Tower",
	"width_end": "Breite am Ende",
	"count": "Anzahl",
	"angle": "Winkel (°)",
	"reach": "Flugweite (Towerbreiten)",
	"per_hit": "Schaden mehr je Treffer",
	"death_damage": "Explosion beim Tod (0 = keine)",
	"death_radius": "Explosionsradius (Towerbreiten)",
	"per_wave": "Schaden pro Welle",
}


static func types() -> Array:
	return SCHEMA.keys()


static func default_for(type: String) -> Dictionary:
	var d := {"type": type}
	var params: Dictionary = SCHEMA.get(type, {}).get("params", {})
	for k in params:
		d[k] = params[k]
	return d


static func describe(ab: Dictionary) -> String:
	var type := str(ab.get("type", "?"))
	# Gleicher Typname mit eigener Bedeutung in einem Modus (z. B. eeveTD-Kettenblitz "chain"): dessen Text
	if ab.has("text") and type in ["pierce", "fork", "chain"] and not ab.has("count"):
		return str(TranslationServer.translate(str(ab.text)))
	match type:
		"splash":
			return str(TranslationServer.translate("Flächenschaden %d%% im Radius %.1f")) % [float(ab.factor) * 100, float(ab.radius)]
		"slow":
			return str(TranslationServer.translate("Verlangsamt um %d%% für %.1fs")) % [float(ab.factor) * 100, float(ab.duration)]
		"poison":
			return str(TranslationServer.translate("Gift: %.1f Schaden/s für %.1fs")) % [float(ab.dps), float(ab.duration)]
		"crit":
			return str(TranslationServer.translate("%d%% Chance auf %.1fx Schaden")) % [float(ab.chance) * 100, float(ab.multiplier)]
		"multishot":
			return str(TranslationServer.translate("Trifft %d Ziele gleichzeitig")) % int(ab.targets)
		"bounce":
			return str(TranslationServer.translate("Springt auf %d weitere Ziele (je %d%% Schaden)")) % [int(ab.targets), float(ab.falloff) * 100]
		"armor_reduce":
			return str(TranslationServer.translate("Senkt Rüstung um %.0f für %.1fs")) % [float(ab.amount), float(ab.duration)]
		"stun":
			if float(ab.get("damage", 0)) > 0.0:
				return str(TranslationServer.translate("%d%% Chance, %.1fs zu betäuben und %d Zusatzschaden")) % [float(ab.chance) * 100, float(ab.duration), int(ab.damage)]
			return str(TranslationServer.translate("%d%% Chance, %.1fs zu betäuben")) % [float(ab.chance) * 100, float(ab.duration)]
		"air_bonus":
			return str(TranslationServer.translate("%.1fx Schaden gegen Flieger")) % float(ab.multiplier)
		"gold_on_hit":
			if float(ab.get("gold_per_wave", 0)) > 0.0:
				return str(TranslationServer.translate("%d%% Chance auf Gold pro Treffer (%s × Welle)")) % [float(ab.chance) * 100, str(snappedf(float(ab.gold_per_wave), 0.01))]
			return str(TranslationServer.translate("%d%% Chance auf %d Gold pro Treffer")) % [float(ab.chance) * 100, int(ab.gold)]
		"speed_aura":
			return str(TranslationServer.translate("Aura: +%d%% Angriffstempo für Tower im Radius %.1f")) % [float(ab.bonus) * 100, float(ab.radius)]
		"damage_aura":
			return str(TranslationServer.translate("Aura: +%d%% Schaden für Tower im Radius %.1f")) % [float(ab.bonus) * 100, float(ab.radius)]
		"bounty_aura":
			return str(TranslationServer.translate("Aura: +%d%% Kopfgeld für Tower im Radius %.1f")) % [float(ab.bonus) * 100, float(ab.radius)]
		"xp_aura":
			return str(TranslationServer.translate("Aura: +%d%% Erfahrung für Tower im Radius %.1f")) % [float(ab.bonus) * 100, float(ab.radius)]
		"stacking_damage":
			var text := str(TranslationServer.translate(str(ab.text))) if ab.has("text") else str(TranslationServer.translate("Jeder Treffer auf dasselbe Ziel macht %d Schaden mehr als der letzte (%.0fs)")) % [int(ab.per_hit), float(ab.duration)]
			if float(ab.get("death_damage", 0.0)) > 0.0:
				text += str(TranslationServer.translate("; stirbt es dabei, explodiert es für %d Zauberschaden im Radius %.1f")) % [int(ab.death_damage), float(ab.death_radius)]
			return text
		"burn_aura":
			return str(TranslationServer.translate("Verbrennt Gegner im Radius %.1f: %.0f Schaden/s")) % [float(ab.radius), float(ab.dps)]
		"slow_aura":
			return str(TranslationServer.translate("Verlangsamt Gegner im Radius %.1f um %d%%")) % [float(ab.radius), float(ab.factor) * 100]
		"armor_aura":
			return str(TranslationServer.translate("Senkt Rüstung von Gegnern im Radius %.1f um %.0f")) % [float(ab.radius), float(ab.amount)]
		"cone":
			var reach := str(TranslationServer.translate("im Kegel (Länge %.1f, Breite bis %.1f)")) % [float(ab.length), float(ab.width_end) * 2.0]
			if ab.has("damage"):
				var chance := str(TranslationServer.translate("%d%% Chance: ")) % (float(ab.chance) * 100) if ab.has("chance") else ""
				return chance + str(TranslationServer.translate("%d Zauberschaden an allen Gegnern")) % int(ab.damage) + " " + reach
			return str(TranslationServer.translate("Trifft alle Gegner")) + " " + reach
		"pierce":
			return str(TranslationServer.translate("Geschoss durchbohrt %d Gegner")) % int(ab.count) + _factor_text(ab)
		"fork":
			return str(TranslationServer.translate("Geschoss gabelt sich %d× in zwei (±%d°)")) % [int(ab.count), int(ab.get("angle", 30.0))] + _factor_text(ab)
		"chain":
			return str(TranslationServer.translate("Geschoss springt %d× weiter (Radius %.1f)")) % [int(ab.count), float(ab.get("radius", 2.5))] + _factor_text(ab)
	# Fähigkeiten einzelner Modi (z. B. eeveTD) bringen ihren Text in den Daten mit
	return str(TranslationServer.translate(str(ab.get("text", type))))


## Schaden der Geschosse nach Durchbohren/Gabeln/Verketten, nur wenn er sich ändert.
static func _factor_text(ab: Dictionary) -> String:
	var f := float(ab.get("factor", 1.0))
	if is_equal_approx(f, 1.0):
		return ""
	return ", " + str(TranslationServer.translate("danach je %d%% Schaden")) % roundi(f * 100)
