"""Originale Blender-Modelle für den vollständigen Bollwerk-Kader.
blender --background --python tools/modelle/kader_bau.py -- [--nur=mira,...]
Nutzt denselben Figurenbauer, Humanoid-Rig und Fluid-Pass wie die vier Starthelden.
"""
import sys, os, math, json
import numpy as np
from pathlib import Path
from runpy import run_path
import bpy

ROOT = Path(__file__).resolve().parents[2]
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
only = next((x.split('=',1)[1].split(',') for x in args if x.startswith('--nur=')), None)
# API laden, ohne die bestehenden Modelle neu zu exportieren.
sys.argv = [__file__, '--', str(ROOT/'assets/models/heroes'), '--nur=__api__']
api = run_path(str(Path(__file__).with_name('helden_bau.py')))
Figur, M, mensch, Anim = [api[k] for k in ('Figur','M','mensch','Anim')]
X,Y,Z = api['X'],api['Y'],api['Z']
heroes = json.loads((ROOT/'data/heroes_helden.json').read_text(encoding='utf-8'))['heroes']


def build(h):
    hid, shape = h['id'],h['silhouette']
    f = Figur(hid)
    tank = h['combat_role'] == 'Tank'
    dwarf = shape in ('hammer','barrel')
    giant = shape == 'stone'
    height = 1.75 if dwarf else 2.8 if giant else 2.15
    female = shape in ('daggers','sword','ice','lantern','crow','sail')
    caster = shape in ('fire','ice','lantern','mirror','crow','shovel')
    width = .69 if giant else .56 if tank else .36 if female else .43
    hip,neck = height*.46,height*.78
    hand=(width+.14,.06,height*.36)
    mensch(f,hip=hip,neck=neck,head_top=height,sh=(width,0,neck-.08),
           elbow=(width+.13,0,height*.54),hand=hand,knee=(.23,.02,height*.24),foot=(.23,.05,.12),hip_x=.2)
    if hid=='brennholt':
        # Independent shoulder girdles: rigid pauldrons follow the clavicle,
        # while the upper arm can still swing underneath the armour.
        for side,s in [('L',1),('R',-1)]:
            f.bone('clavicle.'+side,(s*.15,0,neck-.10),f.J['arm.'+side][0],'chest')
        f.bones=[(name,head,tail,'clavicle.'+name[-1] if name.startswith('arm.') else parent)
                 for name,head,tail,parent in f.bones]
        shoulders=[bone for bone in f.bones if bone[0].startswith('clavicle.')]
        f.bones=f.bones[:4]+shoulders+[bone for bone in f.bones[4:] if not bone[0].startswith('clavicle.')]
    for side,s in [('L',1),('R',-1)]:
        grip=(s*hand[0],hand[1],hand[2])
        parent='fore.'+side
        if hid=='brennholt' and side=='R':
            f.bone('twist.R',grip,(grip[0],grip[1]+.12,grip[2]),parent)
            parent='twist.R'
        f.bone('hand.'+side,grip,(grip[0],grip[1]+.12,grip[2]),parent)
        f.bone('weapon.'+side,grip,(grip[0],grip[1]+.3,grip[2]),'hand.'+side)
    original_finish=f._finish
    f.prop_mode=False
    def finish(vertices,mat,bone):
        if f.prop_mode and bone.startswith('fore.'):
            bone=bone.replace('fore.','weapon.')
        elif hid=='brennholt' and bone=='fore.R':
            bone='twist.R'
        return original_finish(vertices,mat,bone)
    f._finish=finish
    skin=M('#bda18c',.82); leather=M('#473b34',.9); wood=M('#674a32',.9)
    armor=M('#'+h['color'],.42 if tank else .85,.65 if tank else 0)
    metal=M('#657182',.35,.8);trim=M('#bc9c5c',.4,.75)
    cloth=M('#242d42',.93);rune=M('#'+h['color'],.35,0,3)
    white=M('#d1c9b5',.9);dark=M('#171d29',.88)
    stone=M('#69757c',.94)
    if giant: skin=stone
    if shape=='axes': skin=M('#c99b82',.8)
    chestmat = skin if shape in ('axes','fork') else cloth if caster else armor
    # Bottes, semelles, genouillères, gants et jonctions souples.
    for side,s in [('L',1),('R',-1)]:
        for bone,r1,r2,mat in [('thigh',.19,.16,leather),('shin',.15,.13,metal if tank else leather),
                              ('arm',.18 if tank else .12,.11,armor),('fore',.13,.10,skin if shape in ('axes','fork','sword') else leather)]:
            f.glied(bone+'.'+side,r1,r2,mat,seg=10)
        f.box((.31,.55,.22),(s*.23,.13,.17),leather,'shin.'+side,bevel=.035)
        f.box((.33,.57,.055),(s*.23,.13,.0275),dark,'shin.'+side,bevel=.015)
        f.ball(.17,(s*.23,.07,height*.24),metal,'shin.'+side,scale=(1,.75,1),seg=10)
        f.ball(.13,(s*hand[0],hand[1],hand[2]),skin,'hand.'+side,scale=(.8,1,1.2))
        f.ball(.065,(s*(hand[0]-.08),hand[1]+.08,hand[2]+.04),skin,'hand.'+side,scale=(.8,1,1.2),seg=8)
        if not caster:
            f.ball(.22 if tank else .13,(s*(width+.09),-.025,neck-.07),armor if shape!='axes' else white,
                   'clavicle.'+side if hid=='brennholt' else 'chest',scale=(1.05,.95,.68))
        f.cyl(.16,.13,.08,(s*.23,.05,.29),trim,'shin.'+side,seg=10)
    f.cyl(.35,.31,.3,(0,0,hip-.08),leather,'hips',seg=12)
    f.cyl(.36,.37,.1,(0,0,hip+.06),trim,'hips',seg=12)
    f.box((.16,.08,.15),(0,.35,hip+.06),rune,'hips',bevel=.02)
    f.ball(.45,(0,0,hip+.28),chestmat,'chest',scale=(1.3 if shape=='barrel' else 1.12 if tank else .72 if female else .88,.82 if shape=='barrel' else .62,.95),seg=14)
    # Lamellen auf der Brust und Kragen, lesbar aus der Spielkamera.
    if tank:
        for k in range(3):
            f.box((.52-k*.05,.08,.08),(0,.28,hip+.14+k*.14),trim,'chest',rot=(0,0,(-1)**k*8),bevel=.015)
    else:
        f.stab((-.25,.23,neck-.1),(.23,.25,hip+.06),.035,.035,leather,'chest')
        f.ball(.065,(0,.29,neck-.18),rune,'chest',seg=8)
    f.cyl(.19,.17,.1,(0,0,neck-.03),cloth if caster else metal,'chest',seg=12)
    f.ball(.26,(0,.02,neck+.19),skin,'head',scale=(.9,.85,1.15),seg=14,rings=9)
    f.box((.14,.09,.065),(0,.235,neck+.14),skin,'head',bevel=.018)
    for s in [-1,1]:
        f.ball(.035,(s*.105,.224,neck+.23),rune,'head',seg=8,rings=5)
        f.box((.12,.045,.035),(s*.105,.235,neck+.29),dark,'head',rot=(0,s*12,0),bevel=.01)
    # Gegliederter Mantel: eigene Nachlaufkette im gemeinsamen Fluid-Pass.
    f.platte([(-.38,-.27,neck-.03),(.38,-.27,neck-.03),(.46,-.38,.44),(-.46,-.38,.44)],(0,1,0),.045,cloth,'chest')
    for s in [-1,1]:
        f.ball(.065,(s*.26,.2,neck-.05),trim,'chest',seg=8)
    if caster or shape=='wolf':
        robe = white if shape=='lantern' else armor
        f.cyl(.46,.3,hip-.24,(0,0,(hip+.24)/2),robe,'hips',seg=14)
        for s in [-1,1]:
            f.box((.055,.055,hip-.3),(s*.29,.3,(hip+.3)/2),trim,'hips',rot=(0,s*-9,0))
        f.cyl(.21,.11,.38,(width,.03,height*.53),cloth,'fore.L',seg=10)
    if shape in ('wolf','axes','hammer','barrel','shovel'):
        beard=white if shape in ('wolf','hammer') else M('#6e4835',.95)
        for k in range(5):
            f.cyl(.065,.11,.28+(2-abs(2-k))*.06,((k-2)*.07,.21,neck+.015),beard,'head',rot=(-12,0,0),seg=6)
    if female:
        hair=white if shape=='ice' else M('#312b32' if shape=='crow' else '#5d302a',.9)
        for s in [-1,1]:
            f.ball(.12,(s*.18,-.06,neck+.17),hair,'head',scale=(.8,1,2),seg=10)
        if shape in ('sword','sail'):
            for k in range(3):
                f.ball(.12-k*.018,(0,-.22-k*.12,neck+.26-k*.07),hair,'head',scale=(1,1.6,1),seg=10)
    if shape=='fork':
        straw=M('#bca171',.95)
        f.cyl(.45,.45,.04,(0,.01,height-.02),straw,'head',seg=14)
        f.cyl(.27,.2,.22,(0,.01,height+.08),straw,'head',seg=14)
        f.cyl(.275,.275,.05,(0,.01,height+.01),leather,'head',seg=14)
    if shape=='crossbow':
        for s in [-1,1]:
            f.ball(.11,(s*.11,.25,neck+.23),trim,'head',scale=(1,.2,1),seg=12)
            f.ball(.085,(s*.11,.275,neck+.23),M('#8cb6ba',.12,.4),'head',scale=(1,.2,1),seg=12)
        for k in range(5):
            f.box((.1,.1,.18),((k-2)*.13,.33,hip),leather,'hips',bevel=.02)
    # Individuelle Silhouetten und Ausrüstung; keine umgefärbten Kopien der Starthelden.
    if tank and shape not in ('wolf','barrel'):
        f.ball(.29,(0,.01,neck+.23),armor,'head',scale=(1.03,.95,.92),seg=12)
        f.box((.42,.05,.065),(0,.257,neck+.23),dark,'head',bevel=.015)
        for s in [-1,1]: f.box((.1,.12,.3),(s*.24,.07,neck+.06),metal,'head',bevel=.02)
    if shape in ('fire','mirror','crow','shovel','lantern','wolf','scout','daggers'):
        f.ball(.32,(0,-.05,neck+.25),cloth,'head',scale=(1,1,.95),seg=12)
        # Ausschnitt liegt vor der Kapuze, Gesicht bleibt sichtbar.
        f.ball(.22,(0,.13,neck+.2),skin,'head',scale=(.82,.72,1),seg=12)
        for s in [-1,1]: f.ball(.032,(s*.09,.275,neck+.24),rune,'head',seg=8)
    if shape == 'stone':
        for s in [-1,1]:
            for k in range(4):
                f.cyl(.2,.02,.6,(s*(width+.06*k),-.06,neck+.06-k*.05),stone,'arm.'+('L' if s>0 else 'R'),rot=(0,s*(20+k*10),0),seg=5)
        for k in range(6): f.cyl(.13,.02,.42,(math.cos(k)*.18,math.sin(k)*.16,neck+.48),rune,'head',seg=5)
    # Eigene Details je Held (Frisur, Kopfbedeckung, Ausrüstung): tools/modelle/kader_details.py
    run_path(str(Path(__file__).with_name('kader_details.py')))['details'](f,h,M,{'height':height,'hip':hip,'neck':neck,'width':width})
    f.prop_mode=True
    if shape == 'shield':
        before=set(f.bm.verts)
        x=hand[0]
        pts=[(x-.38,.29,.35),(x+.38,.29,.35),(x+.43,.29,1.52),(x,.29,1.72),(x-.43,.29,1.52)]
        f.platte(pts,(0,1,0),.14,armor,'fore.L')
        f.box((.09,.05,1.2),(x,.39,1.02),trim,'fore.L')
        f.box((.62,.05,.09),(x,.39,1.25),trim,'fore.L')
        # Der Unterarm trägt den Schild in gebeugter Deckung. In dieser Griffbasis
        # bleibt die Schildfläche vor dem Körper statt beim Armheben durch die Brust zu kippen.
        pivot=api['Vector']((x,hand[1],hand[2]))
        orient=api['Euler']((-math.pi/2,0,0)).to_matrix()
        for vertex in set(f.bm.verts)-before:
            vertex.co=pivot+orient@(vertex.co-pivot)
        blade(f,-hand[0],hand[2],metal,trim,'fore.R',.85)
        f.cyl(.06,.03,.6,(0,-.05,height+.18),rune,'head',rot=(0,20,0),seg=6)
    elif shape in ('sword','axes','daggers'):
        for side,s in [('R',-1),('L',1)]:
            if shape=='sword' and s>0: continue
            blade(f,s*hand[0],hand[2],metal,trim,'fore.'+side,.55 if shape=='daggers' else 1.2,axe=shape=='axes')
        if shape=='axes':
            for s in [-1,1]:
                f.stab((s*.2,-.1,height-.08),(s*.45,-.2,height+.2),.09,.015,white,'head')
    elif shape in ('fire','ice','wolf','lantern','shovel','mirror','crow','fork','hammer','bell','anchor'):
        x=-hand[0];z=hand[2];bone='fore.R'
        f.stab((x,.08,z-(.55 if shape=='anchor' else .18)),(x,.08,z+(.77 if shape=='anchor' else 1.0)),.06,.045,wood,bone)
        f.weapon_specs=getattr(f,'weapon_specs',{})
        f.weapon_specs['staff_R']={'bone':bone,'head':[x,.08,z+.9],'shaft':[0,0,1],'blade_normal':[0,1,0]}
        if shape=='fork':
            f.box((.55,.12,.12),(x,.08,z+.75),trim,bone)
            for s in [-1,0,1]: f.stab((x+s*.24,.08,z+.72),(x+s*.24,.08,z+1.2),.04,.01,trim,bone)
        elif shape=='hammer':
            f.box((.9,.42,.42),(x,.08,z+.8),metal,bone,bevel=.06)
            f.box((.12,.45,.46),(x,.08,z+.8),rune,bone)
            f.box((.8,.5,.45),(0,-.6,hip+.3),metal,'chest',bevel=.08)
        elif shape=='shovel':
            f.platte([(x-.25,.08,z+.6),(x+.25,.08,z+.6),(x+.22,.08,z+1.05),(x,.08,z+1.2),(x-.22,.08,z+1.05)],(0,1,0),.07,metal,bone)
        elif shape=='anchor':
            # Griff am oberen Schaftende; die Flunken sind der Schlagpunkt,
            # nicht das leere obere Ende des früher verwendeten Stab-Profils.
            f.box((.6,.14,.1),(x,.08,z+.55),metal,bone)
            for s in [-1,1]:
                f.stab((x,.08,z-.3),(x+s*.4,.08,z-.15),.08,.06,metal,bone)
                f.stab((x+s*.4,.08,z-.15),(x+s*.5,.08,z+.1),.06,.01,metal,bone)
            # Den bereits gebauten Schaft und den Anker unter den festen Griff setzen.
            for vertex in f.bm.verts:
                group=f.groups.index('weapon.R')
                if vertex[f.dl].get(group,0)>0:
                    vertex.co.z-=.65
            f.weapon_specs['staff_R'].update(head=[x,.08,z-.95],shaft=[0,0,-1])
            # Five separate interlocking links, attached to the upper eye of the anchor.
            chain_metal=M('#b7c4d2',.24,.85)
            eye=[api['Vector']((x+.06*math.cos(i*math.tau/12),.14,z+.16+.07*math.sin(i*math.tau/12))) for i in range(12)]
            for a,b in zip(eye,eye[1:]+eye[:1]):f.stab(a,b,.018,.018,chain_metal,'weapon.R',seg=6)
            f.chain_root=api['Vector']((x,.14,z+.23))
            for k in range(5):
                joint=f.chain_root+api['Vector']((0,0,-k*.105))
                name=f'chain.{k}'
                f.bone(name,joint,joint+api['Vector']((0,0,-.105)),f'chain.{k-1}' if k else 'weapon.R')
                center=joint+api['Vector']((0,0,-.0525))
                points=[]
                for i in range(12):
                    a=i*math.tau/12
                    points.append(center+api['Vector']((.045*math.cos(a) if k%2==0 else 0,
                        .045*math.cos(a) if k%2 else 0,.072*math.sin(a))))
                for a,b in zip(points,points[1:]+points[:1]):f.stab(a,b,.015,.015,chain_metal,name,seg=6)
        elif shape=='bell':
            f.cyl(.38,.18,.52,(x,.08,z+.7),trim,bone,seg=12)
            f.cyl(.4,.4,.05,(x,.08,z+.43),metal,bone,seg=12)
            f.ball(.07,(x,.08,z+.38),rune,bone)
            for s in [-1,1]: f.cyl(.25,.1,.4,(s*.53,0,neck+.1),trim,'chest',seg=12)
        elif shape=='lantern':
            f.cyl(.28,.24,.15,(x,.08,z+.95),trim,bone,seg=6)
            f.cyl(.24,.28,.15,(x,.08,z+.45),trim,bone,seg=6)
            f.ball(.2,(x,.08,z+.72),rune,bone,scale=(.8,.8,1.3))
            for k in range(6):
                angle=k*math.tau/6
                f.stab((x+math.cos(angle)*.22,.08+math.sin(angle)*.22,z+.48),(x+math.cos(angle)*.22,.08+math.sin(angle)*.22,z+.91),.025,.025,trim,bone)
        elif shape=='mirror':
            f.ball(.4,(x,.08,z+.9),trim,bone,scale=(.8,.18,1.25),seg=16)
            f.ball(.35,(x,.15,z+.9),M('#d4e8f3',.08,1),bone,scale=(.8,.12,1.25),seg=16)
        elif shape=='ice':
            for k in range(5):
                f.cyl(.11,.005,.65,(x+(k-2)*.1,.08,z+.9),rune,bone,rot=(0,(k-2)*18,0),seg=5)
        elif shape=='fire':
            for k in range(5):
                f.cyl(.12,.005,.4+k*.06,(x+math.sin(k)*.12,.08,z+.8+k*.04),rune,bone,seg=6)
            f.box((.42,.13,.52),(hand[0],.15,z+.1),leather,'fore.L',rot=(15,0,10),bevel=.025)
            f.box((.35,.02,.45),(hand[0],.23,z+.1),white,'fore.L',rot=(15,0,10))
        else:
            f.ball(.22,(x,.08,z+1),white if shape=='wolf' else dark,bone,scale=(.8,.7,1.1))
            for s in [-1,1]:
                f.cyl(.08,.005,.28,(x+s*.16,.08,z+1.22),white,bone,rot=(0,s*20,0),seg=5)
    elif shape in ('crossbow','scout','sail'):
        x=-hand[0];z=hand[2];bone='fore.R'
        f.weapon_specs=getattr(f,'weapon_specs',{})
        f.weapon_specs['bow_R']={'bone':bone,'head':[x,.8,z],'shaft':[0,1,0],'blade_normal':[0,0,1]}
        if shape=='crossbow':
            f.box((.16,1.0,.17),(x,.45,z),wood,bone,bevel=.02)
            f.stab((x-.5,.7,z),(x+.5,.7,z),.045,.045,metal,bone)
            f.stab((x-.5,.7,z),(x,.2,z),.012,.012,white,bone)
            f.stab((x+.5,.7,z),(x,.2,z),.012,.012,white,bone)
        else:
            left_grip=api['Vector'](hand)
            f.bone('string.R',(-hand[0],hand[1],hand[2]),(-hand[0],hand[1]+.1,hand[2]),'weapon.R')
            f.bone('string.L',hand,(hand[0],hand[1]+.1,hand[2]),'hand.L')
            for s in [-1,1]:
                end=api['Vector']((x+s*.34,-.18,z+s*.65))
                curve=[(x,.15,z),(x+s*.11,.12,z+s*.30),(x+s*.24,-.02,z+s*.55),end]
                for start,stop in zip(curve,curve[1:]): f.stab(start,stop,.04,.025,wood,bone)
                before=set(f.bm.verts)
                f.stab(end,left_grip,.008,.008,white,'string.R')
                span=left_grip-end
                a=f._gi('string.R');b=f._gi('string.L')
                for vertex in set(f.bm.verts)-before:
                    weight=max(0,min(1,(vertex.co-end).dot(span)/span.length_squared))
                    vertex[f.dl].clear()
                    vertex[f.dl][a]=1-weight
                    vertex[f.dl][b]=weight
        if shape=='sail':
            f.stab((0,-.35,hip),(0,-.35,height+.65),.055,.035,wood,'chest')
            f.platte([(0,-.36,height+.6),(.9,-.36,hip+.3),(0,-.36,hip+.3)],(0,1,0),.035,white,'chest')
        if shape=='scout':
            for k in range(5): f.stab((-.2+k*.08,-.35,hip+.1),(-.2+k*.08,-.35,neck+.25),.018,.012,trim,'chest')
            # Belt lantern leaves the drawing hand and bow string unobstructed.
            lamp=(width+.12,.12,hip-.12)
            f.box((.16,.16,.22),lamp,rune,'hips',bevel=.015)
            for dz in [-.14,.14]:f.box((.24,.24,.045),(lamp[0],lamp[1],lamp[2]+dz),metal,'hips')
    elif shape=='barrel':
        f.weapon_specs={'mug_R':{'bone':'fore.R','head':[-hand[0],.08,hand[2]+.3],
                                'shaft':[0,0,1],'blade_normal':[0,1,0]}}
        f.cyl(.47,.42,.9,(0,-.45,hip+.3),leather,'chest',seg=12)
        for z in [hip-.08,hip+.15,hip+.65]: f.cyl(.48,.48,.065,(0,-.45,z),metal,'chest',seg=12)
        f.cyl(.27,.27,.55,(-hand[0],.08,hand[2]+.05),leather,'fore.R',seg=12)
        f.cyl(.28,.28,.05,(-hand[0],.08,hand[2]+.3),trim,'fore.R',seg=12)
    # Raven plumes, wolf pelt and lantern scout distinguish backs as well as fronts.
    if shape in ('crow','wolf'):
        for s in [-1,1]:
            for k in range(7):
                f.cyl(.09,.005,.6,(s*(.25+k*.07),-.18,neck-.1-k*.04),dark if shape=='crow' else white,'chest',rot=(0,s*(25+k*8),0),seg=5)
    if shape=='crow':
        f.ball(.16,(hand[0],.12,hand[2]+.3),dark,'fore.L',scale=(1,1.6,.8))
        f.cyl(.07,0,.2,(hand[0],.36,hand[2]+.3),trim,'fore.L',rot=(-90,0,0),seg=5)
    for spec in getattr(f,'weapon_specs',{}).values():
        driver=spec['bone']
        spec.update(bone=driver.replace('fore.','weapon.'),driver=driver,
                    grip=[hand[0] if driver.endswith('L') else -hand[0],hand[1],hand[2]])
    f.weapon_torso={'center':[0,0,hip+.28],'radii':[.5 if tank else .34,.31,.43]}
    return f, height, hand


