extends Node
## Autoload "Net": Mehrspieler im WLAN ohne Server.
##
## Ein Gerät ist Gastgeber und rechnet das Spiel (KI, Bisse, Geräusche, Upgrades).
## Die anderen verbinden sich direkt per ENet, schicken nur ihre Eingaben und
## bekommen ~30-mal pro Sekunde den Spielzustand zurück. Gastgeber werden über
## einen UDP-Rundruf im lokalen Netz gefunden; alternativ per IP-Adresse.
##
## Alle RPCs laufen über diesen Knoten (er existiert immer) und werden an die
## aktuelle Spielszene weitergereicht. Die match_id verwirft Nachzügler-Pakete
## einer alten Runde.

signal lobby_changed
signal hosts_changed
signal join_ok
signal join_failed(reason: String)

enum Mode { OFF, HOST, CLIENT }

const PORT := 24642
const DISC_PORT := 24643
const PROTO := 2
const MAX_PLAYERS := 6
const MAGIC := "ZIA"
const JOIN_TIMEOUT := 6.0

var mode: int = Mode.OFF
var my_name := "Spieler"
var players := {}            # Peer-ID -> Name (Gastgeber hat die ID 1)
var looks := {}              # Gastgeber: Peer-ID -> [Farbe, Frisur, Haarfarbe, Hut]
var player_zombie := true    # ein zufälliger Spieler startet als Zombie (sonst der Computer)
var found_hosts := {}        # IP -> {name, count, t}
var match_id := 0
var in_game := false
var game = null              # aktuelle Spielszene (setzt game.gd)
var last_message := ""       # Hinweis fürs Menü nach einem Verbindungsende
var ready_peers := {}        # Gastgeber: Peers, deren Spielszene geladen ist

var _udp_send: PacketPeerUDP
var _udp_listen: PacketPeerUDP
var _bc_t := 0.0
var _joined := false
var _join_t := 0.0
var _host_ip := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func active() -> bool:
	return mode != Mode.OFF

func is_host() -> bool:
	return mode == Mode.HOST

func is_client() -> bool:
	return mode == Mode.CLIENT

func my_id() -> int:
	return multiplayer.get_unique_id() if active() else 1


# ------------------------------------------------------------------ Verbindung

## Eröffnet ein Spiel. Liefert "" oder eine Fehlermeldung.
func host_game() -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_PLAYERS - 1) != OK:
		return "Das Spiel konnte nicht eröffnet werden (Port %d belegt?)." % PORT
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	players = {1: _clean_name(my_name)}
	looks = {1: GameState.look_array()}
	in_game = false
	_udp_send = PacketPeerUDP.new()
	_udp_send.set_broadcast_enabled(true)
	_bc_t = 0.0
	lobby_changed.emit()
	return ""


## Verbindet sich mit einem Gastgeber. Das Ergebnis kommt als join_ok / join_failed.
func join_game(ip: String) -> String:
	leave()
	ip = ip.strip_edges()
	if not ip.is_valid_ip_address():
		return "Das ist keine gültige Adresse."
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		return "Verbindung nicht möglich."
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	_joined = false
	_join_t = JOIN_TIMEOUT
	_host_ip = ip
	return ""


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFF
	players.clear()
	looks.clear()
	ready_peers.clear()
	in_game = false
	_joined = false
	_join_t = 0.0
	if _udp_send != null:
		_udp_send.close()
		_udp_send = null


func host_ip() -> String:
	return _host_ip


func _clean_name(n: String) -> String:
	n = n.strip_edges().replace("|", "").left(12)
	if n == "":
		n = "Spieler"
	var base := n
	var i := 2
	while players.values().has(n):
		n = "%s %d" % [base.left(10), i]
		i += 1
	return n


func _on_connected() -> void:
	_srv_hello.rpc_id(1, my_name, PROTO, GameState.look_array())


