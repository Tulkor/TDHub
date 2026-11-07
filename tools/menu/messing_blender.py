# Messingteile fürs WC3-Menü (Schraube, Eckbeschlag, Kantenleiste, Raute, Knopfrahmen) als echte 3D-Modelle mit
# Metall-Material, ortho von oben gerendert, transparenter Grund. Aufruf (bpy im venv, siehe docs/claude/werkzeuge.md):
#   env/bin/python -I tools/menu/messing_blender.py -- assets/textures/menu/messing
# Danach tools/menu/messing_nach.py (Kantenleiste kachelbar machen, Knopfrahmen auf 1x).
import bpy, bmesh, math, sys
from mathutils import Vector
OUT = sys.argv[sys.argv.index("--")+1]

def _spot(n, l, tc, direction, sharp, strength, color):
    """Heller Fleck in der Umgebung (Softbox): (max(dot(Blickrichtung, direction), 0) ^ sharp) * strength."""
    dot = n.new("ShaderNodeVectorMath"); dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = Vector(direction).normalized()
    l.new(tc.outputs["Generated"], dot.inputs[0])
    mx = n.new("ShaderNodeMath"); mx.operation = 'MAXIMUM'; mx.inputs[1].default_value = 0.0
    l.new(dot.outputs["Value"], mx.inputs[0])
    pw = n.new("ShaderNodeMath"); pw.operation = 'POWER'; pw.inputs[1].default_value = sharp
    l.new(mx.outputs[0], pw.inputs[0])
    mul = n.new("ShaderNodeVectorMath"); mul.operation = 'SCALE'
    mul.inputs[0].default_value = tuple(c * strength for c in color)
    l.new(pw.outputs[0], mul.inputs["Scale"])
    return mul.outputs[0]


