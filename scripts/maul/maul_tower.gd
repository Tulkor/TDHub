class_name MaulTower
extends Tower
## Tower einer Filiale in Shopping Maul. Werte aus data/maul/shops.json (eine Stufe pro Tower,
## Upgrades sind eigene Tower mit "upgrade_from"). Schießt wie ein GemTD-Tower und wirkt dazu
## Zauber mit eigener Abklingzeit: Donnerschlag (nova_spell), Kettenblitz (chain_spell),
## Schockwelle (wave_spell), Blitzlicht/Neid (stun_spell: betäubt alle im Radius), Flirten (flirt_spell:
## hält den stärksten Gegner in Reichweite fest). "life": Chance, beim Kill Leben zurückzuholen. Aussehen: Gebäude aus data/maul/models.json (Wände in der Filialfarbe),
## höher je teurer; ohne Modell eine Neon-Säule.
##
## Profi-Filialen (Etappe 2, Daten in pro.json):
##   Post/IKEO: items = eingelegte Waffen (Slots je Tower), jede feuert mit eigener Abklingzeit.
##   Fitness:   flat = gesammelte Stärke und Doping-Schaden, side = Nebenwirkungsstufen, paused = Kalter Entzug.
##   Gärtnerei: water = Füllstand; Pflanzen greifen nur aktiv (ab 90 %, aus unter 75 %) und mit Wasser an.
##   Bestatter: corpses = gefressene Leichen der Contained Darkness, unleashed_until = Zeit als Unleashed Darkness.

const SPELLS := ["nova_spell", "chain_spell", "wave_spell", "stun_spell", "flirt_spell"]
## Art déco: Licht-Ebene nur für Tower-Modelle (Ebene 20) und Farbe des Tower-Lichts (warmes Messingweiß)
const TOWER_LAYER := 1 << 19
const TOWER_LIGHT := Color(1.0, 0.96, 0.9)

var value := 0             ## Gold, das im Tower steckt (Kauf und Upgrades); Verkauf bringt 75 %
var items: Array = []      ## eingelegte Items (Post, IKEO)
var flat := 0.0            ## zusätzlicher Schaden pro Treffer (Fitness: Stärke und Doping)
var side := 0              ## Nebenwirkungsstufen (Fitness)
var paused := false        ## Fitness: Anabolika nicht bezahlt, greift dieses Level nicht an
var drugs := {}            ## Fitness: "stun", "frost", "slow_aura" aus dem Doping
var water := 0.0           ## Gärtnerei: Wasser in Litern
var active := false        ## Gärtnerei: Pflanze hat genug Wasser und greift an
var corpses := 0           ## Contained Darkness
var unleashed_until := -1.0
var summon_ready := {}     ## Einheit -> Spielzeit, ab der sie wieder beschworen werden kann
var _spell_cd := {}        ## Index der Fähigkeit -> Restzeit
var _item_cd := {}         ## Slot -> Restzeit
var _extra: Array = []     ## Fähigkeiten aus dem Doping


func set_tower(id: String, _t: int) -> void:
	tower_id = id
	tier = 0
	def = MaulData.tower(id)
	stats = def
	color = Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	place_at(cell)
	_spell_cd.clear()
	_item_cd.clear()
	_update_extra()
	_build_visual()


func slots() -> int:
	return int(MaulData.pro().get("slots", {}).get(tower_id, 0))


func plant() -> Dictionary:
	return MaulData.pro().get("garden", {}).get("plants", {}).get(tower_id, {})


func is_unleashed() -> bool:
	return game != null and unleashed_until > game.game_time


## Doping-Fähigkeiten (Betäubung, Frost, Verlangsamungsaura) zu den Fähigkeiten des Towers.
func _update_extra() -> void:
	_extra = []
	if drugs.has("stun"):
		_extra.append({"type": "stun", "chance": float(drugs.stun[0]), "duration": float(drugs.stun[1])})
	if drugs.has("frost"):
		_extra.append({"type": "slow", "factor": float(drugs.frost), "duration": 1.0})
	if drugs.has("slow_aura"):
		_extra.append({"type": "slow_aura", "radius": range_cells(), "factor": float(drugs.slow_aura)})


func abilities() -> Array:
	return stats.get("abilities", []) + _extra if not _extra.is_empty() else stats.get("abilities", [])


func range_cells() -> float:
	var r := float(stats.get("range", 3.0))
	if is_unleashed():
		r = float(MaulData.pro().undertaker.darkness.range)
	if game != null:
		r += game.range_bonus_for(self)
	return r


