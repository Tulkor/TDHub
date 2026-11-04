class_name SvDev
extends RefCounted
## Dev-Texturen für Tower Survivors (Lukas 2026-11-04: „derweil mit Dev-Texturen“): Raster wie bei
## Prototyp-Texturen, im Code erzeugt, triplanar in Weltkoordinaten, damit ein Kästchen überall gleich
## groß ist. Jede Farbe bekommt ein eigenes Material (zwischengespeichert). Später durch echte Modelle
## und Texturen ersetzen, die Bausteine der Waffen (survivors.json → model) bleiben die Vorlage.

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}


## Rastertextur: helle Fläche, dünne Linien, jede vierte Linie kräftiger, ein Quadrat = 1 Einheit.
static func grid_texture(px := 128) -> Texture2D:
	if _tex.has(px):
		return _tex[px]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1))
	var cell := px / 4
	for y in px:
		for x in px:
			var v := 1.0
			if x % cell == 0 or y % cell == 0:
				v = 0.78
			if x == 0 or y == 0 or x == 1 or y == 1:
				v = 0.6
			# Schachbrett leicht abgesetzt, damit man Bewegung und Größe sieht
			if ((x / cell) + (y / cell)) % 2 == 1:
				v *= 0.93
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[px] = t
	return t


## Material mit Raster in der Farbe c. scale: Kästchen pro Einheit (das Bild hat 4×4 Kästchen).
static func mat(c: Color, scale := 0.25, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(), scale, glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = grid_texture()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.75
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


## Warnstreifen Gelb/Schwarz diagonal, triplanar in Weltkoordinaten (ein Streifenpaar ≈ 0,25 Einheiten).
static func hazard() -> StandardMaterial3D:
	if _mats.has("hazard"):
		return _mats.hazard
	var px := 64
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			img.set_pixel(x, y, Color("f2d21b") if ((x + y) / (px / 2)) % 2 == 0 else Color("141414"))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 4.0
	m.roughness = 0.6
	_mats.hazard = m
	return m


## Einfarbig leuchtend ohne Licht (Geschosse, Strahlen, Ringe).
static func flat(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var key := "flat|%s|%s" % [c.to_html(), alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Ein Baustein aus survivors.json → model: {s, size, p, r, c}. colors: {type, dark, light, glow}.
static func part(spec: Dictionary, colors: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var size: Array = spec.get("size", [0.3])
	match str(spec.get("s", "box")):
		"box":
			var b := BoxMesh.new()
			b.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
			mi.mesh = b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = float(size[0])
			c.bottom_radius = float(size[0])
			c.height = float(size[1])
			c.radial_segments = 12
			mi.mesh = c
		"cone":
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = float(size[0])
			k.height = float(size[1])
			k.radial_segments = 12
			mi.mesh = k
		"sphere":
			var s := SphereMesh.new()
			s.radius = float(size[0])
			s.height = float(size[0]) * 2.0
			s.radial_segments = 12
			s.rings = 6
			mi.mesh = s
	var p: Array = spec.get("p", [0, 0, 0])
	mi.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var r: Array = spec.get("r", [0, 0, 0])
	mi.rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))
	var key := str(spec.get("c", "type"))
	var col: Color = colors.get(key, colors.get("type", Color.WHITE))
	mi.material_override = mat(col, 1.0, 1.6 if key == "glow" else 0.0)
	return mi
