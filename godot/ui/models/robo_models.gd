## Robotic explorers in one shared, faction-neutral design: Flyby (octagonal bus, gold wings, mast sphere, boom), Orbiter
## (gold lander bus, dish, legs), Rover (six wheels on rockers, masts), Telescope (long tube with gold wings) and Probe
## (black dome over a gold heat-shield cone).  Small per-name variations only (wing size, boom length, tube length, mast
## heights) so named units differ slightly; no names are written on any model.
class_name RoboModels
extends RefCounted

const TARGET_R := {"Flyby": 3.0, "Orbiter": 2.5, "Rover": 1.4, "Telescope": 2.6, "Probe": 1.45}

static func has(kind: String) -> bool:
	return TARGET_R.has(kind)

static func _m(col: Color, metal := 0.4, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough, emit)

static func _gold() -> StandardMaterial3D:
	return OrionCV2._smat("rb_gold", 512, 512, {"seed": 1301, "cols": 10, "min_len": 40, "max_len": 140, "black_rate": 0.0, "grime": 0.55, "tones": [Color("#d9b04a"), Color("#c99a35"), Color("#e2bd5a"), Color("#bf8f2e"), Color("#d2a53f")], "seam": Color("#7a5a14")}, 0.9, 0.32)

static func _silver() -> StandardMaterial3D:
	return OrionCV2._smat("rb_silver", 512, 512, {"seed": 1307, "cols": 12, "min_len": 40, "max_len": 160, "black_rate": 0.02, "grime": 0.7, "tones": [Color("#d6d8db"), Color("#c3c6ca"), Color("#e4e5e7"), Color("#b0b4b9")], "seam": Color("#585c63")}, 0.8, 0.35)

static func _darkm() -> StandardMaterial3D:
	return OrionCV2._smat("rb_dark", 512, 512, {"seed": 1319, "cols": 12, "min_len": 30, "max_len": 120, "black_rate": 0.03, "grime": 0.8, "tones": [Color("#34363c"), Color("#2a2c31"), Color("#3e4047"), Color("#22242a")], "seam": Color("#0e0f12")}, 0.6, 0.45)

static func _cell(col: String, uv: Vector2) -> StandardMaterial3D:
	return UnitModels.panel_mat(Color(col), uv)

## one flat solar wing: silver frame, gold cells, split into segments along the span (span along Z unless `along_x`)
static func _wing(p: Node3D, pos: Vector3, span: float, chord: float, segs: int, sg: float, col := "#c9a24a") -> void:
	var silver := _silver()
	var seg := span / segs
	for q in segs:
		var z: float = sg * (seg * (q + 0.5) + 0.02 * q)
		UnitModels.box(p, Vector3(chord, 0.022, seg * 0.94), _cell(col, Vector2(maxf(2.0, round(chord * 5.0)), maxf(2.0, round(seg * 5.0)))), pos + Vector3(0, 0, z))
		for e in [-1.0, 1.0]:
			UnitModels.box(p, Vector3(0.025, 0.04, seg * 0.98), silver, pos + Vector3(e * chord * 0.5, 0, z))
			UnitModels.box(p, Vector3(chord * 1.02, 0.04, 0.025), silver, pos + Vector3(0, 0, z + e * seg * 0.49))

