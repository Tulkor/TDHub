extends RefCounted
## Originale SVG-Silhouetten: Wirkungssymbol und erkennbare Aktions-/Schutzdetails.
const DIRECTORY := "res://assets/heroes/ability_icons/"
static var _textures := {}

static func key(hero_id: String, ability: Dictionary, slot: int) -> String:
	if slot==4:return "dodge"
	if ability.has("gadget"):return "gadget_"+str(ability.gadget)
	return str(ability.get("id",hero_id+"_"+str(slot)))

static func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := DIRECTORY+id+".svg"
		if not ResourceLoader.exists(path):
			push_error("Fehlendes Fähigkeitssymbol: "+id)
			return null
		_textures[id]=load(path)
	return _textures[id]
