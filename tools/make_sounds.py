#!/usr/bin/env python3
"""Synthesizes the Godot version's sound effects and ambient music (no samples needed), as Ogg Vorbis files in
godot/assets/audio/. Usage: python3 tools/make_sounds.py   (needs numpy, scipy and ffmpeg with libvorbis)."""
import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'audio')
rng = np.random.default_rng(2030)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.2, shape=3.0):
    """attack then exponential release over n samples"""
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(0, t - a) * shape / max(r, 1e-4))
    return e


def lp(x, f, order=2):
    b, a = butter(order, min(f / (SR / 2), 0.99), 'low')
    return lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = butter(order, min(f / (SR / 2), 0.99), 'high')
    return lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], 'band')
    return lfilter(b, a, x)


def tone(f, d, wave='sine', ph=0.0):
    t = t_(d)
    if callable(f):
        phase = 2 * np.pi * np.cumsum(f(t)) / SR + ph
    else:
        phase = 2 * np.pi * f * t + ph
    if wave == 'sine':
        return np.sin(phase)
    if wave == 'tri':
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if wave == 'saw':
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    return np.sign(np.sin(phase))


def noise(d):
    return rng.standard_normal(int(SR * d))


def pad(x, d):
    n = int(SR * d)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(np.pad(p, (0, n - len(p))) for p in parts)


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def save(name, x, stereo=None, q=5):
    os.makedirs(OUT, exist_ok=True)
    if stereo is not None:
        data = np.stack([x, stereo], axis=1)
    else:
        data = x
    data = np.clip(data, -1, 1)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        wavfile.write(f.name, SR, (data * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f.name, '-c:a', 'libvorbis', '-q:a', str(q), os.path.join(OUT, name + '.ogg')], check=True)
        os.unlink(f.name)
    print('wrote', name)


# ---------------- interface ----------------
def click():
    d = 0.06
    x = tone(1800, d) * env(int(SR * d), 0.001, 0.02, 4) * 0.5 + hp(noise(d), 3000) * env(int(SR * d), 0.001, 0.008, 4) * 0.25
    return norm(x, 0.5)


def select():
    d = 0.12
    x = tone(lambda t: 900 + 500 * t / 0.12, d, 'tri') * env(int(SR * d), 0.002, 0.06, 3)
    return norm(x, 0.45)


def error():
    d = 0.22
    x = tone(220, d, 'tri') * env(int(SR * d), 0.003, 0.1, 3) + tone(233, d, 'tri') * env(int(SR * d), 0.003, 0.1, 3)
    return norm(lp(x, 1800), 0.5)


def next_phase():
    parts = []
    for i, f in enumerate([523.25, 659.25, 783.99]):
        d = 0.5
        n = tone(f, d) * 0.6 + tone(f * 2, d) * 0.15
        parts.append(np.pad(n * env(int(SR * d), 0.005, 0.35, 3), (int(SR * 0.07 * i), 0)))
    return norm(mix(*parts), 0.45)


def new_year():
    parts = []
    for i, f in enumerate([392.0, 523.25, 659.25, 783.99, 1046.5]):
        d = 1.2
        n = tone(f, d) * 0.6 + tone(f * 1.5, d) * 0.1 + tone(f * 2, d) * 0.12
        parts.append(np.pad(n * env(int(SR * d), 0.01, 0.9, 3), (int(SR * 0.09 * i), 0)))
    x = mix(*parts)
    return norm(x + 0.25 * np.pad(x, (int(SR * 0.18), 0))[:len(x)], 0.5)


# ---------------- game ----------------
def dice():
    """a few dice clattering on a table"""
    d = 0.75
    x = np.zeros(int(SR * d))
    t = 0.0
    for i in range(9):
        t += rng.uniform(0.03, 0.11) * (1 + i * 0.12)
        if t > d - 0.08:
            break
        hd = 0.05
        f = rng.uniform(1800, 3600)
        h = bp(noise(hd), f * 0.6, f * 1.4) * env(int(SR * hd), 0.0005, 0.012, 5) * (1 - i * 0.08)
        h += tone(rng.uniform(600, 1100), hd) * env(int(SR * hd), 0.0005, 0.02, 5) * 0.3
        s = int(SR * t)
        x[s:s + len(h)] += h[:len(x) - s]
    return norm(x, 0.6)


