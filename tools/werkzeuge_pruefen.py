#!/usr/bin/env python3
"""Python-Werkzeuge syntaktisch prüfen, ohne Cache-Dateien oder mehrzeilige Shell-Argumente."""
import ast
from pathlib import Path
import sys


def main():
    failed = False
    for filename in sys.argv[1:]:
        try:
            ast.parse(Path(filename).read_text(encoding="utf-8-sig"), filename)
        except (SyntaxError, OSError) as exc:
            print(f"{filename}: {exc}")
            failed = True
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
