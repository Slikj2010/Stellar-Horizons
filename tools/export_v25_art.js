// Renders the 2.5D view's procedural art (galaxy and nebula atlases, deep-field backdrop, nebula wash) with the web
// version's own code in headless Chromium, and saves it as PNG files for the Godot port (godot/assets/v25/).
// Usage: node tools/export_v25_art.js   (needs Playwright with Chromium)
const fs = require('fs'), path = require('path'), { chromium } = require('playwright');
const root = path.join(__dirname, '..'), out = path.join(root, 'godot', 'assets', 'v25');
(async () => {
  fs.mkdirSync(out, { recursive: true });
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  // the flat view's nebula wash (FX.neb), with the RNG consumed by the stars first, exactly as initFX does
  const a = html.indexOf('function mulberry('), b = html.indexOf('\n', a);
  const s0 = html.indexOf('  const rnd = mulberry(20300)'), s1 = html.indexOf('  FX.neb = nb;');
  const fxCode = 'const FX = { t: 0 };\n' + html.slice(a, b) + '\nfunction makeNeb() {\n' + html.slice(s0, s1) + '  return nb;\n}\n';
  let v25 = fs.readFileSync(path.join(root, 'view25.js'), 'utf8');
  v25 = v25.replace(/\}\)\(\);\s*$/, '  V._art = { galaxyAtlas, deepBg, nebulaAtlas };\n})();\n');
  const browser = await chromium.launch(), page = await browser.newPage();
  await page.setContent('<html><body></body></html>');
  await page.addScriptTag({ content: fxCode });
  await page.addScriptTag({ content: v25 });
  const imgs = await page.evaluate(() => ({ galaxies: V25._art.galaxyAtlas().toDataURL('image/png'), deep_bg: V25._art.deepBg().toDataURL('image/png'),
    nebulae: V25._art.nebulaAtlas().toDataURL('image/png'), neb_wash: makeNeb().toDataURL('image/png') }));
  for (const [k, d] of Object.entries(imgs)) { fs.writeFileSync(path.join(out, k + '.png'), Buffer.from(d.split(',')[1], 'base64')); console.log('wrote', k + '.png'); }
  await browser.close();
})();
