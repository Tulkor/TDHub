# Heldenmodelle für Bollwerk (Hero Defense): eigene Low-Poly-Figuren aus einfachen Formen, mit Skelett
# (starre Gewichte je Teil) und Animationen idle, run, attack, cast, death.
# Aufruf (Blender als Python-Modul bpy, siehe tools/modelle/README.md):
#   <python mit bpy> -I tools/modelle/helden_bau.py -- <zielordner> [--nur=torvik,unrat] [--bild=vorschau.png]
#        [--posen=posen.png]
# Blickrichtung der Figuren ist Blender +Y (wird beim glTF-Export zu Godot -Z = vorne).
import bpy, bmesh, math, sys, os, random
from mathutils import Vector, Quaternion, Matrix, Euler

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else '/tmp/helden'
OPT = {a.split('=')[0][2:]: (a.split('=', 1)[1] if '=' in a else '1') for a in argv[1:] if a.startswith('--')}
NUR = OPT.get('nur', '').split(',') if OPT.get('nur') else None
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
FPS = 24
bpy.context.scene.render.fps = FPS

# --- Materialien ------------------------------------------------------------
_mats = {}
def M(color, rough=0.75, metal=0.0, emit=0.0):
    key = (color, rough, metal, emit)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new('m_%s_%d' % (color.strip('#'), len(_mats)))
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    c = tuple(int(color.strip('#')[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    lin = tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)
    p.inputs['Base Color'].default_value = (*lin, 1.0)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if emit > 0:
        p.inputs['Emission Color'].default_value = (*lin, 1.0)
        p.inputs['Emission Strength'].default_value = emit
    _mats[key] = m
    return m


# --- Figur aus Teilen -------------------------------------------------------
class Figur:
    """Sammelt alle Teile einer Figur in einem bmesh; jedes Teil gehört ganz zu einem Knochen."""
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.dl = self.bm.verts.layers.deform.verify()
        self.mats = []
        self.bones = []      # (name, head, tail, parent)
        self.groups = []
        self.J = {}

    def bone(self, name, head, tail, parent=None):
        self.bones.append((name, Vector(head), Vector(tail), parent))
        self.J[name] = (Vector(head), Vector(tail))

    def _mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _gi(self, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        return self.groups.index(bone)

    def _finish(self, verts, mat, bone):
        mi, gi = self._mi(mat), self._gi(bone)
        faces = set()
        for v in verts:
            v[self.dl][gi] = 1.0
            faces.update(v.link_faces)
        for f in faces:
            f.material_index = mi
        return verts

    @staticmethod
    def _mx(loc, rot, scale):
        r = Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4()
        s = Matrix.Diagonal((*scale, 1.0))
        return Matrix.Translation(Vector(loc)) @ r @ s

    def box(self, size, loc, mat, bone, rot=(0, 0, 0), bevel=0.0):
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._mx(loc, rot, size))
        vs = r['verts']
        if bevel > 0:
            edges = list({e for v in vs for e in v.link_edges})
            res = bmesh.ops.bevel(self.bm, geom=vs + edges, offset=bevel, segments=1, affect='EDGES',
                                  profile=0.5, offset_type='OFFSET')
            vs = list({v for f in res['faces'] for v in f.verts} | set(v for v in vs if v.is_valid))
        return self._finish(vs, mat, bone)

    def cyl(self, r1, r2, h, loc, mat, bone, rot=(0, 0, 0), seg=8, scale=(1, 1, 1)):
        """Kegelstumpf, Mitte bei loc, Achse lokal Z (r1 unten, r2 oben)."""
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1,
                                  radius2=max(r2, 0.0001), depth=h, matrix=self._mx(loc, rot, scale))
        return self._finish(r['verts'], mat, bone)

    def ball(self, r, loc, mat, bone, scale=(1, 1, 1), rot=(0, 0, 0), seg=10, rings=7):
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=r,
                                        matrix=self._mx(loc, rot, scale))
        return self._finish(res['verts'], mat, bone)

    def stab(self, a, b, r1, r2, mat, bone, seg=8):
        """Zylinder von Punkt a nach b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        mx = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1,
                                  radius2=max(r2, 0.0001), depth=d.length, matrix=mx)
        return self._finish(r['verts'], mat, bone)

    def glied(self, bone, r1, r2, mat, seg=8, ext=(0.0, 0.0), on=None):
        """Zylinder entlang eines Knochens (ext verlängert an Kopf/Ende)."""
        h, t = self.J[bone]
        d = (t - h).normalized()
        return self.stab(h - d * ext[0], t + d * ext[1], r1, r2, mat, on or bone, seg)

    def platte(self, pts, normal, dicke, mat, bone):
        """Flaches Prisma aus einem Umriss (Punkte in einer Ebene), dicke entlang normal."""
        h = Vector(normal).normalized() * dicke / 2
        lo = [self.bm.verts.new(Vector(p) - h) for p in pts]
        hi = [self.bm.verts.new(Vector(p) + h) for p in pts]
        self.bm.faces.new(lo[::-1])
        self.bm.faces.new(hi)
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        return self._finish(lo + hi, mat, bone)

    def jag(self, verts, depth, seed=1):
        """Untersten Ring eines Teils zackig machen (Lumpen)."""
        rnd = random.Random(seed)
        zmin = min(v.co.z for v in verts)
        for v in verts:
            if abs(v.co.z - zmin) < 1e-4:
                v.co.z += rnd.random() * depth

    def spiegel(self, fn):
        """fn(s, side) für links (+X, 'L') und rechts (-X, 'R')."""
        fn(1, 'L')
        fn(-1, 'R')

    def bauen(self):
        # Skelett
        arm = bpy.data.armatures.new(self.name + '_skel')
        rig = bpy.data.objects.new(self.name, arm)
        bpy.context.scene.collection.objects.link(rig)
        bpy.context.view_layer.objects.active = rig
        for o in bpy.context.scene.objects:
            o.select_set(o == rig)
        bpy.ops.object.mode_set(mode='EDIT')
        eb = {}
        for name, h, t, parent in self.bones:
            b = arm.edit_bones.new(name)
            b.head, b.tail = h, t
            if parent:
                b.parent = eb[parent]
            eb[name] = b
        bpy.ops.object.mode_set(mode='OBJECT')
        # Netz
        me = bpy.data.meshes.new(self.name + '_mesh')
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name + '_body', me)
        bpy.context.scene.collection.objects.link(ob)
        for g in self.groups:
            ob.vertex_groups.new(name=g)
        ob.parent = rig
        mod = ob.modifiers.new('skel', 'ARMATURE')
        mod.object = rig
        self.rig, self.ob = rig, ob
        return rig


def mensch(f, hip, neck, head_top, sh, elbow, hand, knee, foot, hip_x):
    """Standard-Skelett. sh/elbow/hand: linke Seite (+X), rechts wird gespiegelt."""
    f.bone('root', (0, 0, 0), (0, 0, 0.3))
    f.bone('hips', (0, 0, hip), (0, 0, hip + 0.12), 'root')
    f.bone('chest', (0, 0, hip + 0.12), (0, 0, neck), 'hips')
    f.bone('head', (0, 0, neck), (0, 0, head_top), 'chest')
    for s, side in ((1, 'L'), (-1, 'R')):
        m = lambda p: (p[0] * s, p[1], p[2])
        f.bone('arm.' + side, m(sh), m(elbow), 'chest')
        f.bone('fore.' + side, m(elbow), m(hand), 'arm.' + side)
        f.bone('thigh.' + side, (hip_x * s, 0, hip), (knee[0] * s, knee[1], knee[2]), 'hips')
        f.bone('shin.' + side, (knee[0] * s, knee[1], knee[2]), (foot[0] * s, foot[1], foot[2]), 'thigh.' + side)


# --- Torvik Sturmruf: Hüne mit zwei Runenäxten ----------------------------
def torvik():
    f = Figur('torvik')
    hand = (0.74, 0.14, 0.74)
    mensch(f, hip=1.0, neck=1.68, head_top=2.2, sh=(0.56, 0, 1.6), elbow=(0.7, 0.02, 1.13), hand=hand,
           knee=(0.23, 0.03, 0.54), foot=(0.23, 0, 0.12), hip_x=0.2)
    skin, leather, dark = M('#c98e62', 0.7), M('#6b4a2a', 0.85), M('#3b2a1c', 0.9)
    steel, blue = M('#9aa8b8', 0.35, 0.8), M('#2b5f96', 0.45, 0.5)
    fur, beard = M('#d8d2c4', 0.95), M('#b5532a', 0.9)
    rune, eye = M('#7fe8ff', 0.3, 0.0, 6.0), M('#bff6ff', 0.2, 0.0, 8.0)
    gold = M('#d4a640', 0.35, 0.9)
    # Becken, Gürtel, Lendenschurz
    f.cyl(0.42, 0.37, 0.34, (0, 0, 0.9), leather, 'hips', seg=10)
    f.cyl(0.43, 0.43, 0.12, (0, 0, 1.08), dark, 'hips', seg=10)
    f.box((0.2, 0.06, 0.16), (0, 0.42, 1.08), gold, 'hips', bevel=0.02)
    f.ball(0.04, (0, 0.46, 1.08), rune, 'hips', seg=6, rings=4)
    for x, y, rz in ((0, 0.34, 0), (0, -0.34, 0), (0.3, 0.22, -35), (-0.3, 0.22, 35)):
        f.box((0.26, 0.05, 0.42), (x, y, 0.78), dark, 'hips', rot=(0, 0, rz), bevel=0.015)
    # Oberkörper: breite Brust, Bauch, Riemen
    f.cyl(0.36, 0.44, 0.32, (0, 0, 1.27), skin, 'chest', seg=10)
    f.ball(0.5, (0, 0.02, 1.5), skin, 'chest', scale=(1.12, 0.78, 0.6), seg=12)
    f.stab((0.42, 0.33, 1.68), (-0.36, 0.33, 1.15), 0.055, 0.055, leather, 'chest', seg=6)
    f.stab((0.42, -0.3, 1.68), (-0.36, -0.3, 1.15), 0.055, 0.055, leather, 'chest', seg=6)
    # Sturm-Tätowierungen (leuchtend)
    for z, w in ((1.52, 0.22), (1.42, 0.16)):
        f.box((w, 0.02, 0.025), (0.2, 0.39, z), rune, 'chest', rot=(0, -25, 0))
        f.box((w, 0.02, 0.025), (-0.2, 0.39, z), rune, 'chest', rot=(0, 25, 0))
    # Schulterpanzer mit Fell und Dornen
    def schulter(s, side):
        p = (0.6 * s, 0, 1.68)
        f.ball(0.3, p, blue, 'chest', scale=(1.0, 1.05, 0.72), seg=10, rings=6)
        f.cyl(0.32, 0.3, 0.1, (0.6 * s, 0, 1.52), fur, 'chest', seg=10)
        f.cyl(0.36, 0.32, 0.06, (0.6 * s, 0, 1.6), steel, 'chest', seg=10)
        for k, (dy, h) in enumerate(((-0.12, 0.3), (0.08, 0.22))):
            f.cyl(0.07, 0.0, h, (0.68 * s, dy, 1.86 + h / 2 - 0.05), steel, 'chest', rot=(0, 18 * s, 0), seg=6)
    f.spiegel(schulter)
    # Kopf: Glatze mit Haarknoten, geflochtener Bart, leuchtende Augen
    f.cyl(0.14, 0.16, 0.14, (0, 0.02, 1.72), skin, 'head', seg=8)
    f.ball(0.25, (0, 0.04, 1.93), skin, 'head', scale=(0.95, 1.0, 1.08), seg=10)
    f.box((0.34, 0.08, 0.06), (0, 0.24, 2.0), beard, 'head', bevel=0.015)  # Brauen
    f.ball(0.04, (0.085, 0.27, 1.95), eye, 'head', seg=6, rings=4)
    f.ball(0.04, (-0.085, 0.27, 1.95), eye, 'head', seg=6, rings=4)
    f.cyl(0.05, 0.02, 0.12, (0, 0.3, 1.89), skin, 'head', rot=(70, 0, 0), seg=5)
    f.ball(0.2, (0, 0.17, 1.78), beard, 'head', scale=(1.1, 0.8, 0.9), seg=8)
    f.cyl(0.13, 0.03, 0.34, (0, 0.24, 1.58), beard, 'head', rot=(12, 0, 0), seg=6)
    for s in (1, -1):
        f.cyl(0.06, 0.02, 0.3, (0.13 * s, 0.22, 1.6), beard, 'head', rot=(10, 0, 0), seg=5)
        f.ball(0.035, (0.13 * s, 0.24, 1.46), gold, 'head', seg=6, rings=4)
        f.box((0.14, 0.05, 0.04), (0.08 * s, 0.27, 1.85), beard, 'head', rot=(0, 25 * s, 0))
        f.ball(0.06, (0.24 * s, 0.03, 1.93), skin, 'head', scale=(0.5, 1, 1.2), seg=6, rings=4)  # Ohren
    f.ball(0.1, (0, -0.06, 2.2), beard, 'head', seg=8)
    f.cyl(0.08, 0.04, 0.22, (0, -0.16, 2.12), beard, 'head', rot=(-60, 0, 0), seg=6)
    f.cyl(0.06, 0.06, 0.04, (0, -0.06, 2.14), gold, 'head', seg=8)
    # Arme mit Armschienen
    def arm(s, side):
        f.glied('arm.' + side, 0.17, 0.14, skin, ext=(0.05, 0.0))
        f.ball(0.14, f.J['fore.' + side][0], skin, 'arm.' + side, seg=8, rings=5)
        f.glied('fore.' + side, 0.13, 0.12, skin)
        h, t = f.J['fore.' + side]
        f.stab(h + (t - h) * 0.35, h + (t - h) * 0.9, 0.15, 0.14, leather, 'fore.' + side)
        f.stab(h + (t - h) * 0.5, h + (t - h) * 0.6, 0.16, 0.16, steel, 'fore.' + side)
        f.ball(0.13, t, skin, 'fore.' + side, seg=8, rings=5)
        # Runenaxt: Griff schräg nach vorn oben, Doppelblatt oben
        hx = Vector(t)
        d = Vector((0.0, 0.75, 0.66)).normalized()
        a, b = hx - d * 0.2, hx + d * 0.95
        f.stab(a, b, 0.04, 0.04, dark, 'fore.' + side, seg=6)
        f.stab(hx - d * 0.05, hx + d * 0.08, 0.055, 0.055, leather, 'fore.' + side, seg=6)
        top = hx + d * 0.78
        rx = math.degrees(math.atan2(d.y, d.z))
        # Doppelblatt: Blattfläche liegt in der Schlagebene (Y-Z), Schneide breiter als der Ansatz
        n = Vector((0, d.z, -d.y))   # quer zum Griff in der Schlagebene
        for sgn in (1, -1):
            u = n * sgn
            pts = [(0.0, -0.09), (0.3, -0.24), (0.4, -0.1), (0.42, 0.0), (0.4, 0.1), (0.3, 0.24), (0.0, 0.09)]
            f.platte([top + u * a + d * b for a, b in pts], Vector((1, 0, 0)), 0.05, steel, 'fore.' + side)
            f.platte([top + u * (a + 0.015) + d * b for a, b in ((0.3, -0.25), (0.42, -0.1), (0.44, 0.0), (0.42, 0.1), (0.3, 0.25), (0.38, 0.0))],
                     Vector((1, 0, 0)), 0.06, rune, 'fore.' + side)
        f.box((0.08, 0.12, 0.2), tuple(top), steel, 'fore.' + side, rot=(-rx, 0, 0), bevel=0.02)
        f.cyl(0.05, 0.0, 0.16, tuple(hx + d * 1.02), steel, 'fore.' + side, rot=(-rx, 0, 0), seg=5)
        f.ball(0.05, tuple(top + Vector((0.05, 0, 0))), rune, 'fore.' + side, seg=6, rings=4)
        f.ball(0.05, tuple(top - Vector((0.05, 0, 0))), rune, 'fore.' + side, seg=6, rings=4)
        # Beine: Hose, Fellstiefel
        f.glied('thigh.' + side, 0.17, 0.14, dark, ext=(0.06, 0.02))
        f.glied('shin.' + side, 0.13, 0.12, leather)
        k, ft = f.J['shin.' + side]
        f.cyl(0.17, 0.16, 0.2, (ft.x, ft.y, 0.32), fur, 'shin.' + side, seg=8)
        f.box((0.24, 0.42, 0.18), (ft.x, ft.y + 0.08, 0.09), leather, 'shin.' + side, bevel=0.04)
    f.spiegel(arm)
    return f


# --- König Unrat: kleiner dicker Rattenkönig ------------------------------
def ratte(f, loc, rz, bone, s=1.0, rx=0.0):
    fell, rosa, auge = M('#6e625a', 0.9), M('#d99a9a', 0.8), M('#ff4030', 0.3, 0.0, 4.0)
    q = Euler((math.radians(rx), 0, math.radians(rz))).to_matrix()
    p = Vector(loc)
    def at(v):
        return tuple(p + q @ (Vector(v) * s))
    f.ball(0.13 * s, at((0, 0, 0)), fell, bone, scale=(0.6, 1.0, 0.55), rot=(rx, 0, rz), seg=8, rings=5)
    f.cyl(0.07 * s, 0.0, 0.16 * s, at((0, 0.17, 0.0)), fell, bone, rot=(-90 + rx, 0, rz), seg=6)
    f.ball(0.022 * s, at((0, 0.25, 0)), rosa, bone, seg=5, rings=3)
    for e in (1, -1):
        f.ball(0.035 * s, at((0.05 * e, 0.1, 0.07)), rosa, bone, scale=(1, 0.4, 1), rot=(rx, 0, rz), seg=6, rings=4)
        f.ball(0.016 * s, at((0.035 * e, 0.17, 0.035)), auge, bone, seg=4, rings=3)
    f.stab(at((0, -0.12, 0)), at((0.04, -0.3, 0.05)), 0.018 * s, 0.012 * s, rosa, bone, seg=4)
    f.stab(at((0.04, -0.3, 0.05)), at((-0.02, -0.42, 0.14)), 0.012 * s, 0.004 * s, rosa, bone, seg=4)


def unrat():
    f = Figur('unrat')
    mensch(f, hip=0.62, neck=1.3, head_top=1.8, sh=(0.52, 0, 1.18), elbow=(0.7, 0.06, 0.86),
           hand=(0.72, 0.28, 0.66), knee=(0.24, 0.04, 0.34), foot=(0.24, 0, 0.08), hip_x=0.24)
    skin, cloak, shirt = M('#b7b98e', 0.8), M('#4e5a36', 0.95), M('#7a3a2a', 0.9)
    rag, tin, rust = M('#8a7a5a', 0.95), M('#a8a8b0', 0.4, 0.75), M('#8a4a2a', 0.8, 0.5)
    wood, tooth, eye = M('#5a4028', 0.9), M('#efe6c8', 0.5), M('#ffd040', 0.3, 0.0, 4.0)
    ruby, nose = M('#d0203a', 0.2, 0.0, 1.5), M('#c88a7a', 0.8)
    # Bauch und Hemd mit Flicken
    f.ball(0.6, (0, 0.06, 0.9), shirt, 'chest', scale=(1.0, 0.92, 0.88), seg=12, rings=8)
    f.box((0.2, 0.04, 0.18), (0.18, 0.6, 0.98), rag, 'chest', rot=(0, 12, 0), bevel=0.01)
    f.box((0.14, 0.04, 0.14), (-0.22, 0.56, 0.76), cloak, 'chest', rot=(0, -20, 0), bevel=0.01)
    f.cyl(0.58, 0.58, 0.1, (0, 0.04, 0.66), wood, 'hips', seg=12)
    f.box((0.14, 0.05, 0.12), (0, 0.6, 0.66), tin, 'hips', bevel=0.015)
    # Lumpenmantel (hinten offen nach vorn) mit Fellkragen
    v = f.cyl(0.78, 0.5, 1.08, (0, -0.16, 0.66), cloak, 'chest', seg=12, scale=(1.0, 0.85, 1.0))
    f.jag(v, 0.22, seed=3)
    f.cyl(0.58, 0.5, 0.22, (0, -0.06, 1.2), rag, 'chest', seg=10)
    for k in range(9):
        a = math.radians(-40 + k * 280 / 8 + 90)
        f.ball(0.12, (math.cos(a) * 0.52, -0.06 + math.sin(a) * 0.46 - 0.04, 1.3), rag, 'chest', seg=6, rings=4)
    # Kopf: fahles Gesicht, Knollennase, Nagezähne, Bartstoppeln
    f.ball(0.3, (0, 0.1, 1.48), skin, 'head', scale=(1.05, 1.0, 0.98), seg=10)
    f.ball(0.11, (0, 0.38, 1.46), nose, 'head', scale=(0.9, 1.2, 1.0), seg=8, rings=5)
    f.ball(0.04, (0.1, 0.34, 1.57), eye, 'head', seg=6, rings=4)
    f.ball(0.04, (-0.1, 0.34, 1.57), eye, 'head', seg=6, rings=4)
    f.box((0.12, 0.05, 0.035), (0.11, 0.35, 1.63), wood, 'head', rot=(0, -15, 0))
    f.box((0.12, 0.05, 0.035), (-0.11, 0.35, 1.63), wood, 'head', rot=(0, 15, 0))
    f.box((0.05, 0.03, 0.09), (0.03, 0.37, 1.33), tooth, 'head')
    f.box((0.05, 0.03, 0.09), (-0.03, 0.37, 1.33), tooth, 'head')
    bv = f.cyl(0.22, 0.12, 0.22, (0, 0.24, 1.27), rag, 'head', rot=(20, 0, 0), seg=8)
    f.jag(bv, 0.06, seed=5)
    for s in (1, -1):
        f.ball(0.09, (0.29 * s, 0.08, 1.52), skin, 'head', scale=(0.5, 1, 1.3), seg=6, rings=4)
    # Blechkrone: verbeult, ungleiche Zacken, ein Rubin
    f.cyl(0.25, 0.27, 0.16, (0, 0.08, 1.76), tin, 'head', rot=(0, 6, 0), seg=10)
    rnd = random.Random(7)
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        h = 0.14 + rnd.random() * 0.12
        f.cyl(0.07, 0.0, h, (math.cos(a) * 0.24, 0.08 + math.sin(a) * 0.24, 1.84 + h / 2 - 0.02), tin, 'head',
              rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), 0), seg=4)
    f.ball(0.05, (0, 0.34, 1.77), ruby, 'head', scale=(1, 0.6, 1), seg=6, rings=4)
    # Arme: dicke Ärmel, Hände; rechts das Szepter (Kanaldeckel auf krummem Stock)
    def arm(s, side):
        f.glied('arm.' + side, 0.18, 0.15, cloak, ext=(0.05, 0))
        f.glied('fore.' + side, 0.15, 0.11, rag)
        f.ball(0.12, f.J['fore.' + side][1], skin, 'fore.' + side, seg=8, rings=5)
        f.glied('thigh.' + side, 0.16, 0.13, rag, ext=(0.05, 0.02))
        f.glied('shin.' + side, 0.13, 0.12, rag)
        ft = f.J['shin.' + side][1]
        f.box((0.24, 0.36, 0.14), (ft.x, ft.y + 0.07, 0.07), wood, 'shin.' + side, bevel=0.04)
    f.spiegel(arm)
    h = f.J['fore.R'][1]
    f.stab((h.x, h.y, h.z - 0.55), (h.x + 0.02, h.y + 0.04, h.z + 0.05), 0.04, 0.045, wood, 'fore.R', seg=6)
    f.stab((h.x + 0.02, h.y + 0.04, h.z + 0.05), (h.x - 0.04, h.y + 0.02, h.z + 0.62), 0.045, 0.04, wood, 'fore.R', seg=6)
    top = Vector((h.x - 0.04, h.y + 0.02, h.z + 0.72))
    f.cyl(0.2, 0.2, 0.05, tuple(top), rust, 'fore.R', rot=(90, 0, 0), seg=10)
    for k in (-1, 0, 1):
        f.box((0.04, 0.07, 0.34), (top.x + k * 0.09, top.y, top.z), M('#3a2a20', 0.9), 'fore.R')
    f.cyl(0.08, 0.1, 0.06, (top.x, top.y, top.z + 0.22), tin, 'fore.R', seg=6)
    for k in range(4):
        a = k * math.tau / 4
        f.cyl(0.03, 0.0, 0.08, (top.x + math.cos(a) * 0.07, top.y + math.sin(a) * 0.07, top.z + 0.28), tin, 'fore.R', seg=4)
    # Ratten: Krone, Schulter, Mantel hinten, Bauch, Szepter
    ratte(f, (0.06, 0.02, 2.0), 60, 'head', 0.9, rx=-10)
    ratte(f, (0.56, 0.0, 1.38), 160, 'chest', 1.0)
    ratte(f, (-0.3, -0.62, 0.9), 200, 'chest', 1.0, rx=-60)
    ratte(f, (0.42, 0.42, 0.78), 40, 'chest', 0.9, rx=40)
    ratte(f, (top.x + 0.06, top.y, top.z + 0.06), -80, 'fore.R', 0.8)
    return f


# --- Oberschwester Vesna: hagere Feldärztin mit Pestmaske -----------------
def vesna():
    f = Figur('vesna')
    f.bone('root', (0, 0, 0), (0, 0, 0.3))
    f.bone('hips', (0, 0, 1.05), (0, 0, 1.17), 'root')
    f.bone('chest', (0, 0, 1.17), (0, 0, 1.66), 'hips')
    f.bone('head', (0, 0, 1.66), (0, 0, 2.1), 'chest')
    # Gewehr im Anschlag: rechte Hand am Abzug, linke stützt den Lauf
    f.bone('arm.L', (0.3, 0, 1.58), (0.32, 0.2, 1.24), 'chest')
    f.bone('fore.L', (0.32, 0.2, 1.24), (0.1, 0.6, 1.24), 'arm.L')
    f.bone('arm.R', (-0.3, 0, 1.58), (-0.36, 0.06, 1.22), 'chest')
    f.bone('fore.R', (-0.36, 0.06, 1.22), (-0.18, 0.36, 1.2), 'arm.R')
    for s, side in ((1, 'L'), (-1, 'R')):
        f.bone('thigh.' + side, (0.13 * s, 0, 1.05), (0.14 * s, 0.03, 0.56), 'hips')
        f.bone('shin.' + side, (0.14 * s, 0.03, 0.56), (0.14 * s, 0, 0.1), 'thigh.' + side)
    coat, coat2 = M('#363a44', 0.85), M('#2a2d35', 0.9)
    white, red = M('#e8e2d4', 0.7), M('#c8202a', 0.6)
    mask, brass = M('#ece4d0', 0.45), M('#c9a040', 0.35, 0.85)
    lens, glove = M('#7dff9a', 0.1, 0.0, 5.0), M('#1e1e22', 0.6)
    steel, wood = M('#8a9aa8', 0.35, 0.8), M('#5a3a22', 0.8)
    fluid = M('#57ff8a', 0.15, 0.0, 3.5)
    # Mantel: Oberteil, Schoß an der Hüfte, lange Schöße an den Beinen
    f.cyl(0.24, 0.3, 0.52, (0, 0, 1.4), coat, 'chest', seg=10)
    f.cyl(0.3, 0.33, 0.2, (0, 0, 1.6), coat, 'chest', seg=10)
    f.cyl(0.36, 0.26, 0.3, (0, 0, 1.0), coat, 'hips', seg=10)
    def schoss(s, side):
        v = f.cyl(0.26, 0.2, 0.76, (0.15 * s, -0.02, 0.6), coat, 'thigh.' + side, seg=8, scale=(1.0, 1.25, 1.0))
        f.jag(v, 0.06, seed=2 + s)
    f.spiegel(schoss)
    f.box((0.03, 0.03, 0.9), (0, -0.33, 0.62), coat2, 'hips')
    # Schürze mit rotem Kreuz, Gürtel mit Ampullen
    f.box((0.34, 0.04, 0.9), (0, 0.3, 1.02), white, 'hips', rot=(-6, 0, 0), bevel=0.01)
    f.box((0.36, 0.04, 0.36), (0, 0.27, 1.45), white, 'chest', bevel=0.01)
    f.box((0.06, 0.02, 0.2), (0, 0.3, 1.47), red, 'chest')
    f.box((0.2, 0.02, 0.06), (0, 0.3, 1.47), red, 'chest')
    f.cyl(0.32, 0.32, 0.07, (0, 0, 1.17), M('#4a3020', 0.8), 'hips', seg=10)
    for k, x in enumerate((-0.24, -0.14, 0.18, 0.27)):
        a = math.atan2(0.3, x)
        f.cyl(0.035, 0.035, 0.13, (x, math.sqrt(max(0.0, 0.33 ** 2 - x * x)) * 0.95, 1.13), fluid, 'hips', seg=6)
    # Kopf: Kapuze, Pestmaske mit Schnabel, Schutzbrille, Schwesternhaube
    f.cyl(0.11, 0.12, 0.1, (0, 0, 1.7), coat2, 'head', seg=8)
    f.ball(0.25, (0, -0.02, 1.88), coat2, 'head', scale=(1.0, 1.05, 1.08), seg=10)
    f.ball(0.2, (0, 0.08, 1.86), mask, 'head', scale=(0.95, 0.9, 1.0), seg=10)
    f.cyl(0.11, 0.0, 0.46, (0, 0.38, 1.76), mask, 'head', rot=(-75, 0, 0), seg=8, scale=(0.8, 1, 1))
    f.cyl(0.115, 0.115, 0.03, (0, 0.24, 1.8), brass, 'head', rot=(-75, 0, 0), seg=8)
    for s in (1, -1):
        f.cyl(0.07, 0.07, 0.06, (0.08 * s, 0.24, 1.92), brass, 'head', rot=(-90, 0, 0), seg=8)
        f.cyl(0.055, 0.055, 0.02, (0.08 * s, 0.275, 1.92), lens, 'head', rot=(-90, 0, 0), seg=8)
    f.box((0.3, 0.2, 0.12), (0, 0.02, 2.1), white, 'head', rot=(-12, 0, 0), bevel=0.02)
    f.box((0.04, 0.01, 0.08), (0, 0.13, 2.11), red, 'head', rot=(-12, 0, 0))
    f.box((0.08, 0.01, 0.03), (0, 0.13, 2.11), red, 'head', rot=(-12, 0, 0))
    # Arme (Ärmel, Handschuhe)
    def arm(s, side):
        f.ball(0.13, f.J['arm.' + side][0], coat, 'chest', seg=8, rings=5)
        f.glied('arm.' + side, 0.1, 0.09, coat)
        f.glied('fore.' + side, 0.09, 0.075, coat, ext=(0.03, 0))
        f.ball(0.07, f.J['fore.' + side][1], glove, 'fore.' + side, seg=8, rings=5)
        f.glied('thigh.' + side, 0.1, 0.085, coat2)
        f.glied('shin.' + side, 0.085, 0.08, glove)
        ft = f.J['shin.' + side][1]
        f.box((0.16, 0.32, 0.16), (ft.x, ft.y + 0.05, 0.08), glove, 'shin.' + side, bevel=0.03)
    f.spiegel(arm)
    # Spritzengewehr (an der rechten Hand): Kolben, Gehäuse, Glaskolben, Lauf, Nadel
    g = Vector(f.J['fore.R'][1])
    gy = lambda dy, dz=0.0, dx=0.12: (g.x + dx, g.y + dy, g.z + dz)
    f.box((0.1, 0.36, 0.16), gy(-0.32, -0.02), wood, 'fore.R', bevel=0.02)
    f.box((0.12, 0.4, 0.14), gy(0.05, 0.02), steel, 'fore.R', bevel=0.02)
    f.cyl(0.06, 0.06, 0.4, gy(0.12, 0.13), fluid, 'fore.R', rot=(-90, 0, 0), seg=8)
    f.cyl(0.07, 0.07, 0.03, gy(-0.08, 0.13), brass, 'fore.R', rot=(-90, 0, 0), seg=8)
    f.cyl(0.07, 0.07, 0.03, gy(0.32, 0.13), brass, 'fore.R', rot=(-90, 0, 0), seg=8)
    f.cyl(0.035, 0.03, 0.5, gy(0.5, 0.02), steel, 'fore.R', rot=(-90, 0, 0), seg=6)
    f.cyl(0.02, 0.0, 0.16, gy(0.82, 0.02), M('#e0e8f0', 0.2, 0.9), 'fore.R', rot=(-90, 0, 0), seg=5)
    f.box((0.04, 0.06, 0.1), gy(-0.02, -0.1), steel, 'fore.R')
    return f


# --- Zix Funkenkurbel: Goblin im Laufwerk mit Kranarm ---------------------
def zix():
    f = Figur('zix')
    f.bone('root', (0, 0, 0), (0, 0, 0.3))
    f.bone('hips', (0, 0, 0.92), (0, 0, 1.05), 'root')
    f.bone('chest', (0, 0, 1.05), (0, 0, 1.4), 'hips')      # Kanzel
    f.bone('head', (0, 0, 1.4), (0, 0, 1.8), 'chest')      # Goblin
    f.bone('arm.R', (-0.52, 0.0, 1.3), (-0.72, 0.3, 1.66), 'chest')   # Kranarm
    f.bone('fore.R', (-0.72, 0.3, 1.66), (-0.74, 0.86, 1.3), 'arm.R')
    f.bone('arm.L', (0.52, 0.05, 1.18), (0.66, 0.32, 1.12), 'chest')  # Funkenpistole
    f.bone('fore.L', (0.66, 0.32, 1.12), (0.66, 0.74, 1.12), 'arm.L')
    for s, side in ((1, 'L'), (-1, 'R')):
        f.bone('thigh.' + side, (0.36 * s, 0, 0.92), (0.42 * s, 0.26, 0.52), 'hips')
        f.bone('shin.' + side, (0.42 * s, 0.26, 0.52), (0.42 * s, -0.04, 0.1), 'thigh.' + side)
    rust, rust2 = M('#b8642e', 0.6, 0.55), M('#7a4a2a', 0.7, 0.5)
    iron, dark = M('#5a5a60', 0.45, 0.8), M('#2a2a2e', 0.7, 0.5)
    yel, blk = M('#f0c020', 0.6), M('#1a1a1a', 0.7)
    green, leather = M('#7ab04a', 0.7), M('#6a4020', 0.8)
    brass, glow = M('#d0a040', 0.3, 0.9), M('#ffb040', 0.3, 0.0, 6.0)
    lens, red = M('#ff9030', 0.1, 0.0, 3.0), M('#ff3020', 0.3, 0.0, 6.0)
    tooth, eye = M('#f0ead0', 0.5), M('#fff060', 0.3, 0.0, 3.0)
    # Kanzel (Wanne) mit Warnstreifen, Nieten, Auspuff, Antenne
    f.box((0.96, 0.84, 0.46), (0, 0, 1.12), rust, 'chest', bevel=0.07)
    f.box((1.02, 0.9, 0.08), (0, 0, 1.36), rust2, 'chest', bevel=0.03)
    for k in range(5):
        f.box((0.1, 0.03, 0.2), (-0.36 + k * 0.18, 0.43, 1.1), yel if k % 2 == 0 else blk, 'chest', rot=(0, 30, 0))
    for x in (-0.42, 0.42):
        for z in (0.95, 1.27):
            f.ball(0.025, (x, 0.43, z), iron, 'chest', seg=5, rings=3)
    for s in (1, -1):
        f.cyl(0.07, 0.07, 0.6, (0.22 * s, -0.42, 1.42), iron, 'chest', seg=8)
        f.cyl(0.09, 0.09, 0.06, (0.22 * s, -0.42, 1.73), dark, 'chest', seg=8)
    f.stab((-0.36, -0.3, 1.38), (-0.4, -0.36, 2.0), 0.015, 0.01, iron, 'chest', seg=4)
    f.ball(0.04, (-0.4, -0.36, 2.02), red, 'chest', seg=6, rings=4)
    f.cyl(0.5, 0.42, 0.18, (0, 0, 0.87), dark, 'hips', seg=10)
    f.box((0.3, 0.2, 0.22), (0.5, -0.1, 0.98), M('#b03020', 0.6, 0.3), 'chest', bevel=0.03)  # Werkzeugkiste
    f.box((0.06, 0.4, 0.04), (0.66, -0.02, 1.0), iron, 'chest', rot=(0, 0, 10))                 # Schraubenschlüssel
    f.cyl(0.07, 0.07, 0.04, (0.66, 0.2, 1.0), iron, 'chest', rot=(0, 90, 0), seg=6)
    # Hebel
    for s in (1, -1):
        f.stab((0.18 * s, 0.2, 1.36), (0.2 * s, 0.26, 1.58), 0.02, 0.02, iron, 'chest', seg=4)
        f.ball(0.04, (0.2 * s, 0.26, 1.6), M('#c02020', 0.5), 'chest', seg=6, rings=4)
    # Goblin: Rumpf, Kopf mit langen Ohren, Fliegermütze, Brille, Grinsen
    f.ball(0.2, (0, -0.05, 1.46), leather, 'head', scale=(1.1, 0.9, 1.0), seg=8)
    f.ball(0.22, (0, 0.02, 1.7), green, 'head', scale=(1.0, 0.95, 0.95), seg=10)
    f.ball(0.23, (0, -0.02, 1.76), leather, 'head', scale=(1.0, 1.0, 0.7), seg=10, rings=6)
    for s in (1, -1):
        f.cyl(0.08, 0.0, 0.42, (0.36 * s, 0.0, 1.76), green, 'head', rot=(0, 72 * s, 0), seg=6, scale=(1, 0.5, 1))
        f.cyl(0.06, 0.06, 0.05, (0.08 * s, 0.17, 1.82), brass, 'head', rot=(-70, 0, 0), seg=8)
        f.cyl(0.045, 0.045, 0.02, (0.08 * s, 0.195, 1.83), lens, 'head', rot=(-70, 0, 0), seg=8)
        f.ball(0.035, (0.075 * s, 0.19, 1.71), eye, 'head', seg=6, rings=4)
    f.box((0.3, 0.04, 0.03), (0, 0.13, 1.87), dark, 'head', rot=(-20, 0, 0))
    f.cyl(0.05, 0.0, 0.22, (0, 0.3, 1.67), green, 'head', rot=(-80, 0, 0), seg=6)
    f.box((0.18, 0.03, 0.05), (0, 0.2, 1.59), tooth, 'head', rot=(8, 0, 0))
    # Kranarm mit Hydraulik und Greifer
    f.glied('arm.R', 0.08, 0.07, yel, ext=(0.06, 0.04))
    f.glied('fore.R', 0.07, 0.06, yel, ext=(0.04, 0))
    a0, a1 = f.J['arm.R']
    f.stab(a0 + Vector((0, 0.05, -0.12)), a1 + Vector((0, -0.05, -0.12)), 0.035, 0.035, iron, 'arm.R', seg=6)
    f.ball(0.1, tuple(a0), dark, 'chest', seg=8, rings=5)
    f.ball(0.09, tuple(a1), dark, 'arm.R', seg=8, rings=5)
    c = f.J['fore.R'][1]
    f.cyl(0.1, 0.1, 0.1, tuple(c), dark, 'fore.R', seg=8)
    for k in range(3):
        a = k * math.tau / 3
        f.cyl(0.04, 0.0, 0.24, (c.x + math.cos(a) * 0.07, c.y + math.sin(a) * 0.05, c.z - 0.15), iron, 'fore.R',
              rot=(math.sin(a) * 20, -math.cos(a) * 20, 0), seg=4)
    # Funkenpistole
    f.glied('arm.L', 0.06, 0.06, iron, ext=(0.04, 0))
    p0, p1 = f.J['fore.L']
    f.stab(p0, p1, 0.08, 0.06, rust2, 'fore.L', seg=8)
    f.stab(p1, p1 + Vector((0, 0.1, 0)), 0.03, 0.03, brass, 'fore.L', seg=6)
    for k in range(3):
        f.cyl(0.075, 0.075, 0.02, tuple(p0 + (p1 - p0) * (0.3 + k * 0.2)), brass, 'fore.L', rot=(-90, 0, 0), seg=8)
    f.ball(0.06, tuple(p1 + Vector((0, 0.14, 0))), glow, 'fore.L', seg=8, rings=5)
    # Laufbeine (Knie vorn), breite Füße mit drei Zehen
    def bein(s, side):
        f.glied('thigh.' + side, 0.1, 0.08, rust2, ext=(0.05, 0.03))
        f.glied('shin.' + side, 0.08, 0.07, iron, ext=(0.03, 0))
        k = f.J['shin.' + side][0]
        f.ball(0.11, tuple(k), dark, 'thigh.' + side, seg=8, rings=5)
        h0 = f.J['thigh.' + side][0]
        f.stab(h0 + Vector((0, -0.1, -0.05)), k + Vector((0, -0.12, -0.12)), 0.03, 0.03, brass, 'thigh.' + side, seg=6)
        ft = f.J['shin.' + side][1]
        f.box((0.22, 0.2, 0.08), (ft.x, ft.y, 0.06), dark, 'shin.' + side, bevel=0.02)
        for dx, rz in ((-0.08, 18), (0, 0), (0.08, -18)):
            f.box((0.06, 0.22, 0.06), (ft.x + dx, ft.y + 0.17, 0.04), iron, 'shin.' + side, rot=(0, 0, rz), bevel=0.015)
    f.spiegel(bein)
    return f


BAU = {'torvik': torvik, 'unrat': unrat, 'vesna': vesna, 'zix': zix}


# --- Animationen ------------------------------------------------------------
class Anim:
    def __init__(self, rig):
        self.rig = rig
        self.pb = rig.pose.bones
        for p in self.pb:
            p.rotation_mode = 'QUATERNION'
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
        rig.animation_data_create()

    def key(self, frame, poses, loc=None):
        for p in self.pb:
            p.rotation_quaternion = Quaternion()
            p.location = Vector()
        for name, rots in poses.items():
            if name not in self.pb:
                continue
            q = Quaternion()
            for axis, deg in rots:
                q = Quaternion(Vector(axis), math.radians(deg)) @ q
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
        for fr, poses, loc in frames:
            self.key(fr, poses, loc)
        track = self.rig.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, int(frames[0][0]), act)
        self.rig.animation_data.action = None


def merge(*ps):
    out = {}
    for p in ps:
        for k, v in p.items():
            out[k] = out.get(k, []) + list(v)
    return out


# Je Held: wie stark die Arme beim Laufen pendeln, Grundhaltung, Angriff und Zauber.
STIL = {
    'torvik': {'swing': 22, 'step': 34, 'bob': 0.05, 'lean': 8},
    'unrat': {'swing': 30, 'step': 30, 'bob': 0.06, 'lean': 4, 'waddle': 8},
    'vesna': {'swing': 4, 'step': 30, 'bob': 0.035, 'lean': 6},
    'zix': {'swing': 0, 'step': 30, 'bob': 0.07, 'lean': 3, 'mech': True},
}


def animieren(hid, rig):
    st = STIL[hid]
    A = Anim(rig)
    # Ruhe: Atmen (2 s)
    br = {'chest': [(X, -2.5)], 'head': [(X, 2)], 'arm.L': [(Y, -3)], 'arm.R': [(Y, 3)]}
    if st.get('mech'):
        br = {'chest': [(X, -2)], 'head': [(Z, 8)], 'arm.R': [(X, 5)]}
    A.action('idle', [(1, {}, None), (25, br, (0, 0, -0.012)), (49, {}, None)])
    # Laufen: 16 Bilder je Doppelschritt
    N, S = 8, 16
    frames = []
    for i in range(N + 1):
        w = i / N * math.tau
        s, c = math.sin(w), abs(math.cos(w))
        knee_l = max(0.0, -math.sin(w + 0.9)) * 50
        knee_r = max(0.0, math.sin(w + 0.9)) * 50
        sgn = -1 if st.get('mech') else 1   # Knie vorn: Unterschenkel knickt andersherum
        p = {'thigh.L': [(X, st['step'] * s)], 'thigh.R': [(X, -st['step'] * s)],
             'shin.L': [(X, -knee_l * sgn)], 'shin.R': [(X, -knee_r * sgn)],
             'arm.L': [(X, -st['swing'] * s)], 'arm.R': [(X, st['swing'] * s)],
             'hips': [(Z, -6 * s), (X, st['lean'])], 'chest': [(Z, 9 * s)], 'head': [(Z, -4 * s), (X, -st['lean'] * 0.6)]}
        if st.get('waddle'):
            p['hips'].append((Y, st['waddle'] * s))
        if st.get('mech'):
            p['chest'] = [(X, 4 * c), (Y, 3 * s)]
            p['head'] = [(Y, -5 * s)]
            p['arm.R'] = [(X, 6 * s)]
            p['arm.L'] = [(X, -4 * s)]
        frames.append((1 + i * S / N, p, (0, 0, st['bob'] * (c - 0.5))))
    A.action('run', frames)
    # Angriff und Zauber je Held
    if hid == 'torvik':
        up = {'arm.L': [(X, 150), (Y, -15)], 'arm.R': [(X, 150), (Y, 15)], 'fore.L': [(X, 30)], 'fore.R': [(X, 30)],
              'chest': [(X, -12)], 'head': [(X, -6)]}
        down = {'arm.L': [(X, 55), (Y, 8)], 'arm.R': [(X, 55), (Y, -8)], 'fore.L': [(X, -20)], 'fore.R': [(X, -20)],
                'chest': [(X, 18)], 'hips': [(X, 6)], 'thigh.L': [(X, 25)], 'shin.L': [(X, -25)], 'thigh.R': [(X, -15)]}
        A.action('attack', [(1, {}, None), (6, up, (0, 0, 0.04)), (10, down, (0, 0.08, -0.06)), (13, down, (0, 0.08, -0.06)), (20, {}, None)])
        cast = {'arm.L': [(Y, -150)], 'arm.R': [(Y, 150)], 'chest': [(X, -14)], 'head': [(X, -20)]}
        A.action('cast', [(1, {}, None), (7, cast, (0, 0, 0.06)), (12, cast, (0, 0, 0.08)),
                          (16, merge(down, {'arm.L': [(Y, -30)], 'arm.R': [(Y, 30)]}), (0, 0, -0.04)), (24, {}, None)])
    elif hid == 'unrat':
        up = {'arm.R': [(X, 130), (Y, 20)], 'fore.R': [(X, 20)], 'chest': [(X, -10), (Z, -15)], 'arm.L': [(Y, -30)]}
        down = {'arm.R': [(X, 40), (Y, -10)], 'fore.R': [(X, -10)], 'chest': [(X, 16), (Z, 12)], 'arm.L': [(Y, -20), (X, -20)]}
        A.action('attack', [(1, {}, None), (6, up, (0, 0, 0.03)), (10, down, (0, 0.05, -0.05)), (13, down, (0, 0.05, -0.05)), (20, {}, None)])
        wind = {'arm.L': [(X, -40), (Y, -40)], 'chest': [(Z, 25), (X, -8)], 'arm.R': [(X, 40)]}
        throw = {'arm.L': [(X, 140)], 'fore.L': [(X, 20)], 'chest': [(Z, -20), (X, 10)], 'arm.R': [(X, -10)]}
        A.action('cast', [(1, {}, None), (7, wind, None), (11, throw, (0, 0.04, 0.02)), (14, throw, None), (22, {}, None)])
    elif hid == 'vesna':
        aim = {'chest': [(X, 3)], 'head': [(X, 4)]}
        kick = {'chest': [(X, -9)], 'head': [(X, -6)], 'arm.R': [(X, 12)], 'arm.L': [(X, 12)]}
        A.action('attack', [(1, aim, None), (3, kick, (0, -0.06, 0.0)), (8, aim, None), (12, aim, None)])
        lift = {'arm.L': [(X, 25), (Y, -70)], 'fore.L': [(Y, -30)], 'chest': [(X, -6), (Z, 10)], 'head': [(X, -10)],
                'arm.R': [(X, 30)], 'fore.R': [(X, 20)]}
        A.action('cast', [(1, {}, None), (6, lift, (0, 0, 0.03)), (12, lift, (0, 0, 0.04)), (14, kick, (0, -0.05, 0)), (22, {}, None)])
    elif hid == 'zix':
        A.action('attack', [(1, {}, None), (3, {'arm.L': [(Z, -8)], 'chest': [(X, -4)]}, (0, -0.03, 0)), (8, {}, None)])
        up = {'arm.R': [(X, -35)], 'fore.R': [(X, -40)], 'chest': [(X, -6)], 'head': [(X, -10)]}
        set_ = {'arm.R': [(X, 30)], 'fore.R': [(X, 25)], 'chest': [(X, 10)], 'hips': [(X, 4)]}
        A.action('cast', [(1, {}, None), (7, up, (0, 0, 0.05)), (12, set_, (0, 0, -0.06)), (15, set_, (0, 0, -0.06)), (24, {}, None)])
    # Tod: einknicken, nach hinten umfallen
    if st.get('mech'):
        A.action('death', [(1, {}, None),
                           (8, {'thigh.L': [(X, 40)], 'thigh.R': [(X, 30)], 'shin.L': [(X, 40)], 'shin.R': [(X, 50)],
                                'chest': [(X, 15)], 'head': [(Z, 40)], 'arm.R': [(X, 60)]}, (0, 0, -0.3)),
                           (16, {'root': [(Y, 25)], 'thigh.L': [(X, 70)], 'thigh.R': [(X, 60)], 'shin.L': [(X, 70)],
                                 'shin.R': [(X, 80)], 'chest': [(X, 20)], 'head': [(X, 50)], 'arm.R': [(X, 80)]}, (0, 0, -0.5)),
                           (24, {'root': [(Y, 28)], 'thigh.L': [(X, 70)], 'thigh.R': [(X, 60)], 'shin.L': [(X, 70)],
                                 'shin.R': [(X, 80)], 'chest': [(X, 20)], 'head': [(X, 55)], 'arm.R': [(X, 85)]}, (0, 0, -0.5))])
    else:
        A.action('death', [(1, {}, None),
                           (6, {'chest': [(X, -14)], 'head': [(X, -20)], 'arm.L': [(Y, -60)], 'arm.R': [(Y, 60)],
                                'thigh.L': [(X, 20)], 'shin.L': [(X, -40)]}, (0, 0, 0.0)),
                           (14, {'root': [(X, -70)], 'arm.L': [(Y, -90)], 'arm.R': [(Y, 90)], 'thigh.L': [(X, 30)],
                                 'shin.L': [(X, -30)], 'head': [(X, -10)]}, (0, -0.1, 0.12)),
                           (18, {'root': [(X, -90)], 'arm.L': [(Y, -40)], 'arm.R': [(Y, 40)], 'thigh.L': [(X, 20)],
                                 'head': [(X, -15)]}, (0, -0.2, 0.2)),
                           (24, {'root': [(X, -88)], 'arm.L': [(Y, -35)], 'arm.R': [(Y, 35)], 'thigh.L': [(X, 15)],
                                 'head': [(X, -20)]}, (0, -0.2, 0.2))])
    for a in bpy.data.actions:
        for fc in getattr(a, 'fcurves', []):
            for k in fc.keyframe_points:
                k.interpolation = 'BEZIER'


# --- Bauen, exportieren --------------------------------------------------------
gebaut = []
for hid, fn in BAU.items():
    if NUR and hid not in NUR:
        continue
    f = fn()
    rig = f.bauen()
    animieren(hid, rig)
    for o in bpy.context.scene.objects:
        o.select_set(o in (rig, f.ob))
    bpy.context.view_layer.objects.active = rig
    dst = os.path.join(OUT, hid + '.glb')
    bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='NLA_TRACKS', export_skins=True, export_yup=True,
                              export_apply=False, export_nla_strips_merged_animation_name='x')
    print('EXPORT', dst, len(f.ob.data.polygons), 'Flächen')
    gebaut.append((hid, rig))


# --- Vorschau (Cycles) ---------------------------------------------------------
def licht_und_kamera(sc, ziel, dist, hoehe, winkel, breite):
    for o in list(sc.objects):
        if o.type in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    a = math.radians(winkel)
    cam.location = (ziel[0] + math.sin(a) * dist, ziel[1] + math.cos(a) * dist, hoehe)
    d = Vector(ziel) - cam.location
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = breite
    sc.camera = cam
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 3.2
    sun.rotation_euler = Euler((math.radians(50), math.radians(10), math.radians(150)))
    sc.collection.objects.link(sun)
    fill = bpy.data.objects.new('fill', bpy.data.lights.new('fill', 'SUN'))
    fill.data.energy = 0.8
    fill.data.color = (0.6, 0.75, 1.0)
    fill.rotation_euler = Euler((math.radians(60), 0, math.radians(-40)))
    sc.collection.objects.link(fill)


def render(path, w, h):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.film_transparent = False
    if not sc.world:
        sc.world = bpy.data.worlds.new('w')
    sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs[0].default_value = (0.05, 0.055, 0.08, 1)
    sc.world.node_tree.nodes['Background'].inputs[1].default_value = 0.8
    sc.view_settings.view_transform = 'Standard'
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('BILD', path)


def boden(sc, size):
    me = bpy.data.meshes.new('boden')
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size)
    bm.to_mesh(me)
    o = bpy.data.objects.new('boden', me)
    me.materials.append(M('#3a4a32', 0.95))
    sc.collection.objects.link(o)


if OPT.get('bild') and gebaut:
    sc = bpy.context.scene
    boden(sc, 12)
    gap = 1.7
    for i, (hid, rig) in enumerate(gebaut):
        rig.location.x = (i - (len(gebaut) - 1) / 2) * gap
    licht_und_kamera(sc, (0, 0, 1.0), 6.2 + len(gebaut) * 0.6, 3.2, 18, 40)
    render(OPT['bild'], 1600, 800)

if OPT.get('posen') and gebaut:
    # Je Held eine Reihe: Ruhe, Laufen (2 Bilder), Angriff (Höhepunkt), Zauber, Tod.
    # Jede Kopie hält über einen NLA-Streifen ein festes Bild ihrer Aktion.
    sc = bpy.context.scene
    if 'boden' not in sc.objects:
        boden(sc, 30)
    posen = [('idle', 1), ('run', 5), ('run', 13), ('attack', 10), ('cast', 9), ('death', 24)]
    gruppe = {}
    for r, (hid, rig) in enumerate(gebaut):
        body0 = [c for c in sc.objects if c.parent == rig and c.type == 'MESH'][0]
        gruppe[hid] = []
        for i, (an, fr) in enumerate(posen):
            o = rig.copy()
            o.data = rig.data
            sc.collection.objects.link(o)
            o.animation_data_clear()
            body = body0.copy()
            body.parent = o
            body.modifiers['skel'].object = o
            sc.collection.objects.link(body)
            gruppe[hid] += [o, body]
            o.location = (-(i - 2.5) * 1.9, -r * 2.6, 0)
            o.animation_data_create()
            tr = o.animation_data.nla_tracks.new()
            st = tr.strips.new(an, 1, bpy.data.actions[rig.name + '_' + an])
            st.action_frame_start = fr
            st.action_frame_end = fr + 0.5
            st.frame_end = 2
            st.extrapolation = 'HOLD'
        rig.hide_render = True
        body0.hide_render = True
    sc.frame_set(1)
    # Ein Bild je Held (Reihe von der Seite schräg vorn), dann untereinander zusammensetzen
    teile = []
    for r, (hid, rig) in enumerate(gebaut):
        for o in sc.objects:
            if o.type in ('MESH', 'ARMATURE') and o.name != 'boden':
                o.hide_render = o not in gruppe[hid]
        licht_und_kamera(sc, (0, -r * 2.6, 0.8), 17, 5.0, 12, 42)
        pfad = OPT['posen'][:-4] + '_' + hid + '.png'
        render(pfad, 1800, 420)
        teile.append(pfad)
    print('POSEN', ' '.join(teile))
