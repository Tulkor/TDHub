// Nur hinter deckender Geometrie sichtbar. Zusätzlicher Pass derselben (auch animierten) Geometrie.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 color : source_color = vec4(1.0, 0.65, 0.2, 0.4);
uniform bool enabled = true;

void fragment() {
	if (!enabled) { discard; }
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_z = -p.z / p.w;
	float object_z = -VERTEX.z;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	if (scene_z >= object_z - 0.06 || rim < 0.2) { discard; }
	ALBEDO = color.rgb;
	ALPHA = color.a * smoothstep(0.2, 0.85, rim);
}
