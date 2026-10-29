## Japan's crew ships (CV-2 .. CV-9): weathered white plating with orange-gold bands, X-trusses, full hoops (Hiyo / Junyo / Myoko /
## Takao), an angular faceted hub (Hiryu), a cruciform delta plane (Hakaze) and the pod-flanked Yamato.  Nose points to +X.
## Cross-referenced with the in-game tokens (atlas_jp).  Not wired into the game yet; see tests/jp_preview.gd.
class_name JPShips
extends RefCounted

## nose: ["ogive", R, L] ; mods (applied nose to tail, x decreasing):
##   ["band", L, R]  banded drum        ["xtruss", L, R]  X-braced truss      ["rack", L, R]  barrel with equipment racks
##   ["gold", L, R, mast]  gold plated block with slits   ["hoop", Rh, n_tubes, braced]  full hoop around the hull
##   ["hub8", L, R]  faceted hub with oval hatch          ["boom", span, pw, pl]  cross beam with gold panels at its ends
##   ["drum", L, R]  engine block with door hatch
const SPECS := {
	"Seishin": {"nose": ["ogive", 0.3, 0.55], "mods": [["band", 0.5, 0.3], ["xtruss", 0.2, 0.2], ["rack", 0.8, 0.34], ["gold", 0.45, 0.4, 2]], "eng": 1},
	"Kuren": {"nose": ["ogive", 0.3, 0.55], "mods": [["band", 0.5, 0.3], ["xtruss", 0.2, 0.2], ["rack", 0.65, 0.34], ["gold", 0.45, 0.4, 1]], "eng": 1},
	"Hikawa": {"nose": ["ogive", 0.3, 0.5], "mods": [["band", 0.4, 0.3], ["xtruss", 1.0, 0.22], ["boom", 1.15, 0.7, 1.3], ["gold", 0.45, 0.4, 1]], "eng": 1},
	"Kansai": {"nose": ["ogive", 0.3, 0.5], "mods": [["band", 0.4, 0.3], ["xtruss", 0.9, 0.22], ["boom", 1.35, 0.75, 1.4], ["gold", 0.45, 0.4, 1]], "eng": 1},
	"Hiyo": {"nose": ["ogive", 0.28, 0.55], "mods": [["band", 0.7, 0.3], ["hoop", 0.85, 4, true], ["xtruss", 0.2, 0.2], ["rack", 0.95, 0.28], ["drum", 0.7, 0.4]], "eng": 3},
	"Junyo": {"nose": ["ogive", 0.28, 0.55], "mods": [["band", 0.7, 0.3], ["xtruss", 0.2, 0.2], ["hoop", 0.8, 4, false], ["rack", 0.9, 0.28], ["drum", 0.7, 0.4]], "eng": 3},
	"Myoko": {"nose": ["ogive", 0.28, 0.55], "mods": [["band", 0.7, 0.3], ["hoop", 0.85, 4, true], ["rack", 0.95, 0.26], ["hoop", 0.85, 4, true], ["drum", 0.7, 0.4]], "eng": 3},
	"Takao": {"nose": ["ogive", 0.28, 0.55], "mods": [["band", 0.7, 0.3], ["hoop", 0.85, 4, false], ["rack", 0.95, 0.26], ["hoop", 0.85, 4, true], ["drum", 0.7, 0.4]], "eng": 3},
	"Hiryu": {"nose": ["ogive", 0.28, 0.55], "mods": [["band", 0.8, 0.3], ["hub8", 0.95, 0.64], ["drum", 0.75, 0.4]], "eng": 3},
	"Hakaze": {"kind": "plane", "eng": 3},
	"Yamato": {"kind": "yamato", "eng": 3},
}

const ORANGE := Color("#d28a2a")

static func has(name: String) -> bool:
	return SPECS.has(name)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _hull_mat(name: String) -> StandardMaterial3D:
	var sd := int(absi(name.hash()) % 3)
	return OrionCV2._smat("jp_hull%d" % sd, 1024, 512, {"seed": 811 + sd * 37, "cols": 24, "min_len": 50, "max_len": 170, "black_rate": 0.05, "grime": 1.0, "tones": [Color("#e2dfd7"), Color("#d4d0c5"), Color("#c6c1b4"), Color("#ebe8e0"), Color("#b9b4a6")], "seam": Color("#5d5648")}, 0.35, 0.55)

