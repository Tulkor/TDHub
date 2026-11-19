class_name HdCathedral
extends RefCounted
## Schwarze Kathedrale: eigenständige Basaltgotik für Bollwerk.
## Rein optisch, ohne CollisionObject. Freie Lane-/Zonenflächen bleiben aus derselben
## HdArena-Kontur ausgespart; Meshes werden nach Material und Form gebatcht.

static var _materials: Dictionary = {}
var _groups: Dictionary = {}
var _root: Node3D
var _game
var _sites: Array[Vector3] = []
var _street_sites: Array = []
var _lights: Array[OmniLight3D] = []
var _rng := RandomNumberGenerator.new()


static func build(game, parent: Node3D) -> Node3D:
	var builder := HdCathedral.new()
	return builder._build(game, parent)


static func floor_material() -> Material:
	return HdTerrain.material("rock")


static func path_material(_on := true) -> Material:
	return _stone("path", Color("787a7d"), false)


static func wall_material() -> Material:
	return _stone("wall", Color("343b47"), true)


static func roof_material() -> ShaderMaterial:
	if not _materials.has("slate_roof"):
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/hd_gothic_slate.gdshader")
		material.set_shader_parameter("slate_color",Color("202b3c"))
		_materials["slate_roof"]=material
	return _materials["slate_roof"]


static func _stone(id: String, color: Color, masonry: bool) -> ShaderMaterial:
	if _materials.has(id):
		return _materials[id]
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://assets/shaders/terrain_relief.gdshaderinc"
uniform vec4 stone_color : source_color;
uniform bool masonry = false;
uniform bool paving = false;
varying vec3 world_position;
varying vec3 world_normal;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 n=abs(normalize(world_normal));
 vec2 uv=n.y>0.65?world_position.xz:(n.x>0.55?world_position.zy:world_position.xy);
 vec2 tile=uv*(masonry?vec2(0.37,1.15):vec2(0.55,0.55));
 if(paving){tile=uv*vec2(1.8,2.7);}
 if(masonry||paving){tile.x+=mod(floor(tile.y),2.0)*0.5;}
 vec2 cell=floor(tile);vec2 f=fract(tile);
 float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
 float grout=1.0-smoothstep(0.012,0.035,edge);
 float variation=0.84+hash2(cell)*0.27;
 float grain=terrain_grain(world_position*2.0)*0.018;
 float old_seam=step(0.92,hash2(cell+19.0))*(1.0-smoothstep(0.005,0.018,abs(f.x-f.y*0.65-0.17)));
 // Flache, nichtleuchtende Spitzbogennischen gliedern die langen Korridorwände.
 float niche=0.0;
 if(masonry&&n.y<0.4){
  float nx=abs(fract(uv.x/4.8+0.5)-0.5)*4.8;
  float ny=uv.y-0.42;
  float pointed_top=2.15-0.70*pow(clamp(nx/0.7,0.0,1.0),1.6);
  niche=(1.0-smoothstep(0.62,0.70,nx))*smoothstep(0.0,0.07,ny)*(1.0-smoothstep(pointed_top-0.06,pointed_top,ny));
 }
 float damp=smoothstep(0.43,0.72,terrain_grain(world_position*0.23+vec3(6.0,0.0,2.0)));
 float foot_stain=masonry?(1.0-smoothstep(0.0,3.0,max(world_position.y,0.0))):1.0;
 vec3 base=stone_color.rgb*(variation+grain)*(1.0-damp*foot_stain*0.22);
 ALBEDO=mix(base,base*0.48,max(max(grout*0.72,old_seam*0.7),niche*0.7));
 float pore=terrain_grain(world_position*5.0);
 float height=(1.0-grout)*0.025-old_seam*0.012+pore*0.004-niche*0.028;
 NORMAL=terrain_relief_normal(NORMAL,VERTEX,height,0.6);
 ROUGHNESS=mix(mix(0.84,0.64,damp*foot_stain),0.96,max(grout,pore*0.35));
 SPECULAR=mix(0.30+damp*foot_stain*0.08,0.17,max(grout,old_seam));METALLIC=0.0;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("stone_color", color)
	material.set_shader_parameter("masonry", masonry)
	material.set_shader_parameter("paving", id.begins_with("path"))
	_materials[id] = material
	return material


static func _solid(id: String, color: Color, glow := 0.0, metallic := 0.0) -> StandardMaterial3D:
	if _materials.has(id):
		return _materials[id]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.78 if metallic == 0.0 else 0.46
	m.metallic = metallic
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	if metallic > 0.0:
		Metall.veredeln(m)
	_materials[id] = m
	return m


