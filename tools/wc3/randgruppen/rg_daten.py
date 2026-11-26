"""Erzeugt die Daten von Randgruppen TD aus der ausgelesenen Karte (Randgruppen TD2 UltraMods, Fan-Mod von vers.2b).

    python3 -I tools/wc3/randgruppen/rg_daten.py [recherche-ordner]

Quelle (Standard): /mnt/project-files/konzepte/recherche-stand/randgruppen/ mit objects.json, script.j und
war3map.wpm (siehe tools/wc3/README.md). Schreibt:
  data/randgruppen.json       Regeln, Rassen, Level, Schwierigkeiten, Schadenstabelle, Spawns je Bahn
  data/towers/rg_*.json       77 Tower der 11 Rassen
  data/enemies/rg_*.json      35 Gegner (ein Typ je Level)
  data/maps/randgruppen.json  Karte (168 x 168 Felder) mit 9 Zonen und 14 Bahnen

Alle Namen sind neu (Tabellen NAMES, RACES, ENEMIES unten): Die Karte arbeitet mit Klischees über Herkunft,
Sexualität und Krankheiten, Nazi-Figuren und echten Personen; nichts davon kommt ins Spiel. Die Werte stammen
unverändert aus der Karte, verbunden über die WC3-ID ("wc3"). Siehe docs/randgruppentd.md.

Werte in WC3-Einheiten werden umgerechnet: 128 Einheiten = 1 Towerbreite (2 Felder).
"""
import json
import re
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "modelle"))
from tower_look import look  # noqa: E402  Modelle aus data/tower_models.json

ROOT = Path(__file__).resolve().parents[3]
ELEMENTS = json.loads((ROOT / "data/fx/tower_elements.json").read_text(encoding="utf-8"))
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/mnt/project-files/konzepte/recherche-stand/randgruppen")
U = 128.0  # WC3-Einheiten pro Towerbreite

objects = json.load(open(SRC / "objects.json"))
UNITS = {u["id"]: u["mods"] for u in objects["w3u"]}
SCRIPT = (SRC / "script.j").read_text(encoding="utf-8", errors="replace")

# Werte des WC3-Grundtyps (Orc-Wachturm), wo die Karte nichts einträgt. Abklingzeit 0 heißt in WC3 „so schnell
# wie die Animation“; das sind die Endtower mit ca. 0,3 s.
DEFAULT = {"ua1b": 12, "ua1d": 1, "ua1s": 3, "ua1c": 0.6, "ua1r": 800, "ugol": 110, "ua1t": "pierce"}
FAST_COOLDOWN = 0.3
SELL = 0.75

