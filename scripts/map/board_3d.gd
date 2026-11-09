class_name Board3D
extends Node3D
## 3D-Darstellung einer Map: Neon-Gitter als Boden, Steine, Wegpunkte, Weg und Hover-Markierung.
## Blockierte Felder (Mauern) werden nicht gezeichnet, nur ihr Rand als Neonlinie.
## Andere Modi (eeveTD, Shopping Maul) bekommen über FieldStyle ihren eigenen Look (Gras, Marmor …).
## Wird vom Spiel und vom Map-Editor benutzt. Tower und Gegner hängen als Kinder darunter.
##
## Koordinaten: 1 Einheit = 1 Towerbreite (128 WC3-Einheiten). Das Raster ist halb so fein:
## Feld (x, y) liegt bei X = x*CELL..(x+1)*CELL, Z entsprechend, Boden bei Y = 0.
## Tower und Steine belegen TOWER_CELLS × TOWER_CELLS Felder, angegeben über das Feld oben links (Anker).

const COL_ROCK := Color("5c5c63")
const ROCK_HEIGHT := 0.55
## Modelle für Steine (werden reihum verteilt). Fehlen sie, werden einfache Blöcke gezeichnet.
const ROCK_MODELS := [
	"res://assets/models/rocks/rock_b.glb",
	"res://assets/models/rocks/rock_c.glb",
	"res://assets/models/rocks/rock_large_a.glb",
	"res://assets/models/rocks/rock_large_b.glb",
	"res://assets/models/rocks/rock_large_c.glb",
]
## Steine füllen ihre 2×2 Felder (breiteste waagrechte Kante in Towerbreiten), höchstens so hoch
const ROCK_SIZE := 0.94
const ROCK_MAX_HEIGHT := 0.75
const ROCK_SHADER := preload("res://assets/shaders/rock.gdshader")
## Neon: Shader für Röhren (innen weiß, außen farbig) und das Gitter-Feld.
const NEON_SHADER := preload("res://assets/shaders/neon.gdshader")
const MARKER_RING_SHADER := preload("res://assets/shaders/marker_ring.gdshader")
const NEON_FLOOR_SHADER := preload("res://assets/shaders/neon_floor.gdshader")
## Dasselbe Feld beleuchtet und deckend (FieldStyle "floor_lit", z. B. Marmor in Art déco).
const LIT_FLOOR_SHADER := preload("res://assets/shaders/neon_floor_lit.gdshader")
const COL_WAYPOINT := Color("ff36d8")
const COL_PATH := Color("2ef2e0")
## Boden-Shader und seine Texturen (zwei Grasarten, Erde). Erde liegt auf dem Laufweg der leeren Map,
## um Spawn, Ziel und Checkpoints und auf "_"-Feldern; sonst Gras.
## Liegt unter dem Neon-Gitter und ist mit ground_alpha = 0 (Standard) ausgeblendet.
const GROUND_SHADER := "res://assets/shaders/ground.gdshader"
const GROUND_TEXTURES := {
	"grass_a": "res://assets/textures/ground/grass_a.jpg",
	"grass_b": "res://assets/textures/ground/grass_b.jpg",
	"dirt": "res://assets/textures/ground/dirt.jpg",
	"grass_a_normal": "res://assets/textures/ground/grass_a_normal.jpg",
	"grass_b_normal": "res://assets/textures/ground/grass_b_normal.jpg",
	"dirt_normal": "res://assets/textures/ground/dirt_normal.jpg",
}
## Erde: voller Anteil bis DIRT_CORE Felder Abstand vom Weg, dann Auslaufen über DIRT_FADE Felder.
const DIRT_CORE := 0.8
const DIRT_FADE := 2.2
## Um Spawn, Ziel und Checkpoints ist der Erdfleck so viele Felder größer als die Sperrzone.
const DIRT_ZONE_EXTRA := 1.5
## Kantenlänge eines Rasterfelds in Einheiten.
const CELL := 0.5
## Farben der Spieler (Zonen auf Maul-Maps), Spieler 1 zuerst: Pink, Cyan, Neongrün, Weiß, dann weitere.
const PLAYER_COLORS := [Color("ff4fd8"), Color("22c4ee"), Color("39ff6a"), Color("f2f2f2"), Color("ffd166"), Color("b38cff"), Color("ff8a4f"), Color("4f7dff")]
## Ein Tower ist so viele Felder breit und tief.
const TOWER_CELLS := 2
## Fallen sind größer (Trefferfläche).
const TRAP_CELLS := 3

