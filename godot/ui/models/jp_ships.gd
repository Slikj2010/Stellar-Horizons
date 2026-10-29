## Japan's crew ships (CV-2 .. CV-9): white riveted hulls with amber/gold modules, dark hab blocks, lattice booms, big ladder
## rings around the hull (Hiyo / Junyo / Myoko / Takao), an octagonal frame (Hiryu), a pod-studded ogive (Yamato) and a
## delta spaceplane (Hakaze).  Three black engine bells on every ship.  Nose points to +X.
## Not wired into the game yet; see tests/jp_preview.gd for renders.
class_name JPShips
extends RefCounted

const NAMES := ["Seishin", "Hakaze", "Kuren", "Hikawa", "Kansai", "Hiyo", "Junyo", "Myoko", "Takao", "Hiryu", "Yamato"]
const GOLD := Color("#d6a82a")
const LAMP := Color("#ffb347")

static func has(name: String) -> bool:
	return name in NAMES

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("jp_hull%d" % sd, 1024, 512, {"seed": 811 + sd * 29, "cols": 24, "min_len": 50, "max_len": 180, "black_rate": 0.03, "grime": 0.7, "tones": [Color("#e8e6df"), Color("#dcd9d0"), Color("#d0ccc0"), Color("#efede6"), Color("#c6c1b4")], "seam": Color("#7a705a")}, 0.3, 0.55)

static func _amber_mat() -> StandardMaterial3D:
	return OrionCV2._smat("jp_amber", 1024, 512, {"seed": 877, "cols": 20, "min_len": 50, "max_len": 160, "black_rate": 0.02, "grime": 0.8, "tones": [Color("#d9a23c"), Color("#cf972f"), Color("#e2b04f"), Color("#c68b27"), Color("#d4a040")], "seam": Color("#6b4a18")}, 0.45, 0.45)

static func _grey_mat() -> StandardMaterial3D:
	return OrionCV2._smat("jp_grey", 1024, 512, {"seed": 899, "cols": 20, "min_len": 40, "max_len": 140, "black_rate": 0.03, "grime": 0.9, "tones": [Color("#a9abae"), Color("#9a9da1"), Color("#b6b8ba"), Color("#8f9296")], "seam": Color("#3c3e42")}, 0.5, 0.5)

# ------------------------------------------------------------------ parts
## domed nose with gold diamond bands and an antenna spike; returns the x of the shoulder
static func _dome(p: Node3D, R: float, L: float, hull: Material) -> float:
	AsiaShips._nose(p, -L, ["ogive", R, L], hull)
	var gold := _m(GOLD, 0.9, 0.3)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	for k in [0.3, 0.6]:
		var u: float = k
		var r := R * pow(sin((1.0 - u) * PI * 0.5), 0.75)
		AsiaShips._gold_ring(p, -L * u, r * 1.0, 0.012)
	OrionCV2._strut(p, Vector3(-0.01, 0, 0), Vector3(0.12, 0, 0), 0.008, steel)
	UnitModels.ball(p, 0.014, _m(LAMP, 0.0, 0.3, 2.2), Vector3(0.12, 0, 0))
	return -L

static func _windows(p: Node3D, x: float, L: float, R: float, n: int) -> void:
	var dark := _m(Color("#14181f"), 0.5, 0.3, 0.2)
	var white := _m(Color("#e8e6df"), 0.35, 0.5)
	for a in [0.0, PI, PI * 0.5, -PI * 0.5]:
		for i in n:
			var f := OrionCV2._radial(p, x - L * (i + 0.5) / n, a, R * 0.985)
			OrionCV2._rbox(f, Vector3(L / n * 0.8, 0.02, 0.07), white, Vector3.ZERO, 4.0, 6)
			OrionCV2._rbox(f, Vector3(L / n * 0.6, 0.026, 0.045), dark, Vector3.ZERO, 4.0, 6)

