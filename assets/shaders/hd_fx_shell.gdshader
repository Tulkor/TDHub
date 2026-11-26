shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
// Bollwerk: leuchtende Hüllen. pattern 0 Schildkuppel (Rand leuchtet, Waben wandern),
// 1 Wirbelsäule (Streifen drehen sich nach oben), 2 Lichtsäule (steigt auf, oben dünner).
uniform int pattern = 0;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 core : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform float speed = 1.0;
uniform float seed = 0.0;

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 v) {
	vec2 i = floor(v);
	vec2 f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float alpha = 0.0;
	float hot = 0.0;
	if (pattern == 0) {
		vec2 cell = UV * vec2(18.0, 9.0);
		cell.x += floor(cell.y) * 0.5;
		vec2 f = abs(fract(cell) - 0.5);
		float comb = smoothstep(0.38, 0.5, max(f.x, f.y));
		float wave = smoothstep(0.12, 0.0, abs(fract(UV.y * 1.5 - TIME * 0.35 * speed) - 0.5));
		alpha = rim * 0.85 + comb * (0.1 + wave * 0.55) + 0.05;
		hot = rim * 0.6 + wave * comb;
	} else if (pattern == 1) {
		float s = sin(UV.x * 6.2831853 * 3.0 + UV.y * 11.0 - TIME * 9.0 * speed + seed);
		float fine = sin(UV.x * 6.2831853 * 7.0 + UV.y * 23.0 - TIME * 14.0 * speed);
		float streak = smoothstep(0.45, 1.0, s) + smoothstep(0.75, 1.0, fine) * 0.4;
		alpha = streak * smoothstep(0.0, 0.25, 1.0 - UV.y) * smoothstep(0.0, 0.2, UV.y) * 0.8;
		hot = streak * 0.5;
	} else {
		float rise = vnoise(vec2(UV.x * 26.0 + seed, UV.y * 3.0 - TIME * 3.0 * speed)) * 0.6 + vnoise(vec2(UV.x * 9.0 - seed, UV.y * 1.5 - TIME * 1.7 * speed)) * 0.4;
		float body = smoothstep(0.0, 0.6, 1.0 - UV.y) * (0.35 + rise * 0.8);
		float base = smoothstep(0.25, 0.0, UV.y);
		alpha = body * 0.7 + base * 0.6;
		hot = smoothstep(0.7, 1.0, rise) * (1.0 - UV.y) + base;
	}
	ALBEDO = mix(color.rgb, core.rgb, clamp(hot, 0.0, 1.0));
	ALPHA = clamp(alpha * fade * color.a, 0.0, 1.0);
}
