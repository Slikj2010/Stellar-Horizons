## North America's CV-2 crew ships (Orion and Discovery), modelled on the faceted white-plate reference:
## a 12-sided tapering capsule with big black window panels and a lens, a collar with hazard ticks, a long 12-sided
## service module clad in staggered riveted plates with black access panels, four wedge fins on the diagonals and a
## 2x2 cluster of truss-mounted engine bells.  Nose points to +X.  Panels are generated textures (albedo + normal map).
## Not wired into the game yet; see tests/orion_preview.gd for renders.
class_name OrionCV2
extends RefCounted

const SIDES := 12
const CAP_L := 0.76
const CAP_R_NOSE := 0.15
const CAP_R_BASE := 0.42
const COLLAR_L := 0.12
const COLLAR_R := 0.37
const SM_L := 1.18
const SM_R0 := 0.38        ## radius at the front of the service module
const SM_R1 := 0.33        ## radius at the rear
const SM_X0 := -0.145      ## front of the service module

static var _tex := {}

# ------------------------------------------------------------------ texture painting
static func _poly(alb: Image, hgt: Image, pts: PackedVector2Array, col: Color, hv: float) -> void:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	for y in range(maxi(int(mn.y), 0), mini(int(mx.y) + 1, alb.get_height())):
		for x in range(maxi(int(mn.x), 0), mini(int(mx.x) + 1, alb.get_width())):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), pts):
				alb.set_pixel(x, y, col)
				hgt.set_pixel(x, y, Color(hv, hv, hv))

static func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts: c += p
	c /= pts.size()
	var out := PackedVector2Array()
	for p in pts: out.append(c + (p - c) * k)
	return out

## black inset panel with a steel frame
static func _window(alb: Image, hgt: Image, pts: PackedVector2Array) -> void:
	_poly(alb, hgt, pts, Color("#7d8187"), 0.8)
	_poly(alb, hgt, _scaled(pts, 0.9), Color("#16171a"), 0.35)

static func _rivet(alb: Image, hgt: Image, x: int, y: int, light: float) -> void:
	if x < 1 or y < 1 or x >= alb.get_width() - 1 or y >= alb.get_height() - 1: return
	hgt.fill_rect(Rect2i(x - 1, y - 1, 2, 2), Color(0.97, 0.97, 0.97))
	alb.fill_rect(Rect2i(x - 1, y - 1, 2, 2), alb.get_pixel(x, y).lightened(light))

