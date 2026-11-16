// Gemeinsamer Teil von neon_floor.gdshader (unbeleuchtet) und neon_floor_lit.gdshader (beleuchtet).
#include "res://assets/shaders/light_profiles.gdshaderinc"
/// 1 = blockiertes Feld, ein Pixel pro Feld
uniform sampler2D blocked : filter_nearest, repeat_disable;
uniform vec2 cells = vec2(74.0, 74.0);
uniform float cell = 0.5;
/// Abstand der Gitterlinien in Feldern (2 = eine Towerbreite)
uniform float grid_cells = 2.0;
uniform vec4 line_color : source_color = vec4(1.0, 0.36, 0.86, 1.0);
uniform vec4 edge_color : source_color = vec4(0.75, 0.4, 1.0, 1.0);
uniform vec4 floor_color : source_color = vec4(0.09, 0.03, 0.22, 1.0);
uniform float floor_alpha = 0.4;
uniform float line_energy = 1.0;
uniform float edge_energy = 2.6;
/// Jede wievielte Gitterlinie hell ist; die übrigen werden mit minor_energy/minor_alpha gedämpft
uniform float major_every = 5.0;
/// Ursprung des Gitters in Feldern (erstes freies Feld), damit die hellen Linien am Feldrand liegen
uniform vec2 grid_origin = vec2(0.0);
/// helle Linien über der Glow-Schwelle, damit sie wie der Außenrand leicht scheinen
uniform float major_energy = 2.0;
uniform float minor_energy = 0.5;
uniform float minor_alpha = 0.6;
/// Raster der einzelnen Felder (halbe Towerbreite, Tower lassen sich darauf versetzen), noch dunkler
uniform float cell_energy = 0.42;
uniform float cell_alpha = 0.5;
/// Sperrzone um Spawn, Ziel und Checkpoints: durchsichtig rot mit Neonrand
uniform vec4 zone_color : source_color = vec4(1.0, 0.12, 0.22, 1.0);
uniform float zone_alpha = 0.34;
uniform float zone_edge_energy = 3.0;
/// Linienbreite in Einheiten (1 = Towerbreite)
uniform float line_width = 0.014;
uniform float halo_width = 0.08;
/// zusätzliche feine Linien je Feld (Map-Editor), 0 = aus
uniform float fine_strength = 0.0;
/// Anteil des weißen Kerns der Linien (Neon 0.7, gemalte Linien 0)
uniform float core_white = 0.7;
/// Deckkraft der hellen Hauptlinien
uniform float major_alpha = 1.0;
/// 1 = Hauptlinien doppelt (zwei dünne parallele Linien, Art déco)
uniform float major_double = 0.0;
/// Helligkeit schlichter Felder (B-Kanal der Maske)
uniform float plain_shade = 1.0;
// Schachmuster: jede zweite Kachel (grid_cells x grid_cells Felder) um diesen Anteil dunkler (Shopping Maul)
uniform float checker = 0.0;
/// Rauten an den Kreuzungen der Hauptlinien, halbe Diagonale in Einheiten (0 = keine)
uniform float diamond_size = 0.0;
/// Marmor-Adern im Boden (0 = glatt); Farbe und Deckkraft der Adern (A)
uniform float marble = 0.0;
uniform vec4 vein_color : source_color = vec4(0.4, 0.5, 0.48, 0.25);
/// Fugen: Feld- und Towerraster in dieser Farbe statt line_color (A = 0: line_color), kein Metall
uniform vec4 joint_color : source_color = vec4(0.0);
/// Zweiter Bodenbelag je Feld (R der Maske, z. B. Maul: Gänge zwischen den Gebieten in Petrol)
uniform sampler2D paving : filter_nearest, repeat_disable, hint_default_black;
uniform vec4 paving_color : source_color = vec4(0.06, 0.2, 0.21, 1.0);
/// Bodenleuchten in den Kreuzungen der Hauptlinien: Helligkeit des Kerns (0 = keine)
uniform float floor_lamp = 0.0;
uniform vec4 lamp_color : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform vec4 lamp_silver_color : source_color = vec4(0.78, 0.87, 1.0, 1.0);
uniform float lamp_silver_nonbuildable = 0.0;
/// Radius des Kerns und des Lichtscheins auf dem Boden in Einheiten, Helligkeit des Scheins
uniform float lamp_size = 0.06;
uniform float lamp_radius = 0.9;
uniform float lamp_pool = 0.25;
/// Higher powers produce a spotlight-like pool with a steeper outer falloff.
uniform float lamp_falloff = 2.0;
/// Recessed metal housing and individual warm LEDs; preserve surface texture in the light pool.
uniform float lamp_recess = 0.0;
/// -1 preserves the original profile; 0 soft, 1 hard, 2 spotlight.
uniform int lamp_type = -1;
uniform float lamp_half_distance = 0.6;
uniform float lamp_edge_width = 0.03;
uniform float lamp_height = 1.0;
uniform vec3 lamp_direction = vec3(0.0, -1.0, 0.0);
uniform float lamp_inner_angle = 20.0;
uniform float lamp_outer_angle = 40.0;
uniform float lamp_focus = 1.0;
/// Fläche der blockierten Felder (0 = durchsichtig wie bisher)
uniform vec4 blocked_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float blocked_alpha = 0.0;
/// Rand der Sperrzone; Deckkraft 0 = in zone_color
uniform vec4 zone_edge_color : source_color = vec4(0.0);
// Farbstich je Feld (Maul: Gebiet in der Farbe seines Spielers), A = Stärke; nur der Boden, nicht die Linien
uniform sampler2D tint : source_color, filter_nearest, repeat_disable, hint_default_transparent;
// Helligkeit der Stichfarbe (unter 1: dunkler, damit der Marmor dunkel bleibt)
uniform float tint_shade = 0.8;
// 1: Stich auf den Boden (Shopping Maul); tint_lines 1: Gitterlinien und Ränder ganz in der Stichfarbe (GemTD-Maul-Karten)
uniform float tint_floor = 1.0;
uniform float tint_lines = 0.0;
/// Glühen wie die Pilze im Pilzhof: weiter, gesättigter Schein um Hauptlinien und Ränder, während der Kern
/// blass bis weiß bleibt (0 = aus). glow_width = Abklingweite in Einheiten, glow_sat = wie stark die Farbe
/// des Scheins zur reinen Farbe hin gezogen wird (1 = schwächster Kanal ganz heraus)
uniform float glow_halo = 0.0;
/// Sperrzone als Hologramm (0 = schlichte rote Fläche): wandernde Scanlinien, feines Rautengitter,
/// leichtes Flimmern, die Fläche wird zum Rand hin dichter
uniform float zone_holo = 0.0;
uniform float glow_width = 0.22;
uniform float glow_sat = 0.8;

