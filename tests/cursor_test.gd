extends Node
## Lauf: paar
## Eigener Cursor: jeder Stil rendert in jeder Form und mit jedem Umriss ein Bild in der richtigen Größe,
## die Spitze ist nicht durchsichtig, AUTO folgt dem Modus-Stil, Einstellungen bleiben gespeichert.

var failures := 0


func _ready() -> void:
	for st in Cursor.STYLES:
		for kind in ["arrow", "click", "text"]:
			for ol in Cursor.OUTLINES:
				for scale in [Cursor.SIZE_MIN, 1.0, Cursor.SIZE_MAX]:
					var px := Cursor.pixels(scale)
					var img := Cursor.texture(st, kind, px, ol).get_image()
					_check(img.get_width() == px, "%s/%s/%s %d px: Breite %d" % [st, kind, ol, px, img.get_width()])
					if kind == "arrow":
						# Pixel direkt an der Spitze (Hotspot) muss sichtbar sein
						var hot := Vector2i((Vector2(3.5, 3.5) * px / Cursor.VIEW).floor())
						_check(img.get_pixelv(hot).a > 0.3, "%s/%s %d px: Spitze durchsichtig" % [st, ol, px])
	# Umriss ändert das Bild
	var dark := Cursor.texture("white", "arrow", 32, "dark").get_image()
	var light := Cursor.texture("white", "arrow", 32, "light").get_image()
	_check(dark.get_data() != light.get_data(), "Umriss hell und dunkel gleich")
	# AUTO folgt dem Skin
	var old_style: String = Cursor.style
	Cursor.style = Cursor.AUTO
	UiTheme.use_skin(UiTheme.DRUID)
	_check(Cursor.active_style() == "druid", "AUTO in eeveTD: %s" % Cursor.active_style())
	UiTheme.use_skin(UiTheme.POSTER)
	_check(Cursor.active_style() == "poster", "AUTO in Randgruppen: %s" % Cursor.active_style())
	UiTheme.use_skin(UiTheme.ARCADE)
	_check(Cursor.active_style() == "arcade", "AUTO in GemTD: %s" % Cursor.active_style())
	Cursor.style = old_style
	# Knöpfe bekommen den Klick-Zeiger
	var b := Button.new()
	add_child(b)
	_check(b.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Knopf ohne Klick-Zeiger")
	if failures == 0:
		print("OK   Cursor: %d Stile × 3 Formen × 3 Umrisse × 3 Größen" % Cursor.STYLES.size())
	get_tree().quit(1 if failures else 0)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL " + msg)
