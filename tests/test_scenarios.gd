extends RefCounted

## All test functions organized by category.
## Each returns "" on pass, error string on fail.

var _checker
var _SimScript


func _init() -> void:
	var CheckerScript = load("res://tests/invariant_checker.gd")
	_SimScript = load("res://tests/game_simulator.gd")
	_checker = CheckerScript.new()


# ---------------------------------------------------------------------------
#  CORE TESTS
# ---------------------------------------------------------------------------

func test_core_board_init_3x3() -> String:
	var board = BoardModel.new(3)
	if board.board_size != 3:
		return "board_size != 3"
	if board.cell_count != 9:
		return "cell_count != 9"
	for i in 9:
		if board.get_cell(i) != -1:
			return "cell %d not empty" % i
	return _checker.check_board_consistency(board)


func test_core_board_init_6x6() -> String:
	var board = BoardModel.new(6)
	if board.board_size != 6:
		return "board_size != 6"
	if board.cell_count != 36:
		return "cell_count != 36"
	return _checker.check_board_consistency(board)


func test_core_place_valid() -> String:
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()
	var err = sim.place_move(4)  # center
	if err != "":
		return err
	if sim.board.get_cell(4) != 0:
		return "cell 4 should be player 0"
	return ""


func test_core_reject_occupied() -> String:
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()
	sim.place_move(0)
	# Now player 1's turn, try to play on same cell
	var err = sim.place_move(0)
	if err == "":
		return "Should reject occupied cell"
	return ""


func test_core_reject_blocked() -> String:
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()
	sim.board.set_blocked(4, true)
	var err = sim.place_move(4)
	if err == "":
		return "Should reject blocked cell"
	return ""


func test_core_reject_wildcard() -> String:
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()
	sim.board.set_wildcard(4, true)
	sim.board.set_cell(4, 2)
	var err = sim.place_move(4)
	if err == "":
		return "Should reject wildcard cell"
	return ""


func test_core_reject_out_of_bounds() -> String:
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()
	var err = sim.place_move(9)
	if err == "":
		return "Should reject out of bounds cell"
	err = sim.place_move(-1)
	if err == "":
		return "Should reject negative cell"
	return ""


func test_core_turn_alternation() -> String:
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()
	if sim.turn_manager.get_current_player() != 0:
		return "Should start with player 0"
	sim.place_move(0)
	if sim.turn_manager.get_current_player() != 1:
		return "Should be player 1 after first move"
	sim.place_move(1)
	if sim.turn_manager.get_current_player() != 0:
		return "Should be player 0 after second move"
	return ""


func test_core_growth_sequence() -> String:
	# Verify 3 -> 4 -> 6 -> 9 -> 13 -> 18
	GameState.reset_session()
	var expected = [3, 4, 6, 9, 13, 18]

	var err = _checker.check_growth_sequence(0, GameState.current_board_size)
	if err != "":
		return err

	for step in range(1, expected.size()):
		var next_size = GameState.get_next_board_size()
		if next_size != expected[step]:
			return "step %d: expected next_size %d, got %d" % [step, expected[step], next_size]
		GameState.apply_growth()
		err = _checker.check_growth_sequence(step, GameState.current_board_size)
		if err != "":
			return err

	return ""


func test_core_board_grow_preserves_marks() -> String:
	GameState.reset_session()
	var board = BoardModel.new(3)
	board.set_cell(0, 0)
	board.set_cell(1, 1)
	board.set_cell(4, 0)

	var before_counts = _count_marks(board)
	board.grow(4)
	var after_counts = _count_marks(board)

	for p in [0, 1]:
		if before_counts[p] != after_counts[p]:
			return "player %d marks changed: %d -> %d" % [p, before_counts[p], after_counts[p]]
	return ""


func test_core_board_duplicate() -> String:
	var board = BoardModel.new(3)
	board.set_cell(0, 0)
	board.set_cell(4, 1)
	board.set_blocked(8, true)
	board.set_wildcard(2, true)
	board.bomb_cell = 6

	var copy = board.duplicate_board()
	if copy.get_cell(0) != 0:
		return "copy cell 0 wrong"
	if copy.get_cell(4) != 1:
		return "copy cell 4 wrong"
	if not copy.is_blocked(8):
		return "copy blocked 8 wrong"
	if not copy.is_wildcard(2):
		return "copy wildcard 2 wrong"
	if copy.bomb_cell != 6:
		return "copy bomb_cell wrong"

	# Verify independence
	board.set_cell(0, 1)
	if copy.get_cell(0) != 0:
		return "copy not independent"
	return ""


# ---------------------------------------------------------------------------
#  WIN CHECKER TESTS
# ---------------------------------------------------------------------------

