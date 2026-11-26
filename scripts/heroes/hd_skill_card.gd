class_name HdSkillCard
extends PanelContainer
## Fähigkeitskarte im Bollwerk-HUD (Baukasten K3, Lukas 2026-11-25): nur das Symbol auf eingetieftem Leder,
## Taste oben links und Manakosten unten rechts direkt auf der Karte (kontrastreich, ohne eigenes Schild),
## Abklingzeit dunkelt die Karte ab und zeigt die Zahl mit dunklem Schein. Darunter Rang-Rauten, darüber die
## Aufwertungs-Plakette (Plus). Tooltip im MOBA-Stil mit den Werten aller Ränge.

var game  ## HdGame
var slot := 0
var glyph: TextureRect
var key: Label
var mana: Label
var cd_label: Label
var shade: Shade
var pips: Pips
var plus: Plus
var _flash := 0.0
## Dauer des Aufleuchtens, wenn eine Abklingzeit vorzeitig zurückgesetzt wird (Lukas 2026-11-25).
const FLASH_TIME := 0.75


func _init(owner_game, index: int) -> void:
	game = owner_game
	slot = index
	add_theme_stylebox_override("panel", HdUiStyle.skill_frame())
	custom_minimum_size = Vector2(88, 88)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = " "
	var cv := Control.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cv)
	glyph = TextureRect.new()
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.material = HdUiStyle.icon_metal_material()
	cv.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 6
	glyph.offset_top = 6
	glyph.offset_right = -6
	glyph.offset_bottom = -6
	shade = Shade.new()
	cv.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key = HdUiStyle.card_text(Label.new(), HdUiStyle.KEY_TEXT, 14)
	cv.add_child(key)
	key.position = Vector2(4, 0)
	mana = HdUiStyle.card_text(Label.new(), HdUiStyle.MANA_TEXT, 14)
	cv.add_child(mana)
	mana.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	mana.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mana.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mana.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mana.offset_right = -4
	mana.offset_bottom = 1
	cd_label = HdUiStyle.card_text(Label.new(), HdUiStyle.KEY_TEXT, 24)
	cd_label.add_theme_constant_override("outline_size", 6)
	cd_label.add_theme_constant_override("shadow_outline_size", 16)
	cd_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(cd_label)
	cd_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pips = Pips.new()
	if slot < 4:
		plus = Plus.new()
		plus.card = self


func _ready() -> void:
	set_process(false)


func _make_custom_tooltip(_for_text: String) -> Object:
	return HdSkillCard.tooltip(game.hero, slot, false)


## Abklingzeit wurde vorzeitig zurückgesetzt: Karte leuchtet kurz auf, ein Lichtrahmen läuft nach außen.
func flash() -> void:
	_flash = FLASH_TIME
	set_process(true)
	queue_redraw()


func _process(dt: float) -> void:
	_flash = maxf(0.0, _flash - dt)
	var k := _flash / FLASH_TIME
	glyph.self_modulate = Color.WHITE.lerp(Color(1.9, 1.7, 1.25), k)
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)


func _draw() -> void:
	if _flash <= 0.0:
		return
	var k := _flash / FLASH_TIME
	var rect := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(HdUiStyle.SlotFrame.octagon(rect.grow(-2.0), 8.0), Color(1.0, 0.9, 0.65, 0.32 * k))
	for i in 3:
		var spread := 2.0 + float(i) * 2.5 + (1.0 - k) * 5.0
		var ring := HdUiStyle.SlotFrame.octagon(rect.grow(spread), 9.0 + spread * 0.4)
		HdUiStyle.aa_loop(get_canvas_item(), ring, Color(1.0, 0.92, 0.68, k * (1.0 - float(i) * 0.28)), 3.2 - float(i) * 0.9)


## Lange Tastennamen kürzen (Lukas 2026-11-25): Leertaste → Leer, Shift → Umsch, sonst höchstens 4 Zeichen.
static func short_key(text: String) -> String:
	var names := {"Leertaste": "Leer", "Space": "Leer", "Shift": "Umsch", "Ctrl": "Strg", "Control": "Strg", "Escape": "Esc", "Alt": "Alt", "Tab": "Tab"}
	for k in names:
		if text == k or text == TranslationServer.translate(k):
			return TranslationServer.translate(names[k])
	return text if text.length() <= 4 else text.left(4)


