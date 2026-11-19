shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://assets/shaders/terrain_variation.gdshaderinc"
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.5,0.45,0.35,1.0);
uniform float irregularity = 0.0;
uniform float opacity = 0.5;
uniform float texture_scale = 0.9;
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	float grain = sin(world.x*4.1+sin(world.y*2.7))*sin(world.y*3.3)*0.045;
	float side = abs(UV.x*2.0-1.0);
	side += irregularity*(tv_noise(world*.65)-.35)*.65;
	float edge = 1.0-smoothstep(0.40+grain,1.0,side);
	float ends = smoothstep(0.0,0.08,UV.y)*smoothstep(1.0,0.92,UV.y);
	ALBEDO = tv_sample(soil,world*texture_scale,0.0)*tint.rgb*(.9+.2*tv_noise(world*.08));
	ALPHA = edge*ends*opacity*mix(1.0,smoothstep(.18,.7,tv_noise(world*.3)),irregularity);
	ROUGHNESS = 0.97;
	SPECULAR = 0.12;
}