func label() -> String:
	return str(def.get("name", tower_id))


func kill_bonus() -> float:
	return 0.0


func can_attack() -> bool:
	if paused or not plant().is_empty():
		return false
	if is_unleashed():
		return true
	var dmg: Array = stats.get("damage", [0, 0])
	return float(stats.get("cooldown", 0)) > 0.0 and float(dmg[1]) > 0.0


func can_target(e) -> bool:
	return super.can_target(e) and (game == null or game.is_detected(e))


func target_mode() -> String:
	if is_unleashed():
		return str(MaulData.pro().undertaker.darkness.targets)
	return super.target_mode()


func cooldown() -> float:
	var f: float = game.frost_factor(self) if game != null else 1.0
	var cd := float(MaulData.pro().undertaker.darkness.cooldown) if is_unleashed() else float(stats.get("cooldown", 1.0))
	return cd / (1.0 + speed_bonus) * f


## Faktor durch Nebenwirkungen (Fitness): −5 % je Stufe, höchstens −90 %.
func side_factor() -> float:
	return maxf(1.0 - side * float(MaulData.pro().get("fitness", {}).get("side_step", 0.05)), 0.1)


func _roll_damage() -> float:
	var dmg: Array = stats.get("damage", [1, 1])
	var base := randf_range(float(dmg[0]), float(dmg[1]))
	if is_unleashed():
		base = float(MaulData.pro().undertaker.darkness.damage)
	base += flat + (game.flat_bonus_for(self) if game != null else 0.0)
	return base * (game.damage_factor(self) if game != null else 1.0) * side_factor()


func _process(delta: float) -> void:
	super._process(delta)
	if game == null or game.mirror or not game.is_wave_running():
		return
	if not items.is_empty():
		_fire_items(delta)
	if not plant().is_empty():
		_fire_plant(delta)
	var list := abilities()
	for i in list.size():
		var ab: Dictionary = list[i]
		var type := str(ab.get("type", ""))
		if not type in SPELLS:
			continue
		var left: float = _spell_cd.get(i, 0.0) - delta
		if left <= 0.0 and _cast(ab):
			left += float(ab.get("cooldown", 2.0)) * (game.frost_factor(self) if game != null else 1.0)
		_spell_cd[i] = maxf(left, -delta)


## Eingelegte Items (Post, IKEO): jedes ist eine eigene Waffe mit Schaden, Abklingzeit und Reichweite.
func _fire_items(delta: float) -> void:
	for i in items.size():
		var it := MaulData.item(str(items[i]))
		if not it.has("cooldown"):
			continue
		var left: float = _item_cd.get(i, 0.0) - delta
		if left <= 0.0:
			var mode := str(it.get("targets", "both"))
			var target = null
			for e in game.find_targets_in(self, float(it.range), 8):
				if (mode == "air" and not e.flying) or (mode == "ground" and e.flying):
					continue
				target = e
				break
			if target != null:
				game.add_beam(position + Vector3(0, 0.9, 0), target.position, color.lerp(Color.WHITE, 0.3))
				_hit(target, float(it.damage) * game.damage_factor(self))
				left += float(it.cooldown) * game.frost_factor(self)
		_item_cd[i] = maxf(left, -delta)


## Gärtnerei: aktiv ab 90 % Wasser, aus unter 75 %. Jeder Schuss kostet Wasser (gegen Luft das Doppelte).
func _fire_plant(delta: float) -> void:
	var p := plant()
	var g: Dictionary = MaulData.pro().garden
	var cap := float(p.water)
	if active and water < cap * float(g.off):
		active = false
	elif not active and water >= cap * float(g.on):
		active = true
	if not active:
		return
	cooldown_left = maxf(cooldown_left - delta, -delta)
	if cooldown_left > 0.0:
		return
	var targets: Array = game.find_targets(self, 1)
	if targets.is_empty():
		return
	var e = targets[0]
	var cost := float(p.air_cost if e.flying else p.cost)
	if water < cost:
		return
	water -= cost
	game.add_beam(position + Vector3(0, 0.6, 0), e.position, color)
	var dmg: float = float(p.air_damage if e.flying else p.damage) * game.damage_factor(self)
	e.last_hit_by = owner_player
	total_damage += e.take_spell_damage(dmg)
	if e.dead:
		_killed(e)
	cooldown_left += cooldown()


