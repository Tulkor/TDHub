"""Reusable landmark rigs, weapon-path fitting and automatic wrist roll. Requires NumPy."""
import math
import numpy as np

X,Y,Z=(1,0,0),(0,1,0),(0,0,1)


def humanoid_bones(hip, neck, head_top, sh, elbow, hand, knee, foot, hip_x, attachments=False):
    bones=[('root',(0,0,0),(0,0,.3),None),
           ('hips',(0,0,hip),(0,0,hip+.12),'root'),
           ('chest',(0,0,hip+.12),(0,0,neck),'hips'),
           ('head',(0,0,neck),(0,0,head_top),'chest')]
    for sign,side in [(1,'L'),(-1,'R')]:
        mirror=lambda point:(point[0]*sign,point[1],point[2])
        bones.extend([('arm.'+side,mirror(sh),mirror(elbow),'chest'),
                      ('fore.'+side,mirror(elbow),mirror(hand),'arm.'+side),
                      ('thigh.'+side,(hip_x*sign,0,hip),mirror(knee),'hips'),
                      ('shin.'+side,mirror(knee),mirror(foot),'thigh.'+side)])
        if attachments:
            grip=mirror(hand);tip=(grip[0],grip[1]+.12,grip[2])
            bones.extend([('hand.'+side,grip,tip,'fore.'+side),
                          ('weapon.'+side,grip,(grip[0],grip[1]+.3,grip[2]),'hand.'+side)])
    return bones


def unit(vector):
    v=np.array(vector,dtype=float);length=float(np.linalg.norm(v))
    if length<1e-8:raise ValueError('Zero-length axis/bone')
    return v/length


def rotation(axis,degrees):
    x,y,z=unit(axis);angle=math.radians(degrees);c,s=math.cos(angle),math.sin(angle);t=1-c
    return np.array([[t*x*x+c,t*x*y-s*z,t*x*z+s*y],
                     [t*x*y+s*z,t*y*y+c,t*y*z-s*x],
                     [t*x*z-s*y,t*y*z+s*x,t*z*z+c]])


