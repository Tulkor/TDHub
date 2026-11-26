class_name HdFinalStyle
extends RefCounted
## Der Schlund: gemeinsame zerbrochene Kathedralenkrypta und fünf Boss-Schauplätze.
## Ausschließlich Darstellung. Die volle Arena-/Challenge-Bewegungsfläche bleibt frei;
## alle festen Randobjekte liegen außerhalb der jeweiligen Nutzungsradien.
## API: build(game,parent,data,center,boss_id), center in Weltkoordinaten.
## Rückgabe enthält CommonCrypt/ArenaTheme und Metadaten arena_theme/boss_id/arena_center.
## theme_id liest visual.theme aus heroes_bosse.json: forge/tide/rot/time/void.
## Arena-Oberkante .05, Bodenkerben .058: vorhandene Warnflächen bleiben darüber sichtbar.
## GPU-Probe: tools/heroes/boss_probe.tscn -- --arena=<id> oder --schlund=<id>.

static var _catalog: Dictionary = {}
static var _materials: Dictionary = {}
static var _rock_geometry: ArrayMesh
static var _peak_geometry: ArrayMesh
static var _terrain_geometry := {}
var _root: Node3D
var _common: Node3D
var _arena_node: Node3D
var _data: Dictionary
var _arena := Vector3.ZERO
var _radius := 13.0
var _theme := "crypt"
var _accent := Color("c8ac77")
var _groups: Dictionary = {}
var _tag := "common"
var _light_count := 0
var _court_light_count := 0
var _hub := Vector3(0, 0, 25)
var _layout: HdFinalLayout
var _center := Vector3.ZERO
var _terrain_samples: Dictionary = {}


static func theme_id(id: String) -> String:
	return str(_definition(id).get("visual", {}).get("theme", "crypt"))


static func _definition(id: String) -> Dictionary:
	if _catalog.is_empty():
		var source: Dictionary = Database.load_json(HdBossCatalog.DATA)
		for boss in source.get("bosses", []):
			_catalog[str(boss.id)] = boss
	return _catalog.get(id, {})


static func build(game, parent: Node3D, data: Dictionary, center: Vector3, boss_id: String) -> Node3D:
	var builder := HdFinalStyle.new()
	return builder._build(game, parent, data, center, boss_id)


func _build(_game, parent: Node3D, data: Dictionary, center: Vector3, boss_id: String) -> Node3D:
	_data = data
	_center = center
	_layout = _game.final.layout if _game.final and _game.final.layout else HdFinalLayout.new(data, center)
	var spine: Array = data.area.layout.spine
	_hub = (_relative(spine[0]) + _relative(spine[-1])) * 0.5
	_arena = _relative(data.arena.pos)
	_radius = float(data.arena.radius)
	_theme = theme_id(boss_id)
	_accent = Color(str(_definition(boss_id).get("visual", {}).get("accent", "c8ac77")))
	_root = Node3D.new()
	_root.name = "SchlundKrypta"
	_root.position = center
	parent.add_child(_root)
	_root.add_to_group("bollwerk_fire_sources")
	_common = Node3D.new()
	_common.name = "CommonCrypt"
	_root.add_child(_common)
	_arena_node = Node3D.new()
	_arena_node.name = "ArenaTheme"
	_root.add_child(_arena_node)
	_court()
	_crypt_masonry()
	_gate()
	for station in data.get("list", []):
		_station(station)
	_fire_details()
	_trees()
	_approach(center)
	_tag = "arena"
	_boss_arena(center)
	_arena_reliquaries()
	_flush()
	_root.set_meta("arena_theme", _theme)
	_root.set_meta("boss_id", boss_id)
	_root.set_meta("arena_center", center + _arena)
	_root.set_meta("arena_radius", _radius)
	_root.set_meta("draw_batches", _groups.size())
	_root.set_meta("hub_style", "cathedral_canyon_six_arms")
	_root.set_meta("approach_theme", _theme)
	_root.set_meta("crypt_detail_style", "gothic_reliquaries_arcades")
	return _root


func _relative(point: Array) -> Vector3:
	return Vector3(float(point[0]), 0, float(point[1]))


func _court() -> void:
	var half: Array = _data.area.half
	var stone := HdCathedral.wall_material()
	var trim := _mat("crypt_trim", Color("73717b"))
	# Nur die gemeinsame Korridor-/Raumkontur erhält eine erhöhte begehbare Steinfläche.
	var caps := {}
	var segment_index := 0
	for segment in _layout.floor_segments():
		var from: Vector3 = segment.from
		var to: Vector3 = segment.to
		var width := float(segment.width)
		var delta := to - from
		var yaw := atan2(delta.x, delta.z)
		_place("box", HdCathedral.floor_material(), Vector3(width, 0.65, delta.length()), (from + to) * 0.5 + Vector3(0, -0.36 - segment_index * 0.0004, 0), yaw)
		_floor_route(from, to, width * 0.6, HdCathedral.path_material(), segment_index * 0.0003)
		segment_index += 1
		for point in [from, to]:
			var key := "%s:%s" % [point, width]
			if not caps.has(key):
				caps[key] = true
				_place("cylinder", HdCathedral.floor_material(), Vector3(width * 0.5, 0.65, width * 0.5), point + Vector3(0, -0.37, 0))
	for room in _layout.rooms():
		var radius := float(room.radius)
		_place("cylinder", HdCathedral.floor_material(), Vector3(radius, 0.65, radius), room.pos + Vector3(0, -0.357, 0))
	# Dunkler Tiefengrund liegt deutlich unter den Wegen; kein rechteckiges Plateau.
	var depth := _mat("canyon_depth", Color("0b1018"))
	depth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	depth.disable_fog = true
	_place("box", depth, Vector3(float(half[0]) * 8.0, 0.4, float(half[1]) * 8.0), Vector3(0, -8.5, 0))
	_rock_sea()
	# Versetzte Pfeiler und Wächter nur auf sicheren Felsvorsprüngen neben dem Mittelschiff.
	for side in [-1.0, 1.0]:
		for shift in [-8.0, 8.0, 18.0]:
			var p := _hub + Vector3(side * 18.5, 0, shift)
			if not _layout.inside(_center + p, 2.3):
				_guardian(p, -side * PI * 0.5, 1.05)
				_warm_light(p + Vector3(0, 4, 2), Color("f4c98c"), 17.0)
				break
	for segment in _layout.floor_segments():
		var length: float = segment.from.distance_to(segment.to)
		var tangent: Vector3 = (segment.to - segment.from).normalized()
		var normal := Vector3(-tangent.z, 0, tangent.x)
		for i in maxi(1, floori(length / 16.0)):
			var p: Vector3 = segment.from.lerp(segment.to, (i + 0.5) / maxi(1.0, floorf(length / 16.0)))
			for side in [-1.0, 1.0]:
				var edge: Vector3 = p + normal * side * (float(segment.width) * 0.5 + 1.8)
				if not _layout.inside(_center + edge, 1.5):
					_column(edge, 2.5, stone, trim)
	# Zwei Kerzenwachen markieren die Ankunft, abseits der Ankunftsfläche.
	var start := _relative(_data.start)
	for side in [-1.0, 1.0]:
		_brazier(start + Vector3(side * 14.0, 0, 0), Color("e4bb7c"), false)


