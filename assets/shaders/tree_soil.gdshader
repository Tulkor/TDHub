shader_type spatial;
// Erde unter Bäumen (Randgruppen TD): runde Fläche mit ausgefranstem Rand, Erde und Grasflecken in Weltkoordinaten,
// damit sich Flächen dicht stehender Bäume nahtlos zu einem Park verbinden. Rand per Alpha-Scissor (kein Sortieren).
render_mode cull_disabled;

uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 0.7;
uniform float dirt_tile = 1.6;
uniform float grass_tile = 1.2;
uniform float brightness = 0.8;
uniform float saturation = 0.6;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	// Die Patch-Meshes sind zufällig gedreht, die Texturen bleiben in Weltkoordinaten.
	TANGENT = normalize((inverse(MODEL_MATRIX) * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	BINORMAL = normalize((inverse(MODEL_MATRIX) * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
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
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
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

void fragment() {
	vec2 p = world_xz;
	float r = length(UV - 0.5) * 2.0;
	float edge = fbm(p * 2.6) - 0.5;
	ALPHA = 1.0 - smoothstep(0.75, 0.95, r + edge * 0.45);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 d = texture(dirt, p / dirt_tile).rgb;
	vec3 g = texture(grass, p / grass_tile).rgb;
	float gm = smoothstep(0.45, 0.65, fbm(p * 0.9 + vec2(31.0, 7.0)) + r * 0.25);
	vec3 col = mix(d, g, gm) * brightness;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), col, saturation);
	vec3 dn = texture(dirt_normal, p / dirt_tile).rgb * 2.0 - 1.0;
	vec3 gn = texture(grass_normal, p / grass_tile).rgb * 2.0 - 1.0;
	NORMAL_MAP = normalize(mix(dn, gn, gm)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;
	float specular = mix(texture(dirt_specular, p / dirt_tile).r, texture(grass_specular, p / grass_tile).r, gm);
	SPECULAR = specular;
	ROUGHNESS = clamp(0.98 - specular * 0.30, 0.78, 0.98);
}
