## Textures the 2.5D view draws on the fly, the way the web version paints them on HTML canvases: text sprites,
## system labels, the glowing box numbers, and each world's information plate with its card, life and base tray.
## Everything is drawn with Godot's 2D drawing into SubViewports; a small canvas-like helper (Pen) keeps the
## web version's coordinates, sizes, alignments and colours.
class_name V25Paint
extends Node

const FONT_FILES := {400: "IBMPlexSansCondensed-Regular", 500: "IBMPlexSansCondensed-Medium", 600: "IBMPlexSansCondensed-SemiBold", 700: "IBMPlexSansCondensed-Bold"}
static var _fonts := {}

## the web version's font (IBM Plex Sans Condensed) when its files are in assets/fonts, otherwise DejaVu Sans Condensed
static func font(weight: int) -> Font:
	var w := 700 if weight >= 650 else (600 if weight >= 550 else (500 if weight >= 450 else 400))
	if _fonts.has(w): return _fonts[w]
	var f: Font = null
	var path := "res://assets/fonts/%s.ttf" % FONT_FILES[w]
	if ResourceLoader.exists(path): f = load(path)
	else:
		var base: Font = load("res://assets/fonts/DejaVuSansCondensed-Bold.ttf" if w == 700 else "res://assets/fonts/DejaVuSansCondensed.ttf")
		if w == 500 or w == 600:
			var fv := FontVariation.new()
			fv.base_font = base
			fv.variation_embolden = 0.35 if w == 500 else 0.7
			f = fv
		else: f = base
	_fonts[w] = f
	return f

static func css(c) -> Color:
	if c is Color: return c
	var s: String = c
	if s.begins_with("#"): return Color(s)
	var nums := []
	var rx := RegEx.create_from_string("[\\d.]+")
	for m in rx.search_all(s): nums.append(float(m.get_string()))
	return Color(nums[0] / 255.0, nums[1] / 255.0, nums[2] / 255.0, nums[3] if nums.size() > 3 else 1.0)

## a canvas-like pen for one CanvasItem: coordinates and sizes are multiplied by k (the canvas transform scale)
class Pen:
	var ci: CanvasItem
	var k := 1.0
	var alpha := 1.0
	func _init(c: CanvasItem) -> void: ci = c
	func P(x: float, y: float) -> Vector2: return Vector2(x * k, y * k)
	func col(c) -> Color:
		var cc: Color = V25Paint.css(c)
		cc.a *= alpha
		return cc
	func rrect_pts(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		r = minf(r, minf(w, h) / 2.0)
		var cs := [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]
		for c in cs:
			for i in 7:
				var a: float = c[2] + i * (PI / 2) / 6.0
				out.append(P(c[0] + cos(a) * r, c[1] + sin(a) * r))
		return out
	func fill_rrect(x: float, y: float, w: float, h: float, r: float, c) -> void:
		ci.draw_colored_polygon(rrect_pts(x, y, w, h, r), col(c))
	func stroke_rrect(x: float, y: float, w: float, h: float, r: float, c, lw: float) -> void:
		var pts := rrect_pts(x, y, w, h, r)
		pts.append(pts[0])
		ci.draw_polyline(pts, col(c), lw * k, true)
	func dash_rrect(x: float, y: float, w: float, h: float, r: float, c, lw: float, dash: float, gap: float) -> void:
		var pts := rrect_pts(x, y, w, h, r)
		pts.append(pts[0])
		var cc := col(c)
		var on := true
		var left := dash * k
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var L := a.distance_to(b)
			var t := 0.0
			while t < L:
				var step := minf(left, L - t)
				if on: ci.draw_line(a.lerp(b, t / L), a.lerp(b, (t + step) / L), cc, lw * k, true)
				t += step
				left -= step
				if left <= 0.001:
					on = not on
					left = (dash if on else gap) * k
	func fill_poly(pts: Array, c) -> void:
		var pp := PackedVector2Array()
		for q in pts: pp.append(P(q[0], q[1]))
		ci.draw_colored_polygon(pp, col(c))
	func stroke_poly(pts: Array, c, lw: float) -> void:
		var pp := PackedVector2Array()
		for q in pts: pp.append(P(q[0], q[1]))
		pp.append(pp[0])
		ci.draw_polyline(pp, col(c), lw * k, true)
	func circle(x: float, y: float, r: float, c) -> void: ci.draw_circle(P(x, y), r * k, col(c))
	func ring(x: float, y: float, r: float, c, lw: float) -> void: ci.draw_arc(P(x, y), r * k, 0, TAU, 48, col(c), lw * k, true)
	func line(x0: float, y0: float, x1: float, y1: float, c, lw: float) -> void: ci.draw_line(P(x0, y0), P(x1, y1), col(c), lw * k, true)
	func measure(t: String, weight: int, size: float) -> float:
		var fs := maxi(1, roundi(size * k))
		return V25Paint.font(weight).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / k
	## shrink the font in 1px steps until the text fits maxW (down to min); returns the size used
	func fit(t: String, weight: int, size: float, maxW: float, mn: float) -> float:
		var f := size
		while measure(t, weight, f) > maxW and f > mn: f -= 1
		return f
	## text with the canvas's middle baseline; align: left, center, right
	func text(t: String, x: float, y: float, weight: int, size: float, c, align := "left", stroke = null, stroke_w := 0.0, glow = null, glow_r := 0.0) -> void:
		var fnt := V25Paint.font(weight)
		var fs := maxi(1, roundi(size * k))
		var w := fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := P(x, y)
		if align == "center": p.x -= w / 2.0
		elif align == "right": p.x -= w
		p.y += (fnt.get_ascent(fs) - fnt.get_descent(fs)) / 2.0
		if glow != null and glow_r > 0:
			var gc := col(glow)
			for i in 4:
				var rr := glow_r * k * (1.0 - i * 0.22)
				ci.draw_string_outline(fnt, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, roundi(rr)), Color(gc, gc.a * 0.16))
		if stroke != null and stroke_w > 0: ci.draw_string_outline(fnt, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, roundi(stroke_w * k)), col(stroke))
		ci.draw_string(fnt, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col(c))