# ------------------------------------------------------------------ Flyby
static func _flyby(core: Node3D, rng: RandomNumberGenerator) -> void:
	var gold := _gold()
	var silver := _silver()
	var dark := _darkm()
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var R := 0.62
	# octagonal bus, gold foil with silver bands
	var pts: Array = [Vector2(0.3, 0.001), Vector2(0.3, R * 0.88), Vector2(0.27, R), Vector2(-0.27, R), Vector2(-0.3, R * 0.88), Vector2(-0.3, 0.001)]
	for cx in [0.3, -0.3]:
		UnitModels.cylx(core, R * 0.9, R * 0.9, 0.012, silver if cx < 0 else gold, Vector3(cx, 0, 0), 8)
	UnitModels.cylx(core, 0.12, 0.16, 0.12, dark, Vector3(-0.36, 0, 0), 16)
	var gold2: StandardMaterial3D = gold.duplicate()
	gold2.cull_mode = BaseMaterial3D.CULL_DISABLED
	OrionCV2._lathe(core, pts, 8, gold2, Vector3.ZERO)
	for x in [0.28, -0.28]:
		OrionCV2._lathe(core, [Vector2(x + 0.03, R * 0.99), Vector2(x + 0.03, R * 1.03), Vector2(x - 0.03, R * 1.03), Vector2(x - 0.03, R * 0.99)], 8, gold2, Vector3.ZERO)
	# front instrument: silver housing, black lens
	UnitModels.cylx(core, 0.3, 0.33, 0.1, silver, Vector3(0.34, 0, 0), 24)
	UnitModels.cylx(core, 0.2, 0.2, 0.06, dark, Vector3(0.4, 0, 0), 24)
	UnitModels.ball(core, 0.13, _m(Color("#0b0c10"), 0.9, 0.1), Vector3(0.42, 0, 0), Vector3(0.5, 1, 1))
	UnitModels.ring(core, 0.2, 0.235, steel, Vector3(0.43, 0, 0), Vector3(0, 0, PI / 2))
	# side equipment boxes
	for sg in [-1.0, 1.0]:
		OrionCV2._rbox(core, Vector3(0.22, 0.2, 0.18), silver, Vector3(-0.05, 0.18, sg * (R + 0.08)), 4.0, 6)
		UnitModels.cylz(core, 0.07, 0.4, steel, Vector3(0.0, 0.0, sg * (R + 0.2)), 12)
	# wings
	var span := 1.5 + rng.randf() * 0.2
	var chord := 0.7 + rng.randf() * 0.08
	for sg in [-1.0, 1.0]:
		OrionCV2._strut(core, Vector3(0, 0, sg * R), Vector3(0, 0, sg * (R + 0.18)), 0.04, steel)
		_wing(core, Vector3(0, 0, sg * (R + 0.18)), span, chord, 2, sg)
	# mast with a geodesic sphere on top
	OrionCV2._strut(core, Vector3(0, R * 0.9, 0), Vector3(0, R + 0.38, 0), 0.03, steel)
	UnitModels.ring(core, 0.05, 0.075, silver, Vector3(0, R + 0.34, 0))
	var sph := OrionCV2._smat("rb_sphere", 512, 512, {"seed": 1331, "cols": 14, "min_len": 20, "max_len": 60, "black_rate": 0.1, "grime": 0.9, "tones": [Color("#8c8579"), Color("#767064"), Color("#9a9386"), Color("#6a645a")], "seam": Color("#2c2a26")}, 0.6, 0.5)
	var sb := UnitModels.ball(core, 0.27, sph, Vector3(0, R + 0.62, 0))
	(sb.mesh as SphereMesh).radial_segments = 12
	(sb.mesh as SphereMesh).rings = 7
	# long instrument boom down and back, with a dark sensor at the end
	var tip := Vector3(-0.3, -R - 0.7 - rng.randf() * 0.2, 0.06)
	OrionCV2._strut(core, Vector3(-0.1, -R * 0.8, 0), tip, 0.045, _m(Color("#2a2c31"), 0.7, 0.4))
	OrionCV2._strut(core, tip, tip + Vector3(-0.05, -0.3, 0.0), 0.09, dark)
	UnitModels.ring(core, 0.07, 0.095, silver, tip + Vector3(-0.025, -0.1, 0.0), Vector3(0.0, 0, 0.2))
	# thin whip antenna with a tip node
	var base := Vector3(0.12, R * 0.85, 0.12)
	var top := base + Vector3(0.5, 0.55, 0.25)
	OrionCV2._strut(core, base, top, 0.012, steel)
	UnitModels.ball(core, 0.035, silver, top)

