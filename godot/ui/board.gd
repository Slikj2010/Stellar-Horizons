## The 2D game board: the printed map tiles, then every counter and marker drawn on top from the game state.
## Positions come from data/geo.json (the same map geometry the web version uses). Clicks are resolved by pick_at().
extends Node2D

const CS := 62.0  ## counter size on the board (map pixels)
const DOTR := {"ear": 152, "mar": 136, "jup": 312, "ura": 232, "bel": 136, "kui": 142, "sca": 149}
const STATION_ALT := {"as": true, "sa": true}  ## factions whose alternate base image is the station
const MIS_COL := {"mine": Color("#f2a93b"), "common": Color("#4fb3e8"), "dated": Color("#e2675b")}
const C_SEL := Color("#f2a93b")
const C_READY := Color("#4fc3d9")
const C_ZONE := Color(0.31, 0.765, 0.851, 0.16)

var geo: Dictionary
var markers_tex: Texture2D
var markers_fr: Dictionary
var life_tex: Texture2D
var atl := {}  ## faction -> {"tex": Texture2D, "fr": {key: [x, y, w, h]}}
var hits: Array = []  ## clickable things from the last draw, topmost last
var targets: Array = []  ## legal moves of the selected ship (shown as zones)
var font: Font
var _rings := {}
var _boxf := {}
var _hulls := {}
var fx: Node2D  ## animated planets, sun and exploration boxes (board_fx.gd)
var ghost = null  ## {f, img, p, dest}: a counter being dragged on the map

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	geo = _json("res://data/geo.json")
	font = load("res://assets/fonts/Inter-SemiBold.otf")
	for k in geo.maps:
		var r: Array = geo.maps[k]
		var sp := Sprite2D.new()
		sp.texture = load("res://assets/maps/%s.webp" % k)
		sp.centered = false
		sp.position = Vector2(r[0], r[1])
		sp.z_index = -10
		add_child(sp)
	markers_tex = load("res://assets/markers.webp")
	markers_fr = _json("res://assets/markers.json")
	life_tex = load("res://assets/lifemk.webp")
	for f in Game.data.D.FAC:
		atl[f] = {"tex": load("res://assets/atlas_%s.webp" % f), "fr": _json("res://assets/atlas_%s.json" % f)}
	Game.changed.connect(queue_redraw)
	fx = preload("res://ui/board_fx.gd").new()
	fx.z_index = -5
	add_child(fx)
	fx.setup(self)

static func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else {}

## bounds of the whole map, for the camera
func map_rect() -> Rect2:
	var r := Rect2()
	for k in geo.maps:
		var m: Array = geo.maps[k]
		r = r.merge(Rect2(m[0], m[1], m[2], m[3]))
	return r

# ---------------- geometry (ported from the web board) ----------------
func v2(a) -> Vector2: return Vector2(a[0], a[1])
func hull(poly: Array) -> PackedVector2Array:
	var key := str(poly[0]) + str(poly.size())
	if _hulls.has(key): return _hulls[key]
	var pts := PackedVector2Array()
	for q in poly: pts.append(v2(q))
	var h := Geometry2D.convex_hull(pts)
	if h.size() > 1: h.remove_at(h.size() - 1)
	_hulls[key] = h
	return h
func poly_h(poly: Array) -> float:
	var lo := INF
	var hi := -INF
	for q in poly:
		lo = minf(lo, q[1])
		hi = maxf(hi, q[1])
	return hi - lo
func pos_of(loc: String) -> Vector2:
	var p := Game.E.P(loc)
	if p.t == "earth":
		var o = geo.worlds.ear.get("surf", geo.worlds.ear.orbit)
		return Vector2(o[0], o[1] + 20)
	if p.t == "fly": return v2(geo.sys[p.s].flyby)
	if p.t == "box": return v2(geo.sys[p.s].box[str(p.n)])
	var g: Dictionary = geo.worlds[p.w]
	if p.t == "surf": return v2(g.surf) if g.has("surf") else v2(g.orbit) + Vector2(0, 34)
	if p.w == "ear": return v2(g.orbit) - Vector2(0, 110)
	if g.has("surf"): return v2(g.orbit) - Vector2(0, poly_h(g.poly) * .3 if g.has("poly") else 60.0)
	return v2(g.orbit) - Vector2(0, 24)
func world_center(k: String) -> Vector2:
	var g: Dictionary = geo.worlds[k]
	return v2(g.orbit) if g.has("orbit") else v2(g.exp)
