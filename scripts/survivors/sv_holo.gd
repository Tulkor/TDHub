class_name SvHolo
extends RefCounted
## Bausteine des Hologramm-HUDs von Tower Survivors (Entwurf 1 „Cyan-Kommando“, Lukas 2026-11-04):
## Segmentbalken, Ringanzeige, Verlaufskurve, Wellen-Zeitleiste und der Auswahlkreis um Turm oder Waffe.
## Alles zeichnet selbst in _draw, Farben aus HoloTheme.

const LINE := HoloTheme.LINE
const LIGHT := Color("c8f8ff")


## Echtzeit in Sekunden (unabhängig vom Spieltempo 1×/2×/3×).
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Segmentbalken: n Kästchen, frac gefüllt.
class Seg extends Control:
	var n := 10
	var frac := 0.0
	var color := LINE

	func _init(count := 10, size := Vector2(90, 7)) -> void:
		n = count
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(f: float, col := LINE) -> void:
		if is_equal_approx(f, frac) and col == color:
			return
		frac = f
		color = col
		queue_redraw()

	func _draw() -> void:
		var g := 2.0
		var w := (size.x - g * (n - 1)) / n
		for i in n:
			var on := i < roundi(frac * n)
			draw_rect(Rect2(i * (w + g), 0, w, size.y), Color(color, 0.95 if on else 0.16))


## Ringanzeige mit Strichkranz und Wert in der Mitte (Hülle).
class Gauge extends Control:
	var frac := 1.0
	var big := ""
	var small := ""
	var color := LINE

	func _init(px := 132.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(f: float, a: String, b: String, col := LINE) -> void:
		frac = clampf(f, 0.0, 1.0)
		big = a
		small = b
		color = col
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 14.0
		draw_arc(c, r, 0.0, TAU, 72, Color(LINE, 0.3), 1.0, true)
		for i in 60:
			var a := TAU * i / 60.0
			var l := 7.0 if i % 5 == 0 else 3.5
			draw_line(c + Vector2.from_angle(a) * (r + 4.0), c + Vector2.from_angle(a) * (r + 4.0 + l), Color(LINE, 0.55), 1.0, true)
		draw_arc(c, r - 9.0, 0.0, TAU, 48, Color(LINE, 0.18), 4.0, true)
		if frac > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 72, color, 5.0, true)
		var f := HoloTheme.font(true)
		var m := HoloTheme.mono()
		draw_string(f, c + Vector2(-r, 8), big, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 26, Color.WHITE)
		draw_string(m, c + Vector2(-r, 24), small, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, LINE)


## Verlaufskurve (z. B. DPS der letzten Sekunden), Fläche darunter leicht gefüllt.
class Graph extends Control:
	var values: Array = []
	var cap := 60

	func _init(sz := Vector2(260, 40)) -> void:
		custom_minimum_size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func push(v: float) -> void:
		values.append(v)
		while values.size() > cap:
			values.pop_front()
		queue_redraw()

	func _draw() -> void:
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(LINE, 0.35), 1.0)
		if values.size() < 2:
			return
		var top := 1.0
		for v in values:
			top = maxf(top, v)
		var pts := PackedVector2Array()
		for i in values.size():
			var x := size.x * i / float(cap - 1) + size.x * (cap - values.size()) / float(cap - 1)
			pts.append(Vector2(x, size.y - 2.0 - (size.y - 6.0) * values[i] / top))
		var poly := pts.duplicate()
		poly.append(Vector2(pts[pts.size() - 1].x, size.y))
		poly.append(Vector2(pts[0].x, size.y))
		draw_colored_polygon(poly, Color(LINE, 0.12))
		draw_polyline(pts, LINE, 1.4, true)


