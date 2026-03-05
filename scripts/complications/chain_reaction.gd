class_name ChainReactionComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "chain_reaction"
	display_name = "Chain Reaction"
	description = "Cluster 3+ of your marks to destroy an adjacent opponent mark!"
	color = Color(1.0, 0.2, 0.5)
	priority = 22


func on_move_placed(cell: int, player: int, board: BoardModel) -> void:
	var adjacent_own := 0
	var adjacent_opp: Array[int] = []

	for idx in board.get_surrounding_cells(cell):
		if board.get_cell(idx) == player:
			adjacent_own += 1
		elif board.get_cell(idx) == 1 - player:
			adjacent_opp.append(idx)

	if adjacent_own >= 2 and not adjacent_opp.is_empty():
		var target: int = adjacent_opp[randi() % adjacent_opp.size()]
		board.set_cell(target, -1)


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Bonus for moves adjacent to 2+ own marks and near opponent marks
	var score := 0.0
	var empty := board.get_empty_cells()
	for cell in empty:
		var own := 0
		var opp := 0
		for idx in board.get_surrounding_cells(cell):
			if board.get_cell(idx) == player:
				own += 1
			elif board.get_cell(idx) == 1 - player:
				opp += 1
		if own >= 2 and opp >= 1:
			score += 1.5
	return score
