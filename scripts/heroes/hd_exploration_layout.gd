class_name HdExplorationLayout
extends RefCounted
## Geheime Nebenpfade und getrennte Höhlen: dieselbe Kontur für Gelände und Bewegung.
## Die Hauptkarte verrät keine Belohnung; Hinweise/Öffnungen steuert HdExploration.

const SecretEntrances = preload("res://scripts/heroes/hd_secret_entrances.gd")
const PATH_WIDTH := 1.8 ## Halbe begehbare Pfadbreite.
const CAVE_RADIUS := 16.0
static var _paths: Array = []
static var _sites: Array = []
static var _rooms: Array = []
static var _floor_material: Material
static var _theme_materials := {}
static var _query_bins := {}
const QUERY_CELL := 32.0
const QUERY_LIMIT := 32.0 ## Geländeauslauf endet deutlich vor dieser Entfernung.
const CATALOG := "res://data/heroes_secrets.json"
const THEMES := {"basalt":"343d40", "crypt":"46434b", "ice":"364c59", "rot":"3d473b", "forge":"4c3b36", "moon":"3b4055"}


static func _ensure() -> void:
	if not _sites.is_empty():return
	var catalog: Dictionary = Database.load_json(CATALOG)
	var roads: Array = []
	for definition in Database.load_json("res://data/heroes.json").arena.roads:
		roads.append(HdRoad.new(definition,{}))
	for row: Dictionary in catalog.get("sites", []):
		var path: Array = []
		for point in row.path:path.append(Vector3(float(point[0]),0,float(point[1])))
		path = _trail_curve(path,roads,_paths.size())
		_paths.append(path)
		var entrance: Vector3=path[-1]
		var cave := Vector3(float(row.cave[0]),0,float(row.cave[1]))
		var clues: Array=[_along(path,.24),_along(path,.55),_along(path,.8)]
		var site: Dictionary = row.duplicate(true)
		site["order"] = (row.get("order", [0,1,2]) as Array).map(func(value): return int(value))
		site.merge({"pos":entrance,"cave":cave,"return_pos":entrance-(entrance-path[-2]).normalized()*3.0,"radius":2.0,"entrance_kind":"building" if str(row.theme) in ["crypt","forge","moon"] else "cave","clues":clues,"path":path},true)
		_sites.append(site)
		_rooms.append({"id":str(row.id),"center":cave,"radius":CAVE_RADIUS,"theme":str(row.theme),"variant":_rooms.size()%6})
		for i in path.size()-1:
			_add_query(path[i],path[i+1],PATH_WIDTH)
		_add_query(entrance,entrance,2.0)
		_add_query(cave,cave,CAVE_RADIUS)


static func _add_query(a: Vector3, b: Vector3, radius: float) -> void:
	var delta := b-a
	var entry := [a,delta,1.0/maxf(delta.length_squared(),.001),radius]
	var padding := QUERY_LIMIT+radius
	var x0 := floori((minf(a.x,b.x)-padding)/QUERY_CELL)
	var x1 := floori((maxf(a.x,b.x)+padding)/QUERY_CELL)
	var z0 := floori((minf(a.z,b.z)-padding)/QUERY_CELL)
	var z1 := floori((maxf(a.z,b.z)+padding)/QUERY_CELL)
	for z in range(z0,z1+1):
		for x in range(x0,x1+1):
			var key := Vector2i(x,z)
			if not _query_bins.has(key):_query_bins[key]=[]
			_query_bins[key].append(entry)


static func paths() -> Array:
	_ensure()
	return _paths


static func sites() -> Array:
	_ensure()
	return _sites


static func rooms() -> Array:
	_ensure()
	return _rooms


## Höhle einschließlich kleinem Außenpuffer erkennen, damit Wandkontakt nicht zur Hauptkarte springt.
static func cave_at(point: Vector3, radius := 0.0) -> Dictionary:
	for room in rooms():
		if point.distance_to(room.center)<=float(room.radius)-radius:return room
	return {}


static func clearance(point: Vector3) -> float:
	_ensure()
	var distance := QUERY_LIMIT
	var key := Vector2i(floori(point.x/QUERY_CELL),floori(point.z/QUERY_CELL))
	for entry in _query_bins.get(key,[]):
		var a: Vector3=entry[0]
		var delta: Vector3=entry[1]
		var nearest := a+delta*clampf((point-a).dot(delta)*float(entry[2]),0.0,1.0)
		distance=minf(distance,point.distance_to(nearest)-float(entry[3]))
	return distance


