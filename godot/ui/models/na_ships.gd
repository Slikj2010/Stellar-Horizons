## North America's CV-2 .. CV-8 crew ships (everything except Orion / Discovery, which live in orion_cv2.gd): grey-white
## riveted plating, gold fittings and solar panels, black ribbed barrels, lattice trusses, strap-on tank bundles, shuttle-style
## wings and either clustered ribbed bells or a big glowing plume nozzle.  Shares its kit with AsiaShips / OrionCV2.
## Not wired into the game yet; see tests/na_preview.gd for renders.
class_name NAShips
extends RefCounted

## nose: ["ogive"|"needle", R, L] ["capsule", R, L] ["sail", W, L]
## mods: ["barrel", L, R] ["dark", L, R] ["ribbed", L, R] ["truss", L, R] ["bundle", n, tube_r]  (bundle wraps the previous barrel)
##       ["goldtanks", n, r] ["hexsolar", span, len] ["diamond", span, len] ["longsolar", span, w]
##       ["delta", span, chord] ["fin", span, chord]
## eng: n bells, or 0 for the plume nozzle
const SPECS := {
	"Gemini": {"nose": ["needle", 0.26, 0.8], "mods": [["barrel", 0.6, 0.3], ["barrel", 0.85, 0.34], ["bundle", 6, 0.065]], "eng": 4},
	"Artemis": {"nose": ["needle", 0.22, 1.0], "mods": [["barrel", 0.9, 0.27], ["delta", 1.0, 1.3], ["fin", 0.55, 0.6], ["barrel", 0.5, 0.3]], "eng": 3},
	"Venture": {"nose": ["capsule", 0.28, 0.5], "mods": [["barrel", 0.6, 0.3], ["barrel", 0.7, 0.34], ["bundle", 6, 0.07], ["hexsolar", 1.3, 1.0]], "eng": 4},
	"Falcon": {"nose": ["ogive", 0.3, 0.55], "mods": [["barrel", 0.8, 0.3], ["dark", 0.3, 0.32], ["barrel", 0.4, 0.32], ["diamond", 1.2, 0.9]], "eng": 4},
	"Andromeda": {"nose": ["capsule", 0.22, 0.5], "mods": [["truss", 1.1, 0.17], ["barrel", 0.45, 0.3], ["goldtanks", 6, 0.09], ["longsolar", 1.3, 0.22]], "eng": 4},
	"Centaurus": {"nose": ["capsule", 0.22, 0.5], "mods": [["truss", 1.3, 0.17], ["barrel", 0.45, 0.3], ["goldtanks", 4, 0.1], ["longsolar", 1.3, 0.22]], "eng": 3},
	"Endeavor": {"nose": ["ogive", 0.38, 0.65], "mods": [["barrel", 0.5, 0.38], ["ribbed", 1.0, 0.42]], "eng": 4},
	"Enterprise": {"nose": ["ogive", 0.38, 0.7], "mods": [["barrel", 0.55, 0.38], ["ribbed", 1.1, 0.42]], "eng": 4},
	"Atlantis": {"nose": ["capsule", 0.25, 0.45], "mods": [["barrel", 0.3, 0.24], ["ribbed", 1.2, 0.2], ["barrel", 0.4, 0.3]], "eng": 0},
	"Polaris": {"nose": ["capsule", 0.25, 0.5], "mods": [["barrel", 0.35, 0.25], ["ribbed", 1.3, 0.2], ["barrel", 0.4, 0.3]], "eng": 0},
	"Constitution": {"nose": ["sail", 0.8, 0.9], "mods": [["truss", 1.0, 0.17], ["ribbed", 0.6, 0.2], ["barrel", 0.45, 0.3]], "eng": 0},
	"Intrepid": {"nose": ["capsule", 0.26, 0.5], "mods": [["barrel", 0.3, 0.26], ["ribbed", 1.2, 0.22], ["barrel", 0.45, 0.3]], "eng": 0},
}

const GOLD := Color("#d6a82a")
const LAMP := Color("#ffb347")

