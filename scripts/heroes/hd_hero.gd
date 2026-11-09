class_name HdHero
extends Node3D
## Grundlage aller Helden im Hero-Defense-Modus: Werte, Stufen, Bewegung, Grundangriff (Nahkampf im
## Bogen oder Fernkampf), Ausweichen, Stärkungen (buffs), Schild und Heilung. Das eigene Kit steckt
## in der Unterklasse je Held (KITS), Daten in data/heroes_helden.json.
## Steuerung kommt von HdGame (WASD-Modus: move_dir + aim + attack_held; Maus-Modus: order) oder
## vom Bot (bot_act). Fähigkeiten über cast(slot, punkt), Ausweichen über dodge(richtung).
## Unterklassen überschreiben: _build_body, _cast, _kit_step, _ranged_shot, on_hit, status_lines,
## slot_glow, ability, bot_act.

const KITS := {
	"torvik": "res://scripts/heroes/hd_hero_torvik.gd",
	"unrat": "res://scripts/heroes/hd_hero_unrat.gd",
	"vesna": "res://scripts/heroes/hd_hero_vesna.gd",
	"zix": "res://scripts/heroes/hd_hero_zix.gd",
}

var game  ## HdGame
var def: Dictionary
var level := 1
var xp := 0.0
var hp := 100.0
var max_hp := 100.0
var mana := 100.0
var max_mana := 100.0
var armor := 0.0
var speed := 6.0
var radius := 0.7
var cc: HdCc
var dead := false
var respawn_t := 0.0
var facing := Vector3(0, 0, -1)
var move_dir := Vector3.ZERO    ## WASD (Weltrichtung, Länge 0–1)
var aim := Vector3.ZERO         ## Mauspunkt am Boden
var attack_held := false        ## WASD: Linksklick gehalten
var order: Dictionary = {}      ## Maus-Modus: {kind: move, point} | {kind: attack, target}
var auto_attack := false        ## Maus-Modus: in der Nähe selbst angreifen
var attack_cd := 0.0
var cd: Array = [0.0, 0.0, 0.0, 0.0]
var dodge_cd := 0.0
var dodge_t := 0.0
var dodge_dir := Vector3.ZERO
var buffs: Dictionary = {}      ## Name → {until, dmg_out, dmg_in, speed, slow_immune}
var shield := 0.0
var shield_until := 0.0
var damage_done := 0.0
var damage_taken := 0.0
var healing_done := 0.0
var kills := 0
var deaths := 0
## Werte aus Items und Holz (HdShop.bonus): hp, mana, armor, hp_regen, mana_regen und Anteile damage,
## attack_speed, speed, cdr, lifesteal (0,1 = +10 %).
var bonus: Dictionary = {}
var ward_until := 0.0           ## Schutzrolle: weniger Schaden bis dahin
var ward := 0.0
var dodges := 0
var _body: Node3D
var _glow: MeshInstance3D
## Figur aus Blender (tools/modelle/helden_bau.py) mit Animationen idle/run/attack/cast/death; ohne Modell
## bleiben die Dev-Formen aus _build_body sichtbar.
var _anim: AnimationPlayer
var _anim_name := ""
var _anim_lock := 0.0
var _anim_pos := Vector3.ZERO
var _anim_cd: Array = []
var _anim_attack := 0.0
var _dead_t := 0.0


## Neuen Helden zur Datenzeile anlegen (Unterklasse nach id).
static func create(d: Dictionary) -> HdHero:
	var path: String = KITS.get(str(d.get("id", "")), "")
	if path == "":
		return HdHero.new()
	return load(path).new()


func setup(g, d: Dictionary) -> void:
	game = g
	def = d
	radius = float(d.radius)
	speed = float(d.speed)
	cc = HdCc.new(game.cfg.cc, "hero")
	_apply_level()
	hp = max_hp
	mana = max_mana
	_body = Node3D.new()
	add_child(_body)
	_build_body()
	_load_model()
	_glow = HdDev.cyl(1.1, 1.1, 0.05, HdDev.flat(Color(1.0, 0.85, 0.4), 0.35), Vector3(0, 0.05, 0), 24)
	_glow.visible = false
	add_child(_glow)


func _build_body() -> void:
	_body.add_child(HdDev.cyl(0.55, 0.65, 1.5, HdDev.mat(Color("3d8fd6"), 0.5), Vector3(0, 0.75, 0)))


