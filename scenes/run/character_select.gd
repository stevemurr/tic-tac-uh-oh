extends Control

const RunContentRegistryScript = preload("res://scripts/run/run_content_registry.gd")

@onready var character_cards: HFlowContainer = $ContentMargin/VBoxContainer/CharacterCards
@onready var back_btn: Button = $ContentMargin/VBoxContainer/BackButton


func _ready() -> void:
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	_build_character_cards()


func _build_character_cards() -> void:
	for child in character_cards.get_children():
		child.queue_free()

	for character in RunContentRegistryScript.get_all_characters():
		character_cards.add_child(_make_character_card(character))


func _make_character_card(character) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 240)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(character.color))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)

	var title := Label.new()
	title.text = character.display_name
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", character.color)
	content.add_child(title)

	var desc := Label.new()
	desc.text = character.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", NeonColors.TEXT_MUTED)
	content.add_child(desc)

	var active := Label.new()
	active.text = "Active: %s" % character.active_name
	active.add_theme_color_override("font_color", NeonColors.ACCENT)
	content.add_child(active)

	var starter := Label.new()
	starter.text = "Starter rune: %s" % _get_rune_name(character.starter_rune_id)
	starter.add_theme_color_override("font_color", NeonColors.TEXT_MUTED)
	content.add_child(starter)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content.add_child(spacer)

	var button := Button.new()
	button.text = "Begin Ascent"
	button.custom_minimum_size = Vector2(0, 52)
	button.pressed.connect(_on_character_selected.bind(character.character_id))
	content.add_child(button)

	return card


func _make_card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NeonColors.SURFACE.r, NeonColors.SURFACE.g, NeonColors.SURFACE.b, 0.84)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(color.r, color.g, color.b, 0.34)
	style.corner_radius_top_left = 26
	style.corner_radius_top_right = 26
	style.corner_radius_bottom_right = 26
	style.corner_radius_bottom_left = 26
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 24
	style.content_margin_left = 20.0
	style.content_margin_top = 20.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 20.0
	return style


func _get_rune_name(rune_id: String) -> String:
	var rune = RunContentRegistryScript.create_rune(rune_id)
	return rune.display_name if rune else rune_id


func _on_character_selected(character_id: String) -> void:
	GameState.game_mode = GameState.GameMode.CASTLE_ASCENT
	RunState.start_new_run(character_id)
	get_tree().change_scene_to_file("res://scenes/run/castle_map.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
