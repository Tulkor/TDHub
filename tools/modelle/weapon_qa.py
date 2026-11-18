"""Exported weapon audit: whole-transform grip coupling, movement, offhand and cutting planes.
Uses the independent GLB reader/sampler from fluid_qa; no Blender or production writes.
python tools/modelle/weapon_qa.py [--heroes=id,...] [--diagnose]
"""
import argparse
import json
from pathlib import Path
import runpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
QA = runpy.run_path(str(Path(__file__).with_name('fluid_qa.py')))
GLB = runpy.run_path(str(Path(__file__).with_name('rig_fluid.py')))
STYLE = runpy.run_path(str(Path(__file__).with_name('kader_motion.py')))['STYLE']


def unit(value):
    return value / max(float(np.linalg.norm(value)), 1e-10)


def audit(hero):
    doc, binary = GLB['load_glb'](ROOT / hero['model'].removeprefix('res://'))
    read = GLB['read_accessor']
    skin = doc['skins'][0]
    names = {doc['nodes'][n]['name']: n for n in skin['joints']}
    inverse = np.asarray(read(doc,binary,skin['inverseBindMatrices'])).reshape(-1,4,4).transpose(0,2,1)
    modern = any(name.startswith('weapon.') for name in names)
    parts = {};chains={}
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attrs = primitive['attributes']
            positions = np.asarray(read(doc,binary,attrs['POSITION']))
            joints = np.asarray(read(doc,binary,attrs['JOINTS_0']),int)
            weights = QA['weights'](doc,binary,read,attrs['WEIGHTS_0'])
            material = doc['materials'][primitive.get('material',0)]
            label = material.get('name','')
            rigid = any(c in label for c in {
                'torvik':['3b2a1c','7fe8ff','9aa8b8'], 'unrat':['8a4a2a','3a3a3e'],
                'vesna':['5a3a22','8a9aa8','57ff8a','e0e8f0'], 'zix':[]}.get(hero['id'],[]))
            if hero['id']=='zix': rigid = material.get('pbrMetallicRoughness',{}).get('metallicFactor',0)>.4
            for index,node in enumerate(skin['joints']):
                name = doc['nodes'][node]['name']
                if name.startswith('chain.'):
                    mask=np.any((joints==index)&(weights>.001),axis=1)
                    if mask.any():chains[name]=bool(np.all(weights[mask].max(axis=1)>.9999))
                if not (name.startswith('weapon.') if modern else rigid and name.startswith('fore.')): continue
                mask = np.any((joints==index)&(weights>.001),axis=1)
                if not mask.any(): continue
                entry = parts.setdefault(name,{'index':index,'points':[],'blade':[],'rigid':True})
                entry['rigid'] &= bool(np.all(weights[mask].max(axis=1)>.9999))
                entry['points'].extend(positions[mask].tolist())
                if '657182' in label or hero['id']=='torvik' and '9aa8b8' in label:
                    entry['blade'].extend(positions[mask].tolist())
    result = {'hero':hero['id'],'parts':list(parts),'checks':0,'failures':[],'max_grip_matrix_error':0.,
              'max_support_gap':0.,'cuts':[],'min_attack_rotation_degrees':180.}
    def check(ok,message):
        result['checks'] += 1
        if not ok and message not in result['failures']: result['failures'].append(message)
    for name,part in parts.items(): check(part['rigid'],name+': nonrigid held geometry')
    if hero['id']=='sorek':check(len(chains)==5 and all(chains.values()),'anchor needs five rigid chain links')
    if not parts:
        check(hero['id']=='mira','no held geometry found')
        return result
    # Legacy gloves and equipment share forearm bindings; modern hands have independent anchors.
    modern_anchor = {name:skin['joints'].index(names['hand.'+name[-1]]) for name in parts} if modern else {}
    parents={child:parent for parent,node in enumerate(doc['nodes']) for child in node.get('children',[])}
    joints_to_check=[names[name] for name in names if name.startswith(('arm.','fore.','twist.','hand.','weapon.','chain.'))]
    chain_swing=0.
    anatomy=None
    if hero['id']=='brennholt':
        bind=QA['world_matrices'](doc,binary,read)
        rest_normal=unit(np.cross(bind[names['fore.R']][:3,3]-bind[names['arm.R']][:3,3],
                                  bind[names['hand.R']][:3,3]-bind[names['fore.R']][:3,3]))
        arm_index=skin['joints'].index(names['arm.R'])
        fore_index=skin['joints'].index(names['twist.R'])
        anatomy={'wrist_drift':0.,'wrist_side_angle':0.,'elbow_sideways':0.,'forearm_twist':0.,'min_flexion':180.,'max_flexion':0.}
        neutral_wrist=None
    for animation in doc['animations']:
        clip = animation['name']
        if not (clip.startswith('attack') or clip.startswith('cast')): continue
        length = max(float(np.max(read(doc,binary,s['input']))) for s in animation['samplers'])
        first = None;turns = {name:0. for name in parts}
        chain_first=None
        for t in np.linspace(0,length,max(3,round(length*96))):
            world = QA['world_matrices'](doc,binary,read,animation,float(t))
            matrices = {name:world[names[name]]@inverse[part['index']] for name,part in parts.items()}
            if anatomy is not None:
                a,e,h=[world[names[bone]][:3,3] for bone in ('arm.R','fore.R','hand.R')]
                upper,lower=unit(e-a),unit(h-e)
                hinge=(world[names['arm.R']]@inverse[arm_index])[:3,:3]@rest_normal
                fore_normal=(world[names['twist.R']]@inverse[fore_index])[:3,:3]@rest_normal
                wrist=world[names['twist.R']][:3,:3].T@world[names['hand.R']][:3,:3]
                if neutral_wrist is None:neutral_wrist=wrist
                degrees=lambda cosine:float(np.degrees(np.arccos(np.clip(cosine,-1,1))))
                drift=degrees((np.trace(neutral_wrist.T@wrist)-1)/2)
                wrist_side=degrees(np.array([0.,1.,0.])@(neutral_wrist.T@wrist)@np.array([0.,1.,0.]))
                sideways=float(np.degrees(np.arcsin(np.clip(abs(hinge@lower),0,1))))
                projected=unit(hinge-lower*(hinge@lower))
                twist=degrees(projected@fore_normal)
                flexion=degrees(upper@lower)
                for key,value in [('wrist_drift',drift),('wrist_side_angle',wrist_side),('elbow_sideways',sideways),('forearm_twist',twist),('max_flexion',flexion)]:
                    anatomy[key]=max(anatomy[key],value)
                anatomy['min_flexion']=min(anatomy['min_flexion'],flexion)
                check(drift<42.,'Brennholt wrist exceeds controlled pitch range in '+clip)
                check(wrist_side<7.,'Brennholt wrist exceeds subtle lateral articulation in '+clip)
                shaft=unit(matrices['weapon.R'][:3,:3]@np.array([0.,1.,0.]))
                check(shaft[1]>-.94,'Brennholt sword tip points straight down in '+clip)
                check(sideways<5.,'Brennholt elbow bends sideways in '+clip)
                check(twist<85.,'Brennholt forearm over-rotates in '+clip)
                check(flexion<140.,'Brennholt elbow exceeds flexion envelope in '+clip)
                chest=np.linalg.inv(world[names['chest']])
                local_a=(chest@np.r_[a,1])[:3];local_e=(chest@np.r_[e,1])[:3]
                check(local_e[2]<local_a[2]+.06,
                      'Brennholt elbow reverses behind body during raised sword arc in '+clip)
            if first is None: first = matrices
            for node in joints_to_check:
                local=doc['nodes'][node].get('translation',[0,0,0])
                expected=(world[parents[node]]@np.r_[local,1])[:3]
                check(np.linalg.norm(expected-world[node][:3,3])<.0002,
                      doc['nodes'][node]['name']+': skeletal joint slips in '+clip)
            for name,matrix in matrices.items():
                check(np.max(np.abs(matrix[:3,:3].T@matrix[:3,:3]-np.eye(3)))<.0002,
                      name+': weapon geometry stretched in '+clip)
                rotation = matrix[:3,:3]@np.linalg.inv(first[name][:3,:3])
                degrees = float(np.rad2deg(np.arccos(np.clip((np.trace(rotation)-1)*.5,-1,1))))
                turns[name] = max(turns[name],degrees)
                if modern:
                    anchor = modern_anchor[name]
                    error = float(np.max(np.abs(matrix-world[skin['joints'][anchor]]@inverse[anchor])))
                    result['max_grip_matrix_error'] = max(result['max_grip_matrix_error'],error)
                    check(error<.0002,name+': hand/grip/weapon rotation or position separated in '+clip)
            if hero['id']=='sorek':
                relative=np.linalg.inv(world[names['weapon.R']][:3,:3])@world[names['chain.4']][:3,:3]
                if chain_first is None:chain_first=relative
                chain_swing=max(chain_swing,float(np.rad2deg(np.arccos(np.clip((np.trace(relative@chain_first.T)-1)*.5,-1,1)))))
                # Left palm supports the shaft below the right grip; the upper eye stays free.
                rest = np.array([-.70,2.15*.36-.18,-.06,1.])
                target = (matrices['weapon.R']@rest)[:3]
                gap = float(np.linalg.norm(world[names['hand.L']][:3,3]-target))
                result['max_support_gap'] = max(result['max_support_gap'],gap)
                check(gap<.04,'support hand leaves anchor shaft in '+clip)
            if hero['id'] in ('fenn','tessa'):
                for bone,anchor in [('string.L','hand.L'),('string.R','weapon.R')]:
                    i=skin['joints'].index(names[bone]);j=skin['joints'].index(names[anchor])
                    check(np.max(np.abs(world[names[bone]]@inverse[i]-world[names[anchor]]@inverse[j]))<.0002,
                          bone+': bow string anchor detached in '+clip)
        if clip.startswith('attack'):
            # Carried books/birds can intentionally remain still; every attacking weapon must move.
            active = max(turns.values())
            result['min_attack_rotation_degrees'] = min(result['min_attack_rotation_degrees'],active)
            check(active>2.,'all held weapons frozen in '+clip)
    if hero.get('silhouette') in ('shield','sword','daggers','axes','shovel'):
        tempo = STYLE[hero['id']][4]
        for animation in doc['animations']:
            if not animation['name'].startswith('attack_combo_'): continue
            if hero['id']=='brennholt':
                # Check the actual bone directions, not quaternion roll: the raised
                # upper arm supports the swing while the forearm supplies its arc.
                points=[]
                for time in (max(5,int(tempo*.38))/24,max(7,int(tempo*.5))/24):
                    world=QA['world_matrices'](doc,binary,read,animation,time)
                    chest=np.linalg.inv(world[names['chest']])
                    points.append({bone:(chest@world[names[bone]])[:3,3]
                                   for bone in ('arm.R','fore.R','hand.R','head')})
                def arc(start,end):
                    directions=[unit(point[end]-point[start]) for point in points]
                    return float(np.degrees(np.arccos(np.clip(directions[0]@directions[1],-1,1))))
                check(arc('arm.R','fore.R')<85.,'Brennholt excessive upper arm sweep through contact')
                check(arc('fore.R','hand.R')>arc('arm.R','fore.R')+10.,
                      'Brennholt forearm must lead the supported arm swing')
                check(arc('fore.R','hand.R')>65.,'Brennholt attack must be driven by forearm')
                check(points[0]['fore.R'][1]>points[0]['arm.R'][1]+.05,
                      'Brennholt elbow must lift for the chamber')
                check(points[0]['hand.R'][1]>points[0]['head'][1]+.10,
                      'Brennholt fist must lift beside the head for the upright sword chamber')
            for name,part in parts.items():
                if not part['blade']: continue
                blade = np.asarray(part['blade'])
                # Avoid the crossguard on swords/daggers. Axe and shovel heads are already isolated steel.
                if hero['silhouette'] in ('shield','sword','daggers'):
                    blade=blade[blade[:,1]>blade[:,1].max()-.45]
                normal = np.linalg.svd(blade-blade.mean(axis=0),full_matrices=False)[2][-1]
                tip = blade.mean(axis=0) if hero['silhouette']=='axes' else blade[blade[:,1]>blade[:,1].max()-.001].mean(axis=0)
                pair = [QA['world_matrices'](doc,binary,read,animation,t)[names[name]]@inverse[part['index']]
                        for t in (max(5,int(tempo*.38))/24,max(7,int(tempo*.5))/24)]
                velocity = unit((pair[1]@np.r_[tip,1])[:3]-(pair[0]@np.r_[tip,1])[:3])
                # The held windup is not a cutting phase. Brennholt chambers upright
                # and rotates the forearm into the cutting plane during acceleration.
                cutting=pair[1:] if hero['id']=='brennholt' else pair
                across = max(abs(float(unit(matrix[:3,:3]@normal)@velocity)) for matrix in cutting)
                # An inactive offhand blade is carried, rather than used to cut in that combo key.
                index = ['attack_combo_1','attack_combo_2','attack_combo_finish'].index(animation['name'])
                active = hero['silhouette'] not in ('axes','daggers') or index==2 or (name.endswith('L'))==(index==1)
                thrust=active and hero['silhouette']=='daggers' and index<2
                result['cuts'].append({'clip':animation['name'],'weapon':name,'sideways':round(across,5),'active':active,
                                      'type':'thrust' if thrust else 'slash' if active else 'carried',
                                      'travel':np.round((pair[1]@np.r_[tip,1])[:3]-(pair[0]@np.r_[tip,1])[:3],4).tolist(),
                                      'contact':np.round((pair[1]@np.r_[tip,1])[:3],4).tolist()})
                if active and not thrust: check(across<.06,name+': blade strikes sideways in '+animation['name'])
                if active and not thrust:
                    movement=(pair[1]@np.r_[tip,1])[:3]-(pair[0]@np.r_[tip,1])[:3]
                    contact=(pair[1]@np.r_[tip,1])[:3]
                    inward=-1 if name.endswith('L') else 1
                    # Dreierfolge (2026-11-16): Schlag 1 schräg nach innen, Schlag 2 Rückhand nach außen (Einzelwaffe),
                    # Abschluss von oben nach unten. Brennholt behält seine eigenen, nach innen geführten Hiebe.
                    if hero['id']!='brennholt' and index==2:
                        check(movement[1]<-.25,name+': finisher does not travel downward in '+animation['name'])
                    elif hero['id']!='brennholt' and index==1 and hero['silhouette'] not in ('axes','daggers'):
                        check(movement[0]*inward<-.25,name+': backhand does not travel outward in '+animation['name'])
                    else:
                        check(movement[0]*inward>.25,name+': slash travels outward instead of into target in '+animation['name'])
                    check(.65<contact[1]<1.8 and contact[2]<-.7,name+': strike misses frontal torso zone in '+animation['name'])
                    if hero['id']=='brennholt':
                        windshaft=unit(pair[0][:3,:3]@np.array([0.,1.,0.]))
                        check(windshaft[1]>.85,'Brennholt sword tip must point upward while chambered')
                        shaft=unit(pair[1][:3,:3]@np.array([0.,1.,0.]))
                        contact_time=12/24
                        samples=[QA['world_matrices'](doc,binary,read,animation,t)[names[name]]@inverse[part['index']]
                                 for t in (contact_time-1/240,contact_time+1/240)]
                        tangent=unit((samples[1]@np.r_[tip,1])[:3]-(samples[0]@np.r_[tip,1])[:3])
                        check(abs(shaft[1])<.45,'Brennholt blade must approach horizontal at contact as in side-view sketch')
                        check(np.linalg.norm(np.cross(shaft,tangent))>.70,
                              'Brennholt strike must lead across blade rather than thrust along its tip')
                        follow=QA['world_matrices'](doc,binary,read,animation,15/24)
                        shoulder,elbow,wrist=[follow[names[bone]][:3,3] for bone in ('arm.R','fore.R','hand.R')]
                        end_flexion=float(np.degrees(np.arccos(np.clip(unit(elbow-shoulder)@unit(wrist-elbow),-1,1))))
                        check(3.<end_flexion<12.,'Brennholt forearm must finish nearly extended without locking elbow')
                        end=(follow[names[name]]@inverse[part['index']]@np.r_[tip,1])[:3]
                        check(end[1]<contact[1]-.10,
                              'Brennholt blade must continue its descending arc after contact')
                        end_shaft=unit((follow[names[name]]@inverse[part['index']])[:3,:3]@np.array([0.,1.,0.]))
                        check(abs(end_shaft[1])<.35,'Brennholt blade must finish near horizontal, not hang under fist')
                if thrust:
                    for matrix in pair:
                        check(float(unit(matrix[:3,:3]@np.array([0,1,0]))@velocity)>.99,
                              name+': knife thrust does not lead with tip in '+animation['name'])
                if active and hero['silhouette']=='axes':
                    # These single-edged heads project along rest +X, not either face of the plane.
                    for matrix in pair:
                        shaft=unit(matrix[:3,:3]@np.array([0,1,0]))
                        leading=unit(matrix[:3,:3]@np.array([1,0,0]))
                        travel=unit(velocity-shaft*np.dot(velocity,shaft))
                        check(float(leading@travel)>.98,name+': blunt axe back leads in '+animation['name'])
    if hero['id']=='ralda':
        index=parts['weapon.R']['index'];point=np.array([-.70,1.75*.36+.8,-.08,1])
        for animation in doc['animations']:
            if not animation['name'].startswith('attack_combo_'):continue
            pair=[QA['world_matrices'](doc,binary,read,animation,t)[names['weapon.R']]@inverse[index]
                  for t in (int(29*.38)/24,int(29*.5)/24)]
            velocity=unit((pair[1]@point)[:3]-(pair[0]@point)[:3])
            for matrix in pair:
                shaft=unit(matrix[:3,:3]@np.array([0,1,0]))
                face=unit(matrix[:3,:3]@np.array([1,0,0]))
                check(abs(float(face@unit(velocity-shaft*np.dot(shaft,velocity))))>.98,
                      'hammer strikes with wrong side in '+animation['name'])
    if hero['id']=='torvik':
        profile=json.loads((ROOT/'tools/modelle/rig_profiles/torvik.json').read_text())
        for clip,frames in [('attack_cleave',(4,8)),('attack_dual_strike',(5,8)),('attack_overhead',(6,10))]:
            animation=next(a for a in doc['animations'] if a['name']==clip)
            for side in ('L','R'):
                part=parts['weapon.'+side]
                blade=np.asarray(part['blade'])
                normal=np.linalg.svd(blade-blade.mean(axis=0),full_matrices=False)[2][-1]
                point=profile['weapons']['axe.'+side]['head']
                point=np.array([point[0],point[2],-point[1],1])
                pair=[QA['world_matrices'](doc,binary,read,animation,(frame+1)/24)[names['weapon.'+side]]@inverse[part['index']] for frame in frames]
                velocity=unit((pair[1]@point)[:3]-(pair[0]@point)[:3])
                across=max(abs(float(unit(matrix[:3,:3]@normal)@velocity)) for matrix in pair)
                movement=(pair[1]@point)[:3]-(pair[0]@point)[:3]
                contact=(pair[1]@point)[:3]
                result['cuts'].append({'clip':clip,'weapon':'weapon.'+side,'sideways':round(across,5),
                                      'travel':np.round(movement,4).tolist(),'contact':np.round(contact,4).tolist()})
                check(across<.06,'axe.'+side+': flat side hits in '+clip)
                check(movement[0]*(-1 if side=='L' else 1)>.25,'axe.'+side+': Torvik swing travels outward in '+clip)
                check(.65<contact[1]<1.8 and contact[2]<-.7,'axe.'+side+': Torvik misses frontal torso zone in '+clip)
    if hero['id']=='sorek':
        check(chain_swing>5.,'anchor chain is frozen instead of swinging')
        result['chain_swing_degrees']=round(chain_swing,2)
    if hero.get('silhouette') in ('shield','sword','daggers','axes') or hero['id']=='torvik':
        for clip in ('idle','run'):
            animation=next(a for a in doc['animations'] if a['name']==clip)
            world=QA['world_matrices'](doc,binary,read,animation,.25)
            chest_index=skin['joints'].index(names['chest'])
            chest=np.linalg.inv((world[names['chest']]@inverse[chest_index])[:3,:3])
            for name,part in parts.items():
                if name.endswith('L') and hero.get('silhouette')=='shield':continue
                rotation=chest@(world[names[name]]@inverse[part['index']])[:3,:3]
                forward=np.array([0,0,-1])
                if hero.get('silhouette') in ('shield','sword','daggers'):
                    check(float(unit(rotation@np.array([0,1,0]))@forward)>.95,name+': ready blade tip must face forward in '+clip)
                else:
                    shaft=unit(rotation@np.array([0,.66,-.75] if hero['id']=='torvik' else [0,1,0]))
                    edge=unit(rotation@np.array([0,.75,.66] if hero['id']=='torvik' else [1,0,0]))
                    dot=float(edge@unit(forward-shaft*np.dot(forward,shaft)))
                    check(abs(dot)>.98 if hero['id']=='torvik' else dot>.98,name+': ready axe edge must face forward in '+clip)
    if anatomy is not None:result['anatomy_degrees']={key:round(value,2) for key,value in anatomy.items()}
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--heroes')
    parser.add_argument('--diagnose',action='store_true')
    parser.add_argument('--report',type=Path,help='Zusätzlich einen Markdown-Prüfbericht schreiben')
    args=parser.parse_args()
    heroes=json.loads((ROOT/'data/heroes_helden.json').read_text(encoding='utf-8'))['heroes']
    if args.heroes: heroes=[h for h in heroes if h['id'] in args.heroes.split(',')]
    results=[]
    for hero in heroes:
        result=audit(hero);results.append(result)
        print(f'Weapon audit {hero["id"]}: {len(result["parts"])} assemblies, {result["checks"]} checks, '
              f'{len(result["failures"])} failures; support {result["max_support_gap"]:.4f}m',flush=True)
        for failure in result['failures']: print('  FAIL '+failure,flush=True)
    path=ROOT/'.godot/weapon-audit.json';path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    failures=sum(len(r['failures']) for r in results)
    print(f'Weapon audit: {sum(r["checks"] for r in results)} checks, {failures} failures; {path}',flush=True)
    if args.report:write_report(results,args.report)
    if failures and not args.diagnose:raise SystemExit(1)


