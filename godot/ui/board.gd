## The 2D game board: the printed map tiles, then every counter and marker drawn on top from the game state.
## Positions come from data/geo.json (the same map geometry the web version uses). The counters are painted by
## paint_objects(), a port of the web version's paintObjects(): on the flat map it draws them, and while the 2.5D view
## is on it records them for that view instead (as the web version's paint25 does). Clicks are resolved by pick_at().
extends Node2D

const CS := 62.0  ## counter size on the board (map pixels)
const DOTR := {"ear": 152, "mar": 136, "jup": 312, "ura": 232, "bel": 136, "kui": 142, "sca": 149}
const STATION_ALT := {"as": true, "sa": true}  ## factions whose alternate base image is the station
const MIS_COL := {"mine": Color("#ee5f74"), "common": Color("#7fa9d6"), "dated": Color("#e2675b")}
const C_SEL := Color("#ee5f74")
const C_READY := Color("#7fa9d6")
const C_ZONE := Color(0.498, 0.663, 0.839, 0.16)
const WB := {"LS": 56.0, "BS": CS + 10, "TS": 50.0, "GAP": 14.0}
const RING_LABEL := {"jup": [-PI / 2, .2]}

var geo: Dictionary
var geo_std: Dictionary  ## the printed sheet layout (the 2.5D view is built on it)
var geo_flat: Dictionary  ## the same map with the sections laid out as a winding path
var flat_on := false
var _sprites := {}
const LAYOUT_GAP := 330.0
const LAYOUT_AMP := 560.0
const LAYOUT_FREQ := 0.9
var markers_tex: Texture2D
var markers_fr: Dictionary
var life_tex: Texture2D
var atl := {}  ## faction -> {"tex": Texture2D, "fr": {key: [x, y, w, h]}}
var hits: Array = []  ## clickable things from the last paint, topmost last
var targets: Array = []  ## legal moves of the selected ship (shown as zones)
var font: Font
var _rings := {}
var _boxf := {}
var _hulls := {}
var _block := {}
var _wrects = null
var expb: Dictionary
var fx: Node2D  ## animated planets, sun and exploration boxes (board_fx.gd)
var ghost = null  ## {f, img, p, dest, id}: a counter being dragged on the map
var v25 = null  ## the 2.5D view while it is on: paint_objects() records for it
var v25_ring = null  ## the 2.5D view's Sun Observation ring (round the Sun)
var R = null  ## the recorder during paint_objects(), or null when drawing

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	geo_std = _json("res://data/geo.json")
	geo = geo_std
	geo_flat = _make_flat(geo_std)
	font = V25Paint.font(600)
	expb = _json("res://assets/expbox.json")
	for k in geo.maps:
		var r: Array = geo.maps[k]
		var sp := Sprite2D.new()
		sp.texture = load("res://assets/maps/%s.webp" % k)
		sp.centered = false
		sp.position = Vector2(r[0], r[1])
		sp.z_index = -10
		add_child(sp)
		_sprites[k] = sp
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
	set_layout(true)

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
## convex hull (the web version's monotone chain, without collinear points)
func hull(poly: Array) -> PackedVector2Array:
	var key := str(poly[0]) + str(poly.size()) + str(poly[poly.size() - 1])
	if _hulls.has(key): return _hulls[key]
	var P := []
	for q in poly: P.append(v2(q))
	P.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var cr := func(o: Vector2, a: Vector2, b: Vector2) -> float: return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
	var lo := []
	var up := []
	for q in P:
		while lo.size() >= 2 and cr.call(lo[lo.size() - 2], lo[lo.size() - 1], q) <= 0: lo.pop_back()
		lo.append(q)
	for i in range(P.size() - 1, -1, -1):
		var q: Vector2 = P[i]
		while up.size() >= 2 and cr.call(up[up.size() - 2], up[up.size() - 1], q) <= 0: up.pop_back()
		up.append(q)
	lo.pop_back()
	up.pop_back()
	var h := PackedVector2Array(lo + up)
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
## (in the 2.5D view, Sun Observation is the circle round the Sun)
func ring_of(w: String) -> Dictionary:
	if w == "sun" and v25 != null and v25_ring != null: return v25_ring
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
func reset_rings() -> void:
	_block.clear()
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
## the zone of a destination (zoneShape): {poly, hole} or {c, r}
func zone_shape(loc: String, holes := false) -> Dictionary:
	var p := Game.E.P(loc)
	var g = geo.worlds.get(p.w) if p.w != null else null
	if p.t == "fly": return {"poly": hull(geo.sys[p.s].flybyPoly)}
	if p.t == "box": return {"poly": PackedVector2Array(Array(geo.sys[p.s].boxPoly[str(p.n)]).map(func(q): return v2(q)))}
	if p.t == "earth": return {"poly": PackedVector2Array(Array(geo.worlds.ear.spoly).map(func(q): return v2(q)))} if geo.worlds.ear.has("spoly") else {"c": pos_of(loc), "r": 44.0}
	if p.t == "surf" and g.has("spoly"): return {"poly": hull(g.spoly)}
	if p.t == "orbit" and g.has("poly"): return {"poly": hull(g.poly), "hole": hull(g.spoly) if (holes and g.has("spoly")) else null}
	return {"c": pos_of(loc), "r": 44.0}
