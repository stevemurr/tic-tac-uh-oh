---
description: Discover, design, and implement new spatial mixups for tic-tac-uh-oh. Benchmarks existing mixups, identifies gaps in the design space, and guides creation of new ones.
argument-hint: <optional: specific mixup concept or design space gap to explore>
---

# Discover New Spatial Mixups

You are designing new spatial mixups for tic-tac-uh-oh, a Godot 4.6 tic-tac-toe variant. Spatial mixups transform the board when it grows after a draw — they reposition marks to keep gameplay fresh. Each mixup applies a spatial transformation (rotation, shuffle, mirror, etc.) to the grown board.

## Step 1: Analyze Current Mixups

Read `scripts/core/spatial_mixups.gd` and classify each mixup on 3 axes:

**Locality** (how far marks move):
- **Local**: marks shift to adjacent cells only (e.g., Earthquake)
- **Medium**: marks move moderate distances (e.g., Plinko, Spiral)
- **Global**: marks can end up anywhere (e.g., Shuffle)

**Determinism** (predictability of outcome):
- **Deterministic**: same input always produces same output (e.g., Mirror, Rotation, Spiral)
- **Stochastic**: outcome depends on random choices (e.g., Earthquake, Shuffle, Plinko)

**Structure** (how much strategic position is preserved):
- **Preserving**: near-win patterns mostly survive (e.g., Rotation, Mirror)
- **Partial**: some patterns survive (e.g., Spiral, Plinko)
- **Disrupting**: most patterns are destroyed (e.g., Shuffle, Earthquake)

Build a 3x2x3 matrix and identify which cells are empty — those are design space gaps.

## Step 2: Run Explorer Baseline

Run the mixup explorer to get quantitative data:

```bash
godot --headless -s tests/mixup_explorer.gd --quick
```

Parse the output sections:
- `[MIXUP_ANALYSIS_BEGIN/END]` — per-mixup metrics across configurations
- `[MIXUP_RANKINGS_BEGIN/END]` — sorted rankings by fun, displacement, pattern survival, entropy
- `[MIXUP_GAP_ANALYSIS_BEGIN/END]` — automated classification and gap detection

## Step 3: Analyze Results

From the explorer output, answer:
1. Which mixups produce the highest fun scores? Why?
2. Which mixups cause the most stalemates? Why?
3. What's the relationship between displacement and fun?
4. What's the relationship between pattern survival and decisiveness?
5. Which design space cells are empty (from gap analysis)?

If the user provided a specific concept via argument, skip to Step 4 using that concept. Otherwise, propose 2-3 new mixup concepts that fill identified gaps. Ask the user which to pursue.

## Step 4: Design New Mixup

For the chosen concept, define:

- **Name**: PascalCase (e.g., "Vortex", "Gravity", "Zigzag")
- **Algorithm**: Step-by-step description of the transformation
- **Mark preservation proof**: Explain why the total mark count is always preserved
- **Board size handling**: How it works for any NxN board (3x3 through 18x18)
- **Special cell handling**: How it handles bombs, blocked cells, and wildcards
- **Design space position**: Locality / Determinism / Structure classification
- **Expected metrics**: Predicted displacement, pattern survival, entropy ranges

Present this design to the user for approval before implementing.

## Step 5: Implement

Add the new mixup to `scripts/core/spatial_mixups.gd`:

