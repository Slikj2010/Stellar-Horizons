#!/usr/bin/env python3
"""A realistic galaxy backdrop for the Godot version, in the game's dark navy and cyan palette (Stellaris-like: teal
and violet gas clouds, a dusty Milky Way band, tens of thousands of stars, a few diffraction-spiked ones and small
distant galaxies).  Writes two images:
  sky_pano.png  4096x2048 equirectangular, wrapped round the 2.5D view as its sky
  sky_flat.png  3840x2160 flat, behind the 2D map
usage: python3 tools/make_sky.py godot/assets"""
import sys, os
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from make_bodies import fbm, smooth, hexc

def tone(x):
    return 1 - np.exp(-x)

def nebula(P, seed, band_axis, wscale=1.0):
    """P: (..., 3) positions. Returns linear RGB (..., 3) of gas, dust and the galactic glow."""
    Pw = P * wscale
    w1 = np.stack([fbm(Pw + 3.1, 1.3, 4, .5, seed + 1), fbm(Pw + 7.7, 1.3, 4, .5, seed + 2), fbm(Pw + 1.9, 1.3, 4, .5, seed + 3)], -1) - .5
    q = Pw + w1 * 1.7
    big = fbm(q, 1.5, 6, .56, seed + 4)
    teal = smooth(big, .40, .78) ** 1.25
    fil = np.abs(fbm(q + 5, 3.2, 5, .55, seed + 5) - .5)
    filament = (1 - smooth(fil, 0, .13)) * smooth(big, .38, .7)
    violet = smooth(fbm(q * .8 + 11, 1.2, 5, .55, seed + 6), .5, .8) ** 1.3
    warm = smooth(fbm(q * .9 + 23, 1.7, 5, .55, seed + 7), .6, .85) * smooth(big, .35, .65)
    blue = smooth(fbm(q + 41, 1.0, 4, .5, seed + 8), .45, .75)
    dust = smooth(fbm(q * 1.4 + 57, 2.6, 6, .58, seed + 9), .5, .72)
    ax = np.asarray(band_axis, np.float64); ax = ax / np.linalg.norm(ax)
    lat = (P @ ax)
    warp = (fbm(Pw * 1.4 + 71, 2, 4, .5, seed + 10) - .5) * .35
    glow = np.exp(-((lat + warp) / .22) ** 2) * (.55 + .8 * fbm(Pw * 2.2 + 91, 1, 5, .55, seed + 11))
    lane = np.exp(-((lat + warp * .7 + .015) / .05) ** 2) * smooth(fbm(Pw * 3.1 + 13, 1, 5, .6, seed + 12), .38, .7)
    c = np.zeros(P.shape[:-1] + (3,))
    c += teal[..., None] * hexc("#0b6468") * .52
    c += filament[..., None] * hexc("#42d6cf") * .30
    c += blue[..., None] * hexc("#14336f") * .38 * (.4 + big[..., None])
    c += violet[..., None] * hexc("#6a2fa8") * .40
    c += warm[..., None] * hexc("#c8742c") * .42
    c += glow[..., None] * hexc("#a9c4e8") * .13
    c += glow[..., None] * warm[..., None] * hexc("#ffb768") * .30
    c *= (1 - .75 * np.clip(dust * (.35 + teal) + lane, 0, 1))[..., None]
    c += hexc("#02050c")
    return c

# ---------------- stars ----------------
def star_color(rng, n):
    t = rng.random(n)
    cols = np.array([hexc("#9db8ff"), hexc("#cfe0ff"), hexc("#ffffff"), hexc("#fff1d0"), hexc("#ffd29a"), hexc("#ffa772")])
    pos = np.clip(t ** 1.4 * (len(cols) - 1), 0, len(cols) - 1.001)
    i = pos.astype(int); f = (pos - i)[:, None]
    return cols[i] * (1 - f) + cols[i + 1] * f

