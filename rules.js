// Stellar Horizons solo campaign rules engine. Pure logic: no DOM. Browser: window.SHE; Node: module.exports.
// Locations: 'earth' (Earth surface / launch pad), 'orbit:<w>', 'surf:<w>', 'fly:<sys>', 'box:<sys>:<n>'
(function (root) {
'use strict';
function make(D, UNITS) {
const R = { rnd: Math.random };
const d10 = () => Math.floor(R.rnd() * 10) + 1;
const d100 = () => Math.floor(R.rnd() * 100) + 1;
const pick = a => a[Math.floor(R.rnd() * a.length)];
const RES = ['ORE', 'SUP', 'FUEL'];
const FIELDS = ['Phy', 'Eng', 'Bio'];
const FN = { Phy: 'Physics', Eng: 'Engineering', Bio: 'Biology' };
const W = D.W, SYS = D.SYS;

// ---------- locations ----------
const P = loc => { const a = loc.split(':'); return { t: a[0], w: a[0] === 'orbit' || a[0] === 'surf' ? a[1] : null, s: a[0] === 'fly' || a[0] === 'box' ? a[1] : null, n: a[0] === 'box' ? +a[2] : 0 }; };
const sysOf = loc => { const p = P(loc); return p.t === 'earth' ? 'ear' : p.w ? W[p.w].sys : p.s; };
const worldOf = loc => { const p = P(loc); return p.t === 'earth' ? 'ear' : p.w; };
const locName = loc => {
  const p = P(loc);
  if (p.t === 'earth') return 'Earth';
  if (p.t === 'orbit') return p.w === 'ear' ? 'Earth orbit' : W[p.w].n + ' orbit';
  if (p.t === 'surf') return W[p.w].n + ' surface';
  if (p.t === 'fly') return SYS[p.s].n + ' flyby box';
  return SYS[p.s].n + ' transfer box ' + p.n;
};
const worldsIn = s => Object.keys(W).filter(k => W[k].sys === s);
const hasSurf = w => !W[w].tags.includes('station') || w === 'jup' || w === 'ura';
const isGas = w => W[w].tags.includes('gas');
const isSun = w => W[w].tags.includes('sunobs');

// ---------- small helpers ----------
const log = (G, t, c) => { G.log.unshift({ y: G.y, t, c: c || '' }); if (G.log.length > 400) G.log.length = 400; };
const has = (G, k) => !!G.tech[k];
const polLv = (G, k) => G.pol[k] || 0;
const fac = G => D.FAC[G.f];
const decadeRow = y => (y < 2060 ? 0 : y < 2090 ? 1 : y < 2120 ? 2 : 3);
const sum = o => RES.reduce((a, r) => a + (o[r] || 0), 0);
const addRes = (a, b, k = 1) => { RES.forEach(r => { a[r] = (a[r] || 0) + k * (b[r] || 0); }); return a; };
const enough = (a, b) => RES.every(r => (a[r] || 0) >= (b[r] || 0));
const resTxt = o => RES.filter(r => o[r]).map(r => o[r] + ' ' + r).join(' + ') || 'nothing';
const unitData = name => UNITS[name];

// ---------- tech-driven values ----------
const engBase = G => has(G, 'frig') ? 3 : has(G, 'uhlv') ? 4 : 5;
const engRate = (G, s) => engBase(G) - (s && s.cls === 'CV' ? s.sz : 0);
const mult = G => has(G, 'hap') ? .2 : has(G, 'aam') ? .4 : has(G, 'pam') ? .5 : has(G, 'fr') ? .6 : has(G, 'ff') ? .7 : has(G, 'pm') ? .8 : has(G, 'ion') ? .9 : 1;
const range = G => has(G, 'sch') ? 99 : has(G, 'dse') ? 5 : has(G, 'ccls') ? 4 : has(G, 'ldsf') ? 3 : has(G, 'als') ? 2 : has(G, 'astro') ? 1 : 0;
const recall = G => (has(G, 'asm') ? 20 : has(G, 'ism') ? 25 : has(G, 'aops') ? 30 : has(G, 'iops') ? 35 : has(G, 'ops') ? 40 : has(G, 'ag') ? 45 : 50) - (G.f === 'ru' ? 5 : 0);
const malfBase = G => (has(G, 'ai') ? 15 : has(G, 'aqc') ? 18 : has(G, 'qc') ? 21 : has(G, 'acd') ? 24 : has(G, 'icd') ? 27 : 30) - (G.f === 'jp' ? 2 : 0);
const roboBonus = G => (has(G, 'ai') ? 3 : has(G, 'aqc') ? 2 : has(G, 'qc') ? 1 : 0) + (polLv(G, 'rob') >= 3 ? 1 : 0);
const crewBonus = G => has(G, 'acv') ? 5 : has(G, 'aec') ? 3 : has(G, 'cp') ? 2 : has(G, 'suit') ? 1 : 0;
const weapons = G => has(G, 'ef') ? 5 : has(G, 'asw') ? 3 : has(G, 'isw') ? 1 : 0;
const baseCostMod = G => has(G, 'ash') ? 3 : has(G, 'ish') ? 2 : has(G, 'hab') ? 1 : 0;
const transferCap = G => (has(G, 'atr') ? 15 : has(G, 'itr') ? 10 : has(G, 'tr') ? 5 : 0) + (G.freight || 0);
const cargoMul = G => has(G, 'sht') ? 2 : 1;
const cvTechOk = (G, sz) => sz <= 2 ? has(G, 'cv') : sz === 3 ? has(G, 'lcv') : sz === 4 ? has(G, 'frig') : sz === 5 ? has(G, 'dest') : sz === 6 ? has(G, 'cru') : has(G, 'bat');
const lvTechOk = (G, n) => n <= 2 ? true : n === 3 ? has(G, 'cv') : has(G, 'uhlv');
const lims = G => { const l = fac(G).lim; return [l[0] + Math.min(2, polLv(G, 'rob')), l[1] + polLv(G, 'hum'), l[2] + Math.min(2, polLv(G, 'set'))]; };
const nonProbeRE = G => G.ships.filter(s => s.cls === 'RE').length;
const nCV = G => G.ships.filter(s => s.cls === 'CV').length;
const nBase = G => G.bases.length;
const transfer = (G, a, b) => { // heliocentric transfer turns between systems, by blocks of 10
  let d = Math.abs(SYS[a].t - SYS[b].t), m = mult(G), t = 0;
  while (d > 10) { t += Math.max(1, Math.round(10 * m)); d -= 10; }
  t += Math.max(1, Math.round(d * m));
  return Math.max(1, t);
};

// ---------- tech markers ----------
const drawMarker = (G, f) => { const v = pick(D.TECH_POOL); G.mk[f].push(v); return v; };
const markerTxt = (vals, f) => vals.length ? vals.map(v => v + ' ' + FN[f]).join(', ') : 'no markers';

// ---------- new game ----------
function newGame(f, opts) {
  opts = opts || {};
  const F = D.FAC[f];
  const G = {
    v: 2, f, y: 2030, phase: 'move', estep: null, cash: F.cash, polm: 2, vm: 0, mk: { Phy: [], Eng: [], Bio: [] }, bank: { Phy: 0, Eng: 0, Bio: 0 },
    tech: {}, pol: {}, rel: {}, w: {}, fly: {}, cache: 0, ships: [], bases: [], lv: { earth: { 1: 0, 2: 0, 3: 0, 4: 0 } }, probes: { earth: [] },
    mis: { pool: [], mine: null, common: null, kept: [], done: 0 }, log: [], nid: 1, rr: opts.rerolls === false ? 0 : 2, ask: [], alpha: { cv: false, re: false },
    turn: { moved: {}, acted: {}, built: {}, terraBuys: {} }, freight: 0, over: false, endYear: null, debt: 0, half: {},
    opts: { optionalEvents: false, ...opts }, estock: { ORE: 0, SUP: 0, FUEL: 0 },
  };
  F.st.forEach(k => G.tech[k] = 1);
  F.pol.forEach(k => G.pol[k] = 1);
  G.t0 = Object.keys(G.tech).length;
  D.FAC_ORDER.filter(k => k !== f).forEach(k => G.rel[k] = 3);
  Object.keys(W).forEach(k => G.w[k] = { v: W[k].v, card: null, sol: false, life: false, terra: 0, npf: null, npfTrade: null, blk: false });
  D.SYS_ORDER.forEach(s => G.fly[s] = { pir: [], ast: 0 });
  // missions: undated in the pool; draw personal + common
  G.mis.pool = D.MIS.filter(m => !m.yr).map(m => m.id);
  G.mis.mine = drawMission(G); G.mis.common = drawMission(G);
  // starting fleet
  (D.START[f] || []).forEach(([cls, name, loc, hold, probe]) => {
    if (cls === 'LV') { G.lv.earth[name]++; return; }
    const s = makeShip(G, name);
    if (!s) return;
    s.loc = loc; s.hold = hold || 0; s.launched = true;
    if (s.kind === 'Orbiter' || s.kind === 'Rover') s.fixed = loc.startsWith('orbit') || loc.startsWith('surf');
    if (probe) s.probe = probe;
    if (s.cls === 'CV' && loc === 'earth') s.launched = false;
  });
  if (opts.scenario === 'fut2060') { futuristicStart(G, F); return G; }
  log(G, `2030: ${F.n} begins the campaign with $${F.cash}B. Your mission: ${misTxt(G.mis.mine)}. Common mission: ${misTxt(G.mis.common)}.`, 'g');
  startMovement(G);
  return G;
}
// FUTURISTIC START (2060): start after the 2060 economic phase with the first two tech columns (not Signs of Life / Existing
// Life), +$40B and $3B per 2030 starting technology on top of the starting cash, three policies to choose for the missed
// economic phases (2040, 2050, 2060), and every world's exploration value reduced by 1.
function futuristicStart(G, F) {
  G.y = 2060; G.scenario = 'fut2060';
  const bonus = 40 + 3 * F.st.length;
  D.TECH.filter(t => D.TECH_POS[t.k] && D.TECH_POS[t.k][1] <= 1 && t.k !== 'sol' && t.k !== 'exl').forEach(t => G.tech[t.k] = 1);
  G.cash += bonus;
  Object.values(G.w).forEach(w => { w.v = Math.max(0, w.v - 1); });
  D.MIS.forEach(m => { if (m.yr && m.yr <= 2060) G.mis.pool.push(m.id); });
  if (G.mis.common == null) G.mis.common = drawMission(G);
  log(G, `2060 (Futuristic start): ${F.n} begins with $${G.cash}B ($${F.cash}B + $40B + $3B × ${F.st.length} starting technologies) and every technology in the first two columns. All worlds' exploration values are reduced by 1. Your mission: ${misTxt(G.mis.mine)}. Common mission: ${misTxt(G.mis.common)}.`, 'g');
  // finish the 2060 economic phase: policies for the three missed decades, then build & service
  G.phase = 'econ'; G.estep = 'policy'; G.policyPicked = false; G.policyLeft = 3;
  log(G, '2060: choose policies for the three missed economic phases (2040, 2050, 2060).', 'h');
}
function makeShip(G, name) {
  const u = unitData(G.f + '|' + name);
  if (!u) return null;
  const s = { id: G.nid++, name: u.n, kind: u.k.startsWith('CV') ? 'CV' : u.k, cls: u.k.startsWith('CV') ? 'CV' : 'RE', sz: u.k.startsWith('CV') ? +u.k.slice(3) : 0,
    ev: u.ev, spec: u.spec, lab: u.lab, cap: u.cargo, prod: u.prod, cb: u.cb, dr: u.dr, cost: { ORE: u.ore, SUP: u.sup, FUEL: u.fuel }, fuel: u.fuel,
    img: u.k + '|' + u.n, loc: 'earth', hold: 0, res: false, dmg: 0, cargo: { ORE: 0, SUP: 0, FUEL: 0 }, probe: null, fixed: false, launched: false };
  if (s.kind === 'Probe') return null;
  G.ships.push(s);
  return s;
}
const misTxt = id => { if (id == null) return 'none'; const m = D.MIS[id]; return `${W[m.w].n}${m.cv ? ' (crewed)' : ''}, ${m.vp} VP`; };
function drawMission(G) {
  const ok = G.mis.pool.filter(id => G.w[D.MIS[id].w].v > 0 && id !== G.mis.mine && id !== G.mis.common && !G.mis.kept.includes(id));
  if (!ok.length) return null;
  const id = pick(ok); G.mis.pool = G.mis.pool.filter(x => x !== id); return id;
}

// ---------- phases ----------
const PHASES = ['econ', 'build', 'move', 'combat', 'explore', 'trade'];
const ESTEPS = ['politics', 'diplomacy', 'production', 'transport', 'placement', 'tech', 'growth', 'policy'];
const PHASE_NAME = { econ: 'Economic phase', build: 'Build & service', move: 'Movement', combat: 'Combat', explore: 'Exploration', trade: 'Trade & bases' };
const ESTEP_NAME = { politics: 'Politics & events', diplomacy: 'Diplomacy', production: 'Production', transport: 'Resource transport', placement: 'Bases, asteroids & pirates', tech: 'Develop technologies', growth: 'Settlement growth', policy: 'Policy' };

function advance(G) {
  if (G.over || G.ask.length) return false;
  if (G.phase === 'econ') {
    const i = ESTEPS.indexOf(G.estep);
    endEstep(G);
    if (i < ESTEPS.length - 1) { G.estep = ESTEPS[i + 1]; startEstep(G); return true; }
    G.estep = null; G.phase = 'build'; startBuild(G); return true;
  }
  const i = PHASES.indexOf(G.phase);
  if (G.phase === 'move') endMovement(G);
  if (G.phase === 'combat') endCombat(G);
  if (G.phase === 'explore') endExplore(G);
  if (G.phase === 'trade') { endYear(G); return true; }
  G.phase = PHASES[i + 1];
  if (G.phase === 'move') startMovement(G);
  if (G.phase === 'combat') startCombat(G);
  if (G.phase === 'explore') startExplore(G);
  if (G.phase === 'trade') startTrade(G);
  return true;
}
function endYear(G) {
  // 3.6.3 end check
  if (G.y >= 2145) {
    const r = d100(), th = G.y - 2144;
    if (G.y >= 2169 || r <= th) { finish(G, G.y >= 2169 ? 'The campaign reaches its final year.' : `End-of-game roll ${r} against ${th}%: the campaign ends.`); return; }
    log(G, `End-of-game roll ${r} against ${th}%: play continues.`);
  }
  G.y++;
  G.turn = { moved: {}, acted: {}, built: {}, terraBuys: {} };
  G.freight = 0;
  lvReturn(G);
  // dated missions join the pool
  D.MIS.forEach(m => { if (m.yr === G.y) { G.mis.pool.push(m.id); log(G, `New mission available: ${misTxt(m.id)}.`); if (G.mis.common == null) G.mis.common = drawMission(G); } });
  if (G.y >= 2040 && G.y % 10 === 0) { G.phase = 'econ'; G.estep = 'politics'; log(G, `${G.y}: economic phase.`, 'h'); startEstep(G); }
  else { G.phase = 'build'; startBuild(G); }
}

// ================= ECONOMIC PHASE =================
function startEstep(G) {
  const s = G.estep;
  if (s === 'politics') {
    const extra = Math.min(2, polLv(G, 'dip')), allies = Object.values(G.rel).filter(v => v === 0).length;
    G.polm += 2 + extra + allies;
    log(G, `Politics: +${2 + extra + allies} markers (2 base${extra ? `, ${extra} Space Diplomacy` : ''}${allies ? `, ${allies} for alliances` : ''}).`, 'g');
    const n = G.y >= 2100 ? 2 : 1, seen = new Set();
    for (let i = 0; i < n; i++) { const r = d100(); const e = D.EVENTS.find(x => r <= x[0]); if (seen.has(e[1])) { log(G, `Event roll ${r}: ${e[2]} again, ignored.`); continue; } seen.add(e[1]); doEvent(G, e, r); }
  }
  if (s === 'diplomacy') {
    const n = G.y >= 2100 ? 2 : 1;
    for (let i = 0; i < n; i++) {
      const r = d10();
      if (r >= 8) { log(G, `Diplomatic drift roll ${r}: no effect.`); continue; }
      const k = D.FAC_ORDER[r - 1];
      if (k === G.f) { Object.keys(G.rel).forEach(x => G.rel[x] = toNeutral(G.rel[x])); log(G, `Diplomatic drift roll ${r}: all your relations drift one step toward Neutral.`); }
      else { const b = G.rel[k]; G.rel[k] = toNeutral(b); if (b !== G.rel[k]) log(G, `Diplomatic drift roll ${r}: relations with ${D.FAC[k].n} drift to ${D.REL[G.rel[k]]}.`); else log(G, `Diplomatic drift roll ${r} (${D.FAC[k].n}): already Neutral.`); }
    }
    G.dipl = {}; // attempts queued by the UI: {fac: +n/-n}
  }
  if (s === 'production') production(G);
  if (s === 'transport') { G.transferLeft = transferCap(G); if (!G.transferLeft) log(G, 'Resource transport needs Trade Routes; skipped.'); }
  if (s === 'placement') placement(G);
  if (s === 'tech') { FIELDS.forEach(f => { const v = G.mk[f].reduce((a, b) => a + b, 0); G.bank[f] += v; G.mk[f] = []; }); log(G, `Tech markers converted to points: ${FIELDS.map(f => G.bank[f] + ' ' + FN[f]).join(', ')}.`, 'g'); }
  if (s === 'growth') growth(G);
  if (s === 'policy') { G.policyPicked = false; }
}
function endEstep(G) {
  const s = G.estep;
  if (s === 'diplomacy') resolveDiplomacy(G);
  if (s === 'tech') {
    if (G.polm > 0) { log(G, `${G.polm} unconverted politics marker(s) discarded at the end of the tech step.`); G.polm = 0; }
    FIELDS.forEach(f => G.bank[f] = Math.round(G.bank[f] / 2 + 1e-9));
    log(G, `Tech bank halved: ${FIELDS.map(f => G.bank[f] + ' ' + FN[f]).join(', ')}.`);
  }
  if (s === 'policy' && !G.policyPicked) log(G, G.policyLeft > 1 ? `${G.policyLeft} missed policies not chosen.` : 'No new policy chosen this decade.');
  if (s === 'policy') G.policyLeft = 0;
}
const toNeutral = v => v < 3 ? v + 1 : v > 3 ? v - 1 : 3;
function doEvent(G, e, r) {
  const [, k, n, txt] = e;
  log(G, `Event roll ${r}: ${n}. ${txt}`, 'e');
  if (k === 'publicity') G.ask.push({ k: 'publicity', text: 'Publicity Campaign: choose a world to raise its exploration value by 2.' });
  if (k === 'budget') { G.cash += 5; log(G, 'You earn $5B extra this decade.'); }
  if (k === 'miners') { G.half.res = true; G.bases.forEach(b => { if (b.fac.mine) b.dmg.mine++; }); }
  if (k === 'research') { G.half.tech = true; G.bases.forEach(b => { if (b.fac.lab) b.dmg.lab++; }); }
  if (k === 'dockyard') G.bases.forEach(b => { let n2 = 2; for (const r2 of RES) { const t = Math.min(n2, b.stock[r2]); b.stock[r2] -= t; n2 -= t; } if (b.fac.sup) b.dmg.sup++; });
  if (k === 'disaster') { const wk = randomWorld(); log(G, `Disaster strikes ${W[wk].n}.`); G.bases.filter(b => b.w === wk).forEach(b => { ['lab', 'mine', 'sup', 'def'].forEach(c => { if (b.fac[c]) b.dmg[c]++; }); RES.forEach(r2 => b.stock[r2] = Math.floor(b.stock[r2] / 2)); }); }
  if (k === 'race') log(G, 'In solo play every player is tied, so Space Race has no effect.');
  if (k === 'freight') { G.freight = 5; log(G, 'You may transfer up to 5 extra resources in the transport step.'); }
  if (k === 'immigration') { if (G.bases.length) G.ask.push({ k: 'immigration', text: 'Immigration: choose a base to receive 2 settlements.' }); else log(G, 'You have no base, so Immigration has no effect.'); }
  if (k === 'thaw') Object.keys(G.rel).forEach(x => G.rel[x] = toNeutral(G.rel[x]));
  if (k === 'survey') { const wk = randomWorld(); const c = drawCardFor(wk); if (c) { G.w[wk].card = c; log(G, `Survey Error: ${W[wk].n} receives world card ${c}.`); } else log(G, `Survey Error at ${W[wk].n}: the card did not fit.`); }
  if (k === 'swarm') G.extraPirate = true;
  if (k === 'harvest') G.extraAsteroid = true;
  if (k === 'comet') G.w.com.v += 3;
  if (k === 'signals') { G.w.alp.v += 4; G.w.dsa.v += 4; }
  if (k === 'storm') {
    G.ships.slice().forEach(s => {
      if (s.loc === 'earth' || atOwnBase(G, s)) return;
      if (s.cls === 'CV') { s.dmg++; log(G, `${s.name} takes solar storm damage.`); if (s.dmg >= s.sz) loseCV(G, s, 'to the solar storm'); }
      else if (d10() <= 2) { removeShip(G, s); log(G, `${s.name} is destroyed by the solar storm.`, 'x'); }
    });
  }
}
const randomWorld = () => { const r = d100(); const k = Object.keys(W).find(k => W[k].rng && r >= W[k].rng[0] && r <= W[k].rng[1]); return k || 'mar'; };
const drawCardFor = wk => { const c = pick(D.CARDS); return D.cardOk(c, W[wk]) ? c.n : null; };

// diplomacy: G.dipl = {fac: delta} (positive = improve). Cost 1,2,3... markers per attempt; success on d10 <= 6
function dipCost(G) { const n = Object.values(G.dipl || {}).reduce((a, b) => a + Math.abs(b), 0); return n * (n + 1) / 2; }
function setDiplomacy(G, k, delta) {
  if (G.estep !== 'diplomacy') return 'Diplomacy happens in the economic phase.';
  const cur = (G.dipl[k] || 0) + delta;
  const prev = G.dipl[k]; G.dipl[k] = cur;
  if (dipCost(G) > G.polm) { G.dipl[k] = prev || 0; return `That needs ${dipCost({ dipl: { ...G.dipl, [k]: cur } })} politics markers; you have ${G.polm}.`; }
  if (!cur) delete G.dipl[k];
  return null;
}
function resolveDiplomacy(G) {
  const cost = dipCost(G);
  if (!cost) return;
  G.polm -= cost;
  Object.entries(G.dipl).forEach(([k, d]) => {
    let net = 0;
    for (let i = 0; i < Math.abs(d); i++) { const r = d10(); if (r <= 6) net += Math.sign(d); }
    const before = G.rel[k];
    let nv = Math.max(0, Math.min(5, before - net));
    if (nv >= 4 && polLv(G, 'mil') < 1) nv = Math.min(nv, 3);
    if (nv >= 5 && polLv(G, 'mil') < 2) nv = Math.min(nv, 4);
    G.rel[k] = nv;
    log(G, `Diplomacy with ${D.FAC[k].n}: ${Math.abs(d)} attempt(s) ${d > 0 ? 'to improve' : 'to worsen'} relations, net ${net >= 0 ? '+' : ''}${net}. Now ${D.REL[nv]}.`, 'g');
  });
  log(G, `Diplomacy cost ${cost} politics markers.`);
  G.dipl = {};
}

function supportCost(n, lim, steps) { if (n <= lim) return lim - n; let c = 0; for (let i = 0; i < n - lim; i++) c += steps[i] || steps[steps.length - 1]; return -c; }
function production(G) {
  const F = fac(G), row = F.pr[decadeRow(G.y)];
  let cash = row[0] + [0, 2, 4, 8][polLv(G, 'eco')];
  const parts = [`Earth $${row[0]}B`];
  if (polLv(G, 'eco')) parts.push(`policy +$${[0, 2, 4, 8][polLv(G, 'eco')]}B`);
  let relB = 0; Object.values(G.rel).forEach(v => { if (v <= 2) relB += F.rel[v][0]; });
  if (relB) { cash += relB; parts.push(`relations +$${relB}B`); }
  const misB = G.mis.kept.length; if (misB) { cash += misB; parts.push(`missions +$${misB}B`); }
  const blk = Object.values(G.w).filter(x => x.npf && x.blk).length * 2; if (blk) { cash += blk; parts.push(`blockades +$${blk}B`); }
  const pir = Object.values(G.fly).reduce((a, f) => a + f.pir.length, 0); if (pir) { cash -= pir; G.cache += pir; parts.push(`pirates -$${pir}B`); }
  const [lre, lcv, lb] = lims(G);
  const sup = supportCost(nonProbeRE(G), lre, [2, 3, 4, 5]) + supportCost(nCV(G), lcv, [4, 6, 8, 10]) + supportCost(nBase(G), lb, [4, 6, 8, 10]);
  cash += sup; parts.push(`support ${sup >= 0 ? '+' : '-'}$${Math.abs(sup)}B`);
  if (G.debt) { cash -= G.debt; parts.push(`pirate debt -$${G.debt}B`); G.debt = 0; }
  G.cash += cash;
  let tp = { Phy: row[1], Eng: row[2], Bio: row[3] };
  if (has(G, 'sol')) tp.Bio += 2;
  if (has(G, 'exl')) { tp.Bio += 3; tp.Phy += 2; }
  FIELDS.forEach(f => G.bank[f] += tp[f]);
  log(G, `Production: ${parts.join(', ')} = $${cash}B. Tech points +${tp.Phy} Physics, +${tp.Eng} Engineering, +${tp.Bio} Biology.`, 'g');
  // bases
  G.bases.forEach(b => {
    const o = baseOutput(G, b);
    if (!o) return;
    if (o.type === 'tech') { G.bank[o.field] += o.n; log(G, `${b.name} (${W[b.w].n}) produces ${o.n} ${FN[o.field]} points.`, 'g'); }
    else { b.stock[o.type] += o.n; log(G, `${b.name} (${W[b.w].n}) produces ${o.n} ${o.type}.`, 'g'); }
  });
  if (G.cash < 0) log(G, `Your cash is negative ($${G.cash}B). Scrap ships or bases to recover.`, 'x');
  G.half = {};
}
const setRow = n => { let r = null; D.SETT.forEach(x => { if (n >= x[0]) r = x; }); return r; };
function baseOutput(G, b, type) {
  type = type || b.out;
  const w = W[b.w], ws = G.w[b.w], card = ws.card ? D.CARDS.find(c => c.n === ws.card) : null;
  const sr = setRow(b.set - (b.setDmg || 0));
  const pir = G.fly[w.sys].pir.length;
  if (type === 'tech') {
    if (!b.fac.lab) return null;
    let field = card ? card.rf : w.f, n = b.w === 'ear' ? 3 : card ? card.rv : 0;
    if (b.w === 'ear') field = b.techField || 'Phy';
    if (n <= 0) return null;
    n += (b.fac.lab >= 2 ? 3 : 0) + (sr ? sr[3] : 0) + (ws.life ? 2 : ws.sol ? 1 : 0) - b.dmg.lab - pir;
    if (G.half.tech) n = Math.round(n / 2);
    return n > 0 ? { type: 'tech', field, n } : null;
  }
  if (!b.fac.mine || b.w === 'ear') return null;
  let n = (card ? card.prod[type] : 0) + (w.prod[type] || 0);
  if (n <= 0) return null;
  n += D.MINE_BONUS[b.fac.mine] + (sr ? sr[2] : 0) + (G.f === 'as' ? 1 : 0) - b.dmg.mine - pir;
  if (G.half.res) n = Math.round(n / 2);
  return n > 0 ? { type, n } : null;
}
function bestOutput(G, b) {
  let best = null;
  ['tech', ...RES].forEach(t => { const o = baseOutput(G, b, t); if (o && (!best || o.n > best.n)) best = { ...o, t }; });
  return best ? best.t : 'ORE';
}
// resource transfers (Trade Routes): from (earth|baseId) to (earth|baseId)
function transferRes(G, from, to, type, n) {
  if (G.estep !== 'transport') return 'Transfers happen in the resource transport step.';
  if (n > G.transferLeft) return `You can transfer ${G.transferLeft} more this decade.`;
  const src = from === 'earth' ? null : G.bases.find(b => b.id === from), dst = to === 'earth' ? null : G.bases.find(b => b.id === to);
  if (src && src.stock[type] < n) return `${src.name} has only ${src.stock[type]} ${type}.`;
  if (!src && G.cash < earthCash(G, { [type]: n })) return `Sending ${n} ${type} from Earth costs ${earthCostTxt(G, { [type]: n })}.`;
  for (const b of [src, dst]) if (b && G.fly[W[b.w].sys].pir.length) return `A pirate in the ${SYS[W[b.w].sys].n} flyby box blocks transfers there.`;
  if (src) src.stock[type] -= n; else payEarth(G, { [type]: n });
  if (dst) dst.stock[type] += n; else estock(G)[type] += n;
  G.transferLeft -= n;
  log(G, `Transferred ${n} ${type} from ${src ? src.name : 'Earth'} to ${dst ? dst.name : 'Earth (faction board)'}.`);
  return null;
}
function placement(G) {
  const dec = Math.floor(G.y / 10) * 10;
  const r = d100(); const wk = Object.keys(W).find(k => W[k].rng && r >= W[k].rng[0] && r <= W[k].rng[1]);
  if (wk && SYS[W[wk].sys].dec && SYS[W[wk].sys].dec <= dec && !G.w[wk].npf && W[wk].base) {
    const npf = pick(Object.keys(G.rel)); G.w[wk].npf = npf; log(G, `NPF base roll ${r}: ${D.FAC[npf].n} founds a base at ${W[wk].n}.`, 'e');
  } else log(G, `NPF base roll ${r}: no new base.`);
  const place = (what) => {
    const r2 = d100(), k = Object.keys(W).find(x => W[x].rng && r2 >= W[x].rng[0] && r2 <= W[x].rng[1]);
    if (!k) return;
    const s = W[k].sys;
    if (!SYS[s].dec || SYS[s].dec > dec) { log(G, `${what} roll ${r2}: ${SYS[s].n} is not open yet.`); return; }
    if (what === 'Pirate') { G.fly[s].pir.push({ strong: G.y >= 2120, dmg: 0 }); G.cache += 5; log(G, `Pirate roll ${r2}: a pirate appears in the ${SYS[s].n} flyby box (+$5B to the pirate cache).`, 'x'); }
    else { G.fly[s].ast++; log(G, `Asteroid roll ${r2}: an asteroid enters the ${SYS[s].n} flyby box.`, 'e'); }
  };
  if (G.y >= 2050) {
    const n = G.y >= 2100 ? 2 : 1;
    for (let i = 0; i < n; i++) { place('Asteroid'); place('Pirate'); }
    if (G.extraAsteroid) place('Asteroid');
    if (G.extraPirate) place('Pirate');
  }
  G.extraAsteroid = G.extraPirate = false;
  // trade markers: NPF bases and player bases with settlements
  const tm = () => ({ side: pick(['buy', 'sell']), type: pick(RES) });
  Object.keys(G.w).forEach(k => { if (G.w[k].npf && !G.w[k].npfTrade && !G.w[k].blk) G.w[k].npfTrade = tm(); });
  G.bases.forEach(b => { if (b.set > 0 && !b.trade) b.trade = tm(); });
}
function growth(G) {
  G.bases.forEach(b => {
    if (!b.set) return;
    const full = Math.floor(b.set / 10), rem = b.set % 10;
    let r = d10(); if (polLv(G, 'set') >= 3) r = Math.min(r, d10());
    const gain = full + (rem && r <= rem ? 1 : 0);
    if (gain) { b.set += gain; log(G, `${b.name} grows by ${gain} settlement(s) to ${b.set}.`, 'g'); }
  });
}
// cost = chart cost, -3 for each other faction that has the technology (the non-player factions keep their starting
// technologies in solo play), China -4 each instead; North America -2 when it is the first to have it; minimum 5
const techHolders = (G, t) => Object.keys(D.FAC).filter(f => f !== G.f && (D.FAC[f].st || []).includes(t.k));
function techCost(G, t) { const n = techHolders(G, t).length; return Math.max(5, t.c - n * (G.f === 'cn' ? 4 : 3) - (G.f === 'na' && !n ? 2 : 0)); }
function techCostTxt(G, t) {
  const h = techHolders(G, t), per = G.f === 'cn' ? 4 : 3, parts = [`chart ${t.c}`];
  if (h.length) parts.push(`-${h.length * per} (${h.map(f => D.FAC[f].n).join(', ')} ${h.length > 1 ? 'have' : 'has'} it)`);
  if (G.f === 'na' && !h.length) parts.push('-2 (first to develop it)');
  const raw = t.c - h.length * per - (G.f === 'na' && !h.length ? 2 : 0);
  return parts.join(' ') + (raw < 5 ? ', minimum 5' : '');
}
function techState(G, t) {
  if (G.tech[t.k]) return 'have';
  if (t.r.some(x => !G.tech[x])) return 'locked';
  if ((t.k === 'sol') && !Object.values(G.w).some(w => w.sol)) return 'locked';
  if ((t.k === 'exl') && !Object.values(G.w).some(w => w.life)) return 'locked';
  return 'open';
}
function develop(G, k) {
  const t = D.TECHK[k];
  if (G.estep !== 'tech') return 'Technologies are developed in the economic phase tech step.';
  if (techState(G, t) !== 'open') return `${t.n} needs ${t.r.filter(x => !G.tech[x]).map(x => D.TECHK[x].n).join(', ') || 'signs of life to have been found'}.`;
  const c = techCost(G, t);
  if (G.bank[t.f] < c) return `${t.n} costs ${c} ${FN[t.f]} points; you have ${G.bank[t.f]}.`;
  G.bank[t.f] -= c; G.tech[k] = 1;
  log(G, `Developed ${t.n} for ${c} ${FN[t.f]} points: ${t.d}.`, 'g');
  return null;
}
function convertPolitics(G, to) { // to: 'cash' | field
  if (G.polm < 1) return 'No politics markers left.';
  G.polm--;
  if (to === 'cash') G.cash++; else G.bank[to] += polLv(G, 'dip') >= 3 ? 3 : 2;
  return null;
}
function buyVictory(G) { if (G.polm < 4) return 'A victory marker costs 4 politics markers.'; G.polm -= 4; G.vm++; log(G, 'Bought a victory marker with 4 politics markers.', 'g'); return null; }
function redrawMission(G) { if (G.polm < 2) return 'Redrawing a mission costs 2 politics markers.'; if (G.mis.mine == null) return 'You have no mission to redraw.'; G.polm -= 2; G.mis.pool.push(G.mis.mine); G.mis.mine = drawMission(G); log(G, `Mission redrawn: ${misTxt(G.mis.mine)}.`); return null; }
function tradePoints(G, f, dir) { // Genetic Engineering / Matter-Energy Conversion / Nano-Technology
  const k = { Bio: 'gen', Phy: 'mec', Eng: 'nano' }[f];
  if (!has(G, k)) return `You need ${D.TECHK[k].n}.`;
  if (dir === 'buy') { if (G.cash < 1) return 'Not enough cash.'; G.cash--; G.bank[f]++; }
  else { if (G.bank[f] < 2) return 'Not enough points.'; G.bank[f] -= 2; G.cash++; }
  return null;
}
function choosePolicy(G, k) {
  if (G.estep !== 'policy') return 'Policies are chosen in the policy step.';
  if (G.policyPicked) return 'You already chose a policy this decade.';
  const lv = polLv(G, k);
  if (lv >= 3) return 'That policy is already Unified.';
  if (lv === 2 && Object.values(G.pol).includes(3)) return 'You can hold only one Unified policy.';
  if (Object.values(G.pol).reduce((a, b) => a + b, 0) >= 10) return 'You already hold 10 policies.';
  G.pol[k] = lv + 1;
  if (G.policyLeft > 0) { G.policyLeft--; G.policyPicked = G.policyLeft <= 0; } else G.policyPicked = true;
  const p = D.POL.find(x => x.k === k);
  log(G, `Adopted ${D.POL_LV[lv]}${p.n}: ${p.d[lv]}.`, 'g');
  return null;
}

// ================= BUILD & SERVICE =================
function startBuild(G) { log(G, `${G.y}: build and service ships.`, 'h'); }
// buildable list at a location (earth or base id)
function buildOptions(G, where) {
  const out = [];
  const base = where === 'earth' ? null : G.bases.find(b => b.id === where);
  const supLv = base ? base.fac.sup - (base.dmg.sup ? 1 : 0) : 4;
  const inUse = new Set(G.ships.map(s => s.name).concat(Object.values(G.probes).flat()).concat(G.ships.map(s => s.probe).filter(Boolean)));
  Object.keys(UNITS).filter(k => k.startsWith(G.f + '|')).forEach(k => {
    const u = UNITS[k];
    const cv = u.k.startsWith('CV'), sz = cv ? +u.k.slice(3) : 0;
    let why = null;
    if (inUse.has(u.n)) why = 'in service';
    else if (cv && !cvTechOk(G, sz)) why = 'needs ' + (sz <= 2 ? 'Crew Vehicles' : sz === 3 ? 'Large Crew Vehicles' : sz === 4 ? 'Frigates' : sz === 5 ? 'Destroyers' : sz === 6 ? 'Cruisers' : 'Battleships');
    else if (!base && cv && sz > 4 && !has(G, 'elev')) why = 'too large to build on Earth';
    else if (base && (cv && sz > 2 ? supLv < 4 : supLv < 3)) why = cv && sz > 2 ? 'needs a large Spaceport' : 'needs a Spaceport';
    const cost = { ORE: u.ore, SUP: u.sup, FUEL: u.fuel };
    out.push({ key: k, u, cost, why, kind: u.k, cv, sz });
  });
  return out;
}
// Earth: resources on the faction board are used first, the rest is bought at $1B each. Bases only use their own resources.
const estock = G => G.estock || (G.estock = { ORE: 0, SUP: 0, FUEL: 0 });
const earthCash = (G, cost) => RES.reduce((a, r) => a + Math.max(0, (cost[r] || 0) - estock(G)[r]), 0);
function payEarth(G, cost) {
  const used = {}, st = estock(G); let cash = 0;
  RES.forEach(r => { const need = cost[r] || 0, u = Math.min(need, st[r]); used[r] = u; st[r] -= u; cash += need - u; });
  G.cash -= cash; return { used, cash };
}
const unpayEarth = (G, paid) => { addRes(estock(G), paid.used); G.cash += paid.cash; };
const earthCostTxt = (G, cost) => { const st = estock(G), fromSt = RES.filter(r => Math.min(cost[r] || 0, st[r]) > 0).map(r => `${Math.min(cost[r], st[r])} ${r}`), cash = earthCash(G, cost); return [fromSt.length ? fromSt.join(' + ') + ' from the faction board' : '', cash ? `$${cash}B` : ''].filter(Boolean).join(' + ') || 'free'; };
const payable = (G, where, cost) => where === 'earth' ? G.cash >= earthCash(G, cost) : enough(G.bases.find(b => b.id === where).stock, cost);
const pay = (G, where, cost) => { if (where === 'earth') payEarth(G, cost); else addRes(G.bases.find(b => b.id === where).stock, cost, -1); };
function buildUnit(G, key, where, reserved) {
  if (G.phase !== 'build') return 'Ships are built in the build & service phase.';
  const opt = buildOptions(G, where).find(o => o.key === key);
  if (!opt) return 'Unknown unit.';
  if (opt.why) return `${opt.u.n}: ${opt.why}.`;
  const cost = { ...opt.cost };
  if (reserved && opt.cv) { cost.SUP = Math.max(0, cost.SUP - 1); cost.FUEL = Math.max(0, cost.FUEL - 1); }
  const [lre, lcv] = lims(G);
  if (opt.cv && nCV(G) >= lcv + 4) return 'You are already 4 crew vehicles over your support limit.';
  if (!opt.cv && opt.kind !== 'Probe' && nonProbeRE(G) >= lre + 4) return 'You are already 4 robotic explorers over your support limit.';
  if (!payable(G, where, cost)) return `${opt.u.n} costs ${where === 'earth' ? earthCostTxt(G, cost) : resTxt(cost)}.`;
  const paidTxt = where === 'earth' ? earthCostTxt(G, cost) : resTxt(cost);
  pay(G, where, cost);
  const loc = where === 'earth' ? 'earth' : baseLoc(G.bases.find(b => b.id === where));
  if (opt.kind === 'Probe') { (G.probes[loc] = G.probes[loc] || []).push(opt.u.n); }
  else { const s = makeShip(G, opt.u.n); s.loc = loc; s.res = !!reserved && opt.cv; s.built = G.y; }
  log(G, `Built ${opt.kind} ${opt.u.n}${reserved && opt.cv ? ' (reserved)' : ''} at ${where === 'earth' ? 'Earth' : G.bases.find(b => b.id === where).name} for ${paidTxt}.`, 'g');
  return null;
}
// two-sided LV counters. A faction has c13 LV-1/LV-3 counters, c24 LV-2/LV-4 counters, and (North America) c14 LV-1/LV-4.
// LV-1s always use the LV-1/LV-4 counter first (North America's first LV-1 is the one with LV-4 on its back).
// k = LV-1s showing on LV-1/LV-4 counters. A new LV-1 always goes on a free LV-1/LV-4 counter first (one not
// showing LV-4); when an LV-1 leaves play its LV-1/LV-3 counter is freed first. Tracked in G.lv14 / G.lvN1.
function lvK(G) {
  const c = fac(G).lvs, c14 = c[14] || 0, c24 = c[24] || 0, n = lvCount(G);
  if (!c14) return 0;
  let k = Math.min(G.lv14 || 0, n[1]), prev = G.lvN1 || 0;
  if (n[1] < prev) { let gone = prev - n[1]; const on13 = prev - (G.lv14 || 0); gone -= Math.min(gone, Math.max(0, on13)); k = Math.max(0, Math.min(n[1], (G.lv14 || 0) - gone)); }
  for (let add = n[1] - Math.max(prev, k); add > 0; add--) if (k < c14 && n[2] + n[4] <= c24 + c14 - k - 1) k++;
  G.lv14 = k; G.lvN1 = n[1];
  return k;
}
function lvSplit(G, n) {
  const c = fac(G).lvs, c13 = c[13] || 0, c14 = c[14] || 0, c24 = c[24] || 0;
  let k = lvK(G);
  // the LV-1 being added takes a free LV-1/LV-4 counter if there is one
  const cur = lvCount(G); if (n[1] > cur[1] && k < c14 && cur[2] + cur[4] <= c24 + c14 - k - 1) k++;
  return n[1] - k + n[3] <= c13 && n[2] <= c24 && n[2] + n[4] <= c24 + c14 - k ? k : -1;
}
const lvFits = (G, n) => lvSplit(G, n) >= 0;
function lvCanAdd(G, z) { const n = lvCount(G); n[z]++; return lvFits(G, n); }
function lvPoolTxt(G) {
  const c = fac(G).lvs, n = lvCount(G), on14 = lvK(G);
  const parts = [`LV-1/LV-3 counters: ${c[13]} (${n[1] - on14} as LV-1, ${n[3]} as LV-3)`];
  if (c[14]) parts.push(`LV-1/LV-4 counter: ${c[14]} (${on14 ? 'in use as LV-1' : 'free'})`);
  if (c[14]) parts[1] = `LV-1/LV-4 counter: ${c[14]} (${on14 ? 'in use as LV-1' : n[4] > c[24] - n[2] ? 'in use as LV-4' : 'free'})`;
  parts.push(`LV-2/LV-4 counters: ${c[24]} (${n[2]} as LV-2, ${Math.min(n[4], c[24] - n[2])} as LV-4)`);
  return parts.join('; ');
}
const lvCount = (G) => { let n = { 1: 0, 2: 0, 3: 0, 4: 0 }; [G.lv, G.lvCool || {}].forEach(L => Object.values(L).forEach(st => [1, 2, 3, 4].forEach(z => n[z] += st[z] || 0))); return n; };
const lvRecover = (G, key, z) => { G.lvCool = G.lvCool || {}; G.lvCool[key] = G.lvCool[key] || { 1: 0, 2: 0, 3: 0, 4: 0 }; G.lvCool[key][z]++; };
function lvReturn(G) { Object.entries(G.lvCool || {}).forEach(([k, st]) => { G.lv[k] = G.lv[k] || { 1: 0, 2: 0, 3: 0, 4: 0 }; [1, 2, 3, 4].forEach(z => G.lv[k][z] += st[z] || 0); }); G.lvCool = {}; }
function buildLV(G, n, where) {
  if (G.phase !== 'build') return 'Launch vehicles are built in the build & service phase.';
  if (!lvTechOk(G, n)) return n === 3 ? 'LV-3 needs Crew Vehicles.' : 'LV-4 needs Ultra-Heavy Launch Vehicles.';
  if (!lvCanAdd(G, n)) return `No free counter for an LV-${n}: ${n === 1 || n === 3 ? 'LV-1 and LV-3' : 'LV-2 and LV-4'} share two-sided counters, and all that can show LV-${n} are in use.`;
  const base = where === 'earth' ? null : G.bases.find(b => b.id === where);
  if (base && base.fac.sup - (base.dmg.sup ? 1 : 0) < (n <= 2 ? 1 : 2)) return `LV-${n} needs a ${n <= 2 ? 'small' : 'large'} Supply Station.`;
  const cost = { ORE: 1, FUEL: n };
  if (!payable(G, where, cost)) return `LV-${n} costs ${where === 'earth' ? earthCostTxt(G, cost) : resTxt(cost)}.`;
  pay(G, where, cost);
  const key = where === 'earth' ? 'earth' : where;
  G.lv[key] = G.lv[key] || { 1: 0, 2: 0, 3: 0, 4: 0 }; G.lv[key][n]++;
  log(G, `Built LV-${n} at ${base ? base.name : 'Earth'}.`);
  return null;
}
function serviceSite(G, s) { // where a CV can be unreserved/repaired: returns {where, level}
  if (s.loc === 'earth' || (s.loc === 'orbit:ear' && has(G, 'elev'))) return { where: 'earth', level: 4 };
  const b = atOwnBase(G, s); if (!b) return null;
  return { where: b.id, level: b.fac.sup - (b.dmg.sup ? 1 : 0) };
}
const unreserveLevel = sz => sz <= 2 ? 1 : sz === 3 ? 2 : sz <= 5 ? 3 : 4;
function unreserve(G, s) {
  if (G.phase !== 'build') return 'Crew vehicles are unreserved in the build & service phase.';
  if (!s.res) return `${s.name} is not reserved.`;
  const site = serviceSite(G, s);
  if (!site) return `${s.name} must be at Earth or one of your bases with a Supply Station or Spaceport.`;
  if (site.level < unreserveLevel(s.sz)) return `${s.name} needs a ${['', 'small Supply Station', 'large Supply Station', 'small Spaceport', 'large Spaceport'][unreserveLevel(s.sz)]}.`;
  const cost = { SUP: 1, FUEL: 1 };
  if (!payable(G, site.where, cost)) return site.where === 'earth' ? `Unreserving costs ${earthCostTxt(G, cost)}.` : 'Unreserving costs 1 SUP and 1 FUEL.';
  pay(G, site.where, cost); s.res = false;
  log(G, `${s.name} returns to active service.`, 'g');
  return null;
}
function repair(G, s) {
  if (G.phase !== 'build') return 'Repairs happen in the build & service phase.';
  if (!s.dmg) return `${s.name} has no damage.`;
  const site = serviceSite(G, s);
  if (!site || site.level < 1) return `${s.name} must be at Earth or a base with a Supply Station or Spaceport.`;
  const cap = [0, 1, 2, 3, 99][site.level];
  const n = Math.min(s.dmg, cap);
  const cost = { ORE: n };
  if (!payable(G, site.where, cost)) return `Repairing ${n} damage costs ${site.where === 'earth' ? earthCostTxt(G, cost) : n + ' ORE'}.`;
  pay(G, site.where, cost); s.dmg -= n;
  log(G, `Repaired ${n} damage on ${s.name}.`);
  return null;
}
function setReserve(G, s) {
  if (G.phase !== 'build') return 'You can reserve a crew vehicle at the start of a turn.';
  if (s.cls !== 'CV' || s.res) return null;
  s.res = true; log(G, `${s.name} is placed in reserve.`); return null;
}
// optional rule (G.opts.scrapRE): robotic explorers and launch vehicles can be scrapped at your bases and on Earth like crew vehicles
const scrapRule = G => !!(G.opts && G.opts.scrapRE);
function scrapSite(G, s) {
  if (s.cls === 'RE') {
    // telescopes (Earth orbit) and unlaunched explorers scrap on Earth; orbiters over a world with your base and
    // rovers on the surface with your surface base scrap at that base
    if (!scrapRule(G)) return null;
    if (s.loc === 'earth' || (s.kind === 'Telescope' && s.loc === 'orbit:ear')) return { where: 'earth' };
    const p = P(s.loc);
    if (s.kind === 'Orbiter' && p.t === 'orbit') { const b = G.bases.find(x => x.w === p.w); return b ? { where: b.id } : null; }
    if (s.kind === 'Rover' && p.t === 'surf') { const b = G.bases.find(x => baseLoc(x) === s.loc); return b ? { where: b.id } : null; }
    return null;
  }
  return serviceSite(G, s);
}
function refundHalf(G, where, cost) {
  const back = {}; RES.forEach(r => back[r] = Math.round((cost[r] || 0) / 2));
  if (where === 'earth') { addRes(estock(G), back); return `recovered ${resTxt(back)} to the faction board`; }
  addRes(G.bases.find(b => b.id === where).stock, back); return `recovered ${resTxt(back)}`;
}
function scrap(G, s) {
  // only undamaged crew vehicles can be scrapped; a damaged one is simply destroyed
  const site = s.cls === 'CV' && s.dmg ? null : scrapSite(G, s);
  if (site) {
    const c = { ...s.cost }; if (s.res) { c.SUP = Math.max(0, (c.SUP || 0) - 1); c.FUEL = Math.max(0, (c.FUEL || 0) - 1); }
    log(G, `${s.name} scrapped at ${site.where === 'earth' ? 'Earth' : G.bases.find(b => b.id === site.where).name}; ${refundHalf(G, site.where, c)}.`);
    if (s.probe && site.where === 'earth') (G.probes.earth = G.probes.earth || []).push(s.probe);
  } else log(G, `${s.name} is ${s.cls === 'CV' ? 'decommissioned' : 'destroyed'}.`);
  addRes(cargoDump(G, s), s.cargo || {});
  removeShip(G, s);
  return null;
}
function scrapLV(G, where, z) {
  if (!scrapRule(G)) return 'Scrapping launch vehicles is an optional rule (turn it on in Settings before starting a campaign).';
  const st = G.lv[where]; if (!st || !st[z]) return `No LV-${z} ready at ${where === 'earth' ? 'Earth' : 'that base'}.`;
  st[z]--;
  log(G, `LV-${z} scrapped at ${where === 'earth' ? 'Earth' : G.bases.find(b => b.id === where).name}; ${refundHalf(G, where, { ORE: 1, FUEL: z })}. Its counter is free again.`);
  return null;
}
const cargoDump = (G, s) => { if (s.loc === 'earth') return estock(G); const b = atOwnBase(G, s); return b ? b.stock : {}; };
function removeShip(G, s) { G.ships = G.ships.filter(x => x !== s); }
function loseCV(G, s, why) {
  removeShip(G, s);
  const n = s.sz >= 3 ? 5 : 3, got = []; for (let i = 0; i < n; i++) got.push(drawMarker(G, 'Eng'));
  log(G, `${s.name} is lost ${why}. Lessons learned: ${markerTxt(got, 'Eng')}.`, 'x');
}
function loseRE(G, s, why) {
  removeShip(G, s);
  const v = drawMarker(G, 'Eng');
  log(G, `${s.kind} ${s.name}${s.probe ? ' and probe ' + s.probe : ''} ${why}. Lessons learned: ${v} Engineering.`, 'x');
}

// ================= MOVEMENT =================
function startMovement(G) {
  // 3.3.1 drop ships in transfer boxes
  G.ships.forEach(s => {
    const p = P(s.loc);
    if (p.t !== 'box') return;
    if (s.hold > 0) { s.hold--; return; }
    s.loc = p.n > 1 ? `box:${p.s}:${p.n - 1}` : `fly:${p.s}`;
    if (p.n === 1) log(G, `${s.name} arrives in the ${SYS[p.s].n} flyby box.`);
  });
  if (G.y > 2030 || G.phase !== 'move') log(G, `${G.y}: movement. Ships in transfer boxes have moved one box closer.`, 'h');
}
function endMovement(G) { G.ships.forEach(s => { if (P(s.loc).t === 'fly' && s.kind === 'Flyby') s.flyArrive = G.y; }); }
const atOwnBase = (G, s) => { const w = worldOf(s.loc); if (!w || P(s.loc).t === 'fly' || P(s.loc).t === 'box') return null; return G.bases.find(b => b.w === w && (baseLoc(b) === s.loc || (has(G, 'elev') && P(s.loc).t === 'orbit'))) || null; };
const baseLoc = b => (W[b.w].tags.includes('station') ? 'orbit:' : 'surf:') + b.w;
// can a CV be at this location (range + hazards)?
function cvAllowed(G, s, loc) {
  const p = P(loc), sy = sysOf(loc);
  if (sy === 'mer' && !has(G, 'ars')) return 'Mercury\'s severe radiation needs Active Radiation Shielding';
  if (sy === 'alp' && range(G) < 99) return 'Alpha Centauri needs Safe Crew Hibernation';
  if (p.w) {
    const w = W[p.w];
    if (w.tags.includes('tele')) return 'only telescopes can explore there';
    if (w.tags.includes('sunobs')) return 'crew vehicles cannot explore the Sun';
    if (w.tags.includes('rad') && !has(G, 'ars')) return 'severe radiation needs Active Radiation Shielding';
    if (isGas(p.w) && p.t === 'surf') return 'crew vehicles cannot enter a gas giant';
    if (p.t === 'surf' && w.tags.includes('severeAtm') && !has(G, 'psh')) return 'severe atmosphere needs Pressure Shell';
    if (p.t === 'surf' && w.tags.includes('reentry') && s.sz > 4) return 're-entry is limited to CV-4 and smaller';
    if (w.sys === 'ear' && p.w !== 'ear' && !has(G, 'orb')) return 'the Moon and Near Earth Asteroids need Orbital Rendezvous';
  }
  if (sy !== 'ear' || p.t === 'box') {
    // range from Earth or a base able to unreserve this CV
    const r = range(G), need = unreserveLevel(s.sz);
    const origins = [0].concat(G.bases.filter(b => b.fac.sup - (b.dmg.sup ? 1 : 0) >= need).map(b => SYS[W[b.w].sys].t));
    const d = Math.min(...origins.map(o => Math.abs(SYS[sy].t - o)));
    if (d > r) return `${SYS[sy].n} is ${d} away; your crew range is ${r}`;
  }
  return null;
}
// legal moves: [{dest, label, eta, lv, rate, note}]
function moves(G, s) {
  if (G.phase !== 'move' || G.over) return [];
  const out = [], p = P(s.loc);
  if (p.t === 'box' || G.turn.moved[s.id]) return [];
  const here = sysOf(s.loc);
  const add = (dest, extra) => out.push({ dest, label: locName(dest), rate: engRate(G, s), ...extra });
  // ---------- robotic explorers ----------
  if (s.cls === 'RE') {
    if (s.fixed) return [];
    const lvs = lvStockAt(G, s.loc);
    if (!s.launched) {
      if (!lvs.length && !(s.loc === 'earth')) return [];
      const lvOpts = launchLVs(G, s.loc, 1);
      if (!lvOpts.length) return [];
      if (s.kind === 'Telescope') { lvOpts.slice(0, 1).forEach(lv => add('orbit:ear', { lv })); return out; }
      D.SYS_ORDER.forEach(sy => {
        if (sy === 'alp' || sy === 'sca' && s.kind !== 'Flyby' && false) return;
        if (sy === here) {
          worldsIn(sy).forEach(w => {
            if (W[w].tags.includes('tele') || W[w].tags.includes('earth') || w === 'ear') return;
            if (s.kind === 'Orbiter') add('orbit:' + w, { lv: lvOpts[0] });
            if (s.kind === 'Rover' && !isGas(w) && !isSun(w)) add('surf:' + w, { lv: lvOpts[0] });
          });
          if (s.kind === 'Flyby') add('fly:' + sy, { lv: lvOpts[0] });
          return;
        }
        lvOpts.forEach(lv => {
          const t = Math.max(1, transfer(G, here, sy) - (lv.n - 1));
          add(boxFor(sy, t), { lv, eta: t, hold: Math.max(0, t - 6) });
        });
      });
      return out;
    }
    if (p.t === 'fly' && (s.kind === 'Orbiter' || s.kind === 'Rover')) {
      worldsIn(p.s).forEach(w => {
        if (W[w].tags.includes('tele')) return;
        if (s.kind === 'Orbiter') add('orbit:' + w, { final: true });
        if (s.kind === 'Rover' && !isGas(w) && !isSun(w)) add('surf:' + w, { final: true });
      });
    }
    return out;
  }
  // ---------- crew vehicles ----------
  if (s.loc === 'earth') {
    const lvOpts = launchLVs(G, 'earth', s.sz);
    if (!lvOpts.length) return [];
    // leaving Earth: carried by LV to Earth orbit (and on, as one move)
    const tgt = cvTargets(G, s, 'ear');
    tgt.forEach(t => add(t.dest, { lv: lvOpts[0], eta: t.eta, hold: t.hold, why: t.why }));
    return out.filter(o => !o.why);
  }
  cvTargets(G, s, here).forEach(t => { if (t.dest !== s.loc) add(t.dest, { eta: t.eta, hold: t.hold, why: t.why }); });
  return out.filter(o => !o.why);
}
const boxFor = (sy, t) => `box:${sy}:${Math.min(6, t)}`;
function cvTargets(G, s, here) {
  const out = [];
  const push = (dest, extra) => { const why = cvAllowed(G, s, dest); out.push({ dest, why, ...extra }); };
  worldsIn(here).forEach(w => {
    if (W[w].tags.includes('tele') || isSun(w)) return;
    push('orbit:' + w);
    if (!W[w].tags.includes('station')) push('surf:' + w);
  });
  if (here === 'ear') push('earth');
  push('fly:' + here);
  D.SYS_ORDER.forEach(sy => { if (sy === here) return; const t = transfer(G, here, sy); push(boxFor(sy, t), { eta: t, hold: Math.max(0, t - 6) }); });
  return out;
}
function lvStockAt(G, loc) {
  if (loc === 'earth') return Object.entries(G.lv.earth).filter(([, n]) => n > 0).map(([z]) => +z);
  const b = G.bases.find(x => baseLoc(x) === loc); if (!b || !G.lv[b.id]) return [];
  return Object.entries(G.lv[b.id]).filter(([, n]) => n > 0).map(([z]) => +z);
}
// LV choices for a launch needing at least size n: stocked ones, or buy one on Earth if a counter is free
function launchLVs(G, loc, n) {
  const stock = lvStockAt(G, loc).filter(z => z >= n).map(z => ({ n: z, stock: true }));
  const out = [...stock];
  if (loc === 'earth') {
    [1, 2, 3, 4].filter(z => z >= n && lvTechOk(G, z) && lvCanAdd(G, z) && !stock.some(x => x.n === z)).forEach(z => out.push({ n: z, buy: true, cost: { ORE: 1, FUEL: z }, cash: earthCash(G, { ORE: 1, FUEL: z }), txt: earthCostTxt(G, { ORE: 1, FUEL: z }) }));
  }
  out.sort((a, b) => (a.stock ? 0 : 1) - (b.stock ? 0 : 1) || a.n - b.n);
  return out;
}
function engineRoll(G, rate) {
  if (rate < 1) return { r: null, fail: false };
  let r = d100(), fail = r <= rate;
  if (fail && G.rr > 0) { G.rr--; log(G, `Engine roll ${r} fails; improved engine reliability reroll used (${G.rr} left).`); r = d100(); fail = r <= rate; }
  return { r, fail };
}
// carry: probe name to load at launch
function move(G, s, dest, opt) {
  opt = opt || {};
  const m = moves(G, s).filter(x => x.dest === dest);
  if (!m.length) return `${s.name} cannot move to ${locName(dest)} now.`;
  const mv = (opt.lvSize ? m.find(x => x.lv && x.lv.n === opt.lvSize) : null) || m[0];
  // pay for LV if buying
  let lvPaid = null;
  if (mv.lv && mv.lv.buy) { if (G.cash < earthCash(G, mv.lv.cost)) return `A new LV-${mv.lv.n} costs ${earthCostTxt(G, mv.lv.cost)}.`; lvPaid = payEarth(G, mv.lv.cost); }
  else if (mv.lv) { const st = s.loc === 'earth' ? G.lv.earth : G.lv[G.bases.find(b => baseLoc(b) === s.loc).id]; st[mv.lv.n]--; }
  // probe
  if (opt.probe && !s.launched && s.cls === 'RE' && ['Flyby', 'Orbiter', 'Rover'].includes(s.kind)) {
    const pool = G.probes[s.loc] || [];
    if (pool.includes(opt.probe)) { G.probes[s.loc] = pool.filter(x => x !== opt.probe); s.probe = opt.probe; }
  }
  const from = s.loc, fromName = locName(from);
  // pirates intercept CVs leaving a flyby box (unless armed)
  const pf = P(from);
  const leavingFly = s.cls === 'CV' && (pf.t === 'fly' || (sysOf(from) !== sysOf(dest)));
  const pirSys = pf.t === 'fly' ? pf.s : sysOf(from);
  if (leavingFly && G.fly[pirSys].pir.length && !(s.cb - s.dmg > 0) && !opt.pirateDone) {
    G.ask.push({ k: 'pirate', ship: s.id, dest, opt: { ...opt, pirateDone: true }, sys: pirSys, roll: d10(), text: `A pirate in the ${SYS[pirSys].n} flyby box intercepts ${s.name}.` });
    if (lvPaid) unpayEarth(G, lvPaid); else if (mv.lv) { const st = s.loc === 'earth' ? G.lv.earth : G.lv[G.bases.find(b => baseLoc(b) === s.loc).id]; st[mv.lv.n]++; }
    return null;
  }
  const rate = engRate(G, s);
  const { r, fail } = engineRoll(G, rate);
  const rtxt = r === null ? 'no engine roll needed' : `engine roll ${r} vs ${rate}%`;
  if (fail) {
    if (s.cls === 'CV') loseCV(G, s, `to an engine failure leaving ${fromName} (${rtxt})`);
    else loseRE(G, s, `is lost to an engine failure (${rtxt})`);
    if (mv.lv) log(G, `LV-${mv.lv.n} is destroyed with it.`);
    return null;
  }
  // LV recovery
  if (mv.lv) {
    const keep = has(G, 'reuse') && (r === null ? d100() : r) > 25;
    if (keep) { const key = from === 'earth' ? 'earth' : G.bases.find(b => baseLoc(b) === from).id; lvRecover(G, key, mv.lv.n); log(G, `LV-${mv.lv.n} is recovered and returns to ${from === 'earth' ? 'Earth' : 'its base'}; it can launch again next turn.`); }
    else log(G, `LV-${mv.lv.n} is expended${has(G, 'reuse') ? ' (roll 25 or lower)' : ''}.`);
  }
  s.loc = dest; s.hold = mv.hold || 0; s.launched = true;
  if (mv.final || (s.cls === 'RE' && (s.kind === 'Orbiter' || s.kind === 'Rover') && (P(dest).t === 'orbit' || P(dest).t === 'surf'))) s.fixed = true;
  G.turn.moved[s.id] = (G.turn.moved[s.id] || 0) + 1;
  log(G, `${s.name} moves from ${fromName} to ${locName(dest)}${mv.eta ? ` (${mv.eta} turn transfer${s.hold ? ', ' + s.hold + ' turn(s) beyond box 6' : ''})` : ''}, ${rtxt}.`);
  return null;
}
// LV cargo run from Earth to a base: buy resources at $1B each
function shipCargo(G, baseId, load, lvSize) {
  if (G.phase !== 'move') return 'Cargo flights happen in the movement phase.';
  const b = G.bases.find(x => x.id === baseId); if (!b) return 'Unknown base.';
  const opts = launchLVs(G, 'earth', 1).filter(o => !lvSize || o.n === lvSize);
  if (!opts.length) return 'No launch vehicle available on Earth.';
  const lv = opts[0];
  const cap = (lv.n + (G.f === 'sa' ? 1 : 0)) * cargoMul(G);
  const n = sum(load); if (n > cap) return `LV-${lv.n} carries ${cap} resources.`;
  const cost = { ...load }; if (lv.buy) { cost.ORE = (cost.ORE || 0) + 1; cost.FUEL = (cost.FUEL || 0) + lv.n; }
  if (G.cash < earthCash(G, cost)) return `This flight costs ${earthCostTxt(G, cost)}.`;
  if (G.fly[W[b.w].sys].pir.length) log(G, `Note: a pirate waits in the ${SYS[W[b.w].sys].n} flyby box.`);
  payEarth(G, cost); if (lv.stock) G.lv.earth[lv.n]--;
  const { r, fail } = engineRoll(G, engBase(G));
  if (fail) { const v = drawMarker(G, 'Eng'); log(G, `The LV-${lv.n} cargo flight to ${b.name} fails (engine roll ${r}); cargo lost. Lessons learned: ${v} Engineering.`, 'x'); return null; }
  addRes(b.stock, load);
  if (has(G, 'reuse') && r > 25) { lvRecover(G, 'earth', lv.n); log(G, `LV-${lv.n} is recovered; it can launch again next turn.`); }
  log(G, `LV-${lv.n} delivers ${resTxt(load)} to ${b.name} (engine roll ${r}).`, 'g');
  return null;
}
function answer(G, choice, data) {
  const a = G.ask[0]; if (!a) return null;
  if (a.k === 'pirate') {
    const s = G.ships.find(x => x.id === a.ship); G.ask.shift();
    if (!s) return null;
    if (choice === 'pay') { G.cash -= a.roll; G.cache += a.roll; if (G.cash < 0) { G.debt += -G.cash; G.cash = 0; } log(G, `Paid the pirates $${a.roll}B; ${s.name} passes.`); return move(G, s, a.dest, a.opt); }
    if (choice === 'remove') { const c = a.roll * 2; G.cash -= c; G.cache += c; if (G.cash < 0) { G.debt += -G.cash; G.cash = 0; } G.fly[a.sys].pir.shift(); log(G, `Paid $${c}B to drive the pirate off; ${s.name} passes.`); return move(G, s, a.dest, a.opt); }
    if (choice === 'surrender') { s.cargo = { ORE: 0, SUP: 0, FUEL: 0 }; s.res = true; if (G.polm) G.polm--; log(G, `${s.name} surrenders to the pirates: cargo lost, crew vehicle reserved, 1 politics marker taken.`, 'x'); return null; }
    if (choice === 'fight') { pirateBattle(G, [s], a.sys, false); if (G.ships.includes(s) && !G.fly[a.sys].pir.length) return move(G, s, a.dest, a.opt); return null; }
    if (choice === 'stay') { log(G, `${s.name} stays put.`); return null; }
  }
  if (a.k === 'publicity') { const w = G.w[choice]; if (!w || w.v < 1) return 'Pick a world that is not fully depleted.'; w.v += 2; G.ask.shift(); log(G, `Publicity Campaign: ${W[choice].n} rises to ${w.v}.`, 'g'); return null; }
  if (a.k === 'immigration') { const b = G.bases.find(x => x.id === choice); if (!b) return 'Pick one of your bases.'; b.set += 2; G.ask.shift(); log(G, `Immigration: ${b.name} gains 2 settlements.`, 'g'); return null; }
  if (a.k === 'card') {
    G.ask.shift();
    if (choice) { G.w[a.w].card = choice; log(G, `World card ${choice} placed on ${W[a.w].n}.`, 'g'); } else log(G, `World card returned to the deck; ${W[a.w].n} keeps ${G.w[a.w].card || 'no card'}.`);
    if (a.life) { const L = lifeSearch(G, a.w, a.life.base); log(G, `${W[a.w].n}:${L.msg || ' no search for life (' + L.info.skip + ').'}`, L.info.found ? 'g' : undefined); G.lastRoll = { kind: 'life', title: `Search for life on ${W[a.w].n}`, life: L.info, extra: [] }; }
    return null;
  }
  if (a.k === 'flyby') {
    const s = G.ships.find(x => x.id === a.ship); G.ask.shift(); if (!s) return null;
    return flybyTransfer(G, s, choice);
  }
  return null;
}

// ================= COMBAT (pirates, NPF raids & blockades) =================
function startCombat(G) {
  // blockades lapse unless a CV with combat value stays at an NPF base world with embargo or worse
  Object.keys(G.w).forEach(k => { const x = G.w[k]; if (!x.npf) return; const still = x.blk && G.ships.some(s => s.cls === 'CV' && !s.res && worldOf(s.loc) === k && s.cb > s.dmg) && G.rel[x.npf] >= 4; if (x.blk && !still) { x.blk = false; } });
}
function endCombat(G) {}
function armed(s) { return s.cls === 'CV' && !s.res && s.cb - s.dmg > 0; }
function combatOptions(G) {
  const out = [];
  D.SYS_ORDER.forEach(sy => {
    const here = G.ships.filter(s => s.loc === 'fly:' + sy && armed(s));
    if (here.length && G.fly[sy].pir.length) out.push({ k: 'pirate', sys: sy, label: `Attack the pirate in the ${SYS[sy].n} flyby box` });
  });
  Object.keys(G.w).forEach(k => {
    const x = G.w[k]; if (!x.npf) return;
    const here = G.ships.filter(s => worldOf(s.loc) === k && P(s.loc).t !== 'box' && P(s.loc).t !== 'fly' && armed(s));
    if (!here.length) return;
    if (G.rel[x.npf] >= 4 && !x.blk) out.push({ k: 'blockade', w: k, label: `Blockade the ${D.FAC[x.npf].n} base at ${W[k].n}` });
    if (G.rel[x.npf] >= 5) out.push({ k: 'raid', w: k, label: `Raid the ${D.FAC[x.npf].n} base at ${W[k].n}` });
  });
  return out;
}
function combatAct(G, o) {
  if (G.phase !== 'combat') return 'Combat happens in the combat phase.';
  if (G.turn.acted['c:' + (o.sys || o.w)]) return 'Each fleet may search once per turn.';
  G.turn.acted['c:' + (o.sys || o.w)] = 1;
  if (o.k === 'pirate') { pirateBattle(G, G.ships.filter(s => s.loc === 'fly:' + o.sys && armed(s)), o.sys, true); return null; }
  const x = G.w[o.w];
  if (o.k === 'blockade') { x.blk = true; x.npfTrade = null; log(G, `You blockade the ${D.FAC[x.npf].n} base at ${W[o.w].n}: +$2B each production step while it lasts.`, 'g'); return null; }
  if (o.k === 'raid') {
    const fleet = G.ships.filter(s => worldOf(s.loc) === o.w && P(s.loc).t !== 'fly' && armed(s));
    const r = d10(), [cap, dmg] = D.RAID[r];
    let lostCV = false;
    for (let i = 0; i < dmg; i++) { const s = fleet.filter(z => G.ships.includes(z)).sort((a, b) => (b.sz - b.dmg) - (a.sz - a.dmg))[0]; if (!s) break; s.dmg++; recallCheck(G, s); if (s.dmg >= s.sz) { loseCV(G, s, 'in the raid'); lostCV = true; } }
    let room = fleet.filter(z => G.ships.includes(z)).reduce((a, z) => a + z.cap * cargoMul(G) - sum(z.cargo), 0), got = Math.min(cap, room);
    const holder = fleet.filter(z => G.ships.includes(z) && z.cap);
    for (let i = 0; i < got; i++) { const h = holder.find(z => z.cap * cargoMul(G) > sum(z.cargo)); if (!h) break; h.cargo[pick(RES)]++; }
    if (r === 10) { G.w[o.w].npf = null; G.w[o.w].npfTrade = null; log(G, `Raid roll 10: the ${W[o.w].n} NPF base is destroyed.`, 'x'); }
    else log(G, `Raid roll ${r}: captured ${got} resources, took ${dmg} damage.`, 'g');
    if (!lostCV) { G.vm++; log(G, 'No crew vehicle lost in the raid: +1 victory marker.', 'g'); }
    return null;
  }
}
function recallCheck(G, s) { if (s.res) return; if (d100() <= recall(G)) { s.res = true; const b = drawMarker(G, 'Bio'); log(G, `${s.name} is recalled and goes into reserve (+${b} Biology).`); } }
function pirateBattle(G, fleet, sy, playerSearched) {
  const pir = G.fly[sy].pir.slice().sort((a, b) => (b.strong ? 1 : 0) - (a.strong ? 1 : 0))[0];
  if (!pir || !fleet.length) return;
  const pd = pir.strong ? D.PIRATE.strong : D.PIRATE.weak;
  const ncv = fleet.length, mine = d10(), theirs = d10();
  const bonus = ncv - 1;
  if (!(mine - bonus <= 4 || theirs - bonus <= 4)) { log(G, `Search for the pirate fails (rolls ${mine} and ${theirs}).`); return; }
  // tactics points: each side earns the other's roll, +1 per full 7 enemy CV size
  let myTP = theirs + Math.floor(pd.size / 7) + (has(G, 'cc') ? 2 : has(G, 'amsl') ? 1 : 0) + (polLv(G, 'mil') >= 3 ? 2 : 0);
  let pTP = mine + Math.floor(fleet.reduce((a, s) => a + s.sz, 0) / 7);
  const armedFleet = fleet.some(armed);
  if (pTP - myTP >= 3 && armedFleet) { log(G, `The pirate uses its tactics advantage (${pTP} to ${myTP}) to avoid combat.`); return; }
  // direct fire
  const extra = Math.max(0, myTP - pTP);
  const myDmgUp = Math.floor(extra / 2);
  const myTotal = fleet.reduce((a, s) => a + Math.max(0, s.cb - s.dmg), 0) + weapons(G) + d10();
  const pTotal = Math.max(0, pd.cb - pir.dmg) + d10() + (fleet.length - 1);
  let myDmg = D.combatDamage(myTotal, false) + myDmgUp;
  let pDmg = D.combatDamage(pTotal, false);
  log(G, `Combat with the pirate (direct fire): you roll a total of ${myTotal} for ${myDmg} damage; the pirate rolls ${pTotal} for ${pDmg} damage.`, 'e');
  pir.dmg += myDmg;
  if (pir.dmg >= pd.size) {
    G.fly[sy].pir = G.fly[sy].pir.filter(x => x !== pir);
    const share = Math.round(G.cache / 2); G.cache -= share; G.cash += share; G.polm++; G.vm++;
    log(G, `Pirate destroyed! You collect $${share}B from the pirate cache, a politics marker and a victory marker.`, 'g');
  }
  for (let i = 0; i < pDmg; i++) {
    const s = fleet.filter(z => G.ships.includes(z)).sort((a, b) => (b.sz - b.dmg) - (a.sz - a.dmg))[0]; if (!s) break;
    s.dmg++; recallCheck(G, s);
    if (s.dmg >= s.sz) { removeShip(G, s); const n = s.sz >= 4 ? 2 : 1, got = []; for (let j = 0; j < n; j++) got.push(drawMarker(G, 'Eng')); log(G, `${s.name} is destroyed by the pirate. Lessons learned: ${markerTxt(got, 'Eng')}.`, 'x'); }
  }
}

// ================= EXPLORATION =================
function startExplore(G) { log(G, `${G.y}: exploration.`, 'h'); }
function endExplore(G) {
  // flybys sitting in a flyby box must make their outward transfer
  G.ships.filter(s => s.kind === 'Flyby' && P(s.loc).t === 'fly' && !G.turn.acted[s.id]).forEach(s => {
    const nxt = outward(G, P(s.loc).s)[0];
    flybyTransfer(G, s, nxt ? nxt.sys : null);
  });
}
const outward = (G, sy) => D.SYS_ORDER.filter(x => SYS[x].t > SYS[sy].t && x !== 'alp').map(x => ({ sys: x, eta: transfer(G, sy, x) }));
function flybyTransfer(G, s, sy) {
  if (!sy) { removeShip(G, s); log(G, `Flyby ${s.name} has no system farther out and leaves the solar system.`); return null; }
  const { r, fail } = engineRoll(G, engBase(G));
  if (fail) { loseRE(G, s, `is lost to an engine failure on its heliocentric transfer (engine roll ${r})`); return null; }
  const t = transfer(G, P(s.loc).s, sy);
  s.loc = boxFor(sy, t); s.hold = Math.max(0, t - 6);
  log(G, `Flyby ${s.name} makes a heliocentric transfer toward ${SYS[sy].n} (${t} turns, engine roll ${r}).`);
  return null;
}
// what can this ship explore now? [{w, kind:'explore'|'probe'|'produce'|'harvest', value, pen}]
function exploreOptions(G, s) {
  if (G.phase !== 'explore' || G.turn.acted[s.id] || G.over) return [];
  const p = P(s.loc), out = [];
  const add = (w, kind, pen, why) => { if (G.w[w].v < 1 && kind !== 'produce') return; out.push({ w, kind, pen: pen || 0, why, value: exploreValue(G, s, w, kind === 'probe', pen || 0) }); };
  if (s.cls === 'RE') {
    if (s.kind === 'Telescope') { if (s.loc === 'orbit:ear') Object.keys(W).forEach(w => { if (w !== 'alp' && w !== 'ear') add(w, 'explore'); }); return out.sort((a, b) => b.value - a.value); }
    if (s.kind === 'Flyby') {
      if (p.t === 'box' || p.t === 'fly') worldsIn(p.s).forEach(w => { if (!W[w].tags.includes('tele')) { add(w, 'explore', p.n); if (s.probe && p.t === 'fly') add(w, 'probe', 0); } });
      return out;
    }
    if (!s.fixed) return out;
    const w = worldOf(s.loc);
    add(w, 'explore'); if (s.probe) add(w, 'probe');
    if (s.kind === 'Orbiter' && SYS[W[w].sys].hub === w) worldsIn(W[w].sys).forEach(x => { if (x !== w && !W[x].tags.includes('tele')) add(x, 'explore', isSun(x) ? 0 : 1); });
    // rovers cannot explore the Sun, even from Mercury
    if (s.kind === 'Rover') return out.filter(o => !isSun(o.w));
    return out;
  }
  // CV
  if (s.res || p.t === 'box') return out;
  if (p.t === 'fly') { if (s.prod && has(G, 'mine') && G.fly[p.s].ast) out.push({ w: null, kind: 'harvest', value: 0 }); return out; }
  if (atOwnBase(G, s) && !has(G, 'elev')) return out;
  const w = worldOf(s.loc);
  // severe atmospheres (Venus, gas giants) need Pressure Shell for any crewed exploration or production; gas giants are never explored by crew
  const atmOk = !W[w].tags.includes('severeAtm') || has(G, 'psh');
  if (atmOk && !W[w].tags.includes('gas') && !W[w].tags.includes('tele') && s.ev - s.dmg > 0) add(w, 'explore');
  if (atmOk && s.prod && has(G, 'mine') && !G.bases.some(b => b.w === w)) RES.forEach(r => { const v = prodValue(G, w, r); if (v >= 1) out.push({ w, kind: 'produce', res: r, value: v }); });
  return out;
}
function cardFor(G, w) { const c = G.w[w].card; return c ? D.CARDS.find(x => x.n === c) : null; }
function cardBonus(G, s, w, probe) {
  const c = cardFor(G, w); if (!c) return 0;
  const b = c.bonus; let n = b.all || 0;
  if (probe) return n + (b.probe || 0);
  if (s.cls === 'CV') return n + (b.crew || 0);
  if (s.kind === 'Rover') n += b.rover || 0;
  if (s.kind === 'Orbiter') n += b.orbiter || 0;
  if (s.kind === 'Flyby') n += b.flyby || 0;
  if (s.spec) n += b.spec || 0;
  return n;
}
function exploreValue(G, s, w, probe, pen) {
  let wv = G.w[w].v;
  if (s.kind === 'Telescope') wv = Math.round(wv / 2 + 1e-9);
  const unit = probe ? 9 : s.cls === 'CV' ? s.ev - s.dmg : s.ev;
  const tech = s.cls === 'CV' && !probe ? crewBonus(G) : roboBonus(G);
  return wv + unit + tech + cardBonus(G, s, w, probe) - (pen || 0);
}
function malfRate(G, s) {
  let r = malfBase(G);
  const sy = sysOf(s.loc), w = worldOf(s.loc);
  if (!has(G, 'ars') && (sy === 'mer' || (w && W[w].tags.includes('rad')))) r += 10;
  if (s.kind === 'Rover' && w === 'ven' && !has(G, 'psh')) r += 20;
  return r;
}
function lifeSearch(G, w, base) {
  const ws = G.w[w], lc = base + (cardFor(G, w) ? cardFor(G, w).lifeB : 0), bonus = cardFor(G, w) && cardFor(G, w).lifeB ? ` (${base}% + ${cardFor(G, w).lifeB}% from ${ws.card})` : '';
  if (ws.life) return { info: { skip: 'existing life already found here' }, msg: '' };
  if (!lc) return { info: { skip: `${W[w].n} has no chance of life` }, msg: '' };
  if (ws.sol && !has(G, 'sol')) return { info: { skip: 'searching for existing life needs the Signs of Life technology' }, msg: '' };
  const lr = d100(), seek = ws.sol ? 'existing life' : 'signs of life', found = lr <= lc, info = { r: lr, need: lc, seek, found, bonus };
  let msg = ` Search for life: rolled ${lr} on d100, needed ${lc} or less${bonus}`;
  if (!found) return { info, msg: msg + `: no ${seek}.` };
  if (!ws.sol) { ws.sol = true; const b = [drawMarker(G, 'Bio'), drawMarker(G, 'Bio')]; G.vm++; G.polm++; info.reward = `${markerTxt(b, 'Bio')}, +1 victory marker, +1 politics marker`; if (!has(G, 'sol')) { G.tech.sol = 1; info.reward += '; you gain the Signs of Life technology'; } return { info, msg: msg + `: signs of life! ${info.reward}.` }; }
  ws.life = true; const b = []; for (let i = 0; i < 4; i++) b.push(drawMarker(G, 'Bio')); G.vm += 2; G.polm += 2; info.reward = `${markerTxt(b, 'Bio')}, +2 victory markers, +2 politics markers`; if (!has(G, 'exl')) { G.tech.exl = 1; info.reward += '; you gain the Existing Life technology'; }
  return { info, msg: msg + `: existing life! ${info.reward}.` };
}
function explore(G, s, opt) {
  const o = exploreOptions(G, s).find(x => x.w === opt.w && x.kind === opt.kind && (!opt.res || x.res === opt.res));
  if (!o) return `${s.name} cannot do that now.`;
  G.turn.acted[s.id] = 1;
  if (o.kind === 'produce') return produceCV(G, s, o.w, o.res);
  if (o.kind === 'harvest') return harvest(G, s);
  const w = o.w, ws = G.w[w], probe = o.kind === 'probe', cv = s.cls === 'CV' && !probe;
  const val = Math.max(0, o.value);
  let field = W[w].f, lifeChance = W[w].life;
  if (w === 'alp') { const r = d10(); const a = D.ALPHA.find(x => r <= x[0]); field = a[1]; lifeChance = a[2]; G.alpha[cv ? 'cv' : 're'] = true; }
  const auto = Math.floor(val / 10), rem = val % 10, r1 = d10();
  const two = (cv && s.lab) || (s.kind === 'Telescope' && G.f === 'eu');
  const r2 = two ? d10() : null, r = two ? Math.min(r1, r2) : r1;
  const hit = rem > 0 && r <= rem;
  let n = auto + (hit ? 1 : 0);
  const got = []; for (let i = 0; i < n; i++) got.push(drawMarker(G, field));
  const who = probe ? `Probe ${s.probe} (from ${s.name})` : s.name;
  const rollTxt = `rolled ${r}${two ? ` (best of ${r1} and ${r2})` : ''} on d10`;
  const need = rem ? `needs ${rem} or less` : 'no roll needed';
  let res;
  if (!n) res = `${rollTxt}, ${need}: failure.`;
  else if (!rem) res = `${auto} automatic marker(s): ${markerTxt(got, field)}.`;
  else res = `${auto ? auto + ' automatic marker(s), then ' : ''}${rollTxt}, ${need}: ${hit ? 'success' : 'no extra marker'}. Earned ${markerTxt(got, field)}.`;
  let msg = `${who} explores ${W[w].n}${o.pen ? ` from transfer box ${o.pen}` : ''} at value ${val}: ${res}`;
  G.lastRoll = { who, world: W[w].n, val, auto, rem, r, r1, r2, hit, got: got.slice(), field, ok: n > 0, extra: [] };
  const total = got.reduce((a, b) => a + b, 0);
  if (cv ? total >= 3 : got.some(v => v >= 3)) {
    ws.v = Math.max(0, ws.v - 1); G.polm++;
    msg += ` Depletion: ${W[w].n} drops to ${ws.v}; +1 politics marker.`; G.lastRoll.extra.push(`Depletion: ${W[w].n} drops to ${ws.v}.`);
    // missions (telescopes never count)
    if (s.kind !== 'Telescope') [['mine', 'your'], ['common', 'the common']].forEach(([slot, lbl]) => {
      const id = G.mis[slot]; if (id == null) return; const m = D.MIS[id];
      if (m.w !== w || (m.cv && !cv)) return;
      G.polm++; G.mis.done++;
      const cap = Math.max(1, Math.floor((G.y - 2020) / 10));
      if (G.mis.kept.length < cap) { G.mis.kept.push(id); msg += ` ${lbl === 'your' ? 'Your' : 'The common'} mission (${misTxt(id)}) is complete: +1 politics marker, mission kept.`; }
      else { G.vm++; const ret = G.mis.kept.shift(); G.mis.pool.push(ret); G.mis.kept.push(id); msg += ` Mission complete but you can keep only ${cap}: +1 politics marker and +1 victory marker; ${misTxt(ret)} returns to the pool.`; }
      G.mis[slot] = drawMission(G);
    });
    // world card
    if (W[w].base || W[w].tags.includes('gas')) {
      const draws = (s.spec && !probe && s.cls === 'RE') ? 2 : 1;
      const opts = []; for (let i = 0; i < draws; i++) { const c = pick(D.CARDS); if (D.cardOk(c, W[w]) && !opts.includes(c.n)) opts.push(c.n); }
      if (opts.length) G.ask.push({ k: 'card', w, opts, text: `Depletion at ${W[w].n}: you drew ${opts.join(' and ')}. Place a card on the world or return it to the deck.` });
      else if (!ws.card && ws.v === 0) { const ok = D.CARDS.filter(c => D.cardOk(c, W[w])); if (ok.length) { const c = pick(ok); ws.card = c.n; msg += ` Final depletion: ${c.n} is placed.`; } }
    }
    // search for life
    // search for life: if a world card is waiting to be placed, the roll waits for it (cards like Water Ice add to the chance)
    const cardAsk = G.ask.find(q => q.k === 'card' && q.w === w && !q.life);
    if (cardAsk) { cardAsk.life = { base: lifeChance }; G.lastRoll.life = { pending: true }; }
    else { const L = lifeSearch(G, w, lifeChance); G.lastRoll.life = L.info; msg += L.msg; }
    // missions on depleted worlds get replaced
    ['mine', 'common'].forEach(slot => { const id = G.mis[slot]; if (id != null && G.w[D.MIS[id].w].v < 1) { G.mis[slot] = drawMission(G); } });
  }
  log(G, msg, 'g');
  // after effects
  if (probe) { log(G, `Probe ${s.probe} is spent; ${s.name} does not search this turn.`); s.probe = null; if (s.kind === 'Flyby' && P(s.loc).t === 'fly') afterFlybyBox(G, s); return null; }
  if (cv) { const rc = d100(), rv = recall(G); if (rc <= rv) { s.res = true; const b = drawMarker(G, 'Bio'); log(G, `Recall roll ${rc} (recalled on ${rv} or less): ${s.name} is recalled and goes into reserve (+${b} Biology).`); G.lastRoll.extra.push(`Recall roll ${rc} of ${rv}%: recalled.`); } else { log(G, `Recall roll ${rc} (recalled on ${rv} or less): ${s.name} stays active.`); G.lastRoll.extra.push(`Recall roll ${rc} of ${rv}%: stays active.`); } return null; }
  const mr = d100(), mv = malfRate(G, s);
  if (mr <= mv) { G.lastRoll.extra.push(`Malfunction roll ${mr} of ${mv}%: lost.`); loseRE(G, s, `malfunctions and is lost (malfunction roll ${mr}, lost on ${mv} or less)`); return null; }
  log(G, `Malfunction roll ${mr} (lost on ${mv} or less): ${s.name} keeps working.`); G.lastRoll.extra.push(`Malfunction roll ${mr} of ${mv}%: keeps working.`);
  if (s.kind === 'Flyby' && P(s.loc).t === 'fly') afterFlybyBox(G, s);
  return null;
}
function afterFlybyBox(G, s) {
  const opts = outward(G, P(s.loc).s);
  if (!opts.length) { removeShip(G, s); log(G, `Flyby ${s.name} leaves the solar system.`); return; }
  G.ask.push({ k: 'flyby', ship: s.id, opts, text: `Flyby ${s.name} must now make a heliocentric transfer outward. Choose its next system.` });
}
function flybySkip(G, s) { if (s.kind !== 'Flyby' || P(s.loc).t !== 'fly' || G.turn.acted[s.id]) return 'Nothing to skip.'; G.turn.acted[s.id] = 1; afterFlybyBox(G, s); return null; }
function prodValue(G, w, r) { const c = cardFor(G, w); return (c ? c.prod[r] : 0) + (W[w].prod[r] || 0); }
function produceCV(G, s, w, r) {
  const v = prodValue(G, w, r);
  let n = 1 + Math.floor(v / 10) - (v >= 10 ? 0 : 0), roll = d10() - (has(G, 'ref') ? 1 : 0);
  if (roll <= v % 10 || (v >= 10 && roll <= v - 10)) n++;
  if (roll <= 1) n++;
  const room = s.cap * cargoMul(G) - sum(s.cargo);
  const got = Math.min(n, room);
  s.cargo[r] += got;
  log(G, `${s.name} produces ${got} ${r} at ${W[w].n}: rolled ${roll} on d10 against production value ${v}${got < n ? ' (cargo full)' : ''}.`, 'g');
  G.lastRoll = { kind: 'produce', title: `${s.name} produces ${r} at ${W[w].n}`, r: roll, good: n > 1, head: `${got} ${r} produced`, sub: `Rolled ${roll}${has(G, 'ref') ? ' (after Space Refining)' : ''} against production value ${v}${got < n ? '; cargo full' : ''}.`, extra: [] };
  recallLog(G, s);
  return null;
}
function recallLog(G, s) {
  const rc = d100(), rv = recall(G);
  if (rc <= rv) { s.res = true; const b = drawMarker(G, 'Bio'); log(G, `Recall roll ${rc} (recalled on ${rv} or less): ${s.name} is recalled and goes into reserve (+${b} Biology).`); G.lastRoll.extra.push(`Recall roll ${rc} of ${rv}%: recalled.`); }
  else { log(G, `Recall roll ${rc} (recalled on ${rv} or less): ${s.name} stays active.`); G.lastRoll.extra.push(`Recall roll ${rc} of ${rv}%: stays active.`); }
}
function harvest(G, s) {
  const sy = P(s.loc).s; const r = d10(); const [t, n] = D.HARVEST[r];
  const room = s.cap * cargoMul(G) - sum(s.cargo), got = Math.min(n, room);
  s.cargo[t] += got; G.fly[sy].ast--; G.vm++;
  log(G, `${s.name} harvests the asteroid: rolled ${r} on d10, ${got} ${t}${got < n ? ' (cargo full)' : ''}, +1 victory marker.`, 'g');
  G.lastRoll = { kind: 'harvest', title: `${s.name} harvests the asteroid`, r, good: true, head: `${got} ${t} and 1 victory marker`, sub: `Rolled ${r} on the asteroid harvest table${got < n ? '; cargo full' : ''}.`, extra: [] };
  recallLog(G, s);
  return null;
}

// ================= TRADE & BASES =================
function startTrade(G) { log(G, `${G.y}: trade and base construction.`, 'h'); }
function baseCost(G, w) { return Math.max(1, W[w].base - baseCostMod(G)); }
function canFoundBase(G, s) {
  if (G.phase !== 'trade') return null;
  if (s.cls !== 'CV' || s.res || s.ev <= 0) return null;
  const p = P(s.loc); if (!p.w) return null;
  const w = p.w;
  if (!W[w].base) return null;
  const station = W[w].tags.includes('station');
  if (station ? p.t !== 'orbit' : p.t !== 'surf') return null;
  if (G.bases.some(b => b.w === w)) return null;
  if (G.bases.length >= 6) return null;
  return { w, cost: baseCost(G, w) };
}
function foundBase(G, s) {
  const c = canFoundBase(G, s);
  if (!c) return `${s.name} cannot found a base here.`;
  if (s.cargo.SUP < c.cost) return `A base at ${W[c.w].n} costs ${c.cost} SUP from ${s.name}'s hold; it carries ${s.cargo.SUP}.`;
  const [, , lb] = lims(G); if (nBase(G) >= lb + 4) return 'You are already 4 bases over your support limit.';
  s.cargo.SUP -= c.cost;
  const used = new Set(G.bases.map(b => b.name)); const name = D.BASE_NAMES[G.f].find(n => !used.has(n));
  const b = { id: 'b' + G.nid++, name, w: c.w, stock: { ORE: 0, SUP: 0, FUEL: 0 }, fac: { lab: 0, mine: 0, sup: 0, def: 0 }, dmg: { lab: 0, mine: 0, sup: 0, def: 0 }, set: 0, setDmg: 0, trade: null, out: 'ORE', built: G.y, techField: 'Phy' };
  G.bases.push(b); b.out = bestOutput(G, b);
  log(G, `${s.name} founds base ${name} at ${W[c.w].n} for ${c.cost} SUP.`, 'g');
  return null;
}
function buyCargo(G, s, r, n) { // at Earth: buy resources straight into a ship's hold
  if (s.loc !== 'earth') return `${s.name} must be on Earth to take on cargo bought there.`;
  const room = s.cap * cargoMul(G) - sum(s.cargo); n = Math.min(n, room);
  if (n <= 0) return `${s.name} has no cargo room.`;
  if (G.cash < earthCash(G, { [r]: n })) return `${n} ${r} costs ${earthCostTxt(G, { [r]: n })}.`;
  const paid = payEarth(G, { [r]: n }); s.cargo[r] += n; log(G, `${s.name} loads ${n} ${r} on Earth (${paid.used[r] ? paid.used[r] + ' from the faction board' : ''}${paid.used[r] && paid.cash ? ', ' : ''}${paid.cash ? '$' + paid.cash + 'B bought' : ''}).`); return null;
}
function sellCargo(G, s) { // at Earth: nothing is sold; cargo goes onto the faction board for later building
  if (s.loc !== 'earth') return 'Ships unload onto the faction board on Earth.';
  const t = resTxt(s.cargo); addRes(estock(G), s.cargo); s.cargo = { ORE: 0, SUP: 0, FUEL: 0 };
  log(G, `${s.name} unloads ${t} onto the faction board.`); return null;
}
function unload(G, s, b) { if (!b || atOwnBase(G, s) !== b) return 'The ship must be at that base.'; addRes(b.stock, s.cargo); const t = resTxt(s.cargo); s.cargo = { ORE: 0, SUP: 0, FUEL: 0 }; log(G, `${s.name} unloads ${t} at ${b.name}.`); return null; }
function load(G, s, b, r, n) { if (!b || atOwnBase(G, s) !== b) return 'The ship must be at that base.'; const room = s.cap * cargoMul(G) - sum(s.cargo); n = Math.min(n, room, b.stock[r]); if (n <= 0) return 'Nothing to load.'; b.stock[r] -= n; s.cargo[r] += n; log(G, `${s.name} loads ${n} ${r} at ${b.name}.`); return null; }
function upgradeOptions(G, b) {
  return Object.keys(D.FACIL).map(c => {
    const lv = b.fac[c], next = D.FACIL[c][lv];
    let why = null;
    if (!next) why = 'fully built';
    else if (b.dmg[c]) why = 'repair it first';
    else if (c === 'mine' && b.w === 'ear') why = 'Earth orbit cannot produce resources';
    return { c, lv, next, why };
  });
}
function buildFacility(G, b, c) {
  if (G.phase !== 'trade') return 'Facilities are built in the trade & base phase.';
  if (G.turn.built[b.id]) return `${b.name} already built something this turn.`;
  const o = upgradeOptions(G, b).find(x => x.c === c);
  if (!o || o.why) return o ? o.why : 'Unknown facility.';
  if (!enough(b.stock, o.next.c)) return `${o.next.n} costs ${resTxt(o.next.c)}; ${b.name} has ${resTxt(b.stock)}.`;
  addRes(b.stock, o.next.c, -1); b.fac[c]++; G.turn.built[b.id] = 1;
  if (c === 'mine' || c === 'lab') b.out = bestOutput(G, b);
  log(G, `${b.name} builds a ${o.next.n}.`, 'g');
  return null;
}
function buildSettlement(G, b) {
  if (G.phase !== 'trade') return 'Settlements are built in the trade & base phase.';
  if (G.turn.built[b.id]) return `${b.name} already built something this turn.`;
  if (!enough(b.stock, D.SETTLE_COST)) return `A settlement costs ${resTxt(D.SETTLE_COST)}.`;
  addRes(b.stock, D.SETTLE_COST, -1); b.set++; G.turn.built[b.id] = 1;
  log(G, `${b.name} adds a settlement (${b.set} total).`, 'g');
  return null;
}
function repairFacility(G, b, c) {
  if (!b.dmg[c]) return 'No damage to repair.';
  if (b.stock.ORE < 1) return 'Repairs cost 1 ORE per damage marker.';
  b.stock.ORE--; b.dmg[c]--; log(G, `${b.name} repairs its ${c} facility.`); return null;
}
function terraform(G, b) {
  if (G.phase !== 'trade') return 'Terraforming happens in the trade & base phase.';
  if (!has(G, 'terra')) return 'You need Terraforming.';
  if (!D.TERRA[b.w]) return `${W[b.w].n} cannot be terraformed.`;
  const n = G.turn.terraBuys[b.id] || 0, cost = (has(G, 'atm') ? 3 : 4) + n;
  if (b.stock.SUP < cost) return `The next terraforming point costs ${cost} SUP.`;
  b.stock.SUP -= cost; G.turn.terraBuys[b.id] = n + 1; G.w[b.w].terra++;
  log(G, `${b.name} buys a terraforming point for ${cost} SUP (${W[b.w].n}: ${G.w[b.w].terra}/${D.TERRA[b.w]}).`, 'g');
  return null;
}
// trade at own base (buy with cash / sell from stock) or at an NPF base (with a fleet there)
function tradeLimitOwn(b) { const r = setRow(b.set - (b.setDmg || 0)); return r ? r[1] : 0; }
function trade(G, where, qty) {
  if (G.phase !== 'trade') return 'Trading happens in the trade & base phase.';
  let tm, limit, stock, label;
  if (where.base) {
    const b = G.bases.find(x => x.id === where.base); tm = b.trade; limit = tradeLimitOwn(b); stock = b.stock; label = b.name;
    if (!tm) return `${b.name} has no trade marker.`;
    if (!limit) return `${b.name} needs settlements to trade.`;
    if (tm.side === 'buy') { const cost = Math.ceil(Math.min(qty, limit) / 2); if (G.cash < cost) return `Buying costs $${cost}B.`; G.cash -= cost; stock[tm.type] += Math.min(qty, limit); }
    else { const n = Math.min(qty, limit, stock[tm.type]); if (!n) return `No ${tm.type} to sell.`; stock[tm.type] -= n; G.cash += 2 * n; }
    log(G, `Traded at ${label}: ${tm.side === 'buy' ? 'bought' : 'sold'} ${tm.side === 'buy' ? Math.min(qty, limit) : Math.min(qty, limit)} ${tm.type}.`, 'g');
    b.trade = null; return null;
  }
  const w = where.w, x = G.w[w];
  if (!x.npf || !x.npfTrade) return 'That NPF base has no trade marker.';
  if (G.rel[x.npf] > 3) return `Relations with ${D.FAC[x.npf].n} are too poor to trade.`;
  const fleet = G.ships.filter(s => s.cls === 'CV' && worldOf(s.loc) === w && P(s.loc).t !== 'fly' && P(s.loc).t !== 'box');
  if (!fleet.length || fleet.some(s => s.res)) return 'You need an unreserved crew vehicle fleet at that base.';
  limit = fac(G).rel[G.rel[x.npf]] ? fac(G).rel[G.rel[x.npf]][1] : 0;
  if (!limit) return `${D.FAC[x.npf].n} will not trade with you at your current relations.`;
  tm = x.npfTrade;
  if (tm.side === 'buy') {
    const room = fleet.reduce((a, s) => a + s.cap * cargoMul(G) - sum(s.cargo), 0);
    const n = Math.min(qty, limit, room); if (!n) return 'No cargo room.';
    const cost = Math.ceil(n / 2); if (G.cash < cost) return `Buying costs $${cost}B.`;
    G.cash -= cost; let left = n; fleet.forEach(s => { const r = Math.min(left, s.cap * cargoMul(G) - sum(s.cargo)); s.cargo[tm.type] += r; left -= r; });
    log(G, `Bought ${n} ${tm.type} from the ${D.FAC[x.npf].n} base at ${W[w].n} for $${cost}B.`, 'g');
  } else {
    let have = fleet.reduce((a, s) => a + s.cargo[tm.type], 0), n = Math.min(qty, limit, have); if (!n) return `Your fleet carries no ${tm.type}.`;
    let left = n; fleet.forEach(s => { const r = Math.min(left, s.cargo[tm.type]); s.cargo[tm.type] -= r; left -= r; });
    G.cash += 2 * n; log(G, `Sold ${n} ${tm.type} to the ${D.FAC[x.npf].n} base at ${W[w].n} for $${2 * n}B.`, 'g');
  }
  x.npfTrade = null; return null;
}
// Earth market
function earthSell(G, r) { // sell 2 of a type for $1B from a base in Earth orbit with elevator, else nothing
  return 'Resources must be on Earth to sell.';
}

// ================= SCORING =================
function score(G) {
  const parts = [];
  const add = (k, v) => { if (v) parts.push([k, Math.round(v * 100) / 100]); };
  add('Victory markers', G.vm);
  const ic = ['ich', 'ice', 'ichull'].filter(k => has(G, k)).length; add('Interstellar colonizer techs', [0, 15, 30, 50][ic]);
  let terraMost = 0, setVP = 0;
  G.bases.forEach(b => {
    const full = D.TERRA[b.w] && G.w[b.w].terra >= D.TERRA[b.w], half = D.TERRA[b.w] && G.w[b.w].terra * 2 >= D.TERRA[b.w];
    const per = (D.SET_VP[b.w] || D.SET_VP[W[b.w].sys] || 2) + (full ? .5 : half ? .25 : 0);
    setVP += b.set * per;
    if (b.set && (full || half)) terraMost += full ? 25 : 10;
  });
  add('Settlements', setVP); add('Most settlements on terraformed worlds', terraMost);
  add('Missions', G.mis.kept.reduce((a, id) => a + D.MIS[id].vp, 0));
  add('Alpha Centauri', G.alpha.cv && G.alpha.re ? 20 : G.alpha.cv ? 15 : G.alpha.re ? 5 : 0);
  add('Infrastructure', G.bases.reduce((a, b) => a + b.fac.lab + b.fac.mine + b.fac.sup + b.fac.def, 0));
  add('Undeveloped technologies', -3 * D.TECH.filter(t => !G.tech[t.k]).length);
  add('Unspent tech points', Math.floor(FIELDS.reduce((a, f) => a + G.bank[f], 0) / 20));
  add('Unspent politics markers', Math.floor(G.polm / 5));
  add('Space fleet', G.ships.reduce((a, s) => a + (s.cls === 'CV' ? s.sz * .5 : .5), 0));
  const penalty = G.y > 2145 ? -3 * (G.y - 2145) : 0; add('Solo penalty (past 2145)', penalty);
  const total = Math.round(parts.reduce((a, p) => a + p[1], 0) * 100) / 100;
  const rating = D.RATING.find(r => total <= r[0])[1];
  return { parts, total, rating };
}
function finish(G, why) { G.over = true; G.endYear = G.y; const sc = score(G); log(G, `${why} Final score ${sc.total}: ${sc.rating}.`, 'h'); }

return {
  R, D, P, sysOf, worldOf, locName, worldsIn, RES, FIELDS, FN, PHASES, ESTEPS, PHASE_NAME, ESTEP_NAME, newGame, cvAllowed, advance, answer,
  moves, move, buildOptions, buildUnit, buildLV, unreserve, repair, setReserve, scrap, scrapSite, scrapLV, estock, earthCash, earthCostTxt, lvCanAdd, lvPoolTxt, scrapRule, shipCargo,
  exploreOptions, explore, flybySkip, outward, combatOptions, combatAct,
  canFoundBase, foundBase, unload, load, buyCargo, sellCargo, upgradeOptions, buildFacility, buildSettlement, repairFacility, terraform, trade, tradeLimitOwn,
  setDiplomacy, dipCost, develop, techState, techCost, techCostTxt, techHolders, convertPolitics, buyVictory, redrawMission, tradePoints, choosePolicy, transferRes, baseOutput, bestOutput,
  lvRecover, lvReturn, score, lims, nonProbeRE, nCV, nBase, range, recall, malfBase, malfRate, engRate, engBase, mult, transfer, misTxt, lvCount, lvStockAt, launchLVs, atOwnBase, baseLoc, cardFor, prodValue, has, polLv, setRow, cargoMul, resTxt, sum,
};
}
if (typeof module !== 'undefined') module.exports = make; else root.SHE = make;
})(this);
