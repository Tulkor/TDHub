class_name ModelLoader
extends RefCounted
## Lädt optionale 3D-Modelle für Tower, Gegner und Steine.
## In den JSON-Daten: "model": "res://assets/models/….glb" und optional "model_scale" (Größe in Towerbreiten).
## Modelle werden automatisch auf die Größe gebracht (längste Kante = model_scale),
## mittig auf den Boden gestellt und können eingefärbt werden.
## Fehlt das Modell, zeichnet das Spiel eine eingebaute einfache Form.

static var _cache := {}
static var _smooth_cache := {}  ## Mesh -> Mesh mit geglätteten Normalen (für Konturen)
static var _outline_mats: Dictionary = {}  ## je Feld-Stil (FieldStyle) ein Kontur-Material
## Konturfarbe, Leuchtkraft und Dicke je Feld-Stil: Neon hellviolett leuchtend, Druidenhain ohne,
## Art déco Messing, Plakatwand schwarz wie Filzstift (Lukas, 2026-10-29).
## "druid_white": weiße Kontur der eeveTD-Tower zur Probe (Tower.eeve_accent "kontur").
const OUTLINE_LOOK := {
	"druid": [Color("1a2018"), 1.0, 0.0],
	"druid_white": [Color("f4f0e0"), 1.0, 0.012],
	"deco": [Color("c9a36a"), 1.0, 0.012],
	"poster": [Color("0b0b0b"), 1.0, 0.022],
}


static func _load(path: String) -> PackedScene:
	if path == "":
		return null
	if not _cache.has(path):
		var res = load(path) if ResourceLoader.exists(path) else null
		_cache[path] = res if res is PackedScene else null
		if _cache[path] == null:
			push_warning("Modell nicht gefunden: " + path)
	return _cache[path]


## Modell als Knoten, normalisiert auf `size` Towerbreiten. tint != null färbt alle Flächen ein.
static func instantiate(path: String, size := 1.0, tint: Material = null) -> Node3D:
	var scene := _load(path)
	if scene == null:
		return null
	var model = scene.instantiate()
	if not model is Node3D:
		model.free()
		return null
	var holder := Node3D.new()
	holder.add_child(model)
	var box := aabb(model, Transform3D())
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0:
		var s := size / longest
		model.scale = Vector3.ONE * s
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
	if tint != null:
		_apply_material(model, tint)
	else:
		Metall.modell(model)
	_play_idle(model)
	return holder


## Figuren (Quaternius, KayKit) stehen sonst in T-Pose: Ruhe-Animation in Schleife abspielen, falls vorhanden.
static func _play_idle(model: Node) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap: AnimationPlayer = players[0]
		for a in ap.get_animation_list():
			if str(a).to_lower().ends_with("idle"):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
				ap.play(a)
				return
	for sk in model.find_children("*", "Skeleton3D", true, false):
		_lower_arms(sk)


## Figuren ohne Ruhe-Animation (Universal Base Characters, KayKit-Skelette): Oberarme aus der T-Pose
## schräg nach unten drehen. "Unten" = vom Kopf zum Becken, damit es bei jeder Achsenlage des Skeletts passt.
static func _lower_arms(sk: Skeleton3D) -> void:
	var head := -1
	var hips := -1
	var arms: Array[int] = []
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b).to_lower()
		if head < 0 and n.contains("head"):
			head = b
		elif hips < 0 and (n.contains("pelvis") or n.contains("hips")):
			hips = b
		elif n.contains("upperarm") or n.begins_with("arm") or n == "upper_arm.l" or n == "upper_arm.r":
			arms.append(b)
	if head < 0 or hips < 0:
		return
	var down := (sk.get_bone_global_rest(hips).origin - sk.get_bone_global_rest(head).origin).normalized()
	for b in arms:
		var kids := sk.get_bone_children(b)
		if kids.is_empty():
			continue
		var g := sk.get_bone_global_rest(b)
		var dir := (sk.get_bone_global_rest(kids[0]).origin - g.origin).normalized()
		var side := (dir - down * dir.dot(down)).normalized()
		var target := (down * 0.92 + side * 0.4).normalized()
		var basis := Basis(Quaternion(dir, target)) * g.basis
		var parent := sk.get_bone_parent(b)
		var pb := sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis()
		sk.set_bone_pose_rotation(b, (pb.inverse() * basis).get_rotation_quaternion())


