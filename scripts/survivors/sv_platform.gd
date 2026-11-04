class_name SvPlatform
extends Node3D
## Der Turm als Waffenplattform (Lukas 2026-11-04: „man sieht, welche Waffen er ausgerüstet hat“):
## Sockel, sechseckiges Deck mit sechs Montageplätzen an den Ecken, Reaktor-Kern in der Mitte.
## Jeder Platz ist eine sechseckige Klappe (zwei Hälften, Warnstreifen); beim Bau geht sie auf und die
## Waffe fährt auf einer Hebebühne hoch, beim Verkaufen umgekehrt. Leuchtband am Rand: gesperrt rot,
## frei grau, belegt in der Seltenheitsfarbe; Stufen-Lämpchen außen. Alles in Dev-Optik.

const PAD_RADIUS := 1.95
const DECK_Y := 1.5
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
var _t := 0.0


func _ready() -> void:
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 2.3
	bm.bottom_radius = 2.7
	bm.height = 1.3
	bm.radial_segments = 6
	base.mesh = bm
	base.position.y = 0.65
	base.material_override = SvDev.mat(Color("5a6070"))
	add_child(base)

	var deck := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 2.75
	dm.bottom_radius = 2.6
	dm.height = 0.25
	dm.radial_segments = 6
	deck.mesh = dm
	deck.position.y = DECK_Y - 0.12
	deck.material_override = SvDev.mat(Color("8a90a0"))
	add_child(deck)

	# Reaktor-Kern: Säule mit leuchtendem Ring, zeigt über die Farbe das Leben
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.7
	cm.height = 1.5
	cm.radial_segments = 8
	core.mesh = cm
	core.position.y = DECK_Y + 0.75
	core.material_override = SvDev.mat(Color("40465a"))
	add_child(core)
	core_glow = MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.62
	gm.bottom_radius = 0.62
	gm.height = 0.3
	gm.radial_segments = 16
	core_glow.mesh = gm
	core_glow.position.y = DECK_Y + 1.1
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.albedo_color = UiTheme.CYAN
	core_glow.material_override = _core_mat
	add_child(core_glow)
	var cap := MeshInstance3D.new()
	var capm := SphereMesh.new()
	capm.radius = 0.4
	capm.height = 0.5
	cap.mesh = capm
	cap.position.y = DECK_Y + 1.55
	cap.material_override = SvDev.mat(Color("40465a"))
	add_child(cap)

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
	var frame := _mi(prism(hex(HEX_R + 0.06), -0.02, 0.05), SvDev.mat(Color("2c2f38"), 1.0), root)
	var band := _mi(prism(hex(HEX_R + 0.075), 0.0, 0.03), SvDev.flat(Color("3a3f4d")), root)
	frame.name = "Rahmen"
	# Schacht: schwarz, sichtbar, wenn die Klappe offen ist
	_mi(prism(hex(HEX_R - 0.02), 0.05, 0.055), SvDev.flat(Color("07080b")), root)
	var lift := Node3D.new()
	lift.position.y = LIFT_DOWN
	root.add_child(lift)
	_mi(prism(hex(HEX_R - 0.06), -0.08, 0.06), SvDev.mat(Color("4a5060"), 1.0), lift)
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
		_mi(prism(shifted, 0.04, HATCH_TOP), SvDev.mat(Color("5c5f66"), 1.0), half)
		# helle Kante parallel zur Naht (Skizze, Ausschnitt)
		var strip := _strip(shifted, out_dir, 0.05, 0.1)
		if strip.size() >= 3:
			_mi(prism(strip, HATCH_TOP, HATCH_TOP + 0.006), SvDev.mat(Color("8d9099"), 1.0), half)
		# Warnstreifen quer über die Mitte
		var cross := PackedVector2Array([Vector2(-2, -0.11), Vector2(2, -0.11), Vector2(2, 0.11), Vector2(-2, 0.11)])
		for part in Geometry2D.intersect_polygons(shifted, cross):
			_mi(prism(part, HATCH_TOP, HATCH_TOP + 0.008), SvDev.hazard(), half)
		halves.append({"node": half, "dir": Vector3(out_dir.x, 0, out_dir.y)})
	return {"frame": frame, "band": band, "lift": lift, "mount": mount, "halves": halves,
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
	p.band.material_override = SvDev.flat(c)


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
	_core_mat.albedo_color = UiTheme.MISSING.lerp(UiTheme.CYAN, clampf(f, 0.0, 1.0))


func _process(dt: float) -> void:
	_t += dt
	core_glow.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.04)
