"""Turns a hand-made level (dumped by dump_tiles.gd and dump_grid.gd) into a
BuiltLevel text map, so the level keeps its layout but is drawn with the
original tilesets of Tools/art/tiles2.py and props.py.

    python3 scene_to_map.py TILES.json GRID.txt THEME OUT.txt [SPOT.json]

One-off: it converted Forest, Snow Path, City, Polluted Lake and AI
DataCenter. Their old scenes and third-party textures were then removed, so
running it again needs them back from git history (the commit before the
conversion), with the textures under Tools/art/orig/levels/ or in place.
SPOT.json: {"crates": [[x, y]...], "portal": [x, y]} of the level's secret,
plus optional "walls" (cells that become crates), "open_layers" (layers whose
cells are floor), "path_layers" (layers drawn as paths).

Only the layout is read from the old scene: which 16 px cells are walkable
(GRID, the route grid of the running level), which are water or dense
greenery (from the average colour of the tiles drawn there), and where the
player, enemies, items, teleports and turrets are. Areas that the scene kept
far apart (joined by teleports) are packed next to each other.

The map grammar is in Misc/Builder/built_level.gd. After the map rows, a line
"---" starts the extras, one per line, in map pixels:
    tp X Y DX DY        teleport at X,Y to DX,DY
    turret X Y DIR      AI DataCenter turret (DIR: left right up down)
"""
import json
import math
import os
import sys
from collections import deque

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
ORIG = os.path.join(GAME, "Tools", "art", "orig", "levels")
T = 16

SCENE_CHARS = {
    "Enemy.tscn": "E", "Elite.tscn": "L", "trash_bag.tscn": "B", "eco_token.tscn": "C", "heart.tscn": "H",
    "feather.tscn": "F", "barile.tscn": "R", "eco_chest.tscn": "K", "trash.tscn": "W",
    "destructible_obj.tscn": "V",
}

_tex = {}


def texture(res):
    """Pixels of a texture: the untouched original when there is one."""
    if res not in _tex:
        rel = res.replace("res://", "")
        p = os.path.join(ORIG, rel)
        if not os.path.exists(p):
            p = os.path.join(GAME, rel)
        _tex[res] = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    return _tex[res]


_avg = {}


def block_colour(res, rx, ry, rw, rh, fx, fy, alt):
    """Average colour and coverage of the part of an atlas tile under one 16 px cell.
    fx, fy: where the cell centre falls in the tile, 0..1."""
    key = (res, rx, ry, rw, rh, round(fx, 2), round(fy, 2), alt)
    if key in _avg:
        return _avg[key]
    im = texture(res)
    out = (0, 0, 0, 0.0)
    if im is not None:
        if alt & 0x1000:  # flip_h
            fx = 1 - fx
        if alt & 0x2000:  # flip_v
            fy = 1 - fy
        cx, cy = rx + fx * rw, ry + fy * rh
        s = min(8, rw / 2, rh / 2)
        x0, y0 = int(max(rx, cx - s)), int(max(ry, cy - s))
        x1, y1 = int(min(rx + rw, cx + s)), int(min(ry + rh, cy + s))
        r = g = b = n = 0
        tot = max(1, (x1 - x0) * (y1 - y0))
        px = im.load()
        for y in range(y0, y1):
            for x in range(x0, x1):
                if 0 <= x < im.width and 0 <= y < im.height:
                    p = px[x, y]
                    if p[3] > 128:
                        r += p[0]; g += p[1]; b += p[2]; n += 1
        out = (r / n, g / n, b / n, n / tot) if n else (0, 0, 0, 0.0)
    _avg[key] = out
    return out


def hsv(c):
    r, g, b = c[0] / 255, c[1] / 255, c[2] / 255
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        h = 0
    elif mx == r:
        h = 60 * (((g - b) / d) % 6)
    elif mx == g:
        h = 60 * ((b - r) / d + 2)
    else:
        h = 60 * ((r - g) / d + 4)
    return h, (d / mx if mx else 0), mx


def is_water(c):
    h, s, v = hsv(c)
    return 170 <= h <= 235 and s > 0.28 and v > 0.3


