class_name MaulEnemy
extends Enemy
## Gegner in Shopping Maul ("die Gewerbeaufsicht"). Läuft eine Route aus mehreren Abschnitten;
## zwischen zwei Abschnitten wird teleportiert (maul_game.gd → on_enemy_leaked).
## Schaden nach der Maul-Tabelle (rules.json → damage_table), Zauber ignorieren die Rüstung.
## spell_factor (aus Enemy): Zauberschaden, Geist mehr, Zauberresistenz weniger.

var route := ""            ## Name der Route (map.json → maul.routes)
var legs: Array = []       ## Abschnitte: je eine Liste von Wegpunkt-Feldern
var leg := 0               ## aktueller Abschnitt
var chose := false         ## Abzweigung (links/rechts) schon gewählt
var waypoint_at: Array = []  ## Index im Pfad, an dem der jeweilige Wegpunkt des Abschnitts erreicht ist
var ghost := false         ## ignoriert das Maze (Speziallevel Geist)
var invisible := false     ## nur angreifbar, wo jemand enttarnt
var frost := false         ## Frost-Aura: Tower in der Nähe greifen langsamer an
var leak_cost := 1         ## Teamleben, wenn er durchkommt
var detected_until := 0.0  ## Spielzeit, bis zu der er sichtbar ist
var leg_from := 0.0        ## zurückgelegte Strecke beim Betreten des aktuellen Abschnitts
var net_bar := false       ## Koop-Mitspieler: Lebensbalken laut Host sichtbar


func take_damage(amount: float, damage_type := "") -> float:
	if damage_type == "spells":
		return take_spell_damage(amount)
	var a := effective_armor()
	var factor := MaulData.damage_factor(damage_type, armor_type)
	if a > 0.0:
		factor *= 1.0 - 0.06 * a / (1.0 + 0.06 * a)
	elif a < 0.0:
		factor *= 2.0 - pow(0.94, -a)
	return take_raw_damage(amount * factor)


## Zauber: keine Rüstung, Helden (Bosse) nehmen weniger, Geister mehr.
func take_spell_damage(amount: float) -> float:
	var f := spell_factor
	if armor_type == "hero":
		f *= float(MaulData.rules().get("spell_hero_factor", 0.7))
	return take_raw_damage(amount * f)


## Lebensbalken erst im letzten Abschnitt der Route; Koop-Mitspieler übernehmen die Entscheidung des Hosts.
func bar_visible() -> bool:
	if game != null and game.mirror:
		return net_bar
	return super.bar_visible()


func route_progress() -> float:
	if leg < legs.size() - 1:
		return 0.0
	if not chose and game != null and not (game.map.maul.routes[route].get("choices", []) as Array).is_empty():
		return 0.0
	if path_len < 0.0:
		path_len = 0.0
		for i in range(1, path.size()):
			path_len += path[i - 1].distance_to(path[i])
	return (traveled - leg_from) / path_len if path_len > 0.0 else 0.0


func status_visible() -> bool:
	return not invisible or game == null or game.is_detected(self)


func _update_visual() -> void:
	super._update_visual()
	if invisible:
		_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_body_mat.albedo_color.a = 0.35 if game == null or not game.is_detected(self) else 0.8
	if ghost:
		_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_body_mat.albedo_color = _body_mat.albedo_color.lerp(Color("b38cff"), 0.4)
		_body_mat.albedo_color.a = minf(_body_mat.albedo_color.a, 0.6)


## Koop-Mitspieler: der Gegner läuft nur beim Host, hier gleitet er zur gemeldeten Stelle (maul_sync.gd).
var net_pos := Vector2.ZERO


func _process(delta: float) -> void:
	if game == null or not game.mirror:
		# Winter (Teampunkt): nur das Lauftempo sinkt, Gift und Verlangsamung laufen normal ab
		var base := speed
		if game != null:
			speed *= game.winter_factor()
		super._process(delta)
		speed = base
		return
	pos = net_pos if pos.distance_to(net_pos) > 3.0 else pos.lerp(net_pos, clampf(delta * 12.0, 0.0, 1.0))
	_sync_position()
	_update_visual()