func zone(loc: String) -> Dictionary: return zone_shape(loc)
func in_zone(z: Dictionary, pt: Vector2) -> bool:
	if z.has("poly"): return Geometry2D.is_point_in_polygon(pt, z.poly)
	return pt.distance_to(z.c) <= z.r
## where world cards and bases sit (the printed world-card box)
func wcard_frame(k: String):
	var g = geo.worlds.get(k)
	if g == null or not g.has("wcard"): return null
	var wc: Array = g.wcard
	return {"o": Vector2(wc[0], wc[1]), "a": deg_to_rad(wc[2]), "CW": float(wc[3]), "CH": wc[3] * 127.0 / 192.0, "noCard": Game.data.D.W.has(k) and Game.data.D.W[k].tags.has("earth")}
func wat(F: Dictionary, lx: float, ly: float) -> Vector2:
	if F.get("abs", false): return Vector2(lx, ly)
	return F.o + Vector2(lx, ly).rotated(F.a)
## card + base row footprints, for keeping orbiting counters off them
func wcard_rects() -> Array:
	if _wrects != null: return _wrects
	_wrects = []
	for k in geo.worlds:
		var F = wcard_frame(k)
		if F != null: _wrects.append({"F": F, "w": F.CW + WB.LS + 10, "h": F.CH + WB.GAP + WB.BS, "cx": (WB.LS + 10) / 2, "cy": (WB.GAP + WB.BS) / 2})
	return _wrects

# ---------------- counters on an orbit ring never overlap (ringLayout) ----------------
static func ang_dist(a: float, b: float) -> float: return absf(atan2(sin(a - b), cos(a - b)))
## a spot is legal when the counter stays clear of the printed transfer boxes, flyby boxes and labels outside a world's circle
func ring_blocked(w: String, a: float) -> bool:
	var key := w + ":" + str(roundi(a * 180 / PI) % 360)
	if _block.has(key): return _block[key]
	var Rr := ring_of(w)
	var x: float = Rr.c.x + cos(a) * Rr.r
	var y: float = Rr.c.y + sin(a) * Rr.r
	var rad := CS / 2 + 2
	var hit_poly := func(q) -> bool:
		if q == null: return false
		var inside := false
		var j: int = q.size() - 1
		for i in q.size():
			var xi: float = q[i][0]
			var yi: float = q[i][1]
			var xj: float = q[j][0]
			var yj: float = q[j][1]
			if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi: inside = not inside
			var dx := xj - xi
			var dy := yj - yi
			var dd := dx * dx + dy * dy
			var t := clampf(((x - xi) * dx + (y - yi) * dy) / (dd if dd != 0 else 1.0), 0, 1)
			if Vector2(x - xi - t * dx, y - yi - t * dy).length() < rad: return true
			j = i
		return inside
	var b := false
	for S in geo.sys.values():
		for q in S.get("boxPoly", {}).values():
			if hit_poly.call(q):
				b = true
				break
		if b or hit_poly.call(S.flybyPoly):
			b = true
			break
	var L = RING_LABEL.get(w)
	if L != null and ang_dist(a, L[0]) < L[1]: b = true
	# other worlds' printed circles and every EXPLORE box
	if not b:
		for k in geo.worlds:
			var g: Dictionary = geo.worlds[k]
			if k != w and g.has("poly") and g.has("circ") and Vector2(x, y).distance_to(ring_of(k).c) < g.circ + rad:
				b = true
				break
	if not b:
		for RR in wcard_rects():
			var F: Dictionary = RR.F
			var dx: float = x - F.o.x
			var dy: float = y - F.o.y
			var ca := cos(-F.a)
			var sa := sin(-F.a)
			var u: float = dx * ca - dy * sa - RR.cx
			var v: float = dx * sa + dy * ca - RR.cy
			if absf(u) < RR.w / 2 + rad and absf(v) < RR.h / 2 + rad:
				b = true
				break
	if not b:
		for e in expb.values():
			var m: Array = geo.maps[e.map]
			if Vector2(x - (m[0] + e.cx * .4), y - (m[1] + e.cy * .4)).length() < e.s * .4 * .75 + rad:
				b = true
				break
	_block[key] = b
	return b
