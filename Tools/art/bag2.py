import os
import math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit
from pixelkit import Canvas, RAMPS
from PIL import Image
GAME_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) + "/"  # the EcoRescuer project
RAMPS["plastic"] = [(16, 16, 28), (28, 30, 48), (42, 48, 72), (66, 76, 106), (112, 126, 160), (206, 216, 236)]
RAMPS["tie"] = [(20, 60, 36), (34, 104, 52), (62, 156, 66), (120, 206, 84), (190, 240, 140), (240, 255, 210)]

def bag():
    c = Canvas(22, 22)
    cx = 10.5
    top, bottom = 7, 20
    # body: gathered at the neck, full and round at the bottom
    prof = {7: 2.4, 8: 4.0, 9: 5.2, 10: 6.0, 11: 6.6, 12: 7.0, 13: 7.3, 14: 7.5, 15: 7.6,
            16: 7.6, 17: 7.4, 18: 7.0, 19: 6.2, 20: 4.8}
    for y in range(top, bottom + 1):
        half = prof[y]
        for x in range(22):
            dx = (x + 0.5 - (cx + 0.5)) / half
            if abs(dx) <= 1.0:
                ny = (y - 14.5) / 7.0
                v = pixelkit.shade_sphere(max(-0.95, min(0.95, dx * 0.92)), max(-0.95, min(0.95, ny * 0.9)), 0.34)
                c.set(x, y, "plastic", v)
    # two soft folds curving down from the neck
    for side in (-1, 1):
        for i, y in enumerate(range(9, 16)):
            x = int(round(cx + side * (1.2 + i * 0.75)))
            if c.has(x, y):
                c.set(x, y, "plastic", c.val[y][x] - 0.24)
            hx = x - side  # lit edge beside the fold
            if c.has(hx, y) and i < 5:
                c.set(hx, y, "plastic", c.val[y][hx] + 0.14)
    # neck + green drawstring
    for y, half in ((5, 1.4), (6, 1.9), (7, 2.4)):
        for x in range(22):
            if abs(x - cx) <= half:
                c.set(x, y, "plastic", 0.5 - 0.07 * (x - cx))
    for x in range(9, 13):
        c.set(x, 6, "tie", 0.78 if x < 11 else 0.55)
    # knotted ears, two pixels thick
    for (x, y, v) in [(9, 4, .55), (8, 3, .6), (7, 2, .62), (6, 1, .5), (8, 4, .45), (7, 3, .5), (6, 2, .45),
                      (12, 4, .5), (13, 3, .5), (14, 2, .45), (15, 1, .38), (13, 4, .4), (14, 3, .42), (15, 2, .35)]:
        c.set(x, y, "plastic", v)
    c.pixel(7, 1, RAMPS["plastic"][4])
    # one curved gloss streak on the lit side
    for (x, y, i) in [(7, 9, 4), (6, 10, 5), (5, 11, 5), (5, 12, 4), (4, 13, 4), (4, 14, 3), (8, 9, 3)]:
        c.pixel(x, y, RAMPS["plastic"][i])
    # recycle tag hanging from the drawstring
    c.pixel(13, 7, RAMPS["tie"][3])
    for (x, y) in [(14, 8), (15, 8), (16, 8), (14, 9), (15, 9), (16, 9), (15, 10)]:
        c.set(x, y, "tie", 0.65 if y == 8 else 0.45)
    c.pixel(15, 9, RAMPS["tie"][5])
    return c.render()


im = bag()
im.save("out/toxic_waste.png")
old = Image.open(GAME_ROOT + "Collectibles/Assets/Sprites/toxic_waste.png").convert("RGBA")
S = 10
prev = Image.new("RGBA", (22 * S * 3 + 40, 22 * S + 20), (58, 74, 66, 255))
for i, img in enumerate([old, im]):
    big = img.resize((22 * S, 22 * S), Image.NEAREST)
    prev.paste(big, (10 + i * (22 * S + 10), 10), big)
# also at real size on sand and grass
for j, bg in enumerate([(214, 196, 150), (92, 150, 70)]):
    tile = Image.new("RGBA", (40, 40), bg + (255,))
    tile.paste(im, (9, 9), im)
    tile = tile.resize((tile.width * 3, tile.height * 3), Image.NEAREST)
    prev.paste(tile, (10 + 2 * (22 * S + 10), 10 + j * 105), tile)
prev.save("bag_preview.png")
print("ok")