GREEN = ("forest", "park")
TILE_SOLID = ("city",)


def is_wood(c):
    h, s, v = hsv(c)
    return 10 <= h <= 50 and s > 0.3 and v > 0.25


def is_green(c):
    h, s, v = hsv(c)
    return 70 <= h <= 170 and s > 0.2


def load_grid(path):
    with open(path, "rb") as f:
        ox, oy, w, h = map(int, f.readline().split())
        data = f.read()[: w * h]
    return ox, oy, w, h, data


def convert(tiles_path, grid_path, theme, out_path, spot=None):
    d = json.load(open(tiles_path))
    layers = d["layers"]
    # ---- cells covered by tiles: ground colour (first drawn) and top colour (last drawn)
    open_layers = (spot or {}).get("open_layers", [])
    order = sorted(range(len(d["tiles"])), key=lambda i: (layers[d["tiles"][i][11]]["z"] + d["tiles"][i][10], d["tiles"][i][11]))
    cells = {}  # (cx, cy) -> dict(ground, top, solid_tile, n)
    for i in order:
        x, y, w, h, res, rx, ry, rw, rh, solid, z, li, alt = d["tiles"][i]
        L = layers[li]
        if not L["visible"] or L["alpha"] < 0.3 or L["name"] in open_layers:
            continue
        for cy in range(math.floor(y / T + 0.01), math.ceil((y + h) / T - 0.01)):
            for cx in range(math.floor(x / T + 0.01), math.ceil((x + w) / T - 0.01)):
                fx = ((cx + 0.5) * T - x) / w
                fy = ((cy + 0.5) * T - y) / h
                if not (0 <= fx <= 1 and 0 <= fy <= 1):
                    continue
                col = block_colour(res, rx, ry, rw, rh, fx, fy, alt)
                if col[3] < 0.15:
                    continue
                c = cells.setdefault((cx, cy), {"ground": None, "top": None, "layers": 0, "solid": False})
                if c["ground"] is None or (col[3] > 0.9 and c["layers"] == 0):
                    c["ground"] = col
                c["top"] = col
                c["layers"] += 1
                c["solid"] |= bool(solid)
                if solid and col[3] > 0.5:
                    c["solid_cov"] = True
    # ---- walkability from the route grid (8 px)
    gox, goy, gw, gh, g = load_grid(grid_path)

    def gsolid(px, py):
        gx, gy = int((px - gox) // 8), int((py - goy) // 8)
        if 0 <= gx < gw and 0 <= gy < gh:
            return g[gy * gw + gx] == 35
        return True

    def solidity(cx, cy):
        return sum(gsolid(cx * T + ox, cy * T + oy) for ox in (4, 12) for oy in (4, 12))

    # ---- first pass: terrain characters
    m = {}
    trunks = set()
    for (cx, cy), c in cells.items():
        n = solidity(cx, cy)
        if theme in TILE_SOLID and c.get("solid_cov"):
            n = 4  # walls the route grid doesn't see (City: collision layer 1 only)
        gr, top = c["ground"], c["top"]
        # water: in the Forest the lakes are fenced by their shores; elsewhere
        # only water that blocks counts (blue floors and asphalt don't)
        if theme in TILE_SOLID:
            # City: blue glass is not water; the park pond is bright and has no collision tile
            wet = gr and is_water(gr) and hsv(gr)[2] > 0.5 and not c.get("solid_cov")
        else:
            wet = gr and is_water(gr) and theme != "datacenter" and (n >= 2 or theme == "forest" or (top and is_wood(top)))
        if wet:
            # water stays water, unless something walkable is drawn over it (a bridge)
            if n < 2 and top and is_wood(top):
                m[(cx, cy)] = "="
            elif n < 2 and top and not is_water(top):
                m[(cx, cy)] = "."   # grass of the shore drawn over the water's edge
            else:
                m[(cx, cy)] = "~"
        elif n >= 2:
            m[(cx, cy)] = "&" if theme in GREEN else "#"
        else:
            m[(cx, cy)] = "."
            if n == 1:
                trunks.add((cx, cy))
    # a wall cell touching water is part of the shore
    for k, ch in list(m.items()):
        if ch in "#&" and any(m.get((k[0] + dx, k[1] + dy)) == "~" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            if is_water(cells[k]["ground"] or (0, 0, 0)) or theme in ("forest", "park", "lake"):
                m[k] = "~"
    for k in trunks:
        m[k] = "#"
    # layers that vanish in play (a hidden passage): their cells are floor
    for x, y, w, h, res, rx, ry, rw, rh, solid, z, li, alt in d["tiles"]:
        if layers[li]["name"] in open_layers:
            for cy in range(math.floor(y / T + 0.01), math.ceil((y + h) / T - 0.01)):
                for cx in range(math.floor(x / T + 0.01), math.ceil((x + w) / T - 0.01)):
                    m[(cx, cy)] = "."
    # small blocked islands are props, not walls
    seen = set()
    for k, ch in list(m.items()):
        if ch not in "#&" or k in seen:
            continue
        comp, q = [], deque([k])
        seen.add(k)
        while q:
            p = q.popleft()
            comp.append(p)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (p[0] + dx, p[1] + dy)
                if n not in seen and m.get(n) in ("#", "&"):
                    seen.add(n)
                    q.append(n)
        if len(comp) <= 6:
            for p in comp:
                m[p] = "."
            xs = [p[0] for p in comp]
            bottom = max(p[1] for p in comp)
            if theme in GREEN:  # tree trunks
                m[(round(sum(xs) / len(xs)), bottom)] = "T" if len(comp) >= 2 or (bottom + round(sum(xs))) % 3 else "X"
            else:
                m[(round(sum(xs) / len(xs)), bottom)] = "T" if len(comp) >= 4 else ("x" if len(comp) >= 2 else "X")
    # trees drawn as tiles (Forest, City park): one tree prop at each trunk
    if theme in GREEN or theme == "city":
        for x, y, w, h, res, rx, ry, rw, rh, solid, z, li, alt in d["tiles"]:
            if not solid or h < 32 or "Tree" not in layers[li]["name"]:
                continue
            k = (int((x + w / 2) // T), int((y + h - 6) // T))
            if m.get(k) not in (".", ","):
                continue
            if any(m.get((k[0] + dx, k[1] + dy)) in ("T", "X") for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                continue
            m[k] = "T"
    # paths: the less common floor colour that is not grass-like
    floor_cells = [k for k, ch in m.items() if ch == "."]
    for k in floor_cells:
        gr = cells[k]["ground"]
        if gr and path_like(gr, theme):
            m[k] = ","
    # layers named in the spot file are paths wherever they're walkable
    for x, y, w, h, res, rx, ry, rw, rh, solid, z, li, alt in d["tiles"]:
        if layers[li]["name"] in (spot or {}).get("path_layers", []):
            for cy in range(math.floor(y / T + 0.01), math.ceil((y + h) / T - 0.01)):
                for cx in range(math.floor(x / T + 0.01), math.ceil((x + w) / T - 0.01)):
                    if m.get((cx, cy)) == ".":
                        m[(cx, cy)] = ","
    for x, y, w, h, res, rx, ry, rw, rh, solid, z, li, alt in d["tiles"]:
        if not solid and layers[li]["name"] in (spot or {}).get("bridge_layers", []):
            for cy in range(math.floor(y / T + 0.01), math.ceil((y + h) / T - 0.01)):
                for cx in range(math.floor(x / T + 0.01), math.ceil((x + w) / T - 0.01)):
                    if m.get((cx, cy)) in ("~", "#", "."):
                        m[(cx, cy)] = "="
    # ---- things
    extras = []
    things = {}

    def free_cell(px, py, avoid=()):
        cx, cy = int(px // T), int(py // T)
        best = None
        for r in range(0, 8):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    k = (cx + dx, cy + dy)
                    if m.get(k) in (".", ",", "=") and k not in things and k not in avoid:
                        dd = dx * dx + dy * dy
                        if best is None or dd < best[0]:
                            best = (dd, k)
            if best:
                return best[1]
        return None

    for n in d["nodes"]:
        sc = n["scene"].split("/")[-1]
        ch = SCENE_CHARS.get(sc)
        if n["name"] == "PlayerSpawn":
            ch = "P"
        if ch:
            k = free_cell(n["x"], n["y"])
            if k:
                things[k] = ch
        if "dest" in n:
            extras.append(("tp", n["x"], n["y"], n["dest"][0], n["dest"][1]))
        if sc == "turret.tscn":
            folder = n["script"]  # same script for all; direction from the scene folder
            dirn = {"turret": "left", "turretDown": "down", "turretRight": "right", "turretUp": "up"}[n["scene"].split("/")[-2]]
            extras.append(("turret", n["x"], n["y"], dirn))
    if spot:
        for c in spot.get("crates", []):
            k = (int(c[0] // T), int(c[1] // T))
            m[k] = "."
            things[k] = "V"
        k = free_cell(spot["portal"][0], spot["portal"][1])
        if k:
            things[k] = "Y"
        for c in spot.get("walls", []):  # cells of a wall that the seals open
            k = (int(c[0] // T), int(c[1] // T))
            m[k] = "."
            things[k] = "V"
    m.update(things)
    # ---- close the map: void next to walkable ground becomes wall / greenery
    edge = "&" if theme in GREEN else "#"
    for (cx, cy), ch in list(m.items()):
        if ch in "#&~ ":
            continue
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                k = (cx + dx, cy + dy)
                if k not in m:
                    m[k] = edge
    # ---- pack the areas (connected groups of cells) next to each other
    comps = components(m)
    placed, shift = pack(comps)
    rows = {}
    for ci, comp in enumerate(comps):
        sx, sy = shift[ci]
        for (cx, cy) in comp:
            rows[(cx + sx, cy + sy)] = m[(cx, cy)]
    W = max(k[0] for k in rows) + 1
    H = max(k[1] for k in rows) + 1
    lines = ["".join(rows.get((x, y), " ") for x in range(W)).rstrip() for y in range(H)]
    cell_comp = {}
    for ci, comp in enumerate(comps):
        for k in comp:
            cell_comp[k] = ci

    def moved(px, py):
        k = (int(px // T), int(py // T))
        ci = cell_comp.get(k)
        if ci is None:  # nearest cell of any area
            ci = min(range(len(comps)), key=lambda i: min(abs(c[0] - k[0]) + abs(c[1] - k[1]) for c in comps[i][:400]))
        sx, sy = shift[ci]
        return px + sx * T, py + sy * T

    out = []
    for e in extras:
        if e[0] == "tp":
            a = moved(e[1], e[2])
            b = moved(e[3], e[4])
            out.append("tp %d %d %d %d" % (a[0], a[1], b[0], b[1]))
        else:
            a = moved(e[1], e[2])
            out.append("turret %d %d %s" % (a[0], a[1], e[3]))
    lines = fill_pockets(lines, out, "&" if theme in GREEN else "#")
    report(lines, out)
    with open(out_path, "w") as f:
        f.write("\n".join(lines) + "\n")
        if out:
            f.write("---\n" + "\n".join(out) + "\n")
    print(out_path, W, "x", H, "areas:", len(comps), "extras:", len(out))


WALK = set(".,=_oOPBECHFRKLSWDGVY") | {"X", "x"}


def reach(lines, extras):
    H = len(lines)

    def at(x, y):
        return lines[y][x] if 0 <= y < H and 0 <= x < len(lines[y]) else " "
    start = [(x, y) for y in range(H) for x in range(len(lines[y])) if lines[y][x] == "P"]
    tps = []
    for e in extras:
        if e.startswith("tp "):
            a = list(map(int, e.split()[1:]))
            tps.append(((a[0] // T, a[1] // T), (a[2] // T, a[3] // T)))
    seen = set(start)
    q = deque(start)
    while q:
        c = q.popleft()
        nxt = [(c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)]
        for a, b in tps:
            if abs(a[0] - c[0]) <= 1 and abs(a[1] - c[1]) <= 1:
                nxt.append(b)
        for n in nxt:
            if n not in seen and at(*n) in WALK:
                seen.add(n)
                q.append(n)
    return seen


def fill_pockets(lines, extras, wall):
    """Small floor pockets nobody can walk into (inside buildings, between
    trunks) become solid, so they don't show as holes."""
    seen = reach(lines, extras)
    rows = [list(l) for l in lines]
    done = set()
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c not in ".," or (x, y) in seen or (x, y) in done:
                continue
            comp, q = [], deque([(x, y)])
            done.add((x, y))
            while q:
                p = q.popleft()
                comp.append(p)
                for n in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)):
                    if n not in done and 0 <= n[1] < len(rows) and 0 <= n[0] < len(rows[n[1]]) and rows[n[1]][n[0]] in ".,":
                        done.add(n)
                        q.append(n)
            if len(comp) <= 60:
                for (px, py) in comp:
                    rows[py][px] = wall
    return ["".join(r) for r in rows]


def report(lines, extras):
    """Things that can't be reached from P (walking, plus teleports)."""
    H = len(lines)
    def at(x, y):
        return lines[y][x] if 0 <= y < H and 0 <= x < len(lines[y]) else " "
    start = [(x, y) for y in range(H) for x in range(len(lines[y])) if lines[y][x] == "P"]
    tps = []
    for e in extras:
        if e.startswith("tp "):
            a = list(map(int, e.split()[1:]))
            tps.append(((a[0] // T, a[1] // T), (a[2] // T, a[3] // T)))
    seen = set(start)
    q = deque(start)
    while q:
        c = q.popleft()
        nxt = [(c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)]
        for a, b in tps:
            if abs(a[0] - c[0]) <= 1 and abs(a[1] - c[1]) <= 1:
                nxt.append(b)
        for n in nxt:
            if n not in seen and at(*n) in WALK:
                seen.add(n)
                q.append(n)
    lost = [(x, y, lines[y][x]) for y in range(H) for x in range(len(lines[y]))
            if lines[y][x] in "BECKLRHFWY" and (x, y) not in seen]
    print("  unreachable:", lost[:20], "..." if len(lost) > 20 else "")


def path_like(c, theme):
    h, s, v = hsv(c)
    if theme in ("forest", "park"):
        return not (60 <= h <= 175 and s > 0.15)   # not grass: dirt, stone
    if theme == "lake":
        return not (25 <= h <= 60 and s > 0.15 and v > 0.55)  # not sand
    if theme == "snow":
        return v < 0.62 or s > 0.25                 # not snow: rock, ice, earth
    if theme == "city":
        return v < 0.45                             # dark asphalt
    if theme == "datacenter":
        return v < 0.3                              # dark corridors
    return False


def components(m):
    seen = set()
    comps = []
    for k in m:
        if k in seen or m[k] == " ":
            continue
        comp, q = [], deque([k])
        seen.add(k)
        while q:
            p = q.popleft()
            comp.append(p)
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    n = (p[0] + dx, p[1] + dy)
                    if n not in seen and n in m and m[n] != " ":
                        seen.add(n)
                        q.append(n)
        comps.append(comp)
    comps = [c for c in comps if len(c) > 20]
    comps.sort(key=lambda c: -len(c))
    return comps


def pack(comps, gap=6):
    """Shelf packing: the biggest area first, the others in rows below it."""
    boxes = []
    for c in comps:
        xs = [p[0] for p in c]
        ys = [p[1] for p in c]
        boxes.append((min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1))
    width = max(max(b[2] for b in boxes), 120)
    shift = {}
    x = y = 0
    shelf = 0
    for i, (bx, by, bw, bh) in enumerate(boxes):
        if x > 0 and x + bw > width:
            x = 0
            y += shelf + gap
            shelf = 0
        shift[i] = (x - bx + 1, y - by + 1)
        x += bw + gap
        shelf = max(shelf, bh)
    return None, shift


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) < 4:
        sys.exit(__doc__)
    spot = json.loads(open(a[4]).read()) if len(a) > 4 else None
    convert(a[0], a[1], a[2], a[3], spot)