def splat(img, x, y, sx, sy, col, amp, ph=None):
    """add elliptical gaussians; x wraps horizontally when ph (the image width) is given"""
    H, W, _ = img.shape
    for k in range(len(x)):
        rx, ry = max(1, int(np.ceil(3 * sx[k]))), max(1, int(np.ceil(3 * sy[k])))
        cx, cy = int(np.floor(x[k])), int(np.floor(y[k]))
        ys = np.arange(cy - ry, cy + ry + 1)
        xs = np.arange(cx - rx, cx + rx + 1)
        ok = (ys >= 0) & (ys < H)
        if not ok.any(): continue
        g = np.exp(-(((xs[None, :] + .5 - x[k]) / sx[k]) ** 2 + ((ys[:, None] + .5 - y[k]) / sy[k]) ** 2) / 2)
        xi = xs % W if ph else np.clip(xs, 0, W - 1)
        if not ph:
            m = (xs >= 0) & (xs < W)
            g = g * m[None, :]
        img[np.clip(ys, 0, H - 1)[:, None], xi[None, :]] += (g[..., None] * (col[k] * amp[k])) * ok[:, None, None]

def stars(img, rng, pano, band_axis, lat_of, n_faint=70000, n_mid=2200, n_hero=14, SC=1.0):
    H, W, _ = img.shape
    def place(n, bias):
        out = []
        while sum(len(o) for o in out) < n:
            x = rng.random(n * 2) * W
            y = rng.random(n * 2) * H
            if pano:
                lat = (y / H - .5) * np.pi
                keep = rng.random(n * 2) < np.abs(np.cos(lat))      # uniform on the sphere
                lon = x / W * 2 * np.pi - np.pi
                P = np.stack([np.cos(lat) * np.sin(lon), np.sin(lat), np.cos(lat) * np.cos(lon)], -1)
            else:
                keep = np.ones(n * 2, bool)
                P = np.stack([x / W * 2 - 1, y / H * 2 - 1, np.zeros(n * 2)], -1)
            b = np.exp(-(lat_of(P) / .3) ** 2)
            keep &= rng.random(n * 2) < (1 - bias) + bias * b
            out.append(np.stack([x[keep], y[keep]], -1))
        return np.concatenate(out)[:n]
    # faint stars: single texels, dim, many of them (denser in the Milky Way)
    p = place(n_faint, .85)
    mag = rng.random(len(p)) ** 3.2
    col = star_color(rng, len(p))
    sx = np.full(len(p), .62 * SC); sy = np.full(len(p), .62 * SC)
    if pano:
        lat = (p[:, 1] / H - .5) * np.pi
        sx = np.clip(.62 * SC / np.maximum(np.cos(lat), .12), .62 * SC, 5 * SC)
    splat(img, p[:, 0], p[:, 1], sx, sy, col, .1 + mag * .85, pano)
    # brighter stars with a soft halo
    p = place(n_mid, .5)
    mag = rng.random(len(p)) ** 2.2
    col = star_color(rng, len(p))
    s = (.8 + mag * 1.1) * SC
    sx = s.copy()
    if pano:
        lat = (p[:, 1] / H - .5) * np.pi
        sx = s / np.maximum(np.cos(lat), .15)
    splat(img, p[:, 0], p[:, 1], sx, s, col, .5 + mag * 1.2, pano)
    splat(img, p[:, 0], p[:, 1], sx * 4.5, s * 4.5, col, .03 + mag * .09, pano)
    # a few big ones with diffraction spikes
    p = place(n_hero, 0)
    if pano:
        lat = (p[:, 1] / H - .5) * np.pi
        p = p[np.abs(lat) < np.radians(52)]
    col = star_color(rng, len(p)) * .8 + .2
    for k in range(len(p)):
        x0, y0 = p[k]
        splat(img, [x0], [y0], [2.1 * SC], [2.1 * SC], col[k:k + 1], [2.4], pano)
        splat(img, [x0], [y0], [9 * SC], [9 * SC], col[k:k + 1], [.22], pano)
        splat(img, [x0], [y0], [26 * SC], [26 * SC], col[k:k + 1] * np.array([.5, .8, 1.0]), [.035], pano)
        L = (40 + rng.random() * 40) * SC
        splat(img, [x0], [y0], [L], [.7 * SC], col[k:k + 1], [.45], pano)
        splat(img, [x0], [y0], [.7 * SC], [L], col[k:k + 1], [.45], pano)