## Niedrige Arkaden und Grabrelikte liegen vollständig neben der begehbaren Kontur.
## Nur vorhandene Material-/Meshgruppen; keine Kollision, Lichter oder Prozesse.
func _crypt_masonry() -> void:
	var stone := HdCathedral.wall_material()
	var iron := _mat("crypt_wrought_iron", Color("242932"), 0, 0.65)
	var pale := _mat("crypt_carved_limestone", Color("6c6e79"))
	var soot := _mat("crypt_recess", Color("11151e"))
	var segment_index := 0
	for segment in _layout.floor_segments():
		var tangent: Vector3 = (segment.to - segment.from).normalized()
		var normal := Vector3(-tangent.z, 0, tangent.x)
		var length: float = segment.from.distance_to(segment.to)
		var bays := maxi(1, floori(length / (18.0 if Display.quality == Display.LOW else 13.0)))
		for index in bays:
			var middle: Vector3 = segment.from.lerp(segment.to, (index + 0.5) / float(bays))
			for side in [-1.0, 1.0]:
				var p: Vector3 = middle + normal * side * (float(segment.width) * 0.5 + 1.25)
				# Overlapping branch junctions keep their complete width, including foot clearance.
				if _layout.inside(_center + p, 1.05) or _layout.inside(_center + p - tangent * 4.4, 1.05) or _layout.inside(_center + p + tangent * 4.4, 1.05):
					continue
				var yaw := atan2(tangent.x, tangent.z)
				_place("box", stone, Vector3(0.7, 0.35, 8.5), p + Vector3.UP * 0.17, yaw)
				for end in [-1.0, 1.0]:
					var post: Vector3 = p + tangent * end * 4.0
					_place("box", stone, Vector3(0.8, 2.6, 0.8), post - Vector3.UP * 1.2, yaw)
					_place("box", stone, Vector3(0.92, 1.1, 0.92), post + Vector3.UP * 0.55, yaw)
					_place("box", pale, Vector3(1.05, 0.14, 1.05), post + Vector3.UP * 1.14, yaw)
					_place("spire", iron, Vector3(0.22, 0.75, 0.22), post + Vector3.UP * 1.6, PI * 0.25)
				for arch in 3:
					var a := p + tangent * (arch - 1) * 2.45
					_beam(a - tangent * 1.05 + Vector3.UP * 0.4, a - tangent * 1.05 + Vector3.UP * 1.15, 0.09, iron)
					_beam(a + tangent * 1.05 + Vector3.UP * 0.4, a + tangent * 1.05 + Vector3.UP * 1.15, 0.09, iron)
					_beam(a - tangent * 1.05 + Vector3.UP * 1.15, a + Vector3.UP * 1.85, 0.095, iron)
					_beam(a + tangent * 1.05 + Vector3.UP * 1.15, a + Vector3.UP * 1.85, 0.095, iron)
				if (index + segment_index) % 3 == 0:
					var tomb: Vector3 = p + normal * side * 3.1
					if not _layout.inside(_center + tomb, 2.8):
						_reliquary(tomb, atan2(-normal.x * side, -normal.z * side), stone, pale, soot)
		segment_index += 1


func _reliquary(p: Vector3, yaw: float, stone: Material, pale: Material, shadow: Material) -> void:
	_local("box", stone, Vector3(2.1, 2.5, 3.9), p, Vector3(0, -1.2, 0), yaw)
	_local("box", stone, Vector3(2.1, 0.28, 3.9), p, Vector3(0, 0.14, 0), yaw)
	_local("box", pale, Vector3(1.75, 0.5, 3.55), p, Vector3(0, 0.53, 0), yaw)
	_local("box", stone, Vector3(1.95, 0.2, 3.7), p, Vector3(0, 0.87, 0), yaw)
	# A carved recumbent effigy and sealed eye sockets, rather than repeated plain boxes.
	_local("spire", stone, Vector3(0.85, 0.32, 2.1), p, Vector3(0, 1.08, 0.3), yaw + PI * 0.25)
	_local("sphere", pale, Vector3(0.25, 0.25, 0.28), p, Vector3(0, 1.12, -1.08), yaw)
	for side in [-1.0, 1.0]:
		_local("sphere", shadow, Vector3(0.055, 0.045, 0.04), p, Vector3(side * 0.095, 1.3, -1.18), yaw)
		_local("box", shadow, Vector3(0.055, 0.08, 1.8), p, Vector3(side * 0.8, 0.6, 0), yaw)
	_local("box", pale, Vector3(0.1, 0.07, 1.5), p, Vector3(0, 1.3, 0.2), yaw)
	_local("box", pale, Vector3(0.8, 0.07, 0.1), p, Vector3(0, 1.3, -0.1), yaw)


func _rock_sea() -> void:
	var half: Array = _data.area.half
	var basalt := _basalt_material()
	var flank := basalt
	var rng := RandomNumberGenerator.new()
	rng.seed = 961734
	# Drei breite Hauptmassive bilden eine erkennbare Bergsilhouette hinter der Arena.
	for peak in [[Vector3(-66, 0, -99), 22.0, 48.0], [Vector3(0, 0, -126), 20.0, 62.0], [Vector3(70, 0, -101), 25.0, 43.0]]:
		_mountain_mass(peak[0], peak[1], peak[2], basalt, flank, rng)
	_mountain_terrain(half, basalt)


func _mountain_terrain(half: Array, material: Material) -> void:
	var key := hash([_data.area.layout, _data.arena, half, "smooth_normals"])
	if not _terrain_geometry.has(key):
		var extent := Vector2(float(half[0]) + 45, float(half[1]) + 45)
		var step := 3.0
		var cols := ceili(extent.x * 2 / step)
		var rows := ceili(extent.y * 2 / step)
		var points: Array = []
		var peaks := [[Vector3(-66, 0, -99), 40.0, 43.0], [Vector3(0, 0, -126), 36.0, 57.0], [Vector3(70, 0, -101), 44.0, 38.0]]
		for i in 24:
			var angle := TAU * i / 24.0
			var p := Vector3(cos(angle) * (106 + sin(i * 1.71) * 6), 0, sin(angle) * (114 + cos(i * 0.91) * 5))
			var height := 17.0 + pow(sin(i * 1.53), 2) * 10 + maxf(0, -sin(angle)) * 6
			peaks.append([p, 37.0 + fmod(i * 7.1, 8.0), height])
		for z in rows + 1:
			var row := PackedVector3Array()
			for x in cols + 1:
				var p := Vector3(-extent.x + x * step, 0, -extent.y + z * step)
				var distance := p.distance_to(_layout.constrain(_center + p, 0) - _center)
				var ellipse := Vector2(p.x / 116.0, p.z / 128.0).length()
				var foothills := 4.0 + sin(p.x * 0.09 + p.z * 0.06) * 2 + cos(p.z * 0.13) * 1.5
				var ridge := lerpf(-9.0, foothills, 1.0 - smoothstep(0.85, 1.15, ellipse))
				for peak in peaks:
					var t := clampf(1.0 - p.distance_to(peak[0]) / float(peak[1]), 0, 1)
					if t > 0:
						ridge = maxf(ridge, float(peak[2]) * pow(t, 1.25))
				var edge := maxf(absf(p.x) / extent.x, absf(p.z) / extent.y)
				var height := lerpf(-2.2, ridge, smoothstep(6.0, 17.0, distance))
				p.y = lerpf(-9.0, height, 1.0 - smoothstep(0.86, 1.0, edge))
				row.append(p)
			points.append(row)
		var normals: Array = []
		for z in rows + 1:
			var row := PackedVector3Array()
			for x in cols + 1:
				var dx: Vector3 = points[z][mini(x + 1, cols)] - points[z][maxi(x - 1, 0)]
				var dz: Vector3 = points[mini(z + 1, rows)][x] - points[maxi(z - 1, 0)][x]
				row.append(dz.cross(dx).normalized())
			normals.append(row)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for z in rows:
			for x in cols:
				for tri in [[Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1)], [Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]]:
					for index in tri:
						st.set_normal(normals[index.y][index.x])
						st.add_vertex(points[index.y][index.x])
		if _terrain_geometry.size() >= 3:
			_terrain_geometry.clear()
		_terrain_geometry[key] = {"mesh":st.commit(), "points":points, "extent":extent, "step":step}
	_terrain_samples = _terrain_geometry[key]
	var terrain := MeshInstance3D.new()
	terrain.name = "ContinuousMountainRange"
	terrain.mesh = _terrain_samples.mesh
	terrain.material_override = material
	_common.add_child(terrain)


