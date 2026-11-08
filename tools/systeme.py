#!/usr/bin/env python3
"""Modusunabhängige Spielsysteme (scripts/systems/) verwalten und den Umbau der Modi dorthin per Skript erledigen.

Aufrufe (Ausgabe kurz, Details nur auf Nachfrage):
  python3 tools/systeme.py matrix [--md]      System × Modus: gemeinsam / geerbt / eigen (n Fkt.) / –
                                               --md schreibt docs/systeme.md (Übersicht im Repo)
  python3 tools/systeme.py pruefen            Grenzen prüfen (läuft in tools/vor_pr.sh), letzte Zeile OK/FEHLER
  python3 tools/systeme.py neu <name> [--titel=…] [--etappe=N] [--test]
                                               legt scripts/systems/<name>/<name>.gd + Basiswerte <name>.json, Test tests/systems/<name>_test.gd/.tscn
                                               und den Katalog-Eintrag an
  python3 tools/systeme.py umziehen <quelle.gd> <system> <fkt,fkt…> [--schreiben]
                                               Codemod: Funktionen aus einem Spielskript ins System verschieben, in der
                                               Quelle eine Weiterleitung stehen lassen. Ohne --schreiben nur Vorschau.
  python3 tools/systeme.py weiterleitungen [--umstellen] [--entfernen]
                                               Weiterleitungen (## → System) mit Aufrufern; --umstellen schreibt Aufrufer
                                               game.x( auf game.systems.<sys>.x( um, --entfernen löscht unbenutzte
Katalog: scripts/systems/katalog.json. Grundsätze: docs/claude/systeme.md.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
KATALOG = os.path.join(ROOT, "scripts/systems/katalog.json")
MODES = os.path.join(ROOT, "data/modes.json")
SYS_DIR = os.path.join(ROOT, "scripts/systems")
FWD_MARK = "## Weiterleitung → System"


def rel(p):
    return os.path.relpath(p, ROOT)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json_tabs(path, data):
    text = json.dumps(data, ensure_ascii=False, indent="\t")
    # Listen aus einfachen Werten auf eine Zeile (wie von Hand geschrieben)
    text = re.sub(r"\[\n\s*((?:(?:\"[^\"\n]*\"|[-\d.]+|true|false|null),?\n\s*)+)\]",
                  lambda m: "[" + ", ".join(x.strip().rstrip(",") for x in m.group(1).strip().split("\n")) + "]", text)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text + "\n")


SAMMELTEST = os.path.join(ROOT, "tests/systems/systeme_test.gd")


def sync_sammeltest(kat):
    """Kopfzeile '## Modi:' des Sammeltests auf alle Systeme im Katalog bringen (Testauswahl je System)."""
    if not os.path.exists(SAMMELTEST):
        return
    want = "## Modi: kern, " + ", ".join("system:" + n for n in kat["systeme"])
    s = read(SAMMELTEST)
    s2 = re.sub(r"^## Modi:.*$", want, s, count=1, flags=re.M)
    if s2 != s:
        write(SAMMELTEST, s2)


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, text):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)


def mode_files(spec):
    out = []
    for pat in spec.get("dateien", []):
        out += glob.glob(os.path.join(ROOT, pat), recursive=True)
    return sorted(set(out))


FUNC_RE = re.compile(r"^(?:static\s+)?func\s+(\w+)\s*\(", re.M)


def defined_funcs(files):
    """{Funktionsname: Rumpf} aller Top-Level-Funktionen der Dateien."""
    out = {}
    for f in files:
        spans, lines = split_funcs(read(f))
        for n, (a, b) in spans.items():
            out[n] = out.get(n, "") + "\n".join(lines[a:b])
    return out


def strip_strings_comments(src):
    """Kommentare und String-Inhalte entfernen (grob), damit Prüfungen nur Code sehen."""
    out = []
    for line in src.splitlines():
        line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        line = re.sub(r"'(?:[^'\\]|\\.)*'", "''", line)
        line = line.split("#", 1)[0]
        out.append(line)
    return "\n".join(out)


def system_script(name):
    return os.path.join(SYS_DIR, name, name + ".gd")


def system_base(name):
    """Basiswerte des Systems; Modus-Daten (modes.json → system_cfg.<name>) legen sich darüber (Kaskade)."""
    return os.path.join(SYS_DIR, name, name + ".json")


# --- Matrix ---------------------------------------------------------------------------------------------------

def matrix_rows():
    kat = load(KATALOG)
    modes = {m["id"]: m for m in load(MODES)["modes"]}
    modi = kat["_modi"]
    funcs = {m: defined_funcs(mode_files(modi[m])) for m in modi}
    code = {m: strip_strings_comments("\n".join(read(f) for f in mode_files(modi[m]))) for m in modi}
    rows = []
    for sname, s in kat["systeme"].items():
        cells = {}
        for m in modi:
            # Funktionen, die nur ans System weitergeben (systems.<name>.…), zählen nicht als eigen
            own = sorted(n for n in set(s.get("eigen", [])) & set(funcs[m])
                         if ("systems.%s." % sname) not in funcs[m][n])
            parent = modi[m].get("erbt")
            klasse = s.get("klasse")
            uses = bool(klasse) and re.search(r"\b%s\b" % re.escape(klasse), code[m]) is not None
            shared = os.path.exists(system_script(sname)) and bool(FUNC_RE.search(read(system_script(sname))))
            if own:
                cells[m] = ("eigen", own)
            elif uses or (shared and sname in modes.get(m, {}).get("systems", [])) \
                    or ("systems.%s." % sname) in code[m]:
                cells[m] = ("gemeinsam", [])
            elif parent and set(s.get("eigen", [])) & set(funcs[parent]) and not shared:
                cells[m] = ("geerbt", [])
            else:
                cells[m] = ("–", [])
        rows.append((sname, s, cells))
    return list(modi), rows, modes


def cell_text(c):
    kind, own = c
    return "eigen (%d)" % len(own) if kind == "eigen" else kind


def cmd_matrix(args):
    modi, rows, modes = matrix_rows()
    if "--md" in args:
        lines = ["# Spielsysteme × Modi", "",
                 "Erzeugt mit `python3 tools/systeme.py matrix --md`, nicht von Hand ändern. "
                 "eigen (n) = der Modus baut das System noch selbst (n erkannte Funktionen), geerbt = über game.gd, "
                 "gemeinsam = nutzt scripts/systems/ bzw. die gemeinsame Klasse. ✓ = in data/modes.json angekreuzt.", "",
                 "| System | Etappe | " + " | ".join(modi) + " |",
                 "| --- | --- | " + " | ".join("---" for _ in modi) + " |"]
        for sname, s, cells in rows:
            marks = []
            for m in modi:
                tick = " ✓" if sname in modes.get(m, {}).get("systems", []) else ""
                marks.append(cell_text(cells[m]) + tick)
            lines.append("| %s – %s | %s | %s |" % (sname, s["titel"], s.get("etappe", ""), " | ".join(marks)))
        write(os.path.join(ROOT, "docs/systeme.md"), "\n".join(lines) + "\n")
        print("docs/systeme.md geschrieben (%d Systeme × %d Modi)" % (len(rows), len(modi)))
        return 0
    w = max(len(r[0]) for r in rows)
    print(" " * w + "  " + "".join("%-13s" % m[:12] for m in modi))
    eigen = 0
    for sname, _s, cells in rows:
        print(sname.ljust(w) + "  " + "".join("%-13s" % cell_text(cells[m]) for m in modi))
        eigen += sum(1 for m in modi if cells[m][0] == "eigen")
    print("%d Stellen bauen ein System noch selbst" % eigen)
    return 0


# --- Prüfen -----------------------------------------------------------------------------------------------------

def cmd_pruefen(_args):
    kat = load(KATALOG)
    modes = load(MODES)["modes"]
    errors = []
    known = set(kat["systeme"])
    for m in modes:
        for s in m.get("systems", []):
            if s not in known:
                errors.append("modes.json: Modus %s nennt unbekanntes System %s" % (m["id"], s))
        for s in m.get("system_cfg", {}):
            if s not in m.get("systems", []):
                errors.append("modes.json: Modus %s hat system_cfg.%s, aber %s nicht in systems" % (m["id"], s, s))
        if m["id"] not in kat["_modi"]:
            errors.append("katalog.json: Modus %s fehlt unter _modi" % m["id"])
    verboten = [re.compile(p) for p in kat["_verboten"]]
    for f in sorted(glob.glob(os.path.join(SYS_DIR, "**/*.gd"), recursive=True)):
        code = strip_strings_comments(read(f))
        for i, line in enumerate(code.splitlines(), 1):
            for p in verboten:
                hit = p.search(line)
                if hit:
                    errors.append("%s:%d kennt einen Modus (%s)" % (rel(f), i, hit.group(0)))
    for d in sorted(glob.glob(os.path.join(SYS_DIR, "*/"))):
        name = os.path.basename(os.path.normpath(d))
        if name not in known:
            errors.append("scripts/systems/%s fehlt in katalog.json" % name)
        if not os.path.exists(system_script(name)):
            errors.append("scripts/systems/%s/%s.gd fehlt" % (name, name))
        if not any(re.search(r"^## Modi:.*\bsystem:%s\b" % re.escape(name), read(t)[:400], re.M)
                   for t in glob.glob(os.path.join(ROOT, "tests/**/*_test.gd"), recursive=True)):
            errors.append("kein Test mit '## Modi: system:%s' (tools/systeme.py neu %s legt einen an)" % (name, name))
        base = system_base(name)
        if os.path.exists(base):
            try:
                load(base)
            except ValueError as e:
                errors.append("%s: kein gültiges JSON (%s)" % (rel(base), e))
    # Ein Modus, der ein fertiges System benutzt, muss es auch ankreuzen (damit die Testauswahl stimmt).
    modi, rows, mdict = matrix_rows()
    for sname, s, cells in rows:
        for m in modi:
            if cells[m][0] == "gemeinsam" and sname not in mdict.get(m, {}).get("systems", []):
                errors.append("modes.json: %s nutzt %s, hat es aber nicht in systems" % (m, sname))
    for e in errors:
        print("FEHLER " + e)
    print("OK: %d Systeme, %d Modi, Grenzen eingehalten" % (len(known), len(modes)) if not errors
          else "FEHLER: %d Stellen" % len(errors))
    return 1 if errors else 0


# --- Neu ----------------------------------------------------------------------------------------------------------

SYSTEM_TMPL = """extends GameSystem
## {titel}. Modusunabhängig: Basiswerte in {name}.json, Modus-Daten (modes.json → system_cfg.{name})
## legen sich darüber und gewinnen (cfg). Haken ins Spiel: hook("name", [...]). Angelegt mit tools/systeme.py neu {name}.
"""

BASE_TMPL = """{{
\t"_info": "Basiswerte des Systems {name} ({titel}). Ein Modus überschreibt sie in data/modes.json unter system_cfg.{name}; was er angibt, gewinnt, auch verschachtelt (wie CSS)."
}}
"""

TEST_TMPL = """extends Node
## Lauf: einzeln (Name sys{short})
## Modi: system:{name}
## System {name} ({titel}) ohne Modus: an einem leeren Spiel-Knoten angelegt und geprüft.
## Start: tools/run_tests.sh sys{short}

