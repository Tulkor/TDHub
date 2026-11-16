// Vertex-colored soil/river stones: calculated relief and dielectric response, no fake bitmap maps.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform bool vertex_colors = true;
uniform vec4 stone_color : source_color = vec4(0.447, 0.459, 0.424, 1.0);
uniform float relief_strength : hint_range(0.0, 1.0) = 0.45;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Match the previous StandardMaterial vertex_color_is_srgb conversion.
	vec3 low = COLOR.rgb / 12.92;
	vec3 high = pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4));
	vec3 authored_color = mix(low, high, step(vec3(0.04045), COLOR.rgb));
	ALBEDO = vertex_colors ? authored_color : stone_color.rgb;
	float wet = vertex_colors ? COLOR.a : 0.0;
	float grain = terrain_grain(world_pos * (vertex_colors ? 2.0 : 3.0));
	float relief = (grain - 0.5) * (vertex_colors ? 0.006 : 0.004);
	float visible = 1.0 - smoothstep(0.05, 0.22, length(fwidth(world_pos)));
	NORMAL = terrain_relief_normal(NORMAL, VERTEX, relief, relief_strength * visible);
	ROUGHNESS = mix(mix(0.9, 0.97, grain), 0.74, wet);
	SPECULAR = mix(mix(0.3, 0.38, grain), 0.48, wet);
}
