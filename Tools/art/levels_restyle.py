"""Light redesign of the tilesets used by the original levels
(Forest, City, Lake/Beach, Snow Path, AI DataCenter).

Nothing moves: every image keeps its size, its tile layout and its exact alpha,
so tilemaps, collisions and atlas regions in the scenes stay valid.
What changes:
  1. a per-level palette ("theme"): hue remaps for the key materials
     (grass, earth, water, stone, neon...), shadows that lean toward the level's
     shadow color, lights that lean toward its light color, a bit of contrast;
  2. on the prop sheets only (never on terrain atlases, so tiles stay seamless):
     colored outlines instead of flat black and a soft top-left rim light.

The untouched originals live in orig/levels/ (same relative paths as in the
game), so the script always starts from them and can be re-run safely:

    python3 levels_restyle.py OUT            # write into OUT/<game path>
    python3 levels_restyle.py --game         # write straight into the project
    python3 levels_restyle.py OUT forest snow   # only some themes
"""
import colorsys
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ORIG = os.path.join(HERE, "orig", "levels")

L = "Levels/"


def hls(c):
    return colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return (round(r * 255), round(g * 255), round(b * 255))


def toward(deg, target, amt):
    diff = ((target - deg + 540) % 360) - 180
    return deg + diff * amt


# remap: (hue_lo, hue_hi, min_sat, target_hue, pull 0..1, sat_mul, light_add)
THEMES = {
    # deep emerald woods, mossy teal shadows, warm sun on the leaves
    "forest": {
        "files": [L + "Forest_level/Assets/Sprites/forest_terrain.png",
                  L + "Forest_level/Assets/Sprites/Pixeival wood tileset.png"],
        "props": [L + "Forest_level/Assets/Sprites/forest_objects.png"],
        "remap": [(65, 170, 0.15, 150, 0.75, 1.2, -0.05),    # grass/leaves -> deep emerald
                  (0, 50, 0.12, 18, 0.45, 1.15, -0.02),      # earth/wood -> warm red-brown
                  (340, 360, 0.12, 18, 0.45, 1.15, -0.02),
                  (180, 230, 0.15, 180, 0.75, 1.15, 0.0)],    # water -> teal
        "neutral": (40, 0.1),                                # stones get a warm tint
        "shadow": (195, 0.38), "light": (55, 0.24), "sat": 1.08, "contrast": 1.1,
    },
    # the city park: fresher lime grass, cleaner paths
    "park": {
        "files": [L + "City_level/Assets/Sprites/park_terrain.png"],
        "props": [L + "City_level/Assets/Sprites/park_objects.png"],
        "remap": [(65, 170, 0.15, 104, 0.3, 1.1, 0.02),
                  (10, 50, 0.12, 32, 0.3, 1.0, 0.02),
                  (180, 230, 0.15, 200, 0.35, 1.1, 0.02)],
        "shadow": (235, 0.18), "light": (48, 0.12), "sat": 1.05, "contrast": 1.05,
    },
    # downtown at golden hour: indigo shadows, warm lit facades, lilac concrete
    "city": {
        "files": [L + "City_level/Assets/Sprites/city.png"],
        "props": [L + "City_level/Assets/Sprites/city-signs.png"],
        "remap": [(195, 250, 0.12, 186, 0.6, 1.2, 0.02),     # glass / blue buildings -> teal
                  (330, 360, 0.2, 325, 0.7, 1.1, 0.0),       # maroon facades -> plum
                  (0, 30, 0.2, 330, 0.55, 1.1, 0.0),
                  (30, 65, 0.2, 38, 0.5, 1.2, 0.03)],        # yellow / orange -> amber
        "neutral": (262, 0.25),                              # greys get a lilac tint
        "shadow": (245, 0.45), "light": (38, 0.3), "sat": 1.15, "contrast": 1.1,
    },
    # the lake: sunny gold sand, bright turquoise water
    "lake": {
        "files": [L + "BeachLevel/Assets/Sprites/beachtileset.png",
                  L + "BeachLevel/Assets/Sprites/city.png",
                  L + "BeachLevel/Assets/Sprites/interiors_demo.png"],
        "props": [L + "BeachLevel/Assets/Sprites/cuttouts.png"],
        "remap": [(35, 70, 0.12, 44, 0.45, 1.2, 0.02),       # sand -> gold
                  (185, 235, 0.12, 180, 0.75, 1.3, 0.03),   # water -> turquoise
                  (0, 35, 0.15, 14, 0.4, 1.15, 0.01)],       # wood / roofs -> coral
        "neutral": (38, 0.12),                               # greys warm up in the sun
        "shadow": (190, 0.35), "light": (45, 0.22), "sat": 1.1, "contrast": 1.07,
    },
    # frozen path: ice-blue shadows, crisp highlights, colder rock
    "snow": {
        "files": [L + "SnowPathLevel/Assets/Sprites/seasonal sample (winter).png",
                  L + "SnowPathLevel/Assets/Sprites/TilesetFloor.png",
                  L + "SnowPathLevel/Assets/Sprites/Cave_Classic.png",
                  L + "SnowPathLevel/Assets/Sprites/Tileset_Dungeon.png",
                  L + "SnowPathLevel/Assets/Sprites/sCaveTile.png",
                  L + "SnowPathLevel/Assets/Sprites/spr_cave.png",
                  L + "SnowPathLevel/Assets/Sprites/walls.png"],
        "props": [L + "SnowPathLevel/Assets/Sprites/Cave_objects_source.png"],
        "remap": [(50, 110, 0.04, 205, 1.0, 0.45, 0.05),     # khaki snow -> cold blue-white
                  (180, 260, 0.08, 208, 0.35, 1.15, 0.0),    # rock / ice -> glacier blue
                  (0, 45, 0.1, 20, 0.3, 0.6, 0.02),          # wood / red earth: frosted, colder
                  (330, 360, 0.1, 20, 0.3, 0.6, 0.02)],
        "neutral": (212, 0.2),
        "shadow": (222, 0.5), "light": (190, 0.18), "sat": 1.05, "contrast": 1.1,
    },
    # AI DataCenter: cold steel, orange alerts turned into magenta neon
    "datacenter": {
        "files": [L + "Ai DataCenter_level/Assets/Sprites/Tiles.png",
                  L + "Ai DataCenter_level/Assets/Sprites/city_roads_new.png",
                  L + "Ai DataCenter_level/Assets/Sprites/pixel-cyberpunk-interior.png",
                  L + "Ai DataCenter_level/Assets/Sprites/pixel-cyberpunk-interior2.png"],
        "props": [],
        "remap": [(0, 45, 0.35, 322, 0.8, 1.1, 0.02),        # orange/red -> magenta neon
                  (345, 360, 0.35, 322, 0.8, 1.1, 0.02),
                  (175, 205, 0.3, 182, 0.4, 1.2, 0.04),      # cyan screens -> brighter
                  (205, 260, 0.04, 232, 0.5, 1.4, 0.0)],     # steel -> blue-violet
        "neutral": (232, 0.1),
        "shadow": (250, 0.3), "light": (190, 0.1), "sat": 1.05, "contrast": 1.1,
    },
}


