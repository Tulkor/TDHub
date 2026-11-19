# Grafik- und Menüoptimierung

Gemessen lokal mit Godot 4.3, Forward+, Radeon RX 9070 XT, Windows, isoliertem Testprofil. Messaufbau: `tools/render_windows.ps1`, Screenshot-Szene, sechs Sekunden nach zwei Sekunden Aufwärmen. Einzelmessungen sind keine Garantie für andere Geräte oder Kämpfe.

| Vergleich | Vorher | Nachher |
| --- | ---: | ---: |
| Menü-Hintergrund aufbauen | 1792,45 ms | 884,17 ms |
| Menü, mittlere Bildzeit | 11,57 ms | 11,45 ms |
| Bollwerk, statische Umgebung, mittlere Bildzeit | 13,91 ms | 5,88 ms |
| Bollwerk, statische Umgebung, p95 | 19,40 ms | 9,10 ms |

Menü: PackedScenes und Modellgrenzen je Dateipfad wiederverwenden, statt dieselben Ressourcen und Unterbäume für jede Baumplatzierung erneut zu vermessen. Keine relevante Änderung der dauerhaften FPS. Ein versuchtes Zusammenlegen des Menüwaldes wurde wegen schlechterer Bildzeit verworfen. Das unsichtbare 3D-Logo rendert und animiert nicht weiter.

Bollwerk: dieselben 12.848 Bergvegetations-/Felsinstanzen räumlich in 48-m-Zellen statt in riesige modellweite MultiMeshes gruppieren. Diese Aufteilung verbessert die Sichtbarkeitsgrenzen; Knotenzahl und Draw Calls steigen dabei. Die Screenshot-Szene hält die Spielsimulation an: Diese Werte beschreiben Umgebungsrendering und messen keine laufenden Kämpfe. Messung entstand vor dem zusätzlichen Sichtschutz an Geheimwegen.

Vergleichslogs: `.godot/opt-menu-cache.log`, `opt-menu-ohne-cache.log`, `opt-bollwerk-final.log`, `opt-bollwerk-final-basis.log`. Die Bollwerk-Vergleichsaufnahme meldete beim Beenden bestehende Ressourcenreferenzen; die Messung davor wurde vollständig geschrieben. Wiederholbar mit `--menu-cache=off` bzw. `--static-batches=off`.

Abschlussprüfung einschließlich der anschließenden Karten-/HUD-Änderungen: `heroesexplore` 728, `heroesplay` 487 und `heroesmobility` 38 Prüfungen mit echter GPU, jeweils ohne Fehler. `menurender` 6 und `staticbatch` 14 Prüfungen grün; Testauswahl-Konfiguration gültig. Die finale Umgebungsaufnahme liegt unter `export/screens/secret-cover-final_bild.png`; beim Beenden dieser Screenshot-Szene verbleibt eine Ressourcenreferenz, die separaten Tests beenden sauber.
