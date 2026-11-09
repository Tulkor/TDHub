class_name DayCycle
extends Node
## Tageszeit, die im Spiel langsam weiterläuft (eeveTD, YouTD; Lukas 2026-11-09, Vorbild Licht bei Sonnen- und
## Mondauf- und -untergang in WoW, nur das Prinzip): Abenddämmerung, Nacht, Morgendämmerung, Tag.
## Stützpunkte (KEYS) über 24 Stunden mit Himmel, Licht, Nebel und Bildfilter; dazwischen wird gemischt.
## Nacht und Tag kommen unverändert aus FieldStyle (env_night/env) und StyleFilter, die Dämmerungen
## überschreiben einzelne Werte. Sonne und Mond wandern über den Himmel; das Licht steht nie flacher als
## MIN_PITCH, damit die Schatten lang, aber das Spielfeld lesbar bleibt.
## Rein optisch, jeder Spieler rechnet seine eigene Uhr (nichts geht übers Netz).

## Wie schnell die Zeit läuft: [von Stunde, bis Stunde, Sekunden Spielzeit]. Dämmerungen langsamer, die Nacht
## (der gewohnte Look von eeveTD) am längsten. Ein ganzer Tag dauert 22 Minuten.
const PACE := [[18.0, 21.0, 240.0], [21.0, 28.5, 480.0], [4.5, 7.5, 240.0], [7.5, 18.0, 360.0]]
## Start kurz vor Sonnenuntergang: nach gut einer Minute ist die Sonne weg, dann kommt die Nacht.
const START := 18.4
const NIGHT_HOUR := 1.0
const DAY_HOUR := 12.0
## Sonne über dem Horizont von SUNRISE bis SUNSET, Mond von MOONRISE bis MOONSET (nächster Tag).
const SUNRISE := 6.0
const SUNSET := 19.3
const MOONRISE := 20.2
const MOONSET := 5.6
## Ab hier leuchtet der Mond statt der Sonne (beide unter dem Horizont, Licht am schwächsten)
const SWITCH_EVENING := 19.75
const SWITCH_MORNING := 5.8
const SUN_HIGH := 58.0
const MOON_HIGH := 50.0
const MIN_PITCH := 20.0
## Werte neu setzen höchstens so oft (Sekunden); der Himmel rechnet dann seine Umgebungskarte neu.
const STEP := 0.12

