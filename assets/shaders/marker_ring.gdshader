// Wegpunkt-Ring als Leuchtlinie wie das Neon-Feld: flach auf dem Boden, blasser bis weißer Kern,
// gesättigter Schein nach innen und außen, dazu ein dünner zweiter Ring innen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.21, 0.85, 1.0);
uniform float energy = 2.2;
/// Radius des Hauptrings und des inneren Rings (Anteil der halben Fläche), Linienbreite, Weite des Scheins
uniform float radius = 0.62;
uniform float inner = 0.48;
uniform float width = 0.022;
uniform float halo = 0.09;

vec3 sat(vec3 c) {
	float lo = min(c.r, min(c.g, c.b));
	float hi = max(c.r, max(c.g, c.b));
	vec3 s = c - lo * 0.85;
	return s * hi / max(max(s.r, max(s.g, s.b)), 0.001);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float aa = fwidth(r);
	float d = abs(r - radius);
	float di = abs(r - inner);
	float body = 1.0 - smoothstep(width, width + aa, d);
	float core = 1.0 - smoothstep(width * 0.35, width * 0.35 + aa, d);
	float thin = (1.0 - smoothstep(width * 0.35, width * 0.35 + aa, di)) * 0.7;
	float glow = exp(-d / halo) * 0.55 + exp(-di / (halo * 0.5)) * 0.2;
	vec3 c = sat(color.rgb) * energy;
	vec3 col = mix(c * 0.7, c, max(body, thin));
	col = mix(col, vec3(1.0) * energy * 0.9, core * 0.8);
	ALBEDO = col;
	ALPHA = clamp(max(max(body, thin), glow), 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, r));
}