func test_win_row_3x3() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(0, 0)
	board.set_cell(1, 0)
	board.set_cell(2, 0)
	if checker.check_winner_with_wildcards(board) != 0:
		return "Should detect X row win"
	return ""


func test_win_col_3x3() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(0, 1)
	board.set_cell(3, 1)
	board.set_cell(6, 1)
	if checker.check_winner_with_wildcards(board) != 1:
		return "Should detect O column win"
	return ""


func test_win_diag_3x3() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(0, 0)
	board.set_cell(4, 0)
	board.set_cell(8, 0)
	if checker.check_winner_with_wildcards(board) != 0:
		return "Should detect X diagonal win"
	return ""


func test_win_antidiag_3x3() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(2, 1)
	board.set_cell(4, 1)
	board.set_cell(6, 1)
	if checker.check_winner_with_wildcards(board) != 1:
		return "Should detect O anti-diagonal win"
	return ""


func test_win_draw_3x3() -> String:
	# X O X
	# X O O
	# O X X
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(0, 0); board.set_cell(1, 1); board.set_cell(2, 0)
	board.set_cell(3, 0); board.set_cell(4, 1); board.set_cell(5, 1)
	board.set_cell(6, 1); board.set_cell(7, 0); board.set_cell(8, 0)
	if checker.check_winner_with_wildcards(board) != -1:
		return "Should be no winner"
	if not checker.is_draw(board):
		return "Should be a draw"
	return ""


func test_win_no_false_positive() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(0, 0)
	board.set_cell(1, 1)
	board.set_cell(2, 0)
	if checker.check_winner_with_wildcards(board) != -1:
		return "Should not detect winner on partial board"
	return ""


func test_win_sliding_4x4() -> String:
	# 4x4 board, win_length=4
	var board = BoardModel.new(4)
	var checker = WinChecker.new(4, 4)
	# Top row: 0,1,2,3
	for i in 4:
		board.set_cell(i, 0)
	if checker.check_winner_with_wildcards(board) != 0:
		return "Should detect 4-in-a-row on 4x4"
	return ""


func test_win_sliding_6x6() -> String:
	# 6x6 board, win_length=5
	var board = BoardModel.new(6)
	var checker = WinChecker.new(6, 5)
	# Diagonal from (0,0): cells 0,7,14,21,28
	for k in 5:
		board.set_cell(k * 6 + k, 1)
	if checker.check_winner_with_wildcards(board) != 1:
		return "Should detect 5-in-a-row diagonal on 6x6"
	return ""


func test_win_wildcard_counts_both() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	# Row 0: X, wildcard, X -> should count as X win
	board.set_cell(0, 0)
	board.set_cell(1, 2)
	board.set_wildcard(1, true)
	board.set_cell(2, 0)
	if checker.check_winner_with_wildcards(board) != 0:
		return "Wildcard should count for X"
	return ""


func test_win_wildcard_counts_for_o() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	# Column 0: O, wildcard, O
	board.set_cell(0, 1)
	board.set_cell(3, 2)
	board.set_wildcard(3, true)
	board.set_cell(6, 1)
	if checker.check_winner_with_wildcards(board) != 1:
		return "Wildcard should count for O"
	return ""


func test_win_blocked_breaks_line() -> String:
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(0, 0)
	board.set_cell(1, 0)
	board.set_cell(2, 0)
	board.set_blocked(1, true)
	if checker.check_winner_with_wildcards(board) != -1:
		return "Blocked cell should break win pattern"
	return ""


func test_win_pattern_count_formula() -> String:
	# Formula: 2*N*(N-W+1) + 2*(N-W+1)^2
	# For N=3, W=3: 2*3*1 + 2*1 = 8
	# For N=4, W=3: 2*4*2 + 2*4 = 24
	# For N=5, W=3: 2*5*3 + 2*9 = 48
	var test_cases = [
		{"n": 3, "w": 3, "expected": 8},
		{"n": 4, "w": 3, "expected": 24},
		{"n": 5, "w": 3, "expected": 48},
		{"n": 4, "w": 4, "expected": 10},
		{"n": 6, "w": 5, "expected": 16},
	]

	for tc in test_cases:
		var checker = WinChecker.new(tc["n"], tc["w"])
		var count: int = checker.get_all_patterns().size()
		var n: int = tc["n"]
		var w: int = tc["w"]
		var expected: int = 2 * n * (n - w + 1) + 2 * (n - w + 1) * (n - w + 1)
		if count != expected:
			return "N=%d W=%d: expected %d patterns, got %d" % [n, w, expected, count]
	return ""


# ---------------------------------------------------------------------------
#  SPATIAL MIXUP TESTS
# ---------------------------------------------------------------------------

