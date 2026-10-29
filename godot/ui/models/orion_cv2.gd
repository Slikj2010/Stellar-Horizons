## North America's Orion (CV-2): a weathered, painted-metal crew capsule on a ribbed service module with twin engine bells.
## Hand-painted look comes from generated albedo + normal-map textures (panel seams, rivets, grime, orange bands,
## hazard stripe, ribbed radiator) plus a small kit of modelled details (porthole, window, handrails, RCS quads, wiring).
## Nose points to +X.  Not wired into the game yet; see tests/orion_preview.gd for renders.
class_name OrionCV2
extends RefCounted

const CAP_L := 0.95        ## capsule length
const CAP_R0 := 0.22       ## radius at the nose end of the cone
const CAP_R1 := 0.62       ## radius at the base
const SM_R := 0.62
const SM_L := 1.12

static var _tex := {}

# ------------------------------------------------------------------ textures
## Paints an albedo + normal-map pair. o keys: base, seed, cols, rows (v fractions), bands, ribs, hazard, grime, rivets
static func _surf(key: String, w: int, h: int, o: Dictionary) -> Array:
	if _tex.has(key): return _tex[key]
	var base: Color = o.get("base", Color("#b8bbc1"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", 1))
	var alb := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var hgt := Image.create(w, h, false, Image.FORMAT_RGBA8)
	alb.fill(base)
	hgt.fill(Color(0.5, 0.5, 0.5))
	var cols: int = o.get("cols", 12)
	var rows: Array = o.get("rows", [])
	var xs: Array = []
	for i in cols + 1: xs.append(int(round(float(i) * w / cols)))
	var ys: Array = [0]
	for r in rows: ys.append(int(float(r) * h))
	ys.append(h)
	# per-panel tone variation
	for ri in ys.size() - 1:
		for ci in cols:
			var t := rng.randf_range(-0.045, 0.045)
			alb.fill_rect(Rect2i(xs[ci], ys[ri], xs[ci + 1] - xs[ci], ys[ri + 1] - ys[ri]), Color(base.r + t, base.g + t, base.b + t))
	# painted bands: [v0, v1, col, (u0, u1)]
	for b in o.get("bands", []):
		var u0: float = b[3] if b.size() > 3 else 0.0
		var u1: float = b[4] if b.size() > 4 else 1.0
		var rc := Rect2i(int(u0 * w), int(float(b[0]) * h), int((u1 - u0) * w), int(float(b[1] - b[0]) * h))
		var c: Color = b[2]
		for ri in ys.size() - 1:
			for ci in cols:
				var cell := Rect2i(xs[ci], ys[ri], xs[ci + 1] - xs[ci], ys[ri + 1] - ys[ri]).intersection(rc)
				if cell.size.x > 0 and cell.size.y > 0:
					var t := rng.randf_range(-0.05, 0.05)
					alb.fill_rect(cell, Color(c.r + t, c.g + t * 0.6, c.b + t * 0.4))
		alb.fill_rect(Rect2i(rc.position.x, rc.position.y, rc.size.x, 2), c.darkened(0.35))
		alb.fill_rect(Rect2i(rc.position.x, rc.end.y - 2, rc.size.x, 2), c.darkened(0.35))
	# ribbed radiator zone: [v0, v1, count, col]
	for rb in o.get("ribs", []):
		var y0 := int(float(rb[0]) * h)
		var y1 := int(float(rb[1]) * h)
		var u0: float = rb[4] if rb.size() > 4 else 0.0
		var u1: float = rb[5] if rb.size() > 5 else 1.0
		var x0 := int(u0 * w)
		var x1 := int(u1 * w)
		alb.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), rb[3])
		hgt.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), Color(0.6, 0.6, 0.6))
		var step := float(y1 - y0) / int(rb[2])
		for i in int(rb[2]):
			var yy := y0 + int(step * (i + 0.5))
			hgt.fill_rect(Rect2i(x0 + 3, yy - 3, x1 - x0 - 6, 6), Color(0.95, 0.95, 0.95))
			alb.fill_rect(Rect2i(x0 + 3, yy - 3, x1 - x0 - 6, 6), (rb[3] as Color).lightened(0.12))
			alb.fill_rect(Rect2i(x0 + 3, yy + 3, x1 - x0 - 6, 3), (rb[3] as Color).darkened(0.35))
	# seams (grooves) + rivets
	var dark := base.darkened(0.5)
	for ci in cols:
		_vline(alb, hgt, xs[ci], 0, h, dark)
	for ri in range(1, ys.size() - 1):
		_hline(alb, hgt, ys[ri], 0, w, dark)
	if o.get("rivets", true):
		for ci in cols:
			for yy in range(6, h - 4, 11):
				_rivet(alb, hgt, xs[ci] + 6, yy)
				_rivet(alb, hgt, xs[ci] - 6 + (w if ci == 0 else 0), yy)
		for ri in range(1, ys.size() - 1):
			for xx in range(5, w - 4, 11):
				_rivet(alb, hgt, xx, ys[ri] - 6)
				_rivet(alb, hgt, xx, ys[ri] + 6)
	# hazard stripes: [v0, v1]
	if o.has("hazard"):
		var hz: Array = o["hazard"]
		var y0 := int(float(hz[0]) * h)
		var y1 := int(float(hz[1]) * h)
		for y in range(y0, y1):
			for x in w:
				var on := (int((x + y) / 10) % 2) == 0
				alb.set_pixel(x, y, Color("#e8c20c") if on else Color("#17181a"))
		alb.fill_rect(Rect2i(0, y0, w, 2), Color("#17181a"))
		alb.fill_rect(Rect2i(0, y1 - 2, w, 2), Color("#17181a"))
	# grime, scuffs and vertical streaks
	var grime: float = o.get("grime", 0.5)
	var n1 := FastNoiseLite.new()
	n1.seed = int(o.get("seed", 1))
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.012
	var n2 := FastNoiseLite.new()
	n2.seed = int(o.get("seed", 1)) + 7
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.frequency = 0.09
	var n3 := FastNoiseLite.new()
	n3.seed = int(o.get("seed", 1)) + 13
	n3.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n3.frequency = 0.02
	var i1 := n1.get_image(w, h)
	var i2 := n2.get_image(w, h)
	var i3 := n3.get_image(w, h)
	for y in h:
		for x in w:
			var g := clampf((i1.get_pixel(x, y).r - 0.42) * 1.6, 0.0, 1.0) * grime
			var s := clampf((i2.get_pixel(x, y).r - 0.62) * 3.0, 0.0, 1.0) * grime * 0.5
			var st := clampf((i3.get_pixel(int(x * 0.12) % w, y).r - 0.5) * 2.0, 0.0, 1.0) * grime * 0.55
			var a := alb.get_pixel(x, y)
			var f := 1.0 - g * 0.35 - st * 0.3
			var c := Color(a.r * f, a.g * f, a.b * f * (1.0 - g * 0.05))
			c = c.lerp(Color("#d9dadd"), s * 0.35)
			alb.set_pixel(x, y, c)
			var hv := hgt.get_pixel(x, y).r + (i2.get_pixel(x, y).r - 0.5) * 0.08 * grime
			hgt.set_pixel(x, y, Color(hv, hv, hv))
	var nrm := hgt.duplicate() as Image
	nrm.bump_map_to_normal_map(4.0)
	alb.generate_mipmaps()
	nrm.generate_mipmaps()
	var out := [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(nrm)]
	_tex[key] = out
	return out