def blade(f,x,z,metal,trim,bone,length,axe=False):
    if not hasattr(f,'weapon_specs'): f.weapon_specs={}
    f.weapon_specs['weapon_'+bone[-1]]={'bone':bone,'head':[x+(.25 if axe else 0),.07,z+length+(0 if axe else .2)],
                                      'shaft':[0,0,1],'blade_normal':[0,1,0]}
    if axe:f.weapon_specs['weapon_'+bone[-1]]['cutting_edge']=[1,0,0]
    f.stab((x,.07,z-.18),(x,.07,z+.2),.05,.05,trim,bone)
    f.box((.36,.1,.08),(x,.07,z+.18),trim,bone,bevel=.015)
    if axe:
        f.stab((x,.07,z+.2),(x,.07,z+length),.045,.035,trim,bone)
        f.platte([(x-.05,.07,z+length),(x+.4,.07,z+length+.15),(x+.48,.07,z+length-.35),(x-.05,.07,z+length-.2)],(0,1,0),.08,metal,bone)
        f.platte([(x+.37,.07,z+length+.13),(x+.4,.07,z+length+.15),(x+.48,.07,z+length-.35),(x+.45,.07,z+length-.33)],
                 (0,1,0),.09,M('#b7c4d2',.24,.85),bone)
    else:
        f.platte([(x-.09,.07,z+.23),(x+.09,.07,z+.23),(x+.065,.07,z+length),(x,.07,z+length+.2),(x-.065,.07,z+length)],(0,1,0),.06,metal,bone)


