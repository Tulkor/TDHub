// Farbiger Lichtschein eines Gems auf dem Neon-Feld (wie das Pilzlicht auf dem Hof): weicher Kreis,
// in der Mitte am stärksten, additiv, damit Linien und Boden darunter in der Gem-Farbe aufleuchten.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 0.35;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = exp(-r * r * 4.0) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = color.rgb * a * strength;
}
