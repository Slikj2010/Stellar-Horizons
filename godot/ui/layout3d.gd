## Solar-system layout for the 3D view (a port of layout25.js).
## The printed board is cut into one "pod" per heliocentric system (Mercury … Alpha Centauri). Each pod keeps its
## geometry exactly: it is only moved and scaled by S, so every anchor point stays where the rules put it relative to
## its world. Pods are placed on orbit rings round the Sun, with the Main Belt and Kuiper Belt as particle rings.
## Scene coordinates: x east, z south (board y), y up.
class_name SHLayout3D
extends RefCounted

const S := 0.6  ## board units -> scene units
const RING := {"mer": 0, "ven": 1700, "ear": 2700, "mar": 3700, "bel": 4900, "jup": 6300, "sat": 7900, "ura": 9400, "nep": 10800, "kui": 12400, "sca": 14200, "alp": 17600}
const PREF := {"ven": -150, "ear": 25, "mar": -55, "bel": 120, "jup": -140, "sat": 35, "ura": 205, "nep": 95, "kui": -25, "sca": 150, "alp": -75}
## satellite worlds that sit out in the belts at their own place instead of inside their system's pod
const SAT := {"ves": [4560, 290], "cer": [4970, 205], "hyg": [5150, 25], "plu": [12360, 215], "hau": [12760, 295], "eri": [13950, 100], "sed": [14500, 30], "dsa": [15830, -32.2], "sun": [0, 0]}
const BELTS := [{"k": "bel", "r0": 4300, "r1": 5500, "n": 30000, "col": Color(0.72, 0.62, 0.5)}, {"k": "kui", "r0": 11600, "r1": 13200, "n": 26000, "col": Color(0.62, 0.76, 0.92)}]

var pods := {}  ## k -> {k, name, bbox: Rect2 (board), hub: Vector2 (board), org: Vector2 (scene x,z), ring, ang, sat, rect: Rect2 (scene x,z)}
var anchors: Array = []  ## [Vector2 board point, pod key]
var sun_r := 250.0
var _cache := {}

