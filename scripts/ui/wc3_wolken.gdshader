// Wolken über der Menü-Nachtszene (Lukas 2026-11-02): eine große Fläche hoch über der Lichtung, Rauschen zieht mit
// dem Wind langsam durch. Zur Mondseite hin hellere Ränder, in der Ferne weich ausgeblendet.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec2 wind = vec2(0.010, 0.0035);
uniform vec3 moon_dir = vec3(0.0, 0.5, -1.0);
uniform vec3 dark : source_color = vec3(0.07, 0.08, 0.13);
uniform vec3 lit : source_color = vec3(0.42, 0.48, 0.62);
uniform float cover = 0.5;
uniform float fade_near = 120.0;
uniform float fade_far = 420.0;

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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(11.7, 5.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * 0.011 + TIME * wind;
	// grobe Form langsamer als die feinen Fetzen, so verändern sich die Wolken beim Ziehen
	float n = fbm(p) * 0.75 + fbm(p * 2.6 + TIME * wind * 1.7) * 0.25;
	float c = smoothstep(cover, cover + 0.25, n);
	// Mondseite: Dichte ein Stück Richtung Mond kleiner = Rand angestrahlt
	vec2 md = normalize(moon_dir.xz + vec2(0.0001));
	float n2 = fbm(p + md * 0.06) * 0.75 + fbm((p + md * 0.06) * 2.6 + TIME * wind * 1.7) * 0.25;
	float light = clamp((n - n2) * 9.0 + 0.25, 0.0, 1.0);
	vec3 col = mix(dark, lit, light * (1.0 - c * 0.5));
	float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	float fade = smoothstep(fade_near * 0.4, fade_near, dist) * (1.0 - smoothstep(fade_near, fade_far, dist));
	ALBEDO = col;
	ALPHA = c * 0.82 * fade;
}
