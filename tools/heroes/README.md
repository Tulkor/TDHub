# Bollwerk-Endbosse

Gegner-Kampfpass: `tools/heroes/fx_probe.tscn -- --held=gegner` zeigt Warnungen und Treffer der Sichel-/Kreuz-/Rissformen sowie Orb und Gruppen-Heilfläche in `.godot/fx-gegner.png`. `heroescombat` prüft Geometrie, echte Treffer, Drops, Heilung und Dodge-Iframes aller 24 Helden; `heroesnetstate` prüft zusätzlich die Gruppenheilung und Synchronisierung. Windows-Aufnahmen über `tools/render_windows.ps1`, für Ressourcen-Diagnosen optional `-EngineVerbose`.

## Vollständiger Kader

24 Helden (8 Tanks, 4 Heiler, 12 DDs), Entwurf unter `docs/hero-defense/hero-defense-helden.md`.
`python tools/heroes/kader.py` pflegt die 20 neuen Kits und alle 216 Prägungen;
anschließend `kader_doku.py` und `kader_texte.py` für Dokumentation und Englisch ausführen.
Modelle: `blender --background --python tools/modelle/kader_bau.py -- [--nur=mira,albe]`.
Blender 5.3 reicht ohne weitere Plugins. Die bestehenden vier Modelle werden dabei nicht neu gebaut.
GPU-Galerie: `godot --audio-driver Dummy --path . tools/heroes/kader_probe.tscn -- --clip=idle`
(auch run, attack_combo_finish oder cast_0). Prüfung: `tools/run_tests.sh heroesroster heroesnetstate`.
`python tools/modelle/fluid_qa.py --heroes=brennholt,mira,...` prüft dieselben Haut-/Animationsverträge wie bei den Starthelden.

## Erkundung und Mobilität

`data/heroes_secrets.json` beschreibt 30 Nebenpfade/Höhlen mit Titel, Belohnungsart (`kind`), Zugang (`gate`: `runes|hunt|hidden`), Runenfolge, Thema und Weltpunkten. `HdExploration.choose_sites(rng)` zieht genau acht eindeutige Fundorte: alle sechs Belohnungsarten plus zwei weitere, mit allen drei Zugangsarten. Die Auswahl bleibt pro Partie fest und wird mit Rätsel-/Beutestatus vom Host repliziert. Nur diese acht besitzen Hinweise, Interaktionen und Belohnungen; inaktive IDs werden auch bei direkten Befehlen abgelehnt. Statische Gelände-/Höhlenkonturen bleiben auf allen Peers identisch. Räumliche Abfrage-Bins beschleunigen das Gelände; sechs Architekturthemen verwenden vorhandene Normal-/Specularmaterialien. Mehrere Bossbegegnungen führen getrennte Zustände.

`HdExploration` steuert Runenreihenfolgen, Hinweisspuren, verborgene Öffnungen und Gruppenbeute. Nach vollständig abgeschlossenen Zehnerwellen beginnt eine 300-s-Rast; der Wellenknopf überspringt sie ohne Zusatzgold. Helden erhalten nach fünf Sekunden ohne Kampf 50 % Laufbonus, auch mit Clientvorhersage.

Gezielte Tests: `heroesexplore heroesmobility heroesnetstate heroescoop`. Kartenprofil bearbeiten: `python tools/heroes/lane_layout.py --apply`, prüfen mit `--check` (185,3 m/Lane, ca.65 m gemeinsam, Bounds ±192).

Stumme GPU-Aufnahmen über `tools/render_windows.ps1`: `-OptionsJson '["--szene=heroes","--zeit=0","--erkundung=karte","--lanes=alle","--ohnehud","--weit","--abstand=440"]'`. Für einzelne Eingänge `--erkundung=<Fundort-ID>` (z.B. `glutfalte` oder `eisgrab`), zusätzlich `--hoehle --abstand=45` für den Innenraum. `--seed` macht die Auswahl reproduzierbar; ein ausdrücklich angeforderter Fundort wird für die Aufnahme in die Achter-Auswahl aufgenommen.

## Oberfläche „Eisenliturgie“