# --- Neue Namen ----------------------------------------------------------------------------------------------
# Rassen in der Reihenfolge des Startfensters: WC3-ID des Baumeisters -> Name, Farbe, Kurzbeschreibung
RACES = [
    ("u001", "schnaeppchen", "Schnäppchenjäger", "#e8c440", "Masse statt Klasse: extrem billige Tower, viele davon."),
    ("u002", "spaetkauf", "Spätkauf", "#ff8a3d", "Alles aus dem Kiosk um die Ecke: viel Flächenschaden, teuer und stark."),
    ("u003", "kleingarten", "Kleingartenverein", "#5cc85c", "Solide Allrounder, Flächenschaden und ein Rasensprenger, der verlangsamt."),
    ("u004", "theater", "Laientheater", "#d070ff", "Große Reichweite, verlangsamt und vergiftet die Gegner."),
    ("u005", "senioren", "Seniorenklub", "#c8b8a0", "Schwacher Start, starke späte Tower mit Flächenschaden."),
    ("u006", "zocker", "Zocker", "#40d0ff", "Schnelle Angriffe auf kurze Distanz, Gift gegen zähe Gegner."),
    ("u007", "buero", "Bürohengste", "#8ca0c0", "Teure Spezialisten: Gift auf lange Distanz, Dauerfeuer mit Fläche."),
    ("u000", "ritter", "Ritterspiele", "#c06040", "Nahkämpfer mit hohem Schaden, ein Gralsritter mit Gift."),
    ("u008", "hiphop", "Hip-Hop-Crew", "#ff5aa0", "Zauber- und Heldenschaden, eine Bassbox mit riesigem Treffer."),
    ("u00B", "wg", "Studenten-WG", "#7ad0a0", "Große Reichweite, Gift und eine Professorin mit Flächenschaden."),
    ("n016", "zirkus", "Wanderzirkus", "#ffd060", "Flächenschaden fast überall, eine Eisläuferin, die verlangsamt (aus dem UltraMods-Zusatz)."),
]
# Eigene Rassen ohne Vorbild in der Karte (Wunsch von Lukas, 2026-10-27), Werte an der Preiskurve der anderen
# ausgerichtet: (id, Name, Farbe, Kurzbeschreibung, [(Name, Preis, Schaden von, bis, Abklingzeit, Reichweite in
# Towerbreiten, Schadensart, Fähigkeiten), …]; der letzte ist der Endtower (1 Holz).
SPLASH = lambda r, f=0.5: {"type": "splash", "radius": r, "factor": f}
SLOW = lambda f, d: {"type": "slow", "factor": f, "duration": d}
POISON = lambda dps, d=4.0: {"type": "poison", "dps": dps, "duration": d}
OWN_RACES = [
    ("punks", "Punks", "#9bff2a", "Laut, dreckig, Flächenschaden: Dosen, Pogo und eine Garagenband, die alles verlangsamt.", [
        ("Nietenjacke", 12, 15, 19, 0.8, 6.25, "pierce", []),
        ("Dosenwerfer", 40, 30, 42, 1.0, 6.25, "siege", [SPLASH(0.94)]),
        ("Pogo-Tänzer", 95, 70, 90, 0.45, 3.5, "normal", [SPLASH(0.8)]),
        ("Sicherheitsnadel", 140, 90, 120, 0.6, 7.4, "pierce", [POISON(6.0)]),
        ("Iro-Kommando", 220, 140, 170, 0.5, 6.25, "chaos", []),
        ("Garagenband", 420, 260, 300, 0.6, 7.8, "magic", [SPLASH(1.5, 0.6), SLOW(0.25, 3.0)]),
        ("Die Hausbesetzung", 800, 851, 950, 0.3, 23.438, "chaos", []),
    ]),
    ("emos", "Emos", "#c03aa0", "Große Reichweite, viel Gift und Verlangsamung: der Weltschmerz zermürbt jeden Gegner.", [
        ("Ponyfranse", 10, 14, 18, 0.9, 7.8, "magic", []),
        ("Tagebuchschreiber", 45, 24, 30, 1.0, 10.9, "normal", [SLOW(0.25, 4.0)]),
        ("Eyeliner-Profi", 90, 70, 95, 0.8, 9.4, "pierce", [POISON(5.0)]),
        ("Mixtape", 140, 95, 120, 0.7, 7.4, "spells", [SPLASH(0.94)]),
        ("Regenwolke", 230, 150, 190, 0.7, 8.6, "magic", [SPLASH(1.2), SLOW(0.35, 3.0)]),
        ("Weltschmerz", 380, 280, 330, 0.55, 9.4, "chaos", [POISON(8.0)]),
        ("Das Konzert in Schwarz", 780, 851, 950, 0.3, 23.438, "chaos", []),
    ]),
]
# Wie verschmiert die Oberfläche bei welcher Rasse aussieht (RgVandal): Stil und Stärke 0–3.
LOOKS = {
    "hiphop": {"style": "graffiti", "vandal": 3}, "punks": {"style": "punk", "vandal": 3},
    "emos": {"style": "emo", "vandal": 3}, "wg": {"style": "graffiti", "vandal": 1},
    "zocker": {"style": "graffiti", "vandal": 1}, "spaetkauf": {"style": "graffiti", "vandal": 1},
}

