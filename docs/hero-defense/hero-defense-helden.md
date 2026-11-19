# Bollwerk – Heldenliste (Kader 2026-11-15)

Überarbeitete Projektfassung des Entwurfs `hero-defense-helden.md` vom 2026-11-04. Alle 22 ursprünglichen Helden und Ideen sind enthalten; Ada und Sorek ergänzen den Kader. Mechanik und Prägungen entsprechen den aktuellen Spieldaten.

**8 Tanks · 4 Heiler · 12 DDs.** Alle Helden sind in der Heldenwahl verfügbar.

Jeder Held hat einen Grundangriff, eine Passive, Q/W/E sowie R ab Stufe 6. Ränge und Kosten verwenden die bestehende Bollwerk-Progression. Ausweichen und Erkundungstempo bleiben gemeinsame Regeln.

Prägungen nach Welle **10, 20 und 30**: je eine Wahl aus **Offensive / Defensive / Utility**. Jeder Mitspieler wählt für seinen eigenen Helden. Rollenwerte und individuelle Fähigkeitsänderung wirken zusammen; höhere Meilensteine stapeln sich.

Blender-Quelle: `tools/modelle/kader_bau.py`; Laufzeitdaten: `data/heroes_helden.json`; Prägungen: `data/heroes_progression.json`.

---

## Tanks (halten Straßen, fangen Gegner ab)

### 1. König Unrat – Rattenkönig
Rattenkönig.
- Grundangriff: 30 Schaden, 0.9 s Abstand, 2.4 m Reichweite.
- Q **Schrottbombe**: Wurfgeschoss auf einen Ort, explodiert dreimal an derselben Stelle. Jede Explosion macht Schaden und verlangsamt 4 s um 20 %.
- W **Rattenschwarm**: Ratten springen Gegner im großen Umkreis an (bis 5 je Ziel), beißen jede Sekunde und senken je Biss die Rüstung. Ansturm schüttelt sie ab. Fallen sie ab, bleibt 6 s Rattenseuche: −15 % Schaden, −30 % Heilung, springt beim Tod auf 2 Gegner über.
- E **Königsgewand**: Schild über 15 % des Höchstlebens für 6 s. Solange er hält, wirft König Unrat feindliche Geschosse mit 15 % Chance zum Schützen zurück.
- R **Rattenbanner**: Pflanzt für 12 s ein Banner. Darin: +25 % Tempo, immun gegen Verlangsamung, 20 % weniger Schaden. Am Ende bricht die Kanalisation auf: Schaden, Gegner hochgeschleudert (1 s), 3 s um 40 % verlangsamt, und Rattenschwarm auf alle Getroffenen.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Schrottbombe: +1 Explosionen.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Königsgewand: +0.06 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Rattenbanner: +1.5 Radius (m).

---

### 2. Hauptmann Brennholt – Schildträger
Stämmiger Wachhauptmann mit blauem Turmschild, geschlossenem Helm und Schwert.
- Grundangriff: 35 Schaden, 0.9 s Abstand, 2.8 m Reichweite.
- Passiv **Eisenwille**: Schaden von Gegnern vor dir wird um 35 % verringert.
- Q **Schildstoß**: Ein Schildstoß trifft im Kegel, stößt zurück und unterbricht.
- W **Hornruf**: Spotte Gegner im Umkreis für 3 s.
- E **Ansturm**: Stürme 8 m vor, triff Gegner auf der Bahn und betäube sie.
- R **Schildwall**: Eine quer gestellte Schildmauer hält Gegner und Geschosse 6 s auf.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Schildstoß: +1.5 Rückstoß (m).
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Schildwall: +650 Leben.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Hornruf: +2 Radius (m).

---

### 3. Mira Steinhaut – Felsenwächterin
Halbriesin aus Basalt mit kristalliner Krone und schweren Felsenschultern.
- Grundangriff: 35 Schaden, 0.9 s Abstand, 2.8 m Reichweite.
- Passiv **Moos**: Nach 2 s Stillstand regenerierst du 3 % deines Höchstlebens pro Sekunde.
- Q **Felsbrocken**: Ein Fels schlägt nach 0,8 s am Zielpunkt ein und betäubt.
- W **Versteinern**: Werde 2 s unbeweglich und unverwundbar; danach brechen Splitter aus.
- E **Bodenwelle**: Ein Bodenriss schleudert Gegner in einer Linie hoch.
- R **Bergsturz**: Fünf Felsen schlagen nacheinander rund um den Zielpunkt ein.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Bergsturz: +1 Anzahl.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Versteinern: +100 Heilung.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Bodenwelle: +0.8 Breite (m).

