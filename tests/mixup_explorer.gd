extends SceneTree

## Spatial mixup benchmarking harness. Tests each mixup independently across
## multiple complication configurations and reports mixup-specific metrics.
##
## Run via: godot --headless -s tests/mixup_explorer.gd [--seed=N] [--quick]
##
## NOTE: Like playtest_runner.gd, this script avoids class_name references at
## compile time because -s scripts are compiled before autoloads are registered.

var SimScript = null

var _quick_mode: bool = false
var _test_seed: int = 42
var _game_state = null
var _comp_registry = null

# 7 mixup variants: baseline (no mixup) + 6 spatial mixups
var _mixup_variants: Array[String] = ["None", "Rotation", "Earthquake", "Shuffle", "Plinko", "Mirror", "Spiral", "Vortex"]

# 10 complication configs
var _comp_configs: Array[Dictionary] = []

# Results: keyed by mixup name -> config label -> metrics
var _all_results: Array[Dictionary] = []


func _initialize() -> void:
	_test_seed = _parse_seed()
	_quick_mode = _parse_quick()
	seed(_test_seed)

	_game_state = root.get_node("GameState")
	_comp_registry = root.get_node("ComplicationRegistry")
	SimScript = load("res://tests/game_simulator.gd")

	_build_comp_configs()

	var total_combos := _mixup_variants.size() * _comp_configs.size() * 3  # 3 matchups
	var games_per := 8 if _quick_mode else 20
	print("[MIXUP_EXPLORER_BEGIN]")
	print("Seed: %d | %d mixups x %d configs | ~%d games%s" % [
		_test_seed, _mixup_variants.size(), _comp_configs.size(),
		total_combos * games_per / 3,
		" (quick mode)" if _quick_mode else ""
	])
	print("")

	var config_idx := 0
	var total_configs := _mixup_variants.size() * _comp_configs.size()

	for mixup_name in _mixup_variants:
		for cfg in _comp_configs:
			config_idx += 1
			var start := Time.get_ticks_msec()
			var result = _run_mixup_config(mixup_name, cfg)
			var elapsed := Time.get_ticks_msec() - start
			_all_results.append(result)

			print("[PROGRESS] %d/%d [%s | %s] fun=%.2f displacement=%.2f pattern_survival=%.2f entropy=%.2f (%dms)" % [
				config_idx, total_configs,
				mixup_name, cfg["label"],
				result["fun_score"],
				result["avg_displacement"],
				result["avg_pattern_survival"],
				result["avg_spatial_entropy"],
				elapsed
			])

	print("")
	_print_mixup_analysis()
	_print_rankings()
	_print_gap_analysis()
	print("[MIXUP_EXPLORER_END]")
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
# Complication configs (10 total)
# ---------------------------------------------------------------------------

func _build_comp_configs() -> void:
	# Vanilla (no complications)
	_comp_configs.append({"comp_ids": [], "label": "(vanilla)"})

	# 4 solos
	_comp_configs.append({"comp_ids": ["gravity"], "label": "gravity"})
	_comp_configs.append({"comp_ids": ["the_bomb"], "label": "the_bomb"})
	_comp_configs.append({"comp_ids": ["rotating_board"], "label": "rotating_board"})
	_comp_configs.append({"comp_ids": ["mirror_moves"], "label": "mirror_moves"})

	# 4 pairs
	_comp_configs.append({"comp_ids": ["gravity", "the_bomb"], "label": "gravity+the_bomb"})
	_comp_configs.append({"comp_ids": ["gravity", "rotating_board"], "label": "gravity+rotating_board"})
	_comp_configs.append({"comp_ids": ["mirror_moves", "the_bomb"], "label": "mirror_moves+the_bomb"})
	_comp_configs.append({"comp_ids": ["the_bomb", "shrinking_board"], "label": "the_bomb+shrinking_board"})

	# 1 triple
	_comp_configs.append({"comp_ids": ["gravity", "mirror_moves", "the_bomb"], "label": "gravity+mirror_moves+the_bomb"})


