// Faction-vs-faction combat: search, surrender, tactics, strike/direct fire, blockades, interception. Usage: node tests/faction.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
let bad = 0; const fail = m => { bad++; console.log('FAIL', m); };
const mkW = () => E.newWorld({ human: 'na', bots: [{ f: 'cn', variant: 'mil' }] });
const mk = (F, name, sz, cb, loc, dr) => { const s = { id: F.nid++, name, kind: 'CV', cls: 'CV', sz, ev: 3, cb, dr: dr || 0, cap: 4, dmg: 0, res: false, cargo: { ORE: 0, SUP: 0, FUEL: 0 }, loc }; F.ships.push(s); return s; };
const clear = F => { F.ships = []; };
const link = (a, b, v) => { a.rel[b.f] = v; b.rel[a.f] = v; };
function seed(n) { let x = n; E.setRandom && E.setRandom(() => (x = (x * 16807) % 2147483647) / 2147483647); }
// 1. options need embargo/war and an armed fleet at the same place
let w = mkW(), na = w.world.facs.na, cn = w.world.facs.cn; clear(na); clear(cn);
mk(na, 'A1', 4, 4, 'orbit:mar'); mk(cn, 'C1', 4, 3, 'orbit:mar');
na.phase = 'combat'; cn.phase = 'combat'; na.turn.acted = {};
if (E.combatOptions(na).some(o => o.k === 'fleet')) fail('no faction attack at Neutral');
link(na, cn, 4);
if (!E.combatOptions(na).some(o => o.k === 'fleet')) fail('embargo should allow an attack on ships');
if (E.combatOptions(na).some(o => o.k === 'bombard')) fail('no bombardment without a base');
// 2. battles resolve, markers are earned, deterministic over many seeds
let fought = 0, kills = 0, vm = 0;
for (let i = 0; i < 300; i++) {
  w = mkW(); na = w.world.facs.na; cn = w.world.facs.cn; clear(na); clear(cn);
  na.tech.msl = 1; cn.tech.msl = 1; na.tech.isw = 1;
  mk(na, 'A1', 4, 5, 'orbit:mar'); mk(na, 'A2', 3, 3, 'orbit:mar'); mk(cn, 'C1', 4, 3, 'orbit:mar'); mk(cn, 'C2', 2, 2, 'orbit:mar');
  link(na, cn, 5); na.phase = 'combat'; na.turn.acted = {};
  const o = E.combatOptions(na).find(o => o.k === 'fleet'); const before = na.vm + cn.vm;
  na.ask = []; const r = E.combatAct(na, o); if (r) fail('act: ' + r);
  if (na.ask.length) E.answer(na, 'auto');
  const lost = [...na.ships, ...cn.ships].length < 4; if (lost) kills++;
  if (na.vm + cn.vm > before) vm++;
  if (na.log.some(l => /Combat at/.test(l.t))) fought++;
  [na, cn].forEach(F => F.ships.forEach(s => { if (s.dmg > s.sz) fail('overkill ' + s.name); }));
}
console.log('battles', fought, 'with losses', kills, 'with victory markers', vm);
if (!fought) fail('no battle was ever fought');
if (!kills) fail('no ship was ever destroyed');
if (vm < kills * 0.5) fail('victory markers not awarded for kills');
// 3. an unarmed CV surrenders: reserved, cargo gone, politics marker moved
w = mkW(); na = w.world.facs.na; cn = w.world.facs.cn; clear(na); clear(cn);
const att = mk(na, 'A1', 4, 5, 'orbit:mar'), def = mk(cn, 'C1', 3, 0, 'orbit:mar'); def.cargo.ORE = 4; att.cap = 6;
link(na, cn, 4); na.phase = 'combat'; na.turn.acted = {}; const p0 = na.polm, q0 = cn.polm;
for (let i = 0; i < 30 && !def.res; i++) { na.turn.acted = {}; E.combatAct(na, { k: 'fleet', f: 'cn', key: 'w:mar' }); }
if (!def.res || def.cargo.ORE) fail('unarmed CV should surrender: reserved with cargo destroyed');
if (cn.polm >= q0 || na.polm <= p0) fail('a politics marker should pass to the victor');
na.turn.acted = {}; if (!E.combatAct(na, { k: 'fleet', f: 'cn', key: 'w:mar' })) fail('a faction that surrendered cannot be attacked again this turn');
// 3b. surrender terms: embargo must accept; at war a one-sided win with nothing to seize is refused, a politics marker or cargo is worth accepting
function surr(rel, pm, cargo, def) {
  const w2 = E.newWorld({ human: 'eu', bots: [{ f: 'na' }, { f: 'cn', variant: 'mil' }] }), a = w2.world.facs.na, c = w2.world.facs.cn; clear(a); clear(c);
  const at = mk(a, 'A1', 4, 6, 'orbit:mar'), df = mk(c, 'C1', 3, 0, 'orbit:mar'); df.cargo.ORE = cargo; at.cap = 8; c.polm = pm;
  link(a, c, rel); a.phase = 'combat'; a.turn.acted = {}; a.ask = [];
  for (let i = 0; i < 40 && !a.log.some(l => /surrenders|refuses/.test(l.t)); i++) { a.turn.acted = {}; E.combatAct(a, { k: 'fleet', f: 'cn', key: 'w:mar' }); }
  return { accepted: a.log.some(l => /surrenders to/.test(l.t)), refused: a.log.some(l => /refuses the surrender/.test(l.t)) };
}
let r = surr(4, 0, 0); if (!r.accepted) fail('under embargo a surrender must be accepted');
r = surr(5, 0, 0); if (r.accepted || !r.refused) fail('at war, a one-sided fight with nothing to seize should refuse the surrender: ' + JSON.stringify(r));
r = surr(5, 3, 0); if (!r.accepted) fail('at war, a politics marker to take should make the attacker accept');
r = surr(5, 0, 6); if (!r.accepted) fail('at war, cargo to seize should make the attacker accept');
// human attacker gets the choice at war, and can split a base's surrender from its ships
{ const w2 = mkW(), a = w2.world.facs.na, c = w2.world.facs.cn; clear(a); clear(c); mk(a, 'A1', 4, 6, 'orbit:mar'); const df = mk(c, 'C1', 3, 0, 'orbit:mar');
  c.bases.push({ id: 'b' + c.nid++, name: 'CB', w: 'mar', stock: { ORE: 4, SUP: 0, FUEL: 0 }, fac: { lab: 0, mine: 1, sup: 0, def: 0 }, dmg: { lab: 0, mine: 0, sup: 0, def: 0 }, set: 0, setDmg: 0, trade: null, out: 'ORE', built: 2030, techField: 'Phy' });
  link(a, c, 5); a.phase = 'combat'; a.turn.acted = {}; a.ask = []; c.polm = 2;
  for (let i = 0; i < 40 && !a.ask.length; i++) { a.turn.acted = {}; E.combatAct(a, { k: 'bombard', f: 'cn', key: 'w:mar' }); }
  const q = a.ask[0]; if (!q || q.k !== 'surrender' || !q.split) fail('human attacker should be asked about a base surrender with ships: ' + JSON.stringify(q && q.k));
  else { const p0 = c.polm; E.answer(a, 'exclude'); if (a.ask[0] && a.ask[0].k === 'battle') E.answer(a, 'auto'); const att0 = a.ships[0]; if (att0 && !att0.res && c.polm !== p0 - 1) fail('excluded-ships path should still take the base surrender (politics marker)'); if (!a.log.some(l => /excludes/.test(l.t))) fail('exclusion not logged'); } }