# Tower: WC3-ID -> Name
NAMES = {
    "o001": "Wühltisch-Kunde", "o01K": "Coupon-Sammler", "o002": "Sperrmüll-Sammler", "o01M": "Flohmarkt-Profi",
    "o004": "Ramschhändler", "o006": "Schlussverkauf-Stürmer", "o005": "Mister Sonderpreis",
    "o007": "Brausepulver", "o008": "Grillanzünder", "o009": "Zuckerschock", "o00A": "Leuchtreklame",
    "o00B": "Energydrink", "o00C": "Dreifach-Espresso", "o00D": "Der Kioskkönig",
    "o016": "Gartenzwerg", "o000": "Heckenschneider", "o01L": "Hochsitz", "o01N": "Vereinswart",
    "o003": "Vereinsheim", "o01O": "Rasensprenger", "o01P": "Der Obmann",
    "o00L": "Statist", "o00M": "Kühler Kritiker", "o00N": "Intrigantin", "o00O": "Stepptänzer",
    "o00P": "Bühnennebel", "o00Q": "Der Regisseur", "o00R": "Der Star",
    "o00S": "Frührentner", "o00T": "Gehstock-Schwinger", "o00U": "Rollator-Raser", "o00V": "Kaffeekränzchen",
    "o00W": "Bingo-Runde", "o00X": "Kurschatten", "o00Y": "Der Stammtisch-Präsident",
    "o010": "Konsolenkind", "o011": "Rollenspieler", "o012": "Strategie-General", "o015": "Shooter-Profi",
    "o014": "Ruhestörer", "o013": "Hack-and-Slay-Fan", "o00Z": "Der Clanchef",
    "o01Q": "Pförtner", "o01R": "Praktikant", "o01S": "Abteilungsleiter", "o01T": "Vorstandsetage",
    "o01V": "Börsenhai", "o01W": "Alleinunterhalter", "o01U": "Der Aufsichtsrat",
    "o01D": "Steinschleuder", "o00F": "Knappe", "o00G": "Raufbold", "o00H": "Gralsritter",
    "o00I": "Burgtor", "o026": "Der Burgherr", "o00K": "Der Ritterkönig",
    "o01Y": "Reimschmied", "o01Z": "Freestyler", "o020": "Beatboxer", "o021": "Battle-Rapper",
    "o022": "Die Cypher", "o00J": "Bassbox", "o023": "Das Label",
    "o024": "Erstsemester", "o025": "WG-Party", "o027": "Bibliotheksratte", "o028": "Klimaaktivistin",
    "o029": "Die Professorin", "o02A": "Die Abschlussfeier",
    "h002": "Jongleur", "u00C": "Schlangenbeschwörer", "n012": "Kanonenkugel-Mann", "e001": "Trapezkünstlerin",
    "n013": "Eisläuferin", "n014": "Dompteur", "n015": "Der Zirkusdirektor",
}
# Gegner je Level: Typ aus der Karte -> Name (die „Spießer“, die die Hochburg der Toleranz stürmen)
ENEMIES = {
    "n002": "Gartenzaun-Nörgler", "n001": "Ruhestörungs-Melder", "n003": "Falschparker-Petze",
    "n004": "Kehrwochen-Kontrolleur", "n005": "Nachbarschafts-Drohne", "n006": "Hausmeister",
    "n007": "Treppenhaus-Wächter", "n008": "Vereinsmeier", "n009": "Paragraphenreiter",
    "n00A": "Tratsch-Taube", "n00B": "Bürokrat", "n00C": "Leserbrief-Schreiber", "n00D": "Ordnungshüter",
    "n00E": "Mittagsruhe-Wächter", "n00F": "Spähballon", "n00G": "Besserwisser", "n00H": "Beschwerde-Profi",
    "n00J": "Bedenkenträger", "n00K": "Spießbürger", "n00L": "Überwachungs-Drohne", "n00M": "Moralapostel",
    "n00N": "Hecken-Inspektor", "n00O": "Satzungs-Hüter", "n00P": "Stammtisch-Schreier",
    "n00Q": "Geizhals-Luftschiff", "n00I": "Sturkopf", "n00R": "Prinzipienreiter", "n00S": "Ewiggestriger",
    "n00T": "Obernörgler", "n00W": "Tratsch-Satellit", "n00X": "Hardliner", "n00Y": "Hetzer",
    "n00Z": "Wutbürger", "n010": "Der Scharfmacher", "n00U": "Der Oberspießer",
}
DIFFICULTIES = [("Gemütlich", 50), ("Locker", 35), ("Normal", 25), ("Hart", 10), ("Perfekt", 1)]

