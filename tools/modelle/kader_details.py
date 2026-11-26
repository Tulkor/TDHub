"""Eigene Details je Held des Bollwerk-Kaders (Lukas 2026-11-16: alle neuen Helden überarbeiten).
kader_bau.build() ruft details(f, h, M, dims) auf, bevor die Waffen entstehen. Jedes Teil hängt starr an
head, chest oder hips; Skelett, Waffen und Mantelkette bleiben unverändert. Blick nach +Y.
dims: height, hip, neck, width.
"""
import math


def details(f, h, M, dims):
    hid = h['id']
    H, hip, neck, w = dims['height'], dims['hip'], dims['neck'], dims['width']
    hz = neck + .19                      # Kopfmitte
    col = '#' + h['color']
    skin = M('#bda18c', .82)
    dark, white, gold = M('#171d29', .88), M('#d1c9b5', .9), M('#bc9c5c', .4, .75)
    leather, wood, iron = M('#473b34', .9), M('#674a32', .9), M('#657182', .35, .8)
    red, glow = M('#8f2a2a', .85), M(col, .35, 0, 3)
    bone = M('#d9d2bd', .7)

    def face(nose=True, mouth=True, ears=True):
        if nose:
            f.cyl(.045, .0, .11, (0, .27, hz + .01), skin, 'head', rot=(-75, 0, 0), seg=5)
        if mouth:
            f.box((.1, .02, .018), (0, .245, hz - .09), M('#5a2f2a', .8), 'head')
        if ears:
            for s in (1, -1):
                f.ball(.055, (s * .235, .02, hz + .02), skin, 'head', scale=(.45, 1, 1.25), seg=6, rings=4)

    def hair_cap(color, back=.0):
        m = M(color, .92)
        f.ball(.275, (0, -.02, hz + .06), m, 'head', scale=(.95, .95, .9), seg=10, rings=6)
        if back:
            f.ball(.2, (0, -.16, hz - .08), m, 'head', scale=(1.0, .7, 1.0 + back), seg=8, rings=5)
        return m

    def moustache(color, wide=.12):
        m = M(color, .92)
        for s in (1, -1):
            f.cyl(.035, .008, wide * 1.6, (s * wide * .7, .25, hz - .06), m, 'head', rot=(0, 90 + s * 20, 0), seg=5)

    def plume(color, n=6):
        m = M(color, .85)
        for k in range(n):
            f.box((.05, .09, .2 + .04 * (2 - abs(k - 2))), (0, .16 - k * .075, hz + .34 - abs(k - 2) * .02), m, 'head', rot=(-12 + k * 8, 0, 0))

    def tabard(mat, emblem=None):
        f.box((.3, .035, hip * .62), (0, .33, hip - hip * .26), mat, 'hips', rot=(-4, 0, 0), bevel=.01)
        f.box((.32, .035, .34), (0, .3, hip + .34), mat, 'chest', bevel=.01)
        if emblem is not None:
            f.ball(.07, (0, .325, hip + .36), emblem, 'chest', scale=(1, .3, 1), seg=8, rings=5)

    def necklace(mat, n=5, drop=.0):
        for k in range(n):
            a = (k / (n - 1) - .5) * 1.6
            f.ball(.035, (math.sin(a) * .2, .26 + math.cos(a) * .04, neck - .12 - math.cos(a) * (.06 + drop)), mat, 'chest', seg=5, rings=4)

    def pack(mat, size=(.42, .22, .46)):
        f.box(size, (0, -.36, hip + .34), mat, 'chest', bevel=.04)
        for s in (1, -1):
            f.stab((s * .16, -.26, hip + .52), (s * .2, .2, neck - .1), .025, .025, leather, 'chest', seg=5)

    if hid == 'brennholt':      # Hauptmann: Helmbusch, Schärpe, Wappen, Schnurrbart
        plume('#a32a2a')
        moustache('#6e4835', .13)
        f.stab((-.3, .3, neck - .1), (.28, .32, hip + .08), .05, .05, red, 'chest', seg=6)
        f.ball(.09, (.02, .34, hip + .32), gold, 'chest', scale=(1, .3, 1.2), seg=8, rings=5)
        f.box((.05, .02, .12), (.02, .365, hip + .32), red, 'chest')
        f.box((.14, .02, .045), (.02, .365, hip + .34), red, 'chest')
        for s in (1, -1):
            f.box((.09, .04, .3), (s * .12, .36, hip - .32), M(col, .6, .4), 'hips', bevel=.01)
    elif hid == 'mira':         # Felsenwächterin: Moos, Kristalle, Runenrisse, Steinbrauen
        moss, crystal = M('#4d6b33', .95), M('#7fe6c8', .2, 0, 3)
        for s in (1, -1):
            f.ball(.3, (s * (w + .05), -.02, neck + .0), moss, 'chest', scale=(1.1, 1.0, .35), seg=8, rings=5)
            f.box((.3, .09, .07), (s * .13, .25, hz + .12), M('#56626a', .94), 'head', rot=(0, s * 14, 0), bevel=.02)
        for k in range(5):
            a = (k - 2) * .35
            f.cyl(.11, .0, .5 + .12 * (2 - abs(k - 2)), (math.sin(a) * .5, -.4, neck - .05 + math.cos(a) * .12), crystal, 'chest', rot=(-30, a * 40, 0), seg=5)
        for k in range(4):
            f.box((.035, .03, .3 - k * .04), ((k - 1.5) * .16, .5, hip + .32 + (k % 2) * .08), crystal, 'chest', rot=(0, (k - 1.5) * 18, 0))
        f.box((.3, .04, .05), (0, .26, hz - .1), M('#2f373c', .9), 'head')
    elif hid == 'grauhirte':    # Rudelführer: Wolfskopf-Kapuze, Fellkragen, Knochenkette, Horn
        fur = M('#8d949b', .97)
        f.cyl(.13, .07, .26, (0, .26, hz + .3), fur, 'head', rot=(-78, 0, 0), seg=6)          # Schnauze über der Stirn
        f.ball(.035, (0, .4, hz + .27), dark, 'head', seg=5, rings=4)
        for s in (1, -1):
            f.cyl(.07, .0, .22, (s * .17, -.02, hz + .48), fur, 'head', rot=(0, s * 14, 0), seg=4)
            f.ball(.028, (s * .08, .3, hz + .36), M('#ffd24a', .3, 0, 3), 'head', seg=5, rings=4)
            f.cyl(.03, .0, .1, (s * .06, .36, hz + .2), bone, 'head', rot=(180, 0, 0), seg=4)
        v = f.cyl(.52, .34, .26, (0, -.02, neck - .1), fur, 'chest', seg=10, scale=(1.1, .85, 1))
        f.jag(v, .09, seed=5)
        necklace(bone, 7, .05)
        f.stab((.34, .1, hip + .1), (.46, .26, hip - .18), .07, .015, bone, 'hips', seg=6)
    elif hid == 'sirra':        # Giftklinge: Halbmaske, Feder, Giftfläschchen, Wurfmesser
        poison = M('#8fe03a', .2, 0, 2.5)
        f.box((.3, .1, .13), (0, .21, hz - .08), M('#2a1f38', .9), 'head', bevel=.03)
        f.stab((.2, -.05, hz + .28), (.34, -.3, hz + .56), .03, .005, M(col, .8), 'head', seg=4)
        for k in range(3):
            f.cyl(.04, .04, .12, (-.2 + k * .1, .36, hip + .02), poison, 'hips', seg=6)
            f.cyl(.025, .025, .04, (-.2 + k * .1, .36, hip + .1), wood, 'hips', seg=5)
        f.stab((.22, .25, neck - .12), (-.24, .27, hip + .12), .035, .035, leather, 'chest', seg=6)
        for k in range(4):
            t = k / 3
            f.box((.03, .02, .13), (.22 - t * .46, .3, neck - .12 - t * (neck - hip - .24)), iron, 'chest', rot=(0, 35, 0))
        f.box((.12, .03, hip * .5), (.2, -.3, hip - hip * .2), M('#2a1f38', .9), 'hips', rot=(6, 0, -6))
    elif hid == 'kaspar':       # Tüftler: Ledermütze, Schnurrbart, Rucksack mit Zahnrädern und Planrollen
        face(mouth=False)
        f.ball(.285, (0, -.03, hz + .08), leather, 'head', scale=(.97, .97, .8), seg=10, rings=6)
        for s in (1, -1):
            f.box((.08, .12, .22), (s * .24, -.02, hz - .02), leather, 'head', bevel=.02)
        moustache('#8a8a84', .14)
        pack(wood)
        for k in range(2):
            f.cyl(.13 - k * .03, .13 - k * .03, .04, (.24 - k * .42, -.42, hip + .48 - k * .2), gold, 'chest', rot=(90, 0, 0), seg=8)
        for k in range(3):
            f.cyl(.035, .035, .5, (-.12 + k * .1, -.38, hip + .78), white, 'chest', rot=(0, 90, 0), seg=6)
        f.stab((.3, .3, hip + .02), (.36, .34, hip - .2), .02, .02, iron, 'hips', seg=4)
    elif hid == 'yuna':         # Klingentänzerin: Stirnband mit Bändern, Hüftschärpe, Schulterschal
        face(ears=False)
        hair_cap('#5d302a')
        band = M(col, .7, 0, .8)
        f.cyl(.265, .265, .05, (0, .02, hz + .12), band, 'head', seg=12)
        for s in (1, -1):
            t = f.box((.05, .02, .5), (s * .08, -.3, hz - .1), band, 'head', rot=(18, 0, s * 10))
            f.jag(t, .06, seed=3 + s)
        f.cyl(.33, .3, .16, (0, 0, hip + .02), band, 'hips', seg=12)
        t = f.box((.16, .03, hip * .7), (.22, .22, hip - hip * .32), band, 'hips', rot=(-6, 0, 6))
        f.jag(t, .08, seed=9)
        f.ball(.17, (-(w + .06), 0, neck - .05), iron, 'chest', scale=(1, .95, .6), seg=8, rings=5)
        f.cyl(.03, .0, .16, (-(w + .1), 0, neck + .06), iron, 'chest', seg=4)
    elif hid == 'orrin':        # Feuermagier: spitze Kapuze, Glutbart, Runenstola, Kohlebecken auf der Schulter
        ember = M('#ffb14a', .3, 0, 4)
        f.cyl(.2, .0, .42, (0, -.14, hz + .5), M('#242d42', .93), 'head', rot=(-28, 0, 0), seg=6)
        for k in range(3):
            f.cyl(.06, .02, .26 - abs(k - 1) * .05, ((k - 1) * .07, .22, hz - .22), M('#c4572a', .9), 'head', rot=(-10, 0, 0), seg=5)
        for s in (1, -1):
            f.box((.09, .03, hip * .9), (s * .12, .33, hip + .02), M('#7a2f1c', .85), 'chest', rot=(-3, 0, 0))
            for k in range(3):
                f.box((.05, .02, .05), (s * .12, .35, hip + .3 - k * .22), ember, 'chest', rot=(0, 45, 0))
        f.cyl(.16, .1, .12, (w + .06, -.02, neck + .02), iron, 'chest', seg=8)
        for k in range(3):
            f.cyl(.05, .0, .2 + k * .04, (w + .02 + k * .04, -.02, neck + .16), ember, 'chest', seg=5)
    elif hid == 'ilsabet':      # Frostmagierin: Eiskrone, hoher Kragen, Brosche, Schultertuch
        face(ears=False)
        ice = M('#bfeaff', .15, .2, 2.2)
        f.ball(.16, (0, -.2, hz + .16), white, 'head', seg=8, rings=5)
        f.cyl(.24, .24, .04, (0, .0, hz + .26), ice, 'head', seg=10)
        for k in range(5):
            a = (k - 2) * .5
            f.cyl(.035, .0, .2 + .08 * (2 - abs(k - 2)), (math.sin(a) * .22, .1 + math.cos(a) * .12, hz + .36), ice, 'head', seg=4)
        for s in (1, -1):
            f.platte([(s * .1, -.14, neck - .08), (s * .32, -.06, neck - .06), (s * .36, -.1, neck + .34), (s * .16, -.2, neck + .3)],
                     (0, 1, 0), .03, M(col, .7), 'chest')
        v = f.cyl(.46, .3, .2, (0, 0, neck - .14), white, 'chest', seg=10, scale=(1.05, .8, 1))
        f.jag(v, .07, seed=13)
        f.ball(.07, (0, .28, neck - .12), ice, 'chest', scale=(1, .4, 1.3), seg=6, rings=4)
    elif hid == 'tamo':         # Gewitterbauer: Halstuch, Hosenträger, Garbe auf dem Rücken, Stoppelbart, Flicken
        face()
        f.ball(.2, (0, .14, hz - .12), M('#8a7458', .95), 'head', scale=(1, .6, .55), seg=8, rings=5)
        f.cyl(.2, .16, .12, (0, .04, neck - .0), red, 'chest', seg=8)
        f.cyl(.09, .0, .2, (0, .22, neck - .14), red, 'chest', rot=(170, 0, 0), seg=4)
        for s in (1, -1):
            f.stab((s * .16, .27, neck - .1), (s * .2, .3, hip + .06), .03, .03, leather, 'chest', seg=5)
        straw = M('#bca171', .95)
        for k in range(6):
            f.stab(((k - 2.5) * .05, -.36, hip + .1), ((k - 2.5) * .11, -.42, neck + .3), .028, .012, straw, 'chest', seg=4)
        f.cyl(.17, .17, .06, (0, -.37, hip + .42), leather, 'chest', rot=(90, 0, 0), seg=8)
        f.box((.12, .03, .12), (.23, .2, H * .3), M('#7a5a3a', .95), 'hips', rot=(0, 0, 12))
    elif hid == 'albe':         # Lichtheilerin: Schleier, Lichtkranz, Sonnen-Tabard, Gebetsperlen
        sun = M('#ffe9a0', .3, 0, 3.5)
        f.ball(.3, (0, -.07, hz + .1), white, 'head', scale=(1.02, 1.0, 1.05), seg=10, rings=6)
        v = f.cyl(.4, .26, .5, (0, -.12, neck - .0), white, 'head', seg=10, scale=(1, .7, 1))
        f.jag(v, .06, seed=17)
        for k in range(12):
            a = k * math.tau / 12
            f.box((.04, .03, .04), (math.cos(a) * .34, -.12, hz + .16 + math.sin(a) * .34), sun, 'head', rot=(0, math.degrees(-a), 0))
        tabard(white, sun)
        necklace(M('#6a4a2a', .8), 7, .12)
        f.box((.04, .02, .12), (0, .3, neck - .36), gold, 'chest')
        f.box((.1, .02, .035), (0, .3, neck - .34), gold, 'chest')
    elif hid == 'fenn':         # Pfadfinder: Federhut, Schal, Rucksack mit Schlafrolle und Kartenrohr
        green = M('#3f5a3a', .9)
        f.cyl(.4, .4, .03, (0, -.02, hz + .24), green, 'head', seg=10, scale=(1, 1.15, 1))
        f.cyl(.24, .16, .22, (0, -.04, hz + .34), green, 'head', seg=8)
        f.stab((.18, -.05, hz + .28), (.3, -.34, hz + .62), .035, .005, M('#d9c35a', .8), 'head', seg=4)
        f.cyl(.24, .2, .12, (0, .03, neck + .0), M(col, .9), 'chest', seg=8)
        t = f.box((.1, .03, .36), (.14, .26, neck - .22), M(col, .9), 'chest', rot=(-6, 0, -8))
        f.jag(t, .05, seed=21)
        pack(leather, (.4, .2, .4))
        f.cyl(.11, .11, .5, (0, -.38, hip + .64), M('#6a7a5a', .95), 'chest', rot=(0, 90, 0), seg=8)
        f.cyl(.045, .045, .46, (.27, -.36, hip + .34), bone, 'chest', rot=(0, 12, 0), seg=6)
    elif hid == 'ralda':        # Runenwächterin: Zöpfe, Schmiedeschürze, Stirnbrille, Runenplatten
        face()
        hair = hair_cap('#b5532a')
        for s in (1, -1):
            for k in range(4):
                f.ball(.07 - k * .008, (s * .22, .1, hz - .1 - k * .11), hair, 'head', seg=6, rings=4)
            f.ball(.04, (s * .22, .1, hz - .56), gold, 'head', seg=5, rings=4)
            f.cyl(.07, .07, .04, (s * .09, .22, hz + .2), gold, 'head', rot=(-70, 0, 0), seg=8)
            f.box((.2, .06, .22), (s * (w + .1), .0, neck + .06), glow, 'chest', rot=(0, s * 25, 0), bevel=.02)
        tabard(leather)
        for k in range(3):
            f.box((.05, .02, .09), ((k - 1) * .09, .355, hip - .1), glow, 'hips', rot=(0, (k - 1) * 30, 0))
    elif hid == 'varg':         # Berserker: Irokese, Kriegsbemalung, Fellschurz, Knochenkette, Armwickel
        face()
        for k in range(6):
            f.box((.06, .1, .2 + .05 * (2.5 - abs(k - 2.5))), (0, .16 - k * .08, hz + .3), M('#b5532a', .9), 'head', rot=(-15 + k * 7, 0, 0))
        for s in (1, -1):
            f.box((.035, .02, .2), (s * .11, .245, hz + .02), red, 'head', rot=(0, s * 8, 0))
            f.box((.16, .02, .04), (s * .16, .3, hip + .5), red, 'chest', rot=(0, s * -25, 0))
        v = f.cyl(.4, .33, .3, (0, 0, hip - .12), M('#6a5644', .97), 'hips', seg=10)
        f.jag(v, .12, seed=27)
        necklace(bone, 7, .06)
        f.ball(.09, (0, .3, neck - .3), bone, 'chest', scale=(1, .8, 1.1), seg=6, rings=4)
    elif hid == 'lior':         # Trugbildmagier: Turban mit Juwel, schwebende Spiegelscherben, Sternensaum
        mirror = M('#d4e8f3', .08, 1)
        f.ball(.33, (0, -.04, hz + .2), M(col, .8), 'head', scale=(1.05, 1.05, .7), seg=10, rings=6)
        for k in range(3):
            f.cyl(.34 - k * .02, .34 - k * .02, .035, (0, -.04, hz + .12 + k * .09), M('#e6e4f6', .8), 'head', rot=(8 - k * 8, 0, 0), seg=10)
        f.ball(.06, (0, .28, hz + .24), glow, 'head', scale=(1, .5, 1.3), seg=6, rings=4)
        for k in range(5):
            a = k * math.tau / 5 + .4
            f.platte([(math.cos(a) * .62, math.sin(a) * .5 - .05, neck + .1 + (k % 2) * .25),
                      (math.cos(a) * .62 + .1, math.sin(a) * .5 - .05, neck + .25 + (k % 2) * .25),
                      (math.cos(a) * .62, math.sin(a) * .5 - .05, neck + .42 + (k % 2) * .25),
                      (math.cos(a) * .62 - .08, math.sin(a) * .5 - .05, neck + .22 + (k % 2) * .25)], (math.cos(a), math.sin(a), 0), .02, mirror, 'chest')
        for k in range(7):
            a = (k - 3) * .32
            f.box((.04, .02, .04), (math.sin(a) * .44, .2 + math.cos(a) * .14, hip * .16), glow, 'hips', rot=(0, 45, 0))
    elif hid == 'kraehenfrau':  # Fluchweberin: Krähenschädel auf der Stirn, langes Haar, Schädelkette, Federsaum
        f.ball(.12, (0, .24, hz + .3), bone, 'head', scale=(.85, 1.1, .8), seg=8, rings=5)
        f.cyl(.06, .0, .34, (0, .46, hz + .2), bone, 'head', rot=(-112, 0, 0), seg=5)
        for s in (1, -1):
            f.ball(.03, (s * .05, .31, hz + .32), dark, 'head', seg=5, rings=4)
            t = f.box((.12, .05, .7), (s * .2, .1, neck - .12), M('#1c1a22', .92), 'head', rot=(-6, 0, s * 5))
            f.jag(t, .12, seed=31 + s)
        necklace(bone, 5, .1)
        for k in range(9):
            a = (k - 4) * .3
            f.cyl(.05, .0, .3, (math.sin(a) * .42, .1 + math.cos(a) * .2, hip * .2), dark, 'hips', rot=(180, 0, 0), seg=4)
    elif hid == 'bruno':        # Kellerwächter: Glatze mit Haarkranz, mächtiger Schnurrbart, rote Nase, Schürze, Schlüssel und Würste
        face(nose=False)
        f.ball(.07, (0, .27, hz + .0), M('#c7675a', .7), 'head', seg=6, rings=5)
        f.cyl(.275, .27, .12, (0, -.03, hz + .02), M('#8a6a4a', .92), 'head', seg=10)
        moustache('#8a6a4a', .19)
        tabard(white)
        f.cyl(.07, .07, .012, (.3, .3, hip + .0), iron, 'hips', rot=(90, 0, 0), seg=8)
        for k in range(3):
            f.box((.018, .014, .13), (.27 + k * .03, .31, hip - .1), gold, 'hips', rot=(0, (k - 1) * 14, 0))
        for k in range(4):
            f.ball(.06, (-.34, .12 + k * .09, hip + .02 - abs(k - 1.5) * .04), M('#8a3a2a', .7), 'hips', scale=(.8, 1.3, .8), seg=6, rings=4)
    elif hid == 'tessa':        # Windschützin: Kopftuch, Ringelhemd, Seilrolle, Fernrohr
        face(ears=False)
        f.ball(.275, (0, -.02, hz + .09), M(col, .85), 'head', scale=(.97, .97, .75), seg=10, rings=6)
        t = f.box((.12, .03, .34), (.2, -.2, hz - .02), M(col, .85), 'head', rot=(14, 0, -18))
        f.jag(t, .06, seed=37)
        for k in range(4):
            f.cyl(.325 - abs(k - 1.5) * .02, .325 - abs(k - 1.5) * .02, .045, (0, 0, hip + .14 + k * .11), white, 'chest', seg=12, scale=(.74, .64, 1))
        for k in range(3):
            f.cyl(.14, .14, .045, (-.33, .05, hip + .04 - k * .05), M('#b89a6a', .95), 'hips', rot=(0, 90, 0), seg=10)
        f.cyl(.045, .035, .34, (.32, .1, hip - .08), gold, 'hips', rot=(12, 0, 0), seg=8)
    elif hid == 'totengraeber': # Seelenhüter: hoher Zylinder, Schal, Mantelschöße, Grablaterne, Schädel am Gürtel
        f.cyl(.4, .4, .03, (0, -.03, hz + .3), dark, 'head', seg=10)
        f.cyl(.25, .27, .46, (0, -.03, hz + .54), dark, 'head', seg=10)
        f.cyl(.265, .265, .06, (0, -.03, hz + .36), M(col, .8), 'head', seg=10)
        f.cyl(.24, .2, .14, (0, .03, neck + .0), M('#5a5448', .95), 'chest', seg=8)
        t = f.box((.11, .03, .5), (-.14, .27, neck - .3), M('#5a5448', .95), 'chest', rot=(-5, 0, 6))
        f.jag(t, .07, seed=41)
        for s in (1, -1):
            t = f.box((.3, .04, hip * .9), (s * .2, -.3, hip * .62), dark, 'hips', rot=(8, 0, -s * 4), bevel=.01)
            f.jag(t, .12, seed=43 + s)
        f.box((.15, .15, .2), (.34, .16, hip - .16), glow, 'hips', bevel=.015)
        for dz in (-.13, .13):
            f.box((.2, .2, .04), (.34, .16, hip - .16 + dz), iron, 'hips')
        f.ball(.085, (-.3, .24, hip - .02), bone, 'hips', scale=(1, .9, 1.05), seg=8, rings=5)
        f.box((.08, .05, .05), (-.3, .29, hip - .09), bone, 'hips')
    elif hid == 'ada':          # Glockenritterin: Helmbusch, Glocken-Tabard, Seilschärpe, Zopf
        plume('#e6dcb8', 5)
        tabard(M('#3a4668', .85), gold)
        f.cyl(.07, .1, .12, (0, .34, hip + .32), gold, 'chest', seg=8)
        f.cyl(.375, .375, .05, (0, 0, hip + .0), M('#b89a6a', .95), 'hips', seg=12)
        for k in range(2):
            f.stab((.3, .2, hip - .02), (.32 + k * .06, .24, hip - .34), .025, .025, M('#b89a6a', .95), 'hips', seg=5)
            f.ball(.04, (.32 + k * .06, .24, hip - .36), gold, 'hips', seg=5, rings=4)
        for k in range(4):
            f.ball(.07 - k * .008, (0, -.24, hz - .1 - k * .11), M('#c9a45a', .9), 'head', seg=6, rings=4)
    elif hid == 'sorek':        # Kettenwächter: Kapitänsbart, Kopftuch, Tau über der Schulter, Muschelplatte, Tätowierbänder
        moustache('#3e4a52', .13)
        f.ball(.2, (0, .14, hz - .16), M('#3e4a52', .95), 'head', scale=(1, .65, .8), seg=8, rings=5)
        for k in range(5):
            a = k / 4
            f.cyl(.07, .07, .12, (-.28 + a * .5, .3 - abs(a - .5) * .1, neck - .08 - a * (neck - hip - .2)), M('#b89a6a', .95), 'chest', rot=(0, 55, 0), seg=6)
        for k in range(5):
            f.ball(.07, ((w + .08) + math.cos(k * 1.3) * .12, math.sin(k * 1.3) * .12, neck + .1), bone, 'chest', scale=(1, 1, .6), seg=6, rings=4)
        f.box((.44, .03, .05), (0, .29, hip + .48), M(col, .5, 0, 1.2), 'chest')
        f.box((.4, .03, .04), (0, .3, hip + .4), M(col, .5, 0, 1.2), 'chest')
