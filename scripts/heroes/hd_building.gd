class_name HdBuilding
extends Node3D
## Gebäude auf der Straße (Etappe 1: ein Vorwerk). Hat Leben und Rüstung, schießt auf Gegner in
## Reichweite. Gegner greifen es nur an, wenn kein Held in ihrer Reichweite ist (Helden vor Gebäuden).

var game  ## HdGame
var def: Dictionary
var hp := 1000.0
var max_hp := 1000.0
var armor := 0.0
var radius := 1.5
var cd := 0.0
var destroyed := false
var boost_until := 0.0         ## Hochdosis: mehr Schaden, weniger erlittener Schaden
var shield := 0.0
var shield_until := 0.0
var capsule := {}              ## Notfallkapsel von Vesna


func setup(g, d: Dictionary) -> void:
	game = g
	def = d
	max_hp = float(d.hp)
	hp = max_hp
	armor = float(d.get("armor", 0))
	radius = float(d.radius)
	var p: Array = d.pos
	position = Vector3(float(p[0]), 0, float(p[1]))
	var stone := HdDev.mat(Color("8d8f96"), 0.5)
	add_child(HdDev.cyl(radius * 0.8, radius, 3.2, stone, Vector3(0, 1.6, 0), 8))
	add_child(HdDev.cyl(radius * 0.95, radius * 0.95, 0.5, HdDev.mat(Color("6d6f76"), 0.5), Vector3(0, 3.45, 0), 8))
	add_child(HdDev.box(Vector3(0.25, 1.2, 0.25), HdDev.mat(Color("5a3a22"), 0.5), Vector3(0, 4.2, 0)))
	add_child(HdDev.box(Vector3(0.9, 0.55, 0.05), HdDev.mat(UiTheme.CYAN, 0.5, 0.8), Vector3(0.5, 4.5, 0)))


func alive() -> bool:
	return not destroyed


func height() -> float:
	return 4.0


func boosted() -> bool:
	return game.play_time < boost_until


## Schadensfaktor eigener Angriffe (Hochdosis +50 %).
func out_mult() -> float:
	return 1.5 if boosted() else 1.0


## Eingehender Schaden nach Hochdosis und Schild (Rüstung rechnet HdGame).
func incoming(amount: float) -> float:
	if boosted():
		amount *= 0.5
	if shield > 0.0 and game.play_time < shield_until:
		var soak := minf(shield, amount)
		shield -= soak
		amount -= soak
	return amount


func add_shield(amount: float, time: float) -> void:
	shield = (shield if game.play_time < shield_until else 0.0) + amount
	shield_until = game.play_time + time


func shield_left() -> float:
	return shield if game.play_time < shield_until else 0.0


func heal(amount: float, quiet := false) -> float:
	if destroyed or amount <= 0.0:
		return 0.0
	var got := minf(amount, max_hp - hp)
	hp += got
	if not quiet and got >= 1.0:
		game.floater(position + Vector3(0, height() + 0.6, 0), "+%d" % roundi(got), UiTheme.HAVE)
	return got


func step(dt: float) -> void:
	if destroyed:
		return
	cd -= dt
	if cd > 0.0:
		return
	var e = game.nearest_enemy(position, float(def.range))
	if e:
		cd = float(def.interval)
		game.fx.tracer(position + Vector3(0, 3.8, 0), e.position + Vector3(0, e.height() * 0.6, 0), UiTheme.CYAN)
		game.building_hit(e, float(def.damage) * out_mult(), self)


func destroy() -> void:
	destroyed = true
	for c in get_children():
		if c is MeshInstance3D:
			c.material_override = HdDev.mat(Color("3a3a3e"), 0.5)
	scale = Vector3(1, 0.4, 1)