# ---------------------------------------------------------------------------
# Config runner
# ---------------------------------------------------------------------------

func _run_mixup_config(mixup_name: String, cfg: Dictionary) -> Dictionary:
	var rvr_count := 8 if _quick_mode else 20
	var hvr_count := 4 if _quick_mode else 10
	var hvh_count := 4 if _quick_mode else 10

	var all_games: Array[Dictionary] = []

	# RvR
	var rvr_games = _play_matchup(mixup_name, cfg["comp_ids"], "random", "random", rvr_count, 500)
	all_games.append_array(rvr_games)

	# HvR
	var hvr_games = _play_matchup(mixup_name, cfg["comp_ids"], "hard", "random", hvr_count, 200)
	all_games.append_array(hvr_games)

	# HvH
	var hvh_games = _play_matchup(mixup_name, cfg["comp_ids"], "hard", "hard", hvh_count, 200)
	all_games.append_array(hvh_games)

	return _aggregate_results(mixup_name, cfg["label"], all_games)


func _play_matchup(mixup_name: String, comp_ids: Array, p0_type: String, p1_type: String, count: int, max_turns: int) -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	for _i in count:
		var metrics = _play_single_game(mixup_name, comp_ids, p0_type, p1_type, max_turns)
		games.append(metrics)
	return games


func _play_single_game(mixup_name: String, comp_ids: Array, p0_type: String, p1_type: String, max_turns: int) -> Dictionary:
	_game_state.reset_session()
	_game_state.current_board_size = 3
	_game_state.current_win_length = 3

	var sim = SimScript.new()
	sim.forced_mixup = mixup_name

	for id in comp_ids:
		var comp = _comp_registry._create_fresh(id)
		if comp != null:
			sim.add_complication(comp)

	sim.start_round()

	var total_turns := 0
	var draw_count := 0
	var wasted_moves := 0
	var game_over_reason := "max_turns"

	# Mixup-specific metrics (collected per growth event)
	var displacement_samples: Array[float] = []
	var pattern_survival_samples: Array[float] = []
	var entropy_samples: Array[float] = []

	var ai_diff := 1 if _quick_mode else 2  # MEDIUM vs HARD

	for turn_idx in max_turns:
		if sim.game_over:
			break

		var marks_before := _count_marks(sim.board)

		var current_player = sim.turn_manager.get_current_player()
		var player_type = p0_type if current_player == 0 else p1_type

		var err := ""
		if player_type == "hard":
			err = sim.play_ai_move(ai_diff)
		else:
			err = sim.play_random_move()

		if err != "":
			if err == "No playable cells" or err == "AI found no valid move":
				game_over_reason = "stalemate"
				sim.game_over = true
				break
			game_over_reason = "error"
			sim.game_over = true
			break

		total_turns += 1

		var marks_after := _count_marks(sim.board)
		if marks_after < marks_before:
			wasted_moves += marks_before - marks_after + 1

		if sim.draw_occurred:
			draw_count += 1

			# Snapshot board BEFORE growth+mixup for metrics
			var board_before = sim.board.duplicate_board()
			var win_checker_before = WinChecker.new(sim.board.board_size, _game_state.current_win_length)

			err = sim.handle_draw()
			if err != "":
				game_over_reason = "stalemate"
				sim.game_over = true
				break

			# Snapshot board AFTER growth+mixup for metrics
			var board_after = sim.board

			# Compute mixup-specific metrics
			var disp = _compute_displacement(board_before, board_after)
			displacement_samples.append(disp)

			var survival = _compute_pattern_survival(board_before, board_after, win_checker_before)
			pattern_survival_samples.append(survival)

			var ent = _compute_spatial_entropy(board_after)
			entropy_samples.append(ent)

		if sim.game_over and sim.winner >= 0:
			game_over_reason = "win"
		elif sim.game_over:
			game_over_reason = "stalemate"

	return {
		"total_turns": total_turns,
		"draw_count": draw_count,
		"winner": sim.winner,
		"wasted_moves": wasted_moves,
		"game_over_reason": game_over_reason,
		"displacement_samples": displacement_samples,
		"pattern_survival_samples": pattern_survival_samples,
		"entropy_samples": entropy_samples,
	}


