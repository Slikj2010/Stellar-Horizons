## The illustrated title screen, ported from the web version's main menu: the painted picture (station, Earth, Moon and
## the four buttons) with live effects on top: twinkling stars, the pulsing sun, flickering city lights, light pulses
## travelling along the orbit lines, a shimmer across the title, and clouds drifting over the Earth.
class_name TitleScene
extends Control

signal action(k: String)

var M: Dictionary
var ME: Dictionary
var stage: Control
var fx: Control
var _fxtex: Texture2D
var _glow: Texture2D
var _glints: Array = []
var _sats := [{"path": "orbitA", "t": 0.0, "sp": 0.022}, {"path": "orbitB", "t": 0.5, "sp": 0.03}]
var _t := 0.0
var _earth: ColorRect
var _btn_rects: Array = []
var _hover := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	M = _json("res://assets/menu/menu.json")
	ME = _json("res://assets/menu/menu_earth.json")
	_fxtex = load("res://assets/menu/menu_fx.png")
	var g := Gradient.new()
	g.set_color(0, Color(1.000, 0.816, 0.839, 1))
	g.set_color(1, Color(1.000, 0.816, 0.839, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow = gt
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for s in M.stars:
		_glints.append({"x": s[0], "y": s[1], "r": s[2], "ph": rng.randf() * TAU, "sp": 0.5 + rng.randf() * 2.4, "big": rng.randf() < 0.12})
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(M.w, M.h)
	add_child(stage)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/menu/menu.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(M.w, M.h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	# the Earth with its drifting clouds
	_earth = ColorRect.new()
	_earth.position = Vector2(ME.x0, ME.y0)
	_earth.size = Vector2(ME.w, ME.h)
	_earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tx := TextureRect.new()  # the cloud-free globe, drawn by the shader through TEXTURE
	tx.texture = load("res://assets/menu/menu_earth.webp")
	tx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tx.stretch_mode = TextureRect.STRETCH_SCALE
	tx.size = _earth.size
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://ui/shaders/title_earth.gdshader")
	sm.set_shader_parameter("clouds", load("res://assets/menu/menu_clouds.webp"))
	sm.set_shader_parameter("region", Vector2(ME.w, ME.h))
	sm.set_shader_parameter("center", Vector2(M.earth[0] - ME.x0, M.earth[1] - ME.y0))
	sm.set_shader_parameter("radius", float(M.earth[2]))
	sm.set_shader_parameter("sun", Vector3(ME.sun[0], ME.sun[1], ME.sun[2]))
	sm.set_shader_parameter("moon_c", Vector2(M.moon[0] - ME.x0, M.moon[1] - ME.y0))
	sm.set_shader_parameter("moon_r", M.moon[2] * 1.03 + 3.0)
	tx.material = sm
	_earth.color = Color(0.016, 0.020, 0.051, 0)
	_earth.add_child(tx)
	stage.add_child(_earth)
	fx = Control.new()
	fx.size = Vector2(M.w, M.h)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = cm
	fx.draw.connect(_draw_fx)
	stage.add_child(fx)
	for i in M.btn.size():
		var b: Array = M.btn[i]
		var btn := Button.new()
		btn.position = Vector2(b[0], b[1])
		btn.size = Vector2(b[2], b[3])
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var key: String = b[4]
		for st in ["normal", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var hv := StyleBoxFlat.new()
		hv.bg_color = Color(0.3, 0.75, 1.0, 0.12)
		hv.border_color = Color(0.5, 0.85, 1.0, 0.75)
		hv.set_border_width_all(2)
		hv.set_corner_radius_all(10)
		hv.shadow_color = Color(0.3, 0.75, 1.0, 0.35)
		hv.shadow_size = 14
		btn.add_theme_stylebox_override("hover", hv)
		btn.pressed.connect(func(): action.emit(key))
		stage.add_child(btn)
	resized.connect(_layout)
	_layout()

func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else {}

## cover the window while keeping the buttons in view (the picture is anchored to the left)
func _layout() -> void:
	if stage == null: return
	var W := size.x
	var H := size.y
	var ar: float = float(M.w) / float(M.h)
	var w: float
	var h: float
	var x: float
	var y: float
	if W >= H:
		w = maxf(W, H * ar)
		h = w / ar
		x = -(w - W) * 0.4
		y = (H - h) / 2.0
	else:
		h = minf(H, maxf(H * 0.6, W / ar))
		w = h * ar
		x = -minf(w - W, w * 0.045)
		y = (H - h) * 0.42
	stage.position = Vector2(x, y)
	stage.scale = Vector2(w / M.w, w / M.w)

func _process(dt: float) -> void:
	if not visible: return
	if Game.settings.get("anim", true): _t += dt
	if _earth != null:
		var m := (_earth.get_child(0) as TextureRect).material as ShaderMaterial
		m.set_shader_parameter("rot", 2.1 + _t * TAU / 300.0)
	fx.queue_redraw()

static func catmull(pts: Array, t: float) -> Vector2:
	var n := pts.size() - 1
	var f := minf(n - 1e-6, maxf(0.0, t * n))
	var i := int(floor(f))
	var u := f - i
	var p0: Array = pts[maxi(0, i - 1)]
	var p1: Array = pts[i]
	var p2: Array = pts[i + 1]
	var p3: Array = pts[mini(n, i + 2)]
	var out := Vector2.ZERO
	for k in 2:
		var a: float = p0[k]
		var b: float = p1[k]
		var c: float = p2[k]
		var d: float = p3[k]
		var v := 0.5 * ((2 * b) + (-a + c) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (-a + 3 * b - 3 * c + d) * u * u * u)
		out[k] = v
	return out

func _blob(c: Vector2, r: float, col: Color) -> void:
	fx.draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false, col)

func _draw_fx() -> void:
	var t := _t
	var spk := 0.6
	# twinkling stars
	for g in _glints:
		var tw := maxf(0.0, sin(t * g.sp + g.ph))
		var a: float = tw * tw * (0.9 if g.big else 0.55) * spk
		if a < 0.02: continue
		var rr: float = (g.r + 1.5) * (2.2 if g.big else 1.3)
		var c := Vector2(g.x, g.y)
		_blob(c, rr * 2.2, Color(0.86, 0.92, 1.0, a))
		if g.big:
			fx.draw_rect(Rect2(c.x - rr * 4, c.y - 0.5, rr * 8, 1), Color(0.78, 0.88, 1.0, a * 0.5))
			fx.draw_rect(Rect2(c.x - 0.5, c.y - rr * 4, 1, rr * 8), Color(0.78, 0.88, 1.0, a * 0.5))
	# the sun: a pulsing glare with slowly turning rays
	var sp := Vector2(M.sun[0], M.sun[1])
	var pulse := 1.0 + 0.08 * sin(t * 1.3) + 0.04 * sin(t * 3.1)
	_blob(sp, 150.0 * pulse, Color(1.0, 0.8, 0.5, 0.5))
	_blob(sp, 60.0 * pulse, Color(1.0, 0.9, 0.7, 0.35))
	for i in 12:
		var ang := t * 0.05 + TAU / 12.0 * (i + 1)
		var L := 140.0 + 70.0 * sin(t * 0.8 + i * 1.7)
		var dir := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-dir.y, dir.x)
		var a0 := 0.16 + 0.06 * sin(t + i)
		fx.draw_polygon(PackedVector2Array([sp - nrm * 2.5, sp + nrm * 2.5, sp + dir * L]),
			PackedColorArray([Color(1, 0.82, 0.59, a0), Color(1, 0.82, 0.59, a0), Color(1, 0.7, 0.4, 0)]))
	# lens flare ghosts along the sun-to-centre line
	for gh in [[0.35, 18.0, Color(0.47, 0.78, 1.0), 0.10], [0.55, 10.0, Color(1.0, 0.78, 0.47), 0.12], [0.8, 30.0, Color(0.35, 0.63, 1.0), 0.06]]:
		var k: float = gh[0]
		var fp: Vector2 = sp + (Vector2(M.w, M.h) * 0.5 - sp) * k * 1.6
		var cc: Color = gh[2]
		var ga: float = gh[3]
		cc.a = ga * (1.0 + 0.3 * sin(t * 1.3))
		var gr: float = gh[1]
		_blob(fp, gr, cc)
	# the Earth's city lights flicker
	var ci: Array = M.city
	var ca := 0.35 + 0.3 * (0.5 + 0.5 * sin(t * 1.7)) * (0.7 + 0.3 * sin(t * 5.3))
	fx.draw_texture_rect_region(_fxtex, Rect2(ci[0], ci[1], ci[2], ci[3]), Rect2(ci[4], ci[5], ci[2], ci[3]), Color(1, 1, 1, ca))
	# light pulses travelling along the orbit lines
	for s in _sats:
		var pts: Array = M[s.path]
		var u := fposmod(t * s.sp + s.t, 1.0)
		for k in 14:
			var uu := u - k * 0.006
			if uu < 0: break
			var p := catmull(pts, uu)
			_blob(p, 9.0 - k * 0.4, Color(0.55, 0.86, 1.0, (1.0 - k / 14.0) * 0.55 * spk))
	# a light band sweeps across the lettering every few seconds
	var ti: Array = M.title
	var ph := fposmod(t, 7.0) / 7.0
	if ph < 0.45:
		var band: float = ti[0] - 200.0 + (ti[2] + 400.0) * (ph / 0.45)
		var x0: float = maxf(band - 90.0, ti[0])
		var x1: float = minf(band + 90.0, ti[0] + ti[2])
		if x1 > x0:
			var al := 0.9 * sin(PI * (ph / 0.45))
			fx.draw_texture_rect_region(_fxtex, Rect2(x0, ti[1], x1 - x0, ti[3]), Rect2(ti[4] + (x0 - ti[0]), ti[5], x1 - x0, ti[3]), Color(1, 1, 1, al))
