"""Original sprite sheets for the new enemies (volume-shaded, see vol.py).

Humanoid sheets: rows = down, up, side (facing right; flip for left), death.
Columns = idle x2, walk x4, windup, attack.  Drone: one row of 8
(hover x4, windup x2, hit, -) plus a death row.
usage: enemies.py OUT_DIR  ->  sprayer.png, brute.png, bomber.png, drone.png"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vol import Canvas, ellipsoid, capsule, rbox, poly, ramp, hexc
from PIL import Image

DIRS = ("down", "up", "side")


def pal(**kw):
    return {k: ramp(hexc(v)) for k, v in kw.items()}


def legs(c, cx, base, phase, side, mat, boot, w=3.0, gap=3.5, h=8):
    """Two legs; `phase` 0..1 walk cycle (None = standing)."""
    for i, s in enumerate((-1, 1)):
        lift = 0
        fwd = 0
        if phase is not None:
            a = phase * math.tau + (0 if i == 0 else math.pi)
            lift = max(0.0, math.sin(a)) * 2
            fwd = math.cos(a) * 2.5
        if side:
            x = cx + fwd * (1 if i else -1) * 0.8
            z = 1 + i * 0.1
        else:
            x = cx + s * gap
            z = 1
        c.add(capsule(mat, z, x, base - h, x, base - 2 - lift, w))
        c.add(rbox(boot, z + 0.05, x - w - 0.5, base - 3 - lift, x + w + (1.5 if side else 0.5), base - lift, rad=1.2))


# ------------------------------------------------------------------ sprayer

def sprayer(d, phase=None, bob=0, wind=False, attack=False):
    S = 40
    c = Canvas(S, S, pal(suit="#e2c234", tank="#58a83c", mask="#5a5e66", lens="#9cf06a",
                         dark="#2a2c32", hose="#3a3c44", glove="#3a3c44", spray="#8ce04a"))
    cx, base = 20, 37
    side = d == "side"
    legs(c, cx, base, phase, side, "suit", "dark", w=2.8)
    ty = base - 18 + bob
    if d == "down" or side:  # tank behind the body
        c.add(rbox("tank", 0.5, cx - 6 - (3 if side else 0), ty - 1, cx + 6 - (3 if side else 0), ty + 10, rad=4))
    c.add(rbox("suit", 2, cx - 6, ty, cx + 6, ty + 11, rad=4))           # hazmat body
    for x in range(cx - 5, cx + 6):
        c.dot(x, ty + 8, "suit", 1)                                      # belt crease
    if d == "up":
        c.add(rbox("tank", 3, cx - 5, ty, cx + 5, ty + 10, rad=3))
        c.add(ellipsoid("tank", 3.1, cx, ty - 1, 4, 1.8))
        for x in range(cx - 4, cx + 5):
            c.dot(x, ty + 4, "dark", 2)
    # head: hood + gas mask
    hy = ty - 5 + bob * 0.5
    c.add(ellipsoid("suit", 3, cx, hy, 6, 6))
    if d == "down":
        c.add(ellipsoid("mask", 3.5, cx, hy + 1, 4.5, 4))
        for s in (-1, 1):
            c.add(ellipsoid("lens", 3.6, cx + s * 2.2, hy, 1.6, 1.6, depth=0.5))
        c.add(ellipsoid("dark", 3.7, cx, hy + 3.5, 2, 1.6))                 # filter
    elif side:
        c.add(ellipsoid("mask", 3.5, cx + 3, hy + 1, 3, 3.5))
        c.add(ellipsoid("lens", 3.6, cx + 3.5, hy, 1.4, 1.5, depth=0.5))
        c.add(ellipsoid("dark", 3.7, cx + 5.5, hy + 3, 1.8, 1.6))
    # arms + nozzle
    aim = 6 if (wind or attack) else 3
    if d == "down":
        c.add(capsule("suit", 4, cx - 6, ty + 2, cx - 4, ty + 8, 2.2))
        c.add(capsule("suit", 4, cx + 6, ty + 2, cx + 3, ty + 8, 2.2))
        c.add(rbox("hose", 4.5, cx - 1, ty + 7, cx + 2, ty + 7 + aim, rad=1))
        tip = (cx + 0.5, ty + 8 + aim)
    elif side:
        c.add(capsule("suit", 4, cx, ty + 2, cx + 4, ty + 7, 2.2))
        c.add(rbox("hose", 4.5, cx + 3, ty + 5, cx + 5 + aim, ty + 7, rad=1))
        tip = (cx + 6 + aim, ty + 6)
    else:
        c.add(capsule("suit", 1.5, cx - 6, ty + 2, cx - 6, ty + 8, 2.2))
        c.add(capsule("suit", 1.5, cx + 6, ty + 2, cx + 6, ty + 8, 2.2))
        tip = None
    if attack and tip:
        for k in range(3):
            c.dot(tip[0] + (k if side else 0), tip[1] + (0 if side else k), "spray", 5 - k)
    if wind and tip:
        c.dot(tip[0], tip[1], "spray", 5)
    return c.render()


# ------------------------------------------------------------------ bomber

def bomber(d, phase=None, bob=0, wind=False, attack=False):
    S = 40
    c = Canvas(S, S, pal(hood="#5e3e62", skin="#c89a7a", barrel="#4c8e3a", band="#e2b830",
                         dark="#26222c", eye="#ffd860", fuse="#ff6a30", goo="#9ae05a"))
    cx, base = 20, 37
    side = d == "side"
    legs(c, cx, base, phase, side, "dark", "dark", w=2.4, gap=3, h=6)
    ty = base - 15 + bob
    c.add(rbox("hood", 2, cx - 5, ty, cx + 5, ty + 9, rad=3))
    hy = ty - 4
    c.add(ellipsoid("hood", 3, cx, hy, 5.5, 5))
    c.add(poly("hood", 3.05, [(cx - 2, hy - 4), (cx + 2, hy - 4), (cx + (5 if side else 0), hy - 9)], depth=0.5))  # floppy hood tip
    if d == "down":
        c.add(ellipsoid("dark", 3.3, cx, hy + 1, 3.5, 3, depth=0.4))   # shadowed face
        for s in (-1, 1):
            c.dot(cx + s * 1.5, hy + 1, "eye", 5)
    elif side:
        c.add(ellipsoid("dark", 3.3, cx + 3, hy + 1, 2.2, 2.6, depth=0.4))
        c.dot(cx + 4, hy + 1, "eye", 5)
    # the barrel, held in front (down/side) or on the back (up)
    if d == "up":
        bx, by, bz = cx, ty + 1, 4
    elif side:
        bx, by, bz = cx + 5, ty + 2, 4
    else:
        bx, by, bz = cx, ty + 3, 4
    c.add(rbox("barrel", bz, bx - 4.5, by, bx + 4.5, by + 9, rad=2.5))
    for x in range(int(bx - 4), int(bx + 5)):
        c.dot(x, by + 3, "band", 4)
        c.dot(x, by + 6, "band", 3)
    c.add(ellipsoid("barrel", bz + 0.1, bx, by, 4.5, 1.6))
    c.dot(bx - 2, by + 9, "goo", 4)                                    # leak
    c.dot(bx - 2, by + 10, "goo", 3)
    # fuse on top: sparks when lit
    c.dot(bx + 1, by - 1, "dark", 2)
    c.dot(bx + 2, by - 2, "dark", 2)
    if wind or attack:
        for (dx, dy) in ((3, -3), (2, -4), (4, -4), (3, -5)):
            c.dot(bx + dx, by + dy, "fuse" if (dx + dy) % 2 else "eye", 5)
    if d != "up":   # little hands around the barrel
        for s in (-1, 1):
            c.add(ellipsoid("skin", bz + 0.2, bx + s * 4.5, by + 4, 1.4, 1.4))
    return c.render()


# ------------------------------------------------------------------ brute

def brute(d, phase=None, bob=0, wind=False, attack=False):
    """Hulking, hunched polluter: rust-orange hazard armor, a sludge tank with a
    smoking stack on its back, a black respirator with red eyes and huge
    mechanical fists hanging low."""
    S = 56
    c = Canvas(S, S, pal(suit="#4a4e64", armor="#c8682a", stripe="#f0cc34", tank="#4e8a3a", metal="#9aa2ae",
                         mask="#26242a", eye="#ff3a2a", dark="#1c1a20", smoke="#8a8a90", goo="#9ae04a"))
    cx, base = 28, 53
    side = d == "side"
    lean = 4 if attack else (2 if wind else 0)
    # short, thick legs with boots
    legs(c, cx, base, phase, side, "suit", "dark", w=4.6, gap=6.5, h=10)
    ty = base - 30 + bob + lean          # top of the shoulders
    bx = cx + (lean if side else 0)
    # sludge tank + smoke stack on the back (behind the body unless seen from behind)
    tz = 4.5 if d == "up" else 0.8
    tx = bx - (6 if side else 0)
    c.add(rbox("tank", tz, tx - 9, ty - 4, tx + 9, ty + 12, rad=5))
    for x in range(int(tx - 8), int(tx + 9)):
        c.dot(x, ty + 1, "dark", 2)
        c.dot(x, ty + 7, "dark", 2)
    c.add(capsule("metal", tz + 0.1, tx + 6, ty - 2, tx + 6, ty - 7, 1.8))      # stack
    puff = 3 if wind else 1
    for k in range(puff):
        c.dot(tx + 5 + (k % 2), ty - 12 - k * 2, "smoke", 4)
        c.dot(tx + 6, ty - 13 - k * 2, "smoke", 3)
    if d == "up":
        c.add(capsule("goo", 4.6, tx - 4, ty + 10, tx - 4, ty + 13, 1.0))      # leak
    # massive hunched torso: dark suit with rust armor plates + hazard stripes
    c.add(rbox("suit", 2, bx - 13, ty, bx + 13, ty + 20, rad=8))
    if d != "up":
        c.add(poly("armor", 2.5, [(bx - 12, ty + 2), (bx + 12, ty + 2), (bx + 9, ty + 15), (bx - 9, ty + 15)], depth=0.9))
        for x in range(bx - 9, bx + 10):
            if (x // 2) % 2 == 0:
                c.dot(x, ty + 12, "stripe", 4)
                c.dot(x, ty + 13, "dark", 2)
    # huge shoulder plates
    for s_ in (-1, 1):
        if side and s_ < 0:
            continue
        sx = bx + s_ * (13 if not side else 3)
        c.add(ellipsoid("armor", 3.4, sx, ty + 2, 7, 5.5))
        for k in range(-5, 6):
            c.dot(sx + k, ty + 5 - abs(k) // 3, "stripe", 3)
        # long arms ending in big mechanical fists near the ground
        swing = 0 if phase is None else math.sin(phase * math.tau + (0 if s_ < 0 else math.pi)) * 2.5
        fx = sx + s_ * (2 if not side else 0) + (5 + lean * 2 if side else 0)
        fy = base - 9 + swing - (6 if attack and side else 0)
        c.add(capsule("suit", 3.2, sx, ty + 4, fx, fy - 5, 3.6))
        c.add(rbox("metal", 3.6, fx - 6, fy - 5, fx + 6, fy + 5, rad=3))        # gauntlet
        for x in range(int(fx - 4), int(fx + 5), 2):
            c.dot(x, fy - 3, "dark", 1)                                       # knuckle plates
    # small head sunk between the shoulders: respirator, red eyes
    hy = ty - 1
    hx = bx + (4 if side else 0)
    if d == "up":
        c.add(ellipsoid("suit", 4.2, hx, hy - 1, 6, 5))
        c.add(capsule("dark", 4.3, hx - 4, hy - 1, hx + 4, hy - 1, 1.0))   # mask strap
    else:
        c.add(ellipsoid("mask", 4.2, hx, hy, 7, 6.5))
        c.add(rbox("armor", 4.25, hx - 6, hy - 6, hx + 6, hy - 3, rad=1.5, depth=0.6))   # helmet brow
        if side:
            c.add(ellipsoid("metal", 4.4, hx + 4, hy + 2, 2.6, 2.6))       # filter
            for (ex, ey) in ((2, -1), (3, -1), (3, 0)):
                c.dot(hx + ex, hy + ey, "eye", 5)
        else:
            for s_ in (-1, 1):
                for (ex, ey) in ((2, -1), (3, -1), (2, 0), (3, 0)):
                    c.dot(hx + s_ * ex, hy + ey, "eye", 5 if ey < 0 else 4)
            c.add(ellipsoid("metal", 4.4, hx, hy + 3, 3, 2.4))            # filter
            c.dot(hx, hy + 3, "dark", 1)
    if wind:   # red-hot eyes while winding up
        for (x, y) in ((hx - 4, hy - 3), (hx + 4, hy - 3)):
            c.dot(x, y, "eye", 3)
    return c.render()


# ------------------------------------------------------------------ drone

def drone(bob=0.0, rot=0, glow=0.0, hit=False, fall=0.0, tilt=0.0):
    S = 32
    c = Canvas(S, S, pal(body="#4a505c", rim="#8a94a2", eye="#ff3a3a", rotor="#c8d0d8", dark="#1e2026", spark="#ffd060"))
    cx = 16
    cy = 15 + bob + fall * 10
    c.add(ellipsoid("body", 2, cx, cy, 9, 5.5))
    c.add(ellipsoid("rim", 2.2, cx, cy - 1.5, 7.5, 3, depth=0.6))
    c.add(ellipsoid("dark", 2.4, cx, cy + 1.5, 4.5, 3, depth=0.5))
    r = 2.2 + glow * 1.3
    c.add(ellipsoid("eye", 2.6, cx, cy + 1.5, r, r * 0.9, depth=0.6))
    for s in (-1, 1):  # rotor arms
        ax = cx + s * 10
        c.add(capsule("body", 1.5, cx + s * 6, cy - 2, ax, cy - 4 + tilt * s, 1.2))
        if fall < 0.5:
            w = 5 if (rot + (0 if s < 0 else 1)) % 2 == 0 else 3
            for x in range(-w, w + 1):
                c.dot(ax + x, cy - 5 + tilt * s, "rotor", 4 if abs(x) < w else 2)
    im = c.render()
    if glow > 0 or hit:
        px = im.load()
        for y in range(S):
            for x in range(S):
                d = math.hypot(x - cx, y - (cy + 1.5))
                if d < 6 and px[x, y][3] == 0 and glow > 0:
                    px[x, y] = (255, 70, 60, int(90 * glow * (1 - d / 6)))
    return im


# ------------------------------------------------------------------ sheets

def death_frames(fn, n=4):
    """Fall over and fade: rotate the standing 'down' frame."""
    base = fn("down")
    out = []
    for i in range(n):
        im = base.rotate(-25 * (i + 1), resample=Image.NEAREST, center=(base.width / 2, base.height * 0.9))
        a = im.getchannel("A").point(lambda v: int(v * (1 - i * 0.22)))
        im.putalpha(a)
        out.append(im)
    return out


def humanoid_sheet(fn, size):
    rows = []
    for d in DIRS:
        row = [fn(d, None, 0), fn(d, None, -1)]
        row += [fn(d, i / 4, -abs(math.sin(i * math.pi / 2))) for i in range(4)]
        row += [fn(d, None, 0, wind=True), fn(d, None, 0, attack=True)]
        rows.append(row)
    rows.append(death_frames(fn) + [Image.new("RGBA", (size, size))] * 4)
    sheet = Image.new("RGBA", (size * 8, size * 4), (0, 0, 0, 0))
    for j, r in enumerate(rows):
        for i, im in enumerate(r):
            sheet.paste(im, (i * size, j * size), im)
    return sheet


def drone_sheet():
    row = [drone(bob=b, rot=i) for i, b in enumerate((0, -1, -1, 0))]
    row += [drone(glow=0.6, rot=0), drone(glow=1.0, rot=1), drone(hit=True, tilt=2), Image.new("RGBA", (32, 32))]
    death = [drone(fall=f, tilt=3 + i * 2, rot=i) for i, f in enumerate((0.2, 0.5, 0.8, 1.0))]
    sheet = Image.new("RGBA", (32 * 8, 64), (0, 0, 0, 0))
    for i, im in enumerate(row):
        sheet.paste(im, (i * 32, 0), im)
    for i, im in enumerate(death):
        im.putalpha(im.getchannel("A").point(lambda v, i=i: int(v * (1 - i * 0.2))))
        sheet.paste(im, (i * 32, 32), im)
    return sheet


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "enemies"
    os.makedirs(out, exist_ok=True)
    humanoid_sheet(sprayer, 40).save(os.path.join(out, "sprayer.png"))
    humanoid_sheet(bomber, 40).save(os.path.join(out, "bomber.png"))
    humanoid_sheet(brute, 56).save(os.path.join(out, "brute.png"))
    drone_sheet().save(os.path.join(out, "drone.png"))
    print("ok")