static func _vline(alb: Image, hgt: Image, x: int, y0: int, y1: int, col: Color) -> void:
	var w := alb.get_width()
	alb.fill_rect(Rect2i(clampi(x - 1, 0, w - 1), y0, 2, y1 - y0), col)
	hgt.fill_rect(Rect2i(clampi(x - 1, 0, w - 1), y0, 2, y1 - y0), Color(0.2, 0.2, 0.2))

static func _hline(alb: Image, hgt: Image, y: int, x0: int, x1: int, col: Color) -> void:
	alb.fill_rect(Rect2i(x0, y - 1, x1 - x0, 2), col)
	hgt.fill_rect(Rect2i(x0, y - 1, x1 - x0, 2), Color(0.2, 0.2, 0.2))

static func _rivet(alb: Image, hgt: Image, x: int, y: int) -> void:
	var w := alb.get_width()
	var h := alb.get_height()
	if x < 1 or y < 1 or x >= w - 1 or y >= h - 1: return
	hgt.fill_rect(Rect2i(x - 1, y - 1, 3, 3), Color(0.95, 0.95, 0.95))
	var c := alb.get_pixel(x, y)
	alb.fill_rect(Rect2i(x - 1, y - 1, 3, 3), c.lightened(0.18))

static func _smat(key: String, w: int, h: int, o: Dictionary, metal := 0.3, rough := 0.55) -> StandardMaterial3D:
	var t: Array = _surf(key, w, h, o)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t[0]
	m.normal_enabled = true
	m.normal_texture = t[1]
	m.normal_scale = 1.0
	m.metallic = metal
	m.roughness = rough
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func _flag(kind: String) -> ImageTexture:
	if _tex.has("flag_" + kind): return _tex["flag_" + kind]
	var img := Image.create(130, 70, false, Image.FORMAT_RGBA8)
	if kind == "us":
		for y in 70:
			img.fill_rect(Rect2i(0, y, 130, 1), Color("#c9432e") if (y / 5) % 2 == 0 else Color("#ece8de"))
		img.fill_rect(Rect2i(0, 0, 56, 38), Color("#2f4f9c"))
		for i in 5:
			for j in 4: img.fill_rect(Rect2i(6 + i * 10, 5 + j * 9, 3, 3), Color("#ece8de"))
	else:
		img.fill(Color("#ece8de"))
		img.fill_rect(Rect2i(0, 0, 32, 70), Color("#c9282f"))
		img.fill_rect(Rect2i(98, 0, 32, 70), Color("#c9282f"))
		var leaf := PackedVector2Array([Vector2(65, 10), Vector2(72, 26), Vector2(86, 22), Vector2(80, 40), Vector2(92, 46), Vector2(70, 50), Vector2(69, 62), Vector2(61, 62), Vector2(60, 50), Vector2(38, 46), Vector2(50, 40), Vector2(44, 22), Vector2(58, 26)])
		for y in range(8, 64):
			for x in range(34, 96):
				if Geometry2D.is_point_in_polygon(Vector2(x, y), leaf): img.set_pixel(x, y, Color("#c9282f"))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex["flag_" + kind] = t
	return t

