## The technology tree and the policy tree, shown over the map while the Tech or Policy tab is open.
## Tech cards sit on the printed chart's grid (data TECH_POS) with prerequisite lines; click a card to develop it.
extends Control

const LAB := 64.0
const CW := 178.0
const CH := 92.0
const GX := 30.0
const GY := 16.0
const PAD := 14.0
## the web version's chart look (dark take on the printed Technology Tree)
const INK := Color("#dfe7ee")
const WDIM := Color("#8ea1b3")
const OK := Color("#5fcf8a")
const BEACON := Color("#f2a93b")
const LINE := Color("#263a50")
const LINE_COL := {"Bio": Color("#a9bd52"), "Phy": Color("#5ea4f2"), "Eng": Color("#c3ccd6")}
const LINE_OFF := Color("#3a4a5c")
const BAND_G := {"Bio": ["#1f2a12", "#141b0e", "#10150c"], "Phy": ["#13223a", "#0e1829", "#0b1320"], "Eng": ["#22262c", "#191c21", "#131619"]}
const LABEL_COL := {"Bio": Color("#b5c46a"), "Phy": Color("#7fb2f0"), "Eng": Color("#b9c2cc")}
const BADGE_COL := {"Bio": Color("#6f7d2c"), "Phy": Color("#2f69b3"), "Eng": Color("#59626d")}
const F_DISP := "res://assets/fonts/web/jura_bold.tres"
const F_TITLE := "res://assets/fonts/web/jura_title.tres"
const F_BODY := "res://assets/fonts/web/IBMPlexSansCondensed-Regular.ttf"
const F_MONO := "res://assets/fonts/web/IBMPlexMono-Medium.ttf"

var E: SHRules
var D: Dictionary
var main: Node
var mode := "tech"  ## "tech" or "pol"
var top: VBoxContainer
var scroll: ScrollContainer
var canvas: TreeCanvas

## draws the field bands and the prerequisite lines under the cards
class TreeCanvas extends Control:
	var lines: Array = []  ## [{pts: PackedVector2Array, col, w, arrow: Vector2 or null}]
	var bands: Array = []  ## [{rect, f, label, lcol}]
	var bars: Array = []   ## policy chain bars [Rect2]
	var font: Font
	func _draw() -> void:
		for b in bands:
			var r: Rect2 = b.rect
			var g: Array = b.g
			var x1 := r.position.x + r.size.x * 0.4
			draw_polygon(PackedVector2Array([r.position, Vector2(x1, r.position.y), Vector2(x1, r.end.y), Vector2(r.position.x, r.end.y)]), PackedColorArray([Color(g[0]), Color(g[1]), Color(g[1]), Color(g[0])]))
			draw_polygon(PackedVector2Array([Vector2(x1, r.position.y), Vector2(r.end.x, r.position.y), r.end, Vector2(x1, r.end.y)]), PackedColorArray([Color(g[1]), Color(g[2]), Color(g[2]), Color(g[1])]))
			if b.top: draw_line(r.position, Vector2(r.end.x, r.position.y), Color("#2a3a4c"), 1.0)
			var lr: Rect2 = b.lrect
			draw_set_transform(Vector2(lr.position.x + lr.size.x / 2 + 10, lr.position.y + lr.size.y / 2), -PI / 2)
			var w := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string(font, Vector2(-w / 2, 0), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, b.lcol)
			draw_set_transform(Vector2.ZERO)
		for r in bars:
			draw_rect(r, Color(0.106, 0.165, 0.235, 0.8))
			draw_rect(Rect2(r.position + Vector2(r.size.x / 2, 0), Vector2(r.size.x / 2, r.size.y)), Color(0.133, 0.204, 0.290, 0.8))
		for l in lines:
			draw_polyline(l.pts, l.col, l.w, true)
			if l.arrow != null:
				var e: Vector2 = l.arrow
				draw_colored_polygon(PackedVector2Array([e + Vector2(-7, -4.5), e, e + Vector2(-7, 4.5)]), l.col)

