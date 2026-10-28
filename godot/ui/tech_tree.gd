## The technology tree and the policy tree, shown over the map while the Tech or Policy tab is open.
## Tech cards sit on the printed chart's grid (data TECH_POS) with prerequisite lines; click a card to develop it.
extends Control

const LAB := 70.0
const CW := 178.0
const CH := 92.0
const GX := 30.0
const GY := 16.0
const PAD := 14.0
const LINE_COL := {"Bio": Color("#e8702a"), "Phy": Color("#8d89d6"), "Eng": Color("#c7cbd7")}
const BAND_COL := {"Bio": Color(0.910, 0.439, 0.165, 0.06), "Phy": Color(0.718, 0.706, 0.925, 0.06), "Eng": Color(0.803, 0.818, 0.864, 0.05)}

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
	var bands: Array = []  ## [{rect, col, label, lcol}]
	var font: Font
	func _draw() -> void:
		for b in bands:
			draw_rect(b.rect, b.col)
			var r: Rect2 = b.rect
			draw_set_transform(Vector2(r.position.x + 24, r.position.y + r.size.y / 2), -PI / 2)
			var w := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, Vector2(-w / 2, 0), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, b.lcol)
			draw_set_transform(Vector2.ZERO)
		for l in lines:
			draw_polyline(l.pts, l.col, l.w, true)
			if l.arrow != null:
				var e: Vector2 = l.arrow
				draw_colored_polygon(PackedVector2Array([e + Vector2(-8, -5), e, e + Vector2(-8, 5)]), l.col)

func _ready() -> void:
	E = Game.E
	D = Game.data.D
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#161a23")
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var tm := MarginContainer.new()
	for s in ["left", "right", "top"]: tm.add_theme_constant_override("margin_" + s, 14)
	v.add_child(tm)
	top = VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	tm.add_child(top)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	canvas = TreeCanvas.new()
	canvas.font = load("res://assets/fonts/ksp_bold.tres")
	scroll.add_child(canvas)

func refresh() -> void:
	if Game.G == null or not visible: return
	var sx := scroll.scroll_horizontal
	var sy := scroll.scroll_vertical
	UIK.clear(top)
	for c in canvas.get_children():
		canvas.remove_child(c)
		c.queue_free()
	if mode == "pol": _build_pol(Game.G)
	else: _build_tech(Game.G)
	canvas.queue_redraw()
	await get_tree().process_frame
	scroll.scroll_horizontal = sx
	scroll.scroll_vertical = sy

# ---------------- shared bits ----------------
func _card_style(border: Color, bg: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _card(rect: Rect2, border: Color, bg: Color, dim: bool, on_click: Callable) -> VBoxContainer:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _card_style(border, bg))
	b.add_theme_stylebox_override("hover", _card_style(border.lightened(0.3), bg.lightened(0.06)))
	b.add_theme_stylebox_override("pressed", _card_style(UIK.AMBER, bg.lightened(0.1)))
	b.modulate = Color(0.527, 0.542, 0.585, 1) if dim else Color.WHITE
	b.pressed.connect(on_click)
	canvas.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 8)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 5)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	return v

func _lbl(box: Node, txt: String, size: int, col: Color, bold := false, wrap := true) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold: l.add_theme_font_override("font", load("res://assets/fonts/ksp_bold.tres"))
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
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(h)
	for f in facs:
		var p := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(D.FAC[f].c)
		s.set_corner_radius_all(4)
		s.content_margin_left = 4
		s.content_margin_right = 4
		p.add_theme_stylebox_override("panel", s)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size_flags_vertical = Control.SIZE_SHRINK_END
		p.tooltip_text = D.FAC[f].n
		h.add_child(p)
		var l := Label.new()
		l.text = D.FAC[f].pre
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Color("#1b1d2c"))
		p.add_child(l)