## grey rear habitat block (windows, vents) ending in a dark collar
static func _hab(p: Node3D, xf: float, L: float, R: float, grey: Material) -> void:
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	var white := _m(Color("#e2dfd6"), 0.35, 0.5)
	var steel := _m(Color("#8d9198"), 0.85, 0.3)
	var xb := xf - L
	var pts: Array = [Vector2(xf, 0.001), Vector2(xf, R * 0.86), Vector2(xf - 0.03, R * 0.97), Vector2(xf - 0.07, R), Vector2(xb + 0.1, R), Vector2(xb + 0.03, R * 0.9), Vector2(xb, R * 0.8), Vector2(xb, 0.001)]
	OrionCV2._lathe(p, pts, 32, grey, Vector3.ZERO)
	AsiaShips._gold_ring(p, xf - 0.08, R * 1.0, 0.01)
	for a in [0.0, PI, PI * 0.5, -PI * 0.5]:
		var f := OrionCV2._radial(p, xf - L * 0.5, a, R * 0.99)
		OrionCV2._rbox(f, Vector3(L * 0.62, 0.02, R * 0.75), white, Vector3.ZERO, 4.0, 8)
		OrionCV2._rbox(f, Vector3(L * 0.46, 0.028, R * 0.34), dark, Vector3.ZERO, 4.0, 6)
		OrionCV2._vent(f, 0.05, L * 0.4, 4, steel, dark)
	for k in 3:
		var rx := xb + 0.04 + k * 0.04
		UnitModels.ring(p, R * 0.8, R * 0.86, steel, Vector3(rx, 0, 0), Vector3(0, 0, PI / 2))

## amber painted barrel with long ribs
static func _amber_barrel(p: Node3D, xf: float, L: float, R: float, amber: Material) -> void:
	AsiaShips._barrel(p, xf, L, R, amber, LAMP)
	var rib := _m(Color("#8a5f1c"), 0.6, 0.45)
	for i in 14:
		var f := OrionCV2._radial(p, xf - L * 0.5, i * TAU / 14.0 + 0.1, R * 0.995)
		OrionCV2._rbox(f, Vector3(L * 0.86, 0.016, 0.025), rib, Vector3.ZERO, 4.0, 6)

## flat ladder ring standing around the hull: a squashed torus, rungs, spokes and outrigger rods
static func _ring(p: Node3D, x: float, R: float, Ro: float, solid: bool, hull: Material) -> void:
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	var dark := _m(Color("#1d1e22"), 0.5, 0.5)
	var gold := _m(GOLD, 0.9, 0.3)
	var band := Ro * 0.12
	var rc := Ro - band * 0.5
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = rc - band * 0.5
	tm.outer_radius = rc + band * 0.5
	tm.rings = 48
	tm.ring_segments = 12
	mi.mesh = tm
	mi.material_override = hull if solid else steel
	mi.rotation = Vector3(0, 0, PI / 2)
	mi.scale = Vector3(1, 1, 1)
	mi.position = Vector3(x, 0, 0)
	p.add_child(mi)
	# ladder rungs across the band (both faces) and gold edge bands
	var n := 40
	for i in n:
		var f := OrionCV2._radial(p, x, i * TAU / n, rc)
		OrionCV2._rbox(f, Vector3(band * 0.5 * 1.7, band * 0.78, 0.028), dark if solid else dsteel, Vector3.ZERO, 3.5, 5)
	UnitModels.ring(p, Ro - 0.004, Ro + 0.014, gold, Vector3(x, 0, 0), Vector3(0, 0, PI / 2))
	UnitModels.ring(p, rc - band * 0.5 - 0.014, rc - band * 0.5 + 0.004, gold, Vector3(x, 0, 0), Vector3(0, 0, PI / 2))
	# spokes from the hull
	for k in 6:
		var a := k * TAU / 6.0 + PI / 6.0
		OrionCV2._strut(p, Vector3(x, R * 0.92 * sin(a), R * 0.92 * cos(a)), Vector3(x, (rc - band * 0.5) * sin(a), (rc - band * 0.5) * cos(a)), 0.014, steel)
	# outrigger rods along the axis with small nodes
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		var y := rc * sin(a)
		var z := rc * cos(a)
		OrionCV2._strut(p, Vector3(x - 0.2, y, z), Vector3(x + 0.2, y, z), 0.009, steel)
		UnitModels.ball(p, 0.022, gold, Vector3(x + 0.2, y, z))
		UnitModels.ball(p, 0.022, gold, Vector3(x - 0.2, y, z))

