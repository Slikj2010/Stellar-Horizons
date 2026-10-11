"""Deeper browser test: build units on Earth, drag-launch one, screenshot close-ups.
Usage: python3 uitest2.py <site_dir> <out_dir>"""
import sys, subprocess, time, os, json
from playwright.sync_api import sync_playwright
site, out = sys.argv[1], sys.argv[2]
srv = subprocess.Popen([sys.executable, '-m', 'http.server', '8769', '-d', site], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1)
errs = []
def ans(pg):
    for _ in range(6):
        if pg.is_visible('#modal'): pg.click('#mbox [data-ans]'); time.sleep(.15)
def to_phase(pg, ph):
    for _ in range(12):
        if pg.evaluate('G.phase') == ph: return
        ans(pg); pg.click('#next'); time.sleep(.2)
try:
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={'width': 1440, 'height': 900})
        pg.on('console', lambda m: errs.append(m.type + ': ' + m.text) if m.type in ('error',) and 'ERR_FAILED' not in m.text else None)
        pg.on('pageerror', lambda e: errs.append('PAGEERROR: ' + str(e)))
        pg.route('**fonts.googleapis.com**', lambda r: r.abort())
        pg.goto('http://localhost:8769/index.html')
        pg.wait_for_selector('#pick [data-f="ru"]', timeout=15000)
        pg.click('#pick [data-f="ru"]'); time.sleep(1.2)
        pg.screenshot(path=os.path.join(out, 'ui2_start.png'))
        to_phase(pg, 'build')
        pg.evaluate("G.cash = 60")
        # build Chernykh orbiter and Gamov probe via the Turn tab buttons
        pg.click('#tabs [data-t="turn"]'); time.sleep(.2)
        pg.click('[data-build="ru|Chernykh"]'); time.sleep(.3)
        pg.screenshot(path=os.path.join(out, 'ui4_build.png'))
        pg.click('[data-ui="gen"]'); time.sleep(.2)
        pg.click('[data-build="ru|Gamov"]'); time.sleep(.2); pg.click('[data-ui="gen"]'); time.sleep(.2)
        print('ships after build:', pg.evaluate("G.ships.map(s=>s.name+'@'+s.loc).join(', ')"), 'probes', pg.evaluate("JSON.stringify(G.probes)"))
        to_phase(pg, 'move')
        # find Chernykh on screen and drag it to Mars flyby (box 1 of Mars with LV)
        pos = pg.evaluate("""(()=>{const s=G.ships.find(x=>x.name==='Chernykh');const h=hits.find(h=>h.t==='ship'&&h.id===s.id);
            const tgt=E.moves(G,s).find(m=>m.dest.startsWith('box:mar'));const tp=posOf(tgt.dest);
            const r=cv.getBoundingClientRect();return {sx:r.left+h.x*cam.s+cam.x, sy:r.top+h.y*cam.s+cam.y, tx:r.left+tp[0]*cam.s+cam.x, ty:r.top+tp[1]*cam.s+cam.y, dest:tgt.dest}})()""")
        print('drag', pos)
        pg.mouse.move(pos['sx'], pos['sy']); pg.mouse.down(); pg.mouse.move(pos['sx'] + 20, pos['sy'] + 10, steps=4)
        pg.mouse.move(pos['tx'], pos['ty'], steps=12); time.sleep(.2)
        pg.screenshot(path=os.path.join(out, 'ui2_drag.png'))
        pg.mouse.up(); time.sleep(.4)
        pg.screenshot(path=os.path.join(out, 'ui5_moveconfirm.png'))
        pg.click('[data-ui="gen"]'); time.sleep(.3)
        print('moves left for Chernykh:', pg.evaluate("E.moves(G,G.ships.find(x=>x.name==='Chernykh')).length"))
        print('after drop:', pg.evaluate("G.ships.map(s=>s.name+'@'+s.loc+(s.probe?'+'+s.probe:'')).join(', ')"))
        print('log:', pg.evaluate("G.log.slice(0,4).map(l=>l.t).join(' || ')"))
        # select Kozlov in Mars orbit and show Selected tab; zoom to Mars
        pg.evaluate("(()=>{const s=G.ships.find(x=>x.name==='Kozlov');sel={t:'ship',id:s.id};tab='sel';focus(posOf(s.loc),.9);render();})()"); time.sleep(.4)
        pg.screenshot(path=os.path.join(out, 'ui2_mars.png'))
        # explore phase with Kozlov
        to_phase(pg, 'explore')
        pg.evaluate("(()=>{const s=G.ships.find(x=>x.name==='Kozlov');sel={t:'ship',id:s.id};tab='sel';render();})()"); time.sleep(.3)
        if pg.is_visible('[data-ex="0"]'):
            pg.click('[data-ex="0"]'); time.sleep(.3)
            pg.screenshot(path=os.path.join(out, 'ui3_confirm.png'))
            pg.click('[data-ui="go"]'); time.sleep(.3)
            pg.screenshot(path=os.path.join(out, 'ui3_result.png'))
            pg.click('[data-ui="ok"]'); time.sleep(.2); ans(pg)
        print('explore log:', pg.evaluate("G.log.slice(0,3).map(l=>l.t).join(' || ')"))
        pg.click('#tabs [data-t="tech"]'); time.sleep(.2)
        pg.screenshot(path=os.path.join(out, 'ui2_tech.png'))
        pg.click('#tabs [data-t="fac"]'); time.sleep(.3)
        pg.screenshot(path=os.path.join(out, 'ui2_fac.png'))
        b.close()
finally:
    srv.terminate()
print('ERRORS:', len(errs))
for e in errs[:20]: print(' ', e)