func _build(game, parent: Node3D) -> Node3D:
	_game = game
	_rng.seed = 948723
	_root = Node3D.new()
	_root.name = "SchwarzeKathedrale"
	parent.add_child(_root)
	# Zentralbau hält den bisherigen Feste-Fußabdruck (Radius 5) ein.
	HdTerrain.fortress_plaza(game,_root,path_material())
	_chapel(game.fortress_pos, 0.0, 0.34, true, true)
	var landmark := _find_site(Vector3(-33, 0, -33), 17.0)
	if landmark != Vector3.INF:
		_chapel(landmark, deg_to_rad(12), 1.25, true)
		_sites.append(landmark)
	var ossuary := _find_site(Vector3(33, 0, 33), 10.0)
	if ossuary != Vector3.INF:
		_chapel(ossuary, deg_to_rad(-105), 0.65, false)
		_sites.append(ossuary)
	var hamlets: Array = []
	var plazas: Array=[]
	for site in HdArenaMountains.settlements(game.arena_layout):
		var at: Vector3=site.pos
		if site.get("plaza",false):
			plazas.append(site)
			continue
		# Häuser einer Zeile stehen eng wie in einer gewachsenen Altstadt (Lukas 2026-11-19).
		if not _separated(at,7.0):continue
		var depth: float=site.foundation
		_place("box",wall_material(),Vector3(6.6,depth,7.6),at-Vector3.UP*(depth*.5),float(site.yaw))
		if bool(site.ruin):
			_ruin(at,float(site.yaw)+PI)
			for side in [-1.0,1.0]:
				_part("box",wall_material(),Vector3(.65,1.8,4.5),at,Vector3(side*2.8,.65,.2),1,float(site.yaw))
		else:
			_townhouse(site)
		_sites.append(at)
		hamlets.append(site)
	_root.set_meta("settlement_sites",hamlets)
	for plaza in plazas:
		_plaza_monument(plaza)
	_root.set_meta("settlement_plazas",plazas)
	# Schlanke Türme und Kerzennischen begleiten die Wände, niemals die Spielfläche.
	for road in game.arena_layout.paths:
		var count := maxi(2, floori(road.length / 31.0))
		for i in count:
			var s: float = 18.0 + float(i) * 30.0
			if s > road.length - 18.0:
				continue
			var p: Vector3 = road.point(s)
			var tangent: Vector3 = (road.point(minf(s + 0.4, road.length)) - road.point(maxf(s - 0.4, 0.0))).normalized()
			var normal := Vector3(-tangent.z, 0, tangent.x)
			for side in [-1.0, 1.0]:
				var site: Vector3 = p + normal * side * (game.arena_layout.width + 3.4)
				if _available(site, 2.0) and _separated(site, 8.0):
					_tower(site, 0.34 + _rng.randf() * 0.12, _rng.randf() * TAU)
					_sites.append(site)
		# Ein warmer Lesepunkt je Lane-Paar nahe dem inneren Abschnitt.
		var s: float = maxf(road.length - 34.0, 8.0)
		var p: Vector3 = road.point(s)
		var tangent: Vector3 = (road.point(minf(s + 0.5, road.length)) - road.point(maxf(s - 0.5, 0.0))).normalized()
		var normal := Vector3(-tangent.z, 0, tangent.x)
		var site: Vector3 = p + normal * (game.arena_layout.width + 2.2)
		if _available(site, 0.8) and _separated(site, 3.5):
			_candles(site, 1.25, true)
			_sites.append(site)
	_lane_reliquaries()
	_flush()
	if game.day_cycle:
		var lights := _lights.duplicate()
		var update := func(night: bool):
			for light in lights:
				if is_instance_valid(light):
					light.visible = night
		game.day_cycle.period_changed.connect(update)
		update.call(game.is_night())
	_root.set_meta("cathedral_batches", _groups.size())
	_root.set_meta("cathedral_sites", _sites.size())
	_root.set_meta("cathedral_sites_positions",_sites.duplicate())
	_root.set_meta("street_sites",_street_sites)
	game.arena_layout.register_city(_street_sites)
	return _root


func _street_site(at: Vector3, yaw: float, scale: float, kind: String) -> void:
	var front := Vector3(0,0,1).rotated(Vector3.UP,yaw)
	var radius := maxf(4.0,13.0*scale)
	var doorway := at+front*(10.5*scale if kind=="house" else 2.0)
	var approach := at+front*maxf(radius+1.3,doorway.distance_to(at)+1.5)
	var site := {"center":at,"door":doorway,"approach":approach,"radius":radius,"front":front,"kind":kind}
	if kind=="house":
		site["half_size"]=Vector2(6.2,9.5)*scale
		site["yaw"]=yaw
	_street_sites.append(site)


