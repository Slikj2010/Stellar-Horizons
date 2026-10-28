## Stellar Horizons solo campaign rules engine (GDScript port of rules.js). Pure logic: no nodes, no UI.
## Locations: 'earth' (Earth surface / launch pad), 'orbit:<w>', 'surf:<w>', 'fly:<sys>', 'box:<sys>:<n>'.
## Game state G is a plain Dictionary with the same shape as the web version, so saves and logs line up.
## Function names follow the JavaScript engine one for one, which keeps the two versions easy to compare.
class_name SHRules
extends RefCounted

var D: Dictionary
var UNITS: Dictionary
var W: Dictionary
var SYS: Dictionary
## random number source returning a float in [0, 1). Replace it to seed games (see SHRng).
var rnd: Callable = func() -> float: return randf()
## optional hook called with (G, entry) for every log line (tests use it to record whole games)
var on_log: Callable

const RES := ["ORE", "SUP", "FUEL"]
const FIELDS := ["Phy", "Eng", "Bio"]
const FN := {"Phy": "Physics", "Eng": "Engineering", "Bio": "Biology"}

func _init(data: Dictionary, units: Dictionary) -> void:
	D = data
	UNITS = units
	W = D.W
	SYS = D.SYS

# ---------------- JavaScript-compatible helpers ----------------
## number to text exactly as JavaScript prints it (3 not 3.0, 0.5, -195.5)
static func n(x) -> String:
	if x is int: return str(x)
	if x is float:
		if is_nan(x): return "NaN"
		if is_inf(x): return "Infinity" if x > 0 else "-Infinity"
		if x == floorf(x) and absf(x) < 1e15: return str(int(x))
		return var_to_str(x)
	if x is bool: return "true" if x else "false"
	if x == null: return "null"
	return str(x)
## JavaScript truthiness (an empty array or dictionary is true, as in JS)
static func t(v) -> bool:
	match typeof(v):
		TYPE_NIL: return false
		TYPE_BOOL: return v
		TYPE_INT: return v != 0
		TYPE_FLOAT: return v != 0.0 and not is_nan(v)
		TYPE_STRING, TYPE_STRING_NAME: return v != ""
	return true
## a || b
static func orv(a, b) -> Variant:
	return a if t(a) else b
## Math.round (halves round up)
static func rnd_i(x: float) -> int:
	return int(floor(x + 0.5))
static func fl(x: float) -> int:
	return int(floor(x))
static func ce(x: float) -> int:
	return int(ceil(x))
static func sgn(x) -> int:
	return 1 if x > 0 else (-1 if x < 0 else 0)
## Math.max(...a) / Math.min(...a)
static func mx(a: Array) -> Variant:
	var m = -INF
	for x in a: if x > m: m = x
	return m
static func mn(a: Array) -> Variant:
	var m = INF
	for x in a: if x < m: m = x
	return m
## array.find(fn): the first element that passes, or null
static func _find(a: Array, f: Callable) -> Variant:
	for x in a:
		if t(f.call(x)): return x
	return null
static func _findi(a: Array, f: Callable) -> int:
	for i in a.size():
		if t(f.call(a[i])): return i
	return -1
static func _some(a: Array, f: Callable) -> bool:
	for x in a:
		if t(f.call(x)): return true
	return false
static func _every(a: Array, f: Callable) -> bool:
	for x in a:
		if not t(f.call(x)): return false
	return true
static func _filter(a: Array, f: Callable) -> Array:
	var out := []
	for x in a:
		if t(f.call(x)): out.append(x)
	return out
static func _sum(a: Array, f: Callable) -> Variant:
	var s = 0
	for x in a: s += f.call(x)
	return s
## identity tests (GDScript == compares dictionaries by value; these compare references like JS ===)
static func has_obj(a: Array, o) -> bool:
	for x in a:
		if is_same(x, o): return true
	return false
static func idx_obj(a: Array, o) -> int:
	for i in a.size():
		if is_same(a[i], o): return i
	return -1
static func without(a: Array, o) -> Array:
	var out := []
	for x in a:
		if not is_same(x, o): out.append(x)
	return out
## strict equality that never errors on mixed types (1 === '1' is false)
static func eq(a, b) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == TYPE_NIL or tb == TYPE_NIL: return ta == tb
	var na := ta == TYPE_INT or ta == TYPE_FLOAT
	var nb := tb == TYPE_INT or tb == TYPE_FLOAT
	if na and nb: return a == b
	var sa := ta == TYPE_STRING or ta == TYPE_STRING_NAME
	var sb := tb == TYPE_STRING or tb == TYPE_STRING_NAME
	if sa and sb: return String(a) == String(b)
	if ta != tb: return false
	if ta == TYPE_DICTIONARY or ta == TYPE_ARRAY: return is_same(a, b)
	return a == b
## stable sort with a JS comparator (negative: a first); returns a new array
static func ssort(a: Array, cmp: Callable) -> Array:
	if a.size() < 2: return a.duplicate()
	return _msort(a.duplicate(), cmp)
static func _msort(a: Array, cmp: Callable) -> Array:
	if a.size() <= 1: return a
	var m: int = a.size() / 2
	var l := _msort(a.slice(0, m), cmp)
	var r := _msort(a.slice(m), cmp)
	var out := []
	var i := 0
	var j := 0
	while i < l.size() and j < r.size():
		var c = cmp.call(r[j], l[i])
		if c is float and is_nan(c): c = 0
		if c < 0:
			out.append(r[j]); j += 1
		else:
			out.append(l[i]); i += 1
	out.append_array(l.slice(i))
	out.append_array(r.slice(j))
	return out
## { ...a, ...b } (shallow)
static func merged(a, b: Dictionary) -> Dictionary:
	var o: Dictionary = a.duplicate() if a is Dictionary else {}
	for k in b: o[k] = b[k]
	return o
static func gi(d, k, def = 0) -> Variant:
	if d is Dictionary and d.has(k):
		var v = d[k]
		return def if v == null else v
	return def
## string to number like JS unary + (bad text gives 0 here instead of NaN; callers treat both as 'nothing')
static func num(v) -> Variant:
	if v is int or v is float: return v
	if v is bool: return 1 if v else 0
	if v == null: return 0
	var s := String(v).strip_edges()
	if s.is_valid_int(): return s.to_int()
	if s.is_valid_float(): return s.to_float()
	return 0

# ---------------- dice ----------------
func d10() -> int: return fl(rnd.call() * 10) + 1
func d100() -> int: return fl(rnd.call() * 100) + 1
func pick(a: Array) -> Variant:
	var i := fl(rnd.call() * a.size())
	return a[i] if i < a.size() else null

# ---------------- data helpers that were functions in data.js ----------------
func cardOk(card: Dictionary, w: Dictionary) -> bool:
	var tg: Array = w.tags
	if tg.has("tele") or tg.has("alpha") or tg.has("earth") or tg.has("sunobs"): return false
	match card.el:
		"rockyOrIcy": return tg.has("rocky") or tg.has("icy")
		"notVenus": return not tg.has("venus")
		"gas": return tg.has("gas")
		"rocky": return tg.has("rocky")
		"icy": return tg.has("icy")
		"volcanic": return tg.has("volcanic")
		"severeAtm": return tg.has("severeAtm")
		"minimal": return tg.has("minimal")
		"rockyMinimal": return tg.has("rocky") and tg.has("minimal")
	return false
func combatDamage(total, strike: bool) -> int:
	if not strike:
		for p in [[4, 0], [7, 1], [10, 2], [13, 3], [15, 4], [17, 5], [19, 6], [21, 7], [23, 8], [24, 9], [25, 10]]:
			if total <= p[0]: return p[1]
		return int(min(25, total - 15))
	for p in [[6, 0], [8, 1], [10, 2], [12, 3], [15, 4], [18, 5], [21, 6], [24, 7], [27, 8], [29, 9], [31, 10]]:
		if total <= p[0]: return p[1]
	return int(min(25, 10 + ce((total - 31) / 2.0)))

# ---------------- locations ----------------
func P(loc: String) -> Dictionary:
	var a := loc.split(":")
	var ty := a[0]
	return {"t": ty, "w": a[1] if (ty == "orbit" or ty == "surf") else null, "s": a[1] if (ty == "fly" or ty == "box") else null, "n": int(a[2]) if ty == "box" else 0}
func sysOf(loc: String):
	var p := P(loc)
	if p.t == "earth": return "ear"
	if p.w != null: return W[p.w].sys
	return p.s
func worldOf(loc: String):
	var p := P(loc)
	return "ear" if p.t == "earth" else p.w
func locName(loc: String) -> String:
	var p := P(loc)
	if p.t == "earth": return "Earth"
	if p.t == "orbit": return "Earth orbit" if p.w == "ear" else W[p.w].n + " orbit"
	if p.t == "surf": return W[p.w].n + " surface"
	if p.t == "fly": return SYS[p.s].n + " flyby box"
	return SYS[p.s].n + " transfer box " + n(p.n)
func worldsIn(s) -> Array:
	return W.keys().filter(func(k): return W[k].sys == s)
func hasSurf(w) -> bool: return not W[w].tags.has("station") or w == "jup" or w == "ura"
func isGas(w) -> bool: return W[w].tags.has("gas")
func isSun(w) -> bool: return W[w].tags.has("sunobs")

# ---------------- small helpers ----------------
func glog(G: Dictionary, txt: String, c = "") -> void:
	var e := {"y": G.y, "t": txt, "c": c if c != null else ""}
	G.log.push_front(e)
	if on_log.is_valid(): on_log.call(G, e)
	if G.log.size() > 400: G.log.resize(400)
func has(G: Dictionary, k: String) -> bool: return t(G.tech.get(k))
func polLv(G: Dictionary, k: String) -> int: return int(gi(G.pol, k, 0))
func fac(G: Dictionary) -> Dictionary: return D.FAC[G.f]
func decadeRow(y: int) -> int: return 0 if y < 2060 else (1 if y < 2090 else (2 if y < 2120 else 3))
func sum(o) -> int:
	var s := 0
	for r in RES: s += int(gi(o, r, 0))
	return s
func addRes(a: Dictionary, b, k := 1) -> Dictionary:
	for r in RES: a[r] = int(gi(a, r, 0)) + k * int(gi(b, r, 0))
	return a
func enough(a, b) -> bool:
	for r in RES:
		if gi(a, r, 0) < gi(b, r, 0): return false
	return true
func resTxt(o) -> String:
	var parts := []
	for r in RES:
		if t(gi(o, r, 0)): parts.append(n(o[r]) + " " + r)
	return " + ".join(parts) if parts.size() else "nothing"
func unitData(name: String): return UNITS.get(name)

# ---------------- tech-driven values ----------------
func engBase(G) -> int: return 3 if has(G, "frig") else (4 if has(G, "uhlv") else 5)
func engRate(G, s) -> int: return engBase(G) - (int(s.sz) if s != null and s.cls == "CV" else 0)
func mult(G) -> float:
	if has(G, "hap"): return .2
	if has(G, "aam"): return .4
	if has(G, "pam"): return .5
	if has(G, "fr"): return .6
	if has(G, "ff"): return .7
	if has(G, "pm"): return .8
	if has(G, "ion"): return .9
	return 1.0
func crewRange(G) -> int:
	if has(G, "sch"): return 99
	if has(G, "dse"): return 5
	if has(G, "ccls"): return 4
	if has(G, "ldsf"): return 3
	if has(G, "als"): return 2
	if has(G, "astro"): return 1
	return 0
func recall(G) -> int:
	var r := 50
	if has(G, "asm"): r = 20
	elif has(G, "ism"): r = 25
	elif has(G, "aops"): r = 30
	elif has(G, "iops"): r = 35
	elif has(G, "ops"): r = 40
	elif has(G, "ag"): r = 45
	return r - (5 if G.f == "ru" else 0)
func malfBase(G) -> int:
	var r := 30
	if has(G, "ai"): r = 15
	elif has(G, "aqc"): r = 18
	elif has(G, "qc"): r = 21
	elif has(G, "acd"): r = 24
	elif has(G, "icd"): r = 27
	return r - (2 if G.f == "jp" else 0)
func roboBonus(G) -> int: return (3 if has(G, "ai") else (2 if has(G, "aqc") else (1 if has(G, "qc") else 0))) + (1 if polLv(G, "rob") >= 3 else 0)
func crewBonus(G) -> int: return 5 if has(G, "acv") else (3 if has(G, "aec") else (2 if has(G, "cp") else (1 if has(G, "suit") else 0)))
func weapons(G) -> int: return 5 if has(G, "ef") else (3 if has(G, "asw") else (1 if has(G, "isw") else 0))
func baseCostMod(G) -> int: return 3 if has(G, "ash") else (2 if has(G, "ish") else (1 if has(G, "hab") else 0))
func transferCap(G) -> int: return (15 if has(G, "atr") else (10 if has(G, "itr") else (5 if has(G, "tr") else 0))) + int(gi(G, "freight", 0))
func cargoMul(G) -> int: return 2 if has(G, "sht") else 1
func cvTechOk(G, sz: int) -> bool:
	if sz <= 2: return has(G, "cv")
	if sz == 3: return has(G, "lcv")
	if sz == 4: return has(G, "frig")
	if sz == 5: return has(G, "dest")
	if sz == 6: return has(G, "cru")
	return has(G, "bat")
func lvTechOk(G, z: int) -> bool: return true if z <= 2 else (has(G, "cv") if z == 3 else has(G, "uhlv"))
func lims(G) -> Array:
	var l: Array = fac(G).lim
	return [l[0] + mini(2, polLv(G, "rob")), l[1] + polLv(G, "hum"), l[2] + mini(2, polLv(G, "set"))]
func nonProbeRE(G) -> int: return G.ships.filter(func(s): return s.cls == "RE").size()
func nCV(G) -> int: return G.ships.filter(func(s): return s.cls == "CV").size()
func nBase(G) -> int: return G.bases.size()
## heliocentric transfer turns between systems, by blocks of 10
func transfer(G, a, b) -> int:
	var d: int = absi(int(SYS[a].t) - int(SYS[b].t))
	var m := mult(G)
	var tt := 0
	while d > 10:
		tt += maxi(1, rnd_i(10 * m))
		d -= 10
	tt += maxi(1, rnd_i(d * m))
	return maxi(1, tt)

# ---------------- tech markers ----------------
func drawMarker(G, f: String) -> int:
	var v: int = pick(D.TECH_POOL)
	G.mk[f].append(v)
	return v
func markerTxt(vals: Array, f: String) -> String:
	return ", ".join(vals.map(func(v): return n(v) + " " + FN[f])) if vals.size() else "no markers"

# ---------------- new game ----------------
func newGame(f: String, opts = null) -> Dictionary:
	if opts == null: opts = {}
	var F: Dictionary = D.FAC[f]
	var o2 := {"optionalEvents": false}
	for k in opts: o2[k] = opts[k]
	var G := {
		"v": 2, "f": f, "y": 2030, "phase": "move", "estep": null, "cash": F.cash, "polm": 2, "vm": 0, "mk": {"Phy": [], "Eng": [], "Bio": []}, "bank": {"Phy": 0, "Eng": 0, "Bio": 0},
		"tech": {}, "pol": {}, "rel": {}, "w": {}, "fly": {}, "cache": 0, "ships": [], "bases": [], "lv": {"earth": {1: 0, 2: 0, 3: 0, 4: 0}}, "probes": {"earth": []},
		"mis": {"pool": [], "mine": null, "common": null, "kept": [], "done": 0}, "log": [], "nid": 1, "rr": 0 if (typeof(gi(opts, "rerolls", null)) == TYPE_BOOL and not opts.rerolls) else 2, "ask": [], "alpha": {"cv": false, "re": false},
		"turn": {"moved": {}, "acted": {}, "built": {}, "terraBuys": {}}, "freight": 0, "over": false, "endYear": null, "debt": 0, "half": {},
		"opts": o2, "estock": {"ORE": 0, "SUP": 0, "FUEL": 0}, "world": null, "dipl": {},
	}
	for k in F.st: G.tech[k] = 1
	G.variant = null
	if F.has("variants"):
		var v = gi(opts, "variant", null)
		G.variant = v if (v != null and F.variants.has(v)) else F.variants.keys()[0]
	for k in (F.variants[G.variant].pol if G.variant != null else F.pol): G.pol[k] = 1
	G.t0 = G.tech.size()
	for k in D.FAC_ORDER:
		if k != f: G.rel[k] = 3
	for k in W: G.w[k] = {"v": W[k].v, "card": null, "sol": false, "life": false, "terra": 0, "npf": null, "npfTrade": null, "blk": false}
	for s in D.SYS_ORDER: G.fly[s] = {"pir": [], "ast": 0}
	# missions: undated in the pool; draw personal + common
	G.mis.pool = D.MIS.filter(func(m): return not t(m.yr)).map(func(m): return m.id)
	G.mis.mine = drawMission(G)
	G.mis.common = drawMission(G)
	# starting fleet
	for e in D.START.get(f, []):
		var cls: String = e[0]
		var name = e[1]
		var loc: String = e[2]
		if cls == "LV":
			G.lv.earth[int(name)] += 1
			continue
		var s = makeShip(G, name)
		if s == null: continue
		s.loc = loc
		s.hold = e[3] if e.size() > 3 and e[3] != null else 0
		s.launched = true
		if s.kind == "Orbiter" or s.kind == "Rover": s.fixed = loc.begins_with("orbit") or loc.begins_with("surf")
		if e.size() > 4 and t(e[4]): s.probe = e[4]
		if s.cls == "CV" and loc == "earth": s.launched = false
	if gi(opts, "scenario", null) == "fut2060":
		futuristicStart(G, F)
		return G
	glog(G, "2030: " + F.n + " begins the campaign with $" + n(F.cash) + "B. Your mission: " + misTxt(G.mis.mine) + ". Common mission: " + misTxt(G.mis.common) + ".", "g")
	startMovement(G)
	return G
## FUTURISTIC START (2060): first two tech columns (not Signs of Life / Existing Life), +$40B and $3B per 2030 starting
## technology, three policies to choose for the missed economic phases, every world's exploration value reduced by 1.
func futuristicStart(G, F) -> void:
	G.y = 2060
	G.scenario = "fut2060"
	var bonus: int = 40 + 3 * F.st.size()
	for tt in D.TECH:
		if D.TECH_POS.has(tt.k) and D.TECH_POS[tt.k][1] <= 1 and tt.k != "sol" and tt.k != "exl": G.tech[tt.k] = 1
	G.cash += bonus
	for w in G.w.values(): w.v = maxi(0, w.v - 1)
	for m in D.MIS:
		if t(m.yr) and m.yr <= 2060: placeDated(G, m, true)
	if G.mis.common == null: G.mis.common = drawMission(G)
	glog(G, "2060 (Futuristic start): " + F.n + " begins with $" + n(G.cash) + "B ($" + n(F.cash) + "B + $40B + $3B × " + n(F.st.size()) + " starting technologies) and every technology in the first two columns. All worlds' exploration values are reduced by 1. Your mission: " + misTxt(G.mis.mine) + ". Common mission: " + misTxt(G.mis.common) + ".", "g")
	G.phase = "econ"
	G.estep = "policy"
	G.policyPicked = false
	G.policyLeft = 3
	glog(G, "2060: choose policies for the three missed economic phases (2040, 2050, 2060).", "h")
func makeShip(G, name):
	var u = unitData(G.f + "|" + String(name))
	if u == null: return null
	var cv: bool = String(u.k).begins_with("CV")
	var s := {"id": G.nid, "name": u.n, "kind": "CV" if cv else u.k, "cls": "CV" if cv else "RE", "sz": int(String(u.k).substr(3)) if cv else 0,
		"ev": u.ev, "spec": u.spec, "lab": u.lab, "cap": u.cargo, "prod": u.prod, "cb": u.cb, "dr": u.dr, "cost": {"ORE": u.ore, "SUP": u.sup, "FUEL": u.fuel}, "fuel": u.fuel,
		"img": u.k + "|" + u.n, "loc": "earth", "hold": 0, "res": false, "dmg": 0, "cargo": {"ORE": 0, "SUP": 0, "FUEL": 0}, "probe": null, "fixed": false, "launched": false}
	G.nid += 1
	if s.kind == "Probe": return null
	G.ships.append(s)
	return s
func misTxt(id) -> String:
	if id == null: return "none"
	var m: Dictionary = D.MIS[int(id)]
	return W[m.w].n + (" (crewed)" if m.cv else "") + ", " + n(m.vp) + " VP"
## a dated mission token sits on its world (shared board): the first faction to deplete that world (with a crew vehicle when
## marked CV) completes it; it is not replaced. A world already at 0 cannot take it.
func placeDated(G, m, quiet := false) -> void:
	var ws = G.w.get(m.w)
	if ws == null: return
	if G.world != null and not isLead(G): return
	if ws.v < 1:
		if not quiet: glog(G, "Dated mission " + misTxt(m.id) + " is not placed: " + W[m.w].n + " is fully depleted.")
		return
	ws.dmis = m.id
## missions on a world, as this faction sees them: its own mission, the common mission, a dated mission
func missionsAt(G, w) -> Array:
	var out := []
	if G.mis.mine != null and D.MIS[G.mis.mine].w == w: out.append({"id": G.mis.mine, "kind": "mine"})
	if G.mis.common != null and D.MIS[G.mis.common].w == w: out.append({"id": G.mis.common, "kind": "common"})
	if G.w.has(w) and gi(G.w[w], "dmis", null) != null: out.append({"id": G.w[w].dmis, "kind": "dated"})
	return out
## complete a mission: +1 politics marker; keep it if there is room, otherwise the player picks a mission to return
func completeMission(G, id, label: String) -> String:
	G.polm += 1
	G.mis.done += 1
	var cap := misCap(G)
	if G.mis.kept.size() < cap:
		G.mis.kept.append(id)
		return " " + label + " mission (" + misTxt(id) + ") is complete: +1 politics marker, mission kept."
	G.vm += 1
	G.mis.kept.append(id)
	G.ask.append({"k": "mission", "opts": G.mis.kept.duplicate(), "cap": cap, "text": "Mission " + misTxt(id) + " complete, but you can keep only " + n(cap) + " mission" + ("s" if cap > 1 else "") + " this decade (+1 politics marker and +1 victory marker). Choose the mission to give up."})
	return " " + label + " mission (" + misTxt(id) + ") is complete, but you can keep only " + n(cap) + ": +1 politics marker and +1 victory marker; choose a mission to give up."
func misCap(G) -> int: return maxi(1, fl((G.y - 2020) / 10.0))
func drawMission(G):
	var ok: Array = G.mis.pool.filter(func(id): return G.w[D.MIS[id].w].v > 0 and not eq(id, G.mis.mine) and not eq(id, G.mis.common) and not G.mis.kept.has(id))
	if not ok.size(): return null
	var id = pick(ok)
	G.mis.pool = G.mis.pool.filter(func(x): return x != id)
	return id

# ---------------- phases ----------------
const PHASES := ["econ", "build", "move", "combat", "explore", "trade"]
const ESTEPS := ["politics", "initiative", "diplomacy", "production", "transport", "placement", "tech", "growth", "policy"]
const PHASE_NAME := {"econ": "Economic phase", "build": "Build & service", "move": "Movement", "combat": "Combat", "explore": "Exploration", "trade": "Trade & bases"}
const ESTEP_NAME := {"politics": "Politics & events", "initiative": "Initiative", "diplomacy": "Diplomacy", "production": "Production", "transport": "Resource transport", "placement": "Bases, asteroids & pirates", "tech": "Develop technologies", "growth": "Settlement growth", "policy": "Policy"}

func advance(G) -> bool:
	if G.over or G.ask.size(): return false
	if G.phase == "econ":
		var i := ESTEPS.find(G.estep)
		endEstep(G)
		if i < ESTEPS.size() - 1:
			G.estep = ESTEPS[i + 1]
			if G.estep == "initiative" and G.world == null: G.estep = ESTEPS[i + 2]
			startEstep(G)
			return true
		G.estep = null
		G.phase = "build"
		startBuild(G)
		return true
	var i := PHASES.find(G.phase)
	if G.phase == "move": endMovement(G)
	if G.phase == "combat": endCombat(G)
	if G.phase == "explore": endExplore(G)
	if G.phase == "trade":
		endYear(G)
		return true
	G.phase = PHASES[i + 1]
	if G.phase == "move": startMovement(G)
	if G.phase == "combat":
		startCombat(G)
		if not combatPossible(G):
			glog(G, n(G.y) + ": no combat possible (no pirates, and no embargo or war with a faction on the board); combat phase skipped.")
			G.phase = "explore"
	if G.phase == "explore": startExplore(G)
	if G.phase == "trade": startTrade(G)
	return true
