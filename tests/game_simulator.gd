extends RefCounted

## Pure synchronous game simulator that mirrors game.gd logic without UI/await.
## Every mutating method returns "" on success or an error string on failure.

const BoardTransitionGuardScript = preload("res://scripts/core/board_transition_guard.gd")

var board: BoardModel
var win_checker: WinChecker
var move_validator: MoveValidator
var turn_manager: TurnManager
var minimax: MinimaxSolver

var game_over: bool = false
var winner: int = -1  # -1 = none, 0 = X, 1 = O
var draw_occurred: bool = false
var move_history: Array[Dictionary] = []
var forced_mixup: String = ""  # "" = random, "None" = skip, else = forced name

var _complications: Array[ComplicationBase] = []


func _init(size: int = 3, win_length: int = 3) -> void:
	board = BoardModel.new(size)
	win_checker = WinChecker.new(size, win_length)
	move_validator = MoveValidator.new()
	turn_manager = TurnManager.new()
	minimax = MinimaxSolver.new()

	GameState.current_board_size = size
	GameState.current_win_length = win_length


func start_round() -> void:
	board.reset()
	turn_manager.reset()
	game_over = false
	winner = -1
	draw_occurred = false
	move_history.clear()

	# Run complication hooks
	var sorted = _get_sorted_complications()
	for comp in sorted:
		comp.on_board_reset(board)
	for comp in sorted:
		comp.on_game_start(board)

	# Grant steals if stolen_turn is active
	for comp in _complications:
		if comp.complication_id == "stolen_turn" and comp.is_active:
			turn_manager.grant_steal(0)
			turn_manager.grant_steal(1)


func add_complication(comp: ComplicationBase) -> void:
	comp.is_active = true
	_complications.append(comp)
	GameState.add_complication(comp)


func get_complications() -> Array[ComplicationBase]:
	return _complications


func _get_sorted_complications() -> Array[ComplicationBase]:
	var sorted = _complications.duplicate()
	sorted.sort_custom(func(a: ComplicationBase, b: ComplicationBase) -> bool: return a.priority < b.priority)
	return sorted


func place_move(cell: int) -> String:
	if game_over:
		return "Game is already over"

	var player = turn_manager.get_current_player()
	var result = move_validator.validate_move(cell, player, board, _get_sorted_complications())
	if not result.is_valid:
		return result.reason

	board.set_cell(cell, player)

	# Run on_move_placed hooks in priority order
	var sorted = _get_sorted_complications()
	for comp in sorted:
		if comp.is_active:
			comp.on_move_placed(cell, player, board)

	move_history.append({"cell": cell, "player": player, "type": "move"})
	return _check_result()


func execute_steal(cell: int) -> String:
	if game_over:
		return "Game is already over"

	var player = turn_manager.get_current_player()
	if not turn_manager.has_steal(player):
		return "No steal available for player %d" % player

	if cell < 0 or cell >= board.cell_count:
		return "Invalid cell index"
	if board.get_cell(cell) != 1 - player:
		return "Can only steal opponent's mark"
	if board.is_blocked(cell):
		return "Cannot steal blocked cell"

	# Execute steal: replace mark, no side-effect hooks
	turn_manager.use_steal(player)
	board.set_cell(cell, player)

	move_history.append({"cell": cell, "player": player, "type": "steal"})
	return _check_result()


func _check_result() -> String:
	var player = turn_manager.get_current_player()

	# Run on_check_win hooks
	var sorted = _get_sorted_complications()
	for comp in sorted:
		if comp.is_active:
			comp.on_check_win(board, win_checker)

	# Check for winner
	var w = win_checker.check_winner_with_wildcards(board)
	if w != -1:
		winner = w
		game_over = true
		return ""

	# Check for draw
	if win_checker.is_draw(board):
		draw_occurred = true
		# NOTE: Does NOT auto-call handle_draw(). Caller must check draw_occurred
		# and call handle_draw() explicitly. This allows state inspection between
		# draw detection and board growth.
		return ""

	# Run on_turn_end hooks
	for comp in sorted:
		if comp.is_active:
			comp.on_turn_end(player, board, turn_manager)

	# Advance turn
	turn_manager.advance_turn()
	return ""


func handle_draw() -> String:
	if not draw_occurred:
		return "No draw to handle"

	draw_occurred = false
	GameState.draw_count += 1

	if GameState.all_complications_used():
		game_over = true
		return ""

	# Pick new complication
	var active_ids: Array[String] = []
	for comp in _complications:
		active_ids.append(comp.complication_id)

	var new_comp = ComplicationRegistry.pick_random(active_ids)
	if new_comp == null:
		game_over = true
		return ""

	add_complication(new_comp)

	# Grow board
	var new_size = GameState.get_next_board_size()
	var new_win_length = GameState.get_next_win_length()
	GameState.apply_growth()

	board.grow(new_size)

	# Apply spatial mixup
	if forced_mixup == "None":
		pass  # Skip mixup entirely (baseline)
	elif forced_mixup != "":
		SpatialMixups.apply_by_name(board, forced_mixup)
	else:
		SpatialMixups.apply_random(board)

	# Regenerate win patterns
	win_checker.generate_patterns(new_size, new_win_length)
	if forced_mixup != "None":
		BoardTransitionGuardScript.stabilize_mixup(board, win_checker, forced_mixup if forced_mixup != "" else "")

	# Reset turns but keep marks
	turn_manager.reset()

	# Run hooks
	var sorted = _get_sorted_complications()
	for comp in sorted:
		comp.on_board_reset(board)
	for comp in sorted:
		comp.on_game_start(board)

	# Grant steals if stolen_turn is active
	for comp in _complications:
		if comp.complication_id == "stolen_turn" and comp.is_active:
			turn_manager.grant_steal(0)
			turn_manager.grant_steal(1)

	return ""


func play_ai_move(difficulty: MinimaxSolver.Difficulty = MinimaxSolver.Difficulty.HARD) -> String:
	if game_over:
		return "Game is already over"

	minimax.set_difficulty(difficulty)
	minimax.set_complications(_complications)

	var player = turn_manager.get_current_player()
	var move = minimax.get_best_move(board, player)

	if move < 0:
		return "AI found no valid move"

	return place_move(move)


func play_random_move() -> String:
	if game_over:
		return "Game is already over"

	var playable = board.get_playable_cells()
	if playable.is_empty():
		return "No playable cells"

	var cell: int = playable[randi() % playable.size()]
	return place_move(cell)


func run_full_game(max_turns: int = 200) -> String:
	start_round()
	for i in max_turns:
		if game_over:
			return ""

		var err = play_random_move()
		if err != "":
			return "Turn %d: %s" % [i, err]

		if draw_occurred:
			err = handle_draw()
			if err != "":
				return "Turn %d handle_draw: %s" % [i, err]

	if not game_over:
		return "Game did not finish within %d turns" % max_turns

	return ""
