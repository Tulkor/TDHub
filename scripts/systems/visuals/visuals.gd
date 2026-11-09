class_name VisualFx
extends RefCounted
## Darstellung ohne Spielregeln. Bibliothek wie Leveling, Kaskade über system_cfg.visuals.

const STATUS := preload("res://assets/shaders/enemy_status.gdshader")
const OCCLUDED := preload("res://assets/shaders/enemy_occluded.gdshader")
const RANGE := preload("res://assets/shaders/range_area.gdshader")
const BUILD := preload("res://assets/shaders/build_preview.gdshader")
const WIND := preload("res://assets/shaders/foliage_wind.gdshader")
const SHOCK := preload("res://assets/shaders/shockwave.gdshader")
const DISSOLVE := preload("res://assets/shaders/dissolve.gdshader")
const GEM := preload("res://assets/shaders/gem.gdshader")
const GEM_HIGH := preload("res://assets/shaders/gem_refract.gdshader")
const MAX_TRANSIENTS := 24
static var _configs := {}
static var _watched: Array[WeakRef] = []


static func config(context: Object = null) -> Dictionary:
	var node := context
	var mode := ""
	while node != null:
		if node.has_method("system_mode"):
			mode = str(node.system_mode())
			break
		node = node.get_parent() if node is Node else null
	if not _configs.has(mode):
		_configs[mode] = SystemHost.config(mode, "visuals")
	return _configs[mode]


static func _track(mat: ShaderMaterial, kind: String, cfg: Dictionary) -> ShaderMaterial:
	mat.set_meta("visual_kind", kind)
	mat.set_meta("visual_cfg", cfg)
	if _watched.size() % 64 == 0:
		_watched = _watched.filter(func(w): return w.get_ref() != null)
	_watched.append(weakref(mat))
	if not Display.quality_changed.is_connected(refresh_quality):
		Display.quality_changed.connect(refresh_quality)
	_apply_quality(mat)
	return mat


static func refresh_quality() -> void:
	_watched = _watched.filter(func(w): return w.get_ref() != null)
	for w in _watched:
		_apply_quality(w.get_ref())


static func _apply_quality(mat: ShaderMaterial) -> void:
	var cfg: Dictionary = mat.get_meta("visual_cfg")
	match str(mat.get_meta("visual_kind")):
		"status":
			mat.set_shader_parameter("detail", 0.0 if Display.quality == Display.LOW else 1.0)
			mat.next_pass = mat.get_meta("occlusion_material") if bool(cfg.occlusion.enabled) and Display.quality >= int(cfg.occlusion.min_quality) else null
		"occluded":
			mat.set_shader_parameter("enabled", bool(cfg.occlusion.enabled) and Display.quality >= int(cfg.occlusion.min_quality))
		"range":
			mat.set_shader_parameter("motion", float(cfg.range.motion) if Display.quality > Display.LOW else 0.0)
		"wind":
			mat.set_shader_parameter("wind_strength", float(cfg.wind.strength) if bool(cfg.wind.enabled) and Display.quality >= int(cfg.wind.min_quality) else 0.0)
		"gem":
			mat.shader = GEM_HIGH if bool(cfg.gem.refraction) and Display.quality == Display.HIGH else GEM
		"shock":
			mat.set_shader_parameter("strength", float(cfg.shockwave.strength) if Display.quality >= int(cfg.shockwave.min_quality) else 0.0)


static func status(context: Object, bounds: AABB) -> ShaderMaterial:
	var cfg := config(context)
	var mat := ShaderMaterial.new()
	mat.shader = STATUS
	mat.set_shader_parameter("base_y", bounds.position.y)
	mat.set_shader_parameter("height", maxf(bounds.size.y, 0.01))
	mat.set_shader_parameter("strength", float(cfg.status.strength) if bool(cfg.status.enabled) else 0.0)
	mat.render_priority = 2
	var xray := ShaderMaterial.new()
	xray.shader = OCCLUDED
	xray.set_shader_parameter("color", Color.from_string(str(cfg.occlusion.color), Color.GOLD))
	xray.render_priority = 3
	mat.set_meta("occlusion_material", _track(xray, "occluded", cfg))
	return _track(mat, "status", cfg)


