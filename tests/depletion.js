// Depletion rule check over many random explorations: robotic explorers/probes deplete when any single earned marker
// is 3 or more (errata; at most once); crewed vehicles when the earned markers total 3 or more. Usage: node tests/depletion.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
let bad = 0, seen = { re3: 0, re5: 0, cv3: 0, cvLow: 0 };
for (let t = 0; t < 3000; t++) {
  const G = E.newGame('na'), cv = t % 2 === 1;
  const s = cv ? G.ships.find(x => x.cls === 'CV') : G.ships.find(x => x.kind === 'Orbiter');
  s.loc = 'orbit:mar'; s.fixed = true; s.res = false; s.dmg = 0; s.ev = 1 + (t % 25); G.phase = 'explore'; G.turn.acted = {};
  const before = G.w.mar.v; E.explore(G, s, { w: 'mar', kind: 'explore' });
  const got = G.lastRoll.got, dep = before - G.w.mar.v, total = got.reduce((a, b) => a + b, 0);
  const want = cv ? (total >= 3 ? 1 : 0) : (got.some(v => v >= 3) ? 1 : 0); // errata: a 5 marker counts as '3 or more'
  if (dep !== want) { bad++; if (bad < 5) console.log('FAIL', cv ? 'CV' : 'RE', got, 'depleted', dep, 'expected', want); }
  if (!cv && got.filter(v => v === 3).length > 1) seen.re3++; if (!cv && got.includes(5) && !got.includes(3)) seen.re5++;
  if (cv && total >= 3 && !got.some(v => v >= 3)) seen.cv3++; if (cv && got.length && total < 3) seen.cvLow++;
}
console.log('cases seen:', JSON.stringify(seen));
console.log(bad ? bad + ' FAILED' : 'ALL OK'); process.exit(bad ? 1 : 0);
