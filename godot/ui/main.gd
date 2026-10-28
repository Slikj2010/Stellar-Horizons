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
@onready var fboard: Control = $HUD/Root/FactionBoard
@onready var ttree: Control = $HUD/Root/TechTree
@onready var tech_box: VBoxContainer = $HUD/Root/Side/VBox/Tabs/Tech/Box
@onready var pol_box: VBoxContainer = $HUD/Root/Side/VBox/Tabs/Policy/Box

const TAB_TURN := 0
const TAB_SEL := 1
const TAB_FAC := 2
const TAB_TECH := 3
const TAB_POL := 4
const TAB_LOG := 5
var modal: ColorRect
var modal_box: VBoxContainer
var _modal_enter := Callable()  ## what Enter does while the modal is open
var v25: Node3D  ## the 2.5D view (v25/v25.gd, a port of the web version's view25.js)
var _v25c: Control  ## its turn and tilt buttons
var sfx: Node  ## sound effects and music (audio.gd)
var bg: CanvasLayer  ## the flat map's starfield
var _btn3d: Button

const PHASE_HELP := {
	"econ": "Once a decade: politics and events, diplomacy, production, resource transport, bases, asteroids and pirates, technologies, settlement growth and policy.",
	"build": "Build robotic explorers, crew vehicles and launch vehicles; unreserve and repair crew vehicles.",
	"move": "Select a ship (outlined in blue) and pick a destination on the map or in the Selected tab. Ships waiting on Earth are on the faction board (Faction tab): drag one onto the launch pad to launch it. Launches need a launch vehicle and an engine roll.",
	"combat": "Attack pirates, blockade or raid bases of factions you are at embargo or war with.",
	"explore": "Select a ship that can explore (outlined in blue) and choose what to explore.",
	"trade": "Found bases with crew vehicles carrying supplies, build facilities and settlements, trade.",
}

var E: SHRules
var D: Dictionary
var _press := Vector2.ZERO
var _dragging := false
var _drag_btn := 0
var _toast_t := 0.0
var _log_seen := 0
var _setup := {"f": "eu", "bots": false, "botset": [], "cnbot": "mil", "scenario": "std", "variant": "mil"}

func _ready() -> void:
	E = Game.E
	D = Game.data.D
	cam.setup(board.map_rect())
	Game.changed.connect(refresh)
	Game.toast.connect(show_toast)
	Game.rolled.connect(show_roll)
	Game.campaign_started.connect(_on_started)
	next_btn.pressed.connect(func(): next_click())
	$HUD/Root/TopBar/Row/MenuBtn.pressed.connect(func(): show_menu("pause" if Game.G != null else "title"))
	tabs.set_tab_title(0, "Turn")
	tabs.set_tab_title(1, "Selected")
	tabs.set_tab_title(2, "Faction")
	tabs.set_tab_title(TAB_TECH, "Tech")
	tabs.set_tab_title(TAB_POL, "Policy")
	tabs.set_tab_title(TAB_LOG, "Log")
	Game.board_node = board
	fboard.main = self
	ttree.main = self
	tabs.tab_changed.connect(func(_i): _sync_fboard())
	_make_modal()
	_make_log_filter()
	_make_tip()
	bg = CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	var stars = preload("res://ui/starfield.gd").new()
	stars.cam = cam
	bg.add_child(stars)
	sfx = preload("res://ui/audio.gd").new()
	add_child(sfx)
	v25 = preload("res://ui/v25/v25.gd").new()
	add_child(v25)
	v25.setup(self)
	_make_v25_controls()
	title = TitleScene.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	root.move_child(title, menu.get_index())
	title.action.connect(_title_action)
	dev = DevConsole.new()
	dev.set_anchors_preset(Control.PRESET_CENTER)
	dev.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dev.grow_vertical = Control.GROW_DIRECTION_BOTH
	dev.z_index = 60
	root.add_child(dev)
	show_menu("title")
	refresh()
	loading = LoadingScreen.new()
	add_child(loading)
	_startup_load.call_deferred()

var loading: LoadingScreen
var warm_enabled := true  ## the screenshot tests turn this off

## start-up: pull in every image the game uses and build the 2.5D scene now, behind a loading screen
func _startup_load() -> void:
	if not warm_enabled: return
	var t0 := Time.get_ticks_msec()
	loading.begin("Loading the solar system…")
	await get_tree().process_frame
	var paths: Array = []
	for dir in ["res://assets/", "res://assets/v25/", "res://assets/maps/", "res://assets/menu/"]:
		for fn in DirAccess.get_files_at(dir):
			if fn.ends_with(".png") or fn.ends_with(".webp") or fn.ends_with(".import"): 
				var pth: String = dir + fn.trim_suffix(".import")
				if not pth in paths and not pth.ends_with(".import"): paths.append(pth)
	for i in paths.size():
		if i % 4 == 0:
			loading.step(0.5 * i / maxf(1, paths.size()), "Loading art… %d / %d" % [i, paths.size()])
			await get_tree().process_frame
		ResourceLoader.load(paths[i])
	if OS.get_cmdline_user_args().has("--timing"): print("TIMING art ", Time.get_ticks_msec() - t0)
	loading.step(0.55, "Building the 2.5D scene…")
	await get_tree().process_frame
	board.set_layout(false)  # the 2.5D scene is built on the printed sheet's geometry, not the flat winding layout
	v25.ensure()
	if OS.get_cmdline_user_args().has("--timing"): print("TIMING ensure ", Time.get_ticks_msec() - t0)
	loading.step(0.75, "Building models…")
	await get_tree().process_frame
	if v25.MODELS.is_empty(): v25._build_models()
	board.set_layout(true)
	if OS.get_cmdline_user_args().has("--timing"): print("TIMING total ", Time.get_ticks_msec() - t0)
	loading.step(1.0, "Ready")
	await get_tree().process_frame
	loading.done()

## when a campaign starts, run the 2.5D view once (hidden behind the loading screen) so its meshes, shaders and caches
## are ready and the first switch to it does not freeze
func _warm_v25() -> void:
	if not warm_enabled or v25.on or Game.G == null: return
	loading.begin("Preparing the board…")
	await get_tree().process_frame
	toggle_3d()
	var spots := ["", "ear", "jup", "sat", "alp", "dsa", "sca", "sun"]
	for i in spots.size():
		loading.step(float(i) / spots.size(), "Preparing the 2.5D view…")
		if spots[i] == "": v25.fit()
		else: v25.focusPod(spots[i])
		await get_tree().process_frame
		await get_tree().process_frame
	toggle_3d()
	await get_tree().process_frame
	loading.done()

func _process(dt: float) -> void:
	if _toast_t > 0:
		_toast_t -= dt
		if _toast_t <= 0: toast_panel.visible = false

func _on_started() -> void:
	_warm_v25()
	menu.visible = false
	title.visible = false
	fboard.visible = false
	_log_seen = 0
	tabs.current_tab = 0
	var ep: Vector2 = board.world_center("ear")
	fly(ep, 0.32)

