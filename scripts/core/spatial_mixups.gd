class_name SpatialMixups
extends RefCounted

static func apply_random(board: BoardModel) -> String:
	var choice: int = randi() % 7

	if choice == 0:
		_apply_rotation(board)
		return "Rotation"
	elif choice == 1:
		_apply_earthquake(board)
		return "Earthquake"
	elif choice == 2:
		_apply_shuffle(board)
		return "Shuffle"
	elif choice == 3:
		_apply_plinko(board)
		return "Plinko"
	elif choice == 4:
		_apply_mirror(board)
		return "Mirror"
	elif choice == 5:
		_apply_spiral(board)
		return "Spiral"
	else:
		_apply_vortex(board)
		return "Vortex"


static func apply_by_name(board: BoardModel, name: String) -> String:
	match name:
		"Rotation": _apply_rotation(board)
		"Earthquake": _apply_earthquake(board)
		"Shuffle": _apply_shuffle(board)
		"Plinko": _apply_plinko(board)
		"Mirror": _apply_mirror(board)
		"Spiral": _apply_spiral(board)
		"Vortex": _apply_vortex(board)
		_: return ""
	return name


static func get_all_names() -> Array[String]:
	return ["Rotation", "Earthquake", "Shuffle", "Plinko", "Mirror", "Spiral", "Vortex"]


static func _apply_rotation(board: BoardModel) -> void:
	# Rotate 90, 180, or 270 degrees randomly
	var rotations: int = [1, 2, 3][randi() % 3]
	for i in rotations:
		board.rotate_clockwise()

static func _apply_earthquake(board: BoardModel) -> void:
	# Each mark has 50% chance to shift to an adjacent empty cell
	var size := board.board_size
	# Process in random order to avoid bias
	var indices: Array[int] = []
	for i in board.cell_count:
		indices.append(i)
	indices.shuffle()

	for idx in indices:
		if board.get_cell(idx) == -1 or board.is_blocked(idx):
			continue
		if randf() < 0.5:
			continue
		# Try to shift to a random adjacent empty cell
		var r := board.get_row(idx)
		var c := board.get_col(idx)
		var neighbors: Array[int] = []
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				if dr == 0 and dc == 0:
					continue
				if abs(dr) + abs(dc) > 1:
					continue  # Only orthogonal neighbors
				var nr: int = r + dr
				var nc: int = c + dc
				if nr >= 0 and nr < size and nc >= 0 and nc < size:
					var ni := board.index_from_rc(nr, nc)
					if board.is_empty(ni) and not board.is_wildcard(ni):
						neighbors.append(ni)
		if not neighbors.is_empty():
			var target: int = neighbors[randi() % neighbors.size()]
			var mark := board.get_cell(idx)
			var was_wildcard := board.is_wildcard(idx)
			board.set_cell(idx, -1)
			board.set_wildcard(idx, false)
			board.set_cell(target, mark)
			if was_wildcard:
				board.set_wildcard(target, true)

static func _apply_shuffle(board: BoardModel) -> void:
	# Collect all marks, redistribute randomly
	var marks: Array[Dictionary] = []
	for i in board.cell_count:
		if board.get_cell(i) != -1 and not board.is_blocked(i):
			marks.append({"value": board.get_cell(i), "is_wildcard": board.is_wildcard(i)})
			board.set_cell(i, -1)
			board.set_wildcard(i, false)

	# Get all non-blocked positions and shuffle
	var positions: Array[int] = []
	for i in board.cell_count:
		if not board.is_blocked(i):
			positions.append(i)
	positions.shuffle()

	for idx in marks.size():
		if idx < positions.size():
			var pos: int = positions[idx]
			board.set_cell(pos, marks[idx]["value"])
			if marks[idx]["is_wildcard"]:
				board.set_wildcard(pos, true)

