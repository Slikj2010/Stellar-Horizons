## South America / Africa crew ships (CV-2 .. CV-7): weathered dark-grey plating with gold trim, black nose cones, long
## barrels, segmented gold solar arrays, strap-on tank pods, lattice "cage" drums and clustered ribbed bells.
## Shares its kit with AsiaShips / NAShips / OrionCV2.  Nose points to +X.
## Not wired into the game yet; see tests/sa_preview.gd for renders.
class_name SAShips
extends RefCounted

## nose: ["ogive"|"needle", R, L, style] with style "black" | "red" | "grey"; ["sphere", R]
## mods: ["barrel", L, R] ["dark", L, R] ["truss", L, R] ["hub", L, S] ["tanks", L, r, spread, n] ["cage", L, R]
##       ["panels", span, w] (horizontal, +-Z)  ["panelsv", span, w] (vertical, +-Y)  ["mast"]
const SPECS := {
	"Empressa": {"nose": ["ogive", 0.3, 0.6, "black"], "mods": [["barrel", 0.6, 0.32], ["barrel", 0.5, 0.34], ["mast"]], "eng": 3},
	"Estrella": {"nose": ["ogive", 0.3, 0.55, "black"], "mods": [["barrel", 0.6, 0.32], ["panelsv", 0.75, 0.45], ["barrel", 0.45, 0.34]], "eng": 3},
	"Amazon": {"nose": ["ogive", 0.33, 0.6, "red"], "mods": [["barrel", 0.8, 0.36], ["panels", 0.55, 0.6], ["panelsv", 0.55, 0.6], ["barrel", 0.55, 0.36]], "eng": 3},
	"Barroso": {"nose": ["needle", 0.3, 0.9, "grey"], "mods": [["barrel", 1.0, 0.34], ["panelsv", 0.5, 0.7]], "eng": 3},
	"Helios": {"nose": ["sphere", 0.22], "mods": [["truss", 0.5, 0.1], ["barrel", 0.5, 0.3], ["panelsv", 0.6, 0.5], ["barrel", 0.45, 0.32]], "eng": 3},
	"Bantu": {"nose": ["ogive", 0.26, 0.6, "black"], "mods": [["barrel", 0.45, 0.22], ["truss", 0.45, 0.13], ["hub", 0.5, 0.3], ["panels", 0.7, 0.35], ["panelsv", 0.7, 0.35]], "eng": 4},
	"Maghreb": {"nose": ["ogive", 0.26, 0.5, "black"], "mods": [["barrel", 0.4, 0.24], ["barrel", 0.4, 0.26], ["hub", 0.5, 0.3], ["panels", 0.7, 0.35], ["panelsv", 0.7, 0.35]], "eng": 4},
	"Jupiter": {"nose": ["ogive", 0.34, 0.65, "grey"], "mods": [["barrel", 0.5, 0.34], ["tanks", 0.8, 0.24, 0.3, 2]], "eng": 4},
	"Neptuno": {"nose": ["ogive", 0.34, 0.7, "grey"], "mods": [["barrel", 0.55, 0.34], ["tanks", 0.9, 0.24, 0.3, 2]], "eng": 4},
	"Saturno": {"nose": ["ogive", 0.34, 0.65, "grey"], "mods": [["barrel", 0.5, 0.34], ["tanks", 0.85, 0.19, 0.28, 4]], "eng": 4},
	"Nebula": {"nose": ["ogive", 0.4, 0.8, "black"], "mods": [["dark", 0.65, 0.42], ["cage", 0.75, 0.42]], "eng": 4},
	"Nova": {"nose": ["ogive", 0.4, 0.75, "black"], "mods": [["dark", 0.55, 0.42], ["cage", 0.85, 0.42]], "eng": 4},
	"Cosmos": {"nose": ["needle", 0.34, 0.9, "grey"], "mods": [["barrel", 0.8, 0.36], ["tanks", 0.95, 0.22, 0.3, 4]], "eng": 4},
	"Galaxia": {"nose": ["needle", 0.34, 1.0, "grey"], "mods": [["barrel", 0.7, 0.36], ["tanks", 1.05, 0.22, 0.3, 4]], "eng": 4},
}

const GOLD := Color("#c9a24a")
const LAMP := Color("#ffb347")

static func has(name: String) -> bool:
	return SPECS.has(name)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("sa_hull%d" % sd, 1024, 512, {"seed": 511 + sd * 29, "cols": 24, "min_len": 50, "max_len": 200, "black_rate": 0.1, "grime": 1.0, "tones": [Color("#8d9097"), Color("#7b7f86"), Color("#6a6e75"), Color("#9aa0a6"), Color("#5a5e65")], "seam": Color("#26282c")}, 0.5, 0.5)

static func _nose_mat(style: String, hull: Material) -> Material:
	match style:
		"black": return _m(Color("#26282d"), 0.55, 0.45)
		"red": return _m(Color("#8c2f33"), 0.4, 0.5)
	return hull

# ------------------------------------------------------------------ parts
static func _hub(p: Node3D, xf: float, L: float, S: float, hull: Material) -> void:
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	var steel := _m(Color("#8d9198"), 0.85, 0.3)
	OrionCV2._rbox(p, Vector3(L, S * 2.0, S * 2.0), _m(Color("#555961"), 0.55, 0.5), Vector3(xf - L * 0.5, 0, 0), 6.0, 10)
	for a in [0.0, PI, PI * 0.5, -PI * 0.5]:
		var f := OrionCV2._radial(p, xf - L * 0.5, a, S * 0.99)
		OrionCV2._rbox(f, Vector3(L * 0.7, 0.014, S * 1.1), dark, Vector3.ZERO, 4.0, 6)
		OrionCV2._cluster(f, steel, _m(Color("#5b5f66"), 0.8, 0.38), dark, 0.7)
	AsiaShips._gold_ring(p, xf - 0.02, S * 1.05, 0.01)
	AsiaShips._gold_ring(p, xf - L + 0.02, S * 1.05, 0.01)

