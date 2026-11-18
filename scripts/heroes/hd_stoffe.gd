class_name HdStoffe
extends RefCounted
## Stoff-Texturen für Helden- und Gegnermodelle: Leder, Stoff, Fell, Knochen, Chitin (tools/heroes/bollwerk_stoffe.gd)
## sowie Holz und Bruchstein aus HdDev.surface(). Gegner (tools/modelle/bollwerk_figuren.py) tragen sprechende
## Materialnamen, Helden (helden_bau.py, kader_bau.py) nur m_<farbe>_<n>; dort entscheidet die Farbe.
## Die Textur liegt triplanar im Modellraum, die Farbe des Materials bleibt erhalten (Detailkarte grau, Mittel 0.82).

const MEAN := 0.82
## Materialname (ohne Endung .001 usw.) -> Art
const NAMEN := {
	"leder": "leder", "tuch_braun": "stoff", "grabtuch": "stoff", "grabtuch_hell": "stoff", "aschtuch": "stoff",
	"robe": "stoff", "robe_dunkel": "stoff", "umhang": "stoff", "wache": "stoff", "arena_rot": "stoff",
	"fell": "fell", "bart": "fell", "stroh": "fell",
	"knochen": "knochen", "bein_alt": "knochen", "bein_dunkel": "knochen", "zahn": "knochen",
	"chitin": "chitin", "schlacke": "chitin", "schlacke_hell": "chitin",
	"holz": "holz", "rinde": "holz", "wurzel": "holz",
	"stein": "bruchstein", "grabstein": "bruchstein",
	"eisen": "metall", "stahl": "metall", "stahl_dunkel": "metall", "gold": "metall", "altgold": "metall",
	"krone": "metall", "kupfer": "metall", "rost": "metall", "gruft": "metall",
}
## Metall nach Name: [metallic, roughness]; Helden-Metall behält seine Rauheit, Metallgrad mindestens 0.8.
const METALL := {
	"eisen": [0.85, 0.38], "stahl": [0.9, 0.32], "stahl_dunkel": [0.9, 0.36], "gold": [0.95, 0.3],
	"altgold": [0.85, 0.48], "krone": [0.95, 0.28], "kupfer": [0.9, 0.4], "rost": [0.45, 0.78], "gruft": [0.75, 0.5],
}
## Kacheln je Modelleinheit
const SKALA := {"leder": 2.5, "stoff": 3.0, "fell": 2.0, "knochen": 1.5, "chitin": 3.0, "holz": 1.2, "bruchstein": 1.0, "metall": 2.0}
const NORMAL := {"leder": 0.7, "stoff": 0.35, "fell": 0.6, "knochen": 0.5, "chitin": 0.8, "holz": 0.6, "bruchstein": 0.7, "metall": 0.45}
static var _tex: Dictionary = {}
static var _done: Dictionary = {}


## Alle Materialien eines geladenen Modells veredeln (geteilte Materialien nur einmal).
static func modell(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mesh.surface_get_material(i)
			if m is StandardMaterial3D and not _done.has(m.get_instance_id()):
				_done[m.get_instance_id()] = true
				var art := art_fuer(m)
				if art != "":
					anwenden(m, art)


## Art für ein Material: zuerst nach Name, bei Helden-Materialien (m_<farbe>) nach Farbe. "" = unverändert.
static func art_fuer(m: StandardMaterial3D) -> String:
	if m.emission_enabled or m.albedo_texture != null:
		return ""
	var name := _name(m)
	if NAMEN.has(name):
		return NAMEN[name]
	if m.metallic >= 0.3:
		return "metall"
	# Helden: glatte, nicht leuchtende Teile (Rüstplatten, Helme) sind im Modell oft ohne Metallgrad gebaut
	if name.begins_with("m_") and m.roughness >= 0.25 and m.roughness <= 0.45:
		return "metall"
	if name.begins_with("m_"):
		return art_nach_farbe(m.albedo_color)
	return ""


static func _name(m: Material) -> String:
	var name := m.resource_name.to_lower()
	var cut := name.find(".")
	if cut > 0:
		name = name.substr(0, cut)
	return name


## Helden: Braun = Leder, Hautton = glatt, sehr dunkel/Grau = Stoff, alles Farbige = Stoff.
static func art_nach_farbe(c: Color) -> String:
	if c.h > 0.02 and c.h < 0.13:
		if c.s > 0.2 and c.s < 0.55 and c.v > 0.65:
			return ""  # Haut
		if c.s >= 0.35 and c.v < 0.55:
			return "leder"
	return "stoff"


static func anwenden(m: StandardMaterial3D, art: String) -> void:
	var c := m.albedo_color
	var k := 1.0 / MEAN
	m.albedo_color = Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), c.a)
	m.albedo_texture = _textur(art, "detail")
	m.normal_enabled = true
	m.normal_texture = _textur(art, "normal")
	m.normal_scale = float(NORMAL[art])
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * float(SKALA[art])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if art == "metall":
		var mr: Array = METALL.get(_name(m), [maxf(m.metallic, 0.8), clampf(m.roughness, 0.28, 0.45)])
		m.metallic = float(mr[0])
		m.roughness = float(mr[1])
		m.metallic_specular = 0.6
		Metall.veredeln(m)
	elif art == "leder":
		m.roughness = minf(m.roughness, 0.62)
	elif art == "chitin":
		m.roughness = minf(m.roughness, 0.45)
	m.set_meta("hd_stoff", art)


static func _textur(art: String, teil: String) -> Texture2D:
	var key := art + "_" + teil
	if not _tex.has(key):
		_tex[key] = load("res://assets/textures/bollwerk/%s.jpg" % key)
	return _tex[key]