static func has(name: String) -> bool:
	return SPECS.has(name)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("na_hull%d" % sd, 1024, 512, {"seed": 411 + sd * 23, "cols": 24, "min_len": 60, "max_len": 220, "black_rate": 0.08, "grime": 0.85, "tones": [Color("#dcdcd8"), Color("#cfcfca"), Color("#c3c3be"), Color("#e6e6e2"), Color("#b9b9b4")], "seam": Color("#4a4b50")}, 0.4, 0.5)

# ------------------------------------------------------------------ parts
static func _ribbed(p: Node3D, xf: float, L: float, R: float, hull: Material) -> void:
	var dark := _m(Color("#1d1e22"), 0.5, 0.5)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var white := _m(Color("#d9d9d4"), 0.4, 0.5)
	UnitModels.cylx(p, R * 0.9, R * 0.9, L, dark, Vector3(xf - L * 0.5, 0, 0), 32)
	var n := 24
	for i in n:
		var a := i * TAU / n
		var f := OrionCV2._radial(p, xf - L * 0.5, a, R * 0.93)
		OrionCV2._rbox(f, Vector3(L * 0.94, 0.05, 0.035), white, Vector3.ZERO, 3.5, 5)
	for k in 4:
		var rx := xf - L * (0.03 + k * 0.32)
		UnitModels.ring(p, R * 0.95, R * 1.03, steel, Vector3(rx, 0, 0), Vector3(0, 0, PI / 2))
	AsiaShips._gold_ring(p, xf - L * 0.5, R * 0.99, 0.01)

static func _truss(p: Node3D, xf: float, L: float, R: float) -> void:
	var steel := _m(Color("#aeb3ba"), 0.85, 0.3)
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	var gold := _m(GOLD, 0.9, 0.3)
	var corners: Array = []
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		corners.append(Vector2(sin(a), cos(a)) * R)
	for c in corners:
		OrionCV2._strut(p, Vector3(xf, c.x, c.y), Vector3(xf - L, c.x, c.y), 0.012, steel)
	var bays := int(L / 0.18)
	for b in bays + 1:
		var x := xf - L * float(b) / bays
		for k in 4:
			var c0: Vector2 = corners[k]
			var c1: Vector2 = corners[(k + 1) % 4]
			OrionCV2._strut(p, Vector3(x, c0.x, c0.y), Vector3(x, c1.x, c1.y), 0.008, dsteel)
			if b < bays:
				var xn := xf - L * float(b + 1) / bays
				OrionCV2._strut(p, Vector3(x, c0.x, c0.y), Vector3(xn, c1.x, c1.y), 0.006, steel)
		UnitModels.ball(p, 0.018, gold, Vector3(x, corners[0].x, corners[0].y))
	# central fuel line
	UnitModels.cylx(p, 0.04, 0.04, L, _m(Color("#b9794a"), 0.85, 0.35), Vector3(xf - L * 0.5, 0, 0), 12)

static func _tube(p: Node3D, pos: Vector3, L: float, r: float, hull: Material) -> void:
	var pts: Array = [Vector2(L * 0.5 + r * 1.4, 0.001), Vector2(L * 0.5 + r * 0.7, r * 0.6), Vector2(L * 0.5, r), Vector2(-L * 0.5, r), Vector2(-L * 0.5 - r * 0.4, r * 0.7), Vector2(-L * 0.5 - r * 0.5, 0.001)]
	OrionCV2._lathe(p, pts, 16, hull, pos)
	UnitModels.ring(p, r * 0.97, r * 1.12, _m(GOLD, 0.9, 0.3), pos + Vector3(L * 0.25, 0, 0), Vector3(0, 0, PI / 2))

static func _bundle(p: Node3D, xf: float, L: float, R: float, n: int, tr: float, hull: Material) -> void:
	for i in n:
		var a := i * TAU / n + PI / n
		var rad := R + tr * 0.85
		_tube(p, Vector3(xf - L * 0.5, rad * sin(a), rad * cos(a)), L * 0.92, tr, hull)
	# mounting collar
	UnitModels.ring(p, R * 0.98, R * 1.06, _m(Color("#9aa0a8"), 0.85, 0.3), Vector3(xf - L * 0.2, 0, 0), Vector3(0, 0, PI / 2))
	UnitModels.ring(p, R * 0.98, R * 1.06, _m(Color("#9aa0a8"), 0.85, 0.3), Vector3(xf - L * 0.8, 0, 0), Vector3(0, 0, PI / 2))

