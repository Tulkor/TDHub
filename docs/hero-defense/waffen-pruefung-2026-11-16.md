# Bollwerk – Waffenprüfung, 16. November 2026

Ergebnis: 24 Helden, 23 mit Waffen/Handgeräten, 182,337 Einzelprüfungen, 0 Fehler.

Geprüft wurden die finalen GLBs: Angriff und Zauber mit 96 Abtastungen pro Sekunde, starre Waffenvertices, unveränderte Gelenkverbindungen, gemeinsame vollständige Hand-/Waffentransformation und tatsächliche Waffenbewegung. Bei Schneidwerkzeugen wird die physische Klingenebene gegen die Aushol-/Trefferbahn geprüft; bei einseitigen Äxten muss die scharfe Seite führen. Aktive Schnitte müssen nach innen durch eine frontale Rumpfzone laufen; eine korrekt gedrehte Schneide allein genügt nicht. Bogen-/Zughandanker und Soreks zweite Greifhand werden während der Übergänge separat geprüft.

Zusätzlich: Fluid-/Bodenkontaktprüfung und Brustvolumen-Abstände; neue GPU-Angriffsaufnahmen für alle 23 bewaffneten Helden, vier Kontaktbögen mit je acht Zeitpunkten pro Held visuell kontrolliert. Die Volumenprüfung ersetzt keinen vollständigen Mesh-Kollisionssolver.

## Korrigiert

- Bereitschaft: Schwert- und Dolchspitzen zeigen nach vorne, Axtschneiden ebenfalls. Sirra führt zwei Stichangriffe und einen Schnitt aus; Stichspuren passen zur Animation.
- Varg und Totengräber: Klingenebene dreht mit Hand und tatsächlicher Schlagrichtung; Vargs einseitige Äxte führen mit der Schneide.
- Torvik: eigene Hand-/Waffenanker für beide Äxte, Schneiden zur Schlagbahn, Hände vor dem Körper. Die neue Haltung verhindert auch das Durchschlagen der Axtgriffe durch die Brust.
- Ralda: Hammerflächen statt einer beliebigen Kopfseite in Schlagrichtung.
- Sorek: beide Greifhände in Blender mit 96 Hz gebacken; gemessener maximaler Stützhandabstand 2.2 mm. Die untere Stützhand lässt den oberen Schäkel frei. Fünf einzeln starr geriggte Kettenglieder (zusammen etwa 0,53 m) schwingen mit Schwerkraft und Trägheit nach; keine Laufzeitphysik nötig. Der nachträgliche Unterarm-Nachlauf bleibt für Hand-/Waffenketten aus.
- Schlagbahnen: Oberkörperdrehung und Griff-/Waffenziele gemeinsam korrigiert. Brennholt, Yuna und die übrigen körperlichen Nahkämpfer führen die Hiebe nach vorne/innen; Varg und Torvik führen ihre Äxte von den jeweiligen Außenseiten zur Mitte. Trefferziele liegen auf Rumpfhöhe statt neben den Füßen. Die frühere reine Schneidenprüfung hatte die falsche Gesamtrichtung nicht erkannt.

## Kader

| Held | Waffen-/Gerätegruppen | Prüfungen | Ergebnis |
|---|---:|---:|---|
| Torvik Sturmruf | 2 | 5020 | OK |
| König Unrat | 2 | 2502 | OK |
| Oberschwester Vesna | 1 | 682 | OK |
| Zix Funkenkurbel | 2 | 915 | OK |
| Hauptmann Brennholt | 2 | 9713 | OK |
| Mira Steinhaut | 0 | 1 | Ohne Handwaffe |
| Der Grauhirte | 1 | 8885 | OK |
| Sirra Nachtfalke | 2 | 8372 | OK |
| Kaspar der Armbrustmacher | 1 | 7925 | OK |
| Yuna Schnittwind | 1 | 7296 | OK |
| Orrin Glutwort | 2 | 10086 | OK |
| Weise Ilsabet | 1 | 8725 | OK |
| Tamo der Donnerbauer | 1 | 8245 | OK |
| Schwester Albe | 1 | 8405 | OK |
| Fenn Laternenträger | 1 | 9125 | OK |
| Ralda Runenschmied | 1 | 9051 | OK |
| Varg Eisenbart | 2 | 8958 | OK |
| Lior Spiegelseher | 1 | 8405 | OK |
| Die Krähenfrau | 2 | 10086 | OK |
| Bruno Fassroller | 1 | 8725 | OK |
| Tessa Sturmsegel | 1 | 9125 | OK |
| Der Totengräber | 1 | 8894 | OK |
| Ada Glockenwacht | 1 | 8725 | OK |
| Sorek Ankerträger | 1 | 14471 | OK |

## Reproduzieren

`python tools/modelle/weapon_qa.py` oder `tools/run_tests.sh riggen`.
`attack_probe.tscn -- --held=<id> --combo`, bei Vesna/Zix ohne `--combo`; Godot immer mit `--audio-driver Dummy`.
`python tools/heroes/attack_clips.py --kontakt` baut die vier visuellen Prüfbögen.
