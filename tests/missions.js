// Bot mission priority: bots build/research/explore toward their personal mission, then the common one, then their own leanings.
// Usage: node tests/missions.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
const AI = require(path.join(dir, 'ai.js'))(E, D);
let bad = 0; const fail = m => { bad++; console.log('FAIL', m); };
const facs = ['na', 'ru', 'eu', 'jp', 'cn', 'as', 'sa']; let done = 0, games = 0, focus = 0;
for (let g = 0; g < 7; g++) {
  const human = facs[g], H = E.newWorld({ human, bots: facs.filter(f => f !== human).map(f => ({ f })) });
  AI.autoPlay(H, 60000); games++;
  Object.values(H.world.facs).forEach(F => { done += F.mis.done; if (F.f !== human && F.log.some(l => /^Mission focus: /.test(l.t))); });
}
if (done / games < 30) fail('bots complete too few missions: ' + (done / games).toFixed(1) + ' per game');
// a crewed-only goal makes the bot build a crew vehicle
const H = E.newWorld({ human: 'na', bots: [{ f: 'ru' }] }), R = H.world.facs.ru;
R.mis.mine = D.MIS.findIndex(m => m.w === 'mar' && m.cv); R.mis.common = null; R.tech.orb = 1;
const goals = R.mis.mine; if (goals < 0) fail('no crewed Mars mission'); else {
  R.ships.filter(s => s.cls === 'CV').forEach(s => R.ships.splice(R.ships.indexOf(s), 1));
  R.phase = 'build'; R.estep = null; R.cash = 60; AI.botPhase(R);
  if (!R.log.some(l => /^Mission focus: .*crew vehicle/.test(l.t))) fail('no mission focus log line');
  if (!R.ships.some(s => s.cls === 'CV' && s.ev > 0)) fail('no crew explorer built for a crewed mission goal');
}
console.log(bad ? 'FAILED' : 'ALL OK', `(${(done / games).toFixed(1)} missions per game)`);
process.exit(bad ? 1 : 0);
