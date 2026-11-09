class_name RgScenery
extends Node3D
## Wände der Randgruppen-Karte: auf den gesperrten Feldern stehen abwechselnd Häuserblocks und Parkbäume
## (Wunsch von Lukas: „ein Gemisch aus Bäumen und Gebäuden“). Die Karte wird in Viertel von QUARTER Feldern
## geteilt, jedes ist Stadt oder Park; in der Stadt stehen Häuser dort, wo ein ganzer 4×4-Block gesperrt ist,
## der Rest wird mit Bäumen aufgefüllt. Rein optisch, fester Zufallsstartwert: bei allen Spielern gleich.
## Außerhalb der Karte geht die Stadt OUTER Felder weit weiter (Boden, Häuser, Bäume), damit man beim
## weitesten Zoom am Rand nicht ins Leere schaut (wie der Wald in eeveTD).

const N := "res://assets/models/nature/%s.glb"
const C := "res://assets/models/city/%s.glb"
## Bäume: [Modell, Höhe von, Höhe bis, Gewicht]
const TREES := [
	["common_tree_3", 1.6, 2.4, 3.0], ["common_tree_4", 1.6, 2.5, 3.0], ["common_tree_5", 1.5, 2.3, 3.0],
	["pine_1", 1.8, 2.8, 1.0], ["pine_2", 1.8, 2.6, 1.0],
]
## Häuser der Wände (andere als die der Tower, siehe rg_daten.py MODELS): [Modell, Größe von, Größe bis, Gewicht]
const HOUSES := [
	["2story_2", 1.7, 1.9, 2.0], ["2story_double", 1.8, 1.95, 2.0], ["2story_gableroof", 1.7, 1.9, 2.0],
	["3story_slim", 1.7, 1.9, 1.5], ["3story_small", 1.7, 1.9, 1.5], ["4story", 1.8, 1.95, 1.2],
	["2story_center", 1.7, 1.9, 1.2], ["building_skyscraper_b", 1.9, 2.0, 0.4],
]
## Büsche an den Rändern der Wände und kleine Blumen auf dem Pflaster (Lukas, 2026-10-29): nur Schmuck,
## ohne Kollision, die Wege der Gegner bleiben frei. [Modell, Größe von, Größe bis, Gewicht]
const BUSHES := [
	["bush_common", 0.45, 0.7, 3.0], ["bush_common_flowers", 0.45, 0.7, 2.0], ["hp_bush011", 0.4, 0.6, 1.0],
]
const FLOWERS := [["flower_3_group", 0.18, 0.28, 1.0], ["flower_4_group", 0.18, 0.28, 1.0]]
const BUSH_SHARE := 0.3    ## Anteil der freien Wandfelder am Rand mit Busch
const FLOWER_SHARE := 0.05 ## Anteil der Bauflächen-Felder mit Blumen
const QUARTER := 12      ## Kantenlänge eines Viertels in Feldern
const TOWN_SHARE := 0.5  ## Anteil der Viertel, die Stadt sind
const TREE_TINT := Color(1.0, 1.0, 1.0)
## So viele Felder reicht die Stadt über den Kartenrand hinaus (Kamera zeigt höchstens CameraRig.VIEW_MARGIN).
const OUTER := 24
## Boden außerhalb: so breit (Einheiten), Wiese wie die gesperrten Felder der Karte.
const FLOOR_MARGIN := 40.0
## Stadtviertel (Lukas, 2026-10-30): jedes Haus steht auf einem erhöhten Gehweg aus Pflaster mit Bordstein,
## dazwischen Wiese (Boden-Shader, lawn); Bäume dort lockerer als im Park.
const HOUSE_FIT := 0.8        ## Haus auf diesen Anteil verkleinert, der Rest des 4×4-Blocks ist Gehweg
const CURB_HEIGHT := 0.06
const STREET_TREES := 0.35    ## Anteil der freien Felder in Stadtvierteln mit Baum (Park 0.85)
## Gestrichelte weiße Mittellinie auf dem Gegnerweg (der Weg selbst ist Straße im Boden-Shader, road).
const DASH := 0.32
const DASH_GAP := 0.32
const DASH_WIDTH := 0.05
## Erde mit Grasflecken unter jedem Baum (Wunsch von Lukas), im Park wachsen die Flächen zusammen.
const SOIL_SHADER := "res://assets/shaders/tree_soil.gdshader"
const SOIL_SIZE := 1.5  ## Durchmesser einer Fläche (Einheiten); Bäume stehen auf 2×2-Feldern = 1 Einheit

