"""Baut alle Treffer- und Schuss-Effekte aus dem Kenney Particle Pack (CC0, assets/fx/kenney/).

Aufruf: python3 tools/fx/kenney_effekte.py
Schreibt:
  data/fx/hits.json   – Treffer-Effekte (Ebenen im Format von fx_player.gd, Bilder direkt aus assets/fx/kenney/)
  data/fx/shots.json  – Schuss-Effekte; die Sprite-Sheets dazu werden hier aus Kenney-Bildern gerechnet
  assets/fx/shot/*.png
Die Kenney-Bilder sind grau; die Farbe kommt aus den Ebenen bzw. wird ins Sheet eingefärbt. Im Spiel dreht
fx_data.gd jeden Effekt auf die Farbe des Towers, deshalb reicht pro Machart ein Effekt je Farbbereich.
Ein Effekt ändern: Vorlage oder Tabelle unten anpassen, Skript laufen lassen, tools/fx/vorschau.sh ansehen.
"""
import colorsys
import json
import os

import numpy as np
from PIL import Image, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KENNEY = os.path.join(REPO, "assets", "fx", "kenney")
SHOT_DIR = os.path.join(REPO, "assets", "fx", "shot")
TEX = "res://assets/fx/kenney/%s.png"
QUELLE = "Kenney Particle Pack 1.1 (kenney.nl, CC0), erzeugt mit tools/fx/kenney_effekte.py"


# --- Treffer ------------------------------------------------------------------

def fade(n=12, hold=0.25):
	"""Alpha über die Lebenszeit: kurz einblenden, halten, ausblenden."""
	out = []
	for i in range(n):
		t = i / (n - 1)
		a = min(1.0, t / 0.08) if t < 0.08 else (1.0 if t < hold else max(0.0, 1.0 - (t - hold) / (1.0 - hold)))
		out.append([1.0, 1.0, 1.0, round(a, 4)])
	return out


def ramp(a, b, n=12, ease=1.0):
	return [round(a + (b - a) * (i / (n - 1)) ** ease, 4) for i in range(n)]


def layer(name, tex, col, **kw):
	l = {
		"name": name, "pos": [0.0, 0.0, 0.0], "rot": [0.0, 0.0, 0.0, 1.0], "scale": [1.0, 1.0, 1.0],
		"mode": "billboard", "align": "view", "length_scale": 2.0, "velocity_scale": 0.0,
		"delay": 0.0, "duration": 0.1, "loop": False, "bursts": [[0.0, 1, 1, 0.0]], "rate": 0.0, "max": 40,
		"life": [0.3, 0.3], "speed": [0.0, 0.0], "size": [1.0, 1.0], "rotation": [0.0, 0.0],
		"color": [col, col], "gravity": 0.0, "tex": TEX % tex, "add": True, "tint": [2.0, 2.0, 2.0, 1.0],
		"uv_scale": [1, 1], "uv_offset": [0, 0], "size_curve": ramp(1.0, 1.0), "color_curve": fade(),
	}
	l.update(kw)
	return l


def rgba(c, a=1.0, light=0.0):
	r, g, b = c
	return [round(r + (1 - r) * light, 4), round(g + (1 - g) * light, 4), round(b + (1 - b) * light, 4), a]


def burst(n):
	return [[0.0, n, 1, 0.0]]


TURN = [0.0, 6.2832]


def t_spark(c):
	return [
		layer("blitz", "star_09", rgba(c, 1, 0.4), life=[0.16, 0.2], size=[1.5, 1.8], rotation=TURN,
			size_curve=ramp(0.6, 1.2, ease=0.5)),
		layer("glut", "circle_05", rgba(c, 0.8), life=[0.3, 0.3], size=[1.1, 1.1], size_curve=ramp(0.8, 1.3)),
		layer("funken", "trace_01", rgba(c, 1, 0.3), mode="stretch", length_scale=3.0, velocity_scale=0.02,
			bursts=burst(9), life=[0.22, 0.34], speed=[4.0, 7.0], size=[0.14, 0.2], size_curve=ramp(1.0, 0.0),
			shape={"type": "sphere", "radius": 0.15, "thickness": 1.0}, drag=0.15, max_speed=1.5),
	]