def softbox_plane(sc, cx, cy, size):
    """Leuchtfläche über dem Teil, nur für Spiegelungen sichtbar (nicht für die Kamera). Weil die Kamera ortho von
    oben schaut, spiegelt jede Stelle einer flachen Fläche eine andere Stelle dieser Ebene: ein schräger heller
    Streifen läuft als Glanz über das Messing, der Rest bleibt dunkel (nicht komplett beleuchtet)."""
    bpy.ops.mesh.primitive_plane_add(size=size * 1.6, location=(cx, cy, 6))
    pl = bpy.context.object
    pl.visible_camera = False
    pl.visible_shadow = False
    m = bpy.data.materials.new("box"); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    for x in list(n):
        if x.type != 'OUTPUT_MATERIAL':
            n.remove(x)
    out = [x for x in n if x.type == 'OUTPUT_MATERIAL'][0]
    em = n.new("ShaderNodeEmission")
    tc = n.new("ShaderNodeTexCoord")
    mp = n.new("ShaderNodeMapping"); mp.inputs["Rotation"].default_value = (0, 0, math.radians(-40))
    l.new(tc.outputs["Generated"], mp.inputs["Vector"])
    gr = n.new("ShaderNodeTexGradient")
    l.new(mp.outputs["Vector"], gr.inputs["Vector"])
    ramp = n.new("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.interpolation = 'EASE'
    stops = [(0.0, 0.3), (0.26, 0.38), (0.40, 2.6), (0.48, 0.8), (0.62, 0.32), (0.78, 0.6), (0.86, 0.28), (1.0, 0.24)]
    cr.elements[0].position, cr.elements[0].color = stops[0][0], (stops[0][1],) * 3 + (1,)
    cr.elements[1].position, cr.elements[1].color = stops[-1][0], (stops[-1][1],) * 3 + (1,)
    for pos, v in stops[1:-1]:
        e = cr.elements.new(pos); e.color = (v, v * 0.93, v * 0.8, 1)
    l.new(gr.outputs["Fac"], ramp.inputs[0]); l.new(ramp.outputs[0], em.inputs["Color"])
    em.inputs["Strength"].default_value = 1.0
    l.new(em.outputs[0], out.inputs["Surface"])
    pl.data.materials.append(m)


def reset(zenith=0.0):
    """Dunkle Umgebung mit wenigen Softboxen: flache Flächen spiegeln fast nur Dunkel (Messing bleibt satt und
    nicht flächig hell), Wölbungen und Fasen fangen die Lichter als Glanzkanten (Lukas 2026-11-01)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 256
    sc.cycles.use_denoising = True
    sc.cycles.device = 'CPU'
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    nt = w.node_tree; n = nt.nodes; l = nt.links
    bg = n["Background"]
    tc = n.new("ShaderNodeTexCoord")
    parts = [
        _spot(n, l, tc, (0, 0, 1), 3, zenith, (1.0, 0.92, 0.8)),         # von oben: sonst softbox_plane(), bei Leisten/Ecken gleichmäßig
        _spot(n, l, tc, (-0.62, 0.62, 0.48), 40, 14.0, (1.0, 0.88, 0.68)),  # warme Softbox links oben (symmetrisch zur Diagonale,
        # damit Ecke und Leisten an allen vier Ecken gleich beleuchtet zusammenpassen): harte Glanzkante
        _spot(n, l, tc, (-0.3, 0.8, 0.55), 25, 0.9, (1.0, 0.9, 0.75)),     # breiter, schwächer daneben (beidseits)
        _spot(n, l, tc, (-0.8, 0.3, 0.55), 25, 0.9, (1.0, 0.9, 0.75)),
        _spot(n, l, tc, (0.6, -0.6, 0.4), 50, 3.0, (0.65, 0.75, 1.0)),    # kühles Gegenlicht rechts unten
    ]
    acc = parts[0]
    for p in parts[1:]:
        add = n.new("ShaderNodeVectorMath"); add.operation = 'ADD'
        l.new(acc, add.inputs[0]); l.new(p, add.inputs[1]); acc = add.outputs[0]
    base = n.new("ShaderNodeVectorMath"); base.operation = 'ADD'
    base.inputs[1].default_value = (0.09, 0.08, 0.065)
    l.new(acc, base.inputs[0])
    l.new(base.outputs[0], bg.inputs[0])
    # kleines, hartes Streiflicht für Glanzpunkte auf Schrauben und Kanten
    ld = bpy.data.lights.new("k", 'AREA'); ld.energy = 260; ld.size = 1.2; ld.color = (1, 0.9, 0.75)
    lo = bpy.data.objects.new("k", ld); sc.collection.objects.link(lo)
    lo.location = (-12, 10, 9); lo.rotation_euler = (math.radians(-45), math.radians(-50), 0)
    return sc


def brass(name="brass", dark=False, heavy=False):
    """Messing mit feiner Bürstung (Rauschen auf Rauheit und Bump), damit der Glanz nicht wie Plastik wirkt."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; l = nt.links
    p = n["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.50, 0.33, 0.14, 1) if dark else (0.78, 0.56, 0.27, 1)
    p.inputs["Metallic"].default_value = 1.0
    tc = n.new("ShaderNodeTexCoord")
    mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1.0, 40.0, 1.0)
    l.new(tc.outputs["Object"], mp.inputs["Vector"])
    nz = n.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 6.0; nz.inputs["Detail"].default_value = 8.0
    l.new(mp.outputs["Vector"], nz.inputs["Vector"])
    rr = n.new("ShaderNodeMapRange")
    rr.inputs[3].default_value = 0.26 if dark else 0.18
    rr.inputs[4].default_value = 0.40 if dark else 0.32
    l.new(nz.outputs["Fac"], rr.inputs[0]); l.new(rr.outputs[0], p.inputs["Roughness"])
    bump = n.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.08; bump.inputs["Distance"].default_value = 0.02
    l.new(nz.outputs["Fac"], bump.inputs["Height"]); l.new(bump.outputs["Normal"], p.inputs["Normal"])
    if heavy:
        # Ecken: deutlich mehr Metall-Struktur (gehämmert + Kratzer), Lukas 2026-11-02
        hz = n.new("ShaderNodeTexNoise"); hz.inputs["Scale"].default_value = 9.0; hz.inputs["Detail"].default_value = 4.0
        l.new(tc.outputs["Object"], hz.inputs["Vector"])
        vo = n.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 14.0
        l.new(tc.outputs["Object"], vo.inputs["Vector"])
        mix = n.new("ShaderNodeMath"); mix.operation = 'ADD'
        l.new(hz.outputs["Fac"], mix.inputs[0]); l.new(vo.outputs["Distance"], mix.inputs[1])
        mix2 = n.new("ShaderNodeMath"); mix2.operation = 'ADD'
        l.new(mix.outputs[0], mix2.inputs[0]); l.new(nz.outputs["Fac"], mix2.inputs[1])
        bump.inputs["Strength"].default_value = 0.35
        l.new(mix2.outputs[0], bump.inputs["Height"])
        rr.inputs[3].default_value = 0.16; rr.inputs[4].default_value = 0.48
        l.new(hz.outputs["Fac"], rr.inputs[0])
        # leichte Farbschwankung (Patina in den Vertiefungen)
        cr = n.new("ShaderNodeValToRGB")
        cr.color_ramp.elements[0].color = (0.40, 0.27, 0.10, 1); cr.color_ramp.elements[1].color = (0.66, 0.47, 0.21, 1)
        l.new(hz.outputs["Fac"], cr.inputs[0]); l.new(cr.outputs[0], p.inputs["Base Color"])
    return m

def ink():
    m = bpy.data.materials.new("ink"); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.02, 0.012, 0.005, 1)
    p.inputs["Roughness"].default_value = 0.6
    return m