## orbit ring of a world: the printed dotted orbit where the map has one, otherwise just outside the world's circle
func ring_of(w: String) -> Dictionary:
	if _rings.has(w): return _rings[w]
	var g: Dictionary = geo.worlds[w]
	if not g.has("poly"):
		_rings[w] = {"c": world_center(w), "r": 60 + CS / 2 + 6}
		return _rings[w]
	var hp := hull(g.poly)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q in hp:
		mn = mn.min(q)
		mx = mx.max(q)
	var c := (mn + mx) / 2
	var half := (mx.x - mn.x + mx.y - mn.y) / 4
	var circle: float = g.get("circ", half * (.59 if g.has("spoly") else .79))
	_rings[w] = {"c": c, "r": DOTR.get(w, circle + CS / 2 + 12)}
	return _rings[w]
## counters in a transfer box sit along the box, turned to face outward
func box_frame(sy: String, k: int) -> Dictionary:
	var key := sy + str(k)
	if _boxf.has(key): return _boxf[key]
	var q: Array = geo.sys[sy].boxPoly[str(k)]
	var fit = geo.sys[sy].get("boxFit", {}).get(str(k))
	var c: Vector2
	if fit != null: c = Vector2(fit[0], fit[1])
	else:
		for p in q: c += v2(p)
		c /= q.size()
	var hubk = Game.data.D.SYS[sy].hub
	var hub: Vector2 = ring_of(hubk).c if (hubk != null and geo.worlds.has(hubk)) else v2(geo.sys[sy].flyby)
	var outa := atan2(c.y - hub.y, c.x - hub.x) + PI / 2
	var e: float = deg_to_rad(fit[2]) if fit != null else atan2(q[1][1] - q[0][1], q[1][0] - q[0][0])
	var best := e
	var bd := 9.0
	for i in range(-4, 5):
		var a := e + i * PI / 2
		var d := absf(atan2(sin(a - outa), cos(a - outa)))
		if d < bd:
			bd = d
			best = a
	_boxf[key] = {"c": c, "a": best}
	return _boxf[key]
## the clickable zone of a destination
func zone(loc: String) -> Dictionary:
	var p := Game.E.P(loc)
	var g = geo.worlds.get(p.w) if p.w != null else null
	if p.t == "fly": return {"poly": hull(geo.sys[p.s].flybyPoly)}
	if p.t == "box": return {"poly": hull(geo.sys[p.s].boxPoly[str(p.n)])}
	if p.t == "earth" and geo.worlds.ear.has("spoly"): return {"poly": hull(geo.worlds.ear.spoly)}
	if p.t == "surf" and g != null and g.has("spoly"): return {"poly": hull(g.spoly)}
	if p.t == "orbit" and g != null and g.has("poly"): return {"poly": hull(g.poly)}
	return {"c": pos_of(loc), "r": 44.0}
func in_zone(z: Dictionary, pt: Vector2) -> bool:
	if z.has("poly"): return Geometry2D.is_point_in_polygon(pt, z.poly)
	return pt.distance_to(z.c) <= z.r
## where world cards and bases sit (the printed world-card box)
func wcard_frame(k: String):
	var g = geo.worlds.get(k)
	if g == null or not g.has("wcard"): return null
	var wc: Array = g.wcard
	return {"o": Vector2(wc[0], wc[1]), "a": deg_to_rad(wc[2]), "CW": float(wc[3]), "CH": wc[3] * 127.0 / 192.0, "noCard": Game.data.D.W.has(k) and Game.data.D.W[k].tags.has("earth")}
func wat(F: Dictionary, lx: float, ly: float) -> Vector2: return F.o + Vector2(lx, ly).rotated(F.a)

# ---------------- drawing helpers ----------------
func frame_rect(fr: Array) -> Rect2: return Rect2(fr[0], fr[1], fr[2], fr[3])
## draw an atlas frame centred at p, fitted to size, turned by rot
func draw_frame(tex: Texture2D, fr, p: Vector2, size: float, rot := 0.0, mod := Color.WHITE) -> void:
	if fr == null or tex == null: return
	var k: float = size / maxf(fr[2], fr[3])
	var sz := Vector2(fr[2] * k, fr[3] * k)
	draw_set_transform(p, rot)
	draw_texture_rect_region(tex, Rect2(-sz / 2, sz), frame_rect(fr), mod)
	draw_set_transform(Vector2.ZERO)
func unit_frame(f: String, key: String):
	return atl[f].fr.get(key)
func draw_box(p: Vector2, size: float, col: Color, w := 3.0, rot := 0.0) -> void:
	draw_set_transform(p, rot)
	draw_rect(Rect2(-Vector2(size, size) / 2, Vector2(size, size)), col, false, w)
	draw_set_transform(Vector2.ZERO)
