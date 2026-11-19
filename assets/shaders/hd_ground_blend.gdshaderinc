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
// Nutzungskarte (einmal gebacken, hd_vegetation_ground.gd): R Siedlung/Trittfläche, G Nässe (Senken,
// Rinnen neben dem Pflaster), B Hangschutt am Fuß steiler Flächen, A Platzpflaster.
uniform sampler2D ground_use : filter_linear, repeat_disable;
uniform vec4 ground_use_bounds = vec4(-234.0,-234.0,468.0,468.0);
uniform bool ground_use_enabled = false;
vec4 hd_ground_use(vec2 at) {
	if (!ground_use_enabled) return vec4(0.0);
	vec2 uv=(at-ground_use_bounds.xy)/ground_use_bounds.zw;
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return vec4(0.0);
	return texture(ground_use,uv);
}
// Sedimentlogik statt Rauschflecken (Lukas 2026-11-19): Fels nur auf den Kuppen (dieselbe Maske hebt dort
// das Relief), Schutt als Saum darum und am Hangfuß, feuchte Erde in Senken und Rinnen, in der Stadt
// festgetretener Lehm mit Kies, auf Plätzen Pflaster. x Fels, y Kies/Schutt, z Nässe, w Siedlung.
// Ungeglättetes Felsfeld (wie in hd_ground_masks), damit der Schuttsaum breit und weich ausläuft.
float hd_ground_rock_field(vec2 at) {
	vec2 warp=vec2(hd_ground_noise(at*.065+vec2(17,31)),hd_ground_noise(at*.073+vec2(43,7)))-.5;
	return hd_ground_noise((at+warp*12.0)*.115+vec2(11,37));
}
vec4 hd_ground_weights(vec3 masks,vec4 use,vec2 at) {
	float settled=use.r;
	float grain=hd_ground_noise(at*.85+vec2(3.0,7.0));
	float rock=smoothstep(.5,.93,masks.x)*(1.0-settled);
	float raw=hd_ground_rock_field(at);
	float fringe=smoothstep(.28,.5,raw)*(1.0-smoothstep(.5,.66,raw))*(.45+.35*grain);
	float gravel=clamp(fringe*(.45+masks.y*.4)*(1.0-settled)+use.b*(.7+.3*grain)+settled*(.22+.22*grain),0.0,1.0);
	float wet=clamp(masks.z*.55*(1.0-settled*.7)*(1.0-rock)+use.g*(.55+.45*grain),0.0,1.0);
	return vec4(rock,gravel,wet,settled);
}
float hd_ground_hash2(vec2 p){return hd_ground_hash(ivec2(floor(p)));}
// Unregelmäßiges Kopfsteinpflaster für Plätze: Reihen versetzt, Steine verschieden hell, dunkle Fugen.
vec3 hd_ground_setts(vec2 at,out float joint) {
	vec2 tile=at*vec2(2.1,2.6);
	tile.x+=hd_ground_hash2(vec2(0.0,floor(tile.y)))*.9;
	vec2 f=fract(tile);
	float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	joint=1.0-smoothstep(.03,.11,edge);
	float shade=hd_ground_hash2(tile);
	return mix(vec3(.21,.205,.2)*(.72+shade*.5),vec3(.06,.055,.05),joint);
}
vec3 hd_ground_compose(vec3 slab,vec3 earth,vec3 scree,vec4 w,float paved,vec2 at) {
	float slab_gray=dot(slab,vec3(.299,.587,.114));
	float scree_gray=dot(scree,vec3(.299,.587,.114));
	float earth_gray=dot(earth,vec3(.299,.587,.114));
	vec3 bedrock=mix(slab,vec3(slab_gray),.8)*vec3(.33,.37,.44);
	vec3 loose=mix(scree,vec3(scree_gray),.6)*vec3(.47,.46,.43);
	// Lehm nicht mehr orange: erdig-grau, festgetreten noch etwas heller und grauer.
	vec3 loam=mix(earth,vec3(earth_gray),.45)*vec3(.36,.315,.27);
	vec3 trodden=mix(earth,vec3(earth_gray),.72)*vec3(.42,.395,.36);
	// Weite, schwache Tonwechsel (Humus, Lehm, Staub) statt harter Inseln.
	float tone=hd_ground_noise(at*.021+vec2(71.0,19.0));
	loam*=mix(vec3(.9,.92,.95),vec3(1.08,1.04,.98),tone);
	vec3 mud=mix(earth,vec3(earth_gray),.4)*vec3(.15,.135,.12);
	vec3 soil=mix(loam,trodden,w.w);
	soil=mix(soil,mud,w.z*(1.0-w.y*.55));
	vec3 color=mix(soil,mix(loose,loose*.75,w.z),w.y*(1.0-w.z*.35));
	color=mix(color,bedrock,w.x);
	if (paved>.002) {
		float joint;
		vec3 setts=hd_ground_setts(at,joint);
		color=mix(color,setts*mix(1.0,.7,w.z),paved);
	}
	return color;
}
vec3 hd_ground_colors(vec3 slab,vec3 earth,vec3 scree,vec3 masks) {
	return hd_ground_compose(slab,earth,scree,hd_ground_weights(masks,vec4(0.0),vec2(0.0)),0.0,vec2(0.0));
}
vec3 hd_ground_at(sampler2D slab_tex,sampler2D earth_tex,sampler2D scree_tex,vec2 at) {
	vec4 use=hd_ground_use(at);
	return hd_ground_compose(tv_sample(slab_tex,at*.28,0.0),tv_sample(earth_tex,at*.48,0.0),
		tv_sample(scree_tex,at*.37+vec2(9.7,3.2),0.0),hd_ground_weights(hd_ground_masks(at),use,at),use.a,at);
}