def success():
    parts = []
    for i, f in enumerate([659.25, 987.77]):
        d = 0.6
        n = (tone(f, d) + 0.3 * tone(f * 2.01, d)) * env(int(SR * d), 0.004, 0.4, 3)
        parts.append(np.pad(n, (int(SR * 0.09 * i), 0)))
    return norm(mix(*parts), 0.45)


def failure():
    d = 0.55
    x = tone(lambda t: 330 - 140 * t / 0.55, d, 'tri') * env(int(SR * d), 0.005, 0.35, 3)
    return norm(lp(x, 2200), 0.42)


def launch():
    """rocket ignition: a rising rumble with crackle"""
    d = 2.6
    n = noise(d)
    rumble = lp(n, 160, 3) * 2.5
    roar = bp(n, 300, 2500) * 0.6
    crackle = hp(n, 4000) * (rng.random(len(n)) < 0.02) * 2
    t = t_(d)
    e = np.minimum(1, t / 0.35) * np.exp(-np.maximum(0, t - 1.0) * 1.6)
    sweep = tone(lambda t: 60 + 50 * t, d) * 0.4
    x = (rumble + roar * (0.4 + 0.6 * np.minimum(1, t / 1.2)) + crackle + sweep) * e
    return norm(x, 0.7)


def move():
    """a short engine burn"""
    d = 0.9
    n = noise(d)
    t = t_(d)
    x = (lp(n, 400) * 1.6 + bp(n, 600, 2400) * 0.35) * np.minimum(1, t / 0.08) * np.exp(-t * 3.2)
    return norm(x, 0.55)


def explore():
    """a sonar ping with a soft echo"""
    d = 1.5
    p = tone(1320, d) * env(int(SR * d), 0.003, 0.5, 4) + tone(1980, d) * env(int(SR * d), 0.003, 0.25, 4) * 0.3
    x = p + 0.35 * np.pad(p, (int(SR * 0.28), 0))[:len(p)] + 0.15 * np.pad(p, (int(SR * 0.56), 0))[:len(p)]
    return norm(x, 0.45)


def found():
    """discovery: a bright arpeggio over a shimmer"""
    parts = []
    for i, f in enumerate([523.25, 783.99, 1046.5, 1567.98]):
        d = 1.4
        n = (tone(f, d) + 0.25 * tone(f * 3, d)) * env(int(SR * d), 0.004, 1.0, 3)
        parts.append(np.pad(n, (int(SR * 0.08 * i), 0)))
    sh = hp(noise(1.8), 6000) * env(int(SR * 1.8), 0.3, 1.2, 2) * 0.15
    return norm(mix(*parts, sh), 0.5)


def alarm():
    d = 1.2
    t = t_(d)
    f = lambda t: 620 + 200 * (np.sin(2 * np.pi * 3.2 * t) > 0)
    x = tone(f, d, 'tri') * np.minimum(1, t / 0.02) * np.exp(-np.maximum(0, t - 0.8) * 8)
    return norm(lp(x, 2500), 0.4)


def boom():
    d = 1.6
    n = noise(d)
    t = t_(d)
    x = lp(n, 220, 3) * 3 * np.exp(-t * 2.4) + bp(n, 400, 3000) * np.exp(-t * 7) * 0.8 + tone(lambda t: 70 - 30 * t, d) * np.exp(-t * 3) * 0.8
    return norm(x, 0.75)