# WC3-Schadenstabelle (bis Patch 1.28): Angriffsart -> Rüstungsart
ARMOR = ["small", "medium", "large", "fort", "normal", "hero", "divine", "none"]
TABLE = {
    "normal": [1.0, 1.5, 1.0, 0.7, 1.0, 1.0, 0.05, 1.0],
    "pierce": [2.0, 0.75, 1.0, 0.35, 1.0, 0.5, 0.05, 1.5],
    "siege": [1.0, 0.5, 1.0, 1.5, 1.0, 0.5, 0.05, 1.5],
    "magic": [1.25, 0.75, 2.0, 0.35, 1.0, 0.5, 0.05, 1.0],
    "chaos": [1.0] * 8,
    "spells": [1.0, 1.0, 1.0, 1.0, 1.0, 0.7, 0.05, 1.0],
    "hero": [1.0, 1.0, 1.0, 0.5, 1.0, 1.0, 0.05, 1.0],
}
# Fähigkeiten der Tower (WC3-Fähigkeit -> unsere); Werte der WC3-Standardfähigkeiten, gerundet
ABIL = {
    "Afrb": [{"type": "slow", "factor": 0.25, "duration": 3.0}],   # Frostatem
    "Afra": [{"type": "slow", "factor": 0.25, "duration": 5.0}],   # Frostangriff
    "Aspo": [{"type": "slow", "factor": 0.5, "duration": 4.0}, {"type": "poison", "dps": 4.0, "duration": 4.0}],
    "Aven": [{"type": "poison", "dps": 4.0, "duration": 4.0}],      # vergiftete Speere
    "ACvs": [{"type": "poison", "dps": 5.0, "duration": 4.0}],      # vergiftete Waffen
}
# Stadthäuser aus assets/models/city/ (CC0) nach Platz in der Rasse, wenn data/tower_models.json nichts Passendes hat
MODELS = ["1story", "1story_sign", "2story", "2story_balcony", "3story_balcony", "4story_center", "6story_stack"]


def r(v):
    return round(float(v) / U, 3)


def val(m, k):
    v = m.get(k)
    return DEFAULT.get(k) if v in (None, "") else v


def slug(name):
    s = name.lower()
    for a, b in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        s = s.replace(a, b)
    return "rg_" + re.sub(r"[^a-z0-9]+", "_", s).strip("_")


TOWER_ID = {uid: slug(n) for uid, n in NAMES.items()}


def splash(m):
    if m.get("ua1w") != "msplash":
        return []
    radius = float(m.get("ua1h") or m.get("ua1q") or m.get("ua1f") or 0)
    if radius <= 0:
        radius = 60.0  # Flächenangriff ohne eigenen Radius: WC3-Standard
    return [{"type": "splash", "radius": r(radius), "factor": float(m.get("uhd1", 0.5))}]


def tower_json(uid, races, place, ultimate, requires):
    m = UNITS[uid]
    base = float(val(m, "ua1b"))
    dice = float(val(m, "ua1d"))
    sides = float(val(m, "ua1s"))
    cd = float(val(m, "ua1c"))
    abilities = splash(m)
    for a in str(m.get("uabi", "")).split(","):
        abilities += ABIL.get(a, [])
    targets = str(m.get("ua1g") or "air,ground")
    first = races[0]
    return {
        "id": TOWER_ID[uid],
        "name": NAMES[uid],
        "category": "randgruppen",
        "color": first[3],
        "model": "res://assets/models/city/%s.glb" % MODELS[place],
        "model_tint": False,
        "model_solid": True,
        "model_scale": 0.42 + 0.03 * place,
        "damage_type": str(val(m, "ua1t")),
        "targets": "both" if "air" in targets and "ground" in targets else ("air" if "air" in targets else "ground"),
        "rg": {
            "races": [x[1] for x in races],
            "place": place,
            "cost": int(val(m, "ugol")),
            "lumber": int(m.get("ulum") or 0),
            "ultimate": ultimate,
            "requires": requires,
            "wc3": uid,
        },
        "tiers": [{
            "damage": [base + dice, base + dice * sides],
            "range": r(val(m, "ua1r")),
            "cooldown": FAST_COOLDOWN if cd <= 0 else cd,
            "abilities": abilities,
        }],
    }