# ---------------------------------------------------------------------------
# Mixup-specific metrics
# ---------------------------------------------------------------------------

## Mark displacement: how far marks moved (normalized by board size)
func _compute_displacement(before: BoardModel, after: BoardModel) -> float:
	# Collect mark positions before growth
	var before_positions: Dictionary = {}  # mark_key -> [row, col]
	for i in before.cell_count:
		var v = before.cells[i]
		if v >= 0 and v <= 1 and not before.is_blocked(i):
			var key := "%d_%d_%d" % [v, before.get_row(i), before.get_col(i)]
			before_positions[key] = Vector2(
				float(before.get_row(i)) / float(before.board_size),
				float(before.get_col(i)) / float(before.board_size)
			)

	# Collect mark positions after growth+mixup
	var after_positions: Dictionary = {}
	for i in after.cell_count:
		var v = after.cells[i]
		if v >= 0 and v <= 1 and not after.is_blocked(i):
			var key := "%d_%d_%d" % [v, after.get_row(i), after.get_col(i)]
			after_positions[key] = Vector2(
				float(after.get_row(i)) / float(after.board_size),
				float(after.get_col(i)) / float(after.board_size)
			)

	# Since board grew and marks were redistributed, we can't track individual marks.
	# Instead, measure the centroid displacement for each player.
	var total_displacement := 0.0
	var samples := 0

	for player in [0, 1]:
		var before_centroid := Vector2.ZERO
		var before_count := 0
		for i in before.cell_count:
			if before.cells[i] == player and not before.is_blocked(i):
				before_centroid += Vector2(
					float(before.get_row(i)) / float(before.board_size),
					float(before.get_col(i)) / float(before.board_size)
				)
				before_count += 1

		var after_centroid := Vector2.ZERO
		var after_count := 0
		for i in after.cell_count:
			if after.cells[i] == player and not after.is_blocked(i):
				after_centroid += Vector2(
					float(after.get_row(i)) / float(after.board_size),
					float(after.get_col(i)) / float(after.board_size)
				)
				after_count += 1

		if before_count > 0 and after_count > 0:
			before_centroid /= float(before_count)
			after_centroid /= float(after_count)
			total_displacement += before_centroid.distance_to(after_centroid)
			samples += 1

	if samples == 0:
		return 0.0
	return total_displacement / float(samples)


## Pattern survival: fraction of near-win patterns that survive the mixup
func _compute_pattern_survival(before: BoardModel, after: BoardModel, checker_before: WinChecker) -> float:
	# Find "near-win" patterns in before board (patterns where a player has N-1 marks)
	var patterns = checker_before.get_all_patterns()
	var near_wins := 0
	var survived := 0

	for pattern in patterns:
		for player in [0, 1]:
			var player_count := 0
			var empty_count := 0
			var blocked := false
			for idx in pattern:
				if idx >= before.cell_count:
					blocked = true
					break
				if before.is_blocked(idx):
					blocked = true
					break
				if before.cells[idx] == player:
					player_count += 1
				elif before.cells[idx] == -1:
					empty_count += 1
				elif before.is_wildcard(idx):
					player_count += 1

			if blocked:
				continue

			var win_length = pattern.size()
			# Near-win: player has win_length - 1 marks and 1 empty
			if player_count == win_length - 1 and empty_count >= 1:
				near_wins += 1

				# Check if any similar near-win exists in the after board
				# (same player has win_length-1 marks in any pattern)
				# We check if ANY near-win pattern exists for this player after mixup
				var after_checker = WinChecker.new(after.board_size, _game_state.current_win_length)
				var after_patterns = after_checker.get_all_patterns()
				var found := false
				for ap in after_patterns:
					var ap_count := 0
					var ap_empty := 0
					var ap_blocked := false
					for aidx in ap:
						if aidx >= after.cell_count:
							ap_blocked = true
							break
						if after.is_blocked(aidx):
							ap_blocked = true
							break
						if after.cells[aidx] == player:
							ap_count += 1
						elif after.cells[aidx] == -1:
							ap_empty += 1
						elif after.is_wildcard(aidx):
							ap_count += 1
					if ap_blocked:
						continue
					if ap_count == pattern.size() - 1 and ap_empty >= 1:
						found = true
						break
				if found:
					survived += 1

	if near_wins == 0:
		return 1.0  # No near-wins to disrupt
	return float(survived) / float(near_wins)