var map: MapData
var rocks: Dictionary = {}
var path_points := PackedVector2Array()
var marker_lanes: Array = []  ## Bahnen mit Beschriftung an den Wegpunkten, leer = alle (Mehrspieler: nur die eigene)
var path_color := COL_PATH
var hover_cell := Vector2i(-1, -1)  ## Anker (oben links) der Hover-Markierung
var hover_size := TOWER_CELLS       ## Kantenlänge der Hover-Markierung in Feldern
var hover_ok := true
## Reichweite des Towers, der gerade gesetzt wird: Ring um die Bauvorschau (0 = keiner). Modi setzen sie vor
## refresh_hover() (YouTD, Randgruppen, eeveTD-Fallen), Lukas 2026-11-03.
var hover_range := 0.0
var _hover_ring: MeshInstance3D
var _hover_ring_r := 0.0
## Ausgewählte Steine (Anker), werden türkis umrandet.
var selected_rocks: Array = []
var _selection: MultiMeshInstance3D
## Deckkraft des Gras-/Erdbodens unter dem Gitter: 0 = aus.
var ground_alpha := 0.0:
	set(v):
		ground_alpha = v
		if _ground_mat != null:
			_ground_mat.set_shader_parameter("ground_alpha", v)
			_ground.visible = ground_alpha > 0.0
## Tiefe der Schlucht in Einheiten: "_"-Felder (nur Laufweg) liegen so viel tiefer, die Bauflächen stehen
## wie Klippen darüber (YouTD). 0 = alles flach. Vor add_child setzen.
var path_depth := 0.0
## Feine Linien je Feld zusätzlich zum Towergitter (0 = aus), z. B. im Map-Editor.
var grid_strength := 0.0:
	set(v):
		grid_strength = v
		if _floor_mat != null:
			_floor_mat.set_shader_parameter("fine_strength", v)

var _ground: MeshInstance3D
var _ground_mat: ShaderMaterial
var _floor: MeshInstance3D
## Spiegelung auf dem Feld (FieldStyle "reflect"), gleiche Fläche wie _floor
var _reflect: MeshInstance3D
## Farbiger Dunst knapp über dem Feld (FieldStyle "haze", ab Grafik Mittel)
var _haze: MeshInstance3D
var _floor_mat: ShaderMaterial
var _cliffs: MeshInstance3D  ## Felswände der Schlucht (nur mit path_depth > 0)
var _rocks: Array = []  ## je Variante ein MultiMeshInstance3D
var _rock_fits: Array = []  ## je Variante die Transformation, die das Modell auf Feldgröße bringt
var _rock_outlines: Array = []  ## je Variante die Kontur-Hülle (oder null)
var _path: MultiMeshInstance3D
var _rock_shadows: MultiMeshInstance3D  ## Kontaktschatten unter den Steinen (oder null)
var _markers: Node3D
## Zonenrahmen als Lichtstrahlen: Ziel-Helligkeit, aktuelle (blendet über), Aufleuchten, Materialien
const ZONE_BEAM_HEIGHT := 2.4
const ZONE_FAINT := 0.15
const ZONE_FADE_TIME := 2.5  ## Sekunden für das Ausblenden nach dem Start der ersten Welle
const ZONE_FLASH_TIME := 1.6
var zone_glow := 1.0
var zone_rule := true  ## gilt die Gebietsgrenze? Ohne bleiben die Rahmen schwach und leuchten nie auf
var _zone_level := 1.0
var _zone_flash := 0.0
var _zone_shown := 1.0
var _zone_mats: Array = []
var _hover: MeshInstance3D
var _hover_mat: ShaderMaterial
## Aussehen nach dem Oberflächen-Stil beim Anlegen (FieldStyle.current()).
var style: Dictionary = FieldStyle.STYLES[FieldStyle.NEON]


static func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


## Mitte eines Towers/Steins mit Anker a.
static func footprint_center(a: Vector2i, size := TOWER_CELLS) -> Vector2:
	return (Vector2(a) + Vector2.ONE * size / 2.0) * CELL


## Alle Felder, die ein Tower/Stein mit Anker a belegt.
static func footprint(a: Vector2i, size := TOWER_CELLS) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in size:
		for dx in size:
			cells.append(a + Vector2i(dx, dy))
	return cells


## Feld liegt in der Schlucht (abgesenkter Laufweg)?
func is_sunken(c: Vector2i) -> bool:
	return path_depth > 0.0 and map != null and map.in_bounds(c) and map.get_tile(c) == MapData.WALK_ONLY


## Bodenhöhe unter dem Punkt p (Einheiten, X/Z): 0 auf den Bauflächen, -path_depth in der Schlucht.
func ground_y(p: Vector2) -> float:
	return -path_depth if is_sunken(Vector2i(floori(p.x / CELL), floori(p.y / CELL))) else 0.0


