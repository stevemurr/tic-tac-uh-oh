class_name BoardAnimator
extends Node

## Central animation controller for all board visual effects.
## Uses snapshot-and-diff pattern: capture state before events, animate deltas after.
## In headless mode, all animations are skipped.

var board: Control  # Board node
var _headless: bool = false
var _bomb_shader: Shader
var _wildcard_shader: Shader
var _glow_shader: Shader

# Particle scenes
var _place_burst_scene: PackedScene
var _explosion_scene: PackedScene
var _sparkle_scene: PackedScene
var _win_burst_scene: PackedScene

# Snapshot of board state before an event
var _snapshot_cells: Array[int] = []
var _snapshot_blocked: Array[bool] = []
var _snapshot_positions: Dictionary = {}  # cell_index -> Vector2


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	_bomb_shader = load("res://shaders/bomb_pulse.gdshader")
	_wildcard_shader = load("res://shaders/wildcard_shimmer.gdshader")
	_glow_shader = load("res://shaders/cell_glow.gdshader")
	_place_burst_scene = load("res://scenes/game/particles/place_burst.tscn")
	_explosion_scene = load("res://scenes/game/particles/explosion.tscn")
	_sparkle_scene = load("res://scenes/game/particles/sparkle.tscn")
	_win_burst_scene = load("res://scenes/game/particles/win_burst.tscn")


func setup(board_node: Control) -> void:
	board = board_node


# --- Snapshot helpers ---

func take_snapshot(board_model: RefCounted) -> void:
	_snapshot_cells = board_model.cells.duplicate()
	_snapshot_blocked = board_model.blocked_cells.duplicate()
	_snapshot_positions.clear()
	if board and not _headless:
		for i in board.cells.size():
			_snapshot_positions[i] = board.cells[i].position


func was_blocked_in_snapshot(index: int) -> bool:
	return index >= 0 and index < _snapshot_blocked.size() and _snapshot_blocked[index]


func _get_cell(index: int) -> Control:
	if board:
		return board.get_cell_node(index)
	return null


func _get_grid() -> GridContainer:
	if board:
		return board.get_grid()
	return null


func _get_cell_center_in_grid(cell: Control) -> Vector2:
	var cell_size: Vector2 = cell.size
	if cell_size == Vector2.ZERO:
		cell_size = cell.custom_minimum_size
	return cell.position + cell_size / 2.0


func _make_orb_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.96)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.3
	style.corner_radius_top_left = 64
	style.corner_radius_top_right = 64
	style.corner_radius_bottom_right = 64
	style.corner_radius_bottom_left = 64
	style.corner_detail = 20
	style.expand_margin_left = 1.0
	style.expand_margin_top = 1.0
	style.expand_margin_right = 1.0
	style.expand_margin_bottom = 1.0
	style.shadow_color = Color(color.r, color.g, color.b, 0.35)
	style.shadow_size = 12
	return style