## Spatial entropy: Shannon entropy of mark distribution across quadrants
func _compute_spatial_entropy(board: BoardModel) -> float:
	var size := board.board_size
	var half := size / 2
	if half == 0:
		return 0.0

	# Count marks in 4 quadrants
	var quadrants := [0, 0, 0, 0]  # TL, TR, BL, BR
	var total_marks := 0

	for i in board.cell_count:
		if board.cells[i] >= 0 and board.cells[i] <= 1 and not board.is_blocked(i):
			var r := board.get_row(i)
			var c := board.get_col(i)
			var qi := 0
			if r >= half:
				qi += 2
			if c >= half:
				qi += 1
			quadrants[qi] += 1
			total_marks += 1

	if total_marks == 0:
		return 0.0

	# Shannon entropy (base 2, normalized to 0-1 range with max log2(4)=2)
	var entropy := 0.0
	for count in quadrants:
		if count > 0:
			var p := float(count) / float(total_marks)
			entropy -= p * log(p) / log(2.0)

	return entropy / 2.0  # Normalize to 0-1


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

func _aggregate_results(mixup_name: String, config_label: String, games: Array[Dictionary]) -> Dictionary:
	if games.is_empty():
		return {"mixup": mixup_name, "config": config_label, "fun_score": 0.0}

	var n := float(games.size())
	var wins := 0
	var stalemates := 0
	var p0_wins := 0
	var p1_wins := 0
	var total_turns := 0
	var total_draws := 0
	var total_wasted := 0

	var all_disp: Array[float] = []
	var all_surv: Array[float] = []
	var all_ent: Array[float] = []

	for g in games:
		total_turns += g["total_turns"]
		total_draws += g["draw_count"]
		total_wasted += g["wasted_moves"]
		if g["winner"] == 0:
			wins += 1
			p0_wins += 1
		elif g["winner"] == 1:
			wins += 1
			p1_wins += 1
		else:
			stalemates += 1

		all_disp.append_array(g["displacement_samples"])
		all_surv.append_array(g["pattern_survival_samples"])
		all_ent.append_array(g["entropy_samples"])

	var fun_score = _compute_fun_score(games, p0_wins, p1_wins, n)

	return {
		"mixup": mixup_name,
		"config": config_label,
		"total_games": games.size(),
		"win_rate": snapped(wins / n, 0.001),
		"stalemate_rate": snapped(stalemates / n, 0.001),
		"p0_win_rate": snapped(p0_wins / n, 0.001),
		"p1_win_rate": snapped(p1_wins / n, 0.001),
		"avg_turns": snapped(total_turns / n, 0.1),
		"avg_draws": snapped(total_draws / n, 0.1),
		"avg_wasted_moves": snapped(total_wasted / n, 0.1),
		"fun_score": snapped(fun_score, 0.01),
		"avg_displacement": snapped(_avg_array(all_disp), 0.001),
		"avg_pattern_survival": snapped(_avg_array(all_surv), 0.001),
		"avg_spatial_entropy": snapped(_avg_array(all_ent), 0.001),
	}


