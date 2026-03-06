extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var room_code_display: Label = $VBoxContainer/RoomCodeDisplay
@onready var code_input: LineEdit = $VBoxContainer/CodeInputContainer/CodeInput
@onready var join_btn: Button = $VBoxContainer/CodeInputContainer/JoinButton
@onready var create_btn: Button = $VBoxContainer/CreateButton
@onready var settings_container: VBoxContainer = $VBoxContainer/SettingsContainer
@onready var ready_container: HBoxContainer = $VBoxContainer/ReadyContainer
@onready var ready_btn: Button = $VBoxContainer/ReadyContainer/ReadyButton
@onready var ready_status: Label = $VBoxContainer/ReadyContainer/ReadyStatus
@onready var back_btn: Button = $VBoxContainer/BackButton
@onready var size3_btn: Button = $VBoxContainer/SettingsContainer/BoardSizeButtons/Size3
@onready var size5_btn: Button = $VBoxContainer/SettingsContainer/BoardSizeButtons/Size5
@onready var size7_btn: Button = $VBoxContainer/SettingsContainer/BoardSizeButtons/Size7
@onready var complication_toggle: CheckButton = $VBoxContainer/SettingsContainer/ComplicationToggle

var _local_ready: bool = false


func _ready() -> void:
	create_btn.pressed.connect(_on_create_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	code_input.text_submitted.connect(func(_t: String): _on_join_pressed())

	# Board size buttons
	var group := ButtonGroup.new()
	for btn_info in [[size3_btn, 3], [size5_btn, 5], [size7_btn, 7]]:
		var btn: Button = btn_info[0]
		var size_val: int = btn_info[1]
		if btn:
			btn.button_group = group
			btn.pressed.connect(_on_board_size_selected.bind(size_val))

	if complication_toggle:
		complication_toggle.toggled.connect(_on_complication_toggled)

	# Network signals
	NetworkManager.state_changed.connect(_on_net_state_changed)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.error_received.connect(_on_error)
	NetworkManager.ready_state_changed.connect(_on_ready_state_changed)
	NetworkManager.game_message_received.connect(_on_game_message)

	_update_ui_for_state()


func _exit_tree() -> void:
	# Disconnect signals to avoid errors if scene changes
	if NetworkManager.state_changed.is_connected(_on_net_state_changed):
		NetworkManager.state_changed.disconnect(_on_net_state_changed)
	if NetworkManager.room_created.is_connected(_on_room_created):
		NetworkManager.room_created.disconnect(_on_room_created)
	if NetworkManager.room_joined.is_connected(_on_room_joined):
		NetworkManager.room_joined.disconnect(_on_room_joined)
	if NetworkManager.peer_connected.is_connected(_on_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_peer_disconnected)
	if NetworkManager.error_received.is_connected(_on_error):
		NetworkManager.error_received.disconnect(_on_error)
	if NetworkManager.ready_state_changed.is_connected(_on_ready_state_changed):
		NetworkManager.ready_state_changed.disconnect(_on_ready_state_changed)
	if NetworkManager.game_message_received.is_connected(_on_game_message):
		NetworkManager.game_message_received.disconnect(_on_game_message)


func _on_create_pressed() -> void:
	GameState.game_mode = GameState.GameMode.ONLINE
	GameState.local_player_id = 0
	NetworkManager.create_room()
	status_label.text = "Creating room..."
	create_btn.disabled = true
	join_btn.disabled = true


func _on_join_pressed() -> void:
	var code := code_input.text.strip_edges().to_upper()
	if code.length() != 4:
		status_label.text = "Enter a 4-character room code"
		return

	GameState.game_mode = GameState.GameMode.ONLINE
	GameState.local_player_id = 1
	NetworkManager.join_room(code)
	status_label.text = "Joining room %s..." % code
	create_btn.disabled = true
	join_btn.disabled = true


func _on_ready_pressed() -> void:
	_local_ready = not _local_ready
	NetworkManager.set_ready(_local_ready)
	ready_btn.text = "NOT READY" if _local_ready else "READY"
	_update_ready_display()

	# If host and both ready, start the game
	if NetworkManager.is_host and NetworkManager.host_ready and NetworkManager.client_ready:
		_start_game()


func _on_back_pressed() -> void:
	NetworkManager.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_board_size_selected(size_val: int) -> void:
	GameState.start_board_size = size_val
	# Sync settings to client if host
	if NetworkManager.is_host:
		NetworkManager.send_game_message({
			"type": "settings_sync",
			"board_size": GameState.start_board_size,
			"start_with_complication": GameState.start_with_complication,
		})


func _on_complication_toggled(enabled: bool) -> void:
	GameState.start_with_complication = enabled
	if NetworkManager.is_host:
		NetworkManager.send_game_message({
			"type": "settings_sync",
			"board_size": GameState.start_board_size,
			"start_with_complication": GameState.start_with_complication,
		})


# --- Network callbacks ---

func _on_net_state_changed(_new_state: NetworkManager.NetState) -> void:
	_update_ui_for_state()


func _on_room_created(code: String) -> void:
	room_code_display.text = code
	status_label.text = "Room created! Share this code:"
	_show_lobby_ui()


func _on_room_joined(code: String) -> void:
	room_code_display.text = code
	status_label.text = "Joined room %s" % code
	_show_lobby_ui()


func _on_peer_connected() -> void:
	status_label.text = "Opponent connected!"
	ready_container.visible = true
	_update_ready_display()


func _on_peer_disconnected() -> void:
	status_label.text = "Opponent disconnected"
	ready_container.visible = false
	_local_ready = false
	NetworkManager.host_ready = false
	NetworkManager.client_ready = false


func _on_error(message: String) -> void:
	status_label.text = "Error: %s" % message
	create_btn.disabled = false
	join_btn.disabled = false


func _on_ready_state_changed(_host_ready: bool, _client_ready: bool) -> void:
	_update_ready_display()

	# If host and both ready, start the game
	if NetworkManager.is_host and NetworkManager.host_ready and NetworkManager.client_ready:
		_start_game()


func _on_game_message(msg: Dictionary) -> void:
	var type: String = msg.get("type", "")

	match type:
		"settings_sync":
			# Client receives host settings
			if not NetworkManager.is_host:
				GameState.start_board_size = int(msg.get("board_size", 3))
				GameState.start_with_complication = bool(msg.get("start_with_complication", false))
				status_label.text = "Host settings: %dx%d board%s" % [
					GameState.start_board_size,
					GameState.start_board_size,
					" + complication" if GameState.start_with_complication else "",
				]

		"game_start":
			# Client receives game start — set up GameState before transitioning
			if not NetworkManager.is_host:
				GameState.local_player_id = int(msg.get("you_are", 1))
				GameState.start_board_size = int(msg.get("board_size", 3))
				GameState.start_with_complication = bool(msg.get("start_with_complication", false))
				GameState.reset_session()
				var comp_id: String = msg.get("complication_id", "")
				if comp_id != "":
					var comp = ComplicationRegistry.create_fresh(comp_id)
					if comp:
						GameState.add_complication(comp)
				_transition_to_game()


# --- UI helpers ---

func _show_lobby_ui() -> void:
	create_btn.visible = false
	code_input.get_parent().visible = false

	if NetworkManager.is_host:
		settings_container.visible = true
		# Show ready container once peer connects
		if NetworkManager.net_state == NetworkManager.NetState.CONNECTED:
			ready_container.visible = true
	else:
		settings_container.visible = false
		# Client shows ready once connected
		if NetworkManager.net_state == NetworkManager.NetState.CONNECTED:
			ready_container.visible = true


func _update_ui_for_state() -> void:
	match NetworkManager.net_state:
		NetworkManager.NetState.OFFLINE:
			create_btn.disabled = false
			join_btn.disabled = false
			create_btn.visible = true
			code_input.get_parent().visible = true
			settings_container.visible = false
			ready_container.visible = false
			room_code_display.text = ""
		NetworkManager.NetState.CONNECTING:
			status_label.text = "Connecting..."
		NetworkManager.NetState.ESTABLISHING:
			status_label.text = "Establishing P2P connection..."
		NetworkManager.NetState.CONNECTED:
			if NetworkManager.is_host:
				status_label.text = "Opponent connected! Ready up to start."
			else:
				status_label.text = "Connected! Waiting for host settings."
			ready_container.visible = true
		NetworkManager.NetState.DISCONNECTED:
			status_label.text = "Disconnected"
			create_btn.disabled = false
			join_btn.disabled = false


func _update_ready_display() -> void:
	if not ready_status:
		return

	var host_mark := "✓" if NetworkManager.host_ready else "✗"
	var client_mark := "✓" if NetworkManager.client_ready else "✗"

	if NetworkManager.is_host:
		ready_status.text = "You: %s | Opponent: %s" % [host_mark, client_mark]
	else:
		ready_status.text = "You: %s | Host: %s" % [client_mark, host_mark]


func _start_game() -> void:
	# Host starts the game
	GameState.reset_session()
	if GameState.start_with_complication:
		var comp = ComplicationRegistry.pick_random([])
		if comp:
			GameState.add_complication(comp)

	# Send game_start to client
	var comp_id := ""
	if GameState.active_complications.size() > 0:
		comp_id = GameState.active_complications[0].complication_id

	NetworkManager.send_game_message({
		"type": "game_start",
		"board_size": GameState.start_board_size,
		"start_with_complication": GameState.start_with_complication,
		"complication_id": comp_id,
		"you_are": 1,
	})

	_transition_to_game()


func _transition_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
