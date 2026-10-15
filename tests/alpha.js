// Alpha Centauri: a d10 rolled after each successful exploration picks the field (1-4 Phy 3%, 5-7 Eng 5%, 8-10 Bio 10%). Usage: node tests/alpha.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
let bad = 0; const ok = (c, m) => { if (!c) { bad++; console.log('FAIL', m); } else console.log('ok  ', m); };
const seen = { Phy: 0, Eng: 0, Bio: 0 }; let fails = 0, good = 0, mism = 0;
for (let t = 0; t < 400; t++) {
  const G = E.newGame('na'), s = G.ships.find(x => x.kind === 'Orbiter');
  s.loc = 'orbit:alp'; s.fixed = true; s.ev = 40; G.phase = 'explore'; G.turn.acted = {}; G.w.alp.v = 5;
  const o = E.exploreOptions(G, s).find(x => x.w === 'alp'); if (!o) { ok(false, 'alp explore option exists'); break; }
  E.explore(G, s, { w: 'alp', kind: o.kind });
  const L = G.lastRoll;
  if (!L.ok) { fails++; if (L.alpha) mism++; continue; }
  good++; seen[L.field]++;
  const a = D.ALPHA.find(x => L.alpha <= x[0]);
  if (!L.alpha || a[1] !== L.field) mism++;
}
ok(good > 0 && mism === 0, `field follows the d10 roll after every success (${good} successes, ${fails} failures)`);
ok(seen.Phy > 0 && seen.Eng > 0 && seen.Bio > 0, `all three fields occur ${JSON.stringify(seen)}`);
process.exit(bad ? 1 : 0);
