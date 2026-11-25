// Deckende Fassung von ground.gdshader (ohne ALPHA): für Böden mit ground_alpha = 1, z. B. Waldboden.
// Map-Boden: zwei Grasarten und Erde, überblendet.
// Erde liegt dort, wo die Splat-Textur es sagt (Laufweg, Spawn, Ziel, Checkpoints, "_"-Felder),
// die Ränder werden mit Rauschen ausgefranst. Die beiden Grasarten wechseln großflächig per Rauschen.
shader_type spatial;
#define GROUND_OPAQUE
#include "res://assets/shaders/terrain_variation.gdshaderinc"
render_mode blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
#include "res://assets/shaders/ground.gdshaderinc"
