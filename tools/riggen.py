"""Riggen: reusable landmark skeletons, melee presets, weapon IK and automatic wrist roll.

Uses the existing Blender model builder and GLB animation compiler; no Blender needed
for editing animation clips in already skinned GLBs. Requires NumPy.
"""
import argparse
import copy
import json
from pathlib import Path
import runpy
import shutil

ROOT=Path(__file__).resolve().parents[1]
MODELS=ROOT/'tools/modelle'
MOTION=runpy.run_path(str(MODELS/'rig_motion.py'))
GLTF=runpy.run_path(str(MODELS/'torvik_angriffe.py'))


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write(path,data):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def actions(profile):
    base=profile.get('actions')
    if base is None:
        if profile.get('preset','dual_axes')!='dual_axes':raise ValueError('Unknown preset')
        base=GLTF['base_attack_poses'](profile.get('landmarks'))
    apply=MOTION['apply_motion_profile']
    return GLTF['align_cutting_planes']({name:apply(frames,profile,name) for name,frames in base.items()},profile)


def check_geometry(profile,clips):
    rig=MOTION['MotionRig'].from_profile(profile)
    checks=0
    for name,spec in profile.get('clips',{}).items():
        if name not in clips:raise ValueError('Unknown clip '+name)
        for frame,pose,loc in clips[name]:
            key=spec.get('keys',{}).get(str(frame),{})
            goals={**key.get('targets',{}),**key.get('grips',{})}
            for weapon,target in goals.items():
                actual=rig.weapon_head(pose,weapon,loc)
                if weapon in key.get('grips',{}):
                    world=rig.matrix(pose,rig.weapons[weapon]['bone'],loc)@MOTION['np'].r_[rig.weapons[weapon]['grip'],1]
                    actual=(MOTION['np'].linalg.inv(rig.matrix(pose,'chest',loc))@world)[:3]
                distance=float(MOTION['np'].linalg.norm(actual-target))
                if distance>float(profile.get('max_target_error',.2)):raise ValueError('Target missed')
                checks+=1
    return checks


def resize_profile(profile,ratio):
    result=copy.deepcopy(profile)
    result['max_target_error']=result.get('max_target_error',.2)*ratio
    for key,value in result['landmarks'].items():
        if key=='attachments':continue
        result['landmarks'][key]=[v*ratio for v in value] if isinstance(value,list) else value*ratio
    for weapon in result.get('weapons',{}).values():
        for field in ('head','grip'):
            if field in weapon:weapon[field]=[v*ratio for v in weapon[field]]
    for spec in result.get('clips',{}).values():
        for key in spec.get('keys',{}).values():
            key['targets']={weapon:[v*ratio for v in point] for weapon,point in key.get('targets',{}).items()}
            key['grips']={weapon:[v*ratio for v in point] for weapon,point in key.get('grips',{}).items()}
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    new=commands.add_parser('neu',help='Create a scalable humanoid profile with editable body landmarks')
    new.add_argument('id');new.add_argument('--hoehe',type=float,default=2.2)
    new.add_argument('--modell',default='');new.add_argument('--aus',type=Path,required=True)
    for name in ['skelett','bauen','pruefen','info','posen']:
        sub=commands.add_parser(name);sub.add_argument('profil',type=Path)
        if name in ['skelett','bauen','posen']:sub.add_argument('--aus',type=Path)
        if name=='skelett':sub.add_argument('--anhaenge',action='store_true',help='Add hand/weapon attachment bones')
    transfer=commands.add_parser('uebertragen',help='Retarget semantic poses/targets to another humanoid profile')
    transfer.add_argument('quelle',type=Path);transfer.add_argument('ziel',type=Path);transfer.add_argument('--aus',type=Path,required=True)
    fluid=commands.add_parser('weich',help='Apply soft joints, cloth chains and motion overlap')
    fluid.add_argument('held',nargs='*',default=['torvik','unrat','vesna','zix'])
    args=parser.parse_args()
    if args.command=='weich':
        apply=runpy.run_path(str(MODELS/'rig_fluid.py'))['apply_to_glb']
        for hero in args.held:apply(ROOT/'assets/models/heroes'/f'{hero}.glb')
        return
    if args.command=='neu':
        if not .3<=args.hoehe<=20:raise ValueError('Height outside 0.3..20 m')
        profile=resize_profile(read(MODELS/'rig_profiles/torvik.json'),args.hoehe/2.2)
        profile.update(id=args.id,model=args.modell,preset='dual_axes')
        write(args.aus,profile)
        print('Rig profile:',args.aus);return
    if args.command=='uebertragen':
        source=read(args.quelle);target=read(args.ziel)
        scaled=resize_profile(source,target['landmarks']['head_top']/source['landmarks']['head_top'])
        target['clips']=scaled.get('clips',{})
        target['preset']=source.get('preset','dual_axes')
        if 'actions' in source:
            ratio=target['landmarks']['head_top']/source['landmarks']['head_top']
            target['actions']={name:[[fr,pose,[v*ratio for v in loc] if loc else None] for fr,pose,loc in frames] for name,frames in source['actions'].items()}
        solved=actions(target);check_geometry(target,solved)
        write(args.aus,target);print('Retargeted profile:',args.aus);return
    profile=read(args.profil)
    rig=MOTION['MotionRig'].from_profile(profile)
    if args.command=='skelett':
        if 'landmarks' in profile:
            landmarks=dict(profile['landmarks']);landmarks['attachments']=args.anhaenge
            bones=MOTION['humanoid_bones'](**landmarks)
            bones+=profile.get('extra_bones',[])
        else:bones=profile['bones']
        result={'coordinates':'blender_z_up','bones':bones,'weapons':profile.get('weapons',{})}
        if args.aus:write(args.aus,result)
        else:print(json.dumps(result,indent=2))
        print('Skeleton:',len(bones),'bones');return
    model=ROOT/profile.get('model','')
    if args.command=='info':
        import struct
        raw=model.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size])
        print(json.dumps({'profile':profile['id'],'model':str(model),'bones':[n['name'] for n in doc['nodes'] if 'name'in n],
                          'clips':[a['name'] for a in doc.get('animations',[])]},indent=2));return
    clips=actions(profile);count=check_geometry(profile,clips)
    if args.command=='posen':
        if not args.aus:raise ValueError('--aus required for pose export')
        write(args.aus,clips);print('Authored poses:',args.aus);return
    if not model.is_file():raise ValueError('Set profile.model to an existing skinned GLB')
    if args.command=='bauen':
        output=args.aus or model
        if output.resolve()!=model.resolve():
            output.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(model,output)
        GLTF['write_glb'](output,clips,bone_aliases=profile.get('bone_aliases'))
    else:GLTF['write_glb'](model,clips,check=True,bone_aliases=profile.get('bone_aliases'))
    print(f'Riggen: {len(rig.bones)} bones, {len(clips)} clips, {count} weapon targets OK')


if __name__=='__main__':
    try:main()
    except (ValueError,KeyError,OSError) as error:raise SystemExit('Riggen: '+str(error))
