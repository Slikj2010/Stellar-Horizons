## Two copies of the game play an online campaign on this computer: one hosts, one joins; both play their faction with the bot logic.
## godot --headless --path godot res://tests/net_test.tscn -- host|join [target year]
extends Node

var role := "host"
var target := 2032
var t := 0.0
var started := false
var reached := -1.0
var last_holder := ""
var picked := false
var steps := 0
var fac := "jp"
var want := 2
var quit_at := 99999

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	role = a[0] if a.size() else "host"
	target = int(a[1]) if a.size() > 1 else 2032
	fac = a[2] if a.size() > 2 else "jp"
	want = int(a[3]) if a.size() > 3 else 2
	quit_at = int(a[4]) if a.size() > 4 else 99999
	if role == "host":
		Net.host_game("Host")
		Net.choose("na")
	else:
		Net.join_game("127.0.0.1", "Guest")
	Net.game_started.connect(func(): started = true; print(role, ": game started, I am ", Net.me))

func _process(dt: float) -> void:
	t += dt
	if t > 240.0:
		print(role, ": TIMEOUT")
		get_tree().quit(1)
	if not started:
		if role == "host":
			if not picked and Net.players.size() >= want:
				picked = true
				Net.set_bots([{"f": "eu"}, {"f": "ru"}] if want == 2 else [{"f": "ru"}], "std")
			if Net.players.size() >= want and Net.can_start() == "" and t > 2.0:
				Net.start_game()
		else:
			if Net.players.size() >= 1 and not picked:
				picked = true
				Net.choose(fac)
		return
	var G = Game.G
	if G == null: return
	if Net.holder != last_holder:
		last_holder = Net.holder
		print(role, ": turn -> ", Net.holder, " ", int(G.y), " ", G.phase, " ", G.estep)
	if int(G.y) >= quit_at:
		print(role, ": quitting now")
		get_tree().quit(0)
	if int(G.y) >= target:
		if reached < 0: reached = t
		if t - reached > 5.0: _report()
		return
	if t - float(int(t * 20)) / 20.0 > 0.0 and fmod(t, 0.05) > dt: return
	if not Net.my_turn(): return
	steps += 1
	var A = Game.AI
	A.answerAsks(G)
	if A.techStep(G):
		if Game.E.techTurn(G.world) == G.f:
			A.techTurnBot(G)
			Game.act(null)
		else:
			Game.next()
	else:
		A.botPhase(G)
		A.answerAsks(G)
		Game.next()

func _report() -> void:
	var G = Game.G
	var out := []
	for f in G.world.facs:
		var g = G.world.facs[f]
		out.append("%s:%s/%s/c%d/s%d/t%d" % [f, int(g.y), g.phase, int(g.cash), g.ships.size(), g.tech.size()])
	print("RESULT ", role, " ", " ".join(out))
	get_tree().quit(0)