def cam(sc, cx, cy, w, h, px, plane=True):
    """plane False: nur Umgebungslicht, das ist ortho überall gleich; nötig für Leiste und Ecke, die im Spiel
    nahtlos aneinanderstoßen (die Leuchtfläche hängt vom Ort ab und gäbe eine Kante)."""
    if plane:
        softbox_plane(sc, cx, cy, max(w, h))
    cd = bpy.data.cameras.new("c"); cd.type = 'ORTHO'; cd.ortho_scale = max(w, h)
    co = bpy.data.objects.new("c", cd); sc.collection.objects.link(co)
    co.location = (cx, cy, 50); sc.camera = co
    sc.render.resolution_x = int(px * w / max(w, h)); sc.render.resolution_y = int(px * h / max(w, h))
    sc.render.resolution_percentage = 100

def poly_obj(pts, depth, bevel, mat, z=0):
    me = bpy.data.meshes.new("p"); bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for x, y in pts]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]:
        v.co.z += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("p", me); bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    b = o.modifiers.new("b", 'BEVEL'); b.width = bevel; b.segments = 4; b.limit_method = 'ANGLE'
    return o

def screw(x, y, ang, r=0.65, sc=None, z=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, 0.15 + z), segments=48, ring_count=24)
    s = bpy.context.object; s.scale.z = 0.38; s.data.materials.append(brass("sb"))
    bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_cube_add(location=(x, y, 0.15 + z + r * 0.38))
    c = bpy.context.object; c.scale = (r * 0.85, r * 0.12, 0.2); c.rotation_euler.z = ang
    m = s.modifiers.new("d", 'BOOLEAN'); m.object = c; m.operation = 'DIFFERENCE'
    c.hide_render = True
    # dunkler Ring darunter
    bpy.ops.mesh.primitive_cylinder_add(radius=r * 1.12, depth=0.1, location=(x, y, 0.08 + z), vertices=48)
    bpy.context.object.data.materials.append(ink())

def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

# 1) Schraube allein (für Ecken der Tafeln, Karten)
sc = reset(); screw(0, 0, math.radians(35)); cam(sc, 0, 0, 1.6, 1.6, 64); render(OUT + "/schraube.png")
# Rahmenprofil (Lukas 2026-11-02): flaches Band, 17 px breit, in der Mitte eine halbrunde Erhöhung (Wulst).
# Ecke und Leiste haben dasselbe Profil und dasselbe Licht, die Ecke ist damit wie angeschweißt statt aufgelegt.
BAND_W = 1.7      # 17 px
BAND_H = 0.12     # Dicke des flachen Bands
WULST_R = 0.5     # Halbrund in der Mitte


