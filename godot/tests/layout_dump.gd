## Prints the 3D layout's pods (for comparing with layout25.js): godot --headless --path godot -s res://tests/layout_dump.gd
extends SceneTree
func _init() -> void:
	var D: Dictionary = SHData.load_game_data().D
	var geo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geo.json"))
	var S: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sun.json"))
	var m: Array = geo.maps[S.map]
	var L := SHLayout3D.new()
	L.build(geo, D, Vector2(m[0] + S.cx * 0.4, m[1] + S.cy * 0.4))
	var o := {}
	for k in L.pods:
		var p: Dictionary = L.pods[k]
		o[k] = ["%.1f" % p.org.x, "%.1f" % p.org.y, "%.1f" % p.hub.x, "%.1f" % p.hub.y]
	print(JSON.stringify(o))
	quit()
