extends GameSystem
## Bauen, Wege, Lichtpfad und Deckung für alle Modi mit Baufeld. Werte (Basis build.json, Modus in
## system_cfg.build): solid, cover, idle_speed. Haken: build_rule(a) zusätzliche Bauregel des Modus, cover_rule(e)
## (cover "rule"), show_paths() nach dem Umschalten „alle Wege“, path_lights_changed(on).
##
## Deckung: Gegner, die gerade kein Tower erreicht, laufen schneller (idle_speed). Mitspieler im Koop bekommen
## die freien Wegstücke (free_stretch) und sagen damit voraus, wo ein Gegner abbremst.

const COVER_SAMPLE := 0.25

var _cover: Array = []     ## [Tower, größte Reichweite] dieses Bilds
var _cover_frame := -1
var _cover_sig := 0        ## ändert sich, wenn Tower dazukommen, wegfallen oder ihre Reichweite ändern
var _free_cache := {}      ## Bahn/Flieger → {path, sig, list}
var _probe: Enemy = null   ## Messpunkt für free_stretch


func _exit_tree() -> void:
	if _probe != null:
		_probe.free()
		_probe = null


# --- Bauen und Belegen ----------------------------------------------------------

## Blockieren Tower die Gegner (Labyrinth bauen)? YouTD nicht: dort laufen sie auf festen Wegen.
func solid() -> bool:
	return bool(cfg.get("solid", true))


## Passt ein Tower mit Anker a hin: alle Felder baubar, frei und im eigenen Gebiet (any_zone: Gebiete egal),
## die Bauregel des Modus erlaubt es und der Weg bleibt offen.
func can_place(a: Vector2i, any_zone := false) -> bool:
	var cells := Board3D.footprint(a)
	for c in cells:
		if not game.map.is_buildable(c) or game.occupied.has(c) or not (any_zone or game.may_build_for(c)):
			return false
	if not bool(hook("build_rule", [a], true)):
		return false
	return not (solid() and game.pathfinder.would_block_cells(cells))


## Felder eines Towers/Steins (Anker a) belegen oder räumen. solid: blockiert er Gegner (nur wenn solid())?
func occupy(a: Vector2i, on: bool, is_solid := true) -> void:
	var cells := Board3D.footprint(a)
	for c in cells:
		if on:
			game.occupied[c] = a
		else:
			game.occupied.erase(c)
	if solid():
		game.pathfinder.set_solid_cells(cells, on and is_solid)


# --- Wege und Lichtpfad ---------------------------------------------------------

## Lichtpfad ein/aus (Knopf im HUD, Taste L); bleibt gespeichert. Solange er an ist, keine Wegpunkte am Boden.
func set_path_lights(on: bool) -> void:
	Display.set_path_lights(on)
	game.path_lights.visible = on
	game.board.set_path_dots(not on)
	if "lights_button" in game.hud and game.hud.lights_button != null:
		game.hud.lights_button.set_pressed_no_signal(on)
	hook("path_lights_changed", [on])


## Wege aller Spieler zeigen oder nur die eigenen.
func set_show_all_paths(on: bool) -> void:
	game.show_all_paths = on
	if "paths_button" in game.hud and game.hud.paths_button != null:
		game.hud.paths_button.set_pressed_no_signal(on)
	hook("show_paths")


# --- Deckung --------------------------------------------------------------------

## Tempo-Faktor für Gegner, die gerade kein Tower erreicht.
func idle_speed_factor() -> float:
	var c: Dictionary = cfg.get("idle_speed", {})
	var v := float(c.get("default", 1.0))
	match str(c.get("from", "value")):
		"balance":
			v = float(Database.balance.get(str(c.get("key", "")), v))
		"rules":
			v = float(game.rules.get(str(c.get("key", "")), v))
		_:
			v = float(c.get("value", v))
	return maxf(v, float(c.get("min", 0.0)))


## Ist der Gegner gedeckt (cover "towers": in Reichweite eines Towers, der ihn angreifen oder mit einer Aura
## treffen kann)? Wirkt noch Gift, zählt das auch: sonst liefe er mit dem Gift schneller ins Ziel als ohne Schnelllauf.
func is_covered(e) -> bool:
	if str(cfg.get("cover", "towers")) != "towers":
		return bool(hook("cover_rule", [e], true))
	if e.poison_time > 0.0:
		return true
	refresh_cover()
	for c in _cover:
		var t: Tower = c[0]
		if not is_instance_valid(t) or e.pos.distance_squared_to(t.pos) > c[1] * c[1]:
			continue
		if t.can_attack() and t.can_target(e) and t.in_range(e):
			return true
		var aura := t.enemy_aura_radius(e)
		if aura > 0.0 and e.pos.distance_to(t.pos) <= aura:
			return true
	return false


