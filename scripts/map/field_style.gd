class_name FieldStyle
extends RefCounted
## Aussehen des 3D-Spielfelds je Oberflächen-Stil (UiTheme.skin): Boden, Raster, Sperrzonen, Wegpunkte,
## Felsbrocken, Tower-Sockel, Licht und Himmel. Board3D, Tower und CameraRig lesen current().
## - Arcade (GemTD): Neon-Gitter über dem Weltraum, wie bisher.
## - Druidenhain (eeveTD): Gras und Erde bei Tageslicht, dunkles Raster wie in den Boden geritzt, Steinsockel.
## - Art déco (Shopping Maul): heller Kalkstein-Marmor mit Fugenraster und Messingrauten, Gänge in Petrol,
##   Messingsockel, Nacht im Mondlicht (Plaza-Vorbild).
## - Plakatwand (Randgruppen TD): hellgrauer Beton mit ein paar Steinen, Splitt auf den Wegen, Tageslicht;
##   die Wände bestehen aus Häusern und Bäumen (RgScenery).

## Nachtversion des Stils (env_night/floor_night), vor dem Anlegen der Szene setzen.
static var night := false

const NEON := "neon"
const DRUID := "druid"
const DECO := "deco"
const POSTER := "poster"

## Licht und Himmel (CameraRig.add_environment, Vulkan/Forward+: Glow wirkt dort stärker als im alten
## Compatibility-Renderer, die Werte sind darauf abgestimmt): Arcade-Stand, andere Stile überschreiben einzelne Werte.
## Ohne "sky_top" bleibt die Weltraum-Skybox. ambient_sky = Anteil des Umgebungslichts vom Himmel
## (0 = nur Farbe "ambient"). "fill" = Gegenlicht ohne Schatten von der anderen Seite.
const ENV_DEFAULT := {
	# dunkle Szene: schwaches kühles Umgebungslicht und eine schwache, flach stehende Sonne,
	# damit Neon, Sockel und Gems hervorstechen
	"ambient": Color(0.62, 0.7, 0.85), "ambient_energy": 0.1, "ambient_sky": 0.0,
	"sun": Color(1.0, 0.96, 0.88), "sun_energy": 0.55, "sun_pitch": -38.0, "sun_yaw": -35.0,
	"sun_specular": 1.0, "shadow_blur": 1.5, "shadow_opacity": 1.0,
	"fill": Color(0.55, 0.45, 1.0), "fill_energy": 0.0, "fill_pitch": -25.0,
	# Schein des leuchtenden Bodens von unten (wie das Pilzlicht, das die Mauern färbt): Licht ohne Schatten,
	# das schräg nach oben scheint und Unterseiten und Flanken von Towern, Steinen und Gegnern färbt, 0 = aus
	"under": Color(1.0, 0.36, 0.86), "under_energy": 0.0, "under_pitch": 62.0,
	"fog": Color.BLACK, "fog_density": 0.0,
	"glow_threshold": 1.0, "glow_intensity": 0.9, "glow_bloom": 0.0,
	"tonemap": Environment.TONE_MAPPER_FILMIC, "exposure": 0.9, "white": 1.0,
	"contrast": 1.0, "saturation": 1.0, "tint": Color.WHITE,
	# leichte Kontur um alles Deckende (CameraRig, screen_outline.gdshader), 0 = aus
	"outline": 0.4, "outline_color": Color(0.03, 0.02, 0.06),
	# Umgebungsverdeckung, indirektes Licht und Volumen-Nebel (Forward+), 0 = aus
	"ssao": 1.0, "ssao_radius": 0.8, "ssil": 0.0, "vol_fog": 0.0,
	# Ränder abdunkeln und leicht tönen (CameraRig, screen_post.gdshader), 0 = aus
	"vignette": 0.45, "vignette_color": Color(0.12, 0.04, 0.22),
	# Studiolicht nur für Metall-Spiegelungen (Metall, Studiolicht-Block der Himmel-Shader): Stärke, Softboxen oben,
	# Streifen am Horizont. Arcade: rosa Softboxen und Cyan-Streifen wie Neonröhren
	"metall": 0.9, "metall_farbe": Color("ffb0e0"), "metall_farbe2": Color("70f0ff"),
}

