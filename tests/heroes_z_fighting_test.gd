extends Node
## Lauf: einzeln (Name heroeszfight)
## Modi: heroes
## GPU-Tiefentest: dieselben statischen Flächen bei umgekehrter Zeichenreihenfolge.
var failures := 0
var vertices := PackedVector3Array()
var colors := PackedColorArray()
var palette := {}
var labels := {}
var source_count := 0
var game: HdGame
var scene_meshes: Array[ArrayMesh] = []
var findings: Array = []
var controls_passed := false
var faces_by_material := {}
var face_sources := PackedStringArray()
var last_eye := Vector3.ZERO
var last_focus := Vector3.ZERO
var last_size := 500.0

func _ready() -> void:
	Sfx.audible=false
	if "--niedrig" in OS.get_cmdline_user_args():
		Display.quality=Display.LOW
		Display.apply_quality()
	Session.coop={}
	Session.skip_setup=true
	game=load("res://scenes/heroes_game.tscn").instantiate()
	game.bot=true
	game.persist_settings=false
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	_collect(game)
	game.hide()
	if vertices.size()<3000 or source_count<50:
		failures+=1
		printerr("FAIL Z-Fighting-Scan hat nicht genügend statische Geometrie erfasst")
	print("MESSUNG ZFighting Quellen=%d Dreiecke=%d Materialgruppen=%d" % [source_count,vertices.size()/3,palette.size()])
	if DisplayServer.get_name()=="headless":
		print("SKIP Z-Fighting benötigt echten Renderer; tools/render_windows.ps1 -Scene res://tests/heroes_z_fighting_test.tscn")
	else:
		await _controls()
		controls_passed=failures==0
		scene_meshes.append(_mesh(vertices,colors,false))
		scene_meshes.append(_mesh(vertices,colors,true))
		for view in [Vector3(0,420,.01),Vector3(220,300,220),Vector3(-220,300,-220),Vector3(.025,420,.035)]:
			var index := str(view)
			var a: Image=await _capture(vertices,colors,false,view,500.0,Vector3.ZERO,true)
			var b: Image=await _capture(vertices,colors,true,view,500.0,Vector3.ZERO,true)
			var changed := _difference(a,b,"karte-"+str(hash(view)),true)
			print("MESSUNG ZFighting Kamera=%s instabile_Pixel=%d" % [index,changed])
			if changed>0:failures+=1
		for z in [-160.0,0.0,160.0]:
			for x in [-160.0,0.0,160.0]:
				var focus := Vector3(x,0,z)
				var eye := focus+Vector3(35,180,65)
				var a: Image=await _capture(vertices,colors,false,eye,170.0,focus,true)
				var b: Image=await _capture(vertices,colors,true,eye,170.0,focus,true)
				var changed := _difference(a,b,"kachel-"+str(x)+"-"+str(z),true)
				print("MESSUNG ZFighting Kachel=%s instabile_Pixel=%d" % [focus,changed])
				if changed>0:failures+=1
	var report := FileAccess.open("res://.godot/z-fighting-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"status":"skip" if DisplayServer.get_name()=="headless" else ("pass" if failures==0 else "fail"),"controls_passed":controls_passed,"sources":source_count,"triangles":vertices.size()/3,"findings":findings},"  "))
	report.close()
	game.queue_free()
	await get_tree().process_frame
	print("FERTIG Z-Fighting, Fehler: ",failures)
	get_tree().quit(1 if failures else 0)

func _collect(root: Node) -> void:
	for child in root.get_children():
		if child is Node3D and not child.is_visible_in_tree():continue
		if child is HdHero or child is HdEnemy:continue
		if child.name in ["UndergrowthPatches","ExplorationSecrets"]:continue
		if child is MeshInstance3D:
			# Modell-Skins/Skelette gehören nicht zum statischen Geometrietest.
			if not child.skeleton.is_empty() and child.get_node_or_null(child.skeleton) is Skeleton3D:continue
			_append(child.mesh,child.global_transform,child.material_override,str(game.get_path_to(child)))
		elif child is MultiMeshInstance3D and child.multimesh:
			# Große Wald-/Geröll-Scatter sind Textur-/Alpha-Modelle, keine übereinanderliegenden Bodenlagen.
			if "OuterMountainBoundaries" in str(child.get_path()):continue
			if "ExplorationCaverns" in str(child.get_path()) and child.material_override==null:continue
			for i in child.multimesh.instance_count:
				_append(child.multimesh.mesh,child.global_transform*child.multimesh.get_instance_transform(i),child.material_override,str(game.get_path_to(child))+" #instance="+str(i))
		_collect(child)

func _append(mesh: Mesh, transform: Transform3D, override: Material, label: String) -> void:
	if mesh==null:return
	for surface in mesh.get_surface_count():
		var material: Material=override if override else mesh.surface_get_material(surface)
		if material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
		if material is ShaderMaterial:
			var code: String=material.shader.code
			if "depth_draw_never" in code or "blend_add" in code:continue
			if "ALPHA_SCISSOR_THRESHOLD" in code and int(material.get_shader_parameter("surface"))>0:continue
		var key := material.get_instance_id() if material else 0
		if not palette.has(key):
			palette[key]=Color.from_hsv(fposmod(float(palette.size())*.618034,1),.55+.35*fposmod(float(palette.size())*.37,1),.65+.35*fposmod(float(palette.size())*.23,1))
			labels[key]=[]
			faces_by_material[key]=[]
		var group_label := label.get_slice(" #instance=",0)
		if not labels[key].has(group_label):labels[key].append(group_label)
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var ids := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:ids=arrays[Mesh.ARRAY_INDEX]
		if ids.is_empty():
			for i in points.size():ids.append(i)
		var used := false
		for i in range(0,ids.size(),3):
			var a: Vector3=transform*points[ids[i]]
			var b: Vector3=transform*points[ids[i+1]]
			var c: Vector3=transform*points[ids[i+2]]
			var center := (a+b+c)/3.0
			if absf(center.x)>240 or absf(center.z)>240 or center.y>60 or center.y<-.5:continue
			faces_by_material[key].append(vertices.size()/3)
			face_sources.append(label)
			vertices.append_array(PackedVector3Array([a,b,c]))
			for k in 3:colors.append(palette[key])
			used=true
		if used:source_count+=1

func _capture(points: PackedVector3Array, tint: PackedColorArray, reverse: bool, view: Vector3, size := 500.0, focus := Vector3.ZERO, use_scene := false) -> Image:
	last_eye=view
	last_focus=focus
	last_size=size
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1024,1024)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh=scene_meshes[int(reverse)] if use_scene else _mesh(points,tint,reverse)
	node.material_override=material
	viewport.add_child(node)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=size
	camera.position=view
	viewport.add_child(camera)
	camera.look_at(focus,Vector3.FORWARD if absf(view.x-focus.x)<.1 and absf(view.z-focus.z)<.1 else Vector3.UP)
	camera.make_current()
	for frame in 3:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await get_tree().process_frame
	return image

