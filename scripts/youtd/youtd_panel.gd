class_name YoutdPanel
extends Control
## Oberfläche von YouTD außer den Lagern: Werte und Knöpfe in der Leiste oben (Bücher, Food, Elemente, Rezepte,
## nächste Welle), die Fenster „Elemente“ und „Rezepte“ in der Bildmitte (immer nur eines offen, ein neues schließt
## das alte) und kurze Meldungen unter dem Banner. „Elemente“ geht von selbst auf, sobald die Bücher für ein neues
## Level reichen. Tower- und Item-Lager liegen unten links (youtd_store.gd). Dazu Tooltip-Texte für Tower, Items und
## Würfel-Rezepte.

const MSG_TIME := 6.0      ## so lange bleibt eine Meldung stehen (Sekunden, danach blendet sie aus)
const MSG_TOP := 132.0     ## Abstand der Meldungen vom oberen Rand (unter dem Banner)

var game  # youtd_game.gd
var hud: Hud
var _tomes: Label
var _food: Label
var _el_button: Button
var _rec_button: Button
var _next: Button
var _windows := {}         ## "elements"/"recipes" -> PanelContainer
var _buttons := {}         ## "elements"/"recipes" -> Knopf in der Leiste
var _rows := {}            ## Element -> {level: Label, cost: Label, plus: Button, row: Control}
var _el_tomes: Label
var _el_hint: Label
var _rec_grid: GridContainer
var _rec_key := ""
var _could_research := false
var _msgs: VBoxContainer
var _msg_last: Variant = null  ## zuletzt gesehene Meldungen (null = noch nie, dann nichts nachträglich zeigen)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = game.hud
	_tomes = hud.add_bar_chip("Bücher", UiTheme.HAVE)
	_tomes.get_parent().get_parent().tooltip_text = tr("Wissensbücher: damit erforschst du Elemente. Jede geschaffte Welle bringt 8 dazu.")
	_food = hud.add_bar_chip("Food")
	_food.get_parent().get_parent().tooltip_text = tr("Jeder Tower braucht Food nach Seltenheit: gewöhnlich 2, ungewöhnlich 3, selten 4, einzigartig 6.")
	_el_button = _bar_toggle("elements", "Elemente", tr("Elemente erforschen"))
	_rec_button = _bar_toggle("recipes", "Rezepte", tr("Horadrischer Würfel: aus Items im Lager neue machen"))
	_next = hud.add_bar_button("", func(): game.submit({"type": "next_wave"}), false)
	UiTheme.accent_button(_next, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_build_elements()
	_build_recipes()
	_msgs = VBoxContainer.new()
	_msgs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msgs.anchor_left = 0.5
	_msgs.anchor_right = 0.5
	_msgs.offset_top = MSG_TOP
	_msgs.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_msgs.add_theme_constant_override("separation", 2)
	add_child(_msgs)
	refresh()


func _bar_toggle(id: String, text: String, tip: String) -> Button:
	var b := hud.add_bar_button(text, func(): toggle_window(id))
	b.toggle_mode = true
	b.tooltip_text = tip
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	_buttons[id] = b
	return b


# --- Fenster in der Mitte ------------------------------------------------------------

func _window(id: String, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel(16.0, 0.97))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.45
	p.anchor_bottom = 0.45
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.hide()
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var t := UiUtil.label(title, head, 20)
	UiTheme.heading(t)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := UiUtil.button("×", head, close_windows)
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(30, 28)
	x.tooltip_text = tr("Schließen (Esc)")
	_windows[id] = p
	return v


## Fenster öffnen; ein anderes offenes Fenster in der Mitte geht dabei zu.
func open_window(id: String) -> void:
	for k in _windows:
		(_windows[k] as Control).visible = k == id
		(_buttons[k] as Button).set_pressed_no_signal(k == id)
	_rec_key = ""
	refresh()


func toggle_window(id: String) -> void:
	if is_open(id):
		close_windows()
	else:
		open_window(id)


func close_windows() -> void:
	open_window("")


func is_open(id: String) -> bool:
	return _windows.has(id) and (_windows[id] as Control).visible


func any_open() -> bool:
	return _windows.values().any(func(w): return w.visible)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and any_open():
		close_windows()
		get_viewport().set_input_as_handled()


# --- Elemente ----------------------------------------------------------------------

func _build_elements() -> void:
	var v := _window("elements", "Elemente")
	_el_tomes = UiUtil.label("", v, 15)
	_el_hint = UiUtil.wrap_label("", v, 470)
	_el_hint.add_theme_color_override("font_color", UiTheme.HAVE)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for el in YoutdData.elements():
		var id := str(el)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.x = 230
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(row)
		var sw := ColorRect.new()
		sw.color = YoutdData.element_color(id)
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
		var name := UiUtil.label(YoutdData.element_name(id), row, 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lvl := UiUtil.label("0", row, 15)
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost := UiUtil.label("", row, 14)
		cost.custom_minimum_size.x = 76
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost.add_theme_color_override("font_color", UiTheme.MUTED)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plus := UiUtil.button("+", row, func(): game.submit({"type": "research", "element": id}))
		plus.focus_mode = Control.FOCUS_NONE
		plus.custom_minimum_size = Vector2(30, 28)
		_rows[id] = {"level": lvl, "cost": cost, "plus": plus, "row": row}
	var note := UiUtil.wrap_label(tr("Das Fenster geht von selbst auf, sobald die Bücher für ein neues Level reichen."), v, 470)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UiTheme.MUTED)


func _research_count() -> int:
	return YoutdData.elements().filter(func(el): return game.can_research(str(el))).size()


func _refresh_elements() -> void:
	var n := _research_count()
	_el_button.text = tr("Elemente") + (" (%d)" % n if n > 0 else "")
	_el_button.add_theme_color_override("font_color", UiTheme.HAVE if n > 0 else UiTheme.TEXT)
	# Neuer Punkt: Fenster von selbst öffnen (einmal, bis wieder nichts mehr geht)
	var can: bool = n > 0 and game.phase < game.Phase.GAME_OVER
	if can and not _could_research and not is_open("elements"):
		_could_research = true
		open_window("elements")
		return
	_could_research = can
	if not is_open("elements"):
		return
	_el_tomes.text = tr("%d Bücher") % game.tomes
	_el_hint.text = tr("Neuer Punkt frei: du kannst ein Element erforschen.") if n > 0 else ""
	_el_hint.visible = n > 0
	for id in _rows:
		var r: Dictionary = _rows[id]
		var lvl := int(game.elements.get(id, 0))
		var top: int = game.max_element_level()
		(r.level as Label).text = "%d / %d" % [lvl, top]
		(r.level as Label).add_theme_color_override("font_color", YoutdData.element_color(id) if lvl > 0 else UiTheme.MUTED)
		(r.cost as Label).text = tr("%d Bücher") % game.research_cost(id) if lvl < top else tr("fertig")
		var plus: Button = r.plus
		plus.disabled = not game.can_research(id)
		var tip := YoutdData.element_name(id) + " " + tr("Stufe %d / %d") % [lvl, top]
		if lvl < top:
			tip += "\n" + tr("Erforschen: %d Bücher") % game.research_cost(id)
		(r.row as Control).tooltip_text = tip
		plus.tooltip_text = tip


# --- Rezepte -----------------------------------------------------------------------

func _build_recipes() -> void:
	var v := _window("recipes", "Rezepte")
	var sub := UiUtil.wrap_label(tr("Grünes Feld anklicken: das Rezept läuft sofort, die Zutaten nimmt das Spiel aus dem Lager (niedrigstes Level zuerst)."), v, 640)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	_rec_grid = GridContainer.new()
	_rec_grid.columns = 2 + YoutdCube.RARITIES.size()
	_rec_grid.add_theme_constant_override("h_separation", 8)
	_rec_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_rec_grid)
	var note := UiUtil.wrap_label(tr("Rechtsklick auf ein Item im Lager sperrt es für Rezepte."), v, 640)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UiTheme.MUTED)


