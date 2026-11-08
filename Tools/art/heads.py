"""New heads (4 directions) for the redesigned characters, volume-shaded.
Each head image is 32x36; the chin (anchor) is at (16, 31)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vol import Canvas, ellipsoid, capsule, rbox, poly, ramp, hexc

W, Hh = 32, 36
AX, AY = 16, 31  # chin anchor


def pal(d):
    out = {}
    for k, v in d.items():
        out[k] = ramp(hexc(v), spread=0.45 if k == "skin" else 0.62)
    if "skin" in out:
        s = out["skin"]
        out["skin"] = [s[1], s[2], s[3], s[3], s[4], s[5]]
    return out


def hair_tex(x, y, v):
    return v + math.sin((x * 1.3 + y * 0.5) * 1.2) * 0.15 + math.sin((x * 0.5 - y * 0.25) * 2.4) * 0.05


def bark_tex(x, y, v):
    return v + math.sin(x * 2.2 + math.sin(y * 0.7) * 1.5) * 0.14


# --- Mira ---------------------------------------------------------------------

def mira(d):
    c = Canvas(W, Hh, pal({"skin": "#f4c8a8", "hair": "#7a3ec0", "eye": "#3a6ad0", "white": "#f0f4f8",
                           "metal": "#8a94a8", "glass": "#9ae8ff", "lip": "#d0606a"}))
    c.textures["hair"] = hair_tex
    hx, hy = 16, 20
    if d == "up":
        c.add(ellipsoid("hair", 2, hx, hy - 2, 10.5, 10))
        c.add(poly("hair", 2.5, [(6, 18), (26, 18), (27, 35), (16, 33), (5, 35)]))
        c.add(rbox("metal", 3, 7, 9, 25, 11, rad=1))  # goggle strap
        return c
    side = d in ("left", "right")
    s = 1 if d == "right" else -1
    fx = hx + (1 * s if side else 0)
    c.add(ellipsoid("skin", 2, fx, hy + 1, 8.6 if not side else 7.8, 9.0, depth=0.55))
    c.add(ellipsoid("hair", 3, hx - (2 * s if side else 0), hy - 4, 10.5, 8.5))
    cap = c.parts[-1]
    cap.h = {k: v for k, v in cap.h.items() if k[1] <= hy - 1}
    if not side:
        c.add(poly("hair", 3.2, [(6, 14), (12, 12), (9, 22), (6, 33), (4, 26)]))     # long locks
        c.add(poly("hair", 3.2, [(26, 14), (20, 12), (23, 22), (26, 33), (28, 26)]))
        c.add(poly("hair", 3.4, [(9, 12), (19, 11), (13, 18)]))                         # swept bangs
        c.add(poly("hair", 3.4, [(16, 11), (24, 13), (22, 18)]))
    else:
        bx = hx - 6 * s
        c.add(poly("hair", 2.8, [(bx - 3, 12), (bx + 3, 12), (bx + 4 * -s, 34), (bx - 5 * s, 30)]))
        c.add(poly("hair", 3.4, [(hx - 4 * s, 11), (hx + 7 * s, 13), (hx + 2 * s, 18)]))
    # goggles resting on the head
    gy = 11
    for gx in ((11, 21) if not side else ((hx + 3 * s,))):
        c.add(ellipsoid("glass", 4, gx, gy, 3.0, 2.4, depth=0.5))
        c.add(ellipsoid("metal", 3.9, gx, gy, 3.6, 3.0, depth=0.3))
    # face
    ey = hy + 1
    eyes = (12, 19) if not side else ((fx + 3 * s,),)[0]
    for ex in ((12, 19) if not side else (fx + 3 * s - (1 if s < 0 else 0),)):
        c.dot(ex - 1, ey - 1, "hair", 0)
        c.dot(ex, ey - 1, "hair", 0)
        c.dot(ex + 1, ey - 1, "hair", 0)
        c.dot(ex + 2, ey - 2, "hair", 0)  # lash
        c.dot(ex, ey, "white", 5)
        c.dot(ex + 1, ey, "eye", 3)
        c.dot(ex, ey + 1, "eye", 2)
        c.dot(ex + 1, ey + 1, "eye", 1)
        c.dot(ex, ey + 2, "skin", 1)
    mx = fx + (2 * s if side else 0)
    c.dot(mx, ey + 6, "lip", 3)
    c.dot(mx + (1 if not side else s), ey + 6, "lip", 2)
    if not side:
        c.dot(10, ey + 4, "lip", 4)
        c.dot(22, ey + 4, "lip", 4)
    return c


# --- ECO-9 --------------------------------------------------------------------

def eco9(d):
    c = Canvas(W, Hh, pal({"steel": "#a8b4c4", "dark": "#3a4252", "visor": "#28d0f0", "red": "#ff4a3a", "white": "#ffffff"}))
    side = d in ("left", "right")
    s = 1 if d == "right" else -1
    c.add(rbox("steel", 2, 7, 10, 25, 31, rad=5))                 # helmet
    c.add(rbox("dark", 2.5, 9, 25, 23, 31, rad=2))                # jaw plate
    c.add(capsule("steel", 1, 16, 10, 16 + (3 * s if side else 0), 2, 1.2))   # antenna
    c.add(ellipsoid("red", 1.5, 16 + (3 * s if side else 0), 2, 2.0, 2.0))
    if d == "up":
        c.add(rbox("dark", 3, 10, 14, 22, 22, rad=2))             # back vent
        for y in range(15, 22, 2):
            for x in range(11, 22):
                c.dot(x, y, "dark", 0)
        return c
    if not side:
        c.add(rbox("visor", 3, 8, 16, 24, 21, rad=2, depth=0.5))
        for x in range(9, 24):
            c.dot(x, 17, "visor", 5)
        c.add(ellipsoid("dark", 2.6, 6.5, 20, 2.2, 3.0))         # ear bolts
        c.add(ellipsoid("dark", 2.6, 25.5, 20, 2.2, 3.0))
        for x in range(11, 22, 2):
            c.dot(x, 28, "steel", 1)                               # grille
    else:
        vx0 = 16 if s > 0 else 7
        c.add(rbox("visor", 3, vx0, 16, vx0 + 9, 21, rad=2, depth=0.5))
        c.add(ellipsoid("dark", 2.6, 16 - 5 * s, 20, 2.4, 3.0))
        for x in range(vx0 + 1, vx0 + 9):
            c.dot(x, 17, "visor", 5)
    return c


# --- Silvano ------------------------------------------------------------------

def silvano(d):
    c = Canvas(W, Hh, pal({"bark": "#7a5a3a", "moss": "#4a9a3a", "eye": "#9aff6a", "leaf": "#5ac048", "wood": "#5a3e24"}))
    c.textures["bark"] = bark_tex
    side = d in ("left", "right")
    s = 1 if d == "right" else -1
    # antlers
    for sd in ((-1, 1) if not side else (-s,)):
        base_x = 16 + sd * 6
        pts = [(base_x, 13), (base_x + sd * 4, 7), (base_x + sd * 6, 2)]
        c.add(capsule("wood", 1, base_x, 13, base_x + sd * 4, 6, 1.4))
        c.add(capsule("wood", 1, base_x + sd * 4, 6, base_x + sd * 9, 2, 1.1))
        c.add(capsule("wood", 1, base_x + sd * 3, 8, base_x + sd * 1, 1, 1.0))
        for (lx, ly) in ((base_x + sd * 9, 1), (base_x + sd * 1, 0), (base_x + sd * 7, 6)):
            c.add(ellipsoid("leaf", 1.5, lx, ly, 2.2, 1.6))
    # long carved wooden mask
    c.add(rbox("bark", 2, 9 if not side else 10, 9, 23 if not side else 22 + s, 30, rad=5))
    if d == "up":
        c.add(poly("moss", 3, [(9, 16), (23, 16), (21, 32), (16, 34), (11, 32)]))
        return c
    c.add(poly("moss", 3, [(10, 24), (22, 24), (20, 34), (16, 36), (12, 34)]))   # moss beard
    if not side:
        for ex in (12, 19):
            c.add(rbox("wood", 3.5, ex - 1, 16, ex + 2, 18, rad=1, depth=0.3))
            c.dot(ex, 17, "eye", 5)
            c.dot(ex + 1, 17, "eye", 4)
        for y in range(19, 24):
            c.dot(16, y, "bark", 1)
    else:
        ex = 16 + 3 * s
        c.add(rbox("wood", 3.5, ex - 1, 16, ex + 2, 18, rad=1, depth=0.3))
        c.dot(ex + (1 if s > 0 else 0), 17, "eye", 5)
    return c


# --- Barone -------------------------------------------------------------------

def baron(d):
    c = Canvas(W, Hh, pal({"skin": "#eab896", "hat": "#1e1a24", "band": "#b02a30", "stache": "#f0ece4",
                           "gold": "#f0c040", "eye": "#2a2430", "hair": "#c8c4bc"}))
    side = d in ("left", "right")
    s = 1 if d == "right" else -1
    fx = 16 + (s if side else 0)
    c.add(ellipsoid("skin", 2, fx, 21, 8.2, 8.8, depth=0.55))
    c.add(ellipsoid("hair", 1.8, 16 - (3 * s if side else 0), 20, 9.2, 6.5))      # grey hair at the back
    # top hat
    c.add(rbox("hat", 4, 9, 0, 23, 12, rad=1.5))
    c.add(rbox("band", 4.2, 9, 9, 23, 11, rad=0.5, depth=0.4))
    c.add(ellipsoid("hat", 4.4, 16, 13, 13, 2.2, depth=0.5))
    if d == "up":
        return c
    if not side:
        for ex in (12, 19):
            c.dot(ex, 20, "eye", 1)
            c.dot(ex + 1, 20, "eye", 0)
            c.dot(ex - 1, 18, "hair", 1)
            c.dot(ex, 18, "hair", 1)
            c.dot(ex + 1, 18, "hair", 1)
        c.add(ellipsoid("gold", 3.5, 20, 20, 2.6, 2.6, depth=0.3))           # monocle
        c.dot(20, 20, "eye", 0)
        c.add(poly("stache", 3.8, [(7, 23), (12, 22), (16, 24), (20, 22), (25, 23), (27, 20), (22, 26), (16, 25), (10, 26), (5, 20)]))
        c.dot(16, 27, "eye", 2)
    else:
        ex = fx + 4 * s
        c.dot(ex, 20, "eye", 0)
        if s > 0:
            c.add(ellipsoid("gold", 3.5, ex, 20, 2.4, 2.4, depth=0.3))
            c.dot(ex, 20, "eye", 0)
        c.add(poly("stache", 3.8, [(fx + 2 * s, 23), (fx + 9 * s, 21), (fx + 11 * s, 18), (fx + 8 * s, 25), (fx + 3 * s, 25)]))
    return c


HEADS = {"mira": mira, "eco9": eco9, "silvano": silvano, "baron": baron}


def render_all(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    imgs = {}
    for name, fn in HEADS.items():
        for d in ("down", "up", "left", "right"):
            im = fn(d).render()
            im.save(os.path.join(out_dir, f"{name}_{d}.png"))
            imgs[(name, d)] = im
    return imgs


if __name__ == "__main__":
    render_all(sys.argv[1])
    print("ok")
