#!/usr/bin/env python3
"""Procedural planet and moon maps for the Godot version (replaces the maps unwrapped from the printed art, which had
seams, swirls and black holes). One 512x256 equirectangular map per body, plus a round shading mask beside it, in the
same row layout as bodies.png. Every map is computed from 3D noise on the sphere, so it has no seam at the date line
and no pinching at the poles.  usage: python3 tools/make_bodies.py godot/assets"""
import json, sys, os
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree

TW, TH, DS = 512, 256, 256
ROWS = ["mer", "ven", "ear", "moo", "mar", "cer", "jup", "io", "eur", "gan", "cal", "sat", "tit", "ura", "nep", "tri"]

# ---------------- 3D value noise ----------------
def _hash(ix, iy, iz, seed):
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float64) / 65535.0

def vnoise(p, seed):
    x, y, z = p[..., 0], p[..., 1], p[..., 2]
    ix, iy, iz = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
    fx, fy, fz = x - ix, y - iy, z - iz
    sx, sy, sz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    def c(dx, dy, dz): return _hash(ix + dx, iy + dy, iz + dz, seed)
    x00 = c(0, 0, 0) * (1 - sx) + c(1, 0, 0) * sx
    x10 = c(0, 1, 0) * (1 - sx) + c(1, 1, 0) * sx
    x01 = c(0, 0, 1) * (1 - sx) + c(1, 0, 1) * sx
    x11 = c(0, 1, 1) * (1 - sx) + c(1, 1, 1) * sx
    return (x00 * (1 - sy) + x10 * sy) * (1 - sz) + (x01 * (1 - sy) + x11 * sy) * sz

def fbm(p, freq, oct=5, gain=.5, seed=1, stretch=(1, 1, 1)):
    q = p * np.array(stretch) * freq
    a, s, t = 1.0, 0.0, 0.0
    for o in range(oct):
        s += a * vnoise(q * (2 ** o) + o * 17.3, seed + o * 31)
        t += a
        a *= gain
    return s / t

def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)

def mix(c0, c1, t):
    t = np.asarray(t)[..., None]
    return np.asarray(c0) * (1 - t) + np.asarray(c1) * t

def hexc(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float64) / 255.0

def craters(p, layers, seed):
    """layers: (count, radius in radians, depth). Returns a height-like field: -bowl +rim."""
    rng = np.random.default_rng(seed)
    out = np.zeros(p.shape[:-1])
    flat = p.reshape(-1, 3)
    for n, r, depth in layers:
        n = int(n * .55); pts = rng.normal(size=(n, 3)); pts /= np.linalg.norm(pts, axis=1)[:, None]
        rr = r * (0.6 + 0.8 * rng.random(n))
        d, i = cKDTree(pts).query(flat, k=1)
        t = d / rr[i]
        bowl = -np.clip(1 - t * t, 0, 1) ** 1.3 * depth * .55
        rim = np.exp(-((t - 1.05) / .12) ** 2) * depth * .55
        out += (bowl + rim).reshape(out.shape)
    return out

def tone(c, k): return np.clip(c * k[..., None], 0, 1)