func _mountain_mass(p: Vector3, radius: float, height: float, basalt: Material, flank: Material, rng: RandomNumberGenerator) -> void:
	if _layout.inside(_center + p, radius * 1.3 + 1.0):
		return
	_place("mountain", basalt, Vector3(radius, height, radius * 0.85), p - Vector3.UP * 5, rng.randf() * TAU)
	for side in [-1.0, 1.0]:
		var shoulder := p + Vector3(side * radius * 0.45, 0, radius * 0.12)
		var ridge_height := height * (0.53 if side < 0 else 0.68)
		_place("mountain", flank if side < 0 else basalt, Vector3(radius * 0.7, ridge_height, radius * 0.68), shoulder - Vector3.UP * 5, rng.randf() * TAU)


static func _basalt_material() -> ShaderMaterial:
	if not _materials.has("snow_basalt"):
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/shaders/hd_basalt_snow.gdshader")
		material.set_shader_parameter("rock_albedo", load("res://assets/textures/rock/rock_face_03_diff_1k.jpg"))
		material.set_shader_parameter("rock_normal_map", load("res://assets/textures/rock/rock_face_03_nor_gl_1k.jpg"))
		material.set_shader_parameter("rock_roughness", load("res://assets/textures/rock/rock_face_03_rough_1k.jpg"))
		material.set_shader_parameter("rock_specular", load("res://assets/textures/rock/rock_face_03_specular_1k.png"))
		material.set_shader_parameter("snow_line", 25.0)
		material.set_shader_parameter("snow_amount", 0.85)
		_materials["snow_basalt"] = material
	return _materials["snow_basalt"]


func _terrain_y(p: Vector3) -> float:
	var extent: Vector2 = _terrain_samples.extent
	var step: float = _terrain_samples.step
	var points: Array = _terrain_samples.points
	var gx := clampf((p.x + extent.x) / step, 0, points[0].size() - 1.001)
	var gz := clampf((p.z + extent.y) / step, 0, points.size() - 1.001)
	var x := floori(gx)
	var z := floori(gz)
	return lerpf(lerpf(points[z][x].y, points[z][x + 1].y, gx - x), lerpf(points[z + 1][x].y, points[z + 1][x + 1].y, gx - x), gz - z)


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 30771
	var count := 0
	for attempt in 700:
		if count >= 28:
			break
		var p := Vector3(rng.randf_range(-96, 96), 0, rng.randf_range(-77, 87))
		if _layout.inside(_center + p, 4):
			continue
		var distance := p.distance_to(_layout.constrain(_center + p, 0) - _center)
		if distance > 18:
			continue
		p.y = _terrain_y(p)
		if p.y < 0 or p.y > 16 or absf(_terrain_y(p + Vector3.RIGHT) - p.y) > 1.3 or absf(_terrain_y(p + Vector3.FORWARD) - p.y) > 1.3:
			continue
		var path := "res://assets/models/nature/pine_%d.glb" % ([1, 3, 5][count % 3])
		var tree: Node3D = load(path).instantiate()
		var bounds := ModelLoader.aabb(tree, Transform3D.IDENTITY)
		var scale_factor := rng.randf_range(5.5, 9.5) / maxf(bounds.size.y, 0.01)
		tree.scale = Vector3.ONE * scale_factor
		tree.rotation.y = rng.randf() * TAU
		tree.position = p - Vector3.UP * bounds.position.y * scale_factor
		_common.add_child(tree)
		HdTerrain.soil_on_slope(_common, p, maxf(2.2, scale_factor * bounds.size.x * .6), _terrain_y)
		for mesh: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original = mesh.mesh.surface_get_material(surface)
				if original is BaseMaterial3D:
					var key := "pine_%d" % original.get_instance_id()
					if not _materials.has(key):
						var dark: BaseMaterial3D = original.duplicate()
						dark.albedo_color *= Color(0.58, 0.66, 0.62)
						dark.roughness = 0.94
						_materials[key] = dark
					mesh.set_surface_override_material(surface, _materials[key])
		count += 1
	_root.set_meta("pine_count", count)


func _fire_details() -> void:
	for z in [-34.0, -7.0, 21.0, 54.0]:
		for side in [-1.0, 1.0]:
			var p := Vector3(side * 8.5, 0, z)
			_brazier(p, Color("ffad57"), false)
			_warm_light(p + Vector3.UP * 2.3, Color("ffbd78"), 18.0)
	for room in _layout.rooms():
		if str(room.id) == "boss":
			continue
		var axis := _layout.arm_axis(str(room.id))
		var p: Vector3 = room.pos - axis * 4.0 + Vector3(-axis.z, 0, axis.x) * 7.5
		_place("cylinder", _mat("torch_wood", Color("332a24")), Vector3(0.16, 3.1, 0.16), p + Vector3.UP * 1.55)
		_ring(p + Vector3.UP * 2.85, 0.28, _mat("torch_iron", Color("242830"), 0, 0.35), Vector3.ZERO)
		_flames(p + Vector3.UP * 3.35, 0.65)
		_warm_light(p + Vector3.UP * 3.5, Color("ffbe7c"), 16.0)


func _flames(p: Vector3, size: float) -> void:
	var sources: Array = _root.get_meta("fire_sources",[])
	sources.append(p)
	_root.set_meta("fire_sources",sources)
	if not _materials.has("flames"):
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/shaders/hd_fire.gdshader")
		_materials["flames"] = material
	for angle in [0.0, PI * 0.5]:
		_place("fire", _materials["flames"], Vector3(size, size * 1.6, size), p, angle)


func _gate() -> void:
	var p := _relative(_data.gate.pos)
	var stone := HdCathedral.wall_material()
	var gold := _mat("gate_metal", Color("9b845d"), 0, 0.6)
	for side in [-1.0, 1.0]:
		var foot := p + Vector3(side * 8.0, 0, 0)
		_column(foot, 8.3, stone, gold)
		_place("spire", stone, Vector3(1.1, 3.8, 1.1), foot + Vector3.UP * 10.2, PI * 0.25)
		_beam(foot + Vector3.UP * 8.2, p + Vector3(0, 12.0, 0), 0.42, stone)
		_beam(foot + Vector3(side * 0.45, 9.0, 0), p + Vector3(0, 13.0, 0), 0.16, gold)
		_guardian(p + Vector3(side * 15.5, 0, 4.5), -side * 0.35, 0.86)
	# Leere Toröffnung: keine leuchtende Wand vor der Kampfzone.
	_place("spire", _mat("gate_gem_" + _theme, _accent.lerp(Color("e2cf9d"), 0.5), 0.5), Vector3(0.5, 1.6, 0.5), p + Vector3.UP * 13.4, PI * 0.25)


