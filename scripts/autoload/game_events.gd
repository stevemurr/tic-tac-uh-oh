class_name GameEventsClass
extends Node

# Board signals
signal cell_pressed(cell_index: int)
signal move_placed(cell_index: int, player: int)
signal board_updated()
signal board_reset()

# Game flow signals
signal game_started(mode: String)
signal turn_started(player: int)
signal turn_ended(player: int)
signal game_over(winner: int) # -1 for draw/stalemate
signal round_over(winner: int)

# Complication signals
signal complication_added(complication: Resource)
signal complication_triggered(complication: Resource)
signal complication_announcement_finished()
signal draw_occurred()

# Growing board signals
signal board_grown(new_size: int, new_win_length: int)
signal spatial_mixup_applied(mixup_name: String)

# UI signals
signal show_announcement(text: String, color: Color)
signal timer_updated(time_left: float)
signal timer_expired()

# AI signals
signal ai_move_requested(player: int)
signal ai_move_calculated(cell_index: int)
