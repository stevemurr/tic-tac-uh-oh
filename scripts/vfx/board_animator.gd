class_name BoardAnimator
extends Node

## Central animation controller for all board visual effects.
## Uses snapshot-and-diff pattern: capture state before events, animate deltas after.
## In headless mode, all animations are skipped.

signal animation_finished

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


func _get_cell(index: int) -> Control:
	if board:
		return board.get_cell_node(index)
	return null


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
	var tween := CellEffects.pop_scale(cell, 0.2)
	var color := NeonColors.for_player_dim(player)
	CellEffects.flash_color(cell, color, 0.2)
	# Spawn particle burst
	_spawn_particle_at_cell(cell_index, _place_burst_scene, NeonColors.for_player(player))
	await tween.finished


# --- Complication: Gravity ---

func animate_gravity(board_model: RefCounted) -> void:
	if _headless:
		return
	var tweens: Array[Tween] = []
	var size: int = board_model.board_size
	for col in size:
		for row in range(size - 1, -1, -1):
			var idx: int = row * size + col
			var current_mark: int = board_model.get_cell(idx)
			if current_mark == -1:
				continue
			var old_idx := -1
			for old_row in range(row, -1, -1):
				var oi: int = old_row * size + col
				if _snapshot_cells[oi] == current_mark and oi != idx:
					_snapshot_cells[oi] = -99
					old_idx = oi
					break
			if old_idx >= 0 and _snapshot_positions.has(old_idx):
				var cell := _get_cell(idx)
				if cell:
					var old_pos: Vector2 = _snapshot_positions[old_idx]
					var new_pos := cell.position
					cell.position = old_pos
					var tween := CellEffects.slide_to(cell, new_pos, 0.3)
					tweens.append(tween)
	if tweens.size() > 0:
		await tweens[tweens.size() - 1].finished


# --- Complication: Mirror Moves ---

func animate_mirror(mirror_cell: int, board_model: RefCounted) -> void:
	if _headless:
		return
	var cell := _get_cell(mirror_cell)
	if not cell:
		return
	var tween := CellEffects.pulse_glow(cell, Color(NeonColors.ACCENT.r, NeonColors.ACCENT.g, NeonColors.ACCENT.b, 0.4), 0.3, 1)
	CellEffects.pop_scale(cell, 0.2)
	await tween.finished


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
	var cell := _get_cell(blocked_cell)
	if not cell:
		return
	cell.pivot_offset = cell.custom_minimum_size / 2.0
	var tween := CellEffects.flash_color(cell, Color(NeonColors.BOMB.r, NeonColors.BOMB.g, NeonColors.BOMB.b, 0.5), 0.3)
	await tween.finished


# --- Complication: Stolen Turn ---

func animate_steal(cell_index: int, new_player: int) -> void:
	if _headless:
		return
	var cell := _get_cell(cell_index)
	if not cell:
		return
	var color := NeonColors.for_player_dim(new_player, 0.5)
	var tween := CellEffects.color_wave(cell, color, 0.3)
	CellEffects.pop_scale(cell, 0.2)
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
	tween.tween_property(grid, "rotation", deg_to_rad(90.0), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).as_relative()
	await tween.finished
	grid.rotation = 0.0


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


func clear_rotation_warning() -> void:
	if _headless or not board:
		return


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

func animate_chain_reaction(source_cell: int, removed_cells: Array[int]) -> void:
	if _headless:
		return
	var source := _get_cell(source_cell)
	if source:
		CellEffects.flash_color(source, Color(NeonColors.PLAYER_O.r, NeonColors.PLAYER_O.g, NeonColors.PLAYER_O.b, 0.5), 0.15)

	for i in removed_cells.size():
		var cell := _get_cell(removed_cells[i])
		if cell:
			cell.pivot_offset = cell.custom_minimum_size / 2.0
			if i > 0:
				await cell.get_tree().create_timer(0.1).timeout
			var tween := CellEffects.implode(cell, 0.2)
			if i == removed_cells.size() - 1:
				await tween.finished
				for idx in removed_cells:
					var c := _get_cell(idx)
					if c:
						c.scale = Vector2.ONE
						c.modulate.a = 1.0


# --- Complication: Infection ---

func animate_infection(source_cell: int, target_cells: Array[int], player: int) -> void:
	if _headless:
		return
	var color := NeonColors.for_player_dim(player, 0.5)
	for target_idx in target_cells:
		var cell := _get_cell(target_idx)
		if cell:
			CellEffects.color_wave(cell, color, 0.3)
			CellEffects.pop_scale(cell, 0.2)
	if target_cells.size() > 0:
		await board.get_tree().create_timer(0.3).timeout


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

func animate_mixup_rotation(board_model: RefCounted) -> void:
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

	board.sync_from_model(board.get_parent().get_node("BoardAnimator")._get_board_model_from_game())
	for idx in marked_cells:
		var cell := _get_cell(idx)
		if cell:
			cell.scale = Vector2.ONE
			CellEffects.pop_scale(cell, 0.3)
	await board.get_tree().create_timer(0.3).timeout


func animate_mixup_plinko(board_model: RefCounted) -> void:
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

func animate_growth(old_size: int, new_size: int) -> void:
	if _headless or not board:
		return
	for i in board.cells.size():
		var cell := _get_cell(i)
		if cell:
			cell.modulate.a = 0.0
			CellEffects.fade_in(cell, 0.3)
	await board.get_tree().create_timer(0.4).timeout


func animate_mixup(mixup_name: String, board_model: RefCounted) -> void:
	if _headless:
		return
	match mixup_name:
		"Rotation":
			await animate_mixup_rotation(board_model)
		"Earthquake":
			await animate_mixup_earthquake()
		"Shuffle":
			await animate_mixup_shuffle()
		"Plinko":
			await animate_mixup_plinko(board_model)
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