func _ready() -> void:
	E = Game.E
	D = Game.data.D
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#070b11")
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	var tp := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.027, 0.043, 0.067, 0.92)
	tsb.border_color = LINE
	tsb.border_width_bottom = 1
	tsb.content_margin_left = 16
	tsb.content_margin_right = 16
	tsb.content_margin_top = 10
	tsb.content_margin_bottom = 10
	tp.add_theme_stylebox_override("panel", tsb)
	v.add_child(tp)
	top = VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	tp.add_child(top)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	canvas = TreeCanvas.new()
	canvas.font = load(F_DISP)
	scroll.add_child(canvas)

func refresh() -> void:
	if Game.G == null or not visible: return
	var sx := scroll.scroll_horizontal
	var sy := scroll.scroll_vertical
	UIK.clear(top)
	for c in canvas.get_children():
		canvas.remove_child(c)
		c.queue_free()
	canvas.bars = []
	if mode == "pol": _build_pol(Game.G)
	else: _build_tech(Game.G)
	canvas.queue_redraw()
	await get_tree().process_frame
	scroll.scroll_horizontal = sx
	scroll.scroll_vertical = sy

# ---------------- shared bits ----------------
func _card_style(border: Color, bg: Color, width := 1, glow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_color = Color(0.949, 0.663, 0.231, 0.35) if glow else Color(0, 0, 0, 0.5)
	s.shadow_size = 7 if glow else 4
	s.shadow_offset = Vector2(0, 0) if glow else Vector2(0, 2)
	return s

func _card(rect: Rect2, border: Color, bg: Color, dim: bool, on_click: Callable, glow := false) -> VBoxContainer:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	var w := 2 if glow else 1
	b.add_theme_stylebox_override("normal", _card_style(border, bg, w, glow))
	b.add_theme_stylebox_override("hover", _card_style(Color("#4fc3d9"), bg, 1, false))
	b.add_theme_stylebox_override("pressed", _card_style(BEACON, bg, 1, false))
	b.modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE
	b.pressed.connect(on_click)
	canvas.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 8)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 6)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	return v

## text in the web's body font (or Jura for names, IBM Plex Mono for numbers)
func _lbl(box: Node, txt: String, size: int, col: Color, bold := false, wrap := true, font := "") -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", load(font if font != "" else (F_DISP if bold else F_BODY)))
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(l)
	return l

func _tags(box: Node, facs: Array) -> void:
	if not facs.size(): return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_child(h)
	for f in facs:
		var p := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(D.FAC[f].c)
		s.set_corner_radius_all(2)
		s.content_margin_left = 3
		s.content_margin_right = 3
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		p.add_theme_stylebox_override("panel", s)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.tooltip_text = D.FAC[f].n
		h.add_child(p)
		var l := _lbl(p, D.FAC[f].pre, 9, Color.WHITE, false, false, F_MONO)
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

## the web's "key" swatch: a small outlined rounded rectangle and a dim caption
func _key(box: Node, txt: String, col: Color, fade := 1.0) -> void:
	var h := UIK.hbox(box, 5)
	var sw := Panel.new()
	sw.custom_minimum_size = Vector2(14, 10)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(col.r, col.g, col.b, fade)
	s.set_border_width_all(2)
	s.set_corner_radius_all(2)
	sw.add_theme_stylebox_override("panel", s)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var l := _lbl(h, txt, 13, WDIM, false, false)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

# ---------------- research turns ----------------
func rt_info(G):
	if G.world == null or G.estep != "tech" or G.phase != "econ": return null
	var rt := E.techRT(G.world)
	var cur = E.techTurn(G.world)
	return {"round": rt.round, "cur": cur, "mine": cur == G.f, "passed": SHRules.t(rt.passed.get(G.f)), "seq": rt.seq, "done": rt.passed}

func rt_status_bb(G) -> String:
	var r = rt_info(G)
	if r == null: return ""
	var seq := []
	for f in r.seq:
		var t: String = "[color=#%s]%s[/color]" % [Color(D.FAC[f].c).to_html(false), D.FAC[f].pre]
		if SHRules.t(r.done.get(f)): t = "[s]" + t + "[/s]"
		seq.append(t)
	var st: String
	if r.passed: st = "You passed this decade."
	elif r.mine: st = "[b]Your turn:[/b] develop one technology or pass."
	elif r.cur != null: st = D.FAC[r.cur].n + " is researching."
	else: st = "Everyone has passed."
	return "Research round %d · %s · %s" % [r.round, " → ".join(seq), st]

