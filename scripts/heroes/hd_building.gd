class_name HdBuilding
extends Node3D
## Torwerk an einer Straße (Vorwerk oder Innentor, Etappe 2a). Hat Leben und Rüstung, schießt auf
## Gegner in Reichweite. Gegner greifen es nur an, wenn kein Held in ihrer Reichweite ist (Helden vor
## Gebäuden). Gefallen beschleunigt es die Gegner seiner Straße (HdRoad.speed_mult), mit Gold wird es
## repariert oder neu gebaut (HdShop.repair).

var game  ## HdGame
var def: Dictionary
var hp := 1000.0
var max_hp := 1000.0
var armor := 0.0
var radius := 1.5
var cd := 0.0
var destroyed := false
var kind := ""
var road  ## HdRoad
var _meshes: Array = []
var boost_until := 0.0         ## Hochdosis: mehr Schaden, weniger erlittener Schaden
var shield := 0.0
var shield_until := 0.0
var capsule := {}              ## Notfallkapsel von Vesna


## d: Torwerk-Daten (arena.gates), r: seine Straße; ohne r steht in d eine feste Position "pos".
func setup(g, d: Dictionary, r = null) -> void:
	game = g
	def = d
	road = r
	kind = str(d.get("kind", "vorwerk"))
	max_hp = float(d.hp)
	hp = max_hp
	armor = float(d.get("armor", 0))
	radius = float(d.radius)
	if r != null:
		var s: float = r.length * float(d.at)
		position = r.point(s) + r.side(s) * float(d.get("side", 1)) * (float(g.cfg.arena.road_width) * 0.5 + radius + 0.8)
	else:
		var p: Array = d.pos
		position = Vector3(float(p[0]), 0, float(p[1]))
	var stone := HdDev.mat(Color("8d8f96"), 0.5)
	var h := 3.2 if kind == "vorwerk" else 4.2
	_meshes.append(HdDev.cyl(radius * 0.8, radius, h, stone, Vector3(0, h * 0.5, 0), 8))
	_meshes.append(HdDev.cyl(radius * 0.95, radius * 0.95, 0.5, HdDev.mat(Color("6d6f76"), 0.5), Vector3(0, h + 0.25, 0), 8))
	_meshes.append(HdDev.box(Vector3(0.25, 1.2, 0.25), HdDev.mat(Color("5a3a22"), 0.5), Vector3(0, h + 1.0, 0)))
	_meshes.append(HdDev.box(Vector3(0.9, 0.55, 0.05), HdDev.mat(UiTheme.CYAN if kind == "vorwerk" else UiTheme.COIN, 0.5, 0.8), Vector3(0.5, h + 1.3, 0)))
	for m in _meshes:
		add_child(m)


## Name mit Straße, z. B. „Vorwerk Nordstraße“.
func label() -> String:
	return tr(str(def.name)) + ((" " + tr(road.name)) if road != null else "")


func alive() -> bool:
	return not destroyed


func height() -> float:
	return 4.0 if kind == "vorwerk" else 5.0


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
	for c in _meshes:
		c.set_meta("mat", c.material_override)
		c.material_override = HdDev.mat(Color("3a3a3e"), 0.5)
	scale = Vector3(1, 0.4, 1)


## Neu bauen mit einem Teil des Lebens (repair.rebuild_hp).
func rebuild(hp_share: float) -> void:
	destroyed = false
	hp = max_hp * clampf(hp_share, 0.05, 1.0)
	cd = 0.5
	for c in _meshes:
		if c.has_meta("mat"):
			c.material_override = c.get_meta("mat")
	scale = Vector3.ONE