static func _goldtanks(p: Node3D, x: float, R: float, n: int, r: float) -> void:
	var gold := _m(GOLD, 0.9, 0.28)
	for i in n:
		var a := i * TAU / n
		UnitModels.ball(p, r, gold, Vector3(x, (R + r * 0.6) * sin(a), (R + r * 0.6) * cos(a)), Vector3(1.4, 1, 1))
		UnitModels.ring(p, r * 0.8, r * 1.05, _m(Color("#4a4d55"), 0.8, 0.4), Vector3(x, (R + r * 0.6) * sin(a), (R + r * 0.6) * cos(a)), Vector3(0, 0, PI / 2))

static func _panel_mat(w: float, l: float) -> StandardMaterial3D:
	return UnitModels.panel_mat(Color("#c79a2b"), Vector2(maxf(2.0, w * 4.0), maxf(2.0, l * 4.0)))

static func _hexsolar(p: Node3D, x: float, R: float, span: float, len: float) -> void:
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	for s in [-1.0, 1.0]:
		var zc: float = s * (R + 0.18 + span * 0.12)
		var hl := len * 0.5
		var hw := span * 0.5
		var pts := PackedVector2Array([Vector2(hl, 0), Vector2(hl * 0.5, -hw * 0.4), Vector2(-hl * 0.5, -hw * 0.4), Vector2(-hl, 0), Vector2(-hl * 0.5, hw * 0.4), Vector2(hl * 0.5, hw * 0.4)])
		var n := Node3D.new()
		n.position = Vector3(x, 0, zc)
		n.rotation = Vector3(0, 0, 0)
		p.add_child(n)
		AsiaShips._plate(n, pts, 0.03, _panel_mat(span, len))
		OrionCV2._strut(p, Vector3(x, 0, 0), Vector3(x, 0, zc), 0.02, dsteel)

static func _diamond(p: Node3D, x: float, R: float, span: float, len: float) -> void:
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	for s in [-1.0, 1.0]:
		var zc: float = s * (R + 0.1 + span * 0.5)
		var pts := PackedVector2Array([Vector2(len * 0.5, 0), Vector2(0, -span * 0.5), Vector2(-len * 0.5, 0), Vector2(0, span * 0.5)])
		var n := Node3D.new()
		n.position = Vector3(x, 0, zc)
		p.add_child(n)
		AsiaShips._plate(n, pts, 0.03, _panel_mat(span, len))
		OrionCV2._strut(p, Vector3(x, 0, 0), Vector3(x, 0, zc - s * span * 0.5), 0.02, dsteel)

static func _longsolar(p: Node3D, x: float, R: float, span: float, w: float) -> void:
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	for s in [-1.0, 1.0]:
		var zc: float = s * (R + span * 0.5 + 0.05)
		var pts := PackedVector2Array([Vector2(w * 0.5, -span * 0.5), Vector2(-w * 0.5, -span * 0.5), Vector2(-w * 0.5, span * 0.5), Vector2(w * 0.5, span * 0.5)])
		var n := Node3D.new()
		n.position = Vector3(x, 0, zc)
		p.add_child(n)
		AsiaShips._plate(n, pts, 0.03, _panel_mat(w, span))
		OrionCV2._strut(p, Vector3(x, 0, 0), Vector3(x, 0, s * (R + 0.05)), 0.02, dsteel)

