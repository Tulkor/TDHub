#!/usr/bin/env python3
"""Wertet die Testläufe aus (tools/testlauf.sh): je Modus und Bot-Stufe Siege, erreichte Welle und wo Leben verloren gehen.
Aufruf: python3 tools/testlauf/auswerten.py [ergebnisse.jsonl] [--md=datei.md] [--gruppe=rasse|filiale]"""
import json, sys, statistics
from collections import defaultdict

STUFEN = {1: "Gelegenheit", 2: "Solide", 3: "Gut", 4: "Sehr gut"}
NAMEN = {"gemtd": "GemTD", "eevetd": "eeveTD", "shoppingmaul": "Shopping Maul", "randgruppen": "Randgruppen TD", "youtd": "YouTD"}


def main():
    pfad = "/tmp/gemtd-testlauf/ergebnisse.jsonl"
    md = None
    gruppe = None
    for a in sys.argv[1:]:
        if a.startswith("--md="):
            md = a[5:]
        elif a.startswith("--gruppe="):
            gruppe = a[9:]
        else:
            pfad = a
    runs = [json.loads(l) for l in open(pfad) if l.strip()]
    out = []
    by = defaultdict(list)
    for r in runs:
        key = (r["modus"], r["stufe"], r.get(gruppe, "") if gruppe else "")
        by[key].append(r)
    for modus in NAMEN:
        keys = sorted(k for k in by if k[0] == modus)
        if not keys:
            continue
        out.append(f"\n### {NAMEN[modus]}\n")
        out.append("| Bot | Gruppe | Läufe | Siege | Welle (Median, min–max) | Leben am Ende (Ø) | Teuerste Wellen (verlorene Leben gesamt) |")
        out.append("|---|---|---:|---:|---|---:|---|")
        for k in keys:
            rs = by[k]
            wellen = [r["welle"] for r in rs]
            loss = defaultdict(float)
            by_type = defaultdict(float)
            for r in rs:
                typen = r.get("typen", [])
                for i, v in enumerate(r.get("verluste", [])):
                    loss[i] += float(v)
                    if i < len(typen) and float(v) > 0:
                        by_type[str(typen[i])] += float(v)
            top = sorted(((v, i) for i, v in loss.items() if v > 0), reverse=True)[:4]
            tt = ", ".join(f"W{i + 1}: {v:g}" for v, i in top)
            if by_type:
                tt += " · nach Typ: " + ", ".join(f"{t} {v:g}" for t, v in sorted(by_type.items(), key=lambda x: -x[1]))
            out.append(f"| {k[1]} {STUFEN.get(k[1], '')} | {k[2]} | {len(rs)} | {sum(1 for r in rs if r['sieg'])} | "
                       f"{statistics.median(wellen):g} ({min(wellen)}–{max(wellen)}) von {rs[0]['wellen']} | "
                       f"{statistics.mean(float(r['leben']) for r in rs):.0f} von {rs[0]['leben_start']} | {tt} |")
    text = "\n".join(out)
    print(text)
    if md:
        open(md, "w").write(text + "\n")


if __name__ == "__main__":
    main()
