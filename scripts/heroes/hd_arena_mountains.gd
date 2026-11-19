class_name HdArenaMountains
extends RefCounted
## Zusammenhängendes Gebirge der äußeren Bollwerk-Begrenzungen.
## Das Höhenfeld schneidet dieselbe Lane-/Zonenkontur aus wie HdArena; rein optisch.

const CLEARANCE := 1.5
const APRON := 42.0
const StaticBatch = preload("res://scripts/map/static_mesh_batch.gd")
static var _geometry: Dictionary = {}
static var _materials: Dictionary = {}


static func build(game, parent: Node3D, layout: HdArena) -> Node3D:
	var config: Dictionary = game.cfg.arena.get("boundaries", {})
	var step := 3.0 if Display.quality == Display.LOW else 2.0
	var key := hash([layout.geometry_signature,step])
	if not _geometry.has(key):
		if _geometry.size() >= 3:
			_geometry.clear()
		_geometry[key] = _generate(game, layout, config, step)
	var data: Dictionary = _geometry[key]
	var root := Node3D.new()
	root.name = "OuterMountainBoundaries"
	root.set_meta("mountain_style", "continuous_basalt_valleys")
	root.set_meta("mountain_clearance", CLEARANCE)
	root.set_meta("mountain_vertices", data.vertices)
	root.set_meta("mountain_triangles", data.triangles)
	root.set_meta("mountain_main_peaks", 3)
	parent.add_child(root)
	if data.mesh != null:
		var terrain := MeshInstance3D.new()
		terrain.name = "ContinuousBasaltMountains"
		terrain.set_meta("vegetation_ground",true)
		terrain.mesh = data.mesh
		terrain.material_override = _material(float(config.get("mountain_height", 22.0)))
		root.add_child(terrain)

		_scatter(root, data.get("scatter", {}))
	return root


const PINES := ["pine_1", "pine_2", "pine_3", "pine_5"]
const ROCKS := ["rock_medium_1", "rock_medium_2", "rock_medium_3", "rock_tall_a"]


## Tannen und Felsbrocken als MultiMesh je Modell; scatter: Modellname -> [Transform3D mit Fußpunkt, Größe in Metern].
static func _scatter(root: Node3D, scatter: Dictionary) -> void:
	var trees := 0
	var rocks := 0
	for id in scatter:
		var path := "res://assets/models/nature/%s.glb" % id
		if not ResourceLoader.exists(path) or scatter[id].is_empty():
			continue
		var scene: Node3D = load(path).instantiate()
		var bounds := ModelLoader.aabb(scene, Transform3D.IDENTITY)
		var tall := maxf(bounds.size.y, 0.01)
		for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var local := part.transform
			var up := part.get_parent()
			while up != null and up != scene:
				local = (up as Node3D).transform * local
				up = up.get_parent()
			var transforms: Array = []
			for i in scatter[id].size():
				var at: Transform3D = scatter[id][i]
				# Die Basis trägt Drehung und Zielhöhe; das Modell wird auf diese Höhe gebracht und auf den Boden gestellt.
				var fit := Transform3D(at.basis * (1.0 / tall), at.origin) * Transform3D(Basis.IDENTITY, Vector3(0, -bounds.position.y, 0))
				transforms.append(fit * local)
			var first := root.get_child_count()
			StaticBatch.add(root,_tinted(part.mesh,id.begins_with("pine") or id.begins_with("bush") or id.begins_with("fern")),transforms,48.0)
			for child in root.get_children().slice(first):child.set_meta("nature_id",str(id))
		if id.begins_with("pine"):
			trees += scatter[id].size()
		else:
			rocks += scatter[id].size()
		scene.free()
	root.set_meta("mountain_trees", trees)
	root.set_meta("mountain_rocks", rocks)


