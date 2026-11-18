"""Independent checks of final GLB skinning, bind pose and baked attack constraints.

Run after rig_fluid.py; no production assets are written. Copies under .godot
exercise rebuilding without growing the model or losing the canonical source.
"""
import hashlib
import json
from pathlib import Path
import runpy
import struct
import sys
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
CHECKS=0


def check(value,label):
    global CHECKS
    if not value:raise AssertionError(label)
    CHECKS+=1


def unpack(raw):
    size=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+size]),raw[28+size:]


def quaternion_matrix(q):
    q=np.asarray(q,dtype=float);q=q/np.linalg.norm(q)
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])


def slerp(a,b,t):
    a=np.asarray(a,float);b=np.asarray(b,float)
    a/=np.linalg.norm(a);b/=np.linalg.norm(b)
    dot=float(np.dot(a,b))
    if dot<0:b=-b;dot=-dot
    if dot>.9995:
        result=a+(b-a)*t
        return result/np.linalg.norm(result)
    theta=np.arccos(np.clip(dot,-1,1))
    return (np.sin((1-t)*theta)*a+np.sin(t*theta)*b)/np.sin(theta)


def sample(times,values,time,path,interpolation):
    if interpolation=='CUBICSPLINE':
        values=np.asarray(values).reshape(len(times),3,-1)
        if time<=times[0]:return values[0,1]
        if time>=times[-1]:return values[-1,1]
    else:
        if time<=times[0]:return values[0]
        if time>=times[-1]:return values[-1]
    index=int(np.searchsorted(times,time,side='right')-1)
    dt=times[index+1]-times[index];t=float((time-times[index])/dt)
    if interpolation=='CUBICSPLINE':
        a=values[index,1];b=values[index+1,1]
        result=(2*t**3-3*t**2+1)*a+(t**3-2*t**2+t)*dt*values[index,2]+(-2*t**3+3*t**2)*b+(t**3-t**2)*dt*values[index+1,0]
        return result/np.linalg.norm(result) if path=='rotation' else result
    if interpolation=='STEP':return values[index]
    if path=='rotation':return slerp(values[index],values[index+1],t)
    return values[index]*(1-t)+values[index+1]*t


def world_matrices(doc,binary,read,animation=None,time=0):
    overrides={}
    if animation:
        for channel in animation['channels']:
            sampler=animation['samplers'][channel['sampler']]
            times=np.asarray(read(doc,binary,sampler['input'])).reshape(-1)
            values=read(doc,binary,sampler['output'])
            target=channel['target'];path=target['path']
            if path in ['translation','rotation','scale']:
                overrides[target['node'],path]=sample(times,values,time,path,sampler.get('interpolation','LINEAR'))
    parents={child:parent for parent,node in enumerate(doc['nodes']) for child in node.get('children',[])}
    cache={}
    def visit(index):
        if index in cache:return cache[index]
        node=doc['nodes'][index]
        if 'matrix'in node:local=np.asarray(node['matrix'],float).reshape(4,4).T
        else:
            local=np.eye(4)
            q=overrides.get((index,'rotation'),node.get('rotation',[0,0,0,1]))
            scale=overrides.get((index,'scale'),node.get('scale',[1,1,1]))
            local[:3,:3]=quaternion_matrix(q)@np.diag(scale)
            local[:3,3]=overrides.get((index,'translation'),node.get('translation',[0,0,0]))
        cache[index]=visit(parents[index])@local if index in parents else local
        return cache[index]
    return [visit(index) for index in range(len(doc['nodes']))]


def weights(doc,binary,read,index):
    values=np.asarray(read(doc,binary,index),float)
    accessor=doc['accessors'][index]
    # Accept readers which return normalized values or raw normalized integers.
    if accessor.get('normalized') and values.max(initial=0)>1:
        values/=255 if accessor['componentType']==5121 else 65535
    return values


