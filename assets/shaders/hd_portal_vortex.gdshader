shader_type spatial;
// Spawn-Portal von Bollwerk, senkrechtes Quad im Torbogen (QuadMesh in der XY-Ebene).
// strength 0: kleine schwebende Plasmakugel wie eine Lampe (Straße aktiv, niemand kommt).
// strength 1: Wirbel füllt den Bogen, Plasmafäden zucken vom Kern zum Rand (Gegner spawnen).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 portal_color : source_color = vec4(0.71, 0.42, 1.0, 1.0);
uniform vec2 quad_size = vec2(6.0, 5.0);
uniform float idle_radius = 0.6;
instance uniform float strength = 0.0;

float vortex_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vortex_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(vortex_hash(i), vortex_hash(i + vec2(1.0, 0.0)), f.x),
		mix(vortex_hash(i + vec2(0.0, 1.0)), vortex_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vortex_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	float s = smoothstep(0.0, 1.0, clamp(strength, 0.0, 1.0));
	vec2 m = (UV - 0.5) * quad_size;
	m.y = -m.y;
	vec2 radius = mix(vec2(idle_radius), quad_size * 0.47, s);
	vec2 q = m / radius;
	float r = length(q);
	if (r > 1.25) discard;
	float a = atan(q.y, q.x);
	float t = TIME;

	// Spiralarme, die nach innen gezogen werden
	float twist = a + (0.6 + 2.4 * s) / (r + 0.25) - t * (0.8 + 2.2 * s);
	float arms = 0.5 + 0.5 * sin(twist * 3.0 + fbm(vec2(r * 4.0 - t * 1.5, twist)) * 3.0);
	float swirl = pow(arms, 3.0) * smoothstep(1.0, 0.15, r) * (0.2 + 0.8 * s);

	// Plasmafäden vom Kern zur Kugelhülle, wandern und flackern
	float filaments = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float base = fi * 1.0472 + t * (0.25 + 0.07 * fi) + sin(t * 0.7 + fi * 2.3) * 0.8;
		float wobble = (fbm(vec2(r * 3.0 - t * 2.0, fi * 7.3)) - 0.5) * 1.8 * r;
		float diff = a - base - wobble;
		float d = abs(atan(sin(diff), cos(diff))) * max(r, 0.05) * max(radius.x, radius.y);
		float flicker = 0.55 + 0.45 * vortex_noise(vec2(t * 7.0, fi * 3.0));
		float width = 0.02 + 0.03 * r;
		float reach = smoothstep(1.0, 0.85, r) * smoothstep(0.0, 0.12, r);
		filaments += flicker * reach * ((1.0 - smoothstep(0.0, width, d)) + 0.35 * exp(-d * 12.0));
	}
	// Leuchtpunkte, wo die Fäden die Hülle berühren
	float shell_hit = filaments * (1.0 - smoothstep(0.0, 0.12, abs(r - 0.92)));

	float core = exp(-r * r * 9.0) * 1.6;
	float rim = (1.0 - smoothstep(0.0, 0.05, abs(r - 1.0))) * mix(0.6, 0.35, s);
	float glass = smoothstep(1.0, 0.7, r) * 0.1;
	float eye = smoothstep(0.35, 0.05, r) * s * 0.5;   // dunkles Auge im Wirbel

	vec3 col = portal_color.rgb;
	vec3 hot = mix(col, vec3(1.0), 0.55);
	vec3 c = col * (swirl * 1.5 + glass + rim) + hot * (filaments * 0.9 + shell_hit * 0.8) + vec3(1.0, 0.95, 1.0) * core * (1.0 - eye);
	float alpha = clamp(max(max(swirl, filaments), max(core, rim + glass)), 0.0, 1.0) * (1.0 - smoothstep(1.0, 1.2, r));
	ALBEDO = c * 1.6;
	ALPHA = alpha;
}
