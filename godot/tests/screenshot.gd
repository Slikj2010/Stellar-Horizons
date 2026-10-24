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
	Input.parse_input_event(e)
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
