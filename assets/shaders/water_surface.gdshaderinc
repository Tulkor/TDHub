#include "linear_depth.gdshaderinc"
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D flow_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_tex : repeat_enable, filter_linear_mipmap;
#ifdef WATER_DEPTH
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
#endif
#ifdef WATER_REFRACT
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
#endif
uniform vec4 shallow_color : source_color = vec4(0.12, 0.52, 0.52, 0.72);
uniform vec4 deep_color : source_color = vec4(0.02, 0.16, 0.24, 0.9);
uniform vec4 foam_color : source_color = vec4(0.82, 0.95, 0.94, 1.0);
uniform float flow_time = 0.0;
uniform float speed = 0.65;
uniform float tiling = 0.7;
uniform float normal_strength = 0.7;
uniform float wave_height = 0.025;
uniform float foam_strength = 0.65;
uniform float foam_width = 0.16;
uniform float depth_distance = 1.8;
uniform float refraction = 0.012;
uniform float roughness = 0.16;
uniform float width = 2.0;
uniform float body_length = 4.0;
uniform bool pool = false;
uniform float direction = 0.0;
uniform float detail = 1.0;
// Grundrisse anschließender Gewässer (lokal): a = Mitte xz + Längsrichtung xz, b = halbe Länge/Breite + Höhe.
uniform int open_count = 0;
uniform vec4 open_a[16];
uniform vec4 open_b[16];
// Aufprallstellen von Wasserfällen: x, z (lokal), Radius, Strömungs-V für die Schleppe (< 0: keine).
uniform int impact_count = 0;
uniform vec4 impacts[4];
varying vec3 local_pos;

// 1 dort, wo diese Fläche an anderes Wasser gleicher Höhe grenzt: kein Ufer, also kein Uferschaum.
// merged: wie weit die Fläche in einem aufnehmenden Becken liegt (dort blendet sie aus).
float water_open(vec3 p, out float merged) {
	float open = 0.0;
	merged = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= open_count) { break; }
		if (abs(p.y - open_b[i].z) > 0.35) { continue; }
		vec2 v = p.xz - open_a[i].xy;
		vec2 d = open_a[i].zw;
		vec2 q = abs(vec2(dot(v, d), dot(v, vec2(-d.y, d.x)))) - open_b[i].xy;
		float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
		open = max(open, 1.0 - smoothstep(-0.02, 0.1, dist));
		merged = max(merged, open_b[i].w * (1.0 - smoothstep(-0.08, 0.0, dist)));  // knapp hinter dem Rand weg: keine doppelt dunkle Überlappung
	}
	return open;
}

vec2 water_uv(vec2 uv) {
	float c = cos(direction);
	float s = sin(direction);
	return mat2(vec2(c, -s), vec2(s, c)) * uv * tiling;
}

void vertex() {
	local_pos = VERTEX;
	float w = pool ? width : COLOR.g * 16.0;
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(0.0, 0.15, w - UV.x);
	VERTEX.y += sin(UV.y * 2.5 - flow_time * speed * 3.0) * sin(UV.x * 3.5 + flow_time) * wave_height * edge;
}

