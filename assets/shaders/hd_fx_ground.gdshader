shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
#include "res://assets/shaders/hd_ground_height.gdshaderinc"
// Bollwerk: Bodeneffekte der Heldenfähigkeiten auf einer Ebene (UV 0–1, Rand der Kreisformen bei 1).
// mode: 0 Druckwelle, 1 Feuerring, 2 Siegelkreis, 3 Windwirbel, 4 Risse im Kegel, 5 weiches Leuchten,
// 6 Windbahn (Rechteck, läuft nach −Z), 7 Brandfleck, 8 transparente Heilfläche mit Neonrand.
uniform int mode = 0;
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform float half_angle = 3.2;
uniform float seed = 0.0;
uniform float sides = 3.0;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 core : source_color = vec4(1.0);
varying vec2 p;

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 v) {
	vec2 i = floor(v);
	vec2 f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 v) {
	return vnoise(v) * 0.55 + vnoise(v * 2.1 + 3.7) * 0.3 + vnoise(v * 4.3 + 9.1) * 0.15;
}

// Umriss eines regelmäßigen Vielecks (Abstand der Kante je Winkel).
float polygon(float a, float n, float turn) {
	float seg = 6.2831853 / n;
	return cos(seg * 0.5) / cos(mod(a + turn, seg) - seg * 0.5);
}

void vertex() {
	p = UV * 2.0 - 1.0;
	vec2 at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
	VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,hd_effect_height(at),0.0,0.0)).xyz;
}

