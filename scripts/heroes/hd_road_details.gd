class_name HdRoadDetails
extends RefCounted
## Rein optische Straßenränder und Laufrichtung, auch auf deaktivierten Lanes.
## Zwei MultiMeshes insgesamt; gemeinsame Abschnitte und überdeckte Bordsteine werden ausgespart.


static func build(parent: Node3D, roads: Array, width: float, plaza_center := Vector3.ZERO, plaza_radius := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "LanePavingDetails"
	parent.add_child(root)
	var segments: Array = []
	var seen := {}
	for road: HdRoad in roads:
		for i in road.points.size() - 1:
			var a: Vector3 = road.points[i]
			var b: Vector3 = road.points[i + 1]
			if seen.has(hash([a, b])) or seen.has(hash([b, a])):
				continue
			seen[hash([a, b])] = true
			segments.append([a, b, road.id])
	var curbs: Array[Transform3D] = []
	var arrows: Array[Transform3D] = []
	var curb_seen := {}
	var arrow_seen := {}
	for road: HdRoad in roads:
		for block in floori(road.length/1.8):
			var distance := (float(block)+.5)*1.8
			var direction := (road.point(minf(road.length,distance+.4))-road.point(maxf(0,distance-.4))).normalized()
			var side := Vector3(-direction.z,0,direction.x)
			for sign_value in [-1.0,1.0]:
				var at: Vector3 = road.point(distance)+side*float(sign_value)*(width*.5+.13)
				var key := Vector2i(roundi(at.x*2),roundi(at.z*2))
				if curb_seen.has(key):continue
				if plaza_radius>0 and at.distance_to(plaza_center)<plaza_radius+.86:continue
				if HdExplorationLayout.mouth_distance(at)<1.1:continue
				if _inside_other_road(at,segments,-1,width*.5+.18,road.id):continue
				curb_seen[key]=true
				at.y=.075
				curbs.append(Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.z))*Basis.from_scale(Vector3(.24,.14,1.72)),at))
		for arrow in floori(road.length/10.0):
			var distance := (float(arrow)+.5)*10.0
			var at := road.point(distance)
			var key := Vector2i(roundi(at.x),roundi(at.z))
			if arrow_seen.has(key):continue
			if plaza_radius>0 and at.distance_to(plaza_center)<plaza_radius+.6:continue
			arrow_seen[key]=true
			var side := road.side(distance)
			var direction := Vector3(side.z,0,-side.x)
			at.y=.027
			for sign_value in [-1.0,1.0]:
				var from: Vector3 = at-direction*.48+side*float(sign_value)*.42
				var to := at+direction*.30
				var delta := to-from
				arrows.append(Transform3D(Basis(Vector3.UP,atan2(delta.x,delta.z))*Basis.from_scale(Vector3(.12,.018,delta.length())),(from+to)*.5))
	# Derselbe Steinbord um den Vorplatz; echte Lane-Einmündungen bleiben frei.
	var plaza_curbs := 0
	if plaza_radius>0:
		var ring_radius := plaza_radius+.13
		var count := ceili(TAU*ring_radius/1.8)
		var block_length := TAU*ring_radius/float(count)-.06
		for i in count:
			var angle := TAU*(float(i)+.5)/float(count)
			var at := plaza_center+Vector3(cos(angle),0,sin(angle))*ring_radius
			if _inside_other_road(at,segments,-1,width*.5+.25):continue
			at.y=.075
			curbs.append(Transform3D(Basis(Vector3.UP,-angle)*Basis.from_scale(Vector3(.24,.14,block_length)),at))
			plaza_curbs+=1
	var curb_material := StandardMaterial3D.new()
	curb_material.albedo_color = Color("797d84")
	curb_material.roughness = 0.86
	curb_material.metallic_specular = 0.28
	var arrow_material := StandardMaterial3D.new()
	arrow_material.albedo_color = Color("b8a67e")
	arrow_material.metallic = 0.35
	arrow_material.roughness = 0.62
	_batch(root, "RoadCurbs", curbs, curb_material, true)
	_batch(root, "RoadChevrons", arrows, arrow_material, false)
	root.set_meta("road_detail_segments", segments.size())
	root.set_meta("plaza_curbs",plaza_curbs)
	root.set_meta("road_detail_batches", int(not curbs.is_empty()) + int(not arrows.is_empty()))
	return root


static func _inside_other_road(at: Vector3, segments: Array, skip: int, radius: float, skip_road := "") -> bool:
	for index in segments.size():
		if index == skip or (not skip_road.is_empty() and str(segments[index][2])==skip_road):
			continue
		var a: Vector3 = segments[index][0]
		var b: Vector3 = segments[index][1]
		var delta := b - a
		var closest := a + delta * clampf((at - a).dot(delta) / maxf(delta.length_squared(), 0.001), 0.0, 1.0)
		if at.distance_squared_to(closest) < radius * radius:
			return true
	return false


static func _batch(root: Node3D, title: String, transforms: Array[Transform3D], material: Material, shadows: bool) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = title
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
