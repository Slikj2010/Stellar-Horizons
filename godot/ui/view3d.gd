## The 3D view: the board cut into one tile ("pod") per system, set on orbit rings round a glowing Sun, with the
## Main and Kuiper Belts as rings of rocks, turning 3D planets over their printed discs and a starfield all round.
## The pods show a live render of the flat board (counters, cards, markers and highlights included), so everything
## the flat map shows is also here, and clicks, hovering and dragging work the same way.
## Left-drag pans, right-drag turns the view, the wheel zooms. Layout: layout3d.gd (a port of layout25.js).
extends Node3D

const SC := 0.5  ## board render scale (board units -> texture pixels)
const FOV := 41.0
var main: Node
var board: Node2D
var L := SHLayout3D.new()
var vp: SubViewport
var cam: Camera3D
var on := false
var map_r := Rect2()
var target := Vector3.ZERO
var yaw := 0.0
var pitch := 0.98
var dist := 9000.0
var planets: Array = []  ## [MeshInstance3D, seconds per turn, board centre]
var t := 0.0
var _tw: Tween
var _board_parent: Node
var _board_index := 0
var _glow_tex: Texture2D

func setup(m: Node) -> void:
	main = m
	board = m.board
	map_r = board.map_rect()
	var S: Dictionary = board._json("res://data/sun.json")
	var ms: Array = board.geo.maps[S.map]
	L.build(board.geo, Game.data.D, Vector2(ms[0] + S.cx * 0.4, ms[1] + S.cy * 0.4))
	visible = false
	# the board is drawn into this viewport while the 3D view is on
	vp = SubViewport.new()
	vp.size = Vector2i(ceili(map_r.end.x * SC), ceili(map_r.end.y * SC))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	vp.canvas_transform = Transform2D(0.0, Vector2(SC, SC), 0.0, Vector2.ZERO)
	_glow_tex = _radial(Color(1, 1, 1, 1))
	_build_env()
	_build_sun()
	_build_pods()
	_build_rings()
	_build_belts()
	_build_stars()
	_build_planets()
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 10.0
	cam.far = 160000.0
	add_child(cam)
	_place_cam()

