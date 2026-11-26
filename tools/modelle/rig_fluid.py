"""Reversible fluid-motion pass for existing skinned GLBs: soft joints, cloth chains, overlap.

python tools/modelle/rig_fluid.py [torvik unrat vesna zix]
Original meshes/clips remain embedded as a canonical rebuild source. Requires NumPy.
"""
import argparse
import copy
import json
import math
from pathlib import Path
import struct
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
CONFIG=Path(__file__).with_name('rig_profiles')/'fluid.json'
BASE='tdhub_fluid_base'
WIDTH={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
DTYPE={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}


def load_glb(path):
    return decode(Path(path).read_bytes())


def decode(raw):
    size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);binary=bytearray(raw[28+size:])
    return doc,binary


def encode(doc,binary):
    doc['buffers'][0]['byteLength']=len(binary)
    text=json.dumps(doc,separators=(',',':'),ensure_ascii=True).encode()
    text+=b' '*(-len(text)%4);binary=bytes(binary)+b'\0'*(-len(binary)%4)
    return struct.pack('<III',0x46546c67,2,28+len(text)+len(binary))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(binary),0x004e4942)+binary


def restore_blob(raw):
    doc,binary=decode(raw);extras=doc['asset'].get('extras',{});base=extras.pop(BASE,None)
    if base is None:return raw
    for name in ['nodes','skins','meshes','animations']:doc[name]=base[name]
    doc['accessors']=doc['accessors'][:base['accessors']]
    doc['bufferViews']=doc['bufferViews'][:base['views']]
    extras.pop('tdhub_fluid_report',None)
    extras.pop('tdhub_fluid_config',None)
    return encode(doc,binary[:base['length']])


def read_accessor(doc,binary,index):
    item=doc['accessors'][index];view=doc['bufferViews'][item['bufferView']]
    dtype=np.dtype(DTYPE[item['componentType']]);width=WIDTH[item['type']]
    stride=view.get('byteStride',dtype.itemsize*width)
    start=view.get('byteOffset',0)+item.get('byteOffset',0)
    result=np.ndarray((item['count'],width),dtype=dtype,buffer=binary,offset=start,strides=(stride,dtype.itemsize)).copy()
    if item.get('normalized') and item['componentType']!=5126:
        result=result.astype(float)/np.iinfo(dtype).max
    return result


def append(doc,binary,values,kind,component=5126):
    values=np.asarray(values,dtype=DTYPE[component]).reshape((-1,WIDTH[kind]))
    binary.extend(b'\0'*(-len(binary)%4));offset=len(binary);blob=values.tobytes();binary.extend(blob)
    view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(blob)})
    item={'bufferView':view,'componentType':component,'count':len(values),'type':kind}
    if kind in ['SCALAR','VEC3'] and len(values):item.update(min=values.min(axis=0).tolist(),max=values.max(axis=0).tolist())
    index=len(doc['accessors']);doc['accessors'].append(item);return index


