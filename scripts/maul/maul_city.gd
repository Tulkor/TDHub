class_name MaulCity
extends Node3D
## Blockstadt um das Spielfeld von Shopping Maul im Plaza-Art-déco (Lukas, 2026-11-08): Quader aus hellem
## Kalkstein, gestuft wie Art-déco-Hochhäuser, mit Gesimsen und senkrechten Lisenen in Messing. Steht nur auf Feldern,
## die kein Gegner je erreicht (Flutfüllung von allen Wegpunkten aus) und die in keinem Spielergebiet
## liegen, mit Abstand zu allem Begehbaren. Nah am Spielfeld niedrig, nach außen höher, damit die
## schräge Kamera nichts verdeckt. Weiter draußen stehen einzelne Art-déco-Hochhäuser wie in New York
## oder Chicago (Sockel, Schaft mit Lisenen, Rücksprünge, gestufte Messingkrone, Spitze).
## Restflächen zwischen den Blöcken füllen kleine Häuser und Art-déco-Statuen (Messingfigur mit
## erhobenen Armen auf gestuftem Sockel); kleine Laternen stehen an Straßenkreuzungen und entlang des
## Spielfeldrands, Flaggenreihen in Königsblau säumen die Straßen nah am Spielfeld. In der Kartenmitte
## (über dem Hauptgebiet) liegt ein Platz mit dem Atlas-Brunnen (MaulFountain).
## Alles in vier MultiMeshes (Wände, Messing, Laternenlicht, Flaggentuch).

const SHADER := preload("res://assets/shaders/city.gdshader")
const FLAG_SHADER := preload("res://assets/shaders/flag.gdshader")
## Straßenraster: alle BLOCK Felder eine Straße von STREET Feldern
const BLOCK := 14
const STREET := 1
## Grundstücke innerhalb eines Blocks: Kantenlänge in Feldern
const LOT_MIN := 3
const LOT_MAX := 7
## Felder Abstand zu allem Begehbaren
const GAP := 2
## Höhe in Einheiten: Grundhöhe + Zuwachs je Feld Abstand zum Spielfeld, gedeckelt
const H_BASE := 0.6
const H_STEP := 0.09
const H_MAX := 5.2
## Hochhäuser: nehmen einen ganzen Block ein, erst ab SKY_DIST Feldern Abstand, mit dieser Wahrscheinlichkeit
const SKY_DIST := 11.0
const SKY_CHANCE := 0.42
const SKY_HEIGHT := Vector2(10.0, 17.0)
## Wandfarben (Kalkstein, gemischt), Gesims und Lisenen in Messing
const WALLS := [Color("b0b0b0"), Color("9aa8a8"), Color("c2beb2"), Color("a9a59a"), Color("bab5a8"), Color("a0a6a2")]
## Farbige Fassaden (Lukas, 2026-11-09: „mehr farbliche Gebäude“): Ziegelrot, Terrakotta, Ocker, Jadegrün,
## Petrol, Taubenblau, Lachs (Miami), Mint, Sandgelb; COLORED_SHARE der Gebäude bekommt eine davon
const COLORED := [Color("a8523a"), Color("c0704a"), Color("c49a52"), Color("3d7a5e"), Color("2f6e74"),
		Color("4f6c9c"), Color("d08a78"), Color("8cc0a6"), Color("d8bf7a")]
const COLORED_SHARE := 0.4
const CORNICE := Color("b0904f")
## Statuen und Laternen; A = 0: Fläche ohne Fenster (city.gdshader)
const PLINTH := Color(0.56, 0.44, 0.44, 0.0)
const LAMP := Color("ffe2b8")
## Lisenen: Gebäude ab dieser Höhe bekommen senkrechte Messingstreifen am Sockel
const PIER_HEIGHT := 1.3
## Flaggen: Königsblau, Reihen entlang der Straßen bis FLAG_NEAR Felder vom Spielfeld, alle FLAG_EVERY Felder
const FLAG_BLUE := Color("305090")
const FLAG_NEAR := 22.0
const FLAG_EVERY := 3
const FLAG_POLE := 1.15
## Platz mit Atlas-Brunnen: Kantenlänge in Feldern
const PLAZA := 18
## Laternen am Spielfeldrand: ungefähr jedes LAMP_EVERY-te Randfeld
const LAMP_EVERY := 9
## Restflächen: Anteil der Statuen statt kleiner Häuser (nur nah am Spielfeld, wo man sie sieht)
const STATUE_CHANCE := 0.3
const STATUE_NEAR := 14.0
## Blöcke nah am Spielfeld werden mit dieser Wahrscheinlichkeit ein Platz mit großer Statue
const PLAZA_CHANCE := 0.18

var _walls: MultiMeshInstance3D
var _dist := PackedFloat32Array()
var _width := 0
var _cornices: MultiMeshInstance3D
var _lamps: MultiMeshInstance3D
var _flags: MultiMeshInstance3D
var _pyramids: MultiMeshInstance3D
var fountain: MaulFountain
## Feld in der Mitte des Brunnenplatzes (-1, -1 = kein Platz gefunden)
var plaza_center := Vector2i(-1, -1)