def theme_color(c, t):
    h, l, s = hls(c)
    deg = h * 360
    for lo, hi, min_s, target, pull, smul, ladd in t["remap"]:
        if lo <= deg < hi and s >= min_s:
            deg = toward(deg, target, pull)
            s *= smul
            l += ladd
            break
    else:
        if s < 0.1 and "neutral" in t:  # greys pick up the level's tint
            nh, ns = t["neutral"]
            deg, s = nh, max(s, ns * (1 - abs(l - 0.5) * 1.4))
    sh, sa = t["shadow"]
    lh, la = t["light"]
    # hue drift only toward nearby hues, so browns never slide through green
    if l < 0.4 and abs(((sh - deg + 540) % 360) - 180) < 100:
        k = (0.4 - l) / 0.4
        deg = toward(deg, sh, sa * k)
        s = s + (0.25 - s) * 0.15 * k if s < 0.25 else s
    elif l > 0.62 and abs(((lh - deg + 540) % 360) - 180) < 100:
        deg = toward(deg, lh, la * (l - 0.62) / 0.38)
    s = min(1.0, s * t["sat"])
    l = 0.5 + (l - 0.5) * t["contrast"]
    if l < 0.06:  # flat black -> tinted dark
        return rgb(sh / 360, 0.07, 0.3)
    return rgb(deg / 360, l, s)


def restyle(src_path, dst_path, t, props):
    im = Image.open(src_path).convert("RGBA")
    W, H = im.size
    src = im.load()
    cache = {}

    def col(c):
        k = c[:3]
        if k not in cache:
            cache[k] = theme_color(k, t)
        return cache[k]

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dst = out.load()

    def solid(x, y):
        return 0 <= x < W and 0 <= y < H and src[x, y][3] > 0

    for y in range(H):
        for x in range(W):
            c = src[x, y]
            a = c[3]
            if a == 0:
                continue
            nc = col(c)
            if props:
                edge = not (solid(x + 1, y) and solid(x - 1, y) and solid(x, y + 1) and solid(x, y - 1))
                h, l, s = hls(c)
                if edge and l < 0.25:
                    # colored outline: dark shade of the color it encloses
                    inner = None
                    for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1), (1, 1), (-1, 1)):
                        nx, ny = x + dx, y + dy
                        if solid(nx, ny) and hls(src[nx, ny])[1] >= 0.25:
                            inner = col(src[nx, ny])
                            break
                    if inner is not None:
                        ih, il, is_ = hls(inner)
                        nc = rgb(toward(ih * 360, t["shadow"][0], 0.3) / 360, 0.11, min(0.6, is_ * 0.8 + 0.12))
                elif not edge:
                    # rim light on the top-left inside the outline, shade at the bottom
                    up = solid(x, y - 1) and hls(src[x, y - 1])[1] < 0.25 or not solid(x, y - 2)
                    left = solid(x - 1, y) and hls(src[x - 1, y])[1] < 0.25 or not solid(x - 2, y)
                    down = not solid(x, y + 2)
                    hh, ll, ss = hls(nc)
                    if up or left:
                        nc = rgb(toward(hh * 360, t["light"][0], 0.08) / 360, ll + (0.06 if up else 0.04), ss)
                    elif down:
                        nc = rgb(hh, ll - 0.035, ss)
            dst[x, y] = nc + (a,)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    out.save(dst_path, optimize=True)


def ensure_orig(rel):
    """First run: keep a copy of the untouched original."""
    o = os.path.join(ORIG, rel)
    if not os.path.exists(o):
        os.makedirs(os.path.dirname(o), exist_ok=True)
        shutil.copy2(os.path.join(GAME_ROOT, rel), o)
    return o


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    out_root = GAME_ROOT if args[0] == "--game" else args[0]
    only = args[1:] or list(THEMES)
    for name in only:
        t = THEMES[name]
        for rel in t["files"]:
            restyle(ensure_orig(rel), os.path.join(out_root, rel), t, False)
        for rel in t["props"]:
            restyle(ensure_orig(rel), os.path.join(out_root, rel), t, True)
        print("done", name)
