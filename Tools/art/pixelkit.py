"""Tiny pixel-art toolkit: shapes are drawn as (material, shade) per pixel,
then rendered through hand-picked color ramps with a colored outline.
Light comes from the top-left, like the restyled characters."""
from PIL import Image
import math

# Shared EcoRescuer palette: ramps go dark -> light, hue-shifted
# (shadows lean blue/purple, highlights lean yellow).
RAMPS = {
    "green":  [(20, 52, 46), (28, 92, 62), (46, 140, 70), (98, 190, 76), (176, 230, 104), (236, 252, 178)],
    "gold":   [(74, 40, 30), (140, 78, 36), (204, 130, 40), (240, 186, 60), (255, 226, 120), (255, 250, 210)],
    "red":    [(56, 18, 40), (122, 28, 52), (194, 44, 58), (238, 88, 78), (255, 150, 128), (255, 226, 214)],
    "bag":    [(18, 18, 30), (34, 36, 54), (54, 60, 82), (82, 92, 116), (124, 138, 160), (180, 196, 210)],
    "slime":  [(26, 64, 30), (52, 122, 28), (112, 186, 32), (178, 232, 60), (226, 255, 132), (248, 255, 220)],
    "steel":  [(30, 38, 58), (56, 72, 96), (94, 116, 140), (140, 164, 184), (196, 214, 226), (240, 248, 252)],
    "hazard": [(70, 36, 24), (150, 84, 22), (222, 150, 30), (252, 204, 60), (255, 236, 140), (255, 252, 224)],
    "oil":    [(10, 8, 18), (24, 20, 36), (42, 36, 58), (70, 60, 92), (110, 96, 140), (170, 150, 200)],
    "wood":   [(48, 26, 26), (92, 50, 34), (140, 82, 46), (186, 120, 64), (222, 166, 100), (246, 214, 160)],
    "feather":[(40, 46, 86), (64, 92, 148), (96, 150, 200), (150, 206, 232), (214, 242, 250), (255, 255, 255)],
    "quill":  [(70, 50, 60), (130, 100, 100), (190, 160, 140), (230, 210, 180), (250, 240, 220), (255, 255, 250)],
    "white":  [(90, 96, 120), (150, 160, 180), (200, 210, 222), (232, 238, 244), (248, 250, 252), (255, 255, 255)],
}
LIGHT = (-0.55, -0.75, 0.6)  # from the top-left, towards the viewer
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.mat = [[None] * w for _ in range(h)]
        self.val = [[0.0] * w for _ in range(h)]
        self.fixed = {}  # (x, y) -> rgb drawn as-is (eyes, symbols)

    def set(self, x, y, mat, v):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.mat[y][x] = mat
            self.val[y][x] = max(0.0, min(0.999, v))

    def pixel(self, x, y, rgb):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.fixed[(x, y)] = rgb
            if self.mat[y][x] is None:
                self.mat[y][x] = "_fixed"

    def has(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.mat[y][x] is not None

    def render(self, outline=True, outline_shade=0):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = im.load()
        for y in range(self.h):
            for x in range(self.w):
                m = self.mat[y][x]
                if m is None:
                    continue
                if (x, y) in self.fixed:
                    px[x, y] = self.fixed[(x, y)] + (255,)
                    continue
                ramp = RAMPS[m]
                i = int(self.val[y][x] * len(ramp))
                px[x, y] = ramp[i] + (255,)
        if outline:
            out = im.copy()
            op = out.load()
            for y in range(self.h):
                for x in range(self.w):
                    if self.mat[y][x] is not None:
                        continue
                    # an empty pixel touching the shape becomes outline,
                    # tinted with the darkest color of what it touches
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if self.has(nx, ny):
                            m = self.mat[ny][nx]
                            ramp = RAMPS.get(m, RAMPS["oil"])
                            c = ramp[outline_shade]
                            op[x, y] = (max(0, c[0] - 8), max(0, c[1] - 8), max(0, c[2] - 6), 255)
                            break
            im = out
        return im


def shade_sphere(nx, ny, base=0.5, spec=0.0):
    """Lambert-ish shade for a surface normal (nx, ny) on a dome."""
    nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
    d = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
    v = base + 0.5 * d
    if spec and d > 0.9:
        v += spec
    return v


def save(im, path, scale=1):
    if scale > 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(path)
