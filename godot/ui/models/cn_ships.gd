## China's crew ships (CV-2 .. CV-7): grey riveted hulls with gold bracket trim, a blue band behind the pointed nose, small red
## flag decals, hab barrels with window rows, gold solar arrays, lattice/pod modules (Honglong, Tianlong), flat ladder rings
## (Taizhou, Yun Baolei only -- Qing has none), a pair of lifting-body shuttles (Liwei, Song), and 3-4 black bells.
## Nose points to +X.  Not wired into the game yet; see tests/cn_preview.gd for renders.
class_name CNShips
extends RefCounted

## nose: [R, L]   mods: ["barrel", L, R] ["truss", L, R] ["pods", R] ["ring", Ro, nodes] ["panels", span, w] ["panels", span, w]
## panels* are placed on the previous barrel (centre) -- "back" shifts them toward the tail
const SPECS := {
	"Jinlong": {"nose": [0.32, 0.6], "mods": [["barrel", 0.45, 0.33], ["barrel", 1.1, 0.42], ["panels", 0.42, 0.38]], "eng": 3},
	"Shenzhou": {"nose": [0.3, 0.55], "mods": [["barrel", 0.5, 0.33], ["barrel", 0.95, 0.4], ["panels", 0.42, 0.38]], "eng": 3},
	"Lulong": {"nose": [0.3, 0.6], "mods": [["barrel", 0.45, 0.32], ["barrel", 1.0, 0.42], ["panels", 0.42, 0.38]], "eng": 3},
	"Liaoning": {"nose": [0.28, 0.55], "mods": [["barrel", 0.4, 0.3], ["barrel", 0.6, 0.36], ["barrel", 0.75, 0.43], ["panels", 0.7, 0.4]], "eng": 4},
	"Honglong": {"nose": [0.26, 0.5], "mods": [["barrel", 0.35, 0.28], ["pods", 0.1], ["truss", 0.9, 0.14], ["barrel", 0.7, 0.4], ["panels", 0.9, 0.38]], "eng": 3},
	"Tianlong": {"nose": [0.26, 0.5], "mods": [["barrel", 0.35, 0.3], ["pods", 0.1], ["truss", 0.9, 0.14], ["barrel", 0.7, 0.4], ["panels", 0.9, 0.38]], "eng": 3},
	"Huang He": {"nose": [0.4, 1.0], "mods": [["barrel", 1.4, 0.45], ["barrel", 0.9, 0.44], ["panels", 0.5, 0.9]], "eng": 3},
	"Yangtze": {"nose": [0.38, 1.2], "mods": [["barrel", 2.2, 0.43], ["panels", 0.5, 0.9]], "eng": 3},
	"Han": {"nose": [0.3, 0.7], "mods": [["barrel", 0.9, 0.38], ["barrel", 1.2, 0.42], ["barrel", 0.5, 0.45], ["panels", 0.45, 0.36]], "eng": 3},
	"Qing": {"nose": [0.3, 0.6], "mods": [["barrel", 0.5, 0.36], ["barrel", 1.1, 0.3], ["barrel", 0.7, 0.44], ["panels", 0.45, 0.36]], "eng": 3},
	"Shang": {"nose": [0.3, 0.9], "mods": [["barrel", 1.3, 0.4], ["barrel", 0.7, 0.43], ["panels", 0.4, 0.36]], "eng": 3},
	"Taizhou": {"nose": [0.3, 0.7], "mods": [["barrel", 0.5, 0.36], ["ring", 0.8, 4], ["barrel", 1.0, 0.36], ["barrel", 0.6, 0.44]], "eng": 4},
	"Yun Baolei": {"nose": [0.3, 0.8], "mods": [["barrel", 0.5, 0.36], ["ring", 1.0, 4], ["barrel", 1.0, 0.38], ["barrel", 0.6, 0.46]], "eng": 4},
	"Liwei": {"kind": "plane", "R": 0.4, "L": 2.3, "span": 0.95},
	"Song": {"kind": "plane", "R": 0.35, "L": 2.5, "span": 0.85},
}

const GOLD := Color("#d6a82a")
const LAMP := Color("#ffb347")