void fragment() {
	float d = length(p);
	float a = atan(p.x, -p.y);
	float alpha = 0.0;
	float emission = 0.0;
	vec3 col = color.rgb;
	if (mode == 0) {
		float n = fbm(vec2(a * 3.0 + seed, d * 4.0 - progress * 2.0));
		float front = progress * 0.94;
		float w = mix(0.11, 0.045, progress);
		float ring = smoothstep(w, 0.0, abs(d - front + (n - 0.5) * 0.07));
		float wake = smoothstep(front - 0.4, front, d) * step(d, front) * 0.38 * n;
		alpha = (ring + wake) * pow(1.0 - progress, 1.3);
		col = mix(color.rgb, core.rgb, ring * 0.75);
	} else if (mode == 1) {
		float front = progress * 0.94;
		float n = fbm(vec2(a * 5.0 + seed, d * 6.0 - TIME * 2.5));
		float lick = front + (n - 0.45) * 0.16;
		float band = smoothstep(front - 0.6, front, d) * step(d, lick);
		float heat = band * (0.45 + n);
		alpha = heat * (1.0 - progress * progress);
		col = mix(mix(vec3(0.55, 0.05, 0.0), color.rgb, smoothstep(0.2, 0.7, heat)), core.rgb, smoothstep(0.85, 1.25, heat));
	} else if (mode == 2) {
		float outer = smoothstep(0.025, 0.0, abs(d - 0.96));
		float inner = smoothstep(0.018, 0.0, abs(d - 0.84));
		float dash = step(0.5, fract(a / 6.2831853 * 28.0 + TIME * 0.08)) * smoothstep(0.03, 0.0, abs(d - 0.90));
		float star = smoothstep(0.02, 0.0, abs(d - polygon(a, sides, TIME * 0.25) * 0.8));
		star += smoothstep(0.02, 0.0, abs(d - polygon(a, sides, 3.1415927 / sides - TIME * 0.25) * 0.8));
		star *= step(d, 0.84);
		float runes = step(0.72, vnoise(vec2(floor(a / 6.2831853 * 18.0) * 3.1 + seed, floor(TIME * 1.5)))) * smoothstep(0.035, 0.0, abs(d - 0.90));
		float haze = (1.0 - d) * 0.14 * (0.6 + 0.4 * fbm(p * 4.0 + TIME * 0.3));
		float timer = step(fract((a + 3.1415927) / 6.2831853), 1.0 - progress);
		alpha = outer * (0.35 + 0.65 * timer) + inner * 0.7 + dash * 0.6 + star * 0.55 + runes * 0.5 + haze;
		alpha *= 0.8 + 0.2 * sin(TIME * 3.0);
		col = mix(color.rgb, core.rgb, (outer * timer + star) * 0.5);
	} else if (mode == 3) {
		float arms = sin(a * 3.0 + d * 9.0 - TIME * 7.0 + seed);
		float streak = smoothstep(0.55, 1.0, arms) * smoothstep(1.0, 0.72, d) * smoothstep(0.08, 0.3, d);
		float fine = smoothstep(0.8, 1.0, sin(a * 7.0 + d * 15.0 - TIME * 11.0)) * smoothstep(1.0, 0.5, d) * 0.4;
		float rim = smoothstep(0.05, 0.0, abs(d - 0.93)) * 0.5;
		alpha = streak * 0.75 + fine + rim;
		col = mix(color.rgb, core.rgb, streak * 0.6);
	} else if (mode == 4) {
		float wedge = smoothstep(half_angle, half_angle - 0.12, abs(a));
		float bend = (fbm(vec2(d * 5.0, seed)) - 0.5) * 3.0;
		float crack = smoothstep(0.14, 0.0, abs(sin(a * 8.0 + bend)));
		crack += smoothstep(0.1, 0.0, abs(sin(a * 19.0 - bend * 2.0))) * 0.5 * step(0.35, d);
		float reach = smoothstep(progress + 0.02, progress - 0.2, d);
		float front = smoothstep(0.09, 0.0, abs(d - progress * 0.97)) * step(d, 1.0);
		float hot = smoothstep(0.45, 0.0, d) * 0.5;
		float flicker = fbm(vec2(a * 6.0 + seed, d * 7.0 - TIME * 14.0));
		float fill = reach * (0.16 + 0.5 * smoothstep(0.45, 0.85, flicker)) * smoothstep(1.0, 0.85, d);
		crack = max(crack, smoothstep(0.42, 0.0, abs(sin(a * 8.0 + bend))) * 0.45);
		alpha = wedge * (crack * reach * 1.1 + front * 1.0 + hot * reach + fill);
		col = mix(color.rgb, core.rgb, clamp(crack * reach + front, 0.0, 1.0) * 0.7);
	} else if (mode == 5) {
		float soft = pow(max(1.0 - d, 0.0), 1.6) * 0.45;
		float rim = smoothstep(0.04, 0.0, abs(d - 0.95)) * 0.8;
		float motes = smoothstep(0.72, 0.95, vnoise(p * 14.0 + vec2(0.0, TIME * 1.6) + seed)) * (1.0 - d) * 0.7;
		alpha = (soft + rim + motes) * (0.85 + 0.15 * sin(TIME * 5.0 + seed));
		col = mix(color.rgb, core.rgb, soft + motes);
	} else if (mode == 6) {
		float along = UV.y;
		float n = vnoise(vec2(p.x * 7.0 + seed, along * 5.0 + TIME * 9.0));
		float fine = vnoise(vec2(p.x * 19.0, along * 9.0 + TIME * 15.0));
		float streak = smoothstep(0.5, 0.92, n) + smoothstep(0.7, 1.0, fine) * 0.5;
		float side = smoothstep(1.0, 0.55, abs(p.x));
		float ends = smoothstep(0.0, 0.12, along) * smoothstep(1.0, 0.75, along);
		float head = smoothstep(0.2, 0.0, abs((1.0 - along) - progress)) * side;
		alpha = (streak * 0.8 + head) * side * ends;
		col = mix(color.rgb, core.rgb, head + streak * 0.3);
	} else if (mode == 8) {
		float front = clamp(progress, 0.0, 1.0) * 0.978;
		float rim = 1.0 - smoothstep(0.005, 0.022, abs(d - front));
		float halo = (1.0 - smoothstep(0.01, 0.07, abs(d - front))) * 0.22;
		float fill = (1.0 - smoothstep(max(0.0, front - 0.04), max(0.001, front), d)) * 0.035;
		float pulse = 0.94 + 0.06 * sin(TIME * 5.0 + seed);
		alpha = (fill + rim * 0.95 + halo) * pulse * smoothstep(0.0, 0.12, progress);
		col = mix(color.rgb, core.rgb, rim * 0.35);
		emission = rim * 2.4 + halo * 0.8;
	} else {
		float n = fbm(p * 5.0 + seed);
		float body = smoothstep(1.0, 0.25, d + (n - 0.5) * 0.45);
		float ember = smoothstep(0.62, 0.9, fbm(p * 11.0 + seed + TIME * 0.2)) * body;
		alpha = ember * 0.9 + body * 0.12;
		col = mix(color.rgb, core.rgb, ember * 0.5);
	}
	if (mode != 6 && d > 1.0) {
		discard;
	}
	ALBEDO = col;
	EMISSION = col * emission;
	ALPHA = clamp(alpha * fade * color.a, 0.0, 1.0);
}