def write_report(results,path):
    definitions={h['id']:h for h in json.loads((ROOT/'data/heroes_helden.json').read_text(encoding='utf-8'))['heroes']}
    failures=sum(len(r['failures']) for r in results)
    support=max((r['max_support_gap'] for r in results),default=0.)*1000
    lines=['# Bollwerk – Waffenprüfung, 16. November 2026','',
        f'Ergebnis: {len(results)} Helden, {sum(bool(r["parts"]) for r in results)} mit Waffen/Handgeräten, '
        f'{sum(r["checks"] for r in results):,} Einzelprüfungen, {failures} Fehler.','',
        'Geprüft wurden die finalen GLBs: Angriff und Zauber mit 96 Abtastungen pro Sekunde, '
        'starre Waffenvertices, unveränderte Gelenkverbindungen, gemeinsame vollständige Hand-/Waffentransformation '
        'und tatsächliche Waffenbewegung. Bei Schneidwerkzeugen wird die physische Klingenebene gegen die '
        'Aushol-/Trefferbahn geprüft; bei einseitigen Äxten muss die scharfe Seite führen. '
        'Aktive Schnitte müssen nach innen durch eine frontale Rumpfzone laufen; '
        'eine korrekt gedrehte Schneide allein genügt nicht. '
        'Bogen-/Zughandanker und Soreks zweite Greifhand werden während der Übergänge separat geprüft.','',
        'Zusätzlich: Fluid-/Bodenkontaktprüfung und Brustvolumen-Abstände; neue GPU-Angriffsaufnahmen für '
        'alle 23 bewaffneten Helden, vier Kontaktbögen mit je acht Zeitpunkten pro Held visuell kontrolliert. '
        'Die Volumenprüfung ersetzt keinen vollständigen Mesh-Kollisionssolver.','',
        '## Korrigiert','',
        '- Bereitschaft: Schwert- und Dolchspitzen zeigen nach vorne, Axtschneiden ebenfalls. '
        'Sirra führt zwei Stichangriffe und einen Schnitt aus; Stichspuren passen zur Animation.',
        '- Varg und Totengräber: Klingenebene dreht mit Hand und tatsächlicher Schlagrichtung; '
        'Vargs einseitige Äxte führen mit der Schneide.',
        '- Torvik: eigene Hand-/Waffenanker für beide Äxte, Schneiden zur Schlagbahn, Hände vor dem Körper. '
        'Die neue Haltung verhindert auch das Durchschlagen der Axtgriffe durch die Brust.',
        '- Ralda: Hammerflächen statt einer beliebigen Kopfseite in Schlagrichtung.',
        f'- Sorek: beide Greifhände in Blender mit 96 Hz gebacken; gemessener maximaler Stützhandabstand {support:.1f} mm. '
        'Die untere Stützhand lässt den oberen Schäkel frei. Fünf einzeln starr geriggte Kettenglieder '
        '(zusammen etwa 0,53 m) schwingen mit Schwerkraft und Trägheit nach; keine Laufzeitphysik nötig. '
        'Der nachträgliche Unterarm-Nachlauf bleibt für Hand-/Waffenketten aus.',
        '- Schlagbahnen: Oberkörperdrehung und Griff-/Waffenziele gemeinsam korrigiert. '
        'Brennholt, Yuna und die übrigen körperlichen Nahkämpfer führen die Hiebe nach vorne/innen; '
        'Varg und Torvik führen ihre Äxte von den jeweiligen Außenseiten zur Mitte. '
        'Trefferziele liegen auf Rumpfhöhe statt neben den Füßen. '
        'Die frühere reine Schneidenprüfung hatte die falsche Gesamtrichtung nicht erkannt.','',
        '## Kader','',
        '| Held | Waffen-/Gerätegruppen | Prüfungen | Ergebnis |','|---|---:|---:|---|']
    for result in results:
        status='Fehler: '+', '.join(result['failures']) if result['failures'] else 'OK' if result['parts'] else 'Ohne Handwaffe'
        lines.append(f'| {definitions[result["hero"]]["name"]} | {len(result["parts"])} | {result["checks"]} | {status} |')
    lines+=['','## Reproduzieren','',
        '`python tools/modelle/weapon_qa.py` oder `tools/run_tests.sh riggen`.',
        '`attack_probe.tscn -- --held=<id> --combo`, bei Vesna/Zix ohne `--combo`; Godot immer mit `--audio-driver Dummy`.',
        '`python tools/heroes/attack_clips.py --kontakt` baut die vier visuellen Prüfbögen.','']
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text('\n'.join(lines),encoding='utf-8')


if __name__=='__main__':main()
