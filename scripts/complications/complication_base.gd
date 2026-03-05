class_name ComplicationBase
extends Resource

@export var complication_id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var incompatible_with: Array[String] = []
@export var priority: int = 0

var is_active: bool = false
var _state: Dictionary = {}

func on_game_start(board: BoardModel) -> void: pass
func on_turn_start(player_idx: int, board: BoardModel) -> void: pass
func on_validate_move(result: MoveResult, cell: int, player: int, board: BoardModel) -> void: pass
func on_move_placed(cell: int, player: int, board: BoardModel) -> void: pass
func on_turn_end(player: int, board: BoardModel, turns: TurnManager) -> void: pass
func on_check_win(board: BoardModel, checker: WinChecker) -> void: pass
func on_board_reset(board: BoardModel) -> void: pass
func on_resolve_next_turn(proposed: int, turns: TurnManager) -> int: return proposed
func get_visual_effects() -> Dictionary: return {}

func ai_evaluate_modifier(board: BoardModel, player: int) -> float: return 0.0
func ai_modify_available_moves(moves: Array[int], board: BoardModel, player: int) -> Array[int]: return moves
