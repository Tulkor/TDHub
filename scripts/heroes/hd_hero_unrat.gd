class_name HdHeroUnrat
extends HdHero
## König Unrat, Rattenkönig (Wall, hero-defense-helden.md Nr. 14). Vorbild Rat King (Deadlock):
## Schrottbombe (3 Explosionen am Ort), Rattenschwarm (Ratten beißen, senken Rüstung, danach
## Rattenseuche), Königsgewand (Schild + Geschosse zurückwerfen), Rattenbanner (Zone, am Ende
## Ausbruch). Ratten und Seuche rechnet HdEnemy (add_rats/step_debuffs), das Überspringen HdGame.

const RAT := Color("9ac23a")

var bombs: Array = []        ## {pos, next, left, tele}
var banner: Dictionary = {}  ## {pos, until, tele, pole}
var robe_until := 0.0


func _build_body() -> void:
	var cloak := HdDev.mat(Color("6b5a3a"), 0.5)
	_body.add_child(HdDev.cyl(0.6, 0.95, 1.3, cloak, Vector3(0, 0.65, 0), 10))
	_body.add_child(HdDev.sphere(0.62, HdDev.mat(Color("8a7a5a"), 0.5), Vector3(0, 1.45, 0)))
	_body.add_child(HdDev.sphere(0.34, HdDev.mat(Color("c8b090"), 0.5), Vector3(0, 2.05, 0)))
	_body.add_child(HdDev.cyl(0.3, 0.26, 0.28, HdDev.mat(Color("a8a8b0"), 0.5, 0.4), Vector3(0, 2.4, 0), 6))
	for k in 5:
		var a := k * TAU / 5.0
		_body.add_child(HdDev.sphere(0.13, HdDev.mat(Color("5a5048"), 0.5), Vector3(cos(a) * 0.75, 0.9 + 0.2 * (k % 2), sin(a) * 0.75)))
	_body.add_child(HdDev.box(Vector3(0.12, 1.4, 0.12), HdDev.mat(Color("7a6a50"), 0.5), Vector3(0.9, 1.0, -0.2)))


func reflect_chance() -> float:
	if game.play_time < robe_until and shield_left() > 0.0:
		return float(ability(2).reflect)
	return 0.0


func _cast(slot: int, a: Dictionary, dir: Vector3, at: Vector3) -> bool:
	var pw := power()
	match slot:
		0:
			var p := clamp_point(at, float(a.range))
			var t := HdTelegraph.circle(float(a.radius), HdTelegraph.BLUE)
			t.position = Vector3(p.x, 0.05, p.z)
			game.add_child(t)
			game.fx.tracer(position + Vector3(0, 1.8, 0), p + Vector3(0, 0.3, 0), Color("a8a8b0"))
			bombs.append({"pos": p, "next": game.play_time + float(a.flight), "left": int(a.blasts), "tele": t, "pw": pw})
		1:
			var hits: Array = game.enemies_in(HdTelegraph.CIRCLE, position, dir, float(a.radius), 0, 0, 0, 0)
			if hits.is_empty():
				return false
			hits.sort_custom(func(x, y): return x.position.distance_to(position) < y.position.distance_to(position))
			_swarm(hits, int(a.rats), a, pw)
			game.fx.nova(position, float(a.radius), RAT)
		2:
			add_shield(max_hp * float(a.shield), float(a.time))
			robe_until = game.play_time + float(a.time)
			game.fx.nova(position, 1.6, UiTheme.GOLD)
		3:
			_end_banner(false)
			var p := clamp_point(at, float(a.range))
			var t := HdTelegraph.circle(float(a.radius), HdTelegraph.BLUE)
			t.position = Vector3(p.x, 0.04, p.z)
			game.add_child(t)
			var pole := Node3D.new()
			pole.position = p
			pole.add_child(HdDev.box(Vector3(0.18, 3.2, 0.18), HdDev.mat(Color("5a3a22"), 0.5), Vector3(0, 1.6, 0)))
			pole.add_child(HdDev.box(Vector3(1.3, 0.9, 0.06), HdDev.mat(RAT, 0.5, 0.6), Vector3(0.7, 2.6, 0)))
			game.add_child(pole)
			banner = {"pos": p, "until": game.play_time + float(a.duration), "tele": t, "pole": pole, "pw": pw}
	return true


