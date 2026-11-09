// Wasser im Atlas-Brunnen (Shopping Maul): hellblau, glänzend, mit Kreiswellen von der Mitte und den Fontänen.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.06, 0.24, 0.38, 1.0);
uniform vec4 shallow : source_color = vec4(0.45, 0.65, 0.82, 1.0);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float r = length(local_pos.xz);
	float w = sin(r * 14.0 - TIME * 2.4) * 0.5 + 0.5;
	float w2 = sin((local_pos.x + local_pos.z) * 9.0 + TIME * 1.3) * 0.5 + 0.5;
	vec3 n = normalize(vec3(local_pos.x / max(r, 0.001) * (w - 0.5) * 0.25 + (w2 - 0.5) * 0.1, 1.0, local_pos.z / max(r, 0.001) * (w - 0.5) * 0.25));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.15 + 0.45 * fres + 0.1 * w);
	ROUGHNESS = 0.06;
	METALLIC = 0.1;
	SPECULAR = 0.5;
	EMISSION = shallow.rgb * 0.08 * w;
}
