class_name HdBossVisual
extends Node3D
## Originale Gothic-Anatomie, je Material/Glied gebündelt. Gelenkpivots statt starrer Gesamtfigur.
## Keine Lichter, Kollisionen oder Kampfregeln; Blickrichtung -Z.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
var _groups: Dictionary = {}
var core: Node3D
var halo: Node3D
var spin := 0.18
var dark: Material
var iron: Material
var bone: Material
var black: Material
var cloth: Material
var accent: Material
var trim: Material
var _section := "body"
var _limbs := {}
var _theme := ""
var _last_time := -1.0
var _cast_blend := 0.0
## Körperbewegung (2026-11-17): Hieb, Gehen, Zusammenbruch. Vorher bewegten sich nur Kopf und Arme minimal.
var _strike := -1.0          ## Zeit seit Beginn des Hiebs, < 0 = kein Hieb
var _strike_arm := "arm_r"
var _walk := 0.0             ## geglättete Laufgeschwindigkeit
var _step_phase := 0.0
var _dying := false
const STRIKE_TIME := 0.75


## Nahkampfhieb: Arm holt aus, Oberkörper dreht ein, Schlag nach vorn unten, Nachfedern.
func strike() -> void:
	if _dying:
		return
	_strike = 0.0
	_strike_arm = "arm_l" if _strike_arm == "arm_r" and _limbs.has("arm_l") else "arm_r"


## Zusammenbruch: Arme sinken, die Figur knickt nach vorn und sackt in sich zusammen.
func die() -> void:
	_dying = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "rotation:x", -1.15, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", -0.6 * scale.y, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for key: String in _limbs:
		var limb: Node3D = _limbs[key]
		if key == "head":
			tw.tween_property(limb, "rotation", Vector3(.55, 0, .2), 0.9)
		elif key.begins_with("tendril"):
			tw.tween_property(limb, "rotation", Vector3(.5, 0, 0), 1.1)
		else:
			var side := 1.0 if key == "arm_l" else -1.0
			tw.tween_property(limb, "rotation", Vector3(-.35, 0, side * .55), 0.8)
	if core != null:
		tw.tween_property(core, "scale", core.scale * .2, 1.2)


func build(data: Dictionary) -> void:
	var theme := str(data.visual.theme)
	_theme = theme
	dark = _material(theme+"_body", Color(str(data.color)).lightened(.09), .12, .78)
	iron = _material("black_iron", Color("454b58"), .82, .48)
	bone = _material("old_ivory", Color("b4a58d"), 0, .73)
	black = _material("hollow", Color("080b12"), 0, .95)
	cloth = _material(theme+"_shroud", Color(str(data.color)).darkened(.28), 0, .94)
	accent = _material(theme+"_ember", Color(str(data.visual.accent)), .18, .3, .65)
	trim = _material("tarnished_brass", Color("796345"), .8, .45)
	match theme:
		"forge": _forge()
		"tide": _tide()
		"rot": _rot()
		"time": _time()
		"void": _void()
	_flush()
	var size: Array = data.get("size", [4,4.8,4])
	scale = Vector3.ONE*float(size[1])/4.8
	set_meta("gothic_theme",theme)
	set_meta("gothic_batches",_groups.size())
	set_meta("articulated_limbs",_limbs.size())