def qmatrix(q):
    x,y,z,w=q
    result=np.eye(4)
    result[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                  [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                  [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    return result


def qmul(a,b):
    x,y,z,w=a;u,v,t,s=b
    return np.array([w*u+x*s+y*t-z*v,w*v-x*t+y*s+z*u,w*t+x*v-y*u+z*s,w*s-x*u-y*v-z*t])


def matrix_q(rot):
    trace=np.trace(rot)
    if trace>0:
        s=math.sqrt(trace+1)*2;q=[(rot[2,1]-rot[1,2])/s,(rot[0,2]-rot[2,0])/s,(rot[1,0]-rot[0,1])/s,.25*s]
    else:
        axis=int(np.argmax(np.diag(rot)));j=(axis+1)%3;k=(axis+2)%3
        s=math.sqrt(max(0,1+rot[axis,axis]-rot[j,j]-rot[k,k]))*2;q=[0.,0.,0.,0.]
        q[axis]=.25*s;q[j]=(rot[j,axis]+rot[axis,j])/s;q[k]=(rot[k,axis]+rot[axis,k])/s;q[3]=(rot[k,j]-rot[j,k])/s
    q=np.array(q);return (q/np.linalg.norm(q)).tolist()


def rest_matrices(nodes):
    parents={c:p for p,n in enumerate(nodes) for c in n.get('children',[])};cache={}
    def at(i):
        if i in cache:return cache[i]
        n=nodes[i];m=qmatrix(n.get('rotation',[0,0,0,1]));m[:3,3]=n.get('translation',[0,0,0])
        if 'scale'in n:m[:3,:3]=m[:3,:3]@np.diag(n['scale'])
        cache[i]=at(parents[i])@m if i in parents else m
        return cache[i]
    return [at(i) for i in range(len(nodes))]


def blender(v):return np.asarray(v)[...,[0,2,1]]*np.array([1,-1,1])
def godot(v):return np.asarray(v)[...,[0,2,1]]*np.array([1,1,-1])


def subdivision(positions,normals,joints,weights,indices,depth):
    p=positions.tolist();n=normals.tolist();j=joints.tolist();w=weights.tolist();tri=indices.reshape((-1,3)).tolist()
    for level in range(depth):
        cache={};new=[]
        def middle(a,b):
            key=tuple(sorted((a,b)))
            if key in cache:return cache[key]
            idx=len(p);p.append(((np.array(p[a])+p[b])*.5).tolist())
            normal=np.array(n[a])+n[b];n.append((normal/max(np.linalg.norm(normal),1e-8)).tolist())
            merged={}
            for vertex in [a,b]:
                for joint,weight in zip(j[vertex],w[vertex]):merged[joint]=merged.get(joint,0)+weight*.5
            best=sorted(merged.items(),key=lambda v:-v[1])[:4];total=sum(v for _,v in best)
            j.append([x for x,_ in best]+[0]*(4-len(best)));w.append([v/total for _,v in best]+[0]*(4-len(best)))
            cache[key]=idx;return idx
        for a,b,c in tri:
            ab,bc,ca=middle(a,b),middle(b,c),middle(c,a)
            new.extend([[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]])
        tri=new
    return np.array(p),np.array(n),np.array(j),np.array(w),np.array(tri).reshape(-1)


def skin_meshes(doc,binary,profile,source):
    nodes=doc['nodes'];skin=doc['skins'][0];names={n['name']:i for i,n in enumerate(nodes) if 'name'in n}
    matrices=rest_matrices(nodes);skin_indices={nodes[node]['name']:i for i,node in enumerate(skin['joints'])}
    parts=[]
    for definition in profile['parts']:
        part=dict(definition);part['indices']=[];parent=names[part['parent']]
        for index,point in enumerate(part['anchors']):
            target=np.eye(4);target[:3,3]=godot(point)
            local=np.linalg.inv(matrices[parent])@target
            node={'name':'fluid_'+part['name']+'_'+str(index),'translation':local[:3,3].tolist(),
                  'rotation':[0,0,0,1],'extras':{'tdhub_secondary':True,'part':part['name']}}
            # New joints use world-aligned rest axes; account for a rotated original parent.
            node['rotation']=matrix_q(local[:3,:3])
            nid=len(nodes);nodes.append(node);nodes[parent].setdefault('children',[]).append(nid)
            names[node['name']]=nid;matrices.append(target)
            part['indices'].append(len(skin['joints']));skin['joints'].append(nid);parent=nid
        parts.append(part)
    inverse=[np.linalg.inv(matrices[node]).T.reshape(-1) for node in skin['joints']]
    skin['inverseBindMatrices']=append(doc,binary,inverse,'MAT4')
    report={'parts':{p['name']:0 for p in parts},'soft_vertices':0,'extra_joints':sum(len(p['indices']) for p in parts)}
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attrs=primitive['attributes']
            if 'JOINTS_0'not in attrs:continue
            material=doc['materials'][primitive.get('material',0)].get('name','')
            p=read_accessor(doc,binary,attrs['POSITION']);n=read_accessor(doc,binary,attrs['NORMAL'])
            j=read_accessor(doc,binary,attrs['JOINTS_0']).astype(int);w=read_accessor(doc,binary,attrs['WEIGHTS_0']).astype(float)
            indices=read_accessor(doc,binary,primitive['indices']).reshape(-1)
            matches=[part for part in parts if any(color in material for color in part['materials'])]
            depth=max([part.get('subdivide',0) for part in matches] or [0])
            if depth:p,n,j,w,indices=subdivision(p,n,j,w,indices,depth)
            dominant=j[np.arange(len(j)),w.argmax(axis=1)];bp=blender(p)
            # Flesh/fabric bends around elbows, knees and waist; metal and held props stay rigid.
            if any(color in material for color in profile.get('body_materials',[])):
                radius=profile.get('joint_radius',.12)
                for child,parent_name in [('fore.L','arm.L'),('fore.R','arm.R'),('shin.L','thigh.L'),('shin.R','thigh.R'),('chest','hips')]:
                    if child not in skin_indices or parent_name not in skin_indices:continue
                    ci,pi=skin_indices[child],skin_indices[parent_name]
                    origin=matrices[names[child]][:3,3]
                    distance=np.linalg.norm(p-origin,axis=1)
                    selected=np.where(((dominant==ci)|(dominant==pi))&(distance<radius))[0]
                    for vertex in selected:
                        original=int(dominant[vertex]);other=pi if original==ci else ci
                        blend=.42*(1-distance[vertex]/radius)
                        j[vertex]=[original,other,0,0];w[vertex]=[1-blend,blend,0,0]
                    report['soft_vertices']+=len(selected)
            for part in matches:
                allowed=[skin_indices[name] for name in part['joints']]
                selected=np.isin(dominant,allowed)
                if 'bounds'in part:selected&=np.all((bp>=part['bounds'][0])&(bp<=part['bounds'][1]),axis=1)
                progress=np.clip((bp[:,part['axis']]-part['start'])/(part['end']-part['start']),0,1)
                selected&=progress>0
                chain=[skin_indices[part['parent']]]+part['indices']
                for vertex in np.where(selected)[0]:
                    t=float(progress[vertex])*len(part['indices']);left=min(int(t),len(chain)-2);fraction=min(t-left,1)
                    j[vertex]=[chain[left],chain[left+1],0,0];w[vertex]=[1-fraction,fraction,0,0]
                report['parts'][part['name']]=report['parts'].get(part['name'],0)+int(selected.sum())
            w/=np.maximum(w.sum(axis=1,keepdims=True),1e-8)
            # Remove invisible zero-area bevel tips, keeping all source vertices.
            triangles=indices.reshape(-1,3).astype(int)
            corners=p[triangles]
            areas=np.linalg.norm(np.cross(corners[:,1]-corners[:,0],corners[:,2]-corners[:,0]),axis=1)
            indices=triangles[areas>1e-8].reshape(-1)
            attrs['POSITION']=append(doc,binary,p,'VEC3');attrs['NORMAL']=append(doc,binary,n,'VEC3')
            attrs['JOINTS_0']=append(doc,binary,j,'VEC4',5123);attrs['WEIGHTS_0']=append(doc,binary,w,'VEC4')
            primitive['indices']=append(doc,binary,indices.reshape(-1,1),'SCALAR',5125)
    return parts,report


def slerp(a,b,u):
    a=np.asarray(a,float);b=np.asarray(b,float);dot=float(np.dot(a,b))
    if dot<0:b=-b;dot=-dot
    if dot>.9995:
        q=a+(b-a)*u;return q/max(np.linalg.norm(q),1e-9)
    angle=math.acos(np.clip(dot,-1,1));return (math.sin((1-u)*angle)*a+math.sin(u*angle)*b)/math.sin(angle)


def sample(times,values,t,rotation=False,ease=False,mode='LINEAR'):
    if len(times)==1:return values[1 if mode=='CUBICSPLINE' else 0]
    if t>=times[-1]:return values[-2 if mode=='CUBICSPLINE' else -1]
    index=max(0,min(len(times)-2,int(np.searchsorted(times,t,side='right')-1)))
    span=times[index+1]-times[index];u=float(np.clip((t-times[index])/max(span,1e-9),0,1))
    if mode=='STEP':return values[index]
    if mode=='CUBICSPLINE':
        a=values[index*3+1];b=values[(index+1)*3+1]
        out=values[index*3+2]*span;incoming=values[(index+1)*3]*span
        value=(2*u**3-3*u*u+1)*a+(u**3-2*u*u+u)*out+(-2*u**3+3*u*u)*b+(u**3-u*u)*incoming
        return value/max(np.linalg.norm(value),1e-9) if rotation else value
    if ease and span>.075:u=u*u*(3-2*u)
    return slerp(values[index],values[index+1],u) if rotation else values[index]*(1-u)+values[index+1]*u


def qlog(q):
    q=np.array(q,float)
    if q[3]<0:q=-q
    s=np.linalg.norm(q[:3]);return q[:3]*(2*math.atan2(s,q[3])/s) if s>1e-8 else np.zeros(3)


def qexp(v):
    angle=np.linalg.norm(v)
    return np.r_[v*(math.sin(angle/2)/angle),math.cos(angle/2)] if angle>1e-8 else np.array([0,0,0,1.])


def ground_samples(doc,binary,samples,times):
    """Plant the lowest animated sole, never the robe or a held weapon, at y=0.

    Only a common vertical root offset changes; authored limb rotations and
    horizontal weapon trajectories remain intact. Foot lifts remain relative.
    """
    nodes=doc['nodes'];skin=doc['skins'][0]
    names={n.get('name',''):i for i,n in enumerate(nodes)};root=names.get('root')
    if root is None:return
    feet={i for i,n in enumerate(skin['joints']) if nodes[n].get('name','') in ['shin.L','shin.R','foot.L','foot.R']}
    if not feet:return
    soles=[]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            a=primitive['attributes'];p=read_accessor(doc,binary,a['POSITION'])
            j=read_accessor(doc,binary,a['JOINTS_0']).astype(int);w=read_accessor(doc,binary,a['WEIGHTS_0'])
            selected=np.isin(j[np.arange(len(j)),w.argmax(axis=1)],list(feet))
            if selected.any():soles.append((p[selected],j[selected],w[selected]))
    if not soles:return
    p,j,w=(np.concatenate([s[k] for s in soles]) for k in range(3))
    # Include the whole toe/heel volume: when ankles rotate, a point above
    # the rest sole can become the actual contact point (especially rat toes).
    selected=p[:,1]<p[:,1].min()+.28
    p=np.c_[p[selected],np.ones(selected.sum())];j=j[selected];w=w[selected]
    ibm=read_accessor(doc,binary,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    parents={c:i for i,n in enumerate(nodes) for c in n.get('children',[])}
    values=samples.get((root,'translation'),np.repeat([nodes[root].get('translation',[0,0,0])],len(times),axis=0)).copy()
    samples[(root,'translation')]=values
    for frame in range(len(times)):
        cache={}
        def world(i):
            if i in cache:return cache[i]
            n=nodes[i];q=samples.get((i,'rotation'))
            local=qmatrix(q[frame] if q is not None else n.get('rotation',[0,0,0,1]))
            scale=samples.get((i,'scale'));local[:3,:3]@=np.diag(scale[frame] if scale is not None else n.get('scale',[1,1,1]))
            translation=samples.get((i,'translation'));local[:3,3]=translation[frame] if translation is not None else n.get('translation',[0,0,0])
            cache[i]=world(parents[i])@local if i in parents else local
            return cache[i]
        matrices=np.array([world(n)@ibm[k] for k,n in enumerate(skin['joints'])])
        moved=sum(np.einsum('nij,nj->ni',matrices[j[:,k]],p)*w[:,k,None] for k in range(w.shape[1]))
        shift=np.array([0.,-float(moved[:,1].min()),0.])
        values[frame]+=np.linalg.solve(world(parents[root])[:3,:3],shift) if root in parents else shift


def animate(doc,binary,parts,source,profile=None):
    names={n.get('name',''):i for i,n in enumerate(doc['nodes'])};original_nodes=source['nodes']
    for clip in doc['animations']:
        channels={};all_times=[]
        for channel in clip['channels']:
            sampler=clip['samplers'][channel['sampler']]
            mode=sampler.get('interpolation','LINEAR')
            if mode not in ['LINEAR','STEP','CUBICSPLINE']:raise ValueError('Unknown interpolation '+mode)
            times=read_accessor(doc,binary,sampler['input']).ravel();values=read_accessor(doc,binary,sampler['output'])
            channels[(channel['target']['node'],channel['target']['path'])]=(times,values,mode)
            all_times.extend(times.tolist())
        duration=max(all_times)
        rate=int((profile or {}).get('run_rate',96)) if clip['name']=='run' else 48
        times=np.unique(np.r_[np.linspace(0,duration,max(2,math.ceil(duration*rate)+1)),all_times])
        sparse=all(len(v[0])<10 for v in channels.values());attacking=clip['name'].startswith('attack')
        samples={}
        for (node,path),(keys,values,mode) in channels.items():
            rotation=path=='rotation';rows=[];name=original_nodes[node].get('name','')
            lag={'head':.045,'chest':.018,'fore.L':.012,'fore.R':.012}.get(name,0)
            # Authored hand/weapon constraints must stay in phase with their forearms.
            # A separate forearm delay breaks two-handed grips and changes the cutting plane.
            if name.startswith('fore.') and 'hand.'+name[-1] in names:lag=0
            for t in times:
                previous=max(0,min(len(keys)-2,int(np.searchsorted(keys,t,side='right')-1)))
                phase=(t-keys[previous])/max(float(keys[previous+1]-keys[previous]),1e-7)
                # Preserve authored rotations; grounding later shifts the whole rig vertically.
                offset=lag*math.sin(math.pi*float(np.clip(phase,0,1)))**2 if rotation else 0
                if not attacking and lag:offset=lag*math.sin(math.pi*float(t/duration))**2
                rows.append(sample(keys,values,max(0,t-offset),rotation,sparse,mode))
            samples[(node,path)]=np.array(rows)
        if clip['name']!='death':ground_samples(doc,binary,samples,times)
        clip['channels']=[];clip['samplers']=[]
        time_accessor=append(doc,binary,times.reshape(-1,1),'SCALAR')
        def add(node,path,values):
            output=append(doc,binary,values,'VEC4' if path=='rotation' else 'VEC3')
            clip['channels'].append({'sampler':len(clip['samplers']),'target':{'node':node,'path':path}})
            clip['samplers'].append({'input':time_accessor,'output':output,'interpolation':'LINEAR'})
        for (node,path),values in samples.items():add(node,path,values)
        root=names.get('root');root_values=samples.get((root,'translation'),np.zeros((len(times),3)))
        for part in parts:
            driver=names[part.get('driver',part['parent'])]
            driver_values=samples.get((driver,'rotation'),np.repeat([doc['nodes'][driver].get('rotation',[0,0,0,1])],len(times),axis=0))
            angles=np.array([qlog(q) for q in driver_values])
            for depth,skin_index in enumerate(part['indices']):
                node=doc['skins'][0]['joints'][skin_index]
                position=np.zeros(3);velocity=np.zeros(3);rows=[];old_angle=angles[0];old_root=root_values[0]
                for index,t in enumerate(times):
                    dt=float(t-times[index-1]) if index else 1/48
                    change=(angles[index]-old_angle)/max(dt,1e-5);move=(root_values[index]-old_root)/max(dt,1e-5)
                    target=-change*.04*part.get('gain',1)*(1+depth*.22)
                    target+=np.array([-move[2],0,move[0]])*.09*part.get('gain',1)
                    # Subtle independent settling in idle, larger reaction during whole-body motion.
                    if clip['name']=='idle':target+=np.array([math.sin(t*3.1-depth*.4)*.012,0,math.sin(t*2.2)*.008])
                    limit=math.radians(part.get('limit',7));target=np.clip(target,-limit,limit)
                    omega=2*math.pi*part.get('frequency',4)/(1+depth*.16);damping=part.get('damping',.72)
                    steps=max(1,math.ceil(dt*160));h=dt/steps
                    for substep in range(steps):
                        velocity+=(omega*omega*(target-position)-2*damping*omega*velocity)*h
                        position+=velocity*h
                    envelope=min(1,float(t/.10),float((duration-t)/.18))
                    rows.append(qmul(doc['nodes'][node].get('rotation',[0,0,0,1]),qexp(np.clip(position,-limit,limit)*max(envelope,0))))
                    old_angle=angles[index];old_root=root_values[index]
                add(node,'rotation',rows)


def apply_to_glb(path,profile=None):
    path=Path(path);config=json.loads(CONFIG.read_text(encoding='utf-8'))
    profile=profile or config.get(path.stem)
    if profile is None:
        existing,_=load_glb(path)
        profile=existing.get('asset',{}).get('extras',{}).get('tdhub_fluid_config')
    if profile is None:return
    canonical=restore_blob(path.read_bytes());doc,binary=decode(canonical)
    if len(doc.get('skins',[]))!=1:raise ValueError('Fluid pass expects one skin')
    source={name:copy.deepcopy(doc[name]) for name in ['nodes','skins','meshes','animations']}
    source.update(length=doc['buffers'][0]['byteLength'],accessors=len(doc['accessors']),views=len(doc['bufferViews']))
    binary=binary[:source['length']]
    parts,report=skin_meshes(doc,binary,profile,source)
    animate(doc,binary,parts,source,profile)
    extras=doc['asset'].setdefault('extras',{});extras[BASE]=source;extras['tdhub_fluid_report']=report;extras['tdhub_fluid_config']=profile
    missing=[name for name,count in report['parts'].items() if count==0]
    if missing:raise ValueError('No garment vertices found: '+', '.join(missing))
    path.write_bytes(encode(doc,binary))
    print(f'Fluid {path.stem}: {report["extra_joints"]} secondary joints, {report["soft_vertices"]} soft seam vertices; '+str(report['parts']))


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('heroes',nargs='*',default=['torvik','unrat','vesna','zix'])
    args=parser.parse_args()
    for hero in args.heroes:apply_to_glb(ROOT/'assets/models/heroes'/f'{hero}.glb')


if __name__=='__main__':main()
