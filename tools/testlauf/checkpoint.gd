extends Node
## Checkpoints für Testläufe: ein Bot spielt bis Welle N und legt dort einen Spielstand ab; spätere Läufe starten
## direkt aus diesem Stand (--checkpoint=datei) und testen nur noch die Wellen ab N, z. B. mit anderer Spielstärke.
## Speichern: --cp_welle=N --cp_datei=pfad (der Lauf spielt danach normal weiter). Stand = derselbe wie im Spiel
## (SaveGame.capture, Shopping Maul MaulSave.capture), dazu Modus, Welle, Schwierigkeit und Aufstieg; unverschlüsselt
## mit store_var, damit Vektoren und Ganzzahlen erhalten bleiben. Laden: laden(pfad) vor bot.start (Session.load_state).

var ziel: Node  ## der Bot; gelesen wird ziel.game
var welle := 0  ## 1-basiert: Stand vor dieser Welle
var datei := ""
var meta := {}
var fertig := false


func _process(_delta: float) -> void:
	if fertig or welle <= 0:
		return
	var game = ziel.get("game") if is_instance_valid(ziel) else null
	if game == null or not is_instance_valid(game):
		return
	if game is MaulGame:
		if game.phase == MaulGame.Phase.SETUP:
			return
	elif not game.get("setup_done"):
		return
	var w := welle_index(game)
	if w > welle - 1:
		fertig = true
		push_warning("Checkpoint: Welle %d schon vorbei, kein Stand" % welle)
		return
	if w < welle - 1 or not ruhig(game):
		return
	var st := zustand(game)
	if st.is_empty():
		return
	fertig = true
	var data := meta.duplicate()
	data.welle = welle
	data.state = st
	var f := FileAccess.open(datei, FileAccess.WRITE)
	if f == null:
		push_error("Checkpoint: %s nicht schreibbar" % datei)
		return
	f.store_var(data)
	f.close()
	print("CHECKPOINT Welle %d -> %s" % [welle, datei])


## Index der laufenden oder als Nächstes kommenden Welle (0-basiert), wie messung.gd.
static func welle_index(game) -> int:
	if "wave_index" in game:
		return int(game.wave_index)
	if "level" in game:
		return int(game.level) - 1
	return -1


## Darf jetzt gespeichert werden? Gespeichert wird beim ersten Blick auf Welle N: in Modi mit Bauphase meist in
## der Bauphase davor; GemTD-Bots bauen und starten oft im selben Bild, dann ist es der Anfang der Welle (SaveGame
## kann auch mitten in der Welle speichern). Shopping Maul liefert in der Welle den Stand von ihrem Beginn.
static func ruhig(game) -> bool:
	if game is MaulGame:
		return true
	return game.phase < game.Phase.GAME_OVER


static func zustand(game) -> Dictionary:
	if game is MaulGame:
		return MaulSave.capture(game)
	return SaveGame.capture(game)


## Checkpoint lesen und für das nächste Spiel vormerken (Session.load_state, Karte). Leer, wenn die Datei fehlt.
static func laden(pfad: String) -> Dictionary:
	var f := FileAccess.open(pfad, FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	if not data is Dictionary or not data.has("state"):
		return {}
	var st: Dictionary = data.state
	Session.load_state = st
	Session.map_override = MapData.from_dict(st.map) if st.has("map") and st.map is Dictionary else null
	return data