func _forge() -> void:
	_ellipsoid(Vector3(0,2.55,0),Vector3(1.12,1.18,.66),dark)
	_ellipsoid(Vector3(0,2.5,-.54),Vector3(.67,.88,.27),black)
	core = _node(_shape("sphere"),accent,Vector3(0,2.5,-.67),Vector3(.44,.61,.16))
	for side in [-1.0,1.0]:
		_tube([Vector3(side*.5,1.9,0),Vector3(side*.62,.85,.05),Vector3(side*.67,.3,-.15)],[.42,.32,.29],iron)
		_ellipsoid(Vector3(side*.67,.19,-.27),Vector3(.39,.19,.58),iron)
		_ellipsoid(Vector3(side*1.15,3.27,0),Vector3(.69,.43,.65),iron)
		_section = "arm_l" if side > 0 else "arm_r"
		_tube([Vector3(side*1.34,3.17,0),Vector3(side*1.62,2.45,-.05),Vector3(side*1.63,1.75,-.23)],[.34,.28,.31],dark)
		_claws(Vector3(side*1.63,1.78,-.24),side,iron,.8)
		_section = "body"
		_tube([Vector3(side*.43,3.95,.05),Vector3(side*.7,4.4,.08),Vector3(side*.53,4.78,-.07)],[.19,.12,.008],iron)
		for j in 3:
			_tube([Vector3(side*(.9+j*.23),3.53,.12),Vector3(side*(1.05+j*.26),4.03-j*.09,.18)],[.14,.008],iron)
		for link in 6:
			_ring(Vector3(side*1.43,2.85-link*.22,-.42),.16,iron,Vector3(PI*.5,0,link%2*PI*.5))
		for rib in 5:
			var y := 2.0+rib*.23
			_tube([Vector3(side*.14,y,-.83),Vector3(side*.57,y+.08,-.77),Vector3(side*.88,y+.27,-.45)],[.07,.09,.13],iron)
		_rag(Vector3(side*.3,1.8,-.35),.43,1.1,cloth,side*.14)
	_skull(Vector3(0,3.87,-.08),Vector3(.48,.53,.43),iron)
	for slit in 5:
		_bar(Vector3((slit-2)*.13,3.67,-.51),Vector3(.035,.24,.04),accent)
	_section = "arm_l"
	_beam(Vector3(1.83,.47,-.53),Vector3(1.83,2.9,-.53),.075,trim)
	_ellipsoid(Vector3(1.83,1.45,-.53),Vector3(.64,.37,.38),iron)
	_bar(Vector3(1.83,1.45,-.9),Vector3(.58,.27,.06),accent)
	_section = "body"
	halo = _ring_node(Vector3(0,4.1,.24),.7,trim,Vector3(PI*.5,0,0))


func _tide() -> void:
	_tube([Vector3(0,.2,0),Vector3(0,1.15,.12),Vector3(0,2.55,0),Vector3(0,3.26,0)],[1.02,.72,.45,.58],cloth,14)
	for side in [-1.0,1.0]:
		_rag(Vector3(side*.62,2.8,.22),.58,2.3,dark,side*.42)
		_section = "arm_l" if side > 0 else "arm_r"
		_tube([Vector3(side*.52,3.15,0),Vector3(side*1.1,2.55,-.05),Vector3(side*1.32,1.91,-.27)],[.23,.14,.1],dark)
		_claws(Vector3(side*1.31,1.96,-.27),side,bone,.85)
		_section = "body"
		for fin in 4:
			_tube([Vector3(side*.62,2.75+fin*.14,.15),Vector3(side*(1.45-fin*.16),3.65+fin*.15,.24),Vector3(side*(1.2-fin*.1),3.03+fin*.12,.1)],[.1,.025,.01],dark)
		for rib in 4:
			_tube([Vector3(side*.05,2.5+rib*.15,-.45),Vector3(side*.4,2.45+rib*.15,-.42),Vector3(side*.52,2.6+rib*.15,-.08)],[.035,.05,.06],bone)
		for j in 3:
			_rag(Vector3(side*(.45+j*.2),2.9-j*.24,.13),.15,.9+j*.2,cloth,side*.16)
	_skull(Vector3(0,3.65,-.04),Vector3(.38,.55,.36),bone)
	_ring(Vector3(0,4.02,.03),.42,iron,Vector3.ZERO)
	for prong in 7:
		var a := (prong-3)*.38
		_tube([Vector3(sin(a)*.4,4.02,cos(a)*.15),Vector3(sin(a)*.71,4.6-absf(a)*.14,.1),Vector3(sin(a)*.65,4.77-absf(a)*.17,-.1)],[.07,.04,.002],iron)
	_section = "arm_l"
	_beam(Vector3(1.61,.19,-.42),Vector3(1.61,4.17,-.42),.047,iron)
	for fork in [-1.0,0.0,1.0]:
		_tube([Vector3(1.61,3.76,-.42),Vector3(1.61+fork*.35,4.1,-.42),Vector3(1.61+fork*.42,4.65-absf(fork)*.15,-.5)],[.06,.055,.002],bone)
	_section = "body"
	core = _node(_shape("sphere"),accent,Vector3(0,2.85,-.47),Vector3(.12,.19,.08))
	halo = _ring_node(Vector3(0,.12,0),1.05,accent,Vector3.ZERO)
	spin = -.1


