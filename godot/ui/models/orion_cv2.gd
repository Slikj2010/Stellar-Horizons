## North America's Orion (CV-2), modelled on its printed token: a faceted crew capsule with a docking collar and
## dark windows, a long service module in patched white / grey panels, and twin dark engine bells at the tail.
## The nose points to +X. Not wired into the game yet; see tools/orion_preview.gd for the turntable renders.
class_name OrionCV2
extends RefCounted

const CAPSULE_R0 := 0.26   ## nose radius
const CAPSULE_R1 := 0.64   ## radius where the capsule meets the service module
const CAPSULE_L := 1.0
const BODY_R := 0.64
const BODY_L := 1.7

static var _tex := {}

static func _panel_image(w: int, h: int, cols: int, rows: int, seed_v: int, dark_rate: float) -> ImageTexture:
	var key := "p%d_%d_%d_%d_%d_%.2f" % [w, h, cols, rows, seed_v, dark_rate]
	if _tex.has(key): return _tex[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#3a3d44"))
	var tones := [Color("#d6d9de"), Color("#b9bdc5"), Color("#9ea3ac"), Color("#868b95"), Color("#e4e6ea"), Color("#c4c8cf")]
	var cw := w / cols
	var ch := h / rows
	for r in rows:
		for c in cols:
			var col: Color = tones[rng.randi() % tones.size()]
			img.fill_rect(Rect2i(c * cw + 2, r * ch + 2, cw - 4, ch - 4), col)
			# bolt rows / shading band on each tile
			img.fill_rect(Rect2i(c * cw + 2, r * ch + 2, cw - 4, 3), col.darkened(0.12))
			if rng.randf() < dark_rate:
				var iw := int(cw * rng.randf_range(0.35, 0.7))
				var ih := int(ch * rng.randf_range(0.35, 0.65))
				img.fill_rect(Rect2i(c * cw + (cw - iw) / 2, r * ch + (ch - ih) / 2, iw, ih), Color("#1f2125"))
				img.fill_rect(Rect2i(c * cw + (cw - iw) / 2 + 2, r * ch + (ch - ih) / 2 + 2, iw - 4, 2), Color("#3b3e45"))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

static func _flag_us() -> ImageTexture:
	if _tex.has("us"): return _tex["us"]
	var img := Image.create(130, 70, false, Image.FORMAT_RGBA8)
	for y in 70:
		img.fill_rect(Rect2i(0, y, 130, 1), Color("#d9482f") if (y / 5) % 2 == 0 else Color("#f4f1ea"))
	img.fill_rect(Rect2i(0, 0, 56, 38), Color("#3a5aa8"))
	for i in 5:
		for j in 4: img.fill_rect(Rect2i(6 + i * 10, 5 + j * 9, 3, 3), Color("#f4f1ea"))
	var t := ImageTexture.create_from_image(img)
	_tex["us"] = t
	return t

static func _flag_ca() -> ImageTexture:
	if _tex.has("ca"): return _tex["ca"]
	var img := Image.create(130, 70, false, Image.FORMAT_RGBA8)
	img.fill(Color("#f4f1ea"))
	img.fill_rect(Rect2i(0, 0, 32, 70), Color("#d9282f"))
	img.fill_rect(Rect2i(98, 0, 32, 70), Color("#d9282f"))
	var leaf := PackedVector2Array([Vector2(65, 10), Vector2(72, 26), Vector2(86, 22), Vector2(80, 40), Vector2(92, 46), Vector2(70, 50), Vector2(69, 62), Vector2(61, 62), Vector2(60, 50), Vector2(38, 46), Vector2(50, 40), Vector2(44, 22), Vector2(58, 26)])
	for y in range(8, 64):
		for x in range(34, 96):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), leaf): img.set_pixel(x, y, Color("#d9282f"))
	var t := ImageTexture.create_from_image(img)
	_tex["ca"] = t
	return t

static func _m(col: Color, metal := 0.35, rough := 0.5) -> StandardMaterial3D:
	return UnitModels.mat(col, metal, rough)

static func _glow(col: Color) -> StandardMaterial3D:
	var m := _m(col, 0.0, 0.3)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.6
	return m

