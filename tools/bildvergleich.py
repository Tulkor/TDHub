"""Vergleicht zwei Bilder (oder zwei Ordner mit gleichnamigen Bildern), damit Claude ein Bild nur ansieht,
wenn sich wirklich etwas geändert hat, und dann nur den geänderten Ausschnitt.

Ein Screenshot kostet beim Ansehen 800 bis 2800 Tokens. Nach einer kleinen Änderung reicht oft die Antwort
"gleich" oder "geändert oben rechts", und wenn doch hinsehen, dann nur auf alt|neu des geänderten Bereichs.

Aufruf: python3 tools/bildvergleich.py [--schwelle=12] [--aus=vergleich.jpg] alt.png neu.png
        python3 tools/bildvergleich.py alter_ordner/ neuer_ordner/
Ausgabe je Bild: GLEICH <name> | GEÄNDERT <name>: <x> % in <n> Bereichen (<wo>), dazu
        VERGLEICH <jpg> (alt links, neu rechts, nur geänderter Ausschnitt, ca. <n> Tokens)
Exit 0 = alles gleich, 1 = etwas geändert, 2 = Fehler.
Von tools/screenshot.sh automatisch aufgerufen, wenn ein Bild gleichen Namens schon einmal gemacht wurde.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

RASTER = (32, 18)  # Zellen in x und y


def lade(pfad, groesse=None):
    img = Image.open(pfad).convert("RGB")
    if groesse and img.size != groesse:
        img = img.resize(groesse)
    return img


def bereiche(maske):
    """Zusammenhängende geänderte Zellen -> Liste von (x0, y0, x1, y1) in Zellen."""
    h, w = maske.shape
    gesehen = np.zeros_like(maske, bool)
    out = []
    for y in range(h):
        for x in range(w):
            if not maske[y, x] or gesehen[y, x]:
                continue
            stapel, box = [(y, x)], [x, y, x, y]
            gesehen[y, x] = True
            while stapel:
                cy, cx = stapel.pop()
                box = [min(box[0], cx), min(box[1], cy), max(box[2], cx), max(box[3], cy)]
                for ny in range(cy - 1, cy + 2):
                    for nx in range(cx - 1, cx + 2):
                        if 0 <= ny < h and 0 <= nx < w and maske[ny, nx] and not gesehen[ny, nx]:
                            gesehen[ny, nx] = True
                            stapel.append((ny, nx))
            out.append(tuple(box))
    return sorted(out, key=lambda b: -(b[2] - b[0] + 1) * (b[3] - b[1] + 1))


def wo(box):
    cx = (box[0] + box[2] + 1) / 2 / RASTER[0]
    cy = (box[1] + box[3] + 1) / 2 / RASTER[1]
    v = "oben" if cy < 0.34 else ("unten" if cy > 0.66 else "Mitte")
    h = "links" if cx < 0.34 else ("rechts" if cx > 0.66 else "")
    return (v + " " + h).strip() if h or v != "Mitte" else "Mitte"


def vergleiche(alt, neu, schwelle, aus, ausschnitt=None, sauber=False, breite=1024):
    a = lade(alt)
    b = lade(neu, a.size)
    if ausschnitt:
        x, y, cw, ch = ausschnitt
        a, b = a.crop((x, y, x + cw, y + ch)), b.crop((x, y, x + cw, y + ch))
    w, h = a.size
    d = np.abs(np.asarray(a, np.int16) - np.asarray(b, np.int16)).max(axis=2)
    gx, gy = RASTER
    zellen = np.zeros((gy, gx))
    for j in range(gy):
        for i in range(gx):
            blk = d[j * h // gy:(j + 1) * h // gy, i * w // gx:(i + 1) * w // gx]
            zellen[j, i] = (blk > schwelle).mean()
    maske = zellen > 0.01
    anteil = 100.0 * (d > schwelle).mean()
    name = os.path.basename(neu)
    if not maske.any():
        print("GLEICH %s (%.2f %% Pixel leicht anders)" % (name, anteil))
        return False
    bs = bereiche(maske)
    print("GEÄNDERT %s: %.1f %% in %d Bereichen (%s)" % (name, anteil, len(bs), ", ".join(dict.fromkeys(wo(b) for b in bs[:4]))))
    # Ausschnitt: Hülle aller Bereiche mit Rand, alt | neu nebeneinander
    x0 = min(b[0] for b in bs) * w // gx; y0 = min(b[1] for b in bs) * h // gy
    x1 = (max(b[2] for b in bs) + 1) * w // gx; y1 = (max(b[3] for b in bs) + 1) * h // gy
    rand = max(w, h) // 40
    x0, y0, x1, y1 = max(0, x0 - rand), max(0, y0 - rand), min(w, x1 + rand), min(h, y1 + rand)
    if sauber:
        x0, y0, x1, y1 = 0, 0, w, h
    ca, cb = a.crop((x0, y0, x1, y1)), b.crop((x0, y0, x1, y1))
    cw, ch = ca.size
    bild = Image.new("RGB", (cw * 2 + 8, ch), (19, 23, 28) if sauber else (255, 0, 160))
    bild.paste(ca, (0, 0)); bild.paste(cb, (cw + 8, 0))
    zeichnen = ImageDraw.Draw(bild)
    for bx in ([] if sauber else bs):  # geänderte Bereiche im neuen Bild markieren
        r = (bx[0] * w // gx - x0 + cw + 8, bx[1] * h // gy - y0, (bx[2] + 1) * w // gx - x0 + cw + 8, (bx[3] + 1) * h // gy - y0)
        zeichnen.rectangle(r, outline=(0, 255, 255), width=2)
    if bild.width > breite:
        bild = bild.resize((breite, max(1, bild.height * breite // bild.width)))
    if sauber:
        from PIL import ImageFont
        try:
            font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 24)
        except OSError:
            font = ImageFont.load_default()
        labeled = Image.new("RGB", (bild.width, bild.height + 44), (19, 23, 28))
        labeled.paste(bild, (0, 44))
        draw = ImageDraw.Draw(labeled)
        draw.text((14, 8), "VORHER", fill="white", font=font)
        draw.text((bild.width // 2 + 14, 8), "NACHHER", fill="white", font=font)
        bild = labeled
    if not aus:
        aus = os.path.join("/tmp/gemtd-vergleich", os.path.splitext(name)[0] + "_vergleich.jpg")
    os.makedirs(os.path.dirname(aus) or ".", exist_ok=True)
    bild.save(aus, quality=95 if sauber else 85)
    print("VERGLEICH %s (alt links, neu rechts, Ausschnitt %dx%d, ca. %d Tokens)" % (aus, cw, ch, bild.width * bild.height // 750))
    return True


def main(argv):
    schwelle, aus, pfade = 12, "", []
    ausschnitt, sauber, breite = None, False, 1024
    for x in argv:
        if x.startswith("--schwelle="):
            schwelle = int(x.split("=", 1)[1])
        elif x.startswith("--aus="):
            aus = x.split("=", 1)[1]
        elif x.startswith("--ausschnitt="):
            ausschnitt = tuple(map(int, x.split("=", 1)[1].split(",")))
        elif x == "--sauber":
            sauber = True
        elif x.startswith("--breite="):
            breite = int(x.split("=", 1)[1])
        else:
            pfade.append(x)
    if len(pfade) != 2:
        print(__doc__)
        return 2
    alt, neu = pfade
    try:
        if os.path.isdir(alt):
            namen = sorted(n for n in os.listdir(neu) if n.lower().endswith((".png", ".jpg")) and os.path.isfile(os.path.join(alt, n)))
            if not namen:
                print("Keine gleichnamigen Bilder in beiden Ordnern.")
                return 2
            geaendert = [vergleiche(os.path.join(alt, n), os.path.join(neu, n), schwelle, "", ausschnitt, sauber, breite) for n in namen]
            return 1 if any(geaendert) else 0
        return 1 if vergleiche(alt, neu, schwelle, aus, ausschnitt, sauber, breite) else 0
    except OSError as e:
        print("Fehler: %s" % e)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
