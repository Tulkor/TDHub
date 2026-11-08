// Fahnentuch (Shopping Maul, Plaza-Art-déco): Quad mit linker Kante am Mast, weht leicht.
// Königsblau mit weißem Rand oben und unten und einem schmalen Messingstreifen am Mast.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform vec4 cloth : source_color = vec4(0.19, 0.31, 0.56, 1.0);
uniform vec4 trim : source_color = vec4(0.94, 0.94, 0.92, 1.0);
uniform vec4 brass : source_color = vec4(0.79, 0.64, 0.35, 1.0);
/// Ausschlag des Wehens (in Tuchlängen) und Geschwindigkeit
uniform float wave = 0.09;
uniform float speed = 2.2;

varying vec2 uv_;

void vertex() {
	uv_ = UV;
	float phase = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.28;
	float k = VERTEX.x + 0.5;
	VERTEX.z += sin(TIME * speed + k * 5.5 + phase) * wave * k;
	VERTEX.y -= k * k * 0.06;
}

void fragment() {
	vec3 col = cloth.rgb;
	float band = step(uv_.y, 0.13) + step(0.87, uv_.y);
	col = mix(col, trim.rgb, clamp(band, 0.0, 1.0));
	col = mix(col, brass.rgb, step(uv_.x, 0.06));
	// Falten: leichtes Hell-Dunkel längs des Tuchs
	col *= 0.85 + 0.15 * sin(uv_.x * 18.0 + TIME * speed);
	ALBEDO = col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