func build(map: MaulMap) -> void:
	for c in get_children():
		c.queue_free()
	var w := map.width
	var h := map.height
	var dist := _distance_to_reachable(map)
	_dist = dist
	_width = w
	var rng := RandomNumberGenerator.new()
	rng.seed = 5440
	var walls: Array = []     # [Transform3D, Color]
	var cornices: Array = []  # Transform3D
	var lamps: Array = []     # Transform3D (Leuchtkörper)
	var flags: Array = []     # Transform3D (Tuch)
	var pyramids: Array = []  # [Transform3D, Color] (Dächer, Spitzen)
	var beacons: Array = []   # Transform3D (rotes Leuchtfeuer)
	var sky := {"walls": walls, "cornices": cornices, "lamps": lamps, "pyramids": pyramids, "beacons": beacons}
	var used := PackedByteArray()
	used.resize(w * h)
	var free := func(x0: int, y0: int, sx: int, sy: int) -> bool:
		for y in range(y0, y0 + sy):
			for x in range(x0, x0 + sx):
				if x >= w or y >= h or dist[y * w + x] <= GAP or used[y * w + x] != 0:
					return false
		return true
	var take := func(r: Rect2i) -> void:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				used[y * w + x] = 1
	# Straßen bleiben frei (für Laternen), auch beim Auffüllen
	for y in h:
		for x in w:
			if x % BLOCK < STREET or y % BLOCK < STREET:
				used[y * w + x] = 2
	# Brunnenplatz in der Kartenmitte zuerst freihalten
	var plaza := _plaza_rect(map, dist)
	if plaza.size.x > 0:
		take.call(plaza)
		plaza_center = plaza.get_center()
		_plaza_dressing(plaza, cornices, lamps, flags)
	for by in range(0, h, BLOCK):
		for bx in range(0, w, BLOCK):
			var block := Rect2i(bx + STREET, by + STREET, BLOCK - STREET, BLOCK - STREET)
			var bd := dist[mini(block.get_center().y, h - 1) * w + mini(block.get_center().x, w - 1)]
			if bd >= SKY_DIST and rng.randf() < SKY_CHANCE and free.call(block.position.x, block.position.y, block.size.x, block.size.y):
				_skyscraper(block, bd, rng, sky)
				take.call(block)
				continue
			if bd < STATUE_NEAR + 6.0 and rng.randf() < PLAZA_CHANCE and free.call(block.position.x, block.position.y, block.size.x, block.size.y):
				# Platz: große Statue in der Mitte, Laternen an den Ecken
				var m := block.get_center() - Vector2i(2, 2)
				_statue(Rect2i(m, Vector2i(4, 4)), rng, walls, cornices)
				for corner in [Vector2i(1, 1), Vector2i(block.size.x - 2, 1), Vector2i(1, block.size.y - 2), Vector2i(block.size.x - 2, block.size.y - 2)]:
					_lantern(block.position + corner, cornices, lamps)
				take.call(block)
				continue
			var lots: Array[Rect2i] = []
			_split(block, rng, lots)
			for r in lots:
				if not free.call(r.position.x, r.position.y, r.size.x, r.size.y):
					continue
				var d := dist[(r.position.y + r.size.y / 2) * w + r.position.x + r.size.x / 2]
				if r.size.x <= 4 and r.size.y <= 4 and d < STATUE_NEAR and rng.randf() < STATUE_CHANCE * 0.5:
					_statue(r, rng, walls, cornices)
				else:
					_building(r, d, rng, walls, cornices)
				take.call(r)
	# Restflächen: was in kein Grundstück passte, mit kleinen Häusern (3 oder 2 Felder) und Statuen füllen
	for y in h:
		for x in w:
			for n in [3, 2]:
				if not free.call(x, y, n, n):
					continue
				var r := Rect2i(x, y, n, n)
				var d := dist[(y + n / 2) * w + x + n / 2]
				if d < STATUE_NEAR and rng.randf() < STATUE_CHANCE:
					_statue(r, rng, walls, cornices)
				else:
					_building(r, d, rng, walls, cornices)
				take.call(r)
				break
	# Laternen: an Straßenkreuzungen und Straßenmitten in der Stadt, dazu entlang des Spielfeldrands
	for y in h:
		for x in w:
			var k := y * w + x
			var crossing := x % (BLOCK / 2) == 0 and y % (BLOCK / 2) == 0 and used[k] == 2
			var rim := dist[k] == float(GAP) and (x * 7 + y * 13) % LAMP_EVERY == 0
			if (crossing and dist[k] > GAP) or rim:
				_lantern(Vector2i(x, y), cornices, lamps)
				continue
			# Flaggenreihen: entlang der Straßen nah am Spielfeld, das Tuch zeigt die Straße entlang
			if used[k] == 2 and dist[k] > GAP and dist[k] <= FLAG_NEAR:
				var vertical := x % BLOCK < STREET
				var along := y if vertical else x
				if along % FLAG_EVERY == 1 and not (x % BLOCK < STREET and y % BLOCK < STREET):
					_flag(Vector2i(x, y), 90.0 if vertical else 0.0, cornices, flags)
	_walls = _multimesh(walls.size(), true)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_walls.material_override = mat
	for i in walls.size():
		_walls.multimesh.set_instance_transform(i, walls[i][0])
		_walls.multimesh.set_instance_color(i, walls[i][1])
	_cornices = _multimesh(cornices.size(), false)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = CORNICE
	cm.metallic = 0.6
	cm.roughness = 0.45
	_cornices.material_override = cm
	_cornices.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in cornices.size():
		_cornices.multimesh.set_instance_transform(i, cornices[i])
	_lamps = _multimesh(lamps.size(), false)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = LAMP * 2.2
	_lamps.material_override = lm
	_lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in lamps.size():
		_lamps.multimesh.set_instance_transform(i, lamps[i])
	var pyr_mesh := CylinderMesh.new()
	pyr_mesh.top_radius = 0.0
	pyr_mesh.bottom_radius = sqrt(0.5)
	pyr_mesh.height = 1.0
	pyr_mesh.radial_segments = 4
	pyr_mesh.rings = 1
	_pyramids = _multimesh(pyramids.size(), true, pyr_mesh)
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.metallic = 0.7
	pm.roughness = 0.35
	_pyramids.material_override = pm
	for i in pyramids.size():
		_pyramids.multimesh.set_instance_transform(i, pyramids[i][0])
		_pyramids.multimesh.set_instance_color(i, pyramids[i][1])
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.5
	beacon_mesh.height = 1.0
	var beacon_mm := _multimesh(beacons.size(), false, beacon_mesh)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(2.6, 0.25, 0.15)
	beacon_mm.material_override = bm
	beacon_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in beacons.size():
		beacon_mm.multimesh.set_instance_transform(i, beacons[i])
	_flags = MultiMeshInstance3D.new()
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.subdivide_width = 8
	quad.subdivide_depth = 2
	fm.mesh = quad
	fm.instance_count = flags.size()
	_flags.multimesh = fm
	var flag_mat := ShaderMaterial.new()
	flag_mat.shader = FLAG_SHADER
	flag_mat.set_shader_parameter("cloth", FLAG_BLUE)
	_flags.material_override = flag_mat
	add_child(_flags)
	for i in flags.size():
		fm.set_instance_transform(i, flags[i])
	if plaza.size.x > 0:
		fountain = MaulFountain.new()
		var pc := (Vector2(plaza.position) + Vector2(plaza.size) / 2.0) * Board3D.CELL
		fountain.position = Vector3(pc.x, 0, pc.y)
		add_child(fountain)
		fountain.build(float(plaza.size.x) * Board3D.CELL)