## Abgerissene Verbindungen (WLAN weg, App geschlossen) nach wenigen Sekunden erkennen.
func _on_peer_connected(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	# ein Client ist nur mit dem Gastgeber (ID 1) direkt verbunden
	if enet != null and (is_host() or id == 1):
		var pp := enet.get_peer(id)
		if pp != null:
			pp.set_timeout(0, 3000, 7000)


func _on_connection_failed() -> void:
	_fail("Kein Spiel unter dieser Adresse gefunden.")


func _fail(reason: String) -> void:
	leave()
	join_failed.emit(reason)


func _on_server_disconnected() -> void:
	var was_joined := _joined
	last_message = "Die Verbindung zum Gastgeber wurde beendet."
	leave()
	if not was_joined:
		join_failed.emit(last_message)
		last_message = ""
		return
	if game != null:
		game.net_closed()
	else:
		lobby_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	players.erase(id)
	looks.erase(id)
	ready_peers.erase(id)
	# erst senden, wenn alle gleichzeitigen Abmeldungen verarbeitet sind
	_send_lobby.call_deferred()
	lobby_changed.emit()
	if game != null:
		game.net_peer_left(id)


func _send_lobby() -> void:
	if not is_host():
		return
	for id in players:
		if id != 1:
			_cl_lobby.rpc_id(id, players)


@rpc("any_peer", "call_remote", "reliable")
func _srv_hello(pname: String, proto: int, look: Array = []) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	var why := ""
	if proto != PROTO:
		why = "Die Spielversionen passen nicht zusammen."
	elif in_game:
		why = "Dort läuft bereits eine Runde."
	elif players.size() >= MAX_PLAYERS:
		why = "Das Spiel ist voll."
	if why != "":
		_cl_reject.rpc_id(id, why)
		return
	players[id] = _clean_name(pname)
	var lk := [0, 0, 0, 0]
	for i in mini(4, look.size()):
		lk[i] = int(look[i])
	looks[id] = lk
	_send_lobby()
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _cl_reject(reason: String) -> void:
	_fail(reason)


@rpc("authority", "call_remote", "reliable")
func _cl_lobby(p: Dictionary) -> void:
	players = p
	if not _joined:
		_joined = true
		_join_t = 0.0
		join_ok.emit()
	lobby_changed.emit()


# ------------------------------------------------------------------ Rundenstart

## Gastgeber: startet eine (neue) Runde für alle.
func start_match() -> void:
	if not is_host():
		return
	in_game = true
	ready_peers.clear()
	multiplayer.multiplayer_peer.refuse_new_connections = true
	var mid := randi() % 1000000 + 1
	var s: int = int(GameState.cli.get("seed", 0))
	if s == 0:
		s = randi() % 1000000 + 1
	_cl_start.rpc(mid, s, GameState.level_index)
	_do_start(mid, s, GameState.level_index)


@rpc("authority", "call_remote", "reliable")
func _cl_start(mid: int, level_seed: int, level_index: int) -> void:
	_do_start(mid, level_seed, level_index)


func _do_start(mid: int, level_seed: int, level_index: int) -> void:
	match_id = mid
	in_game = true
	GameState.set_level(level_index)
	GameState.level["seed"] = level_seed
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func all_ready() -> bool:
	for id in players:
		if id != 1 and not ready_peers.has(id):
			return false
	return true


# --- Client -> Gastgeber

func send_ready() -> void:
	_srv_ready.rpc_id(1, match_id)

func send_input(mx: float, mz: float, flags: int) -> void:
	_srv_input.rpc_id(1, match_id, mx, mz, flags)

func send_action(kind: String, arg: Vector3) -> void:
	_srv_action.rpc_id(1, match_id, kind, arg)


@rpc("any_peer", "call_remote", "reliable")
func _srv_ready(mid: int) -> void:
	if not is_host() or mid != match_id:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	ready_peers[id] = true
	if game != null:
		game.net_peer_ready(id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_input(mid: int, mx: float, mz: float, flags: int) -> void:
	if is_host() and mid == match_id and game != null:
		game.net_input(multiplayer.get_remote_sender_id(), mx, mz, flags)


@rpc("any_peer", "call_remote", "reliable")
func _srv_action(mid: int, kind: String, arg: Vector3) -> void:
	if is_host() and mid == match_id and game != null:
		game.net_action(multiplayer.get_remote_sender_id(), kind, arg)


# --- Gastgeber -> Clients (nur an Peers, deren Szene geladen ist)

func send_begin(roster: Array, to_peer := 0) -> void:
	for id in ready_peers:
		if to_peer == 0 or id == to_peer:
			_cl_begin.rpc_id(id, match_id, roster)

func send_snapshot(data: Array) -> void:
	for id in ready_peers:
		_cl_snap.rpc_id(id, match_id, data)

## Zuverlässiges Ereignis (Ansage, Einbruch, Spielende ...), optional nur an einen Peer.
func send_event(kind: String, args: Array, to_peer := 0) -> void:
	if not is_host():
		return
	for id in ready_peers:
		if to_peer == 0 or id == to_peer:
			_cl_event.rpc_id(id, match_id, kind, args)

## Unzuverlässiger Effekt (Sound, Partikel) – darf verloren gehen.
func send_fx(kind: String, args: Array) -> void:
	if not is_host() or game == null:
		return
	for id in ready_peers:
		_cl_fx.rpc_id(id, match_id, kind, args)


@rpc("authority", "call_remote", "reliable")
func _cl_begin(mid: int, roster: Array) -> void:
	if mid == match_id and game != null:
		game.net_begin(roster)


@rpc("authority", "call_remote", "unreliable_ordered")
func _cl_snap(mid: int, data: Array) -> void:
	if mid == match_id and game != null:
		game.net_snapshot(data)


@rpc("authority", "call_remote", "reliable")
func _cl_event(mid: int, kind: String, args: Array) -> void:
	if mid == match_id and game != null:
		game.net_event(kind, args)


@rpc("authority", "call_remote", "unreliable")
func _cl_fx(mid: int, kind: String, args: Array) -> void:
	if mid == match_id and game != null:
		game.net_event(kind, args)


# ------------------------------------------------------------------ Suche im WLAN

func start_search() -> void:
	stop_search()
	found_hosts.clear()
	_udp_listen = PacketPeerUDP.new()
	# Broadcast-Empfang einschalten (holt unter Android auch die WLAN-Multicast-Sperre)
	_udp_listen.set_broadcast_enabled(true)
	if _udp_listen.bind(DISC_PORT) != OK:
		_udp_listen = null   # dann bleibt nur die Eingabe der Adresse


func stop_search() -> void:
	if _udp_listen != null:
		_udp_listen.close()
		_udp_listen = null


## Eigene IPv4-Adressen im lokalen Netz (zum Vorlesen/Eintippen).
func local_ips() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			if not out.has(a):
				out.append(a)
	out.sort_custom(func(x, y): return _ip_rank(x) < _ip_rank(y))
	return out


func _ip_rank(a: String) -> int:
	if a.begins_with("192.168."):
		return 0
	if a.begins_with("10.") or a.begins_with("172."):
		return 1
	return 2


func _broadcast_targets() -> Array[String]:
	var out: Array[String] = ["255.255.255.255"]
	for a in local_ips():
		var b := a.get_slice(".", 0) + "." + a.get_slice(".", 1) + "." + a.get_slice(".", 2) + ".255"
		if not out.has(b):
			out.append(b)
	if OS.has_feature("editor") or not OS.has_feature("mobile"):
		out.append("127.0.0.1")   # Test mit mehreren Instanzen auf einem Rechner
	return out


func _process(delta: float) -> void:
	# Beitritt: Zeitüberschreitung
	if is_client() and not _joined and _join_t > 0.0:
		_join_t -= delta
		if _join_t <= 0.0:
			_fail("Keine Antwort – ist das Spiel eröffnet und seid ihr im selben WLAN?")
	# Gastgeber: Rundruf, solange die Lobby offen ist
	if is_host() and not in_game and _udp_send != null:
		_bc_t -= delta
		if _bc_t <= 0.0:
			_bc_t = 1.0
			var msg := "%s|%d|%s|%d" % [MAGIC, PROTO, players.get(1, "?"), players.size()]
			for t in _broadcast_targets():
				_udp_send.set_dest_address(t, DISC_PORT)
				_udp_send.put_packet(msg.to_utf8_buffer())
	# Suche: Rundrufe einsammeln, alte Einträge vergessen
	if _udp_listen != null:
		var changed := false
		var now := Time.get_ticks_msec() / 1000.0
		while _udp_listen.get_available_packet_count() > 0:
			var txt := _udp_listen.get_packet().get_string_from_utf8()
			var ip := _udp_listen.get_packet_ip()
			var parts := txt.split("|")
			if parts.size() < 4 or parts[0] != MAGIC or int(parts[1]) != PROTO:
				continue
			if not found_hosts.has(ip) or found_hosts[ip].count != int(parts[3]) or found_hosts[ip].name != parts[2]:
				changed = true
			found_hosts[ip] = {"name": parts[2], "count": int(parts[3]), "t": now}
		for ip in found_hosts.keys():
			if now - found_hosts[ip].t > 3.5:
				found_hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()