func _usable_recipes() -> int:
	var p: YtPlayer = game.yp()
	var n := 0
	for r in YoutdCube.recipes():
		if YoutdCube.unlocked(r, p) and not YoutdCube.autofill(r, game.item_stash).is_empty():
			n += 1
	return n


func _refresh_recipes() -> void:
	var n := _usable_recipes()
	_rec_button.text = tr("Rezepte") + (" (%d)" % n if n > 0 else "")
	_rec_button.add_theme_color_override("font_color", UiTheme.HAVE if n > 0 else UiTheme.TEXT)
	if not is_open("recipes"):
		return
	var p: YtPlayer = game.yp()
	var key := str(game.item_stash.map(func(it): return [it.get_uid(), it.horadric_lock])) + str(p.get_builder().get_adds_extra_recipes())
	if key == _rec_key:
		return
	_rec_key = key
	for c in _rec_grid.get_children():
		_rec_grid.remove_child(c)
		c.queue_free()
	UiUtil.label("", _rec_grid)
	UiUtil.label("", _rec_grid)
	for rar in YoutdCube.RARITIES:
		var h := UiUtil.label(YoutdData.rarity_name(rar), _rec_grid, 14)
		h.add_theme_color_override("font_color", YoutdData.rarity_color(rar))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for r in YoutdCube.recipes():
		if not YoutdCube.unlocked(r, p):
			continue
		var name := UiUtil.label(recipe_name(r), _rec_grid, 15)
		name.add_theme_font_override("font", UiTheme.font(true))
		var desc := UiUtil.wrap_label(recipe_text(r), _rec_grid, 260)
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", UiTheme.MUTED)
		for i in YoutdCube.RARITIES.size():
			_recipe_cell(r, i)


