// Map-Boden: zwei Grasarten und Erde, überblendet.
// Erde liegt dort, wo die Splat-Textur es sagt (Laufweg, Spawn, Ziel, Checkpoints, "_"-Felder),
// die Ränder werden mit Rauschen ausgefranst. Die beiden Grasarten wechseln großflächig per Rauschen.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
/// Normal-Maps (aus der Helligkeit der Fotos abgeleitet), damit das Licht Struktur zeigt.
uniform sampler2D grass_a_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Lineare Materialdaten: keine source_color-Konvertierung.
uniform sampler2D grass_a_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool surface_pbr = false;
uniform float normal_strength = 1.0;
/// zweite, feinere Lage derselben Normalmaps (Whiteout-Blend), 0 = aus
uniform float detail_normal = 0.6;
uniform float detail_scale = 3.3;
/// Weichzeichnen der Fotos über eine gröbere Mipmap-Stufe (0 = scharf); gegen Flimmern und Rauschen.
uniform float detail_blur = 0.0;
/// Kontrast des Grases um seinen Mittelwert (1 = Foto, kleiner = ruhiger)
uniform float grass_contrast = 1.0;
/// 0 = Bauflächen-Textur genau einmal abtasten (Pflaster: gedrehte oder zweite Abtastung gäbe Doppelbilder)
uniform float vary = 1.0;
/// Straße statt Erde (Randgruppen TD): scharfer Rand, dunkler Belag aus der Erde-Textur, weiße Randlinien. 0 = aus
uniform float road = 0.0;
uniform float road_dark = 0.42;
/// Wiese (Erde und Gras) auf gesperrten Feldern (G-Kanal der Splat-Textur), 0 = aus
uniform float lawn = 0.0;
uniform sampler2D lawn_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lawn_soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lawn_grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lawn_soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lawn_grass_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lawn_soil_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float lawn_tile = 2.6;
/// Erde-Anteil je Rasterfeld (0..1) in R, gesperrte Felder in G, ein Pixel pro Feld.
uniform sampler2D splat : filter_linear, repeat_disable;
/// Größe der Map in Einheiten.
uniform vec2 map_size = vec2(37.0, 37.0);
/// Kantenlänge einer Texturkachel in Einheiten (1 Einheit = 1 Towerbreite).
uniform float grass_tile = 1.5;
uniform float dirt_tile = 2.2;
/// Fotos sind sehr satt und hell; etwas abdunkeln und entsättigen, damit Tower und Gegner auffallen.
uniform float brightness = 0.72;
uniform float saturation = 0.75;
/// Farbstich über alles (Druidenhain: etwas moosiger)
uniform vec3 tint = vec3(1.0);
/// Deckkraft des Bodens; 0 = unsichtbar (nur Rasterlinien bleiben sichtbar).
uniform float ground_alpha = 1.0;
// Stärke der großflächigen Helligkeitsschwankung (Flecken über mehrere Felder)
uniform float macro = 0.12;
/// Rasterlinien (für den Map-Editor), 0 = aus.
uniform float grid_strength = 0.0;
uniform float cell = 0.5;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// Normalen zweier Tangentialraum-Maps (0..1) mischen, ohne dass die Struktur flach wird (Whiteout-Blend):
// Neigungen addieren sich, statt sich wie beim linearen Mischen gegenseitig aufzuheben.
vec3 whiteout(vec3 a, vec3 b, float w) {
	vec3 n1 = a * 2.0 - 1.0;
	vec3 n2 = mix(vec3(0.0, 0.0, 1.0), b * 2.0 - 1.0, w);
	return normalize(vec3(n1.xy + n2.xy, n1.z * n2.z)) * 0.5 + 0.5;
}

// Höhenbasiertes Mischen zweier Normalen: am Übergang setzt sich die Seite mit der stärkeren Struktur durch.
vec3 blend_normals(vec3 a, vec3 b, float t) {
	vec3 n1 = a * 2.0 - 1.0;
	vec3 n2 = b * 2.0 - 1.0;
	float wa = (1.0 - t) * (1.0 + length(n1.xy));
	float wb = t * (1.0 + length(n2.xy));
	return normalize(n1 * wa + n2 * wb) * 0.5 + 0.5;
}

