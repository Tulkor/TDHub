# Hinweise für Claude

Diese Datei wird bei jedem Schritt jedes Threads mitgeschickt, deshalb steht hier nur der Kern. Details je Bereich liegen in `docs/claude/` und kommen automatisch dazu: Der Hook `.claude/hooks/thema.py` blendet die passende Notiz einmal pro Thread ein, sobald Dateien des Bereichs angefasst werden. Von Hand lesen nur, wenn man vorher etwas wissen muss:
`gemtd.md` (game.gd, Tower, Effekte, HUD, Debug, Roguelike, Spielstand, Profil, Spielfeld-Stil, Karte) · `netz.md` · `maul.md` · `eeve.md` · `randgruppen.md` · `youtd.md` · `survivors.md` · `heroes.md` (Bollwerk, Hero Defense) · `werkzeuge.md` (Build/Release, Screenshots, Balance-/HTML-Editor, Texte, Effekte, Modelle, WC3, Tests schreiben).
Neues Wissen zu einem Bereich in dessen Notiz eintragen, nicht hier; neue Notiz = Datei plus Eintrag in `THEMEN` in `thema.py`.

## UI-Stil je Modus (Lukas will das nicht jedes Mal sagen müssen)
- GemTD Arcade: alles aus `scripts/ui/ui_theme.gd`, keine eigenen Farben/Schriften. `UiTheme.panel(pad)` (eckig, pinker Rand, harter Cyan-Schatten), `UiTheme.title(label, size)`, kleine Abschnittstitel Großbuchstaben fett (`UiTheme.font(true)`), Hauptaktion `UiTheme.accent_button(...)`, ausgewählt `UiTheme.box(UiTheme.CYAN, UiTheme.CYAN)` mit dunkler Schrift. Farben `TEXT MUTED GOLD CYAN COIN HAVE MISSING PURPLE_LIGHT`. Schrift DejaVu Sans Mono, Ecken eckig, lange Texte mit Autowrap.
- eeveTD Druidenhain, Randgruppen TD Plakatwand: gleiche `UiTheme`-Namen über `UiTheme.use_skin(...)`, Details in `eeve.md`/`randgruppen.md`. UiTheme-Farben sind `static var`, nicht in `const`-Ausdrücken.
- Hub (Startseite), Einzelspieler und Lobby im Warcraft-III-Stil (Lukas 2026-10-30/11-01, Mockups unter /mnt/project-files/mockups/wc3-menu/ und wc3-lobby/): `scripts/ui/wc3_*.gd` (Theme mit Cinzel, Steintafeln `Wc3Pillar`, spitze Knöpfe `Wc3Button`, Map-Karten `Wc3Card`, Messing als 3D-Renders aus `tools/menu/messing_blender.py` mit Glanz-Shader, 3D-Logo aus `tools/menu/td_hub_logo.py`, 3D-Nachtszene), Bild `tools/screenshot.sh --szene=menu [--seite=single|lobby]`.
- Profil mit Run-History im WC3-Stil wie der Hub (`profile_panel.gd`, Mockups /mnt/project-files/mockups/wc3-profil/).
- Tower Survivors: Hologramm (`UiTheme.use_skin(UiTheme.HOLO)`, `holo_theme.gd`/`holo_box.gd`, Bausteine `sv_holo.gd`), halbtransparent, Cyan-Linien, Details in `survivors.md`.
- Übrige Menüs vor dem Spiel (Spiel laden, Maul-Filialwahl) und Shopping Maul: Art déco aus `scripts/ui/deco_theme.gd` (gleiche Namen; Petrol + Messing, doppelte Messingrahmen `DecoTheme.panel`/`DecoBackdrop`, Hauptknopf mit spitzen Enden; ab 28 px Limelight kräftig `DecoTheme.title`/`display`, kleiner Federo). Startfenster im Spiel folgen dem Modus: `setup_panel.gd` Arcade, `eeve_setup_panel.gd` Druidenhain, nur Maul Art déco.
- Alle sichtbaren Texte auf Deutsch, Übersetzung in `data/i18n/en.json` (`python3 tools/pruefe_ui.py --vorlage`/`--eintragen=`). Ohne gespeicherte Wahl startet das Spiel auf Englisch (`Loc.DEFAULT`, Lukas 2026-10-28), deshalb brauchen auch Daten-Texte über `tr()` einen Eintrag; `run_tests.sh` setzt `GEMTD_SPRACHE=de`.

## Threads: ein Feature, ein Thread (feste Regel von Lukas)
Jeder Schritt schleppt den ganzen Verlauf mit. Größere Features bekommen einen frischen Thread, Kategorie-Threads (Game-Systeme, UI und UX, Balance, Grafik) nur für Kleines. Fertig + gemergt = Thread schließen; was später gebraucht wird, steht im Repo oder unter /mnt/project-files/.

