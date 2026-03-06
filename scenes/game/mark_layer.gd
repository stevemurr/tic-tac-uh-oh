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
		_draw_beveled_line(a * first_progress, b * first_progress, color, thickness, cell.mark_alpha, size_px)
	if second_progress > 0.0:
		_draw_beveled_line(c * second_progress, d * second_progress, color, thickness, cell.mark_alpha, size_px)
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
	_draw_beveled_arc(radius, color, thickness, cell.mark_alpha, progress, size_px)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_beveled_line(from: Vector2, to: Vector2, color: Color, thickness: float, alpha: float, size_px: float) -> void:
	var shadow_offset := Vector2(size_px * 0.03, size_px * 0.035)
	var shadow := Color(0.01, 0.01, 0.02, 0.30 * alpha)
	var edge := Color(color.darkened(0.35).r, color.darkened(0.35).g, color.darkened(0.35).b, 0.62 * alpha)
	var body := Color(color.lightened(0.04).r, color.lightened(0.04).g, color.lightened(0.04).b, alpha)
	var glow := Color(color.r, color.g, color.b, 0.16 * alpha)
	var highlight_offset := Vector2(-size_px * 0.014, -size_px * 0.02)
	var highlight := Color(1.0, 0.98, 0.94, 0.22 * alpha)

	draw_line(from + shadow_offset, to + shadow_offset, shadow, thickness * 1.7, true)
	draw_line(from, to, glow, thickness * 2.2, true)
	draw_line(from, to, edge, thickness * 1.38, true)
	draw_line(from, to, body, thickness, true)
	draw_line(from + highlight_offset, to + highlight_offset, highlight, thickness * 0.22, true)

func _draw_beveled_arc(radius: float, color: Color, thickness: float, alpha: float, progress: float, size_px: float) -> void:
	var arc_end := -PI * 0.5 + TAU * progress
	var points := maxi(int(48 * progress), 6)
	var shadow_offset := Vector2(size_px * 0.03, size_px * 0.035)
	var shadow := Color(0.01, 0.01, 0.02, 0.30 * alpha)
	var edge := Color(color.darkened(0.35).r, color.darkened(0.35).g, color.darkened(0.35).b, 0.62 * alpha)
	var body := Color(color.lightened(0.04).r, color.lightened(0.04).g, color.lightened(0.04).b, alpha)
	var glow := Color(color.r, color.g, color.b, 0.16 * alpha)
	var highlight_offset := Vector2(-size_px * 0.014, -size_px * 0.02)
	var highlight := Color(1.0, 0.98, 0.94, 0.2 * alpha)

	draw_arc(Vector2.ZERO + shadow_offset, radius, -PI * 0.5, arc_end, points, shadow, thickness * 1.7, true)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, points, glow, thickness * 2.2, true)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, points, edge, thickness * 1.38, true)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, points, body, thickness, true)
	draw_arc(Vector2.ZERO + highlight_offset, radius, -PI * 0.5, arc_end, points, highlight, thickness * 0.22, true)

func _draw_blocked_slash() -> void:
	var size_px := minf(size.x, size.y)
	var margin := size_px * 0.28
	draw_line(Vector2(margin, margin), Vector2(size.x - margin, size.y - margin), Color(0.96, 0.54, 0.42, 0.18), 5.0, true)
