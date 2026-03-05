class_name MoveValidator
extends RefCounted

func validate_move(cell: int, player: int, board: BoardModel, complications: Array[ComplicationBase]) -> MoveResult:
	var result := MoveResult.new()
	result.cell = cell
	result.player = player
	result.is_valid = true

	# Basic validation
	if cell < 0 or cell >= board.cell_count:
		result.is_valid = false
		result.reason = "Invalid cell index"
		return result

	if board.is_blocked(cell):
		result.is_valid = false
		result.reason = "Cell is blocked"
		return result

	if board.is_wildcard(cell):
		result.is_valid = false
		result.reason = "Cannot play on wildcard cell"
		return result

	if board.get_cell(cell) != -1:
		result.is_valid = false
		result.reason = "Cell is occupied"
		return result

	# Run through complication hooks (sorted by priority)
	for comp in complications:
		if comp.is_active:
			comp.on_validate_move(result, cell, player, board)
			if not result.is_valid:
				return result

	return result
