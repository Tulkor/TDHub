#!/usr/bin/env python3
"""Welche Tests passen zu den geänderten Dateien? Regeln in tests/bereiche.json, Modi je Test im Testkopf.

Aufruf:
  python3 tools/test_auswahl.py [--basis=REF] [--erklaeren] [--ohne-fest]
                                       -> eine Zeile: "schnell" oder Testnamen (--ohne-fest: CI, ohne lange)
  python3 tools/test_auswahl.py --pruefen                    -> prüft bereiche.json und die Testköpfe
  python3 tools/test_auswahl.py --dateien a.gd b.json         -> Auswahl für diese Dateien statt git diff

Geändert = Commits seit dem gemeinsamen Stand mit REF (Standard origin/main, in CI der Ziel-Branch des PRs,
auch über die Umgebung TEST_BASIS) plus nicht committete und neue Dateien.
Jeder Test trägt in den ersten Zeilen "## Modi: <id>[, <id> …]": Modus-Ids aus data/modes.json, "kern"
(läuft nur bei gemeinsamem Code) oder "system:<name>" (Tests eines gemeinsamen Systems unter scripts/systems/).
"""
import fnmatch
import json
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CODE = re.compile(r"\.(gd|tscn|tres|gdshader|gdshaderinc)$|^project\.godot$|^data/")
CHECKS = {"tabelle", "ui", "maps", "marken", "werkzeuge", "auswahl", "systeme_pruefen", "balanceeditor", "htmleditor", "watertextures", "bossdata"}


