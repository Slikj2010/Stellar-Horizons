## The developer console (the ` key, or Menu > Developer console): grant resources, technologies and policies, set
## relations, and run typed commands. Everything is written to the game log as [Developer]. Port of the web version's.
class_name DevConsole
extends PanelContainer

signal closed

const RES := {"cash": "Cash ($B)", "ORE": "Ore", "SUP": "Supplies", "FUEL": "Fuel", "Phy": "Physics points", "Eng": "Engineering points",
	"Bio": "Biology points", "polm": "Politics markers", "vm": "Victory markers"}
const HELP := "Commands (faction: me or a code such as na, ru, eu, cn, as, jp, sa):\n  give <faction> <res> <n>   res: cash ore sup fuel phy eng bio pol vm (negative n takes away)\n  tech <faction> <key|all>   grant a technology   ·  untech <faction> <key>  remove one\n  pol <faction> <key> <0-3>  set a policy level (0 removes)\n  rel <faction> <other> <level>  level: 0-5 or alliance, collaboration, freetrade, neutral, embargo, war\n  list techs | list pols | list facs  ·  show <faction>  ·  clear  ·  help"

var E: SHRules
var D: Dictionary
var fac := ""
var out_lines: Array = []
var hist: Array = []
var hi := 0
var body: VBoxContainer
var out: RichTextLabel
var cmd: LineEdit
var summary: Label

func _ready() -> void:
	E = Game.E
	D = Game.data.D
	custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.1, 0.97)
	sb.border_color = Color("#4fc3d9")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	visible = false

func facs() -> Array:
	var G = Game.G
	if G == null: return []
	return G.world.facs.values() if G.world != null else [G]

func fac_of(f: String):
	var G = Game.G
	var want: String = G.f if (f == "me" or f == "") else f
	for g in facs():
		if g.f == want: return g
	return null

func open() -> void:
	if Game.G == null: return
	visible = true
	if fac_of(fac) == null: fac = Game.G.f
	build()
	cmd.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func build() -> void:
	for c in body.get_children(): c.queue_free()
	var G = Game.G
	var g = fac_of(fac)
	var st: Dictionary = E.estock(g)
	var h := HBoxContainer.new()
	body.add_child(h)
	var t := Label.new()
	t.text = "Developer console"
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var x := Button.new()
	x.text = "Close"
	x.pressed.connect(close)
	h.add_child(x)
	var fr := _row("Faction")
	var fo := OptionButton.new()
	var sel := 0
	var all := facs()
	for i in all.size():
		fo.add_item(D.FAC[all[i].f].n + (" (you)" if all[i] == G else " (bot)"), i)
		if all[i].f == g.f: sel = i
	fo.select(sel)
	fo.item_selected.connect(func(i): fac = all[i].f; build())
	fr.add_child(fo)
	summary = Label.new()
	summary.add_theme_color_override("font_color", Color("#8fa3b8"))
	summary.add_theme_font_size_override("font_size", 12)
	summary.text = "$%dB · ORE %d · SUP %d · FUEL %d · Phy %d · Eng %d · Bio %d · politics %d · VM %d" % [g.cash, st.ORE, st.SUP, st.FUEL, g.bank.Phy, g.bank.Eng, g.bank.Bio, g.polm, int(g.get("vm", 0))]
	body.add_child(summary)
	# resources
	var rr := _row("Resources")
	var ro := OptionButton.new()
	var keys: Array = RES.keys()
	for k in keys: ro.add_item(RES[k])
	rr.add_child(ro)
	var amt := SpinBox.new()
	amt.min_value = -999
	amt.max_value = 999
	amt.value = 5
	rr.add_child(amt)
	var gb := Button.new()
	gb.text = "Grant"
	gb.pressed.connect(func(): _err(give(g, keys[ro.selected], int(amt.value))))
	rr.add_child(gb)
	# technology
	var tr := _row("Technology")
	var to := OptionButton.new()
	var tk: Array = []
	for tc in D.TECH:
		if not g.tech.has(tc.k):
			to.add_item("%s (%s)" % [tc.n, E.FN[tc.f]])
			tk.append(tc.k)
	if tk.is_empty(): to.add_item("All developed")
	tr.add_child(to)
	var tb := Button.new()
	tb.text = "Grant"
	tb.pressed.connect(func(): if tk.size(): _err(tech(g, tk[to.selected], false)))
	tr.add_child(tb)
	var ta := Button.new()
	ta.text = "Grant all"
	ta.pressed.connect(func(): _err(tech(g, "all", false)))
	tr.add_child(ta)
	# policy
	var pr := _row("Policy")
	var po := OptionButton.new()
	for p in D.POL: po.add_item("%s (now %s)" % [p.n, ["none", "Basic", "Vigorous", "Unified"][E.polLv(g, p.k)]])
	pr.add_child(po)
	var pl := OptionButton.new()
	for n in ["None", "Basic", "Vigorous", "Unified"]: pl.add_item(n)
	pl.select(1)
	pr.add_child(pl)
	var pb := Button.new()
	pb.text = "Set"
	pb.pressed.connect(func(): _err(pol(g, D.POL[po.selected].k, pl.selected)))
	pr.add_child(pb)
	# relations
	var lr := _row("Relations")
	var lo := OptionButton.new()
	var lk: Array = g.rel.keys()
	for k in lk: lo.add_item("%s (now %s)" % [D.FAC[k].n, D.REL[int(g.rel[k])]])
	lr.add_child(lo)
	var ll := OptionButton.new()
	for n in D.REL: ll.add_item(n)
	if lk.size(): ll.select(int(g.rel[lk[0]]))
	lo.item_selected.connect(func(i): ll.select(int(g.rel[lk[i]])))
	lr.add_child(ll)
	var lb := Button.new()
	lb.text = "Set"
	lb.pressed.connect(func(): if lk.size(): _err(rel(g, lk[lo.selected], ll.selected)))
	lr.add_child(lb)
	out = RichTextLabel.new()
	out.custom_minimum_size = Vector2(0, 150)
	out.scroll_following = true
	out.bbcode_enabled = true
	out.add_theme_font_size_override("normal_font_size", 12)
	body.add_child(out)
	_refresh_out()
	cmd = LineEdit.new()
	cmd.placeholder_text = "Type a command, e.g. give me cash 20 (help)"
	cmd.text_submitted.connect(func(s):
		cmd.text = ""
		run(s)
		cmd.call_deferred("grab_focus"))
	body.add_child(cmd)
	var note := Label.new()
	note.text = "Changes are written to the game log as [Developer]. Toggle with the ` key."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color("#8fa3b8"))
	body.add_child(note)

