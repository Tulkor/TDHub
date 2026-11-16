// Source-inspired controls: 50%/zero distance, inner/outer cone and focus.
// Original implementation; no Source shader code or assets are copied.
float surface_light_distance(float distance_to_light, float half_distance, float max_distance) {
	float reach = max(max_distance, 0.001);
	float half_reach = clamp(half_distance, 0.001, reach * 0.95);
	float falloff = exp(-0.69314718 * pow(distance_to_light / half_reach, 2.0));
	return falloff * (1.0 - smoothstep(half_reach, reach, distance_to_light));
}

float surface_light_cone(vec3 ray, vec3 direction, float inner_degrees, float outer_degrees, float focus) {
	float outer_angle = clamp(outer_degrees, 0.1, 89.0);
	float inner_angle = clamp(inner_degrees, 0.0, outer_angle - 0.01);
	vec3 axis = direction / max(length(direction), 0.0001);
	float alignment = dot(normalize(ray), axis);
	float cone = smoothstep(cos(radians(outer_angle)), cos(radians(inner_angle)), alignment);
	return pow(cone, max(focus, 0.01));
}

// type 0: soft radial pool; 1: hard edge, still antialiased; 2: directional spotlight.
float surface_light_profile(int type, vec2 offset, float half_distance, float max_distance,
	float edge_width, float height, vec3 direction, float inner_angle, float outer_angle, float focus) {
	float distance_on_floor = length(offset);
	if (type == 1) {
		float edge = max(edge_width, fwidth(distance_on_floor));
		return 1.0 - smoothstep(max_distance - edge, max_distance + edge, distance_on_floor);
	}
	float light = surface_light_distance(distance_on_floor, half_distance, max_distance);
	if (type == 2) {
		vec3 ray = vec3(offset.x, -max(height, 0.001), offset.y);
		light *= surface_light_cone(ray, direction, inner_angle, outer_angle, focus);
	}
	return light;
}
