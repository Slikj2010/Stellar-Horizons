"""Draws the game's mouse pointers (assets/cursor_*.png): a swept delta-wing "ship" pointer in steel blue with a cyan edge light
and a small orange engine glow; the hand version glows orange with an orbit ring. Run: python3 tools/make_cursor.py"""
from PIL import Image, ImageDraw, ImageFilter
import os
S = 8
N = 44
OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

def poly(pts): return [(x * S, y * S) for x, y in pts]

def ship(accent, hot=False, badge=None):
    big = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))
    A, B, C, D, E_ = (3, 3), (31, 17), (18.5, 20), (15.5, 37), (10, 22)
    outline = [A, B, C, D, E_]
    # soft glow behind
    g = Image.new("RGBA", big.size, (0, 0, 0, 0))
    dg = ImageDraw.Draw(g)
    dg.polygon(poly(outline), fill=accent + (255,))
    if hot: dg.ellipse(((16 - 15) * S, (19 - 15) * S, (16 + 15) * S, (19 + 15) * S), outline=accent + (255,), width=int(1.4 * S))
    g = g.filter(ImageFilter.GaussianBlur(2.4 * S))
    g.putalpha(g.split()[3].point(lambda v: int(v * .75)))
    big = Image.alpha_composite(big, g)
    d = ImageDraw.Draw(big)
    # two facets split along the nose-to-tail ridge: left facet light steel, right facet deep blue
    ridge = (14, 22)
    d.polygon(poly([A, ridge, E_]), fill=(150, 186, 222, 255))      # upper-left
    d.polygon(poly([A, B, C, ridge]), fill=(62, 104, 166, 255))      # upper-right wing
    d.polygon(poly([ridge, C, D]), fill=(26, 52, 98, 255))           # right lower
    d.polygon(poly([ridge, D, E_]), fill=(84, 126, 186, 255))        # left lower
    # edge light and white nose highlight
    d.line(poly(outline + [A]), fill=accent + (255,), width=int(1.8 * S), joint="curve")
    d.line(poly([A, B]), fill=(232, 246, 255, 255), width=int(.9 * S))
    d.line(poly([A, E_]), fill=(214, 236, 255, 255), width=int(.8 * S))
    # engine glow at the tail
    e = Image.new("RGBA", big.size, (0, 0, 0, 0))
    ImageDraw.Draw(e).ellipse(((D[0] - 2.4) * S, (D[1] - 3.4) * S, (D[0] + 2.4) * S, (D[1] + 1.2) * S), fill=(255, 140, 50, 255))
    e = e.filter(ImageFilter.GaussianBlur(1.3 * S))
    big = Image.alpha_composite(big, e)
    d = ImageDraw.Draw(big)
    d.ellipse(((A[0] - 1.5) * S, (A[1] - 1.5) * S, (A[0] + 1.5) * S, (A[1] + 1.5) * S), fill=(255, 255, 255, 255))
    if hot:
        ring = Image.new("RGBA", big.size, (0, 0, 0, 0))
        ImageDraw.Draw(ring).ellipse(((16 - 15) * S, (19 - 15) * S, (16 + 15) * S, (19 + 15) * S), outline=accent + (200,), width=int(.9 * S))
        big = Image.alpha_composite(big, ring)
        d = ImageDraw.Draw(big)
    if badge: badge(d)
    return big.resize((N, N), Image.LANCZOS)

def arrows(cx, cy, dirs, r=6.5, w=1.5):
    def badge(d):
        for dx, dy in dirs:
            tip = (cx + dx * r, cy + dy * r)
            px, py = -dy, dx
            base = (cx + dx * (r - 3.2), cy + dy * (r - 3.2))
            head = [tip, (base[0] + px * 2.6, base[1] + py * 2.6), (base[0] - px * 2.6, base[1] - py * 2.6)]
            d.line(poly([(cx, cy), base]), fill=(225, 238, 250, 255), width=int(w * S))
            d.polygon(poly(head), fill=(225, 238, 250, 255))
    return badge

def save(img, name): img.save(os.path.join(OUT, name))

save(ship((70, 205, 255)), "cursor_arrow.png")
save(ship((255, 150, 70), hot=True), "cursor_point.png")
save(ship((70, 205, 255), badge=arrows(31, 31, [(1, 0), (-1, 0), (0, 1), (0, -1)])), "cursor_move.png")
save(ship((70, 205, 255), badge=arrows(32, 30, [(1, 0), (-1, 0)])), "cursor_hsize.png")
save(ship((70, 205, 255), badge=arrows(32, 30, [(0, 1), (0, -1)])), "cursor_vsize.png")
