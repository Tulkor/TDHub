// Surface-gradient bump in view space: works on generated meshes without UV tangents.
// Height is in scene units; normals and reflectance remain actual material data.
vec3 terrain_relief_normal(vec3 surface_normal, vec3 view_position, float height, float strength) {
	vec3 dx = dFdx(view_position);
	vec3 dy = dFdy(view_position);
	vec3 r1 = cross(dy, surface_normal);
	vec3 r2 = cross(surface_normal, dx);
	float determinant = dot(dx, r1);
	if (abs(determinant) < 0.00000001) return surface_normal;
	vec3 gradient = sign(determinant) * (dFdx(height) * r1 + dFdy(height) * r2);
	return normalize(abs(determinant) * surface_normal - gradient * strength);
}

// Cotangent frame from real projected UVs; handles mirrored/vertical bank faces.
vec3 terrain_texture_normal(vec3 surface_normal, vec3 view_position, vec2 detail_uv, vec3 map_normal, float strength) {
	vec3 dp1 = dFdx(view_position);
	vec3 dp2 = dFdy(view_position);
	vec2 duv1 = dFdx(detail_uv);
	vec2 duv2 = dFdy(detail_uv);
	vec3 p2 = cross(dp2, surface_normal);
	vec3 p1 = cross(surface_normal, dp1);
	vec3 tangent = p2 * duv1.x + p1 * duv2.x;
	vec3 bitangent = p2 * duv1.y + p1 * duv2.y;
	float magnitude = max(dot(tangent, tangent), dot(bitangent, bitangent));
	if (magnitude < 0.00000001) return surface_normal;
	float scale = inversesqrt(magnitude);
	return normalize((tangent * map_normal.x + bitangent * map_normal.y) * scale * strength + surface_normal * map_normal.z);
}

float terrain_grain_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float terrain_grain(vec3 p) {
	vec3 relief_cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float low = mix(mix(terrain_grain_hash(relief_cell), terrain_grain_hash(relief_cell + vec3(1.0, 0.0, 0.0)), f.x),
		mix(terrain_grain_hash(relief_cell + vec3(0.0, 1.0, 0.0)), terrain_grain_hash(relief_cell + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float high = mix(mix(terrain_grain_hash(relief_cell + vec3(0.0, 0.0, 1.0)), terrain_grain_hash(relief_cell + vec3(1.0, 0.0, 1.0)), f.x),
		mix(terrain_grain_hash(relief_cell + vec3(0.0, 1.0, 1.0)), terrain_grain_hash(relief_cell + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(low, high, f.z);
}
