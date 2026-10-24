## Solo campaign with random-but-legal choices, seeded, recording every log line; mirrors tools/parity_solo.js.
## Run: godot --headless --path godot -s res://tests/parity_solo.gd -- <seed> <faction> <out.json>
extends SceneTree

var E: SHRules
func pick(a: Array):
	var i := int(floor(E.rnd.call() * a.size()))
	return a[i] if i < a.size() else null
func r() -> float: return E.rnd.call()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var f: String = args[1] if args.size() > 1 else "na"
	var out_path: String = args[2] if args.size() > 2 else "user://solo.json"
	var data := SHData.load_game_data()
	var D: Dictionary = data.D
	E = SHRules.new(D, data.UNITS)
	E.rnd = SHRng.new(seed_v).as_callable()
	var G := E.newGame(f, {"scrapRE": seed_v % 2 == 1, "scenario": "fut2060" if seed_v % 3 == 2 else "std", "variant": "rob" if seed_v % 4 == 0 else "mil"})
	var all := []
	E.on_log = func(_g, e): all.append(str(e.y) + "|" + e.t)
	var steps := 0
	while not G.over and steps < 20000:
		steps += 1
		var guard := 0
		while G.ask.size() and guard < 50:
			guard += 1
			var a: Dictionary = G.ask[0]
			if a.k == "pirate": E.answer(G, pick(["pay", "remove", "surrender", "fight", "stay"]))
			elif a.k == "publicity": E.answer(G, pick(G.w.keys().filter(func(k): return G.w[k].v > 0)))
			elif a.k == "immigration": E.answer(G, G.bases[0].id)
			elif a.k == "card": E.answer(G, pick(a.opts + [null]))
			elif a.k == "flyby": E.answer(G, pick(a.opts).sys)
			elif a.k == "mission": E.answer(G, pick(a.opts))
			elif a.k == "pbattle": E.answer(G, pick(["auto", "avoid"]))
			elif a.k == "assign": E.answer(G, "auto")
			else: G.ask.pop_front()
		if G.ask.size(): G.ask.clear()
		if G.phase == "econ":
			if G.estep == "diplomacy" and G.polm > 3: E.setDiplomacy(G, pick(G.rel.keys()), pick([1, 1, -1]))
			if G.estep == "tech":
				for i in 6:
					var open: Array = D.TECH.filter(func(tt): return E.techState(G, tt) == "open" and G.bank[tt.f] >= E.techCost(G, tt))
					if not open.size(): break
					E.develop(G, pick(open).k)
				while G.polm > 0: E.convertPolitics(G, pick(["cash", "Phy", "Eng", "Bio"]))
			if G.estep == "policy": E.choosePolicy(G, pick(D.POL).k)
			if G.estep == "transport" and SHRules.t(G.get("transferLeft")) and G.bases.size(): E.transferRes(G, "earth", G.bases[0].id, "SUP", mini(G.transferLeft, 2))
			if G.estep == "production":
				for b in G.bases: b.out = E.bestOutput(G, b)
		if G.phase == "build":
			for i in 3:
				var opts := E.buildOptions(G, "earth").filter(func(o): return o.why == null and G.cash >= E.sum(o.cost) + 6)
				if opts.size() and r() < .6:
					var key = pick(opts).key
					E.buildUnit(G, key, "earth", r() < .1)
			if r() < .5: E.buildLV(G, pick([1, 2, 3, 4]), "earth")
			if r() < .05:
				var z = pick([1, 2, 3, 4])
				if SHRules.t(G.lv.earth[z]): E.scrapLV(G, "earth", z)
			if r() < .03:
				var s = pick(G.ships.filter(func(x): return E.scrapSite(G, x) != null) + [null])
				if s != null: E.scrap(G, s)
			for s in G.ships.filter(func(x): return SHRules.t(x.res)): E.unreserve(G, s)
			for s in G.ships.filter(func(x): return x.loc == "earth" and SHRules.t(x.cap)): E.buyCargo(G, s, "SUP", 9)
			for s in G.ships.filter(func(x): return SHRules.t(x.dmg)): E.repair(G, s)
			for b in G.bases:
				if r() < .3: E.buildLV(G, 1, b.id)
				var o := E.buildOptions(G, b.id).filter(func(x): return x.why == null)
				if o.size() and r() < .3: E.buildUnit(G, pick(o).key, b.id)
		if G.phase == "move":
			for s in G.ships.duplicate():
				if not SHRules.has_obj(G.ships, s) or G.ask.size(): continue
				var m := E.moves(G, s)
				if not m.size() or r() < .35: continue
				var probe = SHRules._first(G.probes.get(s.loc, []))
				var dest = pick(m).dest
				var ld = {"SUP": 2} if (s.cls == "CV" and s.loc == "earth" and r() < .3) else null
				E.move(G, s, dest, {"probe": probe, "load": ld})
			if G.bases.size() and r() < .5: E.shipCargo(G, pick(G.bases).id, {"SUP": 1, "ORE": 1})
		if G.phase == "combat":
			for o in E.combatOptions(G):
				if r() < .7: E.combatAct(G, o)
		if G.phase == "explore":
			for s in G.ships.duplicate():
				if not SHRules.has_obj(G.ships, s) or G.ask.size(): continue
				var o := E.exploreOptions(G, s)
				if o.size(): E.explore(G, s, pick(o))
		if G.phase == "trade":
			for s in G.ships.duplicate():
				if s.cls != "CV": continue
				if E.canFoundBase(G, s) != null: E.foundBase(G, s)
				var b = E.atOwnBase(G, s)
				if b != null: E.unload(G, s, b)
				if s.loc == "earth" and r() < .3: E.sellCargo(G, s)
			for b in G.bases:
				var ops := E.upgradeOptions(G, b).filter(func(o): return o.why == null)
				if ops.size() and r() < .7: E.buildFacility(G, b, pick(ops).c)
				else: E.buildSettlement(G, b)
				if SHRules.t(b.trade): E.trade(G, {"base": b.id}, 3)
				if r() < .2: E.terraform(G, b)
				if r() < .2: E.repairFacility(G, b, pick(["lab", "mine", "sup", "def", "set"]))
			for k in G.w.keys():
				if SHRules.t(G.w[k].npf): E.trade(G, {"w": k}, 4)
		if not G.ask.size(): E.advance(G)
	var sc := E.score(G)
	var fh := FileAccess.open(out_path, FileAccess.WRITE)
	fh.store_string(JSON.stringify({"steps": steps, "year": G.y, "score": sc.total, "rating": sc.rating, "cash": G.cash, "all": all}, " "))
	print(f, " steps ", steps, " year ", G.y, " score ", sc.total)
	quit()
