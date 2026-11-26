class_name HdDev
extends RefCounted
## Grundmaterialien und Formen für Bollwerk: Oberflächen (Mauer, Bruchstein, Putz, Holz) triplanar in
## Weltkoordinaten, Metall, Leuchtendes. grid_texture() bleibt als Dev-Raster für Proben und Tests.

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


## Metall (Gadgets, Rüstungsteile): glatt, metallisch, mit gemeinsamem Metall-Look (Rauheitsflecken).
static func metall(c: Color, scale := 0.25) -> StandardMaterial3D:
	var key := "metall|%s|%s" % [c.to_html(), scale]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.metallic = 0.8
	m.roughness = 0.4
	Metall.veredeln(m)
	_mats[key] = m
	return m


## Oberflächen aus dem CC0-Paket Medieval Village MegaKit (Quaternius), gebaut mit
## tools/heroes/bollwerk_oberflaechen.gd. Die Detailkarte ist grau (Mittel 0.82), die Farbe kommt aus dem Code.
const SURFACES := ["mauer", "bruchstein", "putz", "holz"]
const _DETAIL_MEAN := 0.82
static var _surface_tex: Dictionary = {}


static func _surface_texture(kind: String, part: String) -> Texture2D:
	var key := kind + "_" + part
	if not _surface_tex.has(key):
		_surface_tex[key] = load("res://assets/textures/bollwerk/%s.jpg" % key)
	return _surface_tex[key]


## Oberflächenmaterial in Farbe c: kind aus SURFACES; scale = Kacheln je Einheit (0.5 = eine Kachel auf 2 m).
static func surface(kind: String, c: Color, scale := 0.25, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [kind, c.to_html(), scale, glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var k := 1.0 / _DETAIL_MEAN
	m.albedo_color = Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), c.a)
	m.albedo_texture = _surface_texture(kind, "detail")
	m.normal_enabled = true
	m.normal_texture = _surface_texture(kind, "normal")
	m.normal_scale = 0.8
	m.metallic_specular = 0.3  # matter Stein/Holz, keine Glitzerpunkte auf Kanten
	if kind == "putz":
		m.roughness = 0.88
	else:
		m.roughness_texture = _surface_texture(kind, "rough")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


## Passende Oberfläche zur Farbe, für Stellen ohne ausdrückliche Wahl: Braun = Holz,
## Dunkles und Grau = Stein (dunkel Bruchstein, hell Mauer), sonst Putz.
static func surface_for(c: Color) -> String:
	if c.s > 0.3 and c.h > 0.03 and c.h < 0.14 and c.v < 0.85:
		return "holz"
	if c.v < 0.35 and c.s < 0.5:
		return "bruchstein"
	if c.s < 0.25:
		return "bruchstein" if c.v < 0.45 else "mauer"
	return "putz"


## Standardmaterial in Farbe c (früher Dev-Raster). Leuchtendes bleibt glatt, alles andere bekommt
## eine echte Oberfläche nach surface_for(); scale wie bei surface().
static func mat(c: Color, scale := 0.25, glow := 0.0) -> StandardMaterial3D:
	if glow <= 0.0:
		return surface(surface_for(c), c, scale)
	var key := "%s|%s|%s" % [c.to_html(), scale, glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
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
