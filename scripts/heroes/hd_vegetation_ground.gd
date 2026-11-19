extends RefCounted
## Einmalige Bodenmaske: RG=Erde/Gras, B=Gehweg, A=Verdichtung. Keine Renderknoten.
const RESOLUTION := 1024

static func build(game, plants: Node3D) -> void:
	var bounds: Array=game.cfg.arena.bounds
	var rect := Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2])-float(bounds[0]),float(bounds[3])-float(bounds[1]))
	rect=rect.grow(HdArenaMountains.APRON+6.0)
	var brushes: Array=plants.get_meta("ground_brushes",[]).duplicate()
	brushes.append_array(HdArenaMountains.vegetation_roots(game.arena_layout))
	var secrets: Node3D=game.get_node_or_null("ExplorationCaverns")
	if secrets:
		for piece in secrets.get_meta("secret_cover",[]):
			if piece.kind=="ruin":continue
			brushes.append({"pos":piece.pos,"radius":2.8 if str(piece.kind).begins_with("pine") else 1.6,"grass":.15})
	for node in game.find_children("*","Node3D",true,false):
		if node.has_meta("vegetation_root"):
			brushes.append({"pos":node.position,"radius":2.6,"grass":.15})
	var image := Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for i in brushes.size():_paint(image,rect,brushes[i],i)
	_paint_streets(image,rect,game.get_meta("settlement_street_paths",[]))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var copies := {}
	for node in game.find_children("*","MeshInstance3D",true,false):
		if not node.has_meta("vegetation_ground"):continue
		var source: ShaderMaterial=node.material_override
		if source==null:continue
		var key := source.get_instance_id()
		if not copies.has(key):
			var material: ShaderMaterial=source.duplicate()
			material.set_shader_parameter("vegetation_mask",texture)
			material.set_shader_parameter("vegetation_soil",preload("res://assets/textures/ground/dirt.jpg"))
			material.set_shader_parameter("vegetation_grass",preload("res://assets/textures/ground/grass_a.jpg"))
			material.set_shader_parameter("vegetation_bounds",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
			material.set_shader_parameter("vegetation_enabled",true)
			copies[key]=material
		node.material_override=copies[key]
	game.set_meta("vegetation_ground_texture",texture)
	game.set_meta("vegetation_ground_bounds",rect)
	game.set_meta("vegetation_ground_roots",brushes)


static func _paint(image: Image, rect: Rect2, brush: Dictionary, index: int) -> void:
	var at: Vector3=brush.pos
	var center := (Vector2(at.x,at.z)-rect.position)/rect.size*RESOLUTION
	var radius := float(brush.radius)*RESOLUTION/rect.size.x
	var reach := ceili(radius*1.25)
	var angle := float(index)*2.39996
	var side := Vector2(cos(angle),sin(angle))
	var soil := 1.0-float(brush.grass)*.72
	var grass := float(brush.grass)
	for y in range(maxi(0,floori(center.y)-reach),mini(RESOLUTION,ceili(center.y)+reach+1)):
		for x in range(maxi(0,floori(center.x)-reach),mini(RESOLUTION,ceili(center.x)+reach+1)):
			var p := (Vector2(x+.5,y+.5)-center)/maxf(radius,.001)
			var u := p.dot(side)
			var v := p.dot(Vector2(-side.y,side.x))*1.1
			var distance := u*u+v*v
			# Leicht unregelmäßige Kontur; weich überlappende Pinsel bilden zusammenhängenden Waldboden.
			distance+=sin(u*5.0+float(index))*sin(v*4.0)*.09
			var weight := 1.0-smoothstep(.24,1.0,distance)
			if weight<=0:continue
			var old := image.get_pixel(x,y)
			image.set_pixel(x,y,Color(maxf(old.r,weight*soil),maxf(old.g,weight*grass),old.b,old.a))

static func _paint_streets(image: Image, rect: Rect2, paths: Array) -> void:
	var scale := RESOLUTION/rect.size.x
	for path in paths:
		# Pro Route nur einmal verdichten: mehr Abtastpunkte machen einen Weg nicht heller.
		var coverage := {}
		for i in path.size()-1:
			var a: Vector3=path[i]
			var b: Vector3=path[i+1]
			var steps := maxi(1,ceili(a.distance_to(b)/.4))
			for step in steps+1:
				var at := a.lerp(b,float(step)/steps)
				var door_distance := minf(at.distance_to(path[0]),at.distance_to(path[-1]))
				var radius := 1.12+sin(at.x*.63+at.z*.41)*.13+sin(at.z*1.31-at.x*.27)*.09
				radius+=.25*(1.0-smoothstep(0,3,door_distance))
				var center := (Vector2(at.x,at.z)-rect.position)*scale
				var pixels := radius*scale
				var reach := ceili(pixels)
				for y in range(maxi(0,floori(center.y)-reach),mini(RESOLUTION,ceili(center.y)+reach+1)):
					for x in range(maxi(0,floori(center.x)-reach),mini(RESOLUTION,ceili(center.x)+reach+1)):
						var d := Vector2(x+.5,y+.5).distance_to(center)/pixels
						var weight := 1.0-smoothstep(.42,1.0,d)
						if weight<=0:continue
						var key := y*RESOLUTION+x
						coverage[key]=maxf(float(coverage.get(key,0)),weight)
		for key: int in coverage:
			var x := key%RESOLUTION
			var y := key/RESOLUTION
			var old := image.get_pixel(x,y)
			var weight: float=coverage[key]
			image.set_pixel(x,y,Color(old.r,old.g,maxf(old.b,weight),minf(1,old.a+weight*.38)))
