// Bollwerk: Aufwertungs-Plus als geschliffener Smaragd. Kreuzform mit Facetten (Licht von links oben),
// dunkler Fassungskante und einem Glanz, der alle paar Sekunden schräg darüber wandert.
shader_type canvas_item;

uniform vec4 stone : source_color = vec4(0.27, 0.78, 0.38, 1.0);
uniform float period = 2.4;
uniform float dim = 0.0; // 1 = gesperrt (grau)

float plus_mask(vec2 p, float arm) {
	vec2 a = abs(p - 0.5);
	return (a.x < arm && a.y < 0.5) || (a.y < arm && a.x < 0.5) ? 1.0 : 0.0;
}

void fragment() {
	vec2 p = UV;
	float outer = plus_mask(p, 0.17);
	if (outer < 0.5) {
		COLOR = vec4(0.0);
	} else {
		// Abstand zur Kreuzkante -> Fassungsrand
		vec2 a = abs(p - 0.5);
		float edge = min(max(0.17 - a.x, 0.5 - a.y) * step(a.x, 0.17), 1.0);
		float edge2 = max(0.17 - a.y, 0.5 - a.x) * step(a.y, 0.17);
		float d = max(edge, edge2);
		// Facetten: Richtung vom Zentrum bestimmt Helligkeit
		vec2 dir = p - 0.5;
		float facet = 0.78 + 0.42 * clamp(-dir.x * 1.6 - dir.y * 2.0, -1.0, 1.0);
		vec3 col = stone.rgb * facet;
		col = mix(col, stone.rgb * 1.6 + 0.15, smoothstep(0.08, 0.0, length(dir - vec2(-0.12, -0.14))) * 0.8);
		// Fassungskante
		col = mix(vec3(0.05, 0.12, 0.06), col, smoothstep(0.0, 0.05, d));
		// wandernder Glanz
		float t = fract(TIME / period);
		float sweep = (p.x + p.y * 0.5) - (t * 3.4 - 1.4);
		col += vec3(0.9, 1.0, 0.92) * smoothstep(0.12, 0.0, abs(sweep)) * 0.9;
		col = mix(col, vec3(dot(col, vec3(0.3, 0.55, 0.15))) * 0.6, dim);
		COLOR = vec4(col, 1.0);
	}
}
