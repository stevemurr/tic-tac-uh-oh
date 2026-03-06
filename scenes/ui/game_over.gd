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

func _update_action_labels() -> void:
	if GameState.game_mode == GameState.GameMode.CASTLE_ASCENT and play_again_btn and menu_btn:
		play_again_btn.text = "Continue"
		menu_btn.text = "Abandon Run"
		return
	if GameState.game_mode == GameState.GameMode.ONLINE and play_again_btn:
		play_again_btn.text = "Rematch"
		if menu_btn:
			menu_btn.text = "Main Menu"
	elif play_again_btn and menu_btn:
		play_again_btn.text = "Play Again"
		menu_btn.text = "Main Menu"


func show_results() -> void:
	_update_action_labels()
	var winner := -1
	if GameState.scores[0] > GameState.scores[1]:
		winner = 0
	elif GameState.scores[1] > GameState.scores[0]:
		winner = 1

	if result_label:
		if GameState.game_mode == GameState.GameMode.CASTLE_ASCENT:
			var current_node = RunState.get_current_node()
			if winner == 0:
				result_label.text = "ENCOUNTER CLEARED"
				if current_node and current_node.node_type == "boss":
					result_label.text = "GATE WARDEN FALLS"
				result_label.add_theme_color_override("font_color", NeonColors.SUCCESS)
			else:
				result_label.text = "ENCOUNTER LOST"
				result_label.add_theme_color_override("font_color", Color(1.0, 0.44, 0.3))
		elif GameState.all_complications_used() and winner == -1:
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
		if GameState.game_mode == GameState.GameMode.CASTLE_ASCENT:
			var current_node = RunState.get_current_node()
			score_label.text = "%s  |  X: %d  O: %d" % [
				current_node.title if current_node else "Castle Ascent",
				GameState.scores[0],
				GameState.scores[1],
			]
		else:
			score_label.text = "X: %d  |  O: %d" % [GameState.scores[0], GameState.scores[1]]

	if stats_label:
		if GameState.game_mode == GameState.GameMode.CASTLE_ASCENT:
			stats_label.text = "Resolve: %d/%d | Sigils: %d | Runes: %d" % [
				RunState.resolve,
				RunState.max_resolve,
				RunState.sigils,
				RunState.equipped_runes.size()
			]
		else:
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
