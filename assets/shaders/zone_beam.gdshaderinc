uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.4;
uniform float intensity = 1.0;
/// 0 = Streifen am Boden, 1 = senkrechter Vorhang (UV.y: 0 oben, 1 unten)
uniform float curtain = 0.0;
/// Länge der Seite in Einheiten, damit die Strahlen überall gleich breit sind
uniform float side_len = 10.0;
/// Optional cap for purely visual walls that must not trigger scene bloom (0 = original HDR).
uniform float radiance_limit = 0.0;

void fragment() {
	float a;
	if (curtain > 0.5) {
		float up = 1.0 - UV.y;
		float x = UV.x * side_len;
		// einzelne, scharf begrenzte senkrechte Strahlen verschiedener Breite über einem schwachen Schleier,
		// wandern langsam; nach oben laufen sie aus
		float rays = 0.12 + 0.75 * pow(0.5 + 0.5 * sin(x * 2.3 + TIME * 0.6), 8.0)
			+ 0.5 * pow(0.5 + 0.5 * sin(x * 5.9 - TIME * 0.9), 12.0);
		a = pow(1.0 - up, 1.6) * rays * 0.8;
	} else {
		// Streifen: heller Kern in der Mitte
		float d = abs(UV.y - 0.5) * 2.0;
		a = mix(1.0, 0.35, smoothstep(0.2, 1.0, d));
	}
	// der Vorhang verblasst schneller als der Streifen am Boden: schwach sieht man vor allem die Linie
	ALBEDO = color.rgb * energy * a * (curtain > 0.5 ? intensity * intensity : intensity);
#ifdef ZONE_SURFACE_ONLY
	// Self-lit detail stays on the curtain: no additive floor wash or HDR bloom.
	if (curtain > 0.5) {
		float x = UV.x * side_len;
		float wave_a = 0.5 + 0.5 * sin(x * 2.3 + TIME * 0.6);
		float wave_b = 0.5 + 0.5 * sin(x * 5.9 - TIME * 0.9);
		float filaments = pow(wave_a, 10.0) + pow(wave_b, 15.0) * 0.7;
		float wisps = pow(wave_a, 2.0) * 0.55 + pow(wave_b, 3.0) * 0.25;
		float height_fade = pow(clamp(UV.y, 0.0, 1.0), 1.15);
		vec3 bright_tip = mix(color.rgb, vec3(1.0), 0.42);
		ALBEDO = mix(color.rgb * 0.78, bright_tip, clamp(filaments, 0.0, 1.0));
		ALPHA = clamp((0.035 + wisps * 0.38 + filaments * 0.9) * height_fade * intensity * intensity, 0.0, 0.9);
	} else {
		ALBEDO = mix(color.rgb, vec3(1.0), 0.2);
		ALPHA = clamp(a * intensity * 0.95, 0.0, 0.95);
	}
#endif
	if (radiance_limit > 0.0) {
		float peak = max(ALBEDO.r, max(ALBEDO.g, ALBEDO.b));
		ALBEDO *= min(1.0, radiance_limit / max(peak, 0.0001));
	}
}
