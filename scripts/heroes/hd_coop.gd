class_name HdCoop
extends Node
## Host rechnet die Welt. Eigene Helden/Inventare, sequenzierte Eingaben, lokale Bewegungsvorhersage.

var game: HdGame
var host := true
var player := 0
var slots := {}
var actors := {}
var targets := {}
var inputs := {}
var pending: Array = []
var sequence := 0
var applied := {}
var revision := 0
var last_revision := -1
var send_time := 0.0
var input_time := 0.0
var applying := false
var executing := false
var context_depth := 0
var event_status := ""
var event_card := {}
var info := {}
var scene_visuals := {}
var status_time := 0.0
var reliable_time := 0.0
var chunks := {}
const CONTEXT_FIELDS := ["_tp_cd", "tp_hold", "tp_stone"]
const HERO_FIELDS := ["hp", "max_hp", "combat_until", "mana", "max_mana", "level", "xp", "dead", "respawn_t", "shield", "shield_until", "attack_cd", "dodge_cd", "dodge_t", "dodge_iframe_until", "dodge_dir", "facing", "cd", "buffs", "kills", "damage_done", "healing_done", "armor", "speed", "bonus", "deaths", "dodges", "damage_taken"]
const KIT_FIELDS := ["form_t", "empowered", "nova_discount", "gust_ready", "ammo", "reload_t", "robe_until", "over_t", "stance", "stance_until", "critical", "flow", "flow_until", "charge", "cast_serial"]
const SHOP_FIELDS := ["gold", "wood", "gold_earned", "wood_earned", "inv", "stash", "wood_bought", "crafted", "trophies", "marks", "merchant"]


func setup(owner_game: HdGame, session: Dictionary) -> void:
	game = owner_game
	info = session
	host = str(session.role) == "host"
	player = int(session.player)
	slots[0 if host else player] = {"hero":game.hero, "shop":game.shop, "kit":game.zix_kit.duplicate()}
	_nameplate(player if not host else 0, game.hero)
	Net.game = game
	Net.set_status({"in_game":true, "mode":"heroes", "wave":0, "lives":game.lives})
	if host:
		Net.coop_command.connect(_command)
		Net.coop_ready.connect(_ready_peer)
		Net.hero_input.connect(receive_input)
	else:
		Net.coop_state.connect(apply_state)
		Net.coop_enemies.connect(apply_state)
		Net.send_coop_ready()
		command({"kind":"hero", "id":game.hero_id})


func _ready_peer(peer: int) -> void:
	var index := Net.coop_player_of(peer)
	if index < 1:
		return
	ensure_player(index)
	slots[index].hero.set_meta("offline", false)
	inputs.erase(index)
	applied.erase(index)
	Net.send_coop_state(peer, snapshot())


func ensure_player(index: int, id := "torvik") -> void:
	if slots.has(index):
		return
	var actor := HdHero.create(game.hero_defs.get(id, game.hero_defs.torvik))
	actor.setup(game, game.hero_defs.get(id, game.hero_defs.torvik))
	actor.position = game.hero_spawn() + Vector3(index * 1.5, 0, 0)
	actor.position = game.free_point(actor.position, actor.radius)
	actor.auto_attack = false
	game.add_child(actor)
	slots[index] = {"hero":actor, "shop":HdShop.new(game), "kit":game.zix_kit.duplicate()}
	actor.set_meta("player", index)
	_nameplate(index, actor)


func with_player(index: int, action: Callable):
	if not slots.has(index):
		return null
	var before := {"hero":game.hero, "shop":game.shop, "kit":game.zix_kit, "id":game.hero_id}
	var slot: Dictionary = slots[index]
	for key in CONTEXT_FIELDS:
		before[key] = game.get(key)
		game.set(key, slot.get(key, {} if key == "tp_stone" else 0.0))
	game.hero = slot.hero
	game.hero_id = str(slot.hero.def.id)
	game.shop = slot.shop
	game.zix_kit = slot.kit
	context_depth += 1
	var result = action.call()
	slot.hero = game.hero
	slot.shop = game.shop
	slot.kit = game.zix_kit
	game.hero = before.hero
	game.hero_id = before.id
	game.shop = before.shop
	game.zix_kit = before.kit
	for key in CONTEXT_FIELDS:
		slot[key] = game.get(key)
		game.set(key, before[key])
	context_depth -= 1
	return result


