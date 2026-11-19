class_name HdGothic
extends RefCounted
## Gotische Bauteile für die Spielgebäude von Bollwerk: Torwerke (Vorwerk, Innentor) samt Ruine,
## Teleport-Schreine und Spawn-Portale. Jedes Gebäude wird zu einem Mesh mit einer Fläche je Material
## zusammengefasst (ein Knoten statt vieler Einzelteile). Materialien teilt es mit HdCathedral.
## Rein optisch: Trefferflächen, Radien und Höhen der Spiellogik bleiben unverändert.

static var _shapes := {}
static var _materials := {}
const PORTAL_COLOR := Color("b46bff")
var _parts := {}   ## Material-ID -> {material, items: [[Mesh, Transform3D]]}


static func shape(kind: String) -> Mesh:
	if _shapes.has(kind):
		return _shapes[kind]
	var mesh: Mesh
	if kind == "box":
		mesh = BoxMesh.new()
	elif kind == "lancet":
		# Spitzbogenfenster, Ursprung unten Mitte, zeigt nach +Z.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(-0.5, 0, 0), Vector3(0.5, 0.68, 0), Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(-0.5, 0.68, 0), Vector3(0.5, 0.68, 0),
				Vector3(-0.5, 0.68, 0), Vector3(0.22, 0.9, 0), Vector3(0.5, 0.68, 0), Vector3(-0.5, 0.68, 0), Vector3(-0.22, 0.9, 0), Vector3(0.22, 0.9, 0),
				Vector3(-0.22, 0.9, 0), Vector3(0, 1, 0), Vector3(0.22, 0.9, 0)]:
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(v)
		mesh = st.commit()
	else:
		# prism = achteckige Säule, spire = achteckige Spitze, pyramid = vierseitige Spitze (Kante 1).
		var c := CylinderMesh.new()
		c.height = 1.0
		c.radial_segments = 4 if kind == "pyramid" else 8
		c.rings = 1
		c.bottom_radius = 0.7071 if kind == "pyramid" else 1.0
		c.top_radius = 1.0 if kind == "prism" else 0.0
		mesh = c
	_shapes[kind] = mesh
	return mesh


## Quaderstein der Spielgebäude (hd_gothic_stone.gdshader), leicht strukturiert statt flach.
static func stone() -> Material:
	return _stone_material("stone", Color("39404c"), Vector2(0.62, 0.31), 0.018)


## Gesimse und Leisten: hellerer, glatter behauener Stein mit langen Blöcken.
static func trim() -> Material:
	return _stone_material("trim", Color("6c6f7c"), Vector2(1.1, 0.42), 0.012)


static func _stone_material(id: String, color: Color, block: Vector2, grout: float) -> ShaderMaterial:
	if not _materials.has(id):
		var m := ShaderMaterial.new()
		m.shader = preload("res://assets/shaders/hd_gothic_stone.gdshader")
		m.set_shader_parameter("stone_color", color)
		m.set_shader_parameter("block_size", block)
		m.set_shader_parameter("grout_width", grout)
		_materials[id] = m
	return _materials[id]