func develop(k: String):
	var e = E.develop(Game.G, k)
	if e == null and Game.G.world != null: Game.AI.techLoop(Game.G)
	return e

func pass_research() -> void:
	var go := func():
		var e = E.techPass(Game.G)
		if e == null: Game.AI.techLoop(Game.G, {"humanPasses": true})
		return e
	main.confirm("Pass research?", "You develop no more technologies this decade. The other factions keep taking research turns until they pass too.", go, "Pass")

## politics markers to cash or tech points: one slider per target, together at most the markers you hold
func convert_dialog() -> void:
	var G = Game.G
	var n := 3 if E.polLv(G, "dip") >= 3 else 2
	var mx: int = int(G.polm)
	var box: VBoxContainer = main.modal_box
	UIK.clear(box)
	UIK.title(box, "Convert politics markers")
	UIK.para(box, "You hold %d politics marker%s. Each becomes $1B or %d tech points of one field. Together the sliders use at most %d." % [mx, "" if mx == 1 else "s", n, mx], null, 14, 420)
	var T := [["cash", "Cash", 1, "$", "B", null]]
	for f in E.FIELDS: T.append([f, E.FN[f], n, "", " pts", UIK.FIELD_COL[f]])
	var sls := []
	for t in T:
		var sl := UIK.slider(box, t[1], mx, 0, t[5])
		sl.set_meta("k", t[0])
		sls.append(sl)
	var sum := UIK.para(box, "", null, 14, 420)
	var goh := [null]
	var upd := func():
		var tot := 0
		for i in sls.size():
			var v := int(sls[i].value)
			tot += v
			(sls[i].get_meta("tail") as Label).text = ("→ +%s%d%s" % [T[i][3], v * int(T[i][2]), T[i][4]]) if v else ""
		sum.text = ("Converting %d of %d markers; %d left." % [tot, mx, mx - tot]) if tot else "Move a slider to choose."
		if goh[0] != null: goh[0].disabled = tot == 0
	UIK.share_cap(sls, mx, upd)
	var f := UIK.flow(box)
	var run := func():
		main.modal.visible = false
		var err = null
		for sl in sls:
			for i in int(sl.value):
				err = E.convertPolitics(G, sl.get_meta("k"))
				if err != null: break
			if err != null: break
		Game.act(err)
	goh[0] = UIK.button(f, "Convert", run, true)
	UIK.button(f, "Cancel", func(): main.modal.visible = false)
	main._modal_enter = run
	main.modal.visible = true

## every faction's tech bank in this step's turn order (the web version's tech-bank strip)
func facbanks_bb(G) -> String:
	if G.world == null: return ""
	var RT = rt_info(G)
	var order: Array = RT.seq if RT != null else G.world.meta.order
	var parts := []
	for f in order:
		var g = G.world.facs[f]
		var passed: bool = RT != null and SHRules.t(RT.done.get(f))
		var s := "[color=#%s][b]%s%s[/b][/color]" % [Color(D.FAC[f].c).to_html(false), D.FAC[f].pre, " (you)" if f == G.f else ""]
		for x in E.FIELDS: s += " [color=#%s]%s[/color] %d" % [UIK.FIELD_COL[x].to_html(false), x.substr(0, 1), int(g.bank[x])]
		if passed: s += " [i]passed[/i]"
		if RT != null and RT.cur == f: s = "[bgcolor=#1f232c] " + s + " [/bgcolor]"
		if passed: s = "[color=#4c4f5b]" + s + "[/color]"
		parts.append(s)
	return "[color=#a3a7b2]Tech banks%s:[/color]   %s" % [" (turn order)" if RT != null else "", "    ".join(parts)]

# ---------------- technology tree ----------------
func _tpos(k: String) -> Array: return D.TECH_POS[k]
func _box(k: String) -> Rect2:
	var p := _tpos(k)
	return Rect2(LAB + PAD + p[1] * (CW + GX), PAD + p[0] * (CH + GY), CW, CH)

