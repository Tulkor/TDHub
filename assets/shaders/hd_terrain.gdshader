shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/terrain_variation.gdshaderinc"
#include "res://assets/shaders/hd_ground_blend.gdshaderinc"
#include "res://assets/shaders/hd_vegetation_ground.gdshaderinc"
uniform int surface = 0;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree_specular : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 TANGENT=normalize((inverse(MODEL_MATRIX)*vec4(1.0,0.0,0.0,0.0)).xyz);
 BINORMAL=normalize((inverse(MODEL_MATRIX)*vec4(0.0,0.0,1.0,0.0)).xyz);
}
void fragment(){
 vec3 rock=vec3(0.0);
 if(surface==0){
  hd_ground_surface(albedo_map,normal_map,rough_map,soil_map,soil_normal,soil_specular,
   scree_map,scree_normal,scree_specular,world,ALBEDO,NORMAL_MAP,NORMAL_MAP_DEPTH,ROUGHNESS,SPECULAR);
 } else {
  vec2 uv=world*.28;
  rock=tv_sample(albedo_map,uv,0.0);
  float stone_gray=dot(rock,vec3(.299,.587,.114));
  ALBEDO=mix(rock,vec3(stone_gray),.8)*vec3(.33,.37,.44);
  NORMAL_MAP=tv_normal(normal_map,uv,0.0);
  NORMAL_MAP_DEPTH=.8;
  ROUGHNESS=clamp(tv_sample(rough_map,uv,0.0).r,.7,.97);
  SPECULAR=.24;
 }
 if(surface==1){
  vec2 tile=world*vec2(1.35,2.0);
  tile.x+=mod(floor(tile.y),2.0)*0.5;
  vec2 f=fract(tile);
  float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
  float joint=1.0-smoothstep(0.025,0.085,edge);
  float shade=hash(floor(tile));
  ALBEDO=mix(vec3(0.075,0.09,0.115)*(0.75+shade*0.5)+rock*0.06,vec3(0.022,0.02,0.018),joint);
  NORMAL_MAP_DEPTH=0.3;
  NORMAL=normalize(NORMAL+vec3(dFdx(edge),dFdy(edge),0.0)*1.8);
  ROUGHNESS=mix(0.76,0.97,joint);
  SPECULAR=mix(0.33,0.12,joint);
 }
 if(surface==2){
  ALBEDO=tv_sample(soil_map,world*0.55,0.0)*vec3(0.27,0.25,0.24);
  NORMAL_MAP=tv_normal(soil_normal,world*.55,0.0);
  NORMAL_MAP_DEPTH=0.25;
  ROUGHNESS=0.96;
  SPECULAR=0.13;
 }
 if(surface==0){
  vec4 cover=hd_vegetation_surface(world);
  ALBEDO=mix(ALBEDO,cover.rgb,cover.a);
  NORMAL_MAP_DEPTH=mix(NORMAL_MAP_DEPTH,.22,cover.a);
  ROUGHNESS=mix(ROUGHNESS,.97,cover.a);
  SPECULAR=mix(SPECULAR,.12,cover.a);
 }

 if(surface>0){
  float edge=length((UV-vec2(0.5))*2.0);
  float irregular=surface==2?sin(world.x*3.1)*sin(world.y*2.8)*0.08:0.0;
  ALPHA=1.0-smoothstep(0.82+irregular,1.0+irregular,edge);
  ALPHA_SCISSOR_THRESHOLD=0.4;
 }
 if(surface==0) ALBEDO*=hd_ground_modulation(world);
 else ALBEDO*=(.9+tv_noise(world*.045)*.2)*(.96+hash(floor(world*48.0))*.08);
}
