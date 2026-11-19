#!/usr/bin/env python3
"""Kompatibler Einstieg: RockFace03-Material über den gemeinsamen Geländegenerator."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    sys.path.insert(0, str(ROOT / "tools"))
    from terrain_materials import main as terrain_main
    terrain_main(["--only-rock"])


if __name__ == "__main__":
    main()
