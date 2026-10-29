## Europe's crew ships (CV-2 .. CV-8): blue-grey white riveted hulls with gold bands, hab barrels with window rows, long lattice
## spines, black ribbed drums, gold solar arrays, strap-on four-tank sets each ending in its own bell, and two swept spaceplanes.
## Nose points to +X.  Not wired into the game yet; see tests/eu_preview.gd for renders.
class_name EUShips
extends RefCounted

## nose: [R, L]   mods: ["hab", L, R] ["truss", L, R] ["drums", L, R] ["cage", L, R] ["panels", span, w] ["panelsv", span, w]
##                      ["tanks", L, r, spread] ["frame", R] ["pods", L, r, off]
## eng: bells on the spine end when there are no tanks (0 = none)
const SPECS := {
	"Odyssey": {"nose": [0.3, 0.5], "mods": [["hab", 0.55, 0.3], ["hab", 0.9, 0.33], ["panels", 0.5, 0.3], ["panelsv", 0.5, 0.3]], "eng": 1},
	"Friede": {"nose": [0.26, 0.45], "mods": [["hab", 0.45, 0.26], ["truss", 0.2, 0.1], ["hab", 1.0, 0.33], ["panelsv", 0.45, 0.3]], "eng": 1},
	"Apollo": {"nose": [0.26, 0.6], "mods": [["hab", 0.3, 0.26], ["truss", 1.2, 0.17], ["drums", 0.45, 0.36], ["drums", 0.45, 0.36], ["cage", 0.5, 0.38], ["panelsv", 0.55, 0.3], ["panels", 0.55, 0.3]], "eng": 3},
	"Athena": {"nose": [0.26, 0.7], "mods": [["hab", 0.3, 0.26], ["truss", 1.5, 0.17], ["drums", 0.45, 0.36], ["drums", 0.45, 0.36], ["cage", 0.5, 0.38], ["panelsv", 0.55, 0.3]], "eng": 3},
	"Aquila": {"nose": [0.3, 1.0], "mods": [["hab", 0.7, 0.34], ["frame", 0.38], ["tanks", 1.3, 0.2, 0.26]], "eng": 0},
	"Galicia": {"nose": [0.3, 0.8], "mods": [["hab", 0.8, 0.34], ["frame", 0.38], ["tanks", 1.3, 0.2, 0.26]], "eng": 0},
	"Courageux": {"nose": [0.3, 1.4], "mods": [["hab", 0.6, 0.34], ["frame", 0.38], ["tanks", 1.5, 0.2, 0.26]], "eng": 0},
	"Komet": {"nose": [0.3, 0.9], "mods": [["hab", 0.5, 0.33], ["frame", 0.38], ["tanks", 0.8, 0.2, 0.26], ["frame", 0.4], ["tanks", 0.8, 0.2, 0.26]], "eng": 0},
	"Konstellation": {"nose": [0.3, 0.8], "mods": [["hab", 0.4, 0.33], ["frame", 0.38], ["tanks", 0.6, 0.2, 0.26], ["frame", 0.4], ["tanks", 0.6, 0.2, 0.26], ["frame", 0.4], ["tanks", 0.9, 0.2, 0.26]], "eng": 0},
	"Europa": {"nose": [0.46, 1.1], "mods": [["hab", 0.9, 0.46], ["frame", 0.5], ["tanks", 1.4, 0.24, 0.34], ["pods", 0.9, 0.08, 0.62]], "eng": 0},
	"Mistral": {"kind": "plane", "nose": [0.3, 1.5], "mods": [["hab", 1.2, 0.3]], "span": 1.25, "chord": 1.7, "eng": 1},
	"Pegasus": {"kind": "plane", "nose": [0.3, 1.4], "mods": [["hab", 1.3, 0.3]], "span": 1.4, "chord": 1.5, "eng": 1},
}

const GOLD := Color("#d6a82a")
const LAMP := Color("#58b8ff")

static func has(name: String) -> bool:
	return SPECS.has(name)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("eu_hull%d" % sd, 1024, 512, {"seed": 951 + sd * 37, "cols": 24, "min_len": 50, "max_len": 200, "black_rate": 0.04, "grime": 0.75, "tones": [Color("#e4e7ea"), Color("#d6dade"), Color("#c8cdd3"), Color("#eceff1"), Color("#bcc2ca")], "seam": Color("#5d646e")}, 0.35, 0.5)

static func _gold_trim(p: Node3D, x: float, r: float) -> void:
	AsiaShips._gold_ring(p, x, r, 0.012)

## hab barrel with gold bands and a row of dark windows
static func _hab(p: Node3D, xf: float, L: float, R: float, hull: Material) -> void:
	AsiaShips._barrel(p, xf, L, R, hull, LAMP)
	JPShips._windows(p, xf, L, R, maxi(1, int(L / 0.28)))

