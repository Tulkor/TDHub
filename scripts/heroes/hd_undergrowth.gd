extends RefCounted
## Statische Mischpflanzungen in 24-m-Zellen; wenige Hofbäume separat mit Schatten. Keine Physik.
const Batch = preload("res://scripts/map/static_mesh_batch.gd")
const MODELS := ["hp_grass001","hp_clovers","plant_1","fern_1","bush_common","mushroom_tan_group"]

static func build(game, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name="UndergrowthPatches"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed=781963
	var low := Display.quality==Display.LOW
	var target := 65 if low else 140
	var scatter := {}
	for id in MODELS:scatter[id]=[]
	var centers: Array[Vector3] = []
	var positions: Array[Vector3] = []
	var brushes: Array = []
	var bounds: Array=game.cfg.arena.bounds
	var settlements := HdArenaMountains.settlements(game.arena_layout)
	var cathedral: Node = game.get_node_or_null("SchwarzeKathedrale")
	var buildings: Array=cathedral.get_meta("cathedral_sites_positions",[]) if cathedral else []
	var islands: Array=game.get_meta("settlement_islands",[])
	var used_islands: Array[Vector3]=[]
	for attempt in 2400:
		if centers.size()>=target:break
		var center := Vector3(rng.randf_range(float(bounds[0])+7,float(bounds[2])-7),0,rng.randf_range(float(bounds[1])+7,float(bounds[3])-7))
		var island: Dictionary=islands[attempt] if attempt<islands.size() else {}
		if not island.is_empty():center=island.pos
		if centers.any(func(at):return at.distance_to(center)<8):continue
		if not _available(game,center,settlements,buildings):continue
		var radius := rng.randf_range(2.4,5.2)
		if not island.is_empty():radius=float(island.radius)
		var count := rng.randi_range(7,12) if low else rng.randi_range(16,24)
		var planted := 0
		for index in count:
			var angle := rng.randf()*TAU
			var reach := sqrt(rng.randf())*radius
			var at := center+Vector3(cos(angle)*reach,0,sin(angle)*reach*.7)
			if not _available(game,at,settlements,buildings):continue
			at.y=HdArenaMountains.ground_height(game.arena_layout,at)
			if at.y>10:continue
			var slope := absf(HdArenaMountains.ground_height(game.arena_layout,at+Vector3.RIGHT)-at.y)+absf(HdArenaMountains.ground_height(game.arena_layout,at+Vector3.FORWARD)-at.y)
			if slope>1.2:continue
			var roll := rng.randf()
			var kind := 0 if roll<.48 else (1 if roll<.68 else (2 if roll<.81 else (3 if roll<.92 else (4 if roll<.97 else 5))))
			if kind==4 and at.distance_to(game.arena_layout.nearest(at))<6:continue
			var tall := rng.randf_range(.32,.72)
			if kind==3:tall=rng.randf_range(.6,1.0)
			elif kind==4:tall=rng.randf_range(.85,1.4)
			elif kind==5:tall=rng.randf_range(.15,.3)
			scatter[MODELS[kind]].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*tall),at-Vector3.UP*.025))
			positions.append(at)
			brushes.append({"pos":at,"radius":1.6 if kind==4 else (1.25 if kind in [0,1,3] else 1.05),"grass":.9 if kind in [0,1] else (.55 if kind in [2,3] else .2)})
			planted+=1
		if planted>0:
			centers.append(center)
			if not island.is_empty():used_islands.append(center)
	var city_plants := _city_green(game,scatter,positions,brushes,low)
	var triangles := _batches(root,scatter,low,false)
	var trees := Node3D.new()
	trees.name="CourtyardTrees"
	parent.add_child(trees)
	var tree_scatter := {"common_tree_3":[]}
	var tree_positions: Array[Vector3]=[]
	for island in islands:
		if tree_positions.size()>=(6 if low else 14):break
		var at: Vector3=island.pos
		if not island.tree or not _available(game,at,settlements,buildings):continue
		if tree_positions.any(func(other):return other.distance_to(at)<12):continue
		at.y=HdArenaMountains.ground_height(game.arena_layout,at)
		if at.y>8:continue
		tree_scatter.common_tree_3.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(4.0,5.3)),at))
		tree_positions.append(at)
		brushes.append({"pos":at,"radius":2.4,"grass":.35})
	var tree_triangles := _batches(trees,tree_scatter,low,true)
	trees.set_meta("tree_positions",tree_positions)
	trees.set_meta("triangle_budget",tree_triangles)
	root.set_meta("courtyard_islands",used_islands)
	root.set_meta("patch_centers",centers)
	root.set_meta("plant_positions",positions)
	root.set_meta("ground_brushes",brushes)
	root.set_meta("plant_count",positions.size())
	root.set_meta("city_plants",city_plants)
	root.set_meta("triangle_budget",triangles)
	root.set_meta("batch_count",root.get_child_count())
	return root

