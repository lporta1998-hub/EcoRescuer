"""Organic text maps for the new EcoRescuer levels (BuiltLevel v2).

Terrain:  .  floor   ,  path / plaza   _  special overlay   #  wall   ~  water   =  bridge
          ;  lawn (City park)
          &  dense mass (forest, machinery, containers, junk mountains: blocks, filled with big props)
          o O  small decor        T  big prop (blocks)   x  medium prop (blocks)   X  small prop (blocks)
          b  boat (on water)      c  the theme's special prop (City cars, Lake junk heaps)
Things:   P S D B E L C H F R K Z G   (see built_level.gd)"""
import random, math, sys, os
from collections import deque

WALK = set(".,_=oO;") | set("PBECHFRKDSLZGW")
FREE = set(".,_;")


class Map:
    def __init__(self, w, h, fill="."):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]
        self.extras = []  # lines after "---" (teleports, turrets)

    def get(self, x, y):
        return self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else " "

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = c

    def rect(self, x0, y0, x1, y1, c, only=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if only is None or self.get(x, y) in only:
                    self.set(x, y, c)

    def outline(self, x0, y0, x1, y1, c):
        for x in range(x0, x1 + 1):
            self.set(x, y0, c)
            self.set(x, y1, c)
        for y in range(y0, y1 + 1):
            self.set(x0, y, c)
            self.set(x1, y, c)

    def disc(self, cx, cy, r, c, rng=None, wob=0.0, only=None, sy=1.0):
        R = int(r * (1 + wob)) + 2
        ph = rng.uniform(0, 6.28) if rng else 0
        for y in range(int(cy - R), int(cy + R) + 1):
            for x in range(int(cx - R), int(cx + R) + 1):
                a = math.atan2(y - cy, x - cx)
                rr = r * (1 + wob * (0.6 * math.sin(3 * a + ph) + 0.4 * math.sin(5 * a + ph * 2)))
                if math.hypot(x - cx, (y - cy) / sy) <= rr and (only is None or self.get(x, y) in only):
                    self.set(x, y, c)

    def walkable(self, x, y):
        return self.get(x, y) in WALK

    def reach(self, start):
        dist = {start: 0}
        q = deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in dist and self.walkable(*n):
                    dist[n] = dist[(x, y)] + 1
                    q.append(n)
        return dist

    def open_cell(self, x, y, r=1):
        return all(self.get(x + dx, y + dy) in FREE for dx in range(-r, r + 1) for dy in range(-r, r + 1))

    def place(self, rng, dist, ch, n, min_d=0, max_d=10**9, spacing=6, taken=None, r=1):
        taken = taken if taken is not None else []
        cells = [c for c, d in dist.items() if min_d <= d <= max_d and self.open_cell(*c, r)]
        rng.shuffle(cells)
        placed = 0
        for (x, y) in cells:
            if placed >= n:
                break
            if any(abs(x - tx) + abs(y - ty) < spacing for tx, ty in taken):
                continue
            self.set(x, y, ch)
            taken.append((x, y))
            placed += 1
        return placed

    def text(self):
        out = "\n".join("".join(r).rstrip() for r in self.g) + "\n"
        if self.extras:
            out += "---\n" + "\n".join(self.extras) + "\n"
        return out


class Noise:
    """Value noise with octaves (deterministic)."""
    def __init__(self, seed, scale):
        self.r = random.Random(seed)
        self.scale = scale
        self.grid = {}

    def _v(self, i, j):
        if (i, j) not in self.grid:
            self.grid[(i, j)] = self.r.random()
        return self.grid[(i, j)]

    def _smooth(self, x, y):
        i, j = math.floor(x), math.floor(y)
        fx, fy = x - i, y - j
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = self._v(i, j) + (self._v(i + 1, j) - self._v(i, j)) * fx
        b = self._v(i, j + 1) + (self._v(i + 1, j + 1) - self._v(i, j + 1)) * fx
        return a + (b - a) * fy

    def __call__(self, x, y):
        s = self.scale
        return (self._smooth(x / s, y / s) * 0.6 + self._smooth(x / s * 2 + 17, y / s * 2 + 31) * 0.28
                + self._smooth(x / s * 4 + 5, y / s * 4 + 9) * 0.12)


def forest_border(m, rng, depth=3, extra=4, ch="&", seed=0):
    """Thick, wobbly mass around the map edge."""
    n = Noise(seed + 100, 7)
    for y in range(m.h):
        for x in range(m.w):
            d = min(x, y, m.w - 1 - x, m.h - 1 - y)
            if d < depth + n(x, y) * extra:
                m.set(x, y, ch)


def masses(m, rng, threshold, ch="&", scale=9, seed=0, only="."):
    n = Noise(seed, scale)
    for y in range(m.h):
        for x in range(m.w):
            if m.get(x, y) in only and n(x, y) > threshold:
                m.set(x, y, ch)


def river(m, rng, x0, width=(3, 5), amp=8, freq=0.07, ch="~", seed=0):
    n = Noise(seed + 7, 11)
    centers = []
    for y in range(m.h):
        cx = x0 + amp * math.sin(y * freq + 1.3) + (n(0, y) - 0.5) * 8
        w = width[0] + (width[1] - width[0]) * n(50, y)
        centers.append(cx)
        for x in range(int(cx - w / 2), int(cx + w / 2) + 1):
            m.set(x, y, ch)
    return centers


def bridge(m, y, centers, half, ch="="):
    cx = int(centers[y])
    xs = [x for x in range(cx - half - 6, cx + half + 7) if m.get(x, y) == "~"]
    if not xs:
        return
    for yy in (y - 1, y, y + 1):
        for x in range(xs[0] - 1, xs[-1] + 2):
            if m.get(x, yy) == "~":
                m.set(x, yy, ch)
            elif m.get(x, yy) in "&TxX":
                m.set(x, yy, ".")
    # clear landings on both sides
    for x in list(range(xs[0] - 4, xs[0])) + list(range(xs[-1] + 1, xs[-1] + 5)):
        for yy in (y - 1, y, y + 1):
            if m.get(x, yy) in "&TxX#":
                m.set(x, yy, ".")


def carve_path(m, rng, a, b, width=1, ch=",", over=".&TxXoO", wiggle=0.35):
    """Wandering path from a to b (drunk walk biased to the target)."""
    x, y = a
    steps = 0
    while (x, y) != tuple(b) and steps < 4000:
        steps += 1
        dx, dy = b[0] - x, b[1] - y
        if rng.random() < wiggle:
            sx, sy = rng.choice(((1, 0), (-1, 0), (0, 1), (0, -1)))
        elif abs(dx) > abs(dy) or (abs(dx) == abs(dy) and rng.random() < 0.5):
            sx, sy = (1 if dx > 0 else -1), 0
        else:
            sx, sy = 0, (1 if dy > 0 else -1)
        nx, ny = x + sx, y + sy
        if not (3 <= nx < m.w - 3 and 3 <= ny < m.h - 3):
            continue
        if m.get(nx, ny) in "~#=" and m.get(x, y) not in "~=":
            # don't wade through water / walls: go round
            continue
        x, y = nx, ny
        for ox in range(-width, width + 1):
            for oy in range(-width, width + 1):
                if abs(ox) + abs(oy) <= width and m.get(x + ox, y + oy) in over:
                    m.set(x + ox, y + oy, ch)


def scatter(m, rng, ch, rate, on=".", spacing=0):
    pts = []
    for y in range(m.h):
        for x in range(m.w):
            if m.g[y][x] == on and rng.random() < rate:
                if spacing and any(abs(x - a) < spacing and abs(y - b) < spacing for a, b in pts[-200:]):
                    continue
                if spacing and not all(m.get(x + dx, y + dy) in ".,_oO" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    continue
                m.g[y][x] = ch
                pts.append((x, y))


def connect_or_fill(m, spawn, fill="&"):
    """Every floor cell that can't be reached from the spawn becomes `fill`."""
    dist = m.reach(spawn)
    for y in range(m.h):
        for x in range(m.w):
            if m.walkable(x, y) and (x, y) not in dist:
                m.set(x, y, fill if m.get(x, y) not in "=" else "~")
    return dist


def spread_entities(m, rng, spawn, spec):
    dist = m.reach(spawn)
    far = max(dist.values())
    taken = [spawn]
    for ch, n, a, b, sp in spec:
        got = m.place(rng, dist, ch, n, int(far * a), int(far * b), sp, taken)
        if got < n:
            got += m.place(rng, dist, ch, n - got, 0, far, max(2, sp // 2), taken)
        if got < n:
            got += m.place(rng, dist, ch, n - got, 0, far, 2, taken, r=0)
        assert got == n, (ch, got, n)
    return dist


def ruin_walls(m, rng, cx, cy, w, h):
    """Broken walls of an old building around a plaza, with pillars."""
    x0, y0, x1, y1 = cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2
    for x in range(x0, x1 + 1):
        for y in (y0, y1):
            if rng.random() < 0.62 and m.get(x, y) in ".,oO":
                m.set(x, y, "#")
    for y in range(y0, y1 + 1):
        for x in (x0, x1):
            if rng.random() < 0.55 and m.get(x, y) in ".,oO":
                m.set(x, y, "#")
    for (px, py) in ((x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x0 + 2, y1 - 2), (x1 - 2, y1 - 2)):
        if rng.random() < 0.7 and m.get(px, py) in ".,":
            m.set(px, py, "x")


# ---------------------------------------------------------------------------

def ruins():
    rng = random.Random(11)
    m = Map(110, 72, ".")
    forest_border(m, rng, depth=3, extra=5, seed=1)
    masses(m, rng, 0.62, seed=2, scale=8)
    centers = river(m, rng, 60, width=(4, 6), amp=7, seed=3)
    plazas = [(14, 14), (36, 30), (22, 50), (46, 58), (82, 14), (90, 36), (78, 58), (96, 60)]
    spawn = (10, 63)
    for i, (px, py) in enumerate(plazas):
        r = rng.randint(5, 7)
        m.disc(px, py, r + 2, ".", rng, wob=0.25, only="&TxX")
        m.disc(px, py, r, ",", rng, wob=0.3, only=".&oO")
        if i % 3 != 2:
            ruin_walls(m, rng, px, py, r * 2 - 1 + rng.randint(0, 2), r * 2 - 3)
        if i == 2:
            m.set(px, py, "x")  # the old statue head
    m.disc(spawn[0], spawn[1], 4, ".", only="&")
    for y in (12, 36, 60):
        bridge(m, y, centers, 3)
    # paths that tie the plazas together (west side, then east side, then across the bridges)
    west = [spawn, (22, 50), (36, 30), (14, 14)]
    east = [(82, 14), (90, 36), (78, 58), (96, 60)]
    for a, b in zip(west, west[1:]):
        carve_path(m, rng, a, b)
    for a, b in zip(east, east[1:]):
        carve_path(m, rng, a, b)
    carve_path(m, rng, (22, 50), (46, 58))
    for y, a, b in ((12, (14, 14), (82, 14)), (36, (36, 30), (90, 36)), (60, (46, 58), (78, 58))):
        cx = int(centers[y])
        carve_path(m, rng, a, (cx - 6, y))
        carve_path(m, rng, (cx + 6, y), b)
    scatter(m, rng, "T", 0.022, spacing=4)
    scatter(m, rng, "X", 0.014, spacing=2)
    scatter(m, rng, "x", 0.004, spacing=3)
    scatter(m, rng, "o", 0.035)
    scatter(m, rng, "O", 0.012)
    scatter(m, rng, "O", 0.03, on=",")
    scatter(m, rng, "_", 0.05, on=",")
    m.disc(spawn[0], spawn[1], 2, ".", only="TxXoO")
    m.set(*spawn, "P")
    connect_or_fill(m, spawn)
    spread_entities(m, rng, spawn, [
        ("B", 8, 0.25, 1.0, 14), ("L", 2, 0.6, 1.0, 20), ("E", 10, 0.15, 1.0, 9),
        ("C", 10, 0.1, 1.0, 7), ("H", 2, 0.3, 0.9, 20), ("F", 1, 0.2, 0.5, 10),
        ("R", 2, 0.3, 0.9, 20), ("K", 2, 0.4, 1.0, 25)])
    return m


def factory():
    rng = random.Random(22)
    m = Map(100, 74, ".")
    forest_border(m, rng, depth=3, extra=4, seed=5)
    masses(m, rng, 0.66, seed=6, scale=7)
    # toxic pools, organic
    pools = [(30, 20, 6), (66, 44, 8), (20, 56, 5), (84, 18, 5), (50, 64, 5)]
    for (cx, cy, r) in pools:
        m.disc(cx, cy, r, "~", rng, wob=0.35, sy=0.75)
    # factory halls: rectangular buildings with metal floor and doors
    halls = [(8, 6, 22, 16), (40, 6, 58, 18), (70, 30, 90, 44), (34, 34, 52, 50), (62, 56, 80, 68), (8, 30, 22, 42)]
    for (x0, y0, x1, y1) in halls:
        m.rect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, ".", only="&~")
        m.rect(x0, y0, x1, y1, ",")
        m.outline(x0, y0, x1, y1, "#")
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        for (dx, dy) in rng.sample([(cx, y0), (cx, y1), (x0, cy), (x1, cy)], 2):
            if dx in (x0, x1):
                m.rect(dx, dy - 1, dx, dy + 1, ",")
            else:
                m.rect(dx - 1, dy, dx + 1, dy, ",")
        for _ in range(3):  # machines inside
            m.set(rng.randint(x0 + 2, x1 - 2), rng.randint(y0 + 2, y1 - 2), rng.choice("xT"))
        m.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 1, "_", only=",") if rng.random() < 0.5 else None
    spawn = (14, 64)
    m.disc(spawn[0], spawn[1], 4, ".", only="&~")
    hubs = [spawn, (15, 36), (15, 11), (49, 12), (43, 42), (80, 37), (71, 62), (88, 62), (86, 8)]
    for a, b in zip(hubs, hubs[1:]):
        carve_path(m, rng, a, b, over=".&TxXoO")
    # metal walkways over the pools where a path met one
    for y in range(m.h):
        for x in range(m.w):
            if m.get(x, y) == "~" and sum(m.get(x + dx, y) == "," for dx in (-1, 1)) == 2:
                m.set(x, y, "=")
    scatter(m, rng, "T", 0.006, spacing=5)
    scatter(m, rng, "x", 0.012, spacing=3)
    scatter(m, rng, "X", 0.006, spacing=2)
    scatter(m, rng, "o", 0.015)
    scatter(m, rng, "O", 0.012)
    scatter(m, rng, "_", 0.02, on=",")
    m.disc(spawn[0], spawn[1], 2, ".", only="TxXoO")
    m.set(*spawn, "P")
    connect_or_fill(m, spawn)
    spread_entities(m, rng, spawn, [
        ("B", 8, 0.25, 1.0, 12), ("L", 3, 0.5, 1.0, 18), ("E", 12, 0.15, 1.0, 8),
        ("C", 12, 0.1, 1.0, 6), ("H", 3, 0.3, 0.95, 16), ("F", 1, 0.2, 0.5, 10),
        ("R", 3, 0.25, 0.95, 16), ("K", 2, 0.45, 1.0, 22)])
    return m


def harbor():
    rng = random.Random(33)
    m = Map(112, 72, ".")
    # coastline: land on top, sea below, wobbly shore
    n = Noise(40, 9)
    for x in range(m.w):
        shore = 30 + int((n(x, 0) - 0.5) * 12 + 4 * math.sin(x * 0.08))
        for y in range(shore, m.h):
            m.set(x, y, "~")
    forest_border(m, rng, depth=2, extra=3, seed=8)
    for y in range(m.h):  # the sea reaches the map edge (no containers in the water)
        for x in range(m.w):
            if m.get(x, y) == "&" and y > 34 and any(m.get(x, yy) == "~" for yy in range(y - 6, y)):
                m.set(x, y, "~")
    # islands with a little dock each
    for (cx, cy, r) in ((30, 54, 6), (64, 60, 7), (94, 50, 6)):
        m.disc(cx, cy, r, ".", rng, wob=0.3, sy=0.7)
        m.disc(cx, cy, r - 2, ",", rng, wob=0.2, sy=0.7)
    # warehouses
    for (x0, y0, x1, y1) in ((8, 5, 24, 14), (34, 4, 52, 13), (62, 5, 78, 15), (88, 5, 104, 14)):
        m.rect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, ".", only="&")
        m.rect(x0, y0, x1, y1, ",")
        m.outline(x0, y0, x1, y1, "#")
        m.rect((x0 + x1) // 2 - 1, y1, (x0 + x1) // 2 + 1, y1, ",")
        for _ in range(3):
            m.set(rng.randint(x0 + 2, x1 - 2), rng.randint(y0 + 2, y1 - 2), "x")
    # the quay road
    road = [(6, 19), (30, 21), (56, 18), (84, 20), (106, 19)]
    for a, b in zip(road, road[1:]):
        carve_path(m, rng, a, b, width=1, wiggle=0.15)
    for (x0, y0, x1, y1) in ((8, 5, 24, 14), (34, 4, 52, 13), (62, 5, 78, 15), (88, 5, 104, 14)):
        carve_path(m, rng, ((x0 + x1) // 2, y1 + 1), ((x0 + x1) // 2, 19), width=0, wiggle=0.0)
    # container yards: rows of big props
    for (x0, y0) in ((28, 23), (70, 23), (8, 24)):
        for j in range(2):
            for i in range(3):
                x, y = x0 + i * 4, y0 + j * 3
                if m.get(x, y) == ".":
                    m.set(x, y, "T")
    # piers out to the islands + boardwalks
    def pier(x, y0, y1):
        for y in range(y0, y1 + 1):
            for xx in (x - 1, x, x + 1):
                if m.get(xx, y) == "~":
                    m.set(xx, y, "=")
    pier(30, 26, 52)
    pier(64, 26, 58)
    pier(94, 26, 48)
    for x in range(30, 65):
        for y in (40, 41):
            if m.get(x, y) == "~":
                m.set(x, y, "=")
    scatter(m, rng, "x", 0.01, spacing=3)
    scatter(m, rng, "X", 0.008, spacing=2)
    scatter(m, rng, "o", 0.012)
    scatter(m, rng, "O", 0.008)
    scatter(m, rng, "_", 0.04, on=",")
    # boats moored in the sea
    for (x, y) in ((44, 48), (80, 44), (12, 46), (104, 62), (52, 66)):
        if all(m.get(x + dx, y + dy) == "~" for dx in range(-2, 3) for dy in range(-1, 2)):
            m.set(x, y, "b")
    spawn = (8, 19)
    m.disc(spawn[0], spawn[1], 2, ".", only="TxXoO&")
    m.set(*spawn, "P")
    connect_or_fill(m, spawn)
    spread_entities(m, rng, spawn, [
        ("B", 9, 0.25, 1.0, 12), ("L", 2, 0.5, 1.0, 20), ("E", 13, 0.15, 1.0, 8),
        ("C", 12, 0.1, 1.0, 6), ("H", 3, 0.3, 0.95, 16), ("F", 1, 0.2, 0.5, 10),
        ("R", 2, 0.3, 0.9, 20), ("K", 2, 0.45, 1.0, 22)])
    return m


def fortress():
    rng = random.Random(44)
    m = Map(100, 124, ".")
    # --- the dump (explore area), bottom ---------------------------------
    forest_border(m, rng, depth=3, extra=4, seed=12)
    masses(m, rng, 0.63, seed=13, scale=8, only=".")
    for y in range(0, 62):  # masses only in the dump
        for x in range(m.w):
            if m.get(x, y) == "&" and 4 <= x < m.w - 4:
                m.set(x, y, ".")
    for (cx, cy, r) in ((24, 78, 6), (70, 84, 7), (40, 102, 5), (82, 106, 5), (14, 98, 4)):
        m.disc(cx, cy, r, "~", rng, wob=0.35, sy=0.7)
    # --- fortress wall with an open gate ---------------------------------
    m.rect(0, 58, m.w - 1, 61, "#")
    m.rect(47, 58, 52, 61, ",")
    # --- courtyard inside the fortress ------------------------------------
    m.rect(5, 28, 94, 57, ".")
    m.disc(49, 44, 16, ",", rng, wob=0.15, sy=0.6)
    for (x0, y0, x1, y1) in [(10, 32, 26, 44), (73, 32, 89, 44), (30, 48, 42, 55), (57, 48, 69, 55)]:
        m.rect(x0, y0, x1, y1, ",")
        m.outline(x0, y0, x1, y1, "#")
        m.rect((x0 + x1) // 2 - 1, y1, (x0 + x1) // 2 + 1, y1, ",")
        m.rect((x0 + x1) // 2 - 1, y0, (x0 + x1) // 2 + 1, y0, ",")
    for x in (12, 30, 68, 87):  # banners
        m.set(x, 29, "x")
    # --- the arena, top --------------------------------------------------
    m.rect(0, 0, m.w - 1, 27, "#")
    m.rect(24, 4, 75, 24, ",")
    for y in range(4, 25):
        for x in range(24, 76):
            if (x + y) % 9 == 0:
                m.set(x, y, "_")
    m.rect(47, 25, 52, 27, ",")       # entrance corridor
    m.rect(47, 26, 52, 26, "G")       # the gate (closed until the goal is met)
    m.set(49, 22, "S")                # station inside the arena: starts the fight
    m.set(49, 13, "Z")                # the boss
    m.border(2, "#") if hasattr(m, "border") else None
    for y in range(m.h):
        for x in range(m.w):
            if (x < 2 or x >= m.w - 2 or y < 2 or y >= m.h - 2) and m.get(x, y) not in "&":
                m.set(x, y, "#")
    # dump paths
    spawn = (49, 116)
    m.disc(spawn[0], spawn[1], 4, ".", only="&~")
    for a, b in (((49, 116), (49, 62)), ((49, 70), (14, 112)), ((49, 70), (88, 114)), ((49, 90), (86, 70)), ((49, 90), (12, 68))):
        carve_path(m, rng, a, b, width=1)
    for y in range(62, m.h):
        for x in range(m.w):
            if m.get(x, y) == "~" and sum(m.get(x + dx, y) == "," for dx in (-1, 1)) == 2:
                m.set(x, y, "=")
    # scrap scattered in the dump, rubble in the courtyard
    for y in range(62, m.h):
        for x in range(m.w):
            if m.get(x, y) == "." and rng.random() < 0.012 and all(m.get(x + dx, y + dy) in ".,oO" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                m.set(x, y, rng.choice("TxxX"))
            elif m.get(x, y) == "." and rng.random() < 0.03:
                m.set(x, y, rng.choice("oO"))
    for y in range(29, 58):
        for x in range(m.w):
            if m.get(x, y) == "." and rng.random() < 0.01 and all(m.get(x + dx, y + dy) in ".,oO" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                m.set(x, y, rng.choice("xX"))
            elif m.get(x, y) in ".," and rng.random() < 0.02:
                m.set(x, y, "O")
    m.disc(spawn[0], spawn[1], 2, ".", only="TxXoO")
    m.set(*spawn, "P")
    # things only in the dump and the courtyard (not the arena)
    saved = [r[:] for r in m.g]
    for y in range(0, 28):
        for x in range(m.w):
            if m.g[y][x] in "._,oOG":
                m.g[y][x] = "#"
    m.g[25][49] = ","
    connect_or_fill(m, spawn)
    spread_entities(m, rng, spawn, [
        ("B", 8, 0.2, 1.0, 12), ("L", 3, 0.55, 1.0, 16), ("E", 12, 0.15, 1.0, 8),
        ("C", 12, 0.1, 1.0, 6), ("H", 4, 0.3, 1.0, 14), ("F", 1, 0.2, 0.6, 10),
        ("R", 2, 0.2, 0.8, 18), ("K", 2, 0.5, 1.0, 22)])
    for y in range(0, 28):
        for x in range(m.w):
            m.g[y][x] = saved[y][x]
    return m


# --------------------------------------------------------------------------- the first campaign levels
# City, Snow Path, Polluted Lake and AI DataCenter (Forest keeps the layout of
# its old hand-made scene, see Tools/dev/scene_to_map.py).

def tunnel(m, a, b, width, ch, over="#&.TxXoO", horizontal_first=True):
    """Straight L-shaped corridor from a to b, `width` cells wide (to the right of / below the line)."""
    (x0, y0), (x1, y1) = a, b

    def seg_h(y, xa, xb):
        for x in range(min(xa, xb), max(xa, xb) + width):
            for k in range(width):
                if m.get(x, y + k) in over:
                    m.set(x, y + k, ch)

    def seg_v(x, ya, yb):
        for y in range(min(ya, yb), max(ya, yb) + width):
            for k in range(width):
                if m.get(x + k, y) in over:
                    m.set(x + k, y, ch)
    if horizontal_first:
        seg_h(y0, x0, x1)
        seg_v(x1, y0, y1)
    else:
        seg_v(x0, y0, y1)
        seg_h(y1, x0, x1)


def cliff(m, x0, y0, x1, y1, seed, ch="#"):
    """A rock outcrop seen from above: rounded, uneven top and sides, a straight
    bottom (the cliff face the player walks along)."""
    n = Noise(seed, 5)
    for x in range(x0, x1 + 1):
        end = min(x - x0, x1 - x)
        top = y0 + int(n(x, 0) * 4) + max(0, 4 - end)
        for y in range(top, y1 + 1):
            side = max(0, 3 - (y1 - y)) if end < 2 else 0
            if end + int(n(0, y) * 3) >= side:
                m.set(x, y, ch)


def bridge_rect(m, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if m.get(x, y) == "~":
                m.set(x, y, "=")


def secret_room(m, spawn, rects, crates, portal, decor=()):
    """Carves a secret pocket (floor `rects`, inside solid '#' or '&') that only
    opens to the level through the `crates` (map letter V; they must be cells
    of the rects, next to the open level). `portal` is the secret portal (Y).
    Checks that the portal can't be reached while the crates stand and can be
    once they break."""
    cells = {(x, y) for (x0, y0, x1, y1) in rects for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}
    for c in cells:
        assert m.get(*c) in "#&", ("secret room not inside solid ground", c, m.get(*c))
    for c in cells:
        m.set(*c, ".")
    for c in crates:
        assert c in cells
        m.set(*c, "V")
    for (x, y, ch) in decor:
        m.set(x, y, ch)
    m.set(*portal, "Y")
    near = [(portal[0] + dx, portal[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    shut = m.reach(spawn)
    assert not any(c in shut for c in cells), "secret room is open without breaking the crates"
    for c in crates:
        m.set(*c, ".")
    assert any(c in m.reach(spawn) for c in near), "secret portal unreachable"
    for c in crates:
        m.set(*c, "V")


def city():
    """Downtown: a grid of avenues and building blocks around the park in the
    middle. Each block is different: towers split by alleys, courtyards,
    parking lots, and the monument square (the secret is under its south
    building)."""
    rng = random.Random(55)
    E, SW, RW = 2, 2, 5                  # edge buildings, sidewalk, road
    band = 2 * SW + RW
    BX, BY = [24, 34, 24], [18, 26, 18]  # block sizes: the park in the middle is the largest
    W, H = 2 * E + 4 * band + sum(BX), 2 * E + 4 * band + sum(BY)
    m = Map(W, H, "#")
    rxs = [E + k * band + sum(BX[:k]) for k in range(4)]  # left edge of each vertical street band
    rys = [E + k * band + sum(BY[:k]) for k in range(4)]
    for rx in rxs:
        m.rect(rx, E, rx + band - 1, H - 1 - E, ".")
    for ry in rys:
        m.rect(E, ry, W - 1 - E, ry + band - 1, ".")
    for rx in rxs:
        m.rect(rx + SW, E + SW, rx + SW + RW - 1, H - 1 - E - SW, ",")
    for ry in rys:
        m.rect(E + SW, ry + SW, W - 1 - E - SW, ry + SW + RW - 1, ",")
    # crosswalks on the avenues, before and after every crossing
    for rx in rxs:
        for ry in rys:
            for y in (ry + SW - 2, ry + SW - 1, ry + SW + RW, ry + SW + RW + 1):
                for x in range(rx + SW, rx + SW + RW):
                    if m.get(x, y) == ",":
                        m.set(x, y, "_")

    def block(i, j):
        x0, y0 = rxs[i] + band, rys[j] + band
        return x0, y0, x0 + BX[i] - 1, y0 + BY[j] - 1

    def towers(x0, y0, x1, y1, setback):
        """Three buildings: an alley right through, one dead-end alley, one forecourt."""
        a1 = x0 + rng.randint(6, 7)
        a2 = a1 + 3 + rng.randint(5, 6)
        m.rect(a1, y0, a1 + 2, y1, ".")
        m.rect(a2, y0 + 7, a2 + 2, y1, ".")
        m.set(a2 + 1, y0 + 8, "X")                     # dumpster at the dead end
        m.set(a2, y0 + 10, "O")
        if setback == "e":
            m.rect(a2 + 3, y1 - 3, x1, y1, ".")
            m.set(a2 + 5, y1 - 2, "T")
            m.set(x1 - 1, y1 - 2, "T")
        else:
            m.rect(x0, y1 - 3, a1 - 1, y1, ".")
            m.set(x0 + 1, y1 - 2, "T")
            m.set(a1 - 2, y1 - 2, "T")

    def courtyard(x0, y0, x1, y1, door):
        cx0, cy0, cx1, cy1 = x0 + 5, y0 + 4, x1 - 5, y1 - 4
        m.rect(cx0, cy0, cx1, cy1, ".")
        mx, my = (cx0 + cx1) // 2, (cy0 + cy1) // 2
        if door == "s":
            m.rect(mx - 1, cy1, mx + 1, y1, ".")
        elif door == "n":
            m.rect(mx - 1, y0, mx + 1, cy0, ".")
        elif door == "w":
            m.rect(x0, my - 1, cx0, my + 1, ".")
        else:
            m.rect(cx1, my - 1, x1, my + 1, ".")
        for (x, y) in ((cx0 + 1, cy0 + 1), (cx1 - 1, cy0 + 1)):
            m.set(x, y, "T")
        m.set(cx0 + 1, cy1 - 1, "X")
        m.set(cx1 - 1, cy1 - 1, "x")

    def parking(x0, y0, x1, y1):
        m.rect(x0, y0 + 5, x1, y1, ",")                # the lot; a building along the north side
        for row in (y0 + 8, y0 + 14):
            for x in range(x0 + 3, x1 - 2, 4):
                if rng.random() < 0.75:
                    m.set(x, row, "c")
        m.set(x0 + 1, y0 + 11, "X")
        m.set(x1 - 1, y0 + 11, "X")

    def park(x0, y0, x1, y1):
        m.rect(x0, y0, x1, y1, ";")
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        for k in (3, 4):                               # ring walk
            m.outline(x0 + k, y0 + k, x1 - k, y1 - k, ".")
        m.rect(cx, y0, cx + 1, y1, ".")               # cross walks to the fountain
        m.rect(x0, cy, x1, cy + 1, ".")
        m.disc(cx + 0.5, cy + 0.5, 5.2, ".")
        m.disc(cx + 0.5, cy + 0.5, 2.9, "~")
        for (x, y) in ((cx - 4, cy - 4), (cx + 5, cy - 4), (cx - 4, cy + 5), (cx + 5, cy + 5)):
            m.set(x, y, "x")                           # benches round the fountain
        trees = []
        cells = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if m.get(x, y) == ";"]
        rng.shuffle(cells)
        for (x, y) in cells:
            if all(abs(x - a) + abs(y - b) >= 4 for a, b in trees) and \
                    all(m.get(x + dx, y + dy) in ";" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                m.set(x, y, "T")
                trees.append((x, y))
        for (x, y) in cells[:25]:
            if m.get(x, y) == ";":
                m.set(x, y, "O")                       # litter on the lawn

    def plaza(x0, y0, x1, y1):
        m.rect(x0, y0, x1, y1 - 7, ".")               # the square; buildings along the south side
        cx, cy = (x0 + x1) // 2, (y0 + y1 - 7) // 2
        m.disc(cx + 0.5, cy + 0.5, 2.2, "~")           # the monument's fountain
        for dx, dy in ((-7, -3), (8, -3), (-7, 4), (8, 4)):
            m.set(cx + dx, cy + dy, "T")
        m.set(cx - 3, cy + 4, "x")
        m.set(cx + 4, cy + 4, "x")

    towers(*block(0, 0), "e")
    courtyard(*block(1, 0), "s")
    towers(*block(2, 0), "w")
    parking(*block(0, 1))
    park(*block(1, 1))
    courtyard(*block(2, 1), "w")
    courtyard(*block(0, 2), "n")
    plaza(*block(1, 2))
    towers(*block(2, 2), "e")

    # street furniture: trees and lamps on the curb, parked cars, manholes, litter
    taken = []
    curb = [(x, y) for y in range(H) for x in range(W) if m.get(x, y) == "." and
            any(m.get(x + dx, y + dy) == "," for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    rng.shuffle(curb)
    for (x, y) in curb:
        if any(m.get(x + dx, y + dy) == "_" for dx in range(-3, 4) for dy in range(-3, 4)):
            continue
        if all(abs(x - a) + abs(y - b) >= 7 for a, b in taken):
            m.set(x, y, "T" if len(taken) % 3 else "X")
            taken.append((x, y))
    cars = []
    for y in range(H):
        for x in range(W):
            if m.get(x, y) != "," or rng.random() > 0.15:
                continue
            side = [(dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if m.get(x + dx, y + dy) == "."]
            if len(side) != 1:
                continue
            along = [(1, 0), (-1, 0)] if side[0][0] == 0 else [(0, 1), (0, -1)]
            if all(m.get(x + ax * k, y + ay * k) == "," for ax, ay in along for k in (1, 2, 3)) and \
                    all(abs(x - a) + abs(y - b) >= 9 for a, b in cars):
                m.set(x, y, "c")
                cars.append((x, y))
    scatter(m, rng, "o", 0.006, on=",")
    scatter(m, rng, "O", 0.012, on=".")
    spawn = (rxs[0] + SW + 2, rys[3] + SW + 2)
    m.set(*spawn, "P")
    connect_or_fill(m, spawn, fill="#")
    spread_entities(m, rng, spawn, [
        ("B", 6, 0.25, 1.0, 14), ("L", 2, 0.55, 1.0, 24), ("E", 20, 0.12, 1.0, 9),
        ("C", 12, 0.1, 1.0, 8), ("H", 2, 0.3, 0.9, 20), ("F", 2, 0.2, 0.6, 14),
        ("R", 4, 0.25, 0.95, 16), ("K", 2, 0.4, 1.0, 26), ("W", 14, 0.05, 1.0, 7)])
    x0, y0, x1, y1 = block(1, 2)
    secret_room(m, spawn, [(x0 + 3, y1 - 4, x0 + 13, y1 - 2), (x0 + 12, y1 - 6, x0 + 13, y1 - 5)],
                [(x0 + 12, y1 - 6), (x0 + 13, y1 - 6)], (x0 + 5, y1 - 3),
                decor=[(x0 + 8, y1 - 3, "O"), (x0 + 10, y1 - 4, "o")])
    return m


def snowpath():
    """A mountain trail that climbs from the valley (bottom) to the summit
    (top) through pine woods. Side paths lead to the frozen lake, a crystal
    glade and the two caves in the rock (the chests are in the caves; the
    secret is behind the west cave)."""
    rng = random.Random(66)
    m = Map(96, 122, ".")
    forest_border(m, rng, depth=4, extra=5, seed=61)
    masses(m, rng, 0.6, seed=62, scale=8)
    m.disc(70, 97, 9, "~", rng, wob=0.25, sy=0.7)            # the frozen lake
    cliff(m, 61, 41, 91, 67, 63)                             # east cave rock
    cliff(m, 4, 15, 37, 44, 64)                              # west cave rock
    # cave chambers (cobbled floor) and their tunnels
    for (cx, cy, r) in ((70, 55, 4.5), (81, 62, 3.6), (80, 48, 3.2), (22, 32, 4.5), (13, 25, 3.6), (14, 39, 3.4)):
        m.disc(cx, cy, r, ",", only="#")
    tunnel(m, (56, 54), (68, 54), 3, ",")                    # east cave entrance
    tunnel(m, (72, 56), (80, 61), 3, ",")
    tunnel(m, (71, 53), (79, 48), 3, ",", horizontal_first=False)
    tunnel(m, (24, 31), (41, 31), 3, ",")                    # west cave entrance
    tunnel(m, (21, 30), (13, 24), 3, ",", horizontal_first=False)
    tunnel(m, (21, 33), (13, 38), 3, ",", horizontal_first=False)
    # the trail, valley to summit, with clearings along it
    trail = [(46, 115), (36, 104), (28, 92), (34, 80), (48, 72), (54, 62), (50, 50), (46, 40), (54, 26), (48, 12)]
    for (x, y) in trail:
        m.disc(x, y, 6, ".", rng, wob=0.3, only="&TxX")
    for a, b in zip(trail, trail[1:]):
        carve_path(m, rng, a, b, width=1, wiggle=0.25)
    m.disc(48, 12, 8, ".", rng, wob=0.2, only="&TxX")         # the summit
    m.disc(48, 12, 4.5, ",", rng, wob=0.2)
    # side paths: lake shore and island, crystal glade, cave mouths
    m.disc(15, 64, 7, ".", rng, wob=0.3, only="&TxX")
    carve_path(m, rng, (34, 80), (15, 64), width=1, wiggle=0.3)
    carve_path(m, rng, (36, 104), (58, 100), width=1, wiggle=0.2)
    m.disc(71, 97, 2.8, ".")
    bridge_rect(m, 58, 96, 70, 98)
    carve_path(m, rng, (54, 62), (56, 55), width=1, wiggle=0.1)
    carve_path(m, rng, (46, 40), (42, 32), width=1, wiggle=0.1)
    # crystals in the caves and the glade
    for (x, y) in ((67, 53), (73, 58), (84, 63), (82, 46), (19, 30), (25, 35), (11, 23), (16, 41), (12, 61), (18, 66), (14, 67)):
        if m.get(x, y) in ".,":
            m.set(x, y, "x")
    scatter(m, rng, "T", 0.018, spacing=4)
    scatter(m, rng, "X", 0.008, spacing=2)
    scatter(m, rng, "x", 0.002, spacing=3)
    scatter(m, rng, "o", 0.03)
    scatter(m, rng, "O", 0.006)
    scatter(m, rng, "O", 0.03, on=",")
    scatter(m, rng, "_", 0.03, on=",")
    spawn = trail[0]
    m.disc(spawn[0], spawn[1], 2, ".", only="TxXoO")
    m.set(*spawn, "P")
    m.set(81, 63, "K")                                       # a chest in each cave
    m.set(14, 40, "K")
    connect_or_fill(m, spawn)
    spread_entities(m, rng, spawn, [
        ("B", 10, 0.2, 1.0, 12), ("E", 22, 0.12, 1.0, 8), ("C", 10, 0.1, 1.0, 7),
        ("H", 3, 0.3, 0.95, 18), ("F", 2, 0.2, 0.6, 14), ("R", 3, 0.25, 0.95, 18), ("W", 6, 0.1, 1.0, 10)])
    secret_room(m, spawn, [(4, 37, 8, 40), (9, 38, 10, 39)], [(10, 38), (10, 39)], (5, 38),
                decor=[(7, 40, "x"), (4, 40, "O")])
    return m


def lake():
    """The polluted lake, every shore in use: the polluters' depot on the north
    shore (the secret is in the palms behind it), the bathing beach on the
    west, the fishing village and its piers on the east, the dump on the south
    shore. A boardwalk rings the lake and ties the shores together; a pier and
    two bridges cross the lake by way of two islands."""
    rng = random.Random(77)
    m = Map(112, 90, ".")
    forest_border(m, rng, depth=3, extra=3, seed=71)
    m.rect(34, 0, 62, 3, "&")                                # thick palms behind the depot
    m.disc(57, 47, 25, "~", rng, wob=0.14, sy=0.62)          # the lake
    # boardwalk around the lake, a few cells back from the water
    water = [(x, y) for y in range(m.h) for x in range(m.w) if m.get(x, y) == "~"]
    near = {}
    for (x, y) in water:
        for dy in range(-5, 6):
            for dx in range(-5, 6):
                c = (x + dx, y + dy)
                near[c] = min(near.get(c, 99), max(abs(dx), abs(dy)))
    for (x, y), d in near.items():
        if 2 <= d <= 4 and m.get(x, y) == ".":
            m.set(x, y, ",")
    # islands, the pier and the bridges between them
    m.disc(46, 44, 5.0, ".", sy=0.75)
    m.disc(68, 50, 4.2, ".", sy=0.75)
    m.disc(46, 44, 2.4, ",")
    m.disc(68, 50, 1.8, ",")
    bridge_rect(m, 45, 26, 47, 41)
    bridge_rect(m, 50, 47, 64, 49)
    bridge_rect(m, 67, 54, 69, 70)
    # north shore: the polluters' depot, its yard and the loading road
    depot = ((10, 5, 24, 12), (36, 4, 54, 12), (64, 5, 78, 12), (88, 6, 100, 12))
    for (x0, y0, x1, y1) in depot:
        m.rect(x0, y0 - 1, x1, y1 + 2, ".")
        m.rect(x0, y0, x1, y1, "#")
    m.rect(55, 4, 63, 14, ".")
    m.rect(8, 16, 103, 18, ",")
    for x in (30, 58, 84):                                   # down to the boardwalk
        m.rect(x - 1, 18, x + 1, 24, ",")
    for (x0, x1) in ((26, 34), (56, 62), (80, 86)):          # crate stacks between the warehouses
        for y in (7, 10):
            for x in range(x0, x1 + 1, 3):
                m.set(x, y, "x")
    for x in range(12, 102, 6):                              # palms along the road
        if m.get(x, 20) == ".":
            m.set(x, 20, "T")
    # west: the bathing beach: a beach bar, umbrellas in rows, a path to the water
    m.rect(8, 24, 16, 28, "#")
    m.rect(8, 29, 16, 31, ",")
    for y in range(36, 66, 6):
        for x in range(9, 27, 5):
            if m.get(x, y) == "." and m.get(x + 1, y) == ".":
                m.set(x, y, "T")
                m.set(x + 1, y + 1, "o")                     # a towel (shell) next to it
    m.rect(8, 50, 24, 51, ",")
    # east: the fishing village: huts round a boardwalk square, piers with boats
    for (x0, y0) in ((88, 24), (98, 24), (88, 34), (100, 36), (88, 58), (98, 60), (100, 48)):
        m.rect(x0, y0, x0 + 6, y0 + 3, "#")
    m.rect(87, 42, 98, 54, ",")
    for (x, y) in ((89, 44), (96, 44), (89, 52), (93, 48)):
        m.set(x, y, "x")
    for (y, x0) in ((36, 76), (51, 78), (60, 72)):
        for x in range(x0 - 12, x0 + 14):
            for yy in (y, y + 1):
                if m.get(x, yy) == "~" and near.get((x, yy), 0) == 0:
                    m.set(x, yy, "=")
    for (x, y) in ((70, 34), (72, 40), (74, 55), (63, 60), (36, 52), (40, 36), (56, 38), (52, 58)):
        if all(m.get(x + dx, y + dy) == "~" for dx in range(-2, 3) for dy in range(-1, 2)):
            m.set(x, y, "b")
    # south: the dump: junk heaps everywhere, sludge pools, a track through it
    for (cx, cy, r) in ((40, 80, 3.5), (86, 79, 4.5), (64, 84, 3)):
        m.disc(cx, cy, r, "~", rng, wob=0.3, sy=0.7)
    track = [(8, 80), (24, 76), (50, 74), (74, 78), (96, 74), (104, 70)]
    for a, b in zip(track, track[1:]):
        carve_path(m, rng, a, b, width=1, wiggle=0.15)
    heaps = []
    dump = [(x, y) for y in range(66, m.h) for x in range(14, 106) if m.get(x, y) == "."]
    rng.shuffle(dump)
    for (x, y) in dump:
        if all(abs(x - a) >= 4 or abs(y - b) >= 3 for a, b in heaps) and \
                all(m.get(x + dx, y + dy) in ".oO" for dx in (-2, -1, 0, 1, 2) for dy in (-1, 0, 1)):
            m.set(x, y, "c")
            heaps.append((x, y))
    for (x, y) in dump[:60]:
        if m.get(x, y) == ".":
            m.set(x, y, rng.choice("xXO"))
    scatter(m, rng, "X", 0.004, spacing=2)
    scatter(m, rng, "o", 0.025)
    scatter(m, rng, "O", 0.02)
    scatter(m, rng, "_", 0.025, on=",")
    spawn = (8, 80)
    m.disc(spawn[0], spawn[1], 2, ".", only="TxXoO&")
    m.set(*spawn, "P")
    connect_or_fill(m, spawn)
    spread_entities(m, rng, spawn, [
        ("B", 8, 0.2, 1.0, 14), ("E", 24, 0.1, 1.0, 8), ("L", 1, 0.6, 1.0, 20), ("C", 14, 0.05, 1.0, 9),
        ("H", 2, 0.3, 0.9, 20), ("F", 1, 0.2, 0.5, 14), ("R", 3, 0.3, 0.95, 18), ("K", 1, 0.5, 1.0, 20),
        ("W", 12, 0.05, 1.0, 7)])
    secret_room(m, spawn, [(38, 1, 55, 2), (56, 1, 57, 3)], [(56, 3), (57, 3)], (40, 2),
                decor=[(46, 1, "x"), (52, 2, "x"), (43, 1, "O")])
    return m

def datacenter():
    """NEXUS's data center, a building seen from above: the lobby (bottom), a
    main corridor up the middle and two cross corridors, six halls on the
    sides (server rows, coolant pools, control room, storage) and the core
    room at the top. Wall turrets watch the corridors; the secret is a hidden
    server room behind the storage."""
    rng = random.Random(88)
    m = Map(104, 86, "#")
    halls = {
        "core": (36, 4, 67, 14),
        "nw": (6, 18, 40, 30), "ne": (63, 18, 97, 30),
        "w": (6, 38, 40, 50), "e": (63, 38, 97, 50),
        "sw": (6, 58, 40, 70), "se": (63, 58, 97, 70),
        "lobby": (40, 74, 63, 81),
    }
    for (x0, y0, x1, y1) in halls.values():
        m.rect(x0, y0, x1, y1, ".")
    # corridors: the spine and two cross corridors (circuit floor)
    m.rect(49, 15, 54, 73, ",")
    m.rect(6, 33, 97, 35, ",")
    m.rect(6, 53, 97, 55, ",")
    # doors (3 wide) from the halls to the corridors
    for (x, y0, y1) in ((22, 31, 32), (80, 31, 32), (22, 36, 37), (80, 36, 37), (30, 51, 52), (72, 51, 52), (14, 56, 57), (88, 56, 57)):
        m.rect(x - 1, y0, x + 1, y1, ",")
    for (y, x0, x1) in ((64, 41, 48), (64, 55, 62), (24, 41, 48), (24, 55, 62)):
        m.rect(x0, y - 1, x1, y + 1, ",")
    # server rows (dense racks) in the NE, W and SW halls
    for (x0, y0, x1, y1) in (halls["ne"], halls["sw"]):
        for y in range(y0 + 3, y1 - 2, 4):
            m.rect(x0 + 4, y, x1 - 4, y + 1, "&")
            m.rect((x0 + x1) // 2 - 1, y, (x0 + x1) // 2 + 1, y + 1, ".")   # a gap in each row
    x0, y0, x1, y1 = halls["w"]
    for x in range(x0 + 4, x1 - 3, 6):                                      # racks in columns
        m.rect(x, y0 + 3, x + 1, y1 - 3, "&")
    # coolant pools with grating walkways (SE hall)
    x0, y0, x1, y1 = halls["se"]
    m.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "~")
    m.rect(x0 + 3, (y0 + y1) // 2, x1 - 3, (y0 + y1) // 2 + 1, "=")
    for x in (x0 + 10, x1 - 10):
        m.rect(x, y0 + 3, x + 1, y1 - 3, "=")
    # control room (E): consoles in rows; storage (NW): crates and cable drums
    x0, y0, x1, y1 = halls["e"]
    for y in (y0 + 3, y0 + 7):
        for x in range(x0 + 4, x1 - 2, 4):
            m.set(x, y, "x")
    x0, y0, x1, y1 = halls["nw"]
    for (x, y) in ((x0 + 3, y0 + 3), (x0 + 6, y0 + 3), (x0 + 3, y0 + 6), (x1 - 4, y0 + 3), (x1 - 7, y0 + 3), (x1 - 4, y1 - 3),
                   (x0 + 12, y0 + 8), (x0 + 15, y0 + 8), (x0 + 22, y0 + 5), (x1 - 4, y0 + 7)):
        m.set(x, y, "X")
    # the core: a ring of servers round the NEXUS core (coolant)
    x0, y0, x1, y1 = halls["core"]
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    m.disc(cx + 0.5, cy + 0.5, 2.6, "~")
    for (x, y) in ((cx - 9, y0 + 2), (cx - 5, y0 + 2), (cx + 6, y0 + 2), (cx + 10, y0 + 2),
                   (cx - 9, y1 - 2), (cx + 10, y1 - 2), (x0 + 2, cy), (x1 - 2, cy)):
        m.set(x, y, "T")
    # servers along the hall walls, lobby furniture
    for name in ("nw", "w", "e", "sw"):
        x0, y0, x1, y1 = halls[name]
        for x in range(x0 + 2, x1 - 1, 5):
            if m.get(x, y0) == "." and m.get(x, y0 + 1) == ".":
                m.set(x, y0, "T")
    x0, y0, x1, y1 = halls["lobby"]
    for (x, y) in ((x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x0 + 2, y1 - 2), (x1 - 2, y1 - 2)):
        m.set(x, y, "x")
    scatter(m, rng, "o", 0.02)
    scatter(m, rng, "O", 0.012)
    scatter(m, rng, "_", 0.05, on=",")
    # wall turrets: (wall cell, direction it fires)
    for (x, y, d) in ((48, 22, "right"), (55, 28, "left"), (48, 44, "right"), (55, 47, "left"), (48, 62, "right"),
                      (55, 67, "left"), (12, 32, "down"), (92, 32, "down"), (34, 52, "down"), (68, 52, "down"),
                      (12, 56, "up"), (92, 56, "up"), (44, 15, "up"), (59, 15, "up")):
        assert m.get(x, y) == "#", ("turret not on a wall", x, y)
        m.extras.append("turret %d %d %s" % (x * 16 + 8, y * 16 + 8, d))
    spawn = (51, 78)
    m.set(*spawn, "P")
    connect_or_fill(m, spawn, fill="#")
    spread_entities(m, rng, spawn, [
        ("B", 7, 0.25, 1.0, 14), ("L", 7, 0.4, 1.0, 14), ("E", 18, 0.15, 1.0, 8), ("C", 16, 0.05, 1.0, 7),
        ("H", 4, 0.3, 0.95, 18), ("F", 1, 0.2, 0.5, 14), ("K", 3, 0.4, 1.0, 22)])
    x0, y0, x1, y1 = halls["nw"]
    secret_room(m, spawn, [(x0 + 2, y0 - 6, x0 + 12, y0 - 3), (x0 + 13, y0 - 4, x0 + 14, y0 - 1)],
                [(x0 + 13, y0 - 1), (x0 + 14, y0 - 1)], (x0 + 4, y0 - 5),
                decor=[(x0 + 8, y0 - 6, "T"), (x0 + 11, y0 - 6, "T"), (x0 + 6, y0 - 3, "o")])
    return m

MAPS = {"Ruins": ruins, "Factory": factory, "Harbor": harbor, "Fortress": fortress,
        "City": city, "SnowPath": snowpath, "Lake": lake, "DataCenter": datacenter}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, fn in MAPS.items():
        if len(sys.argv) > 2 and name not in sys.argv[2:]:
            continue
        m = fn()
        open(os.path.join(out, name + ".txt"), "w").write(m.text())
        counts = {c: sum(r.count(c) for r in m.g) for c in "PBELCHFRKWVYTxXcb&"}
        print(name, m.w, m.h, counts)
