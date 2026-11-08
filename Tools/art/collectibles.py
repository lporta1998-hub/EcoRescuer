"""Redrawn EcoRescuer collectibles (same canvas sizes as the originals)."""
import math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from pixelkit import Canvas, shade_sphere, RAMPS, save
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)


def coin():
    # 14x17: an emerald eco-coin with a gold rim and an embossed leaf
    c = Canvas(14, 17)
    cx, cy, r = 6.5, 8.0, 5.9
    for y in range(17):
        for x in range(14):
            dx, dy = (x - cx) / r, (y - cy) / (r * 1.12)
            d = math.hypot(dx, dy)
            if d <= 1.0:
                if d > 0.78:  # rim
                    c.set(x, y, "gold", shade_sphere(dx * 0.9, dy * 0.9, 0.55))
                else:
                    c.set(x, y, "green", 0.42 - 0.18 * (dx + dy) * 0.6)
    # embossed leaf: a diagonal blade with a vein
    leaf = [(5, 10), (6, 9), (7, 8), (8, 7), (6, 10), (7, 9), (8, 8), (5, 9), (6, 8), (7, 7), (8, 6), (9, 6)]
    for (x, y) in leaf:
        c.set(x, y, "green", 0.8)
    for (x, y) in [(5, 11), (6, 10), (7, 9)]:
        c.set(x, y, "green", 0.25)
    c.pixel(4, 5, RAMPS["gold"][5])  # glint
    c.pixel(5, 4, RAMPS["gold"][4])
    return c.render()


def trash_bag():
    # 22x22: tied black garbage bag with a toxic-green tag, leaking a drop
    c = Canvas(22, 22)
    cx, cy = 10.5, 13.0
    for y in range(22):
        for x in range(22):
            dx, dy = (x - cx) / 8.2, (y - cy) / 7.2
            # pear shape: narrower at the top
            w = 1.0 - max(0.0, -dy) * 0.35
            d = math.hypot(dx / w, dy)
            if d <= 1.0 and y <= 20:
                v = shade_sphere(dx * 0.85, dy * 0.85, 0.34)
                # plastic folds
                if (x + y * 2) % 7 == 0 and 0.3 < d < 0.9:
                    v -= 0.18
                c.set(x, y, "bag", v)
    # knot + ears
    for (x, y, v) in [(9, 5, .5), (10, 5, .6), (11, 5, .5), (10, 4, .7), (9, 3, .6), (8, 2, .5),
                      (11, 3, .6), (12, 2, .55), (13, 2, .4), (10, 6, .45)]:
        c.set(x, y, "bag", v)
    # toxic tag hanging from the knot
    for (x, y) in [(12, 7), (13, 7), (12, 8), (13, 8), (14, 8), (13, 9), (14, 9), (12, 9)]:
        c.set(x, y, "slime", 0.6 if y < 9 else 0.4)
    c.pixel(13, 8, RAMPS["slime"][1])
    # slime drip on the side
    for (x, y, v) in [(4, 15, .7), (4, 16, .55), (4, 17, .45), (5, 16, .6), (3, 18, .5)]:
        c.set(x, y, "slime", v)
    # highlight
    for (x, y) in [(7, 9), (6, 10), (7, 10)]:
        c.set(x, y, "bag", 0.9)
    return c.render()


def sack():
    # 20x19: a small blue-grey plastic sack with handles
    c = Canvas(20, 19)
    for y in range(19):
        for x in range(20):
            dx, dy = (x - 9.5) / 7.0, (y - 11.5) / 6.0
            d = math.hypot(dx, dy * (0.9 if dy > 0 else 1.15))
            if d <= 1.0 and y <= 17:
                v = shade_sphere(dx * 0.8, dy * 0.8, 0.32)
                if x in (7, 12) and y > 7:
                    v -= 0.12
                c.set(x, y, "steel", v)
    for (x, y) in [(6, 4), (6, 3), (7, 2), (8, 2), (9, 3), (9, 4), (10, 4), (10, 3), (11, 2), (12, 2), (13, 3), (13, 4)]:
        c.set(x, y, "steel", 0.4)
    # recycle mark
    for (x, y) in [(9, 10), (10, 10), (8, 11), (11, 11), (8, 12), (11, 12), (9, 13), (10, 13)]:
        c.pixel(x, y, RAMPS["green"][3])
    return c.render()


def heart():
    # 14x13: glossy red heart
    c = Canvas(14, 13)
    for y in range(13):
        for x in range(14):
            u = (x - 6.5) / 5.0
            v = 1.22 - (y - 1) * 0.225
            f = (u * u + v * v - 1) ** 3 - u * u * v ** 3
            if f <= 0 and 1 <= x <= 12 and 1 <= y <= 11:
                c.set(x, y, "red", shade_sphere(u * 0.7, -(v - 0.2) * 0.7, 0.30))
    for (x, y) in [(3, 3), (4, 3), (3, 4)]:
        c.pixel(x, y, RAMPS["red"][5])
    return c.render()


