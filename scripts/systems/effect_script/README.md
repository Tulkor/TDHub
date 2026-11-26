# Gemeinsame Effektsprache

Items und Tower speichern `effect_script` als Text. `EffectScript.compile(text)` liefert
`{ok, error, ast, passive}`. AST wird immer aus dem Text erzeugt; gespeicherte ASTs sind
keine ausführbare Quelle. Der Browser nutzt `tools/html_editor/effect_script.js` und
denselben `catalog.json`. Namen unterscheiden Groß-/Kleinschreibung. Kommentare:
`#`, `//`, `--`. Mehrere Ausdrücke durch Zeilenumbrüche oder Semikolon trennen.
Keine Variablen, Schleifen, Dateizugriffe oder eingebettetes Lua/GDScript.

```text
OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))
OnAttack(10%, Chain(3, 5m, Damage(15, "lightning")))
Every(2s, Self(Heal(10), Mana(5)))
OnHurt(Self(Shield(50, 3s)))
OnKill(Gold(5))
OnHit(Burn(10, 4s), ArmorReduce(3, 5s))
Native('{"type":"crit","chance":0.2,"multiplier":2}')
```

`%` teilt Zahlen durch 100. `s` kennzeichnet Simulationssekunden, `m` eine
logische Spieleinheit (Towerbreite im TD, Weltmeter im 3D-Kampf).
`Slow(20%,3s)` senkt das Tempo um 20 %. `DoT/Poison/Burn` nehmen Schaden pro
Sekunde und Dauer. `DamagePercent` bezieht sich auf maximales Leben.
`Buff("damage",20%,5s)` nutzt den Bonusnamen und die Bonussemantik des Ziels.

Top-Level-Ausdrücke ohne Trigger laufen bei `hit`. Trigger sind nur auf oberster
Ebene erlaubt. `OnHit/OnAttack/OnKill/OnHurt/OnCast/OnDeath/OnSpawn/OnDay/OnNight` nehmen optional
eine Chance als erstes Argument. `Every` nimmt ein Intervall; es läuft auf `tick`.
`WhenDay(...)` und `WhenNight(...)` fragen `game.is_night()` ab; die Übergangsereignisse heißen `day` und `night`. `Self` wählt die Quelle. `AoE`/`Allies` wählen Gegner/Verbündete um das aktuelle
Ziel, ohne Ziel um die Quelle. `Cone(Länge,Grad,...)`, `Line(Länge,Breite,...)`
und `Ring(Innenradius,Außenradius,...)` liegen um die Quelle, ausgerichtet zum
Ziel. `Chain(Anzahl,Reichweite,...)` zählt das erste Ziel mit und trifft kein
Ziel doppelt. `IceBall`/`FireBall` fliegen mit 18 Einheiten/s; `Projectile(Tempo,...)`
setzt das Tempo selbst. Sie treffen das gewählte Ziel nach ihrer Flugzeit,
ohne Hindernis- oder Durchschlagsprüfung. Ein vor dem Einschlag gestorbenes Ziel
wird übersprungen. `Delay` verzögert seine Kinder um Simulationssekunden.

`Native(JSON)` aktiviert eine bestehende Towerfähigkeit einschließlich nativer
Passivmechanik wie Multishot, Pierce, Fork, Auren oder Crit. Namen und Standardwerte
stehen unter `native` im Katalog und entsprechen `Abilities.SCHEMA`.
Native Fähigkeiten benötigen die Tower-Laufzeit; sie werden nicht zusätzlich als
Trefferausdruck ausgeführt. Eine Modusintegration muss diese Passiven ausdrücklich
übernehmen oder als nicht unterstützt anzeigen.

Die gemeinsamen Fähigkeiten enthalten auch die bereits verwendeten `nova`
(optionale Verlangsamung für die nativen 3 s) und `wave_damage`. Optionale native
Parameter wie `stun.damage`, `cone.damage`, `gold_on_hit.gold_per_wave` und die
Zielauswahl von Gegner-Auren werden ausdrücklich validiert. `text` ist ein
Beschreibungsfeld, kein zusätzlicher Effekt. Die vorhandenen Tower- und
eeve-Itemdaten werden als vollständige Parameterobjekte im Vertragscheck geprüft.

Die eeveTD-Laufzeit bietet zusätzlich **acht ausdrücklich benannte Fähigkeiten**:
`eeve.area_debuff`, `eeve.amplify`, `eeve.death_explosion`, `eeve.pulse`,
`eeve.rage`, `eeve.hp_cut`, `eeve.orb` und `eeve.chain`. Beispiel:

