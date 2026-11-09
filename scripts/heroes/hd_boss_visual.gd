class_name HdBossVisual
extends Node3D
## Eigene, prozedurale Boss-Silhouetten im vorhandenen Bollwerk-Prototypstil.
## Farbe ergänzt die Form; gegnerische Warnfarben bleiben barrierefrei über HdTelegraph steuerbar.

var core: Node3D
var halo: Node3D
var spin := 0.18


func build(data: Dictionary) -> void:
	var theme := str(data.visual.theme)
	var dark := HdDev.mat(Color(str(data.color)), 0.18)
	var accent_color := Color(str(data.visual.accent))
	var accent := HdDev.mat(accent_color, 0.2, 0.7)
	var metal := HdDev.mat(Color("9d9587"), 0.18)
	match theme:
		"forge":
			_part(HdDev.box(Vector3(2.5, 2.1, 1.6), dark, Vector3(0, 2.2, 0)))
			for side in [-1.0, 1.0]:
				_part(HdDev.cyl(0.45, 0.55, 1.6, dark, Vector3(side * 0.75, 0.8, 0)))
				_part(HdDev.box(Vector3(1.1, 0.8, 1.9), metal, Vector3(side * 1.55, 3, 0)))
				var chain := _ring(0.43, metal, Vector3(side * 1.6, 2, -0.25))
				chain.rotation.x = PI * 0.5
				_ring(0.35, accent, Vector3(side * 1.6, 1.35, -0.25)).rotation.x = PI * 0.5
			_part(HdDev.box(Vector3(1.2, 0.75, 0.9), accent, Vector3(2.25, 1.5, -0.4)))
			_part(HdDev.cyl(0.12, 0.12, 2.5, metal, Vector3(2.25, 2.2, -0.4)))
			_part(HdDev.cyl(0.55, 0.75, 1.1, dark, Vector3(0, 3.65, 0), 6))
			core = _part(HdDev.sphere(0.45, accent, Vector3(0, 2.3, -0.85)))
			halo = _ring(1.0, accent, Vector3(0, 4.1, 0))
		"tide":
			_part(HdDev.cyl(0.65, 1.3, 3.2, dark, Vector3(0, 1.65, 0), 10))
			for side in [-1.0, 1.0]:
				var fin := _spike(Vector3(side * 1.15, 2.6, 0), Vector3(1.4, 2.1, 0.3), accent)
				fin.rotation.z = side * -0.4
				_part(HdDev.sphere(0.35, metal, Vector3(side * 0.9, 1.5, -0.2)))
			_part(HdDev.sphere(0.65, dark, Vector3(0, 3.55, 0)))
			for k in 5:
				var a := TAU * k / 5.0
				_spike(Vector3(cos(a) * 0.5, 4.05, sin(a) * 0.5), Vector3(0.2, 0.8, 0.2), accent)
			_part(HdDev.cyl(0.1, 0.1, 3.6, metal, Vector3(1.8, 2.0, -0.3)))
			for k in [-1, 0, 1]:
				_spike(Vector3(1.8 + k * 0.27, 4.0, -0.3), Vector3(0.16, 0.9, 0.2), accent)
			core = _part(HdDev.sphere(0.32, accent, Vector3(0, 2.75, -0.7)))
			halo = _ring(1.6, accent, Vector3(0, 0.2, 0))
		"rot":
			_part(HdDev.cyl(0.7, 1.45, 3.4, dark, Vector3(0, 1.7, 0), 8))
			for k in 6:
				var a := TAU * k / 6.0
				var branch := HdDev.cyl(0.1, 0.25, 2.0, metal, Vector3(cos(a) * 1.25, 2.35, sin(a) * 1.25))
				branch.rotation.z = cos(a) * -0.7
				branch.rotation.x = sin(a) * 0.7
				_part(branch)
				var cap := _part(HdDev.sphere(0.65, accent, Vector3(cos(a) * 1.4, 3.3, sin(a) * 1.4)))
				cap.scale.y = 0.45
			_part(HdDev.sphere(0.8, dark, Vector3(0, 3.5, 0)))
			core = _part(HdDev.sphere(0.4, accent, Vector3(0, 3.5, -0.75)))
			halo = _ring(1.4, metal, Vector3(0, 4.0, 0))
		"time":
			_part(HdDev.cyl(0.5, 0.95, 2.2, dark, Vector3(0, 1.4, 0), 6))
			var crystal := MeshInstance3D.new()
			crystal.mesh = Tower._gem_mesh()
			crystal.material_override = accent
			crystal.position.y = 3.0
			crystal.scale = Vector3(0.8, 1.3, 0.8)
			core = _part(crystal)
			halo = _ring(1.65, metal, Vector3(0, 2.7, 0))
			halo.rotation.x = PI * 0.5
			var inner := _ring(1.25, accent, Vector3(0, 2.7, 0))
			inner.rotation.z = PI * 0.5
			for k in 8:
				var a := TAU * k / 8.0
				_part(HdDev.box(Vector3(0.2, 0.45, 0.25), accent, Vector3(cos(a) * 1.6, 2.7 + sin(a) * 1.6, -0.05)))
			spin = -0.25
		"void":
			_part(HdDev.sphere(1.5, dark, Vector3(0, 2.3, 0)))
			for side in [-1.0, 1.0]:
				var horn := _spike(Vector3(side * 0.8, 4.0, 0), Vector3(0.7, 1.6, 0.7), metal)
				horn.rotation.z = -side * 0.35
			for k in 6:
				var a := TAU * k / 6.0
				for j in 3:
					var p := Vector3(cos(a) * (1.25 + j * 0.4), 1.5 - j * 0.35, sin(a) * (1.25 + j * 0.4))
					_part(HdDev.sphere(0.35 - j * 0.07, accent if j == 2 else dark, p))
			core = _part(HdDev.sphere(0.65, accent, Vector3(0, 2.5, -1.2)))
			halo = _ring(1.05, metal, Vector3(0, 2.5, -1.3))
			halo.rotation.x = PI * 0.5
	var s: Array = data.get("size", [4, 4.8, 4])
	scale = Vector3.ONE * float(s[1]) / 4.8


func animate(now: float, phase: int, casting: bool) -> void:
	if halo != null:
		halo.rotation.y = now * spin * (1.0 + phase * 0.3)
		halo.scale = Vector3.ONE * (1.0 + phase * 0.05)
	if core != null:
		var pulse := 1.0 + sin(now * (4.0 if casting else 2.0)) * 0.04
		# Der Kristall hat eine eigene Grundform, deshalb die Basisskalierung nur einmal merken.
		if not core.has_meta("base_scale"):
			core.set_meta("base_scale", core.scale)
		core.scale = core.get_meta("base_scale") * pulse * (1.0 + phase * 0.05)


func _part(node: MeshInstance3D) -> MeshInstance3D:
	add_child(node)
	return node


func _ring(radius: float, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.08
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 6
	node.mesh = mesh
	node.material_override = material
	node.position = at
	return _part(node)


func _spike(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	return _part(node)
