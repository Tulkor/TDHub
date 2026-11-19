extends RefCounted
## Gepflasterte Gassen, Quergassen und Plätze der Altstadt als eigene Flächen mit harter Kante und Steinbord,
## genau wie die Monsterwege (Lukas 2026-11-19: „klar abgetrennt und nicht blended“). Nur Optik, keine
## Kollision. Alles hängt am festen Grundriss aus HdCityLayout, damit alle Mitspieler dasselbe sehen.

## Halbe Gassenbreite (m): reicht bis an die Hausfluchten, vorspringende Häuser stehen auf dem Pflaster.
const STREET_HALF := 2.2
const ALLEY_HALF := 1.5
const STEP := 2.0
## Pflaster liegt als dünne Schicht über dem Gelände, die Kante fällt sichtbar ab.
const LIFT := .06
const SKIRT := .14
const CURB := Vector3(.24,.14,1.0)
const CELL := 8.0
const CityLayout := preload("res://scripts/heroes/hd_city_layout.gd")


static func build(game, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name="CityStreets"
	parent.add_child(root)
	var cathedral: Node=game.get_node_or_null("SchwarzeKathedrale")
	if cathedral==null:return root
	var layout: HdArena=game.arena_layout
	var lane_clear := float(game.cfg.arena.road_width)*.5+.45
	var houses: Array=cathedral.get_meta("street_sites",[]).filter(func(s):return s.get("half_size",Vector2.ZERO)!=Vector2.ZERO)
	var why := {}
	var reason := func(p: Vector3) -> String:
		var r := ""
		if layout.boundary_kind(p)!="city":r="land"
		elif Vector2(p.x,p.z).length()<float(game.cfg.arena.fortress_zone)+6.0:r="feste"
		elif p.distance_to(layout.nearest(p))<lane_clear:r="lane"
		elif layout.divider_distance(p)<HdArena.DIVIDER_HALF_WIDTH+1.0:r="wand"
		elif HdExplorationLayout.clearance(p)<=1.0:r="secret"
		return r
	var ok := func(p: Vector3) -> bool:
		var r: String=reason.call(p)
		if r!="":why[r]=int(why.get(r,0))+1
		return r==""
	var pieces: Array=[]
	var town: Array=houses.filter(func(s):return s.get("town",false))
	var plazas: Array=cathedral.get_meta("settlement_plazas",[])
	# Gassen: je Gassenpaar entlang der gekrümmten Mitte, solange Häuser (oder ein Platz) daran liegen.
	var rows := {}
	for site in town:
		var pair := int(site.row)/2
		if not rows.has(pair):rows[pair]=[]
		rows[pair].append((site.center as Vector3).x)
	for plaza in plazas:
		var pair := roundi(((plaza.pos as Vector3).z+162.0)/24.0)
		var half: Vector2=plaza.get("half",Vector2(11,8.5))
		if not rows.has(pair):rows[pair]=[]
		for dx in [-half.x,0.0,half.x]:rows[pair].append((plaza.pos as Vector3).x+dx)
	for pair in rows:
		var xs: Array=rows[pair]
		xs.sort()
		var start: float=xs[0]
		for i in xs.size():
			var last: bool=i==xs.size()-1
			if last or float(xs[i+1])-float(xs[i])>26.0:
				# Gassenenden laufen weiter bis zur nächsten Monsterstraße, wenn sie frei dorthin kommen.
				var from := _reach(int(pair),start-4.0,-1.0,ok,reason,houses)
				var to := _reach(int(pair),float(xs[i])+4.0,1.0,ok,reason,houses)
				_strip(pieces,_street_points(int(pair),from,to),STREET_HALF,ok,houses,false)
				if not last:start=xs[i+1]
	# Plätze: unregelmäßige Vierecke entlang der Gasse, mit Bord, wo keine Gasse einmündet.
	for plaza in plazas:
		var half: Vector2=plaza.get("half",Vector2(11,8.5))
		var yaw: float=plaza.get("street_yaw",plaza.yaw)
		var corners: Array=[]
		var center: Vector3=plaza.pos
		for k in 4:
			var sx := -1.0 if k==0 or k==3 else 1.0
			var sz := -1.0 if k<2 else 1.0
			var jitter := Vector2(float(CityLayout._hash(int(center.x)*7+k,31)%100)/99.0-.5,float(CityLayout._hash(int(center.z)*5+k,37)%100)/99.0-.5)*2.4
			corners.append(center+Vector3(sx*half.x+jitter.x,0,sz*half.y+jitter.y).rotated(Vector3.UP,yaw))
		pieces.append({"kind":"plaza","corners":corners})
	# Quergassen in den Lücken der Häuserzeilen, nur wo sie zwei vorhandene Gassen verbinden.
	var alleys := 0
	for pair in rows:
		if not rows.has(int(pair)+1):continue
		var shift := CityLayout._hash(int(pair),7)%4
		for column in 35:
			if (column+shift)%4!=2:continue
			var x := -170.0+column*10.0
			var line: Array=[]
			var z0 := _street_z(int(pair),x)
			var z1 := _street_z(int(pair)+1,x)
			for k in 13:
				line.append(Vector3(x,0,lerpf(z0,z1,float(k)/12.0)))
			if not (_on_paving(pieces,line[0]) and _on_paving(pieces,line[-1])):continue
			if line.all(func(p):return ok.call(p) and not _in_houses(houses,p,ALLEY_HALF+.3)):
				_strip(pieces,line,ALLEY_HALF,ok,houses,true)
				alleys+=1
	# Jedes Pflasterstück hängt am Netz: was weder eine Lane noch ein angebundenes Stück berührt, bekommt
	# die kürzeste freie Verbindung; Stücke ohne jede Verbindung entfallen (keine Pflasterinseln).
	var connectors := _connect(pieces,layout,lane_clear,ok,houses)
	var grid := {}
	for i in pieces.size():_register(grid,pieces[i],i)
	var paving := SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curbs: Array[Transform3D]=[]
	for i in pieces.size():
		var piece: Dictionary=pieces[i]
		if piece.kind=="plaza":
			_plaza_mesh(paving,layout,piece.corners)
			for k in 4:_curb_line(curbs,layout,piece.corners[k],piece.corners[(k+1)%4],grid,pieces,i,houses,lane_clear)
		else:
			_strip_mesh(paving,layout,piece)
			for side in [-1.0,1.0]:
				var edge: Array=piece.points.map(func(p):return p.c+p.n*side*float(piece.half))
				for k in edge.size()-1:_curb_line(curbs,layout,edge[k],edge[k+1],grid,pieces,i,houses,lane_clear)
	if not pieces.is_empty():
		paving.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name="StreetPaving"
		mesh.mesh=paving.commit()
		mesh.material_override=material()
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	if not curbs.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=BoxMesh.new()
		mm.instance_count=curbs.size()
		for i in curbs.size():mm.set_instance_transform(i,curbs[i])
		var node := MultiMeshInstance3D.new()
		node.name="StreetCurbs"
		node.multimesh=mm
		node.material_override=curb_material()
		root.add_child(node)
	game.set_meta("city_paving",{"grid":grid,"pieces":pieces})
	if OS.has_environment("GEMTD_PFLASTER_JSON"):
		var dump := {"houses":houses.map(func(h):return [h.center.x,h.center.z,h.half_size.x,h.half_size.y,h.get("yaw",0.0),h.get("town",false)]),
			"pieces":pieces.map(func(p):return p.corners.map(func(c):return [c.x,c.z]) if p.kind=="plaza" else p.points.map(func(q):return [q.c.x,q.c.z,float(p.half)]))}
		var lanes: Array=[]
		for road in layout.paths:lanes.append(road.points.map(func(q):return [q.x,q.z]))
		dump["lanes"]=lanes
		var f := FileAccess.open(OS.get_environment("GEMTD_PFLASTER_JSON"),FileAccess.WRITE)
		f.store_string(JSON.stringify(dump))
	root.set_meta("streets",pieces.filter(func(p):return p.kind=="street").size())
	root.set_meta("alleys",alleys)
	root.set_meta("connectors",connectors)
	root.set_meta("plazas",plazas.size())
	root.set_meta("curbs",curbs.size())
	root.set_meta("blocked",why)
	root.set_meta("pieces",pieces)
	return root


## Stadtpflaster: dasselbe weltkoordinatenbasierte Setzpflaster wie die Monsterwege, etwas wärmer und dunkler,
## damit Gassen und Lanes unterscheidbar bleiben.
static func material() -> Material:
	return HdCathedral._stone("path_town",Color("6b6762"),false)


static var _curb_material: StandardMaterial3D

static func curb_material() -> Material:
	if _curb_material==null:
		_curb_material=StandardMaterial3D.new()
		_curb_material.albedo_color=Color("797d84")
		_curb_material.roughness=.86
		_curb_material.metallic_specular=.28
	return _curb_material


## Gepflasterter Vorplatz mit Bord vor einem Einzelgebäude (Kapelle), rechteckig nach dem Grundriss.
static func forecourt(game, parent: Node3D, at: Vector3, yaw: float, half: Vector2) -> MeshInstance3D:
	var layout: HdArena=game.arena_layout
	var corners: Array=[]
	for k in 4:
		var sx := -1.0 if k==0 or k==3 else 1.0
		var sz := -1.0 if k<2 else 1.0
		corners.append(at+Vector3(sx*half.x,0,sz*half.y).rotated(Vector3.UP,yaw))
	var paving := SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	_plaza_mesh(paving,layout,corners)
	paving.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name="Vorplatz"
	mesh.mesh=paving.commit()
	mesh.material_override=material()
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	var curbs: Array[Transform3D]=[]
	for k in 4:_curb_line(curbs,layout,corners[k],corners[(k+1)%4],{},[],-1,[],0.0)
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=BoxMesh.new()
	mm.instance_count=curbs.size()
	for i in curbs.size():mm.set_instance_transform(i,curbs[i])
	var node := MultiMeshInstance3D.new()
	node.name="VorplatzBord"
	node.multimesh=mm
	node.material_override=curb_material()
	mesh.add_child(node)
	return mesh


## Gassenende nach außen verlängern: nur wenn die Gasse frei bis an den Lane-Bord kommt, sonst bleibt das Ende.
static func _reach(pair: int, x: float, direction: float, ok: Callable, reason: Callable, houses: Array) -> float:
	for k in range(1,16):
		var at := x+direction*float(k)*STEP
		var p := Vector3(at,0,_street_z(pair,at))
		var r: String=reason.call(p)
		if r=="lane":return at-direction*STEP
		if r!="" or _in_houses(houses,p,.5):return x
	return x


static func _on_paving(pieces: Array, p: Vector3) -> bool:
	for piece in pieces:
		if piece.kind=="plaza":
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array(piece.corners.map(func(c):return Vector2(c.x,c.z)))):return true
			continue
		for q in piece.points:
			if Vector2(q.c.x-p.x,q.c.z-p.z).length()<float(piece.half)+.6:return true
	return false


