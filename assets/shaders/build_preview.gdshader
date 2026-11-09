shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform bool valid = true;
uniform vec4 valid_color : source_color = vec4(0.2, 0.95, 0.5, 0.38);
uniform vec4 invalid_color : source_color = vec4(1.0, 0.2, 0.15, 0.5);

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float edge = smoothstep(0.88, 0.97, max(p.x, p.y));
	float hatch = step(0.52, fract((UV.x + UV.y) * 9.0));
	vec4 c = valid ? valid_color : invalid_color;
	ALBEDO = c.rgb;
	ALPHA = c.a * (valid ? 0.28 + edge * 0.72 : 0.25 + hatch * 0.45 + edge * 0.3);
}