## Modell aus def.model laden. Die Dev-Formen bleiben als Knoten erhalten (Kits greifen darauf zu), werden
## aber ausgeblendet; Unterklassen schalten ihre Effekt-Teile (z. B. Torviks Form-Leuchten) selbst wieder ein.
func _load_model() -> void:
	var path := str(def.get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var scene = load(path)
	if not scene is PackedScene:
		return
	for c in _body.get_children():
		c.visible = false
	var m: Node3D = scene.instantiate()
	Metall.modell(m)
	m.scale = Vector3.ONE * float(def.get("model_scale", 1.0))
	_body.add_child(m)
	var players := m.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0]
	for a in ["idle", "run"]:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_anim_pos = position
	_play("idle")


func has_model() -> bool:
	return _anim != null


func _play(a: String, lock := 0.0, speed := 1.0) -> void:
	if _anim == null or not _anim.has_animation(a):
		return
	if a != _anim_name or lock > 0.0:
		_anim.play(a, 0.12 if lock <= 0.0 else 0.05)
		if lock > 0.0:
			_anim.seek(0.0, true)
		_anim_name = a
	_anim.speed_scale = speed
	if lock > 0.0:
		_anim_lock = _anim.get_animation(a).length / maxf(speed, 0.1)


## Animation nach Zustand: Angriff/Zauber erkennt sie an neu gesetzten Abklingzeiten (gilt so für jedes Kit,
## auch für eigene _ranged_shot/_cast), Laufen an der Bewegung seit dem letzten Schritt.
func _anim_step(dt: float) -> void:
	if _anim == null:
		return
	var moved := Vector2(position.x - _anim_pos.x, position.z - _anim_pos.z).length() / maxf(dt, 0.0001)
	_anim_pos = position
	_anim_lock = maxf(0.0, _anim_lock - dt)
	if dead:
		_dead_t += dt
		if _anim_name != "death":
			_play("death", 0.01)
		elif _dead_t > 2.5:
			visible = false
		_anim_cd = cd.duplicate()
		return
	var cast := false
	for i in mini(cd.size(), _anim_cd.size()):
		if float(cd[i]) > float(_anim_cd[i]) + 0.01:
			cast = true
	_anim_cd = cd.duplicate()
	var hit := attack_cd > _anim_attack + 0.01
	_anim_attack = attack_cd
	if cast:
		_play("cast", 1.0, 1.4)
	elif hit:
		_play("attack", 1.0, clampf(0.9 / maxf(attack_interval(), 0.2), 1.0, 2.5))
	elif _anim_lock > 0.0:
		return
	elif moved > 0.5:
		_play("run", 0.0, clampf(moved / 5.0, 0.6, 2.2))
	else:
		_play("idle")


func _apply_level() -> void:
	var lv: Dictionary = def.level
	var k := level - 1
	var old_max := max_hp
	max_hp = float(def.hp) + float(lv.hp) * k + b("hp")
	max_mana = float(def.mana) + float(lv.mana) * k + b("mana")
	armor = float(def.armor) + float(lv.armor) * k + b("armor")
	speed = float(def.speed) * (1.0 + b("speed"))
	if old_max > 0.0 and hp > 0.0:
		hp += max_hp - old_max
	hp = clampf(hp, 1.0 if hp > 0.0 else 0.0, max_hp)
	mana = minf(mana, max_mana)


func b(key: String) -> float:
	return float(bonus.get(key, 0.0))


## Neue Item-/Holzwerte übernehmen (Leben wächst mit, wie in WC3).
func set_bonus(d: Dictionary) -> void:
	bonus = d
	_apply_level()


func attack_interval() -> float:
	return float(def.attack.interval) / (1.0 + b("attack_speed"))


func xp_needed(lvl: int) -> float:
	var lv: Dictionary = def.level
	return float(lv.xp_base) * pow(float(lv.xp_growth), lvl - 1)


func add_xp(amount: float) -> void:
	var lv: Dictionary = def.level
	xp += amount
	while level < int(lv.max) and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		_apply_level()
		mana = max_mana
		game.on_level_up()


func power() -> float:
	return (1.0 + float(def.level.damage) * (level - 1)) * (1.0 + b("damage"))


func alive() -> bool:
	return not dead


func dodging() -> bool:
	return dodge_t > 0.0


func ability(slot: int) -> Dictionary:
	return def.abilities[slot]


func ability_cost(slot: int) -> float:
	return float(ability(slot).get("mana", 0))


func unlocked(slot: int) -> bool:
	return level >= int(ability(slot).get("unlock", 1))


func attack_range() -> float:
	return float(def.attack.range)


func ranged() -> bool:
	return bool(def.attack.get("ranged", false))


# ---------------------------------------------------------------- Stärkungen, Schild, Heilung

func add_buff(id: String, d: Dictionary, time: float) -> void:
	var b := d.duplicate()
	b.until = game.play_time + time
	buffs[id] = b


