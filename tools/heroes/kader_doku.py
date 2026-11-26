"""Aktuellen Kader im Stil des ursprünglichen Heldenentwurfs dokumentieren."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
data=json.loads((ROOT/'data/heroes_helden.json').read_text(encoding='utf-8'))
prog=json.loads((ROOT/'data/heroes_progression.json').read_text(encoding='utf-8'))
looks={
'brennholt':'Stämmiger Wachhauptmann mit blauem Turmschild, geschlossenem Helm und Schwert.',
'mira':'Halbriesin aus Basalt mit kristalliner Krone und schweren Felsenschultern.',
'grauhirte':'Alter Hirte mit grauem Bart, Wolfspelz, langem Mantel und Schädelstab.',
'sirra':'Schlanke Giftkämpferin in violettem Leder mit Kapuze und zwei Dolchen.',
'kaspar':'Armbrustmacher mit runder Brille, Werkzeuggürtel und breiter Armbrust.',
'yuna':'Klingentänzerin mit langem Zopf, leichter Kleidung und schmalem Schwert.',
'orrin':'Rußgeschwärzter Gelehrter in dunkler Robe mit Zauberbuch und Flammenstab.',
'ilsabet':'Ältere Magierin mit weißem Haar, langer Robe und verzweigtem Kristallstab.',
'tamo':'Breitschultriger Bauer mit Strohhut, Kupfergabel und aufgerollten Ärmeln.',
'albe':'Ordensfrau in heller Robe mit geschützter Lichtlaterne.',
'fenn':'Junger Pfadfinder mit Bogen, Köcher, Leuchtkugel und leichtem Mantel.',
'ralda':'Gedrungene Runenschmiedin mit hellem Bart, schwerem Hammer und Rückenamboss. Hält als Tank die Straße.',
'varg':'Berserker mit freier Brust, Fellschultern, Bart und zwei schweren Äxten.',
'lior':'Spiegelseher in dunkler Robe mit ovalem Spiegel und Trugbildern.',
'kraehenfrau':'Dunkle Fluchweberin mit Federkragen, langem Gewand und Krähe auf der Hand.',
'bruno':'Breiter Kellerwächter mit Fass auf dem Rücken, Holzkrug und schwerem Lederschurz.',
'tessa':'Windschützin mit Zopf, Bogen und weißem Rückensegel.',
'totengraeber':'Seelenhüter mit Kapuze, langem Mantel, Bart und breitem Spaten. Seine Seelenkraft heilt Verbündete.',
'ada':'Glockenritterin in bronzener Rüstung, mit Schulterglocken und schwerer Handglocke.',
'sorek':'Kettenwächter in petrolfarbener Rüstung, mit großem Anker und goldener Kette.'}
lines=['# Bollwerk – Heldenliste (Kader 2026-11-15)','',
'Überarbeitete Projektfassung des Entwurfs `hero-defense-helden.md` vom 2026-11-04. Alle 22 ursprünglichen Helden und Ideen sind enthalten; Ada und Sorek ergänzen den Kader. Mechanik und Prägungen entsprechen den aktuellen Spieldaten.',
'','**8 Tanks · 4 Heiler · 12 DDs.** Alle Helden sind in der Heldenwahl verfügbar.',
'','Jeder Held hat einen Grundangriff, eine Passive, Q/W/E sowie R ab Stufe 6. Ränge und Kosten verwenden die bestehende Bollwerk-Progression. Ausweichen und Erkundungstempo bleiben gemeinsame Regeln.',
'','Prägungen nach Welle **10, 20 und 30**: je eine Wahl aus **Offensive / Defensive / Utility**. Jeder Mitspieler wählt für seinen eigenen Helden. Rollenwerte und individuelle Fähigkeitsänderung wirken zusammen; höhere Meilensteine stapeln sich.',
'','Blender-Quelle: `tools/modelle/kader_bau.py`; Laufzeitdaten: `data/heroes_helden.json`; Prägungen: `data/heroes_progression.json`.', '', '---','']
n=0
for role,title in [('Tank','Tanks (halten Straßen, fangen Gegner ab)'),('Heiler','Heiler (halten die Gruppe am Leben)'),('DD','DDs (Einzel- und Flächenschaden)')]:
    lines += [f'## {title}','']
    for h in data['heroes']:
        if h['combat_role']!=role: continue
        n+=1
        lines += [f'### {n}. {h["name"]} – {h["title"]}',looks.get(h['id'],h['title'])+'.' if h['id'] not in looks else looks[h['id']],
                  f'- Grundangriff: {h["attack"]["damage"]} Schaden, {h["attack"]["interval"]:g} s Abstand, {h["attack"]["range"]:g} m Reichweite.']
        if h.get('passive'): lines += [f'- Passiv **{h["passive"]["name"]}**: {h["passive"]["desc"]}']
        if h['id']=='zix':
            lines += ['- Q/W/E **Baukasten**: Drei der zehn bestehenden Konstrukte wählen; Bolzenturm, Flammenspeier, Raketenwerfer, Tesla-Spule, Sanitätsmast, Heilsprinkler, Schrottbot, Elektrozaun, Schildkuppel oder Magnetköder. Zwischen Wellen an der Feste austauschbar.']
        for i,a in enumerate(h['abilities']):
            key='R' if h['id']=='zix' else 'QWER'[i]
            lines += [f'- {key} **{a["name"]}**: {a["desc"]}']
        lines += ['- Prägungen (jeweils zusätzlich zu den Rollenwerten):']
        for p in prog['hero_imprints'][h['id']][:3]:
            lines += [f'  - **{dict(offense="Offensive",defense="Defensive",utility="Utility")[p["category"]]}**: {p["desc"]}']
        lines += ['', '---','']
lines += ['## Gelände','',
'Der Grundboden besteht aus rauem, felsigem Basalt mit echter Farb-, Normal- und Rauheitsmap. Um Feste, Kapellen, Türme und Schmiede liegt versetztes Basaltpflaster. Unter Bäumen liegen ausgefranste Erdflächen; im Schlund passen sie sich dem Hang an. Straßen bleiben klar lesbar und Warnflächen über dem Boden sichtbar.', '']
target=ROOT/'docs/hero-defense'
target.mkdir(parents=True,exist_ok=True)
(target/'hero-defense-helden.md').write_text('\n'.join(lines),encoding='utf-8')
print('Dokumentiert:',n,'Helden')