# ---------------- bodies ----------------
def body(name, p):
    lat = np.arcsin(p[..., 1])
    if name == "mer":
        h = fbm(p, 3, 5, .55, 3) * .5 + craters(p, [(60, .16, .55), (220, .07, .5), (700, .032, .4)], 5)
        c = mix(hexc("#5a5249"), hexc("#a39a8d"), np.clip(h * 1.5 + .25, 0, 1))
        return tone(c, .85 + .3 * fbm(p, 9, 3, .5, 8))
    if name == "ven":
        w = fbm(p, 2.2, 4, .5, 11) * 2.4
        q = p + np.stack([np.sin(w * 6), np.cos(w * 5) * .4, np.sin(w * 4 + 1)], -1) * .22
        b = fbm(q, 3, 5, .55, 12, stretch=(1, 2.6, 1))
        c = mix(hexc("#d9c07a"), hexc("#f6e6b4"), smooth(b, .3, .75))
        return mix(c, hexc("#b8905a"), smooth(fbm(q, 6, 3, .5, 13, (1, 3, 1)), .62, .9) * .45)
    if name == "ear":
        h = fbm(p, 1.7, 6, .52, 21)
        land = smooth(h, .5, .54)
        sea = mix(hexc("#0b2d63"), hexc("#1d6fb0"), smooth(h, .25, .5))
        t = np.abs(lat) / (np.pi / 2)
        green = mix(hexc("#3f7a38"), hexc("#7e8f46"), smooth(fbm(p, 5, 4, .5, 22), .35, .7))
        desert = mix(green, hexc("#b79a62"), smooth(fbm(p, 2.5, 3, .5, 23), .52, .72) * (1 - smooth(t, .55, .75)))
        rock = mix(desert, hexc("#8d8678"), smooth(h, .64, .8))
        c = mix(sea, rock, land)
        c = mix(c, hexc("#eef4f8"), smooth(t, .8, .9))
        cl = smooth(fbm(p + np.stack([fbm(p, 3, 3, .5, 25), fbm(p, 3, 3, .5, 26), fbm(p, 3, 3, .5, 27)], -1) * .5, 2.6, 6, .55, 24, (1, 1.5, 1)), .5, .78)
        return mix(c, hexc("#ffffff"), cl * .88)
    if name == "moo":
        mare = smooth(fbm(p, 1.6, 4, .5, 31), .5, .6)
        h = craters(p, [(40, .18, .5), (180, .07, .45), (600, .03, .4)], 32)
        base = mix(hexc("#a9a7a3"), hexc("#55565a"), mare * .85)
        return tone(base, np.clip(.88 + h * .7 + .15 * fbm(p, 14, 3, .5, 33), .4, 1.3))
    if name == "mar":
        d = fbm(p, 2.4, 5, .55, 41)
        dark = smooth(fbm(p, 1.9, 4, .5, 42), .52, .66)
        c = mix(hexc("#b4623a"), hexc("#d58d55"), smooth(d, .35, .7))
        c = mix(c, hexc("#4f3326"), dark * .75)
        c = tone(c, .9 + craters(p, [(80, .1, .3), (300, .04, .3)], 43) * .5 + .2 * fbm(p, 12, 3, .5, 44))
        t = np.abs(lat) / (np.pi / 2)
        return mix(c, hexc("#f2f2f0"), smooth(t, .88, .94) * .95)
    if name == "cer":
        h = craters(p, [(50, .2, .5), (250, .08, .45), (900, .035, .4)], 51)
        c = mix(hexc("#4a4743"), hexc("#7d7a74"), np.clip(fbm(p, 4, 4, .5, 52), 0, 1))
        c = tone(c, np.clip(.9 + h * .8, .45, 1.3))
        sp = np.exp(-(np.linalg.norm(p - np.array([.8, .2, .55]), axis=-1) / .07) ** 2)
        return mix(c, hexc("#f1f1ee"), sp * .9)
    if name in ("jup", "sat", "ura", "nep"):
        cfg = {"jup": ("#e6d3b4", "#b0623a", "#efe1c8", "#7a4b34", 7, .12, 2.4),
               "sat": ("#efdca8", "#c3a064", "#f6ebc6", "#a8895a", 6, .08, 2.4),
               "ura": ("#8fc9cf", "#74b2bb", "#a8dcdc", "#5f9fa9", 4, .02, 1.5),
               "nep": ("#3d5fcf", "#2a3e9c", "#5f86e6", "#22337f", 5, .06, 1.8)}[name]
        A, B, Cc, D, nb, turb, f = cfg
        w = fbm(p, 2.0, 4, .55, 61) - .5
        lat2 = lat + w * turb * 2.2 * np.cos(lat) + (fbm(p, 6, 3, .5, 62, (.5, 4, .5)) - .5) * turb * .8
        bands = .5 + .5 * np.sin(lat2 * nb * 2 + np.sin(lat2 * nb * 3.1) * .8)
        fine = fbm(p, 9, 4, .5, 63, (1, 9, 1))
        t = np.clip(bands * .7 + fine * .5 - .1, 0, 1)
        c = mix(mix(hexc(A), hexc(B), smooth(t, .35, .65)), mix(hexc(Cc), hexc(D), smooth(fine, .45, .75)), .25 * (name in ("jup", "sat")) + .1)
        if name == "jup":
            spot = np.exp(-(((np.arctan2(p[..., 2], p[..., 0]) - 2.2 + np.pi) % (2 * np.pi) - np.pi) / .2) ** 2 - ((lat + .3) / .09) ** 2)
            c = mix(c, hexc("#b5553a"), spot * .9)
        if name == "nep":
            spot = np.exp(-(((np.arctan2(p[..., 2], p[..., 0]) - 1.0 + np.pi) % (2 * np.pi) - np.pi) / .22) ** 2 - ((lat + .35) / .1) ** 2)
            c = mix(c, hexc("#1a2670"), spot * .8)
            c = mix(c, hexc("#e8f0ff"), smooth(fbm(p, 8, 3, .5, 64, (1, 5, 1)), .72, .85) * .5)
        if name in ("ura", "sat"):
            c = mix(c, c.mean(-1, keepdims=True) + np.array([.0, .05, .05]) * (name == "ura"), .15)
        return c
    if name == "io":
        s = fbm(p, 3, 5, .55, 71)
        c = mix(hexc("#e8d35a"), hexc("#d78b38"), smooth(s, .4, .7))
        c = mix(c, hexc("#f2eac2"), smooth(fbm(p, 2, 4, .5, 72), .6, .78) * .6)
        dots = smooth(fbm(p, 14, 2, .5, 73), .78, .84)
        c = mix(c, hexc("#2a1e18"), dots * .85)
        return mix(c, hexc("#b8402a"), smooth(fbm(p, 6, 3, .5, 74), .76, .86) * .6)
    if name == "eur":
        base = mix(hexc("#e9e2d2"), hexc("#cfc2a8"), smooth(fbm(p, 3, 4, .5, 81), .35, .7))
        ln = np.abs(fbm(p + fbm(p, 4, 3, .5, 82)[..., None] * .35, 5, 4, .5, 83) - .5)
        lines = 1 - smooth(ln, .0, .06)
        c = mix(base, hexc("#9a5a3c"), lines * .7)
        return mix(c, hexc("#b88e6a"), smooth(fbm(p, 2.4, 3, .5, 84), .6, .75) * .4)
    if name == "gan":
        a = smooth(fbm(p, 3, 5, .55, 91), .45, .6)
        c = mix(hexc("#6d6258"), hexc("#a39484"), fbm(p, 6, 4, .5, 92))
        c = mix(c, hexc("#c9c4ba"), a * .6)
        h = craters(p, [(60, .1, .4), (250, .045, .35)], 93)
        return tone(c, np.clip(.95 + h * .7, .5, 1.3))
    if name == "cal":
        c = mix(hexc("#3d352f"), hexc("#6e6153"), fbm(p, 5, 5, .55, 101))
        h = craters(p, [(80, .1, .5), (400, .045, .5), (1500, .02, .4)], 102)
        c = tone(c, np.clip(.95 + h * .9, .4, 1.5))
        return mix(c, hexc("#dcd6cc"), smooth(fbm(p, 12, 2, .5, 103), .8, .9) * .5)
    if name == "tit":
        b = fbm(p, 2, 4, .5, 111, (1, 2.2, 1))
        c = mix(hexc("#c98a36"), hexc("#e8b25a"), smooth(b, .3, .7))
        c = mix(c, hexc("#a5692a"), smooth(fbm(p, 5, 3, .5, 112, (1, 3, 1)), .55, .8) * .5)
        return mix(c, hexc("#7a5528"), smooth(np.abs(lat) / (np.pi / 2), .85, .98) * .6)
    if name == "tri":
        base = mix(hexc("#d9cfc8"), hexc("#f3e4e0"), smooth(fbm(p, 3, 4, .5, 121), .35, .7))
        cant = smooth(fbm(p, 12, 3, .5, 122), .5, .7) * .12
        c = mix(base, hexc("#9c6f78"), smooth(fbm(p, 2.4, 3, .5, 123), .55, .72) * .5)
        c = tone(c, .93 + cant)
        return mix(c, hexc("#4a3f45"), smooth(fbm(p + .3, 7, 3, .5, 124, (1, 5, 1)), .7, .82) * .45)
    raise KeyError(name)

