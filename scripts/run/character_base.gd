class_name CharacterBase
extends RefCounted

var character_id: String = ""
var display_name: String = ""
var description: String = ""
var color: Color = Color.WHITE
var starter_rune_id: String = ""
var max_charge: int = 3
var active_name: String = ""
var active_description: String = ""


func on_run_start(_run_state: Node) -> void:
	pass


func on_battle_start(_board: BoardModel, _encounter) -> void:
	pass


func on_round_start(_board: BoardModel) -> void:
	pass


func on_turn_start(_player: int, _board: BoardModel) -> void:
	pass


func on_move_placed(_cell: int, _player: int, _board: BoardModel) -> void:
	pass


func modify_charge_gain(amount: int, _reason: String) -> int:
	return amount


func can_activate(_board: BoardModel, _player: int) -> bool:
	return false


func activate(_board: BoardModel, _player: int) -> Dictionary:
	return {}


func get_hud_state() -> Dictionary:
	return {}