static func _samples(piece: Dictionary) -> Array:
	if piece.kind!="plaza":return piece.points.map(func(q):return q.c)
	var out: Array=[]
	for k in 4:
		for s in 4:out.append((piece.corners[k] as Vector3).lerp(piece.corners[(k+1)%4],float(s)/4.0))
	return out


static func _touch_lane(piece: Dictionary, layout: HdArena, lane_clear: float) -> bool:
	var reach := lane_clear+(float(piece.half) if piece.has("half") else 0.0)+.6
	for p in _samples(piece):
		if (p as Vector3).distance_to(layout.nearest(p))<reach:return true
	return false


static func _connect(pieces: Array, layout: HdArena, lane_clear: float, ok: Callable, houses: Array) -> int:
	var linked: Array=[]
	for piece in pieces:linked.append(_touch_lane(piece,layout,lane_clear))
	var added := 0
	for pass_index in 6:
		var changed := false
		# Über Berührung mit angebundenen Stücken ausbreiten.
		for i in pieces.size():
			if linked[i]:continue
			for j in pieces.size():
				if linked[j] and _samples(pieces[i]).any(func(p):return _on_paving([pieces[j]],p)):
					linked[i]=true
					changed=true
					break
		if linked.all(func(v):return v):break
		# Kürzeste freie Verbindung von einem losen Stück zur Lane oder zu einem angebundenen Stück.
		for i in pieces.size():
			if linked[i]:continue
			var candidates: Array=[]
			var own: Array=_samples(pieces[i])
			for k in range(0,own.size(),2):
				var a: Vector3=own[k]
				candidates.append([a.distance_to(layout.nearest(a)),a,layout.nearest(a)])
				for j in pieces.size():
					if not linked[j]:continue
					for q in _samples(pieces[j]):
						var length := a.distance_to(q)
						if length>=3.0 and length<=36.0:candidates.append([length,a,q])
			candidates.sort_custom(func(x,y):return float(x[0])<float(y[0]))
			var best: Array=[]
			for candidate in candidates.slice(0,40):
				var a: Vector3=candidate[1]
				var b: Vector3=candidate[2]
				var length: float=candidate[0]
				if length>36.0:break
				var line: Array=[]
				var count := maxi(2,ceili(length/STEP))
				for k in count+1:line.append(a.lerp(b,float(k)/count)*Vector3(1,0,1))
				var inner: Array=line.slice(1,line.size()-1)
				if inner.all(func(p):return _on_paving([pieces[i]],p) or (ok.call(p) and not _in_houses(houses,p,ALLEY_HALF+.2))) or _ends_at_lane(line,inner,ok,houses,layout,lane_clear):
					best=[a,b,length,line]
					break
			if best.is_empty():continue
			var before := pieces.size()
			_strip(pieces,best[3],ALLEY_HALF,ok,houses,false)
			for k in range(before,pieces.size()):linked.append(true)
			if pieces.size()>before:
				linked[i]=true
				added+=1
				changed=true
		if not changed:break
	# Was gar keinen Anschluss findet, wird nicht gepflastert.
	for i in range(pieces.size()-1,-1,-1):
		if not linked[i]:pieces.remove_at(i)
	return added


