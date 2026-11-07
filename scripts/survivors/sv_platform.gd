class_name SvPlatform
extends Node3D
## Der Turm als Waffenplattform (Lukas 2026-11-04: „man sieht, welche Waffen er ausgerüstet hat“):
## Sockel, sechseckiges Deck mit sechs Montageplätzen an den Ecken, Reaktor-Kern in der Mitte.
## Jeder Platz ist eine sechseckige Klappe (zwei Hälften, Warnstreifen); beim Bau geht sie auf und die
## Waffe fährt auf einer Hebebühne hoch, beim Verkaufen umgekehrt. Leuchtband am Rand: gesperrt rot,
## frei grau, belegt in der Seltenheitsfarbe; Stufen-Lämpchen außen. Alles in Dev-Optik.

## Groß genug, dass Klappen samt versenkten Hälften und die Waffen ganz auf dem Deck liegen (Lukas 2026-11-04)
const PAD_RADIUS := 2.8
const DECK_R := 4.35
const DECK_Y := 3.4
## Mitte des Glasteils im Kern: dort sitzt das Licht
const CORE_Y := DECK_Y + 1.7
const SLOTS := 6
## Waffen etwas größer als ihre Bausteine, damit man sie aus der Spielansicht erkennt
const WEAPON_SCALE := 1.35
## Klappe: Umkreis des Sechsecks, Oberkante, Spaltbreite der Naht, Weg beim Öffnen
const HEX_R := 0.78
const HATCH_TOP := 0.13
const GAP := 0.035
const OPEN_SLIDE := 0.32
const LIFT_DOWN := -1.1
const OPEN_TIME := 0.35
const RISE_TIME := 0.6