static func _gold_mat() -> StandardMaterial3D:
	return OrionCV2._smat("jp_gold", 512, 256, {"seed": 881, "cols": 12, "min_len": 30, "max_len": 90, "black_rate": 0.03, "grime": 0.6, "tones": [Color("#cf8d2e"), Color("#c0811f"), Color("#d89a3c"), Color("#b87718")], "seam": Color("#4e3209")}, 0.7, 0.42)

static func _band(p: Node3D, x: float, r: float, w := 0.012) -> void:
	UnitModels.ring(p, r - 0.004, r + 2.0 * w, _m(ORANGE, 0.85, 0.35), Vector3(x, 0, 0), Vector3(0, 0, PI / 2))

# ------------------------------------------------------------------ parts
static func _banded(p: Node3D, x: float, L: float, R: float, hull: Material) -> void:
	AsiaShips._barrel(p, x, L, R, hull, Color("#ffb347"))
	# wide orange bands with a diamond pattern, as on the tokens
	var gold := _m(ORANGE, 0.85, 0.35)
	for k in 2:
		var bx := x - L * (0.28 + k * 0.38)
		_band(p, bx, R * 1.0, 0.03)
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var f := OrionCV2._radial(p, bx, a + PI * 0.25, R * 1.01)
			OrionCV2._rbox(f, Vector3(0.05, 0.016, 0.05), gold, Vector3.ZERO, 3.0, 4)
	# rear collar
	UnitModels.ring(p, R * 0.95, R * 1.03, _m(Color("#8d9198"), 0.85, 0.3), Vector3(x - L * 0.97, 0, 0), Vector3(0, 0, PI / 2))

static func _rack(p: Node3D, x: float, L: float, R: float, hull: Material) -> void:
	AsiaShips._barrel(p, x, L, R, hull, Color("#ffb347"))
	var dark := _m(Color("#1b1c20"), 0.5, 0.45)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	# equipment racks on top and bottom, dark window strips on the sides
	for s in [-1.0, 1.0]:
		var f := OrionCV2._radial(p, x - L * 0.5, PI * 0.5 if s > 0 else PI * 1.5, R * 1.0)
		OrionCV2._rbox(f, Vector3(L * 0.6, 0.05, 0.16), _m(Color("#cfcbc0"), 0.4, 0.5), Vector3(0, 0.02, 0), 4.0, 6)
		OrionCV2._rbox(f, Vector3(L * 0.5, 0.012, 0.05), dark, Vector3(0, 0.05, 0), 4.0, 4)
	for s in [0.0, PI]:
		var f2 := OrionCV2._radial(p, x - L * 0.5, s, R * 0.99)
		OrionCV2._vent(f2, 0.09, L * 0.5, 6, steel, dark)

static func _xtruss(p: Node3D, x: float, L: float, R: float) -> void:
	NAShips._truss(p, x, L, R)

static func _goldblock(p: Node3D, x: float, L: float, R: float, mast: int) -> void:
	var g := _gold_mat()
	var pts: Array = [Vector2(x, 0.001), Vector2(x, R * 0.82), Vector2(x - 0.03, R * 0.98), Vector2(x - 0.06, R), Vector2(x - L + 0.06, R), Vector2(x - L + 0.03, R * 0.98), Vector2(x - L, R * 0.82), Vector2(x - L, 0.001)]
	OrionCV2._lathe(p, pts, 8, g, Vector3.ZERO)
	var steel := _m(Color("#8d9198"), 0.85, 0.3)
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var f := OrionCV2._radial(p, x - L * 0.5, a + PI / 8.0, R * 0.93)
		OrionCV2._rbox(f, Vector3(L * 0.5, 0.012, 0.06), dark, Vector3(0, 0.0, 0), 3.0, 4)
	UnitModels.ring(p, R * 0.96, R * 1.04, steel, Vector3(x - L * 0.5, 0, 0), Vector3(0, 0, PI / 2))
	# mast on a small box
	var f2 := OrionCV2._radial(p, x - L * 0.55, PI * 0.5, R * 0.95)
	OrionCV2._rbox(f2, Vector3(0.2, 0.1, 0.2), _m(Color("#cdb77d"), 0.5, 0.5), Vector3(0, 0.05, 0), 3.0, 4)
	OrionCV2._strut(p, Vector3(x - L * 0.55, R + 0.1, 0), Vector3(x - L * 0.55, R + 0.1 + 0.18 * mast, 0), 0.008, steel)
	if mast > 1:
		OrionCV2._strut(p, Vector3(x - L * 0.1, R * 0.95, 0), Vector3(x - L * 0.1, R * 0.95 + 0.12, 0), 0.006, steel)

