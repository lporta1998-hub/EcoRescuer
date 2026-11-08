"""Organic text maps for the new EcoRescuer levels (BuiltLevel v2).

Terrain:  .  floor   ,  path / plaza   _  special overlay   #  wall   ~  water   =  bridge
          &  dense mass (forest, machinery, containers, junk mountains: blocks, filled with big props)
          o O  small decor        T  big prop (blocks)   x  medium prop (blocks)   X  small prop (blocks)
          b  boat (on water)
Things:   P S D B E L C H F R K Z G   (see built_level.gd)"""
import random, math, sys, os
from collections import deque

WALK = set(".,_=oO") | set("PBECHFRKDSLZG")
FREE = set(".,_")


class Map:
    def __init__(self, w, h, fill="."):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]

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
        return "\n".join("".join(r).rstrip() for r in self.g) + "\n"


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


MAPS = {"Ruins": ruins, "Factory": factory, "Harbor": harbor, "Fortress": fortress}

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, fn in MAPS.items():
        m = fn()
        open(os.path.join(out, name + ".txt"), "w").write(m.text())
        counts = {c: sum(r.count(c) for r in m.g) for c in "PBELCHFRKTxXb&"}
        print(name, m.w, m.h, counts)
