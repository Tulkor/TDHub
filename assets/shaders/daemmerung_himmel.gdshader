// Himmel für den Tageszeit-Wechsel (DayCycle): Farbverlauf in drei Bändern wie bei Sonnenauf- und -untergang,
// warmer Schein am Horizont um die Sonne, Sonnen- und Mondscheibe mit Hof, Sterne bei Nacht.
// Nur Uniforms, kein TIME: Godot rechnet die Umgebungs-Cubemap nur neu, wenn DayCycle Werte ändert.
shader_type sky;

// Studiolicht nur für Spiegelungen (Metall-Look aller Modi, Metall in scripts/map/metall.gd).
// Gleicher Block in stil_himmel, skybox und daemmerung_himmel (bei Änderung alle drei): als #include
// in Himmel-Shadern blieben in Godot 4.3 beim Beenden Ressourcen hängen ("resources still in use").
// Wird nur im Umgebungs-Würfel (AT_CUBEMAP_PASS) dazugerechnet: der sichtbare Himmel bleibt gleich,
// Metall bekommt aber helle Flächen zum Spiegeln (Horizontstreifen an senkrechten Flächen,
// Softboxen schräg oben für Kanten und Rundungen). Ohne das spiegelt Metall nur den dunklen Himmel
// und wirkt wie graues Plastik.

/// Stärke (0 = aus), setzt Metall.himmel_werte() je Modus
uniform float metall_glanz = 1.0;
/// Farbe der Softboxen rundum (Hauptlicht) und des Horizontstreifens (Arcade: Pink und Cyan)
uniform vec3 metall_farbe : source_color = vec3(1.0, 0.96, 0.9);
uniform vec3 metall_farbe2 : source_color = vec3(0.75, 0.85, 1.0);

float metall_box(vec3 d, float az, float el, float schaerfe) {
	vec3 a = vec3(cos(az) * cos(el), sin(el), sin(az) * cos(el));
	float c = max(dot(d, a), 0.0);
	// weicher Kern mit kurzem Randabfall, damit Kanten eine klare Lichtkante zeigen
	return smoothstep(cos(schaerfe), cos(schaerfe * 0.55), c);
}

vec3 metall_studio(vec3 dir) {
	vec3 d = normalize(dir);
	// Horizontstreifen: senkrechte Flächen bekommen den typischen hellen Streifen von poliertem Metall
	float band = smoothstep(-0.03, 0.04, d.y) * (1.0 - smoothstep(0.1, 0.3, d.y));
	// vier Softboxen rundum in 50° Höhe (unabhängig von der Kamera), eine kleine Lampe fast senkrecht oben
	float box = 0.0;
	for (int i = 0; i < 4; i++) {
		box += metall_box(d, 0.35 + float(i) * 1.5708, 0.87, 0.3);
	}
	float top = metall_box(d, 0.0, 1.45, 0.22);
	vec3 c = metall_farbe * (box * 1.1 + top * 0.6) + metall_farbe2 * band * 0.45;
	return c * metall_glanz;
}


uniform vec3 top_color : source_color = vec3(0.1, 0.15, 0.35);
uniform vec3 mid_color : source_color = vec3(0.35, 0.3, 0.5);
uniform vec3 horizon_color : source_color = vec3(0.9, 0.5, 0.3);
uniform vec3 ground_color : source_color = vec3(0.05, 0.05, 0.08);
/// Höhe (0..1 über dem Horizont), bis zu der das mittlere Band reicht
uniform float mid_height = 0.28;
/// Richtung zur Sonne und zum Mond (Weltkoordinaten, normiert)
uniform vec3 sun_dir = vec3(0.0, 0.1, -1.0);
uniform vec3 moon_dir = vec3(0.0, 0.5, 1.0);
/// Schein um die Sonne (Mie-Streuung): Farbe, Stärke, Breite; flach über dem Horizont am breitesten
uniform vec3 glow_color : source_color = vec3(1.0, 0.5, 0.2);
uniform float glow = 1.0;
uniform float glow_width = 6.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float sun_size = 0.012;
uniform float sun_energy = 6.0;
uniform vec3 moon_color : source_color = vec3(0.8, 0.85, 1.0);
uniform float moon_size = 0.018;
uniform float moon_energy = 2.0;
uniform float stars = 0.0;
/// leichte Wolkenbänder am Horizont, von der Sonne her angeleuchtet
uniform float clouds = 0.5;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.6, 0.4);
uniform vec3 cloud_dark : source_color = vec3(0.2, 0.18, 0.3);

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
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h < 0.0) {
		col = mix(horizon_color * 0.5, ground_color, smoothstep(0.0, 0.25, -h));
	} else {
		// unten warmes Horizontband, darüber das mittlere Band (z. B. Rosa/Violett), oben das tiefe Blau
		float a = smoothstep(0.0, mid_height, h);
		float b = smoothstep(mid_height * 0.6, 1.0, h);
		col = mix(horizon_color, mid_color, a);
		col = mix(col, top_color, b);
	}
	// Schein um die Sonne: in Richtung der Sonne heller und wärmer, am Horizont am breitesten
	vec3 sd = normalize(sun_dir);
	float cs = max(dot(d, sd), 0.0);
	float flat_h = 1.0 - smoothstep(0.0, 0.6, abs(h));
	float halo = pow(cs, glow_width) * (0.35 + 0.65 * flat_h) + pow(cs, glow_width * 12.0) * 0.8;
	col += glow_color * halo * glow;
	// Wolkenbänder: flach projiziert, Unterseite von der Sonne her angestrahlt
	if (clouds > 0.0 && h > 0.0) {
		vec2 p = d.xz / (h + 0.08) * 1.4;
		float c = fbm(p * vec2(0.6, 1.6) + vec2(3.1, 1.7));
		c = smoothstep(0.5, 0.78, c) * (1.0 - smoothstep(0.05, 0.5, h)) * smoothstep(0.0, 0.03, h);
		vec3 cc = mix(cloud_dark, cloud_lit, pow(cs, 3.0) * 0.8 + 0.2);
		col = mix(col, cc, c * clouds);
	}
	if (AT_CUBEMAP_PASS) {
		// Studiolicht für Metall-Spiegelungen, so hell wie der Himmel gerade ist (nachts schwach, Mondlicht-Ton)
		float hell = dot(mix(horizon_color, top_color, 0.5), vec3(0.3, 0.5, 0.2));
		col += metall_studio(d) * clamp(0.25 + hell * 2.5, 0.25, 1.6);
	} else {
		// Sonnenscheibe mit weichem Rand, darunter am Horizont abgeschnitten
		float sun_disc = smoothstep(cos(sun_size * 1.15), cos(sun_size * 0.85), dot(d, sd));
		col += sun_color * sun_energy * sun_disc * smoothstep(-0.01, 0.01, h);
		vec3 md = normalize(moon_dir);
		float cm = dot(d, md);
		float moon_disc = smoothstep(cos(moon_size * 1.1), cos(moon_size * 0.9), cm);
		col += moon_color * (moon_energy * moon_disc + pow(max(cm, 0.0), 400.0) * 0.25 * moon_energy) * smoothstep(-0.01, 0.01, h);
		if (stars > 0.0 && h > 0.0) {
			vec2 sp = d.xz / (h + 0.3) * 120.0;
			float s = hash(floor(sp));
			float tw = smoothstep(0.996, 1.0, s) * (1.0 - smoothstep(0.0, 0.4, length(fract(sp) - 0.5)));
			col += vec3(0.9, 0.92, 1.0) * tw * stars * smoothstep(0.02, 0.2, h);
		}
	}
	COLOR = col;
}
