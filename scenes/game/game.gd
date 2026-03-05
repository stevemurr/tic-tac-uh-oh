extends Control

enum State {
	IDLE,
	RESETTING_BOARD,
	PLAYER_TURN,
	ANIMATING_MOVE,
	CHECKING_RESULT,
	ANNOUNCING_COMPLICATION,
	GAME_OVER,
}

var _state: State = State.IDLE
var _board_model: BoardModel
var _win_checker: WinChecker
var _move_validator: MoveValidator
var _turn_manager: TurnManager
var _minimax: MinimaxSolver
var _timer: Timer
var _animator: BoardAnimator

@onready var board: Control = $Board
@onready var hud: Control = $CanvasLayer/HUD
@onready var announcement: Control = $CanvasLayer/ComplicationAnnouncement
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen

func _ready() -> void:
	_board_model = BoardModel.new(GameState.current_board_size)
	_win_checker = WinChecker.new(GameState.current_board_size, GameState.current_win_length)
	_move_validator = MoveValidator.new()
	_turn_manager = TurnManager.new()
	_minimax = MinimaxSolver.new()

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	# Setup animator
	_animator = BoardAnimator.new()
	_animator.name = "BoardAnimator"
	add_child(_animator)
	_animator.setup(board)

	board.cell_pressed.connect(_on_cell_pressed)

	if announcement:
		announcement.visible = false
	if game_over_screen:
		game_over_screen.visible = false
		game_over_screen.play_again_pressed.connect(restart_game)
		game_over_screen.menu_pressed.connect(return_to_menu)

	_start_new_round()

func get_board_model() -> BoardModel:
	return _board_model

func _start_new_round() -> void:
	GameState.round_number += 1
	_board_model.reset()
	_turn_manager.reset()

	# Apply complications to new board
	var sorted_comps: Array[ComplicationBase] = GameState.get_active_complications_sorted()
	for comp in sorted_comps:
		comp.on_board_reset(_board_model)
		comp.on_game_start(_board_model)

	# Grant steals if stolen turn is active
	for comp in sorted_comps:
		if comp.complication_id == "stolen_turn":
			_turn_manager.grant_steal(0)
			_turn_manager.grant_steal(1)

	# Rebuild visual board for current size
	board.rebuild_for_size(GameState.current_board_size)
	board.sync_from_model(_board_model)

	# Apply ambient effects for active complications
	_animator.apply_ambient_effects(_board_model, GameState.active_complications)

	_change_state(State.PLAYER_TURN)

func _grow_board_and_continue() -> void:
	var old_size := GameState.current_board_size

	# Grow the board
	var new_size := GameState.get_next_board_size()
	var new_win_length := GameState.get_next_win_length()
	GameState.apply_growth()

	# Snapshot before growth for animation
	_animator.take_snapshot(_board_model)

	# Grow the board model (redistributes existing marks)
	_board_model.grow(new_size)

	# Rebuild visual board first so we can animate
	board.rebuild_for_size(new_size)
	board.sync_from_model(_board_model)

	# Animate growth
	await _animator.animate_growth(old_size, new_size)

	# Snapshot before mixup
	_animator.take_snapshot(_board_model)

	# Apply spatial mixup
	var mixup_name: String = SpatialMixups.apply_random(_board_model)
	GameEvents.spatial_mixup_applied.emit(mixup_name)

	# Sync visual state after mixup
	board.sync_from_model(_board_model)

	# Animate the mixup
	await _animator.animate_mixup(mixup_name, _board_model)

	# Regenerate win patterns
	_win_checker.generate_patterns(new_size, new_win_length)

	GameEvents.board_grown.emit(new_size, new_win_length)

	# Reset turns but keep marks
	_turn_manager.reset()

	# Run complication hooks on the grown board
	var sorted_comps: Array[ComplicationBase] = GameState.get_active_complications_sorted()
	for comp in sorted_comps:
		comp.on_board_reset(_board_model)
		comp.on_game_start(_board_model)

	# Grant steals if stolen turn is active
	for comp in sorted_comps:
		if comp.complication_id == "stolen_turn":
			_turn_manager.grant_steal(0)
			_turn_manager.grant_steal(1)

	# Sync again after complication hooks may have changed state
	board.sync_from_model(_board_model)

	# Apply ambient effects
	_animator.apply_ambient_effects(_board_model, GameState.active_complications)

	_change_state(State.PLAYER_TURN)

