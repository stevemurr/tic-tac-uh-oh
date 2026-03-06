class_name NetworkManagerClass
extends Node

enum NetState {
	OFFLINE,
	CONNECTING,
	IN_LOBBY,
	ESTABLISHING,
	CONNECTED,
	DISCONNECTED,
}

signal state_changed(new_state: NetState)
signal room_created(code: String)
signal room_joined(code: String)
signal peer_connected()
signal peer_disconnected()
signal game_message_received(msg: Dictionary)
signal error_received(message: String)
signal ready_state_changed(host_ready: bool, client_ready: bool)

var net_state: NetState = NetState.OFFLINE
var room_code: String = ""
var is_host: bool = false
var peer_id: String = ""  # "host" or "client"

var host_ready: bool = false
var client_ready: bool = false

var _ws: WebSocketPeer
var _rtc_peer: WebRTCPeerConnection
var _data_channel: WebRTCDataChannel
var _loopback: bool = false
var _seq: int = 0

# ICE candidates queued before remote description is set
var _pending_ice: Array[Dictionary] = []
var _remote_description_set: bool = false


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _ws:
		_ws.poll()
		var ws_state := _ws.get_ready_state()

		if ws_state == WebSocketPeer.STATE_OPEN:
			while _ws.get_available_packet_count() > 0:
				var packet := _ws.get_packet()
				var text := packet.get_string_from_utf8()
				_on_ws_message(text)
		elif ws_state == WebSocketPeer.STATE_CLOSED:
			if net_state == NetState.CONNECTING:
				_set_state(NetState.OFFLINE)
				error_received.emit("Could not connect to signaling server")
			_ws = null

	if _rtc_peer:
		_rtc_peer.poll()

	if _data_channel:
		_check_data_channel()
		if _data_channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			while _data_channel.get_available_packet_count() > 0:
				var packet := _data_channel.get_packet()
				var text := packet.get_string_from_utf8()
				_on_data_channel_message(text)


# --- Public API ---

func create_room() -> void:
	if _loopback:
		room_code = "TEST"
		is_host = true
		peer_id = "host"
		_set_state(NetState.IN_LOBBY)
		room_created.emit(room_code)
		return

	is_host = true
	_connect_to_signaling()


func join_room(code: String) -> void:
	if _loopback:
		room_code = code
		is_host = false
		peer_id = "client"
		_set_state(NetState.IN_LOBBY)
		room_joined.emit(code)
		# Simulate peer connection
		peer_connected.emit()
		return

	room_code = code.to_upper()
	is_host = false
	_connect_to_signaling()


func send_game_message(msg: Dictionary) -> void:
	if is_host:
		_seq += 1
		msg["seq"] = _seq

	if _loopback:
		# In loopback mode, immediately deliver to self
		call_deferred("_emit_game_message", msg)
		return

	if _data_channel and _data_channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		var json := JSON.stringify(msg)
		_data_channel.put_packet(json.to_utf8_buffer())


func set_ready(ready: bool) -> void:
	if is_host:
		host_ready = ready
	else:
		client_ready = ready

	if _loopback:
		ready_state_changed.emit(host_ready, client_ready)
		return

	send_game_message({"type": "ready", "ready": ready})


func leave() -> void:
	host_ready = false
	client_ready = false
	_seq = 0
	room_code = ""

	if _ws:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws_send({"type": "leave"})
		_ws = null

	if _data_channel:
		_data_channel.close()
		_data_channel = null

	if _rtc_peer:
		_rtc_peer.close()
		_rtc_peer = null

	_pending_ice.clear()
	_remote_description_set = false
	_dc_was_open = false
	_set_state(NetState.OFFLINE)
	set_process(false)


func enable_loopback() -> void:
	_loopback = true


func disable_loopback() -> void:
	_loopback = false


func is_online_mode() -> bool:
	return GameState.game_mode == GameState.GameMode.ONLINE


# --- Internal ---

func _emit_game_message(msg: Dictionary) -> void:
	game_message_received.emit(msg)


func _set_state(new_state: NetState) -> void:
	if net_state == new_state:
		return
	net_state = new_state
	state_changed.emit(new_state)


func _connect_to_signaling() -> void:
	_set_state(NetState.CONNECTING)
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(GameState.signaling_url)
	if err != OK:
		error_received.emit("Failed to connect to signaling server")
		_set_state(NetState.OFFLINE)
		return
	set_process(true)
	# Wait for connection, then send create/join
	_wait_for_ws_open()


