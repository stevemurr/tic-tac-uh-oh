class_name TheBombComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "the_bomb"
	display_name = "The Bomb"
	description = "A hidden bomb clears all surrounding cells!"
	color = Color(1.0, 0.3, 0.1)
	priority = 25


func on_game_start(board: BoardModel) -> void:
	_spawn_bomb(board)


func on_board_reset(board: BoardModel) -> void:
	_spawn_bomb(board)


func on_move_placed(cell: int, _player: int, board: BoardModel) -> void:
	if cell == board.bomb_cell:
		board.explode_bomb(cell)
		board.bomb_cell = -1
		# Spawn new bomb after detonation
		_spawn_bomb(board)


func _spawn_bomb(board: BoardModel) -> void:
	var empty := board.get_empty_cells()
	empty = empty.filter(func(i: int) -> bool: return not board.is_wildcard(i))
	if empty.is_empty():
		board.bomb_cell = -1
		return
	board.bomb_cell = empty[randi() % empty.size()]


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	if board.bomb_cell < 0:
		return 0.0
	# Avoid placing on bomb if it would clear own marks
	var surrounding := board.get_surrounding_cells(board.bomb_cell)
	var own_marks := 0
	var opp_marks := 0
	for idx in surrounding:
		if board.get_cell(idx) == player:
			own_marks += 1
		elif board.get_cell(idx) == 1 - player:
			opp_marks += 1
	return float(opp_marks - own_marks) * 2.0


func get_visual_effects() -> Dictionary:
	return {"bomb_pulse": true}
