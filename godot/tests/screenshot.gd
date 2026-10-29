## Renders the game to PNG files for checking the layout (needs a display: run under xvfb-run, not --headless).
## godot --path godot res://tests/shots.tscn -- <out_dir> [faction] [bots 0|1] [plan]
extends Node

var out := "user://shots"
var step := 0
var main: Node
var actions: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var f: String = args[1] if args.size() > 1 else "eu"
	var bots := args.size() > 2 and args[2] == "1"
	var plan: String = args[3] if args.size() > 3 else "basic"
	main = load("res://scenes/main.tscn").instantiate()
	main.warm_enabled = false
	add_child(main)
	actions = _plan(plan, f, bots)

func _plan(plan: String, f: String, bots: bool) -> Array:
	var a := []
	a.append(["wait", 20])
	a.append(["shot", "00_menu"])
	a.append(["call", func():
		var b := []
		if bots:
			for k in Game.data.D.FAC_ORDER:
				if k != f: b.append({"f": k})
		Game.E.rnd = SHRng.new(7).as_callable()
		Game.new_campaign(f, {"scenario": "std"}, b)])
	a.append(["wait", 40])
	a.append(["shot", "01_start"])
	if plan == "basic":
		a.append(["call", func():
			var s = SHRules._find(Game.G.ships, func(x): return Game.E.moves(Game.G, x).size() > 0)
			if s != null:
				Game.select({"t": "ship", "id": s.id})
				main.tabs.current_tab = 1
				main.cam.fly_to(main.board.pos_of(s.loc) if s.loc != "earth" else main.board.world_center("ear"), 0.3)])
		a.append(["wait", 40])
		a.append(["shot", "02_selected"])
		a.append(["call", func():
			for i in 3: Game.next()
			main.tabs.current_tab = 0])
		a.append(["wait", 30])
		a.append(["shot", "03_explore"])
		a.append(["call", func(): main.tabs.current_tab = 2])
		a.append(["wait", 10])
		a.append(["shot", "04_faction"])
		a.append(["call", func(): main.cam.setup(main.board.map_rect())])
		a.append(["wait", 30])
		a.append(["shot", "05_whole_map"])
	if plan == "flat":
		a.append(["call", func(): main.tabs.current_tab = 0; main.cam.setup(main.board.map_rect())])
		a.append(["wait", 40])
		a.append(["shot", "10_whole"])
		a.append(["call", func(): main.cam.fly_to(main.board.world_center("jup"), 0.35)])
		a.append(["wait", 60])
		a.append(["shot", "11_jup"])
		a.append(["call", func(): main.toggle_3d()])
		a.append(["wait", 60])
		a.append(["shot", "12_25d"])
		a.append(["call", func(): main.toggle_3d()])
		a.append(["wait", 40])
		a.append(["shot", "13_back"])
	if plan == "move":
		a.append(["call", func():
			var s = SHRules._find(Game.G.ships, func(x): return Game.E.moves(Game.G, x).size() > 0)
			Game.select({"t": "ship", "id": s.id})
			main.tabs.current_tab = 1
			main.cam.fly_to(main.board.world_center("ear"), 0.42)])
		a.append(["wait", 40])
		a.append(["shot", "02_targets"])
		a.append(["call", func():
			var s = SHRules._find(Game.G.ships, func(x): return Game.E.moves(Game.G, x).size() > 0)
			main.do_move(s, "orbit:moo" if Game.E.moves(Game.G, s).any(func(m): return m.dest == "orbit:moo") else "orbit:ear")
			Game.next()
			main.tabs.current_tab = 0])
		a.append(["wait", 30])
		a.append(["shot", "03_after_move"])
	if plan == "board" or plan == "board2":
		a.append(["call", func(): main.tabs.current_tab = 2])
		a.append(["wait", 20])
		a.append(["shot", "02_board_move"])
		# drag the first ship in the tray onto the launch pad with real mouse events
		a.append(["call", func(): main.fboard.scroll.scroll_vertical = 0])
		a.append(["wait", 10])
		a.append(["drag", "tray", "pad"])
		a.append(["wait", 20])
		a.append(["call", func(): print("pad after drag: ", Game.pad)])
		a.append(["shot", "03_board_pad"])
		a.append(["call", func():
			var fb = main.fboard
			fb.scroll.scroll_vertical = 0])
		a.append(["call", func():
			var s = SHRules._find(Game.G.ships, func(x): return Game.E.moves(Game.G, x).size() > 0 and x.loc == "earth")
			Game.act(Game.E.move(Game.G, s, "orbit:ear"))
			for i in 3: Game.next()])
		a.append(["wait", 20])
		a.append(["shot", "04_board_build"])
		a.append(["call", func():
			var o = SHRules._find(Game.E.buildOptions(Game.G, "earth"), func(x): return x.why == null and x.kind == "Orbiter")
			Game.act(Game.E.buildUnit(Game.G, o.key, "earth"))
			Game.act(Game.E.buildLV(Game.G, 1, "earth"))])
		a.append(["wait", 20])
		a.append(["call", func(): main.fboard.scroll.scroll_vertical = 600])
		a.append(["wait", 10])
		a.append(["shot", "05_board_built"])
		a.append(["call", func(): main.fboard._show_sheet(Game.G.f)])
		a.append(["wait", 20])
		a.append(["shot", "06_sheet"])
	if plan == "lvpair":
		a.append(["call", func():
			var G = Game.G
			while G.phase != "build" and not G.over:
				while G.ask.size(): Game.AI.answerAsks(G)
				Game.next()
			var o = SHRules._find(Game.E.buildOptions(G, "earth"), func(x): return x.why == null and x.kind == "Orbiter")
			Game.act(Game.E.buildUnit(G, o.key, "earth"))
			Game.act(Game.E.buildLV(G, 1, "earth"))
			Game.act(Game.E.buildLV(G, 2, "earth"))
			while G.phase != "move" and not G.over:
				while G.ask.size(): Game.AI.answerAsks(G)
				Game.next()
			main.tabs.current_tab = 2])
		a.append(["wait", 20])
		a.append(["call", func(): main.fboard.scroll.scroll_vertical = 0])
		a.append(["wait", 6])
		a.append(["shot", "lv_01_before"])
		a.append(["dragtype", "lv", "ship"])
		a.append(["wait", 16])
		a.append(["call", func(): print("pad_lv: ", Game.pad_lv, " pad ", Game.pad, " msg ", Game.pad_msg)])
		a.append(["shot", "lv_02_paired"])
		a.append(["call", func():
			var fb = main.fboard
			var btn = _find_node(fb, func(n): return n is Button and n.text.begins_with("Orbit") or (n is Button and n.text.contains("·")))
			print("launch button: ", btn.text if btn else null)
			if btn: btn.pressed.emit()])
		a.append(["wait", 20])
		a.append(["call", func(): for s in Game.G.ships: print(s.name, " ", s.loc, " lv ", Game.G.lv.earth)])
		a.append(["shot", "lv_03_launched"])
	if plan == "bases":
		a.append(["call", func():
			for i in 260:
				var G = Game.G
				while G.ask.size(): Game.AI.answerAsks(G)
				Game.AI.botPhase(G)
				Game.next()
				if G.bases.size() >= 2 and G.phase == "move": break
			main.tabs.current_tab = 2])
		a.append(["wait", 20])
		a.append(["shot", "02_board"])
		a.append(["call", func(): main.fboard.scroll.scroll_vertical = 560])
		a.append(["wait", 20])
		a.append(["shot", "03_board_bases"])
	if plan == "year":
		for i in int(OS.get_environment("SH_STEPS") if OS.get_environment("SH_STEPS") != "" else "60"):
			a.append(["call", func():
				var G = Game.G
				while G.ask.size(): Game.AI.answerAsks(G)
				if not G.over: Game.AI.botPhase(G)
				Game.next()])
			a.append(["wait", 1])
		a.append(["call", func(): main.tabs.current_tab = main.TAB_LOG])
		a.append(["wait", 20])
		a.append(["shot", "09_log"])
		a.append(["call", func(): main.tabs.current_tab = 0; main.cam.setup(main.board.map_rect())])
		a.append(["wait", 20])
		a.append(["shot", "10_map"])
		a.append(["call", func(): main.tabs.current_tab = main.TAB_TECH])
		a.append(["wait", 20])
		a.append(["shot", "11_tech"])
		a.append(["call", func(): main.tabs.current_tab = main.TAB_POL])
		a.append(["wait", 20])
		a.append(["shot", "12_pol"])
	if plan == "mapdrag":
		a.append(["call", func():
			for i in 120:
				var G = Game.G
				while G.ask.size(): Game.AI.answerAsks(G)
				if G.phase == "move" and _mover(G) != null: break
				if not G.over: Game.AI.botPhase(G)
				Game.next()
			var mv = _mover(Game.G)
			print("mover: ", mv[0].name if mv != null else "none", " ", Game.G.y)
			if mv != null:
				main.cam.fly_to((main.board.pos_of(mv[0].loc) + main.board.pos_of(mv[1])) / 2.0, 0.42)])
		a.append(["wait", 50])
		a.append(["call", func():
			print("cam ", main.cam.position, " ", main.cam.get_screen_center_position(), " ", main.cam.zoom, " ", main.cam.is_current())
			var mv = _mover(Game.G)
			print("ship hit ", _hit_of(mv[0].id), " scr ", _scr(_hit_of(mv[0].id)), " dest ", main.board.pos_of(mv[1]))
			var sp := _scr(_hit_of(mv[0].id))
			var dp := _scr(main.board.pos_of(mv[1]))
			_mouse(sp, true)
			for i in 10: _move(sp.lerp(dp, (i + 1) / 10.0))])
		a.append(["wait", 10])
		a.append(["shot", "50_dragging"])
		a.append(["call", func():
			var mv = _mover(Game.G)
			var dp := _scr(main.board.pos_of(mv[1]))
			_mouse(dp, false)
			print("after drop: ", SHRules._find(Game.G.ships, func(x): return x.id == mv[0].id).loc, " (target ", mv[1], ")")])
		a.append(["wait", 20])
		a.append(["shot", "51_dropped"])
		a.append(["call", func():
			var s = Game.G.ships[0]
			var e := InputEventMouseMotion.new()
			e.position = _scr(_hit_of(s.id))
			e.global_position = e.position
			get_viewport().push_input(e)])
		a.append(["wait", 10])
		a.append(["shot", "52_hover"])
		a.append(["call", func():
			var s = Game.G.ships[0]
			for down in [true, false]:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_RIGHT
				e.pressed = down
				e.position = _scr(_hit_of(s.id))
				e.global_position = e.position
				get_viewport().push_input(e)])
		a.append(["wait", 10])
		a.append(["shot", "53_zoom"])
	if plan == "ships25":
		a.append(["call", func():
			for i in 150:
				var G = Game.G
				while G.ask.size(): Game.AI.answerAsks(G)
				if G.phase == "move" and G.ships.any(func(x): return x.loc != "earth"): break
				if not G.over: Game.AI.botPhase(G)
				Game.next()
			main.toggle_3d()])
		a.append(["wait", 10])
		a.append(["call", func():
			var sh = SHRules._find(Game.G.ships, func(x): return x.loc != "earth")
			if sh != null:
				Game.select({"t": "ship", "id": sh.id})
				main.v25.focus(main.board.pos_of(sh.loc), .5)])
		a.append(["wait", 15])
		a.append(["shot", "80_ships"])
		a.append(["call", func():
			main.v25.C.dist = 260
			main.v25.clampCam()
			main.v25.touch()])
		a.append(["wait", 10])
		a.append(["shot", "81_close"])
		a.append(["call", func(): main.tabs.current_tab = 1])
		a.append(["wait", 10])
		a.append(["shot", "82_selected"])
		a.append(["call", func():
			var sh = Game.G.ships[0]
			sh.cap = 4
			if sh != null:
				sh.cargo = {"ORE": 2, "SUP": 1, "FUEL": 0}
				Game.select({"t": "ship", "id": sh.id})
				Game.changed.emit()])
		a.append(["wait", 10])
		a.append(["shot", "83_cargo"])
	if plan == "3ddrag":
		a.append(["call", func():
			for i in 120:
				var G = Game.G
				while G.ask.size(): Game.AI.answerAsks(G)
				if G.phase == "move" and _mover(G) != null: break
				if not G.over: Game.AI.botPhase(G)
				Game.next()
			main.toggle_3d()])
		a.append(["wait", 10])
		a.append(["call", func():
			var mv = _mover(Game.G)
			main.v25.focus(main.board.pos_of(mv[0].loc), .5)])
		a.append(["wait", 10])
		a.append(["shot", "70_v25_before"])
		a.append(["call", func():
			var mv = _mover(Game.G)
			var sp := _scr25(_hit_of(mv[0].id), 34)
			var dsh = main.v25.BOXSH.get(mv[1])
			var dp: Vector2
			if dsh != null:
				var c := Vector2.ZERO
				for q in dsh: c += q
				c /= dsh.size()
				var pr = main.v25.proj(c.x, 7, c.y)
				dp = Vector2(pr[0], pr[1])
			else: dp = _scr25(main.board.pos_of(mv[1]), 0)
			print("drag ", mv[0].name, " to ", mv[1], " from ", sp, " to ", dp)
			_mouse(sp, true)
			for i in 10: _move(sp.lerp(dp, (i + 1) / 10.0))])
		a.append(["wait", 6])
		a.append(["shot", "71_v25_dragging"])
		a.append(["call", func():
			var mv = _mover(Game.G)
			var dsh = main.v25.BOXSH.get(mv[1])
			var dp: Vector2
			if dsh != null:
				var c := Vector2.ZERO
				for q in dsh: c += q
				c /= dsh.size()
				var pr = main.v25.proj(c.x, 7, c.y)
				dp = Vector2(pr[0], pr[1])
			else: dp = _scr25(main.board.pos_of(mv[1]), 0)
			_mouse(dp, false)
			var s = SHRules._find(Game.G.ships, func(x): return x.id == mv[0].id)
			print("after drop: ", s.loc, " (target ", mv[1], ")")])
		a.append(["wait", 10])
		a.append(["shot", "72_v25_dropped"])
		a.append(["call", func():
			var mv0 = SHRules._find(Game.G.ships, func(x): return x.name == "Orion")
			var sp := _scr25(_hit_of(mv0.id), 34)
			_mouse(sp, true)
			_mouse(sp, false)
			print("selected: ", Game.sel)])
		a.append(["wait", 10])
		a.append(["shot", "73_v25_tap"])
	if plan == "scatest":
		a.append(["call", func(): main.toggle_3d()])
		a.append(["wait", 20])
		for k in ["sca", "eri", "sed", "dsa", "kui", "alp"]:
			a.append(["call", func():
				main.v25.focusPod(k)])
			a.append(["wait", 12])
			a.append(["call", func():
				for y in range(100, 800, 60):
					for x in range(60, 1100, 70):
						var e := InputEventMouseMotion.new()
						e.position = Vector2(x, y)
						e.global_position = e.position
						get_viewport().push_input(e)
						_mouse(Vector2(x, y), true)
						_mouse(Vector2(x, y), false)])
			a.append(["wait", 5])
			a.append(["shot", "sc_" + k])
	if plan == "planets":
		a.append(["call", func(): main.toggle_3d()])
		a.append(["wait", 20])
		for k in ["ear", "jup", "sat", "mar", "mer", "ven", "ura", "nep", "moo", "tit", "gan", "cer"]:
			a.append(["call", func():
				var q: Vector2 = main.v25.sheetToScene(main.board.world_center(k))
				main.v25.C.tx = q.x
				main.v25.C.tz = q.y + 10
				main.v25.C.dist = 420
				main.v25.C.pitch = 1.1
				main.v25.C.yaw = 0.0
				main.v25.clampCam()
				main.v25.touch()])
			a.append(["wait", 14])
			a.append(["shot", "pl_" + k])
	if plan == "warm":
		a.append(["call", func():
			main.warm_enabled = true
			main._startup_load()])
		a.append(["wait", 4])
		a.append(["shot", "90_loading"])
		a.append(["wait", 150])
		a.append(["shot", "91_after"])
		a.append(["call", func():
			Game.new_campaign(f, {"scenario": "std"}, [])])
		a.append(["wait", 6])
		a.append(["shot", "92_warm"])
		a.append(["wait", 200])
		a.append(["shot", "93_game"])
		a.append(["call", func():
			var t0 := Time.get_ticks_msec()
			main.toggle_3d()
			main.v25.frame()
			print("TOGGLE_MS ", Time.get_ticks_msec() - t0)])
		a.append(["wait", 10])
		a.append(["shot", "94_25d"])
		a.append(["call", func(): main.v25.fit()])
		a.append(["wait", 10])
		a.append(["shot", "95_fit"])
		a.append(["call", func(): main.v25.focusPod("jup")])
		a.append(["wait", 10])
		a.append(["shot", "96_jup"])
	if plan == "newui":
		a.append(["call", func():
			Game.G.phase = "build"
			Game.G.cash = 40
			var o = SHRules._find(Game.E.buildOptions(Game.G, "earth"), func(x): return x.why == null and x.kind == "Orbiter")
			Game.act(Game.E.buildUnit(Game.G, o.key, "earth"))
			Game.act(Game.E.buildLV(Game.G, 2, "earth"))
			main.tabs.current_tab = 0])
		a.append(["wait", 20])
		a.append(["shot", "70_turn_build"])
		a.append(["call", func():
			main.tabs.current_tab = 2
			main.fboard.scroll.scroll_vertical = 0])
		a.append(["wait", 20])
		a.append(["shot", "71_board_top"])
		a.append(["call", func(): main.fboard.scroll.scroll_vertical = 520])
		a.append(["wait", 10])
		a.append(["shot", "72_board_mid"])
		a.append(["call", func(): main.fboard.scroll.scroll_vertical = 1100])
		a.append(["wait", 10])
		a.append(["shot", "73_board_low"])
		a.append(["call", func():
			main.tabs.current_tab = 1
			var s = SHRules._find(Game.G.ships, func(x): return x.cls == "RE")
			Game.select({"t": "ship", "id": s.id})
			main.scrap_ask(s)])
		a.append(["wait", 10])
		a.append(["shot", "74_scrap"])
		a.append(["call", func():
			main.modal.visible = false
			var o = SHRules._find(Game.E.buildOptions(Game.G, "earth"), func(x): return x.why == null)
			main.buy_unit(o, "earth")])
		a.append(["wait", 10])
		a.append(["shot", "75_buy_confirm"])
		a.append(["call", func():
			main.modal.visible = false
			Game.G.phase = "move"
			main.tabs.current_tab = 0
			Game.changed.emit()])
		a.append(["wait", 10])
		a.append(["shot", "76_turn_move"])
		a.append(["call", func():
			var s = SHRules._find(Game.G.ships, func(x): return Game.E.moves(Game.G, x).size() > 0)
			Game.select({"t": "ship", "id": s.id})
			var m = Game.E.moves(Game.G, s)[0]
			main.do_move(s, m.dest)])
		a.append(["wait", 10])
		a.append(["shot", "77_move_confirm"])
	if plan == "hangar":
		for it in [["na", "na|Orion", "orion"], ["eu", "eu|Newton", "newton"], ["ru", "ru|Sakharov", "sakharov"], ["cn", "cn|Zheng He", "zhenghe"], ["jp", "jp|Yamato", "yamato"], ["as", "as|Delhi", "delhi"], ["sa", "sa|Humboldt", "humboldt"], ["na", "na|Pathfinder", "pathfinder"], ["eu", "eu|Europa", "europa"], ["as", "as|Suri", "suri"], ["ru", "ru|Tsander", "tsander"]]:
			a.append(["call", func(): main.hangar.open(it[0], it[1])])
			a.append(["wait", 40])
			a.append(["shot", "h_" + it[2]])
		return a
	if plan == "basepanel":
		a.append(["call", func():
			var G = Game.G
			var s = SHRules._find(G.ships, func(x): return x.cls == "CV")
			G.phase = "trade"
			G.cash = 30
			G.tech.elev = true
			G.tech.terra = true
			var b := {"id": "bt", "name": "Alpha", "w": "mar", "stock": {"ORE": 6, "SUP": 6, "FUEL": 3}, "fac": {"lab": 1, "mine": 1, "sup": 0, "def": 0}, "dmg": {"lab": 0, "mine": 1, "sup": 0, "def": 0}, "set": 2, "setDmg": 0, "setHits": 1, "trade": {"side": "buy", "type": "SUP"}, "out": "ORE", "built": 2030, "techField": "Phy", "pos": "surf"}
			G.bases.append(b)
			Game.select({"t": "base", "id": "bt"})
			main.tabs.current_tab = 1
			Game.changed.emit()])
		a.append(["wait", 20])
		a.append(["shot", "80_base_panel"])
		a.append(["call", func():
			main._fac_ask(Game.G, Game.G.bases[0], "lab")])
		a.append(["wait", 10])
		a.append(["shot", "81_fac_confirm"])
		a.append(["call", func():
			main.modal.visible = false
			Game.G.phase = "econ"
			Game.G.estep = "production"
			main.tabs.current_tab = 0
			Game.changed.emit()])
		a.append(["wait", 10])
		a.append(["shot", "82_production"])
	if plan == "rings":
		for k in ["sat", "nep"]:
			a.append(["call", func(): main.cam.fly_to(main.board.world_center(k), 0.9)])
			a.append(["wait", 40])
			a.append(["shot", "90_2d_" + k])
		a.append(["call", func(): main.toggle_3d()])
		a.append(["wait", 30])
		for k in ["sat", "nep"]:
			a.append(["call", func(): main.v25.focusPod(k)])
			a.append(["wait", 30])
			a.append(["shot", "91_3d_" + k])
	if plan == "padfilter":
		a.append(["call", func():
			main.tabs.current_tab = 2
			Game.G.phase = "build"
			Game.G.cash = 40
			var o = SHRules._find(Game.E.buildOptions(Game.G, "earth"), func(x): return x.why == null and x.kind == "Flyby")
			Game.act(Game.E.buildUnit(Game.G, o.key, "earth"))
			Game.act(Game.E.buildLV(Game.G, 1, "earth"))
			Game.G.phase = "move"
			Game.changed.emit()])
		a.append(["wait", 20])
		a.append(["call", func():
			var sh = SHRules._find(Game.G.ships, func(x): return Game.E.moves(Game.G, x).size() > 0 and x.loc == "earth")
			main.fboard._stage_on(sh.id)])
		a.append(["wait", 20])
		a.append(["call", func(): main.fboard.scroll.scroll_vertical = 500])
		a.append(["wait", 10])
		a.append(["shot", "95_pad_list"])
		a.append(["call", func():
			main._lf.q = "mars"
			Game.changed.emit()])
		a.append(["wait", 20])
		a.append(["shot", "96_pad_filtered"])
	if plan == "sliders":
		a.append(["call", func():
			Game.G.polm = 4
			main.ttree.convert_dialog()])
		a.append(["wait", 8])
		a.append(["call", func():
			var bx = main.modal_box
			var sl: Array = []
			for r in bx.get_children():
				for c in r.get_children():
					if c is HSlider: sl.append(c)
			sl[0].value = 1
			sl[2].value = 2])
		a.append(["wait", 8])
		a.append(["shot", "85_convert"])
		a.append(["call", func():
			main.modal.visible = false
			main.tabs.current_tab = main.TAB_TECH
			Game.G.estep = "tech"
			Game.changed.emit()])
		a.append(["wait", 10])
		a.append(["shot", "86_tech"])
		a.append(["call", func():
			main.tabs.current_tab = 1
			Game.G.phase = "build"
			var s = SHRules._find(Game.G.ships, func(x): return x.cls == "CV")
			s.loc = "earth"
			s.launched = false
			s.cap = 4
			s.moved = false
			print("SHIP ", s.name)
			Game.select({"t": "ship", "id": s.id})
			Game.G.phase = "move"
			Game.changed.emit()])
		a.append(["wait", 10])
		a.append(["shot", "87_cargo"])
		a.append(["call", func():
			for m in Game.data.D.MIS:
				if m.w == "mar" or m.w == "moo" or m.w == "nea":
					Game.G.mis.mine = m.id
					break
			main._lf.q = "mars"
			Game.changed.emit()])
		a.append(["wait", 10])
		a.append(["shot", "88_filtered"])
		a.append(["call", func():
			main._lf.q = ""
			main._lf.f = "Phy"
			Game.G.phase = "explore"
			Game.changed.emit()])
		a.append(["wait", 10])
		a.append(["shot", "89_phy"])
	if plan == "picker":
		a.append(["call", func():
			main._setup.f = "cn"
			main._setup.botset = ["na", "eu", "cn"] if false else ["na", "eu"]
			main._setup.bots = true
			main.show_menu("start")])
		a.append(["wait", 10])
		a.append(["shot", "80_picker"])
		a.append(["call", func():
			main._start()])
		a.append(["wait", 40])
		a.append(["call", func(): print("FACS ", Game.G.f, " ", Game.G.variant, " ", Game.W.facs.keys())])
	if plan == "dsa":
		a.append(["call", func(): main.toggle_3d()])
		a.append(["wait", 20])
		a.append(["call", func(): main.v25.focusPod("dsa")])
		a.append(["wait", 20])
		a.append(["shot", "70_dsa"])
	if plan == "3d" or plan == "3dbots":
		if plan == "3dbots":
			a.append(["call", func():
				for i in int(OS.get_environment("SH_STEPS") if OS.get_environment("SH_STEPS") != "" else "40"):
					var G = Game.G
					while G.ask.size(): Game.AI.answerAsks(G)
					if not G.over: Game.AI.botPhase(G)
					Game.next()])
		a.append(["call", func(): main.toggle_3d()])
		a.append(["wait", 30])
		a.append(["shot", "60_v25_home"])
		a.append(["call", func(): main.v25.fit()])
		a.append(["wait", 10])
		a.append(["shot", "61_v25_fit"])
		for spot in [["62_v25_earth", "ear"], ["63_v25_jupiter", "jup"], ["64_v25_mars", "mar"], ["65_v25_saturn", "sat"], ["66_v25_kuiper", "kui"], ["67_v25_alpha", "alp"], ["67b_sca", "sca"], ["67c_eri", "eri"], ["67d_dsa", "dsa"], ["67e_sed", "sed"], ["67f_sun", "sun"], ["67g_neptune", "nep"]]:
			a.append(["call", func(): main.v25.focusPod(spot[1])])
			a.append(["wait", 12])
			a.append(["shot", spot[0]])
		a.append(["call", func():
			main.v25.home(main.board.pos_of("earth"))
			main.v25.rotate_by(.6, -.3)])
		a.append(["wait", 10])
		a.append(["shot", "68_v25_turned"])
		a.append(["call", func():
			main.v25.debug_calls = true
			main.v25.frame()
			main.v25.debug_calls = false
			for i in 12:
				var mi: MeshInstance3D = main.v25._pool[i]
				print(i, " vis ", mi.visible, " aabb ", mi.mesh.get_aabb() if mi.mesh else null, " mode ", mi.material_override.get_shader_parameter("MODE") if mi.material_override else null, " off ", mi.sorting_offset, " surf ", mi.mesh.get_surface_count() if mi.mesh else -1)
			var t0 := Time.get_ticks_usec()
			main.v25.prof = true
			for i in 10: main.v25.frame()
			main.v25.prof = false
			print("v25 frame ms: ", (Time.get_ticks_usec() - t0) / 10000.0)
			for k in main.v25._tms: print("  ", k, " ", main.v25._tms[k] / 10000.0)
			main.toggle_3d()])
		a.append(["wait", 20])
		a.append(["shot", "69_back_flat"])
	if plan == "fx":
		for spot in [["40_earth", "ear", 0.8], ["41_sun", "mer", 0.45], ["42_jupiter", "jup", 0.6], ["43_far", "ear", 0.12]]:
			a.append(["call", func():
				var p: Vector2 = main.board.world_center(spot[1]) if spot[1] != "mer" else Vector2(351, 1340)
				main.cam.position = p
				main.cam.zoom = Vector2(spot[2], spot[2])])
			a.append(["wait", 30])
			a.append(["shot", spot[0]])
	if plan == "dev":
		a.append(["call", func(): main.dev.open()])
		a.append(["wait", 10])
		a.append(["call", func():
			main.dev.run("give me cash 20")
			main.dev.run("tech me all")
			main.dev.run("show me")
			main.dev.run("rel me na alliance")])
		a.append(["wait", 10])
		a.append(["shot", "40_dev"])
		a.append(["call", func():
			main.dev.close()
			Game.G = null
			main.show_menu("title")
			main.show_menu("start")
			main._setup.bots = true
			main.show_menu("start")])
		a.append(["wait", 12])
		a.append(["shot", "41_picker"])
	if plan == "menus":
		a.append(["call", func():
			Game.next()
			main.next_click()])
		a.append(["wait", 20])
		a.append(["shot", "30_next_confirm"])
		a.append(["call", func():
			main._modal_enter.call()
			print("phase after enter: ", Game.G.phase)
			main.show_menu("pause")])
		a.append(["wait", 20])
		a.append(["shot", "31_pause"])
		a.append(["call", func():
			print("saved slot 2: ", Game.save_slot(2))
			main.show_menu("save")])
		a.append(["wait", 20])
		a.append(["shot", "32_save"])
		a.append(["call", func(): main.show_menu("settings")])
		a.append(["wait", 20])
		a.append(["shot", "33_settings"])
		a.append(["call", func():
			main._close_menu()
			print("load slot 2: ", Game.load_slot(2), " ", Game.G.phase)
			main.tabs.current_tab = main.TAB_LOG
			main._log_btns["key"].emit_signal("pressed")])
		a.append(["wait", 20])
		a.append(["shot", "34_log"])
	if plan == "screens":
		# play (bots for everyone) until one of our ships can explore a world, then show the explore screens
		a.append(["call", func():
			for i in 400:
				var G = Game.G
				while G.ask.size(): Game.AI.answerAsks(G)
				if G.phase == "explore" and _explorer(G) != null: break
				if not G.over: Game.AI.botPhase(G)
				Game.next()
			var G = Game.G
			var se = _explorer(G)
			print("explorer: ", se[0].name if se != null else "none", " ", G.y)
			if se != null: main.show_explore(G, se[0], se[1])])
		a.append(["wait", 20])
		a.append(["shot", "20_explore_confirm"])
		a.append(["call", func():
			var G = Game.G
			var se = _explorer(G)
			main.modal.visible = false
			if se != null: Game.roll_act(func(): return Game.E.explore(G, se[0], se[1]), true)])
		a.append(["wait", 40])
		a.append(["shot", "21_explore_result"])
		a.append(["call", func():
			main.modal.visible = false
			var G = Game.G
			G.lastRoll = {"kind": "life", "title": "Search for life on Europa", "extra": [], "life": {"r": 7, "found": true, "need": 12, "seek": "microbial life", "bonus": " (+2 from Astrobiology)", "reward": "4 Biology points and 2 VP"}}
			main.show_roll()])
		a.append(["wait", 30])
		a.append(["shot", "22_life"])
		var fake := [
			{"k": "search", "ok": true, "auto": false, "T": 4, "rolls": [{"n": "You", "r": 3}, {"n": "Pirate", "r": 6}], "where": "Jupiter flyby box", "text": "Your fleet finds the pirate."},
			{"k": "battle", "rem": 3, "lose": false, "tie": false, "tp": 5, "opp": 2, "d": 7, "od": 4, "strike": {"dealt": 1, "taken": 0, "tot": 12, "otot": 7}, "direct": {"dealt": 3, "taken": 2, "tot": 12, "otot": 7},
				"mine": [{"n": "Ares II", "cb": 3}, {"n": "base Olympus", "cb": 2}], "theirs": [{"n": "Shenzhou 9", "cb": 2}], "foe": "China", "where": "Mars orbit", "text": "Combat with China at Mars orbit."},
			{"k": "pbattle", "st": {"dm": 6, "dp": 3}, "mine": [{"n": "Ares II", "cb": 3}], "weapons": 1, "pir": {"strong": true, "cb": 3, "size": 2, "dmg": 0}, "myTot": 10, "pTot": 6, "strike": {"deal": 0, "take": 1}, "direct": {"deal": 2, "take": 1}, "myTP": 4, "pTP": 1, "extra": 3, "text": "A strong pirate attacks your fleet in the Saturn flyby box."},
			{"k": "assign", "text": "Your fleet hits China: choose which of their units take the hits, and which of yours.", "screen": [{"key": "12", "n": "Ares III (supply)"}], "groups": [{"side": "foe", "n": 2, "units": [{"key": "40", "n": "Shenzhou 9", "cb": 2, "hp": 3}, {"key": "41", "n": "Tiangong", "cb": 1, "hp": 2}]}, {"side": "mine", "n": 1, "units": [{"key": "10", "n": "Ares II", "cb": 3, "hp": 3}]}]},
			{"k": "basehit", "n": 3, "caps": {"def": 2, "lab": 1, "mine": 2, "set": 3, "res": 4}, "stock": {"ORE": 3, "SUP": 2, "FUEL": 1}, "text": "Your fleet hit China's base Yuegong 2 times."}]
		for i in fake.size():
			var q: Dictionary = fake[i]
			a.append(["call", func():
				main.modal.visible = false
				Game.G.ask.push_front(q)
				Game.changed.emit()])
			a.append(["wait", 30])
			a.append(["shot", "%d_%s" % [23 + i, q.k]])
			a.append(["call", func(): Game.G.ask.pop_front()])
	return a