var pads: Array = []        ## je Platz: {root, frame, band, lift, mount, halves, pips, phase, t, state}
var core_glow: MeshInstance3D
var _core_mat: StandardMaterial3D
var _core_orb: MeshInstance3D
var _core_light: OmniLight3D
var _beacon: MeshInstance3D
var _beacon_light: OmniLight3D
var _beacon_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	var metal := SvDev.metal(Color("8a909c"))
	var dark := SvDev.metal(Color("4a4f5a"))
	# Fuß, schlanke Säule, die sich nach oben zum Deck hin aufweitet (Lukas 2026-11-04)
	# Fuß reicht ins Wasser des Eislochs
	var foot := _cyl(2.0, 2.3, 1.6, 6, dark)
	foot.position.y = -0.45
	var col := _cyl(DECK_R - 0.35, 1.25, DECK_Y - 0.6, 6, metal)
	col.position.y = 0.35 + (DECK_Y - 0.6) * 0.5 - 0.05
	# Leuchtleisten an den Kanten der Säule
	for k in 6:
		var ang := TAU * k / 6.0
		var bottom := Vector3(sin(ang) * 1.27, 0.4, cos(ang) * 1.27)
		var top := Vector3(sin(ang) * (DECK_R - 0.33), DECK_Y - 0.5, cos(ang) * (DECK_R - 0.33))
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.07, 0.07, bottom.distance_to(top))
		strip.mesh = sm
		strip.material_override = SvDev.glow(UiTheme.CYAN, 3.0)
		add_child(strip)
		strip.look_at_from_position((bottom + top) * 0.5, top, Vector3.UP)

	var deck := _cyl(DECK_R, DECK_R - 0.15, 0.45, 6, SvDev.diamond_plate(Color("a3a8b2")))
	deck.position.y = DECK_Y - 0.22
	_railing()

	# Kern: Glaszylinder mit leuchtendem Inneren, Licht fällt aufs Deck (Farbe zeigt das Leben)
	var ring_lo := _cyl(1.0, 1.05, 0.3, 12, dark)
	ring_lo.position.y = DECK_Y + 0.15
	var ring_hi := _cyl(1.0, 1.0, 0.25, 12, dark)
	ring_hi.position.y = DECK_Y + 2.2
	# untere Hälfte Metall, obere Hälfte Glas (Lukas 2026-11-04)
	var lower := _cyl(0.9, 0.95, 0.95, 12, metal)
	lower.position.y = DECK_Y + 0.75
	var mid := _cyl(1.0, 1.0, 0.12, 12, dark)
	mid.position.y = DECK_Y + 1.22
	var glass := _cyl(0.88, 0.88, 0.95, 24, SvDev.glass())
	glass.position.y = CORE_Y
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_mat = SvDev.glow(UiTheme.CYAN, 8.0).duplicate()
	core_glow = _cyl(0.2, 0.2, 0.85, 12, _core_mat)
	core_glow.position.y = CORE_Y
	var orb := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.34
	om.height = 0.68
	orb.mesh = om
	orb.material_override = _core_mat
	orb.position.y = CORE_Y
	add_child(orb)
	_core_orb = orb
	_core_light = OmniLight3D.new()
	_core_light.light_color = UiTheme.CYAN
	_core_light.light_energy = 3.0
	_core_light.omni_range = 9.0
	_core_light.shadow_enabled = false
	_core_light.position.y = CORE_Y
	add_child(_core_light)
	# Deckel und Antenne mit Blinklicht
	var lid := _cyl(0.7, 1.0, 0.3, 12, metal)
	lid.position.y = DECK_Y + 2.45
	var mast := _cyl(0.06, 0.1, 2.6, 8, dark)
	mast.position.y = DECK_Y + 2.6 + 1.3
	for k in 3:
		var bar := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.9 - k * 0.25, 0.05, 0.05)
		bar.mesh = bm2
		bar.material_override = dark
		bar.position.y = DECK_Y + 3.2 + k * 0.55
		bar.rotation.y = k * 0.6
		add_child(bar)
	_beacon = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.13
	bs.height = 0.26
	_beacon.mesh = bs
	_beacon_mat = SvDev.glow(Color("ff2a2a"), 6.0).duplicate()
	_beacon.material_override = _beacon_mat
	_beacon.position.y = DECK_Y + 5.25
	add_child(_beacon)
	_beacon_light = OmniLight3D.new()
	_beacon_light.light_color = Color("ff2a2a")
	_beacon_light.omni_range = 4.0
	_beacon_light.position.y = DECK_Y + 5.25
	add_child(_beacon_light)

	for i in SLOTS:
		var a := TAU * float(i) / SLOTS + PI / 6.0
		var root := Node3D.new()
		root.position = Vector3(cos(a), 0, sin(a)) * PAD_RADIUS + Vector3(0, DECK_Y, 0)
		add_child(root)
		var pad := _build_pad(root)
		var pips := Node3D.new()
		# Lämpchen außen am Platz (vom Kern weg)
		pips.position = Vector3(cos(a), 0, sin(a)) * (HEX_R + 0.08) + Vector3(0, 0.02, 0)
		pips.rotation.y = -a + PI / 2.0
		root.add_child(pips)
		pad.root = root
		pad.pips = pips
		pads.append(pad)
		set_state(i, "locked")


# ---------------------------------------------------------------- Klappe

