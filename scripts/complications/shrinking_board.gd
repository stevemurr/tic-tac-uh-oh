class_name ShrinkingBoardComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "shrinking_board"
	display_name = "Shrinking Board"
	description = "Every 3 moves, a random empty cell gets blocked!"
	color = Color(0.6, 0.6, 0.6)
	priority = 5


func on_game_start(board: BoardModel) -> void:
	_state["moves_since_shrink"] = 0


func on_board_reset(board: BoardModel) -> void:
	_state["moves_since_shrink"] = 0


func on_move_placed(cell: int, player: int, board: BoardModel) -> void:
	_state["moves_since_shrink"] = _state.get("moves_since_shrink", 0) + 1

	if _state["moves_since_shrink"] >= 3:
		_state["moves_since_shrink"] = 0
		_try_shrink(board)


func _try_shrink(board: BoardModel) -> void:
	if board.get_playable_cells().size() <= 3:
		return

	var edge_corners := board.get_edge_corner_cells()
	var candidates: Array[int] = []
	for idx in edge_corners:
		if board.is_empty(idx) and not board.is_wildcard(idx):
			candidates.append(idx)

	# If no edge/corners available, try any empty cell
	if candidates.is_empty():
		candidates = board.get_empty_cells()
		# Filter out wildcards
		candidates = candidates.filter(func(i: int) -> bool: return not board.is_wildcard(i))

	if candidates.is_empty():
		return

	var target: int = candidates[randi() % candidates.size()]
	board.set_blocked(target, true)

	# If bomb was on this cell, relocate it
	if board.bomb_cell == target:
		_relocate_special(board, "bomb")
	# If wildcard was on this cell, relocate it
	if board.is_wildcard(target):
		board.set_wildcard(target, false)
		_relocate_special(board, "wildcard")


func _relocate_special(board: BoardModel, type: String) -> void:
	var empty := board.get_empty_cells()
	empty = empty.filter(func(i: int) -> bool: return not board.is_wildcard(i) and i != board.bomb_cell)
	if empty.is_empty():
		if type == "bomb":
			board.bomb_cell = -1
		return
	var new_pos: int = empty[randi() % empty.size()]
	if type == "bomb":
		board.bomb_cell = new_pos
	elif type == "wildcard":
		board.set_wildcard(new_pos, true)


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Prefer center when board is shrinking
	var center := board.get_center_cell()
	if board.get_cell(center) == player:
		return 2.0
	return 0.0
