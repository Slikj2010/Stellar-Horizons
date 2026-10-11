import json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
z = json.load(open('zones.json'))
Z = {}
for b, zs in z.items():
    for n, p in zs:
        if len(p) >= 3: Z[n.replace('&amp;', '&')] = (b[-1], p)
B = {  # key: (zone name, search radius in source px)
 'mer': ('Mercury Orbit (severe radiation)', 200), 'ven': ('Venus Orbit', 200), 'ear': ('Earth Orbit', 200), 'moo': ('Luna Orbit', 160),
 'mar': ('Mars Orbit', 160), 'cer': ('Ceres', 150), 'jup': ('Jupiter Orbit', 420), 'io': ('Io (Severe radiation)', 140), 'eur': ('Europa (Severe radiation)', 140),
 'gan': ('Ganymede', 140), 'cal': ('Callisto Orbit', 140), 'sat': ('Saturn Orbit', 460), 'tit': ('Titan', 140), 'ura': ('Uranus Orbit', 420), 'nep': ('Neptune', 420), 'tri': ('Triton', 140),
}
out = {}; sheet = []
for k, (zn, R) in B.items():
    c, pts = Z[zn]
    im = np.asarray(Image.open('vm/images/Map %s4200.jpg' % c).convert('RGB')).astype(int)
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    x0, y0 = int(cx - R), int(cy - R)
    crop = im[max(0, y0):int(cy + R), max(0, x0):int(cx + R)]
    x0, y0 = max(0, x0), max(0, y0)
    g = crop.max(2)
    m = g > 60
    m = ndimage.binary_opening(m, iterations=2)
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    best = None
    for i in range(1, n + 1):
        yy, xx = np.nonzero(lab == i)
        if len(xx) < 200: continue
        mx, my = xx.mean(), yy.mean()
        d = np.hypot(mx - (cx - x0), my - (cy - y0))
        h, w = np.ptp(yy) + 1, np.ptp(xx) + 1
        round_ = min(h, w) / max(h, w)
        fill = len(xx) / (np.pi * (max(h, w) / 2) ** 2)
        score = len(xx) * round_ * min(1, fill) / (1 + d / 60)
        if best is None or score > best[0]: best = (score, mx, my, (h + w) / 4, round_, fill)
    _, mx, my, r, rd, fl = best
    out[k] = {'map': c, 'cx': round(mx + x0, 1), 'cy': round(my + y0, 1), 'r': round(r, 1), 'round': round(rd, 2), 'fill': round(fl, 2)}
    v = Image.fromarray(crop.astype('uint8')); d = ImageDraw.Draw(v); d.ellipse((mx - r, my - r, mx + r, my + r), outline=(0, 255, 0), width=3)
    v.thumbnail((260, 260)); sheet.append((k, v))
json.dump(out, open('bodies.json', 'w'), indent=1)
for k, v in out.items(): print(k, v)
S = Image.new('RGB', (260 * 8, 280 * 2), 'black'); D = ImageDraw.Draw(S)
for i, (k, v) in enumerate(sheet):
    S.paste(v, ((i % 8) * 260, (i // 8) * 280 + 18)); D.text(((i % 8) * 260 + 4, (i // 8) * 280 + 2), k, fill=(255, 255, 0))
S.save('bodies_check.png')
