// Identische Materialinseln auf ebenem Bollwerk-Boden und den anliegenden Bergfüßen.
// Integer-Hash: gleiche Masken auch in unterschiedlich optimierten Gelände-Shadern.
float hd_ground_hash(ivec2 grid) {
	uvec2 bits=uvec2(grid);
	uint value=(bits.x*1597334677u)^(bits.y*3812015801u);
	value=(value^(value>>16u))*2246822519u;
	value^=value>>13u;
	return float(value&16777215u)/16777216.0;
}
float hd_ground_noise(vec2 at) {
	ivec2 grid=ivec2(floor(at));
	vec2 blend=fract(at); blend=blend*blend*(3.0-2.0*blend);
	return mix(mix(hd_ground_hash(grid),hd_ground_hash(grid+ivec2(1,0)),blend.x),
		mix(hd_ground_hash(grid+ivec2(0,1)),hd_ground_hash(grid+ivec2(1,1)),blend.x),blend.y);
}
vec3 hd_ground_masks(vec2 at) {
	vec2 warp=vec2(hd_ground_noise(at*.065+vec2(17,31)),hd_ground_noise(at*.073+vec2(43,7)))-.5;
	vec2 area=at+warp*12.0;
	return vec3(smoothstep(.36,.61,hd_ground_noise(area*.115+vec2(11,37))),
		smoothstep(.35,.65,hd_ground_noise(area*.18+vec2(29,3))),
		smoothstep(.38,.72,hd_ground_noise(area*.065+vec2(5,83))));
}
vec3 hd_ground_colors(vec3 slab,vec3 earth,vec3 scree,vec3 masks) {
	float slab_gray=dot(slab,vec3(.299,.587,.114));
	float scree_gray=dot(scree,vec3(.299,.587,.114));
	vec3 bedrock=mix(slab,vec3(slab_gray),.8)*vec3(.33,.37,.44);
	vec3 loose=mix(scree,vec3(scree_gray),.65)*vec3(.46,.47,.45);
	vec3 soil=earth*mix(vec3(.45,.33,.235),vec3(.17,.16,.15),masks.z);
	return mix(soil,mix(bedrock,loose,masks.y),masks.x);
}
vec3 hd_ground_at(sampler2D slab_tex,sampler2D earth_tex,sampler2D scree_tex,vec2 at) {
	return hd_ground_colors(tv_sample(slab_tex,at*.28,0.0),tv_sample(earth_tex,at*.48,0.0),
		tv_sample(scree_tex,at*.37+vec2(9.7,3.2),0.0),hd_ground_masks(at));
}

// Gemeinsame Materialdaten verhindern Beleuchtungskanten zwischen Ebene und Bergfuß.
void hd_ground_surface(sampler2D slab_tex,sampler2D normal_tex,sampler2D rough_tex,
 sampler2D earth_tex,sampler2D earth_normal_tex,sampler2D earth_spec_tex,
 sampler2D scree_tex,sampler2D scree_normal_tex,sampler2D scree_spec_tex,vec2 at,
 out vec3 color,out vec3 normal_data,out float depth,out float roughness,out float specular) {
 vec3 masks=hd_ground_masks(at);
 vec2 uv=at*.28;
 vec2 earth_uv=at*.48;
 vec2 scree_uv=at*.37+vec2(9.7,3.2);
 color=hd_ground_colors(tv_sample(slab_tex,uv,0.0),tv_sample(earth_tex,earth_uv,0.0),tv_sample(scree_tex,scree_uv,0.0),masks);
 vec3 stone_n=tv_normal(normal_tex,uv,0.0)*2.0-1.0;
 vec3 earth_n=tv_normal(earth_normal_tex,earth_uv,0.0)*2.0-1.0;
 vec3 scree_n=tv_normal(scree_normal_tex,scree_uv,0.0)*2.0-1.0;
 normal_data=normalize(mix(earth_n,normalize(mix(stone_n,scree_n,masks.y)),masks.x))*.5+.5;
 depth=mix(.35,.8,masks.x);
 float rock_r=clamp(tv_sample(rough_tex,uv,0.0).r,.7,.97);
 float earth_s=tv_sample(earth_spec_tex,earth_uv,0.0).r;
 float scree_s=tv_sample(scree_spec_tex,scree_uv,0.0).r;
 roughness=mix(mix(.97,.87,masks.z),mix(rock_r,.98-scree_s*.3,masks.y),masks.x);
 specular=mix(mix(earth_s,.28,masks.z*.65),mix(.24,scree_s,masks.y),masks.x);
}
float hd_ground_modulation(vec2 at) {
 return (.9+hd_ground_noise(at*.045)*.2)*(.96+hd_ground_hash(ivec2(floor(at*48.0)))*.08);
}
