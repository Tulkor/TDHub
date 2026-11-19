class_name HdAtmosphere
extends Node3D
## Warm road furniture and small signs of habitation. Static details share material batches;
## only the nearest eight fires have lights/embers. No collision or simulation randomness.
var game: Node3D
var fires: Array[Vector3] = []
var _lamps: Array[OmniLight3D] = []
var _embers: Array[CPUParticles3D] = []
var _clock := 0.0
var _wait := 0.0
var _lane_skips := 0
var _pool_material: ShaderMaterial


func _ready() -> void:
	game = get_parent()
	preload("res://scripts/heroes/hd_settlement_streets.gd").build(game,self)
	var plants := preload("res://scripts/heroes/hd_undergrowth.gd").build(game,self)
	preload("res://scripts/heroes/hd_fields.gd").build(game,self)
	preload("res://scripts/heroes/hd_vegetation_ground.gd").build(game,plants)
	var sky := CanvasLayer.new()
	sky.name="OverheadBirdLayer"
	sky.layer=0
	add_child(sky)
	var birds := preload("res://scripts/heroes/hd_overhead_birds.gd").new()
	birds.name="OverheadBirds"
	birds.game=game
	sky.add_child(birds)
	var builder := HdGothic.new()
	var street_lamps: Array = []
	# Hausecken-Laternen zuerst, damit jede Gasse ihre Lichterkette bekommt (Lukas 2026-11-19: nachts zu dunkel).
	var cathedral: Node=game.get_node_or_null("SchwarzeKathedrale")
	var candidates: Array=(cathedral.get_meta("house_lamps",[]) if cathedral else []).duplicate()
	candidates.append_array(game.get_meta("settlement_street_lamps",[]))
	for lamp in candidates:
		var point: Vector3=lamp.pos
		if not _separated(point,9.0):continue
		_lantern(builder,point,float(lamp.yaw))
		fires.append(point+Vector3.UP*2.02)
		street_lamps.append(point)
	set_meta("street_lantern_positions",street_lamps)
	for road in game.arena_layout.paths:
		# Monsterwege: alle 13 m abwechselnd links und rechts eine Laterne.
		for distance in range(14, int(road.length)-8, 13):
			var at: Vector3 = road.point(distance)
			var direction: Vector3 = (road.point(distance+.5) - road.point(distance-.5)).normalized()
			var side := Vector3(-direction.z, 0, direction.x) * (1.0 if (distance/13)%2==0 else -1.0)
			var point: Vector3 = at + side * (game.arena_layout.width + .7)
			if HdArenaMountains.ground_height(game.arena_layout,point)>1.5:
				_lane_skips+=1
				continue
			if _separated(point, 10.0):
				fires.append(point + Vector3.UP * 2.0)
				_lantern(builder, point, atan2(direction.x, direction.z))
				if (distance/13)%2==0:_clutter(builder, point - direction * 3.0, atan2(direction.x, direction.z), int(distance / 26) % 3)
	for zone in game.cfg.zones.list:
		var center: Vector3 = game.zones.center(str(zone.id))
		for sign in [-1.0, 1.0]:
			var point := center + Vector3(sign*4.5, 0, -3)
			_brazier(builder, point)
			fires.append(point + Vector3.UP * 1.4)
	add_child(builder.commit())
	_build_pools(street_lamps)
	var count := 5 if Display.quality == Display.LOW else 14
	for i in count:
		var light := OmniLight3D.new()
		light.light_color = Color("ffb567")
		light.omni_range = 15.0
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		add_child(light)
		_lamps.append(light)
		if Display.quality != Display.LOW:
			var sparks := HdFxParts.burst(Color("ff9a40"), 7, {"loop":true, "life":2.3, "size":.055, "speed":[.15,.45], "gravity":Vector3(0,.45,0), "spread":30.0})
			add_child(sparks)
			_embers.append(sparks)
	var sound := game.get_node_or_null("Soundscape") as HdSoundscape
	if sound != null: sound.fires = fires.duplicate()
	set_meta("fires", fires.size())
	set_meta("lane_lamp_skips", _lane_skips)
	set_meta("light_budget", count)


## Jede Laterne wirft nachts einen schwachen warmen Schein auf den Boden; ein MultiMesh, keine Lichtquellen.
func _build_pools(street_lamps: Array) -> void:
	_pool_material=ShaderMaterial.new()
	_pool_material.shader=preload("res://assets/shaders/hd_lamp_pool.gdshader")
	var quad := QuadMesh.new()
	quad.size=Vector2(10,10)
	quad.orientation=PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=quad
	var spots: Array=[]
	for at: Vector3 in fires:
		if at.y-HdArenaMountains.ground_height(game.arena_layout,at)>1.6:spots.append(at)
	mm.instance_count=spots.size()
	for i in spots.size():
		var at: Vector3=spots[i]
		at.y=HdArenaMountains.ground_height(game.arena_layout,at)+.07
		mm.set_instance_transform(i,Transform3D(Basis(),at))
	var node := MultiMeshInstance3D.new()
	node.name="LampPools"
	node.multimesh=mm
	node.material_override=_pool_material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	set_meta("lamp_pools",spots.size())