func endYear(G) -> void:
	# 3.6.3 end check
	if G.y >= 2145 and not (G.world != null and not isLead(G)):
		var r := d100()
		var th: int = G.y - 2144
		if G.y >= 2169 or r <= th:
			finish(G, "The campaign reaches its final year." if G.y >= 2169 else "End-of-game roll " + n(r) + " against " + n(th) + "%: the campaign ends.")
			return
		glog(G, "End-of-game roll " + n(r) + " against " + n(th) + "%: play continues.")
	G.y += 1
	G.turn = {"moved": {}, "acted": {}, "built": {}, "terraBuys": {}, "buys": []}
	G.freight = 0
	lvReturn(G)
	# dated missions (turn track): placed on their world, open to every faction
	for m in D.MIS:
		if m.yr == G.y: placeDated(G, m)
	for m in D.MIS:
		if m.yr == G.y and G.w.has(m.w) and eq(gi(G.w[m.w], "dmis", null), m.id): glog(G, "Dated mission placed on " + W[m.w].n + ": " + misTxt(m.id) + (" (crew vehicles only)" if m.cv else "") + ". Open to every faction: the first to deplete " + W[m.w].n + " completes it.", "g")
	if G.y >= 2040 and G.y % 10 == 0:
		G.phase = "econ"
		G.estep = "politics"
		glog(G, n(G.y) + ": economic phase.", "h")
		startEstep(G)
	else:
		G.phase = "build"
		startBuild(G)

# ================= ECONOMIC PHASE =================
func startEstep(G) -> void:
	var s = G.estep
	if s == "politics":
		var extra := mini(2, polLv(G, "dip"))
		var allies: int = G.rel.values().filter(func(v): return v == 0).size()
		G.polm += 2 + extra + allies
		glog(G, "Politics: +" + n(2 + extra + allies) + " markers (2 base" + ((", " + n(extra) + " Space Diplomacy") if extra else "") + ((", " + n(allies) + " for alliances") if allies else "") + ").", "g")
		var cnt := 2 if G.y >= 2100 else 1
		var seen := {}
		for i in cnt:
			var r := d100()
			var e = _find(D.EVENTS, func(x): return r <= x[0])
			if seen.has(e[1]):
				glog(G, "Event roll " + n(r) + ": " + e[2] + " again, ignored.")
				continue
			seen[e[1]] = true
			doEvent(G, e, r)
	if s == "diplomacy":
		var cnt := 2 if G.y >= 2100 else 1
		for i in cnt:
			var r := d10()
			if r >= 8:
				glog(G, "Diplomatic drift roll " + n(r) + ": no effect.")
				continue
			var k: String = D.FAC_ORDER[r - 1]
			if k == G.f:
				for x in G.rel.keys(): setRel(G, x, toNeutral(G.rel[x]))
				glog(G, "Diplomatic drift roll " + n(r) + ": all your relations drift one step toward Neutral.")
			else:
				var b = G.rel[k]
				setRel(G, k, toNeutral(b))
				if b != G.rel[k]: glog(G, "Diplomatic drift roll " + n(r) + ": relations with " + D.FAC[k].n + " drift to " + D.REL[G.rel[k]] + ".")
				else: glog(G, "Diplomatic drift roll " + n(r) + " (" + D.FAC[k].n + "): already Neutral.")
		G.dipl = {}  # attempts queued by the UI: {fac: +n/-n}
	if s == "production": production(G)
	if s == "transport":
		G.transferLeft = transferCap(G)
		if not t(G.transferLeft): glog(G, "Resource transport needs Trade Routes; skipped.")
	if s == "placement": placement(G)
	if s == "tech":
		for f in FIELDS:
			var v: int = _sum(G.mk[f], func(x): return x)
			G.bank[f] += v
			G.mk[f] = []
		glog(G, "Tech markers converted to points: " + ", ".join(FIELDS.map(func(f): return n(G.bank[f]) + " " + FN[f])) + ".", "g")
	if s == "growth": growth(G)
	if s == "policy": G.policyPicked = false
func endEstep(G) -> void:
	var s = G.estep
	if s == "diplomacy": resolveDiplomacy(G)
	if s == "tech":
		if G.polm > 0:
			glog(G, n(G.polm) + " unconverted politics marker(s) discarded at the end of the tech step.")
			G.polm = 0
		for f in FIELDS: G.bank[f] = rnd_i(G.bank[f] / 2.0 + 1e-9)
		glog(G, "Tech bank halved: " + ", ".join(FIELDS.map(func(f): return n(G.bank[f]) + " " + FN[f])) + ".")
	if s == "policy" and not t(gi(G, "policyPicked", false)):
		var left: int = gi(G, "policyLeft", 0)
		glog(G, (n(left) + " missed policies not chosen.") if left > 1 else "No new policy chosen this decade.")
	if s == "policy": G.policyLeft = 0
func toNeutral(v: int) -> int: return v + 1 if v < 3 else (v - 1 if v > 3 else 3)
func doEvent(G, e: Array, r: int) -> void:
	var k: String = e[1]
	glog(G, "Event roll " + n(r) + ": " + e[2] + ". " + e[3], "e")
	if k == "publicity": G.ask.append({"k": "publicity", "text": "Publicity Campaign: choose a world to raise its exploration value by 2."})
	if k == "budget":
		G.cash += 5
		glog(G, "You earn $5B extra this decade.")
	if k == "miners":
		G.half.res = true
		for b in G.bases:
			if t(b.fac.mine): b.dmg.mine += 1
	if k == "research":
		G.half.tech = true
		for b in G.bases:
			if t(b.fac.lab): b.dmg.lab += 1
	if k == "dockyard":
		for b in G.bases:
			var n2 := 2
			for r2 in RES:
				var tk: int = mini(n2, b.stock[r2])
				b.stock[r2] -= tk
				n2 -= tk
			if t(b.fac.sup): b.dmg.sup += 1
	if k == "disaster":
		var wk := randomWorld()
		glog(G, "Disaster strikes " + W[wk].n + ".")
		for b in G.bases.filter(func(x): return x.w == wk):
			for c in ["lab", "mine", "sup", "def"]:
				if t(b.fac[c]): b.dmg[c] += 1
			for r2 in RES: b.stock[r2] = fl(b.stock[r2] / 2.0)
	if k == "race": glog(G, "In solo play every player is tied, so Space Race has no effect.")
	if k == "freight":
		G.freight = 5
		glog(G, "You may transfer up to 5 extra resources in the transport step.")
	if k == "immigration":
		if G.bases.size(): G.ask.append({"k": "immigration", "text": "Immigration: choose a base to receive 2 settlements."})
		else: glog(G, "You have no base, so Immigration has no effect.")
	if k == "thaw":
		for x in G.rel.keys(): setRel(G, x, toNeutral(G.rel[x]))
	if k == "survey":
		var wk := randomWorld()
		var c = drawCardFor(wk)
		if c != null:
			G.w[wk].card = c
			glog(G, "Survey Error: world card " + c + " drawn and placed on " + W[wk].n + ".")
		else: glog(G, "Survey Error: world card drawn for " + W[wk].n + ", does not apply.")
	if k == "swarm": G.extraPirate = true
	if k == "harvest": G.extraAsteroid = true
	if k == "comet": G.w.com.v += 3
	if k == "signals":
		G.w.alp.v += 4
		G.w.dsa.v += 4
	if k == "storm":
		for s in G.ships.duplicate():
			if s.loc == "earth" or atOwnBase(G, s) != null: continue
			if s.cls == "CV":
				s.dmg += 1
				glog(G, s.name + " takes solar storm damage.")
				if s.dmg >= s.sz: loseCV(G, s, "to the solar storm")
			elif d10() <= 2:
				removeShip(G, s)
				glog(G, s.name + " is destroyed by the solar storm.", "x")
func rngWorld(r: int):
	for k in W:
		var g = W[k].rng
		if g != null and r >= g[0] and r <= g[1]: return k
	return null
func randomWorld() -> String:
	var k = rngWorld(d100())
	return k if k != null else "mar"
func drawCardFor(wk: String):
	var c: Dictionary = pick(D.CARDS)
	return c.n if cardOk(c, W[wk]) else null

# diplomacy: G.dipl = {fac: delta} (positive = improve). Cost 1,2,3... markers per attempt; success on d10 <= 6
func dipCost(G) -> int:
	var m := 0
	for v in gi(G, "dipl", {}).values(): m += absi(v)
	return m * (m + 1) / 2
func setDiplomacy(G, k: String, delta: int):
	if G.estep != "diplomacy": return "Diplomacy happens in the economic phase."
	var cur: int = int(gi(G.dipl, k, 0)) + delta
	var prev = G.dipl.get(k)
	G.dipl[k] = cur
	if dipCost(G) > G.polm:
		G.dipl[k] = prev if t(prev) else 0
		var tmp: Dictionary = G.dipl.duplicate()
		tmp[k] = cur
		return "That needs " + n(dipCost({"dipl": tmp})) + " politics markers; you have " + n(G.polm) + "."
	if not t(cur): G.dipl.erase(k)
	return null
## relations are mutual: a change between two factions in play applies to both sides
func setRel(G, k: String, v: int) -> void:
	G.rel[k] = v
	var o = G.world.facs.get(k) if G.world != null else null
	if o != null and o.rel != null: o.rel[G.f] = v
func resolveDiplomacy(G) -> void:
	var cost := dipCost(G)
	if not cost: return
	G.polm -= cost
	for k in G.dipl.keys():
		var d: int = G.dipl[k]
		var net := 0
		for i in absi(d):
			var r := d10()
			if r <= 6: net += sgn(d)
		var before: int = G.rel[k]
		var nv := maxi(0, mini(5, before - net))
		if nv >= 4 and polLv(G, "mil") < 1: nv = mini(nv, 3)
		if nv >= 5 and polLv(G, "mil") < 2: nv = mini(nv, 4)
		setRel(G, k, nv)
		if nv > before and nv >= 4:
			var o = G.world.facs.get(k) if G.world != null else null
			if o != null:
				if gi(o, "aiHostile", null) == null: o.aiHostile = {}
				o.aiHostile[G.f] = G.y
				glog(o, D.FAC[G.f].n + " lowered relations with you: now " + D.REL[nv] + ".", "x")
		glog(G, "Diplomacy with " + D.FAC[k].n + ": " + n(absi(d)) + " attempt(s) " + ("to improve" if d > 0 else "to worsen") + " relations, net " + ("+" if net >= 0 else "") + n(net) + ". Now " + D.REL[nv] + (" for both sides" if G.world != null and G.world.facs.has(k) else "") + ".", "g")
	glog(G, "Diplomacy cost " + n(cost) + " politics markers.")
	G.dipl = {}

func supportCost(cnt: int, lim: int, steps: Array) -> int:
	if cnt <= lim: return lim - cnt
	var c := 0
	for i in cnt - lim: c += steps[i] if i < steps.size() else steps[steps.size() - 1]
	return -c
func production(G) -> void:
	var F := fac(G)
	var row: Array = F.pr[decadeRow(G.y)]
	var cash: int = row[0] + [0, 2, 4, 8][polLv(G, "eco")]
	var parts := ["Earth $" + n(row[0]) + "B"]
	if polLv(G, "eco"): parts.append("policy +$" + n([0, 2, 4, 8][polLv(G, "eco")]) + "B")
	var relB := 0
	for v in G.rel.values():
		if v <= 2: relB += F.rel[v][0]
	if relB:
		cash += relB
		parts.append("relations +$" + n(relB) + "B")
	var misB: int = G.mis.kept.size()
	if misB:
		cash += misB
		parts.append("missions +$" + n(misB) + "B")
	var blk: int = G.w.values().filter(func(x): return x.npf != null and t(x.blk)).size() * 2
	if blk:
		cash += blk
		parts.append("blockades +$" + n(blk) + "B")
	var fblk := 0
	if G.world != null:
		for g in G.world.facs.values(): fblk += g.bases.filter(func(b): return t(gi(b, "blk", false)) and gi(b, "blkBy", null) == G.f).size()
	fblk *= 2
	if fblk:
		cash += fblk
		parts.append("blockades of bases +$" + n(fblk) + "B")
	var pir := 0
	for f in G.fly.values(): pir += f.pir.size()
	if pir:
		cash -= pir
		G.cache += pir
		parts.append("pirates -$" + n(pir) + "B")
	var L := lims(G)
	var sup := supportCost(nonProbeRE(G), L[0], [2, 3, 4, 5]) + supportCost(nCV(G), L[1], [4, 6, 8, 10]) + supportCost(nBase(G), L[2], [4, 6, 8, 10])
	cash += sup
	parts.append("support " + ("+" if sup >= 0 else "-") + "$" + n(absi(sup)) + "B")
	if t(G.debt):
		cash -= G.debt
		parts.append("pirate debt -$" + n(G.debt) + "B")
		G.debt = 0
	G.cash += cash
	var tp := {"Phy": row[1], "Eng": row[2], "Bio": row[3]}
	if has(G, "sol"): tp.Bio += 2
	if has(G, "exl"):
		tp.Bio += 3
		tp.Phy += 2
	for f in FIELDS: G.bank[f] += tp[f]
	glog(G, "Production: " + ", ".join(parts) + " = $" + n(cash) + "B. Tech points +" + n(tp.Phy) + " Physics, +" + n(tp.Eng) + " Engineering, +" + n(tp.Bio) + " Biology.", "g")
	# bases
	for b in G.bases:
		var o = baseOutput(G, b)
		if o == null: continue
		if o.type == "tech":
			G.bank[o.field] += o.n
			glog(G, b.name + " (" + W[b.w].n + ") produces " + n(o.n) + " " + FN[o.field] + " points.", "g")
		else:
			b.stock[o.type] += o.n
			glog(G, b.name + " (" + W[b.w].n + ") produces " + n(o.n) + " " + o.type + ".", "g")
	if G.cash < 0: glog(G, "Your cash is negative ($" + n(G.cash) + "B). Scrap ships or bases to recover.", "x")
	G.half = {}
func setRow(cnt: int):
	var r = null
	for x in D.SETT:
		if cnt >= x[0]: r = x
	return r
func baseOutput(G, b, type = null):
	if type == null: type = b.out
	var w: Dictionary = W[b.w]
	var ws: Dictionary = G.w[b.w]
	var card = null
	if t(ws.card): card = _find(D.CARDS, func(c): return c.n == ws.card)
	var sr = setRow(b.set - int(gi(b, "setDmg", 0)))
	var pir: int = G.fly[w.sys].pir.size()
	if type == "tech":
		if not t(b.fac.lab): return null
		var field = card.rf if card != null else w.f
		var v: int = 3 if b.w == "ear" else (card.rv if card != null else 0)
		if b.w == "ear": field = orv(gi(b, "techField", null), "Phy")
		if v <= 0: return null
		v += (3 if b.fac.lab >= 2 else 0) + (sr[3] if sr != null else 0) + (2 if t(ws.life) else (1 if t(ws.sol) else 0)) - b.dmg.lab - pir
		if t(gi(G.half, "tech", false)): v = rnd_i(v / 2.0)
		if t(gi(b, "blk", false)): v = rnd_i(v / 2.0)
		return {"type": "tech", "field": field, "n": v} if v > 0 else null
	if not t(b.fac.mine) or b.w == "ear": return null
	var v: int = (card.prod[type] if card != null else 0) + int(gi(w.prod, type, 0))
	if v <= 0: return null
	v += D.MINE_BONUS[b.fac.mine] + (sr[2] if sr != null else 0) + (1 if G.f == "as" else 0) - b.dmg.mine - pir
	if t(gi(G.half, "res", false)): v = rnd_i(v / 2.0)
	if t(gi(b, "blk", false)): v = rnd_i(v / 2.0)
	return {"type": type, "n": v} if v > 0 else null
func bestOutput(G, b) -> String:
	var best = null
	for ty in ["tech"] + RES:
		var o = baseOutput(G, b, ty)
		if o != null and (best == null or o.n > best.n):
			best = o.duplicate()
			best.t = ty
	return best.t if best != null else "ORE"
## resource transfers (Trade Routes): from (earth|baseId) to (earth|baseId)
func transferRes(G, from, to, type: String, cnt: int):
	if G.estep != "transport": return "Transfers happen in the resource transport step."
	if cnt > G.transferLeft: return "You can transfer " + n(G.transferLeft) + " more this decade."
	var src = null if from == "earth" else _find(G.bases, func(b): return b.id == from)
	var dst = null if to == "earth" else _find(G.bases, func(b): return b.id == to)
	if src != null and src.stock[type] < cnt: return src.name + " has only " + n(src.stock[type]) + " " + type + "."
	if src == null and G.cash < earthCash(G, {type: cnt}): return "Sending " + n(cnt) + " " + type + " from Earth costs " + earthCostTxt(G, {type: cnt}) + "."
	for b in [src, dst]:
		if b != null and G.fly[W[b.w].sys].pir.size(): return "A pirate in the " + SYS[W[b.w].sys].n + " flyby box blocks transfers there."
	if src != null: src.stock[type] -= cnt
	else: payEarth(G, {type: cnt})
	if dst != null: dst.stock[type] += cnt
	else: estock(G)[type] += cnt
	G.transferLeft -= cnt
	glog(G, "Transferred " + n(cnt) + " " + type + " from " + (src.name if src != null else "Earth") + " to " + (dst.name if dst != null else "Earth (faction board)") + ".")
	return null
## an NPF base takes one of its faction's base names (not one already on the board)
func npfName(G, w):
	var x = G.w.get(w)
	if x == null or not t(x.npf): return null
	if t(gi(x, "npfName", null)): return x.npfName
	var used := {}
	for y in G.w.values():
		if t(gi(y, "npfName", null)): used[y.npfName] = true
	for b in allBases(G): used[b.name] = true
	var names: Array = D.BASE_NAMES.get(x.npf, ["Outpost"])
	var free := names.filter(func(nn): return not used.has(nn))
	x.npfName = pick(free) if free.size() else names[0]
	return x.npfName
## optional rule: enhanced trading. A trade marker stays until every faction in play has traded there once
## (traders are listed on it); markers left at the next placement step are replaced with new ones
func enhTrade(G) -> bool: return t(gi(G.opts, "enhTrade", false))
func facsInPlay(G) -> Array: return G.world.facs.keys() if G.world != null else [G.f]
func _tm() -> Dictionary:
	var side = pick(["buy", "sell"])
	return {"side": side, "type": pick(RES)}
func placement(G) -> void:
	var dec: int = fl(G.y / 10.0) * 10
	if G.world != null and not isLead(G):
		for b in G.bases:
			if b.set > 0 and not t(gi(b, "blk", false)) and (not t(b.trade) or enhTrade(G)): b.trade = _tm()
		return
	var r := d100()
	var wk = rngWorld(r)
	if wk != null and t(SYS[W[wk].sys].dec) and SYS[W[wk].sys].dec <= dec and not t(G.w[wk].npf) and t(W[wk].base):
		var npf = pick(npfKeys(G))
		if npf == null: glog(G, "NPF base roll " + n(r) + ": no non-player faction to found it.")
		else:
			G.w[wk].npf = npf
			G.w[wk].npfName = null
			npfName(G, wk)
			glog(G, "NPF base roll " + n(r) + ": " + D.FAC[npf].n + " founds the base " + G.w[wk].npfName + " at " + W[wk].n + ".", "e")
	else: glog(G, "NPF base roll " + n(r) + ": no new base.")
	if G.y >= 2050:
		var cnt := 2 if G.y >= 2100 else 1
		for i in cnt:
			_place(G, "Asteroid", dec)
			_place(G, "Pirate", dec)
		if t(gi(G, "extraAsteroid", false)): _place(G, "Asteroid", dec)
		if t(gi(G, "extraPirate", false)): _place(G, "Pirate", dec)
	G.extraAsteroid = false
	G.extraPirate = false
	# trade markers: NPF bases and player bases with settlements
	var enh := enhTrade(G)
	var rep := 0
	for k in G.w.keys():
		var x = G.w[k]
		if t(x.npf) and not t(x.blk) and (not t(x.npfTrade) or enh):
			if t(x.npfTrade): rep += 1
			x.npfTrade = _tm()
			npfName(G, k)
	for b in G.bases:
		if b.set > 0 and not t(gi(b, "blk", false)) and (not t(b.trade) or enh): b.trade = _tm()
	if enh and rep: glog(G, "Enhanced trading: " + n(rep) + " unused NPF trade marker(s) replaced with new ones.")
func _place(G, what: String, dec: int) -> void:
	var r2 := d100()
	var k = rngWorld(r2)
	if k == null: return
	var s: String = W[k].sys
	if not t(SYS[s].dec) or SYS[s].dec > dec:
		glog(G, what + " roll " + n(r2) + ": " + SYS[s].n + " is not open yet.")
		return
	if what == "Pirate":
		G.fly[s].pir.append({"strong": G.y >= 2120, "dmg": 0})
		G.cache += 5
		glog(G, "Pirate roll " + n(r2) + ": a pirate appears in the " + SYS[s].n + " flyby box (+$5B to the pirate cache).", "x")
	else:
		G.fly[s].ast += 1
		glog(G, "Asteroid roll " + n(r2) + ": an asteroid enters the " + SYS[s].n + " flyby box.", "e")
func growth(G) -> void:
	for b in G.bases:
		if not t(b.set): continue
		var full: int = b.set / 10
		var rem: int = b.set % 10
		var r := d10()
		if polLv(G, "set") >= 3: r = mini(r, d10())
		var gain: int = full + (1 if rem and r <= rem else 0)
		if gain and t(gi(b, "blk", false)):
			var l: int = mini(b.set, gain)
			b.set -= l
			glog(G, b.name + " is blockaded: " + n(l) + " settlement(s) lost, down to " + n(b.set) + ".", "x")
		elif gain:
			b.set += gain
			glog(G, b.name + " grows by " + n(gain) + " settlement(s) to " + n(b.set) + ".", "g")
## cost = chart cost, -3 for each other faction that has the technology (the non-player factions keep their starting
## technologies in solo play), China -4 each instead; North America -2 when it is the first to have it; minimum 5
func techHolders(G, tt) -> Array:
	return D.FAC.keys().filter(func(f):
		if f == G.f: return false
		if G.world != null and G.world.facs.has(f): return t(G.world.facs[f].tech.get(tt.k))
		return D.FAC[f].get("st", []).has(tt.k))
func techCost(G, tt) -> int:
	var h := techHolders(G, tt).size()
	return maxi(5, tt.c - h * (4 if G.f == "cn" else 3) - (2 if G.f == "na" and not h else 0))
func techCostTxt(G, tt) -> String:
	var h := techHolders(G, tt)
	var per := 4 if G.f == "cn" else 3
	var parts := ["chart " + n(tt.c)]
	if h.size(): parts.append("-" + n(h.size() * per) + " (" + ", ".join(h.map(func(f): return D.FAC[f].n)) + " " + ("have" if h.size() > 1 else "has") + " it)")
	if G.f == "na" and not h.size(): parts.append("-2 (first to develop it)")
	var raw: int = tt.c - h.size() * per - (2 if G.f == "na" and not h.size() else 0)
	return " ".join(parts) + (", minimum 5" if raw < 5 else "")
func techState(G, tt) -> String:
	if t(G.tech.get(tt.k)): return "have"
	if _some(tt.r, func(x): return not t(G.tech.get(x))): return "locked"
	if tt.k == "sol" and not _some(G.w.values(), func(w): return t(w.sol)): return "locked"
	if tt.k == "exl" and not _some(G.w.values(), func(w): return t(w.life)): return "locked"
	return "open"
# ---- research turns (3.1.7, multi-faction games): one at a time in reverse initiative order, each faction develops
# one technology or passes; a faction that passes is out for the rest of the step; repeat until everyone has passed
func techRT(world) -> Dictionary:
	var H = world.facs[world.meta.human]
	var key: String = n(H.y) + ":tech"
	var rt = gi(world.meta, "rt", null)
	if rt == null or rt.key != key:
		var seq: Array = world.meta.order.duplicate()
		seq.reverse()
		world.meta.rt = {"key": key, "seq": seq, "i": 0, "round": 1, "passed": {}}
	return world.meta.rt
## whose research turn it is (faction key), or null when everyone has passed
func techTurn(world):
	var rt := techRT(world)
	var cnt: int = rt.seq.size()
	for j in cnt:
		var f = rt.seq[(rt.i + j) % cnt]
		if not t(rt.passed.get(f)) and not t(world.facs[f].over):
			if j and rt.i + j >= cnt: rt.round += 1
			rt.i = (rt.i + j) % cnt
			return f
	return null
func techNext(world) -> void:
	var rt := techRT(world)
	rt.i += 1
	if rt.i >= rt.seq.size():
		rt.i = 0
		rt.round += 1
