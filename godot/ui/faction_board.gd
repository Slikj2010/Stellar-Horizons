## The faction board: a digital copy of the printed faction sheet, shown over the map when the Faction tab is open.
## Ships built and waiting on Earth live here (not on the map). Drag one from New builds onto the launch pad (or click it),
## then, in the Movement step, pick a destination to launch it with the usual engine roll.
extends Control

const RELCOL := [Color("#8d89d6"), Color("#c7cbd7"), Color("#5fcf8a"), Color("#ced1dd"), Color("#e8702a"), Color("#e0508f")]
const DECADES := ["2030", "2060", "2090", "2120+"]
## regions of the printed faction sheets (boards/<f>.webp, all 1400 x 1059 with the same layout)
const SHEET_FLAG := Rect2(38, 15, 127, 85)
const SHEET_PHOTO := Rect2(402, 186, 495, 98)
const SHEET_BASES := [Rect2(45, 472, 335, 168), Rect2(397, 472, 334, 168), Rect2(747, 472, 335, 168), Rect2(45, 657, 335, 169), Rect2(397, 657, 334, 169), Rect2(747, 657, 335, 169)]
static var _crops := {}
static func crop(f: String, r: Rect2) -> AtlasTexture:
	var key := f + str(r)
	if not _crops.has(key):
		var a := AtlasTexture.new()
		a.atlas = load("res://assets/boards/%s.webp" % f)
		a.region = r
		_crops[key] = a
	return _crops[key]

var E: SHRules
var D: Dictionary
var main: Node  ## the main scene (for selecting bases and switching tabs)
var scroll: ScrollContainer
var body: VBoxContainer
var sheet: Control  ## the printed faction sheet, shown on request

# ---------------- drag and drop pieces ----------------
## a ship counter in the New builds tray or on the pad: drag it, or click it to move it across
class ShipTile extends PanelContainer:
	var ship_id = null
	var tex: Texture2D
	var on_click: Callable
	var on_lv: Callable
	func _can_drop_data(_p: Vector2, data) -> bool:
		return ship_id != null and on_lv.is_valid() and data is Dictionary and data.has("lv")
	func _drop_data(_p: Vector2, data) -> void:
		on_lv.call(data.lv)
	func _get_drag_data(_p: Vector2):
		if ship_id == null: return null
		var pv := TextureRect.new()
		pv.texture = tex
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pv.size = Vector2(72, 72)
		pv.position = -pv.size / 2
		pv.modulate = Color(0.949, 0.957, 0.980, 0.85)
		var holder := Control.new()
		holder.add_child(pv)
		set_drag_preview(holder)
		return {"ship": ship_id}
	func _gui_input(ev: InputEvent) -> void:
		if ship_id != null and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed and on_click.is_valid():
			on_click.call()
			accept_event()

## a launch vehicle counter: drag it onto a ship (in New builds or on the pad) to pair them for the launch
class LvCounter extends TextureRect:
	var lv_n := 0
	var buy := false
	var on_click: Callable
	func _get_drag_data(_p: Vector2):
		if lv_n == 0 or modulate.a < 0.99 and not buy: return null
		var pv := TextureRect.new()
		pv.texture = texture
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pv.size = Vector2(64, 64)
		pv.position = -pv.size / 2
		pv.modulate = Color(0.949, 0.957, 0.980, 0.9)
		var holder := Control.new()
		holder.add_child(pv)
		set_drag_preview(holder)
		return {"lv": lv_n}
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed and on_click.is_valid():
			on_click.call()
			accept_event()

## a place a ship can be dropped: the launch pad or the tray (the pad also takes launch vehicles)
class DropZone extends PanelContainer:
	var on_drop: Callable
	var on_lv: Callable
	var normal: StyleBox
	var hover: StyleBox
	func _can_drop_data(_p: Vector2, data) -> bool:
		var ok: bool = data is Dictionary and (data.has("ship") or (data.has("lv") and on_lv.is_valid()))
		if ok and hover: add_theme_stylebox_override("panel", hover)
		return ok
	func _drop_data(_p: Vector2, data) -> void:
		if normal: add_theme_stylebox_override("panel", normal)
		if data.has("lv"): on_lv.call(data.lv)
		else: on_drop.call(data.ship)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
			if normal: add_theme_stylebox_override("panel", normal)

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
	scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