static func _apply_plinko(board: BoardModel) -> void:
	# Each mark shifts 1-2 cells in a random direction
	var size := board.board_size
	var indices: Array[int] = []
	for i in board.cell_count:
		indices.append(i)
	indices.shuffle()

	for idx in indices:
		if board.get_cell(idx) == -1 or board.is_blocked(idx):
			continue
		var directions := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		var dir: Vector2i = directions[randi() % directions.size()]
		var steps := 1 + randi() % 2  # 1 or 2

		var r := board.get_row(idx)
		var c := board.get_col(idx)
		var final_r := r
		var final_c := c

		for s in steps:
			var nr := final_r + dir.y
			var nc := final_c + dir.x
			if nr >= 0 and nr < size and nc >= 0 and nc < size:
				var ni := board.index_from_rc(nr, nc)
				if board.is_empty(ni) and not board.is_wildcard(ni):
					final_r = nr
					final_c = nc
				else:
					break
			else:
				break

		if final_r != r or final_c != c:
			var target := board.index_from_rc(final_r, final_c)
			var mark := board.get_cell(idx)
			var was_wildcard := board.is_wildcard(idx)
			board.set_cell(idx, -1)
			board.set_wildcard(idx, false)
			board.set_cell(target, mark)
			if was_wildcard:
				board.set_wildcard(target, true)

static func _apply_mirror(board: BoardModel) -> void:
	# Flip horizontally or vertically
	var size := board.board_size
	var flip_horizontal := randf() < 0.5

	var new_cells: Array[int] = []
	new_cells.resize(board.cell_count)
	var new_blocked: Array[bool] = []
	new_blocked.resize(board.cell_count)
	var new_wildcard: Array[bool] = []
	new_wildcard.resize(board.cell_count)

	for r in size:
		for c in size:
			var old_idx := r * size + c
			var new_idx: int
			if flip_horizontal:
				new_idx = r * size + (size - 1 - c)
			else:
				new_idx = (size - 1 - r) * size + c
			new_cells[new_idx] = board.cells[old_idx]
			new_blocked[new_idx] = board.blocked_cells[old_idx]
			new_wildcard[new_idx] = board.wildcard_cells[old_idx]

	board.cells = new_cells
	board.blocked_cells = new_blocked
	board.wildcard_cells = new_wildcard

	# Mirror bomb position
	if board.bomb_cell >= 0:
		var r := board.get_row(board.bomb_cell)
		var c := board.get_col(board.bomb_cell)
		if flip_horizontal:
			board.bomb_cell = r * size + (size - 1 - c)
		else:
			board.bomb_cell = (size - 1 - r) * size + c

static func _apply_spiral(board: BoardModel) -> void:
	# Shift marks along a spiral path (clockwise from top-left)
	var size := board.board_size
	var spiral_order: Array[int] = _get_spiral_order(size)

	# Collect marks in spiral order
	var marks_in_spiral: Array[Dictionary] = []
	for idx in spiral_order:
		marks_in_spiral.append({
			"value": board.get_cell(idx),
			"is_blocked": board.is_blocked(idx),
			"is_wildcard": board.is_wildcard(idx),
		})

	# Shift by 1 position along the spiral
	var shifted: Array[Dictionary] = []
	shifted.append(marks_in_spiral[marks_in_spiral.size() - 1])
	for i in range(0, marks_in_spiral.size() - 1):
		shifted.append(marks_in_spiral[i])

	# Write back, only moving non-blocked marks
	for i in spiral_order.size():
		var idx: int = spiral_order[i]
		if shifted[i]["is_blocked"]:
			continue
		board.set_cell(idx, shifted[i]["value"])
		board.wildcard_cells[idx] = shifted[i]["is_wildcard"]

static func _get_spiral_order(size: int) -> Array[int]:
	var order: Array[int] = []
	var top := 0
	var bottom := size - 1
	var left := 0
	var right := size - 1

	while top <= bottom and left <= right:
		# Top row
		for c in range(left, right + 1):
			order.append(top * size + c)
		top += 1
		# Right column
		for r in range(top, bottom + 1):
			order.append(r * size + right)
		right -= 1
		# Bottom row
		if top <= bottom:
			for c in range(right, left - 1, -1):
				order.append(bottom * size + c)
			bottom -= 1
		# Left column
		if left <= right:
			for r in range(bottom, top - 1, -1):
				order.append(r * size + left)
			left += 1

	return order


