# Art-Pass: Effekte, Sounds und Modelle passend zum Tower (Auftrag Lukas, 2026-11-26)

Bestandsaufnahme von Claude, Umsetzung durch Codex (Lukas: „wenn du direkte Vorgaben hast, gib die Aufgabe an Codex ab“).
Basis: Branch `claude/art-pass` (= Leistungsstand `claude/project-thread-gmxnxm` fdb1ee0). Codex arbeitet auf einem eigenen Branch `codex/art-pass` ab diesem Stand.

## Befund (Stand fdb1ee0)
- Katalog: 5 Schuss-Effekte (`data/fx/shots.json`: magic_beam, lightning_arc, fire_orb, energy_orb, ruby_nova), 23 Treffer-Effekte (`data/fx/hits.json`), 5 Schuss-Sounds + thud (`data/sfx.json`).
- Ohne eigene Angabe wählt `scripts/game/fx_data.gd` (`_auto_shot`, `_auto_hit_for`) und `scripts/autoload/sfx.gd` nur nach **Farbton** (Gelb/Orange → Blitz, Rot → Feuer, sonst magic_beam). Name, Element und Waffe zählen nicht.
- Eigene Werte: nur 35 eeve-Tower setzen `hit_fx` (über `data/tower_models.json`), kein Tower setzt `shot_sfx`. YouTD (690 Tower) und Maul (218) wählen nach Element- bzw. Filialfarbe.
- Folge, z. B.: Steinwerfer schießen Blitzbögen, Krater/Geysire Feuerkugeln, ~12 Blitz-Tower magic_beam, Säure/Gift ohne Gift-Effekt, Eisläuferin Feuer + Explosion.

## A1: Element vor Farbe (ohne neue Assets) – zuerst
1. Neue Datei `data/fx/elements.json`: je Element Schuss-Effekt, Treffer-Effekt (normal und bei Splash) und Sound mit Tonhöhe. Startwerte (nur vorhandene Assets; A2/A3 tauschen sie später aus):

| Element | shot_fx | hit_fx | hit_fx bei splash | shot_sfx |
|---|---|---|---|---|
| feuer | fire_orb | bk_fire | bk_explosion | shot_blast@1.0 |
| blitz | lightning_arc | kb_shock_ring | cyan_shock | shot_zap@1.0 |
| wasser | energy_orb | kb_splash | kb_splash | shot_blip@0.8 |
| eis | energy_orb | blue_ring | blue_ring | shot_pew@1.3 |
| gift | energy_orb | green_poison | green_poison | shot_blip@0.6 |
| erde | energy_orb | brown_dirt | brown_dirt | thud@1.0 |
| physisch | magic_beam | white_slash | bk_explosion | thud@1.2 (Kanone: shot_blast@0.7) |
| dunkel | magic_beam | violet_dark | violet_dark | shot_pew@0.6 |
| licht | magic_beam | gold_star | white_spark | shot_blip@1.4 |
| natur | magic_beam | kb_nature_rays | kb_nature_rays | shot_blip@1.0 |

   Schuss-Effekte werden weiter in der Towerfarbe eingefärbt (wie bisher), damit energy_orb bei Wasser blau, bei Gift grün ist.
2. Neues optionales Feld `"element"` in der Tower-Definition. Reihenfolge der Wahl in `fx_data.gd` und `sfx.gd`: eigenes `shot_fx`/`hit_fx`/`shot_sfx` > `element` > Fähigkeit (bestehende Regeln `ability`/`hit_ability`, bounce/chain → blitz) > Farbton (bisheriges Verhalten als Rückfall). Bestehende eigene `hit_fx` aus `tower_models.json` bleiben vorrangig.
3. `element` für diese Tower setzen (eeve-Tower ggf. über `tools/wc3/eeve/eeve_daten.py`, falls die Dateien dort erzeugt werden; sonst direkt in `data/towers/`):
   - gemtd: aquamarine=wasser, poison_slate=gift, wraith_slate=dunkel (Blutstein, Sternrubin, Dunkler Smaragd, Stein von Bryvx bleiben wie sie sind: Edelsteinnamen).
   - eeve feuer: arcane_lava_piles, camp_fire, essence_of_fire, fire_base_tower, fire_berry_bush, fire_breathing_snowman, flame_grate, heat_stakes, phoenix_egg, scorched_rune, searing_totem, volcano.
   - eeve blitz: arcane_lightning_generator, ball_lightning, great_lightning_turret, heart_of_the_storm, lightning_field, lightning_generator, lightning_rock_elemental, lightning_trap, red_lightning_generator, storm_base_tower, storm_cloud, storm_generator, storm_lantern, stormy_peak, xtreme_lightning_this_is_madness_ultra_q_q_tower.
   - eeve wasser: ancient_fountain_of_wisdom, gaea_spring, geyser, small_geyser, glowing_fountain_of_oxidization, hydro_cannon, tsunami_cannon, water_base_tower.
   - eeve eis: glacier, ice_cube, icy_time_crystal, permafrost_blaster.
   - eeve gift: acid_fountain, fountain_of_corrosion, noxious_tendril_trap, ultra_toxic_shroom_field.
   - eeve erde: crater, deep_crater, earth_base_tower, earthbind_trap, lesser_rock_launcher, rock_launcher, greater_rock_launcher, runed_rock, stone_of_wisdom.
   - eeve licht: moonlight_beam, sacred_orb_of_power. eeve dunkel: scaring_statue_of_corruption.
   - randgruppen: rg_eislaeuferin=eis, rg_kanonenkugel_mann=physisch (Kanonen-Sound), rg_steinschleuder=erde.
   - Danach mit einem kleinen Werkzeug (`tools/art/element_vorschlag.py`, Namens-Schlüsselwörter DE/EN) die übrigen eeve/rg-Tower durchsehen und nur eindeutige Fälle ergänzen; die Liste der Vorschläge im PR-Text nennen.
