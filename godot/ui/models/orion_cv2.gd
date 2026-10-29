## North America's CV-2 crew ships (Orion and Discovery), modelled on the faceted white-plate reference:
## a 12-sided tapering capsule with big black window panels and a lens, a collar with hazard ticks, a long 12-sided
## service module clad in staggered riveted plates with black access panels, four wedge fins on the diagonals and a
## 2x2 cluster of truss-mounted engine bells.  Nose points to +X.  Panels are generated textures (albedo + normal map).
## Not wired into the game yet; see tests/orion_preview.gd for renders.
class_name OrionCV2
extends RefCounted

const SIDES := 12          ## texture pattern columns around the hull
const HULL := 24           ## actual hull facets (smooth shaded, so it reads rounded)
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
	alb.fill(o.get("seam", Color("#25262a")))
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
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, sg := -1) -> void:
	# front faces are clockwise; the cross product of a clockwise triangle points inward
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		var tu := uvb
		uvb = uvc
		uvc = tu
	for v in [[a, uva], [b, uvb], [c, uvc]]:
		st.set_smooth_group(sg)
		st.set_uv(v[1])
		st.add_vertex(v[0])

static func _commit(st: SurfaceTool, parent: Node3D, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

## N-sided frustum along X (front at +X); smooth shaded when sides >= 16.  Face i is centred on angle i*step measured
## from +Z towards +Y.  u wraps once around, aligned so the 12-column texture pattern stays centred on +Z.
static func _prism(parent: Node3D, r_front: float, r_back: float, length: float, sides: int, m: Material, pos: Vector3, caps := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := TAU / sides
	var xf := length * 0.5
	var xb := -length * 0.5
	var sg := 0 if sides >= 16 else -1
	for i in sides:
		var a0 := (i - 0.5) * step
		var a1 := (i + 0.5) * step
		var out := Vector3(0, sin(i * step), cos(i * step))
		var f0 := Vector3(xf, r_front * sin(a0), r_front * cos(a0))
		var f1 := Vector3(xf, r_front * sin(a1), r_front * cos(a1))
		var b0 := Vector3(xb, r_back * sin(a0), r_back * cos(a0))
		var b1 := Vector3(xb, r_back * sin(a1), r_back * cos(a1))
		var u0 := (a0 + PI / SIDES) / TAU
		var u1 := (a1 + PI / SIDES) / TAU
		_tri(st, f0, f1, b1, out, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), sg)
		_tri(st, f0, b1, b0, out, Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1), sg)
		if caps:
			_tri(st, Vector3(xf, 0, 0), f0, f1, Vector3.RIGHT, Vector2(u0, 0), Vector2(u0, 0), Vector2(u1, 0), -1)
			_tri(st, Vector3(xb, 0, 0), b0, b1, Vector3.LEFT, Vector2(u0, 1), Vector2(u0, 1), Vector2(u1, 1), -1)
	return _commit(st, parent, m, pos)

## Surface of revolution about X. pts = [Vector2(x, radius)] from the front backwards; flip for inward-facing (inner bell wall).
static func _lathe(parent: Node3D, pts: Array, seg: int, m: Material, pos: Vector3, flip := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in pts.size() - 1:
		var p0: Vector2 = pts[j]
		var p1: Vector2 = pts[j + 1]
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var am := (a0 + a1) * 0.5
			var out := Vector3(0, sin(am), cos(am)) * (-1.0 if flip else 1.0)
			var v00 := Vector3(p0.x, p0.y * sin(a0), p0.y * cos(a0))
			var v01 := Vector3(p0.x, p0.y * sin(a1), p0.y * cos(a1))
			var v10 := Vector3(p1.x, p1.y * sin(a0), p1.y * cos(a0))
			var v11 := Vector3(p1.x, p1.y * sin(a1), p1.y * cos(a1))
			var uu0 := float(i) / seg
			var uu1 := float(i + 1) / seg
			var vv0 := float(j) / (pts.size() - 1)
			var vv1 := float(j + 1) / (pts.size() - 1)
			_tri(st, v00, v01, v11, out, Vector2(uu0, vv0), Vector2(uu1, vv0), Vector2(uu1, vv1), 0)
			_tri(st, v00, v11, v10, out, Vector2(uu0, vv0), Vector2(uu1, vv1), Vector2(uu0, vv1), 0)
	return _commit(st, parent, m, pos)

## Rounded box (superellipsoid): size is the full extent, k > 2 squarer.
static func _rbox(parent: Node3D, size: Vector3, m: Material, pos: Vector3, k := 5.0, res := 10) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for i in res + 1:
		var th := PI * float(i) / res - PI * 0.5        # latitude
		var row: Array = []
		for j in res * 2 + 1:
			var ph := TAU * float(j) / (res * 2)
			var ct := signf(cos(th)) * pow(absf(cos(th)), 2.0 / k)
			var st_ := signf(sin(th)) * pow(absf(sin(th)), 2.0 / k)
			var cp := signf(cos(ph)) * pow(absf(cos(ph)), 2.0 / k)
			var sp := signf(sin(ph)) * pow(absf(sin(ph)), 2.0 / k)
			row.append(Vector3(ct * cp * size.x * 0.5, st_ * size.y * 0.5, ct * sp * size.z * 0.5))
		grid.append(row)
	for i in res:
		for j in res * 2:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j + 1]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i + 1][j]
			var out := (a + b + c + d) * 0.25
			var uv := Vector2(0.5, 0.5)
			_tri(st, a, b, c, out, uv, uv, uv, 0)
			_tri(st, a, c, d, out, uv, uv, uv, 0)
	return _commit(st, parent, m, pos)