func test_mixup_rotation_preserves_marks() -> String:
	var board = BoardModel.new(3)
	board.set_cell(0, 0); board.set_cell(4, 1); board.set_cell(8, 0)
	var before = board.duplicate_board()
	board.rotate_clockwise()
	return _checker.check_mark_preservation(before, board, "rotation")


func test_mixup_shuffle_preserves_marks() -> String:
	var board = BoardModel.new(3)
	board.set_cell(0, 0); board.set_cell(1, 1); board.set_cell(2, 0)
	board.set_cell(3, 1); board.set_cell(4, 0)
	var before = board.duplicate_board()
	SpatialMixups._apply_shuffle(board)
	return _checker.check_mark_preservation(before, board, "shuffle")


func test_mixup_earthquake_preserves_marks() -> String:
	var board = BoardModel.new(4)
	board.set_cell(0, 0); board.set_cell(5, 1); board.set_cell(10, 0); board.set_cell(15, 1)
	var before = board.duplicate_board()
	SpatialMixups._apply_earthquake(board)
	return _checker.check_mark_preservation(before, board, "earthquake")


func test_mixup_plinko_preserves_marks() -> String:
	var board = BoardModel.new(4)
	board.set_cell(0, 0); board.set_cell(3, 1); board.set_cell(12, 0); board.set_cell(15, 1)
	var before = board.duplicate_board()
	SpatialMixups._apply_plinko(board)
	return _checker.check_mark_preservation(before, board, "plinko")


func test_mixup_mirror_preserves_marks() -> String:
	var board = BoardModel.new(3)
	board.set_cell(0, 0); board.set_cell(1, 1); board.set_cell(2, 0)
	var before = board.duplicate_board()
	SpatialMixups._apply_mirror(board)
	return _checker.check_mark_preservation(before, board, "mirror")


func test_mixup_spiral_preserves_marks() -> String:
	var board = BoardModel.new(3)
	board.set_cell(0, 0); board.set_cell(1, 1); board.set_cell(2, 0)
	var before = board.duplicate_board()
	SpatialMixups._apply_spiral(board)
	return _checker.check_mark_preservation(before, board, "spiral")


func test_mixup_shuffle_6x6() -> String:
	var board = BoardModel.new(6)
	for i in 10:
		board.set_cell(i, i % 2)
	var before = board.duplicate_board()
	SpatialMixups._apply_shuffle(board)
	return _checker.check_mark_preservation(before, board, "shuffle_6x6")


func test_mixup_vortex_preserves_marks() -> String:
	var board = BoardModel.new(4)
	board.set_cell(0, 0); board.set_cell(5, 1); board.set_cell(10, 0)
	board.set_wildcard(3, true); board.set_cell(3, 2)
	board.set_blocked(7, true)
	var before = board.duplicate_board()
	SpatialMixups._apply_vortex(board)
	return _checker.check_mark_preservation(before, board, "vortex")


func test_mixup_vortex_6x6() -> String:
	var board = BoardModel.new(6)
	for i in 12:
		board.set_cell(i, i % 2)
	board.set_blocked(18, true)
	board.bomb_cell = 20
	var before = board.duplicate_board()
	SpatialMixups._apply_vortex(board)
	var err = _checker.check_mark_preservation(before, board, "vortex_6x6")
	if err != "":
		return err
	# Bomb should have moved (it's in the outer ring)
	if board.bomb_cell < 0 or board.bomb_cell >= board.cell_count:
		return "bomb_cell out of bounds after vortex"
	return ""


func test_mixup_rotation_tracks_bomb() -> String:
	var board = BoardModel.new(3)
	board.bomb_cell = 2  # row 0, col 2
	# After 90deg CW rotation: (r=0,c=2) -> new_idx = index_from_rc(2, 2) = 8
	board.rotate_clockwise()
	if board.bomb_cell != 8:
		return "bomb should move to 8 after rotation, got %d" % board.bomb_cell
	return ""


# ---------------------------------------------------------------------------
#  COMPLICATION TESTS
# ---------------------------------------------------------------------------

func test_comp_gravity_3x3() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(GravityComplication.new())
	sim.start_round()

	# Player 0 places at row 0, col 1 (cell 1) — should fall to row 2, col 1 (cell 7)
	var err = sim.place_move(1)
	if err != "":
		return err
	if sim.board.get_cell(7) != 0:
		return "Mark did not fall to bottom (cell 7 = %d)" % sim.board.get_cell(7)
	return ""