func heroes() -> Array:
	return slots.values().filter(func(s): return not bool(s.hero.get_meta("offline", false))).map(func(s): return s.hero)


func receive_input(peer: int, frame: Dictionary) -> void:
	if not host:
		return
	var index := Net.coop_player_of(peer)
	if not slots.has(index) or index <= 0 or not valid_input(frame):
		return
	if int(frame.seq) <= int(inputs.get(index, {}).get("seq", -1)):
		return
	inputs[index] = {"seq":int(frame.seq), "move":(frame.move as Vector3).limit_length(1), "aim":frame.aim, "attack":bool(frame.attack), "at":Time.get_ticks_msec()}


static func valid_input(frame: Dictionary) -> bool:
	return frame.get("seq") is int and frame.seq >= 0 and frame.get("move") is Vector3 and frame.get("aim") is Vector3 and frame.move.is_finite() and frame.aim.is_finite() and frame.aim.length() < 2000 and frame.get("attack") is bool


func step_others(dt: float, now: float) -> void:
	for index in slots:
		if index == 0 or bool(slots[index].hero.get_meta("offline", false)):
			continue
		var frame: Dictionary = inputs.get(index, {})
		var fresh: bool = not frame.is_empty() and Time.get_ticks_msec() - int(frame.at) < 300
		with_player(index, func():
			game.hero.order = {}
			game.hero.auto_attack = false
			game.hero.move_dir = frame.move if fresh else Vector3.ZERO
			game.hero.attack_held = fresh and bool(frame.attack)
			if fresh:
				game.hero.aim = frame.aim
			game.hero.step(dt, now)
			if not game.event_arena.active:
				game._step_stones(dt))
		if fresh:
			applied[index] = int(frame.seq)


func enemy_step(enemy: HdEnemy, dt: float, now: float) -> void:
	var closest := 0
	var distance := INF
	for index in slots:
		var h: HdHero = slots[index].hero
		if h.alive() and h.position.distance_squared_to(enemy.position) < distance:
			distance = h.position.distance_squared_to(enemy.position)
			closest = index
	# Ein bestehendes Heldenziel bleibt während des Angriffs die zuständige Schadensadresse.
	for index in slots:
		if enemy.target == slots[index].hero:
			closest = index
	with_player(closest, func(): enemy.step(dt, now))


func command(data: Dictionary) -> void:
	if not host:
		Net.send_coop_command({"hd":_encode(data)})


func _command(peer: int, envelope: Dictionary) -> void:
	var index := Net.coop_player_of(peer)
	if not host or index <= 0 or not envelope.get("hd") is Dictionary or var_to_bytes(envelope).size() > 8192:
		return
	ensure_player(index)
	execute(index, _decode(envelope.hd))
	send_time = 0


func execute(index: int, data: Dictionary) -> bool:
	if not slots.has(index):
		return false
	executing = true
	with_player(index, func():
		match str(data.get("kind", "")):
			"hero":
				if game.state == "setup" and game.hero_defs.has(str(data.get("id", ""))):
					game.set_hero(str(data.id))
			"cast":
				if game.state == "play" and not game.paused and data.get("at") is Vector3 and data.at.is_finite() and int(data.get("slot", -1)) in range(4):
					game.hero.cast(int(data.slot), data.at)
			"dodge":
				if game.state == "play" and not game.paused and data.get("dir") is Vector3 and data.dir.is_finite():
					game.hero.dodge(data.dir)
			"skill":
				game.hero.skills.upgrade(int(data.get("slot", -1)))
			"shop":
				if game.state == "play" and data.get("cmd") is Dictionary:
					var why := game.shop.act(data.cmd)
					if why != "":
						game.message.emit(why)
			"early":
				game.call_early()
			"imprint":
				game.choose_imprint(int(data.get("index", -1)))
			"pause":
				if game.imprint_pending.is_empty():
					game.paused = bool(data.get("value", false))
	)
	executing = false
	return true


