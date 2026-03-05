class_name GravityComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "gravity"
	display_name = "Gravity"
	description = "Marks fall to the bottom of their column!"
	color = Color(0.2, 0.6, 1.0)
	priority = 20


func on_move_placed(_cell: int, _player: int, board: BoardModel) -> void:
	board.apply_gravity()


func ai_modify_available_moves(moves: Array[int], board: BoardModel, _player: int) -> Array[int]:
	# With gravity, only the top of each column matters for placement
	# but the mark will fall. Return all valid moves but AI should understand gravity.
	var gravity_moves: Array[int] = []
	var seen_cols: Dictionary = {}
	for m in moves:
		var col := board.get_col(m)
		if col not in seen_cols:
			# Find the lowest empty cell in this column
			var lowest := -1
			for row in range(board.board_size - 1, -1, -1):
				var idx := board.index_from_rc(row, col)
				if board.is_empty(idx) and not board.is_wildcard(idx):
					lowest = idx
					break
			if lowest >= 0:
				gravity_moves.append(lowest)
				seen_cols[col] = true
	return gravity_moves


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Prefer lower rows with gravity
	var score := 0.0
	for i in board.cell_count:
		if board.get_cell(i) == player:
			score += board.get_row(i) * 0.5
	return score
