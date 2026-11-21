"""Volume-shaded multi-tile props for the new levels (original art).
Every prop image has its 'feet' at the bottom centre; collision is a small
box at the base (see BuiltLevel)."""
import math, os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vol import Canvas, ellipsoid, capsule, rbox, poly, ramp, hexc
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "props"


def P(**kw):
    return {k: ramp(hexc(v)) for k, v in kw.items()}


def leaf_tex(x, y, v):
    return v + (0.12 if (x * 7 + y * 3) % 9 == 0 else 0) - (0.1 if (x * 5 + y * 11) % 13 == 0 else 0) + math.sin(x * 1.7 + y * 2.3) * 0.05


def bark_tex(x, y, v):
    return v + math.sin(x * 2.5 + math.sin(y * 0.5)) * 0.1


def stone_tex(x, y, v):
    return v + (0.08 if (x * 13 + y * 7) % 11 == 0 else 0) - (0.07 if (x * 3 + y * 5) % 17 == 0 else 0)


def metal_tex(x, y, v):
    return v + (0.05 if y % 6 == 0 else 0)


def shadow(c, cx, cy, rx, ry):
    """Ground shadows are added afterwards as translucent ellipses (grounded)."""
    pass


def grounded(im, wide=0.42):
    """Pads the image by 3 px at the bottom and puts a soft shadow under its base."""
    w, h = im.size
    a = im.getchannel("A")
    rows = [y for y in range(h) if any(a.getpixel((x, y)) for x in range(w))]
    base = rows[-1] if rows else h - 1
    xs = [x for x in range(w) for y in range(max(0, base - 5), base + 1) if a.getpixel((x, y))]
    cx = (min(xs) + max(xs)) / 2 if xs else w / 2
    rx = max(5, (max(xs) - min(xs)) * wide + 3) if xs else w * 0.4
    out = Image.new("RGBA", (w, h + 3), (0, 0, 0, 0))
    px = out.load()
    ry = max(2.5, rx * 0.28)
    cy = base + 0.5
    for y in range(h + 3):
        for x in range(w):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d < 1:
                px[x, y] = (8, 12, 10, 95 if d < 0.6 else 60)
    out.alpha_composite(im, (0, 0))
    return out


def tree2(seed=0, green="#3f8f3a", light="#6cbf4c", trunk="#6e4a2c", w=56, h=74, round_=True):
    """Big leafy tree: a dome of many leaf clumps, light from the top-left."""
    rnd = random.Random(seed)
    c = Canvas(w, h, P(leaf=green, leaf2=light, leafd=sh_hex(green, 0.72), bark=trunk))
    for k in ("leaf", "leaf2", "leafd"):
        c.textures[k] = leaf_tex
    c.textures["bark"] = bark_tex
    cx = w // 2
    c.add(rbox("bark", 1, cx - 4, h - 26, cx + 4, h - 2, rad=2))
    c.add(capsule("bark", 1.1, cx - 3, h - 4, cx - 8, h - 1, 2.0))      # roots
    c.add(capsule("bark", 1.1, cx + 3, h - 4, cx + 8, h - 1, 2.0))
    c.add(capsule("bark", 1.3, cx + 2, h - 24, cx + 10, h - 32, 1.8))   # branch
    top, bot = 4, h - 24
    cyc = (top + bot) / 2
    ry = (bot - top) / 2
    rx = w / 2 - 3
    # back (dark) clumps, then middle, then light clumps on the top-left
    for layer, mat, z, n, r in (("b", "leafd", 2, 9, 11), ("m", "leaf", 3, 12, 9), ("f", "leaf2", 4, 8, 7)):
        for i in range(n):
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(0.0, 0.75 if layer != "f" else 0.55)
            x = cx + math.cos(a) * rx * d
            y = cyc + math.sin(a) * ry * d
            if layer == "f":
                x -= rx * 0.18
                y -= ry * 0.22
            if layer == "b":
                y += ry * 0.15
            rr = r + rnd.uniform(-1.5, 1.5)
            c.add(ellipsoid(mat, z + i * 0.01, x, y, rr, rr * 0.9))
    return c.render()


def sh_hex(h, k):
    c = hexc(h)
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(v * k))) for v in c)