func _process(dt: float) -> void:
	for index in slots:
		var actor: HdHero = slots[index].hero
		if not actor.has_node("PlayerName"):
			_nameplate(index, actor)
		var plate: Label3D = actor.get_node("PlayerName")
		plate.text = "%s · %d/%d" % [str(info.names[index]) if index < info.names.size() else str(index + 1), roundi(actor.hp), roundi(actor.max_hp)]
	status_time -= dt
	if status_time <= 0:
		status_time = 0.5
		if host and Net.is_active():
			var peers: Array = Net.group_peers()
			for index in slots:
				if index == 0:
					continue
				var offline: bool = index >= peers.size() or int(peers[index]) < 0
				slots[index].hero.set_meta("offline", offline)
				if offline:
					game.withdraw_imprint(index)
				slots[index].hero.visible = not offline and not slots[index].hero.dead
		Net.set_status({"in_game":true, "mode":"heroes", "wave":game.wave, "lives":game.lives})
	if host:
		send_time -= dt
		if send_time <= 0:
			send_time = 0.05
			var packet := snapshot()
			reliable_time -= 0.05
			if reliable_time <= 0:
				reliable_time = 0.5
				Net.send_coop_state(0, packet)
			else:
				broadcast_frame(packet)
	else:
		_predict(dt)
		for actor: HdHero in heroes():
			actor._anim_step(dt)
			actor._face(actor.aim - actor.position if actor == game.hero else actor.facing)
		for actor in targets:
			if is_instance_valid(actor) and actor != game.hero:
				actor.position = actor.position.lerp(targets[actor], minf(dt * 16, 1))
				if actor is HdEnemy:
					actor._anim_step(dt, false)


func _predict(dt: float) -> void:
	if game.state != "play" or game.paused:
		return
	game._sample_input()
	if game.control == "maus":
		_mouse_input()
	input_time += dt
	if game.hero.alive() and not game.hero.cc.stunned(game.play_time):
		if game.hero.dodge_t > 0:
			var move_dt := minf(minf(dt, 0.05), game.hero.dodge_t)
			game.hero.dodge_t = maxf(0, game.hero.dodge_t - dt)
			game.move_unit(game.hero, game.hero.dodge_dir, float(game.hero.def.dodge.distance) / float(game.hero.def.dodge.time), move_dt, true)
		else:
			if game.play_time >= float(game.hero.get_meta("root_until", -1)):
				game.move_unit(game.hero, game.hero.move_dir, game.hero.movement_speed(game.play_time), minf(dt, 0.05), true)
	game.hero.dodge_cd = maxf(0, game.hero.dodge_cd - dt)
	if input_time >= 1.0 / 30:
		sequence += 1
		var frame := {"seq":sequence, "move":game.hero.move_dir, "aim":game.hero.aim, "attack":game.hero.attack_held}
		pending.append({"seq":sequence, "move":game.hero.move_dir, "dt":minf(input_time, 0.1)})
		if pending.size() > 90:
			pending.pop_front()
		input_time = 0
		Net.send_hero_input(frame)


