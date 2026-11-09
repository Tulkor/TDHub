class_name EeveScenery
extends Node3D
## Umgebung der eeveTD-Karte: Wald rund um das Spielfeld (Bäume, Unterholz, Waldboden), Friedhof mit Kirche, Bergwerk, Laternen an
## Spawn, Wegpunkten und Ziel und die Nachtvariante (Mondlicht, leuchtende Laternen, Glühwürmchen).
## Rein optisch: läuft bei jedem Spieler gleich (fester Zufallsstartwert), nichts davon geht über das Netz.

const N := "res://assets/models/nature/%s.glb"
## Bäume: [Modell, Höhe von, Höhe bis, Gewicht]
const TREES := [
	["pine_1", 3.6, 5.6, 3.0], ["pine_2", 3.4, 5.2, 3.0], ["pine_3", 3.8, 6.0, 2.0], ["pine_5", 3.0, 4.6, 2.0],
	["common_tree_3", 3.2, 4.8, 1.5], ["common_tree_4", 3.4, 5.0, 1.5], ["common_tree_5", 3.0, 4.6, 1.5],
]
## Unterholz am Waldrand: [Modell, Größe von, Größe bis, Gewicht]
const UNDERGROWTH := [
	["bush_common", 0.9, 1.5, 3.0], ["bush_common_flowers", 0.9, 1.4, 1.5], ["fern_1", 0.7, 1.2, 3.0],
	["plant_1", 0.6, 1.0, 1.5], ["plant_7", 0.6, 1.0, 1.5], ["mushroom_red_group", 0.35, 0.55, 0.8],
	["mushroom_tan_group", 0.35, 0.55, 0.8], ["mushroom_common", 0.3, 0.5, 0.6], ["rock_medium_1", 0.6, 1.1, 0.8],
	["rock_medium_2", 0.6, 1.1, 0.8], ["flower_3_group", 0.4, 0.7, 1.0],
	# handgemalte Pflanzen (Yughues, Karten mit Alpha)
	["hp_bush011", 0.8, 1.3, 1.2], ["hp_bush021", 0.8, 1.2, 0.6], ["hp_bush031", 0.8, 1.3, 1.2],
	["hp_bush041", 0.7, 1.1, 0.4], ["hp_clovers", 0.4, 0.7, 1.2], ["hp_flower1", 0.4, 0.7, 0.8],
	["hp_flower3", 0.4, 0.7, 0.8], ["hp_grass001", 0.4, 0.7, 1.5], ["hp_weed011", 0.4, 0.7, 1.0],
	["hp_weed031", 0.4, 0.7, 1.0],
]
## Alter Friedhof mit Kirche auf einer Lichtung rechts neben der Karte (Kenney Graveyard Kit, Kirche von
## Daniel74, beide CC0), dort sieht man ihn aus der Startkamera. Mitte als Anteil der Kartenhöhe.
const S := "res://assets/models/scenery/%s.glb"
const GRAVEYARD_Y := 0.74
const CLEARING := Vector2(6.0, 5.0)  ## halbe Länge am Rand, Tiefe der Gräberreihen
## Kleines Bergwerk mit Lore rechts unten neben der Karte, unterhalb des Friedhofs ("Free Mine Assets Pack", CC0).
const MINE_Y := 1.02
## Zaun und Laternen im Paket mintgrün: dunkles Eisen wie die Laternen an den Wegpunkten.
const IRON := Color(0.38, 0.36, 0.42)
const GRAVES := [
	"gravestone_cross", "gravestone_round", "gravestone_bevel", "gravestone_broken", "gravestone_decorative",
	"gravestone_wide", "gravestone_cross_large", "cross_wood", "grave", "urn_round",
]
## Wie tief der Wald um die Karte reicht (Einheiten) und wie weit der Waldboden.
const DEPTH := 26.0
const FLOOR_MARGIN := 90.0
## Bis zu diesem Abstand vom Rand werfen Bäume Schatten (weiter weg sieht man sie kaum, spart Leistung).
const SHADOW_DEPTH := 6.0

## Farbe, mit der Bäume und Unterholz multipliziert werden.
const FOREST_TINT := Color(0.6, 0.66, 0.55)

const LANTERN_LIGHT := Color("ff6e14")
const POOL_LIGHT := Color(1.0, 0.5, 0.12)
const POOL_SIZE := 7.0
## Länge des Auslegers, an dem die Laterne hängt
const ARM := 0.42
const POOL_SHADER := "res://assets/shaders/lantern_pool.gdshader"
## Dünner Bodennebel über Friedhof und Bergwerk: [Höhe, Dichte] je Schicht, Farbe bei Tag und Nacht.
const MIST_SHADER := "res://assets/shaders/ground_mist.gdshader"
const MIST_LAYERS := [[0.1, 0.32], [0.4, 0.22], [0.8, 0.15], [1.3, 0.09]]
const MIST_DAY := Color(0.86, 0.88, 0.92)
const MIST_NIGHT := Color(0.5, 0.56, 0.72)