## Zauber wirken, wenn ein Ziel in Reichweite ist. true = gewirkt.
func _cast(ab: Dictionary) -> bool:
	var bonus: float = game.damage_factor(self)
	match str(ab.type):
		"nova_spell":
			var near: Array = game.enemies_in_radius(pos, float(ab.radius)).filter(func(e): return can_target(e))
			if near.is_empty():
				return false
			for e in near:
				if float(ab.get("slow", 0.0)) > 0.0:
					e.apply_slow(float(ab.slow), float(ab.get("slow_duration", 3.0)))
				_spell_hit(e, float(ab.damage) * bonus)
			game.add_ring(pos, float(ab.radius), color)
			return true
		"chain_spell":
			var r := float(ab.get("range", range_cells()))
			var first = null
			for e in game.find_targets_in(self, r, 1):
				first = e
			if first == null:
				return false
			var hit := [first]
			var current = first
			var dmg: float = float(ab.damage) * bonus
			game.add_beam(position + Vector3(0, 1.0, 0), first.position, Color.WHITE)
			_spell_hit(first, dmg)
			for i in int(ab.get("targets", 3)) - 1:
				dmg *= float(ab.get("falloff", 0.85))
				var next = null
				var best := INF
				for other in game.enemies_in_radius(current.pos, 4.0):
					var d: float = other.pos.distance_to(current.pos)
					if not other in hit and can_target(other) and d < best:
						best = d
						next = other
				if next == null:
					break
				game.add_beam(current.position, next.position, Color.WHITE)
				hit.append(next)
				_spell_hit(next, dmg)
				current = next
			return true
		"wave_spell":
			var r := float(ab.get("range", range_cells()))
			var first = null
			for e in game.find_targets_in(self, r, 1):
				first = e
			if first == null:
				return false
			var dir: Vector2 = (first.pos - pos).normalized()
			var width := float(ab.get("width", 1.5))
			var end := pos + dir * r
			for e in game.enemies_in_radius(pos, r + width):
				if not can_target(e):
					continue
				var rel: Vector2 = e.pos - pos
				var along := rel.dot(dir)
				if along >= 0.0 and along <= r and absf(rel.cross(dir)) <= width:
					_spell_hit(e, float(ab.damage) * bonus)
			game.add_beam(Board3D.to_3d(pos, 0.3), Board3D.to_3d(end, 0.3), color.lerp(Color.WHITE, 0.5))
			return true
		"stun_spell":
			var near: Array = game.enemies_in_radius(pos, float(ab.radius)).filter(func(e): return can_target(e))
			if near.is_empty():
				return false
			for e in near:
				e.apply_stun(_stun_time(e, ab))
			game.add_ring(pos, float(ab.radius), Color.WHITE)
			return true
		"flirt_spell":
			# der Gegner mit den meisten Lebenspunkten, der noch nicht festgehalten wird
			var best = null
			for e in game.find_targets_in(self, range_cells(), 99):
				if e.stun_time <= 0.0 and (best == null or e.hp > best.hp):
					best = e
			if best == null:
				return false
			best.apply_stun(_stun_time(best, ab))
			game.add_beam(position + Vector3(0, 1.0, 0), best.position, Color("#ff7ad9"))
			return true
	return false


## Betäubungsdauer eines Zaubers: Bosse (Helden) kürzer.
func _stun_time(e, ab: Dictionary) -> float:
	var boss: bool = e.boss or e.armor_type == "hero"
	return float(ab.get("boss_duration", ab.duration)) if boss else float(ab.duration)


## Life (Fries Carver, Hellboy): Chance, beim Kill Leben zurückzuholen (wie AOX).
func _killed(e) -> void:
	super._killed(e)
	var ab := ability("life")
	if game != null and not ab.is_empty() and randf() < float(ab.chance):
		game.kill_life(owner_player, e)


func _spell_hit(e, dmg: float) -> void:
	if e.dead:
		return
	e.last_hit_by = owner_player
	total_damage += e.take_spell_damage(dmg)
	if e.dead:
		_killed(e)


func info_text() -> String:
	return label()


## Wert der eingelegten Items (zählt beim Verkaufen mit).
func items_value() -> int:
	var v := 0
	for id in items:
		v += int(MaulData.item(str(id)).get("cost", 0))
	return v


# --- Darstellung ---------------------------------------------------------------

