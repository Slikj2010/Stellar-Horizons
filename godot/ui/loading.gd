## Full-screen loading overlay: shown while the game's art and the 2.5D scene are prepared, so nothing has to be built
## (and nothing freezes) the first time the player switches views.
class_name LoadingScreen
extends CanvasLayer

var _bar: ProgressBar
var _msg: Label
var _tip: Label
var _dots: Control
var _t := 0.0
var _root: Control
const TIPS := [
	"Tip: press V to switch between the flat map and the 2.5D view.",
	"Tip: drag a launch vehicle onto a ship on the Faction tab to pair them.",
	"Tip: the ` key opens the developer console.",
	"Tip: right-click a counter to see it large, front and back.",
	"Tip: Whole map shows every section along the route to Alpha Centauri.",
]

func _init() -> void:
	layer = 200
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.022, 0.045)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var sky := TextureRect.new()
	var tex = load("res://assets/sky_flat.png")
	if tex != null:
		sky.texture = tex
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sky.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky.modulate = Color(1.000, 0.878, 0.541, 0.9)
		_root.add_child(sky)
	_dots = Control.new()
	_dots.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dots.draw.connect(_draw_orbits)
	_root.add_child(_dots)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.custom_minimum_size = Vector2(520, 0)
	col.add_theme_constant_override("separation", 14)
	_root.add_child(col)
	var title := Label.new()
	title.text = "STELLAR HORIZONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	col.add_child(title)
	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	col.add_child(_msg)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(520, 8)
	_bar.max_value = 1.0
	col.add_child(_bar)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_color_override("font_color", Color(0.6, 0.68, 0.76))
	_tip.add_theme_font_size_override("font_size", 13)
	col.add_child(_tip)

func _draw_orbits() -> void:
	var c: Vector2 = _dots.size / 2.0 + Vector2(0, -150)
	for i in 3:
		var r := 46.0 + i * 24.0
		_dots.draw_arc(c, r, 0, TAU, 96, Color(0.45, 0.8, 0.95, 0.18), 1.5, true)
		var a := _t * (1.6 - i * 0.4) + i * 2.1
		_dots.draw_circle(c + Vector2(cos(a), sin(a)) * r, 4.0 - i * 0.6, Color(0.9, 0.95, 1.0, 0.95))
	_dots.draw_circle(c, 10, Color(1.0, 0.78, 0.35))
	_dots.draw_circle(c, 18, Color(1.0, 0.7, 0.3, 0.18))

func _process(dt: float) -> void:
	_t += dt
	_dots.queue_redraw()

func begin(msg: String) -> void:
	_tip.text = TIPS[randi() % TIPS.size()]
	_bar.value = 0.0
	_msg.text = msg
	_root.modulate.a = 1.0
	visible = true

func step(p: float, msg: String) -> void:
	_bar.value = p
	_msg.text = msg

func done() -> void:
	_bar.value = 1.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): visible = false)
