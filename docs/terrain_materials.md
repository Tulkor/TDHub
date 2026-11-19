# Gelände-Materialinventar

Automatisch mit `tools/terrain_materials.py` aus tatsächlichen Texturreferenzen in Spielskripten, Shadern und Szenen erstellt.

## Reproduzieren

`python tools/terrain_materials.py` erzeugt fehlende Normal-Maps und deterministische Specular-Maps; `--check` prüft ohne Schreiben.
Benötigt Pillow und NumPy (vorhandene gebündelte Python-Laufzeit). `tools/heroes/materialien.py` bleibt als RockFace03-Kompatibilitätseinstieg erhalten.
Wiederkehrende Prüfung: `tools/run_tests.sh terrainmaterials`; enthalten in `schnell`/`alle` und bei passenden Generator-/Ground-/Rock-Änderungen in `geaendert` (tests/bereiche.json).

Specular-Dateien sind einkanalige lineare **Godot-SPECULAR-Koeffizienten**, keine sRGB-Farbwerte und keine weißen Glanzplatzhalter. Die vorhandenen Normal-Maps werden niemals überschrieben. Material-/Modus-Skalierungen im Shader bleiben die letzte Tuninginstanz.

## Tatsächlich referenzierte Bildmaterialien

| Albedo | Größe | Normal | Specular und Wertebereich | Ableitung |
|---|---|---|---|---|
| `assets/textures/ground/cobble.jpg` | 1024×1024 | `cobble_normal.jpg` (prozedurale Höhenableitung (bestehendes rg_texturen.py)) | `cobble_specular.png` · 0.322–0.478 | aus Albedo-Helligkeitsmuster abgeleitet; keine gemessene Specular-/Rauheitsquelle |
| `assets/textures/ground/concrete.jpg` | 1024×1024 | `concrete_normal.jpg` (prozedurale Höhenableitung (bestehendes rg_texturen.py)) | `concrete_specular.png` · 0.251–0.380 | aus Albedo-Helligkeitsmuster abgeleitet; keine gemessene Specular-/Rauheitsquelle |
| `assets/textures/ground/dirt.jpg` | 1024×1024 | `dirt_normal.jpg` (aus Albedo abgeleitet (bestehendes boden_texturen.py)) | `dirt_specular.png` · 0.102–0.180 | aus Albedo-Helligkeitsmuster abgeleitet; keine gemessene Specular-/Rauheitsquelle |
| `assets/textures/ground/grass_a.jpg` | 1024×1024 | `grass_a_normal.jpg` (aus Albedo abgeleitet (bestehendes boden_texturen.py)) | `grass_a_specular.png` · 0.102–0.180 | aus Albedo-Helligkeitsmuster abgeleitet; keine gemessene Specular-/Rauheitsquelle |
| `assets/textures/ground/grass_b.jpg` | 1024×1024 | `grass_b_normal.jpg` (aus Albedo abgeleitet (bestehendes boden_texturen.py)) | `grass_b_specular.png` · 0.102–0.180 | aus Albedo-Helligkeitsmuster abgeleitet; keine gemessene Specular-/Rauheitsquelle |
| `assets/textures/ground/gravel.jpg` | 1024×1024 | `gravel_normal.jpg` (prozedurale Höhenableitung (bestehendes rg_texturen.py)) | `gravel_specular.png` · 0.220–0.322 | aus Albedo-Helligkeitsmuster abgeleitet; keine gemessene Specular-/Rauheitsquelle |
| `assets/textures/rock/rock_face_03_diff_1k.jpg` | 1024×1024 | `rock_face_03_nor_gl_1k.jpg` (Original OpenGL/Poly Haven, erhalten) | `rock_face_03_specular_1k.png` · 0.424–0.471 | aus vorhandener Rauheit (invertiert, Materialbereich begrenzt) |

Die bestehenden Gras-/Erde-Normalen stammen bereits aus der Helligkeitsableitung von `tools/boden_texturen.py`; Beton/Pflaster/Splitt aus `tools/rg_texturen.py`. RockFace03 nutzt die originale OpenGL-Normal- und Rauheitskarte. Neu abgeleitete Normal-Maps in diesem Lauf: 0.

## Pro Modus: belegte Materialwege