// 4. blockade of a base: halves output, stops growth, pays $2B
w = mkW(); na = w.world.facs.na; cn = w.world.facs.cn; clear(na); clear(cn);
const bse = { id: 'b' + cn.nid++, name: 'Test', w: 'mar', stock: { ORE: 3, SUP: 0, FUEL: 0 }, fac: { lab: 0, mine: 2, sup: 1, def: 1 }, dmg: { lab: 0, mine: 0, sup: 0, def: 0 }, set: 20, setDmg: 0, trade: null, out: 'ORE', built: 2030, techField: 'Phy' };
cn.bases.push(bse); mk(na, 'A1', 4, 0, 'orbit:mar'); link(na, cn, 4); na.phase = 'combat'; na.turn.acted = {};
if (!/armed|Defense/.test(String(E.combatAct(na, { k: 'fblock', f: 'cn', key: 'w:mar', base: bse.id })))) fail('a fleet with no combat value cannot blockade a Defense Network');
na.ships[0].cb = 2; na.turn.acted = {}; if (!E.combatAct(na, { k: 'fblock', f: 'cn', key: 'w:mar', base: bse.id })) fail('combat value 2 cannot blockade a small Defense Network (3)');
na.ships[0].cb = 3; na.turn.acted = {}; if (E.combatAct(na, { k: 'fblock', f: 'cn', key: 'w:mar', base: bse.id })) fail('blockade should start');
if (!bse.blk) fail('base should be blockaded');
const out = E.baseOutput(cn, bse, 'ORE'); bse.blk = false; const out2 = E.baseOutput(cn, bse, 'ORE'); bse.blk = true;
console.log('output blockaded', out && out.n, 'normal', out2 && out2.n);
if (out2 && (!out || out.n > Math.round(out2.n / 2) + 0)) fail('blockade should halve output');
// 4b. the blockader is paid $2B at production, the blockaded base stops growing
{ const c0 = na.cash; na.phase = 'econ'; const bl = na.log.length; E.production ? E.production(na) : null; console.log('blockader cash change', na.cash - c0);
  const set0 = bse.set; E.growth(cn); na.phase = 'combat'; na.turn.acted = {}; console.log('blockaded settlements', set0, '->', bse.set); if (bse.set >= set0 && set0) fail('a blockaded base should lose settlements'); }
