## Renders turntable stills of the Orion CV-2 model:  godot --path . res://tests/orion_preview.tscn -- <outdir>
extends Node
func _ready() -> void:
	var out := "/tmp/orion"
	for a in OS.get_cmdline_user_args(): out = a
	DirAccess.make_dir_recursive_absolute(out)
	var svp := SubViewport.new()
	svp.size = Vector2i(1280, 800)
	svp.own_world_3d = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.msaa_3d = Viewport.MSAA_4X
	add_child(svp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#06080d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7080b0")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	svp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.5
	key.rotation = Vector3(-0.6, 0.7, 0)
	svp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.7
	fill.light_color = Color("#8fa8ff")
	fill.rotation = Vector3(-0.2, -2.4, 0)
	svp.add_child(fill)
	var m := OrionCV2.build()
	svp.add_child(m)
	var r: float = m.get_meta("radius")
	var cam := Camera3D.new()
	cam.fov = 34
	svp.add_child(cam)
	var views := {"side": [0.0, 0.0, 2.75], "three_quarter": [0.65, -0.28, 2.9], "rear": [2.55, -0.2, 3.0], "top": [0.0, -1.2, 3.0], "nose": [-0.5, -0.15, 2.9]}
	for vname in views:
		var v: Array = views[vname]
		m.rotation = Vector3(0, v[0], 0)
		cam.position = Vector3(0, 0, v[2] * r).rotated(Vector3.RIGHT, v[1])
		cam.look_at(Vector3.ZERO, Vector3.UP)
		for i in 4: await get_tree().process_frame
		svp.get_texture().get_image().save_png("%s/orion_%s.png" % [out, vname])
		print("saved ", vname)
	get_tree().quit()