def feather():
    # 32x32: a light-blue speed feather with motion streaks
    c = Canvas(32, 32)

    def spine(t):  # t 0..1 from tip (top right) to base (bottom left)
        x = 25 - 18 * t + 4 * math.sin(t * math.pi)
        y = 4 + 22 * t
        return x, y

    for i in range(400):
        t = i / 399
        sx, sy = spine(t)
        width = 5.2 * math.sin(min(1.0, t * 1.15) * math.pi) ** 0.8 if t < 0.85 else 0
        if width <= 0:
            continue
        # barbs on both sides, perpendicular to the spine
        tx, ty = spine(min(1, t + 0.01))
        ang = math.atan2(ty - sy, tx - sx) + math.pi / 2
        for k in range(-int(width * 2), int(width * 2) + 1):
            s = k / 2
            bx = sx + math.cos(ang) * s - abs(s) * 0.25
            by = sy + math.sin(ang) * s + abs(s) * 0.35
            side = 1 if s > 0 else -1
            v = 0.62 + 0.25 * (side * -0.5) - 0.25 * abs(s) / max(width, 1)
            if int(t * 40) % 7 == 0 and abs(s) > 1.5:  # notches
                continue
            c.set(int(round(bx)), int(round(by)), "feather", v)
    for i in range(200):
        t = i / 199
        sx, sy = spine(t)
        c.set(int(round(sx)), int(round(sy)), "quill", 0.75 - 0.4 * t)
    for i in range(6):  # quill end
        c.set(7 - i // 2, 27 + i // 2, "quill", 0.5)
    c = c.render()
    # motion streaks
    px = c.load()
    for (y, x0, x1) in [(10, 28, 31), (14, 27, 30), (18, 25, 29)]:
        for x in range(x0, x1):
            px[x, y] = RAMPS["feather"][4] + (200,)
    return c


def barrel():
    # 32x32: rusty steel oil barrel with a hazard band and a leak
    c = Canvas(32, 32)
    x0, x1, y0, y1 = 8, 23, 6, 28
    cx = (x0 + x1) / 2
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            nx = (x - cx) / ((x1 - x0) / 2 + 0.6)
            v = shade_sphere(nx, -0.15, 0.32)
            mat = "steel"
            if 13 <= y <= 17:
                mat = "hazard"
            if y in (y0 + 3, y1 - 3) or y in (12, 18):
                v -= 0.22  # rims
            c.set(x, y, mat, v)
    # top lid ellipse
    for x in range(x0, x1 + 1):
        for y in range(y0 - 2, y0 + 1):
            dx = (x - cx) / 8.0
            if dx * dx + ((y - (y0 - 0.5)) / 1.6) ** 2 <= 1:
                c.set(x, y, "steel", 0.75 if y < y0 else 0.6)
    c.set(18, y0 - 1, "oil", 0.2)
    c.set(19, y0 - 1, "oil", 0.2)  # bung
    # hazard stripes
    for y in range(13, 18):
        for x in range(x0, x1 + 1):
            if (x + y) % 4 in (0, 1):
                c.set(x, y, "oil", 0.25 + 0.1 * ((x - cx) < 0))
    # rust patches
    for (x, y) in [(10, 21), (11, 22), (20, 9), (21, 10), (12, 24)]:
        c.set(x, y, "wood", 0.45)
    # oil leak running down
    for (x, y, v) in [(16, 19, .3), (16, 20, .3), (16, 21, .35), (17, 22, .3), (16, 23, .4)]:
        c.set(x, y, "oil", v)
    # toxic sticker
    for (x, y) in [(13, 9), (14, 8), (15, 9), (14, 10)]:
        c.set(x, y, "slime", 0.7)
    return c.render()


def chest(open_=False):
    # 24x22: wooden eco chest with green bands
    c = Canvas(24, 22)
    for y in range(10, 21):
        for x in range(2, 22):
            v = 0.5 + (0.12 if y == 10 else 0) - (0.15 if y == 20 else 0) - 0.08 * ((x - 2) / 20)
            if y in (14, 17):
                v -= 0.2
            mat = "green" if x in (5, 6, 17, 18) else "wood"
            c.set(x, y, mat, v + (0.15 if x in (5, 17) else 0))
    if not open_:
        for y in range(3, 10):
            for x in range(2, 22):
                if (y == 3 and (x < 4 or x > 19)) or (y == 4 and (x < 3 or x > 20)):
                    continue
                v = 0.62 - 0.06 * (y - 3) - 0.06 * ((x - 2) / 20)
                if y == 4:
                    v += 0.18
                mat = "green" if x in (5, 6, 17, 18) else "wood"
                c.set(x, y, mat, v + (0.15 if x in (5, 17) else 0))
        for y in range(7, 13):  # lock
            for x in range(10, 14):
                c.set(x, y, "gold", 0.75 if (x == 10 or y == 7) else 0.5)
        c.pixel(11, 10, RAMPS["oil"][0])
        c.pixel(12, 10, RAMPS["oil"][0])
    else:
        for y in range(0, 6):
            for x in range(2, 22):
                c.set(x, y, "wood", 0.32 if y > 0 else 0.45)
        for y in range(6, 10):
            for x in range(3, 21):
                c.set(x, y, "oil", 0.15)
        for x in range(4, 20, 3):
            c.set(x, 8, "gold", 0.85)
            c.set(x + 1, 9, "gold", 0.7)
        for x in range(3, 21):
            c.set(x, 9, "slime", 0.8 if x % 2 else 0.6)
    return c.render()


ITEMS = {
    "coin.png": coin,
    "toxic_waste.png": trash_bag,
    "trash(1).png": sack,
    "Heart.png": heart,
    "Feather.png": feather,
    "pixellab-oil-barrel-1773596908433.png": barrel,
    "eco_chest.png": lambda: chest(False),
    "eco_chest_open.png": lambda: chest(True),
}

if __name__ == "__main__":
    for name, fn in ITEMS.items():
        fn().save(os.path.join(OUT, name))
    print("ok", OUT)