# ---------------- input on the board ----------------
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var kk: int = (ev as InputEventKey).keycode
		if modal.visible:
			if kk == KEY_ESCAPE: modal.visible = false
			elif (kk == KEY_ENTER or kk == KEY_KP_ENTER) and _modal_enter.is_valid(): _modal_enter.call()
			get_viewport().set_input_as_handled()
			return
		if kk == KEY_QUOTELEFT and Game.G != null:
			if dev.visible: dev.close()
			else:
				menu.visible = false
				dev.open()
			get_viewport().set_input_as_handled()
			return
		if kk == KEY_ESCAPE:
			if menu.visible:
				if Game.G != null: _close_menu()
			elif Game.sel != null: Game.select(null)
			else: show_menu("pause" if Game.G != null else "title")
			get_viewport().set_input_as_handled()
			return
	if menu.visible: return
	if v25.on and (ev is InputEventMouseButton or ev is InputEventMouseMotion or ev is InputEventMagnifyGesture or ev is InputEventPanGesture):
		_input25(ev)
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: _camc().zoom_at(1.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: _camc().zoom_at(1 / 1.12, mb.position)
		elif mb.pressed:
			_press = mb.position
			_dragging = true
			_drag_btn = mb.button_index
			_drag_ship = null
			_tip.visible = false
			# pressing on one of your ships that can move starts dragging it (instead of panning the map)
			if mb.button_index == MOUSE_BUTTON_LEFT and Game.G != null and Game.G.phase == "move" and not Game.G.ask.size():
				var h: Dictionary = board.pick_at(_world(mb.position))
				if h.get("t") == "ship":
					var s = E._shipById(Game.G, h.id)
					if s != null and E.moves(Game.G, s).size(): _drag_ship = s
		elif _dragging and mb.button_index == _drag_btn:
			_dragging = false
			var wp: Vector2 = _world(mb.position)
			if board.ghost != null:
				var dest: String = board.dest_at(wp)
				var s = _drag_ship
				board.ghost = null
				_drag_ship = null
				board.queue_redraw()
				if dest != "" and s != null: do_move(s, dest, {}, wp)
				elif s != null: show_toast("Drop the counter on a highlighted destination to move it.")
				return
			_drag_ship = null
			if mb.position.distance_to(_press) < 6:
				if mb.button_index == MOUSE_BUTTON_LEFT: _click(wp)
				elif mb.button_index == MOUSE_BUTTON_RIGHT: _zoom_counter(board.pick_at(wp))
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _dragging and _drag_ship != null and _drag_btn == MOUSE_BUTTON_LEFT:
			if board.ghost == null and mm.position.distance_to(_press) >= 6:
				if Game.sel == null or Game.sel.t != "ship" or not SHRules.eq(Game.sel.get("id"), _drag_ship.id): Game.select({"t": "ship", "id": _drag_ship.id})
				board.ghost = {"f": Game.G.f, "img": _drag_ship.img, "id": _drag_ship.id}
			if board.ghost != null:
				var wp: Vector2 = _world(mm.position)
				board.ghost.p = wp
				board.ghost.dest = board.dest_at(wp)
				board.queue_redraw()
		elif _dragging:
			_camc().pan_screen(mm.relative)
		else:
			_hover(mm.position)
	elif ev is InputEventMagnifyGesture:
		_camc().zoom_at((ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)
	elif ev is InputEventPanGesture:
		_camc().pan_screen(-(ev as InputEventPanGesture).delta * 20)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = (ev as InputEventKey).keycode
		if JUMP.has(k): _jump_key(k)
		elif k == KEY_V: toggle_3d()
		elif k == KEY_ENTER or k == KEY_KP_ENTER: next_click()

## a screen point on the map, in board coordinates
func _world(sp: Vector2) -> Vector2: return board.get_canvas_transform().affine_inverse() * sp

## the camera the mouse drives on the flat map
func _camc(): return cam

## glide to a board point, zooming in to at least z (flat map zoom)
func fly(p: Vector2, z := -1.0) -> void:
	if v25.on: v25.focus(p, z if z > 0 else 0.0)
	else: cam.fly_to(p, maxf(cam.zoom.x, z) if z > 0 else -1.0)

## the part of the window the map shows in: below the top bar, left of the side panel
func stage_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var side: Control = $HUD/Root/Side
	var top := 62.0
	return Rect2(0, top, maxf(100, side.get_global_rect().position.x - 8), vs.y - top)

## the 2.5D view on or off (toggle25 in the web version)
func toggle_3d() -> void:
	var want: bool = not v25.on
	board.set_layout(not want)
	v25.enable(want)
	board.visible = not want
	bg.visible = not want
	_v25c.visible = want
	_btn3d.add_theme_color_override("font_color", UIK.CYAN if want else Color(0.85, 0.9, 0.95))
	if want: v25.home(board.pos_of("earth") if Game.G != null else Vector2(2500, 450))
	else: board.queue_redraw()
	_tip.visible = false

# ---------------- 2.5D input (setupInput25 in the web version) ----------------
var _g25 = null
func _input25(ev: InputEvent) -> void:
	if ev is InputEventMagnifyGesture:
		v25.zoom((ev as InputEventMagnifyGesture).factor)
		return
	if ev is InputEventPanGesture:
		v25.zoom(1.15 if (ev as InputEventPanGesture).delta.y < 0 else 1 / 1.15)
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		var q := mb.position
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			v25.zoom(1.15)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			v25.zoom(1 / 1.15)
			return
		if mb.pressed:
			_tip.visible = false
			var r: Dictionary = v25.pick(q.x, q.y)
			_g25 = {"k": "press", "x": q.x, "y": q.y, "lx": q.x, "ly": q.y, "hit": r.hit, "p0": v25.ground(q.x, q.y, 0), "moved": false,
				"rot": mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.shift_pressed, "btn": mb.button_index}
			return
		var gg = _g25
		if gg == null or mb.button_index != gg.btn: return
		_g25 = null
		if gg.k == "press" and not gg.moved:
			if gg.btn == MOUSE_BUTTON_RIGHT: _zoom_counter(gg.hit if gg.hit != null else {})
			else: _tap(gg.hit)
		if gg.k == "drag":
			var p = board.ghost.get("p") if board.ghost != null else null
			var s = _drag_ship
			var moves: Array = E.moves(Game.G, s) if s != null else []
			board.ghost = null
			_drag_ship = null
			v25.touch()
			if s == null: return
			# a counter dropped on one of the 3D box shapes goes to that box; anything else is judged on the flat map's zones
			var dests := []
			for m in moves:
				if not dests.has(m.dest): dests.append(m.dest)
			var box = v25.destAt(q.x, q.y, dests)
			if box != null: do_move(s, box, {}, p)
			elif p != null:
				var d: String = board.dest_at(p)
				if d != "": do_move(s, d, {}, p)
		return
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		var q := mm.position
		if _g25 == null:
			var r: Dictionary = v25.pick(q.x, q.y)
			var txt := _tip_text(Game.G, r.hit) if (Game.G != null and r.hit != null and not modal.visible and not fboard.visible and not ttree.visible) else ""
			_show_tip(txt, q)
			return
		var g: Dictionary = _g25
		if g.k == "press" and Vector2(q.x - g.x, q.y - g.y).length() > 6:
			g.moved = true
			var h = g.hit
			if g.rot: g.k = "rot"
			elif h != null and h.t == "ship" and Game.G.phase == "move" and not Game.G.ask.size():
				var s = E._shipById(Game.G, h.id)
				var m: Array = E.moves(Game.G, s) if s != null else []
				if m.size():
					g.k = "drag"
					_drag_ship = s
					Game.select({"t": "ship", "id": s.id})
					board.ghost = {"f": Game.G.f, "img": s.img, "id": s.id}
					v25.touch()
				else: g.k = "pan"
			else: g.k = "pan"
		if g.k == "rot":
			v25.rotate_by(-(q.x - g.lx) * .006, (q.y - g.ly) * .005)
			g.lx = q.x
			g.ly = q.y
		elif g.k == "pan": v25.panBy(g.p0, q.x, q.y)
		elif g.k == "drag":
			var p = v25.sheetAt(q.x, q.y)
			if p != null and board.ghost != null:
				board.ghost.p = p
				v25.touch()

## the map's controls (bottom left of the stage) and the phase hint (top left), as in the web version:
## zoom in and out, the whole map, your ships, the 2.5D switch, and in 2.5D the turn and tilt buttons
var _hint: Label
func _make_v25_controls() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.anchor_top = 1.0
	h.anchor_bottom = 1.0
	h.offset_top = -56
	h.offset_bottom = -16
	h.offset_left = 16
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := func(t: String, fn: Callable, tip: String) -> Button:
		var bt := UIK.button(h, t, fn, false, tip)
		bt.custom_minimum_size = Vector2(40, 36)
		return bt
	add.call("+", func(): _zoom_btn(1.3), "Zoom in")
	add.call("−", func(): _zoom_btn(1 / 1.3), "Zoom out")
	add.call("Whole map", func(): _fit_btn(), "Show the whole map")
	add.call("My ships", func(): _me_btn(), "Go to the selected ship, or your first ship in space")
	_btn3d = add.call("2.5D", func(): toggle_3d(), "Switch between the flat map and the 2.5D space view (V)")
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", 6)
	for b in [["⟲", func(): v25.rotate_by(-.3, 0), "Rotate left"], ["⟳", func(): v25.rotate_by(.3, 0), "Rotate right"], ["⤒", func(): v25.rotate_by(0, .12), "Tilt up"], ["⤓", func(): v25.rotate_by(0, -.12), "Tilt down"]]:
		var bt := UIK.button(c, b[0], b[1], false, b[2])
		bt.custom_minimum_size = Vector2(40, 36)
	c.visible = false
	h.add_child(c)
	root.add_child(h)
	root.move_child(h, 0)
	_v25c = c
	_hint = Label.new()
	_hint.position = Vector2(16, 62 + 12)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", UIK.DIM)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	root.move_child(_hint, 0)

func _zoom_btn(f: float) -> void:
	if v25.on: v25.zoom(f)
	else:
		var st := stage_rect()
		cam.zoom_at(f, st.get_center())

func _fit_btn() -> void:
	if v25.on: v25.fit()
	else: cam.setup(board.map_rect())

func _me_btn() -> void:
	var G = Game.G
	if G == null: return
	var s = _sel_ship()
	if s == null or s.loc == "earth": s = SHRules._find(G.ships, func(x): return x.loc != "earth")
	fly(board.pos_of(s.loc) if s != null else board.world_center("ear"), .9)

const HINTS := {"econ": "Economic phase. Work through each step in the Turn tab.", "build": "Build ships and launch vehicles, unreserve and repair crew vehicles, or load cargo on Earth.",
	"move": "Drag a counter onto a highlighted box to move it. Tap a counter to see its options.", "combat": "Attack pirates or blockade and raid NPF bases where your armed crew vehicles are.",
	"explore": "Tap a ship with a blue ring to explore. Each ship explores once per turn.", "trade": "Found bases, build facilities and settlements, trade and terraform."}

# ---------------- camera hotkeys: belts cycle through their satellites on repeated presses ----------------
const JUMP := {KEY_1: ["mer"], KEY_2: ["ven"], KEY_SPACE: ["ear"], KEY_3: ["mar"], KEY_4: ["bel", "cer", "ves", "hyg"], KEY_5: ["jup"], KEY_6: ["sat"],
	KEY_7: ["ura"], KEY_8: ["nep"], KEY_9: ["kui", "plu", "hau"], KEY_0: ["sca", "eri", "sed"], KEY_A: ["alp"]}
var _jump_last := -1
var _jump_i := 0
func _jump_key(key: int) -> void:
	var list: Array = JUMP[key]
	_jump_i = (_jump_i + 1) % list.size() if _jump_last == key else 0
	_jump_last = key
	var k: String = list[_jump_i]
	if v25.on:
		v25.focusPod(k)
		return
	if D.SYS.has(k): _jump(k)
	elif board.geo.worlds.has(k): fly(board.world_center(k), 0.6)

# ---------------- hover tips and the counter zoom ----------------
var _drag_ship = null
var _tip: PanelContainer
var _tip_lbl: RichTextLabel
func _make_tip() -> void:
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 50
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.11, 0.96)
	sb.border_color = Color(0.25, 0.36, 0.48)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	_tip.add_theme_stylebox_override("panel", sb)
	_tip_lbl = RichTextLabel.new()
	_tip_lbl.bbcode_enabled = true
	_tip_lbl.fit_content = true
	_tip_lbl.scroll_active = false
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_lbl.add_theme_font_size_override("normal_font_size", 13)
	_tip_lbl.add_theme_font_size_override("bold_font_size", 13)
	_tip.add_child(_tip_lbl)
	root.add_child(_tip)

func _hover(sp: Vector2) -> void:
	var G = Game.G
	var txt := ""
	if G != null and not modal.visible and not fboard.visible and not ttree.visible:
		txt = _tip_text(G, board.pick_at(_world(sp)))
	_show_tip(txt, sp)

func _show_tip(txt: String, sp: Vector2) -> void:
	if txt == "":
		_tip.visible = false
		return
	_tip_lbl.text = txt
	_tip.visible = true
	_tip.reset_size()
	var vs := get_viewport().get_visible_rect().size
	var p := sp + Vector2(18, 18)
	var sz := _tip.get_combined_minimum_size()
	if p.x + sz.x > vs.x - 470: p.x = sp.x - sz.x - 12
	if p.y + sz.y > vs.y - 8: p.y = sp.y - sz.y - 12
	_tip.position = p

func _tip_text(G, h: Dictionary) -> String:
	var dim := "[color=#b8896a]%s[/color]"
	match h.get("t"):
		"ship":
			var s = E._shipById(G, h.id)
			if s == null: return ""
			var t := "[b]%s[/b] %s\n%s" % [s.name, dim % s.kind, E.locName(s.loc)]
			var extra := []
			if SHRules.t(s.get("res")): extra.append("reserved")
			if SHRules.t(s.dmg): extra.append("%d damage" % s.dmg)
			if E.sum(s.cargo): extra.append("cargo " + UIK.res_bb(s.cargo))
			if SHRules.t(s.get("probe")): extra.append("carries probe " + s.probe)
			if G.phase == "move" and E.moves(G, s).size(): extra.append("[color=#d9a35a]can move: drag it, or click it[/color]")
			if G.phase == "explore" and E.exploreOptions(G, s).size(): extra.append("[color=#d9a35a]can explore[/color]")
			if extra.size(): t += "\n" + " · ".join(extra)
			return t + "\n" + dim % "Right-click to enlarge"
		"oship":
			for s in G.world.facs[h.f].ships:
				if SHRules.eq(s.id, h.id): return "[b]%s[/b] %s\n%s\n%s" % [s.name, dim % s.kind, D.FAC[h.f].n, dim % "Right-click to enlarge"]
			return ""
		"base":
			var b = E._baseById(G, h.id)
			if b == null: return ""
			var fac := []
			for c in [["lab", "lab"], ["mine", "mine"], ["sup", "supply"], ["def", "defense"]]:
				if SHRules.t(b.fac[c[0]]): fac.append("%s %d" % [c[1], b.fac[c[0]]])
			return "[b]%s[/b] %s\n%s\nStock %s%s" % [b.name, dim % D.W[b.w].n, ", ".join(fac) if fac.size() else "no facilities", UIK.res_bb(b.stock), ("\n%d settlement%s" % [b.set, "s" if b.set > 1 else ""]) if b.set else ""]
		"obase": return "[b]%s[/b] %s\n%s" % [h.name, dim % D.W[h.w].n, D.FAC[h.f].n]
		"npf": return "[b]%s[/b]\n%s" % [str(E.npfName(G, h.k)), dim % "Non-player faction base"]
		"dest":
			for m in board.targets:
				if m.dest == h.dest: return "Move here: [b]%s[/b]%s" % [m.label, (" · %d turns" % m.eta) if SHRules.t(m.get("eta")) else ""]
		"world":
			var k: String = h.k
			if not D.W.has(k): return ""
			var w: Dictionary = D.W[k]
			var ws = G.w.get(k)
			if ws == null: return ""
			var t := "[b]%s[/b]" % w.n
			if k != "alp": t += " [color=#%s]%s[/color]" % [UIK.FIELD_COL.get(w.f, UIK.DIM).to_html(false), SHRules.FN[w.f]]
			t += "\nExploration value [b]%d[/b]%s" % [int(ws.v), (" (printed %d)" % int(w.v)) if int(ws.v) != int(w.v) else ""]
			if SHRules.t(w.get("life")): t += " · life chance %d%%" % int(w.life)
			if SHRules.t(ws.get("card")): t += "\nWorld card: " + str(ws.card)
			if SHRules.t(ws.get("life")): t += "\n[color=#5fcf8a]Life found[/color]"
			for x in E.missionsAt(G, k): t += "\nMission: " + E.misTxt(x.id)
			return t
	return ""

## right-click on a counter: show it large, front and back
func _zoom_counter(h: Dictionary) -> void:
	if not h.has("img") or not h.has("f"): return
	var f: String = h.f
	var key: String = h.img
	UIK.clear(modal_box)
	_modal_enter = func(): modal.visible = false
	var name := ""
	if h.t == "ship":
		var s = E._shipById(Game.G, h.id)
		if s != null: name = "%s (%s)" % [s.name, s.kind]
	elif h.t == "oship": name = D.FAC[f].n + " counter"
	else: name = str(h.get("name", "Base counter"))
	UIK.title(modal_box, name if name != "" else "Counter")
	var row := UIK.hbox(modal_box, 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var sheet := "atlas_" + f
	var base_key: String = key.trim_suffix("|back")
	for k2 in [base_key, base_key + "|back"]:
		var tex = UIK.atlas_tex(sheet, k2)
		if tex == null: continue
		var v := UIK.vbox(row, 4)
		UIK.image(v, tex, 240)
		var l := UIK.para(v, "Back (reserved side)" if k2.ends_with("|back") else "Front", UIK.DIM, 12, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIK.button(UIK.flow(modal_box), "Close", func(): modal.visible = false)
	modal.visible = true

func _jump(sy: String) -> void:
	var hub = D.SYS[sy].hub
	var p: Vector2 = board.world_center(hub) if (hub != null and board.geo.worlds.has(hub)) else board.v2(board.geo.sys[sy].flyby)
	fly(p, 0.38)

func _click(pt: Vector2) -> void:
	if Game.G == null: return
	_tap(board.pick_at(pt))

## select what was tapped (tap in the web version)
func _tap(h) -> void:
	if Game.G == null: return
	if h == null or h.is_empty():
		Game.select(null)
		return
	match h.t:
		"pod":
			if v25.on: v25.focusPod(h.k)
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
		"oship", "obase":
			Game.select({"t": h.t, "f": h.f, "id": h.id})
			tabs.current_tab = 1
		"world":
			if not D.W.has(h.k) or Game.G.w.get(h.k) == null: return
			Game.select({"t": "world", "k": h.k})
			tabs.current_tab = 1

func _sel_ship():
	var s = Game.sel
	if s == null or s.t != "ship": return null
	return E._shipById(Game.G, s.id)

func do_move(s, dest: String, extra := {}, drop_pt = null, ask := true) -> void:
	if ask:
		var G = Game.G
		var mv = null
		for m in E.moves(G, s):
			if m.dest == dest: mv = m
		var body := "%s moves from %s to %s." % [s.name, E.locName(s.loc), E.locName(dest)]
		if mv != null:
			body += "\n" + (("It arrives in %d turn%s." % [int(mv.eta), "" if int(mv.eta) == 1 else "s"]) if SHRules.t(mv.get("eta")) else "It arrives this turn.")
			if mv.get("lv") != null:
				body += "\nLaunch vehicle: LV-%d%s." % [int(extra.get("lvSize", mv.lv.n)), (" (new: %s)" % mv.lv.txt) if SHRules.t(mv.lv.get("buy")) else " from stock"]
		var ld = extra.get("load")
		if ld is Dictionary and E.sum(ld) > 0: body += "\nCargo loaded: " + E.resTxt(ld) + "."
		confirm("Move %s?" % s.name, body, func(): do_move(s, dest, extra, drop_pt, false), "Move")
		return
	var opt := {"probe": SHRules._first(Game.G.probes.get(s.loc, []))}
	for k in extra: opt[k] = extra[k]
	var res = E.move(Game.G, s, dest, opt)
	# a counter dropped on an orbit keeps the spot where it was dropped (as in the web version)
	if s.loc == dest:
		var pp := E.P(dest)
		if pp.t == "orbit" and drop_pt != null:
			var Rr: Dictionary = board.ring_of(pp.w)
			var a := atan2(drop_pt.y - Rr.c.y, drop_pt.x - Rr.c.x)
			var others: Array = Game.G.ships.filter(func(o): return not is_same(o, s) and o.loc == dest)
			s.ang = board.free_angle(a, board.ring_layout(pp.w, others).values(), 2 * asin(minf(1, (board.CS + 8) / 2 / Rr.r)), pp.w)
		elif pp.t != "orbit": s.erase("ang")
	Game.act(res)

# ---------------- refresh ----------------
func refresh() -> void:
	var G = Game.G
	if G == null:
		board.targets = []
		board.queue_redraw()
		return
	year_lbl.text = str(G.y)
	_hint.text = "The campaign is over. See the Turn tab for the final score." if G.over else HINTS.get(G.phase, "")
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
	build_tech_panel()
	build_pol_panel()
	build_log()
	next_btn.disabled = G.over or G.ask.size() > 0
	next_btn.text = "Campaign over" if G.over else ("Answer the question first" if G.ask.size() else _next_label(G))
	build_dialog()
	_sync_fboard()

## the faction board covers the map while the Faction tab is open, the trees while Tech or Policy is open
func _sync_fboard() -> void:
	var on: bool = Game.G != null and not menu.visible
	var show: bool = on and tabs.current_tab == TAB_FAC
	fboard.visible = show
	if show: fboard.refresh()
	var tshow: bool = on and (tabs.current_tab == TAB_TECH or tabs.current_tab == TAB_POL)
	ttree.visible = tshow
	if tshow:
		ttree.mode = "pol" if tabs.current_tab == TAB_POL else "tech"
		ttree.refresh()
	board.queue_redraw()

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
	var nx: String = E.PHASES[j + 1]
	if nx == "combat" and not E.combatPossible(G): nx = "explore"  # nothing to fight: combat is skipped
	return E.PHASE_NAME[nx]

# ---------------- Next, with a check for unused options ----------------
func _next_label(G) -> String: return ("End %d" % int(G.y)) if G.phase == "trade" else "Next: " + _next_name(G)

func next_click() -> void:
	var G = Game.G
	if G == null or G.over: return
	if G.ask.size():
		show_toast("Answer the open question first.")
		return
	if not Game.settings.confirmNext:
		Game.next()
		return
	var warn := unused_actions(G)
	var where: String = E.ESTEP_NAME[G.estep] if G.phase == "econ" and G.estep != null else E.PHASE_NAME[G.phase]
	var body: String
	if warn.size(): body = "You still have unused options in %s:\n\n• %s" % [where, "\n• ".join(warn)]
	else: body = "Nothing left to do in %s." % where
	body += "\n\n(Turn this check off in Settings. Enter confirms.)"
	confirm(_next_label(G) + "?", body, func():
		Game.next()
		return null, "Continue anyway" if warn.size() else "Continue")

func unused_actions(G) -> Array:
	var out := []
	var names := func(a: Array) -> String: return ", ".join(a.map(func(x): return x.name))
	var add := func(a: Array, f: Callable):
		if a.size(): out.append(f.call(a))
	var ph: String = G.phase
	if ph == "move":
		add.call(G.ships.filter(func(s): return s.cls == "RE" and not SHRules.t(s.get("launched")) and E.moves(G, s).size()), func(a): return "Not launched yet: %s." % names.call(a))
		add.call(G.ships.filter(func(s): return (s.kind == "Orbiter" or s.kind == "Rover") and not SHRules.t(s.get("fixed")) and SHRules.t(s.get("launched")) and E.P(s.loc).t == "fly" and E.moves(G, s).size()), func(a): return "Waiting in a flyby box for their final move: %s." % names.call(a))
		add.call(G.ships.filter(func(s): return s.cls == "CV" and not SHRules.t(s.get("res")) and E.moves(G, s).size()), func(a): return "Crew vehicles that can still move: %s." % names.call(a))
	if ph == "explore":
		add.call(G.ships.filter(func(s): return E.exploreOptions(G, s).any(func(o): return o.kind == "explore" or o.kind == "probe")), func(a): return "Ships that can still explore: %s." % names.call(a))
		add.call(G.ships.filter(func(s): return E.exploreOptions(G, s).any(func(o): return o.kind == "produce" or o.kind == "harvest")), func(a): return "Crew vehicles that can still produce or harvest: %s." % names.call(a))
		add.call(G.ships.filter(func(s): return s.kind == "Flyby" and E.P(s.loc).t == "fly" and not SHRules.t(G.turn.acted.get(s.id))), func(a): return "Flybys in a flyby box will be sent outward automatically: %s." % names.call(a))
	if ph == "combat":
		add.call(E.combatOptions(G), func(a): return "Combat available: %s." % "; ".join(a.map(func(o): return o.label)))
	if ph == "build":
		add.call(G.ships.filter(func(s): return s.cls == "CV" and SHRules.t(s.get("res")) and s.loc == "earth"), func(a): return "Reserved crew vehicles on Earth you could unreserve: %s." % names.call(a))
		add.call(G.ships.filter(func(s): return s.cls == "CV" and SHRules.t(s.get("dmg")) and s.loc == "earth"), func(a): return "Damaged crew vehicles you could repair: %s." % names.call(a))
		var pe: Array = G.probes.get("earth", [])
		if pe.size() and not G.ships.any(func(s): return s.cls == "RE" and not SHRules.t(s.get("launched")) and s.kind != "Telescope"):
			out.append("Probe%s %s %s no unlaunched flyby, orbiter or rover to ride on." % ["s" if pe.size() > 1 else "", ", ".join(pe), "have" if pe.size() > 1 else "has"])
	if ph == "trade":
		add.call(G.ships.filter(func(s):
			var c = E.canFoundBase(G, s)
			return c != null and s.cargo.SUP >= c.cost), func(a): return "Crew vehicles that can found a base now: %s." % names.call(a))
		var afford := func(stock, cost) -> bool:
			for r in ["ORE", "SUP", "FUEL"]:
				if int(SHRules.gi(stock, r, 0)) < int(SHRules.gi(cost, r, 0)): return false
			return true
		add.call(G.bases.filter(func(b): return E.upgradeOptions(G, b).any(func(o): return o.why == null and afford.call(b.stock, o.next.c)) or (not SHRules.t(E.builtThisTurn(G, b).get("set")) and afford.call(b.stock, D.SETTLE_COST))), func(a): return "Bases that can still build this turn: %s." % names.call(a))
		add.call(G.bases.filter(func(b): return SHRules.t(b.get("trade")) and E.tradeLimitOwn(b)), func(a): return "Unused trade markers at: %s." % names.call(a))
	if ph == "econ":
		if G.estep == "diplomacy" and E.dipCost(G): out.append("Planned diplomacy attempts (%d politics markers) will now be rolled." % E.dipCost(G))
		if G.estep == "transport" and SHRules.t(G.get("transferLeft")): out.append("%d resource transfer(s) left unused." % int(G.transferLeft))
		if G.estep == "tech":
			var rt = ttree.rt_info(G)
			if rt == null or not rt.passed:
				add.call(D.TECH.filter(func(t): return E.techState(G, t) == "open" and G.bank[t.f] >= E.techCost(G, t)), func(a): return "Technologies you can afford: %s." % ", ".join(a.map(func(t): return t.n)))
			if rt != null and not rt.passed: out.append("Continuing passes your research turn; the other factions finish their research turns.")
			if G.polm: out.append("%d politics marker(s) not converted will be discarded." % int(G.polm))
			out.append("Banked tech points will be halved (now %s)." % ", ".join(SHRules.FIELDS.map(func(f): return "%s %s" % [SHRules.n(G.bank[f]), SHRules.FN[f]])))
		if G.estep == "policy" and not SHRules.t(G.get("policyPicked")):
			out.append(("%d missed %s not adopted yet." % [int(G.policyLeft), "policies" if int(G.policyLeft) > 1 else "policy"]) if int(SHRules.gi(G, "policyLeft", 0)) > 0 else "No policy adopted this decade.")
		if G.estep == "production":
			add.call(G.bases.filter(func(b): return SHRules.t(b.get("out")) and not SHRules.t(E.baseOutput(G, b))), func(a): return "Bases set to produce nothing: %s." % names.call(a))
	return out

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
		UIK.button(f, "Convert politics markers…", func(): ttree.convert_dialog(), G.polm < 1)
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
			UIK.button(h, "Transfer", func():
				var f0: String = places[from.selected][0]
				var t0: String = places[to.selected][0]
				var tyn: String = ty.get_item_text(ty.selected)
				var nn := int(amt.value)
				var extra := ""
				if f0 == "earth": extra += " Resources come off the faction board first, the rest are bought at $1B each."
				if t0 == "earth": extra += " Sold on Earth at 2 for $1B."
				confirm("Transfer %d %s?" % [nn, tyn], "From %s to %s.%s" % [places[from.selected][1], places[to.selected][1], extra], func(): return E.transferRes(G, f0, t0, tyn, nn), "Transfer"))
	if st == "production":
		UIK.para(box, "Production is collected; see the log. Set what each base produces next decade:", UIK.DIM, 13)
		for b in G.bases:
			var h := UIK.hbox(box)
			var l := UIK.rich(h, "[b]%s[/b]\n[color=#b8896a]%s[/color]" % [b.name, D.W[b.w].n], 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var types := ["ORE", "SUP", "FUEL", "tech"]
			var pk := UIK.pick(h, types.map(func(t): var o = E.baseOutput(G, b, t); return "%s %s" % ["Tech" if t == "tech" else t, ("(%d)" % int(o.n)) if o != null else "(none)"]))
			pk.selected = maxi(0, types.find(b.out))
			pk.item_selected.connect(func(i):
				b.out = types[i]
				Game.act(null))
		if not G.bases.size(): UIK.para(box, "You have no bases yet.", UIK.DIM, 13)
	if st == "tech":
		_trade_points(box, G)
		UIK.button(box, "Open the technology tree", func(): tabs.current_tab = TAB_TECH)
		_tech_list(box, G)
	if st == "policy":
		UIK.button(box, "Open the policy tree", func(): tabs.current_tab = TAB_POL)
		var left: int = SHRules.gi(G, "policyLeft", 0)
		UIK.para(box, ("Choose %d more policies (missed decades)." % left) if left > 0 else ("Policy chosen." if SHRules.t(G.get("policyPicked")) else "Choose one policy to adopt or upgrade."))
		for p in D.POL:
			var lv := E.polLv(G, p.k)
			var c := UIK.card(box)
			UIK.rich(c, "[b]%s%s[/b]  [color=#b8896a]%s[/color]" % [D.POL_LV[maxi(0, lv - 1)] if lv else "", p.n, ("level %d" % lv) if lv else "not held"])
			if lv < 3:
				UIK.para(c, "Next: " + p.d[lv], UIK.DIM, 13)
				UIK.button(c, "Adopt " + D.POL_LV[lv] + p.n, func(): confirm("Adopt %s%s?" % [D.POL_LV[lv], p.n], String(p.d[lv]) + "\nYou can adopt one policy per decade.", func(): return E.choosePolicy(G, p.k), "Adopt"), SHRules.t(G.get("policyPicked")))

func _tech_list(box, G) -> void:
	if G.world != null:
		var cur = E.techTurn(G.world)
		if cur == null: UIK.para(box, "Every faction has passed.", UIK.DIM)
		elif cur != G.f: UIK.para(box, "Research turn: " + D.FAC[cur].n, UIK.DIM)
		else:
			UIK.para(box, "Your research turn: develop one technology or pass.", UIK.AMBER)
			UIK.button(box, "Pass (no more technologies this decade)", func(): ttree.pass_research())
	UIK.para(box, "Points: %d Physics, %d Engineering, %d Biology. Unspent points are halved at the end of the step." % [G.bank.Phy, G.bank.Eng, G.bank.Bio])
	var open: Array = D.TECH.filter(func(tt): return E.techState(G, tt) == "open")
	open = SHRules.ssort(open, func(a, b): return E.techCost(G, a) - E.techCost(G, b))
	for tt in open:
		var c := E.techCost(G, tt)
		var ok: bool = G.bank[tt.f] >= c
		var h := UIK.hbox(box)
		var l := UIK.rich(h, "[b][color=#%s]%s[/color][/b] · %d %s\n[color=#b8896a]%s[/color]" % [UIK.FIELD_COL[tt.f].to_html(false), tt.n, c, E.FN[tt.f], tt.d], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.button(h, "Develop", func(): confirm("Develop %s?" % tt.n, "%s\n\nCost: %d %s points (you have %d)." % [tt.d, c, E.FN[tt.f], G.bank[tt.f]], func(): return ttree.develop(tt.k), "Develop"), not ok, E.techCostTxt(G, tt))

func _turn_build(box, G) -> void:
	refund_list(box)
	UIK.head(box, "Earth shipyard")
	UIK.rich(box, "On Earth the resources on your faction board are used first (now %s), the rest is bought at $1B each." % UIK.res_bb(E.estock(G)), 13)
	for o in E.buildOptions(G, "earth"):
		if o.why == "in service": continue
		var h := UIK.hbox(box)
		UIK.image(h, UIK.atlas_tex("atlas_" + G.f, o.kind + "|" + o.u.n), 40)
		var l := UIK.rich(h, "[b]%s[/b] [color=#b8896a]%s[/color]\n%s = %s%s" % [o.u.n, o.kind, UIK.res_bb(o.cost), E.earthCostTxt(G, o.cost), (" · [color=#ef6b5b]%s[/color]" % o.why) if o.why != null else ""], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.button(h, "Build", func(): buy_unit(o, "earth", false), o.why != null or G.cash < E.earthCash(G, o.cost))
		if o.cv and o.why == null: UIK.button(h, "Reserved", func(): buy_unit(o, "earth", true), false, "Reserved: 1 SUP and 1 Fuel cheaper")
	UIK.head(box, "Launch vehicles")
	lv_scrap_row(box)
	UIK.para(box, "On Earth: " + _lv_txt(G) + ". " + E.lvPoolTxt(G) + ".", UIK.DIM, 13)
	var f := UIK.flow(box)
	for z in [1, 2, 3, 4]: UIK.button(f, "Build LV-%d (1 ORE + %d FUEL)" % [z, z], func(): buy_lv(z, "earth"))
	var cvs: Array = G.ships.filter(func(s): return s.cls == "CV")
	if cvs.size():
		UIK.head(box, "Crew vehicles")
		for s in cvs:
			var h := UIK.hbox(box)
			UIK.image(h, UIK.atlas_tex("atlas_" + G.f, s.img + "|back" if SHRules.t(s.res) else s.img), 40)
			var l := UIK.rich(h, "[b]%s[/b] CV-%d · %s%s%s" % [s.name, s.sz, E.locName(s.loc), " · reserved" if SHRules.t(s.res) else "", (" · %d damage" % s.dmg) if SHRules.t(s.dmg) else ""], 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if SHRules.t(s.res): UIK.button(h, "Unreserve", func(): confirm("Unreserve %s?" % s.name, "%s leaves reserve and can be used again." % s.name, func(): return E.unreserve(G, s), "Unreserve"), not E.unreserveInfo(G, s).ok, String(E.unreserveInfo(G, s).get("why", "")))
			else: UIK.button(h, "Reserve", func(): reserve_ask(s))
			if SHRules.t(s.dmg): UIK.button(h, "Repair", func(): Game.act(E.repair(G, s)))
	for b in G.bases.filter(func(x): return SHRules.t(x.fac.sup)):
		UIK.head(box, b.name + " shipyard")
		UIK.rich(box, "Stock " + UIK.res_bb(b.stock), 13)
		var fl := UIK.flow(box)
		for z in [1, 2, 3, 4]: UIK.button(fl, "LV-%d" % z, func(): buy_lv(z, b.id))
		for o in E.buildOptions(G, b.id):
			if o.why == null: UIK.button(fl, "Build " + o.u.n, func(): buy_unit(o, b.id, false))

func _lv_txt(G) -> String:
	var parts := []
	for z in [1, 2, 3, 4]:
		var k := int(SHRules.gi(G.lv.earth, z, 0))
		if k: parts.append("LV-%d ×%d" % [z, k])
	return ", ".join(parts) if parts.size() else "none"

func _ship_row(box, G, s, sub: String) -> HBoxContainer:
	var h := UIK.hbox(box)
	UIK.image(h, UIK.atlas_tex("atlas_" + G.f, s.img + "|back" if SHRules.t(s.res) else s.img), 40)
	var l := UIK.rich(h, "[b]%s[/b] [color=#b8896a]%s[/color]\n%s" % [s.name, ("CV-%d" % s.sz) if s.cls == "CV" else s.kind, sub], 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

func _turn_move(box, G) -> void:
	var ready: Array = G.ships.filter(func(s): return E.moves(G, s).size() > 0)
	UIK.head(box, "Ships that can move (%d)" % ready.size())
	UIK.para(box, "Select a ship to see where it can go. You can also click it on the map.", UIK.DIM, 12)
	for s in ready: _pick_row(box, G, s, E.locName(s.loc) + " · %d destinations" % E.moves(G, s).map(func(m): return m.dest).size())
	var waiting: Array = G.ships.filter(func(s): return s.loc == "earth" and not E.moves(G, s).size())
	if waiting.size():
		UIK.para(box, "On Earth without a launch: " + ", ".join(waiting.map(func(s): return s.name)) + ". They need a launch vehicle (build one, or one is bought at launch if a counter is free).", UIK.DIM, 13)
	if G.bases.size():
		UIK.head(box, "Cargo flight from Earth to a base")
		var lvl := E.launchLVs(G, "earth", 1)
		if not lvl.size():
			UIK.para(box, "No launch vehicle available on Earth.", UIK.DIM, 13)
		else:
			UIK.para(box, "An LV carries resources to one of your bases: faction-board resources first, the rest bought at $1B each. Capacity = LV size%s." % [" + 1 (Equatorial Launch Sites)" if G.f == "sa" else ""], UIK.DIM, 13, 0)
			var h := UIK.flow(box)
			var bp := UIK.pick(h, G.bases.map(func(b): return b.name))
			var lp := UIK.pick(h, lvl.map(func(o): return "LV-%d %s · carries %d" % [o.n, "from stock" if SHRules.t(o.get("stock")) else "(new: %s)" % o.txt, (o.n + (1 if G.f == "sa" else 0)) * E.cargoMul(G)]))
			var slot := UIK.vbox(box)
			var cu := [null]
			var build := func():
				UIK.clear(slot)
				var o: Dictionary = lvl[lp.selected]
				var cap: int = (int(o.n) + (1 if G.f == "sa" else 0)) * E.cargoMul(G)
				cu[0] = cargo_sliders(slot, cap, "LV-%d cargo" % int(o.n), func(): return null if not SHRules.t(o.get("buy")) else o.cost)
			lp.item_selected.connect(func(_i): build.call())
			build.call()
			UIK.button(box, "Launch cargo", func():
				var ld: Dictionary = cu[0].load.call()
				if E.sum(ld) == 0:
					show_toast("Set some cargo with the sliders first.")
					return
				var o: Dictionary = lvl[lp.selected]
				Game.act(E.shipCargo(G, G.bases[bp.selected].id, ld, int(o.n))))

func _turn_combat(box, G) -> void:
	var opts := E.combatOptions(G)
	if not opts.size(): UIK.para(box, "No attacks are possible this turn.", UIK.DIM)
	for o in opts: UIK.button(box, o.label, func(): confirm("Fight?", String(o.label) + "\nThe dice decide the result and losses cannot be undone.", func(): return E.combatAct(G, o), "Fight"))

func _turn_explore(box, G) -> void:
	var ready: Array = G.ships.filter(func(s): return E.exploreOptions(G, s).size() > 0)
	UIK.head(box, "Ships that can explore (%d)" % ready.size())
	UIK.para(box, "Select a ship to see its research and exploration options.", UIK.DIM, 12)
	for s in ready: _pick_row(box, G, s, E.locName(s.loc) + " · %d options" % E.exploreOptions(G, s).size())

## one selectable ship: the chosen one is marked; Select opens the Selected tab
func _pick_row(box, G, s, sub: String) -> void:
	var chosen: bool = Game.sel != null and Game.sel.t == "ship" and SHRules.eq(Game.sel.id, s.id)
	var c := UIK.card(box)
	if chosen: c.modulate = Color(1.0, 0.92, 0.7)
	var h := _ship_row(c, G, s, sub)
	var pick := func():
		Game.select({"t": "ship", "id": s.id})
		if s.loc != "earth": fly(board.pos_of(s.loc))
		tabs.current_tab = 1
	UIK.button(h, "Selected ▸" if chosen else "Select", pick)

func _explore_btn(box, G, s, o) -> void:
	var lbl: String
	match o.kind:
		"explore": lbl = "Explore %s (value %d)" % [D.W[o.w].n, o.value]
		"probe": lbl = "Drop probe on %s (value %d)" % [D.W[o.w].n, o.value]
		"produce": lbl = "Produce %s at %s (value %d)" % [o.res, D.W[o.w].n, o.value]
		"harvest": lbl = "Harvest the asteroid"
		_: lbl = o.kind
	UIK.button(box, lbl, func(): _explore_click(G, s, o))

func _explore_click(G, s, o) -> void:
	if o.kind == "explore" or o.kind == "probe":
		show_explore(G, s, o)
		return
	var room: int = int(s.cap * E.cargoMul(G)) - int(E.sum(s.cargo))
	var fn := func(): return E.explore(G, s, o)
	if o.kind == "produce":
		var v: int = int(o.value)
		confirm("Produce %s at %s?" % [o.res, D.W[o.w].n], "%s produces 1 %s automatically. Then roll a d10%s: %d or less adds 1 more, and a 1 adds another.\n\nProduction value %d. Cargo room %d. Then a recall check (%d%%)." % [s.name, o.res, " (−1 for Space Refining)" if E.has(G, "ref") else "", v % 10 if v % 10 else v, v, room, E.recall(G)], fn, "Produce")
	else:
		confirm("Harvest the asteroid?", "%s rolls a d10 on the asteroid harvest table: 1–3 SUP, 4–6 Fuel, 7–10 Ore (3 to 6 units), and earns 1 victory marker.\n\nCargo room %d. Then a recall check (%d%%)." % [s.name, room, E.recall(G)], fn, "Harvest")

func _turn_trade(box, G) -> void:
	var founders: Array = G.ships.filter(func(s): return E.canFoundBase(G, s) != null)
	for s in founders:
		var c = E.canFoundBase(G, s)
		var h := _ship_row(box, G, s, "Can found a base at %s for %d SUP (carries %d)." % [D.W[c.w].n, c.cost, s.cargo.SUP])
		UIK.button(h, "Found base", func(): found_ask(G, s), s.cargo.SUP < c.cost)
	for b in G.bases: _base_card(box, G, b)
	var npfs: Array = G.w.keys().filter(func(k): return SHRules.t(G.w[k].npf))
	for k in npfs:
		var info = E.npfTradeInfo(G, k)
		if info == null or info.why != null: continue
		UIK.button(box, "Trade at %s (%s %s, up to %d)" % [info.name, info.tm.side, info.tm.type, info.limit], func(): trade_ask(G, {"w": k}, info.tm, int(info.limit), "Trade at %s?" % info.name))


## Genetic Engineering / Matter-Energy Conversion / Nano-Technology: trade tech points for cash
func _trade_points(box, G) -> void:
	var map := {"Bio": "gen", "Phy": "mec", "Eng": "nano"}
	for f in ["Bio", "Phy", "Eng"]:
		if not E.has(G, map[f]): continue
		var h := UIK.hbox(box)
		var l := UIK.para(h, "%s points (%d):" % [E.FN[f], int(G.bank[f])], null, 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.button(h, "Buy 1 for $1B", func(): confirm("Buy 1 %s point?" % E.FN[f], "Pay $1B (you have $%dB) for 1 %s point." % [int(G.cash), E.FN[f]], func(): return E.tradePoints(G, f, "buy"), "Buy"), G.cash < 1)
		UIK.button(h, "Sell 2 for $1B", func(): confirm("Sell 2 %s points?" % E.FN[f], "Trade 2 of your %d %s points for $1B." % [int(G.bank[f]), E.FN[f]], func(): return E.tradePoints(G, f, "sell"), "Sell"), G.bank[f] < 2)

func _cost_line(cost: Dictionary, b) -> String:
	if b == null: return "Costs %s: %s (faction board %s, cash $%dB)." % [E.resTxt(cost), E.earthCostTxt(Game.G, cost), E.resTxt(E.estock(Game.G)), int(Game.G.cash)]
	return "Costs %s from %s's stock (it has %s)." % [E.resTxt(cost), b.name, E.resTxt(b.stock)]

func found_ask(G, s) -> void:
	var c = E.canFoundBase(G, s)
	if c == null: return
	confirm("Found %s base at %s?" % ["an orbital" if c.pos == "orbit" else "a surface", D.W[c.w].n], "Uses %d SUP from %s's hold (it carries %d). The base takes the next name on your faction sheet." % [c.cost, s.name, int(s.cargo.SUP)], func(): return E.foundBase(G, s), "Found base")

func trade_ask(G, where: Dictionary, tm: Dictionary, limit: int, title: String) -> void:
	var body: String = ("Buy up to %d %s at 2 per $1B (you have $%dB)." % [limit, tm.type, int(G.cash)]) if tm.side == "buy" else ("Sell up to %d %s at $2B each." % [limit, tm.type])
	body += "\n" + ("Enhanced trading: you trade here once; the marker stays until every faction has traded." if (where.has("w") and E.enhTrade(G)) else "The trade marker is used up after this trade.")
	confirm(title, body, func(): return E.trade(G, where, 99), "Buy" if tm.side == "buy" else "Sell")

func _fac_ask(G, b, c: String) -> void:
	var o = null
	for x in E.upgradeOptions(G, b):
		if x.c == c: o = x
	if o == null or o.next == null: return
	confirm("Build %s at %s?" % [o.next.n, b.name], _cost_line(o.next.c, b) + "\n\nA base can build several things in one turn, but only one tier of each building (and one settlement) per turn.", func(): return E.buildFacility(G, b, c), "Build")

func _repair_ask(G, b, c: String) -> void:
	confirm("Repair at %s?" % b.name, "Removes 1 damage marker for 1 ORE from %s's stock (it has %d)." % [b.name, int(b.stock.ORE)], func(): return E.repairFacility(G, b, c), "Repair")

func _settle_ask(G, b) -> void:
	confirm("Add a settlement at %s?" % b.name, _cost_line(D.SETTLE_COST, b) + "\n%s has %d settlement%s." % [b.name, b.set, "" if b.set == 1 else "s"], func(): return E.buildSettlement(G, b), "Build")

func _terra_ask(G, b) -> void:
	var c: int = (3 if E.has(G, "atm") else 4) + int(SHRules.gi(G.turn.terraBuys, b.id, 0))
	confirm("Buy a terraforming point for %s?" % D.W[b.w].n, "Costs %d SUP from %s (it has %d). Each extra point this turn costs 1 SUP more." % [c, b.name, int(b.stock.SUP)], func(): return E.terraform(G, b), "Buy")

const FACDESC := {
	"lab": ["Required for the base to produce tech points (the world card's research value, plus bonuses for settlements, signs of life and existing life).", "Adds +3 tech points to the base's research output."],
	"mine": ["Lets the base produce resources of one type per decade (world card production plus the world's intrinsic production; the total must be above 0).", "Adds +1 to resource production.", "Small Refinery (upgrade of a large Mining Station): adds +3 to resource production.", "Large Refinery: adds +5 to resource production."],
	"sup": ["Builds LV-1 and LV-2 launch vehicles, unreserves CV-2s, and repairs 1 damage marker per CV each turn.", "Builds LV-3 and LV-4, unreserves CV-3s, and repairs 2 damage markers per CV.", "Small Spaceport (upgrade of a large Supply Station): builds robotic explorers and CV-2s, unreserves CV-4s and CV-5s, repairs 3 per CV.", "Large Spaceport: builds every crew vehicle, unreserves any size, unlimited repairs per CV."],
	"def": ["Combat value 3 with 1 combat drone: the base fights with it, and a blockading fleet needs combined combat value of at least 3.", "Combat value 7 with 3 combat drones (replaces the small network); a blockading fleet needs combined combat value of at least 7."]}
const FACNAME := {"lab": "Research Lab", "mine": "Mining", "sup": "Supply", "def": "Defense Network"}

func _base_card(box, G, b) -> void:
	var h := UIK.hbox(UIK.card(box))
	var l := UIK.rich(h, "[b]%s[/b] · %s · %d settlement%s\nStock %s" % [b.name, D.W[b.w].n, b.set, "" if b.set == 1 else "s", UIK.res_bb(b.stock)], 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIK.button(h, "Open", func():
		Game.select({"t": "base", "id": b.id})
		tabs.current_tab = 1)

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
		"obase":
			var g = G.world.facs.get(s.f) if G.world != null else null
			var b = E._baseById(g, s.id) if g != null else null
			if b != null:
				UIK.title(box, b.name)
				UIK.para(box, "%s base · %s" % [D.FAC[s.f].n, D.W[b.w].n], UIK.DIM)
				var fac := []
				for c in [["lab", "lab"], ["mine", "mine"], ["sup", "supply"], ["def", "defense"]]:
					if SHRules.t(b.fac[c[0]]): fac.append("%s %d" % [c[1], b.fac[c[0]]])
				UIK.para(box, ("Facilities: " + ", ".join(fac)) if fac.size() else "No facilities.")
				if b.set > 0: UIK.para(box, "%d settlement%s" % [b.set, "s" if b.set > 1 else ""])
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
			var cargo_ui = null
			if s.cls == "CV" and s.loc == "earth" and SHRules.t(s.cap) and s.cap * E.cargoMul(G) > E.sum(s.cargo):
				var newlv := func():
					if lvs.size() == 0: return null
					var o: Dictionary = lvs[lvpick.selected] if lvpick != null else lvs[0]
					return o.cost if SHRules.t(o.get("buy")) else null
				cargo_ui = cargo_sliders(box, int(s.cap * E.cargoMul(G) - E.sum(s.cargo)), "Load cargo on Earth", newlv)
				if lvpick != null: lvpick.item_selected.connect(func(_i): cargo_ui.update.call())
			var uniq := []
			for m in mv:
				if m.dest == s.loc: continue
				if not uniq.any(func(x): return x.dest == m.dest): uniq.append(m)
			var fl := _filter_list(box, uniq.size() > 5)
			for m in uniq:
				var di := _dest_info(G, m.dest)
				var row := UIK.vbox(fl.list, 1)
				row.set_meta("fn", (String(m.label) + " " + di.names).to_lower())
				row.set_meta("ff", di.fields)
				UIK.button(row, m.label, func():
					var extra := {}
					if lvpick != null: extra.lvSize = lvs[lvpick.selected].n
					if cargo_ui != null:
						var ld: Dictionary = cargo_ui.load.call()
						if E.sum(ld) > 0: extra.load = ld
					do_move(s, m.dest, extra))
				var det: String = di.bb
				det += ("" if det == "" else " · ") + (("%d turns" % int(m.eta)) if SHRules.t(m.get("eta")) else "this turn")
				if m.get("lv") != null: det += " · LV-%d%s" % [int(m.lv.n), (" (new: %s)" % m.lv.txt) if SHRules.t(m.lv.get("buy")) else " from stock"]
				if SHRules.t(m.get("final")): det += " · final move"
				UIK.rich(row, "[color=#b8896a]" + det + "[/color]", 12)
				if di.missions != "": UIK.rich(row, di.missions, 12)
			fl.apply.call()
		elif s.loc == "earth": UIK.para(box, "No launch is possible now (it needs a launch vehicle, or it has moved this turn).", UIK.DIM)
	if G.phase == "explore":
		if s.kind == "Flyby" and E.P(s.loc).t == "fly": UIK.button(box, "Skip, transfer outward", func(): confirm("Skip exploring?", s.name + " does not explore and transfers outward.", func(): return E.flybySkip(G, s), "Skip"))
		var ex := E.exploreOptions(G, s)
		if ex.size():
			UIK.head(box, "Explore")
			var fl := _filter_list(box, ex.size() > 5)
			for o in ex:
				var row := UIK.vbox(fl.list, 1)
				var wn: String = D.W[o.w].n if o.get("w") != null else ""
				row.set_meta("fn", (wn + " " + (D.SYS[D.W[o.w].sys].n if o.get("w") != null else "asteroid")).to_lower())
				row.set_meta("ff", D.W[o.w].f if (o.get("w") != null and D.W[o.w].get("f") != null) else "")
				_explore_btn(row, G, s, o)
				if o.get("w") != null:
					var det := ""
					match o.kind:
						"produce": det = "production value %d" % int(o.value)
						"harvest": det = ""
						_: det = "%s · world [b]%d[/b] · explore value [b]%d[/b]%s" % [_field_bb(o.w), int(G.w[o.w].v), int(o.value), (" (−%d distance)" % int(o.pen)) if SHRules.t(o.get("pen")) else ""]
					if det != "": UIK.rich(row, "[color=#b8896a]" + det + "[/color]", 12)
					var ms := _missions_bb(G, [o.w], false)
					if ms != "": UIK.rich(row, ms, 12)
			fl.apply.call()
	if G.phase == "trade":
		var c = E.canFoundBase(G, s)
		if c != null: UIK.button(box, "Found %s base here (%d SUP)" % ["an orbital" if c.pos == "orbit" else "a surface", c.cost], func(): found_ask(G, s), s.cargo.SUP < c.cost)
		var b = E.atOwnBase(G, s)
		if b != null and SHRules.t(s.cap):
			UIK.head(box, "At " + b.name)
			var lf := UIK.flow(box)
			UIK.button(lf, "Unload all", func(): Game.act(E.unload(G, s, b)), E.sum(s.cargo) == 0)
			for r in ["ORE", "SUP", "FUEL"]: UIK.button(lf, "Load " + r, func(): Game.act(E.loadAt(G, s, b, r, 99)), b.stock[r] < 1)
	if s.loc == "earth" and SHRules.t(s.cap):
		UIK.head(box, "Cargo on Earth")
		var room: int = int(s.cap * E.cargoMul(G) - E.sum(s.cargo))
		if room > 0:
			var lbh := [null]
			var cuh := [null]
			cuh[0] = cargo_sliders(box, room, "Load cargo into the hold", null, func(ok): if lbh[0] != null: lbh[0].disabled = not ok or E.sum(cuh[0].load.call()) == 0)
			lbh[0] = UIK.button(box, "Load", func():
				var L: Dictionary = cuh[0].load.call()
				var err = null
				for r in ["ORE", "SUP", "FUEL"]:
					if int(L[r]) > 0:
						err = E.buyCargo(G, s, r, int(L[r]))
						if err != null: break
				Game.act(err), true)
			UIK.para(box, "Or load while launching: the move buttons above use the same sliders.", UIK.DIM, 12, 0)
		else: UIK.para(box, "The hold is full.", UIK.DIM, 13)
		if E.sum(s.cargo): UIK.button(box, "Unload onto the faction board", func(): Game.act(E.sellCargo(G, s)))
	var sv = E.scrapValue(G, s)
	UIK.button(box, ("Scrap (recover %s)" % E.resTxt(sv.back)) if sv != null else "Scrap (destroyed, nothing recovered)", func(): scrap_ask(s))

func _sel_base_panel(box, G, b) -> void:
	var sr = E.setRow(b.set)
	UIK.title(box, b.name)
	UIK.para(box, "%s · %s base · founded %d · %d settlement%s%s" % [D.W[b.w].n, "orbital" if E.basePos(b) == "orbit" else "surface", int(b.built), b.set, "" if b.set == 1 else "s", (" (trade %d, +%d resources, +%d tech)" % [sr[1], sr[2], sr[3]]) if sr != null else ""], UIK.DIM, 13)
	UIK.rich(box, "Stock " + UIK.res_bb(b.stock), 14)
	if SHRules.t(b.get("setHits")):
		var c := UIK.card(box)
		UIK.para(c, "%d settlement damage. One settlement is damaged and does not count for trade or production until repaired (3 damage loses it)." % int(b.setHits), UIK.BAD, 13)
		UIK.button(c, "Repair settlement", func(): _repair_ask(G, b, "set"), b.stock.ORE < 1, "1 ORE per damage marker")
	var note := ""
	if E.basePos(b) == "orbit" and not E.has(G, "elev"): note += " Mines need the Space Elevator technology."
	if D.W[b.w].tags.has("severeAtm") and not E.has(G, "psh"): note += " Mines need the Pressure Shell technology (severe atmosphere)."
	UIK.para(box, "One of each facility type, small first and then large, one tier per turn." + note, UIK.DIM, 12)
	UIK.head(box, "Facilities")
	var trade_phase: bool = G.phase == "trade"
	for o in E.upgradeOptions(G, b):
		var c := UIK.card(box)
		var h := UIK.hbox(c, 8)
		var cur = D.FACIL[o.c][o.lv - 1] if o.lv > 0 else null
		if cur != null and cur.get("m") != null: UIK.image(h, UIK.atlas_tex("markers", cur.m), 54, cur.n)
		var v := UIK.vbox(h, 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.rich(v, "[b]%s[/b]" % (cur.n if cur != null else FACNAME[o.c] + " · none"), 13)
		UIK.para(v, FACDESC[o.c][o.lv - 1] if o.lv > 0 else FACDESC[o.c][0], UIK.DIM, 12)
		if SHRules.t(b.dmg[o.c]): UIK.para(v, "%d damage" % int(b.dmg[o.c]), UIK.BAD, 12)
		if o.next != null: UIK.rich(v, "[color=#b8896a]Next: %s[/color] %s%s" % [o.next.n, UIK.res_bb(o.next.c), (" · [color=#ef6b5b]%s[/color]" % o.why) if o.why != null else ""], 12)
		else: UIK.para(v, "Fully built", UIK.DIM, 12)
		var bf := UIK.flow(c)
		if SHRules.t(b.dmg[o.c]): UIK.button(bf, "Repair", func(): _repair_ask(G, b, o.c), b.stock.ORE < 1, "1 ORE per damage marker")
		if o.next != null: UIK.button(bf, "Build " + o.next.n, func(): _fac_ask(G, b, o.c), o.why != null or not trade_phase or not E.enough(b.stock, o.next.c), String(o.why) if o.why != null else ("Built in the trade & base phase" if not trade_phase else ""))
	var f := UIK.flow(box)
	var done: bool = SHRules.t(E.builtThisTurn(G, b).get("set"))
	UIK.button(f, "Add settlement (%s)" % E.resTxt(D.SETTLE_COST), func(): _settle_ask(G, b), not trade_phase or done or not E.enough(b.stock, D.SETTLE_COST), "One settlement per turn" if done else "")
	if D.TERRA.has(b.w): UIK.button(f, "Terraform (%d/%d)" % [int(G.w[b.w].terra), int(D.TERRA[b.w])], func(): _terra_ask(G, b), not trade_phase or not E.has(G, "terra"), "Needs the Terraforming technology")
	var o = E.baseOutput(G, b)
	UIK.head(box, "Produces each decade")
	UIK.para(box, ("%d %s" % [o.n, (E.FN[o.field] + " points") if o.type == "tech" else o.type]) if o != null else "Nothing yet (needs a Mining Station or Research Lab).", UIK.DIM, 13)
	var pf := UIK.flow(box)
	for ty in ["tech", "ORE", "SUP", "FUEL"]:
		var bo = E.baseOutput(G, b, ty)
		if bo != null: UIK.button(pf, ("Produce %s%s" % [ty, " (selected)" if b.out == ty else ""]), func():
			b.out = ty
			Game.act(null))
	if SHRules.t(b.get("trade")):
		UIK.head(box, "Trade marker")
		var lim: int = E.tradeLimitOwn(b)
		UIK.para(box, "%s (up to %d)" % [("Buy 2 %s per $1B" % b.trade.type) if b.trade.side == "buy" else ("Sell %s for $2B each" % b.trade.type), lim], null, 13)
		UIK.button(box, "Trade", func(): trade_ask(G, {"base": b.id}, b.trade, lim, "Trade at %s?" % b.name), not trade_phase or lim < 1)

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
		else: UIK.button(box, "Trade", func(): trade_ask(G, {"w": k}, info.tm, int(info.limit), "Trade at %s?" % info.name))

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

# ---------------- Tech and Policy tabs (the trees cover the map) ----------------
func build_tech_panel() -> void:
	var G = Game.G
	var box := tech_box
	UIK.clear(box)
	UIK.title(box, "Technologies")
	var R = ttree.rt_info(G)
	var can: bool = G.estep == "tech"
	UIK.para(box, "Research turns: in reverse initiative order each faction develops one technology or passes; repeat until all have passed." if R != null else ("Develop technologies now: click a highlighted card in the tree." if can else "Technologies are developed in the economic phase (every decade from 2040). The tree shows what each one needs."), UIK.DIM, 13)
	if R != null:
		UIK.rich(box, ttree.rt_status_bb(G), 13)
		if R.mine and not R.passed: UIK.button(box, "Pass", func(): ttree.pass_research())
	for f in E.FIELDS: UIK.rich(box, "[color=#%s]%s[/color]: [b]%d[/b] points" % [UIK.FIELD_COL[f].to_html(false), E.FN[f], G.bank[f]], 14)
	var cnt: int = D.TECH.filter(func(t): return SHRules.t(G.tech.get(t.k))).size()
	UIK.para(box, "%d of %d developed. Each undeveloped technology costs 3 VP at the end. Costs drop by 3 for each other faction that has a technology (the faction tags on its card)." % [cnt, D.TECH.size()], UIK.DIM, 13)
	if G.world != null: UIK.rich(box, ttree.facbanks_bb(G), 13)
	UIK.button(box, "Convert politics markers (%d)…" % G.polm, func(): ttree.convert_dialog(), G.polm < 1)
	UIK.button(box, "Back to the map", func(): tabs.current_tab = TAB_TURN)

const RES_COL := {"ORE": Color("#f1e4cf"), "SUP": Color("#e07a4a"), "FUEL": Color("#f8bc04")}
## sliders for ORE / SUP / FUEL that share one hold's free room (the web version's cargoSliders). extra = a Callable that
## returns other Earth costs to add (a new launch vehicle), or null. Returns {"load": Callable -> {ORE,SUP,FUEL}, "update": Callable, "ok": Callable -> bool}
func cargo_sliders(box: Node, room: int, title: String, extra = null, on_change = null) -> Dictionary:
	var G = Game.G
	var c := UIK.card(box)
	UIK.para(c, "%s: %d free. Resources on your faction board are used first, the rest is bought at $1B each." % [title, room], UIK.DIM, 13, 0)
	var sls := {}
	for r in ["ORE", "SUP", "FUEL"]: sls[r] = UIK.slider(c, r, room, 0, RES_COL[r])
	var cost := UIK.rich(c, "", 13)
	var st := {"ok": true}
	var load_fn := func() -> Dictionary:
		var d := {}
		for r in sls: d[r] = int(sls[r].value)
		return d
	var upd := func():
		var L: Dictionary = load_fn.call()
		var all: Dictionary = L.duplicate()
		var x = extra.call() if extra != null else null
		if x != null:
			for r in x: all[r] = int(all.get(r, 0)) + int(x[r])
		var cash: int = E.earthCash(G, all)
		st.ok = cash <= G.cash
		if E.sum(L) or x != null:
			var pre: String = ("Cargo %s" % UIK.res_bb(L)) if E.sum(L) else "New launch vehicle"
			if E.sum(L) and x != null and E.sum(x): pre += " plus the new launch vehicle"
			cost.text = "%s: [b][color=#%s]%s[/color][/b]%s" % [pre, (UIK.GOOD if st.ok else UIK.BAD).to_html(false), E.earthCostTxt(G, all), "" if st.ok else " (you have $%dB)" % int(G.cash)]
		else: cost.text = "[color=#b8896a]No cargo.[/color]"
		if on_change != null: on_change.call(st.ok)
	UIK.share_cap(sls.values(), room, upd)
	upd.call()
	return {"load": load_fn, "update": upd, "ok": func(): return st.ok}

# ---------------- search + research-field filter for long destination / target lists (as in the web version) ----------------
var _lf := {"q": "", "f": ""}
const MIS_KIND := {"mine": ["Your mission", "#f8bc04"], "common": ["Common mission", "#d9a35a"], "dated": ["Dated mission", "#e2675b"]}

## a search box and All/Physics/Engineering/Biology chips above a list; rows carry meta "fn" (search text) and "ff" (fields).
## returns {"list": VBox to add rows to, "apply": Callable to run after the rows are added}
func _filter_list(box: Node, show_bar: bool) -> Dictionary:
	var list := UIK.vbox(box, 6)
	var none := UIK.para(list, "No matches.", UIK.DIM, 13)
	none.visible = false
	var apply := func():
		var q: String = String(_lf.q).strip_edges().to_lower()
		var shown := 0
		for r in list.get_children():
			if r == none: continue
			var ok: bool = (q == "" or String(r.get_meta("fn", "")).contains(q)) and (_lf.f == "" or String(r.get_meta("ff", "")).split(" ").has(_lf.f))
			r.visible = ok
			if ok: shown += 1
		none.visible = shown == 0 and list.get_child_count() > 1
	if show_bar:
		var bar := UIK.vbox(box, 4)
		box.move_child(bar, list.get_index())
		var le := LineEdit.new()
		le.placeholder_text = "Search worlds…"
		le.clear_button_enabled = true
		le.text = _lf.q
		le.text_changed.connect(func(t): _lf.q = t; apply.call())
		bar.add_child(le)
		var chips := UIK.flow(bar)
		var grp := ButtonGroup.new()
		for kv in [["", "All"], ["Phy", "Physics"], ["Eng", "Engineering"], ["Bio", "Biology"]]:
			var b := Button.new()
			b.text = kv[1]
			b.toggle_mode = true
			b.button_group = grp
			b.focus_mode = Control.FOCUS_NONE
			b.button_pressed = _lf.f == kv[0]
			if kv[0] != "": b.add_theme_color_override("font_color", UIK.FIELD_COL[kv[0]])
			b.pressed.connect(func(): _lf.f = kv[0]; apply.call())
			chips.add_child(b)
	return {"list": list, "apply": apply}

func _field_bb(w: String) -> String:
	if w == "alp" or D.W[w].get("f") == null: return "[color=#b8896a]random field[/color]"
	return "[color=#%s]%s[/color]" % [UIK.FIELD_COL[D.W[w].f].to_html(false), E.FN[D.W[w].f]]

## active missions on these worlds (yours, the common one, dated ones), as coloured text
func _missions_bb(G, ws: Array, with_world: bool) -> String:
	var out := []
	for w in ws:
		for m in E.missionsAt(G, w):
			var md: Dictionary = D.MIS[int(m.id)]
			var k: Array = MIS_KIND[m.kind]
			out.append("[color=%s]★ %s[/color]: %s%d VP%s" % [k[1], k[0], (D.W[w].n + ", ") if with_world else "", int(md.vp), " (crewed)" if SHRules.t(md.cv) else ""])
	return "   ".join(out)

## research value, worlds and missions of a move destination: the world itself, or the worlds of the system a box leads to
func _dest_info(G, dest: String) -> Dictionary:
	var p := E.P(dest)
	var ws: Array
	if p.w != null: ws = [p.w]
	elif p.s != null: ws = E.worldsIn(p.s)
	else: ws = ["ear"]
	var live: Array = ws.filter(func(w): return G.w.get(w) != null and not D.W[w].tags.has("tele"))
	var names := []
	var fields := []
	for w in live:
		names.append(D.W[w].n + " " + String(D.SYS[D.W[w].sys].n))
		var f = D.W[w].get("f")
		if f != null and not fields.has(f): fields.append(f)
	var bb := ""
	if p.w != null and live.size():
		bb = "%s [b]%d[/b]" % [_field_bb(p.w), int(G.w[p.w].v)]
	elif live.size():
		var top: Array = live.filter(func(w): return G.w[w].v > 0)
		top.sort_custom(func(a, b): return G.w[a].v > G.w[b].v)
		var parts := []
		for w in top.slice(0, 4): parts.append("%s [color=#%s]%s[/color] [b]%d[/b]" % [D.W[w].n, UIK.FIELD_COL.get(D.W[w].get("f"), UIK.DIM).to_html(false), String(E.FN.get(D.W[w].get("f"), "?")).substr(0, 3), int(G.w[w].v)])
		bb = ", ".join(parts)
	return {"names": " ".join(names).to_lower(), "fields": " ".join(fields), "bb": bb, "missions": _missions_bb(G, live, p.w == null)}

func build_pol_panel() -> void:
	var G = Game.G
	var box := pol_box
	UIK.clear(box)
	UIK.title(box, "Policies")
	UIK.para(box, "Adopt a policy now: click a highlighted card in the tree." if (G.estep == "policy" and not SHRules.t(G.get("policyPicked"))) else "One policy is adopted each decade in the economic phase; each chain goes Basic → Vigorous → Unified.", UIK.DIM, 13)
	var held := []
	for p in D.POL:
		var lv := E.polLv(G, p.k)
		if lv: held.append(D.POL_LV[lv - 1] + p.n)
	UIK.para(box, "You hold: " + (", ".join(held) if held.size() else "none") + ".")
	UIK.para(box, "At most one Unified policy and ten policy levels in total.", UIK.DIM, 13)
	UIK.button(box, "Back to the map", func(): tabs.current_tab = TAB_TURN)

# ---------------- purchases, refunds and scrapping ----------------
func buy_unit(o, where: String, reserved := false) -> void:
	var G = Game.G
	var cost: Dictionary = o.cost.duplicate()
	if reserved:
		cost.SUP = maxi(0, int(cost.SUP) - 1)
		cost.FUEL = maxi(0, int(cost.FUEL) - 1)
	var txt: String = E.earthCostTxt(G, cost) if where == "earth" else E.resTxt(cost)
	confirm("Build %s?" % o.u.n, "%s %s%s at %s.\nCost: %s.\n\nYou can refund it again during this phase." % [o.kind, o.u.n, " (reserved)" if reserved else "", "Earth" if where == "earth" else E._baseById(G, where).name, txt], func(): return E.buildUnit(G, o.key, where, reserved), "Build")

func buy_lv(z: int, where: String) -> void:
	var G = Game.G
	var cost := {"ORE": 1, "FUEL": z}
	var txt: String = E.earthCostTxt(G, cost) if where == "earth" else E.resTxt(cost)
	confirm("Build LV-%d?" % z, "A launch vehicle LV-%d at %s.\nCost: %s.\n\nYou can refund it again during this phase." % [z, "Earth" if where == "earth" else E._baseById(G, where).name, txt], func(): return E.buildLV(G, z, where), "Build")

func _buy_name(G, b: Dictionary) -> String:
	match b.k:
		"ship":
			for sh in G.ships:
				if sh.id == b.sid: return "%s (%s)" % [sh.name, ("CV-%d" % sh.sz) if sh.cls == "CV" else sh.kind]
			return "ship"
		"probe": return "Probe " + String(b.name)
		_: return "LV-%d" % int(b.z)

## everything bought this build phase, each with a Refund button (good for trying other combinations)
func refund_list(box) -> void:
	var G = Game.G
	var buys: Array = E.refundable(G)
	if not buys.size(): return
	UIK.head(box, "Bought this phase · refundable")
	UIK.para(box, "Just planning? Refund a purchase to get back exactly what you paid, then try another combination.", UIK.DIM, 12)
	for b in buys:
		var h := UIK.hbox(box)
		var paid: String = E.earthRefundTxt(b.paid) if b.where == "earth" else E.resTxt(b.paid.cost)
		var l := UIK.rich(h, "[b]%s[/b]\n[color=#b8896a]%s · paid %s[/color]" % [_buy_name(G, b), "Earth" if b.where == "earth" else E._baseById(G, b.where).name, paid], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.button(h, "Refund", func(): Game.act(E.refundBuy(G, b.uid)))
	if buys.size() > 1:
		UIK.button(box, "Refund everything", func():
			var err = null
			for i in range(buys.size() - 1, -1, -1):
				err = E.refundBuy(G, buys[i].uid)
				if err != null: break
			Game.act(err))

func reserve_ask(s) -> void:
	var G = Game.G
	confirm("Reserve %s?" % s.name, "%s is placed in reserve: it costs 1 SUP and 1 FUEL less to build, but it cannot be used until you unreserve it at Earth or a base with a Supply Station." % s.name, func(): return E.setReserve(G, s), "Reserve")

func scrap_ask(s) -> void:
	var G = Game.G
	var sv = E.scrapValue(G, s)
	var body: String
	if sv != null:
		body = "%s is scrapped at %s. You recover half the cost, rounded up: %s." % [s.name, "Earth" if sv.site.where == "earth" else E._baseById(G, sv.site.where).name, E.resTxt(sv.back)]
		if E.sum(s.cargo): body += "\nIts cargo (%s) is unloaded there." % E.resTxt(s.cargo)
	else:
		body = "%s is not at Earth or one of your bases that can scrap it (or it is a damaged crew vehicle), so it is %s and nothing is recovered." % [s.name, "decommissioned" if s.cls == "CV" else "destroyed"]
		if E.sum(s.cargo): body += "\nIts cargo (%s) is lost." % E.resTxt(s.cargo)
	confirm("Scrap %s?" % s.name, body + "\n\nThis cannot be undone.", func(): return E.scrap(G, s), "Scrap")

## stocked launch vehicles on Earth and at bases can be scrapped for half their cost (rounded up)
func lv_scrap_row(box) -> void:
	var G = Game.G
	var f := UIK.flow(box)
	var any := false
	for where in G.lv.keys():
		var st = G.lv[where]
		for z in [1, 2, 3, 4]:
			if int(SHRules.gi(st, z, 0)) < 1: continue
			any = true
			var back := E.halfOf({"ORE": 1, "FUEL": z})
			var nm: String = "Earth" if where == "earth" else (E._baseById(G, where).name if E._baseById(G, where) != null else String(where))
			UIK.button(f, "Scrap LV-%d at %s" % [z, nm], func(): confirm("Scrap LV-%d?" % z, "The launch vehicle at %s is scrapped. You recover half the cost, rounded up: %s. Its counter is free again." % [nm, E.resTxt(back)], func(): return E.scrapLV(G, where, z), "Scrap"), false, "Recover " + E.resTxt(back))
	if not any: f.queue_free()

# ---------------- confirmation and choice dialogs ----------------
func _make_modal() -> void:
	modal = ColorRect.new()
	modal.color = Color(0, 0, 0, 0.55)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(540, 0)
	cc.add_child(pc)
	modal_box = VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 10)
	pc.add_child(modal_box)

## a small dialog: title, text, and an OK button running fn (it may return an error text); fn null = just close
func confirm(title: String, body: String, fn, ok_text := "OK") -> void:
	var opts := [[ok_text, fn]]
	if fn != null: opts.append(["Cancel", null])
	choose(title, body, opts)

## a dialog with several choices: opts = [[label, Callable or null]]
func choose(title: String, body: String, opts: Array) -> void:
	UIK.clear(modal_box)
	UIK.title(modal_box, title)
	UIK.para(modal_box, body, null, 14, 400)
	var f := UIK.flow(modal_box)
	_modal_enter = Callable()
	for o in opts:
		var cb = o[1]
		var run := func():
			modal.visible = false
			if cb != null: Game.roll_act(cb)
		UIK.button(f, o[0], run)
		if not _modal_enter.is_valid(): _modal_enter = run
	modal.visible = true

## the explore confirmation, and the result of the last roll
func show_explore(G, s, o) -> void:
	UIK.clear(modal_box)
	_modal_enter = func():
		modal.visible = false
		Game.roll_act(func(): return E.explore(G, s, o), true)
	SHScreens.explore_confirm(self, modal_box, G, s, o)
	modal.visible = true
func show_roll() -> void:
	var L = Game.G.get("lastRoll") if Game.G != null else null
	if not (L is Dictionary): return
	UIK.clear(modal_box)
	_modal_enter = func(): modal.visible = false
	SHScreens.roll_result(self, modal_box, L)
	modal.visible = true

# ---------------- Log tab ----------------
func _log_col(c):
	match c:
		"g": return UIK.GOOD
		"x": return UIK.BAD
		"h": return UIK.AMBER
		"e": return UIK.CYAN
		"bot": return Color("#b39ddb")
	return null
var _log_filter := "all"
const LOG_FILTERS := [["all", "All"], ["mine", "Yours"], ["bots", "Bots"], ["key", "Highlights"]]
var _log_btns := {}
var _log_search: LineEdit

## filter buttons and a search box above the log text
func _make_log_filter() -> void:
	var sc := log_text.get_parent()
	sc.remove_child(log_text)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	var f := UIK.flow(v)
	var grp := ButtonGroup.new()
	for lf in LOG_FILTERS:
		var b := Button.new()
		b.text = lf[1]
		b.toggle_mode = true
		b.button_group = grp
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = lf[0] == _log_filter
		var key: String = lf[0]
		b.pressed.connect(func():
			_log_filter = key
			build_log())
		f.add_child(b)
		_log_btns[key] = b
	_log_search = LineEdit.new()
	_log_search.placeholder_text = "Search the log"
	_log_search.clear_button_enabled = true
	_log_search.text_changed.connect(func(_t): build_log())
	v.add_child(_log_search)
	v.add_child(log_text)

func _log_keep(l: Dictionary) -> bool:
	var c = l.get("c", "")
	match _log_filter:
		"mine": if c == "bot": return false
		"bots": if c != "bot": return false
		"key": if not (c in ["g", "x", "h", "e"]): return false
	var q: String = _log_search.text.strip_edges().to_lower() if _log_search != null else ""
	return q == "" or String(l.t).to_lower().contains(q)

func build_log() -> void:
	var G = Game.G
	if G == null: return
	var lines := []
	for l in G.log:
		if not _log_keep(l): continue
		var col = _log_col(l.c)
		var t: String = String(l.t).replace("[", "[lb]")
		lines.append(("[color=#%s]%s[/color]" % [col.to_html(false), t]) if col != null else t)
		if lines.size() >= 300: break
	log_text.text = "\n".join(lines) if lines.size() else "[color=#b8896a]No log lines match.[/color]"

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
	_fit_dialog.call_deferred()
	var screen: bool = a.k in ["search", "battle", "pbattle", "assign"]
	dialog.custom_minimum_size.x = 720 if screen or a.k == "basehit" else 0
	if not screen: UIK.para(dialog_box, a.get("text", ""))
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
		"search": SHScreens.search(dialog_box, a)
		"pbattle": SHScreens.pirate(dialog_box, a)
		"assign": SHScreens.assign(dialog_box, a)
		"basehit": SHScreens.basehit(dialog_box, a)
		"battle": SHScreens.battle(dialog_box, a)
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

## size the question dialog to its contents, centred over the map (left of the side panel)
func _fit_dialog() -> void:
	if not dialog.visible: return
	var w: float = maxf(dialog.get_combined_minimum_size().x, 560.0)
	dialog.offset_left = -230.0 - w / 2.0
	dialog.offset_right = -230.0 + w / 2.0
	dialog.offset_top = -60.0
	dialog.offset_bottom = 60.0
	# rich text measures its height only once it has a width: wait for the layout, then fit the height
	await get_tree().process_frame
	await get_tree().process_frame
	if not dialog.visible: return
	var h: float = dialog.get_combined_minimum_size().y
	dialog.offset_top = -h / 2.0
	dialog.offset_bottom = h / 2.0

func _ask_title(a: Dictionary) -> String:
	match a.k:
		"pirate": return "Pirate!"
		"intercept": return "Interception"
		"surrender": return "Surrender offered"
		"search": return "Search"
		"pbattle": return "Combat with the pirate"
		"battle": return "Combat with " + str(a.get("foe", "the enemy"))
		"assign": return "Assign the damage"
		"basehit": return "Base hit"
		"card": return "World card"
		"flyby": return "Flyby transfer"
		"publicity": return "Publicity Campaign"
		"immigration": return "Immigration"
		"mission": return "Too many missions"
	return "Decision"

# ---------------- menus ----------------
var title: TitleScene
var dev: DevConsole
var _menu_from := "start"

func _title_action(k: String) -> void:
	match k:
		"new": show_menu("start")
		"load":
			_menu_from = "title"
			show_menu("load")
		"settings":
			_menu_from = "title"
			show_menu("settings")
		"quit": Game.quit()

func show_menu(mode: String) -> void:
	if mode == "title" and Game.G != null: mode = "pause"
	if mode == "title":
		_menu_from = "title"
		menu.visible = false
		modal.visible = false
		fboard.visible = false
		ttree.visible = false
		title.visible = true
		return
	# behind the menus the title picture stays visible until a campaign is running
	title.visible = Game.G == null
	menu.color.a = 0.82 if Game.G == null else 0.94
	menu.visible = true
	modal.visible = false
	fboard.visible = false
	ttree.visible = false
	UIK.clear(menu_box)
	if mode == "start" or mode == "pause": _menu_from = mode
	match mode:
		"load", "save": return _slots_menu(mode)
		"settings": return _settings_menu()
	UIK.title(menu_box, "Stellar Horizons", 34)
	if mode == "pause":
		UIK.para(menu_box, "Campaign paused: %s, %d." % [D.FAC[Game.G.f].n, int(Game.G.y)], UIK.DIM)
		var col := UIK.vbox(menu_box, 8)
		for it in [["Resume", func(): _close_menu()], ["Save game", func(): show_menu("save")], ["Load game", func(): show_menu("load")],
				["Settings", func(): show_menu("settings")], ["Developer console", func():
					_close_menu()
					dev.open()], ["New campaign", func(): show_menu("start")], ["Quit", func(): Game.quit()]]:
			var b := UIK.button(col, it[0], it[1], it[0] == "Load game" and not Game.any_slot())
			b.custom_minimum_size = Vector2(260, 40)
		return
	UIK.para(menu_box, "Lead a space program from 2030: explore the solar system, found bases and grow settlements.", UIK.DIM)
	UIK.head(menu_box, "Your faction")
	var f := UIK.flow(menu_box)
	for k in D.FAC_ORDER:
		var vs: Array = ["mil", "rob"] if k == "cn" else [""]
		for vv in vs:
			var lbl: String = D.FAC[k].n + ((" · " + D.FAC[k].variants[vv].n) if vv != "" else "")
			var b := UIK.button(f, lbl, func():
				_setup.f = k
				if vv != "": _setup.variant = vv
				_setup.botset = (_setup.botset as Array).filter(func(x): return x != k)
				_setup.bots = _setup.botset.size() > 0
				show_menu("start"))
			b.add_theme_color_override("font_color", Color(D.FAC[k].c).lightened(0.25))
			if _setup.f == k and (vv == "" or _setup.variant == vv): b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover"))
	if _setup.f == "cn": UIK.para(menu_box, D.FAC.cn.variants[_setup.variant].d, UIK.DIM, 13)
	UIK.para(menu_box, D.FAC[_setup.f].ab, UIK.DIM, 13)
	var opts := UIK.flow(menu_box)
	var others: Array = D.FAC_ORDER.filter(func(x): return x != _setup.f)
	var cnt := UIK.pick(opts, range(others.size() + 1).map(func(i): return "No bots (solo)" if i == 0 else "%d bot%s" % [i, "" if i == 1 else "s"]), (_setup.botset as Array).size())
	cnt.item_selected.connect(func(i):
		var cur: Array = (_setup.botset as Array).filter(func(x): return x in others)
		while cur.size() > i: cur.pop_back()
		for k in others:
			if cur.size() >= i: break
			if not k in cur: cur.append(k)
		_setup.botset = cur
		_setup.bots = cur.size() > 0
		show_menu("start"))
	var scen := UIK.pick(opts, ["Standard campaign (2030)", "Futuristic start (2060)"], 1 if _setup.scenario == "fut2060" else 0)
	scen.item_selected.connect(func(i): _setup.scenario = "fut2060" if i == 1 else "std")
	UIK.head(menu_box, "Bots: tick the factions that play as bots")
	for k in others:
		var row := UIK.hbox(menu_box, 8)
		var ck := CheckBox.new()
		ck.text = D.FAC[k].n
		ck.button_pressed = k in _setup.botset
		ck.add_theme_color_override("font_color", Color(D.FAC[k].c).lightened(0.25))
		ck.custom_minimum_size.x = 150
		ck.toggled.connect(func(on):
			var cur: Array = _setup.botset
			if on and not k in cur: cur.append(k)
			if not on: cur.erase(k)
			_setup.bots = cur.size() > 0
			show_menu("start"))
		row.add_child(ck)
		if k == "cn":
			var vp := UIK.pick(row, ["Military", "Robotic"], 1 if _setup.cnbot == "rob" else 0)
			vp.item_selected.connect(func(i): _setup.cnbot = "rob" if i == 1 else "mil")
		UIK.para(row, _bot_blurb(k), UIK.DIM, 12, 520)
	var on: Array = []
	for k in [["rerolls", "engine rerolls"], ["enhTrade", "enhanced trading"]]:
		if Game.settings[k[0]]: on.append(k[1])
	UIK.para(menu_box, "Optional rules: " + (", ".join(on) if on.size() else "none") + " (change them in Settings).", UIK.DIM, 13)
	var go := UIK.flow(menu_box)
	var start := UIK.button(go, "Start campaign", func(): _start())
	start.custom_minimum_size = Vector2(220, 44)
	if Game.has_slot(0): UIK.button(go, "Continue (autosave)", func(): _load(0))
	UIK.button(go, "Load game", func(): show_menu("load"), not Game.any_slot())
	UIK.button(go, "Settings", func(): show_menu("settings"))
	if Game.G != null: UIK.button(go, "Back", func(): _close_menu())
	else: UIK.button(go, "Title screen", func(): show_menu("title"))
	UIK.button(go, "Quit", func(): Game.quit())

func _bot_blurb(f: String) -> String:
	match f:
		"na": return "Versatile: strong robots and crews, leans robotic; explores Engineering and Biology worlds."
		"ru": return "Crewed-vehicle power: Biology worlds like Mars, Europa and Titan, bases and crew technology."
		"eu": return "Robotics and telescopes; Physics research; trades with other factions."
		"jp": return "Robotic explorers; Engineering worlds and the component-design / computing line."
		"cn": return "Military China (embargoes rivals, builds armed ships, hunts pirates) or, with the robotic policy, peaceful and focused on bases."
		"as": return "Base builder: many cheap crew vehicles, mining bases and Biology research."
		"sa": return "Versatile; bases kept stocked by cargo flights; diplomacy and trade."
	return ""

func _close_menu() -> void:
	menu.visible = false
	_sync_fboard()

func _menu_back() -> void: show_menu(_menu_from)

## export every save slot to one file, or import such a file (so saves can move between computers)
var _fd: FileDialog
func _file_dialog(export: bool) -> void:
	if _fd == null:
		_fd = FileDialog.new()
		_fd.use_native_dialog = true
		_fd.access = FileDialog.ACCESS_FILESYSTEM
		_fd.filters = PackedStringArray(["*.json ; Stellar Horizons saves"])
		add_child(_fd)
		_fd.file_selected.connect(func(path: String):
			if _fd.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
				show_toast("Saves exported." if Game.export_saves(path) else "Could not write that file.")
			else:
				show_toast(Game.import_saves(path))
			show_menu("load"))
	_fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE if export else FileDialog.FILE_MODE_OPEN_FILE
	_fd.title = "Export saves" if export else "Import saves"
	_fd.current_file = "stellar-horizons-saves.json" if export else ""
	_fd.popup_centered_ratio(0.6)

## the save slots: autosave plus three manual slots
func _slots_menu(mode: String) -> void:
	UIK.title(menu_box, "Save game" if mode == "save" else "Load game", 28)
	UIK.para(menu_box, ("Choose a slot. The autosave is written each time you press Next and when you quit." if mode == "save" else "Pick a saved campaign. The autosave is written each time you press Next."), UIK.DIM, 13, 460)
	for i in Game.SLOTS.size():
		if mode == "save" and i == 0: continue
		var c := UIK.card(menu_box)
		var h := UIK.hbox(c, 10)
		var v := UIK.vbox(h, 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.rich(v, "[b]%s[/b]" % Game.slot_name(i), 15)
		UIK.para(v, Game.slot_info(i), UIK.DIM, 12, 0)
		var has := Game.has_slot(i)
		if mode == "save":
			UIK.button(h, "Overwrite" if has else "Save", func():
				var ok := Game.save_slot(i)
				show_toast(("Saved to %s." % Game.slot_name(i)) if ok else "Could not save.")
				show_menu("save"))
		else:
			UIK.button(h, "Load", func(): _load(i), not has)
		if has and i > 0:
			var del: Button
			del = UIK.button(h, "Delete", func():
				if del.text == "Delete":
					del.text = "Click again to delete"
					return
				Game.delete_slot(i)
				show_menu(mode))
	UIK.para(menu_box, "Saves are kept in " + ProjectSettings.globalize_path("user://"), UIK.DIM, 12, 460)
	var bar := UIK.flow(menu_box)
	if mode == "load":
		UIK.button(bar, "Export saves…", func(): _file_dialog(true), not Game.any_slot())
		UIK.button(bar, "Import saves…", func(): _file_dialog(false))
	UIK.button(bar, "Back", func(): _menu_back())

func _settings_menu() -> void:
	UIK.title(menu_box, "Settings", 28)
	var rows := [
		["confirmNext", "Confirm before Next", "Ask before ending a phase or step, and list what you have not used yet."],
		["autosave", "Autosave", "Save the campaign to the autosave slot each time you press Next."],
		["anim", "Animated board", "Spinning planets, drifting stars, the sun's corona, glowing exploration boxes and rolling dice."],
		["rerolls", "Improved engine reliability", "Optional rule: two engine-failure rerolls per campaign (applies to new games)."],
		["enhTrade", "Enhanced trading", "Optional rule: a trade marker at a non-player faction's base stays until every faction in play has traded there once; markers still there in the next economic phase are replaced (applies to new games, loaded saves%s)." % (" and this one" if Game.G != null else "")]]
	for r in rows:
		var c := UIK.card(menu_box)
		var h := UIK.hbox(c, 12)
		var v := UIK.vbox(h, 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.rich(v, "[b]%s[/b]" % r[1], 15)
		UIK.para(v, r[2], UIK.DIM, 12, 380)
		var cb := CheckButton.new()
		cb.button_pressed = Game.settings[r[0]]
		cb.focus_mode = Control.FOCUS_NONE
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = r[0]
		cb.toggled.connect(func(on): Game.set_setting(key, on))
		h.add_child(cb)
	for r in [["sfxVol", "Sound effects"], ["musicVol", "Music"]]:
		var c := UIK.card(menu_box)
		var h := UIK.hbox(c, 12)
		var l := UIK.rich(h, "[b]%s[/b]" % r[1], 15)
		l.custom_minimum_size.x = 160
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Game.settings[r[0]]
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.focus_mode = Control.FOCUS_NONE
		var key: String = r[0]
		sl.value_changed.connect(func(v):
			Game.set_setting(key, v)
			sfx.apply_volumes()
			if key == "sfxVol": sfx.play("select"))
		h.add_child(sl)
	UIK.button(UIK.flow(menu_box), "Back", func(): _menu_back())

func _load(i := 0) -> void:
	if not Game.load_slot(i): show_toast("Could not load that saved campaign.")

func _start() -> void:
	var opts := {"scenario": _setup.scenario, "variant": _setup.variant}
	var bots := []
	if _setup.bots:
		for k in D.FAC_ORDER:
			if k != _setup.f and k in _setup.botset: bots.append({"f": k, "variant": _setup.cnbot} if k == "cn" else {"f": k})
	Game.new_campaign(_setup.f, opts, bots)