## Gehört das Feld zur Stadt (Boden dort ohne Gitterlinien)?
func is_city(c: Vector2i) -> bool:
	var k := c.y * _width + c.x
	return c.x >= 0 and c.x < _width and k >= 0 and k < _dist.size() and _dist[k] > 1.0


## Anzahl Laternen (für Tests).
func lamp_count() -> int:
	return _lamps.multimesh.instance_count if _lamps != null else 0


## Anzahl Flaggen (für Tests).
func flag_count() -> int:
	return _flags.multimesh.instance_count if _flags != null else 0


## Anzahl Gebäudeteile (für Tests).
func part_count() -> int:
	return _walls.multimesh.instance_count if _walls != null else 0


## Grundstück zufällig in kleinere teilen, bis es höchstens LOT_MAX breit ist (manchmal früher stoppen).
func _split(r: Rect2i, rng: RandomNumberGenerator, out: Array[Rect2i]) -> void:
	var can_x := r.size.x >= LOT_MIN * 2
	var can_y := r.size.y >= LOT_MIN * 2
	var must := r.size.x > LOT_MAX or r.size.y > LOT_MAX
	if (not can_x and not can_y) or (not must and rng.randf() < 0.45):
		out.append(r)
		return
	var along_x := can_x and (not can_y or r.size.x > r.size.y or (r.size.x == r.size.y and rng.randf() < 0.5))
	var n := r.size.x if along_x else r.size.y
	var cut := rng.randi_range(LOT_MIN, n - LOT_MIN)
	if along_x:
		_split(Rect2i(r.position, Vector2i(cut, r.size.y)), rng, out)
		_split(Rect2i(r.position + Vector2i(cut, 0), Vector2i(r.size.x - cut, r.size.y)), rng, out)
	else:
		_split(Rect2i(r.position, Vector2i(r.size.x, cut)), rng, out)
		_split(Rect2i(r.position + Vector2i(0, cut), Vector2i(r.size.x, r.size.y - cut)), rng, out)


