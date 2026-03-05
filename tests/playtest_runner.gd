extends SceneTree

## Gameplay quality playtest system. Plays ~1,500 games across 48 complication
## configurations and outputs a structured gameplay quality report.
##
## Run via: godot --headless -s tests/playtest_runner.gd [--seed=N] [--quick]
##
## NOTE: This script avoids ALL class_name references (BoardModel, MinimaxSolver,
## ComplicationBase, etc.) because -s scripts are compiled before autoloads are
## registered. All game logic is delegated to game_simulator.gd (loaded at runtime)
## and autoloads are accessed via the scene tree.

var SimScript = null

# All 8 complication IDs
const ALL_COMP_IDS: Array = [
	"gravity", "mirror_moves", "the_bomb", "shrinking_board",
	"stolen_turn", "wildcard_cell", "rotating_board", "time_pressure",
	"decay", "aftershock", "chain_reaction", "infection",
]

# 48 configurations
var _configs: Array[Dictionary] = []

# Aggregate results
var _config_results: Array[Dictionary] = []

var _total_games_played: int = 0
var _quick_mode: bool = false
var _test_seed: int = 42
var _game_state = null  # GameState autoload (accessed at runtime)
var _comp_registry = null  # ComplicationRegistry autoload (accessed at runtime)


func _initialize() -> void:
	_test_seed = _parse_seed()
	_quick_mode = _parse_quick()
	seed(_test_seed)

	_game_state = root.get_node("GameState")
	_comp_registry = root.get_node("ComplicationRegistry")
	SimScript = load("res://tests/game_simulator.gd")

	_build_configs()

	var config_count := _configs.size()
	var estimated_games := _estimate_total_games()
	print("[PLAYTEST_BEGIN]")
	print("Seed: %d | %d configs | ~%d games%s" % [
		_test_seed, config_count, estimated_games,
		" (quick mode)" if _quick_mode else ""
	])
	print("")

	for i in _configs.size():
		var cfg = _configs[i]
		var start := Time.get_ticks_msec()
		var result = _run_config(cfg)
		var elapsed := Time.get_ticks_msec() - start

		_config_results.append(result)

		var label = cfg["label"] if cfg["label"] != "" else "(vanilla)"
		var counts = result["matchup_counts"]
		print("[PROGRESS] %d/%d [%s] RvR:%d HvR:%d HvH:%d (%dms)" % [
			i + 1, config_count, label,
			counts.get("RvR", 0), counts.get("HvR", 0), counts.get("HvH", 0),
			elapsed
		])

	print("")
	_print_per_config_analysis()
	_print_rankings()
	_print_summary()
	print("[PLAYTEST_END]")
	quit()


# ---------------------------------------------------------------------------
# CLI parsing
# ---------------------------------------------------------------------------

func _parse_seed() -> int:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--seed="):
			return int(arg.substr(7))
	return 42


func _parse_quick() -> bool:
	for arg in OS.get_cmdline_args():
		if arg == "--quick":
			return true
	return false


# ---------------------------------------------------------------------------
# Configuration builder
# ---------------------------------------------------------------------------

