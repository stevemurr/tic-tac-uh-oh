extends Control

@onready var summary_label: Label = $ContentMargin/VBoxContainer/SummaryLabel
@onready var route_label: Label = $ContentMargin/VBoxContainer/RouteLabel
@onready var floors_container: VBoxContainer = $ContentMargin/VBoxContainer/FloorsContainer
@onready var back_btn: Button = $ContentMargin/VBoxContainer/BackButton


func _ready() -> void:
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if RunState.run_status == RunState.RunStatus.INACTIVE:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	_rebuild_map()


func _rebuild_map() -> void:
	summary_label.text = "%s  |  Resolve %d/%d  |  Sigils %d  |  Runes %d" % [
		RunState.character.display_name if RunState.character else "Unknown",
		RunState.resolve,
		RunState.max_resolve,
		RunState.sigils,
		RunState.equipped_runes.size(),
	]
	route_label.text = "Climb the Outer Wall. Blue nodes are open, dim nodes are still sealed."
	route_label.text = "Climb the Outer Wall. Bright nodes are open, dim nodes are still sealed."

	for child in floors_container.get_children():
		child.queue_free()

	var floors: Dictionary = {}
	for node in RunState.map_nodes:
		if not floors.has(node.floor):
			floors[node.floor] = []
		floors[node.floor].append(node)

	var floor_keys: Array[int] = []
	for key in floors.keys():
		floor_keys.append(int(key))
	floor_keys.sort()

	for floor_index in floor_keys:
		var header := Label.new()
		header.text = "Floor %d" % (floor_index + 1)
		header.add_theme_color_override("font_color", NeonColors.ACCENT)
		header.add_theme_font_size_override("font_size", 15)
		floors_container.add_child(header)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		floors_container.add_child(row)

		var nodes: Array = floors[floor_index]
		nodes.sort_custom(func(a, b) -> bool: return a.lane < b.lane)
		for node in nodes:
			row.add_child(_make_node_button(node))


func _make_node_button(node) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "%s\n%s" % [_node_badge(node), node.title]
	button.tooltip_text = _node_tooltip(node)
	button.disabled = not node.available or node.visited
	if node.visited:
		button.modulate = Color(0.74, 0.84, 0.96, 0.55)
	elif node.available:
		button.modulate = Color(1, 1, 1, 1)
	else:
		button.modulate = Color(0.72, 0.76, 0.84, 0.45)
	if not button.disabled:
		button.pressed.connect(_on_node_pressed.bind(node.node_id))
	return button


func _node_badge(node) -> String:
	match node.node_type:
		"duel":
			return "DUEL"
		"elite":
			return "ELITE"
		"forge":
			return "FORGE"
		"sanctum":
			return "SANCTUM"
		"boss":
			return "BOSS"
	return node.node_type.to_upper()


func _node_tooltip(node) -> String:
	if node.visited:
		return "Cleared"
	if not node.available:
		return "Locked"
	return "Enter %s" % node.title


func _on_node_pressed(node_id: String) -> void:
	if not RunState.select_node(node_id):
		return

	match RunState.run_status:
		RunState.RunStatus.IN_BATTLE:
			get_tree().change_scene_to_file("res://scenes/game/game.tscn")
		RunState.RunStatus.REWARD:
			get_tree().change_scene_to_file("res://scenes/run/reward_choice.tscn")


func _on_back_pressed() -> void:
	RunState.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
