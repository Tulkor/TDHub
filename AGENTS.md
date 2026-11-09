# Projektregeln für Codex

## Effizient arbeiten
- Tokenverbrauch gering halten: gezielt suchen, nur relevante Ausschnitte lesen und kompakte Script-Ausgaben verwenden.
- Bestehende Regeln in `CLAUDE.md` beachten. Bereichswissen gezielt aus `docs/claude/` lesen; die Claude-Hooks laufen in Codex nicht automatisch.
- Größere, unabhängige Aufgaben bei Bedarf auf separate Chats verteilen; kleine zusammenhängende Änderungen gemeinsam bearbeiten. Übergaben kurz halten und Ergebnisse dauerhaft im Repository dokumentieren.
- Wiederkehrende Abläufe in vorhandene Scripts integrieren oder als Script bzw. bei passenden Arbeitsanweisungen als Skill festhalten. Vorher nach vorhandenen Lösungen suchen; keine parallelen Werkzeugsammlungen aufbauen.
- Neue Erkenntnisse in die passende Bereichsnotiz unter `docs/claude/` eintragen; diese Datei kurz halten.

## Vorhandene Werkzeuge und Tests zuerst
- Godot ist vom Nutzer generell freigegeben und darf für Projektaufgaben ohne erneute Rückfrage verwendet werden, insbesondere für Import, Tests, Rendern und Vorschauen (2026-11-09).
- Einstieg: `tools/lage.sh`; Werkzeugübersicht und weitere Regeln: `CLAUDE.md`, Details: `docs/claude/werkzeuge.md`.
- Code gezielt lesen: `tools/gliederung.py`; Daten lesen/ändern: `tools/daten.py`, `tools/werte_setzen.py`.
- Passende vorhandene Tests nutzen: `tools/run_tests.sh geaendert` oder gezielte Testnamen. Auswahl erklärt `tools/test_auswahl.py --erklaeren`; Zuordnung in `tests/bereiche.json` und den Testköpfen.
- Bei Fehlern `tools/log_auszug.sh <test>` verwenden. Tests nur bei neuem Verhalten oder fehlender Abdeckung ergänzen.
- Vor PR/Merge den vorhandenen Ablauf `tools/vor_pr.sh` verwenden; lange Befehle über `tools/kurz.sh` ausführen.
- Scripts sind überwiegend für Bash/Linux ausgelegt. Unter Windows die verfügbare Laufzeit prüfen; fehlende Voraussetzungen oder nicht ausgeführte Checks offen nennen.

## Gemeinsame Systeme und Modus-Kaskade
- Gemeinsame Spielsysteme liegen unter `scripts/systems/`; Modi wählen sie über `data/modes.json` → `systems` aus.
- Konfiguration kaskadiert von den Basiswerten zur Modus-Konfiguration (`system_cfg`). Modus-Regeln haben Vorrang; nicht überschriebene Basisregeln bleiben erhalten.
- Verschachtelte Dictionaries werden zusammengeführt, Listen vollständig ersetzt. Die gemeinsame Basis darf durch einen Modus nicht verändert werden.
- Gemeinsame Mechanik im gemeinsamen System implementieren und vorhandene Modus-Hooks/Konfiguration nutzen; keine Kopien derselben Mechanik je Modus anlegen.
- Vor Änderungen `docs/claude/systeme.md` und die passende Modus-Notiz lesen. Vorhandene Werkzeuge und Tests: `tools/systeme.py`, `tests/systems/`, insbesondere `systeme_test.gd` für die Kaskade.
- Änderungen an gemeinsamen Systemen für die betroffenen Modi prüfen; Modus-Ausnahmen gezielt im jeweiligen Modus halten.
