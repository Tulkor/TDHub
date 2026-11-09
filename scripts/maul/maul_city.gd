class_name MaulCity
extends Node3D
## Blockstadt um das Spielfeld von Shopping Maul: Quader in Petrol (Farbton und Sättigung wie der
## Marmorboden), gestuft wie Art-déco-Hochhäuser, mit Gesimsen in mattem Messing. Steht nur auf Feldern,
## die kein Gegner je erreicht (Flutfüllung von allen Wegpunkten aus) und die in keinem Spielergebiet
## liegen, mit Abstand zu allem Begehbaren. Nah am Spielfeld niedrig, nach außen höher, damit die
## schräge Kamera nichts verdeckt. Weiter draußen stehen einzelne Art-déco-Hochhäuser wie in New York
## oder Chicago (Sockel, Schaft mit Lisenen, Rücksprünge, gestufte Messingkrone, Spitze).
## Restflächen zwischen den Blöcken füllen kleine Häuser und Art-déco-Statuen (Messingfigur mit
## erhobenen Armen auf gestuftem Sockel); kleine Laternen stehen an Straßenkreuzungen und entlang des
## Spielfeldrands. Alles in drei MultiMeshes (Wände, Messing, Laternenlicht).

const SHADER := preload("res://assets/shaders/city.gdshader")
## Straßenraster: alle BLOCK Felder eine Straße von STREET Feldern
const BLOCK := 14
const STREET := 1
## Grundstücke innerhalb eines Blocks: Kantenlänge in Feldern
const LOT_MIN := 3
const LOT_MAX := 7
## Felder Abstand zu allem Begehbaren
const GAP := 2
## Höhe in Einheiten: Grundhöhe + Zuwachs je Feld Abstand zum Spielfeld, gedeckelt
const H_BASE := 0.5
const H_STEP := 0.07
const H_MAX := 4.2
## Hochhäuser: nehmen einen ganzen Block ein, erst ab SKY_DIST Feldern Abstand, mit dieser Wahrscheinlichkeit
const SKY_DIST := 12.0
const SKY_CHANCE := 0.3
const SKY_HEIGHT := Vector2(8.0, 14.0)
const PIER := Color("2a5a60")
## Wandfarben (gemischt), Gesims
const WALLS := [Color("0f2b31"), Color("133238"), Color("0c2429"), Color("173a40"), Color("112e33"), Color("15353a")]
const CORNICE := Color("7d6a48")
## Statuen und Laternen
const PLINTH := Color("244649")
const LAMP := Color("ffd9a0")
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
	for by in range(0, h, BLOCK):
		for bx in range(0, w, BLOCK):
			var block := Rect2i(bx + STREET, by + STREET, BLOCK - STREET, BLOCK - STREET)
			var bd := dist[mini(block.get_center().y, h - 1) * w + mini(block.get_center().x, w - 1)]
			if bd >= SKY_DIST and rng.randf() < SKY_CHANCE and free.call(block.position.x, block.position.y, block.size.x, block.size.y):
				_skyscraper(block, bd, rng, walls, cornices)
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
	Metall.veredeln(cm)
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


## Gehört das Feld zur Stadt (Boden dort ohne Gitterlinien)?
func is_city(c: Vector2i) -> bool:
	var k := c.y * _width + c.x
	return c.x >= 0 and c.x < _width and k >= 0 and k < _dist.size() and _dist[k] > 1.0


## Anzahl Laternen (für Tests).
func lamp_count() -> int:
	return _lamps.multimesh.instance_count if _lamps != null else 0


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
	var col: Color = WALLS[rng.randi() % WALLS.size()]
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


