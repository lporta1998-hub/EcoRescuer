"""New EcoRescuer characters derived from the user's own hero sprite sheets:
recolor by color role + per-frame overlays anchored to the head."""
import os
import colorsys, math, os, re, sys
from PIL import Image
GAME_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) + "/"  # the EcoRescuer project

ORIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "orig") + "/"
GAME = GAME_ROOT


def hls(c):
    return colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1, max(0, min(1, l)), max(0, min(1, s)))
    return (int(r * 255), int(g * 255), int(b * 255))


def lum(c):
    return (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255


def ramp_map(c, stops, lo=0.02, hi=0.92):
    """Map a color onto a dark->light list of stops by its luminance."""
    l = lum(c)
    t = max(0, min(1, (l - lo) / (hi - lo)))
    f = t * (len(stops) - 1)
    i = min(int(f), len(stops) - 2)
    k = f - i
    a, b = stops[i], stops[i + 1]
    return tuple(int(a[j] + (b[j] - a[j]) * k) for j in range(3))


def H(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def regions(scene):
    t = open(GAME + scene).read()
    ext = {m.group(2): m.group(1) for m in re.finditer(r'path="([^"]+)" id="([^"]+)"', t)}
    atlas = {}
    for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\natlas = ExtResource\("([^"]+)"\)\nregion = Rect2\(([^)]*)\)', t):
        atlas[m.group(1)] = (ext[m.group(2)], tuple(int(float(v)) for v in m.group(3).split(",")))
    out = []
    for frames, name in re.findall(r'\{\n"frames": \[(.*?)\],\n"loop": \w+,\n"name": &"([^"]+)"', t, re.S):
        for i in re.findall(r'SubResource\("([^"]+)"\)', frames):
            if i in atlas:
                out.append((name, atlas[i][0].split("/")[-1], atlas[i][1]))
    return out


def direction(anim):
    if anim.endswith("_up") or anim.endswith("_top"):
        return "up"
    if anim.endswith("_down") or anim == "death":
        return "down"
    if anim.endswith("_left"):
        return "left"
    return "right"


def head_box(px, box, is_head):
    x0, y0, w, h = box
    pts = [(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w) if px[x, y][3] and is_head(px[x, y][:3])]
    if not pts:
        return None
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def put(px, size, x, y, c):
    if 0 <= x < size[0] and 0 <= y < size[1]:
        px[x, y] = c + (255,)


# --- role classifiers (on the ORIGINAL colors) ------------------------------

def ranger_role(c):
    h, l, s = hls(c)
    deg = h * 360
    if l < 0.06:
        return "line"
    if 180 <= deg <= 225 and s > 0.35:
        return "hair"
    if (deg >= 335 or deg <= 12) and s > 0.55 and l < 0.6:
        return "sash"
    if 8 <= deg <= 35 and s > 0.25 and l > 0.32:
        return "skin"
    if 330 <= deg or deg < 8:
        return "skinshade" if l > 0.25 else "outfit"
    return "outfit"


def nerd_role(c):
    h, l, s = hls(c)
    deg = h * 360
    if l < 0.06:
        return "line"
    if 8 <= deg <= 32 and s > 0.3 and l > 0.6:
        return "skin"
    if 18 <= deg <= 55 and s > 0.45 and 0.12 < l <= 0.75:
        return "hair"
    if 70 <= deg <= 130 and s > 0.25:
        return "vest"
    if 230 <= deg <= 300 and l < 0.35:
        return "jacket"
    if (deg >= 330 or deg <= 8) and s > 0.6:
        return "blade"
    if 185 <= deg <= 215 and l > 0.6:
        return "glass"
    if 20 <= deg <= 40 and l <= 0.4:
        return "pants"
    return "metal"


def boar_role(c):
    h, l, s = hls(c)
    deg = h * 360
    if l < 0.07:
        return "line"
    if 100 <= deg <= 170 and s > 0.25:
        return "pants"
    if 190 <= deg <= 230 and s > 0.2:
        return "pantshade"
    if l > 0.62 and s < 0.3:
        return "tusk"
    return "fur"


# --- characters -------------------------------------------------------------

def mira_color(c, role):
    if role == "hair":
        return ramp_map(c, [H("#1a0c2e"), H("#4a2370"), H("#7a42a8"), H("#b07ad8"), H("#e6c8f8")])
    if role == "outfit":
        return None  # decided per pixel (coat vs trousers)
    if role == "sash":
        return ramp_map(c, [H("#1c3a2a"), H("#2f8a5a"), H("#52d08a"), H("#a8f8c8")])
    return c


def baron_color(c, role):
    if role == "hair":   # the bun becomes a top hat
        return ramp_map(c, [H("#060508"), H("#141018"), H("#2a2432"), H("#4a4256"), H("#7a7086")])
    if role == "outfit":
        return ramp_map(c, [H("#05040a"), H("#151320"), H("#26243a"), H("#3e3c58"), H("#6a6888")])
    if role == "sash":
        return ramp_map(c, [H("#3a0a12"), H("#7a1420"), H("#b82a30"), H("#f06a5a")])
    return c


def robot_color(c, role):
    if role in ("skin",):
        return ramp_map(c, [H("#2a3240"), H("#5a6a80"), H("#9aaabb"), H("#cfd9e3"), H("#f4f8fb")])
    if role == "hair":
        return ramp_map(c, [H("#101826"), H("#22344e"), H("#3a5a80"), H("#5aa0c8"), H("#9af0ff")])
    if role == "jacket":
        return ramp_map(c, [H("#0c0e14"), H("#1e222c"), H("#363c4a"), H("#5a6274"), H("#8a92a4")])
    if role == "vest":
        return ramp_map(c, [H("#062830"), H("#0c5866"), H("#18a0b0"), H("#5ae6f0"), H("#c8fcff")])
    if role == "pants":
        return ramp_map(c, [H("#0e1016"), H("#22262e"), H("#3a404c"), H("#5c6474")])
    if role == "blade":
        return ramp_map(c, [H("#0a4a70"), H("#1a9ad0"), H("#5ae0ff"), H("#d8fcff")])
    if role == "glass":
        return ramp_map(c, [H("#600a10"), H("#c81e28"), H("#ff5a4a"), H("#ffd0c0")]) if False else ramp_map(c, [H("#0a5a70"), H("#20c0e8"), H("#a0f6ff"), H("#ffffff")])
    if role == "metal":
        return ramp_map(c, [H("#14161c"), H("#3a404c"), H("#6a7486"), H("#a8b2c2"), H("#e6ecf2")])
    return c


def silvano_color(c, role):
    if role == "fur":
        return ramp_map(c, [H("#140e0a"), H("#3a2a1c"), H("#5e4a30"), H("#7a7040"), H("#9aa458"), H("#d0e08a")])
    if role == "pants":
        return ramp_map(c, [H("#0c2010"), H("#1c4a1e"), H("#2f7a2c"), H("#5aaa3a"), H("#a8e070")])
    if role == "pantshade":
        return ramp_map(c, [H("#0a1a10"), H("#183a20"), H("#2a5a30")])
    if role == "tusk":
        return ramp_map(c, [H("#5a4022"), H("#a87c46"), H("#e0c08a"), H("#fff0d0")])
    return c


# --- per-frame overlays -------------------------------------------------------

def mira_frame(src, dst, box, anim):
    """Coat on top, trousers below, beard and scar replaced by clean skin,
    long flowing hair."""
    spx, dpx = src.load(), dst.load()
    x0, y0, w, h = box
    d = direction(anim)
    skin = [(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w)
            if spx[x, y][3] and ranger_role(spx[x, y][:3]) == "skin"]
    hair = head_box(spx, box, lambda c: ranger_role(c) == "hair")
    if not skin:
        return
    sk_top = min(p[1] for p in skin)
    face_x = [p[0] for p in skin if p[1] <= sk_top + 6]
    fx0, fx1 = (min(face_x), max(face_x)) if face_x else (x0, x0 + w)
    chin = sk_top + 14
    coat_end = chin + 17
    light_skin, mid_skin, lip = H("#f6d2b6"), H("#e4ac88"), H("#c26a6a")
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            c = spx[x, y]
            if not c[3]:
                continue
            role = ranger_role(c[:3])
            in_face = y <= chin and fx0 - 1 <= x <= fx1 + 1 and d != "up"
            if in_face and role in ("outfit", "sash", "skinshade"):
                # beard / scar -> smooth skin (darker at the jaw edge), small lips
                edge = x in (fx0 - 1, fx0, fx1, fx1 + 1) or y == chin
                dpx[x, y] = (mid_skin if edge else light_skin) + (255,)
            elif role == "outfit":
                if y <= coat_end:
                    dpx[x, y] = ramp_map(c[:3], [H("#5a6478"), H("#aab4c6"), H("#dfe5ee"), H("#f6f8fb"), H("#ffffff")], 0.0, 0.33) + (255,)
                else:
                    dpx[x, y] = ramp_map(c[:3], [H("#0a1c22"), H("#16323a"), H("#24505a"), H("#3a7480")], 0.0, 0.33) + (255,)
    if d != "up":
        mx = (fx0 + fx1) // 2 + (0 if d == "down" else (2 if d == "right" else -2))
        put(dpx, dst.size, mx, chin - 4, lip)
        put(dpx, dst.size, mx + (1 if d != "left" else -1), chin - 4, lip)
    if hair is None:
        return
    hx0, hy0, hx1, hy1 = hair
    shades = [H("#24103c"), H("#3e1e62"), H("#5a2e86"), H("#7a46aa"), H("#a070cc")]
    bottom = chin + 8
    def strand(x, y, k):
        put(dpx, dst.size, x, y, shades[k])
    if d == "down":
        for i, x in enumerate((hx0 - 1, hx0, hx0 + 1)):
            for y in range(sk_top + 2, bottom - (2 - i)):
                strand(x, y, [0, 2, 3][i] if (y % 4) else 1)
        for i, x in enumerate((hx1 + 1, hx1, hx1 - 1)):
            for y in range(sk_top + 2, bottom - (2 - i)):
                strand(x, y, [0, 1, 2][i] if (y % 4) else 1)
    elif d == "up":
        for x in range(hx0 - 1, hx1 + 2):
            length = bottom - abs(x - (hx0 + hx1) / 2) * 0.35
            for y in range(sk_top, int(length)):
                k = 2 + ((x - hx0) % 3 == 0) - ((x - hx0) % 3 == 2)
                if x in (hx0 - 1, hx1 + 1) or y >= int(length) - 1:
                    k = 0
                strand(x, y, max(0, min(4, k)))
    else:
        back = hx0 if d == "right" else hx1
        step = -1 if d == "right" else 1
        for y in range(sk_top, bottom):
            for k in range(3):
                strand(back + step * k, y, [3, 2, 1][k] if (y % 5) else 0)
            strand(back + step * 3, y, 0)


def baron_frame(src, dst, box, anim):
    """The bun becomes a tall top hat (black, red band, brim); gold chain."""
    spx, dpx = src.load(), dst.load()
    d = direction(anim)
    hair = head_box(spx, box, lambda c: ranger_role(c) == "hair")
    skin = [(x, y) for y in range(box[1], box[1] + box[3]) for x in range(box[0], box[0] + box[2])
            if spx[x, y][3] and ranger_role(spx[x, y][:3]) == "skin"]
    if not hair:
        return
    hx0, hy0, hx1, hy1 = hair
    sk_top = min(p[1] for p in skin) if skin else hy1
    cx = (hx0 + hx1) // 2
    brim_y = sk_top - 1 if d != "up" else hy0 + 9
    top_y = brim_y - 11
    crown = [H("#0c0a10"), H("#1a1620"), H("#2c2634"), H("#3e3848")]
    for y in range(top_y, brim_y):
        for x in range(cx - 5, cx + 6):
            k = 2 if x <= cx - 3 else (1 if x < cx + 3 else 0)
            if y == top_y:
                k = 3
            put(dpx, dst.size, x, y, crown[k])
        put(dpx, dst.size, cx - 6, y, H("#050407"))
        put(dpx, dst.size, cx + 6, y, H("#050407"))
    for x in range(cx - 6, cx + 7):
        put(dpx, dst.size, x, top_y - 1, H("#050407"))
        put(dpx, dst.size, x, brim_y - 3, H("#b02a30"))
        put(dpx, dst.size, x, brim_y - 2, H("#7a1820"))
    for x in range(cx - 9, cx + 10):
        put(dpx, dst.size, x, brim_y, crown[1])
        put(dpx, dst.size, x, brim_y + 1, H("#050407"))
    if skin and d != "up":
        sx = [p[0] for p in skin]
        mono_x = max(sx) - 3 if d != "left" else min(sx) + 2
        put(dpx, dst.size, mono_x, sk_top + 6, H("#f0c040"))
        put(dpx, dst.size, mono_x + 1, sk_top + 7, H("#f0c040"))
        put(dpx, dst.size, mono_x, sk_top + 8, H("#b08020"))
        cy = sk_top + 22
        for i in range(7):
            put(dpx, dst.size, min(sx) + 1 + i, cy + (1 if 1 <= i <= 5 else 0), H("#f0c040") if i % 2 else H("#b08020"))


def silvano_frame(src, dst, box, anim):
    """Crown of branches with leaves on the head, glowing eyes."""
    spx, dpx = src.load(), dst.load()
    x0, y0, w, h = box
    pts = [(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w) if spx[x, y][3]]
    if not pts:
        return
    top = min(p[1] for p in pts)
    row = [p[0] for p in pts if p[1] <= top + 4]
    cx = (min(row) + max(row)) // 2
    d = direction(anim)
    wood, wood2, leaf, leaf2, leaf3 = H("#4a321c"), H("#7a5632"), H("#2a8a2e"), H("#5cc048"), H("#a8ec70")
    sides = (-1, 1) if d in ("down", "up") else ((1,) if d == "right" else (-1,))
    for side in sides:
        bx = cx + side * 4
        pts = []
        for i in range(10):  # branch curving up and out
            x = bx + side * int(i * 0.55)
            y = top + 2 - i
            pts.append((x, y))
            put(dpx, dst.size, x, y, wood2)
            put(dpx, dst.size, x + side, y, wood)
        for j, (fx, fy) in enumerate(((3, 4), (6, 7), (9, 9))):  # forks
            ox, oy = pts[min(fx, 9)]
            for k in range(1, 4):
                put(dpx, dst.size, ox + side * k, oy - k + 1, wood2)
            lx, ly = ox + side * 4, oy - 3
            for (dx, dy, cc) in ((0, 0, leaf2), (side, 0, leaf), (0, -1, leaf3), (side, -1, leaf2), (-side, 0, leaf)):
                put(dpx, dst.size, lx + dx, ly + dy, cc)
        tx, ty = pts[-1]
        for (dx, dy, cc) in ((0, -1, leaf3), (side, -1, leaf2), (0, -2, leaf2)):
            put(dpx, dst.size, tx + dx, ty + dy, cc)
    # glowing green eyes (the two brightest pixels in the face rows)


def generic(src, dst, box, anim):
    pass


def mira2_color(c, role):
    if role == "hair":
        return ramp_map(c, [H("#1a0c2e"), H("#3e1e62"), H("#6a3a9a"), H("#9a64c8"), H("#d4b0f0")])
    if role == "jacket":   # lab coat
        return ramp_map(c, [H("#5a6478"), H("#aab4c6"), H("#dfe5ee"), H("#f6f8fb"), H("#ffffff")], 0.0, 0.3)
    if role == "vest":     # blouse
        return ramp_map(c, [H("#1a3a40"), H("#24606a"), H("#2f8a90"), H("#5ac0c0"), H("#a8ece4")])
    if role == "pants":
        return ramp_map(c, [H("#101420"), H("#1e2434"), H("#323a50"), H("#4a5470")])
    if role == "blade":
        return "clear"
    return c


def eco9_color(c, role):
    if role in ("skin", "skinshade"):
        return ramp_map(c, [H("#2a3240"), H("#5a6a80"), H("#9aaabb"), H("#cfd9e3"), H("#f4f8fb")])
    if role == "hair":     # helmet dome with a cyan light
        return ramp_map(c, [H("#0a0e16"), H("#18243a"), H("#24406a"), H("#3a8ac0"), H("#8af0ff")])
    if role == "outfit":   # armour plating (and the mouth guard)
        return ramp_map(c, [H("#0c0e14"), H("#20242e"), H("#3a404e"), H("#626a7e"), H("#9aa2b4")], 0.0, 0.33)
    if role == "sash":     # power core
        return ramp_map(c, [H("#063a48"), H("#0c7a90"), H("#28d0e8"), H("#b8faff")])
    return c


def mira2_frame(src, dst, box, anim):
    """Long flowing hair on the Nerd base."""
    spx, dpx = src.load(), dst.load()
    d = direction(anim)
    hair = head_box(spx, box, lambda c: nerd_role(c) == "hair")
    skin = [(x, y) for y in range(box[1], box[1] + box[3]) for x in range(box[0], box[0] + box[2])
            if spx[x, y][3] and nerd_role(spx[x, y][:3]) == "skin"]
    if not hair or not skin:
        return
    hx0, hy0, hx1, hy1 = hair
    sk_top = min(p[1] for p in skin)
    shades = [H("#24103c"), H("#3e1e62"), H("#5a2e86"), H("#7a46aa"), H("#a070cc")]
    bottom = sk_top + 24
    def strand(x, y, k):
        put(dpx, dst.size, x, y, shades[max(0, min(4, k))])
    if d == "down":
        for i, x in enumerate((hx0 - 1, hx0, hx0 + 1, hx0 + 2)):
            for y in range(sk_top + 3, bottom - (3 - i)):
                strand(x, y, [0, 2, 3, 2][i] if y % 4 else 1)
        for i, x in enumerate((hx1 + 1, hx1, hx1 - 1, hx1 - 2)):
            for y in range(sk_top + 3, bottom - (3 - i)):
                strand(x, y, [0, 1, 2, 1][i] if y % 4 else 1)
    elif d == "up":
        for x in range(hx0 - 1, hx1 + 2):
            length = bottom - abs(x - (hx0 + hx1) / 2) * 0.4
            for y in range(hy1 - 2, int(length)):
                k = 2 + ((x - hx0) % 3 == 0) - ((x - hx0) % 3 == 2)
                if x in (hx0 - 1, hx1 + 1) or y >= int(length) - 1:
                    k = 0
                strand(x, y, k)
    else:
        back = hx0 if d == "right" else hx1
        step = -1 if d == "right" else 1
        for y in range(sk_top + 2, bottom):
            for k in range(4):
                strand(back + step * (k - 1), y, [3, 2, 2, 1][k] if y % 5 else 0)
            strand(back + step * 3, y, 0)


CHARS = {
    # name: (base, classifier, color fn, frame fn, scene, files)
    "mira": ("nerd", nerd_role, mira2_color, generic, "Characters/CharacterNerd/Assets/Scenes/Nerd.tscn",
             ["idle.png", "walk.png", "hurt.png", "slash_oversize.png"]),
    "baron": ("ranger", ranger_role, baron_color, baron_frame, "Characters/CharacterRanger/Assets/Scenes/character_body_2d.tscn",
              ["RangerIdle.png", "RangerRun.png", "hurt.png", "character-spritesheet (2).png", "shoot.png"]),
    "eco9": ("ranger", ranger_role, eco9_color, generic, "Characters/CharacterRanger/Assets/Scenes/character_body_2d.tscn",
             ["RangerIdle.png", "RangerRun.png", "hurt.png", "character-spritesheet (2).png", "shoot.png"]),
    "silvano": ("boar", boar_role, silvano_color, silvano_frame, "Characters/CharacterBoar/Assets/Scenes/Boarman.tscn",
                ["boar-character.png"]),
}
PREFIX = {"ranger": "CharacterRanger_", "nerd": "CharacterNerd_", "boar": "CharacterBoar_"}

# extra frames (not in the source scenes) that a character uses: Mira throws
# with the spellcast rows of the full sheet (rows 0 up, 2 down, 3 right).
EXTRA = {"unused": [("attack_up", "character-spritesheet (2).png", (i * 64, 0, 64, 64)) for i in range(7)]
         + [("attack_down", "character-spritesheet (2).png", (i * 64, 128, 64, 64)) for i in range(7)]
         + [("attack", "character-spritesheet (2).png", (i * 64, 192, 64, 64)) for i in range(7)]}


def build(name, out_dir):
    base, role_fn, color_fn, frame_fn, scene, files = CHARS[name]
    regs = regions(scene) + EXTRA.get(name, [])
    os.makedirs(out_dir, exist_ok=True)
    made = {}
    for fname in files:
        src = Image.open(ORIG + PREFIX[base] + fname).convert("RGBA")
        dst = src.copy()
        spx, dpx = src.load(), dst.load()
        cache = {}
        for y in range(src.height):
            for x in range(src.width):
                c = spx[x, y]
                if not c[3]:
                    continue
                key = c[:3]
                if key not in cache:
                    role = role_fn(key)
                    nc = color_fn(key, role)
                    cache[key] = nc
                nc = cache[key]
                if nc == "clear":
                    dpx[x, y] = (0, 0, 0, 0)
                elif nc is not None:
                    dpx[x, y] = nc + (c[3],)
        for anim, f, box in regs:
            if f == fname:
                frame_fn(src, dst, box, anim)
        out = os.path.join(out_dir, f"{name}_{fname.replace(' ', '_').replace('(', '').replace(')', '')}")
        dst.save(out)
        made[fname] = out
    return made


if __name__ == "__main__":
    out = sys.argv[1]
    for n in (sys.argv[2:] or CHARS):
        print(n, list(build(n, out).values()))