---

### 4. Der Grauhirte – Rudelführer
Alter Hirte mit grauem Bart, Wolfspelz, langem Mantel und Schädelstab.
- Grundangriff: 35 Schaden, 0.9 s Abstand, 2.8 m Reichweite.
- Passiv **Rudel**: Jeder lebende eigene Wolf gewährt 2 Rüstung.
- Q **Ruf der Wölfe**: Rufe zwei Wölfe, höchstens vier; sie folgen dir und kämpfen.
- W **Hetzjagd**: Deine Wölfe springen zum Ziel und halten Gegner fest.
- E **Hirtenstab**: Ziehe Gegner im vorderen Kegel zu dir.
- R **Rudelgeist**: Eine Wolfsaura stärkt dich und deine Wölfe; Treffer heilen dich.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Ruf der Wölfe: +12 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Ruf der Wölfe: +180 Leben.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Ruf der Wölfe: +1 Höchstzahl.

---

### 5. Ralda Runenschmied – Runenwächterin
Gedrungene Runenschmiedin mit hellem Bart, schwerem Hammer und Rückenamboss. Hält als Tank die Straße.
- Grundangriff: 35 Schaden, 0.9 s Abstand, 2.8 m Reichweite.
- Passiv **Handwerk**: Eigene Rezepte kosten 10 % weniger Gold.
- Q **Runenhammer**: Ein Hammerschlag trifft vor dir und stärkt Helden in der Nähe.
- W **Barrikade**: Eine widerstandsfähige Barrikade hält Gegner 6 s auf.
- E **Waffe schärfen**: Stärke den Schaden eines verbündeten Helden 8 s um 25 %.
- R **Schmiedefeuer**: Ein Runenamboss schützt Verbündete mit Schilden und stärkt ihren Schaden.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Runenhammer: +45 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Barrikade: +650 Leben.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Waffe schärfen: +3 Dauer (s).

---

### 6. Bruno Fassroller – Kellerwächter
Breiter Kellerwächter mit Fass auf dem Rücken, Holzkrug und schwerem Lederschurz.
- Grundangriff: 35 Schaden, 0.9 s Abstand, 2.8 m Reichweite.
- Passiv **Zäher Sud**: Treffer heilen dich um 2 % deines Höchstlebens, höchstens einmal pro Sekunde.
- Q **Rollendes Fass**: Ein schweres Fass durchrollt Gegner, verlangsamt und stößt sie zurück.
- W **Malzschild**: Eine dicke Malzschicht gewährt dir Schild und Schadensminderung.
- E **Schankruf**: Spotte Gegner und heile dich für jeden angelockten Gegner.
- R **Große Fassflut**: Drei schwere Fässer fächern auf und werfen Gegner um.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Große Fassflut: +1 Anzahl.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Malzschild: +0.12 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Rollendes Fass: +3 Reichweite (m).

---

### 7. Ada Glockenwacht – Glockenritterin
Glockenritterin in bronzener Rüstung, mit Schulterglocken und schwerer Handglocke.
- Grundangriff: 35 Schaden, 0.9 s Abstand, 2.8 m Reichweite.
- Passiv **Resonanz**: Jeder vierte Grundangriff erzeugt einen Schild über 8 % deines Höchstlebens.
- Q **Glockenschlag**: Ein schwerer Klöppel trifft und unterbricht Gegner.
- W **Nachhallpanzer**: Ein Resonanzschild schützt dich; beim Ende trifft ein Nachhall Gegner.
- E **Wachtgeläut**: Das Geläut zieht Gegner auf dich und schützt nahe Helden.
- R **Abendglocke**: Acht Sekunden Geläut: Gegner werden unterbrochen, Verbündete erhalten Schilde.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Abendglocke: +20 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Nachhallpanzer: +0.12 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Wachtgeläut: +2 Radius (m).

---

