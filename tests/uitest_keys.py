"""Enter / Escape hotkeys. Usage: python3 uitest_keys.py <site>"""
import sys, subprocess, time
from playwright.sync_api import sync_playwright
site = sys.argv[1]
srv = subprocess.Popen([sys.executable, '-m', 'http.server', '8773', '-d', site], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1); errs = []; bad = 0
def chk(c, m):
    global bad
    print(('ok   ' if c else 'FAIL ') + m); bad += 0 if c else 1
try:
    with sync_playwright() as p:
        b = p.chromium.launch(args=['--use-gl=swiftshader', '--enable-unsafe-swiftshader'])
        pg = b.new_page(viewport={'width': 1440, 'height': 900})
        pg.on('pageerror', lambda e: errs.append(str(e)))
        pg.route('**fonts.googleapis.com**', lambda r: r.abort())
        pg.goto('http://localhost:8773/index.html'); pg.wait_for_selector('#menu [data-mb="new"]', timeout=20000)
        pg.click('#menu [data-mb="new"]', force=True); time.sleep(.3)
        pg.click('#pick [data-f="eu"]'); pg.keyboard.press('Enter'); time.sleep(2)
        chk(pg.evaluate("!!G && $('menu').hidden"), 'Enter on the faction picker starts the game')
        ph = pg.evaluate("G.phase + '/' + G.estep")
        pg.keyboard.press('Enter'); time.sleep(.5)
        chk(pg.evaluate("!$('modal').hidden"), 'Enter on Next opens the confirm dialog')
        pg.keyboard.press('Enter'); time.sleep(.6)
        chk(pg.evaluate("G.phase + '/' + G.estep") != ph, 'Enter presses Next: ' + ph + ' -> ' + pg.evaluate("G.phase + '/' + G.estep"))
        pg.evaluate("window.__r = 0; ask('Test', '<p>hi</p>', () => { __r++; return null; }, 'Build')"); time.sleep(.2)
        pg.keyboard.press('Escape'); time.sleep(.2)
        chk(pg.evaluate("__r === 0 && $('modal').hidden"), 'Escape cancels a confirm dialog')
        pg.evaluate("ask('Test', '<p>hi</p>', () => { __r++; return null; }, 'Build')"); time.sleep(.2)
        pg.keyboard.press('Enter'); time.sleep(.3)
        chk(pg.evaluate("__r === 1 && $('modal').hidden"), 'Enter confirms a build dialog')
        pg.evaluate("G.ask.push({k:'surrender', text:'t', info:{cvs:1,cvSize:3,seize:0,pm:0}, canDeny:true, split:false, ctx:{d:'x'}}); render()"); time.sleep(.2)
        chk(pg.evaluate("!!document.querySelector('#mbox [data-yes]')"), 'decision dialog has a default yes button')
    print('page errors:', errs)
finally:
    srv.terminate()
sys.exit(1 if bad else 0)
