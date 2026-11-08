"""Volume-shaded pixel-art renderer (in the style of the EcoRescuer heroes).

Parts are volumes (ellipsoids, capsules, rounded boxes) with a height field.
Each pixel takes the front-most part, gets a normal from that part's height
field, is lit from the top-left and quantized onto a hue-shifted 6-tone ramp
(with 2x2 ordered dithering between tones). Overlaps cast contact shadows,
part boundaries get dark inner lines, the silhouette gets a dark outline.
"""
import math, colorsys
from PIL import Image

LIGHT = (-0.55, -0.7, 0.55)
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)
BAYER = [[0.0, 0.5], [0.75, 0.25]]


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def ramp(base, n=6, spread=0.62):
    """Hue-shifted ramp dark->light around `base` (base sits at index 3)."""
    h, l, s = colorsys.rgb_to_hls(*[v / 255 for v in base])
    out = []
    for i in range(n):
        t = (i - 3) / 3.0  # -1 .. +0.67
        nl = max(0.04, min(0.97, l + t * spread * (0.55 if t < 0 else 0.75) * (1 if t < 0 else 1)))
        if t < 0:
            nl = l * (1 + t * 0.62)
        # shadows lean blue/violet, lights lean yellow
        target = 0.68 if t < 0 else 0.13
        dh = ((target - h + 0.5) % 1.0) - 0.5
        nh = (h + dh * abs(t) * 0.12) % 1.0
        ns = min(1, s * (1 + (-t) * 0.15)) if t < 0 else s * (1 - t * 0.25)
        r, g, b = colorsys.hls_to_rgb(nh, nl, ns)
        out.append((int(r * 255), int(g * 255), int(b * 255)))
    return out


class Part:
    def __init__(self, mat, z):
        self.mat, self.z = mat, z
        self.h = {}  # (x, y) -> height 0..1

    def bounds(self):
        return self.h.keys()


def ellipsoid(mat, z, cx, cy, rx, ry, depth=1.0):
    p = Part(mat, z)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1.0:
                p.h[(x, y)] = math.sqrt(1 - d) * depth
    return p


def capsule(mat, z, x0, y0, x1, y1, r, depth=1.0):
    p = Part(mat, z)
    vx, vy = x1 - x0, y1 - y0
    L2 = vx * vx + vy * vy or 1e-6
    for y in range(int(min(y0, y1) - r) - 1, int(max(y0, y1) + r) + 2):
        for x in range(int(min(x0, x1) - r) - 1, int(max(x0, x1) + r) + 2):
            px, py = x + 0.5, y + 0.5
            t = max(0, min(1, ((px - x0) * vx + (py - y0) * vy) / L2))
            cx, cy = x0 + vx * t, y0 + vy * t
            d = math.hypot(px - cx, py - cy) / r
            if d <= 1.0:
                p.h[(x, y)] = math.sqrt(1 - d * d) * depth
    return p


def rbox(mat, z, x0, y0, x1, y1, rad=3.0, depth=1.0, round_bottom=0.0):
    """Rounded box (pillow) from x0..x1, y0..y1 inclusive."""
    p = Part(mat, z)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            # corner rounding
            cx = min(max(x + 0.5, x0 + rad), x1 + 1 - rad)
            cy = min(max(y + 0.5, y0 + rad), y1 + 1 - rad)
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) > rad:
                continue
            e = min(x + 0.5 - x0, x1 + 1 - (x + 0.5), y + 0.5 - y0, y1 + 1 - (y + 0.5))
            p.h[(x, y)] = min(1.0, (max(0.0, e) / (rad + 1.5)) ** 0.6) * depth
    return p


