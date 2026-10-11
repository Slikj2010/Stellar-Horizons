"""Procedural, seamless cloud cover for the title-screen Earth (equirectangular, wraps in longitude, no seam).
Sampled from 3D noise on the sphere so there is no seam and no pinching at the poles. Domain-warped fBm gives
swirls and fronts; a high-frequency octave adds wispy edges; latitude bands thin the subtropics.
Writes menu_clouds.webp (R = cloud density). Usage: python3 tools/gen_clouds.py [seed]"""
import sys, math
import numpy as np
from PIL import Image
rng = np.random.default_rng(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
TW, TH = 2048, 1024
P = rng.permutation(256).astype(np.int64); P = np.concatenate([P, P]); G = rng.random(256)
def vnoise(x, y, z):
    xi, yi, zi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
    xf, yf, zf = x - xi, y - yi, z - zi
    fade = lambda t: t * t * t * (t * (t * 6 - 15) + 10)
    u, v, w = fade(xf), fade(yf), fade(zf)
    h = lambda a, b, c: G[P[P[(a & 255)] + (b & 255)] + (c & 255) & 255]
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wt = (u if dx else 1 - u) * (v if dy else 1 - v) * (w if dz else 1 - w)
                out = out + wt * h(xi + dx, yi + dy, zi + dz)
    return out * 2 - 1
def fbm(x, y, z, oct, lac=2.03, gain=.5):
    s, a, f, n = 0, 1, 1, 0
    for i in range(oct):
        s = s + a * vnoise(x * f + i * 17.3, y * f - i * 9.1, z * f + i * 5.7); n += a; a *= gain; f *= lac
    return s / n
lon = (np.arange(TW) + .5) / TW * 2 * math.pi - math.pi
lat = (np.arange(TH) + .5) / TH * math.pi - math.pi / 2
LON, LAT = np.meshgrid(lon, lat)
X, Y, Z = np.cos(LAT) * np.cos(LON), np.sin(LAT), np.cos(LAT) * np.sin(LON)
F = 2.2
# domain warp: twice, so features curl into swirls and fronts
wx = fbm(X * F, Y * F, Z * F, 4); wy = fbm(X * F + 5.2, Y * F + 1.3, Z * F - 2.1, 4); wz = fbm(X * F - 3.7, Y * F + 8.1, Z * F + 4.4, 4)
X2, Y2, Z2 = X + .55 * wx, (Y + .55 * wy) * 1.7, Z + .55 * wz   # stretched east-west, like real weather systems
qx = fbm(X2 * 3, Y2 * 3, Z2 * 3, 4); qy = fbm(X2 * 3 + 9, Y2 * 3, Z2 * 3, 4)
base = fbm(X2 * 2.6 + .35 * qx, Y2 * 2.6 + .35 * qy, Z2 * 2.6, 7, gain=.55)
detail = fbm(X * 22, Y * 22, Z * 22, 4, gain=.55)
# latitude climate: cloudy equator and storm belts around 50-60 degrees, clearer subtropics and poles
la = np.abs(np.degrees(LAT))
climate = .06 * np.exp(-(la / 9) ** 2) - .07 * np.exp(-((la - 26) / 10) ** 2) + .09 * np.exp(-((la - 55) / 14) ** 2)
d = base + climate + .14 * detail
c = np.clip((d - .04) / .42, 0, 1)
c = c * c * (3 - 2 * c)
# thin, wispy fringes and some dense cores
c = np.clip(c * (.6 + .6 * np.clip(detail + .5, 0, 1)), 0, 1) * .92
print('cover %.0f%%' % (100 * (c > .3).mean()))
Image.fromarray((c * 255).astype(np.uint8), 'L').save('menu_clouds.webp', 'WEBP', quality=88, method=6)
