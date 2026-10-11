"""Menu Earth: split the painted clouds off the title-screen Earth so they can drift around the globe.
Clouds = small bright, low-saturation structures: a grey-scale morphological opening removes them (that is the
cloud-free globe) and the difference is the cloud layer, drawn back additively at a slowly turning longitude.
Writes menu_earth.webp (cloud-free globe, alpha = disc), menu_clouds.png (equirectangular cloud brightness,
normalised by sunlight; far side is a cross-faded copy of the near side) and menu_earth.json.
Usage: python3 tools/build_menu_clouds.py [preview_dir]"""
import json, math, sys
import numpy as np, cv2
from PIL import Image
M = json.load(open('menu.json'))
ex, ey, er = M['earth']
src = np.asarray(Image.open('menu.webp').convert('RGB')).astype(np.float32)
H, W = src.shape[:2]
x0, y0 = max(0, int(ex - er) - 2), max(0, int(ey - er) - 2)
x1, y1 = min(W, int(ex + er) + 3), min(H, int(ey + er) + 3)
crop = src[y0:y1, x0:x1]
yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
u = (xx + .5 - ex) / er; v = (yy + .5 - ey) / er; d = np.hypot(u, v)
nz = np.sqrt(np.clip(1 - u * u - v * v, 0, 1))
SUN = np.array([.62, -.66, .42]); SUN /= np.linalg.norm(SUN)
light = .1 + .9 * np.clip((u * SUN[0] + v * SUN[1] + nz * SUN[2]) * 1.15 + .2, 0, 1)
# cloud-free globe: opening (erode then dilate) with a disc larger than most cloud cells
k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (61, 61))
opened = np.dstack([cv2.morphologyEx(crop[..., c], cv2.MORPH_OPEN, k) for c in range(3)])
opened = cv2.GaussianBlur(opened, (0, 0), 1.2)
diff = np.clip(crop - opened, 0, None)
mn = diff.min(2); mx = diff.max(2); sat = (mx - mn) / np.maximum(mx, 1)
keep = (1 - np.clip((sat - .25) / .3, 0, 1))                       # clouds are grey/white, the orbit line is blue
warm = np.clip((crop[..., 0] - crop[..., 2] - 10) / 25, 0, 1)        # city lights stay on the globe
keep *= 1 - warm
keep *= np.clip((.955 - d) / .05, 0, 1)                              # not the atmosphere at the limb
# orbit line B and the satellite cross the globe: leave them alone
lm = np.zeros(d.shape, np.uint8)
pts = np.array(M['orbitB'], np.float32) - [x0, y0]
cv2.polylines(lm, [pts.astype(np.int32)], False, 255, 14)
cv2.rectangle(lm, (1150 - x0, 780 - y0), (1280 - x0, 880 - y0), 255, -1)
keep *= 1 - cv2.GaussianBlur(lm.astype(np.float32) / 255, (0, 0), 3)
cloud = diff * keep[..., None]                                       # additive cloud light
base = crop - cloud                                                  # globe without those clouds
disc_a = np.clip((.995 - d) / .012, 0, 1)
Image.fromarray(np.dstack([np.clip(base, 0, 255), disc_a * 255]).astype(np.uint8), 'RGBA').save('menu_earth.webp', 'WEBP', quality=90, method=6)
# cloud brightness per unit sunlight, greyscale (clouds take the local light when drawn)
cb = np.clip(cloud.mean(2) / light, 0, 255)
TW, TH = 2048, 1024
lon = (np.arange(TW) + .5) / TW * 2 * math.pi - math.pi
lat = (np.arange(TH) + .5) / TH * math.pi - math.pi / 2
LON, LAT = np.meshgrid(lon, lat)
def samp(f):
    fs = np.clip(f, -math.pi / 2 * .96, math.pi / 2 * .96)
    px = (ex + np.cos(LAT) * np.sin(fs) * er - x0 - .5).astype(np.float32); py = (ey + np.sin(LAT) * er - y0 - .5).astype(np.float32)
    return cv2.remap(cb.astype(np.float32), px, py, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
wrap = lambda a: (a + math.pi) % (2 * math.pi) - math.pi
fa, fb = wrap(LON), wrap(LON - math.pi)
def wgt(f): t = np.clip((np.degrees(np.abs(f)) - 55) / 40, 0, 1); return 1 - t * t * (3 - 2 * t)
wa, wb = wgt(fa), wgt(fb); tot = np.maximum(wa + wb, 1e-6)
cl = samp(fa) * wa / tot + samp(fb) * wb / tot
vis = (ey + np.sin(LAT) * er) < H - 2
cl = np.where(vis, cl, np.flipud(cl))
Image.fromarray(np.clip(cl, 0, 255).astype(np.uint8), 'L').save('menu_clouds.png', optimize=True)
json.dump({'x0': x0, 'y0': y0, 'w': x1 - x0, 'h': y1 - y0, 'sun': SUN.tolist()}, open('menu_earth.json', 'w'))
print('earth crop', x0, y0, x1 - x0, y1 - y0)
if len(sys.argv) > 1:
    out = sys.argv[1]
    def render(rot):
        lonp = np.arcsin(np.clip(u / np.maximum(np.sqrt(1 - v * v), 1e-6), -1, 1)); latp = np.arcsin(np.clip(v, -1, 1))
        tx = ((wrap(lonp - rot) + math.pi) / (2 * math.pi) * TW - .5).astype(np.float32); ty = ((latp + math.pi / 2) / math.pi * TH - .5).astype(np.float32)
        c = cv2.remap(cl.astype(np.float32), tx, ty, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP) * light * (d < .97)
        return np.clip(base + c[..., None] * np.array([1, 1.02, 1.06]), 0, 255).astype(np.uint8)
    Image.fromarray(np.hstack([crop.astype(np.uint8), np.clip(base, 0, 255).astype(np.uint8), render(0), render(.5)])).resize((4 * (x1 - x0) // 2, (y1 - y0) // 2)).save(out + '/mc_cmp.png')