## Plakatwand: Bodentexturen statt Gras und Erde (selbst erzeugt, tools/rg_texturen.py): Pflaster mit Gras
## in den Fugen auf den Bauflächen (Lukas, 2026-10-29), Splitt auf den Wegen und hier und da als Fleck.
const POSTER_TEXTURES := {
	"grass_a": "res://assets/textures/ground/cobble.jpg",
	"grass_b": "res://assets/textures/ground/cobble.jpg",
	"dirt": "res://assets/textures/ground/gravel.jpg",
	"grass_a_normal": "res://assets/textures/ground/cobble_normal.jpg",
	"grass_b_normal": "res://assets/textures/ground/cobble_normal.jpg",
	"dirt_normal": "res://assets/textures/ground/gravel_normal.jpg",
	# Wiese auf den gesperrten Feldern (Lukas, 2026-10-30): Gras und Erde wie in eeveTD
	"lawn_grass": "res://assets/textures/ground/grass_a.jpg",
	"lawn_soil": "res://assets/textures/ground/dirt.jpg",
}

## Art déco (Maul) bei Nacht: Mondlicht, dunkelblauer Himmel.
const DECO_NIGHT := {
	"metall": 0.55, "metall_farbe": Color("c0cce8"), "metall_farbe2": Color("6fb8c0"),
	"sky_top": Color("02070e"), "sky_horizon": Color("0c2032"), "ground_bottom": Color("020507"),
	"ambient": Color("5d7fa8"), "ambient_energy": 0.24, "ambient_sky": 0.0,
	"sun": Color("a8c0ec"), "sun_energy": 0.7, "sun_pitch": -40.0, "sun_yaw": 55.0, "sun_specular": 0.3,
	"shadow_opacity": 0.75, "shadow_blur": 2.2,
	"fill": Color("3a5a78"), "fill_energy": 0.25, "fill_pitch": -25.0,
	"glow_threshold": 0.95, "glow_intensity": 0.65, "exposure": 1.05, "contrast": 1.05,
	"tint": Color(1.0, 0.95, 0.86),
	"vignette": 0.4, "vignette_color": Color(0.02, 0.06, 0.12),
	"ssao": 1.5, "ssil": 0.5,
}