#ifdef LIT
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform float floor_relief : hint_range(0.0, 1.0) = 0.3;
/// Nur beleuchtetes Feld: Helligkeit der Fläche vor dem Licht (das Licht hellt sie wieder auf)
uniform float lit_albedo = 1.0;
/// Eigenleuchten der Linien (Anteil der Linienfarbe)
uniform float line_glow = 0.35;
/// zusätzliches schwaches Leuchten der dicken Hauptlinien und Rauten (0 = aus)
uniform float major_glow = 0.0;
uniform vec4 major_glow_color : source_color = vec4(1.0, 0.78, 0.4, 1.0);
uniform float line_metallic = 0.8;
uniform float line_roughness = 0.35;
uniform sampler2D metal_roughness : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float line_finish = 0.0;
uniform float line_clearcoat = 0.0;
/// Marmor: glatt, mit sichtbarem Glanzlicht der Sonne
uniform float floor_roughness = 0.3;
uniform float floor_specular = 0.6;
#endif

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float is_blocked(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= int(cells.x) || c.y >= int(cells.y)) {
		return 1.0;
	}
	return step(0.5, texelFetch(blocked, c, 0).r);
}

// Röhre mit weißem Kern und weichem Lichthof; d = Abstand zur Linie in Einheiten,
// aa = Breite eines Pixels in Einheiten (nicht fwidth(d): d springt an Feldgrenzen)
vec4 tube(float d, float width, vec3 col, float energy, float aa) {
	float body = 1.0 - smoothstep(width, width + aa, d);
	float core_ = (1.0 - smoothstep(width * 0.3, width * 0.3 + aa, d)) * 0.7;
	float halo = exp(-d / halo_width) * 0.35;
	vec3 c = mix(col, vec3(1.0), core_ * core_white / 0.7) * energy;
	float a = max(body, halo);
	return vec4(mix(col * energy * 0.6, c, body), a);
}

// Gesättigte Fassung einer Farbe: schwächsten Kanal abziehen, Helligkeit des stärksten behalten
vec3 saturate_col(vec3 c, float k) {
	float lo = min(c.r, min(c.g, c.b));
	float hi = max(c.r, max(c.g, c.b));
	vec3 s = c - lo * k;
	return s * hi / max(max(s.r, max(s.g, s.b)), 0.001);
}

