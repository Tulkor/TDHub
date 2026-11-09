class_name Effects
extends MeshInstance3D
## Kurze Schusslinien von Tower zu Gegner, dazu Schuss- und Treffer-Effekte (fx_player.gd).
##
## fx bei add_beam: "" = nur Linie; "t:<tower>:<stufe>" = Schuss und Treffer dieses Towers;
## "n:<tower>:<stufe>:<radius>" = Nova des Towers um from. So passt es auch in die Netz-Pakete.

const BEAM_TIME := 0.12

var beams: Array = []
var _mesh := ImmediateMesh.new()
var fx: FxPlayer
var sounds := true  ## Schuss-Sounds abspielen (aus beim Zuschauen fremder Felder)


func _ready() -> void:
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx = FxPlayer.new()
	add_child(fx)


func add_beam(from: Vector3, to: Vector3, col: Color, fx_key: String = "") -> void:
	if fx_key != "" and fx != null:
		var parts := fx_key.split(":")
		if parts.size() >= 3:
			var set := FxData.for_tower(parts[1], int(parts[2]))
			if sounds:
				if parts[0] == "n":
					Sfx.play_nova(parts[1], int(parts[2]))
				else:
					Sfx.play_shot(parts[1], int(parts[2]))
			if parts[0] == "n":
				var radius := float(parts[3]) if parts.size() > 3 else 2.0
				VisualFx.pulse(self, from, radius, Color(col, 0.45), 1.0)
				VisualFx.shockwave(self, from, radius)
				if set.has("nova"):
					fx.play_nova(set.nova, from, float(parts[3]) if parts.size() > 3 else 2.0)
					return
			else:
				var delay := 0.0
				if set.has("shot"):
					fx.play_shot(set.shot, from, to)
					var e := FxData.shot(str(set.shot.id))
					if str(e.get("kind", "")) == "projectile":
						delay = float(e.get("length", 0.0))
				if set.has("hit"):
					fx.play_hit(set.hit, to, 1.0, delay)
				if set.has("shot"):
					return
	beams.append({"from": from, "to": to, "color": col, "t": BEAM_TIME})


func clear() -> void:
	beams.clear()
	_mesh.clear_surfaces()
	for child in get_children():
		if child.is_in_group("visual_transient") or child.is_in_group("visual_shockwave"):
			remove_child(child)
			child.queue_free()
	if fx != null:
		fx.clear()


func _process(delta: float) -> void:
	if beams.is_empty():
		return
	for b in beams:
		b.t -= delta
	beams = beams.filter(func(b): return b.t > 0.0)
	_mesh.clear_surfaces()
	if beams.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in beams:
		var c: Color = b.color
		c.a = b.t / BEAM_TIME
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(b.from)
		_mesh.surface_add_vertex(b.to)
	_mesh.surface_end()