### 8. Sorek Ankerträger – Kettenwächter
Kettenwächter in petrolfarbener Rüstung, mit großem Anker und goldener Kette.
- Grundangriff: 35 Schaden, 0.9 s Abstand, 2.8 m Reichweite.
- Passiv **Schwerer Stand**: Solange du stillstehst, erleidest du 15 % weniger Schaden.
- Q **Ankerwurf**: Ein Anker trifft den ersten Gegner, zieht ihn zu dir und betäubt.
- W **Kettenkreis**: Schwinge die Kette: Flächenschaden, Gegner werden verlangsamt.
- E **Festmachen**: Verankere dich: Schild, weniger Schaden und immun gegen Verlangsamung.
- R **Hafenbollwerk**: Ein breites Ankerbollwerk stoppt Gegner und Projektile für 8 s.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Ankerwurf: +1.5 Zugweite (m).
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Hafenbollwerk: +800 Leben.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Kettenkreis: +1.5 Radius (m).

---

## Heiler (halten die Gruppe am Leben)

### 9. Oberschwester Vesna – Feldärztin
Feldärztin.
- Grundangriff: 38 Schaden, 0.4 s Abstand, 15 m Reichweite.
- Passiv **Spritzengewehr**: Schüsse fliegen sichtbar und treffen, was in der Bahn steht: eigene Gebäude werden geheilt, Gegner nehmen Schaden und bekommen 3 s lang 50 % weniger Heilung. 8 Schuss, dann Nachladen.
- Q **Aderlass**: Band zwischen einem Gegner und Vesna: 4 s lang verliert der Gegner Leben und Vesna bekommt es. Reißt, wenn beide zu weit auseinander sind. Gut gegen Elite-Gegner und Bosse.
- W **Betäubungspfeil**: Pfeil in Zielrichtung: trifft den ersten Gegner und betäubt ihn 1,8 s. Unterbricht aufgeladene Fähigkeiten.
- E **Notfallkapsel**: Kapsel auf Vesna oder ein eigenes Gebäude, hält 10 s. Fällt das Leben darunter unter 30 %, platzt sie sofort: 35 % Heilung und kurzer Schild. Sonst heilt sie am Ende 10 % und die Abklingzeit sinkt um die Hälfte.
- R **Hochdosis**: Hochdosis auf Vesna oder ein eigenes Gebäude: sofort 25 % Heilung, 8 s lang +50 % Schaden, −50 % erlittener Schaden, +20 % Tempo.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Betäubungspfeil: +30 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Notfallkapsel: +0.08 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Aderlass: +3 Bandreichweite (m).

---

### 10. Schwester Albe – Lichtheilerin
Ordensfrau in heller Robe mit geschützter Lichtlaterne.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Gnade**: Überschüssige Fähigkeitheilung wird zu einem begrenzten Schild.
- Q **Lichtstrahl**: Ein Lichtstrahl schadet Gegnern und heilt Verbündete auf der Linie.
- W **Schutzkreis**: Der Schutzkreis heilt und senkt erlittenen Schaden von Helden um 30 %.
- E **Rettungsgriff**: Ziehe einen verbündeten Helden zu dir und gib ihm einen Schild.
- R **Auferstehung**: Belebe gefallene Mitspieler wieder; lebende Verbündete werden geheilt und geschützt.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Lichtstrahl: +40 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Schutzkreis: +15 Heilung.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Rettungsgriff: +3 Reichweite (m).

---

### 11. Fenn Laternenträger – Pfadfinder
Junger Pfadfinder mit Bogen, Köcher, Leuchtkugel und leichtem Mantel.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Schein**: Gegner im Laternenschein gewähren der Gruppe 20 % zusätzliches Killgold.
- Q **Laterne setzen**: Setze bis zu drei Laternen: ihr Schein heilt und beschleunigt Helden.
- W **Leuchtpfeil**: Markiere einen Gegner: Er nimmt 6 s lang 20 % mehr Schaden.
- E **Wegsprung**: Teleportiere dich zur Laterne nahe dem Zielpunkt und heile dich.
- R **Leuchtfeuer**: Alle Laternen werden 6 s zu Sonnen: mehr Heilung und wiederholte Unterbrechungen.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Leuchtpfeil: +40 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Laterne setzen: +12 Heilung.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Laterne setzen: +1 Höchstzahl.

---

