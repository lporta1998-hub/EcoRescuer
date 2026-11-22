"""EcoRescuer original tilesets v2 (BuiltLevel).

<theme>.png  8x2 atlas, index = row*8 + col
  0-5  floor variants (opaque)            6  wall top        7  wall front
  8    floor under water (collision)      9  dense ground under prop masses (collision)
  10   bridge / walkway                   11 decor A (transparent)   12 decor B (transparent)
  13   closed gate (collision)            14 floor variant             15 special overlay (transparent)
<theme>_water.png, <theme>_path.png  4x4 dual-grid atlases: tile index = TL + 2*TR + 4*BL + 8*BR
  (which of the 4 cells around a grid corner are water / path).
<theme>_grass.png  same, for the lawn (map ";"), only for the themes that have one (city: the park)."""
import math, random, sys, os
from PIL import Image

T = 16
OUT = sys.argv[1] if len(sys.argv) > 1 else "tiles2"
os.makedirs(OUT, exist_ok=True)
TAU = math.tau


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def sh(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def new():
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


def pnoise(u, v, seed=0):
    """Smooth noise periodic over the tile (so dual-grid edges line up)."""
    s = seed * 1.7
    return (0.5 * math.sin(TAU * (2 * u / T) + s) * math.cos(TAU * (v / T) + s * 0.5)
            + 0.35 * math.sin(TAU * (3 * v / T) + 1.3 + s) * math.cos(TAU * (u / T) - s)
            + 0.25 * math.sin(TAU * ((u + v) / T) * 2 + 0.4 + s))


# ---------------------------------------------------------------- floors

def grass(base, seed, flowers=0, clumps=True, tuft=None, light=None, dark=None):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    light = light or sh(base, 1.16)
    dark = dark or sh(base, 0.8)
    for y in range(T):
        for x in range(T):
            n = pnoise(x, y, seed) * 0.05 + rnd.uniform(-0.04, 0.04)
            px[x, y] = sh(base, 1 + n) + (255,)
    if clumps:  # little blades: dark root + light tip
        for _ in range(7):
            x, y = rnd.randrange(T), rnd.randrange(1, T)
            px[x, y] = dark + (255,)
            px[x, (y - 1) % T] = light + (255,)
    if tuft:
        for _ in range(2):
            x, y = rnd.randrange(1, T - 1), rnd.randrange(2, T)
            for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, -2)):
                px[(x + dx) % T, (y + dy) % T] = tuft + (255,)
    for _ in range(flowers):
        x, y = rnd.randrange(T), rnd.randrange(T)
        px[x, y] = rnd.choice([(250, 240, 120), (255, 255, 255), (240, 150, 200)]) + (255,)
    return im


def speckled(base, seed, specks=(), rate=0.05, var=0.06, cracks=0, crack=None):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            c = sh(base, 1 + pnoise(x, y, seed) * 0.04 + rnd.uniform(-var, var))
            if specks and rnd.random() < rate:
                c = rnd.choice(specks)
            px[x, y] = c + (255,)
    for _ in range(cracks):
        x, y = rnd.randrange(T), rnd.randrange(T)
        for _ in range(rnd.randint(3, 6)):
            px[x % T, y % T] = (crack or sh(base, 0.7)) + (255,)
            x += rnd.choice((-1, 0, 1))
            y += 1
    return im