## Rounded wing: rises smoothly from the hull to height h at the back, narrowing in the front, with a domed cross-section.
## Local +Y is radial, +X forward.
static func _fin(parent: Node3D, length: float, h: float, width: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NT := 14
	var NS := 12
	var l2 := length * 0.5
	var rows: Array = []
	for i in NT + 5:
		var t: float
		var hh: float
		var ww: float
		var x: float
		if i <= NT:
			t = float(i) / NT
			x = l2 - t * length
			hh = h * pow(t, 1.15) + 0.004
			ww = width * 0.5 * (0.5 + 0.5 * smoothstep(0.0, 0.5, t))
		else:
			var k := float(i - NT) / 4.0
			x = -l2 - 0.05 * sin(k * PI * 0.5)
			hh = h * cos(k * PI * 0.5) + 0.004 * (1.0 - k)
			ww = width * 0.5 * cos(k * PI * 0.35)
		var row: Array = []
		for sj in NS + 1:
			var s := -1.0 + 2.0 * float(sj) / NS
			var dome := pow(maxf(1.0 - pow(absf(s), 3.0), 0.0), 1.0 / 3.0)
			row.append(Vector3(x, -0.03 + (hh + 0.03) * dome, s * ww))
		rows.append(row)
	for i in rows.size() - 1:
		for sj in NS:
			var a: Vector3 = rows[i][sj]
			var b: Vector3 = rows[i][sj + 1]
			var c: Vector3 = rows[i + 1][sj + 1]
			var d: Vector3 = rows[i + 1][sj]
			var out := Vector3(0.0, 1.0, 0.0) + Vector3(0, 0, (a.z + c.z) * 0.5 / maxf(width, 0.01)) * 1.5
			var uv := Vector2(0.5, 0.5)
			_tri(st, a, b, c, out, uv, uv, uv, 0)
			_tri(st, a, c, d, out, uv, uv, uv, 0)
	return _commit(st, parent, m)

static func _strut(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var d := b - a
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = d.length()
	c.radial_segments = 8
	c.rings = 1
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = m
	n.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + b) * 0.5)
	parent.add_child(n)

## a small RCS nozzle: flared cone, rim and dark throat, pointing along dir
static func _nozzle(parent: Node3D, pos: Vector3, dir: Vector3, scale: float, steel: Material, black: Material) -> void:
	var q := Basis(Quaternion(Vector3.UP, dir.normalized()))
	var c := CylinderMesh.new()
	c.top_radius = 0.03 * scale
	c.bottom_radius = 0.011 * scale
	c.height = 0.07 * scale
	c.radial_segments = 14
	c.rings = 1
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = black
	n.transform = Transform3D(q, pos + dir.normalized() * 0.035 * scale)
	parent.add_child(n)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.034 * scale
	rim.bottom_radius = 0.034 * scale
	rim.height = 0.008 * scale
	rim.radial_segments = 14
	var rn := MeshInstance3D.new()
	rn.mesh = rim
	rn.material_override = steel
	rn.transform = Transform3D(q, pos + dir.normalized() * 0.07 * scale)
	parent.add_child(rn)
	var th := CylinderMesh.new()
	th.top_radius = 0.022 * scale
	th.bottom_radius = 0.022 * scale
	th.height = 0.004 * scale
	th.radial_segments = 12
	var tn := MeshInstance3D.new()
	tn.mesh = th
	tn.material_override = _m(Color("#07080a"), 0.2, 0.6)
	tn.transform = Transform3D(q, pos + dir.normalized() * 0.071 * scale)
	parent.add_child(tn)