Bollwerk verwendet `UiTheme.BOLLWERK` und `scripts/heroes/hd_ui_style.gd`: deckendes Nachtblau, warme doppelte Goldkonturen mit abgeschrägten Ecken/Rautenknoten, Cinzel für Titel und Federo für Fließtext. Die Ornamente sind eine skalierbare `StyleBox`, keine Stockgrafik. `UiTheme.box()` bleibt für bestehende Aufrufer eine `StyleBoxFlat`; individuelle Fähigkeiten verwenden `HdUiStyle.skill_frame()`, Punkteknöpfe `HdUiStyle.upgrade_button()`.

Welle/Feste und Lanes stehen links, Ressourcen mit Tageszeit rechts oben, Ereignisse darunter. Heldenwerte, Fähigkeiten und Inventar sind getrennte untere Bereiche. Unter 1180 Fensterpixeln wandern die Heldenwerte über die Skillreihe; der kompakte Auslöser berücksichtigt Godots logische Stretch-Auflösung. Rückkehr aus Bollwerk stellt den zuvor aktiven Skin wieder her.

```powershell
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/ui_style_check.tscn -Name eisenliturgie-check
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/ui_style_probe.tscn -Name eisenliturgie-kampf -OptionsJson '["--size=1400x900"]'
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/ui_style_probe.tscn -Name eisenliturgie-praegung -OptionsJson '["--size=1400x900","--imprint"]'
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/ui_style_probe.tscn -Name eisenliturgie-1024 -OptionsJson '["--size=1024x768","--layout-check"]'
```

Die Probe zeigt echte Torvik-/Moorgegner-GLBs, Grolms Warnangriff und das Spiel-HUD; `--imprint` öffnet die Prägungswahl. Aufnahmen: `.godot/bollwerk-eisenliturgie-kampf.png` und `...-praegung.png`; `--layout-check` hängt die Auflösung an. Die Probe prüft sichtbare HUD-Rechtecke auf Überlappung und Fenstergrenzen. Die freigegebenen Beispielbilder liegen dauerhaft unter `export/editoren/bollwerk-eisenliturgie-kampf.png` und `...-praegung.png`. `ui_style_check.tscn` prüft Gold-/Navy-Palette, Vektorrahmen, Aufwertungsrauten und Rückwechsel in alle bisherigen Skins.

Nach dem Großangriff in Welle 40 beginnt das Endgebiet „Der Schlund“. Dort wird einmal pro Partie einer der fünf Endbosse gewählt; Tor und Weckuhr verwenden dieselbe gespeicherte Auswahl. Die Kriegsherren in Welle 10/20/30 bleiben erhalten. Die Designs sind eigenständige Figuren mit Raid-Warnmustern und ARPG-Flächenkontrolle; keine übernommenen Figuren oder Assets aus anderen Spielen.

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
- `HdBossCatalog`: Katalog installieren und Auswahl stabil halten. `HdGame.force_final_boss` legt eine Variante für Tests/Vorschauen fest; leer = Zufall. `heroes_endgebiet.json → boss.variants` aktiviert die Auswahl für den Schlund; ohne Varianten gilt weiter `boss.id`. `weaknesses` übersetzt Challenge-Schwächungen in die passende Fähigkeit des jeweiligen Bosses; Lebens-/Heldenboni gelten unverändert.
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

`heroesboss` prüft alle 30 Moves samt Warnzeit/Treffer, Phasen, Rotation, CC-Unterbrechung, Erholung, Limits, Tod durch Heldengeschoss, Übergang W40 → Schlund, Challenge-Schwächungen und Endkampf-Sieg. `heroes` behält für seine bisherigen vier Heldenkampagnen den ursprünglichen Verschlinger als feste Regression. Neue Varianten werden im fokussierten Test geprüft.

Unter Windows vorhandene Wrapper verwenden:

```powershell
./tools/windows.ps1 -Godot C:/tools/godot.exe -Python C:/tools/python.exe -ToolArgs bossdata,heroesboss,heroes,skripte,ui,auswahl
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/boss_probe.tscn -Name boss-gallery
./tools/render_windows.ps1 -Godot C:/tools/godot.exe -Scene res://tools/heroes/boss_probe.tscn -Name boss-fight -OptionsJson '["--kampf=astrael"]'
```