### 12. Der Totengräber – Seelenhüter
Seelenhüter mit Kapuze, langem Mantel, Bart und breitem Spaten. Seine Seelenkraft heilt Verbündete.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Seelenrest**: Grundangriffe heilen den verletztesten nahen Verbündeten um 18.
- Q **Seelenernte**: Eine Sichel aus Seelenkraft trifft Gegner und heilt nahe Verbündete.
- W **Grabhelfer**: Rufe zwei vergängliche Grabhelfer, die Gegner ablenken und bekämpfen.
- E **Totenwache**: Eine Seelenlaterne heilt Verbündete und schwächt Gegner.
- R **Rückkehr der Seelen**: Gefallene Helden kehren zurück; ein großer Seelensegen heilt die Gruppe.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Grabhelfer: +15 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Totenwache: +18 Heilung.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Grabhelfer: +5 Dauer (s).

---

## DDs (Einzel- und Flächenschaden)

### 13. Torvik Sturmruf – Elementarkrieger
Elementarkrieger.
- Grundangriff: 30 Schaden, 0.8 s Abstand, 2.6 m Reichweite.
- Passiv **Sturmbrandung**: Grundangriffe lösen mit 20 % Chance einen Windstoß aus: 2 Zusatzangriffe (höchstens alle 1,5 s). Jeder Windstoß setzt mit 30 % Chance Donnerhieb zurück und verstärkt ihn um 25 %, der Blitz springt dann auf 2 weitere Gegner.
- Q **Donnerhieb**: Zwei Blitzschläge mit beiden Äxten im Kegel vor Torvik, der zweite betäubt kurz.
- W **Glutnova**: Feuerwelle um Torvik, setzt Getroffene 3 s in Brand. Trifft sie 3 oder mehr Gegner, kostet die nächste nur die Hälfte.
- E **Erdschock**: Felsgeschoss in Zielrichtung, trifft den ersten Gegner und verlangsamt ihn 2 s um 40 %.
- R **Windaufstieg**: 15 s Luftelementar: Donnerhieb wird zu Windschlag, Abklingzeit halbiert, doppelte Windstoß-Chance. Beim Verwandeln schleudert ein Windstoß Gegner im Umkreis zurück und betäubt sie 1 s.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Donnerhieb: +0.2 Betäubungsdauer (s).
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Windaufstieg: +2 Dauer (s).
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Erdschock: +3 Reichweite (m).

---

### 14. Zix Funkenkurbel – Mechagoblin
Mechagoblin.
- Grundangriff: 15 Schaden, 0.5 s Abstand, 7 m Reichweite.
- Passiv **Schraubenschlüssel**: Die Funkenpistole repariert eigene Gebäude (6 % je Schuss). Gebäude steigen mit Zix' Stufe mit und halten, bis sie zerstört werden, höchstens so viele je Art wie angegeben.
- Q/W/E **Baukasten**: Drei der zehn bestehenden Konstrukte wählen; Bolzenturm, Flammenspeier, Raketenwerfer, Tesla-Spule, Sanitätsmast, Heilsprinkler, Schrottbot, Elektrozaun, Schildkuppel oder Magnetköder. Zwischen Wellen an der Feste austauschbar.
- R **Überspannung**: 10 s lang alle eigenen Gebäude verstärkt: doppeltes Angriffstempo, +50 % Wirkung, volle Reparatur und eine Sonderwirkung je Gebäude.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Überspannung: +2 Dauer (s).
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Baukasten: +150 Konstruktleben.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Überspannung: -6 Abklingzeit (s).

---

### 15. Sirra Nachtfalke – Giftklinge
Schlanke Giftkämpferin in violettem Leder mit Kapuze und zwei Dolchen.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 2.8 m Reichweite.
- Passiv **Gift**: Grundangriffe legen Gift auf, bis zu zehn Stapel je Gegner.
- Q **Klingenwurf**: Eine Klinge durchbohrt Gegner und legt drei Giftstapel auf.
- W **Schattensprung**: Springe zum Zielpunkt; dein nächster Grundangriff verursacht dreifachen Schaden.
- E **Rauchbombe**: Eine Rauchwolke senkt den Schaden der Gegner darin um 45 %.
- R **Todesfalter**: Zünde deine Giftstapel auf Gegnern im Umkreis: 55 Schaden je Stapel.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Klingenwurf: +1 Giftstapel.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Rauchbombe: +0.08 Schadenssenkung.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Schattensprung: +2 Reichweite (m).

