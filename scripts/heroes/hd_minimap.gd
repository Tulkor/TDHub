extends Control
## Kleine taktische Karte. Geheimwege erscheinen erst nach ihrer Entdeckung.
var game
var _elapsed := 0.0
var _bounds := Rect2(-192,-192,384,384)
var terrain_texture: Texture2D
var _terrain_key := ""
var _frame: StyleBox
var _metal_frame: Wc3Theme.BrassLayer
var zoom := 1.0
var _map_bounds := Rect2(-192,-192,384,384)
var _view_center := Vector2.ZERO
var _area_key := ""
var _dragging := false
var _zoom_in: Button
var _zoom_out: Button
const Terrain = preload("res://scripts/heroes/hd_minimap_terrain.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	_frame = UiTheme.panel(3)
	_metal_frame = Wc3Theme.BrassLayer.new(_draw_metal_frame)
	_metal_frame.name="MetalFrame"
	_metal_frame.material=HdUiStyle.metal_material()
	_metal_frame.modulate=HdUiStyle.GOLD
	add_child(_metal_frame)
	resized.connect(_metal_frame.queue_redraw)
	_zoom_out = _zoom_button("−","ZoomOut",func():set_zoom(zoom/1.25))
	_zoom_in = _zoom_button("+","ZoomIn",func():set_zoom(zoom*1.25))
	resized.connect(_fit_buttons)
	_fit_buttons()

func _draw_metal_frame(canvas: CanvasItem) -> void:
	Wc3Theme.frame(canvas,Rect2(Vector2.ZERO,size),8.0,6.0)
	for at in [Vector2(6,6),Vector2(size.x-6,6),Vector2(6,size.y-6),size-Vector2(6,6)]:
		Wc3Theme.screw(canvas,at,.3,10.0)

func _zoom_button(label: String, id: String, action: Callable) -> Button:
	var button := Button.new()
	button.name=id
	button.text=label
	button.set_meta("own_metal_frame",true)
	button.add_theme_font_size_override("font_size",13)
	button.add_theme_color_override("font_color",UiTheme.GOLD)
	for state in ["normal","hover","pressed","disabled"]:button.add_theme_stylebox_override(state,HdUiStyle.menu_button_style(state,1))
	button.add_theme_stylebox_override("focus",UiTheme.box(Color.TRANSPARENT,UiTheme.GOLD,0,1,1))
	button.pressed.connect(action)
	add_child(button)
	var metal := Wc3Theme.BrassLayer.new(func(canvas: CanvasItem):button.get_theme_stylebox("normal").draw_metal(canvas.get_canvas_item(),Rect2(Vector2.ZERO,button.size)))
	metal.material=HdUiStyle.metal_material()
	button.add_child(metal)
	button.resized.connect(metal.queue_redraw)
	return button

func _fit_buttons() -> void:
	if not is_instance_valid(_zoom_in):return
	_zoom_out.position=Vector2(size.x*.5-26,size.y-24)
	_zoom_in.position=Vector2(size.x*.5+2,size.y-24)
	_zoom_in.size=Vector2(24,24)
	_zoom_out.size=Vector2(24,24)
	_zoom_in.disabled=zoom>=4.0
	_zoom_out.disabled=zoom<=1.0

func _map_rect() -> Rect2:
	return Rect2(Vector2(8,8),(size-Vector2(16,16)).max(Vector2.ONE))

func _set_area(area: Rect2, domain: String) -> void:
	var key := str([area,domain])
	if key!=_area_key:
		_area_key=key
		_map_bounds=area
		_view_center=area.get_center()
		zoom=1.0
		_fit_buttons()
	_fit_view()

func _fit_view() -> void:
	var half := _map_bounds.size/(zoom*2)
	_view_center=_view_center.clamp(_map_bounds.position+half,_map_bounds.end-half)
	_bounds=Rect2(_view_center-half,half*2)

func set_zoom(value: float, anchor := Vector2(-1,-1)) -> void:
	var uv := Vector2(.5,.5)
	if anchor!=Vector2(-1,-1):uv=((anchor-_map_rect().position)/_map_rect().size).clamp(Vector2.ZERO,Vector2.ONE)
	var world_anchor := _bounds.position+uv*_bounds.size
	zoom=clampf(value,1.0,4.0)
	_view_center=world_anchor+(Vector2(.5,.5)-uv)*(_map_bounds.size/zoom)
	_fit_view()
	_fit_buttons()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			set_zoom(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8),event.position)
			accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			_dragging=event.pressed and zoom>1 and _map_rect().has_point(event.position)
	elif event is InputEventMouseMotion and _dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging=false
			return
		_view_center-=event.relative/_map_rect().size*_bounds.size
		_fit_view()
		queue_redraw()
		accept_event()

