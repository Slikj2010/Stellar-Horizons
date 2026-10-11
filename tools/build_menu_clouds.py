"""Menu Earth: split the painted clouds off the title-screen Earth so they can drift around the globe.
Clouds = small bright, low-saturation structures: a grey-scale morphological opening removes them (that is the
cloud-free globe) and the difference is the cloud layer, drawn back additively at a slowly turning longitude.
Writes menu_earth.webp (cloud-free globe, alpha = disc) and menu_earth.json. The moving clouds come from
tools/gen_clouds.py (menu_clouds.webp).
Usage: python3 tools/build_menu_clouds.py"""
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
json.dump({'x0': x0, 'y0': y0, 'w': x1 - x0, 'h': y1 - y0, 'sun': SUN.tolist()}, open('menu_earth.json', 'w'))
print('earth crop', x0, y0, x1 - x0, y1 - y0)