def levels():
    """Level aus dem Auslöser Set Levels: Gegnertyp und Anzahlen (bleiben bis zur nächsten Änderung gleich)."""
    cond = dict(re.findall(r"function (Trig_Set_Levels_Func\d+)\s+takes nothing\s+returns boolean\s+"
                           r"return \( udg_Level_Number == (\d+) \)", SCRIPT))
    a = SCRIPT.index("function Trig_Set_Levels_Actions takes")
    body = SCRIPT[a:SCRIPT.index("endfunction", a)]
    out, cur = {}, None
    for line in body.split("\n"):
        line = line.strip()
        mm = re.match(r"if \( (Trig_Set_Levels_Func\d+)\(\) \) then", line)
        if mm:
            cur = int(cond[mm.group(1)])
            out.setdefault(cur, {})
            continue
        mm = re.match(r"set udg_(Monster_\w+) = (.*)", line)
        if mm and cur is not None:
            out[cur][mm.group(1)] = mm.group(2).strip("'\"")
        if line == "endif":
            cur = None
    counts = {"main": 0, "two": 0, "three": 0, "four": 0}
    keys = {"Monster_Amount": "main", "Monster_Amount_Two": "two", "Monster_Amount_Three": "three", "Monster_Amount_Four": "four"}
    res = []
    for lv in sorted(out):
        for k, v in out[lv].items():
            if k in keys:
                counts[keys[k]] = int(v)
        res.append({"level": lv, "enemy": out[lv]["Monster_Type"], "counts": dict(counts)})
    return res


def enemy_json(uid, level):
    m = UNITS[uid]
    flying = m.get("umvt") == "fly"
    return {
        "id": slug(ENEMIES[uid]),
        "name": ENEMIES[uid],
        "category": "randgruppen",
        "hp": int(m.get("uhpm") or 100),
        "speed": r(m.get("umvs") or 270),
        "armor": float(m.get("udef") or 0),
        "armor_type": "rg_" + str(m.get("udty") or "medium"),
        "bounty": int(m.get("ubba") or 0) + int(1 if m.get("ubdi") is None else m["ubdi"]) * int(m.get("ubsi") or 1),
        "damage": 1000 if level == 35 else 1,  # der Boss kostet alle Leben
        "flying": flying,
        "boss": level == 35,
        "color": "#d8d0c0",
        "size": 1.6 if level == 35 else 1.0,
        "rg": {"level": level, "wc3": uid},
    }


# --- Karte -----------------------------------------------------------------------------------------------------
RECTS = {n: tuple(map(float, v)) for n, *v in re.findall(
    r"gg_rct_(\w+) = Rect\( ([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+) \)", SCRIPT)}
# Zonen in der Reihenfolge, in der Spieler sie bekommen (Einzelspieler: Rot)
ZONES = [("Rot", "Red_Zone"), ("Gelb", "Yellow_Zone_3"), ("Blau", "Blue_Zone"), ("Türkis", "Teal_Zone"),
         ("Orange", "Orange_Zone_1"), ("Lila", "Purple_Zone_1"), ("Grün", "Green_Zone_1"), ("Rosa", "Pink_Zone_1"),
         ("Hellblau", "LightBlue_Zone")]