func rtOn(G) -> bool: return G.world != null and G.estep == "tech" and G.phase == "econ"
func techPass(G):
	if not rtOn(G): return "Not in the research turns."
	var w = G.world
	var rt := techRT(w)
	if t(rt.passed.get(G.f)): return null
	if techTurn(w) != G.f: return "It is " + D.FAC[techTurn(w)].n + "'s research turn."
	rt.passed[G.f] = 1
	techNext(w)
	glog(w.facs[w.meta.human], "Research round " + n(rt.round) + ": " + D.FAC[G.f].n + (" (you)" if G.f == w.meta.human else "") + " passes and develops no more technologies this decade.")
	return null
func develop(G, k: String):
	var tt: Dictionary = D.TECHK[k]
	if G.estep != "tech": return "Technologies are developed in the economic phase tech step."
	if rtOn(G):
		var w = G.world
		var cur = techTurn(w)
		if t(techRT(w).passed.get(G.f)): return "You passed; you cannot develop more technologies this decade."
		if cur != G.f: return "Wait for your research turn (" + ((D.FAC[cur].n + " is researching") if cur != null else "everyone has passed") + ")."
	if techState(G, tt) != "open":
		var miss: Array = tt.r.filter(func(x): return not t(G.tech.get(x))).map(func(x): return D.TECHK[x].n)
		return tt.n + " needs " + (", ".join(miss) if miss.size() else "signs of life to have been found") + "."
	var c := techCost(G, tt)
	if G.bank[tt.f] < c: return tt.n + " costs " + n(c) + " " + FN[tt.f] + " points; you have " + n(G.bank[tt.f]) + "."
	G.bank[tt.f] -= c
	G.tech[k] = 1
	glog(G, "Developed " + tt.n + " for " + n(c) + " " + FN[tt.f] + " points: " + tt.d + ".", "g")
	if rtOn(G):
		var w = G.world
		glog(w.facs[w.meta.human], "Research round " + n(techRT(w).round) + ": " + D.FAC[G.f].n + (" (you)" if G.f == w.meta.human else "") + " develops " + tt.n + " (" + n(c) + " " + FN[tt.f] + ").", "" if G.f == w.meta.human else "bot")
		techNext(w)
	return null
func convertPolitics(G, to: String):  # to: 'cash' | field
	if G.polm < 1: return "No politics markers left."
	if to != "cash" and not FIELDS.has(to): return "Unknown conversion."
	G.polm -= 1
	var v := 3 if polLv(G, "dip") >= 3 else 2
	if to == "cash": G.cash += 1
	else: G.bank[to] += v
	glog(G, "Converted 1 politics marker to " + ("$1B" if to == "cash" else n(v) + " " + FN[to] + " points") + ".")
	return null
func buyVictory(G):
	if G.polm < 4: return "A victory marker costs 4 politics markers."
	G.polm -= 4
	G.vm += 1
	glog(G, "Bought a victory marker with 4 politics markers.", "g")
	return null
func redrawMission(G):
	if G.polm < 2: return "Redrawing a mission costs 2 politics markers."
	if G.mis.mine == null: return "You have no mission to redraw."
	G.polm -= 2
	G.mis.pool.append(G.mis.mine)
	G.mis.mine = drawMission(G)
	glog(G, "Mission redrawn: " + misTxt(G.mis.mine) + ".")
	return null
func tradePoints(G, f: String, dir: String):  # Genetic Engineering / Matter-Energy Conversion / Nano-Technology
	var k: String = {"Bio": "gen", "Phy": "mec", "Eng": "nano"}[f]
	if not has(G, k): return "You need " + D.TECHK[k].n + "."
	if dir == "buy":
		if G.cash < 1: return "Not enough cash."
		G.cash -= 1
		G.bank[f] += 1
	else:
		if G.bank[f] < 2: return "Not enough points."
		G.bank[f] -= 2
		G.cash += 1
	return null
func choosePolicy(G, k: String):
	if G.estep != "policy": return "Policies are chosen in the policy step."
	if t(gi(G, "policyPicked", false)): return "You already chose a policy this decade."
	var lv := polLv(G, k)
	if lv >= 3: return "That policy is already Unified."
	if lv == 2 and G.pol.values().has(3): return "You can hold only one Unified policy."
	if _sum(G.pol.values(), func(x): return x) >= 10: return "You already hold 10 policies."
	G.pol[k] = lv + 1
	if int(gi(G, "policyLeft", 0)) > 0:
		G.policyLeft -= 1
		G.policyPicked = G.policyLeft <= 0
	else: G.policyPicked = true
	var p = _find(D.POL, func(x): return x.k == k)
	glog(G, "Adopted " + D.POL_LV[lv] + p.n + ": " + p.d[lv] + ".", "g")
	return null

# ================= BUILD & SERVICE =================
func startBuild(G) -> void: glog(G, n(G.y) + ": build and service ships.", "h")
## buildable list at a location (earth or base id)
func buildOptions(G, where) -> Array:
	var out := []
	var base = null if where == "earth" else _find(G.bases, func(b): return b.id == where)
	var supLv: int = (base.fac.sup - (1 if t(base.dmg.sup) else 0)) if base != null else 4
	var inUse := {}
	for s in G.ships: inUse[s.name] = true
	for arr in G.probes.values():
		for nn in arr: inUse[nn] = true
	for s in G.ships:
		if t(s.probe): inUse[s.probe] = true
	for k in UNITS.keys():
		if not String(k).begins_with(G.f + "|"): continue
		var u: Dictionary = UNITS[k]
		var cv: bool = String(u.k).begins_with("CV")
		var sz: int = int(String(u.k).substr(3)) if cv else 0
		var why = null
		if inUse.has(u.n): why = "in service"
		elif cv and not cvTechOk(G, sz): why = "needs " + ("Crew Vehicles" if sz <= 2 else ("Large Crew Vehicles" if sz == 3 else ("Frigates" if sz == 4 else ("Destroyers" if sz == 5 else ("Cruisers" if sz == 6 else "Battleships")))))
		elif base == null and cv and sz > 4 and not has(G, "elev"): why = "too large to build on Earth"
		elif base != null and ((supLv < 4) if (cv and sz > 2) else (supLv < 3)): why = "needs a large Spaceport" if (cv and sz > 2) else "needs a Spaceport"
		var cost := {"ORE": u.ore, "SUP": u.sup, "FUEL": u.fuel}
		out.append({"key": k, "u": u, "cost": cost, "why": why, "kind": u.k, "cv": cv, "sz": sz})
	return out
## Earth: resources on the faction board are used first, the rest is bought at $1B each. Bases only use their own resources.
func estock(G) -> Dictionary:
	if not t(gi(G, "estock", null)): G.estock = {"ORE": 0, "SUP": 0, "FUEL": 0}
	return G.estock
func earthCash(G, cost) -> int:
	var st := estock(G)
	var a := 0
	for r in RES: a += maxi(0, int(gi(cost, r, 0)) - int(st[r]))
	return a
func payEarth(G, cost) -> Dictionary:
	var used := {}
	var st := estock(G)
	var cash := 0
	for r in RES:
		var need := int(gi(cost, r, 0))
		var u := mini(need, st[r])
		used[r] = u
		st[r] -= u
		cash += need - u
	G.cash -= cash
	return {"used": used, "cash": cash}
func unpayEarth(G, paid) -> void:
	addRes(estock(G), paid.used)
	G.cash += paid.cash
func earthCostTxt(G, cost) -> String:
	var st := estock(G)
	var fromSt := []
	for r in RES:
		if mini(int(gi(cost, r, 0)), st[r]) > 0: fromSt.append(n(mini(cost[r], st[r])) + " " + r)
	var cash := earthCash(G, cost)
	var parts := []
	if fromSt.size(): parts.append(" + ".join(fromSt) + " from the faction board")
	if cash: parts.append("$" + n(cash) + "B")
	return " + ".join(parts) if parts.size() else "free"
func _baseById(G, id):
	return _find(G.bases, func(b): return eq(b.id, id))
func payable(G, where, cost) -> bool:
	return G.cash >= earthCash(G, cost) if where == "earth" else enough(_baseById(G, where).stock, cost)
func pay(G, where, cost) -> Dictionary:
	if where == "earth": return payEarth(G, cost)
	addRes(_baseById(G, where).stock, cost, -1)
	return {"cost": cost.duplicate()}
## remember a purchase of this build phase so it can be refunded (planning: buy, look, take it back)
func _noteBuy(G, rec: Dictionary) -> void:
	if not G.turn.has("buys"): G.turn.buys = []
	G.nid2 = int(gi(G, "nid2", 0)) + 1
	rec.uid = G.nid2
	G.turn.buys.append(rec)
## purchases of this build phase that can still be taken back
func refundable(G) -> Array:
	if G.phase != "build" or not G.turn.has("buys"): return []
	return G.turn.buys
func refundBuy(G, uid):
	if G.phase != "build": return "Purchases can only be refunded during the build & service phase."
	var e = _find(refundable(G), func(b): return eq(b.uid, uid))
	if e == null: return "That purchase can no longer be refunded."
	var what := ""
	match e.k:
		"ship":
			var sh = _find(G.ships, func(x): return eq(x.id, e.sid))
			if sh == null: return "That ship is gone, so it cannot be refunded."
			if sum(sh.cargo) > 0: return sh.name + " carries cargo: unload it before refunding."
			removeShip(G, sh)
			what = sh.name
		"probe":
			var lst: Array = G.probes.get(e.loc, [])
			var i := lst.find(e.name)
			if i < 0: return "That probe has already been used."
			lst.remove_at(i)
			what = "probe " + String(e.name)
		"lv":
			var st = G.lv.get(e.where)
			if st == null or int(gi(st, e.z, 0)) < 1: return "That launch vehicle has already been used."
			st[e.z] -= 1
			what = "LV-" + n(e.z)
	if e.where == "earth": unpayEarth(G, e.paid)
	else: addRes(_baseById(G, e.where).stock, e.paid.cost)
	G.turn.buys = without(G.turn.buys, e)
	glog(G, "Refunded " + what + ": " + (earthRefundTxt(e.paid) if e.where == "earth" else resTxt(e.paid.cost)) + " returned.")
	return null
func earthRefundTxt(paid) -> String:
	var parts := []
	var r := resTxt(paid.used)
	if r != "none" and r != "nothing" and r != "": parts.append(r + " to the faction board")
	if int(paid.cash) > 0: parts.append("$" + n(paid.cash) + "B")
	return " + ".join(parts) if parts.size() else "nothing"
func buildUnit(G, key: String, where, reserved := false):
	if G.phase != "build": return "Ships are built in the build & service phase."
	var opt = _find(buildOptions(G, where), func(o): return o.key == key)
	if opt == null: return "Unknown unit."
	if opt.why != null: return opt.u.n + ": " + opt.why + "."
	var cost: Dictionary = opt.cost.duplicate()
	if reserved and opt.cv:
		cost.SUP = maxi(0, cost.SUP - 1)
		cost.FUEL = maxi(0, cost.FUEL - 1)
	var L := lims(G)
	if opt.cv and nCV(G) >= L[1] + 4: return "You are already 4 crew vehicles over your support limit."
	if not opt.cv and opt.kind != "Probe" and nonProbeRE(G) >= L[0] + 4: return "You are already 4 robotic explorers over your support limit."
	if not payable(G, where, cost): return opt.u.n + " costs " + (earthCostTxt(G, cost) if where == "earth" else resTxt(cost)) + "."
	var paidTxt := earthCostTxt(G, cost) if where == "earth" else resTxt(cost)
	var paid: Dictionary = pay(G, where, cost)
	var loc: String = "earth" if where == "earth" else baseLoc(_baseById(G, where))
	if opt.kind == "Probe":
		if not G.probes.has(loc): G.probes[loc] = []
		G.probes[loc].append(opt.u.n)
		_noteBuy(G, {"k": "probe", "where": where, "paid": paid, "loc": loc, "name": opt.u.n})
	else:
		var s = makeShip(G, opt.u.n)
		s.loc = loc
		s.res = reserved and opt.cv
		s.built = G.y
		_noteBuy(G, {"k": "ship", "where": where, "paid": paid, "sid": s.id})
	glog(G, "Built " + opt.kind + " " + opt.u.n + (" (reserved)" if reserved and opt.cv else "") + " at " + ("Earth" if where == "earth" else _baseById(G, where).name) + " for " + paidTxt + ".", "g")
	return null
# two-sided LV counters. A faction has c13 LV-1/LV-3 counters, c24 LV-2/LV-4 counters, and (North America) c14 LV-1/LV-4.
# LV-1s always use the LV-1/LV-4 counter first (North America's first LV-1 is the one with LV-4 on its back).
# k = LV-1s showing on LV-1/LV-4 counters. Tracked in G.lv14 / G.lvN1.
func _lvc(G, key: String) -> int: return int(gi(fac(G).lvs, key, 0))
func lvK(G) -> int:
	var c14 := _lvc(G, "14")
	var c24 := _lvc(G, "24")
	var c := lvCount(G)
	if not c14: return 0
	var lv14: int = gi(G, "lv14", 0)
	var k := mini(lv14, c[1])
	var prev: int = gi(G, "lvN1", 0)
	if c[1] < prev:
		var gone: int = prev - c[1]
		var on13: int = prev - lv14
		gone -= mini(gone, maxi(0, on13))
		k = maxi(0, mini(c[1], lv14 - gone))
	var add: int = c[1] - maxi(prev, k)
	while add > 0:
		if k < c14 and c[2] + c[4] <= c24 + c14 - k - 1: k += 1
		add -= 1
	G.lv14 = k
	G.lvN1 = c[1]
	return k
func lvSplit(G, c: Dictionary) -> int:
	var c13 := _lvc(G, "13")
	var c14 := _lvc(G, "14")
	var c24 := _lvc(G, "24")
	var k := lvK(G)
	# the LV-1 being added takes a free LV-1/LV-4 counter if there is one
	var cur := lvCount(G)
	if c[1] > cur[1] and k < c14 and cur[2] + cur[4] <= c24 + c14 - k - 1: k += 1
	return k if (c[1] - k + c[3] <= c13 and c[2] <= c24 and c[2] + c[4] <= c24 + c14 - k) else -1
func lvFits(G, c) -> bool: return lvSplit(G, c) >= 0
func lvCanAdd(G, z: int) -> bool:
	var c := lvCount(G)
	c[z] += 1
	return lvFits(G, c)
func lvPoolTxt(G) -> String:
	var c13 := _lvc(G, "13")
	var c14 := _lvc(G, "14")
	var c24 := _lvc(G, "24")
	var c := lvCount(G)
	var on14 := lvK(G)
	var parts := ["LV-1/LV-3 counters: " + n(c13) + " (" + n(c[1] - on14) + " as LV-1, " + n(c[3]) + " as LV-3)"]
	if c14: parts.append("LV-1/LV-4 counter: " + n(c14) + " (" + ("in use as LV-1" if on14 else ("in use as LV-4" if c[4] > c24 - c[2] else "free")) + ")")
	parts.append("LV-2/LV-4 counters: " + n(c24) + " (" + n(c[2]) + " as LV-2, " + n(mini(c[4], c24 - c[2])) + " as LV-4)")
	return "; ".join(parts)
func lvCount(G) -> Dictionary:
	var c := {1: 0, 2: 0, 3: 0, 4: 0}
	for L in [G.lv, gi(G, "lvCool", {})]:
		for st in L.values():
			for z in [1, 2, 3, 4]: c[z] += int(gi(st, z, 0))
	return c
func _lvSlot() -> Dictionary: return {1: 0, 2: 0, 3: 0, 4: 0}
func lvRecover(G, key: String, z: int) -> void:
	if gi(G, "lvCool", null) == null: G.lvCool = {}
	if not G.lvCool.has(key): G.lvCool[key] = _lvSlot()
	G.lvCool[key][z] += 1
func lvReturn(G) -> void:
	for k in gi(G, "lvCool", {}).keys():
		var st = G.lvCool[k]
		if not G.lv.has(k): G.lv[k] = _lvSlot()
		for z in [1, 2, 3, 4]: G.lv[k][z] += int(gi(st, z, 0))
	G.lvCool = {}
func buildLV(G, z: int, where):
	if G.phase != "build": return "Launch vehicles are built in the build & service phase."
	if not lvTechOk(G, z): return "LV-3 needs Crew Vehicles." if z == 3 else "LV-4 needs Ultra-Heavy Launch Vehicles."
	if not lvCanAdd(G, z): return "No free counter for an LV-" + n(z) + ": " + ("LV-1 and LV-3" if (z == 1 or z == 3) else "LV-2 and LV-4") + " share two-sided counters, and all that can show LV-" + n(z) + " are in use."
	var base = null if where == "earth" else _baseById(G, where)
	if base != null and base.fac.sup - (1 if t(base.dmg.sup) else 0) < (1 if z <= 2 else 2): return "LV-" + n(z) + " needs a " + ("small" if z <= 2 else "large") + " Supply Station."
	var cost := {"ORE": 1, "FUEL": z}
	if not payable(G, where, cost): return "LV-" + n(z) + " costs " + (earthCostTxt(G, cost) if where == "earth" else resTxt(cost)) + "."
	var paid: Dictionary = pay(G, where, cost)
	var key: String = "earth" if where == "earth" else where
	if not G.lv.has(key): G.lv[key] = _lvSlot()
	G.lv[key][z] += 1
	_noteBuy(G, {"k": "lv", "where": key, "paid": paid, "z": z})
	glog(G, "Built LV-" + n(z) + " at " + (base.name if base != null else "Earth") + ".")
	return null
## where a CV can be unreserved/repaired: returns {where, level}
func serviceSite(G, s):
	if s.loc == "earth" or (s.loc == "orbit:ear" and has(G, "elev")): return {"where": "earth", "level": 4}
	var b = atOwnBase(G, s)
	if b == null: return null
	return {"where": b.id, "level": b.fac.sup - (1 if t(b.dmg.sup) else 0)}
func unreserveLevel(sz: int) -> int: return 1 if sz <= 2 else (2 if sz == 3 else (3 if sz <= 5 else 4))
const SITE_NAMES := ["", "small Supply Station", "large Supply Station", "small Spaceport", "large Spaceport"]
## can this reserved crew vehicle be unreserved where it is? {ok, where, cost, why}
func unreserveInfo(G, s) -> Dictionary:
	if s.cls != "CV" or not t(s.res): return {"ok": false, "why": s.name + " is not reserved."}
	var site = serviceSite(G, s)
	var cost := {"SUP": 1, "FUEL": 1}
	if site == null: return {"ok": false, "why": "Crew vehicles in Earth orbit must land on Earth to be unreserved (Space Elevator lets them stay in orbit)." if s.loc == "orbit:ear" else s.name + " must be landed on Earth or at one of your bases with a Supply Station or Spaceport."}
	if site.level < unreserveLevel(s.sz): return {"ok": false, "why": s.name + " (CV-" + n(s.sz) + ") needs a " + SITE_NAMES[unreserveLevel(s.sz)] + " at " + _baseById(G, site.where).name + "."}
	var where: String = "Earth" if site.where == "earth" else _baseById(G, site.where).name
	if not payable(G, site.where, cost): return {"ok": false, "where": where, "why": ("Unreserving costs " + earthCostTxt(G, cost) + ".") if site.where == "earth" else ("Unreserving costs 1 SUP and 1 FUEL from " + where + "'s stock.")}
	return {"ok": true, "where": where, "cost": cost, "costTxt": earthCostTxt(G, cost) if site.where == "earth" else "1 SUP + 1 FUEL from " + where + "'s stock"}
func unreserve(G, s):
	if G.phase != "build": return "Crew vehicles are unreserved in the build & service phase."
	if not t(s.res): return s.name + " is not reserved."
	var site = serviceSite(G, s)
	if site == null: return s.name + " must be at Earth or one of your bases with a Supply Station or Spaceport."
	if site.level < unreserveLevel(s.sz): return s.name + " needs a " + SITE_NAMES[unreserveLevel(s.sz)] + "."
	var cost := {"SUP": 1, "FUEL": 1}
	if not payable(G, site.where, cost): return ("Unreserving costs " + earthCostTxt(G, cost) + ".") if site.where == "earth" else "Unreserving costs 1 SUP and 1 FUEL."
	pay(G, site.where, cost)
	s.res = false
	glog(G, s.name + " returns to active service.", "g")
	return null
func repair(G, s):
	if G.phase != "build": return "Repairs happen in the build & service phase."
	if not t(s.dmg): return s.name + " has no damage."
	var site = serviceSite(G, s)
	if site == null or site.level < 1: return s.name + " must be at Earth or a base with a Supply Station or Spaceport."
	var cap: int = [0, 1, 2, 3, 99][site.level]
	var k: int = mini(s.dmg, cap)
	var cost := {"ORE": k}
	if not payable(G, site.where, cost): return "Repairing " + n(k) + " damage costs " + (earthCostTxt(G, cost) if site.where == "earth" else n(k) + " ORE") + "."
	pay(G, site.where, cost)
	s.dmg -= k
	glog(G, "Repaired " + n(k) + " damage on " + s.name + ".")
	return null
func setReserve(G, s):
	if G.phase != "build": return "You can reserve a crew vehicle at the start of a turn."
	if s.cls != "CV" or t(s.res): return null
	s.res = true
	glog(G, s.name + " is placed in reserve.")
	return null
## optional rule (G.opts.scrapRE): robotic explorers and launch vehicles can be scrapped at your bases and on Earth like crew vehicles
func scrapRule(G) -> bool: return true  # scrapping robotic explorers and launch vehicles is always allowed
func scrapSite(G, s):
	if s.cls == "RE":
		# telescopes (Earth orbit) and unlaunched explorers scrap on Earth; orbiters over a world with your base and
		# rovers on the surface with your surface base scrap at that base
		if not scrapRule(G): return null
		if s.loc == "earth" or (s.kind == "Telescope" and s.loc == "orbit:ear"): return {"where": "earth"}
		var p := P(s.loc)
		if s.kind == "Orbiter" and p.t == "orbit":
			var b = _find(G.bases, func(x): return x.w == p.w)
			return {"where": b.id} if b != null else null
		if s.kind == "Rover" and p.t == "surf":
			var b = _find(G.bases, func(x): return baseLoc(x) == s.loc)
			return {"where": b.id} if b != null else null
		return null
	return serviceSite(G, s)
func halfOf(cost) -> Dictionary:
	var o := {}
	for r in RES: o[r] = rnd_i(gi(cost, r, 0) / 2.0)
	return o
## what scrapping this ship would return (null if it would only be destroyed)
func scrapValue(G, s):
	var site = null if (s.cls == "CV" and t(s.dmg)) else scrapSite(G, s)
	if site == null: return null
	var c: Dictionary = s.cost.duplicate()
	if t(s.res):
		c.SUP = maxi(0, int(gi(c, "SUP", 0)) - 1)
		c.FUEL = maxi(0, int(gi(c, "FUEL", 0)) - 1)
	return {"site": site, "back": halfOf(c), "cargo": s.cargo.duplicate() if s.cargo != null else {}}
func refundHalf(G, where, cost) -> String:
	var back := halfOf(cost)
	if where == "earth":
		addRes(estock(G), back)
		return "recovered " + resTxt(back) + " to the faction board"
	addRes(_baseById(G, where).stock, back)
	return "recovered " + resTxt(back)
func scrap(G, s):
	# only undamaged crew vehicles can be scrapped; a damaged one is simply destroyed
	var site = null if (s.cls == "CV" and t(s.dmg)) else scrapSite(G, s)
	if site != null:
		var c: Dictionary = s.cost.duplicate()
		if t(s.res):
			c.SUP = maxi(0, int(gi(c, "SUP", 0)) - 1)
			c.FUEL = maxi(0, int(gi(c, "FUEL", 0)) - 1)
		glog(G, s.name + " scrapped at " + ("Earth" if site.where == "earth" else _baseById(G, site.where).name) + "; " + refundHalf(G, site.where, c) + ".")
		if t(s.probe) and site.where == "earth":
			if not G.probes.has("earth"): G.probes.earth = []
			G.probes.earth.append(s.probe)
	else: glog(G, s.name + " is " + ("decommissioned" if s.cls == "CV" else "destroyed") + ".")
	addRes(cargoDump(G, s), s.cargo if s.cargo != null else {})
	removeShip(G, s)
	return null
func scrapLV(G, where, z: int):
	if not scrapRule(G): return "Scrapping launch vehicles is an optional rule (turn it on in Settings before starting a campaign)."
	var st = G.lv.get(where)
	if st == null or not t(gi(st, z, 0)): return "No LV-" + n(z) + " ready at " + ("Earth" if where == "earth" else "that base") + "."
	st[z] -= 1
	glog(G, "LV-" + n(z) + " scrapped at " + ("Earth" if where == "earth" else _baseById(G, where).name) + "; " + refundHalf(G, where, {"ORE": 1, "FUEL": z}) + ". Its counter is free again.")
	return null