def animate(h,rig,f):
    run_path(str(Path(__file__).with_name('kader_motion.py')))['write_actions'](h,f,rig,api)


def linked_grip(h,rig,f):
    if h['silhouette']!='anchor':return
    # Bake a real two-bone IK connection, not only matching the five authored key poses.
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    right=rig.data.edit_bones.new('grip.R')
    hand=f.J['hand.R'][0]
    right.head=hand;right.tail=hand+api['Vector']((0,.12,0))
    right.parent=rig.data.edit_bones['chest'];right.use_deform=False
    target=rig.data.edit_bones.new('support.L')
    target.head=(hand.x,hand.y,hand.z-.18)
    target.tail=(hand.x,hand.y+.12,hand.z-.18)
    target.parent=rig.data.edit_bones['weapon.R']
    target.use_deform=False
    bpy.ops.object.mode_set(mode='OBJECT')
    motion=run_path(str(Path(__file__).with_name('rig_motion.py')))['MotionRig'](f.bones,f.weapon_specs)
    # Interpolate the grip target itself. Quaternion interpolation of two arm joints can arc
    # outside the shared reach even when both authored endpoint grips are reachable.
    for track in rig.animation_data.nla_tracks:
        action=track.strips[0].action
        rig.animation_data.action=action
        for frame,pose,loc in f.motion_keys[track.name]:
            matrix=motion.matrix(pose,'hand.R',loc)
            point=matrix@np.r_[list(hand),1]
            local=np.linalg.inv(motion.matrix(pose,'chest',loc))@point
            rig.pose.bones['grip.R'].location=api['Vector'](local[:3])-hand
            rig.pose.bones['grip.R'].keyframe_insert('location',frame=frame)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        if curve.data_path=='pose.bones["grip.R"].location':
                            for key in curve.keyframe_points:key.interpolation='LINEAR'
    run_path(str(Path(__file__).with_name('kader_motion.py')))['bake_linked_grip'](rig,f,api,motion)


