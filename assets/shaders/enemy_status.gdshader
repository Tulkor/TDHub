// Gemeinsame Statusauflage. Modelltexturen bleiben erhalten; Muster statt Ganzkörper-Färbung.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float frost = 0.0;
uniform float poison = 0.0;
uniform float stun = 0.0;
uniform float armor_break = 0.0;
uniform float invulnerable = 0.0;
uniform float burning = 0.0;
uniform float hit = 0.0;
uniform float detail = 1.0;
uniform float strength = 0.7;
uniform float base_y = 0.0;
uniform float height = 1.0;
varying vec3 local_pos;
varying float world_y;

void vertex() {
	local_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (strength < 0.001 || frost + poison + stun + armor_break + invulnerable + burning + hit < 0.001) { discard; }
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float h = clamp((world_y - base_y) / max(height, 0.001), 0.0, 1.0);
	float lines = sin(local_pos.x * 21.0 + sin(local_pos.y * 17.0) * 2.0 + local_pos.z * 13.0);
	float veins = smoothstep(0.78, 0.98, lines);
	float pulse = 0.7 + 0.3 * sin(TIME * 3.0 + local_pos.y * 4.0);
	float ice = smoothstep(0.25, 0.85, h + lines * 0.06 * detail);
	vec3 c = vec3(0.32, 0.7, 1.0) * frost * (ice * 0.35 + rim * 0.7);
	c += vec3(0.12, 1.0, 0.27) * poison * mix(rim * 0.5, veins * pulse, detail);
	c += vec3(1.0, 0.48, 0.05) * burning * (veins * pulse + rim * 0.35);
	c += vec3(0.95, 0.74, 0.12) * invulnerable * rim;
	c += vec3(0.9, 0.48, 0.18) * armor_break * veins * (0.35 + rim);
	c += vec3(0.8, 0.8, 1.0) * stun * (rim * 0.65 + step(0.8, sin(h * 36.0)) * 0.2);
	c += vec3(1.0) * hit * rim * 1.7;
	float peak = max(c.r, max(c.g, c.b));
	if (peak < 0.005) { discard; }
	ALBEDO = c / max(peak, 0.001);
	ALPHA = clamp(peak * strength, 0.0, 0.8);
}
