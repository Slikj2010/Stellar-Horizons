// Multi-faction games played entirely by bots. Usage: node tests/world.js <site_dir> [games]
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
const AI = require(path.join(dir, 'ai.js'))(E, D);
let seed = 4242; E.R.rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const games = +(process.argv[3] || 3); let errors = 0;
const setups = [
  { human: 'na', bots: [{ f: 'ru' }, { f: 'eu' }, { f: 'jp' }, { f: 'cn', variant: 'mil' }, { f: 'as' }, { f: 'sa' }] },
  { human: 'jp', bots: [{ f: 'cn', variant: 'rob' }, { f: 'sa' }] },
  { human: 'eu', bots: [{ f: 'ru' }, { f: 'as' }], scenario: 'fut2060' },
];
for (let i = 0; i < games; i++) {
  const st = setups[i % setups.length];
  try {
    const H = E.newWorld({ ...st, scrapRE: true });
    AI.autoPlay(H);
    // invariants: shared worlds, no faction over its counters, no duplicate Earth-orbit bases from bots
    const facs = Object.values(H.world.facs);
    if (facs.some(g => g.w !== H.w || g.fly !== H.fly)) throw new Error('world not shared');
    const earthBases = facs.flatMap(g => g.bases.filter(b => b.w === 'ear'));
    if (earthBases.length > 1) throw new Error('two bases in Earth orbit');
    const save = E.revive(JSON.parse(E.serialize(H))); if (!save.world || save.world.facs[save.f] !== save) throw new Error('save/load broken');
    console.log(`game ${i} (${st.human} + ${st.bots.map(b => b.f + (b.variant ? '/' + b.variant : '')).join(',')}) ended ${H.endYear}, order ${H.world.meta.order.join('>')}`);
    facs.forEach(g => { const sc = E.score(g); console.log(`  ${g.f}${g.bot ? ' bot' : ''}: score ${sc.total} techs ${Object.keys(g.tech).length} bases ${g.bases.map(b => b.w + (b.fac.lab ? 'L' : '') + (b.fac.mine ? 'M' : '')).join(' ') || '-'} sets ${g.bases.reduce((a, b) => a + b.set, 0)} ships ${g.ships.length} vm ${g.vm} pol ${JSON.stringify(g.pol)}`); });
    const errs = facs.flatMap(g => g.log.filter(l => /Bot error/.test(l.t)).map(l => g.f + ': ' + l.t));
    if (errs.length) { console.log('  bot errors:', [...new Set(errs)].slice(0, 5)); errors++; }
  } catch (e) { errors++; console.log('ERROR', e.stack.split('\n').slice(0, 5).join(' | ')); }
}
console.log(errors ? `FAIL ${errors}` : 'ALL OK');
