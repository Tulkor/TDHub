# Spielsysteme × Modi

Erzeugt mit `python3 tools/systeme.py matrix --md`, nicht von Hand ändern. eigen (n) = der Modus baut das System noch selbst (n erkannte Funktionen), geerbt = über game.gd, gemeinsam = nutzt scripts/systems/ bzw. die gemeinsame Klasse, Modusregel = bewusst eigene Umsetzung (Grund unter der Tabelle, katalog.json → modusregel). ✓ = in data/modes.json angekreuzt.

| System | Etappe | gemtd | eevetd | randgruppen | youtd | shoppingmaul | heroes | survivors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| run_record – Run-Ende, Profil, Debug-Run, Abbruch | 2 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ |
| difficulty – Schwierigkeit und Aufstieg | 2 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – |
| targeting – Ziele finden, Gegner im Kreis, nächster Gegner | 3 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ |
| economy – Gold, Einkommen, Leben, Leak-Strafe | 4 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | Modusregel ✓ | gemeinsam ✓ | Modusregel ✓ | Modusregel ✓ |
| save – Spielstand, Autosave | 4 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | Modusregel ✓ | – | – |
| waves – Spawn-Warteschlange, Auto-Welle | 5 | gemeinsam ✓ | Modusregel ✓ | gemeinsam ✓ | Modusregel ✓ | Modusregel ✓ | gemeinsam ✓ | gemeinsam ✓ |
| coop – Koop-Abgleich: Snapshot und Befehle | 6 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – | – |
| inventory – Item-Plätze, Items auf Tower ziehen | 6 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – |
| leveling – Tower-Level und EP | 0 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – | – | – |
| build – Bauen, Belegen, Wege, Lichtpfad, Deckung | 7 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – | – |
| controls – Eingabe, Auswahl, Hover, Pause, Tempo | 7 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – | – |
| visuals – Gemeinsame Shader und visuelle Effekte | 0 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ |
| water – Fließendes Wasser und Wasserfälle | 0 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ |
| mazes – Maze-Vorlagen | 8 | gemeinsam ✓ | – | – | – | – | – | – |
| timed_events – Ereignis-Uhr: alle N Sekunden ein Ereignis aus einem Pool | 0 | – | – | – | – | – | gemeinsam ✓ | – |
| challenges – Endgebiet mit Challenges und Endboss-Tor | 0 | – | – | – | – | – | gemeinsam ✓ | – |

## Modusregeln

- economy / youtd: Gold je Spieler im YouTD-Kern (yt_player.add_gold, Port der Original-Engine)
- economy / heroes: Geldbörse des Helden (hd_shop.add_gold)
- economy / survivors: Einkommen der Waffenplattform (sv_game.income)
- save / shoppingmaul: eigener Spielstand mit Filialen und Gebieten (maul_save.gd)
- waves / eevetd: tickt nur Uhr und Requisiten und ruft dann den gemeinsamen Ablauf (super)
- waves / youtd: mehrere Spawner mit Zufallsabstand aus der YouTD-Engine
- waves / shoppingmaul: Stapel-Spawn mit Obergrenze je Gebiet