func _available(p: Vector3, radius: float) -> bool:
	if str(_game.cfg.arena.get("boundaries",{}).get("style",""))=="mixed" and _game.arena_layout.boundary_kind(p)=="mountain":
		return false
	var bounds: Array = _game.cfg.arena.bounds
	if p.x - radius < float(bounds[0]) or p.z - radius < float(bounds[1]) or p.x + radius > float(bounds[2]) or p.z + radius > float(bounds[3]):
		return false
	return not _game.arena_layout.inside(p, -radius - 1.0)


func _lane_reliquaries() -> void:
	# Gleichmäßig über alle Straßen verteilen, auch bei acht aktiven Lanes begrenzt.
	var per_side := maxi(1, floori(64.0 / maxf(float(_game.arena_layout.paths.size()) * 2.0, 1.0)))
	var count := 0
	for road in _game.arena_layout.paths:
		var slots := mini(per_side, maxi(1, floori(road.length / 14.0)))
		for i in slots:
			var s: float = road.length * float(i + 1) / float(slots + 1)
			if s < 12.0 or s > road.length - 12.0:
				continue
			var p: Vector3 = road.point(s)
			var tangent: Vector3 = (road.point(minf(s + 0.3, road.length)) - road.point(maxf(s - 0.3, 0.0))).normalized()
			var normal := Vector3(-tangent.z, 0, tangent.x)
			for side in [-1.0, 1.0]:
				var site: Vector3 = p + normal * side * (_game.arena_layout.width + 1.75)
				if not _available(site, 0.55) or not _separated(site, 4.2):
					continue
				var facing: Vector3 = -normal * side
				_wall_reliquary(site, atan2(facing.x, facing.z), i % 3 == 1)
				_sites.append(site)
				count += 1
	_root.set_meta("cathedral_verge_details", count)


func _wall_reliquary(at: Vector3, yaw: float, broken: bool) -> void:
	var stone := wall_material()
	var trim := _solid("trim", Color("747785"))
	var roof := roof_material()
	var dark := _solid("door", Color("171c26"))
	_part("box", stone, Vector3(0.95, 0.32, 0.8), at, Vector3(0, 0.16, 0), 1.0, yaw)
	var height := 2.8 if broken else 3.6
	_part("box", stone, Vector3(0.50, height, 0.42), at, Vector3(0, height * 0.5 + 0.25, 0), 1.0, yaw)
	_part("box", trim, Vector3(0.85, 0.18, 0.65), at, Vector3(0, height + 0.28, 0), 1.0, yaw)
	_part("spire", roof, Vector3(0.48, 1.2 if not broken else 0.45, 0.48), at, Vector3(0, height + (0.95 if not broken else 0.55), 0), 1.0, yaw + PI * 0.25)
	_part("lancet", dark, Vector3(0.28, 0.78, 1.0), at, Vector3(0, height - 0.65, 0.23), 1.0, yaw)
	if broken:
		_part("box", trim, Vector3(0.60, 0.25, 0.50), at, Vector3(0.1, 0.14, -0.45), 1.0, yaw + 0.28)


func _separated(p: Vector3, distance: float) -> bool:
	for site in _sites:
		if site.distance_squared_to(p) < distance * distance:
			return false
	return true


func _find_site(preferred: Vector3, radius: float) -> Vector3:
	for offset in [Vector3.ZERO, Vector3(0, 0, 14), Vector3(14, 0, 0), Vector3(-8, 0, -8), Vector3(14, 0, 14)]:
		var p: Vector3 = preferred + offset
		if _available(p, radius):
			return p
	return Vector3.INF


func _place(kind: String, material: Material, size: Vector3, at: Vector3, yaw := 0.0) -> void:
	_queue(kind, material, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), at))


func _queue(kind: String, material: Material, transform: Transform3D) -> void:
	var key := "%s:%d" % [kind, material.get_instance_id()]
	if not _groups.has(key):
		_groups[key] = {"mesh": _mesh(kind), "material": material, "transforms": []}
	_groups[key].transforms.append(transform)