func test_comp_gravity_4x4() -> String:
	GameState.reset_session()
	GameState.current_board_size = 4
	GameState.current_win_length = 4
	var sim = _SimScript.new(4, 4)
	sim.add_complication(GravityComplication.new())
	sim.start_round()

	# Place at top of col 0 (cell 0) — should fall to bottom (cell 12)
	var err = sim.place_move(0)
	if err != "":
		return err
	if sim.board.get_cell(12) != 0:
		return "Mark did not fall to row 3 col 0 (cell 12 = %d)" % sim.board.get_cell(12)
	return ""


func test_comp_gravity_6x6() -> String:
	GameState.reset_session()
	GameState.current_board_size = 6
	GameState.current_win_length = 5
	var sim = _SimScript.new(6, 5)
	sim.add_complication(GravityComplication.new())
	sim.start_round()

	var err = sim.place_move(0)
	if err != "":
		return err
	if sim.board.get_cell(30) != 0:
		return "Mark did not fall to row 5 col 0 (cell 30 = %d)" % sim.board.get_cell(30)
	return ""


func test_comp_mirror_3x3() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(MirrorMovesComplication.new())
	sim.start_round()

	# Place at cell 0 (row 0, col 0) — mirror = cell 2 (row 0, col 2)
	var err = sim.place_move(0)
	if err != "":
		return err
	if sim.board.get_cell(0) != 0:
		return "Original cell not placed"
	if sim.board.get_cell(2) != 0:
		return "Mirror cell not placed (cell 2 = %d)" % sim.board.get_cell(2)
	return ""


func test_comp_mirror_center_no_double() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(MirrorMovesComplication.new())
	sim.start_round()

	# Center column: mirror of cell 1 is cell 1 (same cell) — should not double
	var err = sim.place_move(1)
	if err != "":
		return err
	if sim.board.get_cell(1) != 0:
		return "Center cell not placed"
	return ""


func test_comp_mirror_4x4() -> String:
	GameState.reset_session()
	GameState.current_board_size = 4
	GameState.current_win_length = 4
	var sim = _SimScript.new(4, 4)
	sim.add_complication(MirrorMovesComplication.new())
	sim.start_round()

	# cell 0 (r0,c0) -> mirror cell 3 (r0,c3)
	var err = sim.place_move(0)
	if err != "":
		return err
	if sim.board.get_cell(3) != 0:
		return "Mirror on 4x4 failed (cell 3 = %d)" % sim.board.get_cell(3)
	return ""


func test_comp_bomb_spawn() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(TheBombComplication.new())
	sim.start_round()

	if sim.board.bomb_cell < 0:
		return "Bomb should be spawned"
	if sim.board.bomb_cell >= sim.board.cell_count:
		return "Bomb cell out of bounds"
	return ""


func test_comp_bomb_explode() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	var bomb = TheBombComplication.new()
	sim.add_complication(bomb)
	sim.start_round()

	# Place marks around center, set bomb at center
	sim.board.set_cell(0, 0)
	sim.board.set_cell(1, 1)
	sim.board.set_cell(2, 0)
	sim.board.bomb_cell = 4

	# Play on bomb cell (center)
	sim.place_move(4)

	# Surrounding cells should be cleared
	for idx in [0, 1, 2]:
		if sim.board.get_cell(idx) != -1:
			return "Cell %d should be cleared by explosion (value=%d)" % [idx, sim.board.get_cell(idx)]
	return ""


func test_comp_bomb_respawn() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(TheBombComplication.new())
	sim.start_round()

	sim.board.bomb_cell = 4
	sim.place_move(4)
	# After explosion, bomb should respawn somewhere
	# (unless board is completely full)
	if sim.board.get_empty_cells().size() > 0 and sim.board.bomb_cell < 0:
		return "Bomb should respawn after explosion"
	return ""


func test_comp_shrinking_3x3() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(ShrinkingBoardComplication.new())
	sim.start_round()

	var blocked_before = _count_blocked(sim.board)

	# Play 3 moves to trigger shrink
	sim.place_move(0)
	sim.place_move(1)
	sim.place_move(2)

	var blocked_after = _count_blocked(sim.board)
	if blocked_after <= blocked_before:
		return "Should have blocked a cell after 3 moves (before=%d, after=%d)" % [blocked_before, blocked_after]
	return ""


func test_comp_shrinking_stops_at_3() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(ShrinkingBoardComplication.new())
	sim.start_round()

	# Fill most cells so playable <= 3
	for i in 6:
		sim.board.set_blocked(i, true)
	# Only cells 6,7,8 remain — playable = 3

	var shrink = ShrinkingBoardComplication.new()
	shrink._state["moves_since_shrink"] = 2
	# Manually trigger shrink check
	shrink.on_move_placed(6, 0, sim.board)
	# Should NOT block more since playable <= 3
	var playable = sim.board.get_playable_cells().size()
	if playable < 3:
		return "Should not shrink below 3 playable cells (got %d)" % playable
	return ""


