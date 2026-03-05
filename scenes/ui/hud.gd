extends Control

@onready var turn_label: Label = $TurnLabel
@onready var score_label: Label = $ScoreLabel
@onready var round_label: Label = $RoundLabel
@onready var complication_container: HBoxContainer = $ComplicationBar
@onready var timer_bar: ProgressBar = $TimerBar
@onready var steal_label: Label = $StealLabel
@onready var board_info_label: Label = $BoardInfoLabel

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	if not turn_label:
		turn_label = Label.new()
		turn_label.name = "TurnLabel"
		turn_label.position = Vector2(20, 10)
		turn_label.add_theme_font_size_override("font_size", 24)
		add_child(turn_label)

	if not score_label:
		score_label = Label.new()
		score_label.name = "ScoreLabel"
		score_label.position = Vector2(20, 45)
		score_label.add_theme_font_size_override("font_size", 18)
		add_child(score_label)

	if not round_label:
		round_label = Label.new()
		round_label.name = "RoundLabel"
		round_label.position = Vector2(20, 75)
		round_label.add_theme_font_size_override("font_size", 16)
		add_child(round_label)

	if not complication_container:
		complication_container = HBoxContainer.new()
		complication_container.name = "ComplicationBar"
		complication_container.position = Vector2(20, 105)
		add_child(complication_container)

	if not timer_bar:
		timer_bar = ProgressBar.new()
		timer_bar.name = "TimerBar"
		timer_bar.position = Vector2(20, 140)
		timer_bar.size = Vector2(200, 20)
		timer_bar.visible = true
		timer_bar.max_value = GameState.DEFAULT_TURN_TIME
		timer_bar.value = GameState.DEFAULT_TURN_TIME
		add_child(timer_bar)

	if not steal_label:
		steal_label = Label.new()
		steal_label.name = "StealLabel"
		steal_label.position = Vector2(20, 170)
		steal_label.add_theme_font_size_override("font_size", 14)
		steal_label.visible = false
		add_child(steal_label)

	if not board_info_label:
		board_info_label = Label.new()
		board_info_label.name = "BoardInfoLabel"
		board_info_label.position = Vector2(20, 195)
		board_info_label.add_theme_font_size_override("font_size", 14)
		board_info_label.add_theme_color_override("font_color", NeonColors.GRID_LINE_BRIGHT)
		add_child(board_info_label)

func update_turn(player: int) -> void:
	if turn_label:
		var mark := "X" if player == 0 else "O"
		var color := NeonColors.for_player(player)
		turn_label.text = "Player %s's Turn" % mark
		turn_label.add_theme_color_override("font_color", color)

func update_scores(scores: Array[int]) -> void:
	if score_label:
		score_label.text = "X: %d  |  O: %d" % [scores[0], scores[1]]

func update_round(round_num: int) -> void:
	if round_label:
		round_label.text = "Round %d" % round_num

func update_board_info(board_size: int, win_length: int) -> void:
	if board_info_label:
		board_info_label.text = "%dx%d | %d-in-a-row" % [board_size, board_size, win_length]

func update_complications(complications: Array[ComplicationBase]) -> void:
	if not complication_container:
		return

	for child in complication_container.get_children():
		child.queue_free()

	for comp in complications:
		var icon_label := Label.new()
		icon_label.text = comp.display_name.substr(0, 2).to_upper()
		icon_label.add_theme_font_size_override("font_size", 14)
		icon_label.add_theme_color_override("font_color", comp.color)
		icon_label.tooltip_text = "%s: %s" % [comp.display_name, comp.description]

		var panel := PanelContainer.new()
		panel.add_child(icon_label)
		complication_container.add_child(panel)

func update_timer(time_left: float, time_max: float = 15.0) -> void:
	if timer_bar:
		timer_bar.visible = true
		timer_bar.max_value = time_max
		timer_bar.value = time_left

		if time_left < 3.0:
			timer_bar.modulate = Color(1.0, 0.2, 0.2)
		else:
			timer_bar.modulate = Color.WHITE

func update_steal_available(x_steal: bool, o_steal: bool) -> void:
	if steal_label:
		var parts: Array[String] = []
		if x_steal:
			parts.append("X can steal!")
		if o_steal:
			parts.append("O can steal!")

		if parts.is_empty():
			steal_label.visible = false
		else:
			steal_label.visible = true
			steal_label.text = " | ".join(parts)
			steal_label.add_theme_color_override("font_color", NeonColors.ACCENT)