func _mesh(kind: String) -> Mesh:
	if kind == "gable":
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-0.5, 0, -0.5)
		var b := Vector3(0.5, 0, -0.5)
		var c := Vector3(0, 1, -0.5)
		var d := Vector3(-0.5, 0, 0.5)
		var e := Vector3(0.5, 0, 0.5)
		var f := Vector3(0, 1, 0.5)
		# Godot uses clockwise front faces; the old inward roof exposed the flat wall cap.
		var vertices := [a,c,b,d,e,f,a,d,f,a,f,c,b,c,f,b,f,e]
		for i in range(0,vertices.size(),3):
			st.add_vertex(vertices[i])
			st.add_vertex(vertices[i+2])
			st.add_vertex(vertices[i+1])
		st.generate_normals()
		return st.commit()
	if kind == "lancet":
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(-0.5, 0, 0), Vector3(0.5, 0.72, 0), Vector3(0.5, 0, 0),
			Vector3(-0.5, 0, 0), Vector3(-0.5, 0.72, 0), Vector3(0.5, 0.72, 0),
			Vector3(-0.5, 0.72, 0), Vector3(0, 1, 0), Vector3(0.5, 0.72, 0)]:
			st.add_vertex(v)
		st.generate_normals()
		return st.commit()
	if kind == "box":
		return BoxMesh.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.0 if kind == "spire" else 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 4 if kind == "spire" else 8
	return cylinder


func _tower(at: Vector3, scale: float, yaw := 0.0) -> void:
	HdTerrain.patch(_root, at, 3.0 * scale + 1.2)
	var stone := wall_material()
	var trim := _solid("trim", Color("747785"))
	var roof := roof_material()
	var gold := _solid("brass", Color("9e8756"), 0.0, 0.65)
	_part("box", stone, Vector3(6.0, 1.2, 6.0), at, Vector3(0, 0.6, 0), scale, yaw)
	_part("box", stone, Vector3(4.5, 14.0, 4.5), at, Vector3(0, 8.0, 0), scale, yaw)
	_part("box", trim, Vector3(4.9, 0.55, 4.9), at, Vector3(0, 5.0, 0), scale, yaw)
	_part("box", trim, Vector3(5.1, 0.65, 5.1), at, Vector3(0, 15.2, 0), scale, yaw)
	_part("spire", roof, Vector3(4.0, 9.0, 4.0), at, Vector3(0, 20.0, 0), scale, yaw + PI * 0.25)
	_part("cylinder", gold, Vector3(0.14, 1.8, 0.14), at, Vector3(0, 25.3, 0), scale, yaw)
	for side in 4:
		var angle := yaw + float(side) * PI * 0.5
		var forward := Vector3(sin(angle), 0, cos(angle))
		_place("box", stone, Vector3(0.95, 7.0, 1.8) * scale, at + forward * 2.8 * scale + Vector3.UP * 4.0 * scale, angle)
		_window(at + forward * 2.265 * scale + Vector3.UP * 8.0 * scale, angle, 1.1 * scale, 3.0 * scale)
		_window(at + forward * 2.265 * scale + Vector3.UP * 12.0 * scale, angle, 0.7 * scale, 1.5 * scale)
		_arch(at + forward * 2.31 * scale + Vector3.UP * 7.8 * scale, angle, 1.5 * scale, 3.4 * scale, trim, 0.16 * scale)
		var ledge: Vector3 = at + forward * 2.85 * scale + Vector3.UP * 5.4 * scale
		_place("spire", stone, Vector3(0.55, 1.4, 0.55) * scale, ledge, angle + PI * 0.25)
	for x in [-2.35, 2.35]:
		for z in [-2.35, 2.35]:
			_part("box", trim, Vector3(0.23, 12.5, 0.23), at, Vector3(x, 8.9, z), scale, yaw)
			_part("spire", roof, Vector3(0.55, 3.2, 0.55), at, Vector3(x, 17.0, z), scale, yaw + PI * 0.25)


func _part(kind: String, material: Material, size: Vector3, origin: Vector3, offset: Vector3, scale: float, yaw: float) -> void:
	_place(kind, material, size * scale, origin + offset.rotated(Vector3.UP, yaw) * scale, yaw)


func _window(at: Vector3, yaw: float, width: float, height: float) -> void:
	var glow := _solid("windows", Color("d8bc7f"), 1.1)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_place("lancet", glow, Vector3(width, height, 1), at, yaw)
	var muntin := _solid("window_lead", Color("4b4537"))
	_place("box", muntin, Vector3(width * 0.07, height * 0.76, 0.04), at + Vector3.UP * height * 0.4, yaw)


