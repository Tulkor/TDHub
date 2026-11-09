// Nur hohe Gem-Stufen auf Grafik Hoch.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
#define GEM_REFRACT
#include "gem_surface.gdshaderinc"