Die GPU-Vitrine schreibt `.godot/boss-gallery.png`, die Kampfvorschau `.godot/boss-fight-<id>.png`. Die Vorschau zeigt eine reproduzierbare Warnphase im Schlund. Die Testauswahl kennt `bossdata` und den Modustest `heroesboss`.

## Steuerung, Fortschritt und Ereignisraum

`tools/run_tests.sh heroesplay heroes` prüft die neuen Abläufe und die bestehende KI. `heroesplay` startet alle 46 Events und vergleicht den räumlichen Suchbereich mit einer vollständigen Suche bei 1024 Gegnern (Ausgabe `MESSUNG`). Der Kandidatenvergleich misst Suchaufwand, keine FPS oder Netzwerklatenz. `koop syscoop gemischt` prüfen den betroffenen gemeinsamen Netzwerkpfad.

GPU-Vorschauen: `tools/heroes/play_probe.tscn`, optional `-- --event` oder `-- --imprint`. Unter Windows mit `tools/render_windows.ps1 -Godot <exe> -Scene res://tools/heroes/play_probe.tscn -Name bollwerk-event -OptionsJson '["--event"]'`. Die Aufnahme liegt unter `.godot/bollwerk-event.png`, weitere Namen `bollwerk-lanes.png` und `bollwerk-imprint.png`.

Fähigkeitswerte kommen aus `heroes_helden.json`, Rangfaktoren/Tags/Prägungen aus `heroes_progression.json`; `HdSkills.add_modifier(id, tags, mods)` ist der Einstieg für passende Powerups. Alle angegebenen Tags müssen zutreffen. Ausführung und Tooltip lesen `hero.ability(slot)`, keine separaten UI-Basiswerte. Ereignisse ausschließlich über `events.start(id)` starten, damit Isolation, Teleport und Rückkehr greifen. `persist_settings=false` isoliert Test-/Probe-Einstellungen.

Für Windows-Regressionen mit echtem Renderer: `tools/render_windows.ps1 -Godot <exe> -Scene res://tests/heroes_test.tscn -Name heroes-full-gpu -OptionsJson '["--gpu-profil"]'`. Eigenes Profil verhindert Überschneidungen mit Headless-Läufen; `--nur=ki` grenzt Aggro/Rückkehr gezielt ein. Ergebnisse stehen in `.godot/heroes-full-gpu.log`, Fehler separat.

## Koop und Tageszeit

Nach fünf `--arena=<id>`-Fotos und `--schlund=varkhun` erzeugt `python tools/heroes/bosse.py --kontakt` den beschrifteten Kontaktbogen unter `export/editoren/bollwerk-arenen-kontakt.png` (Pillow). Der normale Datencheck braucht weiterhin keine Bildbibliothek.

`boss_probe.tscn -- --weg=varkhun --nacht` fotografiert den Portalweg im jeweiligen Bossmotiv bei Nacht; `--weg=nerathis` zeigt die Gezeitenvariante. Der neue Skizzen-Grundriss hat sechs symmetrische Seitenarme mit eigenen Kammern, einen langen Hauptweg und die Bossplattform am oberen Ende. `HdFinalLayout` liefert sowohl sichtbare Bodenflächen als auch Bewegungsgrenzen; außen liegen unpassierbare Felsbereiche. Risse, Wasseradern, Wurzeln, Zeitbrüche und Leerenfugen bleiben rein optisch. Ausgaben `.godot/schlund-weg-<id>.png` (Nachtoption überschreibt dieselbe Fotodatei). `heroesfinal` prüft Erreichbarkeit aller Kammern, Grenzen und die echte sechste Challenge Schattenschar.

Der Schlund besitzt einen gemeinsamen Challenge-Vorplatz und einen kleineren runden Bosskampfplatz hinter dem Tor. `HdFinalStyle` wählt das Design mit derselben stabilen Boss-ID wie die Begegnung: Kettenschmiede (Varkhun), Sturmflut (Nerathis), Dornenfäulnis (Morvath), Gebrochene Zeit (Astrael), Kosmischer Schlund (Zharok). Die reine Darstellung fügt keine Kollisionshindernisse im Kampfbereich hinzu. `boss_probe.tscn -- --arena=varkhun` fotografiert einen Kampfplatz, `--schlund=varkhun` das ganze Gebiet; alle fünf IDs sind nutzbar. Beide fotografieren ohne HUD, reduzieren Fernnebel und blenden kurzlebige Ankunfts-FX aus. `--kampf=astrael` behält die normale Kampfoberfläche und eine Warnphase. GPU-Aufnahmen liegen in `.godot/arena-<id>.png` bzw. `.godot/schlund-<id>.png`.