# ------------------------------------------------------------------ helpers
static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

## A frame sitting on the capsule's cone surface at axial position x and angle ang; local +Z is the outward normal.
static func _on_cone(parent: Node3D, x: float, ang: float) -> Node3D:
	var slope := atan2(CAP_R1 - CAP_R0, CAP_L)
	var rr := lerpf(CAP_R1, CAP_R0, x / CAP_L)
	var n := Node3D.new()
	var b := Basis(Vector3.RIGHT, ang)
	n.transform = Transform3D(b * Basis(Vector3.UP, slope), b * Vector3(0, 0, rr) + Vector3(x, 0, 0))
	parent.add_child(n)
	return n

## A frame on the service module's flank at axial position x and angle ang.
static func _on_sm(parent: Node3D, x: float, ang: float, out := 0.0) -> Node3D:
	var n := Node3D.new()
	var b := Basis(Vector3.RIGHT, ang)
	n.transform = Transform3D(b, b * Vector3(0, 0, SM_R + out) + Vector3(x, 0, 0))
	parent.add_child(n)
	return n

static func _rcs_quad(parent: Node3D, steel: Material, black: Material) -> void:
	UnitModels.box(parent, Vector3(0.07, 0.07, 0.05), steel, Vector3(0, 0, 0.02))
	UnitModels.cylx(parent, 0.012, 0.03, 0.08, black, Vector3(0.075, 0, 0.03), 12)
	UnitModels.cylx(parent, 0.03, 0.012, 0.08, black, Vector3(-0.075, 0, 0.03), 12)
	UnitModels.cyly(parent, 0.012, 0.03, 0.08, black, Vector3(0, 0.075, 0.03), 12)
	UnitModels.cyly(parent, 0.03, 0.012, 0.08, black, Vector3(0, -0.075, 0.03), 12)
	UnitModels.cylz(parent, 0.03, 0.07, black, Vector3(0, 0, 0.075), 12)