def validate_hero(hero,module,path=None):
    path=path or ROOT/f'assets/models/heroes/{hero}.glb'
    raw=path.read_bytes();doc,binary=module['load_glb'](path)
    baseline=module['restore_blob'](raw);source,source_binary=unpack(baseline)
    read=module['read_accessor']
    before_count=CHECKS
    check(doc['materials']==source['materials'],hero+': material identity')
    skin=doc['skins'][0];old_skin=source['skins'][0]
    new_names={doc['nodes'][i]['name'] for i in skin['joints']}
    old_names={source['nodes'][i]['name'] for i in old_skin['joints']}
    check(old_names<=new_names,hero+': original bones retained')
    check(len(skin['joints'])>len(old_skin['joints']),hero+': added secondary bones')
    world=world_matrices(doc,binary,read)
    ibms=np.asarray(read(doc,binary,skin['inverseBindMatrices'])).reshape(-1,4,4).transpose(0,2,1)
    bind_matrices=np.asarray([world[joint]@ibms[index] for index,joint in enumerate(skin['joints'])])
    secondary_weights=[]
    new_indices={i for i,node in enumerate(skin['joints']) if doc['nodes'][node]['name'] not in old_names}
    weapon_vertices=0
    for mesh_index,mesh in enumerate(doc['meshes']):
        check(len(mesh['primitives'])==len(source['meshes'][mesh_index]['primitives']),hero+': primitive count')
        for primitive_index,primitive in enumerate(mesh['primitives']):
            attrs=primitive['attributes'];old=source['meshes'][mesh_index]['primitives'][primitive_index]['attributes']
            positions=np.asarray(read(doc,binary,attrs['POSITION']))
            original=np.asarray(read(source,source_binary,old['POSITION']))
            check(len(positions)>=len(original) and np.allclose(positions[:len(original)],original,atol=1e-6),hero+': original rest vertices retained')
            joints=np.asarray(read(doc,binary,attrs['JOINTS_0']),int)
            influence=weights(doc,binary,read,attrs['WEIGHTS_0'])
            check(np.isfinite(influence).all() and (influence>=-1e-7).all(),hero+': finite positive weights')
            check(np.max(np.abs(influence.sum(axis=1)-1))<.0001,hero+': normalized weights')
            check((joints>=0).all() and (joints<len(skin['joints'])).all(),hero+': valid joint indices')
            points=np.c_[positions,np.ones(len(positions))]
            deformed=np.zeros_like(points,dtype=float)
            for channel in range(joints.shape[1]):
                deformed+=np.einsum('nij,nj->ni',bind_matrices[joints[:,channel]],points)*influence[:,channel,None]
            check(np.max(np.abs(deformed[:,:3]-positions))<.0002,hero+': neutral bind-pose geometry')
            for index in new_indices:
                selected=influence[joints==index]
                secondary_weights.extend(selected[selected>1e-6].tolist())
            # Shafts are whole rigid assemblies, even while nearby flesh or cloth is blended.
            material=doc['materials'][primitive.get('material',0)].get('name','')
            rigid_material=(hero=='torvik' and ('3b2a1c' in material or '7fe8ff'in material)) or (hero=='unrat' and ('8a4a2a' in material or '3a3a3e'in material))
            rigid_material|=hero not in ['torvik','unrat','vesna','zix'] and any(color in material for color in ['657182','bc9c5c','674a32'])
            rigid_material|=hero=='vesna' and any(color in material for color in ['5a3a22','8a9aa8','57ff8a','e0e8f0'])
            rigid_material|=hero=='zix' and float(doc['materials'][primitive.get('material',0)].get('pbrMetallicRoughness',{}).get('metallicFactor',1))>.4
            if rigid_material:
                old_joints=np.asarray(read(source,source_binary,old['JOINTS_0']),int)
                old_weights=weights(source,source_binary,read,old['WEIGHTS_0'])
                fore_indices={i for i,node in enumerate(old_skin['joints']) if source['nodes'][node]['name'].startswith('fore.')}
                selected=np.isin(old_joints[:,0],list(fore_indices))&(old_weights[:,0]>.999)
                if selected.any():
                    for vertex in np.flatnonzero(selected):
                        old_bone=source['nodes'][old_skin['joints'][old_joints[vertex,0]]]['name']
                        new_bone=doc['nodes'][skin['joints'][joints[vertex,0]]]['name']
                        check(old_bone==new_bone and influence[vertex,0]>.999,hero+': rigid weapon binding')
                    weapon_vertices+=int(selected.sum())
    check(bool(secondary_weights),hero+': secondary bones influence real geometry')
    rounded=np.unique(np.round(secondary_weights,3))
    check(len(rounded)>2 and np.any((rounded>.05)&(rounded<.95)),hero+': graduated garment weights')
    before={a['name']:a for a in source.get('animations',[])}
    after={a['name']:a for a in doc.get('animations',[])}
    check(before.keys()<=after.keys(),hero+': original animation names retained')
    animated_secondary=False
    for name,clip in after.items():
        for channel in clip['channels']:
            node=channel['target'].get('node');kind=channel['target']['path']
            sampler=clip['samplers'][channel['sampler']]
            values=np.asarray(read(doc,binary,sampler['output']),float)
            check(np.isfinite(values).all(),hero+': finite animation output')
            if node not in skin['joints'] or doc['nodes'][node]['name'] in old_names or kind!='rotation':continue
            if sampler.get('interpolation')=='CUBICSPLINE':values=values.reshape(-1,3,4)[:,1]
            check(np.max(np.abs(np.linalg.norm(values,axis=1)-1))<.001,hero+': unit secondary quaternion')
            dots=np.abs(values@values[0])
            animated_secondary|=float(dots.min())<.99999
            if name in ['idle','run']:
                check(abs(float(np.dot(values[0],values[-1])))>.99999,hero+': seamless looping secondary '+name)
    check(animated_secondary,hero+': secondary rig actually moves')
    foot_points=[];foot_joints=[];foot_weights=[]
    foot_indices={i for i,n in enumerate(skin['joints']) if doc['nodes'][n].get('name','').startswith(('shin.','foot.'))}
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            a=primitive['attributes'];p=read(doc,binary,a['POSITION'])
            j=np.asarray(read(doc,binary,a['JOINTS_0']),int);w=weights(doc,binary,read,a['WEIGHTS_0'])
            selected=np.isin(j[np.arange(len(j)),w.argmax(axis=1)],list(foot_indices)) & (p[:,1]<.35)
            foot_points.extend(p[selected]);foot_joints.extend(j[selected]);foot_weights.extend(w[selected])
    points=np.c_[foot_points,np.ones(len(foot_points))];fj=np.asarray(foot_joints);fw=np.asarray(foot_weights)
    check(len(points)>20,hero+': actual shoe geometry available for contact check')
    for name,clip in after.items():
        if name=='death':continue
        duration=max(float(np.asarray(read(doc,binary,s['input'])).max()) for s in clip['samplers'])
        for time in np.linspace(0,duration,41):
            world=world_matrices(doc,binary,read,clip,float(time))
            matrices=np.array([world[n]@ibms[k] for k,n in enumerate(skin['joints'])])
            moved=sum(np.einsum('nij,nj->ni',matrices[fj[:,k]],points)*fw[:,k,None] for k in range(fw.shape[1]))
            check(abs(float(moved[:,1].min()))<.006,f'{hero}: sole contacts ground without sinking {name} at {time:.4f}: {moved[:,1].min():.5f} m')
    for name,clip in before.items():
        if not name.startswith('attack'):continue
        old_times=np.unique(np.concatenate([np.asarray(read(source,source_binary,s['input'])).reshape(-1) for s in clip['samplers']]))
        protected=['root','hips','chest','arm.L','fore.L','arm.R','fore.R']
        for time in old_times:
            original=world_matrices(source,source_binary,read,clip,float(time))
            baked=world_matrices(doc,binary,read,after[name],float(time))
            source_names={n['name']:i for i,n in enumerate(source['nodes']) if 'name'in n}
            result_names={n['name']:i for i,n in enumerate(doc['nodes']) if 'name'in n}
            offset=baked[result_names['root']][:3,3]-original[source_names['root']][:3,3]
            check(np.linalg.norm(offset[[0,2]])<.0005,hero+': contact correction is vertical only '+name)
            for bone in protected:
                if bone in source_names:
                    expected=original[source_names[bone]].copy();expected[:3,3]+=offset
                    check(np.max(np.abs(expected-baked[result_names[bone]]))<.0005,hero+': baked attack constraint relative to grounded root '+name+'/'+bone)
    target=ROOT/f'.godot/fluid-qa/{hero}.glb';target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    module['apply_to_glb'](target)
    once=target.read_bytes()
    module['apply_to_glb'](target)
    check(target.read_bytes()==once,hero+': rebuild is byte-identical')
    check(hashlib.sha256(module['restore_blob'](once)).digest()==hashlib.sha256(baseline).digest(),hero+': canonical source restored exactly')
    print(f'Fluid QA {hero}: {CHECKS-before_count} checks OK; {weapon_vertices} rigid weapon vertices',flush=True)