func _chapel(at: Vector3, yaw: float, scale: float, landmark: bool, main := false) -> void:
	_street_site(at,yaw,scale,"house")
	var paving: MeshInstance3D
	if main or landmark or scale>=.5:
		paving=HdTerrain.patch(_root, at, 13.0 * scale + 2.2)
	if main:
		paving.name="FortressDarkPaving"
		paving.position.y=at.y+.024
	var stone := wall_material()
	var trim := _solid("trim", Color("747785"))
	var roof := roof_material()
	_part("box", stone, Vector3(12, 1.0, 22), at, Vector3(0, 0.5, 0), scale, yaw)
	_part("box", stone, Vector3(9.5, 11, 19), at, Vector3(0, 6, 0), scale, yaw)
	_part("box", trim, Vector3(10.2, 0.6, 19.5), at, Vector3(0, 11.7, 0), scale, yaw)
	_part("gable", roof, Vector3(11, 7.5, 21), at, Vector3(0, 12, 0), scale, yaw)
	for side in [-1.0, 1.0]:
		for z in [-6.0, 0.0, 6.0]:
			_part("box", stone, Vector3(1.2, 7.0, 2.2), at, Vector3(side * 5.7, 3.6, z), scale, yaw)
			_part("spire", roof, Vector3(1.2, 3.0, 1.2), at, Vector3(side * 5.7, 8.5, z), scale, yaw + PI * 0.25)
			var offset := Vector3(side * 4.77, 5.0, z)
			_window(at + offset.rotated(Vector3.UP, yaw) * scale, yaw + side * PI * 0.5, 1.6 * scale, 4.1 * scale)
	var door := _solid("door", Color("171c26"))
	_part("lancet", door, Vector3(3.5, 6.5, 1), at, Vector3(0, 1.0, 9.52), scale, yaw)
	_arch(at + Vector3(0, 1.0, 9.62).rotated(Vector3.UP, yaw) * scale, yaw, 4.1 * scale, 6.9 * scale, trim, 0.24 * scale)
	_window(at + Vector3(0, 8.1, 9.55).rotated(Vector3.UP, yaw) * scale, yaw, 2.1 * scale, 3.0 * scale)
	_rose(at + Vector3(0, 9.5, 9.63).rotated(Vector3.UP, yaw) * scale, yaw, 1.7 * scale)
	for side in [-1.0, 1.0]:
		_sentinel(at + Vector3(side * 3.65, 1.0, 9.75).rotated(Vector3.UP, yaw) * scale, yaw, scale * 0.82)
		for z in [-6.0, 0.0, 6.0]:
			_beam(at + Vector3(side * 5.7, 7.0, z).rotated(Vector3.UP, yaw) * scale, at + Vector3(side * 4.85, 10.3, z).rotated(Vector3.UP, yaw) * scale, 0.28 * scale, trim)
	for side in [-1.0, 1.0]:
		_candles(at + Vector3(side * 4.5, 0, 10.4).rotated(Vector3.UP, yaw) * scale, 1.0 * scale, landmark and scale > 1.0)
	if landmark:
		for side in [-1.0, 1.0]:
			_tower(at + Vector3(side * 6.3, 0, 7.0).rotated(Vector3.UP, yaw) * scale, scale * (0.94 if side < 0 else 0.84), yaw)
		_tower(at + Vector3(0, 0, -3).rotated(Vector3.UP, yaw) * scale, scale * 0.6, yaw + PI * 0.25)


func _graveyard(at: Vector3, yaw: float) -> void:
	var stone := _solid("graves", Color("5c6470"))
	var dark := _solid("grave_soil", Color("222a33"))
	for i in 4:
		var local := Vector3(float(i % 2) * 2.4 - 1.2, 0, float(i / 2) * 3.5 - 1.75)
		var p := at + local.rotated(Vector3.UP, yaw)
		_place("box", dark, Vector3(1.5, 0.16, 2.6), p + Vector3.UP * 0.08, yaw)
		_place("box", stone, Vector3(0.9, 1.35, 0.3), p + Vector3(0, 0.7, -1.0).rotated(Vector3.UP, yaw), yaw)
		_place("spire", stone, Vector3(0.62, 0.6, 0.25), p + Vector3(0, 1.65, -1.0).rotated(Vector3.UP, yaw), yaw + PI * 0.25)
		var cross := _solid("window_lead", Color("4b4537"))
		_place("box", cross, Vector3(0.08, 0.65, 0.06), p + Vector3(0, 0.92, -0.82).rotated(Vector3.UP, yaw), yaw)
		_place("box", cross, Vector3(0.42, 0.08, 0.06), p + Vector3(0, 1.05, -0.82).rotated(Vector3.UP, yaw), yaw)
		# Individuell versetzte Deckplatten und kleine Kerzen statt vier identischer Blöcke.
		if i % 2 == 0:
			_place("box", stone, Vector3(1.35, 0.13, 2.45), p + Vector3(0.12, 0.23, 0.02).rotated(Vector3.UP, yaw), yaw + 0.035)
	for side in [-1.0, 1.0]:
		_rail(at + Vector3(side * 2.2, 0, 0).rotated(Vector3.UP, yaw), yaw + PI * 0.5, 5.6)
	if _rng.randf() < 0.35:
		_candles(at + Vector3(3.0, 0, 0), 0.65)