## Kopie des Modell-Meshes mit gedämpften Farben (dunkle Bergtannen, kühler Fels), einmal je Mesh.
static func _tinted(mesh: Mesh, pine: bool) -> Mesh:
	var key := "tint_%d" % mesh.get_instance_id()
	if _materials.has(key):
		return _materials[key]
	var copy: Mesh = mesh.duplicate()
	for surface in copy.get_surface_count():
		var original = copy.surface_get_material(surface)
		if original is BaseMaterial3D:
			var dark: BaseMaterial3D = original.duplicate()
			dark.albedo_color *= Color(0.55, 0.68, 0.62) if pine else Color(0.53, 0.56, 0.61)
			dark.roughness = 0.94
			copy.surface_set_material(surface, dark)
	_materials[key] = copy
	return copy


static func _material(height: float) -> ShaderMaterial:
	if not _materials.has(height):
		# Keep the scanned basalt's real albedo/normal/roughness/specular maps.
		# Duplicate before changing snow; the Schlund's material must stay unchanged.
		var material: ShaderMaterial = HdFinalStyle._basalt_material().duplicate()
		material.set_shader_parameter("snow_line", height * 0.7)
		material.set_shader_parameter("snow_amount", 0.72)
		material.set_shader_parameter("snow_color", Color(0.56, 0.62, 0.68))
		material.set_shader_parameter("stone_brightness", 0.46)
		material.set_shader_parameter("foot_blend", 1.0)
		material.set_shader_parameter("foot_albedo", preload("res://assets/textures/rock/rock_face_03_diff_1k.jpg"))
		material.set_shader_parameter("foot_soil", preload("res://assets/textures/ground/dirt.jpg"))
		material.set_shader_parameter("foot_scree", preload("res://assets/textures/ground/gravel.jpg"))
		material.set_shader_parameter("foot_normal",preload("res://assets/textures/rock/rock_face_03_nor_gl_1k.jpg"))
		material.set_shader_parameter("foot_roughness",preload("res://assets/textures/rock/rock_face_03_rough_1k.jpg"))
		material.set_shader_parameter("foot_soil_normal",preload("res://assets/textures/ground/dirt_normal.jpg"))
		material.set_shader_parameter("foot_soil_specular",preload("res://assets/textures/ground/dirt_specular.png"))
		material.set_shader_parameter("foot_scree_normal",preload("res://assets/textures/ground/gravel_normal.jpg"))
		material.set_shader_parameter("foot_scree_specular",preload("res://assets/textures/ground/gravel_specular.png"))
		_materials[height] = material
	return _materials[height]


static func _city_clearance(p: Vector3, game, config: Dictionary) -> float:
	var fortress: Array = game.cfg.arena.get("fortress", [0, 0])
	var distance := Vector2(p.x-float(fortress[0]), p.z-float(fortress[1])).length() - float(config.get("city_radius", 56.0))
	for site in config.get("city_sites", [[-33,-33,23], [33,33,16]]):
		var delta := Vector2(p.x-float(site[0]), p.z-float(site[1]))
		distance = minf(distance, delta.length()-float(site[2]))
	return distance


static func _walk_clearance(p: Vector3, game, layout: HdArena) -> float:
	var distance := p.distance_to(layout.nearest(p)) - layout.width
	distance = minf(distance, Vector2(p.x,p.z).length()-float(game.cfg.arena.fortress_zone))
	for zone in game.cfg.zones.get("list", []):
		var center = zone.get("center", zone.get("pos", []))
		if center is Array and center.size() == 2:
			distance = minf(distance, Vector2(p.x-float(center[0]),p.z-float(center[1])).length()-float(zone.get("radius",13)))
	for pocket in layout.access_pockets:
		distance=minf(distance,p.distance_to(pocket[0])-float(pocket[1]))
	distance=minf(distance,HdExplorationLayout.clearance(p))
	return distance


