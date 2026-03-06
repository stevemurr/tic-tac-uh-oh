class_name EncounterProfile
extends RefCounted

var encounter_id: String
var display_name: String
var encounter_type: String
var board_size: int
var win_length: int
var ai_difficulty: int
var enemy_trait_id: String
var opening_complication_ids: Array
var reward_tier: int
var boss_phase: int
var resolve_damage_on_loss: int


func _init() -> void:
	encounter_id = ""
	display_name = ""
	encounter_type = "duel"
	board_size = 3
	win_length = 3
	ai_difficulty = GameState.Difficulty.MEDIUM
	enemy_trait_id = ""
	opening_complication_ids = []
	reward_tier = 1
	boss_phase = 0
	resolve_damage_on_loss = 1
