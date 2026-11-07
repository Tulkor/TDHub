// Nebelwand hinter dem Wald im Hauptmenü: unten dicht, nach oben bis etwa Baumhöhe auslaufend, leicht wabernd.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 fog_color : source_color = vec4(0.085, 0.10, 0.18, 1.0);
uniform float density = 0.95;

void fragment() {
	// UV.y: 0 oben, 1 unten am Zylinder (34 m hoch, Unterkante knapp unter dem Boden); ab etwa Baumhöhe
	// (13 m) läuft der Nebel weich in den Himmel aus
	float h = 1.0 - UV.y;
	float wave = sin(UV.x * 40.0 + TIME * 0.05) * 0.03 + sin(UV.x * 97.0 - TIME * 0.03) * 0.02;
	float a = 1.0 - smoothstep(0.42 + wave, 0.85 + wave, h);
	ALBEDO = fog_color.rgb;
	ALPHA = a * density;
}
