extends SceneTree
## Baut die Stoff-Texturen für Helden und Gegner (assets/textures/bollwerk/<art>_detail.jpg und _normal.jpg):
## leder aus der eigenen Bollwerk-Ledertextur (assets/textures/ui/bollwerk_leather.png), stoff, fell, knochen
## und chitin prozedural (eigene Werke, keine Fremdassets). Detailkarten sind grau mit Mittel 0.82 wie bei
## tools/heroes/bollwerk_oberflaechen.gd; die Farbe kommt aus dem Modellmaterial.
## Aufruf: godot --headless --path . -s tools/heroes/bollwerk_stoffe.gd

const SIZE := 512
const MEAN := 0.82
const ZIEL := "res://assets/textures/bollwerk/"


func _init() -> void:
	_save("leder", _leder(), 1.6, 3.0)
	_save("stoff", _stoff(), 0.55, 2.5)
	_save("fell", _fell(), 1.2, 5.0)
	_save("knochen", _knochen(), 1.0, 3.0)
	_save("chitin", _chitin(), 1.1, 6.0)
	_save("metall", _metall(), 0.35, 3.0)
	quit()


## Metall: flache Hammerdellen, darüber feine Schleifspuren.
func _metall() -> PackedFloat32Array:
	var cn := _noise(FastNoiseLite.TYPE_CELLULAR, 0.03, 51, 1)
	cn.fractal_type = FastNoiseLite.FRACTAL_NONE
	cn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var dents := _field(cn, SIZE, SIZE)
	var brush := _field(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.15, 52, 2), SIZE, SIZE / 16)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in out.size():
		out[i] = 0.6 * sqrt(clampf(dents[i], 0.0, 1.0)) + 0.4 * brush[i]
	return out


## Höhenkarte h (0..1) -> Detailkarte (Mittel MEAN, Kontrast) und Normalenkarte (Stärke).
func _save(id: String, h: PackedFloat32Array, contrast: float, strength: float) -> void:
	var mean := 0.0
	for v in h:
		mean += v
	mean /= h.size()
	var detail := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var bump := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var v := h[y * SIZE + x]
			var d := clampf(MEAN + (v - mean) * contrast, 0.2, 1.0)
			detail.set_pixel(x, y, Color(d, d, d))
			bump.set_pixel(x, y, Color(v, v, v))
	bump.bump_map_to_normal_map(strength)
	bump.convert(Image.FORMAT_RGB8)
	detail.save_jpg(ProjectSettings.globalize_path(ZIEL + id + "_detail.jpg"), 0.9)
	bump.save_jpg(ProjectSettings.globalize_path(ZIEL + id + "_normal.jpg"), 0.92)
	print(id, " fertig")


func _noise(type: int, freq: float, seed: int, octaves := 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.seed = seed
	n.fractal_octaves = octaves
	return n


## Kachelbares Rauschen als Feld 0..1 in der Größe w x hh.
func _field(n: Noise, w: int, hh: int) -> PackedFloat32Array:
	var img := n.get_seamless_image(w, hh, false, false, 0.1, true)
	img.convert(Image.FORMAT_L8)
	if w != SIZE or hh != SIZE:
		img.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			out[y * SIZE + x] = img.get_pixel(x, y).r
	return out


func _leder() -> PackedFloat32Array:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/ui/bollwerk_leather.png"))
	img.convert(Image.FORMAT_RGB8)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	var lo := 1.0
	var hi := 0.0
	for y in SIZE:
		for x in SIZE:
			var v := img.get_pixel(x, y).get_luminance()
			out[y * SIZE + x] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	for i in out.size():
		out[i] = (out[i] - lo) / maxf(hi - lo, 0.001)
	return out


## Leinwandbindung: Kett- und Schussfäden im Wechsel, Fadenbreite 8 px, dazu leichtes Rauschen.
func _stoff() -> PackedFloat32Array:
	var grain := _field(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.03, 11), SIZE, SIZE)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	var p := 8.0
	for y in SIZE:
		for x in SIZE:
			var over := (int(x / p) + int(y / p)) % 2 == 0
			var t := sin(PI * fposmod(y if over else x, p) / p)
			out[y * SIZE + x] = 0.35 + 0.45 * t + 0.2 * grain[y * SIZE + x]
	return out


## Fell: feines Rauschen, senkrecht gestreckt zu Haarsträhnen.
func _fell() -> PackedFloat32Array:
	var a := _field(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.08, 21, 3), SIZE, SIZE / 8)
	var b := _field(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.02, 22, 2), SIZE, SIZE)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in out.size():
		out[i] = a[i] * 0.75 + b[i] * 0.25
	return out


## Knochen: weiche Wolken mit feinen Poren und wenigen Haarrissen.
func _knochen() -> PackedFloat32Array:
	var soft := _field(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 31), SIZE, SIZE)
	var pores := _field(_noise(FastNoiseLite.TYPE_VALUE, 0.25, 32, 1), SIZE, SIZE)
	var cn := _noise(FastNoiseLite.TYPE_CELLULAR, 0.012, 33, 1)
	cn.fractal_type = FastNoiseLite.FRACTAL_NONE
	cn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var cracks := _field(cn, SIZE, SIZE)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in out.size():
		var crack := 1.0 - smoothstep(0.0, 0.06, cracks[i])
		out[i] = 0.55 + 0.3 * soft[i] - 0.12 * pores[i] - 0.35 * crack
	return out


## Chitin: gewölbte Platten mit dunklen Fugen.
func _chitin() -> PackedFloat32Array:
	var cn := _noise(FastNoiseLite.TYPE_CELLULAR, 0.018, 41, 1)
	cn.fractal_type = FastNoiseLite.FRACTAL_NONE
	cn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var dome := _field(cn, SIZE, SIZE)
	var en := _noise(FastNoiseLite.TYPE_CELLULAR, 0.018, 41, 1)
	en.fractal_type = FastNoiseLite.FRACTAL_NONE
	en.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var edge := _field(en, SIZE, SIZE)
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	for i in out.size():
		out[i] = (1.0 - dome[i]) * 0.8 * smoothstep(0.0, 0.08, edge[i]) + 0.1
	return out