def poly(mat, z, pts, depth=0.7):
    """Polygon with a soft pillow height (for hair spikes, collars...)."""
    p = Part(mat, z)
    xs = [q[0] for q in pts]
    ys = [q[1] for q in pts]
    inside = set()
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            if _pip(x + 0.5, y + 0.5, pts):
                inside.add((x, y))
    for (x, y) in inside:
        e = 0
        for r in range(1, 4):
            if all((x + dx, y + dy) in inside for dx in range(-r, r + 1) for dy in range(-r, r + 1) if abs(dx) + abs(dy) == r):
                e = r
            else:
                break
        p.h[(x, y)] = (0.35 + e * 0.22) * depth
    return p


def _pip(x, y, pts):
    c = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            c = not c
        j = i
    return c


class Canvas:
    def __init__(self, w, h, palette):
        self.w, self.h = w, h
        self.pal = palette  # mat -> ramp list (6 colors)
        self.parts = []
        self.paint = {}   # (x, y) -> (mat, idx) or rgb, applied after shading
        self.textures = {}  # mat -> fn(x, y, v) -> v

    def add(self, part):
        self.parts.append(part)
        return part

    def dot(self, x, y, mat, idx):
        self.paint[(int(x), int(y))] = (mat, idx)

    def render(self, outline=(18, 12, 22), inner_lines=True):
        top = {}
        for p in sorted(self.parts, key=lambda q: q.z):
            for xy, hh in p.h.items():
                x, y = xy
                if 0 <= x < self.w and 0 <= y < self.h:
                    top[xy] = (p, hh)
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = im.load()
        for (x, y), (p, hh) in top.items():
            gx = p.h.get((x + 1, y), 0) - p.h.get((x - 1, y), 0)
            gy = p.h.get((x, y + 1), 0) - p.h.get((x, y - 1), 0)
            nx, ny, nz = -gx * 1.6, -gy * 1.6, 1.0
            ln = math.sqrt(nx * nx + ny * ny + nz * nz)
            d = (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / ln
            v = 0.12 + 0.88 * max(0.0, d)
            # contact shadow: a part drawn above casts a short shadow down-right
            for (sx, sy) in ((-1, -1), (0, -1), (-1, 0), (0, -2)):
                o = top.get((x + sx, y + sy))
                if o and o[0].z > p.z and o[0] is not p:
                    v -= 0.22
                    break
            tex = self.textures.get(p.mat)
            if tex:
                v = tex(x, y, v)
            ramp_ = self.pal[p.mat]
            f = max(0.0, min(0.999, v)) * (len(ramp_) - 1)
            i = int(f)
            frac = f - i
            if frac > BAYER[y % 2][x % 2] * 0.9 + 0.05 and i < len(ramp_) - 1 and 0.35 < frac:
                i += 1
            px[x, y] = ramp_[i] + (255,)
        # inner lines between different parts (only where the back part is lower)
        if inner_lines:
            src = im.copy().load()
            for (x, y), (p, hh) in top.items():
                for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
                    o = top.get((x + dx, y + dy))
                    if o and o[0] is not p and o[0].mat != p.mat and o[0].z > p.z:
                        r = self.pal[p.mat][0]
                        px[x, y] = (int(r[0] * 0.8), int(r[1] * 0.8), int(r[2] * 0.85), 255)
                        break
        for (x, y), val in self.paint.items():
            if 0 <= x < self.w and 0 <= y < self.h:
                if isinstance(val[0], str):
                    px[x, y] = self.pal[val[0]][val[1]] + (255,)
                else:
                    px[x, y] = tuple(val) + (255,)
        # outline
        out = im.copy()
        o = out.load()
        for y in range(self.h):
            for x in range(self.w):
                if px[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx_, ny_ = x + dx, y + dy
                    if 0 <= nx_ < self.w and 0 <= ny_ < self.h and px[nx_, ny_][3]:
                        c = px[nx_, ny_]
                        o[x, y] = (int(c[0] * 0.18 + outline[0] * 0.82), int(c[1] * 0.18 + outline[1] * 0.82), int(c[2] * 0.18 + outline[2] * 0.82), 255)
                        break
        return out
