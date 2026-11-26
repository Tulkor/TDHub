extends Node2D
## Ein Vordergrund-Silhouettenzug, keine Weltakteure, Schatten, Hitboxen oder Netzwerkdaten.
## Gedachte Flughöhe 50–100 m; die Spielkamera liegt unter dieser Ebene.
var game: Node3D
var _rng := RandomNumberGenerator.new()
var _wait := 14.0
var _age := 0.0
var _duration := 14.0
var _redraw := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _flock: Array = []
var altitude := 75.0

func _ready() -> void:
	_rng.randomize()
	_wait=_rng.randf_range(9,20)
	z_index=0

func _allowed() -> bool:
	if game.paused or game.state!="play" or not is_instance_valid(game.hero):return false
	return not game.event_arena.active and not game.final.active and HdExplorationLayout.cave_at(game.hero.position).is_empty()

func _process(dt: float) -> void:
	if not _allowed():
		if visible:hide()
		return
	if not visible:show()
	if _flock.is_empty():
		_wait-=dt
		if _wait<=0:begin_flock()
		return
	_age+=dt
	_redraw-=dt
	if _age>=_duration:
		_flock.clear()
		_wait=_rng.randf_range(28,65)
		queue_redraw()
	elif _redraw<=0:
		_redraw=1.0/(20.0 if Display.quality==Display.LOW else 30.0)
		queue_redraw()

func begin_flock() -> void:
	_age=0
	_duration=_rng.randf_range(12,18)
	altitude=_rng.randf_range(50,100)
	var reverse := _rng.randf()<.5
	_from=Vector2(1.15 if reverse else -.15,_rng.randf_range(.2,.65))
	_to=Vector2(-.15 if reverse else 1.15,clampf(_from.y+_rng.randf_range(-.25,.25),.12,.8))
	_flock.clear()
	for i in (_rng.randi_range(2,3) if Display.quality==Display.LOW else _rng.randi_range(3,6)):
		_flock.append({"offset":Vector2(-float(i)*.026,absf(float(i%2)*2-1)*float(i)*.018),"phase":_rng.randf()*TAU,"size":_rng.randf_range(.85,1.12)})
	queue_redraw()

func _draw() -> void:
	if _flock.is_empty():return
	var screen := get_viewport_rect().size
	var center := _from.lerp(_to,clampf(_age/_duration,0,1))*screen
	var angle := (_to-_from).angle()
	var color := Color(.045,.052,.06,.82)
	for bird in _flock:
		var at: Vector2=center+(bird.offset as Vector2)*screen
		var size: float=lerpf(19,11,(altitude-50)/50)*float(bird.size)*screen.y/900
		# Kurze Schlagfolgen wechseln mit Gleitflug.
		var cycle := fposmod(_age+float(bird.phase),6.5)
		var wing := sin(_age*13+float(bird.phase))*.42 if cycle<2.8 else .16
		var points := [Vector2(.9,0),Vector2(.08,-.16),Vector2(-.48,-.92-wing),Vector2(-.76,-1.02-wing),Vector2(-.48,-.28),Vector2(-.82,-.1),Vector2(-1.08,0),Vector2(-.82,.1),Vector2(-.48,.28),Vector2(-.76,1.02+wing),Vector2(-.48,.92+wing),Vector2(.08,.16)]
		var polygon := PackedVector2Array()
		for point: Vector2 in points:polygon.append(at+point.rotated(angle)*size)
		draw_colored_polygon(polygon,color)
