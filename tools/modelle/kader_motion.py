"""Individuell komponierte Bollwerk-Posen und geprüfte Waffenbahnen (Blender +Y vorwärts).
Keine Laufzeit-IK: Zielpunkte, Handgelenkrollen und Nachbewegung werden ins GLB gebacken.
"""
import math, copy
import numpy as np
from pathlib import Path
from runpy import run_path
X,Y,Z=(1,0,0),(0,1,0),(0,0,1)
# Schritthöhe, Armhub, Vorneigung, Hüftwiegen, Angriffstakt und Grundhaltung je Figur.
STYLE={
 'brennholt':(27,10,7,3,24,'shield'), 'mira':(23,24,10,6,29,'stone'),
 'grauhirte':(25,9,12,4,27,'staff'), 'sirra':(38,26,13,2,17,'daggers'),
 'kaspar':(28,3,5,2,23,'crossbow'), 'yuna':(36,25,8,2,19,'sword'),
 'orrin':(26,8,4,2,26,'fire'), 'ilsabet':(24,6,8,3,28,'ice'),
 'tamo':(30,15,7,4,25,'fork'), 'albe':(25,8,2,2,26,'lantern'),
 'fenn':(35,15,10,2,21,'bow'), 'ralda':(27,19,6,5,29,'hammer'),
 'varg':(35,30,12,5,20,'axes'), 'lior':(26,8,1,2,25,'mirror'),
 'kraehenfrau':(26,15,10,4,26,'crow'), 'bruno':(24,20,5,7,28,'barrel'),
 'tessa':(36,18,8,3,21,'sail'), 'totengraeber':(25,13,14,3,28,'shovel'),
 'ada':(28,18,4,4,28,'bell'), 'sorek':(27,20,11,5,30,'anchor')}


def merge(a,b):
    return {**copy.deepcopy(a),**copy.deepcopy(b)}


def stance(kind):
    poses={
      'shield':{'arm.L':[(X,35)],'fore.L':[(X,55)],'arm.R':[(X,12)],'chest':[(Z,-5)]},
      'stone':{'arm.L':[(Y,-12)],'arm.R':[(Y,12)],'chest':[(X,-3)],'head':[(X,6)]},
      'staff':{'arm.R':[(X,12),(Y,-10)],'chest':[(X,7)],'head':[(X,-6)]},
      'daggers':{'arm.L':[(X,25),(Y,-30)],'arm.R':[(X,15),(Y,25)],'chest':[(X,-8),(Z,-8)]},
      'crossbow':{'arm.R':[(X,65),(Y,8)],'arm.L':[(X,70),(Y,-35)],'fore.L':[(X,32)],'chest':[(Z,-12)]},
      'sword':{'arm.R':[(X,18),(Y,-15)],'arm.L':[(X,8),(Y,-20)],'hips':[(Z,-8)]},
      'fire':{'arm.L':[(X,28),(Y,-25)],'fore.L':[(X,18)],'arm.R':[(X,10)],'head':[(X,5)]},
      'ice':{'arm.R':[(X,14)],'arm.L':[(Y,-12)],'head':[(Z,5)]},
      'fork':{'arm.R':[(X,20),(Y,-15)],'arm.L':[(X,10)],'chest':[(X,4)]},
      'lantern':{'arm.R':[(X,24)],'fore.R':[(X,15)],'arm.L':[(Y,-15)],'head':[(X,-4)]},
      'bow':{'arm.R':[(X,45)],'arm.L':[(X,30),(Y,-15)],'hips':[(Z,10)]},
      'hammer':{'arm.R':[(X,18)],'arm.L':[(X,12),(Y,-20)],'head':[(X,4)]},
      'axes':{'arm.L':[(X,18),(Y,-20)],'arm.R':[(X,18),(Y,20)],'chest':[(X,-6)]},
      'mirror':{'arm.R':[(X,28),(Y,-10)],'arm.L':[(Y,-25)],'head':[(Z,-4)]},
      'crow':{'arm.L':[(X,42),(Y,-25)],'fore.L':[(X,30)],'arm.R':[(X,12)],'head':[(Z,8)]},
      'barrel':{'chest':[(X,-4),(Z,5)],'arm.R':[(X,20)],'arm.L':[(Y,-15)]},
      'sail':{'arm.R':[(X,40)],'arm.L':[(X,20),(Y,-20)],'hips':[(Z,-8)],'head':[(Z,5)]},
      'shovel':{'arm.R':[(X,12),(Y,-8)],'chest':[(X,10)],'head':[(X,-5)]},
      'bell':{'arm.R':[(X,15)],'arm.L':[(X,8)],'head':[(X,-5)]},
      'anchor':{'arm.R':[(X,-8),(Y,15)],'arm.L':[(X,20)],'chest':[(Z,7)]}}
    result=copy.deepcopy(poses[kind])
    if kind=='crossbow': result['fore.R']=[(X,-65)]
    return result