def slabs(base, seam, seed, size=8, var=0.04):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    tone = {(i, j): rnd.uniform(-0.05, 0.05) for i in range(3) for j in range(3)}
    for y in range(T):
        for x in range(T):
            if x % size == 0 or y % size == 0:
                px[x, y] = seam + (255,)
            else:
                k = 1 + tone[(x // size, y // size)] + rnd.uniform(-var, var) + (0.06 if (x % size == 1 or y % size == 1) else 0)
                px[x, y] = sh(base, k) + (255,)
    return im


# ---------------------------------------------------------------- walls

def wall_top(base, seed, moss=None):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = sh(base, 1 + rnd.uniform(-0.05, 0.05)) + (255,)
    for i in range(T):
        px[i, 0] = sh(base, 1.25) + (255,)
        px[0, i] = sh(base, 1.15) + (255,)
        px[i, T - 1] = sh(base, 0.8) + (255,)
    if moss:
        for _ in range(6):
            x, y = rnd.randrange(T), rnd.randrange(T)
            px[x, y] = moss + (255,)
    return im


def wall_front(base, mortar, seed, moss=None, top=None):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        row = y // 4
        off = (row % 2) * 4
        for x in range(T):
            if y % 4 == 3 or (x + off) % 8 == 7:
                px[x, y] = mortar + (255,)
            else:
                k = 1 + rnd.uniform(-0.06, 0.06) + (0.1 if y % 4 == 0 else 0) - y * 0.012
                px[x, y] = sh(base, k) + (255,)
    for x in range(T):
        px[x, 0] = (top or sh(base, 1.3)) + (255,)
        px[x, T - 1] = sh(mortar, 0.6) + (255,)
    if moss:
        for _ in range(5):
            x = rnd.randrange(T)
            for y in range(rnd.randint(1, 4)):
                px[x, y] = moss + (255,)
    return im


def gate(metal, seed):
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            if x % 4 == 1 or y in (3, 12):
                k = 1.25 if x % 4 == 1 and y % 4 == 0 else 1.0
                px[x, y] = sh(metal, k - (0.2 if x % 4 == 2 else 0)) + (255,)
            elif x % 4 == 2:
                px[x, y] = sh(metal, 0.55) + (255,)
            else:
                px[x, y] = (12, 10, 14, 255)
    for x in range(1, T, 4):
        px[x, 0] = (230, 230, 240, 255)
    return im


def planks(base, gap, seed, vertical=False):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    tones = [rnd.uniform(-0.08, 0.08) for _ in range(4)]
    for y in range(T):
        for x in range(T):
            a, b = (x, y) if vertical else (y, x)
            if a % 4 == 3:
                px[x, y] = gap + (255,)
            else:
                k = 1 + tones[a // 4] + (0.1 if a % 4 == 0 else 0) + math.sin(b * 0.9 + a) * 0.03
                px[x, y] = sh(base, k) + (255,)
    for a in range(0, T, 4):  # nails
        x, y = (a + 1, 2) if vertical else (2, a + 1)
        px[x, y] = (40, 34, 30, 255)
        x, y = (a + 1, 13) if vertical else (13, a + 1)
        px[x, y] = (40, 34, 30, 255)
    return im


# ---------------------------------------------------------------- transparent decor

def decor(draw, seed=0):
    im = new()
    draw(im.load(), random.Random(seed))
    return im


def put(px, x, y, c):
    if 0 <= x < T and 0 <= y < T:
        px[x, y] = tuple(c[:3]) + (255,)


def pebble(px, x, y, r, c):
    for dy in range(-r, r + 1):
        for dx in range(-r - 1, r + 2):
            if (dx / (r + 1)) ** 2 + (dy / r) ** 2 <= 1:
                k = 1.25 if dy < 0 and dx < 0 else (0.75 if dy > 0 else 1.0)
                put(px, x + dx, y + dy, sh(c, k))
    for dx in range(-r, r + 1):
        put(px, x + dx, y + r + 1, (20, 18, 22))


def flowers(px, rnd):
    for _ in range(4):
        x, y = rnd.randrange(2, 14), rnd.randrange(3, 14)
        put(px, x, y + 1, (40, 100, 40))
        c = rnd.choice([(250, 230, 110), (255, 255, 255), (240, 140, 190), (150, 170, 255)])
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 0)):
            put(px, x + dx, y + dy, c if (dx, dy) != (0, 0) else (250, 200, 60))
    for _ in range(3):
        x, y = rnd.randrange(1, 15), rnd.randrange(4, 15)
        for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, -2), (1, -1)):
            put(px, x + dx, y + dy, (70, 140, 50) if dy else (40, 90, 36))


def rubble(c):
    def f(px, rnd):
        for _ in range(3):
            pebble(px, rnd.randrange(3, 13), rnd.randrange(3, 12), rnd.randint(1, 2), c)
    return f


def moss_patch(px, rnd):
    for y in range(T):
        for x in range(T):
            d = math.hypot(x - 8, y - 8) + pnoise(x, y, 3) * 2.5
            if d < 6.5 and rnd.random() < 0.85:
                put(px, x, y, (72, 128, 54) if rnd.random() < 0.7 else (100, 160, 70))