| Modus | Pipeline und Sonderflächen | Quellnachweis |
|---|---|---|
| GemTD (`gemtd`) | Variantenabhängiger Board3D: gewählter UiTheme-Skin → FieldStyle; sichtbarer Fotoboden `ground`, Raster/Marmor `neon_floor` bzw. `neon_floor_lit`. Neon ist keine fehlende Albedo-Map. Optionale Wasser-/Uferflächen separat. | `scripts/map/board_3d.gd:174`, `scripts/map/field_style.gd:251` |
| eeveTD (`eevetd`) | Variantenabhängiger Board3D: gewählter UiTheme-Skin → FieldStyle; sichtbarer Fotoboden `ground`, Raster/Marmor `neon_floor` bzw. `neon_floor_lit`. Startet mit Druiden-Skin; Gras/Erde, optionale Baumuntergründe und Naturmodelle. | `scripts/game/eeve_game.gd:79`, `scripts/map/board_3d.gd:174` |
| Shopping Maul (`shoppingmaul`) | Variantenabhängiger Board3D: gewählter UiTheme-Skin → FieldStyle; sichtbarer Fotoboden `ground`, Raster/Marmor `neon_floor` bzw. `neon_floor_lit`. Startet mit Art-déco-Skin; prozeduraler Marmor, Stadtflächen (`city`) und Brunnenwasser statt pauschaler Grastexturen. | `scripts/maul/maul_game.gd:161`, `scripts/maul/maul_city.gd:15` |
| Randgruppen TD (`randgruppen`) | Variantenabhängiger Board3D: gewählter UiTheme-Skin → FieldStyle; sichtbarer Fotoboden `ground`, Raster/Marmor `neon_floor` bzw. `neon_floor_lit`. Poster-Overrides ersetzen Bauflächen durch Pflaster und Wege durch Splitt; Wiese und Pflaster in RgScenery separat gebunden. | `scripts/map/field_style.gd:51`, `scripts/map/rg_scenery.gd:157` |
| YouTD (`youtd`) | Variantenabhängiger Board3D: gewählter UiTheme-Skin → FieldStyle; sichtbarer Fotoboden `ground`, Raster/Marmor `neon_floor` bzw. `neon_floor_lit`. Startet mit Druiden-Skin; keine Annahme, dass spätere Karten-/Stilwahl unverändert bleibt. | `scripts/youtd/youtd_game.gd:90`, `scripts/map/board_3d.gd:174` |
| Bollwerk (`heroes`) | Eigene HdArena-/HdDev-Oberflächen plus HdFinalStyle; Schlund-Fels bindet RockFace03-Albedo, originale OpenGL-Normale, originale Rauheit und abgeleitete Specular. Weitere Arena-/Schneeflächen sind prozedural. | `scripts/heroes/hd_final_style.gd:234`, `scripts/heroes/hd_arena.gd:1` |
| Tower Survivors (`survivors`) | Eigener SvWorld statt Board3D: Eis-/Schnee-Albedo, Normalen und Rauheit entstehen zur Laufzeit; Specular ist ein Materialkonstantwert (Eis 0.7, Lochfläche 0.8), keine Specular-Bildmap. Meer und Schnee-Overlay haben eigene Shader. Keine externen Gras-/Felsmaps unterstellen. | `scripts/survivors/sv_world.gd:220`, `scripts/survivors/sv_world.gd:225`, `scripts/survivors/sv_world.gd:242` |

Importierte GLB-Materialien (z. B. Natur-/Umgebungsmodelle) bleiben **eingebettet und unverändert**; ihre externen Normal-/Specular-Dateien werden hier nicht pauschal behauptet. Der Bericht verändert keine importierten Figuren-/Tower-/Boss-/UI-Materialien. Statische Pfadfunde belegen Ressourcen und Bindestellen; GPU-/Modustests und die sichtbare Wirkung sind separat zu prüfen.

## Prozedurale Flächen und bewusste Ausnahmen

| Fläche | Tatsächliche Normal-/Specular-Art | Nachweis |
|---|---|---|
| Grundboden / Baum-Erde / RG-Pflaster | Vorhandene Normal-Bildmaps und materialabhängige Specular-PNGs; FieldStyle leitet Dateinamen von der ausgewählten Albedo ab, explizite Overrides haben Vorrang. | `scripts/map/field_style.gd:268` |
| Neon-/Glasfelsen | Analytisches Ader-/Mikrorelief und räumlich variierendes Specular; kein erfundenes Normal-Bitmap. | `assets/shaders/rock.gdshader:49` |
| Maul-Stadt | Analytische Stein-/Fenstervertiefung; Specular/Rauheit unterscheiden Stein und Glas. | `assets/shaders/city.gdshader:65` |
| Beleuchtetes Raster / Marmor | Analytisches Mikrorelief und Specular um vorhandene Stilparameter; unbeleuchtetes Hologramm bleibt bewusst unverändert. | `assets/shaders/neon_floor.gdshaderinc:332` |
| Natürliches Ufer | Analytisches Boden-/Steinrelief, feuchter Rand weniger rau und reflektierender. | `assets/shaders/natural_bank.gdshader:22` |
| Städtisches Ufer | Echte Pflaster-Normal-/Specularmaps, triplanar und mit UV-abgeleiteter Tangentenbasis gebunden. | `scripts/systems/water/water_bank.gd:123` |
| Wasser / Wasserfall / Brunnen | Animierte Normal-Bildmaps für Wasser/Wasserfall; Brunnen analytische Wellennormalen. Bestehende Fresnel-/Reflexion; Gischt ist eine transparente unbeleuchtete Effektfläche. | `assets/shaders/water_surface.gdshaderinc:75` |
| Bollwerk-Kathedralstein | Analytisches Steinrelief, materialabhängiger Specular/Rauheit. Vorhandene Flächenkontur und Farbwahl bleiben erhalten. | `scripts/heroes/hd_cathedral.gd:61` |
| Bollwerk-Schlund-Anmarsch / Arenen | Analytisches Materialrelief und Specular in den vorhandenen Inline-Shadern; RockFace03-Fels zusätzlich mit Originalnormalen und Rauheitsquelle. | `scripts/heroes/hd_final_style.gd:519` |
| Bollwerk HdDev-Prüfboden | Bewusster geometrischer Checker/Entwicklungs-Look: keine künstlichen Normalmaps aufgezwungen; Materialkonstanten statt vorgetäuschter Bild-PBR. | `scripts/heroes/hd_dev.gd:55` |
| Hub-/Menüboden und Stein | Konkrete Beton-/Gras-/Erde-/Splitt-Specularmaps passend zu vorhandenen Normalen; Terrainbilder, keine UI-Icons geändert. | `scripts/ui/wc3_menu_bg.gd:29` |
| Survivors-Schneeüberzug | Geometrische Flächennormalen und konstante Rauheit 0.85; separates Überzugsmaterial, keine zusätzliche Specular-/Normal-Bildmap behauptet. | `scripts/survivors/sv_snow.gdshader:12` |

