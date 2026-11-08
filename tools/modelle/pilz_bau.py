# Bezirk "Überwuchert" (Spuk-Baukasten nach Art eines verlassenen Hinterhofs): wuchernde Pilzkolonien auf geraden
# Backsteinmauern. Pilze blass creme bis rosa, Hüte glühen lindgelb, moosgrüne leuchtende Sporenflecken an Wänden
# und Boden, glühende Fenster und Runen. Keine Pflanzen, kein Efeu. Eigene Arbeit (CC0), Texturen im Skript erzeugt.
# Aufruf (Blender als Python-Modul bpy, siehe tools/modelle/README.md):
#   <python mit bpy> -I tools/modelle/pilz_bau.py -- <zielordner> [--nur=pilz_einzel,pilz_kiste] [--bild=bogen.png]
# Maße in Godot-Einheiten (1 = eine Towerbreite). Vorderseite der Wandteile zeigt nach Blender -Y (Godot +Z),
# Ursprung jedes Teils auf dem Boden.
import bpy, bmesh, math, sys, os, random
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv and not argv[0].startswith('--') else '/tmp/pilze'
OPT = {a.split('=')[0][2:]: (a.split('=', 1)[1] if '=' in a else '1') for a in argv if a.startswith('--')}
NUR = OPT.get('nur', '').split(',') if OPT.get('nur') else None
os.makedirs(OUT, exist_ok=True)
TMP = os.path.join(OUT, '.tex')
os.makedirs(TMP, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

# Farben aus dem Moodboard
STIEL = '#F7DDAF'     # Stiel creme
HUT_RAND = '#F1D3F9'  # Hutrand und Lamellen rosa
HUT_GLUT = '#DFFF2B'  # Hutoberseite glüht lindgelb
HUT_HELL = '#EAF0A8'  # Grundfarbe der Hutoberseite: blass, das Glühen gibt das Lindgelb
MOOS = '#62982C'
SPOR_GLUT = '#9DFF00'
FENSTER = '#E9FF8C'   # Fensterlicht gelbgrün
RUNE = '#9DFF00'
HOLZ = '#4a3526'
HOLZ_DUNKEL = '#2e2119'
EISEN = '#3b3a40'
DACH = '#4a4446'


def lin(color):
    c = tuple(int(color.strip('#')[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# --- Texturen (numpy, fester Zufall) ------------------------------------------
def _noise(rng, n, scales):
    out = np.zeros((n, n))
    for s, w in scales:
        g = rng.random((s, s))
        g = np.kron(g, np.ones((n // s, n // s)))
        # weich machen
        for _ in range(2):
            g = (g + np.roll(g, 1, 0) + np.roll(g, -1, 0) + np.roll(g, 1, 1) + np.roll(g, -1, 1)) / 5.0
        out += g * w
    return out / sum(w for _, w in scales)


def save_image(name, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.flipud(rgba).astype(np.float32).ravel())
    path = os.path.join(TMP, name + '.png')
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img


def brick_texture():
    """Backstein, eine Kachel = 1 x 1 Einheit: 8 Reihen, je 4 Steine, versetzt; Mörtel, Ruß, Altersflecken."""
    n = 512
    rng = np.random.default_rng(11)
    rows, cols = 8, 4
    rh, cw = n // rows, n // cols
    rgb = np.zeros((n, n, 3))
    base = np.array(lin('#6e3b2c'))
    yy, xx = np.mgrid[0:n, 0:n]
    noise = _noise(rng, n, [(8, 1.0), (32, 0.6), (128, 0.35)])
    for r in range(rows):
        off = (cw // 2) * (r % 2)
        for c in range(cols + 1):
            x0 = c * cw - off
            col = base * rng.uniform(0.7, 1.25) * np.array([1.0, rng.uniform(0.85, 1.1), rng.uniform(0.8, 1.15)])
            if rng.random() < 0.12:
                col = col * 0.6  # rußgeschwärzt
            ys, xs = slice(r * rh, (r + 1) * rh), slice(max(x0, 0), min(x0 + cw, n))
            rgb[ys, xs] = col
    mortar = ((yy % rh) < 4) | (((xx + (cw // 2) * ((yy // rh) % 2)) % cw) < 4)
    rgb[mortar] = np.array(lin('#3b3631'))
    rgb *= (0.75 + 0.5 * noise)[..., None]
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((n, n, 1))], axis=2)
    return save_image('backstein', rgba)


def stone_texture():
    """Grauer Abdeckstein / Sockel."""
    n = 256
    rng = np.random.default_rng(5)
    noise = _noise(rng, n, [(4, 1.0), (16, 0.7), (64, 0.4)])
    rgb = np.array(lin('#7a756d'))[None, None, :] * (0.7 + 0.6 * noise)[..., None]
    yy, xx = np.mgrid[0:n, 0:n]
    rgb[(xx % 128) < 3] *= 0.5
    return save_image('stein', np.concatenate([np.clip(rgb, 0, 1), np.ones((n, n, 1))], axis=2))


def spore_textures():
    """Sporenfleck: Farbe (moosgrün, Alpha = unregelmäßiger Fleck) und Leuchtkarte (glühende Punkte)."""
    n = 256
    rng = np.random.default_rng(23)
    yy, xx = np.mgrid[0:n, 0:n] / n - 0.5
    rad = np.sqrt(xx ** 2 + yy ** 2)
    noise = _noise(rng, n, [(4, 1.0), (8, 0.8), (32, 0.5)])
    blob = np.clip((0.42 - rad) * 6.0 + (noise - 0.5) * 2.2, 0, 1)
    alpha = (blob > 0.35).astype(float)
    moss = np.array(lin(MOOS))
    rgb = moss[None, None, :] * (0.55 + 0.7 * noise)[..., None]
    # hellere Ränder und Flecken
    rgb *= (0.8 + 0.4 * blob)[..., None]
    glow = np.zeros((n, n, 3))
    g = np.array(lin(SPOR_GLUT))
    for _ in range(70):
        cx, cy = rng.integers(0, n, 2)
        if alpha[cy, cx] == 0:
            continue
        r = rng.uniform(1.5, 4.5)
        d = np.sqrt((np.mgrid[0:n, 0:n][1] - cx) ** 2 + (np.mgrid[0:n, 0:n][0] - cy) ** 2)
        k = np.clip(1.0 - d / r, 0, 1)[..., None]
        glow = np.maximum(glow, g * k)
        rgb = np.maximum(rgb, g * k * 0.9)
    farbe = save_image('sporen', np.concatenate([np.clip(rgb, 0, 1), alpha[..., None]], axis=2))
    leucht = save_image('sporen_glut', np.concatenate([np.clip(glow, 0, 1), np.ones((n, n, 1))], axis=2))
    return farbe, leucht


# --- Materialien --------------------------------------------------------------
_mats = {}
def M(color, rough=0.8, metal=0.0, emit=0.0, tex=None, emit_tex=None, alpha=False, glow=None):
    key = (color, glow, rough, metal, emit, tex.name if tex else '', emit_tex.name if emit_tex else '', alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new('m_%s_%d' % (color.strip('#'), len(_mats)))
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*lin(color), 1.0)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if tex is not None:
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = tex
        nt.links.new(t.outputs['Color'], p.inputs['Base Color'])
        if alpha:
            # Rundung = glTF alphaMode MASK (keine Sortierprobleme in Godot)
            r = nt.nodes.new('ShaderNodeMath')
            r.operation = 'ROUND'
            nt.links.new(t.outputs['Alpha'], r.inputs[0])
            nt.links.new(r.outputs[0], p.inputs['Alpha'])
    if emit_tex is not None:
        e = nt.nodes.new('ShaderNodeTexImage')
        e.image = emit_tex
        nt.links.new(e.outputs['Color'], p.inputs['Emission Color'])
        p.inputs['Emission Strength'].default_value = emit
    elif emit > 0:
        p.inputs['Emission Color'].default_value = (*lin(glow or color), 1.0)
        p.inputs['Emission Strength'].default_value = emit
    _mats[key] = m
    return m


TEX = {}
def mats():
    if TEX:
        return TEX
    TEX['backstein'] = brick_texture()
    TEX['stein'] = stone_texture()
    TEX['sporen'], TEX['sporen_glut'] = spore_textures()
    TEX.update({
        'ziegel': M('#ffffff', 0.9, tex=TEX['backstein']),
        'stein_m': M('#ffffff', 0.85, tex=TEX['stein']),
        'stiel': M(STIEL, 0.6),
        'rand': M(HUT_RAND, 0.55),
        'glut': M(HUT_HELL, 0.5, emit=0.5, glow=HUT_GLUT),
        'spore': M('#ffffff', 0.9, emit=0.9, tex=TEX['sporen'], emit_tex=TEX['sporen_glut'], alpha=True),
        'holz': M(HOLZ, 0.85),
        'holz_d': M(HOLZ_DUNKEL, 0.9),
        'eisen': M(EISEN, 0.5, 0.6),
        'fenster': M(FENSTER, 0.3, emit=0.9),
        'rune': M(RUNE, 0.4, emit=1.2),
        'dach': M(DACH, 0.85),
    })
    return TEX


# --- Teil aus Formen ----------------------------------------------------------
class Teil:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()
        self.mats = []
        self.box_uv = set()   # Materialien mit Würfel-Projektion (Backstein, Stein)

    def _mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _faces(self, verts, mat):
        fs = {f for v in verts for f in v.link_faces}
        i = self._mi(mat)
        for f in fs:
            f.material_index = i
        return fs

    def box(self, size, at, mat, rot=None):
        """Quader mit Mitte at; rot = Matrix (3x3) oder Winkel um Z."""
        R = rot if isinstance(rot, Matrix) else Matrix.Rotation(rot or 0.0, 4, 'Z')
        if len(R) == 3:
            R = R.to_4x4()
        mx = Matrix.Translation(Vector(at)) @ R @ Matrix.Diagonal((*size, 1.0))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mx)
        return self._faces(r['verts'], mat)

    def cyl(self, r1, r2, h, at, mat, seg=10, axis=None):
        """Kegelstumpf, Boden bei at, entlang axis (Vector, Standard +Z)."""
        axis = Vector(axis or (0, 0, 1)).normalized()
        q = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
        mx = Matrix.Translation(Vector(at)) @ q @ Matrix.Translation((0, 0, h / 2))
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2,
                                  depth=h, matrix=mx)
        return self._faces(r['verts'], mat)

    def ellipsoid(self, radii, at, mat_top, mat_bot, axis=None, split=0.25, seg=14, rings=7):
        """Abgeflachte Kugel (Hut); Flächen oberhalb split (lokal, Anteil von radii.z) bekommen mat_top."""
        axis = Vector(axis or (0, 0, 1)).normalized()
        q = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
        mx = Matrix.Translation(Vector(at)) @ q @ Matrix.Diagonal((*radii, 1.0))
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0, matrix=mx)
        it = self._mi(mat_top)
        ib = self._mi(mat_bot)
        inv = (Matrix.Translation(Vector(at)) @ q).inverted()
        for f in {f for v in r['verts'] for f in v.link_faces}:
            local = inv @ f.calc_center_median()
            f.material_index = it if local.z > split * radii[2] else ib
        return r['verts']

    def plane(self, w, h, at, normal, mat, up=(0, 0, 1), spin=0.0):
        """Rechteck (Abziehbild) mit UV 0..1, Vorderseite in Richtung normal."""
        n = Vector(normal).normalized()
        u = Vector(up).cross(n)
        if u.length < 1e-4:
            u = Vector((1, 0, 0))
        u.normalize()
        v = n.cross(u)
        rot = Matrix.Rotation(spin, 3, n)
        u, v = rot @ u, rot @ v
        c = Vector(at)
        pts = [c - u * w / 2 - v * h / 2, c + u * w / 2 - v * h / 2, c + u * w / 2 + v * h / 2, c - u * w / 2 + v * h / 2]
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self._mi(mat)
        for l, uv in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
            l[self.uv].uv = uv
        return f

    def finish(self):
        """Würfel-Projektion für Backstein/Stein (1 Einheit = eine Kachel) und Objekt anlegen."""
        idx = {self._mi(m) for m in self.box_uv if m in self.mats}
        self.bm.normal_update()
        for f in self.bm.faces:
            if f.material_index not in idx:
                continue
            nx, ny, nz = (abs(c) for c in f.normal)
            for l in f.loops:
                p = l.vert.co
                if nz >= nx and nz >= ny:
                    l[self.uv].uv = (p.x, p.y)
                elif nx >= ny:
                    l[self.uv].uv = (p.y, p.z)
                else:
                    l[self.uv].uv = (p.x, p.z)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = self.mats[p.material_index] in SMOOTH
        return ob


SMOOTH = set()


# --- Bausteine ---------------------------------------------------------------
def pilz(T, base, h, cap, up=(0, 0, 1), lean=(0.0, 0.0), rng=None):
    """Ein Pilz: Stiel von base entlang up (leicht geneigt), flacher Hut mit glühender Oberseite."""
    m = mats()
    up = Vector(up).normalized()
    side = up.orthogonal().normalized()
    other = up.cross(side)
    axis = (up + side * lean[0] + other * lean[1]).normalized()
    base = Vector(base)
    sr = cap * 0.22
    T.cyl(sr * 1.25, sr * 0.85, h, base - axis * 0.03, m['stiel'], seg=8, axis=axis)
    top = base + axis * h
    T.ellipsoid((cap, cap, cap * 0.62), top - axis * cap * 0.12, m['glut'], m['rand'], axis=axis, split=0.05)


def bueschel(T, center, n, size, rng, up=(0, 0, 1), spread=None):
    """Mehrere Pilze dicht beieinander, größter in der Mitte."""
    up = Vector(up).normalized()
    a = up.orthogonal().normalized()
    b = up.cross(a)
    spread = spread or size * 0.9
    for i in range(n):
        if i == 0:
            off, k = Vector((0, 0, 0)), 1.0
        else:
            ang = i * 2.399 + rng.uniform(-0.3, 0.3)
            dist = spread * math.sqrt(i / n) * rng.uniform(0.8, 1.1)
            off = a * math.cos(ang) * dist + b * math.sin(ang) * dist
            k = rng.uniform(0.35, 0.8) * (1.0 - 0.4 * dist / spread)
        h = size * k * rng.uniform(0.9, 1.3)
        pilz(T, Vector(center) + off, h, size * 0.42 * k * rng.uniform(0.85, 1.15), up,
             (off.dot(a) * 0.8 / max(spread, 1e-3) + rng.uniform(-0.1, 0.1),
              off.dot(b) * 0.8 / max(spread, 1e-3) + rng.uniform(-0.1, 0.1)), rng)


def konsole(T, at, r, normal, rng):
    """Baumpilz/Konsolenpilz, der waagrecht aus einer Wand wächst (halb in der Wand)."""
    m = mats()
    n = Vector(normal).normalized()
    T.ellipsoid((r, r * 0.75, r * 0.22), Vector(at), m['glut'], m['rand'], split=0.2)
    # dünner rosa Rand darunter
    T.ellipsoid((r * 0.9, r * 0.68, r * 0.12), Vector(at) - Vector((0, 0, r * 0.12)), m['rand'], m['rand'])


def wand_kolonie(T, at, normal, breite, hoehe, rng, dichte=1.0):
    """Kolonie an einer Wand: Konsolenpilze in Stufen, kleine Pilze, die schräg nach oben wachsen, Sporenfleck."""
    m = mats()
    n = Vector(normal).normalized()
    u = Vector((0, 0, 1)).cross(n).normalized()
    c = Vector(at)
    T.plane(breite * 1.5, hoehe * 1.4, c + n * 0.012, n, m['spore'], spin=rng.uniform(-0.4, 0.4))
    for _ in range(int(6 * dichte)):
        p = c + u * rng.uniform(-breite / 2, breite / 2) + Vector((0, 0, rng.uniform(-hoehe / 2, hoehe / 2)))
        r = rng.uniform(0.09, 0.2) * (1.0 + 0.3 * dichte)
        konsole(T, p + n * r * 0.35, r, n, rng)
    for _ in range(int(5 * dichte)):
        p = c + u * rng.uniform(-breite / 2, breite / 2) + Vector((0, 0, rng.uniform(-hoehe / 2, hoehe / 3)))
        up = (n * 0.8 + Vector((0, 0, 1))).normalized()
        pilz(T, p, rng.uniform(0.08, 0.16), rng.uniform(0.05, 0.09), up,
             (rng.uniform(-0.3, 0.3), rng.uniform(-0.2, 0.2)), rng)


def boden_sporen(T, at, r, rng):
    m = mats()
    T.plane(r * 2, r * 2, Vector(at) + Vector((0, 0, 0.012 + rng.uniform(0, 0.004))), (0, 0, 1), m['spore'],
            up=(0, 1, 0), spin=rng.uniform(0, math.tau))


def mauer(T, x0, x1, dicke, hoehe, rng, y=0.0, axis='x'):
    """Gerade Backsteinmauer von x0 bis x1 (Vorderseite -Y), mit Abdecksteinen und Sockel."""
    m = mats()
    T.box_uv |= {m['ziegel'], m['stein_m']}
    L = x1 - x0
    mid = (x0 + x1) / 2
    def P(a, b, z):
        return (a, b, z) if axis == 'x' else (b, a, z)
    def S(a, b, c):
        return (a, b, c) if axis == 'x' else (b, a, c)
    T.box(S(L, dicke, hoehe), P(mid, y, hoehe / 2), m['ziegel'])
    T.box(S(L + 0.06, dicke + 0.1, 0.1), P(mid, y, hoehe + 0.05), m['stein_m'])
    T.box(S(L + 0.04, dicke + 0.06, 0.16), P(mid, y, 0.08), m['stein_m'])
    # einzelne vorstehende Steine für unruhige Fläche
    for _ in range(int(L * 3)):
        a = rng.uniform(x0 + 0.1, x1 - 0.1)
        z = rng.uniform(0.3, hoehe - 0.2)
        T.box(S(0.25, 0.03, 0.12), P(a, y - dicke / 2 - 0.012, z), m['ziegel'])


def fenster(T, at, w, h, normal, rng):
    """Glühendes Fenster: dunkler Rahmen, Sprossenkreuz, gelbgrün leuchtende Scheibe, Sims."""
    m = mats()
    n = Vector(normal).normalized()
    u = Vector((0, 0, 1)).cross(n).normalized()
    c = Vector(at)
    T.plane(w, h, c + n * 0.015, n, m['fenster'])
    rot = Matrix((u, n, Vector((0, 0, 1)))).transposed()
    t = 0.06
    for dz in (-h / 2, h / 2):
        T.box((w + t * 2, 0.08, t), c + n * 0.03 + Vector((0, 0, dz)), m['holz_d'], rot)
    for du in (-w / 2, w / 2):
        T.box((t, 0.08, h), c + n * 0.03 + u * du, m['holz_d'], rot)
    T.box((0.035, 0.05, h), c + n * 0.035, m['holz_d'], rot)
    T.box((w, 0.05, 0.035), c + n * 0.035, m['holz_d'], rot)
    T.box((w + 0.2, 0.16, 0.06), c + n * 0.07 + Vector((0, 0, -h / 2 - 0.06)), m['stein_m'], rot)
    T.box_uv.add(m['stein_m'])


def rune(T, at, r, normal, rng):
    """Leuchtendes okkultes Zeichen: Ring aus Strichen und Glyphe aus Strichen innen."""
    m = mats()
    n = Vector(normal).normalized()
    u = Vector((0, 0, 1)).cross(n)
    if u.length < 1e-3:
        u = Vector((1, 0, 0))
    u.normalize()
    v = n.cross(u)
    c = Vector(at) + n * 0.014
    def strich(a, b, w=0.035):
        pa, pb = c + u * a[0] + v * a[1], c + u * b[0] + v * b[1]
        d = pb - pa
        f = T.plane(w, d.length, (pa + pb) / 2, n, m['rune'], up=d.normalized().cross(n).cross(n) * -1)
    seg = 14
    for i in range(seg):
        a0, a1 = i * math.tau / seg, (i + 1) * math.tau / seg
        strich((math.cos(a0) * r, math.sin(a0) * r), (math.cos(a1) * r, math.sin(a1) * r))
    pts = [(0, r * 0.75), (r * 0.65, -r * 0.4), (-r * 0.65, -r * 0.4), (0, 0), (0, -r * 0.75)]
    order = list(range(len(pts)))
    rng.shuffle(order)
    for i in range(len(order) - 1):
        strich(pts[order[i]], pts[order[i + 1]])
    strich((-r * 0.3, r * 0.25), (r * 0.3, r * 0.25))


def kiste_koerper(T, at, s, rng, offen=True):
    """Holzkiste aus Brettern, Deckel halb aufgeschoben."""
    m = mats()
    x, y, z = at
    T.box((s, s, s * 0.92), (x, y, z + s * 0.46), m['holz_d'])
    # Bretter außen
    for i in range(3):
        zz = z + s * (0.16 + i * 0.3)
        for (sx, sy, px, py) in ((s + 0.02, 0.03, 0, -s / 2), (s + 0.02, 0.03, 0, s / 2),
                                 (0.03, s + 0.02, -s / 2, 0), (0.03, s + 0.02, s / 2, 0)):
            T.box((sx, sy, s * 0.26), (x + px, y + py, zz), m['holz'])
    # Eckleisten
    for px in (-1, 1):
        for py in (-1, 1):
            T.box((0.07, 0.07, s * 0.96), (x + px * s / 2, y + py * s / 2, z + s * 0.48), m['holz_d'])
    if offen:
        lid = Matrix.Rotation(0.35, 4, 'Y') @ Matrix.Rotation(0.2, 4, 'Z')
        T.box((s * 1.02, s * 1.02, 0.06), (x + s * 0.45, y + 0.05, z + s * 0.84), m['holz'], lid)


# --- Teile ---------------------------------------------------------------------
def pilz_einzel(rng):
    T = Teil('pilz_einzel')
    pilz(T, (0, 0, 0), 0.55, 0.32, lean=(0.08, -0.05), rng=rng)
    pilz(T, (0.18, 0.1, 0), 0.16, 0.09, lean=(0.4, 0.2), rng=rng)
    boden_sporen(T, (0.02, 0.0, 0), 0.38, rng)
    return T


def pilz_bueschel(rng):
    T = Teil('pilz_bueschel')
    bueschel(T, (0, 0, 0), 11, 0.55, rng, spread=0.5)
    boden_sporen(T, (0, 0, 0), 0.75, rng)
    return T


def pilz_wand(rng):
    """Gerades Mauerstück 3 Einheiten lang mit Kolonie in der Mitte und Pilzen am Fuß."""
    T = Teil('pilz_wand')
    mauer(T, -1.5, 1.5, 0.4, 2.0, rng)
    wand_kolonie(T, (0.25, -0.2, 1.0), (0, -1, 0), 1.3, 1.2, rng, 1.6)
    wand_kolonie(T, (-1.0, -0.2, 1.55), (0, -1, 0), 0.5, 0.5, rng, 0.6)
    bueschel(T, (0.4, -0.38, 0), 6, 0.35, rng, spread=0.3)
    boden_sporen(T, (0.3, -0.6, 0), 0.6, rng)
    # Krone oben: Pilze auf der Mauer
    bueschel(T, (-0.6, 0, 2.1), 4, 0.22, rng, spread=0.15)
    return T


def pilz_wand_fenster(rng):
    """Mauerstück mit glühendem Fenster und Rune, Pilze unter dem Sims."""
    T = Teil('pilz_wand_fenster')
    mauer(T, -1.5, 1.5, 0.4, 2.0, rng)
    fenster(T, (-0.45, -0.2, 1.15), 0.7, 0.8, (0, -1, 0), rng)
    rune(T, (0.85, -0.2, 1.15), 0.32, (0, -1, 0), rng)
    wand_kolonie(T, (-0.45, -0.2, 0.55), (0, -1, 0), 0.8, 0.3, rng, 0.8)
    bueschel(T, (-0.9, -0.4, 0), 5, 0.3, rng, spread=0.25)
    return T


def pilz_mauerecke(rng):
    """L-förmige Ecke (je 2 Einheiten), Kolonie wuchert um die Kante, großer Büschel im Winkel."""
    T = Teil('pilz_mauerecke')
    mauer(T, -0.2, 2.0, 0.4, 2.2, rng, y=0.0)
    mauer(T, 0.2, 2.0, 0.4, 2.2, rng, y=0.0, axis='y')
    # Eckpfeiler
    m = mats()
    T.box((0.55, 0.55, 2.45), (0, 0, 1.225), m['ziegel'])
    T.box((0.65, 0.65, 0.12), (0, 0, 2.5), m['stein_m'])
    wand_kolonie(T, (0.9, -0.2, 1.3), (0, -1, 0), 1.0, 1.4, rng, 1.4)
    wand_kolonie(T, (-0.2, 0.9, 1.0), (-1, 0, 0), 1.0, 1.2, rng, 1.2)
    wand_kolonie(T, (-0.28, -0.28, 1.7), (-0.7, -0.7, 0), 0.4, 0.6, rng, 0.7)
    bueschel(T, (-0.55, -0.55, 0), 9, 0.5, rng, spread=0.45)
    boden_sporen(T, (-0.5, -0.5, 0), 0.9, rng)
    bueschel(T, (0.0, 0.0, 2.56), 5, 0.3, rng, spread=0.2)
    return T


def pilz_kiste(rng):
    """Holzkiste mit herausquellenden Pilzen: oben aus dem Spalt, seitlich aus den Ritzen."""
    T = Teil('pilz_kiste')
    s = 0.8
    kiste_koerper(T, (0, 0, 0), s, rng)
    bueschel(T, (-0.1, 0.0, s * 0.9), 12, 0.5, rng, spread=0.36)
    for i in range(5):
        z = rng.uniform(0.15, s * 0.8)
        x = rng.uniform(-s * 0.35, s * 0.35)
        up = Vector((0, -1, 0.9)).normalized()
        pilz(T, (x, -s / 2 - 0.01, z), rng.uniform(0.07, 0.14), rng.uniform(0.05, 0.08), up,
             (rng.uniform(-0.3, 0.3), 0), rng)
    bueschel(T, (s * 0.55, -s * 0.4, 0), 5, 0.25, rng, spread=0.2)
    boden_sporen(T, (0.1, -0.2, 0), 0.75, rng)
    return T


def pilz_haus(rng):
    """Backstein-Kubus (Ruine eines Hinterhauses): Flachdach mit Brüstung, zwei glühende Fenster,
    Rune, Kolonien an Front und Dach. Grundfläche 3 x 2.4, Höhe 3."""
    T = Teil('pilz_haus')
    m = mats()
    T.box_uv |= {m['ziegel'], m['stein_m']}
    W, D, H = 3.0, 2.4, 3.0
    T.box((W, D, H), (0, 0, H / 2), m['ziegel'])
    T.box((W + 0.12, D + 0.12, 0.12), (0, 0, H + 0.06), m['stein_m'])
    T.box((W - 0.4, D - 0.4, 0.04), (0, 0, H + 0.13), m['dach'])
    T.box((W + 0.06, D + 0.06, 0.2), (0, 0, 0.1), m['stein_m'])
    # Gurtgesims zwischen den Geschossen
    T.box((W + 0.06, D + 0.06, 0.08), (0, 0, 1.45), m['stein_m'])
    fenster(T, (-0.75, -D / 2, 2.2), 0.55, 0.75, (0, -1, 0), rng)
    fenster(T, (0.75, -D / 2, 2.2), 0.55, 0.75, (0, -1, 0), rng)
    fenster(T, (W / 2, 0.3, 2.2), 0.55, 0.75, (1, 0, 0), rng)
    # Tür (vernagelt)
    T.box((0.7, 0.06, 1.15), (0.6, -D / 2 - 0.02, 0.62), m['holz_d'])
    for z in (0.35, 0.7, 1.0):
        T.box((0.85, 0.04, 0.12), (0.6, -D / 2 - 0.06, z), m['holz'], 0.12 if z == 0.7 else -0.05)
    rune(T, (-0.75, -D / 2, 0.85), 0.36, (0, -1, 0), rng)
    wand_kolonie(T, (-1.15, -D / 2, 1.2), (0, -1, 0), 0.7, 1.6, rng, 1.4)
    wand_kolonie(T, (W / 2, -0.6, 0.9), (1, 0, 0), 0.9, 1.2, rng, 1.0)
    bueschel(T, (-0.9, 0.3, H + 0.15), 8, 0.45, rng, spread=0.45)
    bueschel(T, (0.9, -0.5, H + 0.15), 4, 0.3, rng, spread=0.2)
    bueschel(T, (-1.35, -D / 2 - 0.3, 0), 7, 0.4, rng, spread=0.35)
    boden_sporen(T, (-1.0, -D / 2 - 0.5, 0), 0.9, rng)
    return T


def runenstein(rng):
    """Liegender Steinblock mit Rune obendrauf und an der Front, ein paar Pilze am Fuß."""
    T = Teil('runenstein')
    m = mats()
    T.box_uv.add(m['stein_m'])
    T.box((0.9, 0.5, 0.7), (0, 0, 0.35), m['stein_m'], 0.1)
    rune(T, (0, -0.255, 0.38), 0.24, (math.sin(0.1), -math.cos(0.1), 0), rng)
    bueschel(T, (0.42, -0.25, 0), 4, 0.22, rng, spread=0.18)
    boden_sporen(T, (0.1, -0.3, 0), 0.55, rng)
    return T


TEILE = [pilz_einzel, pilz_bueschel, pilz_wand, pilz_wand_fenster, pilz_mauerecke, pilz_kiste, pilz_haus, runenstein]
SMOOTH.update({mats()['stiel'], mats()['rand'], mats()['glut']})

gebaut = []
for i, f in enumerate(TEILE):
    if NUR and f.__name__ not in NUR:
        continue
    rng = random.Random(100 + i)
    T = f(rng)
    ob = T.finish()
    gebaut.append(ob)
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    dst = os.path.join(OUT, T.name + '.glb')
    bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', use_selection=True, export_yup=True,
                              export_apply=False, export_image_format='AUTO')
    print('EXPORT', dst, len(ob.data.polygons), 'Flächen')


# --- Vorschau (Cycles) ---------------------------------------------------------
if 'bild' in OPT:
    sc = bpy.context.scene
    x = 0.0
    for ob in gebaut:
        w = ob.dimensions.x
        ob.location.x = x + w / 2 - (ob.bound_box[0][0] + ob.bound_box[6][0]) / 2
        x += w + 0.6
    mid = x / 2
    world = bpy.data.worlds.new('w')
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.025, 0.04, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
    boden = bpy.data.meshes.new('boden')
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60)
    bm.to_mesh(boden)
    bo = bpy.data.objects.new('boden', boden)
    boden.materials.append(M('#2a2f28', 0.95))
    sc.collection.objects.link(bo)
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = float(OPT.get('sonne', 0.6))
    sun.data.color = (0.6, 0.7, 1.0)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = x + 0.5
    cam.location = (mid, -14, 8.5)
    cam.rotation_euler = (math.radians(62), 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 48
    sc.cycles.device = 'CPU'
    sc.view_settings.view_transform = 'AgX'
    sc.render.resolution_x, sc.render.resolution_y = 2000, 700
    sc.render.filepath = OPT['bild']
    bpy.ops.render.render(write_still=True)
    print('BILD', OPT['bild'])
