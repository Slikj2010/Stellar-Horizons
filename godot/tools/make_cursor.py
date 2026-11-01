"""Draws the game's mouse pointers into assets/cursors/ as sprite sheets (24 frames of 48x48, side by side).
  arrow.png : steel-blue swept ship pointer with a little orbiting-moon emblem (the normal pointer)
  hover.png : the same pointer dark with an amber edge, over buttons and ships
  busy.png  : planet with two orbit rings and two moons going round (loading)
  move / hsize / vsize : single frames, the ship pointer with a badge
Run: python3 tools/make_cursor.py"""
from PIL import Image, ImageDraw, ImageFilter
import math, os
S = 8
N = 48
F = 24
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "cursors")
os.makedirs(OUT, exist_ok=True)

def P(pts): return [(x * S, y * S) for x, y in pts]
def circ(d, c, r, **kw): d.ellipse(((c[0] - r) * S, (c[1] - r) * S, (c[0] + r) * S, (c[1] + r) * S), **kw)

def glow(big, draw_fn, radius, alpha=.7):
    g = Image.new("RGBA", big.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(g))
    g = g.filter(ImageFilter.GaussianBlur(radius * S))
    g.putalpha(g.split()[3].point(lambda v: int(v * alpha)))
    return Image.alpha_composite(big, g)

def emblem(big, c, k, scale=1.0, planet=(255, 150, 60), ring=(190, 235, 255), moons=((1, 0.0, 1.0),)):
    """a planet with orbit rings and moons. moons: (ring index, phase, direction*speed)"""
    d = ImageDraw.Draw(big)
    radii = [6.2 * scale, 10.5 * scale]
    for r in radii:
        circ(d, c, r, outline=ring + (150,), width=int(.8 * S))
    big = glow(big, lambda g: circ(g, c, 3 * scale, fill=planet + (255,)), 1.2 * scale, .9)
    d = ImageDraw.Draw(big)
    circ(d, c, 2.7 * scale, fill=planet + (255,))
    circ(d, (c[0] - .8 * scale, c[1] - .9 * scale), 1.0 * scale, fill=(255, 230, 190, 255))
    for ri, ph, sp in moons:
        a = 2 * math.pi * (k / F * sp) + ph
        r = radii[ri]
        m = (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r)
        big = glow(big, lambda g: circ(g, m, 1.6 * scale, fill=(120, 255, 220, 255)), .9 * scale, .9)
        d = ImageDraw.Draw(big)
        circ(d, m, 1.35 * scale, fill=(190, 255, 240, 255))
    return big

def ship(big, accent, dark=False):
    A, B, C, D, E_ = (3, 3), (31, 17), (18.5, 20), (15.5, 37), (10, 22)
    outline = [A, B, C, D, E_]
    big = glow(big, lambda g: g.polygon(P(outline), fill=accent + (255,)), 2.4, .75)
    d = ImageDraw.Draw(big)
    ridge = (14, 22)
    if dark:
        cols = [(24, 44, 62), (16, 32, 48), (10, 20, 34), (20, 38, 56)]
    else:
        cols = [(150, 186, 222), (62, 104, 166), (26, 52, 98), (84, 126, 186)]
    d.polygon(P([A, ridge, E_]), fill=cols[0] + (255,))
    d.polygon(P([A, B, C, ridge]), fill=cols[1] + (255,))
    d.polygon(P([ridge, C, D]), fill=cols[2] + (255,))
    d.polygon(P([ridge, D, E_]), fill=cols[3] + (255,))
    d.line(P(outline + [A]), fill=accent + (255,), width=int(1.9 * S), joint="curve")
    d.line(P([A, B]), fill=(255, 240, 220, 255) if dark else (232, 246, 255, 255), width=int(.9 * S))
    d.line(P([A, E_]), fill=(255, 225, 190, 255) if dark else (214, 236, 255, 255), width=int(.8 * S))
    e = Image.new("RGBA", big.size, (0, 0, 0, 0))
    ImageDraw.Draw(e).ellipse(((D[0] - 2.4) * S, (D[1] - 3.4) * S, (D[0] + 2.4) * S, (D[1] + 1.2) * S), fill=(255, 140, 50, 255))
    big = Image.alpha_composite(big, e.filter(ImageFilter.GaussianBlur(1.3 * S)))
    d = ImageDraw.Draw(big)
    circ(d, A, 1.5, fill=(255, 255, 255, 255))
    return big

def badge(big, cx, cy, dirs, r=6.5, w=1.5):
    d = ImageDraw.Draw(big)
    for dx, dy in dirs:
        tip = (cx + dx * r, cy + dy * r)
        px, py = -dy, dx
        base = (cx + dx * (r - 3.2), cy + dy * (r - 3.2))
        d.line(P([(cx, cy), base]), fill=(225, 238, 250, 255), width=int(w * S))
        d.polygon(P([tip, (base[0] + px * 2.6, base[1] + py * 2.6), (base[0] - px * 2.6, base[1] - py * 2.6)]), fill=(225, 238, 250, 255))
    return big

def frame(kind, k):
    big = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))
    if kind == "arrow":
        big = ship(big, (70, 205, 255))
        big = emblem(big, (37, 37), k, .78)
    elif kind == "hover":
        big = ship(big, (255, 150, 60), dark=True)
        big = emblem(big, (37, 37), k, .78, planet=(70, 205, 255), ring=(255, 220, 170), moons=((1, 0.0, 1.0),))
    elif kind == "busy":
        big = emblem(big, (24, 24), k, 1.5, moons=((0, 0.0, 1.0), (1, 2.0, -1.0)))
    return big.resize((N, N), Image.LANCZOS)

for kind in ["arrow", "hover", "busy"]:
    sheet = Image.new("RGBA", (N * F, N), (0, 0, 0, 0))
    for k in range(F): sheet.paste(frame(kind, k), (k * N, 0))
    sheet.save(os.path.join(OUT, kind + ".png"))

def single(name, dirs, cx, cy):
    big = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))
    big = ship(big, (70, 205, 255))
    big = badge(big, cx, cy, dirs)
    big.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
single("move", [(1, 0), (-1, 0), (0, 1), (0, -1)], 36, 36)
single("hsize", [(1, 0), (-1, 0)], 37, 34)
single("vsize", [(0, 1), (0, -1)], 37, 34)