class MotionRig:
    """Pose axes and landmarks are Blender world coordinates (Z-up, forward +Y)."""
    def __init__(self,bones,weapons=None,constraints=None):
        self.bones={b[0]:{'head':np.array(b[1],float),'tail':np.array(b[2],float),'parent':b[3]} for b in bones}
        if len(self.bones)!=len(bones):raise ValueError('Duplicate bone names')
        self.weapons=weapons or {}
        self.constraints=constraints or {}
        for name,b in self.bones.items():
            unit(b['tail']-b['head'])
            seen={name};parent=b['parent']
            while parent:
                if parent not in self.bones:raise ValueError('Missing parent: '+parent)
                if parent in seen:raise ValueError('Cyclic skeleton')
                seen.add(parent);parent=self.bones[parent]['parent']
        for name,w in self.weapons.items():
            if w['bone'] not in self.bones:raise ValueError('Missing weapon bone: '+name)
            unit(w['shaft']);unit(w['blade_normal'])

    @classmethod
    def from_profile(cls,profile):
        if 'bones' in profile:bones=profile['bones']
        else:bones=humanoid_bones(**profile['landmarks'])
        bones=list(bones)+profile.get('extra_bones',[])
        return cls(bones,profile.get('weapons'))

    def matrix(self,poses,bone,loc=None):
        cache={}
        def visit(name):
            if name in cache:return cache[name]
            b=self.bones[name];q=np.eye(3)
            for axis,degrees in poses.get(name,[]):q=rotation(axis,degrees)@q
            own=np.eye(4);own[:3,:3]=q;own[:3,3]=b['head']-q@b['head']
            if b['parent']:own=visit(b['parent'])@own
            elif loc:own[:3,3]+=loc
            cache[name]=own
            return own
        return visit(bone)

    def weapon_head(self,poses,weapon,loc=None):
        w=self.weapons[weapon]
        return (self.matrix(poses,w['bone'],loc)@np.r_[w['head'],1])[:3]

    def fit_grip(self,poses,weapon,target,loc=None,direction=None,pole=None):
        """Analytic two-bone hand placement; an outside elbow pole avoids torso folds.
        Wrist orientation is a separate hand-bone rotation, never a moving grip.
        """
        w=self.weapons[weapon];fore=w.get('driver',w['bone']);arm=self.bones[fore]['parent']
        hand='hand.'+fore.split('.')[-1]
        parent=self.bones[arm]['parent'];parent_matrix=self.matrix(poses,parent,loc)
        local=(np.linalg.inv(parent_matrix)@np.r_[target,1])[:3]
        shoulder=self.bones[arm]['head'];elbow=self.bones[fore]['head'];grip=np.array(w['grip'])
        a=np.linalg.norm(elbow-shoulder);b=np.linalg.norm(grip-elbow)
        distance=np.linalg.norm(local-shoulder);d=unit(local-shoulder)
        reach=np.clip(distance,abs(a-b)+.001,a+b-.002)
        along=(a*a-b*b+reach*reach)/(2*reach)
        outside=np.array(pole if pole is not None else [1 if fore.endswith('L') else -1,-.15,0.0],float)
        outside=unit(outside-d*np.dot(outside,d))
        bend=shoulder+d*along+outside*math.sqrt(max(0,a*a-along*along))
        destination=shoulder+d*reach
        def between(u,v):
            u=unit(u);v=unit(v);axis=np.cross(u,v);s=np.linalg.norm(axis);c=np.clip(np.dot(u,v),-1,1)
            if s<1e-8:
                if c>0:return np.eye(3)
                axis=unit(np.cross(u,[0,1,0] if abs(u[1])<.9 else [1,0,0]))
                return rotation(axis,180)
            return rotation(axis/s,math.degrees(math.atan2(s,c)))
        def axis_angle(matrix):
            angle=math.acos(np.clip((np.trace(matrix)-1)*.5,-1,1))
            if angle<1e-7:return []
            axis=np.array([matrix[2,1]-matrix[1,2],matrix[0,2]-matrix[2,0],matrix[1,0]-matrix[0,1]])
            if np.linalg.norm(axis)<1e-7:
                vals,vecs=np.linalg.eig(matrix);axis=np.real(vecs[:,np.argmin(abs(vals-1))])
            return [(tuple(unit(axis)),math.degrees(angle))]
        upper=between(elbow-shoulder,bend-shoulder)
        lower=between(grip-elbow,destination-bend)
        result=dict(poses);result[arm]=axis_angle(upper);result[fore]=axis_angle(upper.T@lower)
        if direction is not None and hand in self.bones:
            world_fore=parent_matrix[:3,:3]@lower
            desired=between(world_fore@unit(w['shaft']),direction)@world_fore
            result[hand]=axis_angle(world_fore.T@desired)
        actual=(self.matrix(result,w['bone'],loc)@np.r_[grip,1])[:3]
        return result,float(np.linalg.norm(actual-target))

    def align_edge(self,poses,weapon,velocity,loc=None):
        """Roll hand AND complete weapon so the cutting plane contains the strike velocity."""
        if 'cutting_edge' in self.weapons[weapon]:
            return self.align_face(poses,weapon,velocity,self.weapons[weapon]['cutting_edge'],loc,False)
        w=self.weapons[weapon];hand='hand.'+w.get('driver',w['bone']).split('.')[-1]
        if hand not in self.bones:raise ValueError('Edge alignment requires hand anchor: '+weapon)
        matrix=self.matrix(poses,w['bone'],loc)[:3,:3]
        shaft=unit(matrix@unit(w['shaft']))
        normal=unit(matrix@unit(w['blade_normal']))
        target=np.cross(shaft,unit(velocity))
        if np.linalg.norm(target)<1e-6:return dict(poses)
        target=unit(target)
        if np.dot(normal,target)<0:target=-target  # Equivalent sides of a double-edged blade.
        angle=math.degrees(math.atan2(np.dot(shaft,np.cross(normal,target)),np.dot(normal,target)))
        parent=self.bones[hand]['parent']
        local_axis=self.matrix(poses,parent,loc)[:3,:3].T@shaft
        result=dict(poses)
        result[hand]=list(poses.get(hand,[]))+[(tuple(unit(local_axis)),angle)]
        return result

    def align_face(self,poses,weapon,velocity,face,loc=None,double_sided=True):
        """Aim an axe's leading edge or a hammer's striking face along the transverse travel."""
        w=self.weapons[weapon];hand='hand.'+w.get('driver',w['bone']).split('.')[-1]
        matrix=self.matrix(poses,w['bone'],loc)[:3,:3]
        shaft=unit(matrix@unit(w['shaft']))
        normal=matrix@unit(face);normal=unit(normal-shaft*np.dot(normal,shaft))
        target=np.array(velocity,float)-shaft*np.dot(velocity,shaft)
        if np.linalg.norm(target)<1e-6:return dict(poses)
        target=unit(target)
        if double_sided and np.dot(normal,target)<0:target=-target
        angle=math.degrees(math.atan2(np.dot(shaft,np.cross(normal,target)),np.dot(normal,target)))
        parent=self.bones[hand]['parent']
        axis=self.matrix(poses,parent,loc)[:3,:3].T@shaft
        result=dict(poses);result[hand]=list(poses.get(hand,[]))+[(tuple(unit(axis)),angle)]
        return result

    def auto_wrist(self,poses,weapon,velocity,reference=0):
        """Align the blade plane with motion by rolling the complete forearm assembly."""
        w=self.weapons[weapon];bone=w.get('driver',w['bone']);b=self.bones[bone]
        local_axis=unit(b['tail']-b['head'])
        base=[(a,d) for a,d in poses.get(bone,[]) if abs(float(np.dot(unit(a),local_axis)))<.999]
        result=dict(poses);result[bone]=base
        matrix=self.matrix(result,bone)[:3,:3]
        axis=unit(matrix@local_axis);normal=unit(matrix@unit(w['blade_normal']))
        desired=np.cross(matrix@unit(w['shaft']),unit(velocity))
        if np.linalg.norm(desired)<1e-6:return result,0.0
        desired=unit(desired)
        normal-=axis*np.dot(normal,axis);desired-=axis*np.dot(desired,axis)
        if min(np.linalg.norm(normal),np.linalg.norm(desired))<1e-6:return result,0.0
        normal=unit(normal);desired=unit(desired)
        angle=math.degrees(math.atan2(float(np.dot(axis,np.cross(normal,desired))),float(np.dot(normal,desired))))
        # Double-edged blades have equivalent normals +/-N. Pick the continuous orientation.
        angle=min((angle+180*k for k in range(-3,4)),key=lambda a:abs(a-reference))
        angle=float(np.clip(angle,-110,110))
        result[bone]=[(tuple(float(v) for v in local_axis),angle)]+base
        return result,angle

    def fit_weapon(self,poses,weapon,target,loc=None,velocity=None,seed=73,shaft_direction=None):
        """Small deterministic IK solve for arm XYZ + elbow bend, with automatic wrist roll."""
        w=self.weapons[weapon];fore=w.get('driver',w['bone']);arm=self.bones[fore]['parent']
        axes=[X,Y,Z]
        initial=np.array([next((d for a,d in poses.get(arm,[]) if tuple(a)==axis),0) for axis in axes]+
                         [next((d for a,d in poses.get(fore,[]) if tuple(a)==X),0)],float)
        fore_axis=unit(self.bones[fore]['tail']-self.bones[fore]['head'])
        desired_shaft=unit(shaft_direction) if shaft_direction is not None else None
        if desired_shaft is not None:initial=np.r_[initial,0.0]
        limits=w.get('limits',self.constraints.get('limits'))
        low=np.array([x[0] for x in limits[:len(initial)]]) if limits else np.full(len(initial),-175.)
        high=np.array([x[1] for x in limits[:len(initial)]]) if limits else np.full(len(initial),175.)
        initial=np.clip(initial,low,high)
        rest=[(a,d) for a,d in poses.get(fore,[]) if tuple(a)!=X and abs(float(np.dot(unit(a),fore_axis)))<.999]
        def candidate(v):
            p=dict(poses);p[arm]=list(zip(axes,[float(n) for n in v[:3]]));p[fore]=rest+[(X,float(v[3]))]
            if desired_shaft is not None:p[fore]=[(tuple(fore_axis),float(v[4]))]+p[fore]
            elif velocity is not None:p,_=self.auto_wrist(p,weapon,velocity)
            return p
        def score(v):
            error=self.weapon_head(candidate(v),weapon,loc)-target
            direction_error=0.0
            if desired_shaft is not None:
                shaft=unit(self.matrix(candidate(v),fore)[:3,:3]@unit(w['shaft']))
                direction_error=.7*float(np.sum((shaft-desired_shaft)**2))
            clearance=0.0
            body=self.constraints.get('torso')
            if body:
                pose=candidate(v)
                inverse=np.linalg.inv(self.matrix(pose,'chest',loc))
                grip=np.array(w.get('grip',self.bones[fore]['tail']))
                a=(self.matrix(pose,w['bone'],loc)@np.r_[grip,1])[:3]
                b=self.weapon_head(pose,weapon,loc)
                for point in [a]+[a+(b-a)*t for t in (.25,.5,.75,1.0)]:
                    local=(inverse@np.r_[point,1])[:3]
                    distance=np.linalg.norm((local-np.array(body['center']))/np.array(body['radii']))
                    clearance+=max(0,1.12-distance)**2*3
            return float(np.dot(error,error)+direction_error+clearance+.00000015*np.sum((v-initial)**2))
        rng=np.random.default_rng(seed);best=initial;value=score(best)
        for attempt in range(7):
            v=initial.copy() if attempt==0 else np.clip(initial+rng.normal(0,80,len(initial)),low,high)
            current=score(v)
            for step in [40,20,10,5,2,1,.5]:
                for iteration in range(20):
                    changed=False
                    for dim in range(len(initial)):
                        for sign in [-1,1]:
                            trial=v.copy();trial[dim]=np.clip(trial[dim]+sign*step,low[dim],high[dim])
                            trial_score=score(trial)
                            if trial_score<current:v=trial;current=trial_score;changed=True
                    if not changed:break
            if current<value:best=v;value=current
        result=candidate(best)
        error=float(np.linalg.norm(self.weapon_head(result,weapon,loc)-target))
        if desired_shaft is not None:
            alignment=float(np.dot(unit(self.matrix(result,fore)[:3,:3]@unit(w['shaft'])),desired_shaft))
            if alignment<.97:raise ValueError(f'{weapon}: shaft direction unreachable (alignment {alignment:.3f})')
        return result,error


