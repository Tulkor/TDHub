# Modelle aus CC0-Paketen

- `python3 -I tools/modelle/umwandeln.py --paket=<name>=<entpackter Ordner> …` holt die in `auswahl.json`
  eingetragenen Modelle nach `assets/models/` (eine .glb je Modell, Texturen eingebettet und verkleinert,
  Tangenten und Normalmaps weggelassen). glTF/GLB rechnet Python selbst, FBX geht über Godot (`umwandeln.gd`).
  Paketnamen stehen in `auswahl.json` unter `_info`.
- Ausprobieren ohne das Repo zu ändern: `--auswahl=/tmp/kandidaten.json --ziel=/tmp/kandidaten`.
- `tools/modelle/vorschau.sh <bogen.png> <a.glb> …` rendert jedes Modell einzeln und setzt einen Kontaktbogen
  mit Namen zusammen (zum Auswählen).
- Lizenz jedes Pakets prüfen und in `assets/models/CREDITS.md` eintragen (Regel in CLAUDE.md).

Verwendung im Spiel: eeveTD über `LOOK` in `tools/wc3/eeve/eeve_daten.py` (Modell, `model_solid`, `flame`, `hit_fx`),
Shopping Maul über `data/maul/models.json`.

Boss-Modell: `tools/modelle/boss_rig.py` gibt dem starren "Little Man" (CC-BY) Skelett und Animationen
(`walk`, `idle`, `hit`, `death`). Braucht Blender als Python-Modul: `uv venv -p python3.13 env && uv pip install -p env/bin/python bpy`.
Animationen ansehen: `tools/modelle/vorschau.sh bogen.png --animationen assets/models/enemies/little_man.glb`.

Gegner-Modelle (Skelett, Schleim, Drache, Fledermaus, Quaternius CC0): `tools/modelle/monster_umwandeln.py` wandelt die FBX
aus dem "Animated Monster Pack" mit denselben Animationsnamen wie beim Boss um:
`<python mit bpy> -I tools/modelle/monster_umwandeln.py -- "<Paket>/FBX" assets/models/enemies`.

Bergwerk (eeveTD): `<python mit bpy> -I tools/modelle/mine_umwandeln.py -- <mine_parts.blend> /tmp/mine`, danach die gebrauchten `mine_*.glb` mit `pack_gltf` verkleinert nach `assets/models/scenery/`. Kirche: `tools/modelle/kirche_umwandeln.py`.

Ganze Pakete als Bibliothek (`assets/models/pakete/<id>/`, mit `.gdignore`, kommt nicht in den Build):
`python3 -I tools/modelle/pakete_umwandeln.py --quelle=<Ordner mit den entpackten Zips> [--nur=q_monster,kk_wald] [--ziel=/tmp/x]`.
Pakete, Quellordner und Formatwahl stehen in `pakete.json`; Texturen werden je Paket in `texturen/` geteilt,
`LISTE.txt` zählt die Modelle auf. Ansehen: `tools/modelle/vorschau.sh bogen.png assets/models/pakete/kk_wald/*.glb`.
Ein Modell ins Spiel holen: in `auswahl.json` eintragen und `umwandeln.py --paket=pakete=assets/models/pakete` aufrufen
(bettet die geteilte Textur wieder ein). Lizenzen: `assets/models/CREDITS.md` und `assets/models/licenses/pakete/`.

Tower-Modelle aller Modi (eeveTD, Shopping Maul, Randgruppen TD, YouTD): Zuordnung von Hand in `data/tower_models.json`
(Werte `"<paket>/<name>"` aus der Bibliothek, `res://…`, `kristall`, `haus`, `{m, tint, flame, flame_height, hit_fx, not}`
oder `{fehlt: Grund}`). `python3 -I tools/modelle/tower_modelle.py [--bericht=/mnt/project-files/modelle/tower_ohne_modell.md]`
holt die Modelle nach `assets/models/towers/<paket>/` (nur Ruhe-Animation, Skin-Gewichte als Bytes, Farbkorrekturen
je Paket in `fix_for`), entfernt nicht mehr gebrauchte und listet die Tower ohne passendes Modell. Danach
`eeve_daten.py` und `rg_daten.py` neu laufen lassen; Maul (`maul_tower.gd`) und YouTD (`youtd_tower.gd`) lesen
die Datei über `TowerModels.look()` zur Laufzeit. Figuren spielen ihre Ruhe-Animation (`ModelLoader._play_idle`),
Modelle aus `assets/models/towers/` drehen sich nicht.

Eigene Modelle für Tower ohne freies Modell: `python3 -I tools/modelle/eigenbau.py [--nur=waage]` baut sie aus
einfachen Formen nach `assets/models/pakete/eigen/` (eine Funktion je Modell, braucht trimesh und scipy).

Heldenmodelle für Bollwerk (Torvik, Unrat, Vesna, Zix): eigene Low-Poly-Figuren, `tools/modelle/helden_bau.py` baut sie
aus einfachen Formen mit Skelett (jedes Teil starr an einem Knochen) und Animationen `idle`, `run`, `attack`, `cast`,
`death`: `<python mit bpy> -I tools/modelle/helden_bau.py -- assets/models/heroes [--nur=torvik] [--bild=linie.png]
[--posen=posen.png]` (Vorschau mit Cycles: Aufstellung bzw. je Held eine Reihe Ruhe/Laufen/Angriff/Zauber/Tod).
Ein neuer Held = eine Funktion in `BAU` plus Eintrag in `STIL`/`animieren`. Im Spiel: `"model"` in `data/heroes_helden.json`.

Bollwerk-Gegner (Moor): `<python mit bpy> -I tools/modelle/bollwerk_figuren.py -- assets/models/heroes/gegner [--nur=grolm]
[--bogen=bogen.png] [--posen=posen.png] [--gruppe=reihe.png]`. Ein neuer Gegner = Funktion plus Einträge in `FIGUREN` (Höhe = size[1])
und `STIL` (Angriffsart hieb/beide/wurf/stoss/stab/sprung); im Spiel `"model"` in `data/heroes.json`.