## Nacht (FieldStyle.night): Licht und Nebel stehen in FieldStyle ("env_night" von Druidenhain), dazu hier
## Bodennebel und kühlerer, dunklerer Boden und Wald (Faktoren auf die Tagwerte).
const NIGHT_EXTRA := {
	"fog_height": 0.6, "fog_height_density": 0.05,
	"ground_tint": Vector3(0.72, 0.8, 1.0), "ground_brightness": 0.7, "forest_tint": Color(0.5, 0.56, 0.78),
	# nachts mehr Struktur im Gras und große hellere und dunklere Flecken wie Mondlicht durch Wolken,
	# sonst wirkt das Feld wie eine einheitlich blaue Fläche
	"ground_contrast": 0.7, "ground_macro": 0.45,
}

var board: Board3D
var map: MapData
var _env: Environment
var _lights_env: Array = []  ## Sonne/Mond und Gegenlicht aus CameraRig.add_environment
var _ground_day := []   ## [tint, brightness, grass_contrast, macro] des Spielfeldbodens am Tag
var _forest_mats := []  ## [Material, Tagesfarbe] der Bäume und Büsche
var _prop_mats := {}    ## [Originalmaterial, Tönung] -> abgedunkelte Kopie (Friedhof)
var _lights: Array[OmniLight3D] = []
var _shadow_mmis: Array[MultiMeshInstance3D] = []  ## Bäume nah am Rand mit Schatten (Grafik „Niedrig“: ohne)
var _pools: Array[MeshInstance3D] = []
var _glass_mat: StandardMaterial3D
var _fireflies: CPUParticles3D
var _mist_mats: Array[ShaderMaterial] = []
## Laternen mit eigenem Flackern: [Licht, Glasmaterial, Lichtfleck-Material oder null, Startwert]
var _lamps: Array = []
var _fires: Array[Feuer] = []
## Tageszeit, die im Spiel weiterläuft (DayCycle); null = fest Tag oder Nacht wie bisher
var cycle: DayCycle
var _night := 1.0  ## wie viel Nacht gerade ist (0 Tag … 1 Nacht)
var _lamp := 1.0   ## wie hell die Laternen gerade brennen (0 aus … 1 Nacht)
var _ambience := ""
var _rng := RandomNumberGenerator.new()


## Wald und Laternen neben das Spielfeld von game setzen und Tag oder Nacht einstellen.
static func add_to(game: Node) -> EeveScenery:
	var s := EeveScenery.new()
	s.board = game.board
	s.map = game.map
	for c in game.get_children():
		if c is WorldEnvironment:
			s._env = c.environment
		elif c is DirectionalLight3D:
			s._lights_env.append(c)
	game.add_child(s)
	return s


func _ready() -> void:
	_rng.seed = hash(map.id) if map.id != "" else 7
	var gm: ShaderMaterial = board._ground_mat
	var tint = gm.get_shader_parameter("tint")
	var bright = gm.get_shader_parameter("brightness")
	var contrast = gm.get_shader_parameter("grass_contrast")
	var macro = gm.get_shader_parameter("macro")
	_ground_day = [tint if tint is Vector3 else Vector3.ONE, float(bright) if bright != null else 0.72,
		float(contrast) if contrast != null else 1.0, float(macro) if macro != null else 0.12]
	_add_forest_floor()
	_add_forest()
	_add_graveyard()
	_add_mine()
	_add_mist()
	_add_lanterns()
	_add_fires()
	_add_fireflies()
	# Laternen beleuchten Tower und Gegner, den Boden nur über ihren Lichtfleck (Ebene 2 ausgenommen)
	board._ground.layers = 2
	_apply(FieldStyle.night)
	Display.quality_changed.connect(_on_quality_changed)


func _on_quality_changed() -> void:
	_apply_mix(_night)


## Tageszeit laufen lassen (eeveTD, YouTD): Licht, Himmel, Nebel und Bildfilter folgen der Uhr, die Szenerie
## (Laternen, Wald, Glühwürmchen) der Dunkelheit. Startet bei hour (Standard kurz vor Sonnenuntergang).
func start_cycle(hour := DayCycle.START) -> void:
	if cycle == null:
		cycle = DayCycle.new()
		cycle.name = "DayCycle"
		add_child(cycle)
		cycle.on_night = _apply_mix
	cycle.hour = hour
	if DayCycle.fixed_hour >= 0.0:
		cycle.hour = DayCycle.fixed_hour
		cycle.speed = 0.0
	_attach_cycle()