func _change_state(new_state: State) -> void:
	_state = new_state

	match new_state:
		State.PLAYER_TURN:
			_on_enter_player_turn()
		State.CHECKING_RESULT:
			_on_enter_checking_result()
		State.ANNOUNCING_COMPLICATION:
			_on_enter_announcing_complication()
		State.GAME_OVER:
			_on_enter_game_over()

func _on_enter_player_turn() -> void:
	var player := _turn_manager.get_current_player()

	# Run turn start hooks
	var sorted_comps: Array[ComplicationBase] = GameState.get_active_complications_sorted()
	for comp in sorted_comps:
		if comp.is_active:
			comp.on_turn_start(player, _board_model)

	board.sync_from_model(_board_model)
	_update_hud()

	# Apply ambient effects
	_animator.apply_ambient_effects(_board_model, GameState.active_complications)

	GameEvents.turn_started.emit(player)

	# Start timer if time pressure is active
	_start_timer_if_needed(player)

	# If AI's turn
	if GameState.game_mode == GameState.GameMode.VS_AI and player == 1:
		board.set_cells_disabled(true)
		_request_ai_move()
	else:
		board.set_cells_disabled(false)

func _start_timer_if_needed(player: int) -> void:
	if GameState.game_mode == GameState.GameMode.VS_AI and player == 1:
		return  # No timer for AI

	var time_limit: float = GameState.DEFAULT_TURN_TIME
	for comp in GameState.active_complications:
		if comp is TimePressureComplication and comp.is_active:
			time_limit = comp.get_time_limit()
			break
	_timer.start(time_limit)

func _on_timer_timeout() -> void:
	if _state != State.PLAYER_TURN:
		return

	# Timeout shake animation
	await _animator.animate_timeout()

	# Make a random valid move
	var player := _turn_manager.get_current_player()
	var moves := _board_model.get_playable_cells()
	if moves.is_empty():
		return
	var random_move: int = moves[randi() % moves.size()]
	_execute_move(random_move, player)

func _on_cell_pressed(index: int) -> void:
	if _state != State.PLAYER_TURN:
		return

	var player := _turn_manager.get_current_player()

	# Check if this is a steal attempt (clicking opponent's mark with steal available)
	if _turn_manager.has_steal(player) and _board_model.get_cell(index) == 1 - player:
		_execute_steal(index, player)
		return

	_execute_move(index, player)

func _execute_move(cell: int, player: int) -> void:
	var sorted_comps: Array[ComplicationBase] = GameState.get_active_complications_sorted()
	var result := _move_validator.validate_move(cell, player, _board_model, sorted_comps)

	if not result.is_valid:
		return

	_timer.stop()

	# Snapshot before move for complication animations
	_animator.take_snapshot(_board_model)

	_board_model.set_cell(cell, player)

	_change_state(State.ANIMATING_MOVE)

	# Snapshot before complications to detect changes
	var pre_comp_cells := _board_model.cells.duplicate()

	# Run on_move_placed hooks in priority order
	for comp in sorted_comps:
		if comp.is_active:
			comp.on_move_placed(cell, player, _board_model)

	board.sync_from_model(_board_model)

	# Animate mark placement
	await _animator.animate_place(cell, player)

	# Animate complication effects by comparing pre/post states
	await _animate_complication_effects(cell, player, sorted_comps, pre_comp_cells)

	GameEvents.move_placed.emit(cell, player)

	_change_state(State.CHECKING_RESULT)

