"""Original Torvik attack poses, shared by Blender regeneration and GLB patching.

python tools/modelle/torvik_angriffe.py [--check]
No Blender dependency: existing mesh, skins, materials and old clips stay intact.
Pose axes use the model generator's Blender world coordinates; glTF is Y-up.
"""
import argparse
import json
import math
from pathlib import Path
import struct
import runpy

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
# Twist around each forearm's actual longitudinal rest axis, before elbow bending.
# This rotates hand, shaft and axe head as one rigid assembly without orbiting the grip.
_FORE_LENGTH = math.sqrt(0.04**2 + 0.12**2 + 0.39**2)
TWIST_L = tuple(v / _FORE_LENGTH for v in (0.04, 0.12, -0.39))
TWIST_R = tuple(v / _FORE_LENGTH for v in (-0.04, 0.12, -0.39))


def base_attack_poses(landmarks=None):
    landmarks = landmarks or {'elbow':(.7,.02,1.13),'hand':(.74,.14,.74)}
    delta = [b-a for a,b in zip(landmarks['elbow'],landmarks['hand'])]
    length = math.sqrt(sum(v*v for v in delta))
    TWIST_L = tuple(v/length for v in delta)
    TWIST_R = (-TWIST_L[0],TWIST_L[1],TWIST_L[2])
    cleave_wind = {'chest': [(Z, -32), (X, -6)], 'hips': [(Z, -12)],
                   'arm.L': [(X, 70), (Y, -28), (Z, -58)], 'arm.R': [(X, 80), (Y, 25), (Z, -48)],
                   'fore.L': [(TWIST_L, -72), (X, 18)],
                   'fore.R': [(TWIST_R, -72), (X, 12)], 'head': [(Z, 16)]}
    cleave_hit = {'chest': [(Z, 26), (X, -14)], 'hips': [(Z, 12)],
                  'arm.L': [(X, 72), (Y, -18), (Z, 62)], 'arm.R': [(X, 68), (Y, 24), (Z, 54)],
                  'fore.L': [(TWIST_L, -82), (X, -12)],
                  'fore.R': [(TWIST_R, -82), (X, -18)], 'head': [(Z, -12)]}
    dual_wind = {'arm.L': [(X, 100), (Y, -65)], 'arm.R': [(X, 100), (Y, 65)],
                 'fore.L': [(TWIST_L, -28), (X, 30)],
                 'fore.R': [(TWIST_R, 28), (X, 30)], 'chest': [(X, -10)]}
    dual_hit = {'arm.L': [(X, 65), (Y, 12)], 'arm.R': [(X, 65), (Y, -12)],
                'fore.L': [(TWIST_L, 14), (X, -22)],
                'fore.R': [(TWIST_R, -14), (X, -22)], 'chest': [(X, -20)],
                'hips': [(X, -5)], 'thigh.L': [(X, 16)], 'shin.L': [(X, -16)]}
    overhead_wind = {'arm.L': [(X, 165), (Y, -12)], 'arm.R': [(X, 165), (Y, 12)],
                     'fore.L': [(TWIST_L, -16), (X, 24)], 'fore.R': [(TWIST_R, 16), (X, 24)],
                     'chest': [(X, -15)], 'head': [(X, -8)]}
    overhead_hit = {'arm.L': [(X, 28), (Y, 10)], 'arm.R': [(X, 28), (Y, -10)],
                    'fore.L': [(TWIST_L, 8), (X, -20)], 'fore.R': [(TWIST_R, -8), (X, -20)], 'chest': [(X, -22)],
                    'hips': [(X, -6)], 'thigh.L': [(X, 25)], 'shin.L': [(X, -25)], 'thigh.R': [(X, -12)]}
    actions = {
        'attack_cleave': [(0, {}, None), (4, cleave_wind, (0, -0.03, 0.02)),
                          (8, cleave_hit, (0, 0.10, -0.02)), (11, cleave_hit, (0, 0.10, -0.02)), (19, {}, None)],
        'attack_dual_strike': [(0, {}, None), (5, dual_wind, (0, -0.04, 0.02)),
                               (8, dual_hit, (0, 0.12, -0.035)), (10, dual_hit, (0, 0.12, -0.035)), (18, {}, None)],
        'attack_overhead': [(0, {}, None), (6, overhead_wind, (0, -0.02, 0.06)),
                            (10, overhead_hit, (0, 0.09, -0.07)), (13, overhead_hit, (0, 0.09, -0.07)), (20, {}, None)],
    }
    return actions