static func _hoop(p: Node3D, x: float, Rh: float, R: float, n_tubes: int, braced: bool, hull: Material) -> void:
	var w := 0.14
	var t := 0.075
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var dsteel := _m(Color("#4d5058"), 0.8, 0.4)
	var gold := _m(ORANGE, 0.85, 0.35)
	var pts: Array = [Vector2(x + w * 0.5, Rh - t), Vector2(x + w * 0.5, Rh), Vector2(x - w * 0.5, Rh), Vector2(x - w * 0.5, Rh - t), Vector2(x + w * 0.5, Rh - t)]
	OrionCV2._lathe(p, pts, 48, hull, Vector3.ZERO)
	# raised plates round the outer face
	var segs := 36
	for i in segs:
		var a := i * TAU / segs
		var f := OrionCV2._radial(p, x, a, Rh)
		OrionCV2._rbox(f, Vector3(w * 0.8, 0.02, Rh * TAU / segs * 0.8), hull, Vector3(0, 0.008, 0), 3.0, 4)
	for sx in [-1.0, 1.0]:
		UnitModels.ring(p, Rh - 0.012, Rh + 0.014, gold, Vector3(x + sx * w * 0.5, 0, 0), Vector3(0, 0, PI / 2))
		UnitModels.ring(p, Rh - t - 0.014, Rh - t + 0.01, steel, Vector3(x + sx * w * 0.5, 0, 0), Vector3(0, 0, PI / 2))
	# collar on the hull and spokes
	UnitModels.cylx(p, R * 1.12, R * 1.12, w * 1.2, hull, Vector3(x, 0, 0), 24)
	for k in 8:
		var a := k * TAU / 8.0
		var cardinal := k % 2 == 0
		var dy := sin(a)
		var dz := cos(a)
		var r_in := R * 1.05
		var r_out := Rh - t
		if cardinal or braced:
			OrionCV2._strut(p, Vector3(x + 0.045, r_in * dy, r_in * dz), Vector3(x + 0.045, r_out * dy, r_out * dz), 0.012 if cardinal else 0.008, dsteel)
			OrionCV2._strut(p, Vector3(x - 0.045, r_in * dy, r_in * dz), Vector3(x - 0.045, r_out * dy, r_out * dz), 0.012 if cardinal else 0.008, dsteel)
			if cardinal:
				var rm := lerpf(r_in, r_out, 0.5)
				OrionCV2._strut(p, Vector3(x + 0.045, r_in * dy, r_in * dz), Vector3(x - 0.045, rm * dy, rm * dz), 0.007, steel)
				OrionCV2._strut(p, Vector3(x - 0.045, rm * dy, rm * dz), Vector3(x + 0.045, r_out * dy, r_out * dz), 0.007, steel)
	# capped canisters standing on the ring at the four compass points, with orange bands and small side pegs
	var count := n_tubes
	for k in count:
		var a := k * TAU / count
		var f := OrionCV2._radial(p, x, a, Rh)
		var cap := CapsuleMesh.new()
		cap.radius = 0.062
		cap.height = 0.36
		var mi := MeshInstance3D.new()
		mi.mesh = cap
		mi.material_override = hull
		mi.position = Vector3(0, 0.02, 0)
		f.add_child(mi)
		for off in [-0.11, 0.0, 0.11]:
			var tr := TorusMesh.new()
			tr.inner_radius = 0.058
			tr.outer_radius = 0.07
			var rm := MeshInstance3D.new()
			rm.mesh = tr
			rm.material_override = gold
			rm.position = Vector3(0, 0.02 + off * 1.0, 0)
			f.add_child(rm)
		OrionCV2._strut(f, Vector3(0.1, 0.02, 0), Vector3(-0.1, 0.02, 0), 0.01, dsteel)