In der Lobby Bollwerk wählen und gemeinsam starten (bis 8 Spieler). Jeder wählt vor dem Host-Start seinen Helden; der Host wählt Lanes/Schwierigkeit. Jeder besitzt eigene Ausrüstung und Fähigkeitspunkte. Tötungs-EP/Gold und Wellenbelohnungen gehen an die Gruppe; Entscheidungen/Prägungen sind gemeinsame Weltentscheidungen. Ausweichen und Bewegung werden lokal vorausberechnet, Schaden/Items/Wellen bleiben beim Host. Test `heroescoop` verwendet zwei echte ENet-Prozesse; `heroesnetstate` prüft acht Helden und verlorene/ungeordnete Fragmente.

`game.time_of_day()` liefert die Stunde 0..24; `game.is_night()` den booleschen Zustand. Werwolf-Haken: `game.day_cycle.period_changed.connect(func(night): ... )`. `time_changed(hour)` liefert Uhrupdates, `phase()` unterscheidet dawn/day/dusk/night. Die Uhr stammt aus eeveTD (`DayCycle`), läuft in Bollwerk an der autoritativen Simulationszeit und pausiert bei Spielpause. Start/Tempo in `heroes.json → day_cycle`.

Skriptbeispiel im Item-Editor: `OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))`. Effektumfang, `Native` für Tower, echte `Invoke`-IDs und explizite Modusgrenzen stehen unter `scripts/systems/effect_script/README.md`. Item-Export ersetzt den vollständigen `data/heroes_items.json`-Katalog; der Editor verändert diese Datei nicht ohne Export/Übernahme.
# Angriffsanimationen als animierte WebPs

Waffenprüfung für den vollständigen Kader: `python tools/modelle/weapon_qa.py`; Bericht unter `docs/hero-defense/waffen-pruefung-2026-11-16.md`. Nach Aufnahmen mit `attack_probe` erzeugt `python tools/heroes/attack_clips.py --kontakt` vier Prüfbögen für alle 23 bewaffneten Helden. Freie Vergleichsgalerie: `--galerie --helden=torvik,sirra,varg,sorek`. Aktuelle gemeinsame Schleife: `export/videos/bollwerk-waffen-geprueft-2026-11-16.webp`.

Lane-Profil: `python tools/heroes/lane_layout.py --apply` baut acht symmetrische, gestreckte Straßen aus WEST; `--check` prüft die Daten. Nur der separate Anmarsch wird gespiegelt, der gemeinsame Schluss bleibt identisch. Für vollständige Kartenbilder `screenshot.tscn -- --szene=heroes --zeit=0 --lanes=alle --ohnehud --weit --abstand=340`: alle acht Lanes und 16 Torwerke, unabhängig von der Solo-Vorgabe mit zwei aktiven Lanes.

Gothic-Grafik prüfen: `boss_probe.tscn -- --modell=varkhun` (auch nerathis/morvath/astrael/zharok) zeigt das echte Bossmodell einzeln; `bosse.py --modelle` erzeugt einen beschrifteten Kontaktbogen. Hauptmap über `screenshot.tscn -- --szene=heroes --zeit=0 --weit --ohnehud`, Nacht mit `--nacht`. Detailaufnahme `--punkt=-33,-15 --abstand=65`; für den Kontaktbogen als `export/screens/bollwerk-gothic-detail_bild.png` speichern. Immer den stummen Windows-Renderwrapper nutzen.

Alle vier Helden vergleichen: `attack_probe.tscn -- --held=<id> --clip=run` je Held, anschließend `python tools/heroes/attack_clips.py --galerie --clip run`. Für Angriffe Torvik/Unrat mit `--combo`, Vesna/Zix ohne Zusatz aufnehmen; `attack_clips.py --galerie` erzeugt die gemeinsame Angriffsübersicht. Echte GPU-Aufnahmen, stumm über `render_windows.ps1`; Weichgewichte/Nachlauf über `tools/riggen.py weich`.

