extends Control

var _title_tween: Tween

@onready var title_label: Label = $ContentMargin/VBoxContainer/HeroPanel/HeroContent/TitleLabel
@onready var local_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/LocalButton
@onready var online_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/OnlineButton
@onready var ai_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/AIButton
@onready var difficulty_container: VBoxContainer = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer
@onready var easy_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer/DifficultyButtons/EasyButton
@onready var medium_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer/DifficultyButtons/MediumButton
@onready var hard_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer/DifficultyButtons/HardButton
@onready var size3_btn: Button = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/BoardSizeButtons/Size3
@onready var size5_btn: Button = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/BoardSizeButtons/Size5
@onready var size7_btn: Button = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/BoardSizeButtons/Size7
@onready var complication_toggle: CheckButton = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/ComplicationToggle

func _ready() -> void:
	_wire_mode_signals()
	_wire_settings_signals()
	if difficulty_container:
		difficulty_container.visible = false
	_sync_settings_from_ui()
	_start_title_glow()

func _wire_mode_signals() -> void:
	_connect_pressed(local_btn, _on_local_pressed)
	_connect_pressed(online_btn, _on_online_pressed)
	_connect_pressed(ai_btn, _on_ai_pressed)
	_connect_pressed(easy_btn, _on_easy)
	_connect_pressed(medium_btn, _on_medium)
	_connect_pressed(hard_btn, _on_hard)

func _wire_settings_signals() -> void:
	var group := ButtonGroup.new()
	for btn_info in [[size3_btn, 3], [size5_btn, 5], [size7_btn, 7]]:
		var btn: Button = btn_info[0]
		var size_val: int = btn_info[1]
		if btn == null:
			continue
		btn.button_group = group
		var callback := _on_board_size_selected.bind(size_val)
		if not btn.pressed.is_connected(callback):
			btn.pressed.connect(callback)

	if complication_toggle and not complication_toggle.toggled.is_connected(_on_complication_toggled):
		complication_toggle.toggled.connect(_on_complication_toggled)

func _connect_pressed(button: Button, callback: Callable) -> void:
	if button and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _sync_settings_from_ui() -> void:
	if size5_btn and size5_btn.button_pressed:
		GameState.start_board_size = 5
	elif size7_btn and size7_btn.button_pressed:
		GameState.start_board_size = 7
	else:
		GameState.start_board_size = 3

	if complication_toggle:
		GameState.start_with_complication = complication_toggle.button_pressed

func _start_title_glow() -> void:
	if not title_label or DisplayServer.get_name() == "headless":
		return
	title_label.add_theme_color_override("font_color", NeonColors.TITLE)
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title_label, "modulate:a", 0.78, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _on_board_size_selected(size_val: int) -> void:
	GameState.start_board_size = size_val

func _on_complication_toggled(enabled: bool) -> void:
	GameState.start_with_complication = enabled

func _apply_settings_and_start() -> void:
	GameState.reset_session()
	if GameState.start_with_complication:
		var comp := ComplicationRegistry.pick_random([])
		if comp:
			GameState.add_complication(comp)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_local_pressed() -> void:
	GameState.game_mode = GameState.GameMode.LOCAL_2P
	_apply_settings_and_start()

func _on_online_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/online_lobby.tscn")

func _on_ai_pressed() -> void:
	if difficulty_container:
		difficulty_container.visible = true

func _on_easy() -> void:
	_start_ai_game(GameState.Difficulty.EASY)

func _on_medium() -> void:
	_start_ai_game(GameState.Difficulty.MEDIUM)

func _on_hard() -> void:
	_start_ai_game(GameState.Difficulty.HARD)

func _start_ai_game(diff: int) -> void:
	GameState.game_mode = GameState.GameMode.VS_AI
	GameState.difficulty = diff
	_apply_settings_and_start()