static func _hub8(p: Node3D, x: float, L: float, R: float, hull: Material) -> void:
	var steel := _m(Color("#aeb3ba"), 0.85, 0.3)
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	var gold := _m(ORANGE, 0.85, 0.35)
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	# faceted 8-sided block (flat shaded, chamfered ends) with an inner core
	var pts: Array = [Vector2(x, 0.001), Vector2(x, R * 0.72), Vector2(x - 0.12, R), Vector2(x - L + 0.12, R), Vector2(x - L, R * 0.72), Vector2(x - L, 0.001)]
	_octa(p, pts, hull)
	# frame edges
	for k in 8:
		var a := (k + 0.5) * TAU / 8.0
		var rr := R / cos(PI / 8.0)
		OrionCV2._strut(p, Vector3(x - 0.12, rr * 0.72 / R * R * sin(a) * 0.98, rr * 0.72 / R * R * cos(a) * 0.98), Vector3(x - 0.12, rr * sin(a), rr * cos(a)), 0.012, dsteel)
		OrionCV2._strut(p, Vector3(x - 0.12, rr * sin(a), rr * cos(a)), Vector3(x - L + 0.12, rr * sin(a), rr * cos(a)), 0.016, steel)
		OrionCV2._strut(p, Vector3(x - L + 0.12, rr * sin(a), rr * cos(a)), Vector3(x - L + 0.12, rr * 0.72 * sin(a), rr * 0.72 * cos(a)), 0.012, dsteel)
	# gold oval hatches on the +Z / -Z / +Y faces
	for a in [0.0, PI, PI * 0.5]:
		var f := OrionCV2._radial(p, x - L * 0.45, a, R * 1.0)
		OrionCV2._rbox(f, Vector3(0.26, 0.03, 0.17), gold, Vector3(0, 0.01, 0), 4.0, 10)
		OrionCV2._rbox(f, Vector3(0.16, 0.034, 0.08), dark, Vector3(0, 0.014, 0), 4.0, 8)
		OrionCV2._rbox(f, Vector3(0.14, 0.02, 0.5), _m(Color("#cfcbc0"), 0.4, 0.5), Vector3(0.28, 0.0, 0.0), 3.0, 4)
	# vertical canisters on top / bottom, offset along the hub as on the sheet
	for s in [1.0, -1.0]:
		var cx := x - L * (0.28 if s > 0 else 0.62)
		var cap := CapsuleMesh.new()
		cap.radius = 0.075
		cap.height = 0.55
		var mi := MeshInstance3D.new()
		mi.mesh = cap
		mi.material_override = hull
		mi.position = Vector3(cx, s * (R + 0.2), 0)
		p.add_child(mi)
		for off in [-0.2, 0.2]:
			UnitModels.ring(p, 0.07, 0.085, gold, Vector3(cx, s * (R + 0.2) + off, 0))
		OrionCV2._strut(p, Vector3(cx, s * R * 0.9, 0), Vector3(cx, s * (R + 0.1), 0), 0.02, dsteel)
	# small box turret on top
	OrionCV2._rbox(p, Vector3(0.2, 0.12, 0.2), _m(Color("#cdb77d"), 0.5, 0.5), Vector3(x - L * 0.5, R + 0.06, 0), 3.0, 4)

static func _octa(p: Node3D, pts: Array, hull: Material) -> void:
	# flat shaded 8-sided revolve of the profile (x, r) using the shared lathe with few segments
	OrionCV2._lathe(p, pts, 8, hull, Vector3.ZERO)

