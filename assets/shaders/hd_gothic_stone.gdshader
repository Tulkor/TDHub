shader_type spatial;
// Leichte Quadersteintextur für die gotischen Spielgebäude (HdGothic: Torwerke, Schreine, Portale).
// Weltkoordinaten, Blöcke laufen auf jeder senkrechten Fläche entlang ihrer Waagrechten, damit
// gedrehte Teile keine verzerrten Fugen bekommen. Keine Texturen, nur Rauschen und Relief.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://assets/shaders/terrain_relief.gdshaderinc"

uniform vec4 stone_color : source_color = vec4(0.2, 0.23, 0.28, 1.0);
uniform vec2 block_size = vec2(0.62, 0.31);   // Breite, Höhe eines Quaders in Metern
uniform float grout_width = 0.018;            // Fuge in Metern
uniform float variation = 0.2;                // Helligkeitsstreuung je Block
uniform float relief = 0.6;

varying vec3 world_position;
varying vec3 world_normal;

float block_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 uv;
	if (abs(n.y) > 0.7) {
		uv = world_position.xz;
	} else {
		vec2 tangent = normalize(vec2(-n.z, n.x) + vec2(1e-5));
		uv = vec2(dot(world_position.xz, tangent), world_position.y);
	}
	vec2 tile = uv / block_size;
	float row = floor(tile.y);
	tile.x += mod(row, 2.0) * 0.5 + (block_hash(vec2(row, 3.7)) - 0.5) * 0.3;
	vec2 cell = floor(tile);
	vec2 f = fract(tile);
	vec2 to_edge = min(f, 1.0 - f) * block_size;
	float edge = min(to_edge.x, to_edge.y);
	// Abgeschlagene Kanten: Fugenbreite schwankt mit Rauschen.
	float chip = terrain_grain(vec3(uv * 9.0, 1.3));
	float gw = grout_width * (0.7 + 0.9 * chip);
	float grout = 1.0 - smoothstep(gw * 0.5, gw, edge);
	float bevel = smoothstep(gw, gw + 0.035, edge);

	float rnd = block_hash(cell);
	float rnd2 = block_hash(cell + 17.0);
	float g_mid = terrain_grain(world_position * 3.1);
	float g_fine = terrain_grain(world_position * 11.0);
	float g_large = terrain_grain(world_position * 0.7 + vec3(5.0));
	float speck = g_fine * 0.55 + g_mid * 0.45;

	vec3 base = stone_color.rgb * (1.0 + (rnd - 0.5) * variation * 2.0) * (0.86 + speck * 0.28);
	// Verwitterung: großflächig leicht grünlich-grau, am Fuß dunkler.
	base = mix(base, base * vec3(0.9, 0.97, 0.87), smoothstep(0.55, 0.8, g_large) * 0.35);
	base *= 1.0 - (1.0 - smoothstep(0.0, 1.6, world_position.y)) * 0.18;
	base *= mix(0.94, 1.0, bevel);
	base = mix(base, base * 0.55, grout * 0.75);
	ALBEDO = base;

	float height = bevel * 0.02 + (rnd2 - 0.5) * 0.006 + g_fine * 0.004 + g_mid * 0.003 - grout * 0.01;
	NORMAL = terrain_relief_normal(NORMAL, VERTEX, height, relief);
	ROUGHNESS = mix(0.86, 0.97, grout) - speck * 0.06;
	SPECULAR = 0.3;
	METALLIC = 0.0;
}