## Verbindung zur Lane: alle Punkte frei bis auf die letzten, die schon auf dem Lane-Bord liegen.
static func _ends_at_lane(line: Array, inner: Array, ok: Callable, houses: Array, layout: HdArena, lane_clear: float) -> bool:
	var reached := false
	for p in inner:
		if (p as Vector3).distance_to(layout.nearest(p))<lane_clear+ALLEY_HALF:
			reached=true
			continue
		if reached or not ok.call(p) or _in_houses(houses,p,ALLEY_HALF+.2):return false
	return reached


static func _street_z(pair: int, x: float) -> float:
	var street_z := -168.0+float(pair)*24.0+6.0
	return street_z+CityLayout._field(Vector2(x,street_z),0)*CityLayout.BEND


static func _street_points(pair: int, from: float, to: float) -> Array:
	var points: Array=[]
	var count := maxi(1,ceili((to-from)/STEP))
	for k in count+1:
		var x := lerpf(from,to,float(k)/count)
		points.append(Vector3(x,0,_street_z(pair,x)))
	return points


## Mittellinie in zusammenhängende, freie Stücke schneiden; jedes Stück wird ein eigener Pflasterstreifen.
static func _strip(pieces: Array, line: Array, half: float, ok: Callable, houses: Array, alley: bool) -> void:
	var run: Array=[]
	for k in line.size():
		var c: Vector3=line[k]
		var a: Vector3=line[maxi(k-1,0)]
		var b: Vector3=line[mini(k+1,line.size()-1)]
		var t := Vector3(b.x-a.x,0,b.z-a.z).normalized()
		var n := Vector3(-t.z,0,t.x)
		var free: bool=ok.call(c) and ok.call(c+n*half) and ok.call(c-n*half)
		if free and alley:free=not _in_houses(houses,c,half)
		if free:
			run.append({"c":c,"n":n,"t":t})
		if (not free or k==line.size()-1) and run.size()>=2:
			pieces.append({"kind":"alley" if alley else "street","points":run,"half":half})
		if not free:run=[]


