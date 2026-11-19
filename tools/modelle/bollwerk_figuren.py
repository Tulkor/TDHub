# Bollwerk (Hero Defense): die Moor-Gegner als eigene Low-Poly-Modelle (eigene Arbeit, CC0).
# Jede Figur ist eine Funktion aus einfachen Teilen (Kugel, Zylinder, Kegel, Quader), leicht verbeult für einen
# handgemachten Look, mit flacher Schattierung. Jedes Teil hängt starr an einem Knochen (body, head, arm.L …);
# das Skelett wird aus den Teilen abgeleitet, dazu Animationen idle, run, attack, cast, hit, death.
# Maße in Spieleinheiten, Höhe = size[1] in data/heroes.json. Heldenmodelle: helden_bau.py.
# Blender: Z oben, Blick nach -Y (wird im glTF zu +Z, der Blickrichtung in hd_enemy.gd).
#
#   <python mit bpy> -I tools/modelle/bollwerk_figuren.py -- <zielordner> [--nur=torvik,grolm] [--bogen=bogen.png]
#
# Ohne --bogen nur .glb je Figur; mit --bogen zusätzlich ein Vorschau-Kontaktbogen (Cycles, CPU).
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Euler, Quaternion

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ZIEL = argv[0] if argv else '/tmp/bollwerk'
NUR = next((a.split('=', 1)[1].split(',') for a in argv if a.startswith('--nur=')), None)
BOGEN = next((a.split('=', 1)[1] for a in argv if a.startswith('--bogen=')), '')
POSEN = next((a.split('=', 1)[1] for a in argv if a.startswith('--posen=')), '')
GRUPPE = next((a.split('=', 1)[1] for a in argv if a.startswith('--gruppe=')), '')

FARBEN = {
    # Held
    'stahl': (0.23, 0.50, 0.78), 'stahl_dunkel': (0.12, 0.24, 0.42), 'leder': (0.36, 0.22, 0.12),
    'fell': (0.55, 0.45, 0.32), 'haut': (0.84, 0.62, 0.46), 'bart': (0.62, 0.30, 0.10), 'holz': (0.42, 0.27, 0.13),
    'blitz': (0.45, 0.90, 1.00), 'gold': (0.85, 0.65, 0.22), 'umhang': (0.10, 0.20, 0.45), 'weiss': (0.90, 0.90, 0.88),
    # Moor
    'moos': (0.30, 0.42, 0.16), 'moos_hell': (0.48, 0.60, 0.22), 'sumpf': (0.24, 0.36, 0.24), 'sumpf_dunkel': (0.13, 0.20, 0.15),
    'schlamm': (0.36, 0.26, 0.15), 'schlamm_hell': (0.52, 0.40, 0.24), 'knochen': (0.85, 0.80, 0.66),
    'kroete': (0.42, 0.62, 0.18), 'kroete_bauch': (0.78, 0.76, 0.42), 'gift': (0.55, 1.00, 0.20),
    'robe': (0.30, 0.18, 0.42), 'robe_dunkel': (0.17, 0.10, 0.25), 'rost': (0.42, 0.25, 0.14), 'eisen': (0.30, 0.31, 0.33),
    'stein': (0.38, 0.38, 0.36), 'auge': (1.00, 0.82, 0.25), 'auge_rot': (1.00, 0.30, 0.15), 'zahn': (0.92, 0.88, 0.72),
    'lila_glut': (0.75, 0.35, 1.00), 'schwarz': (0.02, 0.02, 0.02), 'wurzel': (0.30, 0.20, 0.12), 'krone': (0.70, 0.55, 0.20),
}
GLUT = {'blitz': 3.0, 'auge': 4.0, 'auge_rot': 4.0, 'gift': 1.5, 'lila_glut': 3.0}


def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    c = FARBEN[name]
    p.inputs['Base Color'].default_value = (*c, 1)
    p.inputs['Roughness'].default_value = 0.35 if name in ('stahl', 'stahl_dunkel', 'gold', 'eisen', 'krone') else 0.8
    p.inputs['Metallic'].default_value = 0.6 if name in ('stahl', 'gold', 'eisen', 'krone') else 0.0
    if name in GLUT:
        p.inputs['Emission Color'].default_value = (*c, 1)
        p.inputs['Emission Strength'].default_value = GLUT[name]
    return m


class Figur:
    """Sammelt Teile einer Figur; jedes Teil weiß seinen Knochen (für das spätere Skelett)."""

    def __init__(self, name, seed=1):
        self.name = name
        self.teile = []
        self.rng = random.Random(seed)

    def _fertig(self, ob, farbe, ort, gross, dreh, knochen, beule):
        ob.location = ort
        ob.scale = gross
        ob.rotation_euler = Euler([math.radians(a) for a in dreh])
        ob.data.materials.append(mat(farbe))
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        if beule:
            for v in ob.data.vertices:
                v.co += Vector([self.rng.uniform(-beule, beule) for _ in range(3)])
        for p in ob.data.polygons:
            p.use_smooth = False
        vg = ob.vertex_groups.new(name=knochen)
        vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
        self.teile.append(ob)
        return ob

    def kugel(self, farbe, ort, gross, dreh=(0, 0, 0), knochen='body', beule=0.0, stufe=1):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=stufe, radius=1)
        return self._fertig(bpy.context.object, farbe, ort, gross, dreh, knochen, beule)

    def rund(self, farbe, ort, gross, dreh=(0, 0, 0), knochen='body', beule=0.0, seg=8, ringe=6):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ringe, radius=1)
        return self._fertig(bpy.context.object, farbe, ort, gross, dreh, knochen, beule)

    def zyl(self, farbe, ort, r, h, dreh=(0, 0, 0), knochen='body', beule=0.0, seg=8, r2=None):
        if r2 is None:
            bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=1, depth=1)
        else:
            bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=1, radius2=r2 / r, depth=1)
        return self._fertig(bpy.context.object, farbe, ort, (r, r, h), dreh, knochen, beule)

    def kegel(self, farbe, ort, r, h, dreh=(0, 0, 0), knochen='body', beule=0.0, seg=6):
        bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=1, radius2=0, depth=1)
        return self._fertig(bpy.context.object, farbe, ort, (r, r, h), dreh, knochen, beule)

    def quader(self, farbe, ort, gross, dreh=(0, 0, 0), knochen='body', beule=0.0):
        bpy.ops.mesh.primitive_cube_add(size=1)
        return self._fertig(bpy.context.object, farbe, ort, gross, dreh, knochen, beule)

    def paar(self, fn, farbe, ort, *a, **k):
        """Teil links und rechts gespiegelt (x und Drehung um y/z). Knochen mit .L/.R, falls angegeben."""
        kn = k.pop('knochen', 'body')
        dreh = k.pop('dreh', (0, 0, 0))
        for s, seite in ((1, 'L'), (-1, 'R')):
            fn(farbe, (ort[0] * s, ort[1], ort[2]), *a, dreh=(dreh[0], dreh[1] * s, dreh[2] * s),
               knochen=kn.replace('.X', '.' + seite), **k)

    def zusammen(self):
        bpy.ops.object.select_all(action='DESELECT')
        for o in self.teile:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.teile[0]
        bpy.ops.object.join()
        ob = bpy.context.object
        ob.name = self.name
        return ob


# ---------------------------------------------------------------- Moor-Gegner

def sumpfling():
    """Kleiner, gebückter Moorkobold mit großem Kopf (0,9)."""
    f = Figur('sumpfling', 11)
    f.paar(f.zyl, 'sumpf', (0.12, 0, 0.12), 0.06, 0.24, knochen='leg.X')
    f.paar(f.quader, 'sumpf_dunkel', (0.12, -0.05, 0.03), (0.1, 0.16, 0.06), knochen='leg.X')
    f.kugel('moos', (0, 0.02, 0.36), (0.2, 0.18, 0.2), beule=0.02)
    f.kugel('moos_hell', (0, -0.08, 0.36), (0.14, 0.1, 0.14), beule=0.01)
    f.paar(f.zyl, 'sumpf', (0.22, -0.06, 0.32), 0.045, 0.28, dreh=(20, -30, 0), knochen='arm.X')
    f.paar(f.kegel, 'knochen', (0.26, -0.16, 0.2), 0.03, 0.09, dreh=(120, 0, 0), knochen='hand.X')
    f.kugel('moos', (0, -0.1, 0.64), (0.25, 0.22, 0.2), knochen='head', beule=0.03)
    f.paar(f.kegel, 'moos', (0.28, -0.06, 0.7), 0.06, 0.24, dreh=(0, -75, 0), knochen='head')
    f.paar(f.kugel, 'auge', (0.09, -0.28, 0.68), (0.05, 0.03, 0.05), knochen='head', stufe=1)
    f.quader('sumpf_dunkel', (0, -0.29, 0.58), (0.14, 0.03, 0.03), knochen='head')
    f.paar(f.kegel, 'zahn', (0.05, -0.29, 0.56), 0.015, 0.05, dreh=(180, 0, 0), knochen='head')
    return f


def moorklauer():
    """Breiter Kriecher mit zwei großen Scheren (1,0)."""
    f = Figur('moorklauer', 12)
    for i, (x, y) in enumerate(((0.32, 0.1), (0.36, 0.3))):
        f.paar(f.zyl, 'sumpf_dunkel', (x, y, 0.18), 0.05, 0.36, dreh=(0, 35, 0), knochen='leg.X')
    f.kugel('sumpf', (0, 0.15, 0.38), (0.36, 0.42, 0.26), beule=0.03)
    f.kugel('moos', (0, 0.22, 0.56), (0.28, 0.3, 0.12), beule=0.04)
    for i in range(4):
        f.kegel('moos_hell', (0.18 * (i % 2 * 2 - 1) * (0.5 + i * 0.2), 0.05 + i * 0.12, 0.62), 0.05, 0.16, beule=0.01)
    f.kugel('sumpf', (0, -0.22, 0.48), (0.22, 0.2, 0.18), knochen='head', beule=0.02)
    f.paar(f.kugel, 'auge_rot', (0.09, -0.4, 0.54), (0.04, 0.03, 0.04), knochen='head')
    f.paar(f.kegel, 'zahn', (0.07, -0.38, 0.4), 0.025, 0.08, dreh=(180, 0, 0), knochen='head')
    # Scheren
    f.paar(f.zyl, 'sumpf_dunkel', (0.36, -0.22, 0.38), 0.06, 0.32, dreh=(60, 0, -20), knochen='arm.X')
    f.paar(f.kugel, 'schlamm_hell', (0.42, -0.5, 0.36), (0.12, 0.18, 0.1), knochen='hand.X', beule=0.01)
    f.paar(f.kegel, 'knochen', (0.46, -0.72, 0.42), 0.05, 0.22, dreh=(95, 0, 0), knochen='hand.X')
    f.paar(f.kegel, 'knochen', (0.4, -0.7, 0.3), 0.04, 0.18, dreh=(80, 0, 0), knochen='hand.X')
    return f


def schlammwerfer():
    """Schlaksiger Werfer mit Schlammkorb auf dem Rücken (1,2)."""
    f = Figur('schlammwerfer', 13)
    f.paar(f.zyl, 'schlamm', (0.1, 0, 0.22), 0.05, 0.44, knochen='leg.X')
    f.paar(f.quader, 'schlamm', (0.1, -0.06, 0.03), (0.09, 0.2, 0.06), knochen='leg.X')
    f.zyl('schlamm_hell', (0, 0, 0.64), 0.16, 0.46, r2=0.2, beule=0.02)
    f.zyl('leder', (0, 0, 0.48), 0.18, 0.06)
    # Korb mit Schlammkugeln
    f.zyl('holz', (0, 0.24, 0.78), 0.17, 0.28, r2=0.21, beule=0.01)
    for x, y in ((0.06, 0.22), (-0.07, 0.28), (0.0, 0.18)):
        f.kugel('schlamm', (x, y, 0.95), (0.08, 0.08, 0.08), beule=0.01)
    f.paar(f.zyl, 'schlamm_hell', (0.2, -0.04, 0.72), 0.04, 0.34, dreh=(0, -10, 0), knochen='arm.X')
    f.kugel('schlamm', (-0.22, -0.12, 0.5), (0.09, 0.09, 0.09), knochen='hand.R', beule=0.01)
    f.kugel('schlamm_hell', (0, -0.04, 0.98), (0.13, 0.13, 0.15), knochen='head', beule=0.02)
    f.kegel('moos', (0, 0, 1.1), 0.15, 0.14, knochen='head', beule=0.02)
    f.paar(f.kugel, 'auge', (0.05, -0.14, 1.0), (0.03, 0.02, 0.03), knochen='head')
    return f


def speerjaeger():
    """Großer, hagerer Jäger mit Knochenmaske und Speer (1,4)."""
    f = Figur('speerjaeger', 14)
    f.paar(f.zyl, 'sumpf', (0.1, 0, 0.27), 0.05, 0.54, knochen='leg.X')
    f.paar(f.quader, 'sumpf_dunkel', (0.1, -0.05, 0.03), (0.08, 0.18, 0.06), knochen='leg.X')
    f.zyl('fell', (0, 0, 0.6), 0.17, 0.18, r2=0.13, beule=0.02)
    f.zyl('sumpf', (0, 0, 0.86), 0.13, 0.38, r2=0.17)
    f.quader('leder', (0, -0.02, 0.86), (0.05, 0.3, 0.42), dreh=(0, 35, 0))
    f.paar(f.zyl, 'sumpf', (0.2, -0.04, 0.88), 0.035, 0.36, dreh=(15, -10, 0), knochen='arm.X')
    f.kugel('sumpf', (0, -0.02, 1.18), (0.1, 0.11, 0.12), knochen='head')
    f.kugel('knochen', (0, -0.08, 1.2), (0.11, 0.07, 0.13), knochen='head', beule=0.01)
    f.paar(f.quader, 'sumpf_dunkel', (0.04, -0.15, 1.22), (0.03, 0.02, 0.02), knochen='head')
    f.paar(f.kegel, 'knochen', (0.08, 0, 1.33), 0.025, 0.16, dreh=(-15, 25, 0), knochen='head')
    # Speer schräg in der rechten Hand
    f.zyl('holz', (-0.24, -0.1, 0.9), 0.022, 1.3, dreh=(18, 0, 0), knochen='hand.R', seg=6)
    f.kegel('knochen', (-0.24, -0.31, 1.58), 0.05, 0.2, dreh=(18, 0, 0), knochen='hand.R', seg=4)
    f.quader('moos_hell', (-0.24, -0.27, 1.46), (0.08, 0.02, 0.06), knochen='hand.R')
    return f


def giftkroete():
    """Breite, flache Kröte mit Giftblasen (0,7)."""
    f = Figur('giftkroete', 15)
    f.paar(f.kugel, 'kroete', (0.42, 0.25, 0.14), (0.16, 0.24, 0.14), knochen='leg.X', beule=0.02)
    f.paar(f.quader, 'kroete', (0.38, -0.28, 0.05), (0.14, 0.14, 0.08), knochen='arm.X')
    f.kugel('kroete', (0, 0.05, 0.32), (0.5, 0.52, 0.28), beule=0.03, stufe=2)
    f.kugel('kroete_bauch', (0, -0.18, 0.24), (0.38, 0.32, 0.18), beule=0.02)
    # Giftblasen auf dem Rücken
    for x, y, r in ((0.2, 0.1, 0.08), (-0.18, 0.22, 0.1), (0.04, 0.32, 0.07), (-0.08, 0.0, 0.06), (0.26, 0.34, 0.05)):
        f.kugel('gift', (x, y, 0.56 + r * 0.2), (r, r, r))
    # Maul und Augen oben drauf
    f.quader('sumpf_dunkel', (0, -0.44, 0.3), (0.5, 0.06, 0.04), knochen='head')
    f.paar(f.kugel, 'kroete', (0.2, -0.3, 0.52), (0.1, 0.1, 0.09), knochen='head')
    f.paar(f.kugel, 'auge', (0.22, -0.37, 0.55), (0.05, 0.04, 0.05), knochen='head')
    return f


