// Solo campaign with random-but-legal choices (like tests/bot.js), seeded, recording every log line, for comparison with
// the Godot port (godot/tests/parity_solo.gd). Usage: node tools/parity_solo.js <seed> <faction> <out.json>
const path = require('path'), fs = require('fs');
const root = path.join(__dirname, '..');
const D = require(path.join(root, 'data.js'));
const UNITS = require(path.join(root, 'units.json'));
const E = require(path.join(root, 'rules.js'))(D, UNITS);
const seed0 = +(process.argv[2] || 1), f = process.argv[3] || 'na', out = process.argv[4] || 'solo_js.json';
let seed = seed0 % 2147483647; if (seed <= 0) seed += 2147483646;
E.R.rnd = () => { seed = (seed * 48271) % 2147483647; return seed / 2147483647; };
const pick = a => a[Math.floor(E.R.rnd() * a.length)];
const G = E.newGame(f, { scrapRE: seed0 % 2 === 1, scenario: seed0 % 3 === 2 ? 'fut2060' : 'std', variant: seed0 % 4 === 0 ? 'rob' : 'mil' });
const ALL = [];
const origUnshift = Array.prototype.unshift;
G.log.unshift = function (...a) { a.forEach(e => ALL.push(e.y + '|' + e.t)); return origUnshift.apply(this, a); };
let steps = 0;
while (!G.over && steps < 20000) {
  steps++;
  let guard = 0;
  while (G.ask.length && guard++ < 50) {
    const a = G.ask[0];
    if (a.k === 'pirate') E.answer(G, pick(['pay', 'remove', 'surrender', 'fight', 'stay']));
    else if (a.k === 'publicity') E.answer(G, pick(Object.keys(G.w).filter(k => G.w[k].v > 0)));
    else if (a.k === 'immigration') E.answer(G, G.bases[0].id);
    else if (a.k === 'card') E.answer(G, pick([...a.opts, null]));
    else if (a.k === 'flyby') E.answer(G, pick(a.opts).sys);
    else if (a.k === 'mission') E.answer(G, pick(a.opts));
    else if (a.k === 'pbattle') E.answer(G, pick(['auto', 'avoid']));
    else if (a.k === 'assign') E.answer(G, 'auto');
    else G.ask.shift();
  }
  if (G.ask.length) G.ask.length = 0;
  if (G.phase === 'econ') {
    if (G.estep === 'diplomacy' && G.polm > 3) { const k = pick(Object.keys(G.rel)); E.setDiplomacy(G, k, pick([1, 1, -1])); }
    if (G.estep === 'tech') { for (let i = 0; i < 6; i++) { const open = D.TECH.filter(t => E.techState(G, t) === 'open' && G.bank[t.f] >= E.techCost(G, t)); if (!open.length) break; E.develop(G, pick(open).k); } while (G.polm > 0) E.convertPolitics(G, pick(['cash', 'Phy', 'Eng', 'Bio'])); }
    if (G.estep === 'policy') E.choosePolicy(G, pick(D.POL).k);
    if (G.estep === 'transport' && G.transferLeft && G.bases.length) E.transferRes(G, 'earth', G.bases[0].id, 'SUP', Math.min(G.transferLeft, 2));
    if (G.estep === 'production') G.bases.forEach(b => { b.out = E.bestOutput(G, b); });
  }
  if (G.phase === 'build') {
    for (let i = 0; i < 3; i++) {
      const opts = E.buildOptions(G, 'earth').filter(o => !o.why && G.cash >= E.sum(o.cost) + 6);
      if (opts.length && E.R.rnd() < .6) E.buildUnit(G, pick(opts).key, 'earth', E.R.rnd() < .1);
    }
    if (E.R.rnd() < .5) E.buildLV(G, pick([1, 2, 3, 4]), 'earth');
    if (E.R.rnd() < .05) { const z = pick([1, 2, 3, 4]); if (G.lv.earth[z]) E.scrapLV(G, 'earth', z); }
    if (E.R.rnd() < .03) { const s = pick(G.ships.filter(x => E.scrapSite(G, x)).concat([null])); if (s) E.scrap(G, s); }
    G.ships.filter(s => s.res).forEach(s => E.unreserve(G, s));
    G.ships.filter(s => s.loc === 'earth' && s.cap).forEach(s => E.buyCargo(G, s, 'SUP', 9));
    G.ships.filter(s => s.dmg).forEach(s => E.repair(G, s));
    G.bases.forEach(b => { if (E.R.rnd() < .3) E.buildLV(G, 1, b.id); const o = E.buildOptions(G, b.id).filter(x => !x.why); if (o.length && E.R.rnd() < .3) E.buildUnit(G, pick(o).key, b.id); });
  }
  if (G.phase === 'move') {
    G.ships.slice().forEach(s => {
      if (!G.ships.includes(s) || G.ask.length) return;
      const m = E.moves(G, s);
      if (!m.length || E.R.rnd() < .35) return;
      const probe = (G.probes[s.loc] || [])[0];
      E.move(G, s, pick(m).dest, { probe, load: s.cls === 'CV' && s.loc === 'earth' && E.R.rnd() < .3 ? { SUP: 2 } : undefined });
    });
    if (G.bases.length && E.R.rnd() < .5) E.shipCargo(G, pick(G.bases).id, { SUP: 1, ORE: 1 });
  }
  if (G.phase === 'combat') E.combatOptions(G).forEach(o => { if (E.R.rnd() < .7) E.combatAct(G, o); });
  if (G.phase === 'explore') {
    G.ships.slice().forEach(s => {
      if (!G.ships.includes(s) || G.ask.length) return;
      const o = E.exploreOptions(G, s);
      if (o.length) E.explore(G, s, pick(o));
    });
  }
  if (G.phase === 'trade') {
    G.ships.slice().forEach(s => {
      if (s.cls !== 'CV') return;
      const c = E.canFoundBase(G, s); if (c) E.foundBase(G, s);
      const b = E.atOwnBase(G, s); if (b) E.unload(G, s, b);
      if (s.loc === 'earth' && E.R.rnd() < .3) E.sellCargo(G, s);
    });
    G.bases.forEach(b => {
      const ops = E.upgradeOptions(G, b).filter(o => !o.why);
      if (ops.length && E.R.rnd() < .7) E.buildFacility(G, b, pick(ops).c); else E.buildSettlement(G, b);
      if (b.trade) E.trade(G, { base: b.id }, 3);
      if (E.R.rnd() < .2) E.terraform(G, b);
      if (E.R.rnd() < .2) E.repairFacility(G, b, pick(['lab', 'mine', 'sup', 'def', 'set']));
    });
    Object.keys(G.w).forEach(k => { if (G.w[k].npf) E.trade(G, { w: k }, 4); });
  }
  if (!G.ask.length) E.advance(G);
}
const sc = E.score(G);
fs.writeFileSync(out, JSON.stringify({ steps, year: G.y, score: sc.total, rating: sc.rating, cash: G.cash, all: ALL }, null, 1));
console.log(f, 'steps', steps, 'year', G.y, 'score', sc.total);
