// World card is placed before the search-for-life roll. Usage: node tests/life.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
let bad = 0; const ok = (c, m) => { if (!c) { bad++; console.log('FAIL', m); } else console.log('ok  ', m); };
for (let t = 0; t < 200; t++) {
  const G = E.newGame('na'), s = G.ships.find(x => x.kind === 'Orbiter');
  s.loc = 'orbit:mar'; s.fixed = true; s.ev = 40; G.phase = 'explore'; G.turn.acted = {};
  E.explore(G, s, { w: 'mar', kind: 'explore' });
  const a = G.ask.find(q => q.k === 'card');
  if (!a || !a.opts.includes('Subterranean Water')) continue;
  ok(G.lastRoll.life && G.lastRoll.life.pending, 'life roll waits while the card decision is open');
  while (G.ask[0] !== a) G.ask.shift();
  E.answer(G, 'Subterranean Water');
  ok(G.lastRoll.kind === 'life' && G.lastRoll.life.need === 12 + 5, 'card bonus applies: needed ' + (G.lastRoll.life && G.lastRoll.life.need));
  ok(/Search for life: rolled \d+ on d100, needed 17/.test(JSON.stringify(G.log.slice(0, 3))), 'roll is in the log');
  break;
}
console.log(bad ? bad + ' FAILED' : 'ALL OK'); process.exit(bad ? 1 : 0);
