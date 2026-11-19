class_name HdBossFx
extends RefCounted
## Einschläge der Boss-Fähigkeiten. Die Form folgt der aufgelösten Warnfläche (Kreis, Ring, Kegel, Linie,
## Kreuz, Bogen, Kasten); Zeitpunkt und Schaden bestimmt weiter die Warnfläche. Darüber liegt je Boss-Thema
## eine eigene Schicht (VFX-Pass 2026-11-17, Lukas: eindrucksvoll und passend zum Thema):
##   forge  Kettenschmiede: Glutrisse, flüssige Eisensäulen, Funkenregen, Rauchsäule
##   tide   Sturmflut: Wassersäulen, Gischt, Schaumwelle, Nebel
##   rot    Dornenfäulnis: Dornen brechen auf, Sporenwolken, Fäulnislache
##   time   Gebrochene Zeit: Zifferblatt-Siegel, Lichtsäulen, schwebende Splitter, Zeitwelle
##   void   Kosmischer Schlund: Sog nach innen, dunkle Wolke, Tentakel, Sternenstaub
## Läuft über HdFx: Licht-, Lebensdauer-, Ton- und Netzbudgets gelten auch hier.


static func projectile(theme: String, color: Color, size: float) -> Node3D:
	var node := Node3D.new()
	if theme == "forge":
		node.add_child(HdDev.box(Vector3(.22,.22,.65),HdGothic.iron()))
		for z in [-.2,0,.2]: node.add_child(HdDev.box(Vector3(.25,.25,.04),HdGothic.glow(color),Vector3(0,0,z)))
		node.add_child(HdFxParts.burst(Color("ffb35c"),10,{"loop":true,"life":.35,"size":.12,"speed":[.5,1.5],"gravity":Vector3(0,-3,0)}))
	elif theme == "time":
		var ring := HdFxParts.halo(size*2.5,color)
		ring.rotation.x = PI*.5
		node.add_child(ring)
		node.add_child(HdDev.box(Vector3(.06,.45,.06),HdGothic.brass()))
	elif theme == "tide":
		node.add_child(HdDev.sphere(size*.8,HdGothic.glow(color,1.2)))
		node.add_child(HdFxParts.burst(HdFxParts.hot(color,.6),10,{"loop":true,"life":.3,"size":.14,"speed":[.3,1.2],"gravity":Vector3(0,-6,0)}))
	else:
		var shard := HdDev.cyl(0,size*.7,size*3,HdGothic.glow(color),Vector3.ZERO,6)
		shard.rotation.x = PI*.5
		node.add_child(shard)
		if theme == "void": node.add_child(HdDev.sphere(size*.7,HdGothic.iron()))
	node.add_child(HdFxParts.trail(color,size*.65,.35,8))
	return node


## Punkte innerhalb der Warnform (lokal, Blick nach -Z), an denen Einzeleffekte entstehen.
static func _spots(kind: int, radius: float, shape: Vector3, count: int) -> Array:
	var spots: Array = []
	for i in count:
		var fraction := (float(i)+.5)/count
		var angle := fraction*TAU
		var distance := lerpf(maxf(shape.x,.2),radius,.55+.4*sin(i*2.3)*sin(i*2.3))
		if kind in [HdTelegraph.CONE, HdTelegraph.ARC]:
			angle = lerpf(-deg_to_rad(shape.z)*.48,deg_to_rad(shape.z)*.48,fraction)
		var point := Vector3(sin(angle)*distance,0,-cos(angle)*distance)
		if kind == HdTelegraph.LINE: point = Vector3(sin(i*2.7)*shape.y*.4,0,-radius*fraction)
		if kind == HdTelegraph.CROSS:
			point = Vector3(lerpf(-radius,radius,fraction),0,sin(i*2.7)*shape.y*.4)
			if i % 2 == 0: point = Vector3(point.z,0,point.x)
		if kind == HdTelegraph.BOX: point = Vector3(sin(i*2.7)*shape.y*.4,0,lerpf(-radius*.5,radius*.5,fraction))
		spots.append([point,fraction,i])
	return spots