static func to_3d(p: Vector2, height := 0.0) -> Vector3:
	return Vector3(p.x, height, p.y)


static func make_material(col: Color, unshaded := false, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent or col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _ready() -> void:
	style = FieldStyle.current()
	if path_color == COL_PATH:
		path_color = style.path
	_ground = MeshInstance3D.new()
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load(GROUND_SHADER)
	var textures: Dictionary = GROUND_TEXTURES.duplicate()
	textures.merge(style.get("ground_textures", {}), true)
	for key in textures:
		_ground_mat.set_shader_parameter(key, load(textures[key]))
	_ground_mat.set_shader_parameter("cell", CELL)
	_ground_mat.set_shader_parameter("ground_alpha", ground_alpha)
	for key in style.get("ground", {}):
		_ground_mat.set_shader_parameter(key, style.ground[key])
	# Boden und Feld sind durchsichtig (ALPHA im Shader) und werden als große Flächen nach ihrer Mitte
	# sortiert. Ohne Vorrang malen sie alles Durchsichtige in der hinteren (nördlichen) Hälfte wieder
	# zu: Bauvorschau, Auswahl, Reichweiten, Schatten der Flieger. Deshalb immer zuerst zeichnen.
	_ground_mat.render_priority = -2
	_ground.material_override = _ground_mat
	_ground.visible = ground_alpha > 0.0
	add_child(_ground)
	_floor = MeshInstance3D.new()
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = LIT_FLOOR_SHADER if style.get("floor_lit", false) else NEON_FLOOR_SHADER
	_floor_mat.set_shader_parameter("cell", CELL)
	_floor_mat.set_shader_parameter("grid_cells", float(TOWER_CELLS))
	_floor_mat.set_shader_parameter("fine_strength", grid_strength)
	var floor_params := FieldStyle.floor_params()
	for key in floor_params:
		_floor_mat.set_shader_parameter(key, floor_params[key])
	_floor_mat.render_priority = -1
	_floor.material_override = _floor_mat
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor)
	if float(style.get("reflect", 0.0)) > 0.0:
		var rm := ShaderMaterial.new()
		rm.shader = preload("res://assets/shaders/floor_reflect.gdshader")
		rm.set_shader_parameter("strength", float(style.reflect))
		rm.render_priority = 0
		_reflect = MeshInstance3D.new()
		_reflect.material_override = rm
		_reflect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_reflect)
	var haze: Dictionary = style.get("haze", {})
	if not haze.is_empty() and Display.quality >= Display.MEDIUM:
		var hm := ShaderMaterial.new()
		hm.shader = preload("res://assets/shaders/ground_mist.gdshader")
		hm.set_shader_parameter("mist_color", haze.color)
		hm.set_shader_parameter("density", haze.density)
		hm.set_shader_parameter("scale", haze.scale)
		hm.set_shader_parameter("edge", 0.08)
		hm.set_shader_parameter("octaves", 2)
		hm.render_priority = 1
		_haze = MeshInstance3D.new()
		_haze.name = "Haze"
		_haze.material_override = hm
		_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_haze)
	ground_alpha = maxf(ground_alpha, style.ground_alpha)
	for path in ROCK_MODELS:
		var m := ModelLoader.mesh_with_transform(path, ROCK_SIZE, true, ROCK_MAX_HEIGHT)
		if m.is_empty():
			continue
		var mmi := _multimesh(m[0], false)
		mmi.material_override = _rock_material()
		_rocks.append(mmi)
		_rock_fits.append(m[1])
		# Kontur: eigene Hülle mit geglätteten Normalen (die Modelle sind flach schattiert); Druidenhain ohne
		if not ModelLoader.has_outline():
			_rock_outlines.append(null)
			continue
		var hull := _multimesh(ModelLoader.smooth_normals(m[0]), false)
		hull.material_override = ModelLoader.outline_material()
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rock_outlines.append(hull)
	if _rocks.is_empty():
		_rocks.append(_multimesh(_box(Vector3(0.82, ROCK_HEIGHT, 0.82)), false, COL_ROCK))
		_rock_outlines.append(null)
		_rock_fits.append(Transform3D(Basis(), Vector3(0, ROCK_HEIGHT / 2.0, 0)))
	if ContactShadow.strength() > 0.0:
		_rock_shadows = _multimesh(ContactShadow.mesh(TOWER_CELLS * CELL), false)
		_rock_shadows.material_override = ContactShadow.material()
		_rock_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dot := SphereMesh.new()
	dot.radius = 0.055
	dot.height = 0.11
	dot.radial_segments = 12
	dot.rings = 6
	_path = _multimesh(dot, false)
	var arrows := PlaneMesh.new()
	arrows.size = Vector2.ONE * 0.24
	_path.multimesh.mesh = arrows
	var path_mat := ShaderMaterial.new()
	path_mat.shader = preload("res://assets/shaders/path_arrow.gdshader")
	path_mat.set_shader_parameter("color", path_color)
	path_mat.set_shader_parameter("energy", style.path_energy)
	_path.material_override = path_mat
	_path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_markers = Node3D.new()
	add_child(_markers)
	_hover = MeshInstance3D.new()
	var preview_plane := PlaneMesh.new()
	preview_plane.size = Vector2.ONE * CELL
	_hover.mesh = preview_plane
	_hover_mat = ShaderMaterial.new()
	_hover_mat.shader = VisualFx.BUILD
	_hover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover.material_override = _hover_mat
	_hover.visible = false
	add_child(_hover)
	if map != null:
		rebuild()