// Zwei gedrehte, unterschiedlich große Abtastungen derselben Textur, per Rauschen gemischt:
// so fällt die Wiederholung der Kacheln nicht auf.
const mat2 ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

vec3 sample_varied(sampler2D t, vec2 p, float n) {
	vec3 a = texture(t, p, detail_blur).rgb;
	if (vary <= 0.0) {
		return a;
	}
	vec3 b = texture(t, ROT * p * 0.71 + vec2(0.37, 0.13), detail_blur).rgb;
	return mix(a, b, smoothstep(0.3, 0.7, n));
}

// Gedrehte Abtastungen benötigen rückgedrehte Normalen; Albedo-Rotation allein kippt Lichtrelief.
vec3 unrotate_normal(vec3 encoded) {
	vec3 normal = encoded * 2.0 - 1.0;
	normal.xy = transpose(ROT) * normal.xy;
	return normalize(normal) * 0.5 + 0.5;
}

vec3 sample_normal(sampler2D t, vec2 p, float n) {
	vec3 a = texture(t, p, detail_blur).rgb;
	if (vary <= 0.0) { return a; }
	vec3 b = unrotate_normal(texture(t, ROT * p * 0.71 + vec2(0.37, 0.13), detail_blur).rgb);
	return blend_normals(a, b, smoothstep(0.3, 0.7, n));
}