# ------------------------------------------------------------------ Orbiter (lander-style bus on legs)
static func _orbiter(core: Node3D, rng: RandomNumberGenerator) -> void:
	var gold := _gold()
	var silver := _silver()
	var dark := _darkm()
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var black := _m(Color("#3b3f48"), 0.2, 0.5)
	# bus: gold-foil box with a black solar face and silver corner frame
	OrionCV2._rbox(core, Vector3(1.0, 0.85, 1.0), gold, Vector3.ZERO, 6.0, 10)
	for sg in [-1.0, 1.0]:
		UnitModels.box(core, Vector3(0.74, 0.62, 0.02), _cell("#1b2230", Vector2(6, 5)), Vector3(0.02, 0.0, sg * 0.505))
		UnitModels.box(core, Vector3(0.8, 0.04, 0.03), silver, Vector3(0.02, 0.33, sg * 0.5))
		UnitModels.box(core, Vector3(0.8, 0.04, 0.03), silver, Vector3(0.02, -0.33, sg * 0.5))
	for cx in [-0.5, 0.5]:
		for cz in [-0.5, 0.5]:
			OrionCV2._strut(core, Vector3(cx, -0.42, cz), Vector3(cx, 0.42, cz), 0.022, silver)
	# instrument box and thruster pods
	OrionCV2._rbox(core, Vector3(0.28, 0.34, 0.3), _m(Color("#e4e5e7"), 0.5, 0.5), Vector3(0.0, -0.05 + 0.0, 0.66), 4.0, 8)
	UnitModels.cylx(core, 0.06, 0.1, 0.18, dark, Vector3(0.55, 0.05, -0.2), 12)
	# dish on a post
	OrionCV2._strut(core, Vector3(0.0, 0.42, 0.0), Vector3(0.0, 0.7, 0.0), 0.07, silver)
	UnitModels.ball(core, 0.11, silver, Vector3(0.0, 0.74, 0.0))
	var d := UnitModels.dish(core, 0.62 + rng.randf() * 0.08, _m(Color("#eceff2"), 0.4, 0.4), Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.0, -0.55))
	for k in 3:
		var a := k * TAU / 3.0
		OrionCV2._strut(d, Vector3(cos(a), 0.05, sin(a)) * 0.58 * 0.9 / 0.9 * 0.62, Vector3(0, 0.62 * 0.86, 0), 0.01, steel)
	# four splayed legs with gold foot pads
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var top := Vector3(sx * 0.42, -0.3, sz * 0.42)
			var foot := Vector3(sx * 0.95, -1.28, sz * 0.95)
			OrionCV2._strut(core, top, foot, 0.04, dark)
			OrionCV2._strut(core, Vector3(sx * 0.5, -0.05, sz * 0.5), top.lerp(foot, 0.55), 0.018, steel)
			UnitModels.cyly(core, 0.025, 0.1, 0.1, _m(Color("#d2a53f"), 0.9, 0.3), foot + Vector3(0, -0.05, 0), 16)
			UnitModels.cyly(core, 0.11, 0.11, 0.02, _m(Color("#d2a53f"), 0.9, 0.3), foot + Vector3(0, -0.1, 0), 16)

# ------------------------------------------------------------------ Rover
static func _rover(core: Node3D, rng: RandomNumberGenerator) -> void:
	var gold := _gold()
	var silver := _silver()
	var dark := _darkm()
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var black := _m(Color("#1b2230"), 0.3, 0.5)
	# gold chassis with a dark solar deck
	OrionCV2._rbox(core, Vector3(1.55, 0.14, 0.78), gold, Vector3(0, 0.0, 0), 5.0, 8)
	UnitModels.box(core, Vector3(1.5, 0.02, 0.8), _cell("#242b3a", Vector2(10, 5)), Vector3(0, 0.085, 0))
	for sg in [-1.0, 1.0]:
		UnitModels.box(core, Vector3(1.58, 0.03, 0.03), silver, Vector3(0, 0.1, sg * 0.4))
	for sx in [-1.0, 1.0]:
		UnitModels.box(core, Vector3(0.03, 0.03, 0.82), silver, Vector3(sx * 0.78, 0.1, 0))
	# central camera mast and two instrument tubes
	var mh := 0.85 + rng.randf() * 0.1
	UnitModels.cyly(core, 0.05, 0.065, mh, silver, Vector3(0.1, 0.09 + mh * 0.5, 0), 14)
	OrionCV2._rbox(core, Vector3(0.22, 0.14, 0.3), _m(Color("#e8e9ea"), 0.5, 0.45), Vector3(0.12, 0.09 + mh + 0.07, 0), 4.0, 8)
	for sg in [-1.0, 1.0]:
		UnitModels.ball(core, 0.045, _m(Color("#0b0c10"), 0.9, 0.1), Vector3(0.24, 0.09 + mh + 0.07, sg * 0.08), Vector3(0.4, 1, 1))
	UnitModels.cyly(core, 0.075, 0.075, 0.62 + rng.randf() * 0.12, silver, Vector3(-0.45, 0.4, 0.2), 16)
	UnitModels.cyly(core, 0.085, 0.085, 0.04, dark, Vector3(-0.45, 0.72, 0.2), 16)
	UnitModels.cyly(core, 0.035, 0.035, 0.42, silver, Vector3(-0.2, 0.3, -0.22), 12)
	UnitModels.cyly(core, 0.025, 0.025, 0.3, steel, Vector3(0.45, 0.24, -0.25), 10)
	UnitModels.cyly(core, 0.03, 0.03, 0.3, steel, Vector3(0.5, 0.24, 0.28), 10)
	# arm stub
	OrionCV2._strut(core, Vector3(0.7, 0.0, 0.0), Vector3(0.95, -0.05, 0.0), 0.03, steel)
	# six wheels on rocker struts
	for sg in [-1.0, 1.0]:
		for wx in [0.62, 0.0, -0.62]:
			var hub := Vector3(wx, -0.26, sg * 0.58)
			var tire := UnitModels.ring(core, 0.15, 0.25, steel, hub, Vector3(PI / 2, 0, 0))
			tire.scale = Vector3(1, 0.8, 1)
			UnitModels.cylz(core, 0.09, 0.2, silver, hub, 16)
			for k in 6:
				var a := k * TAU / 6.0
				OrionCV2._strut(core, hub + Vector3(cos(a), sin(a), 0) * 0.08 + Vector3(0, 0, sg * 0.05), hub + Vector3(cos(a), sin(a), 0) * 0.2 + Vector3(0, 0, sg * 0.05), 0.014, steel)
			OrionCV2._strut(core, Vector3(wx * 0.55, -0.04, sg * 0.36), Vector3(wx, -0.22, sg * 0.46), 0.022, dark)
			OrionCV2._strut(core, Vector3(wx, -0.22, sg * 0.46), hub + Vector3(0, 0, sg * -0.04), 0.018, steel)