## Staggered riveted plates in long strips (v runs along the ship), plus an optional overlay callable(alb, hgt, w, h).
static func _plates(key: String, w: int, h: int, o: Dictionary) -> Array:
	if _tex.has(key): return _tex[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", 1))
	var alb := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var hgt := Image.create(w, h, false, Image.FORMAT_RGBA8)
	alb.fill(Color("#25262a"))
	hgt.fill(Color(0.28, 0.28, 0.28))
	var cols: int = o.get("cols", 36)
	var tones: Array = o.get("tones", [Color("#dcdcd8"), Color("#cfcfca"), Color("#c3c3be"), Color("#e6e6e2"), Color("#b9b9b4")])
	var lmin: float = o.get("min_len", 70)
	var lmax: float = o.get("max_len", 260)
	var brate: float = o.get("black_rate", 0.12)
	for c in cols:
		var x0 := int(float(c) * w / cols)
		var x1 := int(float(c + 1) * w / cols)
		var y := rng.randi_range(0, 40)
		while y < h:
			var ln := int(rng.randf_range(lmin, lmax))
			if y + ln > h - 26: ln = h - y
			var rc := Rect2i(x0 + 2, y + 2, x1 - x0 - 4, ln - 4)
			if rc.size.y > 8 and rc.size.x > 6:
				var black := rng.randf() < brate
				var col: Color = Color("#1a1b1e") if black else (tones[rng.randi() % tones.size()] as Color)
				var j := rng.randf_range(-0.03, 0.03)
				col = Color(col.r + j, col.g + j, col.b + j)
				alb.fill_rect(rc, col)
				hgt.fill_rect(rc, Color(0.5, 0.5, 0.5) if black else Color(0.62, 0.62, 0.62))
				alb.fill_rect(Rect2i(rc.position.x, rc.position.y, rc.size.x, 2), col.lightened(0.15))
				alb.fill_rect(Rect2i(rc.position.x, rc.end.y - 2, rc.size.x, 2), col.darkened(0.25))
				var lt := 0.5 if black else 0.22
				for yy in range(rc.position.y + 6, rc.end.y - 3, 12):
					_rivet(alb, hgt, rc.position.x + 4, yy, lt)
					_rivet(alb, hgt, rc.end.x - 5, yy, lt)
				for xx in range(rc.position.x + 10, rc.end.x - 8, 12):
					_rivet(alb, hgt, xx, rc.position.y + 4, lt)
					_rivet(alb, hgt, xx, rc.end.y - 5, lt)
				if not black and rng.randf() < 0.2 and rc.size.y > 30:
					var pw := int(rc.size.x * rng.randf_range(0.5, 0.8))
					var ph := int(rc.size.y * rng.randf_range(0.2, 0.4))
					var pr := Rect2i(rc.position.x + (rc.size.x - pw) / 2, rc.position.y + int(rng.randf() * (rc.size.y - ph)), pw, ph)
					alb.fill_rect(pr, Color("#1a1b1e"))
					hgt.fill_rect(pr, Color(0.45, 0.45, 0.45))
			y += ln
	if o.has("overlay"):
		(o["overlay"] as Callable).call(alb, hgt, w, h)
	# grime, scuffs and vertical streaks
	var grime: float = o.get("grime", 0.8)
	var n1 := FastNoiseLite.new()
	n1.seed = int(o.get("seed", 1))
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.012
	var n2 := FastNoiseLite.new()
	n2.seed = int(o.get("seed", 1)) + 7
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.frequency = 0.09
	var i1 := n1.get_image(w, h)
	var i2 := n2.get_image(w, h)
	for y in h:
		for x in w:
			var g := clampf((i1.get_pixel(x, y).r - 0.45) * 1.7, 0.0, 1.0) * grime
			var s := clampf((i2.get_pixel(x, y).r - 0.64) * 3.0, 0.0, 1.0) * grime * 0.5
			var a := alb.get_pixel(x, y)
			var f := 1.0 - g * 0.4
			var c := Color(a.r * f, a.g * f, a.b * f).lerp(Color("#8d8d88"), s * 0.35)
			alb.set_pixel(x, y, c)
			var hv := hgt.get_pixel(x, y).r + (i2.get_pixel(x, y).r - 0.5) * 0.05 * grime
			hgt.set_pixel(x, y, Color(hv, hv, hv))
	var nrm := hgt.duplicate() as Image
	nrm.bump_map_to_normal_map(4.0)
	alb.generate_mipmaps()
	nrm.generate_mipmaps()
	var out := [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(nrm)]
	_tex[key] = out
	return out

## Capsule overlay: big octagonal window with a lens on the +Z flank, trapezoid and small black panels on the others.
static func _capsule_overlay(alb: Image, hgt: Image, w: int, h: int) -> void:
	var fw := float(w) / SIDES
	for f in SIDES:
		var cx: float = (f + 0.5) * fw
		var d := mini(f, SIDES - f)       # distance from the +Z face
		match d:
			0:
				var oct := PackedVector2Array([Vector2(cx - 0.24 * fw, 0.3 * h), Vector2(cx + 0.24 * fw, 0.3 * h), Vector2(cx + 0.46 * fw, 0.4 * h), Vector2(cx + 0.46 * fw, 0.62 * h), Vector2(cx + 0.24 * fw, 0.72 * h), Vector2(cx - 0.24 * fw, 0.72 * h), Vector2(cx - 0.46 * fw, 0.62 * h), Vector2(cx - 0.46 * fw, 0.4 * h)])
				_window(alb, hgt, oct)
				var cy := 0.51 * h
				for i in 3:
					var rad: float = [0.3, 0.24, 0.15][i] * fw
					var col: Color = [Color("#8b8f95"), Color("#1d2228"), Color("#313a44")][i]
					for y in range(int(cy - rad), int(cy + rad)):
						for x in range(int(cx - rad), int(cx + rad)):
							if Vector2(x - cx, y - cy).length() <= rad:
								alb.set_pixel(x, y, col)
								hgt.set_pixel(x, y, Color(0.8 if i == 0 else 0.3, 0.5, 0.5))
			1:
				_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.34 * fw, 0.32 * h), Vector2(cx + 0.34 * fw, 0.24 * h), Vector2(cx + 0.34 * fw, 0.74 * h), Vector2(cx - 0.34 * fw, 0.82 * h)]))
			2:
				_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.3 * fw, 0.12 * h), Vector2(cx + 0.3 * fw, 0.12 * h), Vector2(cx + 0.3 * fw, 0.42 * h), Vector2(cx - 0.3 * fw, 0.42 * h)]))
				_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.3 * fw, 0.62 * h), Vector2(cx + 0.3 * fw, 0.62 * h), Vector2(cx + 0.3 * fw, 0.86 * h), Vector2(cx - 0.3 * fw, 0.86 * h)]))
			3:
				_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.28 * fw, 0.1 * h), Vector2(cx + 0.28 * fw, 0.1 * h), Vector2(cx + 0.38 * fw, 0.7 * h), Vector2(cx - 0.38 * fw, 0.7 * h)]))
			4:
				_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.3 * fw, 0.3 * h), Vector2(cx + 0.3 * fw, 0.3 * h), Vector2(cx + 0.3 * fw, 0.55 * h), Vector2(cx - 0.3 * fw, 0.55 * h)]))
			5:
				_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.3 * fw, 0.52 * h), Vector2(cx + 0.3 * fw, 0.52 * h), Vector2(cx + 0.3 * fw, 0.84 * h), Vector2(cx - 0.3 * fw, 0.84 * h)]))
			_:
				_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.34 * fw, 0.24 * h), Vector2(cx + 0.34 * fw, 0.24 * h), Vector2(cx + 0.34 * fw, 0.66 * h), Vector2(cx - 0.34 * fw, 0.66 * h)]))

