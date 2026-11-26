shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform vec4 tint : source_color = vec4(0.2, 0.22, 0.25, 1.0);
uniform float metalness = 0.0;
uniform float roughness = 0.7;
uniform float glow = 0.0;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float patina = terrain_grain(local_position * 2.2);
	float grain = terrain_grain(local_position * 17.0);
	float etched = smoothstep(0.72, 0.9, terrain_grain(local_position * vec3(7.0, 1.6, 7.0)));
	ALBEDO = tint.rgb * mix(0.72, 1.10, patina) * (1.0 - etched * 0.13);
	METALLIC = metalness;
	ROUGHNESS = clamp(roughness + (grain - 0.5) * 0.12 + etched * 0.1, 0.18, 0.98);
	SPECULAR = mix(0.24, 0.64, metalness) * mix(0.85, 1.0, patina);
	NORMAL = terrain_relief_normal(NORMAL, VERTEX, grain * 0.006 + etched * 0.009, 0.65);
	EMISSION = tint.rgb * glow;
}