func _build_tech(G) -> void:
	var RT = rt_info(G)
	var can: bool = G.estep == "tech" and (RT == null or (RT.mine and not RT.passed))
	# header (the web's tt-top strip)
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 16)
	h.add_theme_constant_override("v_separation", 6)
	top.add_child(h)
	var ttl := _lbl(h, "TECHNOLOGY TREE", 18, INK, false, false, F_TITLE)
	ttl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for f in E.FIELDS:
		var l := UIK.rich(h, "[color=#%s]%s[/color] [b][font=%s]%d[/font][/b]" % [UIK.FIELD_COL[f].to_html(false), E.FN[f], F_MONO, G.bank[f]], 14)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		l.fit_content = true
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size.x = 118
	if RT != null:
		var rs := UIK.rich(h, rt_status_bb(G), 13)
		rs.custom_minimum_size.x = 420
		if RT.mine and not RT.passed: UIK.button(h, "Pass", func(): pass_research())
	for kk in [["developed", OK, 1.0], ["can develop now", BEACON, 1.0], ["available", Color("#4a6684"), 1.0], ["needs earlier tech", Color("#2b3d52"), 0.55]]: _key(h, kk[0], kk[1], kk[2])
	UIK.button(h, "Back to the map", func(): main.tabs.current_tab = 0)
	var h2 := HFlowContainer.new()
	h2.add_theme_constant_override("h_separation", 6)
	top.add_child(h2)
	_lbl(h2, "Politics markers", 13, INK, false, false).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lbl(h2, str(G.polm), 13, INK, false, false, F_MONO).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UIK.button(h2, "Convert…", func(): convert_dialog(), G.polm < 1)
	var pn := 3 if E.polLv(G, "dip") >= 3 else 2
	_lbl(h2, "1 → $1B or %d tech points · Cash $%dB" % [pn, int(G.cash)], 13, WDIM, false, false).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if G.world != null: _banks(G, RT)
	# layout
	var W := LAB + PAD + 7 * (CW + GX)
	var H := 12 * (CH + GY) + PAD * 2
	canvas.custom_minimum_size = Vector2(W, H)
	canvas.bands = []
	var rowh := CH + GY
	for i in 3:
		var f: String = ["Bio", "Phy", "Eng"][i]
		var y0: float = PAD + i * 4 * rowh - PAD / 2 + (0.0 if i else -PAD / 2)
		canvas.bands.append({"rect": Rect2(0, y0, W, 4 * rowh + (PAD if i == 2 else 0.0)), "g": BAND_G[f], "top": i > 0, "label": E.FN[f].to_upper(), "lcol": LABEL_COL[f], "lrect": Rect2(0, PAD + i * 4 * rowh, LAB, 4 * rowh - GY)})
	# prerequisite lines
	var ins := {}
	var outs := {}
	for t in D.TECH:
		for r in t.r:
			if not ins.has(t.k): ins[t.k] = []
			ins[t.k].append(r)
			if not outs.has(r): outs[r] = []
			outs[r].append(t.k)
	var order_cmp := func(a, b):
		var d: int = _tpos(a)[0] - _tpos(b)[0]
		return d if d != 0 else _tpos(a)[1] - _tpos(b)[1]
	for k in ins: ins[k] = SHRules.ssort(ins[k], order_cmp)
	for k in outs: outs[k] = SHRules.ssort(outs[k], order_cmp)
	var cards := []
	for t in D.TECH: cards.append([t.k, _box(t.k)])
	var hits := func(x0: float, y0: float, x1: float, y1: float, skip: Array) -> bool:
		for c in cards:
			if skip.has(c[0]): continue
			var b: Rect2 = c[1]
			if maxf(x0, x1) > b.position.x - 2 and minf(x0, x1) < b.end.x + 2 and maxf(y0, y1) > b.position.y - 2 and minf(y0, y1) < b.end.y + 2: return true
		return false
	var slot := func(lst: Array, k: String, hh: float) -> float:
		var cnt := lst.size()
		var i := lst.find(k)
		return hh / 2 if cnt < 2 else hh / 2 + (i - (cnt - 1) / 2.0) * minf(14, (hh - 24) / (cnt - 1))
	canvas.lines = []
	for t in D.TECH:
		for rk in t.r:
			var a := _box(rk)
			var b := _box(t.k)
			var lit := SHRules.t(G.tech.get(rk))
			var col: Color = LINE_COL[D.TECHK[rk].f] if lit else LINE_OFF
			var pts := PackedVector2Array()
			var arrow = null
			if _tpos(rk)[1] == _tpos(t.k)[1]:
				var x := a.position.x + a.size.x / 2
				pts = PackedVector2Array([Vector2(x, a.end.y), Vector2(x, b.position.y)])
			else:
				var y0: float = a.position.y + slot.call(outs[rk], t.k, a.size.y)
				var y1: float = b.position.y + slot.call(ins[t.k], rk, b.size.y)
				var x0 := a.end.x
				var x1 := b.position.x
				var g_out: float = x0 + GX / 2 + ((outs[rk].find(t.k) % 3) - 1) * 4
				var g_in: float = x1 - GX / 2 + ((ins[t.k].find(rk) % 3) - 1) * 4
				var skip := [rk, t.k]
				if not hits.call(x0, y0, g_in, y0, skip) and not hits.call(g_in, y0, g_in, y1, skip):
					pts = PackedVector2Array([Vector2(x0, y0), Vector2(g_in, y0), Vector2(g_in, y1), Vector2(x1, y1)])
				elif not hits.call(g_out, y0, g_out, y1, skip) and not hits.call(g_out, y1, x1, y1, skip):
					pts = PackedVector2Array([Vector2(x0, y0), Vector2(g_out, y0), Vector2(g_out, y1), Vector2(x1, y1)])
				else:
					var gy0: float = b.position.y + (-GY / 2 if y1 > y0 else b.size.y + GY / 2)
					pts = PackedVector2Array([Vector2(x0, y0), Vector2(g_out, y0), Vector2(g_out, gy0), Vector2(g_in, gy0), Vector2(g_in, y1), Vector2(x1, y1)])
				arrow = Vector2(x1, y1)
			canvas.lines.append({"pts": pts, "col": col, "w": 2.6 if lit else 2.0, "arrow": arrow})
	# cards
	for t in D.TECH:
		var st := E.techState(G, t)
		var c := E.techCost(G, t)
		var ready: bool = can and st == "open" and G.bank[t.f] >= c
		var holders := E.techHolders(G, t)
		if D.FAC[G.f].get("st", []).has(t.k): holders.append(G.f)
		var border: Color
		match st:
			"have": border = OK
			"open": border = BEACON if ready else Color("#4a6684")
			_: border = Color("#2b3d52")
		var bg := Color("#10201a") if st == "have" else Color("#0f1722")
		var v := _card(_box(t.k), border, bg, st == "locked", func(): _tech_click(t), ready)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(row)
		var nm := RichTextLabel.new()
		nm.bbcode_enabled = true
		nm.fit_content = true
		nm.scroll_active = false
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_override("normal_font", load(F_DISP))
		nm.add_theme_font_size_override("normal_font_size", 13)
		nm.add_theme_color_override("default_color", INK)
		nm.text = t.n + ("  [color=#5fcf8a]✓[/color]" if st == "have" else "")
		row.add_child(nm)
		_badge(row, t, st, c)
		var dl := _lbl(v, t.d, 11, WDIM)
		dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tags(v, holders)