def build():
    """a spaceport engineering bay, ~2.4 s: hangar room tone, a heavy servo lift, pneumatic hiss and welding,
    a latch clunk and a welding arc, all in a reverberant steel space"""
    from scipy.signal import fftconvolve
    D = 2.4
    n = int(SR * D)
    dry = np.zeros(n)

    def put(x, at, g=1.0):
        i = int(SR * at)
        if i >= n:
            return
        x = x[:n - i]
        dry[i:i + len(x)] += x * g
    # hangar room tone: a low rumble under everything
    rum = lp(noise(D), 220) * 0.55 + tone(52, D) * 0.12 + tone(104, D) * 0.05
    put(rum * env(n, 0.15, 1.2, 1.4), 0.0)
    # heavy servo: a gantry arm lifting (pitch rises, slight wobble), 0.05-0.95 s
    d = 0.9
    tt = t_(d)
    servo = tone(lambda x: 85 + 150 * (x / d) ** 0.8, d, 'saw') * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * tt))
    servo = lp(servo, 900) * env(int(SR * d), 0.08, 0.5, 2.0) * 0.32
    put(servo, 0.05)
    # pneumatic hiss as the clamps pressurise
    put(bp(noise(0.5), 2200, 9000) * env(int(SR * 0.5), 0.02, 0.32, 2.5) * 0.35, 0.35)
    # welding: a hissing arc with a flickering buzz and crackle pops, 0.75-1.45 s
    d = 0.7
    nw = int(SR * d)
    hiss = bp(noise(d), 2500, 9500) * 0.22
    flick = np.clip(lp(rng.standard_normal(nw), 45) * 20, -1, 1) * 0.5 + 0.55
    arc = lp(tone(100, d, 'saw'), 600) * 0.06
    pops = np.zeros(nw)
    for _ in range(45):
        i = rng.integers(0, nw - 800)
        L = rng.integers(60, 350)
        pops[i:i + L] += hp(rng.standard_normal(L), 3000) * rng.uniform(0.2, 1.0) * np.exp(-np.arange(L) / (L / 4))
    weld = ((hiss + arc) * flick + pops * 0.45) * env(nw, 0.03, 0.6, 2.2)
    put(weld, 0.75)
    # a heavy latch clunk and a metallic ring
    cl = (tone(95, 0.35) + 0.8 * tone(210, 0.35) + 0.5 * tone(540, 0.35)) * env(int(SR * 0.35), 0.0008, 0.16, 4.0)
    put(cl * 0.8, 1.52)
    put(bp(noise(0.06), 800, 5000) * env(int(SR * 0.06), 0.0004, 0.02, 4.0) * 0.7, 1.52)
    ring = (tone(1480, 0.5) + 0.5 * tone(2310, 0.5)) * env(int(SR * 0.5), 0.0006, 0.3, 5.0)
    put(ring * 0.1, 1.54)
    # reverberant steel space: a bright-then-dark decaying noise tail convolved with the dry sound
    rl = int(SR * 0.9)
    tr = np.arange(rl) / SR
    ir = lp(rng.standard_normal(rl), 5000) * np.exp(-tr * 5.5)
    ir[0] = 0
    wet = fftconvolve(dry, ir)[:n]
    wet *= np.max(np.abs(dry)) / (np.max(np.abs(wet)) + 1e-9) * 0.9
    out = dry * 0.8 + wet * 0.55
    # fade out so it ends cleanly within the length
    out *= np.minimum(1.0, (n - np.arange(n)) / (SR * 0.25))
    out = np.tanh(out / np.max(np.abs(out)) * 2.6)  # glue and lift the quieter servo and wrench parts
    return norm(out, 0.32)


def scrap():
    """scrapping: a crunch of metal and a falling clatter"""
    D = 0.9
    crunch = bp(noise(0.35), 300, 4500) * env(int(SR * 0.35), 0.002, 0.14, 4) * 0.8
    thud = tone(lambda x: 150 - 90 * x / 0.3, 0.3) * env(int(SR * 0.3), 0.002, 0.18, 4)
    out = np.zeros(int(SR * D))
    out[:len(crunch)] += crunch
    out[:len(thud)] += thud * 0.9
    for k, at in enumerate((0.3, 0.42, 0.55, 0.66)):
        d = 0.14
        c = (tone(900 - 120 * k, d) + 0.5 * tone(2300 - 200 * k, d)) * env(int(SR * d), 0.0006, 0.06, 5) * (0.55 - 0.1 * k)
        i = int(SR * at)
        out[i:i + len(c)] += c
    return norm(out, 0.55)


