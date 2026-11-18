"""Meaningful regression checks for skeletons, wrist direction, IK paths and GLB preservation."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import struct
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
TOOL=runpy.run_path(str(ROOT/'tools/riggen.py'))
MOTION=TOOL['MOTION']
CHECKS=0


def check(value,label):
    global CHECKS
    if not value:raise AssertionError(label)
    CHECKS+=1


def main():
    profile=TOOL['read'](ROOT/'tools/modelle/rig_profiles/torvik.json')
    rig=MOTION['MotionRig'].from_profile(profile)
    check(len(rig.bones)==16 and rig.bones['weapon.R']['parent']=='hand.R','Humanoid with actual hand/weapon anchors')
    attached=MOTION['humanoid_bones'](**dict(profile['landmarks'],attachments=True))
    check(len(attached)==16 and any(b[0]=='weapon.R' for b in attached),'Hand/weapon attachment bones')
    try:MOTION['MotionRig']([('a',(0,0,0),(0,0,1),'b'),('b',(0,0,0),(0,0,1),'a')])
    except ValueError:check(True,'Cycle rejected')
    else:check(False,'Cycle accepted')
    try:MOTION['MotionRig']([('a',(0,0,0),(0,0,0),None)])
    except ValueError:check(True,'Zero bone rejected')
    else:check(False,'Zero bone accepted')
    simple=MOTION['MotionRig']([('fore.L',(0,0,1),(0,0,.5),None)],
        {'axe':{'bone':'fore.L','head':(.2,0,.3),'shaft':(0,0,1),'blade_normal':(1,0,0)}})
    pose,angle=simple.auto_wrist({},'axe',(1,0,0))
    normal=simple.matrix(pose,'fore.L')[:3,:3]@np.array([1,0,0])
    check(abs(float(np.dot(normal,(0,1,0))))>.999,'Automatic blade-plane alignment')
    check(abs(abs(angle)-90)<.01,'Real wrist roll, not elbow swing')
    matrix=simple.matrix(pose,'fore.L')
    anchor=(matrix@np.array([0,0,1,1]))[:3]
    check(np.linalg.norm(anchor-np.array([0,0,1]))<1e-8,'Wrist pivot stays attached')
    clips=TOOL['actions'](profile)
    check(TOOL['check_geometry'](profile,clips)==12,'All authored hand grips reachable')
    lookup=lambda name,frame:next((p,l) for f,p,l in clips[name] if f==frame)
    for name,frame in [('attack_cleave',8),('attack_dual_strike',8),('attack_overhead',10)]:
        pose,loc=lookup(name,frame)
        chest=rig.matrix(pose,'chest')[:3,:3]@np.array([0,0,1])
        check(chest[1]>.1,'Torvik torso follows strike forward '+name)
    wind,wl=lookup('attack_dual_strike',5);hit,hl=lookup('attack_dual_strike',8)
    for side in ['L','R']:
        top=rig.weapon_head(wind,'axe.'+side,wl);bottom=rig.weapon_head(hit,'axe.'+side,hl)
        check(top[2]-bottom[2]>1.3,'Dual Strike downward travel '+side)
        check(abs(bottom[0])<.4 and abs(bottom[0])<abs(top[0])*.6,'Dual Strike converges onto body-width target '+side)
    wind,wl=lookup('attack_overhead',6);hit,hl=lookup('attack_overhead',10)
    for side in ['L','R']:
        top=rig.weapon_head(wind,'axe.'+side,wl);bottom=rig.weapon_head(hit,'axe.'+side,hl)
        sign=1 if side=='L' else -1
        check(top[0]*sign>.5 and abs(bottom[0])<abs(top[0])-.3 and bottom[1]>.7 and top[2]-bottom[2]>1.2,
              'Overhead drives inward into frontal target '+side)
    scaled=TOOL['resize_profile'](profile,.8)
    check(TOOL['check_geometry'](scaled,TOOL['actions'](scaled))==12,'Same actions on resized future hero')
    unrat=TOOL['read'](ROOT/'tools/modelle/rig_profiles/unrat.json')
    combo=TOOL['actions'](unrat);king=MOTION['MotionRig'].from_profile(unrat)
    check(len(king.bones)==13 and 'tail' in king.bones,'Custom tail rig retained')
    check(TOOL['check_geometry'](unrat,combo)==2,'Unrat finisher targets reachable')
    travels=[]
    for clip,keys in [('attack_combo_1',(4,7)),('attack_combo_2',(4,7)),('attack_combo_finish',(7,11))]:
        points=[]
        for key in keys:
            pose,loc=next((p,l) for f,p,l in combo[clip] if f==key)
            points.append(king.weapon_head(pose,'scepter',loc))
        travels.append(float(np.linalg.norm(points[1]-points[0])))
        if clip=='attack_combo_finish':check(points[0][2]-points[1][2]>1.4,'Finisher has strong downward stroke')
    check(travels[2]>max(travels[:2]),'Finisher travel exceeds both opening strikes')
    finish_pose,finish_loc=next((p,l) for f,p,l in combo['attack_combo_finish'] if f==11)
    shaft=king.matrix(finish_pose,'fore.R')[:3,:3]@MOTION['unit'](unrat['weapons']['scepter']['shaft'])
    check(float(np.dot(MOTION['unit'](shaft),(0,1,0)))>.97,'Finisher shaft points straight away from hero')
    check(abs(float(king.weapon_head(finish_pose,'scepter',finish_loc)[0]))<.08,'Finisher impact is centered in front')
    invalid=copy.deepcopy(profile)
    invalid['clips']['attack_dual_strike']['keys']['5']['grips']['axe.L']=[50,50,50]
    try:TOOL['actions'](invalid)
    except ValueError:check(True,'Unreachable target rejected')
    else:check(False,'Unreachable target accepted')
    path=ROOT/'.godot/riggen-qa/torvik.glb';path.parent.mkdir(parents=True,exist_ok=True)
    fluid=runpy.run_path(str(ROOT/'tools/modelle/rig_fluid.py'))
    raw=fluid['restore_blob']((ROOT/profile['model']).read_bytes());path.write_bytes(raw)
    size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size])
    baseline=doc['asset'].get('extras',{}).get('tdhub_attack_base',[doc['buffers'][0]['byteLength']])[0]
    source_hash=hashlib.sha256(raw[28+size:28+size+baseline]).digest()
    TOOL['GLTF']['write_glb'](path,clips)
    once=path.read_bytes();size=struct.unpack_from('<I',once,12)[0]
    check(hashlib.sha256(once[28+size:28+size+baseline]).digest()==source_hash,'Original mesh/skin/clip binary unchanged')
    TOOL['GLTF']['write_glb'](path,clips)
    check(path.read_bytes()==once,'Rebuild is byte-identical and does not grow')
    doc=json.loads(once[20:20+size]);names={a['name'] for a in doc['animations']}
    check({'idle','run','attack','cast','death'}.issubset(names),'Original clips retained')
    TOOL['GLTF']['write_glb'](path,clips,check=True)
    check(True,'Compiled clips have correct duration')
    print(f'Riggen: {CHECKS} checks OK')


if __name__=='__main__':main()
