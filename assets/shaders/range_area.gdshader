// Ein flaches Quad statt Torus: weiche Füllung, gut erkennbare Grenze und dezente Strichelung.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.2, 0.8, 1.0, 0.7);
uniform float radius = 1.0;
uniform float fill = 0.035;
uniform float motion = 0.12;
uniform float pattern = 0.0;
uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = max(fwidth(r), 0.001);
	float border = max(0.025 / max(radius, 0.1), 0.006);
	float inside = 1.0 - smoothstep(0.99 - aa, 0.99 + aa, r);
	float edge = smoothstep(0.99 - border - aa, 0.99 - border + aa, r) * inside;
	float angle = atan(p.y, p.x);
	float dash = smoothstep(-0.15, 0.15, sin(angle * 24.0 - TIME * motion * 6.0));
	float body = fill;
	if (pattern > 0.5) {
		float ripple = 0.5 + 0.5 * sin(r * 30.0 - TIME * motion * 8.0);
		body *= 0.55 + ripple * 0.45;
	}
	if (pattern > 1.5) {
		body *= 0.5 + 0.5 * smoothstep(0.3, 0.8, sin(p.x * 19.0) * sin(p.y * 19.0));
	}
	float wave = (1.0 - smoothstep(0.0, 0.08, abs(r - progress))) * (1.0 - progress) * step(0.001, progress);
	ALBEDO = color.rgb;
	ALPHA = color.a * inside * (body + edge * (0.55 + dash * 0.35) + wave * 0.35);
}