func snapshot() -> Dictionary:
	revision += 1
	var characters := []
	for index in slots:
		var h: HdHero = slots[index].hero
		var d := {"player":index, "id":h.def.id, "pos":h.position, "ranks":h.skills.ranks, "points":h.skills.points, "ack":int(applied.get(index, 0)), "shop":{}, "kit":slots[index].kit, "online":not bool(h.get_meta("offline", false)), "cc":{"stun":h.cc.stun_until, "slows":h.cc._slows, "armor":h.cc._armor, "root":float(h.get_meta("root_until", -1))}}
		d.imprint_choices = game.imprint_pending.get(index, [])
		for key in HERO_FIELDS:
			d[key] = h.get(key)
		for key in SHOP_FIELDS:
			d.shop[key] = slots[index].shop.get(key)
		if h is HdHeroTorvik:
			d.form_t = h.form_t
		d.kit_state = {}
		for key in KIT_FIELDS:
			if key in h:
				d.kit_state[key] = h.get(key)
		characters.append(d)
	var definitions := {}
	var foes := []
	for e in game.enemies:
		if e.dead or game.event_arena.frozen(e):
			continue
		definitions[e.id] = e.def
		foes.append({"net":e.get_instance_id(), "id":e.id, "pos":e.position, "hp":e.hp, "max_hp":e.max_hp, "shield":e.shield, "facing":e.facing, "cast":e.cast.get("ab", {}), "phase":e.phase, "visible":e.is_visible_in_tree(), "immortal":e.immortal})
	var gates := []
	for b in game.buildings:
		if game.event_arena.frozen(b):
			continue
		gates.append({"net":b.get_instance_id(), "pos":b.position, "hp":b.hp, "max_hp":b.max_hp, "destroyed":b.destroyed, "def":b.def, "road":str(b.road.id) if b.road else "", "kind":b.gate_kind, "gadget":b.kind if b is HdGadget else "", "ally":b.kind if b is HdAlly else "", "owner":game.hero_slot(b.zix) if b is HdGadget else -1, "origin":(b.position + b.mast_b) * 0.5 if b is HdGadget and b.kind == "elektrozaun" else b.position, "direction":(b.mast_b - b.position).cross(Vector3.UP).normalized() if b is HdGadget and b.kind == "elektrozaun" else Vector3.FORWARD})
	var visuals := []
	for child in game.get_children() + game.fx.get_children():
		if child is HdTelegraph and child.visible:
			visuals.append({"net":"w" + str(child.get_instance_id()), "pos":child.position, "rot":child.rotation.y, "shape":child.shape, "radius":child.radius, "inner":child.inner, "angle":child.angle, "length":child.length, "width":child.width, "color":child.color, "progress":child.progress, "flash":child.flash})
	for projectile in game.projectiles:
		visuals.append({"net":"p" + str(projectile.node.get_instance_id()), "pos":projectile.pos, "rot":projectile.node.rotation.y, "shot":true, "look":str(projectile.get("look", "")), "size":float(projectile.get("size", 0.2)), "color":projectile.get("color", UiTheme.CYAN if projectile.from_hero else HdTelegraph.RED)})
	var effects: Array = game.fx.network_events.duplicate()
	game.fx.network_events.clear()
	return {"health_fields":game.health_orbs.field_snapshot(), "health_orbs":game.health_orbs.snapshot(), "definitions":definitions, "visuals":visuals, "fx":effects, "hd":true, "rev":revision, "state":game.state, "paused":game.paused, "wave":game.wave, "wave_time":game.wave_time, "time":game.play_time, "hour":game.time_of_day(), "lives":game.lives, "max_lives":game.max_lives, "kills":game.kills, "lanes":game.active_road_ids(), "heroes":characters, "enemies":foes, "buildings":gates, "event":game.event_arena.active, "event_status":game.events.status(), "card":game.events.kinds.card(), "choice":game.events.choice, "event_id":str(game.events.choice.get("id", game.events.active.get("id", game.events.kinds.task.get("id", "")))), "exploration":game.exploration.snapshot(), "imprints":game.imprints, "imprint_choices":game.imprint_choices, "final":game.final.active, "final_id":game.final_boss_id, "final_lines":game.final.lines(), "final_run":game.final.run_state(), "challenges":_challenge_state()}