## Ein Gebäude auf Grundstück r: 1–3 Stufen, jede schmaler; oben auf jeder Stufe ein Gesims.
func _building(r: Rect2i, d: float, rng: RandomNumberGenerator, walls: Array, cornices: Array) -> void:
	const INSET := 0.05
	var size := Vector2(r.size) * Board3D.CELL - Vector2(INSET, INSET) * 2.0
	var center := (Vector2(r.position) + Vector2(r.size) / 2.0) * Board3D.CELL
	var total := minf(H_BASE + maxf(d - GAP, 0.0) * H_STEP, H_MAX) * rng.randf_range(0.55, 1.3)
	var col := _facade(rng)
	var tiers := 1
	if total > 0.9:
		tiers = rng.randi_range(1, 3)
	elif total > 0.5:
		tiers = rng.randi_range(1, 2)
	var shares: Array = [[1.0], [0.65, 0.35], [0.5, 0.3, 0.2]][tiers - 1]
	var y := 0.0
	var foot := size
	for t in tiers:
		if t > 0:
			foot *= rng.randf_range(0.55, 0.8)
		var part := maxf(total * float(shares[t]), 0.12)
		var basis := Basis.from_scale(Vector3(foot.x, part, foot.y))
		walls.append([Transform3D(basis, Vector3(center.x, y + part / 2.0, center.y)), col])
		if t == 0 and total > PIER_HEIGHT:
			_piers(center, foot, y, part * 0.92, cornices)
		y += part
		# Gesims als Band knapp unter der Dachkante, das Dach selbst bleibt in Wandfarbe
		cornices.append(Transform3D(Basis.from_scale(Vector3(foot.x + 0.03, 0.03, foot.y + 0.03)), Vector3(center.x, y - 0.035, center.y)))
	# schlanke Spitze auf hohen Türmen
	if total > 1.8 and rng.randf() < 0.5:
		var s := minf(foot.x, foot.y) * 0.18
		var tip := total * 0.18
		walls.append([Transform3D(Basis.from_scale(Vector3(s, tip, s)), Vector3(center.x, y + tip / 2.0, center.y)), col])


## Art-déco-Statue auf r: gestufter Sockel in Stein, darauf eine schlanke Messingfigur mit erhobenen Armen
## (wie Prometheus am Rockefeller Center), Blick in eine zufällige der vier Richtungen.
func _statue(r: Rect2i, rng: RandomNumberGenerator, walls: Array, cornices: Array) -> void:
	var s := minf(r.size.x, r.size.y) * Board3D.CELL / 1.0
	var c := (Vector2(r.position) + Vector2(r.size) / 2.0) * Board3D.CELL
	var yaw := Basis(Vector3.UP, rng.randi_range(0, 3) * PI / 2.0)
	var at := func(p: Vector3) -> Vector3:
		return Vector3(c.x, 0, c.y) + yaw * p
	var y := 0.0
	for step in [[0.8, 0.1], [0.62, 0.14], [0.45, 0.22]]:
		var f: float = step[0] * s
		var hgt: float = step[1] * s
		walls.append([Transform3D(yaw.scaled(Vector3(f, hgt, f)), Vector3(c.x, y + hgt / 2.0, c.y)), PLINTH])
		y += hgt
	cornices.append(Transform3D(yaw.scaled(Vector3(0.48 * s, 0.03, 0.48 * s)), Vector3(c.x, y, c.y)))
	# Figur: Beine/Körper als schlanke Säule, Kopf, zwei Arme schräg nach oben, Strahlenkranz dahinter
	var body := 0.5 * s
	cornices.append(Transform3D(yaw * Basis.from_scale(Vector3(0.1 * s, body, 0.07 * s)), at.call(Vector3(0, y + body / 2.0, 0))))
	cornices.append(Transform3D(yaw * Basis.from_scale(Vector3(0.08 * s, 0.08 * s, 0.08 * s)), at.call(Vector3(0, y + body + 0.05 * s, 0))))
	for side in [-1.0, 1.0]:
		var arm := Basis(Vector3.FORWARD, side * deg_to_rad(32.0)) * Basis.from_scale(Vector3(0.04 * s, 0.28 * s, 0.04 * s))
		cornices.append(Transform3D(yaw * arm, at.call(Vector3(side * 0.09 * s, y + body * 0.95 + 0.11 * s, 0))))
	for i in 5:
		var ang := deg_to_rad(-60.0 + i * 30.0)
		var ray := Basis(Vector3.FORWARD, ang) * Basis.from_scale(Vector3(0.02 * s, 0.22 * s, 0.015 * s))
		var off := Vector3(-sin(ang), cos(ang), 0) * 0.16 * s
		cornices.append(Transform3D(yaw * ray, at.call(Vector3(0, y + body * 0.8, -0.06 * s) + off)))


## Kleine Laterne auf Feld c: schlanker Messingmast, oben ein warm leuchtender Kasten.
func _lantern(c: Vector2i, cornices: Array, lamps: Array) -> void:
	var p := (Vector2(c) + Vector2(0.5, 0.5)) * Board3D.CELL
	const POLE := 0.42
	cornices.append(Transform3D(Basis.from_scale(Vector3(0.07, 0.05, 0.07)), Vector3(p.x, 0.025, p.y)))
	cornices.append(Transform3D(Basis.from_scale(Vector3(0.025, POLE, 0.025)), Vector3(p.x, POLE / 2.0, p.y)))
	lamps.append(Transform3D(Basis.from_scale(Vector3(0.07, 0.09, 0.07)), Vector3(p.x, POLE + 0.04, p.y)))
	cornices.append(Transform3D(Basis.from_scale(Vector3(0.09, 0.02, 0.09)), Vector3(p.x, POLE + 0.095, p.y)))