# Bahnen: Spawn, Wegpunkte, Spieler (Zone) und welche Anzahl der Level dort erscheint
LEFT = ["Red_Move", "Orange_Move", "Green_Move", "CentreOut"]
RIGHT = ["Yellow_Move", "Purple_Move", "Pink_Move", "CentreOut"]
LANES = [
    ("Red_Left", LEFT, 0, "main"), ("Red_Right", LEFT, 0, "main"),
    ("YellowLeft", RIGHT, 1, "main"), ("YellowRight", RIGHT, 1, "main"),
    ("Blue_Left", ["BlueTeal_Move", "MiddleLeftTurn", "CentreOut"], 2, "main"),
    ("Blue_Right", ["BlueTeal_Move", "MiddleLeftTurn", "CentreOut"], 2, "main+three"),
    ("Teal_Left", ["BlueTeal_Move", "MiddleRightTurn", "CentreOut"], 3, "main+three"),
    ("Teal_Right", ["BlueTeal_Move", "MiddleRightTurn", "CentreOut"], 3, "main"),
    ("OrangeLeft", ["Orange_Move", "Green_Move", "CentreOut"], 4, "two"),
    ("PurpleRight", ["Purple_Move", "Pink_Move", "CentreOut"], 5, "two"),
    ("GreenSpawn", ["GreenSpawn_Move", "Green_Move", "CentreOut"], 6, "four"),
    ("PinkSpawn", ["PinkSpawn_Move", "Pink_Move", "CentreOut"], 7, "four"),
]


