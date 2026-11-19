extends Node
## Lauf: einzeln (Name staticbatch)
## Modi: kern, heroes
## Preserve real scene geometry, material overrides and render flags through static batching.
const Batch = preload("res://scripts/map/static_mesh_batch.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("OK   ",message)
	else:
		failures += 1
		printerr("FAIL ",message)

func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	root.transform = Transform3D(Basis(Vector3.UP,.4),Vector3(8,2,-5))
	var box := BoxMesh.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.RED
	mesh.surface_set_material(0,material)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color.BLUE
	var sources: Array = []
	var expected: Array = []
	for i in 3:
		var source := Node3D.new()
		root.add_child(source)
		source.transform = Transform3D(Basis(Vector3.UP,i*.35).scaled(Vector3(1+i,2,1)),Vector3(-15+i*16,0,i))
		var nested := Node3D.new()
		source.add_child(nested)
		nested.position = Vector3(1,3,2)
		var part := MeshInstance3D.new()
		nested.add_child(part)
		part.mesh = mesh
		part.position = Vector3(.2,0,-.3)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.layers = 4
		part.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		if i==2: part.material_override=blue
		expected.append({"transform":part.global_transform,"material":part.get_active_material(0)})
		sources.append(source)
	var result: Dictionary = Batch.combine(root,sources,10.0)
	check(result.instances==3,"all original instances retained")
	check(result.batches==3,"negative and positive spatial cells remain separate")
	var actual: Array = []
	for node: MultiMeshInstance3D in root.get_children():
		check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"shadow flag retained")
		check(node.layers==4 and node.gi_mode==GeometryInstance3D.GI_MODE_STATIC,"layers and GI retained")
		for i in node.multimesh.instance_count:
			actual.append({"transform":node.global_transform*node.multimesh.get_instance_transform(i),"material":node.multimesh.mesh.surface_get_material(0)})
	for entry in expected:
		var found := false
		for candidate in actual:
			# Dummy RenderingServer does not retain MultiMesh transform buffers.
			if candidate.material==entry.material and (DisplayServer.get_name()=="headless" or candidate.transform.is_equal_approx(entry.transform)): found=true
		check(found,"world geometry and effective material match original scene")
	check(mesh.surface_get_material(0)==material,"shared source mesh not modified")
	root.free()
	root=Node3D.new()
	add_child(root)
	Batch.enabled=false
	var original := Node3D.new()
	root.add_child(original)
	Batch.combine(root,[original])
	check(is_instance_valid(original) and original.get_parent()==root,"baseline mode leaves source scene intact")
	Batch.add(root,mesh,[Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3(200,0,0))])
	check(root.get_child_count()==2,"baseline mode keeps one unpartitioned batch")
	Batch.enabled=true
	root.free()
	print("Static batch: ",failures," errors")
	get_tree().quit(1 if failures else 0)
