# Bodentexturen

Aus Fotos von Unsplash (Unsplash-Lizenz: kostenlose, auch kommerzielle Nutzung und Bearbeitung erlaubt, Nennung freiwillig), mit `tools/boden_texturen.py` zugeschnitten,
Helligkeit ausgeglichen und nahtlos kachelbar gemacht.

| Datei | Foto |
|---|---|
| grass_a.jpg | Samuel Ramos (unsplash.com, Foto CeqtSiMYzFU) |
| grass_b.jpg | Palani Selvam (unsplash.com, Foto IkghfzzIC2s) |
| dirt.jpg | Dimas H (unsplash.com, Foto zMHbjpxEDqQ) |

Selbst erzeugt (kein Foto, frei wie CC0) mit `tools/rg_texturen.py`, für Randgruppen TD:

| Datei | Inhalt |
|---|---|
| concrete.jpg (+ _normal) | heller Beton mit ein paar Steinen (Baufläche) |
| gravel.jpg (+ _normal) | Splitt (Wege der Gegner) |
| cobble.jpg (+ _normal) | Pflaster mit Gras in den Fugen (Baufläche Randgruppen TD), tools/rg_texturen.py |

`grass_a_specular.png`, `grass_b_specular.png`, `dirt_specular.png`, `concrete_specular.png`,
`gravel_specular.png` und `cobble_specular.png` sind zurückhaltende, materialabhängige
Specular-Ableitungen aus diesen vorhandenen Albedo-Helligkeitsmustern (keine Messaufnahmen).
Reproduzierbar mit `python tools/terrain_materials.py` (Pillow/NumPy); Inventar und Wertebereiche
unter `docs/terrain_materials.md`. Bestehende Normal-Maps bleiben unverändert.