## Dämmerungen: Überschreibungen auf Nacht ("night") bzw. Tag ("day"). "n" = wie viel Nacht (Laternen,
## Glühwürmchen, Waldfarbe, 0 = Tag, 1 = Nacht). Farben: Himmel oben/Mitte/Horizont, Schein um die Sonne,
## Licht der Sonne/des Monds, Umgebung, Nebel (mit "fog_sun" = Streuung zur Sonne hin, warmer Dunst im Gegenlicht).
const KEYS := [
	[1.0, "night", {}],
	# Mond geht unter, erstes Grau am Horizont
	[4.7, "night", {"sky_horizon": Color("3a3458"), "sky_mid": Color("1e2140"), "stars": 0.7}],
	# Morgendämmerung: kühles Blauviolett, am Horizont Rosa
	[5.7, "night", {
		"n": 0.75, "sky_top": Color("1a2148"), "sky_mid": Color("4a4478"), "sky_horizon": Color("c87a8a"),
		"glow_color": Color("ff8a70"), "glow": 0.5, "stars": 0.2,
		"sun": Color("9a90d8"), "sun_energy": 0.35, "ambient": Color("5a5f98"), "ambient_energy": 0.42,
		"fog": Color("2a2a48"), "fog_sun": 0.1, "fill": Color("c08ab0"), "fill_energy": 0.2,
		"haze_color": Color(0.32, 0.24, 0.36), "highlight_tint": Color(0.58, 0.48, 0.58),
	}],
	# Sonnenaufgang: Pfirsich und Rosa, goldrosa Licht ganz flach, lange Schatten
	[6.5, "night", {
		"n": 0.3, "sky_top": Color("3e5a9a"), "sky_mid": Color("b886a8"), "sky_horizon": Color("ffb68a"),
		"glow_color": Color("ffa060"), "glow": 1.1, "stars": 0.0,
		"sun": Color("ffb890"), "sun_energy": 2.0, "ambient": Color("8a7aa8"), "ambient_energy": 0.42,
		"fog": Color("3e3a58"), "fog_density": 0.006, "fog_sun": 0.12, "fill": Color("8a90d0"), "fill_energy": 0.3,
		"exposure": 1.1, "haze_color": Color(0.72, 0.52, 0.42), "haze": 0.3,
		"highlight_tint": Color(0.66, 0.52, 0.46), "shadow_tint": Color(0.4, 0.42, 0.6),
	}],
	# Morgen: golden, Nebel lichtet sich
	[8.2, "day", {
		"sun": Color("ffd8a0"), "sun_energy": 1.5, "sky_horizon": Color("f0d4a8"), "glow_color": Color("ffc080"),
		"glow": 0.6, "fog": Color("a8a490"), "fog_density": 0.006, "fog_sun": 0.15,
		"highlight_tint": Color(0.6, 0.53, 0.44),
	}],
	[DAY_HOUR, "day", {}],
	[16.4, "day", {}],
	# goldene Stunde
	[17.9, "day", {
		"sun": Color("ffc488"), "sun_energy": 1.7, "sky_horizon": Color("f4c890"), "sky_mid": Color("a8b8c0"),
		"glow_color": Color("ffa860"), "glow": 0.8, "fog": Color("8a7a60"), "fog_density": 0.006, "fog_sun": 0.2,
		"ambient": Color("c8b8a8"), "highlight_tint": Color(0.66, 0.52, 0.38), "haze_color": Color(0.6, 0.48, 0.32),
		"haze": 0.35,
	}],
	# Sonnenuntergang: tiefes Orange am Horizont, darüber Magenta und Violett, rotgoldenes Licht von hinten
	[19.0, "night", {
		"n": 0.12, "sky_top": Color("2a3470"), "sky_mid": Color("a8507a"), "sky_horizon": Color("ff7a38"),
		"glow_color": Color("ff6a28"), "glow": 1.5, "stars": 0.0,
		"sun": Color("ffa255"), "sun_energy": 2.5, "sun_specular": 0.9,
		"ambient": Color("5a66a8"), "ambient_energy": 0.3,
		"fog": Color("3a3452"), "fog_density": 0.004, "fog_sun": 0.12, "fill": Color("6a70d8"), "fill_energy": 0.3,
		"exposure": 1.15, "haze_color": Color(0.4, 0.3, 0.5), "haze": 0.35, "haze_reach": 0.55,
		"highlight_tint": Color(0.68, 0.52, 0.36), "shadow_tint": Color(0.36, 0.4, 0.62), "saturation_grade": 0.85,
	}],
	# Abenddämmerung: Sonne weg, Horizont glüht Purpur nach, Laternen gehen an
	[19.75, "night", {
		"n": 0.65, "sky_top": Color("1a2058"), "sky_mid": Color("5a3a78"), "sky_horizon": Color("c85a5a"),
		"glow_color": Color("e05040"), "glow": 0.7, "stars": 0.15,
		"sun": Color("b080c0"), "sun_energy": 0.3, "ambient": Color("6a5aa0"), "ambient_energy": 0.44,
		"fog": Color("2e2440"), "fog_density": 0.016, "fog_sun": 0.15, "fill": Color("9070d0"), "fill_energy": 0.25,
		"haze_color": Color(0.3, 0.2, 0.3), "haze": 0.4, "highlight_tint": Color(0.58, 0.48, 0.52),
	}],
	# blaue Stunde
	[20.6, "night", {
		"n": 0.95, "sky_horizon": Color("4a3a6a"), "sky_mid": Color("2a2a58"), "glow_color": Color("8a4a7a"),
		"glow": 0.25, "stars": 0.5, "sun_energy": 0.55, "fog": Color("22243e"),
	}],
	# Mondaufgang: großer, silberner Mond tief über dem Wald
	[21.6, "night", {"moon_energy": 3.0, "moon_size": 0.03, "stars": 0.8}],
	[23.0, "night", {}],
]

## Nacht und Tag als vollständige Werte (aus FieldStyle und StyleFilter), dazu Werte für Himmel und Filter.
const SKY_NIGHT := {
	"sky_mid": Color("1a1c34"), "glow_color": Color("4a4a7a"), "glow": 0.15, "stars": 1.0, "moon_energy": 2.2,
	"moon_size": 0.022, "fog_sun": 0.0, "n": 1.0, "sun_energy_sky": 0.0,
}
const SKY_DAY := {
	"sky_mid": Color("a0bccc"), "glow_color": Color("fff0c8"), "glow": 0.35, "stars": 0.0, "moon_energy": 0.0,
	"moon_size": 0.018, "fog_sun": 0.15, "n": 0.0, "sun_energy_sky": 6.0,
	# Tag im selben Tonemapper wie die Nacht (Filmic), etwas mehr Belichtung als mit ACES
	"exposure": 0.62, "contrast": 1.1,
}

