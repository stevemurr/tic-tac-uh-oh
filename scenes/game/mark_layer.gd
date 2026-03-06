extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var cell := get_parent()
	if cell == null:
		return

	if cell._is_blocked:
		_draw_blocked_slash()
		return

	match cell.get_mark():
		0:
			_draw_x_mark(cell, NeonColors.PLAYER_X)
		1:
			_draw_o_mark(cell, NeonColors.PLAYER_O)

func _draw_x_mark(cell: Node, color: Color) -> void:
	var size_px := minf(size.x, size.y)
	if size_px <= 0.0:
		size_px = cell.custom_minimum_size.x
	var center := size / 2.0
	var extent := size_px * 0.22
	var thickness := clampf(size_px * 0.09, 7.0, 18.0)
	var a := Vector2(-extent, -extent)
	var b := Vector2(extent, extent)
	var c := Vector2(-extent, extent)
	var d := Vector2(extent, -extent)
	var first_progress := clampf(cell.mark_progress * 2.0, 0.0, 1.0)
	var second_progress := clampf((cell.mark_progress - 0.5) * 2.0, 0.0, 1.0)

	draw_set_transform(center, 0.0, cell.mark_scale)
	if first_progress > 0.0:
		_draw_glow_line(a * first_progress, b * first_progress, color, thickness, cell.mark_alpha)
	if second_progress > 0.0:
		_draw_glow_line(c * second_progress, d * second_progress, color, thickness, cell.mark_alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_o_mark(cell: Node, color: Color) -> void:
	var size_px := minf(size.x, size.y)
	if size_px <= 0.0:
		size_px = cell.custom_minimum_size.x
	var center := size / 2.0
	var radius := size_px * 0.24
	var thickness := clampf(size_px * 0.085, 7.0, 18.0)
	var progress := maxf(cell.mark_progress, 0.02)

	draw_set_transform(center, 0.0, cell.mark_scale)
	_draw_glow_arc(radius, color, thickness, cell.mark_alpha, progress)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_glow_line(from: Vector2, to: Vector2, color: Color, thickness: float, alpha: float) -> void:
	var glow_outer := Color(color.r, color.g, color.b, 0.13 * alpha)
	var glow_mid := Color(color.r, color.g, color.b, 0.28 * alpha)
	var solid := Color(color.r, color.g, color.b, alpha)
	draw_line(from, to, glow_outer, thickness * 2.2, true)
	draw_line(from, to, glow_mid, thickness * 1.45, true)
	draw_line(from, to, solid, thickness, true)
	draw_line(from, to, Color(1, 1, 1, 0.16 * alpha), thickness * 0.22, true)

func _draw_glow_arc(radius: float, color: Color, thickness: float, alpha: float, progress: float) -> void:
	var arc_end := -PI * 0.5 + TAU * progress
	var points := maxi(int(48 * progress), 6)
	var glow_outer := Color(color.r, color.g, color.b, 0.13 * alpha)
	var glow_mid := Color(color.r, color.g, color.b, 0.28 * alpha)
	var solid := Color(color.r, color.g, color.b, alpha)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, points, glow_outer, thickness * 2.2, true)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, points, glow_mid, thickness * 1.45, true)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, points, solid, thickness, true)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, points, Color(1, 1, 1, 0.14 * alpha), thickness * 0.22, true)

func _draw_blocked_slash() -> void:
	var size_px := minf(size.x, size.y)
	var margin := size_px * 0.28
	draw_line(Vector2(margin, margin), Vector2(size.x - margin, size.y - margin), Color(1, 0.45, 0.35, 0.18), 5.0, true)
