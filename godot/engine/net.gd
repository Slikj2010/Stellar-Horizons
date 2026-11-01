## Autoload "Net": online games. One player hosts, the others join with a room code. Everyone keeps a full copy of the world;
## the player whose turn it is (the "token holder") plays on it and the host relays each change to the rest.
## Players act one at a time in initiative order (see SHAI.advanceNet); bots take their turns as part of the previous player's step.
extends Node

signal lobby_changed  ## the list of players or the settings changed
signal status(text: String)  ## a line about the connection (shown in the lobby)
signal joined  ## connected to a host (clients)
signal failed(reason: String)
signal left(reason: String)  ## the connection ended; back to the title
signal game_started

const PORT := 24567
const VERSION := 1
const MAX_PLAYERS := 7

var in_lobby := false
var active := false  ## a game is running
var is_host := false
var me := ""  ## my faction
var holder := ""  ## the faction whose player is acting now
var seq := 0
var my_name := "Player"
var players := {}  ## peer id -> {name, f, variant}  (the host is id 1)
var settings := {"scenario": "std", "bots": []}  ## host's choices: scenario, bot factions [{f, variant}]
var public_ip := ""
var local_ip := ""
var upnp_msg := ""
var _last := PackedByteArray()  ## the latest world snapshot
var _dirty := false
var _clock := 0.0
var _upnp_thread: Thread

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Could not reach the host. Check the room code and that the host's port is open."))
	multiplayer.server_disconnected.connect(func(): leave("The host left the game."))

func my_turn() -> bool: return not active or holder == me
func name_of(f: String) -> String: return Game.D().FAC[f].n if Game.D().FAC.has(f) else f
func player_of(f: String) -> String:
	for id in players:
		if players[id].f == f: return String(players[id].name)
	return ""

# ---------------- room codes ----------------
static func encode_room(ip: String, port: int) -> String:
	var p := ip.split(".")
	if p.size() != 4: return ""
	var b := PackedByteArray()
	for x in p: b.append(int(x))
	b.append(port >> 8)
	b.append(port & 255)
	var al := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # 32 symbols, no I/O/0/1
	var v := 0
	for x in b: v = (v << 8) | x
	var out := ""
	for i in 10:
		out = al[v & 31] + out
		v >>= 5
	return out.substr(0, 5) + "-" + out.substr(5)

## returns {ip, port} or {} when the text is neither a room code nor an address
static func decode_room(txt: String) -> Dictionary:
	var s := txt.strip_edges().to_upper().replace(" ", "")
	if s.contains("."):
		var parts := s.split(":")
		var rx := RegEx.create_from_string("^\\d{1,3}(\\.\\d{1,3}){3}$")
		if rx.search(parts[0]) == null: return {}
		return {"ip": parts[0], "port": int(parts[1]) if parts.size() > 1 else PORT}
	s = s.replace("-", "")
	if s.length() != 10: return {}
	var al := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var v := 0
	for c in s:
		var i := al.find(c)
		if i < 0: return {}
		v = (v << 5) | i
	var b := []
	for i in 6:
		b.push_front(v & 255)
		v >>= 8
	return {"ip": "%d.%d.%d.%d" % [b[0], b[1], b[2], b[3]], "port": (b[4] << 8) | b[5]}

func room_code() -> String: return encode_room(public_ip, PORT) if public_ip != "" else ""
func lan_address() -> String: return "%s:%d" % [local_ip, PORT] if local_ip != "" else ""

# ---------------- hosting and joining ----------------
func host_game(pname: String) -> bool:
	leave("", true)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		failed.emit("Could not open port %d (is another copy of the game already hosting?)." % PORT)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	in_lobby = true
	my_name = pname
	players = {1: {"name": pname, "f": "", "variant": ""}}
	settings = {"scenario": "std", "bots": []}
	public_ip = ""
	local_ip = ""
	upnp_msg = "Opening the port on your router…"
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) < 32):
			local_ip = a
			break
	_find_public_ip()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_open)
	lobby_changed.emit()
	return true

