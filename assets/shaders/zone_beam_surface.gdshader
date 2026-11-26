// Surface-only zone curtains: alpha compositing preserves the floor behind the wall.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#define ZONE_SURFACE_ONLY
#include "res://assets/shaders/zone_beam.gdshaderinc"
