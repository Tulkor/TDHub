# Gemeinsame Shader

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
