extends Control

const TILE_SIZE := 98
const VIEW_COLS := 5
const VIEW_ROWS := 5

@onready var floor_label: Label = $ContentMargin/VBoxContainer/HeaderRow/TitleBlock/FloorLabel
@onready var summary_label: Label = $ContentMargin/VBoxContainer/HeaderRow/TitleBlock/SummaryLabel
@onready var hp_label: Label = $ContentMargin/VBoxContainer/HeaderRow/StatBlock/HpLabel
@onready var gold_label: Label = $ContentMargin/VBoxContainer/HeaderRow/StatBlock/GoldLabel
@onready var map_grid: GridContainer = $ContentMargin/VBoxContainer/MapCard/MapContent/MapGrid
@onready var page_label: Label = $ContentMargin/VBoxContainer/MapCard/MapContent/PageControls/PageLabel
@onready var page_up_btn: Button = $ContentMargin/VBoxContainer/MapCard/MapContent/PageControls/PageUpButton
@onready var page_left_btn: Button = $ContentMargin/VBoxContainer/MapCard/MapContent/PageControls/PageLeftButton
@onready var page_right_btn: Button = $ContentMargin/VBoxContainer/MapCard/MapContent/PageControls/PageRightButton
@onready var page_down_btn: Button = $ContentMargin/VBoxContainer/MapCard/MapContent/PageControls/PageDownButton
@onready var status_label: Label = $ContentMargin/VBoxContainer/StatusLabel
@onready var equipment_label: Label = $ContentMargin/VBoxContainer/EquipmentLabel
@onready var back_btn: Button = $ContentMargin/VBoxContainer/FooterRow/BackButton

var _tile_buttons: Array[Button] = []
var _page_row: int = 0
var _page_col: int = 0


func _ready() -> void:
	if DungeonState.status == DungeonState.CrawlStatus.INACTIVE:
		DungeonState.start_new_run()
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	_connect_page_controls()
	_build_grid()
	_snap_page_to_player()
	_refresh_view("Explore the floor. Clear every enemy before taking the stairs.")


func _build_grid() -> void:
	for child in map_grid.get_children():
		child.queue_free()
	_tile_buttons.clear()

	map_grid.columns = VIEW_COLS
	for index in VIEW_COLS * VIEW_ROWS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		button.toggle_mode = false
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tile_pressed.bind(index))
		map_grid.add_child(button)
		_tile_buttons.append(button)


func _connect_page_controls() -> void:
	_connect_page_button(page_up_btn, _on_page_up_pressed)
	_connect_page_button(page_left_btn, _on_page_left_pressed)
	_connect_page_button(page_right_btn, _on_page_right_pressed)
	_connect_page_button(page_down_btn, _on_page_down_pressed)


func _connect_page_button(button: Button, callback: Callable) -> void:
	if button and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _refresh_view(message: String = "") -> void:
	floor_label.text = "Dungeon Floor %d" % DungeonState.floor_index
	summary_label.text = "%dx%d floor. %d enemies remain before the stairs unlock." % [
		DungeonState.map_width,
		DungeonState.map_height,
		DungeonState.get_remaining_enemy_count()
	]
	hp_label.text = "HP %d / %d" % [DungeonState.player_hp, DungeonState.max_hp]
	gold_label.text = "Gold %d" % DungeonState.gold
	status_label.text = message

	var equipment_lines: Array[String] = DungeonState.get_equipment_descriptions()
	if equipment_lines.is_empty():
		equipment_label.text = "Equipment: none"
	else:
		equipment_label.text = "Equipment: %s" % " | ".join(equipment_lines)

	_refresh_page_controls()
	for index in _tile_buttons.size():
		_refresh_tile(index)


func _refresh_page_controls() -> void:
	var page_x: int = int(_page_col / VIEW_COLS) + 1
	var page_y: int = int(_page_row / VIEW_ROWS) + 1
	page_label.text = "View %d/%d  |  %d/%d" % [
		page_x,
		DungeonState.get_page_count_x(VIEW_COLS),
		page_y,
		DungeonState.get_page_count_y(VIEW_ROWS),
	]
	page_left_btn.disabled = _page_col <= 0
	page_right_btn.disabled = _page_col + VIEW_COLS >= DungeonState.map_width
	page_up_btn.disabled = _page_row <= 0
	page_down_btn.disabled = _page_row + VIEW_ROWS >= DungeonState.map_height


