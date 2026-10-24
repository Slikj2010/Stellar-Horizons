## Autoload "Game": owns the rules engine, the bots and the current campaign, and tells the UI when anything changes.
## The UI never edits the game state directly: it calls the engine through act() / next() / answer() here.
extends Node

signal changed  ## the game state changed (redraw everything)
signal toast(text: String)  ## a short message for the player (an action was refused, and why)
signal campaign_started
signal sound(name: String)  ## ask the audio node to play an effect
signal rolled  ## a die roll worth showing happened (G.lastRoll): exploring, producing, harvesting, a search for life

const SAVE_PATH := "user://campaign.save"  ## the autosave (slot 0)
const SLOTS := ["user://campaign.save", "user://slot1.save", "user://slot2.save", "user://slot3.save"]
const SETTINGS_PATH := "user://settings.cfg"

## player settings, kept in user://settings.cfg. rerolls/scrapRE apply to new games, enhTrade to every game
var settings := {"rerolls": true, "scrapRE": false, "enhTrade": false, "confirmNext": true, "autosave": true, "anim": true, "sfxVol": 0.8, "musicVol": 0.45}

var data: Dictionary
var E: SHRules
var AI: SHAI
var G = null  ## the human faction's state (Dictionary), or null before a campaign starts
var pad = null  ## id of the ship staged on the faction board's launch pad
var pad_lv := {}  ## the launch vehicle paired with it on the faction board: {id: ship id, n: LV size}
var pad_msg := ""  ## why the last pairing was refused
var board_node: Node = null  ## the map board (the faction board borrows its base-counter lookup)
var sel = null  ## what is selected on the board: {t: 'ship'|'base'|'world'|'npf'|'oship', id|k}

func _ready() -> void:
	data = SHData.load_game_data()
	E = SHRules.new(data.D, data.UNITS)
	AI = SHAI.new(E)
	load_settings()
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave()
		get_tree().quit()

func quit() -> void:
	autosave()
	get_tree().quit()

# ---------------- settings ----------------
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK: return
	for k in settings: settings[k] = cf.get_value("game", k, settings[k])

func set_setting(k: String, v) -> void:
	settings[k] = v
	var cf := ConfigFile.new()
	for key in settings: cf.set_value("game", key, settings[key])
	cf.save(SETTINGS_PATH)
	if G != null and (k == "enhTrade" or k == "scrapRE"):
		if k == "enhTrade": apply_settings(G)
		else: G.opts.scrapRE = v
		changed.emit()

## optional rules that follow the settings in every game, saved ones included
func apply_settings(g) -> void:
	var gs: Array = g.world.facs.values() if g.world != null else [g]
	for x in gs:
		if x.get("opts") == null: x.opts = {}
		x.opts.enhTrade = settings.enhTrade

func D() -> Dictionary: return data.D
func multi() -> bool: return G != null and G.world != null

## start a campaign. opts: {scenario, variant, scrapRE, enhTrade, rerolls}; bots: [{f, variant}] (empty = solo)
func new_campaign(f: String, opts: Dictionary, bots: Array) -> void:
	sel = null
	pad = null
	opts = opts.duplicate()
	opts.rerolls = settings.rerolls
	opts.scrapRE = settings.scrapRE
	opts.enhTrade = settings.enhTrade
	if bots.size():
		var o := opts.duplicate()
		o.human = f
		o.bots = bots
		G = E.newWorld(o)
		AI.begin(G)
	else:
		G = E.newGame(f, opts)
	campaign_started.emit()
	changed.emit()

## run an engine call that returns null (done) or a string (why not), then refresh
func act(result) -> void:
	if result is String and result != "": toast.emit(result)
	_after()

func answer(choice, extra = null) -> void:
	if G == null: return
	G.lastRoll = null
	var r = E.answer(G, choice, extra)
	if r is String and r != "": toast.emit(r)
	_after()
	var L = G.get("lastRoll")
	if L is Dictionary and L.get("kind") == "life": rolled.emit()

## run fn (an engine call returning null or an error text) and show its roll if it made one.
## any = show any roll (exploring); otherwise only produce/harvest/life results (those with a kind)
func roll_act(fn: Callable, any := false) -> void:
	if G == null: return
	G.lastRoll = null
	var r = fn.call()
	act(r)
	if r is String and r != "": return
	var L = G.get("lastRoll")
	if L is Dictionary and (any or L.get("kind") != null): rolled.emit()

func next() -> void:
	if G == null or G.over: return
	if G.ask.size():
		toast.emit("Answer the open question first.")
		return
	sel = null
	var y0 = G.y
	if multi(): AI.advanceWorld(G)
	else: E.advance(G)
	if G.y == y0: sound.emit("next")
	_after()
	if settings.autosave: autosave()

func autosave() -> void:
	if G != null: save_slot(0)

func _after() -> void:
	# in a multi-faction research step, let the bots take their turns until it is the human's turn again
	if multi() and G.phase == "econ" and G.estep == "tech" and not G.ask.size(): AI.techLoop(G)
	if sel != null and sel.t == "ship" and E._shipById(G, sel.id) == null: sel = null
	changed.emit()