func text(s: String, p: Vector2, size: int, col: Color, outline := true) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := p + Vector2(-w / 2, size * 0.35)
	if outline: draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
func base_key(b: Dictionary, f: String) -> String:
	var fr: Dictionary = atl[f].fr
	var pre: String = "H Go" if b.name == "Honse Gongdian" else String(b.name).substr(0, 4)
	var keys := fr.keys().filter(func(k): return String(k).begins_with("Base|" + pre))
	if not keys.size(): keys = fr.keys().filter(func(k): return String(k).begins_with("Base|" + pre.substr(0, 3)))  # Asia's Aatma is 'Aatama' on the counter
	if not keys.size(): return ""
	var rx := RegEx.create_from_string("(?i) (b|rv|bi|orbit)$")
	var plain = SHRules._find(keys, func(k): return rx.search(k) == null)
	if plain == null: plain = keys[0]
	var alt = SHRules._find(keys, func(k): return k != plain)
	if alt == null: alt = plain
	var station: bool = Game.E.basePos(b) == "orbit"
	return plain if station != STATION_ALT.has(f) else alt

# ---------------- the board ----------------
func _draw() -> void:
	hits = []
	var G = Game.G
	if G == null: return
	var E: SHRules = Game.E
	var D: Dictionary = Game.data.D
	var sel = Game.sel
	# worlds: current exploration values, missions, terraforming
	for k in geo.worlds:
		var ws = G.w.get(k)
		if ws == null: continue
		var g: Dictionary = geo.worlds[k]
		var wc := world_center(k)
		if g.has("poly"): hits.append({"t": "world", "k": k, "poly": hull(g.poly)})
		else: hits.append({"t": "world", "k": k, "c": wc, "r": 60.0})
		if sel != null and sel.t == "world" and sel.k == k:
			if g.has("poly"):
				var h := hull(g.poly)
				var closed := h.duplicate()
				closed.append(h[0])
				draw_polyline(closed, C_SEL, 5)
			else: draw_arc(wc, 60, 0, TAU, 48, C_SEL, 5)
		# the exploration value is painted by board_fx.gd over the printed box when it has changed
		var i := 0
		for x in E.missionsAt(G, k):
			var fr = markers_fr.get(D.MIS[x.id].mk)
			if fr == null: continue
			var mp := wc + Vector2(-104 - i * 58, -34)
			draw_frame(markers_tex, fr, mp, 50)
			draw_rect(Rect2(mp - Vector2(27, 27), Vector2(54, 54)), MIS_COL[x.kind], false, 3)
			hits.append({"t": "world", "k": k, "c": mp, "r": 25.0})
			i += 1
		if D.TERRA.has(k) and SHRules.t(ws.terra): text("Terraformed %d/%d" % [ws.terra, D.TERRA[k]], wc + Vector2(0, -64), 14, Color("#5fcf8a"))
	# world cards, life markers and bases in each world's card box
	_draw_world_boxes(G, D)
	# pirates and asteroids in the flyby boxes
	for s in G.fly:
		var fly = geo.sys.get(s)
		if fly == null: continue
		var p := v2(fly.flyby)
		var i := 0
		for pr in G.fly[s].pir:
			draw_frame(markers_tex, markers_fr.get("pir_l" if pr.strong else "pir_s"), p + Vector2(-26 + i * 22, -34), 46)
			if SHRules.t(pr.dmg): text("dmg %d" % pr.dmg, p + Vector2(-26 + i * 22, -4), 11, Color("#ef6b5b"))
			i += 1
		for j in G.fly[s].ast: draw_frame(markers_tex, markers_fr.get("ast"), p + Vector2(26 + j * 16, 34), 42)
	# ships (own and other factions'); ships waiting on Earth live on the faction board, not on the map
	var by_loc := {}
	for s in G.ships:
		if s.loc != "earth": by_loc[s.loc] = by_loc.get(s.loc, []) + [[s, ""]]
	if G.world != null:
		for f in G.world.facs:
			if f == G.f: continue
			for s in G.world.facs[f].ships:
				if s.loc != "earth": by_loc[s.loc] = by_loc.get(s.loc, []) + [[s, f]]
	for loc in by_loc:
		_draw_stack(G, E, loc, by_loc[loc])
	# move targets
	if targets.size():
		var seen := {}
		var dests := {}
		for m in targets: dests[m.dest] = true
		for m in targets:
			if seen.has(m.dest): continue
			seen[m.dest] = true
			var z := zone(m.dest)
			if z.has("poly"):
				draw_colored_polygon(z.poly, C_ZONE)
				var closed: PackedVector2Array = z.poly.duplicate()
				closed.append(z.poly[0])
				draw_polyline(closed, C_READY, 4)
			else:
				draw_circle(z.c, z.r, C_ZONE)
				draw_arc(z.c, z.r, 0, TAU, 40, C_READY, 4)
			var lbl: String = m.label
			if SHRules.t(m.get("eta")): lbl += " · %dt" % m.eta
			var zc: Vector2 = pos_of(m.dest)
			text(lbl, zc + Vector2(0, 46), 15, C_READY)
	# a counter being dragged to a destination
	if ghost != null:
		if ghost.get("dest", "") != "":
			var z := zone(ghost.dest)
			if z.has("poly"): draw_colored_polygon(z.poly, Color(C_SEL, 0.25))
			else: draw_circle(z.c, z.r, Color(C_SEL, 0.25))
		draw_box(ghost.p, CS * 1.2 + 6, C_SEL, 3)
		draw_frame(atl[ghost.f].tex, unit_frame(ghost.f, ghost.img), ghost.p, CS * 1.2, 0, Color(1, 1, 1, 0.9))

