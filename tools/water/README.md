# Fließendes Wasser und Wasserfälle

Gemeinsames System: `scripts/systems/water/water.gd` (`WaterSystem`), auswählbar
über `data/modes.json` → `systems`. In allen sieben Modi verfügbar; ohne
Wassereinträge gibt es keine Meshes und keinen laufenden Wasser-Prozess.
Es ist eine visuelle Ebene. Bau-, Lauf-, Schwimm- oder Schadensregeln werden vom
jeweiligen Modus festgelegt. Gelände wird nicht automatisch ausgehoben.

## In einer Karte platzieren

Optionales Feld `water` im Karten-JSON; `MapData` erhält es beim Speichern,
Duplizieren, Laden und damit auch in map-basierten Spielständen.
Die eigene Maul-Kartenklasse übernimmt es ebenfalls. Der HTML-Karteneditor
erhält die Daten beim Laden/Speichern; der Godot-Map-Editor setzt Wasserläufe (siehe unten).

```json
"water": [
  {
    "id": "Bach",
    "kind": "river",
    "points": [[2, 2, 2], [2, 2, 5], [4, 2, 7]],
    "width": 2.0,
    "material": {"speed": 0.8}
  },
  {
    "id": "Fall",
    "kind": "waterfall",
    "points": [[4, 2, 7], [4, 0.15, 7.6]],
    "width": 2.0,
    "right": [1, 0, 0],
    "impact": true
  },
  {
    "id": "Becken",
    "kind": "pool",
    "center": [4, 0.15, 10],
    "size": [6, 5],
    "material": {"speed": 0.15, "direction_degrees": 20}
  }
]
```

Koordinaten `[x,y,z]` in Spiel-Einheiten: `y` ist die Höhe, `x/z` liegen auf dem
Spielfeld. Eine Kachel entspricht `Board3D.CELL` (0,5 Einheiten).
`pool.size` ist Breite/Länge, `river` und `waterfall` bilden ein Band entlang
der Punkte. Die Reihenfolge legt die Strömungsrichtung fest. Wasserfall-Punkte
müssen abwärts führen; `right` ist die horizontale Breitenrichtung.

UVs werden in Metern aufgebaut. `speed` bedeutet Einheiten pro Spielsekunde,
unabhängig von Länge und Unterteilung. Für Flächenwasser dreht
`direction_degrees` die Strömung. Die Animation pausiert mit dem Spiel.
Schaum entsteht nur an echten Ufern und Hindernissen: Wo eine Fläche an ein anderes
Gewässer gleicher Höhe grenzt (Fluss mündet in Becken, Fluss an Fluss), bleibt der
Rand offen, und ein Fluss blendet innerhalb eines Beckens aus. Wasserfälle müssen
oben aus einem Fluss/Becken kommen und unten in eines münden (±0,35 Einheiten);
sonst werden sie nicht gebaut, und `tools/map_check.gd` meldet sie
(`WaterSystem.fall_errors`).

Leichtes Strömungsmodell (`WaterSystem._connect_flow`, `WaterBody._fall_mesh`):
- Wasserfälle folgen einer Wurfparabel mit waagrechtem Abflug von der Kante zum
  Fußpunkt (`gravity` in `water.json`, Standard 9,8). Zwischenpunkte zählen nur
  für die Prüfung. Die Textur beschleunigt mit der Fallgeschwindigkeit; oben ist
  der Fall eine glatte Zunge in Flussfarbe, unten belüftet und weiß. `speed` ist
  beim Wasserfall ein Faktor auf diese Physik-Geschwindigkeit.
- Ein Fluss, der unter einem Wasserfall beginnt, reicht bis unter die Fallkurve
  zurück; ein Fluss, der in ein Becken mündet, reicht ein Stück hinein und blendet
  dort aus. Die Karte selbst bleibt unverändert.
- Der Aufprall (Schaumkern, Ringe, flussab abklingende Schleppe) wird im
  aufnehmenden Wasser gezeichnet, nie auf trockenem Boden. `impact: false` schaltet
  ihn ab.
Wasser über einem tieferen Boden platzieren und Ufer mit Gelände/Modellen
abdecken; überlappende transparente Wasserflächen möglichst vermeiden.

## Wasserläufe: Wasser sucht sich den Weg selbst

Statt jeden Punkt vorzugeben, reicht ein Lauf (`scripts/systems/water/water_route.gd`,
`WaterRoute`). Beim Aufbau wird er zu `river`/`waterfall`/`pool` aufgelöst:

```json
{"kind": "stream", "id": "Bach", "source": [1, 13], "dir": [1, 0], "width": 1.5,
 "via": [[8, 10]], "end": [30, 20], "length": 40}
```

- `source` [x, z] (Pflicht), `dir` Startrichtung, `width` Breite, `via` Wegpunkte (höchstens 16),
  `end` feste Mündung (dann kein freier Lauf), `length` Höchstlänge des freien Laufs.
- Höhengelände (`Terrain.hilly`, z. B. Survivors über den Haken `water_terrain()`): fließt nur
  bergab, steile Stufen werden Wasserfälle, Mulden füllen sich bis zum Überlauf zum Becken, kleine
  Senken aus Geländerauschen werden durchflossen.
- Kachelkarten: `#`, `_` und Sperrzonen sind Hindernisse, dazu der Haken `water_avoid()` (GemTD:
  Gegnerwege, Tower und Steine). Das Wasser hält Abstand je nach Breite, kehrt nach dem Ausweichen
  zur Startrichtung zurück und endet am Kartenrand, in einem anderen Lauf (Zusammenfluss) oder in
  einer Sackgasse als kleiner See. Gerechnet wird beim Aufbau, nicht laufend.
