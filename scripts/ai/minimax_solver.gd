class_name MinimaxSolver
extends RefCounted

enum Difficulty { EASY, MEDIUM, HARD }

const MAX_NODES := 50000

var _checker: WinChecker
var _evaluator: BoardEvaluator
var _complications: Array[ComplicationBase] = []
var _difficulty: Difficulty = Difficulty.MEDIUM
var _nodes_searched: int = 0


func _init() -> void:
	_checker = WinChecker.new()
	_evaluator = BoardEvaluator.new()


func set_difficulty(diff: Difficulty) -> void:
	_difficulty = diff


func set_complications(comps: Array[ComplicationBase]) -> void:
	_complications = comps


func get_best_move(board: BoardModel, player: int) -> int:
	_nodes_searched = 0

	# Regenerate win patterns for the current board size
	_checker.generate_patterns(board.board_size, _get_win_length(board))

	match _difficulty:
		Difficulty.EASY:
			return _get_easy_move(board, player)
		Difficulty.MEDIUM:
			return _get_medium_move(board, player)
		Difficulty.HARD:
			return _get_hard_move(board, player)

	return _get_medium_move(board, player)


func _get_win_length(board: BoardModel) -> int:
	# Derive win length from GameState if available, otherwise match board size
	return GameState.current_win_length


func _get_easy_move(board: BoardModel, player: int) -> int:
	var moves := _get_available_moves(board, player)
	if moves.is_empty():
		return -1

	# 70% random, 30% depth-1 minimax
	if randf() < 0.7:
		return moves[randi() % moves.size()]

	return _find_best_move(board, player, 1)


func _get_medium_move(board: BoardModel, player: int) -> int:
	var depth := _compute_max_depth(board)
	return _find_best_move(board, player, mini(depth, 3))


func _get_hard_move(board: BoardModel, player: int) -> int:
	var depth := _compute_max_depth(board)
	return _find_best_move(board, player, depth)


func _compute_max_depth(board: BoardModel) -> int:
	var empty := board.get_playable_cells().size()
	if empty <= 9:
		return 9  # Full search for small boards
	elif empty <= 16:
		return 5
	elif empty <= 36:
		return 3
	else:
		return 2


func _find_best_move(board: BoardModel, player: int, max_depth: int) -> int:
	var moves := _get_available_moves(board, player)
	if moves.is_empty():
		return -1

	var best_score := -INF
	var best_move := moves[0]

	for move in moves:
		if _nodes_searched >= MAX_NODES:
			break

		var sim_board := board.duplicate_board()
		_simulate_move(sim_board, move, player)

		var score := _minimax(sim_board, max_depth - 1, false, player, -INF, INF)

		if score > best_score:
			best_score = score
			best_move = move

	return best_move


func _minimax(board: BoardModel, depth: int, is_maximizing: bool, ai_player: int, alpha: float, beta: float) -> float:
	_nodes_searched += 1

	if _nodes_searched >= MAX_NODES:
		return _evaluator.evaluate(board, ai_player, _checker, _complications)

	var winner := _checker.check_winner_with_wildcards(board)
	if winner == ai_player:
		return 1000.0 + depth  # Prefer faster wins
	elif winner == 1 - ai_player:
		return -1000.0 - depth  # Prefer slower losses

	if _checker.is_draw(board) or depth <= 0:
		if _difficulty == Difficulty.HARD:
			return _evaluator.evaluate(board, ai_player, _checker, _complications)
		return _evaluator.evaluate(board, ai_player, _checker)

	var current_player := ai_player if is_maximizing else 1 - ai_player
	var moves := _get_available_moves(board, current_player)

	if moves.is_empty():
		return _evaluator.evaluate(board, ai_player, _checker)

	if is_maximizing:
		var max_eval := -INF
		for move in moves:
			if _nodes_searched >= MAX_NODES:
				break
			var sim_board := board.duplicate_board()
			_simulate_move(sim_board, move, current_player)
			var eval := _minimax(sim_board, depth - 1, false, ai_player, alpha, beta)
			max_eval = maxf(max_eval, eval)
			alpha = maxf(alpha, eval)
			if beta <= alpha:
				break
		return max_eval
	else:
		var min_eval := INF
		for move in moves:
			if _nodes_searched >= MAX_NODES:
				break
			var sim_board := board.duplicate_board()
			_simulate_move(sim_board, move, current_player)
			var eval := _minimax(sim_board, depth - 1, true, ai_player, alpha, beta)
			min_eval = minf(min_eval, eval)
			beta = minf(beta, eval)
			if beta <= alpha:
				break
		return min_eval


func _simulate_move(board: BoardModel, cell: int, player: int) -> void:
	board.set_cell(cell, player)

	# Run complication on_move_placed hooks in priority order
	var sorted_comps := _complications.duplicate()
	sorted_comps.sort_custom(func(a: ComplicationBase, b: ComplicationBase) -> bool: return a.priority < b.priority)

	for comp in sorted_comps:
		if comp.is_active:
			comp.on_move_placed(cell, player, board)


func _get_available_moves(board: BoardModel, player: int) -> Array[int]:
	var moves := board.get_playable_cells()

	# Let complications modify available moves
	for comp in _complications:
		if comp.is_active:
			moves = comp.ai_modify_available_moves(moves, board, player)

	return moves


func get_nodes_searched() -> int:
	return _nodes_searched
