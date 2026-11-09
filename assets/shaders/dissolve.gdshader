shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float progress = 0.0;
uniform float roughness = 0.7;
varying vec3 local_pos;

void vertex() { local_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz; }

void fragment() {
	float n = 0.5 + 0.25 * sin(local_pos.x * 11.0 + sin(local_pos.y * 8.0))
		+ 0.25 * sin(local_pos.z * 13.0 - local_pos.y * 10.0);
	if (n < progress) { discard; }
	vec4 c = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = roughness;
	EMISSION = edge_color.rgb * (1.0 - smoothstep(0.0, 0.07, n - progress)) * step(0.001, progress);
}
