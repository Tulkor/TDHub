# Bollwerk – Heldenliste (Entwurf 1, 2026-11-04)

Grundlage: aktives Kampfsystem (siehe Designdokument Abschnitt 5a). Jeder Held hat:
- **Grundangriff** (automatisch auf das nächste Ziel oder per Maus/Taste gezielt),
- **Q, W, E** normale Fähigkeiten (4 Stufen), **R** ultimative Fähigkeit (3 Stufen, ab Level 6/12/18),
- **eine Passive**,
- **Ausweichen** (Leertaste) – bei allen Helden gleich: kurzer Sprung in Laufrichtung, 0,25 s unverwundbar, 6 s Abklingzeit. Manche Helden haben eine eigene Variante (steht dann dabei).
- Prägungen bei Level 10 und 20: 1 von 3 (Offensiv/Defensiv/Hilfe), siehe `hero-defense-praegungen.md`. Die Prägungs-Zeilen in dieser Datei sind überholt.

„Skillshot“ = in Mausrichtung, trifft nur, was in der Linie/Fläche steht. „Ziel“ = klickt einen Gegner an (für Maus-Spieler leichter).

---

## Wall (halten Straßen, fangen Gegner ab)

### 1. Hauptmann Brennholt – Schildträger
Stämmiger Wachhauptmann mit Turmschild. Einfachster Held für Anfänger.
- Passiv **Eisenwille**: Blocken von vorne halbiert Schaden aus Kegeln und Geschossen.
- Q **Schildstoß** (Kegel vorne): stößt Gegner zurück, unterbricht Aufladungen von Gegnerfähigkeiten.
- W **Hornruf**: Gegner im Umkreis greifen 3 s nur ihn an (Spott).
- E **Ansturm** (Skillshot-Linie): rennt los, nimmt den ersten Gegner mit bis zur nächsten Wand, betäubt.
- R **Schildwall**: stellt eine Schildmauer quer zur Straße (6 s), Gegner und feindliche Geschosse kommen nicht durch.
- Prägung: Schildwall wird zum Ring um ihn herum.

### 2. Mira Steinhaut – Felsenwächterin
Halbriesin aus dem Gebirge, langsam, sehr robust.
- Passiv **Moos**: regeneriert stark, solange sie 2 s stillsteht.
- Q **Felsbrocken** (Skillshot, Mörser-artig): wirft einen Stein auf einen Punkt, Aufschlag nach 0,8 s, betäubt.
- W **Versteinern**: 2 s unverwundbar und unbeweglich, wirft danach Splitter im Kreis.
- E **Bodenwelle** (Linie): Riss im Boden, Gegner werden hochgeschleudert.
- R **Bergsturz**: 5 Felsen regnen nacheinander auf markierte Punkte (Spieler zielt jeden einzeln).

### 3. Der Grauhirte – Rudelführer
Alter Hirte mit Wolfsrudel.
- Passiv **Rudel**: je Wolf +2 Rüstung.
- Q **Ruf der Wölfe**: beschwört 2 Wölfe (bis zu 4).
- W **Hetzjagd** (Ziel): alle Wölfe springen ein Ziel an und halten es fest.
- E **Hirtenstab** (Kegel): schlägt zu und zieht Gegner zu sich.
- R **Rudelgeist**: wird selbst zum großen Wolf, Wölfe bekommen Lebensraub.

---

## Klinge (Einzelschaden, beweglich)

### 4. Sirra Nachtfalke – Giftklinge
Schnelle Kämpferin mit zwei Dolchen. Belohnt gutes Ausweichen.
- Passiv **Gift**: Treffer stapeln Gift (bis 10).
- Ausweichen eigene Variante **Schattenschritt**: 2 Aufladungen.
- Q **Klingenwurf** (Skillshot): durchbohrt, legt 3 Gift-Stapel.
- W **Schattensprung** (Ziel): springt hinter das Ziel, nächster Angriff kritisch.
- E **Rauchbombe**: Gegner in der Wolke verfehlen.
- R **Todesfalter**: zündet alles Gift auf allen Gegnern im Umkreis auf einmal.

### 5. Kaspar der Armbrustmacher – Tüftler
Brillenträger mit Werkzeuggürtel. Bringt TD-Gefühl in den Modus.
- Passiv **Werkbank**: Geschütze in seiner Nähe schießen 25 % schneller.
- Q **Bolzen** (Skillshot): weiter Schuss, durchschlägt 2 Gegner.
- W **Geschütz**: stellt eine Armbrust auf (bis zu 3), hält 30 s.
- E **Sprungfeder**: springt rückwärts und lässt eine Falle zurück.
- R **Belagerungsgeschütz**: großer Turm für 20 s, Mörser-Schüsse mit Warnkreis auch für Gegner sichtbar.

