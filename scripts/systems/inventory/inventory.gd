extends GameSystem
## Inventar für alle Item-Modi (wie in WC3): Items aus dem Inventarfenster auf einen Tower in der Welt ziehen
## (InvWorldDrop) und Items zwischen Plätzen verschieben oder tauschen. Welche Items wohin dürfen, sagt der Modus.
## Werte (Basis inventory.json, Modus in system_cfg.inventory): command, tower_ref.
## Haken: inv_drop_reason(t, data) warum Tower t das Item nicht nimmt ("" = nimmt es), inv_drop_hint(t, data)
## Schild an der Maus, item_slots(t) Plätze eines Towers (sonst t.slots()).


## Ziehen auf Tower in der Welt einrichten (einmal beim Spielstart).
func setup_drop() -> InvWorldDrop:
	var d := InvWorldDrop.new()
	d.tower_at = func():
		return game.towers.get(game.occupied.get(game.board.mouse_cell(game.camera_rig.camera), game.NO_CELL))
	d.reason = func(t, data: Dictionary) -> String:
		return str(hook("inv_drop_reason", [t, data], tr("Dieser Tower hat kein Inventar")))
	d.hint = func(t, data: Dictionary) -> String:
		return str(hook("inv_drop_hint", [t, data], free_hint(t)))
	d.drop = drop
	d.mark = func(t, ok: bool) -> void:
		game.board.hover_cell = t.cell if t != null else game.NO_CELL
		game.board.hover_size = Board3D.TOWER_CELLS
		game.board.hover_ok = ok
		game.board.refresh_hover()
	d.tell = func(text: String) -> void:
		if game.has_method("show_message"):
			game.show_message(text)
		else:
			game.hud.show_message(text)
	game.add_child(d)
	return d


## Gezogenes Item (data aus InvSlot) auf Tower t: als Befehl, damit es im Koop beim Host landet.
func drop(t, data: Dictionary) -> void:
	var ref = t.cell if str(cfg.get("tower_ref", "ref")) == "cell" else game.tower_ref(t)
	game.submit({"type": str(cfg.get("command", "item_move")), "from": data.get("from", {}), "to": {"tower": ref, "slot": -1}})


## „+ Einlegen · N frei“.
func free_hint(t) -> String:
	return "+ " + tr("Einlegen · %d frei") % (slots(t) - t.items.size())


## Plätze eines Towers.
func slots(t) -> int:
	return int(hook("item_slots", [t], t.slots() if t.has_method("slots") else 0))


## Item von Platz k der Liste la auf Platz j der Liste lb (beide Listen dürfen gleich sein): liegt dort ein Item,
## tauschen beide, sonst wandert es ans Ende von lb. Ob das erlaubt ist, prüft der Modus vorher.
static func move(la: Array, k: int, lb: Array, j: int) -> void:
	var id = la[k]
	if j >= 0 and j < lb.size():
		la[k] = lb[j]
		lb[j] = id
	else:
		la.remove_at(k)
		lb.append(id)