## a SubViewport that paints with a callable, re-rendered on request
class Sheet extends SubViewport:
	var node := Node2D.new()
	var painter: Callable
	func _init(sz: Vector2i, fn: Callable) -> void:
		size = sz
		transparent_bg = true
		disable_3d = true
		render_target_update_mode = SubViewport.UPDATE_ONCE
		painter = fn
		node.draw.connect(func(): painter.call(node))
		add_child(node)
	func repaint() -> void:
		node.queue_redraw()
		render_target_update_mode = SubViewport.UPDATE_ONCE

# ---------------- text sprites, labels and glyphs: one atlas, shelf-packed ----------------
const AT := 2048
var _atlas: Sheet
var _entries := {}  ## key -> {x, y, w, h, kind, ...}
var _list: Array = []
var _sx := 0
var _sy := 0
var _row := 0

func _ready() -> void:
	_atlas = Sheet.new(Vector2i(AT, AT), _paint_atlas)
	add_child(_atlas)

func atlas_tex() -> Texture2D: return _atlas.get_texture()

func _alloc(w: int, h: int) -> Vector2i:
	if _sx + w > AT:
		_sx = 0
		_sy += _row + 2
		_row = 0
	if _sy + h > AT:
		# full: start again (rare); every sprite is looked up again on the next frame
		_entries.clear()
		_list.clear()
		_sx = 0; _sy = 0; _row = 0
	var p := Vector2i(_sx, _sy)
	_sx += w + 2
	_row = maxi(_row, h)
	return p

func _add(key: String, e: Dictionary) -> Dictionary:
	var p := _alloc(e.w, e.h)
	e.x = p.x
	e.y = p.y
	_entries[key] = e
	_list.append(e)
	_atlas.repaint()
	return e

## V25.text: returns {f: [x,y,w,h], w, h} where w, h are the sprite's size in board units
func text_sprite(t: String, color: String, size: float) -> Dictionary:
	var key := t + "|" + color + "|" + str(roundi(size))
	if _entries.has(key): return _entries[key]
	var fs := maxi(14, roundi(size * 2))
	var tw := V25Paint.font(600).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := ceili(tw) + 12
	var h := roundi(fs * 1.4)
	var e := {"kind": "text", "t": t, "c": color, "fs": fs, "w": w, "h": h, "sw": w / 2.0 * (size / (fs / 2.0)), "sh": h / 2.0 * (size / (fs / 2.0))}
	return _add(key, e)