## a row of cards with relative widths (like a 12-column grid)
func _row(ratios: Array) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	body.add_child(h)
	var out := []
	for r in ratios:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_stretch_ratio = r
		p.size_flags_vertical = Control.SIZE_FILL
		p.add_theme_stylebox_override("panel", _card_style())
		h.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		p.add_child(v)
		out.append(v)
	return out

func _card_style(border := Color("#1b2028"), bg := Color("#1b1e26")) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _cell(grid: GridContainer, txt: String, col = null, right := false) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 14)
	if col != null: l.add_theme_color_override("font_color", col)
	if right: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)

func _counter(f: String, key: String, size: float, box: Node, tip := "") -> TextureRect:
	return UIK.image(box, UIK.atlas_tex("atlas_" + f, key), size, tip)

func _lv_counter(G, z: int, size: float, box: Node, tip: String, buy := false) -> LvCounter:
	var c := LvCounter.new()
	c.texture = UIK.atlas_tex("atlas_" + G.f, "LV-%d" % z)
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.custom_minimum_size = Vector2(size, size)
	c.tooltip_text = tip
	c.lv_n = z
	c.buy = buy
	c.mouse_default_cursor_shape = Control.CURSOR_DRAG
	box.add_child(c)
	return c

## pair a launch vehicle with a ship: the ship is staged on the pad, and launches with that vehicle
func _pair(id, z: int) -> void:
	var G = Game.G
	var s = SHRules._find(G.ships, func(x): return SHRules.eq(x.id, id))
	if s == null: return
	var need: int = int(s.sz) if s.cls == "CV" else 1
	var opt = SHRules._find(E.launchLVs(G, "earth", need), func(o): return o.n == z)
	if opt == null:
		Game.pad_msg = "LV-%d cannot carry %s%s." % [z, s.name, (" (it needs LV-%d or bigger)" % need) if z < need else " now"]
		Game.pad_lv = {}
	else:
		Game.pad_msg = ""
		Game.pad_lv = {"id": id, "n": z}
	Game.pad = id
	Game.sel = {"t": "ship", "id": id}
	Game.changed.emit()