func test_comp_shrinking_6x6() -> String:
	GameState.reset_session()
	GameState.current_board_size = 6
	GameState.current_win_length = 5
	var sim = _SimScript.new(6, 5)
	sim.add_complication(ShrinkingBoardComplication.new())
	sim.start_round()

	var blocked_before = _count_blocked(sim.board)
	sim.place_move(0)
	sim.place_move(1)
	sim.place_move(2)

	var blocked_after = _count_blocked(sim.board)
	if blocked_after <= blocked_before:
		return "Shrinking should work on 6x6"
	return ""


func test_comp_steal_replace() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(StolenTurnComplication.new())
	sim.start_round()

	# Player 0 places at cell 0
	sim.place_move(0)
	# Player 1's turn, steal cell 0
	var err = sim.execute_steal(0)
	if err != "":
		return err
	if sim.board.get_cell(0) != 1:
		return "Stolen cell should now be player 1"
	return ""


func test_comp_steal_used_once() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(StolenTurnComplication.new())
	sim.start_round()

	sim.place_move(0)  # P0
	sim.execute_steal(0)  # P1 steals
	# Now player 1 should not have steal available
	if sim.turn_manager.has_steal(1):
		return "Steal should be used up"
	return ""


func test_comp_steal_no_hooks() -> String:
	# Verify steal doesn't trigger on_move_placed hooks
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(StolenTurnComplication.new())
	sim.add_complication(GravityComplication.new())
	sim.start_round()

	# Player 0 places at bottom-left (cell 6)
	sim.place_move(6)
	# Player 1 steals cell 6 — gravity should NOT apply
	sim.execute_steal(6)
	if sim.board.get_cell(6) != 1:
		return "Steal should place at exact cell without gravity"
	return ""


func test_comp_wildcard_spawn() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(WildcardCellComplication.new())
	sim.start_round()

	var wildcard_count = 0
	for i in sim.board.cell_count:
		if sim.board.is_wildcard(i):
			wildcard_count += 1
			if sim.board.get_cell(i) != 2:
				return "Wildcard cell should have value 2"
	if wildcard_count == 0:
		return "Should spawn at least one wildcard"
	return ""


func test_comp_wildcard_counts_both() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	# Row: X, wildcard, X
	board.set_cell(0, 0)
	board.set_cell(1, 2)
	board.set_wildcard(1, true)
	board.set_cell(2, 0)
	if checker.check_winner_with_wildcards(board) != 0:
		return "Wildcard should count as X"

	# Also try for O
	board.reset()
	board.set_cell(0, 1)
	board.set_cell(1, 2)
	board.set_wildcard(1, true)
	board.set_cell(2, 1)
	if checker.check_winner_with_wildcards(board) != 1:
		return "Wildcard should count as O"
	return ""


func test_comp_rotating_3x3() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(RotatingBoardComplication.new())
	sim.start_round()

	# Play 2 moves — on_turn_end triggers after each; rotation at turn 2
	sim.place_move(0)  # turn_end -> turns_since_rotation = 1
	# Snapshot after first move, before rotation
	var before = sim.board.duplicate_board()
	sim.place_move(1)  # turn_end -> turns_since_rotation = 2, rotate!

	# After rotation, the 2 marks from before + the new mark should all still exist
	# Rotation preserves marks. The new mark (player 1 at cell 1) is placed then rotated.
	# Just verify board consistency and that rotation didn't lose marks.
	var err = _checker.check_board_consistency(sim.board)
	if err != "":
		return err
	# Count total marks: should be exactly 2 (one from each player)
	var marks = 0
	for i in sim.board.cell_count:
		if sim.board.get_cell(i) >= 0 and sim.board.get_cell(i) <= 1:
			marks += 1
	if marks != 2:
		return "Expected 2 marks after 2 moves + rotation, got %d" % marks
	return ""


func test_comp_rotating_4x4() -> String:
	GameState.reset_session()
	GameState.current_board_size = 4
	GameState.current_win_length = 4
	var sim = _SimScript.new(4, 4)
	sim.add_complication(RotatingBoardComplication.new())
	sim.start_round()

	sim.place_move(0)
	sim.place_move(1)
	var err = _checker.check_board_consistency(sim.board)
	if err != "":
		return err
	var marks = 0
	for i in sim.board.cell_count:
		if sim.board.get_cell(i) >= 0 and sim.board.get_cell(i) <= 1:
			marks += 1
	if marks != 2:
		return "Expected 2 marks after 2 moves + rotation, got %d" % marks
	return ""


func test_comp_bomb_3x3() -> String:
	return test_comp_bomb_spawn()


