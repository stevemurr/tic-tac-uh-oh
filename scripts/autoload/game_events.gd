class_name GameEventsClass
extends Node

signal move_placed(cell_index: int, player: int)

# Game flow signals
signal turn_started(player: int)
signal game_over(winner: int) # -1 for draw/stalemate

# Complication signals
signal complication_added(complication: Resource)
signal draw_occurred()

# Growing board signals
signal board_grown(new_size: int, new_win_length: int)
signal spatial_mixup_applied(mixup_name: String)

# UI signals
signal timer_updated(time_left: float)
