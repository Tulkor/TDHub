// Maze-Vorlage auf dem Boden im Vaporwave-/80er-Stil (Lukas 2026-11-09): je Block (2×2 Felder) eine flache Platte
// mit türkisem Neonrand und Eckwinkeln, innen ein Verlauf Orange → Rosa (oben links → unten rechts) aus schrägen
// Streifen, die von oben rechts nach unten links durchziehen. Hin und wieder flackert eine Platte kurz.
// Je Instanz: COLOR = Randfarbe (Alpha = Anteil an der Deckkraft), INSTANCE_CUSTOM.x = Füllung
// (1 = Vapor-Verlauf, 0 = keine, 0.5 = Füllung in Randfarbe, z. B. Konflikt), INSTANCE_CUSTOM.y = Zufallswert.
// Unbeleuchtet und ohne Tiefe schreiben, damit Steine und Tower davor bleiben.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.35;
/// Helligkeit über 1 lässt den Rand im Glow mitleuchten.
uniform float energy = 1.6;
uniform vec3 fill_a : source_color = vec3(1.0, 0.5, 0.04);   // Orange (oben links)
uniform vec3 fill_b : source_color = vec3(1.0, 0.12, 0.72);   // Rosa (unten rechts)
/// Randbreite und Länge der Eckwinkel in UV (0..0.5).
uniform float edge = 0.04;
uniform float corner = 0.24;
/// Streifen je Block, ihr Tempo (Streifen je Sekunde) und ihr Anteil an der Deckkraft.
uniform float stripes = 5.0;
uniform float speed = 0.6;
uniform float fill = 0.6;
/// Helligkeit der Füllung (über 1 leuchtet sie leicht im Glow).
uniform float fill_energy = 1.35;
/// Flackern: Wahrscheinlichkeit je Zeitschritt und wie tief es abdunkelt.
uniform float flicker_rate = 0.025;
uniform float flicker_depth = 0.75;

varying vec4 custom;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = UV;
	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float border = 1.0 - smoothstep(edge * 0.6, edge, d);
	vec2 c = min(uv, 1.0 - uv);
	float bracket = max(c.x, c.y) < corner ? 1.0 - smoothstep(edge * 1.6, edge * 2.2, d) : 0.0;
	float frame = max(border * 0.7, bracket * 0.9);
	// Streifen quer zur Richtung oben rechts → unten links, laufen in diese Richtung
	float phase = (uv.y - uv.x) * stripes * 0.5 - TIME * speed;
	float band = smoothstep(0.42, 0.5, fract(phase)) * (1.0 - smoothstep(0.9, 0.98, fract(phase)));
	float stripe = mix(0.22, 1.0, band);
	vec3 vapor = mix(fill_a, fill_b, clamp((uv.x + uv.y) * 0.5, 0.0, 1.0));
	float mode = custom.x;
	vec3 inner = mode > 0.75 ? vapor * fill_energy : COLOR.rgb;
	float inner_a = mode > 0.25 ? fill * stripe : 0.0;
	vec3 col = mix(inner, COLOR.rgb * energy, frame);
	float a = max(frame, inner_a);
	// hin und wieder kurz flackern, jede Platte zu ihrer Zeit
	float seed = custom.y * 97.0;
	float tick = floor(TIME * 14.0);
	float fl = step(1.0 - flicker_rate, hash(tick + seed)) * flicker_depth;
	fl = max(fl, step(0.996, hash(floor(TIME * 3.0) + 11.0)) * hash(tick * 1.3 + seed) * flicker_depth);
	ALBEDO = col;
	ALPHA = clamp(a * opacity * COLOR.a * (1.0 - fl), 0.0, 1.0);
}
