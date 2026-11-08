extends GameSystem
## Spielstand für alle Modi auf game.gd: Einzelspiel und Koop speichern, Autosave nach jeder Welle, Spielstand einer
## beendeten Partie löschen. Lesen/Schreiben und den Stand selbst macht save_game.gd (SaveGame). Haken: save_kind()
## (Modus des Spielstands), save_extra()/load_extra(d) (über SaveGame), save_mode().


## Nach jeder Welle still speichern (Einzelspiel, Lukas 2026-11-03): „Weiterspielen“ im Hub setzt hier fort,
## auch nach einem Absturz. Überschreibt nur den Spielstand dieser Partie. Nicht im Mehrspieler, nicht beim
## Testen aus dem Map-Editor und nicht in Tests/Screenshots (Session.skip_setup).
func autosave() -> bool:
	if not game.setup_done or not game.solo() or game.phase >= game.Phase.GAME_OVER or Session.return_scene != Session.MAIN_MENU or Session.skip_setup:
		return false
	return save_game()


## Partie vorbei: den Spielstand dieser Partie löschen, damit „Weiterspielen“ keine beendete Partie anbietet
## (wie Shopping Maul).
func drop_autosave() -> void:
	if game.solo() and Session.save_id != "" and Session.return_scene == Session.MAIN_MENU:
		SaveGame.remove(Session.save_id)
		Session.save_id = ""


## Einzelspiel speichern; dieselbe Partie überschreibt ihren Spielstand.
func save_game() -> bool:
	var st := SaveGame.capture(game)
	if st.is_empty():
		return false
	if Session.save_id == "":
		Session.save_id = SaveGame.new_id()
	return SaveGame.write({"id": Session.save_id, "kind": "single", "mode": str(hook("save_kind", [], "")), "meta": SaveGame.meta_for(game), "state": st})


## Koop (Host): das gemeinsame Feld mit allen Spielern speichern, Spielernummern bleiben an den Spieler-IDs.
func save_coop() -> bool:
	var st := SaveGame.capture(game)
	if st.is_empty():
		return false
	var names: Array = game.players.map(func(p): return p.name)
	return SaveGame.write({"id": str(Net.session.get("id", SaveGame.new_id())), "kind": "coop", "mode": str(hook("save_kind", [], "")),
		"meta": SaveGame.meta_for(game, {"players": names}), "map": game.map.to_dict(), "host_uid": Net.uid,
		"coop": Net.session.get("coop", []), "state": st})
