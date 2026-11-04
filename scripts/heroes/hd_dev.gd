class_name HdDev
extends RefCounted
## Dev-Texturen für Bollwerk (Etappe 1, wie bei Tower Survivors): Raster im Code erzeugt, triplanar in
## Weltkoordinaten, ein Kästchen = 1 Einheit. Später durch echte Modelle und Texturen ersetzen.

static var _tex: Texture2D
static var _mats: Dictionary = {}


static func grid_texture() -> Texture2D:
	if _tex:
		return _tex
	var px := 128
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var cell := px / 4
	for y in px:
		for x in px:
			var v := 1.0
			if x % cell == 0 or y % cell == 0:
				v = 0.8
			if x < 2 or y < 2:
				v = 0.62
			if ((x / cell) + (y / cell)) % 2 == 1:
				v *= 0.93
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


## Rastermaterial in Farbe c; scale = Kästchen je Einheit / 4.
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
	m.roughness = 0.8
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


## Einfarbig ohne Licht (Geschosse, Blitze).
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


static func box(size: Vector3, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	return mi


static func cyl(r_top: float, r_bottom: float, h: float, m: Material, pos := Vector3.ZERO, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = seg
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	return mi


static func sphere(r: float, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	return mi