## A four-nozzle RCS cluster on a hull frame (+Y radial, +X axial, +Z tangent).
static func _cluster(parent: Node3D, steel: Material, dsteel: Material, black: Material, s := 1.0) -> void:
	_rbox(parent, Vector3(0.075, 0.045, 0.075) * s, dsteel, Vector3(0, 0.012 * s, 0), 4.0, 8)
	var base := Vector3(0, 0.025 * s, 0)
	for d in [Vector3(1, 0.25, 0), Vector3(-1, 0.25, 0), Vector3(0, 0.25, 1), Vector3(0, 0.25, -1)]:
		_nozzle(parent, base + (d as Vector3).normalized() * 0.03 * s, d, s, steel, black)
	_nozzle(parent, base + Vector3(0, 0.03, 0) * s, Vector3(0, 1, 0), 0.8 * s, steel, black)

## Louvred vent: dark recess with raised rounded slats. Faces +Y.
static func _vent(parent: Node3D, w: float, l: float, slats: int, steel: Material, black: Material) -> void:
	_rbox(parent, Vector3(l, 0.014, w), black, Vector3(0, 0.004, 0), 6.0, 6)
	for i in slats:
		var x := -l * 0.5 + l * (i + 0.5) / slats
		_rbox(parent, Vector3(l / slats * 0.5, 0.012, w * 0.86), steel, Vector3(x, 0.014, 0), 3.0, 6)

## frame on the hull at axial x, angle a and radius rad: +Y radial, +X axial, +Z tangent
static func _radial(parent: Node3D, x: float, a: float, rad: float) -> Node3D:
	var n := Node3D.new()
	var b := Basis(Vector3.RIGHT, PI * 0.5 - a)
	n.transform = Transform3D(b, Vector3(x, rad * sin(a), rad * cos(a)))
	parent.add_child(n)
	return n

## frame on the capsule cone (surface tilted towards the nose)
static func _on_cone(parent: Node3D, x: float, a: float) -> Node3D:
	var rr := lerpf(CAP_R_BASE, CAP_R_NOSE, x / CAP_L) * cos(PI / HULL)
	var f := _radial(parent, x, a, rr)
	var tilt := Node3D.new()
	tilt.basis = Basis(Vector3(0, 0, 1), -atan2(CAP_R_BASE - CAP_R_NOSE, CAP_L))
	f.add_child(tilt)
	return tilt

static func _sm_r(x: float) -> float:
	return lerpf(SM_R0, SM_R1, clampf((SM_X0 - x) / SM_L, 0.0, 1.0)) * cos(PI / HULL)

