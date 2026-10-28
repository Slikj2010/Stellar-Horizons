## Exploration and combat screens: the explore confirmation and result (with dice), the search for life,
## search, ship and pirate combat planning, and assigning damage and base hits by hand.
## Ported from exploreConfirm / exploreResult / lifeBlock / searchScreen / combatScreen / pirateScreen /
## assignScreen and the base-hit form in index.html.
class_name SHScreens
extends RefCounted

const DIE_BG := Color(0.09, 0.13, 0.19)

# ---------------- small parts ----------------
## a die face: green border for a success, red for a failure; d100 dice are round. anim = roll the number for a moment
static func die(box: Node, v, ok: bool, d100 := false, anim := false, tip := "") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = DIE_BG
	sb.border_color = UIK.GOOD if ok else UIK.BAD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(26 if d100 else 10)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(54, 54)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.tooltip_text = tip if tip != "" else ("d100" if d100 else "d10")
	var l := Label.new()
	l.text = str(v)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://assets/fonts/InterDisplay-Bold.otf"))
	l.add_theme_font_size_override("font_size", 21 if d100 else 27)
	l.add_theme_color_override("font_color", UIK.GOOD if ok else UIK.BAD)
	p.add_child(l)
	box.add_child(p)
	if anim and Game.settings.get("anim", true) and p.is_inside_tree():
		var top := 100 if d100 else 10
		var final_txt := str(v)
		var tw := p.create_tween()
		tw.tween_method(func(_x): l.text = str(randi_range(1, top)), 0.0, 1.0, 0.45)
		tw.tween_callback(func(): l.text = final_txt)
		p.pivot_offset = Vector2(27, 27)
		var tw2 := p.create_tween()
		p.rotation = -0.5
		tw2.tween_property(p, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return p

## a row: die on the left, a bold head and a dim line on the right
static func die_row(box: Node, v, ok: bool, head: String, sub: String, d100 := false, anim := false) -> VBoxContainer:
	var h := UIK.hbox(box, 14)
	die(h, v, ok, d100, anim)
	var v2 := UIK.vbox(h, 2)
	v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if head != "": UIK.rich(v2, "[b]%s[/b]" % head, 15)
	if sub != "": UIK.para(v2, sub, UIK.DIM, 13, 0)
	return v2

## a short label that never wraps (for rows of chips and dice)
static func lbl(box: Node, txt: String, col = null, size := 13) -> Label:
	var l := UIK.para(box, txt, col, size, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

static func field_name(w: String) -> String:
	if w == "alp": return "random field"
	return SHRules.FN[Game.D().W[w].f]

static func _units(box: Node, us: Array) -> void:
	if not us.size():
		UIK.para(box, "No armed units.", UIK.DIM, 13, 0)
		return
	for u in us:
		var h := UIK.hbox(box, 6)
		var l := UIK.para(h, u.n, null, 14, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl(h, "combat %d" % int(u.cb), UIK.CYAN, 12)

static func _grid(box: Node, rows: Array, head: Array) -> void:
	var g := GridContainer.new()
	g.columns = head.size()
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 4)
	box.add_child(g)
	for h in head: lbl(g, h, UIK.AMBER, 12)
	for r in rows:
		for i in r.size(): lbl(g, str(r[i]), UIK.DIM if i == 0 else null, 14)

static func _spin_row(box: Node, label: String, hi: int, note := "") -> SpinBox:
	var h := UIK.hbox(box, 8)
	var l := UIK.para(h, label, null, 14, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := UIK.spin(h, 0, maxi(0, hi), 0, 76)
	if note != "": lbl(h, note, UIK.DIM, 12)
	return s

# ---------------- exploring ----------------
## the confirmation before exploring or dropping a probe
static func explore_confirm(main, box: Node, G, s, o) -> void:
	var E: SHRules = Game.E
	var W = Game.D().W
	var v: int = maxi(0, int(o.value))
	var auto: int = v / 10
	var rem: int = v % 10
	var probe: bool = o.kind == "probe"
	var lab: bool = s.cls == "CV" and SHRules.t(s.get("lab")) and not probe
	UIK.title(box, "Explore %s?" % W[o.w].n)
	UIK.rich(box, "%s: [color=#%s]%s[/color] research, world value [b]%d[/b]." % [W[o.w].n, UIK.FIELD_COL.get(W[o.w].f, UIK.DIM).to_html(false), field_name(o.w), int(G.w[o.w].v)])
	var mbb: String = main._missions_bb(G, [o.w], false)
	if mbb != "": UIK.rich(box, mbb)
	var who: String = ("Probe %s (from %s)" % [s.probe, s.name]) if probe else s.name
	UIK.rich(box, "%s explores at value [b]%d[/b]%s." % [who, v, (" (includes −%d for transfer box distance)" % int(o.pen)) if SHRules.t(o.get("pen")) else ""])
	var odds := ""
	if auto: odds += "%d marker%s earned automatically. " % [auto, "s" if auto > 1 else ""]
	if rem: odds += "Roll a d10: %d or less earns %s marker (%d%%%s)." % [rem, "one more" if auto else "a", rem * 10, ", mobile lab rolls two dice and keeps the better" if lab else ""]
	else: odds += "No roll needed."
	UIK.para(box, odds, UIK.DIM, 13, 400)
	var after: String = "The probe is spent afterwards." if probe else (("Then a recall check (%d%%)." % E.recall(G)) if s.cls == "CV" else ("Then a malfunction check (%d%%)." % E.malfRate(G, s)))
	UIK.para(box, after, UIK.DIM, 13, 400)
	# chance meter: the share of a d10 that hits
	if rem:
		var bar := ProgressBar.new()
		bar.max_value = 10
		bar.value = rem
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		box.add_child(bar)
	var f := UIK.flow(box)
	UIK.button(f, "Explore", func():
		main.modal.visible = false
		Game.roll_act(func(): return E.explore(G, s, o), true))
	UIK.button(f, "Cancel", func(): main.modal.visible = false)

## the result of the last roll (G.lastRoll): exploring, producing, harvesting or a search for life
static func roll_result(main, box: Node, L: Dictionary) -> void:
	var FN := SHRules.FN
	var k = L.get("kind")
	if k == "life":
		UIK.title(box, L.title)
		life_block(box, L.life, true)
	elif k != null:
		UIK.title(box, L.title)
		die_row(box, L.r, SHRules.t(L.good), L.head, L.sub, false, true)
		for t in L.extra: UIK.para(box, t, UIK.DIM, 13, 400)
	else:
		UIK.title(box, "%s explores %s" % [L.who, L.world])
		var h := UIK.hbox(box, 14)
		if int(L.rem): die(h, L.r, SHRules.t(L.hit), false, true)
		if int(L.rem) and L.get("r2") != null:
			var dv := UIK.vbox(h, 2)
			lbl(dv, "best of", UIK.DIM, 11)
			lbl(dv, "%d and %d" % [int(L.r1), int(L.r2)], UIK.DIM, 13)
			dv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var v := UIK.vbox(h, 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var res := "[b][color=#%s]%s[/color][/b] at value %d" % [(UIK.GOOD if SHRules.t(L.ok) else UIK.BAD).to_html(false), "Success" if SHRules.t(L.ok) else "Failure", int(L.val)]
		if int(L.rem): res += ": needed %d or less, rolled %d" % [int(L.rem), int(L.r)]
		UIK.rich(v, res + ".")
		if SHRules.t(L.get("alpha")):
			var ah := UIK.hbox(v, 8)
			die(ah, L.alpha, true, false, true)
			lbl(ah, "Alpha Centauri field roll: " + FN[L.field], UIK.DIM, 13)
		var got: Array = L.got
		if got.size():
			var gh := UIK.hbox(v, 6)
			lbl(gh, "Earned", UIK.DIM, 13)
			for g in got: _marker(gh, int(g), L.field)
		else: UIK.para(v, "No tech markers.", UIK.DIM, 13, 0)
		for t in L.extra: UIK.para(box, t, UIK.DIM, 13, 400)
		life_block(box, L.get("life"), true)
	var f := UIK.flow(box)
	UIK.button(f, "Continue", func(): main.modal.visible = false)

## a tech marker chip: value in the field's colour
static func _marker(box: Node, v: int, field: String) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var col: Color = UIK.FIELD_COL.get(field, UIK.DIM)
	sb.bg_color = col.darkened(0.7)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.tooltip_text = "%d %s" % [v, SHRules.FN[field]]
	var l := Label.new()
	l.text = "%d %s" % [v, SHRules.FN[field].substr(0, 3)]
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 13)
	p.add_child(l)
	box.add_child(p)

## search for life, made after a depletion: d100 against the world's life chance
static func life_block(box: Node, f, anim := false) -> void:
	if f == null or not (f is Dictionary): return
	if SHRules.t(f.get("pending")):
		UIK.para(box, "Search for life: rolled after you decide on the world card, because a card can change the chance.", UIK.DIM, 13, 400)
		return
	if SHRules.t(f.get("skip")):
		UIK.para(box, "Search for life: no roll (%s)." % f.skip, UIK.DIM, 13, 400)
		return
	var found := SHRules.t(f.found)
	var sub := "Rolled %d on d100, needed %d or less%s." % [int(f.r), int(f.need), str(f.get("bonus", "")) if f.get("bonus") != null else ""]
	if SHRules.t(f.get("reward")): sub += " " + str(f.reward) + "."
	die_row(box, f.r, found, "Search for %s: %s" % [f.seek, "found!" if found else "nothing found"], sub, true, anim)

# ---------------- questions in the dialog ----------------
static func search(box: Node, a: Dictionary) -> void:
	UIK.para(box, a.where, UIK.DIM, 13, 0)
	var h := UIK.hbox(box, 26)
	for x in a.rolls:
		var v := UIK.vbox(h, 4)
		var l := lbl(v, x.n, UIK.DIM, 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		die(v, x.r, int(x.r) <= int(a.T), false, true)
	UIK.para(box, "Contact is automatic here." if SHRules.t(a.auto) else "A search succeeds if either roll is %d or less (the rolls already include the modifiers)." % int(a.T), UIK.DIM, 13, 0)
	UIK.rich(box, "[b]%s[/b] %s" % ["Contact!" if SHRules.t(a.ok) else "No contact.", a.text])
	var f := UIK.flow(box)
	UIK.button(f, "Continue to the fight" if SHRules.t(a.ok) else "Back to the map", func(): Game.answer("ok"))

## two columns: you and them, each with units and the die
static func _sides(box: Node, left: String, mine: Array, dl, lnote: String, right: String, theirs: Array, dr, rnote: String) -> void:
	var h := UIK.hbox(box, 18)
	for side in [[left, mine, dl, lnote], [right, theirs, dr, rnote]]:
		var c := UIK.card(h)
		c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIK.head(c, side[0])
		_units(c, side[1])
		var dh := UIK.hbox(c, 10)
		die(dh, side[2], true, false, true)
		if side[3] != "": UIK.rich(dh, side[3], 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL

## the tactics-point plan controls shared by ship and pirate combat; returns nothing, wires the buttons
static func _plan(box: Node, r: int, tb: Dictionary, picks_ok: bool, default_direct: bool, on_go: Callable, can_auto: bool) -> void:
	var c := UIK.card(box)
	UIK.head(c, "Your plan (%d tactics point%s)" % [r, "s" if r > 1 else ""])
	var mh := UIK.hbox(c, 8)
	var grp := ButtonGroup.new()
	var bs := CheckBox.new()
	bs.text = "Strike (free; only Space Missiles do damage)"
	bs.button_group = grp
	bs.focus_mode = Control.FOCUS_NONE
	var bd := CheckBox.new()
	bd.text = "Direct fire (1 point)"
	bd.button_group = grp
	bd.focus_mode = Control.FOCUS_NONE
	mh.add_child(bs)
	mh.add_child(bd)
	if default_direct: bd.button_pressed = true
	else: bs.button_pressed = true
	var inc := _spin_row(c, "Increase damage you deal", r / 2, "2 points each")
	var red := _spin_row(c, "Decrease damage you take", r / 2, "2 points each")
	var picks: SpinBox = _spin_row(c, "Pick targets instead of your opponent", r, "1 point each") if picks_ok else null
	var sum := UIK.rich(c, "")
	var go_row := UIK.flow(c)
	var goh := [null]
	var upd := func():
		var dir := bd.button_pressed
		var cost: int = (1 if dir else 0) + 2 * int(inc.value) + 2 * int(red.value) + (int(picks.value) if picks != null else 0)
		var base: Dictionary = tb.direct if dir else tb.strike
		sum.text = "[b][color=#%s]%d[/color][/b] of %d points spent. You deal [b]%d[/b], you take [b]%d[/b]." % [(UIK.BAD if cost > r else UIK.GOOD).to_html(false), cost, r, int(base.dealt) + int(inc.value), maxi(0, int(base.taken) - int(red.value))]
		if goh[0] != null: goh[0].disabled = cost > r
	goh[0] = UIK.button(go_row, "Fight with this plan", func():
		on_go.call({"mode": "direct" if bd.button_pressed else "strike", "inc": int(inc.value), "red": int(red.value), "picks": int(picks.value) if picks != null else 0}))
	if r >= 3: UIK.button(go_row, "Call off the combat (3 points)", func(): Game.answer("avoid"))
	if can_auto: UIK.button(go_row, "Let the game choose", func(): Game.answer("auto"))
	for w in [inc, red, picks]:
		if w != null: w.value_changed.connect(func(_v): upd.call())
	bs.toggled.connect(func(_b): upd.call())
	bd.toggled.connect(func(_b): upd.call())
	upd.call()

## combat between factions: totals, the strike/direct table and the tactics plan
static func battle(box: Node, a: Dictionary) -> void:
	UIK.para(box, a.where, UIK.DIM, 13, 0)
	_sides(box, "You", a.mine, a.d, "[color=#8fbfc4]d10 plus combat values and 1 per extra enemy unit, then the table[/color]", a.foe, a.theirs, a.od, "")
	var sx: Dictionary = a.strike
	var dr: Dictionary = a.direct
	_grid(box, [["Strike", sx.tot, sx.otot, sx.dealt, sx.taken], ["Direct fire", dr.tot, dr.otot, dr.dealt, dr.taken]], ["", "Your total", "Their total", "You deal", "You take"])
	UIK.para(box, "Strike only damages a side with Space Missiles. Direct fire costs 1 tactics point.", UIK.DIM, 13, 0)
	var r: int = int(a.rem)
	var lose := SHRules.t(a.lose)
	var tp_txt := "[b]Tactics points:[/b] you %d, them %d. " % [int(a.tp), int(a.opp)]
	if r > 0 and not lose: tp_txt += "You can spend %d: 1 for direct fire, 2 to deal +1 damage or take 1 less, 1 to pick a target instead of your opponent (3 to call off the combat)." % r
	elif lose: tp_txt += "They won the tactics points and will decide how to fight."
	else: tp_txt += "Tied: the combat is a strike."
	UIK.rich(box, tp_txt)
	if r > 0 and not lose:
		_plan(box, r, {"strike": sx, "direct": dr}, true, false, func(p): Game.answer("plan", p), true)
	else:
		UIK.button(UIK.flow(box), "Fight", func(): Game.answer("auto"))

## combat with a pirate in a flyby box
static func pirate(box: Node, a: Dictionary) -> void:
	UIK.para(box, a.text, UIK.DIM, 13, 0)
	var p: Dictionary = a.pir
	var wnote := ("Weapons technology +%d · " % int(a.weapons)) if SHRules.t(a.get("weapons")) else ""
	_sides(box, "You", a.mine, a.st.dm, wnote + "[b]Total %d[/b]" % int(a.myTot),
		("Strong" if SHRules.t(p.strong) else "Weak") + " pirate", [{"n": "Pirate (size %d, %d damage)" % [int(p.size), int(p.dmg)], "cb": p.cb}], a.st.dp, "[b]Total %d[/b]" % int(a.pTot))
	_grid(box, [["Strike", a.strike.deal, a.strike.take], ["Direct fire", a.direct.deal, a.direct.take]], ["", "You deal", "You take"])
	UIK.para(box, "Strike only damages a side with Space Missiles (the pirate has them). Direct fire costs 1 tactics point.", UIK.DIM, 13, 0)
	var ex: int = int(a.extra)
	var txt := "[b]Tactics points:[/b] you %d, the pirate %d. " % [int(a.myTP), int(a.pTP)]
	txt += ("You can spend %d: 1 for direct fire, 2 to deal +1 damage or take 1 less%s." % [ex, ", 3 to call off the combat" if ex >= 3 else ""]) if ex > 0 else "The pirate has the advantage or it is even: no points to spend, so the fight is a strike."
	UIK.rich(box, txt)
	if ex > 0:
		var tb := {"strike": {"dealt": a.strike.deal, "taken": a.strike.take}, "direct": {"dealt": a.direct.deal, "taken": a.direct.take}}
		_plan(box, ex, tb, false, true, func(pl): Game.answer("plan", pl), false)
	else:
		UIK.button(UIK.flow(box), "Fight", func(): Game.answer("auto"))

## assign hits to units by hand (ship combat and pirate hits on a fleet)
static func assign(box: Node, a: Dictionary) -> void:
	var side_nm := {"foe": "their units", "mine": "your units", "fleet": "your ships"}
	UIK.para(box, a.text, UIK.DIM, 13, 0)
	var scr_boxes := {}
	if a.get("screen") != null and a.screen.size():
		var c := UIK.card(box)
		UIK.head(c, "Screen units")
		UIK.para(c, "Screened units are excluded from direct-fire combat and cannot be hit.", UIK.DIM, 12, 0)
		for u in a.screen:
			var cb := CheckBox.new()
			cb.text = u.n
			cb.button_pressed = true
			cb.focus_mode = Control.FOCUS_NONE
			c.add_child(cb)
			scr_boxes[u.key] = cb
	var spins := {}  # side -> {key: SpinBox}
	var counts := {}
	var goh := [null]
	var upd := func():
		var ok := true
		for g in a.groups:
			var t := 0
			for k in spins[g.side]: t += int(spins[g.side][k].value)
			counts[g.side].text = "Assigned [b][color=#%s]%d[/color][/b] of %d" % [(UIK.GOOD if t == int(g.n) else UIK.AMBER).to_html(false), t, int(g.n)]
			if t != int(g.n): ok = false
		if goh[0] != null: goh[0].disabled = not ok
	for g in a.groups:
		var c := UIK.card(box)
		UIK.head(c, "%d hit%s on %s" % [int(g.n), "s" if int(g.n) > 1 else "", side_nm.get(g.side, g.side)])
		spins[g.side] = {}
		for u in g.units:
			var s := _spin_row(c, u.n, int(g.n), "combat %d, %d to destroy" % [int(u.cb), int(u.hp)])
			spins[g.side][u.key] = s
			s.value_changed.connect(func(_v): upd.call())
		counts[g.side] = UIK.rich(c, "", 13)
	var f := UIK.flow(box)
	goh[0] = UIK.button(f, "Deal the damage", func():
		var alloc := {}
		for side in spins:
			alloc[side] = {}
			for k in spins[side]:
				var v := int(spins[side][k].value)
				if v: alloc[side][k] = v
		var scr := []
		for k in scr_boxes:
			if scr_boxes[k].button_pressed: scr.append(k)
		Game.answer("set", {"alloc": alloc, "scr": scr}))
	UIK.button(f, "Let the game choose", func(): Game.answer("auto"))
	upd.call()

## hits on an enemy base: choose which facilities (and resources) take them
static func basehit(box: Node, a: Dictionary) -> void:
	var nmz := {"def": "Defense Network", "lab": "Research Lab", "mine": "Mining", "sup": "Supply", "set": "Settlements (3 per settlement)", "res": "Resources (2 destroyed per hit)"}
	UIK.para(box, "%d hit%s to assign. Each facility takes hits equal to its size, then it is downgraded or removed. Settlements are one stacked facility: every 3 damage removes one, and a damaged one stops counting. Resources are a valid target only while a facility or settlement stands." % [int(a.n), "s" if int(a.n) > 1 else ""], UIK.DIM, 13, 0)
	var c := UIK.card(box)
	var spins := {}
	for k in nmz:
		var cap := int(SHRules.gi(a.caps, k, 0))
		if cap > 0: spins[k] = _spin_row(c, nmz[k], cap, "up to %d" % cap)
	var rc := UIK.card(box)
	var rhead := UIK.rich(rc, "", 13)
	var rsp := {}
	var rcol := {"ORE": Color("#d3f1ec"), "SUP": Color("#6fb3e8"), "FUEL": Color("#9aeadd")}
	for r in ["ORE", "SUP", "FUEL"]:
		var sl := UIK.slider(rc, r, int(SHRules.gi(a.stock, r, 0)), 0, rcol[r])
		(sl.get_meta("tail") as Label).text = "of %d" % int(SHRules.gi(a.stock, r, 0))
		rsp[r] = sl
	var sum := UIK.rich(box, "", 13)
	var goh := [null]
	var upd := func():
		var used := 0
		for k in spins: used += int(spins[k].value)
		var rhits: int = int(spins["res"].value) if spins.has("res") else 0
		var tot: int = mini(2 * rhits, int(SHRules.gi(a.stock, "ORE", 0)) + int(SHRules.gi(a.stock, "SUP", 0)) + int(SHRules.gi(a.stock, "FUEL", 0)))
		rc.get_parent().visible = tot > 0
		var rsum := 0
		for r in rsp: rsum += int(rsp[r].value)
		rhead.text = "Resources destroyed: choose [b]%d[/b] (chosen %d)" % [tot, rsum]
		sum.text = "Assigned [b][color=#%s]%d[/color][/b] of %d hits." % [(UIK.GOOD if used == int(a.n) else UIK.AMBER).to_html(false), used, int(a.n)]
		if goh[0] != null: goh[0].disabled = used != int(a.n) or (tot > 0 and rsum != tot)
	for k in spins: spins[k].value_changed.connect(func(_v): upd.call())
	for r in rsp: rsp[r].value_changed.connect(func(_v): upd.call())
	var f := UIK.flow(box)
	goh[0] = UIK.button(f, "Apply the hits", func():
		var alloc := {}
		for k in spins: alloc[k] = int(spins[k].value)
		var res = null
		if SHRules.t(alloc.get("res", 0)):
			res = {}
			for r in rsp: res[r] = int(rsp[r].value)
		Game.answer("set", {"alloc": alloc, "res": res}))
	UIK.button(f, "Let the game choose", func(): Game.answer("auto"))
	upd.call()