func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_preview_ring = null
	_gem = null
	_visual = Node3D.new()
	add_child(_visual)
	if FieldStyle.current_name() == FieldStyle.DECO:
		_build_deco_base()
	else:
		_build_neon_base()
	# Höhe wächst mit dem Wert: 9 Gold ≈ 0,35, 6.000 Gold ≈ 1,5 Towerbreiten
	var cost := maxf(float(def.get("value", def.get("cost", 10))), 5.0)
	var h := clampf(0.15 + log(cost) / log(10.0) * 0.36, 0.3, 1.6)
	var look := _look(cost)
	_spin = look.is_empty() or not str(look.path).contains("/models/towers/")
	if not look.is_empty():
		_gem = ModelLoader.instantiate_fit(look.path, 0.84, h + 0.5)
		if _gem:
			if look.tint != "":
				_tint_material(_gem, look.tint, color)
			_gem.position.y = 0.12
			_visual.add_child(_gem)
			if look.tint != "" and FieldStyle.current_name() == FieldStyle.DECO:
				_deco_trim(ModelLoader.aabb(_gem, Transform3D()))
			if FieldStyle.current_name() == FieldStyle.DECO:
				ModelLoader.add_outline(_gem)
				_add_tower_light(_gem)
			_finish_visual()
			return
	_build_pillar(h)


## Sockel im Neon-Stil: dunkle Platte mit leuchtendem Rand in der Filialfarbe.
func _build_neon_base() -> void:
	var base := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.92, 0.12, 0.92)
	base.mesh = slab
	base.position.y = 0.06
	base.material_override = Board3D.make_material(Color("160b28"))
	_visual.add_child(base)
	# Neonrand in der Filialfarbe um den Sockel
	var rim := MeshInstance3D.new()
	var rim_box := BoxMesh.new()
	rim_box.size = Vector3(0.97, 0.04, 0.97)
	rim.mesh = rim_box
	rim.position.y = 0.07  # Oberkante unter der Sockelplatte, sichtbar bleibt nur der Rand
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = color
	rim_mat.emission_enabled = true
	rim_mat.emission = color
	rim_mat.emission_energy_multiplier = 1.2
	rim.material_override = rim_mat
	_visual.add_child(rim)


