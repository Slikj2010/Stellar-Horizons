"""Builds build.ogg and scrap.ogg from a reference clip (usage: make_build_from_ref.py ref.mp3).
The clip's high-frequency noise bed is filtered out, a steel-hall reverb and a welding / cutting arc are added."""
import subprocess, sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter, fftconvolve

ref = sys.argv[1]
OUT = 'godot/assets/audio/'
SR = 44100
rng = np.random.default_rng(5)


def load(args):
    subprocess.run(['ffmpeg', '-v', 'error', '-y'] + args + ['-ar', str(SR), '-ac', '1', '/tmp/_ref.wav'], check=True)
    s, x = wavfile.read('/tmp/_ref.wav')
    return x.astype(float) / 32768


def lp(x, f, o=4):
    b, a = butter(o, f / (SR / 2)); return lfilter(b, a, x)


def hp(x, f, o=2):
    b, a = butter(o, f / (SR / 2), 'high'); return lfilter(b, a, x)


def weld(d, gain, pops_n=60, seed=1):
    r = np.random.default_rng(seed)
    n = int(SR * d)
    hiss = hp(lp(r.standard_normal(n), 9000, 2), 2500) * 0.30
    flick = np.clip(lp(r.standard_normal(n), 45, 2) * 20, -1, 1) * 0.5 + 0.55
    arc = lp(2 * ((2 * np.pi * 100 * np.arange(n) / SR / (2 * np.pi)) % 1) - 1, 700, 2) * 0.08
    pops = np.zeros(n)
    for _ in range(pops_n):
        j = r.integers(0, n - 900); l = r.integers(60, 350)
        pops[j:j + l] += hp(r.standard_normal(l), 3000) * r.uniform(.2, 1) * np.exp(-np.arange(l) / (l / 4))
    return ((hiss + arc) * flick + pops * 0.55) * gain


def finish(dry, name, peak=0.32, tail=0.3):
    n = len(dry)
    rl = int(SR * 0.8); tr = np.arange(rl) / SR
    ir = lp(rng.standard_normal(rl), 4500, 2) * np.exp(-tr * 6); ir[0] = 0
    wet = fftconvolve(dry, ir)[:n]
    wet *= np.max(abs(dry)) / (np.max(abs(wet)) + 1e-9) * 0.8
    out = dry * 0.85 + wet * 0.45
    out *= np.minimum(1, (n - np.arange(n)) / (SR * tail))
    out = np.tanh(out / np.max(abs(out)) * 1.6)
    out = out / np.max(abs(out)) * peak
    wavfile.write('/tmp/_o.wav', SR, (out * 32767).astype(np.int16))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', '/tmp/_o.wav', '-c:a', 'libvorbis', '-q:a', '5', OUT + name], check=True)
    print(name, n / SR)


def put(dry, x, at):
    i = int(SR * at)
    dry[i:i + len(x)] += x[:len(dry) - i]


# build: the clip's body up to just before its closing bangs, then a welding arc over the second half, fading out
x = load(['-ss', '0.2', '-t', '3.0', '-i', ref, '-filter:a', 'atempo=1.4'])
body = hp(lp(x, 1100), 40)
n = int(SR * 2.6)
dry = np.zeros(n)
put(dry, body * np.minimum(1, np.maximum(0, (2.15 - np.arange(len(body)) / SR) / 0.5)), 0.0)  # fade the body out before the bang
put(dry, weld(1.5, 1.0) * np.minimum(1, np.arange(int(SR * 1.5)) / (SR * 0.08)) * np.minimum(1, (np.arange(int(SR * 1.5))[::-1]) / (SR * 0.5)), 0.8)
finish(dry, 'build.ogg')

# scrap: the same material pitched down and slowed (taking something apart), a cutting arc, then a soft metal settle
x = load(['-ss', '0.3', '-t', '2.4', '-i', ref, '-filter:a', 'asetrate=%d,aresample=%d,atempo=1.15' % (int(SR * 0.8), SR)])
body = hp(lp(x, 900), 40)
n = int(SR * 2.2)
dry = np.zeros(n)
put(dry, body[:n] * np.minimum(1, np.maximum(0, (1.7 - np.arange(min(len(body), n)) / SR) / 0.5)), 0.0)
cut = weld(1.3, 1.2, 90, 7)
put(dry, cut * np.minimum(1, np.arange(len(cut)) / (SR * 0.05)) * np.minimum(1, (np.arange(len(cut))[::-1]) / (SR * 0.5)), 0.15)
# the arc cutting through: a rising whine, then a quiet metal settle (no bang)
d = int(SR * 0.7)
whine = lp(np.sin(2 * np.pi * np.cumsum(np.linspace(900, 1900, d)) / SR), 3000, 2) * np.hanning(d) * 0.05
put(dry, whine, 0.2)
finish(dry, 'scrap.ogg')