func build(geo: Dictionary, D: Dictionary, sun_c) -> void:
	var B := {}
	var add := func(k: String, x: float, y: float, anchor: bool):
		if anchor: anchors.append([Vector2(x, y), k])
		if not B.has(k): B[k] = [1e9, 1e9, -1e9, -1e9]
		var b: Array = B[k]
		b[0] = minf(b[0], x)
		b[1] = minf(b[1], y)
		b[2] = maxf(b[2], x)
		b[3] = maxf(b[3], y)
	for k in geo.sys:
		var s: Dictionary = geo.sys[k]
		add.call(k, s.flyby[0], s.flyby[1], true)
		for p in s.flybyPoly: add.call(k, p[0], p[1], true)
		for q in s.boxPoly.values():
			for p in q: add.call(k, p[0], p[1], true)
	for w in geo.worlds:
		var g: Dictionary = geo.worlds[w]
		var k = null
		if SAT.has(w): k = w
		elif D.W.has(w): k = D.W[w].sys
		elif geo.sys.has(w): k = w
		if k == null: continue
		for p in g.get("poly", []): add.call(k, p[0], p[1], true)
		if g.has("orbit"): add.call(k, g.orbit[0], g.orbit[1], true)
		if g.has("surf"): add.call(k, g.surf[0], g.surf[1], true)
		if g.has("wcard"):
			add.call(k, g.wcard[0] - 260, g.wcard[1] - 200, false)
			add.call(k, g.wcard[0] + 260, g.wcard[1] + 260, false)
			anchors.append([Vector2(g.wcard[0], g.wcard[1]), k])
			anchors.append([Vector2(g.wcard[0] + 120, g.wcard[1] + 120), k])
	for k in B:
		var m: Array = B[k]
		if SAT.has(k):
			var cx: float = (m[0] + m[2]) / 2.0
			var cy: float = (m[1] + m[3]) / 2.0
			var hw: float = 520.0 if k == "sun" else maxf((m[2] - m[0]) / 2.0, 495.0 if k == "dsa" else 330.0)
			var hh: float = 520.0 if k == "sun" else maxf((m[3] - m[1]) / 2.0, 420.0 if k == "dsa" else 280.0)
			m = [cx - hw, cy - hh, cx + hw, cy + hh]
		if k == "alp":
			var cx: float = (m[0] + m[2]) / 2.0
			var cy: float = (m[1] + m[3]) / 2.0
			var hw: float = m[2] - m[0]
			var hh: float = m[3] - m[1]
			m = [cx - hw, cy - hh, cx + hw, cy + hh]
		var bb := Rect2(m[0] - 40, m[1] - 40, m[2] - m[0] + 80, m[3] - m[1] + 80)
		var hubW = geo.worlds.get(k) if SAT.has(k) else (geo.worlds.get(D.SYS[k].hub) if D.SYS.has(k) and D.SYS[k].get("hub") != null else null)
		var hub: Vector2 = Vector2(hubW.orbit[0], hubW.orbit[1]) if (hubW != null and hubW.has("orbit")) else bb.get_center()
		if hubW == null and geo.sys.has(k):
			# a system with no hub world (the Scattered Disk): centre it on the circle its transfer boxes sit round
			var P: Array = geo.sys[k].box.values()
			var n := float(P.size())
			var sx := 0.0; var sy := 0.0; var sxx := 0.0; var syy := 0.0; var sxy := 0.0; var sz := 0.0; var sxz := 0.0; var syz := 0.0
			for q in P:
				var x: float = q[0]
				var y: float = q[1]
				sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y
				var z := x * x + y * y
				sz += z; sxz += x * z; syz += y * z
			var A := [[sxx, sxy, sx], [sxy, syy, sy], [sx, sy, n]]
			var bv := [sxz, syz, sz]
			var d0 := _det(A)
			if absf(d0) > 1e-6:
				hub = Vector2(_det(_rep(A, bv, 0)) / d0 / 2.0, _det(_rep(A, bv, 1)) / d0 / 2.0)
		if k == "sun" and sun_c != null: hub = sun_c
		pods[k] = {"k": k, "name": D.W[k].n if SAT.has(k) else D.SYS[k].n, "bbox": bb, "hub": hub, "org": Vector2.ZERO, "ring": SAT[k][0] if SAT.has(k) else RING.get(k, 0), "ang": 0.0, "sat": SAT.has(k)}
	# place the pods round the Sun without overlaps
	var mer: Dictionary = pods.mer
	mer.org = Vector2(0, -430 - (mer.bbox.end.y - mer.hub.y) * S)
	var placed := [mer]
	var order := ["ven", "ear", "mar", "bel", "jup", "sat", "ura", "nep", "kui", "sca", "alp"] + SAT.keys()
	for k in order:
		if not pods.has(k): continue
		var p: Dictionary = pods[k]
		if k == "sun":
			p.ang = 0.0
			p.org = Vector2.ZERO
			p.rect = rect_of(p)
			continue
		var pa: float = SAT[k][1] if SAT.has(k) else PREF[k]
		var best = null
		for mg in [200.0, 120.0, 40.0, -1e9]:
			# (as in layout25.js: a belt satellite takes the first free angle, a system pod the last one found)
			var d := 0
			while d <= 180:
				for sg in ([1, -1] if d else [1]):
					var a := deg_to_rad(pa + sg * d)
					p.org = Vector2(cos(a), sin(a)) * p.ring
					var r := rect_of(p)
					var ok := true
					for q in placed:
						if _hit(r, rect_of(q), mg):
							ok = false
							break
					if ok:
						best = a
						if SAT.has(k): d = 999
						break
				d += 5
			if best != null: break
		p.ang = best
		p.org = Vector2(cos(best), sin(best)) * p.ring
		placed.append(p)
	for k in pods: pods[k].rect = rect_of(pods[k])
	if sun_c != null: sun_r = 428.0 * S

func rect_of(p: Dictionary) -> Rect2:
	var bb: Rect2 = p.bbox
	return Rect2(p.org + (bb.position - p.hub) * S, bb.size * S)

static func _hit(a: Rect2, b: Rect2, m: float) -> bool:
	return a.position.x - m < b.end.x and a.end.x + m > b.position.x and a.position.y - m < b.end.y and a.end.y + m > b.position.y

static func _det(m: Array) -> float:
	return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])

static func _rep(A: Array, bv: Array, c: int) -> Array:
	var out := []
	for i in 3:
		var row := []
		for j in 3: row.append(bv[i] if j == c else A[i][j])
		out.append(row)
	return out

## the pod a board point belongs to: the one whose printed geometry is nearest
func pod_at(pt: Vector2) -> Dictionary:
	var key := Vector2i(roundi(pt.x), roundi(pt.y))
	if _cache.has(key): return _cache[key]
	var best = null
	var bd := 1e18
	for a in anchors:
		var d: float = (a[0] as Vector2).distance_squared_to(pt)
		if d < bd:
			bd = d
			best = a
	var p: Dictionary = pods[best[1]]
	if _cache.size() > 20000: _cache.clear()
	_cache[key] = p
	return p

## board point -> scene point (x, z)
func to_scene(pt: Vector2, pod = null) -> Vector2:
	var p: Dictionary = pod if pod != null else pod_at(pt)
	return p.org + (pt - p.hub) * S

## scene point (x, z) -> board point, or null when it is outside every pod
func from_scene(q: Vector2):
	var best = null
	var ba := 1e18
	for k in pods:
		var p: Dictionary = pods[k]
		var r: Rect2 = p.rect
		if r.has_point(q):
			var a := r.get_area()
			if a < ba:
				ba = a
				best = p
	if best == null: return null
	return (q - best.org) / S + best.hub
