class_name StolenTurnComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "stolen_turn"
	display_name = "Stolen Turn"
	description = "Each player can steal one opponent's cell per round!"
	color = Color(1.0, 0.8, 0.0)
	priority = 30

func on_board_reset(_board: BoardModel) -> void:
	_state["steals_granted"] = true


func on_validate_move(result: MoveResult, cell: int, player: int, board: BoardModel) -> void:
	if result.is_steal:
		# Validate steal move
		if cell < 0 or cell >= board.cell_count:
			result.is_valid = false
			result.reason = "Invalid cell"
			return
		if board.get_cell(cell) != 1 - player:
			result.is_valid = false
			result.reason = "Can only steal opponent's mark"
			return
		if board.is_blocked(cell):
			result.is_valid = false
			result.reason = "Cannot steal blocked cell"
			return
		result.is_valid = true

func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Having a steal available is valuable
	return 1.0


func get_visual_effects() -> Dictionary:
	return {"steal_available": true}