func _emit_energy_orb(source_cell: Control, target_cell: Control, color: Color, duration: float = 0.22, delay: float = 0.0) -> Tween:
	var grid := _get_grid()
	if not grid or not source_cell or not target_cell:
		return null

	var orb := Panel.new()
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.size = Vector2(16, 16)
	orb.pivot_offset = orb.size / 2.0
	orb.position = _get_cell_center_in_grid(source_cell) - orb.size / 2.0
	orb.scale = Vector2(0.4, 0.4)
	orb.modulate.a = 0.0
	orb.z_index = 25
	orb.add_theme_stylebox_override("panel", _make_orb_style(color))
	grid.add_child(orb)

	var target_pos: Vector2 = _get_cell_center_in_grid(target_cell) - orb.size / 2.0
	var tween := orb.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(orb, "position", target_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(orb, "modulate:a", 1.0, duration * 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(orb, "scale", Vector2.ONE, duration * 0.35).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(orb, "scale", Vector2(0.2, 0.2), duration * 0.42).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(orb, "modulate:a", 0.0, duration * 0.42).set_ease(Tween.EASE_IN)
	tween.finished.connect(orb.queue_free)
	return tween


func _get_edge_indices(size: int) -> Array[int]:
	var indices: Array[int] = []
	for row in size:
		for col in size:
			if row == 0 or row == size - 1 or col == 0 or col == size - 1:
				indices.append(row * size + col)
	return indices


func _get_edge_entry_direction(index: int, size: int) -> Vector2:
	var row := index / size
	var col := index % size
	var dir := Vector2.ZERO
	if row == 0:
		dir.y = -1.0
	elif row == size - 1:
		dir.y = 1.0
	if col == 0:
		dir.x = -1.0
	elif col == size - 1:
		dir.x = 1.0
	if dir == Vector2.ZERO:
		var center := float(size - 1) * 0.5
		dir = Vector2(signf(float(col) - center), signf(float(row) - center))
	if dir == Vector2.ZERO:
		return Vector2.UP
	return dir.normalized()


func _get_support_cells(source_cell: int, player: int, board_model: RefCounted) -> Array[Control]:
	var support_cells: Array[Control] = []
	var source := _get_cell(source_cell)
	if source:
		support_cells.append(source)
	if not board_model:
		return support_cells

	for idx in board_model.get_surrounding_cells(source_cell):
		if board_model.get_cell(idx) == player:
			var support := _get_cell(idx)
			if support:
				support_cells.append(support)
	return support_cells


# --- Particle helpers ---

func _spawn_particle_at_cell(cell_index: int, scene: PackedScene, color: Color = Color.WHITE) -> void:
	if _headless or not scene:
		return
	var cell := _get_cell(cell_index)
	if not cell:
		return
	var particles: GPUParticles2D = scene.instantiate()
	particles.position = cell.custom_minimum_size / 2.0
	# Set particle color
	if particles.process_material is ParticleProcessMaterial:
		var mat: ParticleProcessMaterial = particles.process_material.duplicate()
		mat.color = color
		particles.process_material = mat
	cell.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


# --- Mark placement animation ---

func animate_place(cell_index: int, player: int) -> void:
	if _headless:
		return
	var cell := _get_cell(cell_index)
	if not cell:
		return
	cell.pivot_offset = cell.custom_minimum_size / 2.0
	cell.mark_alpha = 0.0
	cell.mark_scale = Vector2(0.72, 0.72)
	cell.mark_progress = 0.0
	var tween := cell.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cell, "mark_alpha", 1.0, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "mark_progress", 1.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cell, "mark_scale", Vector2(1.16, 1.16), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(cell, "mark_scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)
	var color := NeonColors.for_player_dim(player)
	CellEffects.flash_color(cell, color, 0.2)
	# Spawn particle burst
	_spawn_particle_at_cell(cell_index, _place_burst_scene, NeonColors.for_player(player))
	await tween.finished


# --- Complication: Gravity ---

func animate_gravity(board_model: RefCounted, pre_gravity_cells: Array[int]) -> void:
	if _headless or pre_gravity_cells.is_empty():
		return
	var moved_cells: Array[Control] = []
	var max_duration := 0.0
	var size: int = board_model.board_size
	for col in size:
		var source_marks: Array[int] = []
		var target_marks: Array[int] = []
		for row in range(size - 1, -1, -1):
			var idx: int = row * size + col
			if board_model.is_blocked(idx):
				continue
			if idx < pre_gravity_cells.size() and pre_gravity_cells[idx] != -1:
				source_marks.append(idx)
			if board_model.get_cell(idx) != -1:
				target_marks.append(idx)

		var pair_count := mini(source_marks.size(), target_marks.size())
		for i in pair_count:
			var source_idx := source_marks[i]
			var target_idx := target_marks[i]
			if source_idx == target_idx:
				continue

			var target_cell := _get_cell(target_idx)
			if not target_cell or not target_cell.has_method("get_mark_layer"):
				continue
			if not _snapshot_positions.has(source_idx) or not _snapshot_positions.has(target_idx):
				continue

			var mark_layer: Control = target_cell.get_mark_layer()
			if not mark_layer:
				continue

			var offset: Vector2 = _snapshot_positions[source_idx] - _snapshot_positions[target_idx]
			var drop_distance := absf(offset.y)
			var duration := clampf(drop_distance / maxf(target_cell.custom_minimum_size.y * 5.0, 1.0), 0.18, 0.42)
			var mark_color := NeonColors.for_player(board_model.get_cell(target_idx))

			target_cell.z_index = 10
			target_cell.mark_alpha = 1.0
			target_cell.mark_scale = Vector2(0.96, 1.08)
			target_cell.mark_progress = 1.0
			mark_layer.position = offset
			mark_layer.rotation = clampf(offset.y / 900.0, -0.08, 0.08)

			var tween := target_cell.create_tween()
			tween.tween_property(mark_layer, "position", Vector2(0, 10), duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tween.parallel().tween_property(mark_layer, "rotation", 0.0, duration * 0.85).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(target_cell, "mark_scale", Vector2(1.04, 0.9), duration).set_ease(Tween.EASE_IN)
			tween.tween_property(mark_layer, "position", Vector2.ZERO, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
			tween.parallel().tween_property(target_cell, "mark_scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			CellEffects.flash_color(target_cell, Color(mark_color.r, mark_color.g, mark_color.b, 0.12), duration * 0.75)
			moved_cells.append(target_cell)
			max_duration = maxf(max_duration, duration + 0.14)

	if moved_cells.is_empty():
		return

	await board.get_tree().create_timer(max_duration + 0.02).timeout
	for cell in moved_cells:
		cell.z_index = 0
		cell.mark_scale = Vector2.ONE
		var mark_layer: Control = cell.get_mark_layer()
		if mark_layer:
			mark_layer.position = Vector2.ZERO
			mark_layer.rotation = 0.0


# --- Complication: Mirror Moves ---

func animate_mirror(source_cell: int, mirror_cell: int, player: int) -> void:
	if _headless:
		return
	var cell := _get_cell(mirror_cell)
	var source := _get_cell(source_cell)
	if not cell or not source or not cell.has_method("get_mark_layer"):
		return
	var mark_layer: Control = cell.get_mark_layer()
	if not mark_layer:
		return

	var offset: Vector2 = source.position - cell.position
	cell.z_index = 10
	cell.mark_alpha = 0.0
	cell.mark_scale = Vector2(0.9, 0.9)
	cell.mark_progress = 0.0
	mark_layer.position = offset

	var tween := cell.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mark_layer, "position", Vector2.ZERO, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cell, "mark_alpha", 1.0, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "mark_progress", 1.0, 0.14).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "mark_scale", Vector2(1.08, 1.08), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(cell, "mark_scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	CellEffects.pulse_glow(cell, Color(NeonColors.ACCENT.r, NeonColors.ACCENT.g, NeonColors.ACCENT.b, 0.4), 0.22, 1)
	await tween.finished
	mark_layer.position = Vector2.ZERO
	cell.z_index = 0


# --- Complication: The Bomb ---

func animate_bomb_explode(bomb_cell: int, cleared_cells: Array[int]) -> void:
	if _headless:
		return
	var bomb := _get_cell(bomb_cell)
	if bomb:
		bomb.pivot_offset = bomb.custom_minimum_size / 2.0
		var tween := bomb.create_tween()
		tween.tween_property(bomb, "scale", Vector2(1.5, 1.5), 0.1)
		CellEffects.flash_color(bomb, Color.WHITE, 0.1)
		await tween.finished
		var tween2 := bomb.create_tween()
		tween2.tween_property(bomb, "scale", Vector2.ONE, 0.1)
		await tween2.finished

	# Spawn explosion particles
	_spawn_particle_at_cell(bomb_cell, _explosion_scene, NeonColors.BOMB)

	# Animate cleared cells
	var tweens: Array[Tween] = []
	for idx in cleared_cells:
		var cell := _get_cell(idx)
		if cell:
			var t := CellEffects.flash_color(cell, Color(NeonColors.BOMB.r, NeonColors.BOMB.g, NeonColors.BOMB.b, 0.6), 0.4)
			tweens.append(t)
	if tweens.size() > 0:
		await tweens[tweens.size() - 1].finished


func apply_bomb_ambient(bomb_index: int) -> void:
	if _headless or bomb_index < 0:
		return
	var cell := _get_cell(bomb_index)
	if cell and _bomb_shader:
		cell.set_shader_material(_bomb_shader)


func clear_bomb_ambient(bomb_index: int) -> void:
	if _headless or bomb_index < 0:
		return
	var cell := _get_cell(bomb_index)
	if cell:
		cell.clear_shader_material()


# --- Complication: Shrinking Board ---

func animate_shrink(blocked_cell: int) -> void:
	if _headless:
		return
	var size: int = board.get_current_size()
	var pulse_color := Color(0.84, 0.9, 0.96, 0.22)
	for idx in _get_edge_indices(size):
		if idx == blocked_cell:
			continue
		var edge_cell := _get_cell(idx)
		if edge_cell:
			CellEffects.flash_color(edge_cell, pulse_color, 0.12)

	var cell := _get_cell(blocked_cell)
	if not cell:
		return
	cell.pivot_offset = cell.custom_minimum_size / 2.0
	var collapse_dir: Vector2 = _get_edge_entry_direction(blocked_cell, size) * 18.0
	var mark_layer: Control = cell.get_mark_layer()
	if mark_layer:
		mark_layer.position = collapse_dir
		mark_layer.scale = Vector2(1.24, 1.24)
		mark_layer.modulate.a = 0.0

	var tween := cell.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cell, "scale", Vector2(1.05, 1.05), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "rotation", deg_to_rad(3.0) * signf(collapse_dir.x + collapse_dir.y), 0.08).set_ease(Tween.EASE_OUT)
	if mark_layer:
		tween.tween_property(mark_layer, "position", Vector2.ZERO, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(mark_layer, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(mark_layer, "modulate:a", 1.0, 0.1).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(cell, "scale", Vector2(0.92, 0.92), 0.1).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(cell, "rotation", 0.0, 0.14).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(cell, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	CellEffects.flash_color(cell, Color(0.84, 0.9, 0.96, 0.48), 0.32)
	await tween.finished
	if mark_layer:
		mark_layer.position = Vector2.ZERO
		mark_layer.scale = Vector2.ONE
		mark_layer.modulate.a = 1.0


# --- Complication: Stolen Turn ---

func animate_steal(cell_index: int, new_player: int) -> void:
	if _headless:
		return
	var cell := _get_cell(cell_index)
	if not cell:
		return
	var color := NeonColors.for_player_dim(new_player, 0.5)
	cell.mark_alpha = 0.0
	cell.mark_scale = Vector2(0.64, 0.64)
	cell.mark_progress = 0.0
	var tween := cell.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cell, "mark_alpha", 1.0, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "mark_progress", 1.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cell, "mark_scale", Vector2(1.12, 1.12), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(cell, "mark_scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	CellEffects.color_wave(cell, color, 0.3)
	await tween.finished


# --- Complication: Wildcard Cell ---

func animate_wildcard_spawn(cell_index: int) -> void:
	if _headless:
		return
	var cell := _get_cell(cell_index)
	if not cell:
		return
	# Spawn sparkle particles
	_spawn_particle_at_cell(cell_index, _sparkle_scene, NeonColors.WILDCARD)
	# Sparkle burst: create temporary ColorRects that scale up and fade
	var sparkle_colors := [NeonColors.WILDCARD, NeonColors.ACCENT, NeonColors.PLAYER_X, NeonColors.PLAYER_O]
	var sparkle_tweens: Array[Tween] = []
	for i in 5:
		var spark := ColorRect.new()
		spark.size = Vector2(4, 4)
		spark.position = cell.custom_minimum_size / 2.0 - Vector2(2, 2)
		spark.color = sparkle_colors[i % sparkle_colors.size()]
		spark.pivot_offset = Vector2(2, 2)
		cell.add_child(spark)
		var angle := TAU * i / 5.0
		var offset := Vector2(cos(angle), sin(angle)) * 20.0
		var t := cell.create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "position", spark.position + offset, 0.4).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector2(3, 3), 0.2)
		t.tween_property(spark, "modulate:a", 0.0, 0.4)
		t.chain().tween_callback(spark.queue_free)
		sparkle_tweens.append(t)
	if sparkle_tweens.size() > 0:
		await sparkle_tweens[0].finished


func apply_wildcard_ambient(cell_index: int) -> void:
	if _headless or cell_index < 0:
		return
	var cell := _get_cell(cell_index)
	if cell and _wildcard_shader:
		cell.set_shader_material(_wildcard_shader)


# --- Complication: Rotating Board ---

func animate_board_rotation() -> void:
	if _headless or not board:
		return
	var grid: GridContainer = board.get_grid()
	if not grid:
		return
	grid.pivot_offset = grid.size / 2.0
	var tween := grid.create_tween()
	tween.set_parallel(true)
	tween.tween_property(grid, "rotation", deg_to_rad(90.0), 0.42).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).as_relative()
	tween.tween_property(grid, "scale", Vector2(1.03, 1.03), 0.16).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(grid, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished
	grid.rotation = 0.0
	grid.scale = Vector2.ONE


func apply_rotation_warning() -> void:
	if _headless or not board:
		return
	for i in board.cells.size():
		var cell := _get_cell(i)
		if cell:
			var eff_overlay: ColorRect = cell.get_effect_overlay()
			if eff_overlay:
				eff_overlay.visible = true
				eff_overlay.color = Color(NeonColors.WILDCARD.r, NeonColors.WILDCARD.g, NeonColors.WILDCARD.b, 0.1)


# --- Complication: Time Pressure ---

func animate_time_pressure(time_left: float) -> void:
	if _headless or not board:
		return
	if time_left < 3.0 and time_left > 1.0:
		var grid: GridContainer = board.get_grid()
		if grid:
			var pulse := fmod(time_left * 3.0, 1.0)
			grid.modulate = Color(1.0, 1.0 - pulse * 0.3, 1.0 - pulse * 0.3)
	elif time_left <= 1.0 and time_left > 0.0:
		var grid: GridContainer = board.get_grid()
		if grid:
			var flash := fmod(time_left * 8.0, 1.0)
			grid.modulate = Color(1.0, 0.5 + flash * 0.5, 0.5 + flash * 0.5)


func animate_timeout() -> void:
	if _headless or not board:
		return
	var grid: GridContainer = board.get_grid()
	if not grid:
		return
	var original_pos := grid.position
	var tween := grid.create_tween()
	for i in 6:
		var offset := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tween.tween_property(grid, "position", original_pos + offset, 0.05)
	tween.tween_property(grid, "position", original_pos, 0.05)
	await tween.finished
	grid.modulate = Color.WHITE


# --- Complication: Decay ---

func animate_decay_remove(cell_index: int) -> void:
	if _headless:
		return
	var cell := _get_cell(cell_index)
	if not cell:
		return
	cell.pivot_offset = cell.custom_minimum_size / 2.0
	if cell.get_mark() == 0 or cell.get_mark() == 1:
		var tween := cell.create_tween()
		tween.set_parallel(true)
		tween.tween_property(cell, "mark_scale", Vector2(1.5, 1.5), 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(cell, "mark_alpha", 0.0, 0.3)
		await tween.finished
		cell.mark_scale = Vector2.ONE
		cell.mark_alpha = 1.0
		return

	var label_node: Label = cell.get_label()
	if label_node:
		var tween := cell.create_tween()
		tween.set_parallel(true)
		tween.tween_property(label_node, "scale", Vector2(1.5, 1.5), 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(label_node, "modulate:a", 0.0, 0.3)
		await tween.finished
		label_node.scale = Vector2.ONE
		label_node.modulate.a = 1.0


func apply_decay_warning(cell_index: int, turns_remaining: int) -> void:
	if _headless:
		return
	var cell := _get_cell(cell_index)
	if not cell:
		return
	var alpha := 1.0 - (6 - turns_remaining) * 0.15
	alpha = clampf(alpha, 0.3, 1.0)
	cell.modulate.a = alpha


# --- Complication: Aftershock ---

func animate_aftershock_warning() -> void:
	if _headless or not board:
		return
	var grid: GridContainer = board.get_grid()
	if not grid:
		return
	var original_pos := grid.position
	var tween := grid.create_tween()
	for i in 3:
		var offset := Vector2(randf_range(-4, 4), randf_range(-4, 4))
		tween.tween_property(grid, "position", original_pos + offset, 0.05)
	tween.tween_property(grid, "position", original_pos, 0.05)
	await tween.finished


# --- Complication: Chain Reaction ---

func animate_chain_reaction(source_cell: int, removed_cells: Array[int], player: int, board_model: RefCounted) -> void:
	if _headless or removed_cells.is_empty():
		return
	var charge_color := Color(1.0, 0.28, 0.58)
	var support_cells := _get_support_cells(source_cell, player, board_model)
	for support in support_cells:
		support.mark_scale = Vector2(1.08, 1.08)
		var support_tween := support.create_tween()
		support_tween.tween_property(support, "mark_scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		CellEffects.flash_color(support, Color(charge_color.r, charge_color.g, charge_color.b, 0.3), 0.18)

	var max_duration := 0.0
	for target_i in removed_cells.size():
		var cell := _get_cell(removed_cells[target_i])
		if not cell:
			continue

		cell.pivot_offset = cell.custom_minimum_size / 2.0
		var delay := float(target_i) * 0.1
		for support_i in support_cells.size():
			_emit_energy_orb(support_cells[support_i], cell, charge_color, 0.18, delay + float(support_i) * 0.04)

		_spawn_particle_at_cell(removed_cells[target_i], _explosion_scene, charge_color)
		CellEffects.flash_color(cell, Color(charge_color.r, charge_color.g, charge_color.b, 0.62), 0.28)

		var tween := cell.create_tween()
		if delay > 0.0:
			tween.tween_interval(delay + 0.06)
		else:
			tween.tween_interval(0.06)
		tween.set_parallel(true)
		tween.tween_property(cell, "scale", Vector2(1.12, 1.12), 0.08).set_ease(Tween.EASE_OUT)
		tween.tween_property(cell, "rotation", deg_to_rad(8.0) * (-1.0 if target_i % 2 == 0 else 1.0), 0.08).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(cell, "scale", Vector2(0.8, 0.8), 0.08).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(cell, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_IN)
		tween.chain().tween_property(cell, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(cell, "modulate:a", 1.0, 0.12).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(cell, "rotation", 0.0, 0.12).set_ease(Tween.EASE_OUT)
		max_duration = maxf(max_duration, delay + 0.38)

	if max_duration > 0.0:
		await board.get_tree().create_timer(max_duration + 0.03).timeout


# --- Complication: Infection ---

func animate_infection(source_cell: int, target_cells: Array[int], player: int) -> void:
	if _headless or target_cells.is_empty():
		return
	var source := _get_cell(source_cell)
	var infection_color := Color(0.36, 1.0, 0.48)
	if source:
		CellEffects.flash_color(source, Color(infection_color.r, infection_color.g, infection_color.b, 0.26), 0.18)
		source.mark_scale = Vector2(1.06, 1.06)
		var source_tween := source.create_tween()
		source_tween.tween_property(source, "mark_scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var max_duration := 0.0
	for i in target_cells.size():
		var target_idx := target_cells[i]
		var cell := _get_cell(target_idx)
		if cell:
			var delay := float(i) * 0.05
			if source:
				_emit_energy_orb(source, cell, infection_color, 0.18, delay)

			cell.z_index = 10
			cell.mark_alpha = 0.18
			cell.mark_progress = 0.0
			cell.mark_scale = Vector2(0.8, 1.18)
			var mark_layer: Control = cell.get_mark_layer()
			if mark_layer:
				mark_layer.position = Vector2(0, -8)
				mark_layer.rotation = -0.1 if i % 2 == 0 else 0.1

			CellEffects.flash_color(cell, Color(infection_color.r, infection_color.g, infection_color.b, 0.45), 0.3)
			_spawn_particle_at_cell(target_idx, _sparkle_scene, infection_color)

			var tween := cell.create_tween()
			if delay > 0.0:
				tween.tween_interval(delay)
			tween.set_parallel(true)
			tween.tween_property(cell, "mark_alpha", 1.0, 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(cell, "mark_progress", 1.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(cell, "mark_scale", Vector2(1.16, 0.9), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			if mark_layer:
				tween.tween_property(mark_layer, "position", Vector2.ZERO, 0.16).set_ease(Tween.EASE_OUT)
				tween.tween_property(mark_layer, "rotation", 0.0, 0.16).set_ease(Tween.EASE_OUT)
			tween.chain().tween_property(cell, "mark_scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			max_duration = maxf(max_duration, delay + 0.3)

	if max_duration > 0.0:
		await board.get_tree().create_timer(max_duration + 0.03).timeout
		for target_idx in target_cells:
			var cell := _get_cell(target_idx)
			if cell:
				cell.z_index = 0


# --- Win Line Animation ---

func animate_win_line(winning_cells: Array[int], player: int) -> void:
	if _headless:
		return
	var color := NeonColors.for_player(player)
	for cell_index in winning_cells:
		var cell := _get_cell(cell_index)
		if cell:
			cell.pivot_offset = cell.custom_minimum_size / 2.0
			CellEffects.pulse_glow(cell, Color(color.r, color.g, color.b, 0.6), 0.6, 3)
			_spawn_particle_at_cell(cell_index, _win_burst_scene, color)
	if winning_cells.size() > 0:
		await board.get_tree().create_timer(0.8).timeout


# --- Spatial Mixup Animations ---

func animate_mixup_rotation() -> void:
	if _headless or not board:
		return
	var grid: GridContainer = board.get_grid()
	if not grid:
		return
	grid.pivot_offset = grid.size / 2.0
	var tween := grid.create_tween()
	tween.tween_property(grid, "rotation", deg_to_rad(90.0), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).as_relative()
	await tween.finished
	grid.rotation = 0.0


func animate_mixup_earthquake() -> void:
	if _headless or not board:
		return
	var tweens: Array[Tween] = []
	for i in board.cells.size():
		var cell := _get_cell(i)
		if cell:
			var t := CellEffects.shake(cell, 3.0, 0.3)
			tweens.append(t)
	if tweens.size() > 0:
		await tweens[0].finished
	await _animate_snapshot_diff(0.3)


func animate_mixup_shuffle() -> void:
	if _headless or not board:
		return
	var marked_cells: Array[int] = []
	for i in _snapshot_cells.size():
		if _snapshot_cells[i] != -1:
			marked_cells.append(i)

	var lift_tweens: Array[Tween] = []
	for idx in marked_cells:
		var cell := _get_cell(idx)
		if cell:
			cell.pivot_offset = cell.custom_minimum_size / 2.0
			var t := cell.create_tween()
			t.set_parallel(true)
			t.tween_property(cell, "scale", Vector2(1.1, 1.1), 0.2)
			t.tween_property(cell, "position:y", cell.position.y - 5, 0.2)
			lift_tweens.append(t)
	if lift_tweens.size() > 0:
		await lift_tweens[0].finished

	await board.get_tree().create_timer(0.1).timeout

	var board_model := _get_board_model_from_game()
	if board_model:
		board.sync_from_model(board_model)
	for idx in marked_cells:
		var cell := _get_cell(idx)
		if cell:
			cell.scale = Vector2.ONE
			CellEffects.pop_scale(cell, 0.3)
	await board.get_tree().create_timer(0.3).timeout


func animate_mixup_plinko() -> void:
	if _headless or not board:
		return
	await _animate_snapshot_diff(0.3)


func animate_mixup_mirror() -> void:
	if _headless or not board:
		return
	var grid: GridContainer = board.get_grid()
	if not grid:
		return
	var line := ColorRect.new()
	line.color = Color(NeonColors.ACCENT.r, NeonColors.ACCENT.g, NeonColors.ACCENT.b, 0.6)
	line.size = Vector2(2, grid.size.y)
	line.position = Vector2(0, 0)
	grid.add_child(line)

	var tween := grid.create_tween()
	tween.tween_property(line, "position:x", grid.size.x, 0.4).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	line.queue_free()


func animate_mixup_spiral() -> void:
	if _headless or not board:
		return
	await _animate_snapshot_diff(0.4)


func animate_mixup_vortex() -> void:
	if _headless or not board:
		return
	await _animate_snapshot_diff(0.4)


# --- Board Growth Animation ---

func animate_growth() -> void:
	if _headless or not board:
		return
	for i in board.cells.size():
		var cell := _get_cell(i)
		if cell:
			cell.modulate.a = 0.0
			CellEffects.fade_in(cell, 0.3)
	await board.get_tree().create_timer(0.4).timeout


func animate_mixup(mixup_name: String) -> void:
	if _headless:
		return
	match mixup_name:
		"Rotation":
			await animate_mixup_rotation()
		"Earthquake":
			await animate_mixup_earthquake()
		"Shuffle":
			await animate_mixup_shuffle()
		"Plinko":
			await animate_mixup_plinko()
		"Mirror":
			await animate_mixup_mirror()
		"Spiral":
			await animate_mixup_spiral()
		"Vortex":
			await animate_mixup_vortex()


# --- Ambient Effects ---

func apply_ambient_effects(board_model: RefCounted, complications: Array) -> void:
	if _headless or not board:
		return
	for comp in complications:
		if not comp.is_active:
			continue
		match comp.complication_id:
			"the_bomb":
				if board_model.bomb_cell >= 0:
					apply_bomb_ambient(board_model.bomb_cell)
			"wildcard_cell":
				for i in board_model.cell_count:
					if board_model.is_wildcard(i):
						apply_wildcard_ambient(i)
			"rotating_board":
				var effects: Dictionary = comp.get_visual_effects()
				if effects.get("rotation_warning", 2) <= 1:
					apply_rotation_warning()
			"decay":
				_apply_decay_warnings(board_model, comp)


func _apply_decay_warnings(board_model: RefCounted, comp: ComplicationBase) -> void:
	var placements: Dictionary = comp._state.get("placement_turns", {})
	var current_turn: int = comp._state.get("global_turn", 0)
	for cell_key in placements:
		var cell: int = cell_key if cell_key is int else int(str(cell_key))
		if cell < board_model.cell_count and board_model.get_cell(cell) != -1:
			var turns_alive: int = current_turn - placements[cell_key]
			var turns_remaining: int = 6 - turns_alive
			if turns_remaining <= 3:
				apply_decay_warning(cell, turns_remaining)


# --- Internal helpers ---

func _animate_snapshot_diff(duration: float) -> void:
	if not board:
		return
	var current_size: int = board.cells.size()
	for i in current_size:
		var cell := _get_cell(i)
		if not cell:
			continue
		if _snapshot_positions.has(i) and cell.position != _snapshot_positions[i]:
			var old_pos: Vector2 = _snapshot_positions[i]
			var new_pos := cell.position
			cell.position = old_pos
			CellEffects.slide_to(cell, new_pos, duration)
	if current_size > 0:
		await board.get_tree().create_timer(duration + 0.05).timeout


func reset_grid_effects() -> void:
	if _headless or not board:
		return
	var grid: GridContainer = board.get_grid()
	if grid:
		grid.modulate = Color.WHITE
		grid.rotation = 0.0


func _get_board_model_from_game() -> RefCounted:
	var game := board.get_parent()
	if game and game.has_method("get_board_model"):
		return game.get_board_model()
	return null
