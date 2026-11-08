"""EcoRescuer original tilesets v2 (BuiltLevel).

<theme>.png  8x2 atlas, index = row*8 + col
  0-5  floor variants (opaque)            6  wall top        7  wall front
  8    floor under water (collision)      9  dense ground under prop masses (collision)
  10   bridge / walkway                   11 decor A (transparent)   12 decor B (transparent)
  13   closed gate (collision)            14 floor variant             15 special overlay (transparent)
<theme>_water.png, <theme>_path.png  4x4 dual-grid atlases: tile index = TL + 2*TR + 4*BL + 8*BR
  (which of the 4 cells around a grid corner are water / path)."""
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


THEMES = {"ruins": ruins, "factory": factory, "harbor": harbor, "fortress": fortress}

if __name__ == "__main__":
    for name, fn in THEMES.items():
        tiles, water, path = fn()
        atlas(tiles).save(os.path.join(OUT, name + ".png"))
        water.save(os.path.join(OUT, name + "_water.png"))
        path.save(os.path.join(OUT, name + "_path.png"))
    print("ok")
