extends Control
## Tower-Editor: Tower anlegen und bearbeiten, als JSON speichern und direkt im Spiel testen.
## Das Formular wird aus den Daten und aus Abilities.SCHEMA erzeugt.

const CATEGORIES := ["gem", "special"]
const CATEGORY_LABELS := ["Gem (zufällig würfelbar)", "Spezial (per Rezept)"]
const KINDS := ["tower", "trap"]
const KIND_LABELS := ["Tower (blockiert den Weg)", "Falle (Gegner laufen darüber)"]
const TARGETS := ["both", "ground", "air"]
const TARGET_LABELS := ["Boden und Luft", "Nur Boden", "Nur Luft"]

var current: Dictionary = {}
var ids: Array = []
var tower_list: ItemList
var form: VBoxContainer
var status_label: Label


var search: LineEdit
var list_ids: Array = []  ## Eintrag in tower_list -> Tower-ID ("" für Überschriften)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	add_child(outer)

	# Leiste oben
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BAR, UiTheme.BORDER, 0, 1, 10))
	outer.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	top.add_child(th)
	UiTheme.title(UiUtil.label("Tower-Editor", th, 20))
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	th.add_child(gap)
	UiUtil.button("+ Gem", th, func(): _new_tower("gem"))
	UiUtil.button("+ Spezial-Tower", th, func(): _new_tower("special"))
	UiUtil.button("Duplizieren", th, _duplicate)
	UiUtil.button("Datei importieren", th, _import).tooltip_text = "Tower-Datei (.json) laden, z. B. aus dem HTML-Editor"
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(fill)
	status_label = UiUtil.label("", th, 14)
	status_label.add_theme_color_override("font_color", UiTheme.MUTED)
	UiUtil.button("Speichern und testen", th, _test).tooltip_text = "Speichern und als nächsten Gem im Spiel setzen"
	var save := UiUtil.button("Speichern", th, _save)
	save.custom_minimum_size.x = 120
	UiTheme.accent_button(save, UiTheme.GOLD, UiTheme.GOLD_DARK, Color.TRANSPARENT)
	UiUtil.button("Zum Menü", th, func(): Session.goto(Session.MAIN_MENU))

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	outer.add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# Links: Liste mit Suche, gruppiert nach Art
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	search = LineEdit.new()
	search.placeholder_text = "Tower suchen"
	search.text_changed.connect(func(_t): _refresh_list(str(current.get("id", ""))))
	left.add_child(search)
	tower_list = ItemList.new()
	tower_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower_list.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.BORDER, 8, 1, 8))
	tower_list.add_theme_stylebox_override("selected", UiTheme.box(Color("2a0f2e"), UiTheme.GOLD, 4))
	tower_list.add_theme_stylebox_override("selected_focus", UiTheme.box(Color("2a0f2e"), UiTheme.GOLD, 4))
	tower_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tower_list.item_selected.connect(_on_tower_selected)
	left.add_child(tower_list)

	# Rechts: Formular
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	form = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 14)
	scroll.add_child(form)

	_refresh_list()
	for i in list_ids.size():
		if list_ids[i] != "":
			tower_list.select(i)
			_on_tower_selected(i)
			break


static func _group(def: Dictionary) -> int:
	if def.get("category", "gem") == "gem":
		return 0
	return 2 if def.get("kind", "tower") == "trap" else 1


func _refresh_list(select_id := "") -> void:
	ids = Database.tower_ids()
	tower_list.clear()
	list_ids.clear()
	var q := search.text.strip_edges().to_lower() if search != null else ""
	for g in 3:
		var header_added := false
		for id in ids:
			var def: Dictionary = Database.towers[id]
			if _group(def) != g:
				continue
			var label := "%s  [%s]" % [tr(str(def.get("name", id))), id]
			if q != "" and not q in label.to_lower():
				continue
			if not header_added:
				var h := tower_list.add_item(tr(["GEMS", "SPEZIAL-TOWER", "FALLEN"][g]), null, false)
				tower_list.set_item_custom_fg_color(h, UiTheme.MUTED)
				tower_list.set_item_disabled(h, true)
				list_ids.append("")
				header_added = true
			var idx := tower_list.add_item("   " + label)
			tower_list.set_item_custom_fg_color(idx, Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE).lerp(Color.WHITE, 0.2))
			list_ids.append(id)
	var i := list_ids.find(select_id) if select_id != "" else -1
	if i >= 0:
		tower_list.select(i)


func _on_tower_selected(i: int) -> void:
	if list_ids[i] == "":
		return
	current = Database.towers[list_ids[i]].duplicate(true)
	current.erase("_path")
	_build_form()


