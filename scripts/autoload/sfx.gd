extends Node
## Sounds: Schüsse je Tower-Farbe, Ereignisse (Bauen, Fehler, Welle, Boss …) und Ambiente.
## Zuordnung in data/sfx.json, Dateien unter assets/sounds/ (geschnitten von tools/sfx/schneiden.py).
## Lautstärke für Effekte und Ambiente in user://settings.cfg, Abschnitt "audio".
##   Sfx.play("build")              Ereignis aus sfx.json → events
##   Sfx.play_shot("ruby", 2)       Schuss eines Towers (Effects.add_beam ruft das auf)
##   Sfx.set_ambience("amb_forest") Schleife im Hintergrund, "" = aus

const DATA := "res://data/sfx.json"
const DIR := "res://assets/sounds/"
const SETTINGS := "user://settings.cfg"
const BUS_SFX := "Effekte"
const BUS_AMB := "Ambiente"
const VOICES := 20
## Derselbe Schuss-Sound höchstens alle … ms (viele Tower gleicher Farbe würden sonst knattern)
const SAME_GAP_MS := 55
## Höchstens so viele Schüsse gleichzeitig, der Rest der Stimmen bleibt für Ereignisse frei
const MAX_SHOTS := 12

## Headless (Tests, Server) wird nichts wirklich abgespielt: der Dummy-Treiber gibt die Wiedergaben
## sonst nicht mehr frei. Die Auswahl der Stimmen läuft trotzdem, damit Tests sie prüfen können.
var audible := DisplayServer.get_name() != "headless"
var volume := 0.7  ## Effekte, 0 … 1
var ambience_volume := 0.6  ## Ambiente, 0 … 1

var _data: Dictionary = {}
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _last := {}  ## Sound-Schlüssel → Zeit (ms) des letzten Abspielens
var _shot_cache := {}  ## "tower:stufe" → {sound, pitch, db}
var _amb: AudioStreamPlayer
var _amb_id := ""
## Ambiente mit "bursts" (sfx.json): läuft nur ab und zu ein paar Sekunden, dazwischen Pause
var _amb_bursts := {}
var _amb_on := false
var _amb_left := 0.0  ## Sekunden bis zum nächsten Wechsel (Echtzeit, unabhängig vom Spieltempo)
var _amb_len := 0.0   ## Länge des laufenden Stücks


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		volume = clampf(float(cfg.get_value("audio", "effects", volume)), 0.0, 1.0)
		ambience_volume = clampf(float(cfg.get_value("audio", "ambience", ambience_volume)), 0.0, 1.0)
	for bus in [BUS_SFX, BUS_AMB]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_apply_volume()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.bus = BUS_AMB
	add_child(_amb)


func _exit_tree() -> void:
	stop_all()


## Alles anhalten und die geladenen Sounds freigeben.
func stop_all() -> void:
	for p in _players:
		p.stop()
		p.stream = null
		p.remove_meta("until")
	_amb.stop()
	_amb.stream = null
	_streams.clear()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save()


func set_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save()


## Ereignis aus sfx.json → events abspielen. pitch multipliziert die Tonhöhe aus der Datei.
func play(event: String, pitch := 1.0) -> void:
	var ev: Dictionary = _data.get("events", {}).get(event, {})
	if ev.is_empty():
		return
	# "gap": dasselbe Ereignis höchstens alle … Sekunden (z. B. mehrere Bosse hintereinander)
	var now := Time.get_ticks_msec()
	if now - int(_last.get("ev:" + event, -100000)) < int(float(ev.get("gap", 0.0)) * 1000.0):
		return
	_last["ev:" + event] = now
	var base := float(ev.get("pitch", 1.0)) * pitch
	var arp: Array = ev.get("arpeggio", [])
	if arp.is_empty():
		_play(str(ev.sound), base, float(ev.get("db", 0.0)), true)
		return
	# Kleine Tonfolge (Kombinieren): die Töne kurz nacheinander
	for i in arp.size():
		var step := float(arp[i])
		get_tree().create_timer(0.07 * i, true, false, true).timeout.connect(
			func(): _play(str(ev.sound), base * step, float(ev.get("db", 0.0)), true))