def tree(w=48, h=64, seed=0, green="#3e8a3a", trunk="#6a4a2e"):
    random.seed(seed)
    c = Canvas(w, h, P(leaf=green, leaf2="#5aa846", bark=trunk, shadow="#16301c"))
    c.textures["leaf"] = leaf_tex
    c.textures["leaf2"] = leaf_tex
    c.textures["bark"] = bark_tex
    cx = w // 2
    shadow(c, cx, h - 4, 14, 4)
    c.add(rbox("bark", 1, cx - 4, h - 22, cx + 4, h - 3, rad=2))
    c.add(capsule("bark", 1.2, cx - 1, h - 20, cx - 8, h - 28, 1.6))
    blobs = [(cx, 22, 17, 15), (cx - 11, 28, 11, 10), (cx + 11, 28, 11, 10), (cx - 6, 14, 10, 9), (cx + 7, 13, 10, 9), (cx, 33, 13, 8)]
    for i, (bx, by, rx, ry) in enumerate(blobs):
        c.add(ellipsoid("leaf" if i % 2 == 0 else "leaf2", 2 + i * 0.1, bx + random.uniform(-1, 1), by, rx, ry))
    return c.render()


def bush(seed=0, flowers=True):
    random.seed(seed)
    c = Canvas(28, 24, P(leaf="#3f8a3c", leaf2="#58a646", flower="#f0d0f0", shadow="#16301c"))
    c.textures["leaf"] = leaf_tex
    c.textures["leaf2"] = leaf_tex
    shadow(c, 14, 21, 11, 3)
    for i, (bx, by, rx, ry) in enumerate([(14, 14, 10, 8), (8, 16, 6, 5), (20, 16, 6, 5), (12, 10, 6, 5), (17, 10, 5, 4)]):
        c.add(ellipsoid("leaf" if i % 2 == 0 else "leaf2", 1 + i * 0.1, bx, by, rx, ry))
    if flowers:
        for _ in range(5):
            x, y = random.randint(6, 21), random.randint(7, 17)
            c.dot(x, y, "flower", 4)
            c.dot(x + 1, y, "flower", 2)
    return c.render()


def pillar(broken=False):
    c = Canvas(24, 52, P(stone="#b8b0a0", moss="#5a8a40", shadow="#1c2a1c"))
    c.textures["stone"] = stone_tex
    shadow(c, 12, 49, 10, 3)
    top = 18 if broken else 6
    c.add(rbox("stone", 1, 4, 44, 20, 50, rad=1.5))            # base
    c.add(rbox("stone", 2, 6, top + 4, 18, 45, rad=2))         # shaft
    for x in (9, 12, 15):
        for y in range(top + 6, 44):
            c.dot(x, y, "stone", 1)                             # flutes
    if broken:
        c.add(poly("stone", 3, [(6, top + 4), (10, top - 2), (13, top + 2), (18, top - 4), (18, top + 5), (6, top + 6)]))
    else:
        c.add(rbox("stone", 3, 3, top, 21, top + 5, rad=1.5))  # capital
    for (x, y) in ((7, 40), (8, 41), (16, 30), (17, 31), (7, 26)):
        c.dot(x, y, "moss", 3)
    return c.render()


def statue_head():
    c = Canvas(30, 30, P(stone="#a8a090", moss="#5a8a40", shadow="#1c2a1c"))
    c.textures["stone"] = stone_tex
    shadow(c, 15, 27, 13, 3)
    c.add(ellipsoid("stone", 1, 15, 15, 11, 11))
    c.add(rbox("stone", 1.5, 6, 20, 24, 27, rad=3))
    for (x, y) in ((11, 13), (19, 13)):
        c.add(ellipsoid("stone", 2, x, y, 2.2, 1.6, depth=0.3))
        c.dot(x, y + 1, "stone", 0)
    c.add(capsule("stone", 2, 15, 15, 15, 19, 1.4))
    for (x, y) in ((8, 8), (9, 7), (22, 20), (23, 21), (7, 22)):
        c.dot(x, y, "moss", 3)
    return c.render()


