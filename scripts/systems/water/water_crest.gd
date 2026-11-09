class_name WaterCrest
extends RefCounted
## Schmaler Schaumbogen über der Naht: vor der Kante waagrecht, danach auf derselben Fallparabel.

const SHADER := preload("res://assets/shaders/water_crest.gdshader")


static func build(body: WaterBody) -> MeshInstance3D:
	var top := WaterBody.vec(body.definition.points[0])
	var bottom := WaterBody.vec(body.definition.points[-1])
	var across := WaterBody.vec(body.definition.get("right", [1, 0, 0]))
	across.y = 0
	across = across.normalized()
	var flat := Vector3(bottom.x - top.x, 0, bottom.z - top.z)
	var direction := flat.normalized() if flat.length() > 0.001 else Vector3(-across.z, 0, across.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[Vector3] = []
	for i in range(-10, 11):
		var f := maxf(i / 10.0, 0) * 0.25
		var at := top + direction * minf(i / 10.0, 0) * 0.5 + flat * f + Vector3.DOWN * (top.y - bottom.y) * f * f
		rows.append(at + Vector3.UP * 0.025)
	for i in 20:
		for item in [[i, -0.5, 0.0], [i, 0.5, 1.0], [i + 1, -0.5, 0.0], [i, 0.5, 1.0], [i + 1, 0.5, 1.0], [i + 1, -0.5, 0.0]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(float(item[2]), float(item[0]) / 20.0))
			st.add_vertex(rows[int(item[0])] + across * body.body_width * float(item[1]))
	var node := MeshInstance3D.new()
	node.name = "FallCrestFoam"
	node.mesh = st.commit()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 2
	material.set_shader_parameter("foam_tex", WaterBody.FOAM)
	material.set_shader_parameter("width", body.body_width)
	material.set_shader_parameter("foam_color", Color(str(body.options.get("foam_color", "d9f5f0d9"))))
	node.material_override = material
	return node
