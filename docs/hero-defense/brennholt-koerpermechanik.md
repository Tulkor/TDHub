# Brennholt – Körpermechanik, 16. November 2026

Abnahmebeispiel für Lukas. Bis zu seiner Rückmeldung nur Brennholt geändert; die gewünschte Übertragung auf die übrigen Modelle ist noch offen.

## Vergleich mit Referenzen

- [Animation Mentor: Sword Fights and Battle Sequences, Natasha Krinsky](https://www.animationmentor.com/blog/tutorial-animate-sword-fights-battle-sequences/): analysiert unter anderem Greystone-Schwertkampf und unterscheidet Vorbereitung, Beschleunigung, Kontakt und Widerstand. Für Brennholt: sichtbares Ausholen, kurze Beschleunigungsphase und anschließendes Abfangen; die Spielmechanik und Trefferzeit bleiben erhalten.
- [Animation Mentor: Follow-through and Overlapping Action, Drew Adams](https://www.animationmentor.com/blog/follow-through-and-overlapping-action-the-12-basic-principles-of-animation/): Hüfte, Wirbelsäule und nachfolgende Massen sollen versetzt reagieren. Vorher wurden Brust/Hüfte gleichzeitig zwischen zwei gehaltenen Posen bewegt. Jetzt leitet die Hüfte ein, während Brust und Schwert noch ausholen; Schulter und Brust schwingen nach dem Treffer weiter und kommen versetzt zurück.

Die verlinkten Erläuterungen und dokumentierten Beispiele dienen als Bewegungsreferenzen. Keine externen Animationsdaten oder Modelle übernommen.

## Umsetzung und Prüfung

Zwei unabhängige Schultergürtel mit Brust → Schlüsselbein → Oberarm → Unterarm → Hand → Waffe. Schulterpanzer bleiben starr, sind aber nicht mehr direkt an der Brust befestigt. Drei Angriffsvarianten mit zusätzlichen vorbereitenden und auslaufenden Posen, Brustseitneigung und Kopfgegenhaltung. Mehr Bewegung innerhalb derselben Kombo-Dauer.

Blender-Neubau nur für Brennholt. Waffenprüfung: 9.713 Prüfungen ohne Fehler; Fluid-/Waffenabstandprüfung: 3.079 Prüfungen ohne Fehler. Godot-GPU-Probe: alle drei importierten Komboclips und sechs Laufzeitwechsel geprüft; 60 Frames bei 20 fps. Kontaktbogen visuell kontrolliert. Das ist eine technische und visuelle Prüfung, keine vollständige biomechanische Simulation.

Vorschau: `export/videos/bollwerk-brennholt-schultervergleich-2026-11-16.webp`, links vorher, rechts überarbeitet.

Vor GPU-Aufnahmen den Godot-Import mit `--headless --editor --import --audio-driver Dummy` vollständig abschließen lassen. `--editor --quit` kann den Scan vorzeitig abbrechen und alte importierte Modelle zeigen. Für diesen Vergleich unterscheiden sich alle 60 neuen Frames von der vorherigen Aufnahme.

## Rückmeldung: mehr Unterarm, Arm zum Ausholen anheben

Die nächste Variante hält den Oberarm während der eigentlichen Schlagphase relativ zur Brust angehoben. Der Handweg liegt auf einem Bogen mit Unterarmlänge um den Ellbogen; vorherige freie Handziele ließen den Oberarm zu stark absinken. Unterarm klappt aus der gebeugten Ausholstellung nach vorne, Brust- und Schulterdrehung unterstützen mit kleinerem Ausschlag. Zwischen Ausholen und Kontakt beträgt die Richtungsänderung des Unterarms rund 105°, die des Oberarms relativ zur Brust rund 0°; Anheben und Absenken erfolgen vor bzw. nach dieser Phase. Das prüft `weapon_qa.py` nun für alle drei Komboclips anhand tatsächlicher Gelenkpositionen. 9.722 Waffenprüfungen und 3.099 Fluid-/Abstandsprüfungen ohne Fehler, neue GPU-Aufnahme mit 60 Frames. Übertragung auf andere Modelle weiterhin erst nach Rückmeldung.

Vergleich zur unmittelbar vorherigen Schultervariante: `export/videos/bollwerk-brennholt-unterarm-2026-11-16.webp` (links vorher, rechts neu).

## Rückmeldung: Handgelenk hinter den Kopf, tiefer durchschwingen

Ausholen mit höherem Oberarm und zurückgeklapptem Unterarm: Das Handgelenk liegt hinter der Kopfebene, die Klinge zeigt schräg nach hinten/oben. Der Unterarm treibt den Hieb weiterhin an. Nach dem Kontakt folgt eine separate tiefere Pose mit abwärts gerichteter Klinge; erst danach geht die Waffe in die Bereitschaft zurück. Der Oberarm öffnet sich im Nachschwung etwas zur Waffenseite, damit der tiefe Durchzug außerhalb des Brustpanzers bleibt. Die technische Prüfung kontrolliert jetzt zusätzlich Handgelenk hinter Kopf sowie Klingenspitze im Nachschwung mindestens 15 cm unter der Trefferpose und unter 90 cm Höhe. 9.728 Waffenprüfungen und 3.099 Fluid-/Abstandsprüfungen ohne Fehler, drei Clips in Godot geprüft und erneut aufgenommen.

Aktueller Vergleich: `export/videos/bollwerk-brennholt-tiefer-hieb-2026-11-16.webp` (links vorher, rechts neu). Weiterhin nur Brennholt, Übertragung nach Rückmeldung.

## Anatomie-Korrektur nach weiterer Rückmeldung

Die freie Handorientierung und die nachträgliche Schneidenausrichtung hatten die Faust unabhängig vom Unterarm verdreht. Ersetzt durch eine FK-Kette: Schulterbewegung, Ellbogen mit fester Beugeebene, getrennte Unterarmdrehung und konstante neutrale Griffrelation. Die frühere Forderung nach einem völlig unveränderten Oberarm während des Kontakts war für diesen Bewegungsablauf zu starr; die Schulter unterstützt jetzt die überwiegend vom Unterarm geführte Bewegung. Handgelenk hinter der Kopfebene und tiefer Nachschwung bleiben erhalten.

Zusätzlicher Fehler: gegensinnige Quaternion-Vorzeichen ließen den Arm zwischen gültigen Posen einen falschen Drehweg nehmen. Für Brennholt hält `Anim.continuous` die tatsächlich eingefügten lokalen Rotationsquaternionen stetig. Andere Modellgeneratoren erhalten diese Verhaltensänderung erst bei weiterer Übertragung.

Anatomiereferenzen: [Ellbogenmechanik](https://www.ncbi.nlm.nih.gov/sites/books/NBK532948/), [gemessene normale Ellbogenbeweglichkeit](https://pubmed.ncbi.nlm.nih.gov/31210794/), [Anatomy, Biomechanics, and Loads of the Wrist Joint](https://pmc.ncbi.nlm.nih.gov/articles/PMC8880601/). Studienwerte dienen zur Wahl konservativer Animationsgrenzen, nicht als vollständiger biomechanischer Nachweis.

Unabhängig im finalen GLB mit 96 Hz geprüft, einschließlich Übergängen: Ellbogenbeugung etwa 20–120°, Unterarmdrehung höchstens 18°, Faust-/Unterarmrelation praktisch unverändert (unter 0,1° numerische Abweichung). Seitliche Abweichung aus der Ellbogen-Beugeebene unter 2,5°. Zusätzlich Waffenbindung, Schneidenrichtung und Brustvolumen-Abstand geprüft. Blender-Neubau nur für Brennholt, alle drei importierten Angriffscycles in Godot geprüft und mit 60 Frames neu aufgenommen; Kontaktbogen visuell kontrolliert.

Aktuelle Vorschau: `export/videos/bollwerk-brennholt-anatomie-2026-11-16.webp` (links vorher, rechts korrigiert). Übertragung auf weitere Modelle weiterhin nach Lukas' Rückmeldung.

## Rückmeldung: Hieb statt Stich

Trefferpose tiefer angesetzt (Schulterwinkel 10°, Ellbogenbeugung 20°) und eigene Zwischenpose mit noch aufrechter Klinge ergänzt. Die Klinge schneidet von oben nach unten durch, statt am Kontakt überwiegend nach vorne zu zeigen. Zusätzlich zu Schneidenebene und Treffzone prüft die Waffenprüfung jetzt eine deutlich abwärts gerichtete Klinge am Kontakt und eine überwiegend quer zur Klinge laufende momentane Bewegung.

Ellbogenscharnier und Unterarmdrehung sind nun auch im Skelett getrennt: `fore.R` beugt, `twist.R` rollt Unterarmrüstung/Faust/Waffe gemeinsam. Dadurch bleibt die Ellbogenbewegung selbst in schnellen interpolierten Übergängen in ihrer Beugeebene. Handgelenk bleibt neutral. Prüfung: 14.585 Waffen-/Anatomieprüfungen und 3.135 Fluid-/Abstandsprüfungen ohne Fehler, Ellbogen-Seitenbiegung praktisch 0°, maximale Unterarmdrehung etwa 28°.

Aktuelle Vorschau `export/videos/bollwerk-brennholt-schwerthieb-2026-11-16.webp`: dieselbe neue Bewegung zweimal, links schräg von vorne, rechts als Profil. Die Profilkamera `attack_probe.tscn -- --held=brennholt --combo --profil` zeigt den Schlagbogen ohne Verkürzung durch die Frontalperspektive. Weiterhin nur Brennholt geändert.

## Rückmeldung: Spitze nach oben, Unterarm zum Ende strecken

Ausholen mit aufwärts gerichteter Schwertspitze und 115° Ellbogenbeugung; anschließend 75° beim Beginn des Hiebs, 20° am Kontakt und 6° im tiefen Nachschwung. Der Arm endet nahezu gestreckt, ohne den Ellbogen zu überstrecken. Die Schneidenrolle greift erst in der Beschleunigungs-/Trefferphase, damit die aufrechte Ausholstellung nicht seitlich verkippt wird. Die Prüfungen verlangen nun ausdrücklich eine aufwärts gerichtete Schwertspitze beim Ausholen und eine Restbeugung von 3–12° im Nachschwung. Die Schneidenebene wird für Brennholt am Treffer geprüft; die gehaltene Ausholstellung ist noch keine Schnittphase. Alle 14.591 Waffen-/Anatomieprüfungen und 3.132 Fluid-/Abstandsprüfungen grün.

Aktuelle Vorschau: `export/videos/bollwerk-brennholt-streckung-2026-11-16.webp` (dieselbe neue Bewegung links schräg von vorne, rechts im Profil). Andere Modelle weiterhin unverändert.

## Rückmeldung: Spitze nie senkrecht nach unten

Die Spitze bleibt im tiefen Nachschwung schräg nach vorne/unten. Der Ellbogen endet weiterhin mit etwa 6° Restbeugung. Dafür erlaubt das Handgelenk jetzt eine kontrollierte Beugung: 0° beim Ausholen, 5° zu Schnittbeginn, 10° am Kontakt und höchstens 40° im Nachschwung; keine seitliche oder axiale Verdrehung am Handgelenk. Weniger Vorneigung des Oberkörpers im Nachschwung verhindert zusätzlich das senkrechte Abkippen der gesamten Klinge. Auch Fähigkeitspose `cast` erhält eine begrenzte Brustvorneigung.

Die GLB-Prüfung tastet alle Angriffs-/Fähigkeitsübergänge mit 96 Hz ab und verlangt mindestens etwa 20° Abstand zur senkrechten Abwärtsrichtung. Zusätzlich begrenzt sie die Handgelenkbeugung und prüft, dass diese ausschließlich um die vorgesehene Beugeachse erfolgt. 16.207 Waffen-/Anatomieprüfungen und 3.132 Fluid-/Abstandsprüfungen ohne Fehler.

Aktuelle Vorschau: `export/videos/bollwerk-brennholt-klinge-diagonal-2026-11-16.webp`, links schräg von vorne, rechts im Profil. Weiterhin nur Brennholt.

## Nutzer-Skizze: Klinge von aufrecht bis waagerecht

Die gelieferte Seitenansicht präzisiert und ersetzt die vorherige Interpretation eines tief nach unten gerichteten Schwerts: Die Klinge bleibt oberhalb bzw. vor der Faust und kippt während des Hiebs von aufrecht über schräg oben bis ungefähr waagerecht nach vorne. Der alte neutrale Griffwinkel von 90° zum Unterarm erzeugte den falschen Abwärtshang. Der kalibrierte Schwertgriff verwendet nun 20°; der Unterarm leitet weiterhin den Bogen ein. Schulter-/Ellbogenwinkel je Phase: Ausholen 15°/95°, Schnittbeginn −5°/85°, Kontakt −20°/45°, Nachschwung −25°/6°. Die abschließende begrenzte Handgelenkbeugung hält die Klinge annähernd waagerecht, während sich der Arm nach vorne/unten streckt.

Prüfungen auf eine abwärts gerichtete Klinge am Kontakt und eine Klingenspitze unter 90 cm wurden durch die nun ausdrücklich gewünschte Seitenansicht ersetzt: aufrechte Spitze am Anfang, annähernd waagerechte Klinge an Kontakt und Ende, abwärts laufender Bogen und überwiegend quer zur Klinge laufende momentane Bewegung statt Spitzenstoß. Gelenk-, Griff- und Kollisionsprüfungen bleiben aktiv. 16.210 Waffen-/Anatomieprüfungen und 3.132 Fluid-/Abstandsprüfungen grün.

Aktueller Stand: `export/videos/bollwerk-brennholt-skizzenhieb-2026-11-16.webp`, dieselbe neue Bewegung links schräg von vorne, rechts als Profil. Andere Modelle warten weiterhin auf Rückmeldung.

## Bewegung akzeptiert, Schwert braucht etwas Handgelenkspiel

Lukas hat die Schlagbewegung bestätigt. Schulter-, Ellbogen-, Hüft- und Brustposen bleiben unverändert. Nur die Hand artikuliert zusätzlich: 4° leichtes Zurücknehmen beim Ausholen, −6° beim Schnittbeginn, −2° am Kontakt und 37° statt zuvor 35° im Nachschwung. Dazu kommt eine kleine seitliche Neigung von −3°/−6°/0°/+5° in denselben Phasen. Das ergibt eine dezente Einwärtsdrehung und weiches Ausfedern, ohne die angenommene Grundbewegung zu ändern oder die Hand frei zu verdrehen. Die Schneide bleibt am Kontakt passend ausgerichtet.

Die unabhängige GLB-Prüfung erlaubt nun bis 7° begrenzte seitliche Handgelenkbewegung statt ausschließlich einachsiger Beugung; tatsächlicher Spitzenwert etwa 5,8°. Ellbogen-Seitenbiegung bleibt praktisch 0°, Forearm-Roll etwa 13°, Ellbogen endet weiterhin leicht gebeugt. 16.210 Waffen-/Anatomieprüfungen und 3.132 Fluid-/Abstandsprüfungen ohne Fehler.

Aktuelle Vorschau: `export/videos/bollwerk-brennholt-handgelenk-2026-11-16.webp` (links schräg von vorne, rechts im Profil).