## Art-déco-Hochhaus auf Block r, einer von neun Typen nach echten Vorbildern (Lukas, 2026-11-08), alle
## aus Quadern, Pyramiden und Leuchtstreifen; nachts leuchten Kronen und Spitzen:
## New York: Chrysler (gestufte Krone mit Lichtschlitzen, Nadel), Empire State (viele Rücksprünge, Mast),
##   Rockefeller (schmale Scheibe mit seitlichen Stufen); Chicago: Carbide & Carbon (dunkelgrün mit goldener
##   Krone), Board of Trade (Pyramidendach mit Figur); Detroit: Fisher (steiles goldenes Dach), Guardian
##   (Ziegelrot, zwei achteckige Kronen), Penobscot (H-Stufen, rotes Leuchtfeuer); Europa: Boerentoren
##   Antwerpen (schlanker Stufenturm mit Laterne und Eckpfeilern).
func _skyscraper(r: Rect2i, d: float, rng: RandomNumberGenerator, o: Dictionary) -> void:
	var foot := Vector2(r.size) * Board3D.CELL - Vector2(0.1, 0.1)
	var c := (Vector2(r.position) + Vector2(r.size) / 2.0) * Board3D.CELL
	var total := rng.randf_range(SKY_HEIGHT.x, SKY_HEIGHT.y) * clampf(d / 40.0, 0.6, 1.0)
	var col := _facade(rng)
	var m := minf(foot.x, foot.y)
	var kind := rng.randi() % 9
	# Sockel (Kaufhaus-Geschoss) bei allen außer der Scheibe
	var y := 0.0
	if kind != 2:
		var podium := rng.randf_range(0.6, 0.9)
		_wall(o, c, Vector3(foot.x, podium, foot.y), 0.0, col)
		_band(o, c, foot.x, foot.y, podium)
		y = podium
	match kind:
		0:  # Chrysler
			var s := m * 0.5
			_wall(o, c, Vector3(s * 1.35, total * 0.18, s * 1.35), y, col)
			y += total * 0.18
			_band(o, c, s * 1.35, s * 1.35, y)
			var shaft := total * 0.45
			_wall(o, c, Vector3(s, shaft, s), y, col)
			_piers(c, Vector2(s, s), y, shaft, o.cornices)
			# Eckadler: Messingkragen an den Ecken oben am Schaft
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					_brass(o, c + Vector2(dx, dz) * s * 0.5, Vector3(0.14, 0.08, 0.14), y + shaft * 0.7)
			y += shaft
			_band(o, c, s, s, y)
			# Krone: fünf Stufen aus Metall mit Lichtschlitzen (die dreieckigen Fenster des Originals)
			var k := s * 0.85
			for i in 5:
				var hk := 0.5 - i * 0.05
				_brass(o, c, Vector3(k, hk, k), y)
				_lamp_slits(o, c, k, k, y + hk * 0.25, hk * 0.5, 3)
				y += hk
				k *= 0.78
			_pyr(o, c, Vector3(k * 1.2, total * 0.08, k * 1.2), y, CORNICE)
			y += total * 0.08
			_pyr(o, c, Vector3(0.07, total * 0.14, 0.07), y, CORNICE)
		1:  # Empire State
			var s := m * 0.8
			for i in 3:
				var hk := total * (0.12 - i * 0.025)
				_wall(o, c, Vector3(s, hk, s * 0.85), y, col)
				y += hk
				_band(o, c, s, s * 0.85, y)
				s *= 0.82
			var shaft := total * 0.4
			_wall(o, c, Vector3(s, shaft, s * 0.85), y, col)
			_piers(c, Vector2(s, s * 0.85), y, shaft, o.cornices)
			y += shaft
			for i in 3:
				s *= 0.8
				_wall(o, c, Vector3(s, 0.35, s * 0.85), y, col)
				y += 0.35
				_band(o, c, s, s * 0.85, y)
			# angestrahlte Spitze und Mast
			_lamp_slits(o, c, s * 0.8, s * 0.8 * 0.85, y - 0.9, 0.8, 4)
			_brass(o, c, Vector3(0.45, 0.9, 0.45), y)
			_lamp_slits(o, c, 0.45, 0.45, y + 0.15, 0.6, 2)
			y += 0.9
			_brass(o, c, Vector3(0.25, 0.5, 0.25), y)
			y += 0.5
			_pyr(o, c, Vector3(0.06, total * 0.12, 0.06), y, CORNICE)
		2:  # Rockefeller: schmale Scheibe, seitlich gestufte Flügel
			var long := foot.x * 0.9
			var thin := foot.y * 0.32
			var along_x := rng.randf() < 0.5
			var v := func(a: float, b: float) -> Vector3:
				return Vector3(a, 0, b) if along_x else Vector3(b, 0, a)
			for i in 4:
				var h := total * (0.3 + i * 0.22)
				var wdt := long * (1.0 - i * 0.2)
				var dep := thin * (1.6 - i * 0.2)
				var sz: Vector3 = v.call(wdt, dep)
				_wall(o, c, Vector3(sz.x, h, sz.z), 0.0, col)
				_band(o, c, sz.x, sz.z, h)
				if i == 3:
					_piers(c, Vector2(sz.x, sz.z), 0.0, h, o.cornices)
					_lamp_slits(o, c, sz.x, sz.z, h - 0.5, 0.35, 5)
		3:  # Carbide & Carbon: dunkelgrün mit goldener Krone
			var green := Color("1e4536")
			_wall(o, c, Vector3(foot.x * 0.92, 0.05, foot.y * 0.92), y, Color("101a16", 0.0))
			var s := m * 0.48
			var shaft := total * 0.6
			_wall(o, c, Vector3(s, shaft, s), y, green)
			_piers(c, Vector2(s, s), y, shaft, o.cornices)
			y += shaft
			_band(o, c, s, s, y)
			for i in 2:
				s *= 0.82
				_wall(o, c, Vector3(s, 0.6, s), y, green)
				y += 0.6
				_band(o, c, s, s, y)
			var t := s * 0.55
			_brass(o, c, Vector3(t, 1.2, t), y)
			_lamp_slits(o, c, t, t, y + 0.2, 0.8, 2)
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					_pyr(o, c + Vector2(dx, dz) * t * 0.5, Vector3(0.12, 0.6, 0.12), y + 1.2, CORNICE)
			y += 1.2
			_pyr(o, c, Vector3(t * 0.8, total * 0.12, t * 0.8), y, CORNICE)
		4:  # Board of Trade: breiter Turm, Pyramidendach in Kupfergrün, Figur obenauf
			var s := m * 0.55
			var shaft := total * 0.65
			for dx in [-1.0, 1.0]:
				_wall(o, c + Vector2(dx * s * 0.75, 0), Vector3(s * 0.4, shaft * 0.55, s * 1.1), y, col)
			_wall(o, c, Vector3(s, shaft, s * 0.9), y, col)
			_piers(c, Vector2(s, s * 0.9), y, shaft, o.cornices)
			y += shaft
			_band(o, c, s, s * 0.9, y)
			_lamp_slits(o, c, s, s * 0.9, y - 0.45, 0.3, 4)
			_pyr(o, c, Vector3(s * 0.95, total * 0.13, s * 0.85), y, Color("4f8a76"))
			y += total * 0.13
			_brass(o, c, Vector3(0.12, 0.45, 0.1), y - 0.05)
			_brass(o, c, Vector3(0.09, 0.09, 0.09), y + 0.42)
		5:  # Fisher Building: schlanker Turm mit steilem goldenem Dach
			for dx in [-1.0, 1.0]:
				_wall(o, c + Vector2(dx * m * 0.3, 0), Vector3(m * 0.3, total * 0.22, m * 0.8), y, col)
			var s := m * 0.42
			var shaft := total * 0.55
			_wall(o, c, Vector3(s, shaft, s), y, col)
			_piers(c, Vector2(s, s), y, shaft, o.cornices)
			y += shaft
			_band(o, c, s, s, y)
			s *= 0.85
			_wall(o, c, Vector3(s, 0.5, s), y, col)
			_lamp_slits(o, c, s, s, y + 0.1, 0.3, 4)
			y += 0.5
			_pyr(o, c, Vector3(s, total * 0.22, s), y, Color("d8b04a"))
		6:  # Guardian Building: Ziegelrot, zwei achteckige Kronen
			var brick := Color("a8573a")
			var s := m * 0.4
			var shaft := total * 0.5
			_wall(o, c, Vector3(m * 0.85, total * 0.2, m * 0.6), y, brick)
			for dx in [-1.0, 1.0]:
				var p := c + Vector2(dx * s * 0.55, 0)
				var h := shaft * (1.0 if dx < 0 else 0.82)
				_wall(o, p, Vector3(s, h, s), y, brick)
				_piers(p, Vector2(s, s), y, h, o.cornices)
				# Achteck aus zwei Quadern (gerade und um 45° gedreht)
				var k := s * 0.75
				_wall(o, p, Vector3(k, 0.7, k), y + h, brick)
				_wall(o, p, Vector3(k, 0.7, k), y + h, brick, PI / 4.0)
				_band(o, p, k, k, y + h + 0.7)
				_lamp_slits(o, p, k, k, y + h + 0.2, 0.35, 2)
				_pyr(o, p, Vector3(k * 0.8, 0.9, k * 0.8), y + h + 0.7, Color("c97a3a"))
		7:  # Penobscot: H-förmige Stufen, rotes Leuchtfeuer auf der Spitze
			var s := m * 0.6
			for i in 4:
				var h := total * (0.32 - i * 0.06)
				_wall(o, c, Vector3(s, h, s * 0.5), y, col)
				_wall(o, c, Vector3(s * 0.5, h, s), y, col)
				_piers(c, Vector2(s * 0.5, s * 0.5), y, h, o.cornices)
				y += h
				_band(o, c, s, s * 0.5, y)
				_band(o, c, s * 0.5, s, y)
				s *= 0.75
			_brass(o, c, Vector3(0.3, 0.4, 0.3), y)
			y += 0.4
			_pyr(o, c, Vector3(0.05, 0.6, 0.05), y, CORNICE)
			o.beacons.append(Transform3D(Basis.from_scale(Vector3(0.28, 0.28, 0.28)), Vector3(c.x, y + 0.15, c.y)))
		_:  # Boerentoren Antwerpen: schlanker Stufenturm mit Eckpfeilern und Laterne
			var s := m * 0.55
			for i in 4:
				var h := total * (0.3 - i * 0.05)
				_wall(o, c, Vector3(s, h, s), y, col)
				for dx in [-1.0, 1.0]:
					for dz in [-1.0, 1.0]:
						_wall(o, c + Vector2(dx, dz) * s * 0.48, Vector3(s * 0.1, h + 0.3, s * 0.1), y, col)
				y += h
				_band(o, c, s, s, y)
				s *= 0.72
			_wall(o, c, Vector3(s, 0.8, s), y, col)
			_lamp_slits(o, c, s, s, y + 0.15, 0.55, 3)
			y += 0.8
			_band(o, c, s, s, y)
			_brass(o, c, Vector3(s * 0.4, 0.5, s * 0.4), y)
			_pyr(o, c, Vector3(0.08, 0.9, 0.08), y + 0.5, CORNICE)


