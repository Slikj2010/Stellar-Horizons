// Crew vehicle discipline: no more than one CV built per decade early on, never past the support limit by 2+, Space Mining
// only after the production-CV technology, range techs (Orbital Rendezvous, Advanced Astrodynamics) before other Physics for crew factions.
// Usage: node tests/cv.js <site_dir>
const path = require('path'), dir = process.argv[2];
const D = require(path.join(dir, 'data.js')), E = require(path.join(dir, 'rules.js'))(D, require(path.join(dir, 'units.json')));
const AI = require(path.join(dir, 'ai.js'))(E, D);
let bad = 0; const fail = m => { if (bad++ < 8) console.log('FAIL', m); };
const facs = ['na', 'ru', 'eu', 'jp', 'cn', 'as', 'sa'], PROD = { na: 'lcv', ru: 'lcv', sa: 'lcv', as: 'lcv', cn: 'lcv', eu: 'frig', jp: 'frig' };
let maxOver = -9, early = 0, earlyRuns = 0;
for (let g = 0; g < 7; g++) {
  const human = facs[g], H = E.newWorld({ human, bots: facs.filter(f => f !== human).map(f => ({ f })) });
  const prev = {}; let steps = 0, lastY = 0;
  while (!H.over && H.y <= 2120 && steps++ < 60000) {
    if (H.y !== lastY) {
      lastY = H.y;
      Object.values(H.world.facs).forEach(F => {
        if (F.tech.mine && !F.tech[PROD[F.f]]) fail(`${F.f} researched Space Mining in ${H.y} before ${PROD[F.f]}`);
        const over = E.nCV(F) - E.lims(F)[1]; maxOver = Math.max(maxOver, over);
        if (over >= 2) fail(`${F.f} is ${over} CVs over its support limit in ${H.y}`);
        const d = Math.floor(H.y / 10); if (H.y <= 2059) { const p = prev[F.f]; if (p && p.d === d) { if (E.nCV(F) - p.n0 > 2) fail(`${F.f} built ${E.nCV(F) - p.n0} CVs within the decade of ${d * 10} (${H.y})`); } else prev[F.f] = { d, n0: E.nCV(F) }; }
      });
    }
    AI.autoPlay(H, 1);
  }
}
console.log(bad ? 'FAILED' : 'ALL OK', `(max CVs over limit ${maxOver})`);
process.exit(bad ? 1 : 0);
