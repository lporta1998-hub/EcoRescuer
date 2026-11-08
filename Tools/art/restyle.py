"""Restyle EcoRescuer character sprite sheets, frame-agnostic.

Every pixel is processed the same way in every frame, so all animations stay
in sync:
  1. signature recolor: a few exact palette colors per character (their
     clothes) move to that character's identity color;
  2. grading: shadows lean cool, lights lean warm, slightly more saturation;
     near-black inner pixels are lifted to a tinted dark;
  3. colored outlines ("sel-out"): outline pixels take a dark shade of the
     color they enclose instead of flat black;
  4. rim light: inner pixels just under/after the outline on the top-left
     catch a little light, the bottom ones a little shade.
"""
import os
import colorsys, os, sys
from PIL import Image
GAME_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) + "/"  # the EcoRescuer project

ROOT = GAME_ROOT


def hls(c):
    return colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0, min(1, l)), max(0, min(1, s)))
    return (round(r * 255), round(g * 255), round(b * 255))


def recolor(colors, hue, sat, l_off, l_mul):
    """Rule: these exact colors -> hue/sat, lightness l_off + l_mul * L."""
    return (set(colors), lambda h, l, s: (hue / 360, l_off + l_mul * l, sat))


CHARS = {
    "Labra": {
        "files": ["Characters/CharacterLabra/Assets/Sprites/Labra.png",
                  "Characters/CharacterLabra/Assets/Sprites/Labra_attacks.png",
                  "Characters/CharacterLabra/Assets/Sprites/LabraDeath.png"],
        "rules": [
            # shirt: dark greys -> emerald eco jacket
            recolor([(15, 12, 10), (19, 19, 22), (41, 30, 45), (85, 40, 85),
                     (58, 45, 56)], 150, 0.55, 0.13, 1.6),
            # shorts: charcoal -> slate blue
            recolor([(48, 45, 45)], 220, 0.22, 0.12, 1.2),
            # hair: almost-black purple -> rich indigo
            recolor([(22, 5, 47), (30, 9, 62), (36, 5, 67)], 255, 0.42, 0.07, 1.65),
            # shirt logo -> leaf yellow-green
            recolor([(193, 196, 217), (158, 160, 194)], 80, 0.7, 0.05, 0.9),
        ],
    },
    "Ranger": {
        "files": ["Characters/CharacterRanger/Assets/Sprites/RangerIdle.png",
                  "Characters/CharacterRanger/Assets/Sprites/shoot.png",
                  "Characters/CharacterRanger/Assets/Sprites/character-spritesheet (2).png",
                  "Characters/CharacterRanger/Assets/Sprites/hurt.png",
                  "Characters/CharacterRanger/Assets/Sprites/RangerRun.png"],
        "rules": [
            # black outfit -> deep forest green
            recolor([(34, 40, 42), (42, 48, 52), (28, 34, 34), (74, 80, 87)], 128, 0.2, 0.05, 1.35),
            # hair: navy -> brighter teal-navy
            recolor([(4, 11, 24), (6, 20, 33), (7, 31, 42), (13, 56, 77), (26, 83, 105)], 200, 0.6, 0.05, 1.35),
        ],
    },
    "Nerd": {
        "files": ["Characters/CharacterNerd/Assets/Sprites/idle.png",
                  "Characters/CharacterNerd/Assets/Sprites/walk.png",
                  "Characters/CharacterNerd/Assets/Sprites/hurt.png",
                  "Characters/CharacterNerd/Assets/Sprites/slash_oversize.png"],
        "rules": [
            # dark purple jacket -> royal "tech" blue
            recolor([(41, 37, 58), (52, 48, 67), (27, 25, 43), (29, 19, 30)], 218, 0.55, 0.07, 1.7),
            # green vest -> brighter leaf green
            recolor([(68, 109, 41), (49, 79, 34), (24, 38, 17), (32, 52, 22)], 105, 0.55, 0.05, 1.25),
        ],
    },
    "Boarman": {
        "files": ["Characters/CharacterBoar/Assets/Sprites/boar-character.png"],
        "rules": [
            # fur: warmer, a bit brighter
            recolor([(118, 81, 58), (156, 102, 62), (184, 119, 63), (95, 69, 57), (157, 102, 57)],
                    24, 0.5, 0.03, 1.08),
            # pants: richer green
            recolor([(33, 68, 55), (11, 92, 47), (47, 129, 54), (100, 164, 44)], 140, 0.55, 0.03, 1.15),
            # pants shadow navy -> deep teal
            recolor([(25, 40, 50)], 190, 0.4, 0.03, 1.2),
        ],
    },
}