func free_angle(want: float, taken: Array, sep: float, w: String) -> float:
	for pass_ in 2:
		for k in 400:
			var d := ceili(k / 2.0) * sep / 6 * (1 if k % 2 else -1)
			var a := want + d
			var ok := true
			for t in taken:
				if ang_dist(a, t) < sep - 1e-6:
					ok = false
					break
			if ok and (pass_ == 1 or w == "" or not ring_blocked(w, a)): return a
	return want
## angle of each counter on a world's orbit ring
func ring_layout(w: String, lst: Array) -> Dictionary:
	var Rr := ring_of(w)
	var sep := 2 * asin(minf(1, (CS + 8) / 2 / Rr.r))
	var out := {}
	var taken := []
	var order := lst.filter(func(s): return s.get("ang") != null) + lst.filter(func(s): return s.get("ang") == null)
	for s in order:
		var a := free_angle(s.ang if s.get("ang") != null else -PI / 2, taken, sep, w)
		taken.append(a)
		out[s] = a
	return out

# ---------------- painting helpers (draw on the flat map, or record for the 2.5D view) ----------------
func frame_rect(fr: Array) -> Rect2: return Rect2(fr[0], fr[1], fr[2], fr[3])
## draw an atlas frame centred at p, fitted to size, turned by rot
func draw_frame(tex: Texture2D, fr, p: Vector2, size: float, rot := 0.0, mod := Color.WHITE) -> void:
	if fr == null or tex == null: return
	if R != null:
		R.sprite(tex, fr, p.x, p.y, size, rot)
		return
	var k: float = size / maxf(fr[2], fr[3])
	var sz := Vector2(fr[2] * k, fr[3] * k)
	draw_set_transform(p, rot)
	draw_texture_rect_region(tex, Rect2(-sz / 2, sz), frame_rect(fr), mod)
	draw_set_transform(Vector2.ZERO)
func unit_frame(f: String, key: String):
	return atl[f].fr.get(key)
func draw_box(p: Vector2, size: float, col: Color, w := 3.0, rot := 0.0) -> void:
	if R != null: return
	draw_set_transform(p, rot)
	draw_rect(Rect2(-Vector2(size, size) / 2, Vector2(size, size)), col, false, w)
	draw_set_transform(Vector2.ZERO)
## txt(): text with a black outline, centred (or left/right aligned) on p
func text(s: String, p: Vector2, size: int, col: Color, align := "center") -> void:
	if R != null:
		R.text(s, p.x, p.y, size, "#" + col.to_html(false), align)
		return
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := p + Vector2(-w / 2 if align == "center" else (-w if align == "right" else 0.0), (font.get_ascent(size) - font.get_descent(size)) / 2)
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, roundi(size / 5.0)), Color.BLACK)
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
func _mode(m: String, l: float) -> void:
	if R != null:
		R.mode = m
		R.lift = l


# ---------------- the flat layout: sections in a semi-linear progression ----------------
func _tile_of(maps: Dictionary, p) -> String:
	var best := "A"
	var bd := INF
	for k in maps:
		var m: Array = maps[k]
		var dx := maxf(maxf(m[0] - p[0], 0.0), p[0] - m[0] - m[2])
		var dy := maxf(maxf(m[1] - p[1], 0.0), p[1] - m[1] - m[3])
		var d := dx * dx + dy * dy
		if d < bd:
			bd = d
			best = k
	return best