static func _drum(p: Node3D, x: float, L: float, R: float, hull: Material) -> void:
	var gold := _m(ORANGE, 0.85, 0.35)
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	AsiaShips._barrel(p, x, L, R, hull, Color("#ffb347"))
	# broad orange front band, hatch with light doors, grille
	UnitModels.cylx(p, R * 1.03, R * 1.03, 0.09, gold, Vector3(x - 0.05, 0, 0), 32)
	for a in [0.0, PI]:
		var f := OrionCV2._radial(p, x - L * 0.55, a, R * 0.99)
		OrionCV2._rbox(f, Vector3(L * 0.5, 0.02, 0.26), dark, Vector3.ZERO, 3.0, 4)
		for d in [-0.07, 0.07]:
			OrionCV2._rbox(f, Vector3(L * 0.4, 0.024, 0.09), _m(Color("#e8e5dc"), 0.3, 0.5), Vector3(0, 0.004, d), 3.0, 4)
	var f3 := OrionCV2._radial(p, x - L * 0.55, PI * 0.5, R * 0.99)
	OrionCV2._vent(f3, 0.22, L * 0.5, 6, steel, dark)
	UnitModels.ring(p, R * 0.96, R * 1.04, steel, Vector3(x - L * 0.92, 0, 0), Vector3(0, 0, PI / 2))

static func _boom(p: Node3D, x: float, span: float, pw: float, pl: float, hull: Material) -> void:
	var steel := _m(Color("#aeb3ba"), 0.85, 0.3)
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	var gold := _m(ORANGE, 0.85, 0.35)
	var gmat := _gold_mat()
	# cross beam along Z (twin rails with braces) and a shorter spiked beam along Y
	for off in [-0.05, 0.05]:
		OrionCV2._strut(p, Vector3(x, off, -span), Vector3(x, off, span), 0.016, steel)
		OrionCV2._strut(p, Vector3(x, -0.0, 0), Vector3(x, off, 0), 0.01, dsteel)
	var n := int(span / 0.12)
	for i in 2 * n + 1:
		var z := -span + span * i / n
		OrionCV2._strut(p, Vector3(x, -0.05, z), Vector3(x, 0.05, z + span / n * 0.5), 0.007, dsteel)
	for s in [-1.0, 1.0]:
		# bracket and gold panel at each beam tip, lying flat in the XZ plane
		var tip: float = s * span
		OrionCV2._rbox(p, Vector3(0.1, 0.1, 0.1), steel, Vector3(x, 0, tip), 3.0, 4)
		var ch := pw * 0.22
		var pts := PackedVector2Array([Vector2(pl * 0.5 - ch, -pw * 0.5), Vector2(pl * 0.5, -pw * 0.5 + ch), Vector2(pl * 0.5, pw * 0.5 - ch), Vector2(pl * 0.5 - ch, pw * 0.5), Vector2(-pl * 0.5 + ch, pw * 0.5), Vector2(-pl * 0.5, pw * 0.5 - ch), Vector2(-pl * 0.5, -pw * 0.5 + ch), Vector2(-pl * 0.5 + ch, -pw * 0.5)])
		var pn := Node3D.new()
		pn.position = Vector3(x, 0.0, tip + s * (pw * 0.5 + 0.05))
		p.add_child(pn)
		AsiaShips._plate(pn, pts, 0.03, gmat)
		# the inner frame of the panel
		for q in 3:
			OrionCV2._strut(pn, Vector3(-pl * 0.5 + pl * (q + 0.5) / 3.0, 0.02, -pw * 0.45), Vector3(-pl * 0.5 + pl * (q + 0.5) / 3.0, 0.02, pw * 0.45), 0.006, dsteel)
		OrionCV2._strut(pn, Vector3(0, 0.02, -pw * 0.45), Vector3(0, 0.02, pw * 0.45), 0.006, dsteel)
		OrionCV2._strut(p, Vector3(x, 0, tip), Vector3(x, 0, tip + s * 0.06), 0.02, dsteel)
	for s in [-1.0, 1.0]:
		OrionCV2._strut(p, Vector3(x, 0, 0), Vector3(x, s * span * 0.42, 0), 0.02, steel)
		OrionCV2._strut(p, Vector3(x, s * span * 0.42, 0), Vector3(x, s * span * 0.58, 0), 0.007, dsteel)
		UnitModels.ball(p, 0.04, gold, Vector3(x, s * span * 0.42, 0))
	# cage around the beam root
	UnitModels.cylx(p, 0.2, 0.2, 0.2, hull, Vector3(x, 0, 0), 16)