## Felsbrocken: rauchiges Glas (Neon), bemooster Stein (Druidenhain) oder dunkler Marmor (Art déco).
func _rock_material() -> Material:
	match style.rock:
		"stone":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("4f5346")
			m.roughness = 0.95
			m.metallic_specular = 0.12
			return m
		"marble":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("16393b")
			m.roughness = 0.25
			m.metallic_specular = 0.8
			return m
	var glass := ShaderMaterial.new()
	glass.shader = ROCK_SHADER
	# Schein der Neonlinien auf die unteren Flanken (FieldStyle "rock_glow")
	glass.set_shader_parameter("floor_glow", float(style.get("rock_glow", 0.0)))
	# Grundfarbe des Glases (FieldStyle "rock_color", Lukas 2026-11-09: türkis) und dunkler Kern dazu
	if style.has("rock_color"):
		glass.set_shader_parameter("color", style.rock_color)
		glass.set_shader_parameter("core_color", style.rock_core)
	return glass


## Material für Neonröhren: innen weiß, außen col, energy > 1 leuchtet im Glow.
static func neon_material(col: Color, energy := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = NEON_SHADER
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("energy", energy)
	return m


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _multimesh(mesh: Mesh, colors: bool, col := Color.WHITE, unshaded := false) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mmi.multimesh = mm
	var mat := make_material(col, unshaded)
	if colors:
		mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	add_child(mmi)
	return mmi


## Alles neu aufbauen, z. B. nach einer Änderung der Kacheln oder Größe.
func rebuild() -> void:
	if map == null or _ground == null:
		return
	_rebuild_ground()
	_rebuild_floor()
	_rebuild_markers()
	refresh_rocks()
	refresh_path()
	refresh_hover()


## Bodenfläche und Erde-Verteilung (ein Pixel pro Feld) neu berechnen.
func _rebuild_ground() -> void:
	var size := Vector2(map.width, map.height) * CELL
	if path_depth > 0.0:
		_ground.mesh = _terrain_mesh()
		_ground.position = Vector3.ZERO
		_rebuild_cliffs()
	else:
		var plane := PlaneMesh.new()
		plane.size = size
		_ground.mesh = plane
		_ground.position = to_3d(size / 2.0)
	_ground_mat.set_shader_parameter("map_size", size)
	# Abstand jedes Felds zur nächsten Erde-Quelle (Chamfer-Distanz, zwei Durchläufe)
	var w := map.width
	var h := map.height
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(1e6)
	var pf := Pathfinder.new(map)
	for lane in map.lane_count():
		for c in pf.compute_path(lane):
			dist[c.y * w + c.x] = 0.0
	for p in map.all_waypoints():
		var r := map.marker_radius
		for y in range(maxi(p.y - r, 0), mini(p.y + r + 1, h)):
			for x in range(maxi(p.x - r, 0), mini(p.x + r + 1, w)):
				dist[y * w + x] = -DIRT_ZONE_EXTRA
	for y in h:
		for x in w:
			if map.get_tile(Vector2i(x, y)) == MapData.WALK_ONLY:
				dist[y * w + x] = 0.0
	const D := 1.4142
	for y in h:
		for x in w:
			var i := y * w + x
			var v := dist[i]
			if x > 0: v = minf(v, dist[i - 1] + 1.0)
			if y > 0:
				v = minf(v, dist[i - w] + 1.0)
				if x > 0: v = minf(v, dist[i - w - 1] + D)
				if x < w - 1: v = minf(v, dist[i - w + 1] + D)
			dist[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := dist[i]
			if x < w - 1: v = minf(v, dist[i + 1] + 1.0)
			if y < h - 1:
				v = minf(v, dist[i + w] + 1.0)
				if x < w - 1: v = minf(v, dist[i + w + 1] + D)
				if x > 0: v = minf(v, dist[i + w - 1] + D)
			dist[i] = v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)  # RGBA8: L8 mit ungerader Breite wird im GL-Renderer verschoben hochgeladen
	for y in h:
		for x in w:
			var a := clampf(1.0 - (dist[y * w + x] - DIRT_CORE) / DIRT_FADE, 0.0, 1.0)
			if path_depth > 0.0:  # Schlucht: Erde nur unten, oben Gras bis an die Kante
				a = 1.0 if is_sunken(Vector2i(x, y)) else 0.0
			# G = gesperrtes Feld (Wiese in Randgruppen TD, Uniform lawn)
			img.set_pixel(x, y, Color(a, 1.0 if map.get_tile(Vector2i(x, y)) == MapData.BLOCKED else 0.0, a))
	_ground_mat.set_shader_parameter("splat", ImageTexture.create_from_image(img))


## Neon-Feld: Fläche über die ganze Map, blockierte Felder (R), Sperrzonen um die
## Wegpunkte (G) und schlichte Felder ohne Gitter (B) als Maske, ein Pixel pro Feld.
func _rebuild_floor() -> void:
	var size := Vector2(map.width, map.height) * CELL
	if path_depth > 0.0:
		_floor.mesh = _ground.mesh
		_floor.position = Vector3(0, 0.001, 0)
	else:
		var plane := PlaneMesh.new()
		plane.size = size
		_floor.mesh = plane
		_floor.position = to_3d(size / 2.0, 0.001)
	if _reflect != null:
		_reflect.mesh = _floor.mesh
		_reflect.position = _floor.position + Vector3(0, 0.001, 0)
	if _haze != null:
		var hp := PlaneMesh.new()
		hp.size = size
		_haze.mesh = hp
		_haze.position = to_3d(size / 2.0, float(style.haze.height))
	var img := Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)  # RGBA8: L8 mit ungerader Breite wird im GL-Renderer verschoben hochgeladen
	var origin := Vector2i(map.width, map.height)  # erstes freies Feld (oben links)
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if map.get_tile(c) == MapData.BLOCKED:
				img.set_pixel(x, y, Color.WHITE)
			else:
				origin = origin.min(c)
				# G = Sperrzone um Spawn, Ziel und Checkpoints (nicht bebaubar)
				if map.is_marker_zone(c):
					img.set_pixel(x, y, Color(0, 1, 0))
				elif _floor_plain(c):
					img.set_pixel(x, y, Color(0, 0, 1))
	_floor_mat.set_shader_parameter("grid_origin", Vector2(origin))
	_floor_mat.set_shader_parameter("blocked", ImageTexture.create_from_image(img))
	_floor_mat.set_shader_parameter("cells", Vector2(map.width, map.height))
	_floor_mat.set_shader_parameter("tint", _zone_line_tint())
	_floor_mat.set_shader_parameter("tint_floor", 0.0)
	_floor_mat.set_shader_parameter("tint_lines", 1.0)