func _rot() -> void:
	_tube([Vector3(0,.24,0),Vector3(-.19,1.5,.12),Vector3(.08,2.5,0),Vector3(0,3.4,.12)],[.84,.72,.87,.37],dark,12)
	_ellipsoid(Vector3(0,2.55,-.68),Vector3(.46,.68,.18),black)
	for side in [-1.0,1.0]:
		for root_index in 3:
			_tube([Vector3(side*.3,.65,.1),Vector3(side*(.65+root_index*.25),.22,.25-root_index*.35),Vector3(side*(1.1+root_index*.25),.06,.5-root_index*.6)],[.24,.13,.004],dark)
		_section = "arm_l" if side > 0 else "arm_r"
		_tube([Vector3(side*.68,3,.1),Vector3(side*1.5,2.48,.1),Vector3(side*1.74,1.45,-.18)],[.31,.22,.13],dark)
		_claws(Vector3(side*1.74,1.5,-.18),side,bone,1.1)
		_section = "body"
		_tube([Vector3(side*.24,3.65,.1),Vector3(side*.7,4.16,.1),Vector3(side*1.3,4.52,.2),Vector3(side*1.67,4.71,.09)],[.2,.17,.085,.002],dark)
		for thorn in 4:
			_tube([Vector3(side*(.53+thorn*.25),4.04+thorn*.18,.13),Vector3(side*(.45+thorn*.27),4.52+thorn*.085,-.02)],[.075,.002],bone)
		for rib in 5:
			_tube([Vector3(side*.12,2.08+rib*.19,-.81),Vector3(side*.52,2.16+rib*.19,-.73),Vector3(side*.73,2.35+rib*.19,-.31)],[.065,.1,.14],dark)
		for mushroom in 3:
			var p := Vector3(side*(.62+mushroom*.25),3.12-mushroom*.43,.07)
			_ellipsoid(p,Vector3(.4,.13,.36),trim)
			_ellipsoid(p-Vector3(0,.1,.015),Vector3(.27,.055,.27),dark)
	_skull(Vector3(0,3.54,-.26),Vector3(.34,.48,.3),bone)
	core = _node(_shape("sphere"),accent,Vector3(0,2.57,-.79),Vector3(.22,.39,.08))
	for knot in 5:
		_ellipsoid(Vector3(sin(knot*2.4)*.58,1.1+knot*.27,-.62),Vector3(.055,.08,.035),accent)
	halo = _ring_node(Vector3(0,3.65,.28),.74,dark,Vector3(PI*.5,0,0))


func _time() -> void:
	_tube([Vector3(0,.17,.07),Vector3(0,1.3,.04),Vector3(0,2.8,.08),Vector3(0,3.25,.06)],[1.0,.64,.57,.62],cloth,14)
	for side in [-1.0,1.0]:
		_rag(Vector3(side*.5,3.08,.23),.8,2.73,cloth,side*.4)
		_section = "arm_l" if side > 0 else "arm_r"
		_tube([Vector3(side*.56,3.12,0),Vector3(side*1.04,2.5,-.04),Vector3(side*1.25,2.66,-.48)],[.16,.11,.065],bone)
		_claws(Vector3(side*1.25,2.65,-.48),side,bone,.85)
		_section = "body"
		_tube([Vector3(side*.46,3.37,.13),Vector3(side*.4,4.22,.12),Vector3(0,4.59,.12)],[.28,.23,.01],cloth)
		for thread in 3:
			_rag(Vector3(side*(.45+thread*.21),3.1,.2),.14,1.3+thread*.22,trim,side*.1)
	_skull(Vector3(0,3.68,-.32),Vector3(.29,.5,.25),bone)
	core = _node(Tower._gem_mesh(),accent,Vector3(0,2.4,-.62),Vector3(.32,.62,.23))
	for side in [-1.0,1.0]:
		_beam(Vector3(side*.4,1.8,-.57),Vector3(side*.4,3,-.57),.035,trim)
		_beam(Vector3(-.45,2.4+side*.6,-.57),Vector3(.45,2.4+side*.6,-.57),.04,trim)
	halo = _ring_node(Vector3(0,3.02,.36),1.57,trim,Vector3(PI*.5,0,0))
	for tick in 12:
		if tick in [2,3,8]:continue
		var a := TAU*tick/12.0
		_bar(Vector3(sin(a)*1.53,3.02+cos(a)*1.53,.35),Vector3(.055,.24,.045),bone,Vector3(0,0,-a))
	_beam(Vector3(0,3.02,.29),Vector3(.76,3.98,.29),.026,iron)
	_beam(Vector3(0,3.02,.27),Vector3(-.92,2.76,.27),.035,iron)
	spin = -.14


