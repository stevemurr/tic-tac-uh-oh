class_name RuneBase
extends RefCounted

var rune_id: String = ""
var display_name: String = ""
var description: String = ""
var rarity: String = "common"
var color: Color = Color.WHITE


func on_run_start(_run_state: Node) -> void:
	pass


func on_battle_start(_board: BoardModel, _encounter) -> void:
	pass


func on_turn_start(_player: int, _board: BoardModel) -> void:
	pass


func on_move_placed(_cell: int, _player: int, _board: BoardModel) -> void:
	pass


func modify_reward_options(options: Array) -> Array:
	return options


func get_hud_state() -> Dictionary:
	return {}