1. Add `_apply_<name>(board: BoardModel) -> void` static method:
   - Must preserve all marks (same count of X, O, wildcard before and after)
   - Must handle blocked cells (never move a blocked cell's mark)
   - Must handle bomb_cell (update position if the bomb moves)
   - Must handle wildcard cells (preserve wildcard status when moving marks)

2. Update `apply_random()` — increment the modulo and add a new elif branch:
   ```gdscript
   # Change: randi() % 6  ->  randi() % 7
   # Add new elif for choice == 6
   ```

3. Update `apply_by_name()` — add new match arm

4. Update `get_all_names()` — add new name to the returned array

## Step 6: Add Tests

Add a mark preservation test to `tests/test_scenarios.gd`:

```gdscript
func test_mixup_<name>_preserves_marks() -> String:
    var board = BoardModel.new(4)
    # Set up marks, wildcards, blocked cells
    board.set_cell(0, 0); board.set_cell(5, 1); board.set_cell(10, 0)
    board.set_wildcard(3, true); board.set_cell(3, 2)
    board.set_blocked(7, true)
    var before = board.duplicate_board()
    SpatialMixups._apply_<name>(board)
    return _checker.check_mark_preservation(before, board, "<name>")
```

Register the test in `tests/test_runner.gd` under the Spatial Mixups section.

## Step 7: Validate

Run the full test suite — all existing tests must still pass:

```bash
godot --headless -s tests/test_runner.gd
```

Then run the explorer to validate the new mixup's metrics:

```bash
godot --headless -s tests/mixup_explorer.gd --quick
```

Check the output for:
- New mixup appears in rankings with no errors
- New mixup fills the intended design space gap
- Fun scores for configs with the new mixup are reasonable (>= 4.0)
- Stalemate rate is not excessive (< 30%)
- Existing mixup metrics are not degraded

Optionally run the full playtest to verify top configs aren't harmed:

```bash
godot --headless -s tests/playtest_runner.gd --quick
```

Report the results to the user with a summary comparing the new mixup's metrics to existing ones.

## Reference: Board Methods

From `BoardModel`:
- `board_size: int` — current NxN size
- `cell_count: int` — total cells (board_size^2)
- `cells: Array[int]` — raw cell array (-1=empty, 0=X, 1=O, 2=wildcard)
- `get_cell(index) -> int`, `set_cell(index, value)`
- `get_empty_cells() -> Array[int]`
- `get_row(index) -> int`, `get_col(index) -> int`
- `index_from_rc(row, col) -> int`
- `is_empty(index) -> bool`, `is_blocked(index) -> bool`, `is_wildcard(index) -> bool`
- `set_blocked(index, bool)`, `set_wildcard(index, bool)`
- `rotate_clockwise()`, `apply_gravity()`
- `bomb_cell: int` — current bomb position (-1 if none)
- `duplicate_board() -> BoardModel`

## Reference: SpatialMixups API

From `SpatialMixups` (static):
- `apply_random(board) -> String` — applies one of N random spatial transformations
- `apply_by_name(board, name) -> String` — applies a specific named mixup
- `get_all_names() -> Array[String]` — returns all mixup names

Existing mixups:
- **Rotation**: Rotate 90/180/270 degrees (deterministic per choice, random which)
- **Earthquake**: Each mark has 50% chance to shift to adjacent empty cell
- **Shuffle**: Collect all marks, redistribute randomly to any position
- **Plinko**: Each mark slides 1-2 cells in a random cardinal direction
- **Mirror**: Flip horizontally or vertically (handles bomb position)
- **Spiral**: Shift all marks one position along a clockwise spiral path
- **Vortex**: Shift marks within concentric rings, alternating CW/CCW per ring

## Reference: Mixup Design Space Taxonomy

```
             Deterministic              Stochastic
           Pres  Part  Disr         Pres  Part  Disr
Local       ?     ?     ?            ?    [EQ]    ?
Medium     [SP] [VX]    ?            ?    [PL]    ?
Global     [RO]  [MI]   ?            ?     ?    [SH]
```

Key: RO=Rotation, EQ=Earthquake, SH=Shuffle, PL=Plinko, MI=Mirror, SP=Spiral, VX=Vortex

Empty cells represent opportunities for new mixups.

## Reference: Fun Formula

The fun score (0-10) rewards:
- +3 for clear winner (not stalemate)
- +2 for 1-3 board growths
- +2 for moderate length (10-30 turns)
- +1.5 for some mark destruction (1-6 wasted moves)
- +1 for decisive ending
- +0.5 bonus for balanced win rates

## Reference: Mixup-Specific Metrics

From the explorer (`tests/mixup_explorer.gd`):
- **Mark displacement**: Centroid movement of each player's marks (normalized 0-1)
- **Pattern survival**: Fraction of near-win patterns that survive the growth+mixup
- **Spatial entropy**: Shannon entropy of mark distribution across quadrants (normalized 0-1)