## Ändert sich, wenn Tower dazukommen, wegfallen oder ihre Reichweite ändern.
func cover_signature() -> int:
	refresh_cover()
	return _cover_sig


## Einmal pro Bild: Tower, die überhaupt etwas erreichen, mit ihrer größten Reichweite.
func refresh_cover() -> void:
	var frame := Engine.get_process_frames()
	if frame == _cover_frame:
		return
	_cover_frame = frame
	_cover = []
	var sig := []
	for t in game.all_towers():
		var reach := maxf(t.range_cells() if t.can_attack() else 0.0, t._aura_radius())
		if t.can_attack() and t.stats.has("range_air"):
			reach = maxf(reach, float(t.stats.range_air) * (1.0 + t.rogue_range))
		if reach > 0.0:
			_cover.append([t, reach + 1.5])
			sig.append([t.pos, reach, t.target_mode(), t.can_attack()])
	_cover_sig = hash(sig)


## Für Mitspieler: das Stück, auf dem der Gegner schnell läuft oder als Nächstes laufen wird, als [von, bis] in
## zurückgelegter Strecke, oder [-1, -1]. Damit sagen sie voraus, wo er abbremst, statt bis zur
## nächsten Meldung mit 8× weiterzulaufen. Solange Gift wirkt, beginnt das Stück erst danach.
func free_stretch(e) -> Array:
	if str(cfg.get("cover", "towers")) != "towers" or idle_speed_factor() <= 1.0:
		return [-1.0, -1.0]
	refresh_cover()
	var key := "%d/%d" % [e.lane, int(e.flying)]
	var cached: Dictionary = _free_cache.get(key, {})
	if cached.is_empty() or cached.sig != _cover_sig or not is_same(cached.path, e.path):
		cached = {"path": e.path, "sig": _cover_sig, "list": free_stretches(e.path, e.flying)}
		_free_cache[key] = cached
	# Das Stück, auf dem er gerade ist, ab seinem echten Anfang: der Mitspieler liegt oft knapp
	# dahinter und soll dort nicht normal schnell laufen.
	var from: float = e.traveled
	var poisoned: bool = e.poison_time > 0.0
	if poisoned:
		from += e.base_speed() * e.poison_time
	for st in cached.list:
		if st[1] > from:
			return [maxf(st[0], from) if poisoned else st[0], st[1]]
	return [-1.0, -1.0]


## Stücke des Wegs ohne Tower in Reichweite, als [von, bis] in Strecke ab dem Start.
func free_stretches(path: Array, flying: bool) -> Array:
	if _probe == null:
		_probe = Enemy.new()
	_probe.flying = flying
	_probe.poison_time = 0.0
	var out := []
	var start := -1.0
	var done := 0.0
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var seg := a.distance_to(b)
		var n := maxi(ceili(seg / COVER_SAMPLE), 1)
		for k in range(0 if i == 1 else 1, n + 1):
			var s := seg * k / n
			var free := not _probe_covered(a, b, seg, s)
			if free and start < 0.0:
				start = done + _cover_edge(a, b, seg, maxf(s - seg / n, 0.0), s, false)
			elif not free and start >= 0.0:
				out.append([start, done + _cover_edge(a, b, seg, maxf(s - seg / n, 0.0), s, true)])
				start = -1.0
		done += seg
	if start >= 0.0:
		out.append([start, done])
	return out


func _probe_covered(a: Vector2, b: Vector2, seg: float, s: float) -> bool:
	_probe.pos = a.lerp(b, s / seg) if seg > 0.0 else b
	return is_covered(_probe)


## Rand zwischen lo und hi auf dem Abschnitt a–b genauer suchen: dort wechselt is_covered auf covered_at_hi.
func _cover_edge(a: Vector2, b: Vector2, seg: float, lo: float, hi: float, covered_at_hi: bool) -> float:
	for i in 5:
		var mid := (lo + hi) / 2.0
		if _probe_covered(a, b, seg, mid) == covered_at_hi:
			hi = mid
		else:
			lo = mid
	return hi