```text
Native('{"type":"eeve.area_debuff","armor":3,"slow":0.1,"dps":60,"duration":15,"radius":1.95}')
Native('{"type":"eeve.pulse","every":10,"center":"target","radius":0,"slow":0.5,"duration":3,"max":1}')
Native('{"type":"eeve.chain","damage":1250,"chance":0.2,"targets":4,"growth":1.25,"radius":3.91}')
```

Diese Namen werden nur bei einer Quelle mit `effect_script_native_scopes()`
einschließlich `eeve` auf die vorhandene `EeveTower`-API abgebildet; andere Tower
und Helden erhalten einen konkreten Kontextfehler. Es gibt keine automatische
Ersatzwirkung. `eeve.chain` ist der wachsende Schadens-Kettenblitz, `chain` der
gemeinsame Geschoss-Modifikator mit `count` und `factor`. Pulse akzeptiert nur
`center: tower|target` und `targets: both|air|ground`; optionale Schadens-/CC-Werte
beginnen bei null, damit ein importierter Verlangsamungs-Puls keine zusätzliche
Betäubung erhält. Orb-Farben sind HTML-Farben. Laufzeitwirkungen kommen unverändert
aus den vorhandenen Modus-APIs.

`compile().passive` und `passives(text)` behalten die qualifizierten Namen.
Eine native Integration nutzt `native_abilities(source,text) -> {abilities,errors}`
für Kontextprüfung und Abbildung auf die tatsächlichen Typnamen. `Tower` erlaubt
den Kontext `tower`, `EeveTower` zusätzlich `eeve`.

Der Katalog ist zugleich die vollständige Liste der Sprachbausteine. Unterstützung
eines Effekts hängt von Ziel und Spieladapter ab: z. B. `Heal` braucht `heal`,
`Shield` braucht `add_shield`. Kontrolle nutzt vorhandene Gegner-APIs bzw. `HdCc`
einschließlich Bossresistenzen. `Root`, `Knockback(Distanz,Dauer)`, `Summon(id,Anzahl,Dauer)` und spezielle
Fähigkeiten sind bewusst Adapteraufrufe, keine Scheinimplementierungen.

`Invoke("Fähigkeitsname",'{"parameter":1}')` ruft registrierte Spielmechanik auf.
Eine Integration registriert `register_handler(name, Callable)` mit
`handler(source,target,args:Array) -> true | "Fehlermeldung"` oder stellt
`game.effect_script_action(name,args,source,target)` bereit. Bei `Invoke` enthält
`args` genau das JSON-Objekt. So bleibt jede vorhandene oder künftige Mechanik
erreichbar, ohne Codeausführung aus dem Editor zuzulassen. Nicht vorhandene
Adapter und ungeeignete Ziele liefern explizite Laufzeitfehler.

Native Helden-IDs gehören weiterhin zur Klasse und zum gewählten Baukasten ihrer
Quelle. Eine fremde Heldenklasse wird nicht versteckt erzeugt; deren Formzustände,
Ressourcen und permanente Kit-Zustände werden nicht auf die Quelle übertragen.
Alle vier Klassen und ihre eigenen vorhandenen Fähigkeiten werden im jeweiligen
Laufzeitkontext geprüft. `Invoke` ist keine Klassenumwandlung.

Spielintegration: `trigger(source,target,event,dt=0,scripts=[]) -> Array[String]`.
Quelle liefert `effect_scripts() -> Array[String]`, andernfalls werden `def` und
`stats` gelesen. `tick` muss auch ohne aktuellen Gegner und nach Ablegen eines
Items weiterlaufen, damit gestartete Effekte enden. Nur der autoritative Host
führt Trigger aus. Quelle muss `game` bereitstellen; Modi implementieren ihre
eigenen Ereignishooks. Rückgabefehler anzeigen; Tower speichern sie zusätzlich in
`effect_script_errors` und warnen je Meldung einmal. Proccs durch Skriptschaden
können keine weiteren Skriptproccs auslösen (Rekursionsschutz je Quelle).

Optional liefert die Quelle `effect_script_source_key(text) -> String`: Buffs und
CC erhalten dann zusätzlich diesen Schlüssel, auch nach `Delay`/Geschossen.
Bollwerk trennt damit aktive Items, passive Programme und die stabile
Heldenmeisterschaft. Unterschiedliche Effekte überschreiben sich nicht;
identische Programme bzw. Meisterschaft bei geänderter Wertung erneuern dieselbe
Quelle. Ohne diesen Haken bleibt die bisherige Quellenzuordnung erhalten.

Grenzen: 16384 Zeichen, 256 AST-Werte, Tiefe 24, 1024 ausgeführte Knoten je
Ereignis, 256 laufende Verzögerungen/DoTs je Quelle, maximal 32 periodische
Nachholungen je Tick. Chance nutzt `game.rng`, falls vorhanden. Test:
`tests/systems/effect_script_test.tscn`.