### 6. Yuna Schnittwind – Klingentänzerin
Elegante Schwertkämpferin, Nahkampf mit viel Bewegung.
- Passiv **Fluss**: jeder Treffer +3 % Angriffstempo (bis 30 %), verfällt nach 3 s ohne Treffer.
- Q **Windschnitt** (Linie): kurzer Sprint durch Gegner hindurch, Schaden an allen.
- W **Wirbel**: dreht sich 2 s, bewegt sich dabei weiter.
- E **Konter**: 1 s Haltung; wird sie getroffen, weicht sie aus und schlägt zurück (perfektes Timing = Schaden ×3).
- R **Tausend Schnitte**: springt 8-mal zwischen Gegnern im Umkreis, ist dabei unverwundbar.

---

## Sturm (Flächenschaden)

### 7. Orrin Glutwort – Feuermagier
Rußgeschwärzter Gelehrter.
- Passiv **Brand**: Feuerschaden hinterlässt kurz brennenden Boden.
- Q **Feuerball** (Skillshot): explodiert beim ersten Treffer.
- W **Feuerwand** (Linie, frei gezogen): 4 s brennende Wand.
- E **Flammenschritt**: Ausweichen, das eine Feuerspur hinterlässt.
- R **Meteor** (Ort): großer Warnkreis, Aufschlag nach 1,5 s, riesiger Schaden. Auch die Spieler sehen die Aufladung.

### 8. Weise Ilsabet – Frostmagierin
Ältere Magierin, kontrolliert das Schlachtfeld.
- Passiv **Kälte**: Frost verlangsamt, 5 Stapel frieren ein.
- Q **Eislanze** (Skillshot-Linie): durchbohrt ganze Reihen.
- W **Frostfeld** (Ort): Fläche verlangsamt stark.
- E **Eisblock**: friert sich selbst ein (unverwundbar, heilt), oder einen Mitspieler.
- R **Gletscher**: Kegel aus Eis, alle Gegner darin gefroren, danach zerspringt das Eis.

### 9. Tamo der Donnerbauer – Gewitterbauer
Großer Bauer mit Kupfergabel, nah dran am Geschehen.
- Passiv **Ladung**: erlittener Schaden lädt ihn auf, volle Ladung verstärkt die nächste Fähigkeit.
- Q **Blitzkette** (Ziel): springt auf 5 Gegner.
- W **Gabelwurf** (Skillshot): bleibt stecken, zieht Blitze 4 s lang an.
- E **Donnerschlag**: Kreis um ihn, betäubt kurz.
- R **Gewitterfront**: Unwetter folgt ihm 8 s, Blitze schlagen zufällig in Gegner ein.

---

## Hüter (Unterstützung)

### 10. Schwester Albe – Lichtheilerin
Ordensfrau mit Laterne aus Licht.
- Passiv **Gnade**: Heilung über das volle Leben hinaus wird zum Schild.
- Q **Lichtstrahl** (Skillshot-Linie): schadet Gegnern, heilt Mitspieler auf der Linie.
- W **Schutzkreis** (Ort): Mitspieler darin nehmen 30 % weniger Schaden.
- E **Rettungsgriff** (Mitspieler): zieht einen Mitspieler zu sich, z. B. aus einer roten Fläche.
- R **Auferstehung**: belebt alle toten Mitspieler, kurze Unverwundbarkeit.

### 11. Fenn Laternenträger – Pfadfinder
Junger Späher, Sicht und Tempo für das Team.
- Passiv **Schein**: Gegner in seinen Laternen geben +20 % Gold.
- Q **Laterne setzen**: Sicht, Mitspieler im Schein laufen schneller (bis zu 3).
- W **Leuchtpfeil** (Skillshot): markiert das Ziel, alle Treffer darauf +20 %.
- E **Wegsprung**: teleportiert zu einer Laterne.
- R **Leuchtfeuer**: alle Laternen werden 6 s zu Sonnen, blenden Gegner (Fähigkeiten brechen ab).