## Werte je Stil. "floor" sind Parameter für neon_floor.gdshader, "env" für CameraRig.add_environment.
## "floor_lit": Feld beleuchtet und deckend (neon_floor_lit.gdshader, nimmt Sonne, Schatten, Treffer-Lichter an).
## "contact_shadow": Stärke des weichen Schattens unter Towern und Steinen (ContactShadow, 0 = aus).
## "reflect": Stärke der Spiegelung auf dem Feld (Board3D, 0 = keine; Gras und Beton spiegeln nicht).
## "hit_glow": Faktor für den flachen Treffer-Schein auf dem Boden (FxPlayer, Standard 1).
const STYLES := {
	NEON: {
		"ground_alpha": 0.0,
		# Vulkan mischt in linearem Licht: Fläche durchsichtiger und Linien etwas schwächer,
		# sonst wirkt der Boden heller als im alten Renderer
		# Glühen nach dem Prinzip der Pilze (Pilzhof): blasser, fast weißer Kern, breiter gesättigter Schein
		"floor": {"floor_color": Color("040208"), "floor_alpha": 0.6, "halo_width": 0.05, "major_energy": 1.15, "line_energy": 0.55, "minor_energy": 0.26, "cell_energy": 0.12,
				"core_white": 0.6, "edge_energy": 2.0, "glow_halo": 0.28, "glow_width": 0.18, "glow_sat": 0.85,
				"zone_holo": 1.0},
		# dünner farbiger Dunst knapp über dem Boden (Board3D, ground_mist.gdshader), ab Grafik Mittel
		"haze": {"color": Color("7a1aa0"), "density": 0.075, "height": 0.22, "scale": 0.16},
		"path": Color("2ef2e0"), "path_energy": 2.2,
		"marker": Color("ff36d8"), "marker_energy": 2.2,
		"rock": "glass",
		# Felsen bekommen unten einen pinken Schein vom Boden (rock.gdshader floor_glow)
		"rock_glow": 0.3,
		# türkises Rauchglas mit dunkel petrolfarbenem Kern (Lukas, 2026-11-09)
		"rock_color": Color(0.02, 0.72, 0.7), "rock_core": Color(0.0, 0.05, 0.06),
		"base": "glass",
		# Glasboden: Gems und Gegner spiegeln sich (Board3D, floor_reflect.gdshader)
		"reflect": 0.35,
		# violettes Gegenlicht von hinten: Gems und Felsen bekommen eine Lichtkante
		# dazu der Schein der pinken Linien von unten auf Gems, Felsen und Gegner
		"env": {"fill": Color("b070ff"), "fill_energy": 0.35, "fill_pitch": -20.0, "under_energy": 0.9},
	},
	DRUID: {
		"ground_alpha": 1.0,
		"ground": {
			"brightness": 0.5, "saturation": 0.55, "tint": Vector3(0.9, 0.97, 0.8),
			"grass_tile": 2.6, "detail_blur": 2.2, "grass_contrast": 0.4, "normal_strength": 0.7,
		},
		"floor": {
			"floor_alpha": 0.0,
			"line_color": Color("1c2416"), "edge_color": Color("3a2a1a"),
			"line_energy": 1.0, "major_energy": 1.0, "minor_energy": 1.0, "cell_energy": 1.0,
			"cell_alpha": 0.0, "minor_alpha": 0.2, "major_alpha": 0.42,
			"edge_energy": 1.0, "core_white": 0.0, "halo_width": 0.004, "line_width": 0.012,
			"zone_color": Color("b0563a"), "zone_alpha": 0.28, "zone_edge_energy": 0.9,
			"zone_edge_color": Color("5a2a18"),
		},
		"path": Color("e8d27a"), "path_energy": 1.3,
		"marker": Color("d8c888"), "marker_energy": 1.0,
		"rock": "stone",
		"base": "stone",
		"contact_shadow": 0.6,
		"hit_glow": 0.5,
		# Nacht nach dem Vorbild Duskwood (WoW Forever, Wunsch von Lukas): blauvioletter Nebel, in dem der Wald
		# als Silhouette versinkt, kühles Mondlicht, kein Gegenlicht; die warmen Laternen setzt EeveScenery
		"env_night": {
			"metall": 0.45, "metall_farbe": Color("a8b8e0"), "metall_farbe2": Color("6a7aa8"),
			"sky_top": Color("0a0c1c"), "sky_horizon": Color("2a2c4a"), "ground_bottom": Color("0c0d18"),
			# weniger flaches Umgebungslicht, dafür ein kräftigerer, silbriger Mond mit Glanz: Tower, Barrikaden
			# und Bäume bekommen eine helle und eine dunkle Seite statt einheitlich blau zu sein
			"ambient": Color("6a70a8"), "ambient_energy": 0.4, "ambient_sky": 0.0,
			"sun": Color("b8c4ff"), "sun_energy": 0.8, "sun_pitch": -50.0, "sun_specular": 0.6, "shadow_opacity": 0.75,
			# schwaches violettes Gegenlicht als Lichtkante an den Umrissen
			"fill": Color("8a70d0"), "fill_energy": 0.22, "fill_pitch": -20.0,
			"fog": Color("1c2038"), "fog_density": 0.014,
			"glow_threshold": 0.9, "glow_intensity": 0.7,
			"tonemap": Environment.TONE_MAPPER_FILMIC, "exposure": 1.2, "white": 1.0, "contrast": 1.12, "saturation": 1.0,
			"vignette": 0.55, "vignette_color": Color(0.04, 0.04, 0.12),
			"ssao": 1.4, "ssil": 0.8, "vol_fog": 0.02,
		},
		"env": {
			"metall": 0.8, "metall_farbe": Color("fff0d8"), "metall_farbe2": Color("c8d8e8"),
			"sky_top": Color("6f97a8"), "sky_horizon": Color("c9d6b8"), "ground_bottom": Color("2e3a26"),
			# Umgebungslicht großteils vom Himmel: Oberseiten hell und bläulich, Flanken dunkler
			"ambient": Color("b8c6d0"), "ambient_energy": 0.3, "ambient_sky": 0.5,
			# warme Sonne von links hinten: die Schatten fallen nach rechts vorn und sind aus der
			# Spielansicht zu sehen (Arcade: nach hinten, hinter die Tower); das Gegenlicht kommt von vorn
			"sun": Color("ffe4b8"), "sun_energy": 1.7, "sun_pitch": -42.0, "sun_yaw": -110.0,
			"shadow_blur": 2.0, "shadow_opacity": 0.82,
			"fill": Color("9fbcd8"), "fill_energy": 0.4, "fill_pitch": -30.0,
			"fog": Color("8a9a80"), "fog_density": 0.0015,
			"glow_threshold": 1.2, "glow_intensity": 0.5,
			"tonemap": Environment.TONE_MAPPER_ACES, "exposure": 0.88, "white": 6.0,
			"contrast": 1.06, "saturation": 0.95,
			"vignette": 0.3, "vignette_color": Color(0.2, 0.22, 0.12),
			"ssao": 1.6, "ssil": 0.6,
		},
	},
	DECO: {
		"water_bank_style": "city",
		"ground_alpha": 0.0,
		"floor_lit": true,
		"floor": {
			# Plaza-Art-déco (Lukas, 2026-11-08): heller Kalkstein-Marmor mit dunklem Fugenraster in den Gebieten,
			# die Gänge zwischen den Gebieten in Petrol, dicke Linien und Rauten in Messing
			"floor_color": Color("8f8c82"), "floor_alpha": 1.0,
			"paving_color": Color("1d4446"),
			"line_color": Color("b08a4e"), "edge_color": Color("c9a36a"),
			"joint_color": Color("5c584a"),
			"line_energy": 1.0, "major_energy": 1.0, "minor_energy": 1.0, "cell_energy": 1.0,
			"cell_alpha": 0.22, "minor_alpha": 0.5, "major_alpha": 0.95,
			"edge_energy": 1.0, "core_white": 0.0, "halo_width": 0.004, "line_width": 0.011,
			"major_double": 1.0, "diamond_size": 0.2, "marble": 1.0, "plain_shade": 0.78,
			"vein_color": Color(0.5, 0.49, 0.47, 0.45),
			# Platten im Schachmuster, jede zweite eine Spur dunkler
			"checker": 0.06,
			# polierter Stein: deutliches Glanzlicht der tief stehenden Sonne
			"lit_albedo": 0.85, "line_glow": 0.3, "floor_roughness": 0.4, "floor_specular": 0.45,
			# warme Bodenleuchten in den Messingrauten, auf hellem Stein nur ein kleiner Schein
			"floor_lamp": 6.0, "lamp_color": Color("ffd08a"), "lamp_size": 0.07, "lamp_radius": 1.2, "lamp_pool": 0.3,
			"major_glow": 0.35, "major_glow_color": Color("ffc35a"),
			"tint_shade": 0.45,
			"blocked_color": Color("15373a"), "blocked_alpha": 1.0,
			"zone_color": Color("b4553f"), "zone_alpha": 0.3, "zone_edge_energy": 1.0,
			"zone_edge_color": Color("c9a36a"),
		},
		"path": Color("c9a36a"), "path_energy": 1.25,
		"marker": Color("b08a4e"), "marker_energy": 1.2,
		"zone_own": Color("e8c87a"), "zone_other": Color("4d7a78"), "zone_leak": Color("b4553f"),
		"rock": "marble",
		"base": "brass",
		"reflect": 0.12,
		"contact_shadow": 0.6,
		"hit_glow": 0.5,
		# Nacht (Lukas, 2026-11-08: „es soll Nacht bleiben“): kühles Mondlicht, die Kalksteintürme heben sich
		# mit hellen Dächern und erleuchteten Fenstern, Kronen und Spitzen vom dunkelblauen Himmel ab
		"env": DECO_NIGHT,
		"env_night": DECO_NIGHT,
	},
	POSTER: {
		"water_bank_style": "city",
		"ground_alpha": 1.0,
		"ground_textures": POSTER_TEXTURES,
		"ground": {
			"brightness": 0.62, "saturation": 0.75, "tint": Vector3(1.0, 1.0, 1.0),
			"grass_tile": 3.0, "dirt_tile": 2.0, "detail_blur": 0.0, "grass_contrast": 1.0, "normal_strength": 0.9,
			"vary": 0.0, "detail_normal": 0.0,
			# Gegnerweg als Straße mit weißen Randlinien, gesperrte Felder als Wiese (Lukas, 2026-10-30)
			"road": 1.0, "lawn": 1.0,
		},
		"floor": {
			"floor_alpha": 0.0,
			"line_color": Color("2a2a2a"), "edge_color": Color("151515"),
			"line_energy": 1.0, "major_energy": 1.0, "minor_energy": 1.0, "cell_energy": 1.0,
			"cell_alpha": 0.0, "minor_alpha": 0.12, "major_alpha": 0.3,
			"edge_energy": 1.0, "core_white": 0.0, "halo_width": 0.004, "line_width": 0.012,
			"zone_color": Color("e8372a"), "zone_alpha": 0.22, "zone_edge_energy": 0.9,
			"zone_edge_color": Color("151515"),
			"blocked_color": Color("5a5f55"), "blocked_alpha": 0.0,
		},
		"path": Color("e8372a"), "path_energy": 1.2,
		"marker": Color("151515"), "marker_energy": 1.0,
		"rock": "stone",
		"base": "stone",
		"contact_shadow": 0.55,
		"hit_glow": 0.5,
		"env": {
			"metall": 0.8, "metall_farbe": Color("fff4e4"), "metall_farbe2": Color("d0dce8"),
			"sky_top": Color("9fb4c4"), "sky_horizon": Color("dcdcd4"), "ground_bottom": Color("6a6a64"),
			# etwas gedämpfter als zuvor (Lukas, 2026-10-30: „weniger stark beleuchtet“)
			"ambient": Color("c8ccd0"), "ambient_energy": 0.28, "ambient_sky": 0.5,
			"sun": Color("fff1dc"), "sun_energy": 1.25, "sun_pitch": -48.0, "sun_yaw": -110.0,
			"shadow_blur": 1.8, "shadow_opacity": 0.75,
			"fill": Color("b0c0d0"), "fill_energy": 0.22, "fill_pitch": -30.0,
			"glow_threshold": 1.2, "glow_intensity": 0.35,
			"tonemap": Environment.TONE_MAPPER_ACES, "exposure": 0.9, "white": 6.0,
			"contrast": 1.04, "saturation": 0.95,
			"vignette": 0.25, "vignette_color": Color(0.25, 0.24, 0.22),
			"ssao": 1.6, "ssil": 0.4,
		},
	},
}



