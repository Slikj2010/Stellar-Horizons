// Stellar Horizons — bot factions and the multi-faction turn coordinator.
// Browser: window.SHAI = makeAI(E, D). Node: require('./ai.js')(E, D).
// Each bot plays every phase with simple heuristics shaped by its faction: what it explores (field weights), what it
// builds (robotic vs crewed, telescopes, armed ships), what it researches (priority chains), policies, diplomacy, bases.
(function (root) {
'use strict';
function makeAI(E, D) {
  const W = D.W, SYS = D.SYS;
  // ---------------- faction personalities ----------------
  // fw: exploration field weights; re/cv: appetite for robotic explorers / crew vehicles; kinds: robotic explorer mix;
  // lab: bases run research labs (true) or mines (false); bases: base-building drive; tech: research priorities (in order);
  // pol: policy preferences; dip: improve relations with NPFs to trade; bully: worsen relations (embargo); trade: use markers
  const P = {
    na: { fw: { Eng: 1.35, Bio: 1.35, Phy: 1 }, re: 1.2, cv: 1, kinds: { Orbiter: 1.2, Rover: 1.1, Flyby: .8, Telescope: .6 }, lab: true, bases: .7, init: 0,
      tech: ['icd', 'acd', 'qc', 'aqc', 'ai', 'ars', 'pm', 'ff', 'fr', 'cp', 'als', 'aec', 'ag', 'hab', 'mine', 'lcv', 'frig', 'ops', 'tr', 'ldsf', 'psh'], pol: ['rob', 'eco', 'hum', 'set', 'dip'], dip: .2, trade: .3 },
    ru: { fw: { Bio: 1.6, Eng: 1, Phy: .8 }, re: .5, cv: 1.6, kinds: { Orbiter: 1, Flyby: 1.1, Rover: .7, Telescope: .3 }, lab: true, bases: 1.1, init: 0, crewWorlds: ['mar', 'eur', 'tit'],
      tech: ['orb', 'hab', 'cp', 'als', 'aec', 'ccls', 'acv', 'ops', 'iops', 'aops', 'ism', 'ag', 'hab', 'mine', 'lcv', 'frig', 'ldsf', 'psh', 'ars', 'ish'], pol: ['hum', 'set', 'eco', 'dip'], dip: .2, trade: .3 },
    eu: { fw: { Phy: 1.55, Eng: 1.1, Bio: .9 }, re: 1.5, cv: .8, kinds: { Telescope: 1.8, Orbiter: 1.2, Flyby: 1, Rover: .8 }, lab: true, bases: .6, init: 0, teles: 2,
      tech: ['icd', 'acd', 'qc', 'aqc', 'ai', 'pm', 'ff', 'fr', 'ars', 'tr', 'itr', 'cp', 'als', 'nano', 'mec', 'atr'], pol: ['rob', 'dip', 'eco', 'hum'], dip: .6, trade: .6 },
    jp: { fw: { Eng: 1.65, Phy: 1, Bio: .8 }, re: 1.7, cv: .4, kinds: { Orbiter: 1.3, Flyby: 1.1, Rover: 1, Telescope: .8 }, lab: true, bases: .4, init: 0,
      tech: ['icd', 'acd', 'qc', 'aqc', 'nano', 'ai', 'pm', 'ff', 'fr', 'pam', 'ars', 'tr'], pol: ['rob', 'eco', 'dip'], dip: .2, trade: .3 },
    cn_mil: { fw: { Eng: 1.3, Phy: 1.1, Bio: 1 }, re: 1, cv: 1.2, kinds: { Orbiter: 1, Rover: 1, Flyby: .9, Telescope: .5 }, lab: false, bases: .8, init: 2, armed: true, bully: true,
      tech: ['msl', 'amsl', 'isw', 'asw', 'fd', 'cc', 'lcv', 'frig', 'dest', 'icd', 'acd', 'cp', 'hab', 'mine', 'ars', 'pm', 'ff', 'bd'], pol: ['mil', 'hum', 'eco', 'set'], dip: 0, trade: .2 },
    cn_rob: { fw: { Eng: 1.4, Bio: 1.2, Phy: 1 }, re: 1.2, cv: 1.1, kinds: { Orbiter: 1.1, Rover: 1.1, Flyby: .9, Telescope: .6 }, lab: false, bases: .9, init: 0,
      tech: ['icd', 'acd', 'hab', 'lcv', 'frig', 'cp', 'als', 'mine', 'ish', 'qc', 'aqc', 'ops', 'iops', 'pm', 'ff', 'ars', 'tr'], pol: ['rob', 'hum', 'set', 'eco'], dip: .2, trade: .3 },
    as: { fw: { Bio: 1.45, Eng: 1.1, Phy: .8 }, re: .7, cv: 1.5, kinds: { Orbiter: 1, Rover: 1, Flyby: .8, Telescope: .3 }, lab: false, bases: 1.6, init: 0,
      tech: ['orb', 'lcv', 'hab', 'mine', 'astro', 'frig', 'ish', 'ref', 'ash', 'ag', 'ops', 'iops', 'cp', 'als', 'lcv', 'frig', 'tr', 'itr', 'psh', 'ars'], pol: ['set', 'hum', 'eco'], dip: .2, trade: .5 },
    sa: { fw: { Bio: 1.15, Eng: 1.15, Phy: 1.15 }, re: 1.1, cv: 1.1, kinds: { Orbiter: 1.1, Rover: 1.1, Flyby: 1, Telescope: .5 }, lab: false, bases: 1.4, init: 0,
      tech: ['orb', 'lcv', 'hab', 'mine', 'astro', 'cp', 'icd', 'acd', 'ish', 'tr', 'itr', 'atr', 'als', 'pm', 'ff', 'ars', 'qc'], pol: ['dip', 'set', 'eco', 'hum'], dip: 1, trade: 1 },
  };
  const prof = G => P[G.f === 'cn' ? 'cn_' + (G.variant || 'mil') : G.f];
  const fieldOf = w => W[w].f || 'Phy';
  const fw = (G, w) => (prof(G).fw[fieldOf(w)] || 1) * ((prof(G).crewWorlds || []).includes(w) ? 1.25 : 1);
  const pick = a => a[Math.floor(E.R.rnd() * a.length)];
  const wv = (G, w) => G.w[w] ? G.w[w].v : 0;
  const isGas = w => W[w].tags.includes('gas'), tele = w => W[w].tags.includes('tele'), sun = w => W[w].tags.includes('sunobs');
  // how many of my ships already go for / sit at a system (spread the fleet out)
  const crowd = (G, sy, kind) => G.ships.filter(s => s.kind === kind && E.sysOf(s.loc) === sy).length;

  // ---------------- bases: where may a bot build? ----------------
  // avoid worlds that already host a base (anyone's, NPFs included) unless this bot runs labs and the base there mines;
  // never a second base in Earth orbit
  function baseSpotOk(G, w) {
    if (!w || !W[w] || !W[w].base) return false;
    const there = E.allBases(G).filter(b => b.w === w), npf = G.w[w].npf;
    if (w === 'ear') return !there.length;
    if (!there.length && !npf) return true;
    if (there.some(b => b.f === G.f)) return false;
    return prof(G).lab && there.every(b => b.fac.mine && !b.fac.lab);
  }
  const wantBase = G => E.nBase(G) < E.lims(G)[2] + (prof(G).bases >= 1.4 ? 1 : 0);

  // ---------------- targets ----------------
  function worldScore(G, w, kind) {
    if (!G.w[w] || wv(G, w) < 1 || tele(w)) return 0;
    if (kind === 'Rover' && (isGas(w) || sun(w))) return 0;
    if (kind === 'CV' && (sun(w) || W[w].tags.includes('alpha'))) return 0;
    return wv(G, w) * fw(G, w);
  }
  function sysScore(G, sy, kind) {
    const ws = E.worldsIn(sy).map(w => worldScore(G, w, kind)).sort((a, b) => b - a);
    if (!ws.length) return 0;
    return kind === 'Flyby' ? ws[0] + .5 * (ws[1] || 0) + .25 * (ws[2] || 0) : ws[0];
  }
  const baseLocType = w => W[w].tags.includes('station') ? 'orbit' : 'surf';
  // a crew vehicle that can found a base there right away (exploration value, enough supplies on board)
  const canBaseAt = (G, s, dest, sup) => { const p = E.P(dest); return s.cls === 'CV' && s.ev > 0 && p.w && p.t === baseLocType(p.w) && baseSpotOk(G, p.w) && wantBase(G) && sup >= E.baseCost(G, p.w); };
  // a crew vehicle holding the supplies for a base it intends to found: it skips exploring and producing (both make
  // recall checks, and a recalled crew cannot found a base)
  // base spots this crew may reach and found with sup supplies: [{w, dest, cost}]
  function baseSpots(G, s, sup) {
    if (s.cls !== 'CV' || !(s.ev > 0) || !s.cap || !wantBase(G)) return [];
    return Object.keys(G.w).filter(w => baseSpotOk(G, w) && sup >= E.baseCost(G, w)).map(w => ({ w, dest: baseLocType(w) + ':' + w, cost: E.baseCost(G, w) })).filter(x => !E.cvAllowed(G, s, x.dest));
  }
  function planningBase(G, s) {
    if (s.cls !== 'CV' || s.res || !(s.ev > 0) || !s.cap || !wantBase(G) || !s.cargo.SUP) return false;
    const here = E.worldOf(s.loc);
    if (here && canBaseAt(G, s, s.loc, s.cargo.SUP)) return true;
    // or a spot it can reach (in this system, or any system its crew range allows) whose base cost it carries
    return baseSpots(G, s, s.cargo.SUP).length > 0;
  }
  function destScore(G, s, dest, eta, sup) {
    const p = E.P(dest), kind = s.cls === 'CV' ? 'CV' : s.kind;
    if (dest === 'orbit:ear' && kind === 'Telescope') return 50;
    let v;
    if (kind === 'CV' && p.t === 'fly') v = (G.fly[p.s].ast && s.prod && E.has(G, 'mine') && s.cap * E.cargoMul(G) > E.sum(s.cargo)) ? 4 : 0;   // nothing to research in a flyby box
    else if (kind === 'CV' && p.t === 'box' && p.s === E.sysOf(s.loc)) v = 0;
    else if (p.t === 'box' || p.t === 'fly') v = sysScore(G, p.s, kind) / (1 + .5 * crowd(G, p.s, kind));
    else if (p.w) v = worldScore(G, p.w, kind) / (1 + G.ships.filter(x => x !== s && x.kind === s.kind && E.worldOf(x.loc) === p.w).length);
    else v = 0;
    const su = sup == null ? s.cargo.SUP : sup;
    if (canBaseAt(G, s, dest, su)) v += 6 + 6 * prof(G).bases;
    else if (kind === 'CV' && p.t === 'box' && baseSpots(G, s, su).some(x => W[x.w].sys === p.s)) v += 4 + 4 * prof(G).bases;
    return v / (1 + .2 * (eta || 0));
  }
  const best = (arr, f) => { let b = null, bv = -Infinity; arr.forEach(x => { const v = f(x); if (v > bv) { bv = v; b = x; } }); return bv > 0 ? b : null; };

  // ---------------- asks ----------------
  function answerAsks(G) {
    let guard = 0;
    while (G.ask.length && guard++ < 30) {
      const a = G.ask[0];
      let r = null;
      if (a.k === 'pirate') { const s = G.ships.find(x => x.id === a.ship); r = E.answer(G, prof(G).armed && s && s.cb > s.dmg ? 'fight' : G.cash >= a.roll ? 'pay' : 'surrender'); }
      else if (a.k === 'card') r = E.answer(G, a.opts[0]);
      else if (a.k === 'flyby') { const o = best(a.opts, o => sysScore(G, o.sys, 'Flyby') / (1 + .2 * o.eta)) || a.opts[0]; r = E.answer(G, o.sys); }
      else if (a.k === 'publicity') { const w = best(Object.keys(G.w), w => G.ships.some(s => E.worldOf(s.loc) === w) ? worldScore(G, w, 'Orbiter') + 1 : 0) || Object.keys(G.w).find(k => G.w[k].v > 0); r = E.answer(G, w); }
      else if (a.k === 'mission') { const id = a.opts.slice().sort((x, y) => D.MIS[x].vp - D.MIS[y].vp)[0]; r = E.answer(G, id); }
      else if (a.k === 'immigration') r = E.answer(G, G.bases[0] && G.bases[0].id);
      else G.ask.shift();
      if (typeof r === 'string' && G.ask[0] === a) G.ask.shift();
    }
    if (G.ask.length) G.ask.length = 0;
  }

  // ---------------- phases ----------------
  function econ(G) {
    const pr = prof(G);
    if (G.estep === 'initiative') {
      // d10: 6+ spends politics markers on initiative; then a die the size of min(slot, markers held) says how many
      const slot = G.world ? G.world.meta.order.indexOf(G.f) + 1 : 1, cap = Math.min(slot, G.polm), dec = 1 + Math.floor(E.R.rnd() * 10);
      if (!cap) E.log(G, `Initiative: no politics markers to spend.`);
      else if (dec <= 5) { E.setInitBid(G, 0); E.log(G, `Initiative: rolls ${dec} on d10 (6+ to spend) and spends no politics markers.`); }
      else { const n = 1 + Math.floor(E.R.rnd() * cap); E.setInitBid(G, n); E.log(G, `Initiative: rolls ${dec} on d10 (6+ to spend), then ${n} on d${cap} (slot ${slot}, ${G.polm} markers held): spends ${n} politics marker${n > 1 ? 's' : ''}.`); }
    }
    if (G.estep === 'diplomacy') {
      // always try at least one attempt to improve relations, never spend more than 6 markers (attempts cost 1, 2, 3):
      // pick how many attempts at random within that budget, each with a random target that can still improve
      const budget = Math.min(6, G.polm), maxN = budget >= 6 ? 3 : budget >= 3 ? 2 : budget >= 1 ? 1 : 0;
      const targets = Object.keys(G.rel).filter(k => G.rel[k] > 0);
      if (!maxN) E.log(G, 'Diplomacy decision: no politics markers to spend.');
      else if (!targets.length) E.log(G, 'Diplomacy decision: relations with everyone are already at Alliance.');
      else {
        const n = 1 + Math.floor(E.R.rnd() * maxN), picks = [];
        for (let a = 0; a < n; a++) { const k = pick(targets); if (!E.setDiplomacy(G, k, 1)) picks.push(D.FAC[k].n); }
        E.log(G, `Diplomacy decision: ${picks.length} attempt${picks.length > 1 ? 's' : ''} to improve relations (${E.dipCost(G)} politics marker${E.dipCost(G) > 1 ? 's' : ''}): ${picks.join(', ')}.`);
      }
    }
    if (G.estep === 'production') G.bases.forEach(b => { b.out = E.bestOutput(G, b); });
    if (G.estep === 'transport' && G.transferLeft && G.bases.length && G.cash > 12) { const b = G.bases.find(x => x.w !== 'ear') || G.bases[0]; E.transferRes(G, 'earth', b.id, 'SUP', Math.min(G.transferLeft, 3)); }
    if (G.estep === 'tech' && !G.world) { for (let n = 0; n < 12; n++) if (!techPick(G) || techTurnBot(G) !== 'dev') break; }
    if (G.estep === 'policy') {
      for (let n = 0; n < 4 && !G.policyPicked; n++) { const k = pr.pol.find(k => E.polLv(G, k) < 3 && !E.choosePolicy(G, k)); if (!k) { const any = D.POL.find(p => !E.choosePolicy(G, p.k)); if (!any) break; } }
    }
  }
  // research: the best affordable technology by this bot's priorities, or null
  function techPick(G) {
    const pr = prof(G), open = D.TECH.filter(t => E.techState(G, t) === 'open' && G.bank[t.f] >= E.techCost(G, t));
    if (!open.length) return null;
    return best(open, t => { const i = pr.tech.indexOf(t.k); return (i >= 0 ? 100 - i * 3 : 20) - E.techCost(G, t) * .3 + (t.r.length ? 0 : 1); });
  }
  // one research turn: develop one technology, or pass (and turn leftover politics markers into points for its main field)
  function techTurnBot(G) {
    const t = techPick(G);
    if (t && !E.develop(G, t.k)) return 'dev';
    if (G.world) E.techPass(G);
    const main = Object.entries(prof(G).fw).sort((a, b) => b[1] - a[1])[0][0];
    while (G.polm > 0) E.convertPolitics(G, main);
    return 'pass';
  }
  // run research turns while it is a bot's turn (driveHuman: also play the human faction, e.g. in tests;
  // humanPasses: the human leaves the step, so finish every remaining turn)
  function techLoop(H, opt) {
    const world = H.world; if (!world) return;
    opt = opt || {};
    for (let n = 0; n < 500; n++) {
      const f = E.techTurn(world); if (!f) return;
      if (f === H.f && !opt.driveHuman) { if (opt.humanPasses) { E.techPass(H); continue; } return; }
      const g = world.facs[f]; answerAsks(g); techTurnBot(g);
    }
  }
  const techStep = H => H.world && H.phase === 'econ' && H.estep === 'tech';
  function build(G) {
    const pr = prof(G);
    G.ships.filter(s => s.res).forEach(s => E.unreserve(G, s));
    G.ships.filter(s => s.dmg).forEach(s => E.repair(G, s));
    // money is scarce (Earth pays out once a decade): keep enough for launches and unreserving
    const reserve = 10 + 2 * E.nBase(G);
    const [lre, lcv] = E.lims(G);
    const idle = G.ships.some(s => s.loc === 'earth' && !s.res && E.moves && s.cls === 'CV');
    for (let n = 0; n < 2; n++) {
      const opts = E.buildOptions(G, 'earth').filter(o => !o.why && G.cash - E.earthCash(G, o.cost) >= reserve);
      const reOpts = opts.filter(o => !o.cv && E.nonProbeRE(G) < lre), cvOpts = idle && G.ships.some(x => x.cls === 'CV' && x.ev > 0 && x.cap) ? [] : opts.filter(o => o.cv && E.nCV(G) < lcv);
      const teles = G.ships.filter(s => s.kind === 'Telescope').length;
      const scoreRE = o => {
        let k = (pr.kinds[o.kind] || .5);
        if (o.kind === 'Telescope') k *= teles < (pr.teles || 1) ? 1.6 : .25;
        return k * (o.u.ev + (o.u.spec ? 2 : 0)) / Math.max(1, E.sum(o.cost)) * pr.re;
      };
      const canFound = G.ships.some(x => x.cls === 'CV' && x.ev > 0 && x.cap);
      const scoreCV = o => (o.u.ev > 0 && o.u.cargo && !canFound && wantBase(G) ? 2.5 : 1) * (o.u.ev > 0 || (G.bases.length && G.ships.filter(x => x.cls === 'CV' && !(x.ev > 0)).length < G.bases.length) ? 1 : 0) * pr.cv * ((o.u.ev || 0) + (o.u.ev > 0 ? (o.u.cargo || 0) * pr.bases : 0) + (pr.armed ? (o.u.cb || 0) * 1.5 : 0)) / Math.max(1, E.sum(o.cost));
      const cands = reOpts.map(o => [o, scoreRE(o)]).concat(cvOpts.map(o => [o, scoreCV(o)]));
      if (!cands.length) break;
      cands.sort((a, b) => b[1] - a[1]);
      if (E.buildUnit(G, cands[0][0].key, 'earth')) break;
    }
  }
  function move(G) {
    G.ships.slice().forEach(s => {
      if (!G.ships.includes(s) || G.ask.length) return;
      const m = E.moves(G, s); if (!m.length) return;
      const p = E.P(s.loc);
      if (s.cls === 'CV') {
        // reserved (recalled) crews head home: Earth, or one of our bases with a supply station
        if (s.res) {
          const home = best(m, x => x.dest === 'earth' ? 100 : G.bases.some(b => E.baseLoc(b) === x.dest && b.fac.sup) ? 90 : E.sysOf(x.dest) === 'ear' ? 40 : E.P(x.dest).t === 'box' && E.P(x.dest).s === 'ear' ? 30 : 0);
          if (home && s.loc !== 'earth') E.move(G, s, home.dest, {});
          return;
        }
        const here = E.worldOf(s.loc), room = s.cap * E.cargoMul(G) - E.sum(s.cargo);
        // cargo-only crew vehicles haul supplies from Earth to our bases
        if (!(s.ev > 0)) {
          if (!s.cap) return;
          let o;
          if (E.sum(s.cargo) && G.bases.length) o = best(m, x => G.bases.some(b => E.baseLoc(b) === x.dest) ? 10 / (1 + (x.eta || 0)) : 0);
          else if (!E.sum(s.cargo)) o = m.find(x => x.dest === 'earth');
          if (!o && s.loc === 'earth' && G.bases.length) o = best(m, x => G.bases.some(b => E.sysOf(E.baseLoc(b)) === E.sysOf(x.dest)) ? 5 / (1 + (x.eta || 0)) : 0);
          if (o) { const opt = s.loc === 'earth' && room > 0 && G.cash > 8 ? { load: { SUP: Math.min(room, G.cash - 8) } } : {}; if (typeof E.move(G, s, o.dest, opt) === 'string') E.move(G, s, o.dest, {}); }
          return;
        }
        // an explorer that should found a base but has no supplies goes down to Earth to load them
        const needSup = s.cap && s.ev > 0 && wantBase(G) && s.cargo.SUP < 3 && baseSpots(G, s, s.cap * E.cargoMul(G)).length > 0;
        if (needSup && s.loc !== 'earth' && E.sysOf(s.loc) === 'ear' && m.some(x => x.dest === 'earth')) { E.move(G, s, 'earth', {}); return; }
        // stay while there is still exploring worth doing here, or while a base could be founded here
        const canExploreHere = here && wv(G, here) >= (here === 'ear' ? 1 : 2) && s.ev > s.dmg && !isGas(here) && E.P(s.loc).t !== 'fly';
        if (s.launched && here && s.loc !== 'earth' && (canExploreHere || canBaseAt(G, s, s.loc, s.cargo.SUP))) return;
        // go somewhere else worth it (not just hop between this world's orbit and surface), unless a base goes here
        const maxLoad = s.loc === 'earth' && s.cap ? Math.max(0, Math.min(room, G.cash - 8)) : 0;
        // only pay for supplies when there is a base spot this crew can reach and afford with them
        const spots = baseSpots(G, s, s.cargo.SUP + maxLoad);
        const load = spots.length ? Math.min(maxLoad, Math.max(0, Math.min(...spots.map(x => x.cost)) - s.cargo.SUP) + (maxLoad > 3 ? 1 : 0)) : 0, sup = s.cargo.SUP + load;
        const foundHere = x => canBaseAt(G, s, x.dest, sup);
        const o = best(m.filter(x => x.dest !== 'earth' && (E.worldOf(x.dest) !== here || foundHere(x) || s.loc === 'earth')), x => destScore(G, s, x.dest, x.eta, sup) + (s.loc === 'earth' && x.dest === 'orbit:ear' ? .6 : 0));
        if (!o || (destScore(G, s, o.dest, o.eta, sup) < 1.5 && !foundHere(o))) return;
        const opt = load > 0 ? { load: { SUP: load } } : {};
        if (typeof E.move(G, s, o.dest, opt) === 'string' && opt.load) E.move(G, s, o.dest, {});
        return;
      }
      // robotic explorers: launch toward the best target, orbiters/rovers make their final move from the flyby box
      if (s.launched && p.t !== 'fly') return;
      const o = best(m, x => destScore(G, s, x.dest, x.eta));
      if (o) E.move(G, s, o.dest, { probe: (G.probes[s.loc] || [])[0] });
    });
    // supply bases by LV cargo flight with what their next building needs (base builders also stock up for settlements)
    if (G.bases.length && G.cash > 12) {
      const pr = prof(G);
      const need = b => {
        const first = pr.lab || b.w === 'ear' ? 'lab' : 'mine';
        const want = !b.fac[first] ? D.FACIL[first][0].c : !b.fac.sup ? D.FACIL.sup[0].c : pr.bases >= 1 ? D.SETTLE_COST : null;
        if (!want) return null;
        const miss = {}; ['ORE', 'SUP', 'FUEL'].forEach(r => { const d = (want[r] || 0) - (b.stock[r] || 0); if (d > 0) miss[r] = d; });
        return E.sum(miss) ? miss : null;
      };
      const b = G.bases.find(need);
      if (b) {
        const lvs = E.launchLVs(G, 'earth', 1), miss = need(b);
        // the smallest launch vehicle that carries it all (South America & Africa carry one more)
        const lv = lvs.find(o => (o.n + (G.f === 'sa' ? 1 : 0)) * E.cargoMul(G) >= E.sum(miss)) || lvs[lvs.length - 1];
        if (lv) { const cap = (lv.n + (G.f === 'sa' ? 1 : 0)) * E.cargoMul(G), load = {}; let left = cap; ['ORE', 'SUP', 'FUEL'].forEach(r => { const n = Math.min(left, miss[r] || 0); if (n) { load[r] = n; left -= n; } }); E.shipCargo(G, b.id, load, lv.n); }
      }
    }
  }
  function combat(G) {
    if (!prof(G).armed) return;
    E.combatOptions(G).filter(o => o.k === 'pirate').forEach(o => E.combatAct(G, o));
  }
  function explore(G) {
    const pr = prof(G);
    G.ships.slice().forEach(s => {
      if (!G.ships.includes(s) || G.ask.length) return;
      let opts = E.exploreOptions(G, s); if (!opts.length) return;
      if (planningBase(G, s)) { E.log(G, `${s.name} holds ${s.cargo.SUP} SUP for a base and skips exploring (no recall check).`); return; }
      const o = best(opts, o => {
        if (o.kind === 'explore' || o.kind === 'probe') return o.value * fw(G, o.w);
        if (o.kind === 'produce') return (s.cap * E.cargoMul(G) - E.sum(s.cargo) > 0 ? 1 : 0) * o.value * (o.res === 'SUP' ? 1.4 : 1) * (pr.bases > 1 ? 1.5 : .6);
        if (o.kind === 'harvest') return 6;
        return 1;
      });
      if (o) E.explore(G, s, o);
      answerAsks(G);
    });
  }
  function trade(G) {
    const pr = prof(G);
    G.ships.slice().forEach(s => {
      if (s.cls !== 'CV') return;
      const c = E.canFoundBase(G, s);
      if (c && baseSpotOk(G, c.w) && wantBase(G) && s.cargo.SUP >= c.cost) E.foundBase(G, s);
      const b = E.atOwnBase(G, s); if (b && E.sum(s.cargo)) E.unload(G, s, b);
    });
    G.bases.forEach(b => {
      const ups = E.upgradeOptions(G, b).filter(o => !o.why);
      const order = [pr.lab || b.w === 'ear' ? 'lab' : 'mine', 'sup', pr.lab ? 'mine' : 'lab', 'def'];
      order.forEach(c => { const o = ups.find(x => x.c === c); if (o && (c !== 'def' || pr.armed) && b.stock && ['ORE', 'SUP', 'FUEL'].every(r => (b.stock[r] || 0) >= (o.next.c[r] || 0))) E.buildFacility(G, b, c); });
      if (pr.bases >= 1 || b.stock.SUP > 6) E.buildSettlement(G, b);
      if (b.trade && E.R.rnd() < .5 + pr.trade / 2) E.trade(G, { base: b.id }, 4);
    });
    if (pr.trade >= .6) Object.keys(G.w).forEach(k => { if (G.w[k].npf && G.w[k].npfTrade) E.trade(G, { w: k }, 4); });
  }
  function botPhase(G) {
    if (G.over) return;
    answerAsks(G);
    try {
      if (G.phase === 'econ') econ(G);
      else if (G.phase === 'build') build(G);
      else if (G.phase === 'move') move(G);
      else if (G.phase === 'combat') combat(G);
      else if (G.phase === 'explore') explore(G);
      else if (G.phase === 'trade') trade(G);
    } catch (e) { E.log(G, 'Bot error: ' + e.message, 'x'); if (typeof console !== 'undefined') console.warn('bot', G.f, e); }
    answerAsks(G);
  }

  // ---------------- coordinator: every phase, each faction acts in initiative order ----------------
  // movement and technology go in reverse initiative order. Bots ahead of you act as the phase opens; the rest act
  // when you press Next. Notable bot events are copied into your log.
  const stepKey = G => G.y + ':' + G.phase + ':' + (G.estep || '');
  function orderFor(world) { const H = world.facs[world.meta.human], o = world.meta.order.slice(); return (H.phase === 'move' || H.estep === 'tech') ? o.reverse() : o; }
  function mirror(H, g, mark) {
    if (H === g) return;
    const fresh = []; for (const l of g.log) { if (l === mark) break; fresh.push(l); }
    fresh.reverse().forEach(l => { if (l.c === 'g' || l.c === 'x' || /moves from|transfer box|launch|recalled|reserve|skips exploring|founds|cargo flight|loads |^Initiative: |^Diplomacy decision/i.test(l.t)) E.log(H, `${D.FAC[g.f].pre}: ${l.t}`, 'bot'); });
  }
  function runBots(H, when) {
    const world = H.world; if (!world) return;
    if (techStep(H)) return techLoop(H, { humanPasses: when !== 'before' });
    const key = stepKey(H), o = orderFor(world), hi = o.indexOf(H.f);
    const list = when === 'before' ? o.slice(0, hi) : when === 'after' ? o.slice(hi + 1) : o.filter(f => f !== H.f);
    world.meta.done = world.meta.done && world.meta.done.key === key ? world.meta.done : { key, f: {} };
    list.forEach(f => {
      if (world.meta.done.f[f]) return; world.meta.done.f[f] = 1;
      const g = world.facs[f]; if (!g || g.over) return;
      const mark = g.log[0]; botPhase(g); mirror(H, g, mark);
    });
  }
  function begin(H) { runBots(H, 'before'); }
  function advanceWorld(H) {
    const world = H.world; if (!world) return E.advance(H);
    if (H.over || H.ask.length) return false;
    runBots(H, 'after');
    if (H.phase === 'econ' && H.estep === 'initiative') E.resolveInitiative(world);
    const order = world.meta.order.slice();
    for (const f of order) {
      const g = world.facs[f]; if (g.over) continue;
      if (g !== H) answerAsks(g);
      const mark = g.log[0];
      E.advance(g);
      if (g !== H) { answerAsks(g); const fresh = []; for (const l of g.log) { if (l === mark) break; fresh.push(l); } fresh.reverse().forEach(l => { if ((l.c === 'x' && /pirate|destroyed|lost/i.test(l.t)) || /^Diplomacy with /.test(l.t)) E.log(H, `${D.FAC[g.f].pre}: ${l.t}`, 'bot'); }); }
    }
    const lead = world.facs[world.meta.order[0]] || world.facs[order[0]];
    if (Object.values(world.facs).some(g => g.over)) Object.values(world.facs).forEach(g => { if (!g.over) E.finish(g, 'The campaign ends.'); });
    else runBots(H, 'before');
    return true;
  }
  // a whole game with no human (tests): the first faction is driven like a bot too
  function autoPlay(H, maxSteps) {
    let n = 0;
    while (!H.over && n++ < (maxSteps || 50000)) {
      if (techStep(H)) techLoop(H, { driveHuman: true });
      runBots(H, 'before'); const mark = H.log[0]; botPhase(H); answerAsks(H); runBots(H, 'after');
      if (!advanceWorld(H)) { answerAsks(H); if (H.ask.length) H.ask.length = 0; }
    }
    return n;
  }
  return { profiles: P, prof, techLoop, botPhase, answerAsks, runBots, begin, advanceWorld, autoPlay, baseSpotOk, planningBase, baseSpots };
}
if (typeof module !== 'undefined' && module.exports) module.exports = makeAI; else root.SHAI = makeAI;
})(typeof window !== 'undefined' ? window : globalThis);