## tile -> where its top-left corner goes in the flat layout (in order A..I, left to right, on a gentle S-curve)
func flat_origins(maps: Dictionary) -> Dictionary:
	var out := {}
	var x := 0.0
	var i := 0
	for k in maps.keys():
		var m: Array = maps[k]
		out[k] = Vector2(x, roundf(LAYOUT_AMP * sin(i * LAYOUT_FREQ)))
		x += m[2] + LAYOUT_GAP
		i += 1
	return out

func _make_flat(g: Dictionary) -> Dictionary:
	var f: Dictionary = g.duplicate(true)
	var org := flat_origins(g.maps)
	var dl := {}
	for k in g.maps:
		var m: Array = g.maps[k]
		dl[k] = org[k] - Vector2(m[0], m[1])
		f.maps[k] = [org[k].x, org[k].y, m[2], m[3]]
	var tp := func(a: Array, d: Vector2) -> Array: return [a[0] + d.x, a[1] + d.y]
	var tl := func(a: Array, d: Vector2) -> Array:
		var r := []
		for q in a: r.append([q[0] + d.x, q[1] + d.y])
		return r
	for k in f.worlds:
		var w: Dictionary = f.worlds[k]
		var d: Vector2 = dl[_tile_of(g.maps, w.orbit)]
		for key in ["orbit", "surf", "exp"]:
			if w.has(key): w[key] = tp.call(w[key], d)
		for key in ["poly", "spoly"]:
			if w.has(key): w[key] = tl.call(w[key], d)
		if w.has("wcard"):
			var c: Array = w.wcard.duplicate()
			c[0] += d.x
			c[1] += d.y
			w.wcard = c
	for k in f.sys:
		var S: Dictionary = f.sys[k]
		var d0: Vector2 = dl[_tile_of(g.maps, S.flyby)]
		S.flyby = tp.call(S.flyby, d0)
		S.flybyPoly = tl.call(S.flybyPoly, d0)
		for n in S.box:
			var d: Vector2 = dl[_tile_of(g.maps, g.sys[k].box[n])]
			S.box[n] = tp.call(S.box[n], d)
			S.boxPoly[n] = tl.call(S.boxPoly[n], d)
			if S.get("boxFit", {}).has(n):
				var bf: Array = S.boxFit[n].duplicate()
				bf[0] += d.x
				bf[1] += d.y
				S.boxFit[n] = bf
	return f

## switch between the winding-path layout (flat view) and the printed sheet layout (the 2.5D view)
func set_layout(flat: bool) -> void:
	flat_on = flat
	geo = geo_flat if flat else geo_std
	for k in _sprites:
		var m: Array = geo.maps[k]
		_sprites[k].position = Vector2(m[0], m[1])
	_rings.clear()
	_boxf.clear()
	_block.clear()
	_wrects = null
	if fx != null: fx.relayout()
	queue_redraw()

## glowing dashed lanes between consecutive sections, drawn only on the flat map
func _paint_lanes() -> void:
	if not flat_on: return
	var ks: Array = geo.maps.keys()
	for i in range(ks.size() - 1):
		var a: Array = geo.maps[ks[i]]
		var b: Array = geo.maps[ks[i + 1]]
		var p0 := Vector2(a[0] + a[2] - 40, a[1] + a[3] * 0.5)
		var p3 := Vector2(b[0] + 40, b[1] + b[3] * 0.5)
		var dx := (p3.x - p0.x) * 0.5
		var p1 := p0 + Vector2(dx, 0)
		var p2 := p3 - Vector2(dx, 0)
		var pts := PackedVector2Array()
		for j in range(41):
			var t := j / 40.0
			var u := 1.0 - t
			pts.append(u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3)
		for j in range(0, 40, 2):
			draw_line(pts[j], pts[j + 1], Color(0.45, 0.8, 0.95, 0.16), 14.0, true)
			draw_line(pts[j], pts[j + 1], Color(0.7, 0.92, 1.0, 0.75), 4.0, true)
		var dir := (pts[40] - pts[38]).normalized()
		var n := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pts[40] + dir * 8, pts[40] - dir * 52 + n * 30, pts[40] - dir * 52 - n * 30]), Color(0.7, 0.92, 1.0, 0.85))