# ------------------------------------------------------------------ the model
## variant: "orion" or "discovery" (same hull, different plate layout and lamp colours)
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
	var copper := _m(Color("#b9794a"), 0.85, 0.35)
	var warm := [Color("#e0dccf"), Color("#d3cfc2"), Color("#c7c3b7"), Color("#ebe7da"), Color("#bdb9ad")]
	var cool := [Color("#dcdcd8"), Color("#cfcfca"), Color("#c3c3be"), Color("#e6e6e2"), Color("#b9b9b4")]

	# --- capsule (smooth 24-facet cone)
	var cap_mat := _smat("cap%d" % sd, 1152, 288, {"seed": 4 + sd, "cols": SIDES, "min_len": 110, "max_len": 300, "black_rate": 0.0, "grime": 0.8, "overlay": Callable(OrionCV2, "_capsule_overlay"), "tones": warm if disc else cool})
	var cap := _prism(core, CAP_R_NOSE, CAP_R_BASE, CAP_L, HULL, cap_mat, Vector3(CAP_L * 0.5, 0, 0))
	cap.name = "Capsule"
	# rounded nose cap, dark lens and four lamps
	UnitModels.cylx(core, 0.12, 0.155, 0.09, steel, Vector3(CAP_L + 0.04, 0, 0), 32)
	UnitModels.ring(core, 0.135, 0.165, steel, Vector3(CAP_L - 0.005, 0, 0), Vector3(0, 0, PI / 2))
	UnitModels.ball(core, 0.095, _m(Color("#232c36"), 0.9, 0.12), Vector3(CAP_L + 0.085, 0, 0), Vector3(0.5, 1, 1))
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		UnitModels.ball(core, 0.018, lamp, Vector3(CAP_L - 0.035, 0.135 * sin(a), 0.135 * cos(a)))
	# separation ring, collar and ring (rounded torus rails)
	UnitModels.ring(core, CAP_R_BASE + 0.01, CAP_R_BASE + 0.035, steel, Vector3(0.0, 0, 0), Vector3(0, 0, PI / 2))
	var collar_mat := _smat("collar%d" % sd, 256, 128, {"seed": 17 + sd, "cols": SIDES, "min_len": 30, "max_len": 90, "black_rate": 0.45, "grime": 0.8, "tones": warm if disc else cool})
	_prism(core, COLLAR_R, COLLAR_R, COLLAR_L, HULL, collar_mat, Vector3(-0.075, 0, 0))
	UnitModels.ring(core, COLLAR_R + 0.02, COLLAR_R + 0.045, steel, Vector3(SM_X0 + 0.01, 0, 0), Vector3(0, 0, PI / 2))
	# hazard ticks under the separation ring
	var haz := _m(Color("#e6c010"), 0.1, 0.55)
	for k in 4:
		var hp := _radial(core, -0.03, k * PI * 0.5, 0.395)
		_rbox(hp, Vector3(0.05, 0.014, 0.07), haz, Vector3.ZERO, 4.0, 6)
		_rbox(hp, Vector3(0.02, 0.016, 0.025), black, Vector3.ZERO, 4.0, 6)
	# capsule RCS clusters and louvred vents
	for k in 4:
		var cf := _on_cone(core, 0.15, PI * 0.25 + k * PI * 0.5)
		_cluster(cf, steel, dsteel, black, 0.85)
	for k in 4:
		var vf := _on_cone(core, 0.27, PI * 0.25 + k * PI * 0.5 + 0.38)
		_vent(vf, 0.06, 0.11, 5, steel, black)

	# --- service module (smooth 24-facet drum)
	var sm_mat := _smat("sm%d" % sd, 1024, 512, {"seed": 21 + sd, "cols": 36, "min_len": 70, "max_len": 300, "black_rate": 0.1, "grime": 0.95, "overlay": Callable(OrionCV2, "_sm_overlay"), "tones": warm if disc else cool})
	var sm := _prism(core, SM_R0, SM_R1, SM_L, HULL, sm_mat, Vector3(SM_X0 - SM_L * 0.5, 0, 0))
	sm.name = "ServiceModule"
	var tail := SM_X0 - SM_L
	UnitModels.ring(core, SM_R1 * 0.9, SM_R1 * 1.02, dsteel, Vector3(tail, 0, 0), Vector3(0, 0, PI / 2))
	UnitModels.cylx(core, SM_R1 * 0.95, SM_R1 * 0.95, 0.04, dsteel, Vector3(tail - 0.02, 0, 0), 24)
	# vents, thruster clusters and black compartments
	for k in 4:
		var a := k * PI * 0.5
		var cl := _radial(core, SM_X0 - 0.3, a, _sm_r(SM_X0 - 0.3))
		_cluster(cl, steel, dsteel, black, 1.0)
		var vv := _radial(core, SM_X0 - 0.62, a, _sm_r(SM_X0 - 0.62))
		_vent(vv, 0.16, 0.26, 8, steel, black)
		var vd := _radial(core, SM_X0 - 0.5, a + PI * 0.25, _sm_r(SM_X0 - 0.5))
		_vent(vd, 0.1, 0.2, 6, steel, black)
		var bp := _radial(core, tail + 0.24, a, _sm_r(tail + 0.24) + 0.012)
		_rbox(bp, Vector3(0.22, 0.05, 0.2), black, Vector3.ZERO, 4.5, 8)
		_rbox(bp, Vector3(0.18, 0.012, 0.16), dsteel, Vector3(0, 0.022, 0), 4.5, 8)
		var rc := _radial(core, tail + 0.62, a + PI * 0.25, _sm_r(tail + 0.62))
		_cluster(rc, steel, dsteel, black, 0.8)
	# four rounded wing fins on the diagonals
	var fin_mat := _m(Color("#d6d4cb") if disc else Color("#d3d4d4"), 0.35, 0.5)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var fp := _radial(core, tail + 0.3, a, SM_R1 * 0.97)
		_fin(fp, 0.5, 0.17, 0.2, fin_mat)
		_rbox(fp, Vector3(0.12, 0.09, 0.15), black, Vector3(-0.15, 0.12, 0), 4.0, 8)

	# --- engines: 2x2 ribbed bells on trusses with plumbing
	var bell_mat := _m(Color("#9ea3aa"), 0.9, 0.3)
	var rib_mat := _m(Color("#7c8189"), 0.9, 0.35)
	var inner := _m(Color("#101114"), 0.7, 0.3)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var by: float = sy * 0.165
			var bz: float = sz * 0.165
			var cx := tail - 0.1
			var bpos := Vector3(cx, by, bz)
			# gimbal housing, chamber and turbopump bulb
			_rbox(core, Vector3(0.12, 0.11, 0.11), dsteel, bpos + Vector3(0.0, 0, 0), 3.5, 8)
			UnitModels.cylx(core, 0.045, 0.058, 0.1, steel, bpos + Vector3(-0.07, 0, 0), 20)
			UnitModels.ring(core, 0.045, 0.062, steel, bpos + Vector3(-0.015, 0, 0), Vector3(0, 0, PI / 2))
			UnitModels.ball(core, 0.034, copper, bpos + Vector3(-0.02, sy * 0.05, sz * 0.05))
			# bell: parabolic flare as a lathe, dark inside
			var prof: Array = []
			var inprof: Array = []
			var n := 14
			for i in n + 1:
				var t := float(i) / n
				var xx := -0.12 - t * 0.28
				var rr := 0.036 + 0.092 * pow(t, 0.62)
				prof.append(Vector2(xx, rr))
				inprof.append(Vector2(xx, rr - 0.008))
			_lathe(core, prof, 28, bell_mat, bpos)
			_lathe(core, inprof, 28, inner, bpos, true)
			# stiffening ribs: rings stepping down the bell, thicker every third
			for i in 9:
				var t := 0.12 + i * 0.105
				var xx := -0.12 - t * 0.28
				var rr := 0.036 + 0.092 * pow(t, 0.62) + 0.004
				UnitModels.ring(core, rr - 0.002, rr + (0.011 if i % 3 == 0 else 0.007), rib_mat, bpos + Vector3(xx, 0, 0), Vector3(0, 0, PI / 2))
			# longitudinal ribs
			for q in 8:
				var qa := q * TAU / 8.0
				var p0 := Vector3(-0.15, 0.04 * sin(qa), 0.04 * cos(qa)) + bpos
				var t1 := 0.97
				var r1 := 0.036 + 0.092 * pow(t1, 0.62) + 0.004
				var p1 := Vector3(-0.12 - t1 * 0.28, r1 * sin(qa), r1 * cos(qa)) + bpos
				_strut(core, p0, p1, 0.0035, rib_mat)
			UnitModels.ring(core, 0.122, 0.141, steel, bpos + Vector3(-0.4, 0, 0), Vector3(0, 0, PI / 2))
			# trusses and fuel lines up to the rear plate
			for t in 3:
				var ta := t * TAU / 3.0 + PI * 0.5
				var p0 := Vector3(tail - 0.045, by + sy * 0.05 + 0.065 * sin(ta), bz + sz * 0.05 + 0.065 * cos(ta))
				_strut(core, p0, Vector3(cx - 0.05, by + 0.035 * sin(ta), bz + 0.035 * cos(ta)), 0.009, dsteel)
			var pl := Vector3(tail - 0.04, by * 0.55, bz * 0.55)
			_strut(core, pl, bpos + Vector3(-0.02, sy * 0.05, sz * 0.05), 0.011, copper)
			_strut(core, pl + Vector3(0, sy * 0.012, 0), bpos + Vector3(-0.06, sy * 0.045, -sz * 0.03), 0.007, steel)
	# cross braces tying the bell cluster together
	UnitModels.ring(core, 0.26, 0.275, dsteel, Vector3(tail - 0.13, 0, 0), Vector3(0, 0, PI / 2))

	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