## octagonal frame (Hiryu): beams, loops, bracing and a few solid face panels
static func _frame(p: Node3D, xf: float, L: float, R: float, hull: Material) -> void:
	var white := _m(Color("#dedbd2"), 0.45, 0.5)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var gold := _m(GOLD, 0.9, 0.3)
	var corners: Array = []
	for k in 8:
		var a := PI / 8.0 + k * PI / 4.0
		corners.append(Vector2(sin(a), cos(a)) * R)
	var xs: Array = [xf - 0.12, xf - L * 0.33, xf - L * 0.67, xf - L + 0.12]
	for c in corners:
		OrionCV2._strut(p, Vector3(xs[0], c.x, c.y), Vector3(xs[3], c.x, c.y), 0.03, white)
	for i in xs.size():
		for k in 8:
			var c0: Vector2 = corners[k]
			var c1: Vector2 = corners[(k + 1) % 8]
			OrionCV2._strut(p, Vector3(xs[i], c0.x, c0.y), Vector3(xs[i], c1.x, c1.y), 0.024, white)
		for k in 8:
			var c0: Vector2 = corners[k]
			UnitModels.ball(p, 0.04, gold if i % 3 == 0 else steel, Vector3(xs[i], c0.x, c0.y))
	for i in 3:
		for k in 8:
			var c0: Vector2 = corners[k]
			var c1: Vector2 = corners[(k + 1) % 8]
			if k % 2 == 0:
				OrionCV2._strut(p, Vector3(xs[i], c0.x, c0.y), Vector3(xs[i + 1], c1.x, c1.y), 0.011, steel)
			else:
				OrionCV2._strut(p, Vector3(xs[i], c1.x, c1.y), Vector3(xs[i + 1], c0.x, c0.y), 0.011, steel)
	# solid armour panels on the four diagonal faces (upper and lower), open on the axes
	for k in 8:
		if k % 2 == 1:
			continue
		var c0: Vector2 = corners[k]
		var c1: Vector2 = corners[(k + 1) % 8]
		var mid := (c0 + c1) * 0.5
		var len := (c1 - c0).length()
		var a := atan2(mid.x, mid.y)
		var f := OrionCV2._radial(p, xf - L * 0.5, a, mid.length() * 0.985)
		OrionCV2._rbox(f, Vector3(L * 0.84, 0.026, len * 0.82), hull, Vector3.ZERO, 5.0, 8)
	# conical braces from the hull to the end loops
	for e in [0, 3]:
		for k in range(0, 8, 2):
			var c0: Vector2 = corners[k]
			var xr: float = xs[e]
			var xh := xr - 0.3 if e == 0 else xr + 0.3
			OrionCV2._strut(p, Vector3(xr, c0.x, c0.y), Vector3(xh, c0.x * 0.45, c0.y * 0.45), 0.012, steel)