# ---------------- the board ----------------
func _draw() -> void:
	if v25 != null: return
	R = null
	_paint_lanes()
	_paint_orbit_rings()
	paint_objects()

## record the counters for the 2.5D view (called by it every frame)
func record(rec_node) -> void:
	R = rec_node
	rec_node.begin()
	paint_objects()
	R = null
	rec_node.finish(hits)

func _paint_orbit_rings() -> void:
	var G = Game.G
	if G == null: return
	for w in geo.worlds:
		if G.w.get(w) == null or not geo.worlds[w].has("poly") or not DOTR.has(w): continue
		var Rr := ring_of(w)
		var n := roundi(2 * PI * Rr.r / 9)
		for i in n:
			var a := i / float(n) * 2 * PI
			draw_circle(Rr.c + Vector2(cos(a), sin(a)) * Rr.r, 1.7, Color(150 / 255.0, 132 / 255.0, 214 / 255.0, .85))

func paint_objects() -> void:
	hits = []
	var G = Game.G
	if G == null: return
	var E: SHRules = Game.E
	var D: Dictionary = Game.data.D
	var sel = Game.sel
	_mode("flat", 0)
	# worlds: selection, missions, terraforming
	for k in geo.worlds:
		var ws = G.w.get(k)
		if ws == null: continue
		var g: Dictionary = geo.worlds[k]
		var wx: Vector2 = v2(g.orbit) if g.has("orbit") else v2(g.exp)
		var raw = PackedVector2Array(Array(g.poly).map(func(q): return v2(q))) if g.has("poly") else null
		if raw != null: hits.append({"t": "world", "k": k, "poly": raw})
		else: hits.append({"t": "world", "k": k, "c": wx, "rad": 60.0})
		if sel != null and sel.t == "world" and sel.k == k:
			if R != null:
				if raw != null: R.poly(Array(g.poly), "#ee5f74", 5)
				else: R.ring(wx.x, wx.y, 60, "#ee5f74", 5)
			elif raw != null:
				var closed: PackedVector2Array = raw.duplicate()
				closed.append(raw[0])
				draw_polyline(closed, C_SEL, 5)
			else: draw_arc(wx, 60, 0, TAU, 48, C_SEL, 5)
		# mission tokens at the world: yours (gold), the common one (blue), a dated one open to all (red)
		var i := 0
		for x in E.missionsAt(G, k):
			var fr = markers_fr.get(D.MIS[x.id].mk)
			if fr == null: continue
			var S := 50.0
			var mp := wx + Vector2(-104 - i * (S + 8), -34)
			draw_frame(markers_tex, fr, mp, S)
			if R == null: draw_rect(Rect2(mp - Vector2(S / 2 + 2, S / 2 + 2), Vector2(S + 4, S + 4)), MIS_COL[x.kind], false, 3)
			hits.append({"t": "world", "k": k, "c": mp, "rad": S / 2})
			i += 1
		if D.TERRA.has(k) and SHRules.t(ws.get("terra")): text("Terraformed %d/%d" % [ws.terra, D.TERRA[k]], wx + Vector2(0, -64), 14, Color("#5fcf8a"))
	# flyby boxes: pirates and asteroids
	_mode("stand", 22)
	for s in G.fly:
		var fly = geo.sys.get(s)
		if fly == null: continue
		var p := v2(fly.flyby)
		var i := 0
		for pr in G.fly[s].pir:
			draw_frame(markers_tex, markers_fr.get("pir_l" if SHRules.t(pr.strong) else "pir_s"), p + Vector2(-26 + i * 22, -34), 46)
			if SHRules.t(pr.dmg): text("dmg %d" % pr.dmg, p + Vector2(-26 + i * 22, -4), 11, Color("#ef6b5b"))
			i += 1
		for j in int(G.fly[s].ast): draw_frame(markers_tex, markers_fr.get("ast"), p + Vector2(26 + j * 16, 34), 42)
	_mode("flat", 0)
	_paint_world_boxes(G, D)
	_mode("stand", 34)
	# ships (own and other factions'); ships waiting on Earth live on the faction board, not on the map
	var by_loc := {}
	var owner := {}
	for s in G.ships:
		if s.loc != "earth": by_loc[s.loc] = by_loc.get(s.loc, []) + [s]
	if G.world != null:
		for f in G.world.facs:
			if f == G.f: continue
			for s in G.world.facs[f].ships:
				if s.loc == "earth": continue
				owner[s] = f
				by_loc[s.loc] = by_loc.get(s.loc, []) + [s]
	var drag_id = ghost.get("id") if ghost != null else null
	for loc in by_loc:
		var lst: Array = by_loc[loc]
		var p := pos_of(loc)
		var cols := mini(lst.size(), 3)
		var lp := E.P(loc)
		var RL = ring_layout(lp.w, lst.filter(func(x): return not (drag_id != null and not owner.has(x) and SHRules.eq(x.id, drag_id)))) if (lp.t == "orbit" and geo.worlds.has(lp.w)) else null
		var i := -1
		for s in lst:
			i += 1
			if drag_id != null and not owner.has(s) and SHRules.eq(s.id, drag_id): continue
			var c := p + Vector2(((i % 3) - (cols - 1) / 2.0) * (CS + 4), floorf(i / 3.0) * (CS + 4))
			if lp.t == "orbit" and geo.worlds.has(lp.w):
				var Rr := ring_of(lp.w)
				var a: float = RL[s]
				c = Rr.c + Vector2(cos(a), sin(a)) * Rr.r
			var rot := 0.0
			if lp.t == "box":
				var B := box_frame(lp.s, lp.n)
				rot = B.a
				var off := (i - (lst.size() - 1) / 2.0) * 9
				c = B.c + Vector2(off * cos(rot) - off * .6 * sin(rot), off * sin(rot) + off * .6 * cos(rot))
			elif lp.t == "surf" and geo.worlds.has(lp.w) and not geo.worlds[lp.w].has("spoly"):
				var Rr := ring_of(lp.w)
				c = Rr.c + Vector2(((i % 3) - (cols - 1) / 2.0) * (CS + 4), floorf(i / 3.0) * (CS + 4))
			if owner.has(s):
				var of: String = owner[s]
				if R != null: R.ring(c.x, c.y, CS * .62, D.FAC[of].c, 3)
				draw_box(c, CS + 6, Color(D.FAC[of].c), 3, rot)
				draw_frame(atl[of].tex, unit_frame(of, s.img + "|back" if SHRules.t(s.res) else s.img), c, CS, rot)
				hits.append({"t": "oship", "f": of, "id": s.id, "c": c, "r": CS / 2, "img": s.img})
				continue
			var ready: bool = (G.phase == "move" and E.moves(G, s).size() > 0) or (G.phase == "explore" and E.exploreOptions(G, s).size() > 0)
			var is_sel: bool = sel != null and sel.t == "ship" and SHRules.eq(sel.get("id"), s.id)
			if R != null and (ready or is_sel): R.ring(c.x, c.y, CS * .62, "#ee5f74" if is_sel else "#7fa9d6", 3)
			if ready or is_sel: draw_box(c, CS + 8, C_SEL if is_sel else C_READY, 3, rot)
			draw_frame(atl[G.f].tex, unit_frame(G.f, s.img + "|back" if SHRules.t(s.res) else s.img), c, CS, rot)
			if SHRules.t(s.dmg): text("▼%d" % s.dmg, c + Vector2(22, -24), 13, Color("#ef6b5b"))
			if SHRules.t(s.get("hold")): text("+%d" % s.hold, c + Vector2(22, 24), 13, C_SEL)
			if SHRules.t(s.get("probe")): draw_frame(atl[G.f].tex, unit_frame(G.f, "Probe|" + s.probe), c + Vector2(-24, 24), 24)
			hits.append({"t": "ship", "id": s.id, "c": c, "r": CS / 2, "f": G.f, "img": s.img})
	# move targets (the 2.5D view draws its own)
	if targets.size() and R == null:
		var seen := {}
		var dests := {}
		for m in targets: dests[m.dest] = true
		for m in targets:
			if seen.has(m.dest): continue
			seen[m.dest] = true
			var pp := E.P(m.dest)
			var z := zone_shape(m.dest, pp.t == "orbit" and dests.has("surf:" + str(pp.w)))
			if z.has("poly"):
				var fill = z.poly
				if z.get("hole") != null:
					var cut := Geometry2D.clip_polygons(z.poly, z.hole)
					for q in cut:
						if not Geometry2D.is_polygon_clockwise(q) or cut.size() == 1: draw_colored_polygon(q, C_ZONE)
				else: draw_colored_polygon(fill, C_ZONE)
				var closed: PackedVector2Array = z.poly.duplicate()
				closed.append(z.poly[0])
				draw_polyline(closed, C_READY, 4)
				if z.get("hole") != null:
					var hc: PackedVector2Array = z.hole.duplicate()
					hc.append(z.hole[0])
					draw_polyline(hc, C_READY, 4)
			else:
				draw_circle(z.c, z.r, C_ZONE)
				draw_arc(z.c, z.r, 0, TAU, 40, C_READY, 4)
			var lbl: String = m.label
			if SHRules.t(m.get("eta")): lbl += " · %dt" % m.eta
			text(lbl, pos_of(m.dest) + Vector2(0, 46), 15, C_READY)
	_mode("stand", 120)
	# a counter being dragged to a destination
	if ghost != null and ghost.has("p"):
		if R == null and ghost.get("dest", "") != "":
			var z := zone_shape(ghost.dest)
			if z.has("poly"): draw_colored_polygon(z.poly, Color(C_SEL, 0.25))
			else: draw_circle(z.c, z.r, Color(C_SEL, 0.25))
		draw_frame(atl[ghost.f].tex, unit_frame(ghost.f, ghost.img), ghost.p, CS * 1.15, 0, Color(1.000, 0.816, 0.839, 0.9))