## the round field-coloured cost badge; a discounted cost shows the chart cost struck through
func _badge(row: Node, t: Dictionary, st: String, c: int) -> void:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = BADGE_COL[t.f]
	s.set_corner_radius_all(13)
	s.border_color = Color(1, 1, 1, 0.35)
	s.set_border_width_all(2)
	s.content_margin_left = 3
	s.content_margin_right = 3
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(26, 26)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(p)
	var bx := VBoxContainer.new()
	bx.add_theme_constant_override("separation", -3)
	bx.alignment = BoxContainer.ALIGNMENT_CENTER
	bx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bx)
	if st != "have" and c < t.c:
		var old := RichTextLabel.new()
		old.bbcode_enabled = true
		old.fit_content = true
		old.scroll_active = false
		old.autowrap_mode = TextServer.AUTOWRAP_OFF
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		old.add_theme_font_override("normal_font", load(F_MONO))
		old.add_theme_font_size_override("normal_font_size", 9)
		old.add_theme_color_override("default_color", Color(1, 1, 1, 0.7))
		old.text = "[center][s]%d[/s][/center]" % t.c
		bx.add_child(old)
		p.tooltip_text = "Chart cost %d" % t.c
	var cl := _lbl(bx, "✓" if st == "have" else str(c), 12, Color.WHITE, false, false, F_DISP if st == "have" else F_MONO)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## every faction's tech bank in turn order, as the web's outlined chips
