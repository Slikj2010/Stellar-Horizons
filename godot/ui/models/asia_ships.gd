## Asia's crew ships (CV-2 .. CV-7), built from a shared kit in the same style as the Orion: cream riveted plating
## (generated albedo + normal maps), gold trim rings, blue light strips, rounded barrel hulls, parallel tank pods,
## "eye" hub blocks, delta wings / solar arrays and clustered ribbed engine bells.  Nose points to +X.
## Not wired into the game yet; see tests/asia_preview.gd for renders.
class_name AsiaShips
extends RefCounted

## module tokens (nose to tail):
##  ["barrel", L, R]  ["hab", L, R]  ["eye", L, S]  ["tanks", L, r, spread, n]  ["conn"]
##  attachments (no length): ["delta", span, chord]  ["cross", span, chord]  ["tall", span, chord]
##                           ["solar", w, l]  ["solarv", w, l]
const SPECS := {
	"Prayaas": {"nose": ["sphere", 0.36], "mods": [["conn"], ["hab", 0.5, 0.22], ["conn"], ["barrel", 1.1, 0.33]], "eng": 1},
	"Khaj": {"nose": ["sphere", 0.34], "mods": [["conn"], ["hab", 0.45, 0.28], ["barrel", 0.55, 0.32], ["barrel", 0.4, 0.3]], "eng": 1},
	"Jamnagar": {"nose": ["ogive", 0.33, 0.6], "mods": [["barrel", 0.75, 0.34], ["barrel", 0.55, 0.34]], "eng": 1},
	"Rakahak": {"nose": ["needle", 0.24, 1.0], "mods": [["barrel", 0.8, 0.24], ["cross", 0.62, 0.7], ["hab", 0.35, 0.26]], "eng": 1},
	"Gujarat": {"nose": ["needle", 0.3, 1.3], "mods": [["barrel", 0.7, 0.3], ["delta", 1.35, 1.1], ["hab", 0.45, 0.3]], "eng": 1},
	"Inaam": {"nose": ["ogive", 0.3, 0.5], "mods": [["barrel", 0.55, 0.3], ["barrel", 0.5, 0.3], ["barrel", 0.45, 0.3], ["tall", 0.9, 0.5], ["hab", 0.3, 0.3]], "eng": 3},
	"Khajaama": {"nose": ["ogive", 0.34, 0.55], "mods": [["barrel", 0.55, 0.34], ["barrel", 0.5, 0.34], ["solar", 0.85, 0.5], ["tanks", 0.75, 0.2, 0.24, 2]], "eng": 3},
	"Maharashmi": {"nose": ["ogive", 0.34, 0.55], "mods": [["barrel", 0.55, 0.34], ["barrel", 0.45, 0.34], ["tall", 0.95, 0.5], ["tanks", 0.7, 0.2, 0.24, 2]], "eng": 2},
	"Chakra": {"nose": ["ogive", 0.36, 0.6], "mods": [["barrel", 0.7, 0.36], ["barrel", 0.4, 0.34], ["solarv", 0.8, 0.5], ["tanks", 0.7, 0.22, 0.27, 2]], "eng": 3},
	"Kalvari": {"nose": ["ogive", 0.36, 0.6], "mods": [["barrel", 0.65, 0.36], ["tanks", 0.55, 0.2, 0.25, 2], ["tall", 0.9, 0.5], ["tanks", 0.55, 0.22, 0.27, 2]], "eng": 4},
	"Mumbai": {"nose": ["ogive", 0.38, 0.6], "mods": [["barrel", 0.55, 0.38], ["eye", 0.5, 0.34], ["tanks", 0.8, 0.24, 0.3, 2]], "eng": 4},
	"Delhi": {"nose": ["ogive", 0.38, 0.6], "mods": [["barrel", 0.5, 0.38], ["eye", 0.5, 0.34], ["barrel", 0.35, 0.36], ["tanks", 0.75, 0.24, 0.3, 2]], "eng": 4},
	"Ganj-i-sawai": {"nose": ["ogive", 0.46, 0.75], "mods": [["barrel", 0.7, 0.46], ["tanks", 0.95, 0.27, 0.32, 4]], "eng": 4},
	"Vikrant": {"nose": ["ogive", 0.42, 0.65], "mods": [["barrel", 0.55, 0.42], ["eye", 0.55, 0.38], ["tanks", 0.9, 0.26, 0.34, 4]], "eng": 4},
	"Brahmaputra": {"nose": ["ogive", 0.42, 0.65], "mods": [["barrel", 0.5, 0.42], ["eye", 0.6, 0.4], ["hab", 0.25, 0.4], ["tanks", 0.9, 0.26, 0.34, 4]], "eng": 4},
}