## Fest stehende Uhrzeit für Screenshots und Tests (>= 0: Uhr steht dort still).
static var fixed_hour := -1.0

var hour := START
## Stunden je Sekunde ergeben sich aus PACE; 0 = angehalten (Screenshots, Tests), sonst Faktor.
var speed := 1.0
var env: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var on_night := Callable()  ## func(n: float): Szenerie (Laternen, Wald, Glühwürmchen) nachziehen
var _sky_mat: ShaderMaterial
var _grade_mat: ShaderMaterial
var _keys: Array = []  ## [Stunde, vollständige Werte]
var _wait := 0.0
var _last := -1.0


## Uhr an die Umgebung der Szene hängen (nach CameraRig.add_environment, Stil Druidenhain).
func attach(made: Dictionary, game: Node) -> void:
	env = made.env
	sun = made.sun
	fill = made.get("fill")
	if fill == null:
		fill = DirectionalLight3D.new()
		fill.shadow_enabled = false
		fill.light_specular = 0.25
		game.add_child(fill)
	_build_keys()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://assets/shaders/daemmerung_himmel.gdshader")
	if env.sky == null:
		env.sky = Sky.new()
		env.sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	var f := game.get_node_or_null("StyleFilter")
	if f != null:
		var rect := f.find_child("Grade", true, false)
		if rect != null:
			_grade_mat = rect.material
	_last = -1.0
	apply()


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	apply()


## Stunden je Sekunde Spielzeit zur Stunde h (aus PACE).
static func rate(h: float) -> float:
	for p in PACE:
		var a: float = p[0]
		var b: float = p[1]
		var hh := h if h >= a else h + 24.0
		if hh >= a and hh < b:
			return (b - a) / float(p[2])
	return 10.0 / 360.0


func _process(delta: float) -> void:
	if speed <= 0.0 or env == null:
		return
	hour = fposmod(hour + rate(hour) * delta * speed, 24.0)
	_wait -= delta
	if _wait <= 0.0:
		_wait = STEP
		apply()


## Wie viel Nacht gerade ist (0 Tag, 1 Nacht).
func night_amount() -> float:
	return float(sample(hour).n)


func _build_keys() -> void:
	var was := FieldStyle.night
	FieldStyle.night = true
	var night := _full()
	FieldStyle.night = false
	var day := _full()
	FieldStyle.night = was
	night.merge(SKY_NIGHT, true)
	day.merge(SKY_DAY, true)
	# Werte, die nur einer der beiden hat, auf beiden Seiten führen (sonst springt die Mischung)
	for k in night:
		if not day.has(k):
			day[k] = night[k]
	for k in day:
		if not night.has(k):
			night[k] = day[k]
	_keys.clear()
	for k in KEYS:
		var v: Dictionary = (night if k[1] == "night" else day).duplicate()
		v.merge(k[2], true)
		_keys.append([float(k[0]), v])


## Licht des aktiven Stils (Tag oder Nacht nach FieldStyle.night) mit den Werten des Bildfilters;
## dessen Sättigung heißt hier "saturation_grade" (die Sättigung des Lichts heißt schon "saturation").
static func _full() -> Dictionary:
	var v: Dictionary = FieldStyle.env()
	var grade: Dictionary = StyleFilter.look().get("grade", {})
	for k in grade:
		v["saturation_grade" if k == "saturation" else k] = grade[k]
	v["sky_mid"] = v.get("sky_horizon", Color.BLACK)
	return v


## Werte zur Stunde h, zwischen den beiden umgebenden Stützpunkten gemischt (über Mitternacht hinweg).
func sample(h: float) -> Dictionary:
	if _keys.is_empty():
		_build_keys()
	var n := _keys.size()
	var i := n - 1
	for j in n:
		if _keys[j][0] <= h:
			i = j
	var a: Array = _keys[i]
	var b: Array = _keys[(i + 1) % n]
	var ha: float = a[0]
	var hb: float = b[0]
	var span := fposmod(hb - ha, 24.0)
	var t := fposmod(h - ha, 24.0) / maxf(span, 0.001)
	t = t * t * (3.0 - 2.0 * t)
	return mix(a[1], b[1], t)


