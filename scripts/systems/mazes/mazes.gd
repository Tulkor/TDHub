extends GameSystem
## Maze-Vorlagen (Lukas 2026-11-09): ein Maze speichern (aus dem laufenden Spiel oder vorab geplant) und als
## halbtransparente Platten auf dem Boden zeigen (MazeOverlay), damit man es leicht nachbauen kann.
## Basiswerte mazes.json, Modus-Daten in modes.json → system_cfg.mazes gewinnen (cfg).
##
## Vorlagen: mitgeliefert in data/mazes/<map>.json, eigene in user://mazes/<map>.json, beide
## {"templates": [{id, name, note, blocks: [[x, y], …]}]} mit dem Anker (oben links) jedes 2×2-Blocks.
## Nur Anzeige auf diesem Rechner: nichts davon geht in die Simulation, Spielstände oder ans Netz.
##
## Haken ins Spiel: keine. Das Spiel ruft start() nach dem Aufbau des Felds, plan_click()/snap() aus Klick und
## Hover und liest occupied/rocks/towers/map/pathfinder/board.

signal changed

const DATA_DIR := "res://data/mazes"
## Ordner der eigenen Vorlagen (Tests setzen einen eigenen).
static var dir := "user://mazes"

var overlay: MazeOverlay
## Gezeigte Vorlage (Kopie, beim Planen verändert), leer = keine.
var active: Dictionary = {}
## Planen: Klicks setzen und entfernen Blöcke der gezeigten Vorlage statt zu bauen.
var editing := false
## Ungespeicherte Änderungen an der gezeigten Vorlage.
var dirty := false
var opacity := 0.35:
	set(v):
		opacity = clampf(v, 0.1, 1.0)
		if overlay != null:
			overlay.opacity = opacity
## Gebaute Blöcke weiter schwach grün zeigen (sonst verschwinden sie).
var show_done := true
## Bauvorschau rastet auf offene Blöcke der Vorlage ein.
var snap_on := true

var _blocks := {}       ## Anker -> true der gezeigten Vorlage
var _cells := {}        ## jedes Feld eines Blocks -> Anker
var _base_rocks := {}   ## Steine, die beim Start schon lagen (Zufallssteine der Map), zählen nicht zum eigenen Maze
var _sig := ""
var _counts := Vector2i.ZERO  ## gebaut, gesamt
var _conflicts := 0
var _plan_length := 0
var _plan_cache := {}  ## can_plan je Anker/Stand (Hover fragt jedes Bild)


## Nach dem Aufbau des Felds (Board, Steine der Map) aufrufen.
func start() -> void:
	opacity = float(cfg.get("opacity", opacity))
	show_done = bool(cfg.get("show_done", show_done))
	snap_on = bool(cfg.get("snap", snap_on))
	_load_prefs()
	_base_rocks = game.rocks.duplicate()
	overlay = MazeOverlay.new(game.board)
	overlay.opacity = opacity
	game.board.add_child(overlay)
	var last := str(_prefs().get("last", {}).get(map_id(), ""))
	if last != "":
		var t := find(last)
		if not t.is_empty():
			show_template(t)


func map_id() -> String:
	return game.map.id if game.map != null else ""


# --- Vorlagen laden und speichern ------------------------------------------------

## Mitgelieferte Vorlagen dieser Map.
func builtin() -> Array:
	return _read(DATA_DIR.path_join(map_id() + ".json")).map(func(t):
		var d: Dictionary = t.duplicate(true)
		d["builtin"] = true
		return d)


## Eigene Vorlagen dieser Map.
func own() -> Array:
	return _read(_user_file())


## Alle Vorlagen dieser Map: erst eigene (neueste oben), dann mitgelieferte.
func templates() -> Array:
	var mine := own()
	mine.reverse()
	return mine + builtin()


func find(id: String) -> Dictionary:
	for t in templates():
		if str(t.get("id", "")) == id:
			return t
	return {}


## Blöcke, die gerade im Spiel stehen (Steine und Tower, ohne Fallen und ohne Zufallssteine der Map).
func current_blocks() -> Array:
	var out := []
	for a in game.rocks.keys() + game.towers.keys():
		if not _base_rocks.has(a):
			out.append(a)
	return out


## Neue eigene Vorlage aus blocks (Anker); gibt sie zurück.
func save_new(title: String, blocks: Array, note := "") -> Dictionary:
	var list := own()
	var t := {"id": "eigen_%d_%d" % [Time.get_unix_time_from_system(), randi() % 1000], "name": _title(title),
			"note": note, "created": Time.get_datetime_string_from_system(), "blocks": _to_list(blocks)}
	list.append(t)
	_write(list)
	return t


## Aktuelles Maze aus dem Spiel als neue Vorlage speichern und zeigen.
func save_current(title: String) -> Dictionary:
	var t := save_new(title, current_blocks(), tr("aus Welle %d") % (game.wave_index + 1))
	show_template(t)
	return t