## Ecken des Sechsecks (flache Seite oben/unten in der Spielansicht), als (x, z).
static func hex(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 6:
		var ang := deg_to_rad(60.0 * k)
		out.append(Vector2(cos(ang), sin(ang)) * r)
	return out


## Prisma aus einem konvexen Vieleck (x, z) von y0 bis y1, beidseitig, damit die Umlaufrichtung egal ist.
static func prism(poly: PackedVector2Array, y0: float, y1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := poly.size()
	var tri := func(p1: Vector3, p2: Vector3, p3: Vector3, nrm: Vector3):
		for q in [[p1, p2, p3], [p1, p3, p2]]:
			st.set_normal(nrm)
			st.add_vertex(q[0])
			st.set_normal(nrm)
			st.add_vertex(q[1])
			st.set_normal(nrm)
			st.add_vertex(q[2])
	var c := Vector2.ZERO
	for v in poly:
		c += v
	c /= n
	for k in range(1, n - 1):
		tri.call(Vector3(poly[0].x, y1, poly[0].y), Vector3(poly[k].x, y1, poly[k].y), Vector3(poly[k + 1].x, y1, poly[k + 1].y), Vector3.UP)
	for k in n:
		var p := poly[k]
		var q := poly[(k + 1) % n]
		var mid := (p + q) * 0.5 - c
		var nrm := Vector3(mid.x, 0, mid.y).normalized()
		var a1 := Vector3(p.x, y0, p.y)
		var b1 := Vector3(q.x, y0, q.y)
		var a2 := Vector3(p.x, y1, p.y)
		var b2 := Vector3(q.x, y1, q.y)
		tri.call(a1, b1, b2, nrm)
		tri.call(a1, b2, a2, nrm)
	return st.commit()


static func _mi(mesh: Mesh, mat: Material, parent: Node) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	parent.add_child(m)
	return m


## Sechseckige Klappe nach Lukas' Skizze (2026-11-04): zwei Hälften, Naht von der Ecke oben links zur
## Ecke unten rechts, Warnstreifen quer über die Mitte, an der Naht ein schwarzer Spalt mit hellen
## Kanten. Darunter Schacht und Hebebühne, auf der die Waffe hochfährt.
func _build_pad(root: Node3D) -> Dictionary:
	var h := hex(HEX_R)
	# Rand mit Leuchtband (Zustand: gesperrt, frei, Seltenheitsfarbe)
	var frame := _mi(prism(hex(HEX_R + 0.06), -0.02, 0.05), SvDev.metal(Color("4a4f5a"), 1.0), root)
	var band := _mi(prism(hex(HEX_R + 0.075), 0.0, 0.03), SvDev.flat(Color("3a3f4d")), root)
	frame.name = "Rahmen"
	# Schacht: schwarz, sichtbar, wenn die Klappe offen ist
	_mi(prism(hex(HEX_R - 0.02), 0.05, 0.055), SvDev.flat(Color("07080b")), root)
	var lift := Node3D.new()
	lift.position.y = LIFT_DOWN
	root.add_child(lift)
	_mi(prism(hex(HEX_R - 0.06), -0.08, 0.06), SvDev.diamond_plate(Color("8a909c"), 2.5), lift)
	var mount := Node3D.new()
	mount.position.y = 0.06
	mount.scale = Vector3.ONE * WEAPON_SCALE
	lift.add_child(mount)
	# Naht von Ecke 4 (oben links) zu Ecke 1 (unten rechts)
	var seam := (h[1] - h[4]).normalized()
	var nrm := Vector2(seam.y, -seam.x)
	var halves: Array = []
	for side in [[h[1], h[2], h[3], h[4]], [h[4], h[5], h[0], h[1]]]:
		var poly := PackedVector2Array(side)
		var c := (poly[1] + poly[2]) * 0.5
		var out_dir := nrm if c.dot(nrm) > 0.0 else -nrm
		# Spalt: jede Hälfte um die halbe Spaltbreite von der Naht weg
		var shifted := PackedVector2Array()
		for v in poly:
			shifted.append(v + out_dir * GAP * 0.5)
		var half := Node3D.new()
		root.add_child(half)
		_mi(prism(shifted, 0.04, HATCH_TOP), SvDev.diamond_plate(Color("9a9fa8"), 2.5), half)
		# helle Kante parallel zur Naht (Skizze, Ausschnitt)
		var strip := _strip(shifted, out_dir, 0.05, 0.1)
		if strip.size() >= 3:
			_mi(prism(strip, HATCH_TOP, HATCH_TOP + 0.006), SvDev.metal(Color("c8ccd4"), 1.0), half)
		# Warnstreifen quer über die Mitte
		var cross := PackedVector2Array([Vector2(-2, -0.11), Vector2(2, -0.11), Vector2(2, 0.11), Vector2(-2, 0.11)])
		for part in Geometry2D.intersect_polygons(shifted, cross):
			_mi(prism(part, HATCH_TOP, HATCH_TOP + 0.008), SvDev.hazard(), half)
		halves.append({"node": half, "dir": Vector3(out_dir.x, 0, out_dir.y)})
	var light := OmniLight3D.new()
	light.position.y = 0.9
	light.omni_range = 2.6
	light.light_energy = 0.0
	root.add_child(light)
	return {"frame": frame, "band": band, "lift": lift, "mount": mount, "halves": halves, "light": light,
		"phase": "closed", "t": 0.0, "state": "locked"}


## Streifen der Hälfte zwischen d0 und d1 Abstand von ihrer Nahtkante.
func _strip(poly: PackedVector2Array, out_dir: Vector2, d0: float, d1: float) -> PackedVector2Array:
	var base := poly[0]
	for v in poly:
		if v.dot(out_dir) < base.dot(out_dir):
			base = v
	var along := Vector2(-out_dir.y, out_dir.x)
	var p0 := base + out_dir * d0
	var p1 := base + out_dir * d1
	var rect := PackedVector2Array([p0 - along * 3, p0 + along * 3, p1 + along * 3, p1 - along * 3])
	var r := Geometry2D.intersect_polygons(poly, rect)
	return r[0] if not r.is_empty() else PackedVector2Array()


## state: "locked", "free" oder "armed" (dann color = Seltenheitsfarbe). Färbt das Leuchtband am Rand.
func set_state(i: int, state: String, color := Color.WHITE) -> void:
	var p: Dictionary = pads[i]
	p.state = state
	var c := Color("3a3f4d")
	if state == "locked":
		c = UiTheme.MISSING.darkened(0.45)
	elif state == "armed":
		c = color
	p.band.material_override = SvDev.glow(c, 1.0 if state == "locked" else 1.8)
	# Platzlicht: belegt hell in der Seltenheitsfarbe, gesperrt schwach rot, frei aus
	var light: OmniLight3D = p.light
	light.light_color = c
	light.light_energy = 0.7 if state == "armed" else (0.2 if state == "locked" else 0.0)


func is_up(i: int) -> bool:
	return pads[i].phase == "up"


## Klappe auf, Waffe fährt hoch: Ablauf in step().
func _raise(i: int) -> void:
	var p: Dictionary = pads[i]
	p.phase = "opening"
	p.t = 0.0


## Waffe fährt runter, Klappe zu, dann wird die Waffe entfernt (Verkaufen).
func retract(i: int) -> void:
	var p: Dictionary = pads[i]
	set_level(i, 0, Color.WHITE)
	if p.mount.get_child_count() == 0:
		return
	p.phase = "lowering"
	p.t = 0.0


## Klappen-Ablauf: opening → rising → up, lowering → closing → closed. Läuft im Spieltakt (SvGame.step).
func step(dt: float) -> void:
	for i in pads.size():
		var p: Dictionary = pads[i]
		if p.phase == "closed" or p.phase == "up":
			continue
		p.t += dt
		match p.phase:
			"opening":
				var f := clampf(p.t / OPEN_TIME, 0.0, 1.0)
				_set_open(p, f)
				if f >= 1.0:
					p.phase = "rising"
					p.t = 0.0
			"rising":
				var f := clampf(p.t / RISE_TIME, 0.0, 1.0)
				p.lift.position.y = lerpf(LIFT_DOWN, 0.0, f * f * (3.0 - 2.0 * f))
				if f >= 1.0:
					p.phase = "up"
			"lowering":
				var f := clampf(p.t / RISE_TIME, 0.0, 1.0)
				p.lift.position.y = lerpf(0.0, LIFT_DOWN, f * f * (3.0 - 2.0 * f))
				if f >= 1.0:
					_clear_mount(i)
					p.phase = "closing"
					p.t = 0.0
			"closing":
				var f := clampf(p.t / OPEN_TIME, 0.0, 1.0)
				_set_open(p, 1.0 - f)
				if f >= 1.0:
					p.phase = "closed"


## Klappenhälften: f = 0 zu, 1 ganz offen (auseinander und in das Deck gesenkt).
func _set_open(p: Dictionary, f: float) -> void:
	var slide := clampf(f * 1.4, 0.0, 1.0)
	var sink := clampf(f * 1.4 - 0.4, 0.0, 1.0)
	for hv in p.halves:
		hv.node.position = hv.dir * slide * OPEN_SLIDE + Vector3(0, -sink * 0.32, 0)


## Waffe aufbauen: Drehteller (yaw) mit den Bausteinen aus dem Modell. Gibt den Drehteller zurück.
func mount(i: int, w: Dictionary, colors: Dictionary) -> Node3D:
	var p: Dictionary = pads[i]
	clear(i)
	p.lift.position.y = LIFT_DOWN
	_raise(i)
	var yaw := Node3D.new()
	yaw.name = "Waffe"
	# zum Start nach außen schauen
	var outward: Vector3 = p.root.position
	yaw.rotation.y = atan2(-outward.x, -outward.z)
	p.mount.add_child(yaw)
	var recoil := Node3D.new()
	recoil.name = "Rueckstoss"
	yaw.add_child(recoil)
	for spec in w.get("model", []):
		recoil.add_child(SvDev.part(spec, colors))
	return yaw


## Sofort leeren (ohne Ablauf), Klappe zu.
func clear(i: int) -> void:
	_clear_mount(i)
	set_level(i, 0, Color.WHITE)
	var p: Dictionary = pads[i]
	p.phase = "closed"
	_set_open(p, 0.0)


func _clear_mount(i: int) -> void:
	for c in pads[i].mount.get_children():
		pads[i].mount.remove_child(c)
		c.queue_free()


## Stufen-Lämpchen am Rand des Platzes (1–5).
func set_level(i: int, level: int, color: Color) -> void:
	var pips: Node3D = pads[i].pips
	for c in pips.get_children():
		pips.remove_child(c)
		c.queue_free()
	for k in level:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.1, 0.1, 0.1)
		m.mesh = b
		m.position = Vector3(-0.24 + 0.12 * k, 0.12, 0)
		m.material_override = SvDev.flat(color)
		pips.add_child(m)


func set_health(f: float) -> void:
	var c := UiTheme.MISSING.lerp(UiTheme.CYAN, clampf(f, 0.0, 1.0))
	_core_mat.emission = c
	_core_mat.albedo_color = c
	_core_light.light_color = c


func _process(dt: float) -> void:
	_t += dt
	_core_orb.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.06)
	_core_orb.position.y = CORE_Y + sin(_t * 1.3) * 0.04
	_core_light.light_energy = 4.5 + sin(_t * 3.0) * 0.5
	# Antenne blinkt
	# Antennenspitze: rotes Licht, das immer wieder aufleuchtet und abklingt
	var k := fmod(_t, 1.2) / 1.2
	var f := clampf(1.0 - k * 2.2, 0.0, 1.0)
	_beacon_mat.emission_energy_multiplier = 0.3 + f * 7.0
	_beacon_light.light_energy = f * 2.0


