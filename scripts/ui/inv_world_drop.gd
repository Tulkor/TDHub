class_name InvWorldDrop
extends Node
## Items wie in Warcraft III direkt auf einen Tower in der Spielwelt ziehen, auch wenn er nicht ausgewählt ist.
## Läuft für alle Modi mit Inventar: Wird ein Inventarfeld (InvSlot, Daten mit "inv") gezogen, zeigt ein Schild an der
## Maus, ob der Tower darunter das Item nimmt („+ Einlegen · 3 frei“) oder nicht („Inventar voll“), der Modus färbt das
## Feld des Towers grün oder rot (mark). Losgelassen über einem Tower ruft es drop auf, sonst passiert nichts.

var tower_at: Callable   ## func() -> Object: Tower unter der Maus oder null
var reason: Callable     ## func(tower, data) -> String: "" = nimmt das Item, sonst warum nicht
var hint: Callable       ## func(tower, data) -> String: Text, wenn es geht (z. B. „+ Einlegen · 3 frei“)
var drop: Callable       ## func(tower, data) -> void
var mark: Callable       ## func(tower, ok: bool) -> void; tower null = Markierung weg
var tell: Callable       ## func(text) -> void: Meldung, wenn der Tower das Item nicht nimmt

var data = null          ## gerade gezogene Inventardaten (null = kein Ziehen)
var _layer: CanvasLayer
var _tag: PanelContainer
var _label: Label
var _last = null


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_tag = PanelContainer.new()
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = false
	_layer.add_child(_tag)
	_label = UiUtil.label("", _tag, 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func active() -> bool:
	return data != null


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var d = get_viewport().gui_get_drag_data()
		if d is Dictionary and d.get("inv", false):
			data = d
			set_process(true)
	elif what == NOTIFICATION_DRAG_END and data != null:
		var d = data
		data = null
		set_process(false)
		_tag.visible = false
		var t = _under_mouse()
		if mark.is_valid():
			mark.call(null, false)
		_last = null
		if get_viewport().gui_is_drag_successful() or t == null:
			return
		var why: String = reason.call(t, d)
		if why == "":
			drop.call(t, d)
		elif tell.is_valid():
			tell.call(why)


func _under_mouse():
	if UiUtil.mouse_over_ui(get_viewport()) or not tower_at.is_valid():
		return null
	var t = tower_at.call()
	return t if t != null and is_instance_valid(t) else null


func _process(_delta: float) -> void:
	if data == null:
		return
	var t = _under_mouse()
	if t == null:
		_tag.visible = false
		if _last != null and mark.is_valid():
			mark.call(null, false)
		_last = null
		return
	var why: String = reason.call(t, data)
	var ok := why == ""
	if mark.is_valid():
		mark.call(t, ok)
	_last = t
	_label.text = (hint.call(t, data) if hint.is_valid() else "+") if ok else why
	var col := UiTheme.HAVE if ok else UiTheme.MISSING
	_label.add_theme_color_override("font_color", col)
	_tag.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.BG, 0.92), col, 0, 2, 5))
	_tag.reset_size()
	_tag.position = get_viewport().get_mouse_position() + Vector2(22, -34)
	_tag.visible = true
