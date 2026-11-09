shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.2, 0.8, 1.0, 0.7);
uniform float energy = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float arrow = 1.0 - smoothstep(0.13, 0.23, abs(p.y - (abs(p.x) * 0.8 - 0.35)));
	arrow *= 1.0 - smoothstep(0.65, 0.95, abs(p.x));
	ALBEDO = color.rgb;
	EMISSION = color.rgb * energy * 0.3;
	ALPHA = color.a * arrow * (0.7 + 0.3 * sin(TIME * 2.5));
}
