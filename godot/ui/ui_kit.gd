## Small helpers for building the side panels and dialogs in code.
class_name UIK
extends RefCounted

const AMBER := Color("#e8702a")
const CYAN := Color("#8f96e8")
const DIM := Color("#8a8fba")
const GOOD := Color("#e8702a")
const BAD := Color("#e8508a")
const FIELD_COL := {"Phy": Color("#8f9cff"), "Eng": Color("#d8dbf2"), "Bio": Color("#e8702a")}

static var _tex_cache := {}
static var _json_cache := {}

static func clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

static func head(box: Node, txt: String, col := AMBER) -> Label:
	var l := Label.new()
	l.text = txt.to_upper()
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_constant_override("line_spacing", 0)
	box.add_child(l)
	return l

static func title(box: Node, txt: String, size := 20) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", load("res://assets/fonts/InterDisplay-Bold.otf"))
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l

static func para(box: Node, txt: String, col = null, size := 14, minw := 120) -> Label:
	var l := Label.new()
	l.text = txt
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minw
	l.add_theme_font_size_override("font_size", size)
	if col != null: l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l

static func rich(box: Node, bb: String, size := 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bb
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	box.add_child(r)
	return r

static func button(box: Node, txt: String, cb: Callable, disabled := false, tip := "") -> Button:
	var b := Button.new()
	b.text = txt
	b.disabled = disabled
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	box.add_child(b)
	return b

static func flow(box: Node) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	box.add_child(f)
	return f

static func hbox(box: Node, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	box.add_child(h)
	return h

static func vbox(box: Node, sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	box.add_child(v)
	return v

static func sep(box: Node) -> void:
	var s := HSeparator.new()
	s.add_theme_color_override("separator", Color(0.353, 0.376, 0.659, 1))
	box.add_child(s)

## a card-like row: a framed panel holding a vbox
static func card(box: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.094, 0.14, 1)
	sb.border_color = Color(0.353, 0.376, 0.659, 1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v

static func json(path: String) -> Dictionary:
	if not _json_cache.has(path):
		var f := FileAccess.open(path, FileAccess.READ)
		_json_cache[path] = JSON.parse_string(f.get_as_text()) if f else {}
	return _json_cache[path]

## an atlas image as a texture: faction counters (atlas_<f>) or markers ('markers')
static func atlas_tex(sheet: String, key: String):
	var ck := sheet + "/" + key
	if _tex_cache.has(ck): return _tex_cache[ck]
	var fr = json("res://assets/%s.json" % sheet).get(key)
	if fr == null: return null
	var a := AtlasTexture.new()
	a.atlas = load("res://assets/%s.webp" % sheet)
	a.region = Rect2(fr[0], fr[1], fr[2], fr[3])
	_tex_cache[ck] = a
	return a

static func image(box: Node, tex, size: float, tip := "") -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.tooltip_text = tip
	box.add_child(t)
	return t

static func spin(box: Node, lo: int, hi: int, val: int, w := 70) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = val
	s.custom_minimum_size.x = w
	box.add_child(s)
	return s

## a labelled slider (whole numbers) with its value shown on the right; returns the HSlider
static func slider(box: Node, label: String, hi: int, val := 0, col = null, w := 220) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 96
	if col != null: l.add_theme_color_override("font_color", col)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = maxi(hi, 0)
	sl.step = 1
	sl.value = clampi(val, 0, maxi(hi, 0))
	sl.custom_minimum_size = Vector2(w, 24)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	sl.editable = hi > 0
	row.add_child(sl)
	var v := Label.new()
	v.custom_minimum_size.x = 30
	v.text = str(int(sl.value))
	row.add_child(v)
	sl.value_changed.connect(func(x): v.text = str(int(x)))
	var tail := Label.new()
	tail.add_theme_color_override("font_color", DIM)
	row.add_child(tail)
	sl.set_meta("tail", tail)
	return sl

## sliders that share one budget: together they never go above cap (the one being moved gives way); on_change runs after each move
static func share_cap(sliders: Array, cap: int, on_change: Callable) -> void:
	var busy := [false]
	for sl in sliders:
		sl.value_changed.connect(func(_x):
			if busy[0]: return
			var tot := 0
			for o in sliders: tot += int(o.value)
			if tot > cap:
				busy[0] = true
				sl.value = int(sl.value) - (tot - cap)
				busy[0] = false
			on_change.call())

static func pick(box: Node, items: Array, sel := 0) -> OptionButton:
	var o := OptionButton.new()
	for it in items: o.add_item(str(it))
	if items.size(): o.selected = clampi(sel, 0, items.size() - 1)
	o.focus_mode = Control.FOCUS_NONE
	box.add_child(o)
	return o

## resources as text with colours: 2 ORE + 1 SUP
static func res_bb(o) -> String:
	var parts := []
	var cols := {"ORE": "#d8dbf2", "SUP": "#8f9cff", "FUEL": "#e8702a"}
	for r in ["ORE", "SUP", "FUEL"]:
		var v := int(SHRules.gi(o, r, 0))
		if v: parts.append("[color=%s]%d %s[/color]" % [cols[r], v, r])
	return " + ".join(parts) if parts.size() else "nothing"