func _attach_cycle() -> void:
	var made := {"env": _env, "sun": sun(), "fill": null}
	for l in _lights_env:
		if not l.shadow_enabled:
			made.fill = l
	cycle.attach(made, get_parent())
	if made.fill == null:
		_lights_env.append(cycle.fill)


## Laternen flackern: Licht, Glas und Lichtfleck im selben Takt, jede Laterne eigen.
func _process(_delta: float) -> void:
	if _lamp <= 0.02:
		return
	var t := Time.get_ticks_msec() * 0.001
	for l in _lamps:
		var f := Feuer.flicker(t, l[3])
		var light: OmniLight3D = l[0]
		if light.visible:
			light.light_energy = light.get_meta("energy", light.light_energy) * f * _lamp
		if l[1] != null:
			l[1].emission_energy_multiplier = lerpf(0.35, 2.2, _lamp) * (0.75 + 0.25 * f)
		if l[2] != null:
			l[2].set_shader_parameter("strength", 0.42 * _lamp * f)


func _exit_tree() -> void:
	Sfx.set_ambience("")


## Zwischen Tag und Nacht umschalten (Debug-Menü, Tests): mit laufender Tageszeit springt die Uhr auf
## Mitternacht bzw. Mittag, sonst baut CameraRig.add_environment Licht und Himmel neu aus FieldStyle.env().
func set_night(on: bool) -> void:
	if cycle != null:
		cycle.set_hour(DayCycle.NIGHT_HOUR if on else DayCycle.DAY_HOUR)
		return
	if on != FieldStyle.night:
		FieldStyle.night = on
		var game := get_parent()
		for c in game.get_children():
			if c is WorldEnvironment or c is DirectionalLight3D:
				game.remove_child(c)
				c.queue_free()
		var made: Dictionary = CameraRig.add_environment(game)
		_env = made.env
		_lights_env = [made.sun]
		if made.get("fill") != null:
			_lights_env.append(made.fill)
	_apply(on)


## Sonne bzw. Mond (das Licht mit Schatten) für Tests und Debug.
func sun() -> DirectionalLight3D:
	for l in _lights_env:
		if l.shadow_enabled:
			return l
	return null


func _apply(on: bool) -> void:
	_apply_mix(1.0 if on else 0.0)


## Szenerie zur Dunkelheit n (0 Tag, 1 Nacht; Tageszeit mischt dazwischen): Boden, Wald, Nebel, Laternen.
func _apply_mix(n: float) -> void:
	_night = n
	var on := n >= 0.5
	# Hintergrund: Vögel am Tag, tiefes Geisterheulen in der Nacht (data/sfx.json)
	var amb := "amb_night" if on else "amb_forest"
	if amb != _ambience:
		_ambience = amb
		Sfx.set_ambience(amb)
	if _env != null:
		_env.fog_height = lerpf(0.0, NIGHT_EXTRA.fog_height, n)
		_env.fog_height_density = lerpf(0.0, NIGHT_EXTRA.fog_height_density, n)
	var gm: ShaderMaterial = board._ground_mat
	gm.set_shader_parameter("tint", _ground_day[0] * Vector3.ONE.lerp(NIGHT_EXTRA.ground_tint, n))
	gm.set_shader_parameter("brightness", _ground_day[1] * lerpf(1.0, NIGHT_EXTRA.ground_brightness, n))
	gm.set_shader_parameter("grass_contrast", lerpf(_ground_day[2], maxf(_ground_day[2], NIGHT_EXTRA.ground_contrast), n))
	gm.set_shader_parameter("macro", lerpf(_ground_day[3], NIGHT_EXTRA.ground_macro, n))
	var forest: Color = Color.WHITE.lerp(NIGHT_EXTRA.forest_tint, n)
	for m in _forest_mats:
		m[0].albedo_color = m[1] * forest
	# Grafik „Niedrig“: Laternen ohne echtes Licht (jedes Licht zeichnet die Modelle in seiner Nähe noch einmal),
	# der Lichtfleck am Boden bleibt; Bäume ohne Schatten
	var low := Display.quality == Display.LOW
	# Laternen gehen in der Dämmerung an (ab etwa einem Drittel Dunkelheit), voll erst in der Nacht
	var lamp := clampf((n - 0.25) / 0.6, 0.0, 1.0)
	for l in _lights:
		if not l.has_meta("energy"):
			l.set_meta("energy", l.light_energy)
		l.visible = lamp > 0.0 and not low
		l.light_energy = l.get_meta("energy") * lamp
	for m in _shadow_mmis:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for p in _pools:
		p.visible = lamp > 0.0
	for l in _lamps:
		if l[1] != null:
			l[1].emission_energy_multiplier = lerpf(0.35, 2.2, lamp)
		if l[2] != null:
			l[2].set_shader_parameter("strength", 0.42 * lamp)
	_lamp = lamp
	for f in _fires:
		# Feuer brennen immer, ihr Licht sieht man erst, wenn es dunkel wird
		f.set_lit(clampf(0.25 + n, 0.0, 1.0))
	_fireflies.emitting = n > 0.6
	_fireflies.visible = n > 0.6
	for m in _mist_mats:
		m.set_shader_parameter("mist_color", MIST_DAY.lerp(MIST_NIGHT, n))


