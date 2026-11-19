extends RefCounted
## Rein optische, weich auslaufende Trampelpfade. Ein Mesh je Geländegruppe, keine Kollision/Prozesse.
static func add_paths(parent: Node3D, paths: Array, width: float, look: String, height: Callable = Callable(), continuous_uv := false) -> MeshInstance3D:
	if paths.is_empty(): return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := 0
	for path in paths:
		var total := 0.0
		for j in path.size()-1:total+=(path[j] as Vector3).distance_to(path[j+1])
		var walked := 0.0
		for i in range(path.size()-1):
			var a: Vector3 = path[i]
			var b: Vector3 = path[i+1]
			var length := Vector2(b.x-a.x,b.z-a.z).length()
			if length < .01: continue
			var side := Vector3(-(b-a).z,0,(b-a).x).normalized()*width*.5
			var steps := maxi(1, ceili(length / 1.5))
			for k in steps:
				var u := float(k)/steps
				var v := float(k+1)/steps
				var p := a.lerp(b,u)
				var q := a.lerp(b,v)
				if continuous_uv:
					u=(walked+u*length)/maxf(total,.001)
					v=(walked+v*length)/maxf(total,.001)
				for row in [[p-side,Vector2(0,u)],[p+side,Vector2(1,u)],[q-side,Vector2(0,v)], [p+side,Vector2(1,u)],[q+side,Vector2(1,v)],[q-side,Vector2(0,v)]]:
					var point: Vector3 = row[0]
					point.y = float(height.call(point)) if height.is_valid() else point.y
					point.y += .055
					st.set_normal(Vector3.UP)
					st.set_uv(row[1])
					st.add_vertex(point)
					vertices += 1
			walked+=length
	if vertices == 0: return null
	var node := MeshInstance3D.new()
	node.name = "GroundWear"
	node.mesh = st.commit()
	node.material_override = material(look)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func material(look: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/ground_wear.gdshader")
	var colors := {"druid":"9c997d","poster":"a29b8b","deco":"a69b85","neon":"53797c","heroes":"746e61","snow":"d2e4e8"}
	var opacity := {"druid":.65,"poster":.4,"deco":.22,"neon":.14,"heroes":.58,"snow":.18}
	m.set_shader_parameter("tint", Color(str(colors.get(look,"9c997d"))))
	m.set_shader_parameter("opacity", float(opacity.get(look,.5)))
	m.set_shader_parameter("soil", preload("res://assets/textures/ground/gravel.jpg") if look in ["poster","deco","neon","snow"] else preload("res://assets/textures/ground/dirt.jpg"))
	return m


static func map_edges(map: MapData, cell_size: float, ground: Callable) -> Array:
	var paths: Array = []
	# Nur auf begehbarer Seite fester Wände/Häuser, nicht quer durch blockierte Blöcke.
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x,y)
			if map.get_tile(cell) == MapData.BLOCKED: continue
			for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var neighbor: Vector2i = cell+side
				if not map.in_bounds(neighbor) or map.get_tile(neighbor) != MapData.BLOCKED: continue
				var center := (Vector2(cell)+Vector2.ONE*.5)*cell_size + Vector2(side)*cell_size*.2
				var along := Vector2(-side.y,side.x)*cell_size*.55
				var a := Vector3(center.x-along.x,0,center.y-along.y)
				var b := Vector3(center.x+along.x,0,center.y+along.y)
				a.y = float(ground.call(Vector2(a.x,a.z)))
				b.y = float(ground.call(Vector2(b.x,b.z)))
				paths.append([a,b])
	return paths


static func rock_material(look := "druid") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/landscape_rock.gdshader")
	m.set_shader_parameter("rock", preload("res://assets/textures/rock/rock_face_03_diff_1k.jpg"))
	m.set_shader_parameter("ground", preload("res://assets/textures/ground/grass_a.jpg"))
	return m