## Feld eines Rezepts für eine Seltenheit: „vorhanden / nötig“, anklickbar, wenn es reicht.
func _recipe_cell(r: Dictionary, rarity: int) -> void:
	var to: int = rarity + int(r.get("rarity_change", 0))
	if to < 0 or to >= YoutdCube.RARITIES.size():
		var dash := UiUtil.label("–", _rec_grid, 14)
		dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dash.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	var have := YoutdCube.count(game.item_stash, rarity)
	var parts := []
	var need_text := []
	for k in [["permanent", have[0], "Items"], ["usable", have[1], "Öle"]]:
		var need := int(r.get(k[0], 0))
		if need > 0:
			parts.append("%d/%d" % [mini(int(k[1]), 99), need])
			need_text.append(tr("%d von %d %s") % [int(k[1]), need, tr(k[2])])
	var fill := YoutdCube.autofill_rarity(r, game.item_stash, rarity)
	var b := UiUtil.button(" · ".join(parts), _rec_grid, func():
		var list := YoutdCube.autofill_rarity(r, game.item_stash, rarity)
		if not list.is_empty():
			game.submit({"type": "transmute", "uids": list.map(func(it): return it.get_uid())}))
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(92, 30)
	b.disabled = fill.is_empty()
	if not fill.is_empty():
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(UiTheme.HAVE, 0.18), UiTheme.HAVE, 0, 2))
		b.add_theme_color_override("font_color", UiTheme.HAVE)
	b.tooltip_text = "%s (%s)\n%s\n%s" % [recipe_name(r), YoutdData.rarity_name(YoutdCube.RARITIES[rarity]), recipe_text(r),
			tr("Klick: jetzt ausführen") if not fill.is_empty() else tr("Im Lager: %s") % ", ".join(need_text)]


# --- Leiste und Meldungen ----------------------------------------------------------

func refresh() -> void:
	if _tomes == null:
		return
	visible = game.setup_done
	for c in [_tomes, _food]:
		(c.get_parent().get_parent() as Control).visible = game.setup_done
	for b in [_el_button, _rec_button]:
		b.visible = game.setup_done
	_tomes.text = str(game.tomes)
	_food.text = "%d / %d" % [game.food_used(), game.food_cap]
	_food.add_theme_color_override("font_color", UiTheme.MISSING if game.food_used() >= game.food_cap else UiTheme.TEXT)
	_refresh_elements()
	_refresh_recipes()
	_refresh_messages()
	refresh_timer()


