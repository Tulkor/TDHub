"""Bollwerk-Kader: lesbare Quelle der 20 zusätzlichen Helden und ihrer Prägungen.
Aufruf: python tools/heroes/kader.py (bestehende vier Helden bleiben erhalten).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def ab(name, op, desc, **kw):
    tags = ['spell']
    if op in ('shot', 'chain'): tags += ['projectile']
    if op in ('blast', 'zone', 'meteor', 'whirl', 'line'): tags += ['area']
    if kw.get('heal'): tags += ['healing']
    if kw.get('shield') or op == 'guard': tags += ['shield', 'buff']
    if kw.get('stun') or kw.get('slow') or op in ('taunt','pull','wall'): tags += ['control']
    if op in ('summon', 'turret'): tags += ['construct', 'minion']
    if kw.get('duration'): tags += ['duration']
    return dict(name=name, op=op, kind='roster', desc=desc, summary=desc, tags=tags,
                mana=35, cooldown=9.0, range=14.0, radius=4.0, damage=0, **kw)


def skill(name, op, desc, **kw):
    # Defaults werden bewusst vor den expliziten Werten vereinigt.
    base = ab(name, op, desc)
    base.update(kw)
    if op in ('cone','pull'): base['preview']='cone'
    elif op in ('shot','shots','line','dash') or kw.get('shape')=='line': base['preview']='line'
    else: base['preview']='circle'
    if base['preview']=='line': base.setdefault('width',1.2)
    if kw.get('heal'): base['tags'] += ['healing']
    if kw.get('shield') or op == 'guard': base['tags'] += ['shield','buff']
    if kw.get('stun') or kw.get('slow'): base['tags'] += ['control']
    if kw.get('duration'): base['tags'] += ['duration']
    base['tags'] = list(dict.fromkeys(base['tags'] + kw.get('elements', [])))
    return base


S = skill
# id, Name, Titel, Rolle, Farbe, Silhouette, Passive, Fähigkeiten Q/W/E/R.
HEROES = [
('brennholt','Hauptmann Brennholt','Schildträger','Tank','557ba3','shield','front',[
 S('Schildstoß','cone','Ein Schildstoß trifft im Kegel, stößt zurück und unterbricht.',damage=95,stun=.6,knockback=3,range=4,angle=100),
 S('Hornruf','taunt','Spotte Gegner im Umkreis für 3 s.',duration=3,radius=7,cooldown=14),
 S('Ansturm','dash','Stürme 8 m vor, triff Gegner auf der Bahn und betäube sie.',range=8,damage=110,stun=1.2,cooldown=12),
 S('Schildwall','wall','Eine quer gestellte Schildmauer hält Gegner und Geschosse 6 s auf.',duration=6,radius=5,hp=1800,cooldown=65)]),
('mira','Mira Steinhaut','Felsenwächterin','Tank','899785','stone','moss',[
 S('Felsbrocken','meteor','Ein Fels schlägt nach 0,8 s am Zielpunkt ein und betäubt.',damage=140,stun=1.2,delay=.8,at_point=True,elements=['physical']),
 S('Versteinern','guard','Werde 2 s unbeweglich und unverwundbar; danach brechen Splitter aus.',duration=2,damage=130,root=True,invulnerable=True,cooldown=15),
 S('Bodenwelle','line','Ein Bodenriss schleudert Gegner in einer Linie hoch.',damage=110,range=13,width=2,stun=1,elements=['physical']),
 S('Bergsturz','meteor','Fünf Felsen schlagen nacheinander rund um den Zielpunkt ein.',damage=180,stun=.7,count=5,delay=.8,gap=.55,at_point=True,cooldown=65)]),
('grauhirte','Der Grauhirte','Rudelführer','Tank','83929a','wolf','pack',[
 S('Ruf der Wölfe','summon','Rufe zwei Wölfe, höchstens vier; sie folgen dir und kämpfen.',count=2,limit=4,duration=35,pet='wolf',damage=28,cooldown=13),
 S('Hetzjagd','command','Deine Wölfe springen zum Ziel und halten Gegner fest.',damage=55,stun=1.5,at_point=True),
 S('Hirtenstab','pull','Ziehe Gegner im vorderen Kegel zu dir.',damage=85,range=6,angle=110,knockback=3),
 S('Rudelgeist','form','Eine Wolfsaura stärkt dich und deine Wölfe; Treffer heilen dich.',duration=14,dmg_out=.4,lifesteal=.25,shield=.18,cooldown=60)]),
('sirra','Sirra Nachtfalke','Giftklinge','DD','9855bb','daggers','poison',[
 S('Klingenwurf','shot','Eine Klinge durchbohrt Gegner und legt drei Giftstapel auf.',damage=95,poison=3,pierce=True,elements=['poison']),
 S('Schattensprung','blink','Springe zum Zielpunkt; dein nächster Grundangriff verursacht dreifachen Schaden.',range=10,critical=3,cooldown=12,at_point=True),
 S('Rauchbombe','zone','Eine Rauchwolke senkt den Schaden der Gegner darin um 45 %.',duration=5,weaken=.45,radius=5,cooldown=16),
 S('Todesfalter','detonate','Zünde deine Giftstapel auf Gegnern im Umkreis: 55 Schaden je Stapel.',damage=55,radius=10,cooldown=55,elements=['poison'])]),
('kaspar','Kaspar der Armbrustmacher','Tüftler','DD','ae8152','crossbow','workbench',[
 S('Bolzen','shot','Ein schwerer Bolzen durchbohrt bis zu drei Gegner.',damage=150,pierce=3,range=22,elements=['physical']),
 S('Geschütz','turret','Stelle eine Armbrust für 30 s auf, höchstens drei.',duration=30,limit=3,damage=38,pet='crossbow',at_point=True,cooldown=12),
 S('Sprungfeder','dash','Springe rückwärts; eine Falle am Ausgangspunkt betäubt Gegner.',range=6,backward=True,trap=True,damage=90,stun=1.5,cooldown=14),
 S('Belagerungsgeschütz','turret','Ein großer Mörser beschießt Gegnergruppen 20 s lang.',duration=20,limit=1,damage=150,pet='mortar',blast=3,at_point=True,cooldown=65)]),
('yuna','Yuna Schnittwind','Klingentänzerin','DD','57bdb9','sword','flow',[
 S('Windschnitt','dash','Ein kurzer Sprint trifft alle Gegner entlang deiner Bahn.',damage=140,range=8,width=1.5,cooldown=7),
 S('Wirbel','whirl','Wirble 2 s weiterlaufend mit deiner Klinge.',duration=2,damage=65,radius=3.5,interval=.4,cooldown=12),
 S('Konter','guard','Eine Sekunde Konterhaltung: der erste Treffer wird abgewehrt und dreifach erwidert.',duration=1,counter=3,invulnerable=True,cooldown=14),
 S('Tausend Schnitte','strikes','Acht schnelle Sprünge zwischen Gegnern; währenddessen unverwundbar.',count=8,damage=80,radius=9,gap=.16,cooldown=60)]),
('orrin','Orrin Glutwort','Feuermagier','DD','df7545','fire','ember',[
 S('Feuerball','shot','Ein Feuerball explodiert am ersten getroffenen Gegner.',damage=140,blast=3,elements=['fire']),
 S('Feuerwand','zone','Eine vier Sekunden brennende Linie verletzt Gegner wiederholt.',duration=4,damage=55,shape='line',width=2,range=12,interval=.5,at_point=True,elements=['fire']),
 S('Flammenschritt','dash','Springe vorwärts und hinterlasse eine brennende Spur.',range=7,trail=True,damage=35,duration=4,elements=['fire']),
 S('Meteor','meteor','Nach 1,5 s schlägt ein gewaltiger Meteor im sichtbaren Zielkreis ein.',damage=620,radius=7,delay=1.5,stun=.8,at_point=True,cooldown=65,elements=['fire'])]),
('ilsabet','Weise Ilsabet','Frostmagierin','DD','8ec9e5','ice','frost',[
 S('Eislanze','shot','Eine Eislanze durchbohrt die Reihe und sammelt Kälte.',damage=120,pierce=True,slow=.25,elements=['cold']),
 S('Frostfeld','zone','Ein Frostfeld verlangsamt Gegner stark und sammelt Kälte.',damage=30,slow=.55,duration=6,interval=1,at_point=True,elements=['cold']),
 S('Eisblock','guard','Schütze ein nahes verbündetes Ziel mit Eis; Helden werden kurz unverwundbar und heilen.',duration=2.5,heal=140,invulnerable=True,root=True,ally=True,at_point=True,cooldown=18),
 S('Gletscher','cone','Ein großer Eiskegel friert Gegner ein und zerspringt mit hohem Schaden.',damage=360,range=12,angle=100,stun=2.5,cooldown=65,elements=['cold'])]),
('tamo','Tamo der Donnerbauer','Gewitterbauer','DD','d4ad4b','fork','charge',[
 S('Blitzkette','chain','Ein Blitz springt auf bis zu fünf Gegner.',damage=110,count=5,jump=6,elements=['lightning']),
 S('Gabelwurf','zone','Eine Kupfergabel schlägt am Ziel ein und zieht 4 s Blitze an.',damage=70,duration=4,interval=.7,at_point=True,elements=['lightning']),
 S('Donnerschlag','blast','Ein Donnerschlag um dich betäubt kurz.',damage=100,stun=.8,radius=5,cooldown=12,elements=['lightning']),
 S('Gewitterfront','whirl','Ein Gewitter folgt dir 8 s und trifft Gegner in deiner Nähe.',damage=85,duration=8,interval=.7,radius=7,cooldown=65,elements=['lightning'])]),
('albe','Schwester Albe','Lichtheilerin','Heiler','e5d79a','lantern','grace',[
 S('Lichtstrahl','line','Ein Lichtstrahl schadet Gegnern und heilt Verbündete auf der Linie.',damage=85,heal=125,range=16,width=2),
 S('Schutzkreis','zone','Der Schutzkreis heilt und senkt erlittenen Schaden von Helden um 30 %.',heal=28,dmg_in=.3,duration=6,interval=1,radius=5,at_point=True,cooldown=15),
 S('Rettungsgriff','rescue','Ziehe einen verbündeten Helden zu dir und gib ihm einen Schild.',shield=.2,range=14,at_point=True,cooldown=16),
 S('Auferstehung','revive','Belebe gefallene Mitspieler wieder; lebende Verbündete werden geheilt und geschützt.',heal=250,duration=2,invulnerable=True,cooldown=90)]),
('fenn','Fenn Laternenträger','Pfadfinder','Heiler','d5bd64','scout','shine',[
 S('Laterne setzen','beacon','Setze bis zu drei Laternen: ihr Schein heilt und beschleunigt Helden.',heal=22,speed=.2,duration=25,limit=3,interval=1,at_point=True,radius=5),
 S('Leuchtpfeil','shot','Markiere einen Gegner: Er nimmt 6 s lang 20 % mehr Schaden.',damage=85,expose=.2,duration=6),
 S('Wegsprung','beacon_blink','Teleportiere dich zur Laterne nahe dem Zielpunkt und heile dich.',heal=100,range=30,at_point=True,cooldown=14),
 S('Leuchtfeuer','sun','Alle Laternen werden 6 s zu Sonnen: mehr Heilung und wiederholte Unterbrechungen.',heal=55,damage=35,stun=.3,duration=6,radius=7,cooldown=65)]),
('ralda','Ralda Runenschmied','Runenwächterin','Tank','bd8656','hammer','craft',[
 S('Runenhammer','cone','Ein Hammerschlag trifft vor dir und stärkt Helden in der Nähe.',damage=110,range=4,angle=110,dmg_out=.15,duration=4),
 S('Barrikade','wall','Eine widerstandsfähige Barrikade hält Gegner 6 s auf.',duration=6,hp=1600,radius=4,cooldown=16),
 S('Waffe schärfen','buff','Stärke den Schaden eines verbündeten Helden 8 s um 25 %.',dmg_out=.25,duration=8,at_point=True),
 S('Schmiedefeuer','zone','Ein Runenamboss schützt Verbündete mit Schilden und stärkt ihren Schaden.',shield=.06,dmg_out=.25,dmg_in=.2,duration=10,interval=1,radius=7,at_point=True,cooldown=65)]),
('varg','Varg Eisenbart','Berserker','DD','b54b42','axes','berserk',[
 S('Bluthieb','cone','Ein wuchtiger Hieb heilt dich für einen Teil des verursachten Schadens.',damage=170,range=4,angle=100,leech=.25),
 S('Kampfrausch','form','Erhöhe 6 s deinen Schaden und dein Angriffstempo.',duration=6,dmg_out=.3,attack_speed=.25,cooldown=15),
 S('Eisenbrecher','dash','Springe vor und zertrümmere gegnerische Rüstung.',range=7,damage=110,armor_cut=4,duration=5),
 S('Letztes Aufbäumen','form','Erhalte einen starken Schild und mehr Lebensraub und Schaden.',duration=10,shield=.4,dmg_out=.5,lifesteal=.35,cooldown=65)]),
('lior','Lior Spiegelseher','Trugbildmagier','DD','a3a2e1','mirror','mirror',[
 S('Spiegelsplitter','shot','Ein durchbohrender Splitter markiert Gegner und erhöht Folgeschaden.',damage=125,pierce=True,expose=.12,duration=4),
 S('Trugbilder','summon','Zwei Spiegelbilder lenken Gegner ab und greifen 12 s lang an.',count=2,limit=2,duration=12,pet='mirror',damage=28,cooldown=16),
 S('Spiegelwechsel','swap','Tausche den Platz mit deinem nächsten Spiegelbild und erhalte einen Schild.',shield=.15,cooldown=12),
 S('Spiegelkabinett','summon','Rufe vier starke Trugbilder, die Gegner ablenken.',count=4,limit=6,duration=18,pet='mirror',damage=65,cooldown=65)]),
('kraehenfrau','Die Krähenfrau','Fluchweberin','DD','81708e','crow','curse',[
 S('Fluchfeder','shot','Eine Feder durchbohrt Gegner und erhöht ihren erlittenen Schaden.',damage=100,pierce=True,expose=.2,duration=5),
 S('Krähenschwarm','zone','Ein Krähenschwarm verletzt und schwächt Gegner im Zielgebiet.',damage=45,weaken=.2,duration=6,interval=.7,at_point=True),
 S('Unheilsruf','blast','Ein Ruf unterbricht Gegner und senkt ihre Rüstung.',damage=70,stun=.8,armor_cut=4,duration=5,radius=6),
 S('Schwarzer Himmel','zone','Ein großer Fluchschwarm verursacht Schaden und macht Gegner verwundbar.',damage=90,expose=.25,duration=8,interval=.8,radius=8,at_point=True,cooldown=65)]),
('bruno','Bruno Fassroller','Kellerwächter','Tank','b28a55','barrel','brew',[
 S('Rollendes Fass','shot','Ein schweres Fass durchrollt Gegner, verlangsamt und stößt sie zurück.',damage=115,pierce=True,slow=.35,knockback=2,look='rock',speed=13),
 S('Malzschild','guard','Eine dicke Malzschicht gewährt dir Schild und Schadensminderung.',shield=.25,dmg_in=.2,duration=6,cooldown=16),
 S('Schankruf','taunt','Spotte Gegner und heile dich für jeden angelockten Gegner.',radius=6,duration=3,heal=25,cooldown=14),
 S('Große Fassflut','shots','Drei schwere Fässer fächern auf und werfen Gegner um.',count=3,damage=230,pierce=True,stun=1.5,look='rock',speed=13,cooldown=60)]),
('tessa','Tessa Sturmsegel','Windschützin','DD','66b8c8','sail','tailwind',[
 S('Windbolzen','shot','Ein Windbolzen durchbohrt Gegner und schiebt sie zurück.',damage=135,pierce=True,knockback=2,look='wind'),
 S('Sturmböe','cone','Eine breite Böe stößt Gegner zurück und verlangsamt.',damage=100,range=9,angle=90,slow=.4,knockback=4),
 S('Segelsprung','dash','Ein weiter Sprung stärkt kurz dein Lauftempo.',range=9,speed_buff=.3,duration=3),
 S('Orkan','zone','Ein Orkan zieht Gegner wiederholt zur Mitte und verursacht Schaden.',damage=85,pull=1.5,duration=7,interval=.6,radius=7,at_point=True,cooldown=65)]),
('totengraeber','Der Totengräber','Seelenhüter','Heiler','7d9b89','shovel','souls',[
 S('Seelenernte','cone','Eine Sichel aus Seelenkraft trifft Gegner und heilt nahe Verbündete.',damage=100,heal=90,range=6,angle=110),
 S('Grabhelfer','summon','Rufe zwei vergängliche Grabhelfer, die Gegner ablenken und bekämpfen.',count=2,limit=4,duration=18,pet='skeleton',damage=35),
 S('Totenwache','zone','Eine Seelenlaterne heilt Verbündete und schwächt Gegner.',heal=38,weaken=.15,duration=6,interval=1,at_point=True),
 S('Rückkehr der Seelen','revive','Gefallene Helden kehren zurück; ein großer Seelensegen heilt die Gruppe.',heal=320,shield=.2,duration=5,cooldown=90)]),
('ada','Ada Glockenwacht','Glockenritterin','Tank','b6a37b','bell','resonance',[
 S('Glockenschlag','cone','Ein schwerer Klöppel trifft und unterbricht Gegner.',damage=120,stun=.6,range=4.5,angle=105),
 S('Nachhallpanzer','guard','Ein Resonanzschild schützt dich; beim Ende trifft ein Nachhall Gegner.',shield=.25,damage=100,duration=5,cooldown=16),
 S('Wachtgeläut','taunt','Das Geläut zieht Gegner auf dich und schützt nahe Helden.',duration=3,dmg_in=.15,radius=7),
 S('Abendglocke','whirl','Acht Sekunden Geläut: Gegner werden unterbrochen, Verbündete erhalten Schilde.',damage=45,stun=.25,shield=.06,duration=8,interval=1,radius=7,cooldown=65)]),
('sorek','Sorek Ankerträger','Kettenwächter','Tank','578b94','anchor','anchor',[
 S('Ankerwurf','shot','Ein Anker trifft den ersten Gegner, zieht ihn zu dir und betäubt.',damage=115,pull=5,stun=.7,look='scrap',range=14),
 S('Kettenkreis','blast','Schwinge die Kette: Flächenschaden, Gegner werden verlangsamt.',damage=90,slow=.5,radius=5),
 S('Festmachen','guard','Verankere dich: Schild, weniger Schaden und immun gegen Verlangsamung.',shield=.25,dmg_in=.3,slow_immune=True,duration=5,cooldown=15),
 S('Hafenbollwerk','wall','Ein breites Ankerbollwerk stoppt Gegner und Projektile für 8 s.',duration=8,hp=2400,radius=6,cooldown=65)])]

PASSIVES = {
 'front':('Eisenwille','Schaden von Gegnern vor dir wird um 35 % verringert.'),
 'moss':('Moos','Nach 2 s Stillstand regenerierst du 3 % deines Höchstlebens pro Sekunde.'),
 'pack':('Rudel','Jeder lebende eigene Wolf gewährt 2 Rüstung.'),
 'poison':('Gift','Grundangriffe legen Gift auf, bis zu zehn Stapel je Gegner.'),
 'workbench':('Werkbank','Eigene Geschütze in 8 m Umkreis schießen 25 % schneller.'),
 'flow':('Fluss','Treffer gewähren 3 % Angriffstempo, bis 30 %, für 3 s.'),
 'ember':('Brand','Grundangriffe legen eine kurze brennende Fläche am Ziel an.'),
 'frost':('Kälte','Frosttreffer verlangsamen; jeder fünfte Treffer friert kurz ein.'),
 'charge':('Ladung','Erlittener Schaden lädt dich auf; volle Ladung verstärkt die nächste Schadensfähigkeit um 50 %.'),
 'grace':('Gnade','Überschüssige Fähigkeitheilung wird zu einem begrenzten Schild.'),
 'shine':('Schein','Gegner im Laternenschein gewähren der Gruppe 20 % zusätzliches Killgold.'),
 'craft':('Handwerk','Eigene Rezepte kosten 10 % weniger Gold.'),
 'berserk':('Blutmut','Mit sinkendem Leben steigt dein Schaden um bis zu 40 %.'),
 'mirror':('Spiegelhaut','Ein eigenes lebendes Trugbild verringert deinen erlittenen Schaden um 15 %.'),
 'curse':('Schwarzfeder','Grundangriffe machen Gegner 4 s lang um 10 % verwundbarer.'),
 'brew':('Zäher Sud','Treffer heilen dich um 2 % deines Höchstlebens, höchstens einmal pro Sekunde.'),
 'tailwind':('Rückenwind','Grundangriffe gewähren 2 s lang 15 % Lauftempo.'),
 'souls':('Seelenrest','Grundangriffe heilen den verletztesten nahen Verbündeten um 18.'),
 'resonance':('Resonanz','Jeder vierte Grundangriff erzeugt einen Schild über 8 % deines Höchstlebens.'),
 'anchor':('Schwerer Stand','Solange du stillstehst, erleidest du 15 % weniger Schaden.')}

# Je Held: zusätzlich zu den Rollenwerten greift jede Richtung in eine eigene Fähigkeit ein.
# (Slot, Feld, additiver Bonus); Werte werden für mehrere Meilensteine addiert.
SIGNATURES = {
 'torvik':[(0,'stun',.2),(3,'duration',2),(2,'range',3)],
 'unrat':[(0,'blasts',1),(2,'shield',.06),(3,'radius',1.5)],
 'vesna':[(1,'damage',30),(2,'shield',.08),(0,'break_range',3)],
 'zix':[(3,'duration',2),(0,'gadget_stats.hp',150),(3,'cooldown',-6)],
 'brennholt':[(0,'knockback',1.5),(3,'hp',650),(1,'radius',2)],
 'mira':[(3,'count',1),(1,'heal',100),(2,'width',.8)],
 'grauhirte':[(0,'damage',12),(0,'hp',180),(0,'limit',1)],
 'sirra':[(0,'poison',1),(2,'weaken',.08),(1,'range',2)],
 'kaspar':[(1,'damage',15),(2,'shield',.1),(1,'duration',8)],
 'yuna':[(3,'count',2),(2,'duration',.3),(0,'range',2)],
 'orrin':[(3,'damage',100),(2,'shield',.1),(1,'duration',1.5)],
 'ilsabet':[(0,'damage',40),(2,'heal',80),(1,'radius',1.5)],
 'tamo':[(0,'count',1),(2,'shield',.1),(3,'radius',1.5)],
 'albe':[(0,'damage',40),(1,'heal',15),(2,'range',3)],
 'fenn':[(1,'damage',40),(0,'heal',12),(0,'limit',1)],
 'ralda':[(0,'damage',45),(1,'hp',650),(2,'duration',3)],
 'varg':[(3,'dmg_out',.15),(3,'shield',.15),(2,'range',2)],
 'lior':[(3,'damage',20),(1,'hp',200),(1,'duration',4)],
 'kraehenfrau':[(0,'expose',.05),(1,'weaken',.08),(3,'radius',1.5)],
 'bruno':[(3,'count',1),(1,'shield',.12),(0,'range',3)],
 'tessa':[(0,'knockback',1),(2,'shield',.1),(3,'radius',1.5)],
 'totengraeber':[(1,'damage',15),(2,'heal',18),(1,'duration',5)],
 'ada':[(3,'damage',20),(1,'shield',.12),(2,'radius',2)],
 'sorek':[(0,'pull',1.5),(3,'hp',800),(1,'radius',1.5)]}


def build():
    path = ROOT/'data/heroes_helden.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    data['heroes'] = [h for h in data['heroes'] if h['id'] in ('torvik','unrat','vesna','zix')]
    for h in data['heroes']:
        h['combat_role'] = {'unrat':'Tank','vesna':'Heiler'}.get(h['id'],'DD')
    for hid,name,title,role,color,shape,passive,abilities in HEROES:
        tank = role == 'Tank'
        ranged = shape in ('crossbow','fire','ice','lantern','scout','mirror','crow','sail','shovel')
        h = dict(id=hid,name=name,title=title,role=role,combat_role=role,kit='roster',
                 color=color,silhouette=shape,passive_kind=passive,
                 model=f'res://assets/models/heroes/{hid}.glb',
                 hp=860 if tank else 510,hp_regen=3 if tank else 1.8,mana=320,mana_regen=5,
                 armor=6 if tank else 2,speed=5.8 if tank else 6.6,radius=.75 if tank else .6,
                 attack=dict(damage=35 if tank else 43,interval=.9 if tank else .7,range=14 if ranged else 2.8,
                             arc=110,ranged=ranged,animations=['attack_combo_1','attack_combo_2','attack_combo_finish']),
                 level=dict(max=25,xp_base=70,xp_growth=1.25,hp=72 if tank else 45,mana=16,damage=.075,armor=.5 if tank else .3),
                 respawn=dict(base=5,per_level=1),dodge=dict(distance=5.5,time=.22,cooldown=4),
                 passive=dict(zip(('name','desc'),PASSIVES[passive])),abilities=abilities)
        for slot,a in enumerate(abilities):
            a.update(slot=slot,id=f'{hid}_{slot}')
            if slot == 3: a.update(unlock=6,mana=100)
        data['heroes'].append(h)
    path.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
    progpath = ROOT/'data/heroes_progression.json'
    prog = json.loads(progpath.read_text(encoding='utf-8'))
    # Drei echte Richtungen pro Held und Meilenstein, keine zufällige Tag-Lücke.
    prog['hero_imprints'] = {}
    for h in data['heroes']:
        rows=[]
        for milestone in prog['milestones']:
            for direction,(kind,label,mods,stats) in enumerate([
                ('offense','Offensive',{'damage':.22},{'damage':.1}),
                ('defense','Defensive',{'protection':.3},{'hp':.12,'armor':2}),
                ('utility','Utility',{'range':.15,'duration':.15,'cooldown':-.08},{'speed':.06})]):
                slot,field,amount = SIGNATURES[h['id']][direction]
                signature = h['abilities'][0 if h['id']=='zix' else slot]
                # Standardwerte für additive Prägungen müssen explizit sein (keine implizite 0).
                if field=='hp' and 'hp' not in signature: signature['hp']=350
                labels={'stun':'Betäubungsdauer (s)','duration':'Dauer (s)','range':'Reichweite (m)',
                        'blasts':'Explosionen','shield':'Schildanteil','radius':'Radius (m)','damage':'Schaden',
                        'break_range':'Bandreichweite (m)','heal':'Heilung','knockback':'Rückstoß (m)',
                        'hp':'Leben','gadget_stats.hp':'Konstruktleben','count':'Anzahl','width':'Breite (m)',
                        'limit':'Höchstzahl','poison':'Giftstapel','weaken':'Schadenssenkung','dmg_out':'Schadensbonus',
                        'expose':'Verwundbarkeit','pull':'Zugweite (m)','cooldown':'Abklingzeit (s)'}
                detail = f'{"Baukasten" if field.startswith("gadget_stats") else signature["name"]}: {amount:+g} {labels[field]}.'
                rows.append(dict(id=f'{h["id"]}_{milestone}_{kind}',hero=h['id'],milestone=milestone,
                    category=kind,name=f'{h["title"]}: {label} {milestone}',tags=[],mods=mods,stats=stats,
                    skill_changes=[dict(slot=slot,field=field,add=amount)],
                    desc={'offense':'Mehr Schaden für Angriffe und Fähigkeiten.',
                          'defense':'Mehr Leben und Rüstung; stärkere Heilung und Schilde.',
                          'utility':'Mehr Tempo, Reichweite und Dauer; kürzere Abklingzeiten.'}[kind] + ' ' + detail))
        prog['hero_imprints'][h['id']] = rows
    progpath.write_text(json.dumps(prog,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
    # Explizite Standardwerte aus den Prägungen ebenfalls in die Laufzeitdaten schreiben.
    path.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
    print('Kader:',len(data['heroes']),'Helden; Prägungen:',sum(map(len,prog['hero_imprints'].values())))


if __name__ == '__main__': build()