func cargoDump(G, s) -> Dictionary:
	if s.loc == "earth": return estock(G)
	var b = atOwnBase(G, s)
	return b.stock if b != null else {}
func removeShip(G, s) -> void: G.ships = without(G.ships, s)
func loseCV(G, s, why: String) -> void:
	removeShip(G, s)
	var cnt := 5 if s.sz >= 3 else 3
	var got := []
	for i in cnt: got.append(drawMarker(G, "Eng"))
	glog(G, s.name + " is lost " + why + ". Lessons learned: " + markerTxt(got, "Eng") + ".", "x")
func loseRE(G, s, why: String) -> void:
	removeShip(G, s)
	var v := drawMarker(G, "Eng")
	glog(G, s.kind + " " + s.name + ((" and probe " + s.probe) if t(s.probe) else "") + " " + why + ". Lessons learned: " + n(v) + " Engineering.", "x")

# ================= MOVEMENT =================
func startMovement(G) -> void:
	# 3.3.1 drop ships in transfer boxes
	for s in G.ships:
		var p := P(s.loc)
		if p.t != "box": continue
		if s.hold > 0:
			s.hold -= 1
			continue
		s.loc = ("box:" + p.s + ":" + n(p.n - 1)) if p.n > 1 else ("fly:" + p.s)
		if p.n == 1: glog(G, s.name + " arrives in the " + SYS[p.s].n + " flyby box.")
	if G.y > 2030 or G.phase != "move": glog(G, n(G.y) + ": movement. Ships in transfer boxes have moved one box closer.", "h")
func endMovement(G) -> void:
	for s in G.ships:
		if P(s.loc).t == "fly" and s.kind == "Flyby": s.flyArrive = G.y
func atOwnBase(G, s):
	var w = worldOf(s.loc)
	var pt: String = P(s.loc).t
	if w == null or pt == "fly" or pt == "box": return null
	return _find(G.bases, func(b): return b.w == w and (baseLoc(b) == s.loc or (has(G, "elev") and pt == "orbit")))
## a base is in orbit or on the surface of its world (chosen where the founding crew vehicle was)
func basePos(b) -> String:
	var p = gi(b, "pos", null)
	if t(p): return p
	return "orbit" if W[b.w].tags.has("station") else "surf"
func baseLoc(b) -> String: return basePos(b) + ":" + b.w
## can a CV be at this location (range + hazards)? null when it can, else the reason
func cvAllowed(G, s, loc: String):
	var p := P(loc)
	var sy = sysOf(loc)
	if sy == "mer" and not has(G, "ars"): return "Mercury's severe radiation needs Active Radiation Shielding"
	if sy == "alp" and crewRange(G) < 99: return "Alpha Centauri needs Safe Crew Hibernation"
	if p.w != null:
		var w: Dictionary = W[p.w]
		if w.tags.has("tele"): return "only telescopes can explore there"
		if w.tags.has("sunobs"): return "crew vehicles cannot explore the Sun"
		if w.tags.has("rad") and not has(G, "ars"): return "severe radiation needs Active Radiation Shielding"
		if isGas(p.w) and p.t == "surf": return "crew vehicles cannot enter a gas giant"
		if p.t == "surf" and w.tags.has("severeAtm") and not has(G, "psh"): return "severe atmosphere needs Pressure Shell"
		if p.t == "surf" and w.tags.has("reentry") and int(gi(s, "sz", 0)) > 4: return "re-entry is limited to CV-4 and smaller"
		if w.sys == "ear" and p.w != "ear" and not has(G, "orb"): return "the Moon and Near Earth Asteroids need Orbital Rendezvous"
	# without Orbital Rendezvous crews stay on Earth or in Earth orbit (no flyby box, Moon, NEA or transfer boxes)
	if not has(G, "orb") and not (loc == "earth" or loc == "orbit:ear" or loc == "surf:ear"): return "leaving Earth orbit needs Orbital Rendezvous"
	if sy != "ear" or p.t == "box":
		# range from Earth or a base able to unreserve this CV
		var r := crewRange(G)
		var need := unreserveLevel(int(gi(s, "sz", 0)))
		var origins := [0]
		for b in G.bases:
			if b.fac.sup - (1 if t(b.dmg.sup) else 0) >= need: origins.append(SYS[W[b.w].sys].t)
		var d: int = mn(origins.map(func(o): return absi(int(SYS[sy].t) - int(o))))
		if d > r: return SYS[sy].n + " is " + n(d) + " away; your crew range is " + n(r)
	return null
## legal moves: [{dest, label, eta, lv, rate, note}]
func moves(G, s) -> Array:
	if G.phase != "move" or G.over: return []
	var out := []
	var p := P(s.loc)
	if p.t == "box" or t(G.turn.moved.get(s.id)): return []
	var here = sysOf(s.loc)
	var add := func(dest: String, extra: Dictionary):
		var o := {"dest": dest, "label": locName(dest), "rate": engRate(G, s)}
		for k in extra: o[k] = extra[k]
		out.append(o)
	# ---------- robotic explorers ----------
	if s.cls == "RE":
		if t(s.fixed): return []
		var lvs := lvStockAt(G, s.loc)
		if not t(s.launched):
			if not lvs.size() and not (s.loc == "earth"): return []
			var lvOpts := launchLVs(G, s.loc, 1)
			if not lvOpts.size(): return []
			if s.kind == "Telescope":
				add.call("orbit:ear", {"lv": lvOpts[0]})
				return out
			for sy in D.SYS_ORDER:
				if sy == here:
					for w in worldsIn(sy):
						if W[w].tags.has("tele") or W[w].tags.has("earth") or w == "ear": continue
						if s.kind == "Orbiter": add.call("orbit:" + w, {"lv": lvOpts[0]})
						if s.kind == "Rover" and not isGas(w) and not isSun(w): add.call("surf:" + w, {"lv": lvOpts[0]})
					if s.kind == "Flyby": add.call("fly:" + sy, {"lv": lvOpts[0]})
					continue
				for lv in lvOpts:
					var tt := maxi(1, transfer(G, here, sy) - (lv.n - 1))
					add.call(boxFor(sy, tt), {"lv": lv, "eta": tt, "hold": maxi(0, tt - 6)})
			return out
		if p.t == "fly" and (s.kind == "Orbiter" or s.kind == "Rover"):
			for w in worldsIn(p.s):
				if W[w].tags.has("tele"): continue
				if s.kind == "Orbiter": add.call("orbit:" + w, {"final": true})
				if s.kind == "Rover" and not isGas(w) and not isSun(w): add.call("surf:" + w, {"final": true})
		return out
	# ---------- crew vehicles ----------
	if s.loc == "earth":
		var lvOpts := launchLVs(G, "earth", s.sz)
		if not lvOpts.size(): return []
		# leaving Earth: carried by LV to Earth orbit (and on, as one move)
		for tg in cvTargets(G, s, "ear"): add.call(tg.dest, {"lv": lvOpts[0], "eta": tg.get("eta"), "hold": tg.get("hold"), "why": tg.why})
		return out.filter(func(o): return o.why == null)
	for tg in cvTargets(G, s, here):
		if tg.dest != s.loc: add.call(tg.dest, {"eta": tg.get("eta"), "hold": tg.get("hold"), "why": tg.why})
	return out.filter(func(o): return o.why == null)
func boxFor(sy: String, tt: int) -> String: return "box:" + sy + ":" + n(mini(6, tt))
func cvTargets(G, s, here) -> Array:
	var out := []
	var push := func(dest: String, extra := {}):
		var o := {"dest": dest, "why": cvAllowed(G, s, dest)}
		for k in extra: o[k] = extra[k]
		out.append(o)
	for w in worldsIn(here):
		if W[w].tags.has("tele") or isSun(w): continue
		push.call("orbit:" + w)
		if not W[w].tags.has("station"): push.call("surf:" + w)
	if here == "ear": push.call("earth")
	push.call("fly:" + here)
	for sy in D.SYS_ORDER:
		if sy == here: continue
		var tt := transfer(G, here, sy)
		push.call(boxFor(sy, tt), {"eta": tt, "hold": maxi(0, tt - 6)})
	return out
func lvStockAt(G, loc: String) -> Array:
	var st = null
	if loc == "earth": st = G.lv.earth
	else:
		var b = _find(G.bases, func(x): return baseLoc(x) == loc)
		if b == null or not G.lv.has(b.id): return []
		st = G.lv[b.id]
	var out := []
	for z in [1, 2, 3, 4]:
		if int(gi(st, z, 0)) > 0: out.append(z)
	return out
## LV choices for a launch needing at least size n: stocked ones, or buy one on Earth if a counter is free
func launchLVs(G, loc: String, need: int) -> Array:
	var stock := []
	for z in lvStockAt(G, loc):
		if z >= need: stock.append({"n": z, "stock": true})
	var out := stock.duplicate()
	if loc == "earth":
		for z in [1, 2, 3, 4]:
			if z >= need and lvTechOk(G, z) and lvCanAdd(G, z) and not _some(stock, func(x): return x.n == z):
				var c := {"ORE": 1, "FUEL": z}
				out.append({"n": z, "buy": true, "cost": c, "cash": earthCash(G, c), "txt": earthCostTxt(G, c)})
	return ssort(out, func(a, b):
		var d: int = (0 if t(a.get("stock")) else 1) - (0 if t(b.get("stock")) else 1)
		return d if d != 0 else a.n - b.n)
func engineRoll(G, rate: int) -> Dictionary:
	if rate < 1: return {"r": null, "fail": false}
	var r := d100()
	var fail := r <= rate
	if fail and G.rr > 0:
		G.rr -= 1
		glog(G, "Engine roll " + n(r) + " fails; improved engine reliability reroll used (" + n(G.rr) + " left).")
		r = d100()
		fail = r <= rate
	return {"r": r, "fail": fail}
func _lvStoreFor(G, s) -> Dictionary:
	if s.loc == "earth": return G.lv.earth
	return G.lv[_find(G.bases, func(b): return baseLoc(b) == s.loc).id]
## carry: probe name to load at launch. Returns null, or the reason it cannot move.
func move(G, s, dest: String, opt = null):
	if opt == null: opt = {}
	var m := moves(G, s).filter(func(x): return x.dest == dest)
	if not m.size(): return s.name + " cannot move to " + locName(dest) + " now."
	var mv = null
	if t(gi(opt, "lvSize", null)): mv = _find(m, func(x): return x.get("lv") != null and x.lv.n == opt.lvSize)
	if mv == null: mv = m[0]
	var mlv = mv.get("lv")
	# a crew vehicle leaving Earth can be paired with any launch vehicle big enough (chosen on the faction board)
	if s.cls == "CV" and s.loc == "earth" and t(gi(opt, "lvSize", null)) and (mlv == null or mlv.n != opt.lvSize):
		var alt = _find(launchLVs(G, "earth", s.sz), func(x): return x.n == opt.lvSize)
		if alt != null: mlv = alt
	# pay for LV if buying
	var lvPaid = null
	var loadPaid = null
	# a crew vehicle leaving Earth can be loaded with cargo paid on Earth (faction board first, then $1B each)
	var ld = null
	if s.cls == "CV" and s.loc == "earth" and t(gi(opt, "load", null)):
		ld = {}
		for r in RES: ld[r] = maxi(0, fl(num(gi(opt.load, r, 0))))
	if ld != null and sum(ld):
		var room: int = s.cap * cargoMul(G) - sum(s.cargo)
		if sum(ld) > room: return s.name + " has room for " + n(room) + " cargo."
		var all: Dictionary = ld.duplicate()
		if mlv != null and t(mlv.get("buy")):
			for r in RES: all[r] += int(gi(mlv.cost, r, 0))
		if G.cash < earthCash(G, all): return "The launch and cargo cost " + earthCostTxt(G, all) + "."
		loadPaid = payEarth(G, ld)
		for r in RES: s.cargo[r] += ld[r]
		glog(G, s.name + " loads " + resTxt(ld) + " on Earth (" + (("$" + n(loadPaid.cash) + "B") if loadPaid.cash else "no cash") + ((", " + resTxt(loadPaid.used) + " from the faction board") if sum(loadPaid.used) else "") + ").")
	if mlv != null and t(mlv.get("buy")):
		if G.cash < earthCash(G, mlv.cost): return "A new LV-" + n(mlv.n) + " costs " + earthCostTxt(G, mlv.cost) + "."
		lvPaid = payEarth(G, mlv.cost)
	elif mlv != null:
		_lvStoreFor(G, s)[mlv.n] -= 1
	# probe
	if t(gi(opt, "probe", null)) and not t(s.launched) and s.cls == "RE" and ["Flyby", "Orbiter", "Rover"].has(s.kind):
		var pool: Array = G.probes.get(s.loc, [])
		if pool.has(opt.probe):
			G.probes[s.loc] = pool.filter(func(x): return x != opt.probe)
			s.probe = opt.probe
	var from: String = s.loc
	var fromName := locName(from)
	# pirates intercept CVs leaving a flyby box (unless armed)
	var pf := P(from)
	var leavingFly: bool = s.cls == "CV" and (pf.t == "fly" or (sysOf(from) != sysOf(dest)))
	var pirSys = pf.s if pf.t == "fly" else sysOf(from)
	var refund := func():
		if loadPaid != null:
			for r in RES: s.cargo[r] -= ld[r]
			unpayEarth(G, loadPaid)
		if lvPaid != null: unpayEarth(G, lvPaid)
		elif mlv != null: _lvStoreFor(G, s)[mlv.n] += 1
	if leavingFly and G.fly[pirSys].pir.size() and not (s.cb - s.dmg > 0) and not t(gi(opt, "pirateDone", false)):
		G.ask.append({"k": "pirate", "ship": s.id, "dest": dest, "opt": merged(opt, {"pirateDone": true}), "sys": pirSys, "roll": d10(), "text": "A pirate in the " + SYS[pirSys].n + " flyby box intercepts " + s.name + "."})
		refund.call()
		return null
	# hostile fleets intercept ships leaving their location (3.3.6)
	if not t(gi(opt, "iceptDone", false)) and from != "earth":
		var ic := interceptCheck(G, s, from)
		if ic.r == "dead": return null
		if ic.r == "caught":
			if isHuman(G):
				G.ask.append({"k": "intercept", "ship": s.id, "dest": dest, "opt": merged(opt, {"iceptDone": true}), "by": ic.g.f, "key": ic.key, "rA": ic.rA, "rB": ic.rB, "text": D.FAC[ic.g.f].n + " intercepts " + s.name + " as it leaves " + keyName(ic.key) + ". Stop moving, fight, or surrender?"})
				refund.call()
				return null
			if interceptAuto(G, s, ic) == "stop":
				glog(G, s.name + " stops rather than fight " + nm(ic.g) + ".")
				refund.call()
				return null
			interceptFight(G, s, ic, false)
			if not has_obj(G.ships, s) or t(s.res): return null
	var rate := engRate(G, s)
	var er := engineRoll(G, rate)
	var r = er.r
	var rtxt: String = "no engine roll needed" if r == null else "engine roll " + n(r) + " vs " + n(rate) + "%"
	if er.fail:
		if s.cls == "CV": loseCV(G, s, "to an engine failure leaving " + fromName + " (" + rtxt + ")")
		else: loseRE(G, s, "is lost to an engine failure (" + rtxt + ")")
		if mlv != null: glog(G, "LV-" + n(mlv.n) + " is destroyed with it.")
		return null
	# LV recovery
	if mlv != null:
		var keep: bool = has(G, "reuse") and (d100() if r == null else r) > 25
		if keep:
			var key = "earth" if from == "earth" else _find(G.bases, func(b): return baseLoc(b) == from).id
			lvRecover(G, key, mlv.n)
			glog(G, "LV-" + n(mlv.n) + " is recovered and returns to " + ("Earth" if from == "earth" else "its base") + "; it can launch again next turn.")
		else: glog(G, "LV-" + n(mlv.n) + " is expended" + (" (roll 25 or lower)" if has(G, "reuse") else "") + ".")
	s.loc = dest
	s.hold = orv(mv.get("hold"), 0)
	s.launched = true
	if t(mv.get("final")) or (s.cls == "RE" and (s.kind == "Orbiter" or s.kind == "Rover") and (P(dest).t == "orbit" or P(dest).t == "surf")): s.fixed = true
	G.turn.moved[s.id] = int(gi(G.turn.moved, s.id, 0)) + 1
	var eta = mv.get("eta")
	glog(G, s.name + " moves from " + fromName + " to " + locName(dest) + ((" (" + n(eta) + " turn transfer" + ((", " + n(s.hold) + " turn(s) beyond box 6") if t(s.hold) else "") + ")") if t(eta) else "") + ", " + rtxt + ".")
	return null
## LV cargo run from Earth to a base: buy resources at $1B each
func shipCargo(G, baseId, ld: Dictionary, lvSize = null):
	if G.phase != "move": return "Cargo flights happen in the movement phase."
	var b = _baseById(G, baseId)
	if b == null: return "Unknown base."
	var opts := launchLVs(G, "earth", 1).filter(func(o): return not t(lvSize) or o.n == lvSize)
	if not opts.size(): return "No launch vehicle available on Earth."
	var lv = opts[0]
	var cap: int = (lv.n + (1 if G.f == "sa" else 0)) * cargoMul(G)
	var cnt := sum(ld)
	if cnt > cap: return "LV-" + n(lv.n) + " carries " + n(cap) + " resources."
	var cost: Dictionary = ld.duplicate()
	if t(lv.get("buy")):
		cost.ORE = int(gi(cost, "ORE", 0)) + 1
		cost.FUEL = int(gi(cost, "FUEL", 0)) + lv.n
	if G.cash < earthCash(G, cost): return "This flight costs " + earthCostTxt(G, cost) + "."
	if G.fly[W[b.w].sys].pir.size(): glog(G, "Note: a pirate waits in the " + SYS[W[b.w].sys].n + " flyby box.")
	payEarth(G, cost)
	if t(lv.get("stock")): G.lv.earth[lv.n] -= 1
	var er := engineRoll(G, engBase(G))
	if er.fail:
		var v := drawMarker(G, "Eng")
		glog(G, "The LV-" + n(lv.n) + " cargo flight to " + b.name + " fails (engine roll " + n(er.r) + "); cargo lost. Lessons learned: " + n(v) + " Engineering.", "x")
		return null
	addRes(b.stock, ld)
	if has(G, "reuse") and er.r > 25:
		lvRecover(G, "earth", lv.n)
		glog(G, "LV-" + n(lv.n) + " is recovered; it can launch again next turn.")
	glog(G, "LV-" + n(lv.n) + " delivers " + resTxt(ld) + " to " + b.name + " (engine roll " + n(er.r) + ").", "g")
	return null
func _shipById(G, id):
	return _find(G.ships, func(x): return eq(x.id, id))
func answer(G, choice = null, data = null):
	if not G.ask.size(): return null
	var a: Dictionary = G.ask[0]
	if a.k == "pirate":
		var s = _shipById(G, a.ship)
		G.ask.pop_front()
		if s == null: return null
		if choice == "pay":
			G.cash -= a.roll
			G.cache += a.roll
			if G.cash < 0:
				G.debt += -G.cash
				G.cash = 0
			glog(G, "Paid the pirates $" + n(a.roll) + "B; " + s.name + " passes.")
			return move(G, s, a.dest, a.opt)
		if choice == "remove":
			var c: int = a.roll * 2
			G.cash -= c
			G.cache += c
			if G.cash < 0:
				G.debt += -G.cash
				G.cash = 0
			G.fly[a.sys].pir.pop_front()
			glog(G, "Paid $" + n(c) + "B to drive the pirate off; " + s.name + " passes.")
			return move(G, s, a.dest, a.opt)
		if choice == "surrender":
			s.cargo = {"ORE": 0, "SUP": 0, "FUEL": 0}
			s.res = true
			if t(G.polm): G.polm -= 1
			glog(G, s.name + " surrenders to the pirates: cargo lost, crew vehicle reserved, 1 politics marker taken.", "x")
			return null
		if choice == "fight":
			if eq(pirateBattle(G, [s], a.sys, false, {"ship": s.id, "dest": a.dest, "opt": a.opt}), "pending"): return null
			if has_obj(G.ships, s) and not G.fly[a.sys].pir.size(): return move(G, s, a.dest, a.opt)
			return null
		if choice == "stay":
			glog(G, s.name + " stays put.")
			return null
	if a.k == "intercept":
		var s = _shipById(G, a.ship)
		G.ask.pop_front()
		if s == null: return null
		var g = facG(G, a.by)
		var c := {"g": g, "key": a.key, "rA": a.rA, "rB": a.rB}
		if choice == "stop":
			glog(G, s.name + " stops moving.")
			return null
		interceptFight(G, s, c, choice == "surrender")
		if not has_obj(G.ships, s) or t(s.res): return null
		return move(G, s, a.dest, a.opt)
	if a.k == "surrender":
		var ch := "accept"
		if choice == "deny" and t(a.canDeny): ch = "deny"
		elif choice == "exclude" and t(a.split): ch = "exclude"
		G.ask.pop_front()
		afterOffer(G, facG(G, a.ctx.d), a.ctx, ch)
		return null
	if a.k == "basehit":
		var g = facG(G, a.f)
		var b = _baseById(g, a.base) if g != null else null
		if b == null:
			G.ask.pop_front()
			return null
		var al = autoAlloc(b, a.n) if (choice == "auto" or data == null or not t(gi(data, "alloc", null))) else data.alloc
		var bad = checkAlloc(b, a.n, al)
		if bad != null: return bad
		var rp = null
		if t(gi(al, "res", 0)):
			var tot: int = mini(2 * int(num(al.res)), sum(b.stock))
			var pr = gi(data, "res", null) if data != null else null
			if t(pr):
				var tt := 0
				for r in RES: tt += int(num(gi(pr, r, 0)))
				var over := false
				for r in RES:
					if num(gi(pr, r, 0)) > b.stock[r] or num(gi(pr, r, 0)) < 0: over = true
				if tt != tot or over: return "Choose exactly " + n(tot) + " resources, no more of a type than the base holds."
				rp = {"ORE": int(num(gi(pr, "ORE", 0))), "SUP": int(num(gi(pr, "SUP", 0))), "FUEL": int(num(gi(pr, "FUEL", 0)))}
		G.ask.pop_front()
		var r := applyAlloc(b, al, rp)
		var parts := []
		for c in TGT + ["res"]:
			if t(gi(al, c, 0)): parts.append(n(al[c]) + " on " + ("settlements" if c == "set" else (("resources (" + n(r.destroyed) + " destroyed)") if c == "res" else c)))
		blog(G, g, nm(G) + " hits " + nm(g) + "'s base " + b.name + ": " + ", ".join(parts) + ".", "x")
		return null
	if a.k == "assign":
		var st: Dictionary = a.st.duplicate()
		if t(gi(a, "pirate", false)):
			if choice == "auto" or data == null: st.asg = {}
			else:
				var al = gi(gi(data, "alloc", {}), "fleet", {})
				var tot := 0
				for v in al.values(): tot += int(num(v))
				if tot != a.groups[0].n: return "Assign exactly " + n(a.groups[0].n) + " damage."
				var fl_ := []
				for k in al.keys():
					for i in maxi(0, int(num(al[k]))): fl_.append(k)
				st.asg = {"fleet": fl_}
			G.ask.pop_front()
			resolvePirate(G, st, a.up, false)
			var c = gi(st, "cont", null)
			var s = _shipById(G, c.ship) if t(c) else null
			if s != null and has_obj(G.ships, s) and not t(s.res) and not G.fly[st.sy].pir.size(): return move(G, s, c.dest, c.opt)
			return null
		if choice == "auto" or data == null:
			st.asg = {}
			st.scr = null
		else:
			var al = gi(data, "alloc", {})
			var me: String = a.me
			var fa := "fa" if me == "a" else "fb"
			var fo := "fb" if me == "a" else "fa"
			var scr := []
			for k in gi(data, "scr", []):
				if _some(a.screen, func(x): return x.key == k): scr.append(k)
			st.scr = scr if (scr.size() or a.screen.size()) else null
			st.asg = {"fa": [], "fb": []}
			for g in a.groups:
				var m = gi(al, g.side, {})
				var tot := 0
				for v in m.values(): tot += int(num(v))
				if tot != g.n: return "Assign exactly " + n(g.n) + " hit" + ("s" if g.n > 1 else "") + " on " + ("their" if g.side == "foe" else "your") + " units."
				for k in m.keys():
					var c := int(num(m[k]))
					if c > 0 and (not _some(g.units, func(u): return u.key == k) or (g.side == "mine" and scr.has(k))): return "That unit cannot be targeted."
					for i in maxi(0, c): st.asg[fo if g.side == "foe" else fa].append(k)
		G.ask.pop_front()
		resolveBattle(facG(G, st.a), facG(G, st.d), st, a.plan)
		return null
	if a.k == "search":
		G.ask.pop_front()
		return null
	if a.k == "pbattle":
		var st0: Dictionary = a.st
		var up := 0
		var red := 0
		var mode := "direct" if st0.extra >= 1 else "strike"
		if choice == "plan" and data != null:
			up = maxi(0, fl(num(gi(data, "inc", 0))))
			red = maxi(0, fl(num(gi(data, "red", 0))))
			mode = "direct" if gi(data, "mode", null) == "direct" else "strike"
			var cost: int = (1 if mode == "direct" else 0) + 2 * (up + red)
			if cost > st0.extra: return "That costs " + n(cost) + " tactics points; you have " + n(st0.extra) + "."
		else: up = fl((st0.extra - (1 if mode == "direct" else 0)) / 2.0)
		G.ask.pop_front()
		var st := merged(st0, {"red": red, "mode": mode})
		var pr = resolvePirate(G, st, up, choice == "avoid")
		if eq(pr, "pending"): return null
		var c = gi(st, "cont", null)
		var s = _shipById(G, c.ship) if t(c) else null
		if s != null and has_obj(G.ships, s) and not t(s.res) and not G.fly[st.sy].pir.size(): return move(G, s, c.dest, c.opt)
		return null
	if a.k == "battle":
		var A = facG(G, a.st.a)
		var B = facG(G, a.st.d)
		var rem: int = a.rem
		var plan = null
		if choice == "plan" and data != null and a.rem > 0 and not t(a.lose):
			var inc := maxi(0, fl(num(gi(data, "inc", 0))))
			var red := maxi(0, fl(num(gi(data, "red", 0))))
			var picks := maxi(0, fl(num(gi(data, "picks", 0))))
			var direct: bool = gi(data, "mode", null) == "direct"
			if t(gi(data, "avoid", false)):
				if rem < 3: return "Calling off the combat costs 3 tactics points."
				plan = {"avoid": true}
			else:
				var cost: int = (1 if direct else 0) + 2 * inc + 2 * red + picks
				if cost > rem: return "That costs " + n(cost) + " tactics points; you have " + n(rem) + "."
				plan = {"mode": "direct" if direct else "strike", "extra": inc, "red": red, "tgt": picks, "avoid": false}
		G.ask.pop_front()
		if plan == null and a.rem > 0 and not t(a.lose):
			var cs := String(choice) if choice != null else "null"
			if choice == "avoid" and rem >= 3: plan = {"avoid": true}
			elif choice == "strike": plan = {"mode": "strike", "extra": 0, "tgt": rem}
			elif choice == "direct": plan = {"mode": "direct", "extra": 0, "tgt": rem - 1}
			elif cs.begins_with("dx"):
				var k := mini(int(num(cs.substr(2))), fl((rem - 1) / 2.0))
				plan = {"mode": "direct", "extra": k, "tgt": rem - 1 - 2 * k}
			elif cs.begins_with("sx"):
				var k := mini(int(num(cs.substr(2))), fl(rem / 2.0))
				plan = {"mode": "strike", "extra": k, "tgt": rem - 2 * k}
		resolveBattle(A, B, a.st, plan)
		return null
	if a.k == "publicity":
		var w = G.w.get(choice) if choice is String else null
		if w == null or w.v < 1: return "Pick a world that is not fully depleted."
		w.v += 2
		G.ask.pop_front()
		glog(G, "Publicity Campaign: " + W[choice].n + " rises to " + n(w.v) + ".", "g")
		return null
	if a.k == "immigration":
		var b = _baseById(G, choice)
		if b == null: return "Pick one of your bases."
		b.set += 2
		G.ask.pop_front()
		glog(G, "Immigration: " + b.name + " gains 2 settlements.", "g")
		return null
	if a.k == "card":
		G.ask.pop_front()
		if t(choice):
			var old = G.w[a.w].card
			G.w[a.w].card = choice
			glog(G, "World card " + choice + " drawn and placed on " + W[a.w].n + ((", replacing " + old) if (t(old) and old != choice) else "") + ".", "g")
			for o in a.opts:
				if o != choice: glog(G, "World card " + o + " returned to the deck.")
		else: glog(G, "World card" + ("s" if a.opts.size() > 1 else "") + " " + " and ".join(a.opts) + " returned to the deck; " + W[a.w].n + " keeps " + orv(G.w[a.w].card, "no card") + ".")
		if t(gi(a, "life", null)):
			var L := lifeSearch(G, a.w, a.life.base)
			glog(G, W[a.w].n + ":" + (L.msg if t(L.msg) else " no search for life (" + L.info.skip + ")."), "g" if t(gi(L.info, "found", false)) else "")
			G.lastRoll = {"kind": "life", "title": "Search for life on " + W[a.w].n, "life": L.info, "extra": []}
		return null
	if a.k == "mission":
		var id := int(num(choice))
		if not G.mis.kept.has(id): return "Pick one of your kept missions."
		G.ask.pop_front()
		G.mis.kept = G.mis.kept.filter(func(x): return x != id)
		if not t(D.MIS[id].yr): G.mis.pool.append(id)
		glog(G, "Mission " + misTxt(id) + " given up" + (" (dated missions leave the game)" if t(D.MIS[id].yr) else " and returned to the pool") + ". Kept: " + ", ".join(G.mis.kept.map(func(x): return misTxt(x))) + ".")
		return null
	if a.k == "flyby":
		var s = _shipById(G, a.ship)
		G.ask.pop_front()
		if s == null: return null
		return flybyTransfer(G, s, choice)
	return null