def moorbrute():
    """Massiger Koloss mit Steinfäusten und Moos auf den Schultern (1,6)."""
    f = Figur('moorbrute', 16)
    f.paar(f.zyl, 'sumpf_dunkel', (0.26, 0, 0.24), 0.14, 0.48, knochen='leg.X', r2=0.18)
    f.kugel('sumpf', (0, 0.04, 0.82), (0.55, 0.45, 0.48), beule=0.04, stufe=2)
    f.kugel('schlamm_hell', (0, -0.22, 0.7), (0.38, 0.22, 0.3), beule=0.03)
    f.paar(f.kugel, 'moos', (0.42, 0.06, 1.14), (0.3, 0.28, 0.2), knochen='arm.X', beule=0.05)
    for x, y in ((0.4, 0.15), (0.5, -0.05), (-0.44, 0.1), (-0.36, -0.06), (0.1, 0.3), (-0.12, 0.28)):
        f.kegel('moos_hell', (x, y, 1.26), 0.06, 0.18, dreh=(0, x * 30, 0), beule=0.01)
    f.paar(f.zyl, 'sumpf', (0.62, -0.06, 0.72), 0.12, 0.6, dreh=(10, -12, 0), knochen='arm.X')
    f.paar(f.kugel, 'stein', (0.68, -0.14, 0.36), (0.22, 0.22, 0.2), knochen='hand.X', beule=0.04)
    f.kugel('sumpf', (0, -0.3, 1.1), (0.2, 0.18, 0.17), knochen='head', beule=0.02)
    f.paar(f.kugel, 'auge_rot', (0.08, -0.46, 1.14), (0.04, 0.03, 0.03), knochen='head')
    f.paar(f.kegel, 'zahn', (0.1, -0.44, 1.0), 0.04, 0.12, dreh=(-10, 0, 0), knochen='head')
    return f


def sumpfhexer():
    """Gebückter Schamane in Robe mit leuchtendem Wurzelstab (1,5)."""
    f = Figur('sumpfhexer', 17)
    f.zyl('robe_dunkel', (0, 0, 0.36), 0.32, 0.72, r2=0.2, beule=0.02, seg=10)
    f.zyl('robe', (0, 0.02, 0.9), 0.22, 0.42, r2=0.16, dreh=(-8, 0, 0), beule=0.02)
    f.zyl('wurzel', (0, 0, 0.7), 0.23, 0.06, seg=10)
    for i in range(5):
        a = i / 5 * math.tau
        f.kugel('knochen', (math.sin(a) * 0.23, math.cos(a) * 0.23, 0.66), (0.04, 0.04, 0.05))
    f.paar(f.zyl, 'robe', (0.24, -0.06, 0.92), 0.08, 0.36, dreh=(25, -20, 0), knochen='arm.X', r2=0.06)
    # Kapuze mit leuchtenden Augen
    f.kegel('robe_dunkel', (0, 0.0, 1.3), 0.2, 0.42, dreh=(-15, 0, 0), knochen='head', seg=8, beule=0.01)
    f.kugel('sumpf_dunkel', (0, -0.08, 1.2), (0.12, 0.1, 0.12), knochen='head')
    f.paar(f.kugel, 'lila_glut', (0.045, -0.17, 1.22), (0.03, 0.02, 0.025), knochen='head')
    f.kegel('moos', (0, -0.16, 1.1), 0.07, 0.16, dreh=(190, 0, 0), knochen='head', beule=0.01)
    # Wurzelstab mit Kugel
    f.zyl('wurzel', (0.34, -0.2, 0.78), 0.03, 1.4, dreh=(5, 0, 0), knochen='hand.L', seg=5, beule=0.008)
    f.kugel('lila_glut', (0.34, -0.24, 1.5), (0.09, 0.09, 0.09), knochen='hand.L')
    for k in range(3):
        a = k / 3 * math.tau
        f.kegel('wurzel', (0.34 + math.cos(a) * 0.08, -0.24 + math.sin(a) * 0.08, 1.52), 0.02, 0.2,
                dreh=(math.sin(a) * -30, math.cos(a) * 30, 0), knochen='hand.L', seg=4)
    return f


def moorhauptmann():
    """Elite: gepanzerter Moorkrieger mit rostiger Rüstung, Goldbesatz, Schild und Speer (1,9)."""
    f = Figur('moorhauptmann', 18)
    f.paar(f.zyl, 'sumpf_dunkel', (0.2, 0, 0.3), 0.12, 0.6, knochen='leg.X', r2=0.14)
    f.paar(f.quader, 'eisen', (0.2, -0.06, 0.06), (0.2, 0.3, 0.12), knochen='leg.X')
    f.zyl('rost', (0, 0, 0.72), 0.34, 0.32, r2=0.3, seg=8)
    f.zyl('eisen', (0, 0, 1.12), 0.34, 0.5, r2=0.44, seg=8, beule=0.01)
    f.zyl('gold', (0, 0, 0.9), 0.36, 0.06, seg=8)
    f.paar(f.kugel, 'rost', (0.5, 0, 1.36), (0.24, 0.24, 0.18), knochen='arm.X', beule=0.02)
    f.paar(f.kegel, 'gold', (0.58, 0.02, 1.52), 0.06, 0.2, dreh=(0, -25, 0), knochen='arm.X')
    f.paar(f.zyl, 'sumpf', (0.54, -0.04, 1.02), 0.09, 0.44, dreh=(0, -8, 0), knochen='arm.X')
    f.kugel('sumpf', (0, -0.04, 1.58), (0.17, 0.17, 0.18), knochen='head')
    f.rund('eisen', (0, 0, 1.66), (0.2, 0.21, 0.18), knochen='head', seg=8, ringe=5)
    f.quader('eisen', (0, -0.19, 1.56), (0.16, 0.04, 0.06), knochen='head')
    f.paar(f.quader, 'auge_rot', (0.05, -0.19, 1.62), (0.035, 0.02, 0.02), knochen='head')
    f.paar(f.kegel, 'knochen', (0.16, 0.0, 1.8), 0.04, 0.24, dreh=(0, -30, 0), knochen='head')
    # Schild links, Speer rechts
    f.zyl('holz', (0.62, -0.32, 0.92), 0.36, 0.06, dreh=(90, 0, 10), knochen='hand.L', seg=8)
    f.zyl('gold', (0.62, -0.36, 0.92), 0.4, 0.03, dreh=(90, 0, 10), knochen='hand.L', seg=8)
    f.kugel('eisen', (0.63, -0.38, 0.92), (0.09, 0.05, 0.09), knochen='hand.L')
    f.zyl('holz', (-0.58, -0.12, 1.0), 0.03, 2.0, dreh=(8, 0, 0), knochen='hand.R', seg=6)
    f.kegel('eisen', (-0.58, -0.26, 2.06), 0.06, 0.32, dreh=(8, 0, 0), knochen='hand.R', seg=4)
    return f


def grolm():
    """Boss: riesiger Moortroll mit Wurzelgeweih-Krone, Moosmantel und einem glühenden Zyklopenauge (4,2)."""
    f = Figur('grolm', 19)
    f.paar(f.zyl, 'sumpf_dunkel', (0.48, 0.04, 0.42), 0.28, 0.84, knochen='leg.X', r2=0.32, beule=0.02)
    f.paar(f.kugel, 'stein', (0.48, -0.08, 0.1), (0.3, 0.38, 0.14), knochen='leg.X', beule=0.03)
    f.kugel('sumpf', (0, 0.1, 1.55), (1.0, 0.82, 0.85), beule=0.06, stufe=2)
    f.kugel('schlamm_hell', (0, -0.38, 1.35), (0.68, 0.4, 0.55), beule=0.05)
    # Moosmantel auf Schultern und Rücken
    f.kugel('moos', (0, 0.28, 2.05), (1.05, 0.7, 0.4), beule=0.08, stufe=2)
    for i in range(10):
        a = (i / 10 - 0.5) * 2.6
        f.kegel('moos_hell', (math.sin(a) * 0.9, 0.3 + math.cos(a) * 0.3, 2.22), 0.1, 0.32, dreh=(0, a * 25, 0), beule=0.02)
    # Arme mit Steinfäusten, lang bis fast zum Boden
    f.paar(f.kugel, 'moos', (1.0, 0.0, 2.0), (0.42, 0.42, 0.35), knochen='arm.X', beule=0.06)
    f.paar(f.zyl, 'sumpf', (1.14, -0.1, 1.3), 0.24, 1.1, dreh=(8, -10, 0), knochen='arm.X', r2=0.2, beule=0.02)
    f.paar(f.kugel, 'stein', (1.22, -0.2, 0.6), (0.4, 0.4, 0.36), knochen='hand.X', beule=0.06)
    f.paar(f.kegel, 'wurzel', (1.26, -0.4, 0.66), 0.06, 0.3, dreh=(80, 0, 0), knochen='hand.X')
    # Kopf weit vorn unten, mit Hauern, glühenden Augen und Krone
    f.kugel('sumpf', (0, -0.62, 2.18), (0.42, 0.38, 0.36), knochen='head', beule=0.04)
    f.kugel('sumpf_dunkel', (0, -0.9, 2.04), (0.3, 0.16, 0.14), knochen='head', beule=0.02)
    # ein großes Zyklopenauge mit Wulst darüber
    f.kugel('knochen', (0, -0.92, 2.3), (0.24, 0.1, 0.2), knochen='head', stufe=2)
    f.kugel('auge_rot', (0, -0.99, 2.3), (0.16, 0.06, 0.14), knochen='head', stufe=2)
    f.quader('schwarz', (0, -1.05, 2.3), (0.04, 0.02, 0.13), knochen='head')
    f.quader('sumpf_dunkel', (0, -0.9, 2.52), (0.56, 0.14, 0.1), dreh=(-15, 0, 0), knochen='head', beule=0.02)
    # Moosbart unter dem Maul
    for x in (-0.18, 0.0, 0.18):
        f.kegel('moos', (x, -0.88, 1.86), 0.09, 0.4, dreh=(180, 0, 0), knochen='head', beule=0.02)
    f.paar(f.kegel, 'zahn', (0.22, -0.98, 2.06), 0.06, 0.32, dreh=(-20, 0, -10), knochen='head')
    f.zyl('krone', (0, -0.58, 2.5), 0.32, 0.12, seg=8, beule=0.01)
    for i in range(6):
        a = i / 6 * math.tau
        f.kegel('krone', (math.cos(a) * 0.3, -0.58 + math.sin(a) * 0.3, 2.66), 0.05, 0.22, knochen='head', seg=4)
    # Wurzelgeweih
    for s, seite in ((1, 'L'), (-1, 'R')):
        f.zyl('wurzel', (0.5 * s, -0.5, 2.78), 0.06, 0.7, dreh=(0, 50 * s, 0), knochen='head', seg=5, r2=0.03, beule=0.01)
        f.zyl('wurzel', (0.74 * s, -0.5, 3.12), 0.04, 0.45, dreh=(0, 15 * s, 0), knochen='head', seg=5, r2=0.02, beule=0.01)
        f.zyl('wurzel', (0.62 * s, -0.5, 3.0), 0.03, 0.35, dreh=(0, 80 * s, 0), knochen='head', seg=5, r2=0.015)
        f.kugel('gift', (0.85 * s, -0.5, 3.32), (0.06, 0.06, 0.06), knochen='head')
    return f


# ---------------------------------------------------------------- Knochenheer (Wellen 11-20)

FARBEN.update({
    'bein_alt': (0.72, 0.68, 0.55), 'bein_dunkel': (0.45, 0.42, 0.34), 'grabtuch': (0.20, 0.14, 0.26),
    'grabtuch_hell': (0.34, 0.26, 0.42), 'gruft': (0.16, 0.17, 0.2), 'grabstein': (0.42, 0.44, 0.46),
    'geisterlicht': (0.45, 1.00, 0.80), 'seele': (0.60, 0.85, 1.00), 'altgold': (0.62, 0.50, 0.22),
})
GLUT.update({'geisterlicht': 4.0, 'seele': 3.0})


def _gerippe(f, h, breit=1.0, farbe='knochen', augen='geisterlicht', arme=True):
    """Menschliches Gerippe der Höhe h (Blick nach -Y): Beine, Becken, Wirbelsäule, Rippen, Arme, Schädel."""
    b = breit
    f.paar(f.zyl, farbe, (0.09 * b * h, 0, 0.36 * h), 0.022 * h, 0.2 * h, knochen='leg.X', seg=6)
    f.paar(f.kugel, farbe, (0.09 * b * h, -0.005 * h, 0.255 * h), (0.032 * h,) * 3, knochen='leg.X')
    f.paar(f.zyl, farbe, (0.09 * b * h, 0, 0.14 * h), 0.018 * h, 0.22 * h, knochen='leg.X', seg=6)
    f.paar(f.quader, farbe, (0.09 * b * h, -0.04 * h, 0.018 * h), (0.05 * h, 0.13 * h, 0.035 * h), knochen='leg.X')
    f.kugel(farbe, (0, 0, 0.47 * h), (0.13 * b * h, 0.07 * h, 0.055 * h))                       # Becken
    f.zyl(farbe, (0, 0.02 * h, 0.6 * h), 0.022 * h, 0.26 * h, seg=6)                           # Wirbelsäule
    for i in range(4):
        z = (0.6 + i * 0.045) * h
        r = (0.105 + 0.02 * math.sin(i * 0.9)) * b * h
        f.zyl(farbe, (0, -0.01 * h, z), r, 0.02 * h, seg=8)                                    # Rippenbögen
    f.quader(farbe, (0, -0.1 * b * h, 0.67 * h), (0.03 * h, 0.02 * h, 0.15 * h))               # Brustbein
    f.quader(farbe, (0, 0.0, 0.775 * h), (0.34 * b * h, 0.04 * h, 0.03 * h))                   # Schlüsselbein
    if arme:
        f.paar(f.kugel, farbe, (0.17 * b * h, 0, 0.77 * h), (0.035 * h,) * 3, knochen='arm.X')
        f.paar(f.zyl, farbe, (0.185 * b * h, 0, 0.67 * h), 0.017 * h, 0.2 * h, knochen='arm.X', seg=6)
        f.paar(f.zyl, farbe, (0.19 * b * h, -0.05 * h, 0.52 * h), 0.014 * h, 0.2 * h, dreh=(30, 0, 0), knochen='hand.X', seg=6)
        f.paar(f.kugel, farbe, (0.19 * b * h, -0.1 * h, 0.43 * h), (0.028 * h,) * 3, knochen='hand.X')
    # Schädel mit Kiefer und glimmenden Augen
    f.zyl(farbe, (0, 0.01 * h, 0.81 * h), 0.018 * h, 0.06 * h, knochen='head', seg=6)
    f.kugel(farbe, (0, -0.01 * h, 0.9 * h), (0.085 * h, 0.095 * h, 0.085 * h), knochen='head', stufe=2)
    f.quader(farbe, (0, -0.07 * h, 0.835 * h), (0.09 * h, 0.07 * h, 0.035 * h), knochen='head')
    f.paar(f.kugel, 'schwarz', (0.034 * h, -0.092 * h, 0.905 * h), (0.026 * h, 0.012 * h, 0.028 * h), knochen='head')
    f.paar(f.kugel, augen, (0.034 * h, -0.098 * h, 0.905 * h), (0.013 * h, 0.008 * h, 0.013 * h), knochen='head')
    f.quader('schwarz', (0, -0.105 * h, 0.868 * h), (0.018 * h, 0.01 * h, 0.03 * h), knochen='head')
    for i in range(4):
        f.quader('schwarz', ((i - 1.5) * 0.02 * h, -0.106 * h, 0.835 * h), (0.006 * h, 0.01 * h, 0.03 * h), knochen='head')