- `WaterRoute.channel_depth(regions, x, z)` sagt, wie tief Spiele mit eigenem Höhengelände das
  Flussbett graben sollten; ohne Tiefe schäumt ein flacher Wasserfilm überall.
- Map-Editor: Werkzeug „Wasserlauf“ (Taste 7) und Tab „Wasser“; Vorschau mit echtem Wasser.
- Prüfen: `tools/run_tests.sh wasserlauf`; Bilder: `tools/water/route_shot.tscn` (Editor) und
  `tools/water/route_hills.tscn` (Gelände) über `tools/render_windows.ps1`.

## Modus-Regeln und API

Reihenfolge für Materialwerte: Basis-Defaults → Basis-Typ → Kartenmaterial →
explizite Modus-Defaults → explizite Modus-Typregeln. **Modus-Regeln gewinnen.**

```json
"system_cfg": {
  "water": {
    "defaults": {"shallow_color": "#287b8dcc", "foam_strength": 0.4},
    "styles": {"waterfall": {"speed": 1.2}},
    "refraction": false
  }
}
```

Quelle der Platzierungen: Modus-Haken `water_regions()` → Modus-`regions` →
`MapData.water`. `null` delegiert an die nächste Quelle, `[]` entfernt Wasser.
Auch eigenständige Modi ohne `MapData` können `system_cfg.water.regions` nutzen.
`SystemHost` hinterlegt die Modus-ID am System, sodass der Vorrang auch bei
generischen Spiel-Knoten erhalten bleibt.

```gdscript
var water: WaterSystem = systems.water
var errors := water.set_regions(regions) # nur gültige Updates werden übernommen
water.rebuild()                         # Quelle erneut einlesen
water.clear()
```

`set_regions` verändert weder die Karte noch die Wegfindung. Dauerhafte
Änderungen entsprechend in `map.water` oder der Modus-Konfiguration speichern.
Ungültige Geometrie/Materialwerte werden zurückgewiesen, vorhandenes Wasser
bleibt dabei erhalten. Standard: maximal 64 Gewässer, 2048 Geometrie-Segmente
je Fläche, Unterteilung alle 0,5 Einheiten. Große Seen über `geometry.step`
gröber unterteilen oder das Budget gezielt erhöhen.

## Materialien und Grafikstufen

Parameter in `water.json`: `speed`, `tiling`, `normal_strength`, `wave_height`,
`foam_strength`, `foam_width`, `depth_distance`, `refraction`, `roughness`,
`shallow_color`, `deep_color`, `foam_color`. Farben als `#rrggbbaa`.

- Niedrig: animierte Normalen, UV-Strömung, Rand- und Aufprallschaum; kein
  Lesen von Bildschirm- oder Tiefentextur.
- Mittel: zusätzlich Tiefenfarbe und Kontakt-Schaum.
- Hoch: zusätzlich dezente, gegen Vordergrundobjekte begrenzte Brechung.
- `max_quality`, `depth`, `refraction` und `enabled` begrenzen Effekte je Modus.
- Wasserfälle sind zweiseitig und benutzen keine Bildschirmkopie. Aufprall-
  Schaum und Ringe entstehen im Oberflächen-Shader, ohne Partikelprozesse.

Die gemeinsame Tiefenformel in `assets/shaders/linear_depth.gdshaderinc`
funktioniert mit der im Projekt verwendeten Forward+/Reverse-Z-Projektion
für beide Kameratypen. Sie umgeht das [Orthografie-Problem der inversen
Projektionsmatrix in Godot 4.3](https://github.com/godotengine/godot/issues/68878).
Bildschirm-Brechung enthält keine anderen transparenten Objekte; keine echte
Fluid-Simulation oder physikalischen Spiegelungen.

## Texturen reproduzieren

```bash
python tools/water/textures.py
python tools/water/textures.py --check
```

Nur Python-Standardbibliothek, fester Zufallsstartwert, nahtlose periodische
Value-Noise-Texturen (256×256), automatisch auf Nahtfreiheit geprüft:

- `assets/textures/water/flow.png`: R = Strömungsrauschen, G = Fall-Streifen,
  B = unabhängiges Rauschen.
- `normal.png`: Normalen aus der Wasserhöhe.
- `foam.png`: Schaum-Maske.

Quelle/Lizenz in `assets/textures/water/CREDITS.md`, keine externen Bildquellen.

## Prüfen und ansehen

```bash
tools/run_tests.sh syswater watertextures systeme maps
godot --path . res://tools/water/demo.tscn
godot --path . res://tools/water/demo.tscn -- --perspective
godot --path . res://tools/water/demo.tscn -- --live
```

Demo-Daten: `tools/water/demo.json`. `--live` zeigt fließendes Wasser dauerhaft,
Tasten 1/2/3 wechseln die Grafikstufe. Ohne `--live`: Bilder aller drei Stufen
unter `.godot/water-0.png` bis `water-2.png`, plus zweiter Animationszeitpunkt.
Perspektivische Bilder heißen `water-perspective-*.png`.
Der GPU-Test prüft zusätzlich sichtbare Bewegung und freie Beckenmitte ohne
fälschlichen Weißschleier. Headless prüft Daten/Geometrie, nicht die Shader-Grafik.

Windows mit den vorhandenen Wrappern:

```powershell
./tools/windows.ps1 -Godot C:/tools/godot.exe -Python C:/tools/python.exe -ToolArgs syswater,watertextures,systeme,maps
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/water/demo.tscn -Name water-demo
```
