// Bodennebel über einer Fläche (eeveTD: Friedhof und Bergwerk): langsam ziehende, weiche Schwaden.
// Mehrere solcher Flächen übereinander in verschiedenen Höhen wirken wie eine dünne Nebelschicht;
// der GL-Renderer hat keinen Volumennebel, deshalb flache Ebenen mit Rauschen statt FogVolume.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 mist_color : source_color = vec3(0.8, 0.82, 0.86);
/// Deckkraft an der dichtesten Stelle
uniform float density = 0.25;
/// Größe der Schwaden (Weltkoordinaten pro Rauschzelle) und Zuggeschwindigkeit
uniform float scale = 0.35;
uniform vec2 wind = vec2(0.05, 0.02);
uniform float seed = 0.0;
/// ab diesem Abstand vom Rand (UV, 0..0,5) volle Dichte
uniform float edge = 0.35;
/// Rauschlagen je Schwade (4 = fein, 2 = billiger für große Flächen wie den Dunst über dem GemTD-Feld)
uniform int octaves = 4;

varying vec2 world_xz;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < octaves; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = world_xz * scale;
	// zwei Lagen gegeneinander verschoben, damit die Schwaden sich verändern statt nur zu gleiten
	float n = fbm(p + TIME * wind) * 0.6 + fbm(p * 1.7 - TIME * wind * 1.6 + vec2(5.0)) * 0.4;
	// dünner Grundschleier, darin dichtere Schwaden
	n = mix(0.18, 1.0, smoothstep(0.3, 0.75, n));
	// weicher, ovaler Rand
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	float fade = 1.0 - smoothstep(1.0 - edge * 2.0, 1.0, length(d * vec2(0.9, 1.0)));
	ALBEDO = mist_color;
	ALPHA = clamp(n * fade * density, 0.0, 1.0);
}
