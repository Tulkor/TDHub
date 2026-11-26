extends RefCounted
## Äcker vor der Stadt (Lukas 2026-11-19: „am Rand paar Felder“). Nur Optik, keine Kollision: flache Parzellen
## außerhalb der Stadtviertel, weit weg von Lanes, Secret-Pfaden, Zonen und Häusern. Fester Raster und feste
## Hashes, damit alle Mitspieler und Grafikstufen dieselben Felder sehen.
const FIELD := Vector2(16.0,11.0)
const SPACING := 22.0
const MAX_FIELDS := 10
const CROPS := [Color("8f7a3c"), Color("566b33"), Color("7d6a35"), Color("3e2f22")]


static func build(game, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name="Fields"
	parent.add_child(root)
	var layout: HdArena=game.arena_layout
	var bounds: Array=game.cfg.arena.bounds
	var cathedral: Node=game.get_node_or_null("SchwarzeKathedrale")
	var buildings: Array=cathedral.get_meta("cathedral_sites_positions",[]) if cathedral else []
	var fields: Array=[]
	var builder := HdGothic.new()
	var soil := _soil_material()
	for z in range(int(bounds[1])+18,int(bounds[3])-17,9):
		for x in range(int(bounds[0])+18,int(bounds[2])-17,9):
			if fields.size()>=MAX_FIELDS:break
			var at := Vector3(x+4.5*float((z/9)%2),0,z)
			if Vector2(at.x,at.z).length()<72.0:continue
			if layout.inside(at,-9.0) or layout.divider_distance(at)<12.0:continue
			if HdExplorationLayout.clearance(at)<16.0:continue
			if buildings.any(func(b):return Vector2(b.x-at.x,b.z-at.z).length()<18.0):continue
			if fields.any(func(f):return (f.pos as Vector3).distance_to(at)<SPACING):continue
			if _near_zone(game,at,12.0):continue
			# Parzelle entlang der nächsten Lane ausrichten, wie Flurstreifen an einer Landstraße.
			var lane := layout.nearest(at)
			var to_lane := Vector3(lane.x-at.x,0,lane.z-at.z)
			var yaw := atan2(to_lane.x,to_lane.z)+PI*.5+float(_hash(x,z)%9-4)*.03
			var lo := INF
			var hi := -INF
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2.ZERO]:
				var p := at+Vector3(corner.x*FIELD.x*.5,0,corner.y*FIELD.y*.5).rotated(Vector3.UP,yaw)
				if layout.inside(p,-4.0) or HdExplorationLayout.clearance(p)<6.0:
					lo=-INF
					break
				var h := HdArenaMountains.ground_height(layout,p)
				lo=minf(lo,h)
				hi=maxf(hi,h)
			# Leicht gewellte Flur ist ok (auch Bergbauern-Äcker auf Hochflächen), die Parzelle folgt dem Gelände;
			# steile Hänge und Schneelagen bleiben frei.
			if lo==-INF or hi-lo>1.6 or hi>14.0:continue
			at.y=HdArenaMountains.ground_height(layout,at)
			var crop: int=_hash(x*3,z*5)%CROPS.size()
			fields.append({"pos":at,"yaw":yaw,"crop":crop})
			_field(root,builder,soil,at,yaw,crop,x+z,layout)
	if not fields.is_empty():root.add_child(builder.commit())
	root.set_meta("cleared",_clear_scatter(game,fields))
	root.set_meta("fields",fields)
	return root


