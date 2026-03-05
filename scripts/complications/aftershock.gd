class_name AftershockComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "aftershock"
	display_name = "Aftershock"
	description = "Every 4 turns, a random spatial mixup shakes the board!"
	color = Color(0.9, 0.6, 0.2)
	priority = 10
	incompatible_with = ["rotating_board"]


func on_game_start(_board: BoardModel) -> void:
	_state["turns_since_mixup"] = 0


func on_board_reset(_board: BoardModel) -> void:
	_state["turns_since_mixup"] = 0


func on_turn_end(_player: int, board: BoardModel, _turns: TurnManager) -> void:
	_state["turns_since_mixup"] = _state.get("turns_since_mixup", 0) + 1

	if _state["turns_since_mixup"] >= 4:
		_state["turns_since_mixup"] = 0
		SpatialMixups.apply_random(board)


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Center cells are mixup-invariant, worth more
	var center := board.get_center_cell()
	if board.get_cell(center) == player:
		return 3.0
	return 0.0


func get_visual_effects() -> Dictionary:
	var turns_left: int = 4 - _state.get("turns_since_mixup", 0)
	return {"aftershock_warning": turns_left}
