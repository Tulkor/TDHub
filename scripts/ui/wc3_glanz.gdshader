// Glanz auf dem Messing im WC3-Menü (Renders aus Blender): ein weicher Lichtstreif wandert schräg über den
// Bildschirm, alle paar Sekunden einmal; nur wo Messing ist (Alpha der Textur), sonst unverändert.
shader_type canvas_item;

uniform float period = 7.0;
uniform float strength = 0.45;
// Optional: Metallrelief mit der bestehenden UI-Palette einfärben. Standard erhält WC3-Messing.
uniform float palette_metal = 0.0;
// Nur auf einer separaten Schriftebene aktivieren, nicht auf der Knopffläche.
uniform float text_relief = 0.0;
uniform float relief_pixels = 1.0;
uniform float metal_surface = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 c = tex * COLOR;
	float relief = clamp(dot(tex.rgb, vec3(0.3, 0.55, 0.15)) / 0.45, 0.0, 1.6);
	c.rgb = mix(c.rgb, COLOR.rgb * relief, palette_metal);
	if (text_relief > 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE * relief_pixels;
		float left = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
		float right = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		float top = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		float bottom = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
		float bevel = clamp((right - left) * 0.45 + (bottom - top) * 0.7, -0.65, 0.65);
		float shine = 0.88 + bevel;
		float plate = 0.93 + 0.15 * cos(UV.y * 6.2831853) - UV.x * 0.035;
		c.rgb = COLOR.rgb * shine * mix(1.0, plate, metal_surface);
		// Eine schmale dunkle Unterkante lässt die Buchstaben aus dem Metall hervortreten.
		float shadow = texture(TEXTURE, UV - px * vec2(1.0, 1.0)).a * 0.75;
		float glyph_alpha = tex.a;
		float alpha = max(glyph_alpha, shadow);
		c.rgb = mix(vec3(0.025, 0.018, 0.012), c.rgb, glyph_alpha / max(alpha, 0.001));
		c.a = alpha * COLOR.a;
	}
	float pos = SCREEN_UV.x + SCREEN_UV.y * 0.6;
	float sweep = fract(TIME / period) * 2.6 - 0.5;
	float band = smoothstep(0.12, 0.0, abs(pos - sweep));
	// helle Stellen des Renders (Kanten, Wölbungen) glänzen stärker
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	// nur Messing glänzt: dunkle Schatten (lum ~ 0) bleiben dunkel
	c.rgb += vec3(1.0, 0.86, 0.6) * band * strength * lum * 1.6;
	COLOR = c;
}
