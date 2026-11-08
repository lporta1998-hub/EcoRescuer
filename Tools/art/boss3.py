"""MECCA-RIFIUTI v3: the Barone's sleek armored battle suit (original design).
Gunmetal armor, silver plates, gold trim, a green reactor and V-visor, swept
back fins, jet boots and an arm cannon. Same sheet layout as before:
row0 idle x4, row1 walk x4, row2 windup x2 + charge x2, row3 throw x4,
row4 hurt + broken x3, row5 empty (open) x2 + boot x2."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vol import Canvas, ellipsoid, capsule, rbox, poly, ramp, hexc
from PIL import Image, ImageFilter

S = 128
PAL = {
    "arm": ramp(hexc("#3a404c")), "plate": ramp(hexc("#c08e3a"), spread=0.7), "gold": ramp(hexc("#c8d0d8")),
    "dark": ramp(hexc("#22262e")), "glow": ramp(hexc("#58f07a")), "fire": ramp(hexc("#ffb040")),
    "red": ramp(hexc("#e04a3a")), "smoke": ramp(hexc("#7a7a80")), "inner": ramp(hexc("#2e3440")),
}
GLOW = (110, 255, 140)


def metal_tex(x, y, v):
    return v + (0.06 if (x + y * 3) % 13 == 0 else 0)


def suit(bob=0.0, step=0.0, arm_swing=0.0, lean=0.0, crouch=0.0, cannon=0.0, flash=0.0, flames=0.0,
         open_=0.0, power=1.0, damage=0, sparks=0, kneel=0.0, tilt=0.0, seed=0):
    """open_: 0 closed .. 1 fully open (empty). power: glow strength 0..1."""
    c = Canvas(S, S, dict(PAL))
    for m in ("arm", "plate", "inner"):
        c.textures[m] = metal_tex
    glows = []    # (x, y, r) emissive spots for the halo
    cx = 64 + tilt * 3
    base = 121
    crouch += kneel * 10
    hip_y = base - 50 + crouch + bob
    # ---- back fins (swept wings behind the shoulders) -------------------
    sh_y = hip_y - 36 + lean * 4
    for side in (-1, 1):
        fx = cx + side * 20
        c.add(poly("dark", 0.5, [(fx, sh_y + 4), (fx + side * 22, sh_y - 14), (fx + side * 25, sh_y - 11), (fx + side * 9, sh_y + 12)]))
        c.add(poly("plate", 0.6, [(fx + side * 19, sh_y - 12), (fx + side * 25, sh_y - 11), (fx + side * 22, sh_y - 7)], depth=0.5))
        if flames > 0:  # back thrusters
            for k in range(int(4 + flames * 8)):
                c.dot(fx + side * (6 + k * 0.4), sh_y + 14 + k, "fire", 5 if k < 3 else 4)
            glows.append((fx + side * 8, sh_y + 18, 5 * flames))
    # ---- legs ------------------------------------------------------------
    for side in (-1, 1):
        ph = step + (0 if side < 0 else math.pi)
        lift = max(0.0, math.sin(ph)) * 5
        fwd = math.cos(ph) * 3
        hx, hy = cx + side * 11, hip_y + 4
        kx, ky = cx + side * (13 + kneel * 4), hip_y + 25 - lift * 0.5 + kneel * 2
        ax, ay = cx + side * 13 + fwd * 0.3, base - 8 - lift
        if kneel > 0.5 and side < 0:   # one knee on the ground
            kx, ky = cx - 16, base - 6
            ax, ay = cx - 26, base - 4
        c.add(capsule("arm", 1, hx, hy, kx, ky, 6.5))
        if ky - 4 > hy + 4:
            c.add(rbox("plate", 1.4, min(hx, kx) - 5, hy + 1, max(hx, kx) + 5, ky - 4, rad=3, depth=0.8))  # thigh plate
        c.add(capsule("arm", 1.2, kx, ky, ax, ay, 5.5))
        if ay - 4 > ky + 5:
            c.add(rbox("inner", 1.5, kx - 4, ky + 2, kx + 4, ay - 4, rad=3, depth=0.7))                 # shin guard
            for yy in range(int(ky + 4), int(ay - 4), 3):
                c.dot(kx, yy, "plate", 4)
        c.add(ellipsoid("plate", 1.8, kx, ky, 4.5, 4))                                                  # knee
        # jet boot
        c.add(rbox("dark", 2, ax - 8, ay - 2, ax + 8, ay + 7, rad=3))
        c.add(rbox("arm", 2.2, ax - 7, ay - 4, ax + 7, ay + 2, rad=2, depth=0.6))
        for x in range(int(ax - 5), int(ax + 6), 2):
            c.dot(x, ay + 6, "glow", 5 if power > 0.3 else 1)
        if power > 0.3:
            glows.append((ax, ay + 8, 3 * power))
        if flames > 0:
            for k in range(int(3 + flames * 9)):
                w = max(1, int((1 - k / (3 + flames * 9)) * 6))
                for dx in range(-w, w + 1):
                    c.dot(ax + dx, ay + 8 + k, "fire", 5 if abs(dx) < w / 2 else 3)
            glows.append((ax, ay + 12, 7 * flames))
    # ---- pelvis + abdomen -----------------------------------------------
    c.add(rbox("arm", 2.5, cx - 15, hip_y - 6, cx + 15, hip_y + 8, rad=4))
    c.add(poly("plate", 2.7, [(cx - 6, hip_y - 4), (cx + 6, hip_y - 4), (cx, hip_y + 7)], depth=0.5))
    if power > 0.3:
        c.dot(cx, hip_y - 1, "glow", 5)
    ty = hip_y - 38 + lean * 5
    for i in range(3):  # abdomen segments
        c.add(rbox("inner" if i % 2 else "arm", 2.6 + i * 0.01, cx - 12 + i, ty + 26 + i * 4, cx + 12 - i, ty + 30 + i * 4, rad=2, depth=0.6))
    # ---- torso -----------------------------------------------------------
    c.add(poly("arm", 3, [(cx - 21, ty + 1), (cx + 21, ty + 1), (cx + 18, ty + 14), (cx + 11, ty + 30), (cx - 11, ty + 30), (cx - 18, ty + 14)], depth=1.0))
    if open_ < 0.05:
        # chest plates with gold trim and the reactor
        for side in (-1, 1):
            c.add(poly("plate", 3.4, [(cx + side * 3, ty + 4), (cx + side * 19, ty + 3), (cx + side * 16, ty + 15), (cx + side * 5, ty + 21)], depth=0.9))
            for k in range(12):
                c.dot(cx + side * (6 + k), ty + 3 + (k // 6), "gold", 5)
            c.add(poly("plate", 3.45, [(cx + side * 4, ty + 23), (cx + side * 10, ty + 22), (cx + side * 8, ty + 29), (cx + side * 3, ty + 29)], depth=0.6))
        c.add(ellipsoid("dark", 3.6, cx, ty + 15, 6, 6, depth=0.5))
        r = 3.6 * (0.6 + 0.4 * power)
        c.add(ellipsoid("glow", 3.7, cx, ty + 15, r, r, depth=0.6))
        if power > 0.2:
            for (dx, dy) in ((0, 0), (-1, -1), (1, -1)):
                c.dot(cx + dx, ty + 15 + dy, "glow", 5)
            glows.append((cx, ty + 15, 9 * power))
    else:
        # open: chest plates swung out, dark cockpit inside
        c.add(rbox("inner", 3.3, cx - 13, ty + 4, cx + 13, ty + 26, rad=4, depth=0.4))
        c.add(rbox("dark", 3.35, cx - 10, ty + 7, cx + 10, ty + 24, rad=4, depth=0.3))
        for side in (-1, 1):
            o = open_ * 14
            c.add(poly("plate", 3.8, [(cx + side * (12 + o), ty + 3 - o * 0.3), (cx + side * (26 + o * 0.5), ty + 1),
                                       (cx + side * (24 + o * 0.5), ty + 17), (cx + side * (14 + o), ty + 21 - o * 0.2)], depth=0.9))
        if power > 0.2:
            c.dot(cx, ty + 15, "glow", 3)
    # ---- shoulders + arms ------------------------------------------------
    for side in (-1, 1):
        sx, sy = cx + side * 24, ty + 6
        swing = arm_swing * (1 if side < 0 else -1)
        if side > 0 and cannon > 0:   # the cannon arm comes up, pointing at you
            ex, ey = sx + 6, sy + 14 - cannon * 4
            wx, wy = ex - 4 - cannon * 4, ey + 10 - cannon * 4
        else:
            ex, ey = sx + side * 4, sy + 18 + swing * 2
            wx, wy = ex + side * 1 + swing * 3, ey + 17
            if kneel > 0.5 and side > 0:
                wx, wy = ex + 6, ey + 12
        c.add(capsule("arm", 2.8 if side < 0 else 4.4, sx, sy, ex, ey, 5))
        c.add(capsule("plate", 2.9 if side < 0 else 4.5, ex, ey, wx, wy, 5.5))
        c.add(ellipsoid("dark", 3.0 if side < 0 else 4.6, ex, ey, 4, 4))
        if side > 0:
            # arm cannon on the forearm: barrel + green muzzle
            c.add(rbox("dark", 4.7, wx - 5, wy - 6, wx + 5, wy + 4, rad=2))
            if cannon >= 0.5:   # muzzle facing the camera: a glowing ring
                c.add(ellipsoid("dark", 4.9, wx, wy, 5.5, 5.5, depth=0.6))
                c.add(ellipsoid("glow", 5.0, wx, wy, 3.2, 3.2, depth=0.6))
                glows.append((wx, wy, 5))
            else:
                c.add(ellipsoid("glow" if power > 0.3 else "dark", 4.8, wx, wy + 5, 3, 2.2, depth=0.5))
                if power > 0.3:
                    glows.append((wx, wy + 5, 3 * power))
            if flash > 0:
                mx, my = wx, wy
                for k in range(int(6 * flash)):
                    for a in range(0, 360, 45):
                        c.dot(mx + math.cos(math.radians(a)) * k, my + math.sin(math.radians(a)) * k * 0.8, "glow", 5)
                glows.append((mx, my, 12 * flash))
        else:
            c.add(ellipsoid("arm", 3.1, wx, wy + 4, 5, 5))  # fist
        # angular shoulder plates with a silver edge
        zz = 5 if side > 0 else 3.2
        c.add(poly("plate", zz, [(sx - side * 8, sy - 6), (sx + side * 6, sy - 8), (sx + side * 11, sy - 1),
                                 (sx + side * 9, sy + 7), (sx - side * 4, sy + 5)], depth=1.0))
        for k in range(12):
            c.dot(sx + side * (-6 + k), sy - 7 + (k // 5), "gold", 5)
    # ---- helmet -----------------------------------------------------------
    hy = ty - 10 + lean * 6
    hxc = cx + tilt * 2
    c.add(capsule("dark", 3.1, hxc, ty + 2, hxc, ty - 2, 5))                 # neck
    c.add(ellipsoid("arm", 3.9, hxc, hy, 8.5, 10))                         # helmet shell
    c.add(poly("plate", 4.05, [(hxc - 2, hy - 10), (hxc + 2, hy - 10), (hxc + 1, hy - 3), (hxc - 1, hy - 3)], depth=0.6))  # crest ridge
    for side in (-1, 1):  # swept "ear" fins
        c.add(poly("gold", 4.0, [(hxc + side * 7, hy - 2), (hxc + side * 12, hy - 8), (hxc + side * 9, hy + 3)], depth=0.5))
    face_y = hy + 2 - open_ * 16
    c.add(poly("plate", 4.2 + (1 if open_ > 0 else 0), [(hxc - 8, face_y - 6), (hxc + 8, face_y - 6), (hxc + 7, face_y + 4),
                                                         (hxc + 2, face_y + 9), (hxc - 2, face_y + 9), (hxc - 7, face_y + 4)], depth=0.9))
    # V-shaped visor
    if power > 0.15:
        col = "red" if damage >= 2 else "glow"
        for k in range(7):
            c.dot(hxc - 7 + k, face_y - 2 + k // 2, col, 5)
            c.dot(hxc + 7 - k, face_y - 2 + k // 2, col, 5)
        glows.append((hxc, face_y + 1, 6 * power))
    else:
        for k in range(7):
            c.dot(hxc - 7 + k, face_y - 2 + k // 2, "dark", 1)
            c.dot(hxc + 7 - k, face_y - 2 + k // 2, "dark", 1)
    for k in range(-3, 4):   # mouth grille
        c.dot(hxc + k, face_y + 6, "arm", 1)
    if open_ > 0.5:
        c.add(ellipsoid("dark", 4.15, hxc, hy + 2, 6, 6, depth=0.3))      # empty helmet
    # ---- damage ------------------------------------------------------------
    import random
    rnd = random.Random(seed)
    for _ in range(damage * 6):
        x, y = rnd.randint(int(cx) - 20, int(cx) + 20), rnd.randint(int(ty), int(hip_y + 20))
        c.dot(x, y, "dark", 0)
        c.dot(x + 1, y, "dark", 1)
    im = c.render()
    px = im.load()
    for _ in range(sparks):
        x, y = rnd.randint(int(cx) - 26, int(cx) + 26), rnd.randint(int(ty - 10), int(hip_y + 10))
        for d in range(rnd.randint(2, 4)):
            for (dx, dy) in ((d, 0), (-d, 0), (0, d), (0, -d)):
                if 0 <= x + dx < S and 0 <= y + dy < S:
                    px[x + dx, y + dy] = (255, 240, 140, 255) if d < 2 else (255, 170, 60, 255)
    # glow halo (soft, translucent, behind nothing: added on top with low alpha)
    if glows:
        halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        hp = halo.load()
        for (gx, gy, r) in glows:
            if r <= 0:
                continue
            for y in range(int(gy - r * 2), int(gy + r * 2) + 1):
                for x in range(int(gx - r * 2), int(gx + r * 2) + 1):
                    if 0 <= x < S and 0 <= y < S:
                        d = math.hypot(x - gx, y - gy) / (r * 2)
                        if d < 1:
                            a = int((1 - d) ** 2 * 120)
                            old = hp[x, y]
                            col = (255, 190, 90) if (gx, gy, r) in [g for g in glows if False] else GLOW
                            hp[x, y] = col + (min(200, old[3] + a),)
        im = Image.alpha_composite(im, halo)
    return im


def smoke(im, n, seed):
    import random
    rnd = random.Random(seed)
    px = im.load()
    for _ in range(n):
        x, y, r = rnd.randint(40, 88), rnd.randint(14, 60), rnd.randint(3, 6)
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                if 0 <= xx < S and 0 <= yy < S and math.hypot(xx - x, yy - y) <= r:
                    o = px[xx, yy]
                    a = 150
                    px[xx, yy] = tuple(int(o[i] * (1 - a / 255) + 90 * a / 255) for i in range(3)) + (max(o[3], 150),)
    return im


def frames():
    rows = []
    rows.append([suit(bob=b, seed=i, power=0.85 + 0.15 * (i % 2)) for i, b in enumerate((0, -1, -1.5, -0.5))])
    rows.append([suit(step=i * math.pi / 2, bob=-abs(math.sin(i * math.pi / 2)) * 1.5, arm_swing=math.sin(i * math.pi / 2) * 2.5)
                 for i in range(4)])
    rows.append([suit(crouch=4, lean=1, flames=0.35), suit(crouch=6, lean=1.5, flames=0.6),
                 suit(lean=2.5, flames=1.0, arm_swing=-3), suit(lean=2.5, flames=1.0, arm_swing=-3, bob=-1)])
    rows.append([suit(cannon=0.5), suit(cannon=1.0), suit(cannon=1.0, flash=1.0), suit(cannon=0.6, flash=0.3)])
    rows.append([suit(tilt=-1.5, sparks=6, damage=1),
                 smoke(suit(kneel=0.3, damage=2, sparks=5, power=0.6, seed=2), 3, 1),
                 smoke(suit(kneel=1.0, damage=3, sparks=3, power=0.2, seed=3), 4, 2),
                 smoke(suit(kneel=1.0, damage=3, sparks=0, power=0.0, seed=4), 5, 3)])
    rows.append([suit(open_=1.0, power=0.0, kneel=0.25), suit(open_=1.0, power=0.1, kneel=0.25),
                 suit(open_=0.45, power=0.4, kneel=0.1), suit(open_=0.0, power=1.0)])
    return rows


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "boss3_sheet.png"
    rows = frames()
    sheet = Image.new("RGBA", (S * 4, S * 6), (0, 0, 0, 0))
    for j, r in enumerate(rows):
        for i, im in enumerate(r):
            sheet.paste(im, (i * S, j * S), im)
    sheet.save(out)
    bg = Image.new("RGBA", sheet.size, (70, 62, 72, 255))
    bg.alpha_composite(sheet)
    bg.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save("boss3_preview.png")
    print("ok")