## Werkzeuge: erst diese, statt Abläufe neu zu schreiben
Godot installiert der Session-Start-Hook, `godot` liegt in `~/.local/bin`. Grundsatz: Wiederkehrendes läuft über Skripte, Claude startet sie und liest nur deren Kurzausgabe. Fehlt eines für etwas, das öfter vorkommt, eines dazuschreiben.
- Thread-Start: `tools/lage.sh`. Vor PR/Merge: `tools/vor_pr.sh [--alle]` (zieht main nach, passende Tests, Stil, endet mit `BEREIT`/`NICHT BEREIT`). Main nachziehen: `tools/main_nachziehen.sh [--tests]`.
- PRs ohne GitHub-Abfragen: `tools/prs.sh offen` (ungemergte PRs mit Dateien und Überschneidungen), `tools/prs.sh sammeln 72 73 …` (PR-Stände nacheinander in den aktuellen Branch mergen, hält bei Konflikt mit den Stellen an, danach `weiter`), `tools/prs.sh text` (PR-Text-Entwurf aus den Commits). GitHub-MCP nur noch für PR anlegen/mergen.
- Tests: `tools/run_tests.sh [geaendert|schnell|alle|<namen>]`, eine Zeile pro Test, Logs `/tmp/gemtd-tests/`. Roter Test: `tools/log_auszug.sh <test>`. `⚠`-Zeilen sind echte Godot-Fehler, beheben. Neuer Test: `tests/<name>_test.gd` + `.tscn`, zweite Zeile `## Lauf: einzeln|paar|trio|fest …`, dritte `## Modi: <modus-id>|kern` (Testauswahl je Modus über `tests/bereiche.json`, mehr in `werkzeuge.md`).
- Lange Befehle (Build, Import, Umwandeln, pip, große Skripte): `tools/kurz.sh [--name=x] <befehl …>` schreibt das volle Log nach `/tmp/gemtd-kurz/`, zeigt nur Exit, Fehlerzeilen und Schluss.
- Screenshots: `tools/screenshot.sh …`, nur die Zeile `ANSICHT <jpg>` lesen. Vorher/nachher: `python3 tools/bildvergleich.py alt.png neu.png` sagt, ob und wo sich etwas geändert hat; Bild nur ansehen, wenn es sich geändert hat (dann das Vergleichsbild).
- Code lesen: Dateien über 300 Zeilen nicht ganz (Hook blockt). `python3 tools/gliederung.py <datei|ordner> [--suche=wort|--funktion=name]`. Daten: `python3 tools/daten.py tower:ruby|gegner:bat|wellen|<datei> <pfad>`. Werte ändern: `python3 tools/werte_setzen.py tower:ruby 'tiers.*.range*=1.1' [--bericht]`.
- Hochgeladene Pakete (Zip/Ordner): `python3 -I tools/paket.py <zip|ordner>…` zeigt Inhalt nach Art und erkennt die Lizenz (CC0/CC-BY/OFL/NC/Store/unklar), statt `unzip -l` oder Lizenzdateien zu lesen.
- Build nur auf Lukas' ausdrückliche Frage: `tools/build_windows.sh` (Ablauf und Release in `werkzeuge.md`).

## Lizenzen von Assets (Regel von Lukas)
Ins Repo nur, was in einem öffentlichen Repo liegen und mit dem Spiel verkauft werden darf: CC0 bevorzugt, sonst CC-BY/OFL mit Nennung, Pixabay ok. Nicht: NC, Asset-Store-/Stock-Lizenzen ohne Weitergaberecht, unklare Herkunft. Quelle und Lizenz in der CREDITS.md/QUELLEN.md des Ordners.

## Code-Landkarte (Kern)
- `scripts/autoload/`: `database.gd` (alle JSON-Daten: `Database.towers`, `.enemies`, `.wave_sets`, `.balance`, `.modes`, `list_maps()`), `session.gd` (Werte zwischen Szenen), `loc.gd`, `display.gd`, `net.gd` (ENet, Lobby, Sitzungen).
- `scripts/game/game.gd`: Spielablauf, alle Spieleraktionen als Befehle `submit(cmd)` → `execute`, im Koop rechnet der Host. Die anderen Modi erweitern game.gd (`eeve_game.gd`, `rg_game.gd`, `youtd_game.gd`), Maul hat `scripts/maul/maul_game.gd`. Modi in `data/modes.json`, Maps über ihr Feld `game`.
- Oberfläche: `hud.gd` und Bausteine in `scripts/ui/`. Karte/Feld: `scripts/map/`. Netz: `scripts/net/`. Daten: `data/`. Tests: `tests/`.
