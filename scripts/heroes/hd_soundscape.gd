class_name HdSoundscape
extends Node
## Local presentation only: client FX use the same mix as host FX. Existing audio sliders/buses apply.
const DIR := "res://assets/sounds/bollwerk/"
const VOICES := 12
var game: Node3D
var _voices: Array[AudioStreamPlayer] = []
var _streams := {}
var _last := {}
var _previous := ""
var _crow: AudioStreamPlayer
var _crow_calls: Array[AudioStream] = []
var _crow_wait := 12.0
var _ambient_rng := RandomNumberGenerator.new()
var _fire: AudioStreamPlayer
var _foot_at := Vector3.ZERO
var _foot_distance := 0.0
var _bell_wait := 19.0
var fires: Array[Vector3] = []


func _ready() -> void:
	game = get_parent()
	_ambient_rng.randomize()
	_crow_wait=_ambient_rng.randf_range(8,20)
	_crow=AudioStreamPlayer.new()
	_crow.bus=Sfx.BUS_AMB
	add_child(_crow)
	for i in range(1,4):_crow_calls.append(load(DIR+"crow_%d.wav" % i))
	_previous = Sfx.ambience()
	Sfx.set_ambience("hd_wind")
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = Sfx.BUS_SFX
		add_child(voice)
		_voices.append(voice)
	_fire = AudioStreamPlayer.new()
	_fire.bus = Sfx.BUS_AMB
	var stream := load(DIR + "fire_loop.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_fire.stream = stream
	_fire.volume_db = -60
	add_child(_fire)
	if Sfx.audible:
		_fire.play()


func _exit_tree() -> void:
	if Sfx.ambience() == "hd_wind":
		Sfx.set_ambience(_previous)


static func palette(id: String) -> String:
	if id == "thrust": return "swing"
	if id == "steel": return "steel"
	if id.begins_with("boss:"):
		return {"forge":"fire","tide":"swing","rot":"shadow","time":"bell","void":"shadow"}.get(id.split(":")[1],"stone")
	if id.begins_with("roster:"):
		var parts := id.split(":")
		var ability := HdRosterFx._ability(parts[1], int(parts[2]))
		var op := str(ability.get("op", "blast"))
		if parts[1] in ["sorek", "ada"]: return "chain" if parts[1] == "sorek" else "bell"
		if parts[1] == "kaspar": return "bolt"
		if parts[1] == "orrin": return "fire"
		if parts[1] == "ilsabet": return "frost"
		if op in ["heal", "revive", "buff", "beacon", "beacon_blink"]: return "heal"
		if op in ["guard", "wall", "turret", "taunt"]: return "stone"
		if op in ["cone", "line", "dash", "execute"]: return "swing"
		return "shadow"
	if id in ["heal", "health_orb", "capsule_pop", "ascend", "overcharge"]: return "heal"
	if "fire" in id or id in ["scrap_blast", "lob", "overdose"]: return "fire"
	if "thunder" in id or id in ["bolt", "muzzle"]: return "bolt"
	if "wind" in id or id in ["swing", "dash", "gust_line"]: return "swing"
	if id in ["build", "stun_hit"]: return "stone"
	if id == "impact": return "steel"
	return "shadow"


func effect(id: String, at: Vector3, volume := -12.0) -> void:
	if not Sfx.audible or game.get("paused") == true: return
	var actor = game.get("hero")
	if not is_instance_valid(actor): return
	var distance: float = actor.position.distance_to(at)
	if distance > 45.0: return
	var key := palette(id)
	var now := Time.get_ticks_msec()
	if now - int(_last.get(key, -1000)) < (130 if key != "bell" else 900): return
	var voice: AudioStreamPlayer
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null: return
	_last[key] = now
	if not _streams.has(key): _streams[key] = load(DIR + key + ".wav")
	voice.stream = _streams[key]
	voice.pitch_scale = .96 + float(now % 83) * .001
	voice.volume_db = volume - distance * .45
	voice.play()


func _process(dt: float) -> void:
	var actor = game.get("hero")
	if not is_instance_valid(actor): return
	var paused: bool = game.get("paused") == true
	for voice in _voices: voice.stream_paused = paused
	_fire.stream_paused = paused
	_crow.stream_paused = paused or not Sfx.audible
	if paused: return
	var outdoors: bool=game.state=="play" and not game.event_arena.active and not game.final.active and HdExplorationLayout.cave_at(actor.position).is_empty()
	if outdoors:
		_crow_wait-=dt
		if _crow_wait<=0:
			_crow_wait=_ambient_rng.randf_range(24,58)
			if Sfx.audible:
				_crow.stream=_crow_calls[_ambient_rng.randi_range(0,2)]
				_crow.pitch_scale=_ambient_rng.randf_range(.93,1.06)
				_crow.volume_db=_ambient_rng.randf_range(-24,-20)
				_crow.play()
	elif _crow.playing:
		_crow.stop()
	var nearest := 40.0
	for at in fires: nearest = minf(nearest, actor.position.distance_to(at))
	for source: Node3D in get_tree().get_nodes_in_group("bollwerk_fire_sources"):
		for local: Vector3 in source.get_meta("fire_sources",[]):
			nearest = minf(nearest,actor.position.distance_to(source.to_global(local)))
	_fire.volume_db = lerpf(_fire.volume_db, -16.0 - minf(nearest * 1.9, 44.0), minf(dt * 3.0, 1.0))
	var movement: float = actor.position.distance_to(_foot_at)
	if movement < 2.0 and actor.get("dead") != true:
		_foot_distance += movement
		if _foot_distance >= 1.4:
			_foot_distance = 0.0
			_step(actor.position)
	else: _foot_distance = 0.0
	_foot_at = actor.position
	_bell_wait -= dt
	if _bell_wait <= 0:
		_bell_wait = 43.0
		effect("roster:ada:0:cast", actor.position, -29.0)


func _step(_at: Vector3) -> void:
	if not Sfx.audible: return
	if not _streams.has("step"): _streams.step = load(DIR + "step.wav")
	for voice in _voices:
		if not voice.playing:
			voice.stream = _streams.step
			voice.pitch_scale = 1.0 + float(Time.get_ticks_msec() % 100) * .001
			voice.volume_db = -26
			voice.play()
			return
