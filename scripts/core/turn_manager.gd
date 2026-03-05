class_name TurnManager
extends RefCounted

var current_player: int = 0  # 0 = X, 1 = O
var turn_count: int = 0
var skip_next: bool = false
var extra_turn: bool = false
var steal_available: Array[bool] = [false, false]  # Per player

func reset() -> void:
	current_player = 0
	turn_count = 0
	skip_next = false
	extra_turn = false
	steal_available = [false, false]

func advance_turn() -> int:
	turn_count += 1

	if extra_turn:
		extra_turn = false
		return current_player

	var proposed := 1 - current_player

	if skip_next:
		skip_next = false
		proposed = current_player  # Skip means NEXT player is skipped, same player goes again

	current_player = proposed
	return current_player

func get_current_player() -> int:
	return current_player

func grant_extra_turn() -> void:
	extra_turn = true

func skip_next_turn() -> void:
	skip_next = true

func has_steal(player: int) -> bool:
	return steal_available[player]

func use_steal(player: int) -> void:
	steal_available[player] = false

func grant_steal(player: int) -> void:
	steal_available[player] = true
