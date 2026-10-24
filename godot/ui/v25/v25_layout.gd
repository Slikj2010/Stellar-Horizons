## Solar-system layout for the 2.5D view: a line-by-line port of layout25.js (SHL.build).
## The printed board is cut into one "pod" per heliocentric system. Each pod keeps its geometry exactly: it is only moved
## and scaled by S, so every anchor point stays where the rules put it relative to its world. The pods are placed on
## orbit rings round the Sun. Scene coordinates: X east, Z south (the board's y), Y up.
## Pods: {k, name, bbox: [x0,y0,x1,y1] (board), hub: [x,y] (board), org: [X,Z] (scene), ring, ang, sat, rect: [X0,Z0,X1,Z1]}
class_name V25Layout
extends RefCounted

const S := 0.6
const RING := {"mer": 0, "ven": 1700, "ear": 2700, "mar": 3700, "bel": 4900, "jup": 6300, "sat": 7900, "ura": 9400, "nep": 10800, "kui": 12400, "sca": 14200, "alp": 17600}
const PREF := {"ven": -150, "ear": 25, "mar": -55, "bel": 120, "jup": -140, "sat": 35, "ura": 205, "nep": 95, "kui": -25, "sca": 150, "alp": -75}
const SAT := {"ves": [4560, 290], "cer": [4970, 205], "hyg": [5150, 25], "plu": [12360, 215], "hau": [12760, 295], "eri": [13950, 100], "sed": [14500, 30], "dsa": [15830, -32.2], "sun": [0, 0]}
const BELTS := [{"k": "bel", "r0": 4300.0, "r1": 5500.0, "n": 30000, "col": [.72, .62, .5]}, {"k": "kui", "r0": 11600.0, "r1": 13200.0, "n": 26000, "col": [.62, .76, .92]}]

var pods := {}
var AN: Array = []  ## anchors [x, y, pod key]
var rings: Array = []
var sunR := 250.0
var _cache := {}

func build(GEO: Dictionary, D: Dictionary, sunC) -> void:
	var B := {}
	var add := func(k: String, x: float, y: float, anchor: bool):
		if anchor: AN.append([x, y, k])
		if not B.has(k): B[k] = [1e9, 1e9, -1e9, -1e9]
		var b: Array = B[k]
		b[0] = minf(b[0], x); b[1] = minf(b[1], y); b[2] = maxf(b[2], x); b[3] = maxf(b[3], y)
	for k in GEO.sys:
		var s: Dictionary = GEO.sys[k]
		add.call(k, s.flyby[0], s.flyby[1], true)
		for p in s.flybyPoly: add.call(k, p[0], p[1], true)
		for q in s.boxPoly.values():
			for p in q: add.call(k, p[0], p[1], true)
	for w in GEO.worlds:
		var g: Dictionary = GEO.worlds[w]
		var k = null
		if SAT.has(w): k = w
		elif D.W.has(w): k = D.W[w].sys
		elif GEO.sys.has(w): k = w
		if k == null: continue
		for p in g.get("poly", []): add.call(k, p[0], p[1], true)
		if g.has("orbit"): add.call(k, g.orbit[0], g.orbit[1], true)
		if g.has("surf"): add.call(k, g.surf[0], g.surf[1], true)
		if g.has("wcard"):
			add.call(k, g.wcard[0] - 260, g.wcard[1] - 200, false)
			add.call(k, g.wcard[0] + 260, g.wcard[1] + 260, false)
			AN.append([g.wcard[0], g.wcard[1], k])
			AN.append([g.wcard[0] + 120, g.wcard[1] + 120, k])
	for k in B:
		if SAT.has(k):
			var m: Array = B[k]
			var cx: float = (m[0] + m[2]) / 2.0
			var cy: float = (m[1] + m[3]) / 2.0
			var hw: float = 520.0 if k == "sun" else maxf((m[2] - m[0]) / 2.0, 495.0 if k == "dsa" else 330.0)
			var hh: float = 520.0 if k == "sun" else maxf((m[3] - m[1]) / 2.0, 420.0 if k == "dsa" else 280.0)
			B[k] = [cx - hw, cy - hh, cx + hw, cy + hh]
		if k == "alp":
			var m: Array = B[k]
			var cx: float = (m[0] + m[2]) / 2.0
			var cy: float = (m[1] + m[3]) / 2.0
			var hw: float = m[2] - m[0]
			var hh: float = m[3] - m[1]
			B[k] = [cx - hw, cy - hh, cx + hw, cy + hh]
		var bb: Array = B[k]
		var b := [bb[0] - 40.0, bb[1] - 40.0, bb[2] + 40.0, bb[3] + 40.0]
		var hubW = GEO.worlds.get(k) if SAT.has(k) else (GEO.worlds.get(D.SYS[k].hub) if D.SYS.has(k) and D.SYS[k].get("hub") != null else null)
		var hub: Array = [hubW.orbit[0], hubW.orbit[1]] if (hubW != null and hubW.has("orbit")) else [(b[0] + b[2]) / 2.0, (b[1] + b[3]) / 2.0]
		if hubW == null and GEO.sys.has(k):
			# a system with no hub world (the Scattered Disk): centre it on the circle its transfer boxes sit round
			var P: Array = GEO.sys[k].box.values()
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
			if absf(d0) > 1e-6: hub = [_det(_rep(A, bv, 0)) / d0 / 2.0, _det(_rep(A, bv, 1)) / d0 / 2.0]
		if k == "sun" and sunC != null: hub = [sunC[0], sunC[1]]
		pods[k] = {"k": k, "name": D.W[k].n if SAT.has(k) else D.SYS[k].n, "bbox": b, "hub": hub, "org": [0.0, 0.0], "ring": float(SAT[k][0] if SAT.has(k) else RING.get(k, 0)), "ang": 0.0, "sat": SAT.has(k)}
	# placement round the Sun, without overlaps
	var mer: Dictionary = pods.mer
	mer.org = [0.0, -430.0 - (mer.bbox[3] - mer.hub[1]) * S]
	var placed := [mer]
	var order := ["ven", "ear", "mar", "bel", "jup", "sat", "ura", "nep", "kui", "sca", "alp"] + SAT.keys()
	for k in order:
		var p: Dictionary = pods[k]
		var best = null
		var PA: float = SAT[k][1] if SAT.has(k) else PREF[k]
		if k == "sun":
			p.ang = 0.0
			p.org = [0.0, 0.0]
			continue
		for mg in [200.0, 120.0, 40.0, -1e9]:
			var d := 0
			while d <= 180:
				for sg in ([1, -1] if d else [1]):
					var a: float = (PA + sg * d) * PI / 180.0
					p.org = [cos(a) * p.ring, sin(a) * p.ring]
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
		p.org = [cos(best) * p.ring, sin(best) * p.ring]
		placed.append(p)
	for k in pods: pods[k].rect = rect_of(pods[k])
	for k in pods:
		var p: Dictionary = pods[k]
		if p.ring and not p.sat and not (k in ["bel", "kui", "sca", "alp"]): rings.append({"k": k, "r": p.ring})
	sunR = 428.0 * S if sunC != null else 250.0

