/* Solar-system layout for the 2.5D view.
   The printed board is cut into one "pod" per heliocentric system (Mercury ... Alpha Centauri). Each pod keeps its geometry
   exactly (transfer boxes, flyby box, orbit and surface zones, world cards): it is only moved and scaled by a fixed factor,
   so every anchor point is still where the rules put it relative to its world. The pods are then placed on orbit rings round
   the Sun, with the Main Belt and Kuiper Belt as particle rings that their pods sit on.
   Works in the browser (window.SHL) and in Node (module.exports). */
(function (root) {
  'use strict';
  const S = .6;                                   // board units -> scene units
  const RING = { mer: 0, ven: 1700, ear: 2700, mar: 3700, bel: 4900, jup: 6300, sat: 7900, ura: 9400, nep: 10800, kui: 12400, sca: 14200, alp: 17600 };
  const PREF = { ven: -150, ear: 25, mar: -55, bel: 120, jup: -140, sat: 35, ura: 205, nep: 95, kui: -25, sca: 150, alp: -75 }; // preferred angle in degrees (0 = east, +90 = south)
  // Satellite worlds that sit out in the belts at their own place instead of inside their system's pod: ring radius follows the
  // semi-major axis (Main Belt band 4300-5500 = 2.1-3.3 AU, Kuiper band 11600-13200 = 30-50 AU, the scattered disc beyond), angle is spread round the belt.
  const SAT = { ves: { ring: 4560, ang: 290 }, cer: { ring: 4970, ang: 205 }, hyg: { ring: 5150, ang: 25 }, plu: { ring: 12360, ang: 215 }, hau: { ring: 12760, ang: 295 }, eri: { ring: 13950, ang: 100 }, sed: { ring: 14500, ang: 30 }, dsa: { ring: 15245, ang: -30.8 } };
  const BELTS = [{ k: 'bel', r0: 4300, r1: 5500, n: 30000, col: [.72, .62, .5] }, { k: 'kui', r0: 11600, r1: 13200, n: 26000, col: [.62, .76, .92] }];

  function build(GEO, D, sunC) {
    const B = {}, AN = [];
    const add = (k, x, y, anchor) => { if (anchor) AN.push([x, y, k]); const b = B[k] = B[k] || [1e9, 1e9, -1e9, -1e9]; b[0] = Math.min(b[0], x); b[1] = Math.min(b[1], y); b[2] = Math.max(b[2], x); b[3] = Math.max(b[3], y); };
    Object.entries(GEO.sys).forEach(([k, s]) => { add(k, s.flyby[0], s.flyby[1], 1); s.flybyPoly.forEach(p => add(k, p[0], p[1], 1)); Object.values(s.boxPoly).forEach(q => q.forEach(p => add(k, p[0], p[1], 1))); });
    Object.entries(GEO.worlds).forEach(([w, g]) => {
      const k = SAT[w] ? w : D.W[w] ? D.W[w].sys : (GEO.sys[w] ? w : null); if (!k) return;
      (g.poly || []).forEach(p => add(k, p[0], p[1], 1)); if (g.orbit) add(k, g.orbit[0], g.orbit[1], 1); if (g.surf) add(k, g.surf[0], g.surf[1], 1);
      if (g.wcard) { add(k, g.wcard[0] - 260, g.wcard[1] - 200); add(k, g.wcard[0] + 260, g.wcard[1] + 260); AN.push([g.wcard[0], g.wcard[1], k], [g.wcard[0] + 120, g.wcard[1] + 120, k]); }
    });
    const pods = {};
    Object.keys(B).forEach(k => {
      if (SAT[k]) { const m = B[k], cx = (m[0] + m[2]) / 2, cy = (m[1] + m[3]) / 2, hw = Math.max((m[2] - m[0]) / 2, 330), hh = Math.max((m[3] - m[1]) / 2, 280); B[k] = [cx - hw, cy - hh, cx + hw, cy + hh]; }
      const b = B[k].map((v, i) => v + (i < 2 ? -40 : 40)), hubW = SAT[k] ? GEO.worlds[k] : D.SYS[k] && D.SYS[k].hub && GEO.worlds[D.SYS[k].hub];
      let hub = hubW && hubW.orbit ? hubW.orbit.slice() : [(b[0] + b[2]) / 2, (b[1] + b[3]) / 2];
      if (!hubW && GEO.sys[k]) {      // a system with no hub world (the Scattered Disk): centre it on the circle its transfer boxes sit round
        const P = Object.values(GEO.sys[k].box), n = P.length; let sx = 0, sy = 0, sxx = 0, syy = 0, sxy = 0, sz = 0, sxz = 0, syz = 0;
        P.forEach(([x, y]) => { sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y; const z = x * x + y * y; sz += z; sxz += x * z; syz += y * z; });
        const A = [[sxx, sxy, sx], [sxy, syy, sy], [sx, sy, n]], bb = [sxz, syz, sz], det = m => m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
        const rep = c => A.map((r, i) => r.map((v, j) => j === c ? bb[i] : v)), d0 = det(A);
        if (Math.abs(d0) > 1e-6) hub = [det(rep(0)) / d0 / 2, det(rep(1)) / d0 / 2];
      }
      if (k === 'mer' && sunC) hub = sunC.slice();      // Mercury's pod is pinned so that the board's sun sits at the middle of the scene
      pods[k] = { k, name: SAT[k] ? D.W[k].n : D.SYS[k].n, bbox: b, hub, org: [0, 0], ring: SAT[k] ? SAT[k].ring : RING[k] || 0, ang: 0, sat: !!SAT[k] };
    });
    // overlap test between placed pods (rectangles in scene units)
    const rect = p => [p.org[0] + (p.bbox[0] - p.hub[0]) * S, p.org[1] + (p.bbox[1] - p.hub[1]) * S, p.org[0] + (p.bbox[2] - p.hub[0]) * S, p.org[1] + (p.bbox[3] - p.hub[1]) * S];
    const hit = (a, b, m) => a[0] - m < b[2] && a[2] + m > b[0] && a[1] - m < b[3] && a[3] + m > b[1];
    const placed = [pods.mer];
    ['ven', 'ear', 'mar', 'bel', 'jup', 'sat', 'ura', 'nep', 'kui', 'sca', 'alp'].concat(Object.keys(SAT)).forEach(k => {
      const p = pods[k]; let best = null; const PA = SAT[k] ? SAT[k].ang : PREF[k];
      for (let m of [200, 120, 40, -1e9]) {
        for (let d = 0; d <= 180; d += 5) for (const sg of d ? [1, -1] : [1]) {
          const a = (PA + sg * d) * Math.PI / 180; p.org = [Math.cos(a) * p.ring, Math.sin(a) * p.ring];
          const r = rect(p); if (placed.every(q => !hit(r, rect(q), m))) { best = a; if (SAT[k]) d = 999; break; }
        }
        if (best !== null) break;
      }
      p.ang = best; p.org = [Math.cos(best) * p.ring, Math.sin(best) * p.ring]; placed.push(p);
    });
    // which pods can own a point of the board: those whose box meets the printed sheet that holds it
    const sheets = Object.entries(GEO.maps).map(([c, r]) => ({ c, r: [r[0], r[1], r[0] + r[2], r[1] + r[3]] }));
    const sheetOf = (x, y) => { let best = null, bd = 1e18; sheets.forEach(s => { const dx = Math.max(s.r[0] - x, 0, x - s.r[2]), dy = Math.max(s.r[1] - y, 0, y - s.r[3]), d = dx * dx + dy * dy; if (d < bd) { bd = d; best = s; } }); return best; };
    const cand = {};
    sheets.forEach(s => { cand[s.c] = Object.values(pods).filter(p => hit(s.r, p.bbox, 0)); });
    // a point belongs to the system whose printed geometry (boxes, zones, cards) is nearest to it
    const cache = new Map();
    function podAt(x, y) {
      const key = Math.round(x) * 100000 + Math.round(y); let c = cache.get(key); if (c) return c;
      let best = null, bd = 1e18;
      for (let i = 0; i < AN.length; i++) { const a = AN[i], d = (a[0] - x) ** 2 + (a[1] - y) ** 2; if (d < bd) { bd = d; best = a; } }
      c = pods[best[2]]; if (cache.size > 20000) cache.clear(); cache.set(key, c); return c;
    }
    const toL = (x, y, pod) => { const p = pod || podAt(x, y); return [p.org[0] + (x - p.hub[0]) * S, p.org[1] + (y - p.hub[1]) * S, p]; };
    const fromL = (X, Z) => {
      let best = null, ba = 1e18;
      Object.values(pods).forEach(p => { const r = rect(p); if (X >= r[0] && X <= r[2] && Z >= r[1] && Z <= r[3]) { const a = (r[2] - r[0]) * (r[3] - r[1]); if (a < ba) { ba = a; best = p; } } });
      return best ? [(X - best.org[0]) / S + best.hub[0], (Z - best.org[1]) / S + best.hub[1], best] : null;
    };
    // the art of each pod: the parts of the printed sheets inside its box
    Object.values(pods).forEach(p => {
      p.arts = []; sheets.forEach(s => { const r = [Math.max(s.r[0], p.bbox[0]), Math.max(s.r[1], p.bbox[1]), Math.min(s.r[2], p.bbox[2]), Math.min(s.r[3], p.bbox[3])]; if (r[2] - r[0] > 60 && r[3] - r[1] > 60) p.arts.push({ sheet: s.c, rect: r }); });
      p.rect = rect(p);
    });
    const addAnchor = (x, y, k) => { AN.push([x, y, k]); cache.clear(); };
    return { S, pods, podAt, toL, fromL, addAnchor, rect, belts: BELTS, rings: Object.values(pods).filter(p => p.ring && !p.sat && p.k !== 'bel' && p.k !== 'kui' && p.k !== 'sca' && p.k !== 'alp').map(p => ({ k: p.k, r: p.ring })), sunR: sunC ? 428 * S : 250 };
  }
  const api = { build, S, RING };
  if (typeof module !== 'undefined') module.exports = api; else root.SHL = api;
})(this);
