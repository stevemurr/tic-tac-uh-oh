extends Control

signal cell_pressed(index: int)

var cells: Array[Node] = []
var _current_size: int = 3

@onready var grid: GridContainer = $GridContainer

const BASE_CELL_SIZE := 100.0
const GRID_SEPARATION := 4
const MAX_GRID_PX := 312.0  # 3 * 100 + 2 * 4 + padding

func _ready() -> void:
	_setup_cells(3)

func _setup_cells(size: int) -> void:
	_current_size = size

	# Clear existing cells
	for cell in cells:
		cell.queue_free()
	cells.clear()

	grid.columns = size

	var cell_px := _compute_cell_size(size)
	var cell_scene := preload("res://scenes/game/cell.tscn")
	for i in size * size:
		var cell := cell_scene.instantiate()
		cell.cell_index = i
		cell.custom_minimum_size = Vector2(cell_px, cell_px)
		cell.cell_clicked.connect(_on_cell_clicked)
		grid.add_child(cell)
		cells.append(cell)

	# Resize grid container to fit
	var total := cell_px * size + GRID_SEPARATION * (size - 1)
	var half := total / 2.0
	grid.offset_left = -half
	grid.offset_top = -half
	grid.offset_right = half
	grid.offset_bottom = half

func rebuild_for_size(size: int) -> void:
	_setup_cells(size)

func _compute_cell_size(size: int) -> float:
	# Scale cells down so the grid fits in MAX_GRID_PX
	var available := MAX_GRID_PX - GRID_SEPARATION * (size - 1)
	var cell_px := available / size
	return maxf(cell_px, 20.0)  # Floor at 20px

func _on_cell_clicked(index: int) -> void:
	cell_pressed.emit(index)

func sync_from_model(board_model: RefCounted) -> void:
	for i in cells.size():
		var cell := cells[i] as Node
		cell.set_mark(board_model.get_cell(i))
		cell.set_blocked(board_model.is_blocked(i))
		cell.set_wildcard(board_model.is_wildcard(i))
		cell.set_bomb(i == board_model.bomb_cell and board_model.get_cell(i) == -1)

func set_cells_disabled(disabled: bool) -> void:
	for cell in cells:
		cell.disabled = disabled

func play_cell_animation(index: int, anim_name: String) -> void:
	if index >= 0 and index < cells.size():
		var cell := cells[index]
		if anim_name == "place":
			cell.play_place_animation()
		elif anim_name == "explode":
			cell.play_explode_animation()

func get_cell_node(index: int) -> Node:
	if index >= 0 and index < cells.size():
		return cells[index]
	return null

func get_cell_position(index: int) -> Vector2:
	if index >= 0 and index < cells.size():
		return cells[index].position
	return Vector2.ZERO

func get_grid() -> GridContainer:
	return grid

func get_current_size() -> int:
	return _current_size

func reset_board() -> void:
	for cell in cells:
		cell.reset_cell()
