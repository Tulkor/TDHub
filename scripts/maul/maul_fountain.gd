class_name MaulFountain
extends Node3D
## Atlas-Brunnen, Wahrzeichen in der Mitte der Maul-Karte (Plaza-Art-déco, Lukas 2026-11-08):
## rundes Kalksteinbecken mit Wasser und Fontänen, in der Mitte ein gestufter Granitsockel, darauf eine
## kantige Atlas-Figur in Bronze, die eine Armillarsphäre aus Messingringen stemmt (Vorbild Rockefeller
## Center, eigener Entwurf aus Grundkörpern). Die Sphäre dreht sich langsam.

const WATER_SHADER := preload("res://assets/shaders/fountain_water.gdshader")
const STONE := Color("c8c2b4")
const GRANITE := Color("907070")
const BRONZE := Color("a8844a")
const BRASS := Color("e0c070")
## Fontänen im Becken
const JETS := 8
## Größe der Figur und der Sphäre (1 = Grundmaße unten)
const FIGURE := 1.4
const SPHERE := 0.9
## Drehung der Sphäre (Bogenmaß je Sekunde)
const SPIN := 0.12

var sphere: Node3D


## Brunnen auf einem Platz der Breite plaza (Einheiten) aufbauen, Mitte = Ursprung des Knotens.
func build(plaza: float) -> void:
	for c in get_children():
		c.queue_free()
	var r := clampf(plaza * 0.3, 1.6, 3.2)
	var stone := _mat(STONE, 0.0, 0.65)
	var granite := _mat(GRANITE, 0.1, 0.35)
	var bronze := _mat(BRONZE, 0.75, 0.38)
	var brass := _mat(BRASS, 0.9, 0.28)
	# Stufen um das Becken, Beckenrand, Wasser
	_cyl(r + 0.45, 0.05, 0.0, stone)
	_cyl(r + 0.25, 0.1, 0.05, stone)
	_cyl(r, 0.32, 0.15, stone)
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r - 0.12
	disc.bottom_radius = r - 0.12
	disc.height = 0.02
	disc.radial_segments = 48
	water.mesh = disc
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	water.material_override = wm
	water.position.y = 0.48
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# Messingband auf dem Beckenrand
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.1
	torus.outer_radius = r + 0.02
	torus.rings = 48
	rim.mesh = torus
	rim.scale = Vector3(1, 0.4, 1)
	rim.position.y = 0.49
	rim.material_override = brass
	add_child(rim)
	# Fontänen: schräge Wasserstrahlen vom Rand zur Mitte
	var jet_mat := StandardMaterial3D.new()
	jet_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
	jet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jet_mat.emission_enabled = true
	jet_mat.emission = Color("9dc5e5")
	jet_mat.emission_energy_multiplier = 0.35
	jet_mat.roughness = 0.1
	for i in JETS:
		var a := TAU * float(i) / JETS
		var jet := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.015
		cm.bottom_radius = 0.035
		cm.height = r * 0.7
		cm.radial_segments = 8
		jet.mesh = cm
		jet.material_override = jet_mat
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var out := Vector3(cos(a), 0, sin(a))
		jet.position = out * (r * 0.62) + Vector3(0, 0.49 + cm.height * 0.3, 0)
		# nach innen und oben geneigt
		jet.basis = Basis(Vector3.UP.cross(out).normalized(), deg_to_rad(-28.0))
		add_child(jet)
	# Sockel in Granit, gestuft
	var y := 0.49
	for step in [[0.95, 0.25], [0.75, 0.35], [0.6, 0.5]]:
		_cyl(step[0], step[1], y, granite, 8)
		y += step[1]
	_cyl(0.66, 0.05, y, brass, 8)
	y += 0.05
	var atlas := Node3D.new()
	atlas.position.y = y
	atlas.scale = Vector3.ONE * FIGURE
	add_child(atlas)
	_figure(atlas, bronze)
	# Armillarsphäre über den Schultern
	sphere = Node3D.new()
	sphere.position = Vector3(0, y + (2.45 + SPHERE * 0.4) * FIGURE, 0)
	sphere.scale = Vector3.ONE * SPHERE * FIGURE
	add_child(sphere)
	var rings := [[0.0, 0.0], [90.0, 0.0], [90.0, 60.0], [90.0, 120.0], [23.4, 0.0]]
	for i in rings.size():
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.9 if i < 4 else 0.82
		tm.outer_radius = 0.96 if i < 4 else 0.98
		tm.rings = 40
		ring.mesh = tm
		ring.material_override = brass
		ring.rotation_degrees = Vector3(rings[i][0], rings[i][1], 0)
		if i == 4:
			ring.scale = Vector3(1, 2.2, 1)  # breites Tierkreisband
		sphere.add_child(ring)
	var axis := MeshInstance3D.new()
	var ax := CylinderMesh.new()
	ax.top_radius = 0.025
	ax.bottom_radius = 0.025
	ax.height = 2.3
	axis.mesh = ax
	axis.material_override = brass
	axis.rotation_degrees = Vector3(0, 0, 23.4)
	sphere.add_child(axis)
	var globe := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.16
	gm.height = 0.32
	globe.mesh = gm
	globe.material_override = brass
	sphere.add_child(globe)
	# warmes Licht von unten auf die Figur
	var light := OmniLight3D.new()
	light.light_color = Color("ffd8a0")
	light.light_energy = 0.8
	light.omni_range = r * 1.3
	light.position = Vector3(0, 1.6, r * 0.55)
	light.shadow_enabled = false
	add_child(light)


func _process(delta: float) -> void:
	if sphere != null:
		sphere.rotate_y(SPIN * delta)


## Atlas: kantige Figur im Ausfallschritt, Oberkörper vorgebeugt, Arme nach oben zur Sphäre.
func _figure(parent: Node3D, mat: Material) -> void:
	var part := func(size: Vector3, pos: Vector3, rot: Vector3) -> void:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		m.material_override = mat
		m.position = pos
		m.rotation_degrees = rot
		parent.add_child(m)
	# Beine: vorn gebeugt, hinten gestreckt
	part.call(Vector3(0.17, 0.55, 0.2), Vector3(-0.15, 0.28, 0.18), Vector3(-25, 0, 0))
	part.call(Vector3(0.16, 0.5, 0.18), Vector3(-0.15, 0.7, 0.12), Vector3(20, 0, 0))
	part.call(Vector3(0.17, 0.95, 0.2), Vector3(0.15, 0.48, -0.15), Vector3(18, 0, 0))
	# Becken, Rumpf, Kopf
	part.call(Vector3(0.48, 0.22, 0.3), Vector3(0, 0.95, 0.0), Vector3(0, 0, 0))
	part.call(Vector3(0.62, 0.7, 0.34), Vector3(0, 1.38, 0.06), Vector3(14, 0, 0))
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.28
	head.mesh = hm
	head.material_override = mat
	head.position = Vector3(0, 1.82, 0.2)
	parent.add_child(head)
	# Arme: Oberarm schräg nach außen oben, Unterarm senkrecht zur Sphäre
	for side in [-1.0, 1.0]:
		part.call(Vector3(0.15, 0.5, 0.15), Vector3(side * 0.42, 1.78, 0.05), Vector3(0, 0, side * -40.0))
		part.call(Vector3(0.13, 0.48, 0.13), Vector3(side * 0.58, 2.2, 0.05), Vector3(0, 0, side * -8.0))


func _cyl(radius: float, height: float, y0: float, mat: Material, segments := 48) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	m.mesh = c
	m.material_override = mat
	m.position.y = y0 + height / 2.0
	add_child(m)


func _mat(col: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = rough
	return m
