extends Node
## Lauf: einzeln (Name heroesseams)
## Modi: heroes
## Automatischer Materialvergleich über die ganze Karte plus Prüfung aller offenen Geländekanten.
var failures := 0
var game: HdGame

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
	game.hide()
	var terrain: MeshInstance3D=game.get_node("MixedBoundaries/OuterMountainBoundaries/ContinuousBasaltMountains")
	_check_edges(terrain.mesh)
	if DisplayServer.get_name()=="headless":
		print("SKIP Material-Bildvergleich benötigt echten Renderer; Windows: tools/render_windows.ps1 -Scene res://tests/heroes_terrain_seams_test.tscn")
	else:
		var a: Image=await _render(game.get_node("MainTerrainGround").material_override)
		var b: Image=await _render(terrain.material_override)
		_compare(a,b,"normal")
		var injected := StandardMaterial3D.new()
		injected.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		injected.albedo_color=Color.RED
		_compare(a,await _render(injected),"kontrollfehler",false)
		# Auch Oberflächen ohne Pflanzen prüfen, damit dichter Bewuchs Fehler nicht verdeckt.
		var flat: ShaderMaterial=game.get_node("MainTerrainGround").material_override.duplicate()
		var slope: ShaderMaterial=terrain.material_override.duplicate()
		flat.set_shader_parameter("vegetation_enabled",false)
		slope.set_shader_parameter("vegetation_enabled",false)
		_compare(await _render(flat),await _render(slope),"ohne-bewuchs")
	game.queue_free()
	await get_tree().process_frame
	print("FERTIG Übergangstest, Fehler: ",failures)
	get_tree().quit(1 if failures else 0)

func _check_edges(mesh: ArrayMesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():indices.append(i)
	var edges := {}
	for i in range(0,indices.size(),3):
		for pair in [[indices[i],indices[i+1]],[indices[i+1],indices[i+2]],[indices[i+2],indices[i]]]:
			var a: Vector3=vertices[pair[0]]
			var b: Vector3=vertices[pair[1]]
			var u := Vector2i(roundi(a.x*1000),roundi(a.z*1000))
			var v := Vector2i(roundi(b.x*1000),roundi(b.z*1000))
			var key := Vector4i(u.x,u.y,v.x,v.y) if u.x<v.x or (u.x==v.x and u.y<v.y) else Vector4i(v.x,v.y,u.x,u.y)
			if edges.has(key):edges[key][0]+=1
			else:edges[key]=[1,pair[0],pair[1]]
	var total := 0
	var gaps := 0
	var creases := 0
	for edge in edges.values():
		if int(edge[0])!=1:continue
		total+=1
		for i in [int(edge[1]),int(edge[2])]:
			if absf(vertices[i].y+.02)>.012:gaps+=1
			if normals[i].angle_to(Vector3.UP)>deg_to_rad(2):creases+=1
	print("MESSUNG Übergangskanten=%d Höhensprünge=%d Normalsprünge=%d" % [total,gaps,creases])
	if total==0 or gaps>0 or creases>0:
		failures+=1
		printerr("FAIL Offene Geländekanten treffen Grundhöhe und Grundnormale nicht durchgehend")

func _render(material: Material) -> Image:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(768,768)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color.BLACK
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("a8b8cf")
	environment.environment.ambient_light_energy=.6
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-34,0)
	light.light_energy=1.4
	light.shadow_enabled=false
	viewport.add_child(light)
	var plane := MeshInstance3D.new()
	var shape := PlaneMesh.new()
	var bounds: Rect2=game.get_meta("vegetation_ground_bounds",Rect2(-240,-240,480,480))
	shape.size=bounds.size+Vector2.ONE*2.0
	plane.mesh=shape
	plane.material_override=material
	viewport.add_child(plane)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=maxf(bounds.size.x,bounds.size.y)
	camera.position=Vector3(0,150,.001)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	camera.make_current()
	for frame in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	viewport.queue_free()
	await get_tree().process_frame
	return result

func _compare(a: Image, b: Image, label: String, expect_match := true) -> void:
	var bad := 0
	var sum := 0.0
	var total := 0
	var maximum := 0.0
	var minimum := 1.0
	var difference := Image.create(a.get_width(),a.get_height(),false,Image.FORMAT_RGB8)
	for y in range(2,a.get_height()-2):
		for x in range(2,a.get_width()-2):
			var u := a.get_pixel(x,y)
			var v := b.get_pixel(x,y)
			maximum=maxf(maximum,maxf(u.r,maxf(u.g,u.b)))
			minimum=minf(minimum,maxf(u.r,maxf(u.g,u.b)))
			var delta := maxf(absf(u.r-v.r),maxf(absf(u.g-v.g),absf(u.b-v.b)))
			sum+=delta
			total+=1
			if delta>.045:bad+=1
			difference.set_pixel(x,y,Color(delta*5,0,0))
	var ratio := float(bad)/maxi(1,total)
	var mean := sum/maxi(1,total)
	print("MESSUNG Materialvergleich %s Abweichung=%.5f Ausreißer=%.2f%%" % [label,mean,ratio*100])
	if maximum<.015 or maximum-minimum<.035:
		failures+=1
		printerr("FAIL Materialvergleich hat ein leeres/schwarzes Kontrollbild")
		return
	var mismatch := mean>.008 or ratio>.015
	if mismatch==expect_match:
		failures+=1
		printerr("FAIL Sichtbarer Material-/Beleuchtungssprung: ",label)
		a.save_png("res://.godot/terrain-seams-"+label+"-boden.png")
		b.save_png("res://.godot/terrain-seams-"+label+"-hang.png")
		difference.save_png("res://.godot/terrain-seams-"+label+"-abweichung.png")
