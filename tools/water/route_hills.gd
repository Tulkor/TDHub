extends Node3D
## Bild: Wasserlauf auf Gelände mit Höhen. Quelle oben links, das Wasser sucht sich den Weg bergab,
## fällt über die Stufe, füllt die Mulde zum Becken und fließt am Überlauf weiter.
## Start: tools/render_windows.ps1 -Scene res://tools/water/route_hills.tscn -Name wasserlauf-gelaende
## Ergebnis: .godot/wasserlauf-gelaende.png

const SIZE := 40.0

var board: Node3D
var systems := {}
var terrain: WaterRoute.Terrain
var streams := [
	{"kind": "stream", "id": "Bergbach", "source": [7.0, 3.0], "dir": [1, 0.4], "width": 1.6},
	{"kind": "stream", "id": "Seitenarm", "source": [33.0, 4.0], "dir": [-1, 0.3], "width": 1.0},
]


static func height(x: float, z: float) -> float:
	var valley := absf(x - 20.0) * 0.05                       # Tal in der Mitte
	var h := (3.2 if z < 14.0 else 1.0) - z * 0.025 + valley  # Stufe bei z = 14
	var d := Vector2(x - 20.0, z - 26.0).length()
	h -= 0.9 * pow(clampf(1.0 - d / 6.0, 0.0, 1.0), 1.5)     # Mulde
	return h + sin(x * 0.9) * cos(z * 0.7) * 0.04


func water_terrain() -> WaterRoute.Terrain:
	return terrain


func water_regions() -> Variant:
	return null


func system_mode() -> String:
	return "gemtd"


func _ready() -> void:
	CameraRig.add_environment(self, {}, false)
	board = Node3D.new()
	add_child(board)
	terrain = WaterRoute.Terrain.new()
	terrain.bounds = Rect2(0, 0, SIZE, SIZE)
	terrain.step = 0.5
	terrain.hilly = true
	terrain.height = height
	# Flussbett graben: Gelände unter dem Wasser absenken, damit es Tiefe hat.
	_ground(WaterRoute.expand(streams, terrain).regions)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(20, 22, 52)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(20, 0, 18))
	cam.current = true
	var sys: WaterSystem = SystemHost.attach(self, "gemtd", ["water"]).water
	sys.cfg.regions = streams
	for i in 40:
		await get_tree().process_frame
	for r in sys.definitions:
		print("WASSER ", r.kind, " ", r.get("id", ""), " ", r.get("points", [r.get("center"), r.get("size")]))
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.godot/wasserlauf-gelaende.png"))
	print("BILD .godot/wasserlauf-gelaende.png")
	# Nahaufnahmen: Fallkanten und Beckenausfluss.
	for shot in [["fall", Vector3(19, 7, 21), Vector3(19, 1.5, 14)], ["becken", Vector3(20, 6, 40), Vector3(20, 0.2, 31)], ["kante", Vector3(19, 4.2, 17.5), Vector3(19, 2.6, 13.2)]]:
		cam.position = shot[1]
		cam.look_at(shot[2])
		for i in 5:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/wasserlauf-%s.png" % shot[0]))
		print("BILD .godot/wasserlauf-%s.png" % shot[0])
	get_tree().quit()


func _ground(water: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 160
	var s := SIZE / n
	for j in n:
		for i in n:
			var quad := [Vector2(i, j), Vector2(i + 1, j), Vector2(i, j + 1), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for q: Vector2 in quad:
				var x := q.x * s
				var z := q.y * s
				st.add_vertex(Vector3(x, height(x, z) - WaterRoute.channel_depth(water, x, z), z))
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5d6b4a")
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)
