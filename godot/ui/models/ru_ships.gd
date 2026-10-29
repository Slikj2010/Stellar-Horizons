## Russia's crew ships (CV-2 .. CV-8): round rivetted cream command spheres with orange bands, cylindrical cream/black
## modules, lattice frames, black cell arrays, gold solar arrays, a big black engine bell, and two spaceplane lines
## (Komarov / Volkov and Moskva / Vladivostok) with delta wings and gold tail fins.  Nose points to +X.
## Not wired into the game yet; see tests/ru_preview.gd for renders.
class_name RUShips
extends RefCounted

## nose: ["sphere", R] or ["needle", R, L]
## mods: ["neck"] ["barrel", L, R] ["dark", L, R] ["truss", L, R] ["cells", L, R] ["drum", L, R] ["spheres", L, R]
##       ["sphere2", R] ["panels", span, w] ["panelsv", span, w]
## kind "plane": modules form a flattened fuselage and wings come from ["delta", span, chord], ["tall", span, chord], ["fin", span, chord]
const SPECS := {
	"Kliper": {"nose": ["sphere", 0.36], "mods": [["neck"], ["barrel", 0.5, 0.3], ["truss", 0.45, 0.3], ["barrel", 0.5, 0.31]]},
	"Renda": {"nose": ["sphere", 0.34], "mods": [["neck"], ["barrel", 0.4, 0.28], ["barrel", 0.8, 0.31], ["barrel", 0.3, 0.29]]},
	"Leonov": {"nose": ["sphere", 0.34], "mods": [["sphere2", 0.34], ["barrel", 0.9, 0.32], ["panelsv", 0.4, 0.6]], "eng": 2},
	"Titov": {"nose": ["sphere", 0.3], "mods": [["neck"], ["barrel", 0.4, 0.28], ["truss", 1.0, 0.32], ["panelsv", 0.5, 1.0], ["barrel", 0.3, 0.3]], "eng": 2},
	"Gagarin": {"nose": ["sphere", 0.32], "mods": [["neck"], ["barrel", 0.5, 0.22], ["spheres", 0.5, 0.26], ["barrel", 0.6, 0.27], ["panels", 0.35, 0.3], ["panelsv", 0.35, 0.3]]},
	"Tereshkova": {"nose": ["sphere", 0.3], "mods": [["neck"], ["barrel", 0.6, 0.24], ["spheres", 0.5, 0.26], ["barrel", 0.5, 0.27], ["panels", 0.35, 0.3], ["panelsv", 0.35, 0.3]]},
	"Korolev": {"nose": ["sphere", 0.38], "mods": [["neck"], ["barrel", 0.5, 0.3], ["cells", 0.9, 0.3], ["barrel", 0.5, 0.32], ["panelsv", 0.45, 0.45]], "eng": 2},
	"Tsiolkovsky": {"nose": ["sphere", 0.36], "mods": [["neck"], ["barrel", 0.5, 0.29], ["cells", 1.0, 0.3], ["barrel", 0.5, 0.32], ["panelsv", 0.45, 0.45]], "eng": 2},
	"Kuznetsov": {"nose": ["sphere", 0.4], "mods": [["neck"], ["barrel", 0.9, 0.32], ["cells", 0.8, 0.3], ["drum", 0.5, 0.42]], "eng": 3},
	"Pyotr Velikiy": {"nose": ["sphere", 0.42], "mods": [["neck"], ["barrel", 1.0, 0.33], ["barrel", 0.7, 0.33], ["cells", 0.8, 0.31], ["drum", 0.6, 0.46]], "eng": 3},
	"Komarov": {"kind": "plane", "nose": ["needle", 0.2, 1.1], "mods": [["barrel", 0.9, 0.2], ["delta", 0.85, 1.0], ["tall", 0.55, 0.5]]},
	"Volkov": {"kind": "plane", "nose": ["needle", 0.2, 1.1], "mods": [["barrel", 0.8, 0.2], ["delta", 0.75, 1.1], ["tall", 0.7, 0.55]]},
	"Moskva": {"kind": "plane", "nose": ["needle", 0.34, 1.2], "mods": [["barrel", 1.4, 0.36], ["delta", 1.0, 1.2], ["tall", 0.6, 0.6]]},
	"Vladivostok": {"kind": "plane", "nose": ["needle", 0.34, 1.3], "mods": [["barrel", 1.3, 0.36], ["delta", 1.1, 1.3], ["tall", 0.55, 0.6]]},
}