static func _in_houses(houses: Array, p: Vector3, margin: float) -> bool:
	for site in houses:
		var hs: Vector2=site.half_size
		var local: Vector3=(p-site.center).rotated(Vector3.UP,-float(site.get("yaw",0.0)))
		if absf(local.x)<hs.x+margin and absf(local.z)<hs.y+margin:return true
	return false


static func _ground(layout: HdArena, p: Vector3) -> Vector3:
	return Vector3(p.x,HdArenaMountains.ground_height(layout,p)+LIFT,p.z)


static func _strip_mesh(st: SurfaceTool, layout: HdArena, piece: Dictionary) -> void:
	var points: Array=piece.points
	var half: float=piece.half
	for k in points.size()-1:
		var a: Dictionary=points[k]
		var b: Dictionary=points[k+1]
		var row_a: Array=[_ground(layout,a.c-a.n*half),_ground(layout,a.c),_ground(layout,a.c+a.n*half)]
		var row_b: Array=[_ground(layout,b.c-b.n*half),_ground(layout,b.c),_ground(layout,b.c+b.n*half)]
		for j in 2:_quad(st,row_a[j],row_a[j+1],row_b[j],row_b[j+1])
		# Sichtbare Kante: die Pflasterschicht fällt außen senkrecht ab, statt ins Gelände zu verlaufen.
		_skirt(st,row_a[0],row_b[0])
		_skirt(st,row_b[2],row_a[2])
	# Stirnseiten an offenen Enden.
	var first: Dictionary=points[0]
	var last: Dictionary=points[points.size()-1]
	_skirt(st,_ground(layout,first.c+first.n*half),_ground(layout,first.c-first.n*half))
	_skirt(st,_ground(layout,last.c-last.n*half),_ground(layout,last.c+last.n*half))