// 5. bombardment: war only, hits the base
link(na, cn, 4); na.turn.acted = {}; if (!E.combatAct(na, { k: 'bombard', f: 'cn', key: 'w:mar' })) fail('bombardment needs war');
link(na, cn, 5); let hit = 0;
for (let i = 0; i < 60; i++) { na.turn.acted = {}; const f0 = JSON.stringify(bse.fac) + JSON.stringify(bse.stock) + cn.bases.length; E.combatAct(na, { k: 'bombard', f: 'cn', key: 'w:mar' }); if (f0 !== JSON.stringify(bse.fac) + JSON.stringify(bse.stock) + cn.bases.length) hit++; cn.surr = {}; na.ships.forEach(s => { s.dmg = 0; s.res = false; }); if (!cn.bases.includes(bse)) break; }
if (!hit) fail('bombardment never damaged the base');
// 6. interception: a bot's armed CV catches ships leaving its location
let caught = 0, stopped = 0, fights = 0;
for (let i = 0; i < 200; i++) {
  w = E.newWorld({ human: 'eu', bots: [{ f: 'na' }, { f: 'cn', variant: 'mil' }] }); na = w.world.facs.na; cn = w.world.facs.cn; clear(na); clear(cn); link(na, cn, 4);
  mk(cn, 'C1', 4, 4, 'orbit:mar'); const mv = mk(na, 'Mover', 3, i % 2 ? 4 : 0, 'orbit:mar'); na.phase = 'move'; na.turn.moved = {};
  const ms = E.moves(na, mv); const e = E.move(na, mv, ms[0].dest, {});
  const intercepts = na.log.some(l => /intercepts/.test(l.t)); if (intercepts) caught++;
  if (na.log.some(l => /stops rather than fight/.test(l.t))) { stopped++; if (mv.loc !== 'orbit:mar') fail('a stopped ship must not move'); }
  if (na.log.some(l => /Combat at/.test(l.t))) fights++;
  if (na.ask.length) fail('bot movers never get an ask');
}
console.log('caught', caught, 'stopped', stopped, 'fights', fights);
if (!caught || !fights) fail('interception never happened');
// the human gets an ask
w = mkW(); na = w.world.facs.na; cn = w.world.facs.cn; clear(na); clear(cn); link(na, cn, 4);
for (let i = 0; i < 40 && !na.ask.length; i++) { clear(na); clear(cn); mk(cn, 'C1', 4, 4, 'orbit:mar'); const mv = mk(na, 'Mover', 3, 3, 'orbit:mar'); na.phase = 'move'; na.turn.moved = {}; E.move(na, mv, E.moves(na, mv)[0].dest, {}); }
console.log('human intercept ask', na.ask[0] && na.ask[0].k);
// 7. bot decisions: a clearly stronger bot fleet attacks, blockades; a weaker one does not
const AI = require(path.join(dir, 'ai.js'))(E, D);
let atk = 0, weakAtk = 0, blocks = 0, hum = 0;
for (let i = 0; i < 60; i++) {
  w = E.newWorld({ human: 'eu', bots: [{ f: 'na' }, { f: 'cn', variant: 'mil' }] }); na = w.world.facs.na; cn = w.world.facs.cn; const eu = w.world.facs.eu;
  [na, cn, eu].forEach(clear); link(na, cn, 5); link(na, eu, 4);
  mk(na, 'A1', 6, 8, 'orbit:mar'); mk(na, 'A2', 4, 5, 'orbit:mar'); mk(cn, 'C1', 2, 1, 'orbit:mar'); mk(eu, 'E1', 2, 1, 'orbit:mar');
  cn.bases.push({ id: 'b' + cn.nid++, name: 'CBase', w: 'mar', stock: { ORE: 2, SUP: 0, FUEL: 0 }, fac: { lab: 0, mine: 1, sup: 0, def: 0 }, dmg: { lab: 0, mine: 0, sup: 0, def: 0 }, set: 0, setDmg: 0, trade: null, out: 'ORE', built: 2030, techField: 'Phy' });
  na.phase = 'combat'; na.turn.acted = {}; na.ask = [];
  AI.botPhase(na);
  if (na.log.some(l => /Combat at|surrenders/.test(l.t))) atk++;
  if (eu.log.some(l => /Combat at|surrenders|intercepts/.test(l.t))) hum++;
  w = E.newWorld({ human: 'eu', bots: [{ f: 'na' }, { f: 'cn', variant: 'mil' }] }); na = w.world.facs.na; cn = w.world.facs.cn; clear(na); clear(cn); link(na, cn, 5);
  mk(na, 'A1', 2, 1, 'orbit:mar'); mk(cn, 'C1', 6, 8, 'orbit:mar'); na.phase = 'combat'; na.turn.acted = {}; AI.botPhase(na);
  if (na.log.some(l => /Combat at/.test(l.t))) weakAtk++;
}
console.log('strong bot fought', atk, 'of 60; human saw', hum, '; weak bot fought', weakAtk);
if (atk < 30) fail('a clearly stronger bot should attack');
if (weakAtk) fail('a weaker bot should not attack');
if (!hum) fail('the human should be told of fights it is involved in');
// 8. robotic explorers can be launched toward Alpha Centauri (a Flyby cannot make a heliocentric transfer there later)
{ const w2 = mkW(), g = w2.world.facs.na; ['Flyby', 'Orbiter', 'Rover'].forEach(kind => { const re = { id: 900 + g.nid++, name: kind, kind, cls: 'RE', sz: 1, cb: 0, dmg: 0, cargo: { ORE: 0, SUP: 0, FUEL: 0 }, loc: 'earth', launched: false }; g.ships.push(re); g.phase = 'move'; g.turn.moved = {};
  if (!E.moves(g, re).some(m => /alp/.test(m.dest))) fail(kind + ' should be launchable toward Alpha Centauri'); g.ships = g.ships.filter(x => x !== re); }); }