def t_fire(c):
	return [
		layer("feuer", "fire_01", rgba(c, 1, 0.15), bursts=burst(2), life=[0.35, 0.45], size=[1.9, 2.3], rotation=TURN,
			spin=[-3.0, 3.0], size_curve=ramp(0.5, 1.3, ease=0.6), color_curve=fade(hold=0.15)),
		layer("kern", "scorch_02", rgba(c, 1, 0.5), life=[0.16, 0.16], size=[1.6, 1.6], rotation=TURN,
			size_curve=ramp(0.7, 1.1)),
		layer("glut", "star_04", rgba(c, 1, 0.3), bursts=burst(6), life=[0.35, 0.55], speed=[1.5, 3.0],
			size=[0.25, 0.4], gravity=-0.15, size_curve=ramp(1.0, 0.0),
			shape={"type": "sphere", "radius": 0.2, "thickness": 1.0}, drag=0.2, max_speed=0.8),
	]


def t_magic(c):
	return [
		layer("zeichen", "magic_03", rgba(c, 1, 0.2), life=[0.45, 0.45], size=[1.6, 1.6], rotation=[0.0, 0.8],
			spin=[2.5, 2.5], size_curve=ramp(0.3, 1.2, ease=0.4)),
		layer("wirbel", "twirl_01", rgba(c, 1), life=[0.4, 0.4], size=[1.4, 1.4], rotation=TURN, spin=[-7.0, -7.0],
			size_curve=ramp(0.6, 1.3, ease=0.5)),
		layer("sterne", "star_04", rgba(c, 1, 0.4), bursts=burst(7), life=[0.3, 0.5], speed=[1.2, 2.6],
			size=[0.3, 0.45], size_curve=ramp(1.0, 0.0), shape={"type": "sphere", "radius": 0.25, "thickness": 1.0},
			drag=0.2, max_speed=0.6),
	]


def t_ring(c):
	return [
		layer("ring", "circle_02", rgba(c, 1, 0.1), life=[0.35, 0.35], size=[2.0, 2.0],
			size_curve=ramp(0.15, 1.0, ease=0.45), color_curve=fade(hold=0.1)),
		layer("blitz", "flare_01", rgba(c, 1, 0.5), life=[0.2, 0.2], size=[2.6, 2.6], rotation=[-0.4, 0.4],
			size_curve=ramp(1.0, 0.6)),
		layer("stern", "star_06", rgba(c, 1, 0.4), life=[0.25, 0.25], size=[1.2, 1.2], rotation=[0.0, 0.8],
			size_curve=ramp(1.2, 0.3)),
	]


def t_shock(c):
	return [
		layer("welle", "light_03", rgba(c, 0.9), life=[0.32, 0.32], size=[1.8, 1.8], size_curve=ramp(0.3, 1.1, ease=0.5),
			color_curve=fade(hold=0.05)),
		layer("strom", "spark_01", rgba(c, 1, 0.3), bursts=burst(2), life=[0.12, 0.2], size=[1.2, 1.5], rotation=TURN,
			color_curve=fade(hold=0.5)),
		layer("strom2", "spark_02", rgba(c, 1, 0.3), delay=0.08, life=[0.12, 0.16], size=[1.0, 1.2], rotation=TURN,
			color_curve=fade(hold=0.5)),
	]


def t_slash(c):
	return [
		layer("hieb", "slash_03", rgba(c, 1, 0.3), life=[0.18, 0.22], size=[1.6, 1.6], rotation=TURN,
			size_curve=ramp(0.8, 1.2), color_curve=fade(hold=0.3)),
		layer("hieb2", "slash_04", rgba(c, 1, 0.3), delay=0.05, life=[0.18, 0.22], size=[1.4, 1.4], rotation=TURN,
			size_curve=ramp(0.8, 1.2), color_curve=fade(hold=0.3)),
		layer("kratzer", "scratch_01", rgba(c, 1, 0.5), life=[0.15, 0.15], size=[1.0, 1.0], rotation=TURN),
	]


def t_poison(c):
	return [
		layer("wolke", "smoke_04", rgba(c, 0.85), bursts=burst(3), add=False, tint=[1.4, 1.4, 1.4, 1.0],
			life=[0.5, 0.7], speed=[0.3, 0.7], size=[0.8, 1.1], rotation=TURN, spin=[-1.5, 1.5],
			size_curve=ramp(0.5, 1.4, ease=0.6), color_curve=fade(hold=0.2),
			shape={"type": "sphere", "radius": 0.2, "thickness": 1.0}),
		layer("glanz", "magic_05", rgba(c, 1, 0.3), life=[0.25, 0.25], size=[1.4, 1.4], size_curve=ramp(0.6, 1.0)),
		layer("tropfen", "circle_05", rgba(c, 1, 0.2), bursts=burst(6), life=[0.35, 0.5], speed=[1.5, 2.5],
			size=[0.18, 0.26], gravity=0.35, size_curve=ramp(1.0, 0.3),
			shape={"type": "sphere", "radius": 0.15, "thickness": 1.0}),
	]


def t_dark(c):
	return [
		layer("sog", "twirl_02", rgba(c, 1), bursts=burst(2), life=[0.45, 0.5], size=[1.6, 1.8], rotation=TURN,
			spin=[6.0, 8.0], size_curve=ramp(1.2, 0.3, ease=0.7)),
		layer("schatten", "smoke_09", rgba(c, 0.7, -0.5), add=False, tint=[1.0, 1.0, 1.0, 1.0], life=[0.5, 0.5],
			size=[1.6, 1.6], rotation=TURN, spin=[-1.0, -1.0], size_curve=ramp(0.6, 1.2), color_curve=fade(hold=0.2)),
		layer("kern", "star_05", rgba(c, 1, 0.3), life=[0.3, 0.3], size=[1.0, 1.0], size_curve=ramp(1.2, 0.2)),
	]


def t_star(c):
	return [
		layer("stern", "star_08", rgba(c, 1, 0.4), life=[0.25, 0.25], size=[2.0, 2.0], rotation=[0.0, 0.8],
			spin=[1.5, 1.5], size_curve=ramp(0.4, 1.1, ease=0.4)),
		layer("glanz", "star_07", rgba(c, 1, 0.3), bursts=burst(8), life=[0.3, 0.45], speed=[2.0, 4.0],
			size=[0.35, 0.5], rotation=TURN, size_curve=ramp(1.0, 0.0),
			shape={"type": "sphere", "radius": 0.2, "thickness": 1.0}, drag=0.2, max_speed=0.8),
		layer("ring", "circle_01", rgba(c, 0.8), life=[0.3, 0.3], size=[1.6, 1.6], size_curve=ramp(0.3, 1.0, ease=0.5)),
	]


def t_dirt(c):
	return [
		layer("staub", "dirt_02", rgba(c, 1), add=False, tint=[1.3, 1.3, 1.3, 1.0], life=[0.4, 0.4], size=[1.5, 1.5],
			rotation=TURN, size_curve=ramp(0.5, 1.2, ease=0.5), color_curve=fade(hold=0.2)),
		layer("brocken", "dirt_01", rgba(c, 1), add=False, tint=[1.2, 1.2, 1.2, 1.0], bursts=burst(4),
			life=[0.35, 0.5], speed=[2.0, 3.5], size=[0.3, 0.45], rotation=TURN, gravity=0.6,
			shape={"type": "sphere", "radius": 0.15, "thickness": 1.0}, size_curve=ramp(1.0, 0.6)),
		layer("blitz", "scorch_01", rgba(c, 1, 0.5), life=[0.15, 0.15], size=[1.2, 1.2], rotation=TURN),
	]


# (id, Vorlage, Farbe) – fx_data.gd nimmt den Effekt mit dem nächsten Farbton, blasse Tower den blassesten.
HITS = [
	("red_spark", t_spark, "#ff4a3a"),
	("orange_fire", t_fire, "#ff6a1e"),
	("brown_dirt", t_dirt, "#c08850"),
	("gold_star", t_star, "#ffc23a"),
	("yellow_spark", t_spark, "#ffe03a"),
	("lime_shock", t_shock, "#b4ff3a"),
	("green_poison", t_poison, "#50ff40"),
	("teal_ring", t_ring, "#3affb4"),
	("cyan_shock", t_shock, "#3ae8ff"),
	("blue_ring", t_ring, "#4a90ff"),
	("blue_magic", t_magic, "#5a6aff"),
	("violet_dark", t_dark, "#8a3aff"),
	("purple_magic", t_magic, "#c05aff"),
	("pink_star", t_star, "#ff5ad8"),
	("rose_fire", t_fire, "#ff3a7a"),
	("white_slash", t_slash, "#dde8ff"),
	("white_spark", t_spark, "#f0f0ff"),
]


def hex_rgb(h):
	return tuple(int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def hue_sat(h):
	r, g, b = hex_rgb(h)
	hh, _l, s = colorsys.rgb_to_hls(r, g, b)
	hv, sv, _v = colorsys.rgb_to_hsv(r, g, b)
	return round(hv, 3), round(sv, 3)


def build_hits():
	effects = {}
	for fid, tmpl, col in HITS:
		layers = tmpl(hex_rgb(col))
		hue, sat = hue_sat(col)
		length = max(l["delay"] + l["duration"] + l["life"][1] for l in layers)
		effects[fid] = {"name": "Kenney " + tmpl.__name__[2:], "color": col, "hue": hue, "saturation": sat,
			"length": round(length, 2), "layers": layers}
	return {"_quelle": QUELLE, "effects": effects}


# --- Schüsse (Sprite-Sheets) ----------------------------------------------------

def load_grey(name):
	"""Kenney-Bild als Helligkeit*Alpha (0..1)."""
	a = np.asarray(Image.open(os.path.join(KENNEY, name + ".png")).convert("RGBA"), dtype=np.float32) / 255.0
	return a[..., :3].mean(axis=2) * a[..., 3]


def band(img, h):
	"""Mittleren waagrechten Streifen der Höhe h ausschneiden (Rotated-Bilder sind 512 breit)."""
	c = img.shape[0] // 2
	return img[c - h // 2:c - h // 2 + h]


def fit(img, w, h):
	return np.asarray(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS),
		dtype=np.float32) / 255.0


def glow(img, r):
	return np.asarray(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)),
		dtype=np.float32) / 255.0


def colorize(v, col, white=0.7):
	"""Helligkeit → Farbe: dunkle Teile in der Effektfarbe, sehr helle Teile Richtung Weiß."""
	c = np.array(hex_rgb(col), np.float32)
	v = np.clip(v, 0, 1)[..., None]
	w = np.clip((v - white) / (1 - white), 0, 1)
	rgb = c * (1 - w) + w
	return np.concatenate([rgb, v], axis=2)


def save_sheet(fid, frames, cols, col, white=0.7):
	h, w = frames[0].shape[:2]
	rows = (len(frames) + cols - 1) // cols
	sheet = np.zeros((rows * h, cols * w, 4), np.float32)
	for i, f in enumerate(frames):
		y, x = (i // cols) * h, (i % cols) * w
		sheet[y:y + h, x:x + w] = colorize(f, col, white)
	os.makedirs(SHOT_DIR, exist_ok=True)
	Image.fromarray((sheet * 255).astype(np.uint8), "RGBA").save(os.path.join(SHOT_DIR, fid + ".png"), optimize=True)
	return rows


def shift_x(img, dx):
	return np.roll(img, int(dx), axis=1)


def beam_frames():
	"""Magischer Strahl: Kern mit dem Querschnitt (Mitte) von trace_06 über die ganze Länge, darüber zwei gewellte
	Hüllen (trace_03), die nach vorne laufen."""
	w, h = 512, 64
	core_img = fit(band(load_grey("Rotated/trace_06_rotated"), 128), w, h)
	profile = core_img[:, w // 2 - 8:w // 2 + 8].mean(axis=1, keepdims=True)
	profile = profile / max(float(profile.max()), 0.01)
	ends = np.clip(np.minimum(np.arange(w), w - 1 - np.arange(w)) / 12.0, 0, 1)[None, :]
	core = profile * ends
	half = fit(band(load_grey("Rotated/trace_03_rotated"), 80), w // 2, h)
	wave = np.concatenate([half, np.fliplr(half)], axis=1)
	out = []
	env = [0.7, 1.0, 1.0, 0.95, 0.8, 0.6, 0.4, 0.2]
	for i, e in enumerate(env):
		f = core * 0.9 + (shift_x(wave, i * 64) * 0.7 + shift_x(np.flipud(wave), -i * 48) * 0.4) * ends
		f = f + glow(f, 6) * 0.6
		out.append(np.clip(f * e, 0, 1))
	return out, w / h


def lightning_frames():
	"""Blitz: spark_05/06 (gedreht) im Wechsel, gespiegelt, mit Leuchten."""
	w, h = 512, 96
	a = fit(band(load_grey("Rotated/spark_05_rotated"), 160), w, h)
	b = fit(band(load_grey("Rotated/spark_06_rotated"), 160), w, h)
	seq = [(a, 1.0), (np.flipud(b), 1.0), (np.fliplr(a), 0.9), (b, 0.75), (np.flipud(a), 0.5), (np.fliplr(b), 0.3)]
	return [np.clip((f * 1.4 + glow(f, 5) * 1.2) * e, 0, 1) for f, e in seq], w / h


def fireball_frames():
	"""Feuerball: Mündungsfeuer (gedreht) flackert, Kopf zeigt in Flugrichtung (rechts)."""
	w, h = 256, 116
	names = ["muzzle_02_rotated", "muzzle_03_rotated", "muzzle_05_rotated", "muzzle_04_rotated"]
	out = []
	for i in range(8):
		img = load_grey("Rotated/" + names[i % len(names)])
		img = band(img, 232)
		f = np.fliplr(fit(img, w, h)) * (0.8 if i % 2 == 0 else 0.7)
		out.append(np.clip(f + glow(f, 4) * 0.4, 0, 1))
	return out, w / h


def orb_frames():
	"""Energiekugel: runder, heller Kopf (light_01 + circle_05) vorne rechts, Schweif aus trace_01 nach hinten,
	leicht pulsierend. Für Splash-Tower, die nicht nach Feuer aussehen sollen (Wasser, Magie, Silber …)."""
	w, h = 256, 96
	head_s = h
	head = fit(load_grey("light_01"), head_s, head_s) * 0.9 + fit(load_grey("circle_05"), head_s, head_s) * 0.8
	tail = fit(band(load_grey("Rotated/trace_01_rotated"), 64), w, h // 2)
	ramp_x = np.linspace(0.0, 1.0, w)[None, :] ** 1.6
	out = []
	for i in range(8):
		f = np.zeros((h, w), np.float32)
		k = 0.85 + 0.15 * np.sin(i / 8 * 2 * np.pi)
		f[h // 4:h // 4 + h // 2] += np.roll(tail, i * 9, axis=1) * ramp_x * 1.3
		f[:, w - head_s:] += head * k
		out.append(np.clip(f + glow(f, 4) * 0.5, 0, 1))
	return out, w / h


def nova_frames():
	"""Nova: Ring (circle_02) wächst nach außen, dazu kurzer Lichtblitz (light_03) in der Mitte."""
	s = 256
	ring = load_grey("circle_02")
	light = load_grey("light_03")
	out = []
	n = 12
	for i in range(n):
		t = i / (n - 1)
		f = np.zeros((s, s), np.float32)
		k = 0.25 + 0.75 * (1 - (1 - t) ** 2)
		rs = max(8, int(s * k))
		r = fit(ring, rs, rs)
		o = (s - rs) // 2
		f[o:o + rs, o:o + rs] += r * (1.0 - t * 0.8) * 1.3
		ls = max(8, int(s * (0.4 + 0.5 * t)))
		lg = fit(light, ls, ls)
		o = (s - ls) // 2
		f[o:o + ls, o:o + ls] += lg * max(0.0, 0.8 - t) * 0.9
		out.append(np.clip(f + glow(f, 3) * 0.5, 0, 1))
	return out, 1.0


SHOTS = {
	# id: (Bilder, Art, Spalten, Farbe, Werte für die Wiedergabe)
	"magic_beam": (beam_frames, "line", 2, "#ff8fc8", {"length": 0.3, "width": 0.35, "add": True, "brightness": 1.2}),
	"lightning_arc": (lightning_frames, "line", 2, "#ffb04a", {"length": 0.22, "width": 0.6, "add": True, "brightness": 1.3}),
	"fire_orb": (fireball_frames, "projectile", 4, "#ff6a1a", {"length": 0.24, "width": 0.55, "add": True, "brightness": 1.4}),
	"energy_orb": (orb_frames, "projectile", 4, "#3ab8ff", {"length": 0.24, "width": 0.46, "add": True, "brightness": 1.5}),
	"ruby_nova": (nova_frames, "nova", 4, "#ff5a4a", {"length": 0.45, "size": 1.0, "add": True, "brightness": 1.3}),
}


def build_shots():
	effects = {}
	for fid, (make, kind, cols, col, play) in SHOTS.items():
		frames, aspect = make()
		rows = save_sheet(fid, frames, cols, col, 0.85 if kind == "projectile" else 0.7)
		hue, sat = hue_sat(col)
		e = {"name": "Kenney " + make.__name__.replace("_frames", ""), "kind": kind,
			"sheet": "res://assets/fx/shot/%s.png" % fid, "cols": cols, "rows": rows, "frames": len(frames),
			"aspect": round(aspect, 3), "color": col, "hue": hue, "saturation": sat}
		e.update(play)
		effects[fid] = e
		print("Schuss", fid, len(frames), "Bilder")
	return effects


def main():
	hits = build_hits()
	with open(os.path.join(REPO, "data", "fx", "hits.json"), "w", encoding="utf-8") as f:
		json.dump(hits, f, ensure_ascii=False, indent="\t")
		f.write("\n")
	print("Treffer:", ", ".join(hits["effects"]))
	path = os.path.join(REPO, "data", "fx", "shots.json")
	with open(path, encoding="utf-8") as f:
		shots = json.load(f)
	shots["_quelle"] = QUELLE
	shots["effects"] = build_shots()
	with open(path, "w", encoding="utf-8") as f:
		json.dump(shots, f, ensure_ascii=False, indent="\t")
		f.write("\n")
	# Treffer aus Brackeys/Kronbits wieder eintragen (hits.json wurde oben neu geschrieben)
	import zusatz_effekte
	zusatz_effekte.main([])
	import prozedurale_effekte
	prozedurale_effekte.main([])


if __name__ == "__main__":
	main()
