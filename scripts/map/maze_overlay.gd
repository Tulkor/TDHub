class_name MazeOverlay
extends Node3D
## Maze-Vorlage als halbtransparente Platten auf dem Boden (System mazes): je Block (2×2 Felder) eine Platte mit
## Neonrand und Schraffur (maze_overlay.gdshader). Zustände je Block: offen (noch bauen), gebaut, Konflikt
## (dort steht etwas anderes oder der Boden ist nicht baubar) und Entwurf (Planen). Dazu optional der Weg, den die
## Gegner mit dieser Vorlage laufen würden (Punkte wie der echte Weg, in der Vorlagenfarbe).
## Liegt knapp über dem Boden und schreibt keine Tiefe: Steine und Tower verdecken die Platten.

enum State { OPEN, DONE, CONFLICT, DRAFT }
const SHADER := preload("res://assets/shaders/maze_overlay.gdshader")
## Randfarbe je Zustand (Alpha = Anteil an der Deckkraft) und Füllung (1 = Vapor-Verlauf Orange → Rosa, 0 = keine,
## 0.5 = in Randfarbe). Türkiser Rand und Vapor-Verlauf im 80er-Stil (Lukas 2026-11-09).
const COLORS := {
	State.OPEN: Color(0.18, 0.95, 0.94, 1.0),
	State.DONE: Color(0.22, 1.0, 0.42, 0.35),
	State.CONFLICT: Color(1.0, 0.27, 0.27, 1.0),
	State.DRAFT: Color(0.18, 0.95, 0.94, 1.0),
}
const FILLS := {State.OPEN: 1.0, State.DONE: 0.0, State.CONFLICT: 0.5, State.DRAFT: 1.0}
## Punkte des Vorlagenwegs beim Planen (Rosa wie das Ende des Verlaufs).
const COL_PATH := Color(1.0, 0.36, 0.8, 0.85)
const LIFT := 0.035
## Platte etwas kleiner als die 2×2 Felder, damit Nachbarn als einzelne Blöcke lesbar bleiben.
const INSET := 0.92

var board: Board3D
var opacity := 0.35:
	set(v):
		opacity = clampf(v, 0.0, 1.0)
		if _mat != null:
			_mat.set_shader_parameter("opacity", opacity)
var _plates: MultiMeshInstance3D
var _mat: ShaderMaterial
var _dots: MultiMeshInstance3D


func _init(b: Board3D) -> void:
	board = b
	name = "MazeOverlay"


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * Board3D.TOWER_CELLS * Board3D.CELL * INSET
	q.orientation = PlaneMesh.FACE_Y
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("opacity", opacity)
	_mat.render_priority = 1
	_plates = _make(q, _mat)
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.03
	dot.radial_segments = 8
	dot.rings = 2
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dots = _make(dot, dm)


func _make(mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## blocks: Liste von [Anker (Vector2i), State]. Gebaute Blöcke kann man mit show_done = false ausblenden.
func set_blocks(blocks: Array, show_done := true) -> void:
	var list := blocks.filter(func(b): return show_done or b[1] != State.DONE)
	var mm := _plates.multimesh
	mm.instance_count = list.size()
	for i in list.size():
		var a: Vector2i = list[i][0]
		var c := Board3D.footprint_center(a)
		mm.set_instance_transform(i, Transform3D(Basis(), board.to_3d(c, LIFT + board.ground_y(c))))
		mm.set_instance_color(i, COLORS[list[i][1]])
		mm.set_instance_custom_data(i, Color(FILLS[list[i][1]], float(absi(a.x * 31 + a.y * 17) % 101) / 101.0, 0, 0))


## Weg mit der Vorlage (Feldmitten), leer = keiner.
func set_path(points: PackedVector2Array) -> void:
	var mm := _dots.multimesh
	mm.instance_count = points.size()
	var col := COL_PATH
	for i in points.size():
		mm.set_instance_transform(i, Transform3D(Basis(), board.to_3d(points[i], 0.03 + board.ground_y(points[i]))))
		mm.set_instance_color(i, col)


## Anzahl gezeichneter Platten (für Tests).
func plate_count() -> int:
	return _plates.multimesh.instance_count if _plates != null else 0
