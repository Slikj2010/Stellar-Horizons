## Board camera: drag to pan, wheel or pinch to zoom toward the cursor, keys to jump between systems.
extends Camera2D

const ZMIN := 0.12
const ZMAX := 1.6
var bounds := Rect2()
var dragging := false
var moved := 0.0
var _tween: Tween

func _ready() -> void:
	zoom = Vector2(0.3, 0.3)

func setup(r: Rect2) -> void:
	bounds = r
	position = r.get_center()
	zoom = Vector2.ONE * fit_zoom()

func fit_zoom() -> float:
	var vs := get_viewport_rect().size
	return clampf(minf(vs.x / bounds.size.x, vs.y / bounds.size.y), ZMIN, ZMAX)

func zoom_at(factor: float, screen_pt: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen_pt
	var z := clampf(zoom.x * factor, ZMIN, ZMAX)
	zoom = Vector2(z, z)
	force_update_scroll()
	var after := get_canvas_transform().affine_inverse() * screen_pt
	position += before - after
	_clamp()

func pan_screen(rel: Vector2) -> void:
	position -= rel / zoom.x
	_clamp()

func _clamp() -> void:
	if bounds.size == Vector2.ZERO: return
	position = position.clamp(bounds.position, bounds.end)

## glide to a map point, optionally zooming in
func fly_to(p: Vector2, z := -1.0) -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", p, 0.45)
	if z > 0: _tween.parallel().tween_property(self, "zoom", Vector2(z, z), 0.45)