static func area(radius: float, color: Color, context: Object = null, pattern := 0.0) -> MeshInstance3D:
	var cfg := config(context)
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * maxf(radius, 0.01) * 2.04
	node.mesh = plane
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = 0.07
	var mat := ShaderMaterial.new()
	mat.shader = RANGE
	mat.set_shader_parameter("radius", maxf(radius, 0.01))
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("fill", float(cfg.range.fill))
	mat.set_shader_parameter("pattern", pattern)
	node.material_override = _track(mat, "range", cfg)
	return node


static func wind_material(base: BaseMaterial3D, bounds: AABB, context: Object) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WIND
	mat.set_shader_parameter("albedo_color", base.albedo_color)
	if base.albedo_texture != null:
		mat.set_shader_parameter("albedo_texture", base.albedo_texture)
	mat.set_shader_parameter("roughness", base.roughness)
	mat.set_shader_parameter("base_y", bounds.position.y)
	mat.set_shader_parameter("height", maxf(bounds.size.y, 0.01))
	return _track(mat, "wind", config(context))


static func gem_material(context: Object, high_tier: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GEM
	if high_tier:
		_track(mat, "gem", config(context))
	return mat


static func dissolve(model: Node3D, duration: float, color: Color) -> void:
	var mats: Array[ShaderMaterial] = []
	var cache := {}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = null
		for i in mesh.mesh.get_surface_count():
			var base := mesh.get_active_material(i) as BaseMaterial3D
			if base == null:
				continue
			if not cache.has(base):
				var mat := ShaderMaterial.new()
				mat.shader = DISSOLVE
				mat.set_shader_parameter("albedo_color", base.albedo_color)
				mat.set_shader_parameter("edge_color", color)
				mat.set_shader_parameter("roughness", base.roughness)
				if base.albedo_texture != null:
					mat.set_shader_parameter("albedo_texture", base.albedo_texture)
				cache[base] = mat
				mats.append(mat)
			mesh.set_surface_override_material(i, cache[base])
	var tw := model.create_tween()
	tw.tween_interval(duration * 0.35)
	tw.tween_method(func(t: float):
		for mat in mats:
			mat.set_shader_parameter("progress", t), 0.0, 1.0, duration * 0.65)


## Kosmetische Fläche: begrenzte Anzahl, automatische Freigabe, keine Trefferberechnung.
static func pulse(parent: Node, at: Vector3, radius: float, color: Color, pattern := 1.0, duration := 0.6) -> void:
	if not parent.is_inside_tree() or parent.get_tree().get_nodes_in_group("visual_transient").size() >= MAX_TRANSIENTS:
		return
	var node := area(radius, color, parent, pattern)
	parent.add_child(node)
	node.add_to_group("visual_transient")
	node.global_position = at + Vector3.UP * 0.08
	var mat := node.material_override as ShaderMaterial
	var tw := node.create_tween()
	tw.tween_method(func(t: float):
		mat.set_shader_parameter("progress", t)
		mat.set_shader_parameter("color", Color(color, color.a * (1.0 - t))), 0.0, 1.0, duration)
	tw.tween_callback(node.queue_free)


static func shockwave(parent: Node, at: Vector3, radius: float) -> void:
	var cfg := config(parent)
	if not bool(cfg.shockwave.enabled) or Display.quality < int(cfg.shockwave.min_quality) or radius < float(cfg.shockwave.min_radius):
		return
	if not parent.is_inside_tree() or parent.get_tree().get_nodes_in_group("visual_shockwave").size() >= int(cfg.shockwave.max_active):
		return
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHOCK
	node.material_override = _track(mat, "shock", cfg)
	parent.add_child(node)
	node.add_to_group("visual_shockwave")
	node.global_position = at
	var camera := parent.get_viewport().get_camera_3d()
	if camera != null:
		node.global_basis = camera.global_basis
	var tw := node.create_tween()
	tw.tween_method(func(t: float): mat.set_shader_parameter("progress", t), 0.0, 1.0, 0.45)
	tw.tween_callback(node.queue_free)
