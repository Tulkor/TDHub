extends GameSystem
## Eingabe und Tempo für alle Modi mit Baufeld. Werte (Basis controls.json, Modus in system_cfg.controls):
## box_select, speeds. Was ein Klick, das Hovern und die Auswahl im Modus bedeuten, bleibt Haken des Modus
## (_on_click, _update_hover, _select, _box_select); Pause hängt am HUD des Modus.


## Spannt Ziehen mit der linken Maustaste einen Auswahlrahmen auf?
func box_select() -> bool:
	return bool(cfg.get("box_select", true))


## Spieltempo setzen (Befehl speed, im Koop rechnet der Host für alle). Nur Werte aus speeds; im Einzelspiel bleibt
## es für den nächsten Start gemerkt.
func set_speed(f: float) -> bool:
	if not Array(cfg.get("speeds", [1.0, 2.0, 4.0])).any(func(s): return is_equal_approx(float(s), f)):
		return false
	Engine.time_scale = f
	if game.solo():
		Session.speed = f
	return true
