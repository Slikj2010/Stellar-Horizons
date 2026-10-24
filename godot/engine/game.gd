## Autoload "Game": owns the rules engine, the bots and the current campaign, and tells the UI when anything changes.
## The UI never edits the game state directly: it calls the engine through act() / next() / answer() here.
extends Node

signal changed  ## the game state changed (redraw everything)
signal toast(text: String)  ## a short message for the player (an action was refused, and why)
signal campaign_started

const SAVE_PATH := "user://campaign.save"

var data: Dictionary
var E: SHRules
var AI: SHAI
var G = null  ## the human faction's state (Dictionary), or null before a campaign starts
var pad = null  ## id of the ship staged on the faction board's launch pad
var board_node: Node = null  ## the map board (the faction board borrows its base-counter lookup)
var sel = null  ## what is selected on the board: {t: 'ship'|'base'|'world'|'npf'|'oship', id|k}

func _ready() -> void:
	data = SHData.load_game_data()
	E = SHRules.new(data.D, data.UNITS)
	AI = SHAI.new(E)

func D() -> Dictionary: return data.D
func multi() -> bool: return G != null and G.world != null

## start a campaign. opts: {scenario, variant, scrapRE, enhTrade, rerolls}; bots: [{f, variant}] (empty = solo)
func new_campaign(f: String, opts: Dictionary, bots: Array) -> void:
	sel = null
	pad = null
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
	var r = E.answer(G, choice, extra)
	if r is String and r != "": toast.emit(r)
	_after()

func next() -> void:
	if G == null or G.over: return
	if G.ask.size():
		toast.emit("Answer the open question first.")
		return
	sel = null
	if multi(): AI.advanceWorld(G)
	else: E.advance(G)
	_after()

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
	campaign_started.emit()
	changed.emit()
	return true
