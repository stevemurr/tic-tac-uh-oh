extends RefCounted

## Each method returns "" on pass, error string on fail.


func check_board_consistency(board: BoardModel) -> String:
	if board.cells.size() != board.cell_count:
		return "cells array size %d != cell_count %d" % [board.cells.size(), board.cell_count]
	if board.blocked_cells.size() != board.cell_count:
		return "blocked_cells size %d != cell_count %d" % [board.blocked_cells.size(), board.cell_count]
	if board.wildcard_cells.size() != board.cell_count:
		return "wildcard_cells size %d != cell_count %d" % [board.wildcard_cells.size(), board.cell_count]
	if board.cell_count != board.board_size * board.board_size:
		return "cell_count %d != board_size^2 %d" % [board.cell_count, board.board_size * board.board_size]

	for i in board.cell_count:
		var v = board.cells[i]
		if v < -1 or v > 2:
			return "cell %d has invalid value %d" % [i, v]

	if board.bomb_cell >= board.cell_count:
		return "bomb_cell %d out of bounds (cell_count=%d)" % [board.bomb_cell, board.cell_count]

	return ""


func check_mark_preservation(before: BoardModel, after: BoardModel, operation: String) -> String:
	var before_counts = _count_marks(before)
	var after_counts = _count_marks(after)

	for player in [0, 1, 2]:
		if before_counts[player] != after_counts[player]:
			return "%s changed player %d mark count: %d -> %d" % [operation, player, before_counts[player], after_counts[player]]

	return ""


func _count_marks(board: BoardModel) -> Dictionary:
	var counts = {0: 0, 1: 0, 2: 0}
	for i in board.cell_count:
		var v = board.cells[i]
		if v >= 0 and v <= 2 and not board.is_blocked(i):
			counts[v] += 1
	return counts


func check_no_moves_on_blocked(board: BoardModel) -> String:
	for i in board.cell_count:
		if board.is_blocked(i) and board.cells[i] != -1:
			# Blocked cells can retain marks from before they were blocked
			# But new marks should not be placed on them
			pass
	# This check is more about verifying playable_cells excludes blocked
	var playable = board.get_playable_cells()
	for idx in playable:
		if board.is_blocked(idx):
			return "get_playable_cells() returned blocked cell %d" % idx
	return ""


func check_playable_cells_valid(board: BoardModel) -> String:
	var playable = board.get_playable_cells()
	for idx in playable:
		if idx < 0 or idx >= board.cell_count:
			return "playable cell %d out of bounds" % idx
		if board.cells[idx] != -1:
			return "playable cell %d is not empty (value=%d)" % [idx, board.cells[idx]]
		if board.is_blocked(idx):
			return "playable cell %d is blocked" % idx
		if board.is_wildcard(idx):
			return "playable cell %d is wildcard" % idx
	return ""


func check_game_state_sync(board: BoardModel) -> String:
	if board.board_size != GameState.current_board_size:
		return "board.board_size %d != GameState.current_board_size %d" % [board.board_size, GameState.current_board_size]
	return ""


func check_win_patterns_valid(checker: WinChecker, board: BoardModel) -> String:
	var patterns = checker.get_all_patterns()
	for pi in patterns.size():
		var pattern: Array = patterns[pi]
		for idx in pattern:
			if idx < 0 or idx >= board.cell_count:
				return "pattern %d has index %d out of bounds (cell_count=%d)" % [pi, idx, board.cell_count]
	return ""


func check_growth_sequence(step: int, actual_size: int) -> String:
	# Growth: 3 -> 4 -> 6 -> 9 -> 13 -> 18
	# step 0 = initial 3, step 1 = first growth to 4, etc.
	var expected_sizes = [3, 4, 6, 9, 13, 18]
	if step < expected_sizes.size():
		if actual_size != expected_sizes[step]:
			return "growth step %d: expected size %d, got %d" % [step, expected_sizes[step], actual_size]
	return ""


func run_all_checks(sim) -> String:
	var board: BoardModel = sim.board
	var checker: WinChecker = sim.win_checker

	var err = check_board_consistency(board)
	if err != "":
		return "board_consistency: " + err

	err = check_playable_cells_valid(board)
	if err != "":
		return "playable_cells: " + err

	err = check_no_moves_on_blocked(board)
	if err != "":
		return "blocked_cells: " + err

	err = check_win_patterns_valid(checker, board)
	if err != "":
		return "win_patterns: " + err

	return ""
