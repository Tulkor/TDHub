class_name HdArena
extends RefCounted
## Ein Korridornetz aus den Lane-Daten. Dieselbe Kontur erzeugt Wände und begrenzt Bewegung.

var game: HdGame
var paths: Array = []
var width := 10.0
var segments: Array = []
var _segment_bins := {}
var dividers: Array = []
var access_pockets: Array = []
var geometry_signature := 0
var _secret_cover: Array = []
var _city_buildings := {}
var _city_ready := false
const DIVIDER_HALF_WIDTH := 1.6
static var _meshes := {}


func _init(owner_game: HdGame) -> void:
	game = owner_game
	width = float(game.cfg.arena.get("wall_clearance", 10.0))
	for d in game.cfg.arena.roads:
		var road := HdRoad.new(d, {})
		paths.append(road)
		for i in road.points.size() - 1:
			var a: Vector3 = road.points[i]
			var delta: Vector3 = road.points[i + 1] - a
			segments.append([a, delta, 1.0 / maxf(delta.length_squared(), 0.001)])
	_build_separation()
	geometry_signature=hash([game.cfg.arena,game.cfg.zones,width,HdExplorationLayout.paths(),HdExplorationLayout.rooms(),HdExplorationLayout.sites()])


func _build_separation() -> void:
	var pairs := {}
	var first: Dictionary={}
	for gate in game.cfg.arena.gates:
		if first.is_empty() or float(gate.at)<float(first.at):first=gate
	for i in paths.size():
		var road: HdRoad=paths[i]
		var definition: Dictionary=game.cfg.arena.roads[i]
		var pair := str(definition.get("pair",road.id))
		if not pairs.has(pair):pairs[pair]=[]
		pairs[pair].append(road)
		if not first.is_empty():
			var offset: float=float(game.cfg.arena.road_width)*.5+float(game.cfg.arena.teleport.offset)
			var s: float=road.length*float(first.at)
			var at := road.point(s)+road.side(s)*float(first.get("side",1))*road.gate_side*offset
			access_pockets.append([at,1.7])
	for group in pairs.values():
		if group.size()!=2:continue
		var a: HdRoad=group[0]
		var b: HdRoad=group[1]
		var found := false
		for ia in range(1,a.raw_points.size()):
			for ib in range(1,b.raw_points.size()):
				if a.raw_points.slice(ia)!=b.raw_points.slice(ib):continue
				var merge: Vector3=a.raw_points[ia]
				var start: Vector3=(a.raw_points[ia-1]+b.raw_points[ib-1])*.5
				var direction: Vector3=(merge-start).normalized()
				# Ein kleiner gemeinsamer Knoten lässt auch große Gegner sauber einschwenken.
				if start.distance_to(merge)>6.0:
					var bounds: Array=game.cfg.arena.bounds
					var outside := start-direction*600.0
					outside.x=clampf(outside.x,float(bounds[0]),float(bounds[2]))
					outside.z=clampf(outside.z,float(bounds[1]),float(bounds[3]))
					dividers.append([outside,merge-direction*5.0])
				found=true
				break
			if found:break


func divider_distance(p: Vector3) -> float:
	var best := INF
	for divider in dividers:
		var q := Geometry3D.get_closest_point_to_segment(p,divider[0],divider[1])
		best=minf(best,p.distance_to(q))
	return best


func nearest(p: Vector3) -> Vector3:
	var key := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not _segment_bins.has(key):
		var center := Vector3((key.x+.5)*16.0,0,(key.y+.5)*16.0)
		var distances: Array = []
		var center_best := INF
		for segment in segments:
			var q: Vector3 = segment[0]+segment[1]*clampf((center-segment[0]).dot(segment[1])*float(segment[2]),0,1)
			var center_distance := q.distance_to(center)
			distances.append(center_distance)
			center_best=minf(center_best,center_distance)
		var candidates: Array = []
		# Distanz zur Strecke ist 1-Lipschitz: weiter als best + 2*Zellradius kann sie nie gewinnen.
		for i in segments.size():
			if float(distances[i])<=center_best+22.628:candidates.append(segments[i])
		_segment_bins[key]=candidates
	var best := Vector3.ZERO
	var distance := INF
	for segment in _segment_bins[key]:
		var a: Vector3 = segment[0]
		var delta: Vector3 = segment[1]
		var q := a + delta * clampf((p - a).dot(delta) * float(segment[2]), 0, 1)
		if q.distance_squared_to(p) < distance:
			distance = q.distance_squared_to(p)
			best = q
	return best


