"""Measure axe-head centers from actual GLB rest bones and authored poses (NumPy)."""
import json
import math
from pathlib import Path
import struct
import runpy
import sys
import numpy as np

MODULE = runpy.run_path(str(Path(__file__).with_name('torvik_angriffe.py')))
PATH = Path(__file__).resolve().parents[2] / 'assets/models/heroes/torvik.glb'
RAW = PATH.read_bytes()
SIZE = struct.unpack_from('<I', RAW, 12)[0]
DOC = json.loads(RAW[20:20+SIZE])
NODES = DOC['nodes']
PARENTS = {c:p for p,n in enumerate(NODES) for c in n.get('children', [])}
BY_NAME = {n['name']:i for i,n in enumerate(NODES)}
MUL, INV, CONVERT = (MODULE[k] for k in ['multiply','inverse','converted'])


def rotation(q):
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])


def rest_q(i):
    q=NODES[i].get('rotation',(0,0,0,1))
    return MUL(rest_q(PARENTS[i]),q) if i in PARENTS else q


REST_Q = [rest_q(i) for i in range(len(NODES))]


def transforms(poses,loc=None):
    cache={}
    def at(i):
        if i in cache:return cache[i]
        n=NODES[i];q=(0,0,0,1)
        for axis,degrees in poses.get(n['name'],[]):
            a=math.radians(degrees)/2;axis=CONVERT(axis)
            q=MUL((*[v*math.sin(a) for v in axis],math.cos(a)),q)
        q=MUL(n.get('rotation',(0,0,0,1)),MUL(MUL(INV(REST_Q[i]),q),REST_Q[i]))
        t=np.eye(4);t[:3,:3]=rotation(q);t[:3,3]=n.get('translation',(0,0,0))
        if n['name']=='root' and loc:t[:3,3]+=CONVERT(loc)
        cache[i]=(at(PARENTS[i])@t) if i in PARENTS else t
        return cache[i]
    return [at(i) for i in range(len(NODES))]


REST = transforms({})


def center(poses,side,loc=None):
    i=BY_NAME['fore.'+side]
    sign=1 if side=='L' else -1
    # Same shaft direction / head placement as helden_bau.py.
    d=np.array([0,.75,.66]);d/=np.linalg.norm(d)
    p=np.array(CONVERT(np.array([.74*sign,.14,.74])+d*.78))
    return (transforms(poses,loc)[i] @ np.linalg.inv(REST[i]) @ np.r_[p,1])[:3]


def main():
    if '--tune' in sys.argv:
        X,Y,Z=MODULE['X'],MODULE['Y'],MODULE['Z']
        definitions=MODULE['attack_poses']()
        goals=[('dual_wind','attack_dual_strike',1,'L',(.62,2.65,-.05)),
               ('dual_hit','attack_dual_strike',2,'L',(.10,.95,-1.0)),
               ('overhead_wind_L','attack_overhead',1,'L',(.85,2.55,-.15)),
               ('overhead_wind_R','attack_overhead',1,'R',(.55,2.55,-.15)),
               ('overhead_hit_L','attack_overhead',2,'L',(-.75,.90,-.85)),
               ('overhead_hit_R','attack_overhead',2,'R',(-.95,.85,-.85))]
        rng=np.random.default_rng(73)
        for label,name,key,side,target in goals:
            _,base,loc=definitions[name][key]
            arm='arm.'+side;fore='fore.'+side
            twist=base[fore][0]
            initial=np.array([next((deg for axis,deg in base[arm] if axis==a),0) for a in [X,Y,Z]]+
                             [next((deg for axis,deg in base[fore] if axis==X),0)],dtype=float)
            def score(v):
                p=dict(base);p[arm]=[(X,v[0]),(Y,v[1]),(Z,v[2])];p[fore]=[twist,(X,v[3])]
                return float(np.sum((center(p,side,loc)-target)**2)+0.0000008*np.sum((v-initial)**2))
            best=initial.copy();value=score(best)
            for attempt in range(4):
                v=initial.copy() if attempt==0 else np.clip(initial+rng.normal(0,65,4),-175,175)
                current=score(v)
                for step in [40,20,10,5,2,1,.5]:
                    for iteration in range(15):
                        changed=False
                        for axis in range(4):
                            for sign in [-1,1]:
                                trial=v.copy();trial[axis]=np.clip(trial[axis]+sign*step,-175,175)
                                candidate=score(trial)
                                if candidate<current:v=trial;current=candidate;changed=True
                        if not changed:break
                if current<value:best=v;value=current
            p=dict(base);p[arm]=[(X,best[0]),(Y,best[1]),(Z,best[2])];p[fore]=[twist,(X,best[3])]
            print(label, np.round(best,1).tolist(), 'head',np.round(center(p,side,loc),3).tolist(),flush=True)
        return
    for name,frames in MODULE['attack_poses']().items():
        print(name)
        for frame,poses,loc in frames:
            if poses:print(frame, *(side+':'+str(np.round(center(poses,side,loc),3).tolist()) for side in ['L','R']))


if __name__=='__main__':main()
