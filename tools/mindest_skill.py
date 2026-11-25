#!/usr/bin/env python3
"""Mindest-Skill per Bisektion: wie gut muss ein Spieler (Bot mit stufenloser Spielstärke 0–100) mindestens spielen,
um ein Ziel zu erreichen? Je Probe spielen mehrere Seeds (tools/testlauf.sh --skills=S), die Probe gilt als
geschafft, wenn mindestens --quote der Seeds das Ziel erreichen.

Aufruf:
  python3 tools/mindest_skill.py <modus|alle> [--schwierigkeiten=einfach,mittel,schwer] [--aufstiege=0]
      [--ziel=sieg|welle:20|anteil:0.5] [--seeds=1,2,3] [--schritte=5] [--quote=0.5] [--jobs=3] [--tempo=4]
      [--extra="--checkpoint=user://cp.stand"] [--aus=/tmp/gemtd-testlauf/mindest.jsonl] [--md=bericht.md]
Ziel: sieg = ganze Partie gewinnen; welle:N = Welle N erreichen; anteil:x = Anteil x aller Wellen erreichen
(Standard anteil:0.5, solange die Bots nicht gewinnen). Ausgabe: eine Zeile je Modus × Schwierigkeit, dazu jede
Probe als JSON-Zeile in --aus und alle Partien in /tmp/gemtd-testlauf/ergebnisse.jsonl.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODI = ["gemtd", "eevetd", "shoppingmaul", "randgruppen", "youtd", "survivors", "bollwerk"]


def args_lesen(argv):
    a = {"schwierigkeiten": "mittel", "aufstiege": "0", "ziel": "anteil:0.5", "seeds": "1,2,3", "schritte": "5",
         "quote": "0.5", "jobs": "3", "tempo": "4", "extra": "", "aus": "/tmp/gemtd-testlauf/mindest.jsonl", "md": ""}
    pos = []
    for x in argv:
        if x.startswith("--") and "=" in x:
            k, v = x[2:].split("=", 1)
            a[k] = v
        else:
            pos.append(x)
    if not pos:
        print(__doc__)
        sys.exit(1)
    a["modi"] = MODI if pos[0] == "alle" else pos[0].split(",")
    return a


def erreicht(d, ziel):
    if ziel == "sieg":
        return bool(d.get("sieg"))
    art, _, wert = ziel.partition(":")
    if d.get("sieg"):
        return True
    if art == "welle":
        return int(d["welle"]) >= int(wert)
    if art == "anteil":
        return int(d["welle"]) >= float(wert) * int(d["wellen"])
    raise SystemExit("unbekanntes Ziel: " + ziel)


def probe(a, modus, diff, asc, skill):
    """Spielt alle Seeds mit Spielstärke skill, liefert die Ergebnisse (Liste von Dicts)."""
    fd, aus = tempfile.mkstemp(suffix=".jsonl", prefix="probe_")
    os.close(fd)
    cmd = ["bash", os.path.join(ROOT, "tools/testlauf.sh"), modus, "--skills=%g" % skill, "--seeds=" + a["seeds"],
           "--schwierigkeiten=" + diff, "--aufstiege=" + str(asc), "--jobs=" + a["jobs"], "--tempo=" + a["tempo"],
           "--aus=" + aus]
    if a["extra"]:
        cmd.append("--extra=" + a["extra"])
    subprocess.run(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    res = [json.loads(l) for l in open(aus) if l.strip()]
    os.remove(aus)
    # auch ins Sammelprotokoll, wie testlauf.sh ohne --aus
    with open("/tmp/gemtd-testlauf/ergebnisse.jsonl", "a") as f:
        for d in res:
            f.write(json.dumps(d) + "\n")
    return res


def bisektion(a, modus, diff, asc, log):
    ziel = a["ziel"]
    quote = float(a["quote"])
    proben = {}

    def teste(s):
        res = probe(a, modus, diff, asc, s)
        ok = sum(1 for d in res if erreicht(d, ziel))
        wellen = sorted(int(d["welle"]) for d in res)
        geschafft = bool(res) and ok >= quote * len(res)
        proben[s] = {"skill": s, "geschafft": geschafft, "treffer": ok, "partien": len(res), "wellen": wellen,
                     "von": int(res[0]["wellen"]) if res else 0}
        log.write(json.dumps(dict(proben[s], modus=modus, schwierigkeit=diff, aufstieg=asc, ziel=ziel)) + "\n")
        log.flush()
        print("  %-12s %-7s Skill %5.1f: %d/%d erreichen %s, Wellen %s" % (modus, diff + (" +%d" % asc if asc else ""),
              s, ok, len(res), ziel, wellen), flush=True)
        return geschafft

    if not teste(100.0):
        return None, proben
    lo, hi = 0.0, 100.0
    for _ in range(int(a["schritte"])):
        mid = round((lo + hi) / 2.0, 1)
        if teste(mid):
            hi = mid
        else:
            lo = mid
    return (lo, hi), proben


def main():
    a = args_lesen(sys.argv[1:])
    os.makedirs("/tmp/gemtd-testlauf", exist_ok=True)
    zeilen = []
    with open(a["aus"], "a") as log:
        for modus in a["modi"]:
            for diff in a["schwierigkeiten"].split(","):
                for asc in [int(x) for x in a["aufstiege"].split(",")]:
                    if asc and diff != "schwer":
                        continue
                    span, proben = bisektion(a, modus, diff, asc, log)
                    beste = max((max(p["wellen"]) for p in proben.values() if p["wellen"]), default=0)
                    von = max((p["von"] for p in proben.values()), default=0)
                    if span is None:
                        text = "über 100 (bester Bot schafft %s nicht, beste Welle %d/%d)" % (a["ziel"], beste, von)
                    else:
                        text = "%g (zwischen %g und %g)" % (span[1], span[0], span[1])
                    name = diff + (" +%d" % asc if asc else "")
                    print("MINDEST %-12s %-9s %s" % (modus, name, text), flush=True)
                    zeilen.append((modus, name, text, sorted(proben.values(), key=lambda p: p["skill"])))
    if a["md"]:
        with open(a["md"], "w") as f:
            f.write("# Mindest-Skill (Ziel %s, Seeds %s, Quote %s)\n\n" % (a["ziel"], a["seeds"], a["quote"]))
            f.write("| Modus | Schwierigkeit | Mindest-Skill | Proben (Skill: Wellen) |\n|---|---|---|---|\n")
            for modus, name, text, proben in zeilen:
                pr = "; ".join("%g: %s" % (p["skill"], "/".join(str(w) for w in p["wellen"])) for p in proben)
                f.write("| %s | %s | %s | %s |\n" % (modus, name, text, pr))
        print("Bericht:", a["md"])


if __name__ == "__main__":
    main()