def knochenknecht():
    """Einfacher Skelettkrieger mit rostigem Kurzschwert und zerschlissenem Lendentuch (1,1)."""
    f = Figur('knochenknecht', 31)
    _gerippe(f, 1.0)
    f.zyl('grabtuch', (0, 0, 0.43), 0.15, 0.16, r2=0.12, seg=8, beule=0.01)
    f.quader('grabtuch_hell', (0.03, -0.12, 0.36), (0.12, 0.02, 0.2), dreh=(-6, 0, 4))
    f.quader('rost', (-0.19, -0.3, 0.52), (0.035, 0.42, 0.012), dreh=(35, 0, 0), knochen='hand.R')
    f.quader('eisen', (-0.19, -0.12, 0.42), (0.12, 0.025, 0.03), dreh=(35, 0, 0), knochen='hand.R')
    f.quader('rost', (0.0, -0.01, 0.99), (0.2, 0.2, 0.03), knochen='head')                       # Helmrest
    f.kegel('rost', (0.06, 0.02, 1.03), 0.03, 0.08, knochen='head', seg=4)
    return f


def knochenschuetze():
    """Schmaler Skelettschütze mit Kapuze, Langbogen und Köcher (1,3)."""
    f = Figur('knochenschuetze', 32)
    _gerippe(f, 1.0, breit=0.9, farbe='bein_alt')
    f.kugel('grabtuch', (0, 0.03, 0.92), (0.11, 0.12, 0.11), knochen='head', stufe=2)
    f.kegel('grabtuch', (0, 0.1, 0.98), 0.07, 0.16, dreh=(-60, 0, 0), knochen='head')
    f.zyl('grabtuch', (0, 0, 0.74), 0.17, 0.1, r2=0.08, seg=8, beule=0.01)
    f.zyl('leder', (0.08, 0.1, 0.66), 0.045, 0.3, dreh=(0, 20, 0), seg=6)                        # Köcher
    for i in range(3):
        f.zyl('holz', (0.12 + i * 0.02, 0.1, 0.84), 0.006, 0.12, dreh=(0, 20, 0), seg=4)
        f.kegel('bein_dunkel', (0.14 + i * 0.02, 0.1, 0.9), 0.015, 0.04, dreh=(0, 20, 0), seg=4)
    # Bogen in der linken Hand, Sehne als dünner Stab
    for k, (z, w) in enumerate(((0.62, -25), (0.26, 25))):
        f.zyl('holz', (0.19, -0.16 + (0.04 if k == 0 else 0.04), z), 0.012, 0.38, dreh=(w, 0, 0), knochen='hand.L', seg=5)
    f.zyl('bein_alt', (0.19, -0.04, 0.44), 0.003, 0.7, knochen='hand.L', seg=3)
    f.zyl('holz', (-0.19, -0.2, 0.44), 0.006, 0.34, dreh=(90, 0, 0), knochen='hand.R', seg=4)   # Pfeil
    f.kegel('eisen', (-0.19, -0.39, 0.44), 0.016, 0.05, dreh=(90, 0, 0), knochen='hand.R', seg=4)
    return f


def grabwaechter():
    """Breiter Gruftwächter: schweres Gerippe mit Grabstein als Schild und Grabkreuz als Keule (1,7)."""
    f = Figur('grabwaechter', 33)
    _gerippe(f, 1.0, breit=1.45, farbe='bein_alt')
    f.zyl('gruft', (0, 0, 0.68), 0.19, 0.2, r2=0.22, seg=8, beule=0.01)                          # Brustplatte
    f.zyl('altgold', (0, 0, 0.58), 0.2, 0.025, seg=8)
    f.paar(f.kugel, 'gruft', (0.27, 0, 0.8), (0.1, 0.1, 0.07), knochen='arm.X', beule=0.01)
    f.paar(f.kegel, 'bein_dunkel', (0.31, 0, 0.87), 0.025, 0.1, dreh=(0, -25, 0), knochen='arm.X', seg=4)
    f.zyl('gruft', (0, 0, 0.43), 0.2, 0.18, r2=0.15, seg=8)
    # Grabstein-Schild links
    f.quader('grabstein', (0.3, -0.2, 0.52), (0.3, 0.06, 0.4), knochen='hand.L', beule=0.008)
    f.zyl('grabstein', (0.3, -0.2, 0.72), 0.15, 0.06, dreh=(90, 0, 0), knochen='hand.L', seg=8)
    f.quader('gruft', (0.3, -0.235, 0.6), (0.04, 0.012, 0.2), knochen='hand.L')
    f.quader('gruft', (0.3, -0.235, 0.64), (0.14, 0.012, 0.04), knochen='hand.L')
    # Grabkreuz rechts
    f.zyl('eisen', (-0.3, -0.18, 0.72), 0.02, 0.8, dreh=(18, 0, 0), knochen='hand.R', seg=6)
    f.quader('eisen', (-0.3, -0.27, 0.98), (0.32, 0.04, 0.05), dreh=(18, 0, 0), knochen='hand.R')
    f.kegel('eisen', (-0.3, -0.31, 1.14), 0.03, 0.1, dreh=(18, 0, 0), knochen='hand.R', seg=4)
    f.rund('gruft', (0, 0.0, 0.93), (0.1, 0.11, 0.09), knochen='head', seg=8, ringe=5)           # Topfhelm
    f.quader('gruft', (0, -0.1, 0.9), (0.02, 0.02, 0.12), knochen='head')
    return f


def knochengeier():
    """Fliegender Knochenvogel: Rippenkorb, kahler Schädel mit Hakenschnabel, zerfetzte Schwingen (0,6)."""
    # Flügel/Hände starr am Arm (2026-11-17): eigener Handknochen drehte sie sonst vom Arm weg.
    f = Figur('knochengeier', 34)
    f.kugel('bein_alt', (0, 0.05, 0.3), (0.16, 0.3, 0.14), beule=0.01)
    for i in range(4):
        f.zyl('knochen', (0, -0.1 + i * 0.1, 0.3), 0.17 - i * 0.012, 0.02, dreh=(90, 0, 0), seg=8)
    f.zyl('bein_alt', (0, -0.3, 0.38), 0.035, 0.24, dreh=(60, 0, 0), knochen='head', seg=6)      # Hals
    f.kugel('knochen', (0, -0.44, 0.47), (0.09, 0.11, 0.085), knochen='head', stufe=2)
    f.kegel('bein_dunkel', (0, -0.58, 0.44), 0.045, 0.2, dreh=(100, 0, 0), knochen='head', seg=5)
    f.kegel('bein_dunkel', (0, -0.67, 0.39), 0.02, 0.08, dreh=(170, 0, 0), knochen='head', seg=4)
    f.paar(f.kugel, 'geisterlicht', (0.05, -0.5, 0.5), (0.02, 0.02, 0.02), knochen='head')
    for i in range(5):
        f.kegel('grabtuch', ((i - 2) * 0.03, -0.3, 0.33), 0.03, 0.1, dreh=(200, 0, (i - 2) * 12), knochen='head', seg=4)   # Halskrause
    # Schwingen: Knochenarm, Finger und Hautfetzen
    f.paar(f.zyl, 'knochen', (0.3, 0.0, 0.36), 0.022, 0.4, dreh=(0, -80, 0), knochen='arm.X', seg=5)
    f.paar(f.zyl, 'knochen', (0.68, 0.04, 0.36), 0.016, 0.42, dreh=(0, -95, -10), knochen='arm.X', seg=5)
    for i in range(4):
        f.paar(f.quader, 'grabtuch' if i % 2 else 'grabtuch_hell', (0.24 + i * 0.17, 0.14 + i * 0.01, 0.33),
               (0.15, 0.3 - i * 0.04, 0.012), dreh=(0, 0, -8 - i * 5), knochen='arm.X', beule=0.006)
    f.paar(f.kegel, 'bein_dunkel', (0.07, 0.02, 0.14), 0.02, 0.12, dreh=(180, 0, 0), knochen='leg.X', seg=4)
    for i in range(3):
        f.quader('grabtuch', ((i - 1) * 0.07, 0.38, 0.28), (0.06, 0.22, 0.012), dreh=(10, 0, (i - 1) * 14))     # Schwanzfedern
    return f


def totenrufer():
    """Beschwörer: schwebende Kutte mit Schädelgesicht, Knochenstab mit Seelenlicht und kreisenden Schädeln (1,5)."""
    f = Figur('totenrufer', 35)
    f.zyl('grabtuch', (0, 0, 0.4), 0.3, 0.7, r2=0.14, seg=10, beule=0.015)
    for i in range(9):
        a = i / 9 * math.tau
        f.kegel('grabtuch', (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.03), 0.07, 0.2, dreh=(180, 0, 0), seg=4)
    f.zyl('grabtuch_hell', (0, 0, 0.84), 0.16, 0.34, r2=0.2, seg=8, beule=0.01)
    f.zyl('altgold', (0, 0, 0.7), 0.165, 0.03, seg=8)
    f.zyl('bein_alt', (0, -0.14, 0.86), 0.035, 0.18, seg=6)                                      # Wirbelkette vorn
    f.paar(f.zyl, 'grabtuch', (0.26, -0.04, 0.84), 0.07, 0.36, dreh=(0, -28, 0), knochen='arm.X', r2=0.1, seg=6)
    f.paar(f.kugel, 'knochen', (0.36, -0.12, 0.66), (0.045, 0.045, 0.045), knochen='hand.X')
    f.kugel('knochen', (0, -0.05, 1.12), (0.1, 0.11, 0.1), knochen='head', stufe=2)
    f.quader('knochen', (0, -0.12, 1.04), (0.1, 0.07, 0.04), knochen='head')
    f.paar(f.kugel, 'seele', (0.04, -0.15, 1.13), (0.022, 0.014, 0.024), knochen='head')
    f.kugel('grabtuch', (0, 0.02, 1.15), (0.15, 0.16, 0.14), knochen='head', stufe=2)            # Kapuze
    f.kegel('grabtuch', (0, 0.12, 1.26), 0.09, 0.22, dreh=(-50, 0, 0), knochen='head')
    for s in (1, -1):
        f.kegel('bein_dunkel', (0.1 * s, -0.02, 1.3), 0.025, 0.16, dreh=(0, 22 * s, 0), knochen='head', seg=4)   # Hörnerkrone
    # Stab links mit Schädel und Seelenlicht
    f.zyl('bein_dunkel', (0.38, -0.14, 0.82), 0.022, 1.4, knochen='hand.L', seg=6)
    f.kugel('knochen', (0.38, -0.15, 1.56), (0.07, 0.08, 0.07), knochen='hand.L', stufe=2)
    f.kugel('seele', (0.38, -0.15, 1.7), (0.06, 0.06, 0.08), knochen='hand.L', stufe=2)
    f.paar(f.kegel, 'bein_dunkel', (0.05, -0.15, 1.64), 0.012, 0.12, dreh=(0, 18, 0), knochen='hand.L', seg=4)
    for i in range(3):
        a = i / 3 * math.tau + 0.6
        f.kugel('bein_alt', (math.cos(a) * 0.42, math.sin(a) * 0.42, 0.5 + i * 0.22), (0.05, 0.055, 0.05))
        f.kugel('seele', (math.cos(a) * 0.42, math.sin(a) * 0.42 - 0.04, 0.5 + i * 0.22), (0.02, 0.02, 0.02))
    return f


def knochenritter():
    """Elite: gepanzerter Gruftritter mit Hörnerhelm, zerrissenem Umhang, Turmschild und Zweihänder (2,0)."""
    f = Figur('knochenritter', 36)
    _gerippe(f, 1.0, breit=1.3, farbe='bein_alt', augen='auge_rot')
    f.paar(f.zyl, 'gruft', (0.117, 0, 0.16), 0.045, 0.24, knochen='leg.X', r2=0.035, seg=6)      # Beinschienen
    f.paar(f.quader, 'gruft', (0.117, -0.05, 0.03), (0.08, 0.17, 0.06), knochen='leg.X')
    f.zyl('gruft', (0, 0, 0.68), 0.17, 0.22, r2=0.21, seg=8, beule=0.008)
    f.zyl('altgold', (0, 0, 0.57), 0.175, 0.025, seg=8)
    f.zyl('altgold', (0, 0, 0.79), 0.21, 0.02, seg=8)
    f.zyl('gruft', (0, 0, 0.46), 0.18, 0.14, r2=0.14, seg=8)
    for i in range(5):
        f.quader('gruft', ((i - 2) * 0.07, -0.02, 0.36), (0.06, 0.03, 0.14), dreh=(0, 0, 0), beule=0.004)   # Schurz
    f.paar(f.kugel, 'gruft', (0.26, 0, 0.8), (0.11, 0.11, 0.08), knochen='arm.X', beule=0.008)
    f.paar(f.kegel, 'altgold', (0.3, 0, 0.88), 0.03, 0.14, dreh=(0, -30, 0), knochen='arm.X', seg=4)
    f.paar(f.zyl, 'gruft', (0.247, -0.05, 0.52), 0.035, 0.16, dreh=(30, 0, 0), knochen='hand.X', seg=6)
    # Umhang: drei zerfetzte Bahnen am Rücken
    for i in range(3):
        f.quader('grabtuch' if i != 1 else 'grabtuch_hell', ((i - 1) * 0.13, 0.13, 0.45), (0.13, 0.02, 0.62 - abs(i - 1) * 0.1),
                 dreh=(8, 0, (i - 1) * 6), beule=0.006)
    f.rund('gruft', (0, 0.0, 0.92), (0.1, 0.11, 0.1), knochen='head', seg=8, ringe=5)
    f.quader('schwarz', (0, -0.1, 0.9), (0.14, 0.02, 0.025), knochen='head')
    f.paar(f.kegel, 'bein_dunkel', (0.11, 0.0, 1.0), 0.03, 0.2, dreh=(0, -40, 0), knochen='head', seg=5)
    f.kegel('altgold', (0, 0, 1.05), 0.03, 0.12, knochen='head', seg=4)
    # Turmschild links, Zweihänder rechts
    f.quader('gruft', (0.3, -0.2, 0.5), (0.26, 0.04, 0.5), knochen='hand.L', beule=0.004)
    f.kegel('gruft', (0.3, -0.2, 0.2), 0.13, 0.14, dreh=(180, 0, 0), knochen='hand.L', seg=4)
    f.quader('altgold', (0.3, -0.225, 0.52), (0.03, 0.012, 0.36), knochen='hand.L')
    f.quader('altgold', (0.3, -0.225, 0.58), (0.18, 0.012, 0.03), knochen='hand.L')
    f.quader('eisen', (-0.25, -0.34, 0.74), (0.05, 0.016, 0.9), dreh=(28, 0, 0), knochen='hand.R')
    f.quader('altgold', (-0.25, -0.14, 0.36), (0.2, 0.03, 0.03), dreh=(28, 0, 0), knochen='hand.R')
    f.kegel('eisen', (-0.25, -0.57, 1.17), 0.028, 0.1, dreh=(28, 0, 0), knochen='hand.R', seg=4)
    return f