def main(out):
    lon = (np.arange(TW) + .5) / TW * 2 * np.pi - np.pi
    lat = (np.arange(TH) + .5) / TH * np.pi - np.pi / 2
    LO, LA = np.meshgrid(lon, lat)
    P = np.stack([np.cos(LA) * np.sin(LO), np.sin(LA), np.cos(LA) * np.cos(LO)], -1)
    atlas = np.zeros((TH * len(ROWS), TW + DS, 4), np.float64)
    # the round mask: r = limb darkening, a = disc
    yy, xx = np.mgrid[0:DS, 0:DS]
    u = ((xx + .5) / DS * 2 - 1); v = ((yy + .5) / DS * 2 - 1); d = np.sqrt(u * u + v * v)
    mask = np.zeros((DS, DS, 4)); nz = np.sqrt(np.clip(1 - d * d, 0, 1))
    mask[..., 0] = .42 + .36 * nz ** .6; mask[..., 1] = mask[..., 0]; mask[..., 2] = mask[..., 0]
    mask[..., 3] = (d <= 1).astype(float)
    for i, n in enumerate(ROWS):
        c = np.clip(body(n, P), 0, 1)
        y0 = i * TH
        atlas[y0:y0 + TH, :TW, :3] = c
        atlas[y0:y0 + TH, :TW, 3] = 1
        atlas[y0:y0 + DS, TW:TW + DS] = mask if DS <= TH else mask[:TH]
        print(n, end=" ", flush=True)
    img = Image.fromarray((atlas * 255 + .5).astype(np.uint8), "RGBA")
    img.save(os.path.join(out, "bodies.png"))
    meta = json.load(open(os.path.join(out, "bodies.json")))
    meta.update({"tw": TW, "th": TH, "ds": DS})
    json.dump(meta, open(os.path.join(out, "bodies.json"), "w"))
    print("\nwrote", img.size)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "godot/assets")
