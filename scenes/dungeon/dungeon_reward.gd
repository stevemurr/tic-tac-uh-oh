extends Control

@onready var title_label: Label = $ContentMargin/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $ContentMargin/VBoxContainer/SubtitleLabel
@onready var options_container: VBoxContainer = $ContentMargin/VBoxContainer/OptionsContainer
@onready var skip_btn: Button = $ContentMargin/VBoxContainer/FooterRow/SkipButton
@onready var continue_btn: Button = $ContentMargin/VBoxContainer/FooterRow/ContinueButton


func _ready() -> void:
	if skip_btn and not skip_btn.pressed.is_connected(_on_skip_pressed):
		skip_btn.pressed.connect(_on_skip_pressed)
	if continue_btn and not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)

	if DungeonState.last_reward_options.is_empty():
		DungeonState.complete_reward_node_without_pick()
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_map.tscn")
		return

	_build_options()


func _build_options() -> void:
	title_label.text = "Choose Your Reward"
	subtitle_label.text = "Take gear, patch yourself up, or bank the gold before pushing deeper."

	for child in options_container.get_children():
		child.queue_free()

	for index in DungeonState.last_reward_options.size():
		options_container.add_child(_make_option_card(index, DungeonState.last_reward_options[index]))


func _make_option_card(index: int, option: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_style(Color(option.get("accent_color", Color.WHITE))))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

	var title := Label.new()
	title.text = String(option.get("display_name", "Reward"))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(option.get("accent_color", Color.WHITE)))
	content.add_child(title)

	var desc := Label.new()
	desc.text = String(option.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", NeonColors.TEXT_MUTED)
	content.add_child(desc)

	var button := Button.new()
	button.text = "Take"
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(_on_option_pressed.bind(index))
	content.add_child(button)

	return card


func _make_card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NeonColors.SURFACE.r, NeonColors.SURFACE.g, NeonColors.SURFACE.b, 0.84)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.5
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_blend = true
	style.border_color = Color(color.r, color.g, color.b, 0.34)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_detail = 18
	style.expand_margin_left = 1.0
	style.expand_margin_top = 1.0
	style.expand_margin_right = 1.0
	style.expand_margin_bottom = 1.0
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 20
	style.content_margin_left = 18.0
	style.content_margin_top = 18.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 18.0
	return style


func _on_option_pressed(index: int) -> void:
	if DungeonState.claim_reward(index):
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_map.tscn")


func _on_skip_pressed() -> void:
	DungeonState.complete_reward_node_without_pick()
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_map.tscn")


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_map.tscn")
