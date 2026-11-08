# Spielsysteme × Modi

Erzeugt mit `python3 tools/systeme.py matrix --md`, nicht von Hand ändern. eigen (n) = der Modus baut das System noch selbst (n erkannte Funktionen), geerbt = über game.gd, gemeinsam = nutzt scripts/systems/ bzw. die gemeinsame Klasse. ✓ = in data/modes.json angekreuzt.

| System | Etappe | gemtd | eevetd | randgruppen | youtd | shoppingmaul | heroes | survivors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| run_record – Run-Ende, Profil, Debug-Run, Abbruch | 2 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ |
| difficulty – Schwierigkeit und Aufstieg | 2 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – |
| targeting – Ziele finden, Gegner im Kreis, nächster Gegner | 3 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ |
| economy – Gold, Einkommen, Leben, Leak-Strafe | 4 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | eigen (1) ✓ | gemeinsam ✓ | eigen (1) ✓ | eigen (1) ✓ |
| save – Spielstand, Autosave | 4 | eigen (4) ✓ | geerbt ✓ | geerbt ✓ | geerbt ✓ | eigen (1) ✓ | – | – |
| waves – Spawn-Warteschlange, Auto-Welle | 5 | gemeinsam ✓ | eigen (1) ✓ | gemeinsam ✓ | eigen (1) ✓ | eigen (1) ✓ | gemeinsam ✓ | gemeinsam ✓ |
| coop – Koop-Abgleich: Snapshot und Befehle | 6 | eigen (1) ✓ | eigen (3) ✓ | eigen (4) ✓ | eigen (3) ✓ | – ✓ | – | – |
| inventory – Item-Plätze, Items auf Tower ziehen | 6 | eigen (4) | eigen (4) ✓ | geerbt | eigen (4) ✓ | eigen (3) ✓ | gemeinsam ✓ | – |
| leveling – Tower-Level und EP | 0 | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | gemeinsam ✓ | – | – | – |
| build – Bauen, Belegen, Wege, Lichtpfad, Deckung | 7 | eigen (13) ✓ | geerbt ✓ | geerbt ✓ | eigen (4) ✓ | eigen (11) ✓ | – | – |
| controls – Eingabe, Auswahl, Hover, Pause, Tempo | 7 | eigen (6) ✓ | eigen (3) ✓ | eigen (3) ✓ | eigen (4) ✓ | eigen (5) ✓ | – | – |
