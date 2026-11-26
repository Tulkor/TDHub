class_name InvSlot
extends Control
## Ein Inventarfeld wie in Warcraft III, für alle Modi mit Items (Farben aus UiTheme, also im Stil des Modus).
## Zustände: ITEM (belegt), FREE (nutzbarer freier Platz, dunkel eingelassen), LOCKED (Platz, den der Tower nicht hat,
## ausgegraut und schraffiert). Belegte Felder lassen sich ziehen (drag_data), auf jedes Feld außer LOCKED kann man
## Gezogenes legen (on_drop); liegt dort schon ein Item, tauscht der Modus die beiden.
## Verbrauchs-Items (Öle, Tränke) tragen oben rechts einen Tropfen.
## Gezogene Daten sind ein Dictionary mit "inv": true und dem Ort des Items; was ein Ort ist, legt der Modus fest.

signal clicked(button: int)

enum State { FREE, ITEM, LOCKED }

var state := State.FREE
var texture: Texture2D           ## Bild des Items (oder icon_node für gezeichnete Symbole)
var icon_node: Control           ## eigenes Symbol statt Bild (eeveTD: ItemIcon)
var abbr := ""                   ## Kürzel statt Bild (Items ohne Icon, z. B. Shopping Maul)
var border := Color.TRANSPARENT  ## Rahmen in Seltenheitsfarbe, transparent = Standard
var consumable := false
var count := ""                  ## Zahl unten rechts (Ladungen)
var marked := false              ## ausgewählt
var dimmed := false              ## gerade nicht nutzbar (z. B. für Rezepte gesperrt)
var drag_data = null             ## Daten beim Ziehen (null = nicht ziehbar)
var on_drop := Callable()        ## func(data) -> void
var accepts := Callable()        ## func(data) -> bool; leer = alles mit "inv"
var _hover := false
var _drop_hover := false


func _init(side := 44.0) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; _drop_hover = false; queue_redraw())


## Belegtes Feld mit Bild.
func show_item(tex: Texture2D, edge := Color.TRANSPARENT, is_consumable := false) -> InvSlot:
	state = State.ITEM
	texture = tex
	border = edge
	consumable = is_consumable
	queue_redraw()
	return self


## Belegtes Feld mit gezeichnetem Symbol (Größe = Feld minus 3 px Rand ringsum).
func show_node(node: Control, is_consumable := false) -> InvSlot:
	state = State.ITEM
	consumable = is_consumable
	icon_node = node
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = Vector2(3, 3)
	add_child(node)
	queue_redraw()
	return self


## Belegtes Feld ohne Bild: Kürzel des Namens (z. B. „WS“ für Werbesendung) in der Randfarbe.
func show_abbr(item_name: String, edge := Color.TRANSPARENT) -> InvSlot:
	state = State.ITEM
	border = edge
	var words := item_name.split(" ", false)
	abbr = (words[0].left(1) + words[1].left(1)) if words.size() > 1 else item_name.left(2)
	queue_redraw()
	return self


func set_locked() -> InvSlot:
	state = State.LOCKED
	queue_redraw()
	return self


func set_count(text: String) -> InvSlot:
	count = text
	queue_redraw()
	return self


func set_marked(on: bool, dim := false) -> InvSlot:
	marked = on
	dimmed = dim
	queue_redraw()
	return self


func _draw() -> void:
	if UiTheme.bollwerk():
		# Eisenliturgie: Achteck mit Edelstein-Fassungen, Rand und Steine aus der Bollwerk-Metalllage.
		HdUiStyle.draw_slot(self)
		return
	var r := Rect2(Vector2.ZERO, size)
	match state:
		State.LOCKED:
			# ausgegraut: heller grauer Stein mit Schraffur, kein Rahmen in Modusfarbe
			var grey := Color(UiTheme.MUTED.v, UiTheme.MUTED.v, UiTheme.MUTED.v)
			draw_rect(r, Color(grey, 0.32))
			var step := 7.0
			var x := -size.y
			while x < size.x:
				var a := Vector2(maxf(x, 0.0), maxf(-x, 0.0))
				var b := Vector2(minf(x + size.y, size.x), minf(size.x - x, size.y))
				draw_line(a, b, Color(grey, 0.25), 1.5)
				x += step
			draw_rect(r.grow(-0.5), Color(grey, 0.45), false, 1.0)
			return
		State.FREE:
			# nutzbar: dunkler als alles drumherum, oben innen ein Schatten wie eingelassen
			draw_rect(r, UiTheme.BG.darkened(0.55))
			draw_rect(Rect2(0, 0, size.x, 4), Color(0, 0, 0, 0.45))
			draw_rect(Rect2(0, 0, 3, size.y), Color(0, 0, 0, 0.3))
		State.ITEM:
			draw_rect(r, UiTheme.CYAN if marked else UiTheme.BG.darkened(0.3))
			if texture != null:
				var m := 3.0
				draw_texture_rect(texture, Rect2(m, m, size.x - 2 * m, size.y - 2 * m), false, Color(1, 1, 1, 0.45 if dimmed else 1.0))
			elif abbr != "":
				var f := UiTheme.font(true)
				var fs := int(size.y * 0.38)
				var w := f.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2((size.x - w) / 2.0, size.y / 2.0 + fs * 0.36), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
						UiTheme.BG if marked else (border if border.a > 0.0 else UiTheme.TEXT))
	var edge := border if border.a > 0.0 else Color(UiTheme.BORDER, 0.7)
	if _drop_hover:
		edge = UiTheme.CYAN
	elif _hover and state == State.ITEM and not marked:
		edge = edge.lightened(0.35)
	draw_rect(r.grow(-1.0), edge, false, 3.0 if _drop_hover else 2.0)
	if state != State.ITEM:
		return
	if consumable:
		# Tropfen oben rechts: wird beim Anwenden verbraucht
		var c := Vector2(size.x - 8.0, 9.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 1), c + Vector2(0, 5), c + Vector2(-4, 1)]), UiTheme.HAVE)
		draw_circle(c + Vector2(0, 1.5), 3.6, UiTheme.HAVE)
	if count != "":
		var f := UiTheme.font(true)
		var fs := 12
		var w := f.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(size.x - w - 4.0, size.y - 4.0)
		draw_string_outline(f, p, count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
		draw_string(f, p, count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		clicked.emit(ev.button_index)
		accept_event()


## Lange Texte umbrechen statt den Tooltip über den Bildschirm zu ziehen.
func _make_custom_tooltip(for_text: String) -> Object:
	var l := Label.new()
	l.text = for_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420.0 if for_text.length() > 60 else 0.0
	l.add_theme_font_size_override("font_size", 14)
	return l


func _get_drag_data(_at: Vector2) -> Variant:
	if drag_data == null or state != State.ITEM:
		return null
	var c := Control.new()
	if texture != null:
		var p := TextureRect.new()
		p.texture = texture
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.size = size
		p.position = -size * 0.5
		c.add_child(p)
	elif icon_node != null:
		var d: Control = icon_node.duplicate()
		d.size = size
		d.position = -size * 0.5
		c.add_child(d)
	set_drag_preview(c)
	return drag_data


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = state != State.LOCKED and on_drop.is_valid() and data is Dictionary and data.get("inv", false) and data != drag_data
	if ok and accepts.is_valid():
		ok = bool(accepts.call(data))
	if ok != _drop_hover:
		_drop_hover = ok
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	_drop_hover = false
	queue_redraw()
	on_drop.call(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_hover:
		_drop_hover = false
		queue_redraw()
