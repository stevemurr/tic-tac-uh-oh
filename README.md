# Tic-Tac-Uh-Oh

A strategic tic-tac-toe variant built in Godot 4.6 where every draw introduces a random complication that stacks with previously active ones, escalating chaos until someone finally wins.

## How It Works

1. Play tic-tac-toe on a 3x3 board
2. If the game draws, a random **complication** is added and the board **grows**
3. A **spatial mixup** shuffles marks on the expanded board
4. Complications **stack** — the more draws, the wilder the game gets
5. Repeat until someone wins or all 12 complications are exhausted

Win length scales with board size: `(board_size + 3) / 2`

## Game Modes

- **Local 2 Player** — human vs human
- **VS AI** — three difficulty levels:
  - Easy: mostly random moves
  - Medium: depth-3 minimax
  - Hard: full-depth minimax with complication-aware heuristics

## The 12 Complications

| Complication | Effect |
|---|---|
| **Gravity** | Marks fall to the lowest empty cell in their column |
| **Mirror Moves** | Each placement also mirrors horizontally |
| **The Bomb** | A cell explodes on placement, clearing all 8 neighbors |
| **Shrinking Board** | Every 3 moves, a random edge/corner cell gets blocked |
| **Stolen Turn** | Each player gets one "steal" per round to overwrite an opponent's mark |
| **Wildcard Cell** | A random cell counts as both X and O for win checking |
| **Rotating Board** | Every 2 turns, the board rotates 90° clockwise |
| **Time Pressure** | Per-turn timer that shrinks with each stack (10s down to 3s) |
| **Decay** | Marks gradually fade out over time |
| **Aftershock** | Secondary effects cascade after major moves |
| **Chain Reaction** | Successful moves trigger additional automatic placements |
| **Infection** | Marks spread to adjacent cells |

All complications are hook-based and execute in priority order. They interact — gravity fires after rotation, mirror placement happens before gravity drop, bombs can detonate on wildcard cells, etc.

## The 7 Spatial Mixups

Applied when the board grows after a draw:

| Mixup | Effect |
|---|---|
| **Rotation** | Board rotates 90°, 180°, or 270° |
| **Earthquake** | Each mark has 50% chance to shift to an adjacent cell |
| **Shuffle** | All marks redistributed randomly |
| **Plinko** | Marks shift 1-2 cells in a random direction |
| **Mirror** | Board flips horizontally or vertically |
| **Spiral** | Marks shift along a spiral path |
| **Vortex** | Marks shift within concentric rings |

## Running

Requires [Godot 4.6+](https://godotengine.org/).

```bash
# Run the game
godot --path . scenes/main_menu.tscn

# Run tests (77 tests, headless)
godot --headless -s tests/test_runner.gd --seed=42

# Benchmark spatial mixups
godot --headless -s tests/mixup_explorer.gd --quick
```

## Tests

77 tests across 7 categories:

- **Core** (11) — board init, placement, turn alternation, growth
- **Win Checker** (12) — rows, columns, diagonals, sliding windows, wildcards
- **Spatial Mixups** (10) — mark preservation across all 7 mixup types
- **Complications** (22) — each in isolation + combined (gravity+mirror, bomb+mirror, etc.)
- **AI** (8) — valid moves, win/block detection, performance bounds
- **Full Game** (5) — AI vs AI, multi-round growth, 100 random games with invariant checks
- **Edge Cases** (9) — all cells blocked, all 12 complications active, max board size

## Architecture

```
scripts/
├── autoload/          # GameState, GameEvents, ComplicationRegistry
├── core/              # BoardModel, WinChecker, MoveValidator, TurnManager, SpatialMixups
├── complications/     # 12 complication implementations + base class
├── ai/                # MinimaxSolver, BoardEvaluator
└── vfx/               # BoardAnimator, CellEffects, NeonColors
scenes/
├── game/              # Board, Cell, Game (root state machine)
└── ui/                # HUD, complication announcement, game over
shaders/               # bomb_pulse, wildcard_shimmer, cell_glow, neon effects
tests/                 # test_runner, game_simulator, invariant_checker
```

Key patterns:
- **Pure BoardModel** — all logic operates on an immutable data structure
- **Hook-based complications** — each overrides only the hooks it needs (`on_move_placed`, `on_turn_end`, etc.)
- **Priority ordering** — complications execute in defined order so stacking interactions are deterministic
- **Headless testing** — full suite runs without graphics via `godot --headless -s`
