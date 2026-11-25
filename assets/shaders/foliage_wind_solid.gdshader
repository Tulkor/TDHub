// Höhengewichtung hält Wurzeln fest. Phase aus Weltposition, kein Zufall aus der Spiellogik.
shader_type spatial;
#define WIND_SOLID
render_mode cull_disabled, diffuse_lambert_wrap;
#include "res://assets/shaders/foliage_wind.gdshaderinc"