## Wellen-Zeitleiste: Skala 0–count, Marker für Boss- und Bonus-Wellen, Fortschritt bis zur aktuellen Welle.
class Ruler extends Control:
	var count := 30
	var pos := 0.0
	var boss_every := 10
	var perk_every := 5

	func _init() -> void:
		custom_minimum_size = Vector2(620, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_pos(p: float) -> void:
		if absf(p - pos) < 0.01:
			return
		pos = p
		queue_redraw()

	func _draw() -> void:
		var x0 := 40.0
		var w := size.x - 80.0
		var y := 18.0
		var m := HoloTheme.mono()
		draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(LINE, 0.7), 1.0)
		for i in count + 1:
			var x := x0 + w * i / float(count)
			var big := i % 5 == 0
			draw_line(Vector2(x, y), Vector2(x, y + (10.0 if big else 5.0)), Color(LINE, 0.9 if big else 0.45), 1.0)
			if big:
				draw_string(m, Vector2(x - 20, y + 24), str(i), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, LINE)
			if i > 0 and i % boss_every == 0:
				draw_rect(Rect2(x - 4, y - 14, 8, 8), Color("ff5a7a"), false, 1.5)
			elif i > 0 and i % perk_every == 0:
				draw_colored_polygon(PackedVector2Array([Vector2(x, y - 15), Vector2(x + 4, y - 10), Vector2(x, y - 5), Vector2(x - 4, y - 10)]), Color(LIGHT, 0.7))
		var px := x0 + w * clampf(pos / count, 0.0, 1.0)
		draw_rect(Rect2(x0, y - 4, px - x0, 3), Color(LINE, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(px - 7, y - 13), Vector2(px + 7, y - 13), Vector2(px, y - 3)]), Color.WHITE)
		# Pfeile links und rechts wie im Entwurf
		for k in 4:
			var a := 0.3 + 0.7 * (k + 1) / 4.0
			var xl := 2.0 + k * 9.0
			draw_polyline(PackedVector2Array([Vector2(xl, y - 5), Vector2(xl + 5, y), Vector2(xl, y + 5)]), Color(LINE, a), 2.0)
			var xr := size.x - 38.0 + k * 9.0
			draw_polyline(PackedVector2Array([Vector2(xr, y - 5), Vector2(xr + 5, y), Vector2(xr, y + 5)]), Color(LINE, a), 2.0)


