# Bollwerk-Endbosse

Welle 40 wählt einmal pro Partie einen der fünf Endbosse. Ansage und Spawn verwenden dieselbe gespeicherte Auswahl. Die Kriegsherren in Welle 10/20/30 bleiben erhalten. Die Designs sind eigenständige Figuren mit Raid-Warnmustern und ARPG-Flächenkontrolle; keine übernommenen Figuren oder Assets aus anderen Spielen.

| Boss | Design-Thema | Sechs Moves |
| --- | --- | --- |
| Varkhun, der Kettenrichter | Kettenschmiede: Eisenrüstung, Glutkern, Hammer und Ketten | Dreifache Hiebe, versetzte Kettenbahnen, sicherer Innenkreis, Doppelansturm, Kettendiener, Ofenflächen im Ring |
| Nerathis, Königin der Gezeiten | Sturmflut: Flossen, Krone und Dreizack | Auswärts laufende Ringe, nachsetzende Geysire, Geschossfächer, rotierendes Strömungskreuz, jagender Wirbel, Flutring mit sicherer Mitte |
| Morvath, der Dornenchor | Dornenfäulnis: Pilzkrone, verzweigte Dornen und Sporenauge | Rotierende Dornenhiebe, abgelegte Sporenfelder, Fäulnisring, Sporenwichte, wiederholte Wurzelbahnen, ringförmiger Giftgarten |
| Astrael, Hüter der gebrochenen Stunde | Gebrochene Zeit: schwebender Kristall und Uhrwerk | Echos vergangener Heldenpositionen, rotierende Zeigerbahnen, Splitterfächer, einwärts laufende Ringe, versetztes Zifferblatt, fünffaches Erinnerungsecho |
| Zharok, Herz der Finsternis | Kosmischer Schlund: Hörner, Tentakel und leuchtender Schlund | Versetzte Leerenbahnen, nachsetzende Blutflächen, Sternenfächer, sicherer Innenkreis, Schlundlinge, vier rotierende Weltenhiebe |

Jeder Boss startet mit drei Moves. Bei 65 % Leben folgen zwei weitere, bei 30 % der letzte Move sowie neue Rotationen. Phasenwechsel beenden den laufenden Angriff und lassen zwei Sekunden Zeit zur Neuorientierung. Nach jeder vollständigen Combo folgt eine echte Angriffspause (1,25 / 1,10 / 0,95 Sekunden), einschließlich Nahkampf. Ausweichen und die vorhandenen Boss-CC-Regeln gelten weiterhin. Ein unterbrochener Angriff behält seinen beim Ansetzen gestarteten Cooldown.

Die Bossleiste zeigt den aktuellen Move mit einem Ausweichhinweis und kennzeichnet Erholungsfenster. Warnflächen verwenden die vorhandenen Formen und Barrierefreiheitseinstellungen. Die Schadensprüfung verwendet dieselbe Geometrie. Astraels Echos speichern beim Ansetzen vergangene Positionen; nachsetzende Angriffe markieren vor jedem Folgetreffer ihr neues Ziel.

## Daten und Erweiterung

- `data/heroes_bosse.json`: `defaults` → Boss-Overrides, `add_defaults` → Add-Overrides über `SystemHost.cascade`; bestehende Schwierigkeits-/Wellen-/Spielerzahl-Skalierung bleibt aktiv.
- `HdBossCatalog`: Katalog installieren, Welle-40-Gruppen als Kopie auflösen, Auswahl zwischen Ansage und Landung stabil halten. `HdGame.force_final_boss` legt eine Variante für Tests/Vorschauen fest; leer = Zufall.
- `HdBossBrain`: phasenabhängige Rotation, Erholung, sechs Positionsproben im 0,5-Sekunden-Abstand, Besitz und Cleanup. Bestehende Bewegung, Aggro, Leine und CC bleiben in `HdEnemy`.
- Neue Musterfelder: `kind: line` trifft markierte Bahnen direkt; `kind: echo` trifft eingefrorene Erinnerungspositionen; `pattern: orbit` plus `placement_radius` verteilt Kreise; `retarget` steuert das erneute Anvisieren zwischen Wiederholungen. `repeat`, `repeat_windup`, `rotate`, `grow`, `count` und `spread` verwenden die vorhandene Combo-Logik.
- Pro Boss maximal acht lebende Adds, zwölf Bodenflächen und 72 Geschosse. Älteste Bodenflächen werden ersetzt; bei vollem Geschossbudget entstehen keine weiteren. Adds geben weder Gold noch XP. Beim Boss-Tod werden eigene Warnflächen, Pools, Geschosse und Adds entfernt; fremde Gefahren bleiben erhalten. Projektil-Cleanup ist auch beim Tod innerhalb der Geschossiteration sicher.
- `HdBossVisual`: prozedurale Modelle im Dev-Stil von Bollwerk, mit eigener Silhouette und pulsierendem Kern. Keine zusätzlichen Bildtexturen oder Fremdassets. Die Werte sind ein erster Balance-Stand und brauchen noch menschliche Spieltests mit unterschiedlicher Ausrüstung.

## Wiederholbare Prüfungen

```sh
python3 tools/heroes/bosse.py --bericht
tools/run_tests.sh bossdata heroesboss heroes skripte ui auswahl
godot --path . res://tools/heroes/boss_probe.tscn
godot --path . res://tools/heroes/boss_probe.tscn -- --kampf=astrael
tools/screenshot.sh --szene=heroes --endboss=varkhun --held=torvik --zeit=8 --warnung --nah
```

`heroesboss` prüft alle 30 Moves samt Warnzeit/Treffer, Phasen, Rotation, CC-Unterbrechung, Erholung, Limits, Tod durch Heldengeschoss und Welle-40-Sieg. `heroes` behält für seine bisherigen vier Heldenkampagnen den ursprünglichen Verschlinger als feste Regression. Neue Varianten werden im fokussierten Test geprüft.

Unter Windows vorhandene Wrapper verwenden:

```powershell
./tools/windows.ps1 -Godot C:/tools/godot.exe -Python C:/tools/python.exe -ToolArgs bossdata,heroesboss,heroes,skripte,ui,auswahl
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/boss_probe.tscn -Name boss-gallery
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/boss_probe.tscn -Name boss-fight -OptionsJson '["--kampf=astrael"]'
```

Die GPU-Vitrine schreibt `.godot/boss-gallery.png`, die Kampfvorschau `.godot/boss-fight-<id>.png`. Die Vorschau versetzt Boss und Held für eine reproduzierbare Warnphase in die Arena; im normalen Spiel landet der Boss vor der Feste. Die Testauswahl kennt `bossdata` und den Modustest `heroesboss`.