func _size() -> Vector2:
	return Vector2(map.width, map.height) * Board3D.CELL


## Waldboden um die Karte: derselbe Boden-Shader wie das Spielfeld, nur Gras und etwas dunkler.
func _add_forest_floor() -> void:
	var size := _size()
	var floor := MeshInstance3D.new()
	if board.path_depth > 0.0:
		floor.mesh = frame_mesh(size, FLOOR_MARGIN)
	else:
		var plane := PlaneMesh.new()
		plane.size = size + Vector2.ONE * FLOOR_MARGIN * 2.0
		floor.mesh = plane
	var mat: ShaderMaterial = board._ground_mat.duplicate()
	var none := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	none.fill(Color.BLACK)
	mat.set_shader_parameter("splat", ImageTexture.create_from_image(none))
	mat.set_shader_parameter("ground_alpha", 1.0)
	mat.set_shader_parameter("brightness", float(mat.get_shader_parameter("brightness")) * 0.72)
	mat.set_shader_parameter("tint", Vector3(0.82, 0.95, 0.72))
	floor.material_override = mat
	floor.position = Vector3(size.x / 2.0, -0.02, size.y / 2.0)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor.layers = 2
	add_child(floor)


## Boden nur als Rahmen der Breite m um die Karte (Schlucht: unter der Karte darf nichts den abgesenkten Weg
## verdecken; auch für Randgruppen TD).
static func frame_mesh(size: Vector2, m: float) -> ArrayMesh:
	var o := size / 2.0  # Mitte, das Mesh liegt wie die Fläche um die Kartenmitte
	var rects := [Rect2(-m, -m, size.x + 2 * m, m), Rect2(-m, size.y, size.x + 2 * m, m),
			Rect2(-m, 0, m, size.y), Rect2(size.x, 0, m, size.y)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rects:
		var a := Vector3(r.position.x - o.x, 0, r.position.y - o.y)
		var b := a + Vector3(r.size.x, 0, 0)
		var c := a + Vector3(r.size.x, 0, r.size.y)
		var d := a + Vector3(0, 0, r.size.y)
		for v in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	st.generate_tangents()
	return st.commit()


## Abstand eines Punkts zum Rand der Karte (0 innerhalb).
func _outside(p: Vector2) -> float:
	var size := _size()
	var dx := maxf(maxf(-p.x, p.x - size.x), 0.0)
	var dy := maxf(maxf(-p.y, p.y - size.y), 0.0)
	return Vector2(dx, dy).length()


func _pick(list: Array) -> int:
	var total := 0.0
	for e in list:
		total += float(e[3])
	var r := _rng.randf() * total
	for i in list.size():
		r -= float(list[i][3])
		if r <= 0.0:
			return i
	return list.size() - 1


func _add_forest() -> void:
	var size := _size()
	# Pro Modell zwei Listen (nah mit Schatten, fern ohne): [Transform3D, ...]
	var trees := {}
	var step := 1.45
	var y := -DEPTH
	while y < size.y + DEPTH:
		var x := -DEPTH
		while x < size.x + DEPTH:
			var p := Vector2(x, y) + Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)) * step
			var d := _outside(p)
			x += step
			# erste Reihe dicht am Rand, nach außen lichter; ganz am Rand Platz fürs Unterholz
			if d < 0.9 or d > DEPTH or _in_clearing(p):
				continue
			if _rng.randf() > lerpf(0.9, 0.45, d / DEPTH):
				continue
			var i := _pick(TREES)
			# am Rand niedrig, damit Bäume Spawn, Ziel und Tower am Kartenrand nicht verdecken, nach außen höher
			var h := _rng.randf_range(TREES[i][1], TREES[i][2]) * lerpf(0.45, 1.0, clampf((d - 1.0) / 6.0, 0.0, 1.0)) \
					* lerpf(1.0, 1.35, d / DEPTH)
			var key := "%s|%d" % [TREES[i][0], 1 if d < SHADOW_DEPTH else 0]
			trees.get_or_add(key, []).append(_place(p, h))
		y += step
	# Unterholz in einem schmalen Streifen direkt am Rand
	step = 0.75
	y = -4.0
	while y < size.y + 4.0:
		var x := -4.0
		while x < size.x + 4.0:
			var p := Vector2(x, y) + Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)) * step
			var d := _outside(p)
			x += step
			if d < 0.25 or d > 4.0 or _rng.randf() > lerpf(0.75, 0.15, d / 4.0):
				continue
			var i := _pick(UNDERGROWTH)
			var key := "%s|1" % UNDERGROWTH[i][0]
			trees.get_or_add(key, []).append(_place(p, _rng.randf_range(UNDERGROWTH[i][1], UNDERGROWTH[i][2])))
		y += step
	for key in trees:
		var parts: PackedStringArray = key.split("|")
		_add_multimesh(N % parts[0], trees[key], parts[1] == "1")