König Unrat: `python tools/riggen.py bauen tools/modelle/rig_profiles/unrat.json` erzeugt drei Szepterschläge (der dritte ist der schwere Abschluss). GPU: `attack_probe.tscn -- --held=unrat --combo`, dann `attack_clips.py --held unrat --combo`. `--schlaege=3` wiederholt dagegen nur einen einzelnen Clip dreimal.

Für die Beurteilung von Hieb/Stich `attack_probe.tscn -- --held=brennholt --combo --profil`: echte Seitenkamera und gerade Modellausrichtung, sonst unveränderte Aufnahme. Die Seitenkamera überschreibt denselben Aufnahmeordner; vorherige Perspektiven vor dem nächsten Lauf sichern.

Schneller bearbeiten: `python tools/riggen.py bauen tools/modelle/rig_profiles/torvik.json`. Gemeinsames Rig-/Zielpunkt-/Handgelenkwerkzeug für künftige Helden: `tools/modelle/RIGGEN.md`. Torviks Äxte führen bei allen drei Varianten von außen nach innen in den Bereich vor dem Rumpf; Dual Strike beginnt hoch, der Überkopfhieb noch höher. `weapon_qa.py` prüft neben der Schneidenausrichtung auch diese Bewegungsrichtung und Treffzone.

Torvik hat drei eigenständige Clips: `attack_cleave` (Seitenschwung), `attack_dual_strike` (gleichzeitiger Axtschlag), `attack_overhead` (Überkopfhieb). Posen bearbeiten in `tools/modelle/torvik_angriffe.py`, anschließend das Skript ausführen und Godot importieren; `--check` prüft den GLB-Stand. Der Blender-Neubau verwendet dieselben Posen. Im Spiel wechseln die Clips über `attack.animations`, andere Helden behalten ihren bisherigen Clip. `attack_probe.tscn -- --held=torvik --clip=<name>` nimmt eine Variante auf; `attack_clips.py --torvik-variants` erstellt die drei WebPs.

`attack_probe.tscn -- --held=torvik|unrat|vesna|zix` nimmt die echte `attack`-Animation der GLB-Modelle auf neutraler Bühne auf (80 Frames, 20 fps). Zix zeigt dabei dieselbe frontale Entladung wie im Spiel; die übrigen Aufnahmen zeigen nur die Modellanimationen. Die Bühne endet exakt auf y=0 für die Sohlenkontrolle. Unter Windows `tools/render_windows.ps1` mit dieser Szene verwenden: immer stumm. Danach `python tools/heroes/attack_clips.py` mit Pillow ausführen; prüft tatsächliche Bewegung und schreibt Schleifen nach `export/videos/bollwerk-<held>-angriff.webp`.

Hangkuppe und Boden-FX gemeinsam prüfen: `play_probe.tscn -- --hang` setzt den Helden auf einen tatsächlich begehbaren Hang und zeigt dort eine an das echte Höhenfeld angepasste Heilfläche. Ausgabe `.godot/bollwerk-hang-heilflaeche.png`. Die Probe bleibt stumm und verändert keine Modell-/Animationsdateien.

Naturvorschau: `play_probe.tscn -- --natur` zeigt Unterholz und einen reproduzierbaren Vogelflug. `--ohneunterholz` blendet nur die Pflanzen aus; `screenshot.tscn -- --szene=heroes --punkt=-110,-60 --abstand=50 --messen=3 [--ohneunterholz]` nutzt die bestehende Leistungsmessung. Windows immer über `render_windows.ps1`: Bildschirm 2, keine Fokusübernahme, Dummy-Audio.

Automatischer Geländenaht-Test (gesamte Karte, inklusive äußerem Waldrand):
`./tools/render_windows.ps1 -Godot <exe> -Scene res://tests/heroes_terrain_seams_test.tscn -Name terrain-seams`
Mit `-OptionsJson '["--niedrig"]'` die niedrige Grafikstufe prüfen. Der Test untersucht jede offene Meshkante auf Höhen-/Normalsprünge und vergleicht Boden und Bergfuß unter identischer Beleuchtung in eigenen Viewports, jeweils mit und ohne Bewuchs. Ein absichtlich rotes Material muss als Kontrollfehler erkannt werden; leere oder strukturlose Bilder sind ungültig. Toleranzen: mittlere maximale Kanalabweichung 0,008; höchstens 1,5 % Pixel über 0,045 Kanalabweichung. Geometriekanten: maximal 12 mm Abstand zum Grund, höchstens 2° Normalsprung. Bei Fehlern Exit 1 und Bilder `res://.godot/terrain-seams-*-boden.png`, `*-hang.png`, `*-abweichung.png`; keine manuell gewählten Bildpunkte. Headless wird die Geometrie geprüft und der fehlende Bildvergleich ausdrücklich als SKIP gemeldet. Für vollständige QA den echten Windows-Renderer verwenden.