func _build_configs() -> void:
	# Baseline
	_add_config([])

	# Solos (8)
	for id in ALL_COMP_IDS:
		_add_config([id])

	# Pairs (16) — chosen for known hook interactions
	var pairs: Array = [
		["gravity", "mirror_moves"],
		["gravity", "the_bomb"],
		["gravity", "shrinking_board"],
		["gravity", "rotating_board"],
		["gravity", "stolen_turn"],
		["mirror_moves", "the_bomb"],
		["mirror_moves", "shrinking_board"],
		["mirror_moves", "rotating_board"],
		["mirror_moves", "wildcard_cell"],
		["the_bomb", "shrinking_board"],
		["the_bomb", "rotating_board"],
		["the_bomb", "stolen_turn"],
		["shrinking_board", "rotating_board"],
		["shrinking_board", "wildcard_cell"],
		["stolen_turn", "wildcard_cell"],
		["rotating_board", "wildcard_cell"],
		["decay", "the_bomb"],
		["decay", "rotating_board"],
		["aftershock", "the_bomb"],
		["aftershock", "stolen_turn"],
		["chain_reaction", "the_bomb"],
		["chain_reaction", "gravity"],
		["chain_reaction", "mirror_moves"],
		["decay", "chain_reaction"],
		["infection", "the_bomb"],
		["infection", "rotating_board"],
		["infection", "chain_reaction"],
		["infection", "mirror_moves"],
		["infection", "gravity"],
	]
	for pair in pairs:
		_add_config(pair)

	# Triples (15)
	var triples: Array = [
		["gravity", "mirror_moves", "the_bomb"],
		["gravity", "mirror_moves", "rotating_board"],
		["gravity", "the_bomb", "shrinking_board"],
		["gravity", "the_bomb", "rotating_board"],
		["gravity", "shrinking_board", "stolen_turn"],
		["gravity", "rotating_board", "wildcard_cell"],
		["mirror_moves", "the_bomb", "shrinking_board"],
		["mirror_moves", "the_bomb", "rotating_board"],
		["mirror_moves", "shrinking_board", "wildcard_cell"],
		["mirror_moves", "rotating_board", "stolen_turn"],
		["the_bomb", "shrinking_board", "rotating_board"],
		["the_bomb", "shrinking_board", "wildcard_cell"],
		["the_bomb", "stolen_turn", "rotating_board"],
		["shrinking_board", "rotating_board", "wildcard_cell"],
		["stolen_turn", "wildcard_cell", "rotating_board"],
		["decay", "aftershock", "the_bomb"],
		["infection", "the_bomb", "rotating_board"],
		["infection", "chain_reaction", "the_bomb"],
	]
	for triple in triples:
		_add_config(triple)

	# Quads (6)
	var quads: Array = [
		["gravity", "mirror_moves", "the_bomb", "shrinking_board"],
		["gravity", "mirror_moves", "the_bomb", "rotating_board"],
		["gravity", "the_bomb", "shrinking_board", "stolen_turn"],
		["mirror_moves", "the_bomb", "rotating_board", "wildcard_cell"],
		["gravity", "shrinking_board", "rotating_board", "wildcard_cell"],
		["mirror_moves", "shrinking_board", "stolen_turn", "wildcard_cell"],
	]
	for quad in quads:
		_add_config(quad)

	# Extremes (2)
	var all_minus_time: Array = []
	for id in ALL_COMP_IDS:
		if id != "time_pressure":
			all_minus_time.append(id)
	_add_config(all_minus_time)
	_add_config(ALL_COMP_IDS.duplicate())


func _add_config(comp_ids: Array) -> void:
	var label := "+".join(PackedStringArray(comp_ids)) if comp_ids.size() > 0 else ""
	_configs.append({"comp_ids": comp_ids, "label": label})


func _estimate_total_games() -> int:
	var total := 0
	for cfg in _configs:
		var counts = _get_game_counts(cfg["comp_ids"].size())
		total += counts[0] + counts[1] + counts[2]
	return total


func _get_game_counts(num_comps: int) -> Array:
	# Returns [RvR, HvR, HvH] game counts
	if _quick_mode:
		return [3, 1, 1]

	if num_comps <= 2:
		return [20, 10, 5]
	elif num_comps <= 4:
		return [15, 5, 3]
	else:
		return [10, 3, 2]


func _get_ai_difficulty() -> int:
	# In quick mode use MEDIUM (1) for faster minimax; full mode uses HARD (2)
	return 1 if _quick_mode else 2


# ---------------------------------------------------------------------------
# Config runner
# ---------------------------------------------------------------------------