# ================= COMBAT (pirates, NPF raids & blockades) =================
## combat can happen this year if any pirate is on the board, or if any faction in play has an embargo or war with a
## faction that is on the board: an NPF with a base, or another faction in play with ships or bases
func combatPossible(G) -> bool:
	if _some(G.fly.values(), func(f): return f.pir.size() > 0): return true
	var facs: Array = G.world.facs.values() if G.world != null else [G]
	var onBoard := func(k):
		if _some(G.w.values(), func(x): return eq(x.npf, k)): return true
		return G.world != null and G.world.facs.has(k) and (G.world.facs[k].ships.size() > 0 or G.world.facs[k].bases.size() > 0)
	for g in facs:
		for k in g.rel.keys():
			if g.rel[k] >= 4 and onBoard.call(k): return true
	return false
func startCombat(G) -> void:
	# blockades lapse unless a CV with combat value stays at an NPF base world with embargo or worse
	for k in G.w.keys():
		var x = G.w[k]
		if not t(x.npf): continue
		var still: bool = t(x.blk) and _some(G.ships, func(s): return s.cls == "CV" and not t(s.res) and worldOf(s.loc) == k and s.cb > s.dmg) and G.rel[x.npf] >= 4
		if t(x.blk) and not still: x.blk = false
	lapseBlockades(G)
func endCombat(_G) -> void: pass
func armed(s) -> bool: return s.cls == "CV" and not t(s.res) and s.cb - s.dmg > 0
func combatOptions(G) -> Array:
	var out := []
	for sy in D.SYS_ORDER:
		var here = G.ships.filter(func(s): return s.loc == "fly:" + sy and armed(s))
		if here.size() and G.fly[sy].pir.size(): out.append({"k": "pirate", "sys": sy, "label": "Attack the pirate in the " + SYS[sy].n + " flyby box"})
	for k in G.w.keys():
		var x = G.w[k]
		if not t(x.npf): continue
		var here = G.ships.filter(func(s): return worldOf(s.loc) == k and P(s.loc).t != "box" and P(s.loc).t != "fly" and armed(s))
		if not here.size(): continue
		if G.rel[x.npf] >= 4 and not t(x.blk): out.append({"k": "blockade", "w": k, "label": "Blockade the " + D.FAC[x.npf].n + " base at " + W[k].n})
		if G.rel[x.npf] >= 5: out.append({"k": "raid", "w": k, "label": "Raid the " + D.FAC[x.npf].n + " base at " + W[k].n})
	return out + factionCombatOptions(G)
func combatAct(G, o: Dictionary):
	if G.phase != "combat": return "Combat happens in the combat phase."
	if o.k == "fleet" or o.k == "bombard" or o.k == "fblock": return factionAct(G, o)
	var ck: String = "c:" + String(orv(o.get("sys"), o.get("w")))
	if t(G.turn.acted.get(ck)): return "Each fleet may search once per turn."
	G.turn.acted[ck] = 1
	if o.k == "pirate":
		pirateBattle(G, G.ships.filter(func(s): return s.loc == "fly:" + o.sys and armed(s)), o.sys, true)
		return null
	var x = G.w[o.w]
	if o.k == "blockade":
		x.blk = true
		x.npfTrade = null
		glog(G, "You blockade the " + D.FAC[x.npf].n + " base at " + W[o.w].n + ": +$2B each production step while it lasts.", "g")
		return null
	if o.k == "raid":
		var fleet = G.ships.filter(func(s): return worldOf(s.loc) == o.w and P(s.loc).t != "fly" and armed(s))
		var r := d10()
		var cap: int = D.RAID[r][0]
		var dmg: int = D.RAID[r][1]
		var lostCV := false
		for i in dmg:
			var s = _first(ssort(fleet.filter(func(z): return has_obj(G.ships, z)), func(a, b): return (b.sz - b.dmg) - (a.sz - a.dmg)))
			if s == null: break
			s.dmg += 1
			recallCheck(G, s)
			if s.dmg >= s.sz:
				loseCV(G, s, "in the raid")
				lostCV = true
		var room := 0
		for z in fleet:
			if has_obj(G.ships, z): room += z.cap * cargoMul(G) - sum(z.cargo)
		var got := mini(cap, room)
		var holder = fleet.filter(func(z): return has_obj(G.ships, z) and t(z.cap))
		for i in got:
			var h = _find(holder, func(z): return z.cap * cargoMul(G) > sum(z.cargo))
			if h == null: break
			h.cargo[pick(RES)] += 1
		if r == 10:
			G.w[o.w].npf = null
			G.w[o.w].npfTrade = null
			glog(G, "Raid roll 10: the " + W[o.w].n + " NPF base is destroyed.", "x")
		else: glog(G, "Raid roll " + n(r) + ": captured " + n(got) + " resources, took " + n(dmg) + " damage.", "g")
		if not lostCV:
			G.vm += 1
			glog(G, "No crew vehicle lost in the raid: +1 victory marker.", "g")
		return null
	return null
static func _first(a: Array) -> Variant:
	return a[0] if a.size() else null
func recallCheck(G, s) -> void:
	if t(s.res): return
	if d100() <= recall(G):
		s.res = true
		var b := drawMarker(G, "Bio")
		glog(G, s.name + " is recalled and goes into reserve (+" + n(b) + " Biology).")
## damage tables for a pirate fight. The pirate is assumed to carry missiles, so a strike hurts both sides unless fighter drones cancel it.
func pirTables(G, fleet: Array, pir, st) -> Dictionary:
	var pd: Dictionary = D.PIRATE.strong if t(pir.strong) else D.PIRATE.weak
	var myTot: int = _sum(fleet, func(s): return maxi(0, s.cb - s.dmg)) + weapons(G) + st.dm
	var pTot: int = maxi(0, pd.cb - pir.dmg) + st.dp + (fleet.size() - 1)
	var drones := droneCount(G, fleet.map(func(s): return uS(s)))
	var bd := drones if has(G, "bd") else 0
	return {"myTot": myTot, "pTot": pTot, "strike": {"deal": (combatDamage(myTot, true) + bd) if has(G, "msl") else 0, "take": maxi(0, combatDamage(pTot, true) - drones)}, "direct": {"deal": combatDamage(myTot, false), "take": combatDamage(pTot, false)}}
func _strongest(pirs: Array):
	return _first(ssort(pirs, func(a, b): return (1 if t(b.strong) else 0) - (1 if t(a.strong) else 0)))
func pirateBattle(G, fleet: Array, sy: String, _playerSearched := false, cont = null):
	var pir = _strongest(G.fly[sy].pir)
	if pir == null or not fleet.size(): return null
	var pd: Dictionary = D.PIRATE.strong if t(pir.strong) else D.PIRATE.weak
	var ncv := fleet.size()
	var mine := d10()
	var theirs := d10()
	var bonus := ncv - 1
	var found: bool = mine - bonus <= 4 or theirs - bonus <= 4
	if G.world == null or isHuman(G): G.ask.append({"k": "search", "ok": found, "auto": false, "T": 4, "rolls": [{"n": "You", "r": mine - bonus}, {"n": "Pirate", "r": theirs - bonus}], "where": SYS[sy].n + " flyby box",
		"text": ("You find the pirate in the " + SYS[sy].n + " flyby box.") if found else ("You search the " + SYS[sy].n + " flyby box but do not find the pirate.")})
	if not found:
		glog(G, "Search for the pirate fails (rolls " + n(mine) + " and " + n(theirs) + ").")
		return null
	# tactics points: each side earns the other's roll, +1 per full 7 enemy CV size
	var myTP: int = theirs + fl(pd.size / 7.0) + (2 if has(G, "cc") else (1 if has(G, "amsl") else 0)) + (2 if polLv(G, "mil") >= 3 else 0)
	var pTP: int = mine + fl(_sum(fleet, func(s): return s.sz) / 7.0)
	var armedFleet := _some(fleet, func(s): return armed(s))
	if pTP - myTP >= 3 and armedFleet:
		glog(G, "The pirate uses its tactics advantage (" + n(pTP) + " to " + n(myTP) + ") to avoid combat.")
		return null
	var extra := maxi(0, myTP - pTP)
	var st := {"cont": cont, "sy": sy, "ids": fleet.map(func(s): return s.id), "strong": t(pir.strong), "dm": d10(), "dp": d10(), "myTP": myTP, "pTP": pTP, "extra": extra}
	if G.world == null or isHuman(G):  # the player sees the rolls and decides how to spend the tactics points
		var T := pirTables(G, fleet, pir, st)
		G.ask.append({"k": "pbattle", "st": st, "mine": fleet.map(func(s): return {"n": s.name, "cb": maxi(0, s.cb - s.dmg)}), "weapons": weapons(G), "pir": {"strong": t(pir.strong), "cb": maxi(0, pd.cb - pir.dmg), "size": pd.size, "dmg": pir.dmg},
			"myTot": T.myTot, "pTot": T.pTot, "strike": T.strike, "direct": T.direct, "extra": extra, "myTP": myTP, "pTP": pTP, "can": fl(extra / 2.0),
			"text": "Combat with the " + ("strong" if t(pir.strong) else "weak") + " pirate in the " + SYS[sy].n + " flyby box."})
		return "pending"
	var m := "direct" if extra >= 1 else "strike"
	resolvePirate(G, merged(st, {"mode": m}), fl((extra - (1 if m == "direct" else 0)) / 2.0), false)
	return null
## finish a pirate fight with the dice already rolled. up: extra damage bought with tactics points (2 each); avoid: call the combat off (3 points)
func resolvePirate(G, st: Dictionary, up: int, avoid: bool):
	var fleet = G.ships.filter(func(s): return st.ids.has(s.id))
	var sy: String = st.sy
	var pir = _strongest(G.fly[sy].pir)
	if pir == null or not fleet.size(): return null
	var pd: Dictionary = D.PIRATE.strong if t(pir.strong) else D.PIRATE.weak
	var red := maxi(0, int(gi(st, "red", 0)))
	var direct: bool = gi(st, "mode", null) == "direct"
	var spare: int = st.extra - (1 if direct else 0) - 2 * red
	var myDmgUp := maxi(0, mini(up, fl(spare / 2.0)))
	if avoid and st.extra >= 3:
		glog(G, "You spend 3 tactics points to call off the combat with the pirate.")
		return null
	var T := pirTables(G, fleet, pir, st)
	var myTotal: int = T.myTot
	var pTotal: int = T.pTot
	var tab: Dictionary = T.direct if direct else T.strike
	var myDmg: int = tab.deal + myDmgUp
	var pDmg: int = maxi(0, tab.take - red)
	if not t(gi(st, "asg", null)) and fleet.size() > 1 and pDmg > 0 and (G.world == null or isHuman(G)):  # direct fire: the receiving player chooses which ships take the damage
		G.ask.append({"k": "assign", "pirate": true, "st": st, "up": up, "groups": [{"side": "fleet", "n": pDmg, "units": fleet.map(func(s): return {"key": str(s.id), "n": s.name, "cb": maxi(0, s.cb - s.dmg), "hp": s.sz - s.dmg})}], "screen": [], "text": "The pirate hits your fleet: choose which ships take the damage."})
		return "pending"
	var myBase: int = myDmg - myDmgUp
	glog(G, "Combat with the pirate (" + ("direct fire, 1 tactics point" if direct else "strike") + "): your combat total is " + n(myTotal) + " (d10 " + n(st.dm) + " + combat values" + (" + weapons" if weapons(G) else "") + "), which is " + n(myBase) + " damage on the table" + ((", plus " + n(myDmgUp) + " from your tactics points (" + n(st.myTP) + " to " + n(st.pTP) + ")") if myDmgUp else "") + ", " + n(myDmg) + " in all" + (("; you spend " + n(2 * red) + " tactics points to reduce the damage you take by " + n(red)) if red else "") + "; the pirate's total is " + n(pTotal) + " (d10 " + n(st.dp) + ") for " + n(pDmg) + " damage.", "e")
	pir.dmg += myDmg
	if pir.dmg >= pd.size:
		G.fly[sy].pir = without(G.fly[sy].pir, pir)
		var share := rnd_i(G.cache / 2.0)
		G.cache -= share
		G.cash += share
		G.polm += 1
		G.vm += 1
		glog(G, "Pirate destroyed! You collect $" + n(share) + "B from the pirate cache, a politics marker and a victory marker.", "g")
	var q: Array = (gi(gi(st, "asg", {}), "fleet", [])).duplicate()
	for i in pDmg:
		var s = null
		while q.size() and s == null:
			var k = q.pop_front()
			s = _find(fleet, func(z): return str(z.id) == String(k) and has_obj(G.ships, z))
		if s == null: s = _first(ssort(fleet.filter(func(z): return has_obj(G.ships, z)), func(a, b): return (b.sz - b.dmg) - (a.sz - a.dmg)))
		if s == null: break
		s.dmg += 1
		recallCheck(G, s)
		if s.dmg >= s.sz:
			removeShip(G, s)
			var cnt := 2 if s.sz >= 4 else 1
			var got := []
			for j in cnt: got.append(drawMarker(G, "Eng"))
			glog(G, s.name + " is destroyed by the pirate. Lessons learned: " + markerTxt(got, "Eng") + ".", "x")
	return null

# ================= FACTION COMBAT (3.3.6 interception, 3.4.1-3.4.7) =================
# A fleet is every unreserved crew vehicle a faction has at one location (a world including its orbit and surface, or a
# flyby box). Earth is never a battlefield. Embargo or worse allows attacks on ships and blockades; war allows orbital
# bombardment of bases.
func facG(G, f):
	return G.world.facs.get(f) if G.world != null else null
func others(G) -> Array:
	return G.world.facs.values().filter(func(g): return g.f != G.f) if G.world != null else []
func isHuman(G) -> bool: return G.world != null and G.f == G.world.meta.human
func keyOf(loc: String):
	var p := P(loc)
	if p.t == "fly": return "fly:" + p.s
	if (p.t == "orbit" or p.t == "surf") and p.w != "ear": return "w:" + p.w
	return null
func keyName(k: String) -> String: return ("the " + SYS[k.substr(4)].n + " flyby box") if k.begins_with("fly:") else W[k.substr(2)].n
func shipsAt(g, key) -> Array: return g.ships.filter(func(s): return eq(keyOf(s.loc), key) and (s.cls != "CV" or not t(s.res)))
func cvsAt(g, key) -> Array: return shipsAt(g, key).filter(func(s): return s.cls == "CV")
func basesAt(g, key: String) -> Array: return g.bases.filter(func(b): return b.w == key.substr(2)) if key.begins_with("w:") else []
func cbOf(s) -> int: return maxi(0, int(gi(s, "cb", 0)) - s.dmg) if s.cls == "CV" else 0
func dnOf(b) -> int: return 7 if b.fac.def >= 2 else (3 if b.fac.def == 1 else 0)  # Defense Network combat value (the red triangle)
func dnDrones(b) -> int: return 3 if b.fac.def >= 2 else (1 if b.fac.def == 1 else 0)  # combat drones it carries
func surrendered(g, f) -> bool:
	var s = gi(g, "surr", null)
	return s != null and eq(s.get(f), g.y)
func sizeOfFac(c: String, l: int) -> int:
	if c == "mine" or c == "sup": return 2 if (l == 2 or l == 4) else 1
	return l
const DOWNFAC := {"lab": [0, 0, 1], "def": [0, 0, 1], "mine": [0, 0, 1, 1, 2], "sup": [0, 0, 1, 1, 2]}
func markersFor(sz: int) -> int: return 4 if sz >= 7 else (3 if sz == 6 else (2 if sz >= 4 else 1))  # victory markers earned for a CV destroyed / Engineering markers learned
func uS(o) -> Dictionary: return {"t": "s", "o": o}
func uB(o) -> Dictionary: return {"t": "b", "o": o}
func uCb(u) -> int: return cbOf(u.o) if u.t == "s" else dnOf(u.o)
func uHp(u) -> int:
	if u.t == "s": return (u.o.sz - u.o.dmg) if u.o.cls == "CV" else 1
	var k := 1
	for c in ["lab", "mine", "sup", "def"]:
		if t(u.o.fac[c]): k += 1
	return k
func uCV(u) -> bool: return u.t == "s" and u.o.cls == "CV"
func droneCount(g, us: Array) -> int:
	if not has(g, "fd"): return 0
	var a := 0
	for u in us:
		if u.t == "s": a += maxi(0, int(gi(u.o, "dr", 0)) - fl(int(gi(u.o, "dmg", 0)) / 2.0)) if u.o.cls == "CV" else 0
		else: a += dnDrones(u.o)
	return a
func droneMod(g, us: Array) -> int:
	var k := droneCount(g, us)
	return 2 if k >= 5 else (1 if k >= 1 else 0)
func power(g, us: Array) -> int:
	return _sum(us, func(u): return uCb(u)) + (weapons(g) if _some(us, func(u): return uCb(u) > 0) else 0)
func unitsOf(g, ids: Array, bids) -> Array:
	var out := []
	for s in g.ships:
		if ids.has(s.id): out.append(uS(s))
	var bl: Array = bids if bids != null else []
	for b in g.bases:
		if bl.has(b.id): out.append(uB(b))
	return out
func nm(g) -> String: return D.FAC[g.f].n
func blog(A, B, msg: String, c = "") -> void:
	glog(A, msg, c)
	glog(B, msg, c)
	var H = A.world.facs.get(A.world.meta.human) if A.world != null else null
	if H != null and H.f != A.f and H.f != B.f: glog(H, msg, c)

## why one faction cannot start a search against another ('' when it can)
func canFight(A, f, bases: bool) -> String:
	var B = facG(A, f)
	if B == null: return "Unknown faction."
	if A.rel[f] < (5 if bases else 4): return "Relations are " + D.REL[A.rel[f]] + "; " + ("bombarding a base needs war" if bases else "an attack needs embargo or war") + "."
	if surrendered(B, A.f): return nm(B) + " surrendered to you this turn."
	return ""
func fleetTP(g, rollOther: int, enemy: Array) -> int:
	return maxi(0, rollOther) + fl(_sum(enemy.filter(func(u): return uCV(u)), func(u): return u.o.sz) / 7.0) + (2 if has(g, "cc") else (1 if has(g, "amsl") else 0)) + (2 if polLv(g, "mil") >= 3 else 0)
## would the defender rather surrender? (it cannot hurt the attacker, or it is outgunned 2 to 1 and would lose a lot)
func wantSurrender(B, fd: Array, A, fa: Array) -> bool:
	if not _some(fd, func(u): return uCV(u) or u.t == "b"): return false
	var pa := power(A, fa)
	var pb := power(B, fd)
	if pb <= 0: return true
	var est = combatDamage(pa + 5.5 + maxi(0, fd.size() - 1), false)
	var hp: int = _sum(fd, func(u): return uHp(u))
	return pa >= 2 * pb and est >= 0.4 * hp
