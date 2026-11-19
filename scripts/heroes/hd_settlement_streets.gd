extends RefCounted
## Lokale Gehwege in den ungenutzten Siedlungsparzellen. Keine neue Lane-Verbindung/Kollision.
const CELL := 16.0

static func build(game, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name="SettlementWalkways"
	parent.add_child(root)
	var cathedral: Node=game.get_node_or_null("SchwarzeKathedrale")
	if cathedral==null:return root
	var sites: Array=cathedral.get_meta("street_sites",[])
	var pairs: Array = []
	for a in sites.size():
		for b in range(a+1,sites.size()):
			var distance: float=(sites[a].approach as Vector3).distance_to(sites[b].approach)
			if distance>4 and distance<37:pairs.append({"a":a,"b":b,"distance":distance})
	pairs.sort_custom(func(a,b):return float(a.distance)<float(b.distance))
	var degree := {}
	var paths: Array = []
	var access_paths: Array=[]
	var lamps: Array = []
	for pair in pairs:
		var a := int(pair.a)
		var b := int(pair.b)
		if int(degree.get(a,0))>=3 or int(degree.get(b,0))>=3:continue
		var path := _route(game,sites,a,b)
		if path.is_empty():continue
		paths.append(path)
		degree[a]=int(degree.get(a,0))+1
		degree[b]=int(degree.get(b,0))+1
		if paths.size()%2==1:
			var middle := path.size()/2
			var at: Vector3=path[middle]
			var direction: Vector3=(path[mini(path.size()-1,middle+1)]-path[maxi(0,middle-1)]).normalized()
			for sign_side in [-1.0,1.0]:
				var point := at+Vector3(-direction.z,0,direction.x)*float(sign_side)*1.6
				if _clear(game,point,sites,-1,-1) and lamps.all(func(lamp):return (lamp.pos as Vector3).distance_to(point)>16):
					point.y=HdArenaMountains.ground_height(game.arena_layout,point)
					lamps.append({"pos":point,"yaw":atan2(direction.x,direction.z)})
					break
	# Kurze Seitenstraßen öffnen die Viertel zur bestehenden Monsterstraße.
	for index in sites.size():
		var site: Dictionary=sites[index]
		if not site.get("town",false):continue
		var start: Vector3=site.approach
		start.y=0
		var lane: Vector3=game.arena_layout.nearest(start)
		if lane.distance_to(start)>32:continue
		if access_paths.any(func(path):return (path[-1] as Vector3).distance_to(lane)<18):continue
		var path: Array=[start,lane]
		var valid := true
		for meter in ceili(start.distance_to(lane))+1:
			var at := start.move_toward(lane,float(meter))
			if not _clear(game,at,sites,index,-1,true) or HdArenaMountains.ground_height(game.arena_layout,at)>6:
				valid=false
				break
		if valid:
			paths.append(path)
			access_paths.append(path)
	var bins := {}
	for route_index in paths.size():
		var path: Array=paths[route_index]
		for i in path.size()-1:
			var a: Vector3=path[i]
			var b: Vector3=path[i+1]
			var delta := b-a
			var segment := [a,delta,1.0/maxf(.001,Vector2(delta.x,delta.z).length_squared()),route_index]
			for z in range(floori((minf(a.z,b.z)-8)/CELL),floori((maxf(a.z,b.z)+8)/CELL)+1):
				for x in range(floori((minf(a.x,b.x)-8)/CELL),floori((maxf(a.x,b.x)+8)/CELL)+1):
					var key := Vector2i(x,z)
					if not bins.has(key):bins[key]=[]
					bins[key].append(segment)
	game.set_meta("settlement_street_bins",bins)
	game.set_meta("settlement_street_paths",paths)
	game.set_meta("settlement_city_access",access_paths)
	game.set_meta("settlement_street_lamps",lamps)
	var removed := _clear_trees(game)
	root.set_meta("cleared_trees",removed)
	# Oberfläche wird zusammen mit dem Vegetationsboden gebacken, ohne überlagerte Wegplatten.
	game.set_meta("settlement_islands",_islands(game,sites))
	root.set_meta("path_count",paths.size())
	root.set_meta("paths",paths)
	root.set_meta("lamp_candidates",lamps)
	return root

static func _route(game, sites: Array, a: int, b: int) -> Array:
	var start: Vector3=sites[a].approach
	var end: Vector3=sites[b].approach
	var direction := (end-start).normalized()
	var side := Vector3(-direction.z,0,direction.x)
	for bend in [0.0,4.0,-4.0,8.0,-8.0,12.0,-12.0]:
		var raw: Array=[sites[a].door,start,(start+end)*.5+side*float(bend),end,sites[b].door]
		var path := HdRoad.rounded(raw,3.4)
		var valid := true
		for i in path.size()-1:
			var from: Vector3=path[i]
			var to: Vector3=path[i+1]
			var steps := maxi(1,ceili(from.distance_to(to)))
			var previous := HdArenaMountains.ground_height(game.arena_layout,from)
			for k in steps+1:
				var at := from.lerp(to,float(k)/steps)
				if not _clear(game,at,sites,a,b):
					valid=false
					break
				var h := HdArenaMountains.ground_height(game.arena_layout,at)
				if absf(h-previous)>.65 or h>6:
					valid=false
					break
				previous=h
			if not valid:break
		if valid:return path
	return []

static func _clear(game, at: Vector3, sites: Array, own_a: int, own_b: int, lane_access := false) -> bool:
	var flat := Vector3(at.x,0,at.z)
	# Die gesperrten Parzellen dürfen nicht durch eine neue Schneise quer über Lanes verbunden werden.
	if (not lane_access and game.arena_layout.inside(flat,-.5)) or game.arena_layout.divider_distance(flat)<4.0:return false
	if HdExplorationLayout.clearance(flat)<3.5:return false
	if game.arena_layout._city_blocked(flat,.7):return false
	for index in sites.size():
		var site: Dictionary=sites[index]
		if index in [own_a,own_b]:
			var from_door := Vector3(at.x-site.door.x,0,at.z-site.door.z)
			var forward: Vector3=site.front
			var along := from_door.dot(forward)
			if along>=-.35 and (from_door-forward*along).length()<1.8:continue
		if Vector2(at.x-site.center.x,at.z-site.center.z).length()<float(site.radius)+.4:return false
	return true

static func distance(game, at: Vector3) -> float:
	var key := Vector2i(floori(at.x/CELL),floori(at.z/CELL))
	var best := INF
	for segment in game.get_meta("settlement_street_bins",{}).get(key,[]):
		var start: Vector3=segment[0]
		var delta: Vector3=segment[1]
		var p := start+delta*clampf((Vector3(at.x,0,at.z)-Vector3(start.x,0,start.z)).dot(Vector3(delta.x,0,delta.z))*float(segment[2]),0,1)
		best=minf(best,Vector2(at.x-p.x,at.z-p.z).length())
	return best

## Freie Taschen zwischen zwei verschiedenen Wegen, keine Bepflanzung vor Türen.
static func _islands(game, sites: Array) -> Array:
	var result: Array=[]
	var bounds: Array=game.cfg.arena.bounds
	for z in range(int(bounds[1])+8,int(bounds[3])-8,3):
		for x in range(int(bounds[0])+8,int(bounds[2])-8,3):
			var at := Vector3(x+.7,0,z+.3)
			if not _clear(game,at,sites,-1,-1):continue
			var nearest := {}
			var key := Vector2i(floori(at.x/CELL),floori(at.z/CELL))
			for segment in game.get_meta("settlement_street_bins",{}).get(key,[]):
				var a: Vector3=segment[0]
				var d: Vector3=segment[1]
				var point := a+d*clampf((at-a).dot(d)*float(segment[2]),0,1)
				var offset := Vector2(point.x-at.x,point.z-at.z)
				if not nearest.has(segment[3]) or offset.length_squared()<(nearest[segment[3]] as Vector2).length_squared():nearest[segment[3]]=offset
			var offsets: Array=nearest.values()
			offsets.sort_custom(func(a,b):return a.length_squared()<b.length_squared())
			if offsets.size()<2:continue
			var gap: float=offsets[0].length()
			if gap<2.8 or gap>6.5:continue
			var between := false
			for other: Vector2 in offsets:
				if other.length()<8 and (offsets[0] as Vector2).normalized().dot(other.normalized())<.5:between=true
			if not between or result.any(func(island):return (island.pos as Vector3).distance_to(at)<8):continue
			if sites.any(func(site):return (site.door as Vector3).distance_to(at)<6):continue
			var radius := minf(2.4,gap-1.5)
			result.append({"pos":at,"radius":radius,"tree":gap>3.6})
	return result

static func _clear_trees(game) -> int:
	var root: Node=game.get_node_or_null("MixedBoundaries/OuterMountainBoundaries")
	if root==null:return 0
	var removed := 0
	for node in root.get_children():
		if not node is MultiMeshInstance3D or not str(node.get_meta("nature_id","")).begins_with("pine"):continue
		var kept: Array[Transform3D] = []
		for i in node.multimesh.instance_count:
			var transform: Transform3D=node.multimesh.get_instance_transform(i)
			if distance(game,transform.origin)>2.1:kept.append(transform)
		if kept.size()==node.multimesh.instance_count:continue
		removed+=node.multimesh.instance_count-kept.size()
		node.multimesh.instance_count=kept.size()
		for i in kept.size():node.multimesh.set_instance_transform(i,kept[i])

	root.set_meta("mountain_trees",maxi(0,int(root.get_meta("mountain_trees",0))-removed))
	return removed
