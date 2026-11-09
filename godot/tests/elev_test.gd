## Space Elevator / launch rules. godot --headless --path godot res://tests/elev_test.tscn
extends Node
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c: fails += 1
func _ready() -> void:
	var E = Game.E
	var G = E.newGame("na", {})
	for k in ["cv", "lcv", "frig", "dest", "cru", "bat", "orb", "ars", "psh"]: G.tech[k] = true
	G.cash = 999
	G.phase = "build"
	var opts: Array = E.buildOptions(G, "earth")
	var big = SHRules._find(opts, func(o): return o.cv and o.sz >= 5)
	ok(big != null and big.why == "too large to build on Earth", "CV-5+ not buildable on Earth without the Space Elevator (%s)" % [big.why if big else "?"])
	G.tech.elev = true
	opts = E.buildOptions(G, "earth")
	big = SHRules._find(opts, func(o): return o.cv and o.sz >= 5 and o.why == null)
	ok(big != null, "CV-5+ buildable on Earth with the Space Elevator")
	ok(E.buildUnit(G, big.key, "earth") == null, "build it")
	var s = G.ships[-1]
	ok(s.loc == "orbit:ear", "new CV starts in Earth orbit (%s)" % s.loc)
	G.phase = "move"
	G.turn.moved = {}
	var mv: Array = E.moves(G, s)
	ok(mv.size() > 0 and not SHRules._some(mv, func(m): return m.get("lv") != null), "it flies on without a launch vehicle (%d moves)" % mv.size())
	# an old CV-2 left on the surface: no LV needed either
	var c2 = E.makeShip(G, "Gemini")
	c2.loc = "earth"
	mv = E.moves(G, c2)
	ok(mv.size() > 0 and not SHRules._some(mv, func(m): return m.get("lv") != null) and not SHRules._some(mv, func(m): return m.dest == "earth"), "a CV on Earth's surface leaves without an LV with the elevator")
	# telescope on Earth with the elevator: built straight into Earth orbit
	G.ships = G.ships.filter(func(x): return x.kind != "Telescope")
	G.phase = "build"
	var tel = SHRules._find(E.buildOptions(G, "earth"), func(o): return o.kind == "Telescope" and o.why == null)
	if tel != null:
		ok(E.buildUnit(G, tel.key, "earth") == null, "build a telescope on Earth")
		ok(G.ships[-1].loc == "orbit:ear" and G.ships[-1].launched, "telescope is already in Earth orbit")
	# rover on Earth with the elevator still needs a launch vehicle
	var rov = E.makeShip(G, "Pathfinder")
	if rov != null and rov.kind == "Rover":
		rov.loc = "earth"
		G.phase = "move"
		mv = E.moves(G, rov)
		ok(mv.size() > 0 and SHRules._every(mv, func(m): return m.get("lv") != null), "rover on Earth still launches on an LV")
	# bases: Mars surface base and a Mars orbital base, an Earth orbital base
	var mb := {"id": "bm", "name": "Mars Base", "w": "mar", "stock": {"ORE": 20, "SUP": 20, "FUEL": 20}, "fac": {"lab": 0, "mine": 0, "sup": 4, "def": 0}, "dmg": {"lab": 0, "mine": 0, "sup": 0, "def": 0}, "set": 0, "setDmg": 0, "trade": null, "out": "ORE", "built": 2030, "techField": "Phy", "pos": "surf"}
	var eb: Dictionary = mb.duplicate(true)
	eb.id = "be"
	eb.w = "ear"
	eb.pos = "orbit"
	G.bases.append(mb)
	G.bases.append(eb)
	G.ships = G.ships.filter(func(x): return x.kind != "Telescope")
	G.phase = "build"
	var tm = SHRules._find(E.buildOptions(G, "bm"), func(o): return o.kind == "Telescope")
	ok(tm == null or tm.why != null, "a Mars base cannot build telescopes (%s)" % [tm.why if tm else "none listed"])
	var te = SHRules._find(E.buildOptions(G, "be"), func(o): return o.kind == "Telescope")
	ok(te != null and te.why == null, "an Earth-orbit base builds telescopes")
	if te != null and te.why == null:
		var n0 = G.ships.size()
		var r = E.buildUnit(G, te.key, "be")
		ok(r == null and G.ships.size() == n0 + 1 and G.ships[-1].loc == "orbit:ear" and G.ships[-1].launched, "telescope from the orbital base stays in Earth orbit (%s)" % [r])
	# a rover built at the Mars surface base: Mars surface needs no LV, anywhere else does (none in stock: nothing else)
	var ro = SHRules._find(E.buildOptions(G, "bm"), func(o): return o.kind == "Rover" and o.why == null)
	ok(ro != null, "Mars base can build a rover")
	if ro != null:
		E.buildUnit(G, ro.key, "bm")
		var r2 = G.ships[-1]
		ok(r2.loc == "surf:mar", "rover starts at the base (%s)" % r2.loc)
		G.phase = "move"
		G.turn.moved = {}
		mv = E.moves(G, r2)
		ok(mv.size() == 1 and mv[0].dest == "surf:mar" and mv[0].get("lv") == null, "it can only deploy onto Mars' surface without an LV (%s)" % [mv.map(func(m): return m.dest)])
		ok(E.move(G, r2, "surf:mar") == null and r2.launched and r2.fixed and r2.loc == "surf:mar", "deployed in place")
		G.lv["bm"] = {1: 1, 2: 0, 3: 0, 4: 0}
		var r3 = E.makeShip(G, ro.u.n) if false else null
	print("FAILS ", fails)
	get_tree().quit(fails)
