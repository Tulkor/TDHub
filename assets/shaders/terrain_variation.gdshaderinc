// Zwei versetzte/gedrehte Varianten, weich über unregelmäßige Weltflecken gemischt.
// Identische UVs/Gewichte für Farbe und Materialdaten; explizite Ableitungen verhindern Mip-Nähte.
float tv_hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float tv_noise(vec2 p) {
	vec2 tv_grid=floor(p);
	vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(tv_hash(tv_grid),tv_hash(tv_grid+vec2(1,0)),f.x),mix(tv_hash(tv_grid+vec2(0,1)),tv_hash(tv_grid+vec2(1,1)),f.x),f.y);
}
vec2 tv_state(vec2 uv) {
	float variant=tv_noise(uv*.19+vec2(7.3,19.7))*8.0;
	return vec2(floor(variant),smoothstep(.18,.82,fract(variant)));
}
mat2 tv_rotation(float index) {
	float angle=floor(tv_hash(vec2(index,3.7))*4.0)*1.570796327;
	return mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
}
float tv_scale(float index) { return .85+.3*tv_hash(vec2(index,11.2)); }
vec2 tv_offset(float index) { return vec2(tv_hash(vec2(index,4.9)),tv_hash(vec2(index,8.1)))*37.0; }
vec3 tv_variant(sampler2D tex,vec2 uv,float index,float blur) {
	mat2 rotation=tv_rotation(index);
	float scale=tv_scale(index);
	return textureGrad(tex,rotation*uv*scale+tv_offset(index),rotation*dFdx(uv)*scale*exp2(blur),rotation*dFdy(uv)*scale*exp2(blur)).rgb;
}
vec3 tv_sample(sampler2D tex,vec2 uv,float blur) {
	vec2 state=tv_state(uv);
	return mix(tv_variant(tex,uv,state.x,blur),tv_variant(tex,uv,state.x+1.0,blur),state.y);
}
vec3 tv_normal(sampler2D tex,vec2 uv,float blur) {
	vec2 state=tv_state(uv);
	vec3 a=tv_variant(tex,uv,state.x,blur)*2.0-1.0;
	vec3 b=tv_variant(tex,uv,state.x+1.0,blur)*2.0-1.0;
	a.xy=transpose(tv_rotation(state.x))*a.xy;
	b.xy=transpose(tv_rotation(state.x+1.0))*b.xy;
	return normalize(mix(a,b,state.y))*0.5+0.5;
}