func _mesh(points: PackedVector3Array,tint: PackedColorArray,reverse: bool) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_COLOR]=tint
	var indices := PackedInt32Array()
	indices.resize(points.size())
	for i in range(points.size()/3):
		var start := points.size()-3-i*3 if reverse else i*3
		indices[i*3]=start
		indices[i*3+1]=start+1
		indices[i*3+2]=start+2
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _controls() -> void:
	var plane := PlaneMesh.new()
	plane.size=Vector2.ONE*4
	var arrays := plane.surface_get_arrays(0)
	var p: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var ids: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var points := PackedVector3Array()
	var tint := PackedColorArray()
	var control_colors := [Color.from_hsv(.17,.73,.81),Color.from_hsv(.68,.61,.75)]
	for color in control_colors:
		for index in ids:
			points.append(p[index])
			tint.append(color)
	var a: Image=await _capture(points,tint,false,Vector3(0,10,.01),5)
	var b: Image=await _capture(points,tint,true,Vector3(0,10,.01),5)
	var bad := _difference(a,b,"kontrollfehler",false)
	print("MESSUNG ZFighting Kontrollfehler_Pixel=",bad)
	if bad<10000:
		failures+=1
		printerr("FAIL Z-Fighting-Kontrollfehler wurde nicht erkannt")
	# Vollständiger Testpfad einschließlich Farbcodierung und geometrischer Rückprüfung.
	var saved_points := vertices
	var saved_palette := palette
	var saved_faces := faces_by_material
	vertices=points
	palette={0:control_colors[0],1:control_colors[1]}
	faces_by_material={0:[0,1],1:[2,3]}
	var small_a: Image=a.duplicate()
	var small_b: Image=b.duplicate()
	small_a.resize(96,96,Image.INTERPOLATE_NEAREST)
	small_b.resize(96,96,Image.INTERPOLATE_NEAREST)
	var confirmed := _difference(small_a,small_b,"kontrolle-vollstaendig",true,false)
	print("MESSUNG ZFighting Bestaetigter_Kontrollfehler=",confirmed)
	if confirmed<1000:
		failures+=1
		printerr("FAIL Vollständiger Z-Fighting-Testpfad erkennt die eingespritzte Überlagerung nicht")
	vertices=saved_points
	palette=saved_palette
	faces_by_material=saved_faces
	var first := _hit(points,[0,1],Vector3(0,10,.01),Vector3.DOWN)
	var second := _hit(points,[2,3],Vector3(0,10,.01),Vector3.DOWN)
	if not _coplanar(first,second):
		failures+=1
		printerr("FAIL Koplanare Kontrollflächen werden geometrisch nicht erkannt")
	for i in range(points.size()/2,points.size()):points[i].y+=.02
	if _coplanar(_hit(points,[0,1],Vector3(0,10,.01),Vector3.DOWN),_hit(points,[2,3],Vector3(0,10,.01),Vector3.DOWN)):
		failures+=1
		printerr("FAIL Geometrische Kontrolle verwechselt getrennte Flächen mit Z-Fighting")
	a=await _capture(points,tint,false,Vector3(0,10,.01),5)
	b=await _capture(points,tint,true,Vector3(0,10,.01),5)
	var stable := _difference(a,b,"kontrolle-abstand",false)
	print("MESSUNG ZFighting Abstandskontrolle_Pixel=",stable)
	if stable>8:
		failures+=1
		printerr("FAIL Getrennte Flächen wurden fälschlich als Z-Fighting gemeldet")

