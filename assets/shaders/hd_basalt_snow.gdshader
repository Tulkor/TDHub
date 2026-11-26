// Fotografisches CC0-Felsmaterial (Quelle im Texturordner), Weltprojektion + Schnee.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
#include "res://assets/shaders/terrain_variation.gdshaderinc"
#include "res://assets/shaders/hd_ground_blend.gdshaderinc"
#include "res://assets/shaders/hd_vegetation_ground.gdshaderinc"
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_specular : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_scale = 0.085;
uniform float relief_strength = 0.16;
// Wider features and softer mip sampling keep the mountains calm at game distance.
uniform float detail_softness = 1.5;
uniform float albedo_contrast = 0.32;
uniform float stone_brightness = 1.0;
uniform vec4 snow_color : source_color = vec4(0.78,0.84,0.86,1.0);
uniform float snow_line = 25.0;
uniform float snow_amount = 0.8;
uniform float snow_slope_min = 0.18;
uniform float world_height_offset = 0.0;
uniform sampler2D foot_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_scree : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_soil_specular : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_scree_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foot_scree_specular : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float foot_blend = 0.0;
varying vec3 rock_world;
varying vec3 rock_normal;
float hash2(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);
}
void vertex() {
 rock_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 rock_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 TANGENT=normalize((inverse(MODEL_MATRIX)*vec4(1,0,0,0)).xyz);
 BINORMAL=normalize((inverse(MODEL_MATRIX)*vec4(0,0,1,0)).xyz);
}
void fragment() {
 vec3 n=normalize(rock_normal);
 vec3 w=pow(abs(n),vec3(4.0)); w/=max(w.x+w.y+w.z,0.001);
 vec3 p=rock_world*rock_scale;
 vec3 ax=tv_sample(rock_albedo,p.zy,detail_softness);
 vec3 ay=tv_sample(rock_albedo,p.xz,detail_softness);
 vec3 az=tv_sample(rock_albedo,p.xy,detail_softness);
 vec3 scanned=ax*w.x+ay*w.y+az*w.z;
 float luminance=dot(scanned,vec3(0.299,0.587,0.114));
 float macro=noise2(rock_world.xz*0.027);
 float tone=clamp(0.19+(luminance*1.4-0.19)*albedo_contrast,0.12,0.27);
 vec3 stone=vec3(tone)*vec3(0.77,0.82,0.88)*(0.94+macro*0.12)*stone_brightness;
 float altitude=rock_world.y-world_height_offset;
 float foot_weight=(1.0-smoothstep(.25,5.0,altitude+(macro-.5)*1.2*smoothstep(.15,1.0,altitude)))*foot_blend;
 vec3 foot_normal_data=vec3(.5,.5,1.0);
 float foot_depth=0.0;
 float foot_rough=.97;
 float foot_spec=.12;
 if(foot_weight>.001){
  vec3 foot;
  hd_ground_surface(foot_albedo,foot_normal,foot_roughness,foot_soil,foot_soil_normal,foot_soil_specular,
   foot_scree,foot_scree_normal,foot_scree_specular,rock_world.xz,foot,foot_normal_data,foot_depth,foot_rough,foot_spec);
  stone=mix(stone,foot,foot_weight);
 }
 vec4 cover=hd_vegetation_surface(rock_world.xz);
 cover.a*=smoothstep(.2,.5,n.y);
 stone=mix(stone,cover.rgb,cover.a);
 float drift=(noise2(rock_world.xz*0.19)-0.5)*4.2;
 float summit=smoothstep(snow_line-1.0,snow_line+3.5,altitude+drift);
 float dust=smoothstep(snow_line-9.0,snow_line-3.0,altitude+drift)*smoothstep(0.64,0.86,macro)*0.4;
 float snow=max(summit,dust)*smoothstep(snow_slope_min,min(snow_slope_min+0.44,1.0),n.y)*snow_amount;
 vec3 nx=tv_normal(rock_normal_map,p.zy,detail_softness)*2.0-1.0;
 vec3 ny=tv_normal(rock_normal_map,p.xz,detail_softness)*2.0-1.0;
 vec3 nz=tv_normal(rock_normal_map,p.xy,detail_softness)*2.0-1.0;
 vec3 bump=vec3(0,nx.y,nx.x)*w.x+vec3(ny.x,0,ny.y)*w.y+vec3(nz.x,nz.y,0)*w.z;
 bump-=n*dot(n,bump);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(n+bump*relief_strength*(1.0-snow)*(1.0-cover.a*.75)*(1.0-foot_weight)),0.0)).xyz);
 if(foot_weight>.001){
  NORMAL_MAP=foot_normal_data;
  NORMAL_MAP_DEPTH=mix(foot_depth,.22,cover.a)*foot_weight*(1.0-snow);
 }
 float rough=tv_sample(rock_roughness,p.zy,detail_softness).r*w.x+tv_sample(rock_roughness,p.xz,detail_softness).r*w.y+tv_sample(rock_roughness,p.xy,detail_softness).r*w.z;
 ALBEDO=mix(stone,snow_color.rgb*(0.95+macro*0.08),snow);
 ROUGHNESS=mix(mix(mix(.78+rough*.17,foot_rough,foot_weight),.97,cover.a),.97,snow);
 float specular=tv_sample(rock_specular,p.zy,detail_softness).r*w.x+tv_sample(rock_specular,p.xz,detail_softness).r*w.y+tv_sample(rock_specular,p.xy,detail_softness).r*w.z;
 METALLIC=0.0; SPECULAR=mix(mix(mix(specular,foot_spec,foot_weight),.12,cover.a),.28,snow);
 ALBEDO*=mix(1.0,hd_ground_modulation(rock_world.xz),foot_weight);
}
