"""Original pixel-art effect sheets for EcoRescuer (horizontal strips).

    python3 effects.py OUT_DIR

Writes one PNG per effect into OUT_DIR (they go to Misc/FX/ in the game):

  hit.png       24 px x 5   leaf-green impact star (a hero hits a polluter)
  hurt.png      24 px x 5   toxic splat (the hero gets hit)
  purify.png    48 px x 9   smog puff that clears into leaves (polluter defeated)
  sparkle.png   32 px x 6   white ring + twinkles, tinted in game (pickups)
  heal.png      32 px x 8   green pluses and leaves rising (healing)
  blast.png     64 px x 9   toxic barrel explosion (Kamikaze)
  splash.png    32 px x 6   sludge splash (sprayer blob landing)
  dust.png      16 px x 5   dust puff (Bruto's charge, rocks)
  stars.png     32 px x 6   stun stars circling (loops)
  leaf_bolt.png 16 px x 4 x 2 rows  magic-bow shot: row 0 leaf (heroes), row 1 toxic (Baron)
  plasma.png    16 px x 4   NEXUS turret plasma (AI DataCenter)

Everything is drawn here from circles, polygons and fixed palettes, so the
art is original. The script is seeded and gives the same result every run.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

random.seed(7)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# palettes
LEAF = [C("1d4f2a"), C("2e8a3c"), C("58bf45"), C("a5e65a"), C("e8ffb2")]
TOX = [C("2a1638"), C("5b2a6e"), C("9a43a8"), C("d07ad8")]
SLUDGE = [C("2f5410"), C("4f8a16"), C("86c51f"), C("c8f246"), C("f1ffb8")]
SMOG = [C("26242d"), C("3d3a47"), C("5a5666"), C("7d798a")]
FIRE = [C("8f2a12"), C("d2531a"), C("ff9a24"), C("ffd650"), C("fff7d0")]
DUST = [C("6e604d"), C("9c8b70"), C("c8b996"), C("e6dcc0")]
GOLD = [C("8a5a10"), C("e0a020"), C("ffe066"), C("fffbe0")]
RED = [C("5e0b1e"), C("b3182f"), C("ff4a4a"), C("ffb0a8"), C("fff4f0")]
WHITE = C("ffffff")


def strip(size, n, rows=1):
    return Image.new("RGBA", (size * n, size * rows), (0, 0, 0, 0))


def frame(size):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def disc(im, cx, cy, r, col, sy=1.0):
    """Hard-edged filled circle (or ellipse squashed by sy)."""
    if r <= 0:
        return
    px = im.load()
    w, h = im.size
    rr = r * r
    for y in range(int(cy - r * sy) - 1, int(cy + r * sy) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            dx = x + 0.5 - cx
            dy = (y + 0.5 - cy) / sy
            if dx * dx + dy * dy <= rr and 0 <= x < w and 0 <= y < h:
                px[x, y] = col


def ring(im, cx, cy, r, width, col, sy=1.0):
    px = im.load()
    w, h = im.size
    for y in range(int(cy - (r + 1) * sy) - 1, int(cy + (r + 1) * sy) + 2):
        for x in range(int(cx - r) - 2, int(cx + r) + 3):
            dx = x + 0.5 - cx
            dy = (y + 0.5 - cy) / sy
            d = math.hypot(dx, dy)
            if r - width <= d <= r and 0 <= x < w and 0 <= y < h:
                px[x, y] = col


def dot(im, x, y, col):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), col)


def star(im, cx, cy, r_out, r_in, points, rot, col):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / points
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    ImageDraw.Draw(im).polygon(pts, fill=col)


def twinkle(im, x, y, r, cols):
    """4-point twinkle: cross with a bright center."""
    x, y = int(round(x)), int(round(y))
    for i in range(-r, r + 1):
        c = cols[0] if abs(i) == r else cols[1]
        dot(im, x + i, y, c)
        dot(im, x, y + i, c)
    if r >= 2:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            dot(im, x + dx, y + dy, cols[0])
    dot(im, x, y, cols[-1])


def leaf(im, cx, cy, length, angle, pal=LEAF):
    """Small leaf: lens shape with an outline, a light side and a midrib."""
    L = length / 2.0
    W = max(1.2, length * 0.28)
    ca, sa = math.cos(angle), math.sin(angle)

    def P(u, v):
        return (cx + u * ca - v * sa, cy + u * sa + v * ca)

    outline, top = [], []
    for i in range(13):
        t = -1 + 2 * i / 12
        outline.append(P(t * L, math.sqrt(max(0, 1 - t * t)) * W))
    for i in range(12, -1, -1):
        t = -1 + 2 * i / 12
        outline.append(P(t * L, -math.sqrt(max(0, 1 - t * t)) * W))
    d = ImageDraw.Draw(im)
    d.polygon(outline, fill=pal[0])
    inner = []
    for i in range(13):
        t = -1 + 2 * i / 12
        inner.append(P(t * (L - 0.8), math.sqrt(max(0, 1 - t * t)) * (W - 0.9)))
    for i in range(12, -1, -1):
        t = -1 + 2 * i / 12
        inner.append(P(t * (L - 0.8), -math.sqrt(max(0, 1 - t * t)) * (W - 0.9)))
    d.polygon(inner, fill=pal[2])
    for i in range(7):
        t = -1 + 2 * i / 6
        top.append(P(t * (L - 1.0), -math.sqrt(max(0, 1 - t * t)) * (W - 1.0) * 0.9))
    if len(top) > 2:
        d.polygon(top + [P(L - 1.0, 0), P(-(L - 1.0), 0)], fill=pal[3])
    d.line([P(-L, 0), P(L * 0.7, 0)], fill=pal[1], width=1)


def puff(im, cx, cy, r, pal, sy=1.0):
    """Shaded round puff: dark rim bottom-right, light top-left."""
    disc(im, cx, cy, r, pal[0], sy)
    disc(im, cx - r * 0.12, cy - r * 0.12 * sy, r * 0.86, pal[1], sy)
    disc(im, cx - r * 0.3, cy - r * 0.3 * sy, r * 0.55, pal[2], sy)
    if len(pal) > 3 and r >= 4:
        disc(im, cx - r * 0.42, cy - r * 0.42 * sy, r * 0.22, pal[3], sy)


def paste(sheet, fr, i, row=0):
    s = fr.width
    sheet.alpha_composite(fr, (i * s, row * s))


# ---------------------------------------------------------------- effects

def hit():
    S, N = 24, 5
    sh = strip(S, N)
    c = S / 2
    for i in range(N):
        f = frame(S)
        rot = math.pi / 8
        if i == 0:
            star(f, c, c, 6, 2, 4, 0, LEAF[4])
            disc(f, c, c, 2.2, WHITE)
        elif i == 1:
            star(f, c, c, 11, 3.2, 4, 0, LEAF[2])
            star(f, c, c, 7, 2.5, 4, rot, LEAF[3])
            star(f, c, c, 8, 2.2, 4, 0, LEAF[4])
            disc(f, c, c, 3.2, WHITE)
        elif i == 2:
            ring(f, c, c, 8, 1.6, LEAF[3])
            star(f, c, c, 10, 1.8, 4, 0, LEAF[3])
            star(f, c, c, 5, 1.5, 4, rot, LEAF[4])
            disc(f, c, c, 1.8, WHITE)
            for k in range(4):
                a = math.pi / 4 + k * math.pi / 2
                twinkle(f, c + math.cos(a) * 9, c + math.sin(a) * 9, 1, [LEAF[2], LEAF[4]])
        elif i == 3:
            ring(f, c, c, 10, 1.2, LEAF[2])
            for k in range(4):
                a = math.pi / 4 + k * math.pi / 2
                twinkle(f, c + math.cos(a) * 10, c + math.sin(a) * 10, 1, [LEAF[2], LEAF[4]])
            for k in range(4):
                a = k * math.pi / 2
                dot(f, c + math.cos(a) * 7, c + math.sin(a) * 7, LEAF[3])
        else:
            for k in range(4):
                a = math.pi / 4 + k * math.pi / 2
                dot(f, c + math.cos(a) * 11, c + math.sin(a) * 11, LEAF[3])
                a = k * math.pi / 2
                dot(f, c + math.cos(a) * 9, c + math.sin(a) * 9, LEAF[2])
        paste(sh, f, i)
    return sh


def hurt():
    S, N = 24, 5
    sh = strip(S, N)
    c = S / 2
    drops = [(k * math.tau / 7 + random.uniform(-0.2, 0.2), random.uniform(0.8, 1.2)) for k in range(7)]
    for i in range(N):
        f = frame(S)
        if i == 0:
            disc(f, c, c, 4.5, TOX[0])
            disc(f, c, c, 3.5, TOX[2])
            disc(f, c - 1, c - 1, 1.6, SLUDGE[3])
        else:
            r_blob = [0, 7, 6, 4.5, 2.5][i]
            r_drop = [0, 7.5, 9.5, 11, 11.5][i]
            s_drop = [0, 2.4, 1.9, 1.3, 0.8][i]
            for a, m in drops:
                x = c + math.cos(a) * r_drop * m
                y = c + math.sin(a) * r_drop * m
                disc(f, x, y, s_drop + 0.6, TOX[0])
                disc(f, x, y, s_drop, TOX[2] if i < 3 else TOX[1])
                if i == 1:
                    dot(f, x - 0.5, y - 0.5, SLUDGE[3])
            if r_blob > 0:
                disc(f, c, c, r_blob + 0.8, TOX[0])
                disc(f, c, c, r_blob, TOX[1])
                disc(f, c - 0.8, c - 0.8, r_blob * 0.62, TOX[2])
                if i <= 2:
                    disc(f, c - 1.5, c - 1.5, r_blob * 0.3, SLUDGE[3])
                    disc(f, c + 1.5, c + 1, r_blob * 0.2, SLUDGE[2])
                if i >= 3:
                    disc(f, c, c, r_blob * 0.5, (0, 0, 0, 0))
        paste(sh, f, i)
    return sh


def purify():
    S, N = 48, 9
    sh = strip(S, N)
    c = S / 2
    cy = 28
    blobs = [(0, 0, 1.0), (-6, 2, 0.75), (6, 2, 0.75), (-3, -5, 0.7), (4, -4, 0.65)]
    leaves = [(-1.0, -0.6, 0.0), (1.0, -0.8, 1.7), (-0.4, -1.3, 3.4), (0.6, -1.1, 4.4), (0.0, -0.4, 2.2), (-1.2, -1.1, 5.5)]
    sparks = [(-12, -10), (11, -14), (-6, -19), (13, -3), (-14, 0), (3, -22)]
    for i in range(N):
        f = frame(S)
        if i <= 3:  # smog grows
            g = [0.45, 0.75, 0.95, 1.0][i]
            for dx, dy, s in blobs:
                puff(f, c + dx * g, cy + dy * g, 8 * s * g, SMOG)
            if i == 3:  # light breaks through
                disc(f, c, cy - 1, 4.5, LEAF[2])
                disc(f, c, cy - 1, 2.8, LEAF[4])
                for k in range(4):
                    a = k * math.pi / 2 + 0.4
                    for t in range(3, 9):
                        dot(f, c + math.cos(a) * t, cy - 1 + math.sin(a) * t, LEAF[3])
        elif i == 4:  # burst
            for dx, dy, s in blobs:
                puff(f, c + dx * 1.7, cy + dy * 1.7, 6 * s, SMOG[1:])
            star(f, c, cy - 1, 15, 3.5, 4, 0, LEAF[3])
            star(f, c, cy - 1, 9, 3, 4, math.pi / 4, LEAF[4])
            disc(f, c, cy - 1, 4, WHITE)
        else:  # leaves fly up, smog thins out
            k = i - 5  # 0..3
            for dx, dy, s in blobs[:5 - k]:
                r = 5 * s * (1 - k * 0.25)
                if r >= 1.5:
                    puff(f, c + dx * (2.0 + k * 0.4), cy + dy * 2.0 - k * 2, r, SMOG[2:] + [SMOG[3]])
            ring(f, c, cy - 1, 11 + k * 3, 1.2, LEAF[2] if k < 2 else LEAF[1], sy=0.6)
            for j, (vx, vy, a0) in enumerate(leaves):
                t = (k + 1) / 4.0
                x = c + vx * 14 * t + math.sin(a0 + k * 1.3) * 2
                y = cy - 2 + vy * 22 * t + 6 * t * t
                if k == 3 and j % 2 == 0:
                    continue
                leaf(f, x, y, 7 if j % 3 else 8, a0 + k * 0.7)
            for j, (sx, sy_) in enumerate(sparks):
                if (j + k) % 2 == 0:
                    twinkle(f, c + sx, cy + sy_ - k * 2, 2 if k < 2 else 1, [LEAF[3], WHITE])
        paste(sh, f, i)
    return sh


def sparkle():
    S, N = 32, 6
    sh = strip(S, N)
    c = S / 2
    W1, W2 = C("ffffff"), C("c8c8c8")
    pts = [(-9, -6), (8, -9), (10, 6), (-7, 9)]
    for i in range(N):
        f = frame(S)
        r = [4, 7, 10, 12, 14, 15][i]
        if i < 5:
            ring(f, c, c, r, 2 if i < 3 else 1, W2 if i > 2 else W1)
        if i == 0:
            disc(f, c, c, 3, W1)
        if i == 1:
            twinkle(f, c, c, 4, [W2, W1])
        for j, (x, y) in enumerate(pts):
            life = i - j * 0.5
            if 0 <= life < 4:
                rr = [1, 3, 2, 1][int(life)]
                twinkle(f, c + x * (0.8 + i * 0.08), c + y * (0.8 + i * 0.08) - i, rr, [W2, W1])
        paste(sh, f, i)
    return sh


def heal():
    S, N = 32, 8
    sh = strip(S, N)
    c = S / 2

    def plus(f, x, y, s, cols):
        x, y = int(round(x)), int(round(y))
        for i in range(-s, s + 1):
            for w in (0, 1) if s > 1 else (0,):
                dot(f, x + i, y + w, cols[0])
                dot(f, x + w, y + i, cols[0])
        for i in range(-s + 1, s):
            dot(f, x + i, y, cols[1])
            dot(f, x, y + i, cols[1])
        dot(f, x, y, cols[2])

    items = [(-8, 0.0, "p"), (7, 0.25, "l"), (-2, 0.5, "p"), (9, 0.6, "p"), (-9, 0.75, "l"), (2, 0.15, "l")]
    for i in range(N):
        f = frame(S)
        k = i / (N - 1)
        # ground ring of light
        if i < 6:
            ring(f, c, 26, 8 + i * 1.5, 1.4, LEAF[3] if i < 3 else LEAF[2], sy=0.4)
        for x, ph, kind in items:
            t = (k * 1.25 - ph)
            if 0 <= t <= 1:
                y = 27 - t * 22
                xx = c + x + math.sin(t * 6 + x) * 1.5
                if kind == "p":
                    plus(f, xx, y, 2 if t < 0.75 else 1, [LEAF[1], LEAF[3], LEAF[4]])
                else:
                    leaf(f, xx, y, 6, t * 4 + x)
        paste(sh, f, i)
    return sh


def blast():
    S, N = 64, 9
    sh = strip(S, N)
    c = S / 2
    cy = 34
    cloud = [(0, 0, 1.0), (-9, 3, 0.75), (9, 3, 0.75), (-6, -7, 0.7), (6, -7, 0.7), (0, -11, 0.6), (-12, -3, 0.55), (12, -3, 0.55)]
    drops = [(k * math.tau / 9 + 0.3, random.uniform(0.85, 1.15)) for k in range(9)]
    for i in range(N):
        f = frame(S)
        if i == 0:
            disc(f, c, cy, 9, FIRE[3])
            disc(f, c, cy, 6, FIRE[4])
            disc(f, c, cy, 3, WHITE)
        elif i <= 2:
            r = [0, 15, 19][i]
            ring(f, c, cy, r + 8, 2, FIRE[4] if i == 1 else FIRE[3], sy=0.75)
            disc(f, c, cy, r, FIRE[1])
            disc(f, c - 1, cy - 2, r * 0.8, FIRE[2])
            disc(f, c - 2, cy - 3, r * 0.5, FIRE[3])
            disc(f, c - 2, cy - 4, r * 0.25, FIRE[4])
            if i == 2:
                for dx, dy, s in cloud[1:5]:
                    puff(f, c + dx * 1.4, cy + dy * 1.2 + 4, 6 * s, SLUDGE)
        else:
            k = i - 3  # 0..5
            g = 1.0 + k * 0.12
            rise = k * 2.5
            pal = SLUDGE if k < 2 else ([SLUDGE[0], SLUDGE[1], SLUDGE[2], SLUDGE[3]] if k < 4 else [SMOG[1], SLUDGE[0], SLUDGE[1], SLUDGE[2]])
            for j, (dx, dy, s) in enumerate(cloud):
                r = 9 * s * (1.0 - max(0, k - 2) * 0.2)
                if r < 2:
                    continue
                if k >= 4 and j % 2 == 1:
                    continue
                puff(f, c + dx * g * 1.15, cy + dy * g - rise, r, pal)
            if k < 2:  # fire core fading
                disc(f, c, cy - 2 - rise, 7 - k * 3, FIRE[2])
                disc(f, c - 1, cy - 3 - rise, 4 - k * 2, FIRE[3])
            if k < 3:
                ring(f, c, cy + 6, 26 + k * 3, 1.3, SLUDGE[3] if k == 0 else SLUDGE[2], sy=0.5)
            # flying sludge droplets
            if k < 5:
                for a, m in drops:
                    rr = (18 + k * 5) * m
                    x = c + math.cos(a) * rr
                    y = cy + math.sin(a) * rr * 0.7 + k * k * 0.8
                    disc(f, x, y, 2.0 - k * 0.3, SLUDGE[0])
                    disc(f, x - 0.4, y - 0.4, 1.4 - k * 0.25, SLUDGE[3])
        paste(sh, f, i)
    return sh


def splash():
    S, N = 32, 6
    sh = strip(S, N)
    c = S / 2
    gy = 22
    drops = [(-1.0, 1.0), (-0.55, 1.35), (0.0, 1.5), (0.55, 1.35), (1.0, 1.0), (-0.8, 0.6), (0.8, 0.6)]
    for i in range(N):
        f = frame(S)
        # puddle on the ground
        pr = [5, 8, 10, 11, 11, 10][i]
        disc(f, c, gy, pr + 1, SLUDGE[0], sy=0.45)
        disc(f, c, gy, pr, SLUDGE[1], sy=0.45)
        disc(f, c - 1.5, gy - 0.5, pr * 0.55, SLUDGE[2], sy=0.45)
        if i < 4:
            disc(f, c - 2.5, gy - 1, pr * 0.2, SLUDGE[4], sy=0.45)
        if i == 0:
            disc(f, c, gy - 2, 3.5, SLUDGE[0])
            disc(f, c, gy - 2, 2.5, SLUDGE[2])
        if 1 <= i <= 4:
            t = i / 4.0
            for vx, vy in drops:
                x = c + vx * 12 * t
                y = gy - vy * 16 * t + 20 * t * t
                s = 1.8 if i < 3 else 1.2
                disc(f, x, y, s + 0.6, SLUDGE[0])
                disc(f, x, y, s, SLUDGE[3])
        if i in (1, 2):  # crown
            for k in range(-3, 4):
                x = c + k * 2.2
                h = 5 - abs(k) + (2 if i == 1 else 0)
                for yy in range(int(h)):
                    dot(f, x, gy - 1 - yy, SLUDGE[2] if yy < h - 1 else SLUDGE[4])
        paste(sh, f, i)
    return sh


def dust():
    S, N = 16, 5
    sh = strip(S, N)
    c = S / 2
    for i in range(N):
        f = frame(S)
        if i == 0:
            puff(f, c, 10, 3, DUST)
        elif i == 1:
            puff(f, c - 2, 10, 4, DUST)
            puff(f, c + 3, 11, 3, DUST)
        elif i == 2:
            puff(f, c - 3, 9, 4, DUST[1:])
            puff(f, c + 3, 9, 3.5, DUST[1:])
            puff(f, c, 7, 3, DUST[1:])
        elif i == 3:
            puff(f, c - 4, 8, 2.5, DUST[2:] + [DUST[3]])
            puff(f, c + 4, 7, 2.5, DUST[2:] + [DUST[3]])
            puff(f, c, 5, 2, DUST[2:] + [DUST[3]])
        else:
            for x, y in ((c - 5, 7), (c + 5, 6), (c, 3), (c - 2, 5)):
                dot(f, x, y, DUST[2])
        paste(sh, f, i)
    return sh


def stars():
    S, N = 32, 6
    sh = strip(S, N)
    c = S / 2
    cy = 18

    def small_star(f, x, y, r, cols):
        star(f, x, y, r, r * 0.45, 5, -math.pi / 2, cols[0])
        star(f, x, y - 0.3, r * 0.65, r * 0.3, 5, -math.pi / 2, cols[1])
        dot(f, x - 0.5, y - 0.8, cols[2])

    for i in range(N):
        f = frame(S)
        ring(f, c, cy, 11, 1, (255, 255, 255, 70), sy=0.38)
        items = []
        for k in range(3):
            a = i / N * math.tau + k * math.tau / 3
            x = c + math.cos(a) * 11
            y = cy + math.sin(a) * 4.2
            items.append((math.sin(a), x, y))
        for depth, x, y in sorted(items):
            if depth < 0:
                small_star(f, x, y, 3.0, [GOLD[0], GOLD[1], GOLD[2]])
            else:
                small_star(f, x, y, 4.2, [GOLD[1], GOLD[2], GOLD[3]])
        paste(sh, f, i)
    return sh


def leaf_bolt():
    S, N = 16, 4
    sh = strip(S, N, rows=2)
    for row, (glow, pal, spark) in enumerate([
            ((88, 191, 69, 110), LEAF, LEAF[4]),
            ((154, 67, 168, 120), [TOX[0], TOX[1], TOX[2], TOX[3], C("f4c8f6")], SLUDGE[3])]):
        for i in range(N):
            f = frame(S)
            # glow and trail (pointing right)
            disc(f, 9, 8, 5.5, glow, sy=0.7)
            for k, x in enumerate((5, 3, 1)):
                if (i + k) % 2 == 0:
                    dot(f, x, 8 + ((i + k) % 3 - 1), pal[3])
                else:
                    dot(f, x, 8, pal[2])
            leaf(f, 9.5, 8, 9, 0.0, pal)
            # sparkle at the tip, pulsing
            twinkle(f, 13, 8, 1 + (i % 2), [pal[3], spark])
            sh.alpha_composite(f, (i * S, row * S))
    return sh


def plasma():
    S, N = 16, 4
    sh = strip(S, N)
    c = S / 2
    for i in range(N):
        f = frame(S)
        r = [5.5, 6.2, 5.8, 6.6][i]
        disc(f, c, c, r + 1, (255, 74, 74, 90))
        disc(f, c, c, r, RED[1])
        disc(f, c, c, r - 1.4, RED[2])
        disc(f, c - 0.5, c - 0.5, r - 3.0, RED[3])
        disc(f, c - 0.8, c - 0.8, 1.4, RED[4])
        # crackle
        for k in range(3):
            a = i * 1.1 + k * math.tau / 3
            dot(f, c + math.cos(a) * (r + 1.3), c + math.sin(a) * (r + 1.3), RED[3])
        paste(sh, f, i)
    return sh


EFFECTS = {
    "hit": hit, "hurt": hurt, "purify": purify, "sparkle": sparkle, "heal": heal,
    "blast": blast, "splash": splash, "dust": dust, "stars": stars,
    "leaf_bolt": leaf_bolt, "plasma": plasma,
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "fx_out"
    os.makedirs(out, exist_ok=True)
    for name, fn in EFFECTS.items():
        img = fn()
        img.save(os.path.join(out, name + ".png"))
        print(name, img.size)