func apply_state(data: Dictionary) -> void:
	if data.get("hd_chunk", false):
		accept_chunk(data)
		return
	if host or not bool(data.get("hd", false)) or int(data.get("rev", -1)) <= last_revision:
		return
	last_revision = int(data.rev)
	applying = true
	if game.active_road_ids() != data.lanes:
		game.lane_ids = data.lanes
		game._build_roads()
	var was_setup := game.state == "setup"
	var was_over := game.state == "over"
	game.state = str(data.state)
	game.paused = bool(data.paused)
	game.wave = int(data.wave)
	game.wave_time = float(data.wave_time)
	game.exploration.apply_state(data.get("exploration", {}))
	game.play_time = float(data.time)
	game.lives = int(data.lives)
	game.max_lives = int(data.max_lives)
	game.kills = int(data.kills)
	game.day_cycle.set_hour(float(data.hour))
	game.imprints = data.imprints
	game.imprint_choices = data.imprint_choices
	game.events.choice = data.choice
	event_status = str(data.event_status)
	event_card = data.card
	game.events.active = {"id":str(data.event_id)} if str(data.event_id) != "" else {}
	game.event_arena.active = bool(data.event)
	if game.event_arena.active:
		game.event_arena.ensure_ground()
	game.final_boss_id = str(data.final_id)
	if bool(data.final) and not game.final.active:
		game.final.enter()
	game.final.remote_lines = data.final_lines
	game.final.remote_run = data.final_run
	game.health_orbs.apply_state(data.get("health_orbs", []), data.get("health_fields", []))
	for key in data.challenges:
		game.systems.challenges.set(key, data.challenges[key])
	for d in data.heroes:
		var index := int(d.player)
		if index == player:
			game.imprint_choices = d.get("imprint_choices", data.imprint_choices)
		ensure_player(index, str(d.id))
		var h: HdHero = slots[index].hero
		if str(h.def.id) != str(d.id):
			with_player(index, func(): game.set_hero(str(d.id)))
			h = slots[index].hero
		for key in HERO_FIELDS:
			h.set(key, d.get(key, h.get(key)))
		for key in d.kit_state:
			if key in h:
				h.set(key, d.kit_state[key])
		h.skills.ranks.assign(d.ranks)
		h.skills.points = int(d.points)
		if h is HdHeroTorvik:
			h.form_t = float(d.get("form_t", 0))
		for key in SHOP_FIELDS:
			slots[index].shop.set(key, d.shop[key])
		slots[index].kit = d.kit
		h.cc.stun_until = float(d.cc.stun)
		h.cc._slows = d.cc.slows
		h.cc._armor = d.cc.armor
		h.set_meta("root_until", float(d.cc.root))
		h.set_meta("offline", not bool(d.online))
		h.visible = not h.dead and bool(d.online)
		if index == player:
			game.hero = h
			game.hero_id = str(h.def.id)
			game.shop = slots[index].shop
			game.zix_kit = d.kit
			var old := h.position
			h.position = d.pos
			pending = pending.filter(func(f): return int(f.seq) > int(d.ack))
			for frame in pending:
				game.move_unit(h, frame.move, h.movement_speed(game.play_time), float(frame.dt), true)
			if old.distance_to(h.position) < 4:
				h.position = old.lerp(h.position, 0.45)
		else:
			if h.position.distance_to(d.pos) > 20:
				h.position = d.pos
			targets[h] = d.pos
	game.enemy_defs.merge(data.definitions, true)
	_sync_actors(data.enemies, true)
	_sync_visuals(data.visuals)
	for effect in data.fx:
		match str(effect.kind):
			"impact":
				game.fx.impact(effect.pos, effect.element, effect.dir)
			"swing":
				game.fx.swing(effect.pos, effect.dir, float(effect.reach), effect.color)
			"bolt":
				game.fx.bolt(effect.a, effect.b, effect.color)
			"tracer":
				game.fx.tracer(effect.a, effect.b, effect.color)
			"beam":
				game.fx.beam(effect.a, effect.b, effect.color, float(effect.width))
			"play":
				game.fx.play(str(effect.id), effect.pos, effect.dir, float(effect.size), effect.color, effect.to)
			"hold":
				game.fx.hold(str(effect.key), str(effect.id), effect.pos, float(effect.size), effect.color, effect.to)

	_sync_actors(data.buildings, false)
	if game.cam_pos.distance_to(game.hero.position) > 80:
		game.cam_pos = game.hero.position
	if was_setup and game.state != "setup":
		game.hud.on_started()
	if game.state == "over" and not was_over:
		game.ended.emit(game.lives > 0)
	game.hud.econ.shop = game.shop
	game.hud.side.shop = game.shop
	applying = false
	game.changed.emit()