func _refresh_tile(visible_index: int) -> void:
	var button: Button = _tile_buttons[visible_index]
	var global_index := _get_visible_global_index(visible_index)
	if global_index == -1:
		button.text = ""
		button.tooltip_text = ""
		button.disabled = true
		button.visible = false
		return

	button.visible = true
	var discovered := DungeonState.discovered[global_index]
	var tile: Dictionary = DungeonState.get_tile(global_index)
	var tile_type := String(tile.get("type", "empty"))
	var is_player := global_index == DungeonState.player_index
	var can_move := DungeonState.can_move_to(global_index)

	button.disabled = not can_move
	if not discovered:
		button.text = ""
		button.tooltip_text = "Unexplored"
		button.modulate = Color(0.28, 0.3, 0.34, 0.85)
		return

	if is_player:
		button.text = "@"
		button.tooltip_text = "You"
		button.modulate = Color(0.96, 0.82, 0.56, 1.0)
		return

	match tile_type:
		"enemy":
			button.text = "E"
			button.tooltip_text = "Enemy room"
			button.modulate = Color(0.88, 0.46, 0.36, 1.0)
		"treasure":
			button.text = "$"
			button.tooltip_text = "Treasure"
			button.modulate = Color(0.96, 0.82, 0.52, 1.0)
		"stairs":
			button.text = ">"
			button.tooltip_text = "Stairs"
			button.modulate = Color(0.66, 0.84, 0.94, 1.0) if DungeonState.get_remaining_enemy_count() == 0 else Color(0.4, 0.48, 0.58, 0.9)
		"cleared":
			button.text = "."
			button.tooltip_text = "Cleared room"
			button.modulate = Color(0.58, 0.68, 0.74, 0.9)
		"start":
			button.text = "S"
			button.tooltip_text = "Start"
			button.modulate = Color(0.6, 0.76, 0.96, 0.9)
		_:
			button.text = "."
			button.tooltip_text = "Passage"
			button.modulate = Color(0.76, 0.8, 0.86, 0.85)


func _get_visible_global_index(visible_index: int) -> int:
	var local_row: int = int(visible_index / VIEW_COLS)
	var local_col: int = visible_index % VIEW_COLS
	var global_row: int = _page_row + local_row
	var global_col: int = _page_col + local_col
	if global_row >= DungeonState.map_height or global_col >= DungeonState.map_width:
		return -1
	return global_row * DungeonState.map_width + global_col


func _snap_page_to_player() -> void:
	var player_row: int = int(DungeonState.player_index / DungeonState.map_width)
	var player_col: int = DungeonState.player_index % DungeonState.map_width
	_page_row = int(player_row / VIEW_ROWS) * VIEW_ROWS
	_page_col = int(player_col / VIEW_COLS) * VIEW_COLS


func _on_tile_pressed(visible_index: int) -> void:
	var global_index := _get_visible_global_index(visible_index)
	if global_index == -1:
		return

	var result := DungeonState.move_to(global_index)
	match result:
		"enemy":
			get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_battle.tscn")
		"treasure":
			get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_reward.tscn")
		"stairs":
			_snap_page_to_player()
			_refresh_view("You descend deeper into the dungeon.")
		"stairs_locked":
			_refresh_view("The stairs stay sealed until every enemy on this floor is cleared.")
		"empty":
			_snap_page_to_player()
			_refresh_view("You advance into another chamber.")
		_:
			_refresh_view("You can only move one room at a time.")

	if result in ["empty", "stairs", "stairs_locked", "blocked"]:
		_refresh_view(status_label.text)


func _on_page_up_pressed() -> void:
	_page_row = maxi(_page_row - VIEW_ROWS, 0)
	_refresh_view(status_label.text)


func _on_page_left_pressed() -> void:
	_page_col = maxi(_page_col - VIEW_COLS, 0)
	_refresh_view(status_label.text)


func _on_page_right_pressed() -> void:
	_page_col = mini(_page_col + VIEW_COLS, maxi(DungeonState.map_width - VIEW_COLS, 0))
	_refresh_view(status_label.text)


func _on_page_down_pressed() -> void:
	_page_row = mini(_page_row + VIEW_ROWS, maxi(DungeonState.map_height - VIEW_ROWS, 0))
	_refresh_view(status_label.text)


func _on_back_pressed() -> void:
	DungeonState.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