// Gemeinsame Materialdaten verhindern Beleuchtungskanten zwischen Ebene und Bergfuß.
void hd_ground_surface(sampler2D slab_tex,sampler2D normal_tex,sampler2D rough_tex,
 sampler2D earth_tex,sampler2D earth_normal_tex,sampler2D earth_spec_tex,
 sampler2D scree_tex,sampler2D scree_normal_tex,sampler2D scree_spec_tex,vec2 at,
 out vec3 color,out vec3 normal_data,out float depth,out float roughness,out float specular) {
 vec4 use=hd_ground_use(at);
 vec4 w=hd_ground_weights(hd_ground_masks(at),use,at);
 vec2 uv=at*.28;
 vec2 earth_uv=at*.48;
 vec2 scree_uv=at*.37+vec2(9.7,3.2);
 color=hd_ground_compose(tv_sample(slab_tex,uv,0.0),tv_sample(earth_tex,earth_uv,0.0),tv_sample(scree_tex,scree_uv,0.0),w,use.a,at);
 vec3 stone_n=tv_normal(normal_tex,uv,0.0)*2.0-1.0;
 vec3 earth_n=tv_normal(earth_normal_tex,earth_uv,0.0)*2.0-1.0;
 vec3 scree_n=tv_normal(scree_normal_tex,scree_uv,0.0)*2.0-1.0;
 vec3 n=normalize(mix(mix(earth_n,scree_n,w.y),stone_n,w.x));
 // Nasse Erde ist glatter: Relief flacher, Glanz höher.
 n=normalize(mix(n,vec3(0.0,0.0,1.0),w.z*.55*(1.0-w.y)));
 float joint=0.0;
 if (use.a>.002) {
  hd_ground_setts(at,joint);
  n=normalize(mix(n,normalize(stone_n+vec3(0.0,0.0,1.2)),use.a));
 }
 normal_data=n*.5+.5;
 depth=mix(mix(.35,.55,w.y),.8,w.x)*(1.0-w.z*.4);
 float rock_r=clamp(tv_sample(rough_tex,uv,0.0).r,.7,.97);
 float earth_s=tv_sample(earth_spec_tex,earth_uv,0.0).r;
 float scree_s=tv_sample(scree_spec_tex,scree_uv,0.0).r;
 roughness=mix(mix(.95,.98-scree_s*.3,w.y),rock_r,w.x);
 roughness=mix(roughness,.58,w.z*(1.0-w.x));
 roughness=mix(roughness,mix(.78,.97,joint),use.a);
 specular=mix(mix(earth_s,scree_s,w.y),.24,w.x);
 specular=mix(specular,.42,w.z*(1.0-w.x));
 specular=mix(specular,mix(.3,.12,joint),use.a);
}
float hd_ground_modulation(vec2 at) {
 return (.9+hd_ground_noise(at*.045)*.2)*(.96+hd_ground_hash(ivec2(floor(at*48.0)))*.08);
}
