"""Paints the Andromeda galaxy (and its companion M32) as a transparent texture for the Deep Space Astronomy model."""
import numpy as np
from PIL import Image, ImageFilter
rng = np.random.default_rng(31)
W, H = 1280, 800
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
cx, cy = W * .5, H * .45
pa = np.radians(24)  # long axis rises to the upper left
inc = 0.30            # minor/major ratio
dx, dy = x - cx, y - cy
u = dx * np.cos(pa) + dy * np.sin(pa)          # along the long axis
v = (-dx * np.sin(pa) + dy * np.cos(pa)) / inc  # deprojected
R = np.sqrt(u * u + v * v) / 640.0
th = np.arctan2(v, u)
bulge = np.exp(-(R / .11) ** .6) * 1.6
disk = np.exp(-R / .34) * .55
arm = .5 + .5 * np.cos(2 * (th - 2.6 * np.log(R + .03)) + .4)
arm = arm ** 1.6
ring = np.exp(-((R - .62) / .09) ** 2) * .5 + np.exp(-((R - .33) / .06) ** 2) * .3
lum = bulge + disk * (.55 + .6 * arm) + ring * (.6 + .5 * arm)
# dust lanes: darker on the near (lower) side
dust = np.clip((1 - np.abs(np.sin(2 * (th - 2.6 * np.log(R + .03)) + .4)) ** .5) * np.exp(-((R - .3) / .3) ** 2), 0, 1)
dust *= (0.55 + 0.45 * (v < 0))
lum *= 1 - .6 * dust
noise = rng.normal(0, 1, (H, W)).astype(np.float32)
nz = np.asarray(Image.fromarray(((noise * 40 + 128).clip(0, 255)).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)), dtype=np.float32) / 128 - 1
lum *= 1 + nz * 2.2 * (R > .1)
lum *= np.clip(1.25 - R * 1.15, 0, 1) ** 1.4
core = np.array([1.0, .86, .6]); mid = np.array([.9, .8, .72]); blue = np.array([.52, .68, 1.0])
t_core = np.clip(bulge / 1.2, 0, 1)[..., None]; t_blue = np.clip((R - .25) / .5, 0, 1)[..., None]
col = core * t_core + (mid * (1 - t_blue) + blue * t_blue) * (1 - t_core)
img = np.zeros((H, W, 4), np.float32)
L = np.clip(lum, 0, 3)
# companion galaxies
def blob(px, py, rx, ry, a, amp):
    c, s = np.cos(a), np.sin(a)
    uu = (x - px) * c + (y - py) * s; vv = (-(x - px) * s + (y - py) * c)
    return np.exp(-((uu / rx) ** 2 + (vv / ry) ** 2) ** .45 * 2.2) * amp
m32 = blob(W * .36, H * .86, 34, 28, -.3, 1.4)
m110 = blob(W * .72, H * .13, 70, 30, .6, .35)
comp = m32 + m110
rgb = col * L[..., None] + comp[..., None] * np.array([1, .93, .8])
tot = L + comp
# a little star field of the galaxy's foreground
for _ in range(180):
    sx, sy = rng.integers(0, W), rng.integers(0, H)
    amp = rng.random() ** 3 * 1.2 + .15
    g = np.exp(-(((x - sx) ** 2 + (y - sy) ** 2) / (2 * (1.0 + amp) ** 2)))
    rgb += g[..., None] * amp * np.array([.95, .97, 1.0]); tot += g * amp
rgb = np.clip(rgb / np.maximum(tot[..., None], 1e-4), 0, 1)
a = np.clip(tot * 1.5, 0, 1) ** .8
# soften brightest area toward white
rgb = np.clip(rgb + (np.clip(bulge - 1.0, 0, 1)[..., None] * .35), 0, 1)
img[..., :3] = rgb; img[..., 3] = a
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save("godot/assets/v25/andromeda.png")
print("ok")