func _void() -> void:
	_ellipsoid(Vector3(0,2.45,.25),Vector3(1.18,1.36,.73),dark)
	_ellipsoid(Vector3(0,2.65,-.65),Vector3(.86,1.04,.46),black)
	for side in [-1.0,1.0]:
		_tube([Vector3(side*.77,3.25,-.28),Vector3(side*1,2.62,-.52),Vector3(side*.56,1.75,-.38)],[.26,.28,.2],iron)
		_tube([Vector3(side*.68,3.65,.09),Vector3(side*.96,4.26,.2),Vector3(side*.71,4.75,-.08)],[.27,.17,.005],bone)
		for tentacle in 4:
			_section = "tendril_%s_%s" % [side,tentacle]
			var a := .3+tentacle*.86
			var x: float = side*(.82+sin(a)*.4)
			_tube([Vector3(x,2.7-tentacle*.39,.38),Vector3(side*(1.54+sin(a)*.3),2.2-tentacle*.43,.35),Vector3(side*(2+sin(a)*.22),1.27-tentacle*.29,-.17),Vector3(side*(1.75+sin(a)*.2),.31+tentacle*.15,-.62)],[.24,.2,.12,.002],dark)
			_tube([Vector3(side*.81,3.1-tentacle*.24,.2),Vector3(side*(1.25+tentacle*.1),3.5-tentacle*.22,.4)],[.15,.003],iron)
		_section = "body"
		for tooth in 5:
			var x: float = side*(.12+tooth*.145)
			_tube([Vector3(x,3.34-tooth*.045,-.93),Vector3(x*.91,3.02-tooth*.025,-1.02),Vector3(x*.85,2.78-tooth*.02,-.99)],[.095,.055,.003],bone)
			_tube([Vector3(x,1.94+tooth*.035,-.89),Vector3(x*.9,2.18+tooth*.02,-1.01),Vector3(x*.8,2.38+tooth*.015,-.98)],[.09,.045,.003],bone)
		for eye in 3:
			_ellipsoid(Vector3(side*(.4+eye*.2),3.49-eye*.15,-.62),Vector3(.1,.065,.045),accent)
	core = _node(_shape("sphere"),accent,Vector3(0,2.62,-1.14),Vector3(.18,.29,.045))
	halo = _ring_node(Vector3(0,2.65,-.6),1.05,iron,Vector3(PI*.5,0,0))
	spin = .08


func _skull(at: Vector3, size: Vector3, material: Material) -> void:
	_section = "head"
	_queue(_shape("mask"),material,at,size)
	_bar(at+Vector3(0,-size.y*.65,-size.z*.23),size*Vector3(.72,.18,.72),material)
	for side in [-1.0,1.0]:
		_ellipsoid(at+Vector3(side*size.x*.4,size.y*.12,-size.z*.85),size*Vector3(.34,.12,.21),black)
		_ellipsoid(at+Vector3(side*size.x*.4,size.y*.1,-size.z*1.03),size*Vector3(.18,.037,.055),accent)
		_bar(at+Vector3(side*size.x*.4,size.y*.28,-size.z*.77),size*Vector3(.73,.13,.17),material,Vector3(0,0,side*.23))
	for tooth in 5:
		_bar(at+Vector3((tooth-2)*size.x*.23,-size.y*.55,-size.z*.83),Vector3(size.x*.13,size.y*.19,.055),bone)
	_ellipsoid(at+Vector3(0,-size.y*.22,-size.z*.92),size*Vector3(.14,.19,.11),black)
	_section = "body"


func _claws(at: Vector3, side: float, material: Material, size: float) -> void:
	_ellipsoid(at,Vector3(.15,.24,.14)*size,material)
	for finger in 4:
		var p := at+Vector3((finger-1.5)*.095*size,0,-.07)
		_tube([p,p+Vector3(side*.055,-.3*size,-.13),p+Vector3(side*.08,-.43*size,-.26)],[.045*size,.031*size,.002],material,6)


static func _material(id: String, color: Color, metalness: float, roughness: float, glow := 0.0) -> ShaderMaterial:
	if not _materials.has(id):
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/hd_boss_surface.gdshader")
		var parameters := {"tint":color,"metalness":metalness,"roughness":roughness,"glow":glow}
		for parameter in parameters:material.set_shader_parameter(parameter,parameters[parameter])
		_materials[id]=material
	return _materials[id]