def vargul():
    """Boss: Gruftfürst. Riesiges gekröntes Gerippe im Königsmantel, Brustkorb mit Seelenfeuer, Sense (3,6)."""
    f = Figur('vargul', 37)
    _gerippe(f, 1.0, breit=1.5, farbe='bein_alt', augen='seele')
    f.kugel('seele', (0, -0.02, 0.67), (0.07, 0.06, 0.08), stufe=2)                              # Seelenfeuer im Brustkorb
    f.zyl('grabtuch', (0, 0.03, 0.3), 0.3, 0.52, r2=0.17, seg=10, beule=0.012)                   # Mantelrock
    for i in range(11):
        a = i / 11 * math.tau
        f.kegel('grabtuch', (math.cos(a) * 0.27, 0.03 + math.sin(a) * 0.27, 0.02), 0.06, 0.16, dreh=(180, 0, 0), seg=4)
    f.zyl('altgold', (0, 0.02, 0.54), 0.18, 0.03, seg=8)
    f.kugel('gruft', (0, -0.17, 0.54), (0.05, 0.03, 0.06))                                       # Schädelschnalle
    for i in range(4):
        f.quader('grabtuch_hell' if i % 2 else 'grabtuch', ((i - 1.5) * 0.12, 0.17, 0.5), (0.12, 0.025, 0.66),
                 dreh=(10, 0, (i - 1.5) * 5), beule=0.008)                                       # Umhang
    f.zyl('grabtuch_hell', (0, 0.02, 0.8), 0.25, 0.08, r2=0.12, seg=10, beule=0.008)             # Pelzkragen
    f.paar(f.kugel, 'gruft', (0.29, 0, 0.81), (0.12, 0.12, 0.08), knochen='arm.X', beule=0.008)
    for k in range(3):
        f.paar(f.kegel, 'bein_dunkel', (0.26 + k * 0.045, 0.0, 0.89), 0.022, 0.12 + k * 0.03, dreh=(0, -15 - k * 12, 0), knochen='arm.X', seg=4)
    f.zyl('altgold', (0, -0.01, 0.985), 0.095, 0.04, knochen='head', seg=8)                      # Krone
    for i in range(7):
        a = i / 7 * math.tau
        f.kegel('altgold', (math.cos(a) * 0.088, -0.01 + math.sin(a) * 0.088, 1.04), 0.02, 0.1, knochen='head', seg=4)
    f.kugel('seele', (0, -0.1, 1.0), (0.022, 0.015, 0.03), knochen='head')
    f.paar(f.kegel, 'bein_dunkel', (0.1, 0.02, 0.96), 0.03, 0.22, dreh=(0, -65, 0), knochen='head', seg=5)   # Hörner
    for i in range(3):
        f.kegel('bein_alt', ((i - 1) * 0.03, -0.1, 0.78), 0.018, 0.1, dreh=(180, 0, 0), knochen='head', seg=4)   # Knochenbart
    # Sense in der rechten Hand, Seelenlaterne links
    f.zyl('bein_dunkel', (-0.29, -0.14, 0.72), 0.018, 1.25, dreh=(10, 0, 0), knochen='hand.R', seg=6)
    f.quader('eisen', (-0.13, -0.26, 1.3), (0.4, 0.02, 0.09), dreh=(10, 18, 0), knochen='hand.R')
    f.kegel('eisen', (0.1, -0.27, 1.22), 0.045, 0.2, dreh=(10, 108, 0), knochen='hand.R', seg=4)
    f.zyl('gruft', (0.29, -0.14, 0.34), 0.05, 0.1, knochen='hand.L', seg=6)
    f.kugel('seele', (0.29, -0.14, 0.34), (0.035, 0.035, 0.045), knochen='hand.L')
    f.zyl('gruft', (0.29, -0.14, 0.42), 0.006, 0.08, knochen='hand.L', seg=4)
    return f

# ---------------------------------------------------------------- Glutbrut (Wellen 21-30)

FARBEN.update({
    'schlacke': (0.10, 0.08, 0.08), 'schlacke_hell': (0.22, 0.16, 0.14), 'glut': (1.00, 0.42, 0.08), 'glut_hell': (1.00, 0.78, 0.25),
    'asche': (0.30, 0.27, 0.26), 'aschtuch': (0.22, 0.10, 0.09), 'kupfer': (0.55, 0.28, 0.14),
    'leere': (0.10, 0.06, 0.22), 'leere_hell': (0.26, 0.17, 0.48), 'riss': (0.72, 0.45, 1.00), 'stern': (0.85, 0.90, 1.00),
    'chitin': (0.05, 0.04, 0.10),
})
GLUT.update({'glut': 3.5, 'glut_hell': 5.0, 'riss': 3.5, 'stern': 4.0})


def _risse(f, mitte, radius, n, knochen='body', farbe='glut'):
    """Glühende Risse: schmale leuchtende Keile rund um einen Körper."""
    for i in range(n):
        a = i / n * math.tau + 0.4
        b = (i * 37 % 100) / 100.0 - 0.5
        f.quader(farbe, (mitte[0] + math.cos(a) * radius[0], mitte[1] + math.sin(a) * radius[1], mitte[2] + b * radius[2] * 1.2),
                 (0.02 * radius[0] / 0.2 + 0.012, 0.012, radius[2] * 0.55), dreh=(b * 50, 0, math.degrees(a) + 90), knochen=knochen)


def glutling():
    """Kleiner Schlackekobold mit Glutkern im Bauch und Flammenschopf (0,8)."""
    f = Figur('glutling', 41)
    f.paar(f.zyl, 'schlacke', (0.11, 0, 0.1), 0.055, 0.2, knochen='leg.X', seg=6)
    f.paar(f.quader, 'schlacke', (0.11, -0.05, 0.03), (0.1, 0.17, 0.06), knochen='leg.X')
    f.kugel('schlacke_hell', (0, 0.0, 0.36), (0.22, 0.2, 0.2), beule=0.025)
    f.kugel('glut', (0, -0.12, 0.34), (0.11, 0.08, 0.1))
    _risse(f, (0, 0, 0.36), (0.2, 0.18, 0.18), 5)
    f.paar(f.zyl, 'schlacke', (0.25, -0.04, 0.32), 0.045, 0.26, dreh=(15, -30, 0), knochen='arm.X', seg=6)
    f.paar(f.kegel, 'glut_hell', (0.3, -0.12, 0.2), 0.035, 0.1, dreh=(140, 0, 0), knochen='hand.X', seg=4)
    f.kugel('schlacke', (0, -0.08, 0.62), (0.2, 0.18, 0.17), knochen='head', beule=0.02)
    f.paar(f.kugel, 'glut_hell', (0.08, -0.23, 0.65), (0.045, 0.025, 0.04), knochen='head')
    f.quader('glut', (0, -0.24, 0.55), (0.16, 0.02, 0.035), knochen='head')
    for i in range(4):
        f.kegel('glut' if i % 2 else 'glut_hell', ((i - 1.5) * 0.07, -0.02, 0.83 + (i % 2) * 0.05), 0.05, 0.2, knochen='head', seg=5, dreh=((i - 1.5) * -6, (i - 1.5) * 10, 0))
    return f


def glutspeier():
    """Schlanker Feuerspucker: aufgeblähter Glutsack am Hals, Rohrmaul, Schlackepanzer (1,2)."""
    f = Figur('glutspeier', 42)
    f.paar(f.zyl, 'schlacke', (0.1, 0, 0.2), 0.045, 0.4, knochen='leg.X', seg=6)
    f.paar(f.quader, 'schlacke_hell', (0.1, -0.06, 0.03), (0.09, 0.2, 0.06), knochen='leg.X')
    f.zyl('schlacke_hell', (0, 0.02, 0.6), 0.15, 0.42, r2=0.18, beule=0.015)
    for i in range(4):
        f.kegel('schlacke', (0, 0.17, 0.48 + i * 0.1), 0.05, 0.16, dreh=(-70, 0, 0), seg=4)               # Rückenstacheln
    _risse(f, (0, 0.02, 0.6), (0.17, 0.17, 0.3), 4)
    f.kugel('glut', (0, -0.12, 0.82), (0.14, 0.13, 0.13), stufe=2)                                         # Glutsack
    f.paar(f.zyl, 'schlacke', (0.2, -0.03, 0.66), 0.035, 0.32, dreh=(10, -12, 0), knochen='arm.X', seg=6)
    f.paar(f.kugel, 'schlacke_hell', (0.24, -0.08, 0.48), (0.05, 0.05, 0.05), knochen='hand.X')
    f.kugel('schlacke', (0, -0.06, 1.0), (0.13, 0.15, 0.12), knochen='head', beule=0.015)
    f.zyl('kupfer', (0, -0.24, 0.98), 0.06, 0.2, dreh=(90, 0, 0), knochen='head', seg=8, r2=0.08)          # Rohrmaul
    f.zyl('glut_hell', (0, -0.345, 0.98), 0.055, 0.02, dreh=(90, 0, 0), knochen='head', seg=8)
    f.paar(f.kugel, 'glut_hell', (0.07, -0.16, 1.06), (0.03, 0.02, 0.03), knochen='head')
    f.paar(f.kegel, 'schlacke_hell', (0.09, 0.02, 1.12), 0.03, 0.14, dreh=(0, -25, 0), knochen='head', seg=4)
    return f


def lavawalze():
    """Rollender Lavabrocken: runder Schlackekörper mit glühenden Nähten, kurze Stummelarme, breites Maul (1,4)."""
    f = Figur('lavawalze', 43)
    f.kugel('schlacke', (0, 0, 0.5), (0.5, 0.5, 0.48), beule=0.04, stufe=2)
    _risse(f, (0, 0, 0.5), (0.5, 0.5, 0.42), 9)
    for i in range(7):
        a = i / 7 * math.tau
        f.kugel('schlacke_hell', (math.cos(a) * 0.4, math.sin(a) * 0.4 + 0.05, 0.72 + (i % 2) * 0.08), (0.16, 0.16, 0.12), beule=0.02)
    f.kugel('glut', (0, 0, 0.92), (0.2, 0.2, 0.08))                                                         # Lavasee oben
    f.paar(f.kugel, 'schlacke_hell', (0.5, -0.1, 0.42), (0.14, 0.16, 0.13), knochen='arm.X', beule=0.02)
    f.paar(f.kugel, 'schlacke', (0.56, -0.26, 0.3), (0.12, 0.12, 0.11), knochen='hand.X', beule=0.02)
    f.paar(f.kugel, 'schlacke', (0.24, 0.02, 0.1), (0.16, 0.2, 0.1), knochen='leg.X', beule=0.02)
    f.quader('glut_hell', (0, -0.47, 0.42), (0.34, 0.06, 0.1), knochen='head')
    for i in range(5):
        f.kegel('schlacke', ((i - 2) * 0.07, -0.5, 0.47), 0.025, 0.07, dreh=(180, 0, 0), knochen='head', seg=4)
    f.paar(f.kugel, 'glut_hell', (0.16, -0.44, 0.66), (0.06, 0.04, 0.05), knochen='head')
    f.paar(f.quader, 'schlacke', (0.16, -0.46, 0.73), (0.16, 0.06, 0.04), dreh=(0, 18, 0), knochen='head')
    return f


def glutfalter():
    """Flieger: Aschemotte mit glimmenden Flügeln und Glutleib (0,5)."""
    # Flügel/Hände starr am Arm (2026-11-17): eigener Handknochen drehte sie sonst vom Arm weg.
    f = Figur('glutfalter', 44)
    f.kugel('schlacke', (0, 0.0, 0.3), (0.09, 0.16, 0.09))
    f.kugel('glut', (0, 0.2, 0.28), (0.08, 0.2, 0.08), stufe=2)
    for i in range(3):
        f.zyl('schlacke', (0, 0.1 + i * 0.1, 0.28), 0.085 - i * 0.012, 0.02, dreh=(90, 0, 0), seg=6)
    f.kugel('schlacke_hell', (0, -0.18, 0.32), (0.08, 0.08, 0.075), knochen='head')
    f.paar(f.kugel, 'glut_hell', (0.05, -0.24, 0.34), (0.03, 0.025, 0.03), knochen='head')
    f.paar(f.zyl, 'schlacke_hell', (0.06, -0.3, 0.42), 0.006, 0.22, dreh=(50, -20, 0), knochen='head', seg=3)
    for k, (y, lang, breit) in enumerate(((-0.06, 0.52, 0.34), (0.18, 0.4, 0.28))):
        f.paar(f.quader, 'aschtuch', (0.3, y, 0.33), (lang, breit, 0.012), dreh=(0, -8, -12 + k * 26), knochen='arm.X', beule=0.006)
        f.paar(f.quader, 'glut', (0.42, y, 0.345), (lang * 0.45, breit * 0.5, 0.01), dreh=(0, -8, -12 + k * 26), knochen='arm.X')
        f.paar(f.kugel, 'glut_hell', (0.5, y, 0.36), (0.045, 0.045, 0.01), knochen='arm.X')
    return f


def aschenpriester():
    """Zauberer in verkohlter Kutte mit Schlackemaske, Räucherfass und Glutstab (1,5)."""
    f = Figur('aschenpriester', 45)
    f.zyl('aschtuch', (0, 0, 0.38), 0.28, 0.72, r2=0.14, seg=10, beule=0.012)
    for i in range(9):
        a = i / 9 * math.tau
        f.kegel('schlacke', (math.cos(a) * 0.25, math.sin(a) * 0.25, 0.03), 0.06, 0.16, dreh=(180, 0, 0), seg=4)
        f.kugel('glut', (math.cos(a) * 0.27, math.sin(a) * 0.27, 0.1), (0.02, 0.02, 0.03))               # glimmender Saum
    f.zyl('aschtuch', (0, 0, 0.86), 0.15, 0.34, r2=0.2, seg=8)
    f.quader('kupfer', (0, -0.16, 0.82), (0.07, 0.02, 0.4))                                                 # Stola
    f.kugel('glut', (0, -0.175, 0.92), (0.035, 0.015, 0.035))
    f.paar(f.zyl, 'aschtuch', (0.25, -0.04, 0.86), 0.065, 0.36, dreh=(0, -26, 0), knochen='arm.X', r2=0.1, seg=6)
    f.paar(f.kugel, 'schlacke', (0.35, -0.12, 0.68), (0.045, 0.045, 0.045), knochen='hand.X')
    f.kugel('schlacke', (0, -0.04, 1.13), (0.11, 0.12, 0.12), knochen='head', stufe=2)
    f.quader('schlacke_hell', (0, -0.14, 1.12), (0.14, 0.03, 0.2), knochen='head')                         # Maske
    f.paar(f.quader, 'glut_hell', (0.035, -0.158, 1.16), (0.03, 0.012, 0.05), knochen='head')
    f.kugel('aschtuch', (0, 0.03, 1.16), (0.16, 0.17, 0.15), knochen='head', stufe=2)
    f.kegel('aschtuch', (0, 0.06, 1.34), 0.1, 0.3, dreh=(-20, 0, 0), knochen='head')                       # spitze Kapuze
    f.zyl('schlacke', (0.37, -0.14, 0.86), 0.022, 1.45, knochen='hand.L', seg=6)                           # Stab
    f.kugel('glut_hell', (0.37, -0.14, 1.66), (0.08, 0.08, 0.1), knochen='hand.L', stufe=2)
    for i in range(3):
        a = i / 3 * math.tau
        f.kegel('schlacke', (0.37 + math.cos(a) * 0.08, -0.14 + math.sin(a) * 0.08, 1.62), 0.02, 0.22, knochen='hand.L', seg=4)
    f.zyl('eisen', (-0.36, -0.14, 0.6), 0.004, 0.2, knochen='hand.R', seg=3)                               # Räucherfass an Kette
    f.kugel('kupfer', (-0.36, -0.14, 0.46), (0.07, 0.07, 0.08), knochen='hand.R')
    f.kugel('glut', (-0.36, -0.14, 0.52), (0.035, 0.035, 0.03), knochen='hand.R')
    return f


