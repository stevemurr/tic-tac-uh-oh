extends Control

signal play_again_pressed
signal menu_pressed

@onready var result_label: Label = $CenterContainer/GameOverCard/VBoxContainer/ResultLabel
@onready var score_label: Label = $CenterContainer/GameOverCard/VBoxContainer/ScoreLabel
@onready var stats_label: Label = $CenterContainer/GameOverCard/VBoxContainer/StatsLabel
@onready var play_again_btn: Button = $CenterContainer/GameOverCard/VBoxContainer/PlayAgainButton
@onready var menu_btn: Button = $CenterContainer/GameOverCard/VBoxContainer/MenuButton

func _ready() -> void:
	if play_again_btn and not play_again_btn.pressed.is_connected(_on_play_again):
		play_again_btn.pressed.connect(_on_play_again)
	if menu_btn and not menu_btn.pressed.is_connected(_on_menu):
		menu_btn.pressed.connect(_on_menu)

func _update_for_online() -> void:
	if GameState.game_mode == GameState.GameMode.ONLINE and play_again_btn:
		play_again_btn.text = "Rematch"


func show_results() -> void:
	_update_for_online()
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
		stats_label.text = "Rounds: %d | Draws: %d | Active complications: %d" % [
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