func _station(definition: Dictionary) -> void:
	var p := _relative(definition.pos)
	var color := Color(str(definition.get("color", "d6b37a"))).lerp(Color("c8b78e"), 0.72)
	var material := _mat("station_" + str(definition.id), color, 0.12)
	# Geweihter Platz mit radialen Kerben; das Triggerzentrum bleibt nur ein Bodenzeichen.
	_place("cylinder", HdCathedral.path_material(), Vector3(5.8, 0.04, 5.8), p + Vector3.UP * 0.005)
	for i in 8:
		var angle := TAU * i / 8.0
		_place("box", material, Vector3(0.10, 0.035, 0.5), p + Vector3(sin(angle) * 3.0, 0.035, cos(angle) * 3.0), angle)
	# Große, vertiefte Seitenschiffe. Beim Glutpfad und Fluchschrein bleibt die Hauptachse frei.
	var axis := _layout.arm_axis(str(definition.id))
	var arm := _layout.arm(str(definition.id))
	var alcove := p + axis * (float(arm.get("radius", 15.5)) - 4.0)
	var yaw := atan2(-axis.x, -axis.z)
	var stone := HdCathedral.wall_material()
	var dark := _mat("alcove_shadow", Color("171e2b"))
	var pale := _mat("alcove_trim", Color("777985"))
	_local("box", stone, Vector3(15.5, 7.0, 1.5), alcove, Vector3(0, 3.5, -2.5), yaw)
	_local("box", dark, Vector3(7.0, 6.2, 0.12), alcove, Vector3(0, 3.1, -1.68), yaw)
	for i in 5:
		_local("box", pale, Vector3(0.12, 3.9, 0.15), alcove, Vector3((i - 2) * 0.8, 3.5, -1.55), yaw)
		_local("spire", stone, Vector3(1.0, 2.5 + absf(i - 2) * 0.5, 1.0), alcove, Vector3((i - 2) * 3.1, 8.2, -2.5), yaw + PI * 0.25)
	# Stone ribs, a rose window and inset tracery make the challenge apse read as a ruined church.
	_pointed_niche(alcove + Vector3(0, 0, -1.35).rotated(Vector3.UP, yaw), yaw, 7.2, 8.7, stone, pale)
	var rose := alcove + Vector3(0, 6.8, -1.18).rotated(Vector3.UP, yaw)
	_ring(rose, 1.05, pale, Vector3(PI * 0.5, yaw, 0))
	for spoke in 8:
		var angle := spoke * TAU / 8.0
		var edge := rose + Vector3(sin(angle) * 0.92, cos(angle) * 0.92, 0).rotated(Vector3.UP, yaw)
		_beam(rose, edge, 0.07, material)
	for side in [-1.0, 1.0]:
		for tier in 3:
			_local("box", stone, Vector3(0.85 - tier * 0.13, 1.3, 1.6 - tier * 0.28), alcove, Vector3(side * 6.9, 0.65 + tier * 1.15, -0.6 - tier * 0.22), yaw)
	for side in [-1.0, 1.0]:
		var foot := alcove + Vector3(side * 4.1, 0, 0).rotated(Vector3.UP, yaw)
		_column(foot, 7.4, stone, pale)
		_beam(foot + Vector3.UP * 7.3, alcove + Vector3.UP * 10.5, 0.38, stone)
		_beam(foot + Vector3(0, 0, 0.12).rotated(Vector3.UP, yaw) + Vector3.UP * 7.15, alcove + Vector3(0, 10.2, 0.12).rotated(Vector3.UP, yaw), 0.12, material)
		_guardian(alcove + Vector3(side * 6.3, 0, 1.0).rotated(Vector3.UP, yaw), yaw, 0.67)
		_brazier(alcove + Vector3(side * 3.1, 0, 2.6).rotated(Vector3.UP, yaw), Color("e7bc7d"), false)
	_local("box", stone, Vector3(3.2, 0.9, 1.4), alcove, Vector3(0, 0.45, -0.9), yaw)
	_local("spire", material, Vector3(0.42, 1.8, 0.42), alcove, Vector3(0, 2.0, -0.9), yaw + PI * 0.25)
	# Eigenes Relikt je Challenge gibt den fünf Abzweigen auch ohne Text eine Silhouette.
	match str(definition.kind):
		"echos":
			for i in 3:
				_local("spire", pale, Vector3(0.35, 1.5 + i * 0.3, 0.35), alcove, Vector3((i - 1) * 1.2, 4.6, -1.3), yaw)
		"siegel":
			for i in 4:
				_local("box", material, Vector3(0.55, 0.55, 0.35), alcove, Vector3((i - 1.5) * 1.1, 4.2, -1.3), yaw + PI * 0.25)
		"glutpfad":
			_local("sphere", _mat("altar_ember", Color("d99352"), 0.8), Vector3(0.8, 0.6, 0.5), alcove, Vector3(0, 4.4, -1.3), yaw)
		"halten":
			_ring(alcove + Vector3(0, 4.5, -1.3).rotated(Vector3.UP, yaw), 1.1, material, Vector3(PI * 0.5, yaw, 0))
		"wagnis":
			_local("spire", material, Vector3(0.9, 1.4, 0.9), alcove, Vector3(0, 4.8, -1.3), yaw + PI * 0.25)
		"jagd":
			for side in [-1.0, 1.0]:
				_local("spire", material, Vector3(0.4, 1.7, 0.4), alcove, Vector3(side * 0.8, 4.7, -1.3), yaw + PI * 0.25)


func _local(kind: String, material: Material, size: Vector3, origin: Vector3, offset: Vector3, yaw: float) -> void:
	_place(kind, material, size, origin + offset.rotated(Vector3.UP, yaw), yaw)


func _floor_route(from: Vector3, to: Vector3, width: float, material: Material, elevation := 0.0) -> void:
	var delta := to - from
	var yaw := atan2(delta.x, delta.z)
	var middle := (from + to) * 0.5 + Vector3.UP * elevation
	_place("box", material, Vector3(width, 0.018, delta.length()), middle + Vector3(0, -0.005, 0), yaw)
	var trim := _mat("route_brass", Color("8a795b"), 0, 0.3)
	for side in [-1.0, 1.0]:
		var edge := Vector3(side * (width * 0.5 - 0.22), 0, 0).rotated(Vector3.UP, yaw)
		_place("box", trim, Vector3(0.10, 0.018, delta.length()), middle + edge + Vector3.UP * 0.012, yaw)


