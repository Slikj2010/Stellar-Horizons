## Sound effects and ambient music. Effects are picked from what happens: button clicks, dice rolls and their results,
## refusals, phase and year changes, and new lines in your log (launches, moves, building, trading, combat damage,
## new technologies). Volumes are in Settings. The sounds are synthesized by tools/make_sounds.py.
extends Node

const SOUNDS := ["click", "select", "error", "next", "year", "dice", "success", "failure", "launch", "move", "explore", "found", "alarm", "boom", "build", "coins"]
## log text -> sound, first match wins (checked in this order)
const LOG_SOUNDS := [["boom", ["destroyed", " hits ", "damage", "is lost", "malfunctions"]], ["launch", ["moves from Earth to", "launches"]],
	["build", ["builds ", "founds ", "upgrades ", "settlement", "repairs "]], ["move", [" moves from "]],
	["coins", [" sells ", " buys ", "trades", "trade marker"]], ["success", ["develops ", "adopts ", "mission complete", "completes"]]]

var streams := {}
var pool: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var _last_log = null
var _last_year := -1
var _last_ask = null
var _cool := {}

func _ready() -> void:
	for s in SOUNDS:
		var st = load("res://assets/audio/%s.ogg" % s)
		if st != null: streams[s] = st
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music = AudioStreamPlayer.new()
	var ms = load("res://assets/audio/music_space.ogg")
	if ms is AudioStreamOggVorbis: ms.loop = true
	music.stream = ms
	add_child(music)
	apply_volumes()
	music.play()
	Game.sound.connect(play)
	Game.toast.connect(func(_t): play("error"))
	Game.rolled.connect(_on_roll)
	Game.changed.connect(_on_changed)
	Game.campaign_started.connect(func():
		_last_log = null
		_last_year = -1)
	get_tree().node_added.connect(_hook)
	_hook_all(get_tree().root)

func apply_volumes() -> void:
	var mv: float = Game.settings.get("musicVol", 0.45)
	music.volume_db = linear_to_db(maxf(mv, 0.0001)) - 12.0
	music.stream_paused = mv <= 0.001

## play one effect (several can overlap); the same effect at most every 60 ms
func play(name: String, vol := 1.0) -> void:
	var sv: float = Game.settings.get("sfxVol", 0.8)
	if sv <= 0.001 or not streams.has(name): return
	var now := Time.get_ticks_msec()
	if now - int(_cool.get(name, -1000)) < 60: return
	_cool[name] = now
	for p in pool:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = linear_to_db(sv * vol)
			p.play()
			return

func play_later(name: String, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func(): play(name))

# ---------------- what triggers sounds ----------------
func _hook_all(n: Node) -> void:
	_hook(n)
	for c in n.get_children(): _hook_all(c)

func _hook(n: Node) -> void:
	if n is BaseButton and not n.has_meta("sfx"):
		n.set_meta("sfx", true)
		n.pressed.connect(func(): play("click", 0.6))

func _on_roll() -> void:
	var L = Game.G.get("lastRoll") if Game.G != null else null
	if not (L is Dictionary): return
	var k = L.get("kind")
	if k == "life":
		play("dice")
		play_later("found" if SHRules.t(L.life.get("found")) else "failure", 0.5)
		return
	if k != null:
		play("dice")
		play_later("coins" if SHRules.t(L.get("good")) or k == "harvest" else "failure", 0.5)
		return
	play("explore", 0.7)
	if int(L.get("rem", 0)): play_later("dice", 0.15)
	play_later("success" if SHRules.t(L.get("ok")) else "failure", 0.6)
	var lf = L.get("life")
	if lf is Dictionary and SHRules.t(lf.get("found")): play_later("found", 1.3)

func _on_changed() -> void:
	var G = Game.G
	if G == null: return
	# a new year, or a new phase
	if _last_year != -1 and int(G.y) != _last_year: play("year")
	_last_year = int(G.y)
	# an open combat question
	var a = G.ask[0] if G.ask.size() else null
	if a != null and not is_same(a, _last_ask) and a.k in ["battle", "pbattle", "search", "pirate", "intercept"]: play("alarm", 0.8)
	_last_ask = a
	# new lines in the log
	var fresh := []
	for e in G.log:
		if is_same(e, _last_log): break
		fresh.append(e)
		if fresh.size() > 30: break
	var first := _last_log == null
	_last_log = G.log[0] if G.log.size() else null
	if first: return
	for pair in LOG_SOUNDS:
		for e in fresh:
			if e.get("c") == "bot": continue
			var txt: String = e.t
			for w in pair[1]:
				if txt.contains(w):
					play(pair[0])
					return