func _mover(G):
	for s in G.ships:
		if s.loc == "earth": continue
		for m in Game.E.moves(G, s):
			if m.dest != s.loc and m.dest != "earth": return [s, m.dest]
	return null
func _hit_of(id) -> Vector2:
	for h in main.board.hits:
		if h.t == "ship" and SHRules.eq(h.id, id): return h.c
	return Vector2.ZERO
## a board point's screen position in the 2.5D view, lifted like a standing counter
func _scr25(bp: Vector2, lift: float) -> Vector2:
	var v = main.v25
	var q: Vector2 = v.mapP(bp.x, bp.y)
	var pr = v.proj(q.x, lift * v.LAY.S + 31 * v.LAY.S, q.y)
	return Vector2(pr[0], pr[1])
func _scr(wp: Vector2) -> Vector2:
	return (wp - main.cam.get_screen_center_position()) * main.cam.zoom + get_viewport().get_visible_rect().size / 2.0

func _explorer(G):
	for s in G.ships:
		for o in Game.E.exploreOptions(G, s):
			if o.kind == "explore" or o.kind == "probe": return [s, o]
	return null

func _find_node(n: Node, f: Callable):
	for c in n.get_children():
		if f.call(c): return c
		var r = _find_node(c, f)
		if r != null: return r
	return null