func _run_config(cfg: Dictionary) -> Dictionary:
	var comp_ids: Array = cfg["comp_ids"]
	var counts = _get_game_counts(comp_ids.size())

	var all_games: Array[Dictionary] = []
	var matchup_counts := {}

	var ai_max_turns := 100 if _quick_mode else 200

	# RvR: Random vs Random
	var rvr_games = _play_matchup(comp_ids, "random", "random", counts[0], 500)
	all_games.append_array(rvr_games)
	matchup_counts["RvR"] = rvr_games.size()

	# HvR: Hard AI vs Random
	var hvr_games = _play_matchup(comp_ids, "hard", "random", counts[1], ai_max_turns)
	all_games.append_array(hvr_games)
	matchup_counts["HvR"] = hvr_games.size()

	# HvH: Hard AI vs Hard AI
	var hvh_games = _play_matchup(comp_ids, "hard", "hard", counts[2], ai_max_turns)
	all_games.append_array(hvh_games)
	matchup_counts["HvH"] = hvh_games.size()

	_total_games_played += all_games.size()

	# Compute aggregates
	return _aggregate_config(cfg, all_games, matchup_counts, rvr_games, hvr_games, hvh_games)


func _play_matchup(comp_ids: Array, p0_type: String, p1_type: String, count: int, max_turns: int) -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	for _i in count:
		var metrics = _play_single_game(comp_ids, p0_type, p1_type, max_turns)
		games.append(metrics)
	return games


func _play_single_game(comp_ids: Array, p0_type: String, p1_type: String, max_turns: int) -> Dictionary:
	# Reset global state via runtime autoload reference
	_game_state.reset_session()
	_game_state.current_board_size = 3
	_game_state.current_win_length = 3

	var sim = SimScript.new()

	# Add initial complications via ComplicationRegistry (runtime autoload)
	for id in comp_ids:
		var comp = _comp_registry._create_fresh(id)
		if comp != null:
			sim.add_complication(comp)

	sim.start_round()

	# Metrics tracking
	var total_turns := 0
	var draw_count := 0
	var max_board_size := 3
	var board_sizes: Array[int] = [3]
	var wasted_moves := 0
	var bomb_explosions := 0
	var cells_destroyed_by_bomb := 0
	var steals_used := 0
	var shrinks_occurred := 0
	var rotations_occurred := 0
	var mirror_placements := 0
	var game_over_reason := "max_turns"

	# Track rotation state for detection
	var prev_rotation_turns := 0

	for turn_idx in max_turns:
		if sim.game_over:
			break

		# Snapshot mark count before move
		var marks_before := _count_marks(sim.board)

		# Determine current player type
		var current_player = sim.turn_manager.get_current_player()
		var player_type = p0_type if current_player == 0 else p1_type

		# Play move using configured AI difficulty
		var err := ""
		if player_type == "hard":
			err = sim.play_ai_move(_get_ai_difficulty())
		else:
			err = sim.play_random_move()

		if err != "":
			# Graceful handling — treat as end condition
			if err == "No playable cells" or err == "AI found no valid move":
				game_over_reason = "stalemate"
				sim.game_over = true
				break
			# Other error — still end the game
			game_over_reason = "error"
			sim.game_over = true
			break

		total_turns += 1

		# Snapshot mark count after move
		var marks_after := _count_marks(sim.board)

		# Detect mirror placement (mark count increased by more than 1)
		var mark_delta = marks_after - marks_before
		if mark_delta > 1:
			mirror_placements += mark_delta - 1

		# Detect bomb explosion (marks decreased or stayed same despite placing)
		if marks_after < marks_before:
			bomb_explosions += 1
			cells_destroyed_by_bomb += marks_before - marks_after + 1  # +1 for the placed mark that triggered it

		# Detect wasted moves (marks destroyed — either by bomb, shrinking, etc.)
		if marks_after < marks_before:
			wasted_moves += marks_before - marks_after + 1

		# Detect rotation via complication state
		for comp in sim.get_complications():
			if comp.complication_id == "rotating_board":
				var cur_rot = comp._state.get("turns_since_rotation", 0)
				if cur_rot == 0 and prev_rotation_turns > 0:
					rotations_occurred += 1
				prev_rotation_turns = cur_rot

		# Check for draw and handle growth
		if sim.draw_occurred:
			draw_count += 1
			err = sim.handle_draw()
			if err != "":
				game_over_reason = "stalemate"
				sim.game_over = true
				break
			max_board_size = maxi(max_board_size, sim.board.board_size)
			board_sizes.append(sim.board.board_size)
			prev_rotation_turns = 0  # Reset after board growth

		# Check winner
		if sim.game_over and sim.winner >= 0:
			game_over_reason = "win"
		elif sim.game_over:
			game_over_reason = "stalemate"

	# Detect shrinks by counting blocked cells (rough proxy)
	for comp in sim.get_complications():
		if comp.complication_id == "shrinking_board":
			var blocked_count := 0
			for i in sim.board.cell_count:
				if sim.board.is_blocked(i):
					blocked_count += 1
			shrinks_occurred = blocked_count

	# Detect steals used via move_history
	steals_used = 0
	for entry in sim.move_history:
		if entry.get("type", "") == "steal":
			steals_used += 1

	return {
		"total_turns": total_turns,
		"draw_count": draw_count,
		"winner": sim.winner,
		"max_board_size": max_board_size,
		"board_sizes_reached": board_sizes,
		"wasted_moves": wasted_moves,
		"bomb_explosions": bomb_explosions,
		"cells_destroyed_by_bomb": cells_destroyed_by_bomb,
		"steals_used": steals_used,
		"shrinks_occurred": shrinks_occurred,
		"rotations_occurred": rotations_occurred,
		"mirror_placements": mirror_placements,
		"game_over_reason": game_over_reason,
	}


