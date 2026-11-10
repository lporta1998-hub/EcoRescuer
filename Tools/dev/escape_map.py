# Generates Levels/Escape_level/map.txt, the chapter 10 map (see
# Misc/Builder/built_level.gd for the legend). Edit the positions below and run:
#   python3 Tools/dev/escape_map.py            (writes the map, prints it)
# then check it with Tools/dev/check_reachable.gd.
import sys, os
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'Levels', 'Escape_level', 'map.txt')
W, H = 100, 64
g = [['.'] * W for _ in range(H)]
def put(x, y, c): g[y][x] = c
def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = c
def building(x0, y0, x1, y1, door):
    # walls with a floor inside and a 3-wide door in the bottom wall at column `door`
    rect(x0, y0, x1, y1, '#')
    rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, ',')
    for x in range(door, door + 3):
        put(x, y1, ',')

# --- arena on the north pier (like the Fortress): walls, gate, boss, station
rect(0, 0, W - 1, 25, '#')
rect(30, 4, 69, 22, ',')
for y in range(4, 23):          # diagonal paving like the fortress arena
    for x in range(30, 70):
        if (x + y) % 9 == 0:
            put(x, y, '_')
for x in range(47, 53):
    put(x, 23, ','); put(x, 24, 'G'); put(x, 25, ',')
put(50, 9, 'Z')
put(50, 18, 'S')
for x, y in [(33, 6), (66, 6), (33, 20), (66, 20)]:
    put(x, y, 'X')

# --- the docks
rect(0, 26, 3, H - 1, '&'); rect(W - 4, 26, W - 1, H - 1, '&')
rect(4, 26, W - 5, 27, '.')
# water along the south with two bridges to small piers
rect(4, 52, W - 5, H - 1, '~')
rect(4, 51, 30, 51, '~'); rect(70, 51, W - 5, 51, '~')
rect(20, 51, 22, 56, '=')
rect(12, 57, 30, 61, '.'); rect(14, 58, 28, 60, ',')
rect(76, 51, 78, 55, '=')
rect(66, 56, 88, 61, '.'); rect(68, 57, 86, 60, ',')
for x, y in [(8, 55), (40, 58), (55, 62), (92, 58), (60, 54)]:
    put(x, y, 'b')
# main road
rect(4, 48, W - 5, 49, ','); rect(48, 26, 51, 48, ',')
for x in range(6, W - 5, 7):
    put(x, 48, '_')
# warehouses
building(8, 30, 24, 39, 15)
building(64, 30, 82, 37, 72)
building(34, 38, 46, 46, 39)
building(54, 39, 62, 46, 57)
# containers, crates, bollards, lamps
for x in range(28, 46, 4):
    put(x, 29, 'T')
for x in range(56, 64, 4):
    put(x, 29, 'T')
for x, y in [(86, 40), (90, 40), (84, 44), (88, 44), (6, 42), (26, 44), (30, 33), (40, 33), (58, 33), (92, 32)]:
    put(x, y, 'T')
for x, y in [(12, 44), (20, 45), (44, 50), (70, 45), (82, 46), (90, 41), (28, 37), (52, 35), (11, 33), (77, 33)]:
    put(x, y, 'x')
for x, y in [(10, 50), (30, 50), (60, 50), (88, 50), (17, 57), (25, 61), (70, 57), (85, 61)]:
    put(x, y, 'X')
for x, y in [(7, 28), (25, 28), (46, 30), (54, 30), (74, 28), (93, 28), (35, 50), (66, 50)]:
    put(x, y, 'O')
for x, y in [(15, 47), (32, 46), (68, 47), (86, 47)]:
    put(x, y, 'o')

# --- things
put(9, 47, 'P')
bags = [(11, 32), (80, 35), (40, 40), (60, 44), (93, 46), (20, 59), (82, 58)]
enemies = [(18, 35), (70, 33), (38, 44), (59, 41), (30, 41), (75, 44), (90, 34), (24, 59), (72, 59), (56, 28)]
elites = [(44, 31), (86, 38)]
coins = [(14, 36), (22, 33), (66, 32), (79, 31), (36, 39), (44, 45), (56, 41), (61, 45), (28, 47), (94, 30),
         (16, 58), (27, 58), (69, 60), (86, 57), (50, 30), (8, 43)]
for x, y in bags: put(x, y, 'B')
for x, y in enemies: put(x, y, 'E')
for x, y in elites: put(x, y, 'L')
for x, y in coins: put(x, y, 'C')
for x, y in [(21, 37), (66, 35), (91, 49)]: put(x, y, 'H')
put(42, 35, 'F')
for x, y in [(33, 31), (72, 41), (18, 60)]:
    put(x, y, 'R')
put(74, 58, 'R')
put(13, 37, 'K'); put(78, 34, 'K')
put(29, 60, 'D')

# --- secret room in the wall block west of the arena: a corridor from the
# docks, closed by crates (V), to a small store room with the relic (Y)
rect(8, 8, 20, 13, ',')
rect(14, 14, 15, 25, ',')
put(14, 25, 'V'); put(15, 25, 'V')
put(10, 9, 'Y')
put(18, 12, 'x')

out = '\n'.join(''.join(r) for r in g) + '\n'
open(sys.argv[1] if len(sys.argv) > 1 else OUT, 'w').write(out)
print(out)
