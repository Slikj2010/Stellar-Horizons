## The space behind the map: a dark gradient, a soft nebula wash and three layers of twinkling stars that move
## with the camera at different speeds (parallax). Drawn in screen space on a canvas layer behind the board.
## Ported from paintStars / initFX in index.html.
extends Node2D

const TILE := 2048.0
var cam: Camera2D
var stars: Array = []  ## [x, y, r, alpha, phase, speed, parallax, colour]
var nebula: Array = []  ## [x, y, radius, colour]
var t := 0.0
var _glow: Texture2D
var _bg: Texture2D  ## the galaxy backdrop (tools/make_sky.py)

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20300
	for L in [[220, 0.06, 0.45, 1.0], [120, 0.14, 0.7, 1.4], [46, 0.28, 1.0, 2.0]]:
		for i in L[0]:
			var hue := Color.WHITE
			if rng.randf() < 0.12: hue = Color("#ffd9a8") if rng.randf() < 0.5 else Color("#a8c8ff")
			stars.append([rng.randf() * TILE, rng.randf() * TILE, 0.35 + rng.randf() * L[3], L[2] * (0.35 + rng.randf() * 0.65), rng.randf() * TAU, 0.4 + rng.randf() * 2.2, L[1], hue])
	for c in [[Color(79 / 255.0, 195 / 255.0, 217 / 255.0), 0.07], [Color(120 / 255.0, 80 / 255.0, 200 / 255.0), 0.08], [Color(242 / 255.0, 169 / 255.0, 59 / 255.0), 0.035], [Color(60 / 255.0, 90 / 255.0, 200 / 255.0), 0.07]]:
		for i in 5:
			var col: Color = c[0]
			col.a = c[1]
			nebula.append([rng.randf() * 1024.0, rng.randf() * 1024.0, 180.0 + rng.randf() * 320.0, col])
	_bg = load("res://assets/sky_flat.png")
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow = gt

func _process(dt: float) -> void:
	if Game.settings.get("anim", true): t += dt
	queue_redraw()

func _draw() -> void:
	var vs := get_viewport_rect().size
	# background gradient (top-left lighter)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
		PackedColorArray([Color("#060a12"), Color("#05080f"), Color("#03050a"), Color("#05080f")]))
	if cam == null: return
	# the world origin's position on screen
	var o: Vector2 = -cam.get_screen_center_position() * cam.zoom + vs / 2.0
	# the galaxy backdrop drifts slowly against the camera, so it reads as far away
	if _bg != null:
		var ts := _bg.get_size()
		var sc := maxf(vs.x / ts.x, vs.y / ts.y) * 1.14
		var size := ts * sc
		var margin := (size - vs) / 2.0
		var drift := Vector2(tanh(o.x * 0.00035), tanh(o.y * 0.00035)) * margin
		draw_texture_rect(_bg, Rect2(-margin + drift, size), false, Color(0.8, 0.82, 0.85))
	else:
		var nox := fposmod(o.x * 0.04, 1024.0)
		var noy := fposmod(o.y * 0.04, 1024.0)
		for tx in range(-1, int(vs.x / 1024.0) + 2):
			for ty in range(-1, int(vs.y / 1024.0) + 2):
				var base := Vector2(nox + tx * 1024.0, noy + ty * 1024.0)
				for nb in nebula:
					var c: Vector2 = base + Vector2(nb[0], nb[1])
					var r: float = nb[2]
					if c.x + r < 0 or c.y + r < 0 or c.x - r > vs.x or c.y - r > vs.y: continue
					draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false, nb[3])
	# stars
	for st in stars:
		var par: float = st[6]
		var x := fposmod(st[0] + o.x * par, TILE)
		var y := fposmod(st[1] + o.y * par + t * par * 6.0, TILE)
		var tw := 0.55 + 0.45 * sin(t * st[5] + st[4])
		var col: Color = st[7]
		var tx := x
		while tx < vs.x:
			var ty := y
			while ty < vs.y:
				col.a = st[3] * tw
				draw_circle(Vector2(tx, ty), st[2], col)
				if st[2] > 1.6 and tw > 0.9:
					col.a = st[3] * (tw - 0.9) * 4.0
					draw_rect(Rect2(tx - st[2] * 3, ty - 0.3, st[2] * 6, 0.6), col)
					draw_rect(Rect2(tx - 0.3, ty - st[2] * 3, 0.6, st[2] * 6), col)
				ty += TILE
			tx += TILE
