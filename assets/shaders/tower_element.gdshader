shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

uniform int kind = 0;
uniform vec4 tint : source_color = vec4(0.5, 0.75, 1.0, 1.0);
uniform float phase = 0.0;
varying vec3 local_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	local_pos = VERTEX;
	if (kind <= 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
	if (kind == 2) { // Tornado: gedrehter Kegel
		float a = TIME * 2.4 + VERTEX.y * 5.0;
		VERTEX.xz = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xz;
	}
	if (kind == 5) { // periodische Wassersäule, zwischen 35 und 100 Prozent Höhe
		VERTEX.y = (VERTEX.y + 0.5) * (0.65 + sin(TIME * 2.0 + phase) * 0.3) - 0.5;
	}
}
void fragment() {
	float t = TIME + phase;
	vec2 p = UV * 2.0 - 1.0;
	float n = noise(UV * vec2(9.0, 6.0) + vec2(t * 0.25, -t * 0.45));
	float alpha = 0.0;
	float glow = 0.0;
	if (kind <= 1) { // weiche Wolken-Billboards, Sturm mit kurzem Flackern
		alpha = smoothstep(1.0, 0.35, length(p)) * smoothstep(0.22, 0.7, n) * 0.8;
		glow = kind == 0 ? pow(max(0.0, sin(t * 3.3)), 48.0) : 0.18;
	} else if (kind == 2) {
		alpha = (0.2 + n * 0.5) * smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.75, UV.y);
		glow = pow(max(0.0, sin(UV.x * 30.0 + UV.y * 24.0 - t * 7.0)), 12.0) * 0.2;
	} else if (kind == 3) { // spiralförmiger Strudel auf Scheibe
		float r = length(p);
		float spiral = sin(atan(p.y, p.x) * 4.0 + r * 18.0 - t * 4.0);
		alpha = smoothstep(1.0, 0.7, r) * (0.25 + 0.6 * smoothstep(0.0, 1.0, spiral));
		glow = alpha * 0.35;
	} else if (kind == 4) { // Kugelblitz: zuckende Linien auf der Oberfläche
		float arc = pow(max(0.0, sin(UV.x * 38.0 + sin(UV.y * 25.0 + floor(t * 10.0)) * 2.0)), 18.0);
		alpha = 0.3 + arc * 0.65;
		glow = arc * 2.0;
	} else if (kind == 5) {
		alpha = (0.2 + n * 0.55) * smoothstep(0.0, 0.2, UV.y);
		glow = pow(max(0.0, sin(UV.x * 30.0 + UV.y * 35.0 - t * 12.0)), 10.0) * 0.6;
	} else { // Bodendecal mit radialen Blitzbögen
		float r = length(p);
		float arc = pow(max(0.0, sin(atan(p.y, p.x) * 9.0 + sin(r * 25.0 + floor(t * 8.0)) * 0.7)), 22.0);
		alpha = smoothstep(1.0, 0.75, r) * (arc + 0.15);
		glow = arc;
	}
	ALBEDO = tint.rgb * (0.55 + n * 0.5) + vec3(glow);
	EMISSION = tint.rgb * glow;
	ALPHA = alpha * tint.a;
}
