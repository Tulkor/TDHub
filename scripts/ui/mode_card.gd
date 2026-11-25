class_name ModeCard
extends Button
## Karte für einen TD-Modus (Einzelspieler-Auswahl und Lobby): Name, Beschreibung, erlaubte Spielerzahl.
## Ausgewählt (bzw. eigene Stimme) wie alle gedrückten Knöpfe: Cyan mit dunkler Schrift.
## In der Lobby kommen unter die Beschreibung Stimmen-Balken und Namen (set_votes).

var mode_id := ""
var compact := false  ## Beschreibung nur bei der gewählten Karte (Einzelspieler-Liste, damit alle Modi Platz haben)
var _labels: Array[Label] = []
var _name: Label
var _hint: Label
var _players: Label
var _tag: Label
var _votes_box: VBoxContainer
var _bar_fill: ColorRect
var _count: Label
var _who: Label


func _init(m: Dictionary, card_size := Vector2(330, 190)) -> void:
	mode_id = str(m.get("id", ""))
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = card_size
	add_theme_stylebox_override("normal", DecoTheme.box(Color.TRANSPARENT, DecoTheme.GOLD, 0, 1))
	add_theme_stylebox_override("hover", DecoTheme.box(DecoTheme.PANEL, DecoTheme.BRASS_LIGHT, 0, 1))
	add_theme_stylebox_override("disabled", DecoTheme.box(Color.TRANSPARENT, DecoTheme.BORDER, 0, 1))
	add_theme_stylebox_override("pressed", DecoTheme.frame(DecoTheme.BRASS_LIGHT, Color.TRANSPARENT, Color.TRANSPARENT, 16))
	add_theme_stylebox_override("hover_pressed", DecoTheme.frame(DecoTheme.BRASS_LIGHT.lightened(0.1), Color.TRANSPARENT, Color.TRANSPARENT, 16))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 14
	v.offset_right = -16
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_name = _label(str(m.get("name", mode_id)), v, 28)
	DecoTheme.display(_name, 28, 2)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = card_size.x - 32
	# Hinweis („Kommt noch“, erlaubte Spielerzahl) unter dem Namen, damit lange Namen Platz haben
	_tag = _label("", v, 14)
	_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hint = _label(tr(str(m.get("hint", ""))), v, 15)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = card_size.x - 32
	_votes_box = VBoxContainer.new()
	_votes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_votes_box.add_theme_constant_override("separation", 4)
	_votes_box.visible = false
	v.add_child(_votes_box)
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = DecoTheme.BORDER
	bar.custom_minimum_size.y = 10
	_votes_box.add_child(bar)
	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.color = DecoTheme.GOLD
	_bar_fill.anchor_bottom = 1.0
	bar.add_child(_bar_fill)
	_count = _label("", _votes_box, 15)
	_who = _label("", _votes_box, 14)
	_who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_who.custom_minimum_size.x = card_size.x - 32
	var fill := Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	_players = _label(Database.mode_players_text(mode_id), v, 15)
	# Die Karte wächst mit dem Inhalt (größere Schrift, lange Übersetzungen), statt ihn unten herausragen zu lassen
	var base_h := card_size.y
	v.minimum_size_changed.connect(func():
		custom_minimum_size.y = maxf(base_h, v.get_combined_minimum_size().y + 28.0))
	set_state(false, true)


func _label(text: String, parent: Node, font_size: int) -> Label:
	var l := UiUtil.label(text, parent, font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.append(l)
	return l


## on: ausgewählt / eigene Stimme. enabled false: grau, nicht anklickbar. tag: kleiner Hinweis oben rechts.
func set_state(on: bool, enabled: bool, tag := "") -> void:
	disabled = not enabled
	set_pressed_no_signal(on and enabled)
	_players.text = Database.mode_players_text(mode_id)
	_tag.text = tag.to_upper()
	_tag.visible = tag != ""
	_hint.visible = not compact or (on and enabled)
	var dark := on and enabled
	var main := DecoTheme.GOLD_DARK if dark else (DecoTheme.TEXT if enabled else DecoTheme.BORDER_2)
	var soft := DecoTheme.GOLD_DARK if dark else (DecoTheme.BRASS_LIGHT if enabled else DecoTheme.BORDER_2)
	_name.add_theme_color_override("font_color", main)
	_count.add_theme_color_override("font_color", main)
	_hint.add_theme_color_override("font_color", soft)
	_who.add_theme_color_override("font_color", soft)
	_players.add_theme_color_override("font_color", DecoTheme.GOLD_DARK if dark else (DecoTheme.TEXT if enabled else DecoTheme.BORDER_2))
	_hint.add_theme_font_override("font", DecoTheme.font(dark))
	var tag_box := DecoTheme.box(Color.TRANSPARENT, soft, 0, 2, 5)
	_tag.add_theme_stylebox_override("normal", tag_box)
	_tag.add_theme_color_override("font_color", soft)


## Lobby: Stimmen anzeigen (total = alle Spieler, für die Balkenlänge). note ersetzt den Zähler.
func set_votes(count: int, total: int, names: Array, note := "") -> void:
	_votes_box.visible = true
	_bar_fill.get_parent().visible = note == ""
	_bar_fill.anchor_right = float(count) / maxf(total, 1)
	_count.text = note if note != "" else (tr("%d Stimme") % count if count == 1 else tr("%d Stimmen") % count)
	_who.text = ", ".join(names)
	_who.visible = not names.is_empty()


func hide_votes() -> void:
	_votes_box.visible = false