const CREAM := [Color("#e6dcc5"), Color("#d9cdb3"), Color("#cbbfa6"), Color("#efe6d2"), Color("#c1b59c")]
const GOLD := Color("#c9a24a")

static func has(name: String) -> bool:
	return SPECS.has(name)

# ------------------------------------------------------------------ materials
static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("as_hull%d" % sd, 1024, 512, {"seed": 301 + sd * 17, "cols": 24, "min_len": 60, "max_len": 220, "black_rate": 0.04, "grime": 0.6, "tones": CREAM, "seam": Color("#8a7e66")}, 0.3, 0.55)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

# ------------------------------------------------------------------ parts
static func _gold_ring(p: Node3D, x: float, r: float, thick := 0.014) -> void:
	UnitModels.ring(p, r - 0.004, r + 2.0 * thick, _m(GOLD, 0.9, 0.3), Vector3(x, 0, 0), Vector3(0, 0, PI / 2))

static func _barrel(p: Node3D, xf: float, L: float, R: float, hull: Material) -> void:
	var xb := xf - L
	var pts: Array = [Vector2(xf, 0.001), Vector2(xf, R * 0.8), Vector2(xf - 0.02, R * 0.96), Vector2(xf - 0.055, R), Vector2(xb + 0.055, R), Vector2(xb + 0.02, R * 0.96), Vector2(xb, R * 0.8), Vector2(xb, 0.001)]
	OrionCV2._lathe(p, pts, 32, hull, Vector3.ZERO)
	_gold_ring(p, xf - 0.07, R)
	_gold_ring(p, xb + 0.07, R)
	var blue := _m(Color("#58b8ff"), 0.0, 0.3, 2.2)
	for a in [0.0, PI, PI * 0.5]:
		var f := OrionCV2._radial(p, xf - L * 0.5, a, R * 0.99)
		OrionCV2._rbox(f, Vector3(L * 0.55, 0.012, 0.03), blue, Vector3.ZERO, 4.0, 6)
	# a couple of louvred vents and a dark access hatch
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	var steel := _m(Color("#8d9198"), 0.85, 0.3)
	var vf := OrionCV2._radial(p, xf - L * 0.28, PI * 0.25 + 0.15, R * 0.985)
	OrionCV2._vent(vf, 0.07, 0.12, 5, steel, dark)
	var hf := OrionCV2._radial(p, xf - L * 0.72, -PI * 0.25, R * 0.985)
	OrionCV2._rbox(hf, Vector3(0.1, 0.014, 0.08), dark, Vector3.ZERO, 4.0, 6)

