"""Builds build.ogg and scrap.ogg from a repair-shop recording (usage: make_build_workshop.py shop.mp3).
Only the bright, tool-like parts of the recording are used (high-passed at 3 kHz so no voices or speech formants come
through): grinder/air-tool texture and a few tool clinks. The hangar rumble, servo and welding arc are synthesized
(make_build_synth.py), then everything goes through a steel-hall reverb."""
import subprocess, sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter, spectrogram
sys.path.insert(0, 'tools')
import make_build_synth as S

SR = S.SR
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', sys.argv[1], '-ar', str(SR), '-ac', '1', '/tmp/_shop.wav'], check=True)
_, x = wavfile.read('/tmp/_shop.wav')
x = x.astype(float) / 32768
hpx = S.hp(x, 3000, 4)
f, t, P = spectrogram(hpx, SR, nperseg=2048, noverlap=1536)
lev = 10 * np.log10(P.sum(0) + 1e-12)
hop = t[1] - t[0]

def best_window(length, lo=1.0, hi=None, skip=()):
    w = int(length / hop)
    hi = hi or t[-1] - length
    best, bt = -1e9, lo
    for i in range(int(lo / hop), int(hi / hop)):
        if any(abs(t[i] - s) < length for s in skip): continue
        seg = lev[i:i + w]
        sc = seg.mean() - 0.5 * seg.std()  # loud and steady: grinding or an air tool, not speech bursts
        if sc > best: best, bt = sc, t[i]
    return bt

def grab(at, length, fade=0.15):
    seg = hpx[int(at * SR):int((at + length) * SR)].copy()
    n = len(seg)
    seg *= S.fade(n, fade, fade)
    return seg / (np.sqrt((seg ** 2).mean()) + 1e-9) * 0.12  # the recording is quiet: bring it to a steady level

# onsets: sharp tool clinks (a loud jump in the bright band), kept short and high-passed
clinks = []
d = np.diff(lev)
order = np.argsort(d)[::-1]
for i in order:
    tt = t[i]
    if tt < 1 or tt > t[-1] - 0.2 or any(abs(tt - c) < 1.0 for c in clinks): continue
    clinks.append(tt)
    if len(clinks) == 4: break

def clink(at):
    seg = S.hp(x[int(at * SR):int((at + 0.1) * SR)], 3500, 4)
    seg = seg * S.env(len(seg), 0.001, 0.025, 3)
    return seg / (abs(seg).max() + 1e-9) * 0.5

g1 = best_window(1.4)
g2 = best_window(1.4, skip=(g1,))
print('grind windows', g1, g2, 'clinks', clinks)
build = S.make(11, 2.6, extras=[(grab(g1, 1.4) * 0.9, 0.35, 1.0), (clink(clinks[0]), 1.5, 0.8), (clink(clinks[1]), 1.72, 0.7)])
S.save(build, 'build.ogg')
scrap = S.make(23, 2.4, pitch=0.8, weld_at=0.5, weld_len=1.5, ticks=(1.75, 1.95), hiss_at=0.3, extras=[(grab(g2, 1.4) * 0.9, 0.25, 1.0), (clink(clinks[2]), 1.7, 0.8)])
S.save(scrap, 'scrap.ogg')
