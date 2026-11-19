"""Short anchor chain: rigid alternating links, gravity, inertial lag; baked in Blender."""
import math
import numpy as np
import bpy


def bake(rig,f,api):
    tracks=list(rig.animation_data.nla_tracks)
    for track in tracks:track.mute=True
    names=[f'chain.{k}' for k in range(5)]
    rest={name:rig.data.bones[name].matrix_local.to_quaternion() for name in names}
    weapon_rest=rig.data.bones['weapon.R'].matrix_local.inverted()
    chest_rest=rig.data.bones['chest'].matrix_local.inverted()
    length=.105;dt=1/bpy.context.scene.render.fps
    for track in tracks:
        action=track.strips[0].action
        rig.animation_data.action=action
        samples=[]
        for frame in range(math.ceil(action.frame_range[1])+1):
            bpy.context.scene.frame_set(frame)
            weapon=rig.pose.bones['weapon.R'].matrix@weapon_rest
            chest=rig.pose.bones['chest'].matrix@chest_rest
            samples.append((np.array(weapon@f.chain_root),np.array(weapon.to_3x3()),np.array(chest)))
        positions=np.array([samples[0][0]+[0,0,-k*length] for k in range(6)])
        old=positions.copy();poses=[]
        looping=track.name in ('idle','run')
        # Warm up cyclic states; only the last cycle is exported.
        for cycle in range(5 if looping else 1):
            poses=[]
            for root,parent,chest in samples:
                previous=positions.copy()
                positions[1:]+=(positions[1:]-old[1:])*.98+np.array([0,0,-9.81])*dt*dt
                old=previous
                inverse=np.linalg.inv(chest)
                for _ in range(12):
                    positions[0]=root
                    for k in range(5):
                        delta=positions[k+1]-positions[k]
                        distance=max(np.linalg.norm(delta),1e-7)
                        error=delta*(1-length/distance)
                        if k:positions[k]+=error*.5;positions[k+1]-=error*.5
                        else:positions[k+1]-=error
                    for k in range(1,6):
                        local=(inverse@np.r_[positions[k],1])[:3]
                        center=np.array(f.weapon_torso['center'])
                        radii=np.array(f.weapon_torso['radii'])+.04
                        offset=(local-center)/radii;distance=np.linalg.norm(offset)
                        if .001<distance<1:
                            local=center+offset/distance*radii
                            positions[k]=(chest@np.r_[local,1])[:3]
                        positions[k,2]=max(.035,positions[k,2])
                # Exact segment lengths, so individual metal links never stretch.
                positions[0]=root
                for k in range(5):
                    delta=positions[k+1]-positions[k]
                    positions[k+1]=positions[k]+delta/max(np.linalg.norm(delta),1e-8)*length
                rotations=[]
                for k in range(5):
                    direction=api['Vector'](positions[k+1]-positions[k]).normalized()
                    desired=np.array(api['Vector']((0,0,-1)).rotation_difference(direction).to_matrix())
                    local=api['Matrix']((parent.T@desired).tolist()).to_quaternion()
                    rotations.append(rest[names[k]].inverted()@local@rest[names[k]])
                    parent=desired
                poses.append(rotations)
        for frame,rotations in enumerate(poses):
            blend=max(0.,(frame/max(len(poses)-1,1)-.9)/.1) if looping else 0.
            for k,name in enumerate(names):
                bone=rig.pose.bones[name]
                bone.rotation_quaternion=rotations[k].slerp(poses[0][k],blend) if blend else rotations[k]
                bone.keyframe_insert('rotation_quaternion',frame=frame)
    rig.animation_data.action=None
    for track in tracks:track.mute=False