func _animate_complication_effects(cell: int, player: int, comps: Array[ComplicationBase], pre_cells: Array[int]) -> void:
	for comp in comps:
		if not comp.is_active:
			continue
		match comp.complication_id:
			"gravity":
				await _animator.animate_gravity(_board_model)
			"mirror_moves":
				var mirror_idx := _board_model.get_mirror_index(cell)
				if mirror_idx != cell and pre_cells[mirror_idx] == -1 and _board_model.get_cell(mirror_idx) == player:
					await _animator.animate_mirror(mirror_idx, _board_model)
			"the_bomb":
				if pre_cells[cell] != -1 or _board_model.bomb_cell != -1:
					# Check if bomb exploded (bomb was at cell before the move)
					var bomb_was_here := false
					for i in pre_cells.size():
						if i == cell:
							# The bomb_cell is tracked on the model, check if explosion happened
							# by looking for cleared surrounding cells
							pass
					# Detect explosion: surrounding cells were cleared
					var surrounding := _board_model.get_surrounding_cells(cell)
					var any_cleared := false
					for idx in surrounding:
						if idx < pre_cells.size() and pre_cells[idx] != -1 and _board_model.get_cell(idx) == -1:
							any_cleared = true
							break
					if any_cleared:
						var cleared: Array[int] = []
						for idx in surrounding:
							if idx < pre_cells.size() and pre_cells[idx] != -1 and _board_model.get_cell(idx) == -1:
								cleared.append(idx)
						await _animator.animate_bomb_explode(cell, cleared)
				# Re-apply bomb ambient to new bomb position
				_animator.apply_bomb_ambient(_board_model.bomb_cell)
			"shrinking_board":
				# Detect newly blocked cells
				for i in _board_model.cell_count:
					if not _board_model.blocked_cells[i]:
						continue
					if i < pre_cells.size() and not _animator._snapshot_blocked[i]:
						await _animator.animate_shrink(i)
			"chain_reaction":
				# Detect removed cells
				var removed: Array[int] = []
				for i in _board_model.cell_count:
					if i < pre_cells.size() and pre_cells[i] != -1 and _board_model.get_cell(i) == -1 and not _board_model.is_blocked(i):
						removed.append(i)
				if removed.size() > 0:
					await _animator.animate_chain_reaction(cell, removed)
			"infection":
				# Detect converted cells
				var converted: Array[int] = []
				for i in _board_model.cell_count:
					if i < pre_cells.size() and i != cell and pre_cells[i] == 1 - player and _board_model.get_cell(i) == player:
						converted.append(i)
				if converted.size() > 0:
					await _animator.animate_infection(cell, converted, player)

	# Refresh ambient effects after complications
	_animator.apply_ambient_effects(_board_model, GameState.active_complications)

func _execute_steal(cell: int, player: int) -> void:
	if not _turn_manager.has_steal(player):
		return

	# Validate steal
	var result := MoveResult.new()
	result.cell = cell
	result.player = player
	result.is_steal = true
	result.is_valid = true

	var sorted_comps: Array[ComplicationBase] = GameState.get_active_complications_sorted()
	for comp in sorted_comps:
		if comp.is_active:
			comp.on_validate_move(result, cell, player, _board_model)
			if not result.is_valid:
				return

	_timer.stop()
	_turn_manager.use_steal(player)
	_board_model.set_cell(cell, player)

	# Steal is replacement -- NO side effect hooks trigger
	board.sync_from_model(_board_model)

	# Animate steal
	await _animator.animate_steal(cell, player)

	GameEvents.move_placed.emit(cell, player)

	_change_state(State.CHECKING_RESULT)

func _on_enter_checking_result() -> void:
	var sorted_comps: Array[ComplicationBase] = GameState.get_active_complications_sorted()

	# Run on_check_win hooks
	for comp in sorted_comps:
		if comp.is_active:
			comp.on_check_win(_board_model, _win_checker)

	# Check for winner
	var winner := _win_checker.check_winner_with_wildcards(_board_model)

	if winner != -1:
		GameState.scores[winner] += 1
		_change_state(State.GAME_OVER)
		GameEvents.game_over.emit(winner)
		return

	# Check for draw
	if _win_checker.is_draw(_board_model):
		GameState.draw_count += 1
		GameEvents.draw_occurred.emit()

		if GameState.all_complications_used():
			# Ultimate stalemate!
			_change_state(State.GAME_OVER)
			GameEvents.game_over.emit(-1)
			return

		_change_state(State.ANNOUNCING_COMPLICATION)
		return

	# Continue play -- run turn end hooks
	var player := _turn_manager.get_current_player()

	# Snapshot before turn end for rotation/aftershock detection
	_animator.take_snapshot(_board_model)
	var pre_turn_end_cells := _board_model.cells.duplicate()

	for comp in sorted_comps:
		if comp.is_active:
			comp.on_turn_end(player, _board_model, _turn_manager)

	board.sync_from_model(_board_model)

	# Animate turn-end complication effects
	await _animate_turn_end_effects(sorted_comps, pre_turn_end_cells)

	_turn_manager.advance_turn()
	_change_state(State.PLAYER_TURN)

