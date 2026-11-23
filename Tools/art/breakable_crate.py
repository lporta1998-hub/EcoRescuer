"""The breakable crate that seals a secret passage (Misc/Secrets/). It must
not look like the decorative crates of the factory, harbor, lake and data
center props: a single pale pine crate split by a big crack, with splinters
and a painted green leaf, the eco sign that something is behind it.
    python3 breakable_crate.py OUT.png"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vol import Canvas, rbox, poly, ramp, hexc
from props import grounded


def crate():
    c = Canvas(20, 21, {k: ramp(hexc(v)) for k, v in
                        dict(wood="#e0a85a", lid="#f0c27a", dark="#6a3c1a", leaf="#5ad04a").items()})
    c.add(rbox("wood", 1, 1, 5, 18, 20, rad=1.0))          # front
    c.add(rbox("lid", 1.4, 1, 1, 18, 6, rad=1.0, depth=0.5))  # top
    for y in (10, 15):                                       # planks
        for x in range(2, 18):
            c.dot(x, y, "wood", 1)
    for x in (2, 17):                                        # corner posts
        for y in range(6, 20):
            c.dot(x, y, "wood", 2)
    # painted leaf
    c.add(poly("leaf", 2, [(12, 8), (16, 9), (15, 13), (12, 13)], depth=0.3))
    for (x, y) in ((12, 13), (13, 12), (14, 11)):
        c.dot(x, y, "leaf", 1)
    im = c.render()
    px = im.load()
    # the crack: a jagged split from the lid to the base, splinters beside it
    crack = [(8, 1), (8, 2), (9, 3), (9, 4), (8, 5), (8, 6), (9, 7), (10, 8), (10, 9), (9, 10), (9, 11),
             (10, 12), (10, 13), (11, 14), (10, 15), (10, 16), (9, 17), (9, 18), (10, 19)]
    for (x, y) in crack:
        px[x, y] = (34, 18, 10, 255)
    for (x, y) in ((7, 3), (10, 6), (11, 9), (8, 11), (11, 12), (12, 15), (8, 17), (11, 18)):
        px[x, y] = (255, 236, 190, 255)
    for (x, y) in ((6, 8), (5, 9), (12, 17), (13, 18)):   # small side cracks
        px[x, y] = (70, 36, 16, 255)
    return grounded(im)


if __name__ == "__main__":
    crate().save(sys.argv[1])
