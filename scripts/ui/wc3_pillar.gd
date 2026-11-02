class_name Wc3Pillar
extends MarginContainer
## Steinsäule rechts im Hauptmenü (Wc3Theme): Steintextur mit abgeschnittenen Ecken, doppelter Messingrahmen,
## Messing-Eckbeschläge mit Schrauben, oben ein blauer Kristall in Messingfassung. Die Knöpfe kommen in box.
## Ohne Kristall (with_gem false) auch als Steintafel der Einzelspieler-Seite.

const CUT := 30.0
const GEM := "res://assets/textures/menu/kristall_blau.png"

var box: VBoxContainer
## Kristall oben (Hub-Säule); die Tafeln der Einzelspieler-Seite haben keinen.
var gem := true
var _stone: Texture2D
var _gem: Texture2D


func _init(with_gem := true, width := 420.0) -> void:
	gem = with_gem
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_theme_constant_override("margin_left", 44 if gem else 36)
	add_theme_constant_override("margin_right", 44 if gem else 36)
	add_theme_constant_override("margin_top", 64 if gem else 40)
	add_theme_constant_override("margin_bottom", 54 if gem else 40)
	custom_minimum_size.x = width
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_stone = load(Wc3Theme.STONE)
	_gem = load(GEM)
	# Messing (Leisten, Beschläge) auf eigener Ebene mit Glanz; vor box, damit Knöpfe darüber liegen
	var brass := Wc3Theme.BrassLayer.new(_draw_brass)
	add_child(brass)
	move_child(brass, 0)
	resized.connect(queue_redraw)
	resized.connect(brass.queue_redraw)


## Knopf anhängen; parent = box oder eine Zeile aus row().
func button(text_de: String, main: bool, description: String, on_pressed: Callable, parent: Node = null) -> Wc3Button:
	var b := Wc3Button.new(text_de, main)
	b.description = description
	b.pressed.connect(on_pressed)
	if parent is HBoxContainer:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else box).add_child(b)
	return b


func row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	return h


func separator() -> void:
	box.add_child(Wc3Theme.Divider.new())


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var shape := Wc3Theme.cut_rect(r, CUT)
	Wc3Theme.fill_textured(self, shape, _stone, 256.0, Wc3Theme.PILLAR_SHADE)
	# Innenschatten zum Rand hin
	for i in 10:
		draw_polyline(Wc3Theme.closed(Wc3Theme.cut_rect(r.grow(-10 - i * 4), maxf(CUT - 4 - i * 2, 4))), Color(0, 0, 0, 0.13 - i * 0.012), 4.0, true)
	# Messing (Leisten, innerer Rand, Beschläge) auf der Glanz-Ebene (_draw_brass)


## Rahmen aus Messingband mit Wulst und verschweißten Ecken (3D-Renders, Wc3Theme.BrassLayer).
func _draw_brass(ci: CanvasItem) -> void:
	# Band mit Wulst und verschweißte Ecken; der innere Rand ist weg (Lukas 2026-11-02)
	Wc3Theme.panel_frame(ci, Rect2(Vector2.ZERO, size))
	if gem:
		_draw_gem(ci)


## Blauer Kristall oben in einer Messingfassung (Trapez), dahinter ein blaues Leuchten.
func _draw_gem(ci: CanvasItem) -> void:
	var cx := size.x / 2
	var mount := Rect2(cx - 37, 50, 74, 16)
	var trap := PackedVector2Array([Vector2(mount.position.x + 10, mount.position.y), Vector2(mount.end.x - 10, mount.position.y),
		mount.end, Vector2(mount.position.x, mount.end.y)])
	for i in 6:
		ci.draw_circle(Vector2(cx, 34), 30 - i * 4, Color(0.35, 0.67, 1.0, 0.05))
	var gh := 66.0
	var gw := gh * _gem.get_width() / _gem.get_height()
	var gr := Rect2(cx - gw / 2, mount.position.y + 6 - gh, gw, gh)
	ci.draw_texture_rect(_gem, Rect2(gr.position + Vector2(0, 3), gr.size), false, Color(0, 0, 0, 0.8))
	ci.draw_texture_rect(_gem, gr, false)
	# Fassung als 3D-Render (Trapez 74 × 16 im Bild 78 × 20), mit Schatten nach rechts unten
	var fr := Rect2(cx - 39, mount.position.y - 2, 78, 20)
	for o in Wc3Theme.SHADOW_STEPS:
		ci.draw_texture_rect(Wc3Theme.brass("fassung"), Rect2(fr.position + o, fr.size), false, Wc3Theme.SHADOW)
	ci.draw_texture_rect(Wc3Theme.brass("fassung"), fr, false)
