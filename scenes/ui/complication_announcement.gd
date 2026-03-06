extends Control

signal announcement_finished

@onready var bg: ColorRect = $Background
@onready var announcement_card: PanelContainer = $CenterContainer/AnnouncementCard
@onready var title_label: Label = $CenterContainer/AnnouncementCard/VBoxContainer/TitleLabel
@onready var name_label: Label = $CenterContainer/AnnouncementCard/VBoxContainer/NameLabel
@onready var desc_label: Label = $CenterContainer/AnnouncementCard/VBoxContainer/DescLabel

func _ready() -> void:
	if bg:
		bg.mouse_filter = Control.MOUSE_FILTER_STOP

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
	if announcement_card:
		announcement_card.scale = Vector2(0.84, 0.84)
		announcement_card.pivot_offset = announcement_card.size / 2.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	if announcement_card:
		tween.tween_property(announcement_card, "scale", Vector2(1.04, 1.04), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.chain().tween_property(announcement_card, "scale", Vector2.ONE, 0.12)
	await tween.finished

	await get_tree().create_timer(1.8).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade_tween.finished

	announcement_finished.emit()
