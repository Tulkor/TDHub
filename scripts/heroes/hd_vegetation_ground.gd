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
	var use := _bake_use(game,rect)
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
			material.set_shader_parameter("ground_use",use)
			material.set_shader_parameter("ground_use_bounds",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
			material.set_shader_parameter("ground_use_enabled",true)
			copies[key]=material
		node.material_override=copies[key]
	game.set_meta("vegetation_ground_texture",texture)
	game.set_meta("ground_use_texture",use)
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


## Nutzungskarte für die Bodenmaterialien (Lukas 2026-11-19: Sediment nach Nutzung und Gefälle statt
## Rauschflecken). R Siedlung/Trittfläche, G Nässe, B Hangschutt, A Platzpflaster. Nur Optik, einmal je Spiel.
const USE_RESOLUTION := 384

static func _bake_use(game, rect: Rect2) -> ImageTexture:
	var n := USE_RESOLUTION
	var cell := rect.size.x/n
	var layout: HdArena=game.arena_layout
	var lane_width := float(game.cfg.arena.road_width)*.5
	var heights := PackedFloat32Array()
	var settled := PackedFloat32Array()
	var gutter := PackedFloat32Array()
	heights.resize(n*n)
	settled.resize(n*n)
	gutter.resize(n*n)
	for y in n:
		for x in n:
			var p := Vector3(rect.position.x+(x+.5)*cell,0,rect.position.y+(y+.5)*cell)
			var i := y*n+x
			var h := HdArenaMountains.ground_height(layout,p)
			heights[i]=h
			var q := layout.nearest(p)
			var lane := Vector2(p.x,p.z).distance_to(Vector2(q.x,q.z))
			var low := 1.0-smoothstep(1.2,3.5,h)
			# Neben dem Pflaster ist der Boden zertreten; das Regenwasser läuft vom Pflaster in eine Rinne.
			var roadside := (1.0-smoothstep(lane_width+.5,lane_width+9.0,lane))*.8
			var city := .45 if layout.boundary_kind(p)=="city" else 0.0
			settled[i]=maxf(roadside,city)*low
			var wave := .55+.45*sin(p.x*.21+p.z*.17)*sin(p.x*.07-p.z*.13)
			gutter[i]=smoothstep(lane_width-.4,lane_width+.6,lane)*(1.0-smoothstep(lane_width+1.2,lane_width+3.6,lane))*wave*low
	var cathedral: Node=game.get_node_or_null("SchwarzeKathedrale")
	var sites: Array=cathedral.get_meta("street_sites",[]) if cathedral else []
	for site in sites:
		_splat(settled,rect,cell,site.center,16.0,6.0,1.0)
	var paved := PackedFloat32Array()
	paved.resize(n*n)
	var plazas: Array=cathedral.get_meta("settlement_plazas",[]) if cathedral else []
	for plaza in plazas:
		_splat(paved,rect,cell,plaza.pos,float(plaza.get("radius",11.0))*.82,float(plaza.get("radius",11.0))*.6,1.0,true)
		_splat(settled,rect,cell,plaza.pos,float(plaza.get("radius",11.0))+6.0,6.0,1.0)
	# Gepflasterte Gassen: Vorplätze benachbarter Häuser einer Zeile zu einer durchgehenden Gasse verbinden.
	var streets := {}
	for site in sites:
		if not site.get("town",false):continue
		# Gegenüberliegende Zeilen (2k, 2k+1) teilen sich eine Gasse.
		var pair := int(site.get("row",-2))/2
		if not streets.has(pair):streets[pair]=[]
		streets[pair].append(site.approach)
	for pair in streets:
		var points: Array=streets[pair]
		points.sort_custom(func(a,b):return a.x<b.x)
		for i in points.size():
			_splat(paved,rect,cell,points[i],3.2,1.6,.95)
			if i>0 and (points[i] as Vector3).distance_to(points[i-1])<26.0:
				_stroke(paved,rect,cell,points[i-1],points[i],2.6,1.4,.95)
	var blurred := _blur(heights,n,4)
	var slope := PackedFloat32Array()
	slope.resize(n*n)
	for y in range(1,n-1):
		for x in range(1,n-1):
			var i := y*n+x
			var gx := (heights[i+1]-heights[i-1])/(2.0*cell)
			var gz := (heights[i+n]-heights[i-n])/(2.0*cell)
			slope[i]=Vector2(gx,gz).length()
	var talus := _blur(slope,n,3)
	var image := Image.create(n,n,false,Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var i := y*n+x
			# Senken sammeln Wasser und Feinmaterial, Hangfüße den Schutt von oben.
			var hollow := clampf((blurred[i]-heights[i]-.25)*.6,0.0,1.0)
			var scree := clampf(talus[i]*.8-slope[i]*.3,0.0,1.0)*(1.0-smoothstep(5.0,10.0,heights[i]))
			var wet := clampf(maxf(gutter[i]*.75,hollow),0.0,1.0)
			image.set_pixel(x,y,Color(clampf(settled[i],0,1),wet,scree,clampf(paved[i],0,1)))
	if OS.has_environment("GEMTD_BODEN_KARTE"):image.save_png(OS.get_environment("GEMTD_BODEN_KARTE"))
	return ImageTexture.create_from_image(image)


static func _splat(field: PackedFloat32Array, rect: Rect2, cell: float, at: Vector3, radius: float, soft: float, strength: float, ragged := false) -> void:
	var n := USE_RESOLUTION
	var cx := (at.x-rect.position.x)/cell
	var cy := (at.z-rect.position.y)/cell
	var reach := ceili(radius/cell)+1
	for y in range(maxi(0,floori(cy)-reach),mini(n,ceili(cy)+reach+1)):
		for x in range(maxi(0,floori(cx)-reach),mini(n,ceili(cx)+reach+1)):
			var d := Vector2(x+.5-cx,y+.5-cy).length()*cell
			if ragged:
				# Platzränder folgen den Hausfluchten, keine Zirkelkreise.
				var angle := atan2(y+.5-cy,x+.5-cx)
				d*=1.0+.13*sin(angle*3.0+at.x)+.08*sin(angle*5.0-at.z)
			var weight := (1.0-smoothstep(radius-soft,radius,d))*strength
			if weight<=0.0:continue
			field[y*n+x]=maxf(field[y*n+x],weight)


static func _stroke(field: PackedFloat32Array, rect: Rect2, cell: float, a: Vector3, b: Vector3, radius: float, soft: float, strength: float) -> void:
	var steps := maxi(1,ceili(a.distance_to(b)/(cell*.7)))
	for k in steps+1:
		var at := a.lerp(b,float(k)/steps)
		# Breite schwankt leicht, wie in gewachsenen Gassen.
		_splat(field,rect,cell,at,radius*(1.0+.12*sin(at.x*.37+at.z*.23)),soft,strength)


static func _blur(field: PackedFloat32Array, n: int, radius: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(n*n)
	var out := PackedFloat32Array()
	out.resize(n*n)
	var span := float(radius*2+1)
	for y in n:
		var sum := 0.0
		for k in range(-radius,radius+1):sum+=field[y*n+clampi(k,0,n-1)]
		for x in n:
			tmp[y*n+x]=sum/span
			sum+=field[y*n+clampi(x+radius+1,0,n-1)]-field[y*n+clampi(x-radius,0,n-1)]
	for x in n:
		var sum := 0.0
		for k in range(-radius,radius+1):sum+=tmp[clampi(k,0,n-1)*n+x]
		for y in n:
			out[y*n+x]=sum/span
			sum+=tmp[clampi(y+radius+1,0,n-1)*n+x]-tmp[clampi(y-radius,0,n-1)*n+x]
	return out