---

### 16. Kaspar der Armbrustmacher – Tüftler
Armbrustmacher mit runder Brille, Werkzeuggürtel und breiter Armbrust.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Werkbank**: Eigene Geschütze in 8 m Umkreis schießen 25 % schneller.
- Q **Bolzen**: Ein schwerer Bolzen durchbohrt bis zu drei Gegner.
- W **Geschütz**: Stelle eine Armbrust für 30 s auf, höchstens drei.
- E **Sprungfeder**: Springe rückwärts; eine Falle am Ausgangspunkt betäubt Gegner.
- R **Belagerungsgeschütz**: Ein großer Mörser beschießt Gegnergruppen 20 s lang.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Geschütz: +15 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Sprungfeder: +0.1 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Geschütz: +8 Dauer (s).

---

### 17. Yuna Schnittwind – Klingentänzerin
Klingentänzerin mit langem Zopf, leichter Kleidung und schmalem Schwert.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 2.8 m Reichweite.
- Passiv **Fluss**: Treffer gewähren 3 % Angriffstempo, bis 30 %, für 3 s.
- Q **Windschnitt**: Ein kurzer Sprint trifft alle Gegner entlang deiner Bahn.
- W **Wirbel**: Wirble 2 s weiterlaufend mit deiner Klinge.
- E **Konter**: Eine Sekunde Konterhaltung: der erste Treffer wird abgewehrt und dreifach erwidert.
- R **Tausend Schnitte**: Acht schnelle Sprünge zwischen Gegnern; währenddessen unverwundbar.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Tausend Schnitte: +2 Anzahl.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Konter: +0.3 Dauer (s).
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Windschnitt: +2 Reichweite (m).

---

### 18. Orrin Glutwort – Feuermagier
Rußgeschwärzter Gelehrter in dunkler Robe mit Zauberbuch und Flammenstab.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Brand**: Grundangriffe legen eine kurze brennende Fläche am Ziel an.
- Q **Feuerball**: Ein Feuerball explodiert am ersten getroffenen Gegner.
- W **Feuerwand**: Eine vier Sekunden brennende Linie verletzt Gegner wiederholt.
- E **Flammenschritt**: Springe vorwärts und hinterlasse eine brennende Spur.
- R **Meteor**: Nach 1,5 s schlägt ein gewaltiger Meteor im sichtbaren Zielkreis ein.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Meteor: +100 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Flammenschritt: +0.1 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Feuerwand: +1.5 Dauer (s).

---

### 19. Weise Ilsabet – Frostmagierin
Ältere Magierin mit weißem Haar, langer Robe und verzweigtem Kristallstab.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Kälte**: Frosttreffer verlangsamen; jeder fünfte Treffer friert kurz ein.
- Q **Eislanze**: Eine Eislanze durchbohrt die Reihe und sammelt Kälte.
- W **Frostfeld**: Ein Frostfeld verlangsamt Gegner stark und sammelt Kälte.
- E **Eisblock**: Schütze ein nahes verbündetes Ziel mit Eis; Helden werden kurz unverwundbar und heilen.
- R **Gletscher**: Ein großer Eiskegel friert Gegner ein und zerspringt mit hohem Schaden.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Eislanze: +40 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Eisblock: +80 Heilung.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Frostfeld: +1.5 Radius (m).

---

### 20. Tamo der Donnerbauer – Gewitterbauer
Breitschultriger Bauer mit Strohhut, Kupfergabel und aufgerollten Ärmeln.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 2.8 m Reichweite.
- Passiv **Ladung**: Erlittener Schaden lädt dich auf; volle Ladung verstärkt die nächste Schadensfähigkeit um 50 %.
- Q **Blitzkette**: Ein Blitz springt auf bis zu fünf Gegner.
- W **Gabelwurf**: Eine Kupfergabel schlägt am Ziel ein und zieht 4 s Blitze an.
- E **Donnerschlag**: Ein Donnerschlag um dich betäubt kurz.
- R **Gewitterfront**: Ein Gewitter folgt dir 8 s und trifft Gegner in deiner Nähe.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Blitzkette: +1 Anzahl.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Donnerschlag: +0.1 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Gewitterfront: +1.5 Radius (m).