static func _generate(game, layout: HdArena, config: Dictionary, step: float) -> Dictionary:
	var bounds: Array = game.cfg.arena.bounds
	var minimum := Vector2(float(bounds[0])-APRON, float(bounds[1])-APRON)
	var maximum := Vector2(float(bounds[2])+APRON, float(bounds[3])+APRON)
	var cols := ceili((maximum.x-minimum.x)/step)
	var rows := ceili((maximum.y-minimum.y)/step)
	var height := maxf(8.0,float(config.get("mountain_height",22.0)))
	var noise := FastNoiseLite.new()
	noise.seed = 681749
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.48
	var detail := FastNoiseLite.new()
	detail.seed = 4417
	detail.frequency = 0.11
	detail.fractal_octaves = 3
	var regions := FastNoiseLite.new()
	regions.seed = 90211
	regions.frequency = 0.014
	var safe: Array = []
	var green: Array = []
	var points: Array = []
	# Three different dominant massifs, embedded in the same ridged heightfield.
	var peaks := [
		Vector3(float(bounds[0])-8, height*1.36, float(bounds[1])-8),
		Vector3(float(bounds[2])+8, height*1.57, float(bounds[3])+8),
		Vector3(float(bounds[0])-8, height*1.23, float(bounds[3])+8)
	]
	var safe_distance := CLEARANCE + step*0.72
	for z in range(rows+1):
		var row_points: Array[Vector3] = []
		var row_safe: Array[bool] = []
		var row_green: Array[bool] = []
		for x in range(cols+1):
			var p := Vector3(minimum.x+x*step,0,minimum.y+z*step)
			var walk := _walk_clearance(p,game,layout)
			var city := _city_clearance(p,game,config)
			var allowed: bool = walk >= safe_distance and city >= safe_distance and layout.boundary_kind(p) == "mountain"
			row_safe.append(allowed)
			row_green.append(allowed and walk >= safe_distance + 4.0 and city >= safe_distance + 4.0)
			var broad := noise.get_noise_2d(p.x,p.z)
			var ridge := 1.0-absf(noise.get_noise_2d(p.x+138.0,p.z-217.0))
			var elevation := height*(0.24+ridge*0.32+broad*0.15)
			for peak in peaks:
				var delta := Vector2(p.x-peak.x,p.z-peak.z).rotated(.42)
				# Asymmetric long ridges and eroded gullies instead of equally round cones.
				var d := Vector2(delta.x*.78,delta.y*1.18).length()
				var erosion := sin(atan2(delta.y,delta.x)*7.0 + broad*2.0)*.065*smoothstep(4.0,22.0,d)
				elevation = maxf(elevation, peak.y*pow(maxf(0.0,1.0-d/39.0),1.15)*(0.96+broad*0.12+erosion))
			# Plateaus und Felsstufen: in Mesa-Regionen wird die Höhe gestuft, dazwischen bleiben steile Wände.
			var shelf := height * 0.21
			var part := fposmod(elevation, shelf) / shelf
			var stepped := (floorf(elevation / shelf) + smoothstep(0.7, 1.0, part)) * shelf
			var mesa := smoothstep(0.42, 0.6, regions.get_noise_2d(p.x, p.z) * 0.5 + 0.5)
			elevation = lerpf(elevation, stepped, mesa * 0.9)
			elevation += detail.get_noise_2d(p.x, p.z) * height * 0.05 * (1.0 - mesa * 0.6)
			# Sanfter Hangfuß (Lukas 2026-11-15): der Berg steigt über rund 26 m erst flach, dann steiler an.
			var valley := smoothstep(safe_distance, safe_distance+26.0, walk)
			valley *= valley
			var town := smoothstep(safe_distance, safe_distance+30.0, city)
			town *= town
			var edge := minf(minf(p.x-minimum.x,maximum.x-p.x),minf(p.z-minimum.y,maximum.y-p.z))
			var outer := smoothstep(0.0,32.0,maxf(edge,0.0))
			var base := elevation*valley*town*outer
			var relief := 0.0
			if allowed and base < 10.0:
				var masks := HdTerrain.material_masks(Vector2(p.x,p.z))
				# Fels bildet Kuppen, Schutt kleinere Rücken; feuchte Erde bleibt in Mulden.
				var hummock := masks.x * (3.5 - masks.y * 1.4) + (1.0-masks.x) * (1.0-masks.z) * .28
				var transition := smoothstep(safe_distance,safe_distance+10.0,walk) * smoothstep(0.0,10.0,city)
				relief = hummock * transition * (1.0-smoothstep(3.0,10.0,base)) * outer
			p.y = -0.015 + base + relief
			row_points.append(p)
		points.append(row_points)
		safe.append(row_safe)
		green.append(row_green)
	# Jede offene Kante trifft den Grund bündig. Zwei weitere Gitterringe lassen Höhe/Normale auslaufen.
	var edge_blend: Array = []
	for z in range(rows+1):
		var row: Array = []
		for x in range(cols+1):
			var distance := 3.0
			if x==0 or z==0 or x==cols or z==rows:distance=0.0
			for dz in range(-2,3):
				for dx in range(-2,3):
					var sx := x+dx
					var sz := z+dz
					if sx<0 or sz<0 or sx>cols or sz>rows or not safe[sz][sx]:
						distance=minf(distance,Vector2(dx,dz).length())
			var blend := smoothstep(1.42,3.0,distance) if safe[z][x] else 0.0
			points[z][x].y=lerpf(-.018,points[z][x].y,blend)
			row.append(blend)
		edge_blend.append(row)
	var normals: Array = []
	for z in range(rows+1):
		var row: Array[Vector3] = []
		for x in range(cols+1):
			var dx: Vector3 = points[z][mini(x+1,cols)]-points[z][maxi(x-1,0)]
			var dz: Vector3 = points[mini(z+1,rows)][x]-points[maxi(z-1,0)][x]
			row.append(Vector3.UP if float(edge_blend[z][x])==0.0 else dz.cross(dx).normalized())
		normals.append(row)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	for z in rows:
		for x in cols:
			for tri in [[Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1)], [Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]]:
				if not (safe[tri[0].y][tri[0].x] and safe[tri[1].y][tri[1].x] and safe[tri[2].y][tri[2].x]):
					continue
				for index in tri:
					surface.set_normal(normals[index.y][index.x])
					surface.add_vertex(points[index.y][index.x])
				triangles += 1
	if triangles == 0:
		return {"mesh":null,"triangles":0,"vertices":0}
	surface.index()
	var mesh := surface.commit()
	# Bewuchs und Geröll: Tannen in Gruppen auf flachen Hängen und Plateaus unter der Schneegrenze,
	# Felsbrocken überall, große an steilen Stellen. Fester Zufall, damit alle Mitspieler dasselbe sehen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 55173
	var thin := 0.5 if Display.quality == Display.LOW else 1.0
	var settlements := _settlement_plan(game,layout,points,safe,step)
	var scatter := {}
	for id in PINES + ROCKS:
		scatter[id] = []
	for z in range(1, rows):
		for x in range(1, cols):
			var roll := rng.randf()
			var pick := rng.randi()
			var size_roll := rng.randf()
			var turn := rng.randf() * TAU
			var jitter := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)) * step * 0.5
			if not green[z][x] or not (green[z][x + 1] and green[z + 1][x] and green[z][x - 1] and green[z - 1][x]):
				continue
			var at: Vector3 = points[z][x]
			if at.y < 1.2:
				continue
			var slope: float = 1.0 - normals[z][x].y
			at += jitter
			if settlements.any(func(site):return Vector2(at.x-site.pos.x,at.z-site.pos.z).length()<6.5):continue
			var forest := smoothstep(0.38, 0.62, regions.get_noise_2d(at.x * 2.3 + 700.0, at.z * 2.3 - 300.0) * 0.5 + 0.5)
			if slope < 0.2 and at.y < height * 0.66 and roll < (0.05 + 0.3 * forest) * thin * step * 0.5:
				var tall := lerpf(5.0, 10.5, size_roll) * (1.0 - 0.3 * at.y / (height * 0.66))
				scatter[PINES[pick % PINES.size()]].append(Transform3D(Basis(Vector3.UP, turn) * Basis.from_scale(Vector3(tall, tall, tall)), at - Vector3.UP * 0.25))
			elif roll > 1.0 - (0.035 + slope * 0.07) * thin * step * 0.5:
				var big := slope > 0.3 and size_roll > 0.6
				var rock_size := lerpf(1.0, 2.6, size_roll) * (2.0 if big else 1.0)
				var rock_id: String = "rock_tall_a" if big and pick % 2 == 0 else ROCKS[pick % 3]
				var squash := Vector3(rock_size * 1.3, rock_size, rock_size * 1.3) if rock_id != "rock_tall_a" else Vector3.ONE * rock_size * 1.6
				scatter[rock_id].append(Transform3D(Basis(Vector3.UP, turn) * Basis.from_scale(squash), at - Vector3.UP * rock_size * 0.25))
	return {"settlements":settlements,"mesh":mesh,"triangles":triangles,"vertices":mesh.surface_get_array_len(0),"scatter":scatter,"points":points,"safe":safe,"minimum":minimum,"step":step}


