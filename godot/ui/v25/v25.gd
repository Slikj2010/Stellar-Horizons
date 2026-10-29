## The 2.5D view: a line-by-line port of the web version's view25.js.
## It draws the same game state as the flat map (the counters, cards and highlights are recorded from the flat board's
## paint calls), with a tilted perspective camera, a starfield, the systems as glass plates round the Sun, holographic
## transfer and flyby boxes, digital world boxes, spinning planets, ray-marched rocks and hovering counters.
## As in WebGL, everything is drawn in painter's order without a depth test: each draw call is a MeshInstance3D whose
## sorting offset keeps the order. Picking, panning, zooming and turning work like the web version's.
extends Node3D

const FOV := 0.72
const NEAR := 20.0
const FAR := 90000.0
const WHITE := Color(1.000, 0.816, 0.839, 1)
const PAL := {"box": {"top": Color(.03, .11, .19, .84), "rim": Color(.35, .85, 1, .95), "side": [.25, .7, .9], "gc": "#59d5ff"},
	"fly": {"top": Color(.13, .08, .03, .66), "rim": Color(1, .72, .28, .95), "side": [.95, .6, .22], "gc": "#ffb347"}}
## Earth and Mercury print an irregular flyby outline; they get the same slanted long box as the rest
const FLYQ := {"ear": [[2921, 428], [3043, 428], [2875, 754], [2807, 616]], "mer": [[622, 1032], [744, 1032], [576, 1358], [508, 1220]]}
const TRW := 380.0
const TRH := 251.0
const PWS := 260.0
const PHS := 143.0

var on := false
var main: Node
var board: Node2D
var paint: V25Paint
var _sky_ok := false
var C := {"tx": 1500.0, "tz": 900.0, "yaw": 0.0, "pitch": .98, "dist": 2400.0}
var cam: Camera3D
var eye := Vector3.ZERO
var fwd := Vector3(0, 0, -1)
var rgt := Vector3(1, 0, 0)
var cup := Vector3(0, 1, 0)
var W := 1.0
var H := 1.0
var OX := 0.0  ## the stage (the part of the window the map shows in: below the top bar, left of the side panel)
var OY := 0.0
var LAY: V25Layout = null
var ASM = null
var BOXL = null
var BOXSH := {}
var sunRing = null
var bodies: Dictionary
var sunJ: Dictionary
var T := 0.0
var picks: Array = []
var rec: Array = []
var gfx: Array = []
var mode := "flat"
var lift := 0.0

var _calls: Array = []
var _pool: Array = []  ## MeshInstance3D
var _dyn: Array = []  ## ArrayMesh per pool slot
var _mats := {}  ## kind -> Array of ShaderMaterial
var _sh := {}
var _static := {}  ## cached ArrayMeshes
var _tex := {}
var _mroot: Node3D
var _mpool := {}  ## "f|img" -> Array of {h: holder Node3D, m: model, flag: Node3D}
var _mused: Array = []
var _mcount := {}

# ---------------- vertex builder (the web version's 11-float vertices) ----------------
class VB:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var q := PackedVector2Array()
	var c := PackedColorArray()
	func pv(x: float, y: float, z: float, u: float, vv: float, qx: float, qy: float, col: Color) -> void:
		v.append(Vector3(x, y, z)); uv.append(Vector2(u, vv)); q.append(Vector2(qx, qy)); c.append(col)
	func size() -> int: return v.size()
	func add(o: VB) -> void:
		v.append_array(o.v); uv.append_array(o.uv); q.append_array(o.q); c.append_array(o.c)
	func mesh(prim := Mesh.PRIMITIVE_TRIANGLES, into: ArrayMesh = null) -> ArrayMesh:
		var m := into if into != null else ArrayMesh.new()
		m.clear_surfaces()
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = q
		a[Mesh.ARRAY_COLOR] = c
		m.add_surface_from_arrays(prim, a)
		return m

static var _QQ6 := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
## P: four corners TL, TR, BR, BL (Vector3); uv: [u0, v0, u1, v1]
func quad(a: VB, P: Array, uv: Array, c: Color) -> void:
	var p0: Vector3 = P[0]
	var p2: Vector3 = P[2]
	a.v.append_array(PackedVector3Array([p0, P[1], p2, p0, p2, P[3]]))
	if uv == UV1: a.uv.append_array(_QQ6)
	else:
		var u0 := Vector2(uv[0], uv[1])
		var u2 := Vector2(uv[2], uv[3])
		a.uv.append_array(PackedVector2Array([u0, Vector2(uv[2], uv[1]), u2, u0, u2, Vector2(uv[0], uv[3])]))
	a.q.append_array(_QQ6)
	a.c.append_array(PackedColorArray([c, c, c, c, c, c]))
func flatQuad(a: VB, x: float, y: float, w: float, h: float, ang: float, yy: float, uv: Array, c: Color) -> void:
	var hw := w / 2
	var hh := h / 2
	if ang == 0.0:
		quad(a, [Vector3(x - hw, yy, y - hh), Vector3(x + hw, yy, y - hh), Vector3(x + hw, yy, y + hh), Vector3(x - hw, yy, y + hh)], uv, c)
		return
	var co := cos(ang)
	var si := sin(ang)
	quad(a, [Vector3(x - hw * co + hh * si, yy, y - hw * si - hh * co), Vector3(x + hw * co + hh * si, yy, y + hw * si - hh * co), Vector3(x + hw * co - hh * si, yy, y + hw * si + hh * co), Vector3(x - hw * co - hh * si, yy, y - hw * si + hh * co)], uv, c)
const UV1 := [0, 0, 1, 1]
## pts: Array of Vector2 (scene x, z)
func ribbon(a: VB, pts: Array, closed: bool, w: float, yy: float, c: Color) -> void:
	var n := pts.size()
	var m := n if closed else n - 1
	for i in m:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % n]
		var d := p1 - p0
		var l := d.length()
		if l == 0: l = 1
		var nx := -d.y / l * w / 2
		var ny := d.x / l * w / 2
		quad(a, [Vector3(p0.x + nx, yy, p0.y + ny), Vector3(p1.x + nx, yy, p1.y + ny), Vector3(p1.x - nx, yy, p1.y - ny), Vector3(p0.x - nx, yy, p0.y - ny)], UV1, c)
		if closed or i > 0:
			var r := w * .5
			flatQuad(a, p0.x, p0.y, r * 1.4, r * 1.4, 0, yy, UV1, c)
static func earclip(P: Array) -> Array:
	var n := P.size()
	if n < 3: return []
	var area := 0.0
	for i in n:
		var a: Vector2 = P[i]
		var b: Vector2 = P[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var idx := range(n)
	if area < 0: idx.reverse()
	var out := []
	var cr := func(a: Vector2, b: Vector2, c: Vector2) -> float: return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
	var guard := n * n
	while idx.size() > 3 and guard > 0:
		guard -= 1
		var cut := false
		for i in idx.size():
			var i0: int = idx[(i + idx.size() - 1) % idx.size()]
			var i1: int = idx[i]
			var i2: int = idx[(i + 1) % idx.size()]
			var a: Vector2 = P[i0]
			var b: Vector2 = P[i1]
			var c: Vector2 = P[i2]
			if cr.call(a, b, c) <= 0: continue
			var inside := false
			for j in idx:
				if j != i0 and j != i1 and j != i2:
					var p: Vector2 = P[j]
					if cr.call(a, b, p) >= 0 and cr.call(b, c, p) >= 0 and cr.call(c, a, p) >= 0:
						inside = true
						break
			if inside: continue
			out.append_array([i0, i1, i2])
			idx.remove_at(i)
			cut = true
			break
		if not cut: break
	if idx.size() == 3: out.append_array([idx[0], idx[1], idx[2]])
	return out
func fillPoly(a: VB, pts: Array, yy: float, c: Color) -> void:
	var t := earclip(pts)
	for i in t:
		var p: Vector2 = pts[i]
		a.pv(p.x, yy, p.y, 0, 0, 0, 0, c)
static func circlePts(cx: float, cy: float, r: float, n := 48) -> Array:
	var out := []
	for i in n: out.append(Vector2(cx + cos(i / float(n) * 6.2832) * r, cy + sin(i / float(n) * 6.2832) * r))
	return out
static func col(c) -> Color:
	if c is Color: return c
	if c is Array: return Color(c[0], c[1], c[2], c[3] if c.size() > 3 else 1.0)
	return V25Paint.css(c)
static func rgba(c: Array, a: float) -> Color: return Color(c[0], c[1], c[2], a)

# ---------------- setup ----------------
func setup(m: Node) -> void:
	main = m
	board = m.board
	paint = V25Paint.new()
	add_child(paint)
	bodies = board._json("res://assets/bodies.json")
	sunJ = board._json("res://data/sun.json")
	_sh.q = load("res://ui/v25/v25_quad.gdshader")
	_sh.p = load("res://ui/v25/v25_planet.gdshader")
	_sh.r = load("res://ui/v25/v25_rock.gdshader")
	_sh.pt = load("res://ui/v25/v25_points.gdshader")
	_sh.g = load("res://ui/v25/v25_ring.gdshader")
	Game.changed.connect(touch)
	for k in ["bodies", "galaxies", "nebulae", "deep_bg", "neb_wash", "andromeda"]:
		_tex[k] = load("res://assets/bodies.png" if k == "bodies" else "res://assets/v25/%s.png" % k)
	cam = Camera3D.new()
	cam.fov = rad_to_deg(FOV)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = NEAR
	cam.far = FAR
	add_child(cam)
	var env := Environment.new()
	# the sky is a panorama of the galaxy (tools/make_sky.py), wrapped round the scene: stars stay sharp at any zoom
	var sky_tex: Texture2D = load("res://assets/sky_pano.png")
	_sky_ok = sky_tex != null
	if sky_tex != null:
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = sky_tex
		var sky := Sky.new()
		sky.sky_material = pm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.sky_rotation = Vector3(0, 0, PI / 2)  # the panorama's poles lie on the horizon, where the camera rarely looks
		env.background_energy_multiplier = 0.55
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(.008, .014, .03)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.62, .68, .82)
	env.ambient_light_energy = 1.1
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-.9, .6, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = false
	add_child(sun)
	_mroot = Node3D.new()
	add_child(_mroot)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	visible = false
	_build_sky()

func _build_sky() -> void:
	# stars on a distant shell all around; the belts and the sky are built in ensure()
	pass

func enable(v: bool) -> void:
	if v == on: return
	on = v
	visible = v
	if v:
		ensure()
		board.v25 = self
		cam.make_current()
	else:
		board.v25 = null
		cam.clear_current(false)
		main.cam.make_current()
		for mi in _pool: mi.visible = false
		for h in _mused: h.visible = false
		_mused = []
	board.reset_rings()
	board.queue_redraw()

# ---------------- camera ----------------
func setupCam() -> void:
	var cp := cos(C.pitch)
	var sp := sin(C.pitch)
	eye = Vector3(C.tx + C.dist * cp * sin(C.yaw), C.dist * sp, C.tz + C.dist * cp * cos(C.yaw))
	var z := (eye - Vector3(C.tx, 0, C.tz)).normalized()
	rgt = Vector3.UP.cross(z).normalized()
	cup = z.cross(rgt)
	fwd = -z
	cam.transform = Transform3D(Basis(rgt, cup, z), eye)
	var vs := get_viewport().get_visible_rect().size
	var st: Rect2 = main.stage_rect()
	OX = st.position.x
	OY = st.position.y
	W = maxf(1, st.size.x)
	H = maxf(1, st.size.y)
	# the window shows more than the stage: an off-centre frustum keeps the stage framed as in the web version
	var k := (H / 2.0) / (NEAR * tan(FOV / 2.0))
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.size = vs.y / k
	cam.frustum_offset = Vector2((vs.x / 2.0 - (OX + W / 2.0)) / k, ((OY + H / 2.0) - vs.y / 2.0) / k)

## a scene point on screen: [sx, sy, w] or null when it is behind the camera
func proj(x: float, y: float, z: float):
	var d := Vector3(x, y, z) - eye
	var cw := d.dot(fwd)
	if cw <= 0: return null
	var f := 1.0 / tan(FOV / 2.0)
	var a := W / H
	var nx := f / a * d.dot(rgt) / cw
	var ny := f * d.dot(cup) / cw
	return [OX + (nx * .5 + .5) * W, OY + (1 - (ny * .5 + .5)) * H, cw]