var board: Board3D
var map: MapData
var _rng := RandomNumberGenerator.new()


## Häuser und Bäume auf die gesperrten Felder der Karte von game setzen.
static func add_to(game: Node) -> RgScenery:
	var s := RgScenery.new()
	s.board = game.board
	s.map = game.map
	game.board.add_child(s)
	return s


func _ready() -> void:
	_rng.seed = 7041
	var blocked := func(c: Vector2i) -> bool:
		return c.x < 0 or c.y < 0 or c.x >= map.width or c.y >= map.height or map.get_tile(c) == MapData.BLOCKED
	_add_floor()
	var town := {}
	var q0 := -ceili(OUTER / float(QUARTER))
	for qy in range(q0, ceili((map.height + OUTER) / float(QUARTER))):
		for qx in range(q0, ceili((map.width + OUTER) / float(QUARTER))):
			town[Vector2i(qx, qy)] = _rng.randf() < TOWN_SHARE
	var soil: Array[Vector2] = []  # Baumstandorte
	var walks: Array[Vector2] = []  # Mitten der Häuserblöcke (Gehweg)
	var used := {}   # Felder unter Häusern
	var parts := {}  # "pfad|schatten" -> [Transform3D]
	# Häuser: ganze 4×4-Blöcke in Stadtvierteln, Front zur nächsten offenen Seite
	for y in range(-OUTER, map.height + OUTER - 3, 4):
		for x in range(-OUTER, map.width + OUTER - 3, 4):
			if not town[_quarter(x, y)]:
				continue
			var full := true
			for dy in 4:
				for dx in 4:
					full = full and blocked.call(Vector2i(x + dx, y + dy))
			if not full or _rng.randf() < 0.12:
				continue
			for dy in 4:
				for dx in 4:
					used[Vector2i(x + dx, y + dy)] = true
			var i := _pick(HOUSES)
			var size := _rng.randf_range(HOUSES[i][1], HOUSES[i][2]) * HOUSE_FIT
			var center := board.cell_center(Vector2i(x, y)) + Vector2(1.5, 1.5) * Board3D.CELL
			walks.append(center)
			var rot := _facing(Vector2i(x, y), blocked)
			var b := Basis(Vector3.UP, rot).scaled(Vector3.ONE * size)
			parts.get_or_add(C % HOUSES[i][0] + "|1", []).append(Transform3D(b, Vector3(center.x, CURB_HEIGHT, center.y)))
	# Bäume auf allen übrigen gesperrten 2×2-Blöcken, im Park dichter
	for y in range(-OUTER, map.height + OUTER - 1, 2):
		for x in range(-OUTER, map.width + OUTER - 1, 2):
			var a := Vector2i(x, y)
			if used.has(a) or not (blocked.call(a) and blocked.call(a + Vector2i(1, 0)) and blocked.call(a + Vector2i(0, 1))
					and blocked.call(a + Vector2i(1, 1))):
				continue
			var park: bool = not town[_quarter(x, y)]
			if _rng.randf() > (0.85 if park else STREET_TREES):
				continue
			var i := _pick(TREES)
			var p := board.cell_center(a) + Vector2(0.5, 0.5) * Board3D.CELL \
					+ Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
			soil.append(p)
			var h := _rng.randf_range(TREES[i][1], TREES[i][2])
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * h)
			# Schatten nur nahe am Weg (sichtbar und günstig)
			var near_path: bool = not (blocked.call(a + Vector2i(-2, 0)) and blocked.call(a + Vector2i(3, 0))
					and blocked.call(a + Vector2i(0, -2)) and blocked.call(a + Vector2i(0, 3)))
			parts.get_or_add(N % TREES[i][0] + ("|1" if near_path else "|0"), []).append(Transform3D(b, Vector3(p.x, 0.0, p.y)))
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				used[a + d] = true
	# Büsche auf freien Wandfeldern direkt neben offenen Feldern, Blumen auf den Bauflächen
	var open_near := func(c: Vector2i) -> bool:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not blocked.call(c + d):
				return true
		return false
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			var p := board.cell_center(c) + Vector2(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.15, 0.15))
			if blocked.call(c):
				if used.has(c) or not open_near.call(c) or _rng.randf() > BUSH_SHARE:
					continue
				var i := _pick(BUSHES)
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(BUSHES[i][1], BUSHES[i][2]))
				parts.get_or_add(N % BUSHES[i][0] + "|1", []).append(Transform3D(b, Vector3(p.x, 0.0, p.y)))
			elif map.get_tile(c) == MapData.FLOOR and _rng.randf() < FLOWER_SHARE:
				var i := _pick(FLOWERS)
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(FLOWERS[i][1], FLOWERS[i][2]))
				parts.get_or_add(N % FLOWERS[i][0] + "|0", []).append(Transform3D(b, Vector3(p.x, 0.0, p.y)))
	for key in parts:
		var k: PackedStringArray = key.split("|")
		_add_multimesh(k[0], parts[key], k[1] == "1", k[0].contains("/nature/"))
	_add_soil(soil)
	_add_walks(walks)
	_add_center_lines()