// 9. a Flyby still far from its target (turns held beyond box 6 count) cannot explore: the penalty can take the value to zero or below
{ const w2 = mkW(), g = w2.world.facs.na; g.phase = 'explore'; g.turn.acted = {};
  const fl = (loc, hold) => ({ id: 950, name: 'F', kind: 'Flyby', cls: 'RE', sz: 1, ev: 1, cb: 0, dmg: 0, cargo: { ORE: 0, SUP: 0, FUEL: 0 }, loc, hold, launched: true });
  let s = fl('box:alp:6', 35); g.ships = [s]; if (E.exploreOptions(g, s).length) fail('a Flyby 41 turns from Alpha Centauri must not be able to explore it');
  s = fl('box:alp:1', 0); g.ships = [s]; if (!E.exploreOptions(g, s).length) fail('a Flyby one turn out should explore Alpha Centauri'); }
// 10. bases can be founded from orbit or the surface; orbital bases need the Space Elevator for mines; a CV can explore on a world where it has a base
{ const w2 = mkW(), g = w2.world.facs.na; g.ships = []; g.bases = []; g.phase = 'trade';
  const c1 = mk(g, 'Orb', 3, 2, 'orbit:mar'); c1.ev = 3; c1.cargo.SUP = 5; const c2 = mk(g, 'Srf', 3, 2, 'surf:pho'); c2.ev = 3; c2.cargo.SUP = 5;
  const f1 = E.canFoundBase(g, c1); if (!f1 || f1.pos !== 'orbit') fail('should found from orbit: ' + JSON.stringify(f1));
  if (E.foundBase(g, c1)) fail('orbital founding failed'); const b1 = g.bases[0];
  if (E.baseLoc(b1) !== 'orbit:mar') fail('orbital base location ' + E.baseLoc(b1));
  if (E.canFoundBase(g, mk(g, 'Srf2', 3, 2, 'surf:mar'))) fail('only one base per world');
  const mo = E.upgradeOptions(g, b1).find(o => o.c === 'mine'); if (!mo.why) fail('orbital base should not build mines without Space Elevator');
  g.tech.elev = 1; if (E.upgradeOptions(g, b1).find(o => o.c === 'mine').why) fail('Space Elevator should allow mines'); delete g.tech.elev;
  const lab = E.upgradeOptions(g, b1).find(o => o.c === 'lab'); if (lab.why) fail('orbital base can build other facilities: ' + lab.why);
  if (E.foundBase(g, c2)) fail('surface founding failed'); const b2 = g.bases[1]; if (E.baseLoc(b2) !== 'surf:pho') fail('surface base location');
  g.phase = 'explore'; g.turn.acted = {}; const surfOnMars = mk(g, 'OnMars', 3, 2, 'surf:mar'); surfOnMars.ev = 3;
  if (!E.exploreOptions(g, surfOnMars).some(o => o.w === 'mar')) fail('a CV on the surface of a world with our (orbital) base can explore');
  g.turn.acted = {}; c2.loc = 'surf:pho'; if (!E.exploreOptions(g, c2).some(o => o.w === 'pho')) fail('a CV on the surface at our surface base can explore'); }