## Flache freie Bauplätze reservieren, bevor Bäume und Felsen verteilt werden.
static func _settlement_plan(game, layout: HdArena, points: Array, safe: Array, step: float) -> Array:
	return preload("res://scripts/heroes/hd_city_layout.gd").plan(game,layout,points,safe,step)


static func vegetation_roots(layout: HdArena) -> Array:
	var step := 3.0 if Display.quality==Display.LOW else 2.0
	var data: Dictionary=_geometry.get(hash([layout.geometry_signature,step]),{})
	var result: Array = []
	for id in PINES:
		for transform: Transform3D in data.get("scatter",{}).get(id,[]):
			result.append({"pos":transform.origin,"radius":maxf(2.4,transform.basis.get_scale().y*.4),"grass":.14})
	return result


static func settlements(layout: HdArena) -> Array:
	var step := 3.0 if Display.quality==Display.LOW else 2.0
	return _geometry.get(hash([layout.geometry_signature,step]),{}).get("settlements",[])


## Höhe derselben Dreiecke wie im sichtbaren Gelände; kein zweites Rauschmodell.
static func ground_height(layout: HdArena, at: Vector3) -> float:
	var step := 3.0 if Display.quality == Display.LOW else 2.0
	var data: Dictionary = _geometry.get(hash([layout.geometry_signature,step]),{})
	if not data.has("points"):return 0.0
	var uv: Vector2 = (Vector2(at.x,at.z)-data.minimum)/step
	var x := floori(uv.x)
	var z := floori(uv.y)
	var points: Array = data.points
	if z<0 or z>=points.size()-1 or x<0 or x>=points[0].size()-1:return 0.0
	var fx := uv.x-x
	var fz := uv.y-z
	var tri := [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1)] if fx+fz<=1.0 else [Vector2i(x+1,z+1),Vector2i(x,z+1),Vector2i(x+1,z)]
	for p in tri:
		if not data.safe[p.y][p.x]:return 0.0
	if fx+fz<=1.0:return maxf(0,points[z][x].y*(1-fx-fz)+points[z][x+1].y*fx+points[z+1][x].y*fz)
	return maxf(0,points[z+1][x+1].y*(fx+fz-1)+points[z+1][x].y*(1-fx)+points[z][x+1].y*(1-fz))