Palette-/Solidcolor-Naturmodelle (z. B. `rock_medium` / `rock_tall`) behalten ihre eingebetteten Materialfarben, geometrischen Normalen und Rauheitswerte. **Keine** pauschale externe Bitmap-Abdeckung dieser GLBs. Prüfpfade für reale GPU-Ergebnisse: `tools/shaders/terrain_probe.tscn`, `tools/water/route_hills.tscn` sowie die üblichen Modus-Screenshots; Details unter `tools/shaders/README.md`.

## Nachweise und Abgrenzung

Dateiexistenz ist **kein** Nachweis, dass jeder Modus jede Map bindet. Die folgenden Stellen sind statische Nutzungsnachweise, keine pauschale Laufzeitfreigabe aller Modi. Prozedurales Neon, Marmor, Fels sowie Wasser können Normal-/Specular-Daten analytisch im Shader erzeugen und benötigen dann keine Bildmap. UI, Tower, Bosse und Figuren werden nicht bearbeitet.

- `cobble.jpg`: `scripts/map/field_style.gd:52`, `scripts/map/field_style.gd:53`, `scripts/map/rg_scenery.gd:158`, `scripts/systems/water/water_bank.gd:121`.
  - normal: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/field_style.gd:55`, `scripts/map/field_style.gd:56`, `scripts/map/rg_scenery.gd:159`, `scripts/systems/water/water_bank.gd:122`.
  - specular: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/rg_scenery.gd:160`, `scripts/systems/water/water_bank.gd:123`.
- `concrete.jpg`: `scripts/ui/wc3_menu_bg.gd:27`.
  - normal: `scripts/ui/wc3_menu_bg.gd:28`.
  - specular: `scripts/ui/wc3_menu_bg.gd:29`.
- `dirt.jpg`: `scripts/map/board_3d.gd:41`, `scripts/map/field_style.gd:60`, `scripts/map/rg_scenery.gd:239`.
  - normal: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/board_3d.gd:44`, `scripts/map/rg_scenery.gd:241`.
  - specular: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/rg_scenery.gd:243`.
- `grass_a.jpg`: `scripts/map/board_3d.gd:39`, `scripts/map/field_style.gd:59`, `scripts/map/rg_scenery.gd:240`.
  - normal: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/board_3d.gd:42`, `scripts/map/rg_scenery.gd:242`.
  - specular: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/rg_scenery.gd:244`.
- `grass_b.jpg`: `scripts/map/board_3d.gd:40`.
  - normal: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/board_3d.gd:43`.
  - specular: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`.
- `gravel.jpg`: `scripts/map/field_style.gd:54`.
  - normal: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`; zusätzliche direkte Bindings: `scripts/map/field_style.gd:57`.
  - specular: abhängig von tatsächlich gewählter Albedo dynamisch über `scripts/map/field_style.gd:268` → `scripts/map/board_3d.gd:174`.
- `rock_face_03_diff_1k.jpg`: `scripts/heroes/hd_final_style.gd:234`.
  - normal: `scripts/heroes/hd_final_style.gd:235`.
  - specular: `scripts/heroes/hd_final_style.gd:237`.

## Quellen

Vorhandene Quellen-/Lizenznachweise: `assets/textures/ground/CREDITS.md` und `assets/textures/rock/CREDITS.md`. Neu erzeugte Maps sind Ableitungen dieser bestehenden Quellen; es werden keine externen Texturen nachgeladen.