## Service-module overlay: dark rear compartments on the four flat faces.
static func _sm_overlay(alb: Image, hgt: Image, w: int, h: int) -> void:
	var fw := float(w) / SIDES
	for f in [0, 3, 6, 9]:
		var cx: float = (f + 0.5) * fw
		_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.3 * fw, 0.8 * h), Vector2(cx + 0.3 * fw, 0.8 * h), Vector2(cx + 0.3 * fw, 0.96 * h), Vector2(cx - 0.3 * fw, 0.96 * h)]))
	for f in [1, 4, 7, 10]:
		var cx: float = (f + 0.5) * fw
		_window(alb, hgt, PackedVector2Array([Vector2(cx - 0.28 * fw, 0.34 * h), Vector2(cx + 0.28 * fw, 0.34 * h), Vector2(cx + 0.28 * fw, 0.44 * h), Vector2(cx - 0.28 * fw, 0.44 * h)]))

static func _smat(key: String, w: int, h: int, o: Dictionary, metal := 0.35, rough := 0.5) -> StandardMaterial3D:
	var t: Array = _plates(key, w, h, o)
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

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

# ------------------------------------------------------------------ geometry
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	# front faces are clockwise; the cross product of a clockwise triangle points inward
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		var tu := uvb
		uvb = uvc
		uvc = tu
	st.set_smooth_group(-1)
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_smooth_group(-1)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_smooth_group(-1)
	st.set_uv(uvc)
	st.add_vertex(c)

## Flat-shaded N-sided frustum along X (front at +X). Face i is centred on angle i*step measured from +Z towards +Y;
## u covers one face per 1/N, v runs 0 (front) .. 1 (back).
static func _prism(parent: Node3D, r_front: float, r_back: float, length: float, sides: int, m: Material, pos: Vector3, caps := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := TAU / sides
	var xf := length * 0.5
	var xb := -length * 0.5
	for i in sides:
		var a0 := (i - 0.5) * step
		var a1 := (i + 0.5) * step
		var am := i * step
		var out := Vector3(0, sin(am), cos(am))
		var f0 := Vector3(xf, r_front * sin(a0), r_front * cos(a0))
		var f1 := Vector3(xf, r_front * sin(a1), r_front * cos(a1))
		var b0 := Vector3(xb, r_back * sin(a0), r_back * cos(a0))
		var b1 := Vector3(xb, r_back * sin(a1), r_back * cos(a1))
		var u0 := float(i) / sides
		var u1 := float(i + 1) / sides
		_tri(st, f0, f1, b1, out, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1))
		_tri(st, f0, b1, b0, out, Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1))
		if caps:
			_tri(st, Vector3(xf, 0, 0), f0, f1, Vector3.RIGHT, Vector2(u0, 0), Vector2(u0, 0), Vector2(u1, 0))
			_tri(st, Vector3(xb, 0, 0), b0, b1, Vector3.LEFT, Vector2(u0, 1), Vector2(u0, 1), Vector2(u1, 1))
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