func _separated(point: Vector3, radius: float) -> bool:
	for existing in fires:
		if Vector2(existing.x-point.x, existing.z-point.z).length() < radius: return false
	return true


func _process(dt: float) -> void:
	_clock += dt
	_wait -= dt
	if _wait > 0: return
	_wait = .16
	if _pool_material:
		var dark: float = game.day_cycle.night_amount() if game.day_cycle != null else 1.0
		_pool_material.set_shader_parameter("strength",.02+.17*dark)
	var actor = game.get("hero")
	if not is_instance_valid(actor): return
	var nearby := fires.duplicate()
	nearby.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(actor.position) < b.distance_squared_to(actor.position))
	for i in _lamps.size():
		var lamp := _lamps[i]
		lamp.visible = i < nearby.size() and nearby[i].distance_to(actor.position) < 58.0
		if not lamp.visible:
			if i < _embers.size(): _embers[i].emitting = false
			continue
		lamp.position = nearby[i]
		var night: float = game.day_cycle.night_amount() if game.day_cycle != null else 1.0
		lamp.light_energy = lerpf(1.1, 3.4, night) * (1.0 + sin(_clock*8.7+i)*.045 + sin(_clock*13.1+i*2)*.025)
		if i < _embers.size():
			_embers[i].position = lamp.position
			_embers[i].emitting = true


static func _lantern(b: HdGothic, at: Vector3, yaw: float) -> void:
	b.add("prism", HdGothic.stone(), Vector3(.38,.25,.38), at + Vector3.UP*.125)
	b.add("prism", HdGothic.iron(), Vector3(.07,2.15,.07), at + Vector3.UP*1.2)
	b.add("box", HdGothic.iron(), Vector3(.72,.075,.08), at + Vector3.UP*2.3, yaw)
	var p := at + Basis(Vector3.UP,yaw)*Vector3(.27,2.02,0)
	b.add("box", HdGothic.glow(Color("ffb65a"),2.5), Vector3(.22,.36,.22), p)
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			b.add("box", HdGothic.iron(), Vector3(.035,.44,.035), p + Vector3(x*.13,0,z*.13))
	b.add("pyramid", HdGothic.iron(), Vector3(.26,.22,.26), p + Vector3.UP*.32)
	b.add("box", HdGothic.brass(), Vector3(.32,.06,.32), p - Vector3.UP*.23)


static func _brazier(b: HdGothic, at: Vector3) -> void:
	b.add("prism", HdGothic.stone(), Vector3(.6,.28,.6), at+Vector3.UP*.14)
	b.add("prism", HdGothic.iron(), Vector3(.18,.85,.18), at+Vector3.UP*.65)
	b.add("prism", HdGothic.iron(), Vector3(.6,.22,.6), at+Vector3.UP*1.12)
	b.add("prism", HdGothic.glow(Color("ff6c24"),2.8), Vector3(.48,.08,.48), at+Vector3.UP*1.26)
	for k in 5:
		var angle := k*TAU/5
		b.add("spire", HdGothic.glow(Color("ffb15b"),2.8), Vector3(.12,.45+float(k%2)*.2,.12), at+Vector3(sin(angle)*.22,1.5,cos(angle)*.22),angle,Vector3(.12,0,.1))


static func _clutter(b: HdGothic, at: Vector3, yaw: float, variant: int) -> void:
	var wood := HdCathedral._solid("weathered_wood", Color("43372e"))
	if variant == 0:
		for k in 3:
			var p := at + Vector3(k*.36, .23, 0)
			b.add("prism", wood, Vector3(.27,.46,.27), p)
			for h in [-.14,.14]: b.add("prism", HdGothic.iron(), Vector3(.28,.035,.28), p+Vector3.UP*h)
	elif variant == 1:
		b.add("box", wood, Vector3(.95,.55,.65), at+Vector3.UP*.275,yaw)
		for k in [-1.0,1.0]: b.add("box", HdGothic.iron(), Vector3(.06,.57,.67), at+Vector3(k*.3,.285,0),yaw)
		b.add("box", wood, Vector3(.7,.055,.1), at+Vector3(0,.59,0),yaw,Vector3(0,0,.42))
	else:
		for k in 4:
			b.add("box", HdGothic.stone(), Vector3(.32,.16,.24), at+Vector3(sin(k*3.1)*.45,.09,cos(k*2.7)*.4), k*.7)
		b.add("box", HdGothic.iron(), Vector3(.065,.8,.055), at+Vector3(0,.42,0),yaw,Vector3(0,0,.24))
		b.add("box", HdGothic.brass(), Vector3(.4,.06,.05), at+Vector3(0,.62,0),yaw)