static func _nose(p: Node3D, xf: float, spec: Array, hull: Material) -> float:
	var kind: String = spec[0]
	var R: float = spec[1]
	if kind == "sphere":
		# round pod: flattened sphere with a gold equator, a docking window and lamps
		var rr := R * 1.0
		OrionCV2._lathe(p, _sphere_profile(xf, rr), 40, hull, Vector3.ZERO)
		_gold_ring(p, xf - rr * 0.55, rr * 0.93, 0.012)
		var f := OrionCV2._radial(p, xf - rr * 0.25, PI * 0.5, rr * 0.9)
		UnitModels.ring(f, 0.05, 0.075, _m(GOLD, 0.9, 0.3), Vector3.ZERO)
		UnitModels.ball(f, 0.05, _m(Color("#2a5f9a"), 0.8, 0.12, 0.5), Vector3(0, 0.01, 0), Vector3(1, 0.5, 1))
		var blue := _m(Color("#58b8ff"), 0.0, 0.3, 2.2)
		for k in 6:
			var a := k * TAU / 6.0
			UnitModels.ball(p, 0.014, blue, Vector3(xf - rr * 0.3, rr * 0.78 * sin(a), rr * 0.78 * cos(a)))
		return rr * 1.2
	var L: float = spec[2]
	var pts: Array = []
	var n := 14
	var power := 0.75 if kind == "ogive" else 1.35
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(xf - L * (1.0 - u) * 1.0 + 0.0, 0.0))
	pts.clear()
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(xf + L * (1.0 - u), R * pow(sin(u * PI * 0.5), power)))
	OrionCV2._lathe(p, pts, 32, hull, Vector3.ZERO)
	_gold_ring(p, xf + 0.003, R * 0.995)
	var blue := _m(Color("#58b8ff"), 0.0, 0.3, 2.2)
	var glass := _m(Color("#1f4f86"), 0.8, 0.12, 0.6)
	for a in [0.0, PI]:
		var wf := OrionCV2._radial(p, xf + L * 0.4, a, R * pow(sin(0.6 * PI * 0.5), power) * 0.97)
		UnitModels.ball(wf, 0.045, glass, Vector3(0, 0.012, 0), Vector3(1.3, 0.35, 0.8))
		UnitModels.ball(wf, 0.012, blue, Vector3(0.07, 0.02, 0.0))
	return 0.0

static func _sphere_profile(xf: float, r: float) -> Array:
	var pts: Array = []
	var n := 16
	var cx := xf - r * 0.85
	for i in n + 1:
		var a := PI * 0.5 - PI * float(i) / n * 0.62
		pts.append(Vector2(cx + r * 0.85 * sin(a), r * cos(a) + 0.001))
	# flat-ish back
	pts.append(Vector2(xf - r * 1.2, r * 0.7))
	pts.append(Vector2(xf - r * 1.2, 0.001))
	return pts

static func _conn(p: Node3D, x: float, r: float, L: float) -> void:
	UnitModels.cylx(p, r, r, L, _m(Color("#6c7077"), 0.8, 0.4), Vector3(x - L * 0.5, 0, 0), 20)
	_gold_ring(p, x - L * 0.5, r * 1.05, 0.008)

static func _porthole(f: Node3D, r: float) -> void:
	UnitModels.ring(f, r * 0.95, r * 1.25, _m(GOLD, 0.9, 0.3), Vector3.ZERO)
	UnitModels.ball(f, r, _m(Color("#16365e"), 0.9, 0.1, 0.5), Vector3(0, 0.0, 0), Vector3(1, 0.45, 1))

static func _eye(p: Node3D, xf: float, L: float, S: float, hull: Material) -> void:
	var flat := _m(Color("#d9cdb3"), 0.35, 0.5)
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	var steel := _m(Color("#8d9198"), 0.85, 0.3)
	OrionCV2._rbox(p, Vector3(L, S * 2.0, S * 2.0), flat, Vector3(xf - L * 0.5, 0, 0), 6.0, 10)
	for a in [0.0, PI, PI * 0.5]:
		var f := OrionCV2._radial(p, xf - L * 0.5, a, S * 0.99)
		_porthole(f, S * 0.45)
	_gold_ring(p, xf - 0.02, S * 1.05, 0.01)
	_gold_ring(p, xf - L + 0.02, S * 1.05, 0.01)
	# antennas on top
	for k in 3:
		var ax := xf - L * (0.25 + 0.25 * k)
		var top := Vector3(ax, S * 1.0, 0)
		OrionCV2._strut(p, top, top + Vector3(0, 0.12 + 0.05 * k, 0), 0.006, steel)
		UnitModels.ball(p, 0.014, _m(Color("#58b8ff"), 0.0, 0.3, 2.2), top + Vector3(0, 0.125 + 0.05 * k, 0))
	var cf := OrionCV2._radial(p, xf - L * 0.5, -PI * 0.5, S * 0.99)
	OrionCV2._cluster(cf, steel, _m(Color("#5b5f66"), 0.8, 0.38), dark, 0.9)