func rect_of(p: Dictionary) -> Array:
	return [p.org[0] + (p.bbox[0] - p.hub[0]) * S, p.org[1] + (p.bbox[1] - p.hub[1]) * S, p.org[0] + (p.bbox[2] - p.hub[0]) * S, p.org[1] + (p.bbox[3] - p.hub[1]) * S]

static func _hit(a: Array, b: Array, m: float) -> bool:
	return a[0] - m < b[2] and a[2] + m > b[0] and a[1] - m < b[3] and a[3] + m > b[1]

static func _det(m: Array) -> float:
	return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])

static func _rep(A: Array, bv: Array, c: int) -> Array:
	var out := []
	for i in 3:
		var row := []
		for j in 3: row.append(bv[i] if j == c else A[i][j])
		out.append(row)
	return out

## a point belongs to the system whose printed geometry (boxes, zones, cards) is nearest to it
func podAt(x: float, y: float) -> Dictionary:
	var key := roundi(x) * 100000 + roundi(y)
	var c = _cache.get(key)
	if c != null: return c
	var best = null
	var bd := 1e18
	for a in AN:
		var d: float = (a[0] - x) * (a[0] - x) + (a[1] - y) * (a[1] - y)
		if d < bd:
			bd = d
			best = a
	c = pods[best[2]]
	if _cache.size() > 20000: _cache.clear()
	_cache[key] = c
	return c

## board point -> [X, Z, pod]
func toL(x: float, y: float, pod = null) -> Array:
	var p: Dictionary = pod if pod != null else podAt(x, y)
	return [p.org[0] + (x - p.hub[0]) * S, p.org[1] + (y - p.hub[1]) * S, p]

## scene point -> [x, y, pod] on the board, or null
func fromL(X: float, Z: float):
	var best = null
	var ba := 1e18
	for k in pods:
		var p: Dictionary = pods[k]
		var r: Array = p.rect
		if X >= r[0] and X <= r[2] and Z >= r[1] and Z <= r[3]:
			var a: float = (r[2] - r[0]) * (r[3] - r[1])
			if a < ba:
				ba = a
				best = p
	if best == null: return null
	return [(X - best.org[0]) / S + best.hub[0], (Z - best.org[1]) / S + best.hub[1], best]

func addAnchor(x: float, y: float, k: String) -> void:
	AN.append([x, y, k])
	_cache.clear()
