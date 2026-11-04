class_name SvPlatform
extends Node3D
## Der Turm als Waffenplattform (Lukas 2026-11-04: „man sieht, welche Waffen er ausgerüstet hat“):
## Sockel, sechseckiges Deck mit sechs Montageplätzen an den Ecken, Reaktor-Kern in der Mitte.
## Jeder Platz zeigt seinen Zustand: gesperrt (Abdeckplatte mit Warnstreifen), frei (leerer Sockel),
## belegt (Waffe aus Bausteinen, Ring in der Seltenheitsfarbe, Stufen-Lämpchen). Alles in Dev-Optik.

const PAD_RADIUS := 1.95
const DECK_Y := 1.5
const SLOTS := 6
## Waffen etwas größer als ihre Bausteine, damit man sie aus der Spielansicht erkennt
const WEAPON_SCALE := 1.35

var pads: Array = []        ## je Platz: {root, ring, cover, mount, pips}
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
		var pad := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.55
		pm.bottom_radius = 0.6
		pm.height = 0.14
		pm.radial_segments = 12
		pad.mesh = pm
		pad.position.y = 0.07
		pad.material_override = SvDev.mat(Color("6b7183"), 1.0)
		root.add_child(pad)
		var ring := MeshInstance3D.new()
		var rm := TorusMesh.new()
		rm.inner_radius = 0.52
		rm.outer_radius = 0.62
		rm.rings = 16
		rm.ring_segments = 6
		ring.mesh = rm
		ring.position.y = 0.15
		root.add_child(ring)
		var cover := _cover()
		root.add_child(cover)
		var mount := Node3D.new()
		mount.position.y = 0.14
		mount.scale = Vector3.ONE * WEAPON_SCALE
		root.add_child(mount)
		var pips := Node3D.new()
		# Lämpchen außen am Platz (vom Kern weg)
		pips.position = Vector3(cos(a), 0, sin(a)) * 0.72 + Vector3(0, 0.05, 0)
		pips.rotation.y = -a + PI / 2.0
		root.add_child(pips)
		pads.append({"root": root, "ring": ring, "cover": cover, "mount": mount, "pips": pips})
		set_state(i, "locked")


## Abdeckplatte mit Warnstreifen für gesperrte Plätze.
func _cover() -> Node3D:
	var n := Node3D.new()
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.9, 0.1, 0.9)
	plate.mesh = pm
	plate.position.y = 0.2
	plate.material_override = SvDev.mat(Color("2c2f38"), 1.0)
	n.add_child(plate)
	for k in 3:
		var s := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.12, 0.02, 1.1)
		s.mesh = sm
		s.position = Vector3(-0.3 + 0.3 * k, 0.26, 0)
		s.rotation.y = PI / 4.0
		s.material_override = SvDev.flat(UiTheme.COIN)
		n.add_child(s)
	return n


## state: "locked", "free" oder "armed" (dann color = Seltenheitsfarbe).
func set_state(i: int, state: String, color := Color.WHITE) -> void:
	var p: Dictionary = pads[i]
	p.cover.visible = state == "locked"
	var ring: MeshInstance3D = p.ring
	ring.visible = state != "locked"
	ring.material_override = SvDev.flat(color if state == "armed" else Color("3a3f4d"))


## Waffe aufbauen: Drehteller (yaw) mit den Bausteinen aus dem Modell. Gibt den Drehteller zurück.
func mount(i: int, w: Dictionary, colors: Dictionary) -> Node3D:
	var p: Dictionary = pads[i]
	clear(i)
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


func clear(i: int) -> void:
	for c in pads[i].mount.get_children():
		pads[i].mount.remove_child(c)
		c.queue_free()
	set_level(i, 0, Color.WHITE)


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