def rock(seed=0, color="#8a8a86"):
    random.seed(seed)
    c = Canvas(24, 20, P(stone=color, moss="#5a8a40", shadow="#1c2a1c"))
    c.textures["stone"] = stone_tex
    shadow(c, 12, 17, 11, 3)
    c.add(ellipsoid("stone", 1, 11, 12, 9, 6.5))
    c.add(ellipsoid("stone", 1.2, 16, 13, 6, 5))
    c.dot(8, 7, "moss", 3)
    c.dot(9, 7, "moss", 4)
    return c.render()


def machine():
    c = Canvas(40, 44, P(metal="#7a8494", dark="#3a404c", hazard="#e8b830", light="#5ae070", red="#f04a3a", shadow="#101418"))
    c.textures["metal"] = metal_tex
    shadow(c, 20, 41, 18, 3)
    c.add(rbox("metal", 1, 3, 12, 37, 41, rad=3))
    c.add(rbox("dark", 1.5, 7, 16, 33, 28, rad=2, depth=0.5))
    for i, col in enumerate(("light", "red", "light")):
        c.add(ellipsoid(col, 2, 12 + i * 8, 22, 2.2, 2.2, depth=0.4))
    for x in range(3, 38):
        c.dot(x, 33, "hazard" if (x // 3) % 2 else "dark", 3)
    c.add(capsule("dark", 0.5, 30, 12, 30, 2, 2.6))                # exhaust pipe
    c.add(capsule("metal", 0.6, 9, 12, 9, 5, 2.0))
    return c.render()


def tank():
    c = Canvas(36, 52, P(metal="#9aa4ae", toxic="#7ad040", dark="#3a404c", shadow="#101418"))
    c.textures["metal"] = metal_tex
    shadow(c, 18, 49, 16, 3)
    c.add(rbox("metal", 1, 4, 10, 32, 48, rad=6))
    c.add(ellipsoid("metal", 1.5, 18, 10, 14, 5))
    c.add(rbox("toxic", 2, 13, 20, 23, 40, rad=2, depth=0.5))     # sight glass
    for y in (16, 30, 44):
        for x in range(5, 32):
            c.dot(x, y, "dark", 2)
    return c.render()


def tank_rust():
    c = Canvas(34, 46, P(metal="#9a6a4a", toxic="#c8e040", dark="#3a2a24"))
    c.textures["metal"] = stone_tex
    c.add(rbox("metal", 1, 3, 8, 31, 44, rad=6))
    c.add(ellipsoid("metal", 1.5, 17, 8, 14, 5))
    for y in (14, 26, 38):
        for x in range(4, 31):
            c.dot(x, y, "dark", 2)
    c.add(capsule("toxic", 2, 9, 30, 9, 43, 1.2))  # a toxic drip
    return c.render()


def pipes():
    c = Canvas(52, 34, P(pipe="#b0b8c0", pipe2="#c8a040", stand="#4a505a"))
    c.textures["pipe"] = metal_tex
    for x in (8, 26, 44):
        c.add(rbox("stand", 1, x - 2, 14, x + 2, 33, rad=1))
    for i, (y, m) in enumerate(((12, "pipe"), (19, "pipe2"), (26, "pipe"))):
        c.add(capsule(m, 2 + i * 0.1, 2, y, 50, y, 3.2))
        for x in (14, 38):
            c.add(rbox("stand", 3, x - 1, y - 4, x + 1, y + 4, rad=0.5, depth=0.5))
    return c.render()


def chimney():
    c = Canvas(26, 66, P(brick="#8a4a3a", band="#d8d0c0", dark="#2a2024"))
    c.textures["brick"] = stone_tex
    c.add(rbox("brick", 1, 3, 30, 23, 65, rad=2))
    c.add(rbox("brick", 1.2, 6, 4, 20, 34, rad=2))
    for y in (10, 22):
        for x in range(6, 21):
            c.dot(x, y, "band", 4)
            c.dot(x, y + 1, "band", 2)
    c.add(ellipsoid("dark", 2, 13, 4, 7, 2.2, depth=0.3))
    for y in range(36, 64, 4):
        for x in range(4, 23):
            c.dot(x, y, "brick", 1)
    return c.render()


def drums():
    c = Canvas(30, 26, P(blue="#3a6ab0", red="#b03a2a", dark="#2a2e38", shadow="#101418"))
    shadow(c, 15, 23, 14, 3)
    for i, (x, col) in enumerate(((8, "blue"), (21, "red"), (14, "blue"))):
        y = 23 if i < 2 else 13
        c.add(rbox(col, 1 + i, x - 6, y - 12, x + 6, y, rad=3))
        c.add(ellipsoid(col, 1.5 + i, x, y - 12, 6, 2.2))
        for yy in (y - 8, y - 3):
            for xx in range(x - 6, x + 7):
                c.dot(xx, yy, col, 1)
    return c.render()


def crates():
    c = Canvas(28, 30, P(wood="#a8743c", dark="#5a3a1e", shadow="#101418"))
    shadow(c, 14, 27, 13, 3)
    for (x0, y0, x1, y1, z) in ((2, 13, 15, 27, 1), (14, 15, 26, 27, 1.2), (6, 2, 19, 14, 2)):
        c.add(rbox("wood", z, x0, y0, x1, y1, rad=1.5))
        for x in range(x0 + 1, x1):
            c.dot(x, (y0 + y1) // 2, "dark", 2)
        for t in range(0, min(x1 - x0, y1 - y0)):
            c.dot(x0 + 1 + t, y0 + 1 + t * (y1 - y0) // max(1, x1 - x0), "dark", 3)
    return c.render()


def container(color="#b0402c"):
    c = Canvas(48, 34, P(paint=color, dark="#2a2e38", shadow="#101418"))
    shadow(c, 24, 31, 23, 3)
    c.add(rbox("paint", 1, 1, 6, 46, 31, rad=1.5))
    c.add(rbox("paint", 1.5, 1, 2, 46, 8, rad=1.5, depth=0.5))
    for x in range(4, 45, 3):
        for y in range(10, 30):
            c.dot(x, y, "paint", 1)
    c.add(rbox("dark", 2, 40, 12, 44, 28, rad=0.5, depth=0.3))
    return c.render()


def bollard():
    c = Canvas(14, 18, P(metal="#3a404c", rope="#c8a46a", shadow="#101418"))
    shadow(c, 7, 16, 6, 2)
    c.add(rbox("metal", 1, 3, 6, 10, 16, rad=2))
    c.add(ellipsoid("metal", 1.5, 6.5, 6, 4.5, 2.2))
    for x in range(3, 11):
        c.dot(x, 10, "rope", 3)
    return c.render()


def boat():
    c = Canvas(56, 30, P(hull="#e8ecf0", stripe="#2a6ab0", wood="#8a5a34", water="#28506a"))
    c.add(ellipsoid("water", 0, 28, 24, 26, 5, depth=0.2))
    c.add(poly("hull", 1, [(2, 12), (54, 12), (48, 24), (8, 24)], depth=1.0))
    for x in range(5, 52):
        c.dot(x, 16, "stripe", 3)
    c.add(rbox("wood", 2, 18, 4, 34, 13, rad=1.5))
    c.add(rbox("hull", 2.5, 20, 6, 32, 10, rad=1, depth=0.4))
    return c.render()


def junk_pile(seed=0):
    random.seed(seed)
    c = Canvas(44, 34, P(junk="#6a5e58", rust="#9a5634", blue="#4a6a9a", green="#5a8a40", tire="#24242a", shadow="#101014"))
    shadow(c, 22, 31, 20, 3)
    c.add(ellipsoid("junk", 1, 22, 24, 20, 10))
    for i in range(10):
        x, y = random.randint(6, 38), random.randint(12, 28)
        col = random.choice(("rust", "blue", "green", "junk"))
        c.add(rbox(col, 2 + i * 0.1, x - 3, y - 2, x + 3, y + 2, rad=1, depth=0.6))
    c.add(ellipsoid("tire", 3, 30, 18, 5, 3))
    c.dot(30, 18, "junk", 2)
    return c.render()


def tires():
    c = Canvas(26, 28, P(tire="#24242a", shadow="#101014"))
    shadow(c, 13, 25, 12, 3)
    for i, y in enumerate((22, 16, 10)):
        c.add(ellipsoid("tire", 1 + i, 13, y, 10, 4))
        c.add(ellipsoid("tire", 1.5 + i, 13, y - 1, 4, 1.4, depth=0.2))
    return c.render()


def car_wreck():
    c = Canvas(52, 32, P(paint="#7a3a3a", rust="#9a5634", glass="#4a6070", tire="#24242a", shadow="#101014"))
    shadow(c, 26, 29, 24, 3)
    c.add(rbox("paint", 1, 2, 14, 50, 28, rad=4))
    c.add(rbox("paint", 1.5, 12, 5, 38, 16, rad=4))
    c.add(rbox("glass", 2, 15, 7, 24, 14, rad=1, depth=0.4))
    c.add(rbox("glass", 2, 27, 7, 35, 14, rad=1, depth=0.4))
    for (x, y) in ((10, 28), (40, 28)):
        c.add(ellipsoid("tire", 2.5, x, y, 5, 3))
    for (x, y) in ((6, 18), (7, 19), (44, 22), (30, 20), (31, 21)):
        c.dot(x, y, "rust", 3)
    return c.render()


def banner():
    c = Canvas(20, 48, P(pole="#4a4452", cloth="#8a1a24", gold="#e8b830", shadow="#101014"))
    shadow(c, 10, 46, 7, 2)
    c.add(capsule("pole", 1, 10, 46, 10, 3, 1.4))
    c.add(poly("cloth", 2, [(11, 5), (19, 5), (19, 30), (15, 26), (11, 30)]))
    for (x, y) in ((14, 12), (15, 11), (16, 12), (15, 13), (15, 15), (14, 16), (16, 16)):
        c.dot(x, y, "gold", 4)
    return c.render()


# ---------------------------------------------------------------- campaign themes (Forest, Snow Path, City, Lake, AI DataCenter)

def pine(seed=0, green="#2f6e44", snow_=False, w=40, h=70):
    """Conifer: stacked skirts of needles, optionally with snow on each skirt."""
    rnd = random.Random(seed)
    c = Canvas(w, h, P(leaf=green, leafd=sh_hex(green, 0.7), bark="#5a3c26", snow="#eef4ff"))
    c.textures["leaf"] = leaf_tex
    c.textures["leafd"] = leaf_tex
    c.textures["bark"] = bark_tex
    cx = w // 2
    c.add(rbox("bark", 1, cx - 3, h - 14, cx + 3, h - 2, rad=1.5))
    tiers = 4
    for i in range(tiers):
        t = i / (tiers - 1)
        y = 6 + t * (h - 26)
        hw = 5 + t * (w / 2 - 7) + rnd.uniform(-1, 1)
        top = y - 8 - t * 3
        c.add(poly("leafd", 2 + i * 0.1, [(cx, top), (cx + hw, y + 7), (cx - hw, y + 7)], depth=0.9))
        c.add(poly("leaf", 2.05 + i * 0.1, [(cx - 1, top + 1), (cx + hw * 0.4, y + 5), (cx - hw + 1, y + 6)], depth=0.9))
        if snow_:
            for k in range(int(hw * 1.6)):
                xx = cx - hw + 2 + k * 1.2
                yy = y + 6 - abs(xx - cx) * 0.0 - (1 if k % 3 else 0)
                c.dot(int(xx), int(yy), "snow", 4 + (k % 2))
            c.dot(cx, int(top) + 1, "snow", 5)
    return c.render()


def crystal(seed=0, col="#58d8e8", w=26, h=34):
    rnd = random.Random(seed)
    c = Canvas(w, h, P(gem=col, gemd=sh_hex(col, 0.6), rock="#4a5266"))
    c.add(ellipsoid("rock", 1, w / 2, h - 5, w / 2 - 2, 4))
    shards = [(w / 2, h - 6, 0, h - 8), (w / 2 - 6, h - 6, -4, h - 16), (w / 2 + 6, h - 5, 4, h - 14)]
    for i, (x, y, lean, ht) in enumerate(shards):
        hw = 3.2 if i == 0 else 2.6
        c.add(poly("gem" if i != 2 else "gemd", 2 + i * 0.1,
                   [(x - hw, y), (x - hw + lean * 0.5, y - ht + 4), (x + lean, y - ht), (x + hw + lean * 0.5, y - ht + 4), (x + hw, y)], depth=1.0))
    for _ in range(4):
        c.dot(rnd.randint(4, w - 5), rnd.randint(4, h - 12), "gem", 5)
    return c.render()


def street_tree(seed=0):
    rnd = random.Random(seed)
    c = Canvas(36, 56, P(leaf="#4a9a44", leaf2="#72c058", bark="#6a4a2e", pot="#a8a49c", soil="#4a3424"))
    for k in ("leaf", "leaf2"):
        c.textures[k] = leaf_tex
    c.add(rbox("pot", 1, 8, 44, 28, 55, rad=2))
    c.add(ellipsoid("soil", 1.2, 18, 45, 9, 2.2, depth=0.3))
    c.add(rbox("bark", 1.5, 16, 24, 20, 46, rad=1.5))
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0, 0.7)
        c.add(ellipsoid("leaf" if i % 3 else "leaf2", 2 + i * 0.05, 18 + math.cos(a) * 10 * d - (2 if i % 3 == 0 else 0),
                        16 + math.sin(a) * 8 * d - (2 if i % 3 == 0 else 0), 7.5, 7))
    return c.render()


def lamp():
    c = Canvas(18, 60, P(pole="#3a4050", glass="#fff0b0", dark="#22262e"))
    c.textures["pole"] = metal_tex
    c.add(rbox("dark", 1, 5, 54, 13, 59, rad=1.5))
    c.add(capsule("pole", 1.5, 9, 56, 9, 10, 1.6))
    c.add(capsule("pole", 2, 9, 10, 14, 6, 1.3))
    c.add(rbox("dark", 2.5, 11, 4, 17, 8, rad=1))
    c.add(ellipsoid("glass", 3, 14, 8, 2.5, 1.5, depth=0.4))
    return c.render()


def bench():
    c = Canvas(34, 22, P(wood="#a86a3a", metal="#3a4050"))
    c.textures["wood"] = bark_tex
    for x in (5, 29):
        c.add(rbox("metal", 1, x - 1.5, 8, x + 1.5, 21, rad=0.5))
    c.add(rbox("wood", 2, 2, 4, 32, 8, rad=1, depth=0.6))
    c.add(rbox("wood", 2.2, 2, 12, 32, 16, rad=1, depth=0.6))
    return c.render()


def dumpster(col="#2e7a4a"):
    c = Canvas(36, 30, P(paint=col, lid="#24262e", wheel="#1a1a20"))
    c.textures["paint"] = metal_tex
    c.add(rbox("paint", 1, 2, 8, 34, 27, rad=2))
    c.add(rbox("lid", 1.5, 1, 4, 35, 10, rad=1.5, depth=0.5))
    for x in range(4, 33, 4):
        c.dot(x, 18, "paint", 1)
    for x in (7, 29):
        c.add(ellipsoid("wheel", 2, x, 28, 2.5, 1.8))
    return c.render()


def hydrant():
    c = Canvas(14, 20, P(red="#d83a2a", cap="#f0c040"))
    c.add(rbox("red", 1, 3, 6, 11, 19, rad=2))
    c.add(ellipsoid("red", 1.5, 7, 6, 4.5, 3))
    c.add(capsule("red", 2, 1, 11, 13, 11, 1.6))
    c.add(ellipsoid("cap", 2.5, 7, 3, 2, 1.5))
    return c.render()


def parked_car(col="#3a6ab0"):
    c = Canvas(48, 30, P(paint=col, glass="#9ac4dc", tire="#1e1e24", light="#fff0b0"))
    c.add(rbox("paint", 1, 2, 12, 46, 26, rad=4))
    c.add(rbox("paint", 1.5, 11, 4, 37, 15, rad=4))
    c.add(rbox("glass", 2, 14, 6, 23, 13, rad=1, depth=0.4))
    c.add(rbox("glass", 2, 26, 6, 34, 13, rad=1, depth=0.4))
    for x in (10, 38):
        c.add(ellipsoid("tire", 2.5, x, 26, 4.5, 3))
    c.add(ellipsoid("light", 3, 44, 17, 1.5, 1.2, depth=0.3))
    return c.render()


def palm(seed=0):
    rnd = random.Random(seed)
    c = Canvas(50, 70, P(leaf="#3a9a4a", leafd="#2a7038", bark="#9a7448", nut="#6a4a28"))
    c.textures["bark"] = bark_tex
    c.textures["leaf"] = leaf_tex
    x0, y0 = 25, 68
    lean = rnd.choice((-1, 1)) * 5
    for i in range(10):  # ringed trunk, gently bent
        t0, t1 = i / 10, (i + 1) / 10
        c.add(capsule("bark", 1 + i * 0.01, x0 + lean * t0 * t0, y0 - t0 * 46, x0 + lean * t1 * t1, y0 - t1 * 46, 2.6 - t0 * 0.8))
    tx, ty = x0 + lean, y0 - 48
    for k, a in enumerate((200, 235, 270, 305, 340, 160, 20)):
        r = math.radians(a)
        ex, ey = tx + math.cos(r) * 22, ty + math.sin(r) * 9 + 8
        mx_, my_ = tx + math.cos(r) * 12, ty + math.sin(r) * 5 - 3
        c.add(capsule("leaf" if k % 2 else "leafd", 2 + k * 0.05, tx, ty, mx_, my_, 3.2))
        c.add(capsule("leaf" if k % 2 else "leafd", 2.02 + k * 0.05, mx_, my_, ex, ey, 2.2))
    for dx in (-2, 2):
        c.add(ellipsoid("nut", 3, tx + dx, ty + 3, 2, 2))
    return c.render()


def umbrella(col="#e04a3a"):
    c = Canvas(40, 50, P(cloth=col, cloth2="#f4f0e8", pole="#d8d0c0", towel="#3a8ad0"))
    c.add(rbox("towel", 0.5, 4, 40, 26, 48, rad=1, depth=0.2))
    c.add(capsule("pole", 1, 20, 47, 20, 10, 1.1))
    for i in range(6):
        a0 = math.pi + i * math.pi / 6
        a1 = math.pi + (i + 1) * math.pi / 6
        c.add(poly("cloth" if i % 2 == 0 else "cloth2", 2 + i * 0.01,
                   [(20, 4), (20 + math.cos(a0) * 19, 16 + math.sin(a0) * 2), (20 + math.cos(a1) * 19, 16 + math.sin(a1) * 2)], depth=0.6))
    return c.render()


def server(seed=0, led="#40e8e0", led2="#f050c8"):
    rnd = random.Random(seed)
    c = Canvas(30, 52, P(body="#2c3244", front="#1a1e2a", led=led, led2=led2, top="#4a5268"))
    c.textures["body"] = metal_tex
    c.add(rbox("body", 1, 2, 6, 28, 51, rad=1.5))
    c.add(rbox("top", 1.2, 2, 2, 28, 8, rad=1.5, depth=0.5))
    c.add(rbox("front", 1.5, 5, 10, 25, 48, rad=1, depth=0.4))
    for y in range(12, 47, 4):
        for x in range(7, 24):
            c.dot(x, y + 2, "body", 1)
        for x in (8, 11, 14):
            if rnd.random() < 0.7:
                c.dot(x, y, "led" if rnd.random() < 0.7 else "led2", 3)
    return c.render()


def console():
    c = Canvas(36, 30, P(body="#3a4256", screen="#2ad0d8", key="#8a92a6", glow="#d8ffff"))
    c.textures["body"] = metal_tex
    c.add(rbox("body", 1, 3, 14, 33, 29, rad=2))
    c.add(poly("body", 1.5, [(4, 15), (32, 15), (29, 4), (7, 4)], depth=0.6))
    c.add(rbox("screen", 2, 9, 6, 27, 13, rad=1, depth=0.3))
    for x in range(11, 26, 3):
        c.dot(x, 8, "glow", 5)
        c.dot(x + 1, 10, "glow", 3)
    for x in range(7, 30, 3):
        c.dot(x, 19, "key", 4)
        c.dot(x, 22, "key", 3)
    return c.render()


def cable_drum():
    c = Canvas(26, 26, P(wood="#8a6a42", cable="#e0503a", dark="#3a2a1e"))
    c.add(ellipsoid("wood", 1, 13, 14, 11, 11))
    c.add(ellipsoid("cable", 1.5, 13, 14, 8, 8))
    c.add(ellipsoid("dark", 2, 13, 14, 2.5, 2.5, depth=0.3))
    return c.render()


def turret(view="side"):
    """AI DataCenter wall turret: a NEXUS eye on a steel mount.
    side: the barrel points left (the scene flips it); up / down: pointing up or down."""
    c = Canvas(32, 32, P(body="#4a5268", dark="#22283a", eye="#f040c0", barrel="#8a94aa"))
    c.textures["body"] = metal_tex
    c.add(rbox("dark", 1, 8, 8, 24, 24, rad=3))
    c.add(ellipsoid("body", 2, 16, 16, 7, 7))
    if view == "side":
        c.add(capsule("barrel", 3, 15, 16, 2, 16, 2.2))
    elif view == "up":
        c.add(capsule("barrel", 3, 16, 15, 16, 2, 2.2))
    else:
        c.add(capsule("barrel", 3, 16, 17, 16, 30, 2.2))
    c.add(ellipsoid("eye", 4, 16, 16, 2.6, 2.6, depth=0.5))
    return c.render()


THEMES = {
    "ruins": {"tree": [tree2(seed=s) for s in range(3)] + [tree2(seed=7, green="#4a7a2e", light="#86b04c")],
              "bush": [bush(s) for s in range(2)],
              "pillar": [pillar(), pillar(True)], "statue": [statue_head()], "rock": [rock(s) for s in range(2)]},
    "factory": {"machine": [machine()], "tank": [tank(), tank_rust()], "pipes": [pipes()], "chimney": [chimney()],
                "drums": [drums()], "crates": [crates()]},
    "harbor": {"container": [container(), container("#2a6ab0"), container("#3a8a4a")], "crates": [crates()],
               "bollard": [bollard()], "boat": [boat()], "drums": [drums()]},
    "fortress": {"junk": [junk_pile(s) for s in range(2)], "tires": [tires()], "car": [car_wreck()], "banner": [banner()],
                 "drums": [drums()]},
    "forest": {"tree": [tree2(seed=s, green=g, light=l) for s, g, l in ((11, "#2f7a3a", "#58aa48"), (12, "#357f34", "#62b04a"),
                                                                       (13, "#2a6e40", "#4fa050"))] + [pine(seed=14)],
               "bush": [bush(s) for s in range(2)], "rock": [rock(5, "#7c8478")], "stump": [rock(6, "#7a5634")]},
    "snow": {"pine": [pine(seed=s, green=g, snow_=True) for s, g in ((21, "#2a5e48"), (22, "#2e6650"), (23, "#24564a"))],
             "crystal": [crystal(24), crystal(25, "#8ae0ff")], "rock": [rock(26, "#8a96aa")]},
    "city": {"street_tree": [street_tree(s) for s in (31, 32)], "lamp": [lamp()], "bench": [bench()],
             "dumpster": [dumpster(), dumpster("#3a5a9a")], "hydrant": [hydrant()], "car": [parked_car(), parked_car("#c84a3a")]},
    "lake": {"palm": [palm(41), palm(42)], "umbrella": [umbrella(), umbrella("#2a8ad0")], "crates": [crates()],
             "rock": [rock(43, "#9a9488")], "bollard": [bollard()], "boat": [boat()]},
    "datacenter": {"server": [server(51), server(52, "#5af07a", "#40c8f0")], "console": [console()],
                   "drum": [cable_drum()], "crates": [crates()]},
}

TURRETS = {"turret_side": turret("side"), "turret_up": turret("up"), "turret_down": turret("down")}

if __name__ == "__main__":
    for theme, kinds in THEMES.items():
        os.makedirs(os.path.join(OUT, theme), exist_ok=True)
        for kind, imgs in kinds.items():
            for i, im in enumerate(imgs):
                if kind != "boat":
                    im = grounded(im)
                im.save(os.path.join(OUT, theme, f"{kind}_{i}.png"))
    for name, im in TURRETS.items():
        im.save(os.path.join(OUT, name + ".png"))
    print("ok")
