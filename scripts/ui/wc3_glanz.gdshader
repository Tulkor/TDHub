// Glanz auf dem Messing im WC3-Menü (Renders aus Blender): ein weicher Lichtstreif wandert schräg über den
// Bildschirm, alle paar Sekunden einmal; nur wo Messing ist (Alpha der Textur), sonst unverändert.
shader_type canvas_item;

uniform float period = 7.0;
uniform float strength = 0.45;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float pos = SCREEN_UV.x + SCREEN_UV.y * 0.6;
	float sweep = fract(TIME / period) * 2.6 - 0.5;
	float band = smoothstep(0.12, 0.0, abs(pos - sweep));
	// helle Stellen des Renders (Kanten, Wölbungen) glänzen stärker
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	// nur Messing glänzt: dunkle Schatten (lum ~ 0) bleiben dunkel
	c.rgb += vec3(1.0, 0.86, 0.6) * band * strength * lum * 1.6;
	COLOR = c;
}
