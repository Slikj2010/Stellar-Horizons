## Main scene: wires the board, the camera and the HUD (top bar, side panel, question dialog, menus) to the Game autoload.
extends Node

@onready var board: Node2D = $Board
@onready var cam: Camera2D = $Camera
@onready var root: Control = $HUD/Root
@onready var year_lbl: Label = $HUD/Root/TopBar/Row/Year
@onready var phase_lbl: Label = $HUD/Root/TopBar/Row/Phase
@onready var stats_lbl: Label = $HUD/Root/TopBar/Row/Stats
@onready var score_lbl: Label = $HUD/Root/TopBar/Row/Score
@onready var tabs: TabContainer = $HUD/Root/Side/VBox/Tabs
@onready var turn_box: VBoxContainer = $HUD/Root/Side/VBox/Tabs/Turn/Box
@onready var sel_box: VBoxContainer = $HUD/Root/Side/VBox/Tabs/Selected/Box
@onready var fac_box: VBoxContainer = $HUD/Root/Side/VBox/Tabs/Faction/Box
@onready var log_text: RichTextLabel = $HUD/Root/Side/VBox/Tabs/Log/Text
@onready var next_btn: Button = $HUD/Root/Side/VBox/Next
@onready var toast_panel: PanelContainer = $HUD/Root/Toast
@onready var toast_lbl: Label = $HUD/Root/Toast/Label
@onready var dialog: PanelContainer = $HUD/Root/Dialog
@onready var dialog_box: VBoxContainer = $HUD/Root/Dialog/Box
@onready var menu: ColorRect = $HUD/Root/Menu
@onready var menu_box: VBoxContainer = $HUD/Root/Menu/Center/Panel/Box

const PHASE_HELP := {
	"econ": "Once a decade: politics and events, diplomacy, production, resource transport, bases, asteroids and pirates, technologies, settlement growth and policy.",
	"build": "Build robotic explorers, crew vehicles and launch vehicles; unreserve and repair crew vehicles.",
	"move": "Select a ship (outlined in blue) and pick a destination on the map or in the Selected tab. Launches need a launch vehicle and an engine roll.",
	"combat": "Attack pirates, blockade or raid bases of factions you are at embargo or war with.",
	"explore": "Select a ship that can explore (outlined in blue) and choose what to explore.",
	"trade": "Found bases with crew vehicles carrying supplies, build facilities and settlements, trade.",
}
const HOTKEYS := {KEY_1: "mer", KEY_2: "ven", KEY_SPACE: "ear", KEY_3: "mar", KEY_4: "bel", KEY_5: "jup", KEY_6: "sat", KEY_7: "ura", KEY_8: "nep", KEY_9: "kui", KEY_0: "sca", KEY_A: "alp"}

var E: SHRules
var D: Dictionary
var _press := Vector2.ZERO
var _dragging := false
var _drag_btn := 0
var _toast_t := 0.0
var _log_seen := 0
var _setup := {"f": "eu", "bots": false, "scenario": "std", "variant": "mil", "scrapRE": false, "enhTrade": false}

func _ready() -> void:
	E = Game.E
	D = Game.data.D
	cam.setup(board.map_rect())
	Game.changed.connect(refresh)
	Game.toast.connect(show_toast)
	Game.campaign_started.connect(_on_started)
	next_btn.pressed.connect(func(): Game.next())
	$HUD/Root/TopBar/Row/MenuBtn.pressed.connect(func(): show_menu("pause"))
	tabs.set_tab_title(0, "Turn")
	tabs.set_tab_title(1, "Selected")
	tabs.set_tab_title(2, "Faction")
	tabs.set_tab_title(3, "Log")
	show_menu("start")
	refresh()

func _process(dt: float) -> void:
	if _toast_t > 0:
		_toast_t -= dt
		if _toast_t <= 0: toast_panel.visible = false

func _on_started() -> void:
	menu.visible = false
	_log_seen = 0
	tabs.current_tab = 0
	var ep: Vector2 = board.world_center("ear")
	cam.fly_to(ep, 0.32)