def apply_motion_profile(frames,profile,clip):
    """Fit authored keys, hold impacts, and reject unreachable targets rather than silently deforming."""
    rig=MotionRig.from_profile(profile)
    spec=profile.get('clips',{}).get(clip,{})
    result=[]
    for frame,original,loc in frames:
        poses={name:list(values) for name,values in original.items()}
        key=spec.get('keys',{}).get(str(frame),{})
        for bone,rotations in key.get('pose',{}).items():poses[bone]=[(tuple(axis),degrees) for axis,degrees in rotations]
        targets=key.get('targets',{})
        if 'hold' in key:
            held=next(p for f,p,l in result if f==int(key['hold']))
            poses={name:list(values) for name,values in held.items()}
        for weapon,target in targets.items():
            velocity=spec.get('velocity',{}).get(weapon)
            if velocity is None:
                path=sorted((int(f),k['targets'][weapon]) for f,k in spec.get('keys',{}).items() if weapon in k.get('targets',{}))
                current=next(i for i,(f,point) in enumerate(path) if f==frame)
                before=path[max(0,current-1)][1];after=path[min(len(path)-1,current+1)][1]
                travel=np.array(after)-before
                if np.linalg.norm(travel)>1e-6:velocity=travel
            direction=key.get('directions',{}).get(weapon)
            poses,error=rig.fit_weapon(poses,weapon,np.array(target),loc,velocity,shaft_direction=direction)
            if error>float(profile.get('max_target_error',.20)):
                raise ValueError(f'{clip} frame {frame} {weapon}: target error {error:.3f} m')
        for weapon,grip in key.get('grips',{}).items():
            direction=rig.matrix(poses,rig.weapons[weapon]['bone'],loc)[:3,:3]@unit(rig.weapons[weapon]['shaft'])
            if weapon in key.get('grip_directions',{}):
                direction=rig.matrix(poses,'chest',loc)[:3,:3]@unit(key['grip_directions'][weapon])
            target=(rig.matrix(poses,'chest',loc)@np.r_[grip,1])[:3]
            poses,error=rig.fit_grip(poses,weapon,target,loc,direction=direction)
            if error>.02:raise ValueError(f'{clip}/{weapon}: grip unreachable ({error:.3f})')
        result.append((frame,poses,loc))
    return result
