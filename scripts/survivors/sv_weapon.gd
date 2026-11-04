class_name SvWeapon
extends RefCounted
## Eine ausgerüstete Waffe auf einem Montageplatz: Werte aus survivors.json → weapons, Stufe 1–5,
## Zielwahl (nächster Gegner am Turm in Reichweite), Drehen, Feuern. Die Wirkung (Geschosse, Strahlen,
## Flächen) setzt SvGame/SvFx um, hier stehen nur Werte und Zielen.

var game  ## SvGame
var data: Dictionary
var id := ""
var slot := 0
var level := 1
var yaw: Node3D
var recoil: Node3D
var cd_left := 0.0
var damage_done := 0.0
var kills := 0
var best_wave_damage := 0.0
var best_wave := 0
var wave_damage := 0.0
var _kick := 0.0

## Zuschläge wegen der großen Plattform: Zielsuche ab Turmmitte, Flächen (Kegel, Nova) ab dem Platz
const REACH_BONUS := 1.5
const AREA_BONUS := 1.2


func _init(g, d: Dictionary, s: int) -> void:
	game = g
	data = d
	id = str(d.id)
	slot = s


func kind() -> String:
	return str(data.get("kind", "bullet"))


func type() -> String:
	return str(data.get("type", "phys"))


func damage() -> float:
	return float(data.damage) * (1.0 + float(game.cfg.get("level_damage", 0.45)) * (level - 1)) * (1.0 + game.mod("damage"))


func cooldown() -> float:
	return float(data.cooldown) / (1.0 + game.mod("rate"))


func range_() -> float:
	return float(data.range) * (1.0 + float(game.cfg.get("level_range", 0.04)) * (level - 1)) * (1.0 + game.mod("range"))


func shots() -> int:
	var n := int(data.get("shots", 1))
	if kind() == "bullet":
		n += int(game.mod("shots"))
	return n


func chain() -> int:
	var c := int(data.get("chain", 0))
	return c + int(game.mod("chain")) if c > 0 else 0


func splash() -> float:
	return float(data.get("splash", 0.0)) * (1.0 + game.mod("splash"))


func slow() -> Vector2:
	var s: Dictionary = data.get("slow", {})
	if s.is_empty():
		return Vector2.ZERO
	return Vector2(float(s.pct) + game.mod("slow"), float(s.time))


## Brennen bzw. Gift: (Schaden/s, Dauer), wächst mit Stufe, Schaden-Upgrades und Brandbeschleuniger.
func dot(key: String) -> Vector2:
	var s: Dictionary = data.get(key, {})
	if s.is_empty():
		return Vector2.ZERO
	var f: float = (1.0 + float(game.cfg.get("level_damage", 0.45)) * (level - 1)) * (1.0 + game.mod("damage")) * (1.0 + game.mod("dot"))
	return Vector2(float(s.dps) * f, float(s.time))


## Schaden pro Sekunde auf ein Ziel ohne Rüstung (für die Anzeige).
func dps() -> float:
	var d := damage() * shots()
	if kind() == "cone":
		d = damage()
	var v := d / maxf(cooldown(), 0.05)
	v += dot("burn").x + dot("poison").x
	return v


## Zielsuche ab der Turmmitte: Reichweite plus ein Stück Deck, damit Waffen auf der Rückseite der
## großen Plattform (Lukas 2026-11-04) nicht leer ausgehen.
func reach() -> float:
	return range_() + REACH_BONUS


func center() -> Vector3:
	return Vector3(0, origin().y, 0)


func origin() -> Vector3:
	return yaw.global_position if yaw else Vector3.ZERO


func step(dt: float) -> void:
	cd_left -= dt
	if not game.platform.is_up(slot):
		return  # fährt noch aus der Klappe hoch
	if _kick > 0.0:
		_kick = maxf(0.0, _kick - dt * 6.0)
		recoil.position.z = _kick * 0.25
	if kind() == "nova":
		# Novas drehen sich langsam und feuern, sobald ein Gegner im Ring ist
		yaw.rotation.y += dt * 1.5
		if cd_left <= 0.0 and game.nearest(origin(), range_() + AREA_BONUS) != null:
			cd_left = cooldown()
			game.fire(self, null)
		return
	var target = game.nearest(center(), reach())
	if target == null:
		return
	var d: Vector3 = target.global_position - origin()
	var want := atan2(-d.x, -d.z)
	yaw.rotation.y = rotate_toward(yaw.rotation.y, want, dt * 9.0)
	if cd_left <= 0.0 and absf(angle_difference(yaw.rotation.y, want)) < 0.35:
		cd_left = cooldown()
		_kick = 1.0
		game.fire(self, target)


## Richtung, in die der Lauf gerade zeigt (waagrecht).
func forward() -> Vector3:
	return Vector3(-sin(yaw.rotation.y), 0, -cos(yaw.rotation.y))


func muzzle() -> Vector3:
	return origin() + forward() * 0.8 + Vector3(0, 0.35, 0)


func add_damage(v: float) -> void:
	damage_done += v
	wave_damage += v