func _new_tower(category: String) -> void:
	current = {
		"id": "neuer_tower",
		"name": tr("Neuer Tower"),
		"category": category,
		"color": "#ffffff",
		"targets": "both",
		"tiers": [_default_tier()],
	}
	if category == "special":
		current["recipe"] = []
	tower_list.deselect_all()
	_build_form()


func _duplicate() -> void:
	if current.is_empty():
		return
	current = current.duplicate(true)
	current["id"] = str(current.get("id", "tower")) + "_kopie"
	current["name"] = str(current.get("name", "")) + tr(" (Kopie)")
	tower_list.deselect_all()
	_build_form()


func _import() -> void:
	UiUtil.open_json_file(self, func(d: Dictionary, file: String):
		if not d.get("tiers") is Array:
			status_label.text = tr("Keine Tower-Datei: ") + file
			return
		current = d
		if not current.has("id"):
			current["id"] = file.get_basename()
		tower_list.deselect_all()
		_build_form()
		status_label.text = tr("Importiert: %s. Speichern legt den Tower ab.") % file)


func _default_tier() -> Dictionary:
	return {"damage": [10, 15], "range": 3.0, "cooldown": 1.0, "abilities": []}


# --- Formular ----------------------------------------------------------------

func _build_form() -> void:
	for c in form.get_children():
		form.remove_child(c)
		c.queue_free()
	if current.is_empty():
		return

	var title := UiUtil.label(tr(str(current.get("name", ""))), form, 26)
	title.add_theme_color_override("font_color", Color.from_string(str(current.get("color", "#ffffff")), Color.WHITE).lerp(Color.WHITE, 0.25))
	var general := _section("Allgemein")
	_line_edit("ID (Dateiname)", "id", general)
	_line_edit("Name", "name", general)

	var cat_row := UiUtil.row("Kategorie", general, 220)
	var cat := _option(cat_row, CATEGORY_LABELS, CATEGORIES.find(current.get("category", "gem")))
	cat.item_selected.connect(func(i):
		current["category"] = CATEGORIES[i]
		if CATEGORIES[i] == "special" and not current.has("recipe"):
			current["recipe"] = []
		_build_form())

	var kind_row := UiUtil.row("Art", general, 220)
	var kind := _option(kind_row, KIND_LABELS, KINDS.find(current.get("kind", "tower")))
	kind.item_selected.connect(func(i): current["kind"] = KINDS[i])

	var color_row := UiUtil.row("Farbe", general, 220)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(96, 28)
	picker.color = Color.from_string(str(current.get("color", "#ffffff")), Color.WHITE)
	picker.color_changed.connect(func(c: Color): current["color"] = "#" + c.to_html(false))
	color_row.add_child(picker)

	_line_edit("Modell (optional, res://…glb)", "model", general)

	var target_row := UiUtil.row("Ziele", general, 220)
	var tgt := _option(target_row, TARGET_LABELS, TARGETS.find(current.get("targets", "both")))
	tgt.item_selected.connect(func(i): current["targets"] = TARGETS[i])

	_fx_option("Treffer-Effekt", "hit_fx", FxData.hit_ids(), general)
	_fx_option("Schuss-Effekt", "shot_fx", FxData.shot_ids(), general)

	if current.get("category", "gem") == "special":
		_build_recipe()
	_build_tiers()
	if current.get("category", "gem") == "special":
		_build_upgrades()


## Auswahl eines Effekts aus data/fx/ (fx_data.gd). "auto" wird nicht gespeichert.
func _fx_option(text: String, key: String, ids: Array, parent: Node) -> void:
	var r := UiUtil.row(text, parent, 220)
	var values: Array = [FxData.AUTO, FxData.NONE] + ids
	var labels: Array = [tr("Automatisch (nach Farbe)"), tr("Keiner")] + ids
	var o := _option(r, labels, values.find(str(current.get(key, FxData.AUTO))))
	o.item_selected.connect(func(i):
		if values[i] == FxData.AUTO:
			current.erase(key)
		else:
			current[key] = values[i]
		FxData.clear_cache())


func _line_edit(text: String, key: String, parent: Node) -> void:
	var r := UiUtil.row(text, parent, 220)
	var e := LineEdit.new()
	e.text = str(current.get(key, ""))
	e.custom_minimum_size.x = 260
	e.text_changed.connect(func(s): current[key] = s)
	r.add_child(e)


