// Schnee-Überzug für Tower Survivors (SvWorld.snow_cover): weiß auf allem, was nach oben zeigt.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform float threshold = 0.35;
uniform float softness = 0.3;

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float s = smoothstep(threshold, threshold + softness, wn.y);
	ALBEDO = vec3(0.92, 0.95, 1.0);
	ROUGHNESS = 0.85;
	ALPHA = s * 0.97;
}