static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		var va = a[k]
		var vb = b.get(k, va)
		if va is Color and vb is Color:
			out[k] = (va as Color).lerp(vb, t)
		elif (va is float or va is int) and (vb is float or vb is int) and not (va is int and vb is int):
			out[k] = lerpf(float(va), float(vb), t)
		else:
			out[k] = va if t < 0.5 else vb
	return out


## Höhe über dem Horizont (Grad) und Himmelsrichtung (Grad, wie rotation.y eines Lichts) von Sonne und Mond.
static func sun_pos(h: float) -> Vector2:
	var f := (h - SUNRISE) / (SUNSET - SUNRISE)
	# geht hinten rechts auf (Gegenlicht, Morgendunst), steht mittags wie das Tageslicht (-110) und geht vorn links
	# unter: abends liegt das Spielfeld voll im warmen Licht, die Schatten fallen nach hinten
	return Vector2(SUN_HIGH * sin(PI * f), 160.0 + f * 180.0)


static func moon_pos(h: float) -> Vector2:
	var hm := h if h >= 12.0 else h + 24.0
	var f := (hm - MOONRISE) / (MOONSET + 24.0 - MOONRISE)
	return Vector2(MOON_HIGH * sin(PI * f), 160.0 + f * 180.0)


static func sun_is_light(h: float) -> bool:
	return h >= SWITCH_MORNING and h < SWITCH_EVENING


static func _dir(p: Vector2) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(-p.x), deg_to_rad(p.y), 0)).z


func apply() -> void:
	if env == null:
		return
	var v := sample(hour)
	var tint: Color = v.get("tint", Color.WHITE)
	# Licht: Sonne am Tag, Mond in der Nacht; nie flacher als MIN_PITCH
	var sp := sun_pos(hour)
	var mp := moon_pos(hour)
	var body := sp if sun_is_light(hour) else mp
	sun.rotation = Vector3(deg_to_rad(-maxf(body.x, MIN_PITCH)), deg_to_rad(body.y), 0)
	sun.light_color = v.sun * tint
	sun.light_energy = v.sun_energy
	sun.light_specular = v.sun_specular
	sun.shadow_opacity = v.shadow_opacity
	fill.rotation = Vector3(deg_to_rad(v.fill_pitch), deg_to_rad(body.y + 180.0), 0)
	fill.light_color = v.fill * tint
	fill.light_energy = v.fill_energy
	fill.visible = v.fill_energy > 0.01
	env.ambient_light_color = v.ambient * tint
	env.ambient_light_energy = v.ambient_energy
	env.tonemap_exposure = v.exposure
	env.adjustment_enabled = true
	env.adjustment_contrast = v.contrast
	env.adjustment_saturation = v.saturation
	env.glow_intensity = v.glow_intensity
	env.glow_hdr_threshold = v.glow_threshold
	env.fog_light_color = v.fog * tint
	env.fog_density = v.fog_density
	env.fog_sun_scatter = v.fog_sun
	if env.volumetric_fog_enabled:
		env.volumetric_fog_albedo = v.fog
		env.volumetric_fog_density = v.vol_fog
	# Himmel nur neu, wenn sich etwas sichtbar geändert hat (rechnet die Umgebungskarte neu)
	if absf(hour - _last) > 0.02 or _last < 0.0:
		_last = hour
		var sky := {
			"top_color": v.sky_top, "mid_color": v.sky_mid, "horizon_color": v.sky_horizon,
			"ground_color": v.ground_bottom, "glow_color": v.glow_color, "glow": v.glow, "stars": v.stars,
			"sun_dir": _dir(sp), "moon_dir": _dir(mp), "sun_color": v.sun, "moon_color": Color("dfe6ff"),
			"moon_energy": v.moon_energy, "moon_size": v.moon_size, "sun_energy": v.sun_energy_sky if sp.x > -2.0 else 0.0,
			"cloud_lit": v.glow_color, "cloud_dark": v.sky_mid.darkened(0.45), "clouds": 0.6,
		}
		for k in sky:
			_sky_mat.set_shader_parameter(k, sky[k])
	if _grade_mat != null:
		for k in ["shadow_tint", "highlight_tint", "haze_color", "haze", "haze_reach", "haze_low", "brightness"]:
			if v.has(k):
				_grade_mat.set_shader_parameter(k, v[k])
		_grade_mat.set_shader_parameter("saturation", v.saturation_grade)
	if on_night.is_valid():
		on_night.call(float(v.n))