## Fassadenfarbe: meist Kalkstein, ein Teil farbig.
func _facade(rng: RandomNumberGenerator) -> Color:
	if rng.randf() < COLORED_SHARE:
		return COLORED[rng.randi() % COLORED.size()]
	return WALLS[rng.randi() % WALLS.size()]


func _wall(o: Dictionary, p: Vector2, size: Vector3, y0: float, col: Color, yaw := 0.0) -> void:
	o.walls.append([Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), Vector3(p.x, y0 + size.y / 2.0, p.y)), col])


func _brass(o: Dictionary, p: Vector2, size: Vector3, y0: float) -> void:
	o.cornices.append(Transform3D(Basis.from_scale(size), Vector3(p.x, y0 + size.y / 2.0, p.y)))


## Messingband knapp unter der Kante bei Höhe y.
func _band(o: Dictionary, p: Vector2, wx: float, wz: float, y: float) -> void:
	o.cornices.append(Transform3D(Basis.from_scale(Vector3(wx + 0.05, 0.05, wz + 0.05)), Vector3(p.x, y - 0.06, p.y)))


## Vierseitige Pyramide (Dach, Spitze) mit Grundfläche size.x × size.z.
func _pyr(o: Dictionary, p: Vector2, size: Vector3, y0: float, col: Color) -> void:
	o.pyramids.append([Transform3D(Basis.from_scale(size) * Basis(Vector3.UP, PI / 4.0), Vector3(p.x, y0 + size.y / 2.0, p.y)), col])


