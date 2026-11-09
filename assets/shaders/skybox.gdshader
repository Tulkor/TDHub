// Skybox aus sechs Bildern (Sternenhimmel), als Cubemap übergeben,
// dazu ein violetter Schimmer am Horizont.
shader_type sky;

#include "res://assets/shaders/metall_himmel.gdshaderinc"

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