static func _sail(p: Node3D, xf: float, W: float, L: float) -> float:
	# square pyramid sail, diamond-oriented, lattice faces
	var brown := UnitModels.panel_mat(Color("#8a5a2a"), Vector2(6, 6)).duplicate() as StandardMaterial3D
	brown.cull_mode = BaseMaterial3D.CULL_DISABLED
	var steel := _m(Color("#aeb3ba"), 0.85, 0.3)
	var gold := _m(GOLD, 0.9, 0.3)
	var apex := Vector3(xf + L, 0, 0)
	var cs: Array = []
	for k in 4:
		var a := k * PI * 0.5
		cs.append(Vector3(xf, W * sin(a), W * cos(a)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a: Vector3 = cs[k]
		var b: Vector3 = cs[(k + 1) % 4]
		var mid := (a + b) * 0.5
		OrionCV2._tri(st, apex, a, b, Vector3(0.4, mid.y, mid.z), Vector2(0.5, 0), Vector2(0, 1), Vector2(1, 1), -1)
	OrionCV2._commit(st, p, brown)
	for k in 4:
		OrionCV2._strut(p, apex, cs[k], 0.012, steel)
		OrionCV2._strut(p, cs[k], cs[(k + 1) % 4], 0.012, steel)
		UnitModels.ball(p, 0.02, gold, cs[k])
	UnitModels.ball(p, 0.03, gold, apex)
	return 0.0

static func _plume(p: Node3D, x: float, R: float, hull: Material) -> void:
	var tr := R * 0.75
	var pts: Array = [Vector2(x, 0.001), Vector2(x, R * 0.9), Vector2(x - 0.06, R), Vector2(x - 0.22, tr), Vector2(x - 0.24, 0.001)]
	OrionCV2._lathe(p, pts, 32, hull, Vector3.ZERO)
	AsiaShips._gold_ring(p, x - 0.04, R * 0.97, 0.01)
	var ex := x - 0.24
	var rm := tr * 0.95
	AsiaShips._bell(p, Vector3(ex, 0, 0), rm)
	var k := rm / 0.128
	UnitModels.cylx(p, 0.11 * k, 0.11 * k, 0.01, _m(Color("#ffd27a"), 0.0, 0.3, 3.0), Vector3(ex - 0.3 * k, 0, 0), 24)

# ------------------------------------------------------------------ the model
static func build(name: String) -> Node3D:
	var spec: Dictionary = SPECS[name]
	var root := Node3D.new()
	root.name = "NA_" + name
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	var dark := _m(Color("#26282d"), 0.5, 0.5)
	var nose: Array = spec["nose"]
	var R: float = nose[1]
	var x := 0.0
	match nose[0]:
		"sail":
			_sail(core, -0.1, nose[1], nose[2])
			x = -0.1
			# short neck from the sail into the truss
			AsiaShips._conn(core, x, 0.1, 0.1)
			x -= 0.1
			R = 0.2
		"capsule":
			x = -nose[2]
			AsiaShips._nose(core, x, ["ogive", nose[1], nose[2]], hull)
			OrionCV2._strut(core, Vector3(0, 0, 0), Vector3(0.18, 0, 0), 0.007, _m(Color("#aeb3ba"), 0.85, 0.3))
			UnitModels.ball(core, 0.016, _m(GOLD, 0.9, 0.3), Vector3(0.18, 0, 0))
		_:
			x = -nose[2]
			AsiaShips._nose(core, x, nose, hull)
	var last_xf := x
	var last_L := 0.0
	var rear_r := R
	for m in spec["mods"]:
		var t: String = m[0]
		match t:
			"barrel", "dark":
				AsiaShips._barrel(core, x, m[1], m[2], dark if t == "dark" else hull, LAMP)
				last_xf = x
				last_L = m[1]
				x -= m[1]
				R = m[2]
				rear_r = R
			"ribbed":
				_ribbed(core, x, m[1], m[2], hull)
				last_xf = x
				last_L = m[1]
				x -= m[1]
				R = m[2]
				rear_r = R
			"truss":
				_truss(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"bundle":
				_bundle(core, last_xf, last_L, R, int(m[1]), m[2], hull)
				rear_r = R + m[2] * 1.7
			"goldtanks":
				_goldtanks(core, x + 0.25, R, int(m[1]), m[2])
				rear_r = maxf(rear_r, R + m[2] * 1.2)
			"hexsolar":
				_hexsolar(core, x + last_L * 0.5, R, m[1], m[2])
			"diamond":
				_diamond(core, x + last_L * 0.5, R, m[1], m[2])
			"longsolar":
				_longsolar(core, x + 0.1, R, m[1], m[2])
			"delta", "fin":
				var chord: float = m[2]
				AsiaShips._wings(core, t, x + chord * 0.25, m[1], chord, R, hull)
	if int(spec["eng"]) == 0:
		_plume(core, x, R, hull)
	else:
		AsiaShips._engines(core, x, rear_r, int(spec["eng"]), hull)
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
