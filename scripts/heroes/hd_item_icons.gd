extends RefCounted
## Vorhandene CC0-Modellrenders; der Bollwerk-Inventarrahmen liefert die gotische Einfassung.
const ICONS := {
	"heiltrank":"kk_dungeon_bottle_b_brown_gltf", "manatrank":"kk_dungeon_bottle_c_green_gltf",
	"heimkehr":"kk_halloween_lantern_standing", "schutzrolle":"q_fantasy_props_scroll_1",
	"eisenklinge":"kk_abenteurer_sword_2handed_color", "holzschild":"kk_abenteurer_shield_round_color",
	"kraftring":"nature_statue_ring", "lehrlingsstab":"kk_abenteurer_wand",
	"lederstiefel":"bollwerk_lederstiefel", "wetzstein":"kristall_8fd8ff_crystal_13",
	"lebensstein":"kristall_c9a8ff_crystal_20", "glutkern":"nature_campfire_bricks",
	"brecherklinge":"kk_abenteurer_axe_2handed", "turmschild":"kk_abenteurer_shield_spikes_color",
	"windlaeufer":"bollwerk_lederstiefel", "weisenstab":"kk_abenteurer_staff",
	"blutdorn":"kk_abenteurer_dagger", "schmiedesonne":"nature_campfire_pit",
	"bollwerkplatte":"kk_abenteurer_shield_spikes_color", "sturmschwinge":"bollwerk_lederstiefel",
	"erzmagierstab":"kk_abenteurer_spellbook_closed", "vampirklinge":"kk_abenteurer_dagger",
	"festungsherz":"kristall_5aa8ff_crystal_24", "morgenwacht":"kk_abenteurer_sword_2handed_color",
	"moorkrone":"kk_halloween_skull_candle", "gruftsiegel":"kk_halloween_skull",
	"glutherz":"nature_campfire_stones", "kriegsherrenklinge":"kk_abenteurer_sword_2handed_color",
	"arenagurt":"kk_gemischt_chain_shackle", "siegerkranz":"kk_gemischt_idol_a"
}

static func texture(id: String) -> Texture2D:
	if not ICONS.has(id):return null
	var extension := "svg" if str(ICONS[id]).begins_with("bollwerk_") else "png"
	return load("res://assets/youtd/icons/%s.%s" % [ICONS[id],extension])
