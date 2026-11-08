// Großer blauer Kristall im Hauptmenü (Lukas 2026-11-02: anders rendern): wie geschliffenes Glas. Was dahinter liegt
// (der leuchtende Kern, Säulen, Wald) erscheint gebrochen und farblich leicht aufgefächert, Kanten leuchten nach
// Fresnel, im Inneren funkeln kleine Lichtpunkte, die mit dem Blickwinkel wandern.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.35, 0.72, 1.0);
uniform vec3 deep : source_color = vec3(0.04, 0.16, 0.42);
uniform float refraction = 0.07;
uniform float dispersion = 0.012;
uniform float glow = 0.4;

varying vec3 lpos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	// Brechung: Bildschirm hinter der Facette, je Farbkanal etwas anders verschoben
	vec2 off = NORMAL.xy * refraction;
	float r = textureLod(screen_tex, SCREEN_UV - off * (1.0 + dispersion * 20.0), 1.0).r;
	float g = textureLod(screen_tex, SCREEN_UV - off, 1.0).g;
	float b = textureLod(screen_tex, SCREEN_UV - off * (1.0 - dispersion * 20.0), 1.0).b;
	vec3 behind = vec3(r, g, b);
	// Absorption: flache Blickwinkel gehen durch mehr Kristall, werden dunkler und tiefer blau
	vec3 body = mix(behind * tint * tint * 0.9, deep, (1.0 - ndv) * 0.6);
	// Funkeln im Inneren: Zellen, deren Helligkeit vom Blickwinkel abhängt
	vec3 cell = floor(lpos * 9.0 + VIEW * 2.5);
	float sp = step(0.965, hash(cell)) * (0.5 + 0.5 * sin(TIME * 2.0 + hash(cell + 3.1) * 6.28));
	ALBEDO = vec3(0.0);
	EMISSION = body + tint * (glow * (0.25 + fres * 2.2)) + vec3(0.7, 0.9, 1.0) * sp * 1.6;
	METALLIC = 0.0;
	ROUGHNESS = 0.04;
	SPECULAR = 1.0;
	ALPHA = 1.0;
}
