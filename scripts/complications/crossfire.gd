class_name CrossfireComplication
extends ComplicationBase

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


func _init() -> void:
	complication_id = "crossfire"
	display_name = "Crossfire"
	description = "Placed marks blast in four directions, converting opponent marks until a wall stops the ray!"
	color = Color(1.0, 0.72, 0.18)
	priority = 19


func on_board_reset(_board: BoardModel) -> void:
	_state["last_source_cell"] = -1
	_state["last_player"] = -1
	_state["last_converted_cells"] = []


func on_move_placed(cell: int, player: int, board: BoardModel) -> void:
	var converted: Array[int] = []
	var row := board.get_row(cell)
	var col := board.get_col(cell)

	for dir in DIRECTIONS:
		var r := row + dir.y
		var c := col + dir.x

		while r >= 0 and r < board.board_size and c >= 0 and c < board.board_size:
			var idx := board.index_from_rc(r, c)
			if board.is_blocked(idx):
				break
			if board.get_cell(idx) == 1 - player:
				board.set_cell(idx, player)
				converted.append(idx)
			r += dir.y
			c += dir.x

	_state["last_source_cell"] = cell
	_state["last_player"] = player
	_state["last_converted_cells"] = converted


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	var score := 0.0
	for cell in board.get_empty_cells():
		if board.is_blocked(cell) or board.is_wildcard(cell):
			continue
		score += float(_count_conversions(cell, player, board)) * 1.2
	return score


func _count_conversions(cell: int, player: int, board: BoardModel) -> int:
	var total := 0
	var row := board.get_row(cell)
	var col := board.get_col(cell)

	for dir in DIRECTIONS:
		var r := row + dir.y
		var c := col + dir.x

		while r >= 0 and r < board.board_size and c >= 0 and c < board.board_size:
			var idx := board.index_from_rc(r, c)
			if board.is_blocked(idx):
				break
			if board.get_cell(idx) == 1 - player:
				total += 1
			r += dir.y
			c += dir.x

	return total

