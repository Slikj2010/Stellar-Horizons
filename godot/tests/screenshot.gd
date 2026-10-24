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
	return a

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