## Gezeigte (geplante) Vorlage speichern: eigene überschreiben, mitgelieferte als Kopie (as_new erzwingt Kopie).
func save_active(title := "", as_new := false) -> Dictionary:
	if active.is_empty():
		return {}
	var name := title if title != "" else str(active.get("name", ""))
	if active.get("builtin", false) or as_new or str(active.get("id", "")) == "":
		var t := save_new(name, _blocks.keys(), str(active.get("note", "")))
		show_template(t)
		return t
	var list := own()
	for i in list.size():
		if list[i].id == active.id:
			list[i].name = _title(name)
			list[i].blocks = _to_list(_blocks.keys())
	_write(list)
	active.name = _title(name)
	dirty = false
	changed.emit()
	return active


func delete(id: String) -> void:
	_write(own().filter(func(t): return str(t.get("id", "")) != id))
	if str(active.get("id", "")) == id:
		hide_template()
	changed.emit()


func rename(id: String, title: String) -> void:
	var list := own()
	for t in list:
		if str(t.get("id", "")) == id:
			t.name = _title(title)
	_write(list)
	if str(active.get("id", "")) == id:
		active.name = _title(title)
	changed.emit()


# --- Anzeigen und Planen ---------------------------------------------------------

func show_template(t: Dictionary) -> void:
	active = t.duplicate(true)
	_blocks.clear()
	for b in active.get("blocks", []):
		_blocks[Vector2i(int(b[0]), int(b[1]))] = true
	_rebuild_cells()
	dirty = false
	_remember(str(active.get("id", "")))
	refresh(true)


func hide_template() -> void:
	active = {}
	editing = false
	_blocks.clear()
	_rebuild_cells()
	dirty = false
	_remember("")
	refresh(true)


## Planen ein/aus. Ohne gezeigte Vorlage beginnt ein leerer Entwurf.
func set_editing(on: bool) -> void:
	if on and active.is_empty():
		active = {"id": "", "name": tr("Neues Maze"), "blocks": []}
		_blocks.clear()
		_rebuild_cells()
	editing = on
	refresh(true)


## Entwurf mit den Blöcken aus dem Spiel füllen (Planen ab dem jetzigen Stand).
func take_current() -> void:
	for a in current_blocks():
		if not _blocks.has(a):
			_blocks[a] = true
	_rebuild_cells()
	dirty = true
	refresh(true)


## Alle Blöcke des Entwurfs entfernen.
func clear_blocks() -> void:
	_blocks.clear()
	_rebuild_cells()
	dirty = true
	refresh(true)


## Klick beim Planen: Block unter der Maus entfernen, sonst an anchor setzen. true = Klick verbraucht.
func plan_click(cell: Vector2i, anchor: Vector2i) -> bool:
	if not editing:
		return false
	var hit: Vector2i = _cells.get(cell, Vector2i(-1, -1))
	var target := plan_target(cell, anchor)
	if hit != Vector2i(-1, -1):
		_blocks.erase(hit)
	elif can_plan(target):
		_blocks[target] = true
	else:
		Sfx.play("error")
		return true
	_rebuild_cells()
	dirty = true
	refresh(true)
	return true


## Wohin ein Klick beim Planen einen Block setzt: auf einen Stein/Tower im Spiel genau dessen Platz (übernehmen),
## sonst an den Anker unter der Maus.
func plan_target(cell: Vector2i, anchor: Vector2i) -> Vector2i:
	var occ: Vector2i = game.occupied.get(cell, Vector2i(-1, -1))
	return occ if occ != Vector2i(-1, -1) else anchor


## Darf beim Planen ein Block an a? Felder baubar, nicht in einem anderen Block, nichts Fremdes darauf, und der
## Weg mit allen Blöcken der Vorlage und allem im Spiel bleibt offen.
func can_plan(a: Vector2i) -> bool:
	var key := "%s|%d|%s" % [a, _blocks.size(), _sig]
	if _plan_cache.has(key):
		return _plan_cache[key]
	if _plan_cache.size() > 64:
		_plan_cache.clear()
	_plan_cache[key] = _can_plan(a)
	return _plan_cache[key]


func _can_plan(a: Vector2i) -> bool:
	if _blocks.has(a):
		return false
	var cells := Board3D.footprint(a)
	for c in cells:
		if not game.map.in_bounds(c) or not game.map.is_buildable(c) or _cells.has(c):
			return false
		if game.occupied.get(c, a) != a:
			return false
	var pf := _plan_finder()
	return not pf.would_block_cells(cells)


## Bauvorschau einrasten: liegt cell in einem offenen Block der Vorlage, dessen Anker, sonst anchor.
func snap(cell: Vector2i, anchor: Vector2i) -> Vector2i:
	if not snap_on or active.is_empty() or editing:
		return anchor
	var a: Vector2i = _cells.get(cell, Vector2i(-1, -1))
	if a == Vector2i(-1, -1) or game.rocks.has(a) or game.towers.has(a):
		return anchor
	return a


## Gebaut / gesamt der gezeigten Vorlage.
func progress() -> Vector2i:
	return _counts


func conflicts() -> int:
	return _conflicts