const ORANGE := Color("#d98a2b")
const LAMP := Color("#ffb347")

static func has(name: String) -> bool:
	return SPECS.has(name)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("ru_hull%d" % sd, 1024, 512, {"seed": 611 + sd * 31, "cols": 24, "min_len": 40, "max_len": 120, "black_rate": 0.03, "grime": 0.6, "tones": [Color("#dedbd2"), Color("#d0ccc1"), Color("#c3beb2"), Color("#e8e5dc"), Color("#b8b3a7")], "seam": Color("#6c6a63")}, 0.3, 0.55)

static func _gold(p: Node3D, x: float, r: float) -> void:
	UnitModels.ring(p, r - 0.004, r + 0.026, _m(ORANGE, 0.85, 0.35), Vector3(x, 0, 0), Vector3(0, 0, PI / 2))

# ------------------------------------------------------------------ parts
static func _pod(p: Node3D, cx: float, r: float, hull: Material, window := true) -> void:
	UnitModels.ball(p, r, hull, Vector3(cx, 0, 0))
	for dx in [-0.45, 0.0, 0.45]:
		var rr := r * sqrt(1.0 - dx * dx)
		_gold(p, cx + r * dx, rr * 0.99)
	if window:
		var f := OrionCV2._radial(p, cx + r * 0.9, PI * 0.5, r * 0.3)
		UnitModels.ring(f, 0.045, 0.07, _m(ORANGE, 0.85, 0.35), Vector3.ZERO)
		UnitModels.ball(f, 0.045, _m(Color("#16365e"), 0.9, 0.1, 0.4), Vector3(0, 0.01, 0), Vector3(1, 0.45, 1))
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	OrionCV2._strut(p, Vector3(cx + r * 0.95, 0, 0), Vector3(cx + r * 1.2, 0, 0), 0.01, steel)

static func _neck(p: Node3D, x: float, r0: float, r1: float, L: float) -> void:
	UnitModels.cylx(p, r0, r1, L, _m(Color("#4a4d55"), 0.8, 0.4), Vector3(x - L * 0.5, 0, 0), 20)
	_gold(p, x - L, r1 * 1.02)

static func _cells(p: Node3D, xf: float, L: float, R: float) -> void:
	var dark := _m(Color("#17181b"), 0.55, 0.45)
	var cell := _m(Color("#2b2d33"), 0.6, 0.4)
	UnitModels.cylx(p, R * 0.94, R * 0.94, L, dark, Vector3(xf - L * 0.5, 0, 0), 28)
	var rows := maxi(4, int(L / 0.13))
	var n := 14
	for r in rows:
		var x := xf - L * (r + 0.5) / rows
		for i in n:
			var a := i * TAU / n + (PI / n if r % 2 == 1 else 0.0)
			var f := OrionCV2._radial(p, x, a, R * 0.96)
			OrionCV2._rbox(f, Vector3(L / rows * 0.8, 0.06, 0.09), cell, Vector3.ZERO, 3.5, 4)
	_gold(p, xf - 0.01, R)
	_gold(p, xf - L + 0.01, R)

static func _spheres(p: Node3D, xf: float, L: float, R: float, hull: Material) -> void:
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	UnitModels.cylx(p, R * 0.8, R * 0.8, L, _m(Color("#4a4d55"), 0.8, 0.4), Vector3(xf - L * 0.5, 0, 0), 20)
	for col in 2:
		var x := xf - L * (0.28 + 0.44 * col)
		for i in 8:
			var a := i * TAU / 8.0
			UnitModels.ball(p, R * 0.42, hull, Vector3(x, (R * 0.9) * sin(a), (R * 0.9) * cos(a)))
		UnitModels.ball(p, R * 0.5, hull, Vector3(x, 0, 0))
		UnitModels.ring(p, R * 0.8, R * 0.9, steel, Vector3(x, 0, 0), Vector3(0, 0, PI / 2))

static func _panel(p: Node3D, x: float, R: float, span: float, w: float, vertical: bool) -> void:
	SAShips._array(p, x, R, span, w, vertical)