## Punkt auf der Lichtung: u längs des Kartenrands, v Abstand vom Rand nach außen.
func _gy(u: float, v: float) -> Vector2:
	return Vector2(_size().x + v, _size().y * GRAVEYARD_Y + u)


## Wie _gy, aber für das Bergwerk.
func _my(u: float, v: float) -> Vector2:
	return Vector2(_size().x + v, _size().y * MINE_Y + u)


func _in_clearing(p: Vector2) -> bool:
	var c := _gy(0.0, 0.0)
	if absf(p.y - c.y) < CLEARING.x and p.x > c.x and p.x < c.x + CLEARING.y * 1.9:
		return true
	var m := _my(0.0, 0.0)
	return absf(p.y - m.y) < 4.5 and p.x > m.x and p.x < m.x + 6.0


func _add_graveyard() -> void:
	# Modelle schauen mit der Vorderseite zur Karte (Richtung -x)
	var face := -PI / 2.0
	_prop(S % "church", _gy(1.5, CLEARING.y + 2.6), 8.0, face + PI)
	_prop(S % "crypt", _gy(-4.2, CLEARING.y + 0.6), 2.0, face + 0.3)
	# Gräber in drei lockeren Reihen zwischen Kirche und Kartenrand
	for row in 3:
		var v := CLEARING.y - 0.6 - row * 1.1
		var u := -3.4
		while u < 3.5:
			if _rng.randf() < 0.8:
				var name: String = GRAVES[_rng.randi() % GRAVES.size()]
				var at := _gy(u + _rng.randf_range(-0.2, 0.2), v + _rng.randf_range(-0.2, 0.2))
				_prop(S % name, at, _rng.randf_range(0.6, 0.85), face + _rng.randf_range(-0.25, 0.25))
			u += 1.1
	# Eisenzaun zum Spielfeld hin, in der Mitte ein Durchgang mit zwei Laternen
	var fv := 1.4
	var u := -CLEARING.x + 1.0
	while u < CLEARING.x - 1.0:
		if absf(u) > 0.9:
			_prop(S % ("iron_fence_damaged" if _rng.randf() < 0.25 else "iron_fence"), _gy(u, fv), 1.0, face, IRON)
		u += 1.0
	for side in [-1.0, 1.0]:
		var at := _gy(side * 0.9, fv)
		_prop(S % "lightpost_single", at, 1.6, face, IRON)
		_lights.append(_lamp_light(Vector3(at.x, 1.35, at.y)))


func _add_mine() -> void:
	var face := -PI / 2.0  # Vorderseite zur Karte (Richtung -x)
	# Felsen und Steinspitzen als Hang, aus dem die Schienen kommen
	_prop(S % "mine_stalags_5", _my(0.0, 6.2), 3.2, 0.0)
	_prop(S % "mine_stalag_3", _my(-1.7, 5.6), 2.4, 1.0)
	_prop(S % "mine_stalag_3", _my(1.9, 6.0), 2.8, 2.5)
	_prop(S % "mine_rocks_1", _my(-2.6, 4.3), 1.7, 0.4)
	_prop(S % "mine_rocks_5", _my(2.6, 3.9), 1.7, 2.0)
	# Gleis zum Spielfeld hin, die Lore darauf
	for i in 4:
		_prop(S % "mine_rail", _my(0.0, 5.0 - i), 1.02, face)
	_prop(S % "mine_rail_end", _my(0.0, 1.0), 1.0, face)
	_prop(S % "mine_cart", _my(0.0, 3.4), 1.15, face)
	_prop(S % "mine_chest", _my(-2.0, 2.2), 0.7, face + 0.4)
	_prop(S % "mine_coins", _my(-1.3, 1.6), 0.45, 0.0)
	# zwei Stützen mit hängenden Laternen neben dem Gleis, nachts warm beleuchtet
	for side in [-1.0, 1.0]:
		var at := _my(side * 1.3, 4.4)
		_prop(S % "mine_frame_1", at, 2.2, face)
		var lamp := _my(side * 1.3, 4.4 - 0.7)
		_prop(S % "mine_lamp_hanging", lamp, 0.6, 0.0, Color.WHITE, 1.45)
		_lights.append(_lamp_light(Vector3(lamp.x, 1.55, lamp.y)))


