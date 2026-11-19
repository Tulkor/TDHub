shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform vec4 slate_color : source_color = vec4(0.12,0.16,0.23,1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 n=abs(normalize(world_normal));
	vec2 uv=n.y>0.72?world_position.xz:(n.x>n.z?world_position.zy:world_position.xy);
	vec2 tile=uv*vec2(1.65,2.4);
	tile.x+=mod(floor(tile.y),2.0)*0.5;
	vec2 cell=floor(tile);vec2 f=fract(tile);
	float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	float seam=1.0-smoothstep(0.012,0.038,edge);
	float variation=0.86+terrain_grain_hash(vec3(cell,2.0))*0.25;
	float weather=terrain_grain(world_position*0.38);
	float height=(1.0-seam)*0.013+f.y*0.009;
	ALBEDO=slate_color.rgb*variation*mix(0.72,1.0,weather)*(1.0-seam*0.58);
	NORMAL=terrain_relief_normal(NORMAL,VERTEX,height,0.65);
	METALLIC=0.17;
	ROUGHNESS=mix(0.5,0.76,weather)+seam*0.1;
	SPECULAR=0.36;
}
