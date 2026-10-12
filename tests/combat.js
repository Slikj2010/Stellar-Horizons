// Bot diplomacy / war behaviour and policy order. Usage: node tests/combat.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
const AI = require(path.join(dir, 'ai.js'))(E, D);
let bad = 0; const fail = m => { bad++; console.log('FAIL', m); };
// 1. China's military variant has no standing habit of harassing
if (AI.profiles.cn_mil.bully) fail('China (military) still has the standing bully behaviour');
// 2. readiness: no combat-ready CV = 0; bigger CVs and military techs raise it
const H = E.newWorld({ human: 'jp', bots: [{ f: 'cn', variant: 'mil' }, { f: 'eu' }, { f: 'ru' }] }), cn = H.world.facs.cn, eu = H.world.facs.eu;
const mk = (F, name, sz, cb) => F.ships.push({ id: F.nid++, name, kind: 'CV', cls: 'CV', sz, ev: 3, cb, cap: 0, dmg: 0, res: false, cargo: { ORE: 0, SUP: 0, FUEL: 0 }, loc: 'earth' });
eu.ships = eu.ships.filter(s => s.cls !== 'CV'); cn.ships = cn.ships.filter(s => s.cls !== 'CV');
if (AI.readiness(eu) !== 0) fail('no armed CV should mean readiness 0');
mk(cn, 'Song', 2, 3); const r1 = AI.readiness(cn); mk(cn, 'Han', 6, 6); const r2 = AI.readiness(cn); cn.tech.msl = 1; cn.tech.amsl = 1; const r3 = AI.readiness(cn);
if (!(r1 > 0 && r2 > r1 && r3 > r2)) fail(`readiness should grow with CV tiers and techs: ${r1} ${r2} ${r3}`);
// 3. the weaker side answers a lowering of relations by improving them; a faction without Military policy never lowers
function setup(F) { F.phase = 'econ'; F.estep = 'diplomacy'; F.dipl = {}; F.polm = 8; F.aiDip = null; }
Object.values(H.world.facs).forEach(setup);
eu.pol = {}; eu.rel.cn = 4; cn.rel.eu = 4; eu.aiHostile = { cn: H.y };
AI.diplomacyDecide(eu);
if (!(eu.dipl.cn > 0)) fail('a weaker faction should counter an embargo with diplomacy: ' + JSON.stringify(eu.dipl));
eu.rel.cn = 3; cn.rel.eu = 3; setup(eu); eu.aiHostile = {};
let lowered = 0; for (let i = 0; i < 300; i++) { setup(eu); AI.diplomacyDecide(eu); if (Object.values(eu.dipl).some(d => d < 0)) lowered++; }
if (lowered) fail('a faction with no Military policy lowered relations ' + lowered + ' times');
// 4. a faction with no combat-ready CV never lowers relations even with Military policy
const ru = H.world.facs.ru; ru.pol.mil = 2; ru.ships = ru.ships.filter(s => s.cls !== 'CV'); lowered = 0;
for (let i = 0; i < 300; i++) { setup(ru); AI.diplomacyDecide(ru); if (Object.values(ru.dipl).some(d => d < 0)) lowered++; }
if (lowered) fail('a faction with no armed CV lowered relations ' + lowered + ' times');
// 5. policy order: starting track to Unified, then Space Settlement twice, Asia/Russia then Human
['na', 'as', 'ru', 'eu'].forEach(f => {
  const W = E.newWorld({ human: 'jp', bots: [{ f }] }), G = W.world.facs[f], start = Object.keys(G.pol).filter(k => G.pol[k] > 0), seq = [];
  for (let i = 0; i < 9; i++) { G.phase = 'econ'; G.estep = 'policy'; G.policyPicked = false; G.policyLeft = 0; const b = JSON.stringify(G.pol); AI.policyPick(G); const a = G.pol; seq.push(Object.keys(a).find(k => a[k] !== JSON.parse(b)[k]) || '-'); }
  const st = start[0], first3 = seq.slice(0, 3 - (G.pol[st] > 0 ? 0 : 0));
  console.log(f, 'start', start.join(','), 'picks', seq.join(' '));
  const nStart = 3 - (JSON.parse(JSON.stringify({ [st]: 1 }))[st]);   // levels still to climb on the starting track
  if (!seq.slice(0, nStart).every(k => k === st)) fail(`${f}: should finish its starting track (${st}) first: ${seq.join(' ')}`);
  if (G.pol.set < 2) fail(`${f}: should reach Space Settlement level 2`);
  if ((f === 'as' || f === 'ru') && (G.pol.hum || 0) < 2) fail(`${f}: crew-focused factions should go Human`);
});
console.log(bad ? 'FAILED' : 'ALL OK');
process.exit(bad ? 1 : 0);
