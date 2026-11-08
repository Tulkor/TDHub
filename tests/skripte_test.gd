extends Node
## Modi: kern
## Lädt jedes GDScript unter res://scripts, res://tools und res://tests einmal, damit Parse- und
## Typfehler auch in Dateien auffallen, die kein anderer Test öffnet (Editoren, Menüs, Panels).
## Start: godot --headless --path . res://tests/skripte_test.tscn (oder tools/run_tests.sh skripte)

var failures := 0
var count := 0


func _ready() -> void:
	for root in ["res://scripts", "res://tools", "res://tests"]:
		_scan(root)
	if failures == 0:
		print("OK   %d Skripte fehlerfrei geladen" % count)
	else:
		printerr("FAIL %d von %d Skripten mit Fehlern" % [failures, count])
	get_tree().quit(1 if failures else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_scan(dir_path.path_join(sub))
	for file in dir.get_files():
		if file.get_extension() != "gd":
			continue
		var path := dir_path.path_join(file)
		count += 1
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failures += 1
			printerr("FAIL %s lässt sich nicht laden" % path)