static func constrain(point: Vector3, radius: float) -> Vector3:
	var best := point
	var distance := INF
	for path in paths():
		for i in path.size()-1:
			var nearest := Geometry3D.get_closest_point_to_segment(point,path[i],path[i+1])
			var candidate := nearest+(point-nearest).limit_length(maxf(.1,PATH_WIDTH-radius))
			if candidate.distance_squared_to(point)<distance:
				distance=candidate.distance_squared_to(point)
				best=candidate
	for area in sites()+rooms():
		var center: Vector3=area.get("center",area.get("pos",Vector3.ZERO))
		var candidate := center+(point-center).limit_length(maxf(.1,float(area.radius)-radius))
		if candidate.distance_squared_to(point)<distance:
			distance=candidate.distance_squared_to(point)
			best=candidate
	return best


## Statische Geometrie mit sechs Raumthemen; keine Prozesse, Physikkörper oder Dauerlichter.
static func build(_game, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name="ExplorationCaverns"
	parent.add_child(root)
	var batches := {}
	var cover := concealment(_game.arena_layout)
	var scatter := {}
	for piece in cover:
		var at: Vector3 = piece.pos
		if piece.kind == "ruin":
			_append(batches,"rock",_box(Vector3(1.4,piece.height,3.0)),at+Vector3(0,piece.height*.5,0),Basis(Vector3.UP,piece.yaw))
			_append(batches,"rock",_box(Vector3(1.8,.28,3.4)),at+Vector3(0,piece.height,0),Basis(Vector3.UP,piece.yaw))
		else:
			var id: String = piece.kind
			if not scatter.has(id):scatter[id]=[]
			scatter[id].append(Transform3D(Basis(Vector3.UP,piece.yaw).scaled(Vector3.ONE*piece.height),at))
	HdArenaMountains._scatter(root,scatter)
	root.set_meta("secret_cover",cover)
	var visible: Array = []
	for path in paths():
		var trail: Array = []
		for point: Vector3 in path:
			if not trail.is_empty() or point.distance_to(_game.arena_layout.nearest(point))>2.7:
				trail.append(point)
		visible.append(trail)
	var wear := preload("res://scripts/map/ground_wear.gd").add_paths(root,visible,1.65,"heroes",Callable(),true)
	if wear:
		wear.material_override.set_shader_parameter("opacity",.38)
		wear.material_override.set_shader_parameter("irregularity",1.0)
	var basalt: Material=HdArenaMountains._material(22.0)
	for site in sites():
		SecretEntrances.build(root,site)
	for room in rooms():
		var center: Vector3=room.center
		# Der sichtbare Boden reicht unter die Wandfüße; begehbar bleibt der innere Kreis.
		_append(batches,"floor_"+str(room.theme),_cylinder(CAVE_RADIUS+3.5,CAVE_RADIUS+3.5,.18,48),center+Vector3(0,-.08,0))
		for i in 28:
			var angle := TAU*float(i)/28.0
			var height := 5.5+sin(float(i)*2.7+float(room.variant))*1.2
			var at := center+Vector3(cos(angle)*18.8,height*.5-.08,sin(angle)*18.8)
			_append(batches,"rock",_cylinder(1.7,2.4,height,7),at,Basis(Vector3.UP,angle))
			if i%4==0:
				var spire := center+Vector3(cos(angle)*16.9,1.3,sin(angle)*16.9)
				_append(batches,"rock",_cylinder(.08,.65,2.7,6),spire)
		_theme_details(batches,room)
	if _floor_material==null:
		_floor_material=HdCathedral._stone("exploration_floor",Color("343d40"),false)
	for key in batches:
		var instance := MeshInstance3D.new()
		instance.name="Cavern"+str(key).capitalize()
		instance.mesh=batches[key].commit()
		if key=="rock":instance.material_override=basalt
		elif key=="soil" or key=="trail":instance.material_override=HdTerrain.material("soil")
		elif key=="metal":instance.material_override=HdDev.metall(Color("a18d62"))
		elif str(key).begins_with("floor_"):instance.material_override=_theme_material(str(key).trim_prefix("floor_"))
		else:instance.material_override=_floor_material
		root.add_child(instance)
	root.set_meta("cave_count",rooms().size())
	root.set_meta("branch_paths",paths().size())
	return root


## Versetzte Waldsäume und Mauerreste verbergen die Kurven, ohne Laufkonturen zu verengen.
## Keine Zufallsabhängigkeit von aktiven Belohnungen: Auch inaktive Abzweige sehen gleich aus.
static func concealment(layout: HdArena) -> Array:
	var result: Array = []
	for site in sites():
		var path: Array = site.path
		for index in 7:
			var t := .76+float(index)*.035
			var center := _along(path,t)
			var along := (_along(path,minf(1,t+.015))-_along(path,maxf(0,t-.015))).normalized()
			var side := Vector3(-along.z,0,along.x)
			for sign_side in [-1.0,1.0]:
				var bush := index%3==0
				var offset := (2.7 if bush else 3.8)+sin(float(index)*2.3)*.3
				var at: Vector3 = center+side*float(sign_side)*offset
				if at.distance_to(layout.nearest(at))<(3.7 if bush else 4.6):continue
				if clearance(at)<(.3 if bush else 1.0) or layout.divider_distance(at)<4.0:continue
				var ruin: bool = index==4 and sign_side<0 and int(site.order[0])==0
				var kind := "bush_common" if bush else "pine_"+str([1,2,3,5][index%4])
				result.append({"pos":at,"kind":"ruin" if ruin else kind,"height":3.0 if ruin else (1.35 if bush else 6.5+float(index%3)),"yaw":atan2(along.x,along.z)+float(index)*.31})
		_entrance_cover(layout,site,result)
	return result


## Eingang selbst verstecken (Lukas 2026-11-19): Höhlen liegen in einer engen Felsklamm wie ein kleiner
## Bergpass, Krypten hinter Mauerresten und Gestrüpp; dichte Tannen rahmen beides. Alles bleibt mindestens
## 3 m neben der Laufkontur, damit Pfad und Schwelle so breit bleiben wie bisher.
static func _entrance_cover(layout: HdArena, site: Dictionary, result: Array) -> void:
	var path: Array=site.path
	var entrance: Vector3=site.pos
	var inward: Vector3=(entrance-path[-2]).normalized()
	var side := Vector3(-inward.z,0,inward.x)
	var cave := str(site.entrance_kind)!="building"
	var seed_value := int(site.order[0])*7+path.size()
	var spots: Array=[]
	# Klamm/Mauerreste entlang der letzten Pfadmeter.
	for index in 6:
		var t := .86+float(index)*.025
		var center := _along(path,t)
		var along := (_along(path,minf(1,t+.01))-_along(path,maxf(0,t-.01))).normalized()
		var normal := Vector3(-along.z,0,along.x)
		for sign_side in [-1.0,1.0]:
			var offset := 4.6+.5*sin(float(index*3+seed_value))
			var kind := ("rock_tall_a" if (index+int(sign_side>0))%2==0 else "rock_medium_"+str(1+index%3)) if cave else ("ruin" if index%2==0 else "bush_common")
			var height := (2.4+float(index%3)*.5 if kind=="rock_tall_a" else 2.6) if cave else (2.2+float(index%2)*.8 if kind=="ruin" else 1.6)
			spots.append({"pos":center+normal*sign_side*offset,"kind":kind,"height":height,"yaw":atan2(along.x,along.z)+float(index)*.7})
	# Tannen und Gebüsch seitlich und hinter dem Eingang, Büsche schräg davor.
	for ring in [[-3.5,4.0,"bush_common",1.5],[-1.0,7.5,"pine_2",7.5],[3.0,8.5,"pine_1",8.5],[7.0,8.0,"pine_5",7.0],[11.0,6.5,"pine_3",8.0],[15.0,0.0,"pine_2",9.0],[15.0,5.0,"pine_1",8.0]]:
		for sign_side in [-1.0,1.0]:
			if float(ring[1])==0.0 and sign_side>0:continue
			var at: Vector3=entrance+inward*float(ring[0])+side*sign_side*float(ring[1])
			spots.append({"pos":at,"kind":str(ring[2]),"height":float(ring[3])*(.9+.1*sin(at.x)),"yaw":at.x*.37+at.z*.11})
	for spot in spots:
		var at: Vector3=spot.pos
		at.y=0
		spot.pos=at
		if clearance(at)<3.0 or layout.divider_distance(at)<4.0:continue
		if at.distance_to(layout.nearest(at))<layout.width+3.0:continue
		if not cave and spot.kind=="ruin":spot.yaw=atan2(inward.x,inward.z)
		result.append(spot)


## Leicht mäandernde Spur, deren Start exakt auf der gerundeten Straße liegt.
static func _trail_curve(raw: Array, roads: Array, seed_index: int) -> Array:
	var anchor: Vector3 = raw[0]
	var best := INF
	for road: HdRoad in roads:
		var at := road.point(road.project(raw[0],0,road.length))
		if at.distance_squared_to(raw[0])<best:
			best=at.distance_squared_to(raw[0])
			anchor=at
	raw[0]=anchor
	var rounded := HdRoad.rounded(raw,4.5)
	var result: Array = [anchor]
	var walked := 0.0
	for i in rounded.size()-1:
		var a: Vector3 = rounded[i]
		var b: Vector3 = rounded[i+1]
		var length := a.distance_to(b)
		var side := Vector3(-(b-a).z,0,(b-a).x).normalized()
		var steps := maxi(1,ceili(length/3.0))
		for k in range(1,steps+1):
			var t := float(k)/steps
			var distance := walked+t*length
			var fade := clampf(distance/5.0,0,1)*clampf(b.distance_to(raw[-1])/5.0,0,1)
			var offset := sin(distance*.38+float(seed_index)*1.7)*.4*fade
			result.append(a.lerp(b,t)+side*offset)
		walked+=length
	result[-1]=raw[-1]
	return result


static func _along(path: Array, fraction: float) -> Vector3:
	var length := 0.0
	for i in path.size()-1:length+=path[i].distance_to(path[i+1])
	var remaining := length*fraction
	for i in path.size()-1:
		var span: float = path[i].distance_to(path[i+1])
		if remaining<=span:return (path[i] as Vector3).lerp(path[i+1],remaining/maxf(span,.001))
		remaining-=span
	return path[-1]


## Kleine Öffnung im Bordstein, keine breite Schneise entlang der ganzen Nebenroute.
static func mouth_distance(point: Vector3) -> float:
	var distance := INF
	for path in paths():
		for i in mini(5,path.size()-1):
			var at := Geometry3D.get_closest_point_to_segment(point,path[i],path[i+1])
			distance=minf(distance,point.distance_to(at))
	return distance


static func _theme_material(theme: String) -> Material:
	if not _theme_materials.has(theme):
		_theme_materials[theme]=HdCathedral._stone("exploration_"+theme,Color(THEMES.get(theme,"343d40")),false)
	return _theme_materials[theme]


## Randarchitektur bleibt außerhalb der begehbaren Raumkontur. Bodenzeichen sind flach.
static func _theme_details(batches: Dictionary, room: Dictionary) -> void:
	var center: Vector3=room.center
	var theme := str(room.theme)
	var floor_key := "floor_"+theme
	if theme=="crypt":
		for side in [-1,1]:
			for end in [-1,1]:
				var at := center+Vector3(side*14,2.7,end*11)
				_append(batches,floor_key,_box(Vector3(1.1,5.4,1.1)),at)
				_append(batches,"metal",_box(Vector3(1.4,.16,1.4)),at+Vector3(0,2.2,0))
		# Steinernes Grab im hinteren Wandkranz.
		_append(batches,floor_key,_box(Vector3(5,1.1,1.4)),center+Vector3(0,.55,-17.4))
	elif theme=="forge":
		for side in [-1,1]:
			_append(batches,"metal",_cylinder(1.0,1.2,5.0,10),center+Vector3(side*17.6,2.5,0))
			for level in [1.0,3.8]:
				_append(batches,"metal",_cylinder(1.25,1.25,.25,10),center+Vector3(side*17.6,level,0))
		_append(batches,floor_key,_box(Vector3(6,4.6,1.4)),center+Vector3(0,2.3,-17.7))
		for x in [-1.8,-.6,.6,1.8]:
			_append(batches,"metal",_box(Vector3(.18,3.3,.18)),center+Vector3(x,2,-16.9))
	elif theme=="ice":
		for i in 6:
			var angle := TAU*float(i)/6.0
			var at := center+Vector3(cos(angle)*17.6,2.0,sin(angle)*17.6)
			_append(batches,floor_key,_cylinder(.02,.8,4+float(i%3),5),at,Basis(Vector3.UP,angle))
	elif theme=="rot":
		for i in 8:
			var angle := TAU*float(i)/8.0
			var at := center+Vector3(cos(angle)*17.5,1.8,sin(angle)*17.5)
			_append(batches,floor_key,_cylinder(.12,.7,3.6,6),at,Basis(Vector3.FORWARD,.18*sin(angle)))
			_append(batches,floor_key,_cylinder(1.0,1.4,.45,7),at+Vector3(0,.9,0))
	elif theme=="moon":
		for i in 24:
			var angle := TAU*float(i)/24.0
			var at := center+Vector3(cos(angle)*11,.035,sin(angle)*11)
			_append(batches,"metal",_box(Vector3(.08,.025,2.7)),at,Basis(Vector3.UP,-angle))
		for side in [-1,1]:
			_append(batches,"metal",_cylinder(.2,.6,5,8),center+Vector3(side*17.4,2.5,0))
	else:
		for i in 5:
			var at := center+Vector3(-7+float(i)*3.5,2.8,-17.5)
			_append(batches,"rock",_cylinder(.25,.7,4.8+float(i%2),5),at)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size=size
	return mesh


static func _cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius=top
	mesh.bottom_radius=bottom
	mesh.height=height
	mesh.radial_segments=sides
	return mesh


static func _append(batches: Dictionary, key: String, mesh: Mesh, at: Vector3, basis := Basis.IDENTITY) -> void:
	if not batches.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key]=surface
	batches[key].append_from(mesh,0,Transform3D(basis,at))
