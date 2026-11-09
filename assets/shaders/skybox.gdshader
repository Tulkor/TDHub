// Skybox aus sechs Bildern (Sternenhimmel), als Cubemap übergeben,
// dazu ein violetter Schimmer am Horizont.
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


// source_color: die Bilder sind sRGB, Vulkan rechnet linear (sonst wirkt der Himmel milchig hell)
uniform samplerCube cube : source_color, filter_linear;
uniform float brightness = 0.45;
// alles unter black wird schwarz (dunkle Stellen fast schwarz, Sterne bleiben, Lukas 2026-10-29)
uniform float black = 0.06;
uniform vec4 horizon : source_color = vec4(0.32, 0.12, 0.62, 1.0);
uniform float horizon_strength = 0.05;

void sky() {
	vec3 c = texture(cube, EYEDIR).rgb;
	vec3 stars = max(c - black, vec3(0.0)) / (1.0 - black) * brightness;
	float h = exp(-abs(EYEDIR.y) * 5.0);
	COLOR = stars + horizon.rgb * h * horizon_strength;
	if (AT_CUBEMAP_PASS) {
		// Studiolicht für Metall-Spiegelungen (der Sternenhimmel allein ist fast schwarz)
		COLOR += metall_studio(EYEDIR);
	}
}
