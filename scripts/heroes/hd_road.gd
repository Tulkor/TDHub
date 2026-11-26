class_name HdRoad
extends RefCounted
## Eine Straße von Bollwerk (Etappe 2a): Polylinie vom Spawn am Kartenrand bis zur Feste in der Mitte,
## dazu ihre Torwerke (Vorwerk, Innentor). Fällt das Vorwerk, laufen die Gegner dieser Straße schneller
## (Design Abschnitt 2), fällt auch das Innentor, noch einmal schneller. Werte in data/heroes.json (arena.gates).

var id := ""
var name := ""
var raw_points: Array = []
var points: Array = []      ## Vector3
var cum: Array = []         ## Länge bis Punkt i
var length := 0.0
var gates: Array = []       ## HdBuilding, Vorwerk zuerst
var fast := {}              ## {"vorwerk": 1.3, "innentor": 1.15}
var gate_side := 1.0       ## Getrennte Turmseiten für Lanes mit gemeinsamem Schlussabschnitt.


func _init(d: Dictionary, fast_mult: Dictionary) -> void:
	id = str(d.id)
	name = str(d.get("name", id))
	gate_side = float(d.get("gate_side", 1.0))
	fast = fast_mult
	var raw: Array = []
	for i in d.points.size():
		var p: Array = d.points[i]
		raw.append(Vector3(float(p[0]), 0, float(p[1])))
	raw_points=raw
	points = rounded(raw, float(d.get("corner_radius", 6.0)),int(d.get("merge_index",-1)))
	var total := 0.0
	for i in points.size():
		var v: Vector3 = points[i]
		if i > 0:
			total += v.distance_to(points[i - 1])
		cum.append(total)
	length = total


## Quadratische Kurven liegen innerhalb der alten Ecken; Spawn/Ziel bleiben unverändert.
static func rounded(raw: Array, cut := 4.0, keep_index := -1) -> Array:
	if raw.size()<3:return raw.duplicate()
	var result: Array = [raw[0]]
	for i in range(1,raw.size()-1):
		var incoming: Vector3 = raw[i]-raw[i-1]
		var outgoing: Vector3 = raw[i+1]-raw[i]
		if i==keep_index or incoming.normalized().dot(outgoing.normalized())>.995:
			result.append(raw[i])
			continue
		var radius := minf(cut,minf(incoming.length(),outgoing.length())*.28)
		var a: Vector3 = raw[i]-incoming.normalized()*radius
		var b: Vector3 = raw[i]+outgoing.normalized()*radius
		result.append(a)
		var steps := maxi(3,ceili(radius/1.8))
		for k in range(1,steps+1):
			var t := float(k)/steps
			result.append(a.lerp(raw[i],t).lerp(raw[i].lerp(b,t),t))
	result.append(raw[-1])
	return result


func _segment(s: float) -> int:
	for i in range(1, points.size()):
		if s <= cum[i]:
			return i - 1
	return points.size() - 2


## Punkt bei Länge s, lane = seitlicher Versatz (links/rechts der Mitte).
func point(s: float, lane := 0.0) -> Vector3:
	s = clampf(s, 0.0, length)
	var i := _segment(s)
	var a: Vector3 = points[i]
	var b: Vector3 = points[i + 1]
	var seg: float = cum[i + 1] - cum[i]
	var p := a.lerp(b, (s - cum[i]) / maxf(seg, 0.001))
	return p + side(s) * lane


## Einheitsvektor nach rechts (in Laufrichtung) bei Länge s.
func side(s: float) -> Vector3:
	var i := _segment(clampf(s, 0.0, length))
	var d: Vector3 = (points[i + 1] - points[i]).normalized()
	return Vector3(-d.z, 0, d.x)


## Länge s des nächsten Straßenpunkts, nur im Bereich [s0, s1].
func project(pos: Vector3, s0: float, s1: float) -> float:
	s0 = clampf(s0, 0.0, length)
	s1 = clampf(s1, 0.0, length)
	var best := s0
	var best_d := INF
	for i in points.size() - 1:
		if cum[i + 1] < s0 or cum[i] > s1:
			continue
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var ab := b - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var s := clampf(cum[i] + t * ab.length(), s0, s1)
		var d := pos.distance_squared_to(point(s))
		if d < best_d:
			best_d = d
			best = s
	return best


## Abstand eines Punkts zur Straßenmitte (für Bau-/Bot-Fragen).
func distance(pos: Vector3) -> float:
	return pos.distance_to(point(project(pos, 0.0, length)))


## Tempo-Faktor der Gegner auf dieser Straße: jedes gefallene Torwerk beschleunigt.
func speed_mult() -> float:
	var m := 1.0
	for g in gates:
		if g.destroyed:
			m *= float(fast.get(g.gate_kind, 1.0))
	return m


func gate(kind: String):
	for g in gates:
		if g.gate_kind == kind:
			return g
	return null