func _draw_world_boxes(G, D: Dictionary) -> void:
	const LS := 56.0
	const BS := CS + 10
	const TS := 50.0
	const GAP := 14.0
	for k in geo.worlds:
		var ws = G.w.get(k)
		if ws == null: continue
		var bases := []
		for b in G.bases:
			if b.w == k: bases.append([b, G.f])
		if G.world != null:
			for f in G.world.facs:
				if f == G.f: continue
				for b in G.world.facs[f].bases:
					if b.w == k: bases.append([b, f])
		if SHRules.t(ws.npf): bases.append([{"id": "npf:" + k, "name": String(Game.E.npfName(G, k)), "w": k, "set": 0, "npf": true, "trade": ws.npfTrade, "blk": ws.blk}, ws.npf])
		if not SHRules.t(ws.card) and not SHRules.t(ws.sol) and not SHRules.t(ws.life) and not bases.size(): continue
		var F = wcard_frame(k)
		if F == null: continue
		if SHRules.t(ws.card):
			var c = SHRules._find(D.CARDS, func(x): return x.n == ws.card)
			if c != null: draw_frame(markers_tex, markers_fr.get("card_" + c.img), wat(F, 0, 0), F.CW, F.a)
		if SHRules.t(ws.sol) or SHRules.t(ws.life):
			draw_frame(life_tex, [96 if SHRules.t(ws.life) else 0, 0, 96, 96], wat(F, F.CW / 2 + 10 + LS / 2, 0), LS, F.a)
		var row_y: float = 0.0 if F.noCard else F.CH / 2 + GAP + BS / 2
		var unit := BS + 8 + TS + 14
		var i := 0
		for pair in bases:
			var b: Dictionary = pair[0]
			var bf: String = pair[1]
			var lx: float = -F.CW / 2 + BS / 2 + i * unit
			var p := wat(F, lx, row_y)
			i += 1
			draw_frame(atl[bf].tex, unit_frame(bf, base_key(b, bf)), p, BS, F.a)
			if SHRules.t(b.get("npf")):
				hits.append({"t": "npf", "k": k, "c": p, "r": BS / 2, "f": bf, "img": base_key(b, bf)})
				if Game.sel != null and Game.sel.t == "npf" and Game.sel.k == k: draw_box(p, BS + 6, C_SEL, 3, F.a)
				if SHRules.t(b.trade): draw_frame(markers_tex, markers_fr.get(("buy_" if b.trade.side == "buy" else "sell_") + b.trade.type), wat(F, lx + BS / 2 + 8 + TS / 2, row_y), TS, F.a)
				if SHRules.t(b.blk): text("BLOCKADED", wat(F, lx, row_y + BS / 2 + 12), 11, Color("#ef6b5b"))
				continue
			if bf != G.f:
				draw_box(p, BS + 4, Color(D.FAC[bf].c), 3, F.a)
				hits.append({"t": "obase", "f": bf, "name": b.name, "w": b.w, "c": p, "r": BS / 2, "img": base_key(b, bf)})
			else: hits.append({"t": "base", "id": b.id, "c": p, "r": BS / 2, "f": bf, "img": base_key(b, bf)})
			if Game.sel != null and Game.sel.t == "base" and SHRules.eq(Game.sel.get("id"), b.id): draw_box(p, BS + 6, C_SEL, 3, F.a)
			if SHRules.t(b.get("trade")) and bf == G.f: draw_frame(markers_tex, markers_fr.get(("buy_" if b.trade.side == "buy" else "sell_") + b.trade.type), wat(F, lx + BS / 2 + 8 + TS / 2, row_y), TS, F.a)
			if b.set > 0: text("%d settl." % b.set, wat(F, lx, row_y + BS / 2 + 12), 12, Color("#5fcf8a"))