## Weglänge mit der Vorlage in Towerbreiten (beim Planen), 0 = keine/versperrt.
func plan_length() -> float:
	return _plan_length / 2.0


func block_count() -> int:
	return _blocks.size()


func has_block(a: Vector2i) -> bool:
	return _blocks.has(a)


func _process(_delta: float) -> void:
	if overlay == null or active.is_empty():
		return
	refresh()


## Platten neu setzen, wenn sich im Spiel etwas geändert hat (oder force).
func refresh(force := false) -> void:
	if overlay == null:
		return
	var sig := "%d|%d|%d" % [game.occupied.size(), game.rocks.size(), game.towers.size()]
	if not force and sig == _sig:
		return
	_sig = sig
	var list := []
	var done := 0
	_conflicts = 0
	for a in _blocks.keys():
		var st := _state(a)
		if st == MazeOverlay.State.DONE:
			done += 1
		elif st == MazeOverlay.State.CONFLICT:
			_conflicts += 1
		list.append([a, MazeOverlay.State.DRAFT if editing and st == MazeOverlay.State.OPEN else st])
	_counts = Vector2i(done, _blocks.size())
	overlay.set_blocks(list, show_done)
	var dots := PackedVector2Array()
	_plan_length = 0
	if editing:
		var cells := _plan_finder().compute_path(0)
		_plan_length = cells.size()
		for c in cells:
			dots.append(Board3D.cell_center(c))
	overlay.set_path(dots)
	changed.emit()


func _state(a: Vector2i) -> int:
	if game.rocks.has(a) or game.towers.has(a):
		return MazeOverlay.State.DONE
	for c in Board3D.footprint(a):
		if not game.map.in_bounds(c) or not game.map.is_buildable(c) or game.occupied.has(c):
			return MazeOverlay.State.CONFLICT
	return MazeOverlay.State.OPEN


## Wegfindung mit allem im Spiel plus allen Blöcken der Vorlage.
func _plan_finder() -> Pathfinder:
	var pf := Pathfinder.new(game.map)
	var cells: Array[Vector2i] = []
	for c in game.occupied.keys():
		cells.append(c)
	for c in _cells.keys():
		cells.append(c)
	pf.set_solid_cells(cells, true)
	return pf


func _rebuild_cells() -> void:
	_plan_cache.clear()
	_cells.clear()
	for a in _blocks.keys():
		for c in Board3D.footprint(a):
			_cells[c] = a


# --- Dateien ----------------------------------------------------------------------

func _user_file() -> String:
	return dir.path_join(map_id() + ".json")


func _read(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary and d.get("templates") is Array:
		return (d.templates as Array).filter(func(t): return t is Dictionary and t.get("blocks") is Array)
	return []


func _write(list: Array) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_user_file() + ".tmp", FileAccess.WRITE)
	if f == null:
		push_warning("Maze-Vorlagen: kann %s nicht schreiben" % _user_file())
		return
	f.store_string(JSON.stringify({"map": map_id(), "templates": list}, "\t"))
	f.close()
	DirAccess.rename_absolute(_user_file() + ".tmp", _user_file())


static func _to_list(blocks: Array) -> Array:
	var out := []
	for a in blocks:
		out.append([int(a.x), int(a.y)])
	out.sort()
	return out


func _title(t: String) -> String:
	t = t.strip_edges()
	return t if t != "" else tr("Mein Maze")


## Einstellungen der Anzeige und zuletzt gezeigte Vorlage je Map (user://mazes/einstellungen.json).
func _prefs() -> Dictionary:
	var path := dir.path_join("einstellungen.json")
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _load_prefs() -> void:
	var p := _prefs()
	opacity = float(p.get("opacity", opacity))
	show_done = bool(p.get("show_done", show_done))
	snap_on = bool(p.get("snap", snap_on))


func save_prefs() -> void:
	var p := _prefs()
	p.opacity = opacity
	p.show_done = show_done
	p.snap = snap_on
	_store_prefs(p)


func _remember(id: String) -> void:
	var p := _prefs()
	var last: Dictionary = p.get("last", {})
	last[map_id()] = id
	p.last = last
	_store_prefs(p)


func _store_prefs(p: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("einstellungen.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(p, "\t"))


## Liegt cell in einem Block der Vorlage?
func has_block_at(cell: Vector2i) -> bool:
	return _cells.has(cell)


## Anker des Blocks, in dem cell liegt (oder (-1, -1)).
func block_at(cell: Vector2i) -> Vector2i:
	return _cells.get(cell, Vector2i(-1, -1))


## Weglänge (Felder), wenn nur die Map und die Blöcke der Vorlage t stehen; 0 = Weg versperrt.
func template_length(t: Dictionary) -> int:
	var pf := Pathfinder.new(game.map)
	var cells: Array[Vector2i] = []
	for b in t.get("blocks", []):
		cells.append_array(Board3D.footprint(Vector2i(int(b[0]), int(b[1]))))
	pf.set_solid_cells(cells, true)
	var total := 0
	for i in game.map.lane_count():
		total += pf.compute_path(i).size()
	return total