## Leuchtende senkrechte Schlitze an allen vier Seiten eines Quaders (sx × sz), n je Seite.
func _lamp_slits(o: Dictionary, p: Vector2, sx: float, sz: float, y0: float, h: float, n: int) -> void:
	for i in n:
		var t := (float(i) + 0.5) / n - 0.5
		for side in [-1.0, 1.0]:
			o.lamps.append(Transform3D(Basis.from_scale(Vector3(0.04, h, 0.02)), Vector3(p.x + t * sx, y0 + h / 2.0, p.y + side * (sz / 2.0 + 0.012))))
			o.lamps.append(Transform3D(Basis.from_scale(Vector3(0.02, h, 0.04)), Vector3(p.x + side * (sx / 2.0 + 0.012), y0 + h / 2.0, p.y + t * sz)))


## Senkrechte Messing-Lisenen an allen vier Seiten eines Quaders (Grundfläche foot, ab Höhe y0, Höhe hgt).
func _piers(center: Vector2, foot: Vector2, y0: float, hgt: float, cornices: Array) -> void:
	for axis in 2:
		var len_: float = foot.x if axis == 0 else foot.y
		var other: float = foot.y if axis == 0 else foot.x
		var n := clampi(int(len_ / 0.4), 2, 6)
		for i in n:
			var t := ((float(i) + 0.5) / n - 0.5) * len_
			for side in [-1.0, 1.0]:
				var pos := Vector3(center.x + t, y0 + hgt / 2.0, center.y + side * other / 2.0) if axis == 0 \
						else Vector3(center.x + side * other / 2.0, y0 + hgt / 2.0, center.y + t)
				var sc := Vector3(0.035, hgt, 0.03) if axis == 0 else Vector3(0.03, hgt, 0.035)
				cornices.append(Transform3D(Basis.from_scale(sc), pos))


## Fahnenmast mit königsblauem Tuch auf Feld c; yaw_deg = Richtung, in die das Tuch weht.
func _flag(c: Vector2i, yaw_deg: float, cornices: Array, flags: Array) -> void:
	var p := (Vector2(c) + Vector2(0.5, 0.5)) * Board3D.CELL
	cornices.append(Transform3D(Basis.from_scale(Vector3(0.08, 0.04, 0.08)), Vector3(p.x, 0.02, p.y)))
	cornices.append(Transform3D(Basis.from_scale(Vector3(0.025, FLAG_POLE, 0.025)), Vector3(p.x, FLAG_POLE / 2.0, p.y)))
	cornices.append(Transform3D(Basis.from_scale(Vector3(0.04, 0.04, 0.04)), Vector3(p.x, FLAG_POLE + 0.02, p.y)))
	# Tuch: Quad 1×1 um seine Mitte, linke Kante am Mast
	var size := Vector2(0.46, 0.27)
	var yaw := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var basis := yaw * Basis.from_scale(Vector3(size.x, size.y, 1.0))
	var off := yaw * Vector3(size.x / 2.0 + 0.01, 0, 0)
	flags.append(Transform3D(basis, Vector3(p.x, FLAG_POLE - size.y / 2.0 - 0.03, p.y) + off))