// Weiter, gesättigter Schein (glow_halo) auf col legen; d = Abstand zur Linie
void glow(inout vec3 col, inout float alpha, float d, vec3 lc, float energy) {
	float g = exp(-d / glow_width) * glow_halo;
	col = mix(col, saturate_col(lc, glow_sat) * energy, g);
	alpha = max(alpha, g);
}

float is_zone(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= int(cells.x) || c.y >= int(cells.y)) {
		return 0.0;
	}
	return step(0.5, texelFetch(blocked, c, 0).g);
}

// B = schlichtes Feld ohne Gitterlinien (z. B. unter der Maul-Stadt)
float is_plain(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= int(cells.x) || c.y >= int(cells.y)) {
		return 0.0;
	}
	return step(0.5, texelFetch(blocked, c, 0).b);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Marmor: dunkle Grundfläche mit feinen hellen Adern
vec3 marble_color(vec3 base, vec2 p) {
	float n = noise(p * 0.7) * 0.6 + noise(p * 1.9) * 0.3 + noise(p * 5.0) * 0.1;
	float vein = 1.0 - smoothstep(0.0, 0.035, abs(sin((p.x * 0.6 + p.y * 0.35 + n * 5.0) * 3.14159)));
	return mix(base * (0.85 + n * 0.3), vein_color.rgb, vein * vein_color.a);
}