func _cyl(top: float, bottom: float, h: float, seg: int, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	mi.mesh = c
	mi.material_override = m
	add_child(mi)
	return mi


## Geländer am Deckrand: Pfosten, zwei Holme, Warnlämpchen an den Ecken.
func _railing() -> void:
	var r := DECK_R - 0.12
	var m := SvDev.metal(Color("5f86c8"), 1.0)  # Geländer leicht blau
	var corners: Array = []
	for k in 6:
		var ang := TAU * k / 6.0
		corners.append(Vector3(sin(ang) * r, DECK_Y, cos(ang) * r))
	for k in 6:
		var a: Vector3 = corners[k]
		var b: Vector3 = corners[(k + 1) % 6]
		for j in 4:
			var p := a.lerp(b, j / 4.0)
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.08, 0.75, 0.08)
			post.mesh = pm
			post.material_override = m
			post.position = p + Vector3(0, 0.37, 0)
			add_child(post)
		for hgt in [0.72, 0.4]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.06, 0.06, a.distance_to(b))
			rail.mesh = rm
			rail.material_override = m
			add_child(rail)
			rail.look_at_from_position((a + b) * 0.5 + Vector3(0, hgt, 0), b + Vector3(0, hgt, 0), Vector3.UP)
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.08
		lm.height = 0.16
		lamp.mesh = lm
		lamp.material_override = SvDev.glow(UiTheme.COIN, 4.0)
		lamp.position = a + Vector3(0, 0.82, 0)
		add_child(lamp)