func _row(label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 90
	r.add_child(l)
	body.add_child(r)
	return r

func _err(e) -> void:
	if e != null and e != "": print_line(str(e), "#ef6b5b")

func print_line(t: String, col := "") -> void:
	out_lines.append([t, col])
	if out_lines.size() > 200: out_lines.pop_front()
	_refresh_out()

func _refresh_out() -> void:
	if out == null: return
	var s := ""
	for l in out_lines:
		var txt: String = String(l[0]).replace("[", "[lb]")
		s += ("[color=%s]%s[/color]" % [l[1], txt] if l[1] != "" else txt) + "\n"
	out.text = s

func done(g, msg: String) -> void:
	E.glog(g, "[Developer] " + msg, "g")
	print_line(msg)
	Game.changed.emit()
	if visible: build()

# ---------------- commands ----------------
func give(g, r: String, n: int):
	if g == null: return "No such faction in play."
	if not RES.has(r): return "Unknown resource \"%s\"." % r
	if n == 0: return "Give a non-zero whole number."
	if r == "cash": g.cash += n
	elif r == "polm": g.polm = maxi(0, g.polm + n)
	elif r == "vm": g.vm = maxi(0, int(g.get("vm", 0)) + n)
	elif E.FIELDS.has(r): g.bank[r] = maxi(0, g.bank[r] + n)
	else:
		var st: Dictionary = E.estock(g)
		st[r] = maxi(0, int(st.get(r, 0)) + n)
	done(g, "%s: %s%d %s." % [D.FAC[g.f].n, "+" if n > 0 else "", n, RES[r]])
	return null

func tech(g, k: String, off: bool):
	if g == null: return "No such faction in play."
	if k == "all":
		var cnt := 0
		for t in D.TECH:
			if not g.tech.has(t.k): cnt += 1
			g.tech[t.k] = 1
		done(g, "%s: granted all technologies (%d new)." % [D.FAC[g.f].n, cnt])
		return null
	if not D.TECHK.has(k): return "Unknown technology \"%s\" (try: list techs)." % k
	var t: Dictionary = D.TECHK[k]
	if off:
		g.tech.erase(k)
		done(g, "%s: removed %s." % [D.FAC[g.f].n, t.n])
		return null
	if g.tech.has(k): return "%s already has %s." % [D.FAC[g.f].n, t.n]
	g.tech[k] = 1
	done(g, "%s: granted %s." % [D.FAC[g.f].n, t.n])
	return null

func pol(g, k: String, lv: int):
	if g == null: return "No such faction in play."
	var p = SHRules._find(D.POL, func(x): return x.k == k)
	if p == null: return "Unknown policy \"%s\" (try: list pols)." % k
	if lv < 0 or lv > 3: return "Level must be 0 (none) to 3 (Unified)."
	if lv > 0: g.pol[k] = lv
	else: g.pol.erase(k)
	done(g, "%s: %s." % [D.FAC[g.f].n, (["", "Basic ", "Vigorous ", "Unified "][lv] + p.n) if lv > 0 else p.n + " removed"])
	return null

func rel(g, k: String, lv: int):
	if g == null: return "No such faction in play."
	if k == "" or not g.rel.has(k): return "Unknown faction \"%s\" (codes: %s)." % [k, ", ".join(g.rel.keys())]
	if lv < 0 or lv >= D.REL.size(): return "Relation must be 0-5 or one of: %s." % ", ".join(D.REL)
	E.setRel(g, k, lv)
	done(g, "%s and %s: relations set to %s." % [D.FAC[g.f].n, D.FAC[k].n, D.REL[lv]])
	return null

func _rel_key(v: String) -> int:
	if v.is_valid_int():
		var n := v.to_int()
		return n if n >= 0 and n < D.REL.size() else -1
	for i in D.REL.size():
		if D.REL[i].to_lower().replace(" ", "") == v.to_lower().replace(" ", "").replace("_", "").replace("-", ""): return i
	return -1

func run(line: String) -> void:
	line = line.strip_edges()
	if line == "": return
	hist.append(line)
	hi = hist.size()
	print_line("> " + line, "#4fc3d9")
	var parts := line.split(" ", false)
	var c := parts[0].to_lower()
	var a: Array = Array(parts).slice(1)
	var resmap := {"cash": "cash", "ore": "ORE", "sup": "SUP", "fuel": "FUEL", "phy": "Phy", "physics": "Phy", "eng": "Eng", "engineering": "Eng",
		"bio": "Bio", "biology": "Bio", "pol": "polm", "politics": "polm", "vm": "vm", "victory": "vm"}
	var err = null
	match c:
		"help", "?": print_line(HELP)
		"clear":
			out_lines = []
			print_line("Cleared.")
		"give": err = give(fac_of(a[0] if a.size() > 0 else ""), resmap.get(String(a[1]).to_lower(), a[1]) if a.size() > 1 else "", int(a[2]) if a.size() > 2 else 0)
		"tech", "untech": err = tech(fac_of(a[0] if a.size() > 0 else ""), a[1] if a.size() > 1 else "", c == "untech")
		"pol": err = pol(fac_of(a[0] if a.size() > 0 else ""), a[1] if a.size() > 1 else "", int(a[2]) if a.size() > 2 else -1)
		"rel":
			var other: String = String(a[1]).to_lower() if a.size() > 1 else ""
			if other == "me": other = Game.G.f
			err = rel(fac_of(a[0] if a.size() > 0 else ""), other, _rel_key("".join(a.slice(2))))
		"list":
			var w: String = String(a[0]).to_lower() if a.size() else ""
			var s := ""
			if w.begins_with("tech"):
				for t in D.TECH: s += "%s  %s (%s %d)\n" % [String(t.k).rpad(6), t.n, E.FN[t.f], t.c]
			elif w.begins_with("pol"):
				for p in D.POL: s += "%s  %s\n" % [String(p.k).rpad(4), p.n]
			else:
				for g in facs(): s += "%s  %s%s\n" % [String(g.f).rpad(3), D.FAC[g.f].n, " (you)" if g == Game.G else " (bot)"]
			print_line(s.strip_edges())
		"show":
			var g = fac_of(a[0] if a.size() > 0 else "")
			if g == null: err = "No such faction in play."
			else:
				var st: Dictionary = E.estock(g)
				print_line("%s: $%dB · ORE %d SUP %d FUEL %d · Phy %d Eng %d Bio %d · politics %d · VM %d\nTechs (%d): %s" % [D.FAC[g.f].n, g.cash, st.ORE, st.SUP, st.FUEL, g.bank.Phy, g.bank.Eng, g.bank.Bio, g.polm, int(g.get("vm", 0)), g.tech.size(), " ".join(g.tech.keys())])
		_: err = "Unknown command \"%s\". Type help." % parts[0]
	if err != null: print_line(str(err), "#ef6b5b")

func _input(ev: InputEvent) -> void:
	if not visible: return
	if ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_QUOTELEFT:
			close()
			get_viewport().set_input_as_handled()
		elif cmd != null and cmd.has_focus() and ev.keycode == KEY_UP and hi > 0:
			hi -= 1
			cmd.text = hist[hi]
			cmd.caret_column = cmd.text.length()
			get_viewport().set_input_as_handled()
		elif cmd != null and cmd.has_focus() and ev.keycode == KEY_DOWN:
			hi = mini(hist.size(), hi + 1)
			cmd.text = hist[hi] if hi < hist.size() else ""
			get_viewport().set_input_as_handled()