def galaxies(img, rng, n, pano):
    H, W, _ = img.shape
    for _ in range(n):
        x = rng.random() * W; y = (.22 + rng.random() * .56) * H
        a = rng.random() * np.pi; s = 3 + rng.random() * 7; e = .25 + rng.random() * .5
        col = np.array(hexc("#ffe3b0") if rng.random() < .5 else hexc("#a9c4ff"))
        yy, xx = np.mgrid[-int(s * 5):int(s * 5) + 1, -int(s * 5):int(s * 5) + 1]
        u = xx * np.cos(a) + yy * np.sin(a); v = -xx * np.sin(a) + yy * np.cos(a)
        r = np.sqrt((u / s) ** 2 + (v / (s * e)) ** 2)
        g = np.exp(-r * 1.6) * .5 + np.exp(-r * r * 6) * .6
        arms = 1 + .35 * np.cos(2.2 * np.arctan2(v / e, u) + r * 3) * (r < 2.6)
        patch = (g * arms)[..., None] * col * .5
        y0, x0 = int(y) - yy.shape[0] // 2, int(x) - xx.shape[1] // 2
        for j in range(patch.shape[0]):
            for i in range(patch.shape[1]):
                yi = y0 + j; xi = (x0 + i) % W
                if 0 <= yi < H: img[yi, xi] += patch[j, i]

def finish(c, vignette=None):
    c = tone(c * .8)
    if vignette is not None: c = c * vignette[..., None]
    c = np.power(np.clip(c, 0, 1), 1 / 1.45)
    return (c * 255 + .5).astype(np.uint8)

def render_pano(out):
    W0, H0 = 4096, 2048
    ax = (0.35, 0.82, 0.45)
    cache = "/tmp/neb4096.npy"
    if os.path.exists(cache):
        neb = np.load(cache)
    else:
        neb = np.zeros((H0, W0, 3), np.float32)
        for r0 in range(0, H0, 256):
            lat = ((np.arange(r0, r0 + 256) + .5) / H0 - .5) * np.pi
            lon = ((np.arange(W0) + .5) / W0) * 2 * np.pi - np.pi
            LO, LA = np.meshgrid(lon, lat)
            P = np.stack([np.cos(LA) * np.sin(LO), np.sin(LA), np.cos(LA) * np.cos(LO)], -1)
            neb[r0:r0 + 256] = nebula(P, 100, ax, 1.0)
            print("pano", r0, end="\r", flush=True)
        np.save(cache, neb)
    # the gas is soft: render it at 4096 and scale up, then put sharp stars on the 8192 x 4096 sky
    W, H = 8192, 4096
    img = np.zeros((H, W, 3), np.float32)
    for c in range(3):
        img[..., c] = np.asarray(Image.fromarray(neb[..., c], "F").resize((W, H), Image.BICUBIC))
    rng = np.random.default_rng(7)
    lat_of = lambda P: P @ (np.array(ax) / np.linalg.norm(ax))
    stars(img, rng, True, ax, lat_of, 150000, 5200, 18, SC=1.9)
    galaxies(img, rng, 30, True)
    Image.fromarray(finish(img), "RGB").save(os.path.join(out, "sky_pano.png"), compress_level=6)

def render_flat(out):
    W, H = 3840, 2160
    img = np.zeros((H, W, 3), np.float32)
    ax = (0.5, -0.85, 0.0)
    for r0 in range(0, H, 240):
        ys = (np.arange(r0, min(H, r0 + 240)) + .5) / H
        xs = (np.arange(W) + .5) / W
        X, Y = np.meshgrid(xs, ys)
        P = np.stack([X * 3.2, Y * 1.8, np.full_like(X, .37)], -1)
        img[r0:r0 + len(ys)] = nebula(P * .62, 300, (.5, -.85, 0), 1.0)
        print("flat", r0, end="\r", flush=True)
    rng = np.random.default_rng(11)
    def lat_of(P):
        # distance across the diagonal band in the flat image
        return (P[..., 0] * .5 - P[..., 1] * .85) * .9 + .05
    stars(img, rng, False, ax, lat_of, 52000, 1700, 9)
    galaxies(img, rng, 18, False)
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx / W - .5) * 1.6) ** 2 + ((yy / H - .5) * 1.6) ** 2)
    vig = 1 - .45 * smooth(d, .45, 1.1)
    Image.fromarray(finish(img, vig), "RGB").save(os.path.join(out, "sky_flat.png"))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "godot/assets"
    which = sys.argv[2] if len(sys.argv) > 2 else "both"
    if which in ("both", "pano"): render_pano(out)
    if which in ("both", "flat"): render_flat(out)
    print("done")
