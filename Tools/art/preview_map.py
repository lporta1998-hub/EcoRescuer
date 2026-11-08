"""Renders a BuiltLevel v2 map the way the game draws it (for quick iteration).
usage: preview_map.py map.txt theme out.png [x0 y0 w h (cells)]"""
import sys, os, zlib
from PIL import Image

T = 16
CAT = {
    "ruins": {"T": ["tree_0", "tree_1", "tree_2", "tree_3"], "x": ["pillar_0", "pillar_1", "statue_0", "rock_0", "rock_1"],
              "X": ["bush_0", "bush_1"], "&": ["tree_0", "tree_1", "tree_2", "tree_3"], "b": []},
    "factory": {"T": ["machine_0", "tank_0", "tank_1", "pipes_0"], "x": ["drums_0", "crates_0"], "X": ["crates_0"], "&": ["pipes_0", "tank_0", "tank_1", "chimney_0", "pipes_0", "crates_0", "drums_0", "machine_0"], "b": []},
    "harbor": {"T": ["container_0", "container_1", "container_2"], "x": ["crates_0", "drums_0"], "X": ["bollard_0"],
               "&": ["container_0", "container_1", "container_2"], "b": ["boat_0"]},
    "fortress": {"T": ["junk_0", "junk_1", "car_0"], "x": ["tires_0", "drums_0", "banner_0"], "X": ["tires_0"],
                 "&": ["junk_0", "junk_1"], "b": []},
}
FLOORS = [0, 0, 0, 0, 1, 1, 2, 3, 4, 5]


def h(x, y, s=0):
    return zlib.crc32(f"{x},{y},{s}".encode())


def main():
    mp, theme, out = sys.argv[1:4]
    rows = open(mp).read().replace("\r", "").split("\n")
    W = max(len(r) for r in rows)
    H = len(rows)
    ch = lambda x, y: rows[y][x] if 0 <= y < H and 0 <= x < len(rows[y]) else " "
    tdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tiles2")
    pdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "props", theme)
    atlas = Image.open(os.path.join(tdir, theme + ".png"))
    water = Image.open(os.path.join(tdir, theme + "_water.png"))
    path = Image.open(os.path.join(tdir, theme + "_path.png"))
    tile = lambda i: atlas.crop(((i % 8) * T, (i // 8) * T, (i % 8) * T + T, (i // 8) * T + T))
    img = Image.new("RGBA", (W * T, H * T), (0, 0, 0, 255))
    ENT = set("PBECHFRKDSLZGTxX")

    def is_path(x, y):
        c = ch(x, y)
        if c in ",_":
            return True
        if c in ENT or c in "oO":
            return sum(ch(x + dx, y + dy) in ",_" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 2
        return False

    def is_water(x, y):
        return ch(x, y) in "~=b"

    for y in range(H):
        for x in range(W):
            c = ch(x, y)
            if c == " ":
                continue
            if c == "&":
                inner = all(ch(x + dx, y + dy) == "&" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                i = 14 if inner else 9
            else:
                i = 8 if c in "~b" else FLOORS[h(x, y) % len(FLOORS)]
            img.alpha_composite(tile(i), (x * T, y * T))
    for layer, fn in ((water, is_water), (path, is_path)):
        for y in range(H + 1):
            for x in range(W + 1):
                idx = fn(x - 1, y - 1) * 1 + fn(x, y - 1) * 2 + fn(x - 1, y) * 4 + fn(x, y) * 8
                if idx:
                    t = layer.crop(((idx % 4) * T, (idx // 4) * T, (idx % 4) * T + T, (idx // 4) * T + T))
                    img.alpha_composite(t, (x * T - 8, y * T - 8))
    for y in range(H):
        for x in range(W):
            c = ch(x, y)
            i = {"#": 6 if ch(x, y + 1) == "#" else 7, "=": 10, "o": 11, "O": 12, "_": 15, "G": 13}.get(c)
            if i is not None:
                img.alpha_composite(tile(i), (x * T, y * T))
            if c == "#" and ch(x, y - 1) not in "# ":
                img.alpha_composite(tile(6), (x * T, y * T - T))  # wall cap (no collision)
    # props (y-sorted)
    sprites = []
    cache = {}
    def spr(name):
        if name not in cache:
            cache[name] = Image.open(os.path.join(pdir, name + ".png"))
        return cache[name]
    cat = CAT[theme]
    for y in range(H):
        for x in range(W):
            c = ch(x, y)
            names = None
            jx = jy = 0
            if c in "TxXb":
                names = cat[c]
            elif c == "&" and ((y % 2 == 0 and (x + (y // 2) % 2 * 2) % 3 == 0) or
                               ((x + y) % 2 == 0 and any(ch(x + dx, y + dy) not in "&" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))))):
                names = cat["&"]
                jx, jy = h(x, y, 1) % 7 - 3, h(x, y, 2) % 5 - 2
            if names:
                s = spr(names[h(x, y, 3) % len(names)])
                fx, fy = x * T + 8 + jx, y * T + 14 + jy
                sprites.append((fy, fx, s))
    for fy, fx, s in sorted(sprites, key=lambda t: t[0]):
        img.alpha_composite(s, (fx - s.width // 2, fy - s.height + 3))
    if len(sys.argv) > 4:
        x0, y0, w, hh = map(int, sys.argv[4:8])
        img = img.crop((x0 * T, y0 * T, (x0 + w) * T, (y0 + hh) * T))
    img.save(out)


main()