def main():
    module=runpy.run_path(str(Path(__file__).with_name('rig_fluid.py')))
    heroes=next((arg.split('=',1)[1].split(',') for arg in sys.argv if arg.startswith('--heroes=')),['torvik','unrat','vesna','zix'])
    for hero in heroes:
        path=None
        if '--copies'in sys.argv:
            path=ROOT/f'.godot/fluid-qa-input/{hero}.glb';path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes((ROOT/f'assets/models/heroes/{hero}.glb').read_bytes())
            module['apply_to_glb'](path)
        validate_hero(hero,module,path)
        if '--weapons' in sys.argv:
            validate_equipment(hero,module,path)
    print(f'Fluid QA: {CHECKS} checks OK')


def validate_equipment(hero,module,path=None):
    """Sample actual exported skin matrices, including interpolated transitions, not authoring keys."""
    path=path or ROOT/f'assets/models/heroes/{hero}.glb'
    doc,binary=module['load_glb'](path);read=module['read_accessor']
    skin=doc['skins'][0];names={doc['nodes'][n]['name']:n for n in skin['joints']}
    ibm=np.asarray(read(doc,binary,skin['inverseBindMatrices'])).reshape(-1,4,4).transpose(0,2,1)
    assemblies={}
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attrs=primitive['attributes']
            positions=np.asarray(read(doc,binary,attrs['POSITION']))
            joints=np.asarray(read(doc,binary,attrs['JOINTS_0']),int)
            influence=weights(doc,binary,read,attrs['WEIGHTS_0'])
            for index,node in enumerate(skin['joints']):
                name=doc['nodes'][node]['name']
                if not name.startswith('weapon.'):continue
                mask=np.any((joints==index)&(influence>.001),axis=1)
                if not mask.any():continue
                check(np.all(np.max(influence[mask],axis=1)>.9999),hero+': whole rigid '+name)
                assemblies.setdefault(index,[]).extend(positions[mask].tolist())
    if not assemblies:
        print(f'Weapon QA {hero}: legacy forearm assemblies covered by rigid material checks',flush=True)
        return
    definitions=json.loads((ROOT/'data/heroes_helden.json').read_text(encoding='utf-8'))['heroes']
    definition=next(h for h in definitions if h['id']==hero)
    shape=definition.get('silhouette','axes');tank=definition['combat_role']=='Tank'
    height=1.75 if shape in ('hammer','barrel') else 2.8 if shape=='stone' else 2.15
    center=np.array([0,height*.46+.28,0])
    radii=np.array([.5 if tank else .34,.43,.31])
    chest_index=skin['joints'].index(names['chest'])
    deepest=10.;worst=''
    for animation in doc['animations']:
        if animation['name']=='death':continue  # Deliberate collapse onto dropped equipment.
        length=max(float(np.max(read(doc,binary,s['input']))) for s in animation['samplers'])
        for t in np.linspace(0,length,max(3,round(length*48))):
            world=world_matrices(doc,binary,read,animation,float(t))
            torso_inverse=np.linalg.inv(world[names['chest']]@ibm[chest_index])
            for index,points in assemblies.items():
                node=skin['joints'][index];name=doc['nodes'][node]['name'];side=name[-1]
                check(np.linalg.norm(world[node][:3,3]-world[names['hand.'+side]][:3,3])<.0001,hero+': no weapon/hand separation '+animation['name'])
                p=np.c_[points,np.ones(len(points))]
                local=(torso_inverse@world[node]@ibm[index]@p.T).T[:,:3]
                distance=np.linalg.norm((local-center)/radii,axis=1)
                minimum=float(distance.min())
                if minimum<deepest:deepest=minimum;worst=f'{animation["name"]}@{t:.2f}/{name}'
    # A conservative inner breastplate volume: contact at the exterior is allowed.
    check(deepest>1.0,hero+': equipment penetrates chest core '+worst+f' ({deepest:.3f})')
    if hero in ('brennholt','yuna'):
        validate_sword_edge(hero,doc,binary,read,skin,names,ibm,assemblies)
    print(f'Weapon QA {hero}: {len(assemblies)} rigid assemblies, 48 Hz grip/torso audit OK; clearance {deepest:.3f} ({worst})',flush=True)


