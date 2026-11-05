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
		game.building_hit(e, float(def.damage), self)


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
