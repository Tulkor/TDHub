// Höhengewichtung hält Wurzeln fest. Phase aus Weltposition, kein Zufall aus der Spiellogik.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float base_y = 0.0;
uniform float height = 1.0;
uniform float wind_strength = 0.018;

void vertex() {
	if (wind_strength > 0.00001) {
		float weight = clamp((VERTEX.y - base_y) / max(height, 0.001), 0.0, 1.0);
		vec3 origin = MODEL_MATRIX[3].xyz;
		float phase = origin.x * 0.43 + origin.z * 0.31;
		float gust = sin(TIME * 1.4 + phase) + 0.35 * sin(TIME * 2.7 + phase * 1.6);
		VERTEX.xz += vec2(1.0, 0.45) * gust * wind_strength * height * weight * weight;
	}
}

void fragment() {
	vec4 c = texture(albedo_texture, UV) * albedo_color * COLOR;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = roughness;
	BACKLIGHT = c.rgb * 0.12;
}
