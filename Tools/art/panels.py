"""Story panels 04_baron and 07_fall with the new suit and the Baron portrait."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import math, random
GAME_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) + "/"  # the EcoRescuer project
W, H = 1152, 648
EC = GAME_ROOT


def arena(dark=0.5, tint=(60, 30, 90, 90)):
    bg = Image.open('pv_arena.png').convert('RGBA')
    bg = bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST).crop((96, 0, 96 + W, H))
    bg = ImageEnhance.Brightness(bg).enhance(dark)
    return Image.alpha_composite(bg, Image.new('RGBA', (W, H), tint))


def radial(img, cx, cy, r, col, amax):
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    g = glow.load()
    for y in range(max(0, int(cy - r)), min(H, int(cy + r))):
        for x in range(max(0, int(cx - r)), min(W, int(cx + r))):
            d = math.hypot(x - cx, (y - cy) * 1.2) / r
            if d < 1:
                g[x, y] = col + (int((1 - d) ** 2 * amax),)
    return Image.alpha_composite(img, glow)


def shadow(img, box, a=120):
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(box, fill=(0, 0, 0, a))
    return Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(6)))


def finish(img, vy=0.4):
    v = Image.new('L', (W, H), 0)
    vp = v.load()
    for y in range(H):
        for x in range(W):
            dd = math.hypot((x - W / 2) / (W / 2), (y - H * vy) / (H / 2))
            vp[x, y] = int(max(0, min(1, (dd - 0.6) / 0.6)) * 190)
    img = Image.composite(Image.new('RGBA', (W, H), (6, 4, 12, 255)), img, v)
    return ImageEnhance.Contrast(img.convert('RGB')).enhance(1.06)


def frame(col, row, k=4):
    return Image.open('boss3_sheet.png').crop((col * 128, row * 128, col * 128 + 128, row * 128 + 128)).resize((128 * k, 128 * k), Image.NEAREST)


def baron_panel():
    dy = 34
    img = arena()
    sx, sy = 840, -30 + dy
    img = radial(img, sx, sy + 150, 360, (90, 255, 140), 130)
    img = radial(img, 330, 260 + dy, 300, (255, 200, 130), 120)
    img = shadow(img, (sx - 150, sy + 468, sx + 150, sy + 512))
    img.alpha_composite(frame(0, 0), (sx - 256, sy))
    bust = Image.open('baron_portrait.png')
    k = 2.7
    bust = bust.resize((int(bust.width * k), int(bust.height * k)), Image.NEAREST)
    bx, by = 320 - bust.width // 2, 8 + dy
    halo = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    a = bust.getchannel('A').filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(8))
    halo.paste(Image.new('RGBA', bust.size, (10, 6, 16, 160)), (bx, by), a)
    img = Image.alpha_composite(img, halo)
    img.alpha_composite(bust, (bx, by))
    return finish(img)


def fall_panel():
    rnd = random.Random(7)
    img = arena(0.42, (90, 40, 30, 80))
    sx, sy = 640, -50
    img = radial(img, sx, sy + 300, 380, (255, 150, 60), 120)   # fire glow
    img = shadow(img, (sx - 170, sy + 470, sx + 170, sy + 516), 140)
    img.alpha_composite(frame(3, 4), (sx - 256, sy))
    # smoke columns
    sm = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sm)
    for i in range(26):
        x = sx + rnd.randint(-90, 90) + i * 2
        y = sy + 220 - i * 9 + rnd.randint(-10, 10)
        r = 18 + i * 2
        d.ellipse((x - r, y - r, x + r, y + r), fill=(40, 36, 44, 70))
    img = Image.alpha_composite(img, sm.filter(ImageFilter.GaussianBlur(5)))
    # sparks and embers
    px = img.load()
    for _ in range(260):
        x, y = rnd.randint(0, W - 3), rnd.randint(0, 460)
        c = rnd.choice([(255, 220, 120), (255, 150, 60), (255, 250, 200)])
        for dx in range(2):
            for dy in range(2):
                px[x + dx, y + dy] = c + (255,)
    # the Barone, backlit, running away into the night
    run = Image.open(EC + 'Boss/Baron/Sprites/baron_RangerRun.png').crop((0, 64, 64, 128))
    run = run.resize((64 * 4, 64 * 4), Image.NEAREST)
    sil = Image.new('RGBA', run.size, (14, 10, 18, 255))
    sil.putalpha(run.getchannel('A'))
    rim = Image.new('RGBA', run.size, (255, 170, 90, 255))
    rim.putalpha(run.getchannel('A').filter(ImageFilter.MaxFilter(3)))
    img.alpha_composite(rim, (110, 150))
    img.alpha_composite(sil, (112, 150))
    return finish(img, 0.45)


if __name__ == "__main__":
    baron_panel().save('04_baron_new.png')
    fall_panel().save('07_fall_new.png')
    print("ok")