# ---------------- build the board ----------------
func refresh() -> void:
	var G = Game.G
	if G == null or not visible: return
	var keep := scroll.scroll_vertical
	UIK.clear(body)
	var F: Dictionary = D.FAC[G.f]
	var ships: Array = G.ships.filter(func(s): return s.loc == "earth")
	if Game.pad != null and not ships.any(func(s): return SHRules.eq(s.id, Game.pad)): Game.pad = null
	var pad = SHRules._find(ships, func(s): return SHRules.eq(s.id, Game.pad)) if Game.pad != null else null
	var bp: bool = G.phase == "build"

	# row 1: header | foreign relations
	var r1 := _row([4, 8])
	var hh := UIK.hbox(r1[0], 12)
	var fl := UIK.image(hh, crop(G.f, SHEET_FLAG), 76)
	fl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var hv := UIK.vbox(hh, 6)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIK.title(hv, F.n + ((" · " + F.variants[G.variant].n) if G.variant != null else ""), 26)
	var L := E.lims(G)
	var chips := UIK.flow(hv)
	for t in ["Robotic explorers %d/%d" % [E.nonProbeRE(G), L[0]], "Crew vehicles %d/%d" % [E.nCV(G), L[1]], "Bases %d/%d" % [E.nBase(G), L[2]], "Cash $%sB" % SHRules.n(G.cash)]: _chip(chips, t)
	_p(hv, F.ab, UIK.DIM, 13)
	UIK.button(hv, "Show the printed faction sheet", func(): _show_sheet(G.f))
	UIK.head(r1[1], "Foreign relations")
	var rel := HBoxContainer.new()
	rel.add_theme_constant_override("separation", 8)
	r1[1].add_child(rel)
	for i in D.REL.size():
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", _card_style(RELCOL[i].darkened(0.3), RELCOL[i].darkened(0.78)))
		rel.add_child(tile)
		var tv := UIK.vbox(tile, 4)
		var nl := _p(tv, D.REL[i], RELCOL[i], 12)
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var c = F.rel[i] if i < F.rel.size() else null
		var cl := _p(tv, ((("$%dB / " % c[0]) if c[0] else "") + "%dR" % c[1]) if c != null else " ", UIK.DIM, 12)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tags := UIK.flow(tv)
		for k in G.rel:
			if G.rel[k] == i: _tag(tags, D.FAC[k].pre, Color(D.FAC[k].c), D.FAC[k].n)

	# rows: launch pad | new builds; production | population | score; bases; shipyard | crew vehicles; technologies
	var rA := _row([6, 6])
	var rB := _row([4, 4, 4])
	var rC := _row([12])
	var rD := _row([7, 5])
	var r2 := [rB[0], rA[0], rB[1]]
	var r3 := [rC[0], rB[2]]
	var r4 := [rA[1], rD[0]]
	UIK.head(r2[0], "Earth production")
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 10)
	r2[0].add_child(g)
	for t in ["Decade", "Funds", "Phy", "Eng", "Bio"]: _cell(g, t, UIK.DIM, t != "Decade")
	var dr := E.decadeRow(G.y)
	for i in F.pr.size():
		var row: Array = F.pr[i]
		var now: bool = i == dr
		_cell(g, DECADES[i], UIK.AMBER if now else null)
		_cell(g, "$%dB" % row[0], UIK.AMBER if now else null, true)
		_cell(g, str(row[1]), UIK.FIELD_COL.Phy, true)
		_cell(g, str(row[2]), UIK.FIELD_COL.Eng, true)
		_cell(g, str(row[3]), UIK.FIELD_COL.Bio, true)
	_p(r2[0], "Tech points banked: %d Physics, %d Engineering, %d Biology." % [G.bank.Phy, G.bank.Eng, G.bank.Bio], UIK.DIM, 13)

	UIK.head(r2[1], "Earth resources")
	UIK.rich(r2[1], UIK.res_bb(E.estock(G)) + " [color=#a3a7b2]on the faction board[/color]", 14)
	UIK.head(r2[1], "Launch vehicles on Earth · drag one onto a ship to pair them")
	var lvs := UIK.flow(r2[1])
	var any_lv := false
	for z in [1, 2, 3, 4]:
		for i in int(SHRules.gi(G.lv.earth, z, 0)):
			_lv_counter(G, z, 58, lvs, "LV-%d: drag it onto a ship to launch it with this vehicle" % z)
			any_lv = true
		for i in int(SHRules.gi(SHRules.gi(G.get("lvCool", {}), "earth", {}), z, 0)):
			var t := _counter(G.f, "LV-%d" % z, 58, lvs, "LV-%d: recovered, ready next turn" % z)
			t.modulate = Color(0.949, 0.957, 0.980, 0.4)
			any_lv = true
	if not any_lv: _p(lvs, "None in stock: build one in the Build step, or buy one at launch (shown below).", UIK.DIM, 13)
	# vehicles that can be bought at launch (ORE + FUEL on Earth) are dragged the same way
	var buyable: Array = E.launchLVs(G, "earth", 1).filter(func(o): return SHRules.t(o.get("buy")))
	if buyable.size() and G.phase == "move":
		_p(r2[1], "Buy at launch (pays when the ship launches):", UIK.DIM, 12)
		var bl := UIK.flow(r2[1])
		for o in buyable:
			var c := _lv_counter(G, o.n, 46, bl, "LV-%d: buy at launch for %s. Drag it onto a ship." % [o.n, o.txt], true)
			c.modulate = Color(0.949, 0.957, 0.980, 0.6)
	_pad(r2[1], G, pad)

	UIK.head(r2[2], "Base population")
	var sg := GridContainer.new()
	sg.columns = 4
	sg.add_theme_constant_override("h_separation", 10)
	r2[2].add_child(sg)
	for t in ["Settl.", "Trade", "Res.", "Tech"]: _cell(sg, t, UIK.DIM, t != "Settl.")
	for i in D.SETT.size():
		var r: Array = D.SETT[i]
		var nx = D.SETT[i + 1] if i + 1 < D.SETT.size() else null
		var on: bool = G.bases.any(func(b): return b.set >= r[0] and (nx == null or b.set < nx[0]))
		var col = UIK.AMBER if on else null
		_cell(sg, ("%d–%d" % [r[0], nx[0] - 1]) if nx != null else "%d+" % r[0], col)
		_cell(sg, str(r[1]), col, true)
		_cell(sg, ("+%d" % r[2]) if r[2] else "–", col, true)
		_cell(sg, ("+%d" % r[3]) if r[3] else "–", col, true)

	UIK.head(r3[0], "Bases (%d founded)" % G.bases.size())
	var bg := GridContainer.new()
	bg.columns = 3
	bg.add_theme_constant_override("h_separation", 8)
	bg.add_theme_constant_override("v_separation", 8)
	r3[0].add_child(bg)
	for i in D.BASE_NAMES[G.f].size(): _base_slot(bg, G, D.BASE_NAMES[G.f][i], i)
	var sc := E.score(G)
	UIK.head(r3[1], "Victory points")
	var vp := UIK.title(r3[1], SHRules.n(sc.total), 40)
	vp.add_theme_color_override("font_color", UIK.AMBER)
	_p(r3[1], sc.rating, UIK.DIM)
	UIK.head(r3[1], "Missions")
	for x in [[G.mis.mine, "Your mission", UIK.AMBER], [G.mis.common, "Common mission", Color("#ced1dd")]]:
		if x[0] == null: continue
		var mh := UIK.hbox(r3[1])
		UIK.image(mh, UIK.atlas_tex("markers", D.MIS[x[0]].mk), 46)
		var ml := UIK.rich(mh, "[b]%s[/b]\n[color=#%s]%s[/color]" % [E.misTxt(x[0]), x[2].to_html(false), x[1]], 13)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p(r3[1], "Kept %d of %d this decade%s" % [G.mis.kept.size(), E.misCap(G), (": " + ", ".join(G.mis.kept.map(func(id): return E.misTxt(id)))) if G.mis.kept.size() else "."], UIK.DIM, 13)
	UIK.head(r3[1], "Politics")
	var pols := []
	for p in D.POL:
		var lv := E.polLv(G, p.k)
		if lv: pols.append(D.POL_LV[lv - 1] + p.n)
	_p(r3[1], "%d politics markers · %d victory markers · %s" % [G.polm, G.vm, ", ".join(pols) if pols.size() else "no policies"], null, 13)
	UIK.button(r3[1], "Convert politics markers…", func(): main.ttree.convert_dialog(), G.polm < 1, "Slide markers into cash or tech points")

	UIK.head(r4[0], "New builds · drag onto the launch pad")
	_tray(r4[0], G, ships, pad)
	var lf := UIK.flow(r4[0])
	lf.add_theme_constant_override("h_separation", 12)
	for z in [1, 2, 3, 4]:
		var cell := UIK.vbox(lf, 3)
		UIK.button(cell, "Build LV-%d" % z, func(): main.buy_lv(z, "earth"), not bp, "1 ORE + %d FUEL" % z)
		var tk := _counter(G.f, "LV-%d" % z, 58, cell, "LV-%d token: 1 ORE + %d FUEL" % [z, z])
		tk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not bp: tk.modulate = Color(0.949, 0.957, 0.980, 0.5)
	if main != null:
		main.refund_list(r4[0])
		main.lv_scrap_row(r4[0])
	UIK.head(r4[1], "Earth shipyard" + ("" if bp else " · open in the Build & service step"))
	for o in E.buildOptions(G, "earth"):
		if o.why == "in service": continue
		var h := UIK.hbox(r4[1])
		_counter(G.f, o.kind + "|" + o.u.n, 40, h)
		var l := UIK.rich(h, "[b]%s[/b] [color=#a3a7b2]%s[/color]\n%s = %s%s" % [o.u.n, o.kind, UIK.res_bb(o.cost), E.earthCostTxt(G, o.cost), (" · [color=#e0508f]%s[/color]" % o.why) if o.why != null else ""], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.button(h, "Build", func(): main.buy_unit(o, "earth", false), not bp or o.why != null or G.cash < E.earthCash(G, o.cost))
		if o.cv and o.why == null and bp: UIK.button(h, "Reserved", func(): main.buy_unit(o, "earth", true), false, "Reserved: 1 SUP and 1 Fuel cheaper")

	# row 5: crew vehicles and base shipyards
	var cvs: Array = G.ships.filter(func(s): return s.cls == "CV")
	var yards: Array = G.bases.filter(func(b): return SHRules.t(b.fac.sup))
	var r5 := [rD[1]]
	UIK.head(r5[0], "Crew vehicles & base shipyards")
	if not cvs.size() and not yards.size(): _p(r5[0], "No crew vehicles yet. Base shipyards appear here once a base has a Supply Station.", UIK.DIM, 13)
	if cvs.size() or yards.size():
		for s in cvs:
			var h := UIK.hbox(r5[0])
			_counter(G.f, s.img + "|back" if SHRules.t(s.res) else s.img, 40, h)
			var l := UIK.rich(h, "[b]%s[/b] CV-%d · %s%s%s%s" % [s.name, s.sz, E.locName(s.loc), " · reserved" if SHRules.t(s.res) else "", (" · %d damage" % s.dmg) if SHRules.t(s.dmg) else "", (" · cargo " + UIK.res_bb(s.cargo)) if E.sum(s.cargo) else ""], 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if bp:
				if SHRules.t(s.res): UIK.button(h, "Unreserve", func(): main.confirm("Unreserve %s?" % s.name, "%s leaves reserve and can be used again." % s.name, func(): return E.unreserve(G, s), "Unreserve"), not E.unreserveInfo(G, s).ok, String(E.unreserveInfo(G, s).get("why", "")))
				else: UIK.button(h, "Reserve", func(): main.reserve_ask(s))
				if SHRules.t(s.dmg): UIK.button(h, "Repair", func(): Game.act(E.repair(G, s)))
		for b in yards:
			var h := UIK.hbox(r5[0])
			var yl := UIK.rich(h, "[b]%s shipyard[/b] · stock %s" % [b.name, UIK.res_bb(b.stock)], 13)
			yl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for z in [1, 2, 3, 4]: UIK.button(h, "LV-%d" % z, func(): main.buy_lv(z, b.id), not bp)

	# row 6: technologies
	var r6 := _row([12])
	var have: Array = D.TECH.filter(func(t): return SHRules.t(G.tech.get(t.k)))
	UIK.head(r6[0], "Technologies (%d of %d)" % [have.size(), D.TECH.size()])
	var tf := UIK.flow(r6[0])
	for t in have: _tag(tf, t.n, UIK.FIELD_COL[t.f], t.d)
	if not have.size(): _p(tf, "None yet.", UIK.DIM)
	await get_tree().process_frame
	scroll.scroll_vertical = keep

## a wrapped label that may shrink with its card
func _p(box: Node, txt: String, col = null, size := 14) -> Label:
	var l := UIK.para(box, txt, col, size, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _chip(box: Node, txt: String) -> void:
	_tag(box, txt, Color("#e2e5f0"))

func _tag(box: Node, txt: String, col: Color, tip := "") -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.75)
	sb.border_color = col.darkened(0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = tip
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col.lightened(0.15))
	p.add_child(l)
	box.add_child(p)

func _ship_tile(box: Node, G, s, size: float, click: Callable) -> ShipTile:
	var tile := ShipTile.new()
	tile.ship_id = s.id
	var sid = s.id
	tile.on_lv = func(z): _pair(sid, z)
	tile.tex = UIK.atlas_tex("atlas_" + G.f, s.img + "|back" if SHRules.t(s.res) else s.img)
	tile.on_click = click
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG
	tile.tooltip_text = "Drag to the launch pad (or click). Drop a launch vehicle on it to pair them."
	var sb := StyleBoxEmpty.new()
	tile.add_theme_stylebox_override("panel", sb)
	var v := UIK.vbox(tile, 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := UIK.image(v, tile.tex, size)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _p(v, s.name, null, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size.x = size + 8
	var k := _p(v, (("CV-%d" % s.sz) if s.cls == "CV" else s.kind) + (" · reserved" if SHRules.t(s.res) else ""), UIK.DIM, 11)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tile)
	return tile

func _drop_zone(box: Node, dashed_col: Color, drop: Callable) -> DropZone:
	var z := DropZone.new()
	var n := _card_style(dashed_col.darkened(0.2), Color("#1b1d2c"))
	n.set_border_width_all(2)
	var h := _card_style(UIK.CYAN, Color("#1f232c"))
	h.set_border_width_all(2)
	z.normal = n
	z.hover = h
	z.add_theme_stylebox_override("panel", n)
	z.on_drop = drop
	box.add_child(z)
	return z

func _tray(box: Node, G, ships: Array, pad) -> void:
	var z := _drop_zone(box, Color("#1b2028"), func(_id):
		Game.pad = null
		Game.changed.emit())
	z.custom_minimum_size.y = 120
	var f := UIK.flow(z)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	var any := false
	for s in ships:
		if pad != null and SHRules.eq(s.id, pad.id): continue
		_ship_tile(f, G, s, 64, func(): _stage(s.id))
		any = true
	for nm in G.probes.get("earth", []):
		var v := UIK.vbox(f, 2)
		UIK.image(v, UIK.atlas_tex("atlas_" + G.f, "Probe|" + nm), 44, "Probes ride along with a robotic explorer at launch")
		_p(v, nm, UIK.DIM, 11)
		any = true
	if not any: _p(f, "Nothing waiting on Earth. Build units from the shipyard.", UIK.DIM, 13)

func _stage(id) -> void:
	Game.pad_msg = ""
	if not SHRules.eq(Game.pad_lv.get("id"), id): Game.pad_lv = {}
	Game.pad = null if SHRules.eq(Game.pad, id) else id
	Game.sel = {"t": "ship", "id": id}
	Game.changed.emit()

func _pad(box: Node, G, pad) -> void:
	UIK.head(box, "Launch pad")
	var z := _drop_zone(box, UIK.AMBER if pad != null else Color("#3c3c4e"), func(id): _stage_on(id))
	if pad != null:
		var pid = pad.id
		z.on_lv = func(n): _pair(pid, n)
	var photo := crop(G.f, SHEET_PHOTO)
	for st in [[z.normal, 0.32 if pad == null else 0.22], [z.hover, 0.5]]:
		var t := StyleBoxTexture.new()
		t.texture = photo
		t.modulate_color = Color(st[1], st[1], st[1] * 1.1, 1)
		t.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		t.content_margin_left = 12
		t.content_margin_right = 12
		t.content_margin_top = 10
		t.content_margin_bottom = 10
		if st[0] == z.normal: z.normal = t
		else: z.hover = t
	z.add_theme_stylebox_override("panel", z.normal)
	z.custom_minimum_size.y = 110
	var inner := UIK.hbox(z, 12)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	if pad == null:
		var l := _p(inner, "Drag a ship here to stage it for launch.", UIK.DIM, 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return
	_ship_tile(inner, G, pad, 76, func(): _stage(pad.id))
	var mv := E.moves(G, pad)
	var paired := -1
	if Game.pad_lv.get("id") != null and SHRules.eq(Game.pad_lv.id, pad.id): paired = int(Game.pad_lv.n)
	# a robotic explorer's trip time depends on its launch vehicle, so only that vehicle's routes are offered
	if paired > 0 and pad.cls == "RE":
		var only := mv.filter(func(m): return m.get("lv") == null or m.lv.n == paired)
		if only.size(): mv = only
	var lv = null
	if mv.size(): lv = mv[0].get("lv")
	if paired > 0:
		var po = SHRules._find(E.launchLVs(G, "earth", int(pad.sz) if pad.cls == "CV" else 1), func(o): return o.n == paired)
		if po != null: lv = po
	var info := UIK.vbox(inner, 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIK.title(info, pad.name, 18)
	UIK.rich(info, "[color=#a3a7b2]%s%s[/color]" % [("Crew vehicle CV-%d" % pad.sz) if pad.cls == "CV" else pad.kind, (" · cargo " + UIK.res_bb(pad.cargo)) if E.sum(pad.cargo) else ""], 13)
	if lv != null:
		_p(info, "Launch vehicle LV-%d %s%s" % [lv.n, "from stock" if SHRules.t(lv.get("stock")) else "(bought at launch: " + String(lv.txt) + ")", " · paired by you" if paired > 0 else ""], UIK.DIM, 13)
		var lc := _lv_counter(G, lv.n, 64, inner, "The launch vehicle that will carry it. Click to go back to the automatic choice.")
		lc.on_click = func():
			Game.pad_lv = {}
			Game.pad_msg = ""
			Game.changed.emit()
	_p(info, "Drag a launch vehicle here to choose which one carries it.", UIK.DIM, 11)
	if Game.pad_msg != "": _p(info, Game.pad_msg, Color("#e0508f"), 13)
	if G.phase != "move":
		_p(box, "Launches happen in the Movement step.", UIK.DIM, 13)
		return
	if not mv.size():
		_p(box, "This ship cannot launch now (it needs a launch vehicle, or it has already moved).", UIK.DIM, 13)
		return
	_p(box, "Launch to:", UIK.DIM, 13)
	var by_sys := {}
	for m in mv:
		if m.dest == pad.loc: continue
		var sy = E.sysOf(m.dest)
		if not by_sys.has(sy): by_sys[sy] = []
		if not by_sys[sy].any(func(x): return x.dest == m.dest): by_sys[sy].append(m)
	# search and research-field filter, as in the Selected tab
	var groups := []
	var apply := func():
		var q: String = String(main._lf.q).strip_edges().to_lower()
		for g in groups:
			var any := false
			for bt in g.btns:
				var ok: bool = (q == "" or String(bt.get_meta("fn", "")).contains(q)) and (main._lf.f == "" or String(bt.get_meta("ff", "")).split(" ").has(main._lf.f))
				bt.visible = ok
				if ok: any = true
			g.head.visible = any
			g.flow.visible = any
	var total := 0
	for sy in by_sys: total += by_sys[sy].size()
	if total > 5:
		var le := LineEdit.new()
		le.placeholder_text = "Search destinations…"
		le.clear_button_enabled = true
		le.text = main._lf.q
		le.text_changed.connect(func(t): main._lf.q = t; apply.call())
		box.add_child(le)
		var chips := UIK.flow(box)
		var grp := ButtonGroup.new()
		for kv in [["", "All"], ["Phy", "Physics"], ["Eng", "Engineering"], ["Bio", "Biology"]]:
			var cb := Button.new()
			cb.text = kv[1]
			cb.toggle_mode = true
			cb.button_group = grp
			cb.focus_mode = Control.FOCUS_NONE
			cb.button_pressed = main._lf.f == kv[0]
			if kv[0] != "": cb.add_theme_color_override("font_color", UIK.FIELD_COL[kv[0]])
			cb.pressed.connect(func(): main._lf.f = kv[0]; apply.call())
			chips.add_child(cb)
	for sy in D.SYS_ORDER:
		if not by_sys.has(sy): continue
		var hd := _p(box, D.SYS[sy].n, UIK.CYAN, 12)
		var f := UIK.flow(box)
		var g := {"head": hd, "flow": f, "btns": []}
		groups.append(g)
		for m in by_sys[sy]:
			var di: Dictionary = main._dest_info(G, m.dest)
			var bt := UIK.button(f, m.label + ((" · %dt" % m.eta) if SHRules.t(m.get("eta")) else ""), func():
				var extra := {}
				if paired > 0: extra.lvSize = paired
				main.do_move(pad, m.dest, extra), false, String(di.names))
			bt.set_meta("fn", (String(m.label) + " " + String(di.names)).to_lower())
			bt.set_meta("ff", di.fields)
			g.btns.append(bt)
	apply.call()

func _stage_on(id) -> void:
	Game.pad_msg = ""
	if not SHRules.eq(Game.pad_lv.get("id"), id): Game.pad_lv = {}
	Game.pad = id
	Game.sel = {"t": "ship", "id": id}
	Game.changed.emit()

func _base_slot(grid: GridContainer, G, nm: String, idx: int) -> void:
	var b = SHRules._find(G.bases, func(x): return x.name == nm)
	var slot := Control.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(0, 170)
	slot.clip_contents = true
	grid.add_child(slot)
	var art := TextureRect.new()
	art.texture = crop(G.f, SHEET_BASES[idx])
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(0.949, 0.957, 0.980, 1) if b != null else Color(0.296, 0.308, 0.353, 1)
	slot.add_child(art)
	var info := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.067, 0.070, 0.079, 0.78)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	info.add_theme_stylebox_override("panel", sb)
	info.position = Vector2(6, 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(info)
	var h := UIK.hbox(info, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if b == null:
		var e := UIK.rich(h, "[color=#7879a2]Not founded[/color]", 12)
		e.custom_minimum_size.x = 90
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var key: String = Game.board_node.base_key(b, G.f) if Game.board_node != null else ""
	if key != "": _counter(G.f, key, 46, h).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var facs := []
	for c in [["lab", "Lab"], ["mine", "Mine"], ["sup", "Supply"], ["def", "Defense"]]:
		if SHRules.t(b.fac[c[0]]): facs.append("%s %d" % [c[1], b.fac[c[0]]])
	var l := UIK.rich(h, "[b]%s[/b] · %d settl.\n[color=#b8bcc8]%s\nStock[/color] %s" % [D.W[b.w].n, b.set, ", ".join(facs) if facs.size() else "no facilities", UIK.res_bb(b.stock)], 12)
	l.custom_minimum_size.x = 170
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.tooltip_text = "Open " + nm
	slot.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			Game.sel = {"t": "base", "id": b.id}
			if main != null: main.tabs.current_tab = 1
			Game.changed.emit())

# ---------------- the printed sheet ----------------
func _show_sheet(f: String) -> void:
	if sheet != null: sheet.queue_free()
	sheet = ColorRect.new()
	sheet.color = Color(0.062, 0.062, 0.062, 0.85)
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	var t := TextureRect.new()
	t.texture = load("res://assets/boards/%s.webp" % f)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 20
	t.offset_top = 20
	t.offset_right = -20
	t.offset_bottom = -60
	sheet.add_child(t)
	var b := Button.new()
	b.text = "Close the printed sheet"
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_top = -50
	b.offset_bottom = -12
	b.offset_left = -110
	b.offset_right = 110
	b.pressed.connect(func():
		sheet.queue_free()
		sheet = null)
	sheet.add_child(b)
