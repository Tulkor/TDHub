# Gemeinsame Bodenlichtprofile

`assets/shaders/light_profiles.gdshaderinc` enthält wiederverwendbare Funktionen für Oberflächenlicht. Eigene Implementierung, inspiriert von Source-/Hammer-Parametern: 50-%-Distanz, maximale Reichweite sowie Innen-/Außenkegel und Fokus. Referenzen: [Source-Entitydefinitionen](https://github.com/Facepunch/garrysmod/blob/master/bin/base.fgd), [Valves Projektionslicht](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/client/c_env_projectedtexture.cpp). Kein Valve-Code oder Material übernommen.

Das Bodenmaterial verwendet diese Parameter über `FieldStyle.floor`. Modus-Overrides gelten weiterhin zuletzt; andere Modi behalten mit `lamp_type=-1` ihren bisherigen Verlauf.

| Parameter | Wirkung |
|---|---|
| `lamp_type` | `0` weich, `1` hart, `2` Spotlight; `-1` bisherige Exponentialkurve |
| `lamp_radius` | Maximale Reichweite der neuen Profile in Welteinheiten |
| `lamp_half_distance` | Abstand mit 50 % Helligkeit beim weichen Licht; beim Spotlight zusätzlich vom Kegel begrenzt |
| `lamp_edge_width` | Antialiasierter Übergang am Rand des harten Lichts |
| `lamp_height` | Virtuelle Höhe der Spotquelle über dem Boden |
| `lamp_direction` | Kegelrichtung in Weltachsen; Standard `(0,-1,0)` |
| `lamp_inner_angle`, `lamp_outer_angle` | Halbwinkel in Grad: volle Kegelintensität innen, außen null |
| `lamp_focus` | Form des Übergangs zwischen den Kegeln |
| `lamp_pool`, `floor_lamp` | Bodenschein und sichtbare Leuchtkerne getrennt regeln |
| `lamp_silver_nonbuildable`, `lamp_silver_color` | Maul: silberne Fassungen/Leuchtkerne auf Gängen und Wegpunkt-Sperrzonen, im selben Raster wie goldene Bauflächen-Leuchten |

Weiches Licht hat einen kontinuierlichen Abfall und endet an der Reichweite. Hartes Licht hat einen gleichmäßig hellen Innenbereich und einen schmalen, antialiasierten Rand. Spotlights kombinieren Distanzabfall mit einem gerichteten Kegel. Dies sind günstige Oberflächenprojektionen, keine zusätzlichen Godot-Lichtknoten: keine Schatten oder Beleuchtung anderer Objekte. Das schwache weißbläuliche Mondlicht und optische Lichtwände bleiben unabhängig.

Die Maul-Messinglinien nutzen `Metall.linien()` mit derselben Rauheitskarte wie die vorhandenen Metallmaterialien, GGX-Reflexionen und Klarlack ab Grafik Mittel. `line_metallic`, `line_roughness`, `line_finish` bleiben im Stil konfigurierbar; Grafikwechsel aktualisieren die Klarlack-Schicht.

## Prüfen und ansehen

`tools/shaders/light_probe.tscn` prüft per echtem GPU-Pixel-Readback 50-%-/Null-Distanz, weiche/harte Ränder, Innen-/Außenkegel und gerichtete Spots. Über `tools/render_windows.ps1 -Scene res://tools/shaders/light_probe.tscn -Name licht-gpu-check` ausführen (zusätzlich `-Godot` angeben).

Ingame-Vergleich über vorhandene `tools/screenshot.tscn`: `--szene=maul --filiale=hm --nacht --licht=weich|hart|spotlight`. Dies ändert nur das Foto, keine gespeicherten Einstellungen. Der Windows-Aufnahme-Wrapper startet immer mit `--audio-driver Dummy`.