## Platz für den Atlas-Brunnen: freies Quadrat (PLAZA Felder, nur Stadt) möglichst nah an der Kartenmitte.
## Kartenmitte = Mittel der Spielergebiete; gesucht wird in Schritten von 2 Feldern.
func _plaza_rect(map: MaulMap, dist: PackedFloat32Array) -> Rect2i:
	var w := map.width
	var mid := Vector2.ZERO
	for z in map.zones:
		mid += Vector2(z.rect.position) + Vector2(z.rect.size) / 2.0
	mid /= maxf(map.zones.size(), 1)
	var best := Rect2i()
	var best_d := INF
	for y in range(0, map.height - PLAZA, 2):
		for x in range(0, w - PLAZA, 2):
			var d := (Vector2(x, y) + Vector2(PLAZA, PLAZA) / 2.0).distance_squared_to(mid)
			if d >= best_d:
				continue
			var ok := true
			for yy in range(y, y + PLAZA):
				for xx in range(x, x + PLAZA):
					if dist[yy * w + xx] <= GAP:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = Rect2i(x, y, PLAZA, PLAZA)
				best_d = d
	return best


## Schmuck des Brunnenplatzes: Flaggen im Kreis um den Brunnen, Laternen in den Ecken.
func _plaza_dressing(r: Rect2i, cornices: Array, lamps: Array, flags: Array) -> void:
	var c := Vector2(r.position) + Vector2(r.size) / 2.0
	var rad := float(r.size.x) / 2.0 - 1.5
	for i in 12:
		var a := TAU * float(i) / 12.0 + PI / 12.0
		var cell := Vector2i((c + Vector2(cos(a), sin(a)) * rad).floor())
		# Tuch weht im Kreis herum (tangential)
		_flag(cell, -rad_to_deg(a) - 90.0, cornices, flags)
	for corner in [Vector2i(1, 1), Vector2i(r.size.x - 2, 1), Vector2i(1, r.size.y - 2), Vector2i(r.size.x - 2, r.size.y - 2)]:
		_lantern(r.position + corner, cornices, lamps)


## Abstand (Felder, Schachbrett) jedes Felds zum nächsten Feld, das Gegner erreichen oder auf dem
## gebaut wird: Flutfüllung über begehbare Felder ab allen Wegpunkten und der Mall, dazu alle Spielergebiete.
func _distance_to_reachable(map: MaulMap) -> PackedFloat32Array:
	var w := map.width
	var h := map.height
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(1e6)
	var queue: Array[Vector2i] = []
	var seeds: Array[Vector2i] = map.all_waypoints().duplicate()
	var mall: Array = map.maul.get("mall", [])
	if mall.size() == 2:
		seeds.append(MaulMap.cell(mall))  # Mall-Hof unter dem Hauptgebiet
	for p in seeds:
		if map.in_bounds(p) and dist[p.y * w + p.x] > 0.0:
			dist[p.y * w + p.x] = 0.0
			queue.append(p)
	var i := 0
	const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while i < queue.size():
		var c := queue[i]
		i += 1
		for dv in DIRS:
			var n: Vector2i = c + dv
			if map.in_bounds(n) and dist[n.y * w + n.x] > 0.0 and map.get_tile(n) != MapData.BLOCKED:
				dist[n.y * w + n.x] = 0.0
				queue.append(n)
	# Gebiete und Leak-Fläche erst nach der Flutfüllung, sonst hielten sie sie auf
	for z in map.zones:
		for y in range(z.rect.position.y, z.rect.end.y):
			for x in range(z.rect.position.x, z.rect.end.x):
				if map.in_bounds(Vector2i(x, y)):
					dist[y * w + x] = 0.0
	var leak: Array = map.maul.get("leak", [])
	if leak.size() == 4:
		for y in range(int(leak[1]), int(leak[1]) + int(leak[3])):
			for x in range(int(leak[0]), int(leak[0]) + int(leak[2])):
				if map.in_bounds(Vector2i(x, y)):
					dist[y * w + x] = 0.0
	# Abstand zur erreichbaren Fläche (zwei Durchläufe, Schachbrett-Metrik)
	for y in h:
		for x in w:
			var k := y * w + x
			var v := dist[k]
			if x > 0: v = minf(v, dist[k - 1] + 1.0)
			if y > 0:
				v = minf(v, dist[k - w] + 1.0)
				if x > 0: v = minf(v, dist[k - w - 1] + 1.0)
				if x < w - 1: v = minf(v, dist[k - w + 1] + 1.0)
			dist[k] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var k := y * w + x
			var v := dist[k]
			if x < w - 1: v = minf(v, dist[k + 1] + 1.0)
			if y < h - 1:
				v = minf(v, dist[k + w] + 1.0)
				if x < w - 1: v = minf(v, dist[k + w + 1] + 1.0)
				if x > 0: v = minf(v, dist[k + w - 1] + 1.0)
			dist[k] = v
	return dist


func _multimesh(count: int, colors: bool, mesh: Mesh = null) -> MultiMeshInstance3D:
	var box: Mesh = mesh if mesh != null else BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = box
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi
