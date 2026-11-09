#!/usr/bin/env python3
"""Nahtlose Wassertexturen deterministisch erzeugen; nur Python-Standardbibliothek.

python tools/water/textures.py [--size=256] [--check]
--check vergleicht die PNGs bytegenau, ohne Dateien zu ändern.
"""
import argparse
import math
from pathlib import Path
import random
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "assets/textures/water"


def png(size, pixels):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    raw = b"".join(b"\0" + pixels[y * size * 3:(y + 1) * size * 3] for y in range(size))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def field(size, seed, stretched=False):
    rng = random.Random(seed)
    result = [[0.0] * size for _ in range(size)]
    fade = lambda t: t * t * t * (t * (t * 6 - 15) + 10)
    for octave, weight in enumerate([1.0, 0.5, 0.25, 0.125]):
        gx = (8 if stretched else 4) * 2 ** octave
        gy = (2 if stretched else 4) * 2 ** octave
        grid = [[rng.random() for _ in range(gx)] for _ in range(gy)]
        for y in range(size):
            py = y * gy / (size - 1)
            iy, fy = int(py), fade(py % 1)
            for x in range(size):
                px = x * gx / (size - 1)
                ix, fx = int(px), fade(px % 1)
                a, b = grid[iy % gy][ix % gx], grid[iy % gy][(ix + 1) % gx]
                c, d = grid[(iy + 1) % gy][ix % gx], grid[(iy + 1) % gy][(ix + 1) % gx]
                value = (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
                result[y][x] += value * weight / 1.875
    return result


def generate(size):
    height = field(size, 2701)
    streak = field(size, 8009, True)
    patches = field(size, 4417)
    flow, normal, foam = bytearray(), bytearray(), bytearray()
    byte = lambda v: round(max(0.0, min(1.0, v)) * 255)
    for y in range(size):
        for x in range(size):
            h, s, f = height[y][x], streak[y][x], patches[y][x]
            flow.extend([byte(h), byte(s), byte(f)])
            dx = (height[y][(x + 1) % (size - 1)] - height[y][(x - 1) % (size - 1)]) * 2.4
            dy = (height[(y + 1) % (size - 1)][x] - height[(y - 1) % (size - 1)][x]) * 2.4
            length = math.sqrt(dx * dx + dy * dy + 1.0)
            normal.extend([byte(0.5 - dx / length * 0.5), byte(0.5 + dy / length * 0.5), byte(0.5 + 0.5 / length)])
            t = max(0.0, min(1.0, (f - 0.4) / 0.3))
            v = byte(t * t * (3 - 2 * t))
            foam.extend([v, v, v])
    images = {"flow.png": flow, "normal.png": normal, "foam.png": foam}
    for name, pixels in images.items():
        assert pixels[:size * 3] == pixels[-size * 3:], name + ": vertikale Naht"
        for y in range(size):
            start = y * size * 3
            assert pixels[start:start + 3] == pixels[start + (size - 1) * 3:start + size * 3], name + ": horizontale Naht"
    return {name: png(size, pixels) for name, pixels in images.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not 16 <= args.size <= 1024:
        parser.error("size muss zwischen 16 und 1024 liegen")
    files = generate(args.size)
    bad = []
    if not args.check:
        TARGET.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        path = TARGET / name
        if args.check:
            if not path.exists() or path.read_bytes() != content:
                bad.append(name)
        else:
            path.write_bytes(content)
    print("Wassertexturen: " + ("abweichend: " + ", ".join(bad) if bad else f"3 PNGs, {args.size}x{args.size}, reproduzierbar"))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