# ------------------------------------------------------------------ the model
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Orion_CV2"
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var steel := _m(Color("#7d828b"), 0.75, 0.4)
	var dull := _m(Color("#9aa0a8"), 0.5, 0.5)
	var black := _m(Color("#1b1c1f"), 0.55, 0.45)
	var cyan := _m(Color("#7fdcf5"), 0.0, 0.25, 1.1)
	var red := _m(Color("#d9322b"), 0.1, 0.5, 0.9)
	var yel := _m(Color("#f0c418"), 0.1, 0.5, 0.9)
	var tan := _m(Color("#b9a67c"), 0.3, 0.6)
	var orange := Color("#212327")   ## painted bands are black

	# --- capsule: grey painted cone with orange bands and panel seams (v runs nose -> base)
	var cap_mat := _smat("cap", 640, 320, {
		"base": Color("#a2a6ad"), "seed": 4, "cols": 12, "rows": [0.1, 0.3, 0.56, 0.84], "grime": 1.0,
		"bands": [[0.1, 0.3, orange], [0.56, 0.84, orange, 0.0, 0.34], [0.56, 0.84, orange, 0.5, 0.84]],
	})
	var cap := UnitModels.cylx(core, CAP_R0, CAP_R1, CAP_L, cap_mat, Vector3(CAP_L * 0.5, 0, 0), 48)
	cap.name = "Capsule"
	# nose cap: pale blue-grey truncated cone with a dark window block
	UnitModels.cylx(core, 0.1, 0.2, 0.13, _m(Color("#8ea2ad"), 0.5, 0.4), Vector3(CAP_L + 0.045, 0, 0), 24)
	UnitModels.box(core, Vector3(0.1, 0.17, 0.2), black, Vector3(CAP_L - 0.02, 0.0, 0.0))
	UnitModels.cylx(core, 0.045, 0.1, 0.05, _m(Color("#a9c3d0"), 0.4, 0.35), Vector3(CAP_L + 0.13, 0, 0), 16)
	# base lip of the capsule
	UnitModels.cylx(core, SM_R + 0.015, SM_R + 0.015, 0.04, steel, Vector3(0.02, 0, 0), 48)

	# porthole with glowing glass
	var p := _on_cone(core, 0.58, 0.0)
	UnitModels.cylz(p, 0.105, 0.035, steel, Vector3(0, 0, 0.0), 24)
	UnitModels.cylz(p, 0.07, 0.04, cyan, Vector3(0, 0, 0.004), 24)
	# big cyan window and a smaller black port
	var w := _on_cone(core, 0.55, 1.05)
	UnitModels.box(w, Vector3(0.36, 0.2, 0.02), black, Vector3(0, 0, 0.0))
	UnitModels.box(w, Vector3(0.3, 0.15, 0.02), cyan, Vector3(0, 0, 0.012))
	var w2 := _on_cone(core, 0.55, -1.05)
	UnitModels.box(w2, Vector3(0.36, 0.2, 0.02), black, Vector3(0, 0, 0.0))
	UnitModels.box(w2, Vector3(0.3, 0.15, 0.02), cyan, Vector3(0, 0, 0.012))
	var hatch := _on_cone(core, 0.72, 0.5)
	UnitModels.box(hatch, Vector3(0.1, 0.06, 0.02), black, Vector3.ZERO)
	# shoulder bulges (antenna housings)
	for a in [PI * 0.62, -PI * 0.62]:
		var sb := _on_cone(core, 0.8, a)
		UnitModels.cylz(sb, 0.06, 0.1, dull, Vector3(0, 0, 0.02), 16)
	# handrail ladder on the lower flank
	var rail := _on_cone(core, 0.16, PI)
	for i in 5:
		UnitModels.cyly(rail, 0.011, 0.011, 0.16, steel, Vector3(0.14 - i * 0.07, 0, 0.032), 8)
	# national flags (as on the token) on the +Z flank beside the porthole
	var f1 := _on_cone(core, 0.4, 0.55)
	var f2 := _on_cone(core, 0.4, -0.55)
	for pair in [[f1, "us"], [f2, "ca"]]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.2, 0.108)
		q.mesh = qm
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = _flag(pair[1])
		fm.roughness = 0.8
		q.material_override = fm
		q.position = Vector3(0, 0, 0.006)
		q.rotation = Vector3(0, 0, -PI / 2)
		(pair[0] as Node3D).add_child(q)

	# --- hazard stripe band + warning plates
	var haz := _smat("haz", 512, 64, {"base": Color("#9ea2a8"), "seed": 9, "cols": 12, "rows": [], "hazard": [0.18, 0.84], "grime": 0.35, "rivets": false}, 0.2, 0.6)
	UnitModels.cylx(core, SM_R + 0.01, SM_R + 0.01, 0.1, haz, Vector3(-0.05, 0, 0), 48)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var hp := _on_sm(core, -0.05, a, 0.012)
		UnitModels.box(hp, Vector3(0.1, 0.075, 0.012), _m(Color("#8c8f95"), 0.5, 0.5), Vector3.ZERO)
		UnitModels.cylx(hp, 0.0, 0.025, 0.035, red, Vector3(0, 0, 0.012), 3).rotation = Vector3(0, 0, -PI / 2)

	# --- service module: panelled grey drum with a tan ribbed radiator zone
	var sm_mat := _smat("sm", 768, 384, {
		"base": Color("#9ea2a9"), "seed": 21, "cols": 14, "rows": [0.45, 0.6], "grime": 1.1,
		"ribs": [[0.6, 0.95, 6, Color("#c3b58f"), 0.0, 0.2, 0.0, 0.0], [0.6, 0.95, 6, Color("#b09f78"), 0.12, 0.62]],
	}, 0.3, 0.6)
	var sm := UnitModels.cylx(core, SM_R, SM_R, SM_L, sm_mat, Vector3(-0.1 - SM_L * 0.5, 0, 0), 48)
	sm.name = "ServiceModule"
	# lower seam ring & end plate
	UnitModels.cylx(core, SM_R + 0.012, SM_R + 0.012, 0.04, steel, Vector3(-0.1 - SM_L, 0, 0), 48)
	# RCS quads on four sides, indicator lights
	for a in [0.4, PI * 0.5 + 0.4, PI + 0.4, PI * 1.5 + 0.4]:
		var r := _on_sm(core, -0.5, a, 0.0)
		_rcs_quad(r, steel, black)
	var lights := _on_sm(core, -0.28, 0.9, 0.0)
	UnitModels.ball(lights, 0.016, yel, Vector3(0, 0.03, 0.01))
	UnitModels.ball(lights, 0.016, red, Vector3(0, -0.01, 0.01))
	# control panel on the lower body
	var cp := _on_sm(core, -0.95, 0.2, 0.0)
	UnitModels.box(cp, Vector3(0.12, 0.1, 0.014), black, Vector3(0, 0, 0.004))
	UnitModels.box(cp, Vector3(0.07, 0.03, 0.016), _m(Color("#6d8a52"), 0.1, 0.4, 0.6), Vector3(0.0, 0.02, 0.006))
	UnitModels.ball(cp, 0.008, red, Vector3(-0.04, -0.025, 0.012))
	UnitModels.ball(cp, 0.008, yel, Vector3(-0.02, -0.025, 0.012))

	# --- engine section: skirt, two ribbed bells, wiring and a tan hose
	var tail := -0.1 - SM_L
	UnitModels.cylx(core, SM_R * 0.9, SM_R * 0.62, 0.22, _smat("skirt", 256, 128, {"base": Color("#a9adb3"), "seed": 31, "cols": 8, "rows": [], "grime": 0.6}), Vector3(tail - 0.13, 0, 0), 32)
	UnitModels.cylx(core, SM_R * 0.62, SM_R * 0.62, 0.025, yel, Vector3(tail - 0.02, 0, 0), 32)
	# four ribbed bells in a 2x2 square, spaced so neighbouring bells never touch
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var by: float = sy * 0.2
			var bz: float = sz * 0.2
			var x0 := tail - 0.24
			UnitModels.cylx(core, 0.06, 0.06, 0.1, steel, Vector3(x0 - 0.02, by, bz), 16)
			var rr := 0.05
			var xx := x0 - 0.07
			for i in 5:
				var r2 := rr + 0.016 + i * 0.003
				UnitModels.cylx(core, rr, r2, 0.06, _m(Color("#3b3d41"), 0.7, 0.4), Vector3(xx - 0.03, by, bz), 20)
				UnitModels.cylx(core, r2 + 0.004, r2 + 0.004, 0.01, _m(Color("#56595f"), 0.8, 0.35), Vector3(xx - 0.06, by, bz), 20)
				rr = r2
				xx -= 0.065
			UnitModels.cylx(core, rr - 0.01, rr - 0.01, 0.008, _m(Color("#8fd6ff"), 0.0, 0.3, 1.0), Vector3(xx + 0.035, by, bz), 16)
	# swept wings above and below the aft end, just before the engines
	var wing_mat := _smat("wing", 512, 256, {"base": Color("#a2a6ad"), "seed": 41, "cols": 8, "rows": [0.5], "grime": 1.0}, 0.3, 0.55)
	for sy in [-1.0, 1.0]:
		var wroot := UnitModels.box(core, Vector3(0.62, 0.34, 0.035), wing_mat, Vector3(tail - 0.02, sy * 0.72, 0))
		var tip := UnitModels.box(core, Vector3(0.38, 0.3, 0.035), wing_mat, Vector3(tail - 0.14, sy * 1.0, 0))
		wroot.name = "Wing"
		tip.name = "WingTip"
		UnitModels.box(core, Vector3(0.62, 0.03, 0.07), steel, Vector3(tail - 0.02, sy * 0.55, 0))
		UnitModels.box(core, Vector3(0.38, 0.03, 0.06), steel, Vector3(tail - 0.14, sy * 1.15, 0))
		UnitModels.box(core, Vector3(0.05, 0.3, 0.07), steel, Vector3(tail + 0.3, sy * 0.72, 0), Vector3(0, 0, sy * 0.0))
	# red wiring and a tan hose along the skirt
	for i in 3:
		var a := 0.4 + i * 0.12
		var wr := _on_sm(core, tail - 0.1, a + PI * 0.5, -0.0)
		UnitModels.cylx(wr, 0.007, 0.007, 0.26, red, Vector3(0, 0, -0.01), 6)
	var hose := _on_sm(core, tail - 0.1, PI * 0.5 - 0.5, -0.15)
	UnitModels.cylx(hose, 0.018, 0.018, 0.3, _m(Color("#caa86a"), 0.2, 0.7), Vector3(-0.1, 0, 0), 10)

	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