func select(s) -> void:
	sel = s
	changed.emit()

# ---------------- saving ----------------
func _strip(g: Dictionary) -> Dictionary:
	var o := g.duplicate()
	o.erase("world")
	o.erase("_aiGoals")
	return o

func save_game(path := SAVE_PATH) -> bool:
	if G == null: return false
	var blob: Dictionary
	if multi():
		var facs := {}
		for f in G.world.facs: facs[f] = _strip(G.world.facs[f])
		blob = {"v": 3, "meta": G.world.meta, "facs": facs}
	else:
		blob = {"v": 2, "G": _strip(G)}
	var fh := FileAccess.open(path, FileAccess.WRITE)
	if fh == null: return false
	fh.store_string(var_to_str(blob))
	return true

func has_save(path := SAVE_PATH) -> bool: return FileAccess.file_exists(path)

# ---------------- save slots: 0 is the autosave, 1-3 are manual ----------------
func slot_name(i: int) -> String: return "Autosave" if i == 0 else "Slot %d" % i
func has_slot(i: int) -> bool: return FileAccess.file_exists(SLOTS[i])
func any_slot() -> bool:
	for i in SLOTS.size():
		if has_slot(i): return true
	return false

func save_slot(i: int) -> bool:
	if not save_game(SLOTS[i]): return false
	var info := {"f": G.f, "bots": (G.world.meta.order.size() - 1) if multi() else 0, "y": G.y, "phase": G.phase, "over": SHRules.t(G.over), "end": G.get("endYear"),
		"at": Time.get_datetime_string_from_system(false, true)}
	var fh := FileAccess.open(SLOTS[i] + ".info", FileAccess.WRITE)
	if fh: fh.store_string(var_to_str(info))
	return true

func load_slot(i: int) -> bool: return load_game(SLOTS[i])

## every slot in one JSON file
func export_saves(path: String) -> bool:
	var saves := {}
	for i in SLOTS.size():
		if not has_slot(i): continue
		var a := FileAccess.open(SLOTS[i], FileAccess.READ)
		var b := FileAccess.open(SLOTS[i] + ".info", FileAccess.READ)
		saves[str(i)] = {"data": a.get_as_text() if a else "", "info": b.get_as_text() if b else ""}
	var fh := FileAccess.open(path, FileAccess.WRITE)
	if fh == null: return false
	fh.store_string(JSON.stringify({"app": "stellar-horizons-godot-saves", "v": 1, "exported": Time.get_datetime_string_from_system(), "saves": saves}, "\t"))
	return true

## returns a sentence for the player
func import_saves(path: String) -> String:
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null: return "Could not read that file."
	var o = JSON.parse_string(fh.get_as_text())
	if not (o is Dictionary) or o.get("app") != "stellar-horizons-godot-saves" or not (o.get("saves") is Dictionary): return "That is not a Stellar Horizons saves file."
	var ok: Array = []
	for k in o.saves:
		var i := int(k)
		if i < 0 or i >= SLOTS.size(): continue
		var blob = str_to_var(String(o.saves[k].get("data", "")))
		if not (blob is Dictionary): continue
		var a := FileAccess.open(SLOTS[i], FileAccess.WRITE)
		if a == null: continue
		a.store_string(String(o.saves[k].data))
		a.close()
		var b := FileAccess.open(SLOTS[i] + ".info", FileAccess.WRITE)
		if b: b.store_string(String(o.saves[k].get("info", "")))
		ok.append(slot_name(i))
	return ("Imported: " + ", ".join(ok) + ". Existing saves in those slots were replaced.") if ok.size() else "No readable saves in that file."

func delete_slot(i: int) -> void:
	DirAccess.remove_absolute(SLOTS[i])
	DirAccess.remove_absolute(SLOTS[i] + ".info")

## one line about a slot: faction, bots, year and phase, when it was saved
func slot_info(i: int) -> String:
	if not has_slot(i): return "Empty"
	var fh := FileAccess.open(SLOTS[i] + ".info", FileAccess.READ)
	var o = str_to_var(fh.get_as_text()) if fh else null
	if not (o is Dictionary): return "Saved campaign"
	var D: Dictionary = data.D
	var txt: String = D.FAC[o.f].n if D.FAC.has(o.f) else str(o.f)
	if int(o.bots): txt += " + %d bot%s" % [o.bots, "s" if int(o.bots) > 1 else ""]
	txt += " · " + (("finished %s" % str(o.end)) if o.over else "%d · %s" % [int(o.y), E.PHASE_NAME.get(o.phase, o.phase)])
	return txt + " · " + str(o.at)

func load_game(path := SAVE_PATH) -> bool:
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null: return false
	var blob = str_to_var(fh.get_as_text())
	if not (blob is Dictionary): return false
	sel = null
	pad = null
	if blob.get("v") == 3:
		for f in blob.facs: blob.facs[f].world = null
		G = E.attachWorld(blob.facs, blob.meta)
	elif blob.get("v") == 2:
		G = blob.G
		G.world = null
	else: return false
	apply_settings(G)
	campaign_started.emit()
	changed.emit()
	return true