# ---------------- building the scene ----------------
func _radial(c: Color) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([c, Color(c, c.a * 0.45), Color(c, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	return gt

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.45)
	env.ambient_light_energy = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_sun() -> void:
	var R: float = L.sun_r
	var y := R * 0.35
	var sp := SphereMesh.new()
	sp.radius = R * 0.62
	sp.height = R * 1.24
	sp.radial_segments = 48
	sp.rings = 24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.78, 0.42)
	var mi := MeshInstance3D.new()
	mi.mesh = sp
	mi.material_override = mat
	mi.position = Vector3(0, y, 0)
	add_child(mi)
	for g in [[R * 3.4, Color(1, 0.62, 0.2, 0.85)], [R * 1.5, Color(1, 0.86, 0.6, 0.9)]]:
		var s3 := Sprite3D.new()
		s3.texture = _glow_tex
		s3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s3.modulate = g[1]
		s3.pixel_size = g[0] * 2.0 / 256.0
		s3.shaded = false
		s3.transparent = true
		s3.no_depth_test = false
		s3.position = Vector3(0, y, 0)
		var m2 := StandardMaterial3D.new()
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m2.albedo_texture = _glow_tex
		m2.albedo_color = g[1]
		m2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m2.vertex_color_use_as_albedo = true
		s3.material_override = m2
		add_child(s3)
	var light := OmniLight3D.new()
	light.position = Vector3(0, y, 0)
	light.omni_range = 40000.0
	light.omni_attenuation = 0.25
	light.light_energy = 2.0
	light.light_color = Color(1.0, 0.93, 0.84)
	add_child(light)

func _build_pods() -> void:
	var tex := vp.get_texture()
	for k in L.pods:
		if k == "sun": continue
		var p: Dictionary = L.pods[k]
		var r: Rect2 = p.rect
		var bb: Rect2 = p.bbox
		# dark backing plate
		var back := MeshInstance3D.new()
		var bm := PlaneMesh.new()
		bm.size = r.size - Vector2(12, 12)
		back.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.albedo_color = Color(0.02, 0.05, 0.09, 0.8)
		back.material_override = bmat
		back.position = Vector3(r.get_center().x, -2.0, r.get_center().y)
		add_child(back)
		# the live board art
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = r.size
		mi.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var full := Vector2(vp.size) / SC
		mat.uv1_scale = Vector3(bb.size.x / full.x, bb.size.y / full.y, 1)
		mat.uv1_offset = Vector3(bb.position.x / full.x, bb.position.y / full.y, 0)
		mi.material_override = mat
		mi.position = Vector3(r.get_center().x, 0, r.get_center().y)
		add_child(mi)
		# a thin cyan frame and the system's name
		var fr := _line_loop([Vector2(r.position.x + 14, r.position.y + 14), Vector2(r.end.x - 14, r.position.y + 14), Vector2(r.end.x - 14, r.end.y - 14), Vector2(r.position.x + 14, r.end.y - 14)], 1.0, Color(0.31, 0.76, 0.85, 0.35))
		add_child(fr)
		var lb := Label3D.new()
		lb.text = String(p.name).to_upper()
		lb.font = load("res://assets/fonts/InterDisplay-Bold.otf")
		lb.font_size = 72
		lb.outline_size = 14
		lb.modulate = Color(0.85, 0.92, 1.0, 0.9)
		lb.outline_modulate = Color(0, 0, 0, 0.8)
		lb.pixel_size = 1.6
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = Vector3(r.get_center().x, 60, r.position.y - 30)
		add_child(lb)

func _line_loop(pts: Array, y: float, col: Color) -> MeshInstance3D:
	var am := ArrayMesh.new()
	var v := PackedVector3Array()
	for q in pts + [pts[0]]: v.append(Vector3(q.x, y, q.y))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	return mi

func _build_rings() -> void:
	for k in L.pods:
		var p: Dictionary = L.pods[k]
		if not p.ring or p.sat or k in ["bel", "kui", "sca", "alp"]: continue
		var pts := []
		for i in 256: pts.append(Vector2(cos(i * TAU / 256), sin(i * TAU / 256)) * p.ring)
		add_child(_line_loop(pts, -4.0, Color(0.31, 0.76, 0.85, 0.16)))

func _points(v: PackedVector3Array, c: PackedColorArray, size: float) -> MeshInstance3D:
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	am.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.use_point_size = true
	mat.point_size = size
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	return mi

func _build_belts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4900
	for B in L.BELTS:
		var v := PackedVector3Array()
		var c := PackedColorArray()
		var n: int = int(B.n / 2)
		for i in n:
			var a := rng.randf() * TAU
			# denser in the middle of the band
			var u := (rng.randf() + rng.randf()) / 2.0
			var rr: float = lerpf(B.r0, B.r1, u)
			v.append(Vector3(cos(a) * rr, rng.randf_range(-60, 60), sin(a) * rr))
			var col: Color = B.col
			col.a = rng.randf_range(0.35, 0.9)
			c.append(col.lightened(rng.randf_range(-0.2, 0.2)))
		add_child(_points(v, c, 2.0))

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20300
	for layer in [[2600, 1.5], [500, 2.6]]:
		var v := PackedVector3Array()
		var c := PackedColorArray()
		for i in layer[0]:
			var d := Vector3(rng.randfn(), rng.randfn() * 0.6, rng.randfn()).normalized()
			v.append(d * 90000.0)
			var col := Color.WHITE
			if rng.randf() < 0.12: col = Color("#ffd9a8") if rng.randf() < 0.5 else Color("#a8c8ff")
			col.a = rng.randf_range(0.25, 0.95)
			c.append(col)
		add_child(_points(v, c, layer[1]))

func _build_planets() -> void:
	var bj: Dictionary = board._json("res://assets/bodies.json")
	var tex: Texture2D = load("res://assets/bodies.png")
	var AW := float(tex.get_width())
	var AH := float(tex.get_height())
	var pshader: Shader = load("res://ui/shaders/planet3d.gdshader")
	for k in bj.b:
		var o: Dictionary = bj.b[k]
		var m: Array = board.geo.maps[o.map]
		var c := Vector2(m[0] + o.cx * 0.4, m[1] + o.cy * 0.4)
		var q: Vector2 = L.to_scene(c)
		var r: float = o.r * 0.4 * L.S
		var sp := SphereMesh.new()
		sp.radius = r
		sp.height = r * 2
		sp.radial_segments = 48
		sp.rings = 24
		var mat := ShaderMaterial.new()
		mat.shader = pshader
		mat.set_shader_parameter("atlas", tex)
		mat.set_shader_parameter("row", float(o.row))
		mat.set_shader_parameter("AW", AW)
		mat.set_shader_parameter("AH", AH)
		mat.set_shader_parameter("TW", float(bj.tw))
		mat.set_shader_parameter("TH", float(bj.th))
		var mi := MeshInstance3D.new()
		mi.mesh = sp
		mi.material_override = mat
		mi.position = Vector3(q.x, r * 1.05, q.y)
		add_child(mi)
		# a soft shadow on the tile under it
		var sh := Sprite3D.new()
		sh.texture = _radial(Color(0, 0, 0, 0.55))
		sh.pixel_size = r * 2.6 / 256.0
		sh.axis = Vector3.AXIS_Y
		sh.shaded = false
		sh.position = Vector3(q.x, 2.0, q.y)
		add_child(sh)
		planets.append([mi, float(o.spd), c, r])

# ---------------- turning on and off ----------------
func enable(v: bool) -> void:
	if v == on: return
	on = v
	if v:
		_board_parent = board.get_parent()
		_board_index = board.get_index()
		_board_parent.remove_child(board)
		vp.add_child(board)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		visible = true
		cam.make_current()
	else:
		vp.remove_child(board)
		_board_parent.add_child(board)
		_board_parent.move_child(board, _board_index)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		visible = false
		cam.clear_current(false)
		main.cam.make_current()

func _process(dt: float) -> void:
	if not on: return
	if Game.settings.get("anim", true): t += dt
	for p in planets: (p[0] as Node3D).rotation.y = fmod(t * TAU / p[1], TAU)

# ---------------- camera ----------------
func _place_cam() -> void:
	var cp := cos(pitch)
	var sp := sin(pitch)
	cam.position = target + Vector3(dist * cp * sin(yaw), dist * sp, dist * cp * cos(yaw))
	cam.look_at(target, Vector3.UP)

## the ground point (y = h) under a screen point, as scene (x, z), or null
func ground(sp: Vector2, h := 0.0):
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if d.y > -1e-4: return null
	var s := (h - o.y) / d.y
	var g := o + d * s
	return Vector2(g.x, g.z)

## the board point under a screen point (planets first), or null
func board_point(sp: Vector2):
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var best = null
	var bt := 1e18
	for p in planets:
		var c: Vector3 = (p[0] as Node3D).position
		var r: float = p[3]
		var oc := o - c
		var b := oc.dot(d)
		var disc := b * b - (oc.dot(oc) - r * r)
		if disc < 0: continue
		var tt := -b - sqrt(disc)
		if tt > 0 and tt < bt:
			bt = tt
			best = p[2]
	if best != null: return best
	var g = ground(sp)
	if g == null: return null
	return L.from_scene(g)

func zoom_at(factor: float, sp: Vector2) -> void:
	var g = ground(sp)
	var nd := clampf(dist / factor, 350.0, 60000.0)
	var k := nd / dist
	if g != null:
		var gv := Vector3(g.x, 0, g.y)
		target = gv + (target - gv) * k
	dist = nd
	_place_cam()

func pan_screen(rel: Vector2) -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var per_px := 2.0 * dist * tan(deg_to_rad(FOV) / 2.0) / vh
	var right := cam.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	target -= right * rel.x * per_px
	target += fwd * rel.y * per_px / maxf(0.3, sin(pitch))
	_place_cam()

func rotate_view(rel: Vector2) -> void:
	yaw -= rel.x * 0.006
	pitch = clampf(pitch + rel.y * 0.004, 0.22, 1.5)
	_place_cam()

## glide to a board point; z is the flat map's zoom (bigger = closer)
func fly_to(p: Vector2, z := -1.0) -> void:
	var q: Vector2 = L.to_scene(p)
	var nd := dist if z <= 0 else clampf(950.0 / z, 350.0, 60000.0)
	if _tw: _tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_method(func(f: float):
		target = target.lerp(Vector3(q.x, 0, q.y), f)
		dist = lerpf(dist, nd, f)
		_place_cam(), 0.0, 1.0, 0.5)

## the whole solar system
func overview() -> void:
	if _tw: _tw.kill()
	target = Vector3(0, 0, 1500)
	dist = 30000.0
	pitch = 1.0
	yaw = 0.0
	_place_cam()
