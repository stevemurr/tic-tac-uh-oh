class_name BoardModel
extends RefCounted

var board_size: int = 3
var cell_count: int = 9

# Cell values: -1 = empty, 0 = player X, 1 = player O
var cells: Array[int] = []
var blocked_cells: Array[bool] = []
var wildcard_cells: Array[bool] = []
var bomb_cell: int = -1  # Index of bomb cell, -1 if none

func _init(size: int = 3) -> void:
	board_size = size
	cell_count = size * size
	reset()

func reset() -> void:
	cells.resize(cell_count)
	cells.fill(-1)
	blocked_cells.resize(cell_count)
	blocked_cells.fill(false)
	wildcard_cells.resize(cell_count)
	wildcard_cells.fill(false)
	bomb_cell = -1

func get_cell(index: int) -> int:
	return cells[index]

func set_cell(index: int, value: int) -> void:
	cells[index] = value

func is_empty(index: int) -> bool:
	return cells[index] == -1 and not blocked_cells[index]

func is_blocked(index: int) -> bool:
	return blocked_cells[index]

func is_wildcard(index: int) -> bool:
	return wildcard_cells[index]

func set_blocked(index: int, blocked: bool = true) -> void:
	blocked_cells[index] = blocked

func set_wildcard(index: int, wild: bool = true) -> void:
	wildcard_cells[index] = wild

func get_empty_cells() -> Array[int]:
	var empty: Array[int] = []
	for i in cell_count:
		if is_empty(i):
			empty.append(i)
	return empty

func get_playable_cells() -> Array[int]:
	var playable: Array[int] = []
	for i in cell_count:
		if is_empty(i) and not wildcard_cells[i]:
			playable.append(i)
	return playable

func get_row(index: int) -> int:
	return index / board_size

func get_col(index: int) -> int:
	return index % board_size

func index_from_rc(row: int, col: int) -> int:
	return row * board_size + col

func get_center_cell() -> int:
	return (board_size / 2) * board_size + (board_size / 2)

func get_corner_cells() -> Array[int]:
	var corners: Array[int] = []
	var last := board_size - 1
	corners.append(index_from_rc(0, 0))
	corners.append(index_from_rc(0, last))
	corners.append(index_from_rc(last, 0))
	corners.append(index_from_rc(last, last))
	return corners

func get_center_column_cells() -> Array[int]:
	var center_col := board_size / 2
	var result: Array[int] = []
	for row in board_size:
		result.append(index_from_rc(row, center_col))
	return result

func duplicate_board() -> BoardModel:
	var copy := BoardModel.new(board_size)
	copy.cells = cells.duplicate()
	copy.blocked_cells = blocked_cells.duplicate()
	copy.wildcard_cells = wildcard_cells.duplicate()
	copy.bomb_cell = bomb_cell
	return copy

func grow(new_size: int) -> void:
	var old_size := board_size
	var old_cells := cells.duplicate()
	var old_blocked := blocked_cells.duplicate()
	var old_wildcard := wildcard_cells.duplicate()
	var old_count := cell_count

	board_size = new_size
	cell_count = new_size * new_size
	reset()

	# Collect existing marks and redistribute randomly
	var marks: Array[Dictionary] = []  # [{value, is_wildcard}]
	for i in old_count:
		if old_cells[i] != -1 and not old_blocked[i]:
			marks.append({"value": old_cells[i], "is_wildcard": old_wildcard[i]})

	# Get all available positions in new board and shuffle
	var positions: Array[int] = []
	for i in cell_count:
		positions.append(i)
	positions.shuffle()

	# Place marks in shuffled positions
	for idx in marks.size():
		if idx < positions.size():
			var pos: int = positions[idx]
			cells[pos] = marks[idx]["value"]
			wildcard_cells[pos] = marks[idx]["is_wildcard"]

	# Relocate bomb if it existed
	if bomb_cell >= 0:
		var empty := get_empty_cells()
		empty = empty.filter(func(i: int) -> bool: return not wildcard_cells[i])
		if not empty.is_empty():
			bomb_cell = empty[randi() % empty.size()]
		else:
			bomb_cell = -1

# Rotate the board 90 degrees clockwise
func rotate_clockwise() -> void:
	var new_cells: Array[int] = []
	new_cells.resize(cell_count)
	var new_blocked: Array[bool] = []
	new_blocked.resize(cell_count)
	var new_wildcard: Array[bool] = []
	new_wildcard.resize(cell_count)

	for r in board_size:
		for c in board_size:
			var old_idx := index_from_rc(r, c)
			var new_idx := index_from_rc(c, board_size - 1 - r)
			new_cells[new_idx] = cells[old_idx]
			new_blocked[new_idx] = blocked_cells[old_idx]
			new_wildcard[new_idx] = wildcard_cells[old_idx]

	cells = new_cells
	blocked_cells = new_blocked
	wildcard_cells = new_wildcard

	# Rotate bomb cell position too
	if bomb_cell >= 0:
		var r := get_row(bomb_cell)
		var c := get_col(bomb_cell)
		bomb_cell = index_from_rc(c, board_size - 1 - r)

# Get horizontal mirror of a cell index (mirrored across vertical center)
func get_mirror_index(index: int) -> int:
	var r := get_row(index)
	var c := get_col(index)
	return index_from_rc(r, board_size - 1 - c)

# Apply gravity: marks fall to the lowest empty cell in their column
func apply_gravity() -> void:
	for col in board_size:
		# Collect non-empty, non-blocked marks from bottom to top
		var marks: Array[int] = []
		for row in range(board_size - 1, -1, -1):
			var idx := index_from_rc(row, col)
			if blocked_cells[idx]:
				continue
			if cells[idx] != -1:
				marks.append(cells[idx])
				cells[idx] = -1

		# Drop marks from bottom up, skipping blocked cells
		var mark_idx := 0
		for row in range(board_size - 1, -1, -1):
			var idx := index_from_rc(row, col)
			if blocked_cells[idx]:
				continue
			if mark_idx < marks.size():
				cells[idx] = marks[mark_idx]
				mark_idx += 1

# Get surrounding cells for bomb explosion
func get_surrounding_cells(index: int) -> Array[int]:
	var surrounding: Array[int] = []
	var r := get_row(index)
	var c := get_col(index)
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if dr == 0 and dc == 0:
				continue
			var nr := r + dr
			var nc := c + dc
			if nr >= 0 and nr < board_size and nc >= 0 and nc < board_size:
				surrounding.append(index_from_rc(nr, nc))
	return surrounding

# Clear surrounding cells (bomb explosion)
func explode_bomb(index: int) -> Array[int]:
	var cleared: Array[int] = []
	for idx in get_surrounding_cells(index):
		if cells[idx] != -1 and not blocked_cells[idx]:
			cells[idx] = -1
			cleared.append(idx)
	return cleared

func get_edge_corner_cells() -> Array[int]:
	# All border cells for any NxN board
	var result: Array[int] = []
	for i in cell_count:
		var r := get_row(i)
		var c := get_col(i)
		if r == 0 or r == board_size - 1 or c == 0 or c == board_size - 1:
			result.append(i)
	return result