static func _shape(kind: String) -> Mesh:
	if not _meshes.has(kind):
		match kind:
			"sphere":
				var shape := SphereMesh.new()
				shape.radius=1; shape.height=2; shape.radial_segments=16; shape.rings=8
				_meshes[kind]=shape
			"box": _meshes[kind]=BoxMesh.new()
			"mask":
				var vertices := [Vector3(-.65,.55,-.65),Vector3(.65,.55,-.65),Vector3(-1,.08,-.5),Vector3(1,.08,-.5),Vector3(-.45,-.75,-.6),Vector3(.45,-.75,-.6),Vector3(0,-.2,-1),Vector3(0,.85,-.4),Vector3(0,-.95,-.4),Vector3(0,0,.5)]
				var faces := [0,7,1,0,1,6,0,6,2,1,3,6,2,6,4,3,5,6,4,6,5,4,5,8,7,0,9,0,2,9,2,4,9,4,8,9,8,5,9,5,3,9,3,1,9,1,7,9]
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for face in range(0,faces.size(),3):
					var a: Vector3=vertices[faces[face]]
					var b: Vector3=vertices[faces[face+1]]
					var c: Vector3=vertices[faces[face+2]]
					surface.set_normal((b-a).cross(c-a).normalized())
					for p in [a,b,c]:surface.add_vertex(p)
				_meshes[kind]=surface.commit()
			"ring":
				var shape := TorusMesh.new()
				shape.inner_radius=.93; shape.outer_radius=1; shape.rings=40; shape.ring_segments=6
				_meshes[kind]=shape
	return _meshes[kind]


