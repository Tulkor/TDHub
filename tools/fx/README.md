# Effekte umwandeln

Art-Pass A2: `prozedurale_effekte.py` registriert sieben Mesh-Geschosse und drei
begrenzte Treffer. Der Kenney-Import ruft es am Ende automatisch auf; mit
`python tools/fx/prozedurale_effekte.py --pruefen` den Datenstand prüfen.
Die Geometrie entsteht in `scripts/game/fx_procedural.gd` ohne neue Bildassets.
`vorschau.tscn -- --schuesse=stone_arc,arrow,...` zeigt Geschosse,
`--effekttower=storm_cloud,tornado,...` die dauerhaften Tower-Effekte.
`--nur=frost_ring,acid_cloud` beschränkt die Vorschau auf diese Treffer.

Alle Effekte im Spiel kommen aus dem Kenney Particle Pack (CC0, `assets/fx/kenney/`). Nur Material mit einer
Lizenz verwenden, die Weitergabe im öffentlichen Repo und Verkauf des Spiels erlaubt (keine Asset-Store- oder
Stock-Video-Dateien, nichts mit NC oder unklarer Herkunft).

| Datei | Zweck |
|---|---|
| `kenney_effekte.py` | baut `data/fx/hits.json`, `data/fx/shots.json` und die Sheets in `assets/fx/shot/` aus den Kenney-Bildern (Vorlagen und Farbtabelle im Skript). |
| `treffer_umwandeln.py <ordner>` | entpacktes Unity-`.unitypackage` (`tar xzf paket -C ordner`) → `data/fx/hits.json` + Texturen in `assets/fx/hit/` (nur für Pakete, deren Lizenz die Weitergabe erlaubt). Jedes Prefab wird ein Effekt, jedes Partikelsystem eine Ebene (Bursts, Rate, Lebenszeit, Größe/Farbe über die Lebenszeit, Sprite-Sheets, Formen Kugel/Kegel). |
| `video_zu_sheet.py <id> <video> line\|nova` | Video mit Alphakanal → Sprite-Sheet `assets/fx/shot/<id>.png` + Eintrag in `data/fx/shots.json` (nur für Videos, deren Lizenz die Weitergabe erlaubt; Wiedergabe-Werte wie `length`, `width`, `brightness`, `kind` bleiben erhalten). |
| `vorschau.sh [--tower=ruby,topaz] [--zeiten=0.1,0.2]` | Bild aller Effekte bzw. der Effekte einzelner Tower nach `/mnt/project-files/screens/fx/`. |
| `unity_lesen.py` | Hilfsmodul: Unity-YAML lesen. |

Heruntergeladene Pakete und Videos immer in einen eigenen, leeren Ordner entpacken und mit `python3 -I` verarbeiten.

Im Spiel: `scripts/game/fx_data.gd` wählt die Effekte pro Tower (Felder `hit_fx`/`shot_fx` in der Tower-Datei,
sonst Element aus `data/fx/elements.json`, Fähigkeit und schließlich Farbe; Regeln in `data/fx/shots.json` → `auto`), `scripts/game/fx_player.gd` spielt sie ab.
Splash nimmt Feuer (`fire_orb` + `bk_explosion`) nur für warme Tower (`auto.warm`, rot bis gelb), sonst
Energiekugel + Spritzer (`energy_orb` + `kb_splash`, auf die Towerfarbe gedreht). Treffer eines Geschosses
starten erst beim Einschlag. Jeder Treffer leuchtet kurz als Licht in seiner Farbe (`OmniLight3D` aus einem Pool
von 8, nahe Treffer teilen sich eins) plus Lichtschein flach auf dem Boden; abschalten mit
`FxPlayer.lights_enabled = false`, einzeln mit `"light": false` am Treffer. Sprites blenden weich aus, wo sie in
Boden oder Modelle stoßen (`soft` in `assets/shaders/fx_sprite.gdshaderinc`).
Treffer im echten Spiel ansehen: `tools/screenshot.sh --tower=silver:2 --welle=13 --phase=welle --warten=3 --treffer --winkel=nah`
(eeveTD: `--map=eeve --grundtower=water --phase=welle --warten=12 --treffer --winkel=nah --punkt=30,72`).

## Brackeys und Kronbits (CC0)

`python3 tools/fx/zusatz_effekte.py --brackeys=<entpackt> --kronbits=<entpackt>` holt die verwendeten Bilder
nach `assets/fx/brackeys/` und `assets/fx/kronbits/` und trägt die Treffer `bk_*`/`kb_*` in `data/fx/hits.json` ein
(ohne Pfade nur die Einträge). Die Treffer wählt nicht die Farbautomatik, sondern `hit_fx` in den Tower-Daten oder
`auto.hit_ability` in `data/fx/shots.json` (Splash = Explosion). Die Flamme (`flame_01`) spielt `FlameFx` als
Endlos-Billboard ab: in den Tower-Daten `"flame": <Größe>` und optional `"flame_height"` (Anteil der Modellhöhe).
