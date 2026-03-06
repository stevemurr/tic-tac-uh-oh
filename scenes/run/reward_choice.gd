extends Control

@onready var title_label: Label = $ContentMargin/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $ContentMargin/VBoxContainer/SubtitleLabel
@onready var options_container: VBoxContainer = $ContentMargin/VBoxContainer/OptionsContainer
@onready var skip_btn: Button = $ContentMargin/VBoxContainer/SkipButton


func _ready() -> void:
	if skip_btn and not skip_btn.pressed.is_connected(_on_skip_pressed):
		skip_btn.pressed.connect(_on_skip_pressed)
	if RunState.last_reward_options.is_empty():
		RunState.complete_reward_node_without_pick()
		get_tree().change_scene_to_file("res://scenes/run/castle_map.tscn")
		return
	_build_options()


func _build_options() -> void:
	var node = RunState.get_current_node()
	title_label.text = node.title if node else "Choose a Reward"
	subtitle_label.text = "Take one reward and continue the climb."

	for child in options_container.get_children():
		child.queue_free()

	for index in RunState.last_reward_options.size():
		options_container.add_child(_make_option_card(index, RunState.last_reward_options[index]))


func _make_option_card(index: int, option) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_style(option.rarity))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

	var title := Label.new()
	title.text = option.display_name
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", _rarity_color(option.rarity))
	content.add_child(title)

	var desc := Label.new()
	desc.text = option.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", NeonColors.TEXT_MUTED)
	content.add_child(desc)

	var button := Button.new()
	button.text = "Claim"
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(_on_option_pressed.bind(index))
	content.add_child(button)

	return card


func _make_card_style(rarity: String) -> StyleBoxFlat:
	var color := _rarity_color(rarity)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NeonColors.SURFACE.r, NeonColors.SURFACE.g, NeonColors.SURFACE.b, 0.84)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(color.r, color.g, color.b, 0.34)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 20
	style.content_margin_left = 18.0
	style.content_margin_top = 18.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 18.0
	return style


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"starter":
			return NeonColors.PLAYER_X
		"rare":
			return NeonColors.WILDCARD
		_:
			return NeonColors.ACCENT


func _on_option_pressed(index: int) -> void:
	if RunState.claim_reward(index):
		get_tree().change_scene_to_file("res://scenes/run/castle_map.tscn")


func _on_skip_pressed() -> void:
	RunState.complete_reward_node_without_pick()
	get_tree().change_scene_to_file("res://scenes/run/castle_map.tscn")