## Karte auf den Stand des Helden bringen (vom HUD 10-mal pro Sekunde).
func show_state(key_text: String, cost: float, cooldown: float, total: float, locked_text: String, highlighted: bool, nomana: bool) -> void:
	key_text = HdSkillCard.short_key(key_text)
	if key.text != key_text:
		key.text = key_text
		key.add_theme_font_size_override("font_size", 14 if key_text.length() <= 2 else 12)
	mana.text = "" if cost <= 0.0 else str(roundi(cost))
	mana.add_theme_color_override("font_color", HdUiStyle.NO_MANA_TEXT if nomana else HdUiStyle.MANA_TEXT)
	var blocked := locked_text != "" or nomana
	add_theme_stylebox_override("panel", HdUiStyle.skill_frame(highlighted, blocked))
	glyph.modulate = Color(0.62, 0.66, 0.74) if blocked else HdUiStyle.GOLD
	if locked_text != "":
		cd_label.text = locked_text
		cd_label.add_theme_font_size_override("font_size", 13)
		shade.set_state(1.0, true)
	elif cooldown > 0.0:
		cd_label.text = ("%d" % ceili(cooldown)) if cooldown >= 10.0 else ("%.1f" % cooldown)
		cd_label.add_theme_font_size_override("font_size", 24)
		shade.set_state(clampf(cooldown / maxf(total, 0.01), 0.0, 1.0), true)
	else:
		cd_label.text = ""
		shade.set_state(0.0, false)


## Tooltip im MOBA-Stil: Kopf mit Symbol, Taste und Rang, Kosten, Tags, Beschreibung, Werte aller Ränge
## (aktueller in Gold, beim Zeigen auf das Plus der nächste in Grün).
static func tooltip(hero: HdHero, index: int, next: bool) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 340
	box.add_theme_constant_override("separation", 5)
	var tr_ := func(t: String) -> String: return TranslationServer.translate(t)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.material = HdUiStyle.icon_metal_material()
	icon.modulate = HdUiStyle.GOLD
	head.add_child(icon)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	var name_label := Label.new()
	name_label.add_theme_font_override("font", HdUiStyle.font(true))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", HdUiStyle.GOLD_HI)
	titles.add_child(name_label)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", HdUiStyle.COLORS.MUTED)
	titles.add_child(sub)
	var cost := RichTextLabel.new()
	cost.bbcode_enabled = true
	cost.fit_content = true
	cost.scroll_active = false
	cost.add_theme_font_size_override("normal_font_size", 13)
	box.add_child(cost)
	var icons = preload("res://scripts/heroes/hd_ability_icons.gd")
	var game = hero.game
	if index >= 4:
		icon.texture = icons.texture("dodge")
		name_label.text = tr_.call("Ausweichen")
		sub.text = tr_.call("Leertaste")
		cost.text = tr_.call("Abklingzeit") + " %.1f s" % float(hero.def.dodge.cooldown)
		return box
	var a := hero.ability(index)
	icon.texture = icons.texture(icons.key(str(hero.def.id), a, index))
	name_label.text = tr_.call(str(a.name))
	var top := int(hero.skills.cfg.max_rank)
	var rank: int = hero.skills.ranks[index]
	sub.text = "%s · %s" % [game.key_name(index), tr_.call("Rang %d / %d") % [rank, top]]
	var parts: Array = []
	var mana_cost: float = hero.ability_cost(index)
	parts.append("[color=#%s]%d %s[/color]" % [(HdUiStyle.MANA_TEXT if hero.mana >= mana_cost else HdUiStyle.NO_MANA_TEXT).to_html(false), roundi(mana_cost), tr_.call("Mana")])
	var cd_now: float = float(hero.skills.metrics(a).get("cooldown", float(a.get("cooldown", 0.0))))
	parts.append("%s %.1f s" % [tr_.call("Abklingzeit"), cd_now])
	cost.text = "    ".join(parts)
	var tags: String = hero.skills.tag_text(a)
	if tags != "":
		var tag_label := Label.new()
		tag_label.text = tags
		tag_label.add_theme_font_size_override("font_size", 11)
		tag_label.add_theme_color_override("font_color", HdUiStyle.COLORS.MUTED)
		box.add_child(tag_label)
	var desc := Label.new()
	desc.text = tr_.call(str(a.get("desc", a.get("summary", ""))))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 340
	desc.add_theme_font_size_override("font_size", 13)
	box.add_child(desc)
	var rows: Array = hero.skills.rank_table(index)
	if not rows.is_empty():
		var sep := HSeparator.new()
		box.add_child(sep)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 2)
		box.add_child(grid)
		var can_next: bool = next and rank < top
		for row in rows:
			var label := Label.new()
			label.text = str(row.label)
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", HdUiStyle.COLORS.MUTED)
			grid.add_child(label)
			var values := RichTextLabel.new()
			values.bbcode_enabled = true
			values.fit_content = true
			values.scroll_active = false
			values.autowrap_mode = TextServer.AUTOWRAP_OFF
			values.custom_minimum_size.x = 210
			values.add_theme_font_size_override("normal_font_size", 12)
			values.add_theme_color_override("default_color", Color("8b8476"))
			var unit := "" if str(row.unit) == "" else (" " + str(row.unit))
			if not row.varies:
				values.text = "[color=#%s]%s%s[/color]" % [HdUiStyle.GOLD_HI.to_html(false), row.values[0], unit]
			else:
				var cells: Array = []
				for r in row.values.size():
					var v: String = row.values[r]
					if r == rank - 1:
						v = "[color=#%s]%s[/color]" % [HdUiStyle.GOLD_HI.to_html(false), v]
					elif can_next and r == rank:
						v = "[color=#%s]%s[/color]" % [HdUiStyle.UPGRADE.to_html(false), v]
					cells.append(v)
				values.text = " / ".join(cells) + unit
			grid.add_child(values)
	var foot: Array = []
	if a.has("ascended"):
		foot.append("%s: [color=#%s]%s[/color] · %s" % [tr_.call("Aufgestiegen"), HdUiStyle.GOLD.to_html(false), tr_.call(str(a.ascended.get("name", ""))), tr_.call(str(a.ascended.get("desc", "")))])
	if next:
		foot.append("[color=#%s][+][/color] %s" % [HdUiStyle.UPGRADE.to_html(false), tr_.call("Kostet 1 Fähigkeitspunkt") if rank < top else tr_.call("Höchstrang erreicht oder Fähigkeit noch gesperrt")])
	if not foot.is_empty():
		var f := RichTextLabel.new()
		f.bbcode_enabled = true
		f.fit_content = true
		f.scroll_active = false
		f.custom_minimum_size.x = 340
		f.add_theme_font_size_override("normal_font_size", 11)
		f.add_theme_color_override("default_color", HdUiStyle.COLORS.MUTED)
		f.text = "\n".join(foot)
		box.add_child(f)
	return box


