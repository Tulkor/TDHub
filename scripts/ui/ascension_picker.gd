class_name AscensionPicker
extends VBoxContainer
## Wahl der Aufstiegsstufe (+1, +2, …) in den Startfenstern aller Modi (ascension.gd). Steht unter den Knöpfen
## für die Schwierigkeit; das Startfenster meldet mit set_difficulty(), was dort gewählt ist. Wählbar nur auf der
## höchsten angebotenen Schwierigkeit und bis zur freigeschalteten Stufe. Stil des Startfensters: UiTheme (mit dem
## Skin des Modus) oder DecoTheme (Shopping Maul).

signal changed

var mode := "gemtd"     ## Profil-ID des Modus (Freischaltung und Regeln)
var count := 3          ## Anzahl Schwierigkeiten in der Liste des Modus
var difficulty := 0
var level := 0
var host := true        ## Mitspieler sehen nur, was gilt
var wrap_width := 470.0
var th = UiTheme        ## UiTheme oder DecoTheme

var _down: Button
var _up: Button
var _value: Label
var _info: Label
var _text: Label


## Startwerte; level = letzte Wahl (wird auf das Freigeschaltete begrenzt).
func setup(mode_id: String, diff_count: int, diff: int, last_level: int, is_host := true, deco := false, width := 470.0) -> AscensionPicker:
	mode = mode_id
	count = diff_count
	difficulty = diff
	level = clampi(last_level, 0, Ascension.unlocked(mode))
	host = is_host
	wrap_width = width
	th = DecoTheme if deco else UiTheme
	return self


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var cap: Label = th.caption("Aufstieg", row)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.custom_minimum_size.x = 110
	_down = UiUtil.button("◄", row, func(): _step(-1))
	_value = UiUtil.label("", row, 22)
	_value.add_theme_font_override("font", th.font(true))
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.custom_minimum_size.x = 64
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_up = UiUtil.button("►", row, func(): _step(1))
	for b in [_down, _up]:
		b.custom_minimum_size = Vector2(42, 36)
		b.focus_mode = Control.FOCUS_NONE
	_info = UiUtil.label("", row, 14)
	_info.add_theme_color_override("font_color", th.MUTED)
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text = UiUtil.wrap_label("", self, wrap_width)
	_text.add_theme_color_override("font_color", th.DIM)
	_refresh()


## Die Schwierigkeit im Startfenster hat sich geändert.
func set_difficulty(diff: int) -> void:
	difficulty = diff
	_refresh()


## Anderer Modus (GemTD ↔ Roguelike: eigene Freischaltung).
func set_mode(mode_id: String) -> void:
	mode = mode_id
	level = mini(level, Ascension.unlocked(mode))
	_refresh()


## Gilt die Stufe gerade (nur auf der höchsten Schwierigkeit)?
func chosen() -> int:
	return level if on_top() else 0


func on_top() -> bool:
	return difficulty == Ascension.top(mode, count)


func _step(d: int) -> void:
	level = clampi(level + d, 0, Ascension.unlocked(mode))
	_refresh()
	changed.emit()


func _refresh() -> void:
	if _value == null:
		return
	var open := Ascension.unlocked(mode)
	var top := on_top()
	var lv := chosen()
	_value.text = Ascension.label(lv) if lv > 0 else "–"
	_value.add_theme_color_override("font_color", th.GOLD if lv > 0 else th.MUTED)
	_down.disabled = not host or not top or level <= 0
	_up.disabled = not host or not top or level >= open
	var best := Ascension.best(mode)
	_info.text = tr("frei bis %s") % Ascension.label(open) if open > 0 else tr("noch keine Stufe frei")
	if best > 0:
		_info.text += " · " + tr("Rekord %s") % Ascension.label(best)
	var top_name := _top_name()
	if not top:
		_text.text = tr("Aufstiegsstufen gibt es nur auf %s.") % top_name
	elif lv > 0:
		var lines: Array = Ascension.mods(mode, lv).lines
		_text.text = " · ".join(lines) if not lines.is_empty() else tr("Keine Änderung auf dieser Stufe.")
	elif open == 0:
		_text.text = tr("Gewinne auf %s, um +1 freizuschalten. Jede Stufe macht die Gegner stärker, die nächste gibt es für einen Sieg auf der höchsten.") % top_name
	else:
		_text.text = tr("Ohne Aufstieg. Mit ► eine Stufe wählen, ein Sieg auf %s schaltet %s frei.") % [Ascension.label(open), Ascension.label(open + 1)]
	if not host:
		_text.text += " " + tr("Die Stufe wählt der Host.")


## Name der Schwierigkeit, auf der man aufsteigt.
func _top_name() -> String:
	var i := Ascension.top(mode, count)
	var list: Array = []
	match mode:
		"gemtd", "roguelike":
			list = Session.DIFFICULTIES
		"eeve":
			list = Database.eeve.get("difficulties", [])
		"randgruppen":
			list = Database.randgruppen.get("difficulties", [])
		"maul":
			list = MaulData.rules().get("difficulties", [])
		"youtd":
			list = YoutdData.rules().get("difficulties", [])
	return tr(str(list[i].get("name", ""))) if i >= 0 and i < list.size() else tr("Schwer")
