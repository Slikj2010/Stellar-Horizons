## Animated touches on the map, between the printed map sections and the counters: spinning planets and moons,
## the sun's corona and flares, and the exploration boxes (a soft glow in the world's research colour, a sheen
## sweeping across, and the printed value repainted when the world's value has changed).
## Ported from paintBodies / paintSun / paintExplore in index.html. Animation stops when Settings → Animated board is off.
extends Node2D

const FIELD_GLOW := {"Phy": Color(90 / 255.0, 170 / 255.0, 1.0), "Eng": Color(200 / 255.0, 210 / 255.0, 225 / 255.0), "Bio": Color(110 / 255.0, 220 / 255.0, 140 / 255.0)}

const RINGS := {"sat": {"tilt": -0.414, "k": 0.45, "kind": 0, "lim": 2.3}, "nep": {"tilt": -0.1, "k": 0.17, "kind": 1, "lim": 1.0}}
var board: Node2D
var t := 0.0
var bodies: Array = []  ## [node, spd, map, cx, cy]
var _sun_node: Node2D
var _sun_j: Dictionary
var sun_mat: ShaderMaterial
var exp: Dictionary = {}
var _prev := {}
var _hit := {}
var _glow_tex: Texture2D
var glow: Node2D  ## additive layer
var top: Node2D  ## normal layer (numbers)
var font: Font

func setup(b: Node2D) -> void:
	board = b
	font = load("res://assets/fonts/InterDisplay-Bold.otf")
	var geo: Dictionary = board.geo
	var maps: Dictionary = geo.maps
	# spinning bodies
	var bj: Dictionary = board._json("res://assets/bodies.json")
	var btex: Texture2D = load("res://assets/bodies.png")
	var shader: Shader = load("res://ui/shaders/body.gdshader")
	for k in bj.b:
		var o: Dictionary = bj.b[k]
		var m: Array = maps[o.map]
		var n := _Body.new()
		n.tex = btex
		n.r = o.r * 0.4
		n.position = Vector2(m[0] + o.cx * 0.4, m[1] + o.cy * 0.4)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("row", float(o.row))
		mat.set_shader_parameter("AW", float(btex.get_width()))
		mat.set_shader_parameter("AH", float(btex.get_height()))
		mat.set_shader_parameter("TW", float(bj.tw))
		mat.set_shader_parameter("TH", float(bj.th))
		mat.set_shader_parameter("DS", float(bj.ds))
		n.material = mat
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(n)
		if RINGS.has(k):
			# the ring's near half passes in front of the planet (the printed ring art lies behind the sprite)
			var rn := _Ring.new()
			rn.r = n.r * RINGS[k].lim
			var rm := ShaderMaterial.new()
			rm.shader = load("res://ui/shaders/ring_front.gdshader")
			var rp: Dictionary = RINGS[k]
			rm.set_shader_parameter("tilt", rp.tilt)
			rm.set_shader_parameter("k", rp.k)
			rm.set_shader_parameter("kind", rp.kind)
			rm.set_shader_parameter("lim", rp.lim)
			rn.material = rm
			n.add_child(rn)
		bodies.append([n, float(o.spd), o.map, float(o.cx), float(o.cy)])
	_sun_j = board._json("res://data/sun.json")
	_make_sun()
	# exploration boxes
	exp = board._json("res://assets/expbox.json")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.34, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_glow_tex = gt
	glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.draw.connect(_draw_glow)
	add_child(glow)
	top = Node2D.new()
	top.draw.connect(_draw_top)
	add_child(top)

func _make_sun() -> void:
	var S: Dictionary = _sun_j
	if S.is_empty(): return
	if _sun_node != null:
		_sun_node.queue_free()
	var m: Array = board.geo.maps[S.map]
	var c := Vector2(m[0] + S.cx * 0.4, m[1] + S.cy * 0.4)
	var r: float = S.r * 0.4
	var edge: float = m[1] + m[3]
	var o := Vector2(c.x - r * 1.25, c.y - r * 1.18)
	var sz := Vector2(r * 2.5, edge + 170 - o.y)
	var sn := _Rect.new()
	sn.rect = Rect2(o, sz)
	sun_mat = ShaderMaterial.new()
	sun_mat.shader = load("res://ui/shaders/sun.gdshader")
	for kv in [["origin", o], ["size", sz], ["center", c], ["r", r], ["edge", edge]]: sun_mat.set_shader_parameter(kv[0], kv[1])
	sn.material = sun_mat
	add_child(sn)
	_sun_node = sn

## the board's layout changed: put the planets and the sun on their (moved) map sections
func relayout() -> void:
	for b in bodies:
		var m: Array = board.geo.maps[b[2]]
		b[0].position = Vector2(m[0] + b[3] * 0.4, m[1] + b[4] * 0.4)
	_make_sun()

func _process(dt: float) -> void:
	if Game.settings.get("anim", true): t += dt
	for b in bodies:
		var n: Node2D = b[0]
		n.material.set_shader_parameter("rot", 0.0 if b[1] == 0.0 else fmod(t * TAU / b[1], TAU))  # tidally locked moons do not turn
	if sun_mat != null: sun_mat.set_shader_parameter("t", t)
	glow.queue_redraw()
	top.queue_redraw()

