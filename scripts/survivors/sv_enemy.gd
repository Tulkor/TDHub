class_name SvEnemy
extends Node3D
## Gegner in Tower Survivors: läuft gerade auf den Turm zu und greift ihn an, sobald er die Plattform
## erreicht. Werte aus survivors.json → enemies, Leben mit Wellen- und Schwierigkeitsfaktor.
## Verlangsamung, Brennen und Gift laufen hier; Schaden rechnet SvGame.damage().

var data: Dictionary
var id := ""
var hp := 1.0
var max_hp := 1.0
var speed := 2.0
var dps := 5.0
var armor := 0.0
var gold := 1.0
var size := 0.6
var fly := false
var boss := false
var resist: Dictionary = {}
var slow_immune := false
var stop_dist := 3.0
var attacking := false
var dead := false
var ground: Callable  ## Bodenhöhe (x, z) → y, SvWorld.height_at

var slow_pct := 0.0
var slow_time := 0.0
var burn := Vector2.ZERO    ## (Schaden/s, Restzeit)
var poison := Vector2.ZERO
var burn_src = null         ## Waffe, die den Brand gesetzt hat (Statistik)
var poison_src = null

var _body: MeshInstance3D
var _bar_bg: MeshInstance3D
var _bar: MeshInstance3D
var _flash := 0.0
var _bob := 0.0


func setup(d: Dictionary, hp_factor: float, dps_factor: float, tower_radius: float) -> void:
	data = d
	id = str(d.id)
	max_hp = float(d.hp) * hp_factor
	hp = max_hp
	speed = float(d.speed)
	dps = float(d.dps) * dps_factor
	armor = float(d.get("armor", 0))
	gold = float(d.get("gold", 1))
	size = float(d.get("size", 0.6))
	fly = bool(d.get("fly", false))
	boss = bool(d.get("boss", false))
	resist = d.get("resist", {})
	slow_immune = bool(d.get("slow_immune", false))
	stop_dist = tower_radius + size * 0.5 + randf_range(0.0, 0.5)
	_bob = randf() * TAU
	_build()


func _build() -> void:
	_body = MeshInstance3D.new()
	var c := Color(str(data.get("color", "c84040")))
	match str(data.get("shape", "box")):
		"sphere":
			var s := SphereMesh.new()
			s.radius = size * 0.5
			s.height = size
			s.radial_segments = 12
			s.rings = 6
			_body.mesh = s
		"pyramid":
			var p := CylinderMesh.new()
			p.top_radius = 0.0
			p.bottom_radius = size * 0.7
			p.height = size
			p.radial_segments = 4
			_body.mesh = p
		_:
			var b := BoxMesh.new()
			b.size = Vector3.ONE * size
			_body.mesh = b
	_body.material_override = SvDev.mat(c, 1.0 / maxf(size, 0.4) * 0.5, 0.35)  # leicht selbstleuchtend, nachts sichtbar
	_body.position.y = (2.2 if fly else 0.0) + size * 0.5
	add_child(_body)
	if fly:
		# Schatten-Fleck am Boden, damit man die Höhe sieht
		var sh := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2.ONE * size
		sh.mesh = q
		sh.material_override = SvDev.flat(Color(0, 0, 0), 0.35)
		sh.position.y = 0.03
		add_child(sh)
	var bar_y := _body.position.y + size * 0.5 + 0.35
	var w := clampf(size * 1.4, 0.8, 3.0)
	_bar_bg = _quad(Vector2(w, 0.12), Color(0, 0, 0), 0.7)
	_bar_bg.position.y = bar_y
	_bar = _quad(Vector2(w, 0.12), Color("ff4f6a") if not boss else Color("ff4fd8"), 1.0)
	_bar.position.y = bar_y
	_bar.sorting_offset = 0.1
	add_child(_bar_bg)
	add_child(_bar)
	_bar_bg.visible = false
	_bar.visible = false


func _quad(s: Vector2, c: Color, a: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = s
	mi.mesh = q
	var m := SvDev.flat(c, a).duplicate() as StandardMaterial3D
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	mi.material_override = m
	return mi


func current_speed() -> float:
	return speed * (1.0 - (0.0 if slow_time <= 0.0 else slow_pct / 100.0))


func apply_slow(pct: float, time: float) -> void:
	if slow_immune or pct <= 0.0:
		return
	pct = minf(pct, 80.0)
	if pct >= slow_pct or slow_time <= 0.0:
		slow_pct = pct
	slow_time = maxf(slow_time, time)


## Bewegen, Effekte, Angriff. Gibt den Schaden zurück, den der Gegner dem Turm in diesem Schritt macht.
func step(dt: float) -> float:
	if slow_time > 0.0:
		slow_time -= dt
	if _flash > 0.0:
		_flash -= dt
		_body.scale = Vector3.ONE * (1.0 + _flash * 1.2)
	_bob += dt * 4.0
	if fly:
		_body.position.y = 2.2 + size * 0.5 + sin(_bob) * 0.15
	var flat := Vector3(position.x, 0, position.z)  # Abstand nur in der Ebene
	var d := flat.length()
	if d > stop_dist:
		attacking = false
		var mv := minf(current_speed() * dt, d - stop_dist)
		position -= flat.normalized() * mv
		if ground.is_valid():
			position.y = ground.call(position.x, position.z)
		look_at(Vector3(0.001, position.y, 0), Vector3.UP)
		return 0.0
	attacking = true
	# kleines Wippen beim Angriff
	_body.position.z = -absf(sin(_bob * 1.5)) * 0.15
	return dps * dt


func hit_flash() -> void:
	_flash = 0.12
	_update_bar()


func _update_bar() -> void:
	var f := clampf(hp / max_hp, 0.0, 1.0)
	_bar_bg.visible = f < 1.0
	_bar.visible = f < 1.0
	_bar.scale.x = maxf(f, 0.001)


func center() -> Vector3:
	return global_position + Vector3(0, _body.position.y, 0)