func _beam(from: Vector3, to: Vector3, thickness: float, material: Material) -> void:
	var direction := to - from
	if direction.length_squared() < 0.00001:
		return
	var y := direction.normalized()
	var x := y.cross(Vector3.UP).normalized() if absf(y.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var z := x.cross(y).normalized()
	_queue("box", material, Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3(thickness, direction.length(), thickness)), (from + to) * 0.5))


func _arch(at: Vector3, yaw: float, width: float, height: float, material: Material, thickness: float) -> void:
	for side in [-1.0, 1.0]:
		var half: float = side * width * 0.5
		var start := Vector3(half, 0, 0)
		var spring := Vector3(half, height * 0.55, 0)
		_beam(at + start.rotated(Vector3.UP, yaw), at + spring.rotated(Vector3.UP, yaw), thickness, material)
		var previous := spring
		for segment in range(1, 7):
			var t := float(segment) / 6.0
			var point := spring * pow(1.0 - t, 2) + Vector3(half, height * 0.9, 0) * (2.0 * (1.0 - t) * t) + Vector3.UP * height * t * t
			_beam(at + previous.rotated(Vector3.UP, yaw), at + point.rotated(Vector3.UP, yaw), thickness, material)
			previous = point


func _rose(at: Vector3, yaw: float, radius: float) -> void:
	var metal := _solid("window_lead", Color("4b4537"))
	var trim := _solid("trim", Color("747785"))
	for segment in 12:
		var a := TAU * float(segment) / 12.0
		var b := TAU * float(segment + 1) / 12.0
		var p := Vector3(cos(a), sin(a), 0) * radius
		var q := Vector3(cos(b), sin(b), 0) * radius
		_beam(at + p.rotated(Vector3.UP, yaw), at + q.rotated(Vector3.UP, yaw), radius * 0.10, trim)
		if segment % 2 == 0:
			_beam(at + (p * 0.22).rotated(Vector3.UP, yaw), at + p.rotated(Vector3.UP, yaw), radius * 0.07, metal)


func _sentinel(at: Vector3, yaw: float, scale: float) -> void:
	var stone := wall_material()
	var trim := _solid("trim", Color("747785"))
	var face := _solid("door", Color("171c26"))
	var metal := _solid("candle_metal", Color("777363"), 0.0, 0.55)
	_part("box", stone, Vector3(1.5, 0.25, 1.3), at, Vector3(0, 0.13, 0), scale, yaw)
	_part("box", trim, Vector3(1.25, 0.15, 1.1), at, Vector3(0, 0.32, 0), scale, yaw)
	_part("cylinder", stone, Vector3(0.48, 1.6, 0.36), at, Vector3(0, 1.25, 0), scale, yaw)
	_part("box", stone, Vector3(1.12, 0.5, 0.54), at, Vector3(0, 2.0, 0), scale, yaw)
	_part("spire", stone, Vector3(0.52, 0.96, 0.48), at, Vector3(0, 2.72, 0), scale, yaw + PI * 0.25)
	_part("lancet", face, Vector3(0.36, 0.55, 1), at, Vector3(0, 2.23, 0.35), scale, yaw)
	for side in [-1.0, 1.0]:
		var from: Vector3 = at + Vector3(side * 0.48, 2.0, 0.15).rotated(Vector3.UP, yaw) * scale
		var to: Vector3 = at + Vector3(side * 0.10, 1.58, 0.48).rotated(Vector3.UP, yaw) * scale
		_beam(from, to, 0.21 * scale, stone)
	_part("box", metal, Vector3(0.10, 1.4, 0.08), at, Vector3(0, 1.17, 0.5), scale, yaw)
	_part("box", metal, Vector3(0.65, 0.09, 0.10), at, Vector3(0, 1.72, 0.5), scale, yaw)
	_part("spire", metal, Vector3(0.11, 0.28, 0.08), at, Vector3(0, 0.38, 0.5), scale, yaw + PI)


func _rail(at: Vector3, yaw: float, width: float) -> void:
	var metal := _solid("candle_metal", Color("777363"), 0.0, 0.55)
	for i in 7:
		var p: Vector3 = at + Vector3(width * (float(i) / 6.0 - 0.5), 0, 0).rotated(Vector3.UP, yaw)
		_place("box", metal, Vector3(0.065, 1.05, 0.065), p + Vector3.UP * 0.55, yaw)
		_place("spire", metal, Vector3(0.12, 0.23, 0.12), p + Vector3.UP * 1.17, yaw + PI * 0.25)
	for height in [0.38, 0.9]:
		_place("box", metal, Vector3(width, 0.065, 0.065), at + Vector3.UP * height, yaw)