## Wie instantiate, aber auf eine Grundfläche skaliert: breiteste waagrechte Kante = width,
## höchstens max_height hoch.
static func instantiate_fit(path: String, width: float, max_height: float, tint: Material = null) -> Node3D:
	var holder := instantiate(path, 1.0, tint)
	if holder == null:
		return null
	var model: Node3D = holder.get_child(0)
	var box := aabb(holder, Transform3D())
	var flat := maxf(box.size.x, box.size.z)
	if flat <= 0.0:
		return holder
	var f := width / flat
	if box.size.y * f > max_height:
		f = max_height / box.size.y
	model.scale *= f
	model.position *= f
	return holder


## Erstes Mesh eines Modells, normalisiert (für MultiMesh, z. B. Steine).
## Rückgabe: [Mesh, Transform3D] oder [] wenn nicht vorhanden.
## flat = true: breiteste waagrechte Kante = size (füllt die Grundfläche), sonst längste Kante.
## max_height > 0 begrenzt die Höhe durch Stauchen in Y (Breite bleibt).
static func mesh_with_transform(path: String, size := 1.0, flat := false, max_height := 0.0) -> Array:
	var scene := _load(path)
	if scene == null:
		return []
	var model = scene.instantiate()
	var mi := _first_mesh(model, Transform3D())
	model.free()
	if mi.is_empty():
		return []
	var mesh: Mesh = mi[0]
	var xf: Transform3D = mi[1]
	var box: AABB = xf * mesh.get_aabb()
	var longest := maxf(box.size.x, box.size.z) if flat else maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := size / longest if longest > 0.0 else 1.0
	var sy := s
	if max_height > 0.0 and box.size.y * s > max_height:
		sy = max_height / box.size.y
	var scale := Vector3(s, sy, s)
	var fit := Transform3D(Basis().scaled(scale), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale)
	return [mesh, fit * xf]


static func aabb(n: Node, xf: Transform3D) -> AABB:
	var local: Transform3D = xf * (n.transform if n is Node3D else Transform3D())
	var box := AABB()
	var empty := true
	if n is MeshInstance3D and n.mesh != null:
		box = local * n.mesh.get_aabb()
		empty = false
	for c in n.get_children():
		var b := aabb(c, local)
		if b.size != Vector3.ZERO:
			box = b if empty else box.merge(b)
			empty = false
	return box


static func _first_mesh(n: Node, xf: Transform3D) -> Array:
	var local: Transform3D = xf * (n.transform if n is Node3D else Transform3D())
	if n is MeshInstance3D and n.mesh != null:
		return [n.mesh, local]
	for c in n.get_children():
		var r := _first_mesh(c, local)
		if not r.is_empty():
			return r
	return []


static func _apply_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for c in n.get_children():
		_apply_material(c, mat)


## Alle Materialien des Modells leicht durchsichtig machen, Farben und Texturen bleiben.
## glow: Farbe des Lichts von unten (Sockel), schwach als Eigenleuchten.
static func make_translucent(n: Node, alpha: float, glow := Color.BLACK) -> void:
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			var src: Material = n.get_active_material(i)
			if src is BaseMaterial3D:
				var m: BaseMaterial3D = src.duplicate()
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS  # damit die Kontur innen verdeckt wird
				m.albedo_color.a = alpha
				m.roughness = minf(m.roughness, 0.25)
				m.rim_enabled = true
				m.rim = 0.4
				if glow != Color.BLACK:
					m.emission_enabled = true
					m.emission = glow
					m.emission_energy_multiplier = 0.35
				n.set_surface_override_material(i, m)
	for c in n.get_children():
		make_translucent(c, alpha, glow)


