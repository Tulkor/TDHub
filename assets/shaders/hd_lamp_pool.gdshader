shader_type spatial;
// Warmer Lichtkegel unter Laternen, additiv und ohne echte Lichtquelle (Lukas 2026-11-19: nachts zu dunkel).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0,0.62,0.3,1.0);
uniform float strength = 0.0;
void fragment(){
 float d=length(UV-vec2(.5))*2.0;
 float pool=pow(clamp(1.0-d,0.0,1.0),2.6);
 ALBEDO=tint.rgb*pool*strength;
 ALPHA=1.0;
}
