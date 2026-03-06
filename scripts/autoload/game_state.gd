class_name GameStateClass
extends Node

enum GameMode { LOCAL_2P, VS_AI, ONLINE }
enum Difficulty { EASY, MEDIUM, HARD }

const DEFAULT_TURN_TIME: float = 15.0

var game_mode: GameMode = GameMode.LOCAL_2P
var difficulty: Difficulty = Difficulty.MEDIUM
var local_player_id: int = 0  # 0=host/X, 1=client/O
var signaling_url: String = "ws://localhost:8080"
var active_complications: Array[ComplicationBase] = []

# Pre-game settings
var start_board_size: int = 3
var start_with_complication: bool = false

var scores: Array[int] = [0, 0]  # Player 0 (X), Player 1 (O)
var draw_count: int = 0
var round_number: int = 0

# Growing board state
var current_board_size: int = 3
var current_win_length: int = 3
var growth_step: int = 0  # Increment increases each grow: +1, +2, +3...

func reset_session() -> void:
	active_complications.clear()
	scores = [0, 0]
	draw_count = 0
	round_number = 0
	current_board_size = start_board_size
	current_win_length = (start_board_size + 3) / 2
	growth_step = 0

func get_next_board_size() -> int:
	return current_board_size + growth_step + 1

func get_next_win_length() -> int:
	return current_win_length + 1

func apply_growth() -> void:
	current_board_size = get_next_board_size()
	current_win_length = get_next_win_length()
	growth_step += 1

func add_complication(complication: ComplicationBase) -> void:
	active_complications.append(complication)
	complication.is_active = true

func get_active_complications_sorted() -> Array[ComplicationBase]:
	var sorted := active_complications.duplicate()
	sorted.sort_custom(func(a: ComplicationBase, b: ComplicationBase): return a.priority < b.priority)
	return sorted

func all_complications_used() -> bool:
	return active_complications.size() >= 12