## Feuer (Feuer, WoW-Stil): zwei Feuerschalen vor dem Friedhofstor und ein Lagerfeuer am Bergwerk.
func _add_fires() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("2c2a30")
	iron.metallic = 0.7
	iron.roughness = 0.5
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color("1a0c08")
	coal.emission_enabled = true
	coal.emission = Color("ff4a10")
	coal.emission_energy_multiplier = 1.6
	coal.roughness = 1.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("3a2a1e")
	wood.roughness = 0.9
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("55524e")
	stone.roughness = 0.95
	var i := 0
	for side in [-1.0, 1.0]:
		var at := _gy(side * 1.35, 0.3)
		var root := Node3D.new()
		root.position = Vector3(at.x, 0, at.y)
		add_child(root)
		# Schale auf drei Beinen
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var leg := _part(root, _box(Vector3(0.05, 0.62, 0.05)), iron, Vector3(cos(a) * 0.17, 0.3, sin(a) * 0.17))
			leg.rotation = Vector3(sin(a) * 0.22, 0, -cos(a) * 0.22)
		_part(root, _cyl(0.3, 0.16, 0.18), iron, Vector3(0, 0.66, 0))
		_part(root, _cyl(0.26, 0.26, 0.04), coal, Vector3(0, 0.74, 0))
		ContactShadow.add(root, 0.3)
		var f := Feuer.make(0.95, 7.0 + i * 3.3, 5.0, 4.5)
		f.position.y = 0.72
		root.add_child(f)
		# Lichtfleck auf den Boden, nicht auf die Schale
		f.pool.position.y = 0.03 - 0.72
		_fires.append(f)
		i += 1
	# Lagerfeuer: Steinkreis, gekreuzte Scheite, Glut
	var at := _my(2.0, 1.9)
	var camp := Node3D.new()
	camp.position = Vector3(at.x, 0, at.y)
	add_child(camp)
	for k in 9:
		var a := TAU * k / 9.0
		var st := _part(camp, _box(Vector3(0.16, 0.1, 0.12)), stone, Vector3(cos(a) * 0.36, 0.05, sin(a) * 0.36))
		st.rotation.y = -a
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		var log := _part(camp, _cyl(0.035, 0.045, 0.5), wood, Vector3(cos(a) * 0.1, 0.12, sin(a) * 0.1))
		log.basis = Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 1.15)
	_part(camp, _cyl(0.2, 0.24, 0.05), coal, Vector3(0, 0.03, 0))
	ContactShadow.add(camp, 0.45)
	var cf := Feuer.make(1.1, 21.0, 6.0, 5.5)
	cf.position.y = 0.05
	camp.add_child(cf)
	_fires.append(cf)


## Nebelschwaden über Friedhof und Bergwerk (eine Fläche über beide Lichtungen, mehrere Schichten übereinander).
func _add_mist() -> void:
	var a := _gy(-CLEARING.x - 0.5, 0.8)
	var b := _my(5.0, CLEARING.y + 6.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(b.x - a.x, b.y - a.y)
	var shader: Shader = load(MIST_SHADER)
	for i in MIST_LAYERS.size():
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("density", MIST_LAYERS[i][1])
		m.set_shader_parameter("seed", float(i) * 17.3)
		m.set_shader_parameter("wind", Vector2(0.05, 0.025) * (1.0 + i * 0.35))
		m.render_priority = i
		_mist_mats.append(m)
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3((a.x + b.x) / 2.0, MIST_LAYERS[i][0], (a.y + b.y) / 2.0)
		add_child(mi)


func _lamp_light(at: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = LANTERN_LIGHT
	light.light_energy = 1.6
	light.omni_range = 3.5
	light.position = at
	add_child(light)
	_lamps.append([light, null, null, float(_lamps.size()) * 1.7 + 0.3])
	return light


## Einzelnes Modell mit größter Kante size, wie der Wald abgedunkelt (auch nachts über _forest_mats).
func _prop(path: String, at: Vector2, size: float, rot: float, tint := Color.WHITE, y := 0.0) -> void:
	var model := ModelLoader.instantiate(path, size)
	if model == null:
		return
	model.position = Vector3(at.x, y, at.y)
	model.rotation.y = rot
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat = mi.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				var key := [mat, tint]
				if not _prop_mats.has(key):
					var dark: BaseMaterial3D = mat.duplicate()
					dark.albedo_color *= FOREST_TINT * tint
					_forest_mats.append([dark, dark.albedo_color])
					_prop_mats[key] = dark
				mi.set_surface_override_material(i, _prop_mats[key])
	add_child(model)


## Lage eines Modells mit Höhe (bzw. größter Kante) h: gedreht, leicht schief.
func _place(p: Vector2, h: float) -> Transform3D:
	var b := Basis(Vector3.UP, _rng.randf() * TAU)
	b = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.06)) * b
	return Transform3D(b.scaled(Vector3.ONE * h), Vector3(p.x, 0.0, p.y))