## Ratten verteilen: nächste Gegner zuerst, höchstens per_target je Ziel.
func _swarm(hits: Array, total: int, a: Dictionary, pw: float) -> void:
	var left := total
	for e in hits:
		if left <= 0:
			break
		var n := mini(int(a.per_target), left)
		e.add_rats(n, int(a.per_target), float(a.duration), float(a.bite) * pw, float(a.armor), a.plague)
		left -= n
		game.fx.bolt(position + Vector3(0, 1.0, 0), e.position + Vector3(0, 0.5, 0), RAT)


func _kit_step(_dt: float, now: float) -> void:
	for i in range(bombs.size() - 1, -1, -1):
		var b: Dictionary = bombs[i]
		var a := ability(0)
		var t: HdTelegraph = b.tele
		if is_instance_valid(t):
			t.progress = clampf(1.0 - (float(b.next) - now) / float(a.blast_gap), 0.0, 1.0)
		if now < float(b.next):
			continue
		game.fx.nova(b.pos, float(a.radius), Color("e0a050"))
		for e in game.enemies_in(HdTelegraph.CIRCLE, b.pos, Vector3.FORWARD, float(a.radius), 0, 0, 0, 0):
			game.hero_hit(e, float(a.damage) * float(b.pw), "q")
			if not e.dead:
				e.cc.slow("schrottbombe", float(a.slow), float(a.slow_time), now)
		b.left -= 1
		b.next = now + float(a.blast_gap)
		if b.left <= 0:
			if is_instance_valid(t):
				t.trigger(0.2)
			bombs.remove_at(i)
	if banner.is_empty():
		return
	var ba := ability(3)
	var bt: HdTelegraph = banner.tele
	var left := float(banner.until) - now
	bt.progress = clampf(1.0 - left / float(ba.duration), 0.0, 1.0)
	if alive() and Vector2(position.x - banner.pos.x, position.z - banner.pos.z).length() <= float(ba.radius):
		add_buff("rattenbanner", {"speed": float(ba.speed), "dmg_in": float(ba.dmg_in), "slow_immune": true}, 0.25)
	if left <= 0.0:
		_end_banner(true)


## Banner endet: mit Ausbruch (Zeit um) oder ohne (neues Banner, Held ersetzt).
func _end_banner(burst: bool) -> void:
	if banner.is_empty():
		return
	var ba := ability(3)
	if burst:
		var hits: Array = game.enemies_in(HdTelegraph.CIRCLE, banner.pos, Vector3.FORWARD, float(ba.radius), 0, 0, 0, 0)
		game.fx.nova(banner.pos, float(ba.radius), RAT)
		for e in hits:
			game.hero_hit(e, float(ba.damage) * float(banner.pw), "r")
			if e.dead:
				continue
			game.stun(e, float(ba.stun))
			e.cc.slow("rattenbanner", float(ba.slow), float(ba.slow_time), game.play_time)
		var sw := ability(1)
		for e in hits:
			if not e.dead:
				e.add_rats(int(sw.per_target), int(sw.per_target), float(sw.duration), float(sw.bite) * float(banner.pw), float(sw.armor), sw.plague)
	if is_instance_valid(banner.tele):
		banner.tele.trigger(0.3)
	if is_instance_valid(banner.pole):
		banner.pole.queue_free()
	banner = {}


func free_kit() -> void:
	_end_banner(false)
	for b in bombs:
		if is_instance_valid(b.tele):
			b.tele.queue_free()
	bombs.clear()


func status_lines() -> Array:
	var st := super.status_lines()
	if not banner.is_empty():
		st.append(tr("Rattenbanner %d s") % ceili(float(banner.until) - game.play_time))
	if reflect_chance() > 0.0:
		st.append(tr("Königsgewand"))
	return st


func bot_act(e, _to: Vector3, d: float, near: int) -> float:
	if d < 11.0:
		cast(0, e.position)
	if near >= 2 or e.rank != "normal":
		cast(1, e.position)
	if hp < max_hp * 0.7 and near >= 1:
		cast(2, e.position)
	if near >= 3 and unlocked(3):
		cast(3, position)
	return attack_range()
