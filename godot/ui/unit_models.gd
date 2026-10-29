## Procedural 3D models for every unit token: the robotic explorers (Probe, Rover, Flyby, Orbiter, Telescope) and
## the crew vehicles CV-2 .. CV-9, in each faction's livery. Every named unit gets its own build, seeded from
## its name (panel count and length, tank count, antennas, stripe positions, wheel count), so no two look alike.
## Models are built from Godot primitives; the ship's nose points to +X and the model is centred at the origin.
class_name UnitModels
extends RefCounted

## hull / accent / trim / panel cell colours per faction
const LIVERY := {
	"na": {"hull": "#eceff4", "acc": "#2358b8", "trim": "#c42a36", "panel": "#1d3270", "foil": "#c9a64a"},
	"eu": {"hull": "#dfe4ec", "acc": "#3a68c8", "trim": "#e8c440", "panel": "#1a2a60", "foil": "#d9b34e"},
	"ru": {"hull": "#bcc6b4", "acc": "#c83d2c", "trim": "#2d3a2d", "panel": "#1d3562", "foil": "#b9953e"},
	"cn": {"hull": "#ece0c4", "acc": "#c8312a", "trim": "#e2b33a", "panel": "#26285a", "foil": "#e0b441"},
	"jp": {"hull": "#f3f3f1", "acc": "#d6232c", "trim": "#3a3d4a", "panel": "#1c2a64", "foil": "#cfd2d8"},
	"as": {"hull": "#f5f0e6", "acc": "#e8892e", "trim": "#1f8a4c", "panel": "#22306e", "foil": "#d8a23e"},
	"sa": {"hull": "#e8ece0", "acc": "#2e9a5a", "trim": "#e6c23a", "panel": "#1d3a5e", "foil": "#cdb454"},
}
const RE_KINDS := ["Probe", "Rover", "Flyby", "Orbiter", "Telescope"]

static var _mats := {}
static var _solar_tex: ImageTexture