def grade(c):
    h, l, s = hls(c)
    deg = h * 360
    # hue-shift: shadows toward blue-violet, lights toward warm yellow
    if l < 0.35 and s > 0.05:
        t = (0.35 - l) / 0.35
        target = 240
        diff = ((target - deg + 540) % 360) - 180
        deg += diff * 0.12 * t
    elif l > 0.6 and s > 0.05:
        t = (l - 0.6) / 0.4
        target = 50
        diff = ((target - deg + 540) % 360) - 180
        deg += diff * 0.10 * t
    s = min(1.0, s * 1.12 + 0.02)
    if l < 0.07:  # flat black inside a sprite -> tinted dark
        return rgb(250 / 360, 0.09, 0.25)
    return rgb(deg / 360, l, s)


def process(path, rules, out_path):
    im = Image.open(path).convert("RGBA")
    W, H = im.size
    src = im.load()
    mapped = {}

    def map_color(c):
        key = c[:3]
        if key not in mapped:
            new = key
            for colors, fn in rules:
                if key in colors:
                    h, l, s = hls(key)
                    nh, nl, ns = fn(h, l, s)
                    new = rgb(nh, nl, ns)
                    break
            mapped[key] = grade(new) if new == key else rgb(*_g(new))
        return mapped[key]

    def _g(c):  # recolored pixels get the hue-shift grading too
        g = grade(c)
        return hls(g)

    def opaque(x, y):
        return 0 <= x < W and 0 <= y < H and src[x, y][3] > 0

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dst = out.load()
    edge = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if src[x, y][3] == 0:
                continue
            edge[y][x] = not (opaque(x + 1, y) and opaque(x - 1, y) and opaque(x, y + 1) and opaque(x, y - 1))
    for y in range(H):
        for x in range(W):
            a = src[x, y][3]
            if a == 0:
                continue
            c = src[x, y]
            h, l, s = hls(c)
            if edge[y][x] and l < 0.22:
                # colored outline: darkest shade of the inner neighbour's color
                inner = None
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    nx, ny = x - dx, y - dy  # look inwards
                    if opaque(nx, ny) and not edge[ny][nx]:
                        inner = map_color(src[nx, ny])
                        break
                if inner is None:
                    for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if opaque(nx, ny) and not edge[ny][nx]:
                            inner = map_color(src[nx, ny])
                            break
                if inner is None:
                    dst[x, y] = (24, 18, 34, a)
                else:
                    ih, il, is_ = hls(inner)
                    dst[x, y] = rgb(ih + (250 / 360 - ih) * 0.25, 0.1, min(0.55, is_ * 0.8 + 0.1)) + (a,)
                continue
            nc = map_color(c)
            # rim light from the top-left, shade at the bottom
            up = not opaque(x, y - 1) or edge[y - 1][x]
            left = not opaque(x - 1, y) or edge[y][x - 1]
            down = not opaque(x, y + 1) or edge[y + 1][x] if y + 1 < H else True
            if up or left:
                hh, ll, ss = hls(nc)
                nc = rgb(hh + (50 / 360 - hh) * 0.05, ll + (0.07 if up else 0.045), ss)
            elif down:
                hh, ll, ss = hls(nc)
                nc = rgb(hh, ll - 0.04, ss)
            dst[x, y] = nc + (a,)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path)


if __name__ == "__main__":
    out_root = sys.argv[1]
    only = sys.argv[2:] or list(CHARS)
    for name in only:
        cfg = CHARS[name]
        for f in cfg["files"]:
            process(ROOT + f, cfg["rules"], os.path.join(out_root, f))
        print("done", name)