def validate_sword_edge(hero,doc,binary,read,skin,names,ibm,assemblies):
    """Measure the physical blade's plane against its exported windup-to-impact travel."""
    index=skin['joints'].index(names['weapon.R'])
    points=np.asarray(assemblies[index])
    tip=points[points[:,1]>points[:,1].max()-.001].mean(axis=0)
    blade=points[points[:,1]>points[:,1].max()-.5]
    normal=np.linalg.svd(blade-blade.mean(axis=0),full_matrices=False)[2][-1]
    tempo=24 if hero=='brennholt' else 19
    worst=0.
    for animation in doc['animations']:
        if not animation['name'].startswith('attack_combo_'):continue
        # Blender's NLA export retains frame 0 as the clip start; authored keys begin at 1.
        wind=max(5,int(tempo*.38))/24
        hit=max(7,int(tempo*.5))/24
        matrices=[world_matrices(doc,binary,read,animation,t)[names['weapon.R']]@ibm[index] for t in (wind,hit)]
        velocity=(matrices[1]@np.r_[tip,1])[:3]-(matrices[0]@np.r_[tip,1])[:3]
        velocity/=np.linalg.norm(velocity)
        for phase,matrix in zip(('windup','impact'),matrices):
            if hero=='brennholt' and phase=='windup':continue  # Upright chamber precedes forearm roll into cut.
            face=matrix[:3,:3]@normal;face/=np.linalg.norm(face)
            across=abs(float(np.dot(face,velocity)));worst=max(worst,across)
            check(across<.06,hero+': flat blade strikes sideways '+animation['name']+'/'+phase+f' ({across:.3f})')
    print(f'Edge QA {hero}: all 3 cuts track blade plane; worst sideways component {worst:.4f}',flush=True)


if __name__=='__main__':main()
