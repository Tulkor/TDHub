extends GameSystem
## Wellenablauf für alle Modi: Spawn-Warteschlange mit Abständen (auch mehrere Bahnen/Spawner nebeneinander)
## und „Auto“ (nächste Welle von selbst, Taste N). Was in einer Welle kommt und wie ein Gegner entsteht,
## bleibt beim Modus (Wellen-Daten, Haken). Werte (Basis waves.json, Modus in system_cfg):
##   auto.enabled     Gibt es Pausen zwischen den Wellen, die man abkürzen kann (Auto-Knopf, N)?
##   auto.command     Befehl für „nächste Welle jetzt“ (game.submit({"type": …}))
##   auto.due         wann Auto startet: "build_after_first" = in der Bauphase (auto.build_phase) ab Welle 2,
##                    "" = Haken auto_wave_rule() des Modus


## Spawner abarbeiten: solange sein Timer abgelaufen ist, den nächsten Eintrag spawnen (spawn.call(entry)
## gibt die neu entstandenen Gegner zurück) und den nächsten Abstand (interval.call(entry)) addieren.
## Gegner, die schon vor Bildende fällig waren, laufen die verspätete Zeit nach (catch_up), damit die
## Abstände nicht vom Bildraster abhängen. Gibt den neuen Timer zurück; queue wird verbraucht.
func drain(queue: Array, timer: float, delta: float, spawn: Callable, interval: Callable, catch_up := true) -> float:
	timer -= delta
	while timer <= 0.0 and not queue.is_empty():
		var entry = queue.pop_front()
		var made = spawn.call(entry)
		var late := -timer
		if catch_up and late > 0.0 and made is Array:
			for e in made:
				e._process(late)
		timer += float(interval.call(entry))
	return timer


## Hat der Modus Pausen zwischen den Wellen, die man abkürzen kann?
func has_auto() -> bool:
	return bool(cfg.get("auto", {}).get("enabled", false))


## Soll die nächste Welle jetzt von selbst starten (Auto an)?
func auto_due() -> bool:
	var auto: Dictionary = cfg.get("auto", {})
	match str(auto.get("due", "")):
		"build_after_first":
			return int(game.phase) == int(auto.get("build_phase", 0)) and int(game.wave_index) > 0
	return bool(hook("auto_wave_rule", [], false))


## Nächste Welle sofort (wie Taste N).
func next_now() -> void:
	var cmd := str(cfg.get("auto", {}).get("command", ""))
	if cmd != "":
		game.submit({"type": cmd})
