#!/usr/bin/env python3
"""Finds good places for a level's secret area (see Misc/Secrets/secret_spots.gd).

Input: a grid dump written by Tools/dev/dump_grid.gd (8 px cells):
  first line "ox oy w h" (origin in px), then w*h characters:
  '#' solid, '.' open, 'B' trash bag, 'E' enemy, 'T' teleport, 'c' item, 'P' start.

A secret is a pocket of the map that a few crates across a narrow corridor
cut off from the start. For each narrow corridor cell it blocks a small
square, floods from the start and looks at what got cut off. A good pocket:
  - is big enough to be worth it, and not a huge part of the map;
  - holds no trash bag, enemy, teleport or start (the objective must stay
    reachable without breaking anything);
  - is deep (the relic goes on the farthest cell, out of sight).
Prints the best candidates as: score, crate cells (16 px, in px), relic px.

  python3 Tools/dev/find_secret_spots.py dump_Forest.txt [count]
  (env MIN_POCKET / MAX_HALF_WIDTH to look for smaller pockets or wider corridors)
"""
import sys
from collections import deque

import os
MIN_POCKET = int(os.environ.get("MIN_POCKET", 150))   # cells (8 px): 150 = about 10 000 px^2
MAX_POCKET = 6000
MAX_HALF_WIDTH = int(os.environ.get("MAX_HALF_WIDTH", 4))  # corridor half width, cells


def load(path):
    with open(path, "rb") as f:
        ox, oy, w, h = map(int, f.readline().split())
        data = f.read().decode("ascii")
    rows = [data[y * w:(y + 1) * w] for y in range(h)]
    return ox, oy, w, h, rows


def flood(rows, w, h, start, blocked):
    seen = bytearray(w * h)
    q = deque([start])
    seen[start[1] * w + start[0]] = 1
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                i = ny * w + nx
                if not seen[i] and rows[ny][nx] != '#' and i not in blocked:
                    seen[i] = 1
                    q.append((nx, ny))
    return seen


def splits(reach, w, h, cx, cy, block):
    """Quick test: does blocking the square leave its border ring in two or
    more separate pieces? (if not, it can't cut anything off)"""
    r = block + 1
    ring = []
    for x in range(cx - r, cx + r + 1):
        ring.append((x, cy - r))
    for y in range(cy - r + 1, cy + r + 1):
        ring.append((cx + r, y))
    for x in range(cx + r - 1, cx - r - 1, -1):
        ring.append((x, cy + r))
    for y in range(cy + r - 1, cy - r, -1):
        ring.append((cx - r, y))
    open_ = [0 <= x < w and 0 <= y < h and bool(reach[y * w + x]) for x, y in ring]
    if all(open_) or not any(open_):
        return False
    runs = sum(1 for i in range(len(open_)) if open_[i] and not open_[i - 1])
    return runs >= 2


def clearance(rows, w, h, reach):
    """Distance (cells) from every reachable cell to the nearest non-reachable one."""
    dist = [-1] * (w * h)
    q = deque()
    for y in range(h):
        for x in range(w):
            if not reach[y * w + x]:
                dist[y * w + x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and dist[ny * w + nx] < 0:
                dist[ny * w + nx] = dist[y * w + x] + 1
                q.append((nx, ny))
    return dist


def main():
    ox, oy, w, h, rows = load(sys.argv[1])
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    start = next((x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == 'P')
    reach = flood(rows, w, h, start, set())
    dist = clearance(rows, w, h, reach)
    # corridor cells: in the middle of a passage up to ~8 cells (64 px) wide
    cands = [(x, y) for y in range(h) for x in range(w)
             if reach[y * w + x] and 1 <= dist[y * w + x] <= MAX_HALF_WIDTH
             and x % 2 == 0 and y % 2 == 0]
    results = []
    tried = set()
    why = {"size": 0, "content": 0, "same": 0}
    for (cx, cy) in cands:
        block = dist[cy * w + cx] + 1  # a square that spans the corridor
        blocked = set()
        for y in range(cy - block, cy + block + 1):
            for x in range(cx - block, cx + block + 1):
                if 0 <= x < w and 0 <= y < h and reach[y * w + x]:
                    blocked.add(y * w + x)
        if start[1] * w + start[0] in blocked:
            continue
        if not splits(reach, w, h, cx, cy, block):
            why["size"] += 1
            continue
        after = flood(rows, w, h, start, blocked)
        pocket = [i for i in range(w * h) if reach[i] and not after[i] and i not in blocked]
        if not (MIN_POCKET <= len(pocket) <= MAX_POCKET):
            why["size"] += 1
            continue
        key = min(pocket)
        if key in tried:
            why["same"] += 1
            continue  # same pocket from another corridor cell
        tried.add(key)
        if any(rows[i // w][i % w] in "BTP" for i in pocket):
            why["content"] += 1
            continue
        enemies = sum(1 for i in pocket if rows[i // w][i % w] == 'E')
        # depth: how far each pocket cell is from the crates
        pset = set(pocket)
        q = deque()
        depth = {}
        for i in blocked:
            x, y = i % w, i // w
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                j = (y + dy) * w + (x + dx)
                if j in pset and j not in depth:
                    depth[j] = 1
                    q.append(j)
        while q:
            i = q.popleft()
            x, y = i % w, i // w
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                j = (y + dy) * w + (x + dx)
                if j in pset and j not in depth:
                    depth[j] = depth[i] + 1
                    q.append(j)
        if not depth:
            continue
        # relic: the deepest cell with some room around it
        far = max(depth, key=lambda i: (dist[i] >= 2, depth[i]))
        items = sum(1 for i in pocket if rows[i // w][i % w] == 'c')
        score = min(depth[far], 60) + min(len(pocket), 1500) / 100 + 2 * items - 8 * enemies
        # crates: only the blocked cells that touch the pocket seal it (any
        # way in has to step on one of them), as 16 px cells
        seal = [i for i in blocked if any(((i // w) + dy) * w + (i % w) + dx in pset
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        crates = sorted({(((i % w) * 8 + ox) // 16 * 16 + 8, ((i // w) * 8 + oy) // 16 * 16 + 8)
                         for i in seal})
        relic = ((far % w) * 8 + ox + 4, (far // w) * 8 + oy + 4)
        results.append((score, len(pocket), depth[far], items, enemies, crates, relic))
    print("candidates %d, rejected: %s" % (len(cands), why))
    results.sort(reverse=True)
    for r in results[:count]:
        score, size, deep, items, enemies, crates, relic = r
        print("score %.1f  pocket %d cells  depth %d  items %d  enemies %d" % (score, size, deep, items, enemies))
        print("  crates:", crates)
        print("  relic:", relic)


if __name__ == "__main__":
    main()