func _inside(n: Node, fb, which: String) -> bool:
	# the tray is the drop zone with no pad label: a tile inside a DropZone whose first child is a flow container
	var p := n.get_parent()
	while p != null and p != fb:
		if p.has_method("_drop_data"): return p.get_child(0) is HFlowContainer
		p = p.get_parent()
	return false
func _is_pad(n: Node) -> bool: return n.get_child_count() and n.get_child(0) is HBoxContainer
func _mouse(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	if down: e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e)
func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.relative = Vector2(8, 8)
	get_viewport().push_input(e)

func _process(_dt: float) -> void:
	if step >= actions.size():
		get_tree().quit()
		return
	var act: Array = actions[step]
	match act[0]:
		"wait":
			act[1] -= 1
			if act[1] > 0: return
		"shot":
			var img := get_viewport().get_texture().get_image()
			img.save_png(out.path_join(act[1] + ".png"))
			print("shot ", act[1])
		"call": act[1].call()
		"dragtype":
			var fb = main.fboard
			var src = _find_node(fb, func(n): return n.has_method("_get_drag_data") and "lv_n" in n and n.lv_n > 0 and not n.buy)
			var dst = _find_node(fb, func(n): return n.has_method("_drop_data") and "ship_id" in n and n.ship_id != null)
			if src == null or dst == null: print("dragtype: missing ", src, " ", dst)
			else:
				var a := (src as Control).get_global_rect().get_center()
				var b := (dst as Control).get_global_rect().get_center()
				_mouse(a, true)
				for i in 12: _move(a.lerp(b, (i + 1) / 12.0))
				_mouse(b, false)
		"drag":
			var fb = main.fboard
			var src = _find_node(fb, func(n): return n.has_method("_get_drag_data") and n.ship_id != null and _inside(n, fb, "tray"))
			var dst = _find_node(fb, func(n): return n.has_method("_drop_data") and _is_pad(n))
			if src == null or dst == null:
				print("drag: missing ", src, " ", dst)
			else:
				var a := (src as Control).get_global_rect().get_center()
				var b := (dst as Control).get_global_rect().get_center()
				_mouse(a, true)
				for i in 12: _move(a.lerp(b, (i + 1) / 12.0))
				_mouse(b, false)
	step += 1