## labelOf: a system label
func label(t: String) -> Dictionary:
	var key := "L|" + t
	if _entries.has(key): return _entries[key]
	var w := ceili(V25Paint.font(600).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x) + 16
	return _add(key, {"kind": "label", "t": t, "w": w, "h": 56})

## glyph: a box number or FLYBY with a glow in the given colour
func glyph(t: String, color: String) -> Dictionary:
	var key := "G|" + t + color
	if _entries.has(key): return _entries[key]
	return _add(key, {"kind": "glyph", "t": t, "c": color, "w": 160, "h": 160})

func uv_of(e: Dictionary) -> Array:
	return [float(e.x) / AT, float(e.y) / AT, float(e.x + e.w) / AT, float(e.y + e.h) / AT]

func _paint_atlas(n: Node2D) -> void:
	var pen := Pen.new(n)
	for e in _list:
		var ox: float = e.x
		var oy: float = e.y
		match e.kind:
			"text":
				pen.text(e.t, ox + e.w / 2.0, oy + e.h / 2.0, 600, e.fs, e.c, "center", "#000", maxf(3, e.fs / 5.0))
			"label":
				pen.text(e.t, ox + e.w / 2.0, oy + 29, 600, 40, "#bfe9f5", "center", "rgba(2,6,14,.9)", 7)
			"glyph":
				var fs := 40 if e.t.length() > 2 else 104
				pen.text(e.t, ox + 80, oy + 86, 700, fs, "#fff", "center", null, 0, e.c, 18)

# ---------------- world plates (panelFor + drawTray) ----------------
const FIELD := {"Phy": ["#5aaaff", "PHYSICS"], "Eng": ["#d5dbe6", "ENGINEERING"], "Bio": ["#6edc8c", "BIOLOGY"]}
const RESC := {"ORE": "#d9955a", "SUP": "#6fc0ee", "FUEL": "#f2b13c"}
const TAGTXT := {"severeAtm": "Severe atmosphere", "volcanic": "Volcanic", "rad": "Radiation", "minimal": "Minimal gravity", "reentry": "Re-entry"}
const BONUS := {"all": "all", "probe": "probes", "crew": "crewed", "rover": "rovers", "orbiter": "orbiters", "flyby": "flybys", "spec": "specialists"}
const K25 := 1.8
const PWS := 260.0
const SLOT_CARD := [325.0, 36.5, 110.0, 73.0]
const SLOT_LIFE := [288.0, 108.0]
static func slot_base(i: int) -> Array: return [8 + 86 * (i % 4) + 22.0, 176 + 50 * floorf(i / 4.0)]
static func KIND(w: Dictionary) -> String:
	var t: Array = w.tags
	if t.has("sunobs"): return "Solar observatory"
	if t.has("alpha"): return "Interstellar target"
	if t.has("tele"): return "Telescope site"
	if t.has("gas"): return "Gas giant"
	if t.has("earth"): return "Home orbit"
	if t.has("rocky") and t.has("icy"): return "Rocky-icy world"
	if t.has("icy"): return "Icy world"
	if t.has("rocky"): return "Rocky world"
	if t.has("station"): return "Orbital site"
	return "World"

var panels := {}  ## world -> {sheet, key, k, ws, nb}

## the plate texture for a world, repainted when what it shows has changed
func panel(k: String, ws: Dictionary, nb: int, size: Vector2) -> Texture2D:
	var key := "|".join([ws.v, ws.get("life"), ws.get("sol"), ws.get("terra"), ws.get("npf"), ws.get("blk"), ws.get("card"), nb, _npf_name(k, ws)])
	var P = panels.get(k)
	if P == null:
		P = {"key": "", "k": k}
		P.sheet = Sheet.new(Vector2i(roundi(size.x * K25), roundi(size.y * K25)), func(n): _paint_panel(n, P))
		add_child(P.sheet)
		panels[k] = P
	if P.key != key:
		P.key = key
		P.ws = ws.duplicate()
		P.nb = nb
		P.sheet.repaint()
	return P.sheet.get_texture()

func _npf_name(k: String, ws: Dictionary) -> String:
	return str(Game.E.npfName(Game.G, k)) if SHRules.t(ws.get("npf")) and Game.G != null else ""

