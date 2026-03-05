extends Control

signal announcement_finished

@onready var bg: ColorRect = $Background
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	if not bg:
		bg = ColorRect.new()
		bg.name = "Background"
		bg.color = NeonColors.OVERLAY_BG
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(bg)
		move_child(bg, 0)

	if not has_node("VBoxContainer"):
		var vbox := VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(vbox)

		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = "NEW COMPLICATION!"
		title_label.add_theme_font_size_override("font_size", 20)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", NeonColors.ACCENT)
		vbox.add_child(title_label)

		name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.add_theme_font_size_override("font_size", 36)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		desc_label = Label.new()
		desc_label.name = "DescLabel"
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

func show_complication(comp: Resource) -> void:
	visible = true

	if title_label:
		title_label.add_theme_color_override("font_color", NeonColors.ACCENT)
	if name_label:
		name_label.text = comp.display_name
		name_label.add_theme_color_override("font_color", comp.color)
	if desc_label:
		desc_label.text = comp.description

	# Enhanced entrance: scale bounce + fade
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	pivot_offset = size / 2.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.1)
	await tween.finished

	await get_tree().create_timer(1.8).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_tween.finished

	announcement_finished.emit()