func _process(dt: float) -> void:
	_elapsed += dt
	if _elapsed < .1 or not is_visible_in_tree():return
	_elapsed = 0
	queue_redraw()

func _point(p: Vector3) -> Vector2:
	return _map_rect().position+(Vector2(p.x,p.z)-_bounds.position)/_bounds.size*_map_rect().size

func _line(points: Array, color: Color, width: float) -> void:
	var line := PackedVector2Array()
	for p: Vector3 in points:line.append(_point(p))
	var rect := _map_rect()
	for i in line.size()-1:
		var a := line[i]
		var delta := line[i+1]-a
		var first := 0.0
		var last := 1.0
		for axis in 2:
			if absf(delta[axis])<.00001:
				if a[axis]<rect.position[axis] or a[axis]>rect.end[axis]:last=-1
			else:
				var near := (rect.position[axis]-a[axis])/delta[axis]
				var far := (rect.end[axis]-a[axis])/delta[axis]
				first=maxf(first,minf(near,far))
				last=minf(last,maxf(near,far))
		if first<=last:draw_line(a+delta*first,a+delta*last,color,width,true)

func _draw() -> void:
	if game == null or not is_instance_valid(game.hero):return
	draw_style_box(_frame,Rect2(Vector2.ZERO,size))
	var cave := HdExplorationLayout.cave_at(game.hero.position)
	if not cave.is_empty():
		var center: Vector3 = cave.center
		_set_area(Rect2(Vector2(center.x-20,center.z-20),Vector2(40,40)),"cave")
		_terrain("cave")
	elif game.final.active:
		var center: Vector3 = game.final.center
		var b: Array = game.final.bounds()
		_set_area(Rect2(float(b[0]),float(b[1]),float(b[2])-float(b[0]),float(b[3])-float(b[1])),"final")
		_terrain("final")
		for segment in game.final.layout.floor_segments():
			_line([segment.from+center,segment.to+center],Color("696653"),3.0)
		for room in game.final.layout.rooms():
			var outline: Array = []
			for i in 33:outline.append(room.pos+center+Vector3(cos(TAU*i/32.0),0,sin(TAU*i/32.0))*float(room.radius))
			_line(outline,Color("a4a18d"),1)
	elif game.event_arena and game.event_arena.active:
		var b: Array = game.event_arena.bounds()
		_set_area(Rect2(float(b[0]),float(b[1]),float(b[2])-float(b[0]),float(b[3])-float(b[1])),"arena")
		_terrain("arena")
	else:
		var b: Array = game.cfg.arena.bounds
		_set_area(Rect2(float(b[0]),float(b[1]),float(b[2])-float(b[0]),float(b[3])-float(b[1])),"main")
		_terrain("main")
		for road in game.roads:
			_line(Array(road.points),Color("454a45"),4.0)
			_line(Array(road.points),Color("c2b89b"),2.2)
		for site in game.exploration.sites:
			if game.exploration.points.get(site.id,{}).get("discovered",false):
				_line(site.path,Color("8d947b"),1.5)
				if _bounds.has_point(Vector2(site.pos.x,site.pos.z)):draw_circle(_point(site.pos),2.5,UiTheme.GOLD)
	for marker in map_markers():
		if not _bounds.has_point(Vector2(marker.pos.x,marker.pos.z)):continue
		var at := _point(marker.pos)
		match marker.kind:
			"building", "ruin":
				var color := Color("9f9790") if marker.kind=="ruin" else Color("e4be72")
				draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("18242c"))
				draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),color)
				if building_health_visible(marker):
					var start := (at+Vector2(-7,-9)).clamp(_map_rect().position,_map_rect().end-Vector2(14,4))
					draw_rect(Rect2(start,Vector2(14,4)),Color("101b21"))
					var hp: float = marker.health
					var bar_color := Color("73cf97") if hp>.5 else (Color("edc26b") if hp>.25 else Color("ec6a60"))
					draw_rect(Rect2(start+Vector2.ONE,Vector2(12*hp,2)),bar_color)
			"boss":
				var diamond := PackedVector2Array([at+Vector2(0,-4),at+Vector2(4,0),at+Vector2(0,4),at+Vector2(-4,0)])
				draw_circle(at,5,Color("25121c"))
				draw_colored_polygon(diamond,Color("ff654e"))
			"enemy":
				draw_circle(at,2.8,Color("32171d"))
				draw_circle(at,1.8,Color("ff7164"))
			"friend", "self":
				var own: bool = marker.kind=="self"
				draw_circle(at,4 if own else 3.5,Color("142c31"))
				draw_circle(at,3 if own else 2.5,Color("ffe6a0") if own else Color("64e6d4"))


