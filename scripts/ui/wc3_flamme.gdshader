// Flamme in den Laternen der Menü-Nachtszene (Lukas 2026-11-02): Tropfenform, die nach oben züngelt, heller Kern,
// orange Hülle, roter Saum. Immer zur Kamera gedreht, ohne Tiefentest (die Laterne ist rundum geschlossen).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform float phase = 0.0;
uniform float intensity = 2.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	// Billboard: Achsen der Kamera, Größe aus der Skalierung des Knotens
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float t = TIME * 1.6 + phase;
	float y = 1.0 - UV.y;
	float n = vnoise(vec2(UV.x * 4.0, y * 3.0 - t * 2.4)) * 0.65 + vnoise(vec2(UV.x * 9.0, y * 7.0 - t * 4.1)) * 0.35;
	float x = UV.x - 0.5 + (n - 0.5) * 0.22 * y + sin(t * 1.3) * 0.03 * y;
	// Breite: unten rund, oben spitz
	float width = 0.27 * pow(max(1.0 - y, 0.0), 0.9) * sqrt(smoothstep(0.0, 0.22, y)) + 0.002;
	float d = abs(x) / width;
	float top = y + (n - 0.5) * 0.28;
	float body = (1.0 - smoothstep(0.55, 1.0, d)) * (1.0 - smoothstep(0.62, 0.92, top));
	float core = (1.0 - smoothstep(0.0, 0.55, d)) * (1.0 - smoothstep(0.18, 0.5, top)) * smoothstep(0.02, 0.12, y);
	vec3 col = mix(vec3(0.85, 0.18, 0.03), vec3(1.0, 0.55, 0.12), smoothstep(0.0, 0.6, body));
	col = mix(col, vec3(1.0, 0.93, 0.7), core);
	// blauer Fuß am Docht
	col = mix(col, vec3(0.3, 0.45, 1.0), (1.0 - smoothstep(0.0, 0.1, y)) * (1.0 - smoothstep(0.0, 0.6, d)) * 0.6);
	ALBEDO = col * intensity;
	ALPHA = clamp(body + core * 0.5, 0.0, 1.0);
}
