extends Control

var _title_tween: Tween

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var local_btn: Button = $VBoxContainer/LocalButton
@onready var ai_btn: Button = $VBoxContainer/AIButton
@onready var difficulty_container: VBoxContainer = $VBoxContainer/DifficultyContainer
@onready var easy_btn: Button = $VBoxContainer/DifficultyContainer/EasyButton
@onready var medium_btn: Button = $VBoxContainer/DifficultyContainer/MediumButton
@onready var hard_btn: Button = $VBoxContainer/DifficultyContainer/HardButton
@onready var size3_btn: Button = $VBoxContainer/SettingsContainer/BoardSizeButtons/Size3
@onready var size5_btn: Button = $VBoxContainer/SettingsContainer/BoardSizeButtons/Size5
@onready var size7_btn: Button = $VBoxContainer/SettingsContainer/BoardSizeButtons/Size7
@onready var complication_toggle: CheckButton = $VBoxContainer/SettingsContainer/ComplicationToggle

func _ready() -> void:
	_setup_ui()
	if difficulty_container:
		difficulty_container.visible = false
	_start_title_glow()

func _setup_ui() -> void:
	if not has_node("Background"):
		var bg := ColorRect.new()
		bg.name = "Background"
		bg.color = NeonColors.BG_DARK
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		move_child(bg, 0)

	if not has_node("VBoxContainer"):
		var vbox := VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 20)
		add_child(vbox)

		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = "TIC-TAC-UH-OH"
		title_label.add_theme_font_size_override("font_size", 48)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", NeonColors.TITLE)
		vbox.add_child(title_label)

		local_btn = Button.new()
		local_btn.name = "LocalButton"
		local_btn.text = "Local 2 Player"
		local_btn.custom_minimum_size = Vector2(250, 50)
		local_btn.pressed.connect(_on_local_pressed)
		vbox.add_child(local_btn)

		ai_btn = Button.new()
		ai_btn.name = "AIButton"
		ai_btn.text = "VS AI"
		ai_btn.custom_minimum_size = Vector2(250, 50)
		ai_btn.pressed.connect(_on_ai_pressed)
		vbox.add_child(ai_btn)

		difficulty_container = VBoxContainer.new()
		difficulty_container.name = "DifficultyContainer"
		difficulty_container.visible = false
		difficulty_container.add_theme_constant_override("separation", 10)
		vbox.add_child(difficulty_container)

		var diff_label := Label.new()
		diff_label.text = "Select Difficulty:"
		diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		difficulty_container.add_child(diff_label)

		easy_btn = Button.new()
		easy_btn.name = "EasyButton"
		easy_btn.text = "Easy"
		easy_btn.pressed.connect(_on_easy)
		difficulty_container.add_child(easy_btn)

		medium_btn = Button.new()
		medium_btn.name = "MediumButton"
		medium_btn.text = "Medium"
		medium_btn.pressed.connect(_on_medium)
		difficulty_container.add_child(medium_btn)

		hard_btn = Button.new()
		hard_btn.name = "HardButton"
		hard_btn.text = "Hard"
		hard_btn.pressed.connect(_on_hard)
		difficulty_container.add_child(hard_btn)
		_create_settings_nodes(vbox)
	else:
		if local_btn: local_btn.pressed.connect(_on_local_pressed)
		if ai_btn: ai_btn.pressed.connect(_on_ai_pressed)
		if easy_btn: easy_btn.pressed.connect(_on_easy)
		if medium_btn: medium_btn.pressed.connect(_on_medium)
		if hard_btn: hard_btn.pressed.connect(_on_hard)
		_wire_settings_signals()

func _start_title_glow() -> void:
	if not title_label or DisplayServer.get_name() == "headless":
		return
	title_label.add_theme_color_override("font_color", NeonColors.TITLE)
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title_label, "modulate:a", 0.7, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _create_settings_nodes(parent: Node) -> void:
	var settings := VBoxContainer.new()
	settings.name = "SettingsContainer"
	settings.add_theme_constant_override("separation", 10)
	parent.add_child(settings)

	var size_label := Label.new()
	size_label.text = "Board Size:"
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.add_child(size_label)

	var size_hbox := HBoxContainer.new()
	size_hbox.name = "BoardSizeButtons"
	size_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	size_hbox.add_theme_constant_override("separation", 10)
	settings.add_child(size_hbox)

	var group := ButtonGroup.new()
	for size_val in [3, 5, 7]:
		var btn := Button.new()
		btn.name = "Size%d" % size_val
		btn.text = "%d×%d" % [size_val, size_val]
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = (size_val == 3)
		btn.pressed.connect(_on_board_size_selected.bind(size_val))
		size_hbox.add_child(btn)

	size3_btn = size_hbox.get_node("Size3")
	size5_btn = size_hbox.get_node("Size5")
	size7_btn = size_hbox.get_node("Size7")

	complication_toggle = CheckButton.new()
	complication_toggle.name = "ComplicationToggle"
	complication_toggle.text = "Start with random complication"
	complication_toggle.toggled.connect(_on_complication_toggled)
	settings.add_child(complication_toggle)

func _wire_settings_signals() -> void:
	var group := ButtonGroup.new()
	for btn_info in [[size3_btn, 3], [size5_btn, 5], [size7_btn, 7]]:
		var btn: Button = btn_info[0]
		var size_val: int = btn_info[1]
		if btn:
			btn.button_group = group
			btn.pressed.connect(_on_board_size_selected.bind(size_val))
	if complication_toggle:
		complication_toggle.toggled.connect(_on_complication_toggled)

func _on_board_size_selected(size_val: int) -> void:
	GameState.start_board_size = size_val

func _on_complication_toggled(enabled: bool) -> void:
	GameState.start_with_complication = enabled

func _apply_settings_and_start() -> void:
	GameState.reset_session()
	if GameState.start_with_complication:
		var comp = ComplicationRegistry.pick_random([])
		if comp:
			GameState.add_complication(comp)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_local_pressed() -> void:
	GameState.game_mode = GameState.GameMode.LOCAL_2P
	_apply_settings_and_start()

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