def attack(kind,index):
    sign=-1 if index==1 else 1
    wind={'arm.R':[(X,90),(Z,-28*sign)],'fore.R':[(X,20)],'chest':[(X,8),(Z,-18*sign)],'hips':[(Z,-7*sign)]}
    hit={'arm.R':[(X,35),(Z,32*sign)],'fore.R':[(X,-18)],'chest':[(X,-16),(Z,18*sign)],'hips':[(Z,8*sign)]}
    if kind=='shield':
        if index==1:
            wind.update({'arm.L':[(X,20)],'fore.L':[(X,35)]})
            hit.update({'arm.L':[(X,80)],'fore.L':[(X,10)],'arm.R':[(X,15)]})
        else: hit['arm.L']=[(X,45),(Y,-20)]
    elif kind=='stone':
        arm='L' if index==1 else 'R'
        wind={f'arm.{arm}':[(X,-35),(Y,sign*25)],'chest':[(Z,-20*sign),(X,10)],'hips':[(Z,-8*sign)]}
        hit={f'arm.{arm}':[(X,95)],f'fore.{arm}':[(X,-15)],'chest':[(X,-20),(Z,22*sign)],'head':[(X,5)]}
    elif kind=='daggers':
        side='L' if index==1 else 'R'
        wind={f'arm.{side}':[(X,60),(Y,sign*40)],f'fore.{side}':[(X,55)],'chest':[(Z,-25*sign),(X,-4)]}
        hit={f'arm.{side}':[(X,100),(Y,-sign*10)],f'fore.{side}':[(X,-15)],'chest':[(Z,15*sign),(X,-16)]}
        if index<2:
            wind['chest']=[(Z,-5*sign),(X,3)]
            hit['chest']=[(Z,5*sign),(X,-4)]
        if index==2:
            wind=merge(wind,{'arm.L':[(X,95),(Y,-40)],'fore.L':[(X,20)]})
            hit=merge(hit,{'arm.L':[(X,65),(Y,20)],'fore.L':[(X,-15)]})
    elif kind in ('crossbow','bow','sail'):
        if kind=='crossbow':
            wind=stance(kind)
            hit=merge(wind,{'chest':[(X,9),(Z,-15)],'arm.R':[(X,58)],'head':[(X,-5)]})
        else:
            wind={'arm.R':[(X,78),(Y,-22)],'fore.R':[(X,12)],'arm.L':[(X,85),(Y,35)],'fore.L':[(X,60)],'chest':[(Z,-24)]}
            hit=merge(wind,{'arm.L':[(X,60),(Y,60)],'fore.L':[(X,12)],'chest':[(Z,-15),(X,-5)]})
            if kind=='sail': hit['hips']=[(Z,-12),(X,-4)]
    elif kind in ('fire','ice','lantern','mirror','crow'):
        wind={'arm.R':[(X,30),(Y,25)],'fore.R':[(X,25)],'chest':[(X,6),(Z,-8)],'head':[(X,4)]}
        hit={'arm.R':[(X,72),(Y,-20)],'fore.R':[(X,-12)],'chest':[(X,-7),(Z,8)],'head':[(X,-5)]}
        if kind=='lantern': wind['arm.R']=[(X,45)];hit['arm.R']=[(X,70)];hit['arm.L']=[(X,65),(Y,-35)]
        if kind=='mirror': wind['arm.R']=[(X,70),(Y,40)];hit['arm.R']=[(X,65),(Y,-40)]
        if kind=='crow':
            wind={'arm.L':[(X,45)],'fore.L':[(X,35)],'head':[(Z,10)]}
            hit={'arm.L':[(X,100),(Y,-20)],'fore.L':[(X,-20)],'chest':[(X,-8),(Z,10)]}
        if kind=='fire':
            wind['arm.L']=[(X,30),(Y,-20)];hit['arm.L']=[(X,30),(Y,-20)]
        if kind=='ice': hit['head']=[(X,-6),(Z,-7)]
    elif kind in ('fork','staff','shovel'):
        wind={'arm.R':[(X,-20),(Y,15)],'fore.R':[(X,35)],'arm.L':[(X,30)],'chest':[(X,10),(Z,-12)]}
        hit={'arm.R':[(X,90),(Y,-15)],'fore.R':[(X,-15)],'arm.L':[(X,40)],'chest':[(X,-18),(Z,12)]}
        if kind=='shovel': hit['arm.R']=[(X,35),(Z,40*sign)];wind['arm.R']=[(X,110),(Z,-30*sign)]
    elif kind=='hammer':
        wind={'arm.R':[(X,140),(Y,20)],'fore.R':[(X,30)],'chest':[(X,12),(Z,-14)],'arm.L':[(X,60)]}
        hit={'arm.R':[(X,28),(Y,-30)],'fore.R':[(X,-22)],'chest':[(X,-24),(Z,16)],'hips':[(X,-8)],'arm.L':[(X,15)]}
    elif kind=='axes':
        if index==1:
            wind={k.replace('.R','.L'):v for k,v in wind.items()}
            hit={k.replace('.R','.L'):v for k,v in hit.items()}
        if index==2:
            wind.update({'arm.L':[(X,135),(Y,-20)],'arm.R':[(X,135),(Y,20)],'chest':[(X,15)]})
            hit.update({'arm.L':[(X,30),(Y,15)],'arm.R':[(X,30),(Y,-15)],'chest':[(X,-25)]})
    elif kind=='barrel':
        wind={'arm.R':[(X,35),(Y,45)],'chest':[(Z,-20),(X,-8)],'hips':[(Z,-8)],'arm.L':[(Y,-35)]}
        hit={'arm.R':[(X,80),(Y,-35)],'fore.R':[(X,10)],'chest':[(X,-12),(Z,22)],'hips':[(Z,8)]}
    elif kind=='bell':
        wind={'arm.R':[(X,-35),(Z,15)],'chest':[(X,8),(Z,-12)],'arm.L':[(X,15)]}
        hit={'arm.R':[(X,105),(Z,-15)],'fore.R':[(X,10)],'chest':[(X,-15),(Z,12)],'head':[(X,8)]}
    elif kind=='anchor':
        wind={'arm.R':[(X,35),(Z,-65*sign)],'fore.R':[(X,25)],'chest':[(Z,-25*sign),(X,10)],'arm.L':[(X,30)]}
        hit={'arm.R':[(X,85),(Z,45*sign)],'fore.R':[(X,-15)],'chest':[(Z,28*sign),(X,-18)],'hips':[(Z,10*sign)]}
    if index==2 and kind in ('shield','staff','fork','sword','shovel'):
        wind['arm.R']=[(X,145),(Y,15)]
        hit['chest']=[(X,-24),(Z,12)]
        hit['thigh.L']=[(X,22)];hit['shin.L']=[(X,-22)]
    # Blender +X is the left side. A right-hand forehand chambers to the right
    # (+Z torso turn) and follows through to the centre (-Z), not the reverse.
    if kind in ('shield','sword','staff','fork','shovel','hammer','bell','barrel','axes') or kind=='daggers' and index==2:
        side=-1 if kind=='axes' and index==1 else 1
        symmetric=kind in ('axes','daggers') and index==2
        wind['chest']=[(X,6),(Z,0 if symmetric else 18*side)]
        hit['chest']=[(X,-8),(Z,0 if symmetric else -18*side)]
        wind['hips']=[(Z,0 if symmetric else 5*side)]
        hit['hips']=[(Z,0 if symmetric else -5*side)]
    if kind=='anchor':
        wind['chest']=[(X,6),(Z,15)]
        hit['chest']=[(X,-8),(Z,-15)]
        wind['hips']=[(Z,4)];hit['hips']=[(Z,-4)]
    return wind,hit