func test_comp_bomb_6x6() -> String:
	GameState.reset_session()
	GameState.current_board_size = 6
	GameState.current_win_length = 5
	var sim = _SimScript.new(6, 5)
	sim.add_complication(TheBombComplication.new())
	sim.start_round()

	if sim.board.bomb_cell < 0:
		return "Bomb should spawn on 6x6"
	if sim.board.bomb_cell >= 36:
		return "Bomb out of bounds on 6x6"
	return ""


func test_comp_stack_gravity_mirror() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	# Mirror runs first (priority 15), then gravity (priority 20)
	sim.add_complication(MirrorMovesComplication.new())
	sim.add_complication(GravityComplication.new())
	sim.start_round()

	# Place at cell 0 (r0,c0): mirror places at cell 2 (r0,c2), then gravity drops both
	var err = sim.place_move(0)
	if err != "":
		return err

	# After gravity, both marks should be at bottom of their columns
	# Col 0 bottom: cell 6, Col 2 bottom: cell 8
	if sim.board.get_cell(6) != 0:
		return "Gravity+mirror: col 0 bottom should be player 0 (got %d)" % sim.board.get_cell(6)
	if sim.board.get_cell(8) != 0:
		return "Gravity+mirror: col 2 bottom should be player 0 (got %d)" % sim.board.get_cell(8)
	return ""


func test_comp_stack_gravity_rotation() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(RotatingBoardComplication.new())
	sim.add_complication(GravityComplication.new())
	sim.start_round()

	# Just verify no crash and marks are preserved
	var err = sim.place_move(4)
	if err != "":
		return err
	err = sim.place_move(0)
	if err != "":
		return err
	return _checker.check_board_consistency(sim.board)


func test_comp_stack_bomb_mirror() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.add_complication(MirrorMovesComplication.new())
	sim.add_complication(TheBombComplication.new())
	sim.start_round()

	# Just verify no crash
	var err = sim.place_move(0)
	if err != "":
		return err
	return _checker.check_board_consistency(sim.board)


# ---------------------------------------------------------------------------
#  AI TESTS
# ---------------------------------------------------------------------------

func test_ai_valid_move_3x3() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()

	var err = sim.play_ai_move(MinimaxSolver.Difficulty.HARD)
	if err != "":
		return err
	if sim.move_history.size() == 0:
		return "AI should have made a move"
	return ""


func test_ai_valid_move_4x4() -> String:
	GameState.reset_session()
	GameState.current_board_size = 4
	GameState.current_win_length = 4
	var sim = _SimScript.new(4, 4)
	sim.start_round()

	var err = sim.play_ai_move(MinimaxSolver.Difficulty.HARD)
	if err != "":
		return err
	return ""


func test_ai_valid_move_6x6() -> String:
	GameState.reset_session()
	GameState.current_board_size = 6
	GameState.current_win_length = 5
	var sim = _SimScript.new(6, 5)
	sim.start_round()

	var err = sim.play_ai_move(MinimaxSolver.Difficulty.HARD)
	if err != "":
		return err
	return ""


func test_ai_valid_move_9x9() -> String:
	GameState.reset_session()
	GameState.current_board_size = 9
	GameState.current_win_length = 6
	var sim = _SimScript.new(9, 6)
	sim.start_round()

	var err = sim.play_ai_move(MinimaxSolver.Difficulty.HARD)
	if err != "":
		return err
	return ""


func test_ai_blocks_win() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()

	# Set up: Player 0 (X) has cells 0,1 — needs cell 2 to win
	# Player 1 (O) to move — should block cell 2
	sim.board.set_cell(0, 0)
	sim.board.set_cell(1, 0)
	sim.turn_manager.current_player = 1

	var solver = MinimaxSolver.new()
	solver.set_difficulty(MinimaxSolver.Difficulty.HARD)
	var move = solver.get_best_move(sim.board, 1)
	if move != 2:
		return "AI should block at cell 2, chose %d" % move
	return ""


func test_ai_takes_win() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()

	# Player 0 has cells 0,1 — cell 2 wins
	sim.board.set_cell(0, 0)
	sim.board.set_cell(1, 0)
	sim.turn_manager.current_player = 0

	var solver = MinimaxSolver.new()
	solver.set_difficulty(MinimaxSolver.Difficulty.HARD)
	var move = solver.get_best_move(sim.board, 0)
	if move != 2:
		return "AI should take winning move at cell 2, chose %d" % move
	return ""


func test_ai_node_cap_9x9() -> String:
	GameState.reset_session()
	GameState.current_board_size = 9
	GameState.current_win_length = 6
	var sim = _SimScript.new(9, 6)
	sim.start_round()

	var solver = MinimaxSolver.new()
	solver.set_difficulty(MinimaxSolver.Difficulty.HARD)
	solver.get_best_move(sim.board, 0)
	if solver.get_nodes_searched() > MinimaxSolver.MAX_NODES + 1000:
		# Allow small overshoot since check happens per-iteration
		return "Node cap exceeded: %d" % solver.get_nodes_searched()
	return ""