// 11. severe atmospheres need Pressure Shell for mines; gas-giant (orbital) bases also need the Space Elevator
{ const w2 = mkW(), g = w2.world.facs.na; g.bases = [];
  const mkb = (w, pos) => { const b = { id: 'b' + g.nid++, name: 'T' + w, w, stock: { ORE: 9, SUP: 9, FUEL: 9 }, fac: { lab: 0, mine: 0, sup: 0, def: 0 }, dmg: { lab: 0, mine: 0, sup: 0, def: 0 }, set: 0, setDmg: 0, trade: null, out: 'ORE', built: 2030, techField: 'Phy', pos }; g.bases.push(b); return b; };
  const mine = b => E.upgradeOptions(g, b).find(o => o.c === 'mine').why;
  const ven = mkb('ven', 'surf'); g.tech.psh = 0; if (!/Pressure Shell/.test(mine(ven) || '')) fail('Venus mines need Pressure Shell'); g.tech.psh = 1; if (mine(ven)) fail('Venus mine allowed with Pressure Shell: ' + mine(ven));
  const jup = mkb('jup', 'orbit'); delete g.tech.psh; delete g.tech.elev; if (!mine(jup)) fail('Jupiter orbital mine needs tech'); g.tech.psh = 1; if (!/Elevator/.test(mine(jup) || '')) fail('Jupiter still needs Space Elevator'); g.tech.elev = 1; if (mine(jup)) fail('Jupiter mine allowed with both techs');
  const ear = mkb('ear', 'orbit'); if (!mine(ear)) fail('Earth can never mine'); }
// 12. hits on a base: facilities first, then settlements (3 hits per token, then down one token), then the base itself
{ const o = () => ({ hits: new Map(), lostCV: [], lostRE: [], lostB: [], facLost: 0 });
  const b = { fac: { lab: 0, mine: 1, sup: 0, def: 0 }, dmg: { lab: 0, mine: 0, sup: 0, def: 0 }, stock: { ORE: 5, SUP: 0, FUEL: 0 }, set: 20, setHits: 0 };
  let out = o(), u = { t: 'b', o: b };
  E.applyHit(na, u, out); if (b.fac.mine !== 0 || b.set !== 20) fail('the first hit should remove the small mining station, not touch settlements');
  E.applyHit(na, u, out); E.applyHit(na, u, out); if (b.set !== 20 || b.setHits !== 2) fail('settlement should have taken 2 of 3 hits, has ' + b.setHits);
  E.applyHit(na, u, out); if (b.set !== 15) fail('third settlement hit should downgrade 20x to 15x, got ' + b.set);
  for (let i = 0; i < 3; i++) E.applyHit(na, u, out); if (b.set !== 10) fail('15x should downgrade to 10x, got ' + b.set);
  for (let i = 0; i < 6; i++) E.applyHit(na, u, out); if (b.set !== 4) fail('10x -> 5x -> 4x expected, got ' + b.set);
  for (let i = 0; i < 12; i++) E.applyHit(na, u, out); if (b.set !== 0 || u.dead) fail('1x should be removed and the base survive until hit again: ' + b.set + ' ' + u.dead);
  E.applyHit(na, u, out); if (!u.dead || out.lostB[0] !== b) fail('a hit with no buildings should destroy the base');
  console.log('base hits ok'); }
console.log(bad ? 'FAILED' : 'ALL OK');
process.exit(bad ? 1 : 0);