static func has(name: String) -> bool:
	return SPECS.has(name)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("cn_hull%d" % sd, 1024, 512, {"seed": 1051 + sd * 41, "cols": 24, "min_len": 50, "max_len": 190, "black_rate": 0.04, "grime": 0.8, "tones": [Color("#cfd0cf"), Color("#c2c3c3"), Color("#b6b8b9"), Color("#d8d9d8"), Color("#a9abad")], "seam": Color("#8a6d28")}, 0.4, 0.5)

static func _flag(p: Node3D, x: float, R: float, a := PI * 0.5) -> void:
	var f := OrionCV2._radial(p, x, a, R * 0.99)
	OrionCV2._rbox(f, Vector3(0.1, 0.014, 0.065), _m(Color("#c8202a"), 0.2, 0.5, 0.3), Vector3.ZERO, 4.0, 6)
	UnitModels.ball(f, 0.012, _m(GOLD, 0.9, 0.3), Vector3(-0.025, 0.008, -0.015))

## gold bracket corners around a barrel end (small plates standing proud of the hull)
static func _brackets(p: Node3D, x: float, R: float) -> void:
	var gold := _m(GOLD, 0.9, 0.3)
	for k in 8:
		var f := OrionCV2._radial(p, x, k * TAU / 8.0 + PI / 8.0, R * 1.0)
		OrionCV2._rbox(f, Vector3(0.05, 0.02, 0.05), gold, Vector3.ZERO, 3.5, 5)

static func _barrel(p: Node3D, xf: float, L: float, R: float, hull: Material) -> void:
	AsiaShips._barrel(p, xf, L, R, hull, LAMP)
	JPShips._windows(p, xf, L, R, maxi(1, int(L / 0.45)))
	_brackets(p, xf - 0.06, R)
	_brackets(p, xf - L + 0.06, R)

static func _panels(p: Node3D, x: float, R: float, span: float, w: float, vertical: bool) -> void:
	SAShips._array(p, x - w * 0.55, R, span * 1.0, w, vertical)
	SAShips._array(p, x + w * 0.55, R, span * 1.0, w, vertical)

static func _pods(p: Node3D, x: float, R: float, r: float, hull: Material) -> void:
	for a in [0.0, PI, PI * 0.5, -PI * 0.5]:
		var f := OrionCV2._radial(p, x, a, R + r * 0.8)
		UnitModels.ball(f, r * 1.4, hull, Vector3.ZERO)
		UnitModels.ring(f, r * 1.2, r * 1.45, _m(GOLD, 0.9, 0.3), Vector3.ZERO, Vector3(0, 0, PI / 2))

static func _plane(core: Node3D, name: String, spec: Dictionary, hull: Material) -> float:
	var R: float = spec["R"]
	var L: float = spec["L"]
	var span: float = spec["span"]
	var body := Node3D.new()
	body.scale = Vector3(1, 0.72, 1)
	core.add_child(body)
	var pts: Array = []
	var n := 24
	for i in n + 1:
		var u := float(i) / n
		var r := R * pow(sin(minf(u / 0.7, 1.0) * PI * 0.5), 0.9)
		if u > 0.9:
			r *= 1.0 - 0.25 * (u - 0.9) / 0.1
		pts.append(Vector2(-L * u, r + 0.001))
	OrionCV2._lathe(body, pts, 40, hull, Vector3.ZERO)
	var dark := _m(Color("#1c1d21"), 0.6, 0.4)
	OrionCV2._lathe(body, [Vector2(0.0, 0.001), Vector2(-0.3, R * 0.2)], 20, dark, Vector3.ZERO)
	var glass := _m(Color("#14181f"), 0.7, 0.2, 0.3)
	for k in 3:
		var f := OrionCV2._radial(body, -L * (0.3 + 0.05 * k), PI * 0.5, R * pow(sin((0.3 + 0.05 * k) / 0.7 * PI * 0.5), 0.9) * 0.99)
		UnitModels.ball(f, 0.04, glass, Vector3.ZERO, Vector3(1.2, 0.4, 0.8))
	_flag(body, -L * 0.45, R * 0.93)
	AsiaShips._gold_ring(body, -L * 0.7, R * 0.99, 0.012)
	# big delta wings, trailing edge flush with the tail
	var gold := _m(GOLD, 0.85, 0.35)
	var zr := R * 0.75
	for sg in [-1.0, 1.0]:
		var wp := PackedVector2Array([Vector2(-L * 0.38, sg * zr), Vector2(-L * 0.98, sg * zr), Vector2(-L * 0.98, sg * (zr + span)), Vector2(-L * 0.9, sg * (zr + span))])
		if sg < 0:
			wp.reverse()
		AsiaShips._plate(core, wp, 0.04, hull)
		OrionCV2._strut(core, Vector3(-L * 0.38, 0, sg * zr), Vector3(-L * 0.9, 0, sg * (zr + span)), 0.012, gold)
	# tail fin
	AsiaShips._wings(core, "fin", -L * 0.78, 0.8, 0.9, R * 0.7, _m(Color("#2a2c31"), 0.6, 0.45))
	OrionCV2._rbox(core, Vector3(0.22, 0.2, 0.72), _m(Color("#2a2c31"), 0.7, 0.45), Vector3(-L - 0.06, 0, 0), 4.0, 10)
	for z in [-0.24, 0.0, 0.24]:
		RUShips._bell(core, -L - 0.14, 0.0, z, 0.12)
	return -L - 0.14

