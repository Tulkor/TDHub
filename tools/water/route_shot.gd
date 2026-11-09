extends Node
## Bild vom Map-Editor mit Wasserläufen: Felsen im Weg, ein Lauf mit Wegpunkt, einer frei bis zum Rand.
## Start: tools/render_windows.ps1 -Scene res://tools/water/route_shot.tscn -Name wasserlauf
## Ergebnis: .godot/wasserlauf-editor.png


func _ready() -> void:
	var map := MapData.create_empty(60, 60)
	map.id = "wasserlauf_demo"
	map.name = "Wasserlauf"
	for y in range(18, 34):
		for x in range(24, 30):
			map.set_tile(Vector2i(x, y), MapData.BLOCKED)
	for y in range(40, 46):
		for x in range(8, 20):
			map.set_tile(Vector2i(x, y), MapData.BLOCKED)
	map.spawn = Vector2i(4, 56)
	map.goal = Vector2i(56, 56)
	map.checkpoints = [Vector2i(30, 50)]
	map.water = [
		{"kind": "stream", "id": "Bach", "source": [1.0, 13.0], "dir": [1, 0], "width": 1.5},
		{"kind": "stream", "id": "Graben", "source": [4.0, 2.0], "dir": [0, 1], "width": 1.0, "via": [[8.0, 10.0]]},
	]
	Session.editor_map = map
	var editor: Node3D = load("res://scenes/map_editor.tscn").instantiate()
	add_child(editor)
	for i in 30:
		await get_tree().process_frame
	editor.camera_rig.frame_map(map.width * Board3D.CELL, map.height * Board3D.CELL)
	# Werkzeug Wasserlauf und Tab Wasser zeigen, ersten Lauf auswählen.
	editor.tool_buttons[editor.Tool.WATER].button_pressed = true
	editor.tool = editor.Tool.WATER
	var tabs: TabContainer = editor.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = tabs.get_tab_count() - 1
	editor.water_tool._select(0)
	for i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.godot/wasserlauf-editor.png"))
	print("BILD .godot/wasserlauf-editor.png")
	get_tree().quit()