func _draw_stack(G, E: SHRules, loc: String, lst: Array) -> void:
	var p := pos_of(loc)
	var lp := E.P(loc)
	var cols := mini(lst.size(), 3)
	var i := 0
	for pair in lst:
		var s: Dictionary = pair[0]
		var of: String = pair[1]
		var c := p + Vector2(((i % 3) - (cols - 1) / 2.0) * (CS + 4), floorf(i / 3.0) * (CS + 4))
		var rot := 0.0
		if lp.t == "orbit" and geo.worlds.has(lp.w):
			var R := ring_of(lp.w)
			var sep := 2 * asin(minf(1.0, (CS + 8) / 2 / R.r))
			var a := -PI / 2 + (i - (lst.size() - 1) / 2.0) * sep
			c = R.c + Vector2(cos(a), sin(a)) * R.r
		elif lp.t == "box":
			var B := box_frame(lp.s, lp.n)
			rot = B.a
			var off := (i - (lst.size() - 1) / 2.0) * 9
			c = B.c + Vector2(off * cos(rot) - off * .6 * sin(rot), off * sin(rot) + off * .6 * cos(rot))
		elif lp.t == "surf" and geo.worlds.has(lp.w) and not geo.worlds[lp.w].has("spoly"):
			var R := ring_of(lp.w)
			c = R.c + Vector2(((i % 3) - (cols - 1) / 2.0) * (CS + 4), floorf(i / 3.0) * (CS + 4))
		i += 1
		if of != "":
			draw_box(c, CS + 6, Color(Game.data.D.FAC[of].c), 3, rot)
			draw_frame(atl[of].tex, unit_frame(of, s.img + "|back" if SHRules.t(s.res) else s.img), c, CS, rot)
			hits.append({"t": "oship", "f": of, "id": s.id, "c": c, "r": CS / 2, "img": s.img})
			continue
		var ready: bool = (G.phase == "move" and E.moves(G, s).size() > 0) or (G.phase == "explore" and E.exploreOptions(G, s).size() > 0)
		var is_sel: bool = Game.sel != null and Game.sel.t == "ship" and SHRules.eq(Game.sel.get("id"), s.id)
		if ready or is_sel: draw_box(c, CS + 8, C_SEL if is_sel else C_READY, 3, rot)
		draw_frame(atl[G.f].tex, unit_frame(G.f, s.img + "|back" if SHRules.t(s.res) else s.img), c, CS, rot)
		if SHRules.t(s.dmg): text("▼%d" % s.dmg, c + Vector2(22, -24), 13, Color("#ef6b5b"))
		if SHRules.t(s.hold): text("+%d" % s.hold, c + Vector2(22, 24), 13, C_SEL)
		if SHRules.t(s.probe): draw_frame(atl[G.f].tex, unit_frame(G.f, "Probe|" + s.probe), c + Vector2(-24, 24), 24)
		hits.append({"t": "ship", "id": s.id, "c": c, "r": CS / 2, "f": G.f, "img": s.img})

## the move target under a map point, or ""
func dest_at(pt: Vector2) -> String:
	var ordered := SHRules.ssort(targets, func(a, b): return (0 if Game.E.P(a.dest).t != "orbit" else 1) - (0 if Game.E.P(b.dest).t != "orbit" else 1))
	for m in ordered:
		if in_zone(zone(m.dest), pt): return m.dest
	return ""

## what is under a map point: a counter first, then a move target, then a world
func pick_at(pt: Vector2) -> Dictionary:
	for i in range(hits.size() - 1, -1, -1):
		var h: Dictionary = hits[i]
		if h.t == "world": continue
		if h.has("c") and pt.distance_to(h.c) <= h.r: return h
	if targets.size():
		# surfaces sit inside their orbit zones: test them first
		var ordered := SHRules.ssort(targets, func(a, b): return (0 if Game.E.P(a.dest).t != "orbit" else 1) - (0 if Game.E.P(b.dest).t != "orbit" else 1))
		for m in ordered:
			if in_zone(zone(m.dest), pt): return {"t": "dest", "dest": m.dest}
	for i in range(hits.size() - 1, -1, -1):
		var h: Dictionary = hits[i]
		if h.t != "world": continue
		if h.has("poly") and Geometry2D.is_point_in_polygon(pt, h.poly): return h
		if h.has("c") and pt.distance_to(h.c) <= h.r: return h
	return {}
