"""Redesigned characters: the user's body animations (recolored by derive.py)
with new heads and outfit pieces composited onto every frame."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import derive
from derive import H, put, direction, ranger_role, nerd_role, boar_role, ORIG, PREFIX, regions, CHARS
from heads import render_all, AX, AY
from PIL import Image

HEADS = {}


def shade_dot(px, size, x, y, c):
    put(px, size, x, y, c)


def frame_info(spx, box, role_fn, base):
    x0, y0, w, h = box
    pts = [(x, y) for y in range(y0, y0 + h) for x in range(x0, x0 + w) if spx[x, y][3]]
    if not pts:
        return None
    bx0, by0 = min(p[0] for p in pts), min(p[1] for p in pts)
    bx1, by1 = max(p[0] for p in pts), max(p[1] for p in pts)
    info = {"bbox": (bx0, by0, bx1, by1)}
    if base == "boar":
        top = by0
        row = [p[0] for p in pts if p[1] <= top + 6]
        cx = (min(row) + max(row)) // 2
        info.update(cx=cx, chin=top + 17, head=(cx - 12, top, cx + 12, top + 17), roles={"fur", "tusk", "line"})
        return info
    hair = [(x, y) for (x, y) in pts if role_fn(spx[x, y][:3]) == "hair"]
    skin = [(x, y) for (x, y) in pts if role_fn(spx[x, y][:3]) == "skin"]
    if not hair:
        return None
    hx0, hy0 = min(p[0] for p in hair), min(p[1] for p in hair)
    hx1, hy1 = max(p[0] for p in hair), max(p[1] for p in hair)
    sk_top = min((p[1] for p in skin if p[1] >= hy0), default=hy1)
    chin = sk_top + (12 if base == "nerd" else 13)
    cx = (hx0 + hx1) // 2
    roles = {"hair", "skin", "skinshade", "glass", "line"} | ({"outfit"} if base == "ranger" else set())
    info.update(cx=cx, chin=chin, head=(hx0 - 2, hy0 - 1, hx1 + 2, chin), roles=roles, hair=(hx0, hy0, hx1, hy1))
    return info


def clear_head(spx, dpx, info, role_fn):
    x0, y0, x1, y1 = info["head"]
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < len_x[0] and 0 <= y < len_x[1] and spx[x, y][3]:
                if role_fn(spx[x, y][:3]) in info["roles"]:
                    dpx[x, y] = (0, 0, 0, 0)


def paste_head(dst, head, info, d, lying):
    cx, chin = info["cx"], info["chin"]
    if lying:
        bx0, by0, bx1, by1 = info["bbox"]
        body_cx = (bx0 + bx1) / 2
        rot = head.rotate(90 if cx < body_cx else -90, expand=True)
        dst.alpha_composite(rot, (int(cx - rot.width / 2), int(chin - rot.height + 6)))
        return
    dst.alpha_composite(head, (cx - AX, chin - AY))


len_x = [0, 0]


def outfit(name, dpx, size, info, d):
    cx, chin = info["cx"], info["chin"]
    bx0, by0, bx1, by1 = info["bbox"]
    if name == "mira":
        waist = chin + 15
        white, grey, shadow = H("#f6f8fb"), H("#c8d0dc"), H("#7a8498")
        if d in ("down", "up"):
            for side in (-1, 1):
                x_edge = cx + side * 9
                for y in range(waist, min(by1 - 4, waist + 11)):
                    for k in range(4):
                        x = x_edge - side * k
                        put(dpx, size, x, y, shadow if k == 0 else (white if k == 2 else grey))
            if d == "down":
                for i, col in enumerate((H("#ff5aa0"), H("#5ae06a"), H("#5ab0ff"))):
                    vx = cx - 4 + i * 4
                    put(dpx, size, vx, waist - 2, H("#e8f0f8"))
                    put(dpx, size, vx, waist - 1, col)
                    put(dpx, size, vx, waist, col)
        else:
            s = 1 if d == "right" else -1
            for y in range(waist, min(by1 - 4, waist + 12)):
                for k in range(4):
                    x = cx - s * (5 + k + (y - waist) // 4)
                    put(dpx, size, x, y, shadow if k == 3 else (white if k == 1 else grey))
    elif name == "eco9":
        steel, steel2, dark, core = H("#cfd9e3"), H("#8a98aa"), H("#2a3240"), H("#5ae6f8")
        sy = chin + 2
        sides = (-1, 1) if d in ("down", "up") else ((-1,) if d == "right" else (1,))
        for side in sides:
            px0 = cx + side * 9
            for dy in range(-2, 4):
                for dx in range(-4, 5):
                    if dx * dx / 20 + dy * dy / 8 <= 1:
                        c = steel if (dx * side < 0 and dy < 1) else steel2
                        if dy == 3 or abs(dx) == 4:
                            c = dark
                        put(dpx, size, px0 + dx, sy + dy, c)
        if d == "down":
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if dx * dx + dy * dy <= 5:
                        put(dpx, size, cx + dx, chin + 8 + dy, core if dx * dx + dy * dy > 1 else H("#e8feff"))
    elif name == "silvano":
        vine, leaf, leaf2 = H("#2a6a2a"), H("#4aaa3a"), H("#9ae060")
        if d in ("down", "up"):
            for i in range(14):
                x, y = cx - 8 + i, chin + 4 + i // 2
                put(dpx, size, x, y, vine)
                if i % 4 == 0:
                    put(dpx, size, x, y - 1, leaf)
                    put(dpx, size, x + 1, y - 1, leaf2)
        for side in ((-1, 1) if d in ("down", "up") else (1,)):
            lx = cx + side * 10
            for (dx, dy, c) in ((0, 0, leaf), (1, 0, leaf2), (0, -1, leaf2), (-1, 1, vine), (1, 1, leaf)):
                put(dpx, size, lx + dx, chin + 1 + dy, c)
    elif name == "baron":
        fur, fur2, fur3 = H("#f4f0e6"), H("#d8d0c0"), H("#a89c88")
        y0 = chin
        for y in range(y0, y0 + 4):
            for x in range(cx - 9, cx + 10):
                if (x + y) % 3 == 0:
                    c = fur
                elif (x + y) % 3 == 1:
                    c = fur2
                else:
                    c = fur3 if y == y0 + 3 else fur
                if d in ("left", "right") and abs(x - cx) > 6:
                    continue
                put(dpx, size, x, y, c)


def build(name, out_dir):
    base, role_fn, color_fn, frame_fn, scene, files = CHARS[name]
    derived_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "derived")
    regs = regions(scene)
    os.makedirs(out_dir, exist_ok=True)
    for fname in files:
        src = Image.open(ORIG + PREFIX[base] + fname).convert("RGBA")
        clean = fname.replace(' ', '_').replace('(', '').replace(')', '')
        dst = Image.open(os.path.join(derived_dir, f"{name}_{clean}")).convert("RGBA")
        spx, dpx = src.load(), dst.load()
        len_x[0], len_x[1] = src.size
        done = set()
        for anim, f, box in regs:
            if f != fname or box in done:
                continue
            done.add(box)
            info = frame_info(spx, box, role_fn, base)
            if info is None:
                continue
            d = direction(anim)
            bx0, by0, bx1, by1 = info["bbox"]
            lying = anim == "death" and (bx1 - bx0) > (by1 - by0) * 1.15
            clear_head(spx, dpx, info, role_fn)
            if not lying:
                outfit(name, dpx, dst.size, info, d)
            paste_head(dst, HEADS[(name, d if not lying else "down")], info, d, lying)
            dpx = dst.load()
        dst.save(os.path.join(out_dir, f"{name}_{clean}"))


if __name__ == "__main__":
    HEADS.update(render_all(os.path.join(os.path.dirname(os.path.abspath(__file__)), "heads")))
    out = sys.argv[1]
    for n in (sys.argv[2:] or ["mira", "eco9", "silvano", "baron"]):
        build(n, out)
        print("built", n)