func _count_marks(board) -> int:
	var count := 0
	for i in board.cell_count:
		if board.cells[i] == 0 or board.cells[i] == 1:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

func _aggregate_config(cfg: Dictionary, all_games: Array[Dictionary], matchup_counts: Dictionary,
		rvr_games: Array[Dictionary], hvr_games: Array[Dictionary], hvh_games: Array[Dictionary]) -> Dictionary:

	var label: String = cfg["label"] if cfg["label"] != "" else "(vanilla)"
	var has_time_pressure: bool = "time_pressure" in cfg["comp_ids"]

	# Per-matchup stats
	var rvr_stats = _compute_matchup_stats(rvr_games)
	var hvr_stats = _compute_matchup_stats(hvr_games)
	var hvh_stats = _compute_matchup_stats(hvh_games)

	# Overall stats from all games
	var overall = _compute_matchup_stats(all_games)

	# Composite scores
	var decisiveness = _compute_decisiveness(all_games)
	var chaos = _compute_chaos(all_games)
	var fun_score = _compute_fun_score(all_games, overall)

	return {
		"config_id": label,
		"comp_ids": cfg["comp_ids"],
		"has_time_pressure": has_time_pressure,
		"matchup_counts": matchup_counts,
		"total_games": all_games.size(),
		"RvR": rvr_stats,
		"HvR": hvr_stats,
		"HvH": hvh_stats,
		"overall": overall,
		"decisiveness": snapped(decisiveness, 0.001),
		"chaos": snapped(chaos, 0.01),
		"fun_score": snapped(fun_score, 0.01),
	}


func _compute_matchup_stats(games: Array[Dictionary]) -> Dictionary:
	if games.is_empty():
		return {}

	var wins := 0
	var p0_wins := 0
	var p1_wins := 0
	var stalemates := 0
	var total_turns := 0
	var total_draws := 0
	var total_max_board := 0
	var total_wasted := 0
	var total_bomb := 0
	var total_bomb_cells := 0
	var total_steals := 0
	var total_shrinks := 0
	var total_rotations := 0
	var total_mirrors := 0

	for g in games:
		total_turns += g["total_turns"]
		total_draws += g["draw_count"]
		total_max_board += g["max_board_size"]
		total_wasted += g["wasted_moves"]
		total_bomb += g["bomb_explosions"]
		total_bomb_cells += g["cells_destroyed_by_bomb"]
		total_steals += g["steals_used"]
		total_shrinks += g["shrinks_occurred"]
		total_rotations += g["rotations_occurred"]
		total_mirrors += g["mirror_placements"]

		if g["winner"] == 0:
			wins += 1
			p0_wins += 1
		elif g["winner"] == 1:
			wins += 1
			p1_wins += 1
		else:
			stalemates += 1

	var n := float(games.size())
	return {
		"games": games.size(),
		"win_rate": snapped(wins / n, 0.001),
		"p0_win_rate": snapped(p0_wins / n, 0.001),
		"p1_win_rate": snapped(p1_wins / n, 0.001),
		"stalemate_rate": snapped(stalemates / n, 0.001),
		"avg_turns": snapped(total_turns / n, 0.1),
		"avg_draws": snapped(total_draws / n, 0.1),
		"avg_max_board": snapped(total_max_board / n, 0.1),
		"avg_wasted_moves": snapped(total_wasted / n, 0.1),
		"avg_bomb_explosions": snapped(total_bomb / n, 0.1),
		"avg_cells_bombed": snapped(total_bomb_cells / n, 0.1),
		"avg_steals": snapped(total_steals / n, 0.1),
		"avg_shrinks": snapped(total_shrinks / n, 0.1),
		"avg_rotations": snapped(total_rotations / n, 0.1),
		"avg_mirrors": snapped(total_mirrors / n, 0.1),
	}


