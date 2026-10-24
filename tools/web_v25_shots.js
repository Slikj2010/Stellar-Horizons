// Reference screenshots of the web version's 2.5D view, for comparing the Godot port with it.
// Plays the same seeded start as the Godot screenshot test (tests/screenshot.gd, plan 3d: faction na with bots, seed 7).
// Usage: node tools/web_v25_shots.js <outdir> [faction] [steps]
const path = require('path'), fs = require('fs'), http = require('http'), { chromium } = require('playwright');
const root = path.join(__dirname, '..'), out = process.argv[2] || '/tmp/webv25', fac = process.argv[3] || 'na', steps = +(process.argv[4] || 0);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.webp': 'image/webp', '.png': 'image/png', '.css': 'text/css', '.svg': 'image/svg+xml' };
const srv = http.createServer((q, r) => { const f = path.join(root, decodeURIComponent(q.url.split('?')[0])); fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); return; } r.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); r.end(d); }); });
(async () => {
  fs.mkdirSync(out, { recursive: true });
  await new Promise(ok => srv.listen(8765, ok));
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  p.on('pageerror', e => console.log('page error', e.message));
  await p.goto('http://localhost:8765/index.html');
  await p.waitForTimeout(1500);
  await p.evaluate(async ([fac, steps]) => {
    let seed = 7; E.R.rnd = () => { seed = (seed * 48271) % 2147483647; return seed / 2147483647; };
    const bots = D.FAC_ORDER.filter(f => f !== fac).map(f => ({ f }));
    await Promise.all(D.FAC_ORDER.map(loadAtlas));
    G = E.newWorld({ rerolls: true, scrapRE: false, enhTrade: false, scenario: 'std', human: fac, bots });
    AI.begin(G);
    for (let i = 0; i < steps; i++) { while (G.ask.length) AI.answerAsks(G); if (!G.over) AI.botPhase(G); if (G.ask.length || G.over) continue; AI.advanceWorld(G); if (G.phase === 'econ' && G.estep === 'tech' && !G.ask.length) AI.techLoop(G); }
    $('pick').hidden = true; hideMenu(); sel = null; tab = 'turn'; render();
    SET.anim = false;
    await toggle25(true);
  }, [fac, steps]);
  const shot = async (name, fn) => { await p.evaluate(fn); await p.waitForTimeout(400); await p.screenshot({ path: path.join(out, name + '.png') }); console.log('shot', name); };
  await shot('60_v25_home', () => { V25.home(posOf('earth')); dirty = true; });
  await shot('61_v25_fit', () => { V25.fit(); dirty = true; });
  for (const [n, k] of [['62_v25_earth', 'ear'], ['63_v25_jupiter', 'jup'], ['64_v25_mars', 'mar'], ['65_v25_saturn', 'sat'], ['66_v25_kuiper', 'kui'], ['67_v25_alpha', 'alp']]) await shot(n, new Function(`V25.focusPod('${k}'); dirty = true;`));
  await shot('68_v25_turned', () => { V25.home(posOf('earth')); V25.rotate(.6, -.3); dirty = true; });
  await b.close(); srv.close();
})();
