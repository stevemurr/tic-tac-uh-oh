---
description: Discover, design, and implement new complications for tic-tac-uh-oh. Analyzes playtest data to find gameplay gaps, designs complications that fit the fun formula, implements them, and validates via tests + playtesting.
argument-hint: <optional: specific gameplay gap or mechanic idea to explore>
---

# Discover New Complications

You are designing new complications for tic-tac-uh-oh, a Godot 4.6 tic-tac-toe variant with a growing board. Complications are gameplay modifiers that fire via hooks during the game loop.

## Step 1: Analyze Current State

Read these files to understand the current complication landscape:

1. `scripts/complications/complication_base.gd` — the base class and all available hooks
2. `scripts/autoload/complication_registry.gd` — all registered complications and the `_create_fresh()` factory
3. `scripts/autoload/game_state.gd` — the `all_complications_used()` threshold
4. All existing complications in `scripts/complications/*.gd` — understand what mechanics already exist

Categorize each existing complication by its **fun role**:
- **Destruction** (removes marks): e.g., the_bomb, decay, chain_reaction
- **Spatial disruption** (moves marks): e.g., rotating_board, aftershock
- **Restriction** (limits options): e.g., shrinking_board, gravity, time_pressure
- **Augmentation** (adds marks/options): e.g., mirror_moves, wildcard_cell
- **Agency disruption** (changes turn flow): e.g., stolen_turn

Identify which roles are underrepresented — those are the gaps to fill.

## Step 2: Run Playtest Data (if available)

Run the playtest runner to get current fun scores:

```bash
godot --headless -s tests/playtest_runner.gd --quick
```

From the output, identify:
- Top fun configs and what they have in common
- Bottom fun configs and what drags them down
- Stalemate rates by config
- The "fun formula" sweet spot: 10-30 turns, 1-6 wasted moves, 100% decisiveness, some board growth

If the user provided a specific mechanic idea via argument, skip to Step 3 using that idea. Otherwise, propose 2-4 complication concepts based on the gap analysis and ask the user which to pursue.

## Step 3: Design the Complication

For each new complication, define:

- **`complication_id`**: snake_case identifier
- **`display_name`**: short human-readable name
- **`description`**: one-line explanation
- **`priority`**: determines hook execution order (lower = earlier). Key reference points:
  - `rotating_board` / `aftershock`: 10 (spatial, runs early)
  - `decay`: 15
  - `gravity`: 20 (mark settling)
  - `chain_reaction`: 22 (after gravity)
  - `the_bomb`: 25 (destruction, runs late)
- **`incompatible_with`**: array of complication IDs that conflict mechanically
- **Hooks used**: which `on_*` methods it overrides and what they do
- **State**: what goes in `_state` dictionary (or "stateless")
- **AI hints**: what `ai_evaluate_modifier()` and/or `ai_modify_available_moves()` should do
- **Why it's fun**: which fun formula components it contributes to

Present this design to the user for approval before implementing.

## Step 4: Implement

Create the complication file at `scripts/complications/<complication_id>.gd` following these patterns:

```gdscript
class_name <PascalCaseName>Complication
extends ComplicationBase

func _init() -> void:
    complication_id = "<snake_case_id>"
    display_name = "<Display Name>"
    description = "<One-line description>"
    color = Color(<r>, <g>, <b>)
    priority = <int>
    # Only if needed:
    # incompatible_with = ["<other_id>"]

# Override only the hooks you need.
# Initialize _state in on_game_start() and on_board_reset().
# Use board methods: get_cell(), set_cell(), get_empty_cells(),
#   get_surrounding_cells(), is_blocked(), is_wildcard(), cell_count,
#   board_size, get_row(), get_col(), index_from_rc(), get_center_cell()

func ai_evaluate_modifier(board: BoardModel, player: int) -> float:
    # Help AI understand this complication's strategy
    return 0.0
```

Key rules:
- Always reset `_state` in both `on_game_start()` and `on_board_reset()` (board growth invalidates old state)
- Check `cell < board.cell_count` before accessing cells (board size changes)
- Check `not board.is_blocked(cell)` before modifying cells
- Use `board.set_cell(cell, -1)` to clear a mark
- Player values: 0 = X, 1 = O, -1 = empty

## Step 5: Register

Update these files:

1. **`scripts/autoload/complication_registry.gd`**:
   - Add `<ClassName>.new()` to the `_register_all()` array
   - Add `"<id>": return <ClassName>.new()` to the `_create_fresh()` match statement

2. **`scripts/autoload/game_state.gd`**:
   - Update `all_complications_used()` threshold to match total complication count

3. **`.godot/global_script_class_cache.cfg`**:
   - Add the new class entry (alphabetically sorted) with base `ComplicationBase` and the correct path

4. **`tests/playtest_runner.gd`**:
   - Add new ID to `ALL_COMP_IDS` array
   - Add solo config (automatic from the `for id in ALL_COMP_IDS` loop)
   - Add 3-5 targeted pair configs that test synergy with known fun drivers (especially `the_bomb`, `rotating_board`)
   - Optionally add a triple config

## Step 6: Validate

Run the full test suite — all existing tests must still pass:

```bash
godot --headless -s tests/test_runner.gd
```

Then run a quick playtest to verify the new complication works in gameplay:

```bash
godot --headless -s tests/playtest_runner.gd --quick
```

Check the output for:
- New complication configs appear with no errors
- At least one new config scores fun >= 5.0
- No new config has stalemate rate > 30%
- Existing top configs are not degraded

Report the results to the user with a summary of fun scores for the new configs vs. existing top configs.

## Reference: Available Board Methods

From `BoardModel`:
- `board_size: int` — current NxN size
- `cell_count: int` — total cells (board_size^2)
- `cells: Array[int]` — raw cell array (-1=empty, 0=X, 1=O)
- `get_cell(index) -> int`, `set_cell(index, value)`
- `get_empty_cells() -> Array[int]`
- `get_surrounding_cells(index) -> Array[int]` — 8-directional neighbors
- `get_row(index) -> int`, `get_col(index) -> int`
- `index_from_rc(row, col) -> int`
- `get_center_cell() -> int`
- `is_empty(index) -> bool`, `is_blocked(index) -> bool`, `is_wildcard(index) -> bool`
- `rotate_clockwise()`, `apply_gravity()`, `explode_bomb(index)`
- `bomb_cell: int` — current bomb position (-1 if none)

From `SpatialMixups` (static):
- `apply_random(board) -> String` — applies one of 6 random spatial transformations

## Reference: Fun Formula

The fun score (0-10) rewards:
- +3 for clear winner (not stalemate)
- +2 for 1-3 board growths
- +2 for moderate length (10-30 turns)
- +1.5 for some mark destruction (1-6 wasted moves)
- +1 for decisive ending
- +0.5 bonus for balanced win rates
