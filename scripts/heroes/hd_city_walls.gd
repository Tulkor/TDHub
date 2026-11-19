class_name HdCityWalls
extends RefCounted
## Massive Stadtbefestigung auf der gesperrten Seite der bestehenden Lane-Kontur.
## Statische, gecachte MultiMeshes; die Spiellogik bleibt in HdArena.

static var _cache: Dictionary = {}
static var _trim: StandardMaterial3D
var _groups := {}
var _towers: Array[Vector3] = []


static func build(game, parent: Node3D, edges: Array, cache_key: int) -> Node3D:
	var root := Node3D.new()
	root.name = "CityFortifications"
	parent.add_child(root)
	if not _cache.has(cache_key):
		var builder := HdCityWalls.new()
		builder._generate(game,edges)
		if _cache.size() >= 4:_cache.clear()
		_cache[cache_key]={"groups":builder._groups,"towers":builder._towers.size()}
	var entry: Dictionary = _cache[cache_key]
	for group in entry.groups.values():
		var multimesh := MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=HdGothic.shape(str(group.get("kind","box")))
		multimesh.instance_count=group.transforms.size()
		for i in group.transforms.size():multimesh.set_instance_transform(i,group.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh=multimesh
		instance.material_override=group.material
		root.add_child(instance)
	root.set_meta("city_wall_edges",edges.size())
	root.set_meta("city_wall_towers",entry.towers)
	root.set_meta("city_wall_height",5.0)
	var walks: Array = []
	for edge in edges:
		walks.append([edge[0]-edge[2]*1.0,edge[1]-edge[2]*1.0])
	preload("res://scripts/map/ground_wear.gd").add_paths(root,walks,1.25,"heroes")
	return root


func _generate(game, edges: Array) -> void:
	var stone := HdCathedral.wall_material()
	if _trim == null:
		_trim=StandardMaterial3D.new()
		_trim.albedo_color=Color("626a79")
		_trim.roughness=.76
	var walkway := HdCathedral.roof_material()
	for edge in edges:
		var a: Vector3=edge[0]
		var b: Vector3=edge[1]
		var outside: Vector3=edge[2]
		var along: Vector3=(b-a).normalized()
		var middle: Vector3=(a+b)*.5
		var yaw := atan2(along.x,along.z)
		var center := middle+outside*.98
		var length := a.distance_to(b)
		_box(center+Vector3.UP*2.5,Vector3(1.8,5.0,length+.02),stone,yaw)
		_box(center+Vector3.UP*.3,Vector3(2.05,.6,length+.04),stone,yaw)
		_box(center+Vector3.UP*5.03,Vector3(2.1,.28,length+.04),_trim,yaw)
		_box(center+Vector3.UP*5.2,Vector3(1.7,.09,length+.02),walkway,yaw)
		# Doppelter Zinnenkranz rahmt den dunklen Wehrgang ein.
		for side in [-1.0,1.0]:
			_box(center+outside*side*.77+Vector3.UP*5.55,Vector3(.42,.92,.9),stone,yaw)
		var rhythm := floori((middle.x if absf(along.x)>.5 else middle.z)/2.0)
		if posmod(rhythm,4)==0:
			var support := middle+outside*2.12
			if not game.arena_layout.inside(support,-.8):
				_box(support+Vector3.UP*1.9,Vector3(1.25,3.8,1.1),stone,yaw)
				_box(support+Vector3.UP*3.87,Vector3(1.4,.2,1.25),_trim,yaw)
				# Fiale auf dem Strebepfeiler und eiserner Dorn auf der Mauerkrone
				_box(support+Vector3.UP*4.3,Vector3(.6,.7,.6),stone,yaw)
				_spire(support+Vector3.UP*5.45,Vector3(.62,1.6,.62),walkway,yaw)
				_box(support+Vector3.UP*6.45,Vector3(.05,.5,.05),HdGothic.brass(),yaw)
				_spire(center+Vector3.UP*6.6,Vector3(.42,1.25,.42),HdGothic.iron(),yaw)
		# Große Wachttürme stehen auf sicheren Vorplätzen, nie im Korridor.
		if posmod(rhythm,10)==0 and _towers.size()<16:
			var site := middle+outside*3.1
			if game.arena_layout.boundary_kind(site)!="city" or game.arena_layout.inside(site,-2.65):continue
			var clear := true
			for tower in _towers:
				if tower.distance_squared_to(site)<324:clear=false
			if clear:
				_towers.append(site)
				_tower(site,stone,walkway,yaw)


func _spire(at: Vector3, size: Vector3, material: Material, yaw: float) -> void:
	var key := "spire:%d" % material.get_instance_id()
	if not _groups.has(key):_groups[key]={"material":material,"transforms":[],"kind":"pyramid"}
	_groups[key].transforms.append(Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(size),at))


