## The fleet hangar: every robotic explorer and crew vehicle of every faction as a 3D model on a turntable.
## Drag to orbit, wheel to zoom, double-click to reset. Opened from the pause menu or a ship's panel.
extends Control

var main: Node
var D: Dictionary
var UN: Dictionary

var fac := "na"
var kind_filter := "All"
var query := ""
var cur_key := ""
var spin := true
var yaw := 0.6
var pitch := -0.25
var dist := 2.9
var radius := 1.0

var list: ItemList
var info: RichTextLabel
var title_l: Label
var sub_l: Label
var svp: SubViewport
var pivot: Node3D
var cam: Camera3D
var model: Node3D
var fac_row: HFlowContainer
var kind_pick: OptionButton
var keys: Array = []
var _drag := false

func _ready() -> void:
	D = Game.data.D
	UN = Game.data.UNITS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#0a0a0b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	# left column: faction chips, kind filter, search, list
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 340
	row.add_child(left)
	var lv := UIK.vbox(left, 8)
	UIK.title(lv, "Fleet hangar", 20)
	UIK.para(lv, "Every robotic explorer and crew vehicle, in each faction's colours.", UIK.DIM, 12, 0)
	fac_row = HFlowContainer.new()
	fac_row.add_theme_constant_override("h_separation", 4)
	fac_row.add_theme_constant_override("v_separation", 4)
	lv.add_child(fac_row)
	for k in D.FAC_ORDER:
		var b := Button.new()
		b.text = D.FAC[k].pre
		b.tooltip_text = D.FAC[k].n
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): set_faction(k))
		b.set_meta("k", k)
		fac_row.add_child(b)
	var fr := UIK.hbox(lv, 6)
	kind_pick = UIK.pick(fr, ["All", "Robotic explorers", "Crew vehicles", "Probe", "Rover", "Flyby", "Orbiter", "Telescope", "CV-2", "CV-3", "CV-4", "CV-5", "CV-6", "CV-7", "CV-8", "CV-9"])
	kind_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind_pick.item_selected.connect(func(i): kind_filter = kind_pick.get_item_text(i); _fill())
	var se := LineEdit.new()
	se.placeholder_text = "Search units"
	se.clear_button_enabled = true
	se.text_changed.connect(func(t): query = t.strip_edges().to_lower(); _fill())
	lv.add_child(se)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(i): show_unit(keys[i]))
	lv.add_child(list)
	UIK.button(lv, "Back to the game", func(): close())
	# right: the 3D stage with a caption overlay
	var stage := SubViewportContainer.new()
	stage.stretch = true
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.gui_input.connect(_stage_input)
	row.add_child(stage)
	svp = SubViewport.new()
	svp.own_world_3d = true
	svp.msaa_3d = Viewport.MSAA_4X
	svp.transparent_bg = false
	stage.add_child(svp)
	_build_world()
	var cap := VBoxContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.position = Vector2(24, 18)
	stage.add_child(cap)
	title_l = Label.new()
	title_l.add_theme_font_size_override("font_size", 30)
	title_l.add_theme_font_override("font", load("res://assets/fonts/ksp_head.tres"))
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(title_l)
	sub_l = Label.new()
	sub_l.add_theme_color_override("font_color", UIK.DIM)
	sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(sub_l)
	var box := PanelContainer.new()
	box.anchor_left = 0.0
	box.anchor_top = 1.0
	box.anchor_right = 0.0
	box.anchor_bottom = 1.0
	box.offset_left = 24
	box.offset_top = -126
	box.offset_right = 520
	box.offset_bottom = -20
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(box)
	info = UIK.rich(box, "", 14)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := Label.new()
	hint.text = "Drag to rotate · wheel to zoom · double-click to reset"
	hint.add_theme_color_override("font_color", UIK.DIM)
	hint.add_theme_font_size_override("font_size", 12)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -430
	hint.offset_top = -34
	hint.offset_right = -18
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage.add_child(hint)
	var sp := CheckButton.new()
	sp.text = "Spin"
	sp.button_pressed = true
	sp.focus_mode = Control.FOCUS_NONE
	sp.toggled.connect(func(v): spin = v)
	sp.anchor_left = 1.0
	sp.anchor_right = 1.0
	sp.offset_left = -110
	sp.offset_top = 14
	sp.offset_right = -16
	stage.add_child(sp)

