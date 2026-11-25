#!/usr/bin/env python3
"""Wertet die Testläufe aus (tools/testlauf.sh): je Modus, Schwierigkeit (+Aufstieg) und Bot-Stufe/Skill Siege, erreichte
Welle, wo Leben verloren gehen und wie knapp es vorher war (messung.gd: Weg-Anteil des vordersten Gegners je Welle).
Aufruf: python3 tools/testlauf/auswerten.py [ergebnisse.jsonl] [--md=datei.md] [--gruppe=rasse|filiale] [--knapp=0.9]
Spalte „Erste knappe Welle“: erste Welle, in der ein Gegner mindestens --knapp des Wegs schaffte (Median der Läufe);
„Puffer“: wie viele Wellen zwischen der ersten knappen Welle und dem Ende lagen (klein = kippt plötzlich)."""
import json, sys, statistics
from collections import defaultdict

STUFEN = {1: "Gelegenheit", 2: "Solide", 3: "Gut", 4: "Sehr gut"}
REIHE = {"einfach": 0, "mittel": 1, "schwer": 2}


def schwierigkeit(r):
    a = int(r.get("aufstieg", 0))
    return r.get("schwierigkeit", "mittel").capitalize() + (f" +{a}" if a else "")


def diff_key(r):
    return (REIHE.get(r.get("schwierigkeit", "mittel"), 1), int(r.get("aufstieg", 0)))


def erste_knappe(r, grenze):
    for i, k in enumerate(r.get("knapp", [])):
        if float(k) >= grenze:
            return i + 1
    return None
NAMEN = {"gemtd": "GemTD", "eevetd": "eeveTD", "shoppingmaul": "Shopping Maul", "randgruppen": "Randgruppen TD", "youtd": "YouTD",
         "survivors": "Tower Survivors", "bollwerk": "Bollwerk"}


def bot_name(r):
    """Spalte Bot: feste Stufe, Spielstärke (--skill) und ggf. Checkpoint."""
    t = f"Skill {r['skill']:g}" if "skill" in r else f"{r['stufe']} {STUFEN.get(r['stufe'], '')}"
    if r.get("checkpoint"):
        t += f" ab W{r['checkpoint']}"
    return t


def bot_key(r):
    return (1 if "skill" in r else 0, float(r.get("skill", r.get("stufe", 0))), int(r.get("checkpoint", 0)))


def main():
    pfad = "/tmp/gemtd-testlauf/ergebnisse.jsonl"
    md = None
    gruppe = None
    grenze = 0.9
    for a in sys.argv[1:]:
        if a.startswith("--knapp="):
            grenze = float(a[8:])
            continue
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
        key = (r["modus"], diff_key(r), bot_key(r), r.get(gruppe, "") if gruppe else "")
        by[key].append(r)
    for modus in NAMEN:
        keys = sorted(k for k in by if k[0] == modus)
        if not keys:
            continue
        out.append(f"\n### {NAMEN[modus]}\n")
        out.append("| Schwierigkeit | Bot | Gruppe | Läufe | Siege | Welle (Median, min–max) | Erste knappe Welle | Puffer | "
                   "Leben am Ende (Ø) | Teuerste Wellen (verlorene Leben gesamt) |")
        out.append("|---|---|---|---:|---:|---|---:|---:|---:|---|")
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
            ek = [e for e in (erste_knappe(r, grenze) for r in rs) if e is not None]
            ek_txt = f"{statistics.median(ek):g}" if ek else "–"
            puffer = [r["welle"] - e for r, e in ((r, erste_knappe(r, grenze)) for r in rs) if e is not None]
            pf_txt = f"{statistics.median(puffer):g}" if puffer else "–"
            out.append(f"| {schwierigkeit(rs[0])} | {bot_name(rs[0])} | {k[3]} | {len(rs)} | "
                       f"{sum(1 for r in rs if r['sieg'])} | "
                       f"{statistics.median(wellen):g} ({min(wellen)}–{max(wellen)}) von {rs[0]['wellen']} | {ek_txt} | {pf_txt} | "
                       f"{statistics.mean(float(r['leben']) for r in rs):.0f} von {rs[0]['leben_start']} | {tt} |")
    text = "\n".join(out)
    print(text)
    if md:
        open(md, "w").write(text + "\n")


if __name__ == "__main__":
    main()
