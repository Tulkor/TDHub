// Einfacher Verlaufshimmel wie ProceduralSkyMaterial (gleiche Kurven, ohne Sonnenscheibe),
// dazu Studiolicht für Metall-Spiegelungen (metall_himmel.gdshaderinc). Ersetzt das
// ProceduralSkyMaterial in CameraRig.add_environment, Tower Survivors und als reiner
// Spiegel-Himmel in Szenen mit einfarbigem Hintergrund (Metall.spiegel_himmel).
shader_type sky;

#include "res://assets/shaders/metall_himmel.gdshaderinc"

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
