// Einfacher Verlaufshimmel wie ProceduralSkyMaterial (gleiche Kurven, ohne Sonnenscheibe),
// dazu Studiolicht für Metall-Spiegelungen (Block unten). Ersetzt das
// ProceduralSkyMaterial in CameraRig.add_environment, Tower Survivors und als reiner
// Spiegel-Himmel in Szenen mit einfarbigem Hintergrund (Metall.spiegel_himmel).
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


uniform vec3 sky_top_color : source_color = vec3(0.385, 0.454, 0.55);
uniform vec3 sky_horizon_color : source_color = vec3(0.646, 0.656, 0.67);
uniform vec3 ground_horizon_color : source_color = vec3(0.646, 0.656, 0.67);
uniform vec3 ground_bottom_color : source_color = vec3(0.2, 0.169, 0.133);
uniform float sky_curve = 0.15;
uniform float ground_curve = 0.02;

void sky() {
	float v = acos(clamp(EYEDIR.y, -1.0, 1.0));
	vec3 col;
	if (EYEDIR.y >= 0.0) {
		float c = 1.0 - v / (PI * 0.5);
		col = mix(sky_horizon_color, sky_top_color, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	} else {
		float c = (v - PI * 0.5) / (PI * 0.5);
		col = mix(ground_horizon_color, ground_bottom_color, clamp(1.0 - pow(1.0 - c, 1.0 / ground_curve), 0.0, 1.0));
	}
	if (AT_CUBEMAP_PASS) {
		col += metall_studio(EYEDIR);
	}
	COLOR = col;
}