def attack_poses():
    profile = json.loads(Path(__file__).with_name('rig_profiles').joinpath('torvik.json').read_text(encoding='utf-8'))
    actions = base_attack_poses(profile['landmarks'])
    apply = runpy.run_path(str(Path(__file__).with_name('rig_motion.py')))['apply_motion_profile']
    fitted={name:apply(frames,profile,name) if name in profile['clips'] else frames for name,frames in actions.items()}
    return align_cutting_planes(fitted,profile)


def align_cutting_planes(actions,profile):
    if profile.get('id')!='torvik' or not profile['landmarks'].get('attachments'):return actions
    motion=runpy.run_path(str(Path(__file__).with_name('rig_motion.py')))['MotionRig'].from_profile(profile)
    result={}
    for clip,keys in actions.items():
        wind,hit=keys[1],keys[2]
        velocities={weapon:motion.weapon_head(hit[1],weapon,hit[2])-motion.weapon_head(wind[1],weapon,wind[2])
                    for weapon in motion.weapons}
        fitted=[]
        for index,(frame,pose,loc) in enumerate(keys):
            if 0<index<len(keys)-1:
                for weapon,velocity in velocities.items():pose=motion.align_edge(pose,weapon,velocity,loc)
            fitted.append((frame,pose,loc))
        result[clip]=fitted
    return result


def multiply(a, b):
    x, y, z, w = a
    u, v, t, s = b
    return (w*u+x*s+y*t-z*v, w*v-x*t+y*s+z*u, w*t+x*v-y*u+z*s, w*s-x*u-y*v-z*t)


def inverse(q):
    return (-q[0], -q[1], -q[2], q[3])


def converted(v):
    return (v[0], v[2], -v[1])