---

### 21. Varg Eisenbart – Berserker
Berserker mit freier Brust, Fellschultern, Bart und zwei schweren Äxten.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 2.8 m Reichweite.
- Passiv **Blutmut**: Mit sinkendem Leben steigt dein Schaden um bis zu 40 %.
- Q **Bluthieb**: Ein wuchtiger Hieb heilt dich für einen Teil des verursachten Schadens.
- W **Kampfrausch**: Erhöhe 6 s deinen Schaden und dein Angriffstempo.
- E **Eisenbrecher**: Springe vor und zertrümmere gegnerische Rüstung.
- R **Letztes Aufbäumen**: Erhalte einen starken Schild und mehr Lebensraub und Schaden.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Letztes Aufbäumen: +0.15 Schadensbonus.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Letztes Aufbäumen: +0.15 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Eisenbrecher: +2 Reichweite (m).

---

### 22. Lior Spiegelseher – Trugbildmagier
Spiegelseher in dunkler Robe mit ovalem Spiegel und Trugbildern.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Spiegelhaut**: Ein eigenes lebendes Trugbild verringert deinen erlittenen Schaden um 15 %.
- Q **Spiegelsplitter**: Ein durchbohrender Splitter markiert Gegner und erhöht Folgeschaden.
- W **Trugbilder**: Zwei Spiegelbilder lenken Gegner ab und greifen 12 s lang an.
- E **Spiegelwechsel**: Tausche den Platz mit deinem nächsten Spiegelbild und erhalte einen Schild.
- R **Spiegelkabinett**: Rufe vier starke Trugbilder, die Gegner ablenken.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Spiegelkabinett: +20 Schaden.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Trugbilder: +200 Leben.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Trugbilder: +4 Dauer (s).

---

### 23. Die Krähenfrau – Fluchweberin
Dunkle Fluchweberin mit Federkragen, langem Gewand und Krähe auf der Hand.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Schwarzfeder**: Grundangriffe machen Gegner 4 s lang um 10 % verwundbarer.
- Q **Fluchfeder**: Eine Feder durchbohrt Gegner und erhöht ihren erlittenen Schaden.
- W **Krähenschwarm**: Ein Krähenschwarm verletzt und schwächt Gegner im Zielgebiet.
- E **Unheilsruf**: Ein Ruf unterbricht Gegner und senkt ihre Rüstung.
- R **Schwarzer Himmel**: Ein großer Fluchschwarm verursacht Schaden und macht Gegner verwundbar.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Fluchfeder: +0.05 Verwundbarkeit.
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Krähenschwarm: +0.08 Schadenssenkung.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Schwarzer Himmel: +1.5 Radius (m).

---

### 24. Tessa Sturmsegel – Windschützin
Windschützin mit Zopf, Bogen und weißem Rückensegel.
- Grundangriff: 43 Schaden, 0.7 s Abstand, 14 m Reichweite.
- Passiv **Rückenwind**: Grundangriffe gewähren 2 s lang 15 % Lauftempo.
- Q **Windbolzen**: Ein Windbolzen durchbohrt Gegner und schiebt sie zurück.
- W **Sturmböe**: Eine breite Böe stößt Gegner zurück und verlangsamt.
- E **Segelsprung**: Ein weiter Sprung stärkt kurz dein Lauftempo.
- R **Orkan**: Ein Orkan zieht Gegner wiederholt zur Mitte und verursacht Schaden.
- Prägungen (jeweils zusätzlich zu den Rollenwerten):
  - **Offensive**: Mehr Schaden für Angriffe und Fähigkeiten. Windbolzen: +1 Rückstoß (m).
  - **Defensive**: Mehr Leben und Rüstung; stärkere Heilung und Schilde. Segelsprung: +0.1 Schildanteil.
  - **Utility**: Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten. Orkan: +1.5 Radius (m).

---

## Gelände

Der Grundboden besteht aus rauem, felsigem Basalt mit echter Farb-, Normal- und Rauheitsmap. Um Feste, Kapellen, Türme und Schmiede liegt versetztes Basaltpflaster. Unter Bäumen liegen ausgefranste Erdflächen; im Schlund passen sie sich dem Hang an. Straßen bleiben klar lesbar und Warnflächen über dem Boden sichtbar.