func ray(sx: float, sy: float) -> Vector3:
	sx -= OX
	sy -= OY
	var t := tan(FOV / 2.0)
	var nx := sx / W * 2 - 1
	var ny := 1 - sy / H * 2
	var a := W / H
	return (fwd + rgt * nx * t * a + cup * ny * t).normalized()
## the ground point (scene x, z) under a screen point, or null
func ground(sx: float, sy: float, h := 0.0):
	var d := ray(sx, sy)
	if d.y > -1e-4: return null
	var s := (h - eye.y) / d.y
	return Vector2(eye.x + d.x * s, eye.z + d.z * s)
func pxw(d: float) -> float: return 2 * d * tan(FOV / 2.0) / H

func clampCam() -> void:
	C.pitch = clampf(C.pitch, .3, 1.35)
	C.dist = clampf(C.dist, 120, 60000)
	C.tx = clampf(C.tx, -22000, 22000)
	C.tz = clampf(C.tz, -22000, 22000)
func zoom(f: float) -> void:
	C.dist /= f
	clampCam()
func rotate_by(dy: float, dp: float) -> void:
	C.yaw += dy
	C.pitch += dp
	clampCam()
func sheetToScene(p: Vector2) -> Vector2:
	ensure()
	var q := LAY.toL(p.x, p.y)
	return Vector2(q[0], q[1])
func focus(p: Vector2, s := 0.0) -> void:
	var q := sheetToScene(p)
	C.tx = q.x
	C.tz = q.y
	if s > 0: C.dist = maxf(250, 900 / maxf(.3, s))
	clampCam()
func focusPod(k: String) -> void:
	ensure()
	var p = LAY.pods.get(k)
	if p == null: return
	var r: Array = p.rect
	C.tx = (r[0] + r[2]) / 2
	C.tz = (r[1] + r[3]) / 2
	C.dist = maxf(r[2] - r[0], r[3] - r[1]) * 1.35
	C.pitch = maxf(C.pitch, .9)
	clampCam()
func fit() -> void:
	C.tx = 0; C.tz = 400; C.dist = 40000; C.yaw = 0; C.pitch = 1.0
	clampCam()
func home(p: Vector2) -> void:
	var q := sheetToScene(p)
	C.tx = q.x; C.tz = q.y + 60; C.dist = 1500; C.pitch = .98; C.yaw = 0
	clampCam()
func panBy(p0, sx: float, sy: float) -> void:
	var p1 = ground(sx, sy, 0)
	if p1 == null or p0 == null: return
	C.tx += p0.x - p1.x
	C.tz += p0.y - p1.y
	clampCam()

# ---------------- recording (called by the flat board while the 2.5D view is on) ----------------
func begin() -> void:
	rec = []
	gfx = []
	mode = "flat"
	lift = 0
func sprite(tex: Texture2D, f, x: float, y: float, size: float, a := 0.0) -> void:
	if f == null or tex == null: return
	var k: float = size / maxf(f[2], f[3])
	rec.append({"tex": tex, "f": f, "x": x, "y": y, "w": f[2] * k, "h": f[3] * k, "a": a, "mode": mode, "lift": lift, "text": false})
## a ship counter drawn as its 3D model (f = faction, img = "Kind|Name", col = faction colour for the flag)
func model(f: String, img: String, x: float, y: float, size: float, col: String, small := false, face := 1) -> void:
	rec.append({"tex": null, "f": [0, 0, 1, 1], "x": x, "y": y, "w": size, "h": size, "a": 0.0, "mode": mode, "lift": lift, "text": false, "model": true, "mf": f, "img": img, "col": col, "small": small, "face": face})
func text(t: String, x: float, y: float, size: float, color: String, align := "center") -> void:
	var e := paint.text_sprite(t, color, size)
	var off: float = e.sw / 2 if align == "left" else (-e.sw / 2 if align == "right" else 0.0)
	rec.append({"tex": paint.atlas_tex(), "f": [e.x, e.y, e.w, e.h], "tw": V25Paint.AT, "th": V25Paint.AT, "x": x + off, "y": y, "w": e.sw, "h": e.sh, "a": 0.0, "mode": mode, "lift": lift + (18 if mode == "stand" else 0), "text": true})
func ring(x: float, y: float, r: float, color, w := 3.0) -> void: gfx.append({"k": "ring", "x": x, "y": y, "r": r, "color": color, "w": w})
func poly(pts: Array, color, w := 3.0, fill = null) -> void: gfx.append({"k": "poly", "pts": pts, "color": color, "w": w, "fill": fill})
func box(x: float, y: float, s: float, a: float, color, w := 3.0) -> void:
	var h := s / 2
	var c := cos(a)
	var sn := sin(a)
	var pts := []
	for uv in [[-h, -h], [h, -h], [h, h], [-h, h]]: pts.append([x + uv[0] * c - uv[1] * sn, y + uv[0] * sn + uv[1] * c])
	poly(pts, color, w)
## match standing sprites to the flat painter's hit list (so a tap selects the same thing as in the flat view)
func finish(hits_list: Array) -> void:
	for r in rec:
		if r.mode != "stand" or r.text: continue
		r.hit = null
		for i in range(hits_list.size() - 1, -1, -1):
			var h: Dictionary = hits_list[i]
			if (h.t == "ship" or h.t == "oship") and absf(h.c.x - r.x) < 1.5 and absf(h.c.y - r.y) < 1.5:
				r.hit = h
				break

# ---------------- the shared layout ----------------
func podOfW(k: String):
	var p = LAY.pods.get(k)
	if p != null: return p
	var w = Game.data.D.W.get(k)
	return LAY.pods.get(w.sys) if w != null else null
func mapP(x: float, y: float, pod = null) -> Vector2:
	var q := LAY.toL(x, y, pod)
	return Vector2(q[0], q[1])
func ringOf(k: String) -> Dictionary: return board.ring_of(k)

func ensure() -> void:
	if LAY != null: return
	if board.flat_on:  # built on the printed sheet's geometry, never the flat winding layout
		board.set_layout(false)
		ensure()
		board.set_layout(true)
		return
	var m: Array = board.geo_std.maps[sunJ.map]
	var sc := [m[0] + sunJ.cx * .4, m[1] + sunJ.cy * .4]
	var _t0 := Time.get_ticks_msec()
	LAY = V25Layout.new()
	LAY.build(board.geo_std, Game.data.D, sc)
	if OS.get_cmdline_user_args().has("--timing"): print("TIMING layout ", Time.get_ticks_msec() - _t0)
	sunRing = {"c": Vector2(sc[0], sc[1]), "r": LAY.sunR * 1.12 / LAY.S}
	board.v25_ring = sunRing
	board.reset_rings()
	ASM = placeAsm(LAY.S)
	if OS.get_cmdline_user_args().has("--timing"): print("TIMING asm ", Time.get_ticks_msec() - _t0)
	# belts: particle rings (gaps cut out where a pod sits on the ring)
	var r := Mulb.new(4242)
	for b in LAY.BELTS:
		var pod = LAY.pods.get(b.k)
		var rc = pod.rect if pod != null else null
		var vb := VB.new()
		for i in b.n:
			var g := (r.next() + r.next() + r.next()) / 3.0
			var rad: float = b.r0 + (b.r1 - b.r0) * g
			var an := r.next() * 6.2832
			var x := cos(an) * rad
			var z := sin(an) * rad
			if rc != null and x > rc[0] - 60 and x < rc[2] + 60 and z > rc[1] - 60 and z < rc[3] + 60: continue
			var sh := .55 + r.next() * .45
			var big := r.next() < .06
			vb.pv(x, (r.next() - .5) * (b.r1 - b.r0) * .08, z, 0, 0, 0, 0, Color(b.col[0] * sh, b.col[1] * sh, b.col[2] * sh, .95 if big else .7 * sh + .2))
		_static["belt_" + b.k] = vb.mesh(Mesh.PRIMITIVE_POINTS)
	if OS.get_cmdline_user_args().has("--timing"): print("TIMING belts ", Time.get_ticks_msec() - _t0)
	# sky: stars on a distant shell all around
	var sp := VB.new()
	for i in 3200:
		var u := r.next() * 2 - 1
		var a := r.next() * 6.2832
		var s := sqrt(1 - u * u)
		var R := 52000 + r.next() * 8000
		var h := r.next()
		sp.pv(cos(a) * s * R, u * R, sin(a) * s * R, 0, 0, 0, 0, Color(.7 if h < .12 else 1.0, .8 if h < .12 else (.75 if h > .88 else 1.0), 1.0 if h < .12 else (.6 if h > .88 else 1.0), .3 + r.next() * .7))
	_static.sky = sp.mesh(Mesh.PRIMITIVE_POINTS)

## the web version's mulberry32 random numbers
class Mulb:
	var a := 0
	func _init(seed: int) -> void: a = seed
	static func i32(x: int) -> int:
		x = x & 0xFFFFFFFF
		return x - 0x100000000 if x >= 0x80000000 else x
	static func imul(x: int, y: int) -> int: return i32((x & 0xFFFFFFFF) * (y & 0xFFFFFFFF))
	static func ushr(x: int, n: int) -> int: return (x & 0xFFFFFFFF) >> n
	func next() -> float:
		a = i32(a + 0x6D2B79F5)
		var t := imul(a ^ ushr(a, 15), 1 | a)
		t = i32(i32(t + imul(t ^ ushr(t, 7), 61 | t)) ^ t)
		return float((t ^ ushr(t, 14)) & 0xFFFFFFFF) / 4294967296.0

# ---------------- transfer and flyby boxes ----------------
func boxPolys() -> Array:
	var out := []
	for k in board.geo_std.sys:
		var sy: Dictionary = board.geo_std.sys[k]
		for n in sy.boxPoly: out.append({"k": k, "n": n, "id": "box:" + k + ":" + n, "pts": sy.boxPoly[n], "fly": false})
		var fp: Array = FLYQ[k] if FLYQ.has(k) else Array(board.hull(sy.flybyPoly)).map(func(v): return [v.x, v.y])
		out.append({"k": k, "n": "fly", "id": "fly:" + k, "pts": fp, "fly": true})
	return out
static func polyArea(p: Array) -> float:
	var a := 0.0
	for i in p.size():
		var q: Vector2 = p[i]
		var r: Vector2 = p[(i + 1) % p.size()]
		a += q.x * r.y - r.x * q.y
	return absf(a / 2)
static func cen2(p: Array) -> Vector2:
	var s := Vector2.ZERO
	for q in p: s += q
	return s / p.size()
func computeBoxes() -> Array:
	if BOXL != null: return BOXL
	var lst := []
	for B in boxPolys():
		var pod = LAY.pods.get(B.k)
		if pod == null: continue
		var pts := []
		for q in B.pts: pts.append(mapP(q[0], q[1], pod))
		lst.append({"B": B, "pod": pod, "pts": pts, "c": cen2(pts), "s": sqrt(polyArea(pts))})
	BOXSH = {}
	for it in lst:
		var B: Dictionary = it.B
		var hub := Vector2(it.pod.org[0], it.pod.org[1])
		var c: Vector2 = it.c
		var toHub := atan2(hub.y - c.y, hub.x - c.x)
		var shape: Array
		var cs: float
		if not B.fly:
			var nd := 1e9
			for o in lst:
				if not is_same(o, it) and o.B.k == B.k and not o.B.fly: nd = minf(nd, (o.c as Vector2).distance_to(c))
			var side := minf(it.s * .92, nd * .86)
			var h := side / 2
			# a round pad: no corners to line up, so every box sits the same way round its hub
			var rad := minf(side * 1.08, nd * .92) / 2.0
			shape = []
			for j in 24: shape.append(Vector2(c.x + cos(j * TAU / 24.0 + PI / 4) * rad, c.y + sin(j * TAU / 24.0 + PI / 4) * rad))
			cs = rad * 2.0
		else:
			shape = it.pts
			cs = it.s
		BOXSH[B.id] = shape
		it.shape = shape
		it.cs = cs
	BOXL = lst
	return lst