func _banks(G, RT) -> void:
	var order: Array = RT.seq if RT != null else G.world.meta.order
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 4)
	top.add_child(f)
	_lbl(f, "Tech banks%s:" % (" (turn order)" if RT != null else ""), 13, WDIM, false, false).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for fk in order:
		var g = G.world.facs[fk]
		var out: bool = RT != null and SHRules.t(RT.done.get(fk))
		var cur: bool = RT != null and RT.cur == fk
		var pc := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color("#0d1520")
		s.border_color = BEACON if cur else Color("#22344a")
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 2
		s.content_margin_bottom = 2
		pc.add_theme_stylebox_override("panel", s)
		pc.modulate = Color(1, 1, 1, 0.55 if out else 1.0)
		var bb := "[color=#%s][b]%s%s[/b][/color]" % [Color(D.FAC[fk].c).to_html(false), D.FAC[fk].pre, " (you)" if fk == G.f else ""]
		for x in E.FIELDS: bb += " [color=#%s]%s[/color][font=%s]%d[/font]" % [UIK.FIELD_COL[x].to_html(false), x.substr(0, 1), F_MONO, int(g.bank[x])]
		if out: bb += " [i]passed[/i]"
		var rl := UIK.rich(pc, bb, 12)
		rl.fit_content = true
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		f.add_child(pc)

func _tech_click(t: Dictionary) -> void:
	var G = Game.G
	var st := E.techState(G, t)
	var c := E.techCost(G, t)
	var needs := ""
	if t.r.size(): needs = "\nNeeds: " + ", ".join(t.r.map(func(x): return ("✓ " if SHRules.t(G.tech.get(x)) else "✗ ") + D.TECHK[x].n)) + "."
	var body: String = t.d + "." + needs
	if st == "have":
		main.confirm(t.n, body + "\nDeveloped.", null, "OK")
		return
	body += "\nCosts %d %s points (you have %d): %s." % [c, E.FN[t.f], G.bank[t.f], E.techCostTxt(G, t)]
	var RT = rt_info(G)
	if RT != null and (RT.passed or not RT.mine) and st == "open":
		main.confirm(t.n, body + "\n" + ("You passed: no more technologies this decade." if RT.passed else ("Wait for your research turn (%s is researching)." % D.FAC[RT.cur].n if RT.cur != null else "Everyone has passed.")), null, "OK")
		return
	if G.estep != "tech" or st != "open" or G.bank[t.f] < c:
		var why: String = "Technologies are developed in the tech step of the economic phase." if G.estep != "tech" else ("Develop the technologies it needs first." if st != "open" else "Not enough points yet.")
		main.confirm(t.n, body + "\n" + why, null, "OK")
		return
	main.confirm("Develop " + t.n + "?", body, func(): return develop(t.k), "Develop")

# ---------------- policy tree ----------------
func pol_why(G, k: String):
	var lv := E.polLv(G, k)
	if lv >= 3: return "Already Unified."
	if G.estep != "policy": return "Policies are adopted in the policy step of the economic phase (one per decade)."
	if SHRules.t(G.get("policyPicked")): return "You already adopted a policy this decade."
	if lv == 2 and G.pol.values().has(3): return "You can hold only one Unified policy."
	if SHRules._sum(G.pol.values(), func(x): return x) >= 10: return "You already hold 10 policies."
	return null

