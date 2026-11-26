class_name HdRosterFx
extends RefCounted
## Eigene Bildsprache der Kaderhelden. Alle Aufrufe laufen über HdFx play/hold,
## damit Lebensdauer, Effektbudget und Koop dieselben Regeln wie Torvik/Unrat nutzen.
static var _materials := {}
static var _definitions := {}


static func _ability(hero: String, slot: int) -> Dictionary:
	if _definitions.is_empty():
		for definition in Database.load_json("res://data/heroes_helden.json").heroes:
			_definitions[str(definition.id)] = definition
	return _definitions.get(hero, {}).get("abilities", [{},{},{},{}])[clampi(slot,0,3)]


static func _clear(root: Node3D) -> void:
	for child in root.get_children(): child.free()


static func _mat(c: Color, metal := false) -> StandardMaterial3D:
	var key := c.to_html() + str(metal)
	if _materials.has(key): return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = .38 if metal else .72
	m.metallic = .7 if metal else .05
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = .15 if metal else .75
	_materials[key] = m
	return m


static func _line(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var points := PackedVector3Array([a,b])
	parent.add_child(HdFxParts.ribbon(points, width, HdFxParts.strip_material(color, {"taper":.4,"flow":2.0})))


static func _shard(parent: Node3D, at: Vector3, height: float, c: Color, lean := 0.0) -> MeshInstance3D:
	var mesh := HdDev.cyl(0, height * .18, height, _mat(c), at + Vector3.UP * height * .5, 5)
	mesh.rotation.z = lean
	parent.add_child(mesh)
	return mesh


static func _ring(parent: Node3D, r: float, c: Color, mode := HdFxParts.SIGIL) -> Node3D:
	var ground := HdFxParts.ground(mode, r, c)
	(ground.material_override as ShaderMaterial).set_shader_parameter("progress",1.0)
	ground.position.y = .14
	parent.add_child(ground)
	return ground


static func _bell(parent: Node3D, at: Vector3, size: float, c: Color) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.add_child(HdDev.cyl(size*.2,size*.5,size*.65,_mat(Color("b39a67"),true),Vector3.UP*size*.3,12))
	root.add_child(HdDev.cyl(size*.55,size*.55,size*.08,_mat(c),Vector3.ZERO,12))
	root.add_child(HdDev.sphere(size*.1,_mat(c),Vector3(0,-size*.1,0)))
	root.set_meta("swing", .25)
	parent.add_child(root)
	return root


static func _bird(parent: Node3D, at: Vector3, size: float, c: Color) -> Node3D:
	var bird := Node3D.new()
	bird.position = at
	var body := HdDev.sphere(.13*size,_mat(c),Vector3.ZERO)
	body.scale = Vector3(.8,.75,1.7)
	bird.add_child(body)
	bird.add_child(HdDev.sphere(.09*size,_mat(c),Vector3(0,.04,-.23)*size))
	var beak := HdDev.cyl(0,.045*size,.16*size,_mat(c.lightened(.2)),Vector3(0,.035,-.36)*size,4)
	beak.rotation.x = PI*.5
	bird.add_child(beak)
	for s in [-1.0,1.0]:
		var wing := MeshInstance3D.new()
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outline := [Vector3.ZERO,Vector3(s*.8,0,-.08),Vector3(s*.7,0,.08),Vector3(s*.48,0,.13),Vector3(s*.6,0,.24),Vector3(s*.28,0,.36),Vector3(0,0,.2)]
		for k in range(1,outline.size()-1):
			for index in [0,k,k+1]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(outline[index]*size)
		wing.mesh = surface.commit()
		var feather := _mat(c.darkened(.2)).duplicate() as StandardMaterial3D
		feather.cull_mode = BaseMaterial3D.CULL_DISABLED
		wing.material_override = feather
		wing.rotation.z = s * .35
		wing.set_meta("wing", s)
		bird.add_child(wing)
	bird.set_meta("orbit", at.length())
	parent.add_child(bird)
	return bird


static func _lantern(parent: Node3D, at: Vector3, size: float, c: Color) -> Node3D:
	var lamp := Node3D.new()
	lamp.position = at
	lamp.add_child(HdDev.cyl(size*.25,size*.35,size*.18,_mat(Color("b39a67"),true),Vector3.UP*size*.4,6))
	lamp.add_child(HdDev.cyl(size*.35,size*.25,size*.18,_mat(Color("b39a67"),true),Vector3.UP*-size*.4,6))
	lamp.add_child(HdFxParts.halo(size*2,c))
	for k in 6:
		var angle := TAU*k/6.0
		lamp.add_child(HdDev.box(Vector3(.035,.8,.035)*size,_mat(c),Vector3(cos(angle)*.27,0,sin(angle)*.27)*size))
	lamp.set_meta("hover", .12)
	parent.add_child(lamp)
	return lamp


static func _chain(parent: Node3D, a: Vector3, b: Vector3, c: Color, links := 12) -> void:
	var link_radius := a.distance_to(b) / links * .65
	for k in links:
		var t := (k+.5)/float(links)
		var link := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = link_radius * .55
		torus.outer_radius = link_radius * .9
		torus.rings = 8
		torus.ring_segments = 4
		link.mesh = torus
		link.material_override = _mat(c,true)
		link.position = a.lerp(b,t) + Vector3.DOWN*sin(t*PI)*.2
		link.basis = Basis.looking_at((b-a).normalized(),Vector3.UP) * Basis(Vector3.FORWARD,PI*.5 if k%2 else 0)
		parent.add_child(link)


static func _anchor(parent: Node3D, size: float, c: Color) -> void:
	parent.add_child(HdDev.box(Vector3(.11,1.1,.11)*size,_mat(c,true),Vector3.ZERO))
	parent.add_child(HdDev.box(Vector3(.65,.09,.1)*size,_mat(c,true),Vector3(0,.3,0)*size))
	for s in [-1.0,1.0]:
		var arm := HdDev.box(Vector3(.5,.11,.12)*size,_mat(c,true),Vector3(s*.2,-.45,0)*size)
		arm.rotation.z = s*.5
		parent.add_child(arm)
		var tip := _shard(parent,Vector3(s*.42,-.3,0)*size,.3*size,c,s*-.5)
		tip.rotation.x = PI


static func _wolf(parent: Node3D, at: Vector3, size: float, c: Color) -> Node3D:
	var wolf := Node3D.new()
	wolf.position = at
	var body := HdDev.sphere(.42*size,_mat(c),Vector3(0,.5,0)*size)
	body.scale = Vector3(.65,.8,1.5)
	wolf.add_child(body)
	wolf.add_child(HdDev.box(Vector3(.3,.3,.55)*size,_mat(c),Vector3(0,.85,-.6)*size))
	for s in [-1.0,1.0]:
		_shard(wolf,Vector3(s*.12,1,-.5)*size,.25*size,c)
		for z in [-.35,.35]:
			wolf.add_child(HdDev.box(Vector3(.09,.5,.12)*size,_mat(c),Vector3(s*.23,.25,z)*size))
	wolf.set_meta("orbit",at.length())
	parent.add_child(wolf)
	return wolf


static func make(id: String, size: float, c: Color) -> Node3D:
	var parts := id.split(":")
	var hero := str(parts[1])
	var slot := int(parts[2]) if parts.size()>2 else 0
	var ability := _ability(hero,slot)
	var op := str(ability.get("op", "blast"))
	var n := Node3D.new()
	var r := clampf(size,1.2,10)
	if op in ["guard","buff","form"]: r = 1.8
	var ultimate := slot == 3
	var count: int = [3,5,4,8][clampi(slot,0,3)]
	if Display.quality == Display.LOW: count = maxi(2,count/2)
	match hero:
		"brennholt":
			_ring(n,r,c)
			var shields := 7 if ultimate else 1 if slot==0 else 3
			for k in shields:
				var shield := HdDev.box(Vector3(.65,1.3,.09),_mat(c,true),Vector3((k-(shields-1)*.5)*.8,.8,-r*.45))
				shield.rotation.z = -.12 if k%2 else .12
				n.add_child(shield)
				_line(n,shield.position-Vector3.UP*.45,shield.position+Vector3.UP*.45,.06,Color("dfc68e"))
		"mira":
			_ring(n,r,c,HdFxParts.CRACK)
			for k in count:
				var angle := k*TAU/count
				var at := Vector3(0,0,-k*.85) if slot==2 else Vector3(cos(angle),0,sin(angle))*r*.65
				_shard(n,at,1.0+float(k%3)*.4,Color("74858b"),cos(angle)*.2)
			if slot==1: n.add_child(HdFxParts.dome(1.4,Color("829384")))
		"grauhirte":
			_ring(n,r,c,HdFxParts.SWIRL)
			for k in (4 if ultimate else 2):
				var angle := k*TAU/(4 if ultimate else 2)
				var wolf := _wolf(n,Vector3(cos(angle),.15,sin(angle))*r*.55,.8,c)
				wolf.rotation.y = -angle
		"sirra":
			_ring(n,r,c,HdFxParts.SCORCH)
			if slot==2:
				n.add_child(HdFxParts.burst(Color(.14,.09,.2,.45),22,{"loop":true,"life":1.0,"size":1.1,"ring":r*.65,"mix":true,"end_scale":2.0,"gravity":Vector3(0,.3,0)}))
			for k in count:
				var butterfly := _bird(n,Vector3(cos(k*2.4)*r*.6,1.0+float(k%3)*.3,sin(k*2.4)*r*.6),.6,c)
				butterfly.rotation.z = k*.7
		"kaspar":
			_ring(n,r,c)
			for k in count:
				var a := k*TAU/count
				var bolt := HdDev.box(Vector3(.08,.08,1.5),_mat(Color("ced6df"),true),Vector3(cos(a),.8,sin(a))*r*.5)
				bolt.rotation.y = -a
				n.add_child(bolt)
				_line(n,bolt.position,bolt.position+Vector3.UP*.7,.08,c)
		"yuna":
			for k in (8 if ultimate else 2 if slot==0 else 3):
				var blade := HdFxParts.arc(r*(.6+k*.12),.12+k*.03,-1.1,1.2,HdFxParts.strip_material(c,{"taper":1.0,"flow":6.0}),24)
				blade.position.y = .5+k*.35
				blade.rotation = Vector3(PI*.5,0,(-.6 if k%2 else .6)) if slot==2 else Vector3(k*.18,k*.9,.15)
				blade.set_meta("spin",Vector3(0,1.2+k*.4,0))
				n.add_child(blade)
		"orrin":
			_ring(n,r,Color("f06b22"),HdFxParts.SCORCH)
			for k in count:
				var flame := HdFxParts.tube(.25,.02,1.3+float(k%3)*.35,1,Color("ff8f36"),2)
				flame.position = Vector3((k-(count-1)*.5)*.65,0,-r*.3) if slot==1 else Vector3(cos(k*2.4),0,sin(k*2.4))*r*.5
				flame.set_meta("pulse",.15)
				n.add_child(flame)
			if ultimate:
				var meteor := HdDev.cyl(.6,1.0,1.2,_mat(Color("653b29")),Vector3(0,3.5,-1.5),7)
				meteor.rotation = Vector3(.4,.7,.2)
				meteor.set_meta("meteor",true)
				n.add_child(meteor)
				meteor.add_child(HdFxParts.trail(Color("ff8533"),.3,.5,18))
				for k in 5: _shard(meteor,Vector3(cos(k),.4,sin(k))*.6,.45,Color("ffc16b"))
		"ilsabet":
			_ring(n,r,c,HdFxParts.CRACK)
			for k in count:
				var angle := k*TAU/count
				var at := Vector3((k-(count-1)*.5)*.75,0,-r*.4) if ultimate else Vector3(cos(angle),0,sin(angle))*r*(.3 if slot==2 else .65)
				var ice := _shard(n,at,(2.5 if slot==2 else 1.1)+float(k%3)*.5,c,cos(angle)*.3)
				ice.set_meta("pulse",.035)
		"tamo":
			_ring(n,r,c,HdFxParts.CRACK)
			if ultimate:
				for k in 4:
					var cloud := HdDev.sphere(1.1,_mat(Color("48546b")),Vector3((k-1.5)*.8,3.5,0))
					cloud.scale = Vector3(1,.4,1)
					n.add_child(cloud)
			for k in (5 if ultimate else 3):
				var points := PackedVector3Array()
				for j in 8:
					points.append(Vector3((k-2)*r*.3+sin(j*2.7)*.25,3.5-j*.45,cos(j*1.9)*.3))
				n.add_child(HdFxParts.ribbon(points,.09,HdFxParts.strip_material(Color("c6e8ff"),{"flow":8.0})))
		"albe":
			_ring(n,r,c)
			_lantern(n,Vector3(0,2.4,-1.3),1.3 if ultimate else .8,c)
			for k in count:
				var a := k*TAU/count
				_line(n,Vector3(0,2.2,0),Vector3(cos(a)*r,.2,sin(a)*r),.12,c)
			if slot==0: _line(n,Vector3(0,1,0),Vector3(0,1,-r*2),.45,c)
		"fenn":
			_ring(n,r,c,HdFxParts.GLOW)
			for k in (3 if ultimate else 1):
				_lantern(n,Vector3(cos(k*2.1),1.5,sin(k*2.1))*r*.4,.7,c)
				var ray := HdFxParts.tube(.12,.02,3,2,c,1)
				ray.position = Vector3(cos(k*2.1),0,sin(k*2.1))*r*.4
				n.add_child(ray)
		"ralda":
			_ring(n,r,c)
			var anvil := HdDev.box(Vector3(1.2,.4,.65),_mat(Color("566270"),true),Vector3(0,.75,0))
			n.add_child(anvil)
			n.add_child(HdDev.box(Vector3(.5,.7,.55),_mat(c,true),Vector3(0,.35,0)))
			for k in count:
				var a := k*TAU/count
				_line(n,Vector3(cos(a),.2,sin(a))*r*.5,Vector3(cos(a),.2,sin(a))*r*.8,.1,c)
		"varg":
			_ring(n,r,Color("b84038"),HdFxParts.SCORCH)
			for k in count:
				var claw := HdFxParts.arc(r*.7,.13,-.7,.9,HdFxParts.strip_material(Color("db6551"),{"taper":1.0,"flow":3.0}),12)
				claw.rotation = Vector3(.9,k*TAU/count,.2)
				claw.position.y = .6
				n.add_child(claw)
		"lior":
			_ring(n,r,c)
			for k in count:
				var a := k*TAU/count
				var mirror := HdDev.box(Vector3(.6,1.1,.04)*(1.6 if slot==2 else 1.0),_mat(Color("b0c9e4"),true),Vector3(cos(a)*r*.6,1.3,sin(a)*r*.6))
				mirror.rotation = Vector3(.15,a,.25)
				mirror.set_meta("spin",Vector3(0,.6,0))
				n.add_child(mirror)
		"kraehenfrau":
			_ring(n,r,c,HdFxParts.SCORCH)
			for k in (HdFxParts.amount(10) if ultimate else count):
				var bird := _bird(n,Vector3(cos(k*2.4)*r*.7,1.0+float(k%4)*.4,sin(k*2.4)*r*.7),.9,Color("272337"))
				bird.rotation.y = -k*2.4
		"bruno":
			_ring(n,r,Color("c9a05b"),HdFxParts.WAVE)
			if slot==1: n.add_child(HdFxParts.dome(1.5,Color("d3b46b")))
			for k in (3 if ultimate else 1):
				var barrel := _barrel(.7,c)
				barrel.position = Vector3((k-(2 if ultimate else 0)*.5)*1.5,.7,0)
				barrel.set_meta("spin",Vector3(1.8,0,0))
				n.add_child(barrel)
		"tessa":
			_ring(n,r,c,HdFxParts.SWIRL)
			for k in (6 if ultimate else 3):
				var gust := HdFxParts.arc(r*(.4+k*.08),.12,-1.2,1.4,HdFxParts.strip_material(c,{"flow":5.0,"taper":1.0}),24)
				gust.position.y = .3+k*.3
				gust.rotation.y = k*1.5
				gust.set_meta("spin",Vector3(0,1.8,0))
				n.add_child(gust)
		"totengraeber":
			_ring(n,r,c,HdFxParts.SIGIL)
			for k in count:
				var a := k*TAU/count
				var soul := Node3D.new()
				soul.position = Vector3(cos(a)*r*.6,.6,sin(a)*r*.6)
				soul.add_child(HdDev.sphere(.13,_mat(c),Vector3.UP*.9))
				soul.add_child(HdFxParts.tube(.02,.22,.8,2,c,1))
				soul.set_meta("hover",.3)
				n.add_child(soul)
		"ada":
			for k in (3 if ultimate else 1):
				_ring(n,r*(.45+k*.23),c,HdFxParts.WAVE)
				_bell(n,Vector3(cos(k*2.1)*r*.4,1.8,sin(k*2.1)*r*.4),.75,c)
		"sorek":
			_ring(n,r,c,HdFxParts.CRACK)
			var anchor := Node3D.new()
			anchor.position = Vector3(0,1.2,-r*.45)
			_anchor(anchor,1.5,c)
			n.add_child(anchor)
			for k in (8 if slot==1 else 4 if ultimate else 2):
				var a := k*TAU/(8 if slot==1 else 4 if ultimate else 2)
				var start := Vector3(cos(a),.25,sin(a))*r*.6 if slot==1 else Vector3(0,.8,0)
				_chain(n,start,Vector3(cos(a)*r,.25,sin(a)*r),Color("b6a16f"),8)
			if slot==2: n.add_child(HdFxParts.dome(1.6,c))
	# Die Fähigkeit bestimmt die Inszenierung: Geschoss, gerichteter Hieb, Bauplan,
	# Schutz oder Flächenwirkung bleiben auch innerhalb eines Heldenthemas unterscheidbar.
	if op in ["shot","shots"]:
		_clear(n)
		var shot := projectile(hero,c,.25)
		shot.position = Vector3(0,1,-1.3)
		n.add_child(shot)
		_line(n,Vector3(0,1,-.4),Vector3(0,1,-2.8),.16,c)
	elif op in ["turret","wall"]:
		_clear(n)
		_ring(n,r,c)
		var pet := "wall" if op=="wall" else str(ability.get("pet", "crossbow"))
		for k in (5 if op=="wall" else 1):
			var construct := HdRosterConstruct.new()
			construct.def = {"pet":pet,"color":c.to_html(false)}
			construct._build()
			construct.position = Vector3((k-2)*1.5,0,-1.5) if op=="wall" else Vector3(0,0,-1.7)
			construct.scale = Vector3.ONE * (1.5 if pet=="mortar" else 1.0)
			n.add_child(construct)
			for mesh: MeshInstance3D in construct.find_children("*","MeshInstance3D",true,false):
				mesh.material_override = HdFxParts.shell_material(2,c)
	elif op in ["cone","pull","line","dash"]:
		for child in n.get_children():
			if child is MeshInstance3D and child.mesh is PlaneMesh: child.free()
		var trace := HdFxParts.arc(minf(r,3.5),.18,-.9,.9,HdFxParts.strip_material(c,{"taper":1.0,"flow":5.0}),24)
		trace.position.y = .8
		n.add_child(trace)
		if op in ["line","dash"]:
			var line := HdFxParts.ground(HdFxParts.GUST,1.4,c,float(ability.get("range",8)))
			(line.material_override as ShaderMaterial).set_shader_parameter("progress",1.0)
			line.position.y = .15
			n.add_child(line)
	elif op == "buff":
		_clear(n)
		_ring(n,r,c)
		for s in [-1.0,1.0]:
			_line(n,Vector3(s*.7,.5,0),Vector3(s*.7,2.4,0),.16,c)
			_line(n,Vector3(s*.7-.3,1.7,0),Vector3(s*.7+.3,1.7,0),.12,c)
	if op in ["guard","form"]:
		n.add_child(HdFxParts.dome(1.45,c))
	if hero=="ralda" and slot==0:
		_clear(n)
		var head := HdDev.box(Vector3(1.3,.5,.6),_mat(c,true),Vector3(0,.6,-1.5))
		n.add_child(head)
		_line(n,Vector3(0,.6,-1.5),Vector3(0,2,-1.5),.12,c)
		_ring(n,2.2,c,HdFxParts.CRACK)
	return n


static func _barrel(size: float, c: Color) -> Node3D:
	var n := Node3D.new()
	n.add_child(HdDev.cyl(size*.65,size*.65,size*1.5,_mat(Color("705030")),Vector3.ZERO,12))
	for y in [-.6,0,.6]:
		n.add_child(HdDev.cyl(size*.68,size*.68,size*.08,_mat(c,true),Vector3.UP*y*size,12))
	n.rotation.x = PI*.5
	return n


static func play(fx: HdFx, id: String, at: Vector3, dir: Vector3, size: float, color: Color, _to: Vector3) -> void:
	var root := make(id,size,color)
	root.position = at
	root.rotation.y = atan2(-dir.x,-dir.z)
	var life := 1.0 if id.contains(":3:") else .75
	if not fx._add(root,life+.5): return
	root.scale = Vector3.ONE*.35
	var tween := root.create_tween()
	tween.tween_property(root,"scale",Vector3.ONE,.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(life*.45)
	tween.tween_callback(func():
		if is_instance_valid(root): fx._fade_out(root,life*.45))
	fx._sparks(at+Vector3.UP*.2,color,18 if id.contains(":3:") else 8,{"life":.5,"size":.12,"ring":size*.5,"speed":[.4,1.5],"gravity":Vector3(0,.7,0)})
	if id.contains(":3:"): fx._flash(at,color,2,size+2,.2)
	for part in root.get_children():
		if part.has_meta("meteor"):
			part.create_tween().tween_property(part,"position:y",.5,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fx._sparks(at+Vector3.UP*.2,Color("ff9b48"),24,{"life":.7,"size":.18,"speed":[1.2,3.5],"gravity":Vector3(0,-3,0)})
		if part.has_meta("spin"):
			part.create_tween().tween_property(part,"rotation",part.rotation+Vector3(part.get_meta("spin"))*life,life)
		if part.has_meta("hover"):
			part.create_tween().tween_property(part,"position:y",part.position.y+float(part.get_meta("hover")),life)


static func tick(root: Node3D, age: float, dt: float) -> void:
	for part in root.get_children():
		if part.has_meta("spin"): part.rotation += Vector3(part.get_meta("spin"))*dt
		if part.has_meta("swing"): part.rotation.z = sin(age*5)*float(part.get_meta("swing"))
		if part.has_meta("hover"): part.position.y += cos(age*2.5)*float(part.get_meta("hover"))*dt
		if part.has_meta("pulse"): part.scale.y = 1.0+sin(age*4)*float(part.get_meta("pulse"))
		if part.has_meta("orbit"):
			part.position = part.position.rotated(Vector3.UP,dt*.5)
			for wing in part.get_children():
				if wing.has_meta("wing"): wing.rotation.z = sin(age*14)*.55*float(wing.get_meta("wing"))


static func projectile(hero: String, c: Color, size: float) -> Node3D:
	var n := Node3D.new()
	var s := size*2.5
	match hero:
		"bruno": n.add_child(_barrel(s,c))
		"sorek":
			_anchor(n,s,c)
			_chain(n,Vector3(0,0,-s),Vector3(0,0,-s*5),Color("b6a16f"),8)
		"ilsabet":
			_shard(n,Vector3.ZERO,s*3,c)
			n.rotation.x = PI*.5
		"sirra", "kraehenfrau":
			var blade := HdDev.box(Vector3(s*.18,s*.05,s*2.5),_mat(c,true))
			blade.rotation.z = .4
			n.add_child(blade)
			for k in 3: _shard(n,Vector3(s*.15,0,-k*s*.5),s*.4,c,.7)
		"orrin":
			n.add_child(HdDev.sphere(s*.6,_mat(Color("ffb65b"))))
			n.add_child(HdFxParts.tube(s*.8,.02,s*3,1,Color("ff6522"),3))
			n.rotation.x = PI*.5
		"lior":
			var glass := HdDev.box(Vector3(s*.8,s*.06,s*2),_mat(Color("b0c9e4"),true))
			glass.rotation.z = .5
			n.add_child(glass)
		_:
			n.add_child(HdDev.box(Vector3(s*.09,s*.09,s*2.2),_mat(Color("cbd4dd"),true)))
			for side in [-1,1]:
				var fin := HdDev.box(Vector3(s*.5,s*.035,s*.5),_mat(c),Vector3(side*s*.2,0,-s*.7))
				fin.rotation.z = side*.2
				n.add_child(fin)
	if hero != "bruno": n.add_child(HdFxParts.trail(c,size,.3,10))
	return n