## Gitterlinien in jeder Spielerzone (Maul-Maps) in der Farbe ihres Spielers, sonst keine Maske.
func _zone_line_tint() -> Texture2D:
	var img := Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
	for z in map.zones:
		if z.player >= 0:
			img.fill_rect(z.rect.intersection(Rect2i(0, 0, map.width, map.height)), PLAYER_COLORS[z.player % PLAYER_COLORS.size()])
	return ImageTexture.create_from_image(img)


## Feld ohne Gitterlinien zeichnen (Maul: unter der Stadt, YouTD: der Weg unten in der Schlucht).
func _floor_plain(c: Vector2i) -> bool:
	return is_sunken(c)


## Boden mit abgesenkten "_"-Feldern als ein Mesh (gleich hohe Felder einer Zeile zusammengefasst).
func _terrain_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in map.height:
		var x := 0
		while x < map.width:
			var low := is_sunken(Vector2i(x, y))
			var x2 := x + 1
			while x2 < map.width and is_sunken(Vector2i(x2, y)) == low:
				x2 += 1
			var h := -path_depth if low else 0.0
			_quad(st, Vector3(x * CELL, h, y * CELL), Vector3(x2 * CELL, h, y * CELL),
					Vector3(x2 * CELL, h, (y + 1) * CELL), Vector3(x * CELL, h, (y + 1) * CELL), Vector3.UP)
			x = x2
	st.generate_tangents()
	return st.commit()


