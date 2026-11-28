shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0)), 2.0);
	float flow = 0.5 + 0.5 * sin(UV.x * 85.0 - TIME * 28.0 + sin(UV.y * 18.0));
	ALBEDO = mix(vec3(0.08, 0.38, 0.85), vec3(0.65, 0.94, 1.0), flow);
	ALPHA = edge * (0.55 + flow * 0.4);
}
