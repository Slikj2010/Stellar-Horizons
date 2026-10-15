"""2.5D view smoke test. Usage: python3 uitest_25d.py <site> <outdir>"""
import sys, subprocess, time, os
from playwright.sync_api import sync_playwright
site, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
srv = subprocess.Popen([sys.executable, '-m', 'http.server', '8774', '-d', site], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1); errs = []; bad = 0
def chk(c, m):
    global bad
    print(('ok   ' if c else 'FAIL ') + m); bad += 0 if c else 1
try:
    with sync_playwright() as p:
        b = p.chromium.launch(args=['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'])
        pg = b.new_page(viewport={'width': 1440, 'height': 900})
        pg.on('pageerror', lambda e: errs.append(str(e))); pg.on('console', lambda m: errs.append(m.text) if m.type == 'error' else None)
        pg.route('**fonts.googleapis.com**', lambda r: r.abort())
        pg.goto('http://localhost:8774/index.html'); pg.wait_for_selector('#menu [data-mb="new"]', timeout=20000)
        pg.click('#menu [data-mb="new"]', force=True); time.sleep(.3)
        pg.click('#pick [data-f="eu"]'); pg.keyboard.press('Enter'); time.sleep(2)
        pg.evaluate("cam.s=1.2; cam.x=-GEO.worlds.ear.orbit[0]*1.2+500; cam.y=-GEO.worlds.ear.orbit[1]*1.2+400; dirty=true"); time.sleep(.6); pg.screenshot(path=out + '/flat.png'); pg.click('#v25'); time.sleep(2.5)
        chk(pg.evaluate("V25.on && V25.ok === true"), '2.5D view starts: ' + str(pg.evaluate("V25.err || ''")))
        pg.screenshot(path=out + '/a_home.png')
        pg.click('#zfit'); time.sleep(1); pg.screenshot(path=out + '/b_fit.png')
        pg.evaluate("V25.focus(GEO.worlds.ear.orbit, 1.4); V25.cam.pitch = .98; dirty = true"); time.sleep(1)
        pg.screenshot(path=out + '/c_earth.png')
        pk = pg.evaluate("V25.picks().filter(p => p.rec && p.rec.hit && p.rec.hit.t === 'ship').filter(p => p.sx > 0 && p.sx < 1000 && p.sy > 0 && p.sy < 850).map(p => [p.sx, p.sy, p.rec.hit.id])")
        chk(len(pk) >= 1, 'a hovering ship is pickable: ' + str(pk))
        if pk:
            box = pg.evaluate("(() => { const r = V25.canvas().getBoundingClientRect(); return [r.left, r.top]; })()")
            pg.mouse.click(box[0] + pk[0][0], box[1] + pk[0][1]); time.sleep(.5)
            chk(pg.evaluate("sel && sel.t === 'ship' && sel.id === %d" % pk[0][2]), 'tapping the ship selects it')
            pg.screenshot(path=out + '/d_sel.png')
        # drag a movable counter onto a highlighted zone
        pg.evaluate("G.cash = 999; G.phase = 'build'; const o = E.buildOptions(G, 'earth').find(x => !x.why && x.kind === 'Orbiter'); E.buildUnit(G, o.key, 'earth'); G.phase = 'move'; render(); dirty = true"); time.sleep(.6)
        info = pg.evaluate("(() => { const s = G.ships.find(x => x.loc === 'earth' && E.moves(G, x).length); if (!s) return null; const m = E.moves(G, s)[0]; const pp = posOf(m.dest); return { id: s.id, dest: m.dest, x: pp[0], y: pp[1] }; })()")
        chk(info is not None, 'a movable ship exists: ' + str(info))
        if info:
            pg.evaluate("V25.fit(); V25.cam.dist = 13000; V25.cam.tx = -1000; V25.cam.tz = 0; dirty = true"); time.sleep(.8)
            sp = pg.evaluate("V25.picks().filter(p => p.rec && p.rec.hit && p.rec.hit.t === 'ship' && p.rec.hit.id === %d).map(p => [p.sx, p.sy])" % info['id'])
            tp = pg.evaluate("(() => { const q = V25.toScreen(%f, %f, 0); return [q[0], q[1]]; })()" % (info['x'], info['y']))
            box = pg.evaluate("(() => { const r = V25.canvas().getBoundingClientRect(); return [r.left, r.top]; })()")
            chk(bool(sp), 'new ship is pickable at ' + str(sp))
            if sp:
                pg.mouse.move(box[0] + sp[0][0], box[1] + sp[0][1]); pg.mouse.down(); pg.mouse.move(box[0] + sp[0][0] + 20, box[1] + sp[0][1] + 20, steps=3)
                time.sleep(.3); chk(pg.evaluate("!!dragS && !!targets"), 'dragging a counter highlights its destinations')
                pg.screenshot(path=out + '/e_drag.png')
                pg.mouse.move(box[0] + tp[0], box[1] + tp[1], steps=8); pg.mouse.up(); time.sleep(.6)
                chk(pg.evaluate("!$('modal').hidden && /Move/.test($('modal').innerText)"), 'dropping on a zone opens the move dialog: ' + pg.evaluate("$('modal').innerText.slice(0, 60)"))
                pg.screenshot(path=out + '/f_drop.png')
                pg.keyboard.press('Escape'); time.sleep(.3)
        pg.click('#v25'); time.sleep(.5)
        chk(pg.evaluate("!V25.on && cv.style.display !== 'none'"), 'toggle back to the flat map')
        errs = [e for e in errs if 'ERR_FAILED' not in e]
        chk(not errs, 'no page errors: ' + '; '.join(errs[:3]))
        b.close()
finally:
    srv.terminate()
sys.exit(1 if bad else 0)