void fragment() {
	vec2 g = world_xz / cell;
	ivec2 c = ivec2(floor(g));
	float b = is_blocked(c);
	vec2 f = fract(g);
	float aa = max(length(fwidth(world_xz)) * 0.7, 0.0005);

	vec3 col = floor_color.rgb;
	if (c.x >= 0 && c.y >= 0 && c.x < int(cells.x) && c.y < int(cells.y) && texelFetch(paving, c, 0).r > 0.5) {
		col = paving_color.rgb;
	}
	// Anteil der Linien/Rauten/Ränder (für das beleuchtete Feld: Metall statt Marmor)
	float lines = 0.0;
	// Licht der Bodenleuchten (floor_lamp), wird zuletzt als Eigenleuchten dazugegeben
	vec3 lamp_light = vec3(0.0);
	// Anteil der dicken Hauptlinien und Rauten (major_glow)
	float majors = 0.0;
	if (marble > 0.0) {
		col = mix(col, marble_color(col, world_xz), marble);
	}
	vec3 lc = line_color.rgb;
	vec3 ec = edge_color.rgb;
	if (c.x >= 0 && c.y >= 0 && c.x < int(cells.x) && c.y < int(cells.y)) {
		vec4 t = texelFetch(tint, c, 0);
		col = mix(col, t.rgb * tint_shade * (0.6 + length(col)), t.a * tint_floor);
		if (tint_lines > 0.5 && t.a > 0.0) {
			lc = t.rgb;
			ec = t.rgb;
		}
	}
	float alpha = floor_alpha * (1.0 - b);
	if (b > 0.5) {
		col = blocked_color.rgb;
		alpha = blocked_alpha;
	}

	if (b < 0.5) {
		if (is_plain(c) < 0.5) {
			// Gitterlinien: jede major_every-te hell, die übrigen gedämpft
			vec2 go = g - grid_origin;
			if (checker > 0.0) {
				ivec2 k = ivec2(floor(go / grid_cells));
				if (((k.x + k.y) & 1) == 1) {
					col *= 1.0 - checker;
				}
			}
			vec2 dc = abs(fract(go + 0.5) - 0.5) * cell;
			bool joints = joint_color.a > 0.0;
			vec3 jc = joints ? joint_color.rgb : lc;
			vec4 cl = tube(min(dc.x, dc.y), line_width * 0.9, jc, line_energy * cell_energy, aa);
			cl.a *= cell_alpha;
			col = mix(col, cl.rgb, cl.a);
			alpha = max(alpha, cl.a);
			lines = max(lines, joints ? 0.0 : cl.a);
			vec2 gg = go / grid_cells;
			vec2 dg = abs(fract(gg + 0.5) - 0.5) * grid_cells * cell;
			vec4 l = tube(min(dg.x, dg.y), line_width, jc, line_energy * minor_energy, aa);
			l.a *= minor_alpha;
			col = mix(col, l.rgb, l.a);
			alpha = max(alpha, l.a);
			lines = max(lines, joints ? 0.0 : l.a);
			vec2 gm = go / (grid_cells * major_every);
			vec2 lamp_offset = (fract(gm + 0.5) - 0.5) * grid_cells * major_every * cell;
			vec2 dm = abs(lamp_offset);
			float dmm = min(dm.x, dm.y);
			if (major_double > 0.5) {
				dmm = abs(dmm - line_width * 3.0);
			}
			if (glow_halo > 0.0) {
				glow(col, alpha, dmm, lc, line_energy * major_energy);
			}
			vec4 m = tube(dmm, line_width * 1.2, lc, line_energy * major_energy, aa);
			m.a *= major_alpha;
			col = mix(col, m.rgb, m.a);
			alpha = max(alpha, m.a);
			lines = max(lines, m.a);
			majors = max(majors, m.a);
			if (diamond_size > 0.0) {
				// Raute an jeder Kreuzung der Hauptlinien, gefüllt, mit dunklem Innenrand
				float dd = (dm.x + dm.y) / diamond_size;
				float fill = 1.0 - smoothstep(1.0 - aa / diamond_size, 1.0, dd);
				float inner = smoothstep(0.55, 0.55 + aa / diamond_size, dd) * (1.0 - smoothstep(0.7, 0.7 + aa / diamond_size, dd));
				vec3 dcol = mix(lc * line_energy * major_energy, floor_color.rgb, inner * 0.8);
				col = mix(col, dcol, fill * major_alpha);
				alpha = max(alpha, fill * major_alpha);
				lines = max(lines, fill * major_alpha);
				majors = max(majors, fill * major_alpha);
			}
			if (floor_lamp > 0.0) {
				// Anchor classification keeps a fixture one color even at a zone boundary.
				ivec2 lamp_cell = ivec2(floor(grid_origin + floor(gm + 0.5) * grid_cells * major_every));
				float silver = 0.0;
				if (lamp_silver_nonbuildable > 0.0 && lamp_cell.x >= 0 && lamp_cell.y >= 0 && lamp_cell.x < int(cells.x) && lamp_cell.y < int(cells.y)) {
					silver = max(texelFetch(paving, lamp_cell, 0).r, is_zone(lamp_cell));
				}
				vec3 fixture_light = mix(lamp_color.rgb, lamp_silver_color.rgb, silver);
				// Bodenleuchte in jeder Kreuzung der Hauptlinien: heller Kern und ein Lichtkegel auf dem Boden
				float r = length(dm);
				float lamp_core = 1.0 - smoothstep(lamp_size, lamp_size + aa, r);
				float radius = max(lamp_radius, 0.001);
				float pool = exp(-pow(r / radius, lamp_falloff)) * lamp_pool;
				pool *= 1.0 - smoothstep(radius, radius * 2.0, r);
				if (lamp_type >= 0) {
					pool = surface_light_profile(lamp_type, lamp_offset, lamp_half_distance, radius,
						lamp_edge_width, lamp_height, lamp_direction, lamp_inner_angle, lamp_outer_angle, lamp_focus) * lamp_pool;
				}
				if (lamp_recess > 0.0) {
					float housing = 1.0 - smoothstep(lamp_size * 2.0, lamp_size * 2.0 + aa, r);
					float bezel = smoothstep(lamp_size * 1.55 - aa, lamp_size * 1.55, r);
					vec3 surface = col;
					vec3 bezel_color = mix(vec3(0.19, 0.15, 0.085), vec3(0.30, 0.34, 0.39), silver);
					col = mix(col, mix(vec3(0.018, 0.021, 0.023), bezel_color, bezel), housing);
					float angle = atan(dm.y + 0.00001, dm.x + 0.00001);
					float leds = pow(0.5 + 0.5 * cos(angle * 8.0), 5.0);
					float ring = 1.0 - smoothstep(lamp_size * 0.3, lamp_size * 0.3 + aa, abs(r - lamp_size * 1.05));
					lamp_core = max(ring * leds, lamp_core * 0.04);
					// Diffuse pool is modulated by the actual paving, rather than a flat emissive disc.
					lamp_light = fixture_light * (lamp_core * floor_lamp + surface * pool * 2.5 * (1.0 - housing));
				} else {
					lamp_light = fixture_light * (lamp_core * floor_lamp + pool * (1.0 - lamp_core));
					col = mix(col, fixture_light, lamp_core);
				}
			}
		} else {
			col *= plain_shade;
		}
		if (fine_strength > 0.0) {
			vec2 df = abs(fract(g + 0.5) - 0.5) / fwidth(g);
			float fl = (1.0 - clamp(min(df.x, df.y), 0.0, 1.0)) * fine_strength;
			col = mix(col, lc, fl);
			alpha = max(alpha, fl);
		}
		// Sperrzone um die Wegpunkte: rote Fläche, Neonrand zu bebaubaren Feldern
		if (is_zone(c) > 0.5) {
			float dz = 10.0;
			if (is_zone(c + ivec2(-1, 0)) < 0.5) dz = min(dz, f.x);
			if (is_zone(c + ivec2(1, 0)) < 0.5) dz = min(dz, 1.0 - f.x);
			if (is_zone(c + ivec2(0, -1)) < 0.5) dz = min(dz, f.y);
			if (is_zone(c + ivec2(0, 1)) < 0.5) dz = min(dz, 1.0 - f.y);
			float za = zone_alpha;
			vec3 zcol = zone_color.rgb;
			if (zone_holo > 0.0) {
				// Hologramm: dünner Grundschleier, zum Rand hin dichter, darin wandernde Scanlinien
				// und ein feines Rautengitter, das ganze flimmert leicht
				float rim = exp(-dz * cell / 0.35);
				float scan = pow(0.5 + 0.5 * sin((world_xz.y + world_xz.x * 0.3) * 38.0 - TIME * 3.0), 6.0);
				float sweep = pow(fract((world_xz.y - TIME * 0.6) * 0.25), 10.0);
				vec2 dia = abs(fract(vec2(world_xz.x + world_xz.y, world_xz.x - world_xz.y) * 2.5) - 0.5);
				float mesh = 1.0 - smoothstep(0.0, 0.06, min(dia.x, dia.y));
				float flick = 0.88 + 0.12 * sin(TIME * 23.0 + hash(vec2(c)) * 6.28) * sin(TIME * 7.3);
				za = (zone_alpha * 0.45 + rim * 0.35 + scan * 0.18 + mesh * 0.16 + sweep * 0.3) * flick * zone_holo
						+ zone_alpha * (1.0 - zone_holo);
				zcol = mix(zone_color.rgb, mix(zone_color.rgb, vec3(1.0, 0.75, 0.8), 0.5) * 1.6, scan * 0.6 + sweep * 0.5);
			}
			col = mix(col, zcol, clamp(za, 0.0, 1.0));
			alpha = max(alpha, clamp(za, 0.0, 1.0) + floor_alpha * 0.5);
			vec3 zc = zone_edge_color.a > 0.0 ? zone_edge_color.rgb : zone_color.rgb;
			vec4 z = tube(dz * cell, line_width * 1.8, zc, zone_edge_energy, aa);
			col = mix(col, z.rgb, z.a);
			alpha = max(alpha, z.a);
			lines = max(lines, z.a);
		}
		// Ränder zu blockierten Feldern
		float de = 10.0;
		if (is_blocked(c + ivec2(-1, 0)) > 0.5) de = min(de, f.x);
		if (is_blocked(c + ivec2(1, 0)) > 0.5) de = min(de, 1.0 - f.x);
		if (is_blocked(c + ivec2(0, -1)) > 0.5) de = min(de, f.y);
		if (is_blocked(c + ivec2(0, 1)) > 0.5) de = min(de, 1.0 - f.y);
		if (glow_halo > 0.0) {
			glow(col, alpha, de * cell, ec, edge_energy * 0.6);
		}
		vec4 e = tube(de * cell, line_width * 1.6, ec, edge_energy, aa);
		col = mix(col, e.rgb, e.a);
		alpha = max(alpha, e.a);
		lines = max(lines, e.a);
	}
#ifdef LIT
	// beleuchtet (Art déco): Marmor glänzt, Messinglinien sind Metall und leuchten leicht nach,
	// damit sie im Schatten lesbar bleiben; Sonne, Schatten und Treffer-Lichter fallen auf den Boden
	ALBEDO = col * mix(lit_albedo, 1.0, lines);
	EMISSION = col * lines * line_glow + major_glow_color.rgb * majors * major_glow + lamp_light;
	METALLIC = lines * line_metallic;
	// Calculated marble/metal microrelief; the unshaded holographic floor is unchanged.
	float grain = noise(world_xz * 8.0);
	float relief = grain * 0.0012 * marble + lines * 0.0015;
	NORMAL = terrain_relief_normal(NORMAL, VERTEX, relief, floor_relief);
	float polished = line_roughness * mix(1.0, texture(metal_roughness, world_xz * 0.18).r, line_finish);
	ROUGHNESS = clamp(mix(floor_roughness + (grain - 0.5) * 0.04 * marble, polished, lines), 0.04, 1.0);
	SPECULAR = clamp(mix(floor_specular * mix(0.94, 1.02, grain), 0.65, lines * line_finish), 0.0, 1.0);
	CLEARCOAT = lines * line_clearcoat;
	CLEARCOAT_ROUGHNESS = 0.22;
#else
	ALBEDO = col + lamp_light;
	ALPHA = clamp(alpha, 0.0, 1.0);
#endif
}
