class_name NeonColors
extends RefCounted

## Centralized premium castle-tech palette.

# Background
const BG_DARK := Color(0.025, 0.03, 0.05)
const BG_MID := Color(0.05, 0.055, 0.085)
const CELL_BG := Color(0.09, 0.095, 0.14)
const SURFACE := Color(0.07, 0.075, 0.11, 0.92)
const SURFACE_ALT := Color(0.12, 0.12, 0.15, 0.95)
const SURFACE_SOFT := Color(0.17, 0.15, 0.13, 0.52)
const OVERLAY_BG := Color(0.02, 0.025, 0.04, 0.88)
const GAME_OVER_BG := Color(0.02, 0.02, 0.03, 0.92)

# Player colors
const PLAYER_X := Color(0.64, 0.88, 0.95)
const PLAYER_O := Color(0.93, 0.72, 0.44)

# Complication colors
const WILDCARD := Color(0.95, 0.86, 0.52)
const BOMB := Color(0.98, 0.42, 0.28)

# UI colors
const ACCENT := Color(0.89, 0.67, 0.38)
const TITLE := Color(0.97, 0.94, 0.88)
const GRID_LINE := Color(0.18, 0.27, 0.33)
const GRID_LINE_BRIGHT := Color(0.53, 0.68, 0.74)
const OUTLINE := Color(0.62, 0.71, 0.72, 0.34)
const OUTLINE_STRONG := Color(0.86, 0.74, 0.52, 0.76)
const DIM_OUTLINE := Color(0.20, 0.24, 0.30, 0.32)
const TEXT_DEFAULT := Color(0.93, 0.93, 0.96)
const TEXT_MUTED := Color(0.70, 0.73, 0.79)

# Cell states
const CELL_EMPTY_GLOW := Color(0.34, 0.44, 0.50, 0.18)
const CELL_HOVER_GLOW := Color(0.92, 0.78, 0.52, 0.58)
const CELL_BLOCKED := Color(0.14, 0.14, 0.16, 0.84)
const CELL_WILDCARD_OVERLAY := Color(0.95, 0.86, 0.52, 0.16)

# Draw / stalemate
const DRAW := Color(0.78, 0.78, 0.82)
const STALEMATE := Color(0.95, 0.86, 0.50)
const SUCCESS := Color(0.55, 0.83, 0.62)


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