## Gehwege: erhöhte Pflasterplatte mit Bordstein je Häuserblock. Bei Nachbarhäusern berühren sie sich und
## bilden durchgehende Bürgersteige.
func _add_walks(walks: Array[Vector2]) -> void:
	var block := 4.0 * Board3D.CELL
	var slab := BoxMesh.new()
	slab.size = Vector3(block, CURB_HEIGHT, block)
	var walk := StandardMaterial3D.new()
	walk.albedo_texture = load("res://assets/textures/ground/cobble.jpg")
	walk.normal_enabled = true
	walk.normal_texture = load("res://assets/textures/ground/cobble_normal.jpg")
	walk.uv1_triplanar = true
	walk.uv1_world_triplanar = true
	walk.uv1_scale = Vector3.ONE * 0.6
	walk.albedo_color = Color(0.92, 0.9, 0.86)
	walk.roughness = 0.9
	slab.material = walk
	_add_flat(slab, walks, CURB_HEIGHT / 2.0)
	# Bordstein: heller Rand um die Platte
	var curb := BoxMesh.new()
	curb.size = Vector3(block + 0.04, CURB_HEIGHT * 0.9, block + 0.04)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.7, 0.7, 0.68)
	stone.roughness = 0.85
	curb.material = stone
	_add_flat(curb, walks, CURB_HEIGHT * 0.45)