func _key(box: Node, txt: String, col: Color) -> void:
	var h := UIK.hbox(box, 4)
	var sw := Panel.new()
	sw.custom_minimum_size = Vector2(14, 14)
	sw.add_theme_stylebox_override("panel", _card_style(col, Color(0.062, 0.062, 0.062, 0)))
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var l := UIK.para(h, txt, UIK.DIM, 12, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF

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
	# header
	var h := UIK.hbox(top, 16)
	UIK.title(h, "Technology Tree", 22).autowrap_mode = TextServer.AUTOWRAP_OFF
	for f in E.FIELDS:
		var l := UIK.rich(h, "[color=#%s]%s[/color] [b]%d[/b]" % [UIK.FIELD_COL[f].to_html(false), E.FN[f], G.bank[f]], 15)
		l.custom_minimum_size.x = 130
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	for kk in [["developed", UIK.GREEN], ["can develop now", UIK.GOLD], ["available", Color("#3c3c4e")], ["needs earlier tech", Color("#232831")]]: _key(h, kk[0], kk[1])
	var h2 := UIK.flow(top)
	UIK.para(h2, "Politics markers %d" % G.polm, null, 14, 0).autowrap_mode = TextServer.AUTOWRAP_OFF
	UIK.button(h2, "Convert…", func(): convert_dialog(), G.polm < 1)
	if RT != null:
		var rs := UIK.rich(h2, rt_status_bb(G), 14)
		rs.custom_minimum_size.x = 520
		if RT.mine and not RT.passed: UIK.button(h2, "Pass", func(): pass_research())
	if G.world != null: UIK.rich(top, facbanks_bb(G), 14)
	# layout
	var W := LAB + PAD + 7 * (CW + GX)
	var H := 12 * (CH + GY) + PAD * 2
	canvas.custom_minimum_size = Vector2(W, H)
	canvas.bands = []
	for i in 3:
		var f: String = ["Bio", "Phy", "Eng"][i]
		canvas.bands.append({"rect": Rect2(0, PAD / 2 + i * 4 * (CH + GY), W, 4 * (CH + GY)), "col": BAND_COL[f], "label": E.FN[f], "lcol": UIK.FIELD_COL[f]})
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
			var col: Color = LINE_COL[D.TECHK[rk].f] if lit else Color("#232831")
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
			"have": border = UIK.GREEN
			"open": border = UIK.GOLD if ready else Color("#3c3c4e")
			_: border = Color("#232831")
		var bg := Color("#1b1e26") if st != "have" else Color("#232730")
		var v := _card(_box(t.k), border, bg, st == "locked", func(): _tech_click(t))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(row)
		_lbl(row, t.n, 13, UIK.FIELD_COL[t.f].lightened(0.2), true)
		var cost_txt: String = "✓" if st == "have" else str(c)
		var cl := _lbl(row, cost_txt, 13, UIK.GREEN if st == "have" else (UIK.GOLD if c < t.c else Color("#e2e5f0")), true, false)
		cl.size_flags_horizontal = Control.SIZE_SHRINK_END
		if st != "have" and c < t.c: cl.tooltip_text = "Chart cost %d" % t.c
		_lbl(v, t.d, 11, UIK.DIM)
		_tags(v, holders)

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
	var h := UIK.hbox(top, 16)
	UIK.title(h, "Policy Tree", 22).autowrap_mode = TextServer.AUTOWRAP_OFF
	var pl := UIK.para(h, "Adopt one policy now." if (G.estep == "policy" and not SHRules.t(G.get("policyPicked"))) else "One policy per decade; each chain goes Basic → Vigorous → Unified.", UIK.DIM, 14, 0)
	pl.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	for kk in [["held", UIK.GREEN], ["can adopt now", UIK.GOLD], ["next level", Color("#3c3c4e")], ["needs the level before", Color("#232831")]]: _key(h, kk[0], kk[1])
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
		canvas.lines.append({"pts": PackedVector2Array([Vector2(PP, y + PH / 2), Vector2(W - PP, y + PH / 2)]), "col": Color("#f8bc04"), "w": 10.0, "arrow": null})
		for c in 3:
			var x := PP + c * (PW + PGX)
			var lv := c + 1
			if c: canvas.lines.append({"pts": PackedVector2Array([Vector2(x - PGX + 10, y + PH / 2), Vector2(x - 6, y + PH / 2)]), "col": Color("#3c3c4e"), "w": 2.0, "arrow": Vector2(x - 2, y + PH / 2)})
			var st := "have" if my >= lv else ("open" if my == c else "locked")
			var ready: bool = st == "open" and why == null
			var border: Color = UIK.GREEN if st == "have" else (UIK.GOLD if ready else (Color("#3c3c4e") if st == "open" else Color("#232831")))
			var v := _card(Rect2(x, y, PW, PH), border, Color("#232730") if st == "have" else Color("#1b1e26"), st == "locked", func(): _pol_click(p, lv))
			_lbl(v, ["Basic", "Vigorous", "Unified"][c], 10, UIK.DIM)
			_lbl(v, D.POL_LV[c] + p.n, 14, Color("#eff1f8"), true)
			_lbl(v, p.d[c], 11, UIK.DIM)
			_tags(v, facs.filter(func(g): return E.polLv(g, p.k) >= lv).map(func(g): return g.f))
	var starts := []
	for k in D.FAC:
		var f: Dictionary = D.FAC[k]
		starts.append(f.n + ": " + ("Military or Robotic" if f.has("variants") else (", ".join(f.pol.map(func(x): return SHRules._find(D.POL, func(q): return q.k == x).n)) if f.pol.size() else "none")))
	var note := Label.new()
	note.text = "Starting policies: " + " · ".join(starts) + ". Tags on a card show every faction in play holding that level."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UIK.DIM)
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