## Umriss der Form (bleibt kurz stehen, damit man sieht, was getroffen hat).
static func _outline(fx: HdFx, root: Node3D, theme: String, kind: int, radius: float, color: Color, shape: Vector3) -> void:
	if kind in [HdTelegraph.CROSS, HdTelegraph.BOX]:
		var impact := HdTelegraph.make(kind,color)
		impact.radius = radius
		impact.length = radius
		impact.width = shape.y
		root.add_child(impact)
		impact.trigger(.65)
	elif kind == HdTelegraph.LINE:
		var lane := HdFxParts.ground(HdFxParts.GUST,maxf(shape.y,.5),color,radius)
		root.add_child(lane)
		fx._tween(lane,"progress",0,1,.25)
	elif kind == HdTelegraph.CIRCLE:
		var mode: int = {"forge":HdFxParts.CRACK,"tide":HdFxParts.WAVE,"rot":HdFxParts.SCORCH,"time":HdFxParts.SIGIL,"void":HdFxParts.SWIRL}.get(theme,HdFxParts.WAVE)
		var ground := HdFxParts.ground(mode,radius,color)
		ground.position.y = .04
		root.add_child(ground)
		fx._tween(ground,"progress",0,1,.35)
	else:
		var half := deg_to_rad(shape.z)*.5 if kind in [HdTelegraph.CONE, HdTelegraph.ARC] else PI
		var ring := HdFxParts.arc(radius,.22,-half,half,HdFxParts.strip_material(color,{"flow":4.0,"taper":.2}))
		if kind in [HdTelegraph.CONE, HdTelegraph.ARC]: ring.rotation.y = PI
		root.add_child(ring)
		if kind in [HdTelegraph.RING, HdTelegraph.ARC] and shape.x > .1:
			var inside := HdFxParts.arc(shape.x,.16,-half,half,HdFxParts.strip_material(color))
			if kind == HdTelegraph.ARC: inside.rotation.y = PI
			root.add_child(inside)


static func _grow(node: Node3D, delay: float, time := .23) -> void:
	var full := node.scale
	node.scale = Vector3(full.x,.04,full.z)
	node.create_tween().tween_property(node,"scale",full,time).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func play(fx: HdFx, id: String, at: Vector3, direction: Vector3, size: float, color: Color, shape: Vector3) -> void:
	var parts := id.split(":")
	var theme := parts[1]
	var kind := int(parts[2])
	var root := Node3D.new()
	root.position = at + Vector3.UP*.08
	root.rotation.y = atan2(-direction.x,-direction.z)
	if not fx._add(root,2.4): return
	var low := Display.quality == Display.LOW
	var radius := maxf(size,.5)
	var hot := HdFxParts.hot(color,.55)
	var area := kind == HdTelegraph.CIRCLE
	var center := Vector3.ZERO
	var spread := radius
	if kind in [HdTelegraph.CONE, HdTelegraph.ARC]:
		center = Vector3(0,0,-radius*.58)
		spread = radius*.42
	elif kind == HdTelegraph.LINE:
		center = Vector3(0,0,-radius*.5)
		spread = maxf(shape.y,1.0)
	elif kind in [HdTelegraph.CROSS, HdTelegraph.BOX]:
		spread = radius*.5
	var span := Node3D.new()
	span.position = center
	root.add_child(span)
	if kind == HdTelegraph.LINE:
		span.scale = Vector3(1.0,1.0,radius*.5/spread)
	_outline(fx,root,theme,kind,radius,color,shape)
	var count := 7 if low else 14
	if kind in [HdTelegraph.RING, HdTelegraph.ARC] or radius > 6.0: count = 10 if low else 20
	var spots := _spots(kind,radius,shape,count)
	match theme:
		"forge": _forge(fx,root,span,spots,spread,color,hot,area,low)
		"tide": _tide(fx,root,span,spots,spread,color,hot,area,low)
		"rot": _rot(fx,root,span,spots,spread,color,hot,area,low)
		"time": _time(fx,root,span,spots,spread,color,hot,area,low)
		"void": _void(fx,root,span,spots,spread,color,hot,area,low)
		_: _forge(fx,root,span,spots,spread,color,hot,area,low)
	if kind == HdTelegraph.RING:
		# Die Mitte eines Rings ist der sichere Platz: dort keine Bodenflächen.
		for layer in span.get_children():
			if layer is MeshInstance3D and (layer as MeshInstance3D).mesh is PlaneMesh:
				layer.queue_free()
	fx._flash(at,hot,5.0,radius+7.0,.38)
	var tween := root.create_tween()
	tween.tween_interval(1.25)
	tween.tween_property(root,"scale:y",.01,.6)


static func _burst_at(root: Node3D, local: Vector3, c: Color, count: int, opt: Dictionary) -> CPUParticles3D:
	var p := HdFxParts.burst(c,count,opt)
	p.position = local
	root.add_child(p)
	return p


# ---------------------------------------------------------------- Kettenschmiede

static func _forge(fx: HdFx, root: Node3D, span: Node3D, spots: Array, radius: float, color: Color, hot: Color, area: bool, low: bool) -> void:
	var scorch := HdFxParts.ground(HdFxParts.SCORCH,minf(radius,9.0),Color("ff5a12"))
	scorch.position.y = .02
	span.add_child(scorch)
	fx._tween(scorch,"progress",0,1,.3)
	var molten := HdGothic.glow(Color("ffb14a"),3.0)
	for s in spots:
		var p: Vector3 = s[0]
		var f: float = s[1]
		var spot := Node3D.new()
		spot.position = p
		root.add_child(spot)
		# Erstarrende Schlackezacke mit glühender Eisenader, dazwischen aufsteigende Glutsäulen.
		HdRosterFx._shard(spot,Vector3.ZERO,.6+f*1.1,Color("2e2724"),sin(s[2])*.35)
		spot.add_child(HdDev.box(Vector3(.09,.9+f*.6,.09),molten,Vector3(0,.45+f*.3,0)))
		_grow(spot,f*.1)
		if int(s[2]) % 3 == 0:
			_burst_at(root,p+Vector3.UP*.2,Color("ffc766"),6 if low else 10,{"life":.7,"size":.13,"speed":[3.0,7.0],"spread":25.0,"gravity":Vector3(0,-14,0),"fade_to":Color("b3190a")})
	if area:
		var column := HdFxParts.tube(radius*.25,radius*.08,radius*1.2+2.0,2,Color("ff8a2a"),1.6)
		root.add_child(column)
		fx._tween(column,"fade",1.4,0,.7)
		_burst_at(root,Vector3.UP*.3,Color("ffd27a"),14 if low else 30,{"life":1.1,"size":.16,"speed":[4.0,10.0],"spread":40.0,"gravity":Vector3(0,-12,0),"fade_to":Color("8a1a08"),"radius":radius*.3})
	_burst_at(span,Vector3.UP*.6,Color(.16,.13,.12,.65),6 if low else 12,{"life":1.6,"size":1.4,"speed":[.6,2.0],"spread":30.0,"gravity":Vector3(0,1.4,0),"mix":true,"end_scale":2.2,"radius":minf(radius,6.0)*.5})


# ---------------------------------------------------------------- Sturmflut

static func _tide(fx: HdFx, root: Node3D, span: Node3D, spots: Array, radius: float, color: Color, hot: Color, area: bool, low: bool) -> void:
	var foam := HdFxParts.ground(HdFxParts.WAVE,minf(radius+1.0,10.0),Color("dff6ff"))
	foam.position.y = .03
	span.add_child(foam)
	fx._tween(foam,"progress",0,1,.5)
	var pool := HdFxParts.ground(HdFxParts.GLOW,minf(radius,9.0),color)
	pool.position.y = .02
	span.add_child(pool)
	fx._tween(pool,"fade",1,0,1.2,.3)
	for s in spots:
		var p: Vector3 = s[0]
		var f: float = s[1]
		if int(s[2]) % 2 == 1 and not area: continue
		# Wassersäule schießt hoch und fällt als Gischt zurück.
		var height := 1.6+f*1.8
		var spout := HdFxParts.tube(.35,.18,height,2,HdFxParts.hot(color,.25),2.4)
		spout.position = p
		root.add_child(spout)
		_grow(spout,f*.12,.18)
		fx._tween(spout,"fade",1.3,0,.55,.25)
		_burst_at(root,p+Vector3.UP*height*.8,HdFxParts.hot(color,.5),5 if low else 9,{"life":.8,"size":.16,"speed":[1.5,3.5],"spread":70.0,"gravity":Vector3(0,-11,0),"fade_to":color})
	if area:
		var geyser := HdFxParts.tube(radius*.2,radius*.12,radius+3.0,2,Color("cfefff"),3.0)
		root.add_child(geyser)
		_grow(geyser,0,.2)
		fx._tween(geyser,"fade",1.5,0,.6,.3)
	_burst_at(span,Vector3.UP*.4,Color(.75,.9,1.0,.5),6 if low else 12,{"life":1.4,"size":1.3,"speed":[.5,1.6],"spread":80.0,"gravity":Vector3(0,.4,0),"mix":true,"end_scale":2.0,"ring":minf(radius,7.0)*.8})


# ---------------------------------------------------------------- Dornenfäulnis

static func _rot(fx: HdFx, root: Node3D, span: Node3D, spots: Array, radius: float, color: Color, hot: Color, area: bool, low: bool) -> void:
	var puddle := HdFxParts.ground(HdFxParts.SCORCH,minf(radius,9.0),Color("5f8f1f"))
	puddle.position.y = .02
	span.add_child(puddle)
	fx._tween(puddle,"progress",0,1,.4)
	for s in spots:
		var p: Vector3 = s[0]
		var f: float = s[1]
		var spot := Node3D.new()
		spot.position = p
		root.add_child(spot)
		# Dornenbüschel bricht auf: eine große, zwei kleine Dornen, Sporenkapsel an der Spitze.
		var big := 1.0+f*1.3
		HdRosterFx._shard(spot,Vector3.ZERO,big,Color("3b4229"),cos(s[2])*.35)
		HdRosterFx._shard(spot,Vector3(.18,0,.1),big*.55,Color("4d5634"),.6)
		HdRosterFx._shard(spot,Vector3(-.16,0,-.08),big*.45,Color("4d5634"),-.55)
		spot.add_child(HdDev.sphere(.11,HdGothic.glow(color,2.2),Vector3(0,big*.92,0)))
		_grow(spot,f*.1,.26)
		if int(s[2]) % 2 == 0:
			_burst_at(root,p+Vector3.UP*.5,Color(color.r,color.g,color.b,.55),4 if low else 7,{"life":1.6,"size":.6,"speed":[.3,1.0],"spread":60.0,"gravity":Vector3(0,.6,0),"mix":true,"end_scale":2.0})
	_burst_at(span,Vector3.UP*.3,hot,14 if low else 26,{"life":1.8,"size":.13,"speed":[.4,1.4],"spread":50.0,"gravity":Vector3(0,.8,0),"radius":minf(radius,7.0)*.6,"swirl":3.0})


# ---------------------------------------------------------------- Gebrochene Zeit

static func _time(fx: HdFx, root: Node3D, span: Node3D, spots: Array, radius: float, color: Color, hot: Color, area: bool, low: bool) -> void:
	var dial := HdFxParts.ground(HdFxParts.SIGIL,minf(radius+.6,10.0),color)
	dial.position.y = .05
	span.add_child(dial)
	var m := dial.material_override as ShaderMaterial
	m.set_shader_parameter("sides",12.0)
	fx._tween(dial,"progress",0,1,.9)
	# Zwei Zeiger drehen über das Zifferblatt und bleiben beim Einschlag stehen.
	var hands := Node3D.new()
	hands.position.y = .08
	span.add_child(hands)
	for k in 2:
		var length := minf(radius,8.0)*(.85 if k == 0 else .55)
		var hand := HdDev.box(Vector3(.12 if k == 0 else .18,.05,length),HdGothic.glow(hot,2.4),Vector3(0,0,-length*.5))
		hand.rotation.y = k*2.1
		hands.add_child(hand)
	hands.create_tween().tween_property(hands,"rotation:y",-TAU*.75,.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for s in spots:
		var p: Vector3 = s[0]
		var f: float = s[1]
		var spot := Node3D.new()
		spot.position = p
		root.add_child(spot)
		spot.add_child(HdDev.box(Vector3(.1,.5,.1),HdGothic.brass(),Vector3(0,.25,0)))
		var rune := HdFxParts.halo(.45,color)
		rune.position.y = .7
		spot.add_child(rune)
		_grow(spot,f*.15)
		if int(s[2]) % 3 == 0:
			# Lichtsäule: ein Echo der Zeit schlägt an dieser Stelle ein.
			var pillar := HdFxParts.tube(.4,.3,4.5,2,hot,1.2)
			pillar.position = p
			root.add_child(pillar)
			fx._tween(pillar,"fade",1.4,0,.8,.1)
	_burst_at(span,Vector3.UP*.8,hot,10 if low else 22,{"life":1.5,"size":.22,"tex":"shard","speed":[.2,.8],"spread":180.0,"gravity":Vector3.ZERO,"radius":minf(radius,7.0)*.7,"swirl":6.0})
	var ripple := HdFxParts.ground(HdFxParts.WAVE,minf(radius+1.5,11.0),hot)
	ripple.position.y = .06
	span.add_child(ripple)
	fx._tween(ripple,"progress",0,1,.6,.25)


# ---------------------------------------------------------------- Kosmischer Schlund

static func _void(fx: HdFx, root: Node3D, span: Node3D, spots: Array, radius: float, color: Color, hot: Color, area: bool, low: bool) -> void:
	var swirl := HdFxParts.ground(HdFxParts.SWIRL,minf(radius,9.0),color)
	swirl.position.y = .04
	span.add_child(swirl)
	fx._tween(swirl,"fade",.75,0,1.2,.2)
	# Sog: Sternenstaub wird vom Rand zur Mitte gerissen, dann schlägt eine dunkle Welle nach außen.
	var pull := _burst_at(span,Vector3.UP*.4,HdFxParts.hot(color,.4),14 if low else 30,{"life":.6,"size":.14,"speed":[0.0,.2],"gravity":Vector3.ZERO,"ring":minf(radius,8.0),"ring_inner":.6})
	pull.radial_accel_min = -minf(radius,8.0)*7.0
	pull.radial_accel_max = -minf(radius,8.0)*9.0
	var shock := HdFxParts.ground(HdFxParts.WAVE,minf(radius+1.0,10.0),hot)
	shock.position.y = .05
	span.add_child(shock)
	fx._tween(shock,"progress",0,1,.45,.35)
	_burst_at(span,Vector3.UP*.6,Color(.05,.02,.1,.75),6 if low else 12,{"life":1.5,"size":1.6,"speed":[.4,1.6],"spread":60.0,"gravity":Vector3(0,.5,0),"mix":true,"end_scale":2.0,"radius":minf(radius,6.0)*.5})
	var tendril := HdFxParts.strip_material(color,{"flow":-3.0,"taper":.6,"grain":.4})
	for s in spots:
		var p: Vector3 = s[0]
		var f: float = s[1]
		var spot := Node3D.new()
		spot.position = p
		root.add_child(spot)
		HdRosterFx._shard(spot,Vector3.ZERO,.6+f,Color("2a1d3a"),sin(s[2])*.55)
		var i := float(s[2])
		var height := 1.4+f*1.6
		spot.add_child(HdFxParts.ribbon(PackedVector3Array([Vector3.ZERO,Vector3(sin(i)*.45,height*.45,.2),Vector3(cos(i)*.55,height*.8,-.1),Vector3(sin(i*1.7)*.2,height,0)]),.26,tendril))
		_grow(spot,f*.12,.3)
	_burst_at(span,Vector3.UP*1.2,Color("e8dcff"),8 if low else 16,{"life":1.2,"size":.12,"speed":[.5,2.0],"spread":180.0,"gravity":Vector3.ZERO,"radius":minf(radius,7.0)*.6})