static func _apply_vortex(board: BoardModel) -> void:
	# Shift marks within concentric rings, alternating CW/CCW per ring.
	# Creates a twisting vortex effect where inner and outer rings rotate
	# in opposite directions.
	var size := board.board_size
	var center_r := (size - 1) / 2.0
	var center_c := (size - 1) / 2.0

	# Group cells into rings by Chebyshev distance from center
	var ring_map: Dictionary = {}  # int(dist*10) -> Array of cell indices
	for i in board.cell_count:
		var r := board.get_row(i)
		var c := board.get_col(i)
		var dist := maxf(absf(r - center_r), absf(c - center_c))
		var key := roundi(dist * 10)
		if not ring_map.has(key):
			ring_map[key] = []
		ring_map[key].append(i)

	var ring_keys: Array = ring_map.keys()
	ring_keys.sort()

	for ki in ring_keys.size():
		var key: int = ring_keys[ki]
		var ring_cells: Array = ring_map[key]

		if ring_cells.size() <= 1:
			continue

		# Order cells clockwise around the ring
		var ordered := _get_ring_cells_cw(ring_cells, size)

		# Collect non-blocked positions and their values
		var positions: Array[int] = []
		var values: Array[Dictionary] = []
		for idx in ordered:
			if not board.is_blocked(idx):
				positions.append(idx)
				values.append({
					"value": board.cells[idx],
					"is_wildcard": board.wildcard_cells[idx],
				})

		if values.size() <= 1:
			continue

		# Alternate: even rings shift CW (+1), odd rings shift CCW (-1)
		var shift := 1 if ki % 2 == 0 else -1

		# Write shifted values back
		for j in values.size():
			var src_j := (j - shift + values.size()) % values.size()
			board.cells[positions[j]] = values[src_j]["value"]
			board.wildcard_cells[positions[j]] = values[src_j]["is_wildcard"]

	# Update bomb position along its ring
	if board.bomb_cell >= 0 and not board.is_blocked(board.bomb_cell):
		var br := board.get_row(board.bomb_cell)
		var bc := board.get_col(board.bomb_cell)
		var dist := maxf(absf(br - center_r), absf(bc - center_c))
		var bkey := roundi(dist * 10)
		if ring_map.has(bkey):
			var ring_cells: Array = ring_map[bkey]
			if ring_cells.size() > 1:
				var ordered := _get_ring_cells_cw(ring_cells, size)
				var nb_positions: Array[int] = []
				for idx in ordered:
					if not board.is_blocked(idx):
						nb_positions.append(idx)
				var bomb_pos := nb_positions.find(board.bomb_cell)
				if bomb_pos >= 0 and nb_positions.size() > 1:
					var bki := ring_keys.find(bkey)
					var shift := 1 if bki % 2 == 0 else -1
					var new_pos := (bomb_pos + shift + nb_positions.size()) % nb_positions.size()
					board.bomb_cell = nb_positions[new_pos]


static func _get_ring_cells_cw(cells: Array, board_size: int) -> Array[int]:
	# Returns the given cells ordered clockwise via border traversal
	if cells.size() <= 1:
		var result: Array[int] = []
		for c in cells:
			result.append(c)
		return result

	# Find bounding box
	var min_r := board_size
	var max_r := -1
	var min_c := board_size
	var max_c := -1
	var in_ring: Dictionary = {}
	for idx in cells:
		var r: int = idx / board_size
		var c: int = idx % board_size
		min_r = mini(min_r, r)
		max_r = maxi(max_r, r)
		min_c = mini(min_c, c)
		max_c = maxi(max_c, c)
		in_ring[idx] = true

	# Traverse border clockwise: top L->R, right T+1->B, bottom R-1->L, left B-1->T+1
	var ordered: Array[int] = []

	for c in range(min_c, max_c + 1):
		var idx := min_r * board_size + c
		if in_ring.has(idx):
			ordered.append(idx)

	for r in range(min_r + 1, max_r + 1):
		var idx := r * board_size + max_c
		if in_ring.has(idx):
			ordered.append(idx)

	if max_r > min_r:
		for c in range(max_c - 1, min_c - 1, -1):
			var idx := max_r * board_size + c
			if in_ring.has(idx):
				ordered.append(idx)

	if max_c > min_c:
		for r in range(max_r - 1, min_r, -1):
			var idx := r * board_size + min_c
			if in_ring.has(idx):
				ordered.append(idx)

	return ordered
