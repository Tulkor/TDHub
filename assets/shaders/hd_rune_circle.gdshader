shader_type spatial;
// Leuchtender Runenkreis auf einer waagrechten Fläche (PlaneMesh): Ringe, ein Band aus
// prozeduralen Runen und ein Hexagramm, langsam drehend. Für Teleport-Schreine und Spawn-Portale.
// strength (pro Instanz): 0 = ruhig, 1 = voll aktiv (heller, schneller, pulsierend).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 rune_color : source_color = vec4(0.71, 0.42, 1.0, 1.0);
uniform float glow = 1.5;
uniform float spin = 0.06;
uniform float rune_count = 18.0;
instance uniform float strength = 0.4;

float rune_hash(float n) { return fract(sin(n * 127.1 + 4.7) * 43758.5453); }

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Ein Runenzeichen in [-1,1]²: senkrechter Stamm plus zufällige Äste (futhark-artig).
float rune(vec2 p, float id) {
	float h1 = rune_hash(id), h2 = rune_hash(id + 3.1), h3 = rune_hash(id + 7.7), h4 = rune_hash(id + 11.3);
	float s = h1 > 0.5 ? 1.0 : -1.0;
	float d = seg(p, vec2(0.0, -0.8), vec2(0.0, 0.8));
	if (h1 < 0.75) {
		float y = 0.8 - h2 * 0.5;
		d = min(d, seg(p, vec2(0.0, y), vec2(s * 0.55, y - 0.45)));
	}
	if (h3 > 0.35) {
		float y = 0.1 - h4 * 0.5;
		d = min(d, seg(p, vec2(0.0, y), vec2(-s * 0.55, y + (h3 > 0.7 ? 0.45 : -0.45))));
	}
	if (h4 > 0.62) {
		d = min(d, seg(p, vec2(-0.5, h2 * 0.3), vec2(0.5, 0.3 + h2 * 0.3 - h1 * 0.6)));
	}
	if (h2 < 0.28) {
		d = min(d, seg(p, vec2(0.0, 0.8), vec2(0.5, 0.45)));
		d = min(d, seg(p, vec2(0.5, 0.45), vec2(0.0, 0.1)));
	}
	return d;
}

float line(float d, float width) {
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(width, width + aa, d);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) discard;
	float s = clamp(strength, 0.0, 1.0);
	float t = TIME * spin * (1.0 + s * 3.0);
	float a = atan(p.y, p.x) + t;

	float lit = 0.0;
	lit = max(lit, line(abs(r - 0.965), 0.012));
	lit = max(lit, line(abs(r - 0.905), 0.007));
	lit = max(lit, line(abs(r - 0.705), 0.007));
	lit = max(lit, line(abs(r - 0.645), 0.005));
	lit = max(lit, line(abs(r - 0.30), 0.006));

	// Runenband zwischen 0.72 und 0.89
	float cell_a = a / 6.2831853 * rune_count;
	float id = mod(floor(cell_a), rune_count);
	float arc = 6.2831853 * 0.805 / rune_count;
	vec2 q = vec2((fract(cell_a) - 0.5) * arc / 0.09, (r - 0.805) / 0.075);
	lit = max(lit, line(rune(q, id), 0.11) * step(abs(q.y), 1.2));

	// Hexagramm, gegenläufig
	float d_star = 10.0;
	for (int k = 0; k < 6; k++) {
		float a0 = float(k) * 1.0471976 - t * 2.0;
		float a1 = a0 + 2.0943951;
		d_star = min(d_star, seg(p, vec2(cos(a0), sin(a0)) * 0.63, vec2(cos(a1), sin(a1)) * 0.63));
	}
	lit = max(lit, line(d_star, 0.006));
	lit = max(lit, 1.0 - smoothstep(0.0, 0.07, r));

	float pulse = 1.0 + 0.2 * sin(TIME * 4.0) * s;
	float fill = (1.0 - r) * 0.08 * s;
	ALBEDO = rune_color.rgb * glow * mix(0.45, 1.15, s) * pulse;
	ALPHA = clamp(lit + fill, 0.0, 1.0);
}