## Triangular wedge: flush with the hull at the front (+X), rising to height h at the back. Local +Y is radial.
static func _wedge(parent: Node3D, length: float, h: float, width: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l2 := length * 0.5
	var w2 := width * 0.5
	var A := Vector3(l2, 0, w2)
	var B := Vector3(-l2, 0, w2)
	var C := Vector3(-l2, h, w2)
	var A2 := Vector3(l2, 0, -w2)
	var B2 := Vector3(-l2, 0, -w2)
	var C2 := Vector3(-l2, h, -w2)
	var uv := Vector2(0.5, 0.5)
	_tri(st, A, B, C, Vector3(0, 0, 1), uv, uv, uv)
	_tri(st, A2, B2, C2, Vector3(0, 0, -1), uv, uv, uv)
	_tri(st, B, B2, C2, Vector3(-1, 0, 0), uv, uv, uv)
	_tri(st, B, C2, C, Vector3(-1, 0, 0), uv, uv, uv)
	var sl := Vector3(h, length, 0).normalized()
	_tri(st, A, C, C2, sl, uv, uv, uv)
	_tri(st, A, C2, A2, sl, uv, uv, uv)
	_tri(st, A, A2, B2, Vector3.DOWN, uv, uv, uv)
	_tri(st, A, B2, B, Vector3.DOWN, uv, uv, uv)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	parent.add_child(mi)
	return mi

static func _strut(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var d := b - a
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = d.length()
	c.radial_segments = 6
	c.rings = 1
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = m
	n.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + b) * 0.5)
	parent.add_child(n)

## frame on a flat hull face: local +Y is the outward radial direction at angle a (from +Z towards +Y)
static func _radial(parent: Node3D, x: float, a: float, rad: float) -> Node3D:
	var n := Node3D.new()
	var b := Basis(Vector3.RIGHT, PI * 0.5 - a)
	n.transform = Transform3D(b, Vector3(x, rad * sin(a), rad * cos(a)))
	parent.add_child(n)
	return n