func _node(mesh: Mesh, material: Material, at: Vector3, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh; node.material_override=material; node.position=at; node.scale=size
	add_child(node)
	return node


func _queue(mesh: Mesh, material: Material, at := Vector3.ZERO, size := Vector3.ONE, rotation := Vector3.ZERO) -> void:
	var key := str(material.get_instance_id())+":"+_section
	if not _groups.has(key):_groups[key]={"material":material,"parts":[],"section":_section}
	_groups[key].parts.append([mesh,Transform3D(Basis.from_euler(rotation)*Basis.from_scale(size),at)])


func _ellipsoid(at: Vector3, size: Vector3, material: Material) -> void:
	_queue(_shape("sphere"),material,at,size)


func _bar(at: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> void:
	_queue(_shape("box"),material,at,size,rotation)


func _beam(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	_tube([a,b],[radius,radius],material,6)


func _tube(points: Array, radii: Array, material: Material, sides := 9) -> void:
	var rings: Array = []
	var normals: Array = []
	for i in points.size():
		var direction: Vector3 = (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var across := direction.cross(Vector3.FORWARD).normalized()
		if across.is_zero_approx():across=Vector3.RIGHT
		var other := across.cross(direction).normalized()
		var ring: Array = []
		var normal: Array = []
		for k in sides:
			var n: Vector3 = across*cos(TAU*k/sides)+other*sin(TAU*k/sides)
			ring.append(points[i]+n*float(radii[i])); normal.append(n)
		rings.append(ring); normals.append(normal)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(points.size()-1):
		for k in sides:
			var next := (k+1)%sides
			for cell in [Vector2i(row,k),Vector2i(row+1,k),Vector2i(row+1,next),Vector2i(row,k),Vector2i(row+1,next),Vector2i(row,next)]:
				surface.set_normal(normals[cell.x][cell.y]); surface.add_vertex(rings[cell.x][cell.y])
	_queue(surface.commit(),material)


func _rag(at: Vector3, width: float, length: float, material: Material, drift: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for panel in 4:
		var left: float = panel/4.0-.5
		var right: float = (panel+1)/4.0-.5
		var bottom := at+Vector3(drift,-length,.13)
		for p in [at+Vector3(left*width,0,0),bottom+Vector3(left*width,sin(panel*2.3)*.13,0),bottom+Vector3(right*width,sin((panel+1)*2.3)*.13,0),at+Vector3(left*width,0,0),bottom+Vector3(right*width,sin((panel+1)*2.3)*.13,0),at+Vector3(right*width,0,0)]:
			surface.set_normal(Vector3.FORWARD); surface.add_vertex(p)
	_queue(surface.commit(),material)


func _ring(at: Vector3, radius: float, material: Material, rotation: Vector3) -> void:
	_queue(_shape("ring"),material,at,Vector3.ONE*radius,rotation)


func _ring_node(at: Vector3, radius: float, material: Material, rotation: Vector3) -> Node3D:
	var node := _node(_shape("ring"),material,at,Vector3.ONE*radius)
	node.rotation=rotation
	return node


func _flush() -> void:
	for group in _groups.values():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in group.parts:
			var arrays: Array = part[0].surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var transform: Transform3D = part[1]
			var normal_matrix := transform.basis.inverse().transposed()
			for index in (indices if not indices.is_empty() else range(vertices.size())):
				surface.set_normal((normal_matrix*normals[index]).normalized())
				surface.add_vertex(transform*vertices[index])
		var node := _node(surface.commit(),group.material,Vector3.ZERO,Vector3.ONE)
		if group.section != "body":
			if not _limbs.has(group.section):
				var pivot := Node3D.new()
				pivot.name = group.section
				pivot.position = Vector3(0,3.45,0) if group.section == "head" else Vector3(.7 if group.section == "arm_l" else -.7,3.15,0)
				if str(group.section).begins_with("tendril"):
					var center: Vector3 = node.mesh.get_aabb().get_center()
					pivot.position = Vector3(signf(center.x)*.85,2.5,.3)
				add_child(pivot)
				_limbs[group.section] = pivot
			node.reparent(_limbs[group.section],false)
			node.position = -_limbs[group.section].position
		group.parts.clear()


func animate(now: float, phase: int, casting: bool, moving := 0.0) -> void:
	if _dying:
		return
	var dt := clampf(now-_last_time,0,.1) if _last_time >= 0 else .1
	_last_time = now
	_cast_blend = move_toward(_cast_blend,1.0 if casting else 0.0,dt*5.0)
	_walk = lerpf(_walk, clampf(moving / 3.0, 0.0, 1.0), minf(1.0, dt * 6.0))
	_step_phase += dt * (2.2 + _walk * 4.5)
	# Hieb in drei Abschnitten: ausholen (0–35 %), zuschlagen (35–55 %), nachfedern bis zum Ende.
	var wind := 0.0
	var hit := 0.0
	if _strike >= 0.0:
		_strike += dt
		var t := _strike / STRIKE_TIME
		if t >= 1.0:
			_strike = -1.0
		elif t < .35:
			wind = smoothstep(0.0, .35, t)
		elif t < .55:
			wind = 1.0 - smoothstep(.35, .55, t)
			hit = smoothstep(.35, .55, t)
		else:
			hit = 1.0 - smoothstep(.55, 1.0, t)
	var strike_side := 1.0 if _strike_arm == "arm_l" else -1.0
	# Ganzer Körper: Gewicht beim Gehen, Eindrehen beim Ausholen, Vorbeugen beim Treffer.
	rotation = Vector3(-.10 * wind + .24 * hit + .05 * _walk + sin(_step_phase * 2.0) * .015 * _walk,
		strike_side * (.28 * wind - .18 * hit), sin(_step_phase) * .05 * _walk)
	position.y = absf(sin(_step_phase)) * .12 * _walk * scale.y - .1 * hit * scale.y
	for key: String in _limbs:
		var limb: Node3D = _limbs[key]
		var side := 1.0 if key == "arm_l" else -1.0
		if key == "head":
			limb.rotation = Vector3(-.1*_cast_blend - .15*wind + .22*hit,sin(now*.8)*.04, sin(now*1.3)*.025)
		elif key.begins_with("tendril"):
			var offset := float(key.hash()%31)*.2
			limb.rotation = Vector3(sin(now*1.5+offset)*.10 - .25*wind + .45*hit,cos(now*.8+offset)*.09,sin(now*1.1+offset)*(.08+_cast_blend*.10+.08*_walk))
		else:
			var lift := .45 if _theme == "forge" else .33 if _theme == "tide" else .65
			limb.rotation = Vector3(sin(now*1.7+side)*.035+lift*_cast_blend+sin(_step_phase+side*1.6)*.18*_walk,side*.035*sin(now),side*(.03+.07*_cast_blend))
			if key == _strike_arm:
				# Schlagarm: weit über Kopf ausholen, dann vor dem Körper nach unten durchziehen.
				limb.rotation += Vector3(-1.35 * wind + 1.05 * hit, 0, side * (.35 * wind - .1 * hit))
			elif wind + hit > 0.0:
				limb.rotation += Vector3(.25 * wind - .2 * hit, 0, side * .15 * wind)
	if halo != null:
		if not halo.has_meta("base_scale"):halo.set_meta("base_scale",halo.scale)
		halo.rotation.y=now*spin*(1.0+phase*.3)
		halo.scale=halo.get_meta("base_scale")*(1.0+phase*.025)
	if core != null:
		if not core.has_meta("base_scale"):core.set_meta("base_scale",core.scale)
		core.scale=core.get_meta("base_scale")*(1.0+sin(now*(4.0 if casting else 2.0))*.045)