func _guardian(p: Vector3, yaw: float, scale: float) -> void:
	var stone := _mat("guardian_basalt", Color("353e4c"))
	var shadow := _mat("guardian_hood", Color("171e2c"))
	var metal := _mat("guardian_brass", Color("a18b64"), 0, 0.45)
	_local("box", stone, Vector3(3.3, 0.8, 3.1) * scale, p, Vector3.UP * 0.4 * scale, yaw)
	_local("spire", stone, Vector3(1.5, 4.6, 1.5) * scale, p, Vector3.UP * 3.0 * scale, yaw + PI * 0.25)
	_local("box", stone, Vector3(2.8, 1.0, 1.4) * scale, p, Vector3.UP * 4.4 * scale, yaw)
	_local("sphere", shadow, Vector3(0.7, 0.8, 0.7) * scale, p, Vector3(0, 5.55, 0) * scale, yaw)
	_local("spire", stone, Vector3(1.0, 2.0, 1.0) * scale, p, Vector3(0, 6.1, -0.2) * scale, yaw + PI * 0.25)
	for side in [-1.0, 1.0]:
		var hand := p + Vector3(side * 0.65, 3.5, 1.1).rotated(Vector3.UP, yaw) * scale
		_beam(p + Vector3(side * 1.2, 4.4, 0).rotated(Vector3.UP, yaw) * scale, hand, 0.4 * scale, stone)
	_local("box", metal, Vector3(0.17, 4.7, 0.17) * scale, p, Vector3(0, 3.5, 1.1) * scale, yaw)
	_local("spire", metal, Vector3(0.48, 1.1, 0.48) * scale, p, Vector3(0, 6.15, 1.1) * scale, yaw + PI * 0.25)


func _warm_light(p: Vector3, color: Color, reach: float) -> void:
	if _court_light_count >= (10 if Display.quality == Display.LOW else 18):
		return
	var light := OmniLight3D.new()
	light.position = p
	light.light_color = color
	light.light_energy = 2.6
	light.omni_range = reach
	light.shadow_enabled = false
	_common.add_child(light)
	_court_light_count += 1


func _approach(world_center: Vector3) -> void:
	var gate := _relative(_data.gate.pos)
	_floor_route(_hub, gate, 10.0, _approach_floor(world_center), 0.025)
	var accent := _mat("approach_accent_" + _theme, _accent, 0.55)
	var metal := _mat("approach_metal", Color("80705a"), 0, 0.65)
	var dark := _mat("approach_dark", Color("232c3a"))
	# Struktur bricht erst auf den letzten Metern zum Tor aus der gemeinsamen Krypta hervor.
	for side in [-1.0, 1.0]:
		for i in 3:
			var p := Vector3(side * 9.8, 0, lerpf(gate.z + 8.0, _hub.z - 5.0, i / 2.0))
			if not _allowed(p, 1.0):
				continue
			match _theme:
				"forge":
					_column(p, 3.5, dark, metal)
					for k in 3:
						_ring(p + Vector3(0, 1.4 + k * 0.65, side * 0.7), 0.38, metal, Vector3(PI * 0.5, k % 2 * PI * 0.5, 0))
					_brazier(p + Vector3(-side * 1.7, 0, 0), _accent, false)
				"tide":
					_place("box", dark, Vector3(2.4, 0.8, 2.0), p + Vector3.UP * 0.4, side * 0.12)
					_place("spire", accent, Vector3(0.4, 1.8, 0.4), p + Vector3.UP * 1.7, PI * 0.25)
					_ring(p + Vector3.UP * 1.1, 1.15, metal, Vector3.ZERO)
				"rot":
					for k in 3:
						var q := p + Vector3(sin(k * 2.4), 0, cos(k * 2.4))
						_beam(q, q + Vector3(side * 0.6, 2.5 + k * 0.4, 0.5), 0.2, dark)
						_place("sphere", accent, Vector3(0.55, 0.16, 0.55), q + Vector3.UP * (1.4 + k * 0.3))
				"time":
					_place("box", dark, Vector3(1.2, 1.0, 1.2), p + Vector3.UP * 0.5, side * 0.2)
					_place("spire", accent, Vector3(0.3, 1.3, 0.3), p + Vector3.UP * 2.4, PI * 0.25)
					_ring(p + Vector3.UP * 1.2, 0.9, metal, Vector3(PI * 0.5, 0, 0.2))
				"void":
					_place("spire", dark, Vector3(0.9, 2.7, 0.9), p + Vector3.UP * 2.4, i * 0.7)
					_place("spire", accent, Vector3(0.23, 0.9, 0.23), p + Vector3.UP * 4.1, PI * 0.25)
	# Leuchtfeuer direkt vor den beiden Torwachen bilden den letzten warmen Orientierungspunkt.
	for side in [-1.0, 1.0]:
		var p := gate + Vector3(side * 7.7, 0, 5.7)
		_brazier(p, Color("e8bb79"), false)
		_warm_light(p + Vector3.UP * 3.0, Color("ebbb82"), 13.0)
	if _theme == "forge" or _theme == "void":
		var rubble := _mat("approach_flat_rubble", Color("343542"))
		for i in 17:
			var side := -1.0 if i % 2 else 1.0
			var p := Vector3(side * (1.6 + fmod(i * 0.73, 2.5)), 0.018, lerpf(gate.z + 3.0, _hub.z - 3.0, fmod(i * 0.193, 1.0)))
			# Flache versetzte Bruchschollen: unter .05, keine neue Stufe oder Kollision.
			_place("box", rubble, Vector3(0.35 + fmod(i * 0.21, 0.6), 0.022, 0.45 + fmod(i * 0.17, 0.7)), p, i * 0.87)


func _approach_floor(world_center: Vector3) -> ShaderMaterial:
	var key := "approach_floor_%s_%s" % [_theme, world_center]
	if _materials.has(key):
		return _materials[key]
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform vec3 court_center;
uniform vec2 approach_extent;
uniform vec4 accent : source_color;
uniform int motif=0;
varying vec3 world_position;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=(world_position-court_center).xz;
 float progress=1.0-smoothstep(approach_extent.x,approach_extent.y,p.y);
 vec2 uv=p*0.45;vec2 f=fract(uv);
 float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
 float grout=1.0-smoothstep(0.012,0.035,edge);
 vec3 base=vec3(0.29,0.31,0.36)*(0.83+hash2(floor(uv))*0.22)*(1.0-grout*0.38);
 float bend=sin(p.y*0.33)*1.15+sin(p.y*1.17)*0.23;
 float segment=floor(p.y/2.8);float along=fract(p.y/2.8);
 float broken=mix((hash2(vec2(segment,8.7))-0.5)*2.9,(hash2(vec2(segment+1.0,8.7))-0.5)*2.9,along);
 float spine=abs(p.x-broken);
 float fork=floor((p.y+42.0)/7.0);float fork_z=mod(p.y+42.0,7.0);
 float direction=hash2(vec2(fork,19.3))>0.5?1.0:-1.0;
 float fork_base=(hash2(vec2(floor((fork*7.0-42.0)/2.8),8.7))-0.5)*2.9;
 float branch=abs(p.x-fork_base-direction*(fork_z*0.65+abs(sin(fork_z*2.1))*0.16));
 if(fork_z>4.8){branch=20.0;}
 float fissure=min(spine,branch);
 float jagged=hash2(floor(p*6.0))*0.065;
 float trench=1.0-smoothstep(0.13+jagged,0.39+jagged,fissure);
 float light=(1.0-smoothstep(0.025,0.07,fissure))*progress;
 if(motif==2){float water=1.0-smoothstep(0.26,0.68,min(abs(p.x-bend-1.8),abs(p.x+bend+1.8)));base=mix(base,vec3(0.10,0.24,0.29),water*progress*0.83);light=water*0.16*progress;trench=water*0.28;}
 if(motif==3){float vein=abs(sin(p.x*1.8+p.y*0.43+sin(p.y*0.6)));light=(1.0-smoothstep(0.05,0.16,vein))*progress*0.55;trench=(1.0-smoothstep(0.12,0.3,vein))*0.6;base=mix(base,vec3(0.20,0.25,0.18),progress*0.45);}
 if(motif==4){vec2 q=vec2(p.x-sin(floor(p.y/7.0))*0.8,mod(p.y+3.5,7.0)-3.5);float circle=abs(length(q)-2.6);float hand=min(abs(q.x+q.y*0.5),abs(q.x-q.y*0.8));light=(1.0-smoothstep(0.035,0.10,min(circle,hand)))*progress*0.7;trench=(1.0-smoothstep(0.10,0.24,circle))*0.7;base=mix(base,vec3(0.39,0.36,0.40),progress*0.35);}
 if(motif==5){light=(1.0-smoothstep(0.03,0.14,fissure))*progress;trench=1.0-smoothstep(0.14,0.4,fissure);base=mix(base,vec3(0.16,0.16,0.24),progress*0.6);}
 float depth=(motif==1||motif==5)?0.10:0.30;
 ALBEDO=mix(base,base*depth,trench*progress*0.96);ALBEDO=mix(ALBEDO,accent.rgb*0.65,light*0.7);
 EMISSION=accent.rgb*light*0.3;ROUGHNESS=motif==2?0.32:0.85;METALLIC=motif==4?0.25:0.04;
 NORMAL=terrain_relief_normal(NORMAL,VERTEX,-grout*0.02-trench*progress*0.035+terrain_grain(world_position*4.0)*0.006,0.45);
 SPECULAR=mix(motif==2?0.48:0.30,0.17,grout);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("court_center", world_center)
	material.set_shader_parameter("approach_extent", Vector2(_relative(_data.gate.pos).z, _hub.z))
	material.set_shader_parameter("accent", _accent)
	material.set_shader_parameter("motif", {"forge": 1, "tide": 2, "rot": 3, "time": 4, "void": 5}.get(_theme, 0))
	_materials[key] = material
	return material