func inside(p: Vector3, radius := 0.0) -> bool:
	if divider_distance(p)<maxf(0.0,DIVIDER_HALF_WIDTH+radius):return false
	if HdExplorationLayout.clearance(p)<=-radius:return true
	if Vector2(p.x, p.z).length() <= float(game.cfg.arena.fortress_zone) - radius:
		return true
	for z in game.cfg.zones.get("list", []):
		var at = z.get("center", z.get("pos", []))
		if at is Array and at.size() == 2 and Vector2(p.x - float(at[0]), p.z - float(at[1])).length() < float(z.get("radius", 13)) - radius:
			return true
	if p.distance_to(nearest(p))<=maxf(width-radius,.1):return true
	for pocket in access_pockets:
		if p.distance_to(pocket[0])<=maxf(.0,float(pocket[1])-radius):return true
	return false


func constrain(p: Vector3, radius: float) -> Vector3:
	if inside(p, radius):
		return p
	var q := nearest(p)
	var result := q+(p-q).limit_length(maxf(width-radius,.1))
	var exploration := HdExplorationLayout.constrain(p,radius)
	if inside(exploration,radius) and exploration.distance_squared_to(p)<result.distance_squared_to(p):result=exploration
	for pocket in access_pockets:
		var center: Vector3=pocket[0]
		var candidate := center+(p-center).limit_length(maxf(.1,float(pocket[1])-radius))
		if inside(candidate,radius) and candidate.distance_squared_to(p)<result.distance_squared_to(p):result=candidate
	for divider in dividers:
		var closest := Geometry3D.get_closest_point_to_segment(result,divider[0],divider[1])
		var delta := result-closest
		var distance := DIVIDER_HALF_WIDTH+radius+.01
		if delta.length()<distance:
			if delta.is_zero_approx():
				var along: Vector3=(divider[1]-divider[0]).normalized()
				delta=Vector3(-along.z,0,along.x)
			result=closest+delta.normalized()*distance
	return result if inside(result,maxf(0.0,radius-.02)) else q


## Nur Helden nutzen Stadtgassen und niedrige Hänge; Gebäude und Lane-Trennungen bleiben gesperrt.
func foothill(p: Vector3, radius: float) -> bool:
	if inside(p,radius):return true
	if divider_distance(p)<DIVIDER_HALF_WIDTH+radius+1.0:return false
	if _city_blocked(p,radius):return false
	if _city_ready and _city_ground(p,radius):return true
	var nearest_road := nearest(p)
	var delta := p-nearest_road
	if delta.length()>width+12.0-radius:return false
	var edge := nearest_road+delta.normalized()*width
	if boundary_kind(edge)!="mountain" or inside(edge+delta.normalized()*5.0,-.4):return false
	if _secret_cover.is_empty():_secret_cover=HdExplorationLayout.concealment(self)
	for piece in _secret_cover:
		if p.distance_squared_to(piece.pos)<pow(2.0+radius,2):return false
	return HdArenaMountains.ground_height(self,p)<=.8


func constrain_hero(p: Vector3, radius: float) -> Vector3:
	if foothill(p,radius):return p
	# An Hauswänden entlanggleiten, statt aus der Stadt auf die nächste Monster-Lane zu springen.
	var pushed := p
	for pass_index in 3:
		for site in _city_near(pushed):
			var local: Vector3=(pushed-site.center).rotated(Vector3.UP,-float(site.yaw))
			var half: Vector2=site.half_size+Vector2.ONE*(radius+.03)
			if absf(local.x)>=half.x or absf(local.z)>=half.y:continue
			if half.x-absf(local.x)<half.y-absf(local.z):local.x=half.x*(1.0 if local.x>=0 else -1.0)
			else:local.z=half.y*(1.0 if local.z>=0 else -1.0)
			pushed=site.center+local.rotated(Vector3.UP,float(site.yaw))
	if pushed.distance_to(p)>.001 and foothill(pushed,radius):return pushed
	var low := constrain(p,radius)
	var high := p
	# An der Hanggrenze abfangen statt den Helden zurück auf die Lane zu versetzen.
	for iteration in 10:
		var middle := (low+high)*.5
		if foothill(middle,radius):low=middle
		else:high=middle
	return low

func register_city(sites: Array) -> void:
	_city_buildings.clear()
	for site in sites:
		if not site.has("half_size"):continue
		var center: Vector3=site.center
		var reach: float=(site.half_size as Vector2).length()+3
		for z in range(floori((center.z-reach)/16),floori((center.z+reach)/16)+1):
			for x in range(floori((center.x-reach)/16),floori((center.x+reach)/16)+1):
				var key := Vector2i(x,z)
				if not _city_buildings.has(key):_city_buildings[key]=[]
				_city_buildings[key].append(site)
	_city_ready=true

func _city_near(p: Vector3) -> Array:
	return _city_buildings.get(Vector2i(floori(p.x/16),floori(p.z/16)),[])

