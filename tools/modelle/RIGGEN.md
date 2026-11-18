# Riggen: Skelette und Animationen schneller bauen

Stand 2026-11-16: `python tools/modelle/weapon_qa.py` prüft alle 23 bewaffneten Helden inklusive Originalkader, beide Seiten bei Doppelwaffen, Klingenebene und führende Schneide bei einseitigen Äxten. `run_tests.sh riggen` führt diese Prüfung zusätzlich aus. Torvik verwendet nun echte Hand-/Waffenanker; `torvik.json → grips/grip_directions` sind die verbindlichen Griffziele im Brust-Restkoordinatensystem, ältere Kopfziele dienen bei diesen Schlüsseln nur als Orientierungsvorgabe. `riggen pruefen` kontrolliert dann die Griffziele. Der Fluid-Pass verzögert Unterarme mit Handankern nicht separat. Soreks Zweihandbewegung wird in Blender analytisch bei 96 Hz gebacken; kein Laufzeit-IK nötig. Vollständiger Bericht: `docs/hero-defense/waffen-pruefung-2026-11-16.md`.

Kader-Waffenprüfung: `python tools/modelle/fluid_qa.py --heroes=brennholt,sorek --weapons` (beliebige Heldenliste). Die 20 Kaderhelden werden mit `blender --background --python tools/modelle/kader_bau.py` reproduziert. Hand-/Waffenanker, geschützte Schildhaltung und gewichtete Bogensehnen sind Teil des Blender-Modells; die Laufzeit braucht keine IK. Die unabhängige Prüfung tastet finale Animationen mit 48 Hz ab und prüft starre Waffen, Griffbindung sowie ein konservatives Brustvolumen. Sie ersetzt die GPU-Sichtprüfung nicht. Posenreferenz für Waffengebrauch/Deckung und Körperdrehung: [NSFS-Handbuch](https://nordicstagefight.com/wp-content/uploads/2020/12/NSFS-handbook-lastest.pdf), [Royal Armouries – Sword Fighting](https://www.youtube.com/watch?v=MOwAgWzdB2Q). Keine fremden Animationen übernommen.

Ein gemeinsames Werkzeug für vorhandene und neue humanoide Helden. Einstieg: `python tools/riggen.py --help`; benötigt NumPy. Die gebündelte Python-Laufzeit unterstützt NumPy. Blender wird nur für den bisherigen Modell-Neubau benötigt, nicht für das Bearbeiten vorhandener GLB-Animationen.

## Weichere Körper und Gewänder

`python tools/riggen.py weich` bearbeitet alle vier Bollwerk-Helden; einzelne IDs sind möglich, etwa `weich unrat vesna`. Profile stehen in `rig_profiles/fluid.json`. Der bestehende Blender-Neubau und das erneute Bauen der Torvik-/Unrat-Schläge übernehmen diesen Schritt automatisch.

`rig_fluid.py` ergänzt gewichtete Nachlaufketten für Bart, Säume, Schürze, Umhang, Banner, Ohren, Schwanzspitze und Antenne. Stoffflächen werden unterteilt, Körpergelenke weich gewichtet; Waffen und Metall bleiben starr gebunden. Alle Clips erhalten interpolierte Zwischenposen und zeitlich versetzte Körper-/Anhangbewegungen. Die ursprünglichen Angriffsrotationen und horizontalen Zielbahnen bleiben erhalten. Nachlauf wird in die GLB gebacken: keine zusätzliche Laufzeit-Physiksimulation oder Netzwerksynchronisierung.

Der Bodenkontakt wird aus den tatsächlich animierten Schuh-/Fußvertices berechnet: Ein gemeinsamer vertikaler Root-Versatz legt den jeweils tiefsten Stützfuß auf y=0, einschließlich Zehen und Fersen. Das gilt für Ruhe, Laufen, Angriffe und Zauber; die Todesanimation bleibt unverändert. Laufclips werden dafür mit 96 Hz abgetastet. Relative Fußhebungen bleiben sichtbar; dies ist keine horizontale Fußverriegelung oder Terrain-IK. Angriffszielhöhen verschieben sich mit dem geerdeten Körper, Rotation und Ausrichtung der Waffen bleiben unverändert. `fluid_qa.py` prüft den tatsächlichen Sohlenabstand an Zwischenzeitpunkten (höchstens 6 mm) sowie die Waffenketten relativ zum geerdeten Root.

Parameter je Anhang: Material/Region, Verankerung, Knochenzahl, Unterteilung, Federsteifigkeit, Dämpfung und maximaler Winkel. Die kanonische Quelle bleibt im GLB eingebettet; wiederholte Anwendung baut deterministisch von dieser Quelle statt Gewichte mehrfach zu verwischen. `restore_blob()` entfernt den Pass verlustfrei. Der Werkzeug-Einstieg ist für diese vier vorhandenen Rigs ausgelegt; neue Helden benötigen ein passendes Profil.

Torvik, Unrat und Vesna versionieren ihre `.glb.import`-Einstellungen: automatische LOD-Erzeugung aus, da Godot 4.3 beim Vereinfachen dieser Stoff-Rigs degenerierte Dreiecke erzeugt. Zix behält LODs. Das kostet bei entfernten Stoff-Helden die automatische Dreiecksreduktion; Gewandtopologie und Silhouetten bleiben erhalten. Keine globale Änderung der Grafikoptionen.

Bewegungsreferenz: [Animation Mentor: Follow Through and Overlapping Action](https://www.animationmentor.com/blog/follow-through-and-overlapping-action-the-12-basic-principles-of-animation/) — zeitversetzte Körperteile und ausschwingende Anhänge. Keine fremden Modelle oder Animationen übernommen.

`tools/run_tests.sh riggen` prüft auch `fluid_qa.py`: Bindpose, Gewichtsnormalisierung, Waffenbindungen, ursprüngliche Trefferposen, Loop-Enden, bewegte Anhänge und verlustfreien Wiederaufbau. GPU-Prüfung: `attack_probe.tscn -- --held=vesna --clip=run`; danach `attack_clips.py --galerie --clip run` für alle vier zuvor aufgenommenen Helden. `--galerie` ohne Clip kombiniert Torvik-/Unrat-Kombos und Vesna-/Zix-Angriffe.

## Vorhandenen Helden bearbeiten

Zix' Entladungspose: `python tools/riggen.py bauen tools/modelle/rig_profiles/zix.json`. Der Spiel-Effekt liegt in `HdHeroZix.shock_fx()` und wird auch von der GPU-Probe verwendet; das GLB enthält die Körper-/Armbewegung.

Torvik ist vollständig angebunden:

```text
python tools/riggen.py info tools/modelle/rig_profiles/torvik.json
python tools/riggen.py bauen tools/modelle/rig_profiles/torvik.json
python tools/riggen.py pruefen tools/modelle/rig_profiles/torvik.json
```

Im Profil stehen Körperpunkte, Waffen, Schlagrichtungen und Zielpunkte der Axtköpfe. Der Solver berechnet Schulter-/Ellbogenposen und Handgelenkrollen. `targets` sind Weltpunkte in **Blender-Koordinaten: X links, Y vorwärts, Z oben**, vor zusätzlicher Spielerdrehung. `velocity` beschreibt die Schlagrichtung. Eine `hold`-Pose hält die fertige Trefferpose. Änderungen an Schadenswerten oder Spielmechanik sind hiervon unabhängig.

`auto_wrist` dreht den kompletten Unterarm samt Hand und gebundener Waffe um dessen tatsächliche Längsachse. Die Schneidenebene richtet sich zur Schlagbahn aus; bei symmetrischen Axtblättern wird die nächstliegende Orientierung verwendet. Keine einzeln schwebenden Axtköpfe. Zielpunkte außerhalb der Armreichweite werden mit einem Fehler gemeldet (`max_target_error`), statt unsichtbar akzeptiert. Das ist eine kleine, deterministische IK-Hilfe, kein vollständiger physikalischer Ganzkörper-/Kollisionssolver.

Eine Trefferpose kann zusätzlich `directions` enthalten, z. B. `"directions":{"scepter":[0,1,0]}`: Dann werden Zielpunkt und Schaftrichtung gemeinsam gelöst. Diese explizite Richtung ersetzt an diesem Schlüsselbild die automatische Schneidenausrichtung; sie wird auf mindestens 0,97 Übereinstimmung mit der gewünschten Richtung geprüft. Unrats Abschluss trifft so mittig mit gerade nach vorn zeigendem Szepter statt seitlich.

## Neuer Held oder anderes Größenverhältnis

```text
python tools/riggen.py neu mein-held --hoehe 1.8 --modell assets/models/heroes/mein-held.glb --aus .godot/mein-held.json
python tools/riggen.py skelett .godot/mein-held.json --anhaenge --aus .godot/mein-held-skelett.json
python tools/riggen.py uebertragen tools/modelle/rig_profiles/torvik.json .godot/mein-held.json --aus .godot/mein-held-animationen.json
python tools/riggen.py bauen .godot/mein-held-animationen.json --aus .godot/mein-held-vorschau.glb
```

`neu` erstellt ein editierbares humanoides Profil mit skalierten Körperpunkten und Zielpunkten. Schulter, Ellbogen, Hände, Hüfte, Knie und Füße lassen sich danach einzeln anpassen. `skelett` erzeugt die Knochenhierarchie; optional mit zusätzlichen Hand-/Waffenankern. Der vorhandene Blender-Generator `helden_bau.py → mensch()` verwendet exakt dieselbe Funktion `humanoid_bones` für alle vier Helden. Ein generiertes Skelett kann über `Figur.bone(*bone)` direkt im bestehenden Modellbau verwendet werden.

`uebertragen` übernimmt semantische Posen/Schlagziele und rechnet Zielposen auf dem neuen Rig neu. Für fremde Knochennamen ordnet `bone_aliases` die Profilnamen (`arm.L`, `fore.L` usw.) den tatsächlichen GLB-Knochen zu. Benutzerdefinierte `actions` verwenden das bestehende Schema `[frame, {bone: [[axis, degrees], ...]}, root_offset]`; die Zeitbasis ist 24 fps. Mit `posen --aus datei.json` lassen sich die fertig berechneten Posen kontrollieren oder für Blender exportieren.

Ein beliebiges ungeriggtes Fremdmodell wird dadurch **nicht** automatisch korrekt geskinnt. Das Werkzeug erstellt die Skelettstruktur; die starre Teilezuordnung bleibt im vorhandenen Modellgenerator. Der GLB-Animationscompiler benötigt genau ein bereits geskinntes Rig mit TRS-Knoten. Unbekannte Knochen, Matrix-Knoten und unpassende Ziele melden klare Fehler. Die vom Werkzeug verwalteten Clips werden gemeinsam ersetzt; andere Clips, Meshes, Materialien und Skin-Daten bleiben erhalten. Wiederholte Builds sind byte-identisch und vergrößern das Modell nicht fortlaufend.

## Prüfen und ansehen

- `tools/run_tests.sh riggen` prüft 29 Rig-Fälle sowie Fluid- und Waffenprüfungen: Hierarchie, degenerierte Knochen, Handgelenkachse, feste Griffpunkte, Zielreichweite, Torviks konkrete Schlagrichtungen, verkleinerte Helden, Unrats Schwanz/kräftiger gerader Kombo-Abschluss, GLB-Erhalt und wiederholbare Builds.
- GPU-Probe: `tools/heroes/attack_probe.tscn -- --held=torvik --clip=attack_dual_strike` bzw. `attack_overhead`; über `tools/render_windows.ps1` immer stumm aufnehmen.
- `python tools/heroes/attack_clips.py --torvik-variants` erstellt animierte WebP-Vorschauen.

Schlagbahnen (16.11.2026): Griffziele (`grips`) und Schaftrichtungen (`grip_directions`) werden gemeinsam mit der Brustrotation gesetzt. Torviks aktive Ziele verwenden ausschließlich diese Griffdefinitionen; alte konkurrierende Kopfziele entfallen. Die Waffenprüfung misst zusätzlich zur Schneidenebene die tatsächliche Bewegung von außen nach innen und die Treffhöhe vor dem Rumpf. Rückholbewegungen und Sirras Stichangriffe werden davon getrennt behandelt.