static func build(name: String) -> Node3D:
	var spec: Dictionary = SPECS[name]
	var root := Node3D.new()
	root.name = "CN_" + name.replace(" ", "_")
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var blue := _m(Color("#2d4aa0"), 0.5, 0.4)
	AsiaShips.trim_col = LAMP
	if spec.get("kind", "") == "plane":
		_plane(core, name, spec, hull)
		AsiaShips.trim_col = Color("#58b8ff")
		var pb := UnitModels._bounds(core)
		core.position = -pb.get_center()
		root.set_meta("radius", maxf(pb.size.length() * 0.5, 0.3))
		return root
	var nose: Array = spec["nose"]
	var x: float = -nose[1]
	AsiaShips._nose(core, x, ["ogive", nose[0], nose[1]], hull)
	var tip := _m(GOLD, 0.9, 0.3)
	UnitModels.ball(core, 0.03, tip, Vector3(0.0, 0, 0))
	UnitModels.ring(core, nose[0] * 0.96, nose[0] * 1.02, blue, Vector3(x + 0.06, 0, 0), Vector3(0, 0, PI / 2))
	_flag(core, x * 0.35, nose[0] * 0.8)
	var R: float = nose[0]
	var rear_r := R
	var last_x := x
	var last_L := 0.0
	for m in spec["mods"]:
		match m[0]:
			"barrel":
				_barrel(core, x, m[1], m[2], hull)
				if m[2] > 0.3 and m[1] > 0.4:
					_flag(core, x - m[1] * 0.4, m[2], PI * 0.5)
				last_x = x
				last_L = m[1]
				x -= m[1]
				R = m[2]
				rear_r = R
			"truss":
				NAShips._truss(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"pods":
				_pods(core, x + 0.17, 0.29, m[1], hull)
			"ring":
				var Ro: float = m[1]
				JPShips._ring(core, last_x - last_L * 0.5, R, Ro, true, hull)
				var xr: float = last_x - last_L * 0.5
				for a in [0.0, PI, PI * 0.5, -PI * 0.5]:
					var f := OrionCV2._radial(core, xr, a, Ro + 0.04)
					OrionCV2._rbox(f, Vector3(0.2, 0.22, 0.2), hull, Vector3.ZERO, 4.0, 8)
					UnitModels.ring(f, 0.1, 0.115, _m(GOLD, 0.9, 0.3), Vector3(0, 0.11, 0), Vector3.ZERO)
			"panels":
				_panels(core, last_x - last_L * 0.45, R, m[1], m[2], false)
			"panelsv":
				_panels(core, last_x - last_L * 0.45, R, m[1], m[2], true)
	AsiaShips._engines(core, x, rear_r, int(spec["eng"]), hull)
	AsiaShips.trim_col = Color("#58b8ff")
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
