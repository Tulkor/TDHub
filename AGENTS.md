# Projektregeln für Codex

## Effizient arbeiten
- Tokenverbrauch gering halten: gezielt suchen, nur relevante Ausschnitte lesen und kompakte Script-Ausgaben verwenden.
- Bestehende Regeln in `CLAUDE.md` beachten. Bereichswissen gezielt aus `docs/claude/` lesen; die Claude-Hooks laufen in Codex nicht automatisch.
- Größere, unabhängige Aufgaben bei Bedarf auf separate Chats verteilen; kleine zusammenhängende Änderungen gemeinsam bearbeiten. Übergaben kurz halten und Ergebnisse dauerhaft im Repository dokumentieren.
- Wiederkehrende Abläufe in vorhandene Scripts integrieren oder als Script bzw. bei passenden Arbeitsanweisungen als Skill festhalten. Vorher nach vorhandenen Lösungen suchen; keine parallelen Werkzeugsammlungen aufbauen.
- Neue Erkenntnisse in die passende Bereichsnotiz unter `docs/claude/` eintragen; diese Datei kurz halten.

## Vorhandene Werkzeuge und Tests zuerst
- Godot ist vom Nutzer generell freigegeben und darf für Projektaufgaben ohne erneute Rückfrage verwendet werden, insbesondere für Import, Tests, Rendern und Vorschauen (2026-11-09).
- Godot bei Tests, Aufnahmen und Vorschauen immer stumm starten (`--audio-driver Dummy`, Nutzerwunsch 2026-11-10); der Windows-Aufnahme-Wrapper setzt dies automatisch.
- Windows-GPU-Tests und Aufnahmen immer über `tools/render_windows.ps1`: Nutzer spielt auf Bildschirm 1. Testfenster automatisch auf Bildschirm 2, im Fenstermodus und von der Erzeugung an ohne Fokusübernahme. Keine Testfenster auf Bildschirm 1 öffnen oder dorthin aktivieren (Nutzerwunsch 2026-11-18).
- Einstieg: `tools/lage.sh`; Werkzeugübersicht und weitere Regeln: `CLAUDE.md`, Details: `docs/claude/werkzeuge.md`.
- Code gezielt lesen: `tools/gliederung.py`; Daten lesen/ändern: `tools/daten.py`, `tools/werte_setzen.py`.
- Passende vorhandene Tests nutzen: `tools/run_tests.sh geaendert` oder gezielte Testnamen. Auswahl erklärt `tools/test_auswahl.py --erklaeren`; Zuordnung in `tests/bereiche.json` und den Testköpfen.
- Grundregel (Lukas, 2026-11-11): Nur geänderte Bereiche und ihre unmittelbar betroffenen Abhängigkeiten testen. Bei gemeinsamen Systemen die tatsächlich betroffenen Modi einbeziehen. Keine vollständigen oder fachfremden Testläufe ohne konkreten Anlass; breitere Prüfungen nur bei ausdrücklichem Auftrag, verbindlicher Release-Prüfung oder einem bereichsübergreifenden Fehlerverdacht. Bereits grüne Prüfungen nur nach relevanten weiteren Änderungen oder neuen Fehlerhinweisen wiederholen.
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

## Zusammenarbeit mit Claude (Lukas, 2026-11-25)
Claude (Claude Code) und Codex arbeiten im selben Repo. Fachregeln stehen nur einmal, in `CLAUDE.md` und `docs/claude/`; hier nur die Absprachen.
- Eigene Branches: Codex `codex/<thema>`, Claude `claude/<thema>`. Nie auf den Branch der anderen KI pushen, force-pushen oder rebasen. Aufbauen geht über einen eigenen Branch ab deren Stand.
- Auf `main` nur per PR, gemergt wird nur auf Lukas' Wort. Vorher `tools/vor_pr.sh`; offene PRs und Überschneidungen zeigt `tools/prs.sh offen`.
- PR-Text endet mit einer kurzen Übergabe: `Übergabe: Was – Warum – Geprüft (Tests/Screenshot) – Offen`. Die andere KI liest sie, bevor sie auf dem PR aufbaut.
- Gegenseitige Reviews: Wer einen PR der anderen KI prüft, kommentiert im PR (Befund mit Datei:Zeile) und ändert nichts auf deren Branch. Lukas entscheidet bei Uneinigkeit.
- Gleiche Dateien nicht parallel bearbeiten: Vor dem Start `tools/prs.sh offen` prüfen; überschneidet sich ein offener PR, darauf aufbauen oder Lukas fragen.
- Lokaler Klon auf Lukas' PC: Nicht gleichzeitig mit Claude im selben Arbeitsordner arbeiten; Arbeit committen, bevor die andere KI übernimmt, statt unkommittete Stände liegen zu lassen.
- Dauerhaftes Wissen kommt in `docs/claude/<bereich>.md` (gilt für beide), nicht in private Notizen.
