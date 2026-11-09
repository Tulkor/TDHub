"""Nach messing_blender.py: Kantenleiste aus einer Spalte kachelbar machen (waagrecht und senkrecht),
Knopfrahmen auf einfache Größe (300 x 56, Spitze 14) für die StyleBoxTexture der Wc3Button."""
import sys
from pathlib import Path
from PIL import Image

d = Path(sys.argv[1])
k = Image.open(d / "kante_h.png").convert("RGBA")
w, h = k.size
k = k.crop((w // 2, 0, w // 2 + 1, h)).resize((64, h))
k = k.resize((64, 40), Image.LANCZOS)
k.save(d / "kante_h.png")
k.rotate(90, expand=True).save(d / "kante_v.png")
f = Image.open(d / "knopf_rahmen.png").convert("RGBA")
f.resize((f.width // 2, f.height // 2), Image.LANCZOS).save(d / "knopf_rahmen.png")
print("ok", k.size, f.size)
