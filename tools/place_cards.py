"""Find a spot for each world's card + base row, lined up under its printed World Box (in the box's own tilt),
covering no printed text or lines. Usage: python3 tools/place_cards.py [--write]
Writes geo.json worlds[w].wcard = [cx, cy, angle_deg, card_w] (card centre, world units) when --write."""
import json, math, sys
import numpy as np
from PIL import Image
from scipy import ndimage
geo = json.load(open('geo.json')); exp = json.load(open('expbox.json'))
D_NOCARD = {'sun', 'dsa', 'alp'}
CW = 230; CH = CW * 127 / 192; BS = 72; GAP = 14
BLOCK_H = CH + GAP + BS + 8          # card, then a row of bases with trade markers
LS = 56; BOFF = (LS + 10) / 2
BLOCK_W = CW + LS + 10  # card + life marker to its right; two bases with trade markers fit under it
# content mask over the whole board, 1 px = 1 world unit
PAD = 700  # empty space around the board counts as free
W = int(max(m[0] + m[2] for m in geo['maps'].values())) + 2 * PAD; H = int(max(m[1] + m[3] for m in geo['maps'].values())) + 2 * PAD
mask = np.zeros((H + 1, W + 1), bool)
for c, (x, y, w, h) in geo['maps'].items():
    a = np.asarray(Image.open(f'maps/{c}.webp').convert('RGBA'))[..., 3]
    x, y = int(round(x)) + PAD, int(round(y)) + PAD
    mask[y:y + a.shape[0], x:x + a.shape[1]] |= a > 70
mask = ndimage.binary_dilation(mask, iterations=10)  # keep a little clear space around printed art
taken = np.zeros_like(mask)
def rect_pts(cx, cy, a, w, h, step=3):
    us = np.arange(-w / 2, w / 2 + 1, step); vs = np.arange(-h / 2, h / 2 + 1, step)
    U, V = np.meshgrid(us, vs); ca, sa = math.cos(a), math.sin(a)
    return (cx + U * ca - V * sa).round().astype(int), (cy + U * sa + V * ca).round().astype(int)
def cost(cx, cy, a, w, h):
    X, Y = rect_pts(cx, cy, a, w, h)
    out = (X < 0) | (Y < 0) | (X > W) | (Y > H)
    Xc, Yc = X.clip(0, W), Y.clip(0, H)
    return int(mask[Yc, Xc].sum() + taken[Yc, Xc].sum() * 5), int(out.sum())
res = {}; report = []
order = sorted([k for k in geo['worlds'] if k not in D_NOCARD and k in exp], key=lambda k: (abs(exp[k]['ang']) < 30, k))  # tilted planet boxes first
for k in order:
    e = exp[k]; m = geo['maps'][e['map']]
    ex, ey, a = m[0] + e['cx'] * .4 + PAD, m[1] + e['cy'] * .4 + PAD, math.radians(e['ang'])
    ca, sa = math.cos(a), math.sin(a)
    best = None
    for ly in range(40, 330, 6):
        for lx in range(-40, 160, 8):
            # block centre in local frame: card top-left anchored so the card centre is (lx, ly + CH/2)
            bcx, bcy = lx + BOFF, ly + BLOCK_H / 2
            cx, cy = ex + bcx * ca - bcy * sa, ey + bcx * sa + bcy * ca
            c, out = cost(cx, cy, a, BLOCK_W, BLOCK_H)
            score = c * 3 + out * 50 + ly * 0.6 + abs(lx - 50) * 0.5
            if best is None or score < best[0]: best = (score, c, out, lx, ly)
        if best and best[1] == 0 and best[2] == 0 and ly > best[4] + 60: break
    sc, c, out, lx, ly = best
    ccx, ccy = lx, ly + CH / 2
    res[k] = [round(ex + ccx * ca - ccy * sa - PAD, 1), round(ey + ccx * sa + ccy * ca - PAD, 1), e['ang'], CW]
    bcx, bcy = lx + BOFF, ly + BLOCK_H / 2
    bx, by, ba = ex + bcx * ca - bcy * sa, ey + bcx * sa + bcy * ca, a
    if c > 0:
        # no room under the World Box (another world sits below): beside the world circle instead, upright, beyond the orbit ring
        g = geo['worlds'][k]; P = g['poly']; xs = [q[0] for q in P]; ys = [q[1] for q in P]
        wc = ((min(xs) + max(xs)) / 2 + PAD, (min(ys) + max(ys)) / 2 + PAD); rr = g.get('circ', 120) + 80
        sb = None
        for side in (1, -1):
            for dy in range(-140, 141, 10):
                bx2 = wc[0] + side * (rr + BLOCK_W / 2); by2 = wc[1] + dy + BLOCK_H / 2 - CH / 2
                c2, o2 = cost(bx2, by2, 0, BLOCK_W, BLOCK_H)
                sc2 = c2 * 3 + abs(dy) * .3 + (side < 0) * 20
                if sb is None or sc2 < sb[0]: sb = (sc2, c2, bx2, by2)
        if sb[1] < c:
            c = sb[1]; bx, by, ba = sb[2], sb[3], 0
            res[k] = [round(bx - BOFF - PAD, 1), round(by - BLOCK_H / 2 + CH / 2 - PAD, 1), 0, CW]
            lx, ly = 'side', 0
    X, Y = rect_pts(bx, by, ba, BLOCK_W + 20, BLOCK_H + 20, 1)
    ok = (X >= 0) & (Y >= 0) & (X <= W) & (Y <= H); taken[Y[ok], X[ok]] = True
    report.append((k, c, out, lx, ly))
for r in report: print('%-4s cover=%-5d outside=%-4d local=(%s,%s)' % r)
if '--write' in sys.argv:
    for k, v in res.items(): geo['worlds'][k]['wcard'] = v
    json.dump(geo, open('geo.json', 'w'), separators=(',', ':')); print('written')
if '--debug' in sys.argv:
    from PIL import ImageDraw
    big = Image.new('RGB', (W + 1, H + 1))
    for c, (x, y, w, h) in geo['maps'].items(): big.paste(Image.open(f'maps/{c}.webp').convert('RGB'), (int(round(x)) + PAD, int(round(y)) + PAD))
    d = ImageDraw.Draw(big)
    for k, (cx, cy, ang, cw) in res.items():
        cx += PAD; cy += PAD; a = math.radians(ang); ca, sa = math.cos(a), math.sin(a)
        for (w, h, oy, col, ox) in [(CW, CH, 0, (255, 200, 0), 0), (BLOCK_W, BS, CH / 2 + GAP + BS / 2, (0, 200, 255), BOFF), (LS, LS, 0, (0, 255, 0), CW / 2 + 10 + LS / 2)]:
            pts = [(cx + (u + ox) * ca - (v + oy) * sa, cy + (u + ox) * sa + (v + oy) * ca) for u, v in [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]]
            d.polygon(pts, outline=col, width=4)
        d.text((cx, cy), k, fill=(255, 0, 0))
    big.save(sys.argv[-1])
