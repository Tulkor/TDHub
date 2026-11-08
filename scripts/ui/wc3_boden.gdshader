// Boden der Menü-Nachtszene (Lukas 2026-11-02): Gras mit Erdflecken, Kiesweg vom Vordergrund zum Kiesplatz unter
// dem blauen Kristall und weiter zur Kirche. Alles in Weltkoordinaten, Ränder mit Rauschen ausgefranst.
shader_type spatial;

uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_tint : source_color = vec3(0.35, 0.42, 0.36);
uniform vec3 dirt_tint : source_color = vec3(0.48, 0.40, 0.33);
uniform vec3 gravel_tint : source_color = vec3(0.36, 0.35, 0.37);
// Kiesplatz: Mitte (x, z) und Radius
uniform vec3 plaza = vec3(-3.5, 0.0, 5.4);
// Wegpunkte (x, z), als Linienzug
uniform vec2 path_pts[7];
uniform float path_width = 1.5;

varying vec3 wpos;

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
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * t);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	// Gras in zwei Maßstäben gemischt, damit die Kachelung nicht auffällt
	vec2 uv = p / 4.0;
	float big = fbm(p * 0.05);
	vec3 g = mix(texture(grass, uv).rgb, texture(grass, uv * 0.37 + 0.31).rgb, 0.35);
	g *= grass_tint * (0.8 + 0.4 * big);
	vec3 gn = texture(grass_n, uv).rgb;
	// Erdflecken
	float dm = smoothstep(0.58, 0.68, fbm(p * 0.11 + 3.7) + 0.08 * vnoise(p * 1.3));
	vec3 d = texture(dirt, p / 3.0).rgb * dirt_tint;
	vec3 dn = texture(dirt_n, p / 3.0).rgb;
	// Kies: Weg und Platz, Rand ausgefranst, am Rand mischt sich Erde dazu
	float pd = 1e5;
	for (int i = 0; i < 6; i++) {
		pd = min(pd, seg_dist(p, path_pts[i], path_pts[i + 1]));
	}
	float edge_noise = (fbm(p * 0.9) - 0.5) * 0.9;
	float path = 1.0 - smoothstep(path_width - 0.25, path_width + 0.25, pd + edge_noise);
	float pl = 1.0 - smoothstep(plaza.z - 0.3, plaza.z + 0.3, length(p - plaza.xy) + edge_noise);
	float gm = max(path, pl);
	float rim = max(smoothstep(path_width - 0.6, path_width + 0.9, pd + edge_noise), smoothstep(plaza.z - 0.7, plaza.z + 1.2, length(p - plaza.xy) + edge_noise));
	rim = (1.0 - min(rim, 1.0)) * (1.0 - gm);
	dm = max(dm, rim * 0.85);
	vec3 k = mix(texture(gravel, p / 1.6).rgb, vec3(0.5), 0.35) * gravel_tint;
	vec3 kn = texture(gravel_n, p / 1.6).rgb;
	vec3 col = mix(g, d, dm);
	vec3 nrm = mix(gn, dn, dm);
	col = mix(col, k, gm);
	nrm = mix(nrm, kn, gm);
	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = mix(1.0, 0.8, gm);
	ROUGHNESS = mix(0.95, 0.8, gm);
}
