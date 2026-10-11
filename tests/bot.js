// Headless bot: plays full solo campaigns with random-but-legal choices to exercise the rules engine.
// Usage: node bot.js <site_dir> [games]
const path = require('path');
const dir = process.argv[2];
const D = require(path.join(dir, 'data.js'));
const UNITS = require(path.join(dir, 'units.json'));
const E = require(path.join(dir, 'rules.js'))(D, UNITS);
const games = +(process.argv[3] || 7);
let seed = 12345;
E.R.rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const pick = a => a[Math.floor(E.R.rnd() * a.length)];
const facs = Object.keys(D.FAC);
let errors = 0;
const check = (G, where) => {
  // invariants
  if (!Number.isFinite(G.cash)) throw new Error('cash NaN ' + where);
  E.FIELDS.forEach(f => { if (!Number.isFinite(G.bank[f])) throw new Error('bank NaN ' + f); });
  const names = G.ships.map(s => s.name); if (new Set(names).size !== names.length) throw new Error('duplicate ship ' + where);
  G.ships.forEach(s => { E.sysOf(s.loc); if (s.dmg >= s.sz && s.cls === 'CV') throw new Error('dead CV alive ' + s.name); if (s.cls === 'RE' && (s.kind === 'Orbiter' || s.kind === 'Rover') && s.fixed && !/^(orbit|surf)/.test(s.loc)) throw new Error('fixed RE not at world ' + s.name + ' ' + s.loc); });
  E.RES.forEach(r => G.bases.forEach(b => { if (b.stock[r] < 0) throw new Error('negative stock'); }));
  Object.values(G.w).forEach(w => { if (w.v < 0) throw new Error('negative exploration'); });
};
const stats = {};
for (let gi = 0; gi < games; gi++) {
  const f = facs[gi % facs.length];
  const G = E.newGame(f, { scrapRE: gi % 2 === 1, scenario: gi % 3 === 2 ? 'fut2060' : 'std' });
  let steps = 0;
  try {
    while (!G.over && steps < 20000) {
      steps++;
      // answer questions
      let guard = 0;
      while (G.ask.length && guard++ < 50) {
        const a = G.ask[0];
        if (a.k === 'pirate') E.answer(G, pick(['pay', 'remove', 'surrender', 'fight', 'stay']));
        else if (a.k === 'publicity') E.answer(G, pick(Object.keys(G.w).filter(k => G.w[k].v > 0)));
        else if (a.k === 'immigration') E.answer(G, G.bases[0].id);
        else if (a.k === 'card') E.answer(G, pick([...a.opts, null]));
        else if (a.k === 'flyby') E.answer(G, pick(a.opts).sys);
        else G.ask.shift();
      }
      if (G.ask.length) throw new Error('stuck ask ' + G.ask[0].k);
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
        // optional scrapping: now and then scrap a stocked LV or an explorer/CV that is at a scrap site
        if (E.R.rnd() < .05) { const z = pick([1, 2, 3, 4]); if (G.lv.earth[z]) E.scrapLV(G, 'earth', z); }
        if (E.R.rnd() < .03) { const s = pick(G.ships.filter(x => E.scrapSite(G, x)).concat([null])); if (s) E.scrap(G, s); }
        { const c = D.FAC[G.f].lvs, n = E.lvCount(G); if (n[1] + n[3] > (c[13] || 0) + (c[14] || 0) || n[2] + n[4] > (c[24] || 0) + (c[14] || 0) || n[3] > (c[13] || 0) || n[2] > (c[24] || 0)) throw new Error('LV counters over the limit ' + JSON.stringify(n)); }
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
          E.move(G, s, pick(m).dest, { probe });
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
          // CVs at Earth-system worlds get SUP loaded magically? No: use NPF trade or own base. Try found base when cargo allows.
          const c = E.canFoundBase(G, s); if (c) E.foundBase(G, s);
          const b = E.atOwnBase(G, s); if (b) E.unload(G, s, b);
        });
        G.bases.forEach(b => {
          const ops = E.upgradeOptions(G, b).filter(o => !o.why);
          if (ops.length && E.R.rnd() < .7) E.buildFacility(G, b, pick(ops).c); else E.buildSettlement(G, b);
          if (b.trade) E.trade(G, { base: b.id }, 3);
          if (E.R.rnd() < .2) E.terraform(G, b);
        });
        Object.keys(G.w).forEach(k => { if (G.w[k].npf) E.trade(G, { w: k }, 4); });
      }
      if (!G.ask.length) E.advance(G);
      check(G, G.phase + ' ' + G.y);
    }
    const sc = E.score(G);
    const s = stats[f] = { end: G.endYear, score: sc.total, rating: sc.rating, techs: Object.keys(G.tech).length, bases: G.bases.length, sets: G.bases.reduce((a, b) => a + b.set, 0), ships: G.ships.length, vm: G.vm, pir: Object.values(G.fly).reduce((a, x) => a + x.pir.length, 0), npf: Object.values(G.w).filter(x => x.npf).length };
    console.log(f, JSON.stringify(s));
  } catch (e) {
    errors++;
    console.log('ERROR', f, G.y, G.phase, G.estep, e.stack.split('\n').slice(0, 4).join(' | '));
  }
}
console.log(errors ? `FAIL ${errors}` : 'ALL OK');