## Unterhalb der ENet-MTU bleiben: komprimierte Frames in kleine unabhängige Datagramme teilen.
func broadcast_frame(packet: Dictionary) -> void:
	var raw := var_to_bytes(packet)
	var bytes := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var count := ceili(bytes.size() / 900.0)
	for part in count:
		Net.send_hero_frame({"hd_chunk":true, "rev":int(packet.rev), "part":part, "parts":count, "size":raw.size(), "bytes":bytes.slice(part * 900, mini((part + 1) * 900, bytes.size()))})


func accept_chunk(data: Dictionary) -> void:
	var frame := int(data.get("rev", -1))
	var part := int(data.get("part", -1))
	var count := int(data.get("parts", 0))
	var size := int(data.get("size", 0))
	if frame <= last_revision or count < 1 or count > 512 or part < 0 or part >= count or size < 1 or size > 2 * 1024 * 1024 or not data.get("bytes") is PackedByteArray or data.bytes.size() > 900:
		return
	if not chunks.has(frame):
		chunks[frame] = {"count":count, "parts":{}, "size":size}
	if int(chunks[frame].count) != count or int(chunks[frame].size) != size:
		return
	chunks[frame].parts[part] = data.bytes
	for old in chunks.keys():
		if old < frame - 2:
			chunks.erase(old)
	if chunks[frame].parts.size() != count:
		return
	var bytes := PackedByteArray()
	for index in count:
		bytes.append_array(chunks[frame].parts[index])
	chunks.erase(frame)
	var raw := bytes.decompress(size, FileAccess.COMPRESSION_ZSTD)
	if raw.is_empty():
		return
	var state = bytes_to_var(raw)
	if state is Dictionary:
		apply_state(state)


func _sync_actors(rows: Array, foes: bool) -> void:
	var keep := {}
	for d in rows:
		var key := str(d.net)
		keep[key] = true
		var actor = actors.get(key)
		if not is_instance_valid(actor):
			if foes:
				actor = HdEnemy.new()
				actor.road = game.roads[0]
				actor.setup(game, game.enemy_defs[d.id], game.wave)
				game.enemies.append(actor)
			else:
				# Hauptkarten-Torwerke wiederverwenden, damit Straßen-/Shop-Verweise gültig bleiben.
				var road = game.road_by_id(str(d.road))
				actor = road.gate(str(d.kind)) if road else null
				if not is_instance_valid(actor):
					if bool(d.def.get("roster_construct", false)):
						actor = HdRosterConstruct.new()
						var construct_owner: HdHero = slots.get(int(d.def.owner_slot), slots[0]).hero
						actor.setup_construct(game, d.def, d.pos, construct_owner)
					elif str(d.gadget) != "" and slots.has(int(d.owner)):
						actor = HdGadget.new()
						var owner_actor: HdHero = slots[int(d.owner)].hero
						actor.setup_gadget(game, str(d.gadget), d.def, d.origin, owner_actor, d.direction)
						if owner_actor is HdHeroZix:
							owner_actor.gadgets.append(actor)
					elif str(d.ally) != "":
						actor = HdAlly.new()
						actor.setup_ally(game, d.def, str(d.ally), d.pos)
					else:
						actor = HdBuilding.new()
						var definition: Dictionary = d.def.duplicate(true)
						definition.pos = [d.pos.x, d.pos.z]
						actor.setup(game, definition)
					game.buildings.append(actor)
			actors[key] = actor
			actor.set_meta("net", key)
			if not actor.is_inside_tree():
				game.add_child(actor)
			actor.position = d.pos
		actor.hp = float(d.hp)
		actor.max_hp = float(d.max_hp)
		actor.visible = true
		if foes:
			actor.visible = bool(d.get("visible",true))
			actor.immortal = bool(d.get("immortal",false))
			actor.shield = float(d.shield)
			actor.facing = d.facing
			actor.cast = {"ab":d.cast} if not d.cast.is_empty() else {}
			actor.phase = int(d.phase)
			if game.final.active and actor.rank == "boss":
				game.final.boss = actor
		else:
			actor.destroyed = bool(d.destroyed)
		targets[actor] = d.pos
	for key in actors.keys():
		var actor = actors[key]
		if (actor is HdEnemy) != foes or keep.has(key):
			continue
		targets.erase(actor)
		if foes:
			game.enemies.erase(actor)
			actor.queue_free()
		else:
			if actor.road != null:
				actor.hide()
			else:
				game.buildings.erase(actor)
				if actor is HdGadget and is_instance_valid(actor.zix) and actor.zix is HdHeroZix:
					actor.zix.gadgets.erase(actor)
				actor.queue_free()
		actors.erase(key)


