# Map-, Tower- und Item-Editor (HTML)

Map- und Tower-Editor außerhalb des Spiels: eine einzige HTML-Datei, läuft ohne Installation im Browser
(Doppelklick, Edge, Chrome oder Firefox). Ergebnis ist eine eigene JSON-Datei im Format von `data/maps`
bzw. `data/towers`, die man weiterschicken kann.

## Bedienung
- **Map**: Werkzeuge Blockiert / Nur Weg / Boden / Spawn / Ziel / Checkpoint (Tasten 1–6), Pinsel 1×1, 2×2
  (eine Towerbreite) oder 4×4. Linksklick malt, Rechtsklick radiert (auf einem Checkpoint: entfernt ihn),
  mittlere Maustaste oder Leertaste + Ziehen verschiebt, Mausrad zoomt, Strg+Z / Strg+Y.
  Der Weg (Spawn → Checkpoints → Ziel) wird wie im Spiel berechnet (diagonal nur ohne Ecken schneiden).
  Checkpoints lassen sich links umsortieren. Maul-Maps mit mehreren Bahnen: Bahn wählen, Spawn und
  Checkpoints gelten dann für diese Bahn; Baugebiete werden nur angezeigt und bleiben unverändert.
- **Tower**: mitgelieferte Tower als Vorlage wählen oder **+ Gem** / **+ Spezial**; Stufen mit Schaden,
  Reichweite, Abklingzeit und Fähigkeiten (aus `scripts/game/abilities.gd`), Rezept und Upgrades wie im
  Tower-Editor des Spiels. **Erweitert (JSON)** zeigt und ändert alle Felder.
- **Items**: Vorlagen aus `data/heroes_items.json`, neue Items, Duplikate, Name/ID/Stufe, Kosten,
  Werte, Laden und Rezeptzutaten. Mehrfach gleiche Zutaten sind erlaubt. **Erweitert (JSON)** erhält
  auch Verbrauchswirkungen und unbekannte Felder. Alle Änderungen bleiben beim Wechsel des Items im Katalog.
- **Effektskript** bei Towern und Items: z. B. `OnHit(30%, IceBall(AoE(10m, Damage(50), Slow(20%, 3s))))`.
  Sofortige Syntaxprüfung, Hilfe und einsetzbare Beispiele; ungültige Skripte verhindern den Export.
  Gespeichert wird `effect_script` als Text. Parser und Spiel verwenden denselben
  `scripts/systems/effect_script/catalog.json`; Grammatik und Funktionen siehe dessen `README.md`.
  Bei Items bietet **Bollwerk-Fähigkeit einsetzen** gruppierte echte IDs der Helden, Gadgets und
  Gegnerfähigkeiten aus den Spieldaten. Ein auswählbarer, kopierbarer `Invoke("id", '{}')`-Aufruf
  lässt sich anhängen. Eigene Heldenfähigkeiten/Gadgets müssen im Kit bekannt bzw. ausgerüstet sein;
  Gegnerfähigkeiten laufen freundlich durch ihre bestehende Zustandsmaschine. Dies braucht den
  Bollwerk-Adapter. Tower zeigen diese Referenzen nicht; dort bleiben die bisherigen Fähigkeiten
  und `Native(...)` über deren Schema verfügbar.
- Tower- und Item-Entwürfe werden im lokalen Browserspeicher gesichert und beim erneuten Öffnen derselben
  HTML-Datei wiederhergestellt. JSON-Downloads bleiben die dauerhafte, weitergebbare Sicherung.
- **Datei öffnen** (oder Datei ins Fenster ziehen) lädt eine Map oder einen Tower, **Als Datei speichern**
  (Strg+S) lädt `<id>.json` herunter.
  Im Items-Tab lädt Speichern stattdessen **heroes_items.json** als vollständigen Katalog herunter.
  Datei öffnen erkennt komplette Itemkataloge; ein einzelnes Item im Items-Tab wird anhand der ID in
  den aktuellen Katalog übernommen (bestehende ID ersetzt, neue ID angefügt). Ungültige Importe werden abgelehnt.

## Im Spiel verwenden
Map-Editor bzw. Tower-Editor im Spiel → **Datei importieren** → Datei wählen → **Speichern**.
Die Datei landet dann im Benutzerordner (`%APPDATA%\godot\app_userdata\GemTD Nachbau\data\maps|towers\`);
man kann sie auch direkt dorthin kopieren. Ins Repo: Datei nach `data/maps/` bzw. `data/towers/` legen.
Items: den exportierten vollständigen Katalog nach `data/heroes_items.json` übernehmen. Shops,
Stufendefinitionen und Holzregeln bleiben enthalten. Eine einzelne Itemdatei ersetzt diesen Katalog nicht.
Vor dem Export werden IDs, doppelte IDs, Wertebereiche, unbekannte Zutaten, Rezeptkreise und Skripte geprüft.

## Format
Geschrieben wird wie `Database.save_json` (Tabs, Kommazahlen bleiben Kommazahlen, unbekannte Felder bleiben
erhalten). Jede mitgelieferte Map und jeder Tower kommt unverändert Byte für Byte gleich heraus
(geprüft in `pruefen.mjs`). Die JSON-Funktionen stammen aus dem Balance-Editor (`tools/balance_editor/`).

## Dateien
- `editor.html`: HTML-Vorlage; vor Benutzung mit `bauen.py` bauen.
- `item_editor.js`: Itemkatalog, Skriptfelder und lokale Entwürfe.
- `effect_script.js`: gemeinsamer kataloggesteuerter Browserparser für die Effektsprache.
- `bauen.py`: bettet Maps, Tower, Wellen-Sets, Modi, Effekte, Fähigkeiten und Schrift ein, Ergebnis
  `/mnt/project-files/editoren/td_editor.html` (eine Datei zum Weitergeben, etwa 1 MB).
- `pruefen.mjs`: Test im Browser (Format, Malen, Weg, Rückgängig, Speichern und Öffnen, Tower mit Rezept).
  `tools/run_tests.sh htmleditor`.

## Lokal unter Windows
Aus dem Projektordner bauen und per Doppelklick oder PowerShell öffnen:

```powershell
& 'C:/Users/l_neu/Documents/.tools/python/python.exe' tools/html_editor/bauen.py --ziel=export/editoren/td_editor.html
Invoke-Item export/editoren/td_editor.html
```

Der Browsertest unterstützt vorhandene Laufzeiten ohne Installationsschritte:

```powershell
$env:TDHUB_PYTHON='C:/Users/l_neu/Documents/.tools/python/python.exe'
$env:TDHUB_NODE_MODULES='C:/Users/l_neu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'
$env:TDHUB_CHROMIUM='C:/Program Files/Google/Chrome/Application/chrome.exe'
node tools/html_editor/pruefen.mjs --bilder=export/editoren/qa
```

Prüft auch Itemduplikate, Rezeptfehler, Kosten, Skriptfehler, Entwürfe nach Neuladen, vollständige
Kataloge, Einzelitem-Merge und den Erhalt vorhandener Items sowie unbekannter Felder/Werte.
