#ifdef GEM_REFRACT
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
#endif
uniform float facet_strength = 0.0;
uniform vec4 color : source_color = vec4(1.0);
/// Deckkraft in der Mitte der Flächen (zum Rand hin wird es dichter).
uniform float opacity = 0.62;
uniform float glow = 0.25;
/// Höhe der Sockel-Oberseite (Welt-Y); darüber wird der Stein von unten angestrahlt.
uniform float base_top = 0.14;
uniform float under_light = 0.85;
uniform float under_height = 0.45;
/// 0 = Neon-Look (Blick ins Innere dunkel, Ränder hell); 1 = bei Tageslicht normal vom Licht schattiert
/// wie polierter Stein (eeveTD, Druidenhain), sonst wirkt der Kristall flach.
uniform float daylight = 0.0;
/// Nur bei daylight: bis zu dieser Höhe über dem Sockel ist das Modell Fels (Kristalle wachsen aus Gestein),
/// darüber Farbe; Statuen ganz aus Stein (groß) mit farbigen Adern (vein_amount = Anteil der Adern).
uniform float stone_height = 0.1;
uniform float vein_amount = 0.0;
/// Nur bei daylight: wie stark der Fels die Towerfarbe annimmt (Statuen unterscheidbar, aber steinern).
uniform float stone_tint = 0.0;
uniform vec4 stone_color : source_color = vec4(0.42, 0.41, 0.36, 1.0);
uniform vec4 moss_color : source_color = vec4(0.30, 0.38, 0.18, 1.0);
/// Gespiegelte Umgebung auf den Facetten (gespiegelt würde sonst nur der Sternenhimmel):
/// heller Horizont-Streifen und Himmel, je Facette anders, an den Rändern stärker (Fresnel). 0 = aus
uniform float env_reflect = 0.55;
uniform vec4 reflect_horizon : source_color = vec4(1.0, 0.45, 0.9, 1.0);
uniform vec4 reflect_sky : source_color = vec4(0.5, 0.8, 1.0, 1.0);

varying float world_y;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_y = world_pos.y;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	return noise3(p) * 0.55 + noise3(p * 2.1 + 3.7) * 0.3 + noise3(p * 4.7 + 9.1) * 0.15;
}

// Tageslicht-Look: Fels mit Moos oben, Farbe als Kristall bzw. Adern, alles mit Struktur statt einfarbig.
// Rückgabe: rgb = Albedo, a = Anteil Farbe (für Glanz und Eigenleuchten)
vec4 daylight_albedo(vec3 n_world) {
	float n = fbm3(world_pos * 7.0);
	float n2 = fbm3(world_pos * 16.0 + 5.0);
	float h = world_y - base_top;
	// Grenze Fels/Farbe ausgefranst
	float stone = 1.0 - smoothstep(-0.02, 0.02, h - stone_height - (n - 0.5) * 0.12);
	// Adern im Fels (Statuen): Bänder aus dem Rauschen
	float nv = fbm3(world_pos * 3.2 + 11.0);
	float vein = (1.0 - smoothstep(0.0, 0.025, abs(nv - 0.5) - 0.02)) * step(0.001, vein_amount);
	vein *= smoothstep(1.0 - vein_amount - 0.15, 1.0 - vein_amount + 0.15, n);
	float colored = max(1.0 - stone, vein);
	vec3 rock = mix(stone_color.rgb, stone_color.rgb * 0.6 + color.rgb * 0.4, stone_tint) * (0.7 + 0.6 * n) * (0.85 + 0.3 * n2);
	rock = mix(rock, moss_color.rgb * (0.8 + 0.4 * n2), smoothstep(0.55, 0.9, n_world.y) * smoothstep(0.45, 0.7, n) * 0.8);
	vec3 crystal = color.rgb * (0.7 + 0.45 * n);
	// feine dunkle Risse und hellere Spitzen
	crystal *= 1.0 - (1.0 - smoothstep(0.0, 0.03, abs(n2 - 0.5))) * 0.45;
	crystal = mix(crystal, mix(color.rgb, vec3(1.0), 0.35), smoothstep(0.25, 0.6, h) * 0.35);
	return vec4(mix(rock, crystal, colored), colored);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.5);
	// Flächen, die zur Kamera zeigen, wirken wie Blick ins Innere (dunkler, satter)
	vec3 deep = color.rgb * color.rgb;
	vec4 day = vec4(color.rgb, 1.0);
	if (daylight > 0.0) {
		day = daylight_albedo((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
	ALBEDO = mix(mix(deep, color.rgb, 0.4 + 0.6 * fresnel), day.rgb, daylight);
	ALPHA = mix(clamp(opacity + fresnel * 0.45, 0.0, 1.0), 1.0, daylight);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.08, mix(0.9, 0.3, day.a), daylight);
	SPECULAR = mix(0.9, mix(0.15, 0.45, day.a), daylight);
	// Licht von unten: stark am Fuß, nach oben abnehmend; nach unten zeigende Flächen extra hell
	float under = 1.0 - smoothstep(base_top, base_top + under_height, world_y);
	float down = max(0.0, -(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	vec3 lit = mix(color.rgb, vec3(1.0), 0.35);
	EMISSION = (color.rgb * (glow + fresnel * 0.5 * (1.0 - daylight)) + lit * under_light * (under * under + down * 0.6 * under))
			* mix(1.0, day.a, daylight);
	if (env_reflect > 0.0) {
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 rw = reflect(-vw, nw);
		float band = exp(-abs(rw.y - 0.12) * 10.0);
		float sky = smoothstep(0.35, 1.0, rw.y);
		// bei Tageslicht weißlicher Himmel statt Neonfarben
		vec3 env = mix(reflect_horizon.rgb * band + reflect_sky.rgb * sky * 0.45, vec3(band * 0.8 + sky * 0.5), daylight);
		EMISSION += env * env_reflect * (0.2 + fresnel) * mix(1.0, day.a * 0.5, daylight);
	}
	float facet = pow(max(dot(normalize(NORMAL), normalize(vec3(0.35, 0.8, 0.45))), 0.0), 12.0);
	EMISSION += mix(color.rgb, vec3(1.0), 0.65) * facet * facet_strength;
#ifdef GEM_REFRACT
	if (daylight < 0.5) {
		vec2 offset = NORMAL.xy * 0.012 * (1.0 - fresnel);
		vec3 behind = textureLod(screen_tex, clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999)), 0.0).rgb;
		ALBEDO = mix(ALBEDO, behind * mix(vec3(1.0), color.rgb, 0.25), 0.16 * (1.0 - fresnel));
	}
#endif
	RIM = 0.4;
	RIM_TINT = 0.6;
}