func _townhouse(site: Dictionary) -> void:
	var at: Vector3=site.pos
	var yaw: float=site.yaw
	var front := Vector3.BACK.rotated(Vector3.UP,yaw)
	var score := int(site.score)
	var width := 5.4+float(score%5)*.4
	var height := 5.2+float(score%4)*.65+(1.5 if score%7==3 else 0.0)
	# Bürgerhäuser meist traufständig (First parallel zur Gasse), jedes dritte giebelständig.
	var eaves := score%3!=0
	var stone := wall_material()
	var trim := _solid("trim",Color("747785"))
	var timber := _solid("town_timber",Color("292529"))
	var dark := _solid("door",Color("171c26"))
	_part("box",stone,Vector3(width,height,7.2),at,Vector3(0,height*.5,0),1,yaw)
	if eaves:
		_place("gable",roof_material(),Vector3(8,2.3+float(score%3)*.25,width+.65),at+Vector3.UP*height,yaw+PI*.5)
	else:
		_part("gable",roof_material(),Vector3(width+.65,2.7,8),at,Vector3(0,height,0),1,yaw)
	_part("box",trim,Vector3(width+.25,.24,7.45),at,Vector3(0,2.9,0),1,yaw)
	_part("box",trim,Vector3(width+.35,.22,7.5),at,Vector3(0,height-.08,0),1,yaw)
	_part("box",stone,Vector3(.75,2.6,.8),at,Vector3(width*.3,height+1.1,-2.3),1,yaw)
	for side in [-1.0,1.0]:
		_part("box",timber,Vector3(.18,height,.16),at,Vector3(side*(width*.5-.18),height*.5,3.64),1,yaw)
		for y in ([1.2,3.6,6.0] if height>7.0 else [1.2,3.6]):
			_window(at+Vector3(side*width*.27,y,3.63).rotated(Vector3.UP,yaw),yaw,.95,1.5)
		for z in [-2.0,1.6]:
			_window(at+Vector3(side*(width*.5+.015),3.6,z).rotated(Vector3.UP,yaw),yaw+side*PI*.5,.95,1.5)
	_part("lancet",dark,Vector3(1.3,2.35,1),at,Vector3(0,0,3.62),1,yaw)
	_arch(at+Vector3(0,0,3.67).rotated(Vector3.UP,yaw),yaw,1.65,2.6,trim,.15)
	var doorstep := at+front*4.1
	var ground := HdArenaMountains.ground_height(_game.arena_layout,doorstep)
	var rise := maxf(.12,at.y-ground)
	for i in 3:
		_part("box",stone,Vector3(2.0,rise*float(3-i)/3.0,.45),Vector3(at.x,ground,at.z),Vector3(0,rise*float(3-i)/6.0,3.75+float(i)*.4),1,yaw)
	_street_sites.append({"center":at,"door":at+front*4.5,"approach":at+front*6,"radius":4.8,"front":front,"kind":"house","town":true,"half_size":Vector2(width*.5,3.65),"yaw":yaw,"row":site.row})

## Platzmitte: abwechselnd Laufbrunnen mit achteckigem Becken oder Pestsäule, wie auf Plätzen in
## Habsburger Städten. Kleiner, registrierter Fußabdruck: Helden laufen herum, Wege führen hin.
func _plaza_monument(plaza: Dictionary) -> void:
	var at: Vector3=plaza.pos
	at.y=HdArenaMountains.ground_height(_game.arena_layout,at)
	var yaw: float=plaza.yaw
	if not _separated(at,6.0):return
	var stone := wall_material()
	var trim := _solid("trim",Color("747785"))
	var fountain := int(round(at.x*3.0+at.z*7.0))%2==0
	if fountain:
		_part("cylinder",stone,Vector3(1.75,.75,1.75),at,Vector3(0,.37,0),1,yaw+PI/8.0)
		_part("cylinder",_solid("plaza_water",Color("1d2a33"),0.0,0.15),Vector3(1.5,.08,1.5),at,Vector3(0,.68,0),1,yaw+PI/8.0)
		_part("cylinder",trim,Vector3(.32,2.4,.32),at,Vector3(0,1.2,0),1,yaw)
		_part("cylinder",stone,Vector3(.62,.25,.62),at,Vector3(0,2.3,0),1,yaw+PI/8.0)
		_part("spire",trim,Vector3(.35,.8,.35),at,Vector3(0,2.8,0),1,yaw+PI*.25)
	else:
		_part("box",stone,Vector3(3.0,.45,3.0),at,Vector3(0,.22,0),1,yaw)
		_part("box",stone,Vector3(2.2,.45,2.2),at,Vector3(0,.66,0),1,yaw)
		_part("box",trim,Vector3(1.3,1.4,1.3),at,Vector3(0,1.55,0),1,yaw)
		_part("cylinder",stone,Vector3(.36,5.0,.36),at,Vector3(0,4.7,0),1,yaw)
		_part("cylinder",trim,Vector3(.7,.35,.7),at,Vector3(0,7.3,0),1,yaw+PI/8.0)
		_part("spire",_solid("brass",Color("9e8756"),0.0,0.65),Vector3(.55,1.6,.55),at,Vector3(0,8.2,0),1,yaw+PI*.25)
		for corner in 4:
			var c := Vector3(1.05,0,1.05).rotated(Vector3.UP,float(corner)*PI*.5)
			_part("spire",trim,Vector3(.32,.9,.32),at,c+Vector3(0,1.3,0),1,yaw+PI*.25)
	var front := Vector3.BACK.rotated(Vector3.UP,yaw)
	_sites.append(at)
	_street_sites.append({"center":at,"door":at+front*2.2,"approach":at+front*3.4,"radius":2.1,"front":front,
		"kind":"fountain" if fountain else "column","half_size":Vector2(1.6,1.6),"yaw":yaw})