def build_map():
    d = (SRC / "war3map.wpm").read_bytes()
    w, h = 384, 384
    o = -6144.0  # Ursprung der Pfadkarte (Karte 96 x 96 Kacheln, je 4 Zellen à 32)

    def cell(x, y):  # x, y Zellen von unten links
        return d[16 + y * w + x]
    # 2 x 2 Zellen = 1 Feld (64 Einheiten); spielbarer Bereich aus w3i-freiem Rand: 6 Kacheln = 24 Zellen
    x0c, y0c, fw = 24, 24, (w - 48) // 2  # 168 Felder
    tiles = []
    for fy in range(fw):
        row = ""
        for fx in range(fw):
            cx, cy = x0c + fx * 2, y0c + (fw - 1 - fy) * 2
            fl = [cell(cx + i, cy + j) for i in (0, 1) for j in (0, 1)]
            if any(f & 0x02 for f in fl):
                row += "#"
            elif any(f & 0x08 for f in fl):
                row += "_"
            else:
                row += "."
        tiles.append(list(row))

    def to_field(wx, wy):
        return [int((wx - o) / 64) - x0c // 2, fw - 1 - (int((wy - o) / 64) - y0c // 2)]

    def center(name):
        a, b, c, e = RECTS[name]
        return to_field((a + c) / 2, (b + e) / 2)

    def rect(name):
        a, b, c, e = RECTS[name]
        p, q = to_field(a, e), to_field(c, b)
        return [p[0], p[1], q[0] - p[0] + 1, q[1] - p[1] + 1]
    # Nur was von den Spawns aus erreichbar ist, bleibt begehbar (die Ränder sind Wege der fliegenden Baumeister)
    seen = set()
    todo = deque(tuple(center(n)) for n, *_ in LANES)
    while todo:
        x, y = todo.popleft()
        if (x, y) in seen or not (0 <= x < fw and 0 <= y < fw) or tiles[y][x] == "#":
            continue
        seen.add((x, y))
        todo.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    for y in range(fw):
        for x in range(fw):
            if (x, y) not in seen:
                tiles[y][x] = "#"
    lanes = [{"spawn": center(s), "checkpoints": [center(c) for c in cps], "player": p} for s, cps, p, _ in LANES]
    return {
        "format": 2, "id": "randgruppen", "name": "Hochburg der Toleranz", "game": "randgruppen",
        "width": fw, "height": fw, "tiles": ["".join(t) for t in tiles],
        "spawn": lanes[0]["spawn"], "spawn_player": 0, "checkpoints": lanes[0]["checkpoints"],
        "goal": center("Load"), "lanes": lanes[1:],
        "zones": [{"rect": rect(z), "player": i} for i, (_, z) in enumerate(ZONES)],
        "marker_radius": 1, "waves": "classic", "lives": 25, "start_gold": 550,
        "variance": {"random_rocks": 0, "seed": -1},
    }


def main():
    races, towers = [], {}
    for builder, rid, name, color, hint in RACES:
        ids = UNITS[builder]["ubui"].split(",")
        ult = [i for i in ids if int(UNITS[i].get("ulum") or 0) > 0][0]
        rest = [i for i in ids if i != ult]
        # Reihenfolge nach Preis, der Endtower zuletzt
        rest.sort(key=lambda i: int(val(UNITS[i], "ugol")))
        races.append({"id": rid, "name": name, "color": color, "hint": hint, "wc3": builder,
                      "towers": [TOWER_ID[i] for i in rest + [ult]]})
        for place, uid in enumerate(rest + [ult]):
            if uid in towers:
                towers[uid]["rg"]["races"].append(rid)
                continue
            req = [TOWER_ID[i] for i in rest] if uid == ult else []
            towers[uid] = tower_json(uid, [(builder, rid, name, color)], place, uid == ult, req)
    for rid, name, color, hint, tlist in OWN_RACES:
        ids = []
        for place, (tname, cost, lo, hi, cd, rng, dtype, abil) in enumerate(tlist):
            ult = place == len(tlist) - 1
            tid = slug(tname)
            ids.append(tid)
            towers[tid] = {
                "id": tid, "name": tname, "category": "randgruppen", "color": color,
                "model": "res://assets/models/city/%s.glb" % MODELS[place], "model_tint": False, "model_solid": True,
                "model_scale": 0.42 + 0.03 * place, "damage_type": dtype, "targets": "both",
                "rg": {"races": [rid], "place": place, "cost": cost, "lumber": 1 if ult else 0, "ultimate": ult,
                       "requires": ids[:-1] if ult else [], "wc3": ""},
                "tiers": [{"damage": [float(lo), float(hi)], "range": rng, "cooldown": cd, "abilities": abil}],
            }
        races.append({"id": rid, "name": name, "color": color, "hint": hint, "wc3": "", "towers": ids})
    for race in races:
        race["look"] = LOOKS.get(race["id"], {"style": "clean", "vandal": 0})
    lv = levels()
    enemies = {}
    for x in lv:
        enemies[x["enemy"]] = enemy_json(x["enemy"], x["level"])
        x["enemy"] = slug(ENEMIES[x["enemy"]])
    rules = {
        "_comment": "Regeln für Randgruppen TD (Vorbild: Randgruppen TD2 UltraMods, Fan-Mod von vers.2b). Erzeugt von tools/wc3/randgruppen/rg_daten.py, nicht von Hand ändern.",
        "start_gold": 550,
        "builder_cost": 500,
        "sell_factor": SELL,
        "first_pause": 60,
        "pause": 30,
        "level_gold": {"base": 10, "per_level": 2},
        "center_bonus": 0.5,
        "lumber": {"25": 1},
        "difficulties": [{"name": n, "lives": l} for n, l in DIFFICULTIES],
        "difficulty_default": 2,
        "races": races,
        "levels": lv,
        "lane_counts": [k for *_, k in LANES],
        "zones": [n for n, _ in ZONES],
        "boss_level": 35,
        "anti_stuck": {"damage": 10000, "cooldown": 25.0, "until_level": 34},
        "damage_table": {t: {"rg_" + a: f for a, f in zip(ARMOR, v)} for t, v in TABLE.items()},
    }
    out = ROOT / "data"
    for old in (out / "towers").glob("rg_*.json"):
        old.unlink()
    for old in (out / "enemies").glob("rg_*.json"):
        old.unlink()
    for t in towers.values():
        t.update(ELEMENTS.get(t["id"], {}))
        # Passendes Modell aus data/tower_models.json statt Stadthaus (sonst bleibt das Haus)
        m = look("randgruppen", t["id"][3:])
        if m:
            t.update(m)
            t.pop("model_scale", None)
        (out / "towers" / (t["id"] + ".json")).write_text(json.dumps(t, ensure_ascii=False, indent="\t") + "\n")
    for e in enemies.values():
        (out / "enemies" / (e["id"] + ".json")).write_text(json.dumps(e, ensure_ascii=False, indent="\t") + "\n")
    (out / "randgruppen.json").write_text(json.dumps(rules, ensure_ascii=False, indent="\t") + "\n")
    (out / "maps" / "randgruppen.json").write_text(json.dumps(build_map(), ensure_ascii=False, indent="\t") + "\n")
    print("%d Rassen, %d Tower, %d Gegner, %d Level" % (len(races), len(towers), len(enemies), len(lv)))


main()
