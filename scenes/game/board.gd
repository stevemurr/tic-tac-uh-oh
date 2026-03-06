extends Control

signal cell_pressed(index: int)

var cells: Array[Node] = []
var _current_size: int = 3

@onready var frame: Panel = $Frame
@onready var frame_trim: Panel = $FrameTrim
@onready var inner_frame: Panel = $InnerFrame
@onready var grid_backdrop: Panel = $GridBackdrop
@onready var grid: GridContainer = $GridContainer

const GRID_SEPARATION := 6.0
const MIN_GRID_PX := 300.0
const MAX_GRID_PX := 560.0
const BOARD_MARGIN_X := 120.0
const BOARD_MARGIN_Y := 520.0
const FRAME_PADDING := 34.0
const TRIM_PADDING := 24.0
const INNER_PADDING := 18.0
const GRID_BACKDROP_PADDING := 12.0

func _ready() -> void:
	grid.add_theme_constant_override("h_separation", int(GRID_SEPARATION))
	grid.add_theme_constant_override("v_separation", int(GRID_SEPARATION))
	resized.connect(_refresh_layout)
	_setup_cells(3)

func _setup_cells(size: int) -> void:
	_current_size = size

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

	_layout_shell(cell_px, size)

func _layout_shell(cell_px: float, size: int) -> void:
	var total := cell_px * size + GRID_SEPARATION * (size - 1)
	var half := total / 2.0
	grid.offset_left = -half
	grid.offset_top = -half
	grid.offset_right = half
	grid.offset_bottom = half

	var inner_half := half + INNER_PADDING
	inner_frame.offset_left = -inner_half
	inner_frame.offset_top = -inner_half
	inner_frame.offset_right = inner_half
	inner_frame.offset_bottom = inner_half

	var frame_half := half + FRAME_PADDING
	frame.offset_left = -frame_half
	frame.offset_top = -frame_half
	frame.offset_right = frame_half
	frame.offset_bottom = frame_half

	if frame_trim:
		var trim_half := half + TRIM_PADDING
		frame_trim.offset_left = -trim_half
		frame_trim.offset_top = -trim_half
		frame_trim.offset_right = trim_half
		frame_trim.offset_bottom = trim_half

	if grid_backdrop:
		var backdrop_half := half + GRID_BACKDROP_PADDING
		grid_backdrop.offset_left = -backdrop_half
		grid_backdrop.offset_top = -backdrop_half
		grid_backdrop.offset_right = backdrop_half
		grid_backdrop.offset_bottom = backdrop_half

func _refresh_layout() -> void:
	if cells.is_empty():
		return

	var cell_px := _compute_cell_size(_current_size)
	for cell in cells:
		cell.custom_minimum_size = Vector2(cell_px, cell_px)
		if cell.has_method("update_display"):
			cell.update_display()

	_layout_shell(cell_px, _current_size)

func rebuild_for_size(size: int) -> void:
	_setup_cells(size)

func _get_target_grid_px() -> float:
	var viewport := get_viewport_rect().size
	var available_width := maxf(viewport.x - BOARD_MARGIN_X, MIN_GRID_PX)
	var available_height := maxf(viewport.y - BOARD_MARGIN_Y, MIN_GRID_PX)
	return clampf(minf(available_width, available_height), MIN_GRID_PX, MAX_GRID_PX)

func _compute_cell_size(size: int) -> float:
	var available := _get_target_grid_px() - GRID_SEPARATION * (size - 1)
	return maxf(available / size, 20.0)

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

func get_cell_node(index: int) -> Node:
	if index >= 0 and index < cells.size():
		return cells[index]
	return null

func get_grid() -> GridContainer:
	return grid

func get_current_size() -> int:
	return _current_size
