"""Graphics assets: transparent map sections (baked starfield and legend box removed) and spin textures for planets/moons.
Usage: python3 -I build_fx.py <vm_dir> <site_dir> <bodies.json>"""
import sys, os, json, math
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

VM, SITE, BODIES = sys.argv[1:4]
IMG = os.path.join(VM, 'images')
SC = 0.4

# ---------- maps with alpha ----------
LEGEND = ('A', (2540, 2500, 4054, 3360))
for c in 'ABCDEFGHI':
    im = Image.open(os.path.join(IMG, 'Map %s4200.jpg' % c)).convert('RGB')
    a = np.asarray(im).astype(np.int16)
    mx = a.max(2); mn = a.min(2); sat = mx - mn
    bright = mx > 42
    lab, n = ndimage.label(bright, structure=np.ones((3, 3)))
    idx = np.arange(1, n + 1)
    area = ndimage.sum(bright, lab, idx)
    msat = ndimage.mean(sat, lab, idx)
    sl = ndimage.find_objects(lab)
    dims = np.array([max(s[0].stop - s[0].start, s[1].stop - s[1].start) for s in sl])
    big = (area >= 160) | ((msat > 45) & (area >= 12)) | (dims >= 22)
    keep_lab = np.zeros(n + 1, bool); keep_lab[1:] = big
    core = keep_lab[lab]
    # small things (text letters, dots) count only near real content
    near = ndimage.binary_dilation(core, iterations=40)
    keep = core | (bright & near)
    keep = ndimage.binary_dilation(keep, iterations=6)
    km = Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))
    km = np.asarray(km).astype(np.float32) / 255
    ramp = np.clip((mx.astype(np.float32) - 20) / 34, 0, 1)
    alpha = (ramp * km)
    if c == LEGEND[0]:
        x0, y0, x1, y1 = LEGEND[1]; alpha[y0:y1, x0:x1] = 0
    out = np.dstack([a.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    o = Image.fromarray(out, 'RGBA')
    w, h = o.size
    o = o.resize((round(w * SC), round(h * SC)), Image.LANCZOS)
    o.save(os.path.join(SITE, 'maps', c + '.webp'), 'WEBP', quality=74, method=6)
    print('map', c, 'kept %.1f%%' % (100 * alpha.mean()))

# ---------- spinning bodies ----------
B = json.load(open(BODIES))
# hand-measured overrides (source px)
B['jup'].update(cx=2347, cy=1222, r=536)
B['sat'].update(cx=1561, cy=1262, r=215)
B['nep'].update(cx=1374, cy=1232, r=285)
SPEED = {'mer': 160, 'ven': -260, 'ear': 70, 'moo': 140, 'mar': 75, 'cer': 90, 'jup': 38, 'io': 110, 'eur': 120, 'gan': 130, 'cal': 140,
         'sat': 44, 'tit': 150, 'ura': -58, 'nep': 52, 'tri': -150}  # seconds per turn, negative = retrograde
TW, TH, DS = 256, 128, 128  # strip size, disc map size
keys = list(B.keys())
atlas = Image.new('RGBA', (TW + DS, TH * len(keys)), (0, 0, 0, 0))
meta = {}
mapoff = {}
for k in keys:
    b = B[k]; c = b['map']; cx, cy, r = float(b['cx']), float(b['cy']), float(b['r'])
    im = np.asarray(Image.open(os.path.join(IMG, 'Map %s4200.jpg' % c)).convert('RGB')).astype(np.float32)
    R = int(math.ceil(r)) + 2
    crop = im[int(cy) - R:int(cy) + R, int(cx) - R:int(cx) + R]
    yy, xx = np.mgrid[0:2 * R, 0:2 * R]
    u = (xx + .5 - (cx - (int(cx) - R))) / r; v = (yy + .5 - (cy - (int(cy) - R))) / r
    d = np.hypot(u, v); inside = d < 0.985
    L = crop.mean(2)
    Lb = ndimage.gaussian_filter(np.where(inside, L, 0), r / 5) / np.maximum(ndimage.gaussian_filter(inside.astype(np.float32), r / 5), 1e-3)
    lit = inside & (Lb > 0.45 * Lb[inside].max())
    ref = np.median(Lb[lit])
    flat = crop * (ref / np.maximum(Lb, ref * .35))[..., None]
    flat = np.clip(flat, 0, 255)
    # spin mask: sphere pixels, minus rings that cross in front
    mask = inside.copy()
    if k == 'nep':
        ring = (crop[..., 2] - crop[..., 0] < 70) & (L > 110)
        mask &= ~ndimage.binary_dilation(ring, iterations=3)
    if k == 'sat':
        mask &= (v < 0.8)
    # equirectangular strip from the well-lit front hemisphere (mirrored round the back)
    lon = (np.arange(TW) + .5) / TW * 2 * math.pi - math.pi
    lat = (np.arange(TH) + .5) / TH * math.pi - math.pi / 2
    LON, LAT = np.meshgrid(lon, lat)
    # far side = second copy of the near side, cross-faded at the two seams (no mirroring)
    def samp(f):
        fs = np.clip(f * (70 / 90), -math.pi / 2, math.pi / 2)
        su = 0.9 * np.cos(LAT) * np.sin(fs); sv = 0.9 * np.sin(LAT)
        sx = (cx - (int(cx) - R)) + su * r - .5; sy = (cy - (int(cy) - R)) + sv * r - .5
        return np.dstack([ndimage.map_coordinates(flat[..., ch], [sy, sx], order=1, mode='nearest') for ch in range(3)])
    wrap = lambda x: (x + math.pi) % (2 * math.pi) - math.pi
    fa = wrap(LON); fb = wrap(LON - math.pi)
    def w(f):
        t = np.clip((np.degrees(np.abs(f)) - 70) / 40, 0, 1); return 1 - t * t * (3 - 2 * t)
    wa, wb = w(fa), w(fb); tot = np.maximum(wa + wb, 1e-6)
    strip = (samp(fa) * (wa / tot)[..., None] + samp(fb) * (wb / tot)[..., None])
    # disc map: R = shading (Lb / ref), A = spin mask, sampled to DS x DS over [-1,1]
    g = (np.arange(DS) + .5) / DS * 2 - 1
    GX, GY = np.meshgrid(g, g)
    px = (cx - (int(cx) - R)) + GX * r - .5; py = (cy - (int(cy) - R)) + GY * r - .5
    shade = ndimage.map_coordinates(np.clip(Lb / ref, 0, 1.6) / 1.6, [py, px], order=1, mode='nearest')
    m = ndimage.map_coordinates(ndimage.gaussian_filter(mask.astype(np.float32), 1.2 if k != 'sat' else r / 14), [py, px], order=1, mode='constant')
    row = keys.index(k)
    atlas.paste(Image.fromarray(np.clip(strip, 0, 255).astype(np.uint8)).convert('RGBA'), (0, row * TH))
    dm = np.dstack([np.clip(shade * 255, 0, 255), np.zeros_like(shade), np.zeros_like(shade), np.clip(m * 255, 0, 255)]).astype(np.uint8)
    atlas.paste(Image.fromarray(dm, 'RGBA'), (TW, row * TH))
    meta[k] = {'map': c, 'cx': cx, 'cy': cy, 'r': r, 'row': row, 'spd': SPEED.get(k, 120)}
    print('body', k, 'r', r)
atlas.save(os.path.join(SITE, 'bodies.png'))
json.dump({'tw': TW, 'th': TH, 'ds': DS, 'n': len(keys), 'b': meta}, open(os.path.join(SITE, 'bodies.json'), 'w'))
# sun (map A source coords)
json.dump({'map': 'A', 'cx': 878, 'cy': 4373, 'r': 1070}, open(os.path.join(SITE, 'sun.json'), 'w'))
print('done')
