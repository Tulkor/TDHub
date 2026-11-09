// Feuer nach dem Vorbild der Feuerschalen und Lagerfeuer in WoW (nur das Prinzip nachgebaut): mehrere
// Flammenzungen aus verwirbeltem, nach oben laufendem Rauschen, die oben in einzelne Fetzen zerreißen; Farbe
// über die Hitze von dunklem Rot über Orange und Gelb bis fast Weiß im Kern, additiv und hell genug fürs Leuchten.
// Ein Quad als Billboard (Größe aus der Skalierung des Knotens), Fuß der Flamme am unteren Rand.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float intensity = 2.6;
/// Versatz je Feuer, damit nicht alle im Gleichtakt züngeln
uniform float phase = 0.0;
/// Geschwindigkeit der Flammen nach oben
uniform float speed = 1.0;
/// Wie breit die Flamme unten ist (Anteil der Quadbreite) und wie stark sie oben zerfasert
uniform float width = 0.46;
uniform float ragged = 1.0;
/// Farben über die Hitze: Rand (dunkelrot), Körper (orange), Spitze/Kern (gelb, fast weiß)
uniform vec3 col_edge : source_color = vec3(0.55, 0.06, 0.01);
uniform vec3 col_body : source_color = vec3(1.0, 0.36, 0.05);
uniform vec3 col_hot : source_color = vec3(1.0, 0.72, 0.28);
uniform vec3 col_core : source_color = vec3(1.0, 0.95, 0.78);
/// Helligkeit von außen (Flackern, gleicher Takt wie das Licht), 1 = ruhig
uniform float flick = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.1 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Billboard: Achsen der Kamera, Größe aus der Skalierung des Knotens
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float t = TIME * speed + phase;
	float y = 1.0 - UV.y;
	float x = UV.x - 0.5;
	// Verwirbelung: großes, langsames Rauschen biegt die Flamme, je höher desto stärker
	float warp = fbm(vec2(x * 2.0 + phase, y * 1.3 - t * 1.1));
	x += (warp - 0.5) * 0.3 * y * ragged + sin(t * 1.7 + y * 3.0) * 0.02 * y;
	// Umriss: unten rund und breit, nach oben buschig zulaufend
	float env = width * pow(max(1.0 - y, 0.0), 0.45) * pow(smoothstep(0.0, 0.2, y), 0.4) + 0.004;
	float d = clamp(1.0 - abs(x) / env, 0.0, 1.0);
	// mehrere Zungen nebeneinander: quer laufende Wellen, deren Spitzen unterschiedlich hoch reichen
	float tongues = 0.5 + 0.5 * sin(x * 26.0 + vnoise(vec2(x * 6.0, t * 0.8)) * 6.0 + t * 0.7);
	// schnell aufsteigendes, feineres Rauschen: Fetzen, die sich lösen
	float n = fbm(vec2(x * 4.5, y * 2.6 - t * 2.4));
	float n2 = vnoise(vec2(x * 10.0 + 3.0, y * 6.0 - t * 4.0));
	float heat = d * 1.25 - y * 1.05 + (n - 0.5) * (0.5 + 0.9 * y) * ragged + (n2 - 0.5) * 0.25 * y;
	heat += (tongues - 0.5) * 0.35 * smoothstep(0.15, 0.6, y) * ragged;
	// oben lösen sich Fetzen ab: Lücken aus dem Rauschen schneiden
	heat -= smoothstep(0.5, 0.95, y) * smoothstep(0.55, 0.3, n) * 0.5 * ragged;
	heat = clamp(heat, 0.0, 1.2);
	// heißer Kern nur unten in der Mitte, oben bleibt die Flamme orange und rot
	float hot = heat * mix(1.0, 0.6, smoothstep(0.1, 0.7, y));
	vec3 col = mix(col_edge, col_body, smoothstep(0.03, 0.3, hot));
	col = mix(col, col_hot, smoothstep(0.35, 0.75, hot));
	col = mix(col, col_core, smoothstep(0.85, 1.15, hot));
	// Rand weich ausblenden, unten am Glutbett nicht hart abschneiden
	float a = smoothstep(0.0, 0.2, heat) * smoothstep(0.0, 0.06, y);
	ALBEDO = col * a * intensity * flick * (0.55 + 0.6 * heat);
}
