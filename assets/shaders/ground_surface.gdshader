// Deckende Weltkoordinaten-PBR-Fläche für Geländeplatten; Specular ist eine lineare Datenmap.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://assets/shaders/terrain_variation.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D specular_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float texture_scale = 0.6;
uniform float normal_strength = 1.0;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = world_pos * texture_scale;
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	ALBEDO = (tv_sample(albedo_tex, p.zy, 0.0) * weights.x
		+ tv_sample(albedo_tex, p.xz, 0.0) * weights.y
		+ tv_sample(albedo_tex, p.xy, 0.0) * weights.z) * tint.rgb;
	vec3 nx = tv_normal(normal_tex, p.zy, 0.0) * 2.0 - 1.0;
	vec3 ny = tv_normal(normal_tex, p.xz, 0.0) * 2.0 - 1.0;
	vec3 nz = tv_normal(normal_tex, p.xy, 0.0) * 2.0 - 1.0;
	vec3 mapped = normalize(vec3(nx.z * sign(n.x), nx.y, nx.x) * weights.x
		+ vec3(ny.x, ny.z * sign(n.y), ny.y) * weights.y
		+ vec3(nz.x, nz.y, nz.z * sign(n.z)) * weights.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(n, mapped, normal_strength)), 0.0)).xyz);
	float specular = tv_sample(specular_tex, p.zy, 0.0).r * weights.x
		+ tv_sample(specular_tex, p.xz, 0.0).r * weights.y
		+ tv_sample(specular_tex, p.xy, 0.0).r * weights.z;
	SPECULAR = specular;
	ROUGHNESS = clamp(0.98 - specular * 0.30, 0.78, 0.98);
}