func _hex(cx: float, cy: float, r: float) -> Array:
	var out := []
	for i in 6:
		var a := i / 6.0 * 6.2832 + .5236
		out.append([cx + cos(a) * r, cy + sin(a) * r])
	return out

func _paint_panel(n: Node2D, P: Dictionary) -> void:
	var k: String = P.k
	var ws: Dictionary = P.ws
	var D: Dictionary = Game.data.D
	var w: Dictionary = D.W[k]
	var F: Array = ["#e8d27a", "VARIABLE FIELD"] if w.tags.has("alpha") else FIELD.get(w.f, ["#9ad", ""])
	var fc: String = F[0]
	var dead: bool = int(ws.v) < 1
	var x := Pen.new(n)
	x.k = PWS * K25 / 640.0
	x.fill_rrect(6, 6, 628, 340, 24, "rgba(4,12,26,.86)")
	x.alpha = .85
	x.stroke_rrect(6, 6, 628, 340, 24, fc, 4)
	x.alpha = .18
	x.fill_rrect(6, 6, 628, 56, 24, fc)
	x.alpha = 1.0
	# name and kind
	var chipW := x.measure(F[1], 700, 24)
	var f1 := x.fit(w.n, 700, 56, 588 - 28 - chipW - 24, 20)
	x.text(w.n, 28, 36, 700, f1, "#eaf6ff")
	var kd := KIND(w)
	x.text(kd, 28, 86, 500, x.fit(kd, 500, 28, 560, 14), "#9fb7cc")
	# field chip
	x.text(F[1], 616, 36, 700, 24, fc, "right")
	# explore tile
	var hx := _hex(100, 200, 82)
	x.fill_poly(hx, "rgba(60,20,20,.8)" if dead else "rgba(255,255,255,.07)")
	x.stroke_poly(hx, "#e8508a" if dead else fc, 5)
	var hw := func(yy: float) -> float: return maxf(0, minf(71, (82 - absf(yy)) * 1.732))
	var fitHex := func(t: String, wt: int, size: float, yc: float, mn: float) -> float:
		var f := size
		while true:
			if x.measure(t, wt, f) <= 2 * (hw.call(absf(yc) + f * .5) - 6) or f <= mn: break
			f -= 1
		return f
	x.text("EXPLORE", 100, 200 - 52, 700, fitHex.call("EXPLORE", 700, 18, -52, 9), "#a9bfd2", "center")
	var vt := str(maxi(0, int(ws.v)))
	var changed: bool = int(ws.v) != int(w.v)
	x.text(vt, 100, 200 + (6 if changed or dead else 12), 700, fitHex.call(vt, 700, 86, 4, 40), "#fff", "center", null, 0, "#e8508a" if dead else fc, 22)
	var lt = "DEPLETED" if dead else (("printed " + str(w.v)) if changed else null)
	if lt != null: x.text(lt, 100, 254, 600, fitHex.call(lt, 600, 17, 54, 8), "#e8508a" if dead else "#a9bfd2", "center")
	# stat boxes
	var stat := func(a: float, label: String, val: String, c: String):
		x.fill_rrect(a, 112, 128, 92, 12, "rgba(255,255,255,.06)")
		x.text(label, a + 12, 132, 600, x.fit(label, 600, 19, 104, 11), "#8fa6bb")
		x.text(val, a + 12, 172, 700, x.fit(val, 700, 46, 104, 20), c)
	var life_txt: String = "FOUND" if SHRules.t(ws.get("life")) else ("3–10%" if w.tags.has("alpha") else ((str(w.life) + "%") if SHRules.t(w.get("life")) else "—"))
	stat.call(196, "LIFE CHANCE", life_txt, "#6edc8c" if SHRules.t(ws.get("life")) else "#fff")
	stat.call(334, "BASE COST", str(w.base) if SHRules.t(w.get("base")) else "—", "#fff")
	x.fill_rrect(472, 112, 152, 92, 12, "rgba(255,255,255,.06)")
	x.text("PRODUCES", 484, 132, 600, x.fit("PRODUCES", 600, 19, 128, 11), "#8fa6bb")
	var pr: Dictionary = w.get("prod", {}) if w.get("prod") is Dictionary else {}
	if not pr.size(): x.text("—", 484, 172, 700, 46, "#fff")
	var i := 0
	for r in pr:
		var yy := 156 + i * 24
		x.circle(492, yy + 8, 7, RESC.get(r, "#fff"))
		var t := "%s %s" % [r, str(pr[r])]
		x.text(t, 506, yy + 9, 700, x.fit(t, 700, 26, 112, 14), "#fff")
		i += 1
	# tags and state
	var chips := []
	for tg in w.tags:
		if TAGTXT.has(tg): chips.append([TAGTXT[tg], "#9fc3dd", false])
	if w.tags.has("alpha"): chips += [["d10 per success:", "#e8d27a", false], ["1-4 Physics 3%", "#5aaaff", true], ["5-7 Engineering 5%", "#d5dbe6", false], ["8-10 Biology 10%", "#6edc8c", false]]
	if SHRules.t(ws.get("sol")): chips.append(["Solar power", "#f2b13c", false])
	if D.TERRA.has(k): chips.append(["Terraform %s/%s" % [str(ws.get("terra", 0)), str(D.TERRA[k])], "#6edc8c", false])
	if SHRules.t(ws.get("npf")): chips.append(["%s base" % _npf_name(k, ws), "#c9a6ff", false])
	if SHRules.t(ws.get("blk")): chips.append(["BLOCKADED", "#e8508a", false])
	var limit: float = 314.0 if w.get("rng") != null else 338.0
	var W0 := 428.0
	var lay := func(f: float) -> Dictionary:
		var pad := f * .52
		var hh := f * 1.5
		var out := []
		var cx := 196.0
		var cy := 236.0
		var ok := true
		for ch in chips:
			var wd: float = x.measure(ch[0], 600, f) + pad * 2
			if wd > W0: ok = false
			if cx + wd > 196 + W0 and cx > 196:
				cx = 196
				cy += hh + 8
			out.append({"t": ch[0], "col": ch[1], "x": cx, "y": cy, "wd": wd, "hh": hh, "pad": pad})
			cx += wd + 10
			if ch[2]: cx = 196 + W0 + 1
		return {"out": out, "ok": ok and (not out.size() or out[out.size() - 1].y + hh <= limit)}
	var fz := 25.0
	var rows: Dictionary
	while true:
		rows = lay.call(fz)
		if rows.ok or fz <= 13: break
		fz -= 1
	for c in rows.out:
		x.fill_rrect(c.x, c.y, c.wd, c.hh, c.hh / 2, "rgba(255,255,255,.07)")
		x.stroke_rrect(c.x, c.y, c.wd, c.hh, c.hh / 2, c.col, 2)
		x.text(c.t, c.x + c.pad, c.y + c.hh / 2 + 1, 600, fz, c.col)
	if w.get("rng") != null:
		var rt := "random world d100 %s–%s" % [str(w.rng[0]), str(w.rng[1])]
		x.text(rt, 616, 326, 500, x.fit(rt, 500, 19, 400, 11), "#6f879b", "right")
	if dead: x.fill_rrect(6, 6, 628, 340, 24, "rgba(20,0,0,.28)")
	_paint_tray(n, k, ws, w, P.nb)

