class_name HdRosterConstruct
extends HdBuilding
## Besitzergebundene Wölfe, Trugbilder, Grabhelfer, Geschütze und zerstörbare Wände.
var owner_hero: HdHero
var until_time := 0.0
var walk_phase := 0.0


func setup_construct(g, d: Dictionary, at: Vector3, actor: HdHero) -> void:
	game = g
	def = d
	position = at
	owner_hero = actor
	max_hp = float(d.hp)
	hp = max_hp
	armor = float(d.armor)
	radius = float(d.radius)
	gate_kind = "roster"
	until_time = game.play_time + float(d.duration)
	_build()


func _build() -> void:
	var col := Color(str(def.color))
	var metal := HdDev.mat(Color("4d5868"), .45, .7)
	var trim := HdDev.mat(Color("bd9b5c"), .4, .65)
	var glow := HdDev.mat(col, .4, 1.8)
	var pet := str(def.pet)
	if pet == "wall":
		for s in [-1, 1]:
			add_child(HdDev.box(Vector3(.18, 2.7, .4), metal, Vector3(s * .65, 1.35, 0)))
		add_child(HdDev.box(Vector3(1.5, 2.1, .3), metal, Vector3(0, 1.05, 0)))
		add_child(HdDev.box(Vector3(1.3, .12, .36), trim, Vector3(0, 2.05, 0)))
		add_child(HdDev.box(Vector3(.12, 1.8, .38), glow, Vector3(0, 1.2, 0)))
	elif pet == "wolf":
		var fur := HdDev.mat(Color("737e88"), .9)
		add_child(HdDev.sphere(.65, fur, Vector3(0, .85, 0)))
		add_child(HdDev.sphere(.35, fur, Vector3(0, 1.15, -.65)))
		add_child(HdDev.box(Vector3(.28, .24, .5), fur, Vector3(0, 1.05, -.96)))
		for s in [-1, 1]:
			add_child(HdDev.cyl(0, .14, .4, fur, Vector3(s * .22, 1.5, -.55), 5))
			add_child(HdDev.sphere(.055, glow, Vector3(s * .2, 1.22, -.92)))
			for z in [-.4, .4]:
				var leg := HdDev.box(Vector3(.17, .65, .19), fur, Vector3(s * .4, .33, z))
				leg.set_meta("leg", s * (1 if z < 0 else -1))
				add_child(leg)
	elif pet in ["mirror", "skeleton"]:
		var body := glow if pet == "mirror" else HdDev.mat(Color("c8c5ae"), .85)
		for s in [-1, 1]:
			add_child(HdDev.cyl(.1, .13, .8, body, Vector3(s * .2, .45, 0), 6))
			add_child(HdDev.cyl(.09, .12, .7, body, Vector3(s * .45, 1.0, 0), 6))
		for k in 4:
			add_child(HdDev.box(Vector3(.65 - k * .07, .1, .35), body, Vector3(0, 1.35 - k * .13, 0)))
		add_child(HdDev.sphere(.25, body, Vector3(0, 1.8, 0)))
		add_child(HdDev.box(Vector3(.1, .1, 1.2), trim, Vector3(.6, 1, -.4)))
	else:
		add_child(HdDev.cyl(.6, .45, .4, metal, Vector3(0, .2, 0), 8))
		add_child(HdDev.cyl(.17, .24, 1, trim, Vector3(0, .85, 0), 8))
		add_child(HdDev.box(Vector3(1.5, .14, .18), metal, Vector3(0, 1.4, 0)))
		add_child(HdDev.box(Vector3(.35 if pet == "mortar" else .12, .3, 1.4), metal, Vector3(0, 1.5, -.4)))
		add_child(HdDev.sphere(.15, glow, Vector3(0, 1.5, -1.1)))


func label() -> String:
	return tr(str(def.name))


func height() -> float:
	return 2.7 if str(def.pet) == "wall" else 1.9


func blocks(at: Vector3) -> bool:
	return alive() and str(def.pet) == "wall" and at.distance_to(position) < radius + .4


func step(dt: float) -> void:
	if not alive(): return
	if game.play_time >= until_time or not is_instance_valid(owner_hero) or not owner_hero.alive():
		retire()
		return
	if bool(def.mobile):
		var e = game.nearest_enemy(position, 12)
		var to: Vector3 = (e.position if e else owner_hero.position) - position
		if to.length() > (2.2 if e else 4.0):
			game.move_unit(self, to.normalized(), 6, dt)
			rotation.y = atan2(-to.x, -to.z)
			walk_phase += dt * 10
			for part in get_children():
				if part.has_meta("leg"):
					part.rotation.x = sin(walk_phase) * .45 * float(part.get_meta("leg"))
		if str(def.pet) == "mirror":
			for foe in game.enemies_in(HdTelegraph.CIRCLE, position, Vector3.FORWARD, 4, 0, 0, 0, 0):
				foe.taunt(self, .3)
	if str(def.pet) == "wall": return
	cd -= dt
	if cd > 0: return
	var target = game.nearest_enemy(position, float(def.range))
	if target == null: return
	var accelerated: bool = owner_hero.def.get("passive_kind", "") == "workbench" and position.distance_to(owner_hero.position) <= 8
	cd = float(def.interval) / (1.25 if accelerated else 1.0)
	var hit := func():
		if float(def.blast) > 0:
			for e in game.enemies_in(HdTelegraph.CIRCLE, target.position, Vector3.FORWARD, float(def.blast), 0, 0, 0, 0):
				game.hero_hit(e, float(def.damage), "physical")
		else:
			game.hero_hit(target, float(def.damage), "physical")
	game.call_as_hero(owner_hero, hit)
	game.fx.tracer(position + Vector3.UP, target.position + Vector3.UP, Color(str(def.color)))


func retire() -> void:
	destroyed = true
	game.buildings.erase(self)
	queue_free()


func destroy() -> void:
	retire()