static func _batches(root: Node3D, scatter: Dictionary, low: bool, tree: bool) -> int:
	var triangles := 0
	for id in scatter:
		var source: Node3D=load("res://assets/models/nature/"+id+".glb").instantiate()
		var bounds_model := ModelLoader.aabb(source,Transform3D.IDENTITY)
		var fit := 1.0/maxf(.01,maxf(bounds_model.size.y,maxf(bounds_model.size.x,bounds_model.size.z)*.35))
		for part: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			var local := part.transform
			var up := part.get_parent()
			while up!=null and up!=source:
				local=(up as Node3D).transform*local
				up=up.get_parent()
			var transforms: Array = []
			for at: Transform3D in scatter[id]:
				transforms.append(Transform3D(at.basis*fit,at.origin+Vector3.UP*(.065 if bounds_model.size.y<.02 else 0.0))*Transform3D(Basis.IDENTITY,Vector3(0,-bounds_model.position.y,0))*local)
			var mesh: Mesh = HdArenaMountains._tinted(part.mesh,true)
			for surface in mesh.get_surface_count():
				var indices: int = mesh.surface_get_array_index_len(surface)
				triangles+=(indices if indices>0 else mesh.surface_get_array_len(surface))/3*transforms.size()
			Batch.add(root,mesh,transforms,24.0,GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tree else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		source.free()
	for chunk: GeometryInstance3D in root.get_children():
		chunk.visibility_range_end=55.0 if low else 82.0
		chunk.visibility_range_end_margin=8.0
	return triangles


static func _available(game, at: Vector3, settlements: Array, buildings: Array) -> bool:
	if at.distance_to(game.fortress_pos)<17:return false
	if preload("res://scripts/heroes/hd_settlement_streets.gd").distance(game,at)<1.65:return false
	if preload("res://scripts/heroes/hd_city_streets.gd").covered(game,at,1.0):return false
	if Vector2(at.x+33,at.z+33).length()<20 or Vector2(at.x-33,at.z-33).length()<10:return false
	if at.distance_to(game.arena_layout.nearest(at))<4.4:return false
	if settlements.any(func(site):return Vector2(at.x-site.pos.x,at.z-site.pos.z).length()<6.5):return false
	if buildings.any(func(point):return Vector2(at.x-point.x,at.z-point.z).length()<3.6):return false
	for site in HdExplorationLayout.sites():
		if at.distance_to(site.pos)<5.5:return false
	for zone in game.cfg.zones.list:
		var center: Vector3=game.zones.center(str(zone.id))
		if at.distance_to(center)<float(zone.get("radius",13))+.5:return false
	return true


## Grün in der Stadt (Lukas 2026-11-19: „bissl mehr Gras undso in den Städten“): Gras und Unkraut an Hauswänden
## und Bordsteinen, Büsche und Farn in Hinterhöfen, grüne Rasenflecken auf freien Flächen. Fester Seed,
## nie auf Pflaster, Lanes oder vor Türen.
static func _city_green(game, scatter: Dictionary, positions: Array[Vector3], brushes: Array, low: bool) -> int:
	var cathedral: Node=game.get_node_or_null("SchwarzeKathedrale")
	if cathedral==null:return 0
	var Streets := preload("res://scripts/heroes/hd_city_streets.gd")
	var layout: HdArena=game.arena_layout
	var houses: Array=cathedral.get_meta("street_sites",[]).filter(func(s):return s.get("half_size",Vector2.ZERO)!=Vector2.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed=440917
	var planted: Array=[0]
	var free := func(at: Vector3) -> bool:
		if layout.boundary_kind(at)!="city":return false
		if at.distance_to(layout.nearest(at))<float(game.cfg.arena.road_width)*.5+.7:return false
		if layout.divider_distance(at)<HdArena.DIVIDER_HALF_WIDTH+.6 or HdExplorationLayout.clearance(at)<1.5:return false
		if at.distance_to(game.fortress_pos)<17:return false
		if Streets.covered(game,at,.3) or Streets._in_houses(houses,at,.15):return false
		if preload("res://scripts/heroes/hd_settlement_streets.gd").distance(game,at)<1.65:return false
		for site in houses:
			if Vector2(at.x-site.door.x,at.z-site.door.z).length()<2.2:return false
		return true
	var plant := func(at: Vector3, kind: int, size: float, brush: float) -> void:
		at.y=HdArenaMountains.ground_height(layout,at)
		scatter[MODELS[kind]].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),at-Vector3.UP*.025))
		positions.append(at)
		if brush>0.0:brushes.append({"pos":at,"radius":brush,"grass":.9 if kind in [0,1] else .5})
		planted[0]+=1
	var every := 2 if low else 1
	# Hauswände: Grasbüschel und Unkraut in der Traufkante, hinten auch Busch oder Farn.
	for index in range(0,houses.size(),every):
		var site: Dictionary=houses[index]
		if not site.get("town",false):continue
		var hs: Vector2=site.half_size
		var yaw: float=site.get("yaw",0.0)
		for k in 9:
			var side := rng.randi_range(0,3)
			var t := rng.randf_range(-1.0,1.0)
			var local := Vector3(t*hs.x,0,-hs.y-.45) if side==0 else (Vector3(t*hs.x,0,hs.y+.45) if side==1 else Vector3((hs.x+.45)*(1.0 if side==2 else -1.0),0,t*hs.y))
			var at: Vector3=site.center+local.rotated(Vector3.UP,yaw)
			at.y=0
			if not free.call(at):continue
			var back := side==0
			# Büsche sind teuer (900 Dreiecke): nur selten im Hinterhof, sonst Farn, Kraut und Gras.
			var kind := (4 if rng.randf()<.12 else 3) if back and rng.randf()<.5 else (0 if rng.randf()<.7 else 2)
			plant.call(at,kind,rng.randf_range(.75,1.2) if kind==4 else rng.randf_range(.35,.65),1.3 if back else .9)
	# Bordsteine: vereinzeltes Unkraut außen an der Kante.
	var paving: Dictionary=game.get_meta("city_paving",{})
	var step := 0
	for piece in paving.get("pieces",[]):
		if piece.kind=="plaza":continue
		for q in piece.points:
			step+=1
			if step%(3*every)!=0:continue
			var side := 1.0 if rng.randf()<.5 else -1.0
			var at: Vector3=q.c+q.n*side*(float(piece.half)+.35)
			at.y=0
			if free.call(at):plant.call(at,0 if rng.randf()<.75 else 1,rng.randf_range(.28,.48),.7)
	# Freie Stadtflächen: Rasenflecken mit Klee und Gras, gelegentlich ein Busch.
	var bounds: Array=game.cfg.arena.bounds
	var patches := 0
	for attempt in 2600:
		if patches>=(70 if low else 170):break
		var center := Vector3(rng.randf_range(float(bounds[0]),float(bounds[2])),0,rng.randf_range(float(bounds[1]),float(bounds[3])))
		if not free.call(center):continue
		patches+=1
		brushes.append({"pos":center,"radius":rng.randf_range(2.2,3.6),"grass":.95})
		for k in (3 if low else 6):
			var at := center+Vector3(rng.randf_range(-2.4,2.4),0,rng.randf_range(-2.4,2.4))
			if free.call(at):
				var roll := rng.randf()
				plant.call(at,0 if roll<.55 else (1 if roll<.8 else (2 if roll<.92 else 3)),rng.randf_range(.3,.6) if roll<.8 else rng.randf_range(.6,1.1),0.0)
	return planted[0]