## Dieselben Zustände wie beim Kampf: verborgen, eingefroren oder unverwundbar ist nicht bekämpfbar.
func enemy_available(enemy: HdEnemy) -> bool:
	return is_instance_valid(enemy) and not enemy.dead and enemy.is_visible_in_tree() and not enemy.immortal and not game.event_arena.frozen(enemy)


func map_markers() -> Array:
	var markers: Array = []
	# Statische Nutzgebäude sind keine Gegner: eine verschlossene Arena verrät keinen Boss.
	if not game.final.active and not game.event_arena.active and HdExplorationLayout.cave_at(game.hero.position).is_empty():
		markers.append({"pos":game.fortress_pos,"kind":"building","health":clampf(float(game.lives)/maxf(1,game.max_lives),0,1)})
		for zone in game.zones.list:markers.append({"pos":game.zones.center(str(zone.id)),"kind":"building"})
	for building in game.buildings:
		if not is_instance_valid(building) or not building.is_visible_in_tree() or game.event_arena.frozen(building):continue
		var mobile: bool = building is HdAlly or (building is HdRosterConstruct and str(building.def.get("pet","")) in ["wolf","mirror","skeleton"])
		if mobile:continue
		markers.append({"pos":building.position,"kind":"ruin" if building.destroyed else "building","health":0.0 if building.destroyed else clampf(building.hp/maxf(1,building.max_hp),0,1)})
	for enemy: HdEnemy in game.enemies:
		if enemy_available(enemy):markers.append({"pos":enemy.position,"kind":"boss" if enemy.rank=="boss" else "enemy"})
	for actor: HdHero in game.playing_heroes():
		if is_instance_valid(actor) and actor.alive() and actor.is_visible_in_tree() and not bool(actor.get_meta("offline",false)):
			markers.append({"pos":actor.position,"kind":"self" if actor==game.hero else "friend"})
	return markers

func building_health_visible(marker: Dictionary) -> bool:
	return zoom>=1.5 and marker.kind in ["building","ruin"] and marker.has("health")

func _terrain(domain: String) -> void:
	var revealed: Array = []
	for id in game.exploration.points:
		if game.exploration.points[id].get("discovered",false):revealed.append(str(id))
	revealed.sort()
	var key := str([domain,_map_bounds,game.arena_layout.geometry_signature,Display.quality,revealed])
	if key!=_terrain_key:
		terrain_texture=Terrain.build(game,_map_bounds,domain,revealed)
		_terrain_key=key
	var pixels := Vector2(terrain_texture.get_size())
	var region := Rect2((_bounds.position-_map_bounds.position)/_map_bounds.size*pixels,_bounds.size/_map_bounds.size*pixels)
	draw_texture_rect_region(terrain_texture,_map_rect(),region)