def cast(kind,op,slot):
    wind,hit=attack(kind,0)
    if op in ('guard','buff','form'):
        wind={'arm.L':[(X,30),(Y,-25)],'arm.R':[(X,30),(Y,25)],'chest':[(X,9)],'head':[(X,8)]}
        hit={'arm.L':[(X,75),(Y,-65)],'arm.R':[(X,75),(Y,65)],'chest':[(X,-10)],'head':[(X,-12)]}
    elif op in ('zone','beacon','turret','wall','summon'):
        wind={'arm.R':[(X,80),(Y,20)],'fore.R':[(X,45)],'arm.L':[(X,40),(Y,-25)],'chest':[(X,8)]}
        hit={'arm.R':[(X,35),(Y,-15)],'fore.R':[(X,-15)],'arm.L':[(X,30)],'chest':[(X,-22)],'hips':[(X,-8)],'thigh.L':[(X,25)],'shin.L':[(X,-35)]}
        if kind in ('lantern','crow','mirror','ice','fire'):
            hit={'arm.L':[(X,75),(Y,-65)],'arm.R':[(X,75),(Y,65)],'chest':[(X,-10)],'head':[(X,-8)]}
    elif op in ('taunt','sun','revive'):
        wind={'arm.R':[(X,45)],'arm.L':[(X,25),(Y,-15)],'head':[(X,8)],'chest':[(X,6)]}
        hit={'arm.R':[(X,140),(Y,10)],'arm.L':[(X,95),(Y,-75)],'head':[(X,-18)],'chest':[(X,-12)]}
    elif op in ('dash','blink','beacon_blink','swap'):
        wind={'chest':[(X,18)],'hips':[(X,8)],'thigh.L':[(X,25)],'shin.L':[(X,-45)],'arm.R':[(X,-30)],'arm.L':[(X,25)]}
        hit={'chest':[(X,-28)],'arm.R':[(X,25)],'arm.L':[(X,-25)],'thigh.R':[(X,35)],'shin.R':[(X,-25)],'head':[(X,12)]}
    elif op in ('meteor','chain'):
        wind={'arm.R':[(X,145),(Y,15)],'fore.R':[(X,25)],'head':[(X,-15)],'chest':[(X,10)],'arm.L':[(Y,-40)]}
        hit={'arm.R':[(X,55),(Y,-10)],'fore.R':[(X,-15)],'head':[(X,10)],'chest':[(X,-22)],'hips':[(X,-7)]}
    if slot==3:
        wind=merge(wind,{'head':[(X,-18)],'hips':[(X,7)],'chest':[(X,14)]})
        hit=merge(hit,{'chest':[(X,-22)],'arm.L':[(X,100),(Y,-55)]})
    return wind,hit