# ------------------------------------------------------------------ the model
## variant: "orion" or "discovery" (same hull, different plate layout and light colours)
static func build(variant := "orion") -> Node3D:
	var disc := variant == "discovery"
	var sd := 100 if disc else 0
	var root := Node3D.new()
	root.name = "Discovery_CV2" if disc else "Orion_CV2"
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var steel := _m(Color("#a4a9b0"), 0.85, 0.3)
	var dsteel := _m(Color("#5b5f66"), 0.8, 0.38)
	var black := _m(Color("#17181b"), 0.5, 0.45)
	var lamp := _m(Color("#ffb347") if disc else Color("#8fdcff"), 0.0, 0.3, 2.0)
	var warm := [Color("#e0dccf"), Color("#d3cfc2"), Color("#c7c3b7"), Color("#ebe7da"), Color("#bdb9ad")]

	# --- capsule
	var cap_mat := _smat("cap%d" % sd, 1152, 288, {"seed": 4 + sd, "cols": SIDES, "min_len": 110, "max_len": 300, "black_rate": 0.0, "grime": 0.8, "overlay": Callable(OrionCV2, "_capsule_overlay"), "tones": warm if disc else [Color("#dcdcd8"), Color("#cfcfca"), Color("#c3c3be"), Color("#e6e6e2"), Color("#b9b9b4")]})
	var cap := _prism(core, CAP_R_NOSE, CAP_R_BASE, CAP_L, SIDES, cap_mat, Vector3(CAP_L * 0.5, 0, 0))
	cap.name = "Capsule"
	# nose cap, dark lens and four lamps
	UnitModels.cylx(core, 0.12, 0.155, 0.09, steel, Vector3(CAP_L + 0.04, 0, 0), 24)
	UnitModels.cylx(core, 0.085, 0.1, 0.03, black, Vector3(CAP_L + 0.095, 0, 0), 24)
	UnitModels.ball(core, 0.07, _m(Color("#232c36"), 0.9, 0.12), Vector3(CAP_L + 0.1, 0, 0), Vector3(0.45, 1, 1))
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		UnitModels.ball(core, 0.016, lamp, Vector3(CAP_L - 0.02, 0.13 * sin(a), 0.13 * cos(a)))
	# separation ring, collar and ring
	UnitModels.cylx(core, CAP_R_BASE * 1.02, CAP_R_BASE * 1.02, 0.035, steel, Vector3(0.0, 0, 0), 36)
	var collar_mat := _smat("collar%d" % sd, 256, 128, {"seed": 17 + sd, "cols": SIDES, "min_len": 30, "max_len": 90, "black_rate": 0.45, "grime": 0.8, "tones": warm if disc else [Color("#dcdcd8"), Color("#cfcfca"), Color("#e6e6e2")]})
	_prism(core, COLLAR_R, COLLAR_R, COLLAR_L, SIDES, collar_mat, Vector3(-0.075, 0, 0))
	UnitModels.cylx(core, COLLAR_R * 1.06, COLLAR_R * 1.06, 0.03, steel, Vector3(SM_X0 + 0.015, 0, 0), 36)
	# hazard ticks and lamps just under the separation ring
	var haz := _m(Color("#e6c010"), 0.1, 0.55)
	for k in 4:
		var a := k * PI * 0.5
		var hp := _radial(core, -0.03, a, 0.405)
		UnitModels.box(hp, Vector3(0.05, 0.012, 0.07), haz, Vector3.ZERO)
		UnitModels.box(hp, Vector3(0.02, 0.014, 0.025), black, Vector3.ZERO)
	# small pods at the capsule shoulders
	for a in [PI * 0.25, PI * 1.25]:
		var pod := _radial(core, 0.08, a + 0.0, 0.42)
		UnitModels.box(pod, Vector3(0.06, 0.05, 0.06), dsteel, Vector3.ZERO)

	# --- service module
	var sm_mat := _smat("sm%d" % sd, 1024, 512, {"seed": 21 + sd, "cols": 36, "min_len": 70, "max_len": 300, "black_rate": 0.1, "grime": 0.95, "overlay": Callable(OrionCV2, "_sm_overlay"), "tones": warm if disc else [Color("#dcdcd8"), Color("#cfcfca"), Color("#c3c3be"), Color("#e6e6e2"), Color("#b9b9b4")]})
	var sm := _prism(core, SM_R0, SM_R1, SM_L, SIDES, sm_mat, Vector3(SM_X0 - SM_L * 0.5, 0, 0))
	sm.name = "ServiceModule"
	var tail := SM_X0 - SM_L
	# rear plate
	UnitModels.cylx(core, SM_R1 * 0.95, SM_R1 * 0.95, 0.04, dsteel, Vector3(tail - 0.02, 0, 0), 12)
	# four black compartments on the flat faces near the rear
	for k in 4:
		var a := k * PI * 0.5
		var bp := _radial(core, tail + 0.24, a, SM_R1 * cos(PI / SIDES) + 0.035)
		UnitModels.box(bp, Vector3(0.22, 0.05, 0.2), black, Vector3.ZERO)
		UnitModels.box(bp, Vector3(0.18, 0.01, 0.16), dsteel, Vector3(0, 0.028, 0))
	# four wedge fins on the diagonals
	var fin_mat := _m(Color("#d6d4cb") if disc else Color("#d3d4d4"), 0.35, 0.5)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var fp := _radial(core, tail + 0.3, a, SM_R1 * 0.98)
		_wedge(fp, 0.5, 0.17, 0.2, fin_mat)
		UnitModels.box(fp, Vector3(0.12, 0.1, 0.17), black, Vector3(-0.15, 0.13, 0))

	# --- engines: 2x2 bells on trusses
	var bell_mat := _m(Color("#9ea3aa"), 0.9, 0.3)
	var inner := _m(Color("#15161a"), 0.6, 0.4)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var by: float = sy * 0.165
			var bz: float = sz * 0.165
			var cx := tail - 0.1
			UnitModels.cylx(core, 0.05, 0.055, 0.11, steel, Vector3(cx, by, bz), 16)
			UnitModels.cylx(core, 0.034, 0.12, 0.28, bell_mat, Vector3(cx - 0.18, by, bz), 24)
			UnitModels.cylx(core, 0.125, 0.125, 0.018, steel, Vector3(cx - 0.32, by, bz), 24)
			UnitModels.cylx(core, 0.105, 0.105, 0.012, inner, Vector3(cx - 0.322, by, bz), 24)
			UnitModels.cylx(core, 0.07, 0.07, 0.01, _m(Color("#2b2e36"), 0.7, 0.4), Vector3(cx - 0.328, by, bz), 16)
			for t in 3:
				var ta := t * TAU / 3.0 + PI * 0.5
				var p0 := Vector3(tail - 0.04, by + sy * 0.045 + 0.06 * sin(ta), bz + sz * 0.045 + 0.06 * cos(ta))
				_strut(core, p0, Vector3(cx - 0.04, by + 0.03 * sin(ta), bz + 0.03 * cos(ta)), 0.007, dsteel)

	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
