# GemTD: Regeln, Bedienung und Technik

Ausführliche Beschreibung des Modus GemTD (Überblick über TD Hub in der [README](../README.md)).
Alle Tower, Fallen, Rezepte und Werte stammen aus **[BK's] Gem Tower Defense v3.1** (Bryvx),
Gegner und Level aus **Gem TD+ 1.6.14**; Recherche mit Quellen in [wc3_referenz.md](wc3_referenz.md),
alle Tower-Werte in [tower-werte.md](tower-werte.md).

## Bedienung

**Steuerung:** Linksklick setzt Gems bzw. wählt Tower/Steine, links ziehen spannt einen Auswahlrahmen für bis zu 5 Steine auf (Strg+Klick wählt einzelne dazu oder ab),
Strg+Z nimmt den zuletzt gesetzten Gem zurück, Rechtsklick/Esc hebt die Auswahl auf.
Kamera: WASD/Pfeile, Maus an den Fensterrand oder mit gedrückter rechter Maustaste ziehen verschiebt, Q/E oder mittlere Maustaste drehen, Mausrad zoomt. Tasten 1/2/3: Tempo.
Leertaste: große Aktion unten rechts (Behalten, bzw. lila One-Shot). R: Rezeptbuch.

**Oberfläche:** Leiste oben (Welle, Leben, Gold, Chance-Stufe, Tempo), darunter das Phasenbanner. Die Chance-Stufe (bessere Gems) steigt automatisch mit der Welle: Stufe 1 ab Welle 3, dann ab 6, 10, 13, 17, 20, 23 und 27 (`"wave"` in `chance_levels` in `data/balance.json`). Dafür gibt es bis Welle 28 nur 70 % des Golds aus Kills und Fähigkeiten (`gold_income_factor`), danach steigt der Anteil linear bis Welle 35 auf 135 % (`gold_income_ramp`). Der Menü-Knopf fragt vorher nach („Spiel verlassen?“), das Spiel ist solange pausiert.

**Einstellungen** (Hauptmenü): Sprache Deutsch/Englisch, Fenster oder Vollbild, Auflösung. Gespeichert in `user://settings.cfg`. Englische Texte stehen in `data/i18n/en.json` (deutscher Text → englischer Text); neue Texte im Code mit `tr("…")` umschließen und dort eintragen.
Unten die Auswahlkarte: die neuen Gems der Runde (hellblauer Rand = Zutat für einen One-Shot/Spezial-Tower),
Werte des angeklickten Towers, „Wird gebraucht für“ mit allen Rezepten, in denen er vorkommt, und die Aktionen.
Im Rezeptbuch (R) stehen alle Spezial-Rezepte, Zutaten grün (✓ vorhanden) oder rot (✗ fehlt).
Mit „Pin“ angepinnte Rezepte erscheinen links oben und zeigen, was noch fehlt.
Rechts oben zeigt das DPS-Meter die 5 Tower mit dem meisten Schaden pro Sekunde, umschaltbar zwischen aktueller Welle,
der letzten Boss-, Flug-, Boden- und Massenwelle und Gesamt.
„Weg“ in der Leiste oben zeigt die Länge des Laufwegs in Feldern, in der Bauphase mit der Änderung seit Rundenbeginn.
Am Spielende öffnet sich ein Menü: nochmal mit denselben Einstellungen spielen oder zurück ins Hauptmenü.

**Spielablauf wie in Gem TD:**
1. Bauphase: 5 zufällige Gems setzen. Der Weg kann nie ganz blockiert werden.
   Das Raster ist halb so groß wie ein Tower: Tower belegen 2×2 Felder, lassen sich also um eine
   halbe Breite versetzen, und Gegner passen durch Lücken von einem Feld (wie in WC3).
2. Einen der 5 neuen Gems anklicken und rechts wählen: behalten, 2 gleiche → +1 Qualität,
   4 gleiche → +2 Qualitäten (über „Großartig“ hinaus entsteht der Stein von Bryvx),
   oder ein Spezial-Rezept. Die anderen 4 werden zu Steinen. Mit „Abstufen“ behält man einen Gem
   eine Qualität niedriger (z. B. Fehlerhaft → Splitter), etwa weil ein Rezept genau diese Stufe braucht.
   **One-Shot:** Sind schon während der Bauphase alle Zutaten eines Spezial-Rezepts da (gesetzte Gems
   dieser Runde; fertige Tower auf dem Feld zählen dafür nicht), zeigt das Spiel das an. Gem anklicken und „One-Shot“
   wählen baut den Spezial-Tower sofort; die restlichen Gems der Runde entfallen.
3. Die Welle startet. Gegner laufen Spawn (S) → Checkpoints 1…5 → Ziel (Z). Flieger fliegen direkt.

Weitere Regeln:
- **Spezial-Tower:** Zutaten aus den Gems dieser Runde *oder* fertige Tower auf dem Feld. Fertige Tower
  untereinander kombinieren geht nur während der Welle. Beim Setzen und Auswählen der neuen Gems zählen
  für Rezepte nur die Gems dieser Runde.
  Verbrauchte Tower vom Feld werden zu Steinen. Upgrades (z. B. Silber → Sterlingsilber → Silberritter) kosten Gold und gehen nur während der Welle.
- **Fallen (Platten):** Normaler Gem + einer der passenden fehlerhaften Gems in derselben Runde.
  Gegner laufen über Fallen. Zwei Fallen auf dem Feld ergeben eine kombinierte Falle
  (z. B. Halteplatte + Luftplatte → Urplatte): während der Welle eine Falle anklicken, dann „Kombinieren“.
  Fallen sind 3×3 Felder groß und treffen alles auf dieser Fläche (Weitplatte und Luftangriffe
  wirken weiter im Kreis). Tower dürfen auf Fallen gebaut werden; eine Falle unter einem Tower wählt
  man mit einem zweiten Klick aus. Jede Falle lässt sich zweimal verschieben („Verschieben“, dann
  Ziel anklicken), auch auf Checkpoints, Spawn und Ziel.
- **Steine** jederzeit anklicken und kostenlos entfernen (Bau-, Auswahlphase und während der Welle).
  In der Bauphase kann ein ausgewählter Stein auch gleich durch einen neuen Gem ersetzt werden; mit dem
  Auswahlrahmen gehen bis zu 5 Steine auf einmal (so viele, wie in der Runde noch Gems übrig sind).
- **Zurücknehmen:** Gesetzte Gems der laufenden Runde lassen sich in der Bau- und Auswahlphase zurücknehmen
  (Button oder Strg+Z), aus der Auswahlphase geht es dann zurück in die Bauphase. Das korrigiert nur
  Fehlklicks: der nächste gesetzte Gem ist genau der zurückgenommene (kein Neuwürfeln, auch nicht über
  Speichern/Laden), ein ersetzter Stein kommt zurück und seine Kosten werden erstattet.
- **Gem-Qualität** gegen Gold steigern (8 Stufen, 20–230 Gold), danach kommen bessere Gems.
- **Kill-Ränge:** +10 % Schaden pro 10 Kills (max. +120 %), umgesetzt über das Level-System (`data/leveling.json`, Profil gemtd: 1 EP je Kill, 10 EP je Level, bis Level 12).
- **Schadensarten gegen Rüstungsarten** wie in WC3 (Tabelle in `data/balance.json`).

**Schwierigkeit** im Einstellungsfenster vor Runde 1: Einfach (Leben und Rüstung der Gegner ×0,8), Normal (×0,9), Schwer (×1,15).

Unter „Debug: nächster Gem“ lässt sich jeder Tower in jeder Stufe direkt setzen.
Der Schalter „Unsterblich“ daneben lässt die Leben ins Minus gehen, ohne dass das Spiel endet.

## Mehrspieler (GemTD)

Hauptmenü → „Mehrspieler“: einer klickt „Neue Sitzung hosten“, die anderen geben seine IP ein und klicken „Beitreten“
(UDP-Port 24565; im LAN direkt, übers Internet mit Portfreigabe beim Host oder über Tailscale/ZeroTier).
Die Lobby zeigt dem Host seine öffentliche IP (über api.ipify.org) zum Kopieren und gibt den Port per UPnP im Router frei;
klappt das nicht oder hat der Anschluss keine eigene öffentliche Adresse (CGNAT), steht dort, was zu tun ist.
Modus „jeder sein Feld“ wie im alten GemTD: jeder spielt sein eigenes Feld mit eigener Schwierigkeit.
In der Lobby startet der Host mit „Starten“ alle gleichzeitig auf der gewählten Map; wer später kommt oder
zwischendurch weg war, steigt mit „Mitspielen“ ein, mit seinem letzten Stand.
Im Spiel zeigt die Liste „Mitspieler“ rechts unten Welle und Leben der anderen; „Zuschauen“ zeigt ihr Feld, Esc führt zurück.
Das eigene Spiel läuft beim Zuschauen weiter.

Modus „Koop: ein gemeinsames Feld“ (in der Lobby vor dem Start wählen): alle bauen zusammen ein Labyrinth.
Jeder setzt und wählt seine eigenen Gems pro Runde, die Welle startet, sobald alle einen Gem behalten haben
(bis dahin steht oben „Warten“). Tower gehören dem, der sie gesetzt hat: nur er wählt, kombiniert, wertet auf
und nimmt zurück, Rezepte nur mit eigenen Towern. Jeder hat eigenes Gold; Kopfgeld bekommt der Spieler, dessen
Tower zuletzt getroffen hat. Leben bzw. Punkte, Wellen und Tempo sind gemeinsam, Schwierigkeit und Wertung vom Host.
Wer das Spiel verlässt, hält die Runde nicht auf (von seinen gesetzten Gems bleibt der erste) und steigt über
„Mitspielen“ wieder ein. Verlässt der Host, ist die Partie für alle vorbei; vorher kann er sie speichern.

Maul-Maps („Maul (2 Spieler)“, „Maul (4 Spieler)“): jeder Spieler hat eine Zone und baut nur dort; jede Bahn hat ihren eigenen
Spawn und läuft durch mehrere Zonen ins gemeinsame Ziel. Jede Welle erscheint an jeder Bahn eines mitspielenden
Spielers (ist eine Welle gleich viele Punkte wert). Solo auf einer Maul-Map läuft nur die eigene Bahn.
Im Map-JSON: `spawn_player` (Bahn 0), `lanes` [{spawn, checkpoints, player}] und `zones` [{rect [x, y, w, h], player}].
Der Map-Editor bearbeitet bisher nur Bahn 0; Zonen und weitere Bahnen bleiben beim Speichern erhalten.

Technik: `scripts/autoload/net.gd` (Verbindung, Spielerliste, Sitzung), `scripts/net/net_sync.gd` schickt Zuschauern Map,
Feld (bei Änderung) und Gegner/Schüsse etwa 15 Mal pro Sekunde. `scripts/net/remote_field.gd` zeigt das Feld;
die Gegner laufen dort mit dem gemeldeten Tempo selbst weiter und werden nur sanft nachkorrigiert.
Jede Gegnermeldung nennt das Wegstück, auf dem der Gegner im Schnelllauf ist (`game.gd` → `free_stretch`), und ihre
Sendezeit; so bremst er beim Mitspieler am selben Rand und verspätete Meldungen ziehen ihn nicht zurück.
Koop: nur der Host rechnet. Jede Spieleraktion ist ein Befehl (`game.gd` → `submit`/`execute`, Tower über ihren Platz
benannt); Mitspieler schicken ihn an den Host, der ihn mit ihrer Spielernummer prüft und ausführt.
`scripts/systems/coop/coop_sync.gd` schickt den Stand (Tower, Steine, Spieler, Phase) bei jeder Änderung und Gegner etwa
15 Mal pro Sekunde; beim Mitspieler läuft dasselbe Spiel mit `mirror = true`, ohne eigene Simulation.
Was jedem Spieler gehört, steht in `scripts/game/player_state.gd`.

## Wertung

Im Einstellungsfenster vor Runde 1: „Leben“ (wie im Original, bei 0 Leben verloren) oder „Punkte“.
Im Punkte-Modus ist jede Welle `wave_base + wave_step × (Welle − 1)` Punkte wert (`data/balance.json` → `score`;
Welle 1: 100, Welle 40: 490, Welle 50: 590), verteilt nach Lebenspunkten auf ihre Gegner. Ein Kill bringt den Anteil,
ein Durchbruch kostet die Hälfte davon (`leak_factor`). Ein Gegner aus Welle 40 kostet beim Durchbruch also 24,5 Punkte,
eine ganz durchgelassene Welle 1 dagegen 50. Gespielt wird bis zur letzten Welle. Einfach ×0,8, Normal ×1, Schwer ×1,25.

Ist die letzte Welle eine Bosswelle, ist ihr Boss ein **Schadenscheck**: er kostet keine Leben und keine Punkte, wenn er
durchläuft. Am Ende steht, wie viel Schaden er abbekommen hat (absolut und in % seiner Leben). Im Punkte-Modus bringt
jeder Schaden anteilig Punkte, besiegt ist er `final_boss_factor` (3) × den Wert seiner Welle wert (Welle 50: 1770).
Der Endbildschirm schlüsselt im Punkte-Modus auf, woher die Punkte kommen: Kills und Punkte je Wellentyp
(Boden, Gemischt, Masse, Flieger, Boss), der Endboss und was Durchbrüche gekostet haben.

## Speichern

Wer eine Partie mittendrin verlässt (Menü-Knopf oder Fenster schließen), wird gefragt, ob gespeichert werden soll.
Gespeichert wird der komplette Stand, auch mitten in einer Welle (Tower, Steine, Gegner mit Leben und Effekten,
Warteschlange, Zufallsgenerator). „Spiel laden“ im Hauptmenü listet alle Spielstände.

Im Mehrspieler speichert nur der Host. Er holt dabei die Felder aller Mitspieler ein; jeder Mitspieler meldet seinen Stand
außerdem zu Beginn jeder Bauphase und beim Verlassen. Eine gespeicherte Sitzung lädt der Host über „Spiel laden“ → „Hosten“,
die Mitspieler treten bei und spielen dort weiter, wo sie waren. Erkannt werden sie an einer festen Spieler-ID
(`user://settings.cfg`), notfalls am Namen. Ein Koop-Spielstand enthält das gemeinsame Feld mit allen Spielern,
beim Laden bekommt jeder seine alte Spielernummer zurück.

Die Dateien liegen in `user://saves/*.gtd`, binär und mit AES-256 verschlüsselt samt Prüfsumme (`scripts/systems/save/save_game.gd`).
Eine veränderte Datei lässt sich nicht mehr laden. Der Schlüssel steckt im Spiel, gegen gezieltes Auslesen schützt das nicht,
gegen einfaches Ändern schon.

## Tower

| Gems (je 6 Qualitäten) | Spezial-Tower (mit Upgrades) | Fallen |
|---|---|---|
| Amethyst, Aquamarin, Diamant, Smaragd, Opal, Rubin, Saphir, Topas | Silber, Malachit, Sternrubin, Jade, Roter Kristall, Dunkler Smaragd, Gold, Uran 238, Rosa Diamant, Paraiba-Turmalin, Schwarzer Opal, Blutstein, Gelber Saphir, Stein von Bryvx | Luft-, Halte-, Verlangsamungs-, Opalader-, Zauber-, Gift-, Reichweiten-, Kraftplatte; kombiniert: Uralte, Geister-, Ältesten-, Viperplatte |

Vereinfachungen gegenüber WC3 (stehen auch in den Tower-Dateien als Fähigkeiten):
Zauber wie Frostnova, Blitz oder Messerfächer sind als „nova“ (Flächenschaden mit Chance) umgesetzt;
das Teleportieren der Platten (im Original einmal bis 2000 Einheiten weit) ist „Verschieben“: jede Platte darf zweimal
an einen beliebigen begehbaren Platz (`trap_moves` in `data/balance.json`); „Tauschen“ des Schwarzen Opals kostet 200 Gold
(`swap_cost` in der Tower-Datei) und tauscht den Platz mit einem eigenen fertigen Gem oder einem Stein;
„Extra Chance“ (Knopf oben neben der Chance-Stufe, 175 Gold, einmal pro Runde in der Bauphase): eine Gem-Sorte wählen,
jeder Gem, der in dieser Runde noch gesetzt wird, wird mit 5,95 % Chance zu ihrem Perfekten (`extra_chance` in
`data/balance.json`; die Platten-Variante des Originals entfällt, weil Platten hier aus Gems kombiniert werden);
Ein Tower ist 128 WC3-Einheiten breit und belegt 2×2 Felder; ein Feld sind 64 WC3-Einheiten.

## Datenformate

### Map-Format (`data/maps/*.json`)

```json
{
  "format": 2, "id": "classic", "name": "Klassisch", "width": 56, "height": 56,
  "tiles": ["#####…", "#....…", …],
  "spawn": [3, 8], "goal": [52, 45], "checkpoints": [[11, 8], [11, 29], …],
  "marker_radius": 1, "waves": "classic", "lives": 50, "start_gold": 0,
  "variance": {"random_rocks": 25, "seed": -1}
}
```
Alle Angaben in Feldern (halbe Towerbreite). Maps ohne `"format": 2` stammen aus der Zeit, als ein Feld
ein Tower war, und werden beim Laden automatisch verdoppelt.
Kacheln: `.` Boden (bebaubar), `#` blockiert, `_` nur Weg. Um Spawn, Ziel und Checkpoints ist im Umkreis
`marker_radius` nicht bebaubar. `variance.random_rocks` setzt bei jedem Start zufällig Steine.

**Map-Editor:** Kacheln malen (Linksklick, ziehen, Pinselgröße einstellbar), Rechtsklick radiert (rechts ziehen verschiebt die Kamera). Spawn/Ziel/Checkpoints per Werkzeug.
Der Weg wird live angezeigt, *Testen* startet das Spiel mit der Map.

### Tower-Format (`data/towers/*.json`)

```json
{
  "id": "silver", "name": "Silber",
  "category": "special",          // "gem" = wird gewürfelt, "special" = per Rezept
  "kind": "tower",                // "trap" = Falle, Gegner laufen darüber
  "color": "#c8d0d8",
  "model": "res://assets/models/crystals/crystal_09.glb",   // optional, sonst einfache Form
  "damage_type": "spells",        // pierce, magic, normal, siege, hero, spells, chaos
  "targets": "both",              // both | ground | air
  "recipe": [{"tower": "topaz", "tier": 0}, {"any_of": [{"tower": "ruby", "tier": 1}, …]}],
  "recipe_same_round": false,     // true = alle Zutaten aus derselben Runde
  "upgrades": [{"cost": 25, "recipe": []}],     // Stufe 1 → 2, 2 → 3 …
  "tiers": [
    {"name": "Silber", "damage": [20, 21], "range": 4.3, "cooldown": 1.0,
     "abilities": [{"type": "splash", "radius": 1.95, "factor": 0.5}, {"type": "slow", "factor": 0.2, "duration": 5}]}
  ]
}
```
Reichweite/Radien in Towerbreiten (1 = 128 WC3-Einheiten), Abklingzeit in Sekunden. Optional pro Stufe: `range_air`, `model`, `model_scale`.
Fähigkeiten (`scripts/game/abilities.gd`): splash, slow, poison, crit, multishot, bounce, armor_reduce, stun,
air_bonus, gold_on_hit, nova, stacking_damage, wave_damage, speed_aura, damage_aura, burn_aura, slow_aura, armor_aura.
Jede Treffer-Fähigkeit kann `"chance"` haben.

**Tower-Editor:** Tower wählen oder neu anlegen; Art, Modell, Stufen, Fähigkeiten, Rezept und Upgrades bearbeiten.
*Speichern und im Spiel testen* öffnet das Spiel mit diesem Tower als nächstem Gem.

### Gegner

`data/enemies/*.json`: `hp`, `speed` (Towerbreiten/s), `armor`, `armor_type`, `bounty`, `damage` (Leben bei Durchbruch),
`flying`, `boss`, `color`, `size`, optional `shape` und `model`.
Modelle ohne eigenes `model` (animiert, Quaternius CC0): Skelett = Boden, Drache = Flieger, Schleim = Massenwelle
(`"shape": "pyramid"`), Fledermaus = fliegende Massenwelle, Little Man = Boss; die Gegnerfarbe färbt einen Teil des Modells.
Wellenrhythmus (classic): Boden, Masse, Boden, Flieger; Massenwellen ab Welle 10 (10, 14 … 46), Flieger 4, 8 … 48; Bosse 42 und 50.
Eine Bosswelle ist ein einzelner Gegner mit zehnfachen Leben, Gold und Schaden (Gruppe mit `"count": 1`).
Eine Massenwelle hat 25 statt 10 Gegner mit je 40 % Leben, Gold und Leben-Schaden und kürzerem Abstand.
Dafür überschreibt die Gruppe in der Wellendatei `hp`, `bounty`, `damage`, `shape` und `size`.
Schnelllauf: Wo kein Tower einen Gegner angreifen oder mit einer Aura treffen kann, läuft er
`idle_speed_factor` (balance.json, 8) mal so schnell, auf allen Maps und in jeder Zone. Er läuft in kleinen Schritten
und hält genau am Rand einer Reichweite an, damit keine (auch keine Falle) übersprungen wird. Solange Gift wirkt,
läuft er normal schnell.