def write_actions(h,f,rig,api):
    step,swing,lean,waddle,tempo,kind=STYLE[h['id']]
    a=api['Anim'](rig)
    a.continuous=h['id']=='brennholt'
    f.motion_keys={}
    def action(name,keys):
        if kind=='anchor':keys=[(frame*4,pose,loc) for frame,pose,loc in keys]
        f.motion_keys[name]=keys
        a.action(name,keys)
    motion_class=run_path(str(Path(__file__).with_name('rig_motion.py')))['MotionRig']
    constraints={'torso':f.weapon_torso,'limits':[[-60,155],[-100,100],[-120,120],[-140,140],[-80,80]]}
    motion=motion_class(f.bones,getattr(f,'weapon_specs',{}),constraints)
    grips={}
    for side in ('L','R'):
        point=list(f.J['hand.'+side][0])
        grips[side]={'bone':'weapon.'+side,'driver':'fore.'+side,'head':point,'grip':point,'shaft':[0,0,-1],'blade_normal':[0,1,0]}
    hand_motion=motion_class(f.bones,grips,constraints)
    def rotation_pose(matrix):
        q=api['Matrix'](matrix.tolist()).to_quaternion()
        return [(tuple(q.axis),math.degrees(q.angle))]
    def brennholt_arm(pose,phase,loc):
        # Anatomical FK: one elbow hinge plane, forearm rotation separate from
        # the wrist. Controlled wrist pitch keeps the blade diagonally forward
        # at the end of the cut without changing the elbow extension.
        def unit(v):return v/np.linalg.norm(v)
        def frame(direction,normal):return np.column_stack((direction,normal,np.cross(direction,normal)))
        arm=motion.bones['arm.R'];fore=motion.bones['fore.R']
        rest_upper=unit(fore['head']-arm['head'])
        rest_lower=unit(np.array(motion.weapons['weapon_R']['grip'])-fore['head'])
        rest_normal=unit(np.cross(rest_upper,rest_lower))
        elevation,flexion={'guard':(-40,70),'wind':(15,95),'cut':(-5,85),
                           'hit':(-20,45),'follow':(-25,6)}[phase]
        chest=motion.matrix(pose,'chest',loc)[:3,:3]
        normal=chest@unit(np.array([.995,0,.10]))
        forward=chest@np.array([0.,1.,0.]);up=np.cross(normal,forward)
        def direction(degrees):
            angle=math.radians(degrees)
            return math.cos(angle)*forward+math.sin(angle)*up
        upper=frame(direction(elevation),normal)@frame(rest_upper,rest_normal).T
        lower=frame(direction(elevation+flexion),normal)@frame(rest_lower,rest_normal).T
        # Sword grip follows the supplied side-view sketch: blade above the fist,
        # then tilting forward to horizontal; it must not hang below the fist.
        # Slight wrist anticipation/release, without changing the approved arm path.
        wrist_pitch={'guard':0,'wind':4,'cut':-6,'hit':-2,'follow':37}[phase]
        shaft=direction(elevation+flexion-20+wrist_pitch)
        hand=np.column_stack((np.cross(normal,shaft),normal,shaft))
        # Small radial/ulnar cant around the palm's transverse axis; no free twist.
        cant=math.radians({'guard':0,'wind':-3,'cut':-6,'hit':0,'follow':5}[phase])
        hand=hand@np.array([[math.cos(cant),-math.sin(cant),0],
                           [math.sin(cant),math.cos(cant),0],[0,0,1]])
        parent=motion.matrix(pose,arm['parent'],loc)[:3,:3]
        return merge(pose,{'arm.R':rotation_pose(parent.T@upper),'fore.R':rotation_pose(upper.T@lower),
                           'twist.R':[],'hand.R':rotation_pose(lower.T@hand)})
    def brennholt_pronate(pose,velocity,loc):
        # Turn radius/ulna and the complete fist together, never roll the wrist.
        w=motion.weapons['weapon_R']
        fore=motion.matrix(pose,'fore.R',loc)[:3,:3]
        axis=fore@(np.array(w['grip'])-motion.bones['fore.R']['head']);axis/=np.linalg.norm(axis)
        normal=motion.matrix(pose,'weapon.R',loc)[:3,:3]@np.array([0.,1.,0.])
        target=np.cross(axis,velocity);target/=np.linalg.norm(target)
        if target@normal<0:target=-target
        angle=math.degrees(math.atan2(axis@np.cross(normal,target),normal@target))
        local=fore.T@axis
        return merge(pose,{'twist.R':list(pose.get('twist.R',[]))+[(tuple(local),angle)]})
    def anchor_pose(pose,point,direction,loc=None):
        matrix=hand_motion.matrix(pose,'chest',loc)
        point=(matrix@np.r_[point,1])[:3]
        direction=matrix[:3,:3]@np.array(direction)
        pose,error=hand_motion.fit_grip(pose,'R',point,loc,direction=direction)
        if error>.16: raise ValueError(f'Sorek grip unreachable: {error:.3f}')
        direction=hand_motion.matrix(pose,'weapon.R',loc)[:3,:3]@hand_motion.weapons['R']['shaft']
        actual=(hand_motion.matrix(pose,'weapon.R',loc)@np.r_[grips['R']['grip'],1])[:3]
        support=actual+.18*direction
        pose,error=hand_motion.fit_grip(pose,'L',support,loc,direction=direction)
        if error>.18: raise ValueError(f'Sorek support hand unreachable: {error:.3f}')
        return pose
    height=max(b[2].z for b in f.bones)
    def equipped(pose,phase='guard',index=0,loc=None):
        """Place the fist first, then orient the real held object around that grip.
        Outside elbow poles and forward hand space replace unconstrained tip-only IK.
        """
        if kind=='anchor':
            # Drei verschiedene Ankerschläge (2026-11-17): von rechts oben herein, Rückschwung von links,
            # Überkopf-Schmetterschlag mit Ausfallschritt. Richtung = wohin der Ankerkopf zeigt.
            if phase=='wind':
                point,direction=[([.03,.44,1.70],[-.45,.12,.87]),([.18,.42,1.62],[.55,.15,.82]),([.04,.32,1.82],[.05,-.35,.94])][index]
                return anchor_pose(pose,point,direction,loc)
            if phase=='hit':
                point,direction=[([.12,.44,1.40],[.18,.88,-.43]),([.05,.43,1.42],[-.24,.86,-.45]),([.07,.46,1.38],[.04,.66,-.75])][index]
                return anchor_pose(pose,point,direction,loc)
            return anchor_pose(pose,[.10,.44,1.35],[0,.55,-.83],loc)
        result=dict(pose)
        for weapon,w in motion.weapons.items():
            side='L' if weapon.endswith('L') else 'R';sign=1 if side=='L' else -1
            if h['id']=='brennholt' and side=='R':
                result=brennholt_arm(result,phase,loc)
                continue
            if kind in ('crossbow','bow','sail'):
                point=[-.12,.45,height*.60] if kind=='crossbow' else [-.18,.82,height*.76]
                direction=[0,1,0]
                if kind=='crossbow' and phase=='wind':
                    # Spannen: Armbrust sinkt vor den Bauch und zeigt schräg nach unten.
                    point=[-.12,.40,height*.52];direction=[0,.86,-.5]
                elif kind=='crossbow' and phase=='hit':
                    direction=[0,.97,.24]
                elif kind in ('bow','sail') and phase!='guard' and index==1:
                    # Schnellschuss aus der Hocke: Bogen tiefer und flacher.
                    point=[-.22,.80,height*.66];direction=[0,1,-.05]
                elif kind in ('bow','sail') and phase!='guard' and index==2:
                    # Kraftschuss: Bogen hoch, schräg nach oben, Sehne weit zurück.
                    point=[-.16,.78,height*.84];direction=[0,.93,.36]
            elif kind in ('fire','ice','lantern','mirror','crow'):
                point=[sign*.53,.42,height*.58]
                direction=[0,.18,1] if phase=='guard' else [0,.60,.80]
                if phase=='wind':point=[sign*.60,.30,height*.75]
            else:
                point=[sign*.59,.38,height*.48]
                direction=[0,.12,1]
                active=not (kind in ('axes','daggers') and index<2 and (side=='L')!=(index==1))
                if active and phase=='wind':
                    point=[sign*.72,.32,height*.72]
                    direction=[sign*.2,.20,.96]
                    if index==1 and kind not in ('axes','daggers'):
                        point=[sign*.78,.32,height*.60]
                        direction=[sign*.55,.75,.32]
                elif active and phase=='hit':
                    point=[sign*.26,.68,height*.60]
                    direction=[-sign*.16,.98,.02]
                    if kind=='axes' and index==2:
                        point=[sign*.42,.70+(0.1 if side=='L' else 0),height*.63]
                        direction=[-sign*.2,.98,.02]
            if kind=='barrel':
                point=[sign*.70,.50,height*.52]
                direction=[0,.05,1]
                if phase=='wind':point=[sign*.72,.45,height*.72]
                elif phase=='hit':point=[sign*.55,.70,height*.62]
            if kind=='bell' and phase=='guard':
                point=[sign*.72,.50,height*.50]
            if kind in ('shield','sword') and phase=='guard':
                point=[sign*.60,.45,height*.57]
                direction=[0,1,.08]
            if kind=='daggers':
                point=[sign*.55,.42,height*.58];direction=[0,1,.02]
                if active and index<2 and phase=='wind':point=[sign*.50,.26,height*.58]
                elif active and index<2 and phase=='hit':point=[sign*.38,.75,height*.58]
                elif active and index==2 and phase!='guard':
                    point=[sign*.72,.32,height*.72] if phase=='wind' else [sign*.30,.70,height*.60]
                    direction=[sign*.2,.2,.96] if phase=='wind' else [-sign*.3,.95,.02]
            matrix=motion.matrix(result,'chest',loc)
            point=(matrix@np.r_[point,1])[:3]
            direction=matrix[:3,:3]@np.array(direction)
            result,error=motion.fit_grip(result,weapon,point,loc,direction=direction)
            if kind=='axes' and (phase=='guard' or not active):
                result=motion.align_face(result,weapon,matrix[:3,:3]@np.array([0,1,0]),[1,0,0],loc,False)
            if error>.18:raise ValueError(f'{h["id"]}/{phase}/{weapon}: grip error {error:.3f}')
        if kind=='shield':
            # Shield stays ahead of the breastplate; sword hand works beside it.
            # Zweiter Schlag (2026-11-17): Schild holt aus und stößt beim Treffer nach vorn (Schildstoß).
            matrix=hand_motion.matrix(result,'chest',loc)
            spot=[.58,.50,height*.57]
            if index==1 and phase=='wind':spot=[.64,.30,height*.55]
            elif index==1 and phase in ('hit','follow'):spot=[.40,.78,height*.60]
            point=(matrix@np.array(spot+[1.0]))[:3]
            direction=matrix[:3,:3]@np.array([0.,1.,0.])
            result,error=hand_motion.fit_grip(result,'L',point,loc,direction=direction)
            if error>.18:raise ValueError('Shield grip unreachable')
            # Shield's rest normal is -Z after its grip-space rotation.
        elif kind in ('crossbow','bow','sail'):
            point=[-.12,.66,height*.60] if kind=='crossbow' else [-.18,.58,height*.78]
            if kind=='crossbow' and phase=='wind':point=[-.12,.58,height*.46]
            elif kind=='crossbow' and phase=='hit':point=[-.12,.66,height*.645]
            if kind!='crossbow' and phase=='wind':point=[-.18,.30,height*.78]
            if kind in ('bow','sail') and phase!='guard' and index==1:
                point=[-.22,.36 if phase=='wind' else .60,height*.68]
            elif kind in ('bow','sail') and phase!='guard' and index==2:
                point=[-.16,.16 if phase=='wind' else .52,height*.88]
            matrix=hand_motion.matrix(result,'chest',loc)
            point=(matrix@np.r_[point,1])[:3]
            result,error=hand_motion.fit_grip(result,'L',point,loc)
            if error>.18:raise ValueError(f'{h["id"]}: support grip unreachable {error:.3f}')
        return result
    base=stance(kind)
    if h['id']=='brennholt':
        base=merge(base,{'clavicle.R':[(Y,2),(Z,-2)],'clavicle.L':[(Y,-3),(Z,4)]})
    base=equipped(base)
    inhale=merge(base,{'chest':[(X,-2)],'head':[(X,2)]})
    action('idle',[(1,base,None),(25,inhale,(0,0,.008)),(49,base,None)])
    frames=[]
    for k in range(17):
        phase=k*math.tau/16
        s,c=math.sin(phase),abs(math.cos(phase))
        p=merge(base,{'thigh.L':[(X,step*s)],'thigh.R':[(X,-step*s)],
          'shin.L':[(X,-max(0,-math.sin(phase+.9))*48)],'shin.R':[(X,-max(0,math.sin(phase+.9))*48)],
          'hips':[(X,lean),(Z,-waddle*s)],'chest':[(X,-lean*.3),(Z,waddle*s)],'head':[(X,-lean*.5),(Z,-waddle*.4*s)]})
        for side,sign in [('L',-1),('R',1)]:
            p['arm.'+side]=p.get('arm.'+side,[])+[(X,swing*s*sign)]
        # Keep carried equipment clear while the chest counter-rotates over the gait.
        # Empty hands keep their authored arm swing.
        p=equipped(p)
        frames.append((1+k,p,(0,0,.025*(c-.5))))
    action('run',frames)
    def align_strike(wind,hit,index,windloc=None,hitloc=None):
        if kind not in ('shield','sword','daggers','axes','shovel','hammer'):return wind,hit
        for weapon in motion.weapons:
            if kind in ('axes','daggers') and index<2 and weapon.endswith('L')!=(index==1):continue
            # Off-axis axe/hammer heads move as the grip rolls: solve using the final contact path.
            for _iteration in range(12):
                velocity=motion.weapon_head(hit,weapon,hitloc)-motion.weapon_head(wind,weapon,windloc)
                if h['id']=='brennholt':
                    hit=brennholt_pronate(hit,velocity,hitloc)
                elif kind=='daggers' and index<2:
                    for pose,loc in ((wind,windloc),(hit,hitloc)):
                        target=(motion.matrix(pose,motion.weapons[weapon]['bone'],loc)@np.r_[motion.weapons[weapon]['grip'],1])[:3]
                        fitted,_=motion.fit_grip(pose,weapon,target,loc,direction=velocity)
                        pose.update(fitted)
                elif kind=='hammer':
                    wind=motion.align_face(wind,weapon,velocity,[1,0,0],windloc)
                    hit=motion.align_face(hit,weapon,velocity,[1,0,0],hitloc)
                else:
                    wind=motion.align_edge(wind,weapon,velocity,windloc)
                    hit=motion.align_edge(hit,weapon,velocity,hitloc)
        return wind,hit
    # --- Echte Dreierfolgen (2026-11-16): Schrägschlag, Rückhand, Überkopfhieb -------------------
    # Jeder Schlag hat Ausholen, Treffer und Nachschwung als eigene Griffpunkte. Die Punkte stehen
    # relativ zur Schulter in Armlängen (x nach außen, y vorwärts, z oben), die Richtung ist die der
    # Waffe. So passen sie für Zwerge, Menschen und die Felsenwächterin ohne eigene Zahlen je Figur.
    SLASH=[((.30,-.10,.40),(.35,-.35,.87)),((-.45,.78,-.12),(-.45,.88,-.10)),((-.60,.55,-.40),(-.75,.50,-.40))]
    BACKHAND=[((-.75,.40,-.05),(-.85,.20,.45)),((.05,.90,-.10),(.55,.83,.0)),((.55,.55,-.05),(.95,.20,.20))]
    OVERHEAD=[((-.10,-.05,.75),(0,-.55,.83)),((-.25,.82,.18),(0,.84,.54)),((-.25,.80,-.08),(0,.97,.22))]
    THRUST=[((.10,-.15,.15),(0,.20,.98)),((-.20,.85,.10),(0,.95,.30)),((-.20,.80,.0),(0,1,.10))]
    PLANT=[((.0,.10,.80),(0,.10,1)),((-.15,.70,-.20),(0,.50,.86)),((-.15,.68,-.30),(0,.42,.91))]
    PUNCH=[((.30,-.35,.0),(0,1,.20)),((-.30,.90,.05),(-.20,.97,.10)),((-.45,.75,-.15),(-.40,.90,-.10))]
    SLAM=[((-.15,.0,.85),(0,.30,.95)),((-.25,.80,-.40),(0,.70,-.70)),((-.25,.70,-.60),(0,.55,-.84))]
    BODY=[
      ({'chest':[(X,6),(Z,20)],'hips':[(Z,6)],'head':[(Z,-10)]},
       {'chest':[(X,-12),(Z,-22)],'hips':[(Z,-8)],'thigh.L':[(X,14)],'shin.L':[(X,-14)]},
       {'chest':[(X,-14),(Z,-30)],'hips':[(Z,-12)],'thigh.L':[(X,14)],'shin.L':[(X,-14)],'head':[(Z,12)]}),
      ({'chest':[(X,4),(Z,-24)],'hips':[(Z,-6)],'head':[(Z,10)]},
       {'chest':[(X,-8),(Z,20)],'hips':[(Z,8)],'thigh.R':[(X,14)],'shin.R':[(X,-14)]},
       {'chest':[(X,-8),(Z,30)],'hips':[(Z,12)],'thigh.R':[(X,14)],'shin.R':[(X,-14)],'head':[(Z,-12)]}),
      ({'chest':[(X,16)],'hips':[(X,4)],'head':[(X,-12)]},
       {'chest':[(X,-28)],'hips':[(X,-10)],'thigh.L':[(X,28)],'shin.L':[(X,-30)],'head':[(X,10)]},
       {'chest':[(X,-32)],'hips':[(X,-12)],'thigh.L':[(X,30)],'shin.L':[(X,-34)],'head':[(X,8)]})]
    def mirror_body(pose):
        return {bone:[(axis,-angle if axis==Z else angle) for axis,angle in turns] for bone,turns in pose.items()}
    def place(pose,side,offset,direction,loc):
        sign=1 if side=='L' else -1
        shoulder=np.array(f.J['arm.'+side][0]);elbow=np.array(f.J['fore.'+side][0]);fist=np.array(f.J['hand.'+side][0])
        reach=np.linalg.norm(elbow-shoulder)+np.linalg.norm(fist-elbow)
        chest=motion.matrix(pose,'chest',loc)
        target=shoulder+reach*np.array([sign*offset[0],offset[1],offset[2]])
        aim=chest[:3,:3]@np.array([sign*direction[0],direction[1],direction[2]])
        weapon=next((name for name in motion.weapons if name.endswith(side)),None)
        solver,key=(motion,weapon) if weapon else (hand_motion,side)
        fitted=pose
        for _attempt in range(7):
            fitted,error=solver.fit_grip(pose,key,(chest@np.r_[target,1])[:3],loc,direction=aim)
            if error<=.12:break
            target=shoulder+(target-shoulder)*.9   # außer Reichweite: Punkt zur Schulter ziehen
        return fitted
    def strike_keys(index):
        dual=kind in ('axes','daggers')
        caster=kind in ('fire','ice','lantern','mirror','crow')
        if kind=='stone': path=[PUNCH,PUNCH,SLAM][index]
        elif caster: path=[THRUST,BACKHAND,PLANT][index]
        elif dual: path=[SLASH,SLASH,OVERHEAD][index]
        else: path=[SLASH,BACKHAND,OVERHEAD][index]
        left=kind in ('stone','axes','daggers') and index==1
        sides=['L','R'] if kind in ('stone','axes','daggers') and index==2 else ['L' if left else 'R']
        body=BODY[index]
        if left: body=tuple(mirror_body(part) for part in BODY[0])
        scale=.55 if caster else 1.0   # Zauberer drehen den Körper weniger weit
        locs=[(0,-.05,.02),(.0,.12,-.04),(.0,.15,-.055)]
        poses=[]
        for step,part in enumerate(body):
            part={bone:[(axis,angle*scale) for axis,angle in turns] for bone,turns in part.items()}
            pose=equipped(merge(base,part),'guard',index,locs[step])
            for side in sides:
                pose=place(pose,side,path[step][0],path[step][1],locs[step])
            poses.append(pose)
        wind,hit,follow=poses
        if not caster:
            wind,hit=align_strike(wind,hit,index,locs[0],locs[1])
            _unused,follow=align_strike(copy.deepcopy(wind),follow,index,locs[0],locs[2])
        # Takt: ruhig ausholen, kurz halten, in zwei Bildern zuschlagen, ausschwingen, zurück.
        frames=[max(3,int(tempo*.24)),max(5,int(tempo*.38)),max(7,int(tempo*.5)),max(10,int(tempo*.66))]   # .38/.5 prüft weapon_qa.py
        return [(1,base,None),(frames[0],wind,locs[0]),(frames[1],wind,locs[0]),(frames[2],hit,locs[1]),
                (frames[3],follow,locs[2]),(tempo,base,None)]
    NEW_COMBO=('sword','staff','fork','shovel','hammer','bell','barrel','axes','daggers','stone',
               'fire','ice','lantern','mirror','crow')
    authored={}
    for index,name in enumerate(['attack_combo_1','attack_combo_2','attack_combo_finish']):
        if kind in NEW_COMBO and h['id']!='brennholt':
            authored[name]=strike_keys(index)
            action(name,authored[name])
            continue
        wind,hit=attack(kind,index)
        wind=merge(base,wind);hit=merge(base,hit)
        windloc=(0,-.04,.025);hitloc=(.06 if index==1 else -.02,.10 if kind not in ('lantern','crossbow') else -.03,-.04)
        if kind in ('shield','anchor') and index==2:hitloc=(-.02,.26,-.10)   # Ausfallschritt beim Abschluss
        if kind in ('bow','sail') and index==1:windloc=(0,0,-.075);hitloc=(0,0,-.075)
        if kind in ('bow','sail') and index==2:windloc=(0,-.14,.0);hitloc=(0,-.10,.0)
        lunge={'thigh.L':[(X,30)],'shin.L':[(X,-34)],'thigh.R':[(X,-14)],'shin.R':[(X,-8)]} if kind in ('shield','anchor') and index==2 else {}
        twist={'chest':[(X,-4),(Z,-10)],'hips':[(Z,-6)]} if kind=='shield' and index==1 else {}
        if kind=='shield':
            wind=merge(wind,{'arm.L':[(X,35)],'fore.L':[(X,55)]})
            hit=merge(hit,{'arm.L':[(X,45 if index==1 else 35)],'fore.L':[(X,45 if index==1 else 55)]})
        if h['id']=='brennholt':
            wind=merge(wind,{'hips':[(X,3),(Z,-3)],'chest':[(X,7),(Y,-5),(Z,16)],
                'clavicle.R':[(Y,9),(Z,4)],'clavicle.L':[(Y,-4),(Z,3)],
                'head':[(X,-5),(Y,4),(Z,-12)]})
            hit=merge(hit,{'hips':[(X,-3),(Z,-8)],'chest':[(X,-8),(Y,5),(Z,-12)],
                'clavicle.R':[(Y,3),(Z,-6)],'clavicle.L':[(Y,2),(Z,7)],
                'head':[(X,4),(Y,-5),(Z,18)]})
        if kind in ('bow','sail') and index==1:
            crouch={'thigh.L':[(X,22)],'shin.L':[(X,-44)],'thigh.R':[(X,22)],'shin.R':[(X,-44)],'chest':[(X,10),(Z,-18)]}   # beide Knie gleich: Füße bleiben am Boden
            wind=merge(wind,crouch);hit=merge(hit,crouch)
        if kind in ('bow','sail') and index==2:
            brace={'thigh.R':[(X,-22)],'thigh.L':[(X,12)],'shin.L':[(X,-10)],'chest':[(X,-10),(Z,-28)],'hips':[(Z,-10)],'head':[(X,-8)]}
            wind=merge(wind,brace);hit=merge(hit,merge(brace,{'chest':[(X,-6),(Z,-20)]}))
        if kind=='anchor':
            hit=merge(hit,lunge)
            if index==2:
                wind=merge(wind,{'chest':[(X,14)],'hips':[(X,4)],'head':[(X,-10)]})
                hit=merge(hit,{'chest':[(X,-16)],'hips':[(X,-8)],'head':[(X,8)]})
        wind=equipped(wind,'wind',index,windloc)
        hit=equipped(hit,'hit',index,hitloc)
        wind,hit=align_strike(wind,hit,index,windloc,hitloc)
        keys=[(1,base,None),(max(3,int(tempo*.22)),wind,windloc),(max(5,int(tempo*.38)),wind,windloc),
              (max(7,int(tempo*.5)),hit,hitloc),(max(9,int(tempo*.63)),hit,hitloc),(tempo,base,None)]
        if h['id']=='brennholt':
            # Authored breakdowns replace the held block poses. Pelvis starts the
            # transfer while the chest is still chambered; shoulder and head settle last.
            load=merge(wind,{'hips':[(X,5),(Z,8)],'chest':[(X,4),(Y,-3),(Z,10)],
                            'clavicle.R':[(Y,5),(Z,5)]})
            drive=merge(wind,{'hips':[(X,1),(Z,2)],'chest':[(X,7),(Y,-5),(Z,16)]})
            follow=merge(hit,{'hips':[(X,-2),(Z,-7)],'chest':[(X,0),(Y,6),(Z,-16)],
                              'clavicle.R':[(Y,1),(Z,-8)],'head':[(X,3),(Z,14)]})
            # Unterschiede der drei Schläge: Schlag 2 mit Schildstoß und tieferer Drehung, Abschluss mit Ausfallschritt.
            hit=merge(hit,merge(lunge,twist));follow=merge(follow,merge(lunge,twist))
            settle=merge(base,{'hips':[(Z,-4)],'chest':[(X,-5),(Y,3),(Z,-12)],
                              'clavicle.R':[(Y,-2),(Z,-7)],'head':[(Z,10)]})
            load=equipped(load,'wind',index,(0,-.04,-.015))
            drive=equipped(drive,'wind',index,(0,-.02,-.025))
            followloc=(hitloc[0],hitloc[1]+.02,hitloc[2]-.015)
            follow=equipped(follow,'follow',index,followloc)
            settle=equipped(settle,'guard',index,(0,.04,-.015))
            cut=merge(wind,{'chest':[(X,2),(Y,-1),(Z,6)],'hips':[(X,0),(Z,-5)]})
            cutloc=(0,.01,-.005)
            cut=equipped(cut,'cut',index,cutloc)
            # Preserve the cutting plane during acceleration and follow-through.
            velocity=motion.weapon_head(hit,'weapon_R',hitloc)-motion.weapon_head(wind,'weapon_R',windloc)
            for pose,loc in ((cut,cutloc),(follow,followloc)):
                pose.update(brennholt_pronate(pose,velocity,loc))
            keys=[(1,base,None),(5,load,(0,-.04,-.015)),(7,drive,(0,-.02,-.025)),
                  (9,wind,windloc),(10,cut,cutloc),(12,hit,hitloc),(15,follow,followloc),
                  (19,settle,(0,.04,-.015)),(tempo,base,None)]
        authored[name]=keys
        action(name,keys)
    action('attack',authored['attack_combo_1'])
    for slot,ability in enumerate(h['abilities']):
        wind,hit=cast(kind,ability['op'],slot)
        wind=merge(base,wind);hit=merge(base,hit)
        if kind=='shield':
            wind=merge(wind,{'arm.L':[(X,35)],'fore.L':[(X,55)]})
            hit=merge(hit,{'arm.L':[(X,35)],'fore.L':[(X,55)]})
        if h['id']=='brennholt':
            # Ability body lean must not pitch the complete sword vertically down.
            hit=merge(hit,{'chest':[(X,-8),(Y,5),(Z,-12)]})
        wind=equipped(wind,'wind',0)
        hit=equipped(hit,'hit',0)
        wind,hit=align_strike(wind,hit,0)
        duration=30 if slot==3 else 23 if ability['op'] in ('meteor','summon','wall') else 19
        offset=(0,.08,-.055) if ability['op'] not in ('guard','buff','form') else (0,0,.02)
        keys=[(1,base,None),(6,wind,(0,-.03,.02)),(10,wind,(0,-.03,.02)),(14,hit,offset),(18,hit,offset),(duration,base,None)]
        action('cast_'+str(slot),keys)
        if slot==0: action('cast',keys)
    fall={'root':[(X,-82),(Y,12 if kind in ('stone','barrel','anchor') else -8)],'chest':[(X,12)],
          'arm.R':[(Y,65)],'arm.L':[(Y,-55)],'thigh.L':[(X,45)],'shin.L':[(X,-65)],'head':[(X,25)]}
    kneel={'chest':[(X,-15)],'thigh.L':[(X,45)],'shin.L':[(X,-70)],'arm.R':[(X,35)],'head':[(X,20)]}
    # Tod (2026-11-17): Waffen liegen beim Fallen sichtbar neben dem Körper statt im Boden zu versinken.
    # Knien: Waffe stützt sich schräg nach vorn auf den Boden; Liegen: Waffe parallel zum Körper.
    def drop_weapons(pose,point,direction,loc):
        if h['id']=='brennholt' or kind in ('anchor','crossbow','bow','sail'):return pose
        pose=merge(base,pose)
        for weapon in motion.weapons:
            sign=1 if weapon.endswith('L') else -1
            matrix=motion.matrix(pose,'chest',loc)
            target=(matrix@np.r_[[sign*point[0],point[1],point[2]],1])[:3]
            aim=matrix[:3,:3]@np.array([sign*direction[0],direction[1],direction[2]])
            fitted,error=motion.fit_grip(pose,weapon,target,loc,direction=aim)
            if error<=.18:pose=fitted
        return pose
    kneel=drop_weapons(kneel,[.55,.40,height*.42],[.12,.62,-.78],(0,0,-.25))
    fall=drop_weapons(fall,[.52,.10,height*.40],[.25,0,1],(0,-.12,.12))
    action('death',[(1,base,None),(8,kneel,(0,0,-.25)),(18,fall,(0,-.12,.12)),(30,fall,(0,-.12,.12))])
    print('MOTION_PROFILE',h['id'],kind,'3 combos + 4 ability clips',flush=True)