## the little white frame / ring section between hab and tanks (gold braced hexagonal frame)
static func _frame(p: Node3D, xf: float, R: float, hull: Material) -> float:
	var L := 0.32
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var gold := _m(GOLD, 0.9, 0.3)
	var white := _m(Color("#dfe2e6"), 0.45, 0.5)
	var corners: Array = []
	for k in 8:
		var a := PI / 8.0 + k * PI / 4.0
		corners.append(Vector2(sin(a), cos(a)) * R)
	for c in corners:
		OrionCV2._strut(p, Vector3(xf, c.x, c.y), Vector3(xf - L, c.x, c.y), 0.022, white)
	for e in [0.0, 1.0]:
		var x: float = xf - L * e
		for k in 8:
			var c0: Vector2 = corners[k]
			var c1: Vector2 = corners[(k + 1) % 8]
			OrionCV2._strut(p, Vector3(x, c0.x, c0.y), Vector3(x, c1.x, c1.y), 0.018, gold if k % 2 == 0 else white)
	UnitModels.cylx(p, R * 0.5, R * 0.5, L, hull, Vector3(xf - L * 0.5, 0, 0), 20)
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		var f := OrionCV2._radial(p, xf - L * 0.5, a, R * 0.5)
		OrionCV2._rbox(f, Vector3(L * 0.8, 0.03, 0.08), _m(Color("#17181b"), 0.5, 0.45), Vector3.ZERO, 4.0, 6)
	return L

static func _drums(p: Node3D, xf: float, L: float, R: float, hull: Material) -> void:
	NAShips._ribbed(p, xf, L, R, hull)

static func _tankset(p: Node3D, xf: float, L: float, r: float, sp: float, hull: Material) -> void:
	AsiaShips._tanks(p, xf, L, r, sp, 4, hull)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			AsiaShips._bell(p, Vector3(xf - L - 0.01, sy * sp, sz * sp), r * 0.72)

static func build(name: String) -> Node3D:
	var spec: Dictionary = SPECS[name]
	var plane: bool = spec.get("kind", "") == "plane"
	var root := Node3D.new()
	root.name = "EU_" + name
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	AsiaShips.trim_col = LAMP
	var nose: Array = spec["nose"]
	var x: float = -nose[1]
	var body := core
	if plane:
		body = Node3D.new()
		body.scale = Vector3(1, 0.72, 1)
		core.add_child(body)
		AsiaShips._nose(body, x, ["needle", nose[0], nose[1]], hull)
	else:
		AsiaShips._nose(body, x, ["ogive", nose[0], nose[1]], hull)
		for k in [0.3, 0.62]:
			var u: float = k
			AsiaShips._gold_ring(core, -nose[1] * u, nose[0] * pow(sin((1.0 - u) * PI * 0.5), 0.75), 0.012)
	var R: float = nose[0]
	var rear_r := R
	var has_tanks := false
	for m in spec["mods"]:
		match m[0]:
			"hab":
				if plane:
					AsiaShips._barrel(body, x, m[1], m[2], hull, LAMP)
				else:
					_hab(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"truss":
				NAShips._truss(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"drums":
				_drums(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"cage":
				SAShips._cage(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"frame":
				x -= _frame(core, x, m[1], hull)
			"tanks":
				_tankset(core, x, m[1], m[2], m[3], hull)
				x -= m[1]
				has_tanks = true
			"pods":
				for sgn in [-1.0, 1.0]:
					var zz: float = sgn * m[3]
					var pn := Node3D.new()
					pn.position = Vector3(x + m[1] * 0.25, 0.0, zz)
					core.add_child(pn)
					AsiaShips._barrel(pn, m[1] * 0.5, m[1], m[2], hull, LAMP)
					OrionCV2._strut(core, Vector3(x, 0, zz * 0.35), Vector3(x, 0, zz), 0.015, steel)
			"panels":
				SAShips._array(core, x + 0.2, R, m[1], m[2], false)
			"panelsv":
				SAShips._array(core, x + 0.2, R, m[1], m[2], true)
	if plane:
		var span: float = spec["span"]
		var chord: float = spec["chord"]
		AsiaShips._wings(core, "delta", x + chord * 0.6, span, chord, R, hull)
		AsiaShips._wings(core, "fin", x + 0.55, 0.7, 0.7, R, _m(GOLD, 0.8, 0.35))
	if not has_tanks and spec["eng"] > 0:
		AsiaShips._engines(core, x, rear_r, int(spec["eng"]), hull)
	AsiaShips.trim_col = Color("#58b8ff")
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