static func _field(root: Node3D, b: HdGothic, soil: Material, at: Vector3, yaw: float, crop: int, seed_value: int, layout: HdArena) -> void:
	var basis := Basis(Vector3.UP,yaw)
	var ground := func(local: Vector3) -> Vector3:
		var p: Vector3=at+basis*Vector3(local.x,0,local.z)
		p.y=HdArenaMountains.ground_height(layout,p)+local.y
		return p
	# Ackerboden als Gitter auf dem Gelände (2 m), damit die Parzelle auch über flache Kuppen läuft.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int(FIELD.x/2.0)
	var nz := int(FIELD.y/2.0)
	for iz in nz:
		for ix in nx:
			var quad: Array=[]
			for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				quad.append(ground.call(Vector3(-FIELD.x*.5+float(ix+c.x)*FIELD.x/nx,.04,-FIELD.y*.5+float(iz+c.y)*FIELD.y/nz)))
			for index in [0,1,2,1,3,2]:
				st.set_uv(Vector2((quad[index] as Vector3).x,(quad[index] as Vector3).z)*.25)
				st.add_vertex(quad[index])
	st.generate_normals()
	var plane := MeshInstance3D.new()
	plane.mesh=st.commit()
	plane.material_override=soil
	plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plane)
	var color: Color=CROPS[crop]
	var fallow := crop==3
	var crop_material := _crop_material(color)
	# Saatreihen längs der Parzelle in 8 Stücken auf Geländehöhe; Brache zeigt nur Furchen.
	var rows := int(FIELD.y/0.95)
	var piece := (FIELD.x-1.2)/8.0
	for i in rows:
		var offset := -FIELD.y*.5+.55+float(i)*.95
		var height := .1 if fallow else .42+.06*sin(float(i)*1.7+seed_value)
		for k in 8:
			var a: Vector3=ground.call(Vector3(-FIELD.x*.5+.6+piece*float(k),height*.5+.03,offset))
			var c: Vector3=ground.call(Vector3(-FIELD.x*.5+.6+piece*float(k+1),height*.5+.03,offset))
			# Jedes Reihenstück folgt der Neigung, damit die Reihen nicht wie gestapelte Bretter wirken.
			b.add("box",crop_material,Vector3(a.distance_to(c)+.04,height,.42 if fallow else .5),(a+c)*.5,yaw,Vector3(0,0,atan2(c.y-a.y,piece)))
	# Holzzaun an zwei Seiten.
	var wood := _crop_material(Color("3b2e22"))
	for sign_side in [-1.0,1.0]:
		for k in 9:
			var post: Vector3=ground.call(Vector3(-FIELD.x*.5+float(k)*FIELD.x/8.0,.55,sign_side*(FIELD.y*.5+.4)))
			b.add("box",wood,Vector3(.14,1.1,.14),post,yaw)
			if k<8:
				var next: Vector3=ground.call(Vector3(-FIELD.x*.5+float(k+1)*FIELD.x/8.0,.55,sign_side*(FIELD.y*.5+.4)))
				for rail in [.3,-.1]:
					b.add("box",wood,Vector3(post.distance_to(next),.08,.06),(post+next)*.5+Vector3.UP*rail,yaw,Vector3(0,0,atan2(next.y-post.y,FIELD.x/8.0)))


static var _materials := {}

static func _crop_material(c: Color) -> Material:
	var key := c.to_html()
	if _materials.has(key):return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=.95
	_materials[key]=m
	return m


static func _soil_material() -> Material:
	if _materials.has("soil"):return _materials["soil"]
	var m := StandardMaterial3D.new()
	m.albedo_texture=preload("res://assets/textures/ground/dirt.jpg")
	m.albedo_color=Color(.34,.29,.24)
	m.uv1_triplanar=true
	m.uv1_world_triplanar=true
	m.uv1_scale=Vector3.ONE*.5
	m.roughness=.96
	_materials["soil"]=m
	return m


static func _near_zone(game, at: Vector3, margin: float) -> bool:
	for zone in game.cfg.zones.get("list",[]):
		var center: Vector3=game.zones.center(str(zone.id)) if game.zones else Vector3.INF
		if Vector2(center.x-at.x,center.z-at.z).length()<float(zone.get("radius",13))+margin:return true
	return false


static func _hash(a: int, b: int) -> int:
	var v := (a*73856093)^(b*19349663)
	return absi(v^(v>>13))


## Tannen und Felsbrocken auf den Parzellen entfernen (nur Optik, gleiche MultiMeshes wie die Gehwege).
static func _clear_scatter(game, fields: Array) -> int:
	var root: Node=game.get_node_or_null("MixedBoundaries/OuterMountainBoundaries")
	if root==null or fields.is_empty():return 0
	var removed := 0
	for node in root.get_children():
		if not node is MultiMeshInstance3D:continue
		var id := str(node.get_meta("nature_id",""))
		if not (id.begins_with("pine") or id.begins_with("rock")):continue
		var kept: Array[Transform3D]=[]
		for i in node.multimesh.instance_count:
			var t: Transform3D=node.multimesh.get_instance_transform(i)
			var inside := false
			for f in fields:
				var local: Vector3=(t.origin-f.pos).rotated(Vector3.UP,-float(f.yaw))
				if absf(local.x)<FIELD.x*.5+4.0 and absf(local.z)<FIELD.y*.5+3.0:inside=true
			if not inside:kept.append(t)
		if kept.size()==node.multimesh.instance_count:continue
		removed+=node.multimesh.instance_count-kept.size()
		node.multimesh.instance_count=kept.size()
		for i in kept.size():node.multimesh.set_instance_transform(i,kept[i])
	return removed
