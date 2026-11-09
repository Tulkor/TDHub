// Hoch: zusätzliche, dezente Brechung. Transparente Objekte fehlen im Bildschirm-Abbild.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#define WATER_DEPTH
#define WATER_REFRACT
#include "water_surface.gdshaderinc"