## Senkrechte Felswände überall, wo ein Schluchtfeld an eine Baufläche grenzt; oben heller, unten im Schatten.
func _rebuild_cliffs() -> void:
	if _cliffs == null:
		_cliffs = MeshInstance3D.new()
		_cliffs.material_override = _cliff_material()
		add_child(_cliffs)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := path_depth
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if not is_sunken(c):
				continue
			for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = c + dir
				if not map.in_bounds(n) or is_sunken(n):
					continue
				# Kante zwischen c und n, von c aus gesehen links nach rechts
				var mid := (Vector2(c) + Vector2(0.5, 0.5) + Vector2(dir) * 0.5) * CELL
				var side := Vector2(-dir.y, dir.x) * CELL * 0.5
				var a := mid - side
				var b := mid + side
				_quad(st, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, -d, b.y), Vector3(a.x, -d, a.y),
						Vector3(-dir.x, 0, -dir.y), true)
	_cliffs.mesh = st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, e: Vector3, normal: Vector3, shade := false) -> void:
	for v in [a, b, c, a, c, e]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x, v.z))
		if shade:
			st.set_color(Color.WHITE.lerp(Color(0.55, 0.52, 0.48), clampf(-v.y / path_depth, 0.0, 1.0)))
		st.add_vertex(v)


## Fels für die Schluchtwände: Erde-Textur dunkel und grau getönt, ohne Rücksicht auf UVs (triplanar).
func _cliff_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(GROUND_TEXTURES.dirt)
	m.albedo_color = Color("b0a898")
	m.vertex_color_use_as_albedo = true
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.6
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func refresh_rocks() -> void:
	if _rocks.is_empty():
		return
	var buckets := []
	for i in _rocks.size():
		buckets.append([])
	for c in rocks.keys():
		buckets[absi(c.x * 7 + c.y * 13) % _rocks.size()].append(c)
	if _rock_shadows != null:
		var sm := _rock_shadows.multimesh
		sm.instance_count = rocks.size()
		var k := 0
		for c in rocks.keys():
			sm.set_instance_transform(k, Transform3D(Basis(), to_3d(footprint_center(c), ContactShadow.LIFT)))
			k += 1
	for i in _rocks.size():
		var mm: MultiMesh = _rocks[i].multimesh
		mm.instance_count = buckets[i].size()
		var om: MultiMesh = _rock_outlines[i].multimesh if _rock_outlines[i] != null else null
		if om != null:
			om.instance_count = buckets[i].size()
		for j in buckets[i].size():
			var c: Vector2i = buckets[i][j]
			# leicht gedreht, damit nicht alle Steine gleich aussehen
			var turn := Basis(Vector3.UP, float((c.x * 7 + c.y * 13) % 4) * PI / 2.0)  # nur Vierteldrehungen: Stein bleibt in seinen Feldern
			var place := Transform3D(turn, to_3d(footprint_center(c)))
			mm.set_instance_transform(j, place * _rock_fits[i])
			if om != null:
				om.set_instance_transform(j, place * _rock_fits[i])


func refresh_selection() -> void:
	if _selection == null:
		_selection = _multimesh(_box(Vector3(TOWER_CELLS * CELL, 0.04, TOWER_CELLS * CELL)), false, Color(0.13, 0.77, 0.93, 0.45), true)
		var mat := _selection.material_override as StandardMaterial3D
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mm := _selection.multimesh
	mm.instance_count = selected_rocks.size()
	for i in selected_rocks.size():
		mm.set_instance_transform(i, Transform3D(Basis(), to_3d(footprint_center(selected_rocks[i]), 0.03)))


func refresh_path() -> void:
	if _path == null:
		return
	var pm := _path.material_override
	if pm is ShaderMaterial:
		pm.set_shader_parameter("color", path_color)
	elif pm is StandardMaterial3D:
		pm.albedo_color = path_color
		pm.emission = path_color
	var mm := _path.multimesh
	mm.instance_count = path_points.size()
	for i in path_points.size():
		var next: Vector2 = path_points[mini(i + 1, path_points.size() - 1)]
		var prev: Vector2 = path_points[maxi(i - 1, 0)]
		var dir: Vector2 = next - prev
		var facing := Basis(Vector3.UP, atan2(-dir.x, -dir.y)) if not dir.is_zero_approx() else Basis()
		mm.set_instance_transform(i, Transform3D(facing, to_3d(path_points[i], 0.04 + ground_y(path_points[i]))))


## Wegpunkte am Boden ein/aus (aus, solange der Lichtpfad läuft).
func set_path_dots(on: bool) -> void:
	if _path != null:
		_path.visible = on