def bake_linked_grip(rig,f,api,motion):
    """Bake both hands at 96 Hz with the same analytic solver, avoiding cross-chain IK lag.
    Primary grip locations interpolate linearly in chest space; the second palm follows
    the actual shaft and both hands retain the complete authored weapon orientation.
    """
    import bpy
    writer=api['Anim'](rig)
    side='L';left=f.J['hand.L'][0];right=f.J['hand.R'][0]
    support=type(motion)(f.bones,{'L':{'bone':'weapon.L','driver':'fore.L',
        'grip':list(left),'head':list(left),'shaft':[0,0,-1],'blade_normal':[0,1,0]}})
    weapon=next(iter(motion.weapons))
    tracks=list(rig.animation_data.nla_tracks)
    for track in tracks:track.mute=True
    def rotation(matrix):
        q=api['Matrix'](matrix.tolist()).to_quaternion()
        return [(tuple(q.axis),math.degrees(q.angle))]
    for track in tracks:
        if track.name=='death':continue
        action=track.strips[0].action
        rig.animation_data.action=action
        baked=[]
        for frame in range(0,math.ceil(action.frame_range[1])+1):
            bpy.context.scene.frame_set(frame)
            pose={}
            for name,*_ in f.bones:
                rest=writer.rest[name]
                q=rest@rig.pose.bones[name].rotation_quaternion@rest.inverted()
                pose[name]=[(tuple(q.axis),math.degrees(q.angle))]
            loc=tuple(writer.rest['root']@rig.pose.bones['root'].location)
            intended=motion.matrix(pose,'weapon.R',loc)[:3,:3]
            local=np.array(right)+np.array(rig.pose.bones['grip.R'].location)
            target=(motion.matrix(pose,'chest',loc)@np.r_[local,1])[:3]
            pose,error=motion.fit_grip(pose,weapon,target,loc)
            if error>.005:raise ValueError(f'Right anchor grip unreachable: {track.name}/{frame}: {error}')
            fore=motion.matrix(pose,'fore.R',loc)[:3,:3]
            pose['hand.R']=rotation(fore.T@intended)
            target=(motion.matrix(pose,'weapon.R',loc)@np.r_[np.array(right)+[0,0,-.18],1])[:3]
            pose,error=support.fit_grip(pose,side,target,loc)
            if error>.005:raise ValueError(f'Left anchor grip unreachable: {track.name}/{frame}: {error}')
            fore=motion.matrix(pose,'fore.L',loc)[:3,:3]
            pose['hand.L']=rotation(fore.T@intended)
            baked.append((frame,pose,loc))
        for frame,pose,loc in baked:writer.key(frame,pose,loc)
    rig.animation_data.action=None
    for track in tracks:track.mute=False