## Name des Stils, der zum aktiven Oberflächen-Stil passt.
static func current_name() -> String:
	match UiTheme.skin:
		UiTheme.DRUID:
			return DRUID
		UiTheme.DECO:
			return DECO
		UiTheme.POSTER:
			return POSTER
	return NEON


static func current() -> Dictionary:
	return STYLES[current_name()]


## Licht und Himmel des aktiven Stils, fehlende Werte aus ENV_DEFAULT (für CameraRig.add_environment).
## Bei night zusätzlich "env_night" des Stils (falls vorhanden).
static func env(name := "") -> Dictionary:
	var style: Dictionary = STYLES[name if name != "" else current_name()]
	var look: Dictionary = ENV_DEFAULT.duplicate()
	look.merge(style.get("env", {}), true)
	if night:
		look.merge(style.get("env_night", {}), true)
	# Stimmung des Modus (StyleFilter): z. B. wärmeres Licht in Randgruppen TD, Nebel im Wald
	look.merge(StyleFilter.light(name), true)
	return look


## Boden-Parameter (neon_floor) des aktiven Stils, bei night mit "floor_night" überschrieben.
static func floor_params() -> Dictionary:
	var style := current()
	var params: Dictionary = style.floor.duplicate()
	if night:
		params.merge(style.get("floor_night", {}), true)
	return params


static func is_neon() -> bool:
	return current_name() == NEON


## Material für Wegpunkt-Ringe, Zonenränder und Wegpunkte: Neonröhre im Arcade-Stil,
## sonst Metall bzw. warmes Licht in der Stilfarbe (leicht leuchtend, energy wie bei Neon).
static func line_material(col: Color, energy: float) -> Material:
	if is_neon():
		return Board3D.neon_material(col, energy)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.85 if current_name() == DECO else 0.0
	m.roughness = 0.3 if current_name() == DECO else 0.7
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = maxf(energy - 1.0, 0.0) * 0.6 + 0.15
	Metall.veredeln(m)
	return m