func refresh_hover() -> void:
	if _hover == null:
		return
	_hover.visible = map != null and map.in_bounds(hover_cell)
	if _hover.visible:
		_hover.position = to_3d(footprint_center(hover_cell, hover_size), 0.0)
		_hover.scale = Vector3(hover_size, 1, hover_size)
		_hover.position.y = 0.08 + ground_y(Vector2(_hover.position.x, _hover.position.z))
		_hover_mat.set_shader_parameter("valid", hover_ok)
	_refresh_hover_ring()


func _refresh_hover_ring() -> void:
	var show := _hover.visible and hover_range > 0.0
	if not show:
		if _hover_ring != null:
			_hover_ring.visible = false
		return
	if _hover_ring == null or not is_equal_approx(hover_range, _hover_ring_r):
		if _hover_ring != null:
			_hover_ring.queue_free()
		_hover_ring_r = hover_range
		_hover_ring = VisualFx.area(hover_range, Color(0.13, 0.77, 0.93, 0.65), self)
		add_child(_hover_ring)
	var c := footprint_center(hover_cell, hover_size)
	_hover_ring.position = to_3d(c, 0.06 + ground_y(c))
	_hover_ring.visible = true


## Nur diese Bahnen beschriften (leer = alle); die Ringe aller Wegpunkte bleiben stehen.
func set_marker_lanes(lanes: Array) -> void:
	marker_lanes = lanes
	if map != null and _markers != null:
		_rebuild_markers()


## Beschriftungen über den Wegpunkten (Randgruppen TD ohne: dort reicht die Anzeige der Wege, Lukas 2026-10-30).
var marker_labels := true


## Texte der Wegpunkt-Beschriftungen (für Tests).
func marker_texts() -> Array:
	return _markers.get_children().filter(func(n): return n is Label3D).map(func(n): return n.text)


func _rebuild_markers() -> void:
	_zone_mats.clear()
	for c in _markers.get_children():
		_markers.remove_child(c)
		c.queue_free()
	# Maul-Maps: Spawn und Checkpoints jeder Bahn, Spawns mit Nummer ("S2"), Checkpoints z. B. "2.1"
	# (teilen sich Bahnen einen Punkt, steht dort ein Ring mit beiden Namen). Ist nur eine Bahn
	# beschriftet (Mehrspieler, eigene Bahn), steht dort nur die Nummer wie bei einer Bahn.
	var labels := {}
	var order: Array[Vector2i] = []
	var shown := marker_lanes.filter(func(l): return l < map.lane_count()) if not marker_lanes.is_empty() else range(map.lane_count())
	var many := shown.size() > 1
	for lane in map.lane_count():
		var pts := map.waypoints(lane)
		for i in pts.size() - 1:
			if not labels.has(pts[i]):
				labels[pts[i]] = []
				order.append(pts[i])
			if shown.has(lane):
				labels[pts[i]].append(("S%d" % (lane + 1) if many else "S") if i == 0 else ("%d.%d" % [lane + 1, i] if many else str(i)))
	for c in order:
		_add_marker(c, " / ".join(labels[c]), style.marker)
	_add_marker(map.goal, "Z", style.marker)
	for lane in range(1, map.lane_count()):
		if map.lane_goal(lane) != map.goal:
			_add_marker(map.lane_goal(lane), "Z%d" % (lane + 1), style.marker)
	for z in map.zones:
		_add_zone(z.rect, PLAYER_COLORS[z.player % PLAYER_COLORS.size()] if z.player >= 0 else style.marker)


## Rand einer Zone (Maul-Maps) als Lichtstrahl in der Farbe ihres Spielers: heller Streifen am Boden
## und ein Lichtvorhang darüber (zone_beam.gdshader). Die Seiten reichen um eine halbe Breite über die
## Ecken hinaus, damit die Ecken voll ausgefüllt sind. Helligkeit über set_zone_glow/flash_zones.
func _add_zone(r: Rect2i, col: Color, width := 0.12, energy := 2.4) -> void:
	var a := Vector2(r.position) * CELL
	var b := Vector2(r.end) * CELL
	for side in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [Vector2(a.x, b.y), b], [a, Vector2(a.x, b.y)]]:
		var from: Vector2 = side[0]
		var to: Vector2 = side[1]
		var along_z := absf(to.x - from.x) < 0.001
		var side_len := from.distance_to(to)
		var mid := (from + to) / 2.0
		var strip := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(side_len + width, width)
		strip.mesh = plane
		strip.material_override = _zone_material(col, energy, false, side_len)
		strip.position = Vector3(mid.x, 0.03, mid.y)
		var curtain := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(side_len, ZONE_BEAM_HEIGHT)
		curtain.mesh = quad
		curtain.material_override = _zone_material(col, energy, true, side_len)
		curtain.position = Vector3(mid.x, ZONE_BEAM_HEIGHT / 2.0, mid.y)
		for m: MeshInstance3D in [strip, curtain]:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if along_z:
				m.rotation.y = PI / 2.0
			_markers.add_child(m)


