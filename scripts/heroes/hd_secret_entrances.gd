class_name HdSecretEntrances
extends RefCounted
## Geschlossene Hüllen mit echter Türöffnung; die Belohnung bleibt im getrennten Raum.

static func build(parent: Node3D, site: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name="SecretEntrance_"+str(site.id)
	parent.add_child(root)
	var direction: Vector3=(site.pos-site.path[-2]).normalized()
	var yaw := atan2(direction.x,direction.z)
	var at: Vector3=site.pos
	var builder := HdCathedral.new()
	builder._root=root
	builder._rng.seed=721+int(site.order[0])
	var stone := HdCathedral.wall_material()
	var trim := builder._solid("entrance_trim",Color("74757b"))
	var dark := builder._solid("entrance_dark",Color("070a0d"))
	var building := str(site.entrance_kind)=="building"
	if building:
		for side in [-1.0,1.0]:
			builder._part("box",stone,Vector3(.8,6.0,8.5),at,Vector3(side*3.5,2.8,3),1,yaw)
			builder._part("box",stone,Vector3(1.9,5.8,.9),at,Vector3(side*2.55,2.8,-1.0),1,yaw)
			builder._part("box",trim,Vector3(.45,6.7,1.3),at,Vector3(side*3.8,3.1,-.8),1,yaw)
			builder._part("spire",HdCathedral.roof_material(),Vector3(.8,2.0,.8),at,Vector3(side*3.8,7.0,-.8),1,yaw+PI*.25)
			for z in [1.0,4.5]:
				builder._part("box",stone,Vector3(1.2,4.8,1.0),at,Vector3(side*3.9,2.2,z),1,yaw)
		builder._part("box",stone,Vector3(7.2,6,.8),at,Vector3(0,2.8,7.1),1,yaw)
		builder._part("box",stone,Vector3(7.4,1.5,1),at,Vector3(0,5.2,-1),1,yaw)
		builder._part("box",trim,Vector3(8,.3,9),at,Vector3(0,5.9,3),1,yaw)
		builder._part("gable",HdCathedral.roof_material(),Vector3(8.1,3.4,9.4),at,Vector3(0,6.1,3),1,yaw)
		builder._rose(at+Vector3(0,6.6,-1.73).rotated(Vector3.UP,yaw),yaw+PI,.65)
	else:
		var shell := SurfaceTool.new()
		shell.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in 4:
			for step in 12:
				var vertices: Array = []
				for cell in [Vector2i(ring,step),Vector2i(ring+1,step),Vector2i(ring,step+1),Vector2i(ring+1,step+1)]:
					var t := float(cell.x)/4.0
					var profile: Vector2=[Vector2(3.0,4.7),Vector2(5.4,6.5),Vector2(7.0,7.8),Vector2(5.6,6.4),Vector2(.05,.15)][cell.x]
					var angle := PI*float(cell.y)/12.0
					var rough := 1.0+.07*sin(float(cell.y)*3.7+float(cell.x)*2.3)
					vertices.append(Vector3(cos(angle)*profile.x*rough,sin(angle)*profile.y*rough-.35,lerpf(-1.6,14,t)))
				for index in [0,2,1,1,2,3,1,2,0,3,2,1]:shell.add_vertex(vertices[index])
		shell.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name="MountainCaveShell"
		mesh.mesh=shell.commit()
		mesh.material_override=HdArenaMountains._material(22.0)
		mesh.transform=Transform3D(Basis(Vector3.UP,yaw),at)
		root.add_child(mesh)
	# Der schwarze Tunnelabschluss liegt hinter der Eintrittsschwelle, nie vor dem Spieler.
	builder._part("box",dark,Vector3(5.8,4.9,.2),at,Vector3(0,2.25,2.0),1,yaw)
	builder._arch(at+Vector3(0,0,-1.5).rotated(Vector3.UP,yaw),yaw,3.2,4.4,stone,.52)
	if building:builder._arch(at+Vector3(0,0,-1.55).rotated(Vector3.UP,yaw),yaw,3.7,4.7,trim,.14)
	for side in [-1.0,1.0]:
		for i in 4:
			builder._part("box",stone,Vector3(.7,.25,.85),at,Vector3(side*(3.8+float(i)*.3),.1,float(i)*1.5-.5),1,yaw+float(i)*.27)
	builder._flush()
	root.set_meta("entrance_kind",str(site.entrance_kind))
	root.set_meta("trigger_pos",at)
	return root