func _compute_decisiveness(games: Array[Dictionary]) -> float:
	if games.is_empty():
		return 0.0

	var n := float(games.size())
	var wins := 0
	var quick_wins := 0  # Winner found within <= 2 draws

	for g in games:
		if g["winner"] >= 0:
			wins += 1
			if g["draw_count"] <= 2:
				quick_wins += 1

	var win_ratio := wins / n
	var quick_ratio := quick_wins / n
	return win_ratio * 0.6 + quick_ratio * 0.4


func _compute_chaos(games: Array[Dictionary]) -> float:
	if games.is_empty():
		return 0.0

	var total_chaos := 0.0
	for g in games:
		total_chaos += g["wasted_moves"] * 2.0
		total_chaos += g["bomb_explosions"] * 3.0
		total_chaos += g["rotations_occurred"] * 1.0
		total_chaos += g["shrinks_occurred"] * 1.5
		total_chaos += g["steals_used"] * 2.0

	return total_chaos / float(games.size())


func _compute_fun_score(games: Array[Dictionary], overall_stats: Dictionary) -> float:
	if games.is_empty():
		return 0.0

	var total_fun := 0.0

	for g in games:
		var score := 0.0

		# +3 for clear winner
		if g["winner"] >= 0:
			score += 3.0

		# +2 for 1-3 board growths
		if g["draw_count"] >= 1 and g["draw_count"] <= 3:
			score += 2.0

		# +2 for moderate game length (10-30 turns)
		if g["total_turns"] >= 10 and g["total_turns"] <= 30:
			score += 2.0

		# +1.5 for some mark destruction (1-6 wasted moves)
		if g["wasted_moves"] >= 1 and g["wasted_moves"] <= 6:
			score += 1.5

		# +1 for not ending in stalemate
		if g["game_over_reason"] != "stalemate" and g["game_over_reason"] != "max_turns":
			score += 1.0

		total_fun += score

	var avg_fun := total_fun / float(games.size())

	# +0.5 bonus for balanced win rates (p0 and p1 each near 50%)
	var p0_rate: float = overall_stats.get("p0_win_rate", 0.0)
	var p1_rate: float = overall_stats.get("p1_win_rate", 0.0)
	if maxf(p0_rate, p1_rate) > 0:
		var balance := minf(p0_rate, p1_rate) / maxf(p0_rate, p1_rate)
		avg_fun += balance * 0.5

	return clampf(avg_fun, 0.0, 10.0)


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

func _print_per_config_analysis() -> void:
	for result in _config_results:
		print("[ANALYSIS_CONFIG_BEGIN]")
		var output := {
			"config_id": result["config_id"],
			"comp_ids": result["comp_ids"],
			"has_time_pressure": result["has_time_pressure"],
			"total_games": result["total_games"],
			"decisiveness": result["decisiveness"],
			"chaos": result["chaos"],
			"fun_score": result["fun_score"],
			"RvR": result["RvR"],
			"HvR": result["HvR"],
			"HvH": result["HvH"],
		}
		print(JSON.stringify(output, "  "))
		print("[ANALYSIS_CONFIG_END]")
	print("")