### 12. Ralda Runenschmied – Schmiedin
Zwergin mit Hammer und Amboss auf dem Rücken.
- Passiv **Handwerk**: Rezepte kosten für sie und Mitspieler im Umkreis 10 % weniger.
- Q **Runenhammer** (Kegel): Schaden, Rune auf dem Boden verstärkt Mitspieler.
- W **Barrikade** (Linie): baut eine Holzwand, die Gegner aufhält.
- E **Waffe schärfen** (Mitspieler): +25 % Schaden für 8 s.
- R **Schmiedefeuer**: Amboss in den Boden, Mitspieler im Umkreis bekommen Rüstung und Brandschaden auf Angriffe.

---

## Wunschhelden von Lukas (2026-11-04)

Vier zusätzliche Starthelden, Vorbilder von Lukas genannt. Mechanik angelehnt, Namen, Aussehen und Werte eigen.

### 13. Torvik Sturmruf – Elementarkrieger (Klinge, Nahkampf)
Vorbild: Verstärkungs-Schamane (WoW). Hüne mit zwei Runenäxten, Blitze laufen über die Klingen.
- Passiv **Sturmbrandung** (Mischung aus Windzorn und Sturmbringer): Jeder Grundangriff hat 20 % Chance auf **Windstoß**, also 2 sofortige Zusatzangriffe (höchstens alle 1,5 s). Jeder Windstoß hat 30 % Chance, die Abklingzeit von **Donnerhieb** zurückzusetzen und den nächsten Donnerhieb um 25 % zu verstärken (Blitz springt dann auf 2 weitere Gegner).
- Q **Donnerhieb** (Nahkampf, kurzer Kegel): zwei Blitzschläge mit beiden Äxten, hoher Einzelschaden, kurze Abklingzeit (6 s).
- W **Glutnova** (Kreis um ihn): Feuerwelle nach außen, Schaden an allen im Umkreis, setzt kurz in Brand. Trifft sie 3 oder mehr Gegner, ist die nächste Nova halb so teuer.
- E **Erdschock** (Skillshot, Fernkampf): Felsgeschoss in Mausrichtung, Schaden am ersten Ziel, verlangsamt 2 s. Gegen fliehende Gegner und Flieger.
- R **Windaufstieg** (Vorbild Aufstieg): 15 s lang Luftelementar. Donnerhieb wird zu **Windschlag** (Reichweite 6 Felder, ein Fernkampfangriff, durchschlägt), Abklingzeit halbiert, Windstoß-Chance verdoppelt. Beim Verwandeln Windstoß im Kreis (Rückstoß).

### 14. König Unrat – Rattenkönig (Wall)
Vorbild: Rat King (Deadlock), Fähigkeiten gleich, nur Fähigkeit 2 hinterlässt zusätzlich einen Debuff. Kleiner, dicker Herrscher in Lumpenmantel und Blechkrone, Ratten krabbeln auf ihm herum.
- Q **Schrottbombe** (Ort, blauer Kreis für Mitspieler): Wurfgeschoss, explodiert 3-mal an derselben Stelle, jede Explosion Schaden und 20 % Verlangsamung (4 s).
- W **Rattenschwarm**: Ratten springen Gegner im großen Umkreis an (bis 5 pro Ziel), beißen jede Sekunde und senken je Biss die Rüstung (Stapel 4 s). Gegner mit Sprung/Ansturm schütteln sie ab. **Neu:** Fallen die Ratten ab, bleibt **Rattenseuche** 6 s auf dem Ziel: −15 % verursachter Schaden, −30 % erhaltene Heilung, und stirbt das Ziel, springt die Seuche auf 2 Gegner in der Nähe über.
- E **Königsgewand**: Schild über 15 % des Höchstlebens für 6 s, 15 % Chance, feindliche Geschosse zum Schützen zurückzuwerfen.
- R **Rattenbanner** (Ort): pflanzt ein Banner (12 s, großer Kreis). Mitspieler darin: mehr Tempo, immun gegen Verlangsamung, 20 % weniger Schaden. Am Ende bricht die Kanalisation auf: Schaden, Gegner hochgeschleudert, 40 % verlangsamt, und die freigesetzten Ratten wirken Rattenschwarm auf alle Getroffenen. Die Warnfläche des Ausbruchs füllt sich während der 12 s, Gegner sehen sie auch.

