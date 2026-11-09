// Mittel: Tiefenfarbe und Kontaktschaum, ohne Bildschirmkopie für Brechung.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#define WATER_DEPTH
#include "water_surface.gdshaderinc"
