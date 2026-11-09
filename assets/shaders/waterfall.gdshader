// Wasserfall entlang einer Wurfparabel. UV.y = Flugzeit × Bezugsgeschwindigkeit (beschleunigt sichtbar),
// COLOR.r = Belüftung: an der Kante eine glatte Wasserzunge in Flussfarbe, unten zerrissen und weiß.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D flow_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 shallow_color : source_color = vec4(0.25, 0.65, 0.68, 0.8);
uniform vec4 deep_color : source_color = vec4(0.04, 0.27, 0.36, 0.8);
uniform vec4 foam_color : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform float flow_time = 0.0;
uniform float speed = 2.4;
uniform float tiling = 0.7;
uniform float width = 2.0;
uniform float body_length = 3.0;
uniform float foam_strength = 0.85;
uniform float normal_strength = 0.5;
uniform float detail = 1.0;

void fragment() {
	float aer = COLOR.r;
	vec2 uv = vec2(UV.x * tiling, (UV.y - flow_time * speed) * tiling);
	float streak = texture(flow_tex, uv).g;
	float second = texture(flow_tex, uv * vec2(1.6, 0.8) + vec2(0.2, -flow_time * 0.3)).g;
	float threads = mix(streak, streak * 0.7 + second * 0.3, detail);
	float edge = smoothstep(0.0, 0.12 + aer * 0.2, UV.x) * smoothstep(0.0, 0.12 + aer * 0.2, width - UV.x);
	// Luft wird mit der Geschwindigkeit eingemischt: Fäden zuerst, kurz vor dem Aufprall fast nur Gischt.
	float foam = smoothstep(1.05 - aer, 1.35 - aer, threads) + smoothstep(0.7, 1.0, aer) * threads * 0.6;
	foam = clamp(foam, 0.0, 1.0) * foam_strength * foam_color.a;
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, mix(0.55, threads, aer));
	ALBEDO = mix(water, foam_color.rgb, foam);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (1.0 + aer);
	ROUGHNESS = 0.15 + foam * 0.5;
	SPECULAR = 0.5;
	float body = mix(shallow_color.a, shallow_color.a * (0.35 + threads * 0.65), aer);
	ALPHA = clamp(body + foam * 0.25, 0.0, 1.0) * edge;
}