func _ruin(at: Vector3, yaw: float) -> void:
	_street_site(at,yaw+PI,.3,"ruin")
	var stone := wall_material()
	var trim := _solid("trim", Color("747785"))
	# Derselbe geprüfte Vier-Meter-Fußabdruck wie die Grabgruppe, keine neue Kollision.
	_arch(at + Vector3(0, 0.25, -1.5).rotated(Vector3.UP, yaw), yaw, 5.0, 5.6, stone, 0.38)
	_arch(at + Vector3(0, 0.25, -1.52).rotated(Vector3.UP, yaw), yaw, 4.3, 5.25, trim, 0.12)
	for side in [-1.0, 1.0]:
		_part("box", stone, Vector3(1.05, 0.4, 1.1), at, Vector3(side * 2.5, 0.2, -1.5), 1.0, yaw)
		_part("spire", trim, Vector3(0.48, 1.1, 0.48), at, Vector3(side * 2.5, 6.3, -1.5), 1.0, yaw + PI * 0.25)
	_sentinel(at + Vector3(-0.9, 0, 1.2).rotated(Vector3.UP, yaw), yaw, 0.9)
	for i in 5:
		var local := Vector3(_rng.randf_range(-2.2, 2.2), 0.12, _rng.randf_range(-0.7, 2.6))
		_place("box", stone, Vector3(_rng.randf_range(0.5, 1.1), 0.25, _rng.randf_range(0.5, 1.2)), at + local.rotated(Vector3.UP, yaw), yaw + _rng.randf_range(-0.5, 0.5))


func _candles(at: Vector3, scale: float, with_light := false) -> void:
	var metal := _solid("candle_metal", Color("777363"), 0.0, 0.55)
	var wax := _solid("wax", Color("bfb58d"))
	var flame := _solid("fire", Color("f3bd6d"), 2.2)
	var core := _solid("fire_core", Color("ffedba"), 3.0)
	_place("cylinder", metal, Vector3(0.7, 0.25, 0.7) * scale, at + Vector3.UP * 0.13 * scale)
	for offset in [Vector3.ZERO, Vector3(0.45, 0, 0.25), Vector3(-0.35, 0, 0.35)]:
		var p: Vector3 = at + offset * scale
		_place("cylinder", wax, Vector3(0.12, 0.75, 0.12) * scale, p + Vector3.UP * 0.55 * scale)
		_place("spire", flame, Vector3(0.15, 0.5, 0.15) * scale, p + Vector3.UP * 1.1 * scale)
		_place("spire", core, Vector3(0.075, 0.3, 0.075) * scale, p + Vector3.UP * 1.05 * scale)
	if with_light and _lights.size() < (2 if Display.quality == Display.LOW else 8):
		var light := OmniLight3D.new()
		light.position = at + Vector3.UP * 2.0 * scale
		light.light_color = Color("ffca89")
		light.light_energy = 1.1
		light.omni_range = 11.0 * maxf(scale, 1.0)
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		_root.add_child(light)
		_lights.append(light)


func _flush() -> void:
	for group in _groups.values():
		var first := _root.get_child_count()
		var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if group.material == _materials.get("windows") or group.material == _materials.get("fire") or group.material == _materials.get("fire_core"):
			shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		preload("res://scripts/map/static_mesh_batch.gd").add(_root,group.mesh,group.transforms,48.0,shadow)
		for instance: MultiMeshInstance3D in _root.get_children().slice(first):
			instance.material_override=group.material