func _tower(at: Vector3, stone: Material, walkway: Material, yaw: float) -> void:
	# Gotischer Turmhelm: Trommel, steiler Schieferhelm mit Kreuzblume, Eckfialen und Strebepfeiler.
	_box(at+Vector3.UP*8.1,Vector3(2.9,1.3,2.9),stone,yaw)
	_box(at+Vector3.UP*8.82,Vector3(3.2,.16,3.2),_trim,yaw)
	_spire(at+Vector3.UP*11.7,Vector3(3.1,5.6,3.1),walkway,yaw)
	_box(at+Vector3.UP*14.9,Vector3(.07,1.2,.07),HdGothic.brass(),yaw)
	_box(at+Vector3.UP*15.1,Vector3(.5,.07,.07),HdGothic.brass(),yaw)
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			var corner := at+Vector3(sx*1.95,0,sz*1.95).rotated(Vector3.UP,yaw)
			_spire(corner+Vector3.UP*9.45,Vector3(.75,1.9,.75),walkway,yaw)
			_box(corner+Vector3.UP*2.4,Vector3(1.0,4.8,1.0),stone,yaw+PI*.25)
			_spire(corner+Vector3.UP*5.5,Vector3(1.0,1.4,1.0),stone,yaw+PI*.25)
	for side in [-1.0,1.0]:
		for face in [Vector3(side*2.12,0,0),Vector3(0,0,side*2.12)]:
			_box(at+(face+Vector3.UP*4.3).rotated(Vector3.UP,yaw),Vector3(.05 if face.x!=0.0 else .5,1.7,.5 if face.x!=0.0 else .05),HdGothic.window(),yaw)
			_box(at+(face+Vector3.UP*5.3).rotated(Vector3.UP,yaw),Vector3(.05 if face.x!=0.0 else .3,.34,.3 if face.x!=0.0 else .05),HdGothic.window(),yaw)
	_box(at+Vector3.UP*3.6,Vector3(4.2,7.2,4.2),stone,yaw)
	_box(at+Vector3.UP*.35,Vector3(4.6,.7,4.6),stone,yaw)
	_box(at+Vector3.UP*7.22,Vector3(4.65,.3,4.65),_trim,yaw)
	_box(at+Vector3.UP*7.42,Vector3(4.15,.1,4.15),walkway,yaw)
	for side in [-1.0,1.0]:
		for offset in [-1.5,0.0,1.5]:
			for local in [Vector3(side*1.95,8.0,offset),Vector3(offset,8.0,side*1.95)]:
				_box(at+local.rotated(Vector3.UP,yaw),Vector3(.7,1.05,.7),stone,yaw)
		for level in [2.8,5.4]:
			_box(at+Vector3(side*2.11,level,0).rotated(Vector3.UP,yaw),Vector3(.035,.75,.13),walkway,yaw)
			_box(at+Vector3(0,level,side*2.11).rotated(Vector3.UP,yaw),Vector3(.13,.75,.035),walkway,yaw)


func _box(at: Vector3, size: Vector3, material: Material, yaw: float) -> void:
	var key := material.get_instance_id()
	if not _groups.has(key):_groups[key]={"material":material,"transforms":[]}
	_groups[key].transforms.append(Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(size),at))