func doSurrender(A, fa: Array, B, fd: Array) -> void:
	var box := {"room": 0}
	for u in fa:
		if uCV(u): box.room += u.o.cap * cargoMul(A) - sum(u.o.cargo)
	var taken := {"ORE": 0, "SUP": 0, "FUEL": 0}
	var grab := func(r: String, k: int):
		var tk := mini(fl(k / 2.0), box.room)
		if tk > 0:
			taken[r] += tk
			box.room -= tk
	for u in fd:
		if not uCV(u): continue
		for r in RES:
			grab.call(r, u.o.cargo[r])
			u.o.cargo[r] = 0
		u.o.res = true
	for u in fd:
		if u.t != "b": continue
		var k := d10()
		for r in ssort(RES, func(a, b): return u.o.stock[b] - u.o.stock[a]):
			var tk: int = mini(k, u.o.stock[r])
			u.o.stock[r] -= tk
			k -= tk
			grab.call(r, tk)
	var seized := sum(taken)
	for u in fa:
		if not uCV(u): continue
		for r in RES:
			var tk: int = mini(taken[r], u.o.cap * cargoMul(A) - sum(u.o.cargo))
			if tk > 0:
				u.o.cargo[r] += tk
				taken[r] -= tk
	var pm: bool = B.polm > 0
	if pm:
		B.polm -= 1
		A.polm += 1
	if gi(B, "surr", null) == null: B.surr = {}
	B.surr[A.f] = B.y
	blog(A, B, nm(B) + " surrenders to " + nm(A) + ": carried and stockpiled resources are destroyed (" + ((n(seized) + " seized by the victor") if seized else "none seized") + "), its crew vehicles go into reserve" + (" and 1 politics marker is taken" if pm else "") + ".", "x")

## search -> surrender -> tactics points -> (human choice) -> resolve. o: { fa, fd (unit lists), bomb, rA, rD, icept, surr, noAsk }
func startBattle(A, B, key: String, o = null) -> Dictionary:
	if o == null: o = {}
	var fa: Array = o.fa if o.get("fa") != null else cvsAt(A, key).filter(func(s): return armed(s)).map(func(s): return uS(s))
	var fd = o.get("fd")
	if fd == null:
		fd = shipsAt(B, key).map(func(s): return uS(s))
		if t(o.get("bomb")): fd = fd + basesAt(B, key).map(func(b): return uB(b))
	if not fa.size() or not fd.size(): return {"done": true}
	var hasBase := _some(fd, func(u): return u.t == "b")
	var T: int = 4 + maxi(0, fa.filter(func(u): return uCV(u)).size() - 1) + maxi(0, fd.filter(func(u): return uCV(u)).size() - 1)
	var rA: int = o.rA if o.get("rA") != null else d10() - droneMod(A, fa)
	var rB: int = o.rB if o.get("rB") != null else d10() - droneMod(B, fd)
	var where := keyName(key)
	var noAsk := t(o.get("noAsk"))
	var seeA := isHuman(A) and not noAsk
	var seeB := isHuman(B) and not noAsk
	var ok: bool = o.get("rA") != null or hasBase or rA <= T or rB <= T
	if seeA or seeB: (A if seeA else B).ask.append({"k": "search", "ok": ok, "auto": o.get("rA") != null or hasBase, "T": T, "rolls": [{"n": nm(A), "r": rA}, {"n": nm(B), "r": rB}], "where": where,
		"text": (nm(A) + " " + ("intercepts" if t(o.get("icept")) else "finds") + " " + nm(B) + " at " + where + ".") if ok else (nm(A) + " searches for " + nm(B) + " at " + where + " but finds no one.")})
	if not ok:
		blog(A, B, nm(A) + " searches for " + nm(B) + " at " + where + ": no contact (search rolls " + n(rA) + " and " + n(rB) + ", " + n(T) + " or less finds).")
		return {"done": true, "found": false}
	blog(A, B, nm(A) + " " + ("intercepts" if t(o.get("icept")) else "finds") + " " + nm(B) + " at " + where + (" (orbital bombardment)" if hasBase else "") + " (search rolls " + n(rA) + " and " + n(rB) + ").", "e")
	if not _some(fd, func(u): return uCV(u) or u.t == "b"):
		for u in fd:
			if has_obj(B.ships, u.o): loseRE(B, u.o, "is destroyed by " + nm(A))
		return {"done": true, "found": true}
	var offered: bool = t(o.surr) if o.get("surr") != null else wantSurrender(B, fd, A, fa)
	var ctx := {"d": B.f, "key": key, "ia": fa.map(func(u): return u.o.id), "id": fd.filter(func(u): return u.t == "s").map(func(u): return u.o.id), "ib": fd.filter(func(u): return u.t == "b").map(func(u): return u.o.id), "rA": rA, "rB": rB, "noAsk": noAsk}
	if offered:
		# embargo: every surrender must be accepted; war: a fleet's surrender may be refused. Either way a base's surrender must be accepted, but the
		# ships with it can be excluded, fought first and the base's surrender taken afterwards.
		var war: bool = A.rel[B.f] >= 5
		var split: bool = hasBase and _some(fd, func(u): return u.t == "s")
		var canDeny: bool = war and not hasBase
		var choice := "accept"
		if canDeny or split:
			if isHuman(A) and not noAsk:
				A.ask.append({"k": "surrender", "ctx": ctx, "canDeny": canDeny, "split": split, "info": surrenderInfo(A, fa, B, fd), "text": nm(B) + " offers to surrender at " + where + "."})
				return {"pending": true, "found": true}
			choice = botSurrenderChoice(A, fa, B, fd, {"canDeny": canDeny, "split": split})
		return merged(afterOffer(A, B, ctx, choice), {"found": true})
	return merged(tacticsStep(A, B, ctx, null), {"found": true})
## what the attacker would get from accepting a surrender (for the human's prompt and the bot's decision)
func surrenderInfo(A, fa: Array, B, fd: Array) -> Dictionary:
	var cvs := fd.filter(func(u): return uCV(u))
	var bases := fd.filter(func(u): return u.t == "b")
	var room = _sum(fa.filter(func(u): return uCV(u)), func(u): return u.o.cap * cargoMul(A) - sum(u.o.cargo))
	var cargo = _sum(cvs, func(u): return sum(u.o.cargo))
	var stock = 0
	for u in bases: stock += min(5.5, sum(u.o.stock))
	var seize = min(room, fl((cargo + stock) / 2.0))
	return {"cvs": cvs.size(), "cvSize": _sum(cvs, func(u): return u.o.sz), "pm": B.polm > 0, "seize": seize}
## the fight if the surrender is refused: victory markers expected from kills, and what the fight costs us
func fightNet(A, fa: Array, B, fd: Array) -> Dictionary:
	var pa := power(A, fa)
	var pb := power(B, fd)
	var nA := fa.size()
	var nB := fd.size()
	var pool = combatDamage(pa + 5.5 + maxi(0, nB - 1), false)
	var vm := 0
	for u in ssort(fd.filter(func(x): return uCV(x)), func(x, y): return uHp(x) - uHp(y)):
		if pool >= uHp(u):
			pool -= uHp(u)
			vm += markersFor(u.o.sz)
	var back = combatDamage(pb + 5.5 + maxi(0, nA - 1), false) if pb > 0 else 0
	var rc := recall(A) / 100.0
	var weakest = mn(fa.filter(func(u): return uCV(u)).map(func(u): return uHp(u)) + [99])
	var lossRisk = 1 if back >= weakest else back / float(maxi(1, weakest))
	var cost = back * (0.45 + 0.4 * rc) + lossRisk * 2 * (1.5 if fa.filter(func(u): return uCV(u)).size() else 0)
	return {"vm": vm, "cost": cost, "back": back, "oneSided": pb * 3 <= pa or pb == 0}
## attacker's decision on a surrender it may choose to refuse or split
func botSurrenderChoice(A, fa: Array, B, fd: Array, o: Dictionary) -> String:
	var info := surrenderInfo(A, fa, B, fd)
	var pm := 1.5 if info.pm else 0.0
	var resV = info.seize * 0.25
	var reserve = _sum(fd.filter(func(u): return uCV(u)), func(u): return 0.5 + 0.25 * u.o.sz)
	var accept = pm + reserve + resV
	var ships := fd.filter(func(u): return u.t == "s")
	if o.split:
		var f := fightNet(A, fa, B, ships)
		var baseInfo := surrenderInfo(A, fa, B, fd.filter(func(u): return u.t == "b"))
		var excl = f.vm - f.cost + (1.5 if info.pm else 0.0) + baseInfo.seize * 0.25
		return "exclude" if excl > accept else "accept"
	if not o.canDeny: return "accept"
	var f := fightNet(A, fa, B, fd)
	var gain: bool = info.pm or info.seize > 0
	if not gain and f.oneSided: return "deny"
	return "deny" if f.vm - f.cost > accept else "accept"
func afterOffer(A, B, ctx: Dictionary, choice: String) -> Dictionary:
	var fa := unitsOf(A, ctx.ia, [])
	var fd := unitsOf(B, ctx.id, ctx.ib)
	if choice == "accept":
		doSurrender(A, fa, B, fd)
		return {"done": true, "surrendered": true}
	if choice == "exclude":
		blog(A, B, nm(A) + " excludes " + nm(B) + "'s ships from the surrender of the base and fights them first.", "e")
		return tacticsStep(A, B, merged(ctx, {"ib": []}), {"ib": ctx.ib})
	blog(A, B, nm(A) + " refuses the surrender.", "e")
	return tacticsStep(A, B, ctx, null)
func tacticsStep(A, B, ctx: Dictionary, after) -> Dictionary:
	var fa := unitsOf(A, ctx.ia, [])
	var fd := unitsOf(B, ctx.id, ctx.ib)
	var where := keyName(ctx.key)
	if not fa.size() or not fd.size(): return {"done": true}
	var st := {"a": A.f, "d": B.f, "key": ctx.key, "ia": ctx.ia, "id": ctx.id, "ib": ctx.ib, "after": after, "tpA": fleetTP(A, ctx.rB, fd), "tpB": fleetTP(B, ctx.rA, fa), "dA": d10(), "dB": d10(), "noAsk": t(ctx.get("noAsk"))}
	var hA := isHuman(A) and not t(ctx.get("noAsk"))
	var hB := isHuman(B) and not t(ctx.get("noAsk"))
	if hA or hB:
		var me = A if hA else B
		var mine := fa if hA else fd
		var theirs := fd if hA else fa
		var tp: int = st.tpA if hA else st.tpB
		var opp: int = st.tpB if hA else st.tpA
		var cs := battleCalc(A, B, fa, fd, st.dA, st.dB, true)
		var cd := battleCalc(A, B, fa, fd, st.dA, st.dB, false)
		var view := func(c): return {"dealt": c.toB, "taken": c.toA, "tot": c.totA, "otot": c.totB} if hA else {"dealt": c.toA, "taken": c.toB, "tot": c.totB, "otot": c.totA}
		var rem := maxi(0, tp - opp)
		var uname := func(u): return u.o.name if u.t == "s" else "base " + u.o.name
		me.ask.append({"k": "battle", "st": st, "side": "a" if hA else "d", "rem": rem, "lose": tp < opp, "tie": tp == opp, "tp": tp, "opp": opp, "d": st.dA if hA else st.dB, "od": st.dB if hA else st.dA, "strike": view.call(cs), "direct": view.call(cd),
			"mine": mine.map(func(u): return {"n": uname.call(u), "cb": uCb(u)}), "theirs": theirs.map(func(u): return {"n": uname.call(u), "cb": uCb(u)}), "foe": nm(B if hA else A), "where": where,
			"text": "Combat with " + nm(B if hA else A) + " at " + where + "."})
		return {"pending": true}
	return resolveBattle(A, B, st, null)

## the winner of the tactics points spends its remainder
func autoPlan(Wn, En, fw: Array, fe: Array, rem: int, winnerAttacks: bool) -> Dictionary:
	var pw := power(Wn, fw)
	var pe := power(En, fe)
	var mw := has(Wn, "msl")
	var me := has(En, "msl")
	var plan := {"mode": "strike", "extra": 0, "tgt": 0, "avoid": false}
	if rem >= 3 and (pw < 0.45 * pe or (not winnerAttacks and pw < 0.6 * pe)):
		plan.avoid = true
		return plan
	var left := rem
	var direct: bool = left >= 1 and ((winnerAttacks if (not mw and not me) else (true if (me and not mw) else (mw and me and pw < pe))))
	if direct:
		plan.mode = "direct"
		left -= 1
	plan.extra = fl(left / 2.0)
	left -= plan.extra * 2
	plan.tgt = left
	return plan
## who takes the next hit. mode 'strike': the inflicter picks (weakest armed unit first); 'direct': the receiver picks (sturdiest unarmed unit
## first). forced 'kill' / 'soak': a tactics-point pick by the winner, on the enemy's weakest armed unit or on its own sturdiest unarmed one.
func pickUnit(us: Array, mode: String, forced):
	var live := us.filter(func(u): return not t(u.get("dead")))
	if not live.size(): return null
	var pool := live.filter(func(u): return not t(u.get("screen"))) if (mode == "direct" and forced == null) else live
	if not pool.size(): pool = live
	var weak := func(a, b):
		var d: int = int(uCb(b) > 0) - int(uCb(a) > 0)
		return d if d != 0 else uHp(a) - uHp(b)
	var tough := func(a, b):
		var d: int = int(uCb(a) > 0) - int(uCb(b) > 0)
		return d if d != 0 else uHp(b) - uHp(a)
	return ssort(pool, weak if (forced == "kill" or (forced == null and mode == "strike")) else tough)[0]
# Base hits (3.4): each hit is spent on one facility (it takes a damage marker; downgraded or removed when damage equals its
# size), on the settlements (each 3 damage removes one settlement), or on resources (each hit destroys 2 resources).
# A base with no facilities or settlements is destroyed by a single hit. Hits are collected per base and assigned afterwards.
const FAC4 := ["def", "lab", "mine", "sup"]
const TGT := ["def", "lab", "mine", "sup", "set"]
const SETDEF := 3
func facHits(b, c: String) -> int:
	if c == "set": return maxi(0, int(gi(b, "set", 0)) * SETDEF - int(gi(b, "setHits", 0)))
	var l: int = b.fac[c]
	var h: int = -int(gi(b.dmg, c, 0))
	while l > 0:
		h += sizeOfFac(c, l)
		l = DOWNFAC[c][l]
	return maxi(0, h)
func bldgHits(b) -> int:  # hits the base can soak before one destroys it
	var f := 0
	for c in TGT: f += facHits(b, c)
	return f + ce(sum(b.stock) / 2.0) if f else 0
func baseCaps(b) -> Dictionary:
	var c := {}
	for k in TGT: c[k] = facHits(b, k)
	c.res = ce(sum(b.stock) / 2.0) if _some(TGT, func(k): return c[k] > 0) else 0
	return c
func autoAlloc(b, k: int) -> Dictionary:
	var caps := baseCaps(b)
	var al := {"def": 0, "lab": 0, "mine": 0, "sup": 0, "set": 0, "res": 0}
	for c in TGT:
		var tk: int = mini(k, caps[c])
		al[c] = tk
		k -= tk
	return al
func applyAlloc(b, al: Dictionary, resPick = null) -> Dictionary:
	var lost := 0
	var destroyed := 0
	for i in int(num(gi(al, "res", 0))) * 2:  # resources first: they are only a valid target while a facility stands
		var r = null
		if resPick != null: r = _find(RES, func(x): return resPick[x] > 0 and b.stock[x] > 0)
		if r == null: r = ssort(RES, func(x, y): return b.stock[y] - b.stock[x])[0]
		if b.stock[r] > 0:
			b.stock[r] -= 1
			destroyed += 1
			if resPick != null and resPick[r] > 0: resPick[r] -= 1
	for c in FAC4:
		for i in int(num(gi(al, c, 0))):
			b.dmg[c] += 1
			if b.dmg[c] >= sizeOfFac(c, b.fac[c]):
				b.fac[c] = DOWNFAC[c][b.fac[c]]
				b.dmg[c] = 0
				lost += 1
	for i in int(num(gi(al, "set", 0))):
		b.setHits = int(gi(b, "setHits", 0)) + 1
		if b.setHits >= SETDEF:
			b.set = maxi(0, b.set - 1)
			b.setHits = 0
			lost += 1
	b.setDmg = 1 if (int(gi(b, "setHits", 0)) > 0 and b.set > 0) else 0  # the damaged settlement does not count
	return {"lost": lost, "destroyed": destroyed}
func checkAlloc(b, k: int, al):
	var caps := baseCaps(b)
	var tt := 0
	for c in TGT + ["res"]:
		var v := fl(num(gi(al, c, 0)))
		if v < 0 or v > caps[c]: return "Too many hits on " + c + "."
		tt += v
	return null if tt == k else "Assign exactly " + n(k) + " hit" + ("s" if k > 1 else "") + "."
func _mkOut() -> Dictionary: return {"hits": {}, "lostCV": [], "lostRE": [], "lostB": [], "facLost": 0, "pend": []}
func applyHit(g, u, out) -> void:
	if u.t == "s":
		var s = u.o
		if s.cls != "CV":
			u.dead = true
			out.lostRE.append(s)
			return
		s.dmg += 1
		if not out.hits.has(s.id): out.hits[s.id] = {"s": s, "n": 0}
		out.hits[s.id].n += 1
		if s.dmg >= s.sz:
			u.dead = true
			out.lostCV.append(s)
		return
	var b = u.o
	u.bh = int(gi(u, "bh", 0)) + 1
	if u.bh > bldgHits(b):
		u.dead = true
		out.lostB.append(b)
		if out.pend != null: out.pend = out.pend.filter(func(p): return not is_same(p.b, b))
		return
	if out.pend == null:  # direct use (tests): assign at once
		applyAlloc(b, autoAlloc(b, 1))
		out.facLost += 1
		return
	var p = _find(out.pend, func(x): return is_same(x.b, b))
	if p == null:
		p = {"b": b, "n": 0}
		out.pend.append(p)
	p.n += 1
func resolveBattle(A, B, st: Dictionary, plan) -> Dictionary:
	var r := resolveBattle0(A, B, st, plan)
	if t(st.get("after")):
		var fa := unitsOf(A, st.ia, []).filter(func(u): return not t(u.o.res))
		var fb := unitsOf(B, [], st.after.ib)
		if fa.size() and fb.size(): doSurrender(A, fa, B, fb)
	return r
## combat totals and damage: each side's combat values + d10 + 1 per extra enemy unit, looked up on the strike / direct-fire table. A is the attacker.
func battleCalc(A, B, fa: Array, fb: Array, dA: int, dB: int, strike: bool) -> Dictionary:
	var total := func(g, f, e, d): return power(g, f) + d + maxi(0, e.size() - 1)
	# strike: fighter drones cancel enemy damage one for one; Bomber Drones are flown by the side that attacks
	var dmg := func(g, tot, attacking, other, otherUs, mine):
		if strike and not has(g, "msl"): return 0
		var d = combatDamage(tot, strike)
		if strike:
			if has(g, "bd") and attacking: d += droneCount(g, mine)
			d -= droneCount(other, otherUs)
		return maxi(0, d)
	var totA: int = total.call(A, fa, fb, dA)
	var totB: int = total.call(B, fb, fa, dB)
	return {"totA": totA, "totB": totB, "toB": dmg.call(A, totA, true, B, fb, fa), "toA": dmg.call(B, totB, false, A, fa, fb)}
func _ukey(u) -> String: return u.t + str(u.o.id)
func resolveBattle0(A, B, st: Dictionary, plan) -> Dictionary:
	var fa := unitsOf(A, st.ia, [])
	var fb := unitsOf(B, st.id, st.ib)
	if not fa.size() or not fb.size(): return {"done": true}
	var aWins: bool = st.tpA > st.tpB
	var tie: bool = st.tpA == st.tpB
	var rem: int = absi(st.tpA - st.tpB)
	var Wn = A if aWins else B
	var En = B if aWins else A
	var fw := fa if aWins else fb
	var fe := fb if aWins else fa
	if tie or plan == null: plan = {"mode": "strike", "extra": 0, "tgt": 0, "avoid": false} if tie else autoPlan(Wn, En, fw, fe, rem, aWins)
	if t(plan.get("avoid")):
		blog(A, B, nm(Wn) + " spends 3 tactics points to call off the combat at " + keyName(st.key) + ".")
		return {"done": true, "avoided": true}
	var strike: bool = plan.get("mode") != "direct"
	var dA: int = st.dA if st.get("dA") != null else d10()
	var dB: int = st.dB if st.get("dB") != null else d10()
	var bc := battleCalc(A, B, fa, fb, dA, dB, strike)
	var totA: int = bc.totA
	var totB: int = bc.totB
	var toB: int = bc.toB
	var toA: int = bc.toA
	if not tie:
		if aWins:
			toB += int(gi(plan, "extra", 0))
			toA = maxi(0, toA - int(gi(plan, "red", 0)))
		else:
			toA += int(gi(plan, "extra", 0))
			toB = maxi(0, toB - int(gi(plan, "red", 0)))
	# the order of hits and who chooses each target: strike = the inflicting side, direct fire = the receiving side, a tactics-point pick = the winner
	var seq := []
	var ca := toB
	var cb := toA
	var pk: int = 0 if tie else int(gi(plan, "tgt", 0))
	while ca > 0 or cb > 0:
		for aH in [true, false]:
			if (ca > 0) if aH else (cb > 0):
				if aH: ca -= 1
				else: cb -= 1
				var forced = null
				if pk > 0:
					pk -= 1
					forced = "kill" if aH == aWins else "soak"
				var ch: String
				if forced != null: ch = "a" if aWins else "d"
				elif strike: ch = "a" if aH else "d"
				else: ch = "d" if aH else "a"
				seq.append({"aH": aH, "forced": forced, "ch": ch})
	var hmn := {"a": isHuman(A) and not t(st.get("noAsk")), "d": isHuman(B) and not t(st.get("noAsk"))}
	# a human who picks targets (or screens in direct fire) is asked before the hits are dealt
	if not t(st.get("asg")) and (hmn.a or hmn.d):
		var me := "a" if hmn.a else "d"
		var G0 = A if hmn.a else B
		var mineU := fa if hmn.a else fb
		var foeU := fb if hmn.a else fa
		var nOn := func(aH): return seq.filter(func(x): return x.aH == aH and x.ch == me).size()
		var grp := func(side, us, k): return {"side": side, "n": k, "units": us.map(func(u): return {"key": _ukey(u), "n": u.o.name if u.t == "s" else "base " + u.o.name, "cb": uCb(u), "hp": uHp(u)})}
		var groups := []
		var onFoe: int = nOn.call(hmn.a)
		var onMine: int = nOn.call(not hmn.a)
		if onFoe: groups.append(grp.call("foe", foeU.filter(func(u): return strike or not (u.t == "s" and uCb(u) == 0 and _some(foeU, func(x): return x.t == "s" and uCb(x) > 0))), onFoe))
		if onMine: groups.append(grp.call("mine", mineU, onMine))
		var screenable := mineU.filter(func(u): return uCb(u) == 0).map(func(u): return {"key": _ukey(u), "n": u.o.name if u.t == "s" else "base " + u.o.name}) if (not strike and _some(mineU, func(u): return u.t == "s" and uCb(u) > 0)) else []
		if groups.size() or (screenable.size() and _some(seq, func(x): return x.aH != hmn.a)):
			G0.ask.append({"k": "assign", "st": st, "plan": plan, "me": me, "groups": groups, "screen": screenable, "strike": strike, "hits": {"foe": seq.filter(func(x): return x.aH == hmn.a).size(), "mine": seq.filter(func(x): return x.aH != hmn.a).size()},
				"text": ("Strike" if strike else "Direct fire") + " at " + keyName(st.key) + ": assign the damage."})
			return {"pending": true}
	if not strike:
		for pr in [[fa, st.get("scr") if hmn.a else null], [fb, st.get("scr") if hmn.d else null]]:
			var f: Array = pr[0]
			var scr = pr[1]
			if _some(f, func(u): return u.t == "s" and uCb(u) > 0):
				for u in f:
					if (scr.has(_ukey(u)) if scr != null else uCb(u) == 0): u.screen = true
	var outA := _mkOut()
	var outB := _mkOut()
	var asg := {"fa": gi(gi(st, "asg", {}), "fa", []).duplicate(), "fb": gi(gi(st, "asg", {}), "fb", []).duplicate()}
	var hit := func(x) -> bool:
		var us := fb if x.aH else fa
		var g = B if x.aH else A
		var o := outB if x.aH else outA
		var u = null
		if hmn[x.ch]:
			var q: Array = asg["fb" if x.aH else "fa"]
			while q.size() and u == null:
				var k = q.pop_front()
				u = _find(us, func(z): return _ukey(z) == String(k) and not t(z.get("dead")))
		if u == null: u = pickUnit(us, "strike" if strike else "direct", x.forced)
		if u == null: return false
		applyHit(g, u, o)
		return true
	var nA := toB
	var nB := toA
	var stopped := {true: false, false: false}
	for x in seq:
		if stopped[x.aH]: continue
		if not hit.call(x): stopped[x.aH] = true
	blog(A, B, "Combat at " + keyName(st.key) + " (" + ("strike" if strike else "direct fire") + "): " + nm(A) + " rolls " + n(totA) + " for " + n(nA) + " damage, " + nm(B) + " rolls " + n(totB) + " for " + n(nB) + " damage" + ((" (" + nm(Wn) + " spends tactics points)") if (not tie and (t(plan.get("extra")) or t(plan.get("red")) or t(plan.get("tgt")))) else "") + ".", "e")
	_post(A, B, A, B, outA)
	_post(A, B, B, A, outB)
	return {"done": true, "fought": true}
