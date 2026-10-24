## Plays a seeded all-bot campaign and writes every faction's log, for comparison with tools/parity_dump.js.
## Run: godot --headless --path godot -s res://tests/parity_dump.gd -- <seed> <out.json> [maxSteps]
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var out_path: String = args[1] if args.size() > 1 else "user://parity.json"
	var max_steps := int(args[2]) if args.size() > 2 else 50000
	var data := SHData.load_game_data()
	var E := SHRules.new(data.D, data.UNITS)
	var rng := SHRng.new(seed_v)
	E.rnd = rng.as_callable()
	var AI := SHAI.new(E)
	var facs: Array = data.D.FAC_ORDER
	var bots := []
	for i in range(1, facs.size()): bots.append({"f": facs[i], "variant": "rob" if facs[i] == "cn" and seed_v % 2 == 0 else null})
	var t0 := Time.get_ticks_msec()
	var all := []
	E.on_log = func(g, e): all.append(g.f + "|" + str(e.y) + "|" + e.t)
	var H := E.newWorld({"human": facs[0], "bots": bots, "scrapRE": seed_v % 3 == 0, "enhTrade": seed_v % 4 == 0})
	var steps := AI.autoPlay(H, max_steps)
	var out := {"steps": steps, "year": H.y, "facs": {}, "all": all}
	for f in H.world.facs:
		var g = H.world.facs[f]
		var lg := []
		for l in g.log: lg.append(str(l.y) + "|" + str(l.c) + "|" + l.t)
		lg.reverse()
		out.facs[f] = {"cash": g.cash, "vm": g.vm, "polm": g.polm, "score": E.score(g).total, "ships": g.ships.map(func(s): return s.name + "@" + s.loc), "bases": g.bases.map(func(b): return b.name + "@" + b.w + ":" + str(b.set)), "tech": g.tech.keys(), "log": lg}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	print("steps ", steps, " year ", H.y, " in ", Time.get_ticks_msec() - t0, " ms")
	quit()
