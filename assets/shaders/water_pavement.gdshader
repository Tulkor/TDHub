// Wiederverwendung der vorhandenen Pflastertexturen: Gehweg, Bordstein und gefasste Kanalkante.
shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform sampler2D cobble_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D cobble_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D cobble_specular : repeat_enable, filter_linear_mipmap;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.55;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	// Senkrechte Kaimauer bekommt Steinlagen, die waagrechten Gehwege Pflaster in Weltmetern.
	vec3 weights = pow(abs(normalize(world_normal)), vec3(8.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 p = world_pos * 0.32;
	vec3 stone = texture(cobble_tex, p.zy).rgb * weights.x
		+ texture(cobble_tex, p.xz).rgb * weights.y
		+ texture(cobble_tex, p.xy).rgb * weights.z;
	float wall = 1.0 - weights.y;
	ALBEDO = mix(stone * 1.15, stone * vec3(0.65, 0.67, 0.7), wall);
	// Triplanar perturbations preserve the geometric normal when the map is flat.
	vec3 nx = texture(cobble_normal, p.zy).rgb * 2.0 - 1.0;
	vec3 ny = texture(cobble_normal, p.xz).rgb * 2.0 - 1.0;
	vec3 nz = texture(cobble_normal, p.xy).rgb * 2.0 - 1.0;
	vec3 detail = terrain_texture_normal(NORMAL, VERTEX, p.zy, nx, normal_strength) * weights.x
		+ terrain_texture_normal(NORMAL, VERTEX, p.xz, ny, normal_strength) * weights.y
		+ terrain_texture_normal(NORMAL, VERTEX, p.xy, nz, normal_strength) * weights.z;
	NORMAL = normalize(detail);
	float spec = texture(cobble_specular, p.zy).r * weights.x
		+ texture(cobble_specular, p.xz).r * weights.y
		+ texture(cobble_specular, p.xy).r * weights.z;
	ROUGHNESS = clamp(0.94 - spec * 0.1, 0.8, 0.96);
	SPECULAR = spec;
}
