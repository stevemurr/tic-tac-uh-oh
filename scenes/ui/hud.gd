extends Control

@onready var turn_label: Label = $SafeArea/OverlayStack/TopRow/TurnPanel/TurnContent/TurnLabel
@onready var score_label: Label = $SafeArea/OverlayStack/TopRow/ScorePanel/ScoreContent/ScoreLabel
@onready var round_label: Label = $SafeArea/OverlayStack/TopRow/TurnPanel/TurnContent/RoundLabel
@onready var complication_container: Control = $SafeArea/OverlayStack/StatusPanel/StatusContent/ComplicationBar
@onready var timer_bar: ProgressBar = $SafeArea/OverlayStack/StatusPanel/StatusContent/TimerBar
@onready var steal_label: Label = $SafeArea/OverlayStack/StatusPanel/StatusContent/StealLabel
@onready var board_info_label: Label = $SafeArea/OverlayStack/TopRow/ScorePanel/ScoreContent/BoardInfoLabel
@onready var network_status_label: Label = $SafeArea/OverlayStack/StatusPanel/StatusContent/StatusHeader/NetworkStatusLabel

var _time_pressure_label: Label
var _time_pressure_limit: float = 0.0

func _ready() -> void:
	_set_mouse_passthrough(self)
	update_complications([])
	update_network_status("")

func update_turn(player: int) -> void:
	if turn_label:
		var mark := "X" if player == 0 else "O"
		turn_label.text = "Player %s" % mark
		turn_label.add_theme_color_override("font_color", NeonColors.for_player(player))

func update_scores(scores: Array[int]) -> void:
	if score_label:
		score_label.text = "X %d  |  O %d" % [scores[0], scores[1]]

func update_round(round_num: int) -> void:
	if round_label:
		round_label.text = "Round %d" % round_num

func update_board_info(board_size: int, win_length: int) -> void:
	if board_info_label:
		board_info_label.text = "%dx%d  |  %d-in-a-row" % [board_size, board_size, win_length]

func update_complications(complications: Array[ComplicationBase]) -> void:
	if not complication_container:
		return

	_time_pressure_label = null
	_time_pressure_limit = 0.0

	for child in complication_container.get_children():
		child.queue_free()

	if complications.is_empty():
		complication_container.add_child(_build_placeholder_chip())
		clear_timer()
		_set_mouse_passthrough(complication_container)
		return

	for comp in complications:
		complication_container.add_child(_build_complication_chip(comp))
	if not _time_pressure_label:
		clear_timer()
	_set_mouse_passthrough(complication_container)

func _build_placeholder_chip() -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _make_chip_style(NeonColors.DIM_OUTLINE, NeonColors.SURFACE_SOFT))

	var label := Label.new()
	label.text = "No complications active"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", NeonColors.TEXT_MUTED)
	chip.add_child(label)
	return chip

func _build_complication_chip(comp: ComplicationBase) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _make_chip_style(comp.color, Color(0.09, 0.13, 0.21, 0.95)))
	chip.tooltip_text = "%s: %s" % [comp.display_name, comp.description]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.add_theme_stylebox_override("panel", _make_chip_dot_style(comp.color))
	row.add_child(dot)

	var label := Label.new()
	label.text = comp.display_name
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", NeonColors.TEXT_DEFAULT)
	row.add_child(label)

	if comp.complication_id == "time_pressure":
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var timer_label := Label.new()
		timer_label.add_theme_font_size_override("font_size", 13)
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.7))
		row.add_child(timer_label)

		_time_pressure_label = timer_label
		_time_pressure_limit = comp.get_time_limit()
		if comp.is_timer_active():
			_update_time_pressure_chip(comp.get_time_remaining(), _time_pressure_limit, true)
		else:
			_update_time_pressure_chip(_time_pressure_limit, _time_pressure_limit, false)

	return chip

func _make_chip_style(border_color: Color, bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, minf(bg_color.a, 0.7))
	style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.56)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.12)
	style.shadow_size = 12
	style.content_margin_left = 13.0
	style.content_margin_top = 9.0
	style.content_margin_right = 13.0
	style.content_margin_bottom = 9.0
	return style

func _make_chip_dot_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_color = Color(color.r, color.g, color.b, 0.28)
	style.shadow_size = 8
	return style

func update_timer(time_left: float, time_max: float = 15.0) -> void:
	if timer_bar:
		timer_bar.visible = true
		timer_bar.max_value = time_max
		timer_bar.value = time_left

		if time_left < 3.0:
			timer_bar.modulate = Color(1.0, 0.42, 0.32)
		elif time_left < 6.0:
			timer_bar.modulate = Color(1.0, 0.72, 0.32)
		else:
			timer_bar.modulate = Color.WHITE

	_update_time_pressure_chip(time_left, time_max, true)

func clear_timer() -> void:
	if timer_bar:
		timer_bar.visible = false
		timer_bar.value = 0.0
	_update_time_pressure_chip(_time_pressure_limit, _time_pressure_limit, false)

func update_steal_available(x_steal: bool, o_steal: bool) -> void:
	if not steal_label:
		return

	var parts: Array[String] = []
	if x_steal:
		parts.append("X can steal")
	if o_steal:
		parts.append("O can steal")

	if parts.is_empty():
		steal_label.visible = false
	else:
		steal_label.visible = true
		steal_label.text = " | ".join(parts)
		steal_label.add_theme_color_override("font_color", NeonColors.ACCENT)

func update_network_status(text: String) -> void:
	if not network_status_label:
		return

	if text == "":
		network_status_label.visible = false
		return

	network_status_label.visible = true
	network_status_label.text = text

	var normalized := text.to_lower()
	if "disconnect" in normalized:
		network_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))
	elif "your turn" in normalized:
		network_status_label.add_theme_color_override("font_color", NeonColors.SUCCESS)
	else:
		network_status_label.add_theme_color_override("font_color", NeonColors.GRID_LINE_BRIGHT)

func _update_time_pressure_chip(time_left: float, time_max: float, active: bool) -> void:
	if not _time_pressure_label:
		return

	if not active:
		if time_max > 0.0:
			_time_pressure_label.text = "%ss clock" % _format_seconds(time_max)
		else:
			_time_pressure_label.text = "clock"
		_time_pressure_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.7))
		return

	var urgency := time_left / maxf(time_max, 0.001)
	_time_pressure_label.text = "T-%ss" % _format_seconds(time_left)
	if urgency <= 0.3:
		_time_pressure_label.add_theme_color_override("font_color", Color(1.0, 0.44, 0.3))
	elif urgency <= 0.6:
		_time_pressure_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.36))
	else:
		_time_pressure_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.7))

func _format_seconds(value: float) -> String:
	if value < 10.0:
		return "%.1f" % value
	return str(int(ceili(value)))

func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_set_mouse_passthrough(child)
