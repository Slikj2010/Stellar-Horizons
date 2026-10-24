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
	if plan == "year":
		for i in int(OS.get_environment("SH_STEPS") if OS.get_environment("SH_STEPS") != "" else "60"):
			a.append(["call", func():
				var G = Game.G
				while G.ask.size(): Game.AI.answerAsks(G)
				if not G.over: Game.AI.botPhase(G)
				Game.next()])
			a.append(["wait", 1])
		a.append(["call", func(): main.tabs.current_tab = 3])
		a.append(["wait", 20])
		a.append(["shot", "09_log"])
		a.append(["call", func(): main.tabs.current_tab = 0; main.cam.setup(main.board.map_rect())])
		a.append(["wait", 20])
		a.append(["shot", "10_map"])
	return a

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
	step += 1