func _option(parent: Node, labels: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	for l in labels:
		o.add_item(l)
	o.select(maxi(selected, 0))
	parent.add_child(o)
	return o


## Abschnitt als Karte. Der Titel steht fett, ein Hinweis (nach " (") darunter klein.
func _section(title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.BORDER, 10, 1, 16))
	form.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var parts := tr(title).split(" (", true, 1)
	UiUtil.label(parts[0], box, 18).add_theme_color_override("font_color", UiTheme.GOLD)
	if parts.size() > 1:
		var hint := UiUtil.label(parts[1].trim_suffix(")"), box, 13)
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return box


func _build_recipe() -> void:
	var box := _section("Rezept (der ausgewählte Gem muss eine Zutat sein; die anderen werden zu Steinen)")
	if not current.has("recipe"):
		current["recipe"] = []
	var same := CheckBox.new()
	same.text = "Nur aus Gems derselben Runde (sonst auch fertige Tower auf dem Feld)"
	same.button_pressed = bool(current.get("recipe_same_round", false))
	same.toggled.connect(func(on): current["recipe_same_round"] = on)
	box.add_child(same)
	_ingredient_list(box, current["recipe"])


## Zeilen für eine Zutatenliste [{tower, tier}] mit Hinzufügen/Entfernen.
func _ingredient_list(box: Node, recipe: Array) -> void:
	var ids := Database.tower_ids()
	for k in recipe.size():
		var ing: Dictionary = recipe[k]
		if ing.has("any_of"):
			var r0 := HBoxContainer.new()
			box.add_child(r0)
			var names: Array = ing.any_of.map(func(a): return Database.tower_label(str(a.get("tower", "")), int(a.get("tier", 0))))
			UiUtil.label(tr("Einer von: ") + ", ".join(names), r0)
			_any_of_row(box, ing.any_of)
			UiUtil.button("Entfernen", r0, func():
				recipe.remove_at(k)
				_build_form())
			continue
		if str(ing.get("tower", "")) == "" and not ids.is_empty():
			ing["tower"] = ids[0]
		var r := HBoxContainer.new()
		box.add_child(r)
		var o := _option(r, ids.map(func(id): return tr(str(Database.towers[id].get("name", id)))), ids.find(ing.get("tower", "")))
		o.item_selected.connect(func(i): ing["tower"] = ids[i])
		UiUtil.label("Stufe", r)
		var tier_labels := []
		for t in Database.TIER_NAMES.size():
			tier_labels.append("%d – %s" % [t + 1, tr(Database.TIER_NAMES[t])])
		var to := _option(r, tier_labels, int(ing.get("tier", 0)))
		to.item_selected.connect(func(i): ing["tier"] = i)
		UiUtil.button("Entfernen", r, func():
			recipe.remove_at(k)
			_build_form())
	var add_row := HBoxContainer.new()
	box.add_child(add_row)
	UiUtil.button("+ Zutat", add_row, func():
		recipe.append({"tower": Database.gem_ids()[0] if not Database.gem_ids().is_empty() else "", "tier": 0})
		_build_form())
	UiUtil.button("+ Zutat „einer von …“", add_row, func():
		recipe.append({"any_of": []})
		_build_form())


## Alternativen einer „einer von“-Zutat, eingerückt.
func _any_of_row(box: Node, alts: Array) -> void:
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 40)
	box.add_child(inner)
	var v := VBoxContainer.new()
	inner.add_child(v)
	_ingredient_list(v, alts)


## Upgrade von Stufe i auf i+1: Zutaten müssen als fertige Tower auf dem Feld stehen und werden zu Steinen.
func _build_upgrades() -> void:
	var tiers: Array = current.get("tiers", [])
	if tiers.size() < 2:
		return
	var box := _section("Upgrades (Goldkosten; optionale Zutaten müssen fertig auf dem Feld stehen und werden zu Steinen)")
	if not current.has("upgrades"):
		current["upgrades"] = []
	var ups: Array = current["upgrades"]
	while ups.size() < tiers.size() - 1:
		ups.append({"recipe": [], "cost": 0})
	for i in tiers.size() - 1:
		var up: Dictionary = ups[i]
		if not up.has("recipe"):
			up["recipe"] = []
		UiUtil.label(tr("Stufe %d → %d") % [i + 1, i + 2], box, 16)
		UiUtil.spin(UiUtil.row("Goldkosten", box), float(up.get("cost", 0)), 0, 100000, 1, func(x): up["cost"] = int(x))
		_ingredient_list(box, up["recipe"])