## Rückmeldung zu einem eigenen Befehl (game.submit): Bauen, Kombinieren, Fehler … ok = angenommen.
## Im Koop als Mitspieler ist ok immer true (der Host entscheidet später).
func command_sound(cmd: Dictionary, ok: bool) -> void:
	var event := ""
	match str(cmd.get("type", "")):
		"place", "build", "trap", "debug_place", "replace_rocks", "move_trap":
			event = "build"
		"remove_rocks", "sell":
			event = "rock_remove"
		"option":
			match str(cmd.get("action", "")):
				"keep":
					event = "keep"
				"scrap":
					event = "rock_remove"
				"take_back", "move":
					return
				_:
					event = "combine"
		_:
			return
	play(event if ok else "error")


## Schuss des Towers id auf Stufe tier (Klang nach Farbe, Regeln in sfx.json → shots).
func play_shot(id: String, tier: int) -> void:
	var key := "%s:%d" % [id, tier]
	if not _shot_cache.has(key):
		_shot_cache[key] = shot_for(id, tier)
	var s: Dictionary = _shot_cache[key]
	if s.is_empty():
		return
	var vary := float(_data.get("shots", {}).get("variation", 0.0))
	_play(s.sound, s.pitch * (1.0 + randf_range(-vary, vary)), s.db, false, key)


## Nova/Zauber eines Towers (Effects.add_beam mit "n:…").
func play_nova(id: String, tier: int) -> void:
	var n: Dictionary = _data.get("shots", {}).get("nova", {})
	if not n.is_empty():
		_play(str(n.sound), float(n.get("pitch", 1.0)) * _tier_factor(tier), float(n.get("db", 0.0)), false)


## Welcher Schuss-Sound zu einem Tower gehört: {sound, pitch, db}, leer = keiner.
func shot_for(id: String, tier: int) -> Dictionary:
	var def := FxData.tower_def(id)
	var rules: Dictionary = _data.get("shots", {})
	var own := str(def.get("shot_sfx", ""))
	if own == "none":
		return {}
	if own != "":
		var parts := own.split("@")
		return {"sound": parts[0], "pitch": float(parts[1]) if parts.size() > 1 else 1.0, "db": 0.0}
	var pick: Dictionary = FxData.element_for(def).get("sound", {}).duplicate()
	var types := FxData._ability_types(def, tier)
	if pick.is_empty() and ("bounce" in types or "chain" in types):
		pick = {"sound": "shot_zap", "pitch": 1.0}
	for t in types:
		if pick.is_empty() and rules.get("ability", {}).has(t):
			pick = rules.ability[t].duplicate()
			break
	var col := Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	if pick.is_empty():
		if col.v < 0.3 and rules.has("dark"):
			pick = rules.dark.duplicate()
		elif col.s < 0.35 and rules.has("pale"):
			# Weiß klingt am hellsten, je mehr Farbe, desto tiefer (Diamant hoch, Opal mittel)
			pick = rules.pale.duplicate()
			pick.pitch = float(pick.get("pitch", 1.0)) * (1.0 - col.s)
		else:
			var best := {}
			var dist := INF
			for e in rules.get("hue", []):
				var d := FxData._hue_diff(col.h, float(e.hue))
				if absf(d) < absf(dist):
					dist = d
					best = e
			if best.is_empty():
				return {}
			pick = best.duplicate()
			pick.pitch = float(pick.get("pitch", 1.0)) * (1.0 + dist * float(rules.get("hue_pitch", 0.0)))
	return {"sound": str(pick.sound), "pitch": float(pick.get("pitch", 1.0)) * _tier_factor(tier), "db": float(pick.get("db", 0.0))}


