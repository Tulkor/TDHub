# Bollwerk-Oberflächen (HdDev.surface)

Aus dem Paket **Medieval Village MegaKit [Standard]** von Quaternius.

- Quelle: https://quaternius.com (kostenlose Standard-Version)
- Lizenz: CC0 1.0 Universal, laut `License_Standard.txt` im Paket (geprüft 2026-11-18).
- Verwendet: `T_Brick_*` → `mauer_*`, `T_UnevenBrick_*` → `bruchstein_*`, `T_Plaster_*` → `putz_*`, `T_WoodTrim_*` → `holz_*`
  (nur die beiden Bretterbahnen oben, 0–60 % der Höhe). Normalen aus `Normals Godot-Unity` (OpenGL).
- Bearbeitung: auf 1024 px verkleinert, Albedo zu einer grauen Detailkarte (Mittel 0.82) umgerechnet, damit die
  Spielfarbe aus dem Code die Fläche färbt; Rauheit aus `*_Roughness` bzw. dem G-Kanal von `*_ORM`.
- Reproduzierbar: `godot --headless -s tools/heroes/bollwerk_oberflaechen.gd -- <Textures> <Textures/Normals Godot-Unity> assets/textures/bollwerk`

## Stoffe für Modelle (HdStoffe)

- `leder_*`: aus der eigenen Bollwerk-Ledertextur `assets/textures/ui/bollwerk_leather.png` (siehe `assets/textures/ui/CREDITS.md`), grau umgerechnet, Normalen aus der Helligkeit.
- `stoff_*`, `fell_*`, `knochen_*`, `chitin_*`: prozedural mit Godot-Rauschen erzeugt, eigene Werke.
- Reproduzierbar: `godot --headless --path . -s tools/heroes/bollwerk_stoffe.gd`