static func _tm(tex: Texture2D, uv := Vector3.ONE, metal := 0.3, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = uv
	m.metallic = metal
	m.roughness = rough
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Orion_CV2"
	var core := Node3D.new()
	core.name = "Core"
	root.add_child(core)
	var dark := _m(Color("#23252b"), 0.5, 0.55)
	var steel := _m(Color("#8a8f98"), 0.8, 0.35)
	var white := _m(Color("#e9ebef"), 0.3, 0.45)
	var blue := _m(Color("#1f4f8f"), 0.3, 0.5)
	var glass := _m(Color("#0e1218"), 0.9, 0.12)

	# ---- service module: long cylinder wrapped in patched panels; x from 0 (capsule joint) back to -BODY_L ----
	var body := UnitModels.cylx(core, BODY_R, BODY_R, BODY_L, _tm(_panel_image(1024, 256, 24, 6, 11, 0.16), Vector3(1, 1, 1)), Vector3(-BODY_L * 0.5, 0, 0), 48)
	body.name = "ServiceModule"
	# structural rings (blue band like the token's header) and end plates
	for x in [0.0, -0.42, -0.85, -1.28, -BODY_L]:
		UnitModels.cylx(core, BODY_R + 0.012, BODY_R + 0.012, 0.045, steel if x != -0.85 else blue, Vector3(x, 0, 0), 48)
	# a few dark vents and a radiator slab on the flanks
	for s in [-1.0, 1.0]:
		UnitModels.box(core, Vector3(0.5, 0.012, 0.28), _m(Color("#2b2e34"), 0.4, 0.6), Vector3(-0.4, s * (BODY_R + 0.005), 0.0))
		UnitModels.box(core, Vector3(0.34, 0.02, 0.12), steel, Vector3(-1.1, s * (BODY_R + 0.01), 0.18))

	# ---- aft taper and the twin engine bells ----
	UnitModels.cylx(core, BODY_R, BODY_R * 0.82, 0.32, _m(Color("#4a4e57"), 0.6, 0.45), Vector3(-BODY_L - 0.16, 0, 0), 48)
	var tail_x := -BODY_L - 0.34
	for s in [-1.0, 1.0]:
		var by: float = s * 0.27
		UnitModels.cylx(core, 0.1, 0.07, 0.12, steel, Vector3(tail_x + 0.04, by, 0), 20)         # throat
		UnitModels.cylx(core, 0.15, 0.1, 0.34, dark, Vector3(tail_x - 0.12, by, 0), 24)          # bell
		UnitModels.cylx(core, 0.155, 0.155, 0.03, steel, Vector3(tail_x - 0.3, by, 0), 24)       # lip
		UnitModels.ball(core, 0.07, _glow(Color("#7fd0ff")), Vector3(tail_x - 0.2, by, 0), Vector3(1.2, 1, 1))
	# gimbal frame + small RCS quads around the tail ring
	UnitModels.box(core, Vector3(0.12, 0.7, 0.05), steel, Vector3(tail_x + 0.1, 0, 0))
	for i in 4:
		var a := PI / 4 + TAU * i / 4
		var d := Vector3(0, sin(a), cos(a))
		UnitModels.cylx(core, 0.028, 0.045, 0.08, dark, d * (BODY_R * 0.95) + Vector3(-BODY_L + 0.1, 0, 0), 10)

	# ---- crew capsule: faceted frustum, nose to +X ----
	var cap := UnitModels.cylx(core, CAPSULE_R0, CAPSULE_R1, CAPSULE_L, _tm(_panel_image(512, 128, 12, 3, 5, 0.22), Vector3(1, 1, 1), 0.3, 0.45), Vector3(CAPSULE_L * 0.5, 0, 0), 12)
	cap.name = "Capsule"
	UnitModels.cylx(core, CAPSULE_R1 + 0.012, CAPSULE_R1 + 0.012, 0.05, blue, Vector3(0.025, 0, 0), 48)   # joint collar
	# rounded nose cap, docking collar and port
	UnitModels.ball(core, CAPSULE_R0 * 1.02, white, Vector3(CAPSULE_L, 0, 0), Vector3(0.5, 1, 1))
	UnitModels.cylx(core, 0.17, 0.2, 0.12, steel, Vector3(CAPSULE_L + 0.1, 0, 0), 24)
	UnitModels.cylx(core, 0.15, 0.15, 0.04, dark, Vector3(CAPSULE_L + 0.18, 0, 0), 24)
	UnitModels.cylx(core, 0.06, 0.06, 0.03, white, Vector3(CAPSULE_L + 0.2, 0, 0), 16)
	# windows near the nose and a dark hatch, as on the token
	for a in [-0.55, -0.18, 0.18, 0.55]:
		var wy := sin(a) * 0.3
		var wz := cos(a) * 0.3
		var wnd := UnitModels.box(core, Vector3(0.1, 0.085, 0.055), glass, Vector3(0.72, wy, wz), Vector3(a, 0, 0))
		wnd.name = "Window"
	UnitModels.box(core, Vector3(0.16, 0.14, 0.014), dark, Vector3(0.38, 0.0, -0.595))
	# capsule RCS and antenna blade
	for i in 3:
		var a2 := TAU * i / 3.0
		UnitModels.box(core, Vector3(0.05, 0.05, 0.05), dark, Vector3(0.12, sin(a2) * (CAPSULE_R1 - 0.02), cos(a2) * (CAPSULE_R1 - 0.02)), Vector3(a2, 0, 0))
	UnitModels.box(core, Vector3(0.22, 0.02, 0.16), steel, Vector3(0.28, CAPSULE_R1 * 0.78 + 0.05, 0.0))

	# the flags sit on a flat decal pad on the capsule's side
	var flank := Node3D.new()
	flank.name = "Flags"
	core.add_child(flank)
	var cx := 0.55
	var rr := lerpf(CAPSULE_R0, CAPSULE_R1, cx / CAPSULE_L) + 0.004
	var tilt2 := atan2(CAPSULE_R1 - CAPSULE_R0, CAPSULE_L)
	for k in 2:
		var q2 := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.2, 0.108)
		q2.mesh = qm
		q2.material_override = _tm(_flag_us() if k == 0 else _flag_ca(), Vector3.ONE, 0.0, 0.7)
		q2.position = Vector3(cx - 0.12 + k * 0.24, 0.0, rr)
		q2.rotation = Vector3(0, 0, tilt2 * 0.0)
		flank.add_child(q2)
		q2.rotation = Vector3(0, 0, 0)

	var bb := UnitModels._bounds(core)
	core.position = -bb.get_center()
	root.set_meta("radius", maxf(bb.size.length() * 0.5, 0.3))
	return root
