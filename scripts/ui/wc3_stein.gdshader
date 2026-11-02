// Oberfläche für die schlichten Modelle der Menü-Nachtszene: Farbe des Modells mit ruhiger Steintextur (triplanar,
// Lukas 2026-11-02: weniger Rauschen) und optional Moos, das von unten und auf Oberseiten wächst (Säulen).
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.6);
uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.12;
uniform float tex_strength = 0.45;
uniform float brightness = 0.45;
uniform float normal_strength = 0.7;
// 0 = kein Moos, 1 = viel
uniform float moss = 0.0;
uniform float moss_height = 2.2;
uniform vec3 moss_color : source_color = vec3(0.30, 0.46, 0.08);

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = wpos * tex_scale;
	// Steintextur nur als sanfte Helligkeitsänderung um die Modellfarbe, nicht als volles Muster
	float lum = dot(tri(detail, p, w).rgb, vec3(0.333));
	vec3 col = base_color * brightness * mix(1.0, lum * 1.9, tex_strength);
	vec3 nm = tri(detail_n, p, w).rgb;
	if (moss > 0.0) {
		float n = vnoise(wpos * 1.7) * 0.6 + vnoise(wpos * 5.3) * 0.4;
		// unten am Boden und auf nach oben zeigenden Flächen, mit Flecken
		float low = 1.0 - smoothstep(0.0, moss_height, wpos.y + (n - 0.5) * 1.4);
		float top = smoothstep(0.45, 0.85, wnrm.y);
		// Flecken: nur wo das Rauschen hoch ist, unten dichter; feine Ränder aus einem zweiten Rauschen
		float patch = smoothstep(0.42, 0.62, n + (vnoise(wpos * 11.0) - 0.5) * 0.18);
		float m = clamp((low * 1.3 + top * 0.7) * moss, 0.0, 1.0) * patch;
		vec3 mc = moss_color * (0.6 + 0.8 * tri(moss_tex, wpos * 0.6, w).rgb);
		col = mix(col, mc, m);
		nm = mix(nm, tri(moss_n, wpos * 0.6, w).rgb, m);
		ROUGHNESS = mix(0.85, 1.0, m);
	} else {
		ROUGHNESS = 0.85;
	}
	ALBEDO = col;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_strength;
}
