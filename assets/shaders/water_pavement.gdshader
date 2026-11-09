// Wiederverwendung der vorhandenen Pflastertexturen: Gehweg, Bordstein und gefasste Kanalkante.
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D cobble_tex : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	// Senkrechte Kaimauer bekommt Steinlagen, die waagrechten Gehwege Pflaster in Weltmetern.
	vec3 weights = pow(abs(normalize(world_normal)), vec3(8.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 p = world_pos * 0.32;
	vec3 stone = texture(cobble_tex, p.zy).rgb * weights.x
		+ texture(cobble_tex, p.xz).rgb * weights.y
		+ texture(cobble_tex, p.xy).rgb * weights.z;
	float wall = 1.0 - weights.y;
	ALBEDO = mix(stone * 1.15, stone * vec3(0.65, 0.67, 0.7), wall);
	ROUGHNESS = 0.92;
	SPECULAR = 0.18;
}