## one holographic docking slot: glass slab with lit sides, a glowing rim, corner beacons and a floating number
## (split in parts so the parts that do not move can be cached: body, beacons, number)
func _slab_geo(it: Dictionary) -> Dictionary:
	if it.has("geo"): return it.geo
	var pts: Array = it.shape
	var cx := 0.0
	var cz := 0.0
	for q in pts:
		cx += q.x
		cz += q.y
	cx /= pts.size()
	cz /= pts.size()
	var P := []
	for q in pts: P.append(Vector2(cx + (q.x - cx) * .94, cz + (q.y - cz) * .94))
	var fly: bool = it.B.fly
	it.geo = {"P": P, "cx": cx, "cz": cz, "hgt": 9.0 if fly else 7.0, "pal": PAL.fly if fly else PAL.box, "label": "FLYBY" if fly else String(it.B.n), "cs": it.cs, "tri": earclip(P), "round": not fly}
	return it.geo
func slab_body(out: Dictionary, g: Dictionary, hi: bool) -> void:
	var P: Array = g.P
	var hgt: float = g.hgt
	var pal: Dictionary = g.pal
	var cx: float = g.cx
	var cz: float = g.cz
	var pul := .5 + .5 * sin(T * 4) if hi else 0.0
	var tp: Color = pal.top
	var top := Color(minf(1, tp.r + ((.18 + .12 * pul) * .6 if hi else 0.0)), minf(1, tp.g + (.18 + .12 * pul if hi else 0.0)), minf(1, tp.b + ((.18 + .12 * pul) * .6 if hi else 0.0)), tp.a)
	var rim: Color = Color(.75, 1, .85, 1) if hi else pal.rim
	# top face (holo grid)
	for i in g.tri:
		var q: Vector2 = P[i]
		out.top.pv(q.x, hgt, q.y, q.x / 14, q.y / 14, 0, 0, top)
	# sides, lit from the north-west
	for i in P.size():
		var a: Vector2 = P[i]
		var b: Vector2 = P[(i + 1) % P.size()]
		var dx := b.x - a.x
		var dz := b.y - a.y
		var l := sqrt(dx * dx + dz * dz)
		if l == 0: l = 1
		var nx := dz / l
		var nz := -dx / l
		if nx * ((a.x + b.x) / 2 - cx) + nz * ((a.y + b.y) / 2 - cz) < 0:
			nx = -nx
			nz = -nz
		var sh := .55 + .45 * maxf(0, nx * -.6 + nz * -.8)
		var c1 := Color(pal.side[0] * sh, pal.side[1] * sh, pal.side[2] * sh, .9)
		var c0 := Color(.01, .04, .08, .9)
		out.side.v.append_array(PackedVector3Array([Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, hgt, b.y), Vector3(a.x, 0, a.y), Vector3(b.x, hgt, b.y), Vector3(a.x, hgt, a.y)]))
		out.side.uv.append_array(_Z6)
		out.side.q.append_array(_Z6)
		out.side.c.append_array(PackedColorArray([c0, c0, c1, c0, c1, c1]))
	ribbon(out.rim, P, true, 1.9, hgt + .3, rim)
static var _Z6 := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
func slab_beams(beam: VB, glowv: VB, g: Dictionary, hi: bool) -> void:
	var hgt: float = g.hgt
	var rim: Color = Color(.75, 1, .85, 1) if hi else g.pal.rim
	var r := 7.0
	var Rr := rgt * r
	var U := cup * r
	var BP: Array = g.P
	if g.get("round", false):
		BP = []
		for j in range(0, g.P.size(), maxi(1, g.P.size() / 4)): BP.append(g.P[j])
	for q in BP:
		quad(beam, [Vector3(q.x - rgt.x * .9, hgt + 15, q.y - rgt.z * .9), Vector3(q.x + rgt.x * .9, hgt + 15, q.y + rgt.z * .9), Vector3(q.x + rgt.x * .9, hgt, q.y + rgt.z * .9), Vector3(q.x - rgt.x * .9, hgt, q.y - rgt.z * .9)], UV1, Color(rim.r, rim.g, rim.b, .55))
		var y := 7.0 + 14
		quad(glowv, [Vector3(q.x - Rr.x + U.x, y - Rr.y + U.y, q.y - Rr.z + U.z), Vector3(q.x + Rr.x + U.x, y + Rr.y + U.y, q.y + Rr.z + U.z), Vector3(q.x + Rr.x - U.x, y + Rr.y - U.y, q.y + Rr.z - U.z), Vector3(q.x - Rr.x - U.x, y - Rr.y - U.y, q.y - Rr.z - U.z)], UV1, Color(.4, .9, 1, .5))

func drawBoxes() -> void:
	var hi := {}
	for m in board.targets: hi[m.dest] = true
	var hkeys := hi.keys()
	hkeys.sort()
	var hsig := ",".join(hkeys)
	var L := computeBoxes()
	for it in L: _slab_geo(it)
	# the boxes that are not highlighted only change when the highlight moves
	var body = _cache.get("box_body")
	if body == null or body.sig != hsig:
		var out := {"top": VB.new(), "side": VB.new(), "rim": VB.new()}
		for it in L:
			if not hi.has(it.B.id): slab_body(out, it.geo, false)
		body = {"sig": hsig, "top": out.top.mesh() if out.top.size() else null, "side": out.side.mesh() if out.side.size() else null, "rim": out.rim.mesh() if out.rim.size() else null}
		_cache["box_body"] = body
	var hout := {"top": VB.new(), "side": VB.new(), "rim": VB.new()}
	for it in L:
		if hi.has(it.B.id): slab_body(hout, it.geo, true)
	for part in ["top", "side", "rim"]:
		if body[part] != null: flush("q", body[part], null, 8 if part == "top" else 1)
		flush("q", hout[part], null, 8 if part == "top" else 1)
	# beacons and glows face the camera; numbers turn with it
	var csig := [snappedf(C.yaw, .002), snappedf(C.pitch, .002), hsig]
	var cam_parts = _cache.get("box_cam")
	if cam_parts == null or cam_parts.sig != csig:
		var beam := VB.new()
		var glowv := VB.new()
		var num := {}
		for it in L:
			slab_beams(beam, glowv, it.geo, hi.has(it.B.id))
			var g: Dictionary = it.geo
			var sz := minf(g.cs * .78, 46)
			var key: String = g.label + "|" + g.pal.gc
			if not num.has(key): num[key] = VB.new()
			flatQuad(num[key], g.cx, g.cz, sz, sz, -C.yaw, g.hgt + .8, UV1, WHITE)
		var nums := VB.new()
		for key in num:
			var kp: Array = key.split("|")
			var e := paint.glyph(kp[0], kp[1])
			var uv := paint.uv_of(e)
			var vb: VB = num[key]
			for i in vb.size(): vb.uv[i] = Vector2(lerpf(uv[0], uv[2], vb.uv[i].x), lerpf(uv[1], uv[3], vb.uv[i].y))
			nums.add(vb)
		cam_parts = {"sig": csig, "beam": beam.mesh(), "glow": glowv.mesh(), "num": nums.mesh()}
		_cache["box_cam"] = cam_parts
	flush("q", cam_parts.beam, null, 1)
	flush("q", cam_parts.num, paint.atlas_tex(), 0)
	flush("q", cam_parts.glow, null, 3)

## frame for the paint code: where a world's base slots are, in board coordinates
func worldFrame(k: String):
	ensure()
	var A = ASM.get(k) if ASM != null else null
	if A == null or not asmKind(k).base: return null
	var CW: float = V25Paint.SLOT_CARD[2] / LAY.S
	return {"a": 0.0, "abs": true, "noCard": true, "CW": CW, "CH": CW * 127 / 192, "slots": A.slots}
## which box (if any) a screen position is on, among the given destinations
func destAt(sx: float, sy: float, dests: Array):
	var g = ground(sx, sy, 0)
	if g == null: return null
	for d in dests:
		var sh = BOXSH.get(d)
		if sh != null and Geometry2D.is_point_in_polygon(g, PackedVector2Array(sh)): return d
	return null

# ---------------- world boxes: one digital assembly per world, placed once, clear of everything ----------------
func asmKind(k: String) -> Dictionary:
	var w: Dictionary = Game.data.D.W[k]
	var t: Array = w.tags
	var earth := t.has("earth")
	var gas := t.has("gas")
	return {"base": SHRules.t(w.get("base")) or gas or earth, "card": not earth and (SHRules.t(w.get("base")) or gas)}
func asmSize(k: String) -> Vector2: return Vector2(TRW, TRH) if asmKind(k).base else Vector2(PWS, PHS)
static func segD(p: Vector2, a: Vector2, b: Vector2) -> float:
	var d := b - a
	var t := clampf(((p - a).dot(d)) / (d.dot(d) if d.dot(d) != 0 else 1.0), 0, 1)
	return (p - a - d * t).length()
static func polyD(p: Vector2, poly: Array) -> float:
	var ins := false
	var d := 1e9
	var j := poly.size() - 1
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if ((a.y > p.y) != (b.y > p.y)) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x: ins = not ins
		d = minf(d, segD(p, a, b))
		j = i
	return -d if ins else d
