# Tic-Tac-Uh-Oh — Implementation Plan

## Context

Tic-tac-toe is "solved" — optimal play always draws. **Tic-Tac-Uh-Oh** weaponizes that: every draw adds a random complication that stacks with previous ones, escalating chaos until someone finally wins (or all 8 complications are active). Think Balatro's modifier philosophy applied to tic-tac-toe.

**Key design principle**: Complications maintain perfect information. Both players always see the full board state. No hidden information — that would break the tic-tac-toe feel.

---

## Architecture Overview

### Tech
- Godot 4.6, GDScript, mobile renderer
- 2D core gameplay with 3D visual flair (tweens, shaders, camera shake)
- Local 2-player + vs AI (selectable from menu)

### Core Pattern: Hook-Based Complication System
Each complication is a `Resource` subclass that hooks into the game loop at defined points. The game orchestrator calls hooks in priority order. AI simulates moves through the same hooks — no special-casing.

```
game loop → for each hook point → for each complication (sorted by priority) → call hook
```

---

## Directory Structure

```
res://
  scenes/
    main_menu.tscn / .gd
    game/
      game.tscn / game.gd          # Root game scene + state machine
      board.tscn / board.gd        # Visual board, syncs from BoardModel
      cell.tscn / cell.gd          # Individual cell (TextureButton)
    ui/
      hud.tscn / hud.gd
      complication_announcement.tscn / .gd
      game_over.tscn / .gd
  scripts/
    autoload/
      game_events.gd               # Signal bus
      game_state.gd                # Session state (mode, complications, scores)
      complication_registry.gd     # Catalog + random picker
    core/
      board_model.gd               # Pure data model (cells, blocked, wildcard)
      win_checker.gd               # Win/draw detection with modifiable patterns
      move_validator.gd            # Validation pipeline through complication hooks
      turn_manager.gd              # Turn sequencing, skip/extra turns
    ai/
      minimax_solver.gd            # Minimax + alpha-beta, complication-aware
      board_evaluator.gd           # Position heuristic
    complications/
      complication_base.gd         # Abstract base Resource
      gravity.gd
      shrinking_board.gd
      mirror_moves.gd
      the_bomb.gd
      rotating_board.gd
      stolen_turn.gd
      time_pressure.gd
      wildcard_cell.gd
  shaders/
    bomb_pulse.gdshader
    wildcard_shimmer.gdshader
    cell_glow.gdshader
```

---

## Complication Base Class (The Heart)

`complication_base.gd` — every complication overrides only the hooks it needs:

```gdscript
class_name ComplicationBase extends Resource

@export var complication_id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var color: Color
@export var incompatible_with: Array[String] = []
@export var priority: int = 0  # Lower runs first

var is_active: bool = false
var _state: Dictionary = {}    # Per-round mutable state

# Hook points (override as needed)
func on_game_start(board: BoardModel) -> void: pass
func on_turn_start(player_idx: int, board: BoardModel) -> void: pass
func on_validate_move(result: MoveResult, cell: int, player: int, board: BoardModel) -> void: pass
func on_move_placed(cell: int, player: int, board: BoardModel) -> void: pass
func on_turn_end(player: int, board: BoardModel, turns: TurnManager) -> void: pass
func on_check_win(board: BoardModel, checker: WinChecker) -> void: pass
func on_board_reset(board: BoardModel) -> void: pass
func on_resolve_next_turn(proposed: int, turns: TurnManager) -> int: return proposed
func get_visual_effects() -> Dictionary: return {}

# AI hooks
func ai_evaluate_modifier(board: BoardModel, player: int) -> float: return 0.0
func ai_modify_available_moves(moves: Array[int], board: BoardModel, player: int) -> Array[int]: return moves
```

---

## The 8 Complications

### Board Mutations

| # | Name | Mechanic | Priority |
|---|------|----------|----------|
| 1 | **Shrinking Board** | Every 3 moves, a random empty edge/corner cell becomes permanently blocked. Stops when ≤3 cells remain. | 5 |
| 2 | **Gravity** | Marks fall to the lowest empty cell in their column (Connect 4 style). Blocked cells act as floors. | 20 |
| 3 | **Rotating Board** | Every 2 turns, the board rotates 90° clockwise. All marks rotate with it. | 10 |
| 4 | **The Bomb** | A random cell is a bomb. Placing on it clears all 8 surrounding cells. New bomb spawns after detonation. | 25 |

### Rule Modifiers

| # | Name | Mechanic | Priority |
|---|------|----------|----------|
| 5 | **Mirror Moves** | Each placement also places your mark on the horizontally mirrored cell (if empty). Vertical center line shown. | 15 |
| 6 | **Stolen Turn** | Each player gets 1 "steal" per round — replace an opponent's mark with your own instead of placing. | 30 |
| 7 | **Time Pressure** | Per-turn timer. Starts at 10s, decreases by 2s each time this complication stacks (min 3s). Timeout = random valid move. | 35 |
| 8 | **Wildcard Cell** | A random cell becomes wild — counts as both X and O for win checking. Can't be played on directly. | 5 |

### Key Stacking Interactions