func _boss_arena(world_center: Vector3) -> void:
	var stone := HdCathedral.wall_material()
	var metal := _mat("arena_metal_" + _theme, Color("82786b"), 0, 0.55)
	var dark := _mat("arena_dark_" + _theme, Color("121724"))
	var accent := _mat("arena_accent_" + _theme, _accent, 0.5)
	# Eine vollständige, ebene Arena. Der Abgrund ist nur das Bild unter dem Rand.
	_place("cylinder", dark, Vector3(_radius + 4.4, 1.3, _radius + 4.4), _arena + Vector3(0, -1.05, 0))
	_place("cylinder", _arena_floor(world_center + _arena), Vector3(_radius + 0.45, 0.18, _radius + 0.45), _arena + Vector3(0, -0.04, 0))
	for i in 32:
		var a := TAU * i / 32.0
		_place("box", metal, Vector3(0.12, 0.012, 0.5 if i % 4 else 0.85), _arena + Vector3(sin(a) * (_radius - 0.8), 0.052, cos(a) * (_radius - 0.8)), a)
	match _theme:
		"forge":
			for i in 6:
				var a := TAU * i / 6.0 + PI / 6.0
				var p := _rim(a, 4.0)
				_place("box", stone, Vector3(3.2, 3.8, 2.4), p + Vector3.UP * 1.9, a)
				_place("box", accent, Vector3(1.8, 1.3, 0.08), p + Vector3(0, 1.6, -1.24).rotated(Vector3.UP, a), a)
				_place("spire", metal, Vector3(2.5, 2.6, 2.5), p + Vector3.UP * 5.1, a + PI * 0.25)
				# Unterbrochene schwere Ketten hängen außerhalb der Kampffläche.
				for k in 4:
					_ring(p + Vector3(1.5, 2.3 + k * 0.7, 0).rotated(Vector3.UP, a), 0.4, metal, Vector3(PI * 0.5, a + k % 2 * PI * 0.5, 0))
				_brazier(p + Vector3(0, 0, 2).rotated(Vector3.UP, a), _accent, i % 2 == 0)
		"tide":
			_place("cylinder", _mat("crypt_water", Color("173943"), 0.08, 0.4), Vector3(_radius + 5, 0.08, _radius + 5), _arena + Vector3(0, -0.49, 0))
			for i in 8:
				var a := TAU * i / 8.0
				var p := _rim(a, 4.0)
				_column(p, 3.6, stone, metal)
				for side in [-1.0, 1.0]:
					_beam(p + Vector3(side * 0.3, 3.3, 0), p + Vector3(side * 1.2, 5.4, -0.2), 0.21, accent)
				_ring(p + Vector3.UP * 3.5, 0.8, accent, Vector3(PI * 0.5, a, 0))
				_brazier(p + Vector3(1.6, 0, 0).rotated(Vector3.UP, a), _accent, i % 3 == 0)
		"rot":
			for i in 13:
				var a := TAU * i / 13.0
				var p := _rim(a, 3.5)
				var wood := _mat("crypt_roots", Color("394235"))
				for side in [-1.0, 1.0]:
					_beam(p + Vector3(side, 0, 0), p + Vector3(side * 1.4, 4.6, 0.4), 0.35, wood)
					_place("spire", wood, Vector3(0.6, 2.2, 0.6), p + Vector3(side * 1.4, 5.1, 0.4), a)
				for k in 3:
					var offset := Vector3(sin(k * 2.3) * 1.4, 0, cos(k * 2.3) * 1.4)
					_place("cylinder", wood, Vector3(0.15, 1.2 + k * 0.3, 0.15), p + offset + Vector3.UP * (0.6 + k * 0.15))
					_place("sphere", accent, Vector3(0.7 + k * 0.12, 0.23, 0.7 + k * 0.12), p + offset + Vector3.UP * (1.2 + k * 0.3))
		"time":
			for i in 12:
				var a := TAU * i / 12.0
				var p := _rim(a, 3.8)
				_place("box", stone, Vector3(1.0, 3.5, 1.0), p + Vector3.UP * 1.75, a)
				_place("spire", accent, Vector3(0.65, 2.1, 0.65), p + Vector3.UP * 5.3, a + PI * 0.25)
				if i % 3 != 0:
					var q := _rim(a + TAU / 12.0, 3.8)
					_beam(p + Vector3.UP * 6.7, q + Vector3.UP * 6.7, 0.15, metal)
				_ring(p + Vector3.UP * 3.7, 0.8, metal, Vector3(PI * 0.5, a, 0))
		"void":
			for i in 11:
				var a := TAU * i / 11.0
				var p := _rim(a, 4.0)
				_place("spire", dark, Vector3(1.7, 7.0 + fmod(i * 1.7, 2.7), 1.7), p + Vector3.UP * 4.0, a)
				_place("spire", accent, Vector3(0.45, 2.2, 0.45), p + Vector3.UP * 7.7, a + PI * 0.25)
				_place("box", stone, Vector3(2.4, 1.0, 1.8), p + Vector3.UP * 0.3, a + 0.3)
				if i % 3 == 0:
					_ring(p + Vector3.UP * 4.1, 1.1, accent, Vector3(PI * 0.5, a, 0.3))
		_:
			for i in 8:
				_column(_rim(TAU * i / 8.0, 3.0), 4.0, stone, metal)