static func _pod(p: Node3D, pos: Vector3, L: float, r: float, hull: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	p.add_child(n)
	AsiaShips._barrel(n, L * 0.5, L, r, hull, LAMP)

# ------------------------------------------------------------------ the model
static func build(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "JP_" + name
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	var amber := _amber_mat()
	var grey := _grey_mat()
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var gold := _m(GOLD, 0.9, 0.3)
	AsiaShips.trim_col = LAMP
	var x := 0.0
	var rear_r := 0.3
	match name:
		"Seishin", "Kuren":
			x = _dome(core, 0.3, 0.55, hull)
			AsiaShips._barrel(core, x, 0.5, 0.3, hull, LAMP)
			_windows(core, x, 0.5, 0.3, 2)
			x -= 0.5
			AsiaShips._conn(core, x, 0.12, 0.08)
			x -= 0.08
			_amber_barrel(core, x, 0.8, 0.37, amber)
			var tx := x - 0.55
			if name == "Seishin":
				OrionCV2._strut(core, Vector3(tx, 0.34, 0), Vector3(tx, 0.52, 0), 0.02, steel)
				OrionCV2._rbox(core, Vector3(0.14, 0.14, 0.14), hull, Vector3(tx, 0.6, 0), 4.0, 8)
				OrionCV2._strut(core, Vector3(tx, 0.67, 0), Vector3(tx, 0.82, 0), 0.007, steel)
			else:
				OrionCV2._strut(core, Vector3(tx, 0.36, 0), Vector3(tx, 0.62, 0), 0.007, steel)
			x -= 0.8
			_hab(core, x, 0.36, 0.34, grey)
			x -= 0.36
			rear_r = 0.34
		"Hikawa", "Kansai":
			x = _dome(core, 0.3, 0.55, hull)
			AsiaShips._barrel(core, x, 0.5, 0.3, hull, LAMP)
			_windows(core, x, 0.5, 0.3, 2)
			x -= 0.5
			NAShips._truss(core, x, 1.2 if name == "Hikawa" else 1.4, 0.2)
			x -= 1.2 if name == "Hikawa" else 1.4
			# cross boom with gold arrays, and a lattice rear block
			var bx := x + 0.1
			OrionCV2._strut(core, Vector3(bx, 0, -0.9), Vector3(bx, 0, 0.9), 0.025, steel)
			OrionCV2._strut(core, Vector3(bx + 0.18, 0, -0.9), Vector3(bx + 0.18, 0, 0.9), 0.012, steel)
			SAShips._array(core, bx + 0.09, 0.38, 0.62 if name == "Hikawa" else 0.8, 0.4 if name == "Hikawa" else 0.32, false)
			for s in [-1.0, 1.0]:
				OrionCV2._strut(core, Vector3(bx - 0.1, 0.1 * s, 0.9 * s), Vector3(bx - 0.1, -0.1 * s, 0.9 * s), 0.01, steel)
			SAShips._cage(core, x, 0.55, 0.36)
			x -= 0.55
			_hab(core, x, 0.3, 0.34, grey)
			x -= 0.3
			OrionCV2._strut(core, Vector3(x + 0.4, 0.34, 0), Vector3(x + 0.4, 0.62, 0), 0.007, steel)
			rear_r = 0.34
		"Hiyo", "Junyo", "Myoko", "Takao":
			x = _dome(core, 0.3, 0.55, hull)
			var Lm := 0.55
			AsiaShips._barrel(core, x, Lm, 0.3, hull, LAMP)
			_windows(core, x, Lm, 0.3, 2)
			var xr1 := x - Lm * 0.45
			x -= Lm
			var Ll: float = {"Hiyo": 1.0, "Junyo": 0.85, "Myoko": 1.3, "Takao": 1.3}[name]
			AsiaShips._barrel(core, x, Ll, 0.29, hull, LAMP)
			_windows(core, x, Ll, 0.29, 4)
			var xr2 := x - Ll * 0.55
			x -= Ll
			_ring(core, xr1, 0.3, 0.66 if name != "Junyo" else 0.58, true, hull)
			if name in ["Myoko", "Takao"]:
				_ring(core, xr2, 0.29, 0.66, name == "Myoko", hull)
			_hab(core, x, 0.55, 0.37, grey)
			x -= 0.55
			rear_r = 0.37
		"Hiryu":
			x = _dome(core, 0.3, 0.55, hull)
			AsiaShips._barrel(core, x, 0.45, 0.3, hull, LAMP)
			_windows(core, x, 0.45, 0.3, 2)
			x -= 0.45
			var Lf := 1.0
			# the inner hab with gold oval pods, wrapped by the frame
			AsiaShips._barrel(core, x - 0.05, Lf - 0.1, 0.36, hull, LAMP)
			for a in [PI * 0.5, -PI * 0.5, 0.0, PI]:
				var f := OrionCV2._radial(core, x - Lf * 0.5, a, 0.36)
				UnitModels.ball(f, 0.13, gold, Vector3(0, 0.02, 0), Vector3(1.6, 0.35, 0.9))
				UnitModels.ring(f, 0.12, 0.15, steel, Vector3(0, 0.02, 0))
			_frame(core, x, Lf, 0.66, hull)
			x -= Lf
			AsiaShips._conn(core, x, 0.14, 0.1)
			x -= 0.1
			_hab(core, x, 0.55, 0.37, grey)
			x -= 0.55
			rear_r = 0.37
		"Yamato":
			var R := 0.5
			var Ln := 1.5
			var pts: Array = []
			var n := 18
			for i in n + 1:
				var u := float(i) / n
				pts.append(Vector2(-Ln * u, R * pow(sin(u * PI * 0.5), 0.8) + 0.001))
			pts.append(Vector2(-Ln - 0.9, R * 1.02))
			OrionCV2._lathe(core, pts, 40, hull, Vector3.ZERO)
			# gold band section and dark vent slats
			AsiaShips._gold_ring(core, -Ln, R * 1.0, 0.02)
			AsiaShips._gold_ring(core, -Ln - 0.28, R * 1.0, 0.02)
			for a in [0.0, PI, PI * 0.5, -PI * 0.5]:
				var f := OrionCV2._radial(core, -Ln - 0.14, a, R * 1.0)
				var gm := _m(Color("#7a5c1e"), 0.6, 0.45)
				OrionCV2._rbox(f, Vector3(0.22, 0.016, 0.3), gm, Vector3.ZERO, 4.0, 6)
				UnitModels.ball(f, 0.1, gold, Vector3(0, 0.02, 0), Vector3(1.5, 0.35, 1.0))
			# windows on the nose and the vented belt
			var glass := _m(Color("#1f4f86"), 0.8, 0.12, 0.6)
			for a in [PI * 0.5, -PI * 0.5]:
				for k in 3:
					var u := 0.45 + 0.13 * k
					var f := OrionCV2._radial(core, -Ln * u, a, R * pow(sin(u * PI * 0.5), 0.8) * 0.99)
					UnitModels.ball(f, 0.03, glass, Vector3(0, 0.01, 0), Vector3(1.0, 0.35, 1.0))
			var dark := _m(Color("#17181b"), 0.5, 0.45)
			for k in 5:
				UnitModels.ring(core, R * 0.995, R * 1.02, dark, Vector3(-Ln - 0.5 - k * 0.07, 0, 0), Vector3(0, 0, PI / 2))
			x = -Ln - 0.9
			_hab(core, x, 0.4, 0.5, grey)
			x -= 0.4
			# eight strap-on pods on struts: long forward, short aft, at +-Y and +-Z
			for a in [0.0, PI, PI * 0.5, -PI * 0.5]:
				var yz := Vector2(sin(a), cos(a))
				var off := 0.78
				var pf := Vector3(0, yz.x * off, yz.y * off)
				_pod(core, pf + Vector3(-Ln * 0.45 - 0.9 * 0.5 - 0.0, 0, 0), 0.9, 0.1, hull)
				_pod(core, pf + Vector3(-Ln - 0.35, 0, 0), 0.5, 0.1, hull)
				OrionCV2._strut(core, Vector3(-Ln * 0.45 - 0.45, yz.x * R * 0.9, yz.y * R * 0.9), pf + Vector3(-Ln * 0.45 - 0.45, 0, 0), 0.015, steel)
				OrionCV2._strut(core, Vector3(-Ln - 0.35, yz.x * R * 0.9, yz.y * R * 0.9), pf + Vector3(-Ln - 0.35, 0, 0), 0.015, steel)
			rear_r = 0.5
		"Hakaze":
			# slender spindle body (token): long straight taper to a thin nose spike, constant mid-section, short tail taper;
			# near-rectangular wings set behind the middle with only a mild sweep; three small bells
			var R := 0.4
			var L := 2.9
			var body := Node3D.new()
			body.scale = Vector3(1, 0.55, 1)
			core.add_child(body)
			var pts: Array = []
			var n := 26
			for i in n + 1:
				var u := float(i) / n
				var r := R * minf(u / 0.62, 1.0)
				if u > 0.84:
					r *= 1.0 - 0.32 * (u - 0.84) / 0.16
				pts.append(Vector2(-L * u, r + 0.001))
			OrionCV2._lathe(body, pts, 40, hull, Vector3.ZERO)
			OrionCV2._strut(core, Vector3(-0.02, 0, 0), Vector3(0.28, 0, 0), 0.009, steel)
			UnitModels.ball(core, 0.016, _m(LAMP, 0.0, 0.3, 2.2), Vector3(0.28, 0, 0))
			AsiaShips._gold_ring(body, -L * 0.62, R * 0.99, 0.012)
			AsiaShips._gold_ring(body, -L * 0.9, R * 0.78, 0.012)
			var glass := _m(Color("#14181f"), 0.7, 0.2, 0.35)
			var frame := _m(Color("#cfcbbf"), 0.4, 0.5)
			var red := _m(Color("#c8202a"), 0.2, 0.5, 0.4)
			var fd := OrionCV2._radial(body, -L * 0.3, PI * 0.5, R * 0.48 * 0.99)
			UnitModels.ball(fd, 0.1, red, Vector3.ZERO, Vector3(1.0, 0.12, 1.0))
			for k in 3:
				var fw := OrionCV2._radial(body, -L * (0.52 + 0.07 * k), PI * 0.5, R * 0.98)
				OrionCV2._rbox(fw, Vector3(0.16, 0.035, 0.14), frame, Vector3.ZERO, 4.0, 6)
				OrionCV2._rbox(fw, Vector3(0.11, 0.045, 0.09), glass, Vector3.ZERO, 4.0, 6)
			var fc := OrionCV2._radial(body, -L * 0.42, PI * 0.5, R * 0.68 * 0.99)
			OrionCV2._rbox(fc, Vector3(0.55, 0.05, 0.2), frame, Vector3.ZERO, 4.0, 8)
			OrionCV2._rbox(fc, Vector3(0.4, 0.065, 0.13), glass, Vector3.ZERO, 4.0, 8)
			# wings: near-rectangular, mild sweep, gold outer edge
			var gold2 := _m(GOLD, 0.85, 0.35)
			var zr := R * 0.7
			var wspan := 0.85
			for sg in [-1.0, 1.0]:
				var wp := PackedVector2Array([Vector2(-1.5, sg * zr), Vector2(-2.2, sg * zr), Vector2(-2.24, sg * (zr + wspan)), Vector2(-1.7, sg * (zr + wspan))])
				if sg < 0:
					wp.reverse()
				AsiaShips._plate(core, wp, 0.045, hull)
				OrionCV2._strut(core, Vector3(-2.24, 0, sg * (zr + wspan)), Vector3(-1.7, 0, sg * (zr + wspan)), 0.02, gold2)
				OrionCV2._strut(core, Vector3(-2.2, 0, sg * zr), Vector3(-2.24, 0, sg * (zr + wspan)), 0.014, gold2)
			var tr := R * 0.68
			OrionCV2._rbox(core, Vector3(0.22, 0.2, 0.72), _m(Color("#2a2c31"), 0.7, 0.45), Vector3(-L - 0.06, 0, 0), 4.0, 10)
			for z in [-0.24, 0.0, 0.24]:
				RUShips._bell(core, -L - 0.14, 0.0, z, 0.12)
			x = -L - 0.14
			rear_r = 0.0
	if rear_r > 0.0:
		AsiaShips._engines(core, x, rear_r, 3, hull)
	AsiaShips.trim_col = Color("#58b8ff")
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