def wulst(points, mat):
    """Halbrunder Wulst entlang einer Linie (Punkte in Einheiten), Mitte auf der Bandoberfläche."""
    cu = bpy.data.curves.new("w", 'CURVE'); cu.dimensions = '3D'
    sp = cu.splines.new('POLY'); sp.points.add(len(points) - 1)
    for i, (x, y) in enumerate(points):
        sp.points[i].co = (x, y, BAND_H, 1)
    cu.bevel_depth = WULST_R; cu.bevel_resolution = 8; cu.use_fill_caps = True
    o = bpy.data.objects.new("w", cu); bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def schweissnaht(a, b, n=14):
    """Kleine Schweißraupe zwischen a und b (Punkte in Einheiten)."""
    m = brass("naht", dark=True, heavy=True)
    for i in range(n + 1):
        t = i / n
        x = a[0] + (b[0] - a[0]) * t; y = a[1] + (b[1] - a[1]) * t
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.075, location=(x, y, BAND_H + 0.02), segments=12, ring_count=8)
        o = bpy.context.object; o.scale.z = 0.6; o.data.materials.append(m)


# 2) Ecke (80x80 px -> 8 Einheiten, y nach unten gespiegelt): Band wie die Leisten mit abgeschrägter Ecke, Wulst
#    läuft um die Ecke herum, innen ein angeschweißtes Knotenblech mit zwei Schrauben.
sc = reset(zenith=0.24)
P = [(0, 30), (30, 0), (84, 0), (84, 17), (39, 17), (17, 39), (17, 84), (0, 84)]
f = lambda pts: [(x / 10, -y / 10) for x, y in pts]
poly_obj(f(P), BAND_H, 0.03, brass("b", dark=True, heavy=True))
wulst(f([(8.5, 90), (8.5, 34.5), (34.5, 8.5), (90, 8.5)]), brass("bw", heavy=True))
poly_obj(f([(39, 17), (60, 17), (17, 60), (17, 39)]), 0.24, 0.06, brass("g", heavy=True))
schweissnaht((3.9, -1.7), (1.7, -3.9))
schweissnaht((6.0, -1.7), (1.7, -6.0), 20)
# Nähte quer über das Band, wo die Ecke an die Leisten geschweißt ist
schweissnaht((8.0, 0.0), (8.0, -1.7), 9)
schweissnaht((0.0, -8.0), (1.7, -8.0), 9)
for (x, y, a) in [(44, 22, 35), (22, 44, -20)]:
    screw(x / 10, -y / 10, math.radians(a), 0.45, z=0.2)
cam(sc, 4, -4, 8.4, 8.4, 168, plane=False); render(OUT + "/ecke.png")
# 3) Kantenleiste (waagrecht, kachelbar): dasselbe Profil, gleiches Licht
sc = reset(zenith=0.24)
poly_obj([(-20, BAND_W / 2), (20, BAND_W / 2), (20, -BAND_W / 2), (-20, -BAND_W / 2)], BAND_H, 0.03, brass("k", dark=True))
wulst([(-20, 0), (20, 0)], brass("kw"))
cam(sc, 0, 0, 8, BAND_W, 512, plane=False); render(OUT + "/kante_h.png")
# 4) Raute (Trenner)
sc = reset()
poly_obj([(0, 0.7), (0.7, 0), (0, -0.7), (-0.7, 0)], 0.3, 0.2, brass("r"))
cam(sc, 0, 0, 1.6, 1.6, 48); render(OUT + "/raute.png")
# 5) Knopf-Rahmen: Spitzes Sechseck als Messingring (für Knöpfe), 300x56 px
sc = reset()
def hexp(w, h, t):
    return [(-w/2 + t, h/2), (w/2 - t, h/2), (w/2, 0), (w/2 - t, -h/2), (-w/2 + t, -h/2), (-w/2, 0)]
o = poly_obj(hexp(30, 5.6, 1.4), 0.3, 0.1, brass("h"))
inner = poly_obj(hexp(29.2, 4.8, 1.25), 0.6, 0.0, brass("x"), z=-0.1)
m = o.modifiers.new("d", 'BOOLEAN'); m.object = inner; m.operation = 'DIFFERENCE'; inner.hide_render = True
o.modifiers.move(1, 0)
cam(sc, 0, 0, 30.4, 6, 608); render(OUT + "/knopf_rahmen.png")
# 6) Fassung des Kristalls oben an der Hub-Säule: Trapez 74 x 16 px (oben 54 breit), 2x gerendert
sc = reset()
poly_obj([(-2.7, 0.8), (2.7, 0.8), (3.7, -0.8), (-3.7, -0.8)], 0.5, 0.18, brass("f"))
cam(sc, 0, 0, 7.8, 2.0, 156); render(OUT + "/fassung.png")
