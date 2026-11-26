// Gemeinsame Bewuchsmaske auf Original-Boden und Bergmesh; keine zusätzlichen Bodenflächen.
uniform sampler2D vegetation_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D vegetation_soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D vegetation_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 vegetation_bounds = vec4(-192.0,-192.0,384.0,384.0);
uniform bool vegetation_enabled = false;
vec4 hd_vegetation_surface(vec2 at) {
	if (!vegetation_enabled) return vec4(0.0);
	vec2 uv=(at-vegetation_bounds.xy)/vegetation_bounds.zw;
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return vec4(0.0);
	vec4 coverage=texture(vegetation_mask,uv);
	float weight=smoothstep(0.015,0.92,min(coverage.r+coverage.g,1.0));
	float path=smoothstep(.035,.95,coverage.b);
	if (max(weight,path)<0.002) return vec4(0.0);
	float noise=hd_ground_noise(at*.55+vec2(41.0,13.0));
	vec3 vegetation=vec3(0.0);
	if (weight>.002) {
		float grass=smoothstep(.12,.85,coverage.g/max(coverage.r+coverage.g,.001)+(noise-.5)*.24);
		vec3 dirt_tex=tv_sample(vegetation_soil,at*.53,0.0);
		// Waldboden/Humus dunkel und erdig statt orange Flecken unter jedem Baum (Lukas 2026-11-19).
		vec3 dirt=mix(dirt_tex,vec3(dot(dirt_tex,vec3(.299,.587,.114))),.5)*vec3(.27,.235,.2);
		vec3 meadow=tv_sample(vegetation_grass,at*.42,0.0)*vec3(.32,.38,.30);
		vegetation=mix(dirt,meadow,grass)*(.92+noise*.16);
	}
	if (path<.002) return vec4(vegetation,weight);
	// Verdichtete Erde statt aufgesetztem Streifen. Breite Störung und feines Korn ohne neue Sampler.
	float packed=smoothstep(.12,.95,coverage.a);
	vec3 track_tex=tv_sample(vegetation_soil,at*.62,0.0);
	// Festgetretener Weg: staubig grau-braun statt orange Erde (Lukas 2026-11-19).
	track_tex=mix(track_tex,vec3(dot(track_tex,vec3(.299,.587,.114))),.6);
	vec3 track=track_tex*mix(vec3(.4,.37,.33),vec3(.55,.52,.47),packed);
	track*=.91+noise*.18+hd_ground_noise(at*3.7)*.07;
	float combined=weight+path-weight*path;
	return vec4((vegetation*weight*(1.0-path)+track*path)/max(combined,.001),combined);
}