static func _engine(core: Node3D, x: float, R: float, n: int, hull: Material) -> void:
	var tr := R * 0.68
	var pts: Array = [Vector2(x, 0.001), Vector2(x, R * 0.9), Vector2(x - 0.07, R * 0.97), Vector2(x - 0.24, tr), Vector2(x - 0.26, 0.001)]
	OrionCV2._lathe(core, pts, 32, hull, Vector3.ZERO)
	_band(core, x - 0.05, R * 0.97)
	var ex := x - 0.26
	var offs: Array = []
	var rm := tr * 0.75
	match n:
		1:
			offs = [Vector2.ZERO]
		2:
			offs = [Vector2(0, tr * 0.52), Vector2(0, -tr * 0.52)]
			rm = tr * 0.5
		_:
			for k in 3:
				offs.append(Vector2(sin(PI * 0.5 + k * TAU / 3), cos(PI * 0.5 + k * TAU / 3)) * tr * 0.56)
			rm = tr * 0.46
	for o in offs:
		RUShips._bell(core, ex, o.x, o.y, rm)

static func _finish(root: Node3D, core: Node3D) -> Node3D:
	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root

# ------------------------------------------------------------------ special ships
static func _plane(root: Node3D, core: Node3D, hull: Material) -> Node3D:
	var gold := _m(ORANGE, 0.85, 0.35)
	var glass := _m(Color("#1f3f66"), 0.8, 0.12, 0.5)
	var body := Node3D.new()
	body.scale = Vector3(1.0, 0.62, 1.35)
	core.add_child(body)
	AsiaShips._nose(body, -1.4, ["needle", 0.3, 1.4], hull)
	AsiaShips._barrel(body, -1.4, 1.5, 0.3, hull, Color("#ffb347"))
	# nose tip cap
	UnitModels.ball(core, 0.03, _m(Color("#2a2b30"), 0.7, 0.4), Vector3(0.0, 0, 0))
	# cockpit windows and the red sun disc on the top of the fuselage
	for i in 4:
		var f := OrionCV2._radial(core, -0.7 - i * 0.14, PI * 0.5, 0.19)
		OrionCV2._rbox(f, Vector3(0.1, 0.02, 0.07), glass, Vector3.ZERO, 3.0, 4)
	var sun := OrionCV2._radial(core, -0.95, PI * 0.5, 0.2)
	UnitModels.ball(sun, 0.07, _m(Color("#c8202a"), 0.2, 0.5, 0.15), Vector3(0, 0.0, 0), Vector3(1, 0.12, 1))
	AsiaShips.trim_col = ORANGE
	AsiaShips._wings(core, "cross", -1.55, 0.8, 0.95, 0.3, hull)
	AsiaShips.trim_col = Color("#58b8ff")
	_engine(core, -2.9, 0.26, 3, hull)
	return _finish(root, core)

