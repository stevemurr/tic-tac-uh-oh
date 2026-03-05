class_name RotatingBoardComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "rotating_board"
	display_name = "Rotating Board"
	description = "The board rotates 90° every 2 turns!"
	color = Color(0.2, 0.9, 0.4)
	priority = 10


func on_game_start(board: BoardModel) -> void:
	_state["turns_since_rotation"] = 0


func on_board_reset(board: BoardModel) -> void:
	_state["turns_since_rotation"] = 0


func on_turn_end(_player: int, board: BoardModel, _turns: TurnManager) -> void:
	_state["turns_since_rotation"] = _state.get("turns_since_rotation", 0) + 1

	if _state["turns_since_rotation"] >= 2:
		_state["turns_since_rotation"] = 0
		board.rotate_clockwise()


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Center is rotation-invariant, very valuable
	var center := board.get_center_cell()
	if board.get_cell(center) == player:
		return 3.0
	return 0.0


func get_visual_effects() -> Dictionary:
	var turns_left: int = 2 - _state.get("turns_since_rotation", 0)
	return {"rotation_warning": turns_left}