func _paint_world_boxes(G, D: Dictionary) -> void:
	var LS: float = WB.LS
	var BS: float = WB.BS
	var TS: float = WB.TS
	var GAP: float = WB.GAP
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
		# a non-player faction's base looks like any faction base (its own counter art)
		if SHRules.t(ws.get("npf")): bases.append([{"id": "npf:" + k, "name": String(Game.E.npfName(G, k)), "w": k, "set": 0, "npf": true, "trade": ws.get("npfTrade"), "blk": ws.get("blk")}, ws.npf])
		if not SHRules.t(ws.get("card")) and not SHRules.t(ws.get("sol")) and not SHRules.t(ws.get("life")) and not bases.size(): continue
		var F = R.worldFrame(k) if R != null else wcard_frame(k)
		if F == null: continue
		var CW: float = F.CW
		var CH: float = F.CH
		if SHRules.t(ws.get("card")) and not F.get("abs", false):
			var c = SHRules._find(D.CARDS, func(x): return x.n == ws.card)
			if c != null: draw_frame(markers_tex, markers_fr.get("card_" + c.img), wat(F, 0, 0), CW, F.a)
		if (SHRules.t(ws.get("sol")) or SHRules.t(ws.get("life"))) and not F.get("abs", false):
			draw_frame(life_tex, [96 if SHRules.t(ws.get("life")) else 0, 0, 96, 96], wat(F, CW / 2 + 10 + LS / 2, 0), LS, F.a)
		var row_y0: float = 0.0 if F.noCard else CH / 2 + GAP + BS / 2
		var unit := BS + 8 + TS + 14
		var i := 0
		for pair in bases:
			var b: Dictionary = pair[0]
			var bf: String = pair[1]
			var sl = F.slots[mini(i, F.slots.size() - 1)] if F.get("abs", false) else null
			var lx: float = sl.x if sl != null else -CW / 2 + BS / 2 + i * unit
			var row_y: float = sl.y if sl != null else row_y0
			var p := wat(F, lx, row_y)
			i += 1
			if not atl.has(bf): continue
			draw_frame(atl[bf].tex, unit_frame(bf, base_key(b, bf)), p, BS, F.a)
			if SHRules.t(b.get("npf")):
				hits.append({"t": "npf", "k": k, "c": p, "r": BS / 2, "f": bf, "img": base_key(b, bf)})
				if R != null and Game.sel != null and Game.sel.t == "npf" and Game.sel.k == k: R.box(p.x, p.y, BS + 6, F.a, "#ee5f74", 3)
				if Game.sel != null and Game.sel.t == "npf" and Game.sel.k == k: draw_box(p, BS + 6, C_SEL, 3, F.a)
				if SHRules.t(b.trade):
					draw_frame(markers_tex, markers_fr.get(("buy_" if b.trade.side == "buy" else "sell_") + b.trade.type), wat(F, lx + BS / 2 + 8 + TS / 2, row_y), TS, F.a)
					# enhanced trading: who has already traded here (faction colour tags under the marker)
					if R == null:
						var j := 0
						for f in b.trade.get("by", []):
							var dp := wat(F, lx + BS / 2 + 8 + 6 + j * 13, row_y + TS / 2 + 9)
							draw_circle(dp, 5.5, Color(D.FAC[f].c))
							draw_arc(dp, 5.5, 0, TAU, 16, Color.WHITE, 1.5)
							j += 1
				if SHRules.t(b.blk): text("BLOCKADED", wat(F, lx, row_y + BS / 2 + 12), 11, Color("#ef6b5b"))
				continue
			if R != null and bf != G.f: R.box(p.x, p.y, BS + 4, F.a, D.FAC[bf].c, 3)
			if R != null and Game.sel != null and Game.sel.t == "base" and SHRules.eq(Game.sel.get("id"), b.id): R.box(p.x, p.y, BS + 6, F.a, "#ee5f74", 3)
			if bf != G.f:
				draw_box(p, BS + 4, Color(D.FAC[bf].c), 3, F.a)
				hits.append({"t": "obase", "f": bf, "id": b.id, "name": b.name, "w": b.w, "c": p, "r": BS / 2, "img": base_key(b, bf)})
			else: hits.append({"t": "base", "id": b.id, "c": p, "r": BS / 2, "f": bf, "img": base_key(b, bf)})
			if b.set > 0: text(str(b.set), wat(F, lx + BS / 2 - 8, row_y + BS / 2 + 10), 15, Color("#ee5f74"))
			if Game.sel != null and Game.sel.t == "base" and SHRules.eq(Game.sel.get("id"), b.id): draw_box(p, BS + 6, C_SEL, 3, F.a)
			if SHRules.t(b.get("trade")) and b.set > 0: draw_frame(markers_tex, markers_fr.get(("buy_" if b.trade.side == "buy" else "sell_") + b.trade.type), wat(F, lx + BS / 2 + 8 + TS / 2, row_y), TS, F.a)

