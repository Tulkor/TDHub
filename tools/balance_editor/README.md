# Balance-Editor

Kleines Werkzeug außerhalb des Spiels, um Werte von Towern und Gegnern in allen drei Modi
(GemTD, eeveTD, Shopping Maul) in Prozentschritten zu ändern. Eine einzige HTML-Datei,
läuft ohne Installation in Edge oder Chrome (Doppelklick).

## Bedienung
- Oben die Modus-Tabs, darunter **Enemies / Tower**, das Auswahlmenü (Welle bzw. Tower) und
  **Schritt** 1 / 5 / 10 % oder Custom (gilt für alle Pfeile).
- Grüner Pfeil ▲ = Wert um den Schritt erhöhen, roter Pfeil ▼ = senken. Werte lassen sich auch direkt eintippen.
  Ganzzahlen bleiben ganzzahlig (mindestens ±1 je Klick).
- Tower mit Stufen: Stufe oben wählen; „Pfeile auf alle Stufen“ ändert denselben Wert in allen Stufen
  (jeweils relativ zum eigenen Wert).
- **Fähigkeiten**: Typ wechseln, Zahlen mit Pfeilen ändern, Text-/Ja-Nein-Werte direkt, „JSON“ für alles andere,
  ✕ entfernt, „+ Fähigkeit“ fügt eine mit den Standardwerten aus `scripts/game/abilities.gd` hinzu.
- **Änderungen** unten listet alles mit vorher/nachher; ↺ nimmt eine einzelne Änderung zurück.
- Reiter **GemTD Roguelike**: dieselben Wellen, aber die Gegnerwerte stehen in `data/roguelike_enemies.json`
  und gelten nur in der Roguelike-Variante (Anzahl, Abstand und Tower teilt es mit GemTD).
  GemTD-Wellen zeigen Anzahl/Abstand der Gruppe und die Gegnerwerte. Gegnerwerte gelten in allen Wellen,
  in denen der Gegner vorkommt (steht dabei). eeveTD zeigt die Gegner je Gegnerstufe, Maul die 50 Level.

- Reiter **Level & EP** (`data/leveling.json`): je Profil höchstes Level, EP-Kurve (konstant, linear, exponentiell,
  eigene Formel oder Tabelle, „Faktor auf alle Stufen“ erhöht alle benötigten EP), Vorschau der EP je Level wie im Spiel,
  EP je Kill/Boss/Flieger, Boni je Level, Freischaltungen (Wert oder Fähigkeit ab Level) und Abweichungen je Tower.
  „Modi“ ordnet jedem Modus ein Profil zu (oder keines).
- Reiter **Aufstieg** (`data/ascension.json`): je Modus welche Schwierigkeiten im Startfenster stehen (die letzte ist die
  Grundlage für die Aufstiegsstufen), höchste Stufe (0 = ohne Ende), Regeln (Gegner-Leben/-Tempo/-Rüstung um Prozent
  oder Wert alle N Stufen ab Stufe M, Sonderregeln als Schalter vorbereitet), Vorschau +1 … +20, „In alle Modi kopieren“.

## Speichern
Zwei Wege:
1. **Ordner öffnen** (Edge/Chrome) und den Repo-Ordner wählen: lädt die aktuellen Daten von dort,
   **Speichern** schreibt nur die geänderten JSON-Dateien zurück, im gleichen Format wie die Python-Werkzeuge.
2. **Änderungen exportieren** lädt `balance_aenderungen.json` herunter. Im Repo übernehmen mit
   `python3 tools/balance_anwenden.py balance_aenderungen.json` (`--probe` zeigt nur an). Werte, die im Repo
   inzwischen anders sind als beim Bearbeiten, werden als Konflikt gemeldet und ausgelassen.
   So kann Lukas die Datei auch einfach in einen Thread hochladen.

Tower-Tabelle: `balance_anwenden.py` erneuert `docs/tower-werte.md` und kopiert sie nach
`/mnt/project-files/balance/`. Beim direkten Speichern in den Ordner macht das der Commit-Hook
(`tools/git-hooks/pre-commit`) oder von Hand `python3 tools/tower_tabelle.py --kopieren`.

Achtung: eeveTD- und Maul-Daten erzeugen `tools/wc3/eeve/eeve_daten.py` bzw. `tools/wc3/maul_daten.py`
aus den Kartendateien. Wer die neu laufen lässt, überschreibt Änderungen aus dem Editor.

## Dateien
- `balance_editor.html`: der Editor (ohne Daten: dann nur über „Ordner öffnen“).
- `bauen.py`: bettet Daten, Fähigkeiten-Liste und Schrift ein, Ergebnis
  `/mnt/project-files/balance-editor/balance_editor.html` (eine Datei zum Weitergeben).
- `pruefen.mjs`: Test im Browser (Format bleibt Byte für Byte gleich, Pfeile, Fähigkeiten, Export, Übernahme).
  `tools/run_tests.sh balanceeditor`.
