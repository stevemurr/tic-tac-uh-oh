class_name BoardTransitionGuard
extends RefCounted

const REMIX_ATTEMPTS := 6
const SHUFFLE_ATTEMPTS := 96
const DISRUPTION_ATTEMPTS := 16


static func has_immediate_winning_move(board: BoardModel, win_checker: WinChecker) -> bool:
	return not get_immediate_winning_moves(board, win_checker).is_empty()


static func get_immediate_winning_moves(board: BoardModel, win_checker: WinChecker) -> Array[Dictionary]:
	var threats: Array[Dictionary] = []
	var playable_cells: Array[int] = board.get_playable_cells()
	for cell in playable_cells:
		for player in [0, 1]:
			var trial_board := board.duplicate_board()
			trial_board.set_cell(cell, player)
			if win_checker.check_winner_with_wildcards(trial_board) == player:
				threats.append({
					"cell": cell,
					"player": player,
					"pattern": win_checker.get_winning_pattern(trial_board, player),
				})
	return threats


static func stabilize_mixup(board: BoardModel, win_checker: WinChecker, mixup_name: String = "") -> String:
	var final_mixup := mixup_name
	if not has_immediate_winning_move(board, win_checker):
		return final_mixup

	for _attempt in REMIX_ATTEMPTS:
		final_mixup = SpatialMixups.apply_random(board)
		if not has_immediate_winning_move(board, win_checker):
			return final_mixup

	for _attempt in SHUFFLE_ATTEMPTS:
		SpatialMixups.apply_by_name(board, "Shuffle")
		final_mixup = "Shuffle"
		if not has_immediate_winning_move(board, win_checker):
			return final_mixup

	if _disrupt_immediate_wins(board, win_checker):
		return "Shuffle" if final_mixup == "" else final_mixup

	return final_mixup


static func _disrupt_immediate_wins(board: BoardModel, win_checker: WinChecker) -> bool:
	for _attempt in DISRUPTION_ATTEMPTS:
		var threats := get_immediate_winning_moves(board, win_checker)
		if threats.is_empty():
			return true
		if not _break_threat(board, win_checker, threats[0]):
			return false
	return not has_immediate_winning_move(board, win_checker)


static func _break_threat(board: BoardModel, win_checker: WinChecker, threat: Dictionary) -> bool:
	var pattern: Array = threat.get("pattern", [])
	var player: int = int(threat.get("player", -1))
	var winning_cell: int = int(threat.get("cell", -1))
	if pattern.is_empty() or player == -1:
		return false

	var source_candidates: Array[int] = []
	for cell in pattern:
		var idx: int = int(cell)
		if idx == winning_cell:
			continue
		if board.get_cell(idx) == player and not board.is_blocked(idx) and not board.is_wildcard(idx):
			source_candidates.append(idx)
	if source_candidates.is_empty():
		return false
	source_candidates.shuffle()

	var destination_candidates: Array[int] = board.get_playable_cells()
	destination_candidates.erase(winning_cell)
	destination_candidates = destination_candidates.filter(func(idx: int) -> bool: return not pattern.has(idx))
	destination_candidates.shuffle()
	if destination_candidates.is_empty():
		return false

	for source_idx in source_candidates:
		for destination_idx in destination_candidates:
			board.set_cell(source_idx, -1)
			board.set_cell(destination_idx, player)
			if not has_immediate_winning_move(board, win_checker):
				return true
			board.set_cell(destination_idx, -1)
			board.set_cell(source_idx, player)

	return false