def write_glb(path, poses, check=False, bone_aliases=None):
    """Reusable animation compiler for skinned GLBs; preserves mesh/material buffers."""
    path = Path(path)
    bone_aliases = bone_aliases or {}
    poses = {name:[(frame,{bone_aliases.get(bone,bone):rotations for bone,rotations in pose.items()},loc)
                   for frame,pose,loc in frames] for name,frames in poses.items()}
    raw = path.read_bytes()
    json_length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+json_length])
    fluid_profile=doc['asset'].get('extras',{}).get('tdhub_fluid_config')
    if 'tdhub_fluid_base' in doc['asset'].get('extras',{}):
        fluid=runpy.run_path(str(Path(__file__).with_name('rig_fluid.py')))
        raw=fluid['restore_blob'](raw)
        json_length=struct.unpack_from('<I',raw,12)[0]
        doc=json.loads(raw[20:20+json_length])
    if len(doc.get('skins',[]))!=1:raise ValueError('Animation compiler expects one skinned rig per GLB')
    if any('matrix' in n for n in doc['nodes']):raise ValueError('Apply node matrices to TRS before compiling animation')
    binary_start = 20 + json_length + 8
    binary = bytearray(raw[binary_start:])
    if check:
        clips = {a['name']: a for a in doc['animations']}
        for name in poses:
            if name not in clips or not clips[name]['channels']:
                raise SystemExit('Missing clip: ' + name)
            sampler = clips[name]['samplers'][0]
            duration = doc['accessors'][sampler['input']]['max'][0]
            if abs(duration - poses[name][-1][0] / 24) > .001:
                raise SystemExit('Wrong timing: ' + name)
        print(f'GLB: {len(poses)} clips present, valid timing')
        return
    extras = doc['asset'].setdefault('extras', {})
    baseline = extras.setdefault('tdhub_attack_base', [doc['buffers'][0]['byteLength'], len(doc['bufferViews']), len(doc['accessors'])])
    binary = binary[:baseline[0]]
    doc['bufferViews'] = doc['bufferViews'][:baseline[1]]
    doc['accessors'] = doc['accessors'][:baseline[2]]
    managed=set(extras.get('tdhub_managed_animations',
        [a['name'] for a in doc['animations'] if any(s['input']>=baseline[2] for s in a['samplers'])]))
    doc['animations'] = [a for a in doc['animations'] if a['name'] not in managed and a['name'] not in poses]
    extras['tdhub_managed_animations']=sorted(poses)
    nodes = doc['nodes']
    known = {nodes[i]['name'] for i in doc['skins'][0]['joints']}
    used = {bone for frames in poses.values() for _,pose,_ in frames for bone in pose}
    if used-known:raise ValueError('Unmapped bones: '+', '.join(sorted(used-known)))
    for frames in poses.values():
        times=[frame for frame,_,_ in frames]
        if not times or times[0]!=0 or any(b<=a for a,b in zip(times,times[1:])):
            raise ValueError('Frames must start at zero and be strictly increasing')
    parents = {child: parent for parent, node in enumerate(nodes) for child in node.get('children', [])}
    joints = doc['skins'][0]['joints']
    identity = (0, 0, 0, 1)

    def global_rotation(index):
        local = nodes[index].get('rotation', identity)
        return multiply(global_rotation(parents[index]), local) if index in parents else local

    def accessor(values, kind):
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        flat = [x for row in values for x in row]
        binary.extend(struct.pack('<' + 'f'*len(flat), *flat))
        view = len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(flat)*4})
        item = {'bufferView': view, 'componentType': 5126, 'count': len(values), 'type': kind}
        if kind == 'SCALAR':
            item.update(min=[min(flat)], max=[max(flat)])
        index = len(doc['accessors'])
        doc['accessors'].append(item)
        return index

    for name, frames in poses.items():
        clip = {'name': name, 'channels': [], 'samplers': []}
        time = accessor([(frame/24,) for frame, _, _ in frames], 'SCALAR')
        for joint in joints:
            node = nodes[joint]
            rest = global_rotation(joint)
            base = node.get('rotation', identity)
            rotations = []
            for _, positions, _ in frames:
                world_delta = identity
                for axis, degrees in positions.get(node['name'], []):
                    axis = converted(axis)
                    angle = math.radians(degrees)/2
                    delta = (*[x*math.sin(angle) for x in axis], math.cos(angle))
                    world_delta = multiply(delta, world_delta)
                local_delta = multiply(multiply(inverse(rest), world_delta), rest)
                q = multiply(base, local_delta)
                length = math.sqrt(sum(x*x for x in q))
                q = tuple(x/length for x in q)
                if rotations and sum(a*b for a,b in zip(q, rotations[-1])) < 0:
                    q = tuple(-x for x in q)
                rotations.append(q)
            output = accessor(rotations, 'VEC4')
            sampler = len(clip['samplers'])
            clip['samplers'].append({'input': time, 'output': output, 'interpolation': 'LINEAR'})
            clip['channels'].append({'sampler': sampler, 'target': {'node': joint, 'path': 'rotation'}})
            if node['name'] == bone_aliases.get('root','root'):
                base_position = node.get('translation', (0,0,0))
                output = accessor([tuple(a+b for a,b in zip(base_position, converted(loc or (0,0,0)))) for _,_,loc in frames], 'VEC3')
                clip['channels'].append({'sampler': len(clip['samplers']), 'target': {'node': joint, 'path': 'translation'}})
                clip['samplers'].append({'input': time, 'output': output, 'interpolation': 'LINEAR'})
        doc['animations'].append(clip)
    doc['buffers'][0]['byteLength'] = len(binary)
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded)%4)
    binary += b'\0' * (-len(binary)%4)
    total = 12+8+len(encoded)+8+len(binary)
    path.write_bytes(struct.pack('<III',0x46546c67,2,total)+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
    if fluid_profile is not None:
        runpy.run_path(str(Path(__file__).with_name('rig_fluid.py')))['apply_to_glb'](path,fluid_profile)
    print(f'GLB: wrote {len(poses)} clips, mesh/materials/other clips preserved')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    write_glb(Path(__file__).resolve().parents[2]/'assets/models/heroes/torvik.glb',attack_poses(),args.check)


if __name__ == '__main__':
    main()
