// Lokale Verzerrung, kein bildschirmfüllendes Effekt-Quad; nur Grafik Hoch.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float progress = 0.0;
uniform float strength = 0.006;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = exp(-pow((r - progress * 0.9) * 19.0, 2.0));
	float fade = ring * (1.0 - progress) * smoothstep(0.0, 0.1, progress);
	vec2 offset = normalize(p + vec2(0.0001)) * strength * fade;
	ALBEDO = texture(screen_tex, clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999))).rgb;
	ALPHA = fade * 0.65;
}