# ---------------- input on the board ----------------
func _unhandled_input(ev: InputEvent) -> void:
	if menu.visible: return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: cam.zoom_at(1.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: cam.zoom_at(1 / 1.12, mb.position)
		elif mb.pressed:
			_press = mb.position
			_dragging = true
			_drag_btn = mb.button_index
		elif _dragging and mb.button_index == _drag_btn:
			_dragging = false
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.position.distance_to(_press) < 6: _click(board.get_global_mouse_position())
	elif ev is InputEventMouseMotion and _dragging:
		cam.pan_screen((ev as InputEventMouseMotion).relative)
	elif ev is InputEventMagnifyGesture:
		cam.zoom_at((ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)
	elif ev is InputEventPanGesture:
		cam.pan_screen(-(ev as InputEventPanGesture).delta * 20)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = (ev as InputEventKey).keycode
		if HOTKEYS.has(k): _jump(HOTKEYS[k])
		elif k == KEY_ESCAPE: Game.select(null)
		elif k == KEY_ENTER or k == KEY_KP_ENTER: Game.next()

func _jump(sy: String) -> void:
	var hub = D.SYS[sy].hub
	var p: Vector2 = board.world_center(hub) if (hub != null and board.geo.worlds.has(hub)) else board.v2(board.geo.sys[sy].flyby)
	cam.fly_to(p, maxf(cam.zoom.x, 0.38))

func _click(pt: Vector2) -> void:
	var G = Game.G
	if G == null: return
	var h: Dictionary = board.pick_at(pt)
	if h.is_empty():
		Game.select(null)
		return
	match h.t:
		"ship":
			Game.select({"t": "ship", "id": h.id})
			tabs.current_tab = 1
		"dest":
			var s = _sel_ship()
			if s != null: do_move(s, h.dest)
		"base":
			Game.select({"t": "base", "id": h.id})
			tabs.current_tab = 1
		"npf":
			Game.select({"t": "npf", "k": h.k})
			tabs.current_tab = 1
		"oship":
			Game.select({"t": "oship", "f": h.f, "id": h.id})
			tabs.current_tab = 1
		"world":
			Game.select({"t": "world", "k": h.k})
			tabs.current_tab = 1

func _sel_ship():
	var s = Game.sel
	if s == null or s.t != "ship": return null
	return E._shipById(Game.G, s.id)

func do_move(s, dest: String, extra := {}) -> void:
	var opt := {"probe": SHRules._first(Game.G.probes.get(s.loc, []))}
	for k in extra: opt[k] = extra[k]
	Game.act(E.move(Game.G, s, dest, opt))

# ---------------- refresh ----------------
func refresh() -> void:
	var G = Game.G
	if G == null:
		board.targets = []
		board.queue_redraw()
		return
	year_lbl.text = str(G.y)
	phase_lbl.text = (E.PHASE_NAME[G.phase] + ((" · " + E.ESTEP_NAME[G.estep]) if G.estep != null else "")).to_upper()
	var bank: Dictionary = G.bank
	stats_lbl.text = "%s    Cash $%sB    Politics %s    Victory %s    Physics %s    Engineering %s    Biology %s" % [D.FAC[G.f].n, SHRules.n(G.cash), G.polm, G.vm, bank.Phy, bank.Eng, bank.Bio]
	var sc := E.score(G)
	score_lbl.text = "Score " + SHRules.n(sc.total)
	var s = _sel_ship()
	board.targets = E.moves(G, s) if (s != null and G.phase == "move") else []
	board.queue_redraw()
	build_turn()
	build_selected()
	build_faction()
	build_log()
	next_btn.disabled = G.over or G.ask.size() > 0
	next_btn.text = "Campaign over" if G.over else ("Answer the question first" if G.ask.size() else "Next: " + _next_name(G))
	build_dialog()

func _next_name(G) -> String:
	if G.phase == "econ":
		var i := E.ESTEPS.find(G.estep)
		if i < E.ESTEPS.size() - 1:
			var nx: String = E.ESTEPS[i + 1]
			if nx == "initiative" and G.world == null: nx = E.ESTEPS[i + 2]
			return E.ESTEP_NAME[nx]
		return E.PHASE_NAME.build
	if G.phase == "trade": return "next year"
	var j := E.PHASES.find(G.phase)
	return E.PHASE_NAME[E.PHASES[j + 1]]

func show_toast(t: String) -> void:
	toast_lbl.text = t
	toast_panel.visible = true
	_toast_t = 4.0

# ---------------- Turn tab ----------------
func build_turn() -> void:
	var G = Game.G
	var box := turn_box
	UIK.clear(box)
	if G.over:
		UIK.title(box, "Campaign over")
		var sc := E.score(G)
		UIK.para(box, "Final score %s: %s." % [SHRules.n(sc.total), sc.rating], UIK.AMBER, 16)
		for p in sc.parts: UIK.para(box, "%s: %s" % [p[0], SHRules.n(p[1])], UIK.DIM)
		UIK.button(box, "New campaign", func(): show_menu("start"))
		return
	UIK.title(box, E.PHASE_NAME[G.phase] + ((": " + E.ESTEP_NAME[G.estep]) if G.estep != null else ""))
	UIK.para(box, PHASE_HELP[G.phase], UIK.DIM, 13)
	# what just happened (newest log lines since the last refresh of the turn)
	var recent: Array = G.log.slice(0, 4)
	if recent.size():
		var c := UIK.card(box)
		UIK.head(c, "Latest", UIK.CYAN)
		for l in recent: UIK.para(c, l.t, _log_col(l.c), 13)
	match G.phase:
		"econ": _turn_econ(box, G)
		"build": _turn_build(box, G)
		"move": _turn_move(box, G)
		"combat": _turn_combat(box, G)
		"explore": _turn_explore(box, G)
		"trade": _turn_trade(box, G)

func _turn_econ(box, G) -> void:
	var st = G.estep
	if st == "politics" or st == "tech":
		UIK.head(box, "Politics markers: %d" % G.polm)
		var f := UIK.flow(box)
		for to in ["cash", "Phy", "Eng", "Bio"]:
			var lbl: String = "→ $1B" if to == "cash" else "→ %d %s" % [3 if E.polLv(G, "dip") >= 3 else 2, E.FN[to]]
			UIK.button(f, lbl, func(): Game.act(E.convertPolitics(G, to)), G.polm < 1)
		UIK.button(f, "Buy victory marker (4)", func(): Game.act(E.buyVictory(G)), G.polm < 4)
		UIK.button(f, "Redraw mission (2)", func(): Game.act(E.redrawMission(G)), G.polm < 2 or G.mis.mine == null)
	if st == "initiative" and G.world != null:
		var slot: int = G.world.meta.order.find(G.f) + 1
		UIK.para(box, "Spend politics markers on initiative: +10%% each, at most %d (your slot). Now bidding %d." % [slot, int(SHRules.gi(G, "initBid", 0))])
		var f := UIK.flow(box)
		for k in range(0, mini(slot, G.polm) + 1): UIK.button(f, str(k), func(): Game.act(E.setInitBid(G, k)))
	if st == "diplomacy":
		UIK.para(box, "Each attempt costs 1, 2, 3… politics markers in total and succeeds on 6 or less. Planned cost: %d of %d." % [E.dipCost(G), G.polm])
		for k in G.rel:
			var h := UIK.hbox(box)
			var l := UIK.para(h, "%s: %s" % [D.FAC[k].n, D.REL[G.rel[k]]], null, 14)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var planned := int(SHRules.gi(G.dipl, k, 0))
			UIK.para(h, ("%+d" % planned) if planned else "", UIK.AMBER)
			UIK.button(h, "Improve", func(): Game.act(E.setDiplomacy(G, k, 1)))
			UIK.button(h, "Worsen", func(): Game.act(E.setDiplomacy(G, k, -1)))
	if st == "transport":
		var left: int = SHRules.gi(G, "transferLeft", 0)
		UIK.para(box, "Transfers left this decade: %d." % left)
		if left > 0:
			var places := [["earth", "Earth"]]
			for b in G.bases: places.append([b.id, b.name])
			var names := places.map(func(x): return x[1])
			var h := UIK.flow(box)
			var from := UIK.pick(h, names, 0)
			var to := UIK.pick(h, names, mini(1, names.size() - 1))
			var ty := UIK.pick(h, ["ORE", "SUP", "FUEL"], 1)
			var amt := UIK.spin(h, 1, left, 1)
			UIK.button(h, "Transfer", func(): Game.act(E.transferRes(G, places[from.selected][0], places[to.selected][0], ty.get_item_text(ty.selected), int(amt.value))))
	if st == "tech": _tech_list(box, G)
	if st == "policy":
		var left: int = SHRules.gi(G, "policyLeft", 0)
		UIK.para(box, ("Choose %d more policies (missed decades)." % left) if left > 0 else ("Policy chosen." if SHRules.t(G.get("policyPicked")) else "Choose one policy to adopt or upgrade."))
		for p in D.POL:
			var lv := E.polLv(G, p.k)
			var c := UIK.card(box)
			UIK.rich(c, "[b]%s%s[/b]  [color=#8fa3b8]%s[/color]" % [D.POL_LV[maxi(0, lv - 1)] if lv else "", p.n, ("level %d" % lv) if lv else "not held"])
			if lv < 3:
				UIK.para(c, "Next: " + p.d[lv], UIK.DIM, 13)
				UIK.button(c, "Adopt " + D.POL_LV[lv] + p.n, func(): Game.act(E.choosePolicy(G, p.k)), SHRules.t(G.get("policyPicked")))

func _tech_list(box, G) -> void:
	if G.world != null:
		var cur = E.techTurn(G.world)
		if cur == null: UIK.para(box, "Every faction has passed.", UIK.DIM)
		elif cur != G.f: UIK.para(box, "Research turn: " + D.FAC[cur].n, UIK.DIM)
		else:
			UIK.para(box, "Your research turn: develop one technology or pass.", UIK.AMBER)
			UIK.button(box, "Pass (no more technologies this decade)", func(): Game.act(E.techPass(G)))
	UIK.para(box, "Points: %d Physics, %d Engineering, %d Biology. Unspent points are halved at the end of the step." % [G.bank.Phy, G.bank.Eng, G.bank.Bio])
	var open: Array = D.TECH.filter(func(tt): return E.techState(G, tt) == "open")
	open = SHRules.ssort(open, func(a, b): return E.techCost(G, a) - E.techCost(G, b))
	for tt in open:
		var c := E.techCost(G, tt)
		var ok: bool = G.bank[tt.f] >= c
		var h := UIK.hbox(box)
		var l := UIK.rich(h, "[b][color=#%s]%s[/color][/b] · %d %s\n[color=#8fa3b8]%s[/color]" % [UIK.FIELD_COL[tt.f].to_html(false), tt.n, c, E.FN[tt.f], tt.d], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.button(h, "Develop", func(): Game.act(E.develop(G, tt.k)), not ok, E.techCostTxt(G, tt))

func _turn_build(box, G) -> void:
	UIK.head(box, "Earth shipyard")
	UIK.rich(box, "On Earth the resources on your faction board are used first (now %s), the rest is bought at $1B each." % UIK.res_bb(E.estock(G)), 13)
	for o in E.buildOptions(G, "earth"):
		if o.why == "in service": continue
		var h := UIK.hbox(box)
		UIK.image(h, UIK.atlas_tex("atlas_" + G.f, o.kind + "|" + o.u.n), 40)
		var l := UIK.rich(h, "[b]%s[/b] [color=#8fa3b8]%s[/color]\n%s = %s%s" % [o.u.n, o.kind, UIK.res_bb(o.cost), E.earthCostTxt(G, o.cost), (" · [color=#ef6b5b]%s[/color]" % o.why) if o.why != null else ""], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.button(h, "Build", func(): Game.act(E.buildUnit(G, o.key, "earth", false)), o.why != null or G.cash < E.earthCash(G, o.cost))
		if o.cv and o.why == null: UIK.button(h, "Reserved", func(): Game.act(E.buildUnit(G, o.key, "earth", true)), false, "Reserved: 1 SUP and 1 Fuel cheaper")
	UIK.head(box, "Launch vehicles")
	UIK.para(box, "On Earth: " + _lv_txt(G) + ". " + E.lvPoolTxt(G) + ".", UIK.DIM, 13)
	var f := UIK.flow(box)
	for z in [1, 2, 3, 4]: UIK.button(f, "Build LV-%d (1 ORE + %d FUEL)" % [z, z], func(): Game.act(E.buildLV(G, z, "earth")))
	var cvs: Array = G.ships.filter(func(s): return s.cls == "CV")
	if cvs.size():
		UIK.head(box, "Crew vehicles")
		for s in cvs:
			var h := UIK.hbox(box)
			UIK.image(h, UIK.atlas_tex("atlas_" + G.f, s.img + "|back" if SHRules.t(s.res) else s.img), 40)
			var l := UIK.rich(h, "[b]%s[/b] CV-%d · %s%s%s" % [s.name, s.sz, E.locName(s.loc), " · reserved" if SHRules.t(s.res) else "", (" · %d damage" % s.dmg) if SHRules.t(s.dmg) else ""], 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if SHRules.t(s.res): UIK.button(h, "Unreserve", func(): Game.act(E.unreserve(G, s)), not E.unreserveInfo(G, s).ok, String(E.unreserveInfo(G, s).get("why", "")))
			else: UIK.button(h, "Reserve", func(): Game.act(E.setReserve(G, s)))
			if SHRules.t(s.dmg): UIK.button(h, "Repair", func(): Game.act(E.repair(G, s)))
	for b in G.bases.filter(func(x): return SHRules.t(x.fac.sup)):
		UIK.head(box, b.name + " shipyard")
		UIK.rich(box, "Stock " + UIK.res_bb(b.stock), 13)
		var fl := UIK.flow(box)
		for z in [1, 2, 3, 4]: UIK.button(fl, "LV-%d" % z, func(): Game.act(E.buildLV(G, z, b.id)))
		for o in E.buildOptions(G, b.id):
			if o.why == null: UIK.button(fl, "Build " + o.u.n, func(): Game.act(E.buildUnit(G, o.key, b.id, false)))

func _lv_txt(G) -> String:
	var parts := []
	for z in [1, 2, 3, 4]:
		var k := int(SHRules.gi(G.lv.earth, z, 0))
		if k: parts.append("LV-%d ×%d" % [z, k])
	return ", ".join(parts) if parts.size() else "none"

func _ship_row(box, G, s, sub: String) -> HBoxContainer:
	var h := UIK.hbox(box)
	UIK.image(h, UIK.atlas_tex("atlas_" + G.f, s.img + "|back" if SHRules.t(s.res) else s.img), 40)
	var l := UIK.rich(h, "[b]%s[/b] [color=#8fa3b8]%s[/color]\n%s" % [s.name, ("CV-%d" % s.sz) if s.cls == "CV" else s.kind, sub], 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

func _turn_move(box, G) -> void:
	var ready: Array = G.ships.filter(func(s): return E.moves(G, s).size() > 0)
	UIK.head(box, "Ships that can move (%d)" % ready.size())
	for s in ready:
		var h := _ship_row(box, G, s, E.locName(s.loc))
		UIK.button(h, "Select", func():
			Game.select({"t": "ship", "id": s.id})
			if s.loc != "earth": cam.fly_to(board.pos_of(s.loc))
			tabs.current_tab = 1)
	var waiting: Array = G.ships.filter(func(s): return s.loc == "earth" and not E.moves(G, s).size())
	if waiting.size():
		UIK.para(box, "On Earth without a launch: " + ", ".join(waiting.map(func(s): return s.name)) + ". They need a launch vehicle (build one, or one is bought at launch if a counter is free).", UIK.DIM, 13)
	if G.bases.size():
		UIK.head(box, "Cargo flight from Earth to a base")
		var h := UIK.flow(box)
		var bp := UIK.pick(h, G.bases.map(func(b): return b.name))
		var sp := {}
		for r in ["ORE", "SUP", "FUEL"]:
			UIK.para(h, r, UIK.DIM, 13)
			sp[r] = UIK.spin(h, 0, 9, 1 if r != "FUEL" else 0, 64)
		UIK.button(h, "Launch cargo", func():
			var ld := {}
			for r in sp:
				if sp[r].value > 0: ld[r] = int(sp[r].value)
			Game.act(E.shipCargo(G, G.bases[bp.selected].id, ld)))

func _turn_combat(box, G) -> void:
	var opts := E.combatOptions(G)
	if not opts.size(): UIK.para(box, "No attacks are possible this turn.", UIK.DIM)
	for o in opts: UIK.button(box, o.label, func(): Game.act(E.combatAct(G, o)))

func _turn_explore(box, G) -> void:
	var ready: Array = G.ships.filter(func(s): return E.exploreOptions(G, s).size() > 0)
	UIK.head(box, "Ships that can explore (%d)" % ready.size())
	for s in ready:
		var c := UIK.card(box)
		_ship_row(c, G, s, E.locName(s.loc))
		var f := UIK.flow(c)
		for o in E.exploreOptions(G, s): _explore_btn(f, G, s, o)
		if s.kind == "Flyby" and E.P(s.loc).t == "fly": UIK.button(f, "Skip, transfer outward", func(): Game.act(E.flybySkip(G, s)))

func _explore_btn(box, G, s, o) -> void:
	var lbl: String
	match o.kind:
		"explore": lbl = "Explore %s (value %d)" % [D.W[o.w].n, o.value]
		"probe": lbl = "Drop probe on %s (value %d)" % [D.W[o.w].n, o.value]
		"produce": lbl = "Produce %s at %s (value %d)" % [o.res, D.W[o.w].n, o.value]
		"harvest": lbl = "Harvest the asteroid"
		_: lbl = o.kind
	UIK.button(box, lbl, func(): Game.act(E.explore(G, s, o)))

func _turn_trade(box, G) -> void:
	var founders: Array = G.ships.filter(func(s): return E.canFoundBase(G, s) != null)
	for s in founders:
		var c = E.canFoundBase(G, s)
		var h := _ship_row(box, G, s, "Can found a base at %s for %d SUP (carries %d)." % [D.W[c.w].n, c.cost, s.cargo.SUP])
		UIK.button(h, "Found base", func(): Game.act(E.foundBase(G, s)), s.cargo.SUP < c.cost)
	for b in G.bases: _base_card(box, G, b)
	var npfs: Array = G.w.keys().filter(func(k): return SHRules.t(G.w[k].npf))
	for k in npfs:
		var info = E.npfTradeInfo(G, k)
		if info == null or info.why != null: continue
		UIK.button(box, "Trade at %s (%s %s, up to %d)" % [info.name, info.tm.side, info.tm.type, info.limit], func(): Game.act(E.trade(G, {"w": k}, info.limit)))

func _base_card(box, G, b) -> void:
	var c := UIK.card(box)
	UIK.rich(c, "[b]%s[/b] · %s · %d settlement%s\nStock %s" % [b.name, D.W[b.w].n, b.set, "" if b.set == 1 else "s", UIK.res_bb(b.stock)], 13)
	if G.phase == "trade":
		var f := UIK.flow(c)
		for o in E.upgradeOptions(G, b):
			if o.next == null: continue
			UIK.button(f, "%s (%s)" % [o.next.n, E.resTxt(o.next.c)], func(): Game.act(E.buildFacility(G, b, o.c)), o.why != null, String(o.why) if o.why != null else "")
		UIK.button(f, "Add settlement (%s)" % E.resTxt(D.SETTLE_COST), func(): Game.act(E.buildSettlement(G, b)))
		if SHRules.t(b.get("trade")):
			UIK.button(f, "Trade: %s %s (up to %d)" % [b.trade.side, b.trade.type, E.tradeLimitOwn(b)], func(): Game.act(E.trade(G, {"base": b.id}, E.tradeLimitOwn(b))), not E.tradeLimitOwn(b))
		if E.has(G, "terra") and D.TERRA.has(b.w): UIK.button(f, "Terraform", func(): Game.act(E.terraform(G, b)))
		for k in ["lab", "mine", "sup", "def"]:
			if SHRules.t(b.dmg[k]): UIK.button(f, "Repair " + k, func(): Game.act(E.repairFacility(G, b, k)))

# ---------------- Selected tab ----------------
func build_selected() -> void:
	var G = Game.G
	var box := sel_box
	UIK.clear(box)
	var s = Game.sel
	if s == null:
		UIK.para(box, "Click a ship, base or world on the map.", UIK.DIM)
		return
	match s.t:
		"ship":
			var ship = E._shipById(G, s.id)
			if ship != null: _sel_ship_panel(box, G, ship)
		"base":
			var b = E._baseById(G, s.id)
			if b != null: _sel_base_panel(box, G, b)
		"world", "npf": _sel_world_panel(box, G, s.k)
		"oship":
			var g = G.world.facs.get(s.f) if G.world != null else null
			var ship = E._shipById(g, s.id) if g != null else null
			if ship != null:
				UIK.title(box, ship.name)
				UIK.para(box, "%s · %s · %s" % [D.FAC[s.f].n, ("CV-%d" % ship.sz) if ship.cls == "CV" else ship.kind, E.locName(ship.loc)], UIK.DIM)
				UIK.para(box, "Relations: " + D.REL[G.rel[s.f]])

func _sel_ship_panel(box, G, s) -> void:
	var h := UIK.hbox(box, 12)
	UIK.image(h, UIK.atlas_tex("atlas_" + G.f, s.img + "|back" if SHRules.t(s.res) else s.img), 84)
	var v := UIK.vbox(h)
	UIK.title(v, s.name)
	UIK.para(v, "%s · %s" % [("Crew vehicle CV-%d" % s.sz) if s.cls == "CV" else s.kind, E.locName(s.loc)], UIK.DIM)
	var facts := []
	if s.cls == "CV":
		facts.append("search %d" % s.ev)
		if SHRules.t(s.cap): facts.append("cargo %d" % (s.cap * E.cargoMul(G)))
		if SHRules.t(s.cb): facts.append("combat %d" % s.cb)
	else:
		facts.append("search %d" % s.ev)
		if SHRules.t(s.spec): facts.append("spectrometer")
	if SHRules.t(s.res): facts.append("reserved")
	if SHRules.t(s.dmg): facts.append("%d damage" % s.dmg)
	if SHRules.t(s.hold): facts.append("+%d turns beyond box 6" % s.hold)
	if SHRules.t(s.probe): facts.append("probe " + s.probe)
	UIK.para(v, " · ".join(facts), null, 13)
	if E.sum(s.cargo): UIK.rich(box, "Cargo: " + UIK.res_bb(s.cargo), 13)
	# movement
	if G.phase == "move":
		var mv := E.moves(G, s)
		if mv.size():
			UIK.head(box, "Move to")
			var lvs := []
			for m in mv:
				if m.get("lv") != null and not lvs.any(func(x): return x.n == m.lv.n): lvs.append(m.lv)
			var lvpick: OptionButton = null
			if lvs.size() > 1:
				var hh := UIK.hbox(box)
				UIK.para(hh, "Launch vehicle", UIK.DIM)
				lvpick = UIK.pick(hh, lvs.map(func(x): return ("LV-%d (in stock)" % x.n) if SHRules.t(x.get("stock")) else ("LV-%d (buy: %s)" % [x.n, x.txt])))
			var cargo_spin: SpinBox = null
			if s.cls == "CV" and s.loc == "earth" and SHRules.t(s.cap):
				var hh := UIK.hbox(box)
				UIK.para(hh, "Load SUP at launch", UIK.DIM)
				cargo_spin = UIK.spin(hh, 0, s.cap * E.cargoMul(G) - E.sum(s.cargo), 0)
			var by_sys := {}
			for m in mv:
				var sy = E.sysOf(m.dest)
				if not by_sys.has(sy): by_sys[sy] = []
				if not by_sys[sy].any(func(x): return x.dest == m.dest): by_sys[sy].append(m)
			for sy in D.SYS_ORDER:
				if not by_sys.has(sy): continue
				UIK.para(box, D.SYS[sy].n, UIK.CYAN, 12)
				var f := UIK.flow(box)
				for m in by_sys[sy]:
					var lbl: String = m.label + ((" · %d turns" % m.eta) if SHRules.t(m.get("eta")) else "")
					UIK.button(f, lbl, func():
						var extra := {}
						if lvpick != null: extra.lvSize = lvs[lvpick.selected].n
						if cargo_spin != null and cargo_spin.value > 0: extra.load = {"SUP": int(cargo_spin.value)}
						do_move(s, m.dest, extra))
		elif s.loc == "earth": UIK.para(box, "No launch is possible now (it needs a launch vehicle, or it has moved this turn).", UIK.DIM)
	if G.phase == "explore":
		var ex := E.exploreOptions(G, s)
		if ex.size():
			UIK.head(box, "Explore")
			var f := UIK.flow(box)
			for o in ex: _explore_btn(f, G, s, o)
	if G.phase == "trade":
		var c = E.canFoundBase(G, s)
		if c != null: UIK.button(box, "Found a base at %s (%d SUP)" % [D.W[c.w].n, c.cost], func(): Game.act(E.foundBase(G, s)))
		var b = E.atOwnBase(G, s)
		if b != null and E.sum(s.cargo): UIK.button(box, "Unload at " + b.name, func(): Game.act(E.unload(G, s, b)))
	if s.loc == "earth" and SHRules.t(s.cap):
		var f := UIK.flow(box)
		UIK.button(f, "Buy 1 SUP into the hold", func(): Game.act(E.buyCargo(G, s, "SUP", 1)))
		if E.sum(s.cargo): UIK.button(f, "Unload onto the faction board", func(): Game.act(E.sellCargo(G, s)))
	var sv = E.scrapValue(G, s)
	if G.phase == "build" and sv != null: UIK.button(box, "Scrap (recover %s)" % E.resTxt(sv.back), func(): Game.act(E.scrap(G, s)))

func _sel_base_panel(box, G, b) -> void:
	UIK.title(box, b.name)
	UIK.para(box, "%s base at %s" % ["Orbital" if E.basePos(b) == "orbit" else "Surface", D.W[b.w].n], UIK.DIM)
	var facs := []
	for c in ["lab", "mine", "sup", "def"]:
		if SHRules.t(b.fac[c]): facs.append("%s %d%s" % [c, b.fac[c], (" (damaged %d)" % b.dmg[c]) if SHRules.t(b.dmg[c]) else ""])
	UIK.para(box, "Facilities: " + (", ".join(facs) if facs.size() else "none"))
	var o = E.baseOutput(G, b)
	UIK.para(box, "Output: " + ((("%d %s" % [o.n, E.FN[o.field] + " points" if o.type == "tech" else o.type])) if o != null else "nothing yet"), UIK.DIM)
	var f := UIK.flow(box)
	for ty in ["tech", "ORE", "SUP", "FUEL"]:
		var bo = E.baseOutput(G, b, ty)
		if bo != null: UIK.button(f, ("Produce %s%s" % [ty, " (selected)" if b.out == ty else ""]), func():
			b.out = ty
			Game.act(null))
	_base_card(box, G, b)

func _sel_world_panel(box, G, k: String) -> void:
	var w: Dictionary = D.W[k]
	var ws: Dictionary = G.w[k]
	UIK.title(box, w.n)
	UIK.para(box, "%s · exploration value %d · %s%% life · %s" % [D.SYS[w.sys].n, ws.v, w.life, E.FN.get(w.f, "")], UIK.DIM)
	if SHRules.t(ws.card): UIK.para(box, "World card: " + ws.card)
	if SHRules.t(ws.life): UIK.para(box, "Existing life found.", UIK.GOOD)
	elif SHRules.t(ws.sol): UIK.para(box, "Signs of life found.", UIK.GOOD)
	for x in E.missionsAt(G, k): UIK.para(box, "%s mission: %s" % [x.kind.capitalize(), E.misTxt(x.id)], UIK.AMBER)
	if SHRules.t(w.base): UIK.para(box, "Base cost %d SUP." % E.baseCost(G, k), UIK.DIM)
	var info = E.npfTradeInfo(G, k)
	if info != null:
		UIK.head(box, "Non-player base")
		UIK.para(box, "%s (%s), relations %s." % [info.name, D.FAC[info.f].n, D.REL[info.rel]])
		if info.tm != null: UIK.para(box, "Trade marker: %s %s, up to %d." % [info.tm.side, info.tm.type, info.limit])
		if info.why != null: UIK.para(box, info.why, UIK.DIM)
		else: UIK.button(box, "Trade", func(): Game.act(E.trade(G, {"w": k}, info.limit)))

# ---------------- Faction tab ----------------
func build_faction() -> void:
	var G = Game.G
	var box := fac_box
	UIK.clear(box)
	var F: Dictionary = D.FAC[G.f]
	UIK.title(box, F.n + ((" · " + F.variants[G.variant].n) if G.variant != null else ""))
	UIK.para(box, F.ab, UIK.DIM, 13)
	var L := E.lims(G)
	UIK.para(box, "Robotic explorers %d/%d · Crew vehicles %d/%d · Bases %d/%d" % [E.nonProbeRE(G), L[0], E.nCV(G), L[1], E.nBase(G), L[2]])
	UIK.rich(box, "Faction board: " + UIK.res_bb(E.estock(G)) + " · LVs: " + _lv_txt(G), 13)
	UIK.head(box, "Missions")
	UIK.para(box, "Yours: " + E.misTxt(G.mis.mine) + " · Common: " + E.misTxt(G.mis.common))
	UIK.para(box, "Kept %d of %d: %s" % [G.mis.kept.size(), E.misCap(G), ", ".join(G.mis.kept.map(func(x): return E.misTxt(x))) if G.mis.kept.size() else "none yet"], UIK.DIM)
	UIK.head(box, "Foreign relations")
	for k in G.rel: UIK.para(box, "%s: %s" % [D.FAC[k].n, D.REL[G.rel[k]]], null, 13)
	UIK.head(box, "Policies")
	var pols := []
	for p in D.POL:
		var lv := E.polLv(G, p.k)
		if lv: pols.append(D.POL_LV[lv - 1] + p.n)
	UIK.para(box, ", ".join(pols) if pols.size() else "none")
	UIK.head(box, "Technologies (%d)" % G.tech.size())
	UIK.para(box, ", ".join(G.tech.keys().map(func(k): return D.TECHK[k].n)), UIK.DIM, 13)
	UIK.para(box, "Crew range %d · recall %d%% · malfunction %d%% · transfers ×%s" % [E.crewRange(G), E.recall(G), E.malfBase(G), SHRules.n(E.mult(G))], UIK.DIM, 13)
	var sc := E.score(G)
	UIK.head(box, "Score now: %s (%s)" % [SHRules.n(sc.total), sc.rating])
	for p in sc.parts: UIK.para(box, "%s: %s" % [p[0], SHRules.n(p[1])], UIK.DIM, 13)

# ---------------- Log tab ----------------
func _log_col(c):
	match c:
		"g": return UIK.GOOD
		"x": return UIK.BAD
		"h": return UIK.AMBER
		"e": return UIK.CYAN
		"bot": return Color("#b39ddb")
	return null
func build_log() -> void:
	var G = Game.G
	var lines := []
	for l in G.log.slice(0, 160):
		var col = _log_col(l.c)
		var t: String = String(l.t).replace("[", "[lb]")
		lines.append(("[color=#%s]%s[/color]" % [col.to_html(false), t]) if col != null else t)
	log_text.text = "\n".join(lines)

# ---------------- questions (G.ask) ----------------
func build_dialog() -> void:
	var G = Game.G
	UIK.clear(dialog_box)
	if G == null or not G.ask.size():
		dialog.visible = false
		return
	dialog.visible = true
	var a: Dictionary = G.ask[0]
	UIK.title(dialog_box, _ask_title(a))
	UIK.para(dialog_box, a.get("text", ""))
	var f := UIK.flow(dialog_box)
	match a.k:
		"pirate":
			var s = E._shipById(G, a.ship)
			UIK.button(f, "Pay $%dB" % a.roll, func(): Game.answer("pay"))
			UIK.button(f, "Drive it off: $%dB" % (a.roll * 2), func(): Game.answer("remove"))
			if s != null and s.cb > s.dmg: UIK.button(f, "Fight", func(): Game.answer("fight"))
			UIK.button(f, "Surrender (cargo lost, reserved)", func(): Game.answer("surrender"))
			UIK.button(f, "Stay put", func(): Game.answer("stay"))
		"intercept":
			UIK.button(f, "Stop moving", func(): Game.answer("stop"))
			UIK.button(f, "Fight", func(): Game.answer("fight"))
			UIK.button(f, "Surrender", func(): Game.answer("surrender"))
		"surrender":
			UIK.button(f, "Accept", func(): Game.answer("accept"))
			if SHRules.t(a.canDeny): UIK.button(f, "Refuse and fight", func(): Game.answer("deny"))
			if SHRules.t(a.split): UIK.button(f, "Fight the ships first", func(): Game.answer("exclude"))
		"search":
			UIK.para(dialog_box, "Search rolls: " + ", ".join(a.rolls.map(func(r): return "%s %d" % [r.n, r.r])) + " (%d or less finds)." % a.T, UIK.DIM)
			UIK.button(f, "OK", func(): Game.answer("ok"))
		"pbattle":
			UIK.para(dialog_box, "Your total %d, the pirate's %d. Tactics points %d to %d (%d to spend). Strike: you deal %d, take %d. Direct fire: you deal %d, take %d." % [a.myTot, a.pTot, a.myTP, a.pTP, a.extra, a.strike.deal, a.strike.take, a.direct.deal, a.direct.take], UIK.DIM)
			UIK.button(f, "Fight (best use of tactics)", func(): Game.answer("auto"))
			UIK.button(f, "Strike", func(): Game.answer("plan", {"mode": "strike", "inc": floori(a.extra / 2.0)}))
			if a.extra >= 1: UIK.button(f, "Direct fire", func(): Game.answer("plan", {"mode": "direct", "inc": floori((a.extra - 1) / 2.0)}))
			if a.extra >= 3: UIK.button(f, "Call it off (3 points)", func(): Game.answer("avoid"))
		"assign", "basehit": UIK.button(f, "Assign automatically", func(): Game.answer("auto"))
		"battle":
			UIK.para(dialog_box, "Tactics points %d to %d. Strike: you deal %d, take %d. Direct fire: you deal %d, take %d." % [a.tp, a.opp, a.strike.dealt, a.strike.taken, a.direct.dealt, a.direct.taken], UIK.DIM)
			UIK.button(f, "Fight (automatic plan)", func(): Game.answer("auto"))
			if a.rem > 0 and not a.lose:
				UIK.button(f, "Strike", func(): Game.answer("strike"))
				UIK.button(f, "Direct fire", func(): Game.answer("direct"))
				if a.rem >= 3: UIK.button(f, "Call it off", func(): Game.answer("avoid"))
		"card":
			for o in a.opts: UIK.button(f, "Place " + o, func(): Game.answer(o))
			UIK.button(f, "Return to the deck", func(): Game.answer(null))
		"flyby":
			for o in a.opts: UIK.button(f, "%s (%d turns)" % [D.SYS[o.sys].n, o.eta], func(): Game.answer(o.sys))
		"publicity":
			var ks: Array = G.w.keys().filter(func(k): return G.w[k].v > 0)
			ks = SHRules.ssort(ks, func(x, y): return -1 if D.W[x].n < D.W[y].n else 1)
			for k in ks: UIK.button(f, "%s (%d)" % [D.W[k].n, G.w[k].v], func(): Game.answer(k))
		"immigration":
			for b in G.bases: UIK.button(f, b.name, func(): Game.answer(b.id))
		"mission":
			for id in a.opts: UIK.button(f, "Give up " + E.misTxt(id), func(): Game.answer(id))
		_:
			UIK.button(f, "OK", func(): Game.answer("ok"))

func _ask_title(a: Dictionary) -> String:
	match a.k:
		"pirate": return "Pirate!"
		"intercept": return "Interception"
		"surrender": return "Surrender offered"
		"search": return "Search"
		"pbattle", "battle": return "Combat"
		"assign": return "Assign the damage"
		"basehit": return "Base hit"
		"card": return "World card"
		"flyby": return "Flyby transfer"
		"publicity": return "Publicity Campaign"
		"immigration": return "Immigration"
		"mission": return "Too many missions"
	return "Decision"

# ---------------- menus ----------------
func show_menu(mode: String) -> void:
	menu.visible = true
	UIK.clear(menu_box)
	UIK.title(menu_box, "Stellar Horizons", 34)
	if mode == "pause":
		UIK.para(menu_box, "Campaign paused.", UIK.DIM)
		var f := UIK.flow(menu_box)
		UIK.button(f, "Resume", func(): menu.visible = false)
		UIK.button(f, "Save", func():
			show_toast("Campaign saved." if Game.save_game() else "Could not save.")
			menu.visible = false)
		UIK.button(f, "Load", func(): _load(), not Game.has_save())
		UIK.button(f, "New campaign", func(): show_menu("start"))
		UIK.button(f, "Quit", func(): get_tree().quit())
		return
	UIK.para(menu_box, "Lead a space program from 2030: explore the solar system, found bases and grow settlements.", UIK.DIM)
	UIK.head(menu_box, "Your faction")
	var f := UIK.flow(menu_box)
	for k in D.FAC_ORDER:
		var b := UIK.button(f, D.FAC[k].n, func():
			_setup.f = k
			show_menu("start"))
		b.add_theme_color_override("font_color", Color(D.FAC[k].c).lightened(0.25))
		if _setup.f == k: b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover"))
	UIK.para(menu_box, D.FAC[_setup.f].ab, UIK.DIM, 13)
	var opts := UIK.flow(menu_box)
	var bots := CheckButton.new()
	bots.text = "Other factions played by bots"
	bots.button_pressed = _setup.bots
	bots.toggled.connect(func(on): _setup.bots = on)
	opts.add_child(bots)
	var scen := UIK.pick(opts, ["Standard campaign (2030)", "Futuristic start (2060)"], 1 if _setup.scenario == "fut2060" else 0)
	scen.item_selected.connect(func(i): _setup.scenario = "fut2060" if i == 1 else "std")
	if _setup.f == "cn":
		var vr := UIK.pick(opts, ["Military policy", "Robotic policy"], 1 if _setup.variant == "rob" else 0)
		vr.item_selected.connect(func(i): _setup.variant = "rob" if i == 1 else "mil")
	var scrap := CheckButton.new()
	scrap.text = "Optional: scrap explorers and LVs"
	scrap.button_pressed = _setup.scrapRE
	scrap.toggled.connect(func(on): _setup.scrapRE = on)
	opts.add_child(scrap)
	var go := UIK.flow(menu_box)
	var start := UIK.button(go, "Start campaign", func(): _start())
	start.custom_minimum_size = Vector2(220, 44)
	if Game.has_save(): UIK.button(go, "Continue saved campaign", func(): _load())
	if Game.G != null: UIK.button(go, "Back", func(): menu.visible = false)
	UIK.button(go, "Quit", func(): get_tree().quit())

func _load() -> void:
	if not Game.load_game(): show_toast("Could not load the saved campaign.")

func _start() -> void:
	var opts := {"scenario": _setup.scenario, "variant": _setup.variant, "scrapRE": _setup.scrapRE, "enhTrade": _setup.enhTrade}
	var bots := []
	if _setup.bots:
		for k in D.FAC_ORDER:
			if k != _setup.f: bots.append({"f": k})
	Game.new_campaign(_setup.f, opts, bots)