void fragment() {
	vec2 uv = water_uv(UV);
	vec2 drift = vec2(0.0, flow_time * speed * tiling);
	vec3 n1 = texture(normal_tex, uv - drift).rgb;
	vec3 n2 = texture(normal_tex, uv * 1.7 + vec2(0.13, 0.29) - drift * 0.63).rgb;
	NORMAL_MAP = mix(n1, (n1 + n2) * 0.5, detail);
	NORMAL_MAP_DEPTH = normal_strength;
	float noise = texture(flow_tex, uv * 0.6 - drift * 0.45).r;
	float depth = mix(0.25, 0.7, noise);
	float contact = 0.0;
#ifdef WATER_DEPTH
	float below = linear_view_depth(texture(depth_tex, SCREEN_UV).r, PROJECTION_MATRIX);
	float here = linear_view_depth(FRAGCOORD.z, PROJECTION_MATRIX);
	float gap = max(below - here, 0.0) * max(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.05);
	depth = 1.0 - exp(-gap / max(depth_distance, 0.01));
	contact = 1.0 - smoothstep(0.02, max(foam_width, 0.03), gap);
#endif
	float bank = min(UV.x, (pool ? width : COLOR.g * 16.0) - UV.x);
	if (pool) { bank = min(bank, min(UV.y, body_length - UV.y)); }
	// Uferschaum nur an echten Ufern; Übergänge Wasser→Wasser bleiben offen.
	float merged;
	float edge_foam = (1.0 - smoothstep(0.0, max(foam_width, 0.01), bank)) * (1.0 - water_open(local_pos, merged));
	// Schaumbild wie bei Shader-Packs: zwei gegeneinander treibende Rauschlagen, per Schwelle
	// ausgedünnt. Dicht direkt am Ufer, nach außen in einzelne Flocken zerfallend.
	float p1 = texture(foam_tex, uv * 1.3 - drift * 0.8).r;
	float p2 = texture(foam_tex, uv * 2.9 + vec2(0.37, 0.11) - drift * 1.15 + vec2(sin(flow_time * 0.7) * 0.03, 0.0)).r;
	float breakup = mix(p1, p1 * 0.55 + p2 * 0.45, detail);
	// Aufprall: dichter Kern, auslaufende Ringe, und flussab eine abklingende Schaumschleppe.
	float plunge = 0.0;
	float rings = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= impact_count) { break; }
		float r = max(impacts[i].z, 0.1);
		float d = length(local_pos.xz - impacts[i].xy);
		plunge = max(plunge, 1.0 - smoothstep(r * 0.2, r, d));
		rings = max(rings, pow(0.5 + 0.5 * sin(d * 9.0 / r - flow_time * 5.0), 8.0) * (1.0 - smoothstep(r * 0.5, r * 2.2, d)));
		if (impacts[i].w >= 0.0) {
			float along = UV.y - impacts[i].w;
			plunge = max(plunge, step(0.0, along) * exp(-along / (r * 1.1)) * 0.6);
		}
	}
	NORMAL_MAP_DEPTH = normal_strength * (1.0 + plunge * 1.5 + rings * 0.5);
	float mask = max(max(edge_foam, contact), plunge);
	float foam = smoothstep(1.0 - mask, 1.0 - mask + 0.3, breakup) * sqrt(mask);
	foam = max(foam, rings * 0.45 * breakup);
	foam = clamp(foam * 1.8, 0.0, 1.0) * foam_strength * foam_color.a;
	vec4 color = mix(shallow_color, deep_color, depth);
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.0);
	ALBEDO = mix(color.rgb, shallow_color.rgb * 1.15, fresnel * 0.3);
	ALBEDO *= 0.92 + noise * 0.16;
#ifdef WATER_REFRACT
	vec2 offset = (n1.xy * 2.0 - 1.0) * refraction * (1.0 - foam) * depth;
	vec2 refracted_uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
	// Über Wasser liegende Ufer/Tower nicht in die Brechung hineinziehen.
	if (linear_view_depth(texture(depth_tex, refracted_uv).r, PROJECTION_MATRIX) < here - 0.01) {
		refracted_uv = SCREEN_UV;
	}
	vec3 behind = texture(screen_tex, refracted_uv).rgb;
	ALBEDO = mix(ALBEDO, behind * mix(vec3(1.0), color.rgb, 0.35), 0.22 * (1.0 - depth));
#endif
	ALBEDO = mix(ALBEDO, foam_color.rgb, clamp(foam, 0.0, 1.0));
	ROUGHNESS = mix(roughness, 0.8, foam);
	SPECULAR = 0.65;
	ALPHA = clamp(color.a + foam * 0.2, 0.0, 1.0) * (1.0 - merged);
}