## Three ruined rear apses frame the encounter without masking the foreground or adding arena props.
func _arena_reliquaries() -> void:
	var stone := HdCathedral.wall_material()
	var pale := _mat("arena_carved_stone", Color("70727e"))
	var iron := _mat("arena_rusted_iron", Color("4c494a"), 0, 0.62)
	var dark := _mat("arena_shrine_shadow", Color("10131d"))
	var motif := _mat("arena_relic_" + _theme, _accent.lerp(Color("626775"), 0.6), 0.12, 0.25)
	for index in 3:
		var angle := PI + (index - 1) * 0.72
		var p := _rim(angle, 7.6)
		var yaw := atan2(_arena.x - p.x, _arena.z - p.z)
		_local("box", stone, Vector3(6.4, 2.8, 3.4), p, Vector3(0, -1.0, 0), yaw)
		_pointed_niche(p, yaw, 4.9, 7.2 + index * 0.65, stone, pale)
		for side in [-1.0, 1.0]:
			_local("spire", stone, Vector3(0.45, 2.3, 0.45), p, Vector3(side * 2.5, 6.6, 0), yaw + PI * 0.25)
			_local("box", iron, Vector3(0.07, 2.5, 0.07), p, Vector3(side * 1.8, 2, 0), yaw)
		var relic := p + Vector3(0, 1.2, 0.3).rotated(Vector3.UP, yaw)
		match _theme:
			"forge":
				_reliquary(relic, yaw, stone, iron, dark)
				for k in 4:
					_ring(p + Vector3(0, 3.7 + k * 0.55, 0.2).rotated(Vector3.UP, yaw), 0.28, iron, Vector3(PI * 0.5, yaw + k % 2 * PI * 0.5, 0))
			"tide":
				# A drowned reliquary bell and encrusted anchor keep the sea theme in the architecture.
				_local("cylinder", iron, Vector3(0.75, 1.1, 0.75), p, Vector3(0, 3.0, 0.25), yaw)
				_ring(p + Vector3(0, 2.45, 0.25).rotated(Vector3.UP, yaw), 0.8, motif, Vector3.ZERO)
				for side in [-1.0, 1.0]:
					_beam(relic + Vector3.UP * 0.3, relic + Vector3(side * 1.5, 1.2, 0).rotated(Vector3.UP, yaw), 0.16, iron)
					_local("sphere", pale, Vector3(0.2, 0.14, 0.2), p, Vector3(side * 1.15, 0.9, 0.75), yaw)
			"rot":
				_reliquary(relic, yaw, stone, pale, dark)
				for side in [-1.0, 1.0]:
					_beam(p + Vector3(side * 2, 0.2, 0), p + Vector3(side * 0.7, 4.6, 0.3), 0.2, motif)
					_local("spire", dark, Vector3(0.22, 1.6, 0.22), p, Vector3(side * 1.15, 3.8, 0.2), yaw + PI * 0.25)
			"time":
				_ring(p + Vector3.UP * 3.7, 1.5, iron, Vector3(PI * 0.5, yaw, 0))
				for k in 8:
					var a := k * TAU / 8.0
					_local("box", motif, Vector3(0.12, 0.3, 0.1), p, Vector3(sin(a) * 1.28, 3.7 + cos(a) * 1.28, 0.1), yaw)
				_beam(p + Vector3.UP * 3.7, p + Vector3(0.8, 4.5, 0).rotated(Vector3.UP, yaw), 0.09, pale)
			"void":
				_ring(p + Vector3.UP * 3.8, 1.5, dark, Vector3(PI * 0.5, yaw, 0))
				_ring(p + Vector3.UP * 3.8, 1.12, motif, Vector3(PI * 0.5, yaw, 0.25))
				for side in [-1.0, 1.0]:
					_local("spire", dark, Vector3(0.6, 2.5, 0.6), p, Vector3(side * 0.7, 1.7, 0), yaw + side * 0.3)


func _pointed_niche(p: Vector3, yaw: float, width: float, height: float, stone: Material, trim: Material) -> void:
	for side in [-1.0, 1.0]:
		_local("box", stone, Vector3(0.62, height * 0.67, 0.75), p, Vector3(side * width * 0.5, height * 0.335, 0), yaw)
		_local("box", trim, Vector3(0.78, 0.2, 0.85), p, Vector3(side * width * 0.5, height * 0.64, 0), yaw)
	var outline := [Vector2(-0.5, 0.64), Vector2(-0.31, 0.85), Vector2(0, 1), Vector2(0.31, 0.85), Vector2(0.5, 0.64)]
	for index in outline.size() - 1:
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[index + 1]
		var from := p + Vector3(a.x * width, a.y * height, 0).rotated(Vector3.UP, yaw)
		var to := p + Vector3(b.x * width, b.y * height, 0).rotated(Vector3.UP, yaw)
		_beam(from, to, 0.42, stone)
		_beam(from + Vector3(0, 0.15, 0), to + Vector3(0, 0.15, 0), 0.1, trim)
	_local("spire", trim, Vector3(0.35, 1.0, 0.35), p, Vector3(0, height + 0.45, 0), yaw + PI * 0.25)


func _arena_floor(center: Vector3) -> ShaderMaterial:
	var key := "floor_%s_%s" % [_theme, center]
	if _materials.has(key):
		return _materials[key]
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform vec3 arena_center;
uniform vec4 accent : source_color;
uniform int motif=0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=world_position.xz-arena_center.xz;float r=length(p);float a=atan(p.y,p.x);
 vec2 uv=p*0.48;vec2 f=fract(uv);float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
 float grout=1.0-smoothstep(0.015,0.04,edge);float v=0.88+0.18*hash2(floor(uv));
 vec3 base=vec3(0.27,0.28,0.32);float detail=0.0;
 if(motif==1){base=vec3(0.21,0.19,0.19);detail=(1.0-smoothstep(0.02,0.08,abs(sin(p.x*1.1))))*0.22;}
 if(motif==2){base=vec3(0.29,0.38,0.40);detail=(1.0-smoothstep(0.03,0.10,abs(sin(r*1.3+a*1.5))))*0.2;}
 if(motif==3){base=vec3(0.25,0.30,0.23);detail=step(0.76,hash2(floor(p*0.7)))*0.12;}
 if(motif==4){base=vec3(0.38,0.35,0.40);detail=(1.0-smoothstep(0.02,0.06,abs(sin(r*0.65))))*0.23;detail+=step(11.0,r)*(1.0-smoothstep(0.015,0.045,abs(sin(a*12.0))))*0.3;}
 if(motif==5){base=vec3(0.19,0.17,0.26);detail=(1.0-smoothstep(0.02,0.06,abs(sin(a*5.0+sin(r*0.5)))))*smoothstep(3.0,12.0,r)*0.26;}
 ALBEDO=mix(base*v*(1.0-grout*0.42),accent.rgb,detail);ROUGHNESS=motif==2?0.38:0.85;METALLIC=motif==1?0.25:0.04;
 NORMAL=terrain_relief_normal(NORMAL,VERTEX,-grout*0.018+terrain_grain(world_position*4.0)*0.006,0.45);
 SPECULAR=mix(motif==2?0.48:0.30,0.17,grout);
 EMISSION=accent.rgb*detail*0.14;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("arena_center", center)
	material.set_shader_parameter("accent", _accent)
	material.set_shader_parameter("motif", {"forge": 1, "tide": 2, "rot": 3, "time": 4, "void": 5}.get(_theme, 0))
	_materials[key] = material
	return material


