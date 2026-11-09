class_name BezirkUeberwuchert
extends Node3D
## Bezirk „Überwuchert“: verlassener Hinterhof aus geraden Backsteinmauern, auf denen Pilzkolonien wuchern
## (blasse creme- bis rosafarbene Pilze mit lindgelb glühenden Hüten, moosgrün leuchtende Sporenflecken),
## dazu glühende Fenster, Runen und ein paar Grabsteine als Ergänzung. Teile aus tools/modelle/pilz_bau.py.
## Eine Map wählt den Bezirk über ihr Feld "district" (MapData.district), Bollwerk über arena.district.
## Rein optisch, fester Zufallsstartwert: bei jedem Spieler gleich, nichts davon geht über das Netz.

const ID := "ueberwuchert"
const DIR := "res://assets/models/bezirke/ueberwuchert/%s.glb"
const GRAVE := "res://assets/models/scenery/%s.glb"
const TEILE := ["pilz_einzel", "pilz_bueschel", "pilz_wand", "pilz_wand_fenster", "pilz_mauerecke", "pilz_kiste",
	"pilz_haus", "runenstein"]
## Fester Aufbau des Hofs: [Teil, x, z, Drehung in Grad]. Lokal: Vorderseite zur Karte ist +Z, der Hof reicht von
## z = 0 (offene Seite zur Karte) bis z = -TIEFE, x von -BREITE/2 bis BREITE/2. Teile schauen ohne Drehung nach +Z.
const BREITE := 12.0
const TIEFE := 9.0
const AUFBAU := [
	["pilz_haus", -3.0, -7.0, 0.0],
	["pilz_wand_fenster", 0.6, -8.2, 0.0],
	["pilz_haus", 3.9, -6.8, -8.0],
	["pilz_mauerecke", -4.6, -4.7, 90.0],
	["pilz_wand", -5.9, -2.4, 90.0],
	["pilz_wand_fenster", 5.8, -3.6, -90.0],
	["pilz_kiste", -2.1, -3.9, 18.0],
	["pilz_kiste", 3.0, -3.1, -30.0],
	["pilz_kiste", 3.8, -4.1, 10.0],
	["runenstein", 0.4, -5.2, 0.0],
	["pilz_bueschel", -0.9, -2.5, 0.0],
	["pilz_bueschel", 1.6, -1.2, 120.0],
	["pilz_bueschel", -4.4, -0.8, 60.0],
	["pilz_bueschel", 4.8, -1.0, 200.0],
	["pilz_einzel", -2.8, -1.4, 0.0],
	["pilz_einzel", 0.3, -3.6, 70.0],
	["pilz_einzel", 2.5, -5.4, 150.0],
	["pilz_einzel", -3.4, -5.6, 230.0],
]
## Grabsteine nur als Ergänzung (Kenney Graveyard Kit, CC0): [Modell, x, z, Drehung, Größe]
const GRAEBER := [
	["gravestone_broken", -1.3, -5.6, 8.0, 0.7], ["gravestone_round", 1.6, -6.0, -12.0, 0.65],
	["gravestone_cross", -0.4, -6.4, 4.0, 0.75],
]
## Lichter (nur nachts): [x, y, z, Farbe, Stärke] vor Fenstern und großen Kolonien
const LICHTER := [
	[-3.0, 2.0, -5.3, Color("dfff6a"), 1.4], [3.9, 2.0, -5.1, Color("dfff6a"), 1.4],
	[-4.0, 1.0, -3.6, Color("9dff00"), 1.0], [0.4, 0.8, -4.4, Color("9dff00"), 0.9],
	[5.0, 1.2, -3.6, Color("dfff6a"), 1.0],
]

## Faktor auf die Grundfarben, wenn eine Umgebung ihre Modelle abdunkelt (EeveScenery: Wald-Tönung)
const AUFHELLEN := Color(1.6, 1.45, 1.35)
## Bodennebel über dem Hof: leicht grünlich wie Sporenstaub (Tag, Nacht)
const NEBEL_TAG := Color(0.78, 0.86, 0.74)
const NEBEL_NACHT := Color(0.36, 0.52, 0.4)

var lichter: Array[OmniLight3D] = []


## Hof bauen und unter parent hängen. at = Mitte der offenen Seite (Boden), facing = Richtung zur Karte (Welt),
## scale_k vergrößert alles (Bollwerk hat größere Figuren).
static func bauen(parent: Node, at: Vector3, facing: Vector3, scale_k := 1.0) -> BezirkUeberwuchert:
	var b := BezirkUeberwuchert.new()
	b.name = "BezirkUeberwuchert"
	b.position = at
	b.rotation.y = atan2(facing.x, facing.z)
	b.scale = Vector3.ONE * scale_k
	parent.add_child(b)
	b._bauen()
	return b


## Ein einzelnes Teil in Originalgröße (für eigene Anordnungen, z. B. Bollwerk-Ränder oder den Editor).
static func teil(name: String) -> Node3D:
	var scene = load(DIR % name)
	return scene.instantiate() if scene is PackedScene else null


func _bauen() -> void:
	for a in AUFBAU:
		_setzen(teil(a[0]), Vector2(a[1], a[2]), a[3])
	for g in GRAEBER:
		var m := ModelLoader.instantiate(GRAVE % g[0], g[4])
		_setzen(m, Vector2(g[1], g[2]), g[3])
	for l in LICHTER:
		var light := OmniLight3D.new()
		light.light_color = l[3]
		light.light_energy = l[4]
		light.omni_range = 3.2
		light.position = Vector3(l[0], l[1], l[2])
		add_child(light)
		lichter.append(light)


func _setzen(model: Node3D, p: Vector2, deg: float) -> void:
	if model == null:
		return
	model.position = Vector3(p.x, 0.0, p.y)
	model.rotation.y = deg_to_rad(deg)
	add_child(model)


## Liegt p (Welt, XZ) auf dem Hof? Für Wald und Unterholz, die dort nicht wachsen sollen.
func enthaelt(p: Vector2, rand := 1.0) -> bool:
	var l := to_local(Vector3(p.x, 0.0, p.y))
	return absf(l.x) < BREITE / 2.0 + rand and l.z < rand and l.z > -TIEFE - rand