func _find_public_ip() -> void:
	var req := HTTPRequest.new()
	req.timeout = 8
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var ip := body.get_string_from_utf8().strip_edges()
			if decode_room(ip).size(): public_ip = ip
		lobby_changed.emit())
	if req.request("https://api.ipify.org") != OK: req.queue_free()

func _upnp_open() -> void:
	var u := UPNP.new()
	var msg := ""
	var r := u.discover(2000, 2, "InternetGatewayDevice")
	if r != UPNP.UPNP_RESULT_SUCCESS or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
		msg = "Your router did not open the port automatically. Forward UDP port %d to this computer (or play on the same network)." % PORT
	else:
		var m := u.add_port_mapping(PORT, PORT, "Stellar Horizons", "UDP")
		msg = "Port %d opened on your router." % PORT if m == UPNP.UPNP_RESULT_SUCCESS else "Your router refused to open port %d. Forward UDP port %d to this computer." % [PORT, PORT]
	call_deferred("_upnp_done", msg)

func _upnp_done(msg: String) -> void:
	upnp_msg = msg
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	lobby_changed.emit()

func join_game(code: String, pname: String) -> void:
	leave("", true)
	var d := decode_room(code)
	if d.is_empty():
		failed.emit("That is not a room code or address.")
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(String(d.ip), int(d.port)) != OK:
		failed.emit("Could not start the connection.")
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	in_lobby = true
	my_name = pname
	players = {}
	status.emit("Connecting to %s…" % d.ip)

func _fail(reason: String) -> void:
	leave("", true)
	failed.emit(reason)

## leave the lobby or game. quiet = no signal (the caller is about to start something else)
func leave(reason := "", quiet := false) -> void:
	var was := in_lobby or active
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if is_host and public_ip != "":
		pass
	in_lobby = false
	active = false
	is_host = false
	me = ""
	holder = ""
	players = {}
	_dirty = false
	if was and not quiet: left.emit(reason)

# ---------------- lobby ----------------
func _on_connected() -> void:
	joined.emit()
	rpc_id(1, "c_hello", my_name, VERSION)

func _on_peer_connected(id: int) -> void:
	pass

func _on_peer_left(id: int) -> void:
	if not is_host: return
	if not players.has(id): return
	var p: Dictionary = players[id]
	players.erase(id)
	if not active:
		_push_lobby()
		return
	_replace_with_bot(String(p.f), String(p.name))

@rpc("any_peer", "reliable")
func c_hello(pname: String, ver: int) -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	if active:
		rpc_id(id, "s_reject", "That game has already started.")
		return
	if ver != VERSION:
		rpc_id(id, "s_reject", "Different game versions: everyone needs the same download.")
		return
	if players.size() >= MAX_PLAYERS:
		rpc_id(id, "s_reject", "The room is full.")
		return
	players[id] = {"name": pname.substr(0, 20), "f": "", "variant": ""}
	_push_lobby()

@rpc("authority", "reliable")
func s_reject(reason: String) -> void:
	_fail(reason)

@rpc("any_peer", "reliable")
func c_pick(f: String, variant: String) -> void:
	if not is_host or active: return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id): return
	pick_for(id, f, variant)

## choose (or clear, f = "") the faction of a player. Host and clients both end up here, on the host
func pick_for(id: int, f: String, variant: String) -> void:
	if f != "":
		if not Game.D().FAC.has(f): return
		for o in players:
			if o != id and players[o].f == f: return  # taken
		settings.bots = (settings.bots as Array).filter(func(b): return b.f != f)
	players[id].f = f
	players[id].variant = variant
	_push_lobby()

func choose(f: String, variant := "") -> void:
	if is_host: pick_for(1, f, variant)
	else: rpc_id(1, "c_pick", f, variant)

func set_bots(bots: Array, scenario: String) -> void:
	if not is_host: return
	var taken := players.values().map(func(p): return p.f)
	settings.bots = bots.filter(func(b): return not taken.has(b.f))
	settings.scenario = scenario
	_push_lobby()

func _push_lobby() -> void:
	if is_host:
		var st := {"players": players, "settings": settings}
		for id in players:
			if id != 1: rpc_id(id, "s_lobby", st)
	lobby_changed.emit()

@rpc("authority", "reliable")
func s_lobby(st: Dictionary) -> void:
	players = st.players
	settings = st.settings
	lobby_changed.emit()

