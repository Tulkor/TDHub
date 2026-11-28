extends Node
## Lauf: einzeln (Name fxelement)
## Modi: kern
## Elementwahl vor Fähigkeit/Farbe, eigene Angaben und Rückfall aller Tower-Modi.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _ready() -> void:
	Sfx.audible = false
	for row in [["eeve_rock_launcher", "stone_dust", "thud"], ["eeve_lightning_generator", "kb_shock_ring", "shot_zap"], ["eeve_geyser", "kb_splash", "shot_blip"], ["eeve_acid_fountain", "acid_cloud", "shot_blip"]]:
		var def: Dictionary = Database.towers[row[0]]
		var fx := FxData.for_tower(row[0])
		check(fx.hit.id == def.get("hit_fx", row[1]), "%s: Treffer/Override" % row[0])
		check(Sfx.shot_for(row[0], 0).sound == row[2], "%s: Sound" % row[0])
	check(FxData.for_tower("eeve_lightning_generator").shot.id == "chain_lightning", "Blitzbogen")
	Database.towers["__fx_probe"] = {"color": "#ff2200", "element": "eis", "shot_fx": "magic_beam", "hit_fx": "white_slash", "shot_sfx": "thud@0.7", "abilities": [{"type": "splash"}]}
	check(FxData.for_tower("__fx_probe").shot.id == "magic_beam", "Eigener Schuss vor Element")
	check(FxData.for_tower("__fx_probe").hit.id == "white_slash", "Eigener Treffer vor Element")
	check(is_equal_approx(Sfx.shot_for("__fx_probe", 0).pitch, 0.7), "Eigener Sound vor Element")
	Database.towers["__fx_probe"] = {"color": "#ff2200", "element": "wasser", "abilities": [{"type": "splash"}]}
	FxData.clear_cache()
	check(FxData.for_tower("__fx_probe").shot.id == "water_jet", "Element vor Splash/Farbe")
	check(FxData.for_tower("__fx_probe").hit.id == "kb_splash", "Element-Splash")
	Database.towers["__fx_probe"] = {"color": "#ff2200"}
	FxData.clear_cache()
	check(FxData.for_tower("__fx_probe").shot.id == FxData._auto_shot([], Color("ff2200")), "Alte Farbwahl ohne Element")
	Database.towers["__fx_probe"]["abilities"] = [{"type": "chain"}]
	FxData.clear_cache()
	check(FxData.for_tower("__fx_probe").shot.id == "chain_lightning", "Kettenfähigkeit vor Farbe")
	check(Sfx.shot_for("__fx_probe", 0).sound == "shot_zap", "Kettensound")
	Database.towers.erase("__fx_probe")
	FxData.clear_cache()
	for element in FxData._elements:
		var e: Dictionary = FxData._elements[element]
		check(FxData.shots().has(e.shot) and FxData.hits().has(e.hit) and FxData.hits().has(e.splash), "%s: gültige Effekt-IDs" % element)
		check(Sfx._data.sounds.has(e.sound.sound), "%s: gültiger Sound" % element)
	for id in Database.towers:
		if Database.towers[id].has("element"):
			check(not FxData.element_for(Database.towers[id]).is_empty(), "%s: gültiges Element" % id)
	for id in YoutdData.towers():
		var def := YoutdTower.fx_def("youtd_" + id)
		check(not FxData.element_for(def).is_empty(), "YouTD %s: Element übertragen" % id)
		if def.get("lightning", false):
			check(FxData.for_tower("youtd_" + id).shot.id == "chain_lightning", "YouTD %s: Blitzflag" % id)
	print("FERTIG: %d Fehler" % failures)
	get_tree().quit(1 if failures else 0)