void fragment() {
	vec2 p = world_xz;
	float n_tile = fbm(p * 0.35);
	vec2 uv_ga = p / grass_tile;
	vec2 uv_gb = p / (grass_tile * 1.15) + vec2(0.5);
	vec2 uv_dt = p / dirt_tile;
	vec3 ga = sample_varied(grass_a, uv_ga, n_tile);
	vec3 gb = sample_varied(grass_b, uv_gb, 1.0 - n_tile);
	vec3 dt = sample_varied(dirt, uv_dt, n_tile);
	vec3 na = sample_normal(grass_a_normal, uv_ga, n_tile);
	vec3 nb = sample_normal(grass_b_normal, uv_gb, 1.0 - n_tile);
	vec3 nd = sample_normal(dirt_normal, uv_dt, n_tile);

	// Grasarten: kleine, unregelmäßige Flecken (keine großen einfarbigen Flächen)
	float g_mix = smoothstep(0.3, 0.7, fbm(p * 0.45 + vec2(3.7, 1.2)));
	g_mix = (0.2 + 0.6 * g_mix) * vary;  // nie ganz eine Sorte: weiche, unauffällige Wechsel
	vec3 grass = mix(ga, gb * 1.15, g_mix);
	if (grass_contrast < 1.0) {
		// Mittelwert aus der kleinsten Mipmap-Stufe: ruhige Fläche, Struktur nur noch angedeutet
		vec3 mean_g = mix(textureLod(grass_a, vec2(0.5), 10.0).rgb, textureLod(grass_b, vec2(0.5), 10.0).rgb * 1.15, g_mix);
		grass = mix(mean_g, grass, grass_contrast);
	}
	vec3 grass_n = blend_normals(na, nb, g_mix);
	float grass_spec = 0.35;
	float dirt_spec = 0.35;
	if (surface_pbr) {
		grass_spec = mix(sample_varied(grass_a_specular, uv_ga, n_tile).r,
			sample_varied(grass_b_specular, uv_gb, 1.0 - n_tile).r, g_mix);
		dirt_spec = sample_varied(dirt_specular, uv_dt, n_tile).r;
	}
	float lawn_mask = 0.0;

	// Erde: Splat-Wert plus ausfransender Rand
	vec4 sp = texture(splat, p / map_size);
	float w = sp.r;
	float edge = fbm(p * 1.1 + vec2(11.0, 5.0)) - 0.5;
	float d = smoothstep(0.4, 0.6, w + edge * 0.55);
	// vereinzelt abgetretene Stellen im Gras
	float worn = smoothstep(0.66, 0.78, fbm(p * 0.16 + vec2(40.0, 7.0)));
	d = max(d, worn * 0.45);
	// Übergang: Gras hält sich in den Senken der Erde (helle Erde zuerst sichtbar)
	float dirt_h = dot(dt, vec3(0.33));
	float blend = clamp((d - 0.5) * 2.5 + 0.5 + (dirt_h - 0.35) * 0.8 * (1.0 - abs(d * 2.0 - 1.0)), 0.0, 1.0);
	if (lawn > 0.0) {
		// Wiese: ruhiges Gras (gröbere Mipmap, wenig Kontrast) mit großen, weichen Erdflecken
		vec2 lp = p / lawn_tile;
		vec3 lg = texture(lawn_grass, lp, 1.5).rgb;
		vec3 lg_mean = textureLod(lawn_grass, vec2(0.5), 10.0).rgb;
		lg = mix(lg_mean, lg, 0.55);
		vec3 ls = texture(lawn_soil, lp * 0.8, 1.0).rgb;
		float soil = smoothstep(0.5, 0.68, fbm(p * 0.22 + vec2(13.0, 3.0)));
		vec3 lawn_col = mix(lg, ls, soil * 0.85);
		float lm = smoothstep(0.45, 0.55, sp.g) * lawn;
		lawn_mask = lm;
		grass = mix(grass, lawn_col, lm);
		vec3 lawn_n = blend_normals(texture(lawn_grass_normal, lp, 1.5).rgb,
			texture(lawn_soil_normal, lp * 0.8, 1.0).rgb, soil * 0.85);
		grass_n = blend_normals(grass_n, lawn_n, lm);
		if (surface_pbr) {
			float lawn_spec = mix(texture(lawn_grass_specular, lp, 1.5).r,
				texture(lawn_soil_specular, lp * 0.8, 1.0).r, soil * 0.85);
			grass_spec = mix(grass_spec, lawn_spec, lm);
		}
	}
	if (road > 0.0) {
		// Straße: scharfe Kante ohne Ausfransen, Belag = abgedunkelte, entsättigte Erde-Textur
		blend = smoothstep(0.47, 0.53, w);
		dt = vec3(dot(dt, vec3(0.299, 0.587, 0.114))) * road_dark;
	}
	vec3 col = mix(grass, dt, blend);
	if (road > 0.0) {
		// weiße Randlinien knapp innerhalb der Straßenkante, leicht abgenutzt
		float band = 1.0 - smoothstep(0.022, 0.032, abs(w - 0.6));
		band *= 0.75 + 0.25 * noise(p * 9.0);
		col = mix(col, vec3(0.85), band * road);
	}
	vec3 nrm = blend_normals(grass_n, nd, blend);
	if (detail_normal > 0.0) {
		// feine Lage: Grashalme bzw. Kiesel im Kleinen, auch nah an der Kamera nicht glatt
		vec2 pd = ROT * p * detail_scale;
		vec3 dn = unrotate_normal(mix(texture(grass_a_normal, pd / grass_tile).rgb, texture(dirt_normal, pd / dirt_tile).rgb, blend));
		nrm = whiteout(nrm, dn, detail_normal * (1.0 - lawn_mask));
	}
	// Vertiefungen (dunkle Stellen im Foto) zusätzlich abdunkeln
	float cavity = smoothstep(0.05, 0.45, dot(col, vec3(0.299, 0.587, 0.114)));
	col *= mix(0.7, 1.0, cavity);

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation) * brightness * tint;
	// leichte großflächige Helligkeitsschwankung
	col *= 1.0 - macro * 0.5 + macro * fbm(p * 0.12 + vec2(-8.0, 2.0));

	float alpha = ground_alpha;
	if (grid_strength > 0.0) {
		vec2 g = abs(fract(p / cell + 0.5) - 0.5) / fwidth(p / cell);
		float line = 1.0 - clamp(min(g.x, g.y), 0.0, 1.0);
		// auf sichtbarem Boden dunkle Linien, auf durchsichtigem helle
		col = mix(col * (1.0 - grid_strength * line), vec3(0.55, 0.65, 0.8), (1.0 - ground_alpha) * line);
		alpha = max(alpha, grid_strength * line);
	}

	ALBEDO = col;
	ALPHA = alpha;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_strength;
	float surface_spec = clamp(mix(grass_spec, dirt_spec, blend), 0.0, 1.0);
	ROUGHNESS = surface_pbr ? clamp(0.98 - surface_spec * 0.30, 0.78, 0.98) : mix(0.85, 0.95, blend);
	SPECULAR = surface_spec;
}
