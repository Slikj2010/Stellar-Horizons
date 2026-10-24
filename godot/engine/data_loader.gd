## Loads the game data exported from the web version (data/game_data.json, made by tools/export_godot_data.js).
## JSON numbers arrive as floats; whole numbers are turned back into ints so arithmetic and text match the web version.
class_name SHData
extends RefCounted

static func load_game_data(path := "res://data/game_data.json") -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + path)
		return {}
	var raw = JSON.parse_string(f.get_as_text())
	return _ints(raw)

static func _ints(v):
	if v is float:
		return int(v) if v == floorf(v) and absf(v) < 9.0e15 else v
	if v is Array:
		var out := []
		for x in v: out.append(_ints(x))
		return out
	if v is Dictionary:
		var o := {}
		for k in v: o[k] = _ints(v[k])
		return o
	return v