def schmelzhauer():
    """Elite: Schlackeriese mit Ambossschultern, glühendem Brustofen und Schmiedehammer (1,9)."""
    f = Figur('schmelzhauer', 46)
    f.paar(f.zyl, 'schlacke', (0.2, 0, 0.28), 0.12, 0.56, knochen='leg.X', r2=0.14, seg=8, beule=0.012)
    f.paar(f.quader, 'schlacke_hell', (0.2, -0.06, 0.06), (0.22, 0.32, 0.12), knochen='leg.X')
    f.zyl('schlacke_hell', (0, 0, 0.72), 0.3, 0.32, r2=0.28, seg=8, beule=0.015)
    f.zyl('schlacke', (0, 0, 1.12), 0.32, 0.52, r2=0.46, seg=8, beule=0.02)
    f.quader('kupfer', (0, -0.36, 1.1), (0.3, 0.06, 0.3))                                                   # Ofentür
    f.quader('glut_hell', (0, -0.395, 1.1), (0.22, 0.02, 0.2))
    for i in range(3):
        f.quader('schlacke', ((i - 1) * 0.07, -0.41, 1.1), (0.022, 0.02, 0.22))                             # Gitter
    _risse(f, (0, 0, 1.1), (0.42, 0.42, 0.4), 6)
    f.paar(f.quader, 'schlacke_hell', (0.52, 0, 1.4), (0.36, 0.3, 0.2), knochen='arm.X', beule=0.012)       # Ambossschultern
    f.paar(f.kegel, 'kupfer', (0.62, 0.0, 1.56), 0.06, 0.2, dreh=(0, -20, 0), knochen='arm.X', seg=4)
    f.paar(f.zyl, 'schlacke', (0.56, -0.04, 1.02), 0.1, 0.46, dreh=(0, -8, 0), knochen='arm.X', seg=8)
    f.paar(f.kugel, 'schlacke_hell', (0.6, -0.08, 0.72), (0.13, 0.13, 0.13), knochen='hand.X', beule=0.015)
    f.kugel('schlacke', (0, -0.08, 1.56), (0.17, 0.18, 0.16), knochen='head', beule=0.015)
    f.quader('glut_hell', (0, -0.25, 1.58), (0.2, 0.03, 0.045), knochen='head')                             # Sehschlitz
    f.paar(f.kegel, 'schlacke_hell', (0.15, 0.0, 1.72), 0.05, 0.26, dreh=(0, -35, 0), knochen='head', seg=5)
    f.zyl('kupfer', (0, 0.1, 1.72), 0.05, 0.2, knochen='head', seg=6)                                       # Schlot
    f.kugel('asche', (0, 0.1, 1.88), (0.08, 0.08, 0.07), knochen='head', beule=0.02)
    f.zyl('eisen', (-0.6, -0.22, 1.02), 0.035, 1.3, dreh=(20, 0, 0), knochen='hand.R', seg=6)               # Hammer
    f.quader('schlacke', (-0.6, -0.44, 1.62), (0.26, 0.42, 0.26), dreh=(20, 0, 0), knochen='hand.R', beule=0.008)
    f.quader('glut', (-0.6, -0.64, 1.55), (0.2, 0.03, 0.2), dreh=(20, 0, 0), knochen='hand.R')
    return f


def ignar():
    """Boss: Herz der Glut. Titan aus Schlackeplatten um ein offenes, loderndes Herz, Flammenkrone, Lavafäuste (3,6)."""
    f = Figur('ignar', 47)
    f.paar(f.zyl, 'schlacke', (0.24, 0.02, 0.24), 0.14, 0.48, knochen='leg.X', r2=0.18, seg=8, beule=0.015)
    f.paar(f.kugel, 'schlacke_hell', (0.24, -0.05, 0.06), (0.2, 0.26, 0.08), knochen='leg.X', beule=0.02)
    f.paar(f.quader, 'glut', (0.24, -0.15, 0.3), (0.05, 0.02, 0.3), knochen='leg.X')
    f.zyl('schlacke_hell', (0, 0, 0.6), 0.3, 0.26, r2=0.26, seg=8, beule=0.015)
    f.kugel('schlacke', (0, 0.06, 0.98), (0.5, 0.42, 0.42), beule=0.03, stufe=2)
    f.kugel('glut_hell', (0, -0.22, 0.98), (0.2, 0.16, 0.22), stufe=2)                                      # das Herz
    for i in range(6):
        a = (i / 5 - 0.5) * 2.4
        f.quader('schlacke_hell', (math.sin(a) * 0.3, -0.34 - abs(math.cos(a)) * 0.03, 0.98 + math.cos(a * 1.3) * 0.02),
                 (0.05, 0.05, 0.5), dreh=(0, 0, 0), beule=0.006)                                            # Rippenplatten vor dem Herz
    _risse(f, (0, 0.06, 0.98), (0.5, 0.42, 0.4), 9)
    for i in range(7):
        a = (i / 6 - 0.5) * 2.2
        f.kegel('schlacke_hell', (math.sin(a) * 0.42, 0.34, 1.2 + math.cos(a) * 0.14), 0.07, 0.3, dreh=(-50, a * 30, 0), seg=4)   # Rückenkamm
    f.paar(f.kugel, 'schlacke_hell', (0.56, 0, 1.24), (0.24, 0.24, 0.2), knochen='arm.X', beule=0.03)
    for k in range(3):
        f.paar(f.kegel, 'schlacke', (0.5 + k * 0.08, 0.0, 1.42), 0.05, 0.2 + k * 0.05, dreh=(0, -10 - k * 14, 0), knochen='arm.X', seg=4)
    f.paar(f.zyl, 'schlacke', (0.64, -0.04, 0.84), 0.13, 0.56, dreh=(4, -8, 0), knochen='arm.X', seg=8, beule=0.012)
    f.paar(f.kugel, 'glut', (0.68, -0.1, 0.5), (0.2, 0.2, 0.19), knochen='hand.X', beule=0.02, stufe=2)     # Lavafäuste
    f.paar(f.kugel, 'schlacke', (0.68, -0.06, 0.56), (0.17, 0.17, 0.12), knochen='hand.X', beule=0.02)
    f.kugel('schlacke', (0, -0.16, 1.42), (0.17, 0.17, 0.16), knochen='head', beule=0.015)
    f.kugel('schlacke_hell', (0, -0.28, 1.34), (0.13, 0.08, 0.07), knochen='head')
    f.paar(f.kugel, 'glut_hell', (0.07, -0.31, 1.45), (0.04, 0.025, 0.03), knochen='head')
    f.quader('glut', (0, -0.345, 1.34), (0.16, 0.02, 0.03), knochen='head')
    for i in range(7):
        a = i / 7 * math.tau
        f.kegel('glut' if i % 2 else 'glut_hell', (math.cos(a) * 0.12, -0.14 + math.sin(a) * 0.12, 1.66 + (i % 2) * 0.04), 0.045, 0.28, knochen='head', seg=5)
    f.paar(f.kegel, 'schlacke_hell', (0.2, -0.12, 1.5), 0.05, 0.32, dreh=(0, -60, 0), knochen='head', seg=5)
    return f


# ---------------------------------------------------------------- Leere (Wellen 31-40)

def _auge(f, ort, r, knochen='head'):
    f.kugel('stern', ort, (r, r * 0.6, r), knochen=knochen, stufe=2)
    f.kugel('riss', (ort[0], ort[1] - r * 0.45, ort[2]), (r * 0.6, r * 0.3, r * 0.6), knochen=knochen, stufe=2)
    f.quader('schwarz', (ort[0], ort[1] - r * 0.7, ort[2]), (r * 0.16, r * 0.1, r * 0.8), knochen=knochen)


def leerling():
    """Kleiner Leerenkriecher: geduckter Schattenleib, ein großes Auge, Klauenarme (0,9)."""
    f = Figur('leerling', 51)
    f.paar(f.zyl, 'chitin', (0.12, 0.02, 0.12), 0.04, 0.26, dreh=(0, 18, 0), knochen='leg.X', seg=5)
    f.paar(f.kegel, 'chitin', (0.16, -0.04, 0.03), 0.04, 0.12, dreh=(100, 0, 0), knochen='leg.X', seg=4)
    f.kugel('leere', (0, 0.04, 0.36), (0.2, 0.24, 0.18), beule=0.02)
    for i in range(4):
        f.kegel('leere_hell', (0, 0.1 + i * 0.06, 0.5 - i * 0.02), 0.04, 0.16, dreh=(-40 - i * 10, 0, 0), seg=4)
    f.paar(f.zyl, 'chitin', (0.24, -0.08, 0.36), 0.035, 0.3, dreh=(30, -40, 0), knochen='arm.X', seg=5)
    f.paar(f.kegel, 'riss', (0.32, -0.26, 0.26), 0.03, 0.18, dreh=(120, 0, 0), knochen='hand.X', seg=4)
    f.kugel('leere', (0, -0.16, 0.56), (0.19, 0.17, 0.17), knochen='head', beule=0.015)
    _auge(f, (0, -0.31, 0.58), 0.09)
    f.paar(f.kegel, 'leere_hell', (0.14, -0.1, 0.72), 0.035, 0.2, dreh=(0, -35, 0), knochen='head', seg=4)
    return f


def leerenseher():
    """Fernkämpfer: schwebender schmaler Leib mit drei Augen und Tentakelsaum (1,4)."""
    # Flügel/Hände starr am Arm (2026-11-17): eigener Handknochen drehte sie sonst vom Arm weg.
    f = Figur('leerenseher', 52)
    f.zyl('leere', (0, 0, 0.62), 0.12, 0.6, r2=0.18, seg=8, beule=0.012)
    for i in range(7):
        a = i / 7 * math.tau
        f.zyl('leere_hell', (math.cos(a) * 0.09, math.sin(a) * 0.09, 0.18), 0.025, 0.36, dreh=(math.sin(a) * 14, -math.cos(a) * 14, 0), seg=4, r2=0.008)
    f.zyl('chitin', (0, 0, 0.9), 0.2, 0.08, r2=0.14, seg=8)
    f.paar(f.zyl, 'leere_hell', (0.24, -0.06, 0.74), 0.03, 0.4, dreh=(20, -22, 0), knochen='arm.X', seg=5)
    f.paar(f.kugel, 'riss', (0.33, -0.18, 0.56), (0.05, 0.05, 0.05), knochen='arm.X', stufe=2)
    f.kugel('leere', (0, -0.04, 1.14), (0.17, 0.17, 0.2), knochen='head', beule=0.012, stufe=2)
    _auge(f, (0, -0.19, 1.16), 0.075)
    _auge(f, (0.11, -0.15, 1.27), 0.04)
    _auge(f, (-0.11, -0.15, 1.27), 0.04)
    for i in range(5):
        f.kegel('chitin', ((i - 2) * 0.07, 0.02, 1.34 + (2 - abs(i - 2)) * 0.03), 0.03, 0.2, dreh=(0, (i - 2) * 14, 0), knochen='head', seg=4)
    return f


def nichtswandler():
    """Schwerer Leerenläufer: massiger Chitinpanzer mit Riss in der Brust, lange Sichelarme (1,8)."""
    f = Figur('nichtswandler', 53)
    f.paar(f.zyl, 'chitin', (0.2, 0, 0.26), 0.09, 0.52, knochen='leg.X', r2=0.12, seg=6)
    f.paar(f.kegel, 'chitin', (0.2, -0.1, 0.05), 0.09, 0.26, dreh=(95, 0, 0), knochen='leg.X', seg=4)
    f.kugel('leere', (0, 0.06, 0.92), (0.4, 0.36, 0.42), beule=0.025, stufe=2)
    for i in range(4):
        f.quader('chitin', (0, 0.28 - i * 0.02, 0.7 + i * 0.16), (0.56 - i * 0.06, 0.2, 0.12), dreh=(-20, 0, 0), beule=0.008)    # Rückenplatten
    f.quader('riss', (0, -0.3, 0.92), (0.05, 0.03, 0.4), dreh=(0, 8, 0))                                    # Riss in der Brust
    f.quader('stern', (0, -0.315, 0.94), (0.02, 0.02, 0.26), dreh=(0, 8, 0))
    f.paar(f.kugel, 'chitin', (0.44, 0, 1.2), (0.18, 0.18, 0.15), knochen='arm.X', beule=0.012)
    f.paar(f.zyl, 'leere_hell', (0.5, -0.06, 0.9), 0.07, 0.5, dreh=(10, -10, 0), knochen='arm.X', seg=6)
    # Sicheln hängen direkt an der Hand und krümmen sich nach vorn (vorher schwebten sie neben dem Arm).
    f.paar(f.kugel, 'chitin', (0.55, -0.08, 0.64), (0.08, 0.08, 0.08), knochen='hand.X')
    f.paar(f.quader, 'chitin', (0.55, -0.1, 0.44), (0.05, 0.12, 0.4), dreh=(12, 0, 0), knochen='hand.X')
    f.paar(f.quader, 'chitin', (0.55, -0.24, 0.26), (0.05, 0.3, 0.09), dreh=(-25, 0, 0), knochen='hand.X')
    f.paar(f.kegel, 'riss', (0.55, -0.42, 0.33), 0.03, 0.14, dreh=(-60, 0, 0), knochen='hand.X', seg=4)
    f.kugel('leere', (0, -0.2, 1.36), (0.16, 0.17, 0.14), knochen='head', beule=0.012)
    _auge(f, (0.07, -0.33, 1.38), 0.04)
    _auge(f, (-0.07, -0.33, 1.38), 0.04)
    f.paar(f.kegel, 'chitin', (0.1, -0.34, 1.26), 0.03, 0.14, dreh=(160, 0, 0), knochen='head', seg=4)      # Mandibeln
    return f


def leerenschwinge():
    """Flieger: Leerenrochen mit breiten Flossenflügeln, Stachelschwanz und Sternenaugen (0,5)."""
    # Flügel/Hände starr am Arm (2026-11-17): eigener Handknochen drehte sie sonst vom Arm weg.
    f = Figur('leerenschwinge', 54)
    f.kugel('leere', (0, 0.02, 0.3), (0.16, 0.3, 0.07), stufe=2)
    f.kugel('leere_hell', (0, -0.02, 0.27), (0.1, 0.2, 0.04))
    f.kugel('leere', (0, -0.28, 0.31), (0.1, 0.1, 0.06), knochen='head')
    _auge(f, (0.05, -0.36, 0.33), 0.03)
    _auge(f, (-0.05, -0.36, 0.33), 0.03)
    f.paar(f.kegel, 'chitin', (0.07, -0.4, 0.28), 0.02, 0.14, dreh=(95, 0, 12), knochen='head', seg=4)
    for i in range(3):
        f.paar(f.quader, 'leere' if i % 2 == 0 else 'leere_hell', (0.24 + i * 0.2, 0.02 + i * 0.05, 0.3),
               (0.22, 0.44 - i * 0.11, 0.014), dreh=(0, -6, -10 - i * 8), knochen='arm.X', beule=0.005)
    f.paar(f.kegel, 'riss', (0.78, 0.14, 0.31), 0.03, 0.16, dreh=(0, -90, 0), knochen='arm.X', seg=4)
    f.zyl('leere_hell', (0, 0.44, 0.3), 0.025, 0.4, dreh=(90, 0, 0), seg=5, r2=0.01)                        # Schwanz
    f.kegel('riss', (0, 0.7, 0.3), 0.035, 0.16, dreh=(-90, 0, 0), seg=4)
    return f


def riftrufer():
    """Beschwörer: schwebende Leerenpriesterin, hält einen aufgerissenen Riss zwischen den Händen (1,5)."""
    f = Figur('riftrufer', 55)
    f.zyl('leere', (0, 0, 0.42), 0.26, 0.7, r2=0.12, seg=10, beule=0.012)
    for i in range(8):
        a = i / 8 * math.tau
        f.kegel('leere_hell', (math.cos(a) * 0.22, math.sin(a) * 0.22, 0.06), 0.06, 0.24, dreh=(180, 0, 0), seg=4)
    f.zyl('leere_hell', (0, 0, 0.88), 0.14, 0.3, r2=0.2, seg=8)
    f.zyl('chitin', (0, 0, 1.02), 0.26, 0.05, r2=0.16, seg=6)                                               # Kragenplatte
    f.paar(f.zyl, 'leere', (0.24, -0.1, 0.9), 0.035, 0.36, dreh=(55, -18, 0), knochen='arm.X', seg=5)
    f.paar(f.kugel, 'chitin', (0.2, -0.3, 0.8), (0.04, 0.04, 0.04), knochen='hand.X')
    f.quader('riss', (0, -0.34, 0.8), (0.05, 0.03, 0.42), dreh=(0, 12, 0))                                  # der Riss
    f.quader('stern', (0, -0.35, 0.8), (0.02, 0.02, 0.3), dreh=(0, 12, 0))
    for i in range(4):
        f.kugel('riss', (math.cos(i * 1.7) * 0.1, -0.34, 0.66 + i * 0.1), (0.018, 0.018, 0.018))
    f.kugel('leere', (0, -0.03, 1.18), (0.12, 0.13, 0.14), knochen='head', stufe=2)
    _auge(f, (0, -0.14, 1.2), 0.05)
    f.zyl('chitin', (0, -0.02, 1.34), 0.14, 0.03, knochen='head', seg=6)                                    # Reif
    for i in range(6):
        a = i / 6 * math.tau
        f.kegel('riss' if i % 2 else 'chitin', (math.cos(a) * 0.14, -0.02 + math.sin(a) * 0.14, 1.44), 0.022, 0.18, knochen='head', seg=4)
    return f


