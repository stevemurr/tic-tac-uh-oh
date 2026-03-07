class_name DungeonPuzzleGenerator
extends RefCounted

static func generate_puzzle(enemy: Dictionary, floor_index: int) -> Dictionary:
	var preferred: Array = enemy.get("preferred_variants", ["line_strike", "shield_block", "fork_setup"])
	var variant_id: String = String(preferred[randi() % preferred.size()])
	match variant_id:
		"shield_block":
			return _generate_shield_block(floor_index)
		"fork_setup":
			return _generate_fork_setup(floor_index)
		_:
			return _generate_line_strike(floor_index)


static func is_correct_move(puzzle: Dictionary, index: int) -> bool:
	return index in Array(puzzle.get("correct_moves", []))


static func _generate_line_strike(floor_index: int) -> Dictionary:
	return _generate_with_search(
		"line_strike",
		"Line Strike",
		"Place X to complete a winning line.",
		3,
		3,
		3 + mini(floor_index / 2, 2),
		func(board: BoardModel, checker: WinChecker) -> Array[int]:
			var player_wins: Array[int] = _find_immediate_wins(board, 0, checker)
			var enemy_wins: Array[int] = _find_immediate_wins(board, 1, checker)
			if player_wins.is_empty() or not enemy_wins.is_empty():
				return []
			return player_wins
	)


static func _generate_shield_block(floor_index: int) -> Dictionary:
	return _generate_with_search(
		"shield_block",
		"Shield Block",
		"Place X to stop O's immediate winning move.",
		3,
		3,
		2 + mini(floor_index / 2, 2),
		func(board: BoardModel, checker: WinChecker) -> Array[int]:
			var player_wins: Array[int] = _find_immediate_wins(board, 0, checker)
			var enemy_wins: Array[int] = _find_immediate_wins(board, 1, checker)
			if not player_wins.is_empty():
				return []
			if enemy_wins.size() != 1:
				return []
			return enemy_wins
	)


static func _generate_fork_setup(floor_index: int) -> Dictionary:
	return _generate_with_search(
		"fork_setup",
		"Fork Setup",
		"Place X to create two winning threats at once.",
		3,
		3,
		4 + mini(floor_index / 2, 3),
		func(board: BoardModel, checker: WinChecker) -> Array[int]:
			var player_wins: Array[int] = _find_immediate_wins(board, 0, checker)
			var enemy_wins: Array[int] = _find_immediate_wins(board, 1, checker)
			if not player_wins.is_empty() or not enemy_wins.is_empty():
				return []
			return _find_fork_moves(board, 0, checker)
	)


static func _generate_with_search(
	variant_id: String,
	title: String,
	description: String,
	board_size: int,
	win_length: int,
	base_damage: int,
	evaluator: Callable
) -> Dictionary:
	var checker := WinChecker.new(board_size, win_length)

	for attempt in 120:
		var board := BoardModel.new(board_size)
		_randomize_board(board)
		if checker.check_winner_with_wildcards(board) != -1:
			continue

		var correct_moves: Array[int] = evaluator.call(board, checker)
		if correct_moves.is_empty():
			continue

		return {
			"variant_id": variant_id,
			"title": title,
			"description": description,
			"board_size": board_size,
			"win_length": win_length,
			"cells": board.cells.duplicate(),
			"blocked": board.blocked_cells.duplicate(),
			"wildcards": board.wildcard_cells.duplicate(),
			"correct_moves": correct_moves.duplicate(),
			"base_damage": base_damage,
		}

	return _fallback_puzzle(variant_id)


static func _fallback_puzzle(variant_id: String) -> Dictionary:
	match variant_id:
		"shield_block":
			return {
				"variant_id": "shield_block",
				"title": "Shield Block",
				"description": "Place X to stop O's immediate winning move.",
				"board_size": 3,
				"win_length": 3,
				"cells": [1, 1, -1, 0, -1, -1, -1, 0, -1],
				"blocked": [false, false, false, false, false, false, false, false, false],
				"wildcards": [false, false, false, false, false, false, false, false, false],
				"correct_moves": [2],
				"base_damage": 3,
			}
		"fork_setup":
			return {
				"variant_id": "fork_setup",
				"title": "Fork Setup",
				"description": "Place X to create two winning threats at once.",
				"board_size": 3,
				"win_length": 3,
				"cells": [0, -1, -1, -1, 1, -1, -1, -1, 0],
				"blocked": [false, false, false, false, false, false, false, false, false],
				"wildcards": [false, false, false, false, false, false, false, false, false],
				"correct_moves": [2, 6],
				"base_damage": 4,
			}
		_:
			return {
				"variant_id": "line_strike",
				"title": "Line Strike",
				"description": "Place X to complete a winning line.",
				"board_size": 3,
				"win_length": 3,
				"cells": [0, 0, -1, -1, 1, -1, -1, -1, 1],
				"blocked": [false, false, false, false, false, false, false, false, false],
				"wildcards": [false, false, false, false, false, false, false, false, false],
				"correct_moves": [2],
				"base_damage": 3,
			}


static func _randomize_board(board: BoardModel) -> void:
	var positions: Array[int] = []
	for i in board.cell_count:
		positions.append(i)
	positions.shuffle()

	var x_count := 2 + randi() % 2
	var o_count := 2 + randi() % 2
	var cursor := 0
	for i in x_count:
		board.set_cell(positions[cursor], 0)
		cursor += 1
	for i in o_count:
		board.set_cell(positions[cursor], 1)
		cursor += 1


static func _find_immediate_wins(board: BoardModel, player: int, checker: WinChecker) -> Array[int]:
	var winning_moves: Array[int] = []
	for index in board.get_playable_cells():
		var test_board := board.duplicate_board()
		test_board.set_cell(index, player)
		if checker.check_winner_with_wildcards(test_board) == player:
			winning_moves.append(index)
	return winning_moves


static func _find_fork_moves(board: BoardModel, player: int, checker: WinChecker) -> Array[int]:
	var forks: Array[int] = []
	for index in board.get_playable_cells():
		var test_board := board.duplicate_board()
		test_board.set_cell(index, player)
		if checker.check_winner_with_wildcards(test_board) != -1:
			continue
		var next_wins: Array[int] = _find_immediate_wins(test_board, player, checker)
		if next_wins.size() >= 2:
			forks.append(index)
	return forks
