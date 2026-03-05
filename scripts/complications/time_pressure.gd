class_name TimePressureComplication
extends ComplicationBase

func _init() -> void:
	complication_id = "time_pressure"
	display_name = "Time Pressure"
	description = "Turn timer reduced to 10 seconds!"
	color = Color(1.0, 0.2, 0.2)
	priority = 35


func on_game_start(_board: BoardModel) -> void:
	_state["time_limit"] = 10.0
	_state["timer_active"] = false


func on_board_reset(_board: BoardModel) -> void:
	_state["timer_active"] = false


func on_turn_start(_player_idx: int, _board: BoardModel) -> void:
	_state["timer_active"] = true
	_state["time_remaining"] = _state.get("time_limit", 10.0)


func on_turn_end(_player: int, _board: BoardModel, _turns: TurnManager) -> void:
	_state["timer_active"] = false


func get_time_limit() -> float:
	return _state.get("time_limit", 10.0)


func get_time_remaining() -> float:
	return _state.get("time_remaining", 10.0)


func is_timer_active() -> bool:
	return _state.get("timer_active", false)


func set_time_remaining(t: float) -> void:
	_state["time_remaining"] = t


func get_visual_effects() -> Dictionary:
	return {"timer": _state.get("time_remaining", 10.0)}
