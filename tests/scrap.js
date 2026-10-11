// Optional scrapping rule and two-sided LV counters. Usage: node tests/scrap.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
let bad = 0; const ok = (c, m) => { if (!c) { bad++; console.log('FAIL', m); } else console.log('ok  ', m); };
const mkBase = (G, w, sup) => { const b = { id: 'b' + w, name: 'Base ' + w, w, stock: { ORE: 0, SUP: 0, FUEL: 0 }, fac: { lab: 0, mine: 0, sup: sup || 0, def: 0 }, dmg: { lab: 0, mine: 0, sup: 0, def: 0 }, set: 0, setDmg: 0, trade: null, out: 'ORE', built: 2030, techField: 'Phy' }; G.bases.push(b); return b; };
const clone = (G, kind, loc) => { const t = JSON.parse(JSON.stringify(G.ships.find(s => s.cls === 'RE'))); Object.assign(t, { id: 900 + G.ships.length, name: kind + G.ships.length, kind, loc, launched: true, fixed: true, cost: { ORE: 4, SUP: 0, FUEL: 2 } }); G.ships.push(t); return t; };
// rule off: explorers are just destroyed
let G = E.newGame('na'); let tel = G.ships.find(s => s.kind === 'Telescope'); let cash = G.cash;
ok(!E.scrapSite(G, tel), 'rule off: telescope has no scrap site'); E.scrap(G, tel); ok(G.cash === cash && !G.ships.includes(tel), 'rule off: telescope destroyed, nothing back');
// rule on
G = E.newGame('na', { scrapRE: true }); tel = G.ships.find(s => s.kind === 'Telescope'); cash = G.cash;
ok(E.scrapSite(G, tel) && E.scrapSite(G, tel).where === 'earth', 'telescope in Earth orbit scraps on Earth');
const mb = mkBase(G, 'mar'); const orb = clone(G, 'Orbiter', 'orbit:mar'), rov = clone(G, 'Rover', 'surf:mar'), far = clone(G, 'Orbiter', 'orbit:cer');
ok(E.scrapSite(G, orb).where === mb.id, 'orbiter over a world with your base scraps there');
ok(E.scrapSite(G, rov).where === mb.id, 'rover on the surface with your base scraps there');
ok(!E.scrapSite(G, far), 'orbiter without a base is only destroyed');
E.scrap(G, orb); ok(mb.stock.ORE === 2 && mb.stock.FUEL === 1, 'scrapping returns half the materials to the base: ' + JSON.stringify(mb.stock));
const pc = G.cash; E.scrap(G, far); ok(G.cash === pc && !G.ships.includes(far), 'destroyed away from a base: nothing back');
// CV builds a base then scraps itself there
const cv = G.ships.find(s => s.cls === 'CV'); cv.loc = 'surf:pho'; cv.dmg = 0; const pb = mkBase(G, 'pho');
ok(E.scrapSite(G, cv) && E.scrapSite(G, cv).where === pb.id, 'a CV at its new base can scrap itself there');
// LV scrap
G.lv.earth[2] = 1; cash = G.cash; ok(!E.scrapLV(G, 'earth', 2) && G.lv.earth[2] === 0 && G.cash > cash - 1, 'LV-2 scrapped on Earth');
const G2 = E.newGame('na'); G2.lv.earth[2] = 1; ok(typeof E.scrapLV(G2, 'earth', 2) === 'string', 'LV scrapping needs the optional rule');
// two-sided counters
const N = E.newGame('na'); N.tech.uhlv = 1; N.tech.cv = 1; const set = a => N.lv.earth = { 1: a[0], 2: a[1], 3: a[2], 4: a[3] };
set([0, 0, 1, 0]); ok(!E.lvCanAdd(N, 3), 'North America has only one LV-3');
set([1, 0, 0, 0]); ok(E.lvCanAdd(N, 3), 'North America\'s first LV-1 uses the LV-1/LV-4 counter, leaving its LV-3');
set([1, 0, 0, 3]); ok(!E.lvCanAdd(N, 4), 'with that LV-1 out, North America has 3 LV-4s');
set([0, 0, 0, 4]); ok(E.lvCanAdd(N, 1) && E.lvCanAdd(N, 3) && !E.lvCanAdd(N, 2), 'all 4 LV-4s out: the LV-1/LV-3 counter is still free, no LV-2 left');
N.lv.earth[1] = 1; ok(!E.lvCanAdd(N, 3), 'that LV-1 then took the LV-1/LV-3 counter (the LV-1/LV-4 one shows LV-4)');
N.lv.earth[4] = 3; ok(E.lvCanAdd(N, 2), 'an LV-4 leaving frees a counter for an LV-2');
const R = E.newGame('ru'); R.tech.uhlv = 1; R.lv.earth = { 1: 1, 2: 2, 3: 1, 4: 0 };
ok(!E.lvCanAdd(R, 1) && !E.lvCanAdd(R, 3) && E.lvCanAdd(R, 4) && E.lvCanAdd(R, 2), 'other factions: 2 LV-1/LV-3 and 3 LV-2/LV-4 counters');
console.log(bad ? bad + ' FAILED' : 'ALL OK'); process.exit(bad ? 1 : 0);
