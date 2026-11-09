class_name MaulBoard
extends Board3D
## Spielfeld von Shopping Maul: wie Board3D, aber mit eigenen Markierungen (Spawns, Teleports,
## Mall, Leak-Fläche), den 11 Spielergebieten und der Blockstadt (MaulCity) rundherum.
## Das eigene Gebiet leuchtet, die anderen sind blass. Der Boden jedes Gebiets mit Spieler hat einen
## leichten Stich in dessen Farbe (PLAYER_COLORS, Spieler i besitzt Gebiet i).

const COL_LEAK := Color("ff5d7a")
const COL_TELEPORT := Color("b38cff")
## Stärke des Farbstichs im Gebiet (0..1), im eigenen etwas kräftiger.
## Spielerfarbe am Boden nur angedeutet, die Gebietsrahmen zeigen sie deutlich (Lukas, 2026-10-28)
const TINT := 0.06
const TINT_OWN := 0.09

var own_zone := 0
## So viele Spieler spielen mit (Gebiete 0 bis players - 1 haben einen Besitzer).
var players := 1
var city: MaulCity


func _rebuild_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()
	var mm: MaulMap = map as MaulMap
	if mm == null:
		return
	var spawn_cells := {}
	for s in mm.maul.get("spawns", []):
		var c := MaulMap.cell(s.cell)
		_add_marker(c, "S", style.marker)
		spawn_cells[c] = true
	# Teleport-Ziele: erster Wegpunkt jedes weiteren Abschnitts
	var done := {}
	for r in mm.maul.get("routes", {}).values():
		var all_legs: Array = []
		for i in range(1, r.get("legs", []).size()):
			all_legs.append(r.legs[i])
		for ch in r.get("choices", []):
			all_legs.append_array(ch.get("legs", []))
		for leg in all_legs:
			var c := MaulMap.cell(leg[0])
			if not done.has(c):
				done[c] = true
				_add_marker(c, "", style.get("zone_other", COL_TELEPORT))
	var mall: Array = mm.maul.get("mall", [])
	if mall.size() == 2:
		_add_marker(MaulMap.cell(mall), "MALL", style.get("zone_leak", COL_LEAK))
	var leak: Array = mm.maul.get("leak", [])
	if leak.size() == 4:
		_add_zone(Rect2i(int(leak[0]), int(leak[1]), int(leak[2]), int(leak[3])), style.get("zone_leak", COL_LEAK))
	# Rahmen in der Farbe des Spielers, dem das Gebiet gehört; das eigene breiter und heller
	for i in map.zones.size():
		if i < players:
			var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
			_add_zone(map.zones[i].rect, col, 0.22 if i == own_zone else 0.15, 3.2 if i == own_zone else 2.4)
		else:
			_add_zone(map.zones[i].rect, style.get("zone_other", Color(0.45, 0.4, 0.6)))



## Wie Board3D, dazu die Blockstadt auf allem, was Gegner nie erreichen (vor dem Boden, der
## unter der Stadt ohne Gitter gezeichnet wird).
func rebuild() -> void:
	var mm: MaulMap = map as MaulMap
	if mm != null and _ground != null:
		if city == null:
			city = MaulCity.new()
			add_child(city)
		city.build(mm)
	super()
	if mm != null and _floor_mat != null:
		_floor_mat.set_shader_parameter("grid_origin", _grid_center(mm))
		_floor_mat.set_shader_parameter("tint", _tint_texture(mm))
		_floor_mat.set_shader_parameter("tint_floor", 1.0)
		_floor_mat.set_shader_parameter("tint_lines", 0.0)
		_floor_mat.set_shader_parameter("paving", _paving_texture(mm))



func _floor_plain(c: Vector2i) -> bool:
	return city != null and city.is_city(c)


## Die dicken Bodenlinien laufen durch die Mitte der Karte (Mittel der äußeren Spielergebiete), damit
## das Raster links/rechts und oben/unten gleich an den Gebieten endet.
func _grid_center(mm: MaulMap) -> Vector2:
	var sum := Vector2.ZERO
	for i in range(1, mm.zones.size()):
		sum += Vector2(mm.zones[i].rect.position) + Vector2(mm.zones[i].rect.size) / 2.0
	return (sum / maxf(mm.zones.size() - 1, 1)).round()


## Farbstich je Feld: Farbe des Spielers, dem das Gebiet gehört, A = Stärke.
func _tint_texture(mm: MaulMap) -> ImageTexture:
	var img := Image.create(mm.width, mm.height, false, Image.FORMAT_RGBA8)
	for i in mini(players, mm.zones.size()):
		var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		col.a = TINT_OWN if i == own_zone else TINT
		var r: Rect2i = mm.zones[i].rect.intersection(Rect2i(0, 0, mm.width, mm.height))
		img.fill_rect(r, col)
	return ImageTexture.create_from_image(img)


## Bodenbelag je Feld: R = Gang außerhalb der Spielergebiete und der Stadt (Petrol statt Kalkstein).
func _paving_texture(mm: MaulMap) -> ImageTexture:
	var img := Image.create(mm.width, mm.height, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0))
	for z in mm.zones:
		img.fill_rect(z.rect.intersection(Rect2i(0, 0, mm.width, mm.height)), Color.BLACK)
	for y in mm.height:
		for x in mm.width:
			if _floor_plain(Vector2i(x, y)):
				img.set_pixel(x, y, Color.BLACK)
	return ImageTexture.create_from_image(img)
