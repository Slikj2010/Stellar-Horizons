"""Zoom/inspect overlay test. Usage: python3 uitest_zoom.py <site> <out>"""
import sys, subprocess, time, os
from playwright.sync_api import sync_playwright
site, out = sys.argv[1], sys.argv[2]
srv = subprocess.Popen([sys.executable, '-m', 'http.server', '8772', '-d', site], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1)
errs = []
try:
    with sync_playwright() as p:
        b = p.chromium.launch(args=['--use-gl=swiftshader', '--enable-unsafe-swiftshader'])
        pg = b.new_page(viewport={'width': 1440, 'height': 900})
        pg.on('console', lambda m: errs.append(m.text) if m.type == 'error' and 'ERR_FAILED' not in m.text else None)
        pg.on('pageerror', lambda e: errs.append('PAGEERROR: ' + str(e)))
        pg.route('**fonts.googleapis.com**', lambda r: r.abort())
        pg.goto('http://localhost:8772/index.html')
        pg.wait_for_selector('#menu [data-mb="new"]', timeout=20000)
        pg.click('#menu [data-mb="new"]', force=True); time.sleep(.4)
        pg.click('#pick [data-f="eu"]'); pg.click('#pickgo'); time.sleep(2)
        pg.evaluate("document.querySelector('[data-t=\"fac\"]') && document.querySelector('[data-t=\"fac\"]').click()")
        time.sleep(.5)
        print('tabs:', pg.evaluate("[...document.querySelectorAll('#tabs [data-t], .tabs [data-t]')].map(e=>e.dataset.t).join(',')"))
        pg.click('[data-zoomg="buildings"]'); time.sleep(.5)
        print('buildings cells:', pg.locator('#zov .zcell').count(), 'visible:', not pg.evaluate("$('zov').hidden"))
        pg.screenshot(path=os.path.join(out, 'z_buildings.png'))
        pg.locator('#zov [data-zoomm]').first.click(); time.sleep(.3)
        print('marker zoom title:', pg.inner_text('#zbox h2'))
        pg.screenshot(path=os.path.join(out, 'z_marker.png'))
        pg.keyboard.press('Escape'); time.sleep(.2)
        print('closed:', pg.evaluate("$('zov').hidden"))
        pg.click('[data-zoomg="units"]'); time.sleep(.5)
        print('unit cells:', pg.locator('#zov .zcell').count())
        pg.screenshot(path=os.path.join(out, 'z_units.png'))
        pg.locator('#zov [data-zoomu]').first.click(); time.sleep(.3)
        print('unit zoom:', pg.inner_text('#zbox h2'))
        pg.click('[data-zside="back"]'); time.sleep(.2)
        print('side:', pg.inner_text('#zbox p.dim'))
        pg.screenshot(path=os.path.join(out, 'z_unitback.png'))
        pg.click('[data-zclose]'); time.sleep(.2)
        print('closed:', pg.evaluate("$('zov').hidden"))
    print('ERRORS:', errs)
finally:
    srv.terminate()