## Art-déco-Hochhaus auf Block r: breiter Sockel, Schaft mit senkrechten Lisenen, mehrere Rücksprünge
## mit Messingbändern, oben eine gestufte Messingkrone mit Spitze (New York) oder vier Ecktürmchen (Chicago).
func _skyscraper(r: Rect2i, d: float, rng: RandomNumberGenerator, walls: Array, cornices: Array) -> void:
	var foot := Vector2(r.size) * Board3D.CELL - Vector2(0.1, 0.1)
	var c := (Vector2(r.position) + Vector2(r.size) / 2.0) * Board3D.CELL
	var col: Color = WALLS[rng.randi() % WALLS.size()]
	var box := func(size: Vector3, y0: float, list: Array, color = null) -> void:
		var xf := Transform3D(Basis.from_scale(size), Vector3(c.x, y0 + size.y / 2.0, c.y))
		list.append([xf, color] if color != null else xf)
	var band := func(wx: float, wz: float, y: float) -> void:
		cornices.append(Transform3D(Basis.from_scale(Vector3(wx + 0.05, 0.05, wz + 0.05)), Vector3(c.x, y - 0.06, c.y)))
	var total := rng.randf_range(SKY_HEIGHT.x, SKY_HEIGHT.y) * clampf(d / 40.0, 0.6, 1.0)
	# Sockel
	var podium := rng.randf_range(0.7, 1.1)
	box.call(Vector3(foot.x, podium, foot.y), 0.0, walls, col)
	band.call(foot.x, foot.y, podium)
	# Schaft
	var sx := minf(foot.x, foot.y) * rng.randf_range(0.4, 0.5)
	var sz := sx * rng.randf_range(0.85, 1.15)
	var shaft := total * 0.62
	var y := podium
	box.call(Vector3(sx, shaft, sz), y, walls, col)
	# Lisenen: schmale helle Pfeiler über die ganze Schafthöhe, je Seite gleichmäßig verteilt
	var n := rng.randi_range(5, 7)
	for i in n:
		var t := (float(i) + 0.5) / n - 0.5
		for side in [-1.0, 1.0]:
			walls.append([Transform3D(Basis.from_scale(Vector3(0.06, shaft, 0.1)), Vector3(c.x + t * sx, y + shaft / 2.0, c.y + side * sz / 2.0)), PIER])
			walls.append([Transform3D(Basis.from_scale(Vector3(0.1, shaft, 0.06)), Vector3(c.x + side * sx / 2.0, y + shaft / 2.0, c.y + t * sz)), PIER])
	y += shaft
	band.call(sx, sz, y)
	# Rücksprünge
	var rest := total - shaft - podium
	for k in 3:
		sx *= 0.78
		sz *= 0.78
		var part: float = rest * [0.4, 0.3, 0.3][k] * 0.7
		box.call(Vector3(sx, part, sz), y, walls, col)
		y += part
		band.call(sx, sz, y)
	if rng.randf() < 0.6:
		# New York: gestufte Krone aus Messing und eine hohe Spitze
		var kx := sx
		for k in 4:
			kx *= 0.72
			box.call(Vector3(kx, 0.22, kx), y, cornices)
			y += 0.22
		box.call(Vector3(0.05, total * 0.22, 0.05), y, cornices)
	else:
		# Chicago: flaches Dach mit vier Ecktürmchen und einer Laterne in der Mitte
		for dx in [-1.0, 1.0]:
			for dz in [-1.0, 1.0]:
				var tx := Transform3D(Basis.from_scale(Vector3(sx * 0.2, 0.55, sz * 0.2)), Vector3(c.x + dx * sx * 0.38, y + 0.275, c.y + dz * sz * 0.38))
				walls.append([tx, col])
				cornices.append(Transform3D(Basis.from_scale(Vector3(sx * 0.12, 0.25, sz * 0.12)), tx.origin + Vector3(0, 0.4, 0)))
		box.call(Vector3(sx * 0.4, 0.8, sz * 0.4), y, walls, col)
		box.call(Vector3(sx * 0.25, 0.35, sz * 0.25), y + 0.8, cornices)


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


func _multimesh(count: int, colors: bool) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = box
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi
