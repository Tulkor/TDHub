class_name HdFxParts
extends RefCounted
## Bausteine der Bollwerk-Effekte: Bodenebenen, Leuchtbänder, Hüllen, Funken und Geschoss-Formen.
## HdFx setzt daraus die Effekte der Heldenfähigkeiten zusammen. Alles ohne Bildtexturen aus Dateien.

const GROUND := preload("res://assets/shaders/hd_fx_ground.gdshader")
const STRIP := preload("res://assets/shaders/hd_fx_strip.gdshader")
const SHELL := preload("res://assets/shaders/hd_fx_shell.gdshader")

## Formen der Bodenebene (uniform mode in hd_fx_ground.gdshader).
const WAVE := 0
const FLAME := 1
const SIGIL := 2
const SWIRL := 3
const CRACK := 4
const GLOW := 5
const GUST := 6
const SCORCH := 7
const HEAL_AREA := 8

static var _textures := {}
static var _spark_mats := {}
static var _beam_mats := {}


## Hellere Kernfarbe zu c.
static func hot(c: Color, k := 0.65) -> Color:
	return Color(lerpf(c.r, 1.0, k), lerpf(c.g, 1.0, k), lerpf(c.b, 1.0, k), 1.0)


## Weniger Teilchen auf der niedrigen Grafikstufe.
static func amount(n: int) -> int:
	return maxi(1, ceili(n * 0.5)) if Display.quality == Display.LOW else n


static func texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var tex: Texture2D
	if kind == "dot":
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		tex = gt
	else:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		if kind == "plus":
			img.fill_rect(Rect2i(6, 2, 4, 12), Color.WHITE)
			img.fill_rect(Rect2i(2, 6, 12, 4), Color.WHITE)
		else:
			for y in 16:
				for x in 16:
					if absf(x - 7.5) / 3.2 + absf(y - 7.5) / 7.5 < 1.0:
						img.set_pixel(x, y, Color.WHITE)
		tex = ImageTexture.create_from_image(img)
	_textures[kind] = tex
	return tex


## Ebene am Boden mit dem Bodeneffekt-Shader; Radius r (bei GUST: Breite r, Länge length nach −Z).
static func ground(mode: int, r: float, c: Color, length := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	if mode == GUST:
		pm.size = Vector2(r, length)
		pm.center_offset = Vector3(0, 0, -length * 0.5)
	else:
		pm.size = Vector2.ONE * r * 2.0
	mi.mesh = pm
	mi.set_meta("terrain_ground",true)
	pm.subdivide_width=clampi(ceili(pm.size.x/1.5)-1,0,32)
	pm.subdivide_depth=clampi(ceili(pm.size.y/1.5)-1,0,32)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = GROUND
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core", hot(c))
	m.set_shader_parameter("seed", randf() * 20.0)
	mi.material_override = m
	mi.ready.connect(func():
		var owner_node := mi.get_parent()
		while owner_node != null:
			if owner_node.has_method("conform_ground_effect"):
				owner_node.conform_ground_effect(mi)
				break
			owner_node = owner_node.get_parent(), CONNECT_ONE_SHOT)
	return mi


static func heal_area(radius: float) -> MeshInstance3D:
	var area := ground(HEAL_AREA, radius, Color("57ff23"))
	area.material_override.set_shader_parameter("core", Color("8bff45"))
	return area


static func strip_material(c: Color, opt := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = STRIP
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core", opt.get("core", hot(c, 0.8)))
	for key in ["fade", "head", "tail", "flow", "grain", "taper"]:
		if opt.has(key):
			m.set_shader_parameter(key, float(opt[key]))
	return m


## Gemeinsames Material für Strahlen, die jeden Frame neu gezeichnet werden.
static func beam_material(c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if not _beam_mats.has(key):
		_beam_mats[key] = strip_material(c, {"flow": 5.0, "grain": 0.55})
	return _beam_mats[key]


static func _quad(st: SurfaceTool, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, ua: float, ub: float) -> void:
	for corner in [[a0, ua, 0.0], [a1, ua, 1.0], [b0, ub, 0.0], [a1, ua, 1.0], [b1, ub, 1.0], [b0, ub, 0.0]]:
		st.set_uv(Vector2(corner[1], corner[2]))
		st.add_vertex(corner[0])


## Band entlang einer Punktfolge aus zwei gekreuzten Streifen (von jeder Seite sichtbar).
static func ribbon_mesh(points: PackedVector3Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := points.size()
	if count < 2:
		return st.commit()
	var lens := PackedFloat32Array([0.0])
	for i in range(1, count):
		lens.append(lens[i - 1] + points[i].distance_to(points[i - 1]))
	var total := maxf(lens[count - 1], 0.001)
	var sides: Array = []
	for i in count:
		var along: Vector3 = (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		if along.is_zero_approx():
			along = Vector3.FORWARD
		var ref := Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT
		var s1 := along.cross(ref).normalized() * width * 0.5
		sides.append([s1, along.cross(s1).normalized() * width * 0.5])
	for plane in 2:
		for i in count - 1:
			var sa: Vector3 = sides[i][plane]
			var sb: Vector3 = sides[i + 1][plane]
			_quad(st, points[i] - sa, points[i] + sa, points[i + 1] - sb, points[i + 1] + sb, lens[i] / total, lens[i + 1] / total)
	return st.commit()


static func ribbon(points: PackedVector3Array, width: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ribbon_mesh(points, width)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Flacher Bogen in der XZ-Ebene um den Ursprung (Winkel wie atan2(x, z)); UV.x läuft von a0 nach a1.
static func arc(radius: float, width: float, a0: float, a1: float, m: Material, segments := 20) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var ua := float(i) / segments
		var ub := float(i + 1) / segments
		var aa := lerpf(a0, a1, ua)
		var ab := lerpf(a0, a1, ub)
		var da := Vector3(sin(aa), 0, cos(aa))
		var db := Vector3(sin(ab), 0, cos(ab))
		_quad(st, da * (radius - width), da * radius, db * (radius - width), db * radius, ua, ub)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func shell_material(pattern: int, c: Color, speed := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHELL
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core", hot(c))
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("seed", randf() * 20.0)
	return m


## Offene Röhre (unten r0, oben r1), UV.y 0 unten bis 1 oben: Wirbelsäule (pattern 1) oder Lichtsäule (2).
static func tube(r0: float, r1: float, height: float, pattern: int, c: Color, speed := 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 20
	for i in segments:
		var ua := float(i) / segments
		var ub := float(i + 1) / segments
		var da := Vector3(cos(ua * TAU), 0, sin(ua * TAU))
		var db := Vector3(cos(ub * TAU), 0, sin(ub * TAU))
		for corner in [[da * r0, ua, 0.0], [da * r1 + Vector3.UP * height, ua, 1.0], [db * r0, ub, 0.0],
				[da * r1 + Vector3.UP * height, ua, 1.0], [db * r1 + Vector3.UP * height, ub, 1.0], [db * r0, ub, 0.0]]:
			st.set_uv(Vector2(corner[1], corner[2]))
			st.set_normal((da if corner[1] == ua else db))
			st.add_vertex(corner[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = shell_material(pattern, c, speed)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Schildkuppel: Kugelhülle mit leuchtendem Rand und wandernden Waben.
static func dome(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	mi.mesh = s
	mi.material_override = shell_material(0, c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func spark_material(kind: String, mix := false) -> StandardMaterial3D:
	var key := "%s|%s" % [kind, mix]
	if _spark_mats.has(key):
		return _spark_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if mix else BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture(kind)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_spark_mats[key] = m
	return m


## Teilchenwolke. opt: life, size, speed [min, max], dir, spread, flat, gravity, radius (Kugel) oder
## ring (Ringradius), swirl, damping, tex (dot/plus/shard), mix (Rauch statt Leuchten), box (Material:
## feste Trümmer statt Leuchtpunkten), loop (läuft weiter statt einmal), fade_to (Endfarbe).
static func burst(c: Color, count: int, opt := {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	if DisplayServer.get_name() == "headless":
		# Ohne Grafik (Tests, Simulation) meldet der Platzhalter-Renderer Fehler für Teilchen-Meshes.
		p.emitting = false
		return p
	var looping: bool = opt.get("loop", false)
	p.amount = amount(count)
	p.lifetime = float(opt.get("life", 0.4))
	p.one_shot = not looping
	p.explosiveness = 0.0 if looping else float(opt.get("explosive", 0.92))
	p.randomness = 0.6
	p.local_coords = false
	var size := float(opt.get("size", 0.22))
	if opt.has("box"):
		var bm := BoxMesh.new()
		bm.size = Vector3(size, size * 0.6, size * 0.8)
		p.mesh = bm
		p.material_override = opt.box
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		p.particle_flag_rotate_y = true
	else:
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * size
		p.mesh = qm
		p.material_override = spark_material(str(opt.get("tex", "dot")), bool(opt.get("mix", false)))
	if opt.has("ring"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = float(opt.ring)
		p.emission_ring_inner_radius = float(opt.ring) * float(opt.get("ring_inner", 0.85))
		p.emission_ring_height = 0.1
	elif opt.has("radius"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = float(opt.radius)
	p.direction = opt.get("dir", Vector3.UP)
	p.spread = float(opt.get("spread", 180.0))
	p.flatness = float(opt.get("flat", 0.0))
	var speed: Array = opt.get("speed", [1.5, 4.0])
	p.initial_velocity_min = float(speed[0])
	p.initial_velocity_max = float(speed[1])
	p.gravity = opt.get("gravity", Vector3(0, -6.0, 0))
	p.damping_min = float(opt.get("damping", 1.5))
	p.damping_max = p.damping_min * 1.6
	if opt.has("swirl"):
		p.tangential_accel_min = float(opt.swirl) * 0.6
		p.tangential_accel_max = float(opt.swirl)
	p.scale_amount_min = 0.55
	p.scale_amount_max = 1.25
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, float(opt.get("end_scale", 0.15))))
	p.scale_amount_curve = shrink
	if not opt.has("box"):
		var ramp := Gradient.new()
		ramp.set_color(0, c)
		var end: Color = opt.get("fade_to", c)
		ramp.set_color(1, Color(end.r, end.g, end.b, 0.0))
		p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = true
	return p


## Leuchtpunkt, der immer zur Kamera zeigt.
static func halo(size: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * size
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = texture("dot")
	m.albedo_color = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Nachziehende Leuchtspur für bewegte Knoten (Geschosse).
static func trail(c: Color, size: float, life := 0.28, count := 12) -> CPUParticles3D:
	return burst(c, count, {"loop": true, "life": life, "size": size, "speed": [0.0, 0.3], "gravity": Vector3.ZERO, "radius": size * 0.2})


## Sichtbare Form eines Heldengeschosses; +Z ist die Flugrichtung.
## look: orb (Leuchtkugel), dart (Spritzenpfeil), rock (Felsbrocken), wind (Windklinge), scrap (Schrottbombe).
static func shot(look: String, c: Color, size: float) -> Node3D:
	if look.begins_with("boss_"):
		return HdBossFx.projectile(look.trim_prefix("boss_"),c,size)
	if look.begins_with("roster_"):
		return HdRosterFx.projectile(look.trim_prefix("roster_"),c,size)
	var n := Node3D.new()
	match look:
		"enemy_bolt":
			n.add_child(HdDev.box(Vector3(.12,.12,1.4),HdDev.flat(c)))
			n.add_child(trail(c,.08,.16,5))
		"dart":
			size *= 1.7
			var glass := HdDev.cyl(size * 0.32, size * 0.32, size * 2.6, HdDev.flat(c, 0.85), Vector3.ZERO, 8)
			glass.rotation.x = PI * 0.5
			n.add_child(glass)
			var needle := HdDev.cyl(0.0, size * 0.1, size * 1.6, HdDev.flat(Color("e8eef2")), Vector3(0, 0, size * 2.0), 6)
			needle.rotation.x = PI * 0.5
			n.add_child(needle)
			var plunger := HdDev.cyl(size * 0.5, size * 0.5, size * 0.2, HdDev.flat(Color("b9c4cc")), Vector3(0, 0, -size * 1.4), 8)
			plunger.rotation.x = PI * 0.5
			n.add_child(plunger)
			n.add_child(halo(size * 4.0, Color(c.r, c.g, c.b, 0.7)))
			n.add_child(trail(c, size * 0.9, 0.3, 14))
		"rock":
			var rock := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = size
			sm.height = size * 1.7
			sm.radial_segments = 6
			sm.rings = 3
			rock.mesh = sm
			rock.material_override = HdDev.mat(c, 0.5)
			rock.rotation = Vector3(0.4, 0.7, 0.2)
			n.add_child(rock)
			for chip in 3:
				n.add_child(HdDev.box(Vector3.ONE * size * 0.45, HdDev.mat(c.darkened(0.25), 0.5), Vector3(cos(chip * 2.1), sin(chip * 2.1), -0.6 - chip * 0.35) * size))
			n.add_child(burst(Color(0.72, 0.62, 0.48, 0.55), 14, {"loop": true, "life": 0.45, "size": size * 1.6, "speed": [0.2, 0.8], "gravity": Vector3(0, 0.6, 0), "mix": true, "end_scale": 1.6}))
		"wind":
			var blade := arc(size * 3.2, size * 1.3, -0.9, 0.9, strip_material(c, {"taper": 1.0, "grain": 0.5, "flow": 6.0}), 12)
			blade.position.z = -size * 2.2
			n.add_child(blade)
			var upright := arc(size * 3.2, size * 1.3, -0.9, 0.9, strip_material(c, {"taper": 1.0, "grain": 0.5, "flow": 6.0}), 12)
			upright.position.z = -size * 2.2
			upright.rotation.z = PI * 0.5
			n.add_child(upright)
			n.add_child(trail(Color(c.r, c.g, c.b, 0.7), size * 1.2, 0.25, 12))
		"scrap":
			var iron := HdDev.metall(Color("7d7f86"))
			n.add_child(HdDev.sphere(size, HdDev.metall(Color("4a4c52"))))
			for k in 5:
				var a := k * TAU / 5.0
				n.add_child(HdDev.box(Vector3(size * 0.7, size * 0.35, size * 0.5), iron, Vector3(cos(a), sin(a * 2.0) * 0.5, sin(a)) * size * 0.8))
			n.add_child(HdDev.cyl(size * 0.08, size * 0.08, size * 0.7, HdDev.flat(Color("3a2a1a")), Vector3(0, size * 1.1, 0), 5))
			var fuse := halo(size * 1.6, Color(1.0, 0.7, 0.25, 0.9))
			fuse.position.y = size * 1.5
			n.add_child(fuse)
			n.add_child(trail(Color(1.0, 0.6, 0.2), size * 0.5, 0.3, 10))
		_:
			n.add_child(HdDev.sphere(size * 0.7, HdDev.flat(hot(c, 0.75))))
			n.add_child(halo(size * 4.0, Color(c.r, c.g, c.b, 0.7)))
			n.add_child(trail(c, size * 1.1, 0.25, 12))
	return n
