shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
// Bollwerk: leuchtende Bänder (Strahlen, Blitze, Schwungbögen, Leuchtspuren).
// UV.x läuft entlang des Bands (0–1), UV.y quer dazu. tail > 0: nur ein Stück hinter head ist sichtbar
// (Schwung wandert über den Bogen), sonst leuchtet das ganze Band.
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 core : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float flow = 0.0;
uniform float grain = 0.0;
uniform float taper = 0.0;

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 v) {
	vec2 i = floor(v);
	vec2 f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float v = abs(UV.y * 2.0 - 1.0);
	float ends = mix(1.0, sin(UV.x * 3.1415927), taper);
	v = clamp(v / max(ends, 0.05), 0.0, 1.0);
	float glow = pow(1.0 - v, 1.7);
	float hot = smoothstep(0.24, 0.0, v);
	float along = 1.0;
	if (tail > 0.0) {
		float t = (head - UV.x) / tail;
		along = step(0.0, t) * step(t, 1.0) * pow(1.0 - t, 1.4);
	}
	float n = mix(1.0, 0.45 + 1.1 * vnoise(vec2(UV.x * 14.0 - TIME * flow, UV.y * 3.0)), grain);
	ALBEDO = mix(color.rgb, core.rgb, hot);
	ALPHA = clamp((glow * 0.95 + hot) * along * n * fade * color.a * ends, 0.0, 1.0);
}
