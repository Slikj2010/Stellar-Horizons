## Renders the five robotic explorer kinds:  godot --path . res://tests/robo_preview.tscn -- <outdir>
extends Node
func _ready() -> void:
	var out := "/tmp/robo"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var svp := SubViewport.new()
	svp.size = Vector2i(900, 700)
	svp.own_world_3d = true
	svp.msaa_3d = Viewport.MSAA_4X
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#06080d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7080b0")
	env.ambient_light_energy = 0.5
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
	for kind in RoboModels.TARGET_R.keys():
		var m := RoboModels.build_named(kind, kind)
		svp.add_child(m)
		var r: float = m.get_meta("radius")
		for v in [["a", 0.6, -0.3], ["b", 2.2, -0.2]]:
			m.rotation = Vector3(0, v[1], 0)
			cam.position = Vector3(0, 0, 2.6 * r).rotated(Vector3.RIGHT, v[2])
			cam.look_at(Vector3.ZERO, Vector3.UP)
			for i in 4: await get_tree().process_frame
			svp.get_texture().get_image().save_png("%s/%s_%s.png" % [out, kind, v[0]])
		print("saved ", kind)
		m.queue_free()
	get_tree().quit()