static func _yamato(root: Node3D, core: Node3D, hull: Material) -> Node3D:
	var gold := _m(ORANGE, 0.85, 0.35)
	var dark := _m(Color("#17181b"), 0.5, 0.45)
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var dsteel := _m(Color("#4a4d55"), 0.8, 0.4)
	AsiaShips._nose(core, 0.0, ["ogive", 0.52, 1.7], hull)
	AsiaShips._barrel(core, 0.0, 1.2, 0.52, hull, Color("#ffb347"))
	# orange front band and a black slatted vent field on the shoulder
	UnitModels.cylx(core, 0.54, 0.54, 0.16, gold, Vector3(-0.2, 0, 0), 32)
	for a in [PI * 0.5, PI * 1.5, 0.0, PI]:
		var f := OrionCV2._radial(core, -0.78, a, 0.52)
		OrionCV2._vent(f, 0.48, 0.5, 8, steel, dark)
	var sun := OrionCV2._radial(core, 0.55, 0.0, 0.36)
	UnitModels.ball(sun, 0.06, _m(Color("#c8202a"), 0.2, 0.5, 0.15), Vector3(0, 0.0, 0), Vector3(0.12, 1, 1))
	var eye := OrionCV2._radial(core, 0.3, 0.0, 0.46)
	UnitModels.ring(eye, 0.05, 0.075, steel, Vector3.ZERO)
	UnitModels.ball(eye, 0.05, _m(Color("#16365e"), 0.9, 0.1, 0.4), Vector3(0, 0.01, 0), Vector3(1, 0.45, 1))
	# angular rear shoulders
	for s in [-1.0, 1.0]:
		OrionCV2._rbox(core, Vector3(0.55, 0.3, 0.2), _m(Color("#d4d0c5"), 0.4, 0.5), Vector3(-1.2, 0.0, s * 0.5), 3.0, 4)
	# rear body, then three bells
	AsiaShips._barrel(core, -1.2, 0.35, 0.5, hull, Color("#ffb347"))
	_engine(core, -1.55, 0.46, 3, hull)
	# two pairs of pill pods on struts, long pod with a small nose pod
	for s in [-1.0, 1.0]:
		var zc: float = s * 1.0
		OrionCV2._strut(core, Vector3(-0.85, 0, s * 0.45), Vector3(-0.85, 0, zc), 0.03, dsteel)
		OrionCV2._strut(core, Vector3(-0.35, 0, s * 0.45), Vector3(-0.35, 0, zc), 0.025, dsteel)
		var big := CapsuleMesh.new()
		big.radius = 0.12
		big.height = 1.0
		var mb := MeshInstance3D.new()
		mb.mesh = big
		mb.material_override = hull
		mb.rotation = Vector3(0, 0, PI / 2)
		mb.position = Vector3(-0.8, 0, zc)
		core.add_child(mb)
		var sm := CapsuleMesh.new()
		sm.radius = 0.075
		sm.height = 0.42
		var ms := MeshInstance3D.new()
		ms.mesh = sm
		ms.material_override = hull
		ms.rotation = Vector3(0, 0, PI / 2)
		ms.position = Vector3(-0.05, 0, zc)
		core.add_child(ms)
		for bx in [-1.1, -0.5]:
			UnitModels.ring(core, 0.095, 0.115, gold, Vector3(bx, 0, zc), Vector3(0, 0, PI / 2))
		UnitModels.ring(core, 0.07, 0.088, gold, Vector3(-0.15, 0, zc), Vector3(0, 0, PI / 2))
		OrionCV2._strut(core, Vector3(-0.35, 0, zc), Vector3(-0.2, 0, zc), 0.02, dsteel)
	return _finish(root, core)

# ------------------------------------------------------------------ the model
static func build(name: String) -> Node3D:
	var spec: Dictionary = SPECS[name]
	var root := Node3D.new()
	root.name = "JP_" + name
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var hull := _hull_mat(name)
	if spec.get("kind", "") == "plane":
		return _plane(root, core, hull)
	if spec.get("kind", "") == "yamato":
		return _yamato(root, core, hull)
	var nose: Array = spec["nose"]
	var x: float = -float(nose[2])
	AsiaShips._nose(core, x, nose, hull)
	UnitModels.ball(core, 0.035, _m(ORANGE, 0.85, 0.35), Vector3(0, 0, 0))
	var R: float = nose[1]
	var rear_r := R
	for m in spec["mods"]:
		var t: String = m[0]
		match t:
			"band":
				_banded(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"xtruss":
				_xtruss(core, x, m[1], m[2])
				x -= m[1]
				R = m[2]
				rear_r = R
			"rack":
				_rack(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"gold":
				_goldblock(core, x, m[1], m[2], int(m[3]))
				x -= m[1]
				R = m[2]
				rear_r = R
			"hoop":
				_hoop(core, x - 0.08, m[1], R, int(m[2]), bool(m[3]), hull)
				x -= 0.16
			"hub8":
				_hub8(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
			"boom":
				_boom(core, x - 0.2, m[1], m[2], m[3], hull)
				x -= 0.4
			"drum":
				_drum(core, x, m[1], m[2], hull)
				x -= m[1]
				R = m[2]
				rear_r = R
	_engine(core, x, rear_r, int(spec["eng"]), hull)
	return _finish(root, core)
