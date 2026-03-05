class_name DecayComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "decay"
	display_name = "Fading Marks"
	description = "Marks disappear after 6 turns!"
	color = Color(0.7, 0.5, 0.9)
	priority = 15


func on_game_start(_board: BoardModel) -> void:
	_state["placement_turns"] = {}
	_state["global_turn"] = 0


func on_board_reset(_board: BoardModel) -> void:
	_state["placement_turns"] = {}
	_state["global_turn"] = 0


func on_move_placed(cell: int, _player: int, _board: BoardModel) -> void:
	_state["global_turn"] += 1
	_state["placement_turns"][cell] = _state["global_turn"]


func on_turn_end(_player: int, board: BoardModel, _turns: TurnManager) -> void:
	var current: int = _state["global_turn"]
	var to_remove: Array[int] = []
	var placements: Dictionary = _state["placement_turns"]

	for cell_key in placements:
		var cell: int = cell_key if cell_key is int else int(str(cell_key))
		if current - placements[cell_key] >= 6:
			if cell < board.cell_count and board.get_cell(cell) != -1 and not board.is_blocked(cell):
				to_remove.append(cell)

	for cell in to_remove:
		board.set_cell(cell, -1)
		_state["placement_turns"].erase(cell)


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Prefer cells that extend existing lines — isolated marks will decay
	var score := 0.0
	for i in board.cell_count:
		if board.get_cell(i) == player:
			var adjacent_own := 0
			for idx in board.get_surrounding_cells(i):
				if board.get_cell(idx) == player:
					adjacent_own += 1
			score += adjacent_own * 0.5
	return score


func get_visual_effects() -> Dictionary:
	return {"decay_warning": true}