func _animate_turn_end_effects(comps: Array[ComplicationBase], pre_cells: Array[int]) -> void:
	for comp in comps:
		if not comp.is_active:
			continue
		match comp.complication_id:
			"rotating_board":
				# Check if rotation happened (cells changed)
				var rotated := false
				for i in _board_model.cell_count:
					if i < pre_cells.size() and pre_cells[i] != _board_model.get_cell(i):
						rotated = true
						break
				if rotated:
					await _animator.animate_board_rotation()
					board.sync_from_model(_board_model)
			"aftershock":
				# Check if mixup happened
				var changed := false
				for i in _board_model.cell_count:
					if i < pre_cells.size() and pre_cells[i] != _board_model.get_cell(i):
						changed = true
						break
				if changed:
					await _animator.animate_aftershock_warning()
					board.sync_from_model(_board_model)
			"decay":
				# Check for removed marks
				for i in _board_model.cell_count:
					if i < pre_cells.size() and pre_cells[i] != -1 and _board_model.get_cell(i) == -1 and not _board_model.is_blocked(i):
						await _animator.animate_decay_remove(i)
				board.sync_from_model(_board_model)

func _on_enter_announcing_complication() -> void:
	var active_ids: Array[String] = []
	for comp in GameState.active_complications:
		active_ids.append(comp.complication_id)

	var new_comp := ComplicationRegistry.pick_random(active_ids)
	if new_comp == null:
		# No more complications available
		_change_state(State.GAME_OVER)
		GameEvents.game_over.emit(-1)
		return

	GameState.add_complication(new_comp)
	GameEvents.complication_added.emit(new_comp)

	# Show announcement
	if announcement:
		announcement.show_complication(new_comp)
		announcement.visible = true
		await announcement.announcement_finished
		announcement.visible = false
	else:
		await get_tree().create_timer(1.5).timeout

	# Grow board and continue instead of full reset
	_grow_board_and_continue()

func _on_enter_game_over() -> void:
	board.set_cells_disabled(true)
	_timer.stop()
	_animator.reset_grid_effects()

	# Animate win line if there's a winner
	var winner := -1
	if GameState.scores[0] > GameState.scores[1]:
		winner = 0
	elif GameState.scores[1] > GameState.scores[0]:
		winner = 1

	if winner >= 0:
		var winning_cells := _win_checker.get_winning_pattern(_board_model, winner)
		if winning_cells.size() > 0:
			var typed_cells: Array[int] = []
			for c in winning_cells:
				typed_cells.append(c)
			await _animator.animate_win_line(typed_cells, winner)

	if game_over_screen:
		game_over_screen.show_results()
		game_over_screen.visible = true

func _request_ai_move() -> void:
	var player := _turn_manager.get_current_player()
	_minimax.set_complications(GameState.active_complications)

	match GameState.difficulty:
		GameState.Difficulty.EASY:
			_minimax.set_difficulty(MinimaxSolver.Difficulty.EASY)
		GameState.Difficulty.MEDIUM:
			_minimax.set_difficulty(MinimaxSolver.Difficulty.MEDIUM)
		GameState.Difficulty.HARD:
			_minimax.set_difficulty(MinimaxSolver.Difficulty.HARD)

	# Small delay so AI doesn't feel instant
	await get_tree().create_timer(0.4).timeout

	var best_move := _minimax.get_best_move(_board_model, player)
	if best_move >= 0:
		_execute_move(best_move, player)

func _update_hud() -> void:
	if hud:
		hud.update_turn(_turn_manager.get_current_player())
		hud.update_scores(GameState.scores)
		hud.update_complications(GameState.active_complications)
		hud.update_steal_available(
			_turn_manager.has_steal(0),
			_turn_manager.has_steal(1)
		)
		hud.update_round(GameState.round_number)
		hud.update_board_info(GameState.current_board_size, GameState.current_win_length)

func _process(delta: float) -> void:
	if _state == State.PLAYER_TURN and not _timer.is_stopped():
		var time_left := _timer.time_left
		GameEvents.timer_updated.emit(time_left)
		if hud:
			hud.update_timer(time_left, _timer.wait_time)
		# Animate time pressure effects
		_animator.animate_time_pressure(time_left)

func restart_game() -> void:
	GameState.reset_session()
	_board_model = BoardModel.new(GameState.current_board_size)
	_win_checker = WinChecker.new(GameState.current_board_size, GameState.current_win_length)
	_start_new_round()

func return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