static func _bell(core: Node3D, ex: float, oy: float, oz: float, rm: float) -> void:
	var bk := _m(Color("#1c1d21"), 0.7, 0.4)
	var prof: Array = []
	var inprof: Array = []
	for i in 13:
		var tt := float(i) / 12.0
		var r := 0.04 * rm / 0.15 + (rm - 0.04 * rm / 0.15) * pow(tt, 0.7)
		prof.append(Vector2(-tt * 0.5 * rm / 0.15, r))
		inprof.append(Vector2(-tt * 0.5 * rm / 0.15, r - 0.008))
	var at := Vector3(ex, oy, oz)
	OrionCV2._lathe(core, prof, 28, bk, at)
	OrionCV2._lathe(core, inprof, 28, _m(Color("#08090b"), 0.4, 0.4), at, true)
	for i in 4:
		var rx := -(0.1 + i * 0.1) * rm / 0.15
		UnitModels.ring(core, rm * 0.5 + i * rm * 0.14, rm * 0.5 + i * rm * 0.14 + 0.012, _m(ORANGE, 0.85, 0.35), at + Vector3(rx, 0, 0), Vector3(0, 0, PI / 2))
	UnitModels.ring(core, rm * 0.98, rm * 1.05, _m(ORANGE, 0.85, 0.35), at + Vector3(-0.5 * rm / 0.15, 0, 0), Vector3(0, 0, PI / 2))

# ------------------------------------------------------------------ the model
static func build(name: String) -> Node3D:
	var spec: Dictionary = SPECS[name]
	var plane: bool = spec.get("kind", "") == "plane"
	var root := Node3D.new()
	root.name = "RU_" + name.replace(" ", "_")
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	var goldm := _m(Color("#d19a2f"), 0.8, 0.35)
	AsiaShips.trim_col = ORANGE
	var body := core
	if plane:
		body = Node3D.new()
		body.scale = Vector3(1, 0.62 if name in ["Moskva", "Vladivostok"] else 0.8, 1)
		core.add_child(body)
	var nose: Array = spec["nose"]
	var R: float = nose[1]
	var x := 0.0
	if nose[0] == "sphere":
		_pod(body, -R, R, hull)
		x = -R * 2.0
	else:
		x = -nose[2]
		AsiaShips._nose(body, x, ["needle", nose[1], nose[2]], hull)
		AsiaShips._gold_ring(body, x + 0.01, R * 0.97, 0.01)
	var rear_r := R
	for m in spec["mods"]:
		var t: String = m[0]
		match t:
			"neck":
				_neck(core, x, R * 0.4, 0.17, 0.14)
				x -= 0.14
			"sphere2":
				_pod(core, x - m[1] * 0.9, m[1], hull, false)
				x -= m[1] * 1.8
				R = m[1]
			"barrel":
				AsiaShips._barrel(body, x, m[1], m[2], hull, LAMP)
				x -= m[1]
				R = m[2]
				rear_r = R
			"truss":
				NAShips._truss(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"cells":
				_cells(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"drum":
				NAShips._ribbed(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"spheres":
				_spheres(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"panels":
				_panel(core, x + 0.15, R, m[1], m[2], false)
			"panelsv":
				_panel(core, x + 0.15, R, m[1], m[2], true)
			"delta":
				AsiaShips._wings(core, "delta", x + m[2] * 0.2, m[1], m[2], R, hull)
			"tall", "fin":
				AsiaShips._wings(core, t, x + m[2] * 0.25, m[1], m[2], R, goldm)
	# big black engine bell on a short taper
	var tr := rear_r * 0.7
	var pts: Array = [Vector2(x, 0.001), Vector2(x, rear_r * 0.92), Vector2(x - 0.07, rear_r), Vector2(x - 0.26, tr), Vector2(x - 0.28, 0.001)]
	OrionCV2._lathe(core, pts, 32, hull, Vector3.ZERO)
	_gold(core, x - 0.05, rear_r * 0.97)
	var ex := x - 0.28
	var n: int = SPECS[name].get("eng", 1)
	var offs: Array = []
	var rm := tr * 0.95
	match n:
		1:
			offs = [Vector2.ZERO]
		2:
			offs = [Vector2(0, tr * 0.52), Vector2(0, -tr * 0.52)]
			rm = tr * 0.5
		3:
			for k in 3:
				offs.append(Vector2(sin(PI * 0.5 + k * TAU / 3), cos(PI * 0.5 + k * TAU / 3)) * tr * 0.55)
			rm = tr * 0.44
		_:
			offs = [Vector2(tr * 0.5, tr * 0.5), Vector2(tr * 0.5, -tr * 0.5), Vector2(-tr * 0.5, tr * 0.5), Vector2(-tr * 0.5, -tr * 0.5)]
			rm = tr * 0.42
	for o in offs:
		_bell(core, ex, o.x, o.y, rm)
	AsiaShips.trim_col = Color("#58b8ff")
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
