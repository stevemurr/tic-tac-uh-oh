extends Control

signal play_again_pressed
signal menu_pressed

@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var play_again_btn: Button = $VBoxContainer/PlayAgainButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	if not has_node("Background"):
		var bg := ColorRect.new()
		bg.name = "Background"
		bg.color = NeonColors.GAME_OVER_BG
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(bg)
		move_child(bg, 0)

	if not has_node("VBoxContainer"):
		var vbox := VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.offset_left = -150.0
		vbox.offset_top = -120.0
		vbox.offset_right = 150.0
		vbox.offset_bottom = 120.0
		vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
		vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(vbox)

		result_label = Label.new()
		result_label.name = "ResultLabel"
		result_label.add_theme_font_size_override("font_size", 40)
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(result_label)

		score_label = Label.new()
		score_label.name = "ScoreLabel"
		score_label.add_theme_font_size_override("font_size", 24)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(score_label)

		stats_label = Label.new()
		stats_label.name = "StatsLabel"
		stats_label.add_theme_font_size_override("font_size", 16)
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_label)

		play_again_btn = Button.new()
		play_again_btn.name = "PlayAgainButton"
		play_again_btn.text = "Play Again"
		play_again_btn.pressed.connect(_on_play_again)
		vbox.add_child(play_again_btn)

		menu_btn = Button.new()
		menu_btn.name = "MenuButton"
		menu_btn.text = "Main Menu"
		menu_btn.pressed.connect(_on_menu)
		vbox.add_child(menu_btn)

func show_results() -> void:
	var winner := -1
	if GameState.scores[0] > GameState.scores[1]:
		winner = 0
	elif GameState.scores[1] > GameState.scores[0]:
		winner = 1

	if result_label:
		if GameState.all_complications_used() and winner == -1:
			result_label.text = "ULTIMATE STALEMATE!"
			result_label.add_theme_color_override("font_color", NeonColors.STALEMATE)
		elif winner == 0:
			result_label.text = "X WINS!"
			result_label.add_theme_color_override("font_color", NeonColors.PLAYER_X)
		elif winner == 1:
			result_label.text = "O WINS!"
			result_label.add_theme_color_override("font_color", NeonColors.PLAYER_O)
		else:
			result_label.text = "DRAW!"
			result_label.add_theme_color_override("font_color", NeonColors.DRAW)

	if score_label:
		score_label.text = "X: %d  |  O: %d" % [GameState.scores[0], GameState.scores[1]]

	if stats_label:
		stats_label.text = "Rounds: %d | Draws: %d | Complications: %d" % [
			GameState.round_number,
			GameState.draw_count,
			GameState.active_complications.size()
		]

	visible = true

func _on_play_again() -> void:
	visible = false
	play_again_pressed.emit()

func _on_menu() -> void:
	visible = false
	menu_pressed.emit()
