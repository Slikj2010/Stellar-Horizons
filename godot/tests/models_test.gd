extends SceneTree
func _init() -> void:
	var g = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	var n := 0
	var worst := 0.0
	for k in g.UNITS:
		var u: Dictionary = g.UNITS[k]
		var f: String = k.split("|")[0]
		var m := UnitModels.build(f, u.n, u.k)
		var r: float = m.get_meta("radius")
		var cnt := 0
		var st := [m]
		while st.size():
			var x: Node = st.pop_back()
			cnt += 1
			for c in x.get_children(): st.append(c)
		if n < 3 or r > worst: print(k, " ", u.k, " r=", snappedf(r, 0.01), " nodes=", cnt)
		worst = maxf(worst, r)
		m.free()
		n += 1
	print("built ", n, " models")
	quit()