func _print_rankings() -> void:
	print("[ANALYSIS_RANKINGS_BEGIN]")

	var by_fun = _config_results.duplicate()
	by_fun.sort_custom(func(a, b): return a["fun_score"] > b["fun_score"])

	var by_decisive = _config_results.duplicate()
	by_decisive.sort_custom(func(a, b): return a["decisiveness"] > b["decisiveness"])

	var by_chaos = _config_results.duplicate()
	by_chaos.sort_custom(func(a, b): return a["chaos"] > b["chaos"])

	var by_drawn_out = _config_results.duplicate()
	by_drawn_out.sort_custom(func(a, b):
		return a["overall"].get("avg_draws", 0) > b["overall"].get("avg_draws", 0)
	)

	# Most balanced: closest to 50/50 win rate in RvR
	var by_balanced = _config_results.duplicate()
	by_balanced.sort_custom(func(a, b):
		var a_rvr = a.get("RvR", {})
		var b_rvr = b.get("RvR", {})
		var a_diff = absf(a_rvr.get("p0_win_rate", 0.0) - a_rvr.get("p1_win_rate", 0.0))
		var b_diff = absf(b_rvr.get("p0_win_rate", 0.0) - b_rvr.get("p1_win_rate", 0.0))
		return a_diff < b_diff
	)

	# First player advantage: biggest p0 vs p1 gap in RvR
	var by_p1_advantage = _config_results.duplicate()
	by_p1_advantage.sort_custom(func(a, b):
		var a_rvr = a.get("RvR", {})
		var b_rvr = b.get("RvR", {})
		var a_gap = a_rvr.get("p0_win_rate", 0.0) - a_rvr.get("p1_win_rate", 0.0)
		var b_gap = b_rvr.get("p0_win_rate", 0.0) - b_rvr.get("p1_win_rate", 0.0)
		return a_gap > b_gap
	)

	var rankings := {
		"highest_fun": _top_n_labels(by_fun, 10),
		"most_decisive": _top_n_labels(by_decisive, 10),
		"most_chaotic": _top_n_labels(by_chaos, 10),
		"most_drawn_out": _top_n_labels(by_drawn_out, 10),
		"most_balanced": _top_n_labels(by_balanced, 10),
		"first_player_advantage": _top_n_labels(by_p1_advantage, 10),
	}

	print(JSON.stringify(rankings, "  "))
	print("[ANALYSIS_RANKINGS_END]")
	print("")


func _top_n_labels(sorted_results: Array, n: int) -> Array:
	var result: Array = []
	for i in mini(n, sorted_results.size()):
		var r = sorted_results[i]
		result.append({
			"config": r["config_id"],
			"fun": r["fun_score"],
			"decisiveness": r["decisiveness"],
			"chaos": r["chaos"],
			"avg_turns": r["overall"].get("avg_turns", 0),
			"avg_draws": r["overall"].get("avg_draws", 0),
		})
	return result


func _print_summary() -> void:
	print("[ANALYSIS_SUMMARY_BEGIN]")

	var by_fun = _config_results.duplicate()
	by_fun.sort_custom(func(a, b): return a["fun_score"] > b["fun_score"])

	var recommended: Array = []
	var avoid: Array = []

	for r in by_fun:
		if recommended.size() >= 5:
			break
		if not r["has_time_pressure"] or r["comp_ids"].size() > 1:
			recommended.append({
				"config": r["config_id"],
				"fun_score": r["fun_score"],
				"decisiveness": r["decisiveness"],
				"chaos": r["chaos"],
			})

	# Avoid: bottom 5 by fun score
	by_fun.reverse()
	for r in by_fun:
		if avoid.size() >= 5:
			break
		avoid.append({
			"config": r["config_id"],
			"fun_score": r["fun_score"],
			"stalemate_rate": r["overall"].get("stalemate_rate", 0),
		})

	var summary := {
		"total_games_played": _total_games_played,
		"total_configs": _configs.size(),
		"seed": _test_seed,
		"recommended_combos": recommended,
		"avoid_combos": avoid,
	}

	print(JSON.stringify(summary, "  "))
	print("[ANALYSIS_SUMMARY_END]")
