class_name WildcardCellComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "wildcard_cell"
	display_name = "Wildcard Cell"
	description = "A special cell counts for BOTH players!"
	color = Color(1.0, 0.9, 0.2)
	priority = 5


func on_game_start(board: BoardModel) -> void:
	_spawn_wildcard(board)


func on_board_reset(board: BoardModel) -> void:
	# Clear old wildcards
	for i in board.cell_count:
		board.set_wildcard(i, false)
	_spawn_wildcard(board)


func _spawn_wildcard(board: BoardModel) -> void:
	var empty := board.get_empty_cells()
	empty = empty.filter(func(i: int) -> bool: return i != board.bomb_cell)
	if empty.is_empty():
		return
	var target: int = empty[randi() % empty.size()]
	board.set_wildcard(target, true)
	# Place a neutral mark so it's visible
	board.set_cell(target, 2)  # 2 = wildcard marker

func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Wildcard cells near your marks are good
	var score := 0.0
	for i in board.cell_count:
		if board.is_wildcard(i):
			var surrounding := board.get_surrounding_cells(i)
			for idx in surrounding:
				if board.get_cell(idx) == player:
					score += 1.0
	return score


func get_visual_effects() -> Dictionary:
	return {"wildcard_shimmer": true}