## position, size and tilt of a world's printed exploration box
func box_of(k: String) -> Dictionary:
	var e: Dictionary = exp[k]
	var m: Array = board.geo.maps[e.map]
	return {"p": Vector2(m[0] + e.cx * 0.4, m[1] + e.cy * 0.4), "s": e.s * 0.4, "a": deg_to_rad(e.ang), "hub": e.hub}

func _since(k: String, v) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	if not _prev.has(k): _prev[k] = v
	elif _prev[k] != v:
		_hit[k] = now
		_prev[k] = v
	return now - _hit[k] if _hit.has(k) else 9.0

func _draw_glow() -> void:
	var G = Game.G
	if G == null: return
	var W: Dictionary = Game.data.D.W
	var i := 0
	for k in exp:
		i += 1
		var ws = G.w.get(k)
		if ws == null: continue
		var B := box_of(k)
		var h: float = B.s / 2.0
		var v: int = int(ws.v)
		var since := _since(k, v)
		var col: Color = FIELD_GLOW.get(W[k].f, Color(1, 170 / 255.0, 90 / 255.0)) if k != "alp" else Color(1, 170 / 255.0, 90 / 255.0)
		var pulse := 0.5 + 0.5 * sin(t * 1.6 + i * 0.9)
		col.a = (0.1 + 0.12 * pulse if v > 0 else 0.03) + (0.5 * (1.0 - since / 1.2) if since < 1.2 else 0.0)
		glow.draw_set_transform(B.p, B.a)
		glow.draw_texture_rect(_glow_tex, Rect2(-h * 1.75, -h * 1.75, h * 3.5, h * 3.5), false, col)
		# a sheen sweeping diagonally across the tile
		var ph := fmod(t * 0.16 + i * 0.137, 1.0) * 3.2 - 1.1
		if ph > -0.6 and ph < 1.6 and v > 0:
			var bx: float = -h + ph * B.s
			var band := PackedVector2Array([Vector2(bx - h * 0.5 - h * 0.6, -h), Vector2(bx + h * 0.5 - h * 0.6, -h), Vector2(bx + h * 0.5 + h * 0.6, h), Vector2(bx - h * 0.5 + h * 0.6, h)])
			var sq := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
			for poly in Geometry2D.intersect_polygons(band, sq):
				if poly.size() < 3 or absf(_area(poly)) < 1.0: continue
				var cols := PackedColorArray()
				for pt in poly:
					# brightest along the band's middle line
					var mid: float = bx + pt.y * 0.6
					var k2 := clampf(1.0 - absf(pt.x - mid) / (h * 0.5), 0.0, 1.0)
					cols.append(Color(1, 1, 1, 0.22 * k2))
				glow.draw_polygon(poly, cols)
	glow.draw_set_transform(Vector2.ZERO)

static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size(): a += p[i].cross(p[(i + 1) % p.size()])
	return a / 2.0

func _draw_top() -> void:
	var G = Game.G
	if G == null: return
	var W: Dictionary = Game.data.D.W
	for k in exp:
		var ws = G.w.get(k)
		if ws == null: continue
		var B := box_of(k)
		var h: float = B.s / 2.0
		var v: int = int(ws.v)
		var since: float = (Time.get_ticks_msec() / 1000.0 - _hit[k]) if _hit.has(k) else 9.0
		top.draw_set_transform(B.p, B.a)
		if v != int(W[k].v):
			var hub: Array = B.hub
			var hr := h * 0.7
			var c0 := Color(hub[0] / 255.0, hub[1] / 255.0, hub[2] / 255.0)
			top.draw_circle(Vector2.ZERO, hr, c0)
			top.draw_circle(Vector2(0, -hr * 0.1), hr * 0.8, c0.lightened(0.07))
			var pop := 1.0 + 0.45 * (1.0 - since / 0.6) * (1.0 - since / 0.6) if since < 0.6 else 1.0
			var fs := int(h * (0.9 if v >= 10 else 1.2) * pop)
			var s := str(v)
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var bp := Vector2(-w / 2.0, fs * 0.36)
			top.draw_string_outline(font, bp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(fs * 0.16)), Color("#111111"))
			top.draw_string(font, bp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if v < 1:
			top.draw_rect(Rect2(-h, -h, B.s, B.s), Color(10 / 255.0, 0, 0, 0.5))
			top.draw_rect(Rect2(-h, -h, B.s, B.s), Color(239 / 255.0, 107 / 255.0, 91 / 255.0, 0.9), false, 2.5)
		if since < 1.0:
			var gr := h * (1.0 + since * 0.8)
			top.draw_rect(Rect2(-gr, -gr, gr * 2, gr * 2), Color(1, 1, 1, 1.0 - since), false, 3.0)
	top.draw_set_transform(Vector2.ZERO)

## a texture drawn as a square of radius r (the shader turns it into a sphere)
class _Body extends Node2D:
	var tex: Texture2D
	var r := 10.0
	func _draw() -> void: draw_texture_rect(tex, Rect2(-r, -r, r * 2, r * 2), false)

## the square a planet's ring shader paints on (the ring's near half inside the planet's disc)
class _Ring extends Node2D:
	var r := 10.0
	func _draw() -> void: draw_rect(Rect2(-r, -r, r * 2, r * 2), Color.WHITE)

## a plain rectangle for a shader to paint
class _Rect extends Node2D:
	var rect := Rect2()
	func _draw() -> void: draw_rect(rect, Color.WHITE)
