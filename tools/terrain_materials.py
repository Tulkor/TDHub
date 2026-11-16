#!/usr/bin/env python3
"""Inventar und reproduzierbare Normal-/Specular-Ergänzungen ausschließlich für Gelände.

python tools/terrain_materials.py          ergänzt Maps, schreibt docs/terrain_materials.md
python tools/terrain_materials.py --check prüft Inventar, Abmessungen und reproduzierbare Specular-Pixel
Vorhandene Normal-Maps bleiben unverändert. Abgeleitete Specular-Daten sind keine Messwerte.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
GROUND = ROOT / "assets/textures/ground"
ROCK = ROOT / "assets/textures/rock"
RANGES = {
    "grass_a": (0.10, 0.18), "grass_b": (0.10, 0.18), "dirt": (0.10, 0.18),
    "gravel": (0.22, 0.32), "concrete": (0.25, 0.38), "cobble": (0.32, 0.48),
    "rock_face_03_diff_1k": (0.42, 0.54),
}
TEXTURE = re.compile(r"res://(assets/textures/(?:ground|rock)/[^\s\"')]+\.(?:png|jpe?g))")


def references() -> dict[str, list[str]]:
    """Only actual game resources, never icons, units or the generator's own filenames."""
    result: dict[str, list[str]] = {}
    for folder, suffix in (("scripts", ".gd"), ("assets/shaders", ".gdshader"), ("scenes", ".tscn")):
        for file in sorted((ROOT / folder).rglob("*" + suffix)):
            for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
                for match in TEXTURE.finditer(line):
                    result.setdefault(match[1], []).append(f"{file.relative_to(ROOT).as_posix()}:{number}")
    return result


def materials(refs: dict[str, list[str]]) -> list[dict]:
    found = []
    for resource, usage in sorted(refs.items()):
        file = ROOT / resource
        if re.search(r"_(normal|nor_gl|specular|rough|roughness|height|disp|ao)(?:_|\.)", file.name):
            continue
        if file.stem not in RANGES:
            raise ValueError(f"Gelände-Albedo ohne Materialbereich: {resource}; RANGES ergänzen.")
        if file.parent == ROCK:
            normal = ROCK / "rock_face_03_nor_gl_1k.jpg"
            rough = ROCK / "rock_face_03_rough_1k.jpg"
            specular = ROCK / "rock_face_03_specular_1k.png"
        else:
            normal = next((p for ext in (".jpg", ".png") if (p := file.with_name(file.stem + "_normal" + ext)).exists()), file.with_name(file.stem + "_normal.png"))
            rough = next((p for name in ("_roughness", "_rough") for ext in (".png", ".jpg") if (p := file.with_name(file.stem + name + ext)).exists()), None)
            specular = file.with_name(file.stem + "_specular.png")
        found.append({"albedo": file, "normal": normal, "roughness": rough, "specular": specular, "refs": usage, "range": RANGES[file.stem]})
    if not found:
        raise ValueError("Keine Gelände-Albedos im Spielcode gefunden.")
    return found


def specular_pixels(material: dict) -> tuple[np.ndarray, str]:
    low, high = material["range"]
    rough = material["roughness"]
    if rough:
        with Image.open(rough) as image:
            weight = 1.0 - np.asarray(image.convert("L"), dtype=np.float32) / 255.0
        method = "aus vorhandener Rauheit (invertiert, Materialbereich begrenzt)"
    else:
        with Image.open(material["albedo"]) as image:
            height = np.asarray(image.convert("L").filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32)
        p05, p95 = np.percentile(height, (5, 95))
        weight = np.clip((height - p05) / max(float(p95 - p05), 1.0), 0, 1)
        method = "aus Albedo-Helligkeitsmuster abgeleitet; keine gemessene Specular-/Rauheitsquelle"
    return np.rint(255 * (low + weight * (high - low))).astype(np.uint8), method


