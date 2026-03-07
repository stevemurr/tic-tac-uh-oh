extends Control

const START_OPTION_NONE := "__none__"
const START_OPTION_RANDOM := "__random__"

var _title_tween: Tween
var _debug_selection: String = START_OPTION_NONE
var _debug_button_group: ButtonGroup

@onready var title_label: Label = $ContentMargin/VBoxContainer/HeroPanel/HeroContent/TitleLabel
@onready var local_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/LocalButton
@onready var online_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/OnlineButton
@onready var ai_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/AIButton
@onready var castle_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/CastleButton
@onready var dungeon_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DungeonButton
@onready var difficulty_container: VBoxContainer = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer
@onready var easy_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer/DifficultyButtons/EasyButton
@onready var medium_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer/DifficultyButtons/MediumButton
@onready var hard_btn: Button = $ContentMargin/VBoxContainer/ModePanel/ModeContent/DifficultyContainer/DifficultyButtons/HardButton
@onready var size3_btn: Button = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/BoardSizeButtons/Size3
@onready var size5_btn: Button = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/BoardSizeButtons/Size5
@onready var size7_btn: Button = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/BoardSizeButtons/Size7
@onready var debug_start_flow: HFlowContainer = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/DebugStartFlow
@onready var debug_summary_label: Label = $ContentMargin/VBoxContainer/SettingsPanel/SettingsContent/DebugSummaryLabel

func _ready() -> void:
	_wire_mode_signals()
	_wire_settings_signals()
	if difficulty_container:
		difficulty_container.visible = false
	_build_debug_start_options()
	_sync_settings_from_ui()
	_start_title_glow()

func _wire_mode_signals() -> void:
	_connect_pressed(local_btn, _on_local_pressed)
	_connect_pressed(online_btn, _on_online_pressed)
	_connect_pressed(ai_btn, _on_ai_pressed)
	_connect_pressed(castle_btn, _on_castle_pressed)
	_connect_pressed(dungeon_btn, _on_dungeon_pressed)
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

func _build_debug_start_options() -> void:
	if not debug_start_flow:
		return

	for child in debug_start_flow.get_children():
		child.queue_free()

	_debug_button_group = ButtonGroup.new()
	_add_debug_option("Standard", START_OPTION_NONE, "Start clean with no opening complication.")
	_add_debug_option("Random", START_OPTION_RANDOM, "Start with one random complication immediately.")

	var complications: Array[ComplicationBase] = ComplicationRegistry.get_all().duplicate()
	complications.sort_custom(func(a: ComplicationBase, b: ComplicationBase) -> bool: return a.display_name < b.display_name)
	for comp in complications:
		_add_debug_option(comp.display_name, comp.complication_id, comp.description)

	_update_debug_selection(START_OPTION_NONE, "Start clean with no opening complication.")

func _add_debug_option(label_text: String, option_id: String, description: String) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _debug_button_group
	button.text = label_text
	button.custom_minimum_size = Vector2(0, 44)
	button.tooltip_text = description
	if option_id == START_OPTION_NONE:
		button.button_pressed = true

	var callback := _on_debug_option_selected.bind(option_id, description)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

	debug_start_flow.add_child(button)

func _on_debug_option_selected(option_id: String, description: String) -> void:
	_update_debug_selection(option_id, description)

func _update_debug_selection(option_id: String, description: String) -> void:
	_debug_selection = option_id
	if not debug_summary_label:
		return

	match option_id:
		START_OPTION_NONE:
			debug_summary_label.text = "Standard opening. No complication is active at the start."
		START_OPTION_RANDOM:
			debug_summary_label.text = "Random opening enabled. One complication is chosen as soon as the match begins."
		_:
			debug_summary_label.text = "Debug start: %s. %s" % [_format_complication_name(option_id), description]

func _format_complication_name(complication_id: String) -> String:
	var comp: ComplicationBase = ComplicationRegistry.get_by_id(complication_id)
	if comp:
		return comp.display_name
	return complication_id.replace("_", " ").capitalize()

func _start_title_glow() -> void:
	if not title_label or DisplayServer.get_name() == "headless":
		return
	title_label.add_theme_color_override("font_color", NeonColors.TITLE)
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title_label, "modulate:a", 0.92, 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 1.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _on_board_size_selected(size_val: int) -> void:
	GameState.start_board_size = size_val

func _apply_settings_and_start() -> void:
	GameState.start_with_complication = _debug_selection != START_OPTION_NONE
	GameState.reset_session()
	match _debug_selection:
		START_OPTION_RANDOM:
			var random_comp := ComplicationRegistry.pick_random([])
			if random_comp:
				GameState.add_complication(random_comp)
		START_OPTION_NONE:
			pass
		_:
			var selected_comp := ComplicationRegistry.create_fresh(_debug_selection)
			if selected_comp:
				GameState.add_complication(selected_comp)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_local_pressed() -> void:
	GameState.game_mode = GameState.GameMode.LOCAL_2P
	_apply_settings_and_start()

func _on_online_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/online_lobby.tscn")

func _on_ai_pressed() -> void:
	if difficulty_container:
		difficulty_container.visible = true

func _on_castle_pressed() -> void:
	GameState.game_mode = GameState.GameMode.CASTLE_ASCENT
	get_tree().change_scene_to_file("res://scenes/run/character_select.tscn")

func _on_dungeon_pressed() -> void:
	GameState.game_mode = GameState.GameMode.DUNGEON_CRAWL
	DungeonState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_map.tscn")

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