func _wait_for_ws_open() -> void:
	# Polled in _process; once open, we send the room command
	await get_tree().create_timer(0.1).timeout
	if _ws == null:
		return
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if is_host:
			_ws_send({"type": "create_room"})
		else:
			_ws_send({"type": "join_room", "room_code": room_code})
	elif _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_wait_for_ws_open()


func _ws_send(msg: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))


func _on_ws_message(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var msg: Dictionary = json.data
	var type: String = msg.get("type", "")

	match type:
		"room_created":
			room_code = msg.get("room_code", "")
			peer_id = msg.get("peer_id", "host")
			_set_state(NetState.IN_LOBBY)
			room_created.emit(room_code)

		"room_joined":
			peer_id = msg.get("peer_id", "client")
			_set_state(NetState.IN_LOBBY)
			room_joined.emit(room_code)

		"peer_joined":
			# Host: client joined, start WebRTC
			_setup_webrtc(true)

		"signal":
			_on_signaling_data(msg.get("data", {}))

		"peer_disconnected":
			_on_peer_disconnected()

		"error":
			error_received.emit(msg.get("message", "Unknown error"))


func _on_peer_disconnected() -> void:
	if _data_channel:
		_data_channel.close()
		_data_channel = null
	if _rtc_peer:
		_rtc_peer.close()
		_rtc_peer = null
	_pending_ice.clear()
	_remote_description_set = false
	host_ready = false
	client_ready = false
	_set_state(NetState.DISCONNECTED)
	peer_disconnected.emit()


# --- WebRTC ---

func _setup_webrtc(create_offer: bool) -> void:
	_set_state(NetState.ESTABLISHING)
	_remote_description_set = false
	_pending_ice.clear()

	_rtc_peer = WebRTCPeerConnection.new()
	var config := {
		"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]
	}
	_rtc_peer.initialize(config)

	_rtc_peer.session_description_created.connect(_on_session_description)
	_rtc_peer.ice_candidate_created.connect(_on_ice_candidate)

	# Create negotiated data channel (both sides must create with same id)
	var channel_config := {
		"negotiated": true,
		"id": 0,
	}
	_data_channel = _rtc_peer.create_data_channel("game", channel_config)
	_data_channel.write_mode = WebRTCDataChannel.WRITE_MODE_TEXT

	if create_offer:
		_rtc_peer.create_offer()


func _on_session_description(type: String, sdp: String) -> void:
	_rtc_peer.set_local_description(type, sdp)
	_ws_send({
		"type": "signal",
		"data": {"type": type, "sdp": sdp}
	})


func _on_ice_candidate(media: String, index: int, candidate_name: String) -> void:
	_ws_send({
		"type": "signal",
		"data": {
			"type": "ice",
			"media": media,
			"index": index,
			"candidate": candidate_name,
		}
	})


func _on_signaling_data(data: Variant) -> void:
	if data is not Dictionary:
		return
	var msg: Dictionary = data
	var type: String = msg.get("type", "")

	match type:
		"offer":
			# Client receives offer — set up WebRTC and set remote description
			# Setting remote offer auto-triggers session_description_created with an answer
			if not is_host:
				_setup_webrtc(false)
			_rtc_peer.set_remote_description("offer", msg.get("sdp", ""))
			_remote_description_set = true
			_flush_pending_ice()

		"answer":
			# Host receives answer
			_rtc_peer.set_remote_description("answer", msg.get("sdp", ""))
			_remote_description_set = true
			_flush_pending_ice()

		"ice":
			var ice := {
				"media": msg.get("media", ""),
				"index": msg.get("index", 0),
				"candidate": msg.get("candidate", ""),
			}
			if _remote_description_set and _rtc_peer:
				_rtc_peer.add_ice_candidate(ice["media"], ice["index"], ice["candidate"])
			else:
				_pending_ice.append(ice)


func _flush_pending_ice() -> void:
	for ice in _pending_ice:
		if _rtc_peer:
			_rtc_peer.add_ice_candidate(ice["media"], ice["index"], ice["candidate"])
	_pending_ice.clear()


func _on_data_channel_message(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var msg: Dictionary = json.data

	# Handle ready messages internally
	var type: String = msg.get("type", "")
	if type == "ready":
		if is_host:
			client_ready = msg.get("ready", false)
		else:
			host_ready = msg.get("ready", false)
		ready_state_changed.emit(host_ready, client_ready)
		return

	game_message_received.emit(msg)


# Check data channel state and emit peer_connected when open
var _dc_was_open: bool = false

func _check_data_channel() -> void:
	if _data_channel and not _dc_was_open:
		if _data_channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			_dc_was_open = true
			_set_state(NetState.CONNECTED)
			peer_connected.emit()
			# Close signaling WS - no longer needed
			if _ws:
				_ws.close()
				_ws = null