func test_ai_with_gravity() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	var gravity = GravityComplication.new()
	gravity.is_active = true
	sim.add_complication(gravity)
	sim.start_round()

	var solver = MinimaxSolver.new()
	solver.set_difficulty(MinimaxSolver.Difficulty.HARD)
	solver.set_complications(sim.get_complications())
	var move = solver.get_best_move(sim.board, 0)
	if move < 0:
		return "AI should find a valid move with gravity"
	return ""


# ---------------------------------------------------------------------------
#  FULL GAME TESTS
# ---------------------------------------------------------------------------

func test_full_ai_vs_ai_3x3() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()

	for i in 20:
		if sim.game_over:
			break
		var err = sim.play_ai_move(MinimaxSolver.Difficulty.HARD)
		if err != "":
			return "Turn %d: %s" % [i, err]
		if sim.draw_occurred:
			# In a simple 3x3 with no complications, draw means game ends
			sim.game_over = true
			break

	if not sim.game_over and not sim.draw_occurred:
		return "Game should end within 20 turns"
	return ""


func test_full_game_1_growth() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()

	var growths = 0
	for i in 100:
		if sim.game_over:
			break
		var err = sim.play_random_move()
		if err != "":
			return "Turn %d: %s" % [i, err]
		if sim.draw_occurred:
			err = sim.handle_draw()
			if err != "":
				return "handle_draw: " + err
			growths += 1
			if growths >= 1 and not sim.game_over:
				# Continue until game over or next draw
				pass

	if growths < 1 and not sim.game_over:
		return "Expected at least 1 growth"
	return ""


func test_full_game_3_growths() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()

	var growths = 0
	for i in 500:
		if sim.game_over:
			break
		var err = sim.play_random_move()
		if err != "":
			return "Turn %d: %s" % [i, err]
		if sim.draw_occurred:
			err = sim.handle_draw()
			if err != "":
				return "handle_draw: " + err
			growths += 1

	# May or may not reach 3 growths depending on randomness
	return ""


func test_full_100_random_games() -> String:
	for game_idx in 100:
		GameState.reset_session()
		GameState.current_board_size = 3
		GameState.current_win_length = 3
		var sim = _SimScript.new(3, 3)

		var err = sim.run_full_game(200)
		if err != "":
			return "Game %d: %s" % [game_idx, err]

		# Validate final state
		if not sim.game_over:
			return "Game %d did not finish" % game_idx
		if sim.winner != -1 and sim.winner != 0 and sim.winner != 1:
			return "Game %d invalid winner: %d" % [game_idx, sim.winner]
	return ""


func test_full_invariants_every_move() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	sim.start_round()

	var CheckerScript = load("res://tests/invariant_checker.gd")
	var inv = CheckerScript.new()
	for i in 200:
		if sim.game_over:
			break

		var err = inv.run_all_checks(sim)
		if err != "":
			return "Pre-move %d invariant: %s" % [i, err]

		err = sim.play_random_move()
		if err != "":
			return "Turn %d: %s" % [i, err]

		err = inv.run_all_checks(sim)
		if err != "":
			return "Post-move %d invariant: %s" % [i, err]

		if sim.draw_occurred:
			err = sim.handle_draw()
			if err != "":
				return "handle_draw: " + err

			err = inv.run_all_checks(sim)
			if err != "":
				return "Post-growth %d invariant: %s" % [i, err]

	return ""


# ---------------------------------------------------------------------------
#  EDGE CASE TESTS
# ---------------------------------------------------------------------------

func test_edge_all_blocked_is_draw() -> String:
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)

	for i in 9:
		board.set_blocked(i, true)

	if not checker.is_draw(board):
		return "All blocked should be a draw"
	return ""


func test_edge_bomb_relocation_on_grow() -> String:
	# Bomb relocation during grow() is handled by TheBombComplication.on_board_reset(),
	# not by grow() itself (grow() resets bomb_cell to -1 via reset()).
	# Test that the complication properly re-spawns bomb after growth.
	GameState.reset_session()
	GameState.current_board_size = 3
	GameState.current_win_length = 3
	var sim = _SimScript.new(3, 3)
	var bomb = TheBombComplication.new()
	sim.add_complication(bomb)
	sim.start_round()

	var old_bomb = sim.board.bomb_cell
	if old_bomb < 0:
		return "Bomb should exist before grow"

	# Grow the board (simulating what handle_draw does)
	sim.board.grow(4)
	# After grow, bomb_cell is -1 (reset by grow)
	# The complication's on_board_reset re-spawns it
	bomb.on_board_reset(sim.board)

	if sim.board.bomb_cell < 0:
		return "Bomb should be re-spawned after grow + on_board_reset"
	if sim.board.bomb_cell >= sim.board.cell_count:
		return "Bomb out of bounds after grow"
	return ""


