// Nachtozean hinter der Eisfläche (Tower Survivors): dunkles Blau, bewegte Wellen über die Normale, Fresnel.
shader_type spatial;
render_mode cull_back;

uniform vec3 deep = vec3(0.01, 0.03, 0.07);
uniform vec3 shallow = vec3(0.04, 0.12, 0.2);

float wave(vec2 p, vec2 d, float f, float s) {
	return sin(dot(p, d) * f + TIME * s);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz;
	float dx = 0.0;
	float dz = 0.0;
	dx += cos(dot(p, vec2(1.0, 0.3)) * 0.35 + TIME * 0.9) * 0.35;
	dz += cos(dot(p, vec2(-0.4, 1.0)) * 0.5 + TIME * 1.2) * 0.25;
	dx += cos(dot(p, vec2(0.7, -0.8)) * 1.3 + TIME * 1.7) * 0.12;
	dz += cos(dot(p, vec2(0.2, 0.9)) * 1.9 + TIME * 2.1) * 0.08;
	vec3 n = normalize(vec3(-dx, 1.0, -dz));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep, shallow, fres);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