func _build_pol(G) -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 16)
	h.add_theme_constant_override("v_separation", 6)
	top.add_child(h)
	_lbl(h, "POLICY TREE", 18, INK, false, false, F_TITLE).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lbl(h, "Adopt one policy now." if (G.estep == "policy" and not SHRules.t(G.get("policyPicked"))) else "One policy per decade; each chain goes Basic → Vigorous → Unified.", 13, WDIM, false, false).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for kk in [["held", OK, 1.0], ["can adopt now", BEACON, 1.0], ["next level", Color("#4a6684"), 1.0], ["needs the level before", Color("#2b3d52"), 0.55]]: _key(h, kk[0], kk[1], kk[2])
	UIK.button(h, "Back to the map", func(): main.tabs.current_tab = 0)
	const PW := 250.0
	const PH := 96.0
	const PGX := 64.0
	const PGY := 22.0
	const PP := 24.0
	var W := PP * 2 + 3 * PW + 2 * PGX
	var H: float = PP * 2 + D.POL.size() * (PH + PGY) - PGY + 40
	canvas.custom_minimum_size = Vector2(W, H)
	canvas.bands = []
	canvas.lines = []
	var facs: Array = G.world.facs.values() if G.world != null else [G]
	for r in D.POL.size():
		var p: Dictionary = D.POL[r]
		var y: float = PP + r * (PH + PGY)
		var my := E.polLv(G, p.k)
		var why = pol_why(G, p.k)
		canvas.bars.append(Rect2(PP, y + PH / 2 - 13, W - 2 * PP, 26))
		for c in 3:
			var x := PP + c * (PW + PGX)
			var lv := c + 1
			if c: canvas.lines.append({"pts": PackedVector2Array([Vector2(x - PGX + 10, y + PH / 2), Vector2(x - 6, y + PH / 2)]), "col": Color("#6f8aa8"), "w": 2.0, "arrow": Vector2(x - 2, y + PH / 2)})
			var st := "have" if my >= lv else ("open" if my == c else "locked")
			var ready: bool = st == "open" and why == null
			var border: Color = OK if st == "have" else (BEACON if ready else (Color("#4a6684") if st == "open" else Color("#233244")))
			var v := _card(Rect2(x, y, PW, PH), border, Color("#10201a") if st == "have" else Color("#0f1722"), false, func(): _pol_click(p, lv), ready)
			var lc := Color("#8a6a3a") if st == "locked" else BEACON
			_lbl(v, ["BASIC", "VIGOROUS", "UNIFIED"][c], 10, lc, false, false, F_MONO)
			_lbl(v, D.POL_LV[c] + p.n, 13, Color("#7d8a99") if st == "locked" else INK, true)
			_lbl(v, p.d[c], 11, Color("#5d6a78") if st == "locked" else WDIM).size_flags_vertical = Control.SIZE_EXPAND_FILL
			_tags(v, facs.filter(func(g): return E.polLv(g, p.k) >= lv).map(func(g): return g.f))
	var starts := []
	for k in D.FAC:
		var f: Dictionary = D.FAC[k]
		starts.append(f.n + ": " + ("Military or Robotic" if f.has("variants") else (", ".join(f.pol.map(func(x): return SHRules._find(D.POL, func(q): return q.k == x).n)) if f.pol.size() else "none")))
	var note := Label.new()
	note.text = "Starting policies: " + " · ".join(starts) + ". Tags on a card show every faction in play holding that level."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", WDIM)
	note.add_theme_font_override("font", load(F_BODY))
	note.position = Vector2(PP, H - 34)
	note.size = Vector2(W - 2 * PP, 30)
	canvas.add_child(note)

func _pol_click(p: Dictionary, lv: int) -> void:
	var G = Game.G
	var my := E.polLv(G, p.k)
	var name: String = D.POL_LV[lv - 1] + p.n
	var why = pol_why(G, p.k)
	var d: String = p.d[lv - 1] + "."
	if my >= lv: main.confirm(name, d + "\nHeld.", null, "OK")
	elif my != lv - 1: main.confirm(name, d + "\nAdopt " + D.POL_LV[lv - 2] + p.n + " first.", null, "OK")
	elif why != null: main.confirm(name, d + "\n" + why, null, "OK")
	else: main.confirm("Adopt " + name + "?", d + "\nYou can adopt one policy per decade.", func(): return E.choosePolicy(G, p.k), "Adopt")