# ---------------- materials ----------------
static func mat(col: Color, metal := 0.2, rough := 0.55, emit := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [col.to_html(), metal, rough, emit]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

static func _solar_tex_for(cell: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(cell)
	var line := cell.lightened(0.55)
	for i in 64:
		for j in 64:
			if i % 16 == 0 or j % 32 == 0: img.set_pixel(i, j, line)
	var t := ImageTexture.create_from_image(img)
	return t

static func panel_mat(cell: Color, uv: Vector2) -> StandardMaterial3D:
	var key := "panel_%s_%.1f_%.1f" % [cell.to_html(), uv.x, uv.y]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	var tk := "ptex_" + cell.to_html()
	if not _mats.has(tk): _mats[tk] = _solar_tex_for(cell)
	m.albedo_texture = _mats[tk]
	m.texture_repeat = true
	m.uv1_scale = Vector3(uv.x, uv.y, 1)
	m.metallic = 0.7
	m.roughness = 0.28
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

# ---------------- primitives ----------------
static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	return n

## cylinder / cone along X: r_front at +X, r_back at -X
static func cylx(parent: Node3D, r_front: float, r_back: float, length: float, m: Material, pos: Vector3, seg := 28) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_front
	c.bottom_radius = r_back
	c.height = length
	c.radial_segments = seg
	c.rings = 1
	return _mi(parent, c, m, pos, Vector3(0, 0, -PI / 2))

static func cyly(parent: Node3D, r_top: float, r_bot: float, h: float, m: Material, pos: Vector3, seg := 24) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _mi(parent, c, m, pos, Vector3.ZERO)

static func cylz(parent: Node3D, r: float, w: float, m: Material, pos: Vector3, seg := 20) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = w
	c.radial_segments = seg
	c.rings = 1
	return _mi(parent, c, m, pos, Vector3(PI / 2, 0, 0))

static func box(parent: Node3D, size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, m, pos, rot)

static func ball(parent: Node3D, r: float, m: Material, pos: Vector3, sc := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	var n := _mi(parent, s, m, pos, Vector3.ZERO)
	n.scale = sc
	return n

static func ring(parent: Node3D, r_in: float, r_out: float, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = 40
	t.ring_segments = 10
	return _mi(parent, t, m, pos, rot)

## a solar panel: thin slab with a cell grid; `w` along its span, `l` along the ship
static func solar(parent: Node3D, f: String, w: float, l: float, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var L: Dictionary = LIVERY[f]
	var uv := Vector2(maxf(1.0, round(l * 3.0)), maxf(1.0, round(w * 3.0)))
	return box(parent, Vector3(l, 0.025, w), panel_mat(Color(L.panel), uv), pos, rot)

static func dish(parent: Node3D, r: float, m: Material, pos: Vector3, rot: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation = rot
	parent.add_child(pivot)
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 0.12
	c.height = r * 0.42
	c.radial_segments = 28
	c.rings = 1
	var dm: StandardMaterial3D = m.duplicate()
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi(pivot, c, dm, Vector3(0, r * 0.21, 0), Vector3.ZERO)
	var feed_m := mat(Color("#2a2d36"), 0.4, 0.5)
	cyly(pivot, 0.012, 0.012, r * 0.7, feed_m, Vector3(0, r * 0.5, 0), 8)
	ball(pivot, r * 0.07, feed_m, Vector3(0, r * 0.86, 0))
	return pivot

static func nozzle(parent: Node3D, r: float, len: float, pos: Vector3, glow := false) -> void:
	cylx(parent, r * 0.45, r, len, mat(Color("#3a3d46"), 0.8, 0.35), pos, 20)
	cylx(parent, r * 0.5, r * 0.5, len * 0.12, mat(Color("#14151a"), 0.3, 0.7), pos + Vector3(len * 0.45, 0, 0), 16)
	if glow: ball(parent, r * 0.3, mat(Color("#7fd0ff"), 0, 0.3, 2.5), pos + Vector3(-len * 0.52, 0, 0))

static func name_label(parent: Node3D, txt: String, col: Color, pos: Vector3, size: float, back := false) -> void:
	for side in ([1.0, -1.0] if back else [1.0]):
		var l := Label3D.new()
		l.text = txt
		l.font_size = 96
		l.pixel_size = size / 96.0
		l.modulate = col
		l.outline_size = 0
		l.double_sided = false
		l.shaded = true
		l.no_depth_test = false
		l.position = Vector3(pos.x, pos.y, pos.z * side)
		if side < 0: l.rotation.y = PI
		parent.add_child(l)

# ---------------- hash helpers ----------------
static func _rng(seed_txt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed_txt)
	return r

static func _col(h: String) -> Color: return Color(h)

# ---------------- public entry ----------------
## Build the model for a unit. `kind` is "Probe" ... "CV-9"; returns the root Node3D (meta "radius" = framing radius).
static func build(f: String, name: String, kind: String) -> Node3D:
	if not LIVERY.has(f): f = "na"
	var root := Node3D.new()
	root.name = "Model_" + name.replace(" ", "_")
	var rng := _rng(f + "|" + name)
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	match kind:
		"Probe": _probe(core, f, name, rng)
		"Rover": _rover(core, f, name, rng)
		"Flyby": _flyby(core, f, name, rng)
		"Orbiter": _orbiter(core, f, name, rng)
		"Telescope": _telescope(core, f, name, rng)
		_:
			if kind.begins_with("CV-"):
				var fancy := _crew_model(f, name)
				if fancy != null:
					root.free()
					return fancy
				_crew(core, f, name, int(kind.substr(3)), rng)
			else: _probe(core, f, name, rng)
	var bb := _bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	root.set_meta("size", bb.size)
	return root

## Detailed hand-kit crew vehicles (one model per named CV); null when a unit has none, which falls back to the generic _crew.
static func _crew_model(f: String, name: String) -> Node3D:
	var m: Node3D = null
	match f:
		"na":
			if name == "Orion": m = OrionCV2.build("orion")
			elif name == "Discovery": m = OrionCV2.build("discovery")
			elif NAShips.has(name): m = NAShips.build(name)
		"as": if AsiaShips.has(name): m = AsiaShips.build(name)
		"sa": if SAShips.has(name): m = SAShips.build(name)
		"ru": if RUShips.has(name): m = RUShips.build(name)
		"jp": if JPShips.has(name): m = JPShips.build(name)
		"eu": if EUShips.has(name): m = EUShips.build(name)
		"cn": if CNShips.has(name): m = CNShips.build(name)
	if m != null and not m.has_meta("size"):
		m.set_meta("size", _bounds(m).size)
	return m

static func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while stack.size():
		var it: Array = stack.pop_back()
		var node: Node3D = it[0]
		var xf: Transform3D = it[1]
		for c in node.get_children():
			if not (c is Node3D): continue
			var cx: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D and not (c is Label3D):
				var a: AABB = cx * (c as MeshInstance3D).get_aabb()
				out = a if first else out.merge(a)
				first = false
			stack.append([c, cx])
	return out

# ---------------- robotic explorers ----------------
static func _probe(p: Node3D, f: String, name: String, rng: RandomNumberGenerator) -> void:
	var L: Dictionary = LIVERY[f]
	var hull := mat(_col(L.hull), 0.35, 0.4)
	var foil := mat(_col(L.foil), 0.9, 0.25)
	var acc := mat(_col(L.acc), 0.2, 0.5)
	var dark := mat(Color("#2a2d36"), 0.5, 0.5)
	# bus: a squat hexagonal prism wrapped in gold foil
	cyly(p, 0.34, 0.34, 0.46, foil, Vector3.ZERO, 6)
	cyly(p, 0.35, 0.35, 0.06, hull, Vector3(0, 0.23, 0), 6)
	cyly(p, 0.35, 0.35, 0.06, acc, Vector3(0, -0.2, 0), 6)
	# high gain dish on a short mast
	dish(p, 0.4 + rng.randf() * 0.1, hull, Vector3(0, 0.26, 0), Vector3(0.25, 0, 0))
	# descent engine and legs
	cyly(p, 0.12, 0.2, 0.2, dark, Vector3(0, -0.34, 0), 16)
	var legs := 3 + rng.randi_range(0, 1)
	for i in legs:
		var a := TAU * i / legs
		var d := Vector3(cos(a), 0, sin(a))
		var leg := box(p, Vector3(0.04, 0.5, 0.04), dark, d * 0.38 + Vector3(0, -0.28, 0), Vector3(-d.z * 0.5, 0, d.x * 0.5))
		cyly(p, 0.09, 0.09, 0.03, hull, d * 0.5 + Vector3(0, -0.52, 0), 12)
		leg.name = "Leg%d" % i
	# two small panels on booms
	for s in [-1.0, 1.0]:
		cylz(p, 0.012, 0.5, dark, Vector3(0, 0.05, s * 0.5), 6)
		solar(p, f, 0.34, 0.5, Vector3(0, 0.05, s * 0.95), Vector3.ZERO)
	# sensor boom + whip
	cylx(p, 0.012, 0.012, 0.6 + rng.randf() * 0.3, dark, Vector3(0.55, 0.1, 0.0), 6)
	ball(p, 0.04, acc, Vector3(0.9, 0.1, 0.0))
	cyly(p, 0.006, 0.006, 0.5, dark, Vector3(-0.25, 0.4, 0.25), 6)
	name_label(p, name, _col(L.trim).darkened(0.45), Vector3(0, 0.0, 0.345), 0.2, true)

static func _rover(p: Node3D, f: String, name: String, rng: RandomNumberGenerator) -> void:
	var L: Dictionary = LIVERY[f]
	var hull := mat(_col(L.hull), 0.3, 0.45)
	var acc := mat(_col(L.acc), 0.2, 0.5)
	var dark := mat(Color("#23252d"), 0.5, 0.6)
	var tire := mat(Color("#16171b"), 0.1, 0.9)
	var hub := mat(Color("#b7bcc8"), 0.8, 0.3)
	var wheels := 6 if rng.randf() > 0.35 else 4
	var wx: Array = [-0.62, 0.0, 0.62] if wheels == 6 else [-0.5, 0.5]
	# chassis
	box(p, Vector3(1.5, 0.34, 0.86), hull, Vector3(0, 0.34, 0))
	box(p, Vector3(1.52, 0.06, 0.88), acc, Vector3(0, 0.2, 0))
	box(p, Vector3(0.8, 0.22, 0.7), dark, Vector3(0.1, 0.62, 0))
	# wheels + rocker struts
	for x in wx:
		for s in [-1.0, 1.0]:
			cylz(p, 0.22, 0.2, tire, Vector3(x, 0.14, s * 0.56), 22)
			cylz(p, 0.1, 0.215, hub, Vector3(x, 0.14, s * 0.56), 14)
			box(p, Vector3(0.05, 0.28, 0.05), dark, Vector3(x, 0.26, s * 0.46))
	# camera mast with head and two lenses
	cyly(p, 0.03, 0.03, 0.5, dark, Vector3(0.55, 0.95, 0.15), 8)
	box(p, Vector3(0.16, 0.1, 0.26), hull, Vector3(0.55, 1.22, 0.15))
	for s in [-1.0, 1.0]: cylx(p, 0.03, 0.03, 0.06, dark, Vector3(0.66, 1.22, 0.15 + s * 0.08), 10)
	# top solar deck or RTG
	if rng.randf() > 0.4:
		solar(p, f, 0.8, 1.0, Vector3(-0.2, 0.82, 0), Vector3.ZERO)
	else:
		cylx(p, 0.1, 0.1, 0.5, mat(Color("#8a8d96"), 0.7, 0.4), Vector3(-0.5, 0.8, 0), 12)
		for i in 5: box(p, Vector3(0.02, 0.2, 0.2), dark, Vector3(-0.72 + i * 0.1, 0.8, 0))
	# sampling arm
	var arm := box(p, Vector3(0.5, 0.05, 0.05), dark, Vector3(0.95, 0.4, -0.3), Vector3(0, 0, -0.5))
	arm.name = "Arm"
	ball(p, 0.06, acc, Vector3(1.18, 0.3, -0.3))
	# antenna
	dish(p, 0.2, hull, Vector3(-0.65, 0.95, -0.25), Vector3(-0.3, 0, 0.3))
	name_label(p, name, _col(L.acc).darkened(0.3), Vector3(0.0, 0.36, 0.435), 0.2, true)

static func _flyby(p: Node3D, f: String, name: String, rng: RandomNumberGenerator) -> void:
	var L: Dictionary = LIVERY[f]
	var hull := mat(_col(L.hull), 0.3, 0.4)
	var foil := mat(_col(L.foil), 0.9, 0.25)
	var acc := mat(_col(L.acc), 0.2, 0.5)
	var dark := mat(Color("#2a2d36"), 0.5, 0.5)
	# elongated bus
	box(p, Vector3(1.0, 0.5, 0.6), foil, Vector3.ZERO)
	box(p, Vector3(0.2, 0.52, 0.62), acc, Vector3(0.2, 0, 0))
	box(p, Vector3(0.2, 0.52, 0.62), acc, Vector3(-0.3, 0, 0))
	# high gain dish
	var dr := 0.5 + rng.randf() * 0.15
	dish(p, dr, hull, Vector3(0.05, 0.25, 0), Vector3(0, 0, 0.0))
	# main engine
	nozzle(p, 0.2, 0.4, Vector3(-0.68, 0, 0), true)
	# long solar wings, 2-3 segments
	var seg := 2 + rng.randi_range(0, 1)
	var seg_l := 0.7 + rng.randf() * 0.2
	for s in [-1.0, 1.0]:
		cylz(p, 0.02, 0.28, dark, Vector3(-0.1, 0.0, s * 0.45), 8)
		for i in seg:
			solar(p, f, seg_l, 0.7, Vector3(-0.1, 0.0, s * (0.62 + seg_l * 0.5 + i * (seg_l + 0.04))), Vector3.ZERO)
	# instrument boom with magnetometer + camera turret
	cylx(p, 0.015, 0.015, 1.0, dark, Vector3(1.0, 0.05, 0.1), 6)
	ball(p, 0.06, acc, Vector3(1.52, 0.05, 0.1))
	cylx(p, 0.12, 0.12, 0.3, hull, Vector3(0.62, -0.08, -0.12), 18)
	cylx(p, 0.09, 0.09, 0.04, dark, Vector3(0.78, -0.08, -0.12), 16)
	# thruster quads
	for s in [-1.0, 1.0]: box(p, Vector3(0.08, 0.08, 0.08), dark, Vector3(0.35, -0.28, s * 0.25))
	name_label(p, name, _col(L.acc).darkened(0.3), Vector3(0.0, -0.05, 0.31), 0.24, true)

static func _orbiter(p: Node3D, f: String, name: String, rng: RandomNumberGenerator) -> void:
	var L: Dictionary = LIVERY[f]
	var hull := mat(_col(L.hull), 0.3, 0.4)
	var foil := mat(_col(L.foil), 0.9, 0.25)
	var acc := mat(_col(L.acc), 0.2, 0.5)
	var trim := mat(_col(L.trim), 0.3, 0.5)
	var dark := mat(Color("#2a2d36"), 0.5, 0.5)
	# central bus cylinder
	cylx(p, 0.4, 0.4, 1.5, hull, Vector3.ZERO, 32)
	cylx(p, 0.405, 0.405, 0.12, acc, Vector3(0.4, 0, 0), 32)
	cylx(p, 0.405, 0.405, 0.05, trim, Vector3(0.25, 0, 0), 32)
	cylx(p, 0.405, 0.405, 0.12, acc, Vector3(-0.45, 0, 0), 32)
	# nose: sensor cone + instrument deck
	cylx(p, 0.12, 0.4, 0.35, foil, Vector3(0.92, 0, 0), 28)
	cylx(p, 0.08, 0.08, 0.2, dark, Vector3(1.18, 0, 0), 14)
	# main engine
	nozzle(p, 0.3, 0.55, Vector3(-1.02, 0, 0), true)
	# two propellant tanks hanging beside the bus
	var tanks := 2 + 2 * rng.randi_range(0, 1)
	for i in tanks:
		var a := PI / 4 + TAU * i / tanks
		var d := Vector3(0, sin(a), cos(a))
		cylx(p, 0.17, 0.17, 0.9, mat(Color("#cfd4dc"), 0.5, 0.35), d * 0.58 + Vector3(-0.1, 0, 0), 22)
		ball(p, 0.17, mat(Color("#cfd4dc"), 0.5, 0.35), d * 0.58 + Vector3(0.35, 0, 0))
		ball(p, 0.17, mat(Color("#cfd4dc"), 0.5, 0.35), d * 0.58 + Vector3(-0.55, 0, 0))
	# solar wings: one or two pairs
	var pairs := 1 + rng.randi_range(0, 1)
	var wl := 0.9 + rng.randf() * 0.5
	for k in pairs:
		for s in [-1.0, 1.0]:
			var xo := 0.1 - k * 0.6
			box(p, Vector3(0.05, 0.05, 0.5), dark, Vector3(xo, 0.0, s * 0.6), Vector3.ZERO)
			solar(p, f, wl, 0.5, Vector3(xo, 0.0, s * (0.84 + wl * 0.5)), Vector3.ZERO)
	# dish on a mast and a magnetometer boom
	cyly(p, 0.03, 0.03, 0.5, dark, Vector3(0.55, 0.62, 0.0), 8)
	dish(p, 0.38, hull, Vector3(0.55, 0.88, 0.0), Vector3(0.0, 0, 0.0))
	cylx(p, 0.012, 0.012, 1.2, dark, Vector3(0.3, -0.48, 0.0), 6)
	name_label(p, name, _col(L.acc).darkened(0.35), Vector3(0.0, 0.0, 0.405), 0.28, true)

static func _telescope(p: Node3D, f: String, name: String, rng: RandomNumberGenerator) -> void:
	var L: Dictionary = LIVERY[f]
	var hull := mat(_col(L.hull), 0.25, 0.45)
	var foil := mat(_col(L.foil), 0.9, 0.25)
	var acc := mat(_col(L.acc), 0.2, 0.5)
	var dark := mat(Color("#1d1f26"), 0.4, 0.6)
	var gold := mat(Color("#e7b83c"), 1.0, 0.18)
	# barrel and baffle, aperture toward +X
	cylx(p, 0.46, 0.46, 1.8, hull, Vector3.ZERO, 36)
	cylx(p, 0.48, 0.48, 0.1, acc, Vector3(0.55, 0, 0), 36)
	cylx(p, 0.5, 0.46, 0.35, dark, Vector3(1.0, 0, 0), 36)
	# segmented hex primary mirror inside the aperture
	var hexr := 0.15
	var cells: Array = [Vector2(0, 0)]
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		cells.append(Vector2(cos(a), sin(a)) * hexr * 1.76)
	for i in 6:
		var a := TAU * i / 6.0
		cells.append(Vector2(cos(a), sin(a)) * hexr * 3.04)
	for c in cells:
		cylx(p, hexr * 0.97, hexr * 0.97, 0.03, gold, Vector3(0.88, c.x, c.y), 6)
	# secondary mirror on three struts
	for i in 3:
		var a := TAU * i / 3.0
		var d := Vector3(0, sin(a), cos(a))
		box(p, Vector3(0.9, 0.025, 0.025), dark, d * 0.26 + Vector3(1.35, 0, 0), Vector3(0, 0, 0.0)).rotation = Vector3(a, 0, 0.0)
	ball(p, 0.09, gold, Vector3(1.72, 0, 0))
	# sunshield: big flat sail under the barrel
	box(p, Vector3(1.9, 0.02, 1.6), mat(Color("#d7d2c3"), 0.6, 0.5), Vector3(0.1, -0.56, 0))
	box(p, Vector3(1.9, 0.015, 1.6), foil, Vector3(0.1, -0.585, 0))
	# bus and engine at the back
	box(p, Vector3(0.5, 0.7, 0.7), hull, Vector3(-1.05, 0, 0))
	nozzle(p, 0.16, 0.3, Vector3(-1.45, 0, 0))
	# solar wings
	var wl := 0.8 + rng.randf() * 0.5
	for s in [-1.0, 1.0]:
		box(p, Vector3(0.04, 0.04, 0.4), dark, Vector3(-1.0, 0.0, s * 0.55))
		solar(p, f, wl, 0.6, Vector3(-1.0, 0.0, s * (0.75 + wl * 0.5)), Vector3.ZERO)
	dish(p, 0.22, hull, Vector3(-0.95, 0.4, 0.0), Vector3(0.4, 0, 0.0))
	name_label(p, name, _col(L.acc).darkened(0.3), Vector3(0.0, 0.0, 0.465), 0.24, true)

# ---------------- crew vehicles ----------------
## CV-n grows with n: capsule + crew module at the nose, (n-2) hab / tank sections behind it, radiators and a spin ring
## from CV-6, a big engine cluster and extra solar arrays from CV-7, and a second hull plus the largest ring on CV-9.
static func _crew(p: Node3D, f: String, name: String, n: int, rng: RandomNumberGenerator) -> void:
	var L: Dictionary = LIVERY[f]
	var hull := mat(_col(L.hull), 0.3, 0.42)
	var foil := mat(_col(L.foil), 0.9, 0.25)
	var acc := mat(_col(L.acc), 0.2, 0.5)
	var trim := mat(_col(L.trim), 0.3, 0.5)
	var dark := mat(Color("#2a2d36"), 0.5, 0.5)
	var tank := mat(Color("#cfd4dc"), 0.5, 0.35)
	var glass := mat(Color("#7fc8ff"), 0.2, 0.1, 0.6)
	var R := 0.42 + 0.025 * n
	var x := 0.0
	# nose: docking port, capsule cone, crew module with windows
	cylx(p, 0.1, 0.12, 0.2, dark, Vector3(x + 1.25, 0, 0), 16)
	cylx(p, 0.14, 0.3, 0.1, trim, Vector3(x + 1.1, 0, 0), 20)
	cylx(p, R * 0.62, R, 0.75, hull, Vector3(x + 0.7, 0, 0), 32)
	cylx(p, R * 1.01, R * 1.01, 0.1, acc, Vector3(x + 0.38, 0, 0), 32)
	for i in 4:
		var a := PI * 0.5 + i * 0.3 - 0.45
		ball(p, 0.05, glass, Vector3(x + 0.85, sin(a) * R * 0.78, cos(a) * R * 0.78), Vector3(1, 1, 0.5))
	cylx(p, R, R, 1.0, hull, Vector3(x - 0.15, 0, 0), 32)
	cylx(p, R * 1.012, R * 1.012, 0.06, trim, Vector3(x - 0.15, 0, 0), 32)
	x -= 0.65
	# hab / tank sections
	var sections := maxi(0, n - 2)
	var tank_every := 2 if n >= 4 else 99
	for i in sections:
		var seg_len := 0.8 + rng.randf() * 0.25
		var is_tank := (i % tank_every) == tank_every - 1
		var r := R * (0.95 if is_tank else 1.0)
		var m := tank if is_tank else hull
		cylx(p, r, r, seg_len, m, Vector3(x - seg_len * 0.5, 0, 0), 32)
		cylx(p, r * 1.012, r * 1.012, 0.07, acc if (i + int(rng.randf() * 2)) % 2 == 0 else trim, Vector3(x - 0.04, 0, 0), 32)
		if not is_tank:
			for k in 3: ball(p, 0.04, glass, Vector3(x - seg_len * (0.25 + 0.25 * k), R * 0.98, 0.0), Vector3(1.2, 0.5, 1.2))
		else:
			for k in 2: cylx(p, 0.12, 0.12, seg_len * 0.7, tank, Vector3(x - seg_len * 0.5, R * 0.9 * (1 if k == 0 else -1), R * 0.9), 16)
		x -= seg_len
	# service module + engine cluster at the tail
	cylx(p, R, R * 0.85, 0.7, foil, Vector3(x - 0.35, 0, 0), 32)
	x -= 0.7
	var engines := 1 if n <= 3 else (2 if n <= 5 else (3 if n <= 7 else (4 if n == 8 else 5)))
	if engines == 1: nozzle(p, 0.3 + 0.01 * n, 0.5, Vector3(x - 0.25, 0, 0), true)
	else:
		for i in engines:
			var a := TAU * i / engines + (PI / 2 if engines == 2 else 0.0)
			var off := R * 0.5 if engines > 1 else 0.0
			nozzle(p, 0.2, 0.5, Vector3(x - 0.25, sin(a) * off, cos(a) * off), true)
		if engines == 5: nozzle(p, 0.26, 0.6, Vector3(x - 0.3, 0, 0), true)
	var tail_x := x
	var total_l := 2.4 + sections * 0.9
	# solar arrays: size and count scale with the ship
	var pairs := 1 if n <= 4 else (2 if n <= 7 else 3)
	var wl := 0.9 + 0.11 * n + rng.randf() * 0.3
	for k in pairs:
		var xo := -0.2 - k * (total_l * 0.28)
		for s in [-1.0, 1.0]:
			box(p, Vector3(0.05, 0.05, R * 0.6), dark, Vector3(xo, 0, s * (R + R * 0.3)))
			solar(p, f, wl, 0.62, Vector3(xo, 0, s * (R + R * 0.6 + wl * 0.5)), Vector3.ZERO)
			if n >= 5: solar(p, f, wl * 0.7, 0.62, Vector3(xo, 0, s * (R + R * 0.6 + wl * 1.04 + wl * 0.35)), Vector3.ZERO)
	# radiators from CV-5
	if n >= 5:
		for s in [-1.0, 1.0]:
			box(p, Vector3(1.2 + 0.1 * n, 0.02, 0.5 + 0.03 * n), mat(Color("#f1f2f6"), 0.4, 0.4), Vector3(x + 1.0, s * (R + 0.25), 0.0))
			box(p, Vector3(1.2 + 0.1 * n, 0.012, 0.03 + 0.0), acc, Vector3(x + 1.0, s * (R + 0.25) + 0.012, 0.0))
	# spin ring habitat from CV-6
	if n >= 6:
		var rr := R + 0.55 + 0.05 * (n - 6)
		var rx := -total_l * 0.35
		ring(p, rr - 0.1, rr + 0.1, hull, Vector3(rx, 0, 0), Vector3(0, 0, PI / 2))
		for i in 6:
			var a := TAU * i / 6.0
			var spoke := box(p, Vector3(0.03, rr - R, 0.03), dark, Vector3(rx, 0, 0))
			spoke.position = Vector3(rx, sin(a) * (rr + R) * 0.5, cos(a) * (rr + R) * 0.5)
			spoke.rotation = Vector3(-a, 0, 0)
	# command bridge fin and extra hull for the biggest ships
	if n >= 8:
		box(p, Vector3(0.9, 0.35, 0.1), acc, Vector3(0.1, R + 0.15, 0))
		box(p, Vector3(0.9, 0.35, 0.1), acc, Vector3(0.1, -R - 0.15, 0))
	if n >= 9:
		for s in [-1.0, 1.0]:
			cylx(p, 0.34, 0.34, total_l * 0.6, hull, Vector3(-total_l * 0.2, 0, s * (R + 0.45)), 28)
			nozzle(p, 0.24, 0.45, Vector3(tail_x + 0.2, 0, s * (R + 0.45)), true)
	# antenna + dish on the capsule collar
	dish(p, 0.2 + 0.015 * n, hull, Vector3(0.1, R + 0.05, R * 0.3), Vector3(0.2, 0, 0))
	name_label(p, name, _col(L.acc).darkened(0.3), Vector3(-0.15, 0.0, R + 0.012), 0.24 + 0.008 * n, true)
