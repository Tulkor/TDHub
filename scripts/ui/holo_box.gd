class_name HoloBox
extends StyleBox
## Hologramm-Rahmen für den Stil HOLO (Tower Survivors, Lukas 2026-11-04, Entwurf „Cyan-Kommando“):
## halbtransparente Fläche, abgeschrägte Ecken oben links und unten rechts, dünne Leuchtlinie mit
## schwachem Schein, dicke Eckwinkel und auf Wunsch Messstriche an der Unterkante oder eine Lasche oben.

var fill := Color(0.012, 0.1, 0.2, 0.66)
var line := Color("3fe6ff")
var line_alpha := 0.85
var line_width := 1.2
var cut := 12.0
var brackets := true
var ticks := false
var tab := false
var glow := true
## Form: "box" (Ecken abgeschrägt) oder "trap" (Trapez, unten schmaler, für die Kopfleiste)
var shape := "box"


func _shape(r: Rect2) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.4)
	if shape == "trap":
		var s := minf(r.size.y * 0.45, 24.0)
		return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1 - s, y1), Vector2(x0 + s, y1)])
	var p := PackedVector2Array([Vector2(x0 + c, y0)])
	if tab and r.size.x > 160:
		var a := x0 + r.size.x * 0.35
		p.append_array([Vector2(a, y0), Vector2(a + 8, y0 + 7), Vector2(x1 - 58, y0 + 7), Vector2(x1 - 50, y0)])
	p.append_array([Vector2(x1, y0), Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0, y1), Vector2(x0, y0 + c)])
	return p


func _draw(ci: RID, r: Rect2) -> void:
	var pts := _shape(r)
	if fill.a > 0.0:
		RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([fill]))
	var closed := pts.duplicate()
	closed.append(pts[0])
	if line_alpha <= 0.0:
		return
	if glow:
		RenderingServer.canvas_item_add_polyline(ci, closed, PackedColorArray([Color(line, 0.16 * line_alpha)]), 5.0, true)
	RenderingServer.canvas_item_add_polyline(ci, closed, PackedColorArray([Color(line, line_alpha)]), line_width, true)
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.4)
	if brackets and shape == "box" and r.size.x > 60 and r.size.y > 40:
		var k := Color(line, minf(1.0, line_alpha + 0.15))
		var a := r.position
		var b := r.end
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([
			Vector2(a.x, a.y + c + 20), Vector2(a.x, a.y + c), Vector2(a.x + c, a.y), Vector2(a.x + c + 30, a.y)]),
			PackedColorArray([k]), 3.0, true)
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([
			Vector2(b.x, b.y - c - 20), Vector2(b.x, b.y - c), Vector2(b.x - c, b.y), Vector2(b.x - c - 30, b.y)]),
			PackedColorArray([k]), 3.0, true)
	if ticks and r.size.x > 80:
		var x := r.position.x + c + 10.0
		var y := r.end.y
		while x < r.end.x - c - 10.0:
			var big := int(x - r.position.x) % 40 < 8
			RenderingServer.canvas_item_add_line(ci, Vector2(x, y - 4), Vector2(x, y - (10 if big else 6)), Color(line, 0.45), 1.0)
			x += 8.0
