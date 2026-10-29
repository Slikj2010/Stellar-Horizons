## Renders every Japan crew ship:  godot --path . res://tests/jp_preview.tscn -- <outdir> [name]
extends Node
func _ready() -> void:
	var out := "/tmp/jp"
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	if args.size() > 1: only = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var svp := SubViewport.new()
	svp.size = Vector2i(960, 600)
	svp.own_world_3d = true
	svp.msaa_3d = Viewport.MSAA_4X
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#06080d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7080b0")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	svp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.rotation = Vector3(-0.6, 0.7, 0)
	svp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.7
	fill.light_color = Color("#8fa8ff")
	fill.rotation = Vector3(-0.2, -2.4, 0)
	svp.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 34
	svp.add_child(cam)
	var names: Array = JPShips.NAMES.duplicate()
	if only != "": names = [only]
	for nm in names:
		var m := JPShips.build(nm)
		svp.add_child(m)
		var r: float = m.get_meta("radius")
		for v in [["side", 0.0, 0.0], ["tq", 0.6, -0.3], ["top", 0.0, -1.5]]:
			m.rotation = Vector3(0, v[1], 0)
			cam.position = Vector3(0, 0, 2.7 * r).rotated(Vector3.RIGHT, v[2])
			cam.look_at(Vector3.ZERO, Vector3.UP)
			for i in 4: await get_tree().process_frame
			svp.get_texture().get_image().save_png("%s/%s_%s.png" % [out, nm, v[0]])
		print("saved ", nm)
		m.queue_free()
	get_tree().quit()