func _add_multimesh(path: String, xfs: Array, shadows: bool) -> void:
	var m := ModelLoader.mesh_with_transform(path, 1.0)
	if m.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _muted(m[0])
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i] * m[1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shadows:
		_shadow_mmis.append(mmi)
	add_child(mmi)


## Kopie des Meshes mit abgedunkelten Materialien: die Modelle sind satter als der Boden (Druidenhain
## entsättigt), der Wald soll hinter Spielfeld und Towern zurücktreten.
func _muted(mesh: Mesh) -> Mesh:
	var copy: Mesh = mesh.duplicate()
	for i in copy.get_surface_count():
		var mat := copy.surface_get_material(i)
		if mat is BaseMaterial3D:
			var dark: BaseMaterial3D = mat.duplicate()
			dark.albedo_color *= FOREST_TINT
			_forest_mats.append([dark, dark.albedo_color])
			copy.surface_set_material(i, dark)
	return copy


## Eine Laterne an jedem Wegpunkt (Spawn, Checkpoints, Ziel): Holzpfosten mit Messinglaterne in der Ecke
## des Wegpunkts, die von den Wegen wegzeigt.
## Ein Pixel pro Feld, R = 1 in der Schlucht (Board3D.is_sunken), für die Lichtflecken.
func _level_mask() -> Texture2D:
	var img := Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
	for y in map.height:
		for x in map.width:
			if board.is_sunken(Vector2i(x, y)):
				img.set_pixel(x, y, Color.RED)
	return ImageTexture.create_from_image(img)


func _add_lanterns() -> void:
	# schwarzes Eisen wie die Laternenpfähle in Duskwood
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("34303a")
	wood.metallic = 0.6
	wood.roughness = 0.55
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("2a2620")
	brass.metallic = 0.75
	brass.roughness = 0.4
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(1.0, 0.63, 0.31, 0.55)
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.emission_enabled = true
	_glass_mat.emission = LANTERN_LIGHT
	var pool_shader: Shader = load(POOL_SHADER)
	var pts := map.all_waypoints()
	var lanes: Array = []
	for lane in map.lane_count():
		lanes.append(map.waypoints(lane))
	var n := 0
	var mask: Texture2D = null
	for c in pts:
		var at := board.cell_center(c)
		var corner := _free_corner(c, lanes)
		var foot: Vector2 = at + corner * (float(map.marker_radius) + 0.5) * Board3D.CELL * 1.15
		var root := Node3D.new()
		root.position = Vector3(foot.x, 0, foot.y)
		add_child(root)
		# Pfosten mit Ausleger zur Wegmitte, die Laterne hängt daran: so beleuchtet sie den Pfosten von der Seite,
		# und der Pfosten wirft im Lichtfleck einen Schatten von der Laterne weg (wie in Duskwood)
		var arm := -corner.normalized() * ARM
		var lamp := Vector3(arm.x, 1.32, arm.y)
		_part(root, _cyl(0.045, 0.07, 1.6), wood, Vector3(0, 0.8, 0))
		_part(root, _cyl(0.09, 0.11, 0.08), wood, Vector3(0, 0.04, 0))
		var beam := _part(root, _box(Vector3(0.035, 0.035, ARM + 0.06)), wood, Vector3(arm.x / 2.0, 1.56, arm.y / 2.0))
		beam.rotation.y = atan2(arm.x, arm.y)
		_part(root, _cyl(0.008, 0.008, 0.1), wood, lamp + Vector3(0, 0.19, 0))
		_part(root, _box(Vector3(0.16, 0.035, 0.16)), brass, lamp + Vector3(0, -0.12, 0))
		# Glas je Laterne (eigenes Flackern), halb durchsichtig: drinnen brennt eine kleine Flamme
		var glass := _glass_mat.duplicate() as StandardMaterial3D
		_part(root, _box(Vector3(0.12, 0.2, 0.12)), glass, lamp)
		var flame := Feuer.make(0.13, float(n) * 2.9 + 0.5, 0.0, 0.0, false)
		flame.position = lamp + Vector3(0, -0.085, 0)
		root.add_child(flame)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_part(root, _box(Vector3(0.022, 0.22, 0.022)), brass, lamp + Vector3(sx * 0.068, 0, sz * 0.068))
		_part(root, _cyl(0.0, 0.11, 0.1), brass, lamp + Vector3(0, 0.15, 0))
		ContactShadow.add(root, 0.22)
		var light := OmniLight3D.new()
		light.light_color = LANTERN_LIGHT
		light.light_energy = 2.4
		light.omni_range = 4.0
		light.omni_attenuation = 1.3
		light.light_cull_mask = 1
		light.shadow_enabled = false
		light.position = lamp
		root.add_child(light)
		_lights.append(light)
		var pool := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE * POOL_SIZE
		pool.mesh = quad
		var pm := ShaderMaterial.new()
		pm.shader = pool_shader
		pm.set_shader_parameter("light_color", POOL_LIGHT)
		# Vulkan rechnet den Fleck in linearem Licht, ohne Abschwächung wirkt er grell orange
		pm.set_shader_parameter("strength", 0.42)
		pm.set_shader_parameter("phase", float(n) * 2.3)
		# Pfosten im Fleck (UV), von dort fällt sein Schatten von der Laterne weg
		pm.set_shader_parameter("post_uv", Vector2(0.5, 0.5) - arm / POOL_SIZE)
		# Der Boden ist durchsichtig (ALPHA) und wird nach Abstand sortiert: Lichtflecken immer danach zeichnen
		pm.render_priority = 2
		pool.material_override = pm
		# Flackern übernimmt _process (gleicher Takt wie Licht und Glas)
		pm.set_shader_parameter("flicker", 0.0)
		_lamps.append([light, glass, pm, float(n) * 2.9 + 0.5])
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.position = Vector3(foot.x + arm.x, 0.03, foot.y + arm.y)
		add_child(pool)
		_pools.append(pool)
		if board.path_depth > 0.0:
			# Schlucht: derselbe Fleck noch einmal unten, jeder nur über den Feldern seiner Höhe
			if mask == null:
				mask = _level_mask()
			pm.set_shader_parameter("level", 0.0)
			var low := pool.duplicate() as MeshInstance3D
			var lm := pm.duplicate() as ShaderMaterial
			lm.set_shader_parameter("level", 1.0)
			low.material_override = lm
			low.position.y = 0.03 - board.path_depth
			add_child(low)
			_pools.append(low)
			for m in [pm, lm]:
				m.set_shader_parameter("level_mask", mask)
				m.set_shader_parameter("map_size", Vector2(map.width, map.height) * Board3D.CELL)
		n += 1


## Ecke (diagonale Richtung) eines Wegpunkts, die am weitesten von den Wegen dorthin und von dort weg liegt.
func _free_corner(c: Vector2i, lanes: Array) -> Vector2:
	var dirs: Array[Vector2] = []
	for pts in lanes:
		var i: int = pts.find(c)
		if i < 0:
			continue
		if i > 0:
			dirs.append(Vector2(pts[i - 1] - c).normalized())
		if i < pts.size() - 1:
			dirs.append(Vector2(pts[i + 1] - c).normalized())
	if c == map.goal or dirs.is_empty():
		# ohne Weg: die Ecke zur Kartenmitte hin
		dirs.append((Vector2(c) - Vector2(map.width, map.height) / 2.0).normalized())
	var best := Vector2(1, -1)
	var best_score := INF
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var score := -INF
		for d in dirs:
			score = maxf(score, corner.normalized().dot(d))
		# nicht über den Kartenrand hinaus
		var p: Vector2 = Vector2(c) + corner * (map.marker_radius + 1)
		if p.x < 1 or p.y < 1 or p.x > map.width - 2 or p.y > map.height - 2:
			score += 3.0
		if score < best_score:
			best_score = score
			best = corner
	return best


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	# Die Laterne ist selbst die Lichtquelle: ihr Mond-/Sonnenschatten liefe quer durch den eigenen Lichtfleck
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Glühwürmchen am Waldrand unter den Bäumen hervor (nur nachts), nicht mitten über dem Spielfeld,
## damit sie nicht wie die Wegpunkte aussehen.
func _add_fireflies() -> void:
	var size := _size()
	var pts := PackedVector3Array()
	while pts.size() < 400:
		var p := Vector2(_rng.randf_range(-8.0, size.x + 8.0), _rng.randf_range(-8.0, size.y + 8.0))
		var inside := minf(minf(p.x, size.x - p.x), minf(p.y, size.y - p.y))
		var d := _outside(p) if inside < 0.0 else -inside
		if d > -2.0 and d < 2.5:
			pts.append(Vector3(p.x, _rng.randf_range(0.3, 2.4), p.y))
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 140
	_fireflies.lifetime = 5.0
	_fireflies.preprocess = 5.0
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_fireflies.emission_points = pts
	_fireflies.direction = Vector3(0, 1, 0)
	_fireflies.spread = 180.0
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.05
	_fireflies.initial_velocity_max = 0.25
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	_fireflies.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color("e8f080")
	m.emission_enabled = true
	m.emission = Color("d8f060")
	m.emission_energy_multiplier = 5.0
	dot.material = m
	_fireflies.mesh = dot
	_fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fireflies)
