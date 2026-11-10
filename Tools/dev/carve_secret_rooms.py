#!/usr/bin/env python3
"""Carves the secret rooms into the text maps of the built levels (one-off,
already applied: re-running it fails its checks because the rooms exist).
  python3 Tools/dev/carve_secret_rooms.py [Ruins_level ...]

Each carve is a list of rectangles (x0, y0, x1, y1, char) in tiles, applied
in order. Before changing anything it checks that every carved cell and the
1-tile border around the carve is solid ('&' forest/machinery or '#' wall),
so a room never opens into the level by accident; the only open cells allowed
next to it are the entrance floor (`entrance`) and its corners.
Map letters: V breakable crate, Y secret relic (Misc/Builder/built_level.gd).
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')

CARVES = {
    # hidden glade inside the forest block in the middle, entrance from the west
    'Ruins_level': ('&', [(36, 13, 46, 17, '.'), (31, 15, 35, 16, '.'), (31, 15, 31, 16, 'V'),
                          (38, 14, 38, 14, 'o'), (44, 16, 44, 16, 'o'), (45, 14, 45, 14, 'Y')],
                    {(30, 15), (30, 16)}),
    # storeroom under the bottom machinery, entrance from the south-west yard
    'Factory_level': ('&', [(30, 70, 44, 72, ','), (36, 69, 37, 69, 'V'), (33, 71, 33, 71, 'x'),
                            (43, 71, 43, 71, 'Y')], {(36, 68), (37, 68)}),
    # smugglers' gap behind the containers at the top left
    'Harbor_level': ('&', [(8, 1, 24, 2, ','), (15, 3, 16, 3, 'V'), (10, 1, 10, 1, 'x'),
                           (23, 1, 23, 1, 'Y')], {(15, 4), (16, 4)}),
    # clearing in the junk at the bottom left, entrance from the east
    'Fortress_level': ('&', [(4, 64, 12, 70, '.'), (13, 67, 18, 68, '.'), (18, 67, 18, 68, 'V'),
                             (6, 69, 6, 69, 'o'), (5, 65, 5, 65, 'Y')], {(19, 67), (19, 68)}),
}
# (Escape_level's room is made by Tools/dev/escape_map.py)


def carve(name, solid, rects, entrance):
    path = os.path.join(ROOT, 'Levels', name, 'map.txt')
    rows = [list(r) for r in open(path).read().rstrip('\n').split('\n')]
    cells = {(x, y) for (x0, y0, x1, y1, _) in rects
             for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}
    near_entrance = {(x + dx, y + dy) for (x, y) in entrance for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    for (x, y) in cells:
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                c = (x + dx, y + dy)
                if c in cells or c in near_entrance:
                    continue
                assert rows[c[1]][c[0]] in solid, (name, 'not solid', c, rows[c[1]][c[0]])
    for (x, y) in cells:
        assert rows[y][x] in solid, (name, 'already carved?', (x, y), rows[y][x])
    for (x, y) in entrance:
        assert rows[y][x] not in solid, (name, 'entrance not open', (x, y), rows[y][x])
    for (x0, y0, x1, y1, ch) in rects:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                rows[y][x] = ch
    with open(path, 'w') as f:
        f.write('\n'.join(''.join(r) for r in rows) + '\n')
    print('carved', name)


if __name__ == '__main__':
    import sys
    for name, (solid, rects, entrance) in CARVES.items():
        if len(sys.argv) > 1 and name not in sys.argv[1:]:
            continue
        carve(name, solid, rects, entrance)