def hazard(px, rnd):
    for y in range(T):
        for x in range(T):
            if 5 <= y <= 10:
                put(px, x, y, (230, 180, 40) if ((x + y) // 3) % 2 else (30, 30, 34))


def puddle(c):
    def f(px, rnd):
        for y in range(T):
            for x in range(T):
                d = ((x - 8) / 6.5) ** 2 + ((y - 9) / 4.2) ** 2 + pnoise(x, y, 5) * 0.25
                if d < 1:
                    put(px, x, y, sh(c, 1.35) if (x, y) in ((6, 7), (7, 7), (10, 9)) else c)
    return f


def paint_line(px, rnd):
    for x in range(T):
        for y in (7, 8):
            put(px, x, y, (230, 200, 60) if x % 8 < 6 else (0, 0, 0))
    for x in range(T):
        if x % 8 >= 6:
            px[x, 7] = (0, 0, 0, 0)
            px[x, 8] = (0, 0, 0, 0)


def bolts(px, rnd):
    for _ in range(4):
        x, y = rnd.randrange(2, 14), rnd.randrange(2, 14)
        put(px, x, y, (150, 156, 166))
        put(px, x + 1, y, (90, 96, 106))
        put(px, x, y + 1, (40, 40, 46))
    for _ in range(2):
        x, y = rnd.randrange(3, 12), rnd.randrange(3, 12)
        for i in range(4):
            put(px, x + i, y + (i // 2), (110, 80, 50))


def rope(px, rnd):
    for a in range(0, 360, 12):
        for r in (3, 5):
            x = 8 + round(r * math.cos(math.radians(a)))
            y = 8 + round(r * 0.7 * math.sin(math.radians(a)))
            put(px, x, y, (200, 166, 106) if a % 24 else (140, 110, 66))


def bones(px, rnd):
    for _ in range(2):
        x, y = rnd.randrange(3, 11), rnd.randrange(4, 12)
        for i in range(5):
            put(px, x + i, y, (226, 220, 200))
        for dx in (0, 4):
            put(px, x + dx, y - 1, (240, 236, 220))
            put(px, x + dx, y + 1, (200, 194, 176))
    x, y = rnd.randrange(3, 12), rnd.randrange(3, 12)
    for dx in range(3):  # a crushed can
        put(px, x + dx, y, (200, 50, 40))
        put(px, x + dx, y + 1, (160, 36, 30))


def scrap(px, rnd):
    for _ in range(4):
        x, y = rnd.randrange(2, 13), rnd.randrange(2, 13)
        c = rnd.choice([(150, 90, 50), (90, 110, 140), (120, 120, 126)])
        for i in range(rnd.randint(2, 4)):
            put(px, x + i, y, c)
            put(px, x + i, y + 1, sh(c, 0.7))


def red_plate(px, rnd):
    for y in range(T):
        for x in range(T):
            if 2 <= x <= 13 and 2 <= y <= 13:
                c = (70, 66, 74) if (x - y) % 6 else (150, 40, 40)
                if x in (2, 13) or y in (2, 13):
                    c = (110, 104, 116)
                put(px, x, y, c)


# ---------------------------------------------------------------- dual grid

def dual(inside, edge_in, edge_out, seed, noise=0.07, shadow=None, sparkle=None, rim_glow=None):
    """16 tiles; `inside(x, y, depth)` gives the colour of a covered pixel."""
    sheet = Image.new("RGBA", (T * 4, T * 4), (0, 0, 0, 0))
    for idx in range(16):
        tl, tr, bl, br = idx & 1, (idx >> 1) & 1, (idx >> 2) & 1, (idx >> 3) & 1
        tile = new()
        px = tile.load()
        val = {}
        for y in range(T):
            for x in range(T):
                fx, fy = (x + 0.5) / T, (y + 0.5) / T
                v = (tl * (1 - fx) * (1 - fy) + tr * fx * (1 - fy) + bl * (1 - fx) * fy + br * fx * fy)
                # round off the bilinear blend a bit and wobble the edge
                val[(x, y)] = v + pnoise(x, y, seed) * noise * (1 - abs(v - 0.5) * 1.6)
        for y in range(T):
            for x in range(T):
                v = val[(x, y)]
                if v >= 0.5:
                    if v < 0.56:
                        c = edge_out
                    elif v < 0.62:
                        c = edge_in
                    else:
                        c = inside(x, y, min(1.0, (v - 0.62) / 0.4))
                    px[x, y] = tuple(c[:3]) + (255,)
                elif shadow and v > 0.44:
                    px[x, y] = shadow
        sheet.paste(tile, ((idx % 4) * T, (idx // 4) * T))
    return sheet


def water_fn(base, deep, hl, seed):
    rnd = random.Random(seed)
    spark = {(rnd.randrange(T), rnd.randrange(T)) for _ in range(5)}

    def f(x, y, d):
        c = mix(base, deep, d * 0.8)
        w = math.sin(TAU * (x / T) * 2 + y * 0.9) + math.sin(TAU * (y / T) * 3)
        if w > 1.5:
            c = mix(c, hl, 0.55)
        if (x, y) in spark:
            c = hl
        return c
    return f


def cobble_fn(base, mortar, seed, n=3):
    rnd = random.Random(seed)
    pts = []
    for j in range(n):
        for i in range(n):
            pts.append(((i + 0.5 + rnd.uniform(-0.3, 0.3)) * T / n, (j + 0.5 + rnd.uniform(-0.3, 0.3)) * T / n, rnd.uniform(-0.08, 0.08)))

    def near(x, y):
        best = []
        for (px_, py_, t) in pts:
            for ox in (-T, 0, T):
                for oy in (-T, 0, T):
                    best.append((math.hypot(x - px_ - ox, y - py_ - oy), px_ + ox, py_ + oy, t))
        best.sort()
        return best

    def f(x, y, d):
        b = near(x + 0.5, y + 0.5)
        if b[1][0] - b[0][0] < 1.1:
            return mortar
        dx, dy = x + 0.5 - b[0][1], y + 0.5 - b[0][2]
        k = 1 + b[0][3] + (0.12 if dx + dy < -2 else (-0.1 if dx + dy > 2 else 0))
        return sh(base, k)
    return f


def slab_fn(base, seam, seed, size=8):
    rnd = random.Random(seed)
    tone = {(i, j): rnd.uniform(-0.06, 0.06) for i in range(3) for j in range(3)}

    def f(x, y, d):
        if x % size == 0 or y % size == 0:
            return seam
        return sh(base, 1 + tone[(x // size, y // size)] + (0.07 if x % size == 1 or y % size == 1 else 0) + rnd.uniform(-0.03, 0.03))
    return f


def noise_fn(base, seed, specks=(), rate=0.06, var=0.06):
    rnd = random.Random(seed)
    cache = {}

    def f(x, y, d):
        if (x, y) not in cache:
            c = sh(base, 1 + rnd.uniform(-var, var))
            if specks and rnd.random() < rate:
                c = rnd.choice(specks)
            cache[(x, y)] = c
        return cache[(x, y)]
    return f


def atlas(tiles):
    im = Image.new("RGBA", (T * 8, T * 2), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        im.paste(t, ((i % 8) * T, (i // 8) * T))
    return im


# ---------------------------------------------------------------- themes

def ruins():
    g = hx("#4f9a3e")
    floors = [grass(g, s, flowers=(1 if s % 3 == 0 else 0), tuft=hx("#6cb850") if s % 2 else None) for s in range(6)]
    under = grass(sh(g, 0.92), 50, clumps=False)
    dense = grass(hx("#24502a"), 51, clumps=True, light=hx("#336a34"), dark=hx("#173a1e"))
    stone = hx("#a8a292")
    tiles = floors[:6] + [wall_top(stone, 1, moss=hx("#6a9a48")), wall_front(sh(stone, 0.9), hx("#5a564c"), 2, moss=hx("#5a8a40")),
             under, grass(g, 52, clumps=True), planks(hx("#9a6a3c"), hx("#3a2616"), 3), decor(flowers, 4),
             decor(rubble(hx("#a09a8a")), 5), gate(hx("#5a5e6a"), 6), dense, decor(moss_patch, 7)]
    water = dual(water_fn(hx("#3a8ec8"), hx("#235e9a"), hx("#bfe8ff"), 1), hx("#d8f2ff"), hx("#4e3a26"), 11,
                 shadow=(10, 30, 10, 90))
    path = dual(cobble_fn(hx("#b4ac98"), hx("#6e6656"), 2), hx("#8a826e"), hx("#4a5a34"), 12, noise=0.09)
    return tiles, water, path


def factory():
    a = hx("#5a5c62")
    floors = [speckled(a, s, specks=[sh(a, 0.8), sh(a, 1.15)], rate=0.05, cracks=1 if s % 2 else 0) for s in range(6)]
    under = speckled(sh(a, 0.9), 50)
    dense = speckled(hx("#2a2c32"), 51, specks=[hx("#3a3c44")], rate=0.2)
    tiles = floors + [wall_top(hx("#6a5048"), 1), wall_front(hx("#7a4a3a"), hx("#3a2620"), 2, top=hx("#a07060")), under, floors[3],
                      planks(hx("#8a929e"), hx("#2a2e36"), 3, vertical=True), decor(bolts, 4), decor(puddle(hx("#1c1a22")), 5),
                      gate(hx("#8a8e96"), 6), dense, decor(hazard, 7)]
    water = dual(water_fn(hx("#5ec83a"), hx("#2e8a24"), hx("#d8ff8a"), 1), hx("#b8f060"), hx("#2a2a2e"), 11, shadow=(0, 0, 0, 90))
    path = dual(slab_fn(hx("#9c9a94"), hx("#6a6862"), 2), hx("#e0b830"), hx("#2a2a2e"), 12, noise=0.06)
    return tiles, water, path


def harbor():
    c = hx("#9a9a96")
    floors = [slabs(c, sh(c, 0.75), s, size=8) for s in range(4)] + [speckled(c, 20, specks=[sh(c, 0.85)]), speckled(c, 21, cracks=1)]
    under = slabs(sh(c, 0.85), sh(c, 0.65), 50)
    dense = speckled(hx("#3a3c40"), 51)
    tiles = floors + [wall_top(hx("#7a4036"), 1), wall_front(hx("#9a4a3a"), hx("#4a2420"), 2, top=hx("#c07060")), under, floors[2],
                      planks(hx("#8a6a48"), hx("#2e2216"), 3, vertical=True), decor(rope, 4), decor(puddle(hx("#22222a")), 5),
                      gate(hx("#6a6e76"), 6), dense, decor(paint_line, 7)]
    water = dual(water_fn(hx("#2a6a9a"), hx("#174a72"), hx("#a8d8f0"), 1), hx("#e8f6ff"), hx("#5a5a58"), 11, shadow=(0, 0, 0, 80))
    path = dual(noise_fn(hx("#4a4a50"), 2, specks=[hx("#5a5a62"), hx("#3a3a40")], rate=0.1), hx("#606068"), hx("#2e2e34"), 12, noise=0.05)
    return tiles, water, path


def fortress():
    d = hx("#6a5a48")
    floors = [speckled(d, s, specks=[sh(d, 0.75), sh(d, 1.2), hx("#5a6a40")], rate=0.07) for s in range(6)]
    under = speckled(sh(d, 0.9), 50)
    dense = speckled(hx("#2e2620"), 51, specks=[hx("#3e342a")], rate=0.2)
    tiles = floors + [wall_top(hx("#4e4852"), 1), wall_front(hx("#5a5460"), hx("#2a2630"), 2, top=hx("#7a7484")), under, floors[2],
                      planks(hx("#7a5a46"), hx("#2a1e16"), 3), decor(bones, 4), decor(scrap, 5),
                      gate(hx("#7a7e86"), 6), dense, decor(red_plate, 7)]
    water = dual(water_fn(hx("#6a4a7a"), hx("#3e2a4e"), hx("#c0a0e0"), 1), hx("#a8d040"), hx("#2a2018"), 11, shadow=(0, 0, 0, 90))
    path = dual(cobble_fn(hx("#5e5862"), hx("#46404a"), 2), hx("#46404c"), hx("#2a2420"), 12, noise=0.1)
    return tiles, water, path


# ---------------------------------------------------------------- pieces of the five campaign themes

def facade(base, mortar, seed, window=(70, 110, 150), lit=(250, 220, 140)):
    """Building front: plaster with two windows, some of them lit."""
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            k = 1 + rnd.uniform(-0.04, 0.04) - y * 0.008
            px[x, y] = sh(base, k) + (255,)
    for x in range(T):
        px[x, 0] = sh(base, 1.3) + (255,)
        px[x, 1] = sh(base, 0.7) + (255,)
        px[x, T - 1] = mortar + (255,)
    for wx in (2, 9):
        on = rnd.random() < 0.35
        for y in range(4, 11):
            for x in range(wx, wx + 5):
                edge = x in (wx, wx + 4) or y in (4, 10)
                c = sh(base, 0.6) if edge else (lit if on else window)
                if not edge and not on and (x - wx) + (y - 4) < 3:
                    c = mix(window, (230, 240, 250), 0.5)
                px[x, y] = tuple(c) + (255,)
        for x in range(wx, wx + 5):
            px[x, 11] = sh(base, 1.2) + (255,)
    return im


def roof(base, seed, ridge=None):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            k = 1 + rnd.uniform(-0.04, 0.04) + (0.08 if (x + y * 3) % 8 == 0 else 0)
            px[x, y] = sh(base, k) + (255,)
    for i in range(T):
        px[i, 0] = (ridge or sh(base, 1.3)) + (255,)
        px[0, i] = sh(base, 1.15) + (255,)
        px[i, T - 1] = sh(base, 0.72) + (255,)
    for _ in range(2):  # vents / AC units
        x, y = rnd.randrange(3, 11), rnd.randrange(3, 10)
        for dx in range(3):
            for dy in range(2):
                px[x + dx, y + dy] = sh(base, 1.35 if dy == 0 else 0.85) + (255,)
    return im


def rack(seed, body=(36, 40, 52), led=(80, 240, 220), led2=(250, 80, 200)):
    """Server rack front: slots with blinking LEDs."""
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = sh(body, 1 + rnd.uniform(-0.03, 0.03)) + (255,)
    for x in range(T):
        px[x, 0] = sh(body, 1.8) + (255,)
        px[x, T - 1] = sh(body, 0.5) + (255,)
    for y in range(2, T - 2, 3):
        for x in range(1, T - 1):
            px[x, y] = sh(body, 0.6) + (255,)
            px[x, y + 1] = sh(body, 1.25) + (255,)
        for x in range(3, 12, 3):
            if rnd.random() < 0.6:
                px[x, y + 1] = (led if rnd.random() < 0.75 else led2) + (255,)
        px[13, y + 1] = (90, 96, 110, 255)
    for y in range(T):
        px[0, y] = sh(body, 1.4) + (255,)
        px[T - 1, y] = sh(body, 0.55) + (255,)
    return im


def tech_floor(base, line, seed, glow=None):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            c = sh(base, 1 + rnd.uniform(-0.03, 0.03))
            if x % 8 == 0 or y % 8 == 0:
                c = line
            elif x % 8 == 1 or y % 8 == 1:
                c = sh(base, 1.12)
            px[x, y] = c + (255,)
    for (x, y) in ((3, 3), (12, 3), (3, 12), (12, 12)):
        px[x, y] = sh(base, 1.4) + (255,)
    if glow:
        y = rnd.choice((4, 11))
        for x in range(2, 15):
            if x % 8:
                px[x, y] = glow + (255,)
    return im


def hatch(base, line, seed, period=8):
    """Solid wall seen from above, drawn like a floor plan: diagonal hatching."""
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            d = (x + y) % period
            c = line if d == 0 else (sh(base, 1.1) if d == 1 else sh(base, 1 + rnd.uniform(-0.03, 0.03)))
            px[x, y] = c + (255,)
    return im


def snow(base, seed, sparkle=True, prints=False):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            n = pnoise(x, y, seed) * 0.035 + rnd.uniform(-0.02, 0.02)
            px[x, y] = sh(base, 1 + n) + (255,)
    for _ in range(5):  # soft blue drifts
        x, y = rnd.randrange(T), rnd.randrange(T)
        for dx in range(rnd.randint(2, 4)):
            px[(x + dx) % T, y] = mix(base, (150, 180, 220), 0.35) + (255,)
    if sparkle:
        for _ in range(3):
            px[rnd.randrange(T), rnd.randrange(T)] = (255, 255, 255, 255)
    if prints:
        for i in range(3):
            x, y = 5 + (i % 2) * 5, 2 + i * 5
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (0, 2)):
                px[x + dx, y + dy] = mix(base, (120, 150, 200), 0.4) + (255,)
    return im


def sand(base, seed, shells=0):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            n = math.sin(TAU * (x + y * 0.5) / T * 2 + seed) * 0.03 + rnd.uniform(-0.04, 0.04)
            c = sh(base, 1 + n)
            if rnd.random() < 0.04:
                c = sh(base, 0.82)
            px[x, y] = c + (255,)
    for _ in range(shells):
        x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
        px[x, y] = (250, 240, 230, 255)
        px[x + 1, y] = (240, 190, 170, 255)
    return im


def ice(base, seed):
    rnd = random.Random(seed)
    im = new()
    px = im.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = sh(base, 1 + pnoise(x, y, seed) * 0.05) + (255,)
    for _ in range(2):  # cracks
        x, y = rnd.randrange(T), rnd.randrange(T)
        for _ in range(7):
            px[x % T, y % T] = (235, 250, 255, 255)
            x += rnd.choice((1, 1, 0))
            y += rnd.choice((-1, 0, 1))
    return im


def ferns(px, rnd):
    for _ in range(2):
        x, y = rnd.randrange(4, 12), rnd.randrange(8, 14)
        for i in range(5):
            put(px, x - i, y - i // 2, (52, 120, 60))
            put(px, x + i, y - i // 2, (52, 120, 60))
            put(px, x, y - i, (70, 150, 70))
    x, y = rnd.randrange(3, 13), rnd.randrange(3, 8)  # a mushroom
    for dx in (-1, 0, 1):
        put(px, x + dx, y, (200, 50, 40))
    put(px, x, y - 1, (230, 80, 60))
    put(px, x - 1, y, (250, 240, 230))
    put(px, x, y + 1, (236, 226, 200))


def leaves(px, rnd):
    for _ in range(9):
        x, y = rnd.randrange(1, 15), rnd.randrange(1, 15)
        c = rnd.choice([(200, 120, 40), (170, 70, 40), (220, 170, 60), (120, 90, 40)])
        put(px, x, y, c)
        put(px, x + 1, y, sh(c, 0.8))


def snow_rocks(px, rnd):
    for _ in range(2):
        x, y = rnd.randrange(4, 12), rnd.randrange(5, 12)
        pebble(px, x, y, 2, (110, 120, 140))
        for dx in range(-2, 2):
            put(px, x + dx, y - 2, (245, 250, 255))


def crystals(px, rnd):
    for _ in range(2):
        x, y = rnd.randrange(4, 12), rnd.randrange(7, 14)
        h = rnd.randint(4, 7)
        for i in range(h):
            w = 1 if i > h - 3 else 2
            for dx in range(-w + 1, w):
                put(px, x + dx, y - i, (120, 230, 240) if dx <= 0 else (60, 160, 200))
        put(px, x, y - h, (230, 255, 255))


def manhole(px, rnd):
    for y in range(T):
        for x in range(T):
            d = math.hypot(x - 7.5, y - 7.5)
            if d < 6:
                c = (70, 72, 80) if d > 5 else ((96, 98, 106) if (x + y) % 3 else (60, 62, 70))
                put(px, x, y, c)


def litter(px, rnd):
    for _ in range(3):
        x, y = rnd.randrange(2, 13), rnd.randrange(2, 13)
        c = rnd.choice([(230, 230, 220), (200, 60, 50), (60, 120, 200), (120, 180, 80)])
        put(px, x, y, c)
        put(px, x + 1, y, sh(c, 0.8))
        put(px, x, y + 1, sh(c, 0.7))


def crosswalk(px, rnd):
    for y in range(T):
        for x in range(T):
            if (x // 4) % 2 == 0 and 1 <= y <= 14:
                put(px, x, y, (236, 236, 230))


def shells(px, rnd):
    for _ in range(3):
        x, y = rnd.randrange(3, 13), rnd.randrange(3, 13)
        c = rnd.choice([(250, 230, 220), (240, 170, 150), (250, 210, 120)])
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1)):
            put(px, x + dx, y + dy, c if dy == 0 else sh(c, 1.1))
        put(px, x, y + 1, sh(c, 0.7))
    x, y = rnd.randrange(4, 12), rnd.randrange(4, 12)  # a starfish
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, -2), (1, 2), (-1, 2)):
        put(px, x + dx, y + dy, (240, 120, 80))


def seaweed(px, rnd):
    for _ in range(3):
        x, y = rnd.randrange(2, 14), rnd.randrange(8, 15)
        for i in range(rnd.randint(3, 6)):
            put(px, x + (1 if i % 2 else 0), y - i, (60, 120, 70) if i % 2 else (90, 150, 80))


def cables(px, rnd):
    for k, c in enumerate(((40, 200, 220), (230, 70, 190), (60, 60, 70))):
        y0 = 5 + k * 3
        for x in range(T):
            y = y0 + round(math.sin(x * 0.5 + k) * 1.2)
            put(px, x, y, c)
            put(px, x, y + 1, sh(c, 0.55))


def vent(px, rnd):
    for y in range(3, 13):
        for x in range(2, 14):
            c = (30, 34, 44) if y % 2 else (90, 96, 110)
            if x in (2, 13) or y in (3, 12):
                c = (120, 126, 140)
            put(px, x, y, c)


def circuit(px, rnd):
    for x in range(T):
        put(px, x, 8, (60, 230, 220))
    for x in (3, 11):
        for y in range(3, 8):
            put(px, x, y, (60, 230, 220))
        put(px, x, 2, (230, 120, 240))
    for x in (7,):
        for y in range(9, 14):
            put(px, x, y, (60, 230, 220))
        put(px, x, 14, (230, 120, 240))


def energy_gate(px, rnd):
    for y in range(T):
        for x in range(T):
            if x % 4 == 1:
                put(px, x, y, (120, 250, 255) if (y // 2) % 2 else (60, 190, 240))
            elif x % 4 in (0, 2):
                put(px, x, y, (30, 80, 120))
            else:
                put(px, x, y, (10, 14, 24))


def asphalt_fn(base, seed):
    """Asphalt: fine grit and a few darker patches."""
    f = noise_fn(base, seed, specks=[sh(base, 1.2), sh(base, 0.85)], rate=0.08, var=0.04)

    def g(x, y, d):
        if pnoise(x, y, seed) > 0.75:
            return sh(base, 0.88)
        return f(x, y, d)
    return g


def boards_fn(base, gap, seed):
    rnd = random.Random(seed)
    tones = [rnd.uniform(-0.07, 0.07) for _ in range(4)]

    def f(x, y, d):
        if y % 4 == 3:
            return gap
        return sh(base, 1 + tones[y // 4] + (0.08 if y % 4 == 0 else 0) + math.sin(x * 0.8 + y) * 0.03)
    return f


def glow_fn(base, deep, hl, seed):
    """Coolant pool: flat glowing liquid with slow bands."""
    def f(x, y, d):
        c = mix(base, deep, d * 0.7)
        if (x + y * 2) % 11 == 0:
            c = mix(c, hl, 0.6)
        return c
    return f


# ---------------------------------------------------------------- campaign themes (Forest, Snow Path, City, Lake, AI DataCenter)

def forest():
    g = hx("#3f8a3a")
    floors = [grass(g, 60 + s, flowers=(2 if s == 0 else 0), tuft=hx("#5aa646") if s % 2 else None,
                    light=hx("#5fae4a"), dark=hx("#2c6a30")) for s in range(6)]
    under = grass(sh(g, 0.9), 70, clumps=False)
    dense = grass(hx("#1d4424"), 71, clumps=True, light=hx("#2c5c30"), dark=hx("#123018"))
    rock = hx("#7c8478")
    tiles = floors + [wall_top(rock, 72, moss=hx("#4f8a3c")), wall_front(sh(rock, 0.9), hx("#3e4440"), 73, moss=hx("#4a8038")),
                      under, grass(g, 74, flowers=3), planks(hx("#8a5a32"), hx("#33200f"), 75), decor(ferns, 76),
                      decor(leaves, 77), gate(hx("#5a5e6a"), 78), dense, decor(moss_patch, 79)]
    water = dual(water_fn(hx("#2f86a8"), hx("#1b5a7e"), hx("#b8eaf0"), 61), hx("#cdeee8"), hx("#3a2a1a"), 62,
                 shadow=(8, 24, 10, 90))
    path = dual(noise_fn(hx("#9a7450"), 63, specks=[hx("#b08a62"), hx("#7a5a3c"), hx("#8a8478")], rate=0.12),
                hx("#7e6040"), hx("#3e5a2c"), 64, noise=0.1)
    return tiles, water, path


def snowpath():
    sn = hx("#e6eef8")
    floors = [snow(sn, 80 + s, prints=(s == 4)) for s in range(6)]
    under = ice(hx("#a8d4ec"), 90)
    dense = speckled(hx("#2a3242"), 91, specks=[hx("#3a4456"), hx("#e8f0fa")], rate=0.08)
    rock = hx("#5e6a80")
    tiles = floors + [wall_top(hx("#eef4fc"), 92), wall_front(rock, hx("#323a4a"), 93, top=hx("#f4f8ff")),
                      under, snow(sn, 94), planks(hx("#7a5a42"), hx("#2a1e16"), 95), decor(snow_rocks, 96),
                      decor(crystals, 97), gate(hx("#8a9ab0"), 98), dense, decor(lambda px, r: [put(px, 3 + i, 8 + (i % 3), (200, 225, 245)) for i in range(10)], 99)]
    water = dual(water_fn(hx("#5ab0d8"), hx("#2e78a8"), hx("#eaffff"), 81), hx("#f4fbff"), hx("#8aa0b8"), 82,
                 shadow=(20, 40, 70, 70))
    path = dual(cobble_fn(hx("#7a8498"), hx("#4e566a"), 83), hx("#9aa4b8"), hx("#c8d6e8"), 84, noise=0.09)
    return tiles, water, path


def city():
    pv = hx("#b4b0a8")
    floors = [slabs(pv, sh(pv, 0.78), 100 + s, size=8) for s in range(4)] + [speckled(pv, 104, specks=[sh(pv, 0.85)]), speckled(pv, 105, cracks=1)]
    under = slabs(sh(pv, 0.85), sh(pv, 0.65), 106)
    dense = roof(hx("#4a4654"), 107)
    tiles = floors + [roof(hx("#5a5462"), 108, ridge=hx("#8a8292")), facade(hx("#c8a48a"), hx("#5a4436"), 109),
                      under, slabs(pv, sh(pv, 0.78), 110), planks(hx("#7a828e"), hx("#2a2e36"), 111, vertical=True), decor(manhole, 112),
                      decor(litter, 113), gate(hx("#6a6e76"), 114), dense, decor(crosswalk, 115)]
    water = dual(water_fn(hx("#3a7a9a"), hx("#24546e"), hx("#b0dcf0"), 101), hx("#dcecf4"), hx("#6a6660"), 102, shadow=(0, 0, 0, 80))
    path = dual(asphalt_fn(hx("#46464e"), 103), hx("#5a5a62"), hx("#8a8680"), 104, noise=0.04)
    # the park's lawn, with a stone curb
    lawn = hx("#4e9a40")
    lawn_tiles = [grass(lawn, 116 + s, flowers=(1 if s == 0 else 0), light=hx("#68b450"), dark=hx("#357a30")) for s in range(4)]
    grass_ = dual(lambda x, y, d: lawn_tiles[(x // 8 + y // 8) % 4].getpixel((x, y))[:3], hx("#3c7e34"), hx("#8e8a82"), 117, noise=0.05)
    return tiles, water, path, grass_


def lake():
    sd = hx("#e2c890")
    floors = [sand(sd, 120 + s, shells=(1 if s % 3 == 0 else 0)) for s in range(6)]
    under = sand(sh(sd, 0.85), 126)
    dense = roof(hx("#8a4a3a"), 127, ridge=hx("#b06a50"))
    tiles = floors + [roof(hx("#a85a42"), 128, ridge=hx("#d08060")), wall_front(hx("#e4d8c0"), hx("#9a8a70"), 129, top=hx("#fff4e0")),
                      under, sand(sd, 130, shells=2), planks(hx("#a87a4a"), hx("#4a3018"), 131, vertical=True), decor(shells, 132),
                      decor(seaweed, 133), gate(hx("#6a6e76"), 134), dense, decor(rope, 135)]
    water = dual(water_fn(hx("#2ab0c0"), hx("#16788e"), hx("#d8fbff"), 121), hx("#f4ffff"), hx("#c8a868"), 122, shadow=(20, 60, 60, 60))
    path = dual(boards_fn(hx("#b08250"), hx("#5a3c20"), 123), hx("#8a6038"), hx("#c8a870"), 124, noise=0.03)
    return tiles, water, path


def datacenter():
    fl = hx("#3a4052")
    floors = [tech_floor(fl, hx("#262a38"), 140 + s) for s in range(5)] + [tech_floor(fl, hx("#262a38"), 145, glow=hx("#3ad8e0"))]
    under = tech_floor(sh(fl, 0.8), hx("#1e2230"), 146)
    # walls stand out from the dark floor: light steel tops, hatched where they are thick
    dense = hatch(hx("#6a7388"), hx("#4e566a"), 147)
    tiles = floors + [wall_top(hx("#8a94aa"), 148), rack(149),
                      under, floors[1], planks(hx("#6a7286"), hx("#1a1e28"), 150, vertical=True), decor(cables, 151),
                      decor(vent, 152), decor(energy_gate, 153), dense, decor(circuit, 154)]
    water = dual(glow_fn(hx("#38d8e0"), hx("#1a8aa8"), hx("#d8ffff"), 141), hx("#a8ffff"), hx("#1a1e2a"), 142, shadow=(0, 0, 0, 100))
    path = dual(slab_fn(hx("#2a2e3e"), hx("#33505c"), 143, size=16), hx("#2e8a9a"), hx("#1a1e2c"), 144, noise=0.04)
    return tiles, water, path


def passage():
    """Marker under a teleport between two areas of a map: a glowing ring of stones."""
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = im.load()
    for y in range(32):
        for x in range(32):
            d = math.hypot((x - 15.5) / 1.0, (y - 15.5) / 0.75)
            if d < 9:
                a = int(110 * (1 - d / 9))
                px[x, y] = (150, 255, 220, a)
            elif d < 12.5:
                k = 1.2 if y < 14 else 0.8
                ang = math.atan2(y - 15.5, x - 15.5)
                c = (120, 126, 140) if int((ang + 4) * 3) % 2 else (96, 100, 112)
                px[x, y] = sh(c, k) + (255,)
            elif d < 13.5:
                px[x, y] = (30, 30, 40, 255)
    return im


THEMES = {"ruins": ruins, "factory": factory, "harbor": harbor, "fortress": fortress,
          "forest": forest, "snow": snowpath, "city": city, "lake": lake, "datacenter": datacenter}

if __name__ == "__main__":
    for name, fn in THEMES.items():
        tiles, water, path, *grass_ = fn()
        atlas(tiles).save(os.path.join(OUT, name + ".png"))
        water.save(os.path.join(OUT, name + "_water.png"))
        path.save(os.path.join(OUT, name + "_path.png"))
        if grass_:
            grass_[0].save(os.path.join(OUT, name + "_grass.png"))
    passage().save(os.path.join(OUT, "passage.png"))
    print("ok")
