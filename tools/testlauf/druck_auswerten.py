#!/usr/bin/env python3
"""Wertet die Druckkurven aus (tools/druckkurve.sh): je Modus die Schwierigkeitsleiter (Druck pro Startleben,
relativ zu Mittel) und Ausreißer-Wellen (deutlich mehr effektive Leben als der Trend der Nachbarwellen).
Aufruf: python3 tools/testlauf/druck_auswerten.py [druck.jsonl] [--md=bericht.md] [--faktor=1.6]
Exit 1, wenn eine Stufe nicht mehr Druck hat als die davor (Einfach < Mittel < Schwer < Schwer +N)."""
import json, math, sys

NAMEN = {"gemtd": "GemTD", "eevetd": "eeveTD", "shoppingmaul": "Shopping Maul", "randgruppen": "Randgruppen TD", "youtd": "YouTD"}
REIHE = {"einfach": 0, "mittel": 1, "schwer": 2}


def stufe(r):
    return (REIHE.get(r["schwierigkeit"], 1), int(r.get("aufstieg", 0)))


def name(r):
    a = int(r.get("aufstieg", 0))
    return r["schwierigkeit"].capitalize() + (f" +{a}" if a else "")


def art(w):
    return w.get("art") or ("luft" if w["luft"] > 0 else "boden")


def ausreisser(wellen, faktor, nachbarn=2):
    """Wellen, deren effektive Leben über faktor × geometrischem Mittel der nächsten Wellen derselben Art liegen
    (je bis zu `nachbarn` davor und danach; Boss mit Boss, Luft mit Luft, Masse mit Masse)."""
    out = []
    for i, w in enumerate(wellen):
        gleich = [j for j, x in enumerate(wellen) if j != i and art(x) == art(w) and x["ehp"] > 0]
        vor = [j for j in gleich if j < i][-nachbarn:]
        nach = [j for j in gleich if j > i][:nachbarn]
        ref = [wellen[j]["ehp"] for j in vor + nach]
        if len(ref) < 2 or w["ehp"] <= 0:
            continue
        trend = math.exp(sum(math.log(v) for v in ref) / len(ref))
        if w["ehp"] > faktor * trend:
            out.append((i + 1, w["ehp"] / trend))
    return out


def leiter(runs):
    """Fehler, wenn eine Stufe nicht mehr Druck pro Startleben hat als die vorige (sortiert nach Stufe)."""
    fehler = []
    rs = sorted(runs, key=stufe)
    for a, b in zip(rs, rs[1:]):
        if b["druck_pro_leben"] <= a["druck_pro_leben"]:
            fehler.append(f"{name(b)} ({b['druck_pro_leben']}) nicht schwerer als {name(a)} ({a['druck_pro_leben']})")
    return fehler


def main():
    pfad = "/tmp/gemtd-druck/druck.jsonl"
    md = None
    faktor = 1.6
    for a in sys.argv[1:]:
        if a.startswith("--md="):
            md = a[5:]
        elif a.startswith("--faktor="):
            faktor = float(a[9:])
        elif not a.startswith("--"):
            pfad = a
    runs = [json.loads(l) for l in open(pfad) if l.strip()]
    out, fehler_ges = [], []
    for modus, titel in NAMEN.items():
        rs = sorted((r for r in runs if r["modus"] == modus), key=stufe)
        if not rs:
            continue
        mittel = next((r for r in rs if stufe(r) == (1, 0)), rs[0])
        out.append(f"\n### {titel} ({len(mittel['wellen'])} Wellen)\n")
        out.append("| Stufe | Startleben | Effektive Gegner-Leben gesamt | Druck pro Leben | relativ zu Mittel |")
        out.append("|---|---:|---:|---:|---:|")
        for r in rs:
            rel = r["druck_pro_leben"] / max(mittel["druck_pro_leben"], 1)
            out.append(f"| {name(r)} | {r['leben_start']:g} | {r['summe_ehp']:,} | {r['druck_pro_leben']:,} | {rel:.2f} |".replace(",", "."))
        f = leiter(rs)
        fehler_ges += [f"{titel}: {x}" for x in f]
        out.append("\nLeiter: " + ("OK" if not f else "FEHLER – " + "; ".join(f)))
        spitzen = ausreisser(mittel["wellen"], faktor)
        if spitzen:
            out.append(f"Ausreißer auf Mittel (> {faktor:g}× Trend der Nachbarwellen gleicher Art): "
                       + ", ".join(f"W{i} {art(mittel['wellen'][i - 1])} ({x:.1f}×)" for i, x in spitzen))
        else:
            out.append("Keine Ausreißer-Wellen auf Mittel.")
    text = "\n".join(out)
    print(text)
    if md:
        open(md, "w").write(text + "\n")
    print("\nLEITER " + ("OK" if not fehler_ges else "FEHLER (%d)" % len(fehler_ges)))
    sys.exit(1 if fehler_ges else 0)


if __name__ == "__main__":
    main()