func has_buff(id: String) -> bool:
	return buffs.has(id) and game.play_time < float(buffs[id].until)


## Faktor auf den eigenen Schaden (Hochdosis).
func out_mult() -> float:
	var m := 1.0
	for b in buffs.values():
		m *= 1.0 + float(b.get("dmg_out", 0.0))
	return m


func speed_mult() -> float:
	var m := 1.0
	for b in buffs.values():
		m *= 1.0 + float(b.get("speed", 0.0))
	return m


func slow_immune() -> bool:
	for b in buffs.values():
		if bool(b.get("slow_immune", false)):
			return true
	return false


## Eingehender Schaden nach Stärkungen und Schild (Rüstung rechnet HdGame vorher).
func incoming(amount: float) -> float:
	for b in buffs.values():
		amount *= 1.0 - float(b.get("dmg_in", 0.0))
	if shield > 0.0 and game.play_time < shield_until:
		var soak := minf(shield, amount)
		shield -= soak
		amount -= soak
	return amount


func add_shield(amount: float, time: float) -> void:
	shield = maxf(shield if game.play_time < shield_until else 0.0, 0.0) + amount
	shield_until = game.play_time + time


func shield_left() -> float:
	return shield if game.play_time < shield_until else 0.0


func heal(amount: float, quiet := false) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var got := minf(amount, max_hp - hp)
	hp += got
	if not quiet and got >= 1.0:
		game.floater(position + Vector3(0, 2.4, 0), "+%d" % roundi(got), UiTheme.HAVE)
	return got


# ---------------------------------------------------------------- Schritt

func step(dt: float, now: float) -> void:
	_anim_step(dt)
	for i in 4:
		cd[i] = maxf(0.0, cd[i] - dt)
	dodge_cd = maxf(0.0, dodge_cd - dt)
	attack_cd -= dt
	for k in buffs.keys():
		if now >= float(buffs[k].until):
			buffs.erase(k)
	_glow.visible = not buffs.is_empty() and not dead
	_kit_step(dt, now)
	if dead:
		respawn_t -= dt
		if respawn_t <= 0.0:
			_respawn()
		return
	hp = minf(max_hp, hp + (float(def.hp_regen) + b("hp_regen")) * dt)
	mana = minf(max_mana, mana + (float(def.mana_regen) + b("mana_regen")) * dt)
	cc.update(now)
	if dodge_t > 0.0:
		dodge_t -= dt
		var dd: Dictionary = def.dodge
		game.move_unit(self, dodge_dir, float(dd.distance) / float(dd.time), dt, true)
		return
	if cc.stunned(now):
		_body.rotation.x = -0.5
		return
	_body.rotation.x = 0.0
	var spd := speed * speed_mult() * (1.0 if slow_immune() else cc.speed_factor(now))
	if move_dir.length_squared() > 0.01:
		order = {}
		game.move_unit(self, move_dir.limit_length(1.0), spd, dt)
		_face(move_dir)
	elif order.get("kind", "") == "move":
		var to: Vector3 = order.point - position
		to.y = 0.0
		if to.length() < 0.3:
			order = {}
		else:
			game.move_unit(self, to.normalized(), minf(spd, to.length() / dt), dt)
			_face(to)
	elif order.get("kind", "") == "attack":
		var e = order.target
		if e == null or not is_instance_valid(e) or not e.alive():
			order = {}
		else:
			var to: Vector3 = e.position - position
			to.y = 0.0
			if to.length() > attack_range() + e.radius + radius:
				game.move_unit(self, to.normalized(), spd, dt)
				_face(to)
			else:
				_try_attack(e)
	# Grundangriff
	if attack_held:
		var aim_dir := aim - position
		aim_dir.y = 0.0
		_face(aim_dir)
		if ranged():
			if attack_cd <= 0.0:
				_ranged_shot(facing, null)
		else:
			var e = game.enemy_in_arc(position, aim_dir, attack_range() + radius, float(def.attack.get("arc", 120)))
			if e:
				_try_attack(e)
	elif auto_attack and order.is_empty() and move_dir.length_squared() < 0.01:
		var e = game.nearest_enemy(position, maxf(4.5, attack_range() if ranged() else 0.0))
		if e:
			order = {"kind": "attack", "target": e}


## Wird jeden Schritt aufgerufen, auch tot (Kit-Zustände, Zeitgeber).
func _kit_step(_dt: float, _now: float) -> void:
	pass


func _face(v: Vector3) -> void:
	v.y = 0.0
	if v.length_squared() > 0.0001:
		facing = v.normalized()
		rotation.y = atan2(facing.x, facing.z) + PI