def configure_import(dst):
    path=dst.with_suffix('.glb.import')
    if path.exists():
        path.write_text(path.read_text(encoding='utf-8').replace('meshes/generate_lods=true','meshes/generate_lods=false'),encoding='utf-8')


for h in heroes:
    if h.get('kit')!='roster' or only and h['id'] not in only: continue
    dst=ROOT/'assets/models/heroes'/f'{h["id"]}.glb'
    if '--importe' in args:
        configure_import(dst)
        continue
    f,height,hand=build(h)
    bpy.context.scene.render.fps=96 if h['silhouette']=='anchor' else 24
    rig=f.bauen()
    animate(h,rig,f)
    linked_grip(h,rig,f)
    if hasattr(f,'chain_root'):
        run_path(str(Path(__file__).with_name('kader_chain.py')))['bake'](rig,f,api)
    for o in bpy.context.scene.objects: o.select_set(o in (rig,f.ob))
    bpy.context.view_layer.objects.active=rig
    dst=ROOT/'assets/models/heroes'/f'{h["id"]}.glb'
    bpy.ops.export_scene.gltf(filepath=str(dst),export_format='GLB',use_selection=True,export_animations=True,
                             export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True,export_apply=False,
                             export_force_sampling=True,export_frame_step=1)
    configure_import(dst)
    profile={'body_materials':['bda18c','473b34','c99b82'],'joint_radius':.2,'run_rate':192,'parts':[
        {'name':'cape','parent':'chest','materials':['242d42'],'joints':['chest'],
         'bounds':[[-.5,-.5,.4],[.5,-.2,height*.8]],'axis':2,'start':height*.78,'end':.44,
         'anchors':[[0,-.28,height*.76],[0,-.33,height*.5],[0,-.38,.45]],'gain':.8,'limit':6,'subdivide':1}]}
    if h['silhouette'] in ('fire','ice','lantern','mirror','crow','shovel','wolf'):
        profile['parts'].append({'name':'robe','parent':'hips','materials':['d1c9b5' if h['silhouette']=='lantern' else h['color']],
            'joints':['hips'],'bounds':[[-.5,-.5,.2],[.5,.5,height*.47]],'axis':2,'start':height*.46,'end':.24,
            'anchors':[[0,0,height*.45],[0,0,height*.29],[0,0,.25]],'gain':.45,'limit':4,'subdivide':2})
    run_path(str(Path(__file__).with_name('rig_fluid.py')))['apply_to_glb'](dst,profile)
    print('KADER_EXPORT',h['id'],len(f.ob.data.polygons),flush=True)
    bpy.data.objects.remove(f.ob,do_unlink=True)
    bpy.data.objects.remove(rig,do_unlink=True)
print('KADER_FERTIG',flush=True)