static func _tanks(p: Node3D, xf: float, L: float, r: float, spread: float, n: int, hull: Material) -> float:
	var offs: Array = []
	if n == 2:
		offs = [Vector2(0, spread), Vector2(0, -spread)]
	else:
		offs = [Vector2(spread, spread), Vector2(spread, -spread), Vector2(-spread, spread), Vector2(-spread, -spread)]
	for o in offs:
		var bp := Node3D.new()
		bp.position = Vector3(0, o.x, o.y)
		p.add_child(bp)
		_barrel(bp, xf, L, r, hull)
	# saddle block and manifold between the tanks
	var dsteel := _m(Color("#5b5f66"), 0.8, 0.38)
	OrionCV2._rbox(p, Vector3(L * 0.5, spread * 1.3, spread * 1.3), _m(Color("#cfc3a9"), 0.4, 0.5), Vector3(xf - L * 0.5, 0, 0), 4.0, 8)
	_gold_ring(p, xf - L * 0.5, spread * 0.9, 0.01)
	var f := OrionCV2._radial(p, xf - L * 0.5, PI * 0.5, spread * 0.66)
	OrionCV2._cluster(f, _m(Color("#8d9198"), 0.85, 0.3), dsteel, _m(Color("#17181b"), 0.5, 0.45), 0.8)
	return spread + r

