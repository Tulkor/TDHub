shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://assets/shaders/terrain_variation.gdshaderinc"
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 stone_tint : source_color = vec4(0.55,0.57,0.48,1.0);
uniform vec4 ground_tint : source_color = vec4(0.38,0.45,0.28,1.0);
uniform float brightness = 0.7;
uniform float foot_height = 1.8;
varying vec3 world;
varying vec3 up;
void vertex() {
	world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	up = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 weights = pow(abs(up),vec3(4.0));
	weights /= max(dot(weights,vec3(1.0)),.001);
	vec3 p = world*.24;
	vec3 stone = tv_sample(rock,p.zy,0.0)*weights.x + tv_sample(rock,p.xz,0.0)*weights.y + tv_sample(rock,p.xy,0.0)*weights.z;
	float gray = dot(stone,vec3(.299,.587,.114));
	float variation = sin(world.x*.73)*sin(world.z*.61)*.12;
	float foot = 1.0-smoothstep(.05,foot_height,world.y+variation);
	float grass = max(foot,smoothstep(.68,.94,up.y)*.45);
	vec3 soil = tv_sample(ground,world.xz*.4,0.0)*ground_tint.rgb;
	ALBEDO = mix(mix(stone,vec3(gray),.65)*stone_tint.rgb,soil,grass)*brightness;
	ROUGHNESS = .94;
	SPECULAR = .16;
}