var failures := 0


func check(cond: bool, msg: String) -> void:
\tif cond:
\t\tprint("OK   ", msg)
\telse:
\t\tfailures += 1
\t\tprinterr("FAIL ", msg)


func _ready() -> void:
\tawait get_tree().process_frame
\tvar game := Node.new()
\tadd_child(game)
\tvar got := SystemHost.attach(game, "", ["{name}"])
\tcheck(got.has("{name}"), "{name} lässt sich ohne Modus anlegen")
\tprint("\\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
\tget_tree().quit(1 if failures > 0 else 0)
"""

TSCN_TMPL = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/systems/{name}_test.gd" id="1"]

[node name="Sys{camel}Test" type="Node"]
script = ExtResource("1")
"""


def opt(args, key, default=None):
    for a in args:
        if a.startswith("--%s=" % key):
            return a.split("=", 1)[1]
    return default


def cmd_neu(args):
    pos = [a for a in args if not a.startswith("--")]
    if not pos or not re.fullmatch(r"[a-z][a-z0-9_]*", pos[0]):
        print("Aufruf: tools/systeme.py neu <name_klein> [--titel=…] [--etappe=N]")
        return 2
    name = pos[0]
    kat = load(KATALOG)
    entry = kat["systeme"].setdefault(name, {"titel": opt(args, "titel", name), "etappe": 0, "eigen": []})
    if opt(args, "titel"):
        entry["titel"] = opt(args, "titel")
    if opt(args, "etappe"):
        entry["etappe"] = int(opt(args, "etappe"))
    made = []
    camel = "".join(p.capitalize() for p in name.split("_"))
    short = name.replace("_", "")
    files = {
        system_script(name): SYSTEM_TMPL.format(name=name, titel=entry["titel"]),
        system_base(name): BASE_TMPL.format(name=name, titel=entry["titel"]),
    }
    if "--test" in args:  # eigener Test, sobald das System echten Code bekommt (umziehen)
        files[os.path.join(ROOT, "tests/systems/%s_test.gd" % name)] = TEST_TMPL.format(name=name, titel=entry["titel"], short=short)
        files[os.path.join(ROOT, "tests/systems/%s_test.tscn" % name)] = TSCN_TMPL.format(name=name, camel=camel)
    for p, text in files.items():
        if not os.path.exists(p):
            write(p, text)
            made.append(rel(p))
    save_json_tabs(KATALOG, kat)
    sync_sammeltest(kat)
    print("angelegt: " + (", ".join(made) if made else "nichts (gab es schon)"))
    print("Nächste Schritte: Modi in data/modes.json → systems ankreuzen, Code mit 'umziehen' herüberholen")
    return 0


# --- Funktionen ausschneiden (Codemod) ---------------------------------------------------------------------------

TOP_RE = re.compile(r"^(?:static\s+func|func|var|const|signal|enum|class|class_name|extends|@|static\s+var)\b")


def split_funcs(src):
    """Top-Level-Funktionen als {name: (start, end)} in Zeilen; start schließt direkt darüber stehende ##-Zeilen ein."""
    lines = src.split("\n")
    heads = [i for i, l in enumerate(lines) if FUNC_RE.match(l)]
    out = {}
    for i in heads:
        name = FUNC_RE.match(lines[i]).group(1)
        start = i
        while start > 0 and lines[start - 1].startswith("##"):
            start -= 1
        end = i + 1
        while end < len(lines):
            l = lines[end]
            if l and not l[0].isspace() and not l.startswith("#") and TOP_RE.match(l):
                break
            if l.startswith("##") and end + 1 < len(lines):
                j = end
                while j < len(lines) and lines[j].startswith("##"):
                    j += 1
                if j < len(lines) and TOP_RE.match(lines[j]):
                    break
            if l.startswith("# ---"):
                break
            end += 1
        while end > i + 1 and lines[end - 1].strip() == "":
            end -= 1
        out[name] = (start, end)
    return out, lines


def signature(lines, start, end):
    """Kopfzeile(n) bis zum ':' am Zeilenende, Parameter-Namen, Rückgabetyp."""
    head = ""
    for l in lines[start:end]:
        if l.startswith("##"):
            continue
        head += l.strip() + " "
        if head.rstrip().endswith(":"):
            break
    m = re.match(r"(?:static\s+)?func\s+(\w+)\s*\((.*)\)\s*(?:->\s*([\w\[\]., ]+))?\s*:", head.strip())
    params = []
    if m and m.group(2).strip():
        depth, cur = 0, ""
        for ch in m.group(2):
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            if ch == "," and depth == 0:
                params.append(cur)
                cur = ""
            else:
                cur += ch
        params.append(cur)
    names = [re.match(r"\s*(\w+)", p).group(1) for p in params if p.strip()]
    return head.strip(), names, (m.group(3) or "").strip() if m else ""


def member_names(src):
    names = set(FUNC_RE.findall(src))
    names |= set(re.findall(r"^(?:static\s+)?(?:@\w+(?:\([^)]*\))?\s+)*var\s+(\w+)", src, re.M))
    names |= set(re.findall(r"^const\s+(\w+)", src, re.M))
    names |= set(re.findall(r"^signal\s+(\w+)", src, re.M))
    return names


def callers(name, skip):
    pat = re.compile(r"\.%s\(" % re.escape(name))
    out = []
    for f in glob.glob(os.path.join(ROOT, "scripts/**/*.gd"), recursive=True) + \
            glob.glob(os.path.join(ROOT, "tests/**/*.gd"), recursive=True) + \
            glob.glob(os.path.join(ROOT, "tools/*.gd")):
        if os.path.abspath(f) == os.path.abspath(skip):
            continue
        n = len(pat.findall(strip_strings_comments(read(f))))
        if n:
            out.append((rel(f), n))
    return out


def overrides(name, source):
    """Unterklassen (extends \"res://…quelle.gd\"), die name überschreiben – dort braucht es einen Haken."""
    res_path = "res://" + rel(source)
    out = []
    for f in glob.glob(os.path.join(ROOT, "scripts/**/*.gd"), recursive=True):
        s = read(f)
        if ('extends "%s"' % res_path) in s and re.search(r"^func\s+%s\s*\(" % re.escape(name), s, re.M):
            out.append(rel(f))
    return out


def cmd_umziehen(args):
    pos = [a for a in args if not a.startswith("--")]
    if len(pos) < 3:
        print("Aufruf: tools/systeme.py umziehen <quelle.gd> <system> <fkt,fkt…> [--schreiben]")
        return 2
    source = os.path.join(ROOT, pos[0])
    sname = pos[1]
    wanted = [w for w in pos[2].split(",") if w]
    target = system_script(sname)
    if not os.path.exists(target):
        print("System %s gibt es noch nicht: erst tools/systeme.py neu %s" % (sname, sname))
        return 2
    src = read(source)
    spans, lines = split_funcs(src)
    missing = [w for w in wanted if w not in spans]
    if missing:
        print("nicht in %s: %s" % (pos[0], ", ".join(missing)))
        return 2
    members = member_names(src) - set(wanted)
    moved_text, stubs, notes = [], {}, []
    for w in wanted:
        a, b = spans[w]
        body = "\n".join(lines[a:b])
        head, params, ret = signature(lines, a, b)
        # Zugriffe auf Mitglieder des Spiels im verschobenen Code mit game. versehen (nicht hinter einem Punkt,
        # nicht in Strings/Kommentaren grob ausgenommen: nur Code-Teil jeder Zeile).
        used = set()
        new_lines = []
        # Lokale Namen (Parameter, var, for, Lambda-Parameter) verdecken gleichnamige Mitglieder des Spiels.
        local = set(params) | set(re.findall(r"\bvar\s+(\w+)", body)) | set(re.findall(r"\bfor\s+(\w+)\s+in\b", body))
        for lam in re.findall(r"\bfunc\s*\(([^)]*)\)", body):
            local |= set(re.findall(r"(\w+)\s*(?::[^,]*)?(?:,|$)", lam))
        fields = members - local
        for i, l in enumerate(body.split("\n")):
            if l.startswith("##") or FUNC_RE.match(l):
                new_lines.append(l)
                continue
            code, sep, comment = l.partition("#")
            parts = re.split(r'("(?:[^"\\]|\\.)*")', code)
            for k in range(0, len(parts), 2):
                def sub(m):
                    if m.group(1) in fields:
                        used.add(m.group(1))
                        return "game." + m.group(1)
                    return m.group(1)
                parts[k] = re.sub(r"(?<![\w.$%])\b([A-Za-z_]\w*)\b", sub, parts[k])
            code = "".join(parts)
            # var x := game.… lässt sich nicht ableiten (game ist untypisiert): dann ohne Ableitung
            code = re.sub(r"(\bvar\s+\w+\s*):=(\s*[^\n]*\bgame\.)", r"\1=\2", code)
            new_lines.append(code + sep + comment)
        moved_text.append("\n".join(new_lines))
        call = "systems.%s.%s(%s)" % (sname, w, ", ".join(params))
        stub_head = head if head.endswith(":") else head + ":"
        is_void = ret in ("", "void") and not re.search(r"^\s+return\s+\S", body, re.M)
        stubs[w] = "%s  %s\n%s\n\t%s%s" % (FWD_MARK, sname, stub_head, "" if is_void else "return ", call)
        ov = overrides(w, source)
        if ov:
            notes.append("  ! %s wird überschrieben in %s → Haken nötig (System ruft hook(\"%s\"))" % (w, ", ".join(ov), w))
        if used:
            notes.append("  %s: game.%s" % (w, ", game.".join(sorted(used))))
        cs = callers(w, source)
        if cs:
            notes.append("  %s: %d Aufrufer laufen über die Weiterleitung (%s)" % (
                w, sum(n for _, n in cs), ", ".join(f for f, _ in cs[:4]) + (" …" if len(cs) > 4 else "")))
    print("%s → scripts/systems/%s: %d Funktionen" % (pos[0], sname, len(wanted)))
    for n in notes:
        print(n)
    if "--schreiben" not in args:
        print("Vorschau. Mit --schreiben ausführen.")
        return 0
    # Quelle: Funktionen durch Weiterleitungen ersetzen (von hinten, damit die Zeilennummern stimmen)
    for w in sorted(wanted, key=lambda x: -spans[x][0]):
        a, b = spans[w]
        lines[a:b] = stubs[w].split("\n")
    out = "\n".join(lines)
    if not re.search(r"^var systems\b", out, re.M):
        out = re.sub(r"(^extends[^\n]*\n(?:##[^\n]*\n)*)", r"\1\n## Spielsysteme des Modus (SystemHost, data/modes.json → systems).\nvar systems := {}\n",
                     out, count=1, flags=re.M)
    write(source, out)
    tgt = read(target).rstrip("\n") + "\n\n\n" + "\n\n\n".join(moved_text) + "\n"
    write(target, tgt)
    print("geschrieben. Jetzt: game.-Zugriffe prüfen, Haken für Überschreibungen, Test tests/systems/%s_test.gd" % sname)
    return 0


# --- Weiterleitungen ---------------------------------------------------------------------------------------------

def forwarders():
    out = []
    for f in glob.glob(os.path.join(ROOT, "scripts/**/*.gd"), recursive=True):
        lines = read(f).split("\n")
        for i, l in enumerate(lines):
            if l.startswith(FWD_MARK) and i + 1 < len(lines):
                m = FUNC_RE.match(lines[i + 1])
                if m:
                    out.append((f, m.group(1), l[len(FWD_MARK):].strip(), i))
    return out


def cmd_weiterleitungen(args):
    fw = forwarders()
    if not fw:
        print("keine Weiterleitungen")
        return 0
    removed = changed = 0
    for f, name, sname, _ in fw:
        cs = callers(name, f)
        print("%-40s %-24s → %-12s %d Aufrufer" % (rel(f), name, sname, sum(n for _, n in cs)))
        if "--umstellen" in args:
            for cf, _n in cs:
                p = os.path.join(ROOT, cf)
                s = read(p)
                s2 = re.sub(r"\bgame\.%s\(" % re.escape(name), "game.systems.%s.%s(" % (sname, name), s)
                if s2 != s:
                    write(p, s2)
                    changed += 1
    if "--entfernen" in args:
        for f, name, sname, _ in sorted(fw, key=lambda x: -x[3]):
            if callers(name, f):
                continue
            src = read(f)
            uses = re.findall(r"(?<![\w.])%s\(" % re.escape(name), strip_strings_comments(src))
            if len(uses) > 1:  # mehr als die eigene Kopfzeile: wird in der Datei selbst noch gerufen
                continue
            spans, lines = split_funcs(src)
            a, b = spans[name]
            if a > 0 and lines[a - 1].startswith(FWD_MARK):
                a -= 1
            del lines[a:b]
            write(f, "\n".join(lines))
            removed += 1
    print("%d Weiterleitungen, %d Dateien umgestellt, %d entfernt" % (len(fw), changed, removed))
    return 0


def main(argv):
    cmds = {"matrix": cmd_matrix, "pruefen": cmd_pruefen, "neu": cmd_neu, "umziehen": cmd_umziehen,
            "weiterleitungen": cmd_weiterleitungen}
    if not argv or argv[0] not in cmds:
        print(__doc__.strip().split("\n\n")[0])
        print("Befehle: " + ", ".join(cmds))
        return 2
    return cmds[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