def load_json(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def tests():
    """Alle Tests: Name -> {stem, art, modi}. Wie run_tests.sh: tests/**/<stamm>_test.tscn, Kopf in der .gd."""
    out = {}
    for d, _, files in os.walk(os.path.join(ROOT, "tests")):
        for fn in sorted(files):
            if not fn.endswith("_test.tscn"):
                continue
            stem = os.path.relpath(os.path.join(d, fn), os.path.join(ROOT, "tests"))[: -len("_test.tscn")]
            name, art, modi = os.path.basename(stem), "einzeln", None
            try:
                with open(os.path.join(ROOT, "tests", stem + "_test.gd"), encoding="utf-8") as f:
                    head = [next(f, "") for _ in range(8)]
            except OSError:
                head = []
            for line in head:
                m = re.match(r"## Lauf: *(\S+)?(.*)", line)
                if m:
                    art = m.group(1) or "einzeln"
                    n = re.search(r"\(Name ([a-z_]+)\)", m.group(2))
                    if n:
                        name = n.group(1)
                m = re.match(r"## Modi: *(.*)", line)
                if m:
                    modi = [x.strip() for x in m.group(1).split(",") if x.strip()]
            out[name] = {"stem": stem, "art": art, "modi": modi}
    return out


def modes():
    return {m["id"]: m for m in load_json("data/modes.json")["modes"]}


def changed_files(basis):
    def git(*args):
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    try:
        base = git("merge-base", "HEAD", basis).strip()
        files = git("diff", "--name-only", base).splitlines()
        files += git("ls-files", "--others", "--exclude-standard").splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return sorted(set(f for f in files if f))


def targets_for(path, rules, mode_map, all_tests):
    """Ziele für eine Datei und die Regel, die gegriffen hat."""
    m = re.match(r"tests/(.+)_test\.(gd|tscn)$", path)
    if m:  # ein geänderter Test läuft selbst (auch ein langer)
        own = [n for n, info in all_tests.items() if info["stem"] == m.group(1)]
        return own, "der Test selbst"
    m = re.match(r"scripts/systems/([^/]+)/", path)
    if m:
        system = m.group(1)
        users = [mid for mid, md in mode_map.items() if system in md.get("systems", [])]
        if not any("systems" in md for md in mode_map.values()):
            return ["alle"], "scripts/systems/ (noch kein Modus mit 'systems' in modes.json)"
        return users + ["system:" + system], "scripts/systems/%s/ (Modi mit diesem System)" % system
    for pattern, tg in rules:
        if fnmatch.fnmatch(path, pattern):
            return list(tg), pattern
    if CODE.search(path):
        return ["alle"], "gemeinsamer Code"
    return [], "kein Code"


def expand(targets, all_tests):
    """Ziele -> Testnamen; None bedeutet 'alle' (schnell)."""
    names = []
    for t in targets:
        if t == "alle":
            return None
        if t in all_tests or t in CHECKS:
            names.append(t)
            continue
        # Modus-Id oder system:<name>: alle Tests mit diesem Eintrag, ohne die langen
        names += [n for n, info in all_tests.items() if t in (info["modi"] or []) and info["art"] != "fest"]
    return names


def select(files, explain=False, ohne_fest=False):
    cfg = load_json("tests/bereiche.json")
    all_tests, mode_map = tests(), modes()
    names = list(cfg["immer"])
    every = False
    for f in files:
        tg, why = targets_for(f, cfg["regeln"], mode_map, all_tests)
        ex = expand(tg, all_tests)
        if explain:
            print("  %-50s %-28s -> %s" % (f, why[:28], "alle" if ex is None else (" ".join(tg) or "-")), file=sys.stderr)
        if ex is None:
            every = True
        else:
            names += ex
    if every:
        return "schnell"
    seen = []
    for n in names:
        if ohne_fest and all_tests.get(n, {}).get("art") == "fest":
            continue
        if n not in seen:
            seen.append(n)
    return " ".join(seen)


def check():
    cfg = load_json("tests/bereiche.json")
    all_tests, mode_map = tests(), modes()
    errors = []
    allowed = set(mode_map) | {"kern"}
    for name, info in sorted(all_tests.items()):
        if info["modi"] is None:
            errors.append("Test %s: Zeile '## Modi: …' fehlt in tests/%s_test.gd" % (name, info["stem"]))
            continue
        for m in info["modi"]:
            if m not in allowed and not m.startswith("system:"):
                errors.append("Test %s: unbekannter Modus '%s' (erlaubt: %s, system:<name>)" % (name, m, ", ".join(sorted(allowed))))
    for n in cfg["immer"]:
        if n not in all_tests and n not in CHECKS:
            errors.append("immer: unbekannter Test '%s'" % n)
    tracked = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT, capture_output=True, text=True).stdout.splitlines()
    for pattern, tg in cfg["regeln"]:
        for t in tg:
            if t != "alle" and t not in all_tests and t not in CHECKS and t not in mode_map:
                errors.append("Regel %s: unbekanntes Ziel '%s'" % (pattern, t))
        if tracked and not any(fnmatch.fnmatch(f, pattern) for f in tracked):
            errors.append("Regel %s: passt auf keine Datei im Repo (veraltet?)" % pattern)
    for mid, md in mode_map.items():
        if not any(mid in (i["modi"] or []) for i in all_tests.values()):
            errors.append("Modus %s: kein Test trägt '## Modi: %s'" % (mid, mid))
        for s in md.get("systems", []):
            if not os.path.isdir(os.path.join(ROOT, "scripts", "systems", s)):
                errors.append("Modus %s: System '%s' gibt es nicht unter scripts/systems/" % (mid, s))
    for e in errors:
        print(e)
    if errors:
        return 1
    per_mode = {mid: sum(1 for i in all_tests.values() if mid in (i["modi"] or [])) for mid in mode_map}
    print("Testauswahl: %d Tests, %d Regeln, je Modus %s" % (
        len(all_tests), len(cfg["regeln"]), " ".join("%s:%d" % kv for kv in per_mode.items())))
    return 0


def main(argv):
    basis = os.environ.get("TEST_BASIS") or "origin/main"
    explain = ohne_fest = False
    files = None
    for i, a in enumerate(argv):
        if a == "--pruefen":
            return check()
        if a.startswith("--basis="):
            basis = a.split("=", 1)[1]
        elif a == "--erklaeren":
            explain = True
        elif a == "--ohne-fest":
            ohne_fest = True
        elif a == "--dateien":
            files = argv[i + 1:]
            break
        else:
            print("Unbekannt: " + a, file=sys.stderr)
            return 2
    if files is None:
        files = changed_files(basis)
        if files is None:
            print("schnell")
            return 0
    print(select(files, explain, ohne_fest))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