func _build_tiers() -> void:
	var box := _section("Stufen (bei Gems: Splitter, Fehlerhaft, Normal, Makellos, Perfekt, Großartig)")
	var tiers: Array = current.get("tiers", [])
	current["tiers"] = tiers
	for i in tiers.size():
		var tier: Dictionary = tiers[i]
		if not tier.has("damage"):
			tier["damage"] = [10, 15]
		if not tier.has("abilities"):
			tier["abilities"] = []
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 8, 1, 12))
		box.add_child(panel)
		var v := VBoxContainer.new()
		panel.add_child(v)

		var head := HBoxContainer.new()
		v.add_child(head)
		var title := tr("Stufe %d") % (i + 1)
		if current.get("category", "gem") == "gem" and i < Database.TIER_NAMES.size():
			title += " – " + tr(Database.TIER_NAMES[i])
		UiUtil.label(title, head, 16)
		UiUtil.button("Entfernen", head, func():
			tiers.remove_at(i)
			_build_form())

		var dmg: Array = tier.damage
		var dr := UiUtil.row("Schaden min / max", v)
		UiUtil.spin(dr, float(dmg[0]), 0, 100000, 1, func(x): dmg[0] = int(x))
		UiUtil.spin(dr, float(dmg[1]), 0, 100000, 1, func(x): dmg[1] = int(x))
		UiUtil.spin(UiUtil.row("Reichweite (Towerbreiten)", v), float(tier.get("range", 3.0)), 0.5, 30, 0.25, func(x): tier["range"] = x)
		UiUtil.spin(UiUtil.row("Abklingzeit (s)", v), float(tier.get("cooldown", 1.0)), 0.05, 10, 0.05, func(x): tier["cooldown"] = x)

		var abilities: Array = tier.abilities
		var types := Abilities.types()
		for j in abilities.size():
			var ab: Dictionary = abilities[j]
			var ar := HBoxContainer.new()
			v.add_child(ar)
			var labels := types.map(func(t): return Abilities.SCHEMA[t].label)
			var o := _option(ar, labels, types.find(ab.get("type", "")))
			o.item_selected.connect(func(idx):
				abilities[j] = Abilities.default_for(types[idx])
				_build_form())
			var params: Dictionary = Abilities.SCHEMA.get(ab.get("type", ""), {}).get("params", {})
			for p in params:
				UiUtil.label(Abilities.PARAM_LABELS.get(p, p), ar)
				var is_int: bool = typeof(params[p]) == TYPE_INT
				UiUtil.spin(ar, float(ab.get(p, params[p])), 0, 1000, 1.0 if is_int else 0.05,
						func(x): ab[p] = int(x) if is_int else x)
			UiUtil.button("×", ar, func():
				abilities.remove_at(j)
				_build_form())
		UiUtil.button("+ Fähigkeit", v, func():
			abilities.append(Abilities.default_for(types[0]))
			_build_form())

	UiUtil.button("+ Stufe", box, func():
		tiers.append(tiers.back().duplicate(true) if not tiers.is_empty() else _default_tier())
		_build_form())


# --- Speichern / Testen ------------------------------------------------------

func _validate() -> String:
	var id := str(current.get("id", ""))
	if RegEx.create_from_string("^[a-z0-9_]+$").search(id) == null:
		return tr("Ungültige ID: nur Kleinbuchstaben, Ziffern und _ erlaubt.")
	if (current.get("tiers", []) as Array).is_empty():
		return tr("Der Tower braucht mindestens eine Stufe.")
	if current.get("category") == "special" and (current.get("recipe", []) as Array).is_empty():
		return tr("Ein Spezial-Tower braucht ein Rezept.")
	return ""


func _save() -> bool:
	var err := _validate()
	if err != "":
		status_label.text = err
		return false
	var data := current.duplicate(true)
	if str(data.get("model", "")) == "":
		data.erase("model")
	if data.get("category") != "special":
		data.erase("recipe")
		data.erase("upgrades")
	elif data.has("upgrades"):
		data["upgrades"] = (data["upgrades"] as Array).slice(0, maxi((data["tiers"] as Array).size() - 1, 0))
	var path := Database.writable_path("towers", str(data.id))
	if not Database.save_json(path, data):
		status_label.text = tr("Speichern fehlgeschlagen: ") + path
		return false
	Database.reload()
	_refresh_list(str(data.id))
	status_label.text = tr("Gespeichert: ") + path
	return true


func _test() -> void:
	if not _save():
		return
	Session.test_tower = "%s:0" % current.id
	Session.map_override = null
	Session.return_scene = Session.TOWER_EDITOR
	Session.goto(Session.GAME)