def leerenhueter():
    """Elite: gepanzerter Hüter mit Sternenschild, Hörnerhelm und Rissklinge (2,1)."""
    f = Figur('leerenhueter', 56)
    f.paar(f.zyl, 'chitin', (0.2, 0, 0.3), 0.11, 0.6, knochen='leg.X', r2=0.13, seg=6)
    f.paar(f.quader, 'chitin', (0.2, -0.06, 0.06), (0.2, 0.3, 0.12), knochen='leg.X')
    f.zyl('leere', (0, 0, 0.74), 0.3, 0.3, r2=0.26, seg=8)
    f.zyl('chitin', (0, 0, 1.14), 0.3, 0.52, r2=0.44, seg=8, beule=0.012)
    f.quader('riss', (0, -0.37, 1.16), (0.04, 0.03, 0.34))
    f.paar(f.quader, 'riss', (0.12, -0.36, 1.22), (0.16, 0.03, 0.035), dreh=(0, 30, 0))
    f.paar(f.kugel, 'chitin', (0.5, 0, 1.4), (0.24, 0.24, 0.18), knochen='arm.X', beule=0.012)
    f.paar(f.kegel, 'leere_hell', (0.6, 0.0, 1.56), 0.06, 0.3, dreh=(0, -30, 0), knochen='arm.X', seg=4)
    f.paar(f.zyl, 'leere', (0.54, -0.04, 1.04), 0.09, 0.46, dreh=(0, -8, 0), knochen='arm.X', seg=6)
    f.rund('chitin', (0, -0.02, 1.62), (0.19, 0.2, 0.2), knochen='head', seg=8, ringe=5)
    f.quader('riss', (0, -0.2, 1.62), (0.05, 0.03, 0.2), knochen='head')
    f.quader('riss', (0, -0.2, 1.66), (0.22, 0.03, 0.04), knochen='head')
    f.paar(f.kegel, 'leere_hell', (0.2, 0.0, 1.8), 0.05, 0.4, dreh=(0, -25, 0), knochen='head', seg=5)
    f.zyl('chitin', (0.62, -0.34, 0.96), 0.42, 0.05, dreh=(90, 0, 10), knochen='hand.L', seg=6)             # Schild
    f.zyl('leere_hell', (0.62, -0.37, 0.96), 0.3, 0.03, dreh=(90, 0, 10), knochen='hand.L', seg=6)
    f.kugel('stern', (0.625, -0.39, 0.96), (0.08, 0.04, 0.08), knochen='hand.L', stufe=2)
    f.quader('riss', (-0.58, -0.36, 1.2), (0.07, 0.03, 1.3), dreh=(25, 0, 0), knochen='hand.R')             # Rissklinge
    f.quader('stern', (-0.58, -0.37, 1.22), (0.025, 0.02, 1.1), dreh=(25, 0, 0), knochen='hand.R')
    f.quader('chitin', (-0.58, -0.1, 0.64), (0.26, 0.04, 0.05), dreh=(25, 0, 0), knochen='hand.R')
    return f


def verschlinger():
    """Endboss alter Art: Der Verschlinger. Berg aus Leerenfleisch mit senkrechtem Schlund, Augenkranz, Tentakelarmen (4,6)."""
    f = Figur('verschlinger', 57)
    f.kugel('leere', (0, 0.1, 0.62), (0.62, 0.56, 0.6), beule=0.04, stufe=2)
    for i in range(10):
        a = i / 10 * math.tau
        f.zyl('leere_hell', (math.cos(a) * 0.5, 0.1 + math.sin(a) * 0.46, 0.14), 0.09, 0.36, dreh=(math.sin(a) * 30, -math.cos(a) * 30, 0),
              seg=5, r2=0.03, knochen='leg.L' if math.cos(a) > 0 else 'leg.R')                             # Kriechtentakel
    f.kugel('chitin', (0, 0.3, 1.0), (0.5, 0.36, 0.3), beule=0.03, stufe=2)
    for i in range(7):
        a = (i / 6 - 0.5) * 2.4
        f.kegel('chitin', (math.sin(a) * 0.4, 0.42, 1.14 + math.cos(a) * 0.12), 0.07, 0.4, dreh=(-45, a * 30, 0), seg=4)
    # Schlund: senkrechter Spalt mit Zahnreihen und leuchtendem Inneren
    f.kugel('schwarz', (0, -0.36, 0.66), (0.2, 0.14, 0.42), stufe=2)
    f.kugel('riss', (0, -0.3, 0.66), (0.12, 0.1, 0.3), stufe=2)
    for i in range(8):
        z = 0.34 + i * 0.09
        for s in (1, -1):
            f.kegel('zahn', (0.15 * s * (1.0 - abs(i - 3.5) / 6.0), -0.47, z), 0.03, 0.14, dreh=(0, 90 * s, 0), seg=4)
    f.paar(f.kugel, 'leere_hell', (0.66, -0.06, 0.86), (0.2, 0.2, 0.18), knochen='arm.X', beule=0.02)
    f.paar(f.zyl, 'leere', (0.82, -0.2, 0.62), 0.11, 0.6, dreh=(25, -22, 0), knochen='arm.X', seg=6, r2=0.07)
    f.paar(f.kugel, 'leere', (0.88, -0.3, 0.4), (0.1, 0.1, 0.1), knochen='arm.X')
    f.paar(f.zyl, 'leere_hell', (0.9, -0.52, 0.34), 0.085, 0.5, dreh=(75, -6, 0), knochen='hand.X', seg=6, r2=0.035)
    f.paar(f.kegel, 'riss', (0.92, -0.84, 0.28), 0.05, 0.22, dreh=(95, 0, 0), knochen='hand.X', seg=4)
    f.kugel('leere', (0, -0.1, 1.22), (0.3, 0.3, 0.22), knochen='head', beule=0.02, stufe=2)
    _auge(f, (0, -0.37, 1.24), 0.1)
    for i in range(6):
        a = (i / 5 - 0.5) * 2.6
        _auge(f, (math.sin(a) * 0.26, -0.3 + abs(math.sin(a)) * 0.12, 1.24 + math.cos(a) * 0.14 - 0.04), 0.04)
    for i in range(5):
        a = (i / 4 - 0.5) * 1.8
        f.kegel('chitin', (math.sin(a) * 0.22, -0.06, 1.46 + math.cos(a) * 0.06), 0.05, 0.36, dreh=(0, math.degrees(a) * 0.6, 0), knochen='head', seg=5)
    return f

# ---------------------------------------------------------------- Sonderzonen und Ereignisse

FARBEN.update({
    'arena_rot': (0.55, 0.12, 0.22), 'geist': (0.45, 0.85, 0.62), 'geist_hell': (0.75, 1.00, 0.85), 'rinde': (0.26, 0.19, 0.12),
    'laub': (0.20, 0.38, 0.18), 'uebung': (0.72, 0.72, 0.85), 'stroh': (0.70, 0.58, 0.30), 'tuch_braun': (0.36, 0.25, 0.14),
    'wache': (0.26, 0.27, 0.33),
})
GLUT.update({'geist_hell': 2.5})


def arenawaechter():
    """Elite der Arena: Gladiator mit Federbuschhelm, Netz-Schulterpanzer, Dreizack und Rundschild (2,2)."""
    f = Figur('arenawaechter', 61)
    f.paar(f.zyl, 'haut', (0.2, 0, 0.3), 0.1, 0.6, knochen='leg.X', r2=0.13, seg=6)
    f.paar(f.zyl, 'gold', (0.2, 0, 0.18), 0.115, 0.3, knochen='leg.X', seg=6)                               # Beinschienen
    f.paar(f.quader, 'leder', (0.2, -0.06, 0.05), (0.18, 0.3, 0.1), knochen='leg.X')
    f.zyl('arena_rot', (0, 0, 0.66), 0.32, 0.3, r2=0.24, seg=8, beule=0.01)                                 # Rock
    for i in range(6):
        f.quader('leder', (math.sin((i / 5 - 0.5) * 2.2) * 0.3, -0.2 - math.cos((i / 5 - 0.5) * 2.2) * 0.08, 0.6), (0.08, 0.03, 0.3))
    f.zyl('gold', (0, 0, 0.84), 0.28, 0.08, seg=8)
    f.zyl('haut', (0, 0, 1.14), 0.28, 0.5, r2=0.4, seg=8, beule=0.01)
    f.quader('leder', (0, -0.3, 1.2), (0.6, 0.04, 0.09), dreh=(0, 35, 0))
    f.kugel('gold', (0.48, 0, 1.4), (0.26, 0.24, 0.2), knochen='arm.L', beule=0.01)                         # ein Schulterpanzer
    f.quader('gold', (0.56, 0, 1.56), (0.05, 0.3, 0.22), knochen='arm.L')
    f.paar(f.zyl, 'haut', (0.52, -0.04, 1.02), 0.09, 0.46, dreh=(0, -8, 0), knochen='arm.X', seg=6)
    f.paar(f.zyl, 'leder', (0.54, -0.06, 0.84), 0.1, 0.16, knochen='hand.X', seg=6)
    f.kugel('haut', (0, -0.04, 1.58), (0.16, 0.17, 0.17), knochen='head')
    f.rund('gold', (0, 0.0, 1.64), (0.2, 0.21, 0.18), knochen='head', seg=8, ringe=5)
    f.quader('gold', (0, -0.19, 1.56), (0.3, 0.05, 0.16), knochen='head')                                   # Visier
    for i in range(4):
        f.quader('schwarz', ((i - 1.5) * 0.06, -0.22, 1.57), (0.025, 0.02, 0.1), knochen='head')
    for i in range(6):
        f.quader('arena_rot', (0, 0.16 - i * 0.07, 1.86 - abs(i - 2) * 0.03), (0.05, 0.08, 0.22), knochen='head', dreh=(-10 + i * 8, 0, 0))   # Federbusch
    f.zyl('holz', (-0.56, -0.2, 1.1), 0.03, 2.1, dreh=(12, 0, 0), knochen='hand.R', seg=6)                  # Dreizack
    for x in (-0.14, 0.0, 0.14):
        f.kegel('eisen', (-0.56 + x, -0.44, 2.2 + (0.06 if x == 0 else 0)), 0.035, 0.34, dreh=(12, 0, 0), knochen='hand.R', seg=4)
    f.quader('eisen', (-0.56, -0.4, 2.02), (0.34, 0.04, 0.05), dreh=(12, 0, 0), knochen='hand.R')
    f.zyl('arena_rot', (0.6, -0.3, 0.94), 0.36, 0.05, dreh=(90, 0, 8), knochen='hand.L', seg=10)
    f.zyl('gold', (0.6, -0.33, 0.94), 0.4, 0.02, dreh=(90, 0, 8), knochen='hand.L', seg=10)
    f.kegel('gold', (0.605, -0.4, 0.94), 0.09, 0.14, dreh=(90, 0, 8), knochen='hand.L', seg=6)
    return f


def haingeist():
    """Waldgeist des Holzhains: schwebender Rindenleib mit Laubkrone, Astarmen und leuchtendem Kern (1,2)."""
    # Flügel/Hände starr am Arm (2026-11-17): eigener Handknochen drehte sie sonst vom Arm weg.
    f = Figur('haingeist', 62)
    f.zyl('rinde', (0, 0, 0.5), 0.16, 0.6, r2=0.08, seg=7, beule=0.015)
    for i in range(5):
        a = i / 5 * math.tau
        f.zyl('rinde', (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.14), 0.03, 0.3, dreh=(math.sin(a) * 20, -math.cos(a) * 20, 0), seg=4, r2=0.008)   # Wurzeln
    f.kugel('geist_hell', (0, -0.12, 0.62), (0.07, 0.05, 0.1), stufe=2)                                     # Kern
    f.quader('rinde', (0.07, -0.14, 0.62), (0.03, 0.04, 0.22))
    f.quader('rinde', (-0.07, -0.14, 0.62), (0.03, 0.04, 0.22))
    f.paar(f.zyl, 'rinde', (0.24, -0.04, 0.66), 0.03, 0.4, dreh=(10, -40, 0), knochen='arm.X', seg=5)
    for k in range(3):
        f.paar(f.kegel, 'rinde', (0.36, -0.08 - k * 0.05, 0.46 + k * 0.02), 0.015, 0.16, dreh=(150, 0, (k - 1) * 20), knochen='arm.X', seg=3)
    f.kugel('rinde', (0, -0.03, 0.92), (0.14, 0.14, 0.13), knochen='head', beule=0.015)
    f.paar(f.kugel, 'geist_hell', (0.055, -0.15, 0.94), (0.03, 0.02, 0.04), knochen='head')
    f.quader('geist', (0, -0.16, 0.86), (0.06, 0.02, 0.025), knochen='head')
    for i in range(7):
        a = i / 7 * math.tau
        f.kugel('laub' if i % 2 else 'geist', (math.cos(a) * 0.13, -0.02 + math.sin(a) * 0.13, 1.06 + (i % 3) * 0.04), (0.1, 0.1, 0.08), knochen='head', beule=0.015)
    f.paar(f.zyl, 'rinde', (0.1, 0.0, 1.16), 0.018, 0.26, dreh=(0, -30, 0), knochen='head', seg=4, r2=0.006)   # Geweihäste
    return f


def pruefling():
    """Übungsgegner der Prüfungen: Strohpuppe auf Stock mit Eimerhelm und Holzschwert (0,8)."""
    f = Figur('pruefling', 63)
    f.paar(f.zyl, 'holz', (0.08, 0, 0.14), 0.025, 0.28, knochen='leg.X', seg=5)
    f.zyl('stroh', (0, 0, 0.42), 0.16, 0.34, r2=0.13, seg=8, beule=0.012)
    f.zyl('tuch_braun', (0, 0, 0.36), 0.165, 0.05, seg=8)
    f.kugel('auge_rot', (0, -0.15, 0.46), (0.06, 0.02, 0.06))                                               # Zielscheibe
    f.kugel('weiss', (0, -0.145, 0.46), (0.09, 0.015, 0.09))
    for i in range(6):
        f.kegel('stroh', (math.cos(i) * 0.13, math.sin(i) * 0.13, 0.25), 0.03, 0.1, dreh=(180, 0, 0), seg=4)
    f.paar(f.zyl, 'stroh', (0.2, 0, 0.5), 0.04, 0.24, dreh=(0, -70, 0), knochen='arm.X', seg=6)
    f.paar(f.kegel, 'stroh', (0.32, 0, 0.5), 0.045, 0.08, dreh=(0, -90, 0), knochen='hand.X', seg=5)
    f.kugel('stroh', (0, -0.01, 0.7), (0.11, 0.11, 0.11), knochen='head', beule=0.008)
    f.zyl('eisen', (0, -0.01, 0.77), 0.12, 0.14, knochen='head', seg=8, r2=0.1)                             # Eimer
    f.quader('schwarz', (0, -0.115, 0.74), (0.12, 0.02, 0.025), knochen='head')
    f.quader('holz', (-0.33, -0.12, 0.6), (0.04, 0.02, 0.4), dreh=(25, 0, 0), knochen='hand.R')
    f.quader('holz', (-0.33, -0.05, 0.44), (0.12, 0.025, 0.03), dreh=(25, 0, 0), knochen='hand.R')
    return f