func _post(A, B, g, other, o: Dictionary) -> void:
	for s in o.lostRE: removeShip(g, s)
	for s in o.lostCV:
		removeShip(g, s)
		var got := []
		for i in markersFor(s.sz): got.append(drawMarker(g, "Eng"))
		other.vm += markersFor(s.sz)
		blog(A, B, nm(g) + "'s " + s.name + " (CV-" + n(s.sz) + ") is destroyed. " + nm(other) + " earns " + n(markersFor(s.sz)) + " victory marker" + ("s" if markersFor(s.sz) > 1 else "") + "; " + nm(g) + " learns " + markerTxt(got, "Eng") + ".", "x")
	for b in o.lostB:
		g.bases = without(g.bases, b)
		if g.lv != null: g.lv.erase(b.id)
		var got := [drawMarker(g, "Eng")]
		blog(A, B, nm(g) + "'s base " + b.name + " is destroyed. " + nm(g) + " learns " + markerTxt(got, "Eng") + ".", "x")
	for p in o.pend:
		if not has_obj(g.bases, p.b): continue
		if isHuman(other):
			other.ask.append({"k": "basehit", "f": g.f, "base": p.b.id, "name": p.b.name, "n": p.n, "caps": baseCaps(p.b), "stock": p.b.stock.duplicate(), "text": "Your fleet hit " + nm(g) + "'s base " + p.b.name + " " + n(p.n) + " time" + ("s" if p.n > 1 else "") + ". Choose what is hit."})
			continue
		var r := applyAlloc(p.b, autoAlloc(p.b, p.n))
		o.facLost += r.lost
	if o.facLost: blog(A, B, nm(g) + " loses or downgrades " + n(o.facLost) + " facilit" + ("ies" if o.facLost > 1 else "y") + ".", "x")
	for h in o.hits.values():
		var s = h.s
		for i in h.n:
			if not has_obj(g.ships, s) or t(s.res): break
			recallCheck(g, s)

# ---- interception (3.3.6): hostile armed fleets where a ship is leaving. -> { r: 'go' | 'dead' | 'caught', g, key, rA, rB }
func interceptCheck(G, s, from: String) -> Dictionary:
	var key = keyOf(from)
	if key == null: return {"r": "go"}
	for g in others(G):
		if g.rel[G.f] < 4 or surrendered(G, g.f) or isHuman(g): continue  # only bot-run fleets intercept by themselves
		var fi := cvsAt(g, key).filter(func(x): return armed(x))
		if not fi.size(): continue
		var fiU := fi.map(func(x): return uS(x))
		var me := [uS(s)]
		var T: int = 4 + maxi(0, fi.size() - 1)
		var rA: int = d10() - droneMod(g, fiU)
		var rB: int = d10() - droneMod(G, me)
		if not (rA <= T or rB <= T): continue
		if s.cls != "CV":
			blog(g, G, nm(g) + " intercepts " + s.name + " leaving " + keyName(key) + ": it is destroyed.", "x")
			loseRE(G, s, "is destroyed by " + nm(g))
			return {"r": "dead"}
		# a bot only intercepts when it is not outgunned
		if power(g, fiU) < 0.8 * power(G, me) and cbOf(s) > 0: continue
		blog(g, G, nm(g) + " intercepts " + s.name + " leaving " + keyName(key) + " (search rolls " + n(rA) + " and " + n(rB) + ").", "e")
		return {"r": "caught", "g": g, "key": key, "rA": rA, "rB": rB}
	return {"r": "go"}
func interceptFight(G, s, c: Dictionary, surrender: bool) -> Dictionary:
	var fi := cvsAt(c.g, c.key).filter(func(x): return armed(x)).map(func(x): return uS(x))
	return startBattle(c.g, G, c.key, {"fa": fi, "fd": [uS(s)], "rA": c.rA, "rB": c.rB, "icept": true, "surr": surrender, "noAsk": true})
## a bot-run mover decides: fight when it is armed and not outgunned, otherwise stop
func interceptAuto(G, s, c: Dictionary) -> String:
	var pa := power(c.g, cvsAt(c.g, c.key).filter(func(x): return armed(x)).map(func(x): return uS(x)))
	var pm := power(G, [uS(s)])
	return "fight" if (pm > 0 and pm >= 0.8 * pa) else "stop"
func fleetPower(G, o: Dictionary) -> Dictionary:
	var f = facG(G, o.f)
	if f == null: return {"mine": 0, "theirs": 0, "hp": 0}
	var fd: Array = shipsAt(f, o.key).map(func(x): return uS(x)) + (basesAt(f, o.key).map(func(b): return uB(b)) if o.k == "bombard" else [])
	return {"mine": power(G, cvsAt(G, o.key).filter(func(x): return armed(x)).map(func(x): return uS(x))), "theirs": power(f, fd), "hp": _sum(fd, func(u): return uHp(u)), "unarmed": not _some(fd, func(u): return uCb(u) > 0)}
func factionCombatOptions(G) -> Array:
	var out := []
	for g in others(G):
		if G.rel[g.f] < 4 or surrendered(g, G.f): continue
		var keys := []
		for s in G.ships:
			if armed(s):
				var k = keyOf(s.loc)
				if k != null and not keys.has(k): keys.append(k)
		for key in keys:
			var mine := cvsAt(G, key).filter(func(x): return armed(x))
			if shipsAt(g, key).size(): out.append({"k": "fleet", "f": g.f, "key": key, "label": "Attack " + nm(g) + " ships at " + keyName(key)})
			for b in basesAt(g, key):
				if G.rel[g.f] >= 5: out.append({"k": "bombard", "f": g.f, "key": key, "label": "Bombard " + nm(g) + " base " + b.name + " at " + keyName(key)})
				if not (t(gi(b, "blk", false)) and gi(b, "blkBy", null) == G.f) and _sum(mine, func(x): return cbOf(x)) >= dnOf(b): out.append({"k": "fblock", "f": g.f, "key": key, "base": b.id, "label": "Blockade " + nm(g) + " base " + b.name + " at " + keyName(key)})
	# one search per location per turn: hide the ones already used
	return out.filter(func(o): return not t(G.turn.acted.get("c:fb:" + o.base)) if o.k == "fblock" else not t(G.turn.acted.get("c:" + o.key)))
func factionAct(G, o: Dictionary):
	var g = facG(G, o.f)
	if g == null: return "Unknown faction."
	var err := canFight(G, o.f, o.k == "bombard")
	if err != "": return err
	if not _some(cvsAt(G, o.key), func(x): return armed(x)): return "You have no armed crew vehicle there."
	if o.k == "fblock":
		if t(G.turn.acted.get("c:fb:" + o.base)): return "Already blockading this turn."
		var b = _baseById(g, o.base)
		if b == null: return "That base is gone."
		if _sum(cvsAt(G, o.key).filter(func(x): return armed(x)), func(x): return cbOf(x)) < dnOf(b): return "Your fleet needs combat values at least equal to the Defense Network."
		G.turn.acted["c:fb:" + o.base] = 1
		b.blk = true
		b.blkBy = G.f
		b.trade = null
		blog(G, g, nm(G) + " blockades " + nm(g) + "'s base " + b.name + " at " + W[b.w].n + ": its output is halved, its settlements decline and it cannot trade; " + nm(G) + " earns $2B each production step.", "x")
		return null
	if t(G.turn.acted.get("c:" + o.key)): return "Each fleet may search once per turn."
	G.turn.acted["c:" + o.key] = 1
	startBattle(G, g, o.key, {"bomb": o.k == "bombard"})
	return null
## blockades lapse unless the blockading fleet is still there with enough combat value
func lapseBlockades(G) -> void:
	for g in others(G):
		for b in g.bases:
			if not t(gi(b, "blk", false)) or gi(b, "blkBy", null) != G.f: continue
			var f := cvsAt(G, "w:" + b.w).filter(func(x): return armed(x))
			if not (f.size() and _sum(f, func(x): return cbOf(x)) >= dnOf(b) and G.rel[g.f] >= 4):
				b.blk = false
				b.blkBy = null
				blog(G, g, nm(G) + "'s blockade of " + b.name + " ends.")

# ================= EXPLORATION =================
func startExplore(G) -> void: glog(G, n(G.y) + ": exploration.", "h")
func endExplore(G) -> void:
	# flybys sitting in a flyby box must make their outward transfer
	for s in G.ships.filter(func(x): return x.kind == "Flyby" and P(x.loc).t == "fly" and not t(G.turn.acted.get(x.id))):
		var nxt = _first(outward(G, P(s.loc).s))
		flybyTransfer(G, s, nxt.sys if nxt != null else null)
func outward(G, sy) -> Array:
	return D.SYS_ORDER.filter(func(x): return SYS[x].t > SYS[sy].t and x != "alp").map(func(x): return {"sys": x, "eta": transfer(G, sy, x)})
func flybyTransfer(G, s, sy):
	if sy == null or not t(sy):
		removeShip(G, s)
		glog(G, "Flyby " + s.name + " has no system farther out and leaves the solar system.")
		return null
	var er := engineRoll(G, engBase(G))
	if er.fail:
		loseRE(G, s, "is lost to an engine failure on its heliocentric transfer (engine roll " + n(er.r) + ")")
		return null
	var tt := transfer(G, P(s.loc).s, sy)
	s.loc = boxFor(sy, tt)
	s.hold = maxi(0, tt - 6)
	glog(G, "Flyby " + s.name + " makes a heliocentric transfer toward " + SYS[sy].n + " (" + n(tt) + " turns, engine roll " + n(er.r) + ").")
	return null
## what can this ship explore now? [{w, kind:'explore'|'probe'|'produce'|'harvest', value, pen}]
func exploreOptions(G, s) -> Array:
	if G.phase != "explore" or t(G.turn.acted.get(s.id)) or G.over: return []
	var p := P(s.loc)
	var out := []
	var add := func(w, kind: String, pen = 0, why = null):
		if G.w[w].v < 1 and kind != "produce": return
		var pn: int = pen if pen != null else 0
		if kind != "produce" and kind != "harvest" and exploreValue(G, s, w, kind == "probe", pn) <= 0: return
		out.append({"w": w, "kind": kind, "pen": pn, "why": why, "value": exploreValue(G, s, w, kind == "probe", pn)})
	if s.cls == "RE":
		if s.kind == "Telescope":
			if s.loc == "orbit:ear":
				for w in W.keys():
					if w != "alp" and w != "ear": add.call(w, "explore")
			return ssort(out, func(a, b): return b.value - a.value)
		if s.kind == "Flyby":
			# a Flyby in a transfer box is penalised by the turns it still has to travel: its box number plus any turns held beyond box 6
			if p.t == "box" or p.t == "fly":
				for w in worldsIn(p.s):
					if not W[w].tags.has("tele"):
						add.call(w, "explore", p.n + (int(orv(s.hold, 0)) if p.t == "box" else 0))
						if t(s.probe) and p.t == "fly": add.call(w, "probe", 0)
			return out
		if not t(s.fixed): return out
		var w = worldOf(s.loc)
		add.call(w, "explore")
		if t(s.probe): add.call(w, "probe")
		if s.kind == "Orbiter" and SYS[W[w].sys].hub == w:
			for x in worldsIn(W[w].sys):
				if x != w and not W[x].tags.has("tele"): add.call(x, "explore", 0 if isSun(x) else 1)
		# rovers cannot explore the Sun, even from Mercury
		if s.kind == "Rover": return out.filter(func(o): return not isSun(o.w))
		return out
	# CV
	if t(s.res) or p.t == "box": return out
	if p.t == "fly":
		if t(s.prod) and has(G, "mine") and t(G.fly[p.s].ast): out.append({"w": null, "kind": "harvest", "value": 0})
		return out
	var w = worldOf(s.loc)
	# severe atmospheres (Venus, gas giants) need Pressure Shell for any crewed exploration or production; gas giants are never explored by crew
	var atmOk: bool = not W[w].tags.has("severeAtm") or has(G, "psh")
	if atmOk and not W[w].tags.has("gas") and not W[w].tags.has("tele") and s.ev - s.dmg > 0: add.call(w, "explore")
	if atmOk and t(s.prod) and has(G, "mine") and not _some(G.bases, func(b): return b.w == w):
		for r in RES:
			var v := prodValue(G, w, r)
			if v >= 1: out.append({"w": w, "kind": "produce", "res": r, "value": v})
	return out
func cardFor(G, w):
	var c = G.w[w].card
	return _find(D.CARDS, func(x): return x.n == c) if t(c) else null
func cardBonus(G, s, w, probe: bool) -> int:
	var c = cardFor(G, w)
	if c == null: return 0
	var b: Dictionary = c.bonus
	var k: int = gi(b, "all", 0)
	if probe: return k + int(gi(b, "probe", 0))
	if s.cls == "CV": return k + int(gi(b, "crew", 0))
	if s.kind == "Rover": k += int(gi(b, "rover", 0))
	if s.kind == "Orbiter": k += int(gi(b, "orbiter", 0))
	if s.kind == "Flyby": k += int(gi(b, "flyby", 0))
	if t(s.spec): k += int(gi(b, "spec", 0))
	return k
func exploreValue(G, s, w, probe: bool, pen := 0) -> int:
	var wv: int = G.w[w].v
	if s.kind == "Telescope": wv = rnd_i(wv / 2.0 + 1e-9)
	var unit: int = 9 if probe else ((s.ev - s.dmg) if s.cls == "CV" else s.ev)
	var tech: int = crewBonus(G) if (s.cls == "CV" and not probe) else roboBonus(G)
	return wv + unit + tech + cardBonus(G, s, w, probe) - pen
func malfRate(G, s) -> int:
	var r := malfBase(G)
	var sy = sysOf(s.loc)
	var w = worldOf(s.loc)
	if not has(G, "ars") and (sy == "mer" or (w != null and W[w].tags.has("rad"))): r += 10
	if s.kind == "Rover" and w == "ven" and not has(G, "psh"): r += 20
	return r
func lifeSearch(G, w, base: int) -> Dictionary:
	var ws = G.w[w]
	var cf = cardFor(G, w)
	var lc: int = base + (cf.lifeB if cf != null else 0)
	var bonus: String = (" (" + n(base) + "% + " + n(cf.lifeB) + "% from " + ws.card + ")") if (cf != null and t(cf.lifeB)) else ""
	if t(ws.life): return {"info": {"skip": "existing life already found here"}, "msg": ""}
	if not lc: return {"info": {"skip": W[w].n + " has no chance of life"}, "msg": ""}
	if t(ws.sol) and not has(G, "sol"): return {"info": {"skip": "searching for existing life needs the Signs of Life technology"}, "msg": ""}
	var lr := d100()
	var seek := "existing life" if t(ws.sol) else "signs of life"
	var found := lr <= lc
	var info := {"r": lr, "need": lc, "seek": seek, "found": found, "bonus": bonus}
	var msg := " Search for life: rolled " + n(lr) + " on d100, needed " + n(lc) + " or less" + bonus
	if not found: return {"info": info, "msg": msg + ": no " + seek + "."}
	if not t(ws.sol):
		ws.sol = true
		var b := [drawMarker(G, "Bio"), drawMarker(G, "Bio")]
		G.vm += 1
		G.polm += 1
		info.reward = markerTxt(b, "Bio") + ", +1 victory marker, +1 politics marker"
		if not has(G, "sol"):
			G.tech.sol = 1
			info.reward += "; you gain the Signs of Life technology"
		return {"info": info, "msg": msg + ": signs of life! " + info.reward + "."}
	ws.life = true
	var b := []
	for i in 4: b.append(drawMarker(G, "Bio"))
	G.vm += 2
	G.polm += 2
	info.reward = markerTxt(b, "Bio") + ", +2 victory markers, +2 politics markers"
	if not has(G, "exl"):
		G.tech.exl = 1
		info.reward += "; you gain the Existing Life technology"
	return {"info": info, "msg": msg + ": existing life! " + info.reward + "."}
func explore(G, s, opt: Dictionary):
	var o = _find(exploreOptions(G, s), func(x): return eq(x.w, opt.get("w")) and x.kind == opt.kind and (not t(opt.get("res")) or x.get("res") == opt.res))
	if o == null: return s.name + " cannot do that now."
	G.turn.acted[s.id] = 1
	if o.kind == "produce": return produceCV(G, s, o.w, o.res)
	if o.kind == "harvest": return harvest(G, s)
	var w = o.w
	var ws = G.w[w]
	var probe: bool = o.kind == "probe"
	var cv: bool = s.cls == "CV" and not probe
	var val: int = maxi(0, o.value)
	var field: String = W[w].f
	var lifeChance: int = W[w].life
	if w == "alp": G.alpha["cv" if cv else "re"] = true
	var auto: int = val / 10
	var rem: int = val % 10
	var r1 := d10()
	var two: bool = (cv and t(s.lab)) or (s.kind == "Telescope" and G.f == "eu")
	var r2 = d10() if two else null
	var r: int = mini(r1, r2) if two else r1
	var hit: bool = rem > 0 and r <= rem
	var k: int = auto + (1 if hit else 0)
	# Alpha Centauri: its field (and life chance) is decided by a d10 rolled after each successful exploration
	var aRoll = null
	if w == "alp" and k > 0:
		aRoll = d10()
		var a = _find(D.ALPHA, func(x): return aRoll <= x[0])
		field = a[1]
		lifeChance = a[2]
	var got := []
	for i in k: got.append(drawMarker(G, field))
	var who: String = ("Probe " + s.probe + " (from " + s.name + ")") if probe else s.name
	var rollTxt := "rolled " + n(r) + ((" (best of " + n(r1) + " and " + n(r2) + ")") if two else "") + " on d10"
	var need := ("needs " + n(rem) + " or less") if rem else "no roll needed"
	var res: String
	if not k: res = rollTxt + ", " + need + ": failure."
	elif not rem: res = n(auto) + " automatic marker(s): " + markerTxt(got, field) + "."
	else: res = ((n(auto) + " automatic marker(s), then ") if auto else "") + rollTxt + ", " + need + ": " + ("success" if hit else "no extra marker") + ". Earned " + markerTxt(got, field) + "."
	var msg: String = who + " explores " + W[w].n + ((" from transfer box " + n(o.pen)) if t(o.pen) else "") + " at value " + n(val) + ": " + res
	if aRoll != null: msg += " Alpha Centauri field roll " + n(aRoll) + " on d10: " + FN[field] + " (" + n(lifeChance) + "% life chance)."
	G.lastRoll = {"who": who, "world": W[w].n, "val": val, "auto": auto, "rem": rem, "r": r, "r1": r1, "r2": r2, "hit": hit, "got": got.duplicate(), "field": field, "ok": k > 0, "extra": [], "alpha": aRoll}
	var total: int = _sum(got, func(v): return v)
	# depletion (max one per exploration): robotic explorers and probes when any single marker earned is 3 or more;
	# crewed vehicles when the earned markers add up to 3 or more
	if (total >= 3) if cv else _some(got, func(v): return v >= 3):
		ws.v = maxi(0, ws.v - 1)
		G.polm += 1
		msg += " Depletion (" + (("markers total " + n(total)) if cv else ("a " + n(_find(got, func(v): return v >= 3)) + "-point marker")) + "): " + W[w].n + " drops to " + n(ws.v) + "; +1 politics marker."
		G.lastRoll.extra.append("Depletion: " + W[w].n + " drops to " + n(ws.v) + ".")
		# missions (telescopes never count)
		if s.kind != "Telescope":
			for pair in [["mine", "Your"], ["common", "The common"]]:
				var id = G.mis[pair[0]]
				if id == null: continue
				var m: Dictionary = D.MIS[id]
				if m.w != w or (m.cv and not cv): continue
				msg += completeMission(G, id, pair[1])
				G.mis[pair[0]] = drawMission(G)
			var did = gi(ws, "dmis", null)
			if did != null and (not D.MIS[did].cv or cv):
				ws.dmis = null
				msg += completeMission(G, did, "The dated")
		# a mission token on a world that has dropped to 0 is removed (personal / common ones are redrawn)
		if ws.v == 0:
			if gi(ws, "dmis", null) != null:
				msg += " The dated mission " + misTxt(ws.dmis) + " is removed (" + W[w].n + " is fully depleted)."
				ws.dmis = null
			for slot in ["mine", "common"]:
				var id = G.mis[slot]
				if id != null and D.MIS[id].w == w:
					G.mis[slot] = drawMission(G)
					msg += " " + misTxt(id) + " can no longer be completed and is replaced."
		# world card
		if t(W[w].base) or W[w].tags.has("gas"):
			var draws := 2 if (t(s.spec) and not probe and s.cls == "RE") else 1
			var opts := []
			for i in draws:
				var c: Dictionary = pick(D.CARDS)
				var fits := cardOk(c, W[w])
				var dup: bool = fits and opts.has(c.n)
				if fits and not dup: opts.append(c.n)
				glog(G, "World card " + c.n + " drawn for " + W[w].n + (", does not apply." if not fits else (" again (same card)." if dup else ".")), "" if fits else "e")
			if opts.size(): G.ask.append({"k": "card", "w": w, "opts": opts, "text": "Depletion at " + W[w].n + ": you drew " + " and ".join(opts) + ". Place a card on the world or return it to the deck."})
			elif not t(ws.card) and ws.v == 0:
				var ok = D.CARDS.filter(func(c): return cardOk(c, W[w]))
				if ok.size():
					var c: Dictionary = pick(ok)
					ws.card = c.n
					msg += " Final depletion: " + c.n + " is placed."
					glog(G, "World card " + c.n + " drawn and placed on " + W[w].n + " (final depletion).", "g")
		# search for life: if a world card is waiting to be placed, the roll waits for it (cards like Water Ice add to the chance)
		var cardAsk = _find(G.ask, func(q): return q.k == "card" and eq(q.w, w) and not t(q.get("life")))
		if cardAsk != null:
			cardAsk.life = {"base": lifeChance}
			G.lastRoll.life = {"pending": true}
		else:
			var L := lifeSearch(G, w, lifeChance)
			G.lastRoll.life = L.info
			msg += L.msg
		# missions on depleted worlds get replaced
		for slot in ["mine", "common"]:
			var id = G.mis[slot]
			if id != null and G.w[D.MIS[id].w].v < 1: G.mis[slot] = drawMission(G)
	glog(G, msg, "g")
	# after effects
	if probe:
		glog(G, "Probe " + s.probe + " is spent; " + s.name + " does not search this turn.")
		s.probe = null
		if s.kind == "Flyby" and P(s.loc).t == "fly": afterFlybyBox(G, s)
		return null
	if cv:
		var rc := d100()
		var rv := recall(G)
		if rc <= rv:
			s.res = true
			var b := drawMarker(G, "Bio")
			glog(G, "Recall roll " + n(rc) + " (recalled on " + n(rv) + " or less): " + s.name + " is recalled and goes into reserve (+" + n(b) + " Biology).")
			G.lastRoll.extra.append("Recall roll " + n(rc) + " of " + n(rv) + "%: recalled.")
		else:
			glog(G, "Recall roll " + n(rc) + " (recalled on " + n(rv) + " or less): " + s.name + " stays active.")
			G.lastRoll.extra.append("Recall roll " + n(rc) + " of " + n(rv) + "%: stays active.")
		return null
	var mr := d100()
	var mvr := malfRate(G, s)
	if mr <= mvr:
		G.lastRoll.extra.append("Malfunction roll " + n(mr) + " of " + n(mvr) + "%: lost.")
		loseRE(G, s, "malfunctions and is lost (malfunction roll " + n(mr) + ", lost on " + n(mvr) + " or less)")
		return null
	glog(G, "Malfunction roll " + n(mr) + " (lost on " + n(mvr) + " or less): " + s.name + " keeps working.")
	G.lastRoll.extra.append("Malfunction roll " + n(mr) + " of " + n(mvr) + "%: keeps working.")
	if s.kind == "Flyby" and P(s.loc).t == "fly": afterFlybyBox(G, s)
	return null
func afterFlybyBox(G, s) -> void:
	var opts := outward(G, P(s.loc).s)
	if not opts.size():
		removeShip(G, s)
		glog(G, "Flyby " + s.name + " leaves the solar system.")
		return
	G.ask.append({"k": "flyby", "ship": s.id, "opts": opts, "text": "Flyby " + s.name + " must now make a heliocentric transfer outward. Choose its next system."})
