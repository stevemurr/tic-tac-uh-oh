class_name MirrorMovesComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "mirror_moves"
	display_name = "Mirror Moves"
	description = "Each move also places on the mirrored cell!"
	color = Color(0.8, 0.4, 1.0)
	priority = 15


func on_move_placed(cell: int, player: int, board: BoardModel) -> void:
	var mirror := board.get_mirror_index(cell)
	if mirror != cell and board.is_empty(mirror) and not board.is_wildcard(mirror):
		board.set_cell(mirror, player)


func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
	# Center column is powerful with mirror (no mirror effect)
	var center_col_cells := board.get_center_column_cells()
	var score := 0.0
	for idx in center_col_cells:
		if board.get_cell(idx) == player:
			score += 1.5
	return score


func get_visual_effects() -> Dictionary:
	return {"mirror_line": true}