## Hintergrund-Schleife (sfx.json → sounds), "" stoppt sie.
func set_ambience(id: String) -> void:
	if id == _amb_id:
		return
	_amb_id = id
	_amb_bursts = {}
	_amb_on = false
	_amb.stop()
	if id == "":
		return
	var stream := _stream(id)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_amb.stream = stream
	_amb.volume_db = float(_data.sounds[id].get("db", 0.0))
	_amb_bursts = _data.sounds[id].get("bursts", {})
	_amb_on = false
	if _amb_bursts.is_empty():
		if audible:
			_amb.play()
	else:
		_amb_left = _rand_range(_amb_bursts.get("first", [2, 6]))


## Läuft das Ambiente gerade hörbar (bei "bursts" nur während eines Stücks)?
func ambience_on() -> bool:
	return _amb_id != "" and (_amb_bursts.is_empty() or _amb_on)


func _process(delta: float) -> void:
	if _amb_bursts.is_empty() or _amb_id == "":
		return
	_amb_left -= delta / maxf(Engine.time_scale, 0.01)
	var base := float(_data.sounds[_amb_id].get("db", 0.0))
	if _amb_on:
		# Ein- und Ausblenden am Anfang und Ende des Stücks
		var fade := maxf(float(_amb_bursts.get("fade", 1.5)), 0.01)
		var t := _amb_len - _amb_left
		var gain := clampf(minf(t, _amb_left) / fade, 0.0, 1.0)
		_amb.volume_db = base + linear_to_db(maxf(gain, 0.001))
	if _amb_left > 0.0:
		return
	_amb_on = not _amb_on
	if _amb_on:
		_amb_len = _rand_range(_amb_bursts.get("play", [5, 9]))
		_amb_left = _amb_len
		_amb.volume_db = base - 60.0
		if audible:
			_amb.play(randf() * maxf(_amb.stream.get_length() - _amb_len, 0.0))
	else:
		_amb_left = _rand_range(_amb_bursts.get("pause", [20, 45]))
		_amb.stop()


func _rand_range(r) -> float:
	return randf_range(float(r[0]), float(r[1])) if r is Array and r.size() == 2 else float(r)


func ambience() -> String:
	return _amb_id


func _tier_factor(tier: int) -> float:
	return maxf(0.5, 1.0 + float(_data.get("shots", {}).get("tier_pitch", 0.0)) * tier)


## key: Schlüssel für die Drosselung (Standard: Sound und Tonhöhe), Schüsse nehmen den Tower.
func _play(id: String, pitch: float, db: float, important: bool, key := "") -> void:
	var stream := _stream(id)
	if stream == null or volume <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if key == "":
		key = "%s@%.2f" % [id, pitch]
	if not important:
		if now - int(_last.get(key, -100000)) < SAME_GAP_MS:
			return
		var busy := 0
		for p in _players:
			if is_busy(p) and p.has_meta("shot"):
				busy += 1
		if busy >= MAX_SHOTS:
			return
	_last[key] = now
	var player: AudioStreamPlayer = null
	var oldest := INF
	for p in _players:
		if not is_busy(p):
			player = p
			break
		# Alle belegt: die älteste Stimme übernehmen (nur für wichtige Ereignisse)
		if important and float(p.get_meta("t", 0)) < oldest:
			oldest = float(p.get_meta("t", 0))
			player = p
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.1, 4.0)
	player.volume_db = float(_data.sounds[id].get("db", 0.0)) + db
	player.set_meta("t", now)
	player.set_meta("until", now + int(stream.get_length() / player.pitch_scale * 1000.0))
	if important:
		player.remove_meta("shot")
	else:
		player.set_meta("shot", true)
	if audible:
		player.play()


## Spielt die Stimme gerade (headless: hätte sie noch gespielt)?
func is_busy(p: AudioStreamPlayer) -> bool:
	return p.playing if audible else Time.get_ticks_msec() < int(p.get_meta("until", 0))


func _stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var s: Dictionary = _data.get("sounds", {}).get(id, {})
	var stream: AudioStream = null
	if not s.is_empty() and ResourceLoader.exists(DIR + str(s.file)):
		stream = load(DIR + str(s.file))
	_streams[id] = stream
	return stream


func _apply_volume() -> void:
	for pair in [[BUS_SFX, volume], [BUS_AMB, ambience_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(i, pair[1] <= 0.0)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "effects", volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.save(SETTINGS)
