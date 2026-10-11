"""Open gaps between the map sections so world cards and bases fit beside their World Boxes.
Shifts every geo.json coordinate with its section. Re-runnable: original tiling is kept in geo['maps0'].
Usage: python3 tools/spread_map.py ROW_GAP COL_GAP"""
import json, sys
geo = json.load(open('geo.json'))
RG, CG = float(sys.argv[1]), float(sys.argv[2])
if 'maps0' not in geo: geo['maps0'] = {c: list(v) for c, v in geo['maps'].items()}
M0 = geo['maps0']
rows = sorted({v[1] for v in M0.values()})
new = {}
for c, (x, y, w, h) in M0.items():
    r = rows.index(y); same = sorted([k for k, v in M0.items() if v[1] == y], key=lambda k: M0[k][0]); ci = same.index(c)
    new[c] = [x + ci * CG, y + r * RG, w, h]
def sec0(p):
    # which section the point belongs to, judged in the ORIGINAL tiling (points slightly outside go to the nearest)
    cur = geo['maps']
    best = None
    for c, (x, y, w, h) in cur.items():
        dx = max(x - p[0], 0, p[0] - (x + w)); dy = max(y - p[1], 0, p[1] - (y + h)); d = dx + dy
        if best is None or d < best[0]: best = (d, c)
    return best[1]
def shift_pt(p, d): return [round(p[0] + d[0], 1), round(p[1] + d[1], 1)] + list(p[2:])
def delta(c): return (new[c][0] - geo['maps'][c][0], new[c][1] - geo['maps'][c][1])
def walk(v, d):
    if isinstance(v, list) and v and isinstance(v[0], (int, float)): return shift_pt(v, d)
    if isinstance(v, list): return [walk(q, d) for q in v]
    if isinstance(v, dict): return {k: walk(q, d) for k, q in v.items()}
    return v
for k, w in geo['worlds'].items():
    d = delta(sec0(w.get('orbit') or w.get('exp')))
    for f in list(w):
        if f in ('circ',): continue
        if f == 'wcard': w[f] = shift_pt(w[f][:2], d) + w[f][2:]; continue
        w[f] = walk(w[f], d)
for k, s in geo['sys'].items():
    d = delta(sec0(s['flyby']))
    for f in list(s): s[f] = walk(s[f], d) if f != 'boxFit' else {n: shift_pt(v[:2], d) + v[2:] for n, v in s[f].items()}
geo['maps'] = new
json.dump(geo, open('geo.json', 'w'), separators=(',', ':'))
print(new)
