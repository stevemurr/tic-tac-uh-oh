class_name NeonColors
extends RefCounted

## Centralized neon arcade color palette.

# Background
const BG_DARK := Color(0.05, 0.05, 0.1)
const CELL_BG := Color(0.08, 0.08, 0.15)
const OVERLAY_BG := Color(0.03, 0.03, 0.08, 0.85)
const GAME_OVER_BG := Color(0.03, 0.03, 0.08, 0.9)

# Player colors
const PLAYER_X := Color(0.0, 0.9, 1.0)       # neon cyan
const PLAYER_O := Color(1.0, 0.1, 0.6)        # neon magenta

# Complication colors
const WILDCARD := Color(1.0, 0.95, 0.0)       # neon yellow
const BOMB := Color(1.0, 0.3, 0.0)            # neon orange

# UI colors
const ACCENT := Color(0.6, 0.2, 1.0)          # neon purple
const TITLE := Color(1.0, 0.95, 0.0)          # neon yellow
const GRID_LINE := Color(0.0, 0.3, 0.4)       # dim cyan
const GRID_LINE_BRIGHT := Color(0.0, 0.5, 0.6)
const DIM_OUTLINE := Color(0.0, 0.4, 0.5, 0.3)
const TEXT_DEFAULT := Color(0.8, 0.8, 0.9)

# Cell states
const CELL_EMPTY_GLOW := Color(0.0, 0.3, 0.4, 0.2)
const CELL_HOVER_GLOW := Color(0.0, 0.6, 0.8, 0.5)
const CELL_BLOCKED := Color(0.15, 0.15, 0.2, 0.8)
const CELL_WILDCARD_OVERLAY := Color(1.0, 0.95, 0.0, 0.15)

# Draw / stalemate
const DRAW := Color(0.7, 0.7, 0.7)
const STALEMATE := Color(1.0, 0.95, 0.0)


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