# ------------------------------------------------------------------ Telescope
static func _telescope(core: Node3D, rng: RandomNumberGenerator) -> void:
	var gold := _gold()
	var silver := _silver()
	var dark := _darkm()
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var L := 2.2 + rng.randf() * 0.3
	var R := 0.46
	# main tube: dark metal, a gold-foil band, aperture hood with a black interior, and a rear instrument bay
	var tube: Array = [Vector2(L * 0.5, R * 1.18), Vector2(L * 0.5 - 0.05, R * 1.22), Vector2(L * 0.5 - 0.5, R * 1.06), Vector2(L * 0.08, R), Vector2(-L * 0.28, R), Vector2(-L * 0.3, R * 1.1), Vector2(-L * 0.5, R * 1.1), Vector2(-L * 0.5, 0.001)]
	OrionCV2._lathe(core, tube, 36, dark, Vector3.ZERO)
	var inner: Array = [Vector2(L * 0.5 + 0.001, R * 1.14), Vector2(L * 0.5 - 0.5, R * 1.02), Vector2(L * 0.5 - 0.5, 0.001)]
	OrionCV2._lathe(core, inner, 36, _m(Color("#08090b"), 0.4, 0.4), Vector3.ZERO, true)
	UnitModels.cylx(core, R * 1.04, R * 1.04, L * 0.22, gold, Vector3(-L * 0.08, 0, 0), 36)
	UnitModels.cylx(core, R * 1.12, R * 1.12, L * 0.2, silver, Vector3(-L * 0.4, 0, 0), 36)
	for x in [L * 0.28, -L * 0.2, -L * 0.3]:
		UnitModels.ring(core, R * 1.0, R * 1.06, steel, Vector3(x, 0, 0), Vector3(0, 0, PI / 2))
	# rear bay details: radiators, boxes, small dish
	for sg in [-1.0, 1.0]:
		OrionCV2._rbox(core, Vector3(0.45, 0.3, 0.28), silver, Vector3(-L * 0.4, sg * R * 1.18, 0.0), 4.0, 8)
	UnitModels.dish(core, 0.22, _m(Color("#eceff2"), 0.4, 0.4), Vector3(-L * 0.45, R * 1.16 + 0.18, 0.35), Vector3(0.0, 0.0, -0.5))
	# handrail struts
	for k in 3:
		var a := PI * 0.5 + k * 0.3
		OrionCV2._strut(core, Vector3(L * 0.2, R * 1.0 * sin(a + 0.7), R * cos(a + 0.7)), Vector3(-L * 0.1, R * 1.0 * sin(a + 0.7), R * cos(a + 0.7)), 0.01, steel)
	# two solar wings, two panels each, on masts
	for sg in [-1.0, 1.0]:
		OrionCV2._strut(core, Vector3(-L * 0.12, 0.0, sg * R), Vector3(-L * 0.12, 0.0, sg * (R + 0.3)), 0.045, silver)
		for q in 2:
			_wing(core, Vector3(-L * 0.12 + (q - 0.5) * 1.05, 0.0, sg * (R + 0.3)), 1.35, 0.98, 1, sg)
		UnitModels.box(core, Vector3(0.05, 0.05, 1.5), silver, Vector3(-L * 0.12, 0.0, sg * (R + 1.0)))