## Gestrichelte Mittellinie entlang der Gegnerwege aller Bahnen; Abschnitte, die mehrere Bahnen teilen,
## nur einmal. Ecken der Feldkette werden zu geraden Stücken zusammengefasst.
func _add_center_lines() -> void:
	var pf := Pathfinder.new(map)
	var seen := {}
	var xfs: Array[Transform3D] = []
	for lane in map.lane_count():
		var cells: Array[Vector2i] = pf.compute_path(lane)
		var i := 0
		while i < cells.size() - 1:
			# geraden Lauf in gleicher Richtung sammeln
			var dir := cells[i + 1] - cells[i]
			var j := i + 1
			while j < cells.size() - 1 and cells[j + 1] - cells[j] == dir:
				j += 1
			var key := [cells[i], cells[j]]
			if not seen.has(key) and not seen.has([cells[j], cells[i]]):
				seen[key] = true
				var a := board.cell_center(cells[i])
				var b := board.cell_center(cells[j])
				var along := b - a
				var n := floori(along.length() / (DASH + DASH_GAP))
				var rot := Basis(Vector3.UP, atan2(-along.y, along.x))
				for k in n:
					var c := a + along.normalized() * ((k + 0.5) * (DASH + DASH_GAP))
					xfs.append(Transform3D(rot, Vector3(c.x, 0.006, c.y)))
			i = j
	var quad := PlaneMesh.new()
	quad.size = Vector2(DASH, DASH_WIDTH)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.85, 0.85, 0.83)
	white.roughness = 0.8
	quad.material = white
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _add_flat(mesh: Mesh, at: Array[Vector2], y: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(at[i].x, y, at[i].y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Runde Erdflächen unter den Bäumen, knapp über dem Boden und der Sperrfeld-Färbung (y 0.001).
func _add_soil(at: Array[Vector2]) -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * SOIL_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = load(SOIL_SHADER)
	mat.set_shader_parameter("dirt", load("res://assets/textures/ground/dirt.jpg"))
	mat.set_shader_parameter("grass", load("res://assets/textures/ground/grass_a.jpg"))
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = at.size()
	for i in at.size():
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.85, 1.15))
		mm.set_instance_transform(i, Transform3D(b, Vector3(at[i].x, 0.004, at[i].y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _quarter(x: int, y: int) -> Vector2i:
	return Vector2i(floori(x / float(QUARTER)), floori(y / float(QUARTER)))


## Boden um die Karte: derselbe Boden-Shader wie das Spielfeld (Wiese), ohne Wege.
func _add_floor() -> void:
	var size := Vector2(map.width, map.height) * Board3D.CELL
	var floor := MeshInstance3D.new()
	floor.mesh = EeveScenery.frame_mesh(size, FLOOR_MARGIN)
	var mat: ShaderMaterial = board._ground_mat.duplicate()
	var none := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	none.fill(Color(0, 1, 0))  # außerhalb: Wiese (G = gesperrt), kein Weg
	mat.set_shader_parameter("splat", ImageTexture.create_from_image(none))
	mat.set_shader_parameter("ground_alpha", 1.0)
	floor.material_override = mat
	floor.position = Vector3(size.x / 2.0, -0.02, size.y / 2.0)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor)


## Drehung eines Hauses mit Anker a, sodass die Front (−Z des Modells nach +Z gedreht) zur nächsten offenen Seite zeigt.
func _facing(a: Vector2i, blocked: Callable) -> float:
	var best := 0.0
	var best_d := 99
	for dir in [[Vector2i(0, 1), 0.0], [Vector2i(1, 0), PI / 2.0], [Vector2i(0, -1), PI], [Vector2i(-1, 0), -PI / 2.0]]:
		var step: Vector2i = dir[0]
		var start := a + Vector2i(1, 1) + Vector2i(maxi(step.x, 0) * 2, maxi(step.y, 0) * 2)
		for d in range(1, 12):
			if not blocked.call(start + step * d):
				if d < best_d:
					best_d = d
					best = dir[1]
				break
	return best + _rng.randf_range(-0.05, 0.05)


func _pick(list: Array) -> int:
	var total := 0.0
	for e in list:
		total += float(e[3])
	var r := _rng.randf() * total
	for i in list.size():
		r -= float(list[i][3])
		if r <= 0.0:
			return i
	return list.size() - 1


func _add_multimesh(path: String, xfs: Array, shadows: bool, tint: bool) -> void:
	var m := ModelLoader.mesh_with_transform(path, 1.0)
	if m.is_empty():
		return
	var mesh: Mesh = m[0]
	if tint:
		mesh = mesh.duplicate()
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				var t: BaseMaterial3D = mat.duplicate()
				t.albedo_color *= TREE_TINT
				if t.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					# Blätter: lichtdurchlässig statt dunkel im eigenen Schatten (Lukas, 2026-10-29). Keine
					# Schatten auf sich selbst, weich umlaufendes Licht und Licht von hinten durchs Laub.
					t.disable_receive_shadows = true
					t.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					t.backlight_enabled = true
					t.backlight = Color(0.35, 0.45, 0.2)
				mesh.surface_set_material(i, t)
				# Auch deckende Baumteile übernehmen ihre Textur/Farbe; die Basis bleibt fest.
				mesh.surface_set_material(i, VisualFx.wind_material(t, mesh.get_aabb(), self))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i] * m[1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.extra_cull_margin = 0.5 if tint else 0.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