func _build_world() -> void:
	var w := Node3D.new()
	svp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky_pano.png")
	pm.energy_multiplier = 0.8
	sky.sky_material = pm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a7aa8")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 2.4
	key.light_color = Color("#fff4e0")
	key.rotation = Vector3(-0.7, 0.8, 0)
	w.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.6
	fill.light_color = Color("#8fa8ff")
	fill.rotation = Vector3(-0.2, -2.4, 0)
	w.add_child(fill)
	pivot = Node3D.new()
	w.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 38
	cam.far = 500
	w.add_child(cam)
	_cam()

func _cam() -> void:
	if cam == null: return
	cam.position = Vector3(0, 0, dist * radius).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, 0.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)

func open(f := "", key := "") -> void:
	if f != "": fac = f
	visible = true
	_fill()
	if key != "" and keys.has(key): list.select(keys.find(key)); show_unit(key)
	elif cur_key == "" or not keys.has(cur_key): if keys.size(): list.select(0); show_unit(keys[0])
	elif keys.has(cur_key): list.select(keys.find(cur_key))

func close() -> void:
	visible = false

func set_faction(k: String) -> void:
	fac = k
	cur_key = ""
	_fill()
	if keys.size():
		list.select(0)
		show_unit(keys[0])

func _kind_ok(k: String) -> bool:
	match kind_filter:
		"All": return true
		"Robotic explorers": return UnitModels.RE_KINDS.has(k)
		"Crew vehicles": return k.begins_with("CV-")
		_: return k == kind_filter

func _fill() -> void:
	for b in fac_row.get_children():
		b.button_pressed = b.get_meta("k") == fac
		b.add_theme_color_override("font_color", Color(D.FAC[b.get_meta("k")].c).lightened(0.25))
	list.clear()
	keys = []
	var order: Array = UnitModels.RE_KINDS + ["CV-2", "CV-3", "CV-4", "CV-5", "CV-6", "CV-7", "CV-8", "CV-9"]
	var all: Array = []
	for k in UN:
		if not k.begins_with(fac + "|"): continue
		var u: Dictionary = UN[k]
		if not _kind_ok(u.k): continue
		if query != "" and not (u.n.to_lower().contains(query) or u.k.to_lower().contains(query)): continue
		all.append(k)
	all.sort_custom(func(a, b):
		var ia: int = order.find(UN[a].k)
		var ib: int = order.find(UN[b].k)
		return ia < ib or (ia == ib and UN[a].n < UN[b].n))
	for k in all:
		keys.append(k)
		list.add_item("%s   %s" % [UN[k].n, UN[k].k])
	if cur_key != "" and keys.has(cur_key): list.select(keys.find(cur_key))

func show_unit(key: String) -> void:
	cur_key = key
	var u: Dictionary = UN[key]
	var f: String = key.split("|")[0]
	fac = f
	if model != null:
		pivot.remove_child(model)
		model.queue_free()
	model = UnitModels.build(f, u.n, u.k)
	pivot.add_child(model)
	radius = model.get_meta("radius")
	dist = 2.9
	yaw = 0.6
	pitch = -0.22
	pivot.rotation = Vector3(0, yaw, 0)
	_cam()
	title_l.text = u.n
	title_l.add_theme_color_override("font_color", Color(D.FAC[f].c).lightened(0.3))
	var kind_txt: String = ("Crew vehicle %s" % u.k) if u.k.begins_with("CV-") else u.k
	sub_l.text = "%s · %s" % [D.FAC[f].n, kind_txt]
	var bits := []
	bits.append("Search %d" % int(u.ev))
	if u.spec: bits.append("spectrometer")
	if u.lab: bits.append("laboratory")
	if int(u.cargo) > 0: bits.append("cargo %d" % int(u.cargo))
	if int(u.cb) > 0: bits.append("combat %d" % int(u.cb))
	if u.prod: bits.append("produces resources")
	if int(u.dr) > 0: bits.append("drill %d" % int(u.dr))
	info.text = "Cost  %s\n%s" % [UIK.res_bb({"ORE": u.ore, "SUP": u.sup, "FUEL": u.fuel}), " · ".join(bits)]
	for i in keys.size():
		if keys[i] == key: list.select(i)

func _stage_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			if e.pressed and e.double_click:
				yaw = 0.6
				pitch = -0.22
				dist = 2.9
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: dist = clampf(dist * 0.9, 1.5, 9.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: dist = clampf(dist * 1.1, 1.5, 9.0)
	elif e is InputEventMouseMotion and _drag:
		yaw += e.relative.x * 0.01
		pitch = clampf(pitch - e.relative.y * 0.008, -1.3, 1.3)
	_cam()

func _process(dt: float) -> void:
	if not visible or pivot == null: return
	if spin and not _drag: yaw += dt * 0.35
	pivot.rotation = Vector3(0, yaw, 0)
	_cam()