4. YouTD: Element aus `element` der Tower-Daten abbilden (ice=eis, nature=natur, fire=feuer, astral=licht, darkness=dunkel, iron=physisch, storm=blitz); Tower mit `"lightning": true` schießen immer lightning_arc. Maul bleibt nach Filialfarbe.
5. Test: `tests/systems/fx_element_test.gd` (in `tests/bereiche.json` eintragen): Steinwerfer → brown_dirt + thud, Blitzgenerator → lightning_arc + shot_zap, Geysir → kb_splash, Säurebrunnen → green_poison, ein Tower mit eigenem `shot_fx` behält ihn, ein Tower ohne Element bekommt wie bisher die Farbwahl.
6. Nach Änderungen an Tower-Daten: `tools/tower_tabelle.py` → `docs/tower-werte.md`.
7. Beleg: je Element ein Screenshot mit `tools/render_windows.ps1` (verdeckt, Bildschirm 2), z. B. eeve-Welle mit Stein-, Blitz-, Wasser- und Gift-Towern.

## A2: Neue Schuss- und Treffer-Effekte (prozedural, ohne Download)
In `data/fx/shots.json`/`hits.json` registrieren, dann in `elements.json` statt der Startwerte eintragen. Größen relativ zu `Board3D.CELL`, höchstens ~24 Partikel je Effekt, auf Grafikstufe Niedrig ohne Zusatzlicht und mit halber Partikelzahl.
- `stone_arc`: grauer Brocken (low-poly), ballistischer Bogen, kleine Staubspur; Treffer brown_dirt + Bodenstaub.
- `arrow`: schmaler langer Pfeil mit Spitze, gerade Flugbahn, Ausrichtung in Flugrichtung; Treffer white_slash.
- `cannonball`: dunkle Kugel, flacher Bogen, Rauchwölkchen beim Abschuss; Treffer bk_explosion klein.
- `frost_bolt`: hellblauer Eissplitter, Schneeflocken-Partikel; Treffer: Frostring, der kurz am Boden bleibt.
- `poison_glob`: grüner, leicht durchsichtiger Tropfen, tropft beim Flug; Treffer `acid_cloud` (grüne Wolke 1–1,5 s).
- `water_jet`: blauer Strahl (Beam wie magic_beam, aber mit fließender UV-Textur), Treffer kb_splash.
- `chain_lightning`: mehrfach gezackter Bogen zwischen Zielen (lightning_arc als Basis), für bounce/chain.
- Effekt-Tower ohne Modell (eeve, `tower_models.json` „Effekt statt Modell“): Sturmwolke/Strahlende Wolke (Wolken-Billboards mit Noise-Shader, Sturm mit kurzem Blitzflackern), Tornado (gedrehter Zylinder mit laufendem Noise + Trümmerpartikel), Natürlicher Mahlstrom (Scheibe mit Spiral-UV-Shader), Kugelblitz (leuchtende Kugel mit zuckenden Bögen), Geysir/Kleiner Geysir (periodische Wassersäule), Blitzfeld (Bodendecal mit Bögen). Höhe ≤ 2 Felder, Stil wie die übrigen Tower.
- Messung danach: eeve/youtd/randgruppen auf Hoch mit `--messen=8` (VSync aus) gegen die Werte in PR #145; Ziel: kein Lauf mehr als +0,3 ms.

## A3: Sounds (braucht Downloads, vorher Lukas fragen)
Vorschlag CC0: Kenney „Impact Sounds“, „RPG Audio“, „Sci-fi Sounds“. Benötigt: fire_whoosh, ice_crack, water_splash, poison_squish, arrow_release, cannon_boom, rock_impact, electric_crackle, Treffer nach Rüstung (Fleisch/Metall/Stein), Tod nach Gegnerart. Schneiden mit `tools/sfx/schneiden.py`, Quellen in `assets/sounds/QUELLEN.md`, dann in `elements.json` eintragen.

## A4: Fehlende oder notdürftige Modelle (braucht ggf. Downloads)
Aus `data/tower_models.json`: randgruppen Dompteur (Raubkatze), Eisläuferin (Schlittschuh), Eyeliner-Profi/Ponyfranse (Emo-Figur), Rasensprenger; Maul o005 Roboterhund, o00V Kettensäge, h01T Kopierer, h025 Windmühle, h024/h01Q Wahrzeichen; YouTD 145/267 Harpyie, 147 Phönix, 157 Greif mit Reiter, 112 Wasserlauf. Nur CC0, Eintrag in `tower_models.json` und `assets/models/CREDITS.md`.

## Übergabe zurück
PR von `codex/art-pass` mit der vereinbarten Übergabe (Was – Warum – Geprüft – Offen), Screenshots und Messwerten. A1 zuerst als eigener PR, A2–A4 danach getrennt.