func refresh_timer() -> void:
	if _next == null:
		return
	var more: bool = game.setup_done and game.phase < game.Phase.GAME_OVER and game.next_wave <= game.max_wave()
	_next.visible = more
	if not more:
		return
	if game.alive.is_empty():
		_next.text = tr("Welle %d · %d s") % [game.next_wave, ceili(maxf(game.next_wave_in, 0.0))]
	else:
		_next.text = tr("Welle %d schicken") % game.next_wave
	var lines := [tr("Nächste Welle sofort schicken (Taste N); laufende Wellen bleiben auf dem Feld.")]
	for w in game._upcoming_waves(3):
		lines.append("%s · %s%s\n   %s" % [tr("Welle %d") % w.number, tr(w.type), (" · " + w.state) if w.state != "" else "", w.detail])
	_next.tooltip_text = "\n".join(lines)


## Neue Meldungen kurz unter dem Banner zeigen; sie blenden nach MSG_TIME aus.
func _refresh_messages() -> void:
	var now: Array = game.log_lines.duplicate()
	if _msg_last == null or now == _msg_last:
		_msg_last = now
		return
	var old: Array = _msg_last
	_msg_last = now
	var added := now
	for d in old.size() + 1:
		var rest := old.slice(d)
		if now.slice(0, rest.size()) == rest:
			added = now.slice(rest.size())
			break
	for text in added:
		var l := UiUtil.label(str(text), _msgs, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", UiTheme.GOLD_DARK)
		l.add_theme_constant_override("outline_size", 4)
		# Auf dunkler Platte statt direkt auf dem Spielfeld (UI-Prüfung 2026-11-25, Lesbarkeit)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0, 0, 0, 0.62)
		plate.set_content_margin_all(4)
		plate.content_margin_left = 12
		plate.content_margin_right = 12
		l.add_theme_stylebox_override("normal", plate)
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tw := l.create_tween()
		tw.tween_interval(MSG_TIME)
		tw.tween_property(l, "modulate:a", 0.0, 0.8)
		tw.tween_callback(l.queue_free)
	while _msgs.get_child_count() > 4:
		var first := _msgs.get_child(0)
		_msgs.remove_child(first)
		first.queue_free()


## Name eines Rezepts.
static func recipe_name(r: Dictionary) -> String:
	match str(r.get("id", "")):
		"rebrew":
			return _t("Neu brauen")
		"distill":
			return _t("Destillieren")
		"reassemble":
			return _t("Umbauen")
		"perfect":
			return _t("Vervollkommnen")
		"liquefy":
			return _t("Verflüssigen")
		"precipitate":
			return _t("Ausfällen")
		"imbue":
			return _t("Durchtränken")
	return str(r.get("name", ""))


## „3 Items gleicher Seltenheit → 1 Item, Level +5 bis +25“.
static func recipe_text(r: Dictionary) -> String:
	var parts := []
	if int(r.get("permanent", 0)) > 0:
		parts.append(_t("%d Items") % int(r.permanent))
	if int(r.get("usable", 0)) > 0:
		parts.append(_t("%d Öle/Verbrauch") % int(r.usable))
	var res := _t("Öl/Verbrauch") if str(r.get("result", "")) == "usable" else _t("Item")
	var text := _t("%s gleicher Seltenheit → %d× %s") % [" + ".join(parts), int(r.get("count", 1)), res]
	var change := int(r.get("rarity_change", 0))
	if change > 0:
		text += ", " + _t("%d Seltenheit höher") % change
	elif change < 0:
		text += ", " + _t("%d Seltenheit niedriger") % -change
	if str(r.get("id", "")) == "precipitate":
		text += ", " + _t("beliebiges Level")
	elif int(r.get("level_max", 0)) > 0:
		text += ", " + _t("Level +%d bis +%d") % [int(r.level_min), int(r.level_max)]
	return text


static func _t(text: String) -> String:
	return str(TranslationServer.translate(text))


## Kurzinfo zu einem Tower für Tooltips.
static func tower_tip(id: String) -> String:
	var t := YoutdData.tower(id)
	var lines := [str(t.get("name", id)) + " · " + YoutdData.rarity_name(str(t.get("rarity", ""))) + " · " + YoutdData.element_name(str(t.get("element", "")))]
	var d: Array = t.get("damage", [0, 0])
	lines.append(_t("Schaden %d–%d (%s) · alle %s s · Reichweite %d") % [int(d[0]), int(d[1]), YoutdData.attack_name(str(t.get("attack_type", ""))),
			TowerStats.num(float(t.get("cooldown", 1.0)), 2), int(t.get("range", 0))])
	lines.append(_t("Kosten %d Gold · Food %d · Stufe %d") % [int(t.get("cost", 0)), YoutdData.food_cost(id), int(t.get("tier", 1))])
	lines.append_array(mod_lines(t.get("mods", [])))
	for a in ability_names(t):
		lines.append(a)
	var flavor := YoutdData.description("towers", id)
	if flavor != "":
		lines.append(flavor)
	return "\n".join(lines)


static func item_tip(id: String) -> String:
	var it := YoutdData.item(id)
	var type_name := str(TranslationServer.translate(str(YoutdData.rules().get("items", {}).get("type_names", {}).get(str(it.get("type", "")), ""))))
	var lines := [str(it.get("name", id)) + " · " + YoutdData.rarity_name(str(it.get("rarity", ""))) + " · " + type_name]
	lines.append(_t("Ab Welle %d") % int(it.get("level", 0)) if int(it.get("level", 0)) > 0 else "")
	lines.append(YoutdData.description("items", id))
	lines.append_array(mod_lines(it.get("mods", [])))
	lines.append_array(ability_names(it, true))
	return "\n".join(lines.filter(func(l): return l != ""))


## Tooltip eines Items im Lager: wie item_tip, dazu Ladungen und Werte des Skripts.
static func item_tip_for(it: YtItem) -> String:
	var text := item_tip(str(it.get_id()))
	if it.uses_charges():
		text += "\n" + _t("Ladungen: %d") % it.get_charges()
	if it.horadric_lock:
		text += "\n" + _t("Für den Würfel gesperrt")
	return text


## Fähigkeiten, Auren und Zauber eines Towers oder Items (Namen aus YouTD 2, englisch).
## texts: Beschreibung aus YouTD 2 dazu (Items; bei Towern zeigt sie die Auswahlkarte).
static func ability_names(d: Dictionary, texts := false) -> Array:
	var out := []
	var add := func(line: String, kind: String, id) -> void:
		var text := YoutdData.description(kind, str(id)) if texts else ""
		out.append(line + ("\n" + text if text != "" else ""))
	for id in d.get("abilities", []):
		var a := YtAbilityData.ability(int(id))
		if not a.is_empty():
			add.call(_t("Fähigkeit: %s") % str(a.get("name", "")), "abilities", id)
	for id in d.get("auras", []):
		var a := YtAbilityData.aura(int(id))
		if not a.is_empty() and not bool(a.get("hidden", false)) and str(a.get("name", "")) != "":
			add.call(_t("Aura: %s") % str(a.name), "auras", id)
	for id in d.get("autocasts", []):
		var a := YtAbilityData.autocast(int(id))
		if not a.is_empty():
			add.call(_t("Zauber: %s") % str(a.get("name", "")), "autocasts", id)
	return out


## "+25 % Schaden" usw. aus [[MOD, Wert, je Level]].
static func mod_lines(mods: Array) -> Array:
	var out := []
	var r := YoutdData.rules()
	for m in mods:
		var key := str(m[0])
		var flat: bool = (r.get("mod_flat", []) as Array).has(key)
		var name := str(TranslationServer.translate(str(r.get("mod_names", {}).get(key, key))))
		var line := "%s %s" % [_amount(float(m[1]), flat), name]
		if m.size() > 2 and float(m[2]) != 0.0:
			line += " " + _t("(%s je Level)") % _amount(float(m[2]), flat)
		out.append(line)
	return out


static func _amount(v: float, flat: bool) -> String:
	var sign := "+" if v >= 0.0 else ""
	return sign + (TowerStats.num(v, 1) if flat else TowerStats.num(v * 100.0, 2) + " %")
