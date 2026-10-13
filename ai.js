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
  // pol: policy preferences; dip: improve relations with NPFs to trade; bully: aggr: appetite for embargoes/wars (0 never .. .5 China-military); polw: weights for random policy choices; trade: use markers
  const P = {
    na: { aggr: .25, polw: { hum: 3, rob: 2, dip: 1, eco: 1, mil: .5 }, fw: { Eng: 1.35, Bio: 1.35, Phy: 1 }, re: 1.2, cv: 1, kinds: { Orbiter: 1.2, Rover: 1.1, Flyby: .8, Telescope: .6 }, lab: true, bases: .7, init: 0,
      tech: ['icd', 'acd', 'qc', 'aqc', 'ai', 'ars', 'pm', 'ff', 'fr', 'cp', 'als', 'aec', 'ag', 'hab', 'mine', 'lcv', 'frig', 'ops', 'tr', 'ldsf', 'psh'], pol: ['rob', 'eco', 'hum', 'set', 'dip'], dip: .2, trade: .3 },
    ru: { aggr: .3, polw: { hum: 5, dip: 1, eco: 1, mil: 1, rob: .3 }, fw: { Bio: 1.6, Eng: 1, Phy: .8 }, re: .5, cv: 1.6, kinds: { Orbiter: 1, Flyby: 1.1, Rover: .7, Telescope: .3 }, lab: true, bases: 1.1, init: 0, crewWorlds: ['mar', 'eur', 'tit'],
      tech: ['orb', 'hab', 'cp', 'als', 'aec', 'ccls', 'acv', 'ops', 'iops', 'aops', 'ism', 'ag', 'hab', 'mine', 'lcv', 'frig', 'ldsf', 'psh', 'ars', 'ish'], pol: ['hum', 'set', 'eco', 'dip'], dip: .2, trade: .3 },
    eu: { aggr: .05, polw: { rob: 3, dip: 3, eco: 1, hum: .5, mil: .1 }, fw: { Phy: 1.55, Eng: 1.1, Bio: .9 }, re: 1.5, cv: .8, kinds: { Telescope: 1.8, Orbiter: 1.2, Flyby: 1, Rover: .8 }, lab: true, bases: .6, init: 0, teles: 2,
      tech: ['icd', 'acd', 'qc', 'aqc', 'ai', 'pm', 'ff', 'fr', 'ars', 'tr', 'itr', 'cp', 'als', 'nano', 'mec', 'atr'], pol: ['rob', 'dip', 'eco', 'hum'], dip: .6, trade: .6 },
    jp: { aggr: .03, polw: { rob: 4, eco: 2, dip: 1.5, hum: .3, mil: .1 }, fw: { Eng: 1.65, Phy: 1, Bio: .8 }, re: 1.7, cv: .4, kinds: { Orbiter: 1.3, Flyby: 1.1, Rover: 1, Telescope: .8 }, lab: true, bases: .4, init: 0,
      tech: ['icd', 'acd', 'qc', 'aqc', 'nano', 'ai', 'pm', 'ff', 'fr', 'pam', 'ars', 'tr'], pol: ['rob', 'eco', 'dip'], dip: .2, trade: .3 },
    cn_mil: { aggr: .5, polw: { mil: 4, hum: 3, eco: 1.5, rob: 1, dip: .5 }, fw: { Eng: 1.3, Phy: 1.1, Bio: 1 }, re: 1, cv: 1.2, kinds: { Orbiter: 1, Rover: 1, Flyby: .9, Telescope: .5 }, lab: false, bases: .8, init: 2, armed: true,
      tech: ['msl', 'amsl', 'isw', 'asw', 'fd', 'cc', 'lcv', 'frig', 'dest', 'icd', 'acd', 'cp', 'hab', 'mine', 'ars', 'pm', 'ff', 'bd'], pol: ['mil', 'hum', 'eco', 'set'], dip: 0, trade: .2 },
    cn_rob: { aggr: .1, polw: { rob: 3, hum: 2.5, eco: 1.5, dip: 1, mil: .7 }, fw: { Eng: 1.4, Bio: 1.2, Phy: 1 }, re: 1.2, cv: 1.1, kinds: { Orbiter: 1.1, Rover: 1.1, Flyby: .9, Telescope: .6 }, lab: false, bases: .9, init: 0,
      tech: ['icd', 'acd', 'hab', 'lcv', 'frig', 'cp', 'als', 'mine', 'ish', 'qc', 'aqc', 'ops', 'iops', 'pm', 'ff', 'ars', 'tr'], pol: ['rob', 'hum', 'set', 'eco'], dip: .2, trade: .3 },
    as: { aggr: .02, polw: { hum: 5, eco: 1.5, dip: 1, rob: .4, mil: .1 }, fw: { Bio: 1.45, Eng: 1.1, Phy: .8 }, re: .7, cv: 1.5, kinds: { Orbiter: 1, Rover: 1, Flyby: .8, Telescope: .3 }, lab: false, bases: 1.6, init: 0,
      tech: ['orb', 'lcv', 'hab', 'mine', 'astro', 'frig', 'ish', 'ref', 'ash', 'ag', 'ops', 'iops', 'cp', 'als', 'lcv', 'frig', 'tr', 'itr', 'psh', 'ars'], pol: ['set', 'hum', 'eco'], dip: .2, trade: .5 },
    sa: { aggr: .1, polw: { hum: 3, dip: 3, eco: 1, rob: 1.5, mil: .3 }, fw: { Bio: 1.15, Eng: 1.15, Phy: 1.15 }, re: 1.1, cv: 1.1, kinds: { Orbiter: 1.1, Rover: 1.1, Flyby: 1, Telescope: .5 }, lab: false, bases: 1.4, init: 0,
      tech: ['orb', 'lcv', 'hab', 'mine', 'astro', 'cp', 'icd', 'acd', 'ish', 'tr', 'itr', 'atr', 'als', 'pm', 'ff', 'ars', 'qc'], pol: ['dip', 'set', 'eco', 'hum'], dip: 1, trade: 1 },
  };
  const prof = G => P[G.f === 'cn' ? 'cn_' + (G.variant || 'mil') : G.f];
  const fieldOf = w => W[w].f || 'Phy';
  const fw = (G, w) => (prof(G).fw[fieldOf(w)] || 1) * ((prof(G).crewWorlds || []).includes(w) ? 1.25 : 1) * (fieldOf(w) === 'Phy' && rangeStage(G) ? 1.7 : fieldOf(w) === 'Eng' && needCvTech(G) ? 1.4 : 1);
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

  // ---------------- mission goals ----------------
  // Priority 1: the personal mission, 2: the common mission (and dated missions open to all), 3: the faction's own
  // leanings (field weights, base drive). A goal is a mission whose world can still be depleted; a crewed-only mission
  // ("cv") can only be completed by a crew vehicle's depletion. These multiply the value of the world for the right kind of
  // explorer (everything below scales by the faction weights as before), steer what is built and what is researched.
  const GOAL_WT = { mine: 3.5, common: 2, dated: 1.6 };
  const goalCache = new WeakMap();
  function goals(G) {
    const sig = [G.y, G.phase, G.estep, G.mis.mine, G.mis.common].join(':');
    const c = goalCache.get(G); if (c && c.sig === sig && c.n === G.ships.length) return c.v;
    const out = [], add = (id, tier) => { if (id == null) return; const m = D.MIS[id]; if (!m || !G.w[m.w] || wv(G, m.w) < 1) return; out.push({ id, w: m.w, cv: !!m.cv, tier, wt: GOAL_WT[tier], vp: m.vp }); };
    add(G.mis.mine, 'mine'); add(G.mis.common, 'common');
    Object.keys(G.w).forEach(w => { if (G.w[w].dmis != null) add(G.w[w].dmis, 'dated'); });
    goalCache.set(G, { sig, n: G.ships.length, v: out }); return out;
  }
  // can a crew vehicle (of any size) be sent there with the current technology and range? returns the blocking reason or null
  function cvWhy(G, w) { try { return E.cvAllowed(G, { sz: 2 }, 'orbit:' + w); } catch (e) { return 'unknown'; } }
  const kindFits = (kind, w) => kind === 'Telescope' || kind === 'Probe' ? false : kind === 'Rover' ? !(isGas(w) || sun(w)) : true;
  // how much more a world is worth to this kind of explorer because of an open mission there
  function missionMult(G, w, kind) {
    if (kind === 'Telescope') return 1;
    let m = 1;
    goals(G).forEach(g => { if (g.w === w && (!g.cv || kind === 'CV') && g.wt > m) m = g.wt; });
    return m;
  }
  // goals that still lack an explorer able to complete them: [{g, need: 'CV' | 'RE'}] in priority order
  function unmet(G) {
    const cvs = G.ships.some(x => x.cls === 'CV' && x.ev > 0);
    return goals(G).filter(g => {
      if (g.cv) return !cvs;
      if (G.ships.some(x => x.cls === 'RE' && kindFits(x.kind, g.w))) return false;
      return !(cvs && !cvWhy(G, g.w));
    }).map(g => ({ g, need: g.cv ? 'CV' : 'RE' }));
  }
  // technologies this faction's crewed goals are waiting for (with unmet prerequisites), weight by goal priority
  const RANGE_LADDER = ['astro', 'als', 'ldsf', 'ccls', 'dse', 'sch'];
  function techWants(G) {
    const want = {}, add = (k, wt) => { const t = D.TECHK[k]; if (!t || G.tech[k]) return; want[k] = Math.max(want[k] || 0, wt); t.r.forEach(r => add(r, wt)); };
    goals(G).filter(g => g.cv || g.tier !== 'dated').forEach(g => {
      if (!g.cv) return;
      const why = cvWhy(G, g.w); if (!why) return;
      if (/Orbital Rendezvous/.test(why)) add('orb', g.wt);
      else if (/Radiation Shielding/.test(why)) add('ars', g.wt);
      else if (/crew range/.test(why)) { const k = RANGE_LADDER.find(k => !G.tech[k]); if (k) add(k, g.wt); }
    });
    return want;
  }

  // ---------------- crew vehicles: early-game discipline ----------------
  // Crew vehicles start with ~50% recall and, before Orbital Rendezvous / Advanced Astrodynamics, can only work at Earth (or the
  // Mars sector for North America), so a bot builds them only as fast as there are places they can work, never beyond its
  // support limit unless a crewed mission needs it, and it digs for the two range technologies (Physics) first.
  const cvFocus = G => prof(G).cv >= 1;                                     // crew-focused or versatile factions
  const rangeStage = G => cvFocus(G) && !(E.has(G, 'orb') && E.has(G, 'astro'));
  const PROD_CV = { na: 3, ru: 3, sa: 3, as: 3, cn: 3, eu: 4, jp: 4 };     // size of the first space-mining (production) CV
  const prodTech = G => PROD_CV[G.f] >= 4 ? 'frig' : 'lcv';
  // after the range techs: crew-focused factions still need the Crew Vehicle techs (CV-2, then CV-3 or CV-4 for the production CV)
  const needCvTech = G => cvFocus(G) && !rangeStage(G) && !G.tech[prodTech(G)];
  // worlds a crew vehicle could work right now (open value, reachable with this technology and range)
  function cvSites(G) {
    return Object.keys(G.w).filter(w => W[w] && !tele(w) && !sun(w) && !W[w].tags.includes('alpha') && wv(G, w) >= (w === 'ear' ? 1 : 2) && !cvWhy(G, w)).length;
  }
  // how many crew vehicles this bot wants in total: one per workable site (plus one hauler once it has bases), capped by its limit
  function cvTarget(G, lcv) {
    return Math.min(lcv, Math.max(1, cvSites(G)) + (G.bases.length ? 1 : 0));
  }

  // ---------------- war readiness, hostility and policies ----------------
  // How ready a faction is to fight: combat-ready crew vehicles by tier (the biggest indicator: CV2/3 = 1, CV4/5 = 2, CV6 = 3,
  // CV7+ = 4), the Engineering military track (Space Missiles ... Bomber Drones) and, less, the Physics combat techs and its Military policy.
  const MIL_ENG = ['msl', 'amsl', 'fd', 'cc', 'bd'], MIL_PHY = ['isw', 'asw', 'ef'];
  const armedCV = s => s.cls === 'CV' && !s.res && s.cb - s.dmg > 0;
  const cvTier = s => s.sz <= 3 ? 1 : s.sz <= 5 ? 2 : s.sz === 6 ? 3 : 4;
  function readiness(F) {
    const cvs = F.ships.filter(armedCV); if (!cvs.length) return 0;
    const pts = 2 * cvs.reduce((a, s) => a + cvTier(s), 0) + MIL_ENG.filter(k => F.tech[k]).length + .5 * MIL_PHY.filter(k => F.tech[k]).length + .4 * E.polLv(F, 'mil');
    return Math.min(1.5, pts / 14);
  }
  const hasNpfBase = (G, k) => Object.values(G.w).some(x => x.npf === k);
  // a bot may pick a fight only when a Military policy allows it (embargo: Military; war: Vigorous Military)
  const canLower = (G, k) => { const nv = G.rel[k] + 1; return nv <= 5 && (nv < 4 || E.polLv(G, 'mil') >= (nv === 4 ? 1 : 2)); };
  // diplomacy turn of a bot, decided at the moment it resolves (so it sees what factions ahead of it just did):
  // 1. answer factions that lowered relations with it (always when it is the weaker side, else sometimes),
  // 2. improve relations with random factions (at least one attempt), at most 6 markers in total,
  // 3. rarely, lower relations: NPFs with bases are the usual target (raiding pays), factions in play only when clearly stronger.
  function diplomacyDecide(G) {
    const pr = prof(G), world = G.world, tag = G.y + ':dip';
    if (G.aiDip === tag) return; G.aiDip = tag;
    G.dipl = {};
    const inPlay = k => !!(world && world.facs[k]), me = readiness(G);
    const budget = Math.min(6, G.polm), maxN = budget >= 6 ? 3 : budget >= 3 ? 2 : budget >= 1 ? 1 : 0;
    if (!maxN) { E.log(G, 'Diplomacy decision: no politics markers to spend.'); G.aiHostile = {}; return; }
    const notes = []; let n = 0;
    // 1. reactions
    Object.entries(G.aiHostile || {}).forEach(([k, y]) => {
      if (!inPlay(k) || G.rel[k] < 4 || n >= maxN) return;
      const them = readiness(world.facs[k]), weaker = me < them - .1, roll = 1 + Math.floor(E.R.rnd() * 100), chance = weaker ? 100 : G.rel[k] >= 5 ? 50 : 25;
      const go = roll <= chance;
      notes.push(`${D.FAC[k].n} lowered relations to ${D.REL[G.rel[k]]} (readiness ${me.toFixed(2)} vs ${them.toFixed(2)}${weaker ? ', weaker' : ''}): rolls ${roll} (${chance}% to answer) ${go ? '→ counters with diplomacy' : '→ lets it stand'}`);
      if (go && !E.setDiplomacy(G, k, 1)) n++;
    });
    G.aiHostile = {};
    // 3. lowering relations (decided before the random improvements so the cost works out); costs one attempt
    let hostile = null;
    if (pr.aggr > 0 && E.polLv(G, 'mil') >= 1 && n < maxN) {
      const cands = Object.keys(G.rel).filter(k => G.rel[k] < 5 && canLower(G, k) && G.dipl[k] == null && (inPlay(k) ? true : hasNpfBase(G, k)) && !(G.dipl[k] > 0));
      const reach = k => Object.keys(G.w).some(w => G.w[w].npf === k && !cvWhy(G, w));      // an NPF base its crews can actually get to
      let opts = cands.map(k => {
        const npf = !inPlay(k), them = npf ? .25 : readiness(world.facs[k]);
        if (me <= 0) return null;                                    // no combat-ready CV: never
        if (npf && !reach(k)) return null;
        if (!npf && me < them + .25) return null;                     // never start a war it is not clearly winning
        let c = pr.aggr * 100 * (npf ? 2.2 : .35) * (.4 + Math.min(1, me - (npf ? 0 : them)));   // factions in play can answer back, NPFs cannot
        if (G.rel[k] === 4) c *= .5;                                  // from embargo to war is costlier still
        return { k, c, npf };
      }).filter(Boolean);
      if (opts.some(o => o.npf)) opts = opts.filter(o => o.npf);       // raiding NPF bases is the usual target
      if (opts.length) {
        const o = opts[Math.floor(E.R.rnd() * opts.length)], roll = 1 + Math.floor(E.R.rnd() * 100);
        const go = roll <= o.c;
        notes.push(`Hostility check vs ${D.FAC[o.k].n}${o.npf ? ' (NPF)' : ''}: readiness ${me.toFixed(2)}, rolls ${roll} (${Math.round(o.c)}% to ${G.rel[o.k] === 4 ? 'declare war' : 'embargo'}) ${go ? '→ tries to lower relations' : '→ keeps the peace'}`);
        if (go && !E.setDiplomacy(G, o.k, -1)) { hostile = o.k; n++; }
      }
    }
    // 2. improvements with whoever is left
    const targets = Object.keys(G.rel).filter(k => G.rel[k] > 0 && k !== hostile && G.dipl[k] == null);
    const want = Math.max(1 - n, 0) + Math.floor(E.R.rnd() * (maxN - n + 1)) ;
    let made = 0;
    for (let a = 0; a < Math.min(want, maxN - n) && targets.length; a++) { const k = pick(targets); if (!E.setDiplomacy(G, k, 1)) { made++; targets.splice(targets.indexOf(k), 1); } }
    if (!made && !n) notes.push(targets.length ? 'no attempts could be paid for' : 'relations with everyone are already at Alliance');
    const att = Object.entries(G.dipl).map(([k, d]) => `${d > 0 ? '+' : '−'}${D.FAC[k].n}`).join(', ');
    E.log(G, `Diplomacy decision: ${att ? `${Object.keys(G.dipl).length} attempt(s) for ${E.dipCost(G)} politics marker(s): ${att}.` : 'no attempts.'}${notes.length ? ' ' + notes.join('; ') + '.' : ''}`);
  }
  // policies: finish the starting track, then the two Space Settlement levels, then crew-focused factions go Human; everything
  // else is a weighted random pick shaped by the faction's goals
  function policyPick(G) {
    const pr = prof(G);
    if (!G.aiStart) G.aiStart = Object.keys(G.pol).filter(k => G.pol[k] > 0);
    const tryK = k => E.polLv(G, k) < 3 && !E.choosePolicy(G, k);
    for (const k of G.aiStart) if (tryK(k)) return;
    if (E.polLv(G, 'set') < 2 && tryK('set')) return;
    if (pr.cv >= 1.4 && tryK('hum')) return;
    const pool = D.POL.map(p => p.k).filter(k => E.polLv(G, k) < 3);
    while (pool.length) {
      const tot = pool.reduce((a, k) => a + (pr.polw[k] != null ? pr.polw[k] : .5), 0); let r = E.R.rnd() * tot, i = 0;
      for (; i < pool.length - 1; i++) { r -= (pr.polw[pool[i]] != null ? pr.polw[pool[i]] : .5); if (r <= 0) break; }
      const k = pool.splice(i, 1)[0]; if (tryK(k)) return;
    }
  }

  // ---------------- targets ----------------
  function worldScore(G, w, kind) {
    if (!G.w[w] || wv(G, w) < 1 || tele(w)) return 0;
    if (kind === 'Rover' && (isGas(w) || sun(w))) return 0;
    if (kind === 'CV' && (sun(w) || W[w].tags.includes('alpha'))) return 0;
    return wv(G, w) * fw(G, w) * missionMult(G, w, kind);
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
    if (kind === 'CV' && p.w && G.w[p.w] && G.w[p.w].npf && armedCV(s) && p.t !== 'box' && p.t !== 'fly' && G.rel[G.w[p.w].npf] >= 4) v += G.rel[G.w[p.w].npf] >= 5 ? 9 : 6;   // blockade / raid
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
      else if (a.k === 'intercept') { const s = G.ships.find(x => x.id === a.ship), g = G.world && G.world.facs[a.by]; r = E.answer(G, s && g && E.interceptAuto(G, s, { g, key: a.key }) === 'fight' ? 'fight' : 'stop'); }
      else if (a.k === 'battle') r = E.answer(G, 'auto');
      else if (a.k === 'surrender') r = E.answer(G, a.split ? 'exclude' : a.canDeny && !a.info.pm && !a.info.seize ? 'deny' : 'accept');
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
    if (G.estep === 'diplomacy' && !G.world) diplomacyDecide(G);   // in multi-faction games each bot decides as its turn resolves (advanceWorld)
    if (G.estep === 'production') G.bases.forEach(b => { b.out = E.bestOutput(G, b); });
    if (G.estep === 'transport' && G.transferLeft && G.bases.length && G.cash > 12) { const b = G.bases.find(x => x.w !== 'ear') || G.bases[0]; E.transferRes(G, 'earth', b.id, 'SUP', Math.min(G.transferLeft, 3)); }
    if (G.estep === 'tech' && !G.world) { for (let n = 0; n < 12; n++) if (!techPick(G) || techTurnBot(G) !== 'dev') break; }
    if (G.estep === 'policy') {
      for (let n = 0; n < 4 && !G.policyPicked; n++) { const before = JSON.stringify(G.pol); policyPick(G); if (JSON.stringify(G.pol) === before) break; }
    }
  }
  // research: the best affordable technology by this bot's priorities, or null
  function techPick(G) {
    const pr = prof(G), open = D.TECH.filter(t => E.techState(G, t) === 'open' && G.bank[t.f] >= E.techCost(G, t));
    if (!open.length) return null;
    const want = techWants(G), stage = rangeStage(G), pt = prodTech(G), cvf = cvFocus(G);
    return best(open.filter(t => {
      if (stage && t.f === 'Phy' && t.k !== 'orb' && t.k !== 'astro') return false;      // save Physics points for the range techs
      if (t.k === 'mine' && !G.tech[pt]) return false;                                  // space mining waits for the production CV
      return true;
    }), t => {
      const i = pr.tech.indexOf(t.k);
      let v = (i >= 0 ? 100 - i * 3 : 20) - E.techCost(G, t) * .3 + (t.r.length ? 0 : 1) + (want[t.k] ? 25 * want[t.k] : 0);
      if (stage && (t.k === 'orb' || t.k === 'astro')) v += 200;
      else if (cvf && !stage && (t.k === 'cv' || t.k === 'lcv' || (t.k === 'frig' && pt === 'frig'))) v += 60;
      return v;
    });
  }
  // one research turn: develop one technology, or pass (and turn leftover politics markers into points for its main field)
  function techTurnBot(G) {
    const t = techPick(G);
    if (t && !E.develop(G, t.k)) return 'dev';
    if (G.world) E.techPass(G);
    const short = (f, ks) => G.bank[f] < ks.reduce((a, k) => a + (G.tech[k] ? 0 : D.TECHK[k].c), 0);
    const main = rangeStage(G) && short('Phy', ['orb', 'astro']) ? 'Phy' : needCvTech(G) && short('Eng', ['cv', 'lcv']) ? 'Eng' : Object.entries(prof(G).fw).sort((a, b) => b[1] - a[1])[0][0];
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
    { const gs = goals(G), um = unmet(G);
      if (gs.length) E.log(G, `Mission focus: ${gs.map(g => `${g.tier === 'mine' ? 'your mission' : g.tier === 'common' ? 'common mission' : 'dated mission'} ${D.W[g.w].n}${g.cv ? ' (crew vehicle)' : ''}`).join('; ')}.${um.length ? ` Needs ${um[0].need === 'CV' ? 'a crew vehicle' : 'a robotic explorer'} for ${D.W[um[0].g.w].n}${um[0].need === 'CV' && cvWhy(G, um[0].g.w) ? ' (cannot reach it yet: ' + cvWhy(G, um[0].g.w) + ')' : ''}.` : ''}`); }
    for (let n = 0; n < 2; n++) {
      const opts = E.buildOptions(G, 'earth').filter(o => !o.why && G.cash - E.earthCash(G, o.cost) >= reserve);
      // crew vehicles: at most one per workable site, at most `perDecade` this decade, never past the support limit unless a
      // reachable crewed mission needs one (then at most 1 over; 2 over is never allowed)
      const foc = unmet(G)[0], focCV = foc && foc.need === 'CV' && !cvWhy(G, foc.g.w);
      const nCv = E.nCV(G), tgt = cvTarget(G, lcv), perDecade = lcv >= 4 && tgt - nCv >= 2 ? 2 : 1;
      if (!G.aiCv || G.aiCv.d !== Math.floor(G.y / 10)) G.aiCv = { d: Math.floor(G.y / 10), n: 0 };   // CVs built this decade (kept in the save)
      const cvBuilt = G.aiCv.n;
      const over = focCV && G.cash - reserve >= 25 ? 1 : 0;
      // a military-minded bot with no combat-ready crew vehicle builds one (it is what makes embargoes and raids possible at all)
      const needArmed = (pr.armed || (pr.aggr >= .2 && E.polLv(G, 'mil') >= 1)) && !G.ships.some(armedCV);
      const cvRoom = cvBuilt < perDecade && (nCv < tgt || (focCV && nCv < lcv + over) || (needArmed && nCv < lcv)) && nCv < lcv + 1;
      const reOpts = opts.filter(o => !o.cv && E.nonProbeRE(G) < lre), cvOpts = !cvRoom || (idle && G.ships.some(x => x.cls === 'CV' && x.ev > 0 && x.cap)) ? [] : opts.filter(o => o.cv);
      const teles = G.ships.filter(s => s.kind === 'Telescope').length;
      // mission focus: build the explorer the first unmet mission goal needs (foc / focCV set above)
      const scoreRE = o => {
        let k = (pr.kinds[o.kind] || .5);
        if (foc) k *= foc.need === 'RE' ? (kindFits(o.kind, foc.g.w) ? 3 : .6) : focCV ? .5 : 1;
        if (o.kind === 'Telescope') k *= teles < (pr.teles || 1) ? 1.6 : .25;
        return k * (o.u.ev + (o.u.spec ? 2 : 0)) / Math.max(1, E.sum(o.cost)) * pr.re;
      };
      const canFound = G.ships.some(x => x.cls === 'CV' && x.ev > 0 && x.cap), warlike = Object.keys(G.rel).some(k => G.rel[k] >= 4 && !(G.world && G.world.facs[k]) && hasNpfBase(G, k));
      const scoreCV = o => (focCV && o.u.ev > 0 ? 5 : 1) * (needArmed && o.u.cb > 0 ? 4 : 1) * (o.u.ev > 0 && o.u.cargo && !canFound && wantBase(G) ? 2.5 : 1) * (o.u.ev > 0 || (G.bases.length && G.ships.filter(x => x.cls === 'CV' && !(x.ev > 0)).length < G.bases.length) ? 1 : 0) * pr.cv * ((o.u.ev || 0) + (o.u.ev > 0 ? (o.u.cargo || 0) * pr.bases : 0) + ((pr.armed || warlike) ? (o.u.cb || 0) * 1.5 : 0)) / Math.max(1, E.sum(o.cost));
      const cands = reOpts.map(o => [o, scoreRE(o)]).concat(cvOpts.map(o => [o, scoreCV(o)]));
      if (!cands.length) break;
      cands.sort((a, b) => b[1] - a[1]);
      if (E.buildUnit(G, cands[0][0].key, 'earth')) break;
      if (cands[0][0].cv) G.aiCv.n++;
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
    const opts = E.combatOptions(G);
    if (prof(G).armed) opts.filter(o => o.k === 'pirate').forEach(o => E.combatAct(G, o));
    // embargo: blockade an NPF base; war: raid it (raiding pays; the fleet needs a combat-ready crew vehicle with some hull left)
    opts.filter(o => o.k === 'raid' || o.k === 'blockade').forEach(o => {
      const fleet = G.ships.filter(s => E.worldOf(s.loc) === o.w && armedCV(s));
      if (o.k === 'raid' && fleet.reduce((a, s) => a + s.sz - s.dmg, 0) < 3) return;
      const r = E.combatAct(G, o); if (typeof r === 'string') return;
    });
    // against another faction: blockade its bases, then fight where our fleet clearly has the upper hand
    ['fblock', 'fleet', 'bombard'].forEach(kind => {
      E.combatOptions(G).filter(o => o.k === kind).forEach(o => {
        if (kind !== 'fblock') {
          const p = E.fleetPower(G, o);
          if (!(p.mine > 0 && (p.unarmed || p.mine >= (kind === 'bombard' ? 1.5 : 1.25) * p.theirs))) return;
        }
        E.combatAct(G, o);
      });
    });
  }
  function explore(G) {
    const pr = prof(G);
    G.ships.slice().forEach(s => {
      if (!G.ships.includes(s) || G.ask.length) return;
      let opts = E.exploreOptions(G, s); if (!opts.length) return;
      if (planningBase(G, s)) { E.log(G, `${s.name} holds ${s.cargo.SUP} SUP for a base and skips exploring (no recall check).`); return; }
      const o = best(opts, o => {
        if (o.kind === 'explore' || o.kind === 'probe') return o.value * fw(G, o.w) * missionMult(G, o.w, s.cls === 'CV' ? 'CV' : s.kind);
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
    fresh.reverse().forEach(l => { if (l.c === 'g' || l.c === 'x' || /moves from|transfer box|launch|recalled|reserve|skips exploring|founds|cargo flight|loads |^Initiative: |^Diplomacy decision|^Mission focus/i.test(l.t)) E.log(H, `${D.FAC[g.f].pre}: ${l.t}`, 'bot'); });
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
      if (g.phase === 'econ' && g.estep === 'diplomacy' && (g !== H || driving)) diplomacyDecide(g);
      E.advance(g);
      if (g !== H) { answerAsks(g); const fresh = []; for (const l of g.log) { if (l === mark) break; fresh.push(l); } fresh.reverse().forEach(l => { if ((l.c === 'x' && /pirate|destroyed|lost/i.test(l.t)) || /^Diplomacy with |^Diplomacy decision/.test(l.t)) E.log(H, `${D.FAC[g.f].pre}: ${l.t}`, 'bot'); }); }
    }
    const lead = world.facs[world.meta.order[0]] || world.facs[order[0]];
    if (Object.values(world.facs).some(g => g.over)) Object.values(world.facs).forEach(g => { if (!g.over) E.finish(g, 'The campaign ends.'); });
    else runBots(H, 'before');
    return true;
  }
  // a whole game with no human (tests): the first faction is driven like a bot too
  let driving = false;
  function autoPlay(H, maxSteps) {
    let n = 0; driving = true;
    while (!H.over && n++ < (maxSteps || 50000)) {
      if (techStep(H)) techLoop(H, { driveHuman: true });
      runBots(H, 'before'); const mark = H.log[0]; botPhase(H); answerAsks(H); runBots(H, 'after');
      if (!advanceWorld(H)) { answerAsks(H); if (H.ask.length) H.ask.length = 0; }
    }
    driving = false; return n;
  }
  return { profiles: P, prof, readiness, diplomacyDecide, policyPick, techLoop, botPhase, answerAsks, runBots, begin, advanceWorld, autoPlay, baseSpotOk, planningBase, baseSpots };
}
if (typeof module !== 'undefined' && module.exports) module.exports = makeAI; else root.SHAI = makeAI;
})(typeof window !== 'undefined' ? window : globalThis);