def karawanenraeuber():
    """Wegelagerer: vermummter Räuber mit Kapuze, Halstuch, Beutesack und Krummdolchen (1,2)."""
    f = Figur('karawanenraeuber', 64)
    f.paar(f.zyl, 'tuch_braun', (0.1, 0, 0.22), 0.055, 0.44, knochen='leg.X', seg=6)
    f.paar(f.quader, 'leder', (0.1, -0.05, 0.04), (0.1, 0.2, 0.08), knochen='leg.X')
    f.zyl('leder', (0, 0, 0.62), 0.17, 0.4, r2=0.2, seg=8, beule=0.01)
    f.zyl('tuch_braun', (0, 0, 0.44), 0.2, 0.12, r2=0.18, seg=8)
    f.quader('arena_rot', (0, -0.17, 0.5), (0.1, 0.03, 0.22))                                               # Schärpe
    f.quader('leder', (0, -0.19, 0.68), (0.4, 0.03, 0.05), dreh=(0, 40, 0))
    f.kugel('stroh', (0.08, 0.2, 0.7), (0.15, 0.13, 0.18), beule=0.02)                                      # Beutesack
    f.kugel('gold', (0.1, 0.22, 0.88), (0.04, 0.04, 0.03))
    f.paar(f.zyl, 'tuch_braun', (0.22, -0.03, 0.68), 0.045, 0.3, dreh=(0, -12, 0), knochen='arm.X', seg=6)
    f.paar(f.kugel, 'haut', (0.25, -0.08, 0.5), (0.045, 0.045, 0.045), knochen='hand.X')
    f.paar(f.quader, 'eisen', (0.25, -0.22, 0.52), (0.03, 0.26, 0.012), dreh=(15, 0, 12), knochen='hand.X')  # Dolche
    f.kugel('haut', (0, -0.03, 0.96), (0.11, 0.12, 0.12), knochen='head')
    f.quader('arena_rot', (0, -0.11, 0.92), (0.17, 0.06, 0.08), knochen='head')                             # Halstuch vor dem Mund
    f.paar(f.kugel, 'auge', (0.045, -0.13, 0.99), (0.022, 0.014, 0.014), knochen='head')
    f.kugel('tuch_braun', (0, 0.02, 1.0), (0.15, 0.16, 0.14), knochen='head', stufe=2)
    f.kegel('tuch_braun', (0, 0.1, 1.1), 0.08, 0.2, dreh=(-55, 0, 0), knochen='head')
    return f


def kerkerwache():
    """Kerkerwächter: breiter Henker mit Eisenmaske, Schlüsselbund, Kettenschurz und Stachelkeule (1,5)."""
    f = Figur('kerkerwache', 65)
    f.paar(f.zyl, 'wache', (0.16, 0, 0.24), 0.09, 0.48, knochen='leg.X', seg=6)
    f.paar(f.quader, 'eisen', (0.16, -0.05, 0.05), (0.16, 0.26, 0.1), knochen='leg.X')
    f.zyl('wache', (0, 0, 0.58), 0.26, 0.22, r2=0.24, seg=8)
    for i in range(7):
        f.quader('eisen', ((i - 3) * 0.07, -0.22, 0.46), (0.05, 0.02, 0.22 - (i % 2) * 0.05))               # Kettenschurz
    f.zyl('haut', (0, 0, 0.92), 0.25, 0.44, r2=0.36, seg=8, beule=0.012)
    f.quader('leder', (0, -0.27, 0.96), (0.56, 0.04, 0.08), dreh=(0, -35, 0))
    f.zyl('leder', (0, 0, 0.7), 0.27, 0.07, seg=8)
    f.zyl('eisen', (0.2, -0.22, 0.6), 0.05, 0.012, dreh=(90, 0, 0), seg=8)                                  # Schlüsselring
    for k in range(3):
        f.quader('altgold', (0.17 + k * 0.03, -0.23, 0.52), (0.014, 0.012, 0.1), dreh=(0, (k - 1) * 14, 0))
    f.paar(f.kugel, 'wache', (0.4, 0, 1.14), (0.17, 0.17, 0.13), knochen='arm.X', beule=0.01)
    f.paar(f.zyl, 'haut', (0.44, -0.03, 0.84), 0.085, 0.42, dreh=(0, -8, 0), knochen='arm.X', seg=6)
    f.paar(f.zyl, 'eisen', (0.46, -0.05, 0.7), 0.095, 0.1, knochen='hand.X', seg=6)                         # Handschellenreste
    f.kugel('wache', (0, -0.03, 1.3), (0.15, 0.16, 0.17), knochen='head', stufe=2)                          # Henkerhaube
    f.kegel('wache', (0, 0.02, 1.46), 0.09, 0.16, knochen='head')
    f.quader('eisen', (0, -0.16, 1.28), (0.2, 0.03, 0.2), knochen='head')                                   # Eisenmaske
    f.paar(f.quader, 'auge_rot', (0.05, -0.18, 1.32), (0.04, 0.012, 0.022), knochen='head')
    for i in range(3):
        f.quader('schwarz', ((i - 1) * 0.045, -0.18, 1.22), (0.016, 0.012, 0.07), knochen='head')
    f.zyl('holz', (-0.46, -0.2, 0.9), 0.035, 0.8, dreh=(22, 0, 0), knochen='hand.R', seg=6)                 # Stachelkeule
    f.kugel('eisen', (-0.46, -0.36, 1.3), (0.13, 0.13, 0.15), knochen='hand.R', stufe=2)
    for i in range(6):
        a = i / 6 * math.tau
        f.kegel('eisen', (-0.46 + math.cos(a) * 0.14, -0.36, 1.3 + math.sin(a) * 0.14), 0.03, 0.12, dreh=(0, 90 - math.degrees(a), 0), knochen='hand.R', seg=4)
    f.zyl('eisen', (0.46, -0.05, 0.5), 0.012, 0.3, knochen='hand.L', seg=4)                                 # Kette mit Kugel
    f.kugel('eisen', (0.46, -0.05, 0.3), (0.08, 0.08, 0.08), knochen='hand.L')
    return f

FIGUREN = {'sumpfling': (sumpfling, 0.9), 'moorklauer': (moorklauer, 1.0),
           'schlammwerfer': (schlammwerfer, 1.2), 'speerjaeger': (speerjaeger, 1.4), 'giftkroete': (giftkroete, 0.7),
           'moorbrute': (moorbrute, 1.6), 'sumpfhexer': (sumpfhexer, 1.5), 'moorhauptmann': (moorhauptmann, 1.9),
           'grolm': (grolm, 4.2),
           'knochenknecht': (knochenknecht, 1.1), 'knochenschuetze': (knochenschuetze, 1.3), 'grabwaechter': (grabwaechter, 1.7),
           'knochengeier': (knochengeier, 0.6), 'totenrufer': (totenrufer, 1.5), 'knochenritter': (knochenritter, 2.0),
           'vargul': (vargul, 3.6),
           'glutling': (glutling, 0.8), 'glutspeier': (glutspeier, 1.2), 'lavawalze': (lavawalze, 1.4), 'glutfalter': (glutfalter, 0.5),
           'aschenpriester': (aschenpriester, 1.5), 'schmelzhauer': (schmelzhauer, 1.9), 'ignar': (ignar, 3.6),
           'leerling': (leerling, 0.9), 'leerenseher': (leerenseher, 1.4), 'nichtswandler': (nichtswandler, 1.8),
           'leerenschwinge': (leerenschwinge, 0.5), 'riftrufer': (riftrufer, 1.5), 'leerenhueter': (leerenhueter, 2.1),
           'verschlinger': (verschlinger, 4.6),
           'arenawaechter': (arenawaechter, 2.2), 'haingeist': (haingeist, 1.2), 'pruefling': (pruefling, 0.8),
           'karawanenraeuber': (karawanenraeuber, 1.2), 'kerkerwache': (kerkerwache, 1.5)}


def leeren():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bauen(name):
    leeren()
    fn, hoehe = FIGUREN[name]
    ob = fn().zusammen()
    # auf Zielhöhe skalieren, Füße auf z = 0
    zs = [v.co.z for v in ob.data.vertices]
    k = hoehe / (max(zs) - min(zs))
    for v in ob.data.vertices:
        v.co.z -= min(zs)
        v.co *= k
    return ob


# ---------------------------------------------------------------- Skelett und Animationen

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
# Angriffsart je Figur: hieb (rechts), beide (Doppelschlag), wurf (über Kopf), stoss (Speer rechts),
# stab (Stab links), sprung (Satz nach vorn). step/swing = Bein/Arm beim Laufen in Grad, bob = Wippen.
STIL = {
    'sumpfling': {'angriff': 'beide', 'step': 38, 'swing': 30, 'bob': 0.04},
    'moorklauer': {'angriff': 'beide', 'step': 22, 'swing': 10, 'bob': 0.02},
    'schlammwerfer': {'angriff': 'wurf', 'step': 30, 'swing': 22, 'bob': 0.03},
    'speerjaeger': {'angriff': 'wurf', 'step': 32, 'swing': 18, 'bob': 0.03},
    'giftkroete': {'angriff': 'sprung', 'step': 0, 'swing': 0, 'bob': 0.0, 'huepfen': 0.18},
    'moorbrute': {'angriff': 'beide', 'step': 26, 'swing': 20, 'bob': 0.06},
    'sumpfhexer': {'angriff': 'stab', 'step': 0, 'swing': 10, 'bob': 0.04, 'schweben': True},
    'moorhauptmann': {'angriff': 'stoss', 'step': 28, 'swing': 12, 'bob': 0.05},
    'grolm': {'angriff': 'beide', 'step': 22, 'swing': 16, 'bob': 0.12},
    'knochenknecht': {'angriff': 'hieb', 'step': 34, 'swing': 26, 'bob': 0.03},
    'knochenschuetze': {'angriff': 'wurf', 'step': 30, 'swing': 14, 'bob': 0.03},
    'grabwaechter': {'angriff': 'hieb', 'step': 24, 'swing': 14, 'bob': 0.05},
    'knochengeier': {'angriff': 'sprung', 'step': 0, 'swing': 34, 'bob': 0.05, 'schweben': True},
    'totenrufer': {'angriff': 'stab', 'step': 0, 'swing': 10, 'bob': 0.04, 'schweben': True},
    'knochenritter': {'angriff': 'hieb', 'step': 26, 'swing': 14, 'bob': 0.05},
    'vargul': {'angriff': 'hieb', 'step': 22, 'swing': 14, 'bob': 0.1},
    'glutling': {'angriff': 'beide', 'step': 38, 'swing': 30, 'bob': 0.04},
    'glutspeier': {'angriff': 'wurf', 'step': 30, 'swing': 18, 'bob': 0.03},
    'lavawalze': {'angriff': 'beide', 'step': 16, 'swing': 12, 'bob': 0.08},
    'glutfalter': {'angriff': 'sprung', 'step': 0, 'swing': 38, 'bob': 0.05, 'schweben': True},
    'aschenpriester': {'angriff': 'stab', 'step': 0, 'swing': 10, 'bob': 0.04, 'schweben': True},
    'schmelzhauer': {'angriff': 'hieb', 'step': 24, 'swing': 14, 'bob': 0.06},
    'ignar': {'angriff': 'beide', 'step': 22, 'swing': 16, 'bob': 0.1},
    'leerling': {'angriff': 'beide', 'step': 36, 'swing': 30, 'bob': 0.04},
    'leerenseher': {'angriff': 'wurf', 'step': 0, 'swing': 12, 'bob': 0.05, 'schweben': True},
    'nichtswandler': {'angriff': 'beide', 'step': 24, 'swing': 18, 'bob': 0.06},
    'leerenschwinge': {'angriff': 'sprung', 'step': 0, 'swing': 34, 'bob': 0.05, 'schweben': True},
    'riftrufer': {'angriff': 'stab', 'step': 0, 'swing': 8, 'bob': 0.05, 'schweben': True},
    'leerenhueter': {'angriff': 'hieb', 'step': 26, 'swing': 14, 'bob': 0.05},
    'verschlinger': {'angriff': 'beide', 'step': 10, 'swing': 18, 'bob': 0.08},
    'arenawaechter': {'angriff': 'stoss', 'step': 28, 'swing': 14, 'bob': 0.05},
    'haingeist': {'angriff': 'beide', 'step': 0, 'swing': 14, 'bob': 0.05, 'schweben': True},
    'pruefling': {'angriff': 'hieb', 'step': 30, 'swing': 20, 'bob': 0.04},
    'karawanenraeuber': {'angriff': 'beide', 'step': 36, 'swing': 26, 'bob': 0.03},
    'kerkerwache': {'angriff': 'hieb', 'step': 24, 'swing': 14, 'bob': 0.05},
}


def _gruppen(ob):
    """Knochenname -> Liste der Punkte."""
    namen = {g.index: g.name for g in ob.vertex_groups}
    out = {}
    for v in ob.data.vertices:
        for g in v.groups:
            out.setdefault(namen[g.group], []).append(v.co.copy())
    return out


def _mitte(pts):
    return sum(pts, Vector()) / len(pts)


MOOR = ('sumpfling', 'moorklauer', 'schlammwerfer', 'speerjaeger', 'giftkroete', 'moorbrute', 'sumpfhexer', 'moorhauptmann', 'grolm')


def riggen(ob):
    """Skelett aus den Teilen ableiten: Gelenke an den Rändern der Knochengruppen."""
    g = _gruppen(ob)
    H = max(v.co.z for v in ob.data.vertices)
    knochen = []  # (name, kopf, ende, eltern)
    beine = [b for b in ('leg.L', 'leg.R') if b in g]
    huefte = max(max(p.z for p in g[b]) for b in beine) if beine else H * 0.42
    kb = _mitte(g['body'])
    knochen.append(('root', Vector((0, 0, 0)), Vector((0, 0, H * 0.15)), None))
    knochen.append(('body', Vector((0, kb.y, huefte)), Vector((0, kb.y, max(huefte + 0.1, H * 0.8))), 'root'))
    if 'head' in g:
        hz = [p.z for p in g['head']]
        kh = _mitte(g['head'])
        hals = min(hz) + (max(hz) - min(hz)) * 0.3
        knochen.append(('head', Vector((0, kh.y * 0.5 + kb.y * 0.5, hals)), Vector((0, kh.y, max(hz))), 'body'))
    for b in beine:
        m = _mitte(g[b])
        knochen.append((b, Vector((m.x, m.y, huefte)), Vector((m.x, m.y, 0.0)), 'root'))
    for seite in 'LR':
        arm, hand = 'arm.' + seite, 'hand.' + seite
        ellbogen = None
        if arm in g:
            m = _mitte(g[arm])
            oben = max(p.z for p in g[arm])
            unten = min(p.z for p in g[arm])
            schulter = Vector((m.x * 0.8, m.y, oben))
            ellbogen = Vector((m.x, m.y, unten if unten < oben - 0.05 else oben - 0.1))
            if ob.name not in MOOR:
                # Gelenk dort, wo der Arm am Körper sitzt (körpernächster Teil), Ellbogen am fernsten
                # Punkt. Vorher lag die Schulter mitten im Arm: Flügel und schräge Arme drehten sich
                # um ihre eigene Mitte und lösten sich sichtbar vom Körper (2026-11-17).
                innen = min(abs(p.x) for p in g[arm])
                nah = [p for p in g[arm] if abs(p.x) < innen + 0.06]
                schulter = _mitte(nah)
                fern = max(g[arm], key=lambda p: (p - schulter).length)
                ellbogen = fern if (fern - schulter).length > 0.08 else schulter + Vector((0, 0, -0.1))
            knochen.append((arm, schulter, ellbogen, 'body'))
        if hand in g:
            m = _mitte(g[hand])
            kopf = ellbogen if ellbogen is not None else Vector((m.x, m.y, m.z + 0.15))
            ende = m if (m - kopf).length > 0.02 else kopf + Vector((0, 0, -0.1))
            knochen.append((hand, kopf, ende, arm if ellbogen is not None else 'body'))
    arm_d = bpy.data.armatures.new(ob.name + '_rig')
    rig = bpy.data.objects.new(ob.name + '_rig', arm_d)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name, kopf, ende, eltern in knochen:
        eb = arm_d.edit_bones.new(name)
        eb.head, eb.tail, eb.roll = kopf, ende, 0
        if eltern:
            eb.parent = arm_d.edit_bones[eltern]
    bpy.ops.object.mode_set(mode='OBJECT')
    # Teile an Knochen ohne eigenes Gelenk (z. B. hand ohne arm) bleiben über ihre Gruppe am nächsten Eltern
    for vg in ob.vertex_groups:
        if vg.name not in arm_d.bones:
            vg.name = 'body'
    ob.parent = rig
    mod = ob.modifiers.new('rig', 'ARMATURE')
    mod.object = rig
    return rig


