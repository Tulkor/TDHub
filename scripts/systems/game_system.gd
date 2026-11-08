class_name GameSystem
extends Node
## Grundlage aller modusunabhängigen Spielsysteme unter scripts/systems/<name>/<name>.gd.
## Ein System kennt keinen Modus: keine eeve_/rg_/youtd/maul/hd_/sv_-Namen und kein Session.game_kind.
## Was je Modus anders ist, kommt als cfg (Feld "system_cfg" des Modus in data/modes.json) oder über Haken,
## die das Spiel anbietet: hook("name", args) ruft game.<name>(args …) auf, wenn das Spiel die Funktion hat.
## Angelegt werden Systeme von SystemHost aus der Liste "systems" des Modus (tools/systeme.py neu <name>).

## Das Spiel, zu dem das System gehört (game.gd, maul_game.gd, hd_game.gd, sv_game.gd …).
var game: Node
## Einstellungen des Modus für dieses System (modes.json → system_cfg.<name>), leer = Standard.
var cfg: Dictionary = {}


## Von SystemHost aufgerufen, bevor das System in den Baum kommt.
func setup(owner_game: Node, config: Dictionary) -> void:
	game = owner_game
	cfg = config


## Haken ins Spiel: ruft game.<method>(args) auf, wenn es die Funktion gibt, sonst fallback.
func hook(method: String, args: Array = [], fallback: Variant = null) -> Variant:
	if game != null and game.has_method(method):
		return game.callv(method, args)
	return fallback