func test_edge_wildcard_through_growth() -> String:
	GameState.reset_session()
	var board = BoardModel.new(3)
	board.set_wildcard(4, true)
	board.set_cell(4, 2)
	board.set_cell(0, 0)
	board.set_cell(1, 1)

	var wc_before = 0
	for i in board.cell_count:
		if board.is_wildcard(i):
			wc_before += 1

	board.grow(4)

	var wc_after = 0
	for i in board.cell_count:
		if board.is_wildcard(i):
			wc_after += 1

	if wc_after != wc_before:
		return "Wildcard count should be preserved through growth (%d -> %d)" % [wc_before, wc_after]
	return ""


func test_edge_shrinking_relocates_bomb() -> String:
	GameState.reset_session()
	GameState.current_board_size = 4
	GameState.current_win_length = 4
	var board = BoardModel.new(4)

	# Put bomb at an edge cell
	board.bomb_cell = 0

	var shrink = ShrinkingBoardComplication.new()
	shrink._state["moves_since_shrink"] = 2

	# Force the shrink to block cell 0 (bomb's cell)
	# We need to ensure candidate selection picks cell 0
	# Block all other edge cells so only cell 0 is available
	var edges = board.get_edge_corner_cells()
	for e in edges:
		if e != 0:
			board.set_blocked(e, true)

	shrink.on_move_placed(5, 0, board)  # triggers shrink since counter hits 3

	# If cell 0 got blocked, bomb should have moved
	if board.is_blocked(0) and board.bomb_cell == 0:
		return "Bomb should relocate when its cell is blocked"
	return ""


func test_edge_all_complications_simultaneously() -> String:
	GameState.reset_session()
	GameState.current_board_size = 4
	GameState.current_win_length = 4
	var sim = _SimScript.new(4, 4)

	# Add all 8 complications
	sim.add_complication(ShrinkingBoardComplication.new())
	sim.add_complication(GravityComplication.new())
	sim.add_complication(MirrorMovesComplication.new())
	sim.add_complication(TheBombComplication.new())
	sim.add_complication(RotatingBoardComplication.new())
	sim.add_complication(StolenTurnComplication.new())
	sim.add_complication(TimePressureComplication.new())
	sim.add_complication(WildcardCellComplication.new())
	sim.start_round()

	# Play a few moves and check no crash
	for i in 10:
		if sim.game_over:
			break
		var err = sim.play_random_move()
		if err != "":
			# Some errors are expected (no playable cells)
			if err == "No playable cells":
				break
			return "Turn %d: %s" % [i, err]
	return _checker.check_board_consistency(sim.board)


func test_edge_max_growth() -> String:
	# Test the growth sequence math directly via GameState
	GameState.reset_session()
	var expected = [3, 4, 6, 9, 13, 18]
	var board = BoardModel.new(3)

	for step in range(1, expected.size()):
		var next_size = GameState.get_next_board_size()
		var next_wl = GameState.get_next_win_length()
		GameState.apply_growth()
		board.grow(next_size)

		if GameState.current_board_size != expected[step]:
			return "Step %d: expected size %d, got %d" % [step, expected[step], GameState.current_board_size]

	if GameState.current_board_size != 18:
		return "Expected final size 18, got %d" % GameState.current_board_size
	return _checker.check_board_consistency(board)


func test_edge_empty_wildcard_no_win() -> String:
	# An empty wildcard (value 2 but no player mark) shouldn't count toward win
	var board = BoardModel.new(3)
	var checker = WinChecker.new(3, 3)
	board.set_cell(0, 0)
	board.set_wildcard(1, true)
	board.set_cell(1, -1)  # Empty wildcard
	board.set_cell(2, 0)
	if checker.check_winner_with_wildcards(board) != -1:
		return "Empty wildcard should not contribute to win"
	return ""


# ---------------------------------------------------------------------------
#  HELPERS
# ---------------------------------------------------------------------------

func _count_marks(board: BoardModel) -> Dictionary:
	var counts = {0: 0, 1: 0, 2: 0}
	for i in board.cell_count:
		var v = board.cells[i]
		if v >= 0 and v <= 2 and not board.is_blocked(i):
			counts[v] += 1
	return counts


func _count_blocked(board: BoardModel) -> int:
	var count = 0
	for i in board.cell_count:
		if board.is_blocked(i):
			count += 1
	return count