class Anim:
    """Wie in helden_bau.py: Drehungen um Weltachsen je Knochen, als NLA-Spur je Animation."""

    def __init__(self, rig):
        self.rig = rig
        self.pb = rig.pose.bones
        for p in self.pb:
            p.rotation_mode = 'QUATERNION'
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
        rig.animation_data_create()
        self.aktionen = {}

    def key(self, frame, posen, loc=None):
        for p in self.pb:
            p.rotation_quaternion = Quaternion()
            p.location = Vector()
        for name, rots in posen.items():
            if name not in self.pb:
                continue
            q = Quaternion()
            for achse, grad in rots:
                q = Quaternion(Vector(achse), math.radians(grad)) @ q
            self.pb[name].rotation_quaternion = self.rest[name].inverted() @ q @ self.rest[name]
        if loc:
            self.pb['root'].location = self.rest['root'].inverted() @ Vector(loc)
        for p in self.pb:
            p.keyframe_insert('rotation_quaternion', frame=frame)
            p.keyframe_insert('location', frame=frame)

    def action(self, name, frames):
        act = bpy.data.actions.new(self.rig.name + '_' + name)
        act.use_fake_user = True
        self.rig.animation_data.action = act
        for fr, posen, loc in frames:
            self.key(fr, posen, loc)
        spur = self.rig.animation_data.nla_tracks.new()
        spur.name = name
        spur.strips.new(name, int(frames[0][0]), act)
        self.rig.animation_data.action = None
        self.aktionen[name] = act


def _m(*ps):
    out = {}
    for p in ps:
        for k, v in p.items():
            out[k] = out.get(k, []) + list(v)
    return out


def animieren(name, rig):
    """Vorne ist -Y. Drehung um X mit positivem Winkel kippt den Oberkörper nach vorn und schwingt
    hängende Arme nach hinten."""
    st = STIL[name]
    A = Anim(rig)
    H = rig.data.bones['body'].tail_local.z
    # Ruhe: Atmen (2 s)
    atmen = {'body': [(X, 3)], 'head': [(X, -4)], 'arm.L': [(Y, 4)], 'arm.R': [(Y, -4)]}
    A.action('idle', [(1, {}, None), (25, atmen, (0, 0, -0.015 * H)), (49, {}, None)])
    # Laufen: 16 Bilder je Doppelschritt
    frames = []
    for i in range(9):
        w = i / 8 * math.tau
        si, co = math.sin(w), abs(math.cos(w))
        p = {'leg.L': [(X, st['step'] * si)], 'leg.R': [(X, -st['step'] * si)],
             'arm.L': [(X, -st['swing'] * si)], 'arm.R': [(X, st['swing'] * si)],
             'body': [(X, 6), (Z, 5 * si)], 'head': [(X, -3), (Z, -3 * si)]}
        loc = (0, 0, st['bob'] * (co - 0.5))
        if st.get('schweben'):
            p['body'] = [(X, 8), (Y, 6 * si)]
            loc = (0, 0, st['bob'] * (1 + math.sin(w)))
        if st.get('huepfen'):
            t = i / 8
            sprung = math.sin(min(t * 2, 1) * math.pi)
            p = {'leg.L': [(X, -50 * sprung)], 'leg.R': [(X, -50 * sprung)], 'arm.L': [(X, 30 * sprung)],
                 'arm.R': [(X, 30 * sprung)], 'body': [(X, -12 * sprung)]}
            loc = (0, 0, st['huepfen'] * sprung)
        frames.append((1 + i * 2, p, loc))
    A.action('run', frames)
    # Angriff
    art = st['angriff']
    if art == 'beide':
        auf = {'arm.L': [(X, -150)], 'arm.R': [(X, -150)], 'hand.L': [(X, -20)], 'hand.R': [(X, -20)],
               'body': [(X, -14)], 'head': [(X, -8)]}
        ab = {'arm.L': [(X, -50)], 'arm.R': [(X, -50)], 'hand.L': [(X, 20)], 'hand.R': [(X, 20)],
              'body': [(X, 22)], 'head': [(X, 6)]}
        A.action('attack', [(1, {}, None), (7, auf, (0, 0.04 * H, 0.03 * H)), (11, ab, (0, -0.06 * H, -0.04 * H)),
                            (14, ab, (0, -0.06 * H, -0.04 * H)), (22, {}, None)])
    elif art == 'wurf':
        aus = {'arm.R': [(X, 160)], 'hand.R': [(X, 30)], 'body': [(X, -12), (Z, -20)], 'arm.L': [(X, -40)]}
        los = {'arm.R': [(X, -100)], 'hand.R': [(X, -10)], 'body': [(X, 18), (Z, 15)], 'arm.L': [(X, 20)]}
        A.action('attack', [(1, {}, None), (8, aus, None), (12, los, (0, -0.04 * H, 0)), (15, los, None), (22, {}, None)])
    elif art == 'stoss':
        zurueck = {'arm.R': [(X, 35)], 'body': [(Z, -20), (X, -4)], 'arm.L': [(X, -30)]}
        vor = {'arm.R': [(X, -75)], 'body': [(Z, 15), (X, 14)], 'arm.L': [(X, -20)], 'leg.R': [(X, 20)], 'leg.L': [(X, -15)]}
        A.action('attack', [(1, {}, None), (7, zurueck, None), (10, vor, (0, -0.1 * H, -0.02 * H)),
                            (14, vor, (0, -0.1 * H, -0.02 * H)), (22, {}, None)])
    elif art == 'stab':
        auf = {'arm.L': [(X, -60)], 'body': [(X, -8)], 'head': [(X, -10)]}
        vor = {'arm.L': [(X, -95)], 'body': [(X, 16)], 'head': [(X, 8)]}
        A.action('attack', [(1, {}, None), (7, auf, (0, 0, 0.03 * H)), (11, vor, (0, -0.05 * H, 0)), (14, vor, None), (22, {}, None)])
    else:  # sprung
        duck = {'body': [(X, 10)], 'leg.L': [(X, 25)], 'leg.R': [(X, 25)]}
        satz = {'body': [(X, -18)], 'head': [(X, -20)], 'leg.L': [(X, -60)], 'leg.R': [(X, -60)],
                'arm.L': [(X, -50)], 'arm.R': [(X, -50)]}
        A.action('attack', [(1, {}, None), (6, duck, (0, 0, -0.08 * H)), (10, satz, (0, -0.35 * H, 0.25 * H)),
                            (14, {}, (0, -0.2 * H, 0)), (22, {}, None)])
    # Zauber: Arme hoch, Oberkörper zurück, kurz anheben
    hoch = {'arm.L': [(X, -160), (Y, -15)], 'arm.R': [(X, -160), (Y, 15)], 'body': [(X, -14)], 'head': [(X, -18)]}
    if st.get('huepfen'):
        hoch = {'body': [(X, -25)], 'head': [(X, -25)], 'leg.L': [(X, 20)], 'leg.R': [(X, 20)]}
    elif art == 'stab':  # Stab bleibt aufrecht: nur anheben, freie Hand hoch
        hoch = {'arm.L': [(X, -35)], 'arm.R': [(X, -150), (Y, 15)], 'body': [(X, -10)], 'head': [(X, -18)]}
    A.action('cast', [(1, {}, None), (8, hoch, (0, 0, 0.06 * H)), (16, hoch, (0, 0, 0.08 * H)), (24, {}, None)])
    # Treffer: kurz nach hinten zucken
    zuck = {'body': [(X, -16)], 'head': [(X, -12)], 'arm.L': [(X, 20)], 'arm.R': [(X, 20)]}
    A.action('hit', [(1, {}, None), (4, zuck, (0, 0.05 * H, 0)), (10, {}, None)])
    # Tod: nach hinten umkippen und liegen bleiben
    knick = {'body': [(X, -20)], 'head': [(X, -25)], 'leg.L': [(X, 15)], 'leg.R': [(X, 15)],
             'arm.L': [(X, -40), (Y, 30)], 'arm.R': [(X, -40), (Y, -30)]}
    liegt = _m(knick, {'root': [(X, -85)]})
    if st.get('huepfen'):
        knick = {'body': [(X, -10)], 'leg.L': [(X, -40)], 'leg.R': [(X, -40)]}
        liegt = _m(knick, {'root': [(Y, 170)]})
    unten = 1.2 * H if st.get('huepfen') else 0.0  # auf den Rücken gedreht: wieder über den Boden heben
    A.action('death', [(1, {}, None), (6, knick, (0, 0.05 * H, 0.3 * unten)), (16, liegt, (0, 0.2 * H, unten)),
                       (19, _m(liegt, {'head': [(X, 8)]}), (0, 0.22 * H, unten)), (30, liegt, (0, 0.2 * H, unten))])
    # Grundpose zurücksetzen: sonst exportiert glTF die letzte Schlüsselpose (Tod) als Ruhelage der Knochen
    for p in A.pb:
        p.rotation_quaternion = Quaternion()
        p.location = Vector()
    return A


def pose_zeigen(rig, anim, bild):
    """Pose zeigen: Aktion setzen, Bild anspringen (für Vorschaubilder)."""
    for t in rig.animation_data.nla_tracks:
        t.mute = True
    rig.animation_data.action = anim
    bpy.context.scene.frame_set(bild)


def exportieren(ob, rig, pfad):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=pfad, export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='NLA_TRACKS', export_skins=True, export_yup=True,
                              export_apply=False)


def rendern(ob, pfad, groesse=420):
    sc = bpy.context.scene
    if sc.camera:
        sc.render.filepath = pfad
        bpy.ops.render.render(write_still=True)
        return
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = groesse
    sc.render.film_transparent = False
    w = bpy.data.worlds.new('w')
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (0.05, 0.06, 0.09, 1)
    w.node_tree.nodes['Background'].inputs[1].default_value = 0.6
    sc.world = w
    # Boden
    bpy.ops.mesh.primitive_plane_add(size=40)
    boden = bpy.context.object
    bm = bpy.data.materials.new('boden')
    bm.use_nodes = True
    bm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.12, 0.14, 0.11, 1)
    boden.data.materials.append(bm)
    zs = [v.co.z for v in ob.data.vertices]
    h = max(zs)
    breite = max(max(abs(v.co.x) for v in ob.data.vertices), max(abs(v.co.y) for v in ob.data.vertices))
    # Kamera schräg von vorn oben (wie die Spielkamera, etwas flacher)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = max(h, breite * 2) * 1.35
    d = 10.0
    cam.location = (d * 0.55, -d * 0.85, h * 0.5 + d * 0.5)
    ziel = Vector((0, 0, h * 0.45))
    cam.rotation_euler = (ziel - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sonne = bpy.data.objects.new('sonne', bpy.data.lights.new('sonne', 'SUN'))
    sonne.data.energy = 3.5
    sonne.data.angle = math.radians(8)
    sonne.rotation_euler = (math.radians(40), 0, math.radians(20))
    sc.collection.objects.link(sonne)
    fill = bpy.data.objects.new('fill', bpy.data.lights.new('fill', 'SUN'))
    fill.data.energy = 0.8
    fill.data.use_shadow = False
    fill.data.color = (0.5, 0.7, 1.0)
    fill.rotation_euler = (math.radians(60), 0, math.radians(200))
    sc.collection.objects.link(fill)
    sc.render.filepath = pfad
    bpy.ops.render.render(write_still=True)


def gruppenbild(namen, pfad):
    """Alle Figuren nebeneinander in einer Szene, damit die Größen vergleichbar sind."""
    leeren()
    obs, x = [], 0.0
    for n in namen:
        fn, hoehe = FIGUREN[n]
        ob = fn().zusammen()
        zs = [v.co.z for v in ob.data.vertices]
        k = hoehe / (max(zs) - min(zs))
        for v in ob.data.vertices:
            v.co.z -= min(zs)
            v.co *= k
        b = max(abs(v.co.x) for v in ob.data.vertices)
        x += b
        ob.location.x = x
        x += b + 0.35
        obs.append(ob)
    for ob in obs:
        ob.location.x -= x / 2
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True)
    ob = bpy.context.object
    sc = bpy.context.scene
    rendern(ob, pfad, 420)
    sc.render.resolution_x, sc.render.resolution_y = 2000, 700
    cam = sc.camera
    cam.data.ortho_scale = x * 1.02
    cam.location = (0, -12, 6.5)
    cam.rotation_euler = (Vector((0, 0, 1.6)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.render.render(write_still=True)
    print('GRUPPE', pfad)


def main():
    os.makedirs(ZIEL, exist_ok=True)
    if GRUPPE:
        gruppenbild(NUR or list(FIGUREN), GRUPPE)
        return
    namen = NUR or list(FIGUREN)
    bilder = []
    posen = []
    for n in namen:
        ob = bauen(n)
        rig = riggen(ob)
        A = animieren(n, rig)
        exportieren(ob, rig, os.path.join(ZIEL, n + '.glb'))
        print('GLB', n, len(ob.data.polygons), 'Flächen', len(rig.data.bones), 'Knochen')
        if BOGEN:
            p = os.path.join(ZIEL, n + '.png')
            rendern(ob, p)
            bilder.append((n, p))
        if POSEN:
            reihe = []
            for a, bild in (('idle', 1), ('run', 5), ('attack', 7), ('attack', 12), ('cast', 10), ('death', 30)):
                pose_zeigen(rig, A.aktionen[a], bild)
                p = os.path.join(ZIEL, f'{n}_{a}_{bild}.png')
                rendern(ob, p, 300)
                reihe.append(p)
            posen.append((n, reihe))
    if POSEN:
        from PIL import Image, ImageDraw
        s = 300
        im = Image.new('RGB', (6 * s, len(posen) * (s + 20)), (20, 22, 30))
        dr = ImageDraw.Draw(im)
        for j, (n, reihe) in enumerate(posen):
            for i, p in enumerate(reihe):
                im.paste(Image.open(p).convert('RGB').resize((s, s)), (i * s, j * (s + 20)))
            dr.text((6, j * (s + 20) + s + 4), n + '   Ruhe | Laufen | Ausholen | Schlag | Zauber | Tod', fill=(240, 240, 240))
        im.save(POSEN)
        print('POSEN', POSEN)
    if BOGEN:
        from PIL import Image, ImageDraw
        s, spalten = 420, 5
        zeilen = (len(bilder) + spalten - 1) // spalten
        im = Image.new('RGB', (spalten * s, zeilen * (s + 26)), (20, 22, 30))
        dr = ImageDraw.Draw(im)
        for i, (n, p) in enumerate(bilder):
            x, y = (i % spalten) * s, (i // spalten) * (s + 26)
            im.paste(Image.open(p).convert('RGB'), (x, y))
            hoehe = FIGUREN[n][1]
            dr.text((x + 8, y + s + 6), f'{n}  ({hoehe:g})', fill=(240, 240, 240))
        im.save(BOGEN)
        print('BOGEN', BOGEN)


main()