def coins():
    parts = []
    for i in range(4):
        d = 0.25
        f = rng.uniform(2400, 3400)
        n = (tone(f, d) + 0.5 * tone(f * 1.5, d)) * env(int(SR * d), 0.001, 0.08, 4)
        parts.append(np.pad(n, (int(SR * 0.05 * i), 0)))
    return norm(mix(*parts), 0.35)


# ---------------- ambient music ----------------
def music(d=96.0):
    """a slow space pad: detuned chords that drift between four harmonies, a low drone, filtered wind and
    distant shimmering bells. Seamless loop (it fades into its own start)."""
    t = t_(d)
    n = len(t)
    chords = [[110.0, 164.81, 220.0, 277.18, 329.63], [98.0, 146.83, 196.0, 246.94, 293.66],
              [87.31, 130.81, 174.61, 220.0, 261.63], [103.83, 155.56, 207.65, 261.63, 311.13]]
    seg = d / len(chords)
    L = np.zeros(n)
    R = np.zeros(n)
    for ci, ch in enumerate(chords):
        # each chord swells in over the previous one (raised cosine windows, wrapping round the loop)
        cpos = ci * seg
        w = np.zeros(n)
        for k in (-1, 0, 1):
            c = cpos + k * d
            dt = (t - c) / (seg * 1.1)
            w += np.where(np.abs(dt) < 1, 0.5 + 0.5 * np.cos(np.pi * dt), 0)
        for j, f in enumerate(ch):
            for det, pan in ((-0.25, 0.25), (0.25, 0.75)):
                ff = f * 2 ** (det / 12)
                lfo = 1 + 0.003 * np.sin(2 * np.pi * (0.05 + 0.01 * j) * t + j)
                v = (np.sin(2 * np.pi * ff * t * lfo) + 0.18 * np.sin(4 * np.pi * ff * t * lfo)) * w * (0.16 if j else 0.22)
                L += v * (1 - pan)
                R += v * pan
    drone = (np.sin(2 * np.pi * 55 * t) * 0.25 + np.sin(2 * np.pi * 55.15 * t) * 0.2) * (0.7 + 0.3 * np.sin(2 * np.pi * t / d * 2))
    L += drone
    R += drone
    wind = lp(noise(d), 700, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * t / d * 3)) * 0.35
    L += wind
    R += np.roll(wind, 4410)
    # bells: soft high notes from the pentatonic scale, here and there
    scale = [880.0, 987.77, 1108.73, 1318.51, 1479.98, 1760.0]
    for i in range(int(d / 4.5)):
        st = rng.uniform(0, d - 4)
        f = scale[rng.integers(len(scale))]
        bd = 4.0
        b = (np.sin(2 * np.pi * f * t_(bd)) + 0.3 * np.sin(2 * np.pi * f * 2.01 * t_(bd))) * env(int(SR * bd), 0.02, 2.5, 3) * 0.1
        s = int(SR * st)
        pan = rng.uniform(0.2, 0.8)
        L[s:s + len(b)] += b * (1 - pan)
        R[s:s + len(b)] += b * pan
    # a simple reverb: a few delayed, filtered copies
    for dl, g in ((0.11, 0.35), (0.23, 0.25), (0.37, 0.18), (0.53, 0.12)):
        k = int(SR * dl)
        L += lp(np.roll(R, k), 2500) * g
        R += lp(np.roll(L, k + 300), 2500) * g
    L = lp(L, 5000)
    R = lp(R, 5000)
    m = max(np.max(np.abs(L)), np.max(np.abs(R)))
    return L / m * 0.6, R / m * 0.6


if __name__ == '__main__':
    only = os.environ.get('ONLY')
    for name, fn in [('click', click), ('select', select), ('error', error), ('next', next_phase), ('year', new_year),
                     ('dice', dice), ('success', success), ('failure', failure), ('launch', launch), ('move', move),
                     ('explore', explore), ('found', found), ('alarm', alarm), ('boom', boom), ('build_synth', build), ('scrap_synth', scrap), ('coins', coins)]:
        if only and name not in only.split(','): continue
        save(name, fn())
    if not only:
        l, r = music()
        save('music_space', l, r, q=4)