static func _cage(p: Node3D, xf: float, L: float, R: float) -> void:
	var dark := _m(Color("#1d1e22"), 0.5, 0.5)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var gold := _m(GOLD, 0.9, 0.3)
	# tanks inside the cage
	UnitModels.cylx(p, R * 0.86, R * 0.86, L, dark, Vector3(xf - L * 0.5, 0, 0), 28)
	for k in 6:
		var a := k * TAU / 6.0
		var f := OrionCV2._radial(p, xf - L * 0.5, a, R * 0.86)
		OrionCV2._rbox(f, Vector3(L * 0.8, 0.05, 0.12), _m(Color("#6e7279"), 0.6, 0.45), Vector3.ZERO, 4.0, 6)
	var n := 14
	for i in n:
		var a := i * TAU / n
		OrionCV2._strut(p, Vector3(xf, R * sin(a), R * cos(a)), Vector3(xf - L, R * sin(a), R * cos(a)), 0.012, steel)
	var bays := 5
	for b in bays + 1:
		var x := xf - L * float(b) / bays
		UnitModels.ring(p, R * 0.97, R * 1.03, steel if b % 2 == 0 else gold, Vector3(x, 0, 0), Vector3(0, 0, PI / 2))
		if b < bays:
			var xn := xf - L * float(b + 1) / bays
			for i in range(0, n, 2):
				var a0 := i * TAU / n
				var a1 := (i + 1) * TAU / n
				OrionCV2._strut(p, Vector3(x, R * sin(a0), R * cos(a0)), Vector3(xn, R * sin(a1), R * cos(a1)), 0.006, steel)

static func _array(p: Node3D, x: float, R: float, span: float, w: float, vertical: bool) -> void:
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	var mat := UnitModels.panel_mat(Color("#b08a3a"), Vector2(4, 3))
	var gold := _m(GOLD, 0.9, 0.3)
	var segs := 3
	var seg_len := span / segs
	for s in [-1.0, 1.0]:
		var base: float = s * (R + 0.04)
		OrionCV2._strut(p, Vector3(x, 0, 0), Vector3(x, base if vertical else 0.0, 0.0 if vertical else base), 0.02, dsteel)
		for q in segs:
			var off: float = s * (R + 0.08 + seg_len * (q + 0.5) + 0.02 * q)
			var n := Node3D.new()
			n.position = Vector3(x, off, 0) if vertical else Vector3(x, 0, off)
			if vertical: n.rotation = Vector3(PI / 2, 0, 0)
			p.add_child(n)
			var pts := PackedVector2Array([Vector2(w * 0.5, -seg_len * 0.48), Vector2(-w * 0.5, -seg_len * 0.48), Vector2(-w * 0.5, seg_len * 0.48), Vector2(w * 0.5, seg_len * 0.48)])
			AsiaShips._plate(n, pts, 0.03, mat)
			OrionCV2._rbox(n, Vector3(w * 1.04, 0.045, 0.02), gold, Vector3(0, 0, seg_len * 0.5), 3.0, 5)

# ------------------------------------------------------------------ the model
static func build(name: String) -> Node3D:
	var spec: Dictionary = SPECS[name]
	var root := Node3D.new()
	root.name = "SA_" + name
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	var dark := _m(Color("#26282d"), 0.55, 0.45)
	var nose: Array = spec["nose"]
	var R: float = nose[1]
	var x := 0.0
	if nose[0] == "sphere":
		var rr: float = nose[1]
		UnitModels.ball(core, rr, hull, Vector3(-rr, 0, 0))
		AsiaShips._gold_ring(core, -rr, rr * 0.99, 0.012)
		x = -rr * 2.0
	else:
		x = -nose[2]
		AsiaShips._nose(core, x, [nose[0], nose[1], nose[2]], _nose_mat(nose[3], hull))
	var rear_r := R
	for m in spec["mods"]:
		var t: String = m[0]
		match t:
			"barrel", "dark":
				AsiaShips._barrel(core, x, m[1], m[2], dark if t == "dark" else hull, LAMP)
				x -= m[1]
				R = m[2]
				rear_r = R
			"truss":
				NAShips._truss(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"hub":
				_hub(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"cage":
				_cage(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"tanks":
				rear_r = AsiaShips._tanks(core, x, m[1], m[2], m[3], int(m[4]), hull)
				x -= m[1]
			"panels":
				_array(core, x + 0.15, R, m[1], m[2], false)
			"panelsv":
				_array(core, x + 0.15, R, m[1], m[2], true)
			"mast":
				OrionCV2._strut(core, Vector3(x + 0.3, R, 0), Vector3(x + 0.3, R + 0.25, 0), 0.01, _m(Color("#aeb3ba"), 0.85, 0.3))
				UnitModels.ball(core, 0.02, _m(GOLD, 0.9, 0.3), Vector3(x + 0.3, R + 0.26, 0))
	AsiaShips._engines(core, x, rear_r, int(spec["eng"]), hull)
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
