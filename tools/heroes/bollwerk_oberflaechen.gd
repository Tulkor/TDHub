extends SceneTree
## Baut die Bollwerk-Oberflächen (assets/textures/bollwerk) aus dem CC0-Paket
## "Medieval Village MegaKit [Standard]" von Quaternius.
## Aufruf: godot --headless -s tools/heroes/bollwerk_oberflaechen.gd -- <textures_dir> <normals_gl_dir> <ziel>
##   textures_dir   = entpackter Ordner "Textures" des Pakets (T_*_BaseColor.png, *_Roughness.png, *_ORM.png)
##   normals_gl_dir = entpackter Ordner "Textures/Normals Godot-Unity" (OpenGL-Normalen)
## Albedo wird zu einer Graustufen-Detailkarte mit Mittelwert DETAIL_MEAN: Die Spielfarbe aus dem Code
## färbt die Fläche, die Textur liefert nur Fugen, Maserung und Flecken.

const SIZE := 1024
const DETAIL_MEAN := 0.82
const SETS := {
	# ziel: [quelle, Ausschnitt in 0..1 (x, y, w, h), Kontrast, Rauheit aus "R" (Roughness) oder "ORM"]
	"mauer": ["Brick", Rect2(0, 0, 1, 1), 1.5, "R"],
	"bruchstein": ["UnevenBrick", Rect2(0, 0, 1, 1), 1.4, "R"],
	"putz": ["Plaster", Rect2(0, 0, 1, 1), 1.3, "ORM"],
	# WoodTrim ist ein Trim-Sheet: nur die beiden Bretterbahnen oben (0..60 %) kacheln sauber.
	"holz": ["WoodTrim", Rect2(0, 0, 1, 0.6015625), 1.6, "R"],
}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("Aufruf: -- <textures_dir> <normals_gl_dir> <ziel>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(a[2])
	for id in SETS:
		var s: Array = SETS[id]
		var src: String = s[0]
		var crop: Rect2 = s[1]
		var albedo := _load(a[0] + "/T_%s_BaseColor.png" % src, crop)
		_detail(albedo, float(s[2])).save_jpg(a[2] + "/%s_detail.jpg" % id, 0.9)
		_load(a[1] + "/T_%s_Normal.png" % src, crop).save_jpg(a[2] + "/%s_normal.jpg" % id, 0.92)
		var rough: Image
		if s[3] == "ORM":
			rough = _channel(_load(a[0] + "/T_%s_ORM.png" % src, crop), 1)
		else:
			rough = _channel(_load(a[0] + "/T_%s_Roughness.png" % src, crop), 0)
		rough.save_jpg(a[2] + "/%s_rough.jpg" % id, 0.9)
		print(id, " fertig")
	quit()


func _load(path: String, crop: Rect2) -> Image:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	var r := Rect2i(int(crop.position.x * w), int(crop.position.y * h), int(crop.size.x * w), int(crop.size.y * h))
	if r.size != Vector2i(w, h):
		img = img.get_region(r)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return img


func _channel(img: Image, c: int) -> Image:
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var v: float = img.get_pixel(x, y)[c]
			out.set_pixel(x, y, Color(v, v, v))
	return out


func _detail(img: Image, contrast: float) -> Image:
	var sum := 0.0
	for y in SIZE:
		for x in SIZE:
			sum += img.get_pixel(x, y).get_luminance()
	var mean := sum / float(SIZE * SIZE)
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var v := clampf(DETAIL_MEAN + (img.get_pixel(x, y).get_luminance() - mean) * contrast, 0.2, 1.0)
			out.set_pixel(x, y, Color(v, v, v))
	return out
