# Gemeinsame Shader

## Gelände: Normalen und Reflexion

Die Materialprüfung unterscheidet Bild-Maps und berechnete Oberflächen:

| Oberfläche | Normalen | Specular/Rauheit |
|---|---|---|
| Grundboden und Baum-Erde | vorhandene Normalbilder je Belag | abgeleitete `ground/*_specular.png`, passend zum Belag |
| Städtisches Flussufer | echtes `cobble_normal.jpg`, triplanar mit aus UV-Ableitungen berechneter Tangentenbasis | echtes `cobble_specular.png` |
| Natürliches Ufer und Ufersteine | dezentes berechnetes Mikrorelief (`natural_bank.gdshader`) | berechnet; feuchter innerer Ufersaum weniger rau, stärkere dielektrische Reflexion |
| Neon-/Glasfelsen | berechnetes, kleines Relief entlang vorhandener Adern | räumlich berechnet, ursprünglicher Glasstil bleibt |
| Maul-Kalkstein und Fenster | berechnete Körnung und Fenstervertiefung | rauer Kalkstein gegenüber glatteren Glasfenstern |
| Beleuchteter Marmor-/Messingboden | berechnetes Mikrorelief | berechnete Variation um vorhandene Stilparameter |
| Wasser und Wasserfall | animierte Normalbilder, Brunnen mit analytischen Wellen | vorhandener dielektrischer Glanz/Fresnel; keine künstlichen Ersatzbilder |
| Gischt/Kantenschaum | transparente, unbeleuchtete Effektfläche | kein beleuchteter Festkörper, keine bedeutungslosen Normal-/Spec-Bilder |

`terrain_relief.gdshaderinc` berechnet Oberflächengradienten ohne vorausgesetzte
Mesh-Tangenten. Bitmap-Normalen werden mit den tatsächlichen UV-Ableitungen in
den Sichtraum gedreht; vertikale und spiegelverkehrte Uferflächen bleiben korrekt.
Prozedurale Felder sind ausdrücklich keine vorgetäuschten Bitmap-Maps. Farben,
Neonlicht, Glas-/Marmorstil und geometrische Konturen werden beibehalten.

GPU-Probe: `tools/render_windows.ps1 -Scene res://tools/shaders/terrain_probe.tscn
-Godot <exe> -Name terrain-materials`, Bild `.godot/terrain-material-probe.png`.
Echte Ufer: `tools/water/route_hills.tscn`, optional `--city`, Nahbilder
`.godot/wasserlauf[-stadt]-ufer.png`. Gesamtabdeckung und Herkunft der statischen
Bilddaten stehen im Bericht des Werkzeugs `tools/terrain_materials.py`.

`VisualFx` liegt unter `scripts/systems/visuals/`. Basiswerte aus `visuals.json`
werden von `data/modes.json` → `system_cfg.visuals` überschrieben.
Es werden ausschließlich Darstellungen verändert, keine Treffer oder Zufallswürfe.

## Prüfen

```bash
tools/run_tests.sh visuals systeme boss lebensbalken treffer ux
tools/run_tests.sh geaendert
godot --path . res://tools/shaders/probe.tscn
```

Die GPU-Vitrine schreibt `.godot/shader-probe-0.png` bis `-2.png` für
Niedrig/Mittel/Hoch. Compilerfehler prüfen und Bilder ansehen: Headless allein
prüft keine sichtbaren Shader-Ergebnisse. Für echte Spielszenen weiterhin
`tools/screenshot.sh` und `tools/leistung.sh` verwenden.

Windows (Git Bash, Python, Godot 4.3):

```powershell
./tools/windows.ps1 -Godot C:/tools/godot.exe -Python C:/tools/python.exe -ToolArgs visuals,systeme
./tools/shaders/check.ps1 -Godot C:/tools/godot.exe
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -OptionsJson '["--map=eeve","--phase=welle","--messen=3"]'
```

`windows.ps1` nutzt die vorhandenen Bash-Scripts; `-Tool` wählt z. B.
`tools/godot_import.sh`, `-ProjectPath` einen anderen Checkout. Keine zweite
Testauswahl. `render_windows.ps1` startet die vorhandene Screenshot-/Messszene
mit echter GPU im Hintergrund, prüft Fehler und begrenzt die Laufzeit.
Logs unter `.godot/`, getrennte Testprofile im übergeordneten Workspace
unter `.tdhub-test-profile`.

## Grenzen und Modusregeln

- Gegnerstatus für `Enemy` und Unterklassen: Frost, Gift, Feuer, Betäubung,
  Rüstungsbruch, Schutz und Trefferrand. Originaltexturen bleiben erhalten;
  Shaderwerte werden bei Zustandsänderungen und Treffern aktualisiert.
- Modus-Haken: `visual_status_flags()` und `status_visible()`. YouTD ergänzt
  langsameres Tempo, Betäubung und Rüstungsbruch aus dem eigenen Kern. Seine
  Gift-/Feuerbuffs werden nicht anhand von Namen erraten. Maul-Unsichtbarkeit
  verhindert zusätzliche Konturen vor der Enttarnung.
- Auf Niedrig ist der zusätzliche Konturpass vollständig abgehängt. Er erkennt
  Verdeckung im Tiefenbild; transparente Verdeckungen werden nicht zuverlässig erfasst.
- Reichweite in Towerfarbe und eigene Aura-Grenze bei Auswahl/Hover; Bauvorschau
  übernimmt das gültig/ungültig-Ergebnis des Bau-Systems. Nova-Flächen sind kurze
  Trefferanzeigen, keine zusätzliche Schadenszone.
- Felsen variieren deterministisch nach Position. Wind erhält Textur/Farbe und
  Tag/Nacht-Tönung der Wald-/Parkmodelle, auf Niedrig steht er still.
- Hohe Neon-Gem-Stufen ab Tier 4: Brechung nur auf Hoch; Facetten auf allen Stufen.
  Beim Herunterschalten wird ein Shader ohne Bildschirmtextur verwendet.
- Druckwellen nur auf Hoch und ab konfiguriertem Radius, höchstens drei gleichzeitig.
  Bodenpulse höchstens 24, Leichen standardmäßig höchstens 20. Todesdarstellung
  animiert eine zeitlich begrenzte Kopie außerhalb der Simulation.
- Bollwerk/Survivors behalten ihre eigenen Gegner- und Warnflächen-Darstellungen.

Gezielte Modus-Ausnahme (andere Basiswerte bleiben erhalten):

```json
"system_cfg": {
  "visuals": {
    "occlusion": {"enabled": false},
    "wind": {"strength": 0.01},
    "range": {"fill": 0.02}
  }
}
```

Die Konfiguration wird pro Modus gecacht. Tests, die Modus-Daten zur Laufzeit
ändern, leeren anschließend `VisualFx._configs`.

## Texturvarianten

`terrain_variation.gdshaderinc` bietet `tv_sample(tex, uv, blur)` für Farbe/Materialdaten und `tv_normal(tex, uv, blur)` für passend gedrehte Normalen. Beide wählen dieselben zwei Varianten und weichen Mischgewichte; UVs müssen je Materialkanal identisch sein. `textureGrad` verwendet nur die kontinuierlichen UV-Ableitungen, damit Variantenwechsel keine dunklen Mip-Ränder erzeugen. Beispiel: `hd_terrain.gdshader`. Godot 4.3: lokale Hilfsvariablen nicht wie gleichnamige Uniforms nennen (etwa `cell`), sonst kann der GLSL-Generator trotz erfolgreichem Parser die Uniform referenzieren.
