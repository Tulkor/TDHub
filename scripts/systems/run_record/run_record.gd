extends GameSystem
## Run-Ende ins Spielerprofil (profile.gd): gewonnen/verloren mit allen Statistiken, Abbruch mitten im Run,
## Debug-Runs (geben keine EP) und die schon gebuchte Spielzeit. Gleich für alle Modi; was ein Modus
## zusätzlich speichert, kommt über Haken:
##   profile_mode() -> String   Profil-Schlüssel (sonst cfg.profile)
##   profile_extra() -> Dict    zusätzliche Werte für den Run (Elemente, Rasse, Boni …)
##   debug_run() -> bool        Debug-Hilfe benutzt? (sonst game.debug)
## Felder am Spiel, falls vorhanden: play_time (Sekunden), profile_time (schon gebucht), ascension_unlocked,
## _saves_at_start (für „gespeichert“ beim Abbruch).
## Basiswerte run_record.json: abort_min_seconds (kürzere Abbrüche zählen nicht).


## Profil-Schlüssel des Modus (Haken profile_mode, sonst cfg.profile).
func mode_key() -> String:
	return str(hook("profile_mode", [], cfg.get("profile", "")))


## Debug-Run? Dann gibt der Run keine EP und zählt nicht für Bestwerte.
func is_debug() -> bool:
	return bool(hook("debug_run", [], game.get("debug") == true))


## Run ist zu Ende: info (Kurzinfo wie in der Run-History) plus profile_extra, darüber fixed (gewinnt),
## stats für die Tower-Statistik. Gibt die Neuigkeiten des Profils zurück (Level-Aufstieg, Freischaltungen).
func finish(info: Dictionary, stats: Dictionary, fixed: Dictionary = {}) -> Dictionary:
	var row := _row(info, fixed)
	var news: Dictionary = Profile.record_run(mode_key(), row, stats)
	if "ascension_unlocked" in game:
		game.ascension_unlocked = int(news.get("ascension_unlocked", 0))
	return news


## Run abgebrochen (Spiel verlassen, Fenster zu): nur die Zeit zählt, ohne Wertung. Kürzer als
## abort_min_seconds seit der letzten Buchung: nichts. Gibt zurück, ob gebucht wurde.
func abort(info: Dictionary, fixed: Dictionary = {}) -> bool:
	if "play_time" in game and "profile_time" in game \
			and roundi(game.play_time) - int(game.profile_time) < int(cfg.get("abort_min_seconds", 10)):
		return false
	var row := _row(info, fixed)
	if "_saves_at_start" in game:
		row.saved = SaveGame.writes > int(game._saves_at_start)
	Profile.record_abort(mode_key(), row)
	return true


func _row(info: Dictionary, fixed: Dictionary) -> Dictionary:
	var row := info.duplicate()
	row.debug = is_debug()
	if "profile_time" in game:
		row.time_counted = game.profile_time
	row.merge(hook("profile_extra", [], {}), true)
	row.merge(fixed, true)
	if "profile_time" in game and "play_time" in game:
		game.profile_time = roundi(game.play_time)  # Zeit bis hier ist gebucht
	return row