func _city_blocked(p: Vector3, radius: float) -> bool:
	for site in _city_near(p):
		var local: Vector3=(p-site.center).rotated(Vector3.UP,-float(site.yaw))
		var half: Vector2=site.half_size+Vector2.ONE*radius
		if absf(local.x)<half.x and absf(local.z)<half.y:return true
	return false

func _city_ground(p: Vector3, radius: float) -> bool:
	var bounds: Array=game.cfg.arena.bounds
	if p.x<float(bounds[0])+6+radius or p.z<float(bounds[1])+6+radius or p.x>float(bounds[2])-6-radius or p.z>float(bounds[3])-6-radius:return false
	if HdArenaMountains.ground_height(self,p)>6:return false
	for site in HdExplorationLayout.sites():
		if Vector2(p.x-site.pos.x,p.z-site.pos.z).length()<7+radius:return false
	return true


func boundary_kind(point: Vector3) -> String:
	var settings: Dictionary=game.cfg.arena.get("boundaries",{})
	var fortress: Array=game.cfg.arena.fortress
	if Vector2(point.x-float(fortress[0]),point.z-float(fortress[1])).length()<=float(settings.get("city_radius",56.0)):
		return "city"
	for site in settings.get("city_sites",[]):
		if Vector2(point.x-float(site[0]),point.z-float(site[1])).length()<=float(site[2]):return "city"
	if point.distance_to(nearest(point))<float(settings.get("city_road_strip",0)):return "city"
	return "mountain"


func build(parent: Node3D) -> void:
	HdExplorationLayout.build(game,parent)
	if str(game.cfg.arena.get("boundaries",{}).get("style",""))=="mixed":
		_build_mixed(parent)
		return
	var cache_key := geometry_signature
	if _meshes.has(cache_key):
		_attach(parent, _meshes[cache_key])
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bounds: Array = game.cfg.arena.bounds
	var step := 2.0
	var cols := ceili((float(bounds[2]) - float(bounds[0])) / step)
	var rows := ceili((float(bounds[3]) - float(bounds[1])) / step)
	var open := {}
	for z in rows:
		for x in cols:
			var p := Vector3(float(bounds[0]) + (x + 0.5) * step, 0, float(bounds[1]) + (z + 0.5) * step)
			if inside(p, -0.4):
				open[Vector2i(x, z)] = true
	for cell: Vector2i in open:
		var p := Vector3(float(bounds[0]) + cell.x * step, 0, float(bounds[1]) + cell.y * step)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if open.has(cell + d):
				continue
			var at := p + Vector3(0 if d.x < 0 else step, 0, 0) if d.x != 0 else p + Vector3(0, 0, 0 if d.y < 0 else step)
			var along := Vector3(0, 0, step) if d.x != 0 else Vector3(step, 0, 0)
			var n := Vector3(-d.x, 0, -d.y)
			var a := at
			var b := at + along
			for v in [a, b, a + Vector3.UP * 3.2, b, b + Vector3.UP * 3.2, a + Vector3.UP * 3.2]:
				st.set_normal(n)
				st.add_vertex(v)
	var mesh := st.commit()
	if _meshes.size() >= 4:
		_meshes.clear()
	_meshes[cache_key] = mesh
	_attach(parent, mesh)


func _build_mixed(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name="MixedBoundaries"
	parent.add_child(root)
	HdArenaMountains.build(game,root,self)
	var city_edges: Array=[]
	# Massive Mauern exakt auf den logischen Lane-Trennungen; Stadtzugänge bleiben offen.
	for divider in dividers:
		var direction: Vector3=(divider[1]-divider[0]).normalized()
		var side := Vector3(-direction.z,0,direction.x)
		var length: float=(divider[1] as Vector3).distance_to(divider[0])
		var count := ceili(length/2.0)
		for i in count:
			var a: Vector3=divider[0]+direction*(length*float(i)/count)+side*.98
			var b: Vector3=divider[0]+direction*(length*float(i+1)/count)+side*.98
			if HdArenaMountains.ground_height(self,(a+b)*.5)>6:continue
			a.y=HdArenaMountains.ground_height(self,a)
			b.y=HdArenaMountains.ground_height(self,b)
			city_edges.append([a,b,-side])
	var key := geometry_signature
	HdCityWalls.build(game,root,city_edges,key)


func _attach(parent: Node3D, mesh: ArrayMesh) -> void:
	var wall := MeshInstance3D.new()
	wall.name = "ImpassableLaneWalls"
	wall.mesh = mesh
	var stone: Material = HdCathedral.wall_material() if str(game.cfg.arena.get("theme", "")) == "cathedral" else HdDev.mat(Color("956a3b"), 0.5)
	if stone is StandardMaterial3D:
		stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.material_override = stone
	parent.add_child(wall)