# ------------------------------------------------------------------ Probe (entry capsule)
static func _probe(core: Node3D, rng: RandomNumberGenerator) -> void:
	var silver := _silver()
	var steel := _m(Color("#9aa0a8"), 0.85, 0.3)
	var shield := _cell("#c9a24a", Vector2(12, 4))
	var domem := OrionCV2._smat("rb_dome", 512, 512, {"seed": 1361, "cols": 14, "min_len": 20, "max_len": 80, "black_rate": 0.05, "grime": 0.85, "tones": [Color("#2e3036"), Color("#25272c"), Color("#383a41"), Color("#1d1f23")], "seam": Color("#0b0c0e")}, 0.55, 0.45)
	var R := 0.74
	# built along +X, then stood up so the dome is on top and the heat shield points down
	var h := Node3D.new()
	h.rotation = Vector3(0, 0, PI / 2)
	core.add_child(h)
	var dome: Array = []
	for i in 13:
		var t := float(i) / 12.0
		dome.append(Vector2(0.15 + 0.3 * cos(t * PI * 0.5), R * 0.98 * sin(t * PI * 0.5) + 0.001))
	OrionCV2._lathe(h, dome, 32, domem, Vector3.ZERO)
	# white equator band with a ring of square vents
	UnitModels.cylx(h, R, R, 0.16, silver, Vector3(0.07, 0, 0), 32)
	for i in 20:
		var a := i * TAU / 20.0
		var f := OrionCV2._radial(h, 0.15, a, R * 1.0)
		OrionCV2._rbox(f, Vector3(0.07, 0.05, 0.075), _m(Color("#e8e9ea"), 0.4, 0.5), Vector3.ZERO, 4.0, 5)
	for k in 6:
		var a := k * TAU / 6.0 + 0.2
		var f := OrionCV2._radial(h, 0.34, a, R * 0.62)
		OrionCV2._rbox(f, Vector3(0.05, 0.03, 0.05), silver, Vector3.ZERO, 4.0, 5)
	# gold heat-shield cone
	var cone: Array = [Vector2(0.0, R), Vector2(-0.1, R * 0.95), Vector2(-0.78, 0.07), Vector2(-0.84, 0.001)]
	OrionCV2._lathe(h, cone, 32, shield, Vector3.ZERO)
	# antenna spikes on the dome
	for sp in [[0.0, 0.0, 0.34], [0.28, 0.12, 0.16]]:
		var base := Vector3(0.62 - sp[1] * 0.2, 0.0, 0.0)
		var f := OrionCV2._radial(h, 0.45 - sp[1] * 0.5, sp[0], sp[1] * 0.6 + 0.03)
		OrionCV2._strut(f, Vector3.ZERO, Vector3(0.0, 0.0, 0.0) + Vector3(0.0, sp[2], 0.0), 0.012, steel)
		UnitModels.ball(f, 0.022, silver, Vector3(0.0, sp[2], 0.0))

static func build(kind: String) -> Node3D:
	return build_named(kind, kind)

static func build_named(kind: String, name: String) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var root := Node3D.new()
	root.name = "Robo_" + kind
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	match kind:
		"Flyby": _flyby(core, rng)
		"Orbiter": _orbiter(core, rng)
		"Rover": _rover(core, rng)
		"Telescope": _telescope(core, rng)
		_: _probe(core, rng)
	var bb := UnitModels._bounds(core)
	var r := maxf(bb.size.length() * 0.5, 0.3)
	var k: float = TARGET_R[kind] / r
	core.scale = Vector3(k, k, k)
	core.position = -bb.get_center() * k
	root.set_meta("radius", TARGET_R[kind])
	root.set_meta("size", bb.size * k)
	return root
