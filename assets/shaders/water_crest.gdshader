// Animierte Gischt über beiden Seiten der Fallkante. Kein Bildschirm-/Tiefenzugriff.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform sampler2D foam_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 foam_color : source_color = vec4(0.85, 0.96, 0.94, 0.95);
uniform float flow_time = 0.0;
uniform float width = 2.0;

void fragment() {
	vec2 uv = vec2(UV.x * width * 2.2, UV.y * 1.7 - flow_time * 0.9);
	float noise = texture(foam_tex, uv).r;
	float fine = texture(foam_tex, uv * 2.3 + vec2(0.3, -flow_time * 0.25)).r;
	float along = smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.68, 1.0, UV.y));
	float edge = smoothstep(0.0, 0.07, UV.x) * (1.0 - smoothstep(0.93, 1.0, UV.x));
	float flecks = smoothstep(0.18, 0.65, noise * 0.7 + fine * 0.3);
	// An der tatsächlichen Naht bleibt ein dichter Kern, außen löst er sich in Flocken auf.
	float core = 1.0 - smoothstep(0.06, 0.2, abs(UV.y - 0.5));
	ALBEDO = foam_color.rgb * (0.9 + fine * 0.1);
	ALPHA = edge * along * max(flecks * 0.85, core * 0.92) * foam_color.a;
}