## Nur markierte Bodeneffekte verformen; Weltpositionen/Trefferformen bleiben zweidimensional.
static func conform_effect(node: Node3D, layout: HdArena) -> void:
	if node is MeshInstance3D and bool(node.get_meta("terrain_ground", false)):
		if layout == null:
			if node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("terrain_enabled",0.0)
			return
		var step := 3.0 if Display.quality == Display.LOW else 2.0
		var data: Dictionary = _geometry.get(hash([layout.geometry_signature,step]),{})
		if data.has("points") and node.material_override is ShaderMaterial:
			if not data.has("height_texture"):
				var points: Array = data.points
				var image := Image.create(points[0].size(),points.size(),false,Image.FORMAT_RGBAF)
				for z in points.size():
					for x in points[z].size():
						image.set_pixel(x,z,Color(points[z][x].y,1.0 if data.safe[z][x] else 0.0,0,1))
				data.height_texture = ImageTexture.create_from_image(image)
			var material: ShaderMaterial = node.material_override
			material.set_shader_parameter("terrain_height",data.height_texture)
			material.set_shader_parameter("terrain_grid",Vector4(data.minimum.x,data.minimum.y,step,0))
			material.set_shader_parameter("terrain_enabled",1.0)
	for child in node.get_children():
		if child is Node3D: conform_effect(child,layout)