def derive_normal(albedo: Path, target: Path) -> None:
    """Conservative periodic tangent normal fallback; original normals always take precedence."""
    with Image.open(albedo) as image:
        height = np.asarray(image.convert("L").filter(ImageFilter.GaussianBlur(1.0)), dtype=np.float32) / 255
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 1.4
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 1.4
    normal = np.stack((-dx, dy, np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    Image.fromarray(np.rint((normal * 0.5 + 0.5) * 255).astype(np.uint8)).save(target)


def verify(material: dict, expected: np.ndarray) -> None:
    with Image.open(material["albedo"]) as image:
        size = image.size
    for key in ("normal", "specular"):
        with Image.open(material[key]) as image:
            if image.size != size:
                raise ValueError(f"Abmessung von {material[key]} stimmt nicht mit Albedo überein.")
            if key == "normal" and len(image.getbands()) < 3:
                raise ValueError(f"Normal-Map ist nicht RGB: {material[key]}")
            if key == "specular" and (image.mode != "L" or not np.array_equal(np.asarray(image), expected)):
                raise ValueError(f"Specular veraltet/falsch: {material[key]}; Generator ausführen.")


def evidence(file: str, token: str) -> str:
    """Report live line numbers, rather than retaining stale line references after edits."""
    path = ROOT / file
    if path.exists():
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if token in line:
                return f"`{file}:{number}`"
    return f"`{file}` (Stelle nicht gefunden; separat prüfen)"


def mode_report() -> list[str]:
    import json
    modes = json.loads((ROOT / "data/modes.json").read_text(encoding="utf-8"))["modes"]
    shared = "Variantenabhängiger Board3D: gewählter UiTheme-Skin → FieldStyle; sichtbarer Fotoboden `ground`, Raster/Marmor `neon_floor` bzw. `neon_floor_lit`. "
    board = evidence("scripts/map/board_3d.gd", "surface_textures")
    style = evidence("scripts/map/field_style.gd", "static func current_name")
    notes = {
        "gemtd": (shared + "Neon ist keine fehlende Albedo-Map. Optionale Wasser-/Uferflächen separat.", board + ", " + style),
        "eevetd": (shared + "Startet mit Druiden-Skin; Gras/Erde, optionale Baumuntergründe und Naturmodelle.", evidence("scripts/game/eeve_game.gd", "UiTheme.use_skin") + ", " + board),
        "shoppingmaul": (shared + "Startet mit Art-déco-Skin; prozeduraler Marmor, Stadtflächen (`city`) und Brunnenwasser statt pauschaler Grastexturen.", evidence("scripts/maul/maul_game.gd", "UiTheme.use_skin") + ", " + evidence("scripts/maul/maul_city.gd", "city.gdshader")),
        "randgruppen": (shared + "Poster-Overrides ersetzen Bauflächen durch Pflaster und Wege durch Splitt; Wiese und Pflaster in RgScenery separat gebunden.", evidence("scripts/map/field_style.gd", "POSTER_TEXTURES") + ", " + evidence("scripts/map/rg_scenery.gd", "ground_surface.gdshader")),
        "youtd": (shared + "Startet mit Druiden-Skin; keine Annahme, dass spätere Karten-/Stilwahl unverändert bleibt.", evidence("scripts/youtd/youtd_game.gd", "UiTheme.use_skin") + ", " + board),
        "heroes": ("Bestehende Bollwerk-Oberflächen unverändert; neue Arena-/Schlund-Materialbindungen folgen im separaten Bollwerk-PR.", "Bollwerk-Integration separat"),
        "survivors": ("Eigener SvWorld statt Board3D: Eis-/Schnee-Albedo, Normalen und Rauheit entstehen zur Laufzeit; Specular ist ein Materialkonstantwert (Eis 0.7, Lochfläche 0.8), keine Specular-Bildmap. Meer und Schnee-Overlay haben eigene Shader. Keine externen Gras-/Felsmaps unterstellen.", evidence("scripts/survivors/sv_world.gd", "normal_texture") + ", " + evidence("scripts/survivors/sv_world.gd", "m.metallic_specular = 0.7") + ", " + evidence("scripts/survivors/sv_world.gd", "sv_ocean.gdshader")),
    }
    lines = ["## Pro Modus: belegte Materialwege", "", "| Modus | Pipeline und Sonderflächen | Quellnachweis |", "|---|---|---|"]
    for mode in modes:
        description, sources = notes.get(mode["id"], ("Noch nicht im Materialbericht zugeordnet; keine Abdeckung behauptet.", "`data/modes.json`"))
        lines.append(f"| {mode['name']} (`{mode['id']}`) | {description} | {sources} |")
    lines += ["", "Importierte GLB-Materialien (z. B. Natur-/Umgebungsmodelle) bleiben **eingebettet und unverändert**; ihre externen Normal-/Specular-Dateien werden hier nicht pauschal behauptet. Der Bericht verändert keine importierten Figuren-/Tower-/Boss-/UI-Materialien. Statische Pfadfunde belegen Ressourcen und Bindestellen; GPU-/Modustests und die sichtbare Wirkung sind separat zu prüfen.", ""]
    return lines


def procedural_report() -> list[str]:
    entries = [
        ("Grundboden / Baum-Erde / RG-Pflaster", "Vorhandene Normal-Bildmaps und materialabhängige Specular-PNGs; FieldStyle leitet Dateinamen von der ausgewählten Albedo ab, explizite Overrides haben Vorrang.", "scripts/map/field_style.gd", "static func surface_textures"),
        ("Neon-/Glasfelsen", "Analytisches Ader-/Mikrorelief und räumlich variierendes Specular; kein erfundenes Normal-Bitmap.", "assets/shaders/rock.gdshader", "terrain_relief_normal"),
        ("Maul-Stadt", "Analytische Stein-/Fenstervertiefung; Specular/Rauheit unterscheiden Stein und Glas.", "assets/shaders/city.gdshader", "terrain_relief_normal"),
        ("Beleuchtetes Raster / Marmor", "Analytisches Mikrorelief und Specular um vorhandene Stilparameter; unbeleuchtetes Hologramm bleibt bewusst unverändert.", "assets/shaders/neon_floor.gdshaderinc", "terrain_relief_normal"),
        ("Natürliches Ufer", "Analytisches Boden-/Steinrelief, feuchter Rand weniger rau und reflektierender.", "assets/shaders/natural_bank.gdshader", "terrain_relief_normal"),
        ("Städtisches Ufer", "Echte Pflaster-Normal-/Specularmaps, triplanar und mit UV-abgeleiteter Tangentenbasis gebunden.", "scripts/systems/water/water_bank.gd", "cobble_specular"),
        ("Wasser / Wasserfall / Brunnen", "Animierte Normal-Bildmaps für Wasser/Wasserfall; Brunnen analytische Wellennormalen. Bestehende Fresnel-/Reflexion; Gischt ist eine transparente unbeleuchtete Effektfläche.", "assets/shaders/water_surface.gdshaderinc", "NORMAL_MAP_DEPTH"),
        ("Bollwerk-Kathedralstein", "Analytisches Steinrelief, materialabhängiger Specular/Rauheit. Vorhandene Flächenkontur und Farbwahl bleiben erhalten.", "scripts/heroes/hd_cathedral.gd", "terrain_relief_normal"),
        ("Bollwerk-Schlund-Anmarsch / Arenen", "Analytisches Materialrelief und Specular in den vorhandenen Inline-Shadern; RockFace03-Fels zusätzlich mit Originalnormalen und Rauheitsquelle.", "scripts/heroes/hd_final_style.gd", "terrain_relief_normal"),
        ("Bollwerk HdDev-Prüfboden", "Bewusster geometrischer Checker/Entwicklungs-Look: keine künstlichen Normalmaps aufgezwungen; Materialkonstanten statt vorgetäuschter Bild-PBR.", "scripts/heroes/hd_dev.gd", "m.roughness = 0.8"),
        ("Hub-/Menüboden und Stein", "Konkrete Beton-/Gras-/Erde-/Splitt-Specularmaps passend zu vorhandenen Normalen; Terrainbilder, keine UI-Icons geändert.", "scripts/ui/wc3_menu_bg.gd", "DETAIL_SPECULAR"),
        ("Survivors-Schneeüberzug", "Geometrische Flächennormalen und konstante Rauheit 0.85; separates Überzugsmaterial, keine zusätzliche Specular-/Normal-Bildmap behauptet.", "scripts/survivors/sv_snow.gdshader", "ROUGHNESS"),
    ]
    lines = ["## Prozedurale Flächen und bewusste Ausnahmen", "", "| Fläche | Tatsächliche Normal-/Specular-Art | Nachweis |", "|---|---|---|"]
    lines += [f"| {name} | {description} | {evidence(file, token)} |" for name, description, file, token in entries if (ROOT / file).exists()]
    lines += ["", "Palette-/Solidcolor-Naturmodelle (z. B. `rock_medium` / `rock_tall`) behalten ihre eingebetteten Materialfarben, geometrischen Normalen und Rauheitswerte. **Keine** pauschale externe Bitmap-Abdeckung dieser GLBs. Prüfpfade für reale GPU-Ergebnisse: `tools/shaders/terrain_probe.tscn`, `tools/water/route_hills.tscn` sowie die üblichen Modus-Screenshots; Details unter `tools/shaders/README.md`.", ""]
    return lines


def report(found: list[dict], refs: dict[str, list[str]]) -> None:
    rel = lambda p: p.relative_to(ROOT).as_posix()
    lines = ["# Gelände-Materialinventar", "", "Automatisch mit `tools/terrain_materials.py` aus tatsächlichen Texturreferenzen in Spielskripten, Shadern und Szenen erstellt.", "",
             "## Reproduzieren", "", "`python tools/terrain_materials.py` erzeugt fehlende Normal-Maps und deterministische Specular-Maps; `--check` prüft ohne Schreiben.",
             "Benötigt Pillow und NumPy (vorhandene gebündelte Python-Laufzeit). `tools/heroes/materialien.py` bleibt als RockFace03-Kompatibilitätseinstieg erhalten.",
             "Wiederkehrende Prüfung: `tools/run_tests.sh terrainmaterials`; enthalten in `schnell`/`alle` und bei passenden Generator-/Ground-/Rock-Änderungen in `geaendert` (tests/bereiche.json).", "",
             "Specular-Dateien sind einkanalige lineare **Godot-SPECULAR-Koeffizienten**, keine sRGB-Farbwerte und keine weißen Glanzplatzhalter. Die vorhandenen Normal-Maps werden niemals überschrieben. Material-/Modus-Skalierungen im Shader bleiben die letzte Tuninginstanz.", "",
             "## Tatsächlich referenzierte Bildmaterialien", "", "| Albedo | Größe | Normal | Specular und Wertebereich | Ableitung |", "|---|---|---|---|---|"]
    for m in found:
        with Image.open(m["albedo"]) as image:
            size = f"{image.width}×{image.height}"
        pixels, method = specular_pixels(m)
        normal_type = "Original OpenGL/Poly Haven, erhalten" if m["albedo"].parent == ROCK else ("aus Albedo abgeleitet (bestehendes boden_texturen.py)" if m["albedo"].stem in ("grass_a", "grass_b", "dirt") else "prozedurale Höhenableitung (bestehendes rg_texturen.py)")
        if m.get("normal_generated"):
            normal_type = "neu aus Albedo-Helligkeit abgeleitet; kein gemessenes Höhenmaterial"
        lines.append(f"| `{rel(m['albedo'])}` | {size} | `{m['normal'].name}` ({normal_type}) | `{m['specular'].name}` · {pixels.min()/255:.3f}–{pixels.max()/255:.3f} | {method} |")
    lines += ["", "Die bestehenden Gras-/Erde-Normalen stammen bereits aus der Helligkeitsableitung von `tools/boden_texturen.py`; Beton/Pflaster/Splitt aus `tools/rg_texturen.py`. RockFace03 nutzt die originale OpenGL-Normal- und Rauheitskarte. Neu abgeleitete Normal-Maps in diesem Lauf: " + str(sum(bool(m.get("normal_generated")) for m in found)) + ".", ""]
    lines += mode_report()
    lines += procedural_report()
    lines += [
              "## Nachweise und Abgrenzung", "", "Dateiexistenz ist **kein** Nachweis, dass jeder Modus jede Map bindet. Die folgenden Stellen sind statische Nutzungsnachweise, keine pauschale Laufzeitfreigabe aller Modi. Prozedurales Neon, Marmor, Fels sowie Wasser können Normal-/Specular-Daten analytisch im Shader erzeugen und benötigen dann keine Bildmap. UI, Tower, Bosse und Figuren werden nicht bearbeitet.", ""]
    for m in found:
        lines.append(f"- `{m['albedo'].name}`: " + ", ".join(f"`{r}`" for r in m["refs"]) + ".")
        for key in ("normal", "specular"):
            bound = list(refs.get(rel(m[key]), []))
            dynamic = m["albedo"].parent == GROUND and any(r.startswith(("scripts/map/board_3d.gd:", "scripts/map/field_style.gd:")) for r in m["refs"])
            if dynamic:
                resolver = evidence("scripts/map/field_style.gd", "static func surface_textures")
                board = evidence("scripts/map/board_3d.gd", "surface_textures")
                lines.append(f"  - {key}: abhängig von tatsächlich gewählter Albedo dynamisch über {resolver} → {board}" + ("; zusätzliche direkte Bindings: " + ", ".join(f"`{r}`" for r in bound) if bound else "") + ".")
                continue
            lines.append(f"  - {key}: " + (", ".join(f"`{r}`" for r in bound) if bound else "kein direktes statisches Pfad-Binding gefunden; dynamische/konstantenbasierte Bindings separat prüfen") + ".")
    lines += ["", "## Quellen", "", "Vorhandene Quellen-/Lizenznachweise: `assets/textures/ground/CREDITS.md` und `assets/textures/rock/CREDITS.md`. Neu erzeugte Maps sind Ableitungen dieser bestehenden Quellen; es werden keine externen Texturen nachgeladen.", ""]
    (ROOT / "docs/terrain_materials.md").write_text("\n".join(lines), encoding="utf-8")


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="keine Dateien schreiben")
    parser.add_argument("--only-rock", action="store_true", help="Kompatibilität mit tools/heroes/materialien.py")
    args = parser.parse_args(argv)
    refs = references()
    found = materials(refs)
    selected = [m for m in found if not args.only_rock or m["albedo"].parent == ROCK]
    normal_count = 0
    for material in selected:
        pixels, _ = specular_pixels(material)
        if not args.check:
            if not material["normal"].exists():
                derive_normal(material["albedo"], material["normal"])
                material["normal_generated"] = True
                normal_count += 1
            Image.fromarray(pixels).save(material["specular"])
        verify(material, pixels)
    if not args.check and not args.only_rock:
        report(found, refs)
    print(f"OK Gelände: {len(selected)} Albedos, Normal/Specular passend; " + ("Pixel-Reproduzierbarkeit geprüft" if args.check else f"{normal_count} neue Normal-Ableitungen; Specular erzeugt"))


if __name__ == "__main__":
    main()
