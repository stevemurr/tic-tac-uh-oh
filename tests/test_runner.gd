extends SceneTree

## Headless test runner. Run via: godot --headless -s tests/test_runner.gd
## Accepts --seed=N CLI arg for reproducible randomness (default: 42).
##
## Uses load() instead of preload() so that test scripts are compiled AFTER
## autoloads (GameState, ComplicationRegistry) are registered as globals.

var _results: Array[Dictionary] = []
var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0


func _initialize() -> void:
	var test_seed := _parse_seed()
	seed(test_seed)
	print("[INFO] Test seed: %d" % test_seed)

	var ScenariosScript = load("res://tests/test_scenarios.gd")
	var scenarios = ScenariosScript.new()
	var tests = _collect_tests(scenarios)

	for test in tests:
		_run_test(test["name"], test["callable"])

	_print_summary()
	_print_json()
	quit()


func _parse_seed() -> int:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--seed="):
			return int(arg.substr(7))
	return 42


func _collect_tests(s) -> Array[Dictionary]:
	var tests: Array[Dictionary] = []

	# Core
	tests.append({"name": "core/board_init_3x3", "callable": s.test_core_board_init_3x3})
	tests.append({"name": "core/board_init_6x6", "callable": s.test_core_board_init_6x6})
	tests.append({"name": "core/place_valid", "callable": s.test_core_place_valid})
	tests.append({"name": "core/reject_occupied", "callable": s.test_core_reject_occupied})
	tests.append({"name": "core/reject_blocked", "callable": s.test_core_reject_blocked})
	tests.append({"name": "core/reject_wildcard", "callable": s.test_core_reject_wildcard})
	tests.append({"name": "core/reject_out_of_bounds", "callable": s.test_core_reject_out_of_bounds})
	tests.append({"name": "core/turn_alternation", "callable": s.test_core_turn_alternation})
	tests.append({"name": "core/growth_sequence", "callable": s.test_core_growth_sequence})
	tests.append({"name": "core/board_grow_preserves_marks", "callable": s.test_core_board_grow_preserves_marks})
	tests.append({"name": "core/board_duplicate", "callable": s.test_core_board_duplicate})

	# Win Checker
	tests.append({"name": "win/row_3x3", "callable": s.test_win_row_3x3})
	tests.append({"name": "win/col_3x3", "callable": s.test_win_col_3x3})
	tests.append({"name": "win/diag_3x3", "callable": s.test_win_diag_3x3})
	tests.append({"name": "win/antidiag_3x3", "callable": s.test_win_antidiag_3x3})
	tests.append({"name": "win/draw_3x3", "callable": s.test_win_draw_3x3})
	tests.append({"name": "win/no_false_positive", "callable": s.test_win_no_false_positive})
	tests.append({"name": "win/sliding_4x4", "callable": s.test_win_sliding_4x4})
	tests.append({"name": "win/sliding_6x6", "callable": s.test_win_sliding_6x6})
	tests.append({"name": "win/wildcard_counts_both", "callable": s.test_win_wildcard_counts_both})
	tests.append({"name": "win/wildcard_counts_for_o", "callable": s.test_win_wildcard_counts_for_o})
	tests.append({"name": "win/blocked_breaks_line", "callable": s.test_win_blocked_breaks_line})
	tests.append({"name": "win/pattern_count_formula", "callable": s.test_win_pattern_count_formula})

	# Spatial Mixups
	tests.append({"name": "mixup/rotation_preserves_marks", "callable": s.test_mixup_rotation_preserves_marks})
	tests.append({"name": "mixup/shuffle_preserves_marks", "callable": s.test_mixup_shuffle_preserves_marks})
	tests.append({"name": "mixup/earthquake_preserves_marks", "callable": s.test_mixup_earthquake_preserves_marks})
	tests.append({"name": "mixup/plinko_preserves_marks", "callable": s.test_mixup_plinko_preserves_marks})
	tests.append({"name": "mixup/mirror_preserves_marks", "callable": s.test_mixup_mirror_preserves_marks})
	tests.append({"name": "mixup/spiral_preserves_marks", "callable": s.test_mixup_spiral_preserves_marks})
	tests.append({"name": "mixup/shuffle_6x6", "callable": s.test_mixup_shuffle_6x6})
	tests.append({"name": "mixup/vortex_preserves_marks", "callable": s.test_mixup_vortex_preserves_marks})
	tests.append({"name": "mixup/vortex_6x6", "callable": s.test_mixup_vortex_6x6})
	tests.append({"name": "mixup/rotation_tracks_bomb", "callable": s.test_mixup_rotation_tracks_bomb})

	# Complications
	tests.append({"name": "comp/gravity_3x3", "callable": s.test_comp_gravity_3x3})
	tests.append({"name": "comp/gravity_4x4", "callable": s.test_comp_gravity_4x4})
	tests.append({"name": "comp/gravity_6x6", "callable": s.test_comp_gravity_6x6})
	tests.append({"name": "comp/mirror_3x3", "callable": s.test_comp_mirror_3x3})
	tests.append({"name": "comp/mirror_center_no_double", "callable": s.test_comp_mirror_center_no_double})
	tests.append({"name": "comp/mirror_4x4", "callable": s.test_comp_mirror_4x4})
	tests.append({"name": "comp/bomb_spawn", "callable": s.test_comp_bomb_spawn})
	tests.append({"name": "comp/bomb_explode", "callable": s.test_comp_bomb_explode})
	tests.append({"name": "comp/bomb_respawn", "callable": s.test_comp_bomb_respawn})
	tests.append({"name": "comp/shrinking_3x3", "callable": s.test_comp_shrinking_3x3})
	tests.append({"name": "comp/shrinking_stops_at_3", "callable": s.test_comp_shrinking_stops_at_3})
	tests.append({"name": "comp/shrinking_6x6", "callable": s.test_comp_shrinking_6x6})
	tests.append({"name": "comp/steal_replace", "callable": s.test_comp_steal_replace})
	tests.append({"name": "comp/steal_used_once", "callable": s.test_comp_steal_used_once})
	tests.append({"name": "comp/steal_no_hooks", "callable": s.test_comp_steal_no_hooks})
	tests.append({"name": "comp/wildcard_spawn", "callable": s.test_comp_wildcard_spawn})
	tests.append({"name": "comp/wildcard_counts_both", "callable": s.test_comp_wildcard_counts_both})
	tests.append({"name": "comp/rotating_3x3", "callable": s.test_comp_rotating_3x3})
	tests.append({"name": "comp/rotating_4x4", "callable": s.test_comp_rotating_4x4})
	tests.append({"name": "comp/aftershock_prevents_one_move_win", "callable": s.test_comp_aftershock_prevents_one_move_win})
	tests.append({"name": "comp/bomb_3x3", "callable": s.test_comp_bomb_3x3})
	tests.append({"name": "comp/bomb_6x6", "callable": s.test_comp_bomb_6x6})
	tests.append({"name": "comp/stack_gravity_mirror", "callable": s.test_comp_stack_gravity_mirror})
	tests.append({"name": "comp/stack_gravity_rotation", "callable": s.test_comp_stack_gravity_rotation})
	tests.append({"name": "comp/stack_bomb_mirror", "callable": s.test_comp_stack_bomb_mirror})

	# AI
	tests.append({"name": "ai/valid_move_3x3", "callable": s.test_ai_valid_move_3x3})
	tests.append({"name": "ai/valid_move_4x4", "callable": s.test_ai_valid_move_4x4})
	tests.append({"name": "ai/valid_move_6x6", "callable": s.test_ai_valid_move_6x6})
	tests.append({"name": "ai/valid_move_9x9", "callable": s.test_ai_valid_move_9x9})
	tests.append({"name": "ai/blocks_win", "callable": s.test_ai_blocks_win})
	tests.append({"name": "ai/takes_win", "callable": s.test_ai_takes_win})
	tests.append({"name": "ai/node_cap_9x9", "callable": s.test_ai_node_cap_9x9})
	tests.append({"name": "ai/with_gravity", "callable": s.test_ai_with_gravity})

	# Full Game
	tests.append({"name": "full/ai_vs_ai_3x3", "callable": s.test_full_ai_vs_ai_3x3})
	tests.append({"name": "full/game_1_growth", "callable": s.test_full_game_1_growth})
	tests.append({"name": "full/game_3_growths", "callable": s.test_full_game_3_growths})
	tests.append({"name": "full/100_random_games", "callable": s.test_full_100_random_games})
	tests.append({"name": "full/invariants_every_move", "callable": s.test_full_invariants_every_move})

	# Edge Cases
	tests.append({"name": "edge/all_blocked_is_draw", "callable": s.test_edge_all_blocked_is_draw})
	tests.append({"name": "edge/bomb_relocation_on_grow", "callable": s.test_edge_bomb_relocation_on_grow})
	tests.append({"name": "edge/wildcard_through_growth", "callable": s.test_edge_wildcard_through_growth})
	tests.append({"name": "edge/shrinking_relocates_bomb", "callable": s.test_edge_shrinking_relocates_bomb})
	tests.append({"name": "edge/all_complications_simultaneously", "callable": s.test_edge_all_complications_simultaneously})
	tests.append({"name": "edge/max_growth", "callable": s.test_edge_max_growth})
	tests.append({"name": "edge/empty_wildcard_no_win", "callable": s.test_edge_empty_wildcard_no_win})
	tests.append({"name": "edge/post_growth_guard_prevents_one_move_win", "callable": s.test_edge_post_growth_guard_prevents_one_move_win})

	# Run Mode
	tests.append({"name": "run/start_new_run_initializes_state", "callable": s.test_run_start_new_run_initializes_state})
	tests.append({"name": "run/map_generation_unlocks_gate", "callable": s.test_run_map_generation_unlocks_gate})
	tests.append({"name": "run/battle_win_unlocks_rewards", "callable": s.test_run_battle_win_unlocks_rewards})
	tests.append({"name": "run/scene_resources_load", "callable": s.test_run_scene_resources_load})

	return tests


func _run_test(name: String, callable: Callable) -> void:
	var start := Time.get_ticks_msec()
	var error_msg: String = ""

	error_msg = callable.call()

	var elapsed := Time.get_ticks_msec() - start

	if error_msg == "" or error_msg == null:
		_passed += 1
		print("[PASS] %s (%dms)" % [name, elapsed])
		_results.append({"name": name, "status": "pass", "time_ms": elapsed})
	else:
		_failed += 1
		print("[FAIL] %s: %s (%dms)" % [name, error_msg, elapsed])
		_results.append({"name": name, "status": "fail", "reason": error_msg, "time_ms": elapsed})


func _print_summary() -> void:
	var total := _passed + _failed + _skipped
	print("[SUMMARY] %d passed, %d failed, %d skipped, %d total" % [_passed, _failed, _skipped, total])


func _print_json() -> void:
	print("[JSON_RESULTS_BEGIN]")
	print(JSON.stringify(_results, "  "))
	print("[JSON_RESULTS_END]")
