class_name WinChecker
extends RefCounted

var _win_patterns: Array[Array] = []
var _board_size: int = 3
var _win_length: int = 3

var custom_patterns: Array[Array] = []

func _init(board_size: int = 3, win_length: int = 3) -> void:
	_board_size = board_size
	_win_length = win_length
	generate_patterns(board_size, win_length)

func generate_patterns(board_size: int, win_length: int) -> void:
	_board_size = board_size
	_win_length = win_length
	_win_patterns.clear()

	# Rows — sliding windows
	for r in board_size:
		for c in range(0, board_size - win_length + 1):
			var pattern: Array = []
			for k in win_length:
				pattern.append(r * board_size + c + k)
			_win_patterns.append(pattern)

	# Columns — sliding windows
	for c in board_size:
		for r in range(0, board_size - win_length + 1):
			var pattern: Array = []
			for k in win_length:
				pattern.append((r + k) * board_size + c)
			_win_patterns.append(pattern)

	# Diagonals (top-left to bottom-right) — sliding windows
	for r in range(0, board_size - win_length + 1):
		for c in range(0, board_size - win_length + 1):
			var pattern: Array = []
			for k in win_length:
				pattern.append((r + k) * board_size + (c + k))
			_win_patterns.append(pattern)

	# Anti-diagonals (top-right to bottom-left) — sliding windows
	for r in range(0, board_size - win_length + 1):
		for c in range(win_length - 1, board_size):
			var pattern: Array = []
			for k in win_length:
				pattern.append((r + k) * board_size + (c - k))
			_win_patterns.append(pattern)

func get_all_patterns() -> Array[Array]:
	if custom_patterns.size() > 0:
		return custom_patterns
	return _win_patterns

func set_custom_patterns(patterns: Array[Array]) -> void:
	custom_patterns = patterns

func clear_custom_patterns() -> void:
	custom_patterns.clear()

func check_winner(board: BoardModel) -> int:
	# Returns: 0 = X wins, 1 = O wins, -1 = no winner
	for pattern in get_all_patterns():
		var result := _check_pattern(board, pattern)
		if result != -1:
			return result
	return -1

func _check_pattern(board: BoardModel, pattern: Array) -> int:
	var first_val := -1
	for i in pattern.size():
		var idx: int = pattern[i]
		if board.is_blocked(idx):
			return -1
		var val := board.get_cell(idx)
		if board.is_wildcard(idx) and val == -1:
			# Empty wildcard doesn't count
			continue
		if board.is_wildcard(idx):
			# Wildcard with a mark counts for both - skip for now
			continue
		if val == -1:
			return -1
		if first_val == -1:
			first_val = val
		elif val != first_val:
			# Check if mismatch is due to wildcard
			return -1

	if first_val == -1:
		return -1
	return first_val

func check_winner_with_wildcards(board: BoardModel) -> int:
	# More thorough check considering wildcards count as both
	for pattern in get_all_patterns():
		for player in [0, 1]:
			if _pattern_wins_for_player(board, pattern, player):
				return player
	return -1

func _pattern_wins_for_player(board: BoardModel, pattern: Array, player: int) -> bool:
	for i in pattern.size():
		var idx: int = pattern[i]
		if board.is_blocked(idx):
			return false
		if board.is_wildcard(idx):
			# Wildcard counts as this player, always matches
			if board.get_cell(idx) == -1:
				return false  # Empty wildcard doesn't count
			continue
		var val := board.get_cell(idx)
		if val != player:
			return false
	return true

func is_draw(board: BoardModel) -> bool:
	# Draw if no winner and no playable cells
	if check_winner_with_wildcards(board) != -1:
		return false
	return board.get_playable_cells().size() == 0

func get_winning_pattern(board: BoardModel, player: int) -> Array:
	# Returns the winning pattern indices, or empty array
	for pattern in get_all_patterns():
		if _pattern_wins_for_player(board, pattern, player):
			return pattern
	return []