## Abklingzeit: ganze Karte leicht abgedunkelt, der verbleibende Anteil (im Uhrzeigersinn ab oben) stark,
## mit heller Kante am Übergang. Auf das Achteck der Karte beschnitten.
class Shade extends Control:
	var ratio := 0.0
	var active := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(r: float, on: bool) -> void:
		if is_equal_approx(r, ratio) and on == active:
			return
		ratio = r
		active = on
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var rect := Rect2(Vector2.ZERO, size)
		var octagon := HdUiStyle.SlotFrame.octagon(rect, 7.0)
		draw_colored_polygon(octagon, Color(0.012, 0.024, 0.05, 0.45))
		if ratio <= 0.0:
			return
		var c := rect.get_center()
		var radius := size.length()
		var start := -PI * 0.5 + TAU * (1.0 - ratio)
		var pie := PackedVector2Array([c])
		var steps := maxi(2, ceili(ratio * 48.0))
		for i in steps + 1:
			pie.append(c + Vector2.from_angle(start + TAU * ratio * float(i) / float(steps)) * radius)
		for part in Geometry2D.intersect_polygons(pie, octagon):
			draw_colored_polygon(part, Color(0.012, 0.024, 0.05, 0.62))
		if ratio < 1.0:
			draw_line(c, c + Vector2.from_angle(start) * minf(size.x, size.y) * 0.46, Color(0.94, 0.84, 0.64, 0.8), 1.0, true)


## Rang-Rauten unter der Karte; beim Zeigen auf das Plus leuchtet der nächste Rang grün.
class Pips extends Control:
	var rank := 1
	var top := 7
	var preview := false

	func _init() -> void:
		custom_minimum_size = Vector2(80, 9)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_rank(r: int, t: int) -> void:
		if r == rank and t == top:
			return
		rank = r
		top = t
		queue_redraw()

	func _draw() -> void:
		if top <= 0:
			return
		var step := 9.0
		var x0 := (size.x - step * float(top - 1)) * 0.5
		for i in top:
			var c := Vector2(x0 + step * float(i), size.y * 0.5)
			var d := 3.4
			var pts := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
			var on := i < rank
			var nxt := preview and i == rank
			draw_colored_polygon(pts, HdUiStyle.GOLD if on else (Color("1f4a28") if nxt else Color("1c1b18")))
			var rim := Color("f6e2b0") if on else (HdUiStyle.UPGRADE if nxt else Color("5d523f"))
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_polyline(loop, rim, 1.0, true)


## Aufwertungs-Plakette über der Karte (zwei Drittel der Kartenbreite).
class Plus extends Button:
	var card: HdSkillCard

	func _init() -> void:
		HdUiStyle.upgrade_button(self)
		tooltip_text = " "
		focus_mode = Control.FOCUS_NONE
		mouse_entered.connect(func():
			card.pips.preview = true
			card.pips.queue_redraw())
		mouse_exited.connect(func():
			card.pips.preview = false
			card.pips.queue_redraw())

	func _make_custom_tooltip(_for_text: String) -> Object:
		return HdSkillCard.tooltip(card.game.hero, card.slot, true)