func _avg_array(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var total := 0.0
	for v in arr:
		total += v
	return total / float(arr.size())


func _compute_fun_score(games: Array[Dictionary], p0_wins: int, p1_wins: int, n: float) -> float:
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

		# +1 for decisive ending
		if g["game_over_reason"] != "stalemate" and g["game_over_reason"] != "max_turns":
			score += 1.0

		total_fun += score

	var avg_fun := total_fun / n

	# +0.5 bonus for balanced win rates
	var p0_rate := p0_wins / n
	var p1_rate := p1_wins / n
	if maxf(p0_rate, p1_rate) > 0:
		var balance := minf(p0_rate, p1_rate) / maxf(p0_rate, p1_rate)
		avg_fun += balance * 0.5

	return clampf(avg_fun, 0.0, 10.0)


func _count_marks(board) -> int:
	var count := 0
	for i in board.cell_count:
		if board.cells[i] == 0 or board.cells[i] == 1:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

func _print_mixup_analysis() -> void:
	print("[MIXUP_ANALYSIS_BEGIN]")

	# Group results by mixup
	var by_mixup: Dictionary = {}
	for r in _all_results:
		var name: String = r["mixup"]
		if not by_mixup.has(name):
			by_mixup[name] = []
		by_mixup[name].append(r)

	for mixup_name in _mixup_variants:
		if not by_mixup.has(mixup_name):
			continue
		var results: Array = by_mixup[mixup_name]

		var total_fun := 0.0
		var total_stalemate := 0.0
		var total_turns := 0.0
		var total_disp := 0.0
		var total_surv := 0.0
		var total_ent := 0.0
		var count := 0

		for r in results:
			total_fun += r["fun_score"]
			total_stalemate += r["stalemate_rate"]
			total_turns += r["avg_turns"]
			total_disp += r["avg_displacement"]
			total_surv += r["avg_pattern_survival"]
			total_ent += r["avg_spatial_entropy"]
			count += 1

		var n := float(count)
		var summary := {
			"mixup": mixup_name,
			"avg_fun_score": snapped(total_fun / n, 0.01),
			"avg_stalemate_rate": snapped(total_stalemate / n, 0.001),
			"avg_turns": snapped(total_turns / n, 0.1),
			"avg_displacement": snapped(total_disp / n, 0.001),
			"avg_pattern_survival": snapped(total_surv / n, 0.001),
			"avg_spatial_entropy": snapped(total_ent / n, 0.001),
			"per_config": [],
		}

		for r in results:
			summary["per_config"].append({
				"config": r["config"],
				"fun": r["fun_score"],
				"stalemate_rate": r["stalemate_rate"],
				"displacement": r["avg_displacement"],
				"pattern_survival": r["avg_pattern_survival"],
				"entropy": r["avg_spatial_entropy"],
			})

		print(JSON.stringify(summary, "  "))

	print("[MIXUP_ANALYSIS_END]")
	print("")


func _print_rankings() -> void:
	print("[MIXUP_RANKINGS_BEGIN]")

	# Aggregate per-mixup averages
	var mixup_averages: Array[Dictionary] = []
	var by_mixup: Dictionary = {}
	for r in _all_results:
		var name: String = r["mixup"]
		if not by_mixup.has(name):
			by_mixup[name] = []
		by_mixup[name].append(r)

	for mixup_name in _mixup_variants:
		if not by_mixup.has(mixup_name):
			continue
		var results: Array = by_mixup[mixup_name]
		var n := float(results.size())

		var total_fun := 0.0
		var total_stalemate := 0.0
		var total_disp := 0.0
		var total_surv := 0.0
		var total_ent := 0.0

		for r in results:
			total_fun += r["fun_score"]
			total_stalemate += r["stalemate_rate"]
			total_disp += r["avg_displacement"]
			total_surv += r["avg_pattern_survival"]
			total_ent += r["avg_spatial_entropy"]

		mixup_averages.append({
			"mixup": mixup_name,
			"avg_fun": snapped(total_fun / n, 0.01),
			"avg_stalemate_rate": snapped(total_stalemate / n, 0.001),
			"avg_displacement": snapped(total_disp / n, 0.001),
			"avg_pattern_survival": snapped(total_surv / n, 0.001),
			"avg_spatial_entropy": snapped(total_ent / n, 0.001),
		})

	# Sort by fun score
	var by_fun = mixup_averages.duplicate()
	by_fun.sort_custom(func(a, b): return a["avg_fun"] > b["avg_fun"])

	# Sort by displacement (most disruptive)
	var by_disp = mixup_averages.duplicate()
	by_disp.sort_custom(func(a, b): return a["avg_displacement"] > b["avg_displacement"])

	# Sort by pattern survival (most preserving)
	var by_surv = mixup_averages.duplicate()
	by_surv.sort_custom(func(a, b): return a["avg_pattern_survival"] > b["avg_pattern_survival"])

	# Sort by entropy (most spatially uniform)
	var by_ent = mixup_averages.duplicate()
	by_ent.sort_custom(func(a, b): return a["avg_spatial_entropy"] > b["avg_spatial_entropy"])

	# Sort by stalemate rate (lowest first)
	var by_stalemate = mixup_averages.duplicate()
	by_stalemate.sort_custom(func(a, b): return a["avg_stalemate_rate"] < b["avg_stalemate_rate"])

	var rankings := {
		"by_fun_score": by_fun,
		"by_displacement": by_disp,
		"by_pattern_survival": by_surv,
		"by_spatial_entropy": by_ent,
		"by_lowest_stalemate": by_stalemate,
	}

	print(JSON.stringify(rankings, "  "))
	print("[MIXUP_RANKINGS_END]")
	print("")


func _print_gap_analysis() -> void:
	print("[MIXUP_GAP_ANALYSIS_BEGIN]")

	# Classify each mixup on 3 axes
	var classifications: Array[Dictionary] = []

	# Aggregate per-mixup metrics
	var by_mixup: Dictionary = {}
	for r in _all_results:
		var name: String = r["mixup"]
		if not by_mixup.has(name):
			by_mixup[name] = []
		by_mixup[name].append(r)

	for mixup_name in _mixup_variants:
		if mixup_name == "None":
			continue
		if not by_mixup.has(mixup_name):
			continue

		var results: Array = by_mixup[mixup_name]
		var n := float(results.size())

		var avg_disp := 0.0
		var avg_surv := 0.0
		for r in results:
			avg_disp += r["avg_displacement"]
			avg_surv += r["avg_pattern_survival"]
		avg_disp /= n
		avg_surv /= n

		# Locality classification based on displacement
		var locality: String
		if avg_disp < 0.05:
			locality = "Local"
		elif avg_disp < 0.15:
			locality = "Medium"
		else:
			locality = "Global"

		# Determinism: hardcoded based on known algorithm
		var determinism: String
		match mixup_name:
			"Rotation", "Mirror", "Spiral":
				determinism = "Deterministic"
			_:
				determinism = "Stochastic"

		# Structure classification based on pattern survival
		var structure: String
		if avg_surv > 0.7:
			structure = "Preserving"
		elif avg_surv > 0.3:
			structure = "Partial"
		else:
			structure = "Disrupting"

		classifications.append({
			"mixup": mixup_name,
			"locality": locality,
			"determinism": determinism,
			"structure": structure,
			"avg_displacement": snapped(avg_disp, 0.001),
			"avg_pattern_survival": snapped(avg_surv, 0.001),
		})

	# Identify gaps in the design space
	var seen_combos: Array[String] = []
	for c in classifications:
		var combo := "%s/%s/%s" % [c["locality"], c["determinism"], c["structure"]]
		if combo not in seen_combos:
			seen_combos.append(combo)

	var all_localities := ["Local", "Medium", "Global"]
	var all_determinisms := ["Deterministic", "Stochastic"]
	var all_structures := ["Preserving", "Partial", "Disrupting"]

	var missing_combos: Array[String] = []
	for loc in all_localities:
		for det in all_determinisms:
			for stru in all_structures:
				var combo := "%s/%s/%s" % [loc, det, stru]
				if combo not in seen_combos:
					missing_combos.append(combo)

	var gap_analysis := {
		"classifications": classifications,
		"covered_combos": seen_combos,
		"missing_combos": missing_combos,
		"total_possible": all_localities.size() * all_determinisms.size() * all_structures.size(),
		"total_covered": seen_combos.size(),
	}

	print(JSON.stringify(gap_analysis, "  "))
	print("[MIXUP_GAP_ANALYSIS_END]")
