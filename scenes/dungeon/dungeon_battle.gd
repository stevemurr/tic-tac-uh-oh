extends Control

const PuzzleGeneratorScript = preload("res://scripts/dungeon/dungeon_puzzle_generator.gd")

@onready var enemy_label: Label = $ContentMargin/VBoxContainer/HeaderRow/EnemyBlock/EnemyLabel
@onready var enemy_desc_label: Label = $ContentMargin/VBoxContainer/HeaderRow/EnemyBlock/EnemyDescLabel
@onready var player_hp_label: Label = $ContentMargin/VBoxContainer/HeaderRow/StatBlock/PlayerHpLabel
@onready var enemy_hp_label: Label = $ContentMargin/VBoxContainer/HeaderRow/StatBlock/EnemyHpLabel
@onready var objective_title: Label = $ContentMargin/VBoxContainer/ObjectiveCard/ObjectiveContent/ObjectiveTitle
@onready var objective_desc: Label = $ContentMargin/VBoxContainer/ObjectiveCard/ObjectiveContent/ObjectiveDesc
@onready var battle_board: Control = $ContentMargin/VBoxContainer/BoardCard/BattleBoard
@onready var status_label: Label = $ContentMargin/VBoxContainer/StatusLabel
@onready var equipment_label: Label = $ContentMargin/VBoxContainer/EquipmentLabel
@onready var leave_btn: Button = $ContentMargin/VBoxContainer/FooterRow/LeaveButton

var _puzzle_board: BoardModel
var _current_puzzle: Dictionary = {}


func _ready() -> void:
	if DungeonState.pending_enemy.is_empty():
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_map.tscn")
		return

	if leave_btn and not leave_btn.pressed.is_connected(_on_leave_pressed):
		leave_btn.pressed.connect(_on_leave_pressed)
	if battle_board and battle_board.has_signal("cell_pressed") and not battle_board.cell_pressed.is_connected(_on_cell_pressed):
		battle_board.cell_pressed.connect(_on_cell_pressed)

	_refresh_labels("Read the puzzle, place one X, and convert the solution into damage.")
	_next_puzzle()


func _next_puzzle() -> void:
	_current_puzzle = PuzzleGeneratorScript.generate_puzzle(DungeonState.pending_enemy, DungeonState.floor_index)
	_puzzle_board = BoardModel.new(int(_current_puzzle.get("board_size", 3)))
	_puzzle_board.cells = Array(_current_puzzle.get("cells", [])).duplicate()
	_puzzle_board.blocked_cells = Array(_current_puzzle.get("blocked", [])).duplicate()
	_puzzle_board.wildcard_cells = Array(_current_puzzle.get("wildcards", [])).duplicate()

	battle_board.rebuild_for_size(_puzzle_board.board_size)
	battle_board.sync_from_model(_puzzle_board)
	_refresh_interactive_cells()
	_refresh_labels("Solve the current puzzle to damage %s." % DungeonState.pending_enemy.get("display_name", "the enemy"))
	_apply_hint_if_needed()


func _refresh_labels(message: String) -> void:
	var enemy_name := String(DungeonState.pending_enemy.get("display_name", "Enemy"))
	enemy_label.text = enemy_name
	enemy_desc_label.text = String(DungeonState.pending_enemy.get("description", ""))
	player_hp_label.text = "HP %d / %d" % [DungeonState.player_hp, DungeonState.max_hp]
	enemy_hp_label.text = "%s HP %d" % [enemy_name, int(DungeonState.pending_enemy.get("current_hp", 0))]
	objective_title.text = String(_current_puzzle.get("title", "Puzzle"))
	objective_desc.text = String(_current_puzzle.get("description", ""))
	status_label.text = message

	var equipment_lines: Array[String] = DungeonState.get_equipment_descriptions()
	equipment_label.text = "Loadout: %s" % (" | ".join(equipment_lines) if not equipment_lines.is_empty() else "none")


func _refresh_interactive_cells() -> void:
	for index in battle_board.cells.size():
		var cell = battle_board.get_cell_node(index)
		if cell:
			cell.disabled = not _puzzle_board.is_empty(index)
			if cell.has_method("clear_shader_material"):
				cell.clear_shader_material()
			if cell.has_method("get_effect_overlay"):
				var overlay: ColorRect = cell.get_effect_overlay()
				overlay.visible = false


func _apply_hint_if_needed() -> void:
	if not DungeonState.should_reveal_hint():
		return
	var correct_moves: Array = _current_puzzle.get("correct_moves", [])
	if correct_moves.is_empty():
		return
	var hint_index := int(correct_moves[0])
	var hint_cell = battle_board.get_cell_node(hint_index)
	if hint_cell and hint_cell.has_method("get_effect_overlay"):
		var overlay: ColorRect = hint_cell.get_effect_overlay()
		overlay.visible = true
		overlay.color = Color(0.96, 0.8, 0.46, 0.18)


func _on_cell_pressed(index: int) -> void:
	if not _puzzle_board or not _puzzle_board.is_empty(index):
		return

	_puzzle_board.set_cell(index, 0)
	battle_board.sync_from_model(_puzzle_board)
	_refresh_interactive_cells()

	if PuzzleGeneratorScript.is_correct_move(_current_puzzle, index):
		var damage := int(_current_puzzle.get("base_damage", 0)) + DungeonState.get_player_damage_bonus(String(_current_puzzle.get("variant_id", "")))
		DungeonState.pending_enemy["current_hp"] = maxi(int(DungeonState.pending_enemy.get("current_hp", 0)) - damage, 0)
		if int(DungeonState.pending_enemy.get("current_hp", 0)) <= 0:
			DungeonState.complete_battle_win()
			get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_reward.tscn")
			return
		_refresh_labels("Correct. You deal %d damage." % damage)
		await get_tree().create_timer(0.4).timeout
		_next_puzzle()
		return

	var enemy_damage := maxi(int(DungeonState.pending_enemy.get("base_damage", 1)) - DungeonState.get_enemy_damage_reduction(), 1)
	DungeonState.apply_damage(enemy_damage)
	if DungeonState.status == DungeonState.CrawlStatus.LOST:
		status_label.text = "You were overwhelmed in the dungeon."
		leave_btn.text = "Return to Menu"
		battle_board.set_cells_disabled(true)
		return

	_refresh_labels("Wrong read. %s hits you for %d." % [DungeonState.pending_enemy.get("display_name", "The enemy"), enemy_damage])
	await get_tree().create_timer(0.45).timeout
	_next_puzzle()


func _on_leave_pressed() -> void:
	if DungeonState.status == DungeonState.CrawlStatus.LOST:
		DungeonState.reset()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_map.tscn")