func _try_attack(e) -> void:
	if attack_cd > 0.0:
		return
	if ranged():
		_face(e.position - position)
		_ranged_shot(facing, e)
		return
	attack_cd = attack_interval()
	_face(e.position - position)
	_swing_fx()
	game.hero_hit(e, float(def.attack.damage) * power(), "attack")
	on_hit(e)


## Fernkampf-Grundangriff in Richtung dir (target = angeklicktes Ziel oder null).
func _ranged_shot(dir: Vector3, target) -> void:
	attack_cd = attack_interval()
	var e = target if target else game.enemy_in_arc(position, dir, attack_range() + radius, 20.0)
	if e:
		game.fx.tracer(position + Vector3(0, 1.2, 0), e.position + Vector3(0, e.height() * 0.6, 0), UiTheme.CYAN)
		game.hero_hit(e, float(def.attack.damage) * power(), "attack")
		on_hit(e)


## Grundangriff hat getroffen (Torvik: Sturmbrandung).
func on_hit(_e) -> void:
	pass


func _swing_fx() -> void:
	if has_model():
		return
	var tw := create_tween()
	tw.tween_property(_body, "rotation:y", -0.5, 0.08)
	tw.tween_property(_body, "rotation:y", 0.0, 0.14)


func _respawn() -> void:
	dead = false
	visible = true
	_dead_t = 0.0
	_play("idle")
	hp = max_hp
	mana = max_mana
	position = game.hero_spawn()
	order = {}
	game.message.emit(tr("%s ist zurück") % tr(str(def.name)))


func die() -> void:
	dead = true
	deaths += 1
	visible = has_model()  # mit Modell erst nach der Sterbe-Animation ausblenden (_anim_step)
	order = {}
	buffs.clear()
	shield = 0.0
	_on_death()
	respawn_t = float(def.respawn.base) + float(def.respawn.per_level) * level
	game.message.emit(tr("%s ist gefallen") % tr(str(def.name)))


func _on_death() -> void:
	pass


# ---------------------------------------------------------------- Fähigkeiten

## Fähigkeit in Richtung/auf den Punkt at wirken. Gibt false zurück, wenn es nicht geht.
func cast(slot: int, at: Vector3) -> bool:
	if dead or dodging() or cc.stunned(game.play_time) or slot < 0 or slot > 3:
		return false
	if cd[slot] > 0.0 or not unlocked(slot) or mana < ability_cost(slot):
		return false
	var a := ability(slot)
	var dir := at - position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = facing
	dir = dir.normalized()
	var cost := ability_cost(slot)
	if not _cast(slot, a, dir, at):
		return false
	_face(dir)
	mana -= cost
	if cd[slot] <= 0.0:
		cd[slot] = float(a.cooldown) * (1.0 - minf(b("cdr"), 0.4))
	return true


## Kit: Fähigkeit ausführen. false = ging nicht (kein Mana/Abklingzeit verbraucht).
func _cast(_slot: int, _a: Dictionary, _dir: Vector3, _at: Vector3) -> bool:
	return false


## Punkt für Ortsfähigkeiten: höchstens range vom Helden entfernt.
func clamp_point(at: Vector3, r: float) -> Vector3:
	var to := at - position
	to.y = 0.0
	if to.length() > r:
		to = to.normalized() * r
	return Vector3(position.x + to.x, 0, position.z + to.z)


func dodge(dir: Vector3) -> bool:
	if dead or dodge_cd > 0.0 or cc.stunned(game.play_time):
		return false
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = facing
	dodge_dir = dir.normalized()
	dodge_t = float(def.dodge.time)
	dodge_cd = float(def.dodge.cooldown)
	order = {}
	dodges += 1
	game.fx.dash_trail(position, dodge_dir * float(def.dodge.distance))
	return true


# ---------------------------------------------------------------- Anzeige und Bot

## Zustandszeilen für die Heldenleiste.
func status_lines() -> Array:
	var st: Array = []
	if shield_left() > 0.0:
		st.append(tr("Schild %d") % roundi(shield_left()))
	return st


## Fähigkeitsfeld golden umranden (z. B. verstärkter Donnerhieb).
func slot_glow(_slot: int) -> bool:
	return false


## Bot: Fähigkeiten gegen das nächste Ziel e einsetzen (to = Richtung, d = Abstand, near = Gegner im
## Umkreis von 5). Gibt den Wunschabstand zum Ziel zurück (Bewegung macht HdGame.bot_turn).
func bot_act(_e, _to: Vector3, _d: float, _near: int) -> float:
	return attack_range()


## Held wird ersetzt oder das Spiel endet: eigene Objekte in der Welt (Banner, Gebäude) entfernen.
func free_kit() -> void:
	pass
