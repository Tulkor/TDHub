// Felsbrocken: rauchig durchsichtig mit "dunklem Licht" im Inneren.
// Flächen, auf die man frontal blickt (Blick ins Innere), werden dunkel und deckend,
// die Ränder bleiben heller und durchsichtiger.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.36, 0.29, 0.52, 1.0);
uniform vec4 core_color : source_color = vec4(0.015, 0.005, 0.035, 1.0);
uniform float edge_alpha = 0.45;
uniform float core_alpha = 0.92;
/// Wie weit der dunkle Kern zu den Rändern reicht (höher = kleinerer Kern)
uniform float core_falloff = 1.6;
uniform float vein_strength = 0.12;
varying vec3 rock_pos;
varying float variation;
/// Schein des leuchtenden Bodens auf den unteren Flanken (wie Pilzlicht auf den Mauern), 0 = aus
uniform vec4 floor_glow_color : source_color = vec4(0.85, 0.12, 0.7, 1.0);
uniform float floor_glow = 0.0;
/// Höhe in Einheiten, über die der Schein nach oben ausklingt
uniform float floor_glow_height = 0.35;

varying float world_y;
varying float world_ny;

void vertex() {
	rock_pos = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	variation = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	world_ny = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(facing, core_falloff);
	float rim = pow(1.0 - facing, 3.0);
	float grain = sin(rock_pos.x * 19.0 + sin(rock_pos.y * 15.0 + variation * 6.0) + rock_pos.z * 13.0);
	float vein = smoothstep(0.92, 0.995, grain);
	vec3 tint = color.rgb * mix(0.84, 1.14, variation);
	ALBEDO = mix(tint, core_color.rgb, core);
	ALPHA = mix(edge_alpha, core_alpha, core);
	ROUGHNESS = 0.15;
	SPECULAR = 0.4;
	// schwacher violetter Saum, damit die Kontur vor dem dunklen Feld sichtbar bleibt
	EMISSION = tint * (rim * 0.8 + vein * vein_strength);
	if (floor_glow > 0.0) {
		// Flanken und Unterseiten nahe am Boden; nach oben zeigende Flächen kaum
		float side = clamp(0.6 - world_ny * 0.6, 0.0, 1.0);
		EMISSION += floor_glow_color.rgb * floor_glow * exp(-max(world_y, 0.0) / floor_glow_height) * side;
	}
}
