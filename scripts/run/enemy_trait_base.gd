class_name EnemyTraitBase
extends RefCounted

var trait_id: String = ""
var display_name: String = ""
var description: String = ""
var color: Color = Color.WHITE


func on_battle_start(_board: BoardModel, _encounter) -> void:
	pass


func on_round_start(_board: BoardModel) -> void:
	pass


func on_turn_start(_player: int, _board: BoardModel) -> void:
	pass


func on_move_placed(_cell: int, _player: int, _board: BoardModel) -> void:
	pass


func get_opening_complication_ids() -> Array[String]:
	return []


func get_boss_phase_payload(_phase: int) -> Dictionary:
	return {}
