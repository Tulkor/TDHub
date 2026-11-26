class_name RecipeBook
extends Control
## Rezeptbuch (Taste R): alle Spezial-Rezepte, Zutaten grün (vorhanden) oder rot (fehlt), Pins.

signal pins_changed
signal closed

const COLUMNS := 3

var owned: Array = []
var now := {}
var filter := "all"
var grid: GridContainer
var search: LineEdit
var tabs := {}


static func is_pinned(id: String) -> bool:
	return Session.pinned_recipes.has(id)


static func toggle_pin(id: String) -> void:
	if Session.pinned_recipes.has(id):
		Session.pinned_recipes.erase(id)
	else:
		Session.pinned_recipes.append(id)


## Karte für ein Rezept. on_pin wird nach dem Umschalten des Pins aufgerufen.
## now: was gerade zum Bauen zählt, siehe Recipes.ready_now.
static func card(id: String, have: Array, on_pin: Callable, compact := false, now := {}) -> PanelContainer:
	var st := Recipes.status(id, have)
	var ready := Recipes.ready_now(id, have, now)
	# One-Shot aus den Gems dieser Runde: Zutaten aus der Runde zeigen (violett)
	if ready and not now.is_empty() and not now.get("wave", false):
		st = Recipes.status(id, now.get("pool", []))
	var pinned := is_pinned(id)
	var p := PanelContainer.new()
	var border := UiTheme.HAVE if ready else (UiTheme.GOLD if pinned else UiTheme.BORDER)
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, border, 8, 1, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var sw := ColorRect.new()
	sw.color = Color(str(Database.towers[id].get("color", "#ffffff")))
	sw.custom_minimum_size = Vector2(12, 12)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sw)
	var name_l := UiUtil.label(Database.tower_label(id, 0), head, 15)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	var status_text := str(TranslationServer.translate("noch %d")) % st.missing
	var status_col := UiTheme.MISSING
	if ready:
		status_text = "baubar"
		status_col = UiTheme.HAVE
	elif st.missing == 0 and Database.towers[id].get("recipe_same_round", false):
		# Alles da, aber nicht aus einer Runde: geht nur als One-Shot mit den neuen Gems
		status_text = "nur aus einer Runde"
		status_col = UiTheme.MUTED
		p.tooltip_text = "Alle Zutaten müssen in derselben Runde gesetzt werden."
	elif st.missing == 0:
		status_text = "in der Welle"
		status_col = UiTheme.GOLD
		p.tooltip_text = "Fertige Tower auf dem Feld lassen sich nur während der Welle kombinieren."
	var status_l := UiUtil.label(status_text, head, 14)
	status_l.add_theme_color_override("font_color", status_col)
	var pin := Button.new()
	pin.text = "Gepinnt" if pinned else "Pin"
	pin.tooltip_text = "Rezept lösen" if pinned else "Rezept anpinnen: erscheint im Spiel links oben"
	pin.focus_mode = Control.FOCUS_NONE
	pin.add_theme_font_size_override("font_size", 14)
	if pinned:
		for k in ["normal", "hover", "pressed"]:
			pin.add_theme_stylebox_override(k, UiTheme.box(UiTheme.GOLD if k != "hover" else UiTheme.GOLD.lightened(0.12)))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			pin.add_theme_color_override(k, UiTheme.GOLD_DARK)
	pin.pressed.connect(func():
		toggle_pin(id)
		on_pin.call())
	head.add_child(pin)
	for line in st.lines:
		var text: String = line.text
		var col := UiTheme.DIM
		if line.have != null:
			text = ("✓ " if line.have else "✗ ") + text
			col = UiTheme.HAVE if line.have else UiTheme.MISSING
			if line.have and line.get("new", false):
				col = UiTheme.PURPLE_LIGHT
		var l := UiUtil.label(("    " if line.indent > 0 else "") + text, v, 13 if not compact else 12)
		l.add_theme_color_override("font_color", col)
	p.set_meta("missing", st.missing)
	p.set_meta("ready", ready)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 40
	panel.offset_bottom = -40
	panel.add_theme_stylebox_override("panel", UiTheme.panel(20.0))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	UiTheme.title(UiUtil.label("Rezeptbuch", head, 24))
	var group := ButtonGroup.new()
	for f in [["all", "Alle"], ["ready", "Jetzt baubar"], ["pinned", "Angepinnt"]]:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = f[0] == filter
		b.toggled.connect(func(on):
			if on:
				filter = f[0]
				refresh())
		head.add_child(b)
		tabs[f[0]] = b
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	search = LineEdit.new()
	search.placeholder_text = "Suche, z. B. Opal"
	search.custom_minimum_size.x = 220
	search.text_changed.connect(func(_t): refresh())
	head.add_child(search)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close_b := UiUtil.button("Schließen (R)", head, close)
	close_b.focus_mode = Control.FOCUS_NONE
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 18)
	v.add_child(legend)
	for leg in [["✓ fixiert", UiTheme.HAVE], ["✓ ausgewählter neuer Gem", UiTheme.PURPLE_LIGHT], ["✗ fehlt", UiTheme.MISSING], ["am wenigsten fehlt zuerst", UiTheme.MUTED]]:
		UiUtil.label(leg[0], legend, 14).add_theme_color_override("font_color", leg[1])

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var hint := UiUtil.label("Angepinnte Rezepte stehen im Spiel links oben und zeigen, was noch fehlt. Grün sind fixierte Tower aus früheren Runden, violett der ausgewählte neue Gem (bei One-Shots alle Zutaten aus der Runde), rot fehlt noch. Baubar ist ein Rezept aber nur so: beim Setzen und Auswählen aus den Gems dieser Runde, während der Welle aus fertigen Towern auf dem Feld.", v, 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hide()


func open(have: Array, now_pool := {}) -> void:
	owned = have
	now = now_pool
	show()
	refresh()


func close() -> void:
	hide()
	closed.emit()


func refresh() -> void:
	if grid == null:
		return
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var q := search.text.strip_edges().to_lower()
	var cards := []
	for id in Recipes.ids():
		if filter == "pinned" and not is_pinned(id):
			continue
		if q != "":
			var hay := Database.tower_label(id, 0).to_lower()
			for line in Recipes.status(id, []).lines:
				hay += " " + str(line.text).to_lower()
			if not q in hay:
				continue
		var c := card(id, owned, func():
			refresh.call_deferred()
			pins_changed.emit(), false, now)
		if filter == "ready" and not c.get_meta("ready"):
			c.free()
			continue
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.append(c)
	cards.sort_custom(func(a, b):
		if a.get_meta("ready") != b.get_meta("ready"):
			return a.get_meta("ready")
		return int(a.get_meta("missing")) < int(b.get_meta("missing")))
	for c in cards:
		grid.add_child(c)
	if cards.is_empty():
		UiUtil.label("Keine Rezepte für diesen Filter.", grid).add_theme_color_override("font_color", UiTheme.MUTED)
