"""Build web assets for the Stellar Horizons prototype from the Vassal module images.
Usage: python3 -I build_assets.py <vm_dir> <out_dir> <zones.json> <units.json>
Outputs: maps/*.webp, atlas_<fac>.webp + json, markers.webp + json, boards/*.webp, geo.json
"""
import sys, os, json, glob, re
from PIL import Image

VM, OUT, ZONES, UNITS = sys.argv[1:5]
IMG = os.path.join(VM, 'images')
SC = 0.4  # map scale
os.makedirs(os.path.join(OUT, 'maps'), exist_ok=True)
os.makedirs(os.path.join(OUT, 'boards'), exist_ok=True)

# ---------- map sections in a 3x3 grid ----------
rows = [['A', 'B', 'C'], ['D', 'E', 'F'], ['G', 'H', 'I']]
offs = {}
y = 0
for r in rows:
    x = 0
    for c in r:
        im = Image.open(os.path.join(IMG, 'Map %s4200.jpg' % c)).convert('RGB')
        w, h = im.size
        im = im.resize((round(w * SC), round(h * SC)), Image.LANCZOS)
        im.save(os.path.join(OUT, 'maps', c + '.webp'), 'WEBP', quality=72, method=6)
        offs[c] = (x, y, im.size[0], im.size[1])
        x += im.size[0]
    y += round(3360 * SC)

zones = json.load(open(ZONES))