func _encode(value):
	if value is Node:
		return {"actor":str(value.get_meta("net", value.get_instance_id()))}
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _encode(value[key])
		return out
	if value is Array:
		return value.map(_encode)
	return value


func _decode(value):
	if value is Dictionary:
		if value.keys() == ["actor"]:
			for actor in game.buildings:
				if str(actor.get_instance_id()) == str(value.actor):
					return actor
			return null
		var out := {}
		for key in value:
			out[key] = _decode(value[key])
		return out
	if value is Array:
		return value.map(_decode)
	return value


func _sync_visuals(rows: Array) -> void:
	var keep := {}
	for data in rows:
		var id := str(data.net)
		keep[id] = true
		var visual = scene_visuals.get(id)
		if not is_instance_valid(visual):
			if bool(data.get("shot", false)):
				visual = HdFxParts.shot(str(data.look), data.color, float(data.get("size", 0.2))) if str(data.get("look", "")) != "" else HdDev.sphere(0.2, HdDev.flat(data.color))
			else:
				visual = HdTelegraph.make(int(data.shape), data.color)
				for key in ["radius", "inner", "angle", "length", "width"]:
					visual.set(key, data[key])
			game.add_child(visual)
			if bool(data.get("shot",false)):
				game.fx.follow_light(visual,data.color)
			scene_visuals[id] = visual
		visual.position = data.pos
		visual.rotation.y = float(data.rot)
		if visual is HdTelegraph:
			game.conform_ground_effect(visual)
			visual.progress = float(data.progress)
			visual.flash = float(data.get("flash", 0))
	for id in scene_visuals.keys():
		if not keep.has(id):
			scene_visuals[id].queue_free()
			scene_visuals.erase(id)


func _challenge_state() -> Dictionary:
	var state := {}
	for key in ["open", "time", "states", "active_id", "gains", "boss_started", "boss_reason"]:
		state[key] = game.systems.challenges.get(key)
	return state


func _nameplate(index: int, actor: HdHero) -> void:
	if actor.has_node("PlayerName"):
		return
	var label := Label3D.new()
	label.name = "PlayerName"
	label.position.y = 2.7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.012
	label.modulate = Color("9be2ef") if index == player else Color("f1d7a2")
	actor.add_child(label)


func _mouse_input() -> void:
	var actor := game.hero
	var order: Dictionary = actor.order
	actor.move_dir = Vector3.ZERO
	actor.attack_held = false
	if str(order.get("kind", "")) == "move":
		var delta: Vector3 = order.point - actor.position
		if delta.length() > 0.3:
			actor.move_dir = delta.normalized()
		else:
			actor.order = {}
	elif str(order.get("kind", "")) == "attack":
		var enemy = order.get("target")
		if not is_instance_valid(enemy) or enemy.dead:
			actor.order = {}
			return
		actor.aim = enemy.position
		var delta: Vector3 = enemy.position - actor.position
		if delta.length() > actor.attack_range() + enemy.radius + actor.radius:
			actor.move_dir = delta.normalized()
		else:
			actor.attack_held = true
	else:
		var enemy = game.nearest_enemy(actor.position, actor.attack_range())
		if enemy:
			actor.order = {"kind":"attack", "target":enemy}
