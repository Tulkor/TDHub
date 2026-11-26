"""Erzeugt die eeveTD-Daten für das Spiel aus der ausgelesenen Karte (eeveTD v1.01).

    python3 -I tools/wc3/eeve/eeve_daten.py [recherche-ordner]

Quelle (Standard): /mnt/project-files/konzepte/recherche-stand/eeve/ mit objects.json und towers.json
(siehe tools/wc3/README.md). Schreibt:
  data/towers/eeve_*.json   Tower der sechs Elemente mit Fallen, Dual-Grundturm und Dual-Tower, dazu die Barrikade
  data/enemies/eeve_*.json  Gegner je Gegnerstufe und die Challenges

Werte in WC3-Einheiten werden umgerechnet: 128 Einheiten = 1 Towerbreite (2 Felder).
Fähigkeiten, die unser Spiel noch nicht kennt, stehen als "todo" in den Daten und wirken noch nicht.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "modelle"))
from tower_look import look  # noqa: E402  Modelle aus data/tower_models.json

ROOT = Path(__file__).resolve().parents[3]
ELEMENTS = json.loads((ROOT / "data/fx/tower_elements.json").read_text(encoding="utf-8"))
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/mnt/project-files/konzepte/recherche-stand/eeve")
U = 128.0  # WC3-Einheiten pro Towerbreite

objects = json.load(open(SRC / "objects.json"))
UNITS = {u["id"]: u["mods"] for u in objects["w3u"]}
TOWERS = {t["id"]: t for t in json.load(open(SRC / "towers.json"))}

ELEMENTS = {"Nature": "nature", "Earth": "earth", "Fire": "fire", "Storm": "storm", "Magic": "magic", "Water": "water"}
COLORS = {"nature": "#46d160", "earth": "#c08a4a", "fire": "#ff5a2a", "storm": "#7fb2ff", "magic": "#c46bff", "water": "#2fc8e8"}
# Schadensarten heißen in eeve anders als in WC3 (siehe war3mapSkin.txt); unsere Schlüssel in data/eeve.json
DAMAGE = {"chaos": "chaos", "siege": "physical", "hero": "elemental", "normal": "electric", "pierce": "magic", "magic": "magic"}
# Modelle aus dem Crystal Pack je Turmlinie (rein optisch)
MODELS = ["crystal_08", "crystal_11", "crystal_13", "crystal_18", "crystal_19", "crystal_20", "crystal_23", "crystal_24"]
# Passende Modelle aus den CC0-Paketen (assets/models/nature/, tools/modelle/auswahl.json) statt Kristall.
# solid = eigene Farben, undurchsichtig; tint = in Elementfarbe als Glas wie die Kristalle.
# flame = Flamme oben drauf (FlameFx), hit = Treffer-Effekt aus data/fx/hits.json.
N = "res://assets/models/nature/%s.glb"
SOLID = {"model_tint": False, "model_solid": True}
LOOK = {
    "Nature Base Tower": dict(SOLID, model=N % "bush_common_flowers"),
    "Minor Bird Launcher": dict(SOLID, model=N % "pine_5"),
    "Bird Launcher": dict(SOLID, model=N % "pine_2"),
    "Greater Bird Launcher": dict(SOLID, model=N % "pine_1"),
    "Xtreme Bird Launcher": dict(SOLID, model=N % "pine_3"),
    "Wicked Bird Rampage WTF Tower": dict(SOLID, model=N % "common_tree_4"),
    "Thorns Tower": dict(SOLID, model=N % "plant_1"),
    "Itching Thorns Tower": dict(SOLID, model=N % "plant_1_big"),
    "Orb of Life": dict(SOLID, model=N % "common_tree_3", hit_fx="kb_nature_rays"),
    "Sacred Orb of Power": dict(SOLID, model=N % "common_tree_5", hit_fx="kb_nature_rays"),
    "Nonhazardous Shroom Field": dict(SOLID, model=N % "mushroom_common"),
    "Shroom Field": dict(SOLID, model=N % "mushroom_tan_group"),
    "Hazardous Shroom Field": dict(SOLID, model=N % "mushroom_red_group"),
    "Ultra Toxic Shroom Field": dict(SOLID, model=N % "mushroom_laetiporus"),
    "Noxious Tendril Trap": dict(SOLID, model=N % "plant_7"),
    "Magic Mushrooms": dict(SOLID, model=N % "mushroom_red_tall"),
    "Fire Berry Bush": dict(SOLID, model=N % "bush_common", hit_fx="bk_fire"),
    "Thornweed Field": dict(SOLID, model=N % "fern_1"),
    "Gaea Spring": dict(SOLID, model=N % "lily_large"),
    "Camp Fire": dict(SOLID, model=N % "campfire_pit", flame=0.55, flame_height=0.3, hit_fx="bk_fire"),
    "Heat Stakes": dict(SOLID, model=N % "campfire_stones", flame=0.5, flame_height=0.2, hit_fx="bk_fire"),
    "Brazier": dict(SOLID, model=N % "pot_large", flame=0.5, flame_height=0.7, hit_fx="bk_fire"),
    "Blazing Brazier": dict(SOLID, model=N % "pot_large", flame=0.65, flame_height=0.7, hit_fx="bk_fire"),
    "Hell Brazier": dict(SOLID, model=N % "pot_large", flame=0.8, flame_height=0.7, hit_fx="bk_fire"),
    "Searing Totem": dict(model=N % "statue_head", flame=0.45, flame_height=0.95, hit_fx="bk_fire"),
    "Flame Grate": dict(SOLID, model=N % "campfire_bricks", flame=0.35, flame_height=0.2, hit_fx="bk_fire"),
    "Volcano": dict(SOLID, model=N % "rock_tall_e", flame=0.5, flame_height=0.95, hit_fx="bk_explosion"),
    "Earth Base Tower": dict(SOLID, model=N % "rock_medium_1"),
    "Lesser Rock Launcher": dict(SOLID, model=N % "rock_medium_2"),
    "Rock Launcher": dict(SOLID, model=N % "rock_medium_3"),
    "Greater Rock Launcher": dict(SOLID, model=N % "rock_tall_a"),
    "Gold Mine": {"model": "res://assets/models/special/gold_ore.glb", "model_tint": False},
    "Runed Rock": dict(model=N % "stone_tall_g"),
    "Lightning Rock Elemental": dict(model=N % "stone_tall_a", hit_fx="kb_shock_ring"),
    "Ultra FFS Mega Power Totem": dict(model=N % "statue_head"),
    "Ruinous Obelisk": dict(model=N % "statue_column_damaged", hit_fx="kb_magic_ring"),
    "Enchanted Obelisk": dict(model=N % "statue_obelisk", hit_fx="kb_magic_ring"),
    "Ornate Obelisk": dict(model=N % "statue_column", hit_fx="kb_magic_ring"),
    "Runed Obelisk": dict(model=N % "statue_obelisk", hit_fx="kb_magic_ring"),
    "Glowing Engraved Obelisk of Ultimate Pwnage": dict(model=N % "statue_obelisk", hit_fx="kb_magic_ring"),
    "Arcane Shrine": dict(model=N % "statue_ring", hit_fx="kb_magic_ring"),
    "Altar of Magic": dict(model=N % "statue_block", hit_fx="kb_magic_ring"),
    "Scaring Statue of Corruption": dict(model=N % "statue_head"),
    "Stone of Wisdom": dict(model=N % "stone_tall_g"),
}
# Treffer für Sturm-Tower ohne eigenes Modell (Kristalle bleiben)
STORM_HIT = "kb_shock_ring"

NAMES = {
    "Barricade": "Barrikade",
    "Nature Base Tower": "Natur-Grundturm", "Earth Base Tower": "Erd-Grundturm", "Fire Base Tower": "Feuer-Grundturm",
    "Storm Base Tower": "Sturm-Grundturm", "Magic Base Tower": "Magie-Grundturm", "Water Base Tower": "Wasser-Grundturm",
    "Thorns Tower": "Dornenturm", "Itching Thorns Tower": "Juckender Dornenturm",
    "Orb of Life": "Kugel des Lebens", "Sacred Orb of Power": "Heilige Kugel der Macht",
    "Minor Bird Launcher": "Kleiner Vogelwerfer", "Bird Launcher": "Vogelwerfer", "Greater Bird Launcher": "Großer Vogelwerfer",
    "Xtreme Bird Launcher": "Xtremer Vogelwerfer", "Wicked Bird Rampage WTF Tower": "Wilder Vogelrausch-WTF-Turm",
    "Nonhazardous Shroom Field": "Harmloses Pilzfeld", "Shroom Field": "Pilzfeld", "Hazardous Shroom Field": "Gefährliches Pilzfeld",
    "Ultra Toxic Shroom Field": "Ultragiftiges Pilzfeld",
    "Weak Pyramide": "Schwache Pyramide", "Pyramide": "Pyramide", "Mighty Pyramide": "Mächtige Pyramide", "Ancient Pyramide": "Uralte Pyramide",
    "Small Geyser": "Kleiner Geysir", "Geyser": "Geysir", "Crater": "Krater", "Deep Crater": "Tiefer Krater",
    "Ultra FFS Mega Power Totem": "Ultra-FFS-Mega-Power-Totem",
    "Lesser Rock Launcher": "Kleiner Steinwerfer", "Rock Launcher": "Steinwerfer", "Greater Rock Launcher": "Großer Steinwerfer",
    "Gold Mine": "Goldmine", "Diamond Mine": "Diamantmine",
    "Area Roaster": "Flächenröster", "Area Melter": "Flächenschmelzer",
    "Heat Stakes": "Hitzepfähle", "Searing Totem": "Sengendes Totem", "Scorched Rune": "Versengte Rune",
    "Rune of Incineration": "Rune der Einäscherung",
    "Camp Fire": "Lagerfeuer", "Brazier": "Kohlenbecken", "Blazing Brazier": "Loderndes Kohlenbecken", "Hell Brazier": "Höllenbecken",
    "Ultra Hot zOMG Dine in Hell Tower": "Ultraheißer zOMG-Höllenmahl-Turm",
    "Essence of Fire": "Essenz des Feuers", "Phoenix Egg": "Phönix-Ei",
    "Storm Lantern": "Sturmlaterne", "Stormy Peak": "Stürmischer Gipfel", "Storm Generator": "Sturmgenerator",
    "Heart of the Storm": "Herz des Sturms", "Moonshine Rune": "Mondschein-Rune", "Moonlight Beam": "Mondlichtstrahl",
    "Storm Cloud": "Sturmwolke", "Tornado": "Tornado",
    "Lightning Field": "Blitzfeld", "Ball Lightning": "Kugelblitz", "Lightning Generator": "Blitzgenerator",
    "Great Lightning Turret": "Großer Blitzturm",
    "Xtreme Lightning \"This is madness\" Ultra Q_Q Tower": "Xtremer „Das ist Wahnsinn“-Ultra-Q_Q-Blitzturm",
    "Arcane Shrine": "Arkaner Schrein", "Altar of Magic": "Altar der Magie", "Ritual Pit": "Ritualgrube",
    "Stone of Wisdom": "Stein der Weisheit", "Ancient Fountain of Wisdom": "Uralter Brunnen der Weisheit",
    "Cube of Betrayal": "Würfel des Verrats", "Floating Cube of Treachery": "Schwebender Würfel der Heimtücke",
    "Scaring Statue of Corruption": "Schreckliche Statue der Verderbnis",
    "Ruinous Obelisk": "Verfallener Obelisk", "Enchanted Obelisk": "Verzauberter Obelisk", "Ornate Obelisk": "Verzierter Obelisk",
    "Runed Obelisk": "Runen-Obelisk", "Glowing Engraved Obelisk of Ultimate Pwnage": "Leuchtender Obelisk der ultimativen Pwnage",
    "Hydro Cannon": "Hydrokanone", "Tsunami Cannon": "Tsunamikanone",
    "Coral Flower": "Korallenblume", "Tiny Coral": "Winzige Koralle", "Coral Needle": "Korallennadel", "Coral Atoll": "Korallenatoll",
    "The Totally Uber Coral of Absolute GG": "Die total übere Koralle des absoluten GG",
    "Fountain of Corrosion": "Brunnen der Korrosion", "Glowing Fountain of Oxidization": "Leuchtender Brunnen der Oxidation",
    "Ice Cube": "Eiswürfel", "Glacier": "Gletscher", "Permafrost Blaster": "Permafrost-Kanone", "Frozen Monument": "Gefrorenes Monument",
    "Noxious Tendril Trap": "Giftranken-Falle", "Earthbind Trap": "Erdfessel-Falle", "Flame Grate": "Flammenrost",
    "Lightning Trap": "Blitzfalle", "Crystal Trap": "Kristallfalle", "Slowing Puddle": "Bremspfütze",
    "Dual Element Base Tower": "Dual-Grundturm",
    "Acid Fountain": "Säurebrunnen", "Arcane Lava Piles": "Arkane Lavahaufen", "Arcane Lightning Generator": "Arkaner Blitzgenerator",
    "Fire Berry Bush": "Feuerbeerenstrauch", "Fire Breathing Snowman": "Feuerspeiender Schneemann", "Gaea Spring": "Gaia-Quelle",
    "Icy Time Crystal": "Eisiger Zeitkristall", "Lightning Rock Elemental": "Blitz-Felselementar", "Magic Mushrooms": "Magische Pilze",
    "Runed Rock": "Runenfels", "Natural Maelstrom": "Natürlicher Mahlstrom", "Radiating Cloud": "Strahlende Wolke",
    "Red Lightning Generator": "Roter Blitzgenerator", "Thornweed Field": "Dornkrautfeld", "Volcano": "Vulkan",
}
# Vollständige Namen (die Kartendaten kürzen manche ab)
FULL = {"h072": "Xtreme Lightning \"This is madness\" Ultra Q_Q Tower", "h022": "Glowing Engraved Obelisk of Ultimate Pwnage"}


def r(v):
    return round(v / U, 2)


def aura(kind, radius, **kw):
    return dict({"type": kind, "radius": r(radius)}, **kw)


# Fähigkeiten je Tower (Werte aus den Tooltips der Karte, siehe Design-Dokument). Splash kommt aus den Einheitendaten.
ABIL = {
    "h00M": [{"type": "crit", "chance": 0.4, "multiplier": 2.0}],
    "h015": [{"type": "crit", "chance": 0.4, "multiplier": 2.0}],
    "h00Y": [aura("speed_aura", 1000, bonus=0.2)],
    "h014": [aura("speed_aura", 1200, bonus=0.33)],
    "h00G": [{"type": "bounce", "targets": 2, "falloff": 0.5, "radius": r(500)}],
    "h00N": [{"type": "bounce", "targets": 4, "falloff": 0.55, "radius": r(500)}],
    "h00O": [{"type": "bounce", "targets": 6, "falloff": 0.6, "radius": r(500)}],
    "h00P": [{"type": "bounce", "targets": 9, "falloff": 0.65, "radius": r(500)}],
    "h016": [{"type": "bounce", "targets": 19, "falloff": 0.7, "radius": r(500)}],
    "h00E": [{"type": "poison", "dps": 10, "duration": 2.5}, {"type": "slow", "factor": 0.15, "duration": 2.5}],
    "h00Q": [{"type": "poison", "dps": 30, "duration": 5.0}, {"type": "slow", "factor": 0.25, "duration": 5.0}],
    "h00R": [{"type": "poison", "dps": 70, "duration": 8.0}, {"type": "slow", "factor": 0.3, "duration": 8.0}],
    "h00S": [{"type": "poison", "dps": 200, "duration": 15.0}, {"type": "slow", "factor": 0.35, "duration": 15.0}],
    # Pyramiden: Erdstoß trifft alle Bodengegner in Reichweite (Angriff gegen Luft fehlt noch)
    "h08I": [{"type": "multishot", "targets": 99}, {"type": "slow", "factor": 0.15, "duration": 0.6}],
    "h08M": [{"type": "multishot", "targets": 99}, {"type": "slow", "factor": 0.25, "duration": 0.95}],
    "h07J": [{"type": "multishot", "targets": 99}, {"type": "slow", "factor": 0.32, "duration": 1.3}],
    "h08N": [{"type": "multishot", "targets": 99}, {"type": "slow", "factor": 0.4, "duration": 1.65}],
    "h07K": [{"type": "stun", "chance": 0.05, "duration": 2.0, "damage": 100}],
    "h07B": [{"type": "stun", "chance": 0.10, "duration": 2.0, "damage": 400}],
    "h07C": [{"type": "stun", "chance": 0.15, "duration": 2.0, "damage": 700}],
    "h07E": [aura("bounty_aura", 1000, bonus=0.33)],
    "h07D": [aura("bounty_aura", 1200, bonus=0.55)],
    "h03K": [aura("burn_aura", 300, dps=200.0)],
    "h03N": [aura("burn_aura", 300, dps=600.0)],
    "h02U": [{"type": "poison", "chance": 0.12, "dps": 50, "duration": 3.0}, {"type": "slow", "chance": 0.12, "factor": 0.06, "duration": 3.0}],
    "h02V": [{"type": "poison", "chance": 0.13, "dps": 180, "duration": 3.0}, {"type": "slow", "chance": 0.13, "factor": 0.08, "duration": 3.0}],
    "h01E": [{"type": "poison", "chance": 0.14, "dps": 1000, "duration": 3.0}, {"type": "slow", "chance": 0.14, "factor": 0.1, "duration": 3.0}],
    "h02T": [{"type": "poison", "chance": 0.15, "dps": 1800, "duration": 3.0}, {"type": "slow", "chance": 0.15, "factor": 0.12, "duration": 3.0}],
    "h037": [aura("damage_aura", 1000, bonus=0.25)],
    "h03B": [aura("damage_aura", 1200, bonus=0.4)],
    "h074": [{"type": "multishot", "targets": 3}],
    "h060": [{"type": "multishot", "targets": 3}],
    "h05T": [{"type": "multishot", "targets": 3}],
    "h078": [{"type": "multishot", "targets": 4}],
    "h04P": [{"type": "multishot", "targets": 9}],
    "h06T": [{"type": "multishot", "targets": 15}],
    "h06U": [aura("slow_aura", 600, factor=0.15)],
    "h05Y": [aura("slow_aura", 800, factor=0.25)],
    # Kettenblitz: vorerst als Blitzschlag um das Ziel (trifft alle im Umkreis statt einer festen Anzahl)
    "h04I": [{"type": "nova", "chance": 0.06, "damage": 60, "radius": r(300)}],
    "h062": [{"type": "nova", "chance": 0.06, "damage": 240, "radius": r(320)}],
    "h085": [{"type": "nova", "chance": 0.06, "damage": 660, "radius": r(340)}],
    "h05N": [{"type": "nova", "chance": 0.06, "damage": 2400, "radius": r(360)}],
    "h072": [{"type": "nova", "chance": 0.06, "damage": 6000, "radius": r(400)}],
    "h0AF": [{"type": "bounce", "targets": 3, "falloff": 0.55, "radius": r(200)}],
    "h01K": [{"type": "bounce", "targets": 4, "falloff": 0.63, "radius": r(200)}],
    "h01N": [{"type": "bounce", "targets": 5, "falloff": 0.7, "radius": r(200)}],
    "h02S": [aura("xp_aura", 1000, bonus=0.45)],
    "h01G": [aura("xp_aura", 1200, bonus=0.7)],
    "h02O": [{"type": "armor_reduce", "amount": 3.0, "duration": 3.0}],
    "h02D": [{"type": "armor_reduce", "amount": 6.0, "duration": 5.0}],
    "h01F": [{"type": "armor_reduce", "amount": 8.0, "duration": 6.0}],
    "h02W": [{"type": "crit", "chance": 0.05, "multiplier": 1.7}],
    "h020": [{"type": "crit", "chance": 0.05, "multiplier": 2.2}],
    "h029": [{"type": "crit", "chance": 0.05, "multiplier": 2.8}],
    "h02N": [{"type": "crit", "chance": 0.05, "multiplier": 3.5}],
    "h022": [{"type": "crit", "chance": 0.05, "multiplier": 5.5}],
    # Welle, die Gegner auf ihrem Weg trifft: vorerst als Treffer im Umkreis des Ziels
    "h04D": [{"type": "nova", "chance": 0.23, "damage": 180, "radius": r(250)}],
    "h04E": [{"type": "nova", "chance": 0.28, "damage": 1700, "radius": r(300)}],
    "h04U": [aura("armor_aura", 600, amount=5.0)],
    "h056": [aura("armor_aura", 800, amount=8.0)],
    "h04W": [{"type": "slow", "factor": 0.18, "duration": 2.5}],
    "h052": [{"type": "slow", "factor": 0.18, "duration": 2.5}],
    "h04X": [{"type": "slow", "factor": 0.18, "duration": 2.5}],
    "h055": [{"type": "slow", "factor": 0.18, "duration": 2.5}],
}
# Fallen (direkt gebaut, Element 4, 900 Gold + 1 Holz). Gegner laufen darüber, getroffen wird nur, wer auf der Falle steht.
ABIL.update({
    "h045": [{"type": "multishot", "targets": 99}, {"type": "poison", "dps": 100, "duration": 30.0}],
    "h07V": [{"type": "stun", "chance": 1.0, "duration": 2.5}],
    "h03S": [{"type": "stacking_damage", "per_hit": 200, "duration": 3.0},
             {"type": "death_explosion", "damage": 3000, "radius": r(250), "duration": 3.0,
              "text": "Brennende Gegner explodieren beim Tod: 3000 Schaden im Radius 2,0"}],
    "h06O": [{"type": "nova", "damage": 2500, "radius": r(250)}],
    "h026": [{"type": "armor_reduce", "amount": 6.0, "duration": 7.0}],
    "h04K": [{"type": "slow", "factor": 0.17, "duration": 8.0}],
})
# Dual-Tower (Upgrade des Dual-Grundturms, je 3 Punkte in beiden Elementen)
ABIL.update({
    "h013": [{"type": "area_debuff", "radius": r(250), "armor": 3.0, "slow": 0.1, "dps": 60.0, "duration": 15.0,
              "text": "Ätzt Gegner im Radius 2,0 um das Ziel: −3 Rüstung, −10 % Tempo, 60 Schaden/s für 15 s"}],
    "h03V": [{"type": "crit", "chance": 0.1, "multiplier": 10.0}],
    # Kegel wie beim Schneemann (Tooltip nennt keine Maße): Länge 1000 = Reichweite
    "h06V": [{"type": "cone", "chance": 0.2, "damage": 1600, "length": r(1000), "width_start": r(150), "width_end": r(300)}],
    "h011": [{"type": "rage", "bonus": 0.4, "radius": r(450), "duration": 8.0, "every": 15.0,
              "text": "Alle 15 s: +40 % Schaden für Tower im Radius 3,5 für 8 s"}],
    # Feueratem (A02X): 600 lang, Radius 150 am Tower bis 300 am Ende
    "h054": [{"type": "cone", "length": r(600), "width_start": r(150), "width_end": r(300)}],
    "h09Z": [{"type": "amplify", "chance": 0.2, "bonus": 0.25, "duration": 5.0,
              "text": "20 % Chance, das Ziel 5 s zu ertränken: es nimmt 25 % mehr Schaden"}],
    "h01O": [{"type": "pulse", "every": 20.0, "radius": r(1800), "stun": 2.5, "center": "tower",
              "text": "Zeitsperre alle 20 s: betäubt alle Gegner im Radius 14 für 2,5 s"}],
    "h07N": [{"type": "multishot", "targets": 3},
             {"type": "pulse", "every": 12.0, "radius": r(200), "stun": 2.0, "damage": 3000, "center": "target", "targets": "ground",
              "text": "Aufspießen alle 12 s: Bodengegner um das Ziel 2 s betäubt, 3000 Zauberschaden"}],
    "h01Y": [{"type": "pulse", "every": 10.0, "radius": 0.0, "slow": 0.5, "duration": 3.0, "center": "target", "max": 1,
              "text": "Verhexen alle 10 s: ein Gegner wird 3 s zum Tier (−50 % Tempo)"}],
    "h01L": [{"type": "gold_on_hit", "chance": 0.16, "gold": 1}],
    "h00Z": [aura("slow_aura", 800, factor=0.11), aura("armor_aura", 800, amount=4.0)],
    "h09C": [{"type": "hp_cut", "radius": r(700), "factor": 0.23, "factor_challenge": 0.15,
              "text": "Gegner, die in Radius 5,5 kommen, verlieren einmalig 23 % ihrer Leben (Challenge 15 %)"}],
    "h05U": [{"type": "chain", "chance": 0.2, "damage": 1250, "targets": 4, "growth": 1.25, "radius": r(500),
              "text": "20 % Chance auf roten Kettenblitz: 1250 Zauberschaden, springt auf 4 weitere, +25 % je Sprung"}],
    "h010": [{"type": "stun", "chance": 0.15, "duration": 3.0}],
    "h03P": [{"type": "poison", "dps": 250, "duration": 8.0}, {"type": "slow", "factor": 0.07, "duration": 8.0}],
})
TRAPS = ["h045", "h07V", "h03S", "h06O", "h026", "h04K"]
DUAL_BASE = "h0AT"   # Barrikade -> Dual-Grundturm (1998 Gold + 1 Holz, zusammen 2000)
DUAL_PAGE_2 = "h01D"  # zweite Upgrade-Seite im Original, bei uns im selben Turm
# Schaden kommt beim Schneemann aus dem Zauber (3000 je Stoß), nicht aus dem Angriff
DAMAGE_OVERRIDE = {"h054": [3000, 3000]}
DAMAGE_TYPE_OVERRIDE = {"h054": "spells"}

# Werte, die in den Einheitendaten fehlen (Standard des WC3-Grundturms), aus den Tooltips
RANGE = {"h03K": 300, "h03N": 300, "h04D": 700, "h04E": 700, "h05D": 700, "h07K": 650, "h07B": 650, "h07C": 650,
         "h07M": 700, "h0AF": 700, "h01K": 700, "h01N": 700, "h02O": 700, "h02D": 700, "h01F": 700, "h00E": 700, "h00Q": 700,
         "h04P": 800, "h06T": 800, "h011": 700}
COOLDOWN = {"h02D": 0.9, "h04P": 0.9, "h06T": 0.9}
# Erdstoß der Pyramiden: Schaden je Stoß = DPS × 3 s (Design-Dokument)
SHOCK = {"h08I": 150, "h08M": 570, "h07J": 1500, "h08N": 4500}
SHOCK_RANGE = {"h08I": 240, "h08M": 280, "h07J": 325, "h08N": 375}
NO_ATTACK = {"h03K", "h03N"}


def num(v):
    return ("%.1f" % v).replace(".", ",")


def describe(a):
    """Anzeigetext für Fähigkeiten, die abilities.gd nicht selbst beschreibt (Abilities.describe nimmt dann "text")."""
    if "text" in a:
        return a
    a = dict(a)
    if a["type"] == "nova":
        chance = "%d %% Chance: " % round(a["chance"] * 100) if "chance" in a else "Bei jedem Treffer: "
        a["text"] = chance + "%d Zauberschaden im Radius %s um das Ziel" % (a["damage"], num(a["radius"]))
    elif a["type"] == "stacking_damage":
        a["text"] = "Jeder Treffer auf dasselbe Ziel macht %d Schaden mehr als der letzte" % a["per_hit"]
    return a


def slug(name):
    s = name.lower().replace('"', "").replace("'", "")
    return "eeve_" + re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def unit_name(uid):
    return FULL.get(uid, TOWERS[uid]["name"])


def splash(m):
    if m.get("ua1w") != "msplash":
        return []
    radius = float(m.get("ua1h") or m.get("ua1q") or 0)
    if radius <= 0:
        return []
    return [{"type": "splash", "radius": r(radius), "factor": float(m.get("uhd1", 0.5))}]


def tower_json(uid, element, line, children, kind="tower"):
    t = TOWERS[uid]
    m = UNITS[uid]
    name = unit_name(uid)
    base = float(m.get("ua1b", 20) or 0)
    sides = float(m.get("ua1s", 6) or 1)
    tier = {"damage": DAMAGE_OVERRIDE.get(uid, [base + 1, base + sides])}
    tier["range"] = r(float(m.get("ua1r") or RANGE.get(uid, 700)))
    if uid in SHOCK:
        tier["damage"] = [SHOCK[uid], SHOCK[uid]]
        tier["range"] = r(SHOCK_RANGE[uid])
    tier["cooldown"] = float(m.get("ua1c") or COOLDOWN.get(uid, 1.0))
    if uid in NO_ATTACK:
        tier["damage"] = [0, 0]
        tier["cooldown"] = 0.0
    abilities = ([] if uid in NO_ATTACK or uid in DAMAGE_OVERRIDE else splash(m)) + ABIL.get(uid, [])
    abilities = [describe(a) for a in abilities]
    todo = [a["text"] for a in abilities if a["type"] == "todo"]
    tier["abilities"] = [a for a in abilities if a["type"] != "todo"]
    targets = "ground" if uid in SHOCK or kind == "trap" else "both"
    if "air" in str(m.get("ua1g") or "") and "ground" not in str(m.get("ua1g")):
        targets = "air"
    d = {
        "id": slug(name),
        "name": NAMES[name],
        "name_original": name,
        "category": "eeve",
        "color": mix_color(element) if "+" in element else COLORS.get(element, "#d8d8e8"),
        "model": "res://assets/models/crystals/%s.glb" % MODELS[line % len(MODELS)],
        "damage_type": DAMAGE_TYPE_OVERRIDE.get(uid, DAMAGE.get(m.get("ua1t") or "pierce", "magic")),
        "targets": targets,
        "eeve": {
            "element": element,
            "level": int(str(t["req_level"] or 1).split(",")[0]),
            "cost": int(t["cost"] or 0),
            "lumber": int(t["lumber"] or 0),
            "from": slug(unit_name(t["from"])) if t["from"] and t["from"] != "h006" else ("" if kind == "trap" else "eeve_barricade"),
            "next": [slug(unit_name(c)) for c in children],
            "wc3": uid,
        },
        "tiers": [tier],
    }
    if element == "storm":
        d["hit_fx"] = STORM_HIT
    d.update(LOOK.get(name, {}))
    d.update(look("eeve", d["id"][5:]))
    d.update(ELEMENTS.get(d["id"], {}))
    if kind == "trap":
        d["kind"] = "trap"
        d["model_scale"] = 0.3
        d["eeve"]["trap"] = True
    if "+" in element:
        d["eeve"]["element"] = ""
        d["eeve"]["elements"] = element.split("+")
        d["eeve"]["from"] = "eeve_dual_element_base_tower"
    if uid == DUAL_BASE:
        d["eeve"]["dual_base"] = True
        d["eeve"]["level"] = 3
    if todo:
        d["eeve"]["todo"] = todo
    return d


def mix_color(element):
    a, b = (Color_hex(COLORS[e]) for e in element.split("+"))
    return "#%02x%02x%02x" % tuple((x + y) // 2 for x, y in zip(a, b))


def Color_hex(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def dual_element(uid):
    return "+".join(ELEMENTS[e] for e in TOWERS[uid]["element"].split("+"))


# Marktplatz (h0AV): im Original vom Erbauer gebaut (40 Gold, 1 Food), bei uns eine Barrikade für 38 Gold mehr.
# Kauft Items an, verkauft Holz und Tränke, hat die globalen Upgrades (data/eeve_items.json, eeve_items.gd).
MARKETPLACE = {
    "id": "eeve_marketplace", "name": "Marktplatz", "name_original": "Marketplace", "category": "eeve",
    "color": "#d8b860", "model": "res://assets/models/scenery/mine_chest.glb", "model_tint": False, "model_solid": True,
    "damage_type": "", "targets": "both",
    "eeve": {"element": "", "level": 0, "cost": 38, "lumber": 0, "from": "eeve_barricade", "next": [], "wc3": "h0AV", "market": True},
    "tiers": [{"damage": [0, 0], "range": 0.0, "cooldown": 0.0, "abilities": []}],
}


def towers():
    out = [{
        "id": "eeve_barricade", "name": "Barrikade", "name_original": "Barricade", "category": "eeve",
        "color": "#8c8c96", "model": "res://assets/models/rocks/rock_a.glb", "model_tint": False,
        "damage_type": "", "targets": "both",
        "eeve": {"element": "", "level": 0, "cost": 2, "lumber": 0, "from": "", "next": [], "wc3": "h006", "barricade": True},
        "tiers": [{"damage": [0, 0], "range": 0.0, "cooldown": 0.0, "abilities": []}],
    }]
    bases = [b for b in TOWERS["h006"]["upgrades"].split(",") if TOWERS[b]["element"] in ELEMENTS]
    for b in bases:
        element = ELEMENTS[TOWERS[b]["element"]]
        out[0]["eeve"]["next"].append(slug(unit_name(b)))
        lines = TOWERS[b]["upgrades"].split(",")
        out.append(tower_json(b, element, 0, lines))
        for i, first in enumerate(lines):
            uid = first
            while uid:
                kids = [k for k in (TOWERS[uid]["upgrades"] or "").split(",") if k]
                out.append(tower_json(uid, element, i + 1, kids))
                uid = kids[0] if kids else ""
    for i, uid in enumerate(TRAPS):
        out.append(tower_json(uid, ELEMENTS[TOWERS[uid]["element"]], i + 2, [], kind="trap"))
    duals = TOWERS[DUAL_BASE]["upgrades"].split(",") + TOWERS[DUAL_PAGE_2]["upgrades"].split(",")
    out[0]["eeve"]["next"].append("eeve_dual_element_base_tower")
    out[0]["eeve"]["next"].append(MARKETPLACE["id"])
    out.append(MARKETPLACE)
    out.append(tower_json(DUAL_BASE, "", 5, duals))
    for i, uid in enumerate(duals):
        out.append(tower_json(uid, dual_element(uid), i, []))
    return out


# --- Gegner ----------------------------------------------------------------------------

ENEMY_NAMES = {
    "Boar": "Keiler", "Chicken": "Huhn", "Giant Sea Hawk": "Riesen-Seefalke", "Vulture": "Geier", "Giant Wolf": "Riesenwolf",
    "Giant Lobster": "Riesenhummer", "Crab": "Krabbe", "Spirit Owl": "Geistereule", "Tiny Owl": "Kleine Eule", "Flood Lord": "Flutfürst",
    "Spider": "Spinne", "Scarab": "Skarabäus", "Falcon": "Falke", "Harpy": "Harpyie", "Giant Scorpion": "Riesenskorpion",
    "Soldier": "Soldat", "Militia": "Miliz", "Gryphon": "Greif", "Flying Sheep": "Fliegendes Schaf", "Paladin": "Paladin",
    "Grunt": "Grunzer", "Troll": "Troll", "Wyvern Rider": "Wyvernreiter", "Bat Rider": "Fledermausreiter", "Chieftain": "Häuptling",
    "Naga Siren": "Naga-Sirene", "Murloc": "Murloc", "Winged Serpent": "Geflügelte Schlange", "Faerie Drake": "Feendrache",
    "Naga Imperator": "Naga-Imperator", "Ranger": "Waldläufer", "Night Elf Warrior": "Nachtelfenkrieger", "Chimaera": "Chimäre",
    "Hippo Gryph": "Hippogreif", "High Priestess": "Hohepriesterin", "Banshee": "Banshee", "Skeleton": "Skelett",
    "Frost Wyrm": "Frostwyrm", "Gargoyle": "Gargoyle", "Lich Lord": "Lichfürst", "Fire Elemental": "Feuerelementar",
    "Tiny Devil": "Kleiner Teufel", "Phoenix": "Phönix", "Fire Drake": "Feuerdrache", "Fire Lord": "Feuerfürst",
    "Void Keeper": "Leerenwächter", "Daemonic Minion": "Dämonischer Diener", "Daemon Airship": "Dämonen-Luftschiff",
    "Flying Daemon": "Fliegender Dämon", "Daemon Lord": "Dämonenfürst",
    "Clay Golem Challenge": "Lehmgolem", "Flesh Golem Challenge": "Fleischgolem", "Rock Golem Challenge": "Felsgolem",
    "Steel Golem Challenge": "Stahlgolem", "Infernal Golem Challenge": "Höllengolem", "Air Challenge": "Luft-Challenge",
    "Mass Challenge": "Massen-Challenge",
}
# Gegner je Gegnerstufe: Boden, Boden-Masse, Luft, Luft-Masse, Boss (Design-Dokument, Abschnitt Gegner und Wellen)
STAGES = [
    ["Boar", "Chicken", "Giant Sea Hawk", "Vulture", "Giant Wolf"],
    ["Giant Lobster", "Crab", "Spirit Owl", "Tiny Owl", "Flood Lord"],
    ["Spider", "Scarab", "Falcon", "Harpy", "Giant Scorpion"],
    ["Soldier", "Militia", "Gryphon", "Flying Sheep", "Paladin"],
    ["Grunt", "Troll", "Wyvern Rider", "Bat Rider", "Chieftain"],
    ["Naga Siren", "Murloc", "Winged Serpent", "Faerie Drake", "Naga Imperator"],
    ["Ranger", "Night Elf Warrior", "Chimaera", "Hippo Gryph", "High Priestess"],
    ["Banshee", "Skeleton", "Frost Wyrm", "Gargoyle", "Lich Lord"],
    ["Fire Elemental", "Tiny Devil", "Phoenix", "Fire Drake", "Fire Lord"],
    ["Void Keeper", "Daemonic Minion", "Daemon Airship", "Flying Daemon", "Daemon Lord"],
]
KINDS = ["ground", "ground_mass", "air", "air_mass", "boss"]
ARMOR = {"small": "eeve_small", "medium": "eeve_medium", "large": "eeve_large", "hero": "eeve_hero",
         "divine": "eeve_divine", "none": "eeve_none", None: "eeve_large", "normal": "eeve_medium"}
ENEMY_COLORS = ["#b88a5a", "#e07050", "#5aa0e0", "#7a6ad0", "#c04040", "#40a080", "#a0c040", "#9090a0", "#ff7a30", "#a040c0"]
CHALLENGES = ["Clay Golem Challenge", "Flesh Golem Challenge", "Rock Golem Challenge", "Steel Golem Challenge",
              "Mass Challenge", "Air Challenge", "Infernal Golem Challenge"]


def unit_by_name(name):
    for uid, m in UNITS.items():
        if m.get("unam") == name and m.get("uhpm"):
            return uid, m
    raise KeyError(name)


def enemy_json(name, kind, stage):
    uid, m = unit_by_name(name)
    d = {
        "id": slug(ENEMY_NAMES[name].replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")),
        "name": ENEMY_NAMES[name],
        "name_original": name.replace(" Challenge", "") if "Golem" in name else name,
        "category": "eeve",
        "hp": int(m["uhpm"]),
        "speed": round(min(float(m.get("umvs") or 300), 522.0) / U, 3),
        "armor": float(m.get("udef") or 0),
        "armor_type": ARMOR.get(m.get("udty")),
        "bounty": int(m.get("ubba") or 0) + int(m.get("ubdi") or 0),
        "points": int(m.get("upoi") or 0),
        "damage": {"ground": 4, "ground_mass": 1, "air": 4, "air_mass": 1, "boss": 40, "challenge": 0}[kind],
        "flying": m.get("umvt") == "fly",
        "color": ENEMY_COLORS[(stage - 1) % len(ENEMY_COLORS)] if stage else "#e8c840",
        "size": {"ground": 1.0, "ground_mass": 0.75, "air": 1.0, "air_mass": 0.7, "boss": 1.7, "challenge": 1.9}[kind],
        "eeve": {"kind": kind, "stage": stage, "wc3": uid},
    }
    if kind == "boss" or (kind == "challenge" and "Golem" in name):
        d["boss"] = True
    if kind in ("ground_mass", "air_mass") or name == "Mass Challenge":
        d["shape"] = "pyramid"
    return d


def enemies():
    out = []
    for s, row in enumerate(STAGES, start=1):
        for kind, name in zip(KINDS, row):
            out.append(enemy_json(name, kind, s))
    for name in CHALLENGES:
        out.append(enemy_json(name, "challenge", 0))
    return out


def write(kind, items):
    folder = ROOT / "data" / kind
    for old in folder.glob("eeve_*.json"):
        old.unlink()
    for d in items:
        with open(folder / (d["id"] + ".json"), "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent="\t")
            f.write("\n")
    print("%d %s geschrieben" % (len(items), kind))


if __name__ == "__main__":
    write("towers", towers())
    write("enemies", enemies())