func _zone_material(col: Color, energy: float, curtain: bool, side_len: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/zone_beam.gdshader")
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("curtain", 1.0 if curtain else 0.0)
	mat.set_shader_parameter("side_len", side_len)
	mat.set_shader_parameter("intensity", _zone_shown)
	_zone_mats.append(mat)
	return mat


## Helligkeit der Zonenrahmen (1 = voll wie vor der ersten Welle, ZONE_FAINT = nur leicht sichtbar); blendet weich über.
func set_zone_glow(v: float) -> void:
	if v == zone_glow:
		return
	zone_glow = v
	set_process(true)


## Gilt die Gebietsgrenze (nur im eigenen Gebiet bauen)? Ohne bleiben die Rahmen schwach.
func set_zone_rule(on: bool) -> void:
	if on == zone_rule:
		return
	zone_rule = on
	set_process(true)


## Zonenrahmen kurz hell aufleuchten lassen (Bauversuch außerhalb des eigenen Gebiets).
func flash_zones() -> void:
	if not zone_rule:
		return
	_zone_flash = 1.0
	set_process(true)


func _process(delta: float) -> void:
	var target := zone_glow if zone_rule else minf(zone_glow, ZONE_FAINT)
	_zone_level = move_toward(_zone_level, target, delta / ZONE_FADE_TIME)
	_zone_flash = maxf(_zone_flash - delta / ZONE_FLASH_TIME, 0.0)
	var shown := maxf(_zone_level, ease(_zone_flash, 0.5))
	if not is_equal_approx(shown, _zone_shown):
		_zone_shown = shown
		for m: ShaderMaterial in _zone_mats:
			m.set_shader_parameter("intensity", shown)
	if _zone_level == target and _zone_flash == 0.0:
		set_process(false)


## Wegpunkt als Neonröhren-Ring: nur die Kontur, mit überhelltem Kern, der im Glow leuchtet.
func _add_marker(c: Vector2i, text: String, col: Color) -> void:
	if FieldStyle.is_neon():
		# Neon: flache Leuchtlinie wie das Feld (marker_ring.gdshader) statt einer Röhre
		var flat := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * 1.55
		flat.mesh = plane
		var fm := ShaderMaterial.new()
		fm.shader = MARKER_RING_SHADER
		fm.set_shader_parameter("color", col)
		fm.set_shader_parameter("energy", style.marker_energy)
		fm.render_priority = 1
		flat.material_override = fm
		flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flat.position = to_3d(cell_center(c), 0.012 + ground_y(cell_center(c)))
		_markers.add_child(flat)
		_add_marker_label(c, text, col)
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.48
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = FieldStyle.line_material(col, style.marker_energy)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = to_3d(cell_center(c), 0.04 + ground_y(cell_center(c)))
	_markers.add_child(ring)
	_add_marker_label(c, text, col)


func _add_marker_label(c: Vector2i, text: String, col: Color) -> void:
	if text == "" or not marker_labels:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.006
	label.outline_size = 24
	label.modulate = col.lerp(Color.WHITE, 0.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = to_3d(cell_center(c), 0.9 + ground_y(cell_center(c)))
	_markers.add_child(label)


## Feld unter dem Mauszeiger (Strahl von der Kamera auf die Bodenebene).
func mouse_cell(camera: Camera3D) -> Vector2i:
	var hit = _mouse_ground(camera)
	if hit == null:
		return Vector2i(-1, -1)
	return Vector2i(floori(hit.x / CELL), floori(hit.y / CELL))


## Anker für etwas mit size × size Feldern, dessen Mitte möglichst nah am Mauszeiger liegt.
func mouse_anchor(camera: Camera3D, size := TOWER_CELLS) -> Vector2i:
	var hit = _mouse_ground(camera)
	if hit == null:
		return Vector2i(-1, -1)
	return Vector2i(roundi(hit.x / CELL - size / 2.0), roundi(hit.y / CELL - size / 2.0))


## Schnittpunkt des Mausstrahls mit dem Boden als Vector2 (X, Z) oder null.
func _mouse_ground(camera: Camera3D):
	if camera == null:
		return null
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	var hit := from + dir * t
	return Vector2(hit.x, hit.z)
