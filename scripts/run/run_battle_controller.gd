class_name RunBattleController
extends RefCounted

const RunContentRegistryScript = preload("res://scripts/run/run_content_registry.gd")

var encounter = null
var enemy_trait = null


func configure_game_state() -> void:
	encounter = RunState.begin_encounter()
	if encounter == null:
		return

	enemy_trait = RunContentRegistryScript.create_enemy_trait(encounter.enemy_trait_id)

	GameState.reset_session()
	GameState.game_mode = GameState.GameMode.CASTLE_ASCENT
	GameState.difficulty = encounter.ai_difficulty
	GameState.start_board_size = encounter.board_size
	GameState.current_board_size = encounter.board_size
	GameState.current_win_length = encounter.win_length
	GameState.growth_step = 0
	GameState.start_with_complication = not encounter.opening_complication_ids.is_empty()
	GameState.local_player_id = 0

	for comp_id in encounter.opening_complication_ids:
		var comp := ComplicationRegistry.create_fresh(comp_id)
		if comp:
			GameState.add_complication(comp)


func apply_battle_start(board: BoardModel) -> void:
	if RunState.character:
		RunState.character.on_battle_start(board, encounter)
	if enemy_trait:
		enemy_trait.on_battle_start(board, encounter)
	for rune in RunState.equipped_runes:
		rune.on_battle_start(board, encounter)


func apply_turn_start(player: int, board: BoardModel) -> void:
	if RunState.character:
		RunState.character.on_turn_start(player, board)
	if enemy_trait:
		enemy_trait.on_turn_start(player, board)
	for rune in RunState.equipped_runes:
		rune.on_turn_start(player, board)


func apply_move_placed(cell: int, player: int, board: BoardModel) -> void:
	if RunState.character:
		RunState.character.on_move_placed(cell, player, board)
	if enemy_trait:
		enemy_trait.on_move_placed(cell, player, board)
	for rune in RunState.equipped_runes:
		rune.on_move_placed(cell, player, board)
	if player == 0 and RunState.character:
		var gain: int = RunState.character.modify_charge_gain(1, "move")
		RunState.gain_charge(gain)


func build_result_payload(victory: bool) -> Dictionary:
	if encounter == null:
		return {"victory": victory, "resolve_damage": 1, "sigils": 0}

	return {
		"victory": victory,
		"resolve_damage": encounter.resolve_damage_on_loss,
		"sigils": 20 * encounter.reward_tier,
		"reward_tier": encounter.reward_tier,
		"encounter_id": encounter.encounter_id,
	}