func _difference(a: Image,b: Image,label: String,report: bool, record_failure := true) -> int:
	var changed := 0
	var boundary_pixels := 0
	var differences := Image.create(a.get_width(),a.get_height(),false,Image.FORMAT_RGB8)
	var pairs := {}
	var source_pairs := {}
	for y in a.get_height():
		for x in a.get_width():
			var u := a.get_pixel(x,y)
			var v := b.get_pixel(x,y)
			var delta := maxf(absf(u.r-v.r),maxf(absf(u.g-v.g),absf(u.b-v.b)))
			if delta<.03:continue
			if report:
				var ray := _ray(Vector2(x+.5,y+.5),Vector2(a.get_size()))
				var left := _hit(vertices,faces_by_material.get(_material_key(u),[]),ray[0],ray[1])
				var right := _hit(vertices,faces_by_material.get(_material_key(v),[]),ray[0],ray[1])
				if not _coplanar(left,right):
					boundary_pixels+=1
					continue
				if record_failure:
					var source_key := face_sources[int(left.face)]+" <> "+face_sources[int(right.face)]
					if not source_pairs.has(source_key):
						source_pairs[source_key]={"a":face_sources[int(left.face)],"b":face_sources[int(right.face)],"position":[left.pos.x,left.pos.y,left.pos.z],"pixels":0}
					source_pairs[source_key].pixels+=1
			changed+=1
			differences.set_pixel(x,y,Color.RED)
			if report:
				var key := str(u.to_html(false))+"/"+str(v.to_html(false))
				pairs[key]=int(pairs.get(key,0))+1
	if report:print("MESSUNG ZFighting Randkontakte=",boundary_pixels," Koplanare_Pixel=",changed)
	if report and changed>0 and record_failure:
		printerr("FAIL Z-Fighting: ",label," (",changed," instabile Pixel)")
		a.save_png("res://.godot/z-fighting-"+label+"-a.png")
		b.save_png("res://.godot/z-fighting-"+label+"-b.png")
		differences.save_png("res://.godot/z-fighting-"+label+"-fehler.png")
		var ordered := pairs.keys()
		ordered.sort_custom(func(u,v):return int(pairs[u])>int(pairs[v]))
		var details: Array = []
		for pair in ordered.slice(0,6):
			details.append({"pixels":pairs[pair],"a":_identify(str(pair).split("/")[0]),"b":_identify(str(pair).split("/")[1])})
			print("ZF_PAAR ",pairs[pair]," ",_identify(str(pair).split("/")[0])," <> ",_identify(str(pair).split("/")[1]))
		findings.append({"view":label,"changed_pixels":changed,"materials":details,"surfaces":source_pairs.values(),"image":"res://.godot/z-fighting-"+label+"-fehler.png"})
	return changed

func _ray(pixel: Vector2, size: Vector2) -> Array:
	var direction := (last_focus-last_eye).normalized()
	var hint := Vector3.FORWARD if absf(last_eye.x-last_focus.x)<.1 and absf(last_eye.z-last_focus.z)<.1 else Vector3.UP
	var right := direction.cross(hint).normalized()
	var up := right.cross(direction).normalized()
	var uv := pixel/size-Vector2.ONE*.5
	return [last_eye+right*uv.x*last_size-up*uv.y*last_size,direction]

func _hit(points: PackedVector3Array, faces: Array, origin: Vector3, direction: Vector3) -> Dictionary:
	var result := {}
	var distance := INF
	for face in faces:
		var index := int(face)*3
		var a := points[index]
		var b := points[index+1]
		var c := points[index+2]
		var at=Geometry3D.ray_intersects_triangle(origin,direction,a,b,c)
		if at==null:continue
		var span: float=origin.distance_squared_to(at)
		if span>=distance:continue
		distance=span
		result={"pos":at,"normal":(b-a).cross(c-a).normalized(),"face":int(face)}
	return result

func _coplanar(a: Dictionary,b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():return false
	return absf((a.normal as Vector3).dot(b.normal))>cos(deg_to_rad(.5)) and (a.pos as Vector3).distance_to(b.pos)<.001

func _material_key(color: Color) -> int:
	var best := INF
	var result := -1
	for key in palette:
		var expected: Color=palette[key].linear_to_srgb()
		var delta := Vector3(color.r-expected.r,color.g-expected.g,color.b-expected.b).length_squared()
		if delta<best:
			best=delta
			result=int(key)
	return result if best<.01 else -1

func _identify(rgb: String) -> String:
	var color := Color(rgb)
	var best := INF
	var result := "unbekannt"
	for key in palette:
		var expected: Color=palette[key].linear_to_srgb()
		var delta := Vector3(color.r-expected.r,color.g-expected.g,color.b-expected.b).length_squared()
		if delta<best:
			best=delta
			result=str(labels[key]).left(350)
	return result
