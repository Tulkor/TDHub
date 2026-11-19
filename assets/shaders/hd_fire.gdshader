shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;
uniform vec4 fire_color : source_color = vec4(1.0, 0.35, 0.045, 1.0);
void vertex() {
	VERTEX.x += sin(TIME * 3.7 + VERTEX.y * 5.0 + MODEL_MATRIX[3].x) * 0.055 * (UV.y < 0.5 ? 1.0 : 0.3);
}
void fragment() {
	float h = 1.0 - UV.y;
	float sway = sin(h * 9.0 - TIME * 5.1) * 0.13 + sin(h * 17.0 + TIME * 3.0) * 0.065;
	float width = 0.62 * pow(max(1.0 - h, 0.001), 0.65);
	float body = 1.0 - smoothstep(width * 0.4, width, abs((UV.x - 0.5) * 2.0 + sway * h));
	float alpha = body * smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.78, 1.0, h));
	vec3 color = mix(fire_color.rgb, vec3(1.0, 0.84, 0.35), body * (1.0 - h));
	ALBEDO = color;
	EMISSION = color * 1.9;
	ALPHA = alpha * 0.82;
}