## flat swept plate in the XZ plane (x forward, z span), thick in Y
static func _plate(p: Node3D, pts: PackedVector2Array, thick: float, m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(pts)
	var t := thick * 0.5
	var n := pts.size()
	for i in range(0, idx.size(), 3):
		var a := pts[idx[i]]
		var b := pts[idx[i + 1]]
		var c := pts[idx[i + 2]]
		OrionCV2._tri(st, Vector3(a.x, t, a.y), Vector3(b.x, t, b.y), Vector3(c.x, t, c.y), Vector3.UP, a * 1.4, b * 1.4, c * 1.4, -1)
		OrionCV2._tri(st, Vector3(a.x, -t, a.y), Vector3(b.x, -t, b.y), Vector3(c.x, -t, c.y), Vector3.DOWN, a * 1.4, b * 1.4, c * 1.4, -1)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var mid := (a + b) * 0.5
		var out := Vector3(mid.x, 0, mid.y)
		out = Vector3((b - a).y, 0, -(b - a).x)
		var A := Vector3(a.x, t, a.y)
		var B := Vector3(b.x, t, b.y)
		var C := Vector3(b.x, -t, b.y)
		var D := Vector3(a.x, -t, a.y)
		var uv := Vector2(0.5, 0.5)
		# winding-independent outward test uses the polygon centroid
		var cen := Vector2.ZERO
		for q in pts: cen += q
		cen /= n
		var o2 := Vector3(mid.x - cen.x, 0, mid.y - cen.y)
		OrionCV2._tri(st, A, B, C, o2, uv, uv, uv, -1)
		OrionCV2._tri(st, A, C, D, o2, uv, uv, uv, -1)
	OrionCV2._commit(st, p, m)

static func _wing_pts(span: float, chord: float, z0: float) -> PackedVector2Array:
	# swept trapezoid on +Z: root front, root back, tip back, tip front
	return PackedVector2Array([Vector2(chord * 0.5, z0), Vector2(-chord * 0.5, z0), Vector2(-chord * 0.62, z0 + span), Vector2(-chord * 0.12, z0 + span)])

static func _wing_trim(w: Node3D, span: float, chord: float, z0: float, sgn: float) -> void:
	var blue := _m(Color("#58b8ff"), 0.0, 0.3, 2.0)
	var gold := _m(GOLD, 0.9, 0.3)
	OrionCV2._rbox(w, Vector3(chord * 0.55, 0.012, 0.02), blue, Vector3(-chord * 0.1, 0.02, sgn * (z0 + span * 0.45)), 4.0, 6)
	OrionCV2._strut(w, Vector3(chord * 0.5, 0, z0), Vector3(-chord * 0.12, 0, z0 + span), 0.011, gold)

static func _wings(p: Node3D, kind: String, x: float, span: float, chord: float, R: float, hull: Material) -> void:
	var angles: Array = [0.0, PI] if kind in ["delta", "tall"] else [0.0, PI * 0.5, PI, PI * 1.5]
	var base := 0.0 if kind != "tall" else PI * 0.5
	var pts := _wing_pts(span, chord, R * 0.8)
	for a in angles:
		var w := Node3D.new()
		w.position = Vector3(x, 0, 0)
		w.rotation = Vector3(float(a) + base, 0, 0)
		p.add_child(w)
		_plate(w, pts, 0.035, hull)
		_wing_trim(w, span, chord, R * 0.8, 1.0)
		# the root fairing is a rounded bulge on the hull
		OrionCV2._rbox(w, Vector3(chord * 0.9, 0.09, 0.08), _m(Color("#cfc3a9"), 0.4, 0.5), Vector3(0, 0, R * 0.92), 4.0, 8)

static func _solar(p: Node3D, x: float, w: float, l: float, R: float, vertical: bool) -> void:
	var dsteel := _m(Color("#5b5f66"), 0.8, 0.38)
	for s in [-1.0, 1.0]:
		var off := Vector3(0, s * (R + 0.1 + w * 0.5), 0) if vertical else Vector3(0, 0, s * (R + 0.1 + w * 0.5))
		var arm_from := Vector3(x, 0, 0)
		OrionCV2._strut(p, arm_from, arm_from + (Vector3(0, s * (R + 0.1), 0) if vertical else Vector3(0, 0, s * (R + 0.1))), 0.02, dsteel)
		var rot := Vector3(PI / 2, 0, 0) if vertical else Vector3.ZERO
		UnitModels.solar(p, "as", w, l, Vector3(x, 0, 0) + off, rot)
		_gold_ring(p, x, 0.01, 0.0)

static func _bell(p: Node3D, pos: Vector3, rmax: float) -> void:
	var k := rmax / 0.128
	var steel := _m(Color("#8f949c"), 0.9, 0.32)
	var rib := _m(Color("#6c7077"), 0.9, 0.35)
	var inner := _m(Color("#101114"), 0.7, 0.3)
	_m(GOLD)
	var prof: Array = []
	var inprof: Array = []
	var n := 12
	for i in n + 1:
		var t := float(i) / n
		prof.append(Vector2(-0.04 * k - t * 0.28 * k, (0.036 + 0.092 * pow(t, 0.62)) * k))
		inprof.append(Vector2(-0.04 * k - t * 0.28 * k, (0.036 + 0.092 * pow(t, 0.62) - 0.008) * k))
	OrionCV2._lathe(p, prof, 24, steel, pos)
	OrionCV2._lathe(p, inprof, 24, inner, pos, true)
	UnitModels.cylx(p, 0.05 * k, 0.06 * k, 0.1 * k, _m(Color("#5b5f66"), 0.8, 0.38), pos + Vector3(-0.0 * k, 0, 0), 16)
	for i in 6:
		var t := 0.15 + i * 0.15
		var rr := (0.036 + 0.092 * pow(t, 0.62)) * k + 0.004
		UnitModels.ring(p, rr - 0.002, rr + (0.012 if i % 3 == 0 else 0.008) * k, rib, pos + Vector3(-0.04 * k - t * 0.28 * k, 0, 0), Vector3(0, 0, PI / 2))
	UnitModels.ring(p, 0.12 * k, 0.136 * k, _m(GOLD, 0.9, 0.3), pos + Vector3(-0.32 * k, 0, 0), Vector3(0, 0, PI / 2))

static func _engines(p: Node3D, x: float, R: float, n: int, hull: Material) -> void:
	var tr := R * 0.62
	# tapering tail section, then the engine mount plate
	var pts: Array = [Vector2(x, 0.001), Vector2(x, R * 0.9), Vector2(x - 0.07, R * 0.97), Vector2(x - 0.28, tr), Vector2(x - 0.3, 0.001)]
	OrionCV2._lathe(p, pts, 32, hull, Vector3.ZERO)
	_gold_ring(p, x - 0.04, R * 0.95, 0.01)
	var ex := x - 0.3
	var offs: Array = []
	var rm := 0.0
	match n:
		1:
			offs = [Vector2.ZERO]
			rm = tr * 0.82
		2:
			offs = [Vector2(0, tr * 0.5), Vector2(0, -tr * 0.5)]
			rm = tr * 0.45
		3:
			for i in 3: offs.append(Vector2(sin(PI * 0.5 + i * TAU / 3), cos(PI * 0.5 + i * TAU / 3)) * tr * 0.52)
			rm = tr * 0.42
		_:
			offs = [Vector2(tr * 0.5, tr * 0.5), Vector2(tr * 0.5, -tr * 0.5), Vector2(-tr * 0.5, tr * 0.5), Vector2(-tr * 0.5, -tr * 0.5)]
			rm = tr * 0.4
	for o in offs:
		_bell(p, Vector3(ex, o.x, o.y), rm)
		# thin trusses to the mount
		if n > 1:
			var dsteel := _m(Color("#5b5f66"), 0.8, 0.38)
			OrionCV2._strut(p, Vector3(ex + 0.01, o.x * 1.1, o.y * 1.1), Vector3(ex - 0.06 * rm / 0.1, o.x, o.y), 0.007, dsteel)

# ------------------------------------------------------------------ the model
static func build(name: String) -> Node3D:
	var spec: Dictionary = SPECS[name]
	var root := Node3D.new()
	root.name = "Asia_" + name.replace("-", "_")
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	var x := 0.0
	var nose: Array = spec["nose"]
	var nose_len := 0.0
	if nose[0] == "sphere":
		nose_len = _nose(core, 0.0, nose, hull)
		x -= nose_len
	else:
		x = -nose[2]            # nose tip is at x=0.. so the shoulder sits at -L; shift later
		_nose(core, -nose[2] + 0.0, nose, hull)
	var R: float = nose[1]
	var rear_r := R
	var pending_conn := false
	for m in spec["mods"]:
		var t: String = m[0]
		match t:
			"conn":
				_conn(core, x, 0.11, 0.1)
				x -= 0.1
			"barrel", "hab":
				var L: float = m[1]
				var r: float = m[2]
				_barrel(core, x, L, r, hull)
				if t == "hab":
					for a in [0.0, PI]:
						var f := OrionCV2._radial(core, x - L * 0.5, a, r * 0.99)
						_porthole(f, 0.045)
				x -= L
				R = r
				rear_r = r
			"eye":
				_eye(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = m[2]
			"tanks":
				rear_r = _tanks(core, x, m[1], m[2], m[3], int(m[4]), hull)
				x -= m[1]
			"delta", "cross", "tall":
				var chord: float = m[2]
				_wings(core, t, x - chord * 0.05, m[1], chord, R, hull)
			"solar":
				_solar(core, x - 0.05, m[1], m[2], R, false)
			"solarv":
				_solar(core, x - 0.05, m[1], m[2], R, true)
	_engines(core, x, rear_r if spec["eng"] > 1 else R, int(spec["eng"]), hull)
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