def cen(pts):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return [(min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2]

def tx(c, p):
    ox, oy = offs[c][:2]
    return [round(ox + p[0] * SC, 1), round(oy + p[1] * SC, 1)]

def poly(c, pts):
    return [tx(c, p) for p in pts]

Z = {}
for b, zs in zones.items():
    c = b[-1]
    for n, pts in zs:
        if len(pts) < 3:
            continue
        Z[n.replace('&amp;', '&').strip()] = (c, pts)

def z(name):
    return Z[name]

# system: key, zone prefix for approach/flyby
SYSZ = {
    'mer': 'Mercury', 'ven': 'Venus', 'ear': 'Earth', 'mar': 'Mars', 'bel': 'Main Asteroid Belt', 'jup': 'Jupiter',
    'sat': 'Saturn', 'ura': 'Uranus', 'nep': 'Neptune', 'kui': 'Kuiper Belt', 'sca': 'Scattered Disk', 'alp': 'Alpha Centauri'}
geo = {'maps': {c: offs[c] for c in offs}, 'sys': {}, 'worlds': {}}
for k, pre in SYSZ.items():
    fl = [n for n in Z if n.startswith(pre) and 'Flyby' in n][0]
    c, pts = Z[fl]
    boxes = {}
    for i in range(1, 7):
        cand = [n for n in Z if n.startswith(pre) and re.search(r'Approach\s+%d$' % i, n)]
        cc, pp = Z[cand[0]]
        boxes[i] = tx(cc, cen(pp))
    geo['sys'][k] = {'flyby': tx(c, cen(pts)), 'flybyPoly': poly(c, pts), 'box': boxes}

# worlds: key -> (orbit zone, surface zone or None, explore zone)
WZ = {
    'mer': ('Mercury Orbit (severe radiation)', 'Mercury Surface (severe radiation)', "Mercury's exploration"),
    'ven': ('Venus Orbit', 'Venus Surface', "Venus's Exploration"),
    'ear': ('Earth Orbit', 'Earth Surface', None),
    'moo': ('Luna Orbit', 'Luna Surface', "Moon's Exploration"),
    'nea': ('Near Earth Asteroids', None, 'Near Earth Asteroids Exploration'),
    'mar': ('Mars Orbit', 'Mars Surface', "Mar's Exploration"),
    'pho': ('Phobos - Deimos', None, 'Phobos - Deimos Exploration'),
    'com': ('Comet', None, 'Comet Exploration'),
    'bel': ('Main Asteroid Belt', None, None),
    'cer': ('Ceres', None, "Ceres's Exploration"),
    'hyg': ('Hygeia - Pallas', None, 'Hygeia - Pallas Exploration'),
    'ves': ('Vesta', None, "Vesta's Exploration"),
    'jup': ('Jupiter Orbit', 'Jupiter Surface (Severe Radiation, No CV, No Rover, Severe Atmosphere, High Gravity)', "Jupiter's Exploration"),
    'io': ('Io (Severe radiation)', None, "Io's Exploration"),
    'eur': ('Europa (Severe radiation)', None, "Europa's Exploration"),
    'gan': ('Ganymede', None, None),
    'cal': ('Callisto Orbit', 'Callisto Surface', "Callisto's Exploration"),
    'tro': ('Trojans & Greeks', None, 'Trojans & Greeks Exploration'),
    'sat': ('Saturn Orbit', None, "Saturn's Exploration"),
    'mim': ('Mimas - Enceladus - Tethys', None, 'Mimas - Enceladus - Tethys Exploration'),
    'dio': ('Dione - Rhea', None, 'Dione - Rhea Exploration'),
    'tit': ('Titan', None, "Titan's Exploration"),
    'hyp': ('Hyperion - Iapetus', None, 'Hyperion - Iapetus Exploration'),
    'ura': ('Uranus Orbit', 'Uranus', "Uranus's Exploration"),
    'cha': ('Chariklo', None, "Chariklo's Exploration"),
    'obe': ('Oberion - Titania', None, 'Oberion - Titania Exploration'),
    'umb': ('Umbriel - Ariel - Miranda', None, 'Umbriel - Ariel - Miranda Exploration'),
    'nep': ('Neptune', None, 'Neptune Exploration'),
    'tri': ('Triton', None, "Triton's Exploration"),
    'kui': ('Kuiper Belt', None, 'Kuiper Belt Exploration'),
    'hau': ('Haumea - Makemake', None, 'Haumea - Makemake Exploration'),
    'plu': ('Pluto - Charon', None, 'Pluto - Charon Exploration'),
    'sca': ('Scattered Disk', None, None),
    'sed': ('Sedna', None, "Sedna's Exploration"),
    'eri': ('Eris & Dysnomia', None, 'Eris & Dysnomia Exploration'),
    'alp': ('Alpha Centauri', None, 'Alpha Centauri Exploration'),
    'dsa': (None, None, 'Deep Space Astronomy Exploration'),
}
for k, (o, s, e) in WZ.items():
    g = {}
    if o:
        c, pts = Z[o]; g['orbit'] = tx(c, cen(pts)); g['poly'] = poly(c, pts)
    if s:
        c, pts = Z[s]; g['surf'] = tx(c, cen(pts)); g['spoly'] = poly(c, pts)
    if e and e in Z:
        c, pts = Z[e]; g['exp'] = tx(c, cen(pts))
    geo['worlds'][k] = g
# Galatea has no zone: place it below-right of Neptune by hand (Map G lower right)
gx, gy = offs['G'][:2]
geo['worlds']['gal'] = {'orbit': [round(gx + 2150 * SC), round(gy + 3050 * SC)]}
# DSA: centre on its exploration box
geo['worlds']['dsa']['orbit'] = geo['worlds']['dsa']['exp']
json.dump(geo, open(os.path.join(OUT, 'geo.json'), 'w'))

# ---------- counter atlases ----------
PFX = {'na': 'NA', 'ru': 'Ru', 'eu': 'Eu', 'jp': 'Jp', 'cn': 'Ci', 'as': 'As', 'sa': 'SA'}
units = json.load(open(UNITS))
CS = 96

def find(pat):
    g = glob.glob(os.path.join(IMG, pat))
    return g[0] if g else None

def fuzzy(prefix, kind, name):
    # exact, then case-insensitive, then first-4-letter match
    cand = glob.glob(os.path.join(IMG, '%s %s *' % (prefix, kind)))
    cand = [c for c in cand if not re.search(r' rv\.| b\.| orbit\.', os.path.basename(c), re.I)]
    nm = {'baolei':'yunbaolei','tereshkova':'tershkova','sakharov':'','tanka':'tanaka','artemis':'artmis','liaoning':'lioaning'}.get(name.lower().replace(' ',''), name.lower().replace(' ', ''))
    if prefix=='Ru' and kind=='Telescope': return find('Ru Telescope.*')
    best = None
    for c in cand:
        base = os.path.basename(c)[len(prefix) + len(kind) + 2:].rsplit('.', 1)[0].lower().replace(' ', '')
        if base == nm:
            return c
        if base[:4] == nm[:4] and best is None:
            best = c
    return best

def back(front):
    b, ext = front.rsplit('.', 1)
    for suf in [' rv.', ' b.']:
        for e2 in ['jpg', 'png']:
            p = b + suf + e2
            if os.path.exists(p):
                return p
    # odd names (e.g. 'Jp CV-6 Tako rv')
    d = os.path.dirname(front); bn = os.path.basename(b)
    g = glob.glob(os.path.join(d, bn[:bn.rfind(' ') + 4] + '* rv.*'))
    return g[0] if g else None

from collections import OrderedDict
for fk, pre in PFX.items():
    items = OrderedDict()
    for u in units[fk]:
        kind = u['k']
        f = fuzzy(pre, kind, u['n'])
        if not f:
            print('MISSING', fk, kind, u['n'])
            continue
        items['%s|%s' % (kind, u['n'])] = f
        bk = back(f)
        if bk:
            items['%s|%s|back' % (kind, u['n'])] = bk
    for i in range(1, 5):
        f = find('%s LV-%d.*' % (pre, i))
        if f:
            items['LV-%d' % i] = f
    for f in sorted(glob.glob(os.path.join(IMG, '%s Base *' % pre))):
        bn = os.path.basename(f).rsplit('.', 1)[0][len(pre) + 6:]
        items['Base|' + bn] = f
    n = len(items); cols = 12; rws = (n + cols - 1) // cols
    atlas = Image.new('RGBA', (cols * CS, rws * CS), (0, 0, 0, 0))
    frames = {}
    for i, (key, f) in enumerate(items.items()):
        im = Image.open(f).convert('RGBA').resize((CS, CS), Image.LANCZOS)
        x, y = (i % cols) * CS, (i // cols) * CS
        atlas.paste(im, (x, y)); frames[key] = [x, y, CS, CS]
    atlas.save(os.path.join(OUT, 'atlas_%s.webp' % fk), 'WEBP', quality=82, method=6)
    json.dump(frames, open(os.path.join(OUT, 'atlas_%s.json' % fk), 'w'))
    print(fk, n, 'counters', atlas.size)

# ---------- markers atlas ----------
MK = [('tech_Phy_%d' % v, 'Tech Physics %d' % v) for v in (1, 2, 3, 5)] + \
     [('tech_Eng_%d' % v, 'Tech Engineering %d' % v) for v in (1, 2, 3, 5)] + \
     [('tech_Bio_%d' % v, 'Tech Biology %d' % v) for v in (1, 2, 3, 5)] + \
     [('pol', 'Politics x1'), ('vm', 'Victory 1'), ('set', 'Settlement 1'), ('sol', 'Signs of Life'), ('life', 'Life'),
      ('pir_s', 'Pirate Sm'), ('pir_l', 'Pirate Lg'), ('ast', 'Asteroid'), ('dam', 'Dam 1'),
      ('mine_s', 'Mining Station Small'), ('mine_l', 'Mining Station Large'), ('ref_s', 'Refinery Small'), ('ref_l', 'Refinery Large'),
      ('lab_s', 'Research Station Small'), ('lab_l', 'Research Station Large'), ('sup_s', 'Supply Station Small'), ('sup_l', 'Supply Station Large'),
      ('port_s', 'Spaceport Small'), ('port_l', 'Spaceport Large'),
      ('buy_FUEL', 'Buy Fuel'), ('buy_ORE', 'Buy Resources'), ('buy_SUP', 'Buy Supplies'), ('sell_FUEL', 'Sell Fuel'), ('sell_ORE', 'Sell Resources'), ('sell_SUP', 'Sell Supplies'),
      ('mission', 'Mission Mask'), ('done', 'Mission Complete')] + \
     [('n%d' % i, 'Number %d' % i) for i in range(0, 21)]
for f in sorted(glob.glob(os.path.join(IMG, 'Mission *.png'))):
    bn = os.path.basename(f)[8:-4]
    if bn in ('Mask', 'Complete'):
        continue
    MK.append(('mis_' + bn, f))
CARDS = ['Chasms', 'Cratered Surface', 'Escarpments', 'Frozen Methane', 'Helium-3', 'Hematite', 'Hydrogen', 'Impact Basin', 'Maria', 'Mixed Ice',
         'Precious Metals', 'Ridged Terrain', 'Silicate Rocks', 'Subterrain Water', 'Valcanoes', 'Volatile Atmosphere', 'Water Ice',
         'C-Class Asteroid', 'M-Class Asteroid', 'S-Class Asteroid']
frames = {}
tiles = []
for key, nm in MK:
    f = nm if os.path.isabs(nm) else find(nm + '.*')
    if not f:
        print('missing marker', nm); continue
    tiles.append((key, Image.open(f).convert('RGBA').resize((CS, CS), Image.LANCZOS)))
for nm in CARDS:
    f = find(nm + '.*')
    tiles.append(('card_' + nm, Image.open(f).convert('RGBA').resize((CS * 2, round(CS * 2 * 244 / 370)), Image.LANCZOS)))
cols = 16
# simple shelf packing
W = cols * CS
x = y = sh = 0
pos = []
for key, im in tiles:
    if x + im.size[0] > W:
        x = 0; y += sh; sh = 0
    pos.append((key, im, x, y)); x += im.size[0]; sh = max(sh, im.size[1])
atlas = Image.new('RGBA', (W, y + sh), (0, 0, 0, 0))
for key, im, x, y in pos:
    atlas.paste(im, (x, y)); frames[key] = [x, y, im.size[0], im.size[1]]
atlas.save(os.path.join(OUT, 'markers.webp'), 'WEBP', quality=82, method=6)
json.dump(frames, open(os.path.join(OUT, 'markers.json'), 'w'))
print('markers', len(frames), atlas.size)

# ---------- faction boards, tech tree, policy table ----------
for fk, nm in [('na', 'North America'), ('ru', 'Russia'), ('eu', 'Europe'), ('jp', 'Japan'), ('cn', 'China'), ('as', 'Asia'), ('sa', 'South America')]:
    im = Image.open(os.path.join(IMG, 'PC %s.jpg' % nm)).convert('RGB')
    im.thumbnail((1400, 1400), Image.LANCZOS)
    im.save(os.path.join(OUT, 'boards', fk + '.webp'), 'WEBP', quality=72, method=6)
for src, dst, w in [('Tech_Tree_Track.jpg', 'tech', 1500), ('Policy Tree.jpg', 'policy', 900)]:
    im = Image.open(os.path.join(IMG, src)).convert('RGB'); im.thumbnail((w, w * 2), Image.LANCZOS)
    im.save(os.path.join(OUT, 'boards', dst + '.webp'), 'WEBP', quality=72, method=6)
print('done')
