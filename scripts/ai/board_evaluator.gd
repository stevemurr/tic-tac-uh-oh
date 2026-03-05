class_name BoardEvaluator
extends RefCounted

const WIN_SCORE := 1000.0
const DRAW_SCORE := 0.0


func evaluate(board: BoardModel, player: int, checker: WinChecker, complications: Array[ComplicationBase] = []) -> float:
	var winner := checker.check_winner_with_wildcards(board)
	if winner == player:
		return WIN_SCORE
	elif winner == 1 - player:
		return -WIN_SCORE

	if checker.is_draw(board):
		return DRAW_SCORE

	var score := 0.0

	# Evaluate line potential
	for pattern in checker.get_all_patterns():
		score += _evaluate_pattern(board, pattern, player)

	# Center control bonus
	var center := board.get_center_cell()
	if center < board.cell_count and not board.is_blocked(center):
		if board.get_cell(center) == player:
			score += 3.0
		elif board.get_cell(center) == 1 - player:
			score -= 3.0

	# Corner control
	for corner in board.get_corner_cells():
		if not board.is_blocked(corner):
			if board.get_cell(corner) == player:
				score += 1.0
			elif board.get_cell(corner) == 1 - player:
				score -= 1.0

	# Complication modifiers
	for comp in complications:
		if comp.is_active:
			score += comp.ai_evaluate_modifier(board, player)

	return score


func _evaluate_pattern(board: BoardModel, pattern: Array, player: int) -> float:
	var my_count := 0
	var opp_count := 0
	var empty_count := 0
	var blocked := false
	var win_length := pattern.size()

	for idx in pattern:
		if board.is_blocked(idx):
			blocked = true
			break
		var val := board.get_cell(idx)
		if val == player or (board.is_wildcard(idx) and val != -1):
			my_count += 1
		elif val == 1 - player:
			opp_count += 1
		elif val == -1:
			empty_count += 1

	if blocked:
		return 0.0

	# If line has both players' marks (and no wildcard help), it's dead
	if my_count > 0 and opp_count > 0:
		return 0.0

	# Score based on how close to winning
	if my_count == win_length - 1 and empty_count == 1:
		return 10.0  # One away from winning
	elif my_count > 0 and opp_count == 0:
		return float(my_count) * 1.0
	elif opp_count == win_length - 1 and empty_count == 1:
		return -10.0  # Must block
	elif opp_count > 0 and my_count == 0:
		return float(opp_count) * -1.0

	return 0.0