static func segX(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var o := func(p: Vector2, q: Vector2, r: Vector2) -> float: return (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
	return o.call(a, b, c) * o.call(a, b, d) < 0 and o.call(c, d, a) * o.call(c, d, b) < 0
static func polyRect(poly: Array, r: Array, m: float) -> bool:
	var R := [r[0] - m, r[1] - m, r[2] + m, r[3] + m]
	var cs := [Vector2(R[0], R[1]), Vector2(R[2], R[1]), Vector2(R[2], R[3]), Vector2(R[0], R[3])]
	for p in poly:
		if p.x > R[0] and p.x < R[2] and p.y > R[1] and p.y < R[3]: return true
	for c in cs:
		if polyD(c, poly) < 0: return true
	for i in poly.size():
		for j in 4:
			if segX(poly[i], poly[(i + 1) % poly.size()], cs[j], cs[(j + 1) % 4]): return true
	return false
static func rectR(a: Array, b: Array, m: float) -> bool: return a[0] - m < b[2] and a[2] + m > b[0] and a[1] - m < b[3] and a[3] + m > b[1]
static func circR(r: Array, c: Array, rad: float) -> bool:
	var dx := maxf(maxf(r[0] - c[0], 0), c[0] - r[2])
	var dz := maxf(maxf(r[1] - c[1], 0), c[1] - r[3])
	return sqrt(dx * dx + dz * dz) < rad

func placeAsm(S: float) -> Dictionary:
	var D: Dictionary = Game.data.D
	var GEO: Dictionary = board.geo_std
	var circ := []
	var polys := []
	var ks := []
	for k in GEO.worlds:
		if D.W.has(k) and podOfW(k) != null: ks.append(k)
	var ring_ := {}
	for k in bodies.b:
		var b: Dictionary = bodies.b[k]
		var m: Array = GEO.maps[b.map]
		var q := mapP(m[0] + b.cx * .4, m[1] + b.cy * .4)
		circ.append([q.x, q.y, b.r * .4 * S * 1.5, null])
	for k in ks:
		var R := ringOf(k)
		var c := mapP(R.c.x, R.c.y, podOfW(k))
		ring_[k] = {"c": c, "r": R.r * S + 18}
		circ.append([c.x, c.y, ring_[k].r, k])
	for it in computeBoxes(): polys.append(it.shape)
	var placed := []
	var out := {}
	# the placement search below is slow and its result never changes: it is cached in data/v25_asm.json
	# (delete the file, or run with --dump-asm, to rebuild it)
	var cache := {}
	if FileAccess.file_exists("res://data/v25_asm.json") and not OS.get_cmdline_user_args().has("--dump-asm"):
		cache = board._json("res://data/v25_asm.json")
	var found := {}
	var order := ks.duplicate()
	order.sort_custom(func(a, b):
		var sa := asmSize(a)
		var sb := asmSize(b)
		var d := sb.x * sb.y - sa.x * sa.y
		if d != 0: return d < 0
		return a < b)
	for k in order:
		var sz := asmSize(k)
		var w := sz.x
		var h := sz.y
		var c: Vector2 = ring_[k].c
		var r: float = ring_[k].r
		var cands := []
		var g := 12.0
		var anchor = ring_.get("tro") if k == "jup" else null
		if anchor != null:
			var ex := 0
			while ex <= 120:
				var off := -w * .5
				while off <= w * .5:
					cands.append([anchor.c.x - w / 2 + off, anchor.c.y + anchor.r + g + ex, ex * .2 + absf(off) * .05])
					off += 20
				ex += 20
		elif k == "eur":
			var ex := 0
			while ex <= 160:
				var off := -.5
				while off <= .5:
					cands.append([c.x - w / 2 + off * w, c.y + r + g + ex, ex * 1.2 + absf(off) * 20])
					off += .125
				ex += 10
		else:
			var ex := 0
			while ex <= 140:
				var off := -.5
				while off <= .5:
					cands.append([c.x + r + g + ex, c.y - h / 2 + off * h, ex * 1.2 + absf(off) * 20])
					cands.append([c.x - w / 2 + off * w, c.y + r + g + ex, 16 + ex * 1.2 + absf(off) * 20])
					cands.append([c.x - r - g - ex - w, c.y - h / 2 + off * h, 34 + ex * 1.2 + absf(off) * 20])
					cands.append([c.x - w / 2 + off * w, c.y - r - g - ex - h, 52 + ex * 1.2 + absf(off) * 20])
					off += .125
				ex += 14
		var best = null
		if cache.has(k): best = {"sc": 0.0, "cd": [cache[k][0], cache[k][1], 0.0]}
		for cd in (cands if best == null else []):
			var R := [cd[0], cd[1], cd[0] + w, cd[1] + h]
			var pen := 0.0
			for o in circ:
				if circR(R, o, o[2] + 4): pen += 1000
			for pg in polys:
				if polyRect(pg, R, 6): pen += 1000
			for q in placed:
				if rectR(R, q, 8): pen += 1000
			# the tether to the ring must not cross other boxes, rings or boxes
			var nx := maxf(R[0], minf(c.x, R[2]))
			var nz := maxf(R[1], minf(c.y, R[3]))
			var L := Vector2(nx - c.x, nz - c.y).length()
			var t := .2
			while t < .95 and L > 1:
				var p := Vector2(c.x + (nx - c.x) * t, c.y + (nz - c.y) * t)
				var bad := false
				for o in circ:
					if o[3] != k and Vector2(p.x - o[0], p.y - o[1]).length() < o[2]:
						bad = true
						break
				if not bad:
					for pg in polys:
						if polyD(p, pg) < 0:
							bad = true
							break
				if not bad:
					for q in placed:
						if p.x > q[0] and p.x < q[2] and p.y > q[1] and p.y < q[3]:
							bad = true
							break
				if bad: pen += 400
				t += .15
			var sc: float = pen + cd[2] + L * .3
			if best == null or sc < best.sc: best = {"sc": sc, "cd": cd}
		var cd: Array = best.cd
		found[k] = [cd[0], cd[1]]
		var rect := [cd[0], cd[1], cd[0] + w, cd[1] + h]
		placed.append(rect)
		out[k] = {"k": k, "x0": cd[0], "z0": cd[1], "w": w, "h": h, "rect": rect, "c": c, "r": r}
	if cache.is_empty() and OS.get_cmdline_user_args().has("--dump-asm"):
		var f := FileAccess.open("res://data/v25_asm.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(found))
		f.close()
		print("DUMPED asm cache ", found.size())
	# the sheet positions of the base slots become anchors of their pod, so counters and bases map to the right pod
	for k in out:
		var A: Dictionary = out[k]
		var pod: Dictionary = podOfW(k)
		A.slots = []
		for i in 8:
			var sl := V25Paint.slot_base(i)
			var q := Vector2((A.x0 + sl[0] - pod.org[0]) / S + pod.hub[0], (A.z0 + sl[1] - pod.org[1]) / S + pod.hub[1])
			A.slots.append(q)
			if i < 4: LAY.addAnchor(q.x, q.y, pod.k)
		# pods grow to hold their world boxes
		var r: Array = pod.rect
		r[0] = minf(r[0], A.rect[0] - 16)
		r[1] = minf(r[1], A.rect[1] - 16)
		r[2] = maxf(r[2], A.rect[2] + 16)
		r[3] = maxf(r[3], A.rect[3] + 16)
	return out

func baseCount(k: String, ws: Dictionary) -> int:
	var G = Game.G
	var n := 0
	for b in G.bases:
		if b.w == k: n += 1
	if G.world != null:
		for f in G.world.facs:
			if f == G.f: continue
			for b in G.world.facs[f].bases:
				if b.w == k: n += 1
	if SHRules.t(ws.get("npf")): n += 1
	return n

var _links = null
## the belt links' paths (they never move): [{pts, col, arrow: [e, l, r] direction data}]
func _link_paths(S: float) -> Array:
	if _links != null: return _links
	_links = []
	const SATH := {"mer": "sun", "cer": "bel", "hyg": "bel", "ves": "bel", "plu": "kui", "hau": "kui", "eri": "sca", "sed": "sca"}
	const HUEL := {"sun": [1, .72, .3], "bel": [.95, .78, .5], "kui": [.62, .78, .98], "sca": [.75, .65, 1]}
	for k in SATH:
		var hk: String = SATH[k]
		var hp = LAY.pods.get(hk)
		var sp = LAY.pods.get(k)
		if hp == null or sp == null or not board.geo_std.worlds.has(k): continue
		var A: Vector2
		var ra: float
		if board.geo_std.worlds.has(hk):
			var R := ringOf(hk)
			A = mapP(R.c.x, R.c.y, hp)
			ra = R.r * S + 12
		else:
			A = mapP(hp.hub[0], hp.hub[1], hp)
			ra = 80
		var R2 := ringOf(k)
		var B := mapP(R2.c.x, R2.c.y, sp)
		var rb: float = R2.r * S + 12
		var r0 := A.length()
		var r1 := B.length()
		var a0 := atan2(A.y, A.x)
		var da := atan2(B.y, B.x) - a0
		while da > PI: da -= 6.2832
		while da < -PI: da += 6.2832
		var n := maxi(30, ceili(absf(da) * maxf(r0, r1) / 90))
		var pts := []
		var straight := hk == "sun"
		var sr: Array = sp.rect
		for i in n + 1:
			var t := i / float(n)
			var rr := r0 + (r1 - r0) * t
			var an := a0 + da * t
			var q := A.lerp(B, t) if straight else Vector2(cos(an) * rr, sin(an) * rr)
			if q.distance_to(A) > ra and q.distance_to(B) > rb and not (straight and q.x > sr[0] and q.x < sr[2] and q.y > sr[1] and q.y < sr[3]): pts.append(q)
		if pts.size() < 2: continue
		_links.append({"pts": pts, "col": HUEL[hk]})
	return _links

func drawBeltLinks(S: float, px: float) -> void:
	var L := _link_paths(S)
	# the lanes and their arrowheads change only with the zoom
	flushc("links", snappedf(px, px * .05), func():
		var lanes := VB.new()
		for lk in L:
			var pts: Array = lk.pts
			ribbon(lanes, pts, false, maxf(2, px * 1.0), 1.3, rgba(lk.col, .22))
			var e: Vector2 = pts[pts.size() - 1]
			var f: Vector2 = pts[pts.size() - 2]
			var dv := e - f
			var l := dv.length()
			if l == 0: l = 1
			var ux := dv.x / l
			var uz := dv.y / l
			var h := maxf(30, px * 9)
			fillPoly(lanes, [e, Vector2(e.x - ux * h - uz * h * .45, e.y - uz * h + ux * h * .45), Vector2(e.x - ux * h + uz * h * .45, e.y - uz * h - ux * h * .45)], 1.5, rgba(lk.col, .9))
		return lanes, null, 1)
	# the travelling dots move every frame
	var dots := VB.new()
	var ds := maxf(12, px * 4)
	for lk in L:
		var pts: Array = lk.pts
		var acc := 0.0
		var nxt := fmod(T * 70, 150)
		for i in range(1, pts.size()):
			var p0: Vector2 = pts[i - 1]
			var p1: Vector2 = pts[i]
			var Ln := p0.distance_to(p1)
			while nxt < acc + Ln:
				var pp := p0.lerp(p1, (nxt - acc) / Ln)
				flatQuad(dots, pp.x, pp.y, ds, ds, 0, 1.5, UV1, rgba(lk.col, .85))
				nxt += 150
			acc += Ln
	flush("q", dots, null, 1)

var _lanes = null
func drawWorlds(S: float, px: float) -> void:
	var G = Game.G
	var D: Dictionary = Game.data.D
	var GEO: Dictionary = board.geo_std
	var ks := []
	for k in GEO.worlds:
		if G.w.get(k) != null and D.W.has(k) and podOfW(k) != null: ks.append(k)
	# zone discs, orbit tracks (dotted) and surface pads never move
	flushc("w_fill", 0, func():
		var fillv := VB.new()
		for k in ks:
			var R := ringOf(k)
			var c := mapP(R.c.x, R.c.y, podOfW(k))
			var r: float = R.r * S
			var fc := V25Paint.css(V25Paint.FIELD.get(D.W[k].f, ["#8aa"])[0])
			flatQuad(fillv, c.x, c.y, r * 1.8, r * 1.8, 0, .8, UV1, Color(fc, .09))
		return fillv, null, 2)
	flushc("w_zone", 0, func():
		var zone := VB.new()
		for k in ks:
			var gw: Dictionary = GEO.worlds[k]
			if not gw.has("spoly"): continue
			var pts := []
			for q in board.hull(gw.spoly): pts.append(mapP(q.x, q.y, podOfW(k)))
			fillPoly(zone, pts, .9, Color(.43, .86, .55, .08))
		return zone, null, 1)
	# rims and tethers are as wide as the zoom asks
	flushc("w_rim", snappedf(px, px * .05), func():
		var rimv := VB.new()
		for k in ks:
			var gw: Dictionary = GEO.worlds[k]
			var pod = podOfW(k)
			var R := ringOf(k)
			var c := mapP(R.c.x, R.c.y, pod)
			var r: float = R.r * S
			if gw.has("spoly"):
				var pts := []
				for q in board.hull(gw.spoly): pts.append(mapP(q.x, q.y, pod))
				ribbon(rimv, pts, true, maxf(1.6, px * 1.1), 1.2, Color(.43, .86, .55, .55))
			var A = ASM.get(k)
			if A == null: continue
			var nx := maxf(A.rect[0], minf(c.x, A.rect[2]))
			var nz := maxf(A.rect[1], minf(c.y, A.rect[3]))
			var dd := Vector2(nx - c.x, nz - c.y).length()
			if dd > r + 8:
				var ux := (nx - c.x) / dd
				var uz := (nz - c.y) / dd
				ribbon(rimv, [Vector2(c.x + ux * (r - 6), c.y + uz * (r - 6)), Vector2(nx, nz)], false, maxf(2, px * 1.5), 1.5, Color(.62, .78, .95, .8))
		return rimv, null, 1)
	flushc("w_dots", 0, func():
		var dots := VB.new()
		for k in ks:
			if not GEO.worlds[k].has("poly"): continue
			var pod = podOfW(k)
			var R := ringOf(k)
			var n := maxi(24, roundi(2 * PI * R.r / 9))
			for i in n:
				var an := i / float(n) * 6.2832
				var q := mapP(R.c.x + cos(an) * R.r, R.c.y + sin(an) * R.r, pod)
				flatQuad(dots, q.x, q.y, 5.5 * S * 1.5, 5.5 * S * 1.5, 0, 2, UV1, Color(.59, .52, .84, .9))
		return dots, null, 2)
	# travel lanes from each system's hub world to the other worlds of the system (the dots move)
	if _lanes == null:
		_lanes = []
		for sk in D.SYS:
			var hk = D.SYS[sk].get("hub")
			if hk == null or not GEO.worlds.has(hk): continue
			var pod = LAY.pods.get(sk)
			if pod == null or G.w.get(hk) == null: continue
			var A := ringOf(hk)
			var a0 := mapP(A.c.x, A.c.y, pod)
			for w in D.W:
				if w == hk or D.W[w].sys != sk or LAY.pods.has(w) or not GEO.worlds.has(w) or G.w.get(w) == null: continue
				var B := ringOf(w)
				var b0 := mapP(B.c.x, B.c.y, pod)
				var dv := b0 - a0
				var L := dv.length()
				var s0: float = A.r * S + 8
				var s1: float = L - B.r * S - 8
				if s1 - s0 < 30: continue
				_lanes.append([a0, dv / L, s0, s1])
	var lanes := VB.new()
	for ln in _lanes:
		var a0: Vector2 = ln[0]
		var u: Vector2 = ln[1]
		var s0: float = ln[2]
		var s1: float = ln[3]
		var d := s0 + fmod(T * 26, 16)
		while d < s1:
			var al := .25 + .5 * sin((d - s0) / (s1 - s0) * PI)
			flatQuad(lanes, a0.x + u.x * d, a0.y + u.y * d, 5, 5, 0, 1.4, UV1, Color(.62, .55, .98, al))
			d += 16
		var hx := a0.x + u.x * s1
		var hz := a0.y + u.y * s1
		fillPoly(lanes, [Vector2(hx, hz), Vector2(hx - u.x * 16 - u.y * 7, hz - u.y * 16 + u.x * 7), Vector2(hx - u.x * 16 + u.y * 7, hz - u.y * 16 - u.x * 7)], 1.4, Color(.62, .55, .98, .8))
	flush("q", lanes, null, 1)
	# world boxes: plate, card slot, life slot and base tray, parked beside the world where nothing else is
	for k in ks:
		var A = ASM.get(k)
		if A == null: continue
		var key: String = "panel_" + k
		if not _panel_tex.has(k) or _panel_ver != _ver: _panel_tex[k] = paint.panel(k, G.w[k], baseCount(k, G.w[k]), asmSize(k))
		var m = cached(key, 0, func():
			var a := VB.new()
			flatQuad(a, A.x0 + A.w / 2, A.z0 + A.h / 2, A.w, A.h, 0, 3.2, UV1, WHITE)
			return a)
		flush("q", m, _panel_tex[k], 0)
	_panel_ver = _ver
var _panel_tex := {}
var _panel_ver := -1

# ---------------- caches: geometry that only changes with the game state, the zoom or the camera's turn ----------------
var _ver := 0  ## bumped whenever the game state, the selection or a dragged counter changes
var _rec_ver := -1
var _cache := {}
func touch() -> void: _ver += 1
## a cached mesh: rebuilt when sig changes; null when empty
func cached(key: String, sig, build: Callable):
	var e = _cache.get(key)
	if e != null and e.sig == sig: return e.mesh
	var vb: VB = build.call()
	var m = vb.mesh() if vb.size() else null
	_cache[key] = {"sig": sig, "mesh": m}
	return m
func flushc(key: String, sig, build: Callable, tex, md: int) -> void:
	var m = cached(key, sig, build)
	if m != null: flush("q", m, tex, md)

# ---------------- draw calls ----------------
## one draw call: kind q (general), p (planet), r (rock); verts a VB or a cached ArrayMesh
func flush(kind: String, verts, tex, md: int, uni := {}, prim := Mesh.PRIMITIVE_TRIANGLES) -> void:
	if verts is VB and verts.size() == 0: return
	_calls.append({"kind": kind, "verts": verts, "tex": tex, "mode": md, "uni": uni, "prim": prim})
## consecutive draws that share a texture and mode become one call
func batch(lst: Array) -> void:
	var cur = null
	for it in lst:
		if cur != null and cur.tex == it.tex and cur.mode == it.mode:
			cur.verts.add(it.verts)
		else:
			if cur != null: flush("q", cur.verts, cur.tex, cur.mode)
			var vb := VB.new()
			vb.add(it.verts)
			cur = {"tex": it.tex, "mode": it.mode, "verts": vb}
	if cur != null: flush("q", cur.verts, cur.tex, cur.mode)

func _material(kind: String, i: int) -> ShaderMaterial:
	if not _mats.has(kind): _mats[kind] = []
	var lst: Array = _mats[kind]
	while lst.size() <= i:
		var m := ShaderMaterial.new()
		m.shader = _sh[kind]
		lst.append(m)
	return lst[i]

var debug_calls := false
func _submit() -> void:
	if debug_calls:
		var lines := []
		for cl in _calls: lines.append("%s%d:%d%s" % [cl.kind, cl.mode, cl.verts.size() if cl.verts is VB else -1, "T" if cl.tex != null else ""])
		print("calls ", _calls.size(), ": ", " ".join(lines))
	var used := {}
	for i in _calls.size():
		var cl: Dictionary = _calls[i]
		if _pool.size() <= i:
			var mi := MeshInstance3D.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.sorting_use_aabb_center = false
			mi.extra_cull_margin = 16384.0
			mi.ignore_occlusion_culling = true
			add_child(mi)
			_pool.append(mi)
			_dyn.append(ArrayMesh.new())
		var mi: MeshInstance3D = _pool[i]
		if cl.verts is ArrayMesh: mi.mesh = cl.verts
		else: mi.mesh = (cl.verts as VB).mesh(cl.prim, _dyn[i])
		var kind: String = "pt" if cl.prim == Mesh.PRIMITIVE_POINTS else cl.kind
		var n: int = used.get(kind, 0)
		used[kind] = n + 1
		var m := _material(kind, n)
		if kind == "pt": m.set_shader_parameter("PT", cl.uni.get("PT", 1.0))
		elif kind == "q":
			m.set_shader_parameter("MODE", cl.mode)
			m.set_shader_parameter("TM", T)
			m.set_shader_parameter("T", cl.tex)
		else:
			for u in cl.uni: m.set_shader_parameter(u, cl.uni[u])
		mi.material_override = m
		mi.sorting_offset = i * 100000.0
		mi.visible = true
	for i in range(_calls.size(), _pool.size()): _pool[i].visible = false
	_calls = []

# ---------------- models for the locations that have no printed planet ----------------
var MODELS := {}
## planets with rings in the 2.5D view: the ring plane's normal (the planet's axis tilted towards the viewer), the outer radius in planet radii
const RING3 := {"sat": {"n": Vector3(-.3, .75, -.5), "out": 2.3, "kind": 0}, "nep": {"n": Vector3(.2, .72, -.5), "out": 2.6, "kind": 1}}
## moons that are tidally locked to their planet (or to each other) do not turn
const LOCKED_MODELS := ["pho", "mim", "dio", "obe", "umb", "gal", "plu"]
func P_(o: Dictionary) -> Dictionary:
	var p := {"s": 1.0, "rho": 0.0, "w": .12, "ph": 0.0, "c1": [.35, .33, .31], "c2": [.6, .57, .53], "lp": .05, "ice": 0.0, "el": 1.0, "tt": 0.0, "rg": 0.0, "sd": 1.0, "spin": .5}
	p.merge(o, true)
	return p
func rkc(n: int, seed: int, c1: Array, c2: Array, o := {}) -> Array:
	var r := Mulb.new(seed)
	var a := []
	for i in n:
		var p := {"s": .2 + r.next() * .32, "rho": .5 + r.next() * 1.5}
		p.w = (.1 + r.next() * .22) * (1 if r.next() < .5 else -1)
		p.ph = r.next() * 6.28
		p.c1 = c1
		p.c2 = c2
		p.lp = .34
		p.ice = 0.0
		p.el = .68 + r.next() * .3
		p.sd = r.next() * 60
		p.spin = .4 + r.next()
		p.tt = 0.0
		p.rg = 0.0
		p.merge(o, true)
		a.append(p)
	return a
func scaParts() -> Array:
	var U := 18.0
	var R := 100.0
	var r := Mulb.new(91)
	var spec := [[1.3, [.4, .16, .1], [.75, .38, .25], .2], [1.1, [.85, .86, .9], [1, 1, 1], 1], [1, [.3, .32, .4], [.62, .66, .78], .6], [.9, [.5, .25, .15], [.8, .55, .4], .3], [.85, [.32, .34, .42], [.6, .64, .76], .5], [.75, [.7, .72, .8], [.95, .96, 1], .8],
		[.7, [.3, .12, .08], [.62, .32, .22], .2], [.65, [.34, .36, .44], [.64, .68, .8], .5], [.6, [.55, .5, .46], [.85, .8, .74], .3], [.55, [.3, .32, .4], [.6, .64, .76], .6], [.5, [.8, .82, .88], [1, 1, 1], .9], [.45, [.4, .22, .16], [.7, .45, .33], .3]]
	var placed := []
	var out := []
	for i in spec.size():
		var sp: Array = spec[i]
		var s: float = sp[0]
		var rr := U * s * 1.1
		var best = null
		var t := 0
		while t < 4000 and best == null:
			var a := r.next() * 6.2832
			var d := sqrt(r.next()) * (R - rr)
			var x := cos(a) * d * 1.05
			var z := sin(a) * d * 1.1 + 34
			var ok := true
			for q in placed:
				if Vector2(q[0] - x, (q[1] - z) * .62).length() <= q[2] + rr + 5:
					ok = false
					break
			if ok: best = [x, z, rr]
			t += 1
		if best == null: best = [(i - 6) * 14.0, 40.0, rr]
		placed.append(best)
		out.append(P_({"s": s, "rho": Vector2(best[0], best[1] / .85).length() / U, "ph": atan2(best[1] / .85, best[0]), "w": 0.0, "c1": sp[1], "c2": sp[2], "ice": float(sp[3]), "lp": .04 if i % 3 == 1 else .2, "el": 1.0 if i % 3 == 1 else .85, "sd": 70.0 + i * 3, "spin": .25 + (i % 4) * .15}))
	return out
func _build_models() -> void:
	var ROCK := [[.3, .27, .24], [.55, .5, .44]]
	var nea := rkc(3, 11, ROCK[0], ROCK[1], {"lp": .38})
	for i in 3:
		nea[i].s = [.8, .55, .42][i]
		nea[i].rho = [1.1, 1.5, .9][i]
	var bel := rkc(9, 21, ROCK[0], ROCK[1])
	for p in bel: p.s = p.s * .9
	var tro := rkc(5, 31, ROCK[0], ROCK[1], {"rho": 1.7, "s": .3})
	for i in 5:
		tro[i].ph = 1.0 + i * .22
		tro[i].w = .1
		tro[i].rho = 1.6 + (i % 2) * .25
	var tro2 := rkc(5, 32, [.26, .22, .2], [.5, .44, .4], {"rho": 1.7, "s": .3})
	for i in 5:
		tro2[i].ph = 4.1 + i * .22
		tro2[i].w = .1
		tro2[i].rho = 1.6 + (i % 2) * .25
	MODELS = {
		"nea": {"u": 1, "parts": nea},
		"pho": {"u": 1, "parts": [P_({"s": .75, "rho": 1.0, "w": .5, "lp": .32, "el": .8, "c1": [.24, .2, .18], "c2": [.45, .38, .33], "sd": 4.0}), P_({"s": .5, "rho": 1.8, "w": .2, "ph": 3.0, "lp": .28, "el": .85, "c1": [.3, .27, .24], "c2": [.55, .5, .45], "sd": 9.0})]},
		"com": {"u": 1, "parts": [P_({"s": 1.0, "lp": .34, "el": .85, "c1": [.13, .12, .12], "c2": [.34, .3, .27], "spin": .3, "sd": 7.0})], "tail": true},
		"bel": {"u": 1, "parts": bel},
		"hyg": {"u": 1, "parts": [P_({"s": 1.0, "lp": .08, "c1": [.22, .21, .2], "c2": [.42, .4, .37], "sd": 3.0}), P_({"s": .75, "rho": 1.9, "w": .22, "ph": 2.0, "lp": .16, "el": .9, "c1": [.32, .33, .36], "c2": [.52, .53, .56], "sd": 5.0})]},
		"ves": {"u": 1, "parts": [P_({"s": 1.15, "lp": .13, "el": .92, "c1": [.45, .4, .35], "c2": [.88, .85, .8], "sd": 8.0, "spin": .8})]},
		"tro": {"u": 1, "parts": tro + tro2},
		"mim": {"u": 1, "parts": [P_({"s": .6, "rho": 1.3, "w": .45, "c1": [.5, .5, .52], "c2": [.72, .72, .75], "ice": .5, "sd": 2.0}), P_({"s": .65, "rho": 0.0, "c1": [.8, .85, .9], "c2": [1, 1, 1], "ice": 1.0, "sd": 6.0}), P_({"s": .8, "rho": 2.1, "w": .2, "ph": 3.0, "c1": [.55, .56, .6], "c2": [.85, .86, .9], "ice": .8, "sd": 12.0})]},
		"dio": {"u": 1, "parts": [P_({"s": .85, "rho": 1.1, "w": .3, "c1": [.55, .55, .57], "c2": [.85, .86, .88], "ice": .7, "sd": 14.0}), P_({"s": 1.05, "rho": 1.1, "w": .3, "ph": 3.14, "c1": [.46, .45, .45], "c2": [.78, .78, .78], "ice": .4, "sd": 17.0, "lp": .04})]},
		"hyp": {"u": 1, "parts": [P_({"s": .8, "rho": 1.8, "w": .25, "lp": .42, "el": .72, "c1": [.32, .2, .13], "c2": [.62, .42, .28], "sd": 19.0}), P_({"s": 1.0, "rho": 0.0, "tt": 1.0, "c1": [.1, .08, .07], "c2": [.92, .92, .9], "ice": .3, "lp": .06, "sd": 23.0, "spin": .25})]},
		"cha": {"u": 1, "parts": [P_({"s": .8, "lp": .28, "el": .85, "rg": .55, "c1": [.2, .15, .12], "c2": [.4, .32, .26], "sd": 27.0})]},
		"obe": {"u": 1, "parts": [P_({"s": 1.15, "rho": 0.0, "c1": [.42, .4, .4], "c2": [.72, .7, .68], "ice": .4, "sd": 31.0}), P_({"s": .95, "rho": 2.1, "w": .25, "ph": 2.0, "c1": [.38, .34, .3], "c2": [.62, .56, .5], "ice": .3, "sd": 33.0})]},
		"umb": {"u": 1, "parts": [P_({"s": .8, "rho": 1.6, "w": .32, "c1": [.2, .2, .22], "c2": [.4, .4, .42], "sd": 35.0}), P_({"s": .95, "rho": 0.0, "c1": [.7, .72, .76], "c2": [.95, .96, .98], "ice": .8, "sd": 37.0}), P_({"s": .6, "rho": 2.3, "w": .18, "ph": 3.0, "c1": [.4, .4, .42], "c2": [.78, .78, .8], "ice": .5, "lp": .15, "sd": 39.0})]},
		"gal": {"u": 1, "parts": [P_({"s": .95, "rho": 0.0, "lp": .22, "el": .9, "c1": [.22, .21, .22], "c2": [.42, .4, .4], "sd": 41.0}), P_({"s": .5, "rho": 1.5, "w": .5, "lp": .3, "el": .8, "c1": [.2, .2, .2], "c2": [.4, .38, .36], "sd": 43.0}), P_({"s": .42, "rho": 2.1, "w": .3, "ph": 2.5, "lp": .3, "el": .8, "c1": [.25, .24, .24], "c2": [.45, .42, .4], "sd": 45.0})]},
		"sca": {"u": 1, "parts": scaParts()},
		"kui": {"u": 1, "parts": rkc(9, 51, [.32, .34, .4], [.62, .66, .75], {"ice": .6}) + rkc(3, 52, [.4, .2, .12], [.7, .42, .28], {"ice": .2, "s": .35})},
		"plu": {"u": 1, "parts": [P_({"s": 1.15, "rho": 0.0, "w": 0.0, "lp": .03, "c1": [.5, .3, .2], "c2": [.97, .92, .84], "ice": .35, "sd": 49.0, "spin": .35}), P_({"s": .62, "rho": 1.9, "w": .32, "c1": [.33, .32, .36], "c2": [.58, .55, .56], "ice": .2, "lp": .04, "sd": 53.0})]},
		"hau": {"u": 1, "parts": [P_({"s": 1.1, "rho": 0.0, "el": .55, "lp": .08, "c1": [.82, .85, .92], "c2": [1, 1, 1], "ice": 1.0, "sd": 57.0, "spin": 1.6}), P_({"s": .8, "rho": 2.2, "w": .15, "ph": 3.0, "c1": [.5, .25, .13], "c2": [.8, .52, .34], "ice": .3, "lp": .04, "sd": 59.0})]},
		"sed": {"u": 1, "parts": [P_({"s": .95, "lp": .05, "c1": [.22, .05, .03], "c2": [.55, .15, .08], "sd": 61.0})]},
		"eri": {"u": 1, "parts": [P_({"s": 1.15, "rho": 0.0, "lp": .02, "c1": [.82, .84, .86], "c2": [1, 1, 1], "ice": 1.0, "sd": 63.0, "spin": .3}), P_({"s": .38, "rho": 2.0, "w": .45, "c1": [.18, .18, .2], "c2": [.34, .34, .36], "lp": .12, "sd": 65.0})]},
	}
	for lk in LOCKED_MODELS:
		for part in MODELS[lk].parts: part.spin = 0.0
	MODELS.hyp.parts[1].spin = 0.0  # Iapetus is locked; Hyperion tumbles
	ALPHA_PL = {"giant": P_({"lp": .015, "tt": 1.0, "spin": .7, "c1": [.74, .5, .3], "c2": [.97, .86, .66], "sd": 71.0}), "b": P_({"lp": .1, "c1": [.34, .3, .26], "c2": [.62, .55, .48], "sd": 72.0, "spin": .8}),
		"c": P_({"lp": .03, "c1": [.3, .4, .55], "c2": [.62, .74, .88], "sd": 73.0, "spin": .6}), "d": P_({"lp": .12, "c1": [.3, .27, .25], "c2": [.5, .46, .42], "sd": 74.0, "spin": 1.0})}
var ALPHA_PL := {}

func billboard(pos: Vector3, w: float, h: float) -> Array:
	var R := rgt * w
	var U := cup * h
	return [pos - R + U, pos + R + U, pos + R - U, pos - R - U]
func dist2(x: float, y: float, z: float) -> float: return (Vector3(x, y, z) - eye).length_squared()

func drawRock(pos: Vector3, r: float, p: Dictionary) -> void:
	var sc := 2.4 if p.rg else 1.45
	var a := VB.new()
	quad(a, billboard(pos, r * sc, r * sc), UV1, WHITE)
	var Ld := (-pos).normalized()
	flush("r", a, null, 0, {"rot": p.sd + T * p.spin, "SD": float(p.sd), "LP": float(p.lp), "ICE": float(p.ice), "EL": float(p.el), "SC": sc, "RG": float(p.rg), "TT": float(p.tt),
		"C1": Vector3(p.c1[0], p.c1[1], p.c1[2]), "C2": Vector3(p.c2[0], p.c2[1], p.c2[2]), "L": Vector3(Ld.dot(rgt), Ld.dot(cup) * .6 + .25, .55)})

func drawModel(it: Dictionary) -> void:
	var u: float = it.u
	var sp: Dictionary = it.spec
	var parts := []
	for p in sp.parts:
		var f: float = p.ph + p.w * T
		var o := Vector3(it.x + cos(f) * p.rho * u, it.y + sin(f * 1.7) * p.rho * u * .12, it.z + sin(f) * p.rho * u * .85)
		parts.append({"p": p, "o": o, "d": dist2(o.x, o.y, o.z)})
	if sp.get("tail", false):
		var L := Vector2(it.x, it.z).length()
		if L == 0: L = 1
		var dx: float = it.x / L
		var dz: float = it.z / L
		var g := VB.new()
		var g2 := VB.new()
		for i in 30:
			var t := i / 29.0
			var w := sin(T * .8 + i * .5) * u * .25 * t
			var pos := Vector3(it.x + dx * t * u * 8 - dz * w, it.y + t * u * .4, it.z + dz * t * u * 8 + dx * w)
			var rr := u * (.5 + t * 1.9)
			quad(g, billboard(pos, rr, rr), UV1, Color(.62, .82, 1, .2 * (1 - t) + .02))
		for i in 14:
			var t := i / 13.0
			var pos := Vector3(it.x + dx * t * u * 5.5 + dz * u * .35 * t, it.y, it.z + dz * t * u * 5.5 - dx * u * .35 * t)
			var rr := u * (.3 + t)
			quad(g2, billboard(pos, rr, rr), UV1, Color(1, .95, .8, .12 * (1 - t)))
		quad(g2, billboard(Vector3(it.x, it.y, it.z), u * 2.2, u * 2.2), UV1, Color(.8, .9, 1, .3))
		flush("q", g, null, 3)
		flush("q", g2, null, 3)
	parts.sort_custom(func(a, b): return a.d > b.d)
	for e in parts: drawRock(e.o, u * e.p.s, e.p)

var DEEPI = null
## Deep Space Astronomy: the Andromeda galaxy with its companions, in the free part of the world's area
func drawDeep(it: Dictionary) -> void:
	var u: float = it.u
	var pod: Dictionary = podOfW("dsa")
	var rc: Array = pod.rect
	var ar = ASM.dsa.rect if ASM.has("dsa") else null
	var Wd: float = rc[2] - rc[0]
	var Hd: float = rc[3] - rc[1]
	var c := Vector2((rc[0] + rc[2]) / 2.0, (rc[1] + rc[3]) / 2.0)
	if ar != null:
		var ac := Vector2((ar[0] + ar[2]) / 2.0, (ar[1] + ar[3]) / 2.0)
		c += (c - ac).limit_length(Hd * .22)
	var w := minf(Wd * .8, Hd * 1.5)
	c.x -= Wd * .07
	var sway := 1.0 + .015 * sin(T * .4)
	var g := VB.new()
	quad(g, billboard(Vector3(c.x, u * .3, c.y), w / 2.0 * sway, w / 2.0 / 1.6 * sway), UV1, WHITE)
	flush("q", g, _tex.andromeda, 0)

func drawStars(it: Dictionary) -> void:
	var u: float = it.u
	var th := T * .05
	var at := func(r: float, an: float, y := 0.0) -> Vector3: return Vector3(it.x + cos(an) * r * u, it.y + y * u, it.z + sin(an) * r * u)
	var bl := []
	var A: Vector3 = at.call(1.28, th)
	var B: Vector3 = at.call(1.72, th + PI)
	bl.append({"star": true, "pos": A, "r": .62, "c": [1, .94, .68]})
	bl.append({"star": true, "pos": B, "r": .46, "c": [1, .62, .3]})
	var an := T * .4 + 1.1
	bl.append({"pos": Vector3(A.x + cos(an) * 1.15 * u, A.y + .05 * u, A.z + sin(an) * 1.15 * u), "r": .26, "part": ALPHA_PL.giant})
	var P0: Vector3 = at.call(3.5, th * .4 + 3.9)
	bl.append({"star": true, "pos": P0, "r": .16, "c": [1, .3, .2]})
	var pl := [[.31, .075, "b", 2.1], [.44, .066, "c", 1.3], [.6, .06, "d", .8]]
	for i in 3:
		var e: Array = pl[i]
		var a2: float = T * e[3] * .25 + i * 2.1
		bl.append({"pos": Vector3(P0.x + cos(a2) * e[0] * u, P0.y, P0.z + sin(a2) * e[0] * u), "r": e[1], "part": ALPHA_PL[e[2]]})
	for o in bl: o.d = dist2(o.pos.x, o.pos.y, o.pos.z)
	bl.sort_custom(func(a, b): return a.d > b.d)
	for o in bl:
		if o.get("star", false):
			var g := VB.new()
			var a := VB.new()
			quad(g, billboard(o.pos, o.r * u * 3, o.r * u * 3), UV1, rgba(o.c, .55))
			quad(a, billboard(o.pos, o.r * u, o.r * u), UV1, rgba(o.c, 1))
			flush("q", g, null, 3)
			flush("q", a, null, 7)
		else: drawRock(o.pos, o.r * u, o.part)

# ---------------- one frame ----------------
func _process(dt: float) -> void:
	if not on: return
	if Game.settings.get("anim", true): T += dt
	frame()

var prof := false
var _t0 := 0
var _tms := {}
func _tm(k: String) -> void:
	if not prof: return
	var t := Time.get_ticks_usec()
	_tms[k] = _tms.get(k, 0) + (t - _t0)
	_t0 = t
func frame() -> void:
	if Game.G == null: return
	_t0 = Time.get_ticks_usec()
	ensure()
	if MODELS.is_empty(): _build_models()
	var S := LAY.S
	var G = Game.G
	var D: Dictionary = Game.data.D
	var GEO: Dictionary = board.geo_std
	setupCam()
	if _rec_ver != _ver:
		board.record(self)
		for r in rec:
			var q := mapP(r.x, r.y)
			r.X = q.x
			r.Z = q.y
		_rec_ver = _ver
	_tm("rec")
	var px := pxw(C.dist)
	picks = []
	for h in _mused: h.visible = false
	_mused = []
	_mcount = {}
	# 1 sky
	if not _sky_ok:
		flush("q", _static.sky, null, 4, {"PT": 2.4}, Mesh.PRIMITIVE_POINTS)
	# 2 belts, orbit rings, spokes
	for b in LAY.BELTS: flush("q", _static["belt_" + b.k], null, 4, {"PT": clampf(9000 / maxf(900, C.dist), 1.8, 7)}, Mesh.PRIMITIVE_POINTS)
	var rw := maxf(9, px * 1.5)
	var rkey := snappedf(rw, rw * .04)
	if _static.get("rings_key") != rkey:
		var a := VB.new()
		for rg in LAY.rings + [{"r": LAY.pods.sca.ring}]: ribbon(a, circlePts(0, 0, rg.r, 160), true, rw, 1, Color(.31, .76, .85, .3))
		for k in 12:
			var an := k / 12.0 * 6.2832
			ribbon(a, [Vector2(cos(an) * 700, sin(an) * 700), Vector2(cos(an) * 19000, sin(an) * 19000)], false, rw * .55, .5, Color(.31, .76, .85, .08))
		_static.rings = a.mesh()
		_static.rings_key = rkey
	flush("q", _static.rings, null, 1)
	# 3 pod plates: a dark glass floor with a faint grid under each system
	if not _static.has("plates"):
		var a := VB.new()
		for k in LAY.pods:
			if k == "sun": continue
			var r: Array = LAY.pods[k].rect
			var i := 6.0
			quad(a, [Vector3(r[0] + i, 0, r[1] + i), Vector3(r[2] - i, 0, r[1] + i), Vector3(r[2] - i, 0, r[3] - i), Vector3(r[0] + i, 0, r[3] - i)], [(r[0] + i) / 160, (r[1] + i) / 160, (r[2] - i) / 160, (r[3] - i) / 160], Color(.02, .05, .09, .8))
		_static.plates = a.mesh()
	flush("q", _static.plates, null, 10)
	_tm("static")
	drawBeltLinks(S, px)
	_tm("links")
	if C.dist < 26000:
		drawBoxes()
		_tm("boxes")
		drawWorlds(S, px)
		_tm("worlds")
	flushc("frames", snappedf(px, px * .05), func():
		var fr := VB.new()
		for k in LAY.pods:
			if k == "sun": continue
			var r: Array = LAY.pods[k].rect
			var i := 14.0
			ribbon(fr, [Vector2(r[0] + i, r[1] + i), Vector2(r[2] - i, r[1] + i), Vector2(r[2] - i, r[3] - i), Vector2(r[0] + i, r[3] - i)], true, maxf(5, px * 1.2), .6, Color(.31, .76, .85, .22))
		return fr, null, 1)
	_tm("frames")
	# 4 the Sun
	var SR := LAY.sunR
	var sy := SR * .35
	var sa := VB.new()
	var sg := VB.new()
	quad(sg, billboard(Vector3(0, sy, 0), SR * 3.4, SR * 3.4), UV1, Color(1, .62, .2, .85))
	flush("q", sg, null, 3)
	quad(sa, billboard(Vector3(0, sy, 0), SR, SR), UV1, WHITE)
	flush("q", sa, null, 7)
	var sc = proj(0, sy, 0)
	var se = proj(rgt.x * SR, sy + rgt.y * SR, rgt.z * SR)
	if sc != null and se != null: picks.append({"sx": sc[0], "sy": sc[1], "pr": Vector2(se[0] - sc[0], se[1] - sc[1]).length(), "hit": {"t": "world", "k": "sun"}, "z": sc[2], "planet": true})
	# 5 ground decorations: selections, rings, drag targets (they change with the game state)
	var gr = _cache.get("ground")
	if gr == null or gr.sig != _ver:
		var ga := VB.new()
		var gfill := VB.new()
		_ground(ga, gfill, S)
		gr = {"sig": _ver, "fill": gfill.mesh() if gfill.size() else null, "line": ga.mesh() if ga.size() else null}
		_cache["ground"] = gr
	if gr.fill != null: flush("q", gr.fill, null, 1)
	if gr.line != null: flush("q", gr.line, null, 1)
	_tm("ground")
	# 6 flat sprites (world cards, base counters, trade markers)
	var stand := []
	for r in rec:
		if r.mode == "stand": stand.append(r)
	var fl = _cache.get("flat")
	if fl == null or fl.sig != _ver:
		var lst := []
		for r in rec:
			if r.mode == "stand": continue
			var a := VB.new()
			flatQuad(a, r.X, r.Z, r.w * S, r.h * S, r.a, 6.0 if r.text else 4.0, _uv(r), WHITE)
			lst.append({"tex": r.tex, "mode": 0, "verts": a})
		# merge consecutive sprites that share a texture (batch), then keep the meshes
		var calls := []
		for it in lst:
			if calls.size() and calls[calls.size() - 1].tex == it.tex: calls[calls.size() - 1].vb.add(it.verts)
			else:
				var vb := VB.new()
				vb.add(it.verts)
				calls.append({"tex": it.tex, "vb": vb})
		for c in calls: c.mesh = c.vb.mesh()
		fl = {"sig": _ver, "calls": calls}
		_cache["flat"] = fl
	for c in fl.calls: flush("q", c.mesh, c.tex, 0)
	_tm("flat")
	# 7 standing items, far to near: planets, models, counters, labels
	var items := []
	for k in bodies.b:
		var b: Dictionary = bodies.b[k]
		var m: Array = GEO.maps[b.map]
		var q := mapP(m[0] + b.cx * .4, m[1] + b.cy * .4)
		var r: float = b.r * .4 * S
		var y := r * .55
		items.append({"t": "planet", "k": k, "b": b, "x": q.x, "y": y, "z": q.y, "r": r, "d": dist2(q.x, y, q.y)})
	for k in GEO.worlds:
		if bodies.b.has(k): continue
		var kind = "rocks" if MODELS.has(k) else ("deep" if k == "dsa" else ("stars" if k == "alp" else null))
		if kind == null or not D.W.has(k): continue
		var pod = podOfW(k)
		if pod == null: continue
		var Rg := ringOf(k)
		var c := mapP(Rg.c.x, Rg.c.y, pod)
		var u: float = Rg.r * S * .26
		var y := u * .75
		items.append({"t": "model", "k": k, "kind": kind, "spec": MODELS.get(k), "x": c.x, "z": c.y, "u": u, "y": y, "d": dist2(c.x, y, c.y)})
	if LAY.pods.has("sca"):
		var hp: Dictionary = LAY.pods.sca
		var c := mapP(hp.hub[0], hp.hub[1], hp)
		var u := 18.0
		var y := u * .75
		items.append({"t": "model", "k": "sca", "kind": "rocks", "spec": MODELS.sca, "x": c.x, "z": c.y, "u": u, "y": y, "d": dist2(c.x, y, c.y)})
	for r in stand:
		var y: float = r.lift * S + r.h * S / 2
		items.append({"t": "spr", "r": r, "d": dist2(r.X, y, r.Z)})
	items.sort_custom(func(a, b): return a.d > b.d)
	var shad := VB.new()
	for it in items:
		if it.t == "planet": flatQuad(shad, it.x, it.z, it.r * 2.1, it.r * 1.2, 0, 1.6, UV1, Color(0.039, 0.039, 0.043, .38))
		elif it.t == "model": flatQuad(shad, it.x, it.z, it.u * 4.6, it.u * 2.8, 0, 1.6, UV1, Color(0.039, 0.039, 0.043, .3))
		elif not it.r.text: flatQuad(shad, it.r.X, it.r.Z, it.r.w * S * .9, it.r.w * S * .5, 0, 1.6, UV1, Color(0.039, 0.039, 0.043, .4))
	flush("q", shad, null, 2)
	var run := []
	var B: Dictionary = bodies
	var bt: Texture2D = _tex.bodies
	for it in items:
		if it.t == "planet":
			batch(run)
			run = []
			var a := VB.new()
			var R: Vector3 = rgt * it.r
			var U: Vector3 = cup * it.r
			var p := Vector3(it.x, it.y, it.z)
			quad(a, [p - R + U, p + R + U, p + R - U, p - R - U], UV1, WHITE)
			var Ld := (-Vector3(it.x, 0, it.z)).normalized()
			flush("p", a, null, 0, {"T": bt, "AW": float(bt.get_width()), "AH": float(bt.get_height()), "TW": float(B.tw), "TH": float(B.th), "DS": float(B.ds), "row": float(it.b.row),
				"rot": 0.0 if it.b.spd == 0 else fmod(T * 6.2832 / it.b.spd, 6.2832), "L": Vector3(Ld.dot(rgt), Ld.dot(cup) * .6 + .25, .55)})
			if RING3.has(it.k):
				var rg: Dictionary = RING3[it.k]
				var N: Vector3 = rg.n.normalized()
				var ax: Vector3 = N.cross(Vector3.RIGHT if absf(N.x) < .9 else Vector3.FORWARD).normalized()
				var bx: Vector3 = N.cross(ax).normalized()
				var ro: float = it.r * rg.out
				var rv := VB.new()
				quad(rv, [p - ax * ro + bx * ro, p + ax * ro + bx * ro, p + ax * ro - bx * ro, p - ax * ro - bx * ro], UV1, WHITE)
				flush("g", rv, null, 0, {"C": p, "R": float(it.r), "N": N, "EYE": eye, "LS": Ld, "kind": int(rg.kind)})
			var c = proj(it.x, it.y, it.z)
			var e = proj(it.x + rgt.x * it.r, it.y + rgt.y * it.r, it.z + rgt.z * it.r)
			if c != null and e != null and D.W.has(it.k): picks.append({"sx": c[0], "sy": c[1], "pr": Vector2(e[0] - c[0], e[1] - c[1]).length(), "hit": {"t": "world", "k": it.k}, "z": c[2], "planet": true})
		elif it.t == "model":
			batch(run)
			run = []
			if it.kind == "deep": drawDeep(it)
			elif it.kind == "stars": drawStars(it)
			else: drawModel(it)
			var ext: float = it.u * (3.4 if it.kind == "deep" else (4.4 if it.k == "alp" else 2.4))
			var c = proj(it.x, it.y, it.z)
			var e = proj(it.x + rgt.x * ext, it.y + rgt.y * ext, it.z + rgt.z * ext)
			if c != null and e != null and GEO.worlds.has(it.k) and D.W.has(it.k) and G.w.get(it.k) != null: picks.append({"sx": c[0], "sy": c[1], "pr": Vector2(e[0] - c[0], e[1] - c[1]).length(), "hit": {"t": "world", "k": it.k}, "z": c[2], "planet": true})
		else:
			var r: Dictionary = it.r
			if r.get("model", false):
				batch(run)
				run = []
				_ship(r, S)
				continue
			var w: float = r.w * S
			var h: float = r.h * S
			var hw := w / 2
			var l: float = r.lift * S
			var bob := 0.0 if r.text else sin(T * 1.3 + r.x * .013 + r.y * .017) * 3 * S
			var bx: float = r.X
			var by := l + bob
			var bz: float = r.Z
			var uh := cup * h
			var P := [Vector3(bx - rgt.x * hw + uh.x, by + uh.y, bz - rgt.z * hw + uh.z), Vector3(bx + rgt.x * hw + uh.x, by + uh.y, bz + rgt.z * hw + uh.z), Vector3(bx + rgt.x * hw, by, bz + rgt.z * hw), Vector3(bx - rgt.x * hw, by, bz - rgt.z * hw)]
			var a := VB.new()
			quad(a, P, _uv(r), WHITE)
			run.append({"tex": r.tex, "mode": 0, "verts": a})
			if not r.text:
				var c = proj(bx + cup.x * h / 2, by + cup.y * h / 2, bz + cup.z * h / 2)
				var e = proj(bx + rgt.x * hw + cup.x * h / 2, by + cup.y * h / 2, bz + rgt.z * hw + cup.z * h / 2)
				if c != null and e != null: picks.append({"sx": c[0], "sy": c[1], "pr": Vector2(e[0] - c[0], e[1] - c[1]).length(), "x": r.x, "y": r.y, "z": c[2], "rec": r})
	batch(run)
	_tm("stand")
	# 8 labels for every system, constant size on screen, fading out when you are close
	var la := VB.new()
	var d0 := []
	var lab := func(name: String, x: float, z: float, key, big: bool):
		var dd := sqrt(dist2(x, 0, z))
		var pod = LAY.pods.get(key) if key != null else null
		var ext: float = maxf(pod.rect[2] - pod.rect[0], pod.rect[3] - pod.rect[1]) if pod != null else 600.0
		var al := clampf((dd - ext * .9) / (ext * .9), 0, 1)
		if al <= 0: return
		var e := paint.label(name)
		var ph := pxw(dd)
		var h := (22.0 if big else 17.0) * ph
		var w: float = h * e.w / e.h
		var y := 10 * ph + 6 * ph
		var Pq := [Vector3(x - rgt.x * w / 2 + cup.x * h, y + cup.y * h, z - rgt.z * w / 2 + cup.z * h), Vector3(x + rgt.x * w / 2 + cup.x * h, y + cup.y * h, z + rgt.z * w / 2 + cup.z * h), Vector3(x + rgt.x * w / 2, y, z + rgt.z * w / 2), Vector3(x - rgt.x * w / 2, y, z - rgt.z * w / 2)]
		var v := VB.new()
		quad(v, Pq, paint.uv_of(e), Color(1, 1, 1, al))
		d0.append({"tex": paint.atlas_tex(), "mode": 0, "verts": v})
		flatQuad(la, x, z, 9 * ph, 9 * ph, 0, 3, UV1, Color(.55, .9, 1, al))
		var s0 = proj(x, y + h / 2, z)
		if s0 != null and al > .3: picks.append({"sx": s0[0], "sy": s0[1], "pr": maxf(h / ph * .5, w / ph * .5), "hit": {"t": "pod", "k": key} if key != null else null, "z": 0.0, "label": true})
	for k in LAY.pods:
		if k == "sun": continue
		var p: Dictionary = LAY.pods[k]
		var q := mapP(p.hub[0], p.hub[1], p)
		lab.call(String(p.name).to_upper(), q.x, q.y, k, false)
	lab.call("SUN", 0, 0, "mer", true)
	batch(d0)
	flush("q", la, null, 2)
	_tm("labels")
	_submit()
	_tm("submit")

func _ground(ga: VB, gfill: VB, S: float) -> void:
	var mapShape := func(pts: Array) -> Array:
		var cc := Vector2.ZERO
		for p in pts: cc += Vector2(p[0], p[1]) if p is Array else p
		cc /= pts.size()
		var pod := LAY.podAt(cc.x, cc.y)
		var out := []
		for p in pts:
			var v: Vector2 = Vector2(p[0], p[1]) if p is Array else p
			out.append(mapP(v.x, v.y, pod))
		return out
	for g in gfx:
		var c := col(g.color)
		if g.k == "ring":
			var q := mapP(g.x, g.y)
			ribbon(ga, circlePts(q.x, q.y, g.r * S, 40), true, g.w * 1.4 * S, 3, c)
		elif g.k == "poly":
			var pts: Array = mapShape.call(g.pts)
			if g.fill != null: fillPoly(gfill, pts, 2.5, col(g.fill))
			ribbon(ga, pts, true, g.w * 1.4 * S, 3, c)
	if board.targets.size():
		var seen := {}
		var dests := {}
		for m in board.targets: dests[m.dest] = true
		for m in board.targets:
			if seen.has(m.dest): continue
			seen[m.dest] = true
			var p := Game.E.P(m.dest)
			var z: Dictionary = board.zone_shape(m.dest, p.t == "orbit" and dests.has("surf:" + str(p.w)))
			var raw: Array = Array(z.poly) if z.has("poly") else circlePts(z.c.x, z.c.y, z.r, 36)
			var pts: Array = BOXSH[m.dest] if BOXSH.has(m.dest) else mapShape.call(raw)
			fillPoly(gfill, pts, 2.6, Color(.31, .76, .85, .2))
			ribbon(ga, pts, true, 7 * S, 3.2, Color(.31, .76, .85, .95))
			if z.get("hole") != null: ribbon(ga, mapShape.call(Array(z.hole)), true, 5 * S, 3.2, Color(.31, .76, .85, .8))

func _uv(r: Dictionary) -> Array:
	var iw: float = r.get("tw", r.tex.get_width())
	var ih: float = r.get("th", r.tex.get_height())
	var f: Array = r.f
	return [f[0] / iw, f[1] / ih, (f[0] + f[2]) / iw, (f[1] + f[3]) / ih]

# ---------------- picking ----------------
## a point on the board under a screen position, in the board's own (flat map) coordinates, or null
func sheetAt(sx: float, sy: float):
	var g = ground(sx, sy, 0)
	if g == null or LAY == null: return null
	var q = LAY.fromL(g.x, g.y)
	return Vector2(q[0], q[1]) if q != null else null
## what is under a screen position: counters first, then worlds, then system labels; then the flat board's hits
func pick(sx: float, sy: float) -> Dictionary:
	var best = null
	for p in picks:
		if Vector2(sx - p.sx, sy - p.sy).length() > maxf(p.pr, 9): continue
		var hit = p.hit if (p.get("planet", false) or p.get("label", false)) else (p.rec.get("hit") if p.has("rec") else null)
		if hit == null: continue
		var tier := 2 if p.get("label", false) else (1 if p.get("planet", false) else 0)
		if best == null or tier < best.tier or (tier == best.tier and p.z < best.z): best = {"z": p.z, "hit": hit, "tier": tier}
	if best != null: return {"hit": best.hit, "p": null}
	var g = sheetAt(sx, sy)
	return {"hit": board.hit_at_world(g) if g != null else null, "p": g}


# ---------------- ship counters as 3D models, each with a faction flag ----------------
func _ship_node(f: String, img: String, col: Color, robo: bool) -> Dictionary:
	var kn := img.split("|")
	var kind: String = kn[0]
	var nm: String = kn[1] if kn.size() > 1 else ""
	var m: Node3D = UnitModels.build(f, nm, kind)
	var rad: float = float(m.get_meta("radius", 1.0))
	var holder := Node3D.new()
	var pivot := Node3D.new()
	holder.add_child(pivot)
	pivot.add_child(m)
	# opaque-looking, but in the transparent pass so the painter's-order sorting above puts it in the right layer
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi
		inst.sorting_use_aabb_center = false
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if inst.material_override != null:
			var mo = _shipmat(inst.material_override)
			if mo != null: inst.material_override = mo
		if inst.mesh == null: continue
		for si in inst.mesh.get_surface_count():
			var mt := inst.get_active_material(si)
			var d = _shipmat(mt)
			if d != null: inst.set_surface_override_material(si, d)
	# the flag: a mast and a faction-coloured pennant (crew vehicles) or flag (robotic explorers), facing the camera
	var flag := Node3D.new()
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = col
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(.95, .96, 1.0)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = .018
	cm.bottom_radius = .018
	cm.height = 1.0
	mast.mesh = cm
	mast.material_override = bm
	mast.position = Vector3(0, .5, 0)
	flag.add_child(mast)
	var fl := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = [Vector3(0, 1, 0), Vector3(.62, 1, 0), Vector3(.5, .84, 0), Vector3(.62, .68, 0), Vector3(0, .68, 0)] if not robo else [Vector3(0, 1, 0), Vector3(.5, 1, 0), Vector3(.5, .66, 0), Vector3(0, .66, 0)]
	for i in range(1, pts.size() - 1):
		for k in [0, i, i + 1]:
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(pts[k])
	fl.mesh = st.commit()
	fl.material_override = fm
	flag.add_child(fl)
	# a thin white edge so the flag reads against dark space and against the ship's own colour
	var edge := MeshInstance3D.new()
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pe: Array = [Vector3(0, 1.04, -.003), Vector3(.66, 1.04, -.003), Vector3(.66, .64, -.003), Vector3(0, .64, -.003)]
	for i in range(1, pe.size() - 1):
		for k in [0, i, i + 1]:
			st2.set_normal(Vector3(0, 0, 1))
			st2.add_vertex(pe[k])
	edge.mesh = st2.commit()
	edge.material_override = bm
	flag.add_child(edge)
	for mi2 in [mast, fl, edge]:
		mi2.sorting_use_aabb_center = false
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(flag)
	_mroot.add_child(holder)
	return {"h": holder, "p": pivot, "m": m, "flag": flag, "rad": rad, "meshes": holder.find_children("*", "MeshInstance3D", true, false)}

## a copy of a model material for the map: in the transparent pass (so the painter's-order sorting layers it) and with the metal turned down
func _shipmat(mt: Material):
	if not (mt is BaseMaterial3D): return null
	var d: BaseMaterial3D = mt.duplicate()
	d.metallic = minf(d.metallic, .3)  # there is no reflected scene to metal against out here
	d.roughness = maxf(d.roughness, .45)
	if d.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED: d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	return d

func _ship(r: Dictionary, S: float) -> void:
	var key: String = "%s|%s|%s" % [r.mf, r.img, r.col]
	var lst: Array = _mpool.get(key, [])
	var n: int = _mcount.get(key, 0)
	_mcount[key] = n + 1
	if lst.size() <= n:
		var kind: String = String(r.img).split("|")[0]
		lst.append(_ship_node(r.mf, r.img, Color(r.col), RoboModels.has(kind)))
		_mpool[key] = lst
	var e: Dictionary = lst[n]
	var h: Node3D = e.h
	var rw: float = r.w * S
	var want: float = rw * .5 * (1.0 if r.small else 1.55)
	var sc: float = want / maxf(e.rad, .05)
	var bob := sin(T * 1.3 + r.x * .013 + r.y * .017) * 3 * S
	var y: float = r.lift * S + rw * .5 + bob
	h.position = Vector3(r.X, y, r.Z)
	h.visible = true
	# nose to the right of the screen, rolled a little towards the camera, drifting gently
	# the ship keeps its heading in the world (it does not turn with the camera); its facing can be flipped on the Selected tab
	var robo: bool = RoboModels.has(String(r.img).split("|")[0])
	var yaw := (PI if int(r.get("face", 1)) < 0 else 0.0) + (PI / 2 if robo else 0.0) + sin(T * .5 + r.x * .02) * .18
	# seen from the side, like the printed counter, with just a little of the top: the ship leans back by the camera's pitch
	e.p.basis = Basis(Vector3.RIGHT, -(C.pitch - .3)) * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * sc)
	var fh: float = rw * (.35 if r.small else .55)
	e.flag.basis = Basis(rgt, cup, rgt.cross(cup)) * Basis.from_scale(Vector3.ONE * fh)
	e.flag.position = cup * (want * .42) + rgt * (-want * .15)
	var off: float = _calls.size() * 100000.0 - 50000.0
	for mi in e.meshes: (mi as MeshInstance3D).sorting_offset = off
	_mused.append(h)
	var c = proj(r.X, y, r.Z)
	var e2 = proj(r.X + rgt.x * rw * .5, y, r.Z + rgt.z * rw * .5)
	if c != null and e2 != null: picks.append({"sx": c[0], "sy": c[1], "pr": maxf(Vector2(e2[0] - c[0], e2[1] - c[1]).length(), 6.0), "x": r.x, "y": r.y, "z": c[2], "rec": r})
