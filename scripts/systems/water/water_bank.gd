class_name WaterBank
extends RefCounted
## Statische Böschung aus den echten Flussband-Kanten: nasses Innenufer, erhöhte Krone, Geländeanschluss.
## Kein eigener Prozess und keine Kollision; Bau-/Laufregeln bleiben beim Modus.


static func validate(options: Variant) -> String:
	if not options is Dictionary:
		return "banks muss ein Objekt sein"
	if options.has("enabled") and not options.enabled is bool:
		return "banks.enabled muss boolesch sein"
	if str(options.get("style", "auto")) not in ["auto", "natural", "city"]:
		return "unbekannter Uferstil"
	if options.has("rocks") and not options.rocks is bool:
		return "banks.rocks muss boolesch sein"
	for key in ["width", "height", "depth", "ground_height", "variation", "city_width"]:
		if not options.has(key):
			continue
		var value = options[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return "ungültiger Uferwert: " + key
		if key == "variation":
			if float(value) < 0 or float(value) > 1:
				return "banks.variation muss zwischen 0 und 1 liegen"
			continue
		if key != "ground_height" and (float(value) < (0.05 if key in ["width", "depth"] else 0.0) or float(value) > 8.0):
			return "Uferwert außerhalb des Budgets: " + key
	for key in ["soil_color", "grass_color"]:
		if options.has(key) and (not options[key] is String or not Color.html_is_valid(options[key])):
			return "ungültige Uferfarbe: " + key
	return ""


static func build(body: WaterBody, options: Dictionary, ground: Callable, neighbors: Array, fall_ends: Array) -> MeshInstance3D:
	if not bool(options.get("enabled", true)) or body.shore_left.size() < 2:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var soil := Color(str(options.get("soil_color", "66523f")))
	var grass := Color(str(options.get("grass_color", "65704a")))
	var city := str(options.get("style", "natural")) == "city"
	var colors: Array[Color] = [soil.darkened(0.25), soil, soil.lerp(grass, 0.4), grass, grass, grass, grass]
	if city:
		colors.assign([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var count := 0
	var stones: Array[Transform3D] = []
	var sides := [body.shore_left, body.shore_right]
	for side in sides:
		var rows := []
		for i in side.size():
			var center: Vector3 = (body.shore_left[i] + body.shore_right[i]) * 0.5
			var outward: Vector3 = (side[i] - center).normalized()
			var along: float = body._distances[i]
			var end_blend := smoothstep(0, 1.6, minf(along, body.path_length - along))
			var row := _profile(side[i], outward, options, ground, end_blend)
			if ground.is_valid():
				for end: Vector3 in fall_ends:
					if absf(center.y - end.y) > 0.1 or Vector2(center.x - end.x, center.z - end.z).length() > 0.4:
						continue
					# Die Außenkante gehört noch zur oberen Terrasse, auch wenn die Höhentextur
					# am exakt gleichen Rasterpunkt schon die tiefe Seite der Stufe liefert.
					var tangent: Vector3 = body._samples[mini(i + 1, side.size() - 1)] - body._samples[maxi(i - 1, 0)]
					var behind := center - tangent.normalized() * 0.3
					if float(ground.call(behind.x, behind.z)) >= center.y - 0.35:
						row[-1].y = maxf(row[-1].y, center.y - 0.05)
			rows.append(row)
			if not city and bool(options.get("rocks", true)) and stones.size() < 96 and end_blend > 0.5:
				if i > 0 and floori(along / 1.4) != floori(body._distances[i - 1] / 1.4) and _noise(side[i] * 1.7) > -0.15:
					var at: Vector3 = row[3].lerp(row[4], 0.3 + (_noise(center) + 1) * 0.15)
					if not WaterBody.in_water(at, neighbors):
						var radius := 0.12 + (_noise(at * 2.3) + 1) * 0.085
						var basis := Basis.from_euler(Vector3(0.2, at.x + at.z, -0.15)).scaled(Vector3(radius * 1.4, radius * 0.75, radius))
						stones.append(Transform3D(basis, at + Vector3.UP * radius * 0.3))
		for i in range(rows.size() - 1):
			for band in range(colors.size() - 1):
				count += _quad(st, rows[i][band], rows[i][band + 1], rows[i + 1][band], rows[i + 1][band + 1], colors[band], colors[band + 1], neighbors)
		# Stirnflächen der einzelnen Uferkörper schließen, ohne das Flussbett zu versperren.
		for end in [0, rows.size() - 1]:
			var row: Array = rows[end]
			for band in range(1, row.size() - 1):
				count += _quad(st, row[0], row[band], row[0], row[band + 1], soil, grass, neighbors)
	# Das Bett schließt auch einen über ebenem Boden platzierten Fluss von unten.
	var depth := float(options.get("depth", 0.35))
	for i in range(body.shore_left.size() - 1):
		count += _quad(st, body.shore_left[i] + Vector3.DOWN * depth, body.shore_right[i] + Vector3.DOWN * depth, body.shore_left[i + 1] + Vector3.DOWN * depth, body.shore_right[i + 1] + Vector3.DOWN * depth, soil.darkened(0.25), soil.darkened(0.25), [])
	# Nur freie Quellen/Enden abrunden; Wasserfälle und Mündungen bleiben durchgängig offen.
	for end in [0, body.shore_left.size() - 1]:
		var center: Vector3 = (body.shore_left[end] + body.shore_right[end]) * 0.5
		if WaterBody.in_water(center, neighbors) or fall_ends.any(func(p): return p.distance_to(center) < body.body_width * 0.5 + WaterBody.LINK_TOLERANCE):
			continue
		var across: Vector3 = (body.shore_left[end] - center).normalized()
		var radius: float = center.distance_to(body.shore_left[end])
		var sign_dir := -1.0 if end == 0 else 1.0
		var previous := []
		for i in 13:
			var outward := across.rotated(Vector3.UP, sign_dir * PI * i / 12.0)
			# Äußere Hälfte unabhängig von der Orientierung des Flussbands wählen.
			var flow: Vector3 = body._samples[1] - body._samples[0] if end == 0 else body._samples[-1] - body._samples[-2]
			if outward.dot(flow) * sign_dir < -0.001:
				outward = across.rotated(Vector3.UP, -sign_dir * PI * i / 12.0)
			var row := _profile(center + outward * radius, outward, options, ground, 0.0)
			if not previous.is_empty():
				for band in range(colors.size() - 1):
					count += _quad(st, previous[band], previous[band + 1], row[band], row[band + 1], colors[band], colors[band + 1], neighbors)
			previous = row
	if count == 0:
		return null
	st.index()
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "RiverBanks"
	node.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if city:
		var pavement := ShaderMaterial.new()
		pavement.shader = preload("res://assets/shaders/water_pavement.gdshader")
		pavement.set_shader_parameter("cobble_tex", preload("res://assets/textures/ground/cobble.jpg"))
		node.material_override = pavement
	else:
		node.material_override = material
		_add_stones(node, stones)
	node.set_meta("bank_style", "city" if city else "natural")
	return node


static func _profile(edge: Vector3, outward: Vector3, options: Dictionary, ground: Callable, end_blend := 1.0) -> Array[Vector3]:
	var city := str(options.get("style", "natural")) == "city"
	var variation := 0.0 if city else float(options.get("variation", 0.75))
	var width := float(options.get("city_width", 1.35)) if city else float(options.get("width", 0.9)) * (1 + _noise(edge) * variation * 0.32)
	var height := float(options.get("height", 0.16))
	if not city:
		height *= lerpf(1, 0.45 + (_noise(edge * 0.7) + 1) * 0.5, variation)
		height *= lerpf(0.08, 1, end_blend)
		width *= lerpf(0.55, 1, end_blend)
	var foot := edge + outward * width
	foot.y = float(ground.call(foot.x, foot.z)) if ground.is_valid() else float(options.get("ground_height", 0.0))
	foot.y -= 0.025  # knapp in den Boden einlassen: keine offene Lichtfuge
	# Unter Fallkurven verlängerte Unterläufe dürfen keine Uferspitzen zur oberen Klippe hochziehen.
	foot.y = minf(foot.y, edge.y + height * 0.4)
	var crest := edge + outward * minf(width * 0.3, 0.25)
	crest.y = edge.y + height
	var wet := edge - outward * 0.035 + Vector3.DOWN * 0.055
	var bed := edge + Vector3.DOWN * float(options.get("depth", 0.35))
	if city:
		var wall := edge + outward * 0.015
		wall.y = edge.y + height
		var curb := edge + outward * 0.16
		curb.y = wall.y
		var walk := edge + outward * 0.18
		walk.y = wall.y - 0.035
		var rim := edge + outward * (width - 0.06)
		rim.y = walk.y
		return [bed, wet, wall, curb, walk, rim, foot]
	# Mehrere querliegende Stützreihen runden die Krone und lassen die Böschung flach auslaufen.
	var shoulder := edge + outward * width * 0.43
	shoulder.y = lerpf(crest.y, foot.y, 0.18) + maxf(_noise(edge * 1.3), 0) * variation * 0.12 * end_blend
	var slope := edge + outward * width * 0.7
	slope.y = lerpf(crest.y, foot.y, 0.7)
	var feather := edge + outward * width * 0.9
	feather.y = lerpf(crest.y, foot.y, 0.97)
	return [bed, wet, crest, shoulder, slope, feather, foot]


static func _noise(p: Vector3) -> float:
	return sin(p.x * 1.13 + p.z * 0.67) * 0.5 + sin(p.x * 0.43 - p.z * 1.71) * 0.3 + sin(p.x * 2.1 + p.z * 1.2) * 0.2


static func _add_stones(parent: MeshInstance3D, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var stones := MultiMeshInstance3D.new()
	stones.name = "BankStones"
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 7
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("72756c")
	material.roughness = 0.95
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	stones.multimesh = multimesh
	parent.add_child(stones)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inner: Color, outer: Color, neighbors: Array) -> int:
	# Keine Erdschwelle quer durch anschließendes Wasser, auch bei seitlichen Zusammenflüssen.
	var middle := (a + b + c + d) * 0.25
	middle.y = maxf(a.y, c.y) + 0.055
	if WaterBody.in_water(middle, neighbors):
		return 0
	for triangle in [[[a, inner], [b, outer], [c, inner]], [[b, outer], [d, outer], [c, inner]]]:
		if (triangle[1][0] - triangle[0][0]).cross(triangle[2][0] - triangle[0][0]).y < 0:
			triangle.reverse()
		for item in triangle:
			st.set_color(item[1])
			st.set_uv(Vector2(item[0].x, item[0].z))
			st.add_vertex(item[0])
	return 1
