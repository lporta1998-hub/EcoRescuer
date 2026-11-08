"""Bust portrait of the Barone dei Rifiuti for the story panel (original art)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vol import Canvas, ellipsoid, capsule, rbox, poly, ramp, hexc

W, H = 150, 170


def portrait():
    pal = {
        "skin": ramp(hexc("#e6b28e"), spread=0.45), "suit": ramp(hexc("#2c2836")), "satin": ramp(hexc("#4a4258")),
        "shirt": ramp(hexc("#eeeae2")), "tie": ramp(hexc("#b02a34")), "gold": ramp(hexc("#e2b040")),
        "hat": ramp(hexc("#24202a")), "band": ramp(hexc("#9a1e2a")), "hair": ramp(hexc("#d8d4cc"), spread=0.4),
        "brow": ramp(hexc("#9a948c")), "glass": ramp(hexc("#bfe6f0")), "eye": ramp(hexc("#2a2430")),
        "mouth": ramp(hexc("#7a2a2a")), "teeth": ramp(hexc("#f4f0e6")), "cheek": ramp(hexc("#e89a8a"), spread=0.4),
    }
    c = Canvas(W, H, pal)
    cx = 75
    # ---- jacket + shoulders ------------------------------------------------
    c.add(rbox("suit", 1, 14, 118, 136, 172, rad=22))
    c.add(poly("shirt", 1.5, [(cx - 16, 112), (cx + 16, 112), (cx + 9, 170), (cx - 9, 170)], depth=0.6))
    for side in (-1, 1):   # satin lapels
        c.add(poly("satin", 2, [(cx + side * 14, 112), (cx + side * 30, 124), (cx + side * 22, 150), (cx + side * 10, 170), (cx + side * 8, 140)], depth=0.8))
    c.add(poly("tie", 2.5, [(cx - 7, 116), (cx + 7, 116), (cx + 4, 124), (cx + 9, 150), (cx, 160), (cx - 9, 150), (cx - 4, 124)], depth=0.8))
    c.add(ellipsoid("gold", 3, cx, 133, 3, 3))          # tie pin
    for i in range(14):                                   # watch chain
        t = i / 13
        c.dot(cx + 22 + t * 26, 150 + math.sin(t * math.pi) * 8, "gold", 4 if i % 2 else 5)
    c.add(ellipsoid("gold", 2.6, cx - 36, 136, 5, 5))    # gold "$" brooch
    for (x, y) in ((cx - 37, 133), (cx - 36, 134), (cx - 37, 136), (cx - 35, 137), (cx - 36, 138), (cx - 36, 132), (cx - 36, 139)):
        c.dot(x, y, "gold", 1)
    # ---- neck + head -------------------------------------------------------
    c.add(capsule("skin", 2.8, cx, 100, cx, 116, 13))
    c.add(ellipsoid("skin", 3, cx, 82, 29, 31))
    for side in (-1, 1):
        c.add(ellipsoid("skin", 3.05, cx + side * 21, 98, 11, 10))   # jowls
        c.add(ellipsoid("skin", 2.9, cx + side * 29, 80, 5, 8))     # ears
        c.add(ellipsoid("hair", 3.1, cx + side * 27, 70, 6, 11))    # grey side hair
    c.add(ellipsoid("cheek", 3.2, cx - 16, 92, 6, 4, depth=0.4))
    c.add(ellipsoid("cheek", 3.2, cx + 16, 92, 6, 4, depth=0.4))
    c.add(ellipsoid("skin", 3.6, cx, 88, 7, 8))                     # nose
    c.add(ellipsoid("cheek", 3.65, cx, 91, 4, 3.5, depth=0.5))
    # smug grin under the moustache
    c.add(poly("mouth", 3.4, [(cx - 12, 103), (cx + 17, 98), (cx + 13, 104), (cx - 8, 106)], depth=0.4))
    c.add(poly("teeth", 3.45, [(cx - 8, 103), (cx + 14, 99), (cx + 12, 101), (cx - 6, 104)], depth=0.3))
    # curled moustache
    for side in (-1, 1):
        c.add(capsule("hair", 3.8, cx + side * 3, 96, cx + side * 17, 98, 4.2))
        c.add(capsule("hair", 3.85, cx + side * 17, 98, cx + side * 25, 92, 3.0))
        c.add(capsule("hair", 3.9, cx + side * 25, 92, cx + side * 24, 86, 2.0))
    # eyes: half-closed, villain brows
    for side in (-1, 1):
        ex = cx + side * 12
        c.add(ellipsoid("shirt", 3.3, ex, 77, 6, 3.4, depth=0.4))
        c.add(ellipsoid("eye", 3.35, ex + side * -1, 78, 2.6, 2.6, depth=0.4))
        c.dot(ex - 1, 77, "shirt", 5)
        c.add(poly("skin", 3.4, [(ex - 7, 72), (ex + 7, 72), (ex + 7, 76), (ex - 7, 76)], depth=0.5))   # heavy lids
        c.add(poly("brow", 3.5, [(ex - side * 9, 71), (ex + side * 9, 65), (ex + side * 9, 69), (ex - side * 9, 75)], depth=0.7))
    # monocle on his left eye + chain
    mx, my = cx + 12, 77
    for a in range(0, 360, 4):
        for r in (8.0, 9.0):
            c.dot(mx + r * math.cos(math.radians(a)), my + r * 0.95 * math.sin(math.radians(a)), "gold", 5 if 190 < a < 330 else (2 if r > 8.5 else 3))
    c.dot(mx - 3, my - 4, "glass", 5)
    c.dot(mx - 2, my - 5, "glass", 5)
    for i in range(16):
        c.dot(mx + 8 + i * 0.6, my + 6 + i * 3.2, "gold", 4 if i % 2 else 2)
    # ---- top hat -------------------------------------------------------------
    c.add(ellipsoid("hat", 4, cx, 56, 40, 8))                      # brim
    c.add(rbox("hat", 4.2, cx - 25, 4, cx + 25, 54, rad=5))
    c.add(rbox("band", 4.3, cx - 25, 40, cx + 25, 49, rad=2, depth=0.6))
    c.add(rbox("gold", 4.4, cx + 9, 40, cx + 17, 49, rad=1, depth=0.5))  # buckle
    c.add(rbox("hat", 4.45, cx + 11, 42, cx + 15, 47, rad=0.5, depth=0.3))
    return c.render()


if __name__ == "__main__":
    im = portrait()
    im.save(sys.argv[1] if len(sys.argv) > 1 else "baron_portrait.png")
    im.resize((W * 3, H * 3), 0).save("baron_portrait_3x.png")
    print("ok")
