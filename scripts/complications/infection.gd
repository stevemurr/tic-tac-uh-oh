class_name InfectionComplication
extends ComplicationBase

const DIRECTIONS: Array = [
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
	Vector2i(0, -1),                   Vector2i(0, 1),
	Vector2i(1, -1),  Vector2i(1, 0),  Vector2i(1, 1),
]

func _init() -> void:
	complication_id = "infection"
	display_name = "Infection"
	description = "Flank opponent marks between yours to convert them!"
	color = Color(0.3, 0.9, 0.3)
	priority = 18


func on_move_placed(cell: int, player: int, board: BoardModel) -> void:
	var row := board.get_row(cell)
	var col := board.get_col(cell)
	var opponent := 1 - player

	for dir in DIRECTIONS:
		var captured: Array[int] = []
		var r: int = row + int(dir.y)
		var c: int = col + int(dir.x)

		# Walk in this direction, collecting opponent marks
		while r >= 0 and r < board.board_size and c >= 0 and c < board.board_size:
			var idx: int = board.index_from_rc(r, c)
			if board.get_cell(idx) == opponent and not board.is_blocked(idx):
				captured.append(idx)
			elif board.get_cell(idx) == player and not captured.is_empty():
				# Found our own mark after 1+ opponent marks — convert them
				for cap_idx in captured:
					board.set_cell(cap_idx, player)
				break
			else:
				break
			r += int(dir.y)
			c += int(dir.x)


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	var score := 0.0
	var opponent := 1 - player

	for cell in board.get_empty_cells():
		if board.is_blocked(cell) or board.is_wildcard(cell):
			continue
		var conversions := _count_conversions(cell, player, board)
		if conversions >= 2:
			score += conversions * 2.0
		elif conversions == 1:
			score += 1.0
	return score


func _count_conversions(cell: int, player: int, board: BoardModel) -> int:
	var row := board.get_row(cell)
	var col := board.get_col(cell)
	var opponent := 1 - player
	var total := 0

	for dir in DIRECTIONS:
		var count := 0
		var r: int = row + int(dir.y)
		var c: int = col + int(dir.x)

		while r >= 0 and r < board.board_size and c >= 0 and c < board.board_size:
			var idx: int = board.index_from_rc(r, c)
			if board.get_cell(idx) == opponent and not board.is_blocked(idx):
				count += 1
			elif board.get_cell(idx) == player and count > 0:
				total += count
				break
			else:
				break
			r += int(dir.y)
			c += int(dir.x)

	return total


func get_visual_effects() -> Dictionary:
	return {"infection_pulse": true}