## Auswahlkreis (Lukas 2026-11-04): nur um das, was ausgewählt ist (Turm oder eine Waffe), ohne Auswahl
## nichts. Beim Auswählen zieht er sich kurz zusammen und blendet ein, beim Abwählen wird er größer und
## verschwindet. Bei einer Waffe zusätzlich ihre Reichweite als Kreis auf dem Boden.
class SelRing extends Control:
	const IN_TIME := 0.18
	const OUT_TIME := 0.38
	var game  ## SvGame
	var cur: Dictionary = {}      ## {kind: "tower"|"slot", slot, t0}
	var ghosts: Array = []        ## abgewählte Kreise, die gerade verschwinden

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func selected_slot() -> int:
		return int(cur.slot) if not cur.is_empty() and cur.kind == "slot" else -1

	func has_selection() -> bool:
		return not cur.is_empty()

	func select(kind: String, slot := -1) -> void:
		if not cur.is_empty() and cur.kind == kind and int(cur.slot) == slot:
			return
		clear()
		cur = {"kind": kind, "slot": slot, "t0": SvHolo.now()}
		queue_redraw()

	func clear() -> void:
		if cur.is_empty():
			return
		var g := cur.duplicate()
		g.t0 = SvHolo.now()
		ghosts.append(g)
		cur = {}
		queue_redraw()

	func _process(_dt: float) -> void:
		var t := SvHolo.now()
		ghosts = ghosts.filter(func(g): return t - float(g.t0) < OUT_TIME)
		# eine verkaufte Waffe ist nicht mehr auswählbar
		if selected_slot() >= 0 and game.weapons[selected_slot()] == null:
			clear()
		if not cur.is_empty() or not ghosts.is_empty():
			queue_redraw()

	## Ziel in der Welt: Mitte und Radius.
	func _target(sel: Dictionary) -> Array:
		if sel.kind == "slot":
			var p: Vector3 = game.platform.pads[int(sel.slot)].root.global_position
			return [p + Vector3(0, 0.6, 0), 1.25]
		return [Vector3(0, SvPlatform.DECK_Y, 0), SvPlatform.DECK_R + 0.8]

	func _label(sel: Dictionary) -> String:
		if sel.kind == "slot":
			var w = game.weapons[int(sel.slot)]
			if w == null:
				return ""
			return tr("%s · STUFE %d · %d DPS") % [tr(str(w.data.name)).to_upper(), w.level, roundi(w.dps())]
		var n := 0
		for w in game.weapons:
			if w != null:
				n += 1
		return tr("PLATTFORM · %d/%d BESTÜCKT · %d DPS") % [n, game.slots_open, roundi(game.total_dps())]

	func _draw() -> void:
		var cam: Camera3D = game.camera
		if cam == null:
			return
		var t := SvHolo.now()
		for g in ghosts:
			var k := clampf((t - float(g.t0)) / OUT_TIME, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 3.0)
			_ring(cam, g, 1.0 + 0.75 * e, 1.0 - k, t)
		if not cur.is_empty():
			var k := clampf((t - float(cur.t0)) / IN_TIME, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 2.0)
			_ring(cam, cur, lerpf(0.82, 1.0, e), e, t)

	func _ring(cam: Camera3D, sel: Dictionary, scale_: float, a: float, t: float) -> void:
		if a <= 0.01:
			return
		var tg := _target(sel)
		var pos: Vector3 = tg[0]
		if cam.is_position_behind(pos):
			return
		var c := cam.unproject_position(pos)
		var edge := cam.unproject_position(pos + cam.global_basis.x * float(tg[1]))
		var r := c.distance_to(edge) * scale_
		var col := func(alpha: float) -> Color: return Color(LINE, alpha * a)
		# Reichweite der Waffe als Kreis auf dem Boden
		if sel.kind == "slot" and sel == cur:
			var w = game.weapons[int(sel.slot)]
			if w != null:
				_ground_circle(cam, Vector3(pos.x, 0.06, pos.z), w.range_(), col.call(0.55))
		draw_arc(c, r, 0.0, TAU, 96, col.call(0.4), 1.0, true)
		for i in 72:
			var an := TAU * i / 72.0
			var l := 8.0 if i % 6 == 0 else 4.0
			draw_line(c + Vector2.from_angle(an) * (r + 3.0), c + Vector2.from_angle(an) * (r + 3.0 + l), col.call(0.6), 1.0, true)
		# gestrichelter Außenring dreht sich langsam
		var spin := t * 0.25
		for i in 36:
			var an := spin + TAU * i / 36.0
			draw_arc(c, r * 1.23, an, an + TAU / 36.0 * 0.28, 4, col.call(0.55), 4.0, true)
		# Fortschrittsbogen innen: Hülle beim Turm, Stufe bei einer Waffe
		var frac: float = game.hp / maxf(game.max_hp(), 1.0)
		if sel.kind == "slot" and game.weapons[int(sel.slot)] != null:
			frac = float(game.weapons[int(sel.slot)].level) / float(game.cfg.max_level)
		draw_arc(c, r * 0.8, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, col.call(0.95), 2.0, true)
		# Laschen oben, unten, links, rechts
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * r * 1.37, c + d * (r * 1.37 + 16.0), col.call(1.0), 2.0)
		# Eckwinkel
		var h := r * 1.14
		var arm := clampf(r * 0.16, 10.0, 30.0)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p := c + Vector2(sx * h, sy * h)
				draw_polyline(PackedVector2Array([p - Vector2(0, sy * arm), p, p - Vector2(sx * arm, 0)]), col.call(1.0), 2.0)
		var text := _label(sel)
		if text != "":
			var m := HoloTheme.mono()
			var tw := m.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var tp := c + Vector2(-tw * 0.5, -h - 10)
			# dunkle Unterlage, damit die Schrift über hellem Deck lesbar bleibt
			draw_rect(Rect2(tp + Vector2(-8, -13), Vector2(tw + 16, 18)), Color(0.01, 0.06, 0.13, 0.7 * a))
			draw_rect(Rect2(tp + Vector2(-8, -13), Vector2(tw + 16, 18)), col.call(0.6), false, 1.0)
			draw_string(m, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(LIGHT, a))

	func _ground_circle(cam: Camera3D, center: Vector3, radius: float, col: Color) -> void:
		var n := 72
		for i in n:
			if i % 2 == 1:
				continue
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p0 := center + Vector3(cos(a0), 0, sin(a0)) * radius
			var p1 := center + Vector3(cos(a1), 0, sin(a1)) * radius
			if cam.is_position_behind(p0) or cam.is_position_behind(p1):
				continue
			draw_line(cam.unproject_position(p0), cam.unproject_position(p1), col, 1.5, true)
