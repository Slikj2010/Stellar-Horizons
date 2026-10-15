"""Combat screen test. Usage: python3 uitest_combat.py <site> <out>"""
import sys, subprocess, time, os
from playwright.sync_api import sync_playwright
site, out = sys.argv[1], sys.argv[2]
srv = subprocess.Popen([sys.executable, '-m', 'http.server', '8776', '-d', site], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
        pg.goto('http://localhost:8777/index.html' if False else 'http://localhost:8776/index.html'); pg.wait_for_selector('#menu [data-mb="new"]', timeout=20000)
        pg.click('#menu [data-mb="new"]', force=True); pg.click('#pick [data-f="eu"]'); pg.select_option('#nbots', '1'); pg.click('#pickgo'); time.sleep(2)
        pg.evaluate("G.ask.push({ k: 'search', ok: false, auto: false, T: 4, rolls: [{ n: 'You', r: 7 }, { n: 'Pirate', r: 9 }], where: 'Mars flyby box', text: 'You search but do not find the pirate.' }); render()"); time.sleep(.3)
        pg.screenshot(path=os.path.join(out, 'c_search.png'))
        chk('No contact' in pg.inner_text('#mbox') and 'Back to the map' in pg.inner_text('#mbox'), 'failed search shows the rolls and returns to the map')
        pg.keyboard.press('Enter'); time.sleep(.3)
        chk(pg.evaluate("G.ask.length === 0 && $('modal').hidden"), 'Enter closes the search result')
        # pirate combat screen with tactics points
        pg.evaluate("""() => { const s = G.ships.find(x => x.cls === 'CV') || G.ships[0]; window.__s = s; G.ask.push({ k: 'pbattle', st: { cont: null, sy: 'mar', ids: [s.id], strong: false, dm: 7, dp: 3, myTP: 9, pTP: 4, extra: 5 }, mine: [{ n: 'Pegasus', cb: 4 }], weapons: 0, pir: { strong: false, cb: 1, size: 2, dmg: 0 }, myTot: 11, pTot: 4, myBase: 3, pDmg: 0, extra: 5, myTP: 9, pTP: 4, can: 2, text: 'test pirate' }); render(); }""")
        time.sleep(.3); pg.screenshot(path=os.path.join(out, 'c_pirate.png'))
        txt = pg.inner_text('#mbox')
        chk('Total 11' in txt and 'deal 5' in txt and '3 damage' in txt, 'pirate screen shows the roll, table damage and tactics options')
        pg.keyboard.press('Enter'); time.sleep(.3)
        chk(pg.evaluate("G.ask.length === 0"), 'Enter spends the default and resolves')
        # faction combat screen
        pg.evaluate("""() => { const o = Object.values(G.world.facs).find(f => f.f !== G.f); G.ask.push({ k: 'battle', st: { a: G.f, d: o.f, key: 'w:mar', ia: [], id: [], ib: [], tpA: 8, tpB: 3, dA: 6, dB: 2 }, side: 'a', rem: 5, lose: false, tie: false, tp: 8, opp: 3, d: 6, od: 2,
          strike: { dealt: 2, taken: 1, tot: 10, otot: 5 }, direct: { dealt: 3, taken: 2, tot: 12, otot: 7 }, mine: [{ n: 'Pegasus', cb: 4 }], theirs: [{ n: 'Falcon', cb: 3 }], foe: 'Foe', where: 'Mars orbit', text: 't' }); render(); }""")
        time.sleep(.3); pg.screenshot(path=os.path.join(out, 'c_battle.png'))
        chk('Tactics points' in pg.inner_text('#mbox') and pg.locator('#mbox .plan').count() == 1, 'battle screen has the tactics plan builder')
        pg.check('[name="pm"][value="direct"]'); pg.fill('[data-pp="inc"]', '1'); pg.fill('[data-pp="red"]', '1'); pg.fill('[data-pp="picks"]', '2'); time.sleep(.2)
        chk(pg.inner_text('#pcost') == '7', 'cost updates live: ' + pg.inner_text('#pcost'))
        pg.screenshot(path=os.path.join(out, 'c_battle.png'))
        pg.fill('[data-pp="picks"]', '9'); pg.click('[data-plango]'); time.sleep(.3)
        chk(pg.evaluate("G.ask.length === 1"), 'overspending is refused')
        pg.fill('[data-pp="picks"]', '0'); pg.click('[data-plango]'); time.sleep(.3)
        chk(pg.evaluate("G.ask.length === 0"), 'battle plan accepted')
        pg.evaluate("G.ask.push({ k: 'assign', me: 'a', st: { a: G.f, d: Object.keys(G.world.facs).find(f => f !== G.f), key: 'w:mar', ia: [], id: [], ib: [], tpA: 2, tpB: 2, dA: 3, dB: 3 }, plan: null, groups: [{ side: 'foe', n: 2, units: [{ key: 's1', n: 'Falcon', cb: 3, hp: 3 }, { key: 's2', n: 'Orion', cb: 2, hp: 2 }] }, { side: 'mine', n: 1, units: [{ key: 's5', n: 'Pegasus', cb: 4, hp: 5 }, { key: 's6', n: 'Tanker', cb: 0, hp: 2 }] }], screen: [{ key: 's6', n: 'Tanker' }], strike: false, hits: { foe: 2, mine: 1 }, text: 'Direct fire at Mars: assign the damage.' }); render()"); time.sleep(.3)
        pg.screenshot(path=os.path.join(out, 'c_assign.png'))
        chk('Assign damage' in pg.inner_text('#mbox') and pg.locator('#mbox [data-un]').count() == 4, 'assign screen lists units')
        pg.fill('[data-grp="foe"] [data-un="s1"]', '1'); pg.click('[data-asgo]'); time.sleep(.3)
        chk(pg.evaluate("G.ask.length === 1"), 'wrong totals are refused')
    print('page errors:', errs)
finally:
    srv.terminate()
sys.exit(1 if bad or errs else 0)