Z-Fighting-Prüfung: `./tools/render_windows.ps1 -Godot <exe> -Scene res://tests/heroes_z_fighting_test.tscn -Name z-fighting -TimeoutSeconds 360` (optional `-OptionsJson '["--niedrig"]'`). Erfasst sichtbare statische, opake Geometrie der Karte, Bauwerke, Mauern, Ruinen und Geheimzugänge. Alpha-/Partikeleffekte, animierte Skins und Pflanzen-Scatter werden nicht als opake Tiefenlagen behandelt. Vier Gesamtansichten inklusive leicht versetzter Kamera plus neun Kachelansichten werden mit umgekehrter Dreiecksreihenfolge verglichen. Farbcodierte Materiallagen und Strahl-/Ebenenprüfung unterscheiden koplanare Überlagerungen von bloßen Kantenkontakten. Jeder geometrisch bestätigte Z-Fighting-Pixel lässt den Test fehlschlagen. Eingespritzte Kontrollflächen prüfen den vollständigen Detektor; 2 cm Abstand müssen den Konflikt beseitigen. Bericht: `.godot/z-fighting-report.json`; bei Befunden A/B-/Fehlerbilder plus betroffene Knoten/Instanzen und Weltpositionen. Headless meldet den GPU-Test ausdrücklich als SKIP. Geometriekorrekturen am im Bericht bezeichneten Builder vornehmen und erneut prüfen.

Tag-Nacht-Aufnahme an vier Orten: `tools/render_windows.ps1 -Godot <exe> -Scene res://tools/heroes/day_cycle_probe.tscn -Name bollwerk-tag-nacht -TimeoutSeconds 480`. Der echte 22-Minuten-Zyklus wird über `DayCycle.advance` auf 240 Frames abgebildet; Feste, Kathedralbezirk, Wald und Schmiede werden pro Uhrzeit aus derselben Szene aufgenommen. Danach `python tools/heroes/day_cycle_clip.py` für Beschriftung/WebP, und Blender 5.3 mit `--background --factory-startup --python-exit-code 1 --python tools/heroes/day_cycle_clip.py -- --blender` für MP4. Blender 5.3 benötigt vor FFMPEG `render.image_settings.media_type='VIDEO'`; VSE-API ist `sequence_editor.strips`. `-- --verify` dekodiert einen Tag- und Nachtframe zur Farb-/Lesbarkeitskontrolle. Ausgaben: `export/videos/bollwerk-tag-nacht-vier-orte.mp4` und `.webp`, 24 Sekunden; keine Änderung der Spiellogik oder der Tageslichtwerte.

Gehwege/Laternen: `play_probe.tscn -- --gehwege [--insel] [--nacht] [--weit] [--niedrig]` sucht eine Gruppe verbundener Gebäude; `--insel` fokussiert stattdessen eine bepflanzte Tasche mit Hofbaum. Meldet Wege, Laternen, geräumte Bäume und bepflanzte Inseln samt Baum-Geometriebudget. Bilder unter `.godot/bollwerk-gehwege-*.png`. Stets den Windows-Renderwrapper nutzen.

Stadtgrundriss: `play_probe.tscn -- --gehwege --stadt [--niedrig]` zeigt die ganze Bollwerk-Stadt bei Tageslicht (nur für das Foto reduzierter Fernnebel). `.godot/bollwerk-stadt-tag[-niedrig].png`; `STADT_GRUNDRISS` muss auf Hoch/Niedrig identisch sein, damit Gebäudehindernisse im Koop dieselben Positionen haben. Normale Gehwegansicht zeigt die bewohnten Viertel näher.