static func _plaza_mesh(st: SurfaceTool, layout: HdArena, corners: Array) -> void:
	# Gitter über das Viereck, damit die Fläche dem Gelände folgt.
	var n := 8
	for iz in n:
		for ix in n:
			var quad: Array=[]
			for c in [Vector2(ix,iz),Vector2(ix+1,iz),Vector2(ix,iz+1),Vector2(ix+1,iz+1)]:
				var u: float=c.x/n
				var v: float=c.y/n
				var bottom: Vector3=(corners[0] as Vector3).lerp(corners[1],u)
				var top: Vector3=(corners[3] as Vector3).lerp(corners[2],u)
				quad.append(_ground(layout,bottom.lerp(top,v)))
			_quad(st,quad[0],quad[1],quad[2],quad[3])
	for k in 4:
		var a: Vector3=corners[k]
		var b: Vector3=corners[(k+1)%4]
		for s in 4:
			_skirt(st,_ground(layout,a.lerp(b,float(s)/4.0)),_ground(layout,a.lerp(b,float(s+1)/4.0)))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a-b vorn, c-d hinten; Dreiecke so gewickelt, dass die Oberseite nach oben zeigt.
	var up := (b-a).cross(c-a).y<0.0
	for p in ([a,b,c,b,d,c] if up else [a,c,b,b,c,d]):st.add_vertex(p)


static func _skirt(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var a2 := a-Vector3.UP*SKIRT
	var b2 := b-Vector3.UP*SKIRT
	for p in [a,b,a2,b,b2,a2]:st.add_vertex(p)


static func _register(grid: Dictionary, piece: Dictionary, index: int) -> void:
	var points: Array=piece.points.map(func(p):return p.c) if piece.has("points") else piece.corners
	var lo := Vector2(INF,INF)
	var hi := -lo
	for p in points:
		lo=lo.min(Vector2(p.x,p.z))
		hi=hi.max(Vector2(p.x,p.z))
	for x in range(floori((lo.x-4)/CELL),floori((hi.x+4)/CELL)+1):
		for z in range(floori((lo.y-4)/CELL),floori((hi.y+4)/CELL)+1):
			var key := Vector2i(x,z)
			if not grid.has(key):grid[key]=[]
			grid[key].append(index)


## Liegt der Punkt auf (oder bis margin neben) Stadtpflaster? Für Bepflanzung und Prüfungen.
static func covered(game, p: Vector3, margin := 0.0) -> bool:
	var paving: Dictionary=game.get_meta("city_paving",{})
	return not paving.is_empty() and _covered(paving.grid,paving.pieces,p,-1,margin)


static func _covered(grid: Dictionary, pieces: Array, p: Vector3, skip: int, margin := 0.0) -> bool:
	for index in grid.get(Vector2i(floori(p.x/CELL),floori(p.z/CELL)),[]):
		if index==skip:continue
		var piece: Dictionary=pieces[index]
		if piece.kind=="plaza":
			var polygon := PackedVector2Array(piece.corners.map(func(c):return Vector2(c.x,c.z)))
			if margin>0.0:polygon=Geometry2D.offset_polygon(polygon,margin)[0]
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):return true
			continue
		var points: Array=piece.points
		for k in points.size()-1:
			var a: Vector3=points[k].c
			var b: Vector3=points[k+1].c
			var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x,0,p.z),a,b)
			var t := clampf((q-a).dot(b-a)/maxf(a.distance_squared_to(b),.0001),0,1)
			# Nur innerhalb der Streifenlänge zählt, an offenen Enden darf der Bord stehen.
			if q.distance_to(Vector3(p.x,0,p.z))<float(piece.half)-.05+margin and (margin>0.0 or ((k>0 or t>0.0) and (k<points.size()-2 or t<1.0))):return true
	return false


## Bordsteine entlang einer Kante; weg, wo eine andere Pflasterfläche anschließt, ein Haus steht oder die Lane beginnt.
static func _curb_line(curbs: Array[Transform3D], layout: HdArena, a: Vector3, b: Vector3, grid: Dictionary, pieces: Array, skip: int, houses: Array, lane_clear: float) -> void:
	var length := Vector2(b.x-a.x,b.z-a.z).length()
	var count := maxi(1,ceili(length/1.2))
	var yaw := atan2(b.x-a.x,b.z-a.z)
	for k in count:
		var p := a.lerp(b,(float(k)+.5)/count)
		if not pieces.is_empty() and _covered(grid,pieces,p,skip):continue
		if not houses.is_empty() and _in_houses(houses,p,-.1):continue
		if lane_clear>0.0 and p.distance_to(layout.nearest(p))<lane_clear-.2:continue
		var h := HdArenaMountains.ground_height(layout,p)
		curbs.append(Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3(CURB.x,CURB.y,length/count-.06)),Vector3(p.x,h+CURB.y*.5,p.z)))