func flybySkip(G, s):
	if s.kind != "Flyby" or P(s.loc).t != "fly" or t(G.turn.acted.get(s.id)): return "Nothing to skip."
	G.turn.acted[s.id] = 1
	afterFlybyBox(G, s)
	return null
func prodValue(G, w, r: String) -> int:
	var c = cardFor(G, w)
	return (c.prod[r] if c != null else 0) + int(gi(W[w].prod, r, 0))
func produceCV(G, s, w, r: String):
	var v := prodValue(G, w, r)
	var k: int = 1 + v / 10
	var roll: int = d10() - (1 if has(G, "ref") else 0)
	if roll <= v % 10 or (v >= 10 and roll <= v - 10): k += 1
	if roll <= 1: k += 1
	var room: int = s.cap * cargoMul(G) - sum(s.cargo)
	var got := mini(k, room)
	s.cargo[r] += got
	glog(G, s.name + " produces " + n(got) + " " + r + " at " + W[w].n + ": rolled " + n(roll) + " on d10 against production value " + n(v) + (" (cargo full)" if got < k else "") + ".", "g")
	G.lastRoll = {"kind": "produce", "title": s.name + " produces " + r + " at " + W[w].n, "r": roll, "good": k > 1, "head": n(got) + " " + r + " produced", "sub": "Rolled " + n(roll) + (" (after Space Refining)" if has(G, "ref") else "") + " against production value " + n(v) + ("; cargo full" if got < k else "") + ".", "extra": []}
	recallLog(G, s)
	return null
func recallLog(G, s) -> void:
	var rc := d100()
	var rv := recall(G)
	if rc <= rv:
		s.res = true
		var b := drawMarker(G, "Bio")
		glog(G, "Recall roll " + n(rc) + " (recalled on " + n(rv) + " or less): " + s.name + " is recalled and goes into reserve (+" + n(b) + " Biology).")
		G.lastRoll.extra.append("Recall roll " + n(rc) + " of " + n(rv) + "%: recalled.")
	else:
		glog(G, "Recall roll " + n(rc) + " (recalled on " + n(rv) + " or less): " + s.name + " stays active.")
		G.lastRoll.extra.append("Recall roll " + n(rc) + " of " + n(rv) + "%: stays active.")
func harvest(G, s):
	var sy = P(s.loc).s
	var r := d10()
	var ty: String = D.HARVEST[r][0]
	var k: int = D.HARVEST[r][1]
	var room: int = s.cap * cargoMul(G) - sum(s.cargo)
	var got := mini(k, room)
	s.cargo[ty] += got
	G.fly[sy].ast -= 1
	G.vm += 1
	glog(G, s.name + " harvests the asteroid: rolled " + n(r) + " on d10, " + n(got) + " " + ty + (" (cargo full)" if got < k else "") + ", +1 victory marker.", "g")
	G.lastRoll = {"kind": "harvest", "title": s.name + " harvests the asteroid", "r": r, "good": true, "head": n(got) + " " + ty + " and 1 victory marker", "sub": "Rolled " + n(r) + " on the asteroid harvest table" + ("; cargo full" if got < k else "") + ".", "extra": []}
	recallLog(G, s)
	return null

# ================= TRADE & BASES =================
func startTrade(G) -> void: glog(G, n(G.y) + ": trade and base construction.", "h")
func baseCost(G, w) -> int: return maxi(1, W[w].base - baseCostMod(G))
func canFoundBase(G, s):
	if G.phase != "trade": return null
	if s.cls != "CV" or t(s.res) or s.ev <= 0: return null
	var p := P(s.loc)
	if p.w == null: return null
	var w = p.w
	if not t(W[w].base): return null
	# from orbit or from the surface (worlds without a surface: orbit only); one base per world
	if p.t != "orbit" and p.t != "surf": return null
	if _some(G.bases, func(b): return b.w == w): return null
	if G.bases.size() >= 6: return null
	return {"w": w, "cost": baseCost(G, w), "pos": p.t}
func foundBase(G, s):
	var c = canFoundBase(G, s)
	if c == null: return s.name + " cannot found a base here."
	if s.cargo.SUP < c.cost: return "A base at " + W[c.w].n + " costs " + n(c.cost) + " SUP from " + s.name + "'s hold; it carries " + n(s.cargo.SUP) + "."
	if nBase(G) >= lims(G)[2] + 4: return "You are already 4 bases over your support limit."
	s.cargo.SUP -= c.cost
	var used = G.bases.map(func(b): return b.name)
	var name = _find(D.BASE_NAMES[G.f], func(nn): return not used.has(nn))
	var b := {"id": "b" + n(G.nid), "name": name, "w": c.w, "stock": {"ORE": 0, "SUP": 0, "FUEL": 0}, "fac": {"lab": 0, "mine": 0, "sup": 0, "def": 0}, "dmg": {"lab": 0, "mine": 0, "sup": 0, "def": 0}, "set": 0, "setDmg": 0, "trade": null, "out": "ORE", "built": G.y, "techField": "Phy", "pos": c.pos}
	G.nid += 1
	G.bases.append(b)
	b.out = bestOutput(G, b)
	glog(G, s.name + " founds " + ("an orbital" if c.pos == "orbit" else "a surface") + " base " + name + " at " + W[c.w].n + " for " + n(c.cost) + " SUP.", "g")
	return null
func buyCargo(G, s, r: String, k: int):  # at Earth: buy resources straight into a ship's hold
	if s.loc != "earth": return s.name + " must be on Earth to take on cargo bought there."
	var room: int = s.cap * cargoMul(G) - sum(s.cargo)
	k = mini(k, room)
	if k <= 0: return s.name + " has no cargo room."
	if G.cash < earthCash(G, {r: k}): return n(k) + " " + r + " costs " + earthCostTxt(G, {r: k}) + "."
	var paid := payEarth(G, {r: k})
	s.cargo[r] += k
	glog(G, s.name + " loads " + n(k) + " " + r + " on Earth (" + ((n(paid.used[r]) + " from the faction board") if t(paid.used[r]) else "") + (", " if (t(paid.used[r]) and t(paid.cash)) else "") + (("$" + n(paid.cash) + "B bought") if t(paid.cash) else "") + ").")
	return null
func sellCargo(G, s):  # at Earth: nothing is sold; cargo goes onto the faction board for later building
	if s.loc != "earth": return "Ships unload onto the faction board on Earth."
	var tx := resTxt(s.cargo)
	addRes(estock(G), s.cargo)
	s.cargo = {"ORE": 0, "SUP": 0, "FUEL": 0}
	glog(G, s.name + " unloads " + tx + " onto the faction board.")
	return null
func unload(G, s, b):
	if b == null or not is_same(atOwnBase(G, s), b): return "The ship must be at that base."
	addRes(b.stock, s.cargo)
	var tx := resTxt(s.cargo)
	s.cargo = {"ORE": 0, "SUP": 0, "FUEL": 0}
	glog(G, s.name + " unloads " + tx + " at " + b.name + ".")
	return null
func loadAt(G, s, b, r: String, cnt: int):
	if b == null or not is_same(atOwnBase(G, s), b): return "The ship must be at that base."
	var room: int = int(s.cap * cargoMul(G)) - int(sum(s.cargo))
	cnt = mini(cnt, mini(room, int(b.stock[r])))
	if cnt <= 0: return "Nothing to load."
	b.stock[r] -= cnt
	s.cargo[r] += cnt
	glog(G, s.name + " loads " + n(cnt) + " " + r + " at " + b.name + ".")
	return null
func loadCargo(G, s, b, r: String, k: int):
	if b == null or not is_same(atOwnBase(G, s), b): return "The ship must be at that base."
	var room: int = s.cap * cargoMul(G) - sum(s.cargo)
	k = mini(k, mini(room, b.stock[r]))
	if k <= 0: return "Nothing to load."
	b.stock[r] -= k
	s.cargo[r] += k
	glog(G, s.name + " loads " + n(k) + " " + r + " at " + b.name + ".")
	return null
## one tier of each building per base per turn: a new base can add a small lab and a settlement in the same turn,
## but not a small and then a large lab, or two settlements
func builtThisTurn(G, b) -> Dictionary:
	var tb = G.turn.built.get(b.id)
	if tb is Dictionary: return tb
	G.turn.built[b.id] = {}
	return G.turn.built[b.id]
func upgradeOptions(G, b) -> Array:
	var out := []
	for c in D.FACIL.keys():
		var lv: int = b.fac[c]
		var nxt = D.FACIL[c][lv] if lv < D.FACIL[c].size() else null
		var why = null
		if nxt == null: why = "fully built"
		elif t(builtThisTurn(G, b).get(c)): why = "one tier per turn: upgrade it next turn"
		elif t(b.dmg[c]): why = "repair it first"
		elif c == "mine" and b.w == "ear": why = "Earth orbit cannot produce resources"
		elif c == "mine" and basePos(b) == "orbit" and not has(G, "elev"): why = "an orbital base needs the Space Elevator technology to build mines"
		elif c == "mine" and W[b.w].tags.has("severeAtm") and not has(G, "psh"): why = "a severe atmosphere needs the Pressure Shell technology to build mines"
		out.append({"c": c, "lv": lv, "next": nxt, "why": why})
	return out
func buildFacility(G, b, c: String):
	if G.phase != "trade": return "Facilities are built in the trade & base phase."
	var o = _find(upgradeOptions(G, b), func(x): return x.c == c)
	if o == null or o.why != null: return o.why if o != null else "Unknown facility."
	if not enough(b.stock, o.next.c): return o.next.n + " costs " + resTxt(o.next.c) + "; " + b.name + " has " + resTxt(b.stock) + "."
	addRes(b.stock, o.next.c, -1)
	b.fac[c] += 1
	builtThisTurn(G, b)[c] = 1
	if c == "mine" or c == "lab": b.out = bestOutput(G, b)
	glog(G, b.name + " builds a " + o.next.n + ".", "g")
	return null
func buildSettlement(G, b):
	if G.phase != "trade": return "Settlements are built in the trade & base phase."
	if t(builtThisTurn(G, b).get("set")): return b.name + " already added a settlement this turn."
	if not enough(b.stock, D.SETTLE_COST): return "A settlement costs " + resTxt(D.SETTLE_COST) + "."
	addRes(b.stock, D.SETTLE_COST, -1)
	b.set += 1
	builtThisTurn(G, b).set = 1
	glog(G, b.name + " adds a settlement (" + n(b.set) + " total).", "g")
	return null
func repairFacility(G, b, c: String):
	if c == "set":
		if not t(gi(b, "setHits", 0)): return "No damage to repair."
		if b.stock.ORE < 1: return "Repairs cost 1 ORE per damage marker."
		b.stock.ORE -= 1
		b.setHits -= 1
		b.setDmg = 1 if b.setHits > 0 else 0
		glog(G, b.name + " repairs a settlement.")
		return null
	if not t(b.dmg[c]): return "No damage to repair."
	if b.stock.ORE < 1: return "Repairs cost 1 ORE per damage marker."
	b.stock.ORE -= 1
	b.dmg[c] -= 1
	glog(G, b.name + " repairs its " + c + " facility.")
	return null
func terraform(G, b):
	if G.phase != "trade": return "Terraforming happens in the trade & base phase."
	if not has(G, "terra"): return "You need Terraforming."
	if not D.TERRA.has(b.w): return W[b.w].n + " cannot be terraformed."
	var k: int = gi(G.turn.terraBuys, b.id, 0)
	var cost: int = (3 if has(G, "atm") else 4) + k
	if b.stock.SUP < cost: return "The next terraforming point costs " + n(cost) + " SUP."
	b.stock.SUP -= cost
	G.turn.terraBuys[b.id] = k + 1
	G.w[b.w].terra += 1
	glog(G, b.name + " buys a terraforming point for " + n(cost) + " SUP (" + W[b.w].n + ": " + n(G.w[b.w].terra) + "/" + n(D.TERRA[b.w]) + ").", "g")
	return null
## trade at own base (buy with cash / sell from stock) or at an NPF base (with a fleet there)
func tradeLimitOwn(b) -> int:
	var r = setRow(b.set - int(gi(b, "setDmg", 0)))
	return r[1] if r != null else 0
func trade(G, where: Dictionary, qty: int):
	if G.phase != "trade": return "Trading happens in the trade & base phase."
	if t(where.get("base")):
		var b = _baseById(G, where.base)
		if t(gi(b, "blk", false)): return b.name + " is blockaded and cannot trade."
		var tm = b.trade
		var limit := tradeLimitOwn(b)
		var stock: Dictionary = b.stock
		var label: String = b.name
		if not t(tm): return b.name + " has no trade marker."
		if not limit: return b.name + " needs settlements to trade."
		if tm.side == "buy":
			var cost := ce(mini(qty, limit) / 2.0)
			if G.cash < cost: return "Buying costs $" + n(cost) + "B."
			G.cash -= cost
			stock[tm.type] += mini(qty, limit)
		else:
			var k: int = mini(qty, mini(limit, stock[tm.type]))
			if not k: return "No " + tm.type + " to sell."
			stock[tm.type] -= k
			G.cash += 2 * k
		glog(G, "Traded at " + label + ": " + ("bought" if tm.side == "buy" else "sold") + " " + n(mini(qty, limit)) + " " + tm.type + ".", "g")
		b.trade = null
		return null
	var w = where.w
	var x = G.w[w]
	if not t(x.npf) or not t(x.npfTrade): return "That NPF base has no trade marker."
	if gi(x.npfTrade, "by", []).has(G.f): return "You have already traded at " + String(orv(npfName(G, w), "that base")) + "; each faction trades there once."
	if G.rel[x.npf] > 3: return "Relations with " + D.FAC[x.npf].n + " are too poor to trade."
	var fleet = G.ships.filter(func(s): return s.cls == "CV" and worldOf(s.loc) == w and P(s.loc).t != "fly" and P(s.loc).t != "box")
	if not fleet.size() or _some(fleet, func(s): return t(s.res)): return "You need an unreserved crew vehicle fleet at that base."
	var row = fac(G).rel[G.rel[x.npf]] if G.rel[x.npf] < fac(G).rel.size() else null
	var limit: int = row[1] if row != null else 0
	if not limit: return D.FAC[x.npf].n + " will not trade with you at your current relations."
	var tm = x.npfTrade
	if tm.side == "buy":
		var room: int = _sum(fleet, func(s): return s.cap * cargoMul(G) - sum(s.cargo))
		var k: int = mini(qty, mini(limit, room))
		if not k: return "No cargo room."
		var cost := ce(k / 2.0)
		if G.cash < cost: return "Buying costs $" + n(cost) + "B."
		G.cash -= cost
		var left := k
		for s in fleet:
			var r: int = mini(left, s.cap * cargoMul(G) - sum(s.cargo))
			s.cargo[tm.type] += r
			left -= r
		glog(G, "Bought " + n(k) + " " + tm.type + " from the " + D.FAC[x.npf].n + " base at " + W[w].n + " for $" + n(cost) + "B.", "g")
	else:
		var have: int = _sum(fleet, func(s): return s.cargo[tm.type])
		var k: int = mini(qty, mini(limit, have))
		if not k: return "Your fleet carries no " + tm.type + "."
		var left := k
		for s in fleet:
			var r: int = mini(left, s.cargo[tm.type])
			s.cargo[tm.type] -= r
			left -= r
		G.cash += 2 * k
		glog(G, "Sold " + n(k) + " " + tm.type + " to the " + D.FAC[x.npf].n + " base at " + W[w].n + " for $" + n(2 * k) + "B.", "g")
	if enhTrade(G):
		tm.by = gi(tm, "by", []) + [G.f]
		if _every(facsInPlay(G), func(f): return tm.by.has(f)):
			x.npfTrade = null
			glog(G, "Every faction has traded at " + String(npfName(G, w)) + ": its trade marker is removed.")
		else: glog(G, "Enhanced trading: the trade marker at " + String(npfName(G, w)) + " stays for the factions that have not traded there yet.")
	else: x.npfTrade = null
	return null
## what an NPF base offers this faction: limit by relations, and why it cannot trade right now
func npfTradeInfo(G, w):
	var x = G.w.get(w)
	if x == null or not t(x.npf): return null
	var rel: int = G.rel[x.npf]
	var row = fac(G).rel[rel] if rel < fac(G).rel.size() else null
	var limit: int = 0 if rel > 3 else (row[1] if row != null else 0)
	var fleet = G.ships.filter(func(s): return s.cls == "CV" and worldOf(s.loc) == w and P(s.loc).t != "fly" and P(s.loc).t != "box")
	var tm = x.npfTrade
	var by: Array = gi(tm, "by", []) if tm != null else []
	var why = null
	if t(x.blk): why = "Blockaded."
	elif not t(tm): why = "No trade marker until the next economic phase."
	elif by.has(G.f): why = "You have already traded here."
	elif rel > 3: why = "Relations (" + D.REL[rel] + ") are too poor to trade."
	elif not limit: why = D.FAC[x.npf].n + " will not trade at " + D.REL[rel] + "."
	elif not fleet.size(): why = "Bring a crew vehicle here (orbit or surface) to trade."
	elif _some(fleet, func(s): return t(s.res)): why = "Your crew vehicles here must be unreserved."
	elif G.phase != "trade": why = "Trading happens in the trade & base phase."
	return {"name": npfName(G, w), "f": x.npf, "rel": rel, "limit": limit, "tm": tm, "by": by, "why": why, "enh": enhTrade(G)}

# ================= SCORING =================
func score(G) -> Dictionary:
	var parts := []
	var add := func(k: String, v):
		if t(v): parts.append([k, rnd_i(v * 100.0) / 100.0])
	add.call("Victory markers", G.vm)
	var ic := ["ich", "ice", "ichull"].filter(func(k): return has(G, k)).size()
	add.call("Interstellar colonizer techs", [0, 15, 30, 50][ic])
	var terraMost := 0
	var setVP := 0.0
	for b in G.bases:
		var tn = D.TERRA.get(b.w)
		var full: bool = tn != null and G.w[b.w].terra >= tn
		var half: bool = tn != null and G.w[b.w].terra * 2 >= tn
		var per = orv(D.SET_VP.get(b.w), orv(D.SET_VP.get(W[b.w].sys), 2)) + (.5 if full else (.25 if half else 0.0))
		setVP += b.set * per
		if t(b.set) and (full or half): terraMost += 25 if full else 10
	add.call("Settlements", setVP)
	add.call("Most settlements on terraformed worlds", terraMost)
	add.call("Missions", _sum(G.mis.kept, func(id): return D.MIS[id].vp))
	add.call("Alpha Centauri", 20 if (G.alpha.cv and G.alpha.re) else (15 if G.alpha.cv else (5 if G.alpha.re else 0)))
	add.call("Infrastructure", _sum(G.bases, func(b): return b.fac.lab + b.fac.mine + b.fac.sup + b.fac.def))
	add.call("Undeveloped technologies", -3 * D.TECH.filter(func(tt): return not t(G.tech.get(tt.k))).size())
	var bank := 0
	for f in FIELDS: bank += G.bank[f]
	add.call("Unspent tech points", fl(bank / 20.0))
	add.call("Unspent politics markers", fl(G.polm / 5.0))
	add.call("Space fleet", _sum(G.ships, func(s): return s.sz * .5 if s.cls == "CV" else .5))
	var penalty: int = -3 * (G.y - 2145) if G.y > 2145 else 0
	add.call("Solo penalty (past 2145)", penalty)
	var tot := 0.0
	for p in parts: tot += p[1]
	var total := rnd_i(tot * 100.0) / 100.0
	var rating: String = _find(D.RATING, func(r): return total <= r[0])[1]
	return {"parts": parts, "total": total, "rating": rating}
func finish(G, why: String) -> void:
	G.over = true
	G.endYear = G.y
	var sc := score(G)
	glog(G, why + " Final score " + n(sc.total) + ": " + sc.rating + ".", "h")

# ================= SEVERAL FACTIONS (human + bots) =================
# Each faction keeps its own state object (same shape as a solo game); the worlds (exploration values, cards, life,
# NPF bases) and the flyby boxes (pirates, asteroids) are one shared object. world = { meta: {order, human, bots}, facs }.
func isLead(G) -> bool: return G.world == null or G.world.meta.order[0] == G.f
func npfKeys(G) -> Array: return G.rel.keys().filter(func(k): return not (G.world != null and G.world.facs.has(k)))
func allBases(G) -> Array:
	var out := []
	var facs: Array = G.world.facs.values() if G.world != null else [G]
	for g in facs:
		for b in g.bases: out.append(merged(b, {"f": g.f}))
	return out
func attachWorld(facs: Dictionary, meta: Dictionary) -> Dictionary:
	var human: Dictionary = facs[meta.human]
	var world := {"meta": meta, "facs": facs}
	for g in facs.values():
		g.w = human.w
		g.fly = human.fly
		g.world = world
	return human
func newWorld(opts: Dictionary) -> Dictionary:  # {human, variant, bots: [{f, variant}], scenario, rerolls, scrapRE}
	var bots: Array = opts.get("bots", [])
	var fs := [opts.human] + bots.map(func(b): return b.f)
	var order: Array = D.FAC_ORDER.filter(func(f): return fs.has(f))
	var facs := {}
	for f in order:
		var b = _find(bots, func(x): return x.f == f)
		facs[f] = newGame(f, merged(opts, {"variant": opts.get("variant") if f == opts.human else (b.get("variant") if b != null else null)}))
		if f != opts.human: facs[f].bot = true
	var human := attachWorld(facs, {"order": order, "human": opts.human, "bots": bots.map(func(b): return b.f), "done": {}})
	var parts := order.map(func(f): return D.FAC[f].n + (" (you)" if f == opts.human else ((" (bot, " + D.FAC[f].variants[facs[f].variant].n + ")") if facs[f].variant != null else " (bot)")))
	var npfs := npfKeys(human)
	glog(human, "Factions in play (initiative order): " + ", ".join(parts) + ". " + (("Non-player factions: " + ", ".join(npfs.map(func(f): return D.FAC[f].n)) + ".") if npfs.size() else ""), "h")
	return human
## initiative (3.1.2): every faction declares (in the previous initiative order) how many politics markers it spends,
## +10% each, at most its current slot number; then all roll d100 + markers + Military Policy (+20/40/50%).
## The new order runs from the highest result down; ties go to the faction that was ahead before.
func setInitBid(G, k: int):
	var slot: int = (G.world.meta.order.find(G.f) + 1) if G.world != null else 1
	G.initBid = maxi(0, mini(k, mini(G.polm, slot)))
	return null
func resolveInitiative(world: Dictionary) -> Array:
	var o: Array = world.meta.order
	var H = world.facs[world.meta.human]
	var nmf := func(f): return D.FAC[f].n + (" (you)" if f == world.meta.human else "")
	var rows := []
	for i in o.size():
		var f = o[i]
		var g = world.facs[f]
		var bid := maxi(0, mini(int(gi(g, "initBid", 0)), mini(g.polm, i + 1)))
		var mil: int = [0, 20, 40, 50][polLv(g, "mil")]
		g.polm -= bid
		g.initBid = 0
		rows.append({"f": f, "prev": i, "bid": bid, "mil": mil})
	var spent := rows.filter(func(r): return r.bid > 0)
	glog(H, "Initiative: politics markers declared in the previous order (" + ", ".join(o.map(func(f): return nmf.call(f))) + "): " + "; ".join(rows.map(func(r): return nmf.call(r.f) + " " + (("spends " + n(r.bid) + " (+" + n(r.bid * 10) + "%)") if r.bid else "spends none"))) + ".", "h")
	for r in rows:
		r.roll = d100()
		r.tot = r.roll + r.bid * 10 + r.mil
		glog(H, "Initiative roll: " + nmf.call(r.f) + " rolls " + n(r.roll) + ((" +" + n(r.bid * 10) + "% (" + n(r.bid) + " politics marker" + ("s" if r.bid > 1 else "") + ")") if r.bid else "") + ((" +" + n(r.mil) + "% (" + ["", "", "Vigorous ", "Unified "][polLv(world.facs[r.f], "mil")] + "Military Policy)") if r.mil else "") + " = " + n(r.tot) + ".")
	rows = ssort(rows, func(a, b):
		var d: int = b.tot - a.tot
		return d if d != 0 else a.prev - b.prev)
	world.meta.order = rows.map(func(r): return r.f)
	var ties := false
	for i in range(1, rows.size()):
		if rows[i].tot == rows[i - 1].tot: ties = true
	var lst := []
	for i in rows.size():
		var r = rows[i]
		lst.append(n(i + 1) + ". " + nmf.call(r.f) + " (" + n(r.tot) + ((((", up from " if r.prev > i else ", down from ") + n(r.prev + 1))) if r.prev != i else "") + ")")
	glog(H, "New initiative order: " + ", ".join(lst) + "." + (" Ties go to the faction that was ahead before." if ties else ""), "h")
	for g in world.facs.values(): g.initBid = 0
	return spent