func _allowed(p: Vector3, margin: float) -> bool:
	if Vector2(p.x - _arena.x, p.z - _arena.z).length() < _radius + margin + 1.0:
		return false
	for station in _data.get("list", []):
		var at := _relative(station.pos)
		if Vector2(p.x - at.x, p.z - at.z).length() < maxf(7.0, float(station.get("radius", 0))) + margin:
			return false
		if str(station.kind) == "glutpfad":
			var inward := -_layout.arm_axis(str(station.id))
			var delta := p - at
			var along := delta.dot(inward)
			if along > -margin and along < float(station.length) + margin and (delta - inward * along).length() < float(station.width) * 0.5 + margin:
				return false
	return true


func _rim(angle: float, extra: float) -> Vector3:
	return _arena + Vector3(sin(angle), 0, cos(angle)) * (_radius + extra)


static func _mat(id: String, color: Color, glow := 0.0, metallic := 0.0) -> StandardMaterial3D:
	if _materials.has(id):
		return _materials[id]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78 if metallic == 0 else 0.46
	material.metallic = metallic
	if glow > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_materials[id] = material
	return material


func _column(p: Vector3, height: float, stone: Material, trim: Material) -> void:
	_place("box", stone, Vector3(1.8, 0.4, 1.8), p + Vector3.UP * 0.2)
	_place("box", stone, Vector3(1.05, height, 1.05), p + Vector3.UP * height * 0.5)
	_place("box", trim, Vector3(1.5, 0.3, 1.5), p + Vector3.UP * (height - 0.3))
	_place("spire", stone, Vector3(0.75, 1.6, 0.75), p + Vector3.UP * (height + 0.8), PI * 0.25)


func _brazier(p: Vector3, color: Color, light: bool) -> void:
	var stone := _mat("brazier_stone", Color("303642"))
	var iron := _mat("brazier_iron", Color("20252d"), 0, 0.5)
	_place("cylinder", stone, Vector3(0.8, 0.25, 0.8), p + Vector3.UP * 0.125)
	_place("cylinder", iron, Vector3(0.3, 0.85, 0.3), p + Vector3.UP * 0.65)
	_place("cylinder", iron, Vector3(0.75, 0.22, 0.75), p + Vector3.UP * 1.15)
	_ring(p + Vector3.UP * 1.27, 0.8, iron, Vector3.ZERO)
	for i in 5:
		_place("sphere", _mat("embers", Color("f57927"), 1.2), Vector3(0.15, 0.08, 0.15), p + Vector3(sin(i * 2.4) * 0.42, 1.3, cos(i * 2.4) * 0.42))
	_flames(p + Vector3.UP * 1.9, 1.1)
	if light and _light_count < 4:
		var node := OmniLight3D.new()
		node.position = p + Vector3.UP * 2
		node.light_color = color
		node.light_energy = 0.75
		node.omni_range = 9
		node.shadow_enabled = false
		_arena_node.add_child(node)
		_light_count += 1


func _ring(p: Vector3, radius: float, material: Material, rotation: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.09
	mesh.outer_radius = radius
	mesh.rings = 20
	mesh.ring_segments = 6
	_queue("ring_" + str(radius), mesh, material, Transform3D(Basis.from_euler(rotation), p))


func _beam(from: Vector3, to: Vector3, thickness: float, material: Material) -> void:
	var direction := (to - from).normalized()
	var basis := Basis.IDENTITY
	if absf(direction.dot(Vector3.UP)) < 0.999:
		basis = Basis(Vector3.UP.cross(direction).normalized(), acos(clampf(Vector3.UP.dot(direction), -1, 1)))
	var mesh := BoxMesh.new()
	_queue("beam", mesh, material, Transform3D(basis * Basis.from_scale(Vector3(thickness, from.distance_to(to), thickness)), (from + to) * 0.5))


func _place(kind: String, material: Material, size: Vector3, p: Vector3, yaw := 0.0) -> void:
	var mesh: Mesh
	if kind == "box":
		mesh = BoxMesh.new()
	elif kind == "rock":
		mesh = _mountain_mesh()
	elif kind == "mountain":
		mesh = _peak_mesh()
	elif kind == "fire":
		mesh = QuadMesh.new()
	elif kind == "sphere":
		var sphere := SphereMesh.new()
		sphere.radius = 1
		sphere.height = 2
		sphere.radial_segments = 6 if kind == "rock" else 10
		sphere.rings = 3 if kind == "rock" else 5
		mesh = sphere
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0 if kind == "spire" else 1
		cylinder.bottom_radius = 1
		cylinder.height = 1
		cylinder.radial_segments = 5 if kind == "spire" else 48
		mesh = cylinder
	_queue(kind, mesh, material, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), p))


static func _peak_mesh() -> ArrayMesh:
	if _peak_geometry:
		return _peak_geometry
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for level in 4:
		var ring: Array[Vector3] = []
		for i in 8:
			var angle := TAU * i / 8.0
			var radius: float = [1.0, 0.76, 0.38, 0.0][level] * (0.88 + fmod(i * 0.41, 0.23))
			ring.append(Vector3(cos(angle) * radius + level * 0.045, [0.0, 0.24, 0.64, 1.0][level], sin(angle) * radius - level * 0.025))
		rings.append(ring)
	for level in 3:
		for i in 8:
			var j := (i + 1) % 8
			for tri in [[rings[level][j], rings[level + 1][i], rings[level][i]], [rings[level + 1][j], rings[level + 1][i], rings[level][j]]]:
				if (tri[1] - tri[0]).cross(tri[2] - tri[0]).length_squared() < 0.00001:
					continue
				var normal: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
				for point in tri:
					st.set_normal(normal)
					st.add_vertex(point)
	_peak_geometry = st.commit()
	return _peak_geometry


static func _mountain_mesh() -> ArrayMesh:
	if _rock_geometry:
		return _rock_geometry
	# Eigene kantige Basaltform: getrennte Dreiecksnormalen statt geglätteter Kiesel.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var rings: Array = []
	for level in 4:
		var ring := PackedVector3Array()
		for i in 7:
			var angle := TAU * i / 7.0
			var radius: float = [0.72, 1.0, 0.62, 0.06][level] * (0.84 + fmod(i * 0.37, 0.31))
			ring.append(Vector3(cos(angle) * radius + level * 0.035, [-1.0, -0.25, 0.58, 1.0][level], sin(angle) * radius))
		rings.append(ring)
	for level in 3:
		for i in 7:
			var j := (i + 1) % 7
			for tri in [[rings[level][j], rings[level + 1][i], rings[level][i]], [rings[level + 1][j], rings[level + 1][i], rings[level][j]]]:
				var normal: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
				for point in tri:
					vertices.append(point)
					normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	_rock_geometry = ArrayMesh.new()
	_rock_geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _rock_geometry


func _queue(kind: String, mesh: Mesh, material: Material, transform: Transform3D) -> void:
	var key := "%s:%s:%d" % [_tag, kind, material.get_instance_id()]
	if not _groups.has(key):
		_groups[key] = {"mesh": mesh, "material": material, "transforms": [], "tag": _tag}
	_groups[key].transforms.append(transform)


func _flush() -> void:
	for group in _groups.values():
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = group.mesh
		mesh.instance_count = group.transforms.size()
		for i in group.transforms.size():
			mesh.set_instance_transform(i, group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mesh
		node.material_override = group.material
		(_arena_node if group.tag == "arena" else _common).add_child(node)
