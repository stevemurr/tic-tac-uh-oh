class_name NeonColors
extends RefCounted

## Centralized neon arcade color palette.

# Background
const BG_DARK := Color(0.03, 0.05, 0.09)
const BG_MID := Color(0.05, 0.08, 0.14)
const CELL_BG := Color(0.08, 0.11, 0.18)
const SURFACE := Color(0.07, 0.10, 0.16, 0.92)
const SURFACE_ALT := Color(0.11, 0.14, 0.22, 0.95)
const SURFACE_SOFT := Color(0.12, 0.18, 0.28, 0.52)
const OVERLAY_BG := Color(0.02, 0.04, 0.08, 0.88)
const GAME_OVER_BG := Color(0.02, 0.03, 0.06, 0.92)

# Player colors
const PLAYER_X := Color(0.0, 0.9, 1.0)       # neon cyan
const PLAYER_O := Color(1.0, 0.1, 0.6)        # neon magenta

# Complication colors
const WILDCARD := Color(1.0, 0.95, 0.0)       # neon yellow
const BOMB := Color(1.0, 0.3, 0.0)            # neon orange

# UI colors
const ACCENT := Color(1.0, 0.55, 0.18)
const TITLE := Color(1.0, 0.95, 0.84)
const GRID_LINE := Color(0.05, 0.39, 0.49)
const GRID_LINE_BRIGHT := Color(0.12, 0.72, 0.88)
const OUTLINE := Color(0.15, 0.66, 0.82, 0.36)
const OUTLINE_STRONG := Color(0.34, 0.86, 1.0, 0.75)
const DIM_OUTLINE := Color(0.06, 0.42, 0.55, 0.28)
const TEXT_DEFAULT := Color(0.9, 0.93, 0.98)
const TEXT_MUTED := Color(0.66, 0.74, 0.84)

# Cell states
const CELL_EMPTY_GLOW := Color(0.0, 0.3, 0.4, 0.2)
const CELL_HOVER_GLOW := Color(0.0, 0.6, 0.8, 0.5)
const CELL_BLOCKED := Color(0.15, 0.15, 0.2, 0.8)
const CELL_WILDCARD_OVERLAY := Color(1.0, 0.95, 0.0, 0.15)

# Draw / stalemate
const DRAW := Color(0.7, 0.7, 0.7)
const STALEMATE := Color(1.0, 0.95, 0.0)
const SUCCESS := Color(0.46, 0.88, 0.53)


static func for_player(player: int) -> Color:
	return PLAYER_X if player == 0 else PLAYER_O


static func for_player_dim(player: int, alpha: float = 0.4) -> Color:
	var c := for_player(player)
	return Color(c.r, c.g, c.b, alpha)


static func for_cell_state(mark: int) -> Color:
	match mark:
		0: return PLAYER_X
		1: return PLAYER_O
		2: return WILDCARD
		_: return TEXT_DEFAULT
