"""Synthesizes build.ogg and scrap.ogg from scratch (no samples, nothing vocal): a spaceport engineering bay with a low hangar
rumble, a gantry servo, pneumatic hiss, a welding arc and soft metallic ticks, in a steel-hall reverb. No impacts or beeps."""
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter, fftconvolve

SR = 44100
OUT = 'godot/assets/audio/'


def lp(x, f, o=2):
    b, a = butter(o, f / (SR / 2)); return lfilter(b, a, x)


def hp(x, f, o=2):
    b, a = butter(o, f / (SR / 2), 'high'); return lfilter(b, a, x)


def bp(x, lo, hi, o=2):
    b, a = butter(o, [lo / (SR / 2), hi / (SR / 2)], 'band'); return lfilter(b, a, x)


def env(n, a, r, shape=2.0):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-np.maximum(0, t - a) / max(r, 1e-4) * shape)


def fade(n, fi, fo):
    t = np.arange(n) / SR
    return np.minimum(1, t / fi) * np.minimum(1, (n / SR - t) / fo)


def make(seed, d, pitch=1.0, weld_at=0.8, weld_len=1.3, ticks=(1.45, 1.62, 1.8), hiss_at=0.45, extras=()):
    r = np.random.default_rng(seed)
    n = int(SR * d)
    out = np.zeros(n)

    def put(x, at, g=1.0):
        i = int(SR * at)
        if i < n: out[i:i + len(x)] += x[:n - i] * g
    # hangar room tone: filtered noise and a deep hum
    t = np.arange(n) / SR
    out += (lp(r.standard_normal(n), 180 * pitch) * 0.9 + np.sin(2 * np.pi * 48 * pitch * t) * 0.10 + np.sin(2 * np.pi * 96 * pitch * t) * 0.05) * fade(n, 0.2, 0.6) * 0.5
    # gantry servo: low, muffled, rising whirr (sawtooth through a low-pass; no vibrato so it cannot sound vocal)
    ds = int(SR * 0.9)
    f = (70 + 110 * np.linspace(0, 1, ds) ** 0.8) * pitch
    saw = 2 * ((np.cumsum(f) / SR) % 1) - 1
    put(lp(saw, 450 * pitch, 3) * fade(ds, 0.12, 0.4) * 0.35, 0.05)
    # pneumatic hiss: air venting from the clamps
    dh = int(SR * 0.45)
    put(bp(r.standard_normal(dh), 3000, 9500) * env(dh, 0.02, 0.3, 2.5) * 0.4, hiss_at)
    # welding arc: hiss with a flicker and crackle pops
    dw = int(SR * weld_len)
    hiss = bp(r.standard_normal(dw), 2500, 9500) * 0.32
    flick = np.clip(lp(r.standard_normal(dw), 45) * 20, -1, 1) * 0.5 + 0.55
    pops = np.zeros(dw)
    for _ in range(int(55 * weld_len)):
        j = r.integers(0, dw - 900); l = r.integers(60, 350)
        pops[j:j + l] += hp(r.standard_normal(l), 3000) * r.uniform(0.2, 1.0) * np.exp(-np.arange(l) / (l / 4))
    put(((hiss + lp(2 * ((np.cumsum(np.full(dw, 100.0)) / SR) % 1) - 1, 500) * 0.06) * flick + pops * 0.55) * fade(dw, 0.06, 0.5), weld_at)
    # soft metallic ticks as parts settle (short, filtered, nothing like a bang)
    for at in ticks:
        dt = int(SR * 0.09)
        tk = bp(r.standard_normal(dt), 1800 * pitch, 5500 * pitch) * env(dt, 0.0006, 0.018, 3) * 0.28
        tk += np.sin(2 * np.pi * 900 * pitch * np.arange(dt) / SR) * env(dt, 0.0006, 0.03, 3) * 0.07
        put(tk, at)
    for x, at, g in extras: put(x, at, g)  # recorded workshop layers (already filtered)
    # steel-hall reverb
    rl = int(SR * 0.8)
    ir = lp(r.standard_normal(rl), 4500) * np.exp(-np.arange(rl) / SR * 6)
    ir[0] = 0
    wet = fftconvolve(out, ir)[:n]
    wet *= np.max(abs(out)) / (np.max(abs(wet)) + 1e-9) * 0.8
    out = out * 0.85 + wet * 0.45
    out *= fade(n, 0.01, 0.35)
    out = np.tanh(out / np.max(abs(out)) * 1.5)
    return out / np.max(abs(out)) * 0.32


def save(x, name):
    wavfile.write('/tmp/_o.wav', SR, (x * 32767).astype(np.int16))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', '/tmp/_o.wav', '-c:a', 'libvorbis', '-q:a', '5', OUT + name], check=True)
    print(name, len(x) / SR)


if __name__ == '__main__':
    # building: lifting servo, hiss, a welding arc, then ticks as the parts settle
    save(make(11, 2.6), 'build.ogg')
    # scrapping: the same bay, lower and slower, a longer cutting arc, fewer ticks
    save(make(23, 2.4, pitch=0.8, weld_at=0.5, weld_len=1.5, ticks=(1.75, 1.95), hiss_at=0.3), 'scrap.ogg')
