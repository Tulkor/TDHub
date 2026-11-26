extends RefCounted
## Static decoration only: preserve geometry/materials, partition bounds for camera culling.
static var enabled := true

static func add(root: Node3D, mesh: Mesh, transforms: Array, cell_size := 48.0,
		shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON, layers := 1, gi := GeometryInstance3D.GI_MODE_DISABLED) -> int:
	return add_nodes(root, mesh, transforms, cell_size, shadow, layers, gi).size()


## Wie add, gibt aber die erzeugten Knoten zurück. Kacheln statt einer kartengroßen MultiMesh haben
## zwei Vorteile: Kacheln außerhalb des Bildes fallen weg, und Godots automatisches LOD greift. Bei einer
## MultiMesh, deren AABB die Kameraebene schneidet, rechnet Godot mit Abstand 0 und zeichnet jede Instanz
## in voller Auflösung (Bäume: 3000–5000 Dreiecke je Stück).
static func add_nodes(root: Node3D, mesh: Mesh, transforms: Array, cell_size := 48.0,
		shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON, layers := 1, gi := GeometryInstance3D.GI_MODE_DISABLED,
		cull_margin := 0.0) -> Array[MultiMeshInstance3D]:
	var cells := {}
	for transform: Transform3D in transforms:
		var cell := Vector2i(floori(transform.origin.x / cell_size), floori(transform.origin.z / cell_size)) if enabled and cell_size > 0.0 else Vector2i.ZERO
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(transform)
	var out: Array[MultiMeshInstance3D] = []
	for cell in cells:
		var instances: Array = cells[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = instances.size()
		for index in instances.size(): mm.set_instance_transform(index, instances[index])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = shadow
		node.layers = layers
		node.gi_mode = gi
		node.extra_cull_margin = cull_margin
		root.add_child(node)
		out.append(node)
	return out


static func combine(root: Node3D, sources: Array, cell_size := 24.0) -> Dictionary:
	if not enabled: return {"instances":0,"batches":0}
	var groups := {}
	var count := 0
	for source: Node3D in sources:
		for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			if not part.is_visible_in_tree() or not part.mesh is ArrayMesh: continue
			var key := str(part.mesh.get_instance_id()) + ":%d:%d:%d" % [part.cast_shadow,part.layers,part.gi_mode]
			for surface in part.mesh.get_surface_count():
				var material := part.get_active_material(surface)
				key += ":" + str(material.get_instance_id() if material != null else 0)
			if not groups.has(key):
				var mesh: ArrayMesh = part.mesh.duplicate()
				for surface in mesh.get_surface_count(): mesh.surface_set_material(surface,part.get_active_material(surface))
				groups[key] = {"mesh":mesh,"transforms":[],"shadow":part.cast_shadow,"layers":part.layers,"gi":part.gi_mode}
			groups[key].transforms.append(root.global_transform.affine_inverse()*part.global_transform)
			count += 1
	var batches := 0
	for group in groups.values():
		batches += add(root,group.mesh,group.transforms,cell_size,group.shadow,group.layers,group.gi)
	for source in sources: source.free()
	return {"instances":count,"batches":batches}