## Leuchtender Runenkreis (waagrecht, Durchmesser size) in der Farbe color.
static func rune_circle(color: Color, size: float, strength := 0.4, glow_energy := 1.5) -> MeshInstance3D:
	var key := "runes_%s_%s" % [color.to_html(), glow_energy]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://assets/shaders/hd_rune_circle.gdshader")
		m.set_shader_parameter("rune_color", color)
		m.set_shader_parameter("glow", glow_energy)
		_materials[key] = m
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.name = "Runenkreis"
	mi.mesh = plane
	mi.material_override = _materials[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("strength", strength)
	return mi


## Plasma-Wirbel im Torbogen (senkrecht, Breite x Höhe). Ruhig eine kleine Plasmakugel,
## bei surge 1 füllt er den Bogen (siehe set_portal_surge).
static func vortex(width: float, height: float, color: Color) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/hd_portal_vortex.gdshader")
	m.set_shader_parameter("portal_color", color)
	m.set_shader_parameter("quad_size", Vector2(width, height))
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var mi := MeshInstance3D.new()
	mi.name = "Wirbel"
	mi.mesh = quad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("strength", 0.0)
	return mi


## Spawn-Stärke eines Portals aus portal(): 0 = Ruhe (Plasmakugel), 1 = Gegner kommen (Wirbel).
static func set_portal_surge(portal: Node, surge: float) -> void:
	var swirl := portal.get_node_or_null("Wirbel") as GeometryInstance3D
	if swirl:
		swirl.set_instance_shader_parameter("strength", surge)
	var runes := portal.get_node_or_null("Runenkreis") as GeometryInstance3D
	if runes:
		runes.set_instance_shader_parameter("strength", 0.35 + 0.65 * surge)


static func iron() -> Material:
	return HdCathedral._solid("gothic_iron", Color("1d1f25"), 0.0, 0.7)


static func brass() -> Material:
	return HdCathedral._solid("brass", Color("9e8756"), 0.0, 0.65)


static func window() -> Material:
	var m := HdCathedral._solid("windows", Color("d8bc7f"), 1.1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func glow(c: Color, energy := 1.6) -> Material:
	return HdCathedral._solid("gothic_glow_%s_%s" % [c.to_html(), energy], c, energy)


func add(kind: String, material: Material, size: Vector3, at: Vector3, yaw := 0.0, tilt := Vector3.ZERO) -> void:
	var key := material.get_instance_id()
	if not _parts.has(key):
		_parts[key] = {"material": material, "items": []}
	var basis := Basis(Vector3.UP, yaw) * Basis.from_euler(tilt) * Basis.from_scale(size)
	_parts[key].items.append([shape(kind), Transform3D(basis, at)])


## Teil auf einem Kreis um die Mitte: zeigt mit +Z nach außen.
func ring(kind: String, material: Material, size: Vector3, angle: float, distance: float, y: float, tilt := Vector3.ZERO) -> void:
	add(kind, material, size, Vector3(sin(angle) * distance, y, cos(angle) * distance), angle, tilt)


func commit() -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for part in _parts.values():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item in part.items:
			st.append_from(item[0], 0, item[1])
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, part.material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## Torwerk: achteckiger Wehrturm mit Strebepfeilern, Fialen, Spitzbogenfenstern, Zinnenkranz,
## Schieferhelm und Kreuzblume. inner = Innentor (höher, mit Erkern und Kreuz). accent = Farbe der Fahne.
## Rückgabe: [Turm, Fahne]; die Fahne ist ein eigener Knoten, damit sie ihre Farbe behält.
static func gate_tower(radius: float, h: float, inner: bool, accent: Color) -> Array:
	var b := HdGothic.new()
	var wall := stone()
	var edge := trim()
	var slate := HdCathedral.roof_material()
	var r := radius
	b.add("prism", wall, Vector3(r * 1.1, 0.5, r * 1.1), Vector3(0, 0.25, 0))
	b.add("prism", edge, Vector3(r * 1.02, 0.14, r * 1.02), Vector3(0, 0.57, 0))
	b.add("prism", wall, Vector3(r * 0.88, h, r * 0.88), Vector3(0, h * 0.5, 0))
	b.add("prism", edge, Vector3(r * 0.93, 0.16, r * 0.93), Vector3(0, h * 0.52, 0))
	for k in 4:
		# Fensterseiten liegen auf den Flächen des Achtecks (22,5° versetzt), Strebepfeiler dazwischen.
		var face := deg_to_rad(22.5 + k * 90.0)
		var pier := deg_to_rad(67.5 + k * 90.0)
		b.ring("lancet", window(), Vector3(r * 0.3, h * 0.3, 1), face, r * 0.825, h * 0.6)
		b.ring("box", iron(), Vector3(0.035, h * 0.26, 0.03), face, r * 0.83, h * 0.73)
		b.ring("lancet", window(), Vector3(r * 0.2, h * 0.17, 1), face, r * 0.825, h * 0.25)
		b.ring("box", wall, Vector3(r * 0.34, h * 0.72, r * 0.5), pier, r * 0.98, h * 0.36)
		b.ring("box", wall, Vector3(r * 0.3, h * 0.2, r * 0.34), pier, r * 0.9, h * 0.8, Vector3(-0.5, 0, 0))
		b.ring("box", edge, Vector3(r * 0.38, 0.1, r * 0.56), pier, r * 0.98, h * 0.72 + 0.05)
		b.ring("pyramid", slate, Vector3(r * 0.3, r * 0.75, r * 0.3), pier, r * 1.0, h * 0.72 + 0.1 + r * 0.375)
		b.ring("prism", brass(), Vector3(0.03, 0.3, 0.03), pier, r * 1.0, h * 0.72 + 0.25 + r * 0.75)
		# Wasserspeier unter dem Zinnenkranz
		b.ring("box", edge, Vector3(0.16, 0.16, r * 0.5), face, r * 1.1, h - 0.1, Vector3(0.25, 0, 0))
		b.ring("box", iron(), Vector3(0.2, 0.2, 0.2), face, r * 1.32, h - 0.19, Vector3(0.25, 0, 0))
	b.add("prism", edge, Vector3(r * 1.04, 0.3, r * 1.04), Vector3(0, h + 0.15, 0))
	for k in 8:
		var a := deg_to_rad(22.5 + k * 45.0)
		b.ring("box", wall, Vector3(r * 0.42, 0.62, r * 0.2), a, r * 0.88, h + 0.61)
		b.ring("pyramid", wall, Vector3(r * 0.2, 0.24, r * 0.2), a, r * 0.88, h + 1.04)
	var helm := 3.4 if inner else 2.5
	b.add("prism", wall, Vector3(r * 0.62, 0.7, r * 0.62), Vector3(0, h + 0.65, 0))
	b.add("spire", slate, Vector3(r * 0.74, helm, r * 0.74), Vector3(0, h + 1.0 + helm * 0.5, 0), deg_to_rad(22.5))
	b.add("prism", edge, Vector3(r * 0.76, 0.1, r * 0.76), Vector3(0, h + 1.0, 0))
	var tip := h + 1.0 + helm
	b.add("prism", brass(), Vector3(0.045, 1.1, 0.045), Vector3(0, tip + 0.4, 0))
	b.add("box", brass(), Vector3(0.16, 0.16, 0.16), Vector3(0, tip + 0.2, 0), 0.0, Vector3(PI * 0.25, 0, PI * 0.25))
	if inner:
		b.add("box", brass(), Vector3(0.5, 0.07, 0.07), Vector3(0, tip + 0.7, 0))
		for k in 4:
			var a := deg_to_rad(22.5 + k * 90.0)
			b.ring("box", wall, Vector3(r * 0.34, 0.5, r * 0.22), a, r * 0.52, h + 1.5)
			b.ring("lancet", window(), Vector3(r * 0.18, 0.36, 1), a, r * 0.635, h + 1.3)
			b.ring("pyramid", slate, Vector3(r * 0.38, 0.55, r * 0.26), a, r * 0.52, h + 2.02)
	else:
		b.add("box", brass(), Vector3(0.3, 0.3, 0.05), Vector3(0, tip + 0.75, 0), 0.0, Vector3(0, 0, PI * 0.25))
	# Eiserner Ausleger für die Fahne
	b.add("box", iron(), Vector3(0.07, 0.07, r * 0.9), Vector3(0, h * 0.95, r * 1.25))
	b.add("box", iron(), Vector3(0.05, 0.6, 0.05), Vector3(0, h * 0.95 - 0.25, r * 0.95), 0.0, Vector3(0.6, 0, 0))
	var tower := b.commit()
	var flag := HdGothic.new()
	var cloth := glow(accent.darkened(0.25), 0.55)
	flag.add("box", cloth, Vector3(0.05, 1.5, 0.62), Vector3(0, h * 0.95 - 0.8, r * 1.38))
	flag.add("pyramid", cloth, Vector3(0.05, 0.4, 0.44), Vector3(0, h * 0.95 - 1.75, r * 1.38), PI * 0.25, Vector3(PI, 0, 0))
	flag.add("box", glow(accent, 1.4), Vector3(0.07, 0.3, 0.3), Vector3(0, h * 0.95 - 0.75, r * 1.38), 0.0, Vector3(PI * 0.25, 0, 0))
	return [tower, flag.commit()]


## Gefallenes Torwerk: Sockel, abgebrochener Schaft und Trümmer.
static func gate_ruin(radius: float) -> MeshInstance3D:
	var b := HdGothic.new()
	var wall := stone()
	var r := radius
	b.add("prism", wall, Vector3(r * 1.1, 0.5, r * 1.1), Vector3(0, 0.25, 0))
	b.add("prism", wall, Vector3(r * 0.88, 0.9, r * 0.88), Vector3(0, 0.95, 0))
	b.add("box", wall, Vector3(r * 0.9, 1.7, r * 0.5), Vector3(-r * 0.3, 1.7, -r * 0.35), 0.4, Vector3(0, 0, 0.12))
	b.add("box", wall, Vector3(r * 0.5, 1.0, r * 0.4), Vector3(r * 0.45, 1.6, r * 0.2), 1.1, Vector3(0.1, 0, -0.2))
	for k in 7:
		var a := k * 0.9 + 0.3
		var d := r * (1.15 + 0.28 * (k % 3))
		b.add("box", wall if k % 2 == 0 else trim(), Vector3(0.5, 0.34, 0.42) * (0.7 + 0.2 * (k % 3)), Vector3(cos(a) * d, 0.16, sin(a) * d), a * 1.7, Vector3(0.3 * (k % 2), 0, 0.2))
	b.add("spire", HdCathedral.roof_material(), Vector3(r * 0.5, 1.5, r * 0.5), Vector3(r * 1.2, 0.3, -r * 0.9), 0.5, Vector3(1.35, 0, 0.3))
	return b.commit()


## Teleport-Schrein: achteckiger Sockel mit leuchtender Runenscheibe unter einem Spitzbogen mit Laterne.
## Die Scheibe behält die Farbe des Ziels, damit die Steine unterscheidbar bleiben.
static func waystone(color: Color) -> Node3D:
	var root := Node3D.new()
	var b := HdGothic.new()
	var wall := stone()
	b.add("prism", wall, Vector3(1.25, 0.3, 1.25), Vector3(0, 0.15, 0))
	b.add("prism", trim(), Vector3(1.05, 0.08, 1.05), Vector3(0, 0.33, 0))
	b.add("prism", iron(), Vector3(0.74, 0.05, 0.74), Vector3(0, 0.38, 0))
	for side in [-1.0, 1.0]:
		b.add("box", wall, Vector3(0.42, 0.5, 0.42), Vector3(side * 1.12, 0.25, 0))
		b.add("box", wall, Vector3(0.28, 2.4, 0.28), Vector3(side * 1.12, 1.5, 0))
		b.add("box", trim(), Vector3(0.36, 0.1, 0.36), Vector3(side * 1.12, 2.72, 0))
		b.add("pyramid", HdCathedral.roof_material(), Vector3(0.3, 0.8, 0.3), Vector3(side * 1.12, 3.17, 0))
		# Zwei schräge Balken treffen sich zum Spitzbogen.
		b.add("box", trim(), Vector3(0.16, 1.5, 0.2), Vector3(side * 0.58, 3.2, 0), 0.0, Vector3(0, 0, side * 0.86))
		b.add("box", iron(), Vector3(0.05, 0.5, 0.05), Vector3(side * 0.62, 2.2, 0))
		b.add("box", glow(color, 2.0), Vector3(0.09, 0.14, 0.09), Vector3(side * 0.62, 1.9, 0))
	b.add("pyramid", trim(), Vector3(0.3, 0.6, 0.3), Vector3(0, 3.95, 0))
	b.add("prism", brass(), Vector3(0.03, 0.5, 0.03), Vector3(0, 4.4, 0))
	b.add("box", iron(), Vector3(0.04, 0.55, 0.04), Vector3(0, 3.35, 0))
	b.add("box", iron(), Vector3(0.26, 0.05, 0.26), Vector3(0, 3.1, 0))
	b.add("box", glow(color, 2.6), Vector3(0.2, 0.3, 0.2), Vector3(0, 2.93, 0))
	b.add("pyramid", iron(), Vector3(0.28, 0.16, 0.28), Vector3(0, 2.7, 0), 0.0, Vector3(PI, 0, 0))
	root.add_child(b.commit())
	# Statt der farbigen Scheibe: Runenkreis in der Farbe des Ziels.
	var runes := rune_circle(color, 1.42, 0.5)
	runes.position = Vector3(0, 0.41, 0)
	root.add_child(runes)
	return root


## Spawn-Portal quer über die Straße (Breite width entlang X): Pfeiler mit Fialen, Spitzbogen,
## Fallgitter und Laterne. on = Straße aktiv (Laterne und Fenster leuchten).
static func workshop() -> MeshInstance3D:
	var b := HdGothic.new()
	# Open-front vaulted smithy: hearth, chimney, slate canopy, buttresses and anvil.
	b.add("box", stone(), Vector3(5.8,.32,4.6), Vector3(0,.16,0))
	b.add("box", stone(), Vector3(5.0,2.8,.55), Vector3(0,1.65,-1.8))
	for side in [-1.0,1.0]:
		b.add("box", stone(), Vector3(.5,2.8,3.5), Vector3(side*2.25,1.65,-.3))
		for z in [-1.8,.9]:
			b.add("box", trim(), Vector3(.7,3.0,.7), Vector3(side*2.4,1.65,z))
			b.add("spire", iron(), Vector3(.35,1.1,.35), Vector3(side*2.4,3.7,z))
		# Roof slope, with the same layered slate as the cathedral.
		b.add("box", HdCathedral.roof_material(), Vector3(3.0,.2,4.4), Vector3(side*1.25,3.4,-.4),0,Vector3(0,0,side*-.38))
		for k in 3:
			b.add("lancet", window(), Vector3(.45,1.2,1), Vector3(side*(.85+k*.43),1.7,-1.505))
	b.add("box", iron(), Vector3(.12,.13,4.6), Vector3(0,3.97,-.4))
	b.add("box", stone(), Vector3(1.6,1.2,1.2), Vector3(0,.9,-1.1))
	b.add("box", iron(), Vector3(1.1,.7,.08), Vector3(0,1.2,-.45))
	b.add("lancet", glow(Color("ff8a38"),2.4), Vector3(.85,.85,1), Vector3(0,.95,-.395))
	for i in 5: b.add("box", iron(), Vector3(.045,.6,.06), Vector3((i-2)*.15,1.25,-.34))
	b.add("box", stone(), Vector3(.95,3.5,.95), Vector3(0,3.2,-1.2))
	b.add("box", trim(), Vector3(1.3,.22,1.3), Vector3(0,4.95,-1.2))
	b.add("box", stone(), Vector3(1.1,.65,.8), Vector3(2.8,.5,1.7))
	b.add("box", iron(), Vector3(1.4,.27,.58), Vector3(2.8,.95,1.7))
	b.add("spire", iron(), Vector3(.33,.9,.28), Vector3(3.65,.95,1.7),0,Vector3(0,0,-PI*.5))
	for k in 4:
		b.add("box", brass(), Vector3(.09,.06,.7), Vector3(2.5+k*.18,1.12,1.7))
	return b.commit()


static func trial_pillar() -> MeshInstance3D:
	var b := HdGothic.new()
	b.add("prism", stone(), Vector3(.85,.35,.85), Vector3(0,.175,0))
	b.add("prism", stone(), Vector3(.48,3.4,.48), Vector3(0,2.05,0))
	for y in [.5,2.8,3.6]: b.add("prism", trim(), Vector3(.62,.16,.62), Vector3(0,y,0))
	for side in 4:
		b.ring("lancet", window(), Vector3(.3,1.45,1), side*PI*.5,.49,1.4)
	b.add("spire", HdCathedral.roof_material(), Vector3(.72,1.3,.72), Vector3(0,4.3,0))
	b.add("spire", brass(), Vector3(.12,.6,.12), Vector3(0,5.05,0))
	return b.commit()


static func portal(width: float, on: bool) -> MeshInstance3D:
	var b := HdGothic.new()
	var wall := stone()
	var half := width * 0.5 + 0.75
	var light := glow(PORTAL_COLOR, 2.2) if on else iron()
	for side in [-1.0, 1.0]:
		b.add("box", wall, Vector3(1.5, 0.6, 1.7), Vector3(side * half, 0.3, 0))
		b.add("box", wall, Vector3(1.15, 5.2, 1.3), Vector3(side * half, 3.1, 0))
		b.add("box", wall, Vector3(0.7, 2.6, 2.3), Vector3(side * half, 1.6, 0))
		b.add("box", trim(), Vector3(1.3, 0.16, 1.45), Vector3(side * half, 5.75, 0))
		b.add("pyramid", HdCathedral.roof_material(), Vector3(1.0, 2.3, 1.0), Vector3(side * half, 6.98, 0))
		b.add("prism", brass(), Vector3(0.04, 0.6, 0.04), Vector3(side * half, 8.35, 0))
		b.add("lancet", window() if on else iron(), Vector3(0.4, 1.3, 1), Vector3(side * half, 3.3, 0.66))
		b.add("lancet", window() if on else iron(), Vector3(0.4, 1.3, 1), Vector3(side * half, 3.3, -0.66), PI)
		var rise := half * 0.62
		var beam := Vector2(half, rise).length()
		b.add("box", wall, Vector3(beam + 0.3, 0.7, 0.9), Vector3(side * half * 0.5, 5.2 + rise * 0.5, 0), 0.0, Vector3(0, 0, -side * atan2(rise, half)))
		b.add("box", trim(), Vector3(beam + 0.4, 0.14, 1.05), Vector3(side * half * 0.5, 5.6 + rise * 0.5, 0), 0.0, Vector3(0, 0, -side * atan2(rise, half)))
	var apex := 5.2 + half * 0.62
	b.add("pyramid", HdCathedral.roof_material(), Vector3(0.9, 1.6, 0.9), Vector3(0, apex + 1.0, 0))
	b.add("prism", brass(), Vector3(0.04, 0.7, 0.04), Vector3(0, apex + 2.1, 0))
	b.add("box", brass(), Vector3(0.44, 0.06, 0.06), Vector3(0, apex + 2.2, 0))
	b.add("box", iron(), Vector3(0.06, 0.9, 0.06), Vector3(0, apex - 0.7, 0))
	b.add("box", light, Vector3(0.34, 0.5, 0.34), Vector3(0, apex - 1.35, 0))
	# Fallgitter: Eisenstäbe mit Spitzen, zur Mitte hin höher gezogen
	var bars := maxi(5, int(width / 0.9))
	for i in bars:
		var x := lerpf(-width * 0.5 + 0.3, width * 0.5 - 0.3, float(i) / (bars - 1))
		var top := 5.0 + (half - absf(x)) * 0.55
		var length := 1.5 + 0.35 * (i % 2)
		b.add("box", iron(), Vector3(0.09, length, 0.09), Vector3(x, top - length * 0.5, 0))
		b.add("pyramid", iron(), Vector3(0.2, 0.34, 0.2), Vector3(x, top - length - 0.17, 0), 0.0, Vector3(PI, 0, 0))
	var gate := b.commit()
	# Runenkreis am Boden unter dem Bogen; aktive Portale leuchten violett, gesperrte nur matt.
	var runes := rune_circle(PORTAL_COLOR if on else Color("3a3846"), width * 0.95, 0.35 if on else 0.0, 1.5 if on else 0.5)
	runes.position = Vector3(0, 0.04, 0)
	gate.add_child(runes)
	if on:
		var swirl := vortex(width + 0.2, 5.0, PORTAL_COLOR)
		swirl.position = Vector3(0, 2.65, 0)
		gate.add_child(swirl)
	return gate
