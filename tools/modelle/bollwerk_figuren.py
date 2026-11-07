# Bollwerk (Hero Defense): Held Torvik und die Moor-Gegner als eigene Low-Poly-Modelle (eigene Arbeit, CC0).
# Jede Figur ist eine Funktion aus einfachen Teilen (Kugel, Zylinder, Kegel, Quader), leicht verbeult für einen
# handgemachten Look, mit flacher Schattierung. Jedes Teil hängt an einem Knochen (body, head, arm.L …), damit
# später Skelett und Animationen dazukommen können. Maße in Spieleinheiten, Höhe wie "size" in data/heroes.json.
# Blender: Z oben, Blick nach -Y (wird im glTF zu +Z, der Blickrichtung in hd_enemy.gd).
#
#   <python mit bpy> -I tools/modelle/bollwerk_figuren.py -- <zielordner> [--nur=torvik,grolm] [--bogen=bogen.png]
#
# Ohne --bogen nur .glb je Figur; mit --bogen zusätzlich ein Vorschau-Kontaktbogen (Cycles, CPU).
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ZIEL = argv[0] if argv else '/tmp/bollwerk'
NUR = next((a.split('=', 1)[1].split(',') for a in argv if a.startswith('--nur=')), None)
BOGEN = next((a.split('=', 1)[1] for a in argv if a.startswith('--bogen=')), '')

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
    'lila_glut': (0.75, 0.35, 1.00), 'wurzel': (0.30, 0.20, 0.12), 'krone': (0.70, 0.55, 0.20),
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
        ob['knochen'] = knochen
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


# ---------------------------------------------------------------- Held

def torvik():
    f = Figur('torvik', 3)
    # Beine und Stiefel
    f.paar(f.zyl, 'leder', (0.2, 0, 0.32), 0.15, 0.5, knochen='leg.X', r2=0.12)
    f.paar(f.quader, 'leder', (0.2, -0.06, 0.07), (0.24, 0.36, 0.14), knochen='leg.X')
    # Rumpf: Kettenrock, Brustpanzer, Gürtel
    f.zyl('stahl_dunkel', (0, 0, 0.62), 0.36, 0.32, r2=0.30, seg=10)
    f.zyl('stahl', (0, 0, 1.0), 0.38, 0.52, r2=0.46, seg=8, beule=0.01)
    f.zyl('leder', (0, 0, 0.78), 0.39, 0.1, seg=10)
    f.quader('gold', (0, -0.38, 0.78), (0.16, 0.06, 0.12))
    # Blitzrune auf der Brust
    f.quader('blitz', (0, -0.42, 1.08), (0.06, 0.03, 0.22), dreh=(0, 25, 0))
    # Schultern mit Fell
    f.paar(f.kugel, 'stahl', (0.5, 0, 1.24), (0.24, 0.24, 0.2), knochen='arm.X', beule=0.01)
    f.kugel('fell', (0, 0.05, 1.27), (0.45, 0.3, 0.12), beule=0.03)
    # Umhang hinten
    f.quader('umhang', (0, 0.36, 0.88), (0.62, 0.06, 0.78), dreh=(-8, 0, 0), beule=0.02)
    # Arme
    f.paar(f.zyl, 'haut', (0.56, -0.04, 0.96), 0.1, 0.42, knochen='arm.X', dreh=(0, -12, 0))
    f.paar(f.zyl, 'leder', (0.6, -0.06, 0.74), 0.12, 0.18, knochen='hand.X')
    # Kopf: Gesicht, Bart, Flügelhelm
    f.kugel('haut', (0, -0.02, 1.52), (0.2, 0.2, 0.22), knochen='head')
    f.kegel('bart', (0, -0.14, 1.36), 0.17, 0.34, dreh=(195, 0, 0), knochen='head', beule=0.02)
    f.paar(f.quader, 'auge', (0.08, -0.19, 1.56), (0.05, 0.02, 0.025), knochen='head')
    f.rund('stahl', (0, 0.0, 1.64), (0.23, 0.23, 0.17), knochen='head', seg=10, ringe=5)
    f.quader('stahl', (0, -0.2, 1.53), (0.04, 0.03, 0.14), knochen='head')
    f.paar(f.quader, 'weiss', (0.26, 0.05, 1.72), (0.04, 0.22, 0.12), dreh=(0, -35, -20), knochen='head')
    # Zwei Äxte mit leuchtenden Blitzklingen
    for s, seite in ((1, 'L'), (-1, 'R')):
        kn = 'hand.' + seite
        f.zyl('holz', (0.66 * s, -0.22, 0.74), 0.035, 0.85, dreh=(70, 0, 0), knochen=kn, seg=6)
        f.quader('blitz', (0.66 * s, -0.56, 0.98), (0.04, 0.2, 0.34), knochen=kn)
        f.quader('stahl_dunkel', (0.66 * s, -0.46, 0.89), (0.06, 0.08, 0.1), knochen=kn)
    return f


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
    """Boss: riesiger Moortroll mit Wurzelgeweih-Krone, Moosmantel und glühenden Augen (3,4)."""
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
    f.paar(f.kugel, 'auge_rot', (0.15, -0.95, 2.28), (0.07, 0.05, 0.05), knochen='head')
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


FIGUREN = {'torvik': (torvik, 2.1), 'sumpfling': (sumpfling, 0.9), 'moorklauer': (moorklauer, 1.0),
           'schlammwerfer': (schlammwerfer, 1.2), 'speerjaeger': (speerjaeger, 1.4), 'giftkroete': (giftkroete, 0.7),
           'moorbrute': (moorbrute, 1.6), 'sumpfhexer': (sumpfhexer, 1.5), 'moorhauptmann': (moorhauptmann, 1.9),
           'grolm': (grolm, 3.4)}


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


def exportieren(ob, pfad):
    bpy.ops.export_scene.gltf(filepath=pfad, export_format='GLB', use_selection=False, export_apply=True,
                              export_yup=True)


def rendern(ob, pfad, groesse=420):
    sc = bpy.context.scene
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


def main():
    os.makedirs(ZIEL, exist_ok=True)
    namen = NUR or list(FIGUREN)
    bilder = []
    for n in namen:
        ob = bauen(n)
        exportieren(ob, os.path.join(ZIEL, n + '.glb'))
        print('GLB', n, len(ob.data.polygons), 'Flächen')
        if BOGEN:
            p = os.path.join(ZIEL, n + '.png')
            rendern(ob, p)
            bilder.append((n, p))
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