## Sockel in Art déco: zweistufiger Sockel aus Messing und Petrol-Marmor, schmales Band in der Filialfarbe.
func _build_deco_base() -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = DecoTheme.GOLD
	brass.metallic = 0.9
	brass.roughness = 0.3
	Metall.veredeln(brass)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("16393b")
	stone.roughness = 0.2
	stone.metallic_specular = 0.8
	var band := StandardMaterial3D.new()
	band.albedo_color = color
	band.emission_enabled = true
	band.emission = color
	band.emission_energy_multiplier = 0.35
	for step in [[0.96, 0.035, 0.0175, brass], [0.9, 0.07, 0.07, stone], [0.91, 0.018, 0.096, band], [0.82, 0.02, 0.115, brass]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(step[0], step[1], step[0])
		mi.mesh = box
		mi.position.y = step[2]
		mi.material_override = step[3]
		_visual.add_child(mi)


## Art-déco-Zierteile an einem Haus (box = Umriss im Tower): Messing-Lisenen an den Ecken,
## Messing-Gesims oben und eine gestufte Krone mit Spitze, höher bei teuren Towern.
func _deco_trim(box: AABB) -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = DecoTheme.BRASS_LIGHT
	brass.metallic = 0.9
	brass.roughness = 0.28
	brass.emission_enabled = true
	brass.emission = DecoTheme.GOLD
	brass.emission_energy_multiplier = 0.12
	Metall.veredeln(brass)
	var top := box.end.y
	var cx := box.get_center().x
	var cz := box.get_center().z
	var w := minf(box.size.x, box.size.z)
	var parts: Array = []  # [Größe, Mitte]
	# Lisenen an den vier Ecken bis knapp unter das Dach
	var pil := clampf(w * 0.06, 0.018, 0.035)
	var ph := (top - box.position.y) * 0.82
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var p := Vector3(cx + sx * (box.size.x / 2.0 - pil * 0.3), box.position.y + ph / 2.0, cz + sz * (box.size.z / 2.0 - pil * 0.3))
			parts.append([Vector3(pil, ph, pil), p])
	# Krone: drei Stufen, je schmaler, dann eine Spitze
	var steps := 3
	var sw := w * 0.55
	var y := top
	for i in steps:
		var sh := 0.035 + 0.01 * (steps - i)
		parts.append([Vector3(sw, sh, sw), Vector3(cx, y + sh / 2.0, cz)])
		y += sh
		sw *= 0.66
	var spire := clampf((top - box.position.y) * 0.35, 0.08, 0.3)
	parts.append([Vector3(0.022, spire, 0.022), Vector3(cx, y + spire / 2.0, cz)])
	for part in parts:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = part[0]
		mi.mesh = b
		mi.position = part[1]
		mi.material_override = brass
		_visual.add_child(mi)


## Art déco: unsichtbares Licht ohne Schatten, das nur den Tower selbst trifft (eigene Licht-Ebene), damit er
## im dunklen Maul fast ganz ausgeleuchtet ist; Boden und Nachbarn bleiben unberührt (Lukas, 2026-10-30).
func _add_tower_light(model: Node3D) -> void:
	_set_layer(model)
	var box := ModelLoader.aabb(model, Transform3D())
	var top := box.position.y + box.size.y
	for p in [Vector3(0.0, top + 0.3, 0.7), Vector3(0.0, top * 0.5, -0.6)]:
		var light := OmniLight3D.new()
		light.light_color = TOWER_LIGHT
		light.light_energy = 0.75 if p.z > 0.0 else 0.3
		light.omni_range = 1.8 + box.size.y
		light.omni_attenuation = 0.6
		light.shadow_enabled = false
		light.light_cull_mask = TOWER_LAYER
		light.position = p
		_visual.add_child(light)


static func _set_layer(n: Node) -> void:
	if n is VisualInstance3D:
		n.layers |= TOWER_LAYER
	for c in n.get_children():
		_set_layer(c)


## Modell: passendes aus data/tower_models.json (TowerModels), sonst Gebäude nach data/maul/models.json.
## {"path", "tint" (Materialname zum Einfärben oder "")} oder leer.
func _look(cost: float) -> Dictionary:
	var own := TowerModels.look("maul", tower_id)
	if not own.is_empty():
		return {"path": own.model, "tint": ""}
	var cfg := MaulData.models()
	if cfg.is_empty():
		return {}
	var level := 0
	for limit in cfg.get("levels", []):
		if cost >= float(limit):
			level += 1
	var shop_cfg: Dictionary = cfg.get("shops", {}).get(str(def.get("shop", "")), {})
	var dir := "city"
	var tint := str(cfg.get("tint_material", ""))
	var list: Array = []
	if not shop_cfg.is_empty():
		var levels: Array = shop_cfg.get("models", [])
		list = levels[mini(level, levels.size() - 1)] if not levels.is_empty() else []
		dir = str(shop_cfg.get("dir", dir))
		if not bool(shop_cfg.get("tint", true)):
			tint = ""
	elif str(def.get("targets", "both")) == "air":
		list = cfg.get("air", [])
		tint = ""
	else:
		var levels: Array = cfg.get("default", [])
		list = levels[mini(level, levels.size() - 1)] if not levels.is_empty() else []
	if list.is_empty():
		return {}
	var name := str(list[absi(tower_id.hash()) % list.size()])
	return {"path": "res://assets/models/%s/%s.glb" % [dir, name], "tint": tint}


## Färbt alle Flächen mit dem Material mat_name (z. B. die Wände der Quaternius-Häuser) in col.
static func _tint_material(n: Node, mat_name: String, col: Color) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(i)
			if m is BaseMaterial3D and m.resource_name == mat_name:
				var c: BaseMaterial3D = m.duplicate()
				c.albedo_color = col.lerp(Color(0.85, 0.85, 0.85), 0.25)
				n.set_surface_override_material(i, c)
	for c in n.get_children():
		_tint_material(c, mat_name, col)


## Ersatz ohne Modell: Neon-Säule in der Filialfarbe.
func _build_pillar(h: float) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var w := 0.5 if str(def.get("targets", "both")) != "air" else 0.36
	box.size = Vector3(w, h, w)
	body.mesh = box
	body.position.y = 0.12 + h / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.35)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.4
	body.material_override = mat
	_visual.add_child(body)
	# Kappe in Weiß: Lufttower spitz, Bodentower flach, beide als Neonkante
	var cap := MeshInstance3D.new()
	if str(def.get("targets", "both")) == "air":
		var prism := PrismMesh.new()
		prism.size = Vector3(w * 1.2, 0.3, w * 1.2)
		cap.mesh = prism
		cap.position.y = 0.12 + h + 0.15
	else:
		var top := BoxMesh.new()
		top.size = Vector3(w + 0.1, 0.06, w + 0.1)
		cap.mesh = top
		cap.position.y = 0.12 + h + 0.03
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = color.lerp(Color.WHITE, 0.6)
	cap_mat.emission_enabled = true
	cap_mat.emission = color.lerp(Color.WHITE, 0.4)
	cap_mat.emission_energy_multiplier = 1.4
	cap.material_override = cap_mat
	_visual.add_child(cap)
	_finish_visual()