func can_start() -> String:
	if not is_host: return "Only the host starts the game."
	for id in players:
		if players[id].f == "": return "%s has not picked a faction yet." % players[id].name
	return ""

## the host starts: build the world, hand every player their faction and the first snapshot
func start_game() -> String:
	var why := can_start()
	if why != "": return why
	var mef: String = players[1].f
	var others := []
	for id in players:
		if id == 1: continue
		others.append({"f": players[id].f, "variant": players[id].variant if players[id].variant != "" else null})
	var opts := {"scenario": settings.scenario, "variant": players[1].variant if players[1].variant != "" else null, "net": true, "humans": others}
	Game.new_net_campaign(mef, opts, settings.bots)
	me = mef
	active = true
	in_lobby = false
	holder = Game.AI.startRound(Game.G)
	seq = 1
	_last = Game.pack_world(holder, seq)
	for id in players:
		if id != 1: rpc_id(id, "s_start", _last, String(players[id].f))
	game_started.emit()
	Game.net_changed()
	return ""

@rpc("authority", "reliable")
func s_start(bytes: PackedByteArray, myf: String) -> void:
	me = myf
	active = true
	in_lobby = false
	_last = bytes
	var blob = Game.unpack_world(bytes)
	holder = String(blob.holder)
	seq = int(blob.seq)
	Game.net_apply(blob, me, true)
	game_started.emit()

# ---------------- play: snapshots ----------------
## called by Game when the world changed. The token holder's changes go out shortly after
func note_change() -> void:
	if active and holder == me: _dirty = true

func _process(dt: float) -> void:
	if not active: return
	_clock += dt
	if _dirty and _clock > .25:
		_dirty = false
		_clock = 0.0
		_send()

## the player's turn passes to `to` (a faction): send the new state now
func hand_over(to: String) -> void:
	holder = to
	_dirty = false
	_send()

func _send() -> void:
	seq += 1
	if OS.has_environment("SH_NETDEBUG"): print("[net] ", me, " sends seq ", seq, " holder ", holder, " y ", Game.G.y, " ", Game.G.phase)
	_last = Game.pack_world(holder, seq)
	if is_host:
		for id in players:
			if id != 1: rpc_id(id, "s_state", _last)
	else:
		rpc_id(1, "c_state", _last)

@rpc("any_peer", "reliable")
func c_state(bytes: PackedByteArray) -> void:
	if not is_host or not active: return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id) or players[id].f != holder: return  # only the player whose turn it is may change the world
	_last = bytes
	var blob = Game.unpack_world(bytes)
	holder = String(blob.holder)
	seq = int(blob.seq)
	for o in players:
		if o != 1 and o != id: rpc_id(o, "s_state", bytes)
	Game.net_apply(blob, me, false)

@rpc("authority", "reliable")
func s_state(bytes: PackedByteArray) -> void:
	_last = bytes
	var blob = Game.unpack_world(bytes)
	holder = String(blob.holder)
	seq = int(blob.seq)
	Game.net_apply(blob, me, false)

## throw away local changes made out of turn: show the last real state again
func restore() -> void:
	if not active or _last.is_empty(): return
	Game.net_apply(Game.unpack_world(_last), me, false)

# ---------------- a player drops out ----------------
func _replace_with_bot(f: String, pname: String) -> void:
	if f == "": return
	if not _last.is_empty(): Game.net_apply(Game.unpack_world(_last), me, false)
	var G = Game.G
	var world = G.world
	world.meta.humans.erase(f)
	var g = world.facs[f]
	g.bot = true
	g.ask.clear()
	Game.E.glog(G, "%s (%s) left the game; the faction is now run by a bot." % [pname, name_of(f)], "h")
	if holder == f:
		Game.AI.answerAsks(g)
		if not Game.AI.techStep(g): Game.AI.botPhase(g)
		holder = Game.AI.advanceNet(g)
	elif world.meta.humans.is_empty():
		holder = ""
	_send()
	Game.net_changed()
	status.emit("%s left; their faction is now a bot." % pname)
	Game.toast.emit("%s left the game; %s is now a bot." % [pname, name_of(f)])
