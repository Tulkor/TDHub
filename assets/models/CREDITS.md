# Modelle

Alle Modelle stehen unter CC0 (Public Domain), außer dem Boss-Modell (CC-BY 3.0, siehe unten).

- `crystals/crystal_*.glb`: "Crystal Pack" von iPoly3D, https://poly.pizza/bundle/Crystal-Pack-AywAG7aywi
- `crystals/quaternius_*.glb`: "Crystal" und "Big Crystal" von Quaternius (poly.pizza)
- `rocks/*.glb`: "Rock" und "Rock Large" von Quaternius (poly.pizza)

Die Kristalle werden im Spiel in der Farbe des Towers eingefärbt (Feld "color" in data/towers/*.json).

- `special/*.glb`: Quaternius (CC0), von Lukas hochgeladen: `crystal_tree_1..3` (Tree_Blob), `lava_tree` (Tree_Lava),
  `gold_ore` (Resource_Gold). Werden mit eigenen Farben verwendet ("model_tint": false in den Tower-Daten).
  `platonic.glb`: ebenfalls von Lukas (laut ihm auch Quaternius).

## CC0-Pakete für eeveTD und Shopping Maul (2026-10-19)

Von Lukas hochgeladen, Lizenztexte in `licenses/`. Nur die verwendeten Modelle liegen im Repo, umgewandelt
mit `tools/modelle/umwandeln.py` (Auswahl in `tools/modelle/auswahl.json`, Texturen eingebettet und auf 256 px verkleinert).

- `nature/` (eeveTD-Tower, Gärtnerei und Bestatter im Shopping Maul):
  - Bäume, Büsche, Pflanzen, Blumen, Pilze, Felsen (`common_tree_*`, `pine_*`, `bush_*`, `plant_*`, `fern_1`,
    `flower_*`, `mushroom_common`, `mushroom_laetiporus`, `rock_medium_*`): "Stylized Nature MegaKit" (Standard)
    von Quaternius, CC0, https://quaternius.com/packs/stylizednaturemegakit.html
  - Statuen, Obelisken, Feuerstellen, Steine, Topf, Seerose, Pilzgruppen (`statue_*`, `stone_tall_*`, `rock_tall_*`,
    `campfire_stones`, `campfire_bricks`, `pot_large`, `lily_large`, `mushroom_red_*`, `mushroom_tan_group`):
    "Nature Kit" 2.1 von Kenney, CC0, https://kenney.nl/assets/nature-kit
  - `campfire_pit`: "Survival Kit" 2.0 von Kenney, CC0, https://kenney.nl/assets/survival-kit
- `city/` (Shopping-Maul-Tower):
  - Häuser `1story*` bis `6story_stack`: "Ultimate Textured Building Pack" (Dec 2019) von Quaternius, CC0
    (laut quaternius.com; das Zip enthält keinen Lizenztext). Verwendet sind die Varianten mit Materialien
    ("_Mat"); das Material "Main" färbt das Spiel in der Filialfarbe ein.
  - `building_skyscraper_*`: "City Kit (Commercial)" 2.1 von Kenney, CC0, https://kenney.nl/assets/city-kit-commercial

Ebenfalls hochgeladen, aber noch nicht verwendet (bei Bedarf über `auswahl.json` holen): Kenney City Kit Suburban,
Kenney Modular Buildings (beide CC0).

## Gegner-Modelle (CC0, 2026-10-21)

- `enemies/skeleton.glb`, `slime.glb`, `dragon.glb`, `bat.glb`: "Animated Monster Pack" von Quaternius, CC0
  (Lizenztext in `licenses/quaternius_animated_monsters.txt`), von Lukas hochgeladen. Umgewandelt mit
  `tools/modelle/monster_umwandeln.py` (Blender): Animationen umbenannt in `walk`, `idle`, `hit`, `death`, Materialien
  deckend gemacht, Augen-Skelett starr an den Kopf gehängt. Im Spiel (`scripts/game/enemy.gd`, `MONSTERS`):
  Skelett = Bodengegner, Schleim = Massenwelle, Drache = Flieger, Fledermaus = Massenflieger; ein Material wird in
  Richtung der Gegnerfarbe eingefärbt.

## eeveTD-Umgebung: Friedhof, Kirche, handgemalte Pflanzen (CC0, 2026-10-21)

Von Lukas hochgeladen, Lizenztexte in `licenses/`. Verwendet in `scripts/map/eeve_scenery.gd`.

- `scenery/gravestone_*`, `cross_wood`, `grave`, `urn_round`, `crypt`, `iron_fence*`, `lightpost_single`:
  "Graveyard Kit" 5.0 von Kenney, CC0, https://kenney.nl/assets/graveyard-kit (über `tools/modelle/umwandeln.py`)
- `scenery/church.glb`: "Medieval Church" von Daniel74, CC0, Blend Swap 75990 (http://www.blendswap.com/blends/view/75990).
  Umgewandelt mit `tools/modelle/kirche_umwandeln.py`: Statue im Inneren entfernt, Texturen neu zugeordnet und auf 256 px verkleinert.
- `nature/hp_*.glb`: "HandPainted Plants 2" von Nobiax / Yughues, CC0 (Pflanzen-Karten mit Alpha, Textur über das Feld
  `textur` in `tools/modelle/auswahl.json`).

- `scenery/tiere/deer.glb`, `stag.glb`, `fox.glb` (laufen im Hauptmenü hinten vorbei): "Ultimate Animated Animal Pack"
  von Quaternius, CC0, https://quaternius.com/packs/ultimateanimatedanimals.html (`licenses/pakete/quaternius_cc0.txt`)
- `scenery/mine_*.glb` (Bergwerk mit Lore unterhalb des Friedhofs): "Free Mine Assets Pack", CC0, OpenGameArt
  (https://opengameart.org/content/free-mine-assets-pack; das Zip selbst enthält keinen Lizenztext, Lizenz laut Lukas
  und Seite CC0). Umgewandelt mit `tools/modelle/mine_umwandeln.py`: Materialien neu aufgebaut, Schienen flach gelegt,
  Texturen auf 256 px.

## Boss-Modell (CC-BY 3.0, Nennung Pflicht)

- `enemies/little_man.glb`: Little Man by Don Carson [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/8KU4S7I0sL8)
  - Von Lukas hochgeladen (2026-10-20). Geändert: Skelett und Animationen `walk`, `idle`, `hit`, `death` ergänzt, Arme aus der T-Pose nach unten gelegt,
    Füße auf den Ursprung gesetzt (`tools/modelle/boss_rig.py`, Blender). Wird für alle Gegner mit `"boss": true`
    ohne eigenes Modell verwendet (`scripts/game/enemy.gd`, `BOSS_MODEL`).

## Modell-Bibliothek `pakete/` (CC0, 2026-10-28)

Ganze Pakete, von Lukas heruntergeladen, umgewandelt mit `tools/modelle/pakete_umwandeln.py` (Liste in
`tools/modelle/pakete.json`). Eine .glb je Modell, Texturen auf 256 px verkleinert und je Paket in `texturen/`
geteilt. Der Ordner hat eine `.gdignore`: Godot importiert ihn nicht, er landet nicht im Build. Wer ein Modell im
Spiel braucht, holt es wie bisher über `auswahl.json` (Paket `pakete=assets/models/pakete`). Welche Modelle es gibt,
steht in `pakete/<id>/LISTE.txt`. Alle Pakete stehen unter CC0 1.0 (Public Domain), Lizenztexte in `licenses/pakete/`
(Quaternius-Pakete ohne eigenen Text im Zip: `licenses/pakete/quaternius_cc0.txt`).

- `pakete/q_downtown/` (153): "Downtown City MegaKit (Standard)" von Quaternius, CC0, https://quaternius.com/packs/downtowncitymegakit.html (`licenses/pakete/q_downtown.txt`)
- `pakete/q_medieval/` (176): "Medieval Village MegaKit (Standard)" von Quaternius, CC0, https://quaternius.com/packs/medievalvillagemegakit.html (`licenses/pakete/q_medieval.txt`)
- `pakete/q_basis_figuren/` (10): "Universal Base Characters (Standard)" von Quaternius, CC0, https://quaternius.com/packs/universalbasecharacters.html (`licenses/pakete/q_basis_figuren.txt`)
- `pakete/q_fantasy_outfits/` (24): "Modular Character Outfits - Fantasy (Standard)" von Quaternius, CC0, https://quaternius.com/packs/modularcharacteroutfitsfantasy.html (`licenses/pakete/q_fantasy_outfits.txt`)
- `pakete/q_fantasy_props/` (94): "Fantasy Props MegaKit (Standard)" von Quaternius, CC0, https://quaternius.com/packs/fantasypropsmegakit.html (`licenses/pakete/q_fantasy_props.txt`)
- `pakete/q_figuren/` (52): "Ultimate Animated Character Pack" von Quaternius, CC0, https://quaternius.com/packs/ultimatedanimatedcharacter.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_modular_maenner/` (11): "Ultimate Modular Men Pack" von Quaternius, CC0, https://quaternius.com/packs/ultimatemodularcharacters.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_wohnung/` (123): "Ultimate House Interior Pack" von Quaternius, CC0, https://quaternius.com/packs/ultimatehomeinterior.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_feldfruechte/` (102): "Ultimate Crops Pack" von Quaternius, CC0, https://quaternius.com/packs/ultimatecrops.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_tiere/` (12): "Ultimate Animated Animal Pack" von Quaternius, CC0, https://quaternius.com/packs/ultimateanimatedanimals.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_zombie/` (64): "Zombie Apocalypse Kit" von Quaternius, CC0, https://quaternius.com/packs/zombieapocalypsekit.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_monster/` (50): "Ultimate Monsters" von Quaternius, CC0, https://quaternius.com/packs/ultimatemonsters.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_suesse_monster/` (21): "Cute Animated Monsters Pack" von Quaternius, CC0, https://quaternius.com/packs/cutemonsters.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_cyberpunk/` (71): "Cyberpunk Game Kit" von Quaternius, CC0, https://quaternius.com/packs/cyberpunkgamekit.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_geschuetze/` (37): "Steampunk Turret Pack" von Quaternius, CC0, https://quaternius.com/packs/turretpack.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_ruinen/` (92): "Ultimate Modular Ruins Pack" von Quaternius, CC0, https://quaternius.com/packs/ultimatemodularruins.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_bauernhof/` (7): "Farm Animal Pack" von Quaternius, CC0, https://quaternius.com/packs/farmanimal.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_schiffe/` (6): "Ships Pack" von Quaternius, CC0, https://quaternius.com/packs/ships.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_zug/` (14): "Modular Train Pack" von Quaternius, CC0, https://quaternius.com/packs/modulartrain.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_roboter/` (1): "Animated Robot Pack" von Quaternius, CC0, https://quaternius.com/packs/animatedrobot.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/q_waffen/` (55): "Ultimate Guns Pack" von Quaternius, CC0, https://quaternius.com/packs/ultimategun.html (`licenses/pakete/quaternius_cc0.txt`)
- `pakete/kk_abenteurer/` (39): "KayKit Character Pack: Adventurers 2.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/kaykit-adventurers (`licenses/pakete/kk_abenteurer.txt`)
- `pakete/kk_brettspiel/` (162): "KayKit Board Game Bits 1.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/board-game-bits (`licenses/pakete/kk_brettspiel.txt`)
- `pakete/kk_stadt/` (41): "KayKit City Builder Bits 1.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/city-builder-bits (`licenses/pakete/kk_stadt.txt`)
- `pakete/kk_wald/` (105): "KayKit Forest Nature Pack 1.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/kaykit-forest (`licenses/pakete/kk_wald.txt`)
- `pakete/kk_moebel/` (53): "KayKit Furniture Bits 1.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/furniture-bits (`licenses/pakete/kk_moebel.txt`)
- `pakete/kk_halloween/` (63): "KayKit Halloween Bits 1.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/halloween-bits (`licenses/pakete/kk_halloween.txt`)
- `pakete/kk_feiertage/` (98): "KayKit Holiday Bits 1.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/holiday-bits (`licenses/pakete/kk_feiertage.txt`)
- `pakete/kk_gemischt/` (41): "KayKit Mixed Bag 1 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/mixed-bag-1 (`licenses/pakete/kk_gemischt.txt`)
- `pakete/kk_restaurant/` (144): "KayKit Restaurant Bits 1.0 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/restaurant-bits (`licenses/pakete/kk_restaurant.txt`)
- `pakete/kk_skelette/` (19): "KayKit Character Pack: Skeletons 1.1 (Free)" von Kay Lousberg, CC0, https://kaylousberg.itch.io/kaykit-skeletons (`licenses/pakete/kk_skelette.txt`)
- `pakete/kk_dungeon/` (203): "KayKit Dungeon Remastered 1.0" von Kay Lousberg, CC0, https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 (`licenses/pakete/kk_dungeon.txt`)
- `pakete/k_figuren3/` (4): "Animated Characters 3" von Kenney, CC0, https://kenney.nl/assets/animated-characters-3 (`licenses/pakete/k_figuren3.txt`)
- `pakete/k_blaster/` (40): "Blaster Kit 2.1" von Kenney, CC0, https://kenney.nl/assets/blaster-kit (`licenses/pakete/k_blaster.txt`)
- `pakete/k_autos/` (45): "Car Kit" von Kenney, CC0, https://kenney.nl/assets/car-kit (`licenses/pakete/k_autos.txt`)
- `pakete/k_industrie/` (37): "City Kit (Industrial) 2.0" von Kenney, CC0, https://kenney.nl/assets/city-kit-industrial (`licenses/pakete/k_industrie.txt`)
- `pakete/k_fantasy_stadt/` (167): "Fantasy Town Kit 2.0" von Kenney, CC0, https://kenney.nl/assets/fantasy-town-kit (`licenses/pakete/k_fantasy_stadt.txt`)
- `pakete/k_essen/` (200): "Food Kit" von Kenney, CC0, https://kenney.nl/assets/food-kit (`licenses/pakete/k_essen.txt`)
- `pakete/k_moebel/` (120): "Furniture Kit" von Kenney, CC0, https://kenney.nl/assets/furniture-kit (`licenses/pakete/k_moebel.txt`)
- `pakete/k_spielhalle/` (20): "Mini Arcade" von Kenney, CC0, https://kenney.nl/assets/mini-arcade (`licenses/pakete/k_spielhalle.txt`)
- `pakete/k_mini_figuren/` (26): "Mini Characters" von Kenney, CC0, https://kenney.nl/assets/mini-characters (`licenses/pakete/k_mini_figuren.txt`)
- `pakete/k_supermarkt/` (20): "Mini Market" von Kenney, CC0, https://kenney.nl/assets/mini-market (`licenses/pakete/k_supermarkt.txt`)
- `pakete/k_piraten/` (72): "Pirate Kit" von Kenney, CC0, https://kenney.nl/assets/pirate-kit (`licenses/pakete/k_piraten.txt`)
- `pakete/k_weltraum/` (153): "Space Kit" von Kenney, CC0, https://kenney.nl/assets/space-kit (`licenses/pakete/k_weltraum.txt`)
- `pakete/oga_lautsprecher/` (1): "Low Poly Speaker" von cosmac (OpenGameArt), CC0, https://opengameart.org/content/low-poly-speaker (`licenses/pakete/oga_lautsprecher.txt`)

Animierte Figuren und Tiere behalten Skelett und Animationen (auch die FBX-Pakete, die über Godot laufen). Kenney
Animated Characters 3 hat Animationen nur als eigene Dateien, die nicht mit umgewandelt sind.

## Einzelmodelle `pakete/pp_einzeln/` (Poly Pizza, CC-BY 3.0 oder CC0, Nennung Pflicht, 2026-10-28)

Von Lukas einzeln von Poly Pizza geladen. Poly Pizza führt nur CC0- und CC-BY-Modelle; wo die Lizenz nicht sicher
bekannt ist, gilt hier CC-BY (Nennung). `polar_bear.glb` ist `black_bear.glb` mit weiß umgefärbter Textur.

- `pakete/pp_einzeln/barn_owl.glb`: Barn owl by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/eSEv3rCMKbg)
- `pakete/pp_einzeln/beetle.glb`: Beetle by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/4yufxgZ1QQ2)
- `pakete/pp_einzeln/black_bear.glb`: Black bear by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/56ym_pyVnel)
- `pakete/pp_einzeln/clown.glb`: Clown NEW BLOCKS by Olga Nabatova [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/9zy4BD4ewUZ)
- `pakete/pp_einzeln/cobra.glb`: Cobra by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/40_5Xq467-U)
- `pakete/pp_einzeln/cobra_jeremy.glb`: Cobra by jeremy [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/fBz0OKeCCON)
- `pakete/pp_einzeln/gnome.glb`: Gnome by Polygonal Mind [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/Yy3yuQ4l6r)
- `pakete/pp_einzeln/helicopter.glb`: Helicopter by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/cTzINMr0WdS)
- `pakete/pp_einzeln/helicopter_jeremy.glb`: Helicopter by jeremy [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/eb7b31pjGtQ)
- `pakete/pp_einzeln/igloo.glb`: Igloo by Jarlan Perez [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/4t1hupO69xj)
- `pakete/pp_einzeln/kangaroo.glb`: Kangaroo by jeremy [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/3yiIERrKNQr)
- `pakete/pp_einzeln/lion.glb`: Lion by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/3XAJojWxSWz)
- `pakete/pp_einzeln/mailbox.glb`: Mailbox by CreativeTrio [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/2olZ0G8iur)
- `pakete/pp_einzeln/newt.glb`: Newt by Jakob Hippe [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/3Gyw-gUrpp0)
- `pakete/pp_einzeln/orange_coral.glb`: Orange Coral by Device Lab [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/3HEc6LvqCJd)
- `pakete/pp_einzeln/owl.glb`: Owl by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/eoAo21aoZHJ)
- `pakete/pp_einzeln/rat.glb`: Rat by Quaternius CC0 via Poly Pizza (https://poly.pizza/m/iltq5bVNaV)
- `pakete/pp_einzeln/spider.glb`: Spider by Quaternius CC0 via Poly Pizza (https://poly.pizza/m/yRYJiAJyiM)
- `pakete/pp_einzeln/spotted_gecko.glb`: Spotted Gecko by Jeff Larson [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/65Yj7059c2K)
- `pakete/pp_einzeln/step_pyramid.glb`: Step Pyramid by Jarlan Perez [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/5fksyItujX1)
- `pakete/pp_einzeln/tiger.glb`: Tiger by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/5A3w06FXUup)
- `pakete/pp_einzeln/turtle.glb`: Turtle by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/c6n73UnGEP4)
- `pakete/pp_einzeln/walrus.glb`: Walrus by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza (https://poly.pizza/m/2ivrvruGzxc)
- `pakete/pp_einzeln/hour_glass.glb`: Hour Glass by Poly by Google [CC-BY] (https://creativecommons.org/licenses/by/3.0/) via Poly Pizza, von Lukas hochgeladen (2026-10-30); Flächennormalen ergänzt
- `pakete/pp_einzeln/snake.glb`: Snake by Quaternius, CC0, via Poly Pizza, von Lukas hochgeladen (2026-10-30), mit Animationen (Attack, Idle, Jump, Walk)
- `pakete/pp_einzeln/owl_statue.glb`: "Low Poly Owl" (STL), CC0 laut Lukas, von Lukas hochgeladen (2026-10-30); auf 4000 Dreiecke vereinfacht, Steinfarbe ergänzt. Urheber und Link werden nachgetragen.

## Tower-Modelle `towers/` (CC0, aus `pp_einzeln` CC-BY wie oben, 2026-10-28)

Kopien einzelner Modelle aus der Bibliothek `pakete/` (gleicher Unterordner = gleiches Paket, Quelle und Lizenz
wie oben), geholt mit `tools/modelle/tower_modelle.py` nach der Zuordnung in `data/tower_models.json`.
Nur die Ruhe-Animation bleibt; bei `q_figuren` ist die Hautfarbe, bei `q_feldfruechte` die Helligkeit korrigiert,
bei `q_fantasy_props` sind die Vertex-Farben entfernt.

## Eigene Modelle `pakete/eigen/` (CC0, 2026-10-30)

Selbst gebaut aus einfachen Formen mit `tools/modelle/eigenbau.py` (ein Modell = eine Funktion), eigene Arbeit,
CC0: `waage` (YouTD Scales), `it` (YouTD It), `rakete` (YouTD Pocket Rocket), `pfuetze` (eeveTD Bremspfütze),
`blitzfalle` (eeveTD Blitzfalle), `zapfsaeule` und `bohrturm` (Shopping Maul Arol Tankstelle), `trapez`
und `steinschleuder` (Randgruppen TD), `buehne` (Randgruppen Bühnennebel, darauf ein Nebeleffekt: `fog` in
`data/tower_models.json`, `scripts/game/fog_fx.gd`).