## Kopie des Meshes mit geglätteten Normalen: Ecken an derselben Position bekommen dieselbe
## Normale (Summe der angrenzenden Flächennormalen). Für Konturen per aufgeblähter Hülle,
## die an harten Kanten sonst aufreißen. Braucht keine Normalen im Original.
static func smooth_normals(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		else:
			indices.resize(verts.size())
			for i in verts.size():
				indices[i] = i
		var sums := {}
		var sizes := {}  ## Summe der Flächengrößen je Punkt, um gegenläufige Flächen zu erkennen
		for t in range(0, indices.size() - 2, 3):
			var a := verts[indices[t]]
			var b := verts[indices[t + 1]]
			var c := verts[indices[t + 2]]
			# Godot: Vorderseite im Uhrzeigersinn, daher (c - a) × (b - a) zeigt nach außen
			var n := (c - a).cross(b - a)
			for v in [a, b, c]:
				var key: Vector3 = (v * 1000.0).round()
				sums[key] = sums.get(key, Vector3.ZERO) + n
				sizes[key] = float(sizes.get(key, 0.0)) + n.length()
		var orig: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var smooth := PackedVector3Array()
		smooth.resize(verts.size())
		for i in verts.size():
			var key: Vector3 = (verts[i] * 1000.0).round()
			var sum: Vector3 = sums.get(key, Vector3.UP)
			# Dünne Flächen mit Vorder- und Rückseite (Schirmdächer, Planen) heben sich auf: dann die eigene
			# Normale, sonst zeigt die Hülle in eine zufällige Richtung und deckt die Fläche ganz zu
			if sum.length() < 0.25 * float(sizes.get(key, 0.0)):
				smooth[i] = orig[i] if i < orig.size() else Vector3.ZERO
			else:
				smooth[i] = sum.normalized() if sum.length() > 0.0 else Vector3.UP
		var keep := []
		keep.resize(Mesh.ARRAY_MAX)
		keep[Mesh.ARRAY_VERTEX] = verts
		keep[Mesh.ARRAY_NORMAL] = smooth
		keep[Mesh.ARRAY_INDEX] = indices
		# Figuren mit Skelett: Knochen mitnehmen, sonst steht die Kontur in T-Pose neben der Figur
		var flags := 0
		if arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null:
			keep[Mesh.ARRAY_BONES] = arrays[Mesh.ARRAY_BONES]
			keep[Mesh.ARRAY_WEIGHTS] = arrays[Mesh.ARRAY_WEIGHTS]
			if keep[Mesh.ARRAY_BONES].size() == verts.size() * 8:
				flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, keep, [], {}, flags)
	return out


## Leuchtende Kontur um alle Meshes unter n (gleiche wie bei den Felsbrocken): je Mesh eine
## aufgeblähte Hülle als Kind. Das Material darunter muss Tiefe schreiben (opak oder DEPTH_DRAW_ALWAYS).
## false, wenn der aktuelle Feld-Stil keine Konturen zeichnet (Druidenhain).
static func has_outline(key := "") -> bool:
	var look: Array = OUTLINE_LOOK.get(key if key != "" else FieldStyle.current_name(), [])
	return look.is_empty() or float(look[2]) > 0.0


## Kontur-Material im aktuellen Feld-Stil (für eigene Hüllen, z. B. die Felsbrocken).
## key wählt einen Eintrag aus OUTLINE_LOOK statt des Feld-Stils.
static func outline_material(key := "") -> ShaderMaterial:
	if key == "":
		key = FieldStyle.current_name()
	if not _outline_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://assets/shaders/outline.gdshader")
		m.render_priority = 1
		if OUTLINE_LOOK.has(key):
			m.set_shader_parameter("color", OUTLINE_LOOK[key][0])
			m.set_shader_parameter("energy", OUTLINE_LOOK[key][1])
			m.set_shader_parameter("width", OUTLINE_LOOK[key][2])
		_outline_mats[key] = m
	return _outline_mats[key]


static func add_outline(n: Node, key := "") -> void:
	var outline := outline_material(key)
	# Druidenhain: keine Kontur, die Modelle sollen natürlich schattiert wirken
	if not has_outline(key):
		return
	var targets: Array[MeshInstance3D] = []
	_collect_meshes(n, targets)
	for mi in targets:
		# Blätter mit Alpha-Schnitt hätten sonst eine Kontur um jedes ganze Blatt-Rechteck
		if _has_cutout(mi):
			continue
		if not _smooth_cache.has(mi.mesh):
			_smooth_cache[mi.mesh] = smooth_normals(mi.mesh)
		var hull := MeshInstance3D.new()
		hull.mesh = _smooth_cache[mi.mesh]
		hull.material_override = outline
		if mi.skin != null:
			hull.skin = mi.skin
			hull.skeleton = NodePath("../" + str(mi.skeleton))
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(hull)


static func _has_cutout(mi: MeshInstance3D) -> bool:
	for i in mi.mesh.get_surface_count():
		var m: Material = mi.get_active_material(i)
		if m is BaseMaterial3D and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false


static func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and n.mesh != null:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)