### 15. Oberschwester Vesna – Feldärztin (Hüter, Fernkampf)
Vorbilder: Nurse Harrow (Deadlock) und Ana (Overwatch). Hagere Ärztin mit Pestmaske und Spritzengewehr.
- Passiv/Grundangriff **Spritzengewehr**: Schüsse sind Skillshots (Geschoss fliegt sichtbar). Trifft es einen Mitspieler, heilt es; trifft es einen Gegner, macht es Schaden und senkt 3 s dessen Heilung. 8 Schuss, dann Nachladen. Im Maus-Modus hilft eine leichte Zielhilfe auf Mitspieler.
- Q **Aderlass** (eigene Idee): Ziel-Band zwischen einem Gegner und einem Mitspieler. 4 s lang verliert der Gegner Leben und der Mitspieler bekommt es. Reißt, wenn beide zu weit auseinander sind. Gut gegen Elite-Gegner und Bosse.
- E **Notfallkapsel** (eigene Idee): Schuss auf sich oder einen Mitspieler. Die Kapsel hält 10 s; fällt das Leben in der Zeit unter 30 %, platzt sie sofort und heilt 35 % plus kurzer Schild. Wird sie nicht ausgelöst, heilt sie am Ende 10 % und die Abklingzeit sinkt um die Hälfte.
- R **Hochdosis** (wie Anas Ult): schießt einem Mitspieler eine Hochdosis: sofort 25 % Heilung, 8 s lang +50 % Schaden, −50 % erlittener Schaden, +20 % Tempo. Der Mitspieler leuchtet sichtbar.

### 16. Zix Funkenkurbel – Mechagoblin (eigene Rolle: Spezialist)
Kleiner Goblin in einem Laufwerk mit Kranarm, voller Werkzeug. Passt in keine der vier Rollen: Er stellt sich sein Kit selbst zusammen.

- **Baukasten**: 10 Gebäude zur Auswahl, **3 davon** liegen auf Q, W, E. Auswahl bei der Heldenwahl, ändern zwischen den Wellen in der Werkstatt der Feste (nicht während einer Welle).
- Passiv **Schraubenschlüssel**: Grundangriff (kurze Funkenpistole) auf eigene Gebäude repariert sie. Gebäude steigen mit seinem Level mit. Gebäude halten, bis sie zerstört werden, mit Höchstzahl je Art.
- R **Überspannung**: 10 s lang alle eigenen Gebäude verstärkt: +100 % Angriffstempo und Wirkung, volle Reparatur, Sonderwirkung je Gebäude (siehe Tabelle).

| # | Gebäude | Rolle | Wirkung | Max. | Überspannung |
|---|---|---|---|---|---|
| 1 | Bolzenturm | Schaden | schneller Einzelschuss | 2 | Schüsse durchschlagen |
| 2 | Flammenspeier | Schaden | Kegel nach vorne, Brand | 2 | Kegel doppelt so breit |
| 3 | Raketenwerfer | Schaden | Mörser auf Gruppen (blauer Warnkreis) | 1 | 3 Raketen pro Salve |
| 4 | Tesla-Spule | Schaden/Kontrolle | Kettenblitz, jeder 4. Treffer betäubt kurz | 2 | jeder Treffer betäubt 0,3 s |
| 5 | Sanitätsmast | Heilung | Heilstrahl auf den verletztesten Mitspieler | 1 | Strahl heilt 3 Ziele |
| 6 | Heilsprinkler | Heilung | Heilfläche am Boden | 2 | Fläche gibt zusätzlich Schild |
| 7 | Schrottbot | Tank | kleiner Roboter, spottet Gegner, folgt Zix oder bleibt stehen | 1 | wird groß, Spott-Kreis |
| 8 | Elektrozaun | Kontrolle | 2 Masten mit Stromlinie: Gegner darauf verlangsamt, Rüstung −, nach 3 s Kontakt Betäubung | 2 | Betäubung sofort |
| 9 | Schildkuppel | Schutz | Kuppel hält Gegnergeschosse ab | 1 | Kuppel heilt darin |
| 10 | Magnetköder | Kontrolle | zieht Gegner an und lenkt sie 4 s ab | 2 | zieht stärker, explodiert am Ende |

---

## Freischaltbar über das Profil (Ideen für später)

- **Varg Eisenbart**: Berserker, mehr Schaden bei weniger Leben.
- **Lior Spiegelseher**: erzeugt Trugbilder, die Gegnerfähigkeiten auf sich ziehen.
- **Die Krähenfrau**: Fluchtiere, Gegner nehmen mehr Schaden.
- **Bruno Fassroller**: rollt Bierfässer (Skillshots mit Abprallern).
- **Tessa Sturmsegel**: Fernkampf mit Wind, schiebt Gegner zurück.
- **Der Totengräber**: holt besiegte Gegner kurz als Helfer zurück.
