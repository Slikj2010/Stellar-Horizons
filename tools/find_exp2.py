import cv2, numpy as np, json
from PIL import Image, ImageDraw
z = json.load(open('zones.json'))
ZN = {"Mercury's exploration": 'mer', "Venus's Exploration": 'ven', 'Near Earth Asteroids Exploration': 'nea', "Moon's Exploration": 'moo', "Mar's Exploration": 'mar',
 'Comet Exploration': 'com', 'Phobos - Deimos Exploration': 'pho', "Ceres's Exploration": 'cer', 'Hygeia - Pallas Exploration': 'hyg', "Vesta's Exploration": 'ves',
 "Jupiter's Exploration": 'jup', "Io's Exploration": 'io', "Europa's Exploration": 'eur', "Callisto's Exploration": 'cal', 'Trojans &amp; Greeks Exploration': 'tro',
 "Saturn's Exploration": 'sat', 'Mimas - Enceladus - Tethys Exploration': 'mim', 'Dione - Rhea Exploration': 'dio', "Titan's Exploration": 'tit', 'Hyperion - Iapetus Exploration': 'hyp',
 "Uranus's Exploration": 'ura', "Chariklo's Exploration": 'cha', 'Oberion - Titania Exploration': 'obe', 'Umbriel - Ariel - Miranda Exploration': 'umb', 'Neptune Exploration': 'nep',
 "Triton's Exploration": 'tri', 'Kuiper Belt Exploration': 'kui', 'Haumea - Makemake Exploration': 'hau', 'Pluto - Charon Exploration': 'plu', "Sedna's Exploration": 'sed',
 'Eris &amp; Dysnomia Exploration': 'eri', 'Deep Space Astronomy Exploration': 'dsa', 'Alpha Centauri Exploration': 'alp'}
regions = {}
for b, zs in z.items():
    for n, p in zs:
        if n in ZN and len(p) >= 3:
            xs = [q[0] for q in p]; ys = [q[1] for q in p]; regions[ZN[n]] = (b[-1], min(xs), min(ys), max(xs), max(ys))
regions['ear'] = ('B', 790, 1080, 1000, 1290)
regions['gan'] = None
regions['gal'] = ('G', 2160, 2180, 2330, 2350)
# Ganymede exploration zone had no points: find from map D around its world box (left of Ganymede circle)
regions['gan'] = ('D', 3640, 2090, 3760, 2210)
regions['dsa'] = ('I', 275, 905, 405, 1035)
out = {}; sheet = []
cache = {}
for k, reg in regions.items():
    c, x0, y0, x1, y1 = reg
    if c not in cache: cache[c] = cv2.imread('vm/images/Map %s4200.jpg' % c)
    im = cache[c]
    x0 -= 12; y0 -= 12; x1 += 12; y1 += 12
    crop = im[y0:y1, x0:x1]
    hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV).astype(int)
    b, g, r = [crop[..., i].astype(int) for i in range(3)]
    purple = (r - g > 40) & (b - g > 40) & (g < 110)
    sel = (hsv[..., 2] > 95) & ~purple
    sel = cv2.morphologyEx(sel.astype(np.uint8) * 255, cv2.MORPH_OPEN, np.ones((7, 7), np.uint8))
    sel = cv2.morphologyEx(sel, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    n, lab, st, cen = cv2.connectedComponentsWithStats(sel)
    if n < 2: print('MISS', k); continue
    kk = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
    ys, xs = np.nonzero(lab == kk)
    (cx, cy), (w, h), ang = cv2.minAreaRect(np.c_[xs, ys].astype(np.float32))
    ang = ((ang + 45) % 90) - 45
    s = (w + h) / 2
    # hub colour: pixels within 0.32*s of centre that are mid-luminance
    yy, xx = np.mgrid[0:crop.shape[0], 0:crop.shape[1]]
    d = np.hypot(xx - cx, yy - cy)
    rgb = crop[..., ::-1].astype(int); lum = rgb.mean(2)
    ring = (d < s * .3) & (lum > 45) & (lum < 200)
    hub = np.median(rgb[ring], axis=0) if ring.sum() > 20 else np.array([90, 90, 90])
    # orientation: the EXPLORE label sits on the box's top side
    lbl = (d > s * .62) & (d < s * 1.05) & (lum > 150) & ~purple
    if lbl.sum() > 30:
        lx, ly = xx[lbl].mean(), yy[lbl].mean(); up = np.degrees(np.arctan2(lx - cx, -(ly - cy)))
        cands = [ang + 90 * j for j in range(-2, 3)]; ang = min(cands, key=lambda a: abs(((a - up + 180) % 360) - 180))
    out[k] = {'map': c, 'cx': round(x0 + cx, 1), 'cy': round(y0 + cy, 1), 's': round(s, 1), 'ang': round(float(ang), 1), 'hub': [int(v) for v in hub]}
    v = Image.fromarray(crop[..., ::-1].copy()); dd = ImageDraw.Draw(v)
    box = cv2.boxPoints(((cx, cy), (w, h), ang)); dd.polygon([tuple(p) for p in box], outline=(255, 0, 0)); dd.ellipse((cx - s * .3, cy - s * .3, cx + s * .3, cy + s * .3), outline=tuple(int(x) for x in hub), width=6)
    v.thumbnail((170, 170)); sheet.append((k, v))
json.dump(out, open('site/expbox.json', 'w'))
print(len(out), sorted(set(regions) - set(out)))
W = 175; S = Image.new('RGB', (W * 9, (W + 14) * 4), 'black'); D = ImageDraw.Draw(S)
for i, (k, v) in enumerate(sheet): S.paste(v, ((i % 9) * W, (i // 9) * (W + 14) + 12)); D.text(((i % 9) * W, (i // 9) * (W + 14)), k, fill=(255, 255, 0))
S.save('exp_check.png')