| A | B | What happens |
|---|---|---|
| Gravity | Rotating Board | Rotation fires first (pri 10), gravity re-settles after (pri 20) |
| Gravity | Mirror Moves | Mirror picks target column (pri 15), gravity drops it (pri 20) |
| Gravity | Shrinking Board | Blocked cells act as floors — marks stop above them |
| Bomb | Mirror Moves | Mirror mark landing on bomb triggers explosion |
| Bomb | Shrinking Board | If bomb cell gets blocked, bomb relocates |
| Stolen Turn | Mirror/Bomb/Gravity | Steal is replacement, not placement — no side effects trigger |
| Wildcard | Shrinking Board | If wildcard gets blocked, wildcard relocates |

---

## Game Flow State Machine

```
MainMenu → Game.RESETTING_BOARD → Game.PLAYER_TURN ←──────────────┐
                                       │                           │
                         (human click / AI move)                   │
                                       ↓                           │
                                 ANIMATING_MOVE                    │
                          (run on_move_placed hooks)               │
                                       ↓                           │
                                CHECKING_RESULT                    │
                              /        |         \                 │
                          Win        Draw      Neither             │
                           ↓           ↓           ↓               │
                      GAME_OVER   ANNOUNCING    advance turn ──────┘
                           ↓     COMPLICATION       (run on_turn_end hooks)
                       GameOver      ↓
                        screen   pick random complication
                                 dramatic reveal animation
                                 add to active list
                                       ↓
                                 RESETTING_BOARD (loop)
```

If all 8 complications are exhausted on draw → GAME_OVER ("Ultimate Stalemate!")

---

## AI Design

- **Minimax + alpha-beta pruning** on `BoardModel`
- **Complication-aware simulation**: `_simulate_move()` runs the same hooks the real game uses — mirror placement, gravity drop, bomb explosion all happen in the AI's search tree
- **Three difficulty levels**:
  - Easy: 70% random moves, 30% depth-1 minimax
  - Medium: depth-3 minimax, no complication heuristics
  - Hard: full-depth minimax + per-complication `ai_evaluate_modifier` bonuses
- Performance: Even with all 8 complications, alpha-beta pruning keeps search under 1M nodes

---

## Visual Communication of Stacking Complications

- **HUD panel** (top-right): Icon strip of active complications, colored, pulse when triggered
- **Per-cell layers**: Shader overlays stack (bomb pulse, wildcard shimmer, blocked cracks)
- **Board-level indicators**: Gravity arrows on columns, mirror line (vertical dashed), rotation arrows at corners
- **Event flashes**: Camera shake + colored flash matching complication color on trigger
- **Turn banner**: Brief slide-in showing active effects relevant to current turn ("Rotation in 1 turn!", "Steal available")

---

## Implementation Phases

### Phase 1: Core Tic-Tac-Toe
- `BoardModel`, `WinChecker`, `MoveValidator`, `TurnManager`
- `Board` + `Cell` scenes, `game.gd` state machine
- Basic HUD (turn indicator, player labels)
- Main menu (mode selection)
- Local 2-player working end-to-end

### Phase 2: AI
- `MinimaxSolver`, `BoardEvaluator`
- AI player controller, difficulty selection
- VS AI mode working

### Phase 3: Complication Framework
- `ComplicationBase`, `ComplicationRegistry`
- Complication announcement scene (dramatic reveal)
- Draw → pick complication → announce → replay loop
- Game over / scoreboard screen

### Phase 4: Complications (one at a time, in order)
1. Shrinking Board (simplest mutation)
2. Gravity (builds on board mutation)
3. Mirror Moves (introduces placement side-effects)
4. The Bomb (tests interaction with gravity + mirror)
5. Rotating Board (tests interaction with gravity)
6. Stolen Turn (non-placement move type)
7. Wildcard Cell (win condition modification)
8. Time Pressure (timer UI + timeout logic)

### Phase 5: Polish
- Shaders (bomb pulse, wildcard shimmer, cell glow)
- Camera shake, tweens, transitions
- Audio (SFX for placement, explosion, rotation, timer tick)
- Scoreboard stats (draw count, complications encountered)

---

## Verification

1. **Core gameplay**: Play a full game of 2-player tic-tac-toe, verify win/draw detection
2. **AI**: Play vs AI on all 3 difficulties, verify it makes reasonable moves
3. **Complication loop**: Force draws to trigger 3+ complications, verify they stack correctly
4. **Each complication**: Test in isolation AND with 2-3 others active simultaneously
5. **Edge cases**: All cells blocked (shrinking), bomb on wildcard, steal + mirror, gravity + rotation + mirror together
6. **All complications active**: Play until all 8 are active, verify game doesn't break
7. **Timer**: Verify time pressure timeout makes a valid move and doesn't freeze

---

## Critical Files

- `scripts/complications/complication_base.gd` — The hook interface. Getting this right is the #1 priority.
- `scripts/core/board_model.gd` — Pure data model. All logic + AI operates on this.
- `scenes/game/game.gd` — State machine orchestrator. Calls hooks, manages flow.
- `scripts/ai/minimax_solver.gd` — AI that simulates through complication hooks.
- `scripts/autoload/complication_registry.gd` — Random picker with compatibility checking.
