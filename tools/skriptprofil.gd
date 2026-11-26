extends Node
## Skript-Profil für tools/screenshot.gd --skriptprofil=S: misst S Sekunden lang, wie viel Zeit die
## _process- und _physics_process-Funktionen je Skriptdatei brauchen. Dafür schaltet es bei allen Knoten
## mit eigener Funktion die Verarbeitung ab und ruft sie selbst mit Zeitmessung auf (gleiche Reihenfolge
## wie Godot: Priorität, dann Baumreihenfolge nicht garantiert). Signale, Timer, Tweens und _input
## sind nicht dabei. Ausgabe: Zeilen SKRIPTPROFIL <ms/Bild> <Aufrufe/Bild> <skript>:<funktion>.

var _proc := {}      # Knoten-ID -> Knoten (von uns übernommenes _process)
var _phys := {}
var _sum := {}       # "pfad:funktion" -> [usec, aufrufe]
var _frames := 0
var _pframes := 0


func start() -> void:
	process_priority = -1000
	process_physics_priority = -1000
	for n in _walk(get_tree().root):
		_take(n)
	get_tree().node_added.connect(_take)


func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children(true):
		out.append_array(_walk(c))
	return out


func _take(n: Node) -> void:
	if n == self or n.get_script() == null:
		return
	if n.has_method("_process") and n.is_processing():
		_proc[n.get_instance_id()] = n
	if n.has_method("_physics_process") and n.is_physics_processing():
		_phys[n.get_instance_id()] = n
	# Knoten, die erst im _ready die Verarbeitung anschalten, beim nächsten Durchlauf aufnehmen
	if not n.is_node_ready():
		n.ready.connect(_take.bind(n), CONNECT_ONE_SHOT)


func _run(table: Dictionary, physics: bool, delta: float) -> void:
	for id in table.keys():
		var n = table[id]
		if not is_instance_valid(n) or not n.is_inside_tree():
			table.erase(id)
			continue
		# Schaltet ein Knoten sich später selbst ab (set_process(false)), merkt das Profil es nicht und ruft
		# ihn weiter auf; für einen Überblick reicht das.
		if physics and n.is_physics_processing():
			n.set_physics_process(false)
		elif not physics and n.is_processing():
			n.set_process(false)
		if not n.can_process():
			continue
		var t0 := Time.get_ticks_usec()
		if physics:
			n._physics_process(delta)
		else:
			n._process(delta)
		var key := "%s:%s" % [n.get_script().resource_path.trim_prefix("res://"), "_physics_process" if physics else "_process"]
		var e: Array = _sum.get_or_add(key, [0, 0])
		e[0] += Time.get_ticks_usec() - t0
		e[1] += 1


func _process(delta: float) -> void:
	_frames += 1
	_run(_proc, false, delta)


func _physics_process(delta: float) -> void:
	_pframes += 1
	_run(_phys, true, delta)


func report(top: int = 20) -> void:
	var keys := _sum.keys()
	keys.sort_custom(func(a, b): return _sum[a][0] > _sum[b][0])
	var total := 0.0
	for k in keys:
		total += _sum[k][0]
	print("SKRIPTPROFIL bilder=%d physik=%d summe_ms_je_bild=%.3f" % [_frames, _pframes, total / 1000.0 / maxi(_frames, 1)])
	for k in keys.slice(0, top):
		var per: int = _pframes if k.ends_with("_physics_process") else _frames
		print("SKRIPTPROFIL %7.3f ms %6.1f x  %s" % [_sum[k][0] / 1000.0 / maxi(_frames, 1), float(_sum[k][1]) / maxi(per, 1), k])
