class_name HdWobbel
extends RefCounted
## Weiches wabert (Lukas 2026-11-19: "alles nicht Feste soll wabbeln", "eher wabern als wabbeln"): Stofffetzen, Umhänge, Roben-Säume,
## Schleier, Tentakel, Flammen, Moos, Irrlichter. tools/modelle/bollwerk_figuren.py legt je Punkt ein Gewicht
## in die zweite UV-Karte (0 = fest, 1 = frei). Flächen mit Gewicht bekommen hier einen Shader, der das Aussehen
## des StandardMaterial3D (Farbe, Stoff-Textur triplanar, Normal-Map, Rauheit, Metall, Leuchten, Alpha)
## nachbaut und die Punkte im Vertex-Shader schwingen lässt. Ohne Gewicht bleibt alles wie es ist.

const AMP := 0.045  ## Ausschlag als Anteil der Modellhöhe
static var _shader: Shader
static var _shader_alpha: Shader
static var _cache: Dictionary = {}  # Material-ID -> ShaderMaterial
static var _hat: Dictionary = {}    # Mesh-ID -> Array[bool] je Fläche

const CODE := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, %s diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool hat_albedo = false;
uniform sampler2D tex_normal : hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool hat_normal = false;
uniform float normal_scale = 1.0;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform vec3 uv_scale = vec3(1.0);
uniform float amp = 0.03;
uniform float tempo = 1.1;
varying vec3 tri_pos;
varying vec3 tri_w;

vec4 tri(sampler2D t) {
	return texture(t, tri_pos.zy) * tri_w.x + texture(t, tri_pos.xz) * tri_w.y + texture(t, tri_pos.xy) * tri_w.z;
}

void vertex() {
	// Wabern (Lukas: "eher wabern als wabbeln"): langsame, weiche Wellen, die vom festen zum freien Ende
	// durchlaufen (Phase hängt am Gewicht), zwei überlagerte Wellen gegen Gleichtakt.
	float w = UV2.x;
	if (w > 0.001) {
		float ph = NODE_POSITION_WORLD.x * 0.7 + NODE_POSITION_WORLD.z * 0.9 + dot(VERTEX.xz, vec2(1.3, 0.9));
		float t = TIME * tempo;
		float lauf = w * 3.2;
		vec3 off = vec3(sin(t - lauf + ph), 0.5 * sin(t * 0.71 - lauf * 0.8 + ph * 1.3), cos(t * 0.83 - lauf + ph * 0.7))
			+ 0.35 * vec3(sin(t * 1.9 - lauf * 1.7 + ph * 2.1), 0.0, sin(t * 1.6 - lauf * 1.5 + ph * 1.7));
		VERTEX += off * amp * w * w;
	}
	tri_w = pow(abs(NORMAL), vec3(4.0));
	tri_w /= max(dot(tri_w, vec3(1.0)), 0.0001);
	tri_pos = VERTEX * uv_scale;
}

void fragment() {
	vec4 c = albedo;
	if (hat_albedo) {
		c *= tri(tex_albedo);
	}
	ALBEDO = c.rgb;
	%s
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = emission * emission_energy;
	if (hat_normal) {
		NORMAL_MAP = tri(tex_normal).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
"""


static func _shader_fuer(alpha: bool) -> Shader:
	if alpha:
		if _shader_alpha == null:
			_shader_alpha = Shader.new()
			_shader_alpha.code = CODE % ["cull_disabled,", "ALPHA = c.a;"]
		return _shader_alpha
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE % ["", ""]
	return _shader


## Nach HdStoffe.modell() aufrufen: Flächen mit Wabbel-Gewicht bekommen den Wabbel-Shader.
static func modell(root: Node, hoehe := 1.0) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if not mesh is ArrayMesh:
			continue
		var flaechen := _flaechen(mesh)
		for i in flaechen.size():
			if not flaechen[i]:
				continue
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				mi.set_surface_override_material(i, material(m, hoehe))


## Welche Flächen eines Meshes ein Gewicht > 0 tragen (je Mesh nur einmal gerechnet).
static func _flaechen(mesh: ArrayMesh) -> Array:
	var id := mesh.get_instance_id()
	if _hat.has(id):
		return _hat[id]
	var out := []
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		var uv2 = a[Mesh.ARRAY_TEX_UV2]
		var ja := false
		if uv2 is PackedVector2Array:
			for v in uv2:
				if v.x > 0.001:
					ja = true
					break
		out.append(ja)
	_hat[id] = out
	return out


static func material(m: StandardMaterial3D, hoehe := 1.0) -> ShaderMaterial:
	var key := "%d_%.2f" % [m.get_instance_id(), hoehe]
	if _cache.has(key):
		return _cache[key]
	var alpha := m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var s := ShaderMaterial.new()
	s.resource_name = m.resource_name
	s.shader = _shader_fuer(alpha)
	s.set_shader_parameter("albedo", m.albedo_color)
	s.set_shader_parameter("hat_albedo", m.albedo_texture != null)
	if m.albedo_texture:
		s.set_shader_parameter("tex_albedo", m.albedo_texture)
	s.set_shader_parameter("hat_normal", m.normal_enabled and m.normal_texture != null)
	if m.normal_texture:
		s.set_shader_parameter("tex_normal", m.normal_texture)
	s.set_shader_parameter("normal_scale", m.normal_scale)
	s.set_shader_parameter("roughness", m.roughness)
	s.set_shader_parameter("metallic", m.metallic)
	s.set_shader_parameter("specular", m.metallic_specular)
	if m.emission_enabled:
		s.set_shader_parameter("emission", m.emission)
		s.set_shader_parameter("emission_energy", m.emission_energy_multiplier)
	s.set_shader_parameter("uv_scale", m.uv1_scale)
	s.set_shader_parameter("amp", AMP * hoehe)
	_cache[key] = s
	return s
