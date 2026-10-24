// Plays a seeded all-bot campaign with the web engine and writes every faction's log, for comparison with the Godot port.
// Usage: node tools/parity_dump.js <seed> <out.json> [maxSteps]
const path = require('path'), fs = require('fs');
const root = path.join(__dirname, '..');
const D = require(path.join(root, 'data.js'));
const UNITS = require(path.join(root, 'units.json'));
const E = require(path.join(root, 'rules.js'))(D, UNITS);
const AI = require(path.join(root, 'ai.js'))(E, D);
const seed0 = +(process.argv[2] || 1), out = process.argv[3] || 'parity_js.json', maxSteps = +(process.argv[4] || 50000);
let seed = seed0 % 2147483647; if (seed <= 0) seed += 2147483646;
E.R.rnd = () => { seed = (seed * 48271) % 2147483647; return seed / 2147483647; };
const facs = D.FAC_ORDER;
const bots = facs.slice(1).map(f => ({ f, variant: f === 'cn' && seed0 % 2 === 0 ? 'rob' : null }));
const ALL = [];
const origUnshift = Array.prototype.unshift;
// record every log line: G.log arrays are wrapped as they are created (newGame) and when attached
const H = E.newWorld({ human: facs[0], bots, scrapRE: seed0 % 3 === 0, enhTrade: seed0 % 4 === 0 });
// newWorld already logged a line on the human faction; wrap each faction's log from here on
for (const g of Object.values(H.world.facs)) { g.log.unshift = function (...a) { a.forEach(e => ALL.push(g.f + '|' + e.y + '|' + e.t)); return origUnshift.apply(this, a); }; }
const t0 = Date.now();
const steps = AI.autoPlay(H, maxSteps);
const o = { steps, year: H.y, facs: {}, all: ALL };
for (const f of Object.keys(H.world.facs)) {
  const g = H.world.facs[f];
  o.facs[f] = { cash: g.cash, vm: g.vm, polm: g.polm, score: E.score(g).total, ships: g.ships.map(s => s.name + '@' + s.loc), bases: g.bases.map(b => b.name + '@' + b.w + ':' + b.set), tech: Object.keys(g.tech), log: g.log.map(l => l.y + '|' + (l.c || '') + '|' + l.t).reverse() };
}
fs.writeFileSync(out, JSON.stringify(o, null, 1));
console.log('steps', steps, 'year', H.y, 'in', Date.now() - t0, 'ms');