## hitAtWorld: the topmost hit at a board point (counters are squares, worlds polygons or circles)
func hit_at_world(p: Vector2):
	for i in range(hits.size() - 1, -1, -1):
		var h: Dictionary = hits[i]
		if h.has("r"):
			if absf(p.x - h.c.x) <= h.r and absf(p.y - h.c.y) <= h.r: return h
		elif h.has("poly"):
			if Geometry2D.is_point_in_polygon(p, h.poly): return h
		elif p.distance_to(h.c) <= h.rad: return h
	return null

## the move target under a map point, or "" (the smallest zone containing it wins, as in the web version)
func dest_at(pt: Vector2) -> String:
	var best := ""
	var ba := 1e12
	var near := ""
	var nd := 1e9
	for m in targets:
		var z := zone_shape(m.dest)
		if z.has("poly"):
			if Geometry2D.is_point_in_polygon(pt, z.poly):
				var a := _area(z.poly)
				if a < ba:
					ba = a
					best = m.dest
			continue
		var d: float = pt.distance_to(z.c)
		if d < z.r * 1.4 and d < nd:
			nd = d
			near = m.dest
	return best if best != "" else near
static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size(): a += p[i].cross(p[(i + 1) % p.size()])
	return absf(a / 2)

## what is under a map point: a counter first, then a move target, then a world
func pick_at(pt: Vector2) -> Dictionary:
	var h = hit_at_world(pt)
	if h != null and h.t != "world": return h
	if targets.size():
		var d := dest_at(pt)
		if d != "": return {"t": "dest", "dest": d}
	return h if h != null else {}
