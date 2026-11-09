# Fließendes Wasser und Wasserfälle

Gemeinsames System: `scripts/systems/water/water.gd` (`WaterSystem`), auswählbar
über `data/modes.json` → `systems`. In allen sieben Modi verfügbar; ohne
Wassereinträge gibt es keine Meshes und keinen laufenden Wasser-Prozess.
Es ist eine visuelle Ebene. Bau-, Lauf-, Schwimm- oder Schadensregeln werden vom
jeweiligen Modus festgelegt. Flüsse erhalten automatisch erhöhte Uferböschungen mit
Anschluss zum Boden; bestehendes Gelände wird dabei nicht ausgehoben.

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
An jeder angeschlossenen Fallkante entsteht zusätzlich ein animierter Schaumbogen:
Er beginnt noch auf dem Fluss und folgt dann der Fallparabel. Damit verdeckt er die
Geometrienaht, statt nur eine weiße Linie auf eine der beiden Flächen zu zeichnen.
`crest_foam: false` schaltet ihn je Wasserfall/Lauf ab. Er verwendet die gemeinsame
Strömungsuhr, pausiert mit dem Wasser und funktioniert auf allen Grafikstufen.

## Automatische Uferböschungen

Jeder `river` erhält ohne weitere Platzierung ein statisches Ufermesh (`WaterBank`),
auch im Karteneditor und bei aus `stream` erzeugten Flüssen. Es übernimmt die
tatsächlichen geglätteten Kanten und aufgeweiteten Mündungen des Wasserbands:
nasser Innenrand, erhöhte Uferkrone und sanfter äußerer Hang. Das Bett schließt
erhöht platziertes Wasser nach unten ab. Freie Quellen/Enden werden abgerundet;
Mündungen, Zusammenflüsse und Wasserfallanschlüsse bleiben offen.

Naturufer laufen mit mehreren gerundeten Stützreihen und abgesenkten Enden weich
aus. Ortsfeste Variationen verändern Breite/Höhe und bilden kleine Erdhügel; einzelne
niedrig aufgelöste Steine werden pro Fluss in einem MultiMesh gebündelt (maximal 96).
Der Aufbau verbraucht keinen Spiel-Zufall und bleibt bei allen Clients/Neuaufbauten gleich.

Im Stadtstil (FieldStyle `water_bank_style: city`, bei Plakatwand/Art déco) entstehen
stattdessen links und rechts 1,35 Einheiten breite Pflastergehwege mit Bordkante und
gefasster Kanalseite. Das Material nutzt die vorhandene
`assets/textures/ground/cobble.jpg`. Die Pflasterprojektion verwendet Weltmeter;
an Kurven und senkrechten Seiten wird sie ohne UV-Verzerrung überblendet.
`banks.style` kann die automatische Tileset-Wahl (`auto`) mit `natural` oder `city`
überschreiben; explizite Modus-Regeln behalten Vorrang.

Standard: 0,9 Einheiten Hangbreite, 0,16 über der Wasserfläche liegende Uferkrone,
0,35 Betttiefe, erdiger Innenrand und grasfarbene Außenseite. Über `water_terrain()`
schließt der Hang an das tatsächliche Höhenfeld an, sonst an `ground_height` (0).
Die bestehenden Bau-, Bewegungs- und Geländekollisionen werden nicht verändert.
Wer ein eigenes Gelände aushebt, kann weiterhin `WaterRoute.channel_depth` verwenden.

```json
{"kind": "river", "points": [[1, 0.2, 1], [1, 0.2, 8]], "width": 1.5,
 "banks": {"width": 0.7, "height": 0.12, "grass_color": "526941"}}
```

Uferwerte kaskadieren Basis-`water.banks` → Platzierung-`banks` → explizite
Modus-`system_cfg.water.banks`; Modus-Regeln gewinnen. `banks.enabled: false`
deaktiviert sie, etwa bei bereits modellierten Ufern. `stream` reicht seine
`banks`- und `crest_foam`-Werte an alle erzeugten Gewässer weiter. Parameter sind
`enabled`, `style`, `width`, `height`, `depth`, `ground_height`, `soil_color`, `grass_color`,
`variation` (0–1), `rocks` und `city_width`.
Farben als HTML-Farbwert. Ungültige Uferwerte lassen die vorhandene Landschaft
intakt. Böschungen erzeugen keine laufenden Prozesse; Löschen/Neuaufbau des Wassers
räumt sie zusammen mit den Wasserflächen auf.

Vergleichsbilder: `route_hills.tscn` erzeugt zusätzlich `wasserlauf-ufer.png`;
mit `-- --city` entstehen die Bilder unter `wasserlauf-stadt-*.png`.

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