func _asm_kind(w: Dictionary) -> Dictionary:
	var t: Array = w.tags
	var earth := t.has("earth")
	var gas := t.has("gas")
	return {"base": SHRules.t(w.get("base")) or gas or earth, "card": not earth and (SHRules.t(w.get("base")) or gas)}

func _paint_tray(n: Node2D, k: String, ws: Dictionary, w: Dictionary, nb: int) -> void:
	var kd := _asm_kind(w)
	if not kd.base: return
	var D: Dictionary = Game.data.D
	var x := Pen.new(n)
	x.k = K25
	# base tray: a slot (and a trade-marker pad) appears for each base as it is built
	if nb > 0:
		var rows := ceili(nb / 4.0)
		x.fill_rrect(0, 151, 356, 6 + rows * 50 - 6, 9, "rgba(4,12,26,.82)")
		x.stroke_rrect(0, 151, 356, 6 + rows * 50 - 6, 9, "rgba(150,190,230,.35)", 1.4)
		x.text("BASES", 351, 158, 700, 7, "#7f98ad", "right")
		for i in mini(nb, 8):
			var s := slot_base(i)
			var cx: float = s[0]
			var cz: float = s[1]
			x.stroke_rrect(cx - 22, cz - 22, 44, 44, 5, "rgba(160,200,240,.55)", 1.3)
			x.dash_rrect(cx + 26, cz - 15, 30, 30, 4, "rgba(160,200,240,.35)", 1, 2.5, 2.5)
			x.text("TRADE", cx + 41, cz, 600, 7, "rgba(160,200,240,.35)", "center")
	# life slot
	var no_life: bool = w.tags.has("earth")
	var lx: float = SLOT_LIFE[0]
	var lz: float = SLOT_LIFE[1]
	var life := SHRules.t(ws.get("life"))
	var sol := SHRules.t(ws.get("sol"))
	var lc := "#6edc8c" if life else ("#f2b13c" if sol else "rgba(160,200,240,.4)")
	if not no_life:
		x.circle(lx, lz, 15, "rgba(4,12,26,.82)")
		x.ring(lx, lz, 15, lc, 2)
		x.text("✓" if life else ("~" if sol else "?"), lx, lz + .5, 700, 12, lc, "center")
		x.text("LIFE", lx + 21, lz - 6, 600, 7, "#8fa6bb")
		x.text("FOUND" if life else ("SIGNS" if sol else "NOT FOUND"), lx + 21, lz + 5, 700, 9, "#6edc8c" if life else ("#f2b13c" if sol else "#9fb7cc"))
	# card slot
	if kd.card:
		var cx: float = SLOT_CARD[0]
		var cz: float = SLOT_CARD[1]
		var cw: float = SLOT_CARD[2]
		var ch: float = SLOT_CARD[3]
		var X := cx - cw / 2
		var Y := cz - ch / 2
		var c = SHRules._find(D.CARDS, func(q): return q.n == ws.get("card")) if SHRules.t(ws.get("card")) else null
		if c == null:
			x.dash_rrect(X, Y, cw, ch, 8, "rgba(160,200,240,.45)", 1.3, 4, 3)
			x.text("WORLD CARD", cx, cz - 6, 700, x.fit("WORLD CARD", 700, 9, cw - 14, 5), "#9fb7cc", "center")
			x.text("placed on depletion", cx, cz + 6, 500, x.fit("placed on depletion", 500, 7, cw - 14, 4), "#6f879b", "center")
		else:
			var col: String = FIELD.get(c.rf, ["#9ad"])[0]
			x.fill_rrect(X, Y, cw, ch, 8, "rgba(4,12,26,.92)")
			x.stroke_rrect(X, Y, cw, ch, 8, col, 1.8)
			x.alpha = .2
			x.fill_rrect(X, Y, cw, 16, 8, col)
			x.alpha = 1.0
			var fs := 11.0
			while x.measure(c.n, 700, fs) > 100 and fs > 6: fs -= .5
			x.text(c.n, X + 6, Y + 8.5, 700, fs, "#eaf6ff")
			var hx := _hex(X + 22, Y + 40, 16)
			x.fill_poly(hx, "rgba(255,255,255,.07)")
			x.stroke_poly(hx, col, 1.8)
			x.text(str(c.rv), X + 22, Y + 41, 700, 21, "#fff", "center", null, 0, col, 6)
			x.text(String(FIELD.get(c.rf, ["", ""])[1]).substr(0, 3), X + 22, Y + 52, 600, 6, "#a9bfd2", "center")
			var yy := Y + 26
			for r in c.prod:
				if not SHRules.t(c.prod[r]): continue
				x.circle(X + 46, yy, 3.2, RESC.get(r, "#fff"))
				var t := "%s %s" % [r, str(c.prod[r])]
				x.text(t, X + 53, yy + .5, 700, x.fit(t, 700, 10, X + cw - 6 - (X + 53), 5), "#fff")
				yy += 12
			var parts := []
			for a in c.bonus: parts.append("+%s %s" % [str(c.bonus[a]), BONUS.get(a, a)])
			if SHRules.t(c.get("lifeB")): parts.append("+%s%% life" % str(c.lifeB))
			var bt := "EXPLORE " + " · ".join(parts)
			x.text(bt, X + 6, Y + ch - 5, 600, x.fit(bt, 600, 6.5, cw - 10, 3.5), "#9fc3dd")
